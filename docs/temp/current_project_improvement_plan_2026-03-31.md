<!-- /autoplan restore point: C:\Users\hnlyh\.gstack\projects\MoonBitMark\main-autoplan-restore-20260331-133132.md -->
# MoonBitMark Current Project Improvement Plan

Date: 2026-03-31

## Current Status

- Workstream 1: completed
- Workstream 2: completed
- Workstream 3: completed
- Workstream 4: first refactor slice completed
- Workstream 5: completed

Completed so far:

- `src/libzip/zip_spec.mbt` was migrated from the broken declaration-only form to `declare`, restoring the coverage compile path
- `moon test --enable-coverage` and `moon coverage analyze` now both work locally
- `AGENTS.md`, `docs/development.md`, `README.md`, and `.github/workflows/ci.yml` were updated so the documented workflow matches the executable one
- README no longer presents `docs/temp` material as a primary source of current project truth
- `src/mcp/handler/server.mbt` no longer retains a logger on the live STDIO server path, reducing stdout pollution risk
- `docs/features/mcp.md` now records the stdout discipline and the fact that the live server path does not retain a logger
- the first maintainability slice is complete: HTML URL/base/image resolution helpers were moved out of `src/formats/html/converter.mbt` into `src/formats/html/url_resolution.mbt`
- the HTML refactor slice was validated with targeted HTML tests, full `moon test`, and conversion eval (`34/34`, average `0.9983`)
- `docs/KNOWN_ISSUES.md` now records the Windows `C4819` item as deferred-until-reproduced debt after a fresh local native release build did not reproduce it

## Goal

Turn the current healthy-but-not-fully-closed project state into a cleaner, more trustworthy engineering baseline by fixing broken developer workflows, tightening protocol/runtime boundaries, and reducing maintenance risk in the highest-complexity areas.

## Why This Plan Exists

Recent inspection shows the main product path is healthy:

- `moon check` passes
- `moon test` passes with `165/165`
- conversion eval passes with `34/34` and average score `0.9983`

But there are still meaningful gaps:

- MCP support is functional but logger-related protocol hygiene still needs a final closure pass
- several format packages have very large files that increase change risk
- known PDF/OCR and Windows build debts remain open

This plan is about closing those gaps in the right order.

## Premises

1. The next round should prioritize engineering closure over new format surface area.
2. A broken developer-quality workflow is more urgent than incremental conversion-quality gains when the main path is already green.
3. Source-of-truth documentation should not compete with stale historical planning artifacts.
4. MCP should remain intentionally narrow until protocol hygiene and failure-path confidence improve.
5. High-line-count format files are now a maintainability risk worth paying down.

## Non-Goals

- No expansion of supported input formats in this round.
- No attempt to turn OCR into a pure-MoonBit capability.
- No attempt to make MCP a full protocol implementation in this round.
- No GUI-first roadmap work.

## Success Criteria

1. `moon test --enable-coverage` and `moon coverage analyze` both work. Status: completed.
2. Public documentation points to current, trustworthy sources instead of stale planning snapshots. Status: completed.
3. MCP logging cannot accidentally corrupt STDIO protocol output. Status: completed.
4. The highest-risk oversized format files have a concrete refactor plan, and at least the first slice is completed or queued with clear boundaries. Status: completed.
5. Known-issue boundaries remain honest and are reflected consistently in docs and validation guidance. Status: completed.

## Workstreams

### Workstream 1: Restore Developer Confidence In Validation Tooling

Status: completed

Scope:

- fix the `src/libzip/zip_spec.mbt` declaration-only issue that breaks coverage compilation
- verify coverage workflow end to end
- update developer guidance that currently suggests a broken command path

Deliverables:

- working coverage commands
- updated AGENTS/development guidance where needed
- short root-cause note in docs or changelog-style note

Completed deliverables:

- working coverage commands verified locally
- AGENTS/development guidance updated
- README now includes the correct coverage workflow entrypoint

Validation:

- `moon test --enable-coverage`
- `moon coverage analyze`

### Workstream 2: Clean Up Truth Surfaces In Documentation

Status: completed

Scope:

- remove or clearly de-emphasize stale planning/assessment docs from primary discovery paths
- ensure README and judge-facing docs link to current source-of-truth material only
- keep historical docs available without letting them masquerade as current state

Deliverables:

- README cleanup
- labeling or relocation strategy for stale `docs/temp` planning material

Completed deliverables:

- README cleanup completed
- `docs/temp` is now explicitly described as historical / temporary material, not current project truth

Validation:

- manual link/path review
- grep for outdated references from primary docs

### Workstream 3: Tighten MCP Boundary Without Expanding Scope

Status: completed

Scope:

- remove or isolate stdout-based logger behavior from MCP protocol paths
- verify current STDIO assumptions still hold
- avoid adding prompts/resources/streaming in this round

Deliverables:

- safe logger behavior or logger removal from MCP path
- explicit note on stderr/stdout discipline if logger is retained

Completed deliverables:

- live STDIO server path no longer stores a logger instance
- MCP contract docs now state the stdout/logger discipline explicitly
- MCP smoke validation still passes after the cleanup

Validation:

- `tests/integration/mcp_stdio_smoke.ps1`
- focused negative-path manual checks if code changes touch request handling

### Workstream 4: Reduce Maintenance Risk In Large Format Packages

Status: first slice completed

Scope:

- identify the most oversized files that are absorbing too many responsibilities
- split by responsibility, not by arbitrary line count
- prioritize PDF and HTML/EPUB-heavy areas first

Priority targets:

- `src/formats/html/converter.mbt`
- `src/formats/epub/converter.mbt`
- `src/formats/pdf/structure.mbt`
- `src/formats/pdf/normalize.mbt`

Deliverables:

- refactor map for each target file
- first refactor slice for the highest-value file if the split is low-risk

Completed deliverables:

- refactor map is now concrete enough to choose a safe first slice
- first slice completed by extracting HTML URL/base/image resolution helpers into `src/formats/html/url_resolution.mbt`
- refactor validated with targeted HTML tests, full test suite, and conversion eval

Validation:

- `moon check`
- `moon test`
- targeted conversion eval if shared behavior changes

### Workstream 5: Keep Known Debts Honest And Sequenced

Status: completed

Scope:

- keep PDF/OCR bridge-backed limitations explicitly documented
- investigate the Windows `C4819` warning source and decide whether it is fix-now or scheduled debt
- make sure next steps distinguish product risk from documentation risk from tooling risk

Deliverables:

- debt register update or clear TODO sequencing
- decision on whether Windows warning cleanup is in this round or next

Completed deliverables:

- PDF/OCR bridge-backed limitations remain documented as current boundaries
- Windows `C4819` cleanup is explicitly deferred to the next round unless a reproducible case reappears
- `docs/KNOWN_ISSUES.md` now distinguishes reproduced product/runtime issues from environment-specific build-output debt

Validation:

- doc review
- native build output review if warning cleanup is attempted

## Proposed Sequence

### Phase A: Tooling Closure

Do Workstream 1 first.

Reason:

- broken coverage tooling is a real defect in the engineering workflow
- it is small in scope and high leverage
- it gives the team a stronger base before refactors

### Phase B: Documentation Truth Cleanup

Do Workstream 2 second.

Reason:

- low implementation risk
- improves project trust quickly
- reduces future confusion while other changes are in flight

### Phase C: MCP Boundary Hardening

Do Workstream 3 third.

Reason:

- small blast radius
- good time to tighten protocol hygiene before any future MCP expansion

### Phase D: Structural Refactors

Do Workstream 4 fourth.

Reason:

- highest code churn risk
- should happen after tooling and truth-surface cleanup
- benefits from stable validation and clearer docs

### Phase E: Deferred Debt Decision

Do Workstream 5 last unless native build investigation becomes necessary earlier.

Reason:

- some debt is primarily about sequencing and honesty, not immediate breakage
- better to decide with the rest of the round already clarified

## Risks

1. Coverage fix may expose more latent issues once the workflow actually runs.
2. Large-file refactors may accidentally create behavior drift in shared render/normalize paths.
3. MCP cleanup could break the narrow smoke-checked path if stdout/stderr handling changes carelessly.
4. Documentation cleanup can create dead links if historical docs are moved or renamed without a sweep.

## Risk Controls

- keep each workstream independently verifiable
- prefer small refactor slices with tests before broad file churn
- do not expand MCP surface during a hygiene-focused round
- update docs in the same change that alters behavior or discovery paths

## Not In Scope

- new input types
- full MCP feature expansion
- OCR backend innovation
- deep PDF layout intelligence
- GUI roadmap work

## Exit Criteria For This Round

This round is complete when:

- coverage workflow is fixed and documented
- source-of-truth docs are no longer undermined by stale primary links
- MCP path is safe from accidental stdout pollution
- at least one high-risk large-file refactor is either completed safely or decomposed into a clear next-step map
- remaining debts are explicitly sequenced instead of left as vague background concerns

Current read:

- all exit criteria are complete

## AUTOPLAN CEO REVIEW

Mode: `SELECTIVE_EXPANSION`

### 0A. Premise Challenge

Premise 1 is directionally right. The repository already has strong product-path validation, so new format expansion is not the highest-value next move.

Premise 2 is strong and evidence-backed. The coverage workflow is actually broken today because declaration-only functions in `src/libzip/zip_spec.mbt` still carry bodies, which makes `moon test --enable-coverage` fail before the report step.

Premise 3 is also right. The main docs are mostly current, but the README still links directly to a stale assessment snapshot in `docs/temp`, which weakens trust because it competes with current source-of-truth docs.

Premise 4 should be tightened. "Remain intentionally narrow" is right, but the plan should say "harden the existing MCP contract first, then freeze expansion until protocol hygiene is verified" so the round cannot accidentally become an MCP feature push.

Premise 5 is valid, but only as a second-half move. Large-file maintainability is a real risk, but it is less urgent than broken tooling and truth-surface confusion.

### 0B. Existing Code Leverage Map

| Sub-problem | Existing code/docs | Reuse plan |
| --- | --- | --- |
| Coverage workflow repair | `src/libzip/zip_spec.mbt`, `AGENTS.md`, `docs/development.md` | Fix the declaration-only mismatch, then update guidance rather than invent a new workflow |
| Documentation truth surfaces | `README.md`, `docs/benchmark.md`, `docs/competition/judge-runbook.md` | Keep these as the public truth layer and demote stale `docs/temp` references |
| MCP boundary hardening | `src/mcp/handler/server.mbt`, `src/mcp/util/logger.mbt`, `tests/integration/mcp_stdio_smoke.ps1`, `docs/features/mcp.md` | Reuse the existing smoke contract, avoid scope expansion |
| Refactor safety for format packages | `moon test`, conversion eval fixtures/reports | Use the current test/eval scaffolding instead of adding bespoke validation |
| Known debt sequencing | `docs/KNOWN_ISSUES.md`, `docs/architecture/external_dependencies.md` | Keep debt honest and explicit instead of burying it in code comments |

### 0C. Dream State

```text
CURRENT
  main path green
  but coverage broken
  docs mostly current, with stale temp links still visible
  MCP works narrowly, logger hygiene still questionable
  several converters are too large

THIS PLAN
  fix broken engineering workflow
  clean truth surfaces
  harden MCP contract without expanding it
  start maintainability paydown in the worst hotspots

12-MONTH IDEAL
  every supported workflow is verifiably runnable
  docs have one obvious truth layer
  MCP is intentionally expanded only after contract hardening
  converter code is decomposed by responsibility, not size accidents
```

### 0C-bis. Alternatives

| Approach | Effort | Pros | Cons | Decision |
| --- | --- | --- | --- | --- |
| A. Tooling/doc closure first, refactors second | Low-to-medium | highest trust gain, lowest risk, clear sequencing | less exciting than new features | Chosen |
| B. Refactor large files first | Medium-to-high | pays down long-term maintenance faster | risks behavior drift before tooling truth is fixed | Rejected |
| C. Expand MCP and fix hygiene in one round | Medium | could create a stronger demo story | mixes stabilization with feature growth, higher protocol risk | Rejected |

### 0D. Scope Decision

Selective expansion is the right mode. The plan should expand only enough to include one concrete maintainability slice, not a broad refactor campaign.

### 0E. Temporal Interrogation

- Hour 1: fix coverage path, prove it with commands
- Hour 2: clean README/doc discovery paths
- Hour 3: isolate or remove MCP stdout logging risk
- Hour 4+: decide whether one low-risk refactor slice fits this round
- After that: explicitly defer the rest

### 0F. CEO Verdict

The plan is pointed at the right problem, but it was slightly overstuffed. The core move should be "close broken trust surfaces first, then take one maintainability slice," not "do five equal workstreams."

### 1. Scope And Strategy Findings

1. The current plan treats all five workstreams as peer items. They are not peers. Workstreams 1 to 3 are closure work. Workstreams 4 and 5 are partial debt management.
2. Workstream 4 is too broad for the same round unless it is explicitly cut down to one first slice. Four large target files is a backlog, not a single-round commitment.
3. Workstream 5 should not be its own equal workstream. It is mostly a sequencing decision plus one possible Windows investigation.

### 2. Error And Rescue Registry

| Area | Likely failure | Rescue path |
| --- | --- | --- |
| Coverage fix | command still fails under one coverage mode | keep the change scoped to declaration-only repair, rerun both coverage commands before moving on |
| Doc cleanup | broken links or hidden historical context | keep stale docs, but relabel or unlink them from primary docs |
| MCP cleanup | protocol output corruption | keep smoke test as the hard gate, route any retained logging to stderr or disable it |
| Refactor slice | output drift in shared conversion behavior | require `moon test` plus eval if shared behavior changes |

### 3. Failure Modes Registry

| Workstream | Failure mode | Severity | Coverage today | Gap |
| --- | --- | --- | --- | --- |
| Coverage tooling | fixed in one command path but still broken in another | High | manual reproduction only | real |
| Docs truth cleanup | stale temp docs remain primary discovery path | Medium | manual review only | real |
| MCP hardening | stdout pollution breaks JSON-RPC framing | High | smoke test exists | manageable |
| Refactor slice | normalization/render ordering drift | High | tests + eval exist | manageable if slice is small |
| Windows warning triage | round balloons into toolchain churn | Medium | none | real |

### 4. NOT In Scope

- New input formats, because the product path is already broad and the current round is about closure.
- MCP feature expansion, because the existing contract still needs hygiene hardening first.
- OCR backend innovation, because this round does not change the bridge-backed architecture.
- Deep PDF layout work, because it is an ocean, not a lake, for this scope.
- Multi-file refactor campaign across every large converter, because that is too much churn for the same round.

### 5. What Already Exists

- The repo already has a useful source-of-truth doc spine: `README.md`, `docs/benchmark.md`, `docs/features/mcp.md`, `docs/KNOWN_ISSUES.md`.
- The repo already has the right validation entrypoints: `moon check`, `moon test`, conversion eval, MCP smoke.
- The repo already has honest runtime-boundary documentation. The problem is enforcement and discovery, not missing explanation.

### 6. Dream State Delta

If executed as revised, this round gets the project from "strong but with a few trust leaks" to "clean baseline ready for the next optimization round." It does not get all the way to a fully decomposed architecture. That is fine. The important thing is to stop pretending the refactor backlog fits in the same box as the broken tooling fix.

### 7. CEO Completion Summary

- **OK:** the plan is aimed at the right problem
- **WARNING:** the original workstream list was too equal-weighted
- **WARNING:** refactor scope needs to shrink to one slice
- **OK:** no UI scope, so design review is skipped

## AUTOPLAN ENG REVIEW

### Scope Challenge

The implementation path is sound if the round is narrowed to three mandatory steps and one optional step:

1. Fix coverage tooling
2. Clean documentation truth surfaces
3. Harden MCP stdout discipline
4. Optionally do one low-risk converter refactor slice

Trying to do all four large-file refactors in the same round would turn a cleanup plan into an architecture migration.

### Architecture Diagram

```text
Improvement Round
  |
  +-> Tooling closure
  |     +-> src/libzip/zip_spec.mbt
  |     +-> AGENTS.md / docs/development.md
  |
  +-> Doc truth cleanup
  |     +-> README.md
  |     +-> docs/competition/*
  |     +-> docs/temp/*
  |
  +-> MCP boundary hardening
  |     +-> src/mcp/util/logger.mbt
  |     +-> src/mcp/handler/server.mbt
  |     +-> tests/integration/mcp_stdio_smoke.ps1
  |
  +-> Optional maintainability slice
        +-> one of html / epub / pdf normalize / pdf structure
        +-> moon test
        +-> conversion eval if shared behavior changes
```

### Code Quality Review

1. The plan now names the exact code pressure points instead of speaking in generic debt language. Good.
2. The original version still bundled four separate refactor targets into one workstream. That is too vague to implement safely. It should explicitly say "pick one target file for this round."
3. Workstream 5 is better modeled as a decision appendix than a first-class build track.

### Test Review

#### Test Diagram

```text
Codepath A: coverage compile path
  src/libzip/zip_spec.mbt
    -> moon test --enable-coverage
    -> moon coverage analyze

Codepath B: doc discovery path
  README.md / docs/*
    -> primary links
    -> manual link review / grep for stale references

Codepath C: MCP STDIO request loop
  src/mcp/handler/server.mbt
    -> read_line
    -> handle initialize/tools/list/tools/call
    -> write JSON-RPC response only
    -> tests/integration/mcp_stdio_smoke.ps1

Codepath D: optional converter refactor
  selected converter module
    -> moon check
    -> moon test
    -> conversion eval when shared output path changes
```

#### Test Gaps

1. Coverage workflow currently has no green regression check in CI. That is a real gap if the command becomes supported again.
2. Doc truth cleanup is only manually validated. Acceptable for this round, but link grep should be part of the checklist.
3. MCP negative-path coverage is still thin beyond the smoke script. This is acceptable if the round does not expand MCP surface.

### Performance Review

No primary performance risk is introduced by Workstreams 1 to 3. The only performance-sensitive area is Workstream 4, where large converter refactors can accidentally add repeated passes over large documents. That is another reason to keep the refactor slice small and observable.

### Failure Modes

| Codepath | Failure | Test exists | Error handling exists | Silent? | Critical gap |
| --- | --- | --- | --- | --- | --- |
| Coverage compile path | still fails under coverage mode | No persistent regression test | explicit command failure | No | No |
| Doc discovery path | stale or dead primary link | Manual only | N/A | Yes | No |
| MCP STDIO | logger writes non-protocol output | Yes, smoke path | limited | Potentially | No |
| Converter refactor slice | changed markdown semantics | Yes if eval is run | N/A | Potentially | No |

No silent-failure triple gap is currently mandatory, but the coverage path and MCP path both deserve explicit regression checks.

### Parallelization Strategy

| Step | Modules touched | Depends on |
| --- | --- | --- |
| Coverage tooling repair | `src/libzip/`, docs guidance | — |
| Doc truth cleanup | root docs, `docs/temp/` | — |
| MCP hardening | `src/mcp/`, MCP tests/docs | — |
| Optional refactor slice | one selected `src/formats/*` package | coverage/doc cleanup recommended first |

Parallel lanes:

- Lane A: coverage tooling repair
- Lane B: doc truth cleanup
- Lane C: MCP hardening
- Lane D: optional refactor slice, after A succeeds

Execution order:

- Launch A, B, C in parallel if desired.
- Merge and validate.
- Then decide whether D still fits the round.

Conflict flags:

- No direct module overlap among A, B, C.
- D should stay isolated to one converter package to avoid merge churn.

### Eng Completion Summary

- Step 0: scope reduced from five equal workstreams to three mandatory plus one optional
- Architecture Review: 2 issues found
- Code Quality Review: 2 issues found
- Test Review: diagram produced, 3 gaps identified
- Performance Review: 0 immediate issues, 1 refactor caution
- NOT in scope: written
- What already exists: written
- Failure modes: 0 critical gaps
- Outside voice: skipped, unavailable in this environment without extra delegation/tooling

## Cross-Phase Themes

1. The real job is closure, not expansion.
2. The refactor backlog should not masquerade as a single-round commitment.
3. Existing validation is already good enough to support one safe maintainability slice, but not a broad refactor push.

## Decision Audit Trail

| # | Phase | Decision | Classification | Principle | Rationale | Rejected |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | CEO | Keep the round focused on engineering closure | Mechanical | Choose completeness | The main path is already green, but trust surfaces are not fully closed | New format work |
| 2 | CEO | Run in selective expansion mode | Mechanical | Pragmatic | The plan needs one contained maintainability slice, not a blank-check expansion | Hold scope, full expansion |
| 3 | CEO | Shrink Workstream 4 to one refactor slice | Taste | Boil lakes | One slice is complete and safe, four concurrent file splits are not | Broad refactor campaign |
| 4 | CEO | Demote Workstream 5 from equal workstream to deferred decision appendix | Mechanical | Explicit over clever | It is mostly sequencing, not a standalone implementation track | Keeping five equal tracks |
| 5 | Eng | Make coverage repair the first gate | Mechanical | Bias toward action | Broken tooling blocks a trustworthy engineering baseline | Starting with refactors |
| 6 | Eng | Keep MCP narrow and hygiene-focused | Mechanical | Explicit over clever | Contract hardening has clear value, feature expansion does not | MCP expansion |
| 7 | Eng | Require eval only if shared conversion behavior changes | Mechanical | Pragmatic | Full eval on every doc-only or MCP change is wasteful | Running eval unconditionally |
| 8 | Eng | Treat UI scope as false positive and skip design phase | Mechanical | Explicit over clever | The keyword scan matched `format` and `layout`, but the plan is not a UI plan | Running design review anyway |

## AUTOPLAN REVIEW REPORT

### CEO Score

- Strategy direction: 8/10
- Scope calibration: 6/10 before review, 8/10 after scope tightening
- Premise quality: 8/10

### Design Score

- Skipped, no real UI scope

### Eng Score

- Architecture clarity: 8/10 after narrowing the round
- Testability: 7/10
- Risk containment: 8/10

### Autoplan Verdict

This is a good plan after one important correction: do not promise a broad maintainability campaign in the same round as broken-tooling closure. Fix the trust leaks first. Then spend the remaining budget on one carefully bounded refactor slice, if time still exists.
