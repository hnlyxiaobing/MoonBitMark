///|
pub(all) enum SemanticRole {
  Title
  Subtitle
  Body
  Caption
  Note
  Code
  TableHeader
  TableBody
  Quote
  FooterLike
  Image
  Separator
} derive(Debug, Eq, ToJson)

///|
pub impl Show for SemanticRole with output(self, logger) {
  self.to_repr().output(logger)
}

///|
pub(all) struct Provenance {
  source_path : String?
  source_url : String?
  page_no : Int?
  slide_no : Int?
  sheet_name : String?
  chapter : String?
  resource : String?
} derive(Debug, Eq, ToJson)

///|
pub(all) struct SemanticBlock {
  block_id : String
  index : Int
  role : SemanticRole
  text : String
  source_hint : String?
  origin_hint : String?
  diagnostics : Array[String]
  confidence : Int
  provenance : Provenance
} derive(Debug, Eq, ToJson)

///|
pub(all) struct Section {
  id : String
  title : String?
  level : Int
  role : SemanticRole
  block_indices : Array[Int]
  diagnostics : Array[String]
  provenance : Provenance
  children : Array[Section]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct SemanticDocument {
  title : String?
  sections : Array[Section]
  blocks : Array[SemanticBlock]
  provenance : Provenance
} derive(Debug, Eq, ToJson)

///|
pub fn semantic_document_of(document : @ast.Document) -> SemanticDocument {
  let annotations = @ast.normalize_annotations(
    document.annotations,
    document.blocks.length(),
  )
  let document_provenance = document_provenance_of(document.metadata)
  let blocks : Array[SemanticBlock] = []
  let mut sections : Array[Section] = []
  let mut section_counter = 1
  let mut current_page_no = document_provenance.page_no
  let mut current_slide_no = document_provenance.slide_no
  let mut index = 0
  while index < document.blocks.length() {
    let block = document.blocks[index]
    let annotation = annotations[index]
    let semantic_block = semantic_block_of(
      block,
      annotation,
      document.metadata,
      document.title,
      index,
      index > 0,
      document.blocks.get(index - 1),
      current_page_no,
      current_slide_no,
    )
    blocks.push(semantic_block)
    match semantic_block.provenance.page_no {
      Some(value) => current_page_no = Some(value)
      None => ()
    }
    match semantic_block.provenance.slide_no {
      Some(value) => current_slide_no = Some(value)
      None => ()
    }
    match block {
      @ast.Heading(level, inlines) => {
        let section = Section::{
          id: "section-" + section_counter.to_string(),
          title: Some(@ast.plain_text_of_inlines(inlines)),
          level,
          role: semantic_block.role,
          block_indices: [index],
          diagnostics: annotation.diagnostics,
          provenance: semantic_block.provenance,
          children: [],
        }
        sections = insert_section(sections, section)
        section_counter = section_counter + 1
      }
      _ =>
        sections = append_block_to_deepest_section(
          sections,
          index,
          semantic_block.provenance,
        )
    }
    index = index + 1
  }
  SemanticDocument::{
    title: document.title,
    sections,
    blocks,
    provenance: document_provenance,
  }
}

///|
fn semantic_block_of(
  block : @ast.Block,
  annotation : @ast.BlockAnnotation,
  metadata : Map[String, String],
  document_title : String?,
  index : Int,
  has_previous : Bool,
  previous_block : @ast.Block?,
  current_page_no : Int?,
  current_slide_no : Int?,
) -> SemanticBlock {
  let text = @ast.plain_text_of_block(block)
  let provenance = provenance_of(
    metadata, annotation, block, text, current_page_no, current_slide_no,
  )
  SemanticBlock::{
    block_id: annotation.id,
    index,
    role: semantic_role_of(
      block,
      text,
      metadata,
      document_title,
      index == 0,
      has_previous,
      previous_block,
    ),
    text,
    source_hint: annotation.source_hint,
    origin_hint: annotation.origin_hint,
    diagnostics: annotation.diagnostics,
    confidence: confidence_of(block, text, annotation.diagnostics),
    provenance,
  }
}

///|
fn semantic_role_of(
  block : @ast.Block,
  text : String,
  metadata : Map[String, String],
  document_title : String?,
  is_first : Bool,
  has_previous : Bool,
  previous_block : @ast.Block?,
) -> SemanticRole {
  let format_name = metadata.get("format")
  let normalized = text.trim().to_lower().to_string()
  match block {
    @ast.Heading(level, _) =>
      if format_name == Some("pptx") && looks_like_slide_heading(text) {
        Separator
      } else if is_first || matches_document_title(text, document_title) {
        Title
      } else if format_name == Some("pptx") &&
        previous_block_is_slide_heading(previous_block) {
        Title
      } else if level <= 2 && !has_previous {
        Subtitle
      } else if normalized.contains("appendix") ||
        normalized.contains("license") ||
        normalized.contains("copyright") ||
        normalized.contains("references") {
        FooterLike
      } else if level == 2 {
        Subtitle
      } else {
        Body
      }
    @ast.Paragraph(_) =>
      if format_name == Some("html") &&
        is_first &&
        matches_document_title(text, document_title) {
        Title
      } else if normalized.has_prefix("note:") ||
        normalized.has_prefix("warning:") ||
        normalized.has_prefix("tip:") {
        Note
      } else if normalized.has_prefix("figure ") ||
        normalized.has_prefix("fig. ") ||
        normalized.has_prefix("table ") ||
        paragraph_looks_like_caption(text) ||
        previous_block is Some(@ast.Block::Image(_, _, _)) {
        Caption
      } else if normalized.contains("all rights reserved") ||
        normalized.contains("project gutenberg license") ||
        normalized.contains("printed by ") {
        FooterLike
      } else {
        Body
      }
    @ast.List(_, _) =>
      if normalized.has_prefix("note:") || normalized.has_prefix("warning:") {
        Note
      } else {
        Body
      }
    @ast.Quote(_) => Quote
    @ast.CodeBlock(_, _) => Code
    @ast.Table(_, rows) =>
      if rows.length() > 0 {
        TableBody
      } else {
        TableHeader
      }
    @ast.Block::Image(_, _, caption) =>
      match caption {
        Some(value) if @ast.plain_text_of_inlines(value).trim() != "" => Caption
        _ => Image
      }
    @ast.HorizontalRule => Separator
  }
}

///|
fn previous_block_is_slide_heading(previous_block : @ast.Block?) -> Bool {
  match previous_block {
    Some(block) => looks_like_slide_heading(@ast.plain_text_of_block(block))
    None => false
  }
}

///|
fn paragraph_looks_like_caption(text : String) -> Bool {
  let trimmed = text.trim().to_string()
  if trimmed == "" || trimmed.length() > 120 {
    return false
  }
  trimmed.has_prefix("Figure ") ||
  trimmed.has_prefix("Fig. ") ||
  trimmed.has_prefix("Table ") ||
  trimmed.has_prefix("Image ")
}

///|
fn confidence_of(
  block : @ast.Block,
  text : String,
  diagnostics : Array[String],
) -> Int {
  let mut value = 85
  if text.trim() == "" {
    value = 40
  }
  if diagnostics.length() > 0 {
    value = value - diagnostics.length() * 10
  }
  match block {
    @ast.HorizontalRule => value = 95
    @ast.CodeBlock(_, _) => value = 95
    @ast.Table(_, _) => value = value - 5
    @ast.Block::Image(_, _, _) => value = value - 10
    _ => ()
  }
  if value < 10 {
    10
  } else if value > 100 {
    100
  } else {
    value
  }
}

///|
fn document_provenance_of(metadata : Map[String, String]) -> Provenance {
  let format_name = metadata.get("format")
  Provenance::{
    source_path: metadata.get("source_path"),
    source_url: metadata.get("source_url"),
    page_no: parse_optional_int(metadata.get("page_no")),
    slide_no: parse_optional_int(metadata.get("slide_no")),
    sheet_name: metadata.get("sheet_name"),
    chapter: metadata.get("chapter"),
    resource: default_resource_for_format(
      format_name,
      metadata.get("resource"),
      parse_optional_int(metadata.get("slide_no")),
    ),
  }
}

///|
fn provenance_of(
  metadata : Map[String, String],
  annotation : @ast.BlockAnnotation,
  block : @ast.Block,
  text : String,
  current_page_no : Int?,
  current_slide_no : Int?,
) -> Provenance {
  let base = document_provenance_of(metadata)
  let format_name = metadata.get("format")
  let inferred_page_no = page_no_from_hints(annotation, base.page_no)
  let inferred_slide_no = slide_no_from_hints(annotation, base.slide_no)
  let slide_no = match inferred_slide_no {
    Some(value) => Some(value)
    None =>
      infer_slide_no_from_block(
        format_name,
        block,
        text,
        current_slide_no,
        base.slide_no,
      )
  }
  Provenance::{
    source_path: first_present(
      path_like_hint(annotation.source_hint),
      base.source_path,
    ),
    source_url: first_present(
      url_like_hint(annotation.source_hint),
      base.source_url,
    ),
    resource: resource_from_hints(
      annotation.origin_hint,
      annotation.source_hint,
      default_resource_for_format(format_name, base.resource, slide_no),
    ),
    page_no: match inferred_page_no {
      Some(value) => Some(value)
      None => first_present_int(current_page_no, base.page_no)
    },
    slide_no,
    sheet_name: sheet_name_from_hints(annotation, base.sheet_name),
    chapter: chapter_from_hints(annotation, base.chapter),
  }
}

///|
fn default_resource_for_format(
  format_name : String?,
  current : String?,
  slide_no : Int?,
) -> String? {
  match format_name {
    Some("pptx") =>
      match slide_no {
        Some(value) => Some("ppt/slides/slide" + value.to_string() + ".xml")
        None =>
          match current {
            Some(value) if value != "" => Some(value)
            _ => Some("ppt/presentation.xml")
          }
      }
    _ =>
      match current {
        Some(value) if value != "" => Some(value)
        _ =>
          match format_name {
            Some("docx") => Some("word/document.xml")
            Some("html") => Some("html:body")
            Some("pdf") => Some("pdf/document")
            _ => None
          }
      }
  }
}

///|
fn path_like_hint(text : String?) -> String? {
  match text {
    Some(value) => {
      let trimmed = value.trim().to_string()
      if trimmed.contains("/") ||
        trimmed.contains("\\") ||
        (
          trimmed.length() >= 2 &&
          trimmed[1:2].to_string() == ":" &&
          is_ascii_letter(trimmed[0])
        ) {
        Some(trimmed)
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn url_like_hint(text : String?) -> String? {
  match text {
    Some(value) => {
      let trimmed = value.trim().to_string()
      if trimmed.has_prefix("http://") || trimmed.has_prefix("https://") {
        Some(trimmed)
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn resource_from_hints(
  origin_hint : String?,
  source_hint : String?,
  fallback : String?,
) -> String? {
  match extract_text_after_prefix(origin_hint, "resource:") {
    Some(value) => Some(value)
    None =>
      match extract_text_after_prefix(source_hint, "resource:") {
        Some(value) => Some(value)
        None => fallback
      }
  }
}

///|
fn infer_slide_no_from_block(
  format_name : String?,
  block : @ast.Block,
  text : String,
  current_slide_no : Int?,
  fallback : Int?,
) -> Int? {
  match format_name {
    Some("pptx") =>
      match slide_heading_number(block, text) {
        Some(value) => Some(value)
        None => first_present_int(current_slide_no, fallback)
      }
    _ => fallback
  }
}

///|
fn slide_heading_number(block : @ast.Block, text : String) -> Int? {
  match block {
    @ast.Heading(_, _) =>
      if looks_like_slide_heading(text) {
        parse_decimal_digits(text.trim().to_string()[6:].trim().to_string())
      } else {
        None
      }
    _ => None
  }
}

///|
fn looks_like_slide_heading(text : String) -> Bool {
  let trimmed = text.trim().to_string()
  trimmed.has_prefix("Slide ") &&
  parse_decimal_digits(trimmed[6:].trim().to_string()) is Some(_)
}

///|
fn matches_document_title(text : String, document_title : String?) -> Bool {
  match document_title {
    Some(title) =>
      normalize_title_like_text(text) == normalize_title_like_text(title)
    None => false
  }
}

///|
fn normalize_title_like_text(text : String) -> String {
  text.trim().to_lower().to_string()
}

///|
fn is_ascii_letter(ch : UInt16) -> Bool {
  (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
}

///|
fn page_no_from_hints(
  annotation : @ast.BlockAnnotation,
  fallback : Int?,
) -> Int? {
  match extract_number_after_prefix(annotation.source_hint, "page:") {
    Some(value) => Some(value)
    None =>
      match extract_number_after_prefix(annotation.origin_hint, "page:") {
        Some(value) => Some(value)
        None => fallback
      }
  }
}

///|
fn slide_no_from_hints(
  annotation : @ast.BlockAnnotation,
  fallback : Int?,
) -> Int? {
  match extract_number_after_prefix(annotation.source_hint, "slide:") {
    Some(value) => Some(value)
    None =>
      match extract_number_after_prefix(annotation.origin_hint, "slide:") {
        Some(value) => Some(value)
        None => fallback
      }
  }
}

///|
fn sheet_name_from_hints(
  annotation : @ast.BlockAnnotation,
  fallback : String?,
) -> String? {
  match extract_text_after_prefix(annotation.source_hint, "sheet:") {
    Some(value) => Some(value)
    None =>
      match extract_text_after_prefix(annotation.origin_hint, "sheet:") {
        Some(value) => Some(value)
        None => fallback
      }
  }
}

///|
fn chapter_from_hints(
  annotation : @ast.BlockAnnotation,
  fallback : String?,
) -> String? {
  match extract_text_after_prefix(annotation.source_hint, "chapter:") {
    Some(value) => Some(value)
    None =>
      match extract_text_after_prefix(annotation.origin_hint, "chapter:") {
        Some(value) => Some(value)
        None => fallback
      }
  }
}

///|
fn first_present(primary : String?, fallback : String?) -> String? {
  match primary {
    Some(value) if value != "" => Some(value)
    _ => fallback
  }
}

///|
fn parse_optional_int(value : String?) -> Int? {
  match value {
    Some(text) if text != "" => parse_decimal_digits(text.trim().to_string())
    _ => None
  }
}

///|
fn parse_decimal_digits(text : String) -> Int? {
  if text == "" {
    return None
  }
  let mut value = 0
  for ch in text {
    if ch < '0' || ch > '9' {
      return None
    }
    value = value * 10 + (ch.to_int() - '0'.to_int())
  }
  Some(value)
}

///|
fn extract_number_after_prefix(text : String?, prefix : String) -> Int? {
  match extract_text_after_prefix(text, prefix) {
    Some(value) => parse_decimal_digits(value)
    None => None
  }
}

///|
fn extract_text_after_prefix(text : String?, prefix : String) -> String? {
  match text {
    Some(value) => {
      let trimmed = value.trim().to_string()
      let lowered = trimmed.to_lower().to_string()
      if lowered.has_prefix(prefix) {
        Some(trimmed[prefix.length():].trim().to_string())
      } else {
        None
      }
    }
    None => None
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
  provenance : Provenance,
) -> Array[Section] {
  if sections.length() == 0 {
    return [
      Section::{
        id: "section-implicit",
        title: None,
        level: 0,
        role: Body,
        block_indices: [block_index],
        diagnostics: [],
        provenance,
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
        {
          ..current,
          block_indices,
          provenance: merge_provenance(current.provenance, provenance),
        }
      } else {
        {
          ..current,
          children: append_block_to_deepest_section(
            current.children,
            block_index,
            provenance,
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

///|
fn merge_provenance(current : Provenance, incoming : Provenance) -> Provenance {
  Provenance::{
    source_path: first_present(current.source_path, incoming.source_path),
    source_url: first_present(current.source_url, incoming.source_url),
    page_no: first_present_int(current.page_no, incoming.page_no),
    slide_no: first_present_int(current.slide_no, incoming.slide_no),
    sheet_name: first_present(current.sheet_name, incoming.sheet_name),
    chapter: first_present(current.chapter, incoming.chapter),
    resource: first_present(current.resource, incoming.resource),
  }
}

///|
fn first_present_int(primary : Int?, fallback : Int?) -> Int? {
  match primary {
    Some(_) => primary
    None => fallback
  }
}
