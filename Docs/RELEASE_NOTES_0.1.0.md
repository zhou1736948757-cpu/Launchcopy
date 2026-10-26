# Launchcopy 0.1.0

First stable GitHub distribution of Launchcopy, based on the user-accepted L1 implementation.

> **Not notarized. No Developer ID signature.** macOS may block this download or show an unidentified-developer warning. This is not an Apple-approved or App Store release. Do not disable Gatekeeper, SIP or antivirus protections. Review the source and download only from this repository.
>
> **未公证、无 Developer ID 开发者签名。** macOS 可能拦截首次打开；本版本不是 App Store 版本，也不代表通过 Apple 审核。不要关闭系统安全保护。

## Download and compatibility
- `Launchcopy-0.1.0-macos-arm64.zip`: the normal `Launchcopy.app` application, not the integrated test preview.
- Apple Silicon Macs (M-series), macOS 14 or later. Intel, older macOS versions and 120 Hz physical performance are not certified by this release.
- `SHA256SUMS.txt`: archive integrity checksum. `INSTALLATION_AND_LIMITATIONS.md`: installation, data separation and known limitations.

## Included
- Paged application grid, search, folders and drag-and-drop organization.
- Leading application library with category cards and individual application actions.
- Live appearance/grid preferences and English, Simplified Chinese and Japanese localization.
- Activation integrations and local application management/settings. Inward four-finger activation is enabled by default; outward hide, shortcut/hot-corner/login integrations and optional launch history have their own settings. Four-finger gestures use a private macOS framework and may not work consistently on every device or OS update.
- Bounded idle icon/control preparation for first Library entry and grid return. The user accepted the L1 experience; this is not a guarantee of zero hitches under load.

## Data and first launch
The normal bundle identity is `com.launchcopy.app`. No personal application inventory, layout, preferences, usage history or diagnostic captures are included. Existing integrated-preview arrangements are **not automatically imported**; production data is separate. An existing normal Launchcopy installation uses its existing production stores: back up important preferences/layouts before replacing an older installation, and quit that version normally first. This release does not silently overwrite it.

## Verification and limits
Fresh verification after the bounded storage repair: **3838 tests, 0 failures**; focused storage/quit/persistence checks: **125 tests, 0 failures**. Independent production-source review passed within its documented scope. Initial failures and their dispositions remain recorded in the repository. Production Release packaging, strict local code/resource-integrity checks, resolver-only startup, packaged-language validation and ZIP privacy/path/dependency checks passed. Gatekeeper rejection remains expected; no system protections were changed. Automated tests and resolver-only startup checks are not an independent fresh-device GUI installation or an in-place production upgrade test. Developer ID signing and notarization are intentionally not performed. No blanket clean-room, legal-clearance or new open-source-license claim is made; source provenance records remain available in the repository.

## Opening the download
Unzip, place `Launchcopy.app` in Applications if desired, and open it. If macOS blocks it, first verify the source and checksum, then follow Apple's supported per-app instructions **only if you trust it**: [Safely open apps on your Mac](https://support.apple.com/en-us/102445). If the security policy still refuses it, stop rather than globally weakening macOS protections.

## Reporting issues
Report macOS version, Mac architecture and reproduction steps in repository Issues. Avoid publishing app inventories, private paths, personal layouts or raw logs containing sensitive information.

## Pre-release storage safety repair
If the normal layout directory cannot be resolved, Launchcopy now uses explicit read-only protection instead of falling back to the shared temporary root. Workspace changes are blocked rather than falsely claiming persistence. Journal startup/reset cleanup is limited to the two owned temporary filenames while holding the journal lock; unrelated files/directories and existing symlinks are preserved. This does not claim protection against arbitrary adversarial same-user filesystem replacement. The source release also replaces one test helper's scheduler-yield counter with a bounded monotonic wait; all safety predicates remain intact.

Login-at-launch registration depends on installation and macOS policy; successful registration for this unnotarized package has not been certified. Use the settings status rather than assuming registration succeeded. Inward four-finger activation is enabled by default; outward hide, global shortcut, hot corner and launch-history recording have their own enable settings.

## Local package-integrity seal
The final app has a local **ad-hoc** signature to bind its executable, Info.plist and resources coherently. It does not identify a trusted developer, use a Developer ID certificate, include notarization, or grant Gatekeeper approval. macOS may still block it. No system-security settings are changed by this package.

## Integrity
Archive SHA-256: `e62963abfdabe28e9925ceec94a2ebee1631cf4eb44406d5c80be253c497e0a6`

Application executable SHA-256 after the local ad-hoc seal: `474e6645b15c1f90f90393370cba3eeb5882816238010ee18ebcfcd5e07afa63`.
