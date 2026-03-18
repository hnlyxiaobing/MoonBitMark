///|
pub(all) enum Inline {
  Text(String)
  Emphasis(Array[Inline])
  Strong(Array[Inline])
  Link(Array[Inline], String)
  Image(String, String)
  Code(String)
  LineBreak
} derive(Show, Eq, ToJson)

///|
pub(all) enum Block {
  Heading(Int, Array[Inline])
  Paragraph(Array[Inline])
  List(Array[String], Bool)
  Quote(Array[String])
  CodeBlock(String?, String)
  Table(Array[String], Array[Array[String]])
  HorizontalRule
} derive(Show, Eq, ToJson)

///|
pub(all) struct Document {
  title : String?
  metadata : Map[String, String]
  blocks : Array[Block]
} derive(Show, Eq, ToJson)

///|
pub fn text_heading(level : Int, content : String) -> Block {
  Heading(level, [Text(content)])
}

///|
pub fn text_paragraph(content : String) -> Block {
  Paragraph([Text(content)])
}
