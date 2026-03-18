// MoonBitMark CLI - File to Markdown Converter

///|
struct CliOptions {
  input : String
  output : String?
  ctx : @core.ConvertContext
  diag_json : Bool
  detect_only : Bool
  dump_ast : Bool
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
  println("  --diag-json       Print diagnostics/stats as JSON")
  println("  --detect-only     Only print detection result")
  println("  --dump-ast        Print AST JSON instead of Markdown")
  println("  --debug           Enable debug context")
  println("  --help            Show this help message")
  println("")
  println("Supported formats:")
  println("  - Plain text (.txt)")
  println("  - CSV (.csv)")
  println("  - JSON (.json)")
  println("  - PDF (.pdf)")
  println("  - HTML (.html, .htm, .xhtml)")
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
  let mut diag_json = false
  let mut detect_only = false
  let mut dump_ast = false
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
        "--diag-json" => diag_json = true
        "--detect-only" => detect_only = true
        "--dump-ast" => dump_ast = true
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
  if detect_only && positional.length() > 1 {
    fail("--detect-only does not accept an output file")
  }
  if detect_only && dump_ast {
    fail("--detect-only cannot be combined with --dump-ast")
  }
  if diag_json && dump_ast {
    fail("--diag-json cannot be combined with --dump-ast")
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
    diag_json,
    detect_only,
    dump_ast,
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
    if options.detect_only {
      let detection = engine.detect(options.input)
      let output = if options.diag_json {
        render_detection_json(detection)
      } else {
        detection.render()
      }
      emit_output(output, None)
      return
    }

    let result = engine.convert(options.input, ctx=options.ctx)
    let output = if options.dump_ast {
      render_ast_json(result)
    } else if options.diag_json {
      render_diagnostics_json(result)
    } else {
      result.markdown
    }

    emit_output(output, options.output)

    if options.output is Some(path) && !options.diag_json && !options.dump_ast {
      println("Converted: " + options.input + " -> " + path)
      if options.ctx.debug {
        println("")
        println(result.debug_report())
      }
    }
  } catch {
    err => println("Error: " + err.to_string())
  }
}

///|
async fn emit_output(output : String, path : String?) -> Unit {
  match path {
    Some(file_path) => {
      let file = @fs.open(
        file_path,
        mode=WriteOnly,
        create=0o644,
        truncate=true,
      )
      let bytes = @utf8.encode(output)
      file.write(bytes)
      file.close()
    }
    None => println(output)
  }
}

///|
fn render_detection_json(detection : @engine.DetectionResult) -> String {
  json_object([
    json_field("converter", json_string(detection.converter_name)),
    json_field("stream_info", json_of_stream_info(detection.stream_info)),
  ])
}

///|
fn render_ast_json(result : @core.ConvertResult) -> String {
  match result.document {
    Some(document) => document.to_json().to_string()
    None => "null"
  }
}

///|
fn render_diagnostics_json(result : @core.ConvertResult) -> String {
  let fields : Array[String] = [
    json_field("source_type", json_string(result.source_type)),
    json_field("title", json_string_or_null(result.title)),
    json_field("warnings", json_array_of_strings(result.warnings)),
    json_field("diagnostics", json_array_of_diagnostics(result.diagnostics)),
    json_field("stats", json_of_stats(result.stats)),
    json_field("metadata", json_of_string_map(result.metadata)),
    json_field("asset_count", result.assets.length().to_string()),
  ]
  json_object(fields)
}

///|
fn json_of_stream_info(info : @core.StreamInfo) -> String {
  json_object([
    json_field("mimetype", json_string_or_null(info.mimetype)),
    json_field("extension", json_string_or_null(info.extension)),
    json_field("filename", json_string_or_null(info.filename)),
    json_field("url", json_string_or_null(info.url)),
    json_field("charset", json_string_or_null(info.charset)),
  ])
}

///|
fn json_array_of_diagnostics(
  diagnostics : Array[@core.ConversionDiagnostic],
) -> String {
  let items : Array[String] = []
  for diagnostic in diagnostics {
    items.push(json_of_diagnostic(diagnostic))
  }
  json_array(items)
}

///|
fn json_of_diagnostic(diagnostic : @core.ConversionDiagnostic) -> String {
  json_object([
    json_field("level", json_string(diagnostic.level.label())),
    json_field("category", json_string(diagnostic.category())),
    json_field("message", json_string(diagnostic.message)),
    json_field(
      "phase",
      match diagnostic.phase {
        Some(value) => json_string(value.label())
        None => "null"
      },
    ),
    json_field(
      "source",
      match diagnostic.source {
        Some(value) => json_string(value.label())
        None => "null"
      },
    ),
    json_field(
      "hint",
      match diagnostic.hint {
        Some(value) => json_string(value.message())
        None => "null"
      },
    ),
  ])
}

///|
fn json_of_stats(stats : @core.ConvertStats?) -> String {
  match stats {
    Some(value) =>
      json_object([
        json_field("char_count", value.char_count.to_string()),
        json_field("block_count", value.block_count.to_string()),
        json_field(
          "duration_ms",
          match value.duration_ms {
            Some(duration) => duration.to_string()
            None => "null"
          },
        ),
        json_field(
          "used_fallback",
          if value.used_fallback {
            "true"
          } else {
            "false"
          },
        ),
      ])
    None => "null"
  }
}

///|
fn json_of_string_map(map : Map[String, String]) -> String {
  let fields : Array[String] = []
  for key, value in map {
    fields.push(json_field(key, json_string(value)))
  }
  json_object(fields)
}

///|
fn json_array_of_strings(values : Array[String]) -> String {
  let items : Array[String] = []
  for value in values {
    items.push(json_string(value))
  }
  json_array(items)
}

///|
fn json_field(name : String, value : String) -> String {
  json_string(name) + ":" + value
}

///|
fn json_object(fields : Array[String]) -> String {
  "{" + fields.join(",") + "}"
}

///|
fn json_array(items : Array[String]) -> String {
  "[" + items.join(",") + "]"
}

///|
fn json_string_or_null(value : String?) -> String {
  match value {
    Some(text) => json_string(text)
    None => "null"
  }
}

///|
fn json_string(value : String) -> String {
  let mut escaped = value.replace(old="\\", new="\\\\")
  escaped = escaped.replace(old="\"", new="\\\"")
  escaped = escaped.replace(old="\n", new="\\n")
  escaped = escaped.replace(old="\r", new="\\r")
  escaped = escaped.replace(old="\t", new="\\t")
  "\"" + escaped + "\""
}
