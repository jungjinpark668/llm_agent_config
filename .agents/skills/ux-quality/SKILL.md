---
name: ux-quality
description: Run the full UX quality pipeline (review, reform, test, README) on a CLI/TUI application. Produces a UX scorecard, applies prioritized fixes, verifies with tests, and generates usage documentation.
---

# UX quality pipeline

Run the 3-agent UX quality pipeline on a CLI/TUI application. The pipeline evaluates user experience across 9 categories (command discoverability, input convenience, error feedback, etc.), produces a quantitative UX scorecard, applies prioritized fixes, verifies no regressions, and generates a usage README.

## Invocation

`/ux-quality [path/to/repo] [flags]`

**Arguments:**
- `path/to/repo` — target repository (defaults to CWD). If CWD is `~/llm_agent_config/`, require an explicit path.

**Flags (parsed from the argument string):**
- `--review-only` — run context + review only, skip reform, test, and README
- `--no-readme` — run full pipeline but skip README generation
- `--readme-only` — run context + README generation only, skip review and reform
- `--dry-run` — run context + review + reform, show `git diff`, then revert all changes. Skip test and README.

## Agent spawning protocol

Custom agents (`ux-review`, `ux-reform`, `usage-guide-writer`) are defined in
`~/.claude/agents/`. They are auto-discovered as `subagent_type` values only
after a session restart. Within the same session they were created, or if the
system does not recognize the agent name, use this fallback:

1. Read the agent definition file: `~/.claude/agents/<agent-name>.md`
2. Strip the YAML frontmatter (the `---` delimited block)
3. Extract the `tools:` line from frontmatter (informational; general-purpose agent has all tools)
4. Spawn via `general-purpose` with the agent body as the system instructions:
   ```
   Agent({
     subagent_type: "general-purpose",
     prompt: "<agent body content>\n\n<task-specific parameters>"
   })
   ```

The existing `code-tester` agent is reused for regression testing.

**Concretely, for each agent:**

### ux-review (read-only + safe Bash probes)
```
agent_def = Read("~/.claude/agents/ux-review.md")  // strip frontmatter
Agent({
  subagent_type: "general-purpose",
  prompt: "<agent_def body>\n\nREPO_PATH: <path>\n\n## Code context\n<code-context content>"
})
```

### ux-reform (has write access)
```
agent_def = Read("~/.claude/agents/ux-reform.md")  // strip frontmatter
Agent({
  subagent_type: "general-purpose",
  prompt: "<agent_def body>\n\nREPO_PATH: <path>\n\n## Scorecard\n<ux-scorecard content>\n\n## Code context\n<code-context content>"
})
```

### usage-guide-writer (write access for README.md only)
```
agent_def = Read("~/.claude/agents/usage-guide-writer.md")  // strip frontmatter
Agent({
  subagent_type: "general-purpose",
  prompt: "<agent_def body>\n\nREPO_PATH: <path>\nREADME_MODE: generate\n\n## Code context\n<code-context content>\n\n## UX scorecard\n<scorecard content if available>"
})
```

### code-tester (reused from code-quality pipeline)
```
agent_def = Read("~/.claude/agents/code-tester.md")  // strip frontmatter
Agent({
  subagent_type: "general-purpose",
  prompt: "<agent_def body>\n\nREPO_PATH: <path>\n\n## Reform report\n<ux-reform-report content>\n\n## Code context\n<code-context content>"
})
```

## Pipeline

### Stage 1: Setup

1. Determine `REPO_PATH` from argument or CWD.
2. Map the repo name to its vault project name (lowercase, underscores/spaces to hyphens).
3. Create the staging directory:
   ```bash
   STAGING="/tmp/ux-quality-<project>-$(date +%s)"
   mkdir -p "$STAGING"
   ```
4. **Clean working tree check.** Run `git -C <REPO> status --porcelain`. If there are uncommitted changes, warn the user. If changes are from a prior code-quality or ux-quality reform, ask whether to proceed or abort.

### Stage 2: Context (conditional)

1. Check for existing `code-context.md` at `~/llm_agent_config/vault/projects/<project>/code-context.md`.
2. Determine freshness using the standard protocol (check `repo_commit` vs HEAD, check for source file changes).
3. If missing or stale, spawn `code-explore` agent to generate it.
4. If present and fresh, read it directly.
5. Copy to `$STAGING/code-context.md`.

**Skip if** `--readme-only` flag is set and code-context.md already exists (just read it).

### Stage 3: UX review

**Skip if** `--readme-only` flag is set.

1. Read code-context.md content (strip frontmatter).
2. Read `~/.claude/agents/ux-review.md`, strip frontmatter to get the agent body.
3. Spawn ux-review agent using the spawning protocol above.
4. Write the returned scorecard to `$STAGING/ux-scorecard.md`.
5. Parse the overall score from the summary table.

**Short-circuit:** If overall score >= 81/90 (9.0/10 average):
- Report: "UX is in good shape. Score: X/90. No reform needed."
- Present the scorecard to the user.
- Skip reform and test stages.
- Continue to README stage if not `--review-only`.

### Stage 4: UX reform

**Skip if** `--review-only` or `--readme-only` flags are set.

1. **Safety snapshot:** If the working tree has uncommitted changes:
   ```bash
   git -C <REPO> stash push -m "ux-quality-pre-reform-$(date +%s)"
   ```
   Record that a stash was created.

2. Read `~/.claude/agents/ux-reform.md`, strip frontmatter to get the agent body.
3. Spawn ux-reform agent using the spawning protocol.
4. Write the returned reform report to `$STAGING/ux-reform-report.md`.
5. Parse the "Files modified" and "Issues addressed" counts.

**Short-circuit:** If 0 fixes were applied:
- Report: "All issues are informational or require manual review. No changes made."
- Present the scorecard.
- Skip test stage.
- Continue to README stage if applicable.

**Dry-run handling:** If `--dry-run` flag is set:
- Run `git -C <REPO> diff` to show what reform would change.
- Present the diff to the user.
- Revert: `git -C <REPO> checkout -- <modified-files-from-reform-report>`
- If a stash was created: `git -C <REPO> stash pop`
- End pipeline.

### Stage 5: Test

**Skip if** `--review-only`, `--readme-only`, or `--dry-run` flags are set.

1. Read `~/.claude/agents/code-tester.md`, strip frontmatter to get the agent body.
2. Spawn code-tester agent using the spawning protocol.
3. Write the returned test report to `$STAGING/test-report.md`.
4. Parse the verdict.

### Stage 6: README

**Skip if** `--review-only` or `--no-readme` flags are set.

1. Determine README_MODE:
   - If no `README.md` exists in REPO_PATH: `generate`
   - If `README.md` exists and `--readme-only`: `update`
   - If `README.md` exists and running full pipeline: `append` (add missing sections only)

2. Read `~/.claude/agents/usage-guide-writer.md`, strip frontmatter to get the agent body.
3. Spawn usage-guide-writer agent. Include the UX scorecard in the prompt if available (helps the agent understand what the app does).
4. The agent writes README.md directly to REPO_PATH.
5. Record that README was generated/updated.

### Stage 7: Verdict

Based on the test report verdict (if test was run):

**PASS or PASS WITH WARNINGS:**
- Keep all reform changes and README.
- Report score and fixes applied.
- If a stash was created: `git -C <REPO> stash pop`

**FAIL (test-only regressions):**
- Keep reform changes (source is structurally correct).
- Report regressions and suggested test updates.

**FAIL (source regressions):**
- Rollback reform changes:
  ```bash
  git -C <REPO> checkout -- <files-from-reform-report>
  ```
- Keep README (it documents the original state, still useful).
- If a stash was created: `git -C <REPO> stash pop`
- Report: "Reform introduced regressions. Changes rolled back. Scorecard is valid for manual fixes."

**FAIL (pre-existing only):**
- Keep reform changes and README.
- Report: "Tests had pre-existing failures. Reform changes preserved."

**If test was skipped** (0 fixes or short-circuit):
- No verdict needed. Present scorecard and README status.

### Stage 8: Summary

1. Write a final summary to `$STAGING/summary.md` with:
   - Pipeline stages completed
   - UX score (before / estimated after)
   - Fixes applied / skipped / rolled back
   - Test verdict (if run)
   - README status (generated / updated / skipped)
   - Staging directory path

2. Present the summary to the user.

3. If the user asks to persist results to vault, write a note to `vault/projects/<project>/`.

## Error handling

- If any agent fails to return a response, report the failure and continue where possible.
- If code-explore fails, fall back to reading existing code-context.md. If none exists, proceed without context (agents can still scan the repo directly).
- If ux-review fails, abort (no scorecard means reform can't work). README-only mode can still proceed.
- If ux-reform fails, present the scorecard as the final output. README can still proceed.
- If code-tester fails, keep reform changes but warn that testing was not completed.
- If usage-guide-writer fails, report it. Reform changes are independent and unaffected.

## Notes

- The orchestrator runs in main context (opus model). All subagents run on sonnet for cost efficiency.
- Intermediate artifacts go to `/tmp/`, not the vault.
- The pipeline is sequential. Each agent depends on prior output. No parallelization between stages.
- One reform pass only. No retry loops. If reform causes regressions, rollback and report.
- The README runs last so it documents the post-reform state of the application.
