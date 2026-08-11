# pdfsyntax

PDF lexer and parser for converting byte streams to `PdfObject` trees.

## Overview

The `pdfsyntax` package provides:

- **Lexing**: Convert input bytes into a token stream
- **Parsing**: Convert tokens into `PdfObject` values
- **Utilities**: Input stream helpers for reading PDF syntax

## Quick Start

### Parsing Objects from Strings

```mbt check
```

```mbt check
```

```mbt check
```

## Lexing

### Lexing Names

```mbt check
```

### Lexing Numbers

```mbt check
```

```mbt check
```

### Lexing Strings

```mbt check
```

### Lexing Hex Strings

```mbt check
```

### Lexing Comments

```mbt check
```

## Parsing

### Parse Function

The main `parse` function converts a token array to a `PdfObject`:

```mbt nocheck
pub fn PdfSyntax::parse(
  tokens : Array[@pdfgenlex.Token],
  failure_is_ok? : Bool = false,
) -> (Int, @pdf.PdfObject) raise
```

Returns a tuple of (object number, parsed object). The object number is 0 for standalone objects.

### Parsing Objects with Object Numbers

```mbt check
```

## Lexeme Utilities

### Token to String

```mbt check
```

## Input Utilities

### Skip Whitespace

```mbt check
```

### Read Until Predicate

```mbt check
```

### Read Lines

```mbt check
```

### Find EOF Marker

```mbt check
```

## Advanced Lexing

### lex_object_at

For parsing complete PDF objects from files:

```mbt nocheck
pub fn PdfSyntax::lex_object_at(
  oneonly : Bool,                             // Stop after one object?
  input : @pdfio.Input,                       // Input stream
  read_stream_data : Bool,                    // Load stream bytes?
  lexobj : (Int) -> Array[@pdfgenlex.Token],  // Object lookup callback
) -> Array[@pdfgenlex.Token]
```

### lex_next

Low-level token-by-token lexing:

```mbt nocheck
pub fn PdfSyntax::lex_next(
  dict_level : Ref[Int],                      // Dictionary nesting depth
  array_level : Ref[Int],                     // Array nesting depth
  end_on_stream : Bool,                       // Stop at stream?
  input : @pdfio.Input,                       // Input stream
  previous_lexemes : Array[@pdfgenlex.Token], // Previous tokens
  read_stream_data : Bool,                    // Load stream bytes?
  lexobj : (Int) -> Array[@pdfgenlex.Token],  // Object lookup callback
) -> @pdfgenlex.Token
```

### lex_dictionary

Lex a complete dictionary:

```mbt nocheck
pub fn PdfSyntax::lex_dictionary(
  minus_one : Bool,       // Adjust position by -1?
  input : @pdfio.Input,
) -> Array[@pdfgenlex.Token]
```

## Error Handling

Parsing functions raise `@pdf.PdfError` on malformed input:

```mbt nocheck
// With failure_is_ok=true, returns Null instead of raising
let (_, obj) = @pdfsyntax.PdfSyntax::new().parse!(tokens, failure_is_ok=true)
```
