# Interface preparation evidence boundary

## Purpose

This note records simulation-first preparation only. It does not assign a PS
base address, FPGA pin, codec address, codec register value, clock frequency,
or board-specific electrical property.

## AXI4-Lite to local bus

`rtl/anc_axi_lite_local_bridge.sv` accepts AXI4-Lite AW and W independently,
then presents one request on the existing local bus used by `anc_reg_bank`.
Reads wait for `bus_rvalid`. The local bus has no byte-enable signal, so only
`WSTRB=4'b1111` is forwarded; any partial write returns AXI `SLVERR` and does
not change a register. There is one outstanding operation at a time. The
adapter is deliberately not a complete Vivado block-design connection and
provides no PS address-map claim.

## Generic I2C byte writer

`rtl/anc_i2c_byte_writer.sv` generates an open-drain START, three-byte
transaction (`{device_addr,1'b0}`, `register_addr`, `register_data`), ACK/NACK
sampling, and STOP. `scl_oe_low` and `sda_oe_low` must be connected to suitable
open-drain IO cells and pull-ups in a future board design. Clock stretching,
arbitration, bus recovery, and codec initialization policy are not implemented.
The caller supplies all address/data bytes; no WM8731 configuration is asserted.

## CDC event bridge

`rtl/anc_cdc_pulse_bridge.sv` transfers a source event by toggle through two
flip-flops and emits a one-destination-clock pulse. Source and destination
resets are expected to be asserted together at initialization. Events must be
spaced so that the destination observes each toggle; there is no event queue or
back-pressure. This is a reviewable primitive, not evidence of complete clock,
reset, or audio-domain closure.

## Reproducible local checks

From this project directory:

```text
python scripts/run_interface_checks.py
```

The runner compiles and runs the AXI, I2C, and CDC self-checking testbenches,
capturing stdout/stderr under `build/interface_*`. Passing markers prove only
the tested RTL behaviors in Icarus; they do not prove Vivado synthesis,
timing, IO constraints, codec bring-up, board operation, or acoustic results.
