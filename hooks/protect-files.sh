#!/bin/bash
# Block edits to sensitive/credential files in psylab_comm.
# Runs on PreToolUse for Edit|Write|NotebookEdit and MCP filesystem write tools.
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Block every agent write to the user's golden notes: vault/projects/<project>/my-note/.
# Checks all path fields used by Edit/Write/NotebookEdit and MCP filesystem tools.
while IFS= read -r p; do
  if [[ "$p" == *vault/projects/*/my-note || "$p" == *vault/projects/*/my-note/* ]]; then
    echo "BLOCKED: $p is inside a my-note/ folder (the user's golden notes). Agents never write there; read it only." >&2
    exit 2
  fi
done < <(echo "$INPUT" | jq -r '.tool_input | (.file_path, .notebook_path, .path, .source, .destination) // empty')

PROTECTED=(".env" "spacetrack_config.json" "credentials" ".secret" "id_rsa")
for pattern in "${PROTECTED[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    echo "BLOCKED: $FILE_PATH is a protected/sensitive file. Cannot edit." >&2
    exit 2
  fi
done
exit 0
