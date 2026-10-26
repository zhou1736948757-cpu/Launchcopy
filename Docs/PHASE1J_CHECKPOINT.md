# Phase 1J Checkpoint — status + Codex handoff

> Last update: **2026-09-12**
> Product: Launchcopy (`com.launchcopy.app`)
> Result label: **`RC_IMPLEMENTED_MANUAL_PENDING`** (not `LOCAL_RC_VALIDATED`, not `RELEASED`)

---

## 0. One-line status

Automation + safe packaging + Release candidate are done. User GUI matrix and distribution gates are not fully closed. **New user ask (2026-09-12):** tune **app/grid size & placement**, and add **restrained Folder open/close motion** per Apple / Emil design skills — **for Codex to implement**; this file is the handoff.

---

## 1. Candidate identity (do not discard)

```text
path:     .build/candidates/phase1j-rc-20260911/Launchcopy.app
exe-sha256: 246adc55f107a425437cbe1fd2bec638479b571e10becd1605017117a3c8e4a6
git_head: 6382bd9 + dirty (wallpaper/cell + 1J tests/docs/packaging)
signature: adhoc / linker-signed — NOT notarized
full suite: 1530 executed / 0 failures
  evidence: Workflow/artifacts/T-1J-FULL/full-suite.log
```

Preserve wallpaper occlusion + cell transparent idle fill. **`T-WALLPAPER-CELL-FILL` stays CLOSED** (PASS_USER_REPORTED 2026-09-11「黑框没问题，我验收通过」). Do not re-open as pending solely because an earlier tool session was locked.

---

## 2. What Phase 1J already finished

| Track | Status |
|---|---|
| Gate 0 | APPROVED (local Apple Silicon RC; 1I polish deferred; no sign/notarize/publish) |
| Track A — 7 legacy failures | DONE — fixture/assertion aligned to icon±4 + member row-band; no DropIntent product change |
| Track C — safe packaging | DONE — `Scripts/package-app.sh` unique candidates, no default pkill/rm |
| J5 Release package | DONE — candidate path above |
| J6 GUI matrix | **PARTIAL** — see §3 |

Skills / docs already in tree: `Docs/PHASE1J_FAILURE_TRIAGE.md`, `Docs/PHASE1J_VALIDATION_RESULTS.md`, `Docs/PHASE1J_REPORT.md`.

---

## 3. User confirmation checklist (A–D) — **awaiting user**

Reply per item: **通过 / 不通过 / 豁免（写范围）**. Codex must not invent PASS.

### A. 视觉（打开上述候选 `.app`）

| # | Item | Notes / Agent evidence |
|---|---|---|
| A1 | 壁纸在网格后可见 | PASS probe: `Workflow/artifacts/T-1J-GUI/01-initial-grid.png` |
| A2 | 空闲格无深色卡片（黑框） | Carried PASS_USER_REPORTED; screenshot supports |
| A3 | ~~底部大黑带~~ | **RETRACTED 2026-09-12** — 先前把截图底部的 **系统 Dock** 误判成应用黑条；用户确认未见应用内大黑带。不作为缺陷、不挡 RC |
| A4 | 键盘焦点指示仍可见 | Not fully re-probed this session |

### B. 生命周期 / 设置

| # | Item | Notes |
|---|---|---|
| B1 | 隐藏 ≠ 退出（同进程可再呼出） | PASS probe (same pid) |
| B2 | 「设置」单例窗可开 | PASS (AX) |
| B3 | 四指捏合：启用 + **就绪** | PASS (AX Value 就绪) |
| B4 | 登录时打开默认关 | PASS (AX Value 0) |
| B5 | 应用 / 恢复默认 / 关闭行为符合预期 | PENDING user |

### C. 核心交互（Agent 未能完整盖章）

| # | Item | Notes |
|---|---|---|
| C1 | 分页（慢/快/反向/边界） | PENDING user |
| C2 | 搜索过滤（勿乱启动真实 App） | 输入 PASS；过滤视觉 PENDING |
| C3 | Folder 打开/关闭/内层 | PENDING（AX click 易丢焦点） |
| C4 | 拖拽排序 / 移入移出 / 两成员解散 | PENDING user |
| C5 | 四指捏合实机 | PENDING user |
| C6 | Hot Corner（若启用） | PENDING user |
| C7 | 全局快捷键（若已设） | PENDING user |
| C8 | 重启后布局/设置恢复 | PENDING user |

### D. 范围决策

| # | Item | Recommended default |
|---|---|---|
| D1 | 只宣称 Apple Silicon + 当前 macOS + 内建屏 | Keep |
| D2 | Phase 1I 剩余全面视觉 polish **延期不挡 RC** | Keep（但 §4 新请求是**有界**布局+Folder 动效，另开切片） |
| D3 | 本阶段不签名 / 不公证 / 不上传 / 不发布 | Keep |
| D4 | 是否升 `LOCAL_RC_VALIDATED` | **否**，直到 A–C 确认或书面豁免 |

**Suggested user reply template** (also in chat history):

```text
候选 sha256 已核对：是/否
A: 1_ 2_ 3可接受|要修 4_
B: 1_ 2_ 3_ 4_ 5_
C: 1_ 2_ 3_ 4_ 5_ 6_ 7_ 8_
D: 1✅ 2✅ 3✅  升 LOCAL_RC：是/否
```

---

## 4. NEW WORK FOR CODEX — layout size/placement + Folder motion

> Authorized as **planning + bounded implementation after user/Codex Gate**, still under Phase 1J polish slice.
> **Do not** change accepted paging physics / `Timer.tolerance = 0ms` / 5×7 capacity defaults’ *semantic* contracts without an explicit decision delta.
> **Do not** sign, notarize, publish, or delete wallpaper/cell fixes.

### 4.1 Skill references (read these; do not invent motion)

| Skill | Path | Use for |
|---|---|---|
| apple-design | `~/.agents/skills/skills/skills/apple-design/SKILL.md` | Spatial consistency, origin-aware surfaces, springs (damping 1.0 / response ~0.3–0.4), materials, reduced motion |
| emil-design-eng | `~/.agents/skills/skills/skills/emil-design-eng/SKILL.md` | Should-animate gate, ease-out, ≤300ms UI, no `scale(0)`, transform+opacity only |
| animate | `~/.agents/skills/skills/skills/animate/SKILL.md` | Build sequence; Folder open = occasional → standard animation OK |

**Gate (Emil):** Folder open/close is **occasional** → short motion OK. Launcher show/hide via shortcut / four-finger used very often → **keep instant or near-instant**; do not add heavy show/hide chrome animation unless user explicitly asks.

### 4.2 Current reality (code)

| Area | Current | File / constants |
|---|---|---|
| Window | Full `screen.frame` borderless cover | `LauncherWindowController` / `AppDelegate` |
| Grid columns | Fixed **5** | `AppGridPageView.columns` |
| Cell height | Fixed **88** | `AppGridPageView` layout |
| Spacing | **16** | same |
| Grid insets | `inset=24`, **`topInset=96`**, bottom = inset only | `AppGridPageView.layout` ~L284–308 |
| Icon | `iconSide=48`, hit = icon±4 (whole-cell in commit `bddb0fa` → r1 FAIL M1 → restored 2026-09-16 per `D-1J-HIT-REGION-REVERT`) | `AppGridCellView` |
| Visual tokens | chrome/settings/wallpaper blur only — **no grid geometry tokens** | `LaunchcopyVisualTokens.swift` |
| Folder panel | Centered **`0.7×0.8`** of overlay, max 900×700 | `FolderOverlayView.layout` ~L599–607 |
| Folder `MotionParams` | Defined `duration 0.18 / scale 0.96 / displacement 8` + RM zero | `FolderOverlayView.MotionParams` |
| Folder open/close motion | **Params unused** — open/close is effectively **instant** configure/add/remove | `AppDelegate.openFolder` / `closeFolder` / `refreshFolderOverlay` |

**Bottom “black band” (A3):** Retracted. Screenshot bottom strip is the **macOS Dock**, not an in-app opaque fill. Layout work (§4.3) may still improve vertical centering for Launchpad-like feel, but must **not** treat Dock as a Launchcopy bug.

### 4.3 Desired direction (recommended for Codex)

#### A) Grid size & placement

1. Treat usable rect as **between menu-bar band and Dock band** (or content-safe margins), not “top sticky + abandoned bottom”.
2. **Vertically center** the 5×N icon block inside the usable rect (Launchpad-like), or distribute leftover space above/below symmetrically.
3. Optionally derive **cell pitch from available height** so ~7 rows fill the usable area without huge empty slab — keep 5 columns; do **not** silently change items-per-page / persistence schema.
4. Lift magic numbers into `LaunchcopyVisualTokens` (or a small `LaunchcopyGridMetrics` helper): `gridInset`, `topChromeReserve`, `bottomChromeReserve`, `columnSpacing`, `baseCellHeight`, `iconSide` — single source of truth.
5. Search / settings chrome stay reachable; labels remain readable over wallpaper (contrast). No new theme redesign.
6. After change: screenshot before/after on the **same candidate rebuild**; user re-checks A1–A3.

#### B) Folder open / close animation — **yes, add small motion**

Recommended recipe (Apple spatial + Emil ingredients):

| Parameter | Value |
|---|---|
| Purpose | Spatial consistency — panel grows from the **source folder cell**, returns there on close |
| Properties | **`transform` + `opacity` only** (CALayer / `NSAnimationContext`) |
| Enter from | `scale ≈ 0.94–0.96` + `opacity 0`, **origin at folder cell center** (not viewport center, not `scale(0)`) |
| Duration | **180–250ms** (existing `MotionParams.duration = 0.18` is a good start) |
| Curve | Strong ease-out / critically damped feel (`damping 1.0`); **no bounce** on open |
| Exit | **Same path reverse** (symmetric); slightly snappier OK (~150–200ms) |
| Scrim | Optional short opacity on dimming backdrop; keep interruptible |
| Reduce Motion | Opacity cross-fade only; `MotionParams.reduceMotion` already zeros scale/displacement — **wire it** |
| Interrupt | Escape / second click mid-flight must retarget from presentation value (no lockout) |
| Frequency gate | Do **not** animate every keyboard focus move inside the folder |

Wire the existing `MotionParams` instead of inventing a second system. If origin-aware anchor needs the source cell frame, pass it from `AppDelegate` / open path into overlay presentation.

#### C) Explicit non-goals for this Codex slice

- No paging physics / tolerance retune  
- No reopening cell-fill or wallpaper occlusion as “broken” without new evidence  
- No Buho / LaunchBetter source reads  
- No sign / notarize / publish / login-item registration  
- No animating high-frequency launcher toggle unless user later asks  

### 4.4 Suggested Codex task graph

| ID | Task | Output |
|---|---|---|
| L0 | Read this checkpoint + apple-design + emil-design-eng + current layout files | Short plan in `Docs/PHASE1J_LAYOUT_MOTION_PLAN.md` |
| L1 | Grid metrics tokens + vertical placement / safe margins | Code + screenshot artifacts under `Workflow/artifacts/T-1J-LAYOUT/` |
| L2 | Folder open/close origin-aware motion using `MotionParams` + RM | Code + targeted tests if feasible |
| L3 | Neighbor tests + full suite must stay green (1530 baseline may grow) | Log under `Workflow/artifacts/` |
| L4 | Rebuild **new** candidate dir (safe package script); do not overwrite `phase1j-rc-20260911` | New id e.g. `phase1j-layout-YYYYMMDD` |
| L5 | Update this checkpoint + validation results; leave A–D for user | No invented LOCAL_RC_VALIDATED |

### 4.5 Key files Codex will likely touch

```text
Sources/AppGridUI/AppGridPageView.swift          # grid insets / cell pitch / vertical centering
Sources/AppGridUI/AppGridCellView.swift          # only if icon metrics tokenized
Sources/AppGridUI/FolderOverlayView.swift        # MotionParams wiring + panel present/dismiss
Sources/PagingPrototypeApp/AppDelegate.swift     # open/close/refreshFolderOverlay timing + anchor
Sources/PagingPrototypeApp/LaunchcopyVisualTokens.swift  # geometry tokens
Sources/PagingPrototypeApp/LauncherWindowController.swift  # only if safe-area / chrome reserves need window help
Tests/AppGridUITests/…                           # folder present tests if any; layout smoke
Scripts/package-app.sh                           # use as-is for new candidate
```

---

## 5. Permission boundaries (unchanged)

- No commit/push/tag unless user asks  
- No signing / notarization / upload / publication  
- No `LEGACY_DESTRUCTIVE=1` packaging by default  
- No killing unrelated processes  
- English engineering artifacts; Chinese for user communication  

---

## 6. Next actions

1. **User:** fill §3 A–D (A3 no longer a blocker).  
2. **Codex:** execute §4 L0→L4; do not claim RC validated; do not “fix” the Dock.  
3. **After layout/motion candidate:** user re-checks A1–A2/A4 + Folder open/close feel.  
4. Only then consider `LOCAL_RC_VALIDATED`.
