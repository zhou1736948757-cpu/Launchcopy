# Language menu consumers — Worker A handoff

Status: implementation written; source inspection only. No compilation, XCTest,
menu tracking, application launch or runtime/VoiceOver acceptance is claimed.
Main performs serial verification after the shared source freeze.

## Scope and baseline

Read `/Users/mac/.codex/RTK.md`, `Docs/INTERFACE_LANGUAGE_SPEC.md`,
`Workflow/stage-summaries/2026-10-14-language-status-menus.md` and project
`AGENTS.md`. The user waived the old Chief workflow and assigned disjoint paths.
Existing AppKit, SwiftPM 5.9, XCTest, package structure and dirty work are retained.
The two existing controllers were already untracked at entry; they were edited
in place, without replacing their binding or policy implementations.

## Every changed path

- `Sources/PagingPrototypeApp/AppContextMenuController.swift`
- `Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift`
- `Sources/LauncherLocalization/MenuTextKey.swift` (new)
- `Tests/PagingUITests/MenuLanguageConsumersTests.swift` (new)
- `Workflow/results/LANGUAGE_MENU_CONSUMERS.md` (new, this report)

No AppDelegate, shared schema, resource table, Package.swift, other test, global
memory, workflow state or reference-tree changes belong to this worker.

## Integration hooks owned by Main

Both controllers expose the same hook, with a legacy-compatible nil default:

```swift
public var interfaceStringsProvider: () -> LocalizedStrings? = { nil }
```

Main must assign each hook to its **current displayed** immutable strings snapshot,
not accepted or pending language state. Keep the existing organization submenu
closure and owner tracking. Each successful context menu construction consults
its provider once; each available assignment submenu construction consults its
provider once, irrespective of destination count. Invalid/unavailable menus do
not consult their provider. The parent captures its snapshot before calling the
existing organization provider. Main's safe native-menu owner boundary keeps the
displayed snapshot consistent throughout this synchronous nested construction.

Consumers require Main's typed snapshot API:

```swift
public func menuText(_ key: MenuTextKey) -> String
```

`MenuTextKey` is public, String-backed, CaseIterable and Sendable, with public
`englishFallback: String`. Main owns registering all cases in the resource schema,
strict required-key validation and the three tables. No dynamic arguments or
placeholder signatures are needed. The shared `menuText(_:)` API was observed
in the live source during static review; its compiled/resource behavior is not
verified here. Neither consumer branches on language or reads OS locale.

## Exact resource keys and authored text

These are the requested exact values, including the Unicode ellipsis `…`.
English values also equal the key-specific `englishFallback`.

| Swift case | Resource key | en | zh-Hans | ja |
| --- | --- | --- | --- | --- |
| launch | menu.launch | Open | 打开 | 開く |
| setAlias | menu.setAlias | Set Alias… | 设置别名… | 別名を設定… |
| restoreOriginalName | menu.restoreOriginalName | Restore Original Name | 恢复原名 | 元の名前に戻す |
| hideApp | menu.hideApp | Hide App | 隐藏应用 | アプリを非表示 |
| revealInFinder | menu.revealInFinder | Show in Finder | 在 Finder 中显示 | Finderで表示 |
| organizeApps | menu.organizeApps | Organize App | 整理应用 | アプリを整理 |
| moveToFolder | menu.moveToFolder | Move to Folder | 移动到文件夹 | フォルダに移動 |
| moveToTopLevel | menu.moveToTopLevel | Move to Main Page | 移到主页面 | メインページに移動 |

Nil-provider behavior uses the preexisting Chinese literals without constructing
or looking up a fallback resource snapshot, preserving old callers even if the
resource bundle is unavailable. Explicit snapshots use Main's normal validated
English/table fallback behavior. Native menu item accessibility labels equal the
captured title, including verbatim/disambiguated folder titles. These controllers
had no app-owned help/tooltips to translate; none are introduced. The formerly
empty context menu title remains empty. Assignment submenu title is localized.

## Preserved invariants

- Existing `management.*` and `folderAssignment.*` identifiers, action selectors,
  explicit targets, represented-object Binding classes and callback signatures.
- Catalog revision, complete cell token, weak cell lifetime, canonical URL,
  hidden/read-only and assignment reference/snapshot/layout checks; owner-provided
  busy/protection and final `validate` callback.
- `autoenablesItems = false`, item order, key equivalents, availability and
  mutation enablement. No Binding is rebuilt to relabel a retained menu.
- Canonical folder order, owner exclusion, optional move-out separator and action.
  Duplicate user titles retain the existing ordinal/collision algorithm. No user
  folder title, alias, application name, identity or persisted layout is translated.
- Existing actions do not read the language provider. Already-built menu objects
  retain title/AX/binding values when the provider or displayed snapshot changes;
  only subsequent menu construction picks up a new snapshot.

## Bounded native XCTest source added (not executed)

`MenuLanguageConsumersTests` defines 12 test methods. They construct real unshown
NSMenus and cells and invoke selectors only on each item's explicit NSObject
synthetic owner. They never present/track menus, call NSWorkspace, launch the app,
write stores, synthesize input or spin a run loop. Production resources are used
for the three explicit language snapshots, with independent authored text
expectations so missing translations cannot be hidden by the same lookup.

Coverage written:

- Complete nested en/zh-Hans/ja copy and accessibility labels, one snapshot read
  per group, stable item identifiers and untouched token/layout.
- Nil compatibility, retained old menu/binding/target/selector identities and new
  menu locale; provider returning a different snapshot on the next consultation.
- Real selector routing to latest canonical metadata and stable folder IDs,
  including colliding Unicode/percent/placeholder-like user titles.
- Stale catalog revision, cell reuse, moved canonical URL, hidden record, changed
  layout generation and same-generation changed layout refusals.
- Read-only enabled-state invariants and action-time revalidation; busy assignment,
  later protection acquisition and missing callback cancellation.
- Top-level assignment without move-out/separator; invalid binding and unavailable
  organization do not consult unused providers.

Main may run the new focused class together with existing
`AppContextMenuActionTests` and `AppFolderAssignmentMenuTests` only after freeze.
That serial run and strict resource validation remain required; native tracking,
VoiceOver and exact-candidate GUI acceptance remain separate open gates.

## Evidence boundary

RTK-prefixed read/search and Git status commands inspected the owned implementation,
localization seam, domain type and existing native test conventions. Owned Swift
source has been reviewed statically. No builds or tests were executed: executed
XCTest count is **0**, and this worker does not report a test PASS. No app launch,
process control, install, signing, clean, commit or global memory edit occurred.

Final static checks: `rtk proxy git diff --no-index --check -- /dev/null <path>`
was applied separately to each of the five owned files (all were untracked at
entry or newly created). Each produced no whitespace diagnostics; exit 1 is the
normal no-index difference result against `/dev/null`, not test execution or a
compiled-success signal. The local SDK's NSMenuItem header confirms declared
NSAccessibility conformance; this is API source inspection only.

Process deviation: the initial RTK instruction-file read and a no-hit memory
registry search were issued before adopting the RTK prefix. All subsequent shell
commands used RTK, including every project read/edit/check. No relevant global
memory content was used, and no global memory file was edited.
