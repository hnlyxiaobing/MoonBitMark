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
    content="Some(\"media/chart.png\")",
  )
  inspect(semantic.blocks[2].role, content="Caption")
  inspect(semantic.blocks[3].role, content="TableBody")
  inspect(semantic.blocks[3].provenance.sheet_name, content="Some(\"Q1\")")
  inspect(semantic.blocks[3].confidence, content="70")
}

///|
test "semantic document tracks pptx slide context and html title paragraphs" {
  let pptx_document = @ast.Document::{
    title: Some("Deck"),
    metadata: { "format": "pptx" },
    blocks: [
      @ast.Heading(2, [@ast.Text("Slide 3")]),
      @ast.Heading(3, [@ast.Text("Revenue Review")]),
      @ast.Paragraph([@ast.Text("Q1 improved")]),
    ],
    annotations: [],
  }
  let pptx_semantic = semantic_document_of(pptx_document)
  inspect(pptx_semantic.blocks[0].role, content="Separator")
  inspect(pptx_semantic.blocks[1].role, content="Title")
  inspect(pptx_semantic.blocks[1].provenance.slide_no, content="Some(3)")
  inspect(
    pptx_semantic.blocks[2].provenance.resource,
    content="Some(\"ppt/slides/slide3.xml\")",
  )

  let html_document = @ast.Document::{
    title: Some("Example Page"),
    metadata: { "format": "html" },
    blocks: [
      @ast.Paragraph([@ast.Text("Example Page")]),
      @ast.Paragraph([@ast.Text("Body copy")]),
    ],
    annotations: [],
  }
  let html_semantic = semantic_document_of(html_document)
  inspect(html_semantic.blocks[0].role, content="Title")
  inspect(
    html_semantic.blocks[0].provenance.resource,
    content="Some(\"html:body\")",
  )
}

///|
test "semantic document uses composite hints to stabilize roles" {
  let document = @ast.Document::{
    title: Some("Quarterly Review"),
    metadata: { "format": "mixed" },
    blocks: [
      @ast.Paragraph([@ast.Text("Quarterly Review")]),
      @ast.Paragraph([@ast.Text("Figure 2. Revenue by quarter")]),
      @ast.Paragraph([@ast.Text("Speaker note")]),
      @ast.Paragraph([@ast.Text("Quoted callout")]),
    ],
    annotations: [
      @ast.BlockAnnotation::{
        id: "h1",
        source_hint: None,
        origin_hint: Some(
          "resource: word/document.xml; kind: title; style: Title",
        ),
        diagnostics: [],
      },
      @ast.BlockAnnotation::{
        id: "h2",
        source_hint: None,
        origin_hint: Some(
          "resource: html:figcaption; tag: figcaption; kind: caption",
        ),
        diagnostics: [],
      },
      @ast.BlockAnnotation::{
        id: "h3",
        source_hint: Some("slide: 3"),
        origin_hint: Some(
          "resource: ppt/notesSlides/notesSlide3.xml; kind: notes",
        ),
        diagnostics: [],
      },
      @ast.BlockAnnotation::{
        id: "h4",
        source_hint: None,
        origin_hint: Some("resource: html:blockquote; tag: blockquote"),
        diagnostics: [],
      },
    ],
  }
  let semantic = semantic_document_of(document)
  inspect(semantic.blocks[0].role, content="Title")
  inspect(semantic.blocks[1].role, content="Caption")
  inspect(semantic.blocks[2].role, content="Note")
  inspect(semantic.blocks[2].provenance.slide_no, content="Some(3)")
  inspect(semantic.blocks[3].role, content="Quote")
}

///|
test "semantic document preserves provenance from xlsx epub and pdf hints" {
  let document = @ast.Document::{
    title: Some("Sources"),
    metadata: { "format": "aggregate" },
    blocks: [
      @ast.Heading(2, [@ast.Text("Worksheet")]),
      @ast.Paragraph([@ast.Text("Chapter opener")]),
      @ast.Paragraph([@ast.Text("Page body")]),
    ],
    annotations: [
      @ast.BlockAnnotation::{
        id: "p1",
        source_hint: Some("sheet: Summary"),
        origin_hint: Some("resource: xl/worksheets/sheet1.xml; kind: sheet"),
        diagnostics: [],
      },
      @ast.BlockAnnotation::{
        id: "p2",
        source_hint: Some("chapter: Intro"),
        origin_hint: Some("resource: OPS/chapter1.xhtml; kind: heading"),
        diagnostics: [],
      },
      @ast.BlockAnnotation::{
        id: "p3",
        source_hint: Some("page: 7"),
        origin_hint: Some("resource: pdf/native_text_fast/page/7; kind: page"),
        diagnostics: [],
      },
    ],
  }
  let semantic = semantic_document_of(document)
  inspect(semantic.blocks[0].provenance.sheet_name, content="Some(\"Summary\")")
  inspect(semantic.blocks[1].provenance.chapter, content="Some(\"Intro\")")
  inspect(semantic.blocks[2].provenance.page_no, content="Some(7)")
  inspect(
    semantic.blocks[2].provenance.resource,
    content="Some(\"pdf/native_text_fast/page/7\")",
  )
}
