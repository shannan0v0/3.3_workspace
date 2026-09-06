# Vivado / AX7020 implementation placeholder

## Status

This directory remains an implementation handoff note, not a completed board
project. Vivado v2025.2.1 was located at
`E:\vivado.vitis\Vivado\2025.2.1\Vivado\bin\vivado.bat`; an explicit
`xc7z020clg400-1` project was created and synthesis artifacts were generated.
The post-synthesis checkpoint opens independently (`RC=0`, 248413 cells,
199 ports). However, the selected design exceeds LUT capacity
(`147512/53200 = 277.28%`), and the inert XDC provides no real clock
constraints, so this is not a deployable or timing-closed result. The exact
AX7020 revision schematic, verified pin names, fitted WM8731 wiring, PS
physical base address, implementation, bitstream, board result, and acoustic
result remain unverified.

## Intended handoff sequence

1. Create a Vivado project for the exact XC7Z020 part printed on the board.
2. Add every file under `rtl/` and set `anc_top` as the top module.
3. Replace the placeholders in `constraints/AX7020_template.xdc` from the
   exact schematic. Confirm bank voltage, clock frequency, reset polarity,
   and I2S/codec connections before uncommenting constraints.
4. Add a Zynq PS and an AXI-Lite-to-local-bus adapter. Assign the PL register
   window and copy that physical base into the PS application integration.
5. Add codec I2C initialization and a reviewed CDC/clocking implementation.
6. Run synthesis, implementation, timing, and bitstream generation. Preserve
   the tool version, part, warnings, utilization, and worst slack.
7. Program the board and execute the bring-up and A/B measurement plan in
   `docs/wiring_and_metrics.md`.

## Required reports before a board claim

- `synth_design` and `opt_design`/`place_design`/`route_design` logs
- utilization by hierarchy and clock/timing reports
- generated bitstream checksum
- actual board revision and pin/IO voltage review
- codec register dump and I2S capture
- bypass-versus-enabled measurements with the same test signal

## Generated handoff scripts

- `create_project.tcl <exact_part> [project_dir]` creates a project from every
  `rtl/*.sv` source and refuses to overwrite an existing `.xpr`.
- `run_synth_reports.tcl <project.xpr> [report_dir]` runs synthesis and writes
  utilization, estimated timing, and post-synthesis checkpoint artifacts.
- `constraints/AX7020_template.xdc` is intentionally inert; it contains no
  guessed pin or clock values. See `HANDOFF.md` for the gated sequence.

Synthesis and post-synthesis checkpoint artifacts now exist and are listed in
`../audit/step5_vivado_synthesis_evidence.md`. Vivado implementation,
timing closure with real constraints, bitstream, and all hardware/audio steps
remain **UNVERIFIED**.
