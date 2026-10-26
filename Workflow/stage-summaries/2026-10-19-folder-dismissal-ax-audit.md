# Folder dismissal accessibility-tree observation

Date:2026-10-19
Status: BOUNDED_READ_ONLY_AUDIT

## Objective
After source recovery, Main opened own35-member folder, paged through3pages, and Escape closed it visually. CUA accessibility inventory total changed from106before open to166after visually closed, while its first100items omit folder controls. A fresh screenshot proves panel absent and source selection restored. This count difference alone does not prove accessible hidden content, spokenVoiceOver behavior or a production defect. Determine whether current folder dismissal/exit visibility code has a concrete accessibility exposure bug, or whether this observation is consistent with tool enumeration/lazy view realization.

## Ownership and constraints
Main completes authoritative populated-source native report and mandatory rollback verification. One independent read-only explorer checks only FolderOverlayView/accessibility/dismissal/exit lifecycle and relevant existing tests; reportonly, no source/tests/build/native/process/reference operations. TwoagentsincludingMain, max3. Current511inputfreeze at .build/verification/20261019/library-drawer-focus/source-inputs-r1.json remains stable; Main doesnotinspectthe samecodewhileaudit runs. No production repair until a specific branch/counterexample is established. Userwaivedformalworkflow, approvedroutinecorrectnessrepairs/subagents; preserve all dirtystate.

## Required outcome
Actionable defect with exact branch/lines and bounded regression path, or no concrete defect and limitations. AX tree counts and a screenshot are not interchangeable with actual native assistive-technology focus/visibility. No speculative rewrite or cosmetic change. FullLaunchBetter-on-Launchcopygoal remains incomplete; priorlockcounts reset after actualdesktopaccess/nativeprogress.

## Outcome: no concrete defect established
Chandrasekhar completed the bounded read-only report,15inspectedinputhashesmatchfreeze. Escape synchronously clears/detaches; retainedpointerexit exports emptyAXchildren and completes/cancels bydetach. No concrete branch provesclosed-descendantAX/focusleak.106→166counts alonecannotdiscriminate lazyviewrealization/toolcache/windowreachableAXancestry; Main'sfreshscreenshotconfirmsvisuallyclosed/sourcefolderselected. No speculativepatch/tests/build/nativePASS. MainclarifiedreviewruntimeprovenanceasMain-supplied, notnewhumanacceptance. Reviewerclosed; no agentjobleft. Report Workflow/reviews/FOLDER_DISMISSAL_AX_AUDIT-r1.md. Fullgoalstillactive/incomplete; no morecounter-onlyauditswithoutidentity/reachabilitycounterexample.
