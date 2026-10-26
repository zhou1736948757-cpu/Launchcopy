# Folder Viewport Fit — Existing Layout Maintenance

Status: CODE_VALIDATED_GUI_PENDING, 2026-10-14.

## Objective and authority

Repair the existing dynamic-pitch guarantee: all members of the current folder
page stay inside the title/footer-reserved grid area. Current56pt minimum cell
height defeats that guarantee on short panels. This is maintenance, not adjustable
rows/columns, scrolling, capacity migration or Library implementation. Existing
5columns/35members-per-page andphysicalparameters retained. Already-fitting cell
frames must remain exact; shrink only layouts which currently overflow.

## Baseline / constraints

Icon/type code2159/0,340fingerprints, Debug/Release, boundedsourceCLEAR; candidate
icon-type-rc-20261014-r1 retained. AllGUI/restart/VoiceOver/physical/iconquality
pending; native lastlocked/priorpolicydenial unchanged. Unapprovedcapacity/Library
branches do not authorize feature code. Dirtytree/history retained, no install/
launch/sign/publish/commit/processstops. Englishfiles/nativeChinese UI convention.

## Local critical path and sidecars

Main owns tests-first reproduction, minimal FolderOverlayView.layoutPanel repair
andserializedSwift. One independent read-only reviewer can verify bounded geometry/
input/capacity/fit regressions concurrently after stable repair. No duplicate survey
or worker for immediate blocker; atmostMain+2 if another concrete task arises.

## Required invariants / acceptance

Reproduce actual mounted overlay35members at1000x600; frame remains inside panel
reserved area(title40/top24/footer44/bottom12), all slots ordered/nointersection.
Test already-fitting maxpanel/smallfolders unchanged and extreme short panels
bounded/nonnegative. Keep existing horizontal column geometry/gaps and pagecount;
reduce vertical gap only if a row pitch cannot contain the old gap. Current shared
innericon/textfit policy handles compactcells; microscopicviewports do not promise
readable icons. No new frame IO/scans/iconrequests, and no new scroll interaction.
Record red/focused/full, independent source review, Debug/Release/currenthash/
uniquecandidate and remaining realGUI/physical gates. Full goal active/incomplete.

## Reproduction / minimal repair

Actualmountedview red:4methods272assertfailures at00:48:24.817JST; bottomcells
reachnegativepanelcoordinates(-168 in500ptoverlay). Already-fitting exactlegacy
framecasepassed. Source repairremoves56ptfloor; verticalgap=min(16,pitch/2) only
compresseswhenpitchcannotcontainoldgap. Horizontalspacing/columns unchanged;
cellHeight=max(pitch-rowSpacing,0), sameorderedrowpositionsinsidearea. No binding/
capacity/controller/scanning/icon/physics edits. Focused/full/review/buildpending.

## Dated arithmetic correction / authoritative reproduction

Prior survey/testfixture mistakenlyusedpanelHeight-132; realgridheight=panelHeight
-(40+24)-(44+12)=panelHeight-120. Initialred272 andfirstfocused101 failures
includeincorrect12pt expected-area assertions; earlieralreadyfitPASSstatementwas
notverified andissuperseded. Correctedfixturetested againstexactpreviousIconType
FolderOverlay source:4methods191assertfailures at00:53:11.379JST, already-fitting
exactframes nowPASS. Realbottomoverflow(-168) remainsreproduced. Restoredsame
minimalrepairbytesafterterminalred; no unrelatedsourcechanges. Alloldlogsretained.

## Source/test gate

Correctedfocused49/0 at00:54:44.298JST7.190s, full2163/0 at00:57:02.047JST37.720s.
341fingerprints captured; exactlyFolderOverlay/newtestdeltafrom2159baseline.
IndependentHarveySOURCE_REVIEW_CLEAR inFOLDER_VIEWPORT_FIT_SOURCE_REVIEW.md,
98lines; originalmathcontaminationandcorrectionrecorded. Reviewerclosed.
Debug/Release uniquefolder-viewport-rc-20261014-r1 currentlyrunning; no build/hash/
GUI/physicalPASSpresumed. Tinycellreadability/min200paneloutsideoverlay limits
remain honest boundaries. Library/capacitystillunconfirmed; fullgoalACTIVE.

## Final code-only delivery

Correctedred4methods191assertfails -> focused49/0 ->full2163/0. Independent
boundedSOURCE_REVIEW_CLEAR; Debug/Release20.97s success;341postbuildfingerprints
matched,currentexeSHA3cd72adc543a386ef1b9a2318226bae0067a9b0a50c9bf738bc97a040f533db8.
Candidate .build/candidates/folder-viewport-rc-20261014-r1/LaunchcopyUITest.app,
bundlecom.launchcopy.test.folderfit. Manualrunner
.build/verification/20261014/folder-viewport-fit/launch-ui-test-r1.command ready,
385metadata-onlysyntheticbundles/folderfitisolatedprofile/ordinarynon-topmostwindow,
NOT executed. No install/launch/sign/publish/commit/processstops; oldcandidates
retained. Allhelpersclosed/noSwiftjobs.

Exactly2source/testpaths changedfromIconType baseline, no controller/scanning/
iconkeys/persistence/capacity/physics edits. Fixedcurrentpage'souterrowoverflow
relativetoitsactualreservedpanelarea; already-fittingframes/horizontalgapsexact.
Veryshortcells canhaveunreadable/clippedcaptionsorzeroicon; min200panelcanexceed
smallerownerbounds (existingconstraint). Notuniversalfit/readability/performance
acceptance. NativeGUI/VoiceOver/realrestart/matchedphysicalAB/120Hz remainunverified;
lastlocked/priorpolicydenial notbypassed. Usermanualrunner/unlockbeforeCUA.
>25msCAUSALITY_UNRESOLVED unchanged.

Next: actuallargefolderGUIrow/footer/drop/focuscheckincludingcompactviewport and
no falsezero-iconhit; independentLibraryproposal stillrequiresconfirmation before
code, capacityalso unconfirmed. Language/optionalfeaturesremainonfullledger;
goalACTIVE/incomplete, not fulfilledbythismaintenance.

## Evidence archive and next manual entry

Candidate-specific interactive checks are recorded in
`Docs/FOLDER_VIEWPORT_FIT_GUI_VALIDATION_PLAN.md`; all remain UNEXECUTED.
Immutable checkpoint documents and the two changed source/test inputs are
archived with the verification logs in `.build/verification/20261014/folder-viewport-fit/`.
`ARTIFACTS.sha256` binds the archived files and candidate executable; source
fingerprint verification and diff-check remain separate from GUI acceptance.
