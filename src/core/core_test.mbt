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
    Some("docx"),
    Some("demo.docx"),
  )
  inspect(diagnostics.length(), content="2")
}
