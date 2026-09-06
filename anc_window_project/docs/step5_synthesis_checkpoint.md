# Step 5 synthesis checkpoint

Date: 2026-09-05

## Purpose

This checkpoint records the real Vivado synthesis attempt and the evidence
available after the wrapper command timed out. It is not a board or acoustic
validation report.

## Verified facts to preserve

- Vivado executable: `E:\vivado.vitis\Vivado\2025.2.1\Vivado\bin\vivado.bat`.
- Tool probe: Vivado `2025.2.1`; the device query listed XC7Z020 variants.
- The retry project was created for the explicit target `xc7z020clg400-1`.
- The retry synthesis output directory is
  `anc_window_project/build/vivado_project_2025_2_1_xc7z020clg400_1_retry/reports_synth/`.
- The synthesis wrapper reached report/DCP generation, but its outer 840-second
  command timeout did not provide a trustworthy wrapper return code or complete
  stdout/stderr capture. Do not label that wrapper invocation as a clean pass.
- Independent checkpoint opening returned RC=0 and observed 248,413 cells and
  199 ports.
- Post-synthesis utilization exceeds the selected device LUT capacity:
  147,512 used / 53,200 available = 277.28%.
- The inert XDC provides no real clock constraint; the timing report therefore
  has no usable clock path/WNS value and is not timing closure evidence.
- Implementation, bitstream, exact board pinout, PS address mapping, codec
  bring-up, physical audio, and acoustic A/B measurements remain unverified.

## Closure status

The detailed evidence report is `../audit/step5_vivado_synthesis_evidence.md`.
The handoff and final-review wording was updated to distinguish verified
synthesis/DCP evidence from unverified implementation and hardware evidence.
The remaining closure action is a full-plan reread and zero-unchecked-item
scan.
