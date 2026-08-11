# pdf

Core types and operations for in-memory PDF document representation.

## Overview

The `pdf` package provides the fundamental data structures for representing PDF documents in memory. It defines the `PdfObject` enum for all PDF value types, the `Pdf` struct for complete documents, and operations for manipulating objects, dictionaries, streams, and object graphs.

## Core Types

### PdfObject

The central enum representing all PDF value types:

```mbt nocheck
///|
pub(all) enum PdfObject {
  Null
  Boolean(Bool)
  Integer(Int)
  Real(Double)
  String(String)
  Name(String)
  Array(Array[PdfObject])
  Dictionary(Array[(String, PdfObject)])
  Stream(Ref[(PdfObject, Stream)])
  Indirect(Int)
}
```

- **Null**: PDF null value
- **Boolean**: `true` or `false`
- **Integer/Real**: Numeric values
- **String**: Literal or hexadecimal strings
- **Name**: PDF names like `/Type`, `/Page`
- **Array**: Ordered collection of objects
- **Dictionary**: Key-value pairs (keys are names). Stored as an `Array[(String, PdfObject)]` so malformed PDFs with duplicate keys can be represented; use `lookup_immediate` (first match) or `lookup_immediate_all` (all matches).
- **Stream**: Dictionary plus binary data
- **Indirect**: Reference to another object by number

### Pdf

The in-memory document representation:

```mbt nocheck
///|
pub(all) struct Pdf {
  major : Int // PDF major version
  minor : Int // PDF minor version
  root : Int // Object number of document catalog
  objects : PdfObjects // All objects in the document
  mut trailerdict : PdfObject
  was_linearized : Bool
  mut saved_encryption : SavedEncryption?
}
```

### Stream

Stream data can be loaded or deferred:

```mbt nocheck
///|
pub(all) enum Stream {
  Got(@pdfio.MutableBytes) // Data in memory
  ToGet(ToGet) // Data still on disk
}
```

## Creating Documents

### Empty Document

```mbt nocheck
///|
let pdf = @pdf.Pdf::empty()
// Creates PDF 2.0 with no objects
```

### Adding Objects

```mbt nocheck
let pdf = @pdf.Pdf::empty()

// Add an object and get its number
let objnum = pdf.addobj(@pdf.PdfObject::Dictionary([
  ("/Type", @pdf.PdfObject::Name("/Page")),
]))

// Add with a specific object number
pdf.addobj_given_num((42, @pdf.PdfObject::Integer(100)))
```

## Object Lookup

### Basic Lookup

```mbt check

```

### Following Indirect References

```mbt check

```

### Dictionary Key Lookup

```mbt check

```

### Nested Chain Lookup

For deeply nested dictionaries, use `lookup_chain`:

```mbt check

```

## Dictionary Manipulation

### Adding Entries

```mbt check

```

## Traits

### ToPdfNumber

`@pdf.ToPdfNumber` is a small helper trait for converting primitive numeric
types into `PdfObject` numeric nodes.

```mbt check

```

### Replacing Entries

```mbt check

```

### Removing Entries

```mbt check

```

## Object Iteration

### Iterating All Objects

```mbt nocheck
obj.objiter(fn(objnum) {
    println("Object \{objnum}: \{obj}")
  },
  pdf,
)
```

### Selecting Objects by Predicate

```mbt nocheck
// Find all page objects

///|
let page_nums = obj.objselect(
  fn(obj) {
    match pdf.lookup_direct("/Type") {
      Some(Name("/Page")) => true
      _ => false
    }
  },
  pdf,
)
```

### Transforming All Objects

```mbt nocheck
// Apply a transformation to every object
pdf,
.objselfmap(fn(obj) {
    // Return transformed object
    obj
  })
```

## Stream Operations

### Getting Stream Data

```mbt nocheck
match obj {
  Stream(_) => {
    obj.getstream!()  // Loads data if deferred
    let bytes = obj.bigarray_of_stream!()
    // Use bytes...
  }
  _ => ()
}
```

## Geometry Operations

### Parsing Rectangles

```mbt check

```

### Matrices

```mbt nocheck
// Parse a matrix from a dictionary

///|
let matrix = pdf.parse_matrix("/Matrix", dict)

// Create a matrix object

///|
let matrix_obj = @pdf.make_matrix(@pdftransform.TransformMatrix::identity())
```

## Reference Management

### Finding Referenced Objects

```mbt nocheck
// Find all objects reachable from a starting object

///|
let refs = pdf.objects_referenced([], [], start_obj)
```

### Removing Unreferenced Objects

```mbt nocheck
// Garbage collect unreferenced objects
pdf.remove_unreferenced!()
```

## Document Operations

### Renumbering Objects

```mbt nocheck
// Calculate changes to renumber 1..n

///|
let change_table = pdf.changes()

// Apply renumbering

///|
let renumbered = pdf.renumber(change_table)
```

### Deep Copy

```mbt nocheck
// Create an independent copy

///|
let copy = pdf.deep_copy()
```

### Renumbering Multiple PDFs

```mbt nocheck
// Make object numbers mutually exclusive across documents

///|
let renumbered = @pdf.renumber_pdfs([pdf1, pdf2, pdf3])
```

## Name Trees

PDF name trees are hierarchical structures for mapping names to values:

```mbt nocheck
// Lookup in a name tree

///|
let value = pdf.nametree_lookup(@pdf.PdfObject::String("key"), tree)

// Get all entries

///|
let entries = pdf.contents_of_nametree(tree)
```

## Character Classification

```mbt nocheck

```

```mbt check

```

## Error Handling

The package uses `PdfError` for error conditions:

```mbt nocheck
///|
pub(all) suberror PdfError {
  Msg(String)
}
```

Functions that can fail use the `raise` keyword and should be called with `!` or within error handling contexts.
