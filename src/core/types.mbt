// MoonBitMark - Core Type Definitions

///|
/// Conversion result containing Markdown text and optional metadata
pub(all) struct ConvertResult {
  markdown : String
  title : String?
  metadata : Map[String, String]
} derive(Show, Eq, ToJson)

///|
/// Information about the input file/stream
pub(all) struct StreamInfo {
  mimetype : String?
  extension : String?
  filename : String?
  url : String?
  charset : String?
} derive(Show, Eq, ToJson)

///|
/// Document converter trait
pub(open) trait DocumentConverter {
  accepts(StreamInfo) -> Bool
  convert(String) -> ConvertResult raise
}
