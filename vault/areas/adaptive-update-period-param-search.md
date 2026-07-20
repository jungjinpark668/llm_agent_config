---
date: 2026-07-19
tags: [beamforming, lms-tracking, dsp, methodology]
type: concept
status: active
---

# Adaptive update-period parameter search (methodology)

How to find velocity-filter + period-controller parameters for the GSC/LMS
tracker chip family quickly when the sim configuration (beam dynamics, Eb/N0)
changes. Calibrated by the 2026-07 test002 campaign (~2,600 full 2.3M-sample
runs, 2,126 exact-BER configs); the driver amortizes that cost to roughly an
evening per new config.

Driver: `scripts/test_design/test_gsc_and_lms_track/find_t_ctrl_params.py`
(stages 0-4, resume-safe, emits recommendation.json).

## Stage 0 -- analytic sizing (no sim)

From the trajectory spec alone:
- velocity LSB = phi_incr / 256 / T_upd (deg/s). Scaling is measurable only
  if v_max > ~2 LSB; otherwise stop.
- CIC ratio R: largest power of 2 with velocity-sample rate >= 100x
  trajectory bandwidth, warm-up 16R < 10% of run, AND group delay 7.5R ticks
  < 1% of trajectory period. The lag constraint is what picks R=128 over
  R=256: the controller consumes the raw estimate, so delay becomes bias.
- FIR: 13-tap moving average, always (max smoothing wins whenever the rate
  condition holds; taps are hardware-fixed).
- stop_max from acceleration blindness: a_max (P dt)^2 / phi_incr <
  search_bound -> P_max = sqrt(bound * phi_incr / a_max) / dt. On test002
  this gives 22,841 samples >> the 200 cap -- predicted (and observed) the
  cap inert there. On slow realistic dynamics the bound shrinks and becomes
  the dominant safety knob.

## Stage 1 -- calibration (one adapt-off proxy run, ~1 min)

Velocity-chain accuracy vs true phi_dot, and |v| percentiles -> data-driven
del_phi_ref grid for PI.

## Stage 2 -- proxy sweep (~1 h)

Update-skip loop (beamforming() is stateless between updates -> ~30 s per
full-length combo). Grids are class-reduced, not blind:
- PI kp/ki collapse into few behavior classes via delta = floor(kp*e/2^20);
  clamps >= 2 are non-binding when v codes are small. ki=0 (pure
  accumulate-P = integrator on velocity error) is the natural config.
- Step refs {(2,1),(2,2),(3,3),(4,4),(5,4),(3,5),(4,5)}, steps 4-12 / 5-20.

## Stage 3 -- exact BER only near the front (~1-3 h)

Proxies (phi RMS, SINR) rank coarsely but MISORDER the knee -- proven twice:
a step config predicted ~2x BER measured 5.4x; PI configs predicted ~1x
measured 0.13x (better than baseline). Full-demod runs for the proxy front +
step-1 ring + audit sample only.

## Stage 4 -- diagnostics gate (what makes it a method)

1. Neighbor smoothness: |dlog10 BER| distribution between step-1 neighbors.
2. Audit: random combos in the dominated region must stay dominated.
3. Boundary: every winner's unit neighbors measured and worse (expand+rerun
   otherwise -- triggered once in the campaign, 8 combos, all worse).
4. PI class enumeration: fine grid covers all distinct behaviors.

## Transferable findings (test002, 200 Hz sine, Eb/N0 6 dB)

- Combined front: PI owns 0-25% saving (BER down to 0.12x baseline -- smooth
  +/-2 period modulation cuts LMS gradient noise near velocity zero); step
  mode owns 25-43%; BER cliff past ~45% (re-engage lag during the velocity
  ramp, NOT the stop_max cap).
- Failure mechanism at high saving: slow dn-side re-engage, bursts of symbol
  errors after the velocity-zero point. Governed by dn_ref/dn_step.
- BER rows < 1e-5 rest on < 50 error events; judge by neighbor consistency.

Related: [[gsc-lms-track-datapath]], [[2026-07-19-update-period-scaling-campaign]]

## v2 recipe: from-scratch parameter search on a NEW signal condition (2026-07-20)

Validated on test002 (~2,600 exact-BER runs). Stages, cheapest first:

**Stage 0 — analytic walls (no sim, one numpy pass over the trajectory):**
1. bins_per_sample(t) = |phi_dot(t)|·dt/phi_inc. Get v_peak_bins.
2. Silicon walls: T_search = 0.5·B/v_peak_bins (B = 4, lms_track.sv:80,
   50% transient margin); T_wrap = 7/v_peak_bins (4-bit ind_dot); accel
   bound sqrt(2·budget/(phi_ddot·tau^2)), tau = 4.75·R·T.
3. SNR wall: gb_opt from misadjustment (anchors: 0.012 @ 6 dB, 0.1-0.2 @
   40 dB; 1-D probe if between). ref_max = budget_bins·gb/(1-gb),
   budget = 0.35 deg/phi_inc.
4. Ceiling curve: saving(ref) = 1 - E[T_base/clip(ref/bins_per_sample,
   T_min, T_max)]. If ceiling at ref_max is not worth it, STOP (feature
   off for this condition).
5. R from staleness: largest power-of-2 R with 4.75·R·T_max < 3% of the
   trajectory quarter-period (bigger R = cleaner velocity; ma13 fixed).

**Stage 1 — calibration (3 short runs):** baseline metrics + codebook pick
histogram (confirms gamma*P scale) + vel_meas_corr (chain sanity).

**Stage 2 — coarse (10-20 full runs):** ref ladder around 60-80% of
ref_max x gb {anchor/1.5, anchor, anchor·1.5}. Fixed: kp = 6.0,
ki = kp·1.6e-4 (reference-validated ratio), clamps +pm/-4·pm with pm from
slew: reach T_max within a quarter of the envelope timescale.

**Stage 3 — fine (20-40 runs):** ref step 4 codes, gb step ~0.002, kp
{6,7,8}, ki {1..16} joint at the winner. Expect a flat plateau; pm/pn/smax
usually inert when the equilibrium is interior.

**Stage 4 — MANDATORY validation:** >= 3 seeds on top-3 (test002 lesson:
4-of-4 single-seed sub-baseline BER wins were flukes; savings are the
robust statistic, PI savings deterministic, step-mode savings fragile).
Trace plot with measured-velocity overlay; ceiling-efficiency check
(measured/ideal >= 70%, else controller problem, not parameters).

Encode-ready for find_t_ctrl_params.py (stages 0-1 already there; walls
2-3 and the seed rule are the v2 additions).
