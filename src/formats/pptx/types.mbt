// PPTX Converter - Pure MoonBit Implementation
// Converts PowerPoint presentations (.pptx) to Markdown

///|
/// PPTX 解析错误类型
suberror PPTXError {
  InvalidZipStructure
  MissingPresentationXml
  MalformedSlideXml(String)
  UnsupportedShapeType(String)
  ImageExtractionFailed(String)
}

///|
/// 形状位置信息
priv struct Position {
  mut top : Int
  mut left : Int
}

///|
/// 文本形状
priv struct TextShape {
  mut text : String
  mut is_title : Bool
  mut position : Position
}

///|
/// 图片形状
priv struct PictureShape {
  mut name : String
  mut description : String
  mut media_path : String
  mut content_type : String
}

///|
/// 表格单元格
priv struct TableCell {
  mut text : String
}

///|
/// 表格行
priv struct TableRow {
  mut cells : Array[TableCell]
}

///|
/// 表格形状
priv struct TableShape {
  mut rows : Array[TableRow]
}

///|
/// 幻灯片
priv struct Slide {
  mut number : Int
  mut shapes : Array[Shape]
  mut notes : String
}

///|
/// 形状联合类型
priv enum Shape {
  Text(TextShape)
  Picture(PictureShape)
  Table(TableShape)
  Group(Array[Shape])
}
