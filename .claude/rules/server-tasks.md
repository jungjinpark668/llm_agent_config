# Server task submission

Default behaviors when sending tasks to remote servers. These trigger
automatically, in order, whenever Claude executes code on a server.

File transport is rsync-based. Git is local only; servers never run git.

---

## 1. Sync hook discovery (prerequisite)

**When:** Claude is about to send any task to a remote server.

**Rule:** Before doing anything remote, find the project's sync hook. Search
for `hooks/server-sync.sh` or similar (`*sync*.sh`, `*server*.sh`) in the
project root, `hooks/`, or `scripts/`.

- **Found:** Read the script into context. Extract server aliases, hostnames,
  remote paths, venv activation, SSH options, and rsync excludes. Use these
  values for all subsequent server commands instead of guessing.
- **Not found:** Ask the user how they handle file sync between local and
  server. Do not assume any sync mechanism exists. Do not proceed until this
  is resolved.

Always run the sync hook before remote execution to push latest code.

---

## 2. Worktree handling

**When:** Sync hook was found and Claude is about to sync or execute remotely.

**Detection:**
```bash
TOPLEVEL=$(git rev-parse --show-toplevel)
COMMON=$(git rev-parse --git-common-dir)
# If COMMON != TOPLEVEL/.git, Claude is in a worktree
```

**Main repo:** Use the sync hook as-is. No changes.

**Worktree:** Create a separate server directory to avoid overwriting main's
files. Use the sync hook's `REMOTE_DIR_OVERRIDE` env var instead of
replicating rsync logic.

- Naming: `<original_dir_name>_wt_<branch_name>`
  (e.g., `psylab_comm_wt_feature-alpha`)
- Create directory and symlink venv on server:
  ```bash
  ssh <server> "mkdir -p ~/<parent>/<wt_dir_name>"
  ssh <server> "ln -sfn ~/<REMOTE_DIR>/venv ~/<parent>/<wt_dir_name>/venv"
  ```
- Sync via the hook with override (single source of rsync logic):
  ```bash
  REMOTE_DIR_OVERRIDE="<parent>/<wt_dir_name>" ./hooks/server-sync.sh <server>
  ```
- All tmux sessions and log paths use the worktree directory, not the
  main one.

**Sync hook merge policy:**
- The sync hook must accept `REMOTE_DIR_OVERRIDE` env var. The line should
  read: `REMOTE_DIR="${REMOTE_DIR_OVERRIDE:-psylab/psylab_comm}"`.
- If the hook is missing this override, add it before first worktree sync.
  This is a one-line backward-compatible change (default path unchanged,
  cron unaffected).
- Worktree branches should NOT modify the hook's default `REMOTE_DIR` or
  other hardcoded values. Only the env var controls the target directory.
- On merge, the hook should have no conflicts since worktree branches
  never change it.

**Cleanup after merge:**
- When a worktree is resolved/merged locally, ask the user before deleting
  the server-side copy. **Never delete server files without explicit
  permission.**
- Prompt: "Worktree `<branch>` has been merged. Delete the server copy at
  `~/<parent>/<wt_dir_name>` on `<server>`?"
- Only after user confirms:
  ```bash
  ssh <server> "rm -rf ~/<parent>/<wt_dir_name>"
  ```

---

## 3. Validate before full run

**When:** Claude is about to launch a full parallel worker sweep
(ProcessPoolExecutor, multi-worker run, or equivalent).

**Rule:** Execute a minimum working example first. The test must finish
within 3 minutes. It only checks that the code imports, initializes, and
runs one iteration without crashing. Not a full test suite.

How to build the MWE:
- Single worker (`--workers 1` or equivalent)
- Single case / smallest grid point (one parameter combination)
- Minimal sample count (e.g., 1 time point, 1 pilot, fewest iterations)
- If the project has a `test` command (e.g., `sync_server.sh test`), use it
  only if it runs under 3 minutes. Otherwise, construct a shorter invocation.

Verify clean exit:
- No `Traceback` in output
- No `Error` (other than expected log lines)
- Exit code 0

**Pass:** Proceed to the full parallel run.
**Fail:** Stop. Report the error to the user. Do NOT launch the full run.

---

## 4. Background monitoring (always on)

**When:** Claude sends any command to a remote server (SSH, tmux launch, sync
script run or test).

**Rule:** Use the Monitor tool with an `until` SSH loop that polls for task
completion. The loop exits when the tmux session ends or a completion/error
marker appears in the log.

```bash
until ssh <server> "! tmux has-session -t <session> 2>/dev/null || \
  grep -qE 'DONE|Error|Traceback' <logfile> 2>/dev/null"; do
  sleep <interval>
done
```

**Intervals:**
- Test/validation runs: 30s
- Full sweeps: 60-120s (match expected duration)

**After the loop exits:** Read the tail of the remote log via SSH and report
results to the user. If the task failed, include the traceback.
