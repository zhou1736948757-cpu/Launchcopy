# Folder Trackpad Paging

Status: APPROVED_IMPLEMENTATION_CONTRACT
Approval: User confirmed continuous finger-following inner paging on 2026-10-16.
Date: 2026-10-16

## Problem and outcome
The adaptive folder currently exposes page buttons and keyboard navigation but lacks the same direct-manipulation two-finger horizontal paging as the outer launcher. Users expect dragging content to follow the fingers, settling after release rather than a threshold-triggered abrupt page replacement.

## Scope
Add isolated inner paging using the existing PagingCore behavior and normalized scroll mapping, without changing outer physics, Timer defaults, 5x7 outer capacity, approved adaptive folder geometry or canonical stored member order. The panel, title, dim backdrop and footer stay fixed; only member content moves inside a clipped viewport.

## Input and lifecycle contract
Horizontal two-finger scroll belongs exclusively to the open folder, never simultaneously to the outer pager. Preserve existing direction normalization, settling and edge damping; vertical scrolling does not page. Opening/closing, resize/reflow, content replacement, hide, teardown and unavailable geometry cancel inner interaction safely. Title composition/editing, active application drag, menus and drawing-only exit visuals cannot begin a paging gesture. Inner paging and application drag are distinct interactions. Keyboard/page-button changes synchronize one authoritative committed inner page and clear stale member selection; activation cannot launch an offscreen identity.

## Architecture and performance
Reuse the existing paging engine with folder-local state, not an independent approximate threshold algorithm or a second permanently running timer. Retain/reuse a bounded current/neighbor member presentation. Resolve layouts and names outside frame callbacks; do not scan, write preferences or trigger icon rebinding every frame. One authoritative folder layout snapshot defines viewport, columns, rows and page capacity. Cancel async work through generation/identity gates.

## Acceptance
Real two-finger drag follows motion and settles within the folder only; first/last page edges resist without leaking to the outer page. Rapid reversal, interrupted settle, partial final page, Return and arrow navigation remain coherent. Resize and title draft behavior keep approved layout guarantees. Reduce Motion reduces movement without breaking page semantics. Existing page buttons, keyboard navigation, member drag/move-out and canonical persistence remain valid.

## Verification and maintenance
Add pure input/state coverage, view/owner routing and lifecycle regressions; run actual focused and full suites and build/package an unsigned isolated candidate. Separately record native observations and human physical smoothness acceptance; generated events are not real trackpad evidence. Retain previous candidates and profile data, do not install/sign or change system preferences. Human layout proportions already accepted; this does not pre-accept new motion.

## Decision
User confirmed continuous finger-following folder paging using the existing outer behavior on 2026-10-16; discrete threshold-only page replacement was not selected.
