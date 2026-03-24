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
