// MoonBitMark - Main Conversion Engine

///|
pub(all) enum ConverterKind {
  Docx
  Epub
  Pptx
  Xlsx
  Pdf
  Image
  Html
  Json
  Csv
  Text
}

///|
pub(all) struct ConverterRegistration {
  name : String
  priority : Int
  hint : @core.DiagnosticHint
  accepts : (@core.StreamInfo) -> Bool
  convert : async (@core.InputSource, @core.ConvertContext) -> @core.ConvertResult
}

///|
pub(all) struct DetectionResult {
  converter_name : String
  stream_info : @core.StreamInfo
} derive(Show, Eq, ToJson)

///|
pub fn DetectionResult::render(self : DetectionResult) -> String {
  let lines : Array[String] = ["converter: " + self.converter_name]
  match self.stream_info.extension {
    Some(value) => lines.push("extension: " + value)
    None => ()
  }
  match self.stream_info.mimetype {
    Some(value) => lines.push("mimetype: " + value)
    None => ()
  }
  match self.stream_info.filename {
    Some(value) => lines.push("filename: " + value)
    None => ()
  }
  match self.stream_info.url {
    Some(value) => lines.push("url: " + value)
    None => ()
  }
  lines.join("\n")
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
pub async fn MarkItDown::detect(
  self : MarkItDown,
  input : String,
) -> DetectionResult {
  self.detect_source(@core.InputSource::from_string(input))
}

///|
pub async fn MarkItDown::detect_source(
  self : MarkItDown,
  input : @core.InputSource,
) -> DetectionResult {
  let info = detect_stream_info(input)
  let converter = self.select_converter(info)
  DetectionResult::{ converter_name: converter.name, stream_info: info }
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
  let info = detect_stream_info(input)
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

  let raw_result = (converter.convert)(input, ctx) catch {
    err =>
      if is_rendered_diagnostic(err.to_string()) {
        fail(err.to_string())
      } else {
        fail(
          render_engine_failure(
            @core.ConversionFailed(err.to_string(), converter.name),
            Some(@core.Convert(converter.name)),
            Some(input_source),
            Some(converter.hint),
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
    if (converter.accepts)(info) {
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
  let markdown_with_assets = materialize_output_assets(
    raw_result.markdown,
    raw_result.assets,
  )
  let rendered_markdown = render_output_mode(
    markdown_with_assets,
    raw_result.title,
    metadata,
    ctx.output_mode,
  )
  let (
    embedded_markdown,
    embedded_warnings,
    embedded_diagnostics,
    embedded_count,
  ) = match ctx.asset_output_dir {
    Some(dir) =>
      materialize_embedded_assets(rendered_markdown, raw_result.assets, dir)
    None => (rendered_markdown, [], [], 0)
  }
  let (asset_markdown, asset_warnings, asset_diagnostics, data_uri_asset_count) = match
    ctx.asset_output_dir {
    Some(dir) => materialize_data_uri_assets(embedded_markdown, dir)
    None => (embedded_markdown, [], [], 0)
  }
  let warnings : Array[String] = []
  for warning in raw_result.warnings {
    warnings.push(warning)
  }
  for warning in embedded_warnings {
    warnings.push(warning)
  }
  for warning in asset_warnings {
    warnings.push(warning)
  }
  let asset_count = embedded_count + data_uri_asset_count
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
  for diagnostic in embedded_diagnostics {
    diagnostics.push(diagnostic)
  }
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
    assets: raw_result.assets,
    source_type: raw_result.source_type,
    stats,
    document: raw_result.document,
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
  let fallback_hint = converter.hint
  for diagnostic in raw_diagnostics {
    let normalized = diagnostic.with_defaults(
      fallback_phase,
      fallback_source,
      Some(fallback_hint),
    )
    push_unique_diagnostic(diagnostics, normalized)
  }
  for
    diagnostic in @core.diagnostics_from_warnings(
      warnings,
      fallback_phase,
      fallback_source,
      hint=fallback_hint,
    ) {
    push_unique_diagnostic(diagnostics, diagnostic)
  }
  diagnostics
}

///|
fn push_unique_diagnostic(
  diagnostics : Array[@core.ConversionDiagnostic],
  diagnostic : @core.ConversionDiagnostic,
) -> Unit {
  for existing in diagnostics {
    if existing.level == diagnostic.level &&
      existing.message == diagnostic.message {
      return
    }
  }
  diagnostics.push(diagnostic)
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
fn materialize_output_assets(
  markdown : String,
  assets : Array[@core.OutputAsset],
) -> String {
  let mut rewritten = markdown
  for asset in assets {
    rewritten = rewritten.replace(
      old=asset.placeholder,
      new="moonbitmark-asset://" + asset.filename,
    )
  }
  rewritten
}

///|
async fn materialize_embedded_assets(
  markdown : String,
  assets : Array[@core.OutputAsset],
  asset_output_dir : String,
) -> (String, Array[String], Array[@core.ConversionDiagnostic], Int) {
  let mut rewritten = markdown
  let warnings : Array[String] = []
  let diagnostics : Array[@core.ConversionDiagnostic] = []
  let normalized_dir = normalize_asset_path(asset_output_dir)
  let mut asset_count = 0
  ensure_directory_chain(asset_output_dir)
  for asset in assets {
    let relative_path = normalized_dir + "/" + asset.filename
    let disk_path = join_asset_path(asset_output_dir, asset.filename)
    let write_result = write_asset_file(disk_path, asset.bytes) catch {
      err => {
        let message = "Failed to write asset file: " + relative_path
        warnings.push(message)
        diagnostics.push(
          @core.warning_diagnostic(
            message,
            Some(@core.Postprocess(Some("assets"))),
            asset.source,
            Some(
              match asset.hint {
                Some(hint) => hint
                None => @core.Custom(err.to_string())
              },
            ),
          ),
        )
        false
      }
    }
    if write_result {
      rewritten = rewritten.replace(old=asset.placeholder, new=relative_path)
      asset_count = asset_count + 1
    }
  }
  (rewritten, warnings, diagnostics, asset_count)
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
  .register_named(Image, 75)
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
  match kind {
    Docx =>
      ConverterRegistration::{
        name: "docx",
        priority,
        hint: @core.CheckArchiveIntegrity,
        accepts: accepts_docx,
        convert: convert_docx,
      }
    Epub =>
      ConverterRegistration::{
        name: "epub",
        priority,
        hint: @core.CheckArchiveIntegrity,
        accepts: accepts_epub,
        convert: convert_epub,
      }
    Pptx =>
      ConverterRegistration::{
        name: "pptx",
        priority,
        hint: @core.CheckArchiveIntegrity,
        accepts: accepts_pptx,
        convert: convert_pptx,
      }
    Xlsx =>
      ConverterRegistration::{
        name: "xlsx",
        priority,
        hint: @core.CheckArchiveIntegrity,
        accepts: accepts_xlsx,
        convert: convert_xlsx,
      }
    Pdf =>
      ConverterRegistration::{
        name: "pdf",
        priority,
        hint: @core.InspectSourceDocument,
        accepts: accepts_pdf,
        convert: convert_pdf,
      }
    Image =>
      ConverterRegistration::{
        name: "image",
        priority,
        hint: @core.InspectSourceDocument,
        accepts: accepts_image,
        convert: convert_image,
      }
    Html =>
      ConverterRegistration::{
        name: "html",
        priority,
        hint: @core.InspectSourceDocument,
        accepts: accepts_html,
        convert: convert_html,
      }
    Json =>
      ConverterRegistration::{
        name: "json",
        priority,
        hint: @core.InspectSourceDocument,
        accepts: accepts_json,
        convert: convert_json,
      }
    Csv =>
      ConverterRegistration::{
        name: "csv",
        priority,
        hint: @core.InspectSourceDocument,
        accepts: accepts_csv,
        convert: convert_csv,
      }
    Text =>
      ConverterRegistration::{
        name: "text",
        priority,
        hint: @core.InspectSourceDocument,
        accepts: accepts_text,
        convert: convert_text,
      }
  }
}

///|
fn accepts_docx(info : @core.StreamInfo) -> Bool {
  @docx.DocxConverter::accepts(info)
}

///|
fn accepts_epub(info : @core.StreamInfo) -> Bool {
  @epub.EpubConverter::accepts(info)
}

///|
fn accepts_pptx(info : @core.StreamInfo) -> Bool {
  @pptx.PptxConverter::accepts(info)
}

///|
fn accepts_xlsx(info : @core.StreamInfo) -> Bool {
  @xlsx.XlsxConverter::accepts(info)
}

///|
fn accepts_pdf(info : @core.StreamInfo) -> Bool {
  @pdf.PdfConverter::accepts(info)
}

///|
fn accepts_image(info : @core.StreamInfo) -> Bool {
  @image.ImageConverter::accepts(info)
}

///|
fn accepts_html(info : @core.StreamInfo) -> Bool {
  @html.HtmlConverter::accepts(info)
}

///|
fn accepts_json(info : @core.StreamInfo) -> Bool {
  @json.JsonConverter::accepts(info)
}

///|
fn accepts_csv(info : @core.StreamInfo) -> Bool {
  @csv.CsvConverter::accepts(info)
}

///|
fn accepts_text(info : @core.StreamInfo) -> Bool {
  @text.TextConverter::accepts(info)
}

///|
async fn convert_docx(
  input : @core.InputSource,
  ctx : @core.ConvertContext,
) -> @core.ConvertResult {
  convert_with_materialized_path(input, "docx", @core.CheckArchiveIntegrity, path => {
    @docx.DocxConverter::convert(path, ctx~)
  })
}

///|
async fn convert_epub(
  input : @core.InputSource,
  ctx : @core.ConvertContext,
) -> @core.ConvertResult {
  convert_with_materialized_path(input, "epub", @core.CheckArchiveIntegrity, path => {
    @epub.EpubConverter::convert(path, ctx~)
  })
}

///|
async fn convert_pptx(
  input : @core.InputSource,
  ctx : @core.ConvertContext,
) -> @core.ConvertResult {
  convert_with_materialized_path(input, "pptx", @core.CheckArchiveIntegrity, path => {
    @pptx.PptxConverter::convert(path, ctx~)
  })
}

///|
async fn convert_xlsx(
  input : @core.InputSource,
  ctx : @core.ConvertContext,
) -> @core.ConvertResult {
  convert_with_materialized_path(input, "xlsx", @core.CheckArchiveIntegrity, path => {
    @xlsx.XlsxConverter::convert(path, ctx~)
  })
}

///|
async fn convert_pdf(
  input : @core.InputSource,
  ctx : @core.ConvertContext,
) -> @core.ConvertResult {
  convert_with_materialized_path(input, "pdf", @core.InspectSourceDocument, path => {
    @pdf.PdfConverter::convert(path, ctx~)
  })
}

///|
async fn convert_image(
  input : @core.InputSource,
  ctx : @core.ConvertContext,
) -> @core.ConvertResult {
  convert_with_materialized_path(input, "image", @core.InspectSourceDocument, path => {
    @image.ImageConverter::convert(path, ctx~)
  })
}

///|
async fn convert_html(
  input : @core.InputSource,
  ctx : @core.ConvertContext,
) -> @core.ConvertResult {
  convert_with_materialized_path(input, "html", @core.InspectSourceDocument, path => {
    @html.HtmlConverter::convert(path, ctx~)
  })
}

///|
async fn convert_json(
  input : @core.InputSource,
  ctx : @core.ConvertContext,
) -> @core.ConvertResult {
  @json.JsonConverter::convert_source(input, ctx~)
}

///|
async fn convert_csv(
  input : @core.InputSource,
  ctx : @core.ConvertContext,
) -> @core.ConvertResult {
  @csv.CsvConverter::convert_source(input, ctx~)
}

///|
async fn convert_text(
  input : @core.InputSource,
  ctx : @core.ConvertContext,
) -> @core.ConvertResult {
  @text.TextConverter::convert_source(input, ctx~)
}
