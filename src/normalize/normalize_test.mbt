///|
test "normalize document adjusts headings tables and image paragraphs" {
  let document = @ast.Document::{
    title: Some("Demo"),
    metadata: {},
    blocks: [
      @ast.Heading(4, [@ast.Text("  Top  ")]),
      @ast.Heading(6, [@ast.Text("Deep")]),
      @ast.Paragraph([@ast.Text("hello   \n world")]),
      @ast.Paragraph([@ast.Image(" chart ", "image.png")]),
      @ast.Table([], [
        [[@ast.Text("h1")], [@ast.Text("h2")]],
        [[@ast.Text("v1")]],
      ]),
    ],
    annotations: [],
  }
  let normalized = normalize_document(document)
  inspect(normalized.blocks.length(), content="5")
  inspect(normalized.blocks[0], content="Heading(4, [Text(\"Top\")])")
  inspect(normalized.blocks[1], content="Heading(5, [Text(\"Deep\")])")
  inspect(normalized.blocks[2], content="Paragraph([Text(\"hello world\")])")
  inspect(normalized.blocks[3], content="Image(\"chart\", \"image.png\", None)")
  inspect(
    normalized.annotations[1].diagnostics[0],
    content="Normalized heading level from 6 to 5",
  )
}
