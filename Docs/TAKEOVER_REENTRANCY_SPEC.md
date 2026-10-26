# Gesture takeover callback ownership

Date: 2026-10-20. Selected dedicated correctness follow-up to the approved whole-code review; not paging tuning.

## Problem / scope
During settling→physical-began takeover, interruption detaches the old transition then synchronously calls external stale/interruption/state observers. Those observers can teardown, cancel, or install a newer navigation context, but the old method currently continues by emitting notifications and creating a tracking session. Repair that concrete terminal/later-owner violation.

Unfreeze ONLY the private interruption continuation and its settling-began caller. Keep public APIs, normal input decisions/event order, current-page semantics, tokens/counters, GestureSession, spring/target/overscroll/glide equations and every parameter untouched. Existing UI/adapter/domain methods remain frozen. Environment-setter reentrancy and other Core callbacks are not globally redesigned/certified in this scope.

## Ownership contract
- Interruption returns whether the same takeover still owns continuation. Absence of an active transition is not permission to synthesize a session: nested began during the detached transient is rejected inertly.
- Capture original transition token and current session reference. Detach/stale/count the old transition in the existing order. After each outward stale and interruption callback, require !tearingDown, same token, no newer active transition, same session reference and the expected settling state before continuing.
- Publish interrupted in the existing order, then recheck the same ownership with expected interrupted state before permitting creation of the new session. Cancel/teardown or an accepted later navigation wins; no old tracking session or later old notifications may overwrite it. A rejected navigation/no-op is not a new owner.
- Ordinary, non-reentrant trace remains stale→interruption→interrupted→tracking. New session starts at the current displayed offset exactly as before. No new operation epoch, callbacks, per-frame allocation, timers, async work or stored state is necessary.
- State observers see the same normal states/order as before; no early property rewrite or widened canRequestPage permission. Requests during interrupted remain rejected by the existing API. Cancel followed by a valid new began from idle remains a distinct accepted owner and must survive.
- Latest environment values are not restored from a cached target/domain. Existing environment policy is unchanged; this patch is not a general guarantee for arbitrary nested environment-operation compositions.

## Acceptance / evidence
Use pure synchronous Core event traces, no AppKit/files/physical events. Cover teardown and cancellation independently at stale/interruption/interrupted-state boundaries; accepted newer request at settling stale/interruption boundaries; rejected interrupted-state requests; cancel→new accepted gesture; detached nested-began rejection; ordinary takeover offset/event order and bounded subsequent commit. Teardown must suppress every later callback/session; new context/session must retain exact identity, token and commit outcome.

Run selected regressions RED on byte-frozen old Core and normal trace control on both old/current, restoring exact current bytes in finally. Prove all production files other than PagingCore are unchanged, and replacing only the two bounded edited regions reconstructs old Core bytes (physics/parameters untouched). Focused Core/Surface/Folder/leading/direct navigation and full tests, Debug/Release unsigned isolated package and diff serially on frozen inputs. Independent bounded source/test-source review before final verification. No physical smoothness/120Hz/native acceptance inferred; first Library hitch remains user-deferred with CPU causality unproven.

## Ownership / safety / maintenance
Main owns production Core, inverse-delta proof and integration. One worker owns only new Tests/PagingCoreTests/TakeoverReentrancyTests.swift. Later fresh read-only reviewer owns one report; maximum3agents includingMain, no concurrent SwiftPM. Preserve dirty baseline and all prior acceptance history. No source-reference/formal-data/OS/UI/process-signal/install/sign/publish/Git mutation. Existing automated suites may use their own temporary fixtures. Current fd395b00 runtime remains untouched; latest49d89899 package is unlaunched. Update stage/plan/project memory/current index with exact outcomes and limits. Previous goal turn was concrete icon-source repair progress; full parity remains incomplete.
