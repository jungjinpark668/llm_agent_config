---
date: 2026-06-04
tags: [vault-infra, hooks, concurrency]
type: concept
status: active
---

# Vault concurrency and the hook workflow

Audit of what happens when two Claude Code sessions run in different projects at
the same time, and which shared writes can collide. The cron sync that pushes to
the lab servers is the same one described in [[server-infrastructure]].

## Project detection is safe

Every hook resolves the project from the working directory, not from shared
state. `hooks/lib/detect-project.sh` maps the CWD basename to a lowercase-hyphenated
name and matches it against `vault/projects/`, with a keyword fallback on the path.
This is stateless and per-process, so two sessions in two different project dirs
each detect their own project with no cross-talk. `session-start.sh` and
`user-prompt-submit.sh` both source this one helper.

## Shared-write races (fixed)

| Site | Risk | Fix |
|------|------|-----|
| `pre-compact.sh` → `agent/pre-compact-snapshot.md` | Global file, non-atomic read→trim→write. Two concurrent compactions lose one snapshot. | mkdir-lock + temp-file then atomic `mv`. |
| `update-timeline.sh` → `projects/<p>/timeline.md` | Two sessions in the **same** project duplicate the `## DATE` header or interleave lines (check-then-append + several `echo >>`). | mkdir-lock + single atomic append of the whole block; header guard inside the lock. |
| `server-sync.sh` (cron, every 5 min) | A slow run overlaps the next and they collide on `.git/index.lock`. | Non-blocking mkdir-lock at the top; second run logs "skipping" and exits. |
| `~/.claude/.session-topic` | Global single slot; one session's checkpoint overwrites another's, and session end deletes it for everyone. | Namespaced per `$CLAUDE_CODE_SESSION_ID` in both the checkpoint skill and `session-stop.sh`. |

Locking uses `mkdir` (atomic), not `flock` — macOS does not ship `flock`. Stale
locks older than 30s are stolen. See `hooks/lib/locking.sh`.

## Accepted / not machine-fixed

- `agent/session-log.md` is appended by Claude directly (no hook writes it), so
  concurrent appends are model-driven and rare. Left as-is.
- The cron commits the whole repo (`git add -A`) regardless of which session made a
  change, and can stamp a half-written file. Low frequency, accepted.

## Open issue — projects are not versioned

`.gitignore` line `**/projects/` ignores `vault/projects/`, so **no project note is
committed by the auto-commit cron** — they live only on local disk and are rsynced
to servers (rsync ignores `.gitignore`). This contradicts "the vault is committed
memory." Narrowing the pattern (ignore Claude's session-projects path only) would
version the notes. Needs a decision before changing, since the broad pattern may be
intentional.
