# Native source event evidence — independent bounded wording review

Date: 2026-10-15. Repository: `/Users/mac/Projects/Launch_Copy/PagingPrototype`.

## Verdict and findings

**PASS — bounded evidence quality and claim wording, at the snapshots identified below. No actionable evidence-wording finding.** The receipt and latest stage entry consistently support healthy-root fixture arrival/removal and an initial Sources-status smoke on the reported candidate. This is an independent review of saved evidence and Main's supplied CUA account, **not independent live observation**, a repeated source-code review, or whole-goal acceptance.

**Reviewer executions: 0 tests, 0 builds, 0 Swift invocations, 0 process inspection/control actions, 0 native UI actions, 0 browser actions, 0 agents spawned or messaged.** Work comprised file/directory reads, SHA-256 snapshot checks, and this one report write. No source, configuration, other document, fixture, or external reference directory was changed or inspected beyond the explicitly listed inputs. Main's execution counts below are reported evidence, not reviewer executions.

## Evidence identity and bounded observations

Main and `native-healthy-root.json` identify executable SHA-256 `66cd55c147954f91387131a0585bb970bda5ace6925079ab45138b2ba653a32b`, PID **65891**. This reviewer did not independently hash the executable or query the process. The fresh private profile's Applications baseline was **0 apps**. The stage explicitly corrects the earlier automatic-40-app-seeding assumption; that assumption must not be reused as current fixture evidence.

| Evidence | Supported bounded gate | Limit |
| --- | --- | --- |
| Main reports native Sources automatic checkbox value 1 and normal enabled status before fixture moves; receipt records `automatic_observed: true`. No Refresh Now or Apply. | Initial native Sources/status smoke on the identified candidate and healthy root. | Enabled status alone does not establish unavailable-root degradation or execution of the new loss branch. |
| AX-set exact query `Native Source Probe` initially returns no results. | Discriminating zero-result search baseline. | No baseline 40-app catalog or group membership exists in this fresh profile. |
| Authored Info-only APPL fixture atomically moved from private-profile `SourceControlStaged` into existing Applications; named `Native Source Probe` result appears automatically. Receipt move-in timestamp: `2026-10-15T13:10:12.844522+00:00`, inode **38242711**. | Observed native catalog/search response to fixture arrival inside a healthy watched root, without explicit refresh. | This is an authored catalog fixture, not evidence that an executable application was launched, nor proof of a particular OS callback or internal branch trace. |
| Same fixture moved out into staging; no results return and exact query remains. Receipt move-out timestamp: `2026-10-15T13:10:25.768918+00:00`, inode **38242711**. | Observed native catalog/search response to fixture removal and query retention through both transitions. Same recorded inode supports fixture identity across the moves. | The root itself remained available. The timestamps identify move actions, not measured UI completion times or an event-latency distribution. |

The supplied Main account/stage records no Refresh Now, Apply, or restart during this sequence; the receipt explicitly records `refresh_now_used: false` and the move results. There are **2 recorded fixture moves**, one appearance observation and one disappearance observation. This supports the observed automatic healthy-root behavior; it does not prove universal event delivery, deterministic latency, or specific FSEvents callback delivery independently of Main's observations. The fixture ended in staging according to that account. An empty Applications root after removal is not an unavailable root.

## Gates that remain open or separate

- **Unavailable-root automatic notification and native coverage-loss latch:** not exercised by this new sequence. No root was made missing/unreadable, so no delivered invalidation under root loss, degraded-status transition, persistence of the latch after availability returns, or explicit retry clearing that latch was observed here. Existing causal unit-test evidence and source review remain separate evidence layers.
- **Canonical/group retention:** exact-query retention is supported, but no group fixture was present in the fresh profile. Neither absence of a group nor a zero-result query proves preservation of canonical references/group membership during source loss. Old `889d...` manual missing/degraded/recovery and Group1 evidence is historical prepatch evidence, not a rerun on `66cd55c1`.
- **Final Sources status, normal Quit, and process absence:** Main was still finishing these when the inspected stage snapshot was read. The receipt snapshot has no final status or cleanup fields. Do not claim these complete from this review; a later appended receipt/stage section needs its own attribution. Initial normal enabled status is supported, final status remains unreviewed.
- **Latency, physical/manual input and other interaction acceptance, whole-goal parity:** no new acceptance claim. AX-assisted search and observed event results do not substitute for physical-input acceptance or performance measurements.
- **Wallpaper:** remains `NOT_FIXED` in the inspected stage; separate approval/control work remains pending. Source-event evidence does not close that issue.

## Relationship to the existing repair review

`Docs/APP_SOURCES_RUNTIME_COVERAGE_REPAIR.md` explicitly limits changed-candidate native work to Sources/status smoke and does not promise automatic root-return repair. `SOURCE_RUNTIME_COVERAGE_REVIEW.md` already provides the bounded source verdict; this report does not repeat or expand it.

That earlier review reports Main receipts of RED **2 tests / 6 assertion failures**, overlap RED **1 test / 1 failure**, and final focused **102 tests / 0 failures** (coordinator **16 / 0**). The inspected stage separately reports Main full-suite **2680 / 0**, Debug, Release and packaging checks. This reviewer did not open those logs or validate their execution anew; none is a substitute for the missing native root-loss gate. The earlier review's statement that changed-candidate native work was then pending is correctly understood as its historical snapshot. The stage's later unlocked-resume entries supersede the former lock state without silently rewriting it.

## Exact inputs and snapshot boundary

Content inputs inspected in this review (six files):

1. `/Users/mac/.codex/RTK.md` — shell-prefix rules.
2. `AGENTS.md` — project rules; direct task authorization governs the old-Chief waiver and report-only scope.
3. `Docs/APP_SOURCES_RUNTIME_COVERAGE_REPAIR.md` — SHA-256 `ae8ca9326908bd153321b0a04cd683ffc45ab9a2949251c36339ef9081bd26f6`.
4. `Workflow/results/SOURCE_RUNTIME_COVERAGE_REVIEW.md` — SHA-256 `ee40596d08ae9766baf2de31260ac4d959fe3e464698ee5cbe72167296159226`.
5. `.build/verification/20261015/source-reappearance-native/coverage-repair/native-healthy-root.json` — SHA-256 `c71fc468e2f4f582998b24931eeef1a856df6c029414873bc562886cc3d33b35`; snapshot ends with `move_out_native_result`, with no final-status/Quit receipt.
6. `Workflow/stage-summaries/2026-10-15-source-reappearance-native.md` — SHA-256 `8b51f788ae113e5b1ae532942f02255da50e9073adfb54cf45ddf48ff6d917ad`; snapshot ends with “Native healthy-root evidence and review dispatch.”

Project/evidence directory names and absence of the assigned output file were also checked. Main's exact CUA narrative supplied in this task was treated as attributed evidence. No screenshots, executable, source bodies, test/build/package logs, recovery metadata, live process, fixture directory contents, or external reference directories were independently inspected. Later concurrent appends are outside these snapshots and do not invalidate their bounded historical reading.

Only output written: `Workflow/results/SOURCE_NATIVE_EVENT_EVIDENCE_REVIEW.md`. Next evidence action belongs to Main: append final Sources/status and normal-Quit/cleanup observations, preserving the remaining gate boundaries above. No further source change or test/build execution is requested by this wording audit.
