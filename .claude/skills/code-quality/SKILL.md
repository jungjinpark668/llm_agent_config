---
name: code-quality
description: Run the full code quality pipeline (explore, review, reform, test) on a target repository. Produces a scorecard, applies prioritized fixes, and verifies with tests.
---

# Code quality pipeline

Run the 4-agent code quality pipeline on a target repository. The pipeline evaluates code against 9 categories (8 coding rules + project conventions), produces a quantitative scorecard, applies prioritized fixes, and verifies with tests.

## Invocation

`/code-quality [path/to/repo] [flags]`

**Arguments:**
- `path/to/repo` — target repository (defaults to CWD). If CWD is `~/llm_agent_config/`, require an explicit path.

**Flags (parsed from the argument string):**
- `--review-only` — run explore + review only, skip reform and test
- `--skip-explore` — assume code-context.md is fresh, skip the explore stage
- `--dry-run` — run explore + review + reform, show `git diff`, then revert all changes. Skip test stage.

## Agent spawning protocol

Custom agents (`code-review`, `code-reform`, `code-tester`) are defined in
`~/.claude/agents/`. They are auto-discovered as `subagent_type` values only
after a session restart. Within the same session they were created, or if the
system does not recognize the agent name, use this fallback:

1. Read the agent definition file: `~/.claude/agents/<agent-name>.md`
2. Strip the YAML frontmatter (the `---` delimited block)
3. Extract the `tools:` line from frontmatter -- note which tools the agent
   needs (this is informational; the general-purpose agent has all tools)
4. Spawn via `general-purpose` with the agent body as the system instructions:
   ```
   Agent({
     subagent_type: "general-purpose",
     prompt: "<agent body content>\n\n<task-specific parameters>"
   })
   ```

`code-explore` is a built-in subagent type and never needs this fallback.

**Concretely, for each agent:**

### code-review (read-only)
```
agent_def = Read("~/.claude/agents/code-review.md")  // strip frontmatter
Agent({
  subagent_type: "general-purpose",
  prompt: "<agent_def body>\n\nREPO_PATH: <path>\nRULES_PATH: ~/llm_agent_config/.claude/rules/coding-rules.md\n\n## Code context\n<code-context content>"
})
```

### code-reform (has write access)
```
agent_def = Read("~/.claude/agents/code-reform.md")  // strip frontmatter
Agent({
  subagent_type: "general-purpose",
  prompt: "<agent_def body>\n\nREPO_PATH: <path>\n\n## Scorecard\n<scorecard content>\n\n## Code context\n<code-context content>"
})
```

### code-tester (read + Bash)
```
agent_def = Read("~/.claude/agents/code-tester.md")  // strip frontmatter
Agent({
  subagent_type: "general-purpose",
  prompt: "<agent_def body>\n\nREPO_PATH: <path>\n\n## Reform report\n<reform-report content>\n\n## Code context\n<code-context content>"
})
```

This approach keeps the agent logic in `.claude/agents/` as the single source
of truth. The skill reads the definition at runtime, so updates to agent files
take effect immediately without changing the skill.

## Pipeline

### Stage 1: Setup

1. Determine `REPO_PATH` from argument or CWD.
2. Map the repo name to its vault project name (lowercase, underscores/spaces to hyphens).
3. Create the staging directory:
   ```bash
   STAGING="/tmp/code-quality-<project>-$(date +%s)"
   mkdir -p "$STAGING"
   ```
4. Check `mcp__filesystem__list_allowed_directories` to verify the target repo is accessible via MCP filesystem tools. If not, warn the user that agents will use built-in Read/Glob/Grep only.

### Stage 2: Explore (conditional)

**Skip if** `--skip-explore` flag is set.

1. Check for existing `code-context.md` at `~/llm_agent_config/vault/projects/<project>/code-context.md`.
2. Determine freshness:
   - If missing: spawn code-explore agent.
   - If present: read `repo_commit` from frontmatter. Run `git -C <REPO> diff --name-only <repo_commit>..HEAD -- '*.py'`. If source files changed, respawn. If only docs/config changed, use existing.
   - Also check for Source manifest and Quality signals sections. If missing (old-format code-context), respawn to get the enhanced output.
3. If spawning code-explore:
   ```
   Agent({
     subagent_type: "code-explore",
     prompt: "REPO_PATH: <path>, PROJECT: <project>"
   })
   ```
4. After agent returns: inject `repo_commit` hash and write to vault.
5. Copy code-context.md to `$STAGING/code-context.md`.

### Stage 3: Review

1. Read code-context.md content (strip frontmatter).
2. Read `~/.claude/agents/code-review.md`, strip frontmatter to get the agent body.
3. Spawn code-review agent using the spawning protocol above:
   ```
   Agent({
     subagent_type: "general-purpose",
     prompt: "<code-review agent body>\n\nREPO_PATH: <path>\nRULES_PATH: ~/llm_agent_config/.claude/rules/coding-rules.md\n\n## Code context\n<code-context content>"
   })
   ```
4. Write the returned scorecard to `$STAGING/scorecard.md`.
4. Parse the overall score from the summary table.

**Short-circuit:** If overall score >= 9.0/10 (81/90 or higher):
- Report: "Codebase is in good shape. Score: X/90. No reform needed."
- Present the scorecard to the user.
- Skip reform and test stages.
- End pipeline.

### Stage 4: Reform

**Skip if** `--review-only` flag is set.

1. **Safety snapshot:** If the working tree has uncommitted changes:
   ```bash
   git -C <REPO> stash push -m "code-quality-pre-reform-$(date +%s)"
   ```
   Record that a stash was created so it can be restored later.

2. Read `~/.claude/agents/code-reform.md`, strip frontmatter to get the agent body.
3. Spawn code-reform agent using the spawning protocol:
   ```
   Agent({
     subagent_type: "general-purpose",
     prompt: "<code-reform agent body>\n\nREPO_PATH: <path>\n\n## Scorecard\n<scorecard content>\n\n## Code context\n<code-context content>"
   })
   ```

3. Write the returned reform report to `$STAGING/reform-report.md`.
4. Parse the "Files modified" and "Issues addressed" counts.

**Short-circuit:** If 0 fixes were applied (all issues were P2 or manual-review-required):
- Report: "All issues are informational or require manual review. No changes made."
- Present the scorecard.
- Skip test stage.
- End pipeline.

**Dry-run handling:** If `--dry-run` flag is set:
- Run `git -C <REPO> diff` to show what reform would change.
- Present the diff to the user.
- Revert: `git -C <REPO> checkout -- <modified-files-from-reform-report>`
- If a stash was created: `git -C <REPO> stash pop`
- End pipeline.

### Stage 5: Test

**Skip if** `--review-only` or `--dry-run` flags are set.

1. Read `~/.claude/agents/code-tester.md`, strip frontmatter to get the agent body.
2. Spawn code-tester agent using the spawning protocol:
   ```
   Agent({
     subagent_type: "general-purpose",
     prompt: "<code-tester agent body>\n\nREPO_PATH: <path>\n\n## Reform report\n<reform-report content>\n\n## Code context\n<code-context content>"
   })
   ```

2. Write the returned test report to `$STAGING/test-report.md`.
3. Parse the verdict.

### Stage 6: Verdict

Based on the test report verdict:

**PASS or PASS WITH WARNINGS:**
- Keep all reform changes.
- Report: "Reform complete. All tests pass. Score improved from X/90 to estimated Y/90."
- If a stash was created and user had prior changes: `git -C <REPO> stash pop`

**FAIL (test-only regressions):**
- Keep reform changes (source code is structurally correct).
- Report the regressions and suggested test updates from the test report.
- Present both the reform report's "Test updates needed" section and the test report's regression details.

**FAIL (source regressions):**
- Rollback reform changes:
  ```bash
  git -C <REPO> checkout -- <files-from-reform-report>
  ```
- If a stash was created: `git -C <REPO> stash pop`
- Report: "Reform introduced source-level regressions. Changes rolled back. Scorecard is still valid for manual fixes."
- Present the scorecard as informational.

**FAIL (pre-existing only):**
- Keep reform changes (they did not cause the failures).
- Report: "Tests had pre-existing failures (not caused by reform). Reform changes preserved."

### Stage 7: Summary

1. Write a final summary to `$STAGING/summary.md` with:
   - Pipeline stages completed
   - Overall score
   - Fixes applied / skipped / rolled back
   - Test verdict
   - Staging directory path

2. Present the summary to the user. Do NOT delete the staging directory (user may want to inspect artifacts).

3. If the user asks to persist results to the vault, write a note to `vault/projects/<project>/` with appropriate frontmatter.

## Error handling

- If any agent fails to return a response, report the failure and continue with remaining stages where possible.
- If code-explore fails, fall back to reading existing code-context.md (even if stale). If none exists, abort pipeline.
- If code-review fails, abort (no scorecard means nothing downstream can work).
- If code-reform fails, present the scorecard as the final output.
- If code-tester fails, keep reform changes but warn the user that testing was not completed.

## Notes

- The orchestrator runs in the main context (opus model). All subagents run on sonnet for cost efficiency.
- Intermediate artifacts are session-scoped. They go to `/tmp/`, not the vault. The vault is reserved for durable cross-session data (code-context.md only).
- The pipeline is sequential. Each agent depends on the previous agent's output. No parallelization between stages.
- One reform pass only. No retry loops. If reform causes regressions, rollback and report.
