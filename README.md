# llm_agent_config

Centralized Claude Code configuration with persistent memory via an Obsidian vault.
One repo, synced everywhere — local Mac, lab servers, anywhere you use Claude Code.

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

### 1. Initialize the vault (first time only)

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

### 4. Sync to lab servers

Push your local config to remote servers so they share the same setup:

```bash
# Sync to all servers
./sync-servers.sh

# Sync to a specific server only
./sync-servers.sh <server-alias>
```

First run copies the repo and runs setup. Later runs sync the latest changes.
See [Server Sync](#server-sync) for details.

---

## Workflow — How to Use This Well

### Starting a session

1. Open Claude Code in any project directory.
2. The session-start hook fires automatically — it detects your project and shows checkpoint headers.
3. If you need deeper context from a previous session, say: **"load vault context"** or Claude will spawn a subagent to read it.

### During work

Just work normally. The hooks handle everything in the background:
- Vault writes are validated automatically (frontmatter, naming, links).
- If you edit config files, you'll get a reminder to update vault docs.

### Saving context (before breaks or long sessions)

Type **`/checkpoint`** to save your current working state. This survives:
- Closing the terminal
- Context compaction (when the conversation gets too long)
- Switching between machines (via git sync)

### Taking notes

Type **`/obsidian-notes`** when you want Claude to remember something across sessions.
Only use this for non-trivial insights — the quality gate prevents note bloat.

### Starting on a new codebase

Type **`/project-archaeology`** once per project. Claude will deeply analyze the codebase and produce vault documentation so future sessions can get up to speed instantly.

### Vault health check

Type **`/obsidian-audit`** periodically (weekly or after creating many notes) to catch broken links, missing frontmatter, or misplaced notes.

### Ending a session

Just close the terminal. The session-end hook reminds Claude to log meaningful work.
Cron auto-commits and pushes every 5 minutes, so your vault is always backed up.

---

## Automatic Tasks

These run without you doing anything — triggered by hooks in `settings.json`.

| When | What Runs | What It Does |
|------|-----------|--------------|
| **You open Claude Code** | `session-start.sh` | Detects your project from the current directory, shows checkpoint headers so Claude knows where you left off |
| **You close Claude Code** | `session-stop.sh` | Reminds to log the session if meaningful work was done, checks for reusable patterns |
| **Context compacts** (conversation too long) | `pre-compact.sh` | Saves git state snapshot to `vault/agent/pre-compact-snapshot.md`, prints checkpoint headers for recovery |
| **Claude writes/edits a vault `.md` file** | `validate-vault-write.sh` | Checks the file has YAML frontmatter, lowercase-hyphenated filename, and at least one wikilink |
| **Claude writes/edits a vault `.md` file** | `detect-stale-notes.sh` | Warns if a config file changed but vault docs weren't updated |
| **Claude writes `working-context.md`** | `update-timeline.sh` | Appends a checkpoint summary to `timeline.md` — a permanent append-only history |
| **Every 5 minutes** (cron) | `server-sync.sh` | Auto-commits vault changes and pushes to GitHub |
| **Claude needs your attention** | `terminal-notifier` | macOS notification popup |

### What you trigger manually

| Command | What It Does |
|---------|--------------|
| `/checkpoint` | Saves current goal, plan, progress, decisions, and blockers to vault |
| `/obsidian-notes` | Take notes, recall context, build cross-session connections |
| `/obsidian-audit` | 14-point vault health check with scorecard |
| `/project-archaeology` | Deep 4-phase codebase analysis → vault documentation |

---

## Server Sync

Keeps your local machine and remote lab servers in sync via rsync over SSH.
No git credentials needed on the servers — everything is pushed from your local machine.

### How it works

```
Local Mac ──rsync──▶ server-1
            ──rsync──▶ server-2
```

- `sync-servers.sh` rsyncs the repo to each server, then runs `setup.sh` remotely to set up symlinks
- First run initializes everything (creates dirs, symlinks). Later runs just sync changes.

### First time setup

```bash
# Make sure you can SSH to your servers
ssh user@server.example.edu

# Then sync (handles init automatically)
./sync-servers.sh
```

The script checks on each server:
- Whether `~/llm_agent_config/` exists (copies if not)
- Whether symlinks are set up (runs `setup.sh` if not)
- Whether the vault structure is intact (creates missing dirs if needed)

### Ongoing sync

```bash
./sync-servers.sh              # all servers
./sync-servers.sh <alias>      # specific server only
```

Server list is defined at the top of `sync-servers.sh` — edit to add/remove servers.

---

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
| `sync-servers.sh` | Manual | Sync config to lab servers |
