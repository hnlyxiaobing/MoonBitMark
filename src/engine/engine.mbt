// MoonBitMark - Main Conversion Engine

///|
pub(all) enum ConverterKind {
  Docx
  Epub
  Pptx
  Xlsx
  Pdf
  Html
  Json
  Csv
  Text
}

///|
pub(all) struct ConverterRegistration {
  kind : ConverterKind
  name : String
  priority : Int
}

///|
pub(all) struct MarkItDown {
  converters : Array[ConverterRegistration]
}

///|
pub fn MarkItDown::new() -> MarkItDown {
  register_default_converters(MarkItDown::{ converters: [] })
}

///|
pub fn MarkItDown::register(
  self : MarkItDown,
  converter : ConverterRegistration,
) -> MarkItDown {
  let converters = self.converters
  converters.push(converter)
  MarkItDown::{ converters, }
}

///|
pub fn MarkItDown::register_named(
  self : MarkItDown,
  kind : ConverterKind,
  priority : Int,
) -> MarkItDown {
  self.register(default_registration(kind, priority))
}

///|
pub fn MarkItDown::detect_converter_name(
  self : MarkItDown,
  input : String,
) -> String raise {
  let info = stream_info_of_input(@core.InputSource::from_string(input))
  self.select_converter(info).name
}

///|
pub async fn MarkItDown::convert(
  self : MarkItDown,
  input : String,
  ctx? : @core.ConvertContext = @core.ConvertContext::default(),
) -> @core.ConvertResult {
  self.convert_source(@core.InputSource::from_string(input), ctx~)
}

///|
pub async fn MarkItDown::convert_source(
  self : MarkItDown,
  input : @core.InputSource,
  ctx? : @core.ConvertContext = @core.ConvertContext::default(),
) -> @core.ConvertResult {
  let info = stream_info_of_input(input)
  let converter = self.select_converter(info) catch {
    err =>
      fail(
        format_engine_error(
          category="FormatDetectionError",
          phase="detect/select",
          source=describe_input(input),
          message=err.to_string(),
          hint=Some("Check the file extension, URL, or MIME information."),
        ),
      )
  }

  let raw_result = run_converter(converter, input) catch {
    err =>
      fail(
        format_engine_error(
          category="ConversionFailed",
          phase=converter.name,
          source=describe_input(input),
          message=err.to_string(),
          hint=Some("Inspect the source document or run with debug context."),
        ),
      )
  }

  finalize_result(raw_result, converter, input, info, ctx)
}

///|
pub fn MarkItDown::select_converter(
  self : MarkItDown,
  info : @core.StreamInfo,
) -> ConverterRegistration raise {
  let mut selected : ConverterRegistration? = None
  for converter in self.converters {
    if accepts_converter(converter, info) {
      match selected {
        Some(current) =>
          if converter.priority > current.priority {
            selected = Some(converter)
          }
        None => selected = Some(converter)
      }
    }
  }

  match selected {
    Some(converter) => converter
    None => fail("Unsupported input: " + describe_stream_info(info))
  }
}

///|
fn stream_info_of_input(input : @core.InputSource) -> @core.StreamInfo {
  match input {
    @core.FileInput(path, _) =>
      @core.StreamInfo::{
        mimetype: None,
        extension: file_extension(path),
        filename: file_name(path),
        url: None,
        charset: None,
      }
    @core.UrlInput(url, _) =>
      @core.StreamInfo::{
        mimetype: Some("text/html"),
        extension: file_extension(url),
        filename: file_name(url),
        url: Some(url),
        charset: None,
      }
    @core.BytesInput(name, _, mimetype) =>
      @core.StreamInfo::{
        mimetype,
        extension: option_extension(name),
        filename: name,
        url: None,
        charset: None,
      }
  }
}

///|
fn describe_stream_info(info : @core.StreamInfo) -> String {
  match info.url {
    Some(url) => url
    None =>
      match info.filename {
        Some(filename) => filename
        None =>
          match info.extension {
            Some(extension) => extension
            None => "<unknown>"
          }
      }
  }
}

///|
fn describe_input(input : @core.InputSource) -> String {
  match input.name() {
    Some(name) => name
    None => "<unknown input>"
  }
}

///|
fn option_extension(name : String?) -> String? {
  match name {
    Some(value) => file_extension(value)
    None => None
  }
}

///|
fn file_name(path : String) -> String? {
  let normalized = path.replace(old="\\", new="/")
  match find_last_char(normalized, '/') {
    Some(index) =>
      if index + 1 < normalized.length() {
        Some(normalized[index + 1:].to_string())
      } else {
        None
      }
    None => if normalized.length() > 0 { Some(normalized) } else { None }
  }
}

///|
fn file_extension(path : String) -> String? {
  let normalized = path.replace(old="\\", new="/")
  let basename = match find_last_char(normalized, '/') {
    Some(index) => normalized[index + 1:].to_string()
    None => normalized
  }
  match find_last_char(basename, '.') {
    Some(index) => Some(basename[index:].to_lower().to_string())
    None => None
  }
}

///|
fn find_last_char(s : String, target : Char) -> Int? {
  let mut found = -1
  let mut i = 0
  for ch in s {
    if ch == target {
      found = i
    }
    i = i + 1
  }
  if found >= 0 {
    Some(found)
  } else {
    None
  }
}

///|
fn accepts_converter(
  converter : ConverterRegistration,
  info : @core.StreamInfo,
) -> Bool {
  match converter.kind {
    Docx => @docx.DocxConverter::accepts(info)
    Epub => @epub.EpubConverter::accepts(info)
    Pptx => @pptx.PptxConverter::accepts(info)
    Xlsx => @xlsx.XlsxConverter::accepts(info)
    Pdf => @pdf.PdfConverter::accepts(info)
    Html => @html.HtmlConverter::accepts(info)
    Json => @json.JsonConverter::accepts(info)
    Csv => @csv.CsvConverter::accepts(info)
    Text => @text.TextConverter::accepts(info)
  }
}

///|
async fn run_converter(
  converter : ConverterRegistration,
  input : @core.InputSource,
) -> @core.ConvertResult {
  let input_name = match input {
    @core.FileInput(path, _) => path
    @core.UrlInput(url, _) => url
    @core.BytesInput(name, _, _) =>
      match name {
        Some(value) => value
        None => fail("Bytes input is not supported without a source name")
      }
  }

  match converter.kind {
    Docx => @docx.DocxConverter::convert(input_name)
    Epub => @epub.EpubConverter::convert(input_name)
    Pptx => @pptx.PptxConverter::convert(input_name)
    Xlsx => @xlsx.XlsxConverter::convert(input_name)
    Pdf => @pdf.PdfConverter::convert(input_name)
    Html => @html.HtmlConverter::convert(input_name)
    Json => @json.JsonConverter::convert(input_name)
    Csv => @csv.CsvConverter::convert(input_name)
    Text => @text.TextConverter::convert(input_name)
  }
}

///|
fn finalize_result(
  raw_result : @core.ConvertResult,
  converter : ConverterRegistration,
  input : @core.InputSource,
  info : @core.StreamInfo,
  ctx : @core.ConvertContext,
) -> @core.ConvertResult {
  let metadata = if ctx.keep_metadata {
    enrich_metadata(raw_result.metadata, converter, input, info)
  } else {
    Map::new()
  }
  let diagnostics = merge_diagnostics(raw_result, converter, input)
  let rendered_markdown = render_output_mode(
    raw_result.markdown,
    raw_result.title,
    metadata,
    ctx.output_mode,
  )
  let stats = match raw_result.stats {
    Some(existing) => Some(existing)
    None => Some(@core.stats_for_markdown(rendered_markdown))
  }

  @core.ConvertResult::{
    markdown: rendered_markdown,
    title: raw_result.title,
    metadata,
    warnings: raw_result.warnings,
    diagnostics,
    source_type: raw_result.source_type,
    stats,
  }
}

///|
fn enrich_metadata(
  original : Map[String, String],
  converter : ConverterRegistration,
  input : @core.InputSource,
  info : @core.StreamInfo,
) -> Map[String, String] {
  let metadata = Map::new()
  for key, value in original {
    metadata[key] = value
  }
  metadata["converter"] = converter.name
  metadata["source_kind"] = input.kind()
  metadata["source_type"] = converter.name

  match input.name() {
    Some(name) => metadata["source_name"] = name
    None => ()
  }
  match info.extension {
    Some(extension) => metadata["extension"] = extension
    None => ()
  }
  match info.mimetype {
    Some(mimetype) => metadata["mimetype"] = mimetype
    None => ()
  }
  match info.url {
    Some(url) => metadata["url"] = url
    None => ()
  }

  metadata
}

///|
fn merge_diagnostics(
  raw_result : @core.ConvertResult,
  converter : ConverterRegistration,
  input : @core.InputSource,
) -> Array[@core.ConversionDiagnostic] {
  let diagnostics : Array[@core.ConversionDiagnostic] = []
  for diagnostic in raw_result.diagnostics {
    diagnostics.push(diagnostic)
  }
  for
    diagnostic in @core.diagnostics_from_warnings(
      raw_result.warnings,
      Some(converter.name),
      input.name(),
    ) {
    diagnostics.push(diagnostic)
  }
  diagnostics
}

///|
fn render_output_mode(
  markdown : String,
  title : String?,
  metadata : Map[String, String],
  mode : @core.OutputMode,
) -> String {
  match mode {
    @core.PlainText => markdown
    @core.StandardMarkdown => markdown
    @core.FrontMatterMarkdown => add_frontmatter(markdown, title, metadata)
  }
}

///|
fn add_frontmatter(
  markdown : String,
  title : String?,
  metadata : Map[String, String],
) -> String {
  let lines : Array[String] = ["---"]
  match title {
    Some(value) => lines.push("title: " + escape_frontmatter(value))
    None => ()
  }
  for key, value in metadata {
    if key != "title" {
      lines.push(key + ": " + escape_frontmatter(value))
    }
  }
  lines.push("---")
  lines.push("")
  lines.push(markdown)
  lines.join("\n")
}

///|
fn escape_frontmatter(value : String) -> String {
  "\"" + value.replace(old="\"", new="\\\"") + "\""
}

///|
fn format_engine_error(
  category~ : String,
  phase~ : String,
  source~ : String,
  message~ : String,
  hint~ : String?,
) -> String {
  let mut result = "Error: " + category + "\n"
  result = result + "  Phase: " + phase + "\n"
  result = result + "  Source: " + source + "\n"
  result = result + "  Message: " + message
  match hint {
    Some(value) => result = result + "\n  Hint: " + value
    None => ()
  }
  result
}

///|
fn register_default_converters(engine : MarkItDown) -> MarkItDown {
  engine
  .register_named(Docx, 100)
  .register_named(Epub, 95)
  .register_named(Pptx, 90)
  .register_named(Xlsx, 85)
  .register_named(Pdf, 80)
  .register_named(Html, 70)
  .register_named(Json, 50)
  .register_named(Csv, 40)
  .register_named(Text, 10)
}

///|
fn default_registration(
  kind : ConverterKind,
  priority : Int,
) -> ConverterRegistration {
  ConverterRegistration::{ kind, name: converter_name(kind), priority }
}

///|
fn converter_name(kind : ConverterKind) -> String {
  match kind {
    Docx => "docx"
    Epub => "epub"
    Pptx => "pptx"
    Xlsx => "xlsx"
    Pdf => "pdf"
    Html => "html"
    Json => "json"
    Csv => "csv"
    Text => "text"
  }
}
