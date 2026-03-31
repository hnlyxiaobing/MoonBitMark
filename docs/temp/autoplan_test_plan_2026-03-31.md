# MoonBitMark Improvement Round Test Plan

Date: 2026-03-31
Plan: `docs/temp/current_project_improvement_plan_2026-03-31.md`

## Current Validation Status

Already completed in this round:

1. `moon test --enable-coverage`
2. `moon coverage analyze`
3. `moon check`
4. `moon test`
5. `tests/integration/mcp_stdio_smoke.ps1`
6. `moon test src/formats/html`
7. `python tests/conversion_eval/scripts/run_eval.py run`
8. `moon build --target native --release`

Still expected before final closeout:

- none

## Scope

This test plan covers the planned improvement round focused on coverage-tooling repair, documentation truth-surface cleanup, MCP STDIO boundary hardening, and limited maintainability refactors.

## Test Matrix

| Area | Change Type | Validation | Why |
| --- | --- | --- | --- |
| Coverage tooling | compiler/build workflow | `moon test --enable-coverage` | proves the coverage compile path is no longer broken |
| Coverage reporting | reporting workflow | `moon coverage analyze` | proves the reporting command path actually works |
| Developer docs | doc truth surface | manual link/path review + targeted grep | catches stale primary links or broken references |
| MCP STDIO | protocol hygiene | `tests/integration/mcp_stdio_smoke.ps1` | ensures stdout remains protocol-safe |
| Main product path | regression safety | `moon check`, `moon test` | catches broad regressions from cleanup/refactors |
| Shared conversion behavior | output quality | `python tests/conversion_eval/scripts/run_eval.py run` when refactors touch shared converter behavior | catches silent behavior drift in large-file splits |
| Windows warning cleanup | native build output | `moon build --target native --release` or `scripts/build.bat` if warning triage is attempted | verifies build output did not regress |

## Key Codepaths To Verify

1. Coverage compile path through `src/libzip/zip_spec.mbt`.
2. README and judge-facing docs no longer route readers to stale planning docs as current truth.
3. MCP request loop still handles `initialize`, `tools/list`, `tools/call`, and notification-without-response behavior.
4. Any refactored format package still produces identical or intentionally reviewed output on existing tests and eval fixtures.

## Failure Modes To Catch

1. Coverage fix compiles only in one mode, but still fails under analysis.
2. Doc cleanup removes discoverability for historical material instead of merely de-emphasizing it.
3. MCP logger changes accidentally write to stdout and corrupt JSON-RPC framing.
4. File splits in PDF/HTML/EPUB create subtle ordering or normalization regressions.
5. Windows warning investigation grows into a toolchain migration by accident.

## Recommended Execution Order

1. `moon test --enable-coverage`
2. `moon coverage analyze`
3. `moon check`
4. `moon test`
5. `tests/integration/mcp_stdio_smoke.ps1` if MCP path changed
6. `python tests/conversion_eval/scripts/run_eval.py run` if shared conversion code changed
7. native build check only if Windows-warning work is in scope

## Exit Gate

The round is not ready to land unless the changed workstream's primary validation passes and no source-of-truth doc points users toward stale state as if it were current.

Current read:

- coverage, doc-cleanup, MCP hardening, refactor-slice validation, and debt-sequencing review gates are satisfied
