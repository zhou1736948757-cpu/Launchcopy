# Phase 1H Checkpoint

> Last update: 2026-09-11 — Gate 0 APPROVED; A/B/C/F + packaging script landed.

## Done

| Task | Status | Evidence |
|---|---|---|
| Gate 0 | APPROVED | `Workflow/decisions/2026-09-11-phase1h-gate0-approved.md` |
| T-1H-A apply plan + schema v2 | COMPLETED | `Workflow/results/T-1H-A.md` |
| T-1H-C Launch at Login adapter | COMPLETED | `Workflow/results/T-1H-C.md` (Fake-only mutations) |
| T-1H-B/F Settings UI + wire | COMPLETED | `Workflow/results/T-1H-B-F.md` |
| Packaging script | COMPLETED | `Scripts/package-app.sh` → `.build/packaged/Launchcopy.app` |
| ADR-014 | ACCEPTED draft | `Docs/ADR-014-PACKAGING-AND-DISTRIBUTION.md` |

## Identity

- Display name: **Launchcopy**
- Bundle ID: **`com.launchcopy.app`** (in packaged Info.plist)
- Locale: Chinese primary UI strings in status menu + settings

## Verification (2026-09-11)

- Filtered activation/settings tests: **55 executed / 0 failures**
- `plutil -lint` Info.plist OK
- Packaged app: `.build/packaged/Launchcopy.app` (unsigned)

## Remaining

- App icon asset (placeholder absent — Resources empty)
- Shortcut recorder UI (readonly display for now)
- Independent Reviewer pass
- Notarization / signed artifact (not authorized)
- Phase 1G physical debt still PENDING (not PASS)
- User GitHub publish (user-owned)

## How to try

```bash
cd /Users/mac/Projects/Launch_Copy/PagingPrototype
swift run PagingPrototypeApp
# or open .build/packaged/Launchcopy.app
```

菜单栏 → **激活设置…**
