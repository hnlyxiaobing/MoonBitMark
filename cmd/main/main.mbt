// MoonBitMark CLI - File to Markdown Converter

///|
struct CliOptions {
  input : String
  output : String?
  ctx : @core.ConvertContext
  diag_json : Bool
  detect_only : Bool
  dump_ast : Bool
  dump_raw_ast : Bool
  dump_normalized_ast : Bool
  dump_semantic : Bool
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
  println("  --ocr <off|auto|force> Configure OCR strategy")
  println("  --ocr-lang <lang> Set OCR language (default: eng)")
  println("  --ocr-images     OCR embedded images in supported archive formats")
  println(
    "  --ocr-backend <backend> Select OCR backend (auto/mock/tesseract via Python bridge)",
  )
  println("  --ocr-timeout <ms> Set OCR backend timeout in milliseconds")
  println("  --diag-json       Print diagnostics/stats as JSON")
  println("  --detect-only     Only print detection result")
  println("  --dump-ast        Print AST as strict JSON instead of Markdown")
  println("  --dump-raw-ast    Print raw AST before normalization")
  println("  --dump-normalized-ast Print normalized AST after shared passes")
  println("  --dump-semantic   Print derived semantic section tree")
  println("  --debug           Enable debug context")
  println("  --help            Show this help message")
  println("")
  println("Supported formats:")
  println("  - Plain text (.txt)")
  println("  - CSV (.csv)")
  println("  - JSON (.json)")
  println("  - PDF (.pdf)")
  println("  - Images (.png, .jpg, .jpeg, .bmp, .gif, .tif, .tiff, .webp)")
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
  let mut dump_raw_ast = false
  let mut dump_normalized_ast = false
  let mut dump_semantic = false
  let mut asset_output_dir : String? = None
  let mut output_mode = @core.StandardMarkdown
  let mut ocr_mode = @ocr.Off
  let mut ocr_language = "eng"
  let mut ocr_images = false
  let mut ocr_backend : String? = None
  let mut ocr_timeout_ms : Int? = None
  let positional : Array[String] = []

  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if positional.length() == 0 && arg.has_prefix("--") {
      match arg {
        "--frontmatter" => output_mode = @core.FrontMatterMarkdown
        "--plain-text" => output_mode = @core.PlainText
        "--no-metadata" => keep_metadata = false
        "--diag-json" => diag_json = true
        "--detect-only" => detect_only = true
        "--dump-ast" => dump_ast = true
        "--dump-raw-ast" => dump_raw_ast = true
        "--dump-normalized-ast" => dump_normalized_ast = true
        "--dump-semantic" => dump_semantic = true
        "--debug" => debug = true
        "--ocr-images" => ocr_images = true
        "--asset-dir" => {
          if i + 1 >= args.length() {
            fail("Missing directory after --asset-dir")
          }
          asset_output_dir = Some(args[i + 1])
          i = i + 2
          continue
        }
        "--ocr" => {
          if i + 1 >= args.length() {
            fail("Missing mode after --ocr")
          }
          ocr_mode = parse_ocr_mode(args[i + 1])
          i = i + 2
          continue
        }
        "--ocr-lang" => {
          if i + 1 >= args.length() {
            fail("Missing language after --ocr-lang")
          }
          ocr_language = args[i + 1]
          i = i + 2
          continue
        }
        "--ocr-backend" => {
          if i + 1 >= args.length() {
            fail("Missing backend after --ocr-backend")
          }
          ocr_backend = Some(args[i + 1])
          i = i + 2
          continue
        }
        "--ocr-timeout" => {
          if i + 1 >= args.length() {
            fail("Missing value after --ocr-timeout")
          }
          ocr_timeout_ms = Some(
            parse_positive_int(args[i + 1], "--ocr-timeout"),
          )
          i = i + 2
          continue
        }
        _ => fail("Unknown option: " + arg)
      }
      i = i + 1
      continue
    }

    positional.push(arg)
    i = i + 1
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
  if detect_only && dump_raw_ast {
    fail("--detect-only cannot be combined with --dump-raw-ast")
  }
  if detect_only && dump_normalized_ast {
    fail("--detect-only cannot be combined with --dump-normalized-ast")
  }
  if detect_only && dump_semantic {
    fail("--detect-only cannot be combined with --dump-semantic")
  }
  if diag_json && dump_ast {
    fail("--diag-json cannot be combined with --dump-ast")
  }
  if diag_json && dump_raw_ast {
    fail("--diag-json cannot be combined with --dump-raw-ast")
  }
  if diag_json && dump_normalized_ast {
    fail("--diag-json cannot be combined with --dump-normalized-ast")
  }
  if diag_json && dump_semantic {
    fail("--diag-json cannot be combined with --dump-semantic")
  }
  let dump_count = bool_count([
    dump_ast, dump_raw_ast, dump_normalized_ast, dump_semantic,
  ])
  if dump_count > 1 {
    fail("Only one dump mode can be enabled at a time")
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
      ocr: @ocr.OcrConfig::{
        mode: ocr_mode,
        language: ocr_language,
        enable_embedded_images: ocr_images,
        backend: ocr_backend,
        timeout_ms: ocr_timeout_ms,
      },
    },
    diag_json,
    detect_only,
    dump_ast,
    dump_raw_ast,
    dump_normalized_ast,
    dump_semantic,
  }
}

///|
fn bool_count(values : Array[Bool]) -> Int {
  let mut count = 0
  for value in values {
    if value {
      count = count + 1
    }
  }
  count
}

///|
fn parse_ocr_mode(value : String) -> @ocr.OcrMode raise {
  match value.to_lower().to_string() {
    "off" => @ocr.Off
    "auto" => @ocr.Auto
    "force" => @ocr.Force
    _ => fail("Invalid OCR mode: " + value)
  }
}

///|
fn parse_positive_int(value : String, option_name : String) -> Int raise {
  if value == "" {
    fail("Missing integer value for " + option_name)
  }
  let mut result = 0
  for ch in value {
    if ch < '0' || ch > '9' {
      fail("Invalid integer after " + option_name + ": " + value)
    }
    result = result * 10 + (ch.to_int() - '0'.to_int())
  }
  result
}

///|
async fn main {
  let args = @env.args()

  if args.length() < 2 || args.contains("--help") {
    print_usage()
    return
  }

  let options : CliOptions = parse_args(args) catch {
    err => {
      print_usage()
      println("")
      fail("CLI argument error: " + err.to_string())
    }
  }
  let engine = @engine.MarkItDown::new()

  validate_cli_options(options)
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
  let output = if options.dump_raw_ast {
    render_document_json(result.raw_document)
  } else if options.dump_normalized_ast || options.dump_ast {
    render_ast_json(result)
  } else if options.dump_semantic {
    render_semantic_json(result.semantic_document)
  } else if options.diag_json {
    render_diagnostics_json(result)
  } else {
    result.markdown
  }

  emit_output(output, options.output)

  if options.output is Some(path) &&
    !options.diag_json &&
    !options.dump_ast &&
    !options.dump_raw_ast &&
    !options.dump_normalized_ast &&
    !options.dump_semantic {
    println("Converted: " + options.input + " -> " + path)
    if options.ctx.debug {
      println("")
      println(result.debug_report())
    }
  }
}

///|
fn validate_cli_options(options : CliOptions) -> Unit raise {
  match options.output {
    Some(output_path) => validate_output_path(options.input, output_path)
    None => ()
  }
}

///|
fn validate_output_path(
  input_path : String,
  output_path : String,
) -> Unit raise {
  let normalized_input = normalize_cli_path(input_path)
  let normalized_output = normalize_cli_path(output_path)
  if normalized_input == normalized_output {
    fail("Output path conflicts with input path: " + output_path)
  }
}

///|
fn normalize_cli_path(path : String) -> String {
  path.replace(old="\\", new="/").trim().to_lower().to_string()
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
  render_document_json(result.document)
}

///|
fn render_document_json(document : @ast.Document?) -> String {
  match document {
    Some(value) => json_of_document(value)
    None => "null"
  }
}

///|
fn json_of_document(document : @ast.Document) -> String {
  json_object([
    json_field("title", json_string_or_null(document.title)),
    json_field("metadata", json_of_string_map(document.metadata)),
    json_field("blocks", json_array_of_blocks(document.blocks)),
    json_field("annotations", json_array_of_annotations(document.annotations)),
  ])
}

///|
fn json_array_of_blocks(blocks : Array[@ast.Block]) -> String {
  let items : Array[String] = []
  for block in blocks {
    items.push(json_of_block(block))
  }
  json_array(items)
}

///|
fn json_of_block(block : @ast.Block) -> String {
  match block {
    @ast.Heading(level, inlines) =>
      json_object([
        json_field("type", json_string("heading")),
        json_field("level", level.to_string()),
        json_field("inlines", json_array_of_inlines(inlines)),
      ])
    @ast.Paragraph(inlines) =>
      json_object([
        json_field("type", json_string("paragraph")),
        json_field("inlines", json_array_of_inlines(inlines)),
      ])
    @ast.List(items, ordered) =>
      json_object([
        json_field("type", json_string("list")),
        json_field("ordered", if ordered { "true" } else { "false" }),
        json_field("items", json_array_of_inline_groups(items)),
      ])
    @ast.Quote(lines) =>
      json_object([
        json_field("type", json_string("quote")),
        json_field("lines", json_array_of_strings(lines)),
      ])
    @ast.CodeBlock(lang, content) =>
      json_object([
        json_field("type", json_string("code_block")),
        json_field("lang", json_string_or_null(lang)),
        json_field("content", json_string(content)),
      ])
    @ast.Table(headers, rows) =>
      json_object([
        json_field("type", json_string("table")),
        json_field("headers", json_array_of_inline_groups(headers)),
        json_field("rows", json_array_of_inline_rows(rows)),
      ])
    @ast.Image(alt, url, caption) =>
      json_object([
        json_field("type", json_string("image")),
        json_field("alt", json_string(alt)),
        json_field("url", json_string(url)),
        json_field(
          "caption",
          match caption {
            Some(inlines) => json_array_of_inlines(inlines)
            None => "null"
          },
        ),
      ])
    @ast.HorizontalRule =>
      json_object([json_field("type", json_string("horizontal_rule"))])
  }
}

///|
fn json_array_of_annotations(
  annotations : Array[@ast.BlockAnnotation],
) -> String {
  let items : Array[String] = []
  for annotation in annotations {
    items.push(
      json_object([
        json_field("id", json_string(annotation.id)),
        json_field("source_hint", json_string_or_null(annotation.source_hint)),
        json_field("origin_hint", json_string_or_null(annotation.origin_hint)),
        json_field("diagnostics", json_array_of_strings(annotation.diagnostics)),
      ]),
    )
  }
  json_array(items)
}

///|
fn json_array_of_inline_groups(items : Array[Array[@ast.Inline]]) -> String {
  let groups : Array[String] = []
  for item in items {
    groups.push(json_array_of_inlines(item))
  }
  json_array(groups)
}

///|
fn json_array_of_inline_rows(rows : Array[Array[Array[@ast.Inline]]]) -> String {
  let rendered_rows : Array[String] = []
  for row in rows {
    rendered_rows.push(json_array_of_inline_groups(row))
  }
  json_array(rendered_rows)
}

///|
fn json_array_of_inlines(inlines : Array[@ast.Inline]) -> String {
  let items : Array[String] = []
  for inline in inlines {
    items.push(json_of_inline(inline))
  }
  json_array(items)
}

///|
fn json_of_inline(inline : @ast.Inline) -> String {
  match inline {
    @ast.Text(content) =>
      json_object([
        json_field("type", json_string("text")),
        json_field("content", json_string(content)),
      ])
    @ast.Emphasis(children) =>
      json_object([
        json_field("type", json_string("emphasis")),
        json_field("children", json_array_of_inlines(children)),
      ])
    @ast.Strong(children) =>
      json_object([
        json_field("type", json_string("strong")),
        json_field("children", json_array_of_inlines(children)),
      ])
    @ast.Link(children, url) =>
      json_object([
        json_field("type", json_string("link")),
        json_field("children", json_array_of_inlines(children)),
        json_field("url", json_string(url)),
      ])
    @ast.Image(alt, url) =>
      json_object([
        json_field("type", json_string("image")),
        json_field("alt", json_string(alt)),
        json_field("url", json_string(url)),
      ])
    @ast.Code(content) =>
      json_object([
        json_field("type", json_string("code")),
        json_field("content", json_string(content)),
      ])
    @ast.LineBreak =>
      json_object([json_field("type", json_string("line_break"))])
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
    json_field("has_raw_ast", json_bool(result.raw_document is Some(_))),
    json_field(
      "has_normalized_ast",
      json_bool(result.normalized_document is Some(_)),
    ),
    json_field("has_semantic", json_bool(result.semantic_document is Some(_))),
  ]
  json_object(fields)
}

///|
fn render_semantic_json(document : @semantic.SemanticDocument?) -> String {
  match document {
    Some(value) => json_of_semantic_document(value)
    None => "null"
  }
}

///|
fn json_of_semantic_document(document : @semantic.SemanticDocument) -> String {
  json_object([
    json_field("title", json_string_or_null(document.title)),
    json_field("provenance", json_of_provenance(document.provenance)),
    json_field("sections", json_array_of_sections(document.sections)),
    json_field("blocks", json_array_of_semantic_blocks(document.blocks)),
  ])
}

///|
fn json_array_of_sections(sections : Array[@semantic.Section]) -> String {
  let items : Array[String] = []
  for section in sections {
    items.push(json_of_section(section))
  }
  json_array(items)
}

///|
fn json_of_section(section : @semantic.Section) -> String {
  json_object([
    json_field("id", json_string(section.id)),
    json_field("title", json_string_or_null(section.title)),
    json_field("level", section.level.to_string()),
    json_field("role", json_string(section.role.to_string())),
    json_field("block_indices", json_array_of_ints(section.block_indices)),
    json_field("diagnostics", json_array_of_strings(section.diagnostics)),
    json_field("provenance", json_of_provenance(section.provenance)),
    json_field("children", json_array_of_sections(section.children)),
  ])
}

///|
fn json_array_of_semantic_blocks(
  blocks : Array[@semantic.SemanticBlock],
) -> String {
  let items : Array[String] = []
  for block in blocks {
    items.push(
      json_object([
        json_field("block_id", json_string(block.block_id)),
        json_field("index", block.index.to_string()),
        json_field("role", json_string(block.role.to_string())),
        json_field("text", json_string(block.text)),
        json_field("source_hint", json_string_or_null(block.source_hint)),
        json_field("origin_hint", json_string_or_null(block.origin_hint)),
        json_field("diagnostics", json_array_of_strings(block.diagnostics)),
        json_field("confidence", block.confidence.to_string()),
        json_field("provenance", json_of_provenance(block.provenance)),
      ]),
    )
  }
  json_array(items)
}

///|
fn json_of_provenance(provenance : @semantic.Provenance) -> String {
  json_object([
    json_field("source_path", json_string_or_null(provenance.source_path)),
    json_field("source_url", json_string_or_null(provenance.source_url)),
    json_field(
      "page_no",
      match provenance.page_no {
        Some(value) => value.to_string()
        None => "null"
      },
    ),
    json_field(
      "slide_no",
      match provenance.slide_no {
        Some(value) => value.to_string()
        None => "null"
      },
    ),
    json_field("sheet_name", json_string_or_null(provenance.sheet_name)),
    json_field("chapter", json_string_or_null(provenance.chapter)),
    json_field("resource", json_string_or_null(provenance.resource)),
  ])
}

///|
fn json_array_of_ints(values : Array[Int]) -> String {
  let items : Array[String] = []
  for value in values {
    items.push(value.to_string())
  }
  json_array(items)
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
fn json_bool(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
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
  let mut escaped = ""
  for ch in value {
    let piece = match ch {
      '\\' => "\\\\"
      '"' => "\\\""
      '\n' => "\\n"
      '\r' => "\\r"
      '\t' => "\\t"
      '\u{0008}' => "\\b"
      '\u{000C}' => "\\f"
      _ => ch.to_string()
    }
    escaped = escaped + piece
  }
  "\"" + escaped + "\""
}
