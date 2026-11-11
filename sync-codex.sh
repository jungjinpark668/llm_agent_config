#!/bin/bash
# sync-codex.sh — Regenerate the Codex copies from the Claude sources.
# The Claude files are the single source of truth; never edit the Codex copies by hand.
#   .claude/CLAUDE.md           -> .codex/AGENTS.md and AGENTS.md
#   .claude/skills/<name>/      -> .agents/skills/<name>/   (synced/ is left alone)
#   .claude/agents/<name>.md    -> .codex/agents/<name>.toml (name, description, developer_instructions)
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

# Agents: the frontmatter gives name and description, the markdown body becomes
# developer_instructions. tools: and model: are Claude Code fields and are dropped.
mkdir -p .codex/agents
for src in .claude/agents/*.md; do
    name=$(basename "$src" .md)
    python3 - "$name" <(swap < "$src") > ".codex/agents/$name.toml" <<'PY'
import json
import sys

name, path = sys.argv[1], sys.argv[2]
_, front, body = open(path).read().split("---\n", 2)
fields = dict(line.split(": ", 1) for line in front.splitlines() if ": " in line)
description = fields["description"].strip()
if description.startswith('"'):
    description = json.loads(description)
body = body.strip("\n")
literal_quote = "'" * 3
if literal_quote in body:
    sys.exit(f"{name}: the body holds three single quotes in a row, which a TOML literal string cannot hold")
print(f"name = {json.dumps(fields['name'].strip())}")
print(f"description = {json.dumps(description, ensure_ascii=False)}")
print(f"developer_instructions = {literal_quote}\n{body}{literal_quote}")
PY
    echo "  [Generated] .codex/agents/$name.toml"
done
