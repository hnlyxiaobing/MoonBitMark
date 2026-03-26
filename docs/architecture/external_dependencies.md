# External Dependencies And Runtime Boundaries

This document is the source of truth for "pure MoonBit" versus "bridge/process-backed" behavior.

## Capability Map

| Area | Pure MoonBit | External dependency | Default state | Verification |
| --- | --- | --- | --- | --- |
| TXT / CSV / JSON / HTML structure / DOCX / PPTX / XLSX / EPUB container parsing | Yes | None | Core path | `moon test`, `conversion_eval` |
| PDF native extraction | Mostly | `bobzhang/mbtpdf` MoonBit package dependency | Core path | `moon test`, `conversion_eval` |
| PDF fallback bridge | No | Python runtime plus `scripts/pdf/bridge.py`, and `pdfminer` when used | Optional fallback | PDF tests and manual bridge checks |
| OCR | No | Python runtime plus `scripts/ocr/bridge.py`; backend may be `mock` or system `tesseract` | Optional capability | `tests/ocr/*.ps1` |
| MCP STDIO server | Yes for current minimal loop | No extra runtime beyond built binary | Experimental entrypoint | `tests/integration/mcp_stdio_smoke.ps1` |
| Conversion eval baselines | No | Python env with `markitdown` / `docling` | Optional/manual | `run_eval.py run --compare-baselines` |
| Portable source validation (Linux/macOS) | Yes for source-level check/test | Runner toolchain and MoonBit install | CI validates `moon check` / `moon test` only | `.github/workflows/ci.yml` |
| Native Windows build | No | MSVC toolchain, `cl.exe`, vcvars environment | Required for native release builds on Windows | `scripts/build.bat`, CI |

## OCR Boundary

- MoonBit invokes `python scripts/ocr/bridge.py ...`.
- `mock` is the stable automated test backend.
- `tesseract` depends on a system executable on `PATH`.
- `auto` means "use an available backend if one exists"; it is not a guarantee that OCR is present.

## PDF Boundary

- The main PDF path stays inside the MoonBit project structure.
- Fallback extraction may shell out through `scripts/pdf/bridge.py`.
- PDF OCR remains a recovery path, not a full page-rendering/layout engine.

## Baseline Comparison Boundary

- Latest local eval summary currently reports `markitdown` and `docling` as unavailable by default.
- Baseline comparison is therefore treated as an optional environment, not a guaranteed always-on step.
- CI now exposes a manual path to run baseline comparison when maintainers choose to provision that environment.

## Build And Package Identity

### Compiler strategy

- `moonpkg.json` currently pins Windows native builds to `cl.exe`.
- `scripts/build.bat` and `scripts/test.bat` load `MOONBITMARK_VCVARS64` before invoking `moon`.
- CI now distinguishes between:
  - portable source validation on Linux/macOS via `moon check` / `moon test`
  - Windows-only native release validation via MSVC

This is intentional. The assumption is now documented instead of being implied.

### Module identity

- `moon.mod.json` keeps the module name `moonbitlang/moonbitmark`.
- That name remains the canonical MoonBit import identity for packages under `src/` and `cmd/`.
- Repository hosting and local checkout path do not change that public module identity.
