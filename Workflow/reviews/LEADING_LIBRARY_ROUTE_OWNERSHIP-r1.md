# Leading Library route ownership — independent review and repair

Date:2026-10-19. Reviewer Parfit (`01a15329-26bc-7202-899d-0a2c19c7197c`), source/test-design inspection only. No writes, test/build/UI/prefs/process/reference-source operations. Agent closed after final bounded re-review.

## Main-found and reproduced contract gaps
Ordinary grid delivery consumed original events and called surface before the Window readability guard; a cached grid/native destination survived non-pager semantic owner changes. Main factored value decisions on the actual event path. Worker Avicenna wrote8value-only regressions. Main RED-r1:8tests,38failedassertions/5failedcases. Repair: normal grid/native events pass through the existing Window/AppKit path; deferred original begin forwards once; grid availability revocation drains; button/hide semantic owner changes clear held begin and drain old tails. Focused green-r1:110/0.

## Reviewer P2 / solution
Reviewer found that the Window's prior unreadable-stream suppression remained set when an available zero-delta began was held by parent arbitration; later changed/tails were suppressed even though deferred began reached native dispatch. Initial SOURCE ACCEPT withheld.

Main preserved late Window gating and factored its sequence flag into `MainGridScrollSequenceGate`. Actual Window observes fresh available boundaries after folder routing but before the leading callback; consumed events still return immediately, Library native mode still precedes the late gate. No global early unreadability rejection was introduced.

Seven joint/value tests mirror that order and conditional returns. Before repair, a no-op early observer preserves the old flag behavior: Main window-RED-r1 executed7tests with9failedassertions across2cases, including the precise unreadable→readable zero-began held→grid-changed/tail suppression. The repaired observer resets only on available began/mayBegin/independent wheel, never on readability alone or old changes/ends/momentum. Main focused green-r2:117/0.

## Final disposition
Bounded **SOURCE ACCEPT**: prior P2 closed; no new confirmed P1/P2 in reviewed changes. Reviewer explicitly confirmed actual Window order and joint tests. RED/GREEN execution was Main-owned, not independently rerun by reviewer. Final527input full/build/package verification is a separate gate. Real cached NSEvent dispatch count, AppKit behavior, physical smoothness and human fidelity remain unverified while desktop is locked.

Intermediate525input run3206/0/package is retained but superseded by the known P2 and is not the final accepted source/package. No legacy tests or product parameters were weakened; no current native/physical PASS follows from these records.
