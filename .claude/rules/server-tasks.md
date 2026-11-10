# Server task submission

Before sending ANY task to a remote server (ssh, rsync, tmux, remote build or run), invoke the `server-tasks` skill and follow it. It holds the full procedure: sync-hook discovery, worktree server directories, parallelism policy, minimum working example before a full run, and Monitor-based waiting.

Hard rules that apply even before the skill is loaded:
- RPI (`143.215.153.94`, user `jpark3066`): single worker only. No `ProcessPoolExecutor`, no multiprocessing pools, no `--workers` above 1.
- Unlisted servers: single worker until their capacity is confirmed.
- Never delete server files without the user's explicit permission.
- Files reach servers only through the project's rsync sync hook. Servers never run git.
