#!/bin/bash
# Claude Code SessionStart hook: minimal bootstrap
# Agent loads deeper context via subagent when needed
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(dirname "$SCRIPT_DIR")/vault"
CWD="$PWD"

# --- Detect matching project by CWD name mapping ---
REPO_NAME=$(basename "$CWD")
MAPPED_NAME=$(echo "$REPO_NAME" | sed -e 's/ /-/g' -e 's/_/-/g' | tr '[:upper:]' '[:lower:]' | sed -e 's/--/-/g')
MATCHED_PROJECT=""

if [ -d "$VAULT/projects/$MAPPED_NAME" ]; then
    MATCHED_PROJECT="$MAPPED_NAME"
else
    for PROJECT_DIR in "$VAULT/projects"/*/; do
        [ -d "$PROJECT_DIR" ] || continue
        PROJECT_NAME=$(basename "$PROJECT_DIR")
        IFS='-' read -ra KEYWORDS <<< "$PROJECT_NAME"
        for KEYWORD in "${KEYWORDS[@]}"; do
            [ ${#KEYWORD} -lt 4 ] && continue
            if echo "$CWD" | grep -qi "$KEYWORD"; then
                MATCHED_PROJECT="$PROJECT_NAME"
                break 2
            fi
        done
    done
fi

# --- List checkpoint headers (one line each) ---
CHECKPOINT_LINES=""
for CTX in "$VAULT"/projects/*/working-context.md; do
    [ -f "$CTX" ] || continue
    PROJ=$(basename "$(dirname "$CTX")")
    while IFS= read -r line; do
        CLEAN=$(echo "$line" | sed 's/^## Checkpoint[ ]*[-—]*[ ]*//')
        CHECKPOINT_LINES+="  $PROJ: $CLEAN"$'\n'
    done < <(grep "^## Checkpoint" "$CTX" 2>/dev/null)
done

# --- Check code-context freshness ---
CODE_CTX_STATUS=""
if [ -n "$MATCHED_PROJECT" ]; then
    CODE_CTX="$VAULT/projects/$MATCHED_PROJECT/code-context.md"
    if [ -f "$CODE_CTX" ]; then
        CTX_DATE=$(grep "^date:" "$CODE_CTX" 2>/dev/null | head -1 | sed 's/date: //')
        CODE_CTX_STATUS="Code context: $CODE_CTX (dated ${CTX_DATE:-unknown})"
    else
        CODE_CTX_STATUS="Code context: not found — generate on first coding task"
    fi
fi

# --- Check if vault audit is overdue (>7 days) ---
AUDIT_REMINDER=""
AUDIT_MARKER="$VAULT/.last-audit"
if [ -f "$AUDIT_MARKER" ]; then
    LAST_AUDIT=$(cat "$AUDIT_MARKER")
    LAST_EPOCH=$(date -j -f "%Y-%m-%d" "$LAST_AUDIT" "+%s" 2>/dev/null || echo 0)
    NOW_EPOCH=$(date "+%s")
    DAYS_SINCE=$(( (NOW_EPOCH - LAST_EPOCH) / 86400 ))
    if [ "$DAYS_SINCE" -ge 7 ]; then
        AUDIT_REMINDER="VAULT AUDIT OVERDUE: Last audit was $DAYS_SINCE days ago ($LAST_AUDIT). Run /obsidian-audit."
    fi
else
    AUDIT_REMINDER="VAULT AUDIT: No audit on record. Run /obsidian-audit to check vault health."
fi

# --- Output (~8 lines) ---
echo "Vault: $VAULT"
if [ -n "$MATCHED_PROJECT" ]; then
    echo "Project documentation detected: $VAULT/projects/$MATCHED_PROJECT"
    echo "CWD project: $MATCHED_PROJECT"
fi
[ -n "$CODE_CTX_STATUS" ] && echo "$CODE_CTX_STATUS"
if [ -n "$CHECKPOINT_LINES" ]; then
    echo "Checkpoints:"
    echo -n "$CHECKPOINT_LINES"
fi
[ -n "$AUDIT_REMINDER" ] && echo "$AUDIT_REMINDER"
echo "Load vault context via subagent or obsidian-notes skill when starting project work."
