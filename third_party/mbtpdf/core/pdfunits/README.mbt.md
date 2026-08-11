# @bobzhang/mbtpdf/core/pdfunits

Unit conversions for PDF measurements.

## Overview

This package provides utilities for converting between common length units used in PDF documents. PDF uses points as its native unit (72 points = 1 inch).

## Types

### LengthUnit

Supported length units:

```moonbit nocheck
///|
pub(all) enum LengthUnit {
  PdfPoint // 1/72 inch (PDF native unit)
  Inch // 1 inch = 72 points
  Centimetre // 1 cm = 28.3465 points
  Millimetre // 1 mm = 2.83465 points
}
```

## Methods

### LengthUnit::to_points

Convert a measurement to PDF points.

```moonbit check

```

### LengthUnit::to_inches

Convert a measurement to inches.

```moonbit check

```

### LengthUnit::to_centimetres

Convert a measurement to centimetres.

```moonbit check

```

### LengthUnit::to_millimetres

Convert a measurement to millimetres.

```moonbit check

```

## Unit Relationships

The fundamental relationships are:
- 1 inch = 72 PDF points
- 1 inch = 2.54 centimetres
- 1 centimetre = 10 millimetres

```moonbit check

```
