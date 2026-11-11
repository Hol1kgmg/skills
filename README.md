# SKILL

他リポジトリで使う agent skill を管理するリポジトリ。`skills/<name>/SKILL.md` に 1 スキル 1 ディレクトリ。

## Install

### npx skills（Claude Code / Codex / Cursor など各エージェント対応）

```bash
npx skills add Hol1kgmg/SKILL                 # 対話的に選択
npx skills add Hol1kgmg/SKILL -s '*'          # 全部
npx skills add Hol1kgmg/SKILL -s dependabot-review -g   # グローバル
```

### pnpm（v12.11+ / [Agent Skills](https://pnpm.io/ja/agent-skills)）

```bash
pnpm add -D @hol1kgmg/skills
pnpm approve      # 承認すると .claude/skills などに pnpm-@hol1kgmg+skills-<name> としてリンク
```

リンク先の `.<agent>/skills` ディレクトリが事前に必要（Claude Code 内から実行した場合は自動作成）。`pnpm dlx` / グローバルインストールでは無効。

### Claude Code plugin

```
/plugin marketplace add Hol1kgmg/SKILL
/plugin install hol1kgmg-skills@hol1kgmg
```

スキルは `/hol1kgmg-skills:<name>` で呼べる。

## Skills

| name | 概要 |
|---|---|
| dependabot-review | open な dependabot PR を一覧・レビュー。semver 判定と nix flake.lock の実バージョン比較は `references/` の手順書で分割 |
| speckit-explain | spec-kit ワークフローと各 speckit-* skill の説明 |
| cognitive-rhythm-writing | 説明文に緩急を設計する規範。出所: [gist](https://gist.github.com/k16shikano/eb2929f13ed19c97188393d297be8432)（Unlicense） |
| japanese-tech-writing | 日本語の技術文書の文章規範。出所: [gist](https://gist.github.com/k16shikano/fd287c3133457c4fd8f5601d34aa817d)（Unlicense） |

gist 由来の skill は `flake.nix` の input で版を固定し、`.github/workflows/vendor-gist-skills.yaml` が毎週金曜に最新化して main に直接 commit する。手で編集しない。

## Develop

```bash
mise run setup                 # ツール導入 + lefthook (gitleaks)
mise run new <name>            # 新規スキル雛形（npx skills init）
mise run validate              # claude plugin validate
claude --plugin-dir .          # ローカル動作確認
mise run publish               # npm へ公開（package.json の version を上げてから）
mise run vendor                # flake.lock の gist を skills/ に写す（nix が必要。更新は nix flake update <input>）
```
