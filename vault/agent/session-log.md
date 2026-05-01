## 2026-04-30
**Worked on:** llm_agent_config workflow demo + project archaeology on psylab-comm
**What worked:** Subagent-based context loading kept main context clean. Three parallel Explore agents for deep dives covered beamforming, signal chain, and test/script structure simultaneously. Phase 3 verification (pip install -e . + pytest) passed cleanly: 1189 tests, 0 failures.
**What failed:** First Explore subagent (beamforming deep dive) hit a context issue and returned a garbled checkpoint summary instead of the requested analysis. The other two subagents worked fine. Compensated by relying on the two good reports plus Phase 1 surface scan.
**Key decisions:** Produced 3 vault notes (architecture-overview, beamforming-subsystem, signal-chain-and-testing) plus the existing config-system-overview. Chose not to create separate notes for satellite and localization since they're well-covered within the signal-chain note and aren't complex enough to warrant standalone notes.
**Open:** Full project-archaeology would benefit from reading gsc_bf.py completely (only first ~500 lines were covered by subagent). The GSCBF class is ~1500 lines and the most complex part of the codebase.
**Connections:** [[architecture-overview]] ← [[beamforming-subsystem]] ← [[signal-chain-and-testing]] form a linked chain; [[config-system-overview]] connects to the llm_agent_config system
