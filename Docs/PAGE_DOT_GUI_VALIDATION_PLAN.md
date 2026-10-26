# Clickable Page Dots — Exact Candidate GUI / Physical Gates

Status: NOT EXECUTED,2026-10-13. Source tests/review do not satisfy this gate.
Candidate: .build/candidates/page-dots-rc-20261013-r2/LaunchcopyUITest.app.
Bundle com.launchcopy.test.pagedots; executable SHA256:
a99e9888ecf7465d32a8067ff0310278781b45f57d6bf0915971580dbc7c7079.
Manual entry: .build/verification/20261013/page-dots/launch-ui-test-r2.command.

## Isolation / prerequisites

385 synthetic metadata-only bundles, candidate-local dots profile; fixed Baseline
and contained Extras; ordinary non-topmost window, fake activation/login, no
production preferences/layout/cache. These fixtures cannot certify app launch or
real icon workload. Runner does not reset existing profile or close resident apps.
Native last locked and earlier Terminal policy denial remain; do not bypass them.
User manual runner launch/unlock is needed before native CUA continuation.
Only normally Quit the specifically started test instance; no force stop/install.

## Rendered interactions (raw evidence required)

1. Check notch-safe search, no top decorative page number, unchanged wallpaper/
   material and label visibility. Dot strip must not overlap last-row icons/text
   at both contained small-window and authorized full-screen sizes. Minimum hit
   size and Dock/edge interference require actual rendered/input checks.
2. Click nonadjacent pages and rapidly replace the target. Commit selection follows
   the final committed page, not intermediate offsets; current picture remains
   continuous and no old completion jumps back. Clicking the current idle page or
   already active target has no extra effects. Return to committed while another
   target animates remains possible. Check nine-dot/window controls with >9pages:
   browsing changes only viewport; absolute target IDs remain correct.
3. Direction/Return during direct animation does not seed or launch old content.
   First direction afterward selects on final committed page. Search remains
   active/current query survives; field Return/Down cannot transfer stale focus
   mid-jump. Typing/clearing a query cancels obsolete navigation, then count/dots
   reconcile to committed results, including 0/1 page hidden strip.
4. Folder open/title editor/held B1 cell/click-only press/drag must ignore dot
   requests without focus loss, saves, session cancellation or wrong old-cell
   launch attributable to the ignored request. Exercise actual down/up/chrome
   routing; detached performClick and source traces alone do not prove this gate.
   Existing click-outside-folder policy must not regress.
5. Hide/resign/resize (height-only included)/screen change/catalog replacement/
   teardown must reject stale direct completions. Ordinary physical gestures and
   release window remain unchanged. Repeat show/resize/cancel/reopen cycles.
6. VoiceOver discovers labeled page/count/current and window controls. AXPress
   dispatches once; disabled/hidden controls and stale owner state do not navigate.
   Test selected/nonselected and hidden ancestors; Bool is action handling only,
   not completed navigation or a VoiceOver acceptance certificate.

## Performance and restart

Collect matched catalog/icon/viewport/build/frame-source/device workloads before
and after UI changes. Separate callback time from end-to-end cadence; >25ms
causality is still unresolved. Synthetic residency tests prove bounded reuse,
not smoothness/latency/real-icon workload. No unsolicited OS/TCC/settings changes;
use approved app-local RM override or ask before changing system preferences.
60Hz physical comparison,120Hz/multi-display and sustained source-watching remain
separate gates. Retest safe normal Quit and same profile restart without reset;
check sources/layout/titles/hidden/aliases/preferences retained. Record exact
candidate/profile/screenshots/actions and honest PASS/FAIL/UNTESTED per item.
No whole-parity, distribution or physical PASS is implied by this candidate.
