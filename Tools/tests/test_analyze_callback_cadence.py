import json
import tempfile
import unittest
from pathlib import Path

from Tools.analyze_callback_cadence import analyze, load_jsonl, render_markdown


class CallbackCadenceAnalyzerTests(unittest.TestCase):
    def callback(self, seq, entry, scheduled, raw, *, first=False, missed=0, wall=500_000, cpu=200_000, mode="default", **extra):
        value = {
            "kind": "frame_callback",
            "driver_generation": 1,
            "callback_seq": seq,
            "nominal_interval_ns": 16_666_667,
            "scheduled_ns": scheduled,
            "entry_ns": entry,
            "exit_ns": entry + wall,
            "lateness_ns": entry - scheduled,
            "missed_periods": missed,
            "first_tick": first,
            "raw_callback_interval_ns": raw,
            "simulation_dt_ns": 16_666_667,
            "callback_wall_ns": wall,
            "thread_cpu_entry_ns": 100,
            "thread_cpu_exit_ns": 100 + cpu,
            "callback_cpu_ns": cpu,
            "mode": mode,
        }
        value.update(extra)
        return value

    def test_first_tick_and_long_interval_use_preceding_callback(self):
        records = [
            self.callback(1, 116_666_667, 116_666_667, None, first=True, wall=2_000_000, cpu=1_000_000),
            self.callback(2, 150_000_000, 133_333_334, 33_333_333, missed=1, wall=700_000),
        ]
        report = analyze(records)
        self.assertEqual(report["callback_count"], 2)
        self.assertEqual(report["first_tick_summary"]["count"], 1)
        self.assertAlmostEqual(report["first_tick_summary"]["ticks"][0]["start_to_entry_ms"], 16.666667, places=5)
        self.assertEqual(report["missed_periods"]["total_missed_periods"], 1)
        hitch = report["long_intervals"][0]
        self.assertEqual(hitch["callback_seq"], 2)
        self.assertEqual(hitch["preceding_callback_wall_ms"], 2.0)
        self.assertEqual(hitch["preceding_callback_cpu_ms"], 1.0)
        self.assertAlmostEqual(hitch["recorded_exit_to_next_entry_residual_ms"], 31.333333, places=5)

    def test_unknown_fields_and_raw_mode_do_not_leak(self):
        secret = "com.secret.App /Users/me/private https://secret.invalid RAW_PRIVATE_MODE"
        records = [self.callback(1, 116_666_667, 116_666_667, None, first=True, mode="RAW_PRIVATE_MODE", app_name=secret, path=secret)]
        report = analyze(records)
        rendered = json.dumps(report, sort_keys=True) + render_markdown(report)
        self.assertNotIn(secret, rendered)
        self.assertNotIn("RAW_PRIVATE_MODE", rendered)
        self.assertEqual(report["mode_counts"]["other"], 1)

    def test_threshold_counts_are_strict(self):
        records = [
            self.callback(1, 100, 100, None, first=True),
            self.callback(2, 20_000_100, 1, 20_000_000),
            self.callback(3, 45_000_101, 1, 25_000_001),
            self.callback(4, 95_000_102, 1, 50_000_001),
        ]
        summary = analyze(records)["interval_summary"]
        self.assertEqual(summary["gt_20_0_ms"], 2)
        self.assertEqual(summary["gt_25_0_ms"], 2)
        self.assertEqual(summary["gt_33_3_ms"], 1)
        self.assertEqual(summary["gt_50_0_ms"], 1)

    def test_report_exposes_acceptance_counts_and_interval_denominator(self):
        records = [
            self.callback(1, 100, 100, None, first=True),
            self.callback(2, 16_700_100, 16_666_767, 16_700_000),
            {"kind": "frame_callback", "callback_seq": 3},
            {"kind": "other", "secret": "must-not-leak"},
        ]
        report = analyze(records)
        self.assertEqual(report["input_record_count"], 4)
        self.assertEqual(report["callback_count"], 2)
        self.assertEqual(report["raw_interval_count"], 1)
        self.assertEqual(report["rejected_callback_count"], 1)
        self.assertEqual(report["ignored_non_callback_count"], 1)
        rendered = render_markdown(report)
        self.assertIn("raw intervals analyzed: 1", rendered)
        self.assertIn("generations with at least one recorded callback: 1", rendered)
        self.assertNotIn("must-not-leak", rendered)

    def test_jsonl_loader_rejects_non_object(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.jsonl"
            path.write_text("[]\n")
            with self.assertRaisesRegex(ValueError, "expected JSON object"):
                load_jsonl(path)


if __name__ == "__main__":
    unittest.main()
