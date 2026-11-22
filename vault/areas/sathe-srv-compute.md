---
date: 2026-07-21
tags: [compute, server, sathe, parallel-sims, job-scheduling]
type: concept
status: active
---

# Sathe server compute (sim offload)

How to run large parallel Python sim sweeps on the GT sathe servers. Established
2026-07-21 offloading the beamforming 80 MHz alpha campaign; generalizes to any
single-core job fleet. Vivado-specific usage lives in [[fpga-bridge-compile]].

## Hosts

- `sathe-srv1.ece.gatech.edu` / `sathe-srv2.ece.gatech.edu`, user `jpark3066`
  (ssh config has aliases; srv2 uses `~/.ssh/id_sathe_srv2`).
- **USER RULE (2026-07-22): compute jobs run on srv1 ONLY. Never launch on
  srv2 without the user explicitly naming srv2 — server choice is the
  user's, even when srv1 is loaded and srv2 looks free.** Also cap
  concurrent sims at the user-stated pool (16 as of this writing).
- Both: 128 cores, RHEL 8.10. srv1 was idle (load 0.3), srv2 lightly used.
  RAM not measured. Every ssh prints a 14-line GT banner — filter it when
  parsing remote output (`grep -v` on banner phrases).
- `/usr/bin/python3.11` and `3.12` exist; system `python3` is 3.6 (too old).
- Storage: `$HOME=/nethome/jpark3066` (NFS, shared across both servers).
  `~/psylab` is a symlink to `/home/sathe/usr/jpark` (22 TB shared research
  mount, ~600 GB free). **Project convention: code goes under
  `~/psylab/<repo-name>`, NOT plain `$HOME`.** Local disk: srv1 `/` 24 GB
  free; srv2 has a roomy nvme (~780 GB).

## Tooling (beamforming_lms_tracker_tsmc28_test)

`exec/sathe-srv-sync <srv1|srv2> <action>` — modeled on psylab_comm's
`sync_server.sh`, generalized:

- `push` — rsync `src/ scripts/ exec/` (excl. FPGA submodule) + the
  as-taped-out `reference/28nm_tapeout/{array_manifold,Makevar}` (326 MB;
  never the 191 GB tapeout DB).
- `setup` — `python3.12 -m venv venv-linux` + deps. Full dep set:
  `numpy scipy matplotlib tabulate pylfsr tqdm requests sgp4`
  (`psylab_comm.satellite` imports requests/sgp4 at package-import time —
  missing them kills any import of psylab_comm).
- `put <local> [rel]` — upload anything to a repo-relative path.
- `run <name> <cmd...>` — arbitrary command in detached tmux `bf_<name>`,
  cwd = repo root, `venv-linux/bin` first on PATH (plain `python x.py` uses
  the venv), BLAS pinned (`OMP/MKL/OPENBLAS/NUMEXPR_NUM_THREADS=1`,
  essential at pool 16+), output tees to `log/bf_<name>.log` (truncated per
  run — `tee -a` on a stale log used to retrigger error greps).
- `pull` — rsync remote `cache/` to a stage dir, then MERGE: appends only
  new `results.jsonl` lines, copies other files only if absent locally.
  Never clobbers local rows.
- `status` / `attach <session>` / `kill <session>`.

Job fleets: `run_jobs.py <jobs_file> --pool N` — one argument line per
`sweep_alpha_tiers.py` invocation, ThreadPoolExecutor keeps N slots full,
survives individual job failures, prints `[job i/N rc=..]` lines (the thing
watchers grep). Exists because BSD/remote `xargs -I` has a 255-byte
replacement limit. Result rows carry a `host` field for provenance.

## Calibration (srv1, single core)

- 110k-sample quarter-window run (200 Hz tier): ~56 s ≈ Mac M-series parity.
- 0.2 Hz quarter window (110M samples): ~15 h.
- MWE gate before fleets: one 200 Hz combo, must pass < 3 min.

## Gotchas (cost real time)

- **pkill misses pool children.** Killing the driver by cmdline pattern
  orphans its ProcessPoolExecutor workers (`python -c from multiprocessing…`)
  to PPID 1; they burn CPU for hours and their results are unwritable (the
  dead parent owned results.jsonl). Kill by PPID==1 + `multiproc` filter, or
  the whole process group. Bit us twice (34 orphans on the Mac).
- **Cross-platform float drift.** Same seed is NOT bit-identical between
  Mac/ARM and srv1/x86 (BLAS reduction order feeds the adaptive loop, which
  amplifies LSB diffs; observed ~1% EVM shift on an identical combo). Keep
  any ranking/grid single-platform; the `host` row field tracks provenance.
- **BLAS thread pinning is NOT server-only.** The server REMOTE_ENV pins
  OMP/MKL/OPENBLAS/NUMEXPR/VECLIB_NUM_THREADS=1; running `run_job_pool.py`
  LOCALLY on the Mac without the same env let each numpy sim spawn many BLAS
  threads → 14 sims drove load to 95+ (near hang). Always prefix local pools
  with the same `OMP_NUM_THREADS=1 ...` env. Verify: 1 core per sim ≈ 100%
  CPU each; if python CPU >> pool×100%, threads aren't pinned.
- Monitor remote fleets with ssh until-loops on the tmux session/log
  (per server-task rules), not sleep-polling; watchers wake on
  `+N [job` lines or `rc=[1-9]`.

## HSPICE runs (measured 2026-11-22)

Source: the hive_2026 SPICE clock tree runs on sathe-srv2, HSPICE X-2025.06-SP1, netlists of
22 to 34 thousand MOSFETs and 290 to 476 thousand nodes ([[2026-11-22-spice-clock-tree-phase1-results]]).

- `hspice -mp N` uses N + 1 cores. Each of the N workers takes one core at `-mt 1`, and the
  master process keeps one more core busy for the whole run (ps showed 95 % lifetime CPU on the
  master). Count N + 1 against a core limit.
- More threads per process (`-mt`) gave almost no speed-up: 340 s at 4 threads against 451 to
  503 s at 1 thread for the same deck. Run 1 thread per case and many cases in parallel.
- With `-mp` and more `.ALTER` cases than workers, only the first case of each worker has a
  measure file (`<out>/<deck>_dp/worker<N>/<deck>.mt<k>.csv`) while the job runs. All measure
  files appear at the top of the `-o` folder when the job ends.
- Stopping a `-mp` job: `tmux send-keys -t <session> C-c`. All its processes end within
  30 s and the finished cases keep their measure files in the worker folders.
- `.OPTION PUTMEAS = 0` keeps the measured nodes out of the waveform file (about 1 GB down to
  4 MB per case with 17,729 measured nodes). The measure files do not change.
- Each case also writes an `.ic<k>` file, about 30 MB for a netlist of 476 thousand nodes.
- Each run checks out 2 hspice tokens.

Related: [[fpga-bridge-compile]] (Vivado on the same hosts, tmux/pkill
lessons), [[vault-concurrency]].
