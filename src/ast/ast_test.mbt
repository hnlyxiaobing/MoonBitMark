///|
test "render markdown document" {
  let doc = Document::{
    title: Some("Demo"),
    metadata: {},
    blocks: [
      text_heading(1, "Demo"),
      Paragraph([
        Text("hello "),
        Strong([Text("world")]),
        Text(" "),
        Link([Text("site")], "https://example.com"),
      ]),
      List(["a", "b"], false),
    ],
  }
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
test "parse markdownish document" {
  let doc = @ast.document_of_markdownish(
    "# Title\n\n- one\n- two\n\n| a | b |\n| --- | --- |\n| 1 | 2 |",
    Some("Title"),
    {},
  )
  inspect(doc.blocks.length(), content="3")
}
