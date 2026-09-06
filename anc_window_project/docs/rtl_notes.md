# RTL Notes and Evidence Boundary

The four SystemVerilog modules are intended to compile with Icarus Verilog 12 in SystemVerilog mode:

* `rtl/anc_fx_lms_core.sv`: 128-tap Q15 FIR plus bounded FxLMS update and saturation.
* `rtl/anc_reg_bank.sv`: local control/status bus and coefficient write pulse.
* `rtl/anc_i2s_if.sv`: synchronized 32-bit I2S slot boundary.
* `rtl/anc_top.sv`: integration wrapper.

The project currently has no verified AX7020 pin assignment, no Vivado-generated IP, no codec I2C sequencer, and no hardware audio path. A successful local compile or simulation must not be described as synthesis, timing closure, bitstream generation, board bring-up, or acoustic cancellation.

Before hardware use, add the exact board constraints, reset/clock review, WM8731 register initialization, CDC review, resource/timing reports, and physical A/B measurements.
