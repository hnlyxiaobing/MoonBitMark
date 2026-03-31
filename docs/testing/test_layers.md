# Test Layers

This repository now separates "quality" from "feature existence" explicitly.

## Layers

| Layer | Goal | Primary entrypoints | What it proves | What it does not prove |
| --- | --- | --- | --- | --- |
| `quality` | Measure output quality across curated fixtures | `tests/conversion_eval/scripts/run_eval.py run` | Markdown quality against expected references | CLI exit behavior, MCP transport wiring, OCR backend availability |
| `integration` | Verify public entrypoints actually close the loop | `tests/integration/mcp_stdio_smoke.ps1`, `tests/integration/mcp_http_smoke.ps1` | Public MCP entrypoints can receive and answer verified requests | Full MCP protocol coverage or long-running server semantics |
| `cli` | Verify public command surface, success paths, and negative paths | `tests/cli/cli_smoke.ps1`, `tests/cli/cli_negative.ps1` | Argument parsing, output behavior, error signaling | Conversion quality on broad corpora |
| `ocr` | Verify OCR success/failure diagnostics are predictable | `tests/ocr/ocr_force_smoke.ps1`, `tests/ocr/ocr_backend_missing.ps1`, `tests/ocr/ocr_timeout_smoke.ps1` | Mock success, missing backend, timeout behavior | Real OCR accuracy across languages/layouts |
| `mcp` | Track MCP separately from CLI and quality | `tests/integration/mcp_stdio_smoke.ps1`, `tests/integration/mcp_http_smoke.ps1` | Verified STDIO + loopback HTTP request/response paths, static resources/prompts, and runtime boundary enforcement | SSE, streaming, auth, remote upload semantics |
| `baseline-comparison` | Compare MoonBitMark against external tools | `run_eval.py run --compare-baselines`, optional CI manual job | External baseline deltas when env is prepared | Default local availability; this layer is optional by design |

## Rule

Do not treat `conversion_eval` pass rate or average score as proof that CLI, MCP, or OCR are "implemented". A high quality score only proves the evaluated cases converted well.

## Current First-Phase Mapping

- TASK-002: `integration` / `mcp`
- TASK-003 and TASK-004: `cli`
- TASK-006: `ocr`
- TASK-007: this document
- TASK-009: CI wiring plus optional `baseline-comparison`
