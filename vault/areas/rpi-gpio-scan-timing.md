---
date: 2026-06-15
tags: [raspberry-pi, gpio, scan-chain, timing, test-infra]
type: concept
status: active
---

# RPi GPIO scan timing (keyword: rpi-gpio-scan-timing)

The default scan pulse timing for Raspberry-Pi-hosted scan chains, and why it is
what it is. This is the `PulseConfig` default in
`psylab_test_infra/scan/controller.py`; the realization lives in
`scan/io/protocol.py` `_sleep`. Discovered while speeding up the DSU memory test
([[dsu-mem-scan-test]]).

## The problem: time.sleep floors at ~60 us on the Pi

Measured on the RPi (`time.perf_counter_ns` around 2000 calls each):

| delay mechanism | requested | actual per call |
|---|---|---|
| `time.sleep` | 50 ns | ~60,800 ns |
| `time.sleep` | 100 ns | ~61,900 ns |
| `time.sleep` | 1 us | ~61,400 ns |
| `time.sleep` | 10 us | ~72,700 ns |
| busy-wait (perf_counter spin) | 50–500 ns | ~2,540 ns |

`time.sleep()` cannot resolve anything under ~10 us — every sub-floor request
costs ~61 us. With four phi/phi_bar edges per scanned bit, that is ~244 us/bit of
pure delay, which dominated scan time (a 16,609-bit chain shift was ~4.5 s).

## The fix: busy-wait for sub-millisecond delays

`_sleep` busy-waits (spins on `perf_counter_ns`) for any delay under 1 ms, and
falls back to `time.sleep` for longer waits. A short pulse then costs ~2.5 us (the
`perf_counter` call floor) instead of ~61 us — ~24x cheaper, still ~250x the
chip's 10 ns / 1 ns pulse minimums, and an explicit guaranteed hold (not left to
implicit GPIO latency). This applies to every scan caller automatically.

## The default (rpi-gpio-scan-timing)

`PulseConfig` defaults: `pulse_width=1 us`, `non_overlap=500 ns`,
`update_off_delay=1 us`, `capture_off_delay=1 us`. These are nominal minimums; the
realized width is the ~2.5 us busy-wait floor. Values below 1 ms all realize the
same ~2.5 us, so the exact numbers are documentary — the busy-wait is the actual
lever. Override per controller via the `pulse` arg only if a chip needs wider
pulses.

## What this does and does not fix

Real but modest: ~1.5–1.7x overall, not the ~6x a naive sleep-only model predicts.
Removing the sleep floor exposed the next bottleneck — the gpiozero `.on()/.off()`
calls themselves cost ~40 us each, and those now dominate a bit shift. Pulse
timing cannot beat that; the only further lever is the GPIO path itself (hardware
SPI, batched/DMA GPIO, or a C helper). So this default is the optimal *timing*
config; deeper speedups are a separate hardware-path effort.

Links: [[dsu-mem-scan-test]]
