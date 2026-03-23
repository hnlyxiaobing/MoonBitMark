///|
test "csv helper counts" {
  let rows = parse_csv_rows("a,b\n1,2\n")
  inspect(csv_row_count(rows), content="2")
  inspect(csv_column_count(rows), content="2")
}

///|
test "csv parser supports quoted commas and multiline cells" {
  let rows = parse_csv_rows(
    "name,notes,quote\nAlice,\"line 1\nline 2\",\"He said \"\"hi\"\"\"\n",
  )
  inspect(rows.length(), content="2")
  inspect(rows[1][1], content="line 1\nline 2")
  inspect(rows[1][2], content="He said \"hi\"")
}

///|
test "csv markdown rendering normalizes multiline table cells" {
  let metadata = Map::new()
  let doc = csv_rows_to_document(
    [["name", "notes"], ["Alice", "line 1\nline 2"]],
    Some("demo"),
    metadata,
  )
  inspect(
    @ast.render_markdown(doc),
    content="| name | notes |\n| --- | --- |\n| Alice | line 1<br>line 2 |",
  )
}

///|
test "csv warning diagnostics render markdown phase" {
  let diagnostics = csv_warning_diagnostics("empty.csv", "")
  inspect(diagnostics.length(), content="1")
  inspect(
    diagnostics[0].render(),
    content="Warning: ConverterWarning\n  Phase: render/markdown\n  Source: empty.csv\n  Message: CSV input produced empty Markdown output.\n  Hint: Check whether the CSV contains at least one non-empty row.",
  )
}
