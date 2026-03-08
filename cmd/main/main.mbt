// MoonBitMark CLI - File to Markdown Converter

fn print_usage() -> Unit {
  println("MoonBitMark v0.3.0 - File to Markdown Converter")
  println("")
  println("Usage: moon run cmd/main <input> [output_file]")
  println("")
  println("Supported formats:")
  println("  - Plain text (.txt)")
  println("  - CSV (.csv)")
  println("  - JSON (.json)")
  println("  - PDF (.pdf)")
  println("  - HTML (.html, .htm)")
  println("  - Word (.docx)")
  println("  - URL (http://... or https://...)")
}

async fn main {
  let args = @env.args()
  
  if args.length() < 2 {
    print_usage()
    return
  }
  
  let input_file = args[1]
  let output_file = if args.length() >= 3 {
    Some(args[2])
  } else {
    None
  }
  
  try {
    let result = convert_file(input_file)
    
    match output_file {
      Some(path) => {
        let file = @fs.open(path, mode=WriteOnly, create=0o644, truncate=true)
        let bytes = @utf8.encode(result)
        file.write(bytes)
        file.close()
        println("Converted: " + input_file + " -> " + path)
      }
      None => {
        println(result)
      }
    }
  } catch {
    err => {
      println("Error: " + err.to_string())
    }
  }
}

async fn convert_file(file_path: String) -> String raise {
  let file_lower = file_path.to_lower()
  if file_lower.has_suffix(".txt") {
    @text.TextConverter::convert(file_path)
  } else if file_lower.has_suffix(".csv") {
    @csv.CsvConverter::convert(file_path)
  } else if file_lower.has_suffix(".json") {
    @json.JsonConverter::convert(file_path)
  } else if file_lower.has_suffix(".pdf") {
    @pdf.PdfConverter::convert(file_path)
  } else if file_lower.has_suffix(".html") || file_lower.has_suffix(".htm") {
    @html.HtmlConverter::convert(file_path)
  } else if file_lower.has_suffix(".docx") {
    @docx.DocxConverter::convert(file_path)
  } else if file_lower.has_prefix("http://") || file_lower.has_prefix("https://") {
    @html.HtmlConverter::convert(file_path)
  } else {
    fail("Unknown format: " + file_path)
  }
}
