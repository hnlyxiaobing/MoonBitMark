///|
test "csv helper counts" {
  inspect(csv_row_count("a,b\n1,2\n"), content="2")
  inspect(csv_column_count("a,b\n1,2\n"), content="2")
}

///|
test "csv warning diagnostics render markdown phase" {
  let diagnostics = csv_warning_diagnostics("empty.csv", "")
  inspect(diagnostics.length(), content="1")
  inspect(
    diagnostics[0].render(),
    content="Error: ConverterWarning\n  Phase: render/markdown\n  Source: empty.csv\n  Message: CSV input produced empty Markdown output.\n  Hint: Check whether the CSV contains at least one non-empty row.",
  )
}
