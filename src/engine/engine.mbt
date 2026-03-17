// MoonBitMark - Main Conversion Engine

///|
pub(all) struct ConverterRegistration {
  name : String
  priority : Int
}

///|
pub(all) struct MarkItDown {
  converters : Array[ConverterRegistration]
}

///|
pub fn MarkItDown::new() -> MarkItDown {
  let engine = MarkItDown::{ converters: [] }
  engine
  .register("docx", 100)
  .register("epub", 95)
  .register("pptx", 90)
  .register("xlsx", 85)
  .register("pdf", 80)
  .register("html", 70)
  .register("json", 50)
  .register("csv", 40)
  .register("text", 10)
}

///|
pub fn MarkItDown::register(
  self : MarkItDown,
  name : String,
  priority : Int,
) -> MarkItDown {
  let converters = self.converters
  converters.push({ name, priority })
  MarkItDown::{ converters, }
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

  let raw_result = run_converter(converter.name, input) catch {
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
    if accepts_converter(converter.name, info) {
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
fn accepts_converter(name : String, info : @core.StreamInfo) -> Bool {
  match name {
    "docx" => @docx.DocxConverter::accepts(info)
    "epub" => @epub.EpubConverter::accepts(info)
    "pptx" => @pptx.PptxConverter::accepts(info)
    "xlsx" => @xlsx.XlsxConverter::accepts(info)
    "pdf" => @pdf.PdfConverter::accepts(info)
    "html" => @html.HtmlConverter::accepts(info)
    "json" => @json.JsonConverter::accepts(info)
    "csv" => @csv.CsvConverter::accepts(info)
    "text" => @text.TextConverter::accepts(info)
    _ => false
  }
}

///|
async fn run_converter(
  name : String,
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

  match name {
    "docx" => @docx.DocxConverter::convert(input_name)
    "epub" => @epub.EpubConverter::convert(input_name)
    "pptx" => @pptx.PptxConverter::convert(input_name)
    "xlsx" => @xlsx.XlsxConverter::convert(input_name)
    "pdf" => @pdf.PdfConverter::convert(input_name)
    "html" => @html.HtmlConverter::convert(input_name)
    "json" => @json.JsonConverter::convert(input_name)
    "csv" => @csv.CsvConverter::convert(input_name)
    "text" => @text.TextConverter::convert(input_name)
    _ => fail("Unknown converter: " + name)
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
