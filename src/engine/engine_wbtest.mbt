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

///|
test "merge diagnostics deduplicates mirrored warnings" {
  let diagnostics = merge_diagnostics(
    [
      @core.warning_diagnostic(
        "Dropped <style> blocks during HTML conversion.",
        Some(@core.Normalize(Some("preprocess"))),
        Some(@core.File("demo.html")),
        Some(@core.InspectSourceDocument),
      ),
    ],
    ["Dropped <style> blocks during HTML conversion."],
    ConverterRegistration::{ kind: Html, name: "html", priority: 70 },
    @core.FileInput("demo.html", None),
  )
  inspect(diagnostics.length(), content="1")
  inspect(
    diagnostics[0].render(),
    content="Warning: ConverterWarning\n  Phase: normalize/preprocess\n  Source: demo.html\n  Message: Dropped <style> blocks during HTML conversion.\n  Hint: Inspect the source document or run with debug context.",
  )
}
