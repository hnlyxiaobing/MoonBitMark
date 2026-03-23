///|
pub fn render_markdown(doc : Document) -> String {
  let rendered : Array[String] = []
  for block in doc.blocks {
    rendered.push(render_block(block))
  }
  rendered.filter(part => part != "").join("\n\n").trim().to_string()
}

///|
fn render_block(block : Block) -> String {
  match block {
    Heading(level, inlines) => "#".repeat(level) + " " + render_inlines(inlines)
    Paragraph(inlines) => render_inlines(inlines)
    List(items, ordered) => render_list(items, ordered)
    Quote(lines) => lines.map(line => "> " + line).join("\n")
    CodeBlock(lang, content) => render_code_block(lang, content)
    Table(headers, rows) => render_table(headers, rows)
    HorizontalRule => "---"
  }
}

///|
pub fn render_inlines(inlines : Array[Inline]) -> String {
  let parts : Array[String] = []
  for inline in inlines {
    parts.push(render_inline(inline))
  }
  parts.join("")
}

///|
fn render_inline(inline : Inline) -> String {
  match inline {
    Text(text) => escape_markdown_text(text)
    Emphasis(children) => "*" + render_inlines(children) + "*"
    Strong(children) => "**" + render_inlines(children) + "**"
    Link(children, href) => "[" + render_inlines(children) + "](" + href + ")"
    Image(alt, src) => "![" + escape_link_label(alt) + "](" + src + ")"
    Code(content) => render_inline_code(content)
    LineBreak => "  \n"
  }
}

///|
fn render_list(items : Array[String], ordered : Bool) -> String {
  let lines : Array[String] = []
  let mut index = 1
  for item in items {
    if ordered {
      lines.push(index.to_string() + ". " + item)
    } else {
      lines.push("- " + item)
    }
    index = index + 1
  }
  lines.join("\n")
}

///|
fn render_code_block(lang : String?, content : String) -> String {
  let bt = "\u{0060}"
  let triple_bt = bt + bt + bt
  match lang {
    Some(name) if name != "" =>
      triple_bt + " " + name + "\n" + content + "\n" + triple_bt
    _ => triple_bt + "\n" + content + "\n" + triple_bt
  }
}

///|
fn render_table(headers : Array[String], rows : Array[Array[String]]) -> String {
  if headers.length() == 0 {
    return ""
  }
  let width = table_width(headers, rows)
  let lines : Array[String] = []
  lines.push(render_table_row(headers, width))
  lines.push("| " + Array::make(width, "---").join(" | ") + " |")
  for row in rows {
    lines.push(render_table_row(row, width))
  }
  lines.join("\n")
}

///|
fn table_width(headers : Array[String], rows : Array[Array[String]]) -> Int {
  let mut width = headers.length()
  for row in rows {
    if row.length() > width {
      width = row.length()
    }
  }
  width
}

///|
fn render_table_row(cells : Array[String], width : Int) -> String {
  let normalized = normalize_table_row(cells, width)
  "| " + normalized.map(cell => escape_table_cell(cell)).join(" | ") + " |"
}

///|
fn normalize_table_row(cells : Array[String], width : Int) -> Array[String] {
  let normalized : Array[String] = []
  let mut index = 0
  while index < width {
    normalized.push(if index < cells.length() { cells[index] } else { "" })
    index = index + 1
  }
  normalized
}

///|
fn escape_table_cell(cell : String) -> String {
  cell
  .replace(old="|", new="\\|")
  .replace(old="\r\n", new="<br>")
  .replace(old="\r", new="<br>")
  .replace(old="\n", new="<br>")
}

///|
fn render_inline_code(content : String) -> String {
  let ticks = if content.contains("`") { "``" } else { "`" }
  ticks + content + ticks
}

///|
fn escape_markdown_text(text : String) -> String {
  text
}

///|
fn escape_link_label(text : String) -> String {
  text.replace(old="]", new="\\]")
}
