---
name: study
description: Study flow for one question about theory, a paper, or a result the user does not believe yet. Claim, source and predicted number first, then the smallest run, then the user's own conclusion in my-note. The user starts it by typing /study.
argument-hint: [one question]
disable-model-invocation: true
---

# Study flow

Question: $ARGUMENTS

These rules hold until the user ends the flow or types `/clear`. One question per flow. The flow has five steps. Where a turn ends with STOP, end your turn there and wait for the user.

If the line "Question:" above is empty, ask the user for the question and do nothing else.

## Turn 1: steps 1 and 2 (this turn)

Write no code and run nothing. Reading files, papers and vault notes is allowed, and needed for the sources.

Answer with these four items and nothing else:

1. Claim. One sentence that can be true or false. Under it, a table of every symbol you use (symbol, meaning, unit), then the reason in at most five lines, one logic step per line.
2. Source. Paper and equation number, or file and line, or a `my-note/` file. If you find none, write `no source`. The claim is then a guess, and the user decides whether it is worth a run (doctrine rule 4).
3. Number. One number, or one plot shape, that must differ if the claim is true. Give the predicted value for each case that will be compared, and how you got it.
4. Smallest run. The shortest run that measures this number: script or command, input data, seed, expected run time.

End the turn with this question: "Run it? You can give me your own prediction first." STOP.

## Turn 2: steps 3 and 4 (after the user says run)

3. Run exactly the smallest run of item 4. Use the same data and the same seed for every case that is compared. A run on a remote server follows the `server-tasks` skill.
4. Print one table: case, predicted, measured, match (yes or no). Under it give the exact command and where the output is.
   - Match: say that the claim holds for this setup, and name the setup.
   - No match: the difference is the finding. Say which one is wrong (the claim, the prediction, or the run) and give the evidence. Propose one next question.

After a result, never change the run, the tolerance or the prediction to get a match. A new prediction is a new question.

End the turn by asking the user to write their conclusion (step 5), or to name what is still unclear. STOP.

## Step 5: record

- The user writes 3 to 5 lines in their own words in `~/llm_agent_config/vault/projects/<project>/my-note/<topic>.md`: the claim, the number, the conclusion. Never write in `my-note/` yourself, unless the user explicitly asks for it.
- When the user has written them, read the lines and name any gap between them and the evidence.
- Write your own note in the project folder of the vault (vault rules apply): the four items, the table, the command, the sources.
- Tell the user to type `/clear` before the next question.

## Rules for the whole flow

- Stay on this one question. If a new question comes up, list it under "Next questions" and let the user choose.
- Every statement rests on a source or on a run. Mark anything else `not verified`.
- Answer in the default delivery style (doctrine rule 5). Go deeper only when the user asks.
