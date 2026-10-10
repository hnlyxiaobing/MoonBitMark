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
  inspect(diagnostics.length(), content="2")
  inspect(diagnostics[0].level.label(), content="Warning")
  inspect(
    diagnostics[0].render(),
    content="Warning: ConverterWarning\n  Phase: convert/docx\n  Source: demo.docx\n  Message: missing image\n  Hint: Inspect the converter output for details.",
  )
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

///|
test "debug report includes stats diagnostics and ast state" {
  let result = @core.ConvertResult::markdown_only("hello", "text")
    .with_document(
      Some(@ast.document(Some("Demo"), {}, [@ast.text_paragraph("hello")])),
    )
    .with_stats(Some(@core.stats_for_markdown("hello")))
    .with_diagnostics([
      @core.warning_diagnostic(
        "style dropped",
        Some(@core.Normalize(Some("html"))),
        Some(@core.File("demo.html")),
        Some(@core.InspectSourceDocument),
      ),
    ])
  inspect(
    result.debug_report(),
    content="ConvertResult Debug Report\nsource_type: text\nstats: chars=5, blocks=1\nwarnings: 0\ndiagnostics: 1\nassets: 0\nast: present\nraw_ast: present\nnormalized_ast: present\nmetadata: none\nDiagnostics:\nWarning: ConverterWarning\n  Phase: normalize/html\n  Source: demo.html\n  Message: style dropped\n  Hint: Inspect the source document or run with debug context.",
  )
}

///|
test "file helpers normalize basename and stem" {
  inspect(
    @core.file_name_only("docs\\nested/report.final.txt"),
    content="report.final.txt",
  )
  debug_inspect(
    @core.file_stem("docs\\nested/report.final.txt"),
    content=(
      #|Some("report.final")
    ),
  )
  inspect(@core.path_extension("docs/nested/archive.DOCX"), content="docx")
}

///|
test "find_last_char returns final index" {
  debug_inspect(
    @core.find_last_char("alpha/beta/gamma", '/'),
    content="Some(10)",
  )
  debug_inspect(@core.find_last_char("no-delimiter", '/'), content="None")
}

///|
test "find_tag_close skips greater-than inside quotes" {
  assert_eq(@core.find_tag_close("<a href=\"x>y\">t", 0), Some(13))
  assert_eq(@core.find_tag_close("<a href='p>q'/>", 0), Some(14))
  assert_eq(@core.find_tag_close("<a href=\"x>y\">", 0), Some(13))
}

///|
test "find_tag_close handles self-closing and unterminated tags" {
  assert_eq(@core.find_tag_close("<a/>", 0), Some(3))
  assert_eq(@core.find_tag_close("<a b=\"x", 0), None)
  assert_eq(@core.find_tag_close("<a>", 5), None)
  assert_eq(@core.find_tag_close("<a>", -1), None)
}

///|
test "markup_tag_matches enforces tag name boundaries" {
  assert_true(@core.markup_tag_matches("<table>", 0, "table", false))
  assert_true(
    @core.markup_tag_matches("<table class=\"x\">", 0, "table", false),
  )
  assert_true(@core.markup_tag_matches("<table/>", 0, "table", false))
  assert_true(@core.markup_tag_matches("<table", 0, "table", false))
  assert_true(@core.markup_tag_matches("</table>", 0, "table", true))
  assert_false(@core.markup_tag_matches("<tablet>", 0, "table", false))
  assert_false(@core.markup_tag_matches("</tablet>", 0, "table", true))
  assert_false(@core.markup_tag_matches("<pre>", 0, "p", false))
}

///|
test "find_markup_tag skips longer names for opener and closer" {
  let text = "<tablet>k</tablet><table>x</table>after"
  assert_eq(@core.find_markup_tag(text, "table", 0, false), Some(18))
  assert_eq(@core.find_markup_tag(text, "table", 0, true), Some(26))
  assert_eq(@core.find_markup_tag("<pre>", "p", 0, false), None)
  assert_eq(@core.find_markup_tag("<p>", "p", 0, false), Some(0))
}
