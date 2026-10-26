# Leading Library routing — regression repair results

Date:2026-10-19. Full objective ACTIVE / INCOMPLETE. Approved Library semantics and paging parameters unchanged. Main owns integration/serial verification/native UI; agents were limited to disjoint test authoring and independent read-only review.

## Proven contract gaps and repairs
1. Non-pager pane changes (button entry / owner hide) left cached grid/native routes alive. Semantic location changes now revoke held begin and drain the old tail; only a new gesture/independent wheel chooses a new owner.
2. Ordinary grid events were consumed and forwarded directly before Window readability protection. Grid/native current events now continue through existing Window/AppKit delivery; the held original begin forwards once, with no generated event. Revoked grid admission drains rather than leaking into an unavailable grid.
3. Independent review found stale Window unreadability suppression when a new available zero-delta began was held before the late gate saw it. Window now observes fresh boundaries before parent arbitration, using a small value gate, while retaining late grid suppression and Library/folder priority. Old changes/ends/momentum and mere readability recovery cannot reset suppression.

No synthetic input, provider/index migration, gesture retuning, new frame source, UI opt-in change, reference code/assets, production data mutation or distribution action.

## Evidence progression
| Packet | Actual result / scope |
| --- | --- |
| Ownership RED-r1 |8tests,38failedassertions across5cases. Value-input decision path with unchanged failing delivery/owner behavior; not a native observation. |
| First GREEN |110/0 focused;525inputs full3206/0,Debug/Release/package/diff. Intermediate r2 package retained but superseded by reviewer P2; green was not source/native acceptance. |
| Window joint RED-r1 |7tests,9failedassertions across2cases. Factored unchanged late gate plus no-op early observer reproduces held-begin suppression with exact production-order value harness. |
| Final focused GREEN-r2 |117/0. Eight ownership tests plus seven Window/gate tests added; no legacy expectations weakened. No shown window or NSEvent synthesis. |
| Final frozen serial verification |527inputs; full-r2 **3213/0**, Debug/Release/package-r2/diff all passed. Frozen manifest `source-inputs-r2.json`; logs and receipts under `.build/verification/20261019/leading-library-route-ownership/`. |
| Independent review |Parfit bounded SOURCE ACCEPT after final re-review, prior P2 closed. Reviewer inspected actual Window wiring and test design, did not rerun tests or UI. `Workflow/reviews/LEADING_LIBRARY_ROUTE_OWNERSHIP-r1.md`. |

Main retained RED input hashes, failed-case names and both serial manifest generations. No source changes while either frozen serial run was live. Current source is not represented by the earlier902e83b5 candidate or the superseded intermediate r2.

## Native / physical limits and next executable action
Fresh CUA observation still returned **LOCKED**; current candidate was not opened. Previous owned52219/3f folder app was not quit. An unlock request is already pending; do not repeatedly ask or use alternate computer-control technology. New package must remain unsigned/uninstalled and use a fresh isolated profile with only verified owned fixtures.

After manual unlock: normal Quit exact old owned instance, verify absence, native-open newest matching candidate through CUA. Follow `Docs/LEADING_LIBRARY_NATIVE_VALIDATION.md` for retained button/Escape, app-page count, leading horizontal navigation versus Library vertical list, prior-page versus first-page return, protected folder/work, resize/hide and exact rollback. Real cached event dispatch, AppKit behavior, physical touchpad smoothness and human aesthetic acceptance are NOT proved by value tests/source review. Existing generated drag and long-tail frame causality remain unresolved.

## Final delivered source/package checkpoint
Candidate: `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/leading-library-rc-20261019-r3/LaunchcopyUITest.app`

Executable SHA-256: `9a438f149b44ef6ba4e42cc413e1eec35feef40a7dab61d645c84e62b8724219`. Source manifest527/527 stillmatches. Focused117/0/full3213/0, all5serialjobs exit0;365packagedkeys×3languages verified. New strict-v1 gui profile seeded ONLY249 verified authored fixturefiles (82syntheticapps and ownlayout/capacity); no appearance/Library/history/pref/cache/lock imports. Native entry remains LibrarydefaultOFF.

A post-package CUA preflight again returned LOCKED; exact ps confirmed priorowned52219/3f stillrunning. No newcandidate launched or installed, no previousapp quit, no duplicateunlockquestion or alternatecontrol. Real-event/native/physical gates remain pending. This turn made concrete source/test/package progress; no broader-parity completion claim.

## Native resume supersession —2026-10-19
Actualmanualunlock→old52219normalQuit/absence→matchingnew9a438f14r3own50252running. NativeLibrarycoldOFF/historyOFF, explicitownON/Saved/historyOFF; independentquery/Escape clear/back restoresmainquery; page2entry/Backreturns2; LibraryAXscroll0→0.139475→0. Icons lateroriginal1–10 and11–20colored. Fullcurrentnative/physicalgateNOTclosed: generatedCUAscrollnoneffectsinconclusive, userrealtrackpadtestnowrequested. Currentemptyfirstmainpage leftforuser, don'tinterfereUI. Currentnative-results-r1.json/stage supersede earlierLOCKED/NOT_RUNcheckpoint; no sourcechangeorbuildrerun.
