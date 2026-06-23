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

- 2026-06-22 RESOLVED: nightly SkillOpt-Sleep STOPPED. 2 nights / 2 projects (beamforming + psylab_comm) / 107k tokens / 0 lift / 0 proposed edits. Sleep's judge has no signal on free-form research/coding intents and does not run repo pytest as oracle. Not scheduled. Real lift only via deferred SkillOpt-proper benchmark (manual). Captured value kept.
- Open: confirmed skill-only start (`evolve_memory` off); revisit per-project `CLAUDE.md` memory after beamforming proves out. Verify exact CLI subcommands against `python -m skillopt_sleep --help` (preview-stage docs).
