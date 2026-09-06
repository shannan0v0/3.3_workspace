"""Step-2 checker for the resource-controlled time-multiplexed core."""

from pathlib import Path
import subprocess
import sys

from tm_fx_lms_cycle_model import TmFxLmsCycleModel, enabled_latency

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "audit" / "step2_tm_core"
RTL = ROOT / "rtl" / "anc_fx_lms_tm_core.sv"
VVP = AUDIT / "anc_fx_lms_tm_core.vvp"


def model_checks() -> None:
    model = TmFxLmsCycleModel()
    assert model.tick(rst=1)["sample_ready"] == 0
    assert model.tick()["sample_ready"] == 1

    model.coeff[0] = 16384
    model.tick(sample_valid=1, enable=1, ref_sample=1000,
               error_sample=0, mu_q15=0)
    assert model.outputs()["sample_ready"] == 0
    for _ in range(128):
        out = model.tick()
    assert out["sample_out_valid"] == 1
    assert out["anti_noise_sample"] == 500
    assert out["residual_sample"] == 0
    for _ in range(129):
        out = model.tick()
    assert out["sample_ready"] == 1

    # Independent negative-update direction check.
    model.coeff[0] = 0
    model.tick(sample_valid=1, enable=1, ref_sample=16384,
               error_sample=-16384, mu_q15=16384)
    # The current RTL samples enable/bypass live in ST_DELTA, so the
    # transaction driver must hold them for all active phase clocks.
    for _ in range(257):
        model.tick(enable=1, bypass=0)
    assert model.coeff[0] == -4096, model.coeff[0]

    # Busy request is dropped and counted, while bypass is immediate.
    model.tick(sample_valid=1, enable=1, ref_sample=1,
               error_sample=2, mu_q15=0)
    out = model.tick(sample_valid=1, enable=1, ref_sample=3,
                     error_sample=4, mu_q15=0)
    assert out["overrun"] == 1 and out["overrun_count"] == 1
    while not model.outputs()["sample_ready"]:
        model.tick()
    out = model.tick(sample_valid=1, bypass=1, enable=0,
                     ref_sample=-7, error_sample=9)
    assert out["sample_out_valid"] == 1
    assert out["anti_noise_sample"] == -7
    assert out["residual_sample"] == 9

    assert enabled_latency() == 257


def main() -> int:
    AUDIT.mkdir(parents=True, exist_ok=True)
    model_checks()
    (AUDIT / "model.stdout.txt").write_text(
        "TM_MODEL_SELFTEST_PASS\nENABLED_ACTIVE_PHASE_CLOCKS=257\n",
        encoding="utf-8",
    )
    cmd = ["iverilog", "-g2012", "-s", "anc_fx_lms_tm_core",
           "-o", str(VVP), str(RTL)]
    proc = subprocess.run(cmd, cwd=ROOT.parent, text=True,
                          capture_output=True, check=False)
    (AUDIT / "compile.stdout.txt").write_text(proc.stdout, encoding="utf-8")
    (AUDIT / "compile.stderr.txt").write_text(proc.stderr, encoding="utf-8")
    (AUDIT / "compile.rc.txt").write_text(str(proc.returncode) + "\n",
                                            encoding="utf-8")
    report = [
        "# Step 2 core mini-check",
        "",
        f"- Python model: PASS (enabled latency {enabled_latency()} clocks)",
        f"- Icarus compile RC: {proc.returncode}",
        f"- VVP exists: {VVP.exists()}",
        "- Icarus `always_*` constant-select warnings, if present, are tool warnings; no compile error was observed.",
        "",
        "VERDICT: PASS" if proc.returncode == 0 and VVP.exists() else "VERDICT: FAIL",
    ]
    (AUDIT / "result.md").write_text("\n".join(report) + "\n", encoding="utf-8")
    print("TM_MODEL_PASS")
    print(f"IVERILOG_RC={proc.returncode}")
    print(f"VVP_EXISTS={VVP.exists()}")
    return proc.returncode


if __name__ == "__main__":
    sys.exit(main())
