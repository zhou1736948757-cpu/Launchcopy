# Phase 1I Gate 0 — Draft decision packet

- **Date**: 2026-09-11
- **Prompt**: `Docs/PHASE1I_INDEPENDENT_VISUAL_SYSTEM_AND_PRODUCT_POLISH_PROMPT.md`
- **Prompt SHA-256**: `f3532e254a6ae33ebc46359da8c9ae9a42bab7b6975877e99a5bbc57fccf39f9` (verified)
- **Status**: DRAFT — awaiting user confirmation of D1–D8; **no product source edits until APPROVED**

## 1. Phase 1H reconciliation (honest)

| Layer | Status | Note |
|---|---|---|
| Product identity | DONE | Launchcopy / `com.launchcopy.app` |
| Settings window | DONE | Renamed「设置」; apply success banner; restore defaults; shortcut preset+record |
| Launch at Login | DONE | SMAppService + Fake; default off |
| Packaging script | DONE | unsigned `.build/packaged/Launchcopy.app` |
| User practical acceptance | RECORDED | 「基本功能都实现了，也没什么问题」 |
| Formal App icon / Resources | **OPEN** | Resources still empty — primary 1I driver |
| Independent Reviewer pass on 1H | **OPEN** | Not blocking daily use |
| Signing / notarization / RC | **NOT STARTED** | Deferred to Phase 1J |
| Phase 1G physical gates | **PENDING debt** | M01–M12 etc. not invented PASS |

Checkpoint `PHASE1H_CHECKPOINT.md` is slightly stale (still says shortcut readonly / 「激活设置」); live code has recorder +「设置」. Gate 0 treats **live tree** as truth.

## 2. Why Phase 1I before RC

Functionally ready enough for daily use, but visual system is still prototype-grade (system black fill, generic focus, neutral folders, no product icon). Freezing RC now would freeze those interim looks.

## 3. Proposed Phase 1I boundary

**In:** tokenized visual system; restyle background/cells/pager/search/folder/drag/focus/errors; formal icons; optional polish on settings; a11y appearance modes; zh/en copy boundary; screenshot + VoiceOver + perf + trackpad regression; LaunchBetter ownership/whitelist if Route B/C.

**Out:** signing, notarization, publish, commit/push/tag; Buho reverse materials; changing paging physics, 5×7 capacity, search/folder/drag persistence, activation entry semantics (unless D4/D8 narrow exceptions).

## 4. Craft reference (not a copy source)

User pointed at a GitHub “skills” Apple-adjacent craft guide — interpreted as **Emil Kowalski (`emil-design-eng`)**: polish, motion decision framework, Reduce Motion, press feedback, no animation on high-frequency keyboard actions. Also available: `apple-design` for HIG vocabulary. These inform taste/criteria; they are **not** LaunchBetter asset transfer.

## 5. Decisions required (D1–D8)

Pending user answers in chat; recommendations marked.

## 6. Stop condition

No product source modification until user approves this packet and D1–D8.
