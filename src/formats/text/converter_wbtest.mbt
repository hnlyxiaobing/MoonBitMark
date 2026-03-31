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
