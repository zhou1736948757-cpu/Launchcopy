# Outward Hide static hypotheses (not a physical diagnosis)

Date:2026-10-23. Read-only explorer Locke, agent01a16457-e6ca-74b2-825d-cc062e22856e, nowclosed. No builds/tests/native operations by explorer.

Observed code: optionaloutward path retains original provider timestamp; historicinward-only path aligns to currentclock. Productionbackend anchors firstcallback to systemUptime, subsequenttimestamps use callbackdelta; PinchSystemClock also uses systemUptime. Therefore a clockdomain mismatch is NOT established, but callbackdelta drift/future/expiry remains untested by existing equalclock mocks.

Other static hypotheses: silencecomparison now-minus-previoussourcetime mixes deliveryage with interframegap; one rejectedterminal may leave consumerquarantined while backend hasalreadyclosed its session andsuppresses furtheremptyframes; backendall-newIDs synthesizes began while recognizer stillrequires explicitrelease; fourcontact baseline/minradius and fixed15% growth can rejectparticularmotions; unknowndevicefallback may mixstreams. Each has source-derivedconditions, no actualusercontact/time trace. No physicalrootcause or fix follows.

Main prioritizes bounded neutral inputdelivery/time/reject/admission/cancellation counters. No change to recognition/threshold/freshness/release/guards before evidence. Existing rawreference-excluded rule preserved. Newdeliveryprobe is not a behavioral fix.
