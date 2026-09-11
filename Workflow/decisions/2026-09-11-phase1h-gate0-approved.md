# Phase 1H Gate 0 — APPROVED

- **Date**: 2026-09-11
- **Prompt**: `Docs/PHASE1H_PRODUCT_SETTINGS_AND_PACKAGING_READINESS_PROMPT.md`
- **Prompt SHA-256**: `8634c050773b710b3c47224906d0f354d34d5f688d0f0fa271b741cd44292ace`
- **User approval**: 「批准」(2026-09-11)
- **Supersedes**: `Workflow/decisions/2026-09-10-phase1h-gate0-draft.md`

## Phase 1G reconciliation

| Layer | Status |
|---|---|
| Automated implementation | COMPLETE (practical; 1468/0 at T-1G-E baseline + later smoke fixes) |
| User practical acceptance | RECORDED（「修好了」等） |
| Evidence-backed physical gates | NOT PASS — debt: M01–M12, energy A/B, multi-display, sleep/lock, rapid-race, 120Hz, B10/B11 |

## Approved product decisions

| ID | Decision |
|---|---|
| D1 display name | **Launchcopy** |
| D1 Bundle ID | **`com.launchcopy.app`** |
| D1 internal | `PagingPrototype` may remain package/executable module name |
| D2 distribution | GitHub public / open-source + direct-distribution readiness; **user** performs upload; this phase does not auto commit/push |
| D3 four-finger | Direct builds keep private MultitouchSupport + explicit Enabled≠Ready / error UI |
| D4 Launch at Login | Implement setting via public `SMAppService`; **default off**; real machine enable requires a separate announced reversible authorization |
| D5 Settings UX | Native AppKit preferences window |
| D6 locale | Chinese UI primary; localization-ready string boundaries |

## Implementation authorization

Product source implementation for Phase 1H is **authorized** under the above decisions and the Phase 1H prompt in/out of scope rules.
