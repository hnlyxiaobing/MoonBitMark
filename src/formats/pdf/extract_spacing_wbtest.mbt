///|
/// Unit tests for the word-spacing-aware PDF extractor, using minimal
/// in-memory PDFs whose content streams exercise TJ displacement and Td
/// horizontal moves.

///|
/// Assemble a minimal single-page PDF (Helvetica base font, uncompressed
/// content stream) with a correct xref table. All content is ASCII, so
/// string lengths equal byte offsets.
fn build_test_pdf(
  content : String,
  base_font~ : String = "Helvetica",
) -> String {
  let objects : Array[String] = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
    "<< /Type /Font /Subtype /Type1 /BaseFont /\{base_font} >>",
    "<< /Length \{content.length()} >>\nstream\n\{content}\nendstream",
  ]
  let header = "%PDF-1.4\n"
  let buf = StringBuilder()
  buf.write_string(header)
  let offsets : Array[Int32] = []
  let mut offset = header.length()
  for i, obj in objects {
    offsets.push(offset)
    let chunk = "\{i + 1} 0 obj\n\{obj}\nendobj\n"
    buf.write_string(chunk)
    offset = offset + chunk.length()
  }
  let xref_offset = offset
  buf.write_string("xref\n0 \{objects.length() + 1}\n")
  buf.write_string("0000000000 65535 f \n")
  for obj_offset in offsets {
    buf.write_string(pad_xref_offset(obj_offset))
    buf.write_string(" 00000 n \n")
  }
  buf.write_string("trailer\n")
  buf.write_string("<< /Size \{objects.length() + 1} /Root 1 0 R >>\n")
  buf.write_string("startxref\n\{xref_offset}\n%%EOF\n")
  buf.to_string()
}

///|
fn pad_xref_offset(value : Int32) -> String {
  let digits = value.to_string()
  let padding = 10 - digits.length()
  if padding <= 0 {
    return digits
  }
  let buf = StringBuilder()
  for _ in 0..<padding {
    buf.write_char('0')
  }
  buf.write_string(digits)
  buf.to_string()
}

///|
fn extract_test_content(
  content : String,
  base_font~ : String = "Helvetica",
) -> String raise {
  let input = @pdfio.Input::of_string(build_test_pdf(content, base_font~))
  let pdf = @pdfread.PdfRead::new().pdf_of_input(None, None, input)
  let warnings : Array[String] = []
  let pages = extract_spacing_pages(pdf, warnings)
  pages.join("\n")
}

///|
test "TJ negative displacement materializes a word space" {
  // -250 at 10pt is a 0.25em gap: a word boundary.
  let text = extract_test_content(
    "BT /F1 10 Tf 100 700 Td [(The) -250 (plot)] TJ ET",
  )
  inspect(text, content="The plot")
}

///|
test "TJ small kerning displacement does not split words" {
  // -30 is ordinary kerning (0.03em), far below the word threshold.
  let text = extract_test_content(
    "BT /F1 10 Tf 100 700 Td [(fi) -30 (ne)] TJ ET",
  )
  inspect(text, content="fine")
}

///|
test "Td horizontal move materializes a word space" {
  // 8 units at 10pt is a 0.8em move: a word boundary.
  let text = extract_test_content(
    "BT /F1 10 Tf 100 700 Td (The) Tj 8 0 Td (plot) Tj ET",
  )
  inspect(text, content="The plot")
}

///|
test "Td small horizontal move does not split words" {
  let text = extract_test_content(
    "BT /F1 10 Tf 100 700 Td (fi) Tj 1 0 Td (ne) Tj ET",
  )
  inspect(text, content="fine")
}

///|
test "spacing falls back to default font size without Tf" {
  // No Tf: default 12pt. TJ gap is font-size independent and still inserts;
  // Td 4 0 is 4/12 = 0.33em, also a word boundary.
  let tj_text = extract_test_content("BT 100 700 Td [(The) -250 (plot)] TJ ET")
  inspect(tj_text, content="The plot")
  let td_text = extract_test_content(
    "BT 100 700 Td (The) Tj 4 0 Td (plot) Tj ET",
  )
  inspect(td_text, content="The plot")
}

///|
test "no duplicate or leading spaces from repeated gaps" {
  // Consecutive large displacements collapse to one space, and a gap at the
  // start of output does not produce a leading space.
  let text = extract_test_content(
    "BT /F1 10 Tf 100 700 Td [(The) -300 -300 (plot)] TJ ET",
  )
  inspect(text, content="The plot")
}

///|
test "wide gap between non-Latin scripts stays glued" {
  // Arabic (UTF-16BE hex strings): justification widens inter-letter gaps,
  // which must not be split into spaces.
  let text = extract_test_content(
    "BT /F1 10 Tf 100 700 Td [<FEFF0629063A> -300 <FEFF06440627>] TJ ET",
  )
  inspect(text, content="ةغلا")
}

///|
test "wide gap between punctuation-only pieces stays glued" {
  let text = extract_test_content(
    "BT /F1 10 Tf 100 700 Td [(x) -300 (+) -300 (-)] TJ ET",
  )
  inspect(text, content="x +-")
}

///|
test "wide gap with a Latin side is materialized" {
  let text = extract_test_content(
    "BT /F1 10 Tf 100 700 Td [(add) -300 (\\050)] TJ ET",
  )
  inspect(text, content="add (")
}

///|
test "Tc above threshold materializes space between Tj pieces" {
  // Tc=3 at 10pt: 3/10 = 0.3 >= 0.21, so a word boundary is inserted.
  let text = extract_test_content(
    "BT /F1 10 Tf 100 700 Td 3 Tc (Hello) Tj (World) Tj ET",
  )
  inspect(text, content="Hello World")
}

///|
test "Tc below threshold does not split words" {
  // Tc=1 at 10pt: 1/10 = 0.1 < 0.21, pieces stay glued.
  let text = extract_test_content(
    "BT /F1 10 Tf 100 700 Td 1 Tc (Hello) Tj (World) Tj ET",
  )
  inspect(text, content="HelloWorld")
}

///|
test "Tw does not alter extracted text with existing spaces" {
  // Tw affects visual width of existing space glyphs but does not add or
  // remove characters; the space in "Hello World" is already in the string.
  let text = extract_test_content(
    "BT /F1 10 Tf 100 700 Td 5 Tw (Hello World) Tj ET",
  )
  inspect(text, content="Hello World")
}

///|
test "DoubleQuote operator sets Tc state for subsequent pieces" {
  // " 0 3 (Hello) sets Tc=3; the following (World) Tj sees the Tc gap.
  let text = extract_test_content(
    "BT /F1 10 Tf 100 700 Td 0 3 (Hello) \" (World) Tj ET",
  )
  inspect(text, content="Hello World")
}

///|
test "Tc persists across multiple Tj within same BT block" {
  // Tc=3 set once, applies to every subsequent Tj in the block.
  let text = extract_test_content(
    "BT /F1 10 Tf 100 700 Td 3 Tc (A) Tj (B) Tj (C) Tj ET",
  )
  inspect(text, content="A B C")
}

///|
test "pending_space does not leak across BT blocks" {
  // First BT sets pending_space via Tc after Tj; the second BT must start
  // clean — "next" must not inherit a spurious leading space.
  let text = extract_test_content(
    "BT /F1 10 Tf 100 700 Td 3 Tc (hello) Tj ET BT /F1 10 Tf 100 700 Td (next) Tj ET",
  )
  inspect(text, content="hello\nnext")
}

///|
test "Tm large gap materializes a word space" {
  // "Hi" at x=100, then Tm places "there" at x=200 — a gap far exceeding
  // the advance width of "Hi" at 10pt (~10.6 units), so it is a word boundary.
  let text = extract_test_content(
    "BT /F1 10 Tf 10 0 0 10 100 700 Tm (Hi) Tj 10 0 0 10 200 700 Tm (there) Tj ET",
  )
  inspect(text, content="Hi there")
}

///|
test "Tm small gap does not split words" {
  // Place second Tm very close to first text end — gap well below threshold.
  // "Hi" at 10pt Helvetica ≈ 10.56 units, so x=110 gives gap ≈ 0.
  let text = extract_test_content(
    "BT /F1 10 Tf 10 0 0 10 100 700 Tm (Hi) Tj 10 0 0 10 110 700 Tm (!) Tj ET",
  )
  inspect(text, content="Hi!")
}

///|
test "quote operator starts a new line before showing text" {
  // ' is T* followed by Tj: the next piece moves to the next line.
  let text = extract_test_content(
    "BT /F1 10 Tf 100 700 Td (Line1) Tj (Line2) ' ET",
  )
  inspect(text, content="Line1\nLine2")
}

///|
test "TD horizontal move materializes a word space" {
  // TD also sets the leading; with ty = 0 only the horizontal move counts.
  let text = extract_test_content(
    "BT /F1 10 Tf 100 700 Td (The) Tj 8 0 TD (plot) Tj ET",
  )
  inspect(text, content="The plot")
}

///|
test "backwards Td move does not materialize a space" {
  // A negative tx moves the pen left, so the pieces overlap instead of
  // opening a word gap; the ratio test is one-sided.
  let text = extract_test_content(
    "BT /F1 10 Tf 100 700 Td (The) Tj -8 0 Td (plot) Tj ET",
  )
  inspect(text, content="Theplot")
}

///|
test "Tm gap is not materialized when the font has no metrics" {
  // Non-standard fonts have no advance table, so `expected_x` cannot track
  // the true pen position and a Tm-driven "gap" would be the whole inter-run
  // distance (glyph ink included). The extractor therefore skips the OpTm
  // gap check without metrics and leaves the decision to TJ/Td/Tc, which are
  // exact. Two runs one glyph-width apart must stay glued.
  let text = extract_test_content(
    "BT /F1 10 Tf 10 0 0 10 100 700 Tm (Hi) Tj 10 0 0 10 110 700 Tm (!) Tj ET",
    base_font="MyEmbeddedFont",
  )
  inspect(text, content="Hi!")
}
