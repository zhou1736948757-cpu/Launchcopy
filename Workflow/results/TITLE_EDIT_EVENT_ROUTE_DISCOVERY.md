# Title-edit outer event route discovery

Date: 2026-10-15. Scope: source-only discovery in PagingPrototype (SwiftPM/AppKit). Role: bounded read-only Explorer; human waiver of legacy Chief applies; Main + Explorer = 2, ceiling = 3; no agents spawned. Main retains edit-admission analysis and actual native OS/Dock activation controls.

## Conclusion and evidence boundary

**Source-proven:** after title completion clears `KeyboardFocusController.isEditingTitle`, a Return/Enter delivered to that controller can activate a member while the folder remains open. Neither a top-level selection nor a visible member focus ring is required. The selected internal index, or index zero if nil, must resolve to an existing member; application opening then requires the shared launch validations below.

**Not proven:** that the anomalous native Return reached this route, that the same event both completed editing and activated a member, or that a particular end-edit notification/movement occurred. No explicit replay/forward-to-keyboard call exists in the inspected title completion/window code. AppKit dispatch between these source entry points remains a runtime evidence gap.

The supplied native observations are context, not observations made by this discovery: inactive AX editor stays draft until first Escape then commits; active blue-field normal typing/AX set followed by Escape cancels; active Tab/Return behaves normally; the last background AX restore/Return also displayed Info-only member05 app-open failure. The supplied 454-input / 5280... candidate and 2672/0 result, and already reviewed editor-notification fix, were not rerun or independently tied to the running executable here. The reviewed fix is not established as the native anomaly's cause. No real title/input, application identity/path, or private runtime logs are reproduced.

## Minimal route (repository-relative file:line references)

```text
QuitOnBlankClickWindow.sendEvent(event)                 AppDelegate.swift:3764
  library mode? -> native super.sendEvent; Escape seam :3767-3773
  otherwise Escape-only drag/exit-visual interception  :3800-3807
  Return has no custom window interception
  -> super.sendEvent(event)                            :3940
     [AppKit dispatch/ordering: runtime gap]
     +-> title field-editor delegate                   FolderTitleEditor.swift:61
     |   insertNewline -> commit -> true                :64-66
     |   cancelOperation -> cancel -> true              :67-69
     |   endEditing(cancel movement) -> cancel          :77-85
     |   endEditing(other/missing movement) -> commit
     |   -> owner commit/cancel -> finish               AppDelegate.swift:1802-1842
     |      dismiss -> unmount -> endTitleEditing(false)
     |      -> conditional makeFirstResponder(keyboard)
     |
     +-> KeyboardFocusController.keyDown                KeyboardFocusController.swift:137
         OR performKeyEquivalent                       :177
         !isEditingTitle + Return/Enter + open folder
         -> activateInnerMember                        :369-374
         -> onActivateMember -> launchMember            AppDelegate.swift:964,1668
         -> makeMemberLaunchCell(current servedRevision):1679
         -> AppLaunchController.handleCell              :1680
         -> binding/revision/hidden/catalog/file checks AppLaunchController.swift:150-168
         -> launcher.openApplication -> NSWorkspace.open:168,39-40
```

`AppDelegate.swift` and the other abbreviated app filenames above are under `Sources/PagingPrototypeApp/`. The actual member-launch function is `launchMember`; “memberAppLaunch” is used here as the requested semantic endpoint, not a literal symbol found in these files. `QuitOnBlankClickWindow` has **no `keyDown` override** in its declaration (`AppDelegate.swift:3725-3950`); window-level keyDown behavior beyond its `sendEvent` hook is inherited. The controller supplies the custom keyDown implementation.

## Source order and admission conditions

1. **Window delivery is a prerequisite, not established by AX.** Outside library mode, custom mouse delivery/hit-test branches do not route Return; only Escape has a custom keyDown interception. That Escape hook consumes the event when `handleEscapeDuringDrag()` reports an active drag or retained folder-exit visual (`AppDelegate.swift:3516-3524,3800-3807`). Return otherwise reaches `super.sendEvent`; this does not prove which responder/command receives it.

2. **Editor command delivery consumes its recognized command.** `FolderTitleEditor.control(...doCommandBy:)` commits newline or cancels Escape and returns true, even if terminal completion already occurred (`FolderTitleEditor.swift:61-73,91-102`). Tab/default returns false to AppKit; if AppKit ends editing, any non-cancel movement commits (`:77-85`). This code does not inspect marked text itself; receiving the selector/notification from the native text system is a separate premise.

3. **First terminal completion wins.** A first end-edit notification with integer `NSCancelTextMovement` cancels; other/missing/unusable movement commits. Both `commit()` and `cancel()` set `didFinish` before callbacks (`FolderTitleEditor.swift:77-102`). Therefore a hypothetical earlier non-cancel completion can prevent a later Escape from undoing it; a later cancel movement cannot retroactively reverse a completed commit. This is a conditional source consequence, not a finding about the actual notification payload/order.

4. **Owner teardown removes the controller's edit guard before optional focus restoration.** Callbacks bind to the rename token (`AppDelegate.swift:1781-1793`). Commit validates the captured token/context and current layout/store/catalog; invalid current targets also finish the session (`:1802-1810`). Valid rename calculation calls finish before committing the renamed layout (`:1812-1819`); cancel also calls finish (`:1824-1825`). Exact finish order (`:1829-1842`): capture editor/window and `ownedResponder` -> nil rename context/editor owner -> `dismissWithoutCallback()` -> unmount -> `endTitleEditing()` -> clear keyboard title callbacks -> clear owner `isTitleEditing` -> refresh readiness -> attempt keyboard first-responder restoration only if `returnFocus && ownedResponder`. `ownedResponder` means `currentEditor() != nil` OR `window.firstResponder === editor`; it is not a key/active test. The return value of this restoration `makeFirstResponder` call is unused. Unmount removes the view; it has no explicit application callback/focus call (`Sources/AppGridUI/FolderOverlayView.swift:543-548`). Synchronous AppKit consequences of removal remain unobserved here. `endTitleEditing()` itself only sets false (`KeyboardFocusController.swift:438-440`); it does not clear `innerFocusIndex` or close the folder.

5. **Controller admission is local state, not actual text-input inspection.** In keyDown, Escape is handled first; otherwise `isEditingTitle == true` delegates to `super.keyDown` and returns without this controller's activation (`KeyboardFocusController.swift:137-147`). In key equivalents, Command-F precedes the edit guard, then editing returns false (`:177-185`). After the guard clears, key codes 36/76 activate (`:162-170,191-200,540-553`). These paths contain no independent NSTextInputClient/NSTextView/currentEditor/marked-text check, no key-window/app-active check, and no repeat-event suppression. Modifier filtering is only explicit for Command-F (`:545-546`); activation recognition uses the key code alone. Absence of these checks does not establish a defect or authorize a new policy.

6. **Folder branch bypasses top-level selection requirements.** Pointer-navigation suppression applies only when no folder is open (`KeyboardFocusController.swift:148-152,186-190`). With a folder open, activation proceeds even during pointer navigation. `activateInnerMember()` requires `openEntry`, a valid `innerFocusIndex ?? 0`, and a live callback (`:369-374`). Mouse/keyboard folder-open seams initialize index zero and clear top-level focus (`:292-297,308-315`). A visible inner ring is not read by activation. Finishing title editing preserves the internal index, so this need not select the first member if earlier navigation selected another. No source evidence here maps the supplied member05 fixture to an actual index/event.

7. **Member activation is not successful application opening.** Production callback wiring is `onActivateMember -> launchMember` (`AppDelegate.swift:964`). That method needs controller, assembly, served revision, then synthesizes a cell using the current served revision (`:1668-1680`; `AppCatalogAssembly.swift:615-627`). `AppLaunchController` validates binding/AppID, served revision equality, not hidden, current catalog URL, and file existence before calling the launcher (`AppLaunchController.swift:150-168`). This member path passes no expected URL. It does not recheck title-edit state, OS focus, or event provenance. Its synthesized current-revision token is not evidence of the originating key's revision/ownership. A false launcher result becomes `.failedToLaunch`; feedback maps that to `.launchFailed` (`ApplicationActionFeedback.swift:12-17`; `AppDelegate.swift:173-183`). A displayed notice alone neither identifies the event entry path nor proves a successful open.

## Lifecycle context only

`backgroundUITestMode` explicitly does not provide background input (`LauncherWindowController.swift:41-43`); its present branch orders the window back and returns (`:204-212`) before the production key/order-front/activate calls (`:231-235`). This establishes no OS key/active state for a later AX operation.

The existing key-window observer calls `rebuildFirstResponder` (`AppSearchController.swift:74-83,265-284`). Its mode provider returns the title editor only when it is mounted and has a current field editor, otherwise the keyboard controller for an open folder (`AppDelegate.swift:972-981`). Thus a mounted title field lacking `currentEditor()` does not itself win that provider. **Restoration to keyboard alone is insufficient to explain a launch while `isEditingTitle` remains true.** An end/clear of that state before controller activation would additionally be needed. Actual observer firing, responder changes, end-edit notifications, and successful restoration in the native anomaly have not been established. No edit-start admission audit or native activation controls were performed here.

## Supported counterexamples and limits

| Claim being limited | Source-supported counterexample / evidence boundary |
| --- | --- |
| Every Return during title editing launches a member | Editor newline returns true; controller editing guard prevents its own activation in both entry methods. `PointerPageFocusTests.swift:319-341` directly exercises the controller edit guard, but does not exercise a native title field or assert member callbacks. |
| No outer selection/ring means Return cannot launch | Folder branch precedes top-level focus lookup; internal index defaults to zero. `FolderIntegrationTests.swift:581-640` asserts no outer focus/no initial inner ring after opening. These assertions plus source admission establish the counterexample; this test does not itself send a launch Return in that state. |
| Pointer-navigation guard blocks folder Return | `PointerPageFocusTests.swift:288-308` directly calls keyDown Return and key-equivalent Enter and expects member callbacks while pointer navigation is active. These are two explicit method invocations, not proof one native event calls both. |
| Escape always cancels regardless of prior completion | Cancellation wins only when first; terminal guards block later completion. A live non-cancel end-edit callback commits by design. No actual movement/order can be inferred from the physical Escape label. |
| The reviewed cancellation fix proves the native anomaly resolved/caused | `FolderTitleEditorCompletionTests.swift:51-118` injects notifications/commands, including missing/unusable metadata; it cannot prove what native AppKit delivered. Supplied active Escape success also limits any universal failure claim. |
| App-open failure proves title command replay or successful launch | Shared member launch can fail after validation; notice has no input-route attribution. `FolderIntegrationTests.swift:220-258` covers synthetic launch cells/stale rejection, not native event provenance. |

## Exactly missing runtime evidence

To distinguish supported admission from the native anomaly, the existing evidence lacks a correlated sequence for the anomalous interaction:

- Whether Return/Escape entered this owned window at all, and its order relative to title completion, key-window restoration and any second/repeated key event. A neutral event correlation token, key code, repeat/modifier bits and before/after ordering would distinguish one-event redispatch from a later independent Return. No characters or title text are necessary.
- Actual `NSApp.isActive`, `window.isKeyWindow`, event/window ownership equality, and first-responder role/identity equality at delivery and restoration; whether `editor.currentEditor()` existed and whether each responder request succeeded. AX focused/set/press/raise is not a substitute. Main owns collecting/controlling native activation evidence.
- Which title callback arrived first: selector versus `controlTextDidEndEditing`, whether the movement key was absent/unusable/cancel/other, whether the callback belonged to the current session, and whether `didFinish` was already terminal. This is the essential missing evidence for first Escape committing. The current source contains the reviewed fix; no actual movement value is assumed.
- Whether/when finish cleared the keyboard edit flag relative to Return, whether restoration was attempted/succeeded, and whether keyDown, performKeyEquivalent, the title delegate, or none received the event. The source does not establish AppKit's order or replay.
- At member callback/launch attempt: folder-open state, member-index bounds/default status, edit-guard state, and a neutral call-path marker correlated to the key. Then the shared outcome and whether the launcher API was invoked/returned false. These distinguish activation callback, validation rejection and `.failedToLaunch`; Info-only UI does not supply the chain. Avoid member identities, real titles, URLs and paths in evidence.

These are evidence requirements, not an authorized instrumentation/implementation proposal. No new activation policy is recommended.

## Possible scoped test locations (not changed or run)

- `Tests/PagingUITests/PointerPageFocusTests.swift:288,319` and `KeyboardFocusControllerTests.swift:101,112,120`: local keyDown/key-equivalent admission, edit guard before/after explicit endTitleEditing, open-folder index validity, and separation of distinct invocations. Existing direct event calls cannot reproduce native dispatch ordering.
- `Tests/PagingUITests/FolderTitleEditorCompletionTests.swift:51,63,96,121,154,177`: controlled completion-order/metadata/idempotency cases. These establish consequences of supplied callbacks, not actual notification movement.
- `Tests/PagingUITests/FolderRenameAssemblyTests.swift:119,178,191,302`: production completion wiring, old-session isolation and native responder-transfer seam. The `:302` test requests another field as responder without manually injecting a notification; it still does not establish inactive real-key routing or same-event replay. Main retains begin-edit admission scope.
- `Tests/PagingUITests/FolderIntegrationTests.swift:220,243,581` and `KeyboardLaunchTests.swift:189,203`: member launch validation/nonfatal failure and selection context. Top-level no-focus tests do not prove no member launch with an open folder.

Confidence: high for the conditional source route and guard/order descriptions; undetermined for the anomalous native event path, notification movement and root cause. This is discovery, not a runtime PASS or a repair verdict.

## Execution disclosure

Only this report was written. No product/tests were modified; no Swift/test/build/UI/process-control commands or agent dispatch were performed. No reference assets or excluded-project file contents were opened. Initial discovery mistakenly used an ancestor-wide filename search, which returned excluded-tree AGENTS pathnames; subsequent reads/searches were confined to the requested project and instruction/memory files. The first instruction-read/inventory shell calls were unprefixed; after reading RTK, all shell commands used `rtk proxy`. These are procedure deviations, not evidence about product behavior. The memory-registry keyword check had no relevant match and contributed no conclusions.
