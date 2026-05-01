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
./hooks/server-sync.sh

# Sync to a specific server only
./hooks/server-sync.sh <server-alias>
```

First run copies the repo and runs setup. Later runs sync the latest changes.
See [Server Sync](#server-sync) for details.

---

## Workflow — how to use this well

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

## Session lifecycle — file-level trace

```
SESSION START ──→ WORK ──→ CHECKPOINT ──→ (compaction) ──→ RECOVERY ──→ SESSION END
     │                         │               │               │              │
  reads vault              writes vault    saves snapshot   reads vault    writes vault
```

Every step reads from or writes to specific files. Here's the full trace.

### 1. Session start

When you open Claude Code in a project directory (e.g. `~/PSy_lab/psylab_comm/`):

```
┌─────────────────────────────────────────────────────────────┐
│  hooks/session-start.sh fires automatically                 │
│                                                             │
│  1. Takes your CWD: /Users/you/PSy_lab/psylab_comm         │
│  2. Extracts: "psylab_comm"                                 │
│  3. Converts: "psylab_comm" → "psylab-comm" (sed s/_/-/g)  │
│  4. Checks: does vault/projects/psylab-comm/ exist? → YES  │
│  5. Reads: vault/projects/*/working-context.md              │
│     (greps for "## Checkpoint" headers)                     │
│  6. Prints ~8 lines to Claude's context                     │
└─────────────────────────────────────────────────────────────┘
```

Output Claude sees:

```
Vault: /Users/you/llm_agent_config/vault
Project documentation detected: vault/projects/psylab-comm
CWD project: psylab-comm
Load vault context via subagent or obsidian-notes skill when starting project work.
```

That's ALL that enters Claude's context — just a few lines. The full vault stays outside. Then Claude spawns a subagent to load deeper context:

```
┌──────────────────────────────────────────────────────────────┐
│  Explore subagent (separate context, disposable)             │
│                                                              │
│  READS: vault/projects/psylab-comm/working-context.md        │
│  READS: any notes with "project: psylab-comm" frontmatter   │
│  RETURNS: 25-line summary to main Claude                     │
│  THEN: subagent context is discarded                         │
└──────────────────────────────────────────────────────────────┘
```

The subagent reads everything, distills it, and only the summary enters main context — keeping the context window clean.

### 2. Checkpoint

The most important skill. When you type `/checkpoint`:

```
┌─ Step 1: Claude writes working-context.md ───────────────────────────────┐
│                                                                           │
│  FILE: vault/projects/<project>/working-context.md                        │
│                                                                           │
│  APPENDS a new ---CHECKPOINT--- block:                                    │
│    - Current goal (quotes your words)                                     │
│    - Plan with [x] done / [ ] remaining                                   │
│    - Progress (specific file paths, function names)                       │
│    - Key decisions and WHY                                                │
│    - Active files being edited                                            │
│    - Open/blocked items                                                   │
│                                                                           │
│  Then TRIMS to keep only the last 5 checkpoints.                          │
└───────────────────────────────────────────────────────────────────────────┘
         │
         ▼ (PostToolUse hook fires automatically)
┌─ Step 2: update-timeline.sh extracts + appends ──────────────────────────┐
│                                                                           │
│  READS:  vault/projects/<project>/working-context.md                      │
│          (extracts the LAST checkpoint: goal, progress, open items)        │
│                                                                           │
│  WRITES: vault/projects/<project>/timeline.md                             │
│          (appends a 2-line summary — NEVER edits previous entries)         │
│                                                                           │
│  This is the PERMANENT record. Even when working-context.md trims         │
│  old checkpoints, timeline.md keeps every entry forever.                  │
└───────────────────────────────────────────────────────────────────────────┘
         │
         ▼ (another PostToolUse hook fires)
┌─ Step 3: validate-vault-write.sh checks the file ───────────────────────┐
│                                                                           │
│  READS: the file that was just written                                    │
│  CHECKS: frontmatter? lowercase filename? wikilinks?                      │
│  OUTPUT: error message if validation fails, silent if passes              │
└───────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─ Step 4: Claude writes session tag ──────────────────────────────────────┐
│                                                                           │
│  FILE: ~/.claude/.session-topic                                           │
│  CONTENT: one line, e.g. "API auth refactor"                              │
│  USED BY: pre-compact.sh (to know which checkpoint to recover)            │
└───────────────────────────────────────────────────────────────────────────┘
```

### 3. Compaction and recovery

When the conversation gets too long (at 40% of context window), Claude auto-compacts:

```
┌─ pre-compact.sh fires ───────────────────────────────────────────────────┐
│                                                                           │
│  READS: git status of all vault-tracked repos                             │
│  READS: recently modified vault notes                                     │
│                                                                           │
│  WRITES: vault/agent/pre-compact-snapshot.md                              │
│          (keeps last 5 snapshots — git branch, changes, recent commits)   │
│                                                                           │
│  PRINTS: checkpoint headers from all working-context.md files             │
│          (these survive compaction because they're hook output)            │
└───────────────────────────────────────────────────────────────────────────┘
         │
         │  (compaction happens — conversation history is compressed)
         │  (Claude loses intermediate reasoning, file contents it read)
         ▼
┌─ Recovery ────────────────────────────────────────────────────────────────┐
│                                                                           │
│  Claude sees the checkpoint headers printed by pre-compact.sh             │
│  Claude spawns Explore subagent to READ:                                  │
│    - vault/projects/<project>/working-context.md                          │
│    - vault/agent/pre-compact-snapshot.md                                  │
│  Subagent returns 25-line summary                                         │
│  Claude picks up exactly where it left off                                │
└───────────────────────────────────────────────────────────────────────────┘
```

### 4. Session end

When you close the terminal:

```
┌─ session-stop.sh fires ──────────────────────────────────────────────────┐
│                                                                           │
│  READS: vault/agent/session-log.md                                        │
│  CHECKS: was it updated today?                                            │
│                                                                           │
│  If NO → prints reminder:                                                 │
│    "SESSION LOG REMINDER: consider appending to session-log.md"           │
│    "PATTERN CHECK: any reusable pattern for instincts.yaml?"              │
│                                                                           │
│  DELETES: ~/.claude/.session-topic (cleanup)                              │
└───────────────────────────────────────────────────────────────────────────┘
```

### 5. Sync

Every 5 minutes via cron:

```
┌─ server-sync.sh ─────────────────────────────────────────────────────────┐
│                                                                           │
│  IN: ~/llm_agent_config/ (the whole repo)                                 │
│                                                                           │
│  1. git add -A && git commit (auto-commits vault changes)                 │
│  2. git push origin main (pushes to GitHub)                               │
│  3. rsync to lab servers                                                  │
│  4. On each server: checks symlinks, runs setup.sh if needed              │
│                                                                           │
│  LOGS TO: hooks/sync.log                                                  │
│  EXCLUDES: .git/, sync.log, settings.local.json, .obsidian workspace     │
└───────────────────────────────────────────────────────────────────────────┘
```

When you walk from your Mac to a lab server, the vault is already there.

### 6. Project archaeology

A one-time deep analysis of a codebase via `/project-archaeology`. Runs 4 phases:

```
Phase 1: Surface Scan    → reads README, pyproject.toml, file tree, git log
Phase 2: Deep Dives      → reads source code, traces data flow, design decisions
Phase 3: Verification    → pip install, pytest, verifies claims from Phase 2
Phase 4: Vault Notes     → writes Obsidian notes with evidence tags
```

During Phases 1-3 it works in a temporary scratch clone (`/tmp/archaeology-<project>-<timestamp>/`). This is deleted when Phase 4 succeeds. The permanent output is vault notes with `project:` frontmatter that future subagents find via grep:

```
vault/projects/<project>/
├── architecture-overview.md         ← project structure, class hierarchy, build/test
├── <theme>-subsystem.md             ← domain-specific deep dives
├── signal-chain-and-testing.md      ← TX/RX pipeline, test patterns
├── working-context.md               ← checkpoint (maintained by /checkpoint)
└── timeline.md                      ← permanent history (maintained by hook)
```

#### Archaeology notes are static

Archaeology notes are written once and never automatically updated. There is no hook that watches source code changes.

**When they go stale:**
- You add new modules or classes to the codebase
- You refactor the class hierarchy
- You change major design patterns
- Test counts or build commands change

**How to update them:**
1. **Run `/project-archaeology` again** — it will overwrite the existing notes with fresh analysis
2. **Update manually via `/obsidian-notes`** — tell Claude "update the beamforming-subsystem note, we added a new class"
3. **The `detect-stale-notes.sh` hook gives a nudge** — but only when you edit config/instruction files (CLAUDE.md, settings.json, hook scripts), not source code

**The gap:** There is no hook that says "you changed `gsc_bf.py`, so `beamforming-subsystem.md` might be stale." Staleness detection only watches config files. Archaeology notes can silently drift from reality.

**Mitigation:** The `working-context.md` checkpoints capture incremental changes session by session. The subagent reads both the (possibly stale) archaeology notes AND the (fresh) checkpoint, getting a blended picture. The archaeology notes provide the stable foundation, checkpoints provide the recent delta.

---

## Complete file map — who writes what, who reads what

| File | Written by | Read by |
|------|-----------|---------|
| `vault/projects/<proj>/working-context.md` | `/checkpoint` skill | `session-start.sh` (headers), `pre-compact.sh` (headers), Explore subagent (full), `update-timeline.sh` (extract) |
| `vault/projects/<proj>/timeline.md` | `update-timeline.sh` (auto) | You (in Obsidian or Claude) — reference only, never auto-read |
| `vault/projects/<proj>/*.md` (archaeology notes) | `/project-archaeology` or `/obsidian-notes` | Explore subagent (found via `project:` frontmatter grep) |
| `vault/agent/pre-compact-snapshot.md` | `pre-compact.sh` (auto) | Explore subagent (recovery after compaction) |
| `vault/agent/session-log.md` | Claude (end of session) | `session-stop.sh` (checks date), Explore subagent |
| `vault/agent/connections.md` | Claude (`/obsidian-notes`) | Explore subagent |
| `vault/agent/open-questions.md` | Claude | Explore subagent |
| `vault/agent/instincts.yaml` | Claude | Claude (pattern reference) |
| `~/.claude/.session-topic` | `/checkpoint` skill | `pre-compact.sh`, `session-stop.sh` (deletes) |
| `hooks/sync.log` | `server-sync.sh` (cron) | You (debugging sync) |

### Two write paths, one recovery path

```
Write path 1 — checkpoint (you control):
  /checkpoint → working-context.md → (auto) timeline.md

Write path 2 — compaction (automatic):
  context too long → pre-compact.sh → pre-compact-snapshot.md

Recovery path (always the same):
  session-start.sh prints headers → subagent reads working-context.md → 25-line summary
```

Whether you're starting a new session, recovering from compaction, or switching machines — the recovery path is identical.

---

## Automatic tasks

These run without you doing anything — triggered by hooks in `settings.json`.

| When | What runs | What it does |
|------|-----------|--------------|
| **You open Claude Code** | `session-start.sh` | Detects your project from the current directory, shows checkpoint headers so Claude knows where you left off |
| **You close Claude Code** | `session-stop.sh` | Reminds to log the session if meaningful work was done, checks for reusable patterns |
| **Context compacts** (conversation too long) | `pre-compact.sh` | Saves git state snapshot to `vault/agent/pre-compact-snapshot.md`, prints checkpoint headers for recovery |
| **Claude writes/edits a vault `.md` file** | `validate-vault-write.sh` | Checks the file has YAML frontmatter, lowercase-hyphenated filename, and at least one wikilink |
| **Claude writes/edits a vault `.md` file** | `detect-stale-notes.sh` | Warns if a config file changed but vault docs weren't updated |
| **Claude writes `working-context.md`** | `update-timeline.sh` | Appends a checkpoint summary to `timeline.md` — a permanent append-only history |
| **Every 5 minutes** (cron) | `server-sync.sh` | Auto-commits vault changes and pushes to GitHub |
| **Claude needs your attention** | `terminal-notifier` | macOS notification popup |

### When to use each skill

#### `/checkpoint` — save your place

**When:**
- Before taking a break or closing the terminal
- When context is getting heavy (long session, many tool calls)
- Before pivoting to a different task
- Before running `/compact`

**How often:** Every 30-60 minutes in an active session, or at natural breakpoints.

**What it produces:** Appends to `vault/projects/<project>/working-context.md`. The `update-timeline.sh` hook auto-appends a summary to `timeline.md`.

**Example:**
```
You've been debugging GSCBF tracking for 45 minutes.
You found the root cause and fixed it.
→ Type /checkpoint before moving on to the next task.
```

#### `/obsidian-notes` — remember something

**When:**
- A non-obvious solution was found (capture the reasoning, not just the fix)
- A meaningful connection between ideas surfaces
- You explicitly want Claude to remember something across sessions
- Project context was built that would take >5 minutes to reconstruct

**When NOT to:** Quick Q&A, simple file edits, information already in the codebase or git history.

**What it produces:** A new `.md` file in `vault/projects/` or `vault/areas/` with frontmatter, wikilinks, and evidence tags.

**Example:**
```
You discovered that the Sherman-Morrison inverse update in matrix.py
diverges when the forgetting factor β < 1 due to exponential error growth.
This took 20 minutes to figure out.
→ Tell Claude to note this, or type /obsidian-notes.
```

#### `/obsidian-audit` — check vault health

**When:**
- After creating 3+ vault notes in a session
- Weekly if the vault is actively growing
- When you suspect sync issues
- After a subagent creates vault content (verify it followed conventions)

**How often:** Weekly, or after any large note-creation session.

**What it produces:** A 14-point scorecard printed to the conversation (not saved to a file). Checks sync health, frontmatter, naming, wikilinks, orphans, content quality, folder depth, volume, and rules freshness. After the audit, it stamps `vault/.last-audit` with the current date.

**Example:**
```
You just ran /project-archaeology and it created 4 new notes.
→ Run /obsidian-audit to verify they all pass the quality gate.
```

**Weekly reminder (enabled by default):**

The `session-start.sh` hook checks `vault/.last-audit` on every session start. If the last audit was more than 7 days ago (or no audit has ever been run), it prints a reminder:

```
VAULT AUDIT OVERDUE: Last audit was 12 days ago (2026-04-18). Run /obsidian-audit.
```

This is not automatic execution — it's a nudge. You still decide whether to run it.

**How it works:**

```
/obsidian-audit runs
  → prints 14-point scorecard
  → stamps: vault/.last-audit = "2026-04-30"

Next session start (any project)
  → session-start.sh reads vault/.last-audit
  → compares to today
  → if >= 7 days: prints "VAULT AUDIT OVERDUE"
  → if < 7 days: silent
```

**Why not fully automatic?** A remote scheduled agent (via `/schedule`) can't access your local vault — it runs in Anthropic's cloud without your local files, cron, or symlinks. The session-start reminder is the practical alternative: it runs locally where the vault lives, and nudges you at the right time.

**Setup (already done by default):** The reminder is built into `hooks/session-start.sh`. No extra setup needed. If you want to change the interval from 7 days, edit the line `if [ "$DAYS_SINCE" -ge 7 ]` in the hook.

**To disable:** Remove or comment out the "Check if vault audit is overdue" block in `hooks/session-start.sh`.

#### `/project-archaeology` — deep codebase documentation

**When:**
- First time working on a codebase (run once per project)
- After major refactors that make existing archaeology notes stale
- When a new team member or a fresh Claude session needs instant context

**How often:** Once per project. Re-run only after major structural changes.

**What it produces:** 3-10 vault notes in `vault/projects/<project>/` covering architecture, subsystems, signal flow, and test patterns. Also creates `agent/session-log.md` entry.

**Example:**
```
You cloned a new repo and opened Claude Code in it.
The session-start hook says "no project documentation detected."
→ Type /project-archaeology to bootstrap the vault documentation.
```

#### Decision tree

```
Starting on a new codebase?
  → /project-archaeology (once)

Working on a task?
  → Just work. Hooks handle formatting and validation.

Taking a break or switching tasks?
  → /checkpoint

Found a non-obvious insight worth preserving?
  → /obsidian-notes

Created several notes recently?
  → /obsidian-audit

Archaeology notes feel outdated after a big refactor?
  → /project-archaeology again, or /obsidian-notes to update specific notes
```

---

## Server sync

Keeps your local machine and remote lab servers in sync via rsync over SSH.
No git credentials needed on the servers — everything is pushed from your local machine.

### How it works

```
Local Mac ──rsync──▶ server-1
            ──rsync──▶ server-2
```

- `hooks/server-sync.sh` rsyncs the repo to each server, then runs `setup.sh` remotely to set up symlinks
- First run initializes everything (creates dirs, symlinks). Later runs just sync changes.

### First time setup

```bash
# Make sure you can SSH to your servers
ssh user@server.example.edu

# Then sync (handles init automatically)
./hooks/server-sync.sh
```

The script checks on each server:
- Whether `~/llm_agent_config/` exists (copies if not)
- Whether symlinks are set up (runs `setup.sh` if not)
- Whether the vault structure is intact (creates missing dirs if needed)

### Ongoing sync

```bash
./hooks/server-sync.sh              # all servers
./hooks/server-sync.sh <alias>      # specific server only
```

Server list is defined at the top of `hooks/server-sync.sh` — edit to add/remove servers.

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
