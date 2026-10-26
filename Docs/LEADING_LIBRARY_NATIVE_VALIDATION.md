# Leading Library — isolated native validation packet

Date: 2026-10-19. Approved product contract: `LEADING_LIBRARY_IMPLEMENTATION_SPEC.md`. This is an executable checklist, not a native PASS or authority to touch production data.

## Preflight / isolation
1. Read current delivery index/results and verify the candidate executable hash and frozen source receipt. Use the newest matching candidate, not a historical process ID or the running old folder binary.
2. Manually unlocked desktop is required. CUA only; no shell UI launch, synthesized NSEvents, AppleScript, event injection, security/OS changes or automatic unlock workaround. Do not repeatedly retry a locked desktop.
3. Recheck exact old owned process path before normal Quit through CUA; verify absence before opening the exact new app through CUA. Do not terminate a formal/unknown app or signal any process. Do not overwrite/install a candidate.
4. New profile may seed ONLY249 already authored/hash-verified local fixtures (82synthetic apps, own layout/capacity). No old preferences, activity, cache or locks. Library/history begin defaultOFF. No real application action is necessary for this packet. Do not save screenshots containing personal wallpaper; inline observation only.

## Source-specific native checks
| Check | Expected outcome and evidence boundary |
| --- | --- |
| Cold default | Main grid readable; no top number, no Library app dot, Library disabled in own Settings. Record actual default, not a copied preference. |
| Explicit isolated enable | Enable Library through own native Settings. Existing accessible entry button appears. History remains OFF. Native setting acknowledgment is not fsync/power-loss proof. |
| Retained button / Escape | Button enters Library; independent Library query/list/details remain functional. Escape preserves existing composition→details→query→back precedence. Back restores original main query/page/selection. |
| Prior-page distinction | From second app page enter with button; Close/Escape restores second page. A horizontal swipe return goes to first app page instead. No additional app page/dot is inserted and saved organization is unchanged. |
| Leading boundary | From first app page swipe toward left Library pane, content follows and settles. Reverse returns to first app page. A grid-directed swipe still uses existing main paging. Record actual event/tool scope; generated scrolling cannot certify physical feel or all phased touchpad paths. |
| Library vertical scroll | Native vertical list scrolling changes list viewport, not the parent pane or hidden grid. Direction reversal within that stream does not transfer ownership. |
| Late tails / new input | Following button navigation, hide or cancellation, old changed/momentum events do not operate the new pane. A fresh gesture/independent wheel can select a new route. Value-input regression tests are separate from this real window check. |
| Protected work | Open folder retains local scroll ownership; no Library entry silently closes it. Parent transition does not allow drag/rename/dot actions to start. Do not invent a drag failure from ineffective generated tool motion. |
| Resize / key loss / hide | Cancel preview to last semantic pane; no orphaned preview, hidden grid, stale transform, locked input or active shared frame demand. Windowized test titlebar remains movable/resizable. No OS Space/fullscreen change is needed. |
| Readability | Small-window protection remains active; ordinary grid events continue through Window/AppKit gates. Restore only the own test window geometry afterward. |

## Locale / accessibility / performance
Current compact English/Japanese layout may be checked in the same candidate after reading the exact accepted language; restore that choice, not an assumed language. No OS language changes. Accessibility tree inspection is not spoken VoiceOver acceptance. Existing Reduce Motion settings may be observed; do not toggle OS settings without specific authority.

Record current candidate/PID, original own preferences, actual controls/actions/outcomes and exact rollback. Separate source review, automated component checks, generated native input, real physical touchpad and human aesthetic acceptance. No claim of physical 60/120Hz no-regression, frame-hitch causality or full parity follows merely from green tests/package.

## Current pending state
Desktop locked at the latest check; no new candidate has been opened and previous own52219 was not quit. An unlock question is already pending; do not resend it on each continuation. Resume this packet only after genuine desktop access returns.

## 2026-10-19 actual native resume
Manualunlockconfirmed; newest9a438f14r3nowown50252,old52219normallyquit/absence. NativecoldOFF→ownON/historyOFF, query/Escapeprecedence, page2Backreturn andAXverticalviewportcontrols observed. Generatedwheel-scrollinginconclusive; physicaltestquestionpending frommainfirstpage. This supersedes lockedpendingstate above. AvoidcontrollingUI untilhumanresponds.
