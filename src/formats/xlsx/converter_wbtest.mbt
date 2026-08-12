///|
test "xlsx file stem helper" {
  debug_inspect(
    @core.file_stem("sheets/demo.xlsx"),
    content=(
      #|Some("demo")
    ),
  )
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
    @ast.render_markdown(@ast.document(None, {}, blocks)),
    content="### Quarterly Budget\n\n| Month | Amount |\n| --- | --- |\n| Jan | 10 |\n\n| Owner | Status |\n| --- | --- |\n| Ada | Ready |",
  )
}

///|
test "xlsx formula falls back when cached value is missing" {
  inspect(get_cell_value("", "", "SUM(A1:A3)", []), content="=SUM(A1:A3)")
}

///|
fn sheet_events(xml : String) -> Array[@xml.ParseEvent] {
  match @xml.parse_xml(xml) {
    Ok(events) => events
    Err(_) => abort("failed to parse fixture worksheet XML")
  }
}

///|
test "xlsx row numbers pad skipped rows with empty rows" {
  let data = extract_sheet_data(
    sheet_events(
      "<sheetData><row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>top</t></is></c></row><row r=\"4\"><c r=\"A4\" t=\"inlineStr\"><is><t>bottom</t></is></c></row></sheetData>",
    ),
    [],
  )
  inspect(data.rows.length(), content="4")
  debug_inspect(
    data.rows,
    content=(
      #|[["top"], [], [], ["bottom"]]
    ),
  )
}

///|
test "xlsx rows without r attribute fall back to sequential placement" {
  let data = extract_sheet_data(
    sheet_events(
      "<sheetData><row><c r=\"A1\" t=\"inlineStr\"><is><t>a</t></is></c></row><row><c r=\"B2\" t=\"inlineStr\"><is><t>b</t></is></c></row></sheetData>",
    ),
    [],
  )
  inspect(data.rows.length(), content="2")
  debug_inspect(
    data.rows,
    content=(
      #|[["a"], ["", "b"]]
    ),
  )
}

///|
test "xlsx region splitting is insensitive to omitted empty row elements" {
  let with_empty_rows = extract_sheet_data(
    sheet_events(
      "<sheetData><row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>one</t></is></c></row><row r=\"2\"/><row r=\"3\"/><row r=\"4\"><c r=\"A4\" t=\"inlineStr\"><is><t>two</t></is></c></row></sheetData>",
    ),
    [],
  )
  let without_empty_rows = extract_sheet_data(
    sheet_events(
      "<sheetData><row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>one</t></is></c></row><row r=\"4\"><c r=\"A4\" t=\"inlineStr\"><is><t>two</t></is></c></row></sheetData>",
    ),
    [],
  )
  let regions_with = detect_sheet_regions(normalize_sheet_rows(with_empty_rows))
  let regions_without = detect_sheet_regions(
    normalize_sheet_rows(without_empty_rows),
  )
  inspect(regions_with.length(), content="2")
  inspect(regions_without.length(), content="2")
}
