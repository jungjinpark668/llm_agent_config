#!/bin/bash
# server-sync.sh — Auto-sync llm_agent_config: git push to GitHub + rsync to lab servers
# Runs via cron every 5 minutes. Also callable manually.
#
# Usage (manual):
#   ./hooks/server-sync.sh              # git + all servers
#   ./hooks/server-sync.sh sathesrv1    # git + sathesrv1 only
#   ./hooks/server-sync.sh git          # git only, skip servers

set -euo pipefail

# ── Server config (edit here to add/remove servers) ──
SERVERS=(
    "sathesrv1:sathe-srv1"
    "sathesrv2:sathe-srv2"
)
SYNC_USER="jpark3066"
DOMAIN="ece.gatech.edu"

SSH_OPTS="-o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$SCRIPT_DIR/sync.log"
REMOTE_DIR="llm_agent_config"

log() { echo "$(date '+%Y-%m-%d %H:%M'): $*" >> "$LOG_FILE"; }

# ── Log rotation (keep last 500 lines) ──
if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt 1000 ]; then
    tail -500 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

# ── Parse arguments ──
SKIP_SERVERS=0
TARGETS=()
if [ "${1:-}" = "git" ]; then
    SKIP_SERVERS=1
elif [ -n "${1:-}" ]; then
    FOUND=0
    for ENTRY in "${SERVERS[@]}"; do
        ALIAS="${ENTRY%%:*}"
        if [ "$ALIAS" = "$1" ]; then
            TARGETS=("$ENTRY")
            FOUND=1
            break
        fi
    done
    if [ "$FOUND" = "0" ]; then
        echo "Unknown target: $1"
        echo "Available: git $(for E in "${SERVERS[@]}"; do echo -n "${E%%:*} "; done)"
        exit 1
    fi
else
    TARGETS=("${SERVERS[@]}")
fi

cd "$REPO_DIR"

# ── Step 1: Git commit + push to GitHub ──
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null || [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
    git add -A
    git commit -m "auto: $(date '+%Y-%m-%d %H:%M')" --quiet
    log "Committed local changes"
fi

if ! git push origin main --quiet 2>/dev/null; then
    # Pull first if push fails (remote has new commits)
    if git pull --rebase origin main --quiet 2>/dev/null; then
        git push origin main --quiet 2>/dev/null || log "PUSH FAILED after pull"
    else
        git rebase --abort 2>/dev/null
        if git pull origin main --no-rebase -X ours --no-edit --quiet 2>/dev/null; then
            git push origin main --quiet 2>/dev/null || log "PUSH FAILED after merge"
        else
            log "GIT SYNC FAILED — manual intervention needed"
        fi
    fi
fi

log "Git sync done"

# ── Step 2: Rsync to lab servers ──
[ "$SKIP_SERVERS" = "1" ] && { log "Skipping servers (git-only mode)"; exit 0; }

for ENTRY in "${TARGETS[@]}"; do
    ALIAS="${ENTRY%%:*}"
    HOSTNAME="${ENTRY#*:}"
    HOST="${SYNC_USER}@${HOSTNAME}.${DOMAIN}"

    # Quick SSH check — skip if unreachable (BatchMode=yes won't hang on prompts)
    if ! ssh $SSH_OPTS "$HOST" true 2>/dev/null; then
        log "${ALIAS}: unreachable, skipping"
        continue
    fi

    # Rsync files
    if rsync -az --delete \
        --exclude='.git/' \
        --exclude='.DS_Store' \
        --exclude='hooks/sync.log' \
        --exclude='.claude/settings.local.json' \
        --exclude='vault/.obsidian/workspace' \
        --exclude='vault/.obsidian/workspace.json' \
        --exclude='vault/.obsidian/cache/' \
        -e "ssh ${SSH_OPTS}" \
        "${REPO_DIR}/" "${HOST}:~/${REMOTE_DIR}/" 2>/dev/null; then

        # Remote setup check (only if needed)
        ssh $SSH_OPTS "$HOST" bash -s <<'REMOTE' 2>/dev/null
REPO_DIR="$HOME/llm_agent_config"
VAULT="$REPO_DIR/vault"
CLAUDE_DIR="$HOME/.claude"

# Create missing vault dirs
for DIR in inbox projects areas library personal agent; do
    [ ! -d "$VAULT/$DIR" ] && mkdir -p "$VAULT/$DIR"
done

# Check symlinks — only run setup if broken
mkdir -p "$CLAUDE_DIR"
NEEDS_SETUP=0
for ITEM in settings.json CLAUDE.md rules skills; do
    SRC="$REPO_DIR/.claude/$ITEM"
    DEST="$CLAUDE_DIR/$ITEM"
    [ ! -e "$SRC" ] && continue
    if [ ! -L "$DEST" ] || [ "$(readlink "$DEST")" != "$SRC" ]; then
        NEEDS_SETUP=1
        break
    fi
done
if [ "$NEEDS_SETUP" = "1" ]; then
    chmod +x "$REPO_DIR/setup.sh" 2>/dev/null
    cd "$REPO_DIR" && ./setup.sh
fi

chmod +x "$REPO_DIR"/hooks/*.sh "$REPO_DIR"/*.sh 2>/dev/null
REMOTE

        log "${ALIAS}: synced"
    else
        log "${ALIAS}: rsync failed"
    fi
done

log "Sync complete"
