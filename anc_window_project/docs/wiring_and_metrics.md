# Wiring, bring-up, and measurement plan

## Scope and hardware boundary

The RTL assumes an AX7020/XC7Z020 board with a WM8731-compatible stereo I2S
path, but the exact board revision, codec population, connector wiring, and
pin map are not verified. Do not connect or constrain signals from this file
alone. First compare the board marking and schematic, then update the XDC.

## Logical signal plan

```text
reference microphone / ADC left  -> I2S SDIN -> anc_i2s_if -> ref_sample
error microphone / ADC right     -> I2S SDIN -> anc_i2s_if -> error_sample
                                      anc_fx_lms_core
residual / anti-noise            <- I2S SDOUT (right/left contract to review)
PS/Zynq AXI-Lite                 -> local register bus -> anc_reg_bank
100 MHz PL clock + reset         -> all RTL (CDC review required)
```

The MVP uses 32-bit I2S slots: one leading dummy bit, 24 data bits, and seven
pad bits. `LRCLK=0` is treated as reference and `LRCLK=1` as error. These are
RTL assumptions, not verified codec settings. The selected codec's data
format, polarity, word length, sample rate, master/slave mode, and MCLK
requirements must be confirmed before use.

## Safe bring-up order

1. Confirm board revision, FPGA part, IO bank voltage, oscillator, reset,
   codec population, connector pinout, and microphone signal conditioning.
2. Replace every `<...>` XDC placeholder and run electrical/CDC review.
3. Configure the codec over I2C and capture a known digital tone at 16 kHz.
4. Run the register sequence in `docs/register_map.md`: reset, coefficients,
   small `MU_Q15`, bypass A/B, then enabled mode.
5. Verify `SAMPLE_COUNT`, `CLIP_COUNT`, `ANTI_NOISE`, and `RESIDUAL` through the
   PS register driver before making an acoustic claim.
6. Keep microphones and loudspeaker physically separated during first tests;
   use a current-limited, low-level signal and stop if clipping/oscillation
   appears.

## Metrics to record

| Metric | Procedure | Status here |
|---|---|---|
| Functional correctness | Existing self-checking TBs and Python reference | Verified locally |
| Output clipping | Read `CLIP_COUNT`; compare with `SAMPLE_COUNT` | RTL only |
| End-to-end latency | Timestamp input/output samples at the same clock reference | Not measured |
| Bypass A/B level | RMS of residual in bypass and enabled modes on identical input | Not measured |
| Noise reduction | `20*log10(RMS_bypass/RMS_enabled)` over a fixed window | Not measured |
| Stability | Long run, coefficient range, clip rate, and output spectrum | Not measured |
| FPGA resources/timing | Vivado utilization and worst negative slack for exact part | Not available |

Report sample rate, window length, input level, microphone placement, speaker
level, codec settings, firmware commit, FPGA bitstream checksum, and whether
bypass or enabled mode was used. Never substitute simulation PASS markers for
an acoustic, timing, synthesis, or board result.
