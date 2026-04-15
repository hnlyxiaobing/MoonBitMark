///|
pub fn document_of_markdownish(
  markdown : String,
  title : String?,
  metadata : Map[String, String],
) -> Document {
  let blocks : Array[Block] = []
  for chunk in markdown.split("\n\n").to_array() {
    let trimmed = chunk.trim().to_string()
    if trimmed == "" {
      continue
    }
    blocks.push(parse_markdownish_block(trimmed))
  }
  document(title, metadata, blocks)
}

///|
pub fn parse_markdownish_block(chunk : String) -> Block {
  if chunk.has_prefix("```") {
    parse_code_block(chunk)
  } else if chunk.has_prefix("#") {
    parse_heading_block(chunk)
  } else if is_quote_block(chunk) {
    parse_quote_block(chunk)
  } else if is_table_block(chunk) {
    parse_table_block(chunk)
  } else if is_list_block(chunk) {
    parse_list_block(chunk)
  } else if chunk == "---" {
    HorizontalRule
  } else {
    text_paragraph(chunk)
  }
}

///|
fn parse_heading_block(chunk : String) -> Block {
  let mut level = 0
  let mut index = 0
  for ch in chunk {
    if ch == '#' {
      level = level + 1
      index = index + 1
    } else {
      break
    }
  }
  let text = chunk[index:].trim().to_string()
  Heading(level, text_inlines(text))
}

///|
fn parse_code_block(chunk : String) -> Block {
  let lines = chunk.split("\n").to_array()
  if lines.length() == 0 {
    return CodeBlock(None, "")
  }
  let header = lines[0].trim().to_string()
  let lang = if header.length() > 3 {
    Some(header[3:].trim().to_string())
  } else {
    None
  }
  let content_lines : Array[String] = []
  let mut index = 1
  while index < lines.length() - 1 {
    content_lines.push(lines[index].to_string())
    index = index + 1
  }
  CodeBlock(lang, content_lines.join("\n"))
}

///|
fn is_quote_block(chunk : String) -> Bool {
  for line in chunk.split("\n").to_array() {
    if line.trim() != "" && !line.trim_start().has_prefix("> ") {
      return false
    }
  }
  true
}

///|
fn parse_quote_block(chunk : String) -> Block {
  let lines : Array[String] = []
  for line in chunk.split("\n").to_array() {
    let trimmed = line.trim_start().to_string()
    if trimmed.has_prefix("> ") {
      lines.push(trimmed[2:].to_string())
    }
  }
  Quote(lines)
}

///|
fn is_list_block(chunk : String) -> Bool {
  let lines = chunk.split("\n").to_array()
  if lines.length() == 0 {
    return false
  }
  for line in lines {
    let trimmed = line.trim_start().to_string()
    if trimmed == "" {
      continue
    }
    if trimmed.has_prefix("- ") {
      continue
    }
    if ordered_list_prefix_length(trimmed) is Some(_) {
      continue
    }
    return false
  }
  true
}

///|
fn parse_list_block(chunk : String) -> Block {
  let items : Array[Array[Inline]] = []
  let lines = chunk.split("\n").to_array()
  let mut ordered = false
  for line in lines {
    let trimmed = line.trim_start().to_string()
    if trimmed.has_prefix("- ") {
      items.push(text_inlines(trimmed[2:].to_string()))
    } else {
      match ordered_list_prefix_length(trimmed) {
        Some(prefix_len) => {
          ordered = true
          items.push(text_inlines(trimmed[prefix_len:].to_string()))
        }
        None => ()
      }
    }
  }
  List(items, ordered)
}

///|
fn ordered_list_prefix_length(line : String) -> Int? {
  let mut digits = 0
  let mut index = 0
  for ch in line {
    if ch >= '0' && ch <= '9' {
      digits = digits + 1
      index = index + 1
      continue
    }
    if digits > 0 && ch == '.' {
      if index + 1 < line.length() && line[index + 1] == ' ' {
        return Some(index + 2)
      }
    }
    break
  }
  None
}

///|
fn is_table_block(chunk : String) -> Bool {
  let lines = chunk.split("\n").to_array()
  lines.length() >= 2 && lines[0].contains("|") && lines[1].contains("---")
}

///|
fn parse_table_block(chunk : String) -> Block {
  let lines = chunk.split("\n").to_array()
  let headers = split_table_row(lines[0].to_string())
  let rows : Array[Array[Array[Inline]]] = []
  let mut index = 2
  while index < lines.length() {
    let row = split_table_row(lines[index].to_string())
    if row.length() > 0 {
      rows.push(row)
    }
    index = index + 1
  }
  Table(headers, rows)
}

///|
fn split_table_row(line : String) -> Array[Array[Inline]] {
  let trimmed = line.trim().to_string()
  let without_left = if trimmed.has_prefix("|") {
    trimmed[1:].to_string()
  } else {
    trimmed
  }
  let content = if without_left.has_suffix("|") {
    without_left[:without_left.length() - 1].to_string()
  } else {
    without_left
  }
  let cells : Array[Array[Inline]] = []
  for cell in content.split("|").to_array() {
    cells.push(text_inlines(cell.trim().to_string()))
  }
  cells
}
