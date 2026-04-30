#!/bin/bash
# Block edits to sensitive/credential files in psylab_comm.
# Runs on PreToolUse for Edit|Write.
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

PROTECTED=(".env" "spacetrack_config.json" "credentials" ".secret" "id_rsa")
for pattern in "${PROTECTED[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    echo "BLOCKED: $FILE_PATH is a protected/sensitive file. Cannot edit." >&2
    exit 2
  fi
done
exit 0
