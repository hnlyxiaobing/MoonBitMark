///|
test "MarkItDown new" {
  let engine = @engine.MarkItDown::new()
  inspect(engine.converters.length(), content="10")
}

///|
test "MarkItDown select converter by extension" {
  let engine = @engine.MarkItDown::new()
  inspect(engine.detect_converter_name("test.txt"), content="text")
}

///|
test "MarkItDown detects image converter by extension" {
  let engine = @engine.MarkItDown::new()
  inspect(engine.detect_converter_name("scan.png"), content="image")
}

///|
test "custom registration keeps highest priority" {
  let engine = @engine.MarkItDown::{ converters: [] }
    .register_named(@engine.Text, 10)
    .register_named(@engine.Html, 50)
  let info = @core.StreamInfo::{
    mimetype: Some("text/html"),
    extension: Some(".html"),
    filename: Some("index.html"),
    url: None,
    charset: None,
  }
  inspect(engine.select_converter(info).name, content="html")
}
