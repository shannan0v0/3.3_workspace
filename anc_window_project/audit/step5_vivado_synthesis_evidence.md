# Step 5 Vivado synthesis evidence

Date: 2026-09-05
Scope: Vivado project creation, synthesis-report generation, and independent
post-synthesis checkpoint opening. This is not board or acoustic validation.

## Commands and observed results

1. **Tool and device probe**
   - Launcher: `E:\vivado.vitis\Vivado\2025.2.1\Vivado\bin\vivado.bat`
   - Observed tool version: `Vivado v2025.2.1`.
   - The device query listed XC7Z020 variants.

2. **Project creation**
   - Maintained script: `anc_window_project/vivado/create_project.tcl`.
   - Explicit target used for the retry project: `xc7z020clg400-1`.
   - Observed result: project created; 7 delivered `rtl/*.sv` sources were added
     and `anc_top` was selected as top. The project is under
     `anc_window_project/build/vivado_project_2025_2_1_xc7z020clg400_1_retry/`.

3. **Synthesis/report generation**
   - Maintained script: `anc_window_project/vivado/run_synth_reports.tcl`.
   - Report directory:
     `anc_window_project/build/vivado_project_2025_2_1_xc7z020clg400_1_retry/reports_synth/`
   - The outer synthesis command reached report and DCP generation, but its
     840-second wrapper timeout did not preserve a trustworthy wrapper return
     code or complete stdout/stderr capture. Therefore this invocation is not
     labeled as a clean wrapper pass. The generated files below were checked
     independently.

4. **Independent checkpoint verification**
   - Probe script: `anc_window_project/build/step5_open_dcp_probe.tcl`.
   - Actual launcher invocation used the observed `...\Vivado\bin\vivado.bat`
     path, batch mode, and `-source step5_open_dcp_probe.tcl`.
   - Observed result: `RC=0`; stdout marker
     `DCP_OPEN_OK cells=248413 ports=199`; stderr was empty.
   - Probe stdout, stderr, and RC are preserved as
     `build/step5_open_dcp_probe.stdout.txt`,
     `build/step5_open_dcp_probe.stderr.txt`, and
     `build/step5_open_dcp_probe.rc.txt`.

## Artifact integrity

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `reports_synth/synth_utilization.rpt` | 8,799 | `2367e49b4708dbe5a5b5aef908e194117bf8e04d81758b77cfd45615fc9b200c` |
| `reports_synth/synth_timing_summary.rpt` | 8,376 | `a501fa4a63aae215bca72724117d38e73dd8d9d0784013c85912685081a7f0c5` |
| `reports_synth/post_synth.dcp` | 75,999,912 | `9dfbfd1ce8c7ae3877c53e5a9561d2a4183d74f38b554c1bade973f83819b75a` |

The utilization report header records Vivado 2025.2.1, design `anc_top`,
device `xc7z020clg400-1`, and design state `Synthesized`. The timing report
records the same synthesized design and device family.

## Results and engineering interpretation

- Slice LUTs: `147512 / 53200 = 277.28%`; this exceeds the selected device
  capacity and is a synthesis resource-gate failure, not a deployable FPGA
  result.
- Slice registers: `5457 / 106400 = 5.13%`.
- Block RAM tiles: `0 / 140 = 0.00%`.
- DSPs: `220 / 220 = 100.00%`.
- Timing summary: WNS/TNS fields are `NA`; the report says there are no user
  specified timing constraints. The inert XDC also reports 5,677 no-clock
  register/latch pins and 22,927 unconstrained internal endpoints. This is
  evidence of missing constraints, not timing closure.

## Remaining boundary

This evidence verifies tool availability, explicit-part project generation,
synthesis-report/DCP production, and independent DCP readability. It does not
verify implementation, placement/routing, timing closure, bitstream
production, exact AX7020 revision or pins, PS physical address mapping, WM8731
codec bring-up, physical audio, CDC margin on hardware, or acoustic A/B/RMS
performance. The target part was used as an explicit XC7Z020-family synthesis
part; it is not a claim that the exact board revision or pinout was identified.

VERDICT: PARTIAL (synthesis artifacts verified; resource gate and constraints
are not deployment-ready)
