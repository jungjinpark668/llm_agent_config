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

# --- Output (~8 lines) ---
echo "Vault: $VAULT"
if [ -n "$MATCHED_PROJECT" ]; then
    echo "Project documentation detected: $VAULT/projects/$MATCHED_PROJECT"
    echo "CWD project: $MATCHED_PROJECT"
fi
if [ -n "$CHECKPOINT_LINES" ]; then
    echo "Checkpoints:"
    echo -n "$CHECKPOINT_LINES"
fi
echo "Load vault context via subagent or obsidian-notes skill when starting project work."
