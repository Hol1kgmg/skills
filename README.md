# SKILL

他リポジトリで使う agent skill を管理するリポジトリ。`skills/<name>/SKILL.md` に 1 スキル 1 ディレクトリ。

## Install

### npx skills（Claude Code / Codex / Cursor など各エージェント対応）

```bash
npx skills add Hol1kgmg/SKILL                 # 対話的に選択
npx skills add Hol1kgmg/SKILL -s '*'          # 全部
npx skills add Hol1kgmg/SKILL -s dependabot-review -g   # グローバル
```

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

## Develop

```bash
mise run setup                 # ツール導入 + lefthook (gitleaks)
mise run new <name>            # 新規スキル雛形（npx skills init）
mise run validate              # claude plugin validate
claude --plugin-dir .          # ローカル動作確認
```
