///|
test "docx file stem helper" {
  inspect(file_stem("book/chapter1.docx"), content="Some(\"chapter1\")")
}

///|
test "docx warning diagnostics target document xml" {
  let diagnostics = docx_warning_diagnostics("demo.docx", true, [])
  inspect(diagnostics.length(), content="1")
  inspect(
    diagnostics[0].render(),
    content="Error: ConverterWarning\n  Phase: parse/word/document.xml\n  Source: word/document.xml\n  Message: No text content extracted from word/document.xml.\n  Hint: Verify the DOCX contains visible text in word/document.xml.",
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
