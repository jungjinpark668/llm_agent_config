---
name: review-code
description: Independent review of one change against its check or spec, done by a fresh read-only subagent that has not seen the reasoning behind the change. Reports only gaps that affect correctness, each with file and line, and results that were claimed without evidence. Use after a build passes its check, or when the user asks to review a change, a diff, or a claimed result. Not for a whole-repository quality pass (that is code-quality) and not for style.
argument-hint: [files or git range, default is the current diff]
---

# Review a change against its check

Target: $ARGUMENTS

Why a separate agent: a reviewer that has not seen your reasoning is not swayed by it (Claude Code docs, best practices, "Give Codex a check to run"). So the reviewer gets the four facts below and nothing else.

## 1. Write the brief

1. `REPO_PATH`: the absolute path of the repository.
2. `CHANGE`: the path of a diff file, plus the list of changed files and new files. The reviewer cannot run git, so write the diff to a file yourself: in your scratchpad directory when the session has one, otherwise `/tmp/review-<repo>-<time>.diff`. Empty target: `git diff HEAD`; if that is empty, `git diff HEAD~1 HEAD`. A target that is a git range or a file list: the diff of exactly that. New untracked files are not in a diff: take them from `git status --short` and add them to the list.
3. `SPEC`: the task in one sentence, the check (command and pass rule), and the expected-values table with sources. If there is none, write the task as the user stated it and `no check table`.
4. `CLAIMS`: every result you reported as true (for example "all tests pass", or a measured number). Give each one with its command and the output file, or quote the output lines.

Leave out your reasoning, your explanation of why the code is right, and the conversation.

## 2. Spawn the reviewer

Spawn the `code-review` agent by its own type name (`subagent_type: code-review`), so that its read-only tool list applies. The prompt starts with the line `MODE: change`, then the brief. Wait for its report.

For high-stakes output, as defined under "Santa Method Verification" in AGENTS.md, spawn two reviewers in one message with the same brief. Both must pass.

## 3. Check the report yourself

Open every cited file and line before you repeat a finding. A reviewer can be wrong. Mark each finding `confirmed` or `not confirmed`, with the reason.

## 4. Report to the user

- Verdict: `PASS`, `FAIL`, or `CANNOT JUDGE`.
- One table: file and line, problem, confirmed (yes or no), fixed (yes or no).
- Claims without evidence.
- What was not reviewed.

## 5. Fixes

Fix nothing unless the build flow called this skill or the user asked for fixes. When you do fix:

- Fix only confirmed gaps that affect correctness. Skip style: a reviewer that is asked to find problems always finds something, and fixing every finding adds code nobody needs (Claude Code docs, best practices, "Review against your spec").
- After a fix, run the check again with the `test` skill, then review again. At most 3 rounds. Then stop and report to the user.
