import json
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))

import analyze_frame_hitches as analyzer


def telemetry_frame(timestamp, interval_seconds):
    return {"event_phase": "frame", "timestamp": timestamp, "frame_interval": interval_seconds}


def profile_frame(timestamp, total_ns=500_000):
    return {
        "kind": "frame",
        "timestamp": timestamp,
        "input_ns": 100_000,
        "state_ns": 100_000,
        "view_ns": 100_000,
        "total_ns": total_ns,
    }


class FrameHitchAnalyzerTests(unittest.TestCase):
    def test_counts_only_telemetry_frame_events_and_required_thresholds(self):
        telemetry = [
            {"event_phase": "gesture.changed", "timestamp": 1.1, "frame_interval": 9.0},
            telemetry_frame(1.0, 0.016),
            telemetry_frame(1.03, 0.030),
            telemetry_frame(1.09, 0.060),
        ]
        result = analyzer.analyze_records(telemetry)
        self.assertEqual(3, result["frame_count"])
        self.assertEqual(2, result["interval_summary"]["threshold_counts"][">20ms"])
        self.assertEqual(2, result["interval_summary"]["threshold_counts"][">25ms"])
        self.assertEqual(1, result["interval_summary"]["threshold_counts"][">33.3ms"])
        self.assertEqual(1, result["interval_summary"]["threshold_counts"][">50ms"])

    def test_clock_mismatch_is_not_used_for_cross_clock_join(self):
        telemetry = [
            telemetry_frame(1_787_932_125.0, 0.016),
            telemetry_frame(1_787_932_125.024, 0.024),
        ]
        profile = [profile_frame(566_062.000), profile_frame(566_062.024, total_ns=820_000)]
        result = analyzer.analyze_records(telemetry, profile)
        hitch = result["hitches"][0]
        self.assertEqual(1, hitch["frame_ordinal"])
        self.assertEqual(0, hitch["callback_frame_ordinal"])
        self.assertEqual(0.5, hitch["callback_total_ms"])
        self.assertEqual("PROFILE_CORRELATED", hitch["profile_evidence_level"])
        self.assertEqual("UNRESOLVED", hitch["evidence_level"])
        self.assertNotIn("timestamp", json.dumps(result))

    def test_hitch_uses_preceding_callback_not_current_callback(self):
        telemetry = [
            telemetry_frame(100.0, 0.016),
            telemetry_frame(100.030, 0.030),
        ]
        profile = [
            profile_frame(10.000, total_ns=750_000),
            profile_frame(10.030, total_ns=9_000_000),
        ]
        result = analyzer.analyze_records(telemetry, profile)
        hitch = result["hitches"][0]
        self.assertEqual(1, hitch["frame_ordinal"])
        self.assertEqual(0, hitch["callback_frame_ordinal"])
        self.assertEqual(0.75, hitch["callback_total_ms"])
        self.assertNotEqual(9.0, hitch["callback_total_ms"])

    def test_first_frame_hitch_has_no_preceding_callback_attribution(self):
        telemetry = [telemetry_frame(100.0, 0.030)]
        profile = [profile_frame(10.0, total_ns=9_000_000)]
        result = analyzer.analyze_records(telemetry, profile)
        hitch = result["hitches"][0]
        self.assertEqual(0, hitch["frame_ordinal"])
        self.assertIsNone(hitch["callback_frame_ordinal"])
        self.assertIsNone(hitch["callback_total_ms"])
        self.assertEqual("UNRESOLVED", hitch["profile_evidence_level"])

    def test_preceding_callback_parts_control_profile_evidence(self):
        telemetry = [
            telemetry_frame(100.0, 0.016),
            telemetry_frame(100.030, 0.030),
        ]
        invalid_preceding = profile_frame(10.000, total_ns=200_000)
        valid_current = profile_frame(10.030, total_ns=9_000_000)
        result = analyzer.analyze_records(telemetry, [invalid_preceding, valid_current])
        hitch = result["hitches"][0]
        self.assertEqual(0, hitch["callback_frame_ordinal"])
        self.assertEqual("PROFILE_ORDINAL_UNVERIFIED", hitch["profile_evidence_level"])

    def test_current_callback_parts_do_not_invalidate_preceding_callback_evidence(self):
        telemetry = [
            telemetry_frame(100.0, 0.016),
            telemetry_frame(100.030, 0.030),
        ]
        valid_preceding = profile_frame(10.000, total_ns=750_000)
        invalid_current = profile_frame(10.030, total_ns=200_000)
        result = analyzer.analyze_records(telemetry, [valid_preceding, invalid_current])
        hitch = result["hitches"][0]
        self.assertEqual(0, hitch["callback_frame_ordinal"])
        self.assertEqual(0.75, hitch["callback_total_ms"])
        self.assertEqual("PROFILE_CORRELATED", hitch["profile_evidence_level"])

    def test_ordinal_alignment_validates_adjacent_intervals(self):
        telemetry = [
            telemetry_frame(1000.0, 0.016),
            telemetry_frame(1000.03, 0.030),
            telemetry_frame(1000.046, 0.016),
        ]
        profile = [profile_frame(50.0), profile_frame(50.03), profile_frame(50.046)]
        result = analyzer.analyze_records(telemetry, profile)
        alignment = result["profile_alignment"]
        self.assertTrue(alignment["count_match"])
        self.assertEqual(2, alignment["adjacent_within_tolerance"])
        self.assertEqual("PROFILE_CORRELATED", result["hitches"][0]["profile_evidence_level"])
        self.assertEqual("UNRESOLVED", result["hitches"][0]["evidence_level"])

    def test_alignment_mismatch_does_not_claim_profile_correlation(self):
        telemetry = [telemetry_frame(1.0, 0.016), telemetry_frame(1.03, 0.030)]
        profile = [profile_frame(10.0), profile_frame(10.08)]
        result = analyzer.analyze_records(telemetry, profile)
        self.assertEqual(1, result["profile_alignment"]["adjacent_mismatches"])
        self.assertEqual("PROFILE_ORDINAL_UNVERIFIED", result["hitches"][0]["profile_evidence_level"])
        self.assertEqual("UNRESOLVED", result["hitches"][0]["evidence_level"])

    def test_pre_window_is_directionally_correct(self):
        telemetry = [
            telemetry_frame(100.0, 0.016),
            {"event_phase": "icon.async", "timestamp": 100.010, "app_name": "must-not-leak"},
            telemetry_frame(100.030, 0.030),
            {"event_phase": "layout", "timestamp": 100.031},
        ]
        result = analyzer.analyze_records(telemetry)
        self.assertEqual(["icon:1"], result["hitches"][0]["pre_window_event_categories"])

    def test_after_event_is_never_reported_as_cause(self):
        telemetry = [
            telemetry_frame(4.0, 0.016),
            telemetry_frame(4.030, 0.030),
            {"event_phase": "transition.begin", "timestamp": 4.031},
        ]
        result = analyzer.analyze_records(telemetry)
        self.assertEqual([], result["hitches"][0]["pre_window_event_categories"])

    def test_runloop_pair_is_verified_before_waiting_like_interpretation(self):
        telemetry = [telemetry_frame(1_000.0, 0.016), telemetry_frame(1_000.030, 0.030)]
        profile = [profile_frame(10.0), profile_frame(10.030)]
        runloop = [
            {"kind": "runloop", "activity": "beforeWaiting", "timestamp": 10.001, "gap_ns": 1_000_000},
            {"kind": "runloop", "activity": "afterWaiting", "timestamp": 10.026, "gap_ns": 25_000_000},
        ]
        result = analyzer.analyze_records(telemetry, profile, runloop, runloop_gap_ms=20)
        gap = result["hitches"][0]["runloop_large_gaps"][0]
        self.assertTrue(gap["pair_verified"])
        self.assertEqual("beforeWaiting->afterWaiting", gap["pair"])
        self.assertEqual("waiting-like", gap["classification"])

    def test_invalid_runloop_gap_is_unclassified(self):
        telemetry = [telemetry_frame(10.0, 0.016), telemetry_frame(10.030, 0.030)]
        profile = [profile_frame(20.0), profile_frame(20.030)]
        runloop = [
            {"kind": "runloop", "activity": "beforeWaiting", "timestamp": 20.001, "gap_ns": 1_000_000},
            {"kind": "runloop", "activity": "afterWaiting", "timestamp": 20.026, "gap_ns": 200_000_000},
        ]
        result = analyzer.analyze_records(telemetry, profile, runloop, runloop_gap_ms=20)
        gap = result["hitches"][0]["runloop_large_gaps"][0]
        self.assertFalse(gap["pair_verified"])
        self.assertEqual("unclassified", gap["classification"])

    def test_privacy_allowlist_blocks_raw_sensitive_and_unknown_fields(self):
        sensitive = "Secret App com.example.secret https://example.test/a /private/icon.png BASE64ICON"
        telemetry = [
            telemetry_frame(200.0, 0.016),
            {
                "event_phase": "unrecognized.payload",
                "timestamp": 200.010,
                "app_name": sensitive,
                "bundle_id": sensitive,
                "url": sensitive,
                "path": sensitive,
                "icon_data": sensitive,
                "arbitrary_unknown": sensitive,
            },
            telemetry_frame(200.030, 0.030),
        ]
        result = analyzer.analyze_records(telemetry, run_context="SELFDRIVE")
        serialized = json.dumps(result) + analyzer.render_markdown(result)
        self.assertNotIn(sensitive, serialized)
        self.assertNotIn("unrecognized.payload", serialized)
        self.assertIn("other:1", serialized)
        self.assertIn("not physical-feel evidence", serialized)

    def test_missing_optional_profiles_are_honestly_unresolved(self):
        telemetry = [telemetry_frame(50.0, 0.016), telemetry_frame(50.030, 0.030)]
        result = analyzer.analyze_records(telemetry, None, None)
        self.assertFalse(result["profile_alignment"]["profile_available"])
        self.assertFalse(result["runloop_profile_available"])
        self.assertIsNone(result["hitches"][0]["callback_total_ms"])
        self.assertEqual("UNRESOLVED", result["hitches"][0]["evidence_level"])

    def test_jsonl_loader_reports_missing_file_as_cli_input_error(self):
        missing = Path(tempfile.gettempdir()) / "frame-hitch-analyzer-no-such-file.jsonl"
        with self.assertRaises(analyzer.InputDataError) as raised:
            analyzer.load_jsonl(missing, "telemetry")
        self.assertIn(str(missing), str(raised.exception))


if __name__ == "__main__":
    unittest.main()
