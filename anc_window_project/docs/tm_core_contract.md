# Time-Multiplexed FxLMS Core Contract

## Scope

`rtl/anc_fx_lms_tm_core.sv` is an independent alternative to the existing
`anc_fx_lms_core.sv`. It is not instantiated by `anc_top` and does not replace
or modify the existing datapath. The supported configuration is `TAPS=128`.

The core is a bounded Q15 MVP. Audio/reference/error containers are signed
24-bit values with 15 fractional bits. Coefficients and `mu_q15` are signed
16-bit Q15 values. The secondary path is the identity approximation; no
measured secondary-path FIR is included.

## Handshake and ownership

* `sample_valid` is a one-clock request pulse. A request is accepted only when
  `sample_ready=1` (the core is idle). There is no input FIFO.
* `sample_ready` is high only in `ST_IDLE` and low during reset. `busy` is the
  inverse processing state, low for immediate bypass/disabled transfers.
* A `sample_valid` observed while `busy=1` is dropped, increments saturating
  `overrun_count`, and latches `overrun=1`. Software must wait for
  `sample_ready` before issuing the next request.
* `sample_out_valid` is a one-clock pulse. For an accepted enabled,
  non-bypass sample, it accompanies the FIR result before coefficient updates
  finish. `anti_noise_sample` and `residual_sample` remain stable until the
  next valid result.
* `coeff_wr_en` is accepted only with `coeff_wr_ready=1`. The 7-bit address
  spans all entries 0..127. A write while busy is ignored; software must hold
  the request until `coeff_wr_ready`.
* Reset is synchronous, clears coefficients/history/counters/outputs, and
  returns to idle. `bypass` has priority over `enable`; bypass outputs the
  reference sample immediately and does not adapt. Disabled non-bypass mode
  outputs zero immediately and does not adapt. Accepted samples still advance
  the circular reference history.

## Fixed-point operations

For each FIR tap, the shared multiplier forms an explicitly signed product:

`product = signed(coeff_q15) * signed(x_q15)`

The 128 products accumulate in signed 64-bit `fir_acc`; the sample result is
`signed(fir_acc) >>> 15`, then saturated to signed 24 bits. Coefficient update
uses the identity filtered-x approximation and a deterministic two-stage
quantization:

`gradient_q15 = (signed(mu_q15) * signed(error_q15)) >>> 15`

`delta_q15 = (signed(gradient_q15) * signed(x_q15)) >>> 15`

`coeff_next = sat16(signed(coeff_old) + signed(delta_q15))`

The shared multiplier operands are sign-extended to explicit 32-bit signed
values, and all adds use signed 64-bit intermediates. Arithmetic right shift
rounds toward negative infinity. Output and coefficient arithmetic saturate;
clip and overrun counters saturate at `0xffffffff`.

## Cycle schedule

For an accepted enabled, non-bypass sample at edge `C0`:

| Edge | State/action | Output/handshake |
|---|---|---|
| C0 | Capture reference/error/mu, write history, enter FIR | `sample_ready` drops after C0 |
| C1..C128 | One FIR tap per cycle, tap 0..127 | `busy=1` |
| C128 | Commit FIR result and residual | `sample_out_valid=1` for this cycle |
| C129 | One shared multiply computes `mu*error` gradient | `busy=1` |
| C130..C257 | One coefficient delta per cycle, tap 0..127 | coefficients commit sequentially |
| after C257 | Return idle | `sample_ready=1`, next accept is C258 |

Thus the maximum accepted-sample-to-ready interval is 258 clock edges after
C0 in the default 128-tap configuration, excluding reset. Bypass and disabled
non-bypass samples complete at C0/C1 observation without entering FIR/update.

The circular history write pointer advances for every accepted sample. Tap 0
uses the captured current sample; tap `i>0` uses history index
`(sample_ptr-i) mod 128`.

## Verification boundary and limitations

The accompanying `sim/tb_anc_fx_lms_tm_core.sv` is a local Icarus behavioral
check for handshake, bypass, FIR arithmetic, negative signed update, address
127, overrun, and saturation. It is not a synthesis, timing, resource, board,
codec, or acoustic result. Vivado is unavailable in the execution environment;
DSP/LUT/BRAM counts and Fmax remain unmeasured. Before integration, add a
reviewed AXI/I2S adapter, measured secondary-path model, reset/CDC review, and
an independent synthesis report.
