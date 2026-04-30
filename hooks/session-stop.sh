#!/bin/bash
# Claude Code SessionEnd hook: remind about session log and pattern extraction
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(dirname "$SCRIPT_DIR")/vault"
SESSION_LOG="$VAULT/agent/session-log.md"

# Clean up session tag
rm -f "$HOME/.claude/.session-topic"

# Check if session log was updated today
TODAY=$(date +%Y-%m-%d)
if [ -f "$SESSION_LOG" ]; then
    if ! grep -q "## $TODAY" "$SESSION_LOG"; then
        echo "SESSION LOG REMINDER: If this was a meaningful session, consider appending to $VAULT/agent/session-log.md with: what worked, what failed, key decisions, and connections made."
    fi
fi

echo "PATTERN CHECK: Did this session reveal any reusable pattern worth adding to $VAULT/agent/instincts.yaml?"
