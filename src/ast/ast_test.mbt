///|
test "render markdown document" {
  let doc = document(Some("Demo"), {}, [
    text_heading(1, "Demo"),
    Paragraph([
      Text("hello "),
      Strong([Text("world")]),
      Text(" "),
      Link([Text("site")], "https://example.com"),
    ]),
    List([text_inlines("a"), text_inlines("b")], false),
  ])
  inspect(
    @ast.render_markdown(doc),
    content="# Demo\n\nhello **world** [site](https://example.com)\n\n- a\n- b",
  )
}

///|
test "render inline variants" {
  inspect(
    @ast.render_inlines([
      Emphasis([Text("one")]),
      Text(" "),
      Code("x = 1"),
      LineBreak,
      Image("alt", "image.png"),
    ]),
    content="*one* `x = 1`  \n![alt](image.png)",
  )
}

///|
test "render inline text escapes markdown specials" {
  inspect(
    @ast.render_inlines([Text("# heading *stars* [link] _under_ `code` \\")]),
    content="\\# heading \\*stars\\* \\[link\\] \\_under\\_ \\`code\\` \\\\",
  )
}

///|
test "render table preserves inline formatting and escapes cell pipes" {
  let doc = document(None, {}, [
    Table([text_inlines("name"), text_inlines("notes")], [
      [[Strong([Text("Alice")])], [Text("value | with break\nnext")]],
    ]),
  ])
  inspect(
    @ast.render_markdown(doc),
    content="| name | notes |\n| --- | --- |\n| **Alice** | value \\| with break<br>next |",
  )
}

///|
test "parse markdownish document" {
  let doc = @ast.document_of_markdownish(
    "# Title\n\n- one\n- two\n\n| a | b |\n| --- | --- |\n| 1 | 2 |",
    Some("Title"),
    {},
  )
  inspect(doc.blocks.length(), content="3")
}
