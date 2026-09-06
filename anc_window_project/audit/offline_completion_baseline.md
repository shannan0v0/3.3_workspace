# Offline Completion Baseline

Date/time (local): 2026-09-05T13:31:47.115439+08:00
Scope: this baseline records offline-only work before any RTL modification.
Command policy: every later step must record command, stdout/stderr, and exit code; existing runners remain preserved.

## Explicit project file probe
- `rtl/anc_fx_lms_core.sv`: exists=True, bytes=5651, sha256=8b01cd8dc16c9f05cd6d29e8e469047b07def4ee31012ce48f0218777a3663f6
- `rtl/anc_i2s_if.sv`: exists=True, bytes=4143, sha256=82e530bd6c651f70813e6c81ce2ea49c2ad75913b1b8a5d33d4fabf50485a53d
- `rtl/anc_top.sv`: exists=True, bytes=3240, sha256=85ac298684c97f873db4cd9eca77b646417ee185b542af276f2a781e4596bfc5
- `scripts/golden_reference.py`: exists=True, bytes=2370, sha256=e10df48cf0f274fd8411a3c33d457e3d6d3eaefb8c071e2649c4ca7ad6f9adeb
- `scripts/run_rtl_python_regression.py`: exists=True, bytes=8933, sha256=9108144017ecd32891938b2662920f6882e11963504f7f7bef90441110b6b4e6
- `scripts/run_interface_checks.py`: exists=True, bytes=2460, sha256=3fe04e2554f03f56f976bbf53d73f2da1ae5870e0ebcec9de85aaf582e594608
- `ps/anc_bringup.c`: exists=True, bytes=935, sha256=2e1a7eecbd3626cf3d745a91a63f98599391bed665b3523add86d02cb674bad6
- `ps/anc_regs.h`: exists=True, bytes=2063, sha256=a4de2fd91461b4c08e579d745045ad5b1b19cc211e3bb1f873fb71eda5bddfc0
- `vivado/create_project.tcl`: exists=True, bytes=1521, sha256=93b15f3c9c890ffd7c864818715186352b0c7ba4898b68b0e0a9043e6662ceea
- `vivado/run_synth_reports.tcl`: exists=True, bytes=1020, sha256=69c0460afdcb5dbf5d7a1d443af8edfa6195eea6fd51fbd462ccc01b3e15b9d2
- `constraints/AX7020_template.xdc`: exists=True, bytes=1022, sha256=8eef0a7243be8990ef1664ed31c4f0f9bc8e4520e1fef8e4ca716ce810876201
- `audit/step5_vivado_synthesis_evidence.md`: exists=True, bytes=3904, sha256=e2c262a53265ba3744a01dc5083caa3b24817272c0470a7d8e39df49a7f443e0
- `audit/step6_final_review.md`: exists=True, bytes=4193, sha256=ffa5dc3c3e891e98692d1994d4adf579847b1f21447585d807495c37ff2a60c0
- file_probe_missing=0

## Tool probe
- `python`: C:\Users\Lenovo\AppData\Local\Programs\Python\Python38\python.EXE
- `iverilog`: D:\iverilog\bin\iverilog.EXE
- `vvp`: D:\iverilog\bin\vvp.EXE
- `git`: D:\Git\cmd\git.EXE
- Vivado launcher `E:\vivado.vitis\Vivado\2025.2.1\Vivado\bin\vivado.bat`: exists=True

## Existing verified evidence baseline
- Existing local RTL/Python regression: PASS, 203 compared samples (from prior audit/log; will be rerun after changes).
- Existing interface simulations: TB_AXI_PASS, TB_I2C_PASS, TB_CDC_PASS (from prior audit/log; will be rerun after changes).
- Existing offline analysis: 12 parameter rows × 4096 samples (from prior audit/log).
- Existing independent artifact audit: 49/49 PASS (from prior audit/log).
- Existing Vivado synthesis/DCP is readable, but the prior resource gate failed: Slice LUT 147512/53200 = 277.28%; DSP 220/220 = 100%.
- Existing timing report has no user-specified timing constraints; this is not timing closure.

## Hardware boundary
- Not verified offline: exact AX7020 revision, schematic pin map, IO voltage, clock wiring, PS physical AXI address, real WM8731 presence/configuration, bitstream, implementation, board execution, audio loop, acoustic A/B/RMS and dB results.
- No board or audio hardware is connected for this offline completion run.

## Baseline command/result
`python <inline baseline probe>`
- exit_code=0; missing_known_files=0; baseline_path=D:\GenericAgent-Desktop-Windows-Portable\runtime\app\temp\anc_window_project\audit\offline_completion_baseline.md
