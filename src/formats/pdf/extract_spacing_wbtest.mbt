///|
/// Unit tests for the word-spacing-aware PDF extractor, using minimal
/// in-memory PDFs whose content streams exercise TJ displacement and Td
/// horizontal moves.

///|
/// Assemble a minimal single-page PDF (Helvetica base font, uncompressed
/// content stream) with a correct xref table. All content is ASCII, so
/// string lengths equal byte offsets.
fn build_test_pdf(content : String) -> String {
  let objects : Array[String] = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    "<< /Length \{content.length()} >>\nstream\n\{content}\nendstream",
  ]
  let header = "%PDF-1.4\n"
  let buf = StringBuilder()
  buf.write_string(header)
  let offsets : Array[Int] = []
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
fn pad_xref_offset(value : Int) -> String {
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
fn extract_test_content(content : String) -> String raise {
  let input = @pdfio.Input::of_string(build_test_pdf(content))
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
