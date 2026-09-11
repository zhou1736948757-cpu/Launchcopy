#!/usr/bin/env python3
"""Privacy-safe analysis of opt-in RunLoop Timer callback boundary JSONL.

The successful report never copies unknown input fields, run IDs, paths, URLs,
application identities, or raw runloop modes. It reports only fixed schema
fields, fixed anonymous mode categories, callback ordinals, and durations.
"""

from __future__ import annotations

import argparse
import json
import math
import statistics
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

ALLOWED_MODES = ("default", "eventTracking", "modalPanel", "other", "none")
THRESHOLDS_MS = (20.0, 25.0, 33.3, 50.0)


class InputDataError(ValueError):
    pass


def _number(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)) and math.isfinite(float(value)):
        return float(value)
    return None


def _integer(value: Any) -> int | None:
    number = _number(value)
    if number is None or not number.is_integer():
        return None
    return int(number)


def _ms(ns: Any) -> float | None:
    number = _number(ns)
    return None if number is None else number / 1_000_000.0


def _percentile(values: list[float], quantile: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    index = (len(ordered) - 1) * quantile
    lower = math.floor(index)
    upper = math.ceil(index)
    if lower == upper:
        return ordered[lower]
    fraction = index - lower
    return ordered[lower] * (1 - fraction) + ordered[upper] * fraction


def _summary(values: list[float]) -> dict[str, float | int | None]:
    return {
        "count": len(values),
        "min_ms": min(values) if values else None,
        "median_ms": statistics.median(values) if values else None,
        "p95_ms": _percentile(values, 0.95),
        "p99_ms": _percentile(values, 0.99),
        "max_ms": max(values) if values else None,
    }


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    try:
        lines = path.read_text().splitlines()
    except OSError as error:
        raise InputDataError(f"cannot read {path}: {error}") from error
    records: list[dict[str, Any]] = []
    for line_number, line in enumerate(lines, 1):
        if not line.strip():
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError as error:
            raise InputDataError(f"invalid JSONL at {path}:{line_number}: {error}") from error
        if not isinstance(value, dict):
            raise InputDataError(f"expected JSON object at {path}:{line_number}")
        records.append(value)
    return records


def _accepted(records: Iterable[dict[str, Any]]) -> tuple[list[dict[str, Any]], dict[str, int]]:
    accepted: list[dict[str, Any]] = []
    counts = {
        "input_record_count": 0,
        "ignored_non_callback_count": 0,
        "rejected_callback_count": 0,
    }
    for record in records:
        counts["input_record_count"] += 1
        if record.get("kind") != "frame_callback":
            counts["ignored_non_callback_count"] += 1
            continue
        generation = _integer(record.get("driver_generation"))
        sequence = _integer(record.get("callback_seq"))
        interval_ns = _number(record.get("nominal_interval_ns"))
        entry_ns = _number(record.get("entry_ns"))
        scheduled_ns = _number(record.get("scheduled_ns"))
        exit_ns = _number(record.get("exit_ns"))
        if None in (generation, sequence, interval_ns, entry_ns, scheduled_ns, exit_ns):
            counts["rejected_callback_count"] += 1
            continue
        mode = record.get("mode")
        accepted.append({
            "driver_generation": generation,
            "callback_seq": sequence,
            "nominal_interval_ms": interval_ns / 1_000_000.0,
            "scheduled_ns": scheduled_ns,
            "entry_ns": entry_ns,
            "exit_ns": exit_ns,
            "lateness_ms": _ms(record.get("lateness_ns")),
            "missed_periods": _integer(record.get("missed_periods")),
            "first_tick": record.get("first_tick") is True,
            "raw_interval_ms": _ms(record.get("raw_callback_interval_ns")),
            "simulation_dt_ms": _ms(record.get("simulation_dt_ns")),
            "callback_wall_ms": _ms(record.get("callback_wall_ns")),
            "callback_cpu_ms": _ms(record.get("callback_cpu_ns")),
            "mode": mode if mode in ALLOWED_MODES else "other",
        })
    accepted.sort(key=lambda item: (item["driver_generation"], item["callback_seq"]))
    return accepted, counts


def analyze(records: Iterable[dict[str, Any]], hitch_ms: float = 20.0) -> dict[str, Any]:
    callbacks, acceptance = _accepted(records)
    intervals = [item["raw_interval_ms"] for item in callbacks if item["raw_interval_ms"] is not None]
    lateness = [item["lateness_ms"] for item in callbacks if item["lateness_ms"] is not None]
    wall = [item["callback_wall_ms"] for item in callbacks if item["callback_wall_ms"] is not None]
    cpu = [item["callback_cpu_ms"] for item in callbacks if item["callback_cpu_ms"] is not None]
    first_ticks: list[dict[str, Any]] = []
    for item in callbacks:
        if not item["first_tick"]:
            continue
        start_ns = item["scheduled_ns"] - item["nominal_interval_ms"] * 1_000_000.0
        first_ticks.append({
            "driver_generation": item["driver_generation"],
            "callback_seq": item["callback_seq"],
            "start_to_entry_ms": (item["entry_ns"] - start_ns) / 1_000_000.0,
            "lateness_ms": item["lateness_ms"],
        })

    previous_by_generation: dict[int, dict[str, Any]] = {}
    long_intervals: list[dict[str, Any]] = []
    for item in callbacks:
        generation = item["driver_generation"]
        previous = previous_by_generation.get(generation)
        raw = item["raw_interval_ms"]
        if raw is not None and raw > hitch_ms:
            previous_wall = previous.get("callback_wall_ms") if previous else None
            previous_cpu = previous.get("callback_cpu_ms") if previous else None
            callback_external = None
            if previous_wall is not None:
                callback_external = max(raw - previous_wall, 0.0)
            long_intervals.append({
                "driver_generation": generation,
                "callback_seq": item["callback_seq"],
                "raw_interval_ms": raw,
                "nominal_interval_ms": item["nominal_interval_ms"],
                "lateness_ms": item["lateness_ms"],
                "missed_periods": item["missed_periods"],
                "preceding_callback_wall_ms": previous_wall,
                "preceding_callback_cpu_ms": previous_cpu,
                "recorded_exit_to_next_entry_residual_ms": callback_external,
                "mode": item["mode"],
            })
        previous_by_generation[generation] = item

    missed = [item["missed_periods"] or 0 for item in callbacks]
    mode_counts = Counter(item["mode"] for item in callbacks)
    threshold_counts = {f"gt_{str(value).replace('.', '_')}_ms": sum(v > value for v in intervals) for value in THRESHOLDS_MS}
    first_start = [item["start_to_entry_ms"] for item in first_ticks]
    first_lateness = [item["lateness_ms"] for item in first_ticks if item["lateness_ms"] is not None]

    return {
        "schema_version": 1,
        "privacy_note": "Fixed timing fields and anonymous mode categories only; no input identities or paths are copied.",
        "input_record_count": acceptance["input_record_count"],
        "callback_count": len(callbacks),
        "rejected_callback_count": acceptance["rejected_callback_count"],
        "ignored_non_callback_count": acceptance["ignored_non_callback_count"],
        "raw_interval_count": len(intervals),
        "recorded_generation_count": len({item["driver_generation"] for item in callbacks}),
        # Retained for machine consumers of schema version 1. This means only
        # generations with at least one accepted callback record.
        "generation_count": len({item["driver_generation"] for item in callbacks}),
        "mode_counts": {mode: mode_counts.get(mode, 0) for mode in ALLOWED_MODES},
        "interval_summary": {**_summary(intervals), **threshold_counts},
        "lateness_summary": _summary(lateness),
        "callback_wall_summary": _summary(wall),
        "callback_cpu_summary": _summary(cpu),
        "missed_periods": {
            "callbacks_with_missed_periods": sum(value > 0 for value in missed),
            "total_missed_periods": sum(missed),
            "max_missed_periods": max(missed) if missed else 0,
        },
        "first_tick_summary": {
            "count": len(first_ticks),
            "start_to_entry": _summary(first_start),
            "lateness": _summary(first_lateness),
            "ticks": first_ticks,
        },
        "long_interval_threshold_ms": hitch_ms,
        "long_intervals": long_intervals,
        "interpretation_boundary": (
            "Lateness and the recorded-exit-to-next-entry remainder are recorder-derived measurements. "
            "They do not prove that the Timer closure returned at the recorded exit, nor do they "
            "identify scheduler, RunLoop, WindowServer, AppKit, Core Animation, GPU, or any single component."
        ),
    }


def _fmt(value: Any) -> str:
    return "-" if value is None else f"{value:.3f}"


def render_markdown(report: dict[str, Any]) -> str:
    interval = report["interval_summary"]
    missed = report["missed_periods"]
    lines = [
        "# Frame Callback Cadence Report",
        "",
        f"- input records: {report['input_record_count']}",
        f"- accepted callbacks: {report['callback_count']}",
        f"- rejected callback records: {report['rejected_callback_count']}",
        f"- ignored non-callback records: {report['ignored_non_callback_count']}",
        f"- raw intervals analyzed: {report['raw_interval_count']} (first ticks have null raw interval)",
        f"- generations with at least one recorded callback: {report['recorded_generation_count']}",
        f"- interval p95/p99/max: {_fmt(interval['p95_ms'])} / {_fmt(interval['p99_ms'])} / {_fmt(interval['max_ms'])} ms",
        f"- >20 / >25 / >33.3 / >50 ms: {interval['gt_20_0_ms']} / {interval['gt_25_0_ms']} / {interval['gt_33_3_ms']} / {interval['gt_50_0_ms']}",
        f"- callbacks with missed periods: {missed['callbacks_with_missed_periods']} (total missed={missed['total_missed_periods']})",
        "",
        "## Long intervals",
        "",
        "| generation | seq | interval ms | lateness ms | missed | preceding recorded-segment wall ms | preceding recorded-segment current-thread CPU ms | recorded-exit→next-entry remainder ms | mode |",
        "|---:|---:|---:|---:|---:|---:|---:|---:|---|",
    ]
    for item in report["long_intervals"]:
        lines.append(
            f"| {item['driver_generation']} | {item['callback_seq']} | {_fmt(item['raw_interval_ms'])} | "
            f"{_fmt(item['lateness_ms'])} | {item['missed_periods'] if item['missed_periods'] is not None else '-'} | "
            f"{_fmt(item['preceding_callback_wall_ms'])} | {_fmt(item['preceding_callback_cpu_ms'])} | "
            f"{_fmt(item['recorded_exit_to_next_entry_residual_ms'])} | {item['mode']} |"
        )
    lines.extend(["", f"> {report['interpretation_boundary']}", ""])
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("callback_jsonl", type=Path)
    parser.add_argument("--hitch-ms", type=float, default=20.0)
    parser.add_argument("--format", choices=("json", "markdown"), default="markdown")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    if not math.isfinite(args.hitch_ms) or args.hitch_ms <= 0:
        parser.error("--hitch-ms must be a positive finite number")
    try:
        report = analyze(load_jsonl(args.callback_jsonl), hitch_ms=args.hitch_ms)
    except InputDataError as error:
        print(f"callback-analyzer: {error}", file=sys.stderr)
        return 2
    rendered = json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2) if args.format == "json" else render_markdown(report)
    if args.output:
        args.output.write_text(rendered + ("" if rendered.endswith("\n") else "\n"))
    else:
        print(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
