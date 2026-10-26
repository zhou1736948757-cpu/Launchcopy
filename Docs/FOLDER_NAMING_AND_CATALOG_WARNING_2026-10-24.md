# Meaningful new-folder titles and truthful catalog warnings

## Problem and approved outcome
The user asks that app-on-app grouping create a folder with a meaningful name instead of `Group N`, and asks what the bottom-right partial-load warning means. Prioritize this feedback over the unimplemented reentrant-release audit; do not imply that audit has been repaired or caused the intermittent physical drag failures.

## Discovery
`LayoutMutation.defaultFolderTitle` currently generates `Group N`. Actual drag creation supplies no explicit title. Existing folders already support user rename, normalization and persistence. Catalog metadata and the Library taxonomy are available locally, without scanning or network work in a drop callback.

The catalog warning comes from scan outcomes, not the launch result or icon loader. `CatalogScanner` counts unreadable directories, invalid/corrupt bundles, cycles and missing bundle identifiers. A missing identifier still admits the app with a canonical-path identity; counting that alone as a partial loading failure is misleading. The current adapter merges all categories into one total.

## Naming requirements
- Only newly created app-on-app folders receive a suggested title; never silently rename existing `Group` folders or any user title.
- If both apps share a known category, use its displayed localized category name. Respect already committed manual category overrides even if the optional Library view is disabled.
- Otherwise use the two current display names (including committed aliases) with a localized joiner; use a localized `Apps` fallback if usable names are unavailable. No online inference, hard-coded app-brand list or new usage collection.
- Normalize to the existing 64-grapheme folder-title limit, keep Unicode/emoji intact, balance long two-name suggestions so neither app disappears, make the generated title unique with a deterministic smallest unused numeric suffix, and reserve suffix space before truncation.
- Existing rename UX remains available. Do not auto-open an editor, migrate old titles, change folder IDs/member order, or add a second mutation/persistence pass.
- Resolve the actual release target after existing token/layout/catalog validation. Compute a title only for an accepted new-folder operation; stale/cancelled/reorder/move-into-folder operations must not invoke naming.

## Catalog warning requirements
- Preserve the full anonymous issue count. Distinguish non-blocking missing-identifier warnings from discovery failures without making AppGridUI import MacAppCatalog.
- A successful scan with only missing identifiers is ready (or empty when genuinely empty), not a partial failure. Inaccessible sources and invalid/corrupt bundles remain visible as discovery problems, including a zero-record failed discovery.
- Keep cancellation, stale refresh/configuration protection and latest-wins behavior. No scan-policy expansion, permission changes, silent root removal or hiding genuine failures.
- Replace the misleading wording with text that describes unreadable sources or app items, not an assertion that every displayed app failed to load. Keep English, Simplified Chinese and Japanese resources consistent.
- Explain source-confirmed meaning separately from the exact live failure categories; do not claim the current warning has only a harmless cause without a captured categorized result.

## Architecture and ownership
Main owns drag/controller/mutation integration, AppDelegate naming composition, all localization changes, native UI and verification/package delivery. A policy worker owns only a new pure naming policy and its tests. A catalog worker owns only refresh-outcome severity/adaptation and focused catalog tests. Shared tree, disjoint write sets, no concurrent builds or desktop use; at most three active agents including Main. No legacy workflow/watchdog.

## Acceptance and delivery
Demonstrate the previous generic creation through production drag routing, then category/mixed/unknown/alias/Unicode/duplicate/long-name behavior, exact target-then-source member order and one generation increment. Test actual release-target changes, cancellation/staleness, persistence reload, language changes and existing-title preservation. Catalog tests cover soft-only, hard-only, mixed, zero-app, failed/cancelled and later healthy refreshes plus the adapter's category mapping.

Run nonzero focused/full tests, Debug/Release, strict isolated packaging, localization verification and independent bounded source review. Preserve the current human-updated integrated profile; no agent real-app grouping/launch/removal. Native presentation and human physical grouping remain distinct gates. No signing, install, commit, forced exit, reference-source or raw-evidence reads. Keep plans, stage summary, result and delivery index current.

## Behavioral reference boundary
Apple's public [iPhone folder guide](https://support.apple.com/guide/iphone/organize-your-apps-in-folders-iph822ece7dd/ios) documents app-on-app creation and user rename. It does not specify the current internal naming algorithm. The category/pair/collision policy above is independently defined for Launchcopy, not a claim to reproduce Apple's private implementation. No reference source or assets were read or copied.

## 2026-10-26 supersession — concise category names, never concatenated app names

### Product correction and scope
The user reports that the newly generated name is awkward despite confirming that a first grouping succeeded and no longer uses Group. That earlier acceptance proves the bounded operation/non-Group property, not approval of the naming aesthetic. This dated correction supersedes the two-name/joiner/alias fallback and balanced-pair requirements above, and their matching acceptance expectations; other contracts remain in force. Do not infer the exact current user-folder name from the feedback or log it.

### New naming decision
Use only committed category snapshots and the existing displayed language. Prefer the target (stationary app receiving the drop)'s recognized category; if unavailable, unknown, or without a usable localized label, use the source app's recognized category; otherwise use the existing localized neutral Apps / 应用 / アプリ title. Shared categories naturally yield the same name. The target-first choice is an explicit independent product rule for mixed categories, not a claim about Apple's private algorithm. Respect committed manual categories even when Library is disabled. Never concatenate app names/aliases or guess semantic meaning from brands, histories, filesystem scans, or online inference. Do not claim that category metadata is always accurate.

Keep existing Unicode/control normalization, the64-grapheme bound, deterministic smallest unused numeric suffix, actual release-target resolution, one validated atomic mutation and persistence. Existing titles (including the folder just created by the user) remain literal saved content, unaffected by language/category updates; no migration/editor auto-open. Avoid unneeded dependencies, tasks, IO or frame work. Remove the now-unused name/joiner inputs and balanced-pair machinery from the pure policy and its sole composition; retain the existing localization joiner resource as an unused compatibility key in this bounded change rather than changing package schema/inventories.

### Acceptance and evidence
Pure tests cover target-first mixed categories, source-only known category, unknown/nil inputs, missing/unsafe labels, Unicode literal/control normalization,64-grapheme suffix-aware collision handling, category/fallback uniqueness and input immutability. Composition tests cover three languages, committed manual overrides with Library OFF, aliases not affecting generated names, existing-title preservation and real persistence reload. Actual-window drop tests must remain one commit/generation and target-then-source members, use the validated actual target and preserve earlier stale/cancel/reorder guards. Demonstrate a focused regression against the old rule before product edits. Then run focused/full nonzero suites, Debug/actualRelease, strict isolated package/resource checks and bounded independent source review. Never treat these as human aesthetic or broad intermittent-drag acceptance.

Deliver a unique unsigned candidate; preserve the latest isolated profile. Main owns policy/composition, tests/build/package/native and shared docs. One disjoint worker may update only composition/actual-owner test files without running builds. A later read-only reviewer audits frozen source; at most three agents including Main, no legacy Chief/watchdog. No reference source/assets, real-app organization/launch/removal, signing/install/publish/Git mutation, forced exit or production data changes. Record any native/unlock limitation honestly; no repeated acceptance question for the already closed first-trial operation.
