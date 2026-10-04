# nix flake.lock のバージョン差分判定

`nix` ecosystem のPRに適用する。PR一覧取得・基本情報取得・CI状態確認・レポート出力は SKILL.md 本体が担当するため、ここでは「変更内容の確認」と「判定」のみを行う。

## なぜ semver 判定ができないか

flake の input はタグなしのコミット追従であることが多い。dependabot のPRタイトルは `bump <input> from <hash> to <hash>` の形式で、`gh pr diff` で見える `flake.lock` の差分も rev/narHash の変化だけ。実際にどのツールがいくつからいくつに動いたかは分からないため、`nix eval` で実バージョンを解決して比較する。

## 1. 変化した input の特定

```
gh pr diff <番号> -- flake.lock
```

ローカルの `flake.lock` を Read し、`nodes.root.inputs` に列挙されている名前を **直接 input** として把握する。差分の中で `locked.rev` が変わっている直接 input を特定し、旧 rev・新 rev・`locked.owner` / `locked.repo` を控える。

直接 input の下位(ある input が自前で持つ `nixpkgs` 等)だけが変わっている場合も、その親 input の rev が変わっているので親で扱う。

## 2. 各 input の役割を把握する

`flake.nix` を Read し、各直接 input が何に使われているかを分類する。

| 分類 | 例 | 扱い |
|---|---|---|
| devShell / packages で実際にツールを引いている | `nixpkgs`、オーバーレイ、自前の NUR | ステップ3で実バージョンを比較 |
| ビルドヘルパー・ライブラリのみ | `flake-utils`、`flake-parts` | CI(`nix flake check` 等)が通れば追加確認不要 |

## 3. 実バージョンの比較

`flake.nix` の `devShells.*.packages`(および `packages.*` で公開しているもの)に列挙された属性のうち、変化した input 由来のものを旧・新で解決して比較する。

**旧側は必ずローカルの `flake.lock`(main の checkout)から解決する。** rolling 系ブランチは履歴が書き換えられることがあり、旧 rev を `github:...` で直接指定すると tarball が 404 になる場合がある(ローカルの lock 済み rev は nix store にキャッシュ済みなので解決できる)。

```
# 旧(ローカル lock)
nix eval --impure --raw --expr '(builtins.getFlake (toString ./.)).inputs.<input>.<attrPath>.${builtins.currentSystem}.<attr>.version'
# 新(PR の新 rev)
nix eval --impure --raw --expr '(builtins.getFlake "github:<owner>/<repo>/<NEW_REV>").<attrPath>.${builtins.currentSystem}.<attr>.version'
```

- `<attrPath>` は nixpkgs 系なら `legacyPackages`、通常の flake なら `packages`
- `<owner>/<repo>` は `flake.lock` の `locked.owner` / `locked.repo`
- 各属性について旧→新のバージョンを一覧化する(変化なしも「変化なし」と明記する)
- 旧側では解決できたが新側で属性が見つからない場合(属性パスのリネーム等)は「属性解決失敗」として要確認扱いにする
- 新側の解決に失敗した場合はネットワークか rev の問題なので、「属性解決失敗」ではなく「解決不能」として要確認扱いにする

## 4. 判定基準

| 判定 | 条件 |
|---|---|
| ✅ マージ推奨 | CI全て成功 かつ コンフリクトなし かつ 比較対象の属性に変化なし |
| ⚠️ 要確認 | いずれかの属性のバージョンが変化/属性解決失敗/解決不能、のいずれかに該当 |
| ❌ マージ非推奨 | CI失敗 または コンフリクトあり |

利用側リポジトリの AGENTS.md / CLAUDE.md に「変化しても ✅ でよい属性」「必ず ⚠️ にする属性」が定義されていればそれを優先する。

⚠️ の場合の確認事項は、変化した属性の性質から書く:

- **ランタイム**(node / go / python 等): アプリ側でバージョンを固定しているファイル(`package.json` の `engines`、`go.mod` の `go` ディレクティブ等)や、デプロイ先の対応状況との整合性
- **コード生成ツール**(sqlc / oapi-codegen / protoc 等): マージ後に再生成して差分が出ないか(出るならコミットが必要か)
- **lint / fmt ツール**: ルール変更で CI が落ちないか(PR の CI が通っていれば通常は問題なし)
- **その他の CLI**: 変化を一覧に載せるのみでよい
