// XLSX Converter Tests

///|
/// Test cell reference to column index conversion
@Test
test test_cell_ref_to_col_index() {
  // A -> 0
  let idx_a = cell_ref_to_col_index("A1")
  inspect(idx_a, content="0")!

  // B -> 1
  let idx_b = cell_ref_to_col_index("B1")
  inspect(idx_b, content="1")!

  // Z -> 25
  let idx_z = cell_ref_to_col_index("Z1")
  inspect(idx_z, content="25")!

  // AA -> 26
  let idx_aa = cell_ref_to_col_index("AA1")
  inspect(idx_aa, content="26")!

  // AB -> 27
  let idx_ab = cell_ref_to_col_index("AB1")
  inspect(idx_ab, content="27")!
}

///|
/// Test strip_namespace function
@Test
test test_strip_namespace() {
  // Strip w: prefix
  let name1 = strip_namespace("w:t")
  inspect(name1, content="t")!

  // No namespace
  let name2 = strip_namespace("t")
  inspect(name2, content="t")!

  // Strip r: prefix
  let name3 = strip_namespace("r:id")
  inspect(name3, content="id")!
}

///|
/// Test resolve_cell_value function
@Test
test test_resolve_cell_value() {
  let shared_strings : Array[String] = ["Name", "Age", "Alice"]

  // Shared string type
  let val1 = resolve_cell_value("s", "0", shared_strings)
  inspect(val1, content="Name")!

  let val2 = resolve_cell_value("s", "2", shared_strings)
  inspect(val2, content="Alice")!

  // Boolean type
  let val3 = resolve_cell_value("b", "1", shared_strings)
  inspect(val3, content="TRUE")!

  let val4 = resolve_cell_value("b", "0", shared_strings)
  inspect(val4, content="FALSE")!

  // Number type (no type attribute)
  let val5 = resolve_cell_value("", "42", shared_strings)
  inspect(val5, content="42")!

  // Error type
  let val6 = resolve_cell_value("e", "#VALUE!", shared_strings)
  inspect(val6, content="#VALUE!")!
}

///|
/// Test XlsxConverter accepts function
@Test
test test_xlsx_accepts() {
  let converter = XlsxConverter::new()

  // Should accept .xlsx extension
  let info1 = @core.StreamInfo::{
    extension: Some(".xlsx"),
    mimetype: None,
    filename: None,
    url: None,
    charset: None,
  }
  assert_true!(converter.accepts(info1))

  // Should accept uppercase extension
  let info2 = @core.StreamInfo::{
    extension: Some(".XLSX"),
    mimetype: None,
    filename: None,
    url: None,
    charset: None,
  }
  assert_true!(converter.accepts(info2))

  // Should not accept other extensions
  let info3 = @core.StreamInfo::{
    extension: Some(".docx"),
    mimetype: None,
    filename: None,
    url: None,
    charset: None,
  }
  assert_true!(!converter.accepts(info3))
}
