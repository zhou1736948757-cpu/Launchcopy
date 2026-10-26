# Controlled real native application launch results

Date: 2026-10-15. Main native bounded PASS; not independent live Reviewer acceptance or complete parity.

## Frozen product / controlled fixture
Existing candidate: `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/source-coverage-rc-20261015-r1/LaunchcopyUITest.app`.
Executable SHA256: `66cd55c147954f91387131a0585bb970bda5ace6925079ab45138b2ba653a32b`. Launcher PID **71877**.
All455product input hashes unchanged and reverified after the native test. No product source/test/resource/Package.swift/build/package/physics change this turn. Earlier2680/0 XCTest is historical, not a new execution.

A standalone independently authored AppKit fixture, **Launchcopy Native Launch Probe**, only displays static success text and a normal Quit button. No file IO/preferences/network/event injection/global hooks/other application control. Its source and zero-output successful compiler receipt are retained under `.build/verification/20261015/controlled-native-launch/`.
- Local fixture compile: `xcrun swiftc`, Swift6 mode, complete concurrency, warnings-as-errors; exit0, compiler output0bytes.
- Fixture executable SHA256: `6972c9ca26a6a9ae02fcdd6c6381fe0f9e2b7768b4196f7f1c88a16328ee6fb8`.
- No explicit signing/install/notarization. Compiler/linker default signatures, if any, are not a distribution claim.
- Only the candidate-local synthetic Applications directory received the fixture. No real app or formal data used. Initial source0 apps; final source0 apps.

## Actual native launch evidence
| Route | Anti-false-positive control | Observed result | Exit |
| --- | --- | --- | --- |
| Grid single click | Exact fixture executable absent immediately before real coordinate click on observed named cell. No fixture CUA binding before click. | Exact executable process **72080** appeared, verified **before** binding CUA to it. Actual titled window contained `Controlled launch succeeded`. | Native `Quit probe` button; exact executable absent. |
| Library details Open | Temporarily enabled Library via isolated native settings from its originalOff state; selected the named fixture. Exact fixture executable absent before Open. | Real native detailsOpen created a genuinely new process **72895**, verified **before** re-binding CUA; actual success window/text observed. | Native `Quit probe`; exact executable absent. |

These are real application launches from the currently displayed grid/Library UI, not injected `AppLaunching` callbacks, a direct helper call to NSWorkspace, shell `open`, or CUA's `getApp` manufacturing startup. Product source uses the existing validated public launch adapter. No internal callback trace or arbitrary external-application compatibility claim follows from this one controlled app.

## Restore / safety
- Library restored **Off** via native settings (saved status observed); entry removed. No other Library metadata changed.
- Fixture moved back to own private `SourceControlStaged` sibling, not deleted. Automatic catalog removal observed; grid returns noresults, queryempty.
- Launcher normal menu Quit; exact main/fixture executable process absence verified by shell; **no subsequent app query**.
- Staged fixture executable hash equals the compiled hash. All455source hashes and candidate hash unchanged; `git diff --check` pass.
- Layout may retain latent refs for these authored test apps by design; no saved canonical layout reset/deletion/overwrite was used to manufacture cleanup.
- No system wallpaper/security/privacy settings, installation/signing/publish/commit, reference code/resources, ordinary app stop or process kill.

Receipt: `.build/verification/20261015/controlled-native-launch/receipt.json`.
Stage: `Workflow/stage-summaries/2026-10-15-controlled-native-launch.md`.

## Remaining gates
Only these two specific launch routes on this one current macOS/candidate are accepted by Main. No independent live Reviewer run, physical-input/paging/120Hz/IME/VoiceOver/full production activation/quarantine/notarization acceptance. Full LaunchBetter-on-Launchcopy objective remains ACTIVE/incomplete, including explicitly pending product decisions. Wallpaper showedready/visible in this currentwarm-cache session, but earliercoldsource-open failure has not been causally fixed.
