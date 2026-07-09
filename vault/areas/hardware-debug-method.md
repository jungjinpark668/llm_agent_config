---
date: 2026-07-09
tags: [debugging, methodology, hardware, bench]
type: concept
status: active
---

# Hardware debug method — general rules

General doctrine for debugging any silicon/bench/hardware test, in any
project. Not case-specific.

## The standing assumption

**The chip (DUT) is never wrong. If something is wrong, it's your code** —
the test program, the golden model, or the stimulus schedule. Debug starts
from that assumption and only abandons it when a cycle-accurate predicted
timeline provably diverges from measurement.

## No guessing — derive from references

There are always references: RTL, gate-level netlist (apr.v), simulation
waveforms, the testbench. Chip behavior is derivable **cycle by cycle,
clock edge by clock edge**. Guessed theories (noise, drift, warm-up, marginal
wires) are forbidden until the derived expectation fails.

## Predict first, then debug

Set the model before touching the bench: "if I toggle this signal, the state
becomes S1; then if I toggle that, I expect S2." Write the expected timeline
down, then diff the measurement against it. A debug session without a
predicted timeline is guessing.

## Supporting rules

- **Staging vs commit**: scan-in / config writes only STAGE values; a domain
  clock edge COMMITS them into the datapath. Every clocked config target
  needs its commit edge before the test runs — check this first on any
  head-of-run mismatch.
- **Mismatch shape triage**: split exact / near-miss / garbage before
  counting anything. Near-miss (small structured deltas, correlated with
  golden) ⇒ wrong golden-model input (init state, commit timing, enables).
  Garbage ⇒ protocol/path. Mixed ⇒ two problems; never one classifier bucket.
- **Self-healing theories are wrong**: if a theory needs broken state to fix
  itself, the state was never broken — find the EVENT at the boundary
  (a clock tick, a reload, a mode change).
- **Fit discipline**: no conclusions from underdetermined fits; check
  equations vs unknowns before calling a residual "evidence".
- **One consistency check kills a theory**: before building a probe program,
  ask "what already-observed correct value would be impossible if this theory
  were true?"

Case study that produced these rules: [[2026-07-09-weight-commit-debug-postmortem]].
