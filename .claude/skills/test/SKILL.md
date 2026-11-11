---
name: test
description: Test a change or a claim with a check that comes back pass or fail. Expected values with their sources come first, then the smallest run, then a predicted-versus-measured table with the command and its output. Use when the user asks to test, verify or validate code or a result, and at the check step of the build flow. Not for a question that needs no run.
argument-hint: [what to test]
---

# Test: name the check, then run it

Target: $ARGUMENTS

Apply these steps to every test in this task.

## 1. Name the check before any run

- What is tested, in one sentence.
- The command or the measurement.
- Expected values as a table: value, expected, tolerance, source.

An expected value may come from a paper equation, a closed form, golden data, RTL, a `my-note/` file, or a table the user confirmed in the build flow. It may not come from the output of the code under test: such a test passes even when the code is wrong. For RTL the reference is the project's bit-true model or its existing check targets, not a checker written in this session.

If the build flow already has a confirmed table, use it unchanged. If every row has a source, go on to step 2. If a row has no source, show the table, mark that row `NO SOURCE`, and stop for the user's value (doctrine rule 4).

## 2. Choose how to run

| Situation | How |
|---|---|
| The check exists and its output is short | Run it in this session |
| The check exists and its output is long (full suite, sweep, many seeds) | Spawn the `code-tester` agent with `CHECK:` holding the command and the table. Only its report returns |
| New behavior needs a new test file | Spawn the `code-test-builder` agent with `CHECK:` holding the table (spec mode) |
| Current behavior must stay the same during a refactor | Spawn the `code-test-builder` agent with `TARGET_FILES:` (baseline mode) |
| The check runs on a remote server or on the bench | Run it in this session under the `server-tasks` skill. Never hand it to a subagent |

Spawn these agents by their own type name (`subagent_type: code-tester`), so that their tool limits apply. Give each one `REPO_PATH:` and, when the project has a `code-context.md`, its content under a `## Code context` header.

## 3. Run the smallest case first

One case, one seed, a short run. Then the full check.

## 4. Report

- One table: value, expected, measured, pass or fail.
- The exact command, its exit code, and the last lines of its output or the path of the output file.
- Verdict: `PASS`, `FAIL`, or `NOT RUN` with the reason.

Never report `PASS` for something that did not run.

## 5. On FAIL

Report the difference before you change anything. The difference is the debug signal (doctrine rule 1). Say which is wrong (the code, the expected value, or the test) and give the evidence. Do not edit an expected value, a tolerance, a seed or the test to get a pass without the user's OK.

Inside the build flow, continue with its step 4. Outside it, wait for the user.
