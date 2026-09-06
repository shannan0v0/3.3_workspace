# Step 6 Final Evidence Review

Date: 2026-09-05
Scope: independent local verification, evidence aggregation, and closure review for the ANC Window simulation-first project.

## Verification table

| # | Command / action | Observed output | Exit / result |
|---|---|---|---|
| 1 | `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_local_checks.ps1` | `TB_CORE_PASS`, `TB_REG_PASS`, `PY_GOLDEN_PASS`, `LOCAL_CHECKS_PASS`; compiler emitted only the known Icarus `sorry` constant-select warning | RC=0 / PASS |
| 2 | `python scripts/run_interface_checks.py` | `TB_AXI_PASS`, `TB_I2C_PASS`, `TB_CDC_PASS`, `INTERFACE_CHECKS_PASS` | RC=0 / PASS |
| 3 | `python scripts/run_rtl_python_regression.py` | `RTL_PYTHON_REGRESSION_PASS samples=203`; trace samples matched the integer Python model | RC=0 / PASS |
| 4 | `python scripts/offline_anc_analysis.py` | `OFFLINE_ANC_ANALYSIS_PASS rows=12 samples_per_row=4096`; saturation probe passed | RC=0 / PASS |
| 5 | Python compilation of the four maintained scripts | `py_compile_all_scripts` completed with no output | RC=0 / PASS |
| 6 | Empty-`PATH` dependency probe for `run_interface_checks.py` | `INTERFACE_CHECKS_BLOCKED: iverilog/vvp not found`; no stderr | RC=2 / expected fail-closed PASS |
| 7 | Independent artifact audit | `FINAL_INDEPENDENT_AUDIT PASS checks=49 failures=0` | RC=0 / PASS |

All command stderr streams were inspected. There were no `error` or `fatal` diagnostics. The only non-empty tool diagnostic was the known nonfatal Icarus `sorry` warning recorded above.

## Independent artifact audit details

- Seven required simulation markers were present: `TB_CORE_PASS`, `TB_REG_PASS`, `PY_GOLDEN_PASS`, `TB_AXI_PASS`, `TB_I2C_PASS`, `TB_CDC_PASS`, and `RTL_REGRESSION_PASS`.
- `build/offline_anc_mu_sweep.csv` was parsed independently: 11-column header, 12 data rows, and `sample_count=4096` in the inspected rows. First, middle, and last rows were non-empty and numeric; signed coefficient fields stayed within the Q15 16-bit range. Repeated SHA-256 readback was stable at `01993fb7d13fae7ddc9eb29f63c684e768a14f610b6dea2588f84d7c6b44fa0b`.
- The offline report was checked for its actual boundary wording: synthetic experiment, identity secondary path, not acoustic cancellation, and unverified hardware boundary.
- README, Vivado handoff documentation, and the Step 5 audit were non-empty and retained their non-hardware / `VERDICT: PARTIAL` claims.
- `vivado/constraints/AX7020_template.xdc` remained inert with no active constraint lines; seven non-empty RTL source files were inventoried.
- Before closure marking, the plan scan found exactly two open checklist items: Step 6 and the termination gate.

## Checker correction record

Two earlier audit attempts failed in the audit harness, not in the project checks. The first used guessed log names and attempted UTF-8 decoding on PowerShell UTF-16 output / a binary VVP artifact. The second used stale CSV field names and rejected signed coefficient fields. The harness was corrected using the filenames emitted by the inspected scripts, byte-safe text decoding, the actual 11-column CSV schema, and signed/unsigned-aware range checks. The corrected audit passed 49/49 checks.

## Environment and boundary

The local RTL/Python result is simulation/reference-model evidence. In a
later tool-enabled run, Vivado v2025.2.1 created the explicit
`xc7z020clg400-1` project, generated synthesis reports and a post-synthesis
DCP, and an independent DCP probe returned RC=0 with
`DCP_OPEN_OK cells=248413 ports=199`. That design is not deployable because
LUT utilization is 277.28%; the inert XDC has no real clock constraints, so
WNS/TNS are not timing-closure evidence. Implementation, bitstream
 generation, exact pin validation, board execution, codec bring-up, and
acoustic A/B measurement remain unverified. See
`step5_vivado_synthesis_evidence.md`; replace the inert XDC from the exact
board schematic before hardware use.

A `git status` / `git rev-parse --show-toplevel` probe at `anc_window_project` returned RC=128 (`not a git repository`); no Git commit is claimed for this directory.

VERDICT: PARTIAL
