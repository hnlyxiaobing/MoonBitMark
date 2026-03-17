///|
test "render markdown document" {
  let doc = Document::{
    title: Some("Demo"),
    metadata: {},
    blocks: [
      Heading(1, "Demo"),
      text_paragraph("hello"),
      List(["a", "b"], false),
    ],
  }
  inspect(@ast.render_markdown(doc), content="# Demo\n\nhello\n\n- a\n- b")
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
