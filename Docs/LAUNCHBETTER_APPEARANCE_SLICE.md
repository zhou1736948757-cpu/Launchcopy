# Appearance Parity Slice 1 — Labels and Wallpaper Blur

Date: 2026-10-13
Authority: approved staged scope in `LAUNCHBETTER_PARITY_SPEC.md`

## Observable requirements and scope

The reference product exposes app-label visibility and wallpaper blur intensity
(0–60). Independently implement those controls in Launchcopy. Preserve the existing
default: labels visible, blur radius 18; preserve 48pt icon geometry, icon-plus-4pt
launch hits, 5×7 capacity, paging physics and existing activation settings.

Use one settings window with Appearance and Activation sections. Appearance has
its own draft, Apply and Restore Defaults actions; closing without Apply discards
its draft. Saving appearance must not save/reset activation or layout. Opening the
settings view must not apply changes or rescan apps. No reference code/assets are
implementation inputs; controls and persistence are authored independently.

## Architecture and behavior

- Foundation value-type AppearancePreferences: show labels and integer blur radius,
  explicit supported range and versioned standalone UserDefaults namespace.
- Read only at startup/settings lifecycle. Persist only on explicit Apply; preserve
  unknown future versions and reject their overwrite. Corrupt load falls back to
  defaults without writing until the user's explicit Apply.
- Application coordinator owns committed preferences; persist successfully before
  applying UI. Apply/revert status is visible and accessible; settings labels follow
  the project's existing Chinese convention.
- Label visibility updates existing grid/folder/pool/proxy cells directly, including
  newly bound and reused cells. Keep accessible names and folder title editor.
  No catalog commit, icon reload, generation bump, geometry change or disk work.
- Wallpaper settings reuse the nonblocking loader and generation gate. Blur zero
  means no blur, not no wallpaper. Reduce Transparency overrides the wallpaper;
  a late result cannot undo a newer policy/radius. Re-render once per committed blur
  change, never once per slider tick/frame. Keep rendering cached and off-main.
- Do not create another settings-window owner or change current singleton/hide
  behavior. Appearance changes do not change current keyboard/folder/search mode.

## Performance and acceptance

Structural budget: label-only Apply issues zero icon loads/scans/wallpaper requests;
no appearance work in advanceFrame. One blur request only when committed radius
changes; equal-value Apply is a no-op. Synthetic tests prove these invariants,
not physical smoothness. Capture matched-device frame data when practical before
claiming measured regression-free performance.

Verify defaults/invalid/future/corrupt round-trip, independent namespace, save-before-
apply and failed-save behavior; live/new/pooled/folder/proxy label state and retained
accessibility; radius forwarding, stale result rejection, accessibility override;
real control-to-draft-to-save wiring. Run focused and full suites with executed
counts, debug/release builds, independent review, unique candidate hash and live
GUI Apply/reopen checks. No signing/install/publish/commit or unrelated settings.

## Ownership and maintenance

Main owns preference domain/store/coordinator, new AppearanceSettingsView,
existing settings-window embedding, AppDelegate integration, wallpaper radius,
docs and final verification. Worker owns AppGridCellView/AppGridPageView/
FolderOverlayView, AppCatalogAssembly's renderer label-property plumbing and
associated tests. Disjoint writes, serialized SwiftPM, at most 3 agents including
Main. Reviewer is read-only after a stable implementation.

This is the first appearance slice, not full LaunchBetter UI/function parity.
Icon sizing/layout controls, page dots, app management and Library remain on the
approved roadmap and must not be forgotten or declared complete by this slice.
