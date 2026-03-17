///|
test "MarkItDown new" {
  let engine = @engine.MarkItDown::new()
  inspect(engine.converters.length(), content="9")
}

///|
test "MarkItDown select converter by extension" {
  let engine = @engine.MarkItDown::new()
  inspect(engine.detect_converter_name("test.txt"), content="text")
}
