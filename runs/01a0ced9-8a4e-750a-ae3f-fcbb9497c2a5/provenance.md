# Web HTML Safety Foundry Retry

- Run UUIDv7: `01a0ced9-8a4e-750a-ae3f-fcbb9497c2a5`
- Date: 2026-09-23
- Baseline: `bb28284`; committed plan: `2d11a35`
- NLSpec: `docs/nlspecs/2026-07-10-web-html-component-safety.nlspec.md`
- Plan: `docs/plans/2026-09-23-web-html-safety-retry-plan.md`
- Planner: `gpt-6-sol` (high)
- Green implementer: `gpt-6-luna` (xhigh), with a fresh Luna context for late evaluator corrections
- Reviewer and Red corpus repair: `gpt-6-sol` (high)

## Isolation and evidence

Green worked under `/private/tmp/jasonette-web-html-01a0ced9-8a4e-750a-ae3f-fcbb9497c2a5/`. Its initial input was NLSpec sections 1–5 and the implementation plan. That workspace had no `.git`, `runs/`, spec, or Definition of Done. For each Red run, the orchestrator temporarily copied the Red suite into the workspace, ran it, and removed the overlay before sending Green only test-name PASS/FAIL outcomes. The final overlay is absent. The original July run corpus remains untouched; this run's corrected corpus is under `red/`.

The coverage-map verifier reports **340 Vitest cases and 340 expanded Gherkin scenarios**, covering 53 automated Definition of Done items. Two items require external evidence. The public type contract also compiles with `npx tsc --project runs/01a0ced9-8a4e-750a-ae3f-fcbb9497c2a5/red/tests/tsconfig.public-types.json`.

| Iteration | Red corpus state | PASS | FAIL | Note |
| --- | --- | ---: | ---: | --- |
| 1 | Original July corpus | 262 | 36 | Initial Luna implementation |
| 2 | Original July corpus | 263 | 35 | Green correction |
| 3 | Partly repaired copy | 269 | 29 | Red fixture repairs in progress |
| 4 | Repaired copy | 298 | 0 | First converged candidate |
| 5 | Added getter case | 299 | 0 | Case later replaced because it overconstrained legacy `$jason` lookup |
| 6 | Corrected collision case | 298 | 1 | Green collision precedence regression |
| 7 | Split precedence/order cases | 300 | 0 | Reviewer then found uncovered special-name cases |
| 8 | Expanded compatibility corpus | 313 | 1 | Reverse getter insertion order |
| 9 | Corrected 314-case corpus | 314 | 0 | Reviewer then found body-key alias collision gap |
| 10 | Body-key collision corpus | 327 | 0 | Reviewer then found member-root collision gap |
| 11 | Final corrected corpus | **340** | **0** | Final isolated Green source |

Full Red output and filtered outcomes for all 11 iterations are in `withheld/iterationN-raw.json` and `outcomes/iterationN.txt`. The pre-correction source digest is in `green-source-frozen.sha256`. The final digest in `green-source-final.sha256` covers each source path and bytes, sorted under `packages/template-engine/src` and `packages/web-renderer/src`, separated by NUL bytes. Main checkout and isolated Green source match that digest.

## Local verification on final source

All eight exact commands in NLSpec section 3.6 passed on the review branch: focused template tests (34), focused Web tests (72), both typechecks, both builds, full template tests (141), and full Web tests (102, including CLI). The public type contract compiled. No local CLI timeout occurred. `git diff --check` passed.

## Barrier and acceptance audit

During the third Green pass, the orchestrator sent one qualitative note about Red observer/test defects rather than only test-name PASS/FAIL. This breached the Foundry feedback rule. That recipient made no product edits afterward. Later evaluator work used a fresh Luna context, and its test feedback contained only names with PASS/FAIL. The deviation remains part of the run record; this is not a claim that the historical strict barrier was flawless.

The reviewer found and repaired incorrect inherited Red fixtures and an overconstrained getter case before final acceptance testing. Red changes were confined to this run's copied corpus. The final read-only review found no remaining concrete product defect and independently passed 28 built-package compatibility vectors. All jobs passed in [CI run 35895845382](https://github.com/Bande-a-Bonnot/JASONETTE-Reborn/actions/runs/35895845382) at PR head `44170efdec529dc4efd962c617684bd85a014d3b`, whose product source digest matches `green-source-final.sha256`. Draft PR #25 remains unmerged. jsdom evidence establishes renderer-owned attribute and operation order; browser-enforced sandbox behavior remains a browser-platform assumption under the NLSpec.
