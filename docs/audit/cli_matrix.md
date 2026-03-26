# CLI Matrix

Validated against:

- `tests/cli/cli_smoke.ps1`
- `tests/cli/cli_negative.ps1`
- direct local runs on `2026-03-26`

Notes:

- `--dump-ast` emits strict JSON for the normalized `@ast.Document` schema and is validated by parsing the output in smoke coverage.
- `--ocr-backend missing_backend` is accepted by argument parsing; unsupported backend is reported as a runtime OCR warning, not a parse error.

## Option Matrix

| Surface | Success example | Failure example | Automated by |
| --- | --- | --- | --- |
| `--help` | `main.exe --help` prints usage and exits `0` | N/A | `tests/cli/cli_smoke.ps1` |
| default convert | `main.exe sample.txt out.md` writes Markdown and prints `Converted:` | unsupported extension / missing file | smoke + negative |
| `--frontmatter` | `main.exe --frontmatter sample.txt` emits YAML frontmatter | generic parse failure if no input is supplied | `tests/cli/cli_smoke.ps1` |
| `--plain-text` | `main.exe --plain-text sample.txt` preserves plain text output | generic parse failure if no input is supplied | `tests/cli/cli_smoke.ps1` |
| `--no-metadata` | `main.exe --no-metadata --diag-json sample.txt` returns empty `metadata` object | generic parse failure if no input is supplied | `tests/cli/cli_smoke.ps1` |
| `--asset-dir <dir>` | `main.exe --asset-dir assets image.jpg image.md` writes extracted asset files | `main.exe --asset-dir` fails with `Missing directory after --asset-dir` | `tests/cli/cli_smoke.ps1` + manual |
| `--ocr off|auto|force` | `main.exe --ocr force --ocr-backend mock --diag-json image.jpg` reflects OCR metadata | `main.exe --ocr sometimes image.jpg` fails with `Invalid OCR mode` | smoke + negative |
| `--ocr-lang <lang>` | `main.exe --ocr force --ocr-lang chi_sim ...` reflects `ocr_lang=chi_sim` | `main.exe --ocr-lang` fails with `Missing language after --ocr-lang` | smoke + manual |
| `--ocr-images` | accepted and reflected as `ocr_images=true` in metadata | no dedicated parse failure; only meaningful with OCR-enabled flows | `tests/cli/cli_smoke.ps1` |
| `--ocr-backend <backend>` | `main.exe --ocr-backend mock ...` selects mock backend | `main.exe --ocr-backend` fails with `Missing backend after --ocr-backend` | smoke + manual |
| `--ocr-timeout <ms>` | `main.exe --ocr-timeout 2500 ...` reflects timeout metadata | missing value or non-digit input fails | smoke + manual |
| `--diag-json` | `main.exe --diag-json sample.txt` emits diagnostics JSON | `main.exe --diag-json --dump-ast sample.txt` is rejected | smoke + manual |
| `--detect-only` | `main.exe --detect-only --diag-json sample.txt` reports converter selection without conversion | output path or `--dump-ast` combination is rejected | smoke + manual |
| `--dump-ast` | `main.exe --dump-ast sample.html` emits strict JSON for the normalized AST document | incompatible with `--detect-only` or `--diag-json` | smoke + manual |
| `--debug` | `main.exe --debug sample.txt out.md` prints debug report after file write | generic parse failure if no input is supplied | `tests/cli/cli_smoke.ps1` |

## Negative Path Matrix

| Scenario | Expected behavior | Automated by |
| --- | --- | --- |
| unknown option | non-zero exit, `Unknown option` in output | `tests/cli/cli_negative.ps1` |
| missing required option value | non-zero exit, option-specific error message | `tests/cli/cli_negative.ps1` |
| incompatible flag combination | non-zero exit, explicit combination error | `tests/cli/cli_negative.ps1` |
| missing input | non-zero exit, `Missing input path or URL` | `tests/cli/cli_negative.ps1` |
| nonexistent file | non-zero exit, OS file-open failure text | `tests/cli/cli_negative.ps1` |
| unsupported extension | non-zero exit, `Unsupported input` | `tests/cli/cli_negative.ps1` |
| output path conflict | non-zero exit, `Output path conflicts with input path` | `tests/cli/cli_negative.ps1` |

## Recommended Validation Order

1. `moon check`
2. `moon test`
3. `moon build --target native --release`
4. `powershell -File tests/cli/cli_smoke.ps1`
5. `powershell -File tests/cli/cli_negative.ps1`
