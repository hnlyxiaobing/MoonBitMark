// MoonBitMark CLI - File to Markdown Converter

///|
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
  println("  - PowerPoint (.pptx)")
  println("  - Excel (.xlsx)")
  println("  - EPUB (.epub)")
  println("  - URL (http://... or https://...)")
}

///|
async fn main {
  let args = @env.args()

  if args.length() < 2 {
    print_usage()
    return
  }

  let input_file = args[1]
  let output_file = if args.length() >= 3 { Some(args[2]) } else { None }
  let engine = @engine.MarkItDown::new()

  try {
    let result = engine.convert(input_file)

    match output_file {
      Some(path) => {
        let file = @fs.open(path, mode=WriteOnly, create=0o644, truncate=true)
        let bytes = @utf8.encode(result.markdown)
        file.write(bytes)
        file.close()
        println("Converted: " + input_file + " -> " + path)
      }
      None => println(result.markdown)
    }
  } catch {
    err => println("Error: " + err.to_string())
  }
}
