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
**Connections:** [[ro-usage-guide]] ← [[ro-full-characterization]] (usage recipes built on the characterization data); closes the "clk_main_div_o measurement instrument" open item from [[silicon-functional-test-recipe]] (34410A works within 3 Hz-300 kHz via the divider).

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

## 2026-07-09/10
**Worked on:** tsmc28 SPI streaming campaign: test-1 closure, corruption root-cause, fmax, t2a.
**What worked:** Designer's debug doctrine (chip-never-wrong, predict-first from RTL/apr.v/TB, transcribe-don't-invent). Selector-weight readback (cdot as byte echo) turned inference into measurement. Region-0 rotation closed test 1 at 1420/1420 bit-exact on errata silicon. Mixed-speed fills (slow readback fill after tx_ready) got fmax past the bridge's 1 MHz return-path ceiling: bench-chain fmax @1.0 V = 3.5 MHz. Three-stage archive diff (rtl/post-syn/post-apr) pinned the corruption to APR; PT signoff shows exactly one violation: clk_gate_read_serializer_data_r_reg/E setup -11 ps.
**What failed:** Five of my mechanism theories (wire warm-up, weight drift, held-through-fill disturb, runt capture, MISR-invariance fmax — killed by the 0.5% nondeterministic bit floor). Bus-grouped vars in the flat gate-level VCD are phantoms (all-zero/x shadows) — per-bit scalar nets required.
**Key decisions:** No re-tapeout: region-0 rotation for bit-exact tests; zero-stuffed + manual clk_update_ext ticks methodology for GSC/LMS performance (vault-noted); t2b design pends meta-corruption measurement.
**Open:** Silicon kHz eater's physical mechanism (deep VCD analysis in progress, per-bit extraction v3); t2b meta decision; bridge forward/return bandwidth as system ceiling.
**Connections:** [[spi-streaming-protocol]] ← [[lfsr-misr-power-fmax-test]] (region-0 erratum shapes the fmax method).

## 2026-07-10
**Worked on:** tsmc28 bench — loadline closure, chip-io validation, weight-path corruption law + software fixes (beamforming-lms-tracker-tsmc28-test)
**What worked:** 341-loop sustained-streaming loadline (VDD_TEST 1.003 V, no droop; designer chose no trim). Probe-free chip-io 4/4 after root-causing missing scan_out pad enables (A/B diag on silicon: bare reads zeros, +enable_scan_out_pads reads seed bit-exact). Weight probe invented: wb taps + misr-bypass SCAN readback (erratum-free) + streamer-driven clk_update_ext ticks — mapped the full meta/weight corruption law (pure 1->0, per-chunk severity; chunk1 pure neighbor law 4/4 stimuli exact; chunk0 hardwired position mask; chunk2 MSB-side position-fixed + LSB flake; chunk3 nondeterministic run-erosion). Consumed-path proof: 803/803 cdot inputs == law(sent). Fixes verified on silicon: held-out prediction 100.000% bits chunks 0/1; run>=2 encoding 704/706 bit-exact.
**What failed:** self-indexing stimulus (index bits corrupt like payload); s&~(s>>1) boolean model for chunk 3 (position/stochastic instead); unit +1 adc dies chunks 1-3 (isolated bit — but that failure re-proved the adc law and explained wb_0 sparsity).
**Key decisions:** identification by global best-match over random 384b weights (margin-gated); ambiguous pile turned out to be chunk-3 captures — structured stimuli unlocked them. Chunk 3 declared unusable weight channel; GSC/LMS plan unaffected (scan weights).
**Open:** wb_2 upper-meta probe + adc=3 consumed-path extension (proposed, user-gated); commits pending; chunk-2 LSB flake = only nondeterminism.
**Connections:** [[spi-streaming-protocol]] ← [[scan-chain-architecture]] (misr-bypass scan readback as the erratum-free observation channel — same trick fixed chip-io and enabled the weight probe)

## 2026-07-11
**Worked on:** tsmc28 LFSR power characterization + GSC clk_update debug ladder (beamforming-lms-tracker-tsmc28-test)
**What worked:** test_lfsr.py power mode (tuned-rail LFSR runs, kill-safe); bitbang->sync_div->syn_ro staircase in check_clk_update.py; wb_1 read via misr_bypass + parked ext-clock scans (free-running freeze reads zero — must park deterministically)
**What failed:** misr-bypass read under free-running syn_ro (bus zero between handshakes); pkill -f matched tmux wrapper (killed session hard — kill python pid only); sc_lfsr_done scan reads spurious vs live 2 GHz clock
**Key decisions:** stop_code=0 for infinite LFSR (unreachable from nonzero seed); Keithley = tied-rail convergence criterion (powercard +44..83 mV load-dependent probe offset); skew guard 50 mV warn / 100 mV abort
**Results:** GSC weight-update ceiling 941-1054 MHz @1.0 V; full-compute @941 MHz = 50.6/179.9 mA (~230 mW); LFSR-only @2.09 GHz = 5.6/78.7 mA; designer: matches PT report
**Open:** 1054-1388 MHz readout wedge; VDD_TEST lockstep +83 mV under load
**Connections:** [[lfsr-misr-power-fmax-test]] ← [[clk-update-counter-stop-latch-bringup]] (load_buf-on-internal-clock class of bugs guided the debug)

## 2026-07-12
**Worked on:** Rebuilt gsc_and_lms_track test family (run_py_sim + generate_test_data + plot CLI) on psylab_comm; full test001 run + chip vector generation.
**What worked:** Per-sample loop parity carried over cleanly (counters −1, phi-after-sample, noise-in-stream/gain0); scan-init vectors bit-exact vs as-taped-out case_3; 12.9k samp/s → 181 s full sim; npz+downcast cache 101 MB.
**What failed:** `from psylab_test_infra.utils import ...` breaks on macOS (package __init__ imports smbus2) — file-path import of logging_utils instead. code-explore agent type unavailable this session (code-context.md still pending).
**Key decisions:** py_sim npz cache is THE golden (no golden_*.txt); single-file case registry `test<NNN>` + params.json dump; Makevar as-built sizes pinned in TestVars defaults; PI-ctrl/scale-shift vectors skipped.
**Open:** run_test/verify_test stubs; user review of test001 plots; chip-side bb_data demod scaling to confirm at verify_test.
**Connections:** [[gsc-lms-track-test-family]] ← [[gsc-lms-track-datapath]] (as-built widths drove params)

## 2026-07-15
**Worked on:** GSC/LMS tracker "freeze" root-cause + full 200k three-pass chip validation (beamforming-lms-tracker-tsmc28-test)
**What worked:** Evidence-chain debugging: scan-disturbance discriminator (identical spans killed the hypothesis) -> py-golden comparison (chip matches py at 2k; py itself hovers early) -> readback-latch analysis (identical words at rise 6 vs final = completion-latched register) -> 20k horizon test (py climbs +89, chip pinned) -> cache-window floor arithmetic (39124 = init-16) -> missing poly-coeff files. 12 constants fixed everything. Then: 4x200k passes all 0 rx_req failures; per-word drift-tracked decoding beat every global-alignment scheme.
**What failed:** (1) My "tracker frozen" verdict from single kill-peek snapshots — completion-latched register shows stale words, one word behind. (2) "est-mode-only" assumption zeroing poly coeffs at bring-up — never re-audited when task became tracking. (3) Global head-offset wb_0 alignment under sparse scans (gapped words); tag-law constant-origin model (origin drifts ~1.6 samples/word from wb handoff gap); tx-sequence alignment of wb_3 decisions (transitional-slot flicker = no statistical power). (4) jsonl-buffered-in-RAM intermediate results (user needed live files — line-buffered jsonl added).
**Key decisions:** Zero-fill policy tightened: any load_init consumer not explicitly user-authorized as zero must be raised, not assumed inactive. Scan misr-bypass kept as readback channel (user-approved; MISO region-0 deferred to 2.3M-scale runs). Chip-native BER reported as Q-model estimate from measured instant EVM (1.4e-2) with transport-limit caveat rather than pretending sequence alignment worked.
**Open:** bit-exact bb/PSF model (corr 0.55 — structure wrong somewhere); preamble-embedded test vectors for absolute symbol sync; full 2.3M-sample run; MISO region-0 mass readback for wb_0 at scale.
**Connections:** [[gsc-lms-track-test-family]] <- [[spi-streaming-protocol]] (wb handoff gap = same serializer enable-gap as wb_1 chunk-3 law)

## 2026-07-18
**Worked on:** beamforming-lms-tracker-tsmc28-test — alpha sweep validation + silicon re-run (test002)
**What worked:** Quantized-rx replication proved sim==chip (chip EVM 21.5% inside sim phase band 20.4-28.6%); 54-combo full-2.3M alpha sweep found aw 2^-15 optimum (BER 3.9x); per-case scan-shift override (load_init.opt_int) let test002 reuse test001 vectors byte-identical; full 2.3M silicon pass clean (0 rx_req failures, capture counts == test001).
**What failed:** opt_int first assumed Path, crashed on VectorDir (fixed: VectorDir.__truediv__ returns Path). Sym-run-middle EVM selector broke on test002 — chip decim phase landed low-energy this restart, 100% inner decisions; selector picks off-phase instants. Use per-word phase-locked selection cross-run.
**Key decisions:** Chosen setting at=2^-4/aw=2^-15 (robustness over absolute-BER winner 2^-3); wb_3 declared transport-limited for alpha comparison — wb_0/wb_1 SINR pass is the silicon observable.
**Open:** wb_0/wb_1 pass at new alphas to show SINR gain on silicon (not yet requested).
**Connections:** [[alpha-sweep-optimum]] ← [[gsc-lms-track-test-family]] (transport ISI floor masks dense-domain gains)

## 2026-07-19
**Worked on:** Update-period scaling campaign (beamforming-lms-tracker-tsmc28-test): quantized velocity chain + controllers, ~2,600 full-run sweep with exact BER, methodology driver.
**What worked:** Update-skip proxy loop (stateless beamforming) for 30 s full-length runs; two-stage coarse->fine with diagnostics gate; PI ki=0 hypothesis (accumulate-P = velocity-error integrator) confirmed -- PI beats baseline BER up to 25% saving; analytic stage-0 formulas reproduce empirical R choice and stop_max inertness.
**What failed:** Proxy metrics (phi RMS/SINR) misordered the BER knee twice (step D 5.4x surprise, PI 0.13x surprise) -- exact BER is mandatory near the front. Coarse PI grid missed ki=0 entirely.
**Key decisions:** R=128 + ma13 velocity chain (raw-lag argument); two-stage search with boundary-expansion rule (triggered once, 8 combos, all worse); stop_max sweep skipped after data showed cap never binds on this trajectory.
**Open:** Operating-point pick (user), test003 + chip vectors, variable-tick chip streaming mechanics.
**Connections:** [[adaptive-update-period-param-search]] <- [[update-period-scaling-campaign]] (methodology distilled from campaign)
