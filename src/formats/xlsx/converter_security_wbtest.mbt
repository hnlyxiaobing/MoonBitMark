// White-box regression tests for the XLSX sheet parser.
//
// The cases below cover the resource-amplification and index hardening in
// `extract_sheet_data` / `cell_ref_to_col_index`: attacker controlled row
// numbers and cell references must never materialize an unbounded amount of
// memory nor write through a negative array index.

///|
fn xlsx_security_events(xml : String) -> Array[@xml.ParseEvent] {
  @xml.parse_xml(xml) catch {
    _ => abort("failed to parse fixture worksheet XML")
  }
}

///|
test "xlsx row index beyond the excel limit does not materialize placeholder rows" {
  let data = extract_sheet_data(
    xlsx_security_events(
      "<sheetData><row r=\"999999999\"><c r=\"A1\" t=\"inlineStr\"><is><t>x</t></is></c></row></sheetData>",
    ),
    [],
  )
  assert_eq(data.rows.length(), 1)
}

///|
test "xlsx cell without r attribute is appended instead of writing a negative index" {
  let data = extract_sheet_data(
    xlsx_security_events(
      "<sheetData><row r=\"1\"><c t=\"inlineStr\"><is><t>x</t></is></c></row></sheetData>",
    ),
    [],
  )
  assert_eq(data.rows.length(), 1)
  debug_inspect(
    data.rows,
    content=(
      #|[["x"]]
    ),
  )
}

///|
test "xlsx cell reference beyond the excel column limit is not materialized" {
  let data = extract_sheet_data(
    xlsx_security_events(
      "<sheetData><row r=\"1\"><c r=\"ZZZZZZZ1\" t=\"inlineStr\"><is><t>x</t></is></c></row></sheetData>",
    ),
    [],
  )
  assert_eq(data.rows.length(), 1)
  assert_true(data.max_cols <= xlsx_max_cols)
}

///|
test "xlsx cell reference with six letters does not allocate hundreds of millions of columns" {
  let data = extract_sheet_data(
    xlsx_security_events(
      "<sheetData><row r=\"1\"><c r=\"ZZZZZZ1\" t=\"inlineStr\"><is><t>x</t></is></c></row></sheetData>",
    ),
    [],
  )
  assert_eq(data.rows.length(), 1)
  assert_true(data.max_cols <= xlsx_max_cols)
}

///|
test "xlsx column reference at the excel limit is preserved" {
  let data = extract_sheet_data(
    xlsx_security_events(
      "<sheetData><row r=\"1\"><c r=\"XFD1\" t=\"inlineStr\"><is><t>x</t></is></c></row></sheetData>",
    ),
    [],
  )
  assert_eq(data.max_cols, xlsx_max_cols)
}

///|
test "xlsx row index that overflows int32 is treated as sequential" {
  let data = extract_sheet_data(
    xlsx_security_events(
      "<sheetData><row r=\"9999999999\"><c r=\"A1\" t=\"inlineStr\"><is><t>x</t></is></c></row></sheetData>",
    ),
    [],
  )
  assert_eq(data.rows.length(), 1)
}

///|
test "xlsx padded rows stay within the cell budget" {
  let data = extract_sheet_data(
    xlsx_security_events(
      "<sheetData><row r=\"1\"><c r=\"XFD1\" t=\"inlineStr\"><is><t>x</t></is></c></row><row r=\"2\"><c r=\"A2\" t=\"inlineStr\"><is><t>y</t></is></c></row></sheetData>",
    ),
    [],
  )
  let normalized = normalize_sheet_rows(data)
  let mut total = 0
  for row in normalized {
    total = total + row.length()
  }
  assert_true(total <= xlsx_max_cells)
}
