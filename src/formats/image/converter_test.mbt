///|
test "ImageConverter accepts png extension" {
  let info = @core.StreamInfo::{
    mimetype: None,
    extension: Some(".png"),
    filename: Some("scan.png"),
    url: None,
    charset: None,
  }
  assert_true(@image.ImageConverter::accepts(info))
}

///|
test "ImageConverter rejects text extension" {
  let info = @core.StreamInfo::{
    mimetype: None,
    extension: Some(".txt"),
    filename: Some("notes.txt"),
    url: None,
    charset: None,
  }
  assert_false(@image.ImageConverter::accepts(info))
}
