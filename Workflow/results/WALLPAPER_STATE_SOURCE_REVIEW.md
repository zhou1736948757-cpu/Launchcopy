# Wallpaper State — Independent Bounded Source Review

Date: 2026-10-15

## Verdict

**PASS — bounded SOURCE review only.** No concrete supported privacy leak, stale-state regression, thread-confinement violation, or behavior regression attributable to the scoped diagnostic additions was found. This is not a test, build, native-window, wallpaper-compositing, or full-parity acceptance verdict.

## Authority and scope

Read project `AGENTS.md` and `Workflow/stage-summaries/2026-10-15-wallpaper-state-diagnosis.md`. Followed the user's explicit authorization for this independent reviewer and waiver of formal Chief workflow; created no agents or goals. Reviewed the native macOS AppKit/Swift controller and application-owner wiring using their existing MainActor and dependency-injection conventions.

The reviewed additions are the internal `LoadState`/`publish` mechanism and its attach/refresh/completion calls in `WallpaperBackdropView.swift`, `installIsolatedWallpaperDiagnostics` and its startup call in `AppDelegate.swift`, and the complete new `WallpaperLoadStateTests.swift`. The large pre-existing dirty tree is baseline, not review scope. The current Git HEAD diff includes older loader, source, appearance, profile, and rendering changes; those differences do not establish changes made in this diagnostic stage. In particular, this verdict does not independently certify the entire dirty tree against HEAD or an unavailable frozen pre-stage snapshot.

Only this report was written. No implementation edits, Swift commands, tests, builds, app launches, process control, reference-product reads, or raw-reference reads were performed. All shell commands were RTK-prefixed.

## Source findings and evidence

### Default observer and discrete publication — PASS

`WallpaperBackdropView.swift:27-42` defines six fixed, payload-free raw-string states. `loadState` starts at `.idle`; the optional `onLoadStateChange` has no initializer and therefore defaults to nil. `publish` updates the stored value before notification and suppresses duplicate states. The mechanism remains internal rather than adding a public diagnostic API.

Publication is confined to existing controller boundaries: attach (`:110`), disabled policy (`:139`), missing source (`:158`), pending loader (`:164`), and accepted success/failure completion (`:174`, `:177`). There is no polling, timer, per-frame publication, or extra rendering request in `publish`.

### Source, policy, and render behavior — PASS within the scoped additions

The observed branches use the existing policy predicate, resolver, request, loader, and image-assignment path (`WallpaperBackdropView.swift:124-180`). Policy-disabled returns before source resolution or rendering. Missing-source returns before the loader. Success reports `.ready` only after image installation and the existing dim-layer update; failure reports `.renderFailed` without introducing another source or decode attempt. The diagnostic observer does not choose a source, adjust blur, alter material policy, write image data, or schedule work.

Attach invalidates prior-host work, clears the prior image, and resets state (`:92-110`); this is host-generation safety, not a new source/policy/render strategy. Broad HEAD differences such as prior raw-image handling and loader injection remain outside this stage's asserted diagnostic delta.

### Resolved-profile-only AX wiring and privacy — PASS

`AppDelegate.swift:2815-2822` checks the resolved `uiTestProfile`, not merely the command-line profile option. `uiTestProfile` has a restricted setter (`:23`) and is assigned after successful profile resolution/rechecking (`:353-370`). Startup configures that profile first; a thrown configuration error terminates the startup path before window/backdrop wiring (`:375-382`).

The sole product observer assignment is this installer. Its closure weakly captures the supplied window and performs only `setAccessibilityHelp("Wallpaper diagnostic: " + state.rawValue)` (`:2818-2821`). It neither retains the owner/window strongly nor includes paths, app identifiers, image content, associated errors, or source metadata. Initial help is populated from current state, so duplicate suppression does not omit the initial `.idle` token.

Startup installs the observer between the initial attach and the subsequent refresh (`:571-582`). A nil/unresolved profile returns without altering the observer or window help. Production constructs a fresh controller with the default nil observer. The installer adds no filesystem write, timer, diagnostic frame work, cache work, or preferences mutation; existing profile setup/provider work is baseline rather than an observer side effect.

### Stale callback and host-generation safety — PASS

Every refresh advances `generation` before any policy/source early return (`WallpaperBackdropView.swift:126-127`), so an older completion cannot restore either an image or a ready/failed state after disabling policy or losing the source. Every attach also advances generation (`:93`), including host replacement. Completion uses a weak controller and checks both the captured generation and a live host before image mutation or state publication (`:165-178`). An obsolete success and obsolete failure therefore both return silently. Controller disposal makes pending completions harmless through the weak capture.

### UI-thread confinement — PASS at source level

The controller is `@MainActor` (`WallpaperBackdropView.swift:24`); state storage, `publish`, attach, and refresh inherit this isolation. The loader and completion types are MainActor-bound (`:48-52`). The background loader runs the render function on the background queue and explicitly dispatches completion to the main queue (`:81-89`). AppKit image installation and state publication occur inside that completion. The installer is explicitly `@MainActor` (`AppDelegate.swift:2815`), and its only observer operation is the window AX-help mutation. No new dispatch to a background queue or independent invocation of the observer was found in the scoped wiring.

This is a source reasoning result; compiler validation and live thread/runtime evidence remain Main-owned.

### Callback reentrancy assumptions — not a supported blocker

`publish` invokes the observer synchronously. A hypothetical custom observer that reenters `refresh` or `attach` at `.loading` could change generation before the outer invocation subsequently starts its loader; the completion guard would still discard the outer obsolete result, but the extra loader invocation would be possible. The internal callback seam does not promise arbitrary mutating-observer reentrancy.

The actual product observer only weakly updates window AX help; it does not invoke controller lifecycle methods or change policy/source. The test observer only records states. No supported mutating callback or concrete reentrant production path was found. This assumption is recorded rather than elevated into an invented blocker.

## Test-source assessment

Six new MainActor test methods were inspected, not executed:

- `:16-32`: current completion moves loading to ready/failure, records notification order, and keeps a synthetic private-source name out of emitted tokens.
- `:35-46`: policy-disabled and missing-source differ; neither starts the loader, and disabled policy does not resolve a source.
- `:49-63`: stale success after policy disable and stale failure after newer success cannot replace current state.
- `:66-77`: host replacement resets to idle and rejects the prior host's completion.
- `:80-93`: production and requested-but-unresolved profiles leave the observer nil and existing window help unchanged.
- `:96-115`: a successfully configured isolated profile receives the exact neutral idle/disabled/missing-source AX tokens without making the test window visible.

The latest inspected tests include the `throws`/`XCTUnwrap` cleanup (`:10-13`, `:76`), rather than the earlier `try!` form. Temporary-directory writes in the profile test are fixture setup/cleanup, not product observer behavior.

**Nonblocking coverage limits:** stale-result assertions inspect state rather than image identity or notification count; repeated-state suppression, dropped-host lifetime, and weak-window disposal are established here by source reasoning rather than dedicated tests. The resolved-profile test checks only three AX tokens; ready/failure/loading are covered through the controller observer, not an end-to-end window-help test. These are useful future test refinements, not evidence of a current supported defect.

## Execution evidence boundary

Reviewer executed zero tests/builds/native checks. Main's initial focused **54 tests / 0 failures** was reported before the trivial `try!` to `throws` cleanup and is not reviewer execution or proof that these final hashes passed. Main's latest full run was in progress according to the dispatch; this report neither claims its outcome nor incorporates unprovided execution results. Main owns serial focused/full validation, Debug/Release builds, packaged-resource checks, and native AX-token/visual inspection.

A `.ready` source state means an image was assigned for the accepted generation; it is not proof of correct visible compositing. Physical/native and broader parity gates remain open.

## Findings summary

Blocking findings: **0**. Concrete supported leaks/regressions in scope: **0**. Advisory test-coverage limits and synchronous callback assumptions are described above. Confidence is high for the scoped source/wiring conclusions, with runtime acceptance explicitly unassessed.

## Reviewed input SHA-256

The three implementation/test hashes were captured after reads and rechecked immediately before report creation; they matched. Full-file hashes include pre-existing baseline content.

| Input | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/WallpaperBackdropView.swift` | `7c48bab327f37a36de486c7e74572bb50e4e0b0e55d986e0e1789cc645529a65` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `51849aa9833610c7ce6c3655c00870f78d13328f5052a89ae9d5ecdc60ab23e4` |
| `Tests/PagingUITests/WallpaperLoadStateTests.swift` | `08d08f3ae15d93e70f3f05851c7e93550dae69005aa768e024c19d612fb83737` |
| `AGENTS.md` (read-time context) | `6928c4ebd8edcabc637e028d24790450a052b739117f0b0ef9f6ad6b45b7bcfc` |
| `Workflow/stage-summaries/2026-10-15-wallpaper-state-diagnosis.md` (read-time context) | `92ef7f4464997ef0bd4f3db6ac4545f1eaef870c048bf6af4b3fd83bfe4e50ea` |

If the source/test hashes change, this verdict applies to the recorded snapshot only and needs a bounded delta review.
