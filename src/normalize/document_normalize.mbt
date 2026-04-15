///|
type AnnotatedBlock = (@ast.Block, @ast.BlockAnnotation)

///|
pub fn normalize_document(document : @ast.Document) -> @ast.Document {
  let pairs = zip_blocks_with_annotations(document)
  let heading_pairs = normalize_heading_levels(pairs)
  let list_pairs = normalize_list_blocks(heading_pairs)
  let table_pairs = normalize_table_shape(list_pairs)
  let final_pairs = normalize_paragraph_whitespace(table_pairs)
  build_document(document, final_pairs)
}

///|
fn zip_blocks_with_annotations(
  document : @ast.Document,
) -> Array[AnnotatedBlock] {
  let annotations = @ast.normalize_annotations(
    document.annotations,
    document.blocks.length(),
  )
  let pairs : Array[AnnotatedBlock] = []
  let mut index = 0
  while index < document.blocks.length() {
    pairs.push((document.blocks[index], annotations[index]))
    index = index + 1
  }
  pairs
}

///|
fn build_document(
  original : @ast.Document,
  pairs : Array[AnnotatedBlock],
) -> @ast.Document {
  let blocks : Array[@ast.Block] = []
  let annotations : Array[@ast.BlockAnnotation] = []
  for pair in pairs {
    blocks.push(pair.0)
    annotations.push(pair.1)
  }
  @ast.Document::{
    title: original.title,
    metadata: original.metadata,
    blocks,
    annotations: @ast.normalize_annotations(annotations, blocks.length()),
  }
}

///|
fn normalize_heading_levels(
  pairs : Array[AnnotatedBlock],
) -> Array[AnnotatedBlock] {
  let normalized : Array[AnnotatedBlock] = []
  for pair in pairs {
    let block = pair.0
    let annotation = pair.1
    match block {
      @ast.Heading(level, inlines) => {
        let clamped = clamp_heading_level(level)
        let expected = clamped
        let updated_annotation = if expected == level {
          annotation
        } else {
          annotation_with_diagnostic(
            annotation,
            "Normalized heading level from " +
            level.to_string() +
            " to " +
            expected.to_string(),
          )
        }
        normalized.push((@ast.Heading(expected, inlines), updated_annotation))
      }
      _ => normalized.push((block, annotation))
    }
  }
  normalized
}

///|
fn clamp_heading_level(level : Int) -> Int {
  if level < 1 {
    1
  } else if level > 6 {
    6
  } else {
    level
  }
}

///|
fn normalize_list_blocks(
  pairs : Array[AnnotatedBlock],
) -> Array[AnnotatedBlock] {
  let normalized : Array[AnnotatedBlock] = []
  for pair in pairs {
    let block = pair.0
    let annotation = pair.1
    match block {
      @ast.List(items, ordered) => {
        let next_items : Array[Array[@ast.Inline]] = []
        for item in items {
          let normalized_item = normalize_list_item_whitespace(item)
          if @ast.plain_text_of_inlines(normalized_item) != "" {
            next_items.push(normalized_item)
          }
        }
        let next_annotation = if next_items.length() == items.length() {
          annotation
        } else {
          annotation_with_diagnostic(
            annotation, "Removed empty list items during normalization",
          )
        }
        normalized.push((@ast.List(next_items, ordered), next_annotation))
      }
      _ => normalized.push((block, annotation))
    }
  }
  normalized
}

///|
fn normalize_list_item_whitespace(
  inlines : Array[@ast.Inline],
) -> Array[@ast.Inline] {
  let normalized = normalize_inline_whitespace(inlines)
  let prefix = leading_whitespace_prefix(inlines)
  if prefix == "" || normalized.length() == 0 {
    return normalized
  }
  let result : Array[@ast.Inline] = []
  let mut is_first = true
  for inline in normalized {
    if is_first {
      match inline {
        @ast.Text(text) => result.push(@ast.Text(prefix + text))
        _ => {
          result.push(@ast.Text(prefix))
          result.push(inline)
        }
      }
      is_first = false
    } else {
      result.push(inline)
    }
  }
  result
}

///|
fn leading_whitespace_prefix(inlines : Array[@ast.Inline]) -> String {
  match inlines.get(0) {
    Some(@ast.Text(text)) => {
      let mut prefix = ""
      for ch in text {
        if ch == ' ' || ch == '\t' {
          prefix = prefix + ch.to_string()
        } else {
          break
        }
      }
      prefix
    }
    _ => ""
  }
}

///|
fn normalize_table_shape(
  pairs : Array[AnnotatedBlock],
) -> Array[AnnotatedBlock] {
  let normalized : Array[AnnotatedBlock] = []
  for pair in pairs {
    let block = pair.0
    let annotation = pair.1
    match block {
      @ast.Table(headers, rows) => {
        let result = normalize_table(headers, rows)
        let next_annotation = if result.2 {
          annotation_with_diagnostic(
            annotation, "Normalized table shape to a rectangular layout",
          )
        } else {
          annotation
        }
        normalized.push((@ast.Table(result.0, result.1), next_annotation))
      }
      _ => normalized.push((block, annotation))
    }
  }
  normalized
}

///|
fn normalize_table(
  headers : Array[Array[@ast.Inline]],
  rows : Array[Array[Array[@ast.Inline]]],
) -> (Array[Array[@ast.Inline]], Array[Array[Array[@ast.Inline]]], Bool) {
  let mut changed = false
  let seed_headers = if headers.length() == 0 && rows.length() > 0 {
    changed = true
    rows[0]
  } else {
    headers
  }
  let source_rows : Array[Array[Array[@ast.Inline]]] = []
  let mut row_start = 0
  if headers.length() == 0 && rows.length() > 0 {
    row_start = 1
  }
  let mut row_index = row_start
  while row_index < rows.length() {
    source_rows.push(rows[row_index])
    row_index = row_index + 1
  }
  let width = table_width(seed_headers, source_rows)
  let next_headers = normalize_row_shape(seed_headers, width)
  if next_headers != seed_headers {
    changed = true
  }
  let next_rows : Array[Array[Array[@ast.Inline]]] = []
  for row in source_rows {
    let normalized_row = normalize_row_shape(row, width)
    if normalized_row != row {
      changed = true
    }
    next_rows.push(normalized_row)
  }
  (next_headers, next_rows, changed)
}

///|
fn table_width(
  headers : Array[Array[@ast.Inline]],
  rows : Array[Array[Array[@ast.Inline]]],
) -> Int {
  let mut width = headers.length()
  for row in rows {
    if row.length() > width {
      width = row.length()
    }
  }
  width
}

///|
fn normalize_row_shape(
  row : Array[Array[@ast.Inline]],
  width : Int,
) -> Array[Array[@ast.Inline]] {
  let normalized : Array[Array[@ast.Inline]] = []
  let mut index = 0
  while index < width {
    normalized.push(
      match row.get(index) {
        Some(cell) => normalize_inline_whitespace(cell)
        None => []
      },
    )
    index = index + 1
  }
  normalized
}

///|
fn normalize_paragraph_whitespace(
  pairs : Array[AnnotatedBlock],
) -> Array[AnnotatedBlock] {
  let normalized : Array[AnnotatedBlock] = []
  for pair in pairs {
    let block = pair.0
    let annotation = pair.1
    match block {
      @ast.Paragraph([@ast.Inline::Image(alt, src)]) =>
        normalized.push(
          (@ast.Block::Image(squeeze_whitespace(alt), src, None), annotation),
        )
      @ast.Paragraph(inlines) => {
        let next_inlines = normalize_inline_whitespace(inlines)
        let next_annotation = if next_inlines == inlines {
          annotation
        } else {
          annotation_with_diagnostic(
            annotation, "Normalized paragraph whitespace",
          )
        }
        normalized.push((@ast.Paragraph(next_inlines), next_annotation))
      }
      @ast.Heading(level, inlines) =>
        normalized.push(
          (
            @ast.Heading(level, normalize_inline_whitespace(inlines)),
            annotation,
          ),
        )
      @ast.Block::Image(alt, src, caption) =>
        normalized.push(
          (
            @ast.Block::Image(
              squeeze_whitespace(alt),
              src,
              normalize_caption(caption),
            ),
            annotation,
          ),
        )
      _ => normalized.push((block, annotation))
    }
  }
  normalized
}

///|
fn normalize_caption(caption : Array[@ast.Inline]?) -> Array[@ast.Inline]? {
  match caption {
    Some(inlines) => Some(normalize_inline_whitespace(inlines))
    None => None
  }
}

///|
fn normalize_inline_whitespace(
  inlines : Array[@ast.Inline],
) -> Array[@ast.Inline] {
  let normalized : Array[@ast.Inline] = []
  let mut pending_text = ""
  let flush_pending_text = fn() {
    let compact = squeeze_whitespace(pending_text)
    if compact != "" {
      normalized.push(@ast.Text(compact))
    }
    pending_text = ""
  }
  for inline in inlines {
    match inline {
      @ast.Text(text) => pending_text = pending_text + text
      @ast.Emphasis(children) => {
        flush_pending_text()
        normalized.push(@ast.Emphasis(normalize_inline_whitespace(children)))
      }
      @ast.Strong(children) => {
        flush_pending_text()
        normalized.push(@ast.Strong(normalize_inline_whitespace(children)))
      }
      @ast.Link(children, url) => {
        flush_pending_text()
        normalized.push(@ast.Link(normalize_inline_whitespace(children), url))
      }
      @ast.Inline::Image(alt, url) => {
        flush_pending_text()
        normalized.push(@ast.Inline::Image(squeeze_whitespace(alt), url))
      }
      @ast.Code(text) => {
        flush_pending_text()
        normalized.push(@ast.Code(text))
      }
      @ast.LineBreak => {
        flush_pending_text()
        normalized.push(@ast.LineBreak)
      }
    }
  }
  flush_pending_text()
  normalized
}

///|
fn squeeze_whitespace(text : String) -> String {
  let mut result = ""
  let mut previous_space = false
  for ch in text.trim() {
    let is_space = ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t'
    if is_space {
      if !previous_space {
        result = result + " "
      }
    } else {
      result = result + ch.to_string()
    }
    previous_space = is_space
  }
  result
}

///|
fn annotation_with_diagnostic(
  annotation : @ast.BlockAnnotation,
  diagnostic : String,
) -> @ast.BlockAnnotation {
  let next_diagnostics : Array[String] = []
  for item in annotation.diagnostics {
    next_diagnostics.push(item)
  }
  next_diagnostics.push(diagnostic)
  { ..annotation, diagnostics: next_diagnostics }
}
