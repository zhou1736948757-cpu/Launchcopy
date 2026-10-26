# Appearance persistent-store construction failure — delivery checkpoint

Date: 2026-10-15. Full objective ACTIVE/incomplete. CODE_VALIDATED; independent bounded SOURCE PASS. Main native acceptance covers healthy persistence/configuration only, not a real OS constructor failure.

## Counterexample and two-input repair
A nil failable persistent appearance-store constructor previously became an InMemoryAppearancePreferencesStore returning Saved. Edited controls could display green Applied and change the interface without any persistent owner. Even unchanged/default Apply acknowledged success.

An internal, synchronous MainActor factory seam first preserved the old fallback. The first unannotated closure did not compile; that attempt is retained separately as `seam-compile-failure.log` and is **not** behavioral RED. With closure isolation corrected, the actual configured view/Apply handlers ran: **2 XCTest /5 assertion failures** (green Applied instead of unavailable; displayed values changed). Original, invalid-seam, successful-RED and final input/body snapshots are all retained; no invented intermediate hash.

Only one app source file and one existing test changed:
- `AppDelegate.swift`: retains injected-store precedence and the same dedicated/profile suite constructor. Factory nil clears the coordinator and returns without resetting accepted displayed/queued preferences; no successful in-memory substitute. View has no Apply callback, so its existing translated unavailable handler keeps the draft and rejects both edited/default Apply. Weak/current-view/no-current-coordinator discard restores only previously accepted pending-or-displayed settings; stale callbacks cannot reset a replaced owner/view.
- `AppearanceDraftCloseIntegrationTests.swift`: seven added tests, all six prior retained. Actual constructor/controls/close and explicit store precedence exercised without real defaults/device/window-ordering access. Already persisted queued style is not lost and can finish its existing presentation. Other activation/alias drafts remain untouched.

Appearance store/protocol/coordinator/view/enums/schema/resource tables are unchanged. No false corrupt-data label, new preference/error case, session-only feature, automatic retry/force-flush, global fallback or native fault-injection flag. Other453 of455 frozen inputs unchanged, including prior gesture/Library repairs, Core/PagingUI, scripts/resources.

## Actual verification
| Gate | Result |
| --- | --- |
| Invalid initial seam | compile failure only; retained, no test credit |
| Causal RED | 2 XCTest /5 assertion failures after successful compilation,0.651s |
| Focused | 100 XCTest /0 failures,9.717s; actual close/controller suite13/0 |
| Full | 2700 XCTest /0 failures,53.538s; trailing SwiftTesting zero footer excluded |
| Debug | explicit build exit0 |
| Release/package | unique test-entry candidate assembled, exit0; actual Release build and packaged probe |
| Localization | positive288 keys/signatures ×3 languages; no new negative-probe claim |
| Integrity | all455 final hashes and executable reverified after native work; git diff check pass |
| Independent Bacon | bounded SOURCE PASS, no actionable P0–P3; all455 hashes/exacttwo diffs/RED snapshots verified, Main logs inspected. Reviewer tests/build/native/process executions0; closed. |

## Candidate
`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/appearance-store-unavailable-rc-20261015-r1/LaunchcopyUITest.app`

ExecutableSHA256: `79002dc4eb582358c64dc7937d932c69b090067deb5001eaf9480bcd44b0e473`.
Source455 freeze: `.build/verification/20261015/appearance-store-unavailable/source-inputs-final.json`, SHA256 `1b0e05712f5b14afa0010430792c402d75edeee733b42ed2617ed04ed8b87548`.
Prior candidates remain retained; no install, explicit signing/notarization, publish/commit/reset/clean/process kill.

## Main exact-candidate healthy native gate
Fresh private profile, one independently authored executable fixture; no original app data. PID99555: native controls initially labelsOn/blur18/icon48/font11. Set icon64/font16 and native Apply -> actual Applied feedback. Normal Quit/exactabsence. Genuinely new PID792: native controls restore64/16, labelsOn/blur18 unchanged. RestoreDefaults+Apply ->48/11 acknowledged; no third process after defaults is claimed. Activation/Library remain their test defaults. This verifies the ordinary constructor/configuration/persistence path, not nil frequency or an actual UserDefaults failure.

Wallpaper first loading later ready, new warm process ready/visible. No source-open/OS/root-cause repair is claimed; earlier loading failures remain real. No OS wallpaper/security/privacy setting changed.

## Additional native context actions (existing approved requirements)
Full transaction: `Workflow/results/CONTROLLED_CONTEXT_ACTIONS_NATIVE_RESULTS.md` and `native-context-actions.json`.
- Product context Reveal switched an owned Finder window's selection from a deliberately selected control file to the expected probe bundle. No shell reveal or already-selected-target shortcut. Closed only own new window and compared the returned original Finder header in memory; no original title/path persisted.
- Product context Open created exact probe PID2739 **before** any CUA binding of that fixture; actual static success window, native Quit/exactabsence.
- Launcher's window disappeared after successful launch, while PID792 stayed resident. Normal Finder Open restored the same process/window, then normal launcher Quit/exactabsence. No crash/restart or process kill substituted.
- Second owned Finder reopen window closed; original header restored. Inventory API lacked window IDs, so no complete original-window inventory proof is claimed.

Main bounded native observations, not an independent live Reviewer or physical/performance/VoiceOver claim. Both owned programs stopped; fixture/control file and own test data retained, no applied fault. No ordinary app opened/stopped or user files opened.

## Remaining objective
All three concrete source gaps identified by the current requirement audit now have bounded repairs/evidence (cold gesture enable, Library choices, appearance nil-factory honesty). That does **not** finish the complete LaunchBetter-on-Launchcopy objective. Next useful safe acceptance work includes a populated dense35-member folder/current compact appearance/names/layout transaction, and combined open-Library source-change behavior, with exact workload/candidate identity. Human Chinese/Japanese IME, spoken VoiceOver, matched real-icon physical performance/gesture/energy/120Hz and unresolved >25ms causality stay distinct. Unconfirmed capacity/layout/destructive/usage/extra-gesture branches remain part of full pending scope, not silently deleted. Optional OS-wallpaper source control still requires its separate approval.
