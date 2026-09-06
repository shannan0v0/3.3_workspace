# Step 3[D] independent closeout

## Scope
Independent closeout of the already executed `anc_fx_lms_tm_core` RTL TB. No legacy RTL, plan checkmark, board, codec, or acoustic result was modified or inferred.

## Real commands and evidence
- Context: `D:\GenericAgent-Desktop-Windows-Portable\runtime\app\temp\step3_tm_validation_delegate_20260905_v4\context.json`
- Independent model imported and executed from `D:\GenericAgent-Desktop-Windows-Portable\runtime\app\temp\anc_window_project\scripts\tm_fx_lms_cycle_model.py`.
- Real TB source: `D:\GenericAgent-Desktop-Windows-Portable\runtime\app\temp\anc_window_project\audit\step3_tm_validation_delegate_20260905_v3\tb.sv`
- Real TB stdout: `D:\GenericAgent-Desktop-Windows-Portable\runtime\app\temp\anc_window_project\audit\step3_tm_validation_delegate_20260905_v3\tb.stdout.txt`
- Real TB stderr: `D:\GenericAgent-Desktop-Windows-Portable\runtime\app\temp\anc_window_project\audit\step3_tm_validation_delegate_20260905_v3\tb.stderr.txt`
- Real TB return code: `D:\GenericAgent-Desktop-Windows-Portable\runtime\app\temp\anc_window_project\audit\step3_tm_validation_delegate_20260905_v3\tb.rc.txt` (value `0`)
- This finalizer command: `"D:\GenericAgent-Desktop-Windows-Portable\runtime\python\python.exe" "D:\GenericAgent-Desktop-Windows-Portable\runtime\app\temp\anc_window_project\audit\step3_tm_validation_delegate_20260905_v3\finalize_step3_evidence.py"`
- The original TB compile/run shell command was not preserved in the context; no compile command is inferred here.

The finalizer itself imports and executes the independent Python cycle model, then compares post-edge visible outputs against all real TB traces. The original simulator invocation command was not preserved, so it is explicitly not claimed; the preserved TB source/output/stderr/RC are the evidence of that earlier run.

## Nine-case results
| Case | TB marker | Python replay | Trace edges | Transactions | Output pulses | Mismatch edges |
|---|---|---|---:|---:|---:|---:|
| reset | PASS | PASS | 3 | 0 | 0 | 0 |
| coefficient_write | PASS | PASS | 5 | 0 | 0 | 0 |
| bypass | PASS | PASS | 5 | 1 | 1 | 0 |
| all_128_taps | PASS | PASS | 517 | 129 | 129 | 0 |
| saturation | PASS | PASS | 517 | 129 | 129 | 0 |
| negative_update_direction | PASS | PASS | 261 | 1 | 1 | 0 |
| busy | PASS | PASS | 261 | 1 | 1 | 0 |
| overrun_protection | PASS | PASS | 261 | 1 | 1 | 0 |
| continuous_samples | PASS | PASS | 778 | 3 | 3 | 0 |

## Global checks
- Imported model: **PASS**
- Edge replay: **PASS** (2608/2608, last edge 2608)
- TB: **PASS** (RC=0, checks 3683 pass/0 fail, summary=(0, 2608))
- Metrics: **PASS** (active=257, taps=128, budget=6250)
- Overrun protection: **PASS** (TB final=2, replay max=2)

## Boundary
Python/Icarus replay proves local cycle-level behavior represented by the preserved testbench. It does not prove Vivado timing closure, implementation/bitstream generation, exact XDC pinout, board/codec operation, end-to-end latency, or acoustic A/B performance. The separate Vivado evidence remains resource-over-limit/PARTIAL as documented elsewhere.

VERDICT: PASS
