#!/bin/bash
# PostToolUse hook: remind about ISSCC figure style when matplotlib code is written/edited.
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only check .py files
[[ "$FILE_PATH" == *.py ]] || exit 0

# Only check if file exists and contains matplotlib
[ -f "$FILE_PATH" ] || exit 0
grep -qE 'import matplotlib|from matplotlib|import pyplot|from pyplot' "$FILE_PATH" || exit 0

# Check if apply_isscc_style is already present
if grep -q 'apply_isscc_style' "$FILE_PATH"; then
    if ! grep -qE 'CLR_NAVY|#1a1f7a' "$FILE_PATH"; then
        echo "ISSCC FIGURE CHECK: apply_isscc_style found but ISSCC color palette is missing. See .claude/isscc-figure/SKILL.md."
    fi
    exit 0
fi

echo "ISSCC FIGURE REMINDER: This file contains matplotlib code without ISSCC style. Apply apply_isscc_style(ax), use ISSCC colors (CLR_NAVY, CLR_RED, CLR_GREEN, CLR_PURPLE), and triple-save PNG+SVG+EPS. Full spec: .claude/isscc-figure/SKILL.md"
