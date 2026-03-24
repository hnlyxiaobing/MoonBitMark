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
