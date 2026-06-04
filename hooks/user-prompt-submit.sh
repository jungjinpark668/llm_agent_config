#!/bin/bash
# Claude Code UserPromptSubmit hook: when the prompt contains a keyword listed
# in the current project's context-map.md, surface the mapped notes as pointers.
# Pointer-only by design — main context stays clean; load via subagent if needed.
INPUT=$(cat)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(dirname "$SCRIPT_DIR")/vault"
source "$SCRIPT_DIR/lib/detect-project.sh"

# Working dir from the hook payload (fall back to $PWD).
CWD=$(echo "$INPUT" | python3 -c "
import sys, json
try: print(json.load(sys.stdin).get('cwd','') or '')
except: print('')
" 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"

PROJECT=$(detect_project "$CWD" "$VAULT")
[ -z "$PROJECT" ] && exit 0

MANIFEST="$VAULT/projects/$PROJECT/context-map.md"
[ -f "$MANIFEST" ] || exit 0

# Match prompt against the "## keywords" rules (case-insensitive, min 4 chars).
MATCHED=$(echo "$INPUT" | MANIFEST="$MANIFEST" python3 -c "
import sys, json, os

try:
    prompt = (json.load(sys.stdin).get('prompt') or '').lower()
except Exception:
    prompt = ''

notes = {}          # note -> set of matched keywords
section = None
with open(os.environ['MANIFEST']) as f:
    for line in f:
        s = line.strip()
        if s.startswith('## '):
            section = s[3:].strip().lower()
            continue
        if section != 'keywords' or not s.startswith('-') or '->' not in s:
            continue
        kw_part, note_part = s.lstrip('- ').split('->', 1)
        hits = [k.strip().lower() for k in kw_part.split(',')
                if len(k.strip()) >= 4 and k.strip().lower() in prompt]
        if not hits:
            continue
        for note in (n.strip() for n in note_part.split(',') if n.strip()):
            notes.setdefault(note, set()).update(hits)

for note, kws in notes.items():
    print(note + '\t' + ', '.join(sorted(kws)))
" 2>/dev/null)

[ -z "$MATCHED" ] && exit 0

echo "[vault] Prompt keywords matched project notes ($PROJECT):"
while IFS=$'\t' read -r NOTE KWS; do
    [ -z "$NOTE" ] && continue
    echo "- $VAULT/projects/$PROJECT/$NOTE (matched: $KWS)"
done <<< "$MATCHED"
echo "Load via an Explore subagent only if the current task needs it; do not bulk-read into main context."
exit 0
