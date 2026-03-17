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
  source_type : String
  stats : ConvertStats?
} derive(Show, Eq, ToJson)

///|
pub(all) enum DiagnosticLevel {
  Info
  Warning
  Error
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
  category : String
  phase : String?
  source : String?
  message : String
  hint : String?
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
    source_type,
    stats: None,
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
pub fn ConvertResult::with_stats(
  self : ConvertResult,
  stats : ConvertStats?,
) -> ConvertResult {
  { ..self, stats, }
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
pub fn warning_diagnostic(
  category : String,
  message : String,
  phase : String?,
  source : String?,
  hint : String?,
) -> ConversionDiagnostic {
  ConversionDiagnostic::{
    level: Warning,
    category,
    phase,
    source,
    message,
    hint,
  }
}

///|
pub fn error_diagnostic(
  category : String,
  message : String,
  phase : String?,
  source : String?,
  hint : String?,
) -> ConversionDiagnostic {
  ConversionDiagnostic::{ level: Error, category, phase, source, message, hint }
}

///|
pub fn diagnostics_from_warnings(
  warnings : Array[String],
  phase : String?,
  source : String?,
) -> Array[ConversionDiagnostic] {
  let diagnostics : Array[ConversionDiagnostic] = []
  for warning in warnings {
    diagnostics.push(
      warning_diagnostic("ConverterWarning", warning, phase, source, None),
    )
  }
  diagnostics
}
