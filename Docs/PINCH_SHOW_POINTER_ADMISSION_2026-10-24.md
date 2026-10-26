# Pointer admission after pinch Show

## Problem and scope
The user reports three to four ineffective three-finger pointer drags after a four-finger inward pinch shows the launcher. Investigate native main-grid input admission and the Show lifecycle, then repair a demonstrated defect. Keep system pointer dragging separate from the four-finger recognizer.

## Evidence and limits
The running isolated candidate is `LaunchcopyPreviewInlineRename.app`, PID 5996, binary SHA-256 `ab2b343b99cb91c288766abc0d58b9973b8e9ad7a665182eddc4a4908aa9df72`. Its current physical report is preserved in `.build/verification/20261024/pinch-open-drag/physical-report-mixed-r1.json`. It reports 7 window downs, 80 window drags, 1 B1 main down, 0 B1 main drags, 3 native folder downs, 38 coordinator moves, and 2 commits. This aggregate includes earlier folder operations; commits cannot be attributed to the failed main attempts. Report-time booleans are not failure-time snapshots. All cancellation and admission-denial counters are zero; this narrows investigation but does not identify the cause.

## Requirements and non-goals
- Exercise the production Show and window routing paths, not a copied approximation.
- Preserve the existing visible-icon hit contract, transaction/generation validation, search and title-edit gates, and native window chrome handling.
- Do not retune PagingCore, PagingUI, thresholds, four-finger detection, or persistence to mask missing input.
- Preserve the user's current isolated arrangement and settings. Do not automate real-app launches, grouping, or reorder operations.
- If additional diagnosis is necessary, use default-off, fixed-label in-memory counters only; never record app identities, names, paths, text, raw touches, or coordinates.
- Do not infer a hit-test, focus, or CPU cause from aggregate counters alone.

## Architecture and acceptance
Main investigates Show, layout, and window-to-cell routing; a bounded read-only sidecar audits activation/input ownership independently. A source repair requires a deterministic failing regression through a production seam and explicit negative controls. Targeted and full tests, Debug/Release packaging, source verification, independent bounded review, native presentation, and user physical acceptance remain separate evidence layers. The final physical gate is a fresh four-finger Show followed by first-attempt main-grid pointer dragging, then folder dragging independently.

## Delivery
Keep this specification, the stage summary, `Workflow/PLAN.md`, and project `MEMORY.md` current. Preserve all previous source/test failures and candidate receipts. Do not replace the running preview until its diagnostic evidence has been retained and the replacement passes automated gates. The exact cause and physical repair remain unresolved at stage start.

## Observed outcome and scope retained
The user subsequently reported first-attempt success on the same binary. The follow-up capture is again mixed (13downs, includingfolderinput), not a single-attempt trace. Product-source unchanged; newproductionShow control plus existingownerclass58/0. A singlepositivephysicalobservation doesnot close intermittentcausality orauthorize changingiconhitsemantics. No moreblindscriptedtrials requested; retainfailuresif theyrecur.
