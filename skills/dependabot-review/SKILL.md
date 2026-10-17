---
name: dependabot-review
description: openなdependabotのPRを一覧し、ユーザーが選んだ対象PRについてマージ可能かをレビューする(デフォルトはcheck-only)。CI状態・コンフリクト有無を確認したうえで、ecosystemごとの手順(semver判定 / nix flake.lockの実バージョン比較 / flake = false な input の内容差分)でバージョン差分を判定し、レポートに統合する。ユーザーが複数PRのマージを明示指示した場合のみ、1件ずつマージ→残りをrebaseする手順に従いマージを実施する。
allowed-tools: Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr checks:*), Bash(gh pr merge:*), Bash(gh pr comment:*), Bash(gh run list:*), Bash(nix eval:*), Bash(git clone:*), Bash(git -C:*), Read, Grep, Glob, AskUserQuestion
---

# dependabot-review — dependabot PR マージ可否レビュー(デフォルトcheck-only)

openな dependabot PR を洗い出し、ユーザーが選んだ対象について CI・コンフリクト・変更内容を確認し、マージ可否を判定してレポートする。
変更内容の確認と判定は、対象PRの ecosystem に応じて以下の手順書に従う。

| ecosystem | 手順書 |
|---|---|
| `nix`(devShell / packages で使う input) | [references/nix-flake.md](references/nix-flake.md)(flake.lock は rev しか変わらないため `nix eval` で実バージョンを比較) |
| `nix`(`flake = false` で中身をそのまま配置する input。agent skill / rules など) | [references/nix-content-input.md](references/nix-content-input.md)(rev 間の内容差分を読んで安全性と挙動変化を判定) |
| それ以外(npm / github-actions / gomod / docker / pip / cargo / bundler など) | [references/semver.md](references/semver.md)(PRタイトル・bodyの `from A to B` から semver 判定) |

`nix` の 2 手順の振り分けは [references/nix-flake.md](references/nix-flake.md) のステップ 2 で行う。

リポジトリ固有の判定ルール(例: 「Node のバージョン変化は必ず要確認」「このツールは生成コードに影響する」)は、利用側リポジトリの AGENTS.md / CLAUDE.md に書かれていればそれに従う。なければ手順書のデフォルト基準を使う。

**デフォルトはチェックと報告のみを行う。`gh pr merge` / `gh pr close` などの状態変更操作は、ユーザーが明示的にマージを指示するまで行わない。**
- 1件のみのマージ指示 → `gh pr merge <番号> --squash --delete-branch` でよい
- 同一 ecosystem / directory(= 同一lockfileに触る)の**複数PR**のマージ指示 → 下記「複数PR承認時のマージ手順」に従う

## 手順

### 1. openな dependabot PR の一覧取得

```
gh pr list --author "app/dependabot" --state open --json number,title,headRefName,createdAt,url
```

- 結果が0件なら「openなdependabot PRはありません」と報告して終了する

### 2. ユーザーに対象PRを確認

AskUserQuestion で取得した一覧を提示し、どのPRをレビュー対象にするか選んでもらう。
- 選択肢には「すべてレビューする」を含める
- `$ARGUMENTS` にPR番号が明示されていればこのステップは省略し、指定されたPRを対象とする

### 3. ecosystem の判定

`.github/dependabot.yml` を Read し、定義されている `package-ecosystem` と `directory` の組を把握する。これがこのリポジトリで現れうる ecosystem の全てである。

各対象PRの `headRefName` から ecosystem と directory を判定する(dependabot のブランチ命名規則: `dependabot/<package-manager>/<directory>/<package>-<version>`。directory がルートの場合は省略される)。

| `headRefName` の第2セグメント | ecosystem |
|---|---|
| `npm_and_yarn` | npm |
| `github_actions` | github-actions |
| `go_modules` | gomod |
| `docker` | docker |
| `nix` | nix |
| `pip` / `cargo` / `bundler` / `composer` / `gradle` / `maven` 等 | 同名 |

判定に迷う場合は `gh pr view <番号> --json files` で変更ファイルを確認し、`dependabot.yml` の `directory` と照合する。

対象PRを ecosystem / directory ごとにグルーピングする。

### 4. 対象PRごとの詳細確認

各PRについて以下を取得・確認する(ecosystem共通の部分)。

**基本情報とマージ可否**
```
gh pr view <番号> --json number,title,body,mergeable,mergeStateStatus,additions,deletions,changedFiles,labels,url
```
- `mergeable` が `CONFLICTING` の場合はコンフリクトありとして明記する
- `mergeStateStatus` が `BLOCKED` の場合は理由(レビュー必須・CI未完了等)を推測して記載する

**CI状態**
```
gh pr checks <番号>
```
- 失敗しているチェックがあれば名前と結果を記載する
- pending中のチェックがあれば「CI実行中のため判定保留」と明記する

**変更内容とバージョン差分の判定(ecosystem別)**

ステップ3でグルーピングした ecosystem ごとに、対応する手順書を Read して従う。手順書は PRごとに「バージョン差分の種別」「判定(✅/⚠️/❌)」「⚠️の場合の確認事項」を確定させる。判定に使う CI状態・コンフリクト有無はこのステップで取得した値を使う。

### 5. レポート出力

チャット上に以下の形式で報告する:

```
## dependabot PR レビューレポート

| PR | パッケージ | バージョン | 種別 | CI | コンフリクト | 判定 | 備考 |
|---|---|---|---|---|---|---|---|
| #12 | eslint-plugin-... | 1.0.0→1.0.1 | patch | ✅ | なし | ✅ マージ推奨 | - |
| #5  | npm-minor-patch (group) | ... | minor | ✅ | なし | ⚠️ 要確認 | 8パッケージ一括更新、@tanstack/* を個別確認推奨 |
| #33 | nixpkgs | rev変更 | rev | ✅ | なし | ⚠️ 要確認 | nodejs: 24.15.0→24.16.0、他の devShell パッケージは変化なし |
| #40 | Hol1kgmg/skills (flake=false) | rev変更 | content | ✅ | なし | ⚠️ 要確認 | dependabot-review/SKILL.md に Bash 手順追加 |

### 詳細(要確認・非推奨のPRのみ)
- PR番号ごとに判定理由と確認事項を記載

### 対象外(レビュー未実施)
- 一覧取得したがユーザーが選ばなかったPRの番号とタイトル
```

- レポート末尾に「マージを進める場合は対象PR番号を指定してください」と付記し、実際のマージはユーザー指示を待つ

## 複数PR承認時のマージ手順

ユーザーが同一 ecosystem / directory の dependabot PR を**2件以上まとめてマージ**するよう指示した場合にのみ、この手順を使う。対象PRが1件のみ、または互いに異なる ecosystem / directory(同一lockfileを触らない)の場合は、個別に `gh pr merge <番号> --squash --delete-branch` すればよい。

### なぜ必要か

同一lockfileを触る複数PRを連続squashマージすると、各PRの lockfile 差分が「PR作成時点のmain」を基準にしたテキストパッチであるため、GitHub上ではコンフリクトとして検出されないまま lockfile が破損することがある(例: `pnpm-lock.yaml` に同じパッケージのエントリが重複して main のCIが壊れる)。これを防ぐため、1件マージするごとに残りのPRを dependabot に最新mainで作り直させてから次をマージする。

### 手順

1. マージ順を決める(通常はPR番号の昇順。ユーザー指定があればそれに従う)
2. 先頭のPRをマージする:
   ```
   gh pr merge <PR番号1> --squash --delete-branch
   ```
3. 残りの各PRに dependabot の rebase を依頼する(dependabot が最新mainを基準に lockfile を再生成して force-push する):
   ```
   gh pr comment <PR番号2> --body "@dependabot rebase"
   ```
4. rebase 完了後に再実行されたCIの結果を確認する(数分かかる。完了まで待つ):
   ```
   gh pr checks <PR番号2> --watch
   ```
   全てpassしたら次をマージする。失敗していれば内容をユーザーに提示し、指示を仰ぐ(自動で修正しない)
5. 残りPRがなくなるまで 2〜4 を、次のPRを対象にして繰り返す
6. 全マージ後、mainのCIが成功していることを確認する:
   ```
   gh run list --branch main --limit 1
   ```

### 注意事項

- rebase で dependabot がコンフリクトを解消できなかった場合、PRに dependabot がその旨コメントする。その場合は自動解決せず、ユーザーに提示して指示を仰ぐ
- `@dependabot rebase` はPRに手動コミットがあると拒否される。dependabot PR に手を入れている場合はユーザーに知らせる
