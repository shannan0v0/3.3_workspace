# ANC Register Map

The local bus is a synchronous request interface: assert `bus_valid` for one `sys_clk` cycle, set `bus_write=1` for a write, and hold `bus_addr`/`bus_wdata` stable for that cycle. `bus_ready` is permanently high in this MVP. A read returns `bus_rvalid=1` for one clock and the combinational `bus_rdata` value for the requested address.

All addresses are byte addresses. Values are little-endian 32-bit words at the adapter boundary.

| Address | Name | Access | Meaning |
|---:|---|---|---|
| 0x000 | CONTROL | RW | bit 0: enable; bit 1: bypass. Reset is disabled + bypass. |
| 0x004 | MU_Q15 | RW | FxLMS step size, lower 16 bits, default 64. |
| 0x008 | STATUS | RO | bit 0 is nonzero after any sample; bit 1 is nonzero after any clip. |
| 0x00C | SAMPLE_COUNT | RO | Number of accepted stereo samples, saturating only by 32-bit wrap in this MVP. |
| 0x010 | CLIP_COUNT | RO | Number of FIR results outside the signed 24-bit range. |
| 0x014 | ANTI_NOISE | RO | Sign-extended latest 24-bit anti-noise output. |
| 0x018 | RESIDUAL | RO | Sign-extended latest 24-bit residual/error sample. |
| 0x100 + 4*i | COEFF[i] | WO | Signed Q15 coefficient write, `i=0..127`, lower 16 bits used. |

## Safe bring-up sequence

1. Hold reset and confirm `CONTROL=0x2` after reset.
2. Write coefficient values, normally zero or a measured initial model.
3. Set `MU_Q15` to a small value.
4. Run bypass first (`CONTROL=0x3`), then enable with bypass cleared (`CONTROL=0x1`).
5. Read counters and output samples while the offline model checks stability.

The addresses are a PL-side contract only. The PS physical address and AXI adapter must be assigned in the future Vivado design.
