# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Overview

MoonBitMark is a document converter that transforms various file formats (TXT, CSV, JSON, PDF, HTML, DOCX, URLs) to Markdown. It compiles to native code for fast execution.

## Commands

```bash
# Type check
moon check

# Build (Release mode, requires MSVC on Windows)
moon build --target native --release

# Run the compiled binary
_build/native/release/build/cmd/main/main.exe <input> [output]

# Run tests
moon test

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
  `moon.pkg.json` file listing its dependencies. Each package has its files and
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
└── formats/        # Format converters (one subdirectory per format)
    ├── text/       # Plain text (.txt)
    ├── csv/        # CSV → Markdown tables
    ├── json/       # JSON → code blocks
    ├── pdf/        # PDF via mbtpdf library
    ├── html/       # HTML + URL fetching
    └── docx/       # DOCX via FFI (libzip + expat)
```

**Conversion flow:** CLI → detect format by extension → select converter → read/convert → output Markdown

### Adding a New Converter

1. Create `src/formats/<format>/converter.mbt` with:
   - `XxxConverter` struct
   - `accepts(info: @core.StreamInfo) -> Bool` - check if format matches
   - `convert(file_path: String) -> String raise` - async conversion

2. Create `src/formats/<format>/moon.pkg.json`:
   ```json
   { "import": ["moonbitlang/moonbitmark/src/core", "moonbitlang/async/fs"] }
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
  prefer assertion tests. You can use `moon coverage analyze > uncovered.log` to
  see which parts of your code are not covered by tests.

## Dependencies

- `moonbitlang/async` - File system, HTTP client
- `bobzhang/mbtpdf` - PDF text extraction

## FFI (DOCX Converter)

The DOCX converter uses native C libraries via FFI:
- **libzip** - ZIP extraction
- **expat** - XML parsing

Install on Windows: `vcpkg install libzip:x64-windows expat:x64-windows`

FFI bindings are in `src/formats/docx/ffi/`.

## Pure MoonBit libzip (In Development)

A pure MoonBit implementation of libzip is being developed at `src/libzip/`:

**Current Status:**
- ✅ ZIP structure parsing
- ✅ Store decompression (no compression)
- ⚠️ Deflate decompression (simplified implementation)
- ⚠️ CRC32 validation (simplified implementation)

**Known Limitation:**
MoonBit's `UInt` type has restrictions on bitwise operations. `1.to_uint()` returns `Double`, not `UInt`, making bit masking and comparison difficult.
