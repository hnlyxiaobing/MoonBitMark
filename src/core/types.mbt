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
  source_type : String
  stats : ConvertStats?
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
    source_type,
    stats: None,
  }
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
  FileInput(path : String, bytes : Bytes?)
  UrlInput(url : String, fetched_html : String?)
  BytesInput(name : String?, bytes : Bytes, mimetype : String?)
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
