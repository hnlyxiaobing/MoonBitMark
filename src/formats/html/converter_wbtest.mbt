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
test "html warning diagnostics carry typed source" {
  let diagnostics = html_warning_diagnostics(
    "https://example.com", "<style>a{}</style><script>x()</script>",
  )
  inspect(diagnostics.length(), content="2")
  inspect(
    diagnostics[0].render(),
    content="Error: ConverterWarning\n  Phase: normalize/preprocess\n  Source: https://example.com\n  Message: Dropped <script> blocks during HTML conversion.\n  Hint: Scripts are intentionally removed before Markdown rendering.",
  )
}
