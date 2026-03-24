# MoonBitMark

MoonBitMark is a MoonBit document-to-Markdown engine with a shared conversion pipeline, a CLI frontend, and an experimental MCP STDIO entrypoint.

## Supported Inputs

- TXT
- CSV
- JSON
- PDF
- image files
- HTML / XHTML / URL
- DOCX
- PPTX
- XLSX
- EPUB

## Capability Boundary

- CLI is the primary public entrypoint.
- OCR is optional and bridge-backed: MoonBit shells out to `python scripts/ocr/bridge.py`, with `mock` for tests and `tesseract` as a real backend option.
- PDF keeps a MoonBit-native main path, but fallback extraction may use `scripts/pdf/bridge.py`.
- MCP currently means a minimal experimental STDIO server, not a fully mature protocol surface.
- `conversion_eval` measures quality; it is not proof that CLI/MCP/OCR entrypoints are fully wired.

Details: `docs/architecture/external_dependencies.md`

## Commands

Core development:

```bash
moon check
moon test
moon info
moon fmt
```

Windows native release build:

```bat
scripts\build.bat
```

Run the CLI:

```bash
_build/native/release/build/cmd/main/main.exe <input> [output]
```

Run the experimental MCP smoke check:

```powershell
powershell -File tests/integration/mcp_stdio_smoke.ps1
```

## Validation

Current first-phase validation entrypoints:

- `tests/cli/cli_smoke.ps1`
- `tests/cli/cli_negative.ps1`
- `tests/ocr/ocr_force_smoke.ps1`
- `tests/ocr/ocr_backend_missing.ps1`
- `tests/ocr/ocr_timeout_smoke.ps1`
- `tests/integration/mcp_stdio_smoke.ps1`
- `tests/conversion_eval/scripts/run_eval.py run`

Latest local quality summary in `tests/conversion_eval/reports/latest/summary.md` reports:

- `29/29` passed
- average score `0.9964`
- `archive / web / ocr` clusters all fully passed in the current local run

## Docs

- `docs/audit/placeholder_audit.md`
- `docs/audit/cli_matrix.md`
- `docs/testing/test_layers.md`
- `docs/architecture/external_dependencies.md`
- `docs/features/ocr.md`
- `docs/features/mcp.md`
- `AGENTS.md`

## Current Limits

- MCP is still experimental: STDIO only, verified on `initialize`, `tools/list`, and `tools/call`.
- OCR success depends on an external backend; `auto` does not guarantee one exists.
- `--dump-ast` currently emits MoonBit Json text rather than strict JSON.
- Baseline comparison against `markitdown` / `docling` is optional and environment-dependent.

## License

Apache-2.0
