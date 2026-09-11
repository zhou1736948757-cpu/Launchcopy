# Handoff: Launchcopy launcher background stays pure black (wallpaper not visible)

- **Date**: 2026-09-11
- **Product**: Launchcopy (`com.launchcopy.app`)
- **Repo**: `/Users/mac/Projects/Launch_Copy/PagingPrototype`
- **Goal**: Show **blurred desktop wallpaper** behind the app grid (LaunchBetter-like), with Reduce Transparency → opaque fallback.
- **Current symptom**: User still sees **absolute pure black** behind icons. Not “too dark blur” — looks like no wallpaper at all.

---

## 1. User-confirmed facts

- Desktop wallpaper is **clearly visible** when Launchcopy is quit.
- System **Reduce Transparency is OFF**.
- Screenshots show solid black behind icons (settings gear top-right, settings window may be open).
- User believes wallpaper image was never actually introduced into the visible hierarchy (not a dimming-only issue).

---

## 2. Evidence that rendering pipeline IS producing an image

### Runtime logs (packaged app stdout)

Repeatedly observed:

```text
paging-wallpaper: refresh begin size=1470x956 scale=2.0
paging-wallpaper: sync RAW desktop shown 图片生成限制.png size=2508x1672
paging-wallpaper: replaced with blur 1029x669
```

Desktop URL resolved via `NSWorkspace.shared.desktopImageURL(for:)` to something like:

`/Users/mac/Downloads/图片生成限制.png`

### Disk cache sample (not black)

`~/Library/Caches/LaunchcopyWallpaper/v1-*-*.png` exists.

Pillow sampling of a cache file showed approx:

- avg RGB ≈ `(78, 84, 72)` (muted olive/gray-green)
- corners/center non-zero

So **blur/render is not outputting an all-black bitmap**. If UI is pure black, the failure is almost certainly **compositing / view opacity / layer hierarchy**, or the visible window is not the hierarchy we think we’re painting.

---

## 3. Desired architecture (from LaunchBetter, Route B reference)

LaunchBetter (user-owned) pattern — **do not copy line-by-line; reimplement**:

### Window (`LauncherWindow.swift`)

```swift
isOpaque = false
backgroundColor = .clear
// full screen.frame, borderless
```

### Content hierarchy (`LauncherWindowController.swift`)

```text
root (NSView, wantsLayer)
  ├─ backgroundLayer (CALayer)  // wallpaper CGImage in .contents
  ├─ dimLayer (CALayer)         // black ~0.35 opacity (animated on show)
  └─ foregroundView (NSView, transparent)
        └─ grid / search / settings chrome
```

Grid uses `collectionView.backgroundColors = [.clear]`.
When wallpaper allowed: `surface.layer?.backgroundColor = nil`.
Reduce Transparency: opaque `windowBackgroundColor` fallback, no blur.

### WallpaperProvider optimizations (digest)

- Thumbnail decode (~512px)
- Cover crop + Gaussian blur
- Render at ~0.25–0.35× resolution (blur hides detail)
- Memory + async disk cache; in-flight dedupe
- Ignore window origin in cache key
- Provenance/whitelist: `Docs/PHASE1I_VISUAL_REFERENCE_DIGEST.md`, `PROVENANCE/PHASE1I_SOURCE_ACCESS.md`

---

## 4. What Launchcopy currently does

### Key files

| File | Role |
|---|---|
| `Sources/PagingPrototypeApp/WallpaperBackdropProvider.swift` | Blur pipeline + caches |
| `Sources/PagingPrototypeApp/WallpaperBackdropView.swift` | `WallpaperBackdropController` — installs pass-through `NSImageView` + dim view under host subviews |
| `Sources/PagingPrototypeApp/LaunchcopyVisualTokens.swift` | blur radius / scale / colors |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | Builds window, attaches backdrop, hosts `PagingSurface` |
| `Sources/PagingPrototypeApp/LauncherWindowController.swift` | Option B panel; sets `window.isOpaque = false`, `.clear`; may hide menu bar/Dock while visible |
| `Sources/PagingUI/PagingSurface.swift` | Full-bleed paging surface; **recently** `override var isOpaque: Bool { false }` + transparent internal container |
| `Sources/AppGridUI/AppGridPageView.swift` | Page chrome; background cleared; `override var isOpaque: Bool { false }` |

### Current intended hierarchy

```text
QuitOnBlankClickWindow (isOpaque=false, backgroundColor=clear)
  contentView = ClickDeliveryProbeView (isOpaque override false)
    ├─ PassThroughImageView   // wallpaper (hitTest=nil)
    ├─ PassThroughDimView     // light black veil (hitTest=nil)
    ├─ PagingSurface          // full bounds, should be non-opaque
    │     └─ TransparentPageContainerView  // pages/cells
    ├─ search field (optional)
    └─ settings gear button
```

### Packaging note

`Scripts/package-app.sh` now: kill old Launchcopy processes → delete old `.app` → build → assemble `.build/packaged/Launchcopy.app`.

Run:

```bash
cd /Users/mac/Projects/Launch_Copy/PagingPrototype
./Scripts/package-app.sh
.build/packaged/Launchcopy.app/Contents/MacOS/Launchcopy 2>&1 | tee /tmp/paging-smoke-out.log
# look for paging-wallpaper: lines
```

---

## 5. Attempts already made (all failed visually for user)

1. Sibling `WallpaperBackdropView` under surface + dim ~0.42  
2. Clear `AppGridPageView` background (was `controlBackgroundColor` — definitely wrong for wallpaper)  
3. `window.isOpaque=false` + clear  
4. CALayer on backdrop view / root-layer insert  
5. `PagingSurface.isOpaque` override + clear layers  
6. Internal `containerView` → `TransparentPageContainerView`  
7. Pass-through `NSImageView` under surface + sync **RAW** desktop image before blur  
8. Reduced dim/blur  

**Still pure black on user screenshots** despite logs claiming RAW + blur applied.

---

## 6. Strongest remaining hypotheses (ordered)

### H1 — Something still paints an opaque full-screen black above the image view (MOST LIKELY)

Even with `isOpaque == false`, some child may still fill bounds:

- Live page **hosts** inside `PagingSurface` (not only `AppGridPageView`)
- Any `NSView` with default opaque behavior + `wantsLayer`
- Lab overlay / other chrome
- A layer AppKit re-creates, wiping or covering wallpaper

**Debug**: Temporarily set wallpaper `NSImageView` to a **bright solid red** `NSImage` and/or set `surface.alphaValue = 0.3`.  

- If still pure black → wallpaper view not in visible tree / wrong window.  
- If red shows dimmed → compositing works; previous “black” may have been ultra-dark wallpaper+blur (less likely given user certainty).  
- If red never shows but logs say image set → wrong host / removed from hierarchy after refresh.

### H2 — Wallpaper view not actually under the visible surface after later layout

`fillContentToWindowBounds`, folder overlay, settings button, or re-attach may reorder/remove views. `layoutToHost()` tries to re-sink image view; verify with runtime dump of `contentView.recursiveDescription` / subview order after show.

### H3 — Full-screen + `NSApp.presentationOptions = [.hideDock, .hideMenuBar]` interaction

While launcher is visible, menu bar/Dock are hidden. Confirm this doesn’t leave a black backstop that confuses testing. Try **disabling chrome-hide temporarily** while debugging wallpaper.

### H4 — Wrong window / multiple instances

User may still be looking at an old instance (Ice, Dock). Script tries to kill old processes; double-check only one `Launchcopy` PID and that stdout log updates on each launch.

### H5 — Image assigned but not drawn (NSImageView scale/layer quirk)

Less likely after RAW 2508×1672 assign, but try `window.contentView?.layer?.contents = cgImage` **on the contentView layer itself** (LaunchBetter-style single root layer contents) with all child views proven non-filling.

---

## 7. Recommended fix plan for GPT / next agent

### A. Prove compositing in 5 minutes

1. Kill all Launchcopy; delete `.build/packaged/Launchcopy.app`.  
2. In `WallpaperBackdropController.refresh`, force:

   ```swift
   imageView.image = NSImage(size: size)
   imageView.image?.lockFocus()
   NSColor.systemRed.setFill()
   NSRect(origin: .zero, size: size).fill()
   imageView.image?.unlockFocus()
   ```

3. If user still sees black → hierarchy/opacity bug, not wallpaper decode.  
4. If user sees red → restore wallpaper; tune blur/dim.

### B. Match LaunchBetter root compositing exactly

1. `contentView` = clear root `wantsLayer`.  
2. Set wallpaper as **`contentView.layer?.contents`** (or sublayers at index 0/1 before any subviews).  
3. Put **only** a transparent foreground host for `PagingSurface` + chrome.  
4. Audit every view in the chain: `override var isOpaque: Bool { false }` where SDK requires override; `layer?.backgroundColor = nil`.  
5. Dump `contentView.subviews` and layer tree after `launcher.show`.

### C. Align blur with LaunchBetter render

LaunchBetter `WallpaperProvider.render`:

- Cover-scale via **CGContext.draw** into target pixel buffer first  
- Then `CIImage(cgImage:).clampedToExtent()` + `CIGaussianBlur`  
- Crop to target; shared `CIContext`  

Current Launchcopy path uses CI transform cover + blur; cache is non-black, so secondary — but aligning render may help quality once visible.

### D. Keep packaging hygiene

Always:

```bash
# already in Scripts/package-app.sh — keep it
# stop processes → rm -rf .build/packaged/Launchcopy.app → swift build → assemble
```

---

## 8. Non-goals / don’t break

- Paging physics, 5×7 capacity, search/folder/drag persistence, activation entries  
- Blank-click: settings open → close settings first; else hide launcher; `onLauncherDidHide` closes settings as safety net  
- Icon hit target: icon only + ~4px  
- No Buho reverse materials; LaunchBetter only per approved whitelist + window files already noted in provenance  

---

## 9. Acceptance check

Wallpaper is fixed when:

1. Between app icons, user can clearly see **desktop content** (blurred or raw).  
2. With Reduce Transparency ON → solid token color, no crash.  
3. Logs still show successful apply; UI matches.  
4. Only one Launchcopy process; fresh `.app` hash each package.

---

## 10. One-sentence summary for GPT

**Wallpaper bitmaps are successfully decoded/cached (non-black), but the full-screen launcher UI still composites as pure black—almost certainly an opaque view/layer above the wallpaper (especially `PagingSurface`’s page container / surface chain) or wallpaper not attached to the live visible root; fix by proving with a solid red backdrop, then adopting LaunchBetter’s clear-window + root-layer wallpaper behind a fully non-opaque foreground grid.**
