# Foundry run invalidated

Run `019f4bec-43dc-742b-80b0-e42b7d46ebdd` is **not an authoritative Green implementation lineage**.

Although its final corrected red suite reported 277/277 passing, the Phase 3 barrier audit found P0 information-barrier violations in Green revision prompts:

- `phase2/green-team-revision5.json` disclosed Red-review assertion categories and status.
- `phase2/green-team-revision6.json` disclosed that a named failure was a Red harness defect.
- `phase2/green-team-revision7.json` disclosed a Red oracle diagnosis and exact remediation.
- At least one envelope also had non-replayable `visible_context` hash metadata.

No implementation from this Green workspace may be merged or used as the base of a replacement Green implementation. The source branch remained at the untouched product baseline; only Red tests and run evidence were committed.

The Phase 3 implementation and test review findings are preserved in `reviews/phase3/final-review-results.json`. A fresh Foundry run must restart from the committed product baseline and use:

1. a physically fresh Green workspace without Red/spec/run artifacts;
2. PromptEnvelope hashes over the exact serialized `content` values;
3. Green prompts containing only Data Model + How + PASS/FAIL labels;
4. no orchestrator diagnosis, Red-review conclusion, assertion category, or raw diagnostic;
5. dispatch-time workspace manifests and final barrier replay.
