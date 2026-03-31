///|
test "xlsx file stem helper" {
  inspect(@core.file_stem("sheets/demo.xlsx"), content="Some(\"demo\")")
}

///|
test "xlsx warning diagnostics include workbook source" {
  let diagnostics = xlsx_warning_diagnostics("book.xlsx", [
    "No sheets discovered in xl/workbook.xml.", "XLSX conversion produced empty Markdown output.",
  ])
  inspect(diagnostics.length(), content="2")
  inspect(
    diagnostics[0].render(),
    content="Warning: ConverterWarning\n  Phase: parse/xl/workbook.xml\n  Source: xl/workbook.xml\n  Message: No sheets discovered in xl/workbook.xml.\n  Hint: Inspect archive integrity and verify the expected internal entries exist.",
  )
}

///|
test "xlsx worksheet warning diagnostics target archive entry" {
  let diagnostics = xlsx_warning_diagnostics("book.xlsx", [
    "Failed to parse worksheet XML: Sheet1 (xl/worksheets/sheet1.xml).",
  ])
  inspect(diagnostics.length(), content="1")
  inspect(
    diagnostics[0].render(),
    content="Warning: ConverterWarning\n  Phase: parse/worksheet\n  Source: xl/worksheets/sheet1.xml\n  Message: Failed to parse worksheet XML: Sheet1 (xl/worksheets/sheet1.xml).\n  Hint: Inspect malformed worksheet XML inside the XLSX archive.",
  )
}

///|
test "xlsx asset warning diagnostics target archive entry" {
  let diagnostics = xlsx_warning_diagnostics("book.xlsx", [
    "Failed to extract XLSX asset: xl/media/image1.png",
  ])
  inspect(diagnostics.length(), content="1")
  inspect(
    diagnostics[0].render(),
    content="Warning: ConverterWarning\n  Phase: load/asset\n  Source: xl/media/image1.png\n  Message: Failed to extract XLSX asset: xl/media/image1.png\n  Hint: Inspect archive integrity and verify the expected internal entries exist.",
  )
}

///|
test "xlsx typed failure render targets workbook xml" {
  let rendered = render_xlsx_failure(
    @core.ZipError("Failed to read xl/workbook.xml", Some("xl/workbook.xml")),
    Some(@core.Load(Some("xl/workbook.xml"))),
    Some(@core.ArchiveEntry("xl/workbook.xml")),
    Some(@core.CheckArchiveIntegrity),
  )
  inspect(
    rendered,
    content="Error: ZipError\n  Phase: load/xl/workbook.xml\n  Source: xl/workbook.xml\n  Message: Failed to read xl/workbook.xml (xl/workbook.xml)\n  Hint: Inspect archive integrity and verify the expected internal entries exist.",
  )
}

///|
test "xlsx cell normalization trims whitespace" {
  inspect(normalize_xlsx_cell_text(" first \r\n"), content="first")
}

///|
test "xlsx asset gallery is appended to markdown" {
  inspect(
    append_xlsx_asset_gallery("## Sheet1", [
      @core.OutputAsset::{
        placeholder: "moonbitmark-raw://xlsx/1",
        filename: "xlsx-image-1.png",
        bytes: b"",
        source: None,
        hint: None,
      },
    ]),
    content="## Sheet1\n\n## Embedded Assets\n\n![xlsx-image-1.png](moonbitmark-raw://xlsx/1)",
  )
}

///|
test "xlsx sheet regions split sparse tables and promote a title row" {
  let data = SheetData::{
    rows: [
      ["Quarterly Budget", "", "", ""],
      ["Month", "Amount", "", ""],
      ["Jan", "10", "", ""],
      ["", "", "Owner", "Status"],
      ["", "", "Ada", "Ready"],
    ],
    max_cols: 4,
  }
  let blocks = sheet_data_to_blocks(data)
  inspect(
    @ast.render_markdown(@ast.Document::{ title: None, metadata: {}, blocks }),
    content="### Quarterly Budget\n\n| Month | Amount |\n| --- | --- |\n| Jan | 10 |\n\n| Owner | Status |\n| --- | --- |\n| Ada | Ready |",
  )
}

///|
test "xlsx formula falls back when cached value is missing" {
  inspect(get_cell_value("", "", "SUM(A1:A3)", []), content="=SUM(A1:A3)")
}
