# Accessibility Material Consumer Repair

Date: 2026-10-13
Authority: approved parity specification §§4–6 and accepted Phase1I material
semantics. This is a bounded existing-contract bug fix, not a new capacity,
page-navigation, preference or independent visual redesign decision.

## Observed gaps

chromeFill returns alpha0.55 even when prefersOpaqueChrome is true. The actual
launcher settings button applies the policy only on creation; the accessibility
notification handler updates wallpaper/folder but not that chrome. Contrast has
a semantic token but no border consumer there. Folder panel border/footer and
restored move-out backdrop always use normal material values.

## Repair

Keep normal colors/layout/fonts, default5×7, paging physics and user settings
unchanged. Reduce Transparency: real settings chrome and folder surfaces become
opaque, wallpaper continues to skip blur as before. Increase Contrast: visible
panel/settings boundaries and footer text strengthen without changing hit boxes,
cell binding, icon loads, title editing, focus or navigation. Flags independent of
Reduce Motion. Map semantic flags at the app owner; no app-target dependency in
AppGridUI. Update only layers/text, not grid content, on a material update.

Folder visual-only exits remain immutable/inert; collapsed move-out presentation
keeps its clear background, and restore uses the current material instead of the
old hardcoded alpha. No new callbacks/timers/IO/telemetry/settings schema. Live
system settings are not changed by tests. No global monitor or private API.

## Ownership / validation

Main: LaunchcopyVisualTokens, AppDelegate real notification/chrome/folder mapping
and application tests. Worker: FolderOverlayView narrow material consumer + new
material tests only. Neither modifies another's files; at most3 including Main.
Independent Reviewer follows stable source; Main alone runs Swift/builds.

Token opacity/contrast matrix, actual detached button creation and injected policy
refresh, folder layers/footer/clear-restore/visual-only/teardown regression. Changes
must preserve cell instances/bindings/request counts and folder edit callbacks.
Nonzero full suite, Debug/Release, unique preserved candidate and source manifest.
Exact GUI/pixels and matched physical AB remain separate; existing isolated R2
runner/manual launch boundary is unchanged. Not full visual parity completion.

Performance budget: per material event O(1) chrome/layer updates and zero added
scan/save/icon-load/page-rebind/frame work. Existing accessibility cancellation/
folder refresh behavior is not broadened. No physical no-regression claim without
matched unlocked-device capture. Baseline current1917/0 and R2 hashes are recorded
in the isolated-ui-profile stage summary. Prior goal turn classified PROGRESS.
