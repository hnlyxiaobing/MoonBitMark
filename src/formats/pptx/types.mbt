// PPTX Converter - Type Definitions
// Currently minimal types as needed for implementation

///|
/// PPTX 解析错误类型
suberror PPTXError {
  InvalidZipStructure
  MissingPresentationXml
  MalformedSlideXml(String)
  UnsupportedShapeType(String)
  ImageExtractionFailed(String)
}
