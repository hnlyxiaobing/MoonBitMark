///|
test "semantic document groups blocks under heading sections" {
  let document = @ast.Document::{
    title: Some("Doc"),
    metadata: { "source_path": "docs/demo.docx" },
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
  inspect(semantic.blocks[0].role, content="Title")
  inspect(semantic.provenance.source_path, content="Some(\"docs/demo.docx\")")
  inspect(semantic.blocks[0].confidence, content="85")
}

///|
test "semantic document infers note caption and provenance hints" {
  let document = @ast.Document::{
    title: Some("Demo"),
    metadata: {
      "source_url": "https://example.com/demo.html",
      "chapter": "Overview",
    },
    blocks: [
      @ast.Paragraph([@ast.Text("Note: keep this section concise")]),
      @ast.Block::Image("chart", "asset://1", None),
      @ast.Paragraph([@ast.Text("Figure 1. Revenue trend")]),
      @ast.Table([[@ast.Text("Name")]], [[[@ast.Text("Value")]]]),
    ],
    annotations: [
      @ast.BlockAnnotation::{
        id: "b1",
        source_hint: Some("chapter: Summary"),
        origin_hint: None,
        diagnostics: [],
      },
      @ast.BlockAnnotation::{
        id: "b2",
        source_hint: Some("page: 3"),
        origin_hint: Some("resource: media/chart.png"),
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
        source_hint: Some("sheet: Q1"),
        origin_hint: None,
        diagnostics: ["normalized table shape"],
      },
    ],
  }
  let semantic = semantic_document_of(document)
  inspect(semantic.blocks[0].role, content="Note")
  inspect(semantic.blocks[1].role, content="Image")
  inspect(semantic.blocks[1].provenance.page_no, content="Some(3)")
  inspect(
    semantic.blocks[1].provenance.resource,
    content="Some(\"resource: media/chart.png\")",
  )
  inspect(semantic.blocks[2].role, content="Caption")
  inspect(semantic.blocks[3].role, content="TableBody")
  inspect(semantic.blocks[3].provenance.sheet_name, content="Some(\"Q1\")")
  inspect(semantic.blocks[3].confidence, content="70")
}
