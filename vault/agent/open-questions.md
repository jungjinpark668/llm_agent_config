---
date: 2026-06-17
tags: [claude_util]
type: log
status: active
---

# Open questions

Running log of unresolved decisions to revisit when planning. Per CLAUDE.md, check this file when making decisions or planning.

## SkillOpt-Sleep adoption (2026-06-17)
Plan approved and captured. See [[skillopt-sleep-adoption]] and [[skillopt-sleep]].

- 2026-06-22: SkillOpt-proper benchmark harness for code-review BUILT (`~/tools/SkillOpt/skillopt/envs/rulereview/`, registered, split+scorer verified). Blocked on 2 prereqs: `pip install -e ~/tools/SkillOpt` + an API key (ANTHROPIC_API_KEY -> claude_chat). Manual+paid path. Awaiting: user key + OK to pip-install (venv), then smoke `python scripts/train.py --config configs/rulereview/default.yaml`.
- 2026-06-22 RESOLVED: nightly SkillOpt-Sleep STOPPED. 2 nights / 2 projects (beamforming + psylab_comm) / 107k tokens / 0 lift / 0 proposed edits. Sleep's judge has no signal on free-form research/coding intents and does not run repo pytest as oracle. Not scheduled. Real lift only via deferred SkillOpt-proper benchmark (manual). Captured value kept.
- Open: confirmed skill-only start (`evolve_memory` off); revisit per-project `CLAUDE.md` memory after beamforming proves out. Verify exact CLI subcommands against `python -m skillopt_sleep --help` (preview-stage docs).

## 2026-07-10 — upper-meta consumed-path check (tsmc28, deferred by user)
Streamed meta[437:384] verification impossible via wb_2 (state word registers
load scan init only — RTL-proven, see [[spi-streaming-protocol]] meta-map
CORRECTION). Future recipe lives in that note's open-side-quests list:
clk_update_counter_stop -> sync-div period probe. User: "some day I'll check it."

## 2026-11-10: weekly audit runs on the Mac (resolved, one follow-up open)
Fact: `.gitignore` line 20 (`**/projects/`, since commit 04c4b6e, 2026-04-30) also matches `vault/projects/`. `git ls-files vault/projects` returns 0 files, so project notes and `my-note/` exist only on the Mac. A cloud run works on a clone of the GitHub repo, so it cannot see them.
Decision (the user, 2026-11-10): option A. The weekly audit runs on the Mac and project notes stay off GitHub. Option B (stop ignoring `vault/projects/` so that a cloud routine can read the notes) was not chosen.
State: `hooks/weekly-audit.sh` and the launchd agent `com.llm-agent-config.weekly-audit` are installed (every day 10:00, the audit runs when the last one is 7 or more days old). The first real run on 2026-11-10 passed: exit 0, report written, stamp set, `my-note/` unchanged. The cloud routine `trig_019cbJbCKoJJ1SWqMCrmLxA1` is switched off (`enabled: false`). Design, tests and limits: [[weekly-audit-local-run]]. The gap was found in the session described in [[last-point-hook]].
Open: the Claude Code sign-in ends on 2026-11-11 at 22:47 UTC (`claude auth status`, field `loginExpiresAt`, read on 2026-11-10). The user has to run `claude auth login`. While the sign-in is invalid, a weekly run fails, shows a notification and is tried again the next day.

## 2026-11-10: flow commands built (three follow-ups open)
Fact: the skills `/study`, `/build`, `/test` and `/review-code` exist, and the agents `code-review`, `code-tester` and `code-test-builder` each have a new mode for them. Nine predictions were tested in 12 fresh headless sessions, and all held after three wording fixes. Design, sources, test table and limits: [[flow-commands]].
Decision (the user, 2026-11-10): "Yes creat both command", plus test and review skills that call the flow, plus an upgrade of the existing agents.
Open 1: every agent has `model: sonnet`. The reviewer may then be a smaller model than the session that wrote the code. Claude Code docs, best practices: a subagent is "the same model (or a smaller one) on the same task". No measurement exists for this setup. The user decides whether `code-review` gets `model: inherit`.
Open 2: the `checkpoint` skill has the same name as `/checkpoint`, a built-in alias of `/rewind` (Claude Code docs, commands). Which one runs when the user types it is not tested. Baseline: `/checkpoint` was typed 0 times in 14 transcripts.
Open 3: not tested yet: an interactive session, the fix loop after a review FAIL, the two-reviewer path, `code-quality` and `ux-quality` after the change to agent type names, and the Codex copies inside Codex.

## History

Keep this section last. Add new entries above it.

- 2026-11-10, entry "weekly audit runs on the Mac": the lines below are the entry as it stood before the local run was built and tested on the same day. They are kept word for word.
  - Old heading: `2026-11-10: weekly cloud audit cannot see project notes (decision needed)`. Changed because the user decided for option A.
  - Old line, changed because the cloud routine was switched off before its first run: Fact: `.gitignore` line 20 (`**/projects/`, since commit 04c4b6e, 2026-04-30) also matches `vault/projects/`. `git ls-files vault/projects` returns 0 files, so project notes and `my-note/` exist only on the Mac. The weekly cloud routine `trig_019cbJbCKoJJ1SWqMCrmLxA1` (Mondays 18:00 UTC, first run 2026-11-16) works on a clone of the GitHub repo. Its prompt says "Run the skill's Golden-Note Sync section for every folder in `vault/projects/`", but the clone has no such folder. It can only audit `agent/`, `areas/`, `library/`, and it would still stamp `vault/.last-audit`.
  - Old line, superseded by the decision: Options: (A) run the weekly audit on the Mac, where the notes are, and pause the cloud routine; project notes stay off GitHub. (B) stop ignoring `vault/projects/` so the notes are pushed and the cloud routine sees them; only if the repository is private and chip notes may be stored there. Agent's recommendation: A. Asked the user on 2026-11-10. See [[last-point-hook]] for the session where this was found.
  - Old line with wrong wording ("NOT PASSED or not finished"). The cron test did finish and it failed: a cron job cannot read the Claude Code login. The line was: 2026-11-10 DECIDED by the user: option A (weekly audit on the Mac, project notes stay off GitHub). Done: cloud routine paused (`enabled: false`). Cron login test: NOT PASSED or not finished: output was: started 14:30:01 by ppid 95897 (/usr/sbin/cron) Not logged in · Please run /login exit=1 .
  - Old line, superseded: the run was built on 2026-11-10 and is started by a launchd agent, not by cron. The line was: 2026-11-10 NOT DONE YET (session hit its usage limit): the local weekly run itself. Planned design: script `hooks/weekly-audit.sh`, started by cron every day at 10:00, runs only when `vault/.last-audit` is 7 or more days old. It calls `~/.local/bin/claude -p` with `--permission-mode dontAsk --model sonnet --max-budget-usd --no-session-persistence` (dontAsk allows vault edits through the existing allow rule, denies `my-note/` through the ask rule, and allows only read-only shell commands; source: Claude Code docs, permission modes). The script must set PATH (`/opt/homebrew/bin`, `/usr/local/bin`), set `LAST_POINT_DIR` to a throwaway folder so the run does not become the last point of the repo folder, collect the check 1 facts itself (`crontab -l` is not a read-only command), compare a copy of every `my-note/` folder before and after, write the report into the git-ignored project folder, and stamp `.last-audit`. Also open: README section "Two layers of automation" still describes the cloud run as active.
  - Old line, folded into the entry above: 2026-11-10 RESOLVED: the weekly audit runs on the Mac. cron could not log in to Claude Code ("Not logged in"), a launchd agent can. Installed: `hooks/weekly-audit.sh` + launchd agent `com.llm-agent-config.weekly-audit` (every day 10:00, runs when the last audit is 7+ days old). First real run on 2026-11-10 passed (exit 0, report written, stamp set). The report stays local in `vault/projects/llm-agent-config/`. README section updated. Details: [[weekly-audit-local-run]]. Still open: the Claude Code sign-in ends by 2026-11-11 and needs `claude auth login`.
