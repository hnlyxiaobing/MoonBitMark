// MoonBitMark CLI - File to Markdown Converter

///|
struct CliOptions {
  input : String
  output : String?
  ctx : @core.ConvertContext
}

///|
fn print_usage() -> Unit {
  println("MoonBitMark v0.3.0 - File to Markdown Converter")
  println("")
  println("Usage: moon run cmd/main [options] <input> [output_file]")
  println("")
  println("Options:")
  println("  --frontmatter     Include YAML frontmatter in markdown output")
  println("  --plain-text      Skip markdown-specific postprocessing")
  println("  --no-metadata     Drop enriched metadata from engine output")
  println(
    "  --asset-dir <dir> Write embedded image assets to the given directory",
  )
  println("  --debug           Enable debug context")
  println("  --help            Show this help message")
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
fn parse_args(args : Array[String]) -> CliOptions raise {
  let mut keep_metadata = true
  let mut debug = false
  let mut asset_output_dir : String? = None
  let mut output_mode = @core.StandardMarkdown
  let positional : Array[String] = []

  for i = 1, pending_asset_dir = false; i < args.length(); i = i + 1 {
    let arg = args[i]
    if pending_asset_dir {
      asset_output_dir = Some(arg)
      continue i + 1, false
    }

    if positional.length() == 0 && arg.has_prefix("--") {
      match arg {
        "--frontmatter" => output_mode = @core.FrontMatterMarkdown
        "--plain-text" => output_mode = @core.PlainText
        "--no-metadata" => keep_metadata = false
        "--debug" => debug = true
        "--asset-dir" => continue i + 1, true
        _ => fail("Unknown option: " + arg)
      }
      continue
    }

    positional.push(arg)
  } nobreak {
    if pending_asset_dir {
      fail("Missing directory after --asset-dir")
    }
  }

  if positional.length() == 0 {
    fail("Missing input path or URL")
  }
  if positional.length() > 2 {
    fail("Too many positional arguments")
  }

  CliOptions::{
    input: positional[0],
    output: positional.get(1),
    ctx: @core.ConvertContext::{
      keep_metadata,
      debug,
      max_file_size: None,
      timeout_ms: None,
      asset_output_dir,
      output_mode,
    },
  }
}

///|
async fn main {
  let args = @env.args()

  if args.length() < 2 || args.contains("--help") {
    print_usage()
    return
  }

  let options = parse_args(args) catch {
    err => {
      print_usage()
      println("")
      println("Error: " + err.to_string())
      return
    }
  }
  let engine = @engine.MarkItDown::new()

  try {
    let result = engine.convert(options.input, ctx=options.ctx)

    match options.output {
      Some(path) => {
        let file = @fs.open(path, mode=WriteOnly, create=0o644, truncate=true)
        let bytes = @utf8.encode(result.markdown)
        file.write(bytes)
        file.close()
        println("Converted: " + options.input + " -> " + path)
      }
      None => println(result.markdown)
    }
  } catch {
    err => println("Error: " + err.to_string())
  }
}
