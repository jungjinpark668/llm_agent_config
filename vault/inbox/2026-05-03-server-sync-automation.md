---
date: 2026-05-03
tags: [psylab-comm, infrastructure, server]
type: concept
status: backlog
project: psylab-comm
---

# Server sync automation

## Current state
`scripts/beamforming/lms_tracking/adaptive_ctrl/sync_server.sh` manually syncs source files to `jpark3066@sathe-srv1.ece.gatech.edu:~/psylab/psylab_comm/` via rsync, then launches scripts in tmux.

## What to automate
psylab_comm needs its own standalone sync automation (independent of llm_agent_config):

- Watch for local file changes (src/, scripts/, tests/) and rsync to server
- Or use fswatch/launchd on macOS to trigger rsync on save
- Could live as a top-level `tools/sync/` or `scripts/server/` in psylab_comm
- `venv_setup` and `venv_activate` are server-side commands for Python env management
- Cache and figures stay on server, pulled back on demand

## Key constraints
- Git is local only (no remote push for sync — rsync handles deployment)
- Never sync: venv, cache/, figures/, .git/, __pycache__/
- Server venv uses `venv_setup` (create) and `venv_activate` (activate)
- Tmux sessions survive SSH disconnect
- This is a psylab_comm project tool, NOT part of llm_agent_config

## Reference
- `scripts/beamforming/lms_tracking/adaptive_ctrl/sync_server.sh` (current manual approach, script-specific)
- Goal: generalize to project-level so any script dir can deploy + run on server

[[working-context]]
