///|
test "text converter helpers" {
  inspect(count_lines("a\nb\n"), content="3")
  inspect(@core.file_stem("docs/readme.txt"), content="Some(\"readme\")")
}

///|
test "text converter preserves lightweight bullet structure" {
  let doc = text_to_document(
    "Important points:\n\n- Hamburgers are delicious\n   - Dogs are the best\n   - I love fuzzy blankets\n",
    None,
    {},
  )
  inspect(
    @ast.render_markdown(doc),
    content="Important points:\n\n- Hamburgers are delicious\n   - Dogs are the best\n   - I love fuzzy blankets",
  )
}

///|
async test "text converter supports bytes input source" {
  let result = TextConverter::convert_source(
    @core.BytesInput(
      Some("bytes-demo.txt"),
      @utf8.encode("line 1\nline 2"),
      None,
    ),
  )
  inspect(result.title, content="Some(\"bytes-demo\")")
  assert_true(result.markdown.contains("line 1"))
}

///|
test "text converter preserves structured lines for long no-blank-line inputs" {
  let doc = text_to_document(
    "Title\nSubtitle\nField A\nField B\nField C\nField D\nField E\nField F\nField G\nField H\nField I\nField J\nField K\nField L\nField M\nField N\nField O\nField P\nField Q\nField R\nField S\nField T",
    None,
    {},
  )
  inspect(
    @ast.render_markdown(doc),
    content="Title\n\nSubtitle\n\nField A\n\nField B\n\nField C\n\nField D\n\nField E\n\nField F\n\nField G\n\nField H\n\nField I\n\nField J\n\nField K\n\nField L\n\nField M\n\nField N\n\nField O\n\nField P\n\nField Q\n\nField R\n\nField S\n\nField T",
  )
}
