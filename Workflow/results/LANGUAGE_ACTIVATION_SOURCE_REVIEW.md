# Activation language: independent bounded source review

Date: 2026-10-14. Contract: `Docs/INTERFACE_LANGUAGE_SPEC.md` (approved).

## Result

**No concrete source-level bug or regression found in the reviewed activation-language slice.** This is a bounded source-review conclusion, not an execution PASS, full interface-language parity certification, or GUI acceptance. Main had not compiled or executed the new tests at assignment time; this reviewer ran neither.

## Scope and method

Reviewed the frozen activation window, ShortcutRecording, ActivationTextKey, Main's ActivationSettingsCoordinator and ActivationStatusTextKey, the relevant LocalizedStrings accessors/resource-schema entries and en/zh-Hans/ja resource entries, and the two new activation-language test files. Inspected only the relevant AppDelegate bootstrap, settings injection/reopen, readiness and language-presentation call sites to establish the real production snapshot path. Read RTK, repository instructions and the approved specification; the user's explicit waiver supersedes the old workflow. No helper was dispatched, preserving Main + this reviewer + the existing grid worker (maximum three).

Used current-source reads and scoped Git diffs. No reference checkout was read. Other module implementations still owned by the grid worker were not reviewed; calls into their relabel methods are integration boundaries, not evidence that their internals preserve state.

## Evidence

| Concern | Concrete source evidence | Bounded conclusion |
| --- | --- | --- |
| Production selected snapshot before controls | `Sources/PagingPrototypeApp/AppDelegate.swift:194`, `:2034-2041`, `:1810-1816`; `Sources/PagingPrototypeApp/ActivationSettingsCoordinator.swift:76-88`; `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift:259-280` | Bootstrap installs language before settings construction. AppDelegate injects its displayed snapshot, which the constructor retains before creating child views, the window and activation controls. The optional Chinese compatibility default is not the configured production path. |
| Language transition uses the new snapshot for service text | `Sources/PagingPrototypeApp/AppDelegate.swift:2114-2117`; `Sources/PagingPrototypeApp/ActivationSettingsCoordinator.swift:83-88`; `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift:650-691` | AppDelegate replaces its retained snapshot before window relabel calls the retained readiness/login providers. Equal service status can therefore rerender without fabricating a status transition. |
| Retained drafts, controls, selections and bindings | `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift:198-216`, `:229-237`, `:658-680`; `Sources/PagingPrototypeApp/ActivationSettingsCoordinator.swift:77-104`; `Sources/PagingPrototypeApp/AppDelegate.swift:2054-2063` | The activation relabel path changes titles/accessibility and retained menu-item titles, with no activation reload, selection reassignment or callback replacement. Production reopen sets preservation mode (`AppDelegate.swift:1816`) and refreshes accepted language without reloading the activation draft. Preservation inside other settings views remains outside this review. |
| Recording, rejection notice and raw shortcut identity | `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift:187`, `:689-711`, `:738-781`; `Sources/PagingPrototypeApp/ShortcutRecording.swift:94-103`, `:139-143`, `:145-158` | Recording and bare-key rejection are retained semantic flags. Relabel rerenders their text without removing the monitor or changing ShortcutSpec. Preset bindings/tags are independent of translated captions. Unknown key-code descriptions use the selected snapshot; known binding names and modifier symbols remain stable. |
| Production recording/sheet ownership | `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift:191-195`, `:743`, `:766`, `:897-905`; `Sources/PagingPrototypeApp/AppDelegate.swift:2069-2072`, `:2088-2090`, `:2099-2107` | The reviewed seam reports recording, attached sheets and marked text as owners, and recording/sheet completion schedules a retry. This is source evidence for this seam only, not execution or exhaustive ownership certification. |
| Semantic banners and original expiry | `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift:601-623`, `:684-687` | Applied/restored banner kind is retained as a typed key. Relabel updates only visible banner text/accessibility. It does not replace or reschedule the original hide work item, clear the key, change color or revive an expired banner. |
| Validation/login/future-schema errors and native details | `Sources/PagingPrototypeApp/ActivationSettingsCoordinator.swift:161-184`, `:228-248`, `:254-273`; `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift:887-905` | Action-time failures render against the displayed snapshot; every validation, login and readiness branch maps to typed text. Native login error detail is appended verbatim rather than used as a format string. Alerts preserve supplied title/message; only their app-owned close button is localized by the window. Attached alerts finish before deferred presentation. |
| Activation resources and fallback | `Sources/LauncherLocalization/ActivationTextKey.swift:4-96`; `Sources/LauncherLocalization/ActivationStatusTextKey.swift:2-52`; `Sources/LauncherLocalization/LocalizedStrings.swift:46-72`, `:107-109`; `Sources/LauncherLocalization/LocalizationResources.swift:103-105`, `:113-119`, `:129-134` | Static inspection found corresponding activation UI/status entries in all three tables. The integer token names match their typed accessors; selected-table fallback proceeds to English and key-specific safe English values. This does not certify resource parsing, packaging or runtime lookup. |

For **each** of `Sources/LauncherLocalization/Resources/{en,zh-Hans,ja}.lproj/Localizable.strings`, reviewed status/validation/future-version entries at lines 104-126, activation-control/accessibility/recording/banner entries at lines 129-171, unknown-key formatting at line 189, and activation-tab text at line 29. Both validation vocabularies (window helper and coordinator production path) are present. No activation key mismatch, missing translation or placeholder mismatch was observed by source inspection. No preference payload write or schema change occurs in the reviewed relabel/shortcut-formatting code; activation transaction/store behavior itself was not re-reviewed.

## New tests: source coverage, not executed evidence

- `Tests/PagingUITests/ActivationLanguageConsumersTests.swift:41-92` constructs actual unshown controls for English, Simplified Chinese and Japanese and checks titles, accessibility, popup tags and status text. It tests an injected constructor snapshot, not AppDelegate startup execution.
- Lines 94-163 cover retained view/constraint/menu-item identities, represented objects, selection, raw draft and callback preservation; lines 166-245 cover recording rejection/cancellation/acceptance and preset actions; lines 247-302 cover disabled state and retained status-provider rerendering.
- Lines 305-335 cover semantic banner kind/color/visibility; lines 337-352 cover expiry followed by relabel. The latter does **not** time a relabel while the banner is still visible to prove the original deadline; the no-reschedule conclusion above is from source inspection.
- Lines 354-374 cover action-time alert construction, validation and native-detail preservation without displaying a sheet.
- `Tests/PagingUITests/ActivationServiceLanguageTests.swift:7-26` covers every login state, native failure detail and all validation cases across `InterfaceLanguage.allCases`. Lines 29-33 cover only absent-composition readiness, despite the method name mentioning ready. Other readiness branches were inspected in coordinator source, not demonstrated by this test.

## Remaining evidence boundaries

No build, type-check, XCTest, resource validator, application launch/control, process stop, commit or global-memory write was performed. No claim is made about compilation, test counts, real modal/menu timing, live field-editor selection, long-label clipping, VoiceOver, fresh-process persistence, packaged resources, performance, or full UI parity. These remain Main's separate gates. No speculative style findings or unrelated modules are included.

Only this report was written. Procedural note: the initial RTK-document read and narrow memory-registry search were inadvertently issued without the RTK prefix; all subsequent shell commands used RTK. The memory search returned no relevant entry and supplied no review evidence.

## Report-time source fingerprints

These SHA-256 values identify the listed files at report creation; they are not build/resource-runtime acceptance and do not establish stability of the entire shared worktree.

| File | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift` | `a07c8c896c35d94044e58010275964e13480c1ba93501a67f764328a82d129ea` |
| `Sources/PagingPrototypeApp/ShortcutRecording.swift` | `d6116451bb06af5b22601e5d6ac4e87bc64280362e682f5331d199951b6e8f54` |
| `Sources/PagingPrototypeApp/ActivationSettingsCoordinator.swift` | `60baeb75df0d2f3409e72e46c1a5d9bdd2e7269d539096569f6b12d8dceca31a` |
| `Sources/LauncherLocalization/ActivationTextKey.swift` | `533676211fe6d644d582eb1469cccad0a9286b7d2acbfa7a40783bccc9dcf17d` |
| `Sources/LauncherLocalization/ActivationStatusTextKey.swift` | `cb32434f19bea6d0cd52a2ed114bf165d54cb99515b842fc6be26e35a01b9094` |
| `Sources/LauncherLocalization/LocalizedStrings.swift` | `206f9bcdcb2c6498111fa06d5f41608e04c9661ed2d8067f59d0fc73656b0486` |
| `Tests/PagingUITests/ActivationLanguageConsumersTests.swift` | `bed0b64d61b3ee0f4b68df30bafb535b7c9175666bf5999e2826ddfe11566397` |
| `Tests/PagingUITests/ActivationServiceLanguageTests.swift` | `4b16d72352690daadafab40475522e456ebdbbbe5371a1edbbfce8f0c0d2f59f` |
| `Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings` | `5b1bc0ea7185f199bfc46eda3d37ad736d53853d0dceb76021100db0f9f9eeca` |
| `Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings` | `0587a9cd832a5dc3c1f34619150aa54dd91b33b2376092022b97ee5a22ece099` |
| `Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings` | `be8561fe74bb9abd59e5eaeaa84f1ffe1235902fb79f42d735a0b93026561347` |

Recorded at 2026-10-14T04:04:37.243189+00:00.
