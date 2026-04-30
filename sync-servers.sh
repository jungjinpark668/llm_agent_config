#!/bin/bash
# Convenience wrapper — everything lives in hooks/server-sync.sh now
exec "$(dirname "$0")/hooks/server-sync.sh" "$@"
