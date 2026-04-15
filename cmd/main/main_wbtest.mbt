///|
test "parse args enables frontmatter and output file" {
  let options = parse_args([
    "moonbitmark", "--frontmatter", "demo.docx", "out.md",
  ])
  inspect(options.input, content="demo.docx")
  inspect(options.output, content="Some(\"out.md\")")
  inspect(options.ctx.output_mode, content="FrontMatterMarkdown")
}

///|
test "parse args supports metadata and asset flags" {
  let options = parse_args([
    "moonbitmark", "--no-metadata", "--asset-dir", "assets", "demo.epub",
  ])
  inspect(options.ctx.keep_metadata, content="false")
  inspect(options.ctx.asset_output_dir, content="Some(\"assets\")")
}

///|
test "parse args supports ocr flags" {
  let options = parse_args([
    "moonbitmark", "--ocr", "force", "--ocr-lang", "chi_sim", "--ocr-images", "--ocr-backend",
    "mock", "--ocr-timeout", "2500", "scan.png",
  ])
  inspect(options.ctx.ocr.mode, content="Force")
  inspect(options.ctx.ocr.language, content="chi_sim")
  inspect(options.ctx.ocr.enable_embedded_images, content="true")
  inspect(options.ctx.ocr.backend, content="Some(\"mock\")")
  inspect(options.ctx.ocr.timeout_ms, content="Some(2500)")
}

///|
test "parse args supports detect and diagnostics flags" {
  let options = parse_args([
    "moonbitmark", "--detect-only", "--diag-json", "demo.html",
  ])
  inspect(options.detect_only, content="true")
  inspect(options.diag_json, content="true")
}

///|
test "parse args supports dump ast" {
  let options = parse_args(["moonbitmark", "--dump-ast", "demo.html"])
  inspect(options.dump_ast, content="true")
}

///|
test "render ast json emits strict schema" {
  let result = @core.ConvertResult::markdown_only("", "html").with_document(
    Some(
      @ast.document(Some("Smoke Title"), { "source": "fixture" }, [
        @ast.Heading(1, [@ast.Text("Heading")]),
        @ast.Paragraph([@ast.Text("Body")]),
        @ast.List([[@ast.Strong([@ast.Text("One")])]], false),
      ]),
    ),
  )
  inspect(
    render_ast_json(result),
    content="{\"title\":\"Smoke Title\",\"metadata\":{\"source\":\"fixture\"},\"blocks\":[{\"type\":\"heading\",\"level\":1,\"inlines\":[{\"type\":\"text\",\"content\":\"Heading\"}]},{\"type\":\"paragraph\",\"inlines\":[{\"type\":\"text\",\"content\":\"Body\"}]},{\"type\":\"list\",\"ordered\":false,\"items\":[[{\"type\":\"strong\",\"children\":[{\"type\":\"text\",\"content\":\"One\"}]}]]}],\"annotations\":[{\"id\":\"block-1\",\"source_hint\":null,\"origin_hint\":null,\"diagnostics\":[]},{\"id\":\"block-2\",\"source_hint\":null,\"origin_hint\":null,\"diagnostics\":[]},{\"id\":\"block-3\",\"source_hint\":null,\"origin_hint\":null,\"diagnostics\":[]}]}",
  )
}

///|
test "json string escapes backslashes" {
  assert_eq(json_string("tail \\"), "\"" + "tail \\\\" + "\"")
}

///|
test "json string escapes windows paths as valid json" {
  inspect(
    json_string("tests\\conversion_eval\\fixtures\\inputs\\pdf\\fake_memo.pdf"),
    content="\"tests\\\\conversion_eval\\\\fixtures\\\\inputs\\\\pdf\\\\fake_memo.pdf\"",
  )
}

///|
test "render ast json returns null without document" {
  inspect(
    render_ast_json(@core.ConvertResult::markdown_only("", "text")),
    content="null",
  )
}

///|
test "render semantic json includes provenance and confidence fields" {
  let document = @semantic.SemanticDocument::{
    title: Some("Demo"),
    provenance: @semantic.Provenance::{
      source_path: Some("docs/demo.docx"),
      source_url: None,
      page_no: None,
      slide_no: Some(2),
      sheet_name: None,
      chapter: Some("Overview"),
      resource: Some("word/document.xml"),
    },
    sections: [
      @semantic.Section::{
        id: "section-1",
        title: Some("Intro"),
        level: 1,
        role: @semantic.Title,
        block_indices: [0],
        diagnostics: [],
        provenance: @semantic.Provenance::{
          source_path: Some("docs/demo.docx"),
          source_url: None,
          page_no: None,
          slide_no: Some(2),
          sheet_name: None,
          chapter: Some("Overview"),
          resource: Some("word/document.xml"),
        },
        children: [],
      },
    ],
    blocks: [
      @semantic.SemanticBlock::{
        block_id: "block-1",
        index: 0,
        role: @semantic.Title,
        text: "Intro",
        source_hint: Some("slide: 2"),
        origin_hint: Some("resource: word/document.xml"),
        diagnostics: [],
        confidence: 88,
        provenance: @semantic.Provenance::{
          source_path: Some("docs/demo.docx"),
          source_url: None,
          page_no: None,
          slide_no: Some(2),
          sheet_name: None,
          chapter: Some("Overview"),
          resource: Some("resource: word/document.xml"),
        },
      },
    ],
  }
  inspect(
    render_semantic_json(Some(document)),
    content="{\"title\":\"Demo\",\"provenance\":{\"source_path\":\"docs/demo.docx\",\"source_url\":null,\"page_no\":null,\"slide_no\":2,\"sheet_name\":null,\"chapter\":\"Overview\",\"resource\":\"word/document.xml\"},\"sections\":[{\"id\":\"section-1\",\"title\":\"Intro\",\"level\":1,\"role\":\"Title\",\"block_indices\":[0],\"diagnostics\":[],\"provenance\":{\"source_path\":\"docs/demo.docx\",\"source_url\":null,\"page_no\":null,\"slide_no\":2,\"sheet_name\":null,\"chapter\":\"Overview\",\"resource\":\"word/document.xml\"},\"children\":[]}],\"blocks\":[{\"block_id\":\"block-1\",\"index\":0,\"role\":\"Title\",\"text\":\"Intro\",\"source_hint\":\"slide: 2\",\"origin_hint\":\"resource: word/document.xml\",\"diagnostics\":[],\"confidence\":88,\"provenance\":{\"source_path\":\"docs/demo.docx\",\"source_url\":null,\"page_no\":null,\"slide_no\":2,\"sheet_name\":null,\"chapter\":\"Overview\",\"resource\":\"resource: word/document.xml\"}}]}",
  )
}

///|
test "parse args rejects missing input" {
  let result : Result[CliOptions, Error] = try? parse_args([
    "moonbitmark", "--frontmatter",
  ])
  guard result is Err(_) else {
    fail("expected parse_args to fail without an input")
  }
}

///|
test "parse args rejects output with detect only" {
  let result : Result[CliOptions, Error] = try? parse_args([
    "moonbitmark", "--detect-only", "demo.docx", "out.md",
  ])
  guard result is Err(_) else {
    fail("expected parse_args to reject output with detect-only")
  }
}

///|
test "parse args rejects dump ast with detect only" {
  let result : Result[CliOptions, Error] = try? parse_args([
    "moonbitmark", "--detect-only", "--dump-ast", "demo.docx",
  ])
  guard result is Err(_) else {
    fail("expected parse_args to reject dump-ast with detect-only")
  }
}

///|
test "parse args rejects invalid ocr mode" {
  let result : Result[CliOptions, Error] = try? parse_args([
    "moonbitmark", "--ocr", "sometimes", "demo.png",
  ])
  guard result is Err(_) else {
    fail("expected parse_args to reject invalid ocr mode")
  }
}

///|
test "validate output path rejects input overwrite" {
  let result : Result[Unit, Error] = try? validate_output_path(
    "fixtures\\scan.png", "fixtures/scan.png",
  )
  guard result is Err(_) else {
    fail("expected validate_output_path to reject overwrite path")
  }
}
