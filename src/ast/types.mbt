///|
pub(all) struct BlockAnnotation {
  id : String
  source_hint : String?
  origin_hint : String?
  diagnostics : Array[String]
} derive(Show, Eq, ToJson)

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
  Image(String, String, Array[Inline]?)
  HorizontalRule
} derive(Show, Eq, ToJson)

///|
pub(all) struct Document {
  title : String?
  metadata : Map[String, String]
  blocks : Array[Block]
  annotations : Array[BlockAnnotation]
} derive(Show, Eq, ToJson)

///|
pub fn default_block_annotation(index : Int) -> BlockAnnotation {
  BlockAnnotation::{
    id: "block-" + (index + 1).to_string(),
    source_hint: None,
    origin_hint: None,
    diagnostics: [],
  }
}

///|
pub fn normalize_annotations(
  annotations : Array[BlockAnnotation],
  block_count : Int,
) -> Array[BlockAnnotation] {
  let normalized : Array[BlockAnnotation] = []
  let mut index = 0
  while index < block_count {
    normalized.push(
      match annotations.get(index) {
        Some(existing) => existing
        None => default_block_annotation(index)
      },
    )
    index = index + 1
  }
  normalized
}

///|
pub fn Document::with_annotations(
  self : Document,
  annotations : Array[BlockAnnotation],
) -> Document {
  {
    ..self,
    annotations: normalize_annotations(annotations, self.blocks.length()),
  }
}

///|
pub fn document(
  title : String?,
  metadata : Map[String, String],
  blocks : Array[Block],
) -> Document {
  Document::{
    title,
    metadata,
    blocks,
    annotations: normalize_annotations([], blocks.length()),
  }
}

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
pub fn plain_text_of_block(block : Block) -> String {
  match block {
    Heading(_, inlines) => plain_text_of_inlines(inlines)
    Paragraph(inlines) => plain_text_of_inlines(inlines)
    List(items, _) => {
      let parts : Array[String] = []
      for item in items {
        parts.push(plain_text_of_inlines(item))
      }
      parts.join("\n")
    }
    Quote(lines) => lines.join("\n")
    CodeBlock(_, content) => content
    Table(headers, rows) => {
      let parts : Array[String] = []
      for header in headers {
        parts.push(plain_text_of_inlines(header))
      }
      for row in rows {
        for cell in row {
          parts.push(plain_text_of_inlines(cell))
        }
      }
      parts.join("\n")
    }
    Image(alt, src, caption) => {
      let suffix = match caption {
        Some(inlines) => "\n" + plain_text_of_inlines(inlines)
        None => ""
      }
      alt + "\n" + src + suffix
    }
    HorizontalRule => ""
  }
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
