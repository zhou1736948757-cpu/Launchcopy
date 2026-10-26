# Idle cards source review r1

Franklin independent source-only FAIL: P2 prewarming admission did not exclude zero-delta parent .hold. No source edits/tests/UI by reviewer. Other inspected key/cancellation/strict-consume/old-control revocation paths had no actionable finding.

Repair: separate owner canPrepare, wired weakly to !navigator.isTransitioning, no change to shared navigation canTransition. Hold resolving without pager now notifies readiness; actual navigator/surface/owner regression added.
