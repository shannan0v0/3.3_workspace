# PS integration example

`anc_regs.h` defines the PL register offsets and safe configuration sequence.
`anc_bringup.c` shows how a Zynq PS application could call it after the Vivado
AXI-Lite physical base address has been assigned.

No physical base address is included because the AXI adapter and Vivado block
design do not exist in the current verified artifact. Do not use address zero
on hardware; pass the platform's mapped, uncached MMIO base pointer instead.
