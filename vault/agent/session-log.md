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

## 2026-06-13/14
**Worked on:** First-silicon RO frequency measurement, then full RO0/RO1 coarse×fine characterization + clock-divider validation on the RPi bench.
**What worked:** Cross-divider consistency check (measure at 2 dividers, scaled freq must agree) was the key tool — it exposed that all earlier "results" were the 34410A no-signal floor (~640 Hz), and later confirmed real signal at 0.006-0.02% spread. PSU current is a probe-independent RO-alive test (VDD_RO 0.02→0.17 mA, core +2 mA when RO enabled). Two complementary divider runs (sel 14/15 fast; sel 1-4 slow) merged by cluster-agreement covered the ~10^6× RO range that no single divider pair can. coarse=binary ÷2 (1.99×), fine=linear-in-period (R²=0.9999).
**What failed:** Root cause of the flat ~640 Hz was a physical probe connection (user fixed it), NOT instrument mode or chip — wasted a coarse/fine sweep + a divider ladder on floor data before catching it. Lesson: monotonic fine-tracking is NOT proof of real signal (aliased beats track too); only cross-divider agreement is. First sweep used div 13/14 — too low, floored the fast corner; needed 14/15.
**Key decisions:** Verify scan health (scan_init_test --power) before each campaign; never touch PSU on a live board (--skip-power always); run in tmux (RPi link drops constantly).
**Open:** exact 1 GHz needs a VDD_RO trim (not done — touches power); coarse0/fine0 RO >19.6 GHz unmeasurable with DMM; characterization only at 1.0 V (no voltage sweep yet); an adaptive per-config divider would replace the two-run workaround.
**Connections:** [[ro-usage-guide]] ← [[2026-06-14-ro-full-characterization]] (usage recipes built on the characterization data); closes the "clk_main_div_o measurement instrument" open item from [[silicon-functional-test-recipe]] (34410A works within 3 Hz-300 kHz via the divider).

## 2026-06-15
**Worked on:** DSU scan-bypass memory verification — `scratch/dsu_mem_scan_test.py`, written then run on silicon (RPi bench).
**What worked:** Staged + clock-gated bypass protocol passed first try — MWE (bank A addr 0) and sampled both-bank run (addrs 0/1/25/114/255/256/510/511) all match. Gating `sc_clk_gate_dsu_en` around each op (clk idle except the commit/read window) makes writes disturb-free; addr/data settle before any clock edge. Different seeds per bank confirmed A and B are separate memories (no aliasing).
**What failed:** Nothing on-chip. Plan went through ~6 user-corrected revisions first (DSU = Data *Streaming* Unit not Stimulus; both banks are single-port 1RW tested independently, not A-read/B-write; enables can be hoisted per-pass since clk is gated; RO-only clock, no ext clk).
**Key decisions:** Clock = RO0 only (coarse8/fine15, div16); enables hoisted out of the per-word loop, parked once per pass; gate transitions roundtrip+retry against RO-induced bit-slips; ran with --skip-power on the live board.
**Connections:** [[dsu-mem-scan-test]] applies the [[dsu-architecture]] bypass path with the [[ro-usage-guide]] clock setup; reused the `build_and_scan_in()` lesson from [[silicon-functional-test-recipe]].

## 2026-06-16
**Worked on:** cdot_product silicon fmax test (Task B) on design_jj — and a long methodology debug that overturned an early wrong answer.
**What worked:** Final fmax = 807.7 MHz (bit-exact 2050/2050; next code 845 MHz fails). Bisection over the raw-RO ladder with an AB-pointer guard + clean-bank discipline, after a cold setup_power cycle restored the chip baseline. Details in [[cdot-fmax-silicon-result]].
**What failed (save future hours):** (1) early "GHz passes" were STALE-DATA artifacts — skip-load + unreset bank B, readback returned a prior record; the AB-pointer guard fixes it. (2) The datapath runs on the UNDIVIDED RO; the clk divider only feeds a measurement pad — dividing the axis mislabeled 3273 MHz as 1636 MHz. (3) Bypass-writing bank B to "clear" it corrupts the port-B controller (AB=511). (4) A partial (short-stimulus) bank over-runs and wraps AB; use the full 512-depth bank. (5) Extended testing degraded the chip (slow baseline went 2050→8/2050); power-cycle + scan-init check restored it.
**Key decisions:** Trust the chip test over the 2 GHz prior; report the adjacent pass/fail RO-code pair (resolution = RO code spacing). Each fmax point loads bank A once at a slow clock, streams at the test clock.
**Connections:** [[cdot-fmax-silicon-result]] extends [[cdot-product-datapath-test]] and uses the bring-up from [[chip-init-sequence]]; clock fact ties to [[chip-top-architecture]].

## 2026-06-19 — bb_proc test pipeline + first silicon smoke (beamforming-lms-tracker-intel16-test)
**Worked on:** Built `test_bb_proc` pipeline (run_py_sim→generate_test_data→run_test→verify_test→run_power) for design_jj baseband processor on `psylab_comm`; locked 500MHz clock; ran first on-chip smoke.
**What worked:**
- Clock: RO0 coarse=1/fine=15 + vdd_main=vdd_ro=1.015V → 499.74MHz. `cache/ro_test/ro0_sweep.csv` was STALE (~17% high vs chip today); remapped on-chip (c1f15=490 @1.0V, vdd-trim +1.5% → 500). Reference `Intel_neurosoc_test/ro1_sweep.csv` unusable (flat ~0.19MHz).
- Offline pipeline (8 modules in `src/bb_proc_test/`): config, storage (lossless minimal-int), chip_format (DSU pack/unpack round-trip exact), signals, py_sim (serial GSC/LMS float golden), test_data_gen (parallel), chip_run, CLI. All `python -m` self-checks pass.
- Smoke (bf_mode=0 static, 1 block/16 words, sel 0 y) ran end-to-end DONE_EXIT_0 @500MHz/1.015V; chip produced STRUCTURED non-zero port-B data (set-bits 285-462/word) => cdot datapath computed. Full chain sim→golden→DSU→chip→readback works.
**What failed / learned (saves re-discovery):**
- RPi link (143.215.153.94) VERY flaky — drops every ~1-2min; need background poll-until-reachable before every ssh op. tmux runs persist across drops (launch once, monitor).
- `ScanController.scan_in()` reuses a CACHED vector; staged `set_input_value` ignored unless you call `build_and_scan_in()` (= stage_current_inputs+scan_in). Use build_and_scan_in everywhere.
- `sc_sel_mem_write_buffer` + `sc_bf_mode` are cen_load-latched → changing sel needs a cen_load pulse.
- `BBProc16nmTestCtrl.reset()` toggles ALL rails (would wipe cen_load'd init) → use isolated `ctrl._rstn_dsu.set()` to re-arm DSU only.
- `sc_dsu_pA_r_last` is a 1-cycle pulse; compute is ~150ns vs seconds/scan-poll → poll misses it. Use fixed settle or treat data-present as done.
**Open:** port-B y decode (40b entry layout from `dsu/mem_write_buffer.sv` + cdot pipeline-latency offset) → build in verify.py against golden; verify.py behavioral metrics (MAE/BER/SER/phi/SINR, no plots); run_power (pA_repeat replay + AdaptiveGPSController I/V); continuous re_comp_start + adaptive (gsc/lms) multi-block.
**Key decisions:** golden = float, behavioral-similarity compare (NO bit-exact); lossless storage (int dtype only where already integer); 1 data block = 1 full DSU bank; chip records 1 sel/pass (multi-sel = N passes, re-cen_load + arm per sel).
**Connections:** [[silicon-functional-test-recipe]] [[dsu-architecture]] [[chip-init-sequence]]

## 2026-06-19 (cont) — SILICON SMOKE PASSED, full pipeline validated
**Result:** bf_mode=0 static cdot validated bit-exact on chip @500MHz/1.015V. chip bf_w_out (port-B sel0) == integer MAC of loaded ints, 50/50 lag0. verify.py behavioral: MAE=0.0034, corr=0.99998 vs float golden. Full chain works: sim->golden->DSU->chip->readback->verify->PASS.
**Root-cause fixed:** first smoke gave incoherent y. Cause = DSU bank-A bypass write bit-slip under running RO (8/16 words corrupt round 0). Fix = load_dsu_sram write-verify-retry (readback bankA, re-write mismatched addrs, converged round 4). Bank A now bit-correct -> cdot coherent.
**Port-B sel0 decode (VALIDATED, in chip_format.unpack_portB_y):** 25 entries/word, entry k at bits[40k+39:40k] LSB-first; real=high20 signed, imag=low20 signed; y_float=y_int/2^16. Real design-written words have top-24 padding=0 (use to filter valid vs stale port-B words). pA_r_last is a 1-cycle pulse (poll misses; compute ~150ns); proceed on data, not the flag.
**Open:** chip writes ~50/76 y per block (pipeline latency 6 + partial-word non-fire) - last partial word doesn't fire; verify uses valid run. bit-slip retry is SLOW for 512 words -> gate clock during DSU scan (perf). run_power (pA_repeat replay + AdaptiveGPSController I/V) not built. Other-sel port-B decoders (symbol sel11=psf_out21+psf_out21+sym4, wa, etc.) stubs. continuous re_comp_start + adaptive multi-block.
**Connections:** [[silicon-functional-test-recipe]] [[dsu-architecture]]

## 2026-06-20 (cont) — bf_mode=0 multi-run + sel-switch bug
**Multirun (all 6 static sels x 3 runs):** sel0 (y) REPEATABLE across 3 runs (identical valid words) AND bit-exact (MAE 0.0034, corr 0.99998). => chip deterministic + readback reliable.
**BUG found: sel switching broken** — bf_w/wq/symbol readback == y readback (16/16 identical); every pass records sel0 regardless of sc_sel_mem_write_buffer. RTL: sel_mem_write_buffer_r <= sc_sel_mem_write_buffer on cen_load (baseband_processor.sv:3184). Hypothesis: arm_dsu (rstn_dsu) ran AFTER set_record_sel and reset sel_r to 0 (y wouldn't reveal it since sel0=reset value). FIX (testing): reorder to arm_dsu -> set_record_sel(full re-stage+cen_load) -> run_block, so sel latches AFTER the dsu reset. Also parameterized stage_design_init(sel) (was hardcoded "0000").
**Validated port-B decoders (chip_format):** unpack_portB_y (sel0, bit-exact), unpack_portB_vector (sel1/2 16x12b, sel7/8 16x13b), unpack_portB_symbol (sel11, 54b: psf_re25+psf_im25+sym4, 18/word). wq (7/8) is STALE in static (wq=init, not loaded). bf_w (1/2) fires every sample.
**Reliability:** DSU bypass write+read both bit-slip; load_dsu_sram uses STICKY verify (word verified once it reads correct, sticky) -> converges. SLOW (~5-7min/16-word load); gate clock during scan for 512-word.

## 2026-06-20 (cont) — sel-switch bug LOCALIZED, stuck (needs RTL-designer)
**Confirmed:** scan APPLIES sel correctly (diag_sel.py: chip readback sc_sel_mem_write_buffer=1011, design_jj roundtrip PASS). But recording stays sel0 (y) for every sel.
**RTL paradox:** sel_mem_write_buffer_r <= sc_sel_mem_write_buffer on cen_load (baseband_processor.sv:3182-3184), reset rstn_baseband_processor_r. bf_mode_r same logic (1924-1926). BOTH resets = rstn_sync_w (1899,1901); ALL 4 cen_loads = {4{cen_load_sync_w}} (1920). Weights DO latch (y bit-exact => cen_load works). So by RTL sel_r should latch 11 too — but it doesn't switch the port-B mux. sel_r is internal (not scannable) so can't observe directly. NEEDS chip/RTL-designer insight or invasive debug.
**Tried (no fix):** full re-stage (stage_design_init param'd with sel), reorder arm_dsu->set_record_sel->run_block, separate cen_load pulse. None switch sel_r.
**Hypotheses for next:** (1) symbol/bf_w buffers not firing for SHORT block (76 samp ~20 sym < 22/word) so port-B keeps stale y — but bf_w fires every 5 samp, should write 15 words, yet reads y => points to sel_r not the fire. (2) cen_load synchronizer timing vs sel field. (3) a write-buffer enable I'm missing.
**SOLID this session:** full pipeline built+validated; bf_mode=0 sel0 (y) BIT-EXACT + repeatable x3 @500MHz; bank-A bit-slip fixed (sticky verify). Remaining: sel-switch, then all-sels, then bf_mode 1/2/3 continuous (re_comp_start, port-B pB-address-continuation TBD).

## 2026-06-23 — tsmc28 FPGA bridge compile (bb_proc bring-up)
**Worked on:** Set up + compiled the TE0725 FPGA bridge for the bb_proc 28nm tapeout; cleaned `exec/rpi-sync`.
**What worked:** Reused existing `gen_bridge.py` flow — one source CSV (`csv/bb_proc_bridge.csv`, 20 signals) generates `bridge.sv`/`bridge.xdc`; same CSV also feeds `test_drivers` `create_rpi_ports_from_csv()`, so FPGA + RPi never drift. FMC_DB pins came straight from the package xlsx "FOLC pin num"; all 20 resolved against `mb_db.json`. Built clean on sathe-srv2: WNS +7.5ns, 0 DRC, bit+mcs.
**What failed:** sathe-srv1 stalled ~20 min loading Vivado off NFS (stuck at banner, 0 synth output), left orphaned procs. `pkill -f vivado_sr.tcl` over SSH self-killed the remote shell (pattern in its own cmdline). `> build.log` stayed empty (Vivado logs to vivado.log).
**Key decisions:** SPI on RPi hardware-SPI pins GPIO8-11 (Pull=PU); clk_ext on EXTCLK; slow clocks + rest on spare GPIO (delegated); B34 = LVCMOS18 (--vdd_pst 1.8); no --invert-DB. bridge.sv/xdc stay gitignored (generated); CSV is tracked source.
**Connections:** [[fpga-bridge-compile]] documents the full flow + gotchas; signals trace to [[chip-top-architecture]], [[spi-streaming-protocol]], [[scan-chain-architecture]].
**Open:** Program TE0725 + bench bring-up; write the tsmc28 RPi test controller that consumes the same CSV.

## 2026-07-05
**Worked on:** tsmc28 proper chip init through scan (test_setup_init.py, TB main-flow port with all-external clocks) + run_lfsr_misr.py rewired to the TB TEST_LFSR block; first silicon runs.
**What worked:** Full Steps 0-6 init on silicon (headers-off pi_capture-verified 11x0, clean scan orientation, VDD_CORE_LOW after verify); lfsr_done=1 on every BIST run; stimulus proven against the pre-syn VCD by control-event sequence diff (sim == TB model exactly, 145 events; bench == TB + documented deviations); golden-format writer byte-identical round-trip; 3x repeatable 8332b scan-outs.
**What failed:** MISR signature != golden AND differs on every run (4 runs, 4 signatures, warm or power-cycled) — real on-chip nondeterminism in the bf_w_out wb stream, NOT the scan read path (ruled out) and NOT cycle-count sensitivity (MISR steps per wb fire only).
**Key decisions:** clocks held external for the entire init (4 bypass bits scanned first, never touched; set_clock_ctrl choreography dropped as electrically equivalent); one clock object per pin for the whole process (SclkPin over SpiStream's lgpio for sclk); cycle counts parameterized with TB defaults, bench 30/3000 per spec; headers-on skips PSU ch1.
**Open:** MISR nondeterminism campaign — discriminators: identical-predecessor double runs, longer/double priming, per-phase full-chain capture vs sim VCD (infra ready). Also promote the VCD control-event checker if reused.
**Connections:** [[init-load-external-clock]] ← implemented by test_setup_init; [[ldo-header-engage]] read-back recipe silicon-confirmed in-flow.

## 2026-07-06
**Worked on:** bf_w write-buffer SPI read (wb_1) + probe ladder closing the MISR-nondeterminism root cause.
**What worked:** Sim bf_w track extracted from pre-syn VCD (init loads exact, +/-1-LSB adaptation steps per clk_update tick, golden capture = init+1step); clk_update island-roundtrip proven alive on silicon via clk_o (after fixing the div_en=0 check bug); scan-path MISR fire-counter (read I) as SPI-independent proof.
**What failed:** wb_1/wb_2 capture ZERO entries in every mode (ext scheduled, sync_div, forced-sync) -> update_w (clk_update rise synchronizer -> pulse, core.sv:930-964) never pulses on this die. This freezes all update-gated capture regs (adc->cdot, bf_w step) = the actual source of the per-run-random y words behind the MISR nondeterminism.
**Key decisions:** verdicts always cross-checked through two paths (SPI TX and scan MISR counter) before concluding; physical stress probes (voltage) deferred to user decision.
**Open:** voltage-sensitivity probe on read I; netlist review of the synchronizer block; mode survey to route around update_w.
**Connections:** [[lfsr-misr-power-fmax-test]] ← update_w root cause; [[init-load-external-clock]] unaffected (init itself verified).

## 2026-07-08
**Worked on:** tsmc28 chip 3 IO bring-up completion + vault cleanup after root cause found
**What worked:** rstn_spi D26→D28 bodge fixed ALL SPI failures — full ladder PASS first try (rx_req drop at exactly 2776, miso/tx_ready via in-process --spi-tx-check). Chip IO fully verified except mosi.
**What failed:** Weeks of "chip broken" theories were bench artifacts — rx_req-drop detector invalid while dead rstn_spi held slave in reset; stale SPI-flash bitstream faked clk_ext deaths; powercard init zeroed VDD_TEST during diagnosis.
**Key decisions:** Retired bogus fault maps (chip #1/#2 SPI verdicts, FMC→DB condemnation); consolidated debug arc into [[chip-io-bringup-results]] + [[rstn-spi-d28-remap]], deleted spi-pads-debug-status.md, rewrote working-context to current state.
**Open:** mosi verification; deterministic LFSR/MISR golden mismatch on chip 3 (design-test); uncommitted bench code held per user.
**Connections:** [[rstn-spi-d28-remap]] ← [[chip-io-bringup-results]] one dead trace invalidated every downstream SPI diagnosis
