#!/bin/bash
# sync-codex.sh — Regenerate the Codex copies from the Claude sources.
# The Claude files are the single source of truth; never edit the Codex copies by hand.
#   .claude/CLAUDE.md           -> .codex/AGENTS.md and AGENTS.md
#   .claude/skills/<name>/      -> .agents/skills/<name>/   (synced/ is left alone)
# Word swap only: "Claude" -> "Codex" (keeps "Claude Code"), bare "CLAUDE.md" -> "AGENTS.md".
# Paths are kept (~/.claude/..., .claude/CLAUDE.md), because those files really live there.
set -euo pipefail
REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$REPO_DIR"

swap() {
    sed -e 's/Claude Code/@@CLAUDE_CODE@@/g' \
        -e 's/^CLAUDE\.md/AGENTS.md/' \
        -e 's/\([^/]\)CLAUDE\.md/\1AGENTS.md/g' \
        -e 's/Claude/Codex/g' \
        -e 's/@@CLAUDE_CODE@@/Claude Code/g'
}

swap < .claude/CLAUDE.md > .codex/AGENTS.md
cp .codex/AGENTS.md AGENTS.md
echo "  [Generated] .codex/AGENTS.md, AGENTS.md"

for src in .claude/skills/*/; do
    name=$(basename "$src")
    [ "$name" = "synced" ] && continue
    [ -f "$src/SKILL.md" ] || continue
    (cd "$src" && find . -type f) | while IFS= read -r f; do
        dst=".agents/skills/$name/${f#./}"
        mkdir -p "$(dirname "$dst")"
        case "$f" in
            *.md) swap < "$src/$f" > "$dst" ;;
            *)    cp "$src/$f" "$dst" ;;
        esac
    done
    echo "  [Generated] .agents/skills/$name"
done
