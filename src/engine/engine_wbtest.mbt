///|
test "rendered diagnostics are passed through" {
  let message = @core.error_diagnostic(
    @core.ZipError("Bad archive", Some("book.epub")),
    Some(@core.Load(Some("archive"))),
    Some(@core.File("book.epub")),
    Some(@core.CheckArchiveIntegrity),
  ).render()
  inspect(is_rendered_diagnostic(message), content="true")
}
