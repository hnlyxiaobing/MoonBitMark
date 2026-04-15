///|
test "docx file stem helper" {
  inspect(@core.file_stem("book/chapter1.docx"), content="Some(\"chapter1\")")
}

///|
test "docx warning diagnostics target document xml" {
  let diagnostics = docx_warning_diagnostics("demo.docx", [
    "No text content extracted from word/document.xml.",
  ])
  inspect(diagnostics.length(), content="1")
  inspect(
    diagnostics[0].render(),
    content="Warning: ConverterWarning\n  Phase: parse/word/document.xml\n  Source: word/document.xml\n  Message: No text content extracted from word/document.xml.\n  Hint: Verify the DOCX contains visible text in word/document.xml.",
  )
}

///|
test "docx typed failure render targets archive entry" {
  let rendered = render_docx_failure(
    @core.ZipError(
      "Failed to read document.xml from DOCX",
      Some("word/document.xml"),
    ),
    Some(@core.Load(Some("word/document.xml"))),
    Some(@core.ArchiveEntry("word/document.xml")),
    Some(@core.CheckArchiveIntegrity),
  )
  inspect(
    rendered,
    content="Error: ZipError\n  Phase: load/word/document.xml\n  Source: word/document.xml\n  Message: Failed to read document.xml from DOCX (word/document.xml)\n  Hint: Inspect archive integrity and verify the expected internal entries exist.",
  )
}

///|
test "docx heading normalization adds spacing before numbers" {
  inspect(normalize_docx_heading_text("Section1.2.3"), content="Section 1.2.3")
}

///|
test "docx promotes short leading title paragraph" {
  inspect(
    docx_is_promotable_title([@ast.Text("Test Document")]),
    content="true",
  )
}

///|
test "docx ordered list paragraphs are grouped into one markdown list" {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
    "<w:body>" +
    "<w:p><w:pPr><w:numPr><w:ilvl w:val=\"0\"/><w:numId w:val=\"42\"/></w:numPr></w:pPr><w:r><w:t>First</w:t></w:r></w:p>" +
    "<w:p><w:pPr><w:numPr><w:ilvl w:val=\"0\"/><w:numId w:val=\"42\"/></w:numPr></w:pPr><w:r><w:t>Second</w:t></w:r></w:p>" +
    "</w:body>" +
    "</w:document>"
  let numbering = DocxNumbering::{
    num_to_abstract: { "42": "7" },
    level_formats: { "7:0": "decimal" },
  }
  let (blocks, warnings) = extract_blocks_from_docx_xml(xml, {}, numbering, {})
  inspect(warnings.length(), content="0")
  inspect(
    @ast.render_markdown(@ast.document(None, {}, blocks)),
    content="1. First\n2. Second",
  )
}

///|
test "docx inserts spaces across adjacent runs" {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
    "<w:body>" +
    "<w:p><w:r><w:t>Paragraph</w:t></w:r><w:r><w:t>2.1.1</w:t></w:r></w:p>" +
    "<w:p><w:pPr><w:numPr><w:ilvl w:val=\"0\"/><w:numId w:val=\"42\"/></w:numPr></w:pPr><w:r><w:t>List item</w:t></w:r><w:r><w:t>a</w:t></w:r></w:p>" +
    "</w:body>" +
    "</w:document>"
  let numbering = DocxNumbering::{
    num_to_abstract: { "42": "7" },
    level_formats: { "7:0": "decimal" },
  }
  let (blocks, warnings) = extract_blocks_from_docx_xml(xml, {}, numbering, {})
  inspect(warnings.length(), content="0")
  inspect(
    @ast.render_markdown(@ast.document(None, {}, blocks)),
    content="# Paragraph 2.1.1\n\n1. List item a",
  )
}

///|
test "docx tables become markdown tables" {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
    "<w:body>" +
    "<w:tbl>" +
    "<w:tr>" +
    "<w:tc><w:p><w:r><w:t>Name</w:t></w:r></w:p></w:tc>" +
    "<w:tc><w:p><w:r><w:t>Value</w:t></w:r></w:p></w:tc>" +
    "</w:tr>" +
    "<w:tr>" +
    "<w:tc><w:p><w:r><w:t>Alpha</w:t></w:r></w:p></w:tc>" +
    "<w:tc><w:p><w:r><w:t>10</w:t></w:r></w:p></w:tc>" +
    "</w:tr>" +
    "</w:tbl>" +
    "</w:body>" +
    "</w:document>"
  let (blocks, warnings) = extract_blocks_from_docx_xml(
    xml,
    {},
    DocxNumbering::{ num_to_abstract: {}, level_formats: {} },
    {},
  )
  inspect(warnings.length(), content="0")
  inspect(
    @ast.render_markdown(@ast.document(None, {}, blocks)),
    content="| Name | Value |\n| --- | --- |\n| Alpha | 10 |",
  )
}
