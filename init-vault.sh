#!/bin/bash
# init-vault.sh — Initialize the Obsidian vault directory structure inside this repo

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VAULT="$SCRIPT_DIR/vault"

if [ -d "$VAULT" ] && [ "$(ls -A "$VAULT" 2>/dev/null)" ]; then
    echo "Error: $VAULT already exists and is not empty."
    echo "Move or delete it if you want to initialize a fresh vault."
    exit 1
fi

echo "Initializing Obsidian vault at $VAULT..."

mkdir -p "$VAULT/.obsidian"
mkdir -p "$VAULT/inbox"
mkdir -p "$VAULT/projects"
mkdir -p "$VAULT/areas"
mkdir -p "$VAULT/library"
mkdir -p "$VAULT/personal"
mkdir -p "$VAULT/agent"

cat > "$VAULT/README.md" <<'EOF'
# Obsidian Notes

Agent-managed Obsidian vault for persistent memory across Claude Code sessions.

## Structure
- `inbox/` — Quick capture, unprocessed thoughts
- `projects/` — Active, time-bound work
- `areas/` — Durable domain knowledge
- `library/` — Atomic reference notes, papers, tools
- `personal/` — Goals, journal, personal context
- `agent/` — Agent meta-layer (session log, connections, open questions)
EOF

cat > "$VAULT/.gitignore" <<'EOF'
.obsidian/workspace
.obsidian/workspace.json
.obsidian/cache/
*.tmp
EOF

echo ""
echo "Vault initialized at $VAULT"
echo ""
echo "The vault is part of this repo — no separate git init needed."
echo "Open $VAULT in Obsidian to start using it."
