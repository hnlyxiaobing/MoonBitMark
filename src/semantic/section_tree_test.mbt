///|
test "semantic document groups blocks under heading sections" {
  let document = @ast.Document::{
    title: Some("Doc"),
    metadata: {},
    blocks: [
      @ast.Heading(1, [@ast.Text("Intro")]),
      @ast.Paragraph([@ast.Text("Body")]),
      @ast.Heading(2, [@ast.Text("Detail")]),
      @ast.CodeBlock(Some("txt"), "code"),
    ],
    annotations: [
      @ast.BlockAnnotation::{
        id: "b1",
        source_hint: None,
        origin_hint: None,
        diagnostics: [],
      },
      @ast.BlockAnnotation::{
        id: "b2",
        source_hint: None,
        origin_hint: None,
        diagnostics: [],
      },
      @ast.BlockAnnotation::{
        id: "b3",
        source_hint: None,
        origin_hint: None,
        diagnostics: [],
      },
      @ast.BlockAnnotation::{
        id: "b4",
        source_hint: None,
        origin_hint: None,
        diagnostics: [],
      },
    ],
  }
  let semantic = semantic_document_of(document)
  inspect(semantic.sections.length(), content="1")
  inspect(semantic.sections[0].title, content="Some(\"Intro\")")
  inspect(semantic.sections[0].children[0].title, content="Some(\"Detail\")")
  inspect(semantic.blocks[3].role, content="Code")
}
