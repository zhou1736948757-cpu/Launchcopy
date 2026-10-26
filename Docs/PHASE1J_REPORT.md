# Phase 1J — Release Candidate Report

- **Date**: 2026-09-11
- **Result label**: **RC_IMPLEMENTED_MANUAL_PENDING** (not `LOCAL_RC_VALIDATED`, not `RELEASED`)
- **Support claim**: Apple Silicon arm64, macOS 26.5.2 (25F84), built-in Color LCD; **local unsigned only**

## 1. Candidate identity

```text
.path = .build/candidates/phase1j-rc-20260911/Launchcopy.app
.exe  = …/Contents/MacOS/Launchcopy
.sha256(exe) = 246adc55f107a425437cbe1fd2bec638479b571e10becd1605017117a3c8e4a6
.git_head = 6382bd9 + dirty (wallpaper/cell + Phase 1J test/packaging)
.signature = adhoc / linker-signed
.notarization = NOT_RUN
.publication = NOT_RUN
```

Verified running process matched this path (pid 49430) during GUI probes.

## 2. Track A — seven legacy failures

Cleared by **contract-aligned test/fixture repairs** (no DropIntent / hitTest product change):

| Contract preserved | Repair style |
|---|---|
| icon ±4pt launch hit | Bug9 expectations + launch path point/window |
| folder-member row-band > move-out | Bug10/Bug11/DragCommit fixtures + row-band regression |

> **2026-09-16 postscript:** the icon ±4pt launch hit contract was **not** continuously
> preserved — the Phase 1J commit `bddb0fa` widened it to whole-cell bounds (Reviewer r1
> FAIL, finding M1). It was restored to icon±4 the same day per user decision
> `Workflow/decisions/D-1J-HIT-REGION-REVERT.md` (`T-1J-LM-HITREVERT`).

Full suite: **1530 executed / 0 failures** (`Workflow/artifacts/T-1J-FULL/full-suite.log`).

## 3. Packaging safety

`Scripts/package-app.sh`: unique `.build/candidates/<id>/`, no default `pkill`/`rm`, exact `--show-bin-path` binary, refuse overwrite. Smoke: `Scripts/package-app-smoke.sh` PASS.

## 4. GUI matrix (packaged candidate)

| Check | Status | Evidence |
|---|---|---|
| Exact candidate process | PASS | `lsof` path + exe sha256 |
| Wallpaper behind grid | PASS | `Workflow/artifacts/T-1J-GUI/01-initial-grid.png` |
| Idle cells without dark cards | PASS | same screenshot (PASS_USER_REPORTED carried) |
| Bottom full-width black band | OBSERVED | same screenshot — not re-opened as cell-fill; needs user call |
| Settings window (「设置」) | PASS | AX: 四指捏合启用=1 / 就绪; 登录时打开=0 |
| Residence hide ≠ quit | PASS | windows empty, same pid; `open` re-shows |
| Search field accepts text | PASS (input) | AX Value=Calculator |
| Search filters results | PENDING | AX still listed full catalog; no confirming screenshot |
| Folder open / inner nav | PENDING | AX click lost focus/hid window |
| Paging / drag / four-finger physical | NOT_RUN | needs user trackpad |
| Restart layout restore | NOT_RUN | needs user |
| Reduce Transparency fallback | NOT_RUN | needs authorized setting change |

## 5. Distribution gates (separate)

| Gate | Status |
|---|---|
| Local build + bundle inventory | PASS |
| Ad-hoc signature classification | PASS (adhoc) |
| Developer ID / Hardened Runtime | NOT_RUN |
| Notarization | NOT_RUN |
| Publish / upload | NOT_RUN |

## 6. Next approval

1. User completes remaining GUI matrix on this exact candidate (or waives with scope).
2. Optionally authorize signing experiment (J7) — still no publish.
3. Independent Reviewer on stable evidence before claiming `LOCAL_RC_VALIDATED`.
