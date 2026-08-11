# pdfgenlex

Generic lexer tokens for PDF parsing.

## Overview

The `pdfgenlex` package defines the `Token` enum representing all lexical tokens that appear in PDF syntax. It provides functions to lex tokens from input streams or strings.

## Types

### PdfGenLex

Lexer context.

```mbt nocheck
pub struct PdfGenLex { ... }
pub fn PdfGenLex::new() -> PdfGenLex
```

## Token Type

```mbt nocheck
///|
pub(all) enum Token {
  LexNull // null value
  LexBool(Bool) // true / false
  LexInt(Int) // integer literal
  LexReal(Double) // floating-point literal
  LexString(String) // string literal (...)
  LexName(String) // name /Foo
  LexLeftSquare // [
  LexRightSquare // ]
  LexLeftDict // <<
  LexRightDict // >>
  LexStream(Stream) // stream data
  LexEndStream // endstream
  LexObj // obj
  LexEndObj // endobj
  LexR // R (indirect reference)
  LexComment(String) // % comment
  StopLexing // internal: stop signal
  LexNone // internal: no token
}
```

## Lexing from Strings

```mbt check
```

```mbt check
```

```mbt check
```

```mbt check
```

## Lexing from Input

```mbt check
```

```mbt check
```

## Debug Output

```mbt check
```

## Token Categories

### Literals

- `LexNull` - PDF null
- `LexBool(Bool)` - `true` or `false`
- `LexInt(Int)` - integer like `42`, `-10`
- `LexReal(Double)` - floating point like `3.14`, `1.0e-5`
- `LexString(String)` - literal string content

### Structural

- `LexName(String)` - names like `foo`, `Type`
- `LexLeftSquare`, `LexRightSquare` - `[` and `]`
- `LexLeftDict`, `LexRightDict` - `<<` and `>>`

### Objects

- `LexObj`, `LexEndObj` - object delimiters
- `LexStream(Stream)`, `LexEndStream` - stream delimiters
- `LexR` - indirect reference marker

### Special

- `LexComment(String)` - PDF comments
- `StopLexing` - internal stop signal
- `LexNone` - placeholder for no token
