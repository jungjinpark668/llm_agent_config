## 2026-04-30
**Worked on:** llm_agent_config workflow demo + project archaeology on psylab-comm
**What worked:** Subagent-based context loading kept main context clean. Three parallel Explore agents for deep dives covered beamforming, signal chain, and test/script structure simultaneously. Phase 3 verification (pip install -e . + pytest) passed cleanly: 1189 tests, 0 failures.
**What failed:** First Explore subagent (beamforming deep dive) hit a context issue and returned a garbled checkpoint summary instead of the requested analysis. The other two subagents worked fine. Compensated by relying on the two good reports plus Phase 1 surface scan.
**Key decisions:** Produced 3 vault notes (architecture-overview, beamforming-subsystem, signal-chain-and-testing) plus the existing config-system-overview. Chose not to create separate notes for satellite and localization since they're well-covered within the signal-chain note and aren't complex enough to warrant standalone notes.
**Open:** Full project-archaeology would benefit from reading gsc_bf.py completely (only first ~500 lines were covered by subagent). The GSCBF class is ~1500 lines and the most complex part of the codebase.
**Connections:** [[architecture-overview]] ← [[beamforming-subsystem]] ← [[signal-chain-and-testing]] form a linked chain; [[config-system-overview]] connects to the llm_agent_config system

## 2026-06-11
**Worked on:** Intel16 test chip deep-dive — full documentation set for design_jj + DSU silicon functional testing (beamforming-lms-tracker-intel16-test).
**What worked:** Deterministic extraction (python over conf JSON + grep over generated scan modules) caught what readers missed: silicon common chain = 1058b WITHOUT sc_clk_gate_design_ev_en (reference RTL has 1059); design_jj/dsu confs match RTL exactly. Direct RTL reads refuted a subagent claim — array_manifold_mem IS scan-writable (sc_array_manifold_mem_wen/addr/din + q capture). Adversarial notes-only review found a real driver trap: bare ScanController.scan_in() resends the cached vector; scripts must use build_and_scan_in().
**What failed:** Explorer subagents fabricated/garbled details under pressure (pad map rows, scan inventory, "no manifold write path") — every load-bearing claim needed primary-source verification. My own first recipe draft had OSR=4 (confused field width with value; sps=3 ⇒ OSR=3) and smoke arithmetic missing the 3 after-rst words.
**Key decisions:** First silicon test = bf_mode 00 (frozen weights by construction), smoke-sized 30-word run; no vector regeneration (fetch archived test_vec); notes-only deliverable, RPi script is a follow-up plan.
**Open:** archived test_vec + sim defines location; RO characterization CSV; clk_main_div_o measurement instrument; pass-2 alignment verification.
**Connections:** [[silicon-functional-test-recipe]] ← [[design-jj-sim-test-flow]] (recipe is a 1:1 mapping of the verified TB sequence onto scan operations)
