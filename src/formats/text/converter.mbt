// Plain Text Converter

/// Converter for plain text files
pub(all) struct TextConverter {
  dummy: Int
}

/// Create a new text converter
pub fn TextConverter::new() -> TextConverter {
  TextConverter::{
    dummy: 0
  }
}

/// Accepts function - checks if file is text
pub fn TextConverter::accepts(info: @core.StreamInfo) -> Bool {
  match info.mimetype {
    Some(mt) => mt == "text/plain"
    None => {
      match info.extension {
        Some(".txt") => true
        _ => false
      }
    }
  }
}

/// Convert function - reads file and returns content
pub async fn TextConverter::convert(file_path: String) -> String raise {
  let file = @fs.open(file_path, mode=ReadOnly)
  let mut content = ""
  while file.read_until("\n") is Some(line) {
    content = content + line + "\n"
  }
  file.close()
  content
}