# Settings consumer key requests

Published 2026-10-14. Exact API requested from the resource worker:

```swift
public func settingsText(_ key: SettingsTextKey) -> String
public func hiddenReferenceCount(_ count: Int) -> String
```

All enum cases below are ASCII English camelCase. Chinese values preserve the existing default output exactly. English and Japanese are independently authored by the resource worker. No consumer formats user content as a template.

`managementHiddenSuffix` includes all separator spacing/punctuation (Chinese: `（已隐藏）`). Append it to the existing verbatim app/alias title, preserving original-name search and represented objects. `hiddenReferenceCount` includes the whole count sentence; Chinese baseline is `\(count) 个隐藏引用（含暂未安装的应用）`, English must distinguish one/other.

## AppearanceSettingsView

| Exact case | Existing Simplified Chinese |
| --- | --- |
| `appearanceShowLabels` | 显示应用名称 |
| `appearanceBlurAccessibility` | 壁纸模糊强度 |
| `appearanceIconAccessibility` | 图标首选尺寸 |
| `appearanceFontAccessibility` | 应用名称字号 |
| `appearanceApply` | 应用外观 |
| `appearanceRestoreDefaults` | 恢复默认 |
| `appearanceBlurCaption` | 壁纸模糊强度（0–60） |
| `appearanceHelp` | 图标和名称在现有格子内自动适配，较大的设置可能缩小显示。0 表示不模糊。修改后点击应用；手势、拖拽或改名结束后再显示，关闭不会保存草稿。 |
| `appearanceIconCaption` | 图标首选尺寸（32–64 pt） |
| `appearanceFontCaption` | 应用名称字号（9–16 pt） |
| `appearanceLoadFuture` | 外观设置来自较新版本，本版本不会覆盖。 |
| `appearanceLoadCorrupt` | 外观设置无法读取，已使用默认值。点击应用可保存新的设置。 |
| `appearanceInvalidDraft` | 外观设置值无效，未保存修改。 |
| `appearanceUnavailable` | 外观设置暂不可用。 |
| `appearanceSaveFuture` | 较新版本的外观设置未被覆盖。 |
| `appearanceInvalidPreferences` | 模糊强度、图标尺寸或字号超出支持范围。 |
| `appearanceSaveFailed` | 外观设置无法保存，未应用修改。 |
| `appearanceDraftDefaults` | 默认值已载入草稿；点击应用后保存。 |
| `appearanceApplied` | 外观设置已应用。 |
| `appearanceQueued` | 外观设置已保存，等待手势、拖拽或改名结束后显示。 |
| `appearancePresentationUnavailable` | 外观设置已保存；当前界面不可用，重新打开后显示。 |

## AppManagementSettingsView

| Exact case | Existing Simplified Chinese |
| --- | --- |
| `managementHideSelected` | 隐藏所选应用 |
| `managementSaveAlias` | 保存别名 |
| `managementClearAlias` | 恢复原名 |
| `managementRestoreAll` | 恢复全部隐藏应用 |
| `managementAppAccessibility` | 管理应用 |
| `managementAliasPlaceholder` | 留空恢复原名 |
| `managementAliasAccessibility` | 应用别名 |
| `managementHelp` | 隐藏不会删除应用或保存的排列。别名只影响显示和搜索，不会修改应用文件；原名仍可搜索。 |
| `managementSelectApp` | 选择应用… |
| `managementHiddenSuffix` | （已隐藏） |
| `managementLoadFuture` | 应用管理设置来自较新版本，本版本不会覆盖。 |
| `managementLoadCorrupt` | 管理设置无法读取，已使用默认值；保存后替换损坏设置。 |
| `managementSaved` | 应用管理设置已保存。 |
| `managementInvalidAlias` | 别名不能包含控制字符，最多128个字符。 |
| `managementSaveFuture` | 较新版本的设置未被覆盖。 |
| `managementSaveFailed` | 无法应用设置，请重新选择应用后重试。 |

## AppSourcesSettingsView

| Exact case | Existing Simplified Chinese |
| --- | --- |
| `sourcesAutomatic` | 自动刷新应用列表 |
| `sourcesAdd` | 添加文件夹… |
| `sourcesRemove` | 移除所选来源 |
| `sourcesApply` | 应用来源设置 |
| `sourcesRefresh` | 立即刷新 |
| `sourcesRootAccessibility` | 额外应用来源 |
| `sourcesFixedCaption` | 固定来源（保留） |
| `sourcesExtraCaption` | 额外来源 |
| `sourcesHelp` | 仅支持可读取的本地文件夹；不接受整个主目录、磁盘根或网络位置。移除来源不会删除应用、保存的排列或别名。更改后点击应用；立即刷新仅使用已保存的来源。 |
| `sourcesLoadFuture` | 来源设置来自较新版本，本版本不会覆盖。 |
| `sourcesLoadCorrupt` | 来源设置无法读取，已使用固定来源；点击应用后保存新设置。 |
| `sourcesWatchActive` | 自动刷新已启用；变化会合并处理。 |
| `sourcesWatchDisabled` | 自动刷新已关闭；可使用立即刷新。 |
| `sourcesWatchUnavailable` | 自动刷新不可用；请使用立即刷新。 |
| `sourcesWatchDegraded` | 部分来源暂不可监测；请使用立即刷新重新检查（含恢复的文件夹）。 |
| `sourcesSelectRoot` | 选择额外来源… |
| `sourcesRemovedDraft` | 来源已从草稿移除；点击应用后生效。应用和保存的排列不会被删除。 |
| `sourcesPanelPrompt` | 选择应用文件夹 |
| `sourcesAddedDraft` | 来源已加入草稿；点击应用后保存。 |
| `sourcesAlreadyCovered` | 所选文件夹已包含在固定来源中。 |
| `sourcesRejected` | 无法添加此来源；请选择可读取的本地应用文件夹。 |
| `sourcesSaved` | 来源设置已保存并应用。 |
| `sourcesSaveFuture` | 较新版本的来源设置未被覆盖。 |
| `sourcesInvalidRoot` | 来源校验失败，修改未保存；请重新选择文件夹。 |
| `sourcesSaveFailed` | 来源设置无法保存，修改未应用。 |
| `sourcesSuperseded` | 本次操作已取消或被更新的操作取代。 |
