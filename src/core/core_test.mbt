// Core package tests

///|
test "MarkItDown new" {
  let result = @core.ConvertResult::markdown_only("hello", "text")
  inspect(result.source_type, content="text")
}

///|
test "ConvertContext default" {
  let ctx = @core.ConvertContext::default()
  inspect(ctx.keep_metadata, content="true")
}

///|
test "warnings convert to diagnostics" {
  let diagnostics = @core.diagnostics_from_warnings(
    ["missing image", "style dropped"],
    Some(@core.Convert("docx")),
    Some(@core.File("demo.docx")),
  )
  let expected = "Error: ConverterWarning\n  Phase: convert/docx\n  Source: demo.docx\n  Message: missing image\n  Hint: Inspect the converter output for details."
  inspect(diagnostics.length(), content="2")
  inspect(diagnostics[0].render(), content=expected)
}

///|
test "typed error diagnostic renders normalized fields" {
  let diagnostic = @core.error_diagnostic(
    @core.ZipError("Missing archive entry", Some("word/document.xml")),
    Some(@core.Load(Some("archive"))),
    Some(@core.ArchiveEntry("word/document.xml")),
    Some(@core.CheckArchiveIntegrity),
  )
  let expected = "Error: ZipError\n  Phase: load/archive\n  Source: word/document.xml\n  Message: Missing archive entry (word/document.xml)\n  Hint: Inspect archive integrity and verify the expected internal entries exist."
  inspect(diagnostic.category(), content="ZipError")
  inspect(diagnostic.render(), content=expected)
}
