# Leading Library page — product/navigation proposal

Date:2026-10-19. Status: PROPOSED / awaiting explicit product decision. This does not amend the approved separate-view contract yet.

## Problem and intended outcome
The requested full experience includes a reserved Library-as-leading-page variant. The approved implementation currently offers an optional separate Library; broad permission does not settle its horizontal navigation or page model. Offer a leading Library page while retaining Launchcopy paging performance and canonical app-page identity.

## Recommended user-visible semantics
When the existing optional Library feature is enabled (default remainsOFF), place it to the left of the first app page: horizontal swipe from that boundary enters Library; swipe back returns to the first grid page. Retain the existing button/keyboard-accessible entry; entering through that action from another app page remembers the prior grid state for Close/Escape return. App-only page numbers remain1…N; Library has a distinct accessible identity rather than being named apppage0. Preserve grid query/committedpage/focus/organization; no capacity or storage migration. Drag, title editing and an open folder exclude entry rather than silently cancelling user work. Main's ordinary app navigation/physics remains unchanged; no new activation gesture/history collection.

## Architecture constraints, not implementation approval
Represent Library and canonical app pages with explicit semantic locations. Do not persist an arbitrary physical offset or insert an undocumented negative page. Reuse the existing frame/gesture ownership infrastructure; no second independent pump, synthetic wheel/key chaining or per-frame catalog/icon/classification/persistence work. Resolve exact mapping, momentum ownership, interruption, accessible page-dot behavior, resize/hide lifecycle and existing separate-view restoration before implementation. Existing arrow-key grid item navigation remains app-only; the retained accessible Library button provides keyboard entry. Do not invent new global shortcuts.

## Non-goals and acceptance
No extra pinch/spread/three-finger gesture, full uninstall, private assets/source or OS settings. No default-ON Library or usage tracking. Require a bounded approved implementation spec, explicit index/anchor/focus contracts, disjoint owners, source review, focused/fullnonzero suites, Debug/Release/package/current-native checks and matched physical paging evidence. Automated/native/generated/physical/human gates stay distinct. Deferring this variant is an explicit scope disposition, not proof of full reference parity.

## Open decision
Should this leading-page navigation replace the separate-only Library presentation when Library is enabled, with the semantics above, or should the current separate entry remain for now? No source code may change for this branch until the human confirms.

## Product decision —2026-10-19
User explicitly selected the recommended leading Library page scheme via the pending decision question. The product semantics above are APPROVED. Architecture/index/owner contracts still need a concrete implementation specification before source changes; this is not source/GUI/physical acceptance. Preserve the optional defaultOFF and separate app-page numbering.
