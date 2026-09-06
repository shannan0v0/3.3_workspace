# AX7020 ANC Window MVP

This is a pure-English, simulation-first RTL skeleton for the assumed ALINX AX7020 / XC7Z020 and WM8731 stereo I2S path. The first milestone is a Q15 128-tap FxLMS MVP at a 16 kHz sample boundary.

## Layout

* `rtl/` - synthesizable SystemVerilog modules
* `sim/` - self-checking Icarus testbenches
* `scripts/` - reproducible local checks and Python reference
* `constraints/` - deliberately uncommitted AX7020 pin template
* `docs/` - architecture, register map, wiring/metrics, and evidence limits
* `ps/` - PS-side register driver example; physical base is not guessed
* `vivado/` - implementation handoff and unverified board checklist
* `skills/` - reusable ANC FPGA workflow skill

## Local check from zero

Use the project root as the working directory. The wrapper preserves compile,
simulation, and Python logs under `build/`:

```text
scripts\\run_local_checks.cmd
```

Or, from PowerShell:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\run_local_checks.ps1
```

A successful run requires `iverilog`, `vvp`, and `python` on PATH (the script
also checks the documented `D:\\iverilog\\bin` fallback) and prints:
`TB_CORE_PASS`, `TB_REG_PASS`, `PY_GOLDEN_PASS`, and `LOCAL_CHECKS_PASS`.

## Hardware boundary

This is a simulation-ready MVP, not a board image. Vivado synthesis/
implementation, exact AX7020 pin constraints, codec I2C setup, PS/AXI address
assignment, bitstream programming, and acoustic A/B measurements remain
**UNVERIFIED**. Follow `vivado/README.md` and
`docs/wiring_and_metrics.md` only after checking the exact board schematic.
