#!/bin/bash
# Block edits to sensitive/credential files in psylab_comm.
# Runs on PreToolUse for Edit|Write|NotebookEdit and MCP filesystem write tools.
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

PROTECTED=(".env" "spacetrack_config.json" "credentials" ".secret" "id_rsa")
for pattern in "${PROTECTED[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    echo "BLOCKED: $FILE_PATH is a protected/sensitive file. Cannot edit." >&2
    exit 2
  fi
done

# The user's golden notes (vault/projects/<project>/my-note/) are written only on the
# user's explicit request, so every write there asks the user to confirm.
# Checks all path fields used by Edit/Write/NotebookEdit and MCP filesystem tools.
while IFS= read -r p; do
  if [[ "$p" == *vault/projects/*/my-note || "$p" == *vault/projects/*/my-note/* ]]; then
    jq -n --arg r "my-note write: $p. Approve only if you explicitly asked for this write." \
      '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
    exit 0
  fi
done < <(echo "$INPUT" | jq -r '.tool_input | (.file_path, .notebook_path, .path, .source, .destination) // empty')
exit 0
