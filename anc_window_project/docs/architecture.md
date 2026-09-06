# AX7020 ANC FPGA MVP Architecture

## Scope

This directory contains a simulation-ready, synthesizable MVP for an active-noise-control window on an ALINX AX7020 / XC7Z020. It targets the assumed WM8731 stereo codec path, 16 kHz audio, 24-bit I2S slots, and a Q15 128-tap FxLMS core. The design is deliberately usable without an audio board: the local bus and the core can be driven by a testbench.

The implementation is not a completed board image. No AX7020 schematic, verified codec pin map, Vivado project, bitstream, timing report, or acoustic measurement was available when this artifact was created.

## Clock and CDC assumptions

* `sys_clk` is a 100 MHz PL clock (10 ns period).
* I2S BCLK and LRCLK are asynchronous inputs to `sys_clk` and pass through two flip-flop synchronizers.
* The compact I2S boundary detects synchronized BCLK edges in the system-clock domain. A board release must replace this with a reviewed CDC/timing implementation if the selected BCLK is too close to the system-clock limit.
* LRCLK=0 denotes the left/reference microphone slot; LRCLK=1 denotes right/error. Each slot has 32 BCLK bits: one leading dummy bit, 24 data bits, and seven zero/pad bits.

## Data path

1. `anc_i2s_if` receives one left and one right 24-bit sample and asserts `sample_valid` after a complete stereo pair.
2. `anc_fx_lms_core` shifts the reference history, computes a 128-tap signed Q15 FIR, and saturates the result to signed 24 bits.
3. In enabled/non-bypass mode it updates all coefficients with an identity secondary-path approximation: `c[i] += mu * error * x[i]`, with a total right shift of 30 bits. This is an explicit MVP, not the measured secondary-path model.
4. The core exposes the anti-noise sample and the residual sample to the I2S transmitter. Bypass mode outputs the reference sample for an A/B path check.
5. `anc_reg_bank` provides a minimal synchronous local bus for PS/AXI integration.

## Fixed-point contract

Audio samples are signed 24-bit containers with 15 fractional bits. Coefficients and `mu` are signed/unsigned 16-bit Q15 values. The FIR accumulator is 64 bits in this MVP. Output and coefficient updates saturate rather than wrap. The implementation should be profiled and pipelined before claiming a target Fmax or resource budget.

## Integration boundary

`anc_top` is intentionally independent of a specific AXI interconnect and PS address map. A Vivado block design should add a clock/reset source, an AXI-lite-to-local-bus adapter, codec I2C initialization, and verified AX7020 pin constraints. Those board-specific steps are not represented as completed evidence here.
