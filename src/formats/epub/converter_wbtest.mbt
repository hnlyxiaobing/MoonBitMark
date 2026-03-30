///|
test "epub metadata map includes fields" {
  let metadata = EpubMetadata::default()
  metadata.title = Some("Demo")
  metadata.authors.push("A")
  metadata.language = Some("en")
  let result = metadata_of_epub(metadata, "OPS/content.opf")
  inspect(result["author"], content="A")
}

///|
test "epub warning diagnostics classify spine issues" {
  let diagnostics = epub_warning_diagnostics([
    "Missing spine resource in archive: OPS/chapter1.xhtml", "Missing manifest item for spine idref: chap2",
  ])
  inspect(diagnostics.length(), content="2")
  inspect(
    diagnostics[0].render(),
    content="Warning: ConverterWarning\n  Phase: load/spine-resource\n  Source: OPS/chapter1.xhtml\n  Message: Missing spine resource in archive: OPS/chapter1.xhtml\n  Hint: Inspect archive integrity and verify the expected internal entries exist.",
  )
}

///|
test "epub warning diagnostics classify asset extraction issues" {
  let diagnostics = epub_warning_diagnostics([
    "Failed to extract EPUB asset: OPS/images/cover.jpg",
  ])
  inspect(diagnostics.length(), content="1")
  inspect(
    diagnostics[0].render(),
    content="Warning: ConverterWarning\n  Phase: load/asset\n  Source: OPS/images/cover.jpg\n  Message: Failed to extract EPUB asset: OPS/images/cover.jpg\n  Hint: Inspect archive integrity and verify the expected internal entries exist.",
  )
}

///|
test "epub typed failure render includes archive source" {
  let rendered = render_epub_failure(
    @core.ZipError(
      "Failed to read container.xml",
      Some("META-INF/container.xml"),
    ),
    Some(@core.Load(Some("container"))),
    Some(@core.ArchiveEntry("META-INF/container.xml")),
    Some(@core.CheckArchiveIntegrity),
  )
  inspect(
    rendered,
    content="Error: ZipError\n  Phase: load/container\n  Source: META-INF/container.xml\n  Message: Failed to read container.xml (META-INF/container.xml)\n  Hint: Inspect archive integrity and verify the expected internal entries exist.",
  )
}

///|
test "epub sanitization drops raw media fragments" {
  inspect(
    sanitize_epub_text(
      "id=\"video1\" controls=\"controls\" src=\"../video/shared-culture.mp4\" type=\"video/mp4\"",
    ),
    content="",
  )
}

///|
test "epub sanitization trims media annotations and reader notices" {
  inspect(
    sanitize_epub_text(
      "what does it mean to be human epubReadingSystem aware scripted video control using click and dblclick, space key. Video sources: mp4, webm",
    ),
    content="what does it mean to be human",
  )
  inspect(
    sanitize_epub_text("Your Reading System does not support (this) video."),
    content="",
  )
  inspect(sanitize_epub_text("play pause mute unmute MUTED"), content="")
}

///|
test "epub identifies gutenberg license blocks and end markers" {
  inspect(
    is_epub_gutenberg_license_block(
      "This ebook is for the use of anyone anywhere in the United States and most other parts of the world at no cost and with almost no restrictions whatsoever.",
    ),
    content="true",
  )
  inspect(
    is_epub_end_gutenberg_marker(
      "*** END OF THE PROJECT GUTENBERG EBOOK WINTER SPORTS IN SWITZERLAND ***",
    ),
    content="true",
  )
}

///|
test "epub trims trailing gutenberg license blocks" {
  let blocks = trim_epub_trailing_gutenberg_blocks([
    @ast.text_heading(2, "CHAPTER I"),
    @ast.text_paragraph("Body paragraph"),
    @ast.text_paragraph(
      "*** END OF THE PROJECT GUTENBERG EBOOK WINTER SPORTS IN SWITZERLAND ***",
    ),
    @ast.text_paragraph("The full Project Gutenberg license follows."),
  ])
  inspect(
    @ast.render_markdown(@ast.Document::{ title: None, metadata: {}, blocks }),
    content="## CHAPTER I\n\nBody paragraph",
  )
}

///|
test "epub parses gutenberg xhtml without boilerplate heading noise" {
  let sample = "<?xml version=\"1.0\" encoding=\"utf-8\"?>" +
    "<html xmlns=\"http://www.w3.org/1999/xhtml\">" +
    "<body class=\"x-ebookmaker x-ebookmaker-2\"><div class=\"pg-boilerplate pgheader section\">" +
    "<h2>The Project Gutenberg eBook of Winter Sports in Switzerland, by E. F. Benson</h2>" +
    "<p><strong>Title</strong>: Winter Sports in Switzerland</p>" +
    "</div>" +
    "<table><tr><td>Contents.</td></tr></table>" +
    "<h2><a id=\"CHAPTER_I\"/>CHAPTER I<br/><br/><small>THE SUN-SEEKER</small></h2>" +
    "<p>There is an amazingly silly proverb.</p>" +
    "</body></html>"
  let blocks = parse_epub_special_xhtml(sample, "OPS/60153-h-0.htm.html").unwrap()
  inspect(
    @ast.render_markdown(@ast.Document::{ title: None, metadata: {}, blocks }),
    content="## The Project Gutenberg eBook of Winter Sports in Switzerland, by E. F. Benson\n\n## CHAPTER I THE SUN-SEEKER\n\nThere is an amazingly silly proverb.",
  )
}

///|
test "epub asset appendix only keeps ocr blocks" {
  let blocks = append_epub_asset_blocks(
    [@ast.text_paragraph("body")],
    [
      @core.OutputAsset::{
        placeholder: "moonbitmark-asset://epub-asset-1.jpg",
        filename: "epub-asset-1.jpg",
        bytes: b"",
        source: None,
        hint: None,
      },
    ],
    [],
  )
  inspect(
    @ast.render_markdown(@ast.Document::{ title: None, metadata: {}, blocks }),
    content="body",
  )
}
