# OCR Support

## Status

OCR is an **optional capability layer**, not a guaranteed built-in runtime feature.

MoonBitMark calls:

```text
python scripts/ocr/bridge.py ...
```

So OCR availability depends on both:

- a Python runtime
- a selected backend (`mock`, `tesseract`, or whatever `auto` can find)
- for PDF recovery, a Python environment that can render PDF pages (the bridge will delegate to the local baseline venv when needed)

## CLI Surface

```text
--ocr <off|auto|force>
--ocr-lang <lang>
--ocr-images
--ocr-backend <auto|mock|tesseract>
--ocr-timeout <ms>
```

## Backends

| Backend | Purpose | Expected use |
| --- | --- | --- |
| `mock` | deterministic fake OCR text | automated tests |
| `tesseract` | real OCR via system executable | manual/local validation |
| `auto` | use an available backend if one exists | convenience mode, not a guarantee |

## Current coverage

- image-file OCR
- embedded-image OCR for DOCX / PPTX / EPUB when `--ocr-images` is enabled
- PDF OCR recovery now renders the requested recovery pages through the Python bridge and injects page-specific OCR text back into the PDF pipeline
- mixed PDF documents can recover only the routed OCR pages instead of requiring the whole document to be recovery-only
- PDF `diag-json` / diagnostics distinguish route marking, text fallback usage, and whether OCR recovery actually intervened

## Behavior contract

- OCR should not silently become a hard requirement for non-OCR conversions.
- Missing backend, timeout, or bridge failure should produce warnings/diagnostics instead of crashing the whole conversion.
- `diag-json` metadata should reflect the configured OCR mode/backend/lang/timeout and the actual attempt/availability result when OCR runs.
- PDF text extraction fallback (`pdfminer`) and OCR recovery are tracked separately; OCR recovery should not be mislabeled as `pdf_text_fallback_used`.

## Automated checks

```powershell
powershell -ExecutionPolicy Bypass -File tests/ocr/ocr_force_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/ocr/ocr_backend_missing.ps1
powershell -ExecutionPolicy Bypass -File tests/ocr/ocr_timeout_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/ocr/pdf_ocr_force_smoke.ps1
```

These scripts cover:

- successful mock OCR
- missing `tesseract` backend
- backend timeout
- multi-page PDF OCR recovery with page-specific mock output

## Limits

- no bbox/layout OCR protocol
- no HTML remote-image OCR
- PDF OCR recovery is still a bounded bridge-assisted path, not a full document-layout understanding system
