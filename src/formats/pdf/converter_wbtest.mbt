///|
test "pdf helper counts and file stem" {
  inspect(count_occurrences("a---a---", "---"), content="2")
  inspect(file_stem("reports/spec.pdf"), content="Some(\"spec\")")
}

///|
test "pdf warning diagnostics render postprocess phase" {
  let diagnostics = pdf_warning_diagnostics("spec.pdf", ".1\nBody", ".1 Body")
  inspect(diagnostics.length(), content="1")
  inspect(
    diagnostics[0].render(),
    content="Error: ConverterWarning\n  Phase: postprocess/numbering-merge\n  Source: spec.pdf\n  Message: Merged partial numbering lines during PDF post-processing.\n  Hint: Review merged numbering if the PDF relies on strict line boundaries.",
  )
}
