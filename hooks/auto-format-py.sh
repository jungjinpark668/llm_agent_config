#!/bin/bash
# Auto-format Python files after Edit/Write using ruff.
# Runs on PostToolUse for Edit|Write.
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ "$FILE_PATH" == *.py ]]; then
  ruff format "$FILE_PATH" 2>/dev/null
  ruff check --fix "$FILE_PATH" 2>/dev/null
fi
exit 0
