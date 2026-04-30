#!/bin/bash
# Cron sync: auto-commit and push vault changes every 5 minutes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
cd "$REPO_DIR" || exit 1

LOG_FILE="$SCRIPT_DIR/sync.log"

# Step 1: Commit local changes
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    git add -A
    git commit -m "auto: $(date '+%Y-%m-%d %H:%M')"
fi

# Step 2: Pull remote changes (rebase first, fallback to merge)
if ! git pull --rebase origin main 2>&1; then
    echo "$(date '+%Y-%m-%d %H:%M'): PULL FAILED with rebase. Trying merge..." >> "$LOG_FILE"
    git rebase --abort 2>/dev/null
    if ! git pull origin main --no-rebase -X ours --no-edit 2>&1; then
        echo "$(date '+%Y-%m-%d %H:%M'): MERGE FAILED. Manual intervention required." >> "$LOG_FILE"
        exit 1
    fi
fi

# Step 3: Push
git push origin main 2>&1 || {
    echo "$(date '+%Y-%m-%d %H:%M'): PUSH FAILED" >> "$LOG_FILE"
    exit 1
}

echo "$(date '+%Y-%m-%d %H:%M'): Sync successful" >> "$LOG_FILE"
