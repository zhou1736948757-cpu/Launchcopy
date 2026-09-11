#!/usr/bin/env python3
"""Privacy-safe, stdlib-only frame hitch correlation analyzer.

The telemetry clock is a wall clock while frame/runloop profiles use uptime.
This tool deliberately never subtracts timestamps across those clock domains.
Telemetry frames and frame-profile frames are correlated by ordinal only, then
verified with adjacent interval deltas within each stream's own clock domain.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

DEFAULT_THRESHOLDS_MS = (20.0, 25.0, 33.3, 50.0)
KNOWN_RUNLOOP_ACTIVITIES = {
    "entry",
    "beforeTimers",
    "beforeSources",
    "beforeWaiting",
    "afterWaiting",
    "exit",
}


class InputDataError(ValueError):
    """A user-facing input problem. CLI errors may name the input path."""


def _number(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        value = float(value)
        return value if math.isfinite(value) else None
    return None


def _ns_to_ms(value: Any) -> float | None:
    number = _number(value)
    return None if number is None or number < 0 else number / 1_000_000.0


def load_jsonl(path: str | Path, label: str) -> list[dict[str, Any]]:
    """Load JSON object lines, failing closed on malformed input."""
    source = Path(path)
    try:
        with source.open("r", encoding="utf-8") as handle:
            records: list[dict[str, Any]] = []
            for line_number, line in enumerate(handle, start=1):
                if not line.strip():
                    continue
                try:
                    value = json.loads(line)
                except json.JSONDecodeError as error:
                    raise InputDataError(
                        f"invalid {label} JSONL at {source}:{line_number}: {error.msg}"
                    ) from error
                if not isinstance(value, dict):
                    raise InputDataError(
                        f"invalid {label} JSONL object at {source}:{line_number}"
                    )
                records.append(value)
            return records
    except OSError as error:
        raise InputDataError(f"cannot read {label}: {source}: {error.strerror or error}") from error


def _event_category(event_phase: Any) -> str:
    """Map telemetry to a fixed anonymous vocabulary; never echo unknown fields."""
    phase = event_phase if isinstance(event_phase, str) else ""
    if phase.startswith("gesture."):
        return "gesture"
    if phase.startswith("transition."):
        return "transition"
    if phase.startswith("interruption."):
        return "interruption"
    if phase == "icon.async":
        return "icon"
    if phase == "layout":
        return "layout"
    if phase == "resize":
        return "resize"
    if phase == "state.changed":
        return "state"
    if phase == "catalog.presentation":
        return "catalog"
    if phase in {"run.begin", "run.end", "teardown.complete"}:
        return "lifecycle"
    return "other"


def _telemetry_frames(records: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    frames: list[dict[str, Any]] = []
    for record in records:
        if record.get("event_phase") != "frame":
            continue
        interval_seconds = _number(record.get("frame_interval"))
        if interval_seconds is None or interval_seconds < 0:
            continue
        frames.append(
            {
                "interval_ms": interval_seconds * 1_000.0,
                "timestamp": _number(record.get("timestamp")),
            }
        )
    return frames


def _profile_frames(records: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    frames: list[dict[str, Any]] = []
    for record in records:
        if record.get("kind") != "frame":
            continue
        frames.append(
            {
                "timestamp": _number(record.get("timestamp")),
                "total_ms": _ns_to_ms(record.get("total_ns")),
                "parts_valid": _profile_parts_valid(record),
            }
        )
    return frames


def _profile_parts_valid(record: dict[str, Any]) -> bool:
    total = _number(record.get("total_ns"))
    parts = [_number(record.get(name)) for name in ("input_ns", "state_ns", "view_ns")]
    if total is None or total < 0 or any(part is None or part < 0 for part in parts):
        return False
    return sum(parts) <= total


def _runloop_records(records: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for record in records:
        if record.get("kind") != "runloop":
            continue
        activity = record.get("activity")
        result.append(
            {
                "activity": activity if activity in KNOWN_RUNLOOP_ACTIVITIES else None,
                "timestamp": _number(record.get("timestamp")),
                "gap_ns": _number(record.get("gap_ns")),
            }
        )
    return result


def _alignment_summary(
    telemetry_frames: list[dict[str, Any]],
    profile_frames: list[dict[str, Any]] | None,
    tolerance_ms: float,
) -> tuple[dict[str, Any], list[bool | None]]:
    """Verify ordinal association without crossing telemetry/profile clock domains."""
    if profile_frames is None:
        return (
            {
                "mode": "frame_ordinal",
                "profile_available": False,
                "telemetry_frames": len(telemetry_frames),
                "profile_frames": 0,
                "count_match": False,
                "adjacent_compared": 0,
                "adjacent_within_tolerance": 0,
                "adjacent_mismatches": 0,
                "adjacent_unverifiable": 0,
            },
            [None] * len(telemetry_frames),
        )

    local_valid: list[bool | None] = [None] * len(telemetry_frames)
    comparable = min(len(telemetry_frames), len(profile_frames))
    compared = 0
    valid_count = 0
    mismatch_count = 0
    unverifiable = 0
    for ordinal in range(1, comparable):
        telemetry_interval = _number(telemetry_frames[ordinal].get("interval_ms"))
        previous_timestamp = _number(profile_frames[ordinal - 1].get("timestamp"))
        current_timestamp = _number(profile_frames[ordinal].get("timestamp"))
        if telemetry_interval is None or previous_timestamp is None or current_timestamp is None:
            unverifiable += 1
            continue
        compared += 1
        profile_interval = (current_timestamp - previous_timestamp) * 1_000.0
        valid = abs(profile_interval - telemetry_interval) <= tolerance_ms
        local_valid[ordinal] = valid
        if valid:
            valid_count += 1
        else:
            mismatch_count += 1

    return (
        {
            "mode": "frame_ordinal",
            "profile_available": True,
            "telemetry_frames": len(telemetry_frames),
            "profile_frames": len(profile_frames),
            "count_match": len(telemetry_frames) == len(profile_frames),
            "adjacent_compared": compared,
            "adjacent_within_tolerance": valid_count,
            "adjacent_mismatches": mismatch_count,
            "adjacent_unverifiable": unverifiable,
        },
        local_valid,
    )


def _pre_window_categories(
    telemetry_records: Iterable[dict[str, Any]],
    telemetry_frames: list[dict[str, Any]],
    ordinal: int,
) -> list[str]:
    """Return only events in the *preceding* telemetry interval, never after it."""
    if ordinal == 0:
        return []
    start = _number(telemetry_frames[ordinal - 1].get("timestamp"))
    end = _number(telemetry_frames[ordinal].get("timestamp"))
    if start is None or end is None or end < start:
        return []
    categories: Counter[str] = Counter()
    for record in telemetry_records:
        if record.get("event_phase") == "frame":
            continue
        timestamp = _number(record.get("timestamp"))
        if timestamp is not None and start < timestamp <= end:
            categories[_event_category(record.get("event_phase"))] += 1
    return [f"{category}:{categories[category]}" for category in sorted(categories)]


def _safe_pair(previous: str | None, current: str | None) -> str:
    if previous is None or current is None:
        return "unclassified_pair"
    return f"{previous}->{current}"


def _classify_pair(previous: str | None, current: str | None, verified: bool) -> str:
    if not verified:
        return "unclassified"
    if previous == "beforeWaiting" and current == "afterWaiting":
        return "waiting-like"
    if (previous, current) in {
        ("afterWaiting", "beforeTimers"),
        ("beforeTimers", "beforeSources"),
        ("beforeSources", "beforeWaiting"),
    }:
        return "active-like"
    return "unclassified"


def _runloop_gaps_for_window(
    runloop_records: list[dict[str, Any]] | None,
    start_uptime: float | None,
    end_uptime: float | None,
    minimum_gap_ms: float,
    pair_tolerance_ms: float,
) -> list[dict[str, Any]]:
    if runloop_records is None or start_uptime is None or end_uptime is None or end_uptime < start_uptime:
        return []

    gaps: list[dict[str, Any]] = []
    for index, current in enumerate(runloop_records):
        current_timestamp = _number(current.get("timestamp"))
        gap_ns = _number(current.get("gap_ns"))
        if (
            current_timestamp is None
            or gap_ns is None
            or gap_ns < minimum_gap_ms * 1_000_000.0
            or not (start_uptime < current_timestamp <= end_uptime)
        ):
            continue
        previous = runloop_records[index - 1] if index else None
        previous_timestamp = _number(previous.get("timestamp")) if previous else None
        actual_gap_ns = (
            (current_timestamp - previous_timestamp) * 1_000_000_000.0
            if previous_timestamp is not None
            else None
        )
        allowed_error_ns = max(pair_tolerance_ms * 1_000_000.0, gap_ns * 0.02)
        verified = actual_gap_ns is not None and abs(actual_gap_ns - gap_ns) <= allowed_error_ns
        previous_activity = previous.get("activity") if previous else None
        current_activity = current.get("activity")
        gaps.append(
            {
                "gap_ms": gap_ns / 1_000_000.0,
                "pair": _safe_pair(previous_activity, current_activity),
                "pair_verified": verified,
                "classification": _classify_pair(previous_activity, current_activity, verified),
            }
        )
    return gaps


def _rounded(value: float | None, digits: int = 3) -> float | None:
    return None if value is None else round(value, digits)


def analyze_records(
    telemetry_records: list[dict[str, Any]],
    frame_profile_records: list[dict[str, Any]] | None = None,
    runloop_profile_records: list[dict[str, Any]] | None = None,
    *,
    hitch_threshold_ms: float = 20.0,
    alignment_tolerance_ms: float = 1.0,
    runloop_gap_ms: float = 20.0,
    runloop_pair_tolerance_ms: float = 1.0,
    run_context: str = "UNSPECIFIED",
) -> dict[str, Any]:
    """Build a report from already loaded JSON records using only safe fields."""
    if hitch_threshold_ms <= 0 or alignment_tolerance_ms < 0 or runloop_gap_ms <= 0 or runloop_pair_tolerance_ms < 0:
        raise ValueError("analysis thresholds must be non-negative and hitch/runloop thresholds must be positive")

    telemetry_frames = _telemetry_frames(telemetry_records)
    profile_frames = _profile_frames(frame_profile_records) if frame_profile_records is not None else None
    runloop = _runloop_records(runloop_profile_records) if runloop_profile_records is not None else None
    alignment, local_alignment = _alignment_summary(telemetry_frames, profile_frames, alignment_tolerance_ms)

    thresholds = sorted({*DEFAULT_THRESHOLDS_MS, float(hitch_threshold_ms)})
    threshold_counts = {
        f">{threshold:g}ms": sum(frame["interval_ms"] > threshold for frame in telemetry_frames)
        for threshold in thresholds
    }
    max_interval = max((frame["interval_ms"] for frame in telemetry_frames), default=None)

    hitches: list[dict[str, Any]] = []
    for ordinal, frame in enumerate(telemetry_frames):
        current_interval = frame["interval_ms"]
        if current_interval <= hitch_threshold_ms:
            continue
        previous_interval = telemetry_frames[ordinal - 1]["interval_ms"] if ordinal else None
        next_interval = telemetry_frames[ordinal + 1]["interval_ms"] if ordinal + 1 < len(telemetry_frames) else None

        # telemetry/profile frame ordinal i describes the callback *entry* at i.
        # Therefore interval i spans profile[i - 1].timestamp -> profile[i].timestamp,
        # and the callback body that lies at the start of (and can contribute to)
        # that interval is profile[i - 1], not profile[i].
        callback_total = None
        callback_frame_ordinal = None
        profile_start = None
        profile_end = None
        if profile_frames is not None and 0 < ordinal < len(profile_frames):
            callback_frame_ordinal = ordinal - 1
            callback_total = profile_frames[callback_frame_ordinal]["total_ms"]
            profile_end = profile_frames[ordinal]["timestamp"]
            profile_start = profile_frames[callback_frame_ordinal]["timestamp"]

        if profile_frames is None or ordinal <= 0 or ordinal >= len(profile_frames):
            profile_evidence_level = "UNRESOLVED"
        elif local_alignment[ordinal] is True and profile_frames[ordinal - 1]["parts_valid"]:
            profile_evidence_level = "PROFILE_CORRELATED"
        else:
            profile_evidence_level = "PROFILE_ORDINAL_UNVERIFIED"

        # Missing either optional profile prevents a complete cross-artifact hitch
        # association. Preserve the narrower profile result separately, but do
        # not promote the hitch's overall evidence level beyond UNRESOLVED.
        evidence_level = (
            profile_evidence_level
            if profile_frames is not None and runloop is not None
            else "UNRESOLVED"
        )

        hitches.append(
            {
                "frame_ordinal": ordinal,
                "previous_interval_ms": _rounded(previous_interval),
                "current_interval_ms": _rounded(current_interval),
                "next_interval_ms": _rounded(next_interval),
                "callback_frame_ordinal": callback_frame_ordinal,
                "callback_total_ms": _rounded(callback_total),
                "pre_window_event_categories": _pre_window_categories(telemetry_records, telemetry_frames, ordinal),
                "runloop_large_gaps": _runloop_gaps_for_window(
                    runloop,
                    profile_start,
                    profile_end,
                    runloop_gap_ms,
                    runloop_pair_tolerance_ms,
                ),
                "profile_evidence_level": profile_evidence_level,
                "evidence_level": evidence_level,
            }
        )

    context = run_context.upper()
    if context not in {"MANUAL", "SELFDRIVE", "UNSPECIFIED"}:
        context = "UNSPECIFIED"
    context_note = (
        "SELFDRIVE is a synthetic performance comparison, not physical-feel evidence."
        if context == "SELFDRIVE"
        else "No physical-feel conclusion is produced by this analyzer."
    )

    return {
        "schema_version": 1,
        "run_context": context,
        "context_note": context_note,
        "frame_count": len(telemetry_frames),
        "interval_summary": {
            "maximum_ms": _rounded(max_interval),
            "threshold_counts": threshold_counts,
            "hitch_threshold_ms": _rounded(hitch_threshold_ms),
        },
        "profile_alignment": alignment,
        "runloop_profile_available": runloop is not None,
        "hitches": hitches,
        "privacy_note": "Report contains only fixed categories, ordinals, and durations; source fields and paths are not emitted.",
    }


def _format_ms(value: float | None) -> str:
    return "n/a" if value is None else f"{value:.3f} ms"


def render_markdown(result: dict[str, Any]) -> str:
    """Render only report-owned fields; no source records or paths are interpolated."""
    lines = [
        "# Frame Hitch Analysis",
        "",
        "## Scope and privacy",
        "",
        f"- Context: `{result['run_context']}`.",
        f"- {result['context_note']}",
        f"- {result['privacy_note']}",
        "",
        "## Summary",
        "",
        f"- Telemetry frame events: **{result['frame_count']}**.",
        f"- Maximum interval: **{_format_ms(result['interval_summary']['maximum_ms'])}**.",
    ]
    for threshold, count in result["interval_summary"]["threshold_counts"].items():
        lines.append(f"- `{threshold}`: **{count}**.")

    alignment = result["profile_alignment"]
    lines.extend(
        [
            "",
            "## Frame-profile ordinal alignment",
            "",
            "- Mode: `frame_ordinal` (no telemetry wall-clock minus uptime arithmetic).",
            f"- Telemetry/profile frames: **{alignment['telemetry_frames']} / {alignment['profile_frames']}**; count match: **{str(alignment['count_match']).lower()}**.",
            f"- Adjacent intervals verified: **{alignment['adjacent_within_tolerance']} / {alignment['adjacent_compared']}**; mismatches: **{alignment['adjacent_mismatches']}**; unverifiable: **{alignment['adjacent_unverifiable']}**.",
            "",
            "## Hitches",
            "",
        ]
    )
    if not result["hitches"]:
        lines.append("No intervals exceeded the selected hitch threshold.")
    for hitch in result["hitches"]:
        callback_ordinal = hitch.get("callback_frame_ordinal")
        callback_label = (
            "Preceding callback total"
            if callback_ordinal is None
            else f"Preceding callback total (frame ordinal {callback_ordinal})"
        )
        lines.extend(
            [
                f"### Frame ordinal {hitch['frame_ordinal']}",
                "",
                f"- Intervals (previous/current/next): {_format_ms(hitch['previous_interval_ms'])} / {_format_ms(hitch['current_interval_ms'])} / {_format_ms(hitch['next_interval_ms'])}.",
                f"- {callback_label}: {_format_ms(hitch['callback_total_ms'])}.",
                f"- Pre-window anonymous event categories: {', '.join(hitch['pre_window_event_categories']) or 'none'}.",
                f"- Profile evidence: `{hitch['profile_evidence_level']}`; overall evidence: `{hitch['evidence_level']}`.",
            ]
        )
        gaps = hitch["runloop_large_gaps"]
        if gaps:
            lines.append("- Runloop large gaps (validated adjacent pair required for interpretation):")
            for gap in gaps:
                lines.append(
                    f"  - {_format_ms(gap['gap_ms'])}; pair `{gap['pair']}`; "
                    f"pair verified: `{str(gap['pair_verified']).lower()}`; "
                    f"classification: `{gap['classification']}`."
                )
        else:
            lines.append("- Runloop large gaps: none associated, unavailable, or not safely alignable.")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("telemetry", help="telemetry JSONL input")
    parser.add_argument("--frame-profile", help="optional frame-profile JSONL input")
    parser.add_argument("--runloop-profile", help="optional runloop-profile JSONL input")
    parser.add_argument("--format", choices=("markdown", "json"), default="markdown")
    parser.add_argument("--output", help="optional report output file")
    parser.add_argument("--hitch-threshold-ms", type=float, default=20.0)
    parser.add_argument("--alignment-tolerance-ms", type=float, default=1.0)
    parser.add_argument("--runloop-gap-ms", type=float, default=20.0)
    parser.add_argument("--runloop-pair-tolerance-ms", type=float, default=1.0)
    parser.add_argument("--run-context", choices=("MANUAL", "SELFDRIVE", "UNSPECIFIED"), default="UNSPECIFIED")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    arguments = parser.parse_args(argv)
    try:
        telemetry = load_jsonl(arguments.telemetry, "telemetry")
        profile = load_jsonl(arguments.frame_profile, "frame profile") if arguments.frame_profile else None
        runloop = load_jsonl(arguments.runloop_profile, "runloop profile") if arguments.runloop_profile else None
        result = analyze_records(
            telemetry,
            profile,
            runloop,
            hitch_threshold_ms=arguments.hitch_threshold_ms,
            alignment_tolerance_ms=arguments.alignment_tolerance_ms,
            runloop_gap_ms=arguments.runloop_gap_ms,
            runloop_pair_tolerance_ms=arguments.runloop_pair_tolerance_ms,
            run_context=arguments.run_context,
        )
    except (InputDataError, ValueError) as error:
        parser.error(str(error))

    output = render_markdown(result) if arguments.format == "markdown" else json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if arguments.output:
        try:
            Path(arguments.output).write_text(output, encoding="utf-8")
        except OSError as error:
            parser.error(f"cannot write report: {error.strerror or error}")
    else:
        sys.stdout.write(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
