///|
test "epub metadata map includes fields" {
  let metadata = EpubMetadata::default()
  metadata.title = Some("Demo")
  metadata.authors.push("A")
  metadata.language = Some("en")
  let result = metadata_of_epub(metadata, "OPS/content.opf")
  inspect(result["author"], content="A")
}
