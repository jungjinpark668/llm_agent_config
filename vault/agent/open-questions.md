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

- 2026-06-22: beamforming night 1 = REJECT (0.000->0.000, replay=mock, no checkable oracle, 26k tokens, nothing adopted). SkillOpt lift needs a test signal beamforming lacks. Decision pending: try `psylab_comm` once (has pytest = grader; `--backend claude` + `replay_mode=fresh`), or stop chasing nightly lift and keep captured value.
- Open: confirmed skill-only start (`evolve_memory` off); revisit per-project `CLAUDE.md` memory after beamforming proves out. Verify exact CLI subcommands against `python -m skillopt_sleep --help` (preview-stage docs).
