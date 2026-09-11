#!/usr/bin/env python3
"""Privacy-safe same-clock callback ↔ RunLoop correlation analyzer.

Join classes are recorder-derived observations, not root causes. The successful
report never copies unknown input fields, run IDs, paths, URLs, application
identities, or raw runloop modes. Negative, missing, overflow, sequence-
discontinuous, and cross-generation deltas are invalid and are never clamped to 0.
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
KNOWN_ACTIVITIES = {
    "entry",
    "beforeTimers",
    "beforeSources",
    "beforeWaiting",
    "afterWaiting",
    "exit",
}
JOIN_CLASSES = (
    "NO_OBSERVER_BOUNDARY",
    "WAITING_BOUNDED",
    "RUNLOOP_ACTIVE_BOUNDED",
    "MIXED_OBSERVED_BOUNDARIES",
    "UNCLASSIFIED",
    "SCHEMA_CALLBACK_WITHOUT_TAIL",
)
THRESHOLDS_MS = (20.0, 25.0, 33.3, 50.0)
UINT64_MAX = 2**64 - 1
GATE = "CAUSALITY_UNRESOLVED"
PRIVACY_NOTE = (
    "Fixed timing fields, anonymous mode categories, and observation join classes "
    "only; no input identities, paths, run IDs, or raw modes are copied."
)
INTERPRETATION_BOUNDARY = (
    "Join classes are observations of recorder-derived same-clock bounds. "
    "They do not prove Timer closure return, and they do not identify scheduler, "
    "RunLoop, WindowServer, AppKit, Core Animation, GPU, or any single component. "
    "Gate remains CAUSALITY_UNRESOLVED."
)


class InputDataError(ValueError):
    pass


def _number(value: Any) -> float | None:
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)) and math.isfinite(float(value)):
        return float(value)
    return None


def _ns(value: Any) -> int | None:
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, int):
        if 0 <= value < UINT64_MAX:
            return value
        return None
    if isinstance(value, float) and math.isfinite(value):
        if value < 0 or value >= UINT64_MAX:
            return None
        return int(value)
    return None


def _integer(value: Any) -> int | None:
    number = _number(value)
    if number is None or not number.is_integer():
        return None
    return int(number)


def _ms(ns: int | None) -> float | None:
    return None if ns is None else ns / 1_000_000.0


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


def _mode(value: Any) -> str:
    return value if value in ALLOWED_MODES else "other"


def _activity(value: Any) -> str | None:
    return value if value in KNOWN_ACTIVITIES else None


def _delta_ns(end: int | None, start: int | None) -> int | None:
    if end is None or start is None or end < start:
        return None
    return end - start


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


def _parse_callback(record: dict[str, Any]) -> dict[str, Any] | None:
    generation = _integer(record.get("driver_generation"))
    sequence = _integer(record.get("callback_seq"))
    interval_ns = _ns(record.get("nominal_interval_ns"))
    entry_ns = _ns(record.get("entry_ns"))
    scheduled_ns = _ns(record.get("scheduled_ns"))
    exit_ns = _ns(record.get("exit_ns"))
    if None in (generation, sequence, interval_ns, entry_ns, scheduled_ns, exit_ns):
        return None

    has_pre_return_key = "pre_return_ns" in record
    pre_return_raw = record.get("pre_return_ns")
    schema_without_tail = (not has_pre_return_key) or pre_return_raw is None
    pre_return_ns = None if schema_without_tail else _ns(pre_return_raw)
    pre_return_invalid = (not schema_without_tail) and pre_return_ns is None

    raw_present = "raw_callback_interval_ns" in record and record.get("raw_callback_interval_ns") is not None
    raw_interval_ns = _ns(record.get("raw_callback_interval_ns")) if raw_present else None
    raw_interval_invalid = raw_present and raw_interval_ns is None

    return {
        "driver_generation": generation,
        "callback_seq": sequence,
        "nominal_interval_ns": interval_ns,
        "scheduled_ns": scheduled_ns,
        "entry_ns": entry_ns,
        "exit_ns": exit_ns,
        "pre_return_ns": pre_return_ns,
        "schema_without_tail": schema_without_tail,
        "pre_return_invalid": pre_return_invalid,
        "first_tick": record.get("first_tick") is True,
        "raw_interval_ns": raw_interval_ns,
        "raw_interval_invalid": raw_interval_invalid,
        "mode": _mode(record.get("mode")),
    }


def _parse_arm(record: dict[str, Any]) -> dict[str, Any] | None:
    generation = _integer(record.get("driver_generation"))
    arm_ns = _ns(record.get("arm_ns"))
    if generation is None or arm_ns is None:
        return None
    return {
        "driver_generation": generation,
        "arm_ns": arm_ns,
    }


def _parse_runloop(record: dict[str, Any]) -> dict[str, Any] | None:
    has_timestamp_ns = "timestamp_ns" in record
    timestamp_raw = record.get("timestamp_ns")
    if has_timestamp_ns and timestamp_raw is not None:
        timestamp_ns = _ns(timestamp_raw)
        if timestamp_ns is None:
            return None
        joinable = True
    else:
        timestamp_ns = None
        joinable = False
    observation_seq = _integer(record.get("observation_seq"))
    return {
        "activity": _activity(record.get("activity")),
        "timestamp_ns": timestamp_ns,
        "observation_seq": observation_seq,
        "joinable": joinable,
        "mode": _mode(record.get("mode")),
    }


def _partition(
    callback_records: Iterable[dict[str, Any]],
    runloop_records: Iterable[dict[str, Any]] | None,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]], dict[str, int]]:
    counts = {
        "input_record_count": 0,
        "rejected_callback_count": 0,
        "ignored_non_callback_count": 0,
        "rejected_arm_count": 0,
        "rejected_runloop_count": 0,
    }
    callbacks: list[dict[str, Any]] = []
    arms: list[dict[str, Any]] = []
    runloops: list[dict[str, Any]] = []
    streams: list[Iterable[dict[str, Any]]] = [callback_records]
    if runloop_records is not None:
        streams.append(runloop_records)
    for stream in streams:
        for record in stream:
            counts["input_record_count"] += 1
            kind = record.get("kind")
            if kind == "frame_callback":
                parsed = _parse_callback(record)
                if parsed is None:
                    counts["rejected_callback_count"] += 1
                else:
                    callbacks.append(parsed)
            elif kind == "timer_generation_arm":
                parsed = _parse_arm(record)
                if parsed is None:
                    counts["rejected_arm_count"] += 1
                else:
                    arms.append(parsed)
            elif kind == "runloop":
                parsed = _parse_runloop(record)
                if parsed is None:
                    counts["rejected_runloop_count"] += 1
                else:
                    runloops.append(parsed)
            else:
                counts["ignored_non_callback_count"] += 1
    callbacks.sort(key=lambda item: (item["driver_generation"], item["callback_seq"], item["entry_ns"]))
    arms.sort(key=lambda item: (item["driver_generation"], item["arm_ns"]))
    if runloops and all(item["observation_seq"] is not None for item in runloops):
        runloops.sort(key=lambda item: (item["observation_seq"], item["timestamp_ns"] if item["timestamp_ns"] is not None else -1))
    else:
        runloops.sort(key=lambda item: (item["timestamp_ns"] is None, item["timestamp_ns"] if item["timestamp_ns"] is not None else 0, item["observation_seq"] or 0))
    return callbacks, arms, runloops, counts


def _invalid_sample(*, kind: str, reason: str, generation: int | None, sequence: int | None) -> dict[str, Any]:
    sample = {"kind": kind, "reason": reason}
    if generation is not None:
        sample["driver_generation"] = generation
    if sequence is not None:
        sample["callback_seq"] = sequence
    return sample


def _in_window(item: dict[str, Any], start_ns: int, end_ns: int) -> bool:
    timestamp_ns = item.get("timestamp_ns")
    return bool(item.get("joinable")) and timestamp_ns is not None and start_ns <= timestamp_ns <= end_ns


def _classify_remainder(
    runloops: list[dict[str, Any]],
    start_ns: int,
    end_ns: int,
) -> dict[str, Any]:
    remainder_ns = _delta_ns(end_ns, start_ns)
    if remainder_ns is None:
        return {
            "join_class": None,
            "waiting_pair_ns": None,
            "active_pair_ns": None,
            "uncovered_ns": None,
            "valid": False,
            "invalid_reason": "NEGATIVE_DELTA",
        }

    observers = [item for item in runloops if _in_window(item, start_ns, end_ns)]
    if not observers:
        return {
            "join_class": "NO_OBSERVER_BOUNDARY",
            "waiting_pair_ns": 0,
            "active_pair_ns": 0,
            "uncovered_ns": remainder_ns,
            "valid": True,
            "invalid_reason": None,
        }

    first_obs = observers[0]["timestamp_ns"]
    last_obs = observers[-1]["timestamp_ns"]
    uncovered_ns = _delta_ns(first_obs, start_ns)
    suffix_ns = _delta_ns(end_ns, last_obs)
    if uncovered_ns is None or suffix_ns is None:
        return {
            "join_class": None,
            "waiting_pair_ns": None,
            "active_pair_ns": None,
            "uncovered_ns": None,
            "valid": False,
            "invalid_reason": "NEGATIVE_DELTA",
        }
    uncovered_ns += suffix_ns

    pairs: list[tuple[dict[str, Any], dict[str, Any]]] = []
    for previous, current in zip(runloops, runloops[1:]):
        if _in_window(previous, start_ns, end_ns) and _in_window(current, start_ns, end_ns):
            pairs.append((previous, current))

    waiting_ns = 0
    active_ns = 0
    waiting_count = 0
    active_count = 0
    unclassified_pair = False
    for previous, current in pairs:
        pair_ns = _delta_ns(current["timestamp_ns"], previous["timestamp_ns"])
        if pair_ns is None:
            return {
                "join_class": None,
                "waiting_pair_ns": None,
                "active_pair_ns": None,
                "uncovered_ns": None,
                "valid": False,
                "invalid_reason": "SEQUENCE_DISCONTINUITY",
            }
        previous_activity = previous["activity"]
        current_activity = current["activity"]
        if previous_activity is None or current_activity is None:
            unclassified_pair = True
            continue
        if previous_activity == "beforeWaiting" and current_activity == "afterWaiting":
            waiting_count += 1
            waiting_ns += pair_ns
        else:
            active_count += 1
            active_ns += pair_ns

    if not pairs or unclassified_pair:
        join_class = "UNCLASSIFIED"
    elif waiting_count and active_count:
        join_class = "MIXED_OBSERVED_BOUNDARIES"
    elif waiting_count:
        join_class = "WAITING_BOUNDED"
    elif active_count:
        join_class = "RUNLOOP_ACTIVE_BOUNDED"
    else:
        join_class = "UNCLASSIFIED"

    return {
        "join_class": join_class,
        "waiting_pair_ns": waiting_ns,
        "active_pair_ns": active_ns,
        "uncovered_ns": uncovered_ns,
        "valid": True,
        "invalid_reason": None,
    }


def _arm_for_generation(arms_by_generation: dict[int, list[dict[str, Any]]], generation: int, entry_ns: int) -> dict[str, Any] | None:
    candidates = arms_by_generation.get(generation) or []
    if not candidates:
        return None
    preceding = [item for item in candidates if item["arm_ns"] <= entry_ns]
    return (preceding or candidates)[-1]


def analyze(
    callback_records: Iterable[dict[str, Any]],
    runloop_records: Iterable[dict[str, Any]] | None = None,
    hitch_ms: float = 25.0,
) -> dict[str, Any]:
    if not math.isfinite(hitch_ms) or hitch_ms <= 0:
        raise ValueError("hitch_ms must be a positive finite number")

    callbacks, arms, runloops, acceptance = _partition(callback_records, runloop_records)
    joinable = [item for item in runloops if item["joinable"] and item["timestamp_ns"] is not None]
    hitch_ns = hitch_ms * 1_000_000.0
    invalid_samples: list[dict[str, Any]] = []
    remainders: list[dict[str, Any]] = []
    long_intervals: list[dict[str, Any]] = []
    raw_intervals_ms: list[float] = []
    recorded_bodies_ms: list[float] = []
    closure_tails_ms: list[float] = []
    remainders_ms: list[float] = []
    join_class_counts: Counter[str] = Counter()
    mode_counts = Counter(item["mode"] for item in callbacks)
    schema_without_tail_count = sum(1 for item in callbacks if item["schema_without_tail"])

    for item in callbacks:
        body_ns = _delta_ns(item["exit_ns"], item["entry_ns"])
        if body_ns is None:
            invalid_samples.append(
                _invalid_sample(
                    kind="callback_body",
                    reason="NEGATIVE_DELTA",
                    generation=item["driver_generation"],
                    sequence=item["callback_seq"],
                )
            )
        else:
            recorded_bodies_ms.append(_ms(body_ns) or 0.0)
        item["recorded_body_ns"] = body_ns

        if item["pre_return_invalid"]:
            invalid_samples.append(
                _invalid_sample(
                    kind="closure_tail",
                    reason="OVERFLOW",
                    generation=item["driver_generation"],
                    sequence=item["callback_seq"],
                )
            )
            item["closure_tail_ns"] = None
        elif item["schema_without_tail"]:
            item["closure_tail_ns"] = None
        else:
            tail_ns = _delta_ns(item["pre_return_ns"], item["exit_ns"])
            if tail_ns is None:
                invalid_samples.append(
                    _invalid_sample(
                        kind="closure_tail",
                        reason="NEGATIVE_DELTA",
                        generation=item["driver_generation"],
                        sequence=item["callback_seq"],
                    )
                )
            else:
                closure_tails_ms.append(_ms(tail_ns) or 0.0)
            item["closure_tail_ns"] = tail_ns

        if item["raw_interval_invalid"]:
            invalid_samples.append(
                _invalid_sample(
                    kind="raw_interval",
                    reason="OVERFLOW",
                    generation=item["driver_generation"],
                    sequence=item["callback_seq"],
                )
            )
        elif item["raw_interval_ns"] is not None:
            raw_intervals_ms.append(_ms(item["raw_interval_ns"]) or 0.0)

    arms_by_generation: dict[int, list[dict[str, Any]]] = {}
    for arm in arms:
        arms_by_generation.setdefault(arm["driver_generation"], []).append(arm)

    first_ticks: list[dict[str, Any]] = []
    for item in callbacks:
        if not item["first_tick"]:
            continue
        arm = _arm_for_generation(arms_by_generation, item["driver_generation"], item["entry_ns"])
        if arm is None:
            first_ticks.append(
                {
                    "driver_generation": item["driver_generation"],
                    "callback_seq": item["callback_seq"],
                    "status": "FIRST_TICK_WITHOUT_ARM",
                    "delay_ns": None,
                }
            )
            continue
        delay_ns = _delta_ns(item["entry_ns"], arm["arm_ns"])
        if delay_ns is None:
            invalid_samples.append(
                _invalid_sample(
                    kind="first_tick",
                    reason="NEGATIVE_DELTA",
                    generation=item["driver_generation"],
                    sequence=item["callback_seq"],
                )
            )
            first_ticks.append(
                {
                    "driver_generation": item["driver_generation"],
                    "callback_seq": item["callback_seq"],
                    "status": "INVALID_FIRST_TICK_DELAY",
                    "delay_ns": None,
                }
            )
            continue
        first_ticks.append(
            {
                "driver_generation": item["driver_generation"],
                "callback_seq": item["callback_seq"],
                "status": "ok",
                "delay_ns": delay_ns,
            }
        )

    by_generation: dict[int, list[dict[str, Any]]] = {}
    for item in callbacks:
        by_generation.setdefault(item["driver_generation"], []).append(item)

    for generation, group in by_generation.items():
        for previous, current in zip(group, group[1:]):
            if current["callback_seq"] <= previous["callback_seq"] or current["entry_ns"] < previous["entry_ns"]:
                invalid_samples.append(
                    _invalid_sample(
                        kind="remainder",
                        reason="SEQUENCE_DISCONTINUITY",
                        generation=generation,
                        sequence=current["callback_seq"],
                    )
                )
                remainders.append(
                    {
                        "driver_generation": generation,
                        "preceding_callback_seq": previous["callback_seq"],
                        "callback_seq": current["callback_seq"],
                        "join_class": None,
                        "recorded_body_ns": previous.get("recorded_body_ns"),
                        "closure_tail_ns": previous.get("closure_tail_ns"),
                        "post_tail_remainder_ns": None,
                        "waiting_pair_ns": None,
                        "active_pair_ns": None,
                        "uncovered_ns": None,
                        "mode": current["mode"],
                        "raw_interval_ns": current["raw_interval_ns"],
                        "valid": False,
                    }
                )
                continue

            if previous["schema_without_tail"]:
                remainder = {
                    "driver_generation": generation,
                    "preceding_callback_seq": previous["callback_seq"],
                    "callback_seq": current["callback_seq"],
                    "join_class": "SCHEMA_CALLBACK_WITHOUT_TAIL",
                    "recorded_body_ns": previous.get("recorded_body_ns"),
                    "closure_tail_ns": None,
                    "post_tail_remainder_ns": None,
                    "waiting_pair_ns": None,
                    "active_pair_ns": None,
                    "uncovered_ns": None,
                    "mode": current["mode"],
                    "raw_interval_ns": current["raw_interval_ns"],
                    "valid": True,
                }
                join_class_counts["SCHEMA_CALLBACK_WITHOUT_TAIL"] += 1
                remainders.append(remainder)
            elif previous["pre_return_ns"] is None:
                invalid_samples.append(
                    _invalid_sample(
                        kind="remainder",
                        reason="MISSING_MARKER",
                        generation=generation,
                        sequence=current["callback_seq"],
                    )
                )
                remainders.append(
                    {
                        "driver_generation": generation,
                        "preceding_callback_seq": previous["callback_seq"],
                        "callback_seq": current["callback_seq"],
                        "join_class": None,
                        "recorded_body_ns": previous.get("recorded_body_ns"),
                        "closure_tail_ns": None,
                        "post_tail_remainder_ns": None,
                        "waiting_pair_ns": None,
                        "active_pair_ns": None,
                        "uncovered_ns": None,
                        "mode": current["mode"],
                        "raw_interval_ns": current["raw_interval_ns"],
                        "valid": False,
                    }
                )
            else:
                remainder_ns = _delta_ns(current["entry_ns"], previous["pre_return_ns"])
                classified = _classify_remainder(runloops, previous["pre_return_ns"], current["entry_ns"])
                if remainder_ns is None or not classified["valid"]:
                    reason = classified["invalid_reason"] or "NEGATIVE_DELTA"
                    invalid_samples.append(
                        _invalid_sample(
                            kind="remainder",
                            reason=reason,
                            generation=generation,
                            sequence=current["callback_seq"],
                        )
                    )
                    remainders.append(
                        {
                            "driver_generation": generation,
                            "preceding_callback_seq": previous["callback_seq"],
                            "callback_seq": current["callback_seq"],
                            "join_class": None,
                            "recorded_body_ns": previous.get("recorded_body_ns"),
                            "closure_tail_ns": previous.get("closure_tail_ns"),
                            "post_tail_remainder_ns": None,
                            "waiting_pair_ns": None,
                            "active_pair_ns": None,
                            "uncovered_ns": None,
                            "mode": current["mode"],
                            "raw_interval_ns": current["raw_interval_ns"],
                            "valid": False,
                        }
                    )
                else:
                    join_class_counts[classified["join_class"]] += 1
                    remainders_ms.append(_ms(remainder_ns) or 0.0)
                    remainders.append(
                        {
                            "driver_generation": generation,
                            "preceding_callback_seq": previous["callback_seq"],
                            "callback_seq": current["callback_seq"],
                            "join_class": classified["join_class"],
                            "recorded_body_ns": previous.get("recorded_body_ns"),
                            "closure_tail_ns": previous.get("closure_tail_ns"),
                            "post_tail_remainder_ns": remainder_ns,
                            "waiting_pair_ns": classified["waiting_pair_ns"],
                            "active_pair_ns": classified["active_pair_ns"],
                            "uncovered_ns": classified["uncovered_ns"],
                            "mode": current["mode"],
                            "raw_interval_ns": current["raw_interval_ns"],
                            "valid": True,
                        }
                    )

            last = remainders[-1]
            raw = current["raw_interval_ns"]
            if raw is not None and raw > hitch_ns:
                long_intervals.append(
                    {
                        "driver_generation": generation,
                        "callback_seq": current["callback_seq"],
                        "raw_interval_ns": raw,
                        "recorded_body_ns": last["recorded_body_ns"],
                        "closure_tail_ns": last["closure_tail_ns"],
                        "post_tail_remainder_ns": last["post_tail_remainder_ns"],
                        "join_class": last["join_class"],
                        "waiting_pair_ns": last["waiting_pair_ns"],
                        "active_pair_ns": last["active_pair_ns"],
                        "uncovered_ns": last["uncovered_ns"],
                        "mode": current["mode"],
                        "valid": last["valid"],
                    }
                )

    generations = {item["driver_generation"] for item in callbacks} | {item["driver_generation"] for item in arms}
    first_delay_ms = [_ms(item["delay_ns"]) for item in first_ticks if item["delay_ns"] is not None]
    first_delay_ms_values = [value for value in first_delay_ms if value is not None]
    threshold_counts = {
        f"gt_{str(value).replace('.', '_')}_ms": sum(interval > value for interval in raw_intervals_ms)
        for value in THRESHOLDS_MS
    }

    return {
        "schema_version": 1,
        "gate": GATE,
        "privacy_note": PRIVACY_NOTE,
        "input_record_count": acceptance["input_record_count"],
        "accepted_callback_count": len(callbacks),
        "callback_count": len(callbacks),
        "rejected_callback_count": acceptance["rejected_callback_count"],
        "ignored_non_callback_count": acceptance["ignored_non_callback_count"],
        "accepted_arm_count": len(arms),
        "rejected_arm_count": acceptance["rejected_arm_count"],
        "accepted_runloop_count": len(runloops),
        "rejected_runloop_count": acceptance["rejected_runloop_count"],
        "joinable_runloop_count": len(joinable),
        "raw_interval_count": len(raw_intervals_ms),
        "first_tick_count": len(first_ticks),
        "recorded_generation_count": len(generations),
        "invalid_sample_count": len(invalid_samples),
        "schema_callback_without_tail_count": schema_without_tail_count,
        "first_tick_without_arm_count": sum(item["status"] == "FIRST_TICK_WITHOUT_ARM" for item in first_ticks),
        "mode_counts": {mode: mode_counts.get(mode, 0) for mode in ALLOWED_MODES},
        "join_class_counts": {name: join_class_counts.get(name, 0) for name in JOIN_CLASSES},
        "interval_summary": {**_summary(raw_intervals_ms), **threshold_counts},
        "recorded_body_summary": _summary(recorded_bodies_ms),
        "closure_tail_summary": _summary(closure_tails_ms),
        "post_tail_remainder_summary": _summary(remainders_ms),
        "first_tick_summary": {
            "count": len(first_ticks),
            "with_arm_count": sum(item["status"] == "ok" for item in first_ticks),
            "without_arm_count": sum(item["status"] == "FIRST_TICK_WITHOUT_ARM" for item in first_ticks),
            "delay": _summary(first_delay_ms_values),
            "ticks": first_ticks,
        },
        "long_interval_threshold_ms": hitch_ms,
        "long_intervals": long_intervals,
        "remainders": remainders,
        "invalid_samples": invalid_samples,
        "interpretation_boundary": INTERPRETATION_BOUNDARY,
    }


def _fmt(value: Any) -> str:
    return "-" if value is None else f"{value:.3f}"


def _fmt_ms(ns: int | None) -> str:
    return "-" if ns is None else f"{ns / 1_000_000.0:.3f}"


def _fmt_class(value: str | None) -> str:
    return "-" if value is None else value


def render_markdown(report: dict[str, Any]) -> str:
    interval = report["interval_summary"]
    join_counts = report["join_class_counts"]
    first = report["first_tick_summary"]
    lines = [
        "# Callback ↔ RunLoop Correlation Report",
        "",
        f"Gate: `{report['gate']}`",
        "",
        f"- input records: {report['input_record_count']}",
        f"- accepted callback records: {report['accepted_callback_count']}",
        f"- rejected callback records: {report['rejected_callback_count']}",
        f"- ignored non-callback records: {report['ignored_non_callback_count']}",
        f"- accepted arm records: {report['accepted_arm_count']}",
        f"- rejected arm records: {report['rejected_arm_count']}",
        f"- accepted runloop records: {report['accepted_runloop_count']}",
        f"- rejected runloop records: {report['rejected_runloop_count']}",
        f"- raw intervals analyzed: {report['raw_interval_count']}",
        f"- first ticks analyzed separately: {report['first_tick_count']}",
        f"- generations observed: {report['recorded_generation_count']}",
        f"- invalid samples: {report['invalid_sample_count']}",
        f"- schema-without-tail callbacks: {report['schema_callback_without_tail_count']}",
        f"- interval p95/p99/max: {_fmt(interval['p95_ms'])} / {_fmt(interval['p99_ms'])} / {_fmt(interval['max_ms'])} ms",
        f"- >20 / >25 / >33.3 / >50 ms: {interval['gt_20_0_ms']} / {interval['gt_25_0_ms']} / {interval['gt_33_3_ms']} / {interval['gt_50_0_ms']}",
        "",
        "## Join classes (observation, not root cause)",
        "",
        f"- NO_OBSERVER_BOUNDARY: {join_counts['NO_OBSERVER_BOUNDARY']}",
        f"- WAITING_BOUNDED: {join_counts['WAITING_BOUNDED']}",
        f"- RUNLOOP_ACTIVE_BOUNDED: {join_counts['RUNLOOP_ACTIVE_BOUNDED']}",
        f"- MIXED_OBSERVED_BOUNDARIES: {join_counts['MIXED_OBSERVED_BOUNDARIES']}",
        f"- UNCLASSIFIED: {join_counts['UNCLASSIFIED']}",
        f"- SCHEMA_CALLBACK_WITHOUT_TAIL: {join_counts['SCHEMA_CALLBACK_WITHOUT_TAIL']}",
        "",
        "## First ticks",
        "",
        f"- count: {first['count']} (with arm={first['with_arm_count']}, without arm={first['without_arm_count']})",
        "",
        "## Long intervals",
        "",
        "| generation | seq | interval ms | body ms | tail ms | remainder ms | join class | waiting pair ms | active pair ms | uncovered ms | mode |",
        "|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|",
    ]
    for item in report["long_intervals"]:
        lines.append(
            f"| {item['driver_generation']} | {item['callback_seq']} | {_fmt_ms(item['raw_interval_ns'])} | "
            f"{_fmt_ms(item['recorded_body_ns'])} | {_fmt_ms(item['closure_tail_ns'])} | "
            f"{_fmt_ms(item['post_tail_remainder_ns'])} | {_fmt_class(item['join_class'])} | "
            f"{_fmt_ms(item['waiting_pair_ns'])} | {_fmt_ms(item['active_pair_ns'])} | "
            f"{_fmt_ms(item['uncovered_ns'])} | {item['mode']} |"
        )
    lines.extend(["", f"> {report['interpretation_boundary']}", ""])
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--callback", type=Path, required=True)
    parser.add_argument("--runloop", type=Path)
    parser.add_argument("--hitch-ms", type=float, default=25.0)
    parser.add_argument("--format", choices=("json", "markdown"), default="markdown")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    if not math.isfinite(args.hitch_ms) or args.hitch_ms <= 0:
        parser.error("--hitch-ms must be a positive finite number")
    try:
        callback_records = load_jsonl(args.callback)
        runloop_records = load_jsonl(args.runloop) if args.runloop is not None else None
        report = analyze(callback_records, runloop_records, hitch_ms=args.hitch_ms)
    except InputDataError as error:
        print(f"callback-runloop-correlation: {error}", file=sys.stderr)
        return 2
    rendered = json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2) if args.format == "json" else render_markdown(report)
    if args.output:
        args.output.write_text(rendered + ("" if rendered.endswith("\n") else "\n"))
    else:
        print(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
