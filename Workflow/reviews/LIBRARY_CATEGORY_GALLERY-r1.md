# Library Category Gallery — Independent Bounded Review r1

Date: 2026-10-19

Verdict: **SOURCE_ACCEPT — no blocking production finding.** One nonblocking P3 test-isolation finding below. This is not native acceptance, full-suite certification, packaging approval, or proof that the reported blue artifact has disappeared.

## Scope and evidence boundary

Reviewed `Docs/LIBRARY_CATEGORY_GALLERY_SPEC.md`, the current gallery, rendering coordinator and owner controller, the gallery and responder-isolation tests, and the adjusted `LeadingLibraryPreviewTests` fixture. Read relevant existing view, owner integration, preview, navigation, window-gate and route-ownership tests and the production projection, icon-pipeline and parent-navigation call paths.

Source reads only. No SwiftPM/build/test execution, UI operation, app launch, process inspection/control, formal data access, or LaunchBetter/Buho reference access. Only this report was written. The review used the latest overview-header geometry and gallery binding/accessibility changes rather than the earlier versions seen during initial inspection.

Main reports final focused-r6: **63 tests, 0 failures, 0 warnings**, including the 13 responder-isolation cases and the autorelease-pool deallocation case. This is explicitly supplied evidence, not a reviewer-run result. Main's earlier full-suite run was superseded by fixture repair; the final full suite and package were still forthcoming when this report was prepared.

## Finding — P3: explicitly retain the old card in the same-generation regression

- Location: `Tests/PagingUITests/LibraryCategoryGalleryTests.swift:144-147`.
- Evidence: the test retains only the old icon button. Its activation closure weakly captures the containing card (`Sources/PagingPrototypeApp/AppLibraryGalleryView.swift:197-200`). Rebinding removes that card and replaces the `cards` array (`:83-85`); no deliberate strong old-card lifetime spans the attempted activation.
- Reproduction / missing discriminator: let the old card deallocate before `old.performClick(nil)`. The weak-card guard returns before reaching the gallery's binding check, so `opens == 0` still holds even without binding-revision rejection. AppKit autorelease timing can instead keep the card alive temporarily; the test should not depend on that timing.
- Likely root cause: the fixture proves that an obsolete button cannot act after its container is gone, but does not deterministically isolate the new same-generation binding rule.
- Recommended bounded solution: retain `oldCard`, obtain the button from it, and wrap the old-button click/assertion in `withExtendedLifetime(oldCard)`. Keep the fresh-button success assertion. Optionally exercise the old category/details callbacks under the same deliberately retained lifetime.
- Affected scope: regression reliability only. The current production `bindingRevision` increment and checks (`AppLibraryGalleryView.swift:80-100`) correctly reject callbacks from replaced bindings.
- Regression risks: none from the suggested test-only adjustment; avoid introducing a production retention change to make the test pass.
- Confidence: high for the coverage gap; no production stale-action defect established.

## Source conclusions

- Gallery grouping comes from the supplied filtered snapshot, includes populated categories in taxonomy order, and keeps layout separate from the canonical paging model. Geometry clamps sparse-category columns and bounds card widths. The overview-only centered search and hidden details toggle leave the queried-browser header branch intact (`AppLibraryView.swift:333-350`).
- Direct launch/detail admission looks up the current snapshot and constructs immutable requests (`AppLibraryView.swift:584-600`); owner resolution checks active committed ownership, readiness, action generation, catalog revision, URL, visibility and current projected membership (`AppLibraryOwnerController.swift:381-389`). Replacement bindings have an independent revision, including same-projection-generation relabels. No concrete stale-generation execution path was found in this scope.
- Card/button/observer/pipeline callbacks use weak owner captures; no concrete closure ownership cycle was found. The final deallocation test drains the AppKit autorelease pool while retaining its nil assertions (`LibraryCategoryGalleryTests.swift:151-162`); Main reports it passes. That distinguishes the supplied deferred-release failure from a demonstrated closure cycle.
- Icon work is asynchronous, viewport-gated and bounded to seven displayed app buttons per populated category. Requests are canceled on replacement, hide/removal and visibility loss, with serial/key/generation checks on delivery. Reduced Transparency and Increased Contrast select a solid material fallback. Source inspection does not substitute for visible-window request/delivery or performance measurements.
- The miniatures use a category label and one accessible/focusable representative rather than presenting every miniature as a separate app-launch target (`AppLibraryGalleryView.swift:188-200`). Real VoiceOver order, keyboard focus-ring visibility and native material appearance remain visual/accessibility verification items.
- Close revokes session/actions, resigns a Library-owned responder while mounted, resets, checks ownership again, then detaches (`AppLibraryOwnerController.swift:253-299`). The repeated ownership check covers reset-time focus reacquisition and avoids deliberately ending another control's reused window field editor. Existing tests cover owned controls/editors, nonowned marked editors, rejected transitions, preview cancellation and resignation-time focus transfer. No additional concrete responder reentrancy defect was found in the production callback paths inspected.
- The gallery uses native `NSScrollView`; parent horizontal navigation is decided in the window pre-dispatch hook, before native target delivery. The router retains a stream's native/parent ownership, and native vertical events continue to AppKit (`LeadingLibraryNavigator.swift:95-125`; `AppDelegate.swift:2686-2699`). The Library root still absorbs edge bubbling. No changed gallery code intercepts or synthesizes the parent swipe stream.

## Preview fixture adjustment

Accepted at source level. `LeadingLibraryPreviewTests.swift:93,108-121` installs the readiness counter before attach and waits for at least two receipts before opening a preview. The current fixture has no activity coordinator or other pre-open readiness producer: preference load emits its change once (`AppLibraryPreferencesCoordinator.swift:28-43`), and the attach task performs its final `preferencesChanged()` after awaiting that load (`AppLibraryOwnerController.swift:84-91`). Both notify through the existing readiness callback. This closes the fixture's scheduling race without changing production startup or weakening the gated projection's exact single-request assertion (`LeadingLibraryPreviewTests.swift:296-319`). The bounded wait asserts on timeout; elapsed time is not treated as successful readiness.

## Focus-ring and native acceptance limits

The source now supports a close-time ownership/order claim. It does **not** establish a pixel root cause or prove that the blue search remnant is gone. `LeadingLibraryNavigator.beginTransition()` (`:148-156`) does not resign an already committed Library search responder; production rendering moves the parent layer (`AppDelegate.swift:2640-2652`). The close-time cleanup occurs later, on committed return. Retaining focus during the moving phase is a separate observable state, not by itself a demonstrated AppKit rendering bug.

Native verification should distinguish: a focused search during tracking/settling, a canceled swipe returning to Library, and a completed return after cleanup. Verify absence of the reported remnant after completion, preserved native vertical scrolling and momentum, category/overflow/direct-launch/detail/back/Escape behavior, keyboard focus and VoiceOver, and solid material fallback. Do not globally disable focus indication or discard marked text to start a transition; current production transition readiness rejects marked-text admission (`AppDelegate.swift:2719-2723`). Any native result must identify the newly packaged candidate; the already-running older candidate cannot validate these sources.

## Reviewed input fingerprints (SHA-256)

```text
b0fc6e1f81486b44c732d7f15862ae7eb25b2daab1387f3cefa0affabde77c61  Docs/LIBRARY_CATEGORY_GALLERY_SPEC.md
f7ec9638d3c363583727f70d6fdc6faf350e38cf76923a70c00b97d4d15029dd  Sources/PagingPrototypeApp/AppLibraryGalleryView.swift
fe4783ab3c3f323242aec966f0a8941234d2dd137ab425606c45ee9d092eaf3d  Sources/PagingPrototypeApp/AppLibraryView.swift
b1b9983f04f34e0c7a778f13fcd3a717eb15e763515589c7313a7f9682d7d6a7  Sources/PagingPrototypeApp/AppLibraryOwnerController.swift
52f16fd4b2bfac92d4ffd2b1349636eadfd8c48cc9c05483fd0669624f5ae1b6  Tests/PagingUITests/LibraryCategoryGalleryTests.swift
a3b0aeeda8352a2146f98f6f12c0495fb139e4fb35ed6955b9bb16e5e9bd288e  Tests/PagingUITests/LibraryResponderIsolationTests.swift
f3b5d346991c8babe652434a26085a80486d164adbdba5d930c6659f7981a051  Tests/PagingUITests/LeadingLibraryPreviewTests.swift
```

No implementation changes or architecture expansion are authorized by this report. Main retains integration, final verification and native acceptance ownership.

## 2026-10-19 addendum — P3 test repair accepted

Bounded source re-review confirms that `LibraryCategoryGalleryTests.swift:144-151` now retains `oldCard` and encloses the obsolete button activation and `opens == 0` assertion in `withExtendedLifetime(oldCard)`. The fresh-button activation and `opens == 1` assertion remain at `:152-153`. The old card's weak callback can therefore reach the binding-revision guard throughout the negative assertion; deallocation timing no longer supplies an alternative reason for rejection. **P3 is resolved at source level. SOURCE_ACCEPT stands with no open findings in this bounded review.**

The three production source fingerprints were recomputed and exactly match the original review. The updated test fingerprint supersedes only its earlier fingerprint above:

```text
49c62782e1565a321b6c48f2d46c61171d1a5953995259e147e770eef8876503  Tests/PagingUITests/LibraryCategoryGalleryTests.swift
```

No tests/builds or native checks were run by this reviewer. Main will refreeze and rerun final verification for the updated test input. The earlier focused-r6 receipt belongs to the preceding test fingerprint, and the prior full-r2 result is preliminary; neither is represented here as final execution evidence for this update. Packaging and native focus-ring/transition acceptance remain Main-owned outstanding gates. This addendum changes only this review report and preserves its historical findings and evidence.

## 2026-10-19 addendum — native-r1 AX follow-up, r2 source acceptance

Main reports that native r1 rendered the gallery correctly, but its exported accessibility hierarchy did not match the intended miniature semantics: forcing `setAccessibilityElement` produced an unknown first representative and failed to suppress the other decorative buttons. Main also reports debug-address-like identifiers from interpolating `AppID`. These are supplied native observations, not reviewer observations. They supersede any reading of the initial source conclusions as proof that r1 actually exposed only one native AX target; the initial review established intent and explicitly left native AX behavior unverified.

Reviewed the narrow current repair and its assertions, without SwiftPM, UI or process access:

- `AppLibraryGalleryView.swift:186-196`: each freshly constructed icon receives `library.card.<category raw value>.app.<slot>` before it enters the hierarchy. The miniature representative at index 3 explicitly has AX hidden set to false; indices 4 through 6 have it set to true. The icon buttons no longer force their AX element status, so the representative retains the native button semantics. The existing category label, category activation and `refusesFirstResponder` policy remain intact. Decorative miniatures remain visually present and retain their intended pointer behavior; AX suppression does not use visual hiding or disable actions globally.
- `AppLibraryGalleryView.swift:280-281`: the standalone button default identifier is the constant `library.app`, then the card assigns a category/slot identifier to every instantiated gallery icon. Neither path interpolates `AppID`. These identify presentation slots, not durable application identity; launch/detail validation still uses the captured record ID and current owner admission, not an AX identifier. No remaining source/test/script consumer of the former app-ID-derived identifier was found in the bounded search.
- `LibraryCategoryGalleryTests.swift:57-59`: assertions cover exactly three hidden buttons, the representative's category/slot identifier, and its enabled state. Existing miniature activation, same-generation binding rejection with retained `oldCard`, and deallocation assertions remain present. Getter assertions verify configured properties, not the exported native AX tree or VoiceOver behavior.

**SOURCE_ACCEPT for this bounded r2 repair; no new actionable finding.** No owner, paging, icon-loading, action-generation or geometry behavior was changed by the reviewed AX/identifier edit. The coordinator and owner fingerprints still match the original review; only the gallery source and gallery test fingerprints below supersede their earlier values:

```text
94476fa64fcb7101e02df3f1251ca6e9ac11e6aeca599e99bbe32c87b0ee8e54  Sources/PagingPrototypeApp/AppLibraryGalleryView.swift
102aa2af6da9d782c70eaa4fa3c9089ea07dad6326b7c39c86fba3a83701cd71  Tests/PagingUITests/LibraryCategoryGalleryTests.swift
```

Main reports the preceding final full suite as 3236 tests / 0 failures and preceding build/package verification complete. Those results and native-r1 appearance evidence belong to the earlier candidate and do not certify these new fingerprints. Main owns the r2 refreeze, retest, package and native AX reinspection: confirm the representative has native button role/category label, the three decorative miniatures are absent from the exported hierarchy, identifiers contain no debug address, and keyboard/pointer category entry remains usable. Native focus-ring and physical swipe acceptance retain the earlier evidence boundary. Only this review report was modified by the reviewer.
