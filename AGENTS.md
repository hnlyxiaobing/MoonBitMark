# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Overview

MoonBitMark is a document converter that transforms TXT, CSV, JSON, PDF, image, HTML/XHTML/URL, DOCX, PPTX, XLSX, and EPUB inputs into Markdown. The CLI is the main public entrypoint; OCR is an optional bridge-backed capability, and MCP is currently an experimental STDIO server.

## Commands

```bash
# Type check
moon check

# Build (Release mode, requires MSVC on Windows)
# Use the script for proper MSVC environment:
scripts/build.bat

# Or manually:
moon build --target native --release

# Run the compiled binary
_build/native/release/build/cmd/main/main.exe <input> [output]

# Run tests
moon test

# Run tests with coverage enabled
moon test --enable-coverage

# Analyze coverage after coverage-enabled tests
moon coverage analyze

# Update snapshots after intentional output changes
moon test --update

# Format code
moon fmt

# Update package interfaces (check .mbti diffs for API changes)
moon info

# Combined final step
moon info && moon fmt
```

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- In the toplevel directory, there is a `moon.mod.json` file listing module
  metadata.

### Architecture

```
src/
├── core/           # Core types (ConvertResult, StreamInfo, DocumentConverter trait)
│   ├── types.mbt   # Type definitions
│   └── engine.mbt  # MarkItDown engine
├── libzip/         # Pure MoonBit ZIP library (Store + Deflate)
├── xml/            # Pure MoonBit XML parser (SAX-style)
└── formats/        # Format converters (one subdirectory per format)
    ├── text/       # Plain text (.txt)
    ├── csv/        # CSV → Markdown tables
    ├── json/       # JSON → code blocks
    ├── pdf/        # PDF via mbtpdf library
    ├── html/       # HTML + URL fetching
    ├── docx/       # DOCX via Pure MoonBit (libzip + xml)
    └── pptx/       # PPTX via Pure MoonBit (libzip + xml) - IN DEVELOPMENT
```

**Conversion flow:** CLI → detect format by extension → select converter → read/convert → output Markdown

### Adding a New Converter

1. Create `src/formats/<format>/converter.mbt` with:
   - `XxxConverter` struct
   - `accepts(info: @core.StreamInfo) -> Bool` - check if format matches
   - `convert(file_path: String) -> String raise` - async conversion

2. Create `src/formats/<format>/moon.pkg`:
   ```
   import {
     "moonbitlang/moonbitmark/src/core",
     "moonbitlang/async/fs",
   }
   ```

3. Register in `cmd/main/main.mbt` by adding format detection in `convert_file()`.

## Coding Convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

### MoonBit-Specific Patterns

```moonbit
// String slicing (requires `raise` on function)
let part = s[start:end].to_string()

// Method calls, not functions
s.to_lower()   // ✓
to_lowercase(s) // ✗

// Mutable variables
let mut counter = 0
counter = counter + 1

// Array initialization with type
let arr : Array[String] = Array::new()

// Error types use suberror
suberror MyError { NotFound, InvalidInput(String) }
```

## Tooling

- `moon fmt` is used to format your code properly.

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when
  changes affect outputs, run `moon test --update` to refresh snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. Use snapshot tests to record current
  behavior. For solid, well-defined results (e.g. scientific computations),
  prefer assertion tests. To inspect coverage, first run
  `moon test --enable-coverage`, then run `moon coverage analyze` (optionally
  redirecting to a log file) to see which parts of your code are not covered by
  tests.

## Repo-Scoped Skills

- This repo includes project-scoped skills under `.codex/skills/`.
- When working in this repository, prefer explicitly invoking them with
  `$skill-name` in your prompt when the task matches.
- Common examples:
  - `$moonbit-agent-guide` for general MoonBit development, testing, and `moon`
    tooling workflows.
  - `$moonbit-refactoring` for package-local refactors, renames, and code
    reorganization.
  - `$moonbit-lang` for MoonBit language rules, syntax, and type-system
    questions.
  - `$moonbit-spec-test-development` or `$moonbit-extract-spec-test` for
    spec-driven development and test extraction workflows.
- Repo-scoped skills are preferred over user-global variants when both exist,
  because they can be pinned and updated together with this repository.

## Commit And Push Workflow

- When a development round is complete and the user asks to submit the work, use
  `$moonbitmark-commit-push` to finish the repository state.
- Before committing, inspect `git status --short`, `git diff --stat`, and
  `git diff --name-status` so the commit message is based on the actual change
  scope instead of guessed from filenames alone.
- Run validation that matches the changed files before committing. For MoonBit
  source/package changes, prefer `moon info`, `moon fmt`, and `moon test`. For
  non-MoonBit changes, run the most relevant lightweight verification available.
- Write commit messages in imperative mood with a concise subject line and a
  short body that names the main change areas and any important verification.
- Avoid vague subjects such as `update files`, `misc fixes`, or `cleanup`.
- Stage the intended repository changes, create the commit with the generated
  message, and push the current branch to the configured remote.
- Do not amend, force-push, or rewrite history unless the user explicitly asks
  for it.
- If the worktree contains changes that appear unrelated to the current task and
  the intended commit scope cannot be determined safely, stop and ask the user
  before creating the commit.

### Commit Skill

- `$moonbitmark-commit-push` is the repo-scoped skill for the final
  `status -> validation -> commit message -> commit -> push` workflow.
- Use it when the user asks to "提交", "commit", "push", "提交并推送", or any
  equivalent finalization request.

## Commit And Push Workflow

- When a development round is complete and the user asks to submit the work, use
  `$moonbitmark-commit-push` to finish the repository state.
- Before committing, inspect `git status --short`, `git diff --stat`, and
  `git diff --name-status` so the commit message is based on the actual change
  scope instead of guessed from filenames alone.
- Run validation that matches the changed files before committing. For MoonBit
  source/package changes, prefer `moon info`, `moon fmt`, and `moon test`. For
  non-MoonBit changes, run the most relevant lightweight verification available.
- Write commit messages in imperative mood with a concise subject line and a
  short body that names the main change areas and any important verification.
- Avoid vague subjects such as `update files`, `misc fixes`, or `cleanup`.
- Stage the intended repository changes, create the commit with the generated
  message, and push the current branch to the configured remote.
- Do not amend, force-push, or rewrite history unless the user explicitly asks
  for it.
- If the worktree contains changes that appear unrelated to the current task and
  the intended commit scope cannot be determined safely, stop and ask the user
  before creating the commit.

### Commit Skill

- `$moonbitmark-commit-push` is the repo-scoped skill for the final
  `status -> validation -> commit message -> commit -> push` workflow.
- Use it when the user asks to "提交", "commit", "push", "提交并推送", or any
  equivalent finalization request.

## Dependencies

- `moonbitlang/async` - File system, HTTP client
- `bobzhang/mbtpdf` - PDF text extraction

## Runtime Boundaries

Core archive/XML parsing is pure MoonBit:

- **libzip** (`src/libzip/`) - ZIP extraction with Store and Deflate decompression
- **xml** (`src/xml/`) - SAX-style XML parser for DOCX/PPTX/EPUB processing

Bridge-backed capabilities are not pure MoonBit-only:

- **OCR** uses `scripts/ocr/bridge.py` and an external backend such as `mock` or `tesseract`
- **PDF fallback extraction** may use `scripts/pdf/bridge.py`
- **Windows native release builds** assume MSVC `cl.exe` as configured by `moonpkg.json`

For the authoritative boundary list, see `docs/architecture/external_dependencies.md`.

### Features
- ✅ ZIP structure parsing
- ✅ Store decompression (no compression)
- ✅ Deflate decompression - Fixed Huffman (working)
- ✅ Deflate decompression - Dynamic Huffman
- ✅ CRC32 validation (IEEE 802.3)
- ✅ XML parsing (tags, attributes, text content)

## Known Issues

See [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) for a list of known bugs and issues.
