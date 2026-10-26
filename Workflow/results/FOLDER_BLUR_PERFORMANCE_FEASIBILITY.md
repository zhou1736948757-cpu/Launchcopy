# Folder Exterior Blur: Performance-First Architecture Advice

Date: 2026-10-16
Status: DISCOVERY_ONLY; NOT_IMPLEMENTED; NOT_BENCHMARKED

## Authority and scope
User selected panel + exterior blur, then explicitly prioritized performance and authorized omitting exterior blur. No folder-induced dimming. Existing layout, physics, input ownership and canonical data stay unchanged. Read-only sidecar Aristotle completed and closed; concurrency2 including Main. No source edits, UI actions, tests, builds or new candidate this stage.

## Concrete findings
The launcher background is a composition of sibling wallpaper, surface and chrome views in AppDelegate. Capturing only PagingSurface misses wallpaper/chrome. The folder overlay itself has entrance/exit opacity and transforms; an exterior image must be a fixed root sibling beneath it, not a child that would zoom the entire background. Existing exit visuals retain the real view for interrupted presentation fidelity and must not be replaced by a snapshot. Existing wallpaper has baseline tint independent of folder opening.

## Recommendation and limits
Trial a single directly downsampled own-content snapshot at a stable opening boundary, not in repeated refreshFolderOverlay. A longest edge around1024px is a candidate bound, not a measured optimum; one RGBA8 image has at most about4MiB but capture/output/intermediates/upload need additional memory. AppKit capture remains main-thread; immutable pixel filtering may run off-thread with a reused context. Cache only for that valid opening session, fixed sibling and no input/AX. Independent generation + viewport/content/appearance/wallpaper invalidation must reject stale work. Skip unstable paging, retained exit, transient notification or drag states rather than remounting views for capture. Remove exterior blur on resize/screen change/hide/teardown/move-out and do not continuously recapture. No display/other-window capture or disk image/log payloads.

Compare engineering and actual rendering cost with a retained native within-window material, but do not assume either wins. Native material includes system tint and is not a pure configurable blur; do not silently restore an exterior brightness pulse. Prefer one shared blurred representation if it avoids unnecessary stacked passes, subject to stable panel/editor host and legibility. Material design remains to be finalized against the approved conditional outcome.

Main-thread capture, layer correctness, upload, animation interaction and cold open are unknown costs. Smaller pixel output does not prove a cheaper view traversal. Do not block opening for a blur result or show a late abrupt switch. If faithful/coherent output and matched native performance cannot be established, deliver panel glass only and defer exterior blur, as already authorized. No automatic fallback to full-screen live blur.

## Next executable action
Bounded material prototype and matched native performance/visual evidence after settling any material architecture change in the spec. No performance claim or physical gesture acceptance follows from this discovery. Current unsigned clear-backdrop candidate bb1cabc3 remains unchanged; prior2791/0 is not glass verification.

References: Docs/FOLDER_FROSTED_MATERIAL_SPEC.md; Sources/PagingPrototypeApp/AppDelegate.swift (root composition, openFolder and retained exit); Sources/AppGridUI/FolderOverlayView.swift (stable panel/editor, move-out); Sources/PagingPrototypeApp/WallpaperBackdropProvider.swift (current thumbnail filtering); Apple Core Image Programming Guide performance chapter (reduced outputs/context reuse).
