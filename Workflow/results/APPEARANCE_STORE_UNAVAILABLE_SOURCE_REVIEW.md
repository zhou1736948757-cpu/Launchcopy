# Appearance store unavailable — independent bounded SOURCE review

Date: 2026-10-15. Verdict: **PASS (bounded SOURCE review)**. No actionable P0–P3 findings in the reviewed two-input delta. No implementation fix is requested. This verdict does not close the overall goal, certify a package, or establish physical/native acceptance.

## Authority and execution boundary

Read `/Users/mac/.codex/RTK.md`, project `AGENTS.md`, `Docs/APPEARANCE_STORE_UNAVAILABLE_REPAIR.md`, and `Workflow/stage-summaries/2026-10-15-appearance-store-unavailable.md`. Followed the explicit report-only assignment and existing shared-worktree preservation constraint. No agents were dispatched. The sole file written by this reviewer is this report; implementation, tests, manifests, resources, and other agents' work were preserved.

Reviewer executions: **0 tests, 0 Swift/compiler commands, 0 builds, 0 package commands, 0 native/UI operations, 0 application/process-control actions**. Read-only shell/Python inspection was used for source, saved logs, SHA-256 verification, and in-memory diff comparison. Test/build results below belong to Main's retained evidence, not independent reviewer execution.

## Exact input identity and scope

Evidence directory: `.build/verification/20261015/appearance-store-unavailable/`.

- Baseline, invalid seam-compilation, successful RED, and final manifests each contain exactly **455 inputs**, with identical path sets.
- `baseline-inputs.json` exactly equals the prior `library-folder-choices/source-inputs-final.json`. That prior stage identifies candidate executable `252ec673581b1c3d0c54c1fee9ce1080a89691a0fd114e93ebe7c2096b57cba3`. This establishes source-manifest continuity; this reviewer did not independently inspect or execute that packaged binary.
- Independently hashed all 455 current files against `source-inputs-final.json`: **455 matches, 0 missing/mismatched**.
- Exactly **2 inputs changed; 453 unchanged**: `Sources/PagingPrototypeApp/AppDelegate.swift` and existing `Tests/PagingUITests/AppearanceDraftCloseIntegrationTests.swift`. This is one app source file plus one existing test file, not two app source changes.
- Saved original, successful RED, and invalid seam-compilation bodies match their respective manifest hashes. Both saved `*.swift.diff` files exactly match independently regenerated baseline-to-final unified diffs.
- `AppearancePreferences.swift` (including protocol, store, schema, coordinator, and presentation enum), `AppearanceSettingsView.swift`, localization/resources, package/scripts, cold-gesture and Library choices changes, Core, and paging inputs remain unchanged within this 455-input comparison. The broad pre-existing dirty tree is not attributed to this repair.

SHA-256 anchors:

| Artifact | SHA-256 |
| --- | --- |
| `baseline-inputs.json` | `0c06c767c6f0ef418811454ff01c9bfb90f36c21678ba158083ba55a69b7d083` |
| `red-inputs.json` | `014279c0a25570572758721235a122a85a4109ba93b2c3602adb313241aa8a55` |
| `source-inputs-final.json` | `1b0e05712f5b14afa0010430792c402d75edeee733b42ed2617ed04ed8b87548` |
| Final `AppDelegate.swift` | `acaf24393491048bad28455ce05afa157ac216caae1b5696c8a02ac5fad0e3f7` |
| Final integration test / saved RED test | `44b01928621febc37a4092fec46a5a360d19dd470fe799ed658dc585b4743ccd` |
| `red.log` | `88644b11a66e5093c76ece2742e9042ab8918cde0332db060b39e81349988ff8` |
| `focused.log` | `b213e8b9fe7d63cb746c8d28dd0d763dd93c12c6b0167a5662ddec006bcdbb4d` |
| Terminal `full.log` | `b033cddf76cb92868be15fa4523fde1202ff774c252551463608c460a433dbbf` |

## Source assessment

1. **Conditional persistence honesty.** `AppDelegate.swift:2124` retains explicit-store precedence, the same profile/default suite selection, and the healthy coordinator installation. Its synchronous internal factory parameter is nonescaping and explicitly `@MainActor`, matching the actor-isolated store initializer and installation method. The nil branch clears the coordinator and returns before changing displayed or pending accepted preferences. It cannot acknowledge edits through an automatically substituted in-memory store. Explicitly injected stores still bypass the factory and retain their existing semantics.

2. **Default boot and unavailable Apply.** Initial displayed values remain `AppearancePreferences.default` and pending values start nil (`AppDelegate.swift:100`). Factory failure therefore leaves the existing defaults intact on fresh startup. `configureAppearanceSettings` records the current view, uses pending accepted values before displayed values, sets a constant unavailable presentation provider, and clears `onApply`. The unchanged view's real `applyClicked` handler invokes its existing translated unavailable feedback before any coordinator/save/no-op shortcut can run. Both edited and equal/default drafts are rejected, remain editable, and cannot report Applied. No corrupt/future label, schema/resource change, global permission action, retry, or session-only mode is introduced. Fresh-start default behavior is established by source initialization and control flow; the new fixture tests exercise replacement of an explicitly installed default owner, not an actual failed OS startup.

3. **Accepted displayed/queued state.** The failure branch preserves both snapshots. Unavailable configuration and dismissal restore `pendingAppearancePreferences ?? appearancePreferences`, so an already persisted queued style is not replaced by older displayed defaults or an unaccepted draft. The unchanged readiness arbitration may still present that earlier accepted style later. This is consistent with persistence-before-presentation. The constant unavailable provider and view's accepted-status guard prevent that drain from turning the rejected draft's feedback into Applied. The new queued-state test uses the existing readiness restriction, actually saves first, and later drains through the real owner method.

4. **Dismissal, replacement, and lifetime.** The unavailable discard closure captures self and view weakly, checks final teardown, requires no current coordinator, and checks current configured-view identity before reloading only that view. Retained callbacks cannot reset a replacement view or a healthy replacement owner's draft. Existing healthy discard identity guards remain intact. Real controller hide/close wiring invokes the discard callback; appearance handling does not reload activation or alias controls. Tests cover both replacement branches and unrelated draft preservation. Weak capture/teardown safety is additionally a source assessment; the seven new tests are not presented as a dedicated deallocation/teardown test suite.

5. **Healthy paths and isolation.** Successful installation/configuration and persistence coordinator behavior are unchanged after factory extraction. Existing corrupt/future payload handling and healthy equal-Apply behavior remain in their original owner/view code. The profile/default suite expression is unchanged, is evaluated once only when no explicit store was supplied, and factory nil does not retry another suite. Existing production startup still resolves/rejects test-profile configuration before installing appearance preferences. New nil-factory tests instantiate the actual AppDelegate and controller with an injected fixture store, then invoke the real failure branch; they do not open production defaults or construct a fake unavailable view. The new tests do not directly assert the factory's suite string; suite selection is verified here by source continuity, with existing profile assembly evidence kept distinct.

## Causal RED validity and test integrity

The first saved attempt is **invalid as behavioral RED**: `seam-compile-failure.log` shows the default closure calling a MainActor initializer from a nonisolated function type; no tests executed. Its exact bodies and manifest remain retained. Independently compared that app body with successful RED: the sole correction is adding `@MainActor` to the factory function type.

The successful RED app differs from baseline only by extraction of the internal factory seam; the original `InMemoryAppearancePreferencesStore()` fallback is still present. `red.log` records a completed build and **2 actual XCTest cases, 5 assertion failures, 0 unexpected failures, 0.651 seconds**. Default/equal Apply incorrectly reports localized Applied and green; edited Apply does likewise and changes actual `app.appearancePreferences` to the edited style. These failures reach actual AppDelegate configuration, the real configured view's Apply handler, and real owner presentation state. They are not missing-symbol, compilation-only, or mocked-result failures.

Successful RED to final changes **only AppDelegate.swift**. The test file is byte-for-byte identical, including both causal tests and all seven added tests; six old test methods remain unchanged, yielding **13 actual-controller cases**. No assertions were weakened, tests removed/skipped, result hardcoding added, or alternate implementation substituted. The fixture store's empty-write assertion alone would not detect writes to the old fallback store; the genuine RED signal comes from the unavailable-feedback and actual displayed-preference assertions, which demonstrably failed before the repair.

## Main's observed verification evidence

Read terminal `focused.log`: **100 XCTest cases / 0 failures, 9.717 seconds**, across exactly these six executed suites:

| Suite | Tests |
| --- | ---: |
| `AppearanceDraftCloseIntegrationTests` | 13 |
| `AppearancePreferencesTests` | 23 |
| `IconTypographyOwnerTests` | 16 |
| `IconTypographyPreferencesTests` | 8 |
| `LanguageRuntimeIntegrationTests` | 23 |
| `LanguageSettingsConsumersTests` | 17 |

No separate nonexistent view-test suite is inferred from a filter. Read terminal `full.log`: **2700 XCTest cases / 0 failures, 53.538 seconds**, ending with `All tests` passed at 2026-10-15 23:13:56.054. The full log includes all 13 integration cases and the existing `UITestProfileAssemblyTests`. The trailing Swift Testing message reporting zero tests is a separate runner epilogue; it neither replaces nor adds to the nonzero XCTest counts.

Main additionally reported explicit Debug build terminal exit 0 in the follow-up handoff. This is attributed to Main; this reviewer did not run or independently inspect a separate Debug-build log. Release packaging is Main-owned and was reported running; this review does not depend on its completion or wait for GUI work.

## Findings and remaining gates

**No concrete P0–P3 finding; no minimal fix required for this delta.** Confidence is high for the bounded source/control-flow and retained causal-test assessment. Evidence consists of current-file hashes, exact body/diff comparisons, supporting owner/view/controller source, and Main's saved nonzero XCTest logs.

Factory nil is deterministic injection through a production construction seam. This report makes **no claim of real `UserDefaults(suiteName:)` nil, OS/device failure reproduction, native failure-path UI acceptance, physical input acceptance, package identity, or whole-product/full-goal completion**. Main may finish a new unique candidate and healthy Apply/restart checks; those establish healthy-path regression evidence only. Existing broader physical/parity/performance/wallpaper gates remain outside this review. No native fault-injection flag or OS permission manipulation is requested.
