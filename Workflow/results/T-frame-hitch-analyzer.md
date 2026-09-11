> **Superseded note:** A later ordinal audit found that `callback_total_ms` used `profile[i]` instead of the preceding callback `profile[i-1]`. Counts and interval summaries remain valid; callback-attribution values and the original 11-test status are superseded by `Workflow/results/T-frame-hitch-analyzer-repair.md`.

# T-frame-hitch-analyzer — Worker result

## Status

**Completed.** Date basis follows the task packet: **2026-08-28**. Repository/log timestamps dated 2026-08-29 were not used to infer execution ordering.

## Changed files (only assigned write scope)

1. `Tools/analyze_frame_hitches.py`
2. `Tools/tests/test_analyze_frame_hitches.py`
3. `Docs/FRAME_HITCH_ANALYZER.md`
4. `Workflow/results/T-frame-hitch-analyzer.md` (this result)

No Swift source, `Package.swift`, or pre-existing JSONL was modified. No Git clean/reset/commit was run.

## Delivered analyzer behavior

- Python standard library only (`argparse`, `json`, `pathlib`, `collections`, etc.); no dependency install or third-party import.
- Reads only telemetry records whose `event_phase` is `frame` for interval statistics. The report always includes `>20`, `>25`, `>33.3`, and `>50 ms` counts.
- Never subtracts telemetry wall-clock timestamps from frame-profile/runloop uptime timestamps. Telemetry-to-profile association is frame ordinal only; each adjacent ordinal is independently checked against the corresponding in-clock interval delta.
- Computes each hitch's prior/current/next intervals, callback total, directionally correct preceding-window anonymous event categories, validated runloop large gaps, and evidence state.
- A runloop gap gets an `active-like` / `waiting-like` interpretation only after checking that the immediately adjacent observed activity pair and its timestamp delta agree with `gap_ns`. Otherwise it remains `unclassified`.
- Missing frame profile or runloop profile gives overall hitch evidence `UNRESOLVED`; profile-specific evidence is retained separately so missing runloop data cannot be represented as completed attribution.
- Generated Markdown/JSON uses a fixed allow-list of categories and report-owned fields. It does not serialize source timestamps, run IDs, input paths, app names, bundle IDs, URLs, paths, icon data, or unknown source fields. `SELFDRIVE` output states that it is synthetic performance comparison data, not physical-feel evidence.

## Read-only anonymous input verification

The analyzer streams JSONL with `Path.open()` one line at a time, parses JSON objects, and builds new in-memory report records. It never opens inputs for writing. Line counts and SHA-256 values were captured before and after analysis; both observations matched.

| Anonymous input | Lines | SHA-256 |
|---|---:|---|
| Manual telemetry | 1,266 | `e5ad613aa1de2b489ccf330211dcffbe456820c844e54c0e0f9704b7e2897258` |
| Manual frame profile | 1,761 | `b159703ab92620146b3e424ec14fa17219dfbe0024653b04a27098db15a98c98` |
| SELFDRIVE-neutral telemetry | 1,023 | `9e4cc2508c45dddb9b7682d81672092113d0c588e346b14b8aeb556833e45cb2` |
| SELFDRIVE-neutral frame profile | 798 | `f1dd3785cc59c1e8aef19929b85e6f79b002af8daa1b191f1d5fc70e210a9db9` |

## Commands and actual results

### Unit tests

```bash
python3 -m unittest -v Tools/tests/test_analyze_frame_hitches.py
```

Result: **11 tests run, 0 failures (`OK`)**. Coverage includes clock-domain join protection, ordinal alignment and mismatch downgrade, preceding-window direction, exclusion of after-events, validated/unvalidated runloop pairs, privacy allow-list behavior, and missing-profile degradation.

### Manual anonymous run

After binding anonymous input shell variables, executed:

```bash
python3 Tools/analyze_frame_hitches.py "$MANUAL_TELEMETRY" \
  --frame-profile "$MANUAL_FRAME_PROFILE" \
  --format json --run-context MANUAL --output /tmp/frame-hitch-phys-result.json
```

Actual result: **596** telemetry frames; **16** intervals `>20 ms`; maximum **23.702 ms**. Frame counts matched at 596/596. All 16 hitch ordinals had `PROFILE_CORRELATED` profile evidence. The overall evidence remained `UNRESOLVED` because this validation intentionally had no runloop profile, rather than claiming root-cause attribution.

### SELFDRIVE-neutral anonymous run

```bash
python3 Tools/analyze_frame_hitches.py "$SELFDRIVE_TELEMETRY" \
  --frame-profile "$SELFDRIVE_FRAME_PROFILE" \
  --format json --run-context SELFDRIVE --output /tmp/frame-hitch-selfdrive-neutral-result.json
```

Actual result: **638** telemetry frames; **12** intervals `>20 ms`; maximum **53.510 ms**. Frame counts matched at 638/638. All 12 hitch ordinals had `PROFILE_CORRELATED` profile evidence; overall evidence was `UNRESOLVED` because runloop input was absent. The JSON includes the explicit SELFDRIVE-not-physical-feel notice.

### Existing anonymous runloop smoke

```bash
python3 Tools/analyze_frame_hitches.py "$RUNLOOP_SMOKE_TELEMETRY" \
  --frame-profile "$RUNLOOP_SMOKE_FRAME_PROFILE" \
  --runloop-profile "$RUNLOOP_SMOKE_RUNLOOP_PROFILE" \
  --runloop-gap-ms 20 --format json --run-context SELFDRIVE \
  --output /tmp/frame-hitch-runloop-smoke.json
```

Actual result: 551 frames, 6 hitches, and 3 in-window large runloop gaps. All 3 gap records passed adjacent-pair validation; classifications were one `active-like` and two `unclassified`, with no scheduler/root-cause claim.

### Privacy and input-integrity checks

```bash
rg -n -i 'launch-copy-paging-prototype|run_id|bundle|app_name|https?://|/tmp/' \
  /tmp/frame-hitch-phys-result.json \
  /tmp/frame-hitch-selfdrive-neutral-result.json \
  /tmp/frame-hitch-runloop-smoke.json
```

Result: no matches (`generated-report privacy scan: clean`).

```bash
rg -n '[[:blank:]]+$' \
  Tools/analyze_frame_hitches.py \
  Tools/tests/test_analyze_frame_hitches.py \
  Docs/FRAME_HITCH_ANALYZER.md
```

Result: no matches (`no trailing whitespace`).

## Limits / non-claims

- Frame ordinal alignment is validated locally but does not repair or hide adjacent interval mismatches; the two requested validation files contained ordinary ordinal mismatches outside their `>20 ms` hitch rows.
- Callback totals bound only the existing instrumented callback window. They do not prove absence of deferred AppKit/display/CA work, recorder effects, timer cadence effects, or scheduling effects.
- `waiting-like` means only a verified coarse runloop pair. It is not proof of system scheduling, WindowServer, or a single component.
- SELFDRIVE data remains a synthetic comparison and is not a substitute for physical trackpad validation.
