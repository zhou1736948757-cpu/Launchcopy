# Native localized live Appearance — 2026-10-18

## Result
BOUNDED_NATIVE_LOCALE_LAYOUT_PASS on the exact already-running isolated candidate. This closes the pending current-candidate English/Japanese Appearance layout check at the observed viewport, not the complete input/accessibility/performance matrix.

## Identity and preserved baseline
Candidate: `.build/candidates/live-appearance-grid-rc-20261017-r1/LaunchcopyUITest.app`; executable SHA256 `b1ca4fcbcedc4ff5da45d3775cf6a9c587b4cb117933d87ce5d7ef7ce8cf48c7`; exact running PID29032 verified before interaction. All488 production/test/package inputs still match source-integrated-r3.json. No build/test/source work was repeated.

Fresh native baseline differed from the previous historical handover: wallpaper blur28.40063010899183 (display28), icon54, font12, names on, columns6/rows5. These current human choices were preserved, not restored to the older23 blur value. Original language was Follow System, resolving Chinese.

## Actual native observations
1. Selected English through the normal Language choice and Apply; native saved/applied feedback observed.
2. English Appearance: six tabs/no independent Grid; name checkbox, all three labeled sliders/numbers readable; no healthy Apply. Native downward scroll reached all row/column/count30/automatic-save explanation/status/Defaults controls without overlap or unreachable bottom content.
3. Selected Japanese through the same normal controls and observed saved/applied feedback. Japanese tabs fit the existing settings width. Bottom row/column/count30, wrapped explanation/status/Defaults were visibly readable. Upward scroll exposed the three correctly translated slider labels and unchanged numeric values.
4. Restored Follow System using Language Apply, observed Chinese saved/applied feedback, and left Appearance at the top. Fresh final AX still shows the exact starting appearance/capacity values. Did not invoke Defaults or any appearance/capacity control.

Main wallpaper diagnostic was ready before the locale changes. This is a new successful readiness observation, not a root-cause fix or reliability guarantee. Inline screenshots were inspected; no personal screenshot files saved.

## Evidence and limits
Structured receipt: `.build/verification/20261018/current-parity-locales/native-locales-r1.json`. Tests remain the prior completed2951/0 baseline, not rerun evidence. Native AX/screenshot review is Main's bounded observation, not independent Reviewer/native VoiceOver or human aesthetic acceptance. No real IME, quantitative latency/energy/RSS,120Hz, multidisplay or full parity claim. No restart, source/data-layout migration, production preferences, OS/security/reference/installation/signing/publishing/commit action.
