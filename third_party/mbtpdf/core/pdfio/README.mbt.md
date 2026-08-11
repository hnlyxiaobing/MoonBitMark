# pdfio

Low-level I/O primitives for reading and writing PDF byte streams.

## Overview

The `pdfio` package provides the fundamental I/O abstractions used throughout the PDF library. It defines:

- **MutableBytes**: The primary byte buffer type
- **Input**: Seekable input stream abstraction
- **Output**: Seekable output stream abstraction
- **Bitstream**: MSB-first bit-level reading and writing

## Byte Buffer Types

```mbt nocheck
///|
pub type MutableBytes = Array[Byte]

///|
pub type CoreBytes = Bytes

///|
pub type RawBytes = MutableBytes
```

### Creating Buffers

```mbt check
```

### Byte Access

```mbt check
```

### Conversions

```mbt check
```

```mbt check
```

```mbt check
```

### Copying

```mbt check
```

## Input Streams

The `Input` struct provides a seekable byte stream:

```mbt nocheck
///|
pub struct Input {
  pos_in : () -> Int // Current position
  seek_in : (Int) -> Unit // Seek to position
  input_char : () -> Char? // Read next char
  input_byte : () -> Int // Read next byte
  in_channel_length : Int // Total length
  set_offset : (Int) -> Unit // Set base offset
  source : String // Source description
}
```

### Creating Input from Bytes

```mbt check
```

### Creating Input from String

```mbt check
```

### Peeking and Rewinding

```mbt check
```

### Reading Lines

```mbt check
```

### Extracting Bytes from Input

```mbt check
```

## Output Streams

The `Output` struct provides a seekable output stream:

```mbt nocheck
///|
pub struct Output {
  pos_out : () -> Int // Current position
  seek_out : (Int) -> Unit // Seek to position
  output_char : (Char) -> Unit // Write char
  output_byte : (Int) -> Unit // Write byte
  output_string : (String) -> Unit // Write string
  out_channel_length : () -> Int // Written length
  flush : async () -> Unit // Flush buffer
}
```

### Creating Output Buffers

```mbt check
```

## Native File/Channel IO

`core/pdfio` is intentionally focused on in-memory `Input`/`Output` and byte
utilities.

For native `@fs.File` helpers (read whole file/channel into memory, or create an
`Output` backed by a channel), use `io/pdfiofs`.

## Bitstreams

For reading data at the bit level (MSB-first order).

### Creating a Bitstream

```mbt nocheck
```

### Bit-Level Reading

```mbt check
```

### Bitstream Position

```mbt nocheck
```

### Alignment

```mbt nocheck
```

### Write Bitstreams

```mbt check
```

## Constants

```mbt nocheck
///|
pub let no_more : Int = -1 // Indicates end of input
```

## Utility Functions

### Transform Bytes In-Place (Internal)

```mbt nocheck
```

### Fill Bytes (Internal)

```mbt nocheck
```
