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
  List(Array[Array[Inline]], Bool)
  Quote(Array[String])
  CodeBlock(String?, String)
  Table(Array[Array[Inline]], Array[Array[Array[Inline]]])
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
  Heading(level, text_inlines(content))
}

///|
pub fn text_paragraph(content : String) -> Block {
  Paragraph(text_inlines(content))
}

///|
pub fn text_inlines(content : String) -> Array[Inline] {
  [Text(content)]
}

///|
pub fn plain_text_of_inlines(inlines : Array[Inline]) -> String {
  let parts : Array[String] = []
  for inline in inlines {
    parts.push(plain_text_of_inline(inline))
  }
  parts.join("")
}

///|
fn plain_text_of_inline(inline : Inline) -> String {
  match inline {
    Text(text) => text
    Emphasis(children) => plain_text_of_inlines(children)
    Strong(children) => plain_text_of_inlines(children)
    Link(children, _) => plain_text_of_inlines(children)
    Image(alt, _) => alt
    Code(text) => text
    LineBreak => "\n"
  }
}
