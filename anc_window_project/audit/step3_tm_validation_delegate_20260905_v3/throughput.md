# Step 3[D] throughput budget

- Context: `D:\GenericAgent-Desktop-Windows-Portable\runtime\app\temp\step3_tm_validation_delegate_20260905_v4\context.json`
- Independent model imported and executed from `D:\GenericAgent-Desktop-Windows-Portable\runtime\app\temp\anc_window_project\scripts\tm_fx_lms_cycle_model.py`.
- Real TB source: `D:\GenericAgent-Desktop-Windows-Portable\runtime\app\temp\anc_window_project\audit\step3_tm_validation_delegate_20260905_v3\tb.sv`
- Real TB stdout: `D:\GenericAgent-Desktop-Windows-Portable\runtime\app\temp\anc_window_project\audit\step3_tm_validation_delegate_20260905_v3\tb.stdout.txt`
- Real TB stderr: `D:\GenericAgent-Desktop-Windows-Portable\runtime\app\temp\anc_window_project\audit\step3_tm_validation_delegate_20260905_v3\tb.stderr.txt`
- Real TB return code: `D:\GenericAgent-Desktop-Windows-Portable\runtime\app\temp\anc_window_project\audit\step3_tm_validation_delegate_20260905_v3\tb.rc.txt` (value `0`)
- This finalizer command: `"D:\GenericAgent-Desktop-Windows-Portable\runtime\python\python.exe" "D:\GenericAgent-Desktop-Windows-Portable\runtime\app\temp\anc_window_project\audit\step3_tm_validation_delegate_20260905_v3\finalize_step3_evidence.py"`
- The original TB compile/run shell command was not preserved in the context; no compile command is inferred here.

| Quantity | Value | Calculation/meaning |
|---|---:|---|
| Clock frequency | 100 MHz | Contract budget assumption |
| Sample rate | 16 kHz | Contract boundary |
| Budget clocks/sample | 6250 | 100,000,000 / 16,000 |
| Active clocks/sample | 257 | 128 FIR + 1 gradient + 128 delta |
| Margin | 5993 clocks | 6250 - 257 |
| Nominal utilization | 4.112% | 257 / 6250 × 100 |
| TB reported active clocks | 257 | Must equal 257 |
| TB reported budget | 6250 | Must equal 6250 |
| TB overrun final count | 2 | Expected 2 in overrun case |

Budget checks: **PASS**.

This is a cycle-budget calculation, not a Vivado timing-closure result. The project still requires separate synthesis/implementation timing evidence; no board, codec, or acoustic claim follows from this table.
