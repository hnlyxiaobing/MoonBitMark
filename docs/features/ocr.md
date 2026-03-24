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
- PDF recovery-path OCR evidence, still experimental
- PDF `diag-json` / diagnostics 会区分 route 标记、是否真正尝试 OCR、以及 recovery path 是否实际介入

## Behavior contract

- OCR should not silently become a hard requirement for non-OCR conversions.
- Missing backend, timeout, or bridge failure should produce warnings/diagnostics instead of crashing the whole conversion.
- `diag-json` metadata should reflect the configured OCR mode/backend/lang/timeout and the actual attempt/availability result when OCR runs.

## Automated checks

```powershell
powershell -File tests/ocr/ocr_force_smoke.ps1
powershell -File tests/ocr/ocr_backend_missing.ps1
powershell -File tests/ocr/ocr_timeout_smoke.ps1
```

These scripts cover:

- successful mock OCR
- missing `tesseract` backend
- backend timeout

## Limits

- no bbox/layout OCR protocol
- no HTML remote-image OCR
- PDF OCR is still a recovery path, not a mature page-rendering pipeline
