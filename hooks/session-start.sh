#!/bin/bash
# Claude Code SessionStart hook: minimal bootstrap
# Agent loads deeper context via subagent when needed
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(dirname "$SCRIPT_DIR")/vault"
CWD="$PWD"

# --- Detect matching project by CWD name mapping ---
source "$SCRIPT_DIR/lib/detect-project.sh"
MATCHED_PROJECT=$(detect_project "$CWD" "$VAULT")

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

# --- Collect per-project default notes (manifest "## always" list) ---
# These are injected in full so the session always starts with baseline context.
DEFAULT_NOTES=""
if [ -n "$MATCHED_PROJECT" ]; then
    MANIFEST="$VAULT/projects/$MATCHED_PROJECT/context-map.md"
    if [ -f "$MANIFEST" ]; then
        while IFS= read -r NOTE; do
            [ -z "$NOTE" ] && continue
            NOTE_PATH="$VAULT/projects/$MATCHED_PROJECT/$NOTE"
            [ -f "$NOTE_PATH" ] || continue
            BODY=$(awk 'NR==1 && $0=="---"{fm=1; next} fm==1 && $0=="---"{fm=0; next} fm!=1{print}' "$NOTE_PATH")
            DEFAULT_NOTES+="--- $NOTE ---"$'\n'"$BODY"$'\n\n'
        done < <(awk '
            /^##[[:space:]]+always[[:space:]]*$/ {grab=1; next}
            /^##[[:space:]]/ {grab=0}
            grab && /^-[[:space:]]/ {sub(/^-[[:space:]]*/,""); print}
        ' "$MANIFEST")
    fi
fi

# --- Output (~8 lines + any default notes) ---
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
if [ -n "$DEFAULT_NOTES" ]; then
    echo ""
    echo "=== Default project context (auto-loaded from context-map.md) ==="
    echo -n "$DEFAULT_NOTES"
fi
