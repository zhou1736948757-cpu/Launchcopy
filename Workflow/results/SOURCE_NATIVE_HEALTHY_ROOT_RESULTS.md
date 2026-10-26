# Source monitoring — native healthy-root verification

Date: 2026-10-15. Main native observations; not independent live Reviewer acceptance.

## Candidate and environment
- Existing unsigned, uninstalled `source-coverage-rc-20261015-r1/LaunchcopyUITest.app`.
- Executable SHA-256: `66cd55c147954f91387131a0585bb970bda5ace6925079ab45138b2ba653a32b`; PID 65891.
- Ordinary non-topmost isolated GUI profile. It starts with an **empty** Applications directory. Correction: the prior handoff incorrectly assumed automatic seeding of 40 apps/Group 1. That dataset belongs to a different candidate profile, which was not copied or modified.
- Native Sources checkbox on; status: automatic refresh enabled, changes coalesced. No Refresh Now, Apply, source preference edits, or restart during event test.

## Observed transaction
| Step | File action / native result |
| --- | --- |
| Baseline | AX search value `Native Source Probe`; no applications found. |
| Install simulation | Atomically moved one authored Info-only APPL bundle from candidate-local SourceControlStaged into the existing watched Applications directory. Native result named Native Source Probe appeared; exact query retained. |
| Removal simulation | Moved that same bundle back to staging, inode 38242711 unchanged. Native no-results state returned; exact query retained. |
| Restore | Cleared query; original empty catalog restored. Sources still enabled, checkbox on. |
| Exit | Normal application-menu Quit; exact executable process absent, verified without a post-Quit app query. |

## Evidence / boundaries
Receipt: `.build/verification/20261015/source-reappearance-native/coverage-repair/native-healthy-root.json`.
All 455 frozen input hashes and executable hash reverified after native actions; zero source/test/resource changes. `git diff --check` passed. No redundant tests/builds were run this turn; prior 2680/0 XCTest and builds belong to the repair execution, not new executions.

**PASS (bounded):** real native file events in a healthy existing synthetic source update the visible catalog automatically in both directions, preserve the query, and retain normal source coverage status on the repaired candidate. No injected callback or manual refresh substitutes for these observations.

**Not established:** missing-root native event delivery, native exercise of the availability-loss latch, automatic full-root reattachment, folder retention on this initially empty profile, precise latency, successful launch of these metadata-only apps, physical paging/IME/VoiceOver/120Hz, or full migration acceptance. Earlier 40-app/group manual recovery evidence remains attributed to its earlier candidate. A transient app reference may remain latent in this isolated layout by design; no canonical layout deletion/overwrite was used to fake restoration.

Wallpaper remains loading/black, **NOT_FIXED**. Its proposed temporary OS-wallpaper A/B/A still requires the separate pending approval. No wallpaper/privacy/security setting, signing, installation, formal app data, personal app, reference resources, or unrelated process was modified.

Independent Arendt review: bounded evidence-quality PASS at its recorded pre-cleanup snapshot; 0 tests/builds/Swift/process/native actions. See `Workflow/results/SOURCE_NATIVE_EVENT_EVIDENCE_REVIEW.md`. Later final status/normal Quit/exact absence are Main observations, not independently reviewed. Reviewer closed.
