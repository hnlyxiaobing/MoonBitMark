///|
pub(all) enum SemanticRole {
  Title
  Body
  Quote
  Code
  Table
  Image
  Separator
} derive(Show, Eq, ToJson)

///|
pub(all) struct SemanticBlock {
  block_id : String
  index : Int
  role : SemanticRole
  text : String
  source_hint : String?
  origin_hint : String?
  diagnostics : Array[String]
} derive(Show, Eq, ToJson)

///|
pub(all) struct Section {
  id : String
  title : String?
  level : Int
  block_indices : Array[Int]
  diagnostics : Array[String]
  children : Array[Section]
} derive(Show, Eq, ToJson)

///|
pub(all) struct SemanticDocument {
  title : String?
  sections : Array[Section]
  blocks : Array[SemanticBlock]
} derive(Show, Eq, ToJson)

///|
pub fn semantic_document_of(document : @ast.Document) -> SemanticDocument {
  let annotations = @ast.normalize_annotations(
    document.annotations,
    document.blocks.length(),
  )
  let blocks : Array[SemanticBlock] = []
  let mut sections : Array[Section] = []
  let mut section_counter = 1
  let mut index = 0
  while index < document.blocks.length() {
    let block = document.blocks[index]
    let annotation = annotations[index]
    blocks.push(semantic_block_of(block, annotation, index))
    match block {
      @ast.Heading(level, inlines) => {
        let section = Section::{
          id: "section-" + section_counter.to_string(),
          title: Some(@ast.plain_text_of_inlines(inlines)),
          level,
          block_indices: [index],
          diagnostics: annotation.diagnostics,
          children: [],
        }
        sections = insert_section(sections, section)
        section_counter = section_counter + 1
      }
      _ => sections = append_block_to_deepest_section(sections, index)
    }
    index = index + 1
  }
  SemanticDocument::{ title: document.title, sections, blocks }
}

///|
fn semantic_block_of(
  block : @ast.Block,
  annotation : @ast.BlockAnnotation,
  index : Int,
) -> SemanticBlock {
  SemanticBlock::{
    block_id: annotation.id,
    index,
    role: semantic_role_of(block, index == 0),
    text: @ast.plain_text_of_block(block),
    source_hint: annotation.source_hint,
    origin_hint: annotation.origin_hint,
    diagnostics: annotation.diagnostics,
  }
}

///|
fn semantic_role_of(block : @ast.Block, is_first : Bool) -> SemanticRole {
  match block {
    @ast.Heading(_, _) => if is_first { Title } else { Body }
    @ast.Paragraph(_) => Body
    @ast.List(_, _) => Body
    @ast.Quote(_) => Quote
    @ast.CodeBlock(_, _) => Code
    @ast.Table(_, _) => Table
    @ast.Block::Image(_, _, _) => Image
    @ast.HorizontalRule => Separator
  }
}

///|
fn insert_section(
  sections : Array[Section],
  section : Section,
) -> Array[Section] {
  if sections.length() == 0 {
    return [section]
  }
  let result : Array[Section] = []
  let last_index = sections.length() - 1
  let mut index = 0
  while index < sections.length() {
    let current = sections[index]
    if index == last_index && section.level > current.level {
      result.push({
        ..current,
        children: insert_section(current.children, section),
      })
    } else {
      result.push(current)
    }
    index = index + 1
  }
  if section.level <= sections[last_index].level {
    result.push(section)
  }
  result
}

///|
fn append_block_to_deepest_section(
  sections : Array[Section],
  block_index : Int,
) -> Array[Section] {
  if sections.length() == 0 {
    return [
      Section::{
        id: "section-implicit",
        title: None,
        level: 0,
        block_indices: [block_index],
        diagnostics: [],
        children: [],
      },
    ]
  }
  let result : Array[Section] = []
  let last_index = sections.length() - 1
  let mut index = 0
  while index < sections.length() {
    let current = sections[index]
    if index == last_index {
      let next = if current.children.length() == 0 {
        let block_indices = current.block_indices
        block_indices.push(block_index)
        { ..current, block_indices, }
      } else {
        {
          ..current,
          children: append_block_to_deepest_section(
            current.children,
            block_index,
          ),
        }
      }
      result.push(next)
    } else {
      result.push(current)
    }
    index = index + 1
  }
  result
}
