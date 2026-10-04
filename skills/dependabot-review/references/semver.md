# semver ベースのバージョン差分判定

`nix` 以外の ecosystem(npm / github-actions / gomod / docker / pip / cargo など)のPRに適用する。PR一覧取得・基本情報取得・CI状態確認・レポート出力は SKILL.md 本体が担当するため、ここでは「変更内容の確認」と「判定」のみを行う。

## 1. バージョン差分の読み取り

各対象PRについて `gh pr view <番号> --json title,body` を取得する。

- **単独PR**: `title` の `bump X from A to B` から A→B を読む
- **group PR**(title が `bump the <group名> group ...` の形): title にバージョンは含まれないので、`body` 冒頭の「Updates `X` from A to B」の列挙(または表)から各パッケージのA→Bを読む。最も影響が大きい区分(major > minor > patch)を代表種別とする

A→B の区分:
- メジャー番号が変わっていれば major bump
- マイナー番号のみ変わっていれば minor bump
- パッチ番号のみ変わっていれば patch bump
- semver として読めない(docker の `alpine3.20` → `alpine3.21` のような日付・派生タグ等)場合は「種別不明」として ⚠️ 扱いにする

`headRefName` は新バージョンしか含まないことが多いため、新旧比較には使わない。

## 2. 変更内容の確認

```
gh pr diff <番号>
```

- `.github/dependabot.yml` の `directory` 配下にあるマニフェスト(`package.json` / `go.mod` / `Dockerfile` / `compose.yaml` / `pyproject.toml` / `Cargo.toml` / workflow yml など)で対象パッケージのバージョン変更を確認する
- lockfile(`pnpm-lock.yaml` / `package-lock.json` / `yarn.lock` / `go.sum` / `Cargo.lock` / `poetry.lock` など)以外に意図しない差分(アプリコードの変更等)が含まれていないか確認する
- github-actions は SHA pin と横の `# vN` コメントが両方更新されているか確認する
- major bump の場合は、body に記載された changelog / release notes へのリンクや breaking changes への言及を確認する

## 3. 判定基準

| 判定 | 条件 |
|---|---|
| ✅ マージ推奨 | CI全て成功 かつ コンフリクトなし かつ minor/patch bump かつ lockfile以外の意図しない差分なし |
| ⚠️ 要確認 | major bump/種別不明/CI pending/body に breaking changes の言及あり/lockfile以外に差分あり、のいずれかに該当 |
| ❌ マージ非推奨 | CI失敗 または コンフリクトあり |

`⚠️ 要確認` と判定したPRには、判定理由に加えて **具体的に何を確認すべきか** を必ず記載する。

- 対象パッケージのリリースノートURL(body 内のリンク、なければ `https://github.com/<owner>/<repo>/releases` で推測)を明記し、確認すべき breaking changes の観点(API変更・実行環境要件・設定ファイル形式の変更など)を具体的に書く
- body に breaking changes の記載があれば、それを直接引用して転記する
- group PR の場合は、その中でも影響範囲が大きいパッケージを名指しし、個別確認を促す
- 実行環境要件の変更(Node.js / Go / Python のバージョン等)が言及されている場合は、リポジトリ側でランタイムを固定しているファイル(`package.json` の `engines`、`go.mod` の `go` ディレクティブ、`.tool-versions` / `mise.toml`、`flake.nix` の devShell、CI の setup-* アクションなど、存在するもの)を実際に読み、要件を満たしているかどうかまで判定して記載する
- `package.json` の `packageManager`(pnpm / yarn 本体)の更新は lockfile の `lockfileVersion` が変わる可能性があるため、major bump でなくても lockfile の再生成が必要かを body で確認する
