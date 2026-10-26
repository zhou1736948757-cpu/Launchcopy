# Wallpaper source-control A / B / A results

Date: 2026-10-19
Status: EXPERIMENT_COMPLETED / ORIGINAL_RESTORED / FAILURE_NOT_REPRODUCED / CAUSALITY_UNRESOLVED

## Authority and scope
The human's “我全部授权” followed the specifically explained temporary macOS wallpaper control experiment. It authorizes this original / authored fixture / original experiment and rollback; it is not used as authority for security/privacy changes, real application removal, signing, installation or publication. The goal resumed and was observed ACTIVE. No product implementation change was made.

## Identity and method
Same unsigned, uninstalled `library-drawer-focus-rc-20261019-r1/LaunchcopyUITest.app`, executable SHA-256 `658bd6b98992fabba2bcb9e5ad35e7bd25b324a6f14e1afe422b6b2f24382038`, and its isolated `UITestProfiles/gui` profile for all three phases. Each phase was opened by normal Finder Open only after the preceding own instance was normally quit and exact executable absence verified. Test window remained ordinary and non-topmost. No cache clearing, security/permission/signature change or alternate helper read of the personal image.

Before any setting mutation, native Wallpaper settings exposed the selected original still-image thumbnail as a reliable rollback entry. Fill Screen and All Spaces ON were noted neutrally. B is a separately authored 1600 x 1000 RGB gradient PNG created under the verification directory, not copied user/reference content. Original filename, path, pixels and content hash were not saved to diagnostic artifacts; native views were inspected without saving screenshots.

## Actual observations
| Stage | Exact own PID | Native state and visible outcome |
| --- | --- | --- |
| Existing pre-A instance | 15521 | render-failed before normal Quit; this is later than the prior bounded loading/source-open sample, not a simultaneous observation |
| A: original, fresh Finder Open | 24473 | ready; original blurred backdrop visibly present, BEFORE changing wallpaper |
| B: authored source selected natively | 26147 | ready; authored gradient visibly present |
| A2: original restored natively | 27037 | ready; original blurred backdrop visibly present |

All three experimental instances were normally quit; exact process absence was checked. Original selected thumbnail, Fill Screen and All Spaces ON were restored and verified in native settings, then confirmed by the restored original app backdrop. The settings window was closed; no own test instance remains running. The synthetic wallpaper may remain as a recent item in macOS Wallpaper settings; it is not selected. Its fixture file is retained so that recent entry does not point to a deleted file. No recent-item cleanup or unrelated preference mutation was attempted.

## Interpretation and limitations
The intended failure/success/failure distinction did NOT occur: A had already recovered before B. This confirms that the current packaged path can render both sources in this runtime context, but does not identify why the previous instance failed or prove intermittent reliability fixed. Relaunch, visiting native Wallpaper settings, system/source availability, retained warm caches and timing are confounds. Opening Settings itself is not established as the cause of recovery. No image-source, OS, TCC, permission, signature, compositor or blur-algorithm root cause follows from this experiment.

Earlier samples still localize only those bounded windows to ImageIO source-open; the current all-ready observations do not negate them. Conversely those samples cannot be promoted to the explanation of every future failure. No blind retries, extra workers, fake-ready state, cache purge or speculative source patch was added. A future repair requires a reproducible failure and evidence that distinguishes source-open, decode/render and installation stages.

## Integrity and review
All 511 frozen source/package inputs and 86 existing isolated fixture JSON/plist payloads match their retained baselines. Exact candidate hash unchanged. No new source/test/build/package run was needed or claimed; prior 3098/0 remains historical automated evidence, not rerun here. Existing root-loss fault remains rolled back.

Independent Dirac read-only evidence review agreed: no causal attribution or product repair claim is warranted. That review inspected the named protocol, receipt and prior result only; it did not execute UI/tests or issue a runtime PASS. Its reported historical pending-approval/running-state inconsistency is addressed by this dated supersession and continuity entries. Reviewer is closed.

## Current continuation boundary
The specifically pending wallpaper-experiment authorization is resolved and the experiment completed. Earlier “awaiting approval”, PID15521-running and goal-BLOCKED entries are historical, superseded here. Wallpaper is currently observed working, while intermittent root cause remains unresolved. Full LaunchBetter-on-Launchcopy objective remains incomplete; current-build physical gestures/performance, actual IME/spoken VoiceOver, 120Hz/multidisplay and any separately reserved product contracts are not supplied by this experiment. No further repeated green checks or OS changes are justified just to manufacture progress.

Receipt: `.build/verification/20261019/wallpaper-source-control/receipt-r1.json`.
