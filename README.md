# llm_agent_config

Centralized Claude Code configuration with persistent memory via an Obsidian vault.

## Structure

```
.claude/              Claude Code configuration (symlinked to ~/.claude/)
  CLAUDE.md           Master instructions
  settings.json       Permissions, hooks
  rules/              Behavioral rules
  skills/             Slash commands (checkpoint, obsidian-notes, obsidian-audit, project-archaeology)
hooks/                Shell hooks for session lifecycle and vault validation
vault/                Obsidian vault (persistent memory)
```

## Setup

### 1. Initialize the vault

```bash
chmod +x init-vault.sh setup.sh hooks/*.sh
./init-vault.sh
```

### 2. Symlink Claude config

```bash
./setup.sh
```

This creates symlinks from `~/.claude/` to this repo's `.claude/` directory.

### 3. (Optional) Auto-sync via cron

To auto-commit and push every 5 minutes:

```bash
crontab -e
```

Add:

```
*/5 * * * * ~/llm_agent_config/hooks/server-sync.sh >> ~/llm_agent_config/hooks/sync.log 2>&1
```

## Skills

| Command | Description |
|---------|-------------|
| `/checkpoint` | Save working context for session recovery |
| `/obsidian-notes` | Take notes, recall context, build connections |
| `/obsidian-audit` | 14-point vault health check |
| `/project-archaeology` | Reverse-engineer a codebase into vault docs |

## Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| `session-start.sh` | Session start | Detect project, load checkpoint headers |
| `session-stop.sh` | Session end | Remind about session log |
| `pre-compact.sh` | Before compaction | Save git/vault snapshot |
| `validate-vault-write.sh` | Write/Edit | Check frontmatter, naming, wikilinks |
| `detect-stale-notes.sh` | Write/Edit | Warn when config changes but docs don't |
| `update-timeline.sh` | Write/Edit | Append checkpoint summaries to timeline |
| `server-sync.sh` | Cron (5 min) | Auto-commit and push |
