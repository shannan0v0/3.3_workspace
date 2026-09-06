"""Deterministic RTL/Python regression for the ANC FxLMS core.

The script generates a SystemVerilog trace bench, runs Icarus/VVP, and
compares every sample against the integer model in golden_reference.py.
It intentionally exercises disabled/bypass behavior, saturation, signed
negative LMS updates, reset, coefficient writes, and deterministic random
vectors without requiring a board or an audio device.
"""
from __future__ import annotations

import random
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
SIM = ROOT / "sim"
RTL = ROOT / "rtl"
BUILD.mkdir(exist_ok=True)

sys.path.insert(0, str(Path(__file__).resolve().parent))
from golden_reference import CoreModel, MIN24, MAX24  # noqa: E402


# Event format: ("reset",), ("write", index, value), or
# ("sample", reference, error, enable, bypass, mu).
def make_events():
    events = [("reset",)]
    events += [("write", 0, 32767), ("write", 1, 32767), ("write", 2, -32768)]
    events += [
        ("sample", 0, 0, 0, 0, 0),
        ("sample", MAX24, 0, 0, 0, 0),       # disabled still computes clip status
        ("sample", MAX24, 0, 1, 0, 0),
        ("sample", MAX24, 0, 1, 0, 0),       # FIR output saturation
        ("sample", MIN24, 0, 1, 1, 0),       # explicit bypass, signed boundary
        ("sample", -1, -1, 1, 0, 0),
        ("sample", 1, 1, 1, 0, 0),
    ]
    events += [("reset",)]
    events += [
        ("sample", 32768, -32768, 1, 0, 32767),  # negative update quadrant
        ("sample", 32768, 0, 1, 0, 0),
        ("sample", -32768, 32768, 1, 0, 16384),
        ("sample", 65536, -65536, 1, 0, 4096),
    ]
    events += [("reset",), ("write", 0, 12000), ("write", 1, -7000), ("write", 2, 3000)]

    rng = random.Random(0xA0C2026)
    # Deterministic random regression.  Values intentionally include ordinary
    # and boundary samples; enable/bypass/mu vary independently.
    special = [MIN24, MAX24, -1, 0, 1, -32768, 32767, 65536, -65536]
    for i in range(192):
        if i < len(special):
            ref = special[i]
            err = special[-1 - i]
        else:
            ref = rng.randint(-120000, 120000)
            err = rng.randint(-90000, 90000)
        enable = 0 if i % 17 == 0 else 1
        bypass = 1 if i % 23 == 0 else 0
        mu = (0, 32, 256, 1024, 4096, 16384)[i % 6]
        events.append(("sample", ref, err, enable, bypass, mu))
    return events


def sv_num(value: int, width: int) -> str:
    if value < 0:
        return f"-{width}'sd{-value}"
    return f"{width}'sd{value}"


def make_sv(events: list[tuple]) -> str:
    lines = [
        "`timescale 1ns/1ps",
        "module tb_anc_rtl_python_regression;",
        "  logic clk=0; always #5 clk=~clk;",
        "  logic rst, sample_valid, enable, bypass;",
        "  logic signed [23:0] ref_sample, error_sample;",
        "  logic [15:0] mu_q15;",
        "  logic coeff_wr_en; logic [6:0] coeff_wr_addr;",
        "  logic signed [15:0] coeff_wr_data;",
        "  logic sample_out_valid;",
        "  logic signed [23:0] anti_noise_sample, residual_sample;",
        "  logic [31:0] sample_count, clip_count;",
        "  integer trace_idx=0;",
        "  anc_fx_lms_core dut (.*);",
        "  task automatic do_reset; begin",
        "    rst=1; sample_valid=0; coeff_wr_en=0; enable=0; bypass=0;",
        "    ref_sample=0; error_sample=0; mu_q15=0;",
        "    repeat(2) @(posedge clk); @(negedge clk); rst=0;",
        "  end endtask",
        "  task automatic do_write(input integer a, input integer d); begin",
        "    @(negedge clk); coeff_wr_addr=a[6:0]; coeff_wr_data=d; coeff_wr_en=1;",
        "    @(posedge clk); #1; @(negedge clk); coeff_wr_en=0;",
        "  end endtask",
        "  task automatic do_sample(input integer r, input integer e,",
        "      input integer en, input integer bp, input integer mu); begin",
        "    @(negedge clk); ref_sample=r; error_sample=e; enable=en; bypass=bp;",
        "      mu_q15=mu[15:0]; sample_valid=1;",
        "    @(posedge clk); #1;",
        "    if (!sample_out_valid) $fatal(1, \"NO_SAMPLE_VALID idx=%0d\", trace_idx);",
        "    $display(\"TRACE %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d\",",
        "      trace_idx, $signed(anti_noise_sample), $signed(residual_sample),",
        "      sample_count, clip_count, $signed(dut.coeff[0]),",
        "      $signed(dut.coeff[1]), $signed(dut.coeff[2]),",
        "      $signed(dut.coeff[127]), $signed(ref_sample));",
        "    trace_idx=trace_idx+1; @(negedge clk); sample_valid=0;",
        "  end endtask",
        "  initial begin",
    ]
    for event in events:
        if event[0] == "reset":
            lines.append("    do_reset;")
        elif event[0] == "write":
            _, addr, data = event
            lines.append(f"    do_write({addr}, {sv_num(data, 16)});")
        else:
            _, ref, err, enable, bypass, mu = event
            lines.append(
                f"    do_sample({sv_num(ref, 24)}, {sv_num(err, 24)}, "
                f"{enable}, {bypass}, {mu});"
            )
    lines += [
        "    $display(\"RTL_REGRESSION_PASS samples=%0d\", trace_idx);",
        "    $finish;",
        "  end",
        "endmodule",
        "",
    ]
    return "\n".join(lines)


def expected_trace(events: list[tuple]):
    model = CoreModel()
    rows = []
    idx = 0
    for event in events:
        if event[0] == "reset":
            model = CoreModel()
        elif event[0] == "write":
            _, addr, value = event
            model.write_coeff(addr, value)
        else:
            _, ref, err, enable, bypass, mu = event
            anti, residual = model.sample(ref, err, bool(enable), bool(bypass), mu)
            rows.append((idx, anti, residual, model.samples, model.clips,
                         model.coeff[0], model.coeff[1], model.coeff[2],
                         model.coeff[127], ref))
            idx += 1
    return rows


def find_tool(name: str, fallback: str) -> str | None:
    return shutil.which(name) or (fallback if Path(fallback).exists() else None)


def main() -> int:
    events = make_events()
    expected = expected_trace(events)
    sv_path = BUILD / "tb_anc_rtl_python_regression.sv"
    vvp_path = BUILD / "tb_anc_rtl_python_regression.vvp"
    out_path = BUILD / "rtl_python_regression_run.txt"
    err_path = BUILD / "rtl_python_regression_stderr.txt"
    sv_path.write_text(make_sv(events), encoding="ascii")

    iverilog = find_tool("iverilog", r"D:\iverilog\bin\iverilog.exe")
    vvp = find_tool("vvp", r"D:\iverilog\bin\vvp.exe")
    if not iverilog or not vvp:
        print("REGRESSION_ENV_FAIL missing iverilog/vvp")
        return 2

    compile_cmd = [
        iverilog, "-g2012", "-s", "tb_anc_rtl_python_regression",
        "-o", str(vvp_path), str(RTL / "anc_fx_lms_core.sv"), str(sv_path),
    ]
    comp = subprocess.run(compile_cmd, cwd=ROOT, text=True,
                          capture_output=True, timeout=60)
    (BUILD / "rtl_python_regression_compile_stdout.txt").write_text(comp.stdout, encoding="utf-8")
    (BUILD / "rtl_python_regression_compile_stderr.txt").write_text(comp.stderr, encoding="utf-8")
    print(f"REGRESSION_COMPILE_RC={comp.returncode}")
    if comp.returncode:
        print(comp.stderr)
        return 1

    run = subprocess.run([vvp, str(vvp_path)], cwd=ROOT, text=True,
                         capture_output=True, timeout=120)
    out_path.write_text(run.stdout, encoding="utf-8")
    err_path.write_text(run.stderr, encoding="utf-8")
    print(f"REGRESSION_RUN_RC={run.returncode}")
    if run.stderr.strip():
        print("REGRESSION_STDERR_PRESENT=1")
    actual = []
    for line in run.stdout.splitlines():
        fields = line.split()
        if fields and fields[0] == "TRACE":
            if len(fields) != 11:
                print("REGRESSION_PARSE_FAIL", line)
                return 1
            actual.append(tuple(int(x) for x in fields[1:]))
    if run.returncode:
        print(run.stdout)
        print(run.stderr)
        return 1
    if len(actual) != len(expected):
        print(f"REGRESSION_TRACE_COUNT_FAIL expected={len(expected)} actual={len(actual)}")
        return 1
    for pos, (got, want) in enumerate(zip(actual, expected)):
        if got != want:
            print(f"REGRESSION_MISMATCH row={pos}")
            print("GOT   =", got)
            print("EXPECT=", want)
            return 1
    if "RTL_REGRESSION_PASS" not in run.stdout:
        print("REGRESSION_PASS_MARKER_FAIL")
        return 1
    print(f"RTL_PYTHON_REGRESSION_PASS samples={len(actual)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
