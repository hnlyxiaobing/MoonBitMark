// PPTX Converter Tests

///|
test "PptxConverter::new creates converter" {
  let converter = @pptx.PptxConverter::new()
  inspect(converter.dummy, content="0")
}

///|
test "PptxConverter::accepts .pptx extension" {
  let info = @core.StreamInfo::{
    extension: Some(".pptx"),
    filename: Some("test.pptx"),
    mimetype: None,
    url: None,
    charset: None,
  }
  assert_true(@pptx.PptxConverter::accepts(info))
}

///|
test "PptxConverter::accepts .PPTX extension (case insensitive)" {
  let info = @core.StreamInfo::{
    extension: Some(".PPTX"),
    filename: Some("TEST.PPTX"),
    mimetype: None,
    url: None,
    charset: None,
  }
  assert_true(@pptx.PptxConverter::accepts(info))
}

///|
test "PptxConverter::rejects non-pptx extension" {
  let info = @core.StreamInfo::{
    extension: Some(".docx"),
    filename: Some("test.docx"),
    mimetype: None,
    url: None,
    charset: None,
  }
  assert_false(@pptx.PptxConverter::accepts(info))
}

///|
test "PptxConverter::rejects missing extension" {
  let info = @core.StreamInfo::{
    extension: None,
    filename: None,
    mimetype: None,
    url: None,
    charset: None,
  }
  assert_false(@pptx.PptxConverter::accepts(info))
}
