// Core package tests

///|
test "MarkItDown new" {
  let engine = @core.MarkItDown::new()
  inspect(engine.dummy, content="0")
}

///|
test "MarkItDown convert" {
  let result = @core.MarkItDown::convert("test.txt")
  inspect(result, content="Converted: test.txt")
}
