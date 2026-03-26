///|
test "html title and warnings" {
  inspect(
    extract_title("<html><head><title> Demo </title></head></html>"),
    content="Some(\"Demo\")",
  )
  inspect(
    collect_html_warnings("<style>a{}</style><script>x()</script>").length(),
    content="2",
  )
}

///|
test "html direct ast document" {
  let doc = html_to_document(
    "<body><h1>Demo</h1><p>Hello <strong>world</strong></p><ul><li>A</li><li>B</li></ul></body>",
    Some("Demo"),
  )
  inspect(doc.blocks.length(), content="3")
}

///|
test "html prepends title when body heading differs" {
  let doc = html_to_document(
    "<html><head><title>Simple Table Test</title></head><body><h1>Sample Data Table</h1></body></html>",
    Some("Simple Table Test"),
  )
  inspect(
    @ast.render_markdown(doc),
    content="Simple Table Test\n\n# Sample Data Table",
  )
}

///|
test "html unwraps div containers into nested blocks" {
  let doc = html_to_document(
    "<body><div><h2>Nested</h2><p>Hello</p><ul><li>A</li><li>B</li></ul></div></body>",
    None,
  )
  inspect(@ast.render_markdown(doc), content="## Nested\n\nHello\n\n- A\n- B")
}

///|
test "html warning diagnostics carry typed source" {
  let diagnostics = html_warning_diagnostics(
    "https://example.com", "<style>a{}</style><script>x()</script>",
  )
  inspect(diagnostics.length(), content="2")
  inspect(
    diagnostics[0].render(),
    content="Warning: ConverterWarning\n  Phase: normalize/preprocess\n  Source: https://example.com\n  Message: Dropped <script> blocks during HTML conversion.\n  Hint: Scripts are intentionally removed before Markdown rendering.",
  )
}

///|
test "html table cells preserve inline formatting" {
  inspect(
    @ast.render_inlines(
      extract_table_cells(
        "<tr><td><strong>Total Products:</strong></td><td>4</td></tr>",
      )[0],
    ),
    content="**Total Products:**",
  )
}

///|
test "html unwraps header containers" {
  let doc = html_to_document(
    "<body><header><h2>Hero</h2><p>Intro</p></header></body>",
    None,
  )
  inspect(@ast.render_markdown(doc), content="## Hero\n\nIntro")
}
