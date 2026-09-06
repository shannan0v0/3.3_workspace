#!/usr/bin/env python3
"""Compile and run the interface-preparation simulations with captured evidence."""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
BUILD.mkdir(exist_ok=True)

CASES = [
    (
        "axi",
        "tb_axi_lite_local_bridge",
        ["rtl/anc_axi_lite_local_bridge.sv", "rtl/anc_reg_bank.sv", "sim/tb_axi_lite_local_bridge.sv"],
        "TB_AXI_PASS",
    ),
    (
        "i2c",
        "tb_anc_i2c_byte_writer",
        ["rtl/anc_i2c_byte_writer.sv", "sim/tb_anc_i2c_byte_writer.sv"],
        "TB_I2C_PASS",
    ),
    (
        "cdc",
        "tb_anc_cdc_pulse_bridge",
        ["rtl/anc_cdc_pulse_bridge.sv", "sim/tb_anc_cdc_pulse_bridge.sv"],
        "TB_CDC_PASS",
    ),
]


def run_capture(name: str, command: list[str], log_stem: str) -> subprocess.CompletedProcess[str]:
    print("COMMAND:", " ".join(command))
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    (BUILD / f"{log_stem}.stdout.txt").write_text(result.stdout, encoding="utf-8")
    (BUILD / f"{log_stem}.stderr.txt").write_text(result.stderr, encoding="utf-8")
    print(f"{name}: returncode={result.returncode}")
    if result.stdout.strip():
        print(result.stdout.strip())
    if result.stderr.strip():
        print("STDERR:", result.stderr.strip())
    return result


def main() -> int:
    iverilog = shutil.which("iverilog")
    vvp = shutil.which("vvp")
    if not iverilog or not vvp:
        print("INTERFACE_CHECKS_BLOCKED: iverilog/vvp not found")
        return 2

    failures = 0
    for name, top, sources, marker in CASES:
        output = BUILD / f"tb_{name}.vvp"
        compile_cmd = [iverilog, "-g2012", "-s", top, "-o", str(output)] + sources
        compiled = run_capture(name + " compile", compile_cmd, f"interface_{name}_compile")
        if compiled.returncode != 0:
            failures += 1
            continue
        simulated = run_capture(name + " simulation", [vvp, str(output)], f"interface_{name}_run")
        if simulated.returncode != 0 or marker not in simulated.stdout:
            failures += 1

    if failures:
        print(f"INTERFACE_CHECKS_FAIL cases={failures}")
        return 1
    print("INTERFACE_CHECKS_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
