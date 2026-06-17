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

- Next action: clone `microsoft/SkillOpt` to `~/tools/SkillOpt`, add `.skillopt-sleep/` to `.gitignore`, run a free mock eval (`python -m skillopt_sleep harvest` / `dry-run --backend mock`) from the beamforming repo at `/Users/parkjungjin/PSy_lab/Beamforming/beamforming_lms_tracker_inte16_test`.
- Open: confirmed skill-only start (`evolve_memory` off); revisit per-project `CLAUDE.md` memory after beamforming proves out. Verify exact CLI subcommands against `python -m skillopt_sleep --help` (preview-stage docs).
