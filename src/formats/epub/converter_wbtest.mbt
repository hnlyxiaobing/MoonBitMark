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
    content="Error: ConverterWarning\n  Phase: load/spine-resource\n  Source: OPS/chapter1.xhtml\n  Message: Missing spine resource in archive: OPS/chapter1.xhtml\n  Hint: Inspect archive integrity and verify the expected internal entries exist.",
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
