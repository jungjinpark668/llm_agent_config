---
name: build
description: Build flow for code, scripts, figures, sweeps and bench runs. The check and its expected values with sources come first, then the smallest working case, the check run, a fresh review, and the record. The user starts it by typing /build.
argument-hint: [task]
disable-model-invocation: true
---

# Build flow

Task: $ARGUMENTS

These rules hold until the task is recorded or the user ends the flow. The flow has five steps. Where a turn ends with STOP, end your turn there and wait for the user.

If the line "Task:" above is empty, ask the user for the task and do nothing else.

## Turn 1: steps 1 and 2 (this turn)

Change no file and run nothing that changes state. Reading code, RTL, data and vault notes is allowed, and needed for the sources.

Answer with these five items and nothing else:

1. Task. One sentence, plus what is out of scope.
2. Check. The command or the measurement that comes back pass or fail: a pytest target, an exact bit-error count, a `check_*` make target, an instrument reading. If the project has none for this task, say so and propose the smallest one.
3. Expected values. A table with one row per value the check compares: value, expected, tolerance, source. A source is a file and line (code or RTL), a paper equation, a measured data file, or a `my-note/` file. A row without one gets `NO SOURCE` in the source column.
4. Limits. What the work may touch, the server rules that apply (see the `server-tasks` skill), and the expected run time.
5. Smallest case. The minimum working example that exercises the check: one point, one setting, a short run.

End the turn with one question: does the user confirm the table, or which rows change? A row marked `NO SOURCE` needs the user's value or the user's OK (doctrine rule 4). STOP.

## Turn 2: steps 3 and 4 (after the user confirms the table)

3. Build the smallest case only. Follow the coding rules. Then run the check with the `test` skill, using the confirmed table unchanged.
4. Compare.
   - Fail: the difference is the debug signal. Fix the code, or tell the user which table row looks wrong and why. Never tune a value until the check passes, never weaken the check, and never change a table row without the user's OK (doctrine rule 2).
   - Pass: run the `review-code` skill on the change. Fix only confirmed gaps that affect correctness, then run the check again. At most 3 fix rounds, then stop and report.

When the smallest case has passed the check and the review, do the full run if the task has one (full test suite, sweep, long run). A run on a remote server or on the bench follows the `server-tasks` skill and starts only after the user says go.

## Step 5: record

- Final answer: the table with a measured column, the exact commands, the last lines of their output or the path of the output file, the review verdict, and what was not checked. Never write "done" without this evidence.
- Write the checkpoint or the project note in the vault (vault rules apply).
- Tell the user which confirmed values deserve one line each in `my-note/`. Never write in `my-note/` yourself, unless the user explicitly asks for it.

## Rules for the whole flow

- Every value rests on a source or on a run. Mark anything else `not verified`.
- Change only what the task needs. A formatting hook may reformat a file you edited: leave its changes, and name them in the final answer.
- Answer in the default delivery style (doctrine rule 5).
