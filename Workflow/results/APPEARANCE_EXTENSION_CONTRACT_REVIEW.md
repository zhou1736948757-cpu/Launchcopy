# Appearance Preferences and Settings Extension Contract Review

Date: 2026-10-13  
Repository: `/Users/mac/Projects/Launch_Copy/PagingPrototype`  
HEAD observed: `319b8cc149a8553adfc3414abaacbe28b59d97ef` plus preserved dirty work  
Review mode: bounded, read-only source inspection; one report output  
Disposition: **one conditional P2 persistence finding; schema 2 extension recommendation pending Main/user approval**

## Scope and evidence boundary

Reviewed the existing appearance value/store/coordinator, native appearance settings section and its shared settings-window wiring, and the already-mounted label/blur/material consumers. The project is a Swift Package targeting macOS 14 with AppKit views, an application composition root, and separate paging/catalog/grid/icon modules (`Package.swift:7–49`). Appearance persistence belongs to the application target; reusable grid consumers receive semantic settings without depending on that target.

No Swift, tests, builds, application, GUI, preference store or image renderer was executed. Regression recipes below are source-derived instructions for Main, **not reproduced runtime failures or passing tests**. Existing test sources were inspected; historical review/stage results do not certify the current dirty tree.

The only file written by this review is `Workflow/results/APPEARANCE_EXTENSION_CONTRACT_REVIEW.md`. No implementation, specification approval, workflow-state update, installation, commit, reset or cleanup is performed. LaunchBetter, BuhoReverseNotes, reverse evidence and assets were not opened. Reference-named specifications were not followed from document links. Existing own-project appearance/material review and repair records supplied continuity only.

There is no duplicated grid/icon geometry survey. Rows/columns remain unapproved and outside this report. Main's page-dot hidden-ancestor accessibility defect and red-test repair are separate work and are not reviewed here.

Latest Main direction: schema **2**, icon **32–64**, font **9–16**, with explicit user confirmation still pending. No icon/type feature implementation is assumed to exist. Recommendations below are an approval input, not an approved specification or authorization to implement.

## 1. Current bounded finding

### F1 — [P2] Equal Apply can report success without repairing a payload that became corrupt after coordinator initialization

**Confidence:** high for the control-flow result; conditional on the persisted payload changing during the coordinator's lifetime.

**Evidence**

- `Sources/PagingPrototypeApp/AppearancePreferences.swift:104–109` caches the initial `loadResult` and `committed`.
- `:113–117` reloads the store only to reject a future version, then decides the equal-draft no-op using the **cached** `loadResult`.
- `:118–123` is the only save/commit/application path; it is bypassed by that no-op.
- `Sources/PagingPrototypeApp/AppearanceSettingsView.swift:90–97` reports successful application for every `.saved` result.
- `AppearancePreferences.swift:62–70` returns `.corrupt` for malformed data and `.loaded(.default)` for a missing payload. Neither is repaired by loading.
- The comment at `:116` expressly excludes explicit corrupt repair from the no-op, but the implementation only recognizes corruption present at initialization.

**Reproducible regression recipe for Main**

1. Use a dedicated synthetic UserDefaults suite and the real appearance store. Save `showsAppLabels = false`, `wallpaperBlurRadius = 42`.
2. Construct the coordinator and reload a native appearance view from its committed state. Record zero application callbacks.
3. Replace `appearance.payload` in that same synthetic suite with `Data("not JSON".utf8)` after initialization. Do not restart the coordinator.
4. Invoke Apply with the unchanged committed draft, either through the view's Apply button or directly through the coordinator.
5. Current source returns `.saved` at line 117, never invokes `save`, leaves the malformed bytes intact, and keeps cached `loadResult = .loaded(oldValue)`. A fresh store still loads `.corrupt`; a fresh coordinator falls back to defaults. Through the native view, the user receives a successful-application message despite that outcome.

The same stale no-op can leave a removed payload absent: applying unchanged nondefault preferences reports success, while the next load returns defaults. This is not a claim that normal single-writer usage currently corrupts preferences; the trigger is explicitly a changed persisted payload during an existing settings session.

**Likely root cause**

The coordinator combines a fresh future-version check with a cached healthy-state check. A successful previous load is treated as evidence that current persistence is healthy.

**Recommended bounded repair**

Decide the no-op using the current load result. A fresh corrupt result must reach explicit save/repair even if the draft equals the in-memory committed value. A missing payload that no longer represents a nondefault committed draft must not be reported as successfully saved without restoring it. Preserve the future-version refusal before any write and preserve the no-application-callback rule when effective values do not change. Do not turn this into automatic repair on load or reopening.

**Affected scope and regression risks**

Coordinator persistence correctness and the native Apply result message. The repair must retain no-op behavior for a healthy matching payload, explicit corrupt repair exactly once, no runtime change on failed saves, and byte-for-byte future payload protection. Multi-process preference synchronization is not specified by this finding.

**Existing regression gap**

`Tests/PagingUITests/AppearancePreferencesTests.swift:105–113` only covers a store already corrupt **before** coordinator construction. `:71–86` covers healthy equal Apply; `:96–103` covers future state at initialization. None covers healthy initialization followed by corruption/removal and an equal Apply.

### Other current-contract results

No additional source-confirmed defect was established in the bounded label/blur/material flow.

| Current behavior | Reproducible source evidence and qualification |
| --- | --- |
| Labels default visible; blur defaults to 18 with integral 0–60 validation | `AppearancePreferences.swift:4–16`. Store rejects invalid preferences before encoding (`:73–80`). |
| Read is nonmutating; corrupt data falls back; future data is protected | `AppearancePreferences.swift:62–80`. Header is decoded before the preference body, so an integer version above 1 is refused even with an unknown body shape. Save rechecks current storage. |
| Persist before committing/applying; failed save leaves committed state intact | `AppearancePreferences.swift:118–124`; test source `AppearancePreferencesTests.swift:71–113`. F1 qualifies the equal-draft shortcut. |
| Native controls stage a draft; defaults stage only; Apply is explicit | `AppearanceSettingsView.swift:21–25,62–110`. Future load disables the four current editable controls. Errors do not invoke runtime application. |
| Reopening uses committed preferences; one settings window owns all sections | `ActivationSettingsCoordinator.swift:67–93`; `AppDelegate.swift:1771–1779`; `ActivationSettingsWindowController.swift:491–510`. Hiding the window does not save appearance. Reopen discards its unsaved draft by reloading it. |
| Shortcut recording stops when leaving Activation | `ActivationSettingsWindowController.swift:583–607`; test source `AppearancePreferencesTests.swift:194–218`. Local monitor also requires a live recording state and the settings window. |
| Real owner supplies startup and live label values | `AppDelegate.swift:175,600,1463,1841–1849,1884–1890`. Renderer updates live/pool pages and reasserts policy on render (`AppCatalogAssembly.swift:219–225,350`); cells preserve binding/accessibility (`AppGridCellView.swift:29–33,172–174`). Ordinary and search presentation use the same renderer (`AppCatalogAssembly.swift:484–486`). Folder members and remaining-member proxy receive the policy (`FolderOverlayView.swift:108–113,160,680,797–805`); the folder title remains visible. |
| Label-only application does not request wallpaper; blur application uses current material policy | `AppDelegate.swift:1884–1890,2279–2282`. No catalog/page reload is called by this method. This is a structural source result, not a measured frame-time guarantee. |
| Reduce Transparency blocks wallpaper work and invalidates a pending image | `LaunchcopyVisualTokens.swift:28–30`; `WallpaperBackdropView.swift:105–123,143–151`. Generation changes precede the early return. Rendering runs through a background loader (`:63–70`). Zero blur selects the sharp/full-requested-resolution route (`WallpaperBackdropProvider.swift:87–93,124–126`). Exact effective-radius bits distinguish cache keys (`:171–191`). |
| Current material mapping stays separate from appearance persistence | `AppDelegate.swift:1864–1879,2203–2213`; `LaunchcopyVisualTokens.swift:50–55`; `FolderOverlayView.swift:297–314,656–667`. Ordinary chrome remains unchanged; transparency requests actual opaque chrome/panel/backdrop fills; contrast separately strengthens boundaries/footer. Material updates reject visual-only/torn-down overlays and retain the collapsed-clear exception. |
| Owner invalidates an unaccepted title before accessibility-driven focus transfer | `AppDelegate.swift:1867–1875,1555–1568`; mounted-owner regression source `FolderRenameAssemblyTests.swift:445–467`. Direct material-consumer updates preserve an editor; the full owner notification intentionally cancels its unaccepted draft. These are different paths, not contradictory requirements. |

The existing label test source explicitly permits label changes during visual-only presentation (`AppearanceLabelsTests.swift:224–254`). Material immutability must not be generalized into a new prohibition on label updates. No such redesign is proposed.

## 2. Recommended schema 2 compatibility contract

The proposed icon/font bounds below come directly from Main's latest direction and remain **pending explicit user confirmation**. The inspected appearance model currently has only the two original fields (`AppearancePreferences.swift:4–16`).

### Envelope and value fields

Retain the dedicated suite, payload key and single encoded Data write:

- Production suite: `com.launchcopy.appearance`.
- Key: `appearance.payload`.
- Test isolation: continue using `uiTestProfile.appearanceSuiteName` (`AppDelegate.swift:1841–1844`; `UITestProfile.swift:28–38`).
- Proposed current schema version: **2**; readable versions: **1 and 2**.
- Keep material/accessibility flags runtime-owned. Do not persist system flags, rows, columns, page indices, grid capacity, catalog identities, image data, or workspace layout in this extension.

Suggested persisted field names and types:

| Field | Stored type | Default | Validation |
| --- | --- | --- | --- |
| `showsAppLabels` | Bool | true | Required Boolean in both supported schemas. |
| `wallpaperBlurRadius` | Int | 18 | Existing inclusive 0–60; retain existing semantics. |
| `iconPointSize` | Int | 48 | Proposed inclusive **32–64**, pending confirmation. |
| `labelFontPointSize` | Int | 11 | Proposed inclusive **9–16**, pending confirmation. |

The proposed default sizes match current cell appearance (`AppGridCellView.swift:24,93`); this is a default-compatibility observation, not a geometry/fit approval. Main must approve exactly which captions receive the font preference. Existing folder member-count text uses a separate font (`:100`), and the open-folder title is a different semantic control. Do not silently extend a caption preference to title editors, settings chrome or unrelated UI.

Illustrative proposed schema 2 payload:

```json
{
  "schemaVersion": 2,
  "preferences": {
    "showsAppLabels": false,
    "wallpaperBlurRadius": 42,
    "iconPointSize": 48,
    "labelFontPointSize": 11
  }
}
```

### Load/save decision matrix

| Stored state | Recommended load behavior | Recommended write behavior |
| --- | --- | --- |
| Absent key | In-memory defaults, no creation on read. | Explicit changed Apply writes complete schema 2. Healthy equal default Apply can stay a no-op. |
| Valid schema 1 | Decode/validate its two required original fields; preserve both exactly; supply only new icon/font defaults in memory. No migration write on load/reopen. | Changed accepted Apply writes complete schema 2. Equal Apply may leave valid v1 bytes untouched; version upgrade alone must not introduce a runtime callback. |
| Invalid schema 1 | Existing corrupt fallback, retain bytes. Missing/null/wrong-type original fields or out-of-range blur must not become a valid defaulted v1 payload. | Explicit valid Apply can replace corrupt bytes with schema 2. |
| Valid schema 2 | Require all four fields and validate all ranges before exposing loaded preferences. | Save a complete schema 2 payload after validation. |
| Invalid schema 2 | Corrupt fallback, retain bytes. Missing/null/wrong-type/new out-of-range values must not silently default or clamp during decode. | Explicit valid Apply repairs it; invalid drafts preserve original bytes. |
| Integer version > 2, regardless of preference-body shape | Return future-version result before interpreting preferences; runtime defaults and read-only settings. | Reject equal/changed/defaults Apply; preserve exact stored Data. Recheck before write, not just at initialization. |
| Unsupported older version (0/negative), malformed JSON/header or wrong stored object type | Corrupt result, retain original object/data during read. | Follow explicit corrupt-repair policy; no automatic rewrite. |

Backward compatibility means **the new application reads valid v1**, while the current v1 application refuses v2 as future. It does not mean a v1 application can edit new fields.

Keep version-specific decoding at the persistence boundary, such as a two-field v1 DTO mapped to the expanded value and a complete v2 DTO. A default argument on a Swift initializer does not give synthesized `Decodable` missing-key migration behavior. Simply adding nonoptional fields to the existing synthesized model will make valid v1 loads fail (`AppearancePreferences.swift:4–16,50–53,67–69`).

Do not stamp new fields as schema 1. The current v1 reader has no place to retain unknown preference keys, and its writer emits only the two known fields (`:50–53,76–79`). A schema-1 payload with appended icon/font keys can therefore be loaded and later overwritten by a label/blur edit, losing those keys. Bumping to 2 activates the old application's existing refusal instead.

Future protection here is based on a valid integer version header. Unknown keys within an already-supported version are not evidence of a future version under the current contract. Future incompatible/additive persisted features must increment the version; this review does not promise arbitrary same-version unknown-field round trips or introduce a generic JSON preservation layer.

### Validation and commit semantics

- Use one value-level validator for the real store, in-memory store and coordinator. Combine the original blur rule with the proposed icon/font bounds once approved.
- Reject invalid values as a whole. Do not silently clamp stored/committed preferences or partially accept labels while rejecting icon/font.
- Use integral persisted units. Wrong types, fractional numeric values, unrepresentable integers and missing/null required v2 keys must fail decoding/validation; test the decoder's actual behavior rather than assuming initializer defaults apply.
- Preserve accepted state and stored bytes on validation/encoding/future-version failure. Keep unrelated preference keys and suites untouched.
- Load/reopen never repair or migrate storage. Explicit Apply alone may write.
- Successful equal effective values require no owner callback, including v1 default augmentation and explicit equal-default corrupt repair. F1's persisted-state mismatch must still be repaired rather than hidden by this rule.
- Header-first future detection remains ahead of full v2-body decoding. Raising only the future cutoff without introducing a v1 decoder is insufficient.
- The existing `.saved` result means the store accepted a UserDefaults write; it is not evidence of synchronous disk durability. A real restart check remains Main-owned.

## 3. Native settings extension hazards to address when approved

These are concrete integration risks in existing code, **not defects in an already-implemented icon/font feature**.

| Existing seam | Required extension behavior |
| --- | --- |
| `AppearanceSettingsView.swift:83–85` reconstructs a fresh value from only checkbox and blur controls. | Update the draft as a whole value, including both new controls; retain all staged fields when any single control changes. Merely adding defaulted value properties would reset new loaded preferences whenever labels/blur change or Apply calls `controlChanged`. |
| `:101–110` defaults/reload synchronize only the current controls. | Defaults stage all four approved defaults without saving. Reload/reopen populate all four controls from committed state. Close without Apply preserves the committed payload. |
| `:66–71,93–97` has a two-control future lock and blur-only validation text. | Disable new controls for future storage too. Keep refusal/error messages accurate for icon/font failures; a font error must not say only blur is invalid. Preserve edits on a failed save. |
| `AppDelegate.swift:1773–1776` reloads the section from coordinator state on every settings opening. | Retain the committed/draft boundary for the expanded value. Do not add per-slider persistence, render callbacks or separate independent saves. |
| `AppearancePreferences.swift:15,89–92,113–119` currently validates blur only. | Expand every validation entry point consistently; avoid real-store versus in-memory/coordinator disagreement. |
| `AppDelegate.swift:1885–1890` updates labels and conditionally refreshes wallpaper only. | After feature implementation, changing icon/font alone must reach the approved consumer seam; preserving only these existing assignments would save new preferences without applying them. Retain blur-only wallpaper work and label-only no-rebind behavior. Consumer mechanics/geometry are owned by the other agent. |

A schema change cannot itself establish UI application or viewport suitability. No proposed ranges are certified as fitting the grid by this review.

## 4. Regression handoff to Main

No tests are added or run by this review. Use dedicated synthetic suites; never seed production preferences.

| Regression | Required assertions |
| --- | --- |
| F1: corruption/removal after healthy initialization, equal nondefault Apply | Actual save/repair occurs; fresh store reads original committed values; UI success corresponds to repaired persistence; no owner callback for unchanged effective values. Repair once, then no-op. |
| Healthy equal Apply | No save and no callback when current stored values still match. |
| Golden v1 payload | Example `{"schemaVersion":1,"preferences":{"showsAppLabels":false,"wallpaperBlurRadius":42}}` loads false/42 and default icon/font; bytes unchanged by read/reopen/equal Apply; changed Apply writes full v2. Test 0/60 blur boundaries too. |
| v1 corruption | Missing/null/wrong-type original keys and invalid blur remain corrupt; new-field migration must not erase corruption by defaulting old fields. |
| Complete v2 round trip | All four nondefault values survive a fresh store/coordinator. Unrelated key/suite contents remain unchanged. |
| Approved range boundaries | If confirmed: icon 32/64 and font 9/16 accepted; 31/65 and 8/17 rejected; invalid save leaves stored state and committed state unchanged. Include wrong-type, fractional, huge integer, missing/null fields. |
| Downgrade protection | Current v1 cutoff treats version 2 as future and refuses save; do not regress header-first ordering when editing the store. |
| Future >2 with opaque body | Example `{"schemaVersion":3,"newerField":[1,2,3]}`; defaults only in memory, all editable appearance controls disabled, equal/changed/defaults writes refused, exact bytes preserved. |
| Future payload introduced after coordinator/view creation | Current store recheck refuses write and owner callback; no success message. UI need not poll persistence, but must not bypass refusal. |
| Native draft collection | Seed nondefault icon/font, change only labels or blur, then Apply: new fields survive. Also change only icon/font, exercise Defaults, failed save, close/reopen and repeated Apply. |
| Mounted owner forwarding | Persist via the real coordinator/view callback seam, check owner receives complete preferences; verify existing label paths and blur dispatch retain their scoped budgets. Icon/font consumer/geometry assertions are assigned elsewhere. |
| Existing regressions retained | `AppearancePreferencesTests.swift:23–146,194–256`; `AppearanceRendererLabelsTests.swift:21–129`; `AppearanceLabelsTests.swift:25–254`; `WallpaperBackdropControllerTests.swift:50–159`; `WallpaperBackdropProviderTests.swift:53–118`; `LauncherChromeMaterialTests.swift:11–70`; `FolderMaterialPolicyTests.swift:133–234,276–332`; `FolderRenameAssemblyTests.swift:445–467`. These are inspected source assertions, not execution evidence. |

Settings and renderer tests currently exercise separate parts of the path. The label-only owner test (`AppearancePreferencesTests.swift:238–256`) wires wallpaper but not a content assembly or open folder. A focused mounted-owner test would close that integration gap; absence of such a test is not itself a second product defect.

Main owns approval of schema fields, bounds and caption scope, implementation and fixes, focused test execution, build/full-suite decisions, exact-candidate native settings acceptance and restart durability evidence. This review makes no whole-product, physical-performance or GUI acceptance claim.

## Reviewed input identities

SHA-256 captured after source inspection at approximately **2026-10-13T13:32Z**. These identify the reviewed dirty files, not a built candidate. The report's final check compares them again; later Main edits require line/hash revalidation. File-level hashes do not imply every line of a larger file was reviewed.

```text
c214f04f42748e21bcf2a6143f367685e117c39984afca24a96aea6afe51f693  Package.swift
6928c4ebd8edcabc637e028d24790450a052b739117f0b0ef9f6ad6b45b7bcfc  AGENTS.md
198d9f3e604359ab6ccf6b0336485f061613481edb4877115eb32a9b5e1caeca  Sources/PagingPrototypeApp/AppearancePreferences.swift
e51d7be699bcc63e81c5c3de8faccb1f0f6636b81d1f633addb5b1366aa8d8ab  Sources/PagingPrototypeApp/AppearanceSettingsView.swift
a1edb0d4d7aa3af77f37ebc30d59f66af067d68fbda3ee00fd87acc61303b489  Sources/PagingPrototypeApp/ActivationSettingsCoordinator.swift
f84694b14a2d9b72e370b7ad9673b587c5597f6f1285abc99335991a262b06d1  Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift
440dcd426d16b4502288d255bfed39975617d6f223718e38350541ca59c5fd76  Sources/PagingPrototypeApp/AppDelegate.swift
020029f817b44021912e26b49f08f4c3e7d8cbee70edf487fbb6d9c7865dceb4  Sources/PagingPrototypeApp/AppCatalogAssembly.swift
63f4958112f158f66fd888853f369adb80077971d90008272f77cc6b94fe1a3a  Sources/PagingPrototypeApp/WallpaperBackdropProvider.swift
70653541a442b62a1ad2115ab1a19115c283772bd205c1e0e09a07335495cb79  Sources/PagingPrototypeApp/WallpaperBackdropView.swift
b0e33cdf67e3a53385026f39e67508abaeecce3e185ff601f5a54e85ab4f2220  Sources/PagingPrototypeApp/LaunchcopyVisualTokens.swift
2140b8488035f4ecd5560e1ef329d697fbcb30a50fa3559f9d9f9d4c759acb79  Sources/PagingPrototypeApp/UITestProfile.swift
a00c0c190ac247ab05d23509572c6a2f432eb3090e49d729ab46616ef3f585e7  Sources/PagingPrototypeApp/PageDotsView.swift
52b7fa063c66fa397f7c1b74af73b921aa3f38c6f9335dec88d284537e439874  Sources/AppGridUI/AppGridCellView.swift
e4ad35b405f9a2e750b723496f312545cc43d4facdf5e5bf62d576e0edac46af  Sources/AppGridUI/AppGridPageView.swift
c15663ae78b97b256685095aea74a2a08c57df19b22c96d4663a0fde58368c51  Sources/AppGridUI/FolderOverlayView.swift
361beac3483c812c227ca3bed4dc27c90ee5124550f2a6736217569082377e47  Sources/AppGridUI/AppGridSearchPresentationController.swift
45723d439e3bc88608a6afc364cc741ebd6629f602634043997236e1ad07af52  Tests/PagingUITests/AppearancePreferencesTests.swift
f1f8881fd26f5126f48b298fb557ba92b3ce728d38702d7725b2f4f3708569c5  Tests/PagingUITests/AppearanceRendererLabelsTests.swift
5e355dae15eee44bda526022d06c6091d12f10157191e607b242362aeec5de4a  Tests/PagingUITests/LauncherChromeMaterialTests.swift
74a2864c88d5bb3fa0db5926a28162ca9462a8bbbc28b3486a4d32e464a31d4a  Tests/PagingUITests/WallpaperBackdropControllerTests.swift
ef6204ba15b631ce2c0b2ab1333c7e25ffd23a96d78f6c0a49e93f5ff705c976  Tests/PagingUITests/WallpaperBackdropProviderTests.swift
385d8c83551260c29c24553b51f574aa341557f26b710159256a40c424bc4bed  Tests/PagingUITests/FolderRenameAssemblyTests.swift
05b4b77236bf3ac27da52e8dd1a48e690ea16b093c5084b9fff7854f45887147  Tests/AppGridUITests/AppearanceLabelsTests.swift
b04b92ddb453ea195b17598620b28f3764d3ddbacea86f3daca746ee57925746  Tests/AppGridUITests/FolderMaterialPolicyTests.swift
61a4056be4671b344fe993626b7d1a3bf0d484e039edbffe05d40b96e2cd4fbe  Docs/GRID_APPEARANCE_AND_CAPACITY_PROPOSAL.md
c791d4579f5fc9c32ce1cdb9b27ae9c4807d17290babee51167c40ea8e831217  Docs/ACCESSIBILITY_MATERIAL_REPAIR.md
3e4751888371d60c008e893aa1639ca71d1a755a67645ac1bacd2cbf9134208a  Docs/APPEARANCE_SLICE_REVIEW.md
cdc9816c8bb0ade492de5fe3924c4eabb79792b74adc57a61fbbab36b7d6cbc1  Docs/ACCESSIBILITY_MATERIAL_REVIEW.md
98137d02a3aaead7a591f2f5ba3df674c92a0604f2161eaca39a297544b32a82  Workflow/stage-summaries/2026-10-13-appearance-parity.md
```

Final read-only integrity check: **29/30 captured file hashes unchanged**, including
all appearance preference/settings, owner, label, blur and folder material inputs.
Only `PageDotsView.swift` changed concurrently, consistent with Main's separately
announced repair; its earlier hash above is historical and conveys no current
review verdict. That repair was not reopened or audited here. Git status retained
all pre-write entries and gained this report plus the separately owned
`Workflow/results/ICON_TYPE_INTEGRATION_SURVEY.md`; this review created only its
assigned report and did not read or modify the other agent's output.

