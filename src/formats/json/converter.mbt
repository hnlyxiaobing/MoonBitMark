// JSON Converter - Converts JSON files to Markdown code blocks

/// Converter for JSON files
pub(all) struct JsonConverter {
  dummy: Int
}

/// Create a new JSON converter
pub fn JsonConverter::new() -> JsonConverter {
  JsonConverter::{
    dummy: 0
  }
}

/// Accepts function - checks if file is JSON
pub fn JsonConverter::accepts(info: @core.StreamInfo) -> Bool {
  match info.mimetype {
    Some(mt) => mt == "application/json"
    None => {
      match info.extension {
        Some(".json") => true
        _ => false
      }
    }
  }
}

/// Convert function - converts JSON to Markdown code block
pub async fn JsonConverter::convert(file_path: String) -> String raise {
  let file = @fs.open(file_path, mode=ReadOnly)
  let mut content = ""
  let mut is_first = true
  while file.read_until("\n") is Some(line) {
    if is_first {
      let trimmed = line.trim_start()
      content = content + trimmed.to_string() + "\n"
      is_first = false
    } else {
      content = content + line + "\n"
    }
  }
  file.close()
  let final_trimmed = content.trim_end()
  // Use Unicode escape for backtick: U+0060
  let bt = "\u{0060}"
  let triple_bt = bt + bt + bt
  triple_bt + " json\n" + final_trimmed.to_string() + "\n" + triple_bt
}