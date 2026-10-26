# Drag feedback refinement results —2026-10-21

## Delivery and exact scope
Removed the explicit dark card/separator border/black shadow behind the durable icon+caption in DragUIVisuals.configureViews. This is a confirmed source-level contributor to the reported unwanted backing. Unchanged: source snapshot policy, captured content geometry, host/elevation/reuse/cleanup, indicators, paging/drag thresholds, persistence and preference schemas. Native continuous drag appearance is still pending human acceptance; no screenshot of an actual admitted new drag is claimed.

The other reported issue, perceived roughly0.3s release-to-placement lag, is NOT FIXED. Read-only source trace found synchronous pointerUp/model commit/open-folder refresh, no fixed300ms wait. Conditional same-revision PagingSurface refresh and asynchronous icon rebind/delivery remain possible boundaries, not demonstrated causes. Do not relabel the user's time estimate as measurement or lower unrelated dwell/persistence/animation constants. Next discriminator: exercise actual AppDelegate pointerUp wiring with controlled store/icon delivery, then neutral runtime boundary measurements if still needed. See timing-source-findings.md in the evidence folder.

## Verification
- RED: new hosted-preview test fails on the old source with54decorative-backing assertions.
- GREEN:31focused preview/host/elevation/folder/main tests,0failures.
- Full authoritative suite:3382tests,0failures (3381previous+1regression),terminalexit0.
- Debugbuild and actualRelease unique packaging:exit0; packaged365keys×3languages verified.
- Frozen553recordedsourceinputs unchanged after testing/packaging; exactlytwo code/test files differ from the preceding553baseline. gitdiffcheckPASS.
- Independent Laplace SOURCE_ACCEPT for the bounded visual delta/test; no finding, no independent runtime/timing/performance/fullparityPASS. Read-only Feynman delay trace is distinct. Both agentsclosed.

## Candidate and data handover
Unsigned/uninstalled candidate: `.build/candidates/drag-feedback-rc-20261021-r1/LaunchcopyUITest.app`.

Executable SHA-256: `327e29d8de4fdf6fc78a3c24f593efa35d22780ba7d07d24ac968d3937ee8a56`.

Old original json-inspection instance normalCommandQ/exactabsence, no force/signals. The actual human's current35-member order was preserved: layout hash4302aa865272fce32c622284fecf40dd30b94c372aecb1f0ee25f6cd56cfdef7, NOT overwritten with old723199c6fixture backup. Its changed member permutation/top-level46→48 normalization is intentional recorded runtime change, not hidden as seedhashstability.248otherknownauthoredfiles remain oldhashmatched. Freshnewprofile contains249currentauthoredfixturefiles includinglatestlayout/capacity, verifiedbyteidenticalafteropening; no oldpreferences/history/wallpapercache copied. Originalprofile preserved.

Main supportedCUA opened exactnewcandidate and verified ordinarywindow/main populated plus35-memberglassfolderpage1/3 withthelatestmemberorder andvisibleicons. Initial scan/firstfoldermoment hadunloadedicons; nextsnapshotshowedthem, withoutarbitrarilyclaimingduration/cause. Wallpaper remainedloadinginthisfreshprocess, notREADY; no performance/compositingacceptance onnormalwallpaperclaimed. Leftfolderopenforvisualinspection, settingsclosed/queryempty. Desktop2placementnotverified. See results-r1.jsonforcurrentPIDattimeofreceipt; don'tcarryoldPIDforward.

No realapp launch/removal, userformaldata, OS/backend/consent, forbiddenreference, sign/install/publish/Git/reset/clean, processsignals or savedscreenshots. MainsoleUI/serialverification; no livebuild/test/agentsremain. Fullgoalremainsincomplete/active, optionaloutwardHideunchanged/proposed, firstLibraryhitchnonblocking/causeunproved.

Evidence: `.build/verification/20261021/drag-feedback/` contains before-source, frozeninputs, RED/focused/full/build/package logs, separate source reviews, latestownedlayout backups, candidatefixturemanifest and finalneutralreceipt. Prior generated-drag/no-value-control packet remains historical and is superseded only by the user's actual physical drag feedback—not by fabricated automation admission.
