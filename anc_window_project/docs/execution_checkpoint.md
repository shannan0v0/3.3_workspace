# Execution Checkpoint: Steps 2-3 plus Step 4 repair

Date: 2026-09-04

## Findings

* The first delegated RTL task was stopped after repeated planning-only output and no files; only its exact child PID was terminated.
* The main agent then created the project under `temp/anc_window_project` only.
* Four RTL modules, an AX7020 constraint template, README, architecture/register notes, two self-checking testbenches, an integer Python reference, and Step 4 handoff files now exist.
* Icarus Verilog 12 compiled the four RTL modules with `-g2012 -s anc_top` and returned code 0. The compiler emitted only its known `always_comb` constant-select warning.

## Evidence

* Top compile artifact/logs: `build/anc_top.vvp`, `build/compile_stdout.txt`, `build/compile_stderr.txt`
* Core TB: `build/tb_core.vvp`, `build/tb_core_compile_stdout.txt`, `build/tb_core_compile_stderr.txt`, `build/tb_core_run.txt` -> `TB_CORE_PASS`
* Register TB: `build/tb_reg.vvp`, `build/tb_reg_compile_stdout.txt`, `build/tb_reg_compile_stderr.txt`, `build/tb_reg_run.txt` -> `TB_REG_PASS`
* Python reference: `scripts/golden_reference.py`, `build/python_golden_run.txt` -> `PY_GOLDEN_PASS`
* Step 4 wrapper first failed before execution because PowerShell rejected a cross-line function call; it was changed to explicit argument arrays.
* The second wrapper attempt returned RC=1 before compilation because the `Run-Captured` function displayed an empty argument list; the parameter named `$Args` collided with PowerShell's automatic `$args` variable. It was renamed to `$ToolArgs`.
* The third wrapper attempt passed all source arguments to Icarus, but PowerShell `ErrorActionPreference=Stop` promoted Icarus's known nonfatal `always_*` constant-select warning from stderr before `$LASTEXITCODE` could be checked. `Run-Captured` is being changed to use `Continue` only around the native invocation, while retaining explicit nonzero-RC failure handling.
* The project path and all relative artifact paths are ASCII and contain no spaces.
* Step 5 first ad-hoc static check used the nonexistent `ps\\anc_ps_driver.c`; physical inspection showed the delivered PS files are `ps\\anc_bringup.c`, `ps\\anc_regs.h`, and `ps\\README.md`.
* Step 5 second ad-hoc static check used the nonexistent `rtl\\i2s_sample_boundary.sv`; physical inspection showed the delivered I2S module is `rtl\\anc_i2s_if.sv`. The maintained wrapper already references `anc_i2s_if.sv`; both failures were checker-list naming errors, not source failures.
* Step 5 third ad-hoc static check used the nonexistent `LICENSE.txt` and `docs\\reproduction.md`; physical root/docs inspection confirmed they are not part of this delivery, while the actual documented files are `docs\\architecture.md`, `docs\\register_map.md`, `docs\\rtl_notes.md`, `docs\\wiring_and_metrics.md`, and `docs\\execution_checkpoint.md`. The check list will use actual delivered files only.

## Step 3 offline ANC analysis

* `scripts/offline_anc_analysis.py` passed `py_compile` and a complete run: `OFFLINE_ANC_ANALYSIS_PASS rows=12 samples_per_row=4096`.
* The saturation boundary probe passed: `coeff_hi=32767`, `coeff_lo=-32768`, `clips=1`, `samples=2`.
* Independent CSV validation passed against the generated 11-column header, with 12 data rows and `sample_count=4096` for every row; first, middle, and last rows were inspected.
* A second generator run returned code 0 and produced the same CSV SHA-256: `01993fb7d13fae7ddc9eb29f63c684e768a14f610b6dea2588f84d7c6b44fa0b`.
* One earlier independent check failed with exit code 1 because the checker expected stale field names (`mu`, `rms_first_512`, etc.); the corrected checker used the actual header (`mu_q15`, `initial_rms`, `final_rms`, `change_db`, `coeff_rmse`, `clip_count`, `sample_count`, and final coefficients) and passed. This was a checker defect, not a production artifact defect.
* Report boundary is explicit: synthetic deterministic identity-secondary-path/Q15 integer experiment only; no acoustic, codec, board, physical stability, or global-convergence claim.

## Boundary

The local compile/simulation/reference-model checks remain valid as simulation
 evidence only. A later tool-enabled Vivado v2025.2.1 run used the explicit
`xc7z020clg400-1` target and verified project creation, synthesis-report
production, and independent DCP opening (`RC=0`, 248413 cells, 199 ports).
The design is not deployable: LUT utilization is 277.28%, and the inert XDC
has no real clock constraints, so timing closure is not demonstrated.
Implementation, bitstream generation, exact pins, codec bring-up, board
execution, and acoustic A/B measurement remain unverified. Pin placeholders
must be replaced from the exact AX7020 schematic before hardware use.


## Step 6 independent re-audit

* The independent report is `../verify_anc_window_reaudit/reverify_audit_report.md`; its 16-row audit table was read and its Mini checks passed.
* The literal verdict file is `../verify_anc_window_reaudit/REVERIFY_VERDICT.txt`; its last non-empty line is `VERDICT: PARTIAL`.
* Local Icarus/VVP/Python checks, the F-01 negative-update regression, saturation/bypass probes, and the independent I2S probe passed with no unresolved functional failure.
* Vivado synthesis-report generation and independent post-synthesis DCP
  opening are now verified by the Step 5 evidence report; implementation,
  timing closure with real constraints, bitstream, physical board execution,
  codec bring-up, and acoustic measurement remain unverified.


## Step 6 final review (2026-09-05)

* `audit/step6_final_review.md` records the independent closure audit and its command/output/exit-code table.
* Sequential rerun results: `run_local_checks.ps1` RC=0 with `TB_CORE_PASS`, `TB_REG_PASS`, `PY_GOLDEN_PASS`, `LOCAL_CHECKS_PASS`; `run_interface_checks.py` RC=0 with AXI/I2C/CDC markers and `INTERFACE_CHECKS_PASS`; `run_rtl_python_regression.py` RC=0 with `RTL_PYTHON_REGRESSION_PASS samples=203`; `offline_anc_analysis.py` RC=0 with `OFFLINE_ANC_ANALYSIS_PASS rows=12 samples_per_row=4096`; four-script Python compilation RC=0.
* Independent artifact audit returned `FINAL_INDEPENDENT_AUDIT PASS checks=49 failures=0`. It checked all required markers, text stderr, actual CSV schema and signed ranges, first/middle/last rows, repeat SHA-256, boundary claims, non-empty docs, inert XDC, RTL inventory, and the pre-close plan state.
* The adversarial empty-`PATH` probe correctly failed closed: RC=2, `INTERFACE_CHECKS_BLOCKED: iverilog/vvp not found`, empty stderr.
* Two earlier audit failures were checker defects only: guessed log/encoding handling and stale CSV field/sign rules. The corrected audit passed without changing the tested RTL or generated data.
* Git probes at this directory returned RC=128 because it is not a Git repository; no commit is claimed.
* Overall status remains `VERDICT: PARTIAL` solely for the previously documented environment boundary: Vivado/verified part, synthesis/timing/implementation/bitstream, exact pins, board/codec execution, and acoustic measurements remain unverified.
