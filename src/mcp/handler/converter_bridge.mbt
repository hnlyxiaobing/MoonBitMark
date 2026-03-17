// MoonBitMark MCP Handler - Bridge to Existing Converters

///|
pub fn detect_document_type(input : String) -> String {
  let engine = @engine.MarkItDown::new()
  match try? engine.detect_converter_name(input) {
    Ok(name) => name
    Err(_) => "unknown"
  }
}

///|
pub async fn convert_to_markdown(input : String) -> String {
  let engine = @engine.MarkItDown::new()
  let result = engine.convert(input)
  result.markdown
}
