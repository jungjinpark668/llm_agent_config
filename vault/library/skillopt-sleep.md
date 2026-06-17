---
date: 2026-06-17
tags: [agent-tooling, skill-optimization, self-improvement, claude-code]
type: concept
status: active
---

# SkillOpt and SkillOpt-Sleep

Reference for microsoft/SkillOpt. The rollout into my own config is tracked in [[skillopt-sleep-adoption]].

## What it is
SkillOpt treats one skill markdown file as the trainable state of a frozen model and "trains" it like a network, without touching weights. The deployed artifact is a compact `best_skill.md` (300-2,000 tokens) that runs against the unchanged model with zero inference-time cost.

## The loop (SkillOpt proper)
`rollout` (run the target model on benchmark tasks, record scored trajectories) -> `reflect` (a separate optimizer model reads success/failure minibatches) -> bounded add/delete/replace edits capped by an edit budget (the "learning rate") -> held-out `gate` (keep an edit only if the validation score strictly improves) -> export `best_skill.md`.

Adding a target means writing a Python env: `dataloader.py` + `rollout.py` + a scorer emitting `hard`/`soft` in [0,1]. Their warning: "noisy scoring kills the optimizer."

## The two-condition test (when can a markdown file be optimized?)
1. In the execution path: instructions the model follows while doing a task.
2. Has an automatic, low-noise grader over a recurring task family.

Condition 1 is common (skills, agents, rules files, auto-injected notes, CLAUDE.md all qualify). Condition 2 is the scarce ingredient and the real gate.

## SkillOpt-Sleep (deployment companion, the "always learning" piece)
Nightly cycle for Claude Code: harvest `~/.claude` transcripts (read-only) -> mine recurring checkable tasks -> replay offline on your budget -> consolidate (reflect -> bounded edit -> gate) -> stage a proposal -> you adopt.

- Reads: `~/.claude/history.jsonl`, `~/.claude/projects/<slug>/<sessionId>.jsonl`; detects approval phrases ("thanks" / "still broken").
- Writes: a NEW managed skill `~/.claude/skills/skillopt-sleep-learned/SKILL.md`, plus optional `<project>/CLAUDE.md`. Never edits existing skills or agents.
- Safe defaults: `backend=mock` (free), `auto_adopt=false` (stage only), `gate_mode=on`, `redact_secrets=true`, `projects=invoked`, budgets 40 tasks / 400k tokens per night.
- State: `~/.skillopt-sleep/` (outside any repo). Staging: `<project>/.skillopt-sleep/staging/<ts>/`.
- Engine CLI: `python -m skillopt_sleep {harvest|dry-run|run|status|adopt|schedule}`. Real backends shell out to the `claude`/`codex` CLI already on PATH, so the `claude` backend needs no extra API key. `schedule` installs its own nightly cron, so no plugin is required.

## Fit for my artifacts
- Agents are the purest fit: an agent `.md` body is a system prompt = a skill document. `code-review`/`ux-review` already emit a gradable scorecard, so they are the strongest deferred benchmark targets. Optimize the body only; preserve frontmatter (`name`/`tools`/`model`).
- `coding-rules.md` is skill-like and its grader could reuse the code-review score. Risk: the optimizer maximizes the metric, not my intent, so hand-authored policy stays human-reviewed.
- Vault notes are reference knowledge with no task score, so they fail condition 2 and are not a SkillOpt target. `obsidian-audit` stays the tool for note quality. Sleep's `CLAUDE.md` memory is the nearest analog: feed insights into the vault, do not optimize the notes.

## Caveats
Preview-stage; docs are internally inconsistent on exact command strings, so verify against `python -m skillopt_sleep --help`. Headline gains (+19-24 pts, 0.00 -> 1.00) are on benchmarks with a clean grader; flat within noise on subjective tasks. Paper arXiv 2605.23904; repo https://github.com/microsoft/SkillOpt .
