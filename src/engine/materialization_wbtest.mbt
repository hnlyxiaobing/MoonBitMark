///|
/// Two different byte payloads uploaded under the same file name used to
/// derive the same temp path within one millisecond, so the second write
/// truncated the first (or the first conversion read the second's bytes).
async test "bytes inputs with the same name materialize to distinct files" {
  let first = materialize_input_path(
    @core.BytesInput(Some("same.docx"), b"first", None),
    "docx",
    @core.InspectSourceDocument,
  )
  let second = materialize_input_path(
    @core.BytesInput(Some("same.docx"), b"second", None),
    "docx",
    @core.InspectSourceDocument,
  )
  assert_true(first.file_path != second.file_path)
  assert_eq(@fs.read_file(first.file_path).text(), "first")
  assert_eq(@fs.read_file(second.file_path).text(), "second")
  cleanup_materialized_input(first)
  cleanup_materialized_input(second)
  assert_false(@fs.exists(first.file_path))
  assert_false(@fs.exists(second.file_path))
}
