// XLSX Converter Tests

///|
/// Test XlsxConverter::accepts with .xlsx extension
test "XlsxConverter accepts .xlsx extension" {
  let info = @core.StreamInfo::{
    extension: Some(".xlsx"),
    mimetype: None,
    filename: None,
    url: None,
    charset: None,
  }
  let result = XlsxConverter::accepts(info)
  inspect(result, content="true")
}

///|
/// Test XlsxConverter::accepts with uppercase extension
test "XlsxConverter accepts .XLSX extension" {
  let info = @core.StreamInfo::{
    extension: Some(".XLSX"),
    mimetype: None,
    filename: None,
    url: None,
    charset: None,
  }
  let result = XlsxConverter::accepts(info)
  inspect(result, content="true")
}

///|
/// Test XlsxConverter::accepts rejects other extensions
test "XlsxConverter rejects .docx extension" {
  let info = @core.StreamInfo::{
    extension: Some(".docx"),
    mimetype: None,
    filename: None,
    url: None,
    charset: None,
  }
  let result = XlsxConverter::accepts(info)
  inspect(result, content="false")
}

///|
/// Test XlsxConverter::accepts with no extension
test "XlsxConverter handles no extension" {
  let info = @core.StreamInfo::{
    extension: None,
    mimetype: None,
    filename: None,
    url: None,
    charset: None,
  }
  let result = XlsxConverter::accepts(info)
  inspect(result, content="false")
}
