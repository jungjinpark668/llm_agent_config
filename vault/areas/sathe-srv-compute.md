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
- Monitor remote fleets with ssh until-loops on the tmux session/log
  (per server-task rules), not sleep-polling; watchers wake on
  `+N [job` lines or `rc=[1-9]`.

Related: [[fpga-bridge-compile]] (Vivado on the same hosts, tmux/pkill
lessons), [[vault-concurrency]].
