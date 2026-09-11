# Launchcopy App Icon — generation prompts

Image API was unavailable in-session (invalid xAI key). Use one of these prompts in Codex CLI / Imagine / SF Symbols export workflow.

## Primary prompt

```text
macOS app icon for "Launchcopy". Rounded squircle, soft dark charcoal to deep navy gradient,
centered abstract grid of four soft glowing rounded squares suggesting an app launcher grid,
subtle cyan-indigo accent glow, minimal flat Big Sur style, no text, no letters, no third-party
brand marks, high resolution, centered.
```

## Alternate (lighter)

```text
macOS app icon, light gray squircle, indigo soft grid of four rounded tiles, gentle shadow,
clean SF-style product icon, no typography.
```

## Install

Place resulting `AppIcon.icns` (or 1024 PNG → `iconutil`) at:

`Resources/AppIcon.icns`

Update `Scripts/package-app.sh` to copy into `Contents/Resources/` and set `CFBundleIconFile`.
