# Skill: ANC Window FPGA bring-up

## Purpose

Use this skill to develop and verify the AX7020 active-noise-control MVP
without confusing local simulation evidence with board evidence.

## Inputs

- exact board revision and schematic
- verified FPGA part and IO voltages
- codec/microphone wiring and I2S format
- Vivado project or a stated local-tool-only limitation
- test signal and measurement window

## Workflow

1. Read `plan_anc_window/plan.md` and locate the first incomplete action.
2. Run `scripts/run_local_checks.cmd` (or the PowerShell script) before and
   after RTL changes. Preserve the files under `build/`.
3. Use `docs/register_map.md` and `ps/anc_regs.h` for software/PL contracts.
4. Start hardware with bypass, inspect counters and signed sample readback,
   then enable the small-Q15 configuration.
5. Record the metrics in `docs/wiring_and_metrics.md` with conditions and
   artifacts. Keep any unverified board assumptions explicit.

## Evidence rules

- `TB_CORE_PASS`, `TB_REG_PASS`, and `PY_GOLDEN_PASS` prove only the local
  tests represented by those files.
- Synthesis, implementation, timing closure, bitstream programming, codec
  bring-up, and acoustic A/B reduction require their own artifacts.
- Never invent a package pin, PS physical base address, codec register value,
  resource count, or noise-reduction number.

## Troubleshooting order

Check reset and clock first, then I2S slot polarity/word alignment, then local
bus address and write strobes, then signed width/saturation and clipping. A
nonzero clip counter is a diagnostic signal, not a success criterion.
