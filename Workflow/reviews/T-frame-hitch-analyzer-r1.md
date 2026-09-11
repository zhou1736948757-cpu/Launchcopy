> **Superseded note:** This review did not catch a one-frame callback attribution defect. Its original PASS is preserved as historical evidence but is no longer the current analyzer verdict. See `Workflow/reviews/T-frame-hitch-analyzer-repair-r1.md`.

# Review: T-frame-hitch-analyzer-r1

## Verdict

**PASS**

- Review date basis: **2026-08-28** (per task packet).
- This conclusion does **not** use filesystem or machine-generated `2026-08-29` timestamps as proof of execution ordering.
- Scope observed: read-only inspection of the task/result, analyzer, tests, documentation, and the four required anonymous inputs. The only repository write made by this review is this artifact.

## Findings

### P0

None.

### P1

None.

### P2

None.

## Acceptance evidence

### Clock domains and ordinal safety

- The analyzer explicitly documents that telemetry uses a wall clock while profile/runloop use uptime, and says it deliberately avoids cross-domain timestamp subtraction (`Tools/analyze_frame_hitches.py:1-8`).
- Frame/profile correlation is ordinal-only. Its verifier computes only the adjacent profile delta, compares it with the telemetry interval, and records a per-ordinal `True` / `False` / unavailable result (`Tools/analyze_frame_hitches.py:154-211`).
- A hitch is `PROFILE_CORRELATED` only when that ordinal's local interval verification is `True` and its profile parts are valid; otherwise it is `PROFILE_ORDINAL_UNVERIFIED` (`Tools/analyze_frame_hitches.py:347-352`). This prevents a count match or an unrelated ordinal from upgrading a mismatch.
- Unit coverage includes a deliberately incompatible telemetry/profile clock magnitude without a cross-clock join and an ordinal-delta mismatch that remains unverified (`Tools/tests/test_analyze_frame_hitches.py:43-77`).

### Directional telemetry window

- The pre-window uses the previous frame timestamp as an exclusive lower bound and the current frame as an inclusive upper bound, excludes `event_phase == "frame"`, and cannot include a post-frame event (`Tools/analyze_frame_hitches.py:214-233`).
- The preceding-event and after-event failure modes are covered directly (`Tools/tests/test_analyze_frame_hitches.py:79-96`).

### Runloop interpretation boundary

- A candidate runloop gap must be in the frame-profile uptime window and must have a real immediately preceding observation in the supplied runloop stream (`Tools/analyze_frame_hitches.py:256-283`).
- The declared `gap_ns` is checked against that adjacent observation timestamp delta with the configured bounded tolerance before any interpretation (`Tools/analyze_frame_hitches.py:284-285`).
- Classification is `unclassified` unless verification passes; only the enumerated verified pairs become `waiting-like` or `active-like` (`Tools/analyze_frame_hitches.py:242-253`, `Tools/analyze_frame_hitches.py:286-296`).
- Synthetic unit cases cover both a verified `beforeWaiting -> afterWaiting` pair and an invalid gap that must stay `unclassified` (`Tools/tests/test_analyze_frame_hitches.py:98-121`).
- Documentation expressly limits `waiting-like`: it is not proof of scheduler, WindowServer, or any single root cause (`Docs/FRAME_HITCH_ANALYZER.md:9-10`).

### Honest degradation and privacy

- If either optional profile is absent, the overall hitch evidence is retained as `UNRESOLVED`; the profile-only result is not presented as complete cross-artifact attribution (`Tools/analyze_frame_hitches.py:354-361`). The `SELFDRIVE` context is explicitly called synthetic comparison rather than physical-feel evidence (`Tools/analyze_frame_hitches.py:383-390`; `Docs/FRAME_HITCH_ANALYZER.md:13`).
- Source telemetry is reduced to a fixed anonymous event-category vocabulary (`Tools/analyze_frame_hitches.py:74-95`), and successful report records contain only report-owned ordinals, durations, evidence labels, fixed categories, and fixed metadata (`Tools/analyze_frame_hitches.py:363-405`). Markdown rendering interpolates those report-owned fields only (`Tools/analyze_frame_hitches.py:413-471`).
- The test suite injects app name, bundle ID, URL, path, icon data, and an unknown field, then verifies the serialized JSON/Markdown does not contain them (`Tools/tests/test_analyze_frame_hitches.py:123-145`).

## Required anonymous-input recomputation

Input identity was checked by line count and SHA-256 during this review. These hashes identify the inspected anonymous snapshots; they are not timestamp-based sequencing evidence.

| Anonymous input | Lines | SHA-256 |
|---|---:|---|
| Manual telemetry | 1,266 | `e5ad613aa1de2b489ccf330211dcffbe456820c844e54c0e0f9704b7e2897258` |
| Manual frame profile | 1,761 | `b159703ab92620146b3e424ec14fa17219dfbe0024653b04a27098db15a98c98` |
| SELFDRIVE-neutral telemetry | 1,023 | `9e4cc2508c45dddb9b7682d81672092113d0c588e346b14b8aeb556833e45cb2` |
| SELFDRIVE-neutral frame profile | 798 | `f1dd3785cc59c1e8aef19929b85e6f79b002af8daa1b191f1d5fc70e210a9db9` |

| Run | Analyzer recomputation | Independent source count | Result |
|---|---|---|---|
| Manual | 596 frames; 16 intervals `>20ms`; max 23.702 ms | 596 / 16 / 23.702 ms | Matches required acceptance values |
| SELFDRIVE-neutral | 638 frames; 12 intervals `>20ms`; max 53.510 ms | 638 / 12 / 53.510 ms | Matches required acceptance values |

For both runs, telemetry/profile frame counts matched. The analyzer reported ordinary adjacent-delta mismatches transparently (Manual: 28; SELFDRIVE-neutral: 33); all reported hitch ordinals were locally verified and therefore `PROFILE_CORRELATED`. Overall evidence remained `UNRESOLVED` because these required runs did not supply a runloop profile.

The generated JSON reports had exactly these top-level keys: `context_note`, `frame_count`, `hitches`, `interval_summary`, `privacy_note`, `profile_alignment`, `run_context`, `runloop_profile_available`, and `schema_version`. A streaming scan of each generated report found no input-path prefix, `run_id`, `bundle`, `app_name`, URL, icon-data, or `timestamp` field. The SELFDRIVE run also contained the required non-physical-feel notice.

## Commands executed and results

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  Tools/tests/test_analyze_frame_hitches.py
```

Result: **11 tests run, 0 failures, `OK`**.

```bash
python3 Tools/analyze_frame_hitches.py "$MANUAL_TELEMETRY" \
  --frame-profile "$MANUAL_FRAME_PROFILE" \
  --format json --run-context MANUAL

python3 Tools/analyze_frame_hitches.py "$SELFDRIVE_TELEMETRY" \
  --frame-profile "$SELFDRIVE_FRAME_PROFILE" \
  --format json --run-context SELFDRIVE
```

Result: The two core analyzer invocations above were re-run by this reviewer as stdout pipelines and parsed in-memory for the required metric rows.

```bash
shasum -a 256 "$MANUAL_TELEMETRY" "$MANUAL_FRAME_PROFILE" \
  "$SELFDRIVE_TELEMETRY" "$SELFDRIVE_FRAME_PROFILE"
wc -l "$MANUAL_TELEMETRY" "$MANUAL_FRAME_PROFILE" \
  "$SELFDRIVE_TELEMETRY" "$SELFDRIVE_FRAME_PROFILE"
```

Result: line counts and hashes match the table above.

## Automated-evidence limits

- This is a code, unit-test, JSON report, and anonymous-data recomputation review. It is not a physical trackpad validation, subjective smoothness assessment, or release/CI acceptance claim.
- The four required inputs contain telemetry and frame-profile evidence, not a required real-data runloop profile. Runloop safety was therefore verified from implementation plus targeted synthetic unit cases, not from a claimed physical root-cause conclusion.
- A `waiting-like` label remains a validated coarse runloop-pair description only; it does not establish scheduler, WindowServer, or any other single cause.
