#!/bin/bash
# Resolve the vault project name for a working directory.
# Single source of truth for CWD -> project mapping, shared by
# session-start.sh and user-prompt-submit.sh.
#
# Usage:
#   source "$SCRIPT_DIR/lib/detect-project.sh"
#   PROJECT=$(detect_project "$CWD" "$VAULT")   # echoes "" if no match
detect_project() {
    local cwd="$1"
    local vault="$2"
    local repo_name mapped matched=""
    repo_name=$(basename "$cwd")
    mapped=$(echo "$repo_name" | sed -e 's/ /-/g' -e 's/_/-/g' | tr '[:upper:]' '[:lower:]' | sed -e 's/--/-/g')

    if [ -d "$vault/projects/$mapped" ]; then
        matched="$mapped"
    else
        local project_dir project_name keyword
        for project_dir in "$vault/projects"/*/; do
            [ -d "$project_dir" ] || continue
            project_name=$(basename "$project_dir")
            local keywords
            IFS='-' read -ra keywords <<< "$project_name"
            for keyword in "${keywords[@]}"; do
                [ ${#keyword} -lt 4 ] && continue
                if echo "$cwd" | grep -qi "$keyword"; then
                    matched="$project_name"
                    break 2
                fi
            done
        done
    fi
    echo "$matched"
}
