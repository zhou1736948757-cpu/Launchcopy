import io
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

from Tools.analyze_callback_runloop_correlation import (
    GATE,
    InputDataError,
    analyze,
    load_jsonl,
    main,
    render_markdown,
)


class CallbackRunLoopCorrelationAnalyzerTests(unittest.TestCase):
    def callback(
        self,
        seq,
        entry,
        *,
        exit_ns=None,
        pre_return=None,
        first=False,
        missed=0,
        gen=1,
        raw=None,
        scheduled=None,
        interval=16_666_667,
        mode="default",
        include_pre_return=True,
        **extra,
    ):
        exit_value = entry + 500_000 if exit_ns is None else exit_ns
        value = {
            "kind": "frame_callback",
            "driver_generation": gen,
            "callback_seq": seq,
            "nominal_interval_ns": interval,
            "scheduled_ns": entry if scheduled is None else scheduled,
            "entry_ns": entry,
            "exit_ns": exit_value,
            "lateness_ns": 0,
            "missed_periods": missed,
            "first_tick": first,
            "raw_callback_interval_ns": raw,
            "mode": mode,
        }
        if include_pre_return:
            value["pre_return_ns"] = exit_value + 10_000 if pre_return is None else pre_return
        value.update(extra)
        return value

    def arm(self, gen, arm_ns, interval=16_666_667, tolerance=8_333_000, **extra):
        value = {
            "kind": "timer_generation_arm",
            "driver_generation": gen,
            "arm_ns": arm_ns,
            "nominal_first_deadline_ns": arm_ns + interval,
            "interval_ns": interval,
            "tolerance_ns": tolerance,
        }
        value.update(extra)
        return value

    def runloop(
        self,
        seq,
        timestamp_ns,
        activity,
        *,
        previous="none",
        mode="default",
        include_timestamp_ns=True,
        timestamp=None,
        **extra,
    ):
        value = {
            "kind": "runloop",
            "activity": activity,
            "observation_seq": seq,
            "gap_ns": 0,
            "previous_activity": previous,
            "mode": mode,
            "since_same_ns": 0,
        }
        if include_timestamp_ns:
            value["timestamp_ns"] = timestamp_ns
        if timestamp is not None:
            value["timestamp"] = timestamp
        value.update(extra)
        return value

    def test_old_schema_without_pre_return_is_schema_callback_without_tail(self):
        records = [
            self.callback(1, 1_000, exit_ns=1_500, first=True, include_pre_return=False),
            self.callback(2, 2_000, exit_ns=2_400, raw=1_000, include_pre_return=False),
        ]
        report = analyze(records)
        self.assertEqual(report["accepted_callback_count"], 2)
        self.assertEqual(report["schema_callback_without_tail_count"], 2)
        self.assertEqual(report["join_class_counts"]["SCHEMA_CALLBACK_WITHOUT_TAIL"], 1)
        remainder = report["remainders"][0]
        self.assertEqual(remainder["join_class"], "SCHEMA_CALLBACK_WITHOUT_TAIL")
        self.assertIsNone(remainder["closure_tail_ns"])
        self.assertIsNone(remainder["post_tail_remainder_ns"])
        self.assertNotEqual(remainder["post_tail_remainder_ns"], 2_000 - 1_500)
        self.assertEqual(remainder["recorded_body_ns"], 500)

    def test_missing_pre_return_does_not_split_tail_or_use_exit_as_pre_return(self):
        records = [
            self.callback(1, 10_000, exit_ns=11_000, first=True, pre_return=None),
            self.callback(2, 40_000, exit_ns=41_000, raw=30_000, pre_return=41_200),
        ]
        records[0]["pre_return_ns"] = None
        report = analyze(records)
        remainder = report["remainders"][0]
        self.assertEqual(remainder["join_class"], "SCHEMA_CALLBACK_WITHOUT_TAIL")
        self.assertIsNone(remainder["post_tail_remainder_ns"])
        self.assertIsNone(remainder["uncovered_ns"])
        self.assertNotEqual(remainder.get("post_tail_remainder_ns"), 29_000)

    def test_missing_timestamp_ns_is_accepted_but_not_joinable(self):
        callbacks = [
            self.callback(1, 1_000, exit_ns=1_100, pre_return=1_200, first=True),
            self.callback(2, 2_000, exit_ns=2_100, pre_return=2_200, raw=1_000),
        ]
        runloops = [
            self.runloop(
                1,
                1_500,
                "beforeWaiting",
                include_timestamp_ns=False,
                timestamp=1_500.25,
            ),
            self.runloop(
                2,
                1_800,
                "afterWaiting",
                include_timestamp_ns=False,
                timestamp=1_800.5,
            ),
        ]
        report = analyze(callbacks, runloops)
        self.assertEqual(report["accepted_runloop_count"], 2)
        self.assertEqual(report["joinable_runloop_count"], 0)
        remainder = report["remainders"][0]
        self.assertEqual(remainder["join_class"], "NO_OBSERVER_BOUNDARY")
        self.assertEqual(remainder["uncovered_ns"], 800)
        rendered = json.dumps(report) + render_markdown(report)
        self.assertNotIn("1.50025", rendered)
        self.assertNotIn("1500.25", rendered)
        self.assertNotIn("1800.5", rendered)

    def test_equal_bounds_are_zero_length_not_waiting_bounded(self):
        records = [
            self.callback(1, 1_000, exit_ns=1_500, pre_return=2_000, first=True),
            self.callback(2, 2_000, exit_ns=2_400, pre_return=2_500, raw=1_000),
        ]
        report = analyze(records, [])
        remainder = report["remainders"][0]
        self.assertEqual(remainder["post_tail_remainder_ns"], 0)
        self.assertEqual(remainder["uncovered_ns"], 0)
        self.assertEqual(remainder["join_class"], "NO_OBSERVER_BOUNDARY")
        self.assertNotEqual(remainder["join_class"], "WAITING_BOUNDED")

    def test_no_observer_boundary(self):
        callbacks = [
            self.callback(1, 1_000, exit_ns=1_200, pre_return=1_300, first=True),
            self.callback(2, 5_000, exit_ns=5_200, pre_return=5_300, raw=4_000),
        ]
        runloops = [
            self.runloop(1, 900, "beforeWaiting"),
            self.runloop(2, 5_100, "afterWaiting", previous="beforeWaiting"),
        ]
        report = analyze(callbacks, runloops)
        remainder = report["remainders"][0]
        self.assertEqual(remainder["join_class"], "NO_OBSERVER_BOUNDARY")
        self.assertEqual(remainder["post_tail_remainder_ns"], 3_700)
        self.assertEqual(remainder["uncovered_ns"], 3_700)
        self.assertEqual(remainder["waiting_pair_ns"], 0)
        self.assertEqual(remainder["active_pair_ns"], 0)

    def test_waiting_bounded_classification(self):
        callbacks = [
            self.callback(1, 1_000, exit_ns=1_100, pre_return=1_200, first=True),
            self.callback(2, 10_000, exit_ns=10_100, pre_return=10_200, raw=9_000),
        ]
        runloops = [
            self.runloop(1, 2_000, "beforeWaiting"),
            self.runloop(2, 8_000, "afterWaiting", previous="beforeWaiting"),
        ]
        report = analyze(callbacks, runloops)
        remainder = report["remainders"][0]
        self.assertEqual(remainder["join_class"], "WAITING_BOUNDED")
        self.assertEqual(remainder["waiting_pair_ns"], 6_000)
        self.assertEqual(remainder["active_pair_ns"], 0)
        self.assertEqual(remainder["uncovered_ns"], (2_000 - 1_200) + (10_000 - 8_000))

    def test_runloop_active_bounded_classification(self):
        callbacks = [
            self.callback(1, 1_000, exit_ns=1_100, pre_return=1_200, first=True),
            self.callback(2, 5_000, exit_ns=5_100, pre_return=5_200, raw=4_000),
        ]
        runloops = [
            self.runloop(1, 2_000, "beforeTimers"),
            self.runloop(2, 2_500, "beforeSources", previous="beforeTimers"),
            self.runloop(3, 3_000, "beforeWaiting", previous="beforeSources"),
        ]
        report = analyze(callbacks, runloops)
        remainder = report["remainders"][0]
        self.assertEqual(remainder["join_class"], "RUNLOOP_ACTIVE_BOUNDED")
        self.assertEqual(remainder["waiting_pair_ns"], 0)
        self.assertEqual(remainder["active_pair_ns"], 1_000)

    def test_multiple_observers_mixed_boundaries(self):
        callbacks = [
            self.callback(1, 1_000, exit_ns=1_100, pre_return=1_200, first=True),
            self.callback(2, 20_000, exit_ns=20_100, pre_return=20_200, raw=19_000),
        ]
        runloops = [
            self.runloop(1, 2_000, "beforeWaiting"),
            self.runloop(2, 8_000, "afterWaiting", previous="beforeWaiting"),
            self.runloop(3, 9_000, "beforeTimers", previous="afterWaiting"),
            self.runloop(4, 10_000, "beforeSources", previous="beforeTimers"),
        ]
        report = analyze(callbacks, runloops)
        remainder = report["remainders"][0]
        self.assertEqual(remainder["join_class"], "MIXED_OBSERVED_BOUNDARIES")
        self.assertEqual(remainder["waiting_pair_ns"], 6_000)
        self.assertEqual(remainder["active_pair_ns"], 2_000)
        self.assertEqual(remainder["uncovered_ns"], (2_000 - 1_200) + (20_000 - 10_000))

    def test_unclassified_single_observer_and_unknown_activity(self):
        callbacks = [
            self.callback(1, 1_000, exit_ns=1_100, pre_return=1_200, first=True),
            self.callback(2, 4_000, exit_ns=4_100, pre_return=4_200, raw=3_000),
        ]
        runloops = [self.runloop(1, 2_000, "beforeWaiting")]
        report = analyze(callbacks, runloops)
        self.assertEqual(report["remainders"][0]["join_class"], "UNCLASSIFIED")

        secret_activity = "RAW_PRIVATE_ACTIVITY"
        unknown = [
            self.runloop(1, 2_000, secret_activity),
            self.runloop(2, 3_000, secret_activity, previous=secret_activity),
        ]
        unknown_report = analyze(callbacks, unknown)
        self.assertEqual(unknown_report["remainders"][0]["join_class"], "UNCLASSIFIED")
        rendered = json.dumps(unknown_report) + render_markdown(unknown_report)
        self.assertNotIn(secret_activity, rendered)

    def test_cross_generation_is_not_joined(self):
        callbacks = [
            self.callback(1, 1_000, exit_ns=1_100, pre_return=1_200, first=True, gen=1),
            self.callback(2, 5_000, exit_ns=5_100, pre_return=5_200, raw=4_000, gen=1),
            self.callback(1, 8_000, exit_ns=8_100, pre_return=8_200, first=True, gen=2),
        ]
        runloops = [
            self.runloop(1, 6_000, "beforeWaiting"),
            self.runloop(2, 7_000, "afterWaiting", previous="beforeWaiting"),
        ]
        report = analyze(callbacks, runloops)
        self.assertEqual(len(report["remainders"]), 1)
        self.assertEqual(report["remainders"][0]["driver_generation"], 1)
        self.assertEqual(report["remainders"][0]["callback_seq"], 2)
        self.assertEqual(report["recorded_generation_count"], 2)
        self.assertFalse(
            any(
                item["driver_generation"] == 1 and item.get("callback_seq") == 1 and item.get("preceding_callback_seq") == 2
                for item in report["remainders"]
            )
        )

    def test_first_tick_with_arm_uses_arm_ns(self):
        records = [
            self.arm(1, 1_000),
            self.callback(
                1,
                5_000,
                exit_ns=5_400,
                pre_return=5_500,
                first=True,
                scheduled=17_666_667,
                interval=16_666_667,
            ),
        ]
        report = analyze(records)
        tick = report["first_tick_summary"]["ticks"][0]
        self.assertEqual(tick["status"], "ok")
        self.assertEqual(tick["delay_ns"], 4_000)
        self.assertNotEqual(tick["delay_ns"], 5_000 - (17_666_667 - 16_666_667))
        self.assertEqual(report["first_tick_summary"]["with_arm_count"], 1)
        self.assertEqual(report["raw_interval_count"], 0)

    def test_first_tick_without_arm_does_not_infer_from_scheduled(self):
        records = [
            self.callback(
                1,
                250_000_000,
                exit_ns=250_500_000,
                pre_return=250_510_000,
                first=True,
                scheduled=200_000_000,
                interval=16_666_667,
            )
        ]
        report = analyze(records)
        tick = report["first_tick_summary"]["ticks"][0]
        self.assertEqual(tick["status"], "FIRST_TICK_WITHOUT_ARM")
        self.assertIsNone(tick["delay_ns"])
        inferred = 250_000_000 - (200_000_000 - 16_666_667)
        self.assertNotEqual(tick["delay_ns"], inferred)
        self.assertEqual(report["first_tick_without_arm_count"], 1)
        self.assertEqual(report["first_tick_summary"]["delay"]["count"], 0)

    def test_negative_remainder_is_invalid_not_clamped(self):
        records = [
            self.callback(1, 1_000, exit_ns=1_100, pre_return=5_000, first=True),
            self.callback(2, 4_000, exit_ns=4_100, pre_return=4_200, raw=3_000),
        ]
        report = analyze(records)
        remainder = report["remainders"][0]
        self.assertFalse(remainder["valid"])
        self.assertIsNone(remainder["post_tail_remainder_ns"])
        self.assertIsNone(remainder["uncovered_ns"])
        self.assertGreaterEqual(report["invalid_sample_count"], 1)
        self.assertTrue(any(sample["reason"] == "NEGATIVE_DELTA" for sample in report["invalid_samples"]))
        self.assertNotEqual(remainder["post_tail_remainder_ns"], 0)

    def test_negative_body_and_tail_are_invalid_not_clamped(self):
        records = [
            self.callback(1, 5_000, exit_ns=4_000, pre_return=3_000, first=True),
            self.callback(2, 10_000, exit_ns=10_100, pre_return=10_200, raw=5_000),
        ]
        report = analyze(records)
        self.assertGreaterEqual(report["invalid_sample_count"], 2)
        reasons = {sample["kind"] for sample in report["invalid_samples"]}
        self.assertIn("callback_body", reasons)
        self.assertIn("closure_tail", reasons)
        remainder = report["remainders"][0]
        self.assertIsNone(remainder["recorded_body_ns"])
        self.assertIsNone(remainder["closure_tail_ns"])
        self.assertNotEqual(remainder["recorded_body_ns"], 0)
        self.assertNotEqual(remainder["closure_tail_ns"], 0)

    def test_privacy_does_not_leak_secret_fields_or_raw_mode(self):
        secret = "com.secret.App /Users/me/private https://secret.invalid RAW_PRIVATE_MODE"
        records = [
            self.arm(1, 1_000, **{"run_id": secret, "path": secret}),
            self.callback(
                1,
                2_000,
                first=True,
                mode="RAW_PRIVATE_MODE",
                app_name=secret,
                path=secret,
                url=secret,
                run_id=secret,
            ),
            self.callback(
                2,
                30_000_000,
                raw=28_000_000,
                mode="RAW_PRIVATE_MODE",
                app_name=secret,
            ),
            {"kind": "other", "secret": secret, "path": secret},
        ]
        runloops = [
            self.runloop(
                1,
                3_000,
                "beforeWaiting",
                mode="RAW_PRIVATE_MODE",
                path=secret,
                bundle_id=secret,
            )
        ]
        report = analyze(records, runloops)
        rendered = json.dumps(report, sort_keys=True) + render_markdown(report)
        self.assertNotIn(secret, rendered)
        self.assertNotIn("RAW_PRIVATE_MODE", rendered)
        self.assertNotIn("/Users/me/private", rendered)
        self.assertEqual(report["mode_counts"]["other"], 2)
        self.assertEqual(report["gate"], GATE)
        self.assertNotIn("ROOT_CAUSE_FOUND", rendered)

    def test_report_exposes_required_counts_and_markdown_denominators(self):
        records = [
            self.arm(1, 1_000),
            {"kind": "timer_generation_arm", "driver_generation": 1},
            self.callback(1, 2_000, first=True),
            self.callback(2, 18_700_000, raw=16_698_000),
            {"kind": "frame_callback", "callback_seq": 3},
            {"kind": "other", "secret": "must-not-leak"},
        ]
        runloops = [
            self.runloop(1, 3_000, "beforeTimers"),
            {"kind": "runloop", "activity": "beforeWaiting", "timestamp_ns": "not-a-number"},
        ]
        report = analyze(records, runloops)
        self.assertEqual(report["input_record_count"], 8)
        self.assertEqual(report["accepted_callback_count"], 2)
        self.assertEqual(report["rejected_callback_count"], 1)
        self.assertEqual(report["ignored_non_callback_count"], 1)
        self.assertEqual(report["accepted_arm_count"], 1)
        self.assertEqual(report["rejected_arm_count"], 1)
        self.assertEqual(report["accepted_runloop_count"], 1)
        self.assertEqual(report["rejected_runloop_count"], 1)
        self.assertEqual(report["raw_interval_count"], 1)
        self.assertEqual(report["first_tick_count"], 1)
        self.assertEqual(report["recorded_generation_count"], 1)
        rendered = render_markdown(report)
        for phrase in (
            "input records:",
            "accepted callback records:",
            "rejected callback records:",
            "ignored non-callback records:",
            "accepted arm records:",
            "rejected arm records:",
            "accepted runloop records:",
            "rejected runloop records:",
            "raw intervals analyzed:",
            "first ticks analyzed separately:",
            "generations observed:",
            "invalid samples:",
        ):
            self.assertIn(phrase, rendered)
        self.assertIn("CAUSALITY_UNRESOLVED", rendered)
        self.assertNotIn("must-not-leak", rendered)
        self.assertNotIn("ROOT_CAUSE_FOUND", rendered)

    def test_jsonl_loader_rejects_malformed_line(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.jsonl"
            path.write_text("{}\n{not json}\n")
            with self.assertRaisesRegex(InputDataError, "invalid JSONL"):
                load_jsonl(path)

    def test_jsonl_loader_rejects_non_object(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.jsonl"
            path.write_text("[]\n")
            with self.assertRaisesRegex(InputDataError, "expected JSON object"):
                load_jsonl(path)

    def test_cli_reads_callback_and_runloop_files(self):
        with tempfile.TemporaryDirectory() as directory:
            directory_path = Path(directory)
            callback_path = directory_path / "callback.jsonl"
            runloop_path = directory_path / "runloop.jsonl"
            callback_path.write_text(
                "\n".join(
                    json.dumps(record)
                    for record in [
                        self.arm(1, 1_000),
                        self.callback(1, 2_000, exit_ns=2_100, first=True, pre_return=2_200),
                        self.callback(2, 40_000_000, exit_ns=40_000_100, raw=39_998_000, pre_return=40_000_200),
                    ]
                )
                + "\n"
            )
            runloop_path.write_text(
                "\n".join(
                    json.dumps(record)
                    for record in [
                        self.runloop(1, 3_000, "beforeWaiting"),
                        self.runloop(2, 30_000_000, "afterWaiting", previous="beforeWaiting"),
                    ]
                )
                + "\n"
            )
            stdout = io.StringIO()
            stderr = io.StringIO()
            with redirect_stdout(stdout), redirect_stderr(stderr):
                code = main(
                    [
                        "--callback",
                        str(callback_path),
                        "--runloop",
                        str(runloop_path),
                        "--format",
                        "json",
                        "--hitch-ms",
                        "25",
                    ]
                )
            self.assertEqual(code, 0)
            self.assertEqual(stderr.getvalue(), "")
            payload = json.loads(stdout.getvalue())
            self.assertEqual(payload["gate"], GATE)
            self.assertEqual(payload["long_intervals"][0]["join_class"], "WAITING_BOUNDED")
            self.assertNotIn("ROOT_CAUSE_FOUND", stdout.getvalue())

    def test_cli_malformed_file_returns_two(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.jsonl"
            path.write_text("{not json}\n")
            stdout = io.StringIO()
            stderr = io.StringIO()
            with redirect_stdout(stdout), redirect_stderr(stderr):
                code = main(["--callback", str(path), "--format", "json"])
            self.assertEqual(code, 2)
            self.assertIn("invalid JSONL", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
