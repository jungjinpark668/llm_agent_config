#!/bin/bash
# setup.sh — Symlink Claude Code configuration from this repo to ~/.claude/

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKUP_SUFFIX=".orig.$(date +%Y%m%d_%H%M%S)"
TARGET_DIR="$HOME/.claude"

echo "===> Setting up Claude Code config..."
mkdir -p "$TARGET_DIR"

ITEMS=("settings.json" "CLAUDE.md" "rules" "skills")

for item in "${ITEMS[@]}"; do
    src="$REPO_DIR/.claude/$item"
    dest="$TARGET_DIR/$item"

    [ ! -e "$src" ] && continue

    if [ -L "$dest" ]; then
        LINK_TARGET=$(readlink "$dest")
        if [ "$LINK_TARGET" = "$src" ]; then
            echo "  [Skipping] $item (already linked)"
            continue
        fi
    fi

    if [ -e "$dest" ]; then
        echo "  [Backup] Moving existing $item to $item$BACKUP_SUFFIX"
        mv "$dest" "$dest$BACKUP_SUFFIX"
    fi

    ln -s "$src" "$dest"
    echo "  [Linked] $item → $src"
done

echo ""
echo "Done! Configuration links established."
echo ""
echo "Next: Initialize the vault (if not already done):"
echo "  ./init-vault.sh"
