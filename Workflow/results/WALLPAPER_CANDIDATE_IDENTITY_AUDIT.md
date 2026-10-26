# Wallpaper candidate identity audit

Date: 2026-10-15
Scope: read-only, bounded static packaging/signature inspection; report-only delivery.

## Result

The candidates have byte-identical application Info.plists, the same bundle identifier, and the same native UI-test entry marker. Their inherited linker-generated ad-hoc code signatures have the same signing mode and code identifier, but different CDHashes and different implicit designated requirements. They do **not** establish a stable designated requirement across these builds.

Both candidates fail the same read-only code-signature verification with a resource-envelope error. This is a concrete shared packaging/signature limitation, not evidence of a new regression in the current candidate. No concrete wallpaper-source API packaging precondition or unsupported source-access contract is established by the permitted inputs. In particular, neither the requirement change nor verification failure proves a TCC cause or a need for Full Disk Access.

Wallpaper remains unresolved. Historical wallpaper-ready behavior of the earlier candidate is supplied task context, not a native observation repeated by this audit. Main retains ownership of the same-binary Finder-open/activation control.

## Authority and evidence boundary

The human's explicit report-only assignment and Chief-workflow waiver govern this slice. No agents were dispatched or messaged. Only this new report was written; no workflow state, stage summary, existing report, source, candidate, or script was edited.

The project is a SwiftPM/macOS AppKit application; the inspected shell packaging script assembles a SwiftPM executable into an application bundle. Architecture context comes from the assigned stage summary and packaging script, not a new implementation review.

Inputs inspected:
- `Workflow/stage-summaries/2026-10-15-wallpaper-launch-context.md` and the wallpaper-loading stage summary.
- Existing wallpaper-loading diagnosis/source-review text, solely to locate and attribute the 455-input freeze.
- `.build/verification/20261015/wallpaper-loading/source-inputs-final.json`.
- `Scripts/package-app.sh`, read as text only.
- Each named candidate's `CANDIDATE_MANIFEST.txt`, application `Contents/Info.plist`, executable SHA-256, and public `codesign` display/verification output.

No reference/Buho/LaunchBetter directories, image/asset contents, personal wallpaper data, TCC database, private APIs, native UI, process inspection/control, tests, Swift commands, builds, packaging execution, signing, installation, permission changes, or feature changes were used. Filename-only discovery did not read asset contents. No current source/test files were opened or rehashed beyond the allowed packaging script. This audit does not claim 455/455 independent source verification.

## Exact candidates

All paths below are relative to the project root `/Users/mac/Projects/Launch_Copy/PagingPrototype`.

| Field | Current | Earlier |
| --- | --- | --- |
| Candidate directory under `.build/candidates/` | `title-edit-focus-rc-20261015-r1` | `identifier-search-rc-20261015-r1` |
| App | `LaunchcopyUITest.app` | `LaunchcopyUITest.app` |
| Executable SHA-256, independently rehashed | `889d661392cc18f0e59958b1b51d499dfac13d82a116a7fa53e1b31852c12bed` | `f3709254c9e332d831f6ae3ad40d5d1aa3bdc6d90934122d023e082a0def4086` |
| Manifest build time, provenance only | `2026-10-15T10:00:48Z` | `2026-10-15T00:26:13Z` |
| Manifest configuration | `release` | `release` |
| Manifest git head, provenance only | `319b8cc149a8553adfc3414abaacbe28b59d97ef` | same |
| Manifest dirty count, provenance only | `408` | `371` |
| Manifest localization-manifest hash | `9b91d16b8b7b419ff0f451f32bb4958e6eb8d0b32966c1364f303f4e0c304f7d` | `958c1b06c20320f677500150dbc49fab1d178c3d00f2812797c940112a899647` |

Executable hashes match their sidecars. The equal recorded git head does not establish equal source trees; the executable and recorded localization-manifest hashes differ. Localization files/assets were not inspected or validated here. Build times, dirty counts, and localization hashes above are sidecar assertions, not independently reconstructed history.

## Bundle metadata and modes

Both complete application Info.plists have SHA-256:
`ca2bee2f54a7459a3df4f47848c8e0690e8ae8b5b33f5af461f5f6b82d678254`.

| Metadata | Both candidates |
| --- | --- |
| `CFBundleIdentifier` | `com.launchcopy.ui-test` |
| Name / display name / executable | `LaunchcopyUITest` |
| Package type / principal class | `APPL` / `NSApplication` |
| Version / build / minimum macOS | `0.1.0` / `1` / `14.0` |
| `LaunchcopyUITestEntry` | `version = 1; profile = gui` |
| Manifest entry mode / isolated profile | `marker-v1` / `true` |
| `LSBackgroundOnly` | absent |
| `LSUIElement` | absent |

Neither plist explicitly opts into a background-only or UI-element bundle mode. Neither contains a wallpaper-background preference, wallpaper source URL, or a foreground/background launch flag. Static bundle metadata therefore supplies no changed background default between these candidates. Actual activation policy, application preference defaults, launch options, current profile state, and effective source access cannot be inferred from these plists.

The assigned launch-context summary states that the test entry skips passive makeKey/orderFront/activation. That is attributed stage context, not independently re-established from source or runtime in this audit. The `gui` marker by itself is not evidence of foreground activation.

## Public signature metadata and verification

| Field | Current | Earlier |
| --- | --- | --- |
| Code-signing identifier | `PagingPrototypeApp` | `PagingPrototypeApp` |
| Format | thin arm64 app bundle | same |
| Signature | `adhoc` | `adhoc` |
| CodeDirectory version / flags | `20400 / 0x20002 (adhoc,linker-signed)` | same |
| TeamIdentifier | not set | not set |
| Info.plist binding | `not bound` | `not bound` |
| Sealed resources | `none` | `none` |
| Displayed entitlements | no entitlement payload output | no entitlement payload output |
| CDHash | `51382d40e611bd9861ccd2a7d780c8c8bc7f18fb` | `a7623c9b430d6d98f1161dd9d348e48cecfe5478` |
| Full CodeDirectory SHA-256 | `51382d40e611bd9861ccd2a7d780c8c8bc7f18fb26c777fec398222c04ed1039` | `a7623c9b430d6d98f1161dd9d348e48cecfe547842a877e47c448186852defb9` |

No certificate authority chain is displayed. No app-sandbox or file-access entitlement was displayed; no hardened-runtime flag appears in the reported flags. This is a statement about inspected signature metadata, not a runtime permission determination. The signing identifier differs from the bundle identifier in the same way for both candidates.

The separate `codesign -d -r- --entitlements -` inspections returned exit 0 and:

Current:
```text
# designated => cdhash H"51382d40e611bd9861ccd2a7d780c8c8bc7f18fb"
```

Earlier:
```text
# designated => cdhash H"a7623c9b430d6d98f1161dd9d348e48cecfe5478"
```

These are the tool's displayed implicit designated requirements, with no certificate/team anchor displayed. Equal bundle identifiers do not make these displayed requirements equal. Within one unchanged candidate the inspected requirement is fixed; across these two candidates it differs with the code hash. This audit does not claim how any existing privacy-settings row was matched to either requirement.

For **each app bundle**, `codesign --verify --verbose=4` returned exit 1:
```text
code has no resources but signature indicates they must be present
```

The same read-only verification aimed at **each packaged executable path** also returned exit 1 with that message. Neither target may be reported as signature-verification PASS. Display success and verification success are distinct. This inspection did not bypass the error, repair the bundles, or test execution/admission policy.

## Existing packaging contract

The current `Scripts/package-app.sh`:
- Explicitly declares that it does not sign or notarize (line 3); ends with an unsigned/not-notarized notice (line 229). The script was not executed, including any commands or subprocesses in its text.
- Defaults to product `Launchcopy`, bundle ID `com.launchcopy.app`, executable input `PagingPrototypeApp` (lines 11–16). The two inspected bundles use the explicit reserved test identity instead.
- Requires an explicit test profile for `com.launchcopy.ui-test`, requires non-destructive packaging, and records `marker-v1` / isolated profile (lines 43–64).
- Copies the executable to `Contents/MacOS/$PRODUCT_NAME` (line 124), writes application metadata, and inserts the version/profile test marker when isolated (line 179).
- Does not specify `LSBackgroundOnly`, `LSUIElement`, a wallpaper default, a signing identity, entitlements, a designated requirement, or a wallpaper-file authorization contract.

The script's unsigned description is consistent with not performing a bundle-signing step; it does not mean that the copied Mach-O has no embedded signature. Both observed binaries retain a linker-generated ad-hoc signature. The current script plus public metadata explain that distinction without establishing every historical build command.

A shared missing/invalid bundle resource seal is a concrete packaging verification limitation. No inspected script or plist promises successful signed-bundle verification, cross-build requirement stability, a preserved OS authorization grant, or wallpaper access. No evidence in this scope establishes that wallpaper loading requires a different signing arrangement or a new source-access wrapper. A source/API contract finding would require separately authorized source/API evidence; none is invented here.

## Freeze linkage and integrity

The supplied wallpaper-loading freeze is:
`.build/verification/20261015/wallpaper-loading/source-inputs-final.json`.

Its independently computed SHA-256 is
`2ab1e65f615b365fa5d9869cfa2ee73c47d21f2cab3d5a9fa798a85d3eb34d7b`,
and it contains 455 path-to-hash entries. Only its `Scripts/package-app.sh` entry was checked against current file content:
`0a8ef1084618a1316a608dd4ee002efae5182d2d263d2b2eba2a60fb012b96c3` — match.

Additional independently hashed sidecar inputs:
- Current `CANDIDATE_MANIFEST.txt`: `96fbb0d843ef40af0a3d7105ea2e380ab18f172c5740b00132ebd5079c4d9325`.
- Earlier `CANDIDATE_MANIFEST.txt`: `3d04ea6a28454c1817ab7865b970f0df1e94ea861a9c123470a7dfbb2bbc5d89`.

The freeze, packaging script, both sidecars, both Info.plists, and both executable hashes were checked again immediately before exclusive creation of this report. This establishes stability of those bounded inputs over this audit, not a full source freeze, complete resource integrity, or build reproducibility.

## Facts, hypotheses, and handoff

Confirmed: identical plist identity/modes; equal ad-hoc/linker signing mode; unequal CDHashes/designated requirements; no entitlement payload displayed; identical bundle/executable verification errors; current packaging script agrees with its entry in the supplied 455-input manifest.

Unproven: signature identity caused the wallpaper wait; a displayed Downloads permission row authorizes the current candidate; a TCC denial occurred; Full Disk Access is necessary; normal Finder activation changes readiness; fixing bundle signing fixes wallpaper loading; any particular wallpaper API packaging contract was violated.

The earlier reported wallpaper-ready outcome and the shared verification failure show why that failure alone cannot discriminate the two reported outcomes. They do not prove that signing is irrelevant to all launch contexts. No permission or signing change is recommended as a wallpaper fix from this evidence.

Next action remains Main's already-owned normal Finder-open control on the exact current binary, with its existing source/cache/privacy constraints. No duplicate native control, repair, feature, or full-product acceptance is claimed here.

**Exact changed path:** `/Users/mac/Projects/Launch_Copy/PagingPrototype/Workflow/results/WALLPAPER_CANDIDATE_IDENTITY_AUDIT.md` (new file only).
