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
  let input_source = diagnostic_source_of_input(input)
  let converter = self.select_converter(info) catch {
    err =>
      fail(
        render_engine_failure(
          @core.FormatDetectionError(err.to_string()),
          Some(@core.Detect(Some("select"))),
          Some(input_source),
          Some(@core.CheckInputDetection),
        ),
      )
  }

  let raw_result = run_converter(converter, input) catch {
    err =>
      if is_rendered_diagnostic(err.to_string()) {
        fail(err.to_string())
      } else {
        fail(
          render_engine_failure(
            @core.ConversionFailed(err.to_string(), converter.name),
            Some(@core.Convert(converter.name)),
            Some(input_source),
            Some(fallback_hint_for_converter(converter)),
          ),
        )
      }
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
fn diagnostic_source_of_input(
  input : @core.InputSource,
) -> @core.DiagnosticSource {
  match input {
    @core.FileInput(path, _) => @core.File(path)
    @core.UrlInput(url, _) => @core.Url(url)
    @core.BytesInput(name, _, _) => @core.Bytes(name)
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
        None =>
          fail(
            render_engine_failure(
              @core.InputError(
                "Bytes input is not supported without a source name",
                None,
              ),
              Some(@core.Load(Some("resolve-input"))),
              Some(@core.Bytes(None)),
              Some(@core.ProvideBytesSourceName),
            ),
          )
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
async fn finalize_result(
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
  let (asset_markdown, asset_warnings, asset_diagnostics, asset_count) = match
    ctx.asset_output_dir {
    Some(dir) => materialize_data_uri_assets(rendered_markdown, dir)
    None => (rendered_markdown, [], [], 0)
  }
  let warnings : Array[String] = []
  for warning in raw_result.warnings {
    warnings.push(warning)
  }
  for warning in asset_warnings {
    warnings.push(warning)
  }
  if asset_count > 0 {
    metadata["asset_count"] = asset_count.to_string()
    match ctx.asset_output_dir {
      Some(dir) => metadata["asset_output_dir"] = normalize_asset_path(dir)
      None => ()
    }
  }
  let diagnostics = merge_diagnostics(
    raw_result.diagnostics,
    raw_result.warnings,
    converter,
    input,
  )
  for diagnostic in asset_diagnostics {
    diagnostics.push(diagnostic)
  }
  let stats = match raw_result.stats {
    Some(existing) => Some(existing)
    None => Some(@core.stats_for_markdown(asset_markdown))
  }

  @core.ConvertResult::{
    markdown: asset_markdown,
    title: raw_result.title,
    metadata,
    warnings,
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
  raw_diagnostics : Array[@core.ConversionDiagnostic],
  warnings : Array[String],
  converter : ConverterRegistration,
  input : @core.InputSource,
) -> Array[@core.ConversionDiagnostic] {
  let diagnostics : Array[@core.ConversionDiagnostic] = []
  let fallback_phase = Some(@core.Convert(converter.name))
  let fallback_source = Some(diagnostic_source_of_input(input))
  let fallback_hint = fallback_hint_for_converter(converter)
  for diagnostic in raw_diagnostics {
    diagnostics.push(
      diagnostic.with_defaults(
        fallback_phase,
        fallback_source,
        Some(fallback_hint),
      ),
    )
  }
  for
    diagnostic in @core.diagnostics_from_warnings(
      warnings,
      fallback_phase,
      fallback_source,
      hint=fallback_hint,
    ) {
    diagnostics.push(diagnostic)
  }
  diagnostics
}

///|
fn fallback_hint_for_converter(
  converter : ConverterRegistration,
) -> @core.DiagnosticHint {
  match converter.kind {
    Docx => @core.CheckArchiveIntegrity
    Epub => @core.CheckArchiveIntegrity
    Pptx => @core.CheckArchiveIntegrity
    Xlsx => @core.CheckArchiveIntegrity
    Pdf => @core.InspectSourceDocument
    Html => @core.InspectSourceDocument
    Json => @core.InspectSourceDocument
    Csv => @core.InspectSourceDocument
    Text => @core.InspectSourceDocument
  }
}

///|
fn render_engine_failure(
  error : @core.ConversionError,
  phase : @core.ConversionPhase?,
  source : @core.DiagnosticSource?,
  hint : @core.DiagnosticHint?,
) -> String {
  @core.error_diagnostic(error, phase, source, hint).render()
}

///|
fn is_rendered_diagnostic(message : String) -> Bool {
  message.has_prefix("Error: ") && message.contains("\n  Message: ")
}

///|
async fn materialize_data_uri_assets(
  markdown : String,
  asset_output_dir : String,
) -> (String, Array[String], Array[@core.ConversionDiagnostic], Int) {
  let mut rewritten = markdown
  let warnings : Array[String] = []
  let diagnostics : Array[@core.ConversionDiagnostic] = []
  let normalized_dir = normalize_asset_path(asset_output_dir)
  let mut cursor = 0
  let mut asset_index = 1
  let mut asset_count = 0

  while true {
    match find_substring(rewritten, "data:image/", cursor) {
      Some(start) => {
        let end = match find_data_uri_end(rewritten, start) {
          Some(value) => value
          None => break
        }
        let uri = rewritten[start:end].to_string()
        match decode_data_uri_asset(uri, asset_index) {
          Some((filename, bytes)) => {
            let relative_path = normalized_dir + "/" + filename
            let disk_path = join_asset_path(asset_output_dir, filename)
            ensure_directory_chain(asset_output_dir)
            let write_result = write_asset_file(disk_path, bytes) catch {
              err => {
                let message = "Failed to write asset file: " + relative_path
                warnings.push(message)
                diagnostics.push(
                  @core.warning_diagnostic(
                    message,
                    Some(@core.Postprocess(Some("assets"))),
                    Some(@core.Generated(relative_path)),
                    Some(@core.Custom(err.to_string())),
                  ),
                )
                false
              }
            }
            if write_result {
              rewritten = rewritten[:start].to_string() +
                relative_path +
                rewritten[end:].to_string()
              asset_count = asset_count + 1
              asset_index = asset_index + 1
              cursor = start + relative_path.length()
            } else {
              cursor = end
            }
          }
          None => {
            let message = "Failed to decode embedded data URI image asset."
            warnings.push(message)
            diagnostics.push(
              @core.warning_diagnostic(
                message,
                Some(@core.Postprocess(Some("assets"))),
                Some(@core.Generated("data-uri-image")),
                Some(
                  @core.Custom(
                    "Verify the data URI uses a supported image media type and valid base64 payload.",
                  ),
                ),
              ),
            )
            cursor = end
          }
        }
      }
      None => break
    }
  }

  (rewritten, warnings, diagnostics, asset_count)
}

///|
async fn write_asset_file(path : String, bytes : Bytes) -> Bool {
  let file = @fs.open(path, mode=WriteOnly, create=0o644, truncate=true)
  file.write(bytes)
  file.close()
  true
}

///|
async fn ensure_directory_chain(path : String) -> Unit {
  let normalized = normalize_asset_path(path)
  let mut current = directory_prefix(normalized)
  for segment in split_path_segments(normalized) {
    current = join_segment(current, segment)
    ignore(
      @fs.mkdir(current, permission=0o755, recursive=true) catch {
        _ => ()
      },
    )
  }
}

///|
fn decode_data_uri_asset(uri : String, index : Int) -> (String, Bytes)? {
  if !uri.has_prefix("data:image/") {
    return None
  }
  let comma = match find_substring(uri, ",", 0) {
    Some(value) => value
    None => return None
  }
  let header = uri[5:comma].to_string()
  if !header.contains(";base64") {
    return None
  }
  let media_type = match header.split(";").next() {
    Some(value) => value.to_string()
    None => return None
  }
  let payload = uri[comma + 1:].to_string()
  let bytes = @base64.decode(payload, ignore_whitespace=true) catch {
    _ => return None
  }
  let filename = "image-" +
    index.to_string() +
    "." +
    image_extension(media_type)
  Some((filename, bytes))
}

///|
fn image_extension(media_type : String) -> String {
  match media_type {
    "image/png" => "png"
    "image/jpeg" => "jpg"
    "image/jpg" => "jpg"
    "image/gif" => "gif"
    "image/webp" => "webp"
    "image/svg+xml" => "svg"
    "image/x-icon" => "ico"
    _ => "bin"
  }
}

///|
fn find_data_uri_end(text : String, start : Int) -> Int? {
  let mut i = start
  while i < text.length() {
    let ch = text[i]
    if ch == ')' ||
      ch == ' ' ||
      ch == '"' ||
      ch == '\n' ||
      ch == '\r' ||
      ch == '\t' {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn find_substring(text : String, needle : String, start : Int) -> Int? {
  if start >= text.length() {
    None
  } else {
    let tail = text[start:].to_string()
    match tail.find(needle[:]) {
      Some(pos) => Some(start + pos)
      None => None
    }
  }
}

///|
fn normalize_asset_path(path : String) -> String {
  path.replace(old="\\", new="/")
}

///|
fn join_asset_path(dir : String, name : String) -> String {
  let normalized = normalize_asset_path(dir)
  if normalized == "" {
    name
  } else if normalized.has_suffix("/") {
    normalized + name
  } else {
    normalized + "/" + name
  }
}

///|
fn directory_prefix(path : String) -> String {
  if path.length() >= 2 && path[1] == ':' {
    path[0:2].to_string()
  } else if path.has_prefix("/") {
    "/"
  } else {
    ""
  }
}

///|
fn split_path_segments(path : String) -> Array[String] {
  let normalized = normalize_asset_path(path)
  let segments : Array[String] = []
  let mut current = ""
  let mut start = 0
  if normalized.length() >= 2 && normalized[1] == ':' {
    start = 2
  } else if normalized.has_prefix("/") {
    start = 1
  }
  let mut i = start
  while i < normalized.length() {
    let ch = normalized[i]
    if ch == '/' {
      if current != "" {
        segments.push(current)
        current = ""
      }
    } else {
      current = current + normalized[i:i + 1].to_string()
    }
    i = i + 1
  }
  if current != "" {
    segments.push(current)
  }
  segments
}

///|
fn join_segment(current : String, segment : String) -> String {
  if current == "" || current == "/" {
    current + segment
  } else {
    current + "/" + segment
  }
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
