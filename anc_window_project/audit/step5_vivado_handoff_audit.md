# Step 5 Vivado handoff audit

Date: 2026-09-05
Scope: non-hardware project handoff and environment-gated Vivado check.

## Verification table

| # | Verification action | Tool | Observed output | Result |
|---|---|---|---|---|
| 1 | Check required handoff artifacts are non-empty | Python `Path` audit | `HANDOFF_OK` for `vivado/create_project.tcl` (1449 B), `run_synth_reports.tcl` (1020 B), `HANDOFF.md` (807 B), `README.md` (2236 B), and `constraints/AX7020_template.xdc` (721 B) | PASS |
| 2 | Count source files referenced by project generator | Python `Path.glob` | `RTL_SOURCE_COUNT 7`; the seven delivered `rtl/*.sv` files were enumerated | PASS |
| 3 | Inspect project-generator safety and setup guards | Python string audit | Part argument required; existing `.xpr` overwrite refused; `rtl/*.sv` enumeration and `anc_top` top assignment present | PASS |
| 4 | Inspect synthesis/report script guards and outputs | Python string audit | Project argument and project-existence check present; `synth_design`, `report_utilization`, `report_timing_summary`, and checkpoint output present | PASS |
| 5 | Check constraints template does not assert unverified hardware facts | Python line audit | `CHECK xdc_has_no_active_commands PASS`; all XDC lines are comments and contain no active pin, IO standard, or clock command | PASS |
| 6 | Check handoff boundary statement | Python string audit | `CHECK handoff_states_unverified PASS`; handoff explicitly states no PS map, codec init, pinout, bitstream, implementation, board, or acoustic result is produced | PASS |
| 7 | Resolve implementation tool and standard install candidates | PowerShell | `VIVADO_EXECUTABLE_NOT_FOUND`; `D:\Xilinx\Vivado`, `C:\Xilinx\Vivado`, and `D:\vivado\xilinx\Vivado` absent; earlier probe also returned `TCLSH_NOT_FOUND` | ENVIRONMENT BLOCK |

## Adversarial checks

- Missing exact part: `create_project.tcl` requires an explicit part argument and exits with usage when absent.
- Existing project: the generator refuses to overwrite an existing `.xpr`.
- Missing project: `run_synth_reports.tcl` errors before opening a nonexistent project.
- Unverified pins/clocks: the XDC template is intentionally inert rather than guessing values.

## Evidence hashes

- `vivado/constraints/AX7020_template.xdc` SHA-256:
  `9a5150431a5baf66bbb1a6e8ac6142b70fc613a531c6d2d3f15308622bc1acf0`

## Boundary

The handoff files were generated and statically audited. A later tool-enabled
run used Vivado v2025.2.1 and the explicit synthesis target
`xc7z020clg400-1`; project creation, RTL synthesis-report generation, and
independent post-synthesis DCP opening were verified. The selected design is
not deployable: LUT utilization is 277.28%, and the inert XDC supplies no real
clock constraints, so timing closure is not demonstrated. Implementation,
bitstream generation, exact XDC validation, board bring-up, codec operation,
and acoustic measurements remain unverified. Detailed evidence is in
`step5_vivado_synthesis_evidence.md`.

VERDICT: PARTIAL
