#!/bin/bash
# weekly-audit.sh — Weekly vault audit + golden-note sync, run on this Mac.
#
# Started every day at 10:00 by the launchd agent in hooks/weekly-audit.plist.
# It runs the audit only when vault/.last-audit is 7 or more days old, so a day
# when the Mac is off, or the Claude Code login has expired, only delays it.
# A launchd agent is used because a cron job cannot read the Claude Code login
# (tested 2026-11-10: cron gave "Not logged in", a launchd agent worked).
#
# Usage (manual):
#   ./hooks/weekly-audit.sh           # run if the last audit is 7+ days old
#   ./hooks/weekly-audit.sh --force   # run now
#
# What the run may do: Claude Code runs headless in permission mode dontAsk.
# It can edit files in vault/ (allow rule in .claude/settings.json), it cannot
# write my-note/ (ask rule, refused in this mode), and its shell commands are
# limited to read-only ones. This script stamps vault/.last-audit itself.
# Log: hooks/weekly-audit.log. Report: vault/projects/llm-agent-config/.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
VAULT="$REPO_DIR/vault"
LOG_FILE="$SCRIPT_DIR/weekly-audit.log"
TODAY="$(date '+%Y-%m-%d')"
REPORT="$VAULT/projects/llm-agent-config/$TODAY-vault-audit.md"
MAX_USD=6
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

log() { echo "$(date '+%Y-%m-%d %H:%M'): $*" >> "$LOG_FILE"; }
notify() {
    command -v terminal-notifier >/dev/null &&
        terminal-notifier -title "Vault audit" -message "$1" >/dev/null 2>&1
    return 0
}

# ── Run only when the last audit is 7+ days old (same rule as session-start.sh) ──
if [ "${1:-}" != "--force" ] && [ -f "$VAULT/.last-audit" ]; then
    LAST_EPOCH=$(date -j -f "%Y-%m-%d" "$(cat "$VAULT/.last-audit")" "+%s" 2>/dev/null || echo 0)
    if [ $(( ($(date '+%s') - LAST_EPOCH) / 86400 )) -lt 7 ]; then
        exit 0
    fi
fi

# ── State of every my-note folder: one line per file (checksum + path) ──
mynote_state() {
    find "$VAULT/projects" -path '*/my-note/*' -type f -exec shasum {} + 2>/dev/null | sort
}

# my-note/ is not in git, so keep a copy for the time of the run.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/my-note-copy"
BEFORE="$(mynote_state)"
rsync -a --prune-empty-dirs --include='*/' --include='my-note/**' --exclude='*' \
    "$VAULT/projects/" "$WORK/my-note-copy/"

# crontab -l is not a read-only command, so the run cannot call it itself.
CRON_LINE="$(crontab -l 2>/dev/null | grep server-sync || echo "no server-sync line in crontab")"

read -r -d '' PROMPT <<EOF || true
Weekly audit of the Obsidian vault at ~/llm_agent_config/vault. Today is $TODAY.

This is an unattended run on the user's Mac. Nobody can answer questions. Wherever a rule says to ask or confirm with the user, write the question under Action Items in the report and keep going.

Permissions of this run: you can change files only inside ~/llm_agent_config/vault/, and only with the Edit and Write tools. Writes to any my-note/ folder are refused. Shell commands are limited to read-only ones (ls, cat, grep, find, wc, head, tail, git status, git log, git diff). A refused call is expected: do not try another way around it. If it blocked a check, say so in the report.

Steps:
1. Read ~/llm_agent_config/.claude/skills/obsidian-audit/SKILL.md and ~/llm_agent_config/.claude/rules/obsidian-notes.md in full. Follow the skill.
2. Run checks 1-14 on the vault. All 14 checks are report-only: list each problem as an Action Item and do not fix it. For check 1 you cannot run crontab yourself. The wrapper script read it just now: "$CRON_LINE". Read the tail of ~/llm_agent_config/hooks/sync.log and run the git commands of check 1 yourself.
3. Run the skill's Golden-Note Sync section for every folder in vault/projects/. Fix every STALE and WRONG agent note exactly as the skill says: move the old wording to the note's History section with a dated line "YYYY-MM-DD: superseded by my-note/<file>: <one-line reason>", then put the golden fact in the body and cite my-note/<file>. For each project whose my-note folder is missing or holds no .md file, print "NO GOLDEN NOTE: vault/projects/<project>/my-note/ is missing or empty. Golden evaluation skipped." and skip it.
4. Hard limits for the whole run:
   - Never create, edit, move, rename, or delete anything under vault/projects/*/my-note/. Reading it is fine. Those files are the user's golden notes.
   - Never delete or rename any file anywhere.
   - Change nothing outside vault/.
   - Do not run git add, git commit or git push. A separate job syncs the repository.
5. Write the report, using the skill's Report Format, to $REPORT. This folder is not in git, so the report stays on this Mac. Frontmatter:
   ---
   date: $TODAY
   tags: [claude_util, audit]
   type: log
   status: completed
   project: llm-agent-config
   ---
   Write every note name in Action Items and in Fixes as a wikilink: [[note-file-name-without-.md]]. If an earlier *-vault-audit.md exists in the same folder, add the line "Previous audit: [[<that file name without .md>]]".
6. Do not write vault/.last-audit. The wrapper script stamps it after you finish.
7. Final message: the score, the Golden-Note Sync table, every warning line, and the report path.
EOF

log "Audit started"
RESULT="$(cd "$REPO_DIR" && LAST_POINT_DIR="$WORK/last-point" "$HOME/.local/bin/claude" -p "$PROMPT" \
    --model sonnet --permission-mode dontAsk --max-budget-usd "$MAX_USD" \
    --no-session-persistence --output-format json 2>>"$LOG_FILE")"
STATUS=$?

IS_ERROR="$(printf '%s' "$RESULT" | jq -r 'if .is_error == false then "false" else "true" end' 2>/dev/null || echo true)"
SUMMARY="$(printf '%s' "$RESULT" | jq -r '"turns=\(.num_turns) cost_usd=\(.total_cost_usd) refused_calls=\(.permission_denials | length)"' 2>/dev/null || echo "no summary")"
printf '%s' "$RESULT" | jq -r '.permission_denials[]? | "refused: \(.tool_name) \(.tool_input | tostring | .[0:200])"' >> "$LOG_FILE" 2>/dev/null

# ── Golden notes must be exactly as before ──
if [ "$BEFORE" != "$(mynote_state)" ]; then
    KEEP="$HOME/.claude/my-note-before-audit-$TODAY"
    cp -R "$WORK/my-note-copy" "$KEEP"
    WARN="MY-NOTE GUARD TRIPPED: files in my-note/ changed during the audit run. Copy of their state before the run: $KEEP"
    log "$WARN"
    [ -f "$REPORT" ] && printf '\n%s\n' "$WARN" >> "$REPORT"
    notify "$WARN"
fi

if [ "$STATUS" -eq 0 ] && [ "$IS_ERROR" = "false" ] && [ -f "$REPORT" ]; then
    echo "$TODAY" > "$VAULT/.last-audit"
    SCORE="$(grep -m1 -o -E 'Score: *[0-9]+ */ *[0-9]+' "$REPORT" || echo "score not found")"
    log "Audit done. $SCORE. $SUMMARY. Report: $REPORT"
    notify "$SCORE. Report: projects/llm-agent-config/$TODAY-vault-audit.md"
else
    HAS_REPORT="missing"
    [ -f "$REPORT" ] && HAS_REPORT="written"
    log "Audit FAILED (exit $STATUS, is_error=$IS_ERROR, report $HAS_REPORT). $SUMMARY. Output: $(printf '%s' "$RESULT" | head -c 300)"
    notify "Audit failed. See hooks/weekly-audit.log"
fi
