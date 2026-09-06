# `anc_fx_lms_tm_core` interface and cycle contract

Date: 2026-09-05  
Source: `rtl/anc_fx_lms_tm_core.sv` (additive alternative; it is not instantiated by `anc_top`).

## Scope and fixed boundary

- This is an independent, resource-controlled time-multiplexed FxLMS datapath.
- The supported configuration is **exactly `TAPS=128`**. The parameter is retained for array sizing/reset loops; the 7-bit address and tap counters are intentionally fixed to 128 entries. Other values are not a supported contract.
- The secondary path is the documented bounded identity approximation. This is an algorithm/model boundary, not a measured acoustic secondary path.
- One syntactic signed 40x40 multiplier datapath is selected by state and reused by FIR, gradient, and coefficient-update phases. A synthesis report is still required to establish the actual mapped resource count.

## Port contract

| Signal | Meaning |
|---|---|
| `rst` | Synchronous, active-high reset sampled on `posedge clk`. Reset clears state, coefficients, history, outputs, counters, and flags. While asserted, `sample_ready`, `coeff_wr_ready`, and `busy` are all low. |
| `sample_valid` | Pulse/request. It is accepted only when the pre-edge state is `ST_IDLE` and reset is inactive. A request while busy is dropped and increments saturating `overrun_count`; `overrun` latches high. |
| `enable` | Enables the FIR/update path. If low and `bypass=0`, an accepted sample emits zero anti-noise and does not enter the time-multiplexed path. |
| `bypass` | Accepted sample emits `ref_sample` immediately, copies `error_sample` to `residual_sample`, and does not update coefficients. It has priority over `enable`. |
| `ref_sample` | Signed 24-bit Q15 reference/input sample. Captured into circular history on every accepted sample. |
| `error_sample` | Signed 24-bit Q15 error/residual sample; captured for the active transaction and returned as `residual_sample`. |
| `mu_q15` | Signed 16-bit Q15 adaptation step; captured at acceptance and used in the single `ST_GRAD` multiply. |
| `coeff_wr_en`, `coeff_wr_addr`, `coeff_wr_data` | Idle-only signed 16-bit coefficient write. `coeff_wr_ready` is high exactly when idle and reset is inactive. A write concurrent with an accepted sample is legal and visible to FIR tap 0. |
| `sample_ready` | Combinational `(state == ST_IDLE) && !rst`; it is a level, not a reservation. A sample request should be sent only when it is high. |
| `busy` | Combinational `(state != ST_IDLE) && !rst`. It remains high during FIR, gradient, and delta phases, including the cycle in which `sample_out_valid` pulses. |
| `sample_out_valid` | One-clock pulse for an accepted sample. Bypass/disabled samples pulse at their acceptance edge; enabled samples pulse at the final FIR edge, before the 129 coefficient-update clocks finish. |
| `anti_noise_sample` | Signed 24-bit output. Bypass returns reference; disabled returns zero; enabled FIR result is saturated to signed 24 bits. |
| `residual_sample` | Captured `error_sample` associated with the accepted transaction. |
| `sample_count` | Saturating 32-bit count of accepted sample requests, including bypass and disabled requests; busy-time requests do not count. |
| `clip_count` | Saturating 32-bit count of enabled FIR results whose pre-saturation Q15 output is outside the signed 24-bit range. |

## Schedule and latency

For an enabled, non-bypass sample accepted at edge `E0` while idle:

| Edge relative to acceptance | Pre-edge state/action | Result |
|---:|---|---|
| `E0` | `ST_IDLE` captures inputs/history and enters `ST_FIR` | `sample_count++`; no output pulse |
| `E1..E128` | `ST_FIR`, taps 0..127 | At `E128`, output pulses using the final accumulator result and state enters `ST_GRAD` |
| `E129` | `ST_GRAD` | Computes `gradient_q15 = (mu * error) >>> 15`; enters `ST_DELTA` |
| `E130..E257` | `ST_DELTA`, taps 0..127 | Updates coefficients when enabled and not bypass; at `E257` returns to `ST_IDLE` |

Therefore the enabled transaction occupies **257 clocks until ready returns** and uses **257 active phase clocks after the acceptance edge**. At 100 MHz and 16 kHz, the budget is 6250 clocks/sample; the nominal schedule leaves 5993 clocks of budget. This is a cycle budget, not a timing-closure claim.

## Fixed-point equations

All operands are explicitly sign-extended before the shared multiply. Arithmetic right shift is used; negative values therefore round toward negative infinity.

- FIR accumulator: `fir_acc_next = fir_acc + signed(coeff[tap]) * signed(tap_value)`.
- FIR output before saturation: `fir_output_wide = fir_acc_next >>> 15`.
- Gradient: `gradient_q15 = (signed(mu_q15) * signed(error_sample)) >>> 15`.
- Coefficient delta: `delta = (gradient_q15 * signed(tap_value)) >>> 15`.
- Update: `coeff[tap] = sat16(signed(coeff[tap]) + delta)`.
- Enabled FIR output: `anti_noise_sample = sat24(fir_output_wide)`.
- `tap_value` is `ref_reg` for tap 0; for taps 1..127 it is `x_hist[(sample_ptr - tap) mod 128]`, where `sample_ptr` is the location written by the current transaction.

Saturation limits are signed 16-bit `[-32768, 32767]`, signed 24-bit `[-8388608, 8388607]`, and unsigned 32-bit counters `[0, 0xffffffff]`.

## Verification and non-claims

The companion `scripts/tm_fx_lms_cycle_model.py` is an independent integer model of these equations and state transitions. Local Icarus/Python evidence can establish syntax and model behavior only. It does not establish Vivado utilization/timing closure, implementation/bitstream, exact XDC pins, board/codec operation, end-to-end latency, or acoustic A/B performance.
