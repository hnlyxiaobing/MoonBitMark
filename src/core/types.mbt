// MoonBitMark - Core Type Definitions

///|
pub(all) struct ConvertStats {
  char_count : Int
  block_count : Int
  duration_ms : Int?
  used_fallback : Bool
} derive(Show, Eq, ToJson)

///|
pub(all) struct ConvertResult {
  markdown : String
  title : String?
  metadata : Map[String, String]
  warnings : Array[String]
  diagnostics : Array[ConversionDiagnostic]
  assets : Array[OutputAsset]
  source_type : String
  stats : ConvertStats?
  document : @ast.Document?
} derive(Show, Eq, ToJson)

///|
pub(all) struct OutputAsset {
  placeholder : String
  filename : String
  bytes : Bytes
  source : DiagnosticSource?
  hint : DiagnosticHint?
} derive(Show, Eq, ToJson)

///|
pub(all) enum DiagnosticLevel {
  Info
  Warning
  Error
} derive(Show, Eq, ToJson)

///|
pub fn DiagnosticLevel::label(self : DiagnosticLevel) -> String {
  match self {
    Info => "Info"
    Warning => "Warning"
    Error => "Error"
  }
}

///|
pub(all) enum ConversionPhase {
  Detect(String?)
  Load(String?)
  Parse(String?)
  Normalize(String?)
  Render(String?)
  Postprocess(String?)
  Convert(String)
} derive(Show, Eq, ToJson)

///|
pub(all) enum DiagnosticSource {
  Input(String)
  File(String)
  Url(String)
  ArchiveEntry(String)
  Bytes(String?)
  Generated(String)
} derive(Show, Eq, ToJson)

///|
pub(all) enum DiagnosticHint {
  CheckInputDetection
  InspectSourceDocument
  ProvideBytesSourceName
  CheckArchiveIntegrity
  Custom(String)
} derive(Show, Eq, ToJson)

///|
pub(all) enum ConversionError {
  InputError(String, String?)
  FormatDetectionError(String)
  ZipError(String, String?)
  XmlParseError(String, Int?)
  UnsupportedFeatureError(String, String)
  ConversionFailed(String, String)
} derive(Show, Eq, ToJson)

///|
pub(all) struct ConversionDiagnostic {
  level : DiagnosticLevel
  error : ConversionError?
  phase : ConversionPhase?
  source : DiagnosticSource?
  message : String
  hint : DiagnosticHint?
} derive(Show, Eq, ToJson)

///|
pub fn ConvertResult::markdown_only(
  markdown : String,
  source_type : String,
) -> ConvertResult {
  ConvertResult::{
    markdown,
    title: None,
    metadata: Map::new(),
    warnings: [],
    diagnostics: [],
    assets: [],
    source_type,
    stats: None,
    document: None,
  }
}

///|
pub fn ConvertResult::with_title(
  self : ConvertResult,
  title : String?,
) -> ConvertResult {
  { ..self, title, }
}

///|
pub fn ConvertResult::with_metadata(
  self : ConvertResult,
  metadata : Map[String, String],
) -> ConvertResult {
  { ..self, metadata, }
}

///|
pub fn ConvertResult::with_warnings(
  self : ConvertResult,
  warnings : Array[String],
) -> ConvertResult {
  { ..self, warnings, }
}

///|
pub fn ConvertResult::with_diagnostics(
  self : ConvertResult,
  diagnostics : Array[ConversionDiagnostic],
) -> ConvertResult {
  { ..self, diagnostics, }
}

///|
pub fn ConvertResult::with_assets(
  self : ConvertResult,
  assets : Array[OutputAsset],
) -> ConvertResult {
  { ..self, assets, }
}

///|
pub fn ConvertResult::with_stats(
  self : ConvertResult,
  stats : ConvertStats?,
) -> ConvertResult {
  { ..self, stats, }
}

///|
pub fn ConvertResult::with_document(
  self : ConvertResult,
  document : @ast.Document?,
) -> ConvertResult {
  { ..self, document, }
}

///|
pub(all) struct StreamInfo {
  mimetype : String?
  extension : String?
  filename : String?
  url : String?
  charset : String?
} derive(Show, Eq, ToJson)

///|
pub(all) enum InputSource {
  FileInput(String, Bytes?)
  UrlInput(String, String?)
  BytesInput(String?, Bytes, String?)
} derive(Show, Eq, ToJson)

///|
pub fn InputSource::from_string(input : String) -> InputSource {
  if input.has_prefix("http://") || input.has_prefix("https://") {
    UrlInput(input, None)
  } else {
    FileInput(input, None)
  }
}

///|
pub fn InputSource::name(self : InputSource) -> String? {
  match self {
    FileInput(path, _) => Some(path)
    UrlInput(url, _) => Some(url)
    BytesInput(name, _, _) => name
  }
}

///|
pub fn InputSource::kind(self : InputSource) -> String {
  match self {
    FileInput(_, _) => "file"
    UrlInput(_, _) => "url"
    BytesInput(_, _, _) => "bytes"
  }
}

///|
pub(all) enum OutputMode {
  PlainText
  StandardMarkdown
  FrontMatterMarkdown
} derive(Show, Eq, ToJson)

///|
pub(all) struct ConvertContext {
  keep_metadata : Bool
  debug : Bool
  max_file_size : Int?
  timeout_ms : Int?
  asset_output_dir : String?
  output_mode : OutputMode
  ocr : @ocr.OcrConfig
} derive(Show, Eq, ToJson)

///|
pub fn ConvertContext::default() -> ConvertContext {
  ConvertContext::{
    keep_metadata: true,
    debug: false,
    max_file_size: None,
    timeout_ms: None,
    asset_output_dir: None,
    output_mode: StandardMarkdown,
    ocr: @ocr.OcrConfig::default(),
  }
}

///|
pub(open) trait DocumentConverter {
  name() -> String
  priority() -> Int
  accepts(StreamInfo) -> Bool
}

///|
pub fn count_markdown_blocks(markdown : String) -> Int {
  let trimmed = markdown.trim()
  if trimmed == "" {
    0
  } else {
    trimmed.split("\n\n").to_array().length()
  }
}

///|
pub fn stats_for_markdown(
  markdown : String,
  duration_ms? : Int,
  used_fallback? : Bool = false,
) -> ConvertStats {
  ConvertStats::{
    char_count: markdown.length(),
    block_count: count_markdown_blocks(markdown),
    duration_ms,
    used_fallback,
  }
}

///|
pub fn ConversionPhase::label(self : ConversionPhase) -> String {
  match self {
    Detect(detail) => format_phase_label("detect", detail)
    Load(detail) => format_phase_label("load", detail)
    Parse(detail) => format_phase_label("parse", detail)
    Normalize(detail) => format_phase_label("normalize", detail)
    Render(detail) => format_phase_label("render", detail)
    Postprocess(detail) => format_phase_label("postprocess", detail)
    Convert(name) => "convert/" + name
  }
}

///|
fn format_phase_label(stage : String, detail : String?) -> String {
  match detail {
    Some(value) => stage + "/" + value
    None => stage
  }
}

///|
pub fn DiagnosticSource::label(self : DiagnosticSource) -> String {
  match self {
    Input(name) => name
    File(path) => path
    Url(url) => url
    ArchiveEntry(path) => path
    Bytes(name) =>
      match name {
        Some(value) => value
        None => "<bytes>"
      }
    Generated(name) => name
  }
}

///|
pub fn DiagnosticHint::message(self : DiagnosticHint) -> String {
  match self {
    CheckInputDetection => "Check the file extension, URL, or MIME information."
    InspectSourceDocument =>
      "Inspect the source document or run with debug context."
    ProvideBytesSourceName =>
      "Provide a source name for bytes input so format detection can proceed."
    CheckArchiveIntegrity =>
      "Inspect archive integrity and verify the expected internal entries exist."
    Custom(message) => message
  }
}

///|
pub fn ConversionError::category(self : ConversionError) -> String {
  match self {
    InputError(_, _) => "InputError"
    FormatDetectionError(_) => "FormatDetectionError"
    ZipError(_, _) => "ZipError"
    XmlParseError(_, _) => "XmlParseError"
    UnsupportedFeatureError(_, _) => "UnsupportedFeatureError"
    ConversionFailed(_, _) => "ConversionFailed"
  }
}

///|
pub fn ConversionError::message(self : ConversionError) -> String {
  match self {
    InputError(message, detail) =>
      match detail {
        Some(value) => message + " (" + value + ")"
        None => message
      }
    FormatDetectionError(message) => message
    ZipError(message, file) =>
      match file {
        Some(value) => message + " (" + value + ")"
        None => message
      }
    XmlParseError(message, line) =>
      match line {
        Some(value) => message + " (line " + value.to_string() + ")"
        None => message
      }
    UnsupportedFeatureError(feature, format) =>
      "Unsupported feature: " + feature + " (" + format + ")"
    ConversionFailed(message, _) => message
  }
}

///|
pub fn ConversionDiagnostic::category(self : ConversionDiagnostic) -> String {
  match self.error {
    Some(error) => error.category()
    None => "ConverterWarning"
  }
}

///|
pub fn ConversionDiagnostic::with_defaults(
  self : ConversionDiagnostic,
  phase : ConversionPhase?,
  source : DiagnosticSource?,
  hint : DiagnosticHint?,
) -> ConversionDiagnostic {
  let next_phase = match self.phase {
    Some(existing) => Some(existing)
    None => phase
  }
  let next_source = match self.source {
    Some(existing) => Some(existing)
    None => source
  }
  let next_hint = match self.hint {
    Some(existing) => Some(existing)
    None => hint
  }
  { ..self, phase: next_phase, source: next_source, hint: next_hint }
}

///|
pub fn ConversionDiagnostic::render(self : ConversionDiagnostic) -> String {
  let mut result = self.level.label() + ": " + self.category() + "\n"
  match self.phase {
    Some(phase) => result = result + "  Phase: " + phase.label() + "\n"
    None => ()
  }
  match self.source {
    Some(source) => result = result + "  Source: " + source.label() + "\n"
    None => ()
  }
  result = result + "  Message: " + self.message
  match self.hint {
    Some(hint) => result = result + "\n  Hint: " + hint.message()
    None => ()
  }
  result
}

///|
pub fn ConvertStats::render(self : ConvertStats) -> String {
  let parts : Array[String] = [
    "chars=" + self.char_count.to_string(),
    "blocks=" + self.block_count.to_string(),
  ]
  match self.duration_ms {
    Some(value) => parts.push("duration_ms=" + value.to_string())
    None => ()
  }
  if self.used_fallback {
    parts.push("used_fallback=true")
  }
  parts.join(", ")
}

///|
pub fn render_diagnostics_report(
  diagnostics : Array[ConversionDiagnostic],
) -> String {
  if diagnostics.length() == 0 {
    "Diagnostics: none"
  } else {
    let lines : Array[String] = ["Diagnostics:"]
    for diagnostic in diagnostics {
      lines.push(diagnostic.render())
    }
    lines.join("\n")
  }
}

///|
pub fn ConvertResult::debug_report(self : ConvertResult) -> String {
  let lines : Array[String] = [
    "ConvertResult Debug Report",
    "source_type: " + self.source_type,
  ]
  match self.title {
    Some(value) => lines.push("title: " + value)
    None => ()
  }
  match self.stats {
    Some(stats) => lines.push("stats: " + stats.render())
    None => ()
  }
  lines.push("warnings: " + self.warnings.length().to_string())
  lines.push("diagnostics: " + self.diagnostics.length().to_string())
  lines.push("assets: " + self.assets.length().to_string())
  match self.document {
    Some(_) => lines.push("ast: present")
    None => lines.push("ast: none")
  }
  if self.metadata.length() == 0 {
    lines.push("metadata: none")
  } else {
    lines.push("metadata:")
    for key, value in self.metadata {
      lines.push("  " + key + ": " + value)
    }
  }
  lines.push(render_diagnostics_report(self.diagnostics))
  lines.join("\n")
}

///|
pub fn warning_diagnostic(
  message : String,
  phase : ConversionPhase?,
  source : DiagnosticSource?,
  hint : DiagnosticHint?,
) -> ConversionDiagnostic {
  ConversionDiagnostic::{
    level: Warning,
    error: None,
    phase,
    source,
    message,
    hint,
  }
}

///|
pub fn error_diagnostic(
  error : ConversionError,
  phase : ConversionPhase?,
  source : DiagnosticSource?,
  hint : DiagnosticHint?,
) -> ConversionDiagnostic {
  let message = error.message()
  ConversionDiagnostic::{
    level: Error,
    error: Some(error),
    phase,
    source,
    message,
    hint,
  }
}

///|
pub fn diagnostics_from_warnings(
  warnings : Array[String],
  phase : ConversionPhase?,
  source : DiagnosticSource?,
  hint? : DiagnosticHint = Custom("Inspect the converter output for details."),
) -> Array[ConversionDiagnostic] {
  let diagnostics : Array[ConversionDiagnostic] = []
  for warning in warnings {
    diagnostics.push(warning_diagnostic(warning, phase, source, Some(hint)))
  }
  diagnostics
}
