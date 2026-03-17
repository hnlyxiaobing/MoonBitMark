// CSV Converter - Converts CSV files to Markdown tables

///|
/// Converter for CSV files
pub(all) struct CsvConverter {
  dummy : Int
}

///|
/// Create a new CSV converter
pub fn CsvConverter::new() -> CsvConverter {
  CsvConverter::{ dummy: 0 }
}

///|
/// Accepts function - checks if file is CSV
pub fn CsvConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.mimetype {
    Some(mt) => mt == "text/csv"
    None =>
      match info.extension {
        Some(".csv") => true
        _ => false
      }
  }
}

///|
/// Convert function - converts CSV to Markdown table
pub async fn CsvConverter::convert(file_path : String) -> @core.ConvertResult {
  let file = @fs.open(file_path, mode=ReadOnly)
  let mut content = ""
  let mut is_first = true
  while file.read_until("\n") is Some(line) {
    if is_first {
      // Trim BOM and leading whitespace
      let trimmed = line.trim_start()
      content = content + trimmed.to_string() + "\n"
      is_first = false
    } else {
      content = content + line + "\n"
    }
  }
  file.close()
  @core.ConvertResult::markdown_only(csv_to_markdown(content), "csv")
}

///|
/// Helper function to convert CSV content to Markdown
fn csv_to_markdown(csv : String) -> String {
  let lines = csv.split("\n")
  let lines_array = lines.to_array()
  if lines_array.length() == 0 {
    return ""
  }

  let markdown_lines = Array::new()
  let mut is_header = true

  for line in lines_array {
    if line.trim() == "" {
      continue
    }

    let cells_iter = line.split(",")
    let cells_array = cells_iter.to_array()
    let row = "| " + cells_array.join(" | ") + " |"
    markdown_lines.push(row)

    if is_header {
      let separators = cells_array.map(fn(_) { "---" })
      let separator = "| " + separators.join(" | ") + " |"
      markdown_lines.push(separator)
      is_header = false
    }
  }

  markdown_lines.join("\n")
}
