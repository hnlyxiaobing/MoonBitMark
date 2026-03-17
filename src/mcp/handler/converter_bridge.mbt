// MoonBitMark MCP Handler - Bridge to Existing Converters

///|
pub fn detect_document_type(input : String) -> String {
  let engine = @engine.MarkItDown::new()
  let detected : Result[String, Error] = try? engine.detect_converter_name(
    input,
  )
  match detected {
    Ok(name) => name
    Err(_) => "unknown"
  }
}

///|
pub async fn convert_document_to_markdown(input : String) -> String {
  let engine = @engine.MarkItDown::new()
  let result = engine.convert(input)
  result.markdown
}
