# Project Overview
他リポジトリで使う agent skill を管理するリポジトリ。`skills/<name>/SKILL.md` に 1 スキル 1 ディレクトリで置く。リポジトリ全体が 1 つの Claude Code plugin（`.claude-plugin/`）であり、`npx skills add Hol1kgmg/SKILL` でも導入できる。新しいスキルを追加したら README.md の Skills 表も更新する。

# Setup and Basic Usage
Setup instructions and basic usage are documented in [README.md](./README.md).

# Work Rules
1. Propose implementation plan
2. Wait for approval
3. Start implementation

# Tool Usage Policy
**Prefer dedicated tools for file operations by default** (not enforced via `permissions.deny` — occasional Bash use is fine when it's genuinely more convenient):
- `ls`, `find` → `Glob` tool
- `cat`, `head`, `tail` → `Read` tool
- `grep` → `Grep` tool
- `sed`, `awk` → `Edit` tool
- File writing → `Write` tool
- `curl` → `WebFetch` tool

# Language Settings
- Responses: `.claude/settings.json` - `language`
- Thinking: English (for token reduction)
