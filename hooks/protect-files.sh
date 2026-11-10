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

# Codex apply_patch puts the patch text in tool_input.command, and Codex cannot show an
# "ask" prompt (it runs the call anyway), so Codex writes into any my-note/ are blocked.
if [[ "$(echo "$INPUT" | jq -r '.tool_name // empty')" == "apply_patch" ]] &&
   echo "$INPUT" | jq -r '.tool_input.command // empty' | grep -qE '^\*\*\* (Add File|Update File|Delete File|Move to): (.*/)?my-note/'; then
  echo "BLOCKED: Codex cannot ask for confirmation, so it never writes my-note/ (the user's golden notes). Ask the user to write it by hand or in Claude Code." >&2
  exit 2
fi

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
