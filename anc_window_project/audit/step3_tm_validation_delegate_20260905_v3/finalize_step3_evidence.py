from __future__ import annotations

import hashlib
import importlib.util
import json
import re
import sys
from collections import OrderedDict
from pathlib import Path

CONTEXT_PATH = Path(r"D:\GenericAgent-Desktop-Windows-Portable\runtime\app\temp\step3_tm_validation_delegate_20260905_v4\context.json")
REQUIRED_CASES = [
    "reset",
    "coefficient_write",
    "bypass",
    "all_128_taps",
    "saturation",
    "negative_update_direction",
    "busy",
    "overrun_protection",
    "continuous_samples",
]
INPUT_KEYS = ["rst", "sv", "en", "bp", "ref", "err", "mu", "cwen", "caddr", "cdata"]
OUTPUT_KEYS = ["ready", "cwready", "busy", "ov", "ovc", "valid", "anti", "residual", "sc", "clip"]
TRACE_RE = re.compile(r"^TRACE\s+tag=(\S+)\s+(.*)$")
PAIR_RE = re.compile(r"(\w+)=(-?\d+)")
CASE_BEGIN_RE = re.compile(r"^CASE_BEGIN\s+(\S+)\s*$")
CASE_RESULT_RE = re.compile(r"^CASE\s+(\S+)\s+(PASS|FAIL)\s*$")
CHECK_RE = re.compile(r"^CHECK\s+(PASS|FAIL)\s+case_item=(\S+)\s+(?:value=(-?\d+)|actual=(-?\d+)\s+expected=(-?\d+))")
SUMMARY_RE = re.compile(r"^SUMMARY\s+failures=(\d+)\s+trace_edges=(\d+)\s*$")
METRIC_RE = re.compile(r"^TB_METRIC\s+(\w+)=(-?\d+)\s*$")


def load_context() -> tuple[dict, dict]:
    if not CONTEXT_PATH.is_file():
        raise FileNotFoundError(f"context missing: {CONTEXT_PATH}")
    context = json.loads(CONTEXT_PATH.read_text(encoding="utf-8"))
    paths = {**context["input_files"], **context["output_files"]}
    missing = [name for name, value in paths.items() if name not in {"python_comparison", "throughput", "report", "finalizer_script", "finalizer_stdout", "finalizer_stderr", "finalizer_rc"} and not Path(value).is_file()]
    if missing:
        raise FileNotFoundError("context input missing: " + ", ".join(missing))
    return context, paths


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def import_model(model_path: Path):
    spec = importlib.util.spec_from_file_location("independent_tm_fx_lms_cycle_model", model_path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot import independent model: {model_path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def parse_trace_line(line: str) -> tuple[str, dict[str, int]]:
    match = TRACE_RE.match(line)
    if not match:
        raise ValueError(f"malformed TRACE line: {line[:240]}")
    tag, rest = match.groups()
    pairs = {key: int(value) for key, value in PAIR_RE.findall(rest)}
    required = set(INPUT_KEYS + OUTPUT_KEYS + ["edge"])
    absent = sorted(required - set(pairs))
    if absent:
        raise ValueError(f"TRACE {tag} missing fields: {absent}")
    return tag, pairs


def format_command(script_path: Path) -> str:
    return f'"{sys.executable}" "{script_path}"'


def main() -> int:
    context, p = load_context()
    model_module = import_model(Path(p["cycle_model"]))
    model = model_module.TmFxLmsCycleModel()
    tb_stdout = Path(p["tb_stdout"])
    tb_stderr = Path(p["tb_stderr"])
    tb_rc = Path(p["tb_rc"])
    tb_lines = tb_stdout.read_text(encoding="utf-8", errors="replace").splitlines()
    stderr_text = tb_stderr.read_text(encoding="utf-8", errors="replace")
    rc_text = tb_rc.read_text(encoding="utf-8", errors="replace").strip()
    try:
        tb_returncode = int(rc_text)
    except ValueError as exc:
        raise ValueError(f"TB RC is not an integer: {rc_text!r}") from exc

    case_stats: OrderedDict[str, dict] = OrderedDict(
        (name, {"trace_edges": 0, "model_mismatches": 0, "model_outputs": 0, "model_transactions": 0, "tb_result": None, "first_mismatch": None, "max_overrun": 0})
        for name in REQUIRED_CASES
    )
    current_case: str | None = None
    case_results: dict[str, str] = {}
    mismatch_rows: list[dict] = []
    trace_count = 0
    previous_edge = 0
    expected_edge = 1
    model_selftest_model = model_module.TmFxLmsCycleModel()
    model_selftest_model.tick(rst=1)
    selftest_ok = model_selftest_model.outputs(rst=1)["sample_ready"] == 0 and model_selftest_model.tick()["sample_ready"] == 1
    checks_pass = 0
    checks_fail = 0
    check_fail_lines: list[str] = []
    summary = None
    metrics: dict[str, int] = {}
    overrun_check_value = None

    for line_no, line in enumerate(tb_lines, start=1):
        if begin := CASE_BEGIN_RE.match(line):
            current_case = begin.group(1)
            if current_case not in case_stats:
                raise ValueError(f"unknown case at TB stdout line {line_no}: {current_case}")
            continue
        if result := CASE_RESULT_RE.match(line):
            case_name, result_value = result.groups()
            case_results[case_name] = result_value
            if case_name not in case_stats:
                raise ValueError(f"unknown case result at TB stdout line {line_no}: {case_name}")
            case_stats[case_name]["tb_result"] = result_value
            continue
        if check := CHECK_RE.match(line):
            status, item, value, actual, expected = check.groups()
            if status == "PASS":
                checks_pass += 1
            else:
                checks_fail += 1
                check_fail_lines.append(line)
            if item == "overrun.final_count" and value is not None:
                overrun_check_value = int(value)
            continue
        if summary_match := SUMMARY_RE.match(line):
            summary = (int(summary_match.group(1)), int(summary_match.group(2)))
            continue
        if metric := METRIC_RE.match(line):
            metrics[metric.group(1)] = int(metric.group(2))
            continue
        if line.startswith("TRACE "):
            if current_case is None:
                raise ValueError(f"TRACE before CASE_BEGIN at TB stdout line {line_no}")
            tag, values = parse_trace_line(line)
            edge = values["edge"]
            if edge != expected_edge:
                raise ValueError(f"non-contiguous trace edge at line {line_no}: got {edge}, expected {expected_edge}")
            previous_edge = edge
            expected_edge += 1
            trace_count += 1
            stat = case_stats[current_case]
            stat["trace_edges"] += 1
            accepted_edge = (not values["rst"]) and model.state == "IDLE" and bool(values["sv"])
            predicted = model.tick(
                rst=values["rst"], sample_valid=values["sv"], enable=values["en"], bypass=values["bp"],
                ref_sample=values["ref"], error_sample=values["err"], mu_q15=values["mu"],
                coeff_wr_en=values["cwen"], coeff_wr_addr=values["caddr"], coeff_wr_data=values["cdata"],
            )
            stat["model_transactions"] += int(accepted_edge)
            stat["model_outputs"] += int(predicted["sample_out_valid"])
            stat["max_overrun"] = max(stat["max_overrun"], int(predicted["overrun_count"]))
            actual = {"ready": values["ready"], "cwready": values["cwready"], "busy": values["busy"], "ov": values["ov"], "ovc": values["ovc"], "valid": values["valid"], "anti": values["anti"], "residual": values["residual"], "sc": values["sc"], "clip": values["clip"]}
            predicted_visible = {"ready": predicted["sample_ready"], "cwready": predicted["coeff_wr_ready"], "busy": predicted["busy"], "ov": predicted["overrun"], "ovc": predicted["overrun_count"], "valid": predicted["sample_out_valid"], "anti": predicted["anti_noise_sample"], "residual": predicted["residual_sample"], "sc": predicted["sample_count"], "clip": predicted["clip_count"]}
            differences = {key: {"rtl": actual[key], "python": predicted_visible[key]} for key in OUTPUT_KEYS if actual[key] != predicted_visible[key]}
            if differences:
                stat["model_mismatches"] += 1
                row = {"line": line_no, "edge": edge, "case": current_case, "tag": tag, "differences": differences}
                mismatch_rows.append(row)
                if stat["first_mismatch"] is None:
                    stat["first_mismatch"] = row

    expected_summary = (0, 2608)
    required_metrics = {"active_clocks_per_enabled_sample": 257, "fir_taps_per_enabled_sample": 128, "budget_clocks_per_sample": 6250}
    summary_ok = summary == expected_summary
    metrics_ok = all(metrics.get(k) == value for k, value in required_metrics.items())
    case_names_ok = list(case_results) == REQUIRED_CASES
    cases_ok = all(stat["tb_result"] == "PASS" and stat["model_mismatches"] == 0 and stat["trace_edges"] > 0 for stat in case_stats.values())
    overrun_ok = overrun_check_value == 2 and case_stats["overrun_protection"]["max_overrun"] == 2
    trace_ok = trace_count == 2608 and previous_edge == 2608
    tb_ok = tb_returncode == 0 and summary_ok and checks_fail == 0 and checks_pass == 3683
    all_checks_ok = bool(selftest_ok and trace_ok and tb_ok and case_names_ok and cases_ok and metrics_ok and overrun_ok)

    audit_command = format_command(Path(p["finalizer_script"]))
    evidence_lines = [
        f"- Context: `{CONTEXT_PATH}`",
        f"- Independent model imported and executed from `{Path(p['cycle_model'])}`.",
        f"- Real TB source: `{Path(p['tb_source'])}`",
        f"- Real TB stdout: `{tb_stdout}`",
        f"- Real TB stderr: `{tb_stderr}`",
        f"- Real TB return code: `{tb_rc}` (value `{tb_returncode}`)",
        f"- This finalizer command: `{audit_command}`",
        "- The original TB compile/run shell command was not preserved in the context; no compile command is inferred here.",
    ]
    hashes = [
        ("tb.sv", Path(p["tb_source"])), ("tb.stdout.txt", tb_stdout), ("tb.stderr.txt", tb_stderr), ("tb.rc.txt", tb_rc), ("cycle_model.py", Path(p["cycle_model"])),
    ]
    hash_lines = [f"- `{name}`: {path.stat().st_size} bytes, SHA-256 `{sha256(path)}`" for name, path in hashes]
    case_rows = []
    for name, stat in case_stats.items():
        case_rows.append(f"| {name} | {stat['tb_result'] or 'MISSING'} | {'PASS' if stat['model_mismatches'] == 0 and stat['trace_edges'] > 0 else 'FAIL'} | {stat['trace_edges']} | {stat['model_transactions']} | {stat['model_outputs']} | {stat['model_mismatches']} | {stat['max_overrun']} |")
    mismatch_detail = "none"
    if mismatch_rows:
        mismatch_detail = json.dumps(mismatch_rows[:10], ensure_ascii=False, indent=2)

    python_report = "\n".join([
        "# Independent Python cycle-model comparison",
        "",
        "This report is generated by executing the independent integer model and replaying every real RTL TB `TRACE` edge. It is not a grep-only marker check.",
        "",
        *evidence_lines,
        "",
        "## Replay result",
        f"- TRACE edges parsed: **{trace_count}**; contiguous edge range: **1..{previous_edge}**; expected 2608: **{'PASS' if trace_ok else 'FAIL'}**.",
        f"- Model self-test/reset sanity: **{'PASS' if selftest_ok else 'FAIL'}**.",
        f"- Visible output fields compared per edge: `{', '.join(OUTPUT_KEYS)}` (10 fields).",
        f"- Total mismatching edges: **{len(mismatch_rows)}**; total field mismatches: **{sum(len(row['differences']) for row in mismatch_rows)}**.",
        f"- TB checks: PASS **{checks_pass}**, FAIL **{checks_fail}**; summary `failures={summary[0] if summary else 'MISSING'} trace_edges={summary[1] if summary else 'MISSING'}`; TB RC **{tb_returncode}**.",
        "",
        "## Required nine-case table",
        "| Case | TB marker | Independent model | Trace edges | Accepted transactions | Output pulses | Mismatching edges | Max overrun count |",
        "|---|---|---|---:|---:|---:|---:|---:|",
        *case_rows,
        "",
        "## Mismatch detail",
        "```json",
        mismatch_detail,
        "```",
        "",
        "## Evidence hashes",
        *hash_lines,
        "",
        "The TB stderr is preserved and cited rather than discarded; it contains Icarus diagnostic warnings. Local Icarus/Python evidence establishes the simulated interface behavior only; it does not establish Vivado timing closure, implementation, bitstream, board pins, codec operation, or acoustic performance.",
    ])

    clocks_budget = 6250
    active_clocks = 257
    margin = clocks_budget - active_clocks
    utilization = active_clocks / clocks_budget * 100.0
    throughput_report = "\n".join([
        "# Step 3[D] throughput budget",
        "",
        *evidence_lines,
        "",
        "| Quantity | Value | Calculation/meaning |",
        "|---|---:|---|",
        f"| Clock frequency | 100 MHz | Contract budget assumption |",
        f"| Sample rate | 16 kHz | Contract boundary |",
        f"| Budget clocks/sample | {clocks_budget} | 100,000,000 / 16,000 |",
        f"| Active clocks/sample | {active_clocks} | 128 FIR + 1 gradient + 128 delta |",
        f"| Margin | {margin} clocks | {clocks_budget} - {active_clocks} |",
        f"| Nominal utilization | {utilization:.3f}% | {active_clocks} / {clocks_budget} × 100 |",
        f"| TB reported active clocks | {metrics.get('active_clocks_per_enabled_sample', 'MISSING')} | Must equal 257 |",
        f"| TB reported budget | {metrics.get('budget_clocks_per_sample', 'MISSING')} | Must equal 6250 |",
        f"| TB overrun final count | {overrun_check_value if overrun_check_value is not None else 'MISSING'} | Expected 2 in overrun case |",
        "",
        f"Budget checks: **{'PASS' if metrics_ok and overrun_ok else 'FAIL'}**.",
        "",
        "This is a cycle-budget calculation, not a Vivado timing-closure result. The project still requires separate synthesis/implementation timing evidence; no board, codec, or acoustic claim follows from this table.",
    ])

    verdict = "PASS" if all_checks_ok else "FAIL"
    final_report = "\n".join([
        "# Step 3[D] independent closeout",
        "",
        "## Scope",
        "Independent closeout of the already executed `anc_fx_lms_tm_core` RTL TB. No legacy RTL, plan checkmark, board, codec, or acoustic result was modified or inferred.",
        "",
        "## Real commands and evidence",
        *evidence_lines,
        "",
        "The finalizer itself imports and executes the independent Python cycle model, then compares post-edge visible outputs against all real TB traces. The original simulator invocation command was not preserved, so it is explicitly not claimed; the preserved TB source/output/stderr/RC are the evidence of that earlier run.",
        "",
        "## Nine-case results",
        "| Case | TB marker | Python replay | Trace edges | Transactions | Output pulses | Mismatch edges |",
        "|---|---|---|---:|---:|---:|---:|",
        *[f"| {name} | {stat['tb_result'] or 'MISSING'} | {'PASS' if stat['model_mismatches'] == 0 and stat['trace_edges'] > 0 else 'FAIL'} | {stat['trace_edges']} | {stat['model_transactions']} | {stat['model_outputs']} | {stat['model_mismatches']} |" for name, stat in case_stats.items()],
        "",
        "## Global checks",
        f"- Imported model: **{'PASS' if selftest_ok else 'FAIL'}**",
        f"- Edge replay: **{'PASS' if trace_ok else 'FAIL'}** ({trace_count}/2608, last edge {previous_edge})",
        f"- TB: **{'PASS' if tb_ok else 'FAIL'}** (RC={tb_returncode}, checks {checks_pass} pass/{checks_fail} fail, summary={summary})",
        f"- Metrics: **{'PASS' if metrics_ok else 'FAIL'}** (active={metrics.get('active_clocks_per_enabled_sample')}, taps={metrics.get('fir_taps_per_enabled_sample')}, budget={metrics.get('budget_clocks_per_sample')})",
        f"- Overrun protection: **{'PASS' if overrun_ok else 'FAIL'}** (TB final={overrun_check_value}, replay max={case_stats['overrun_protection']['max_overrun']})",
        "",
        "## Boundary",
        "Python/Icarus replay proves local cycle-level behavior represented by the preserved testbench. It does not prove Vivado timing closure, implementation/bitstream generation, exact XDC pinout, board/codec operation, end-to-end latency, or acoustic A/B performance. The separate Vivado evidence remains resource-over-limit/PARTIAL as documented elsewhere.",
        "",
        f"VERDICT: {verdict}",
    ])

    Path(p["python_comparison"]).write_text(python_report + "\n", encoding="utf-8")
    Path(p["throughput"]).write_text(throughput_report + "\n", encoding="utf-8")
    Path(p["report"]).write_text(final_report + "\n", encoding="utf-8")
    print(f"MODEL_IMPORT=PASS path={p['cycle_model']}")
    print(f"TRACE_REPLAY={'PASS' if trace_ok else 'FAIL'} edges={trace_count} mismatching_edges={len(mismatch_rows)}")
    print(f"TB_RC={tb_returncode} CHECKS_PASS={checks_pass} CHECKS_FAIL={checks_fail} SUMMARY={summary}")
    print(f"CASE_RESULTS={json.dumps({name: {'tb': stat['tb_result'], 'model_mismatches': stat['model_mismatches'], 'edges': stat['trace_edges'], 'transactions': stat['model_transactions']} for name, stat in case_stats.items()}, ensure_ascii=False)}")
    print(f"THROUGHPUT budget={clocks_budget} active={active_clocks} margin={margin} utilization_percent={utilization:.3f}")
    print(f"REPORTS={p['python_comparison']}|{p['throughput']}|{p['report']}")
    print(f"VERDICT: {verdict}")
    return 0 if all_checks_ok else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"FINALIZER_ERROR: {type(exc).__name__}: {exc}", file=sys.stderr)
        raise
