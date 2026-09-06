# Vivado handoff

1. Confirm the exact FPGA part from the board and run `create_project.tcl`
   with that part as an explicit argument.
2. Review `constraints/AX7020_template.xdc`; it is intentionally inert and
   contains no board pin, IO voltage, or clock claim.
3. Review the generated source set and connect the PS/AXI/I2C/CDC pieces only
   after schematic and clock/reset review.
4. Run `run_synth_reports.tcl <project.xpr> [report_dir]` and preserve the
   tool version, part, logs, utilization, and timing reports.

The scripts do not create a PS address map, codec initialization, pinout,
bitstream, implementation result, board result, or acoustic result. A real
synthesis run was performed with Vivado v2025.2.1 for the explicit synthesis
target `xc7z020clg400-1`; its reports and post-synthesis DCP are recorded in
`../audit/step5_vivado_synthesis_evidence.md`. The result is not deployable:
LUT utilization is 277.28%, and the inert XDC leaves timing unconstrained.
Implementation, bitstream, exact board wiring, codec bring-up, and acoustic
results remain unverified.
