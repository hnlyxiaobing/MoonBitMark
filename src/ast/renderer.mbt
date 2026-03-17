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
    Heading(level, text) => "#".repeat(level) + " " + text
    Paragraph(inlines) => render_inlines(inlines)
    List(items, ordered) => render_list(items, ordered)
    Quote(lines) => lines.map(line => "> " + line).join("\n")
    CodeBlock(lang, content) => render_code_block(lang, content)
    Table(headers, rows) => render_table(headers, rows)
    HorizontalRule => "---"
  }
}

///|
fn render_inlines(inlines : Array[Inline]) -> String {
  let parts : Array[String] = []
  for inline in inlines {
    match inline {
      Text(text) => parts.push(text)
    }
  }
  parts.join("")
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
      triple_bt +
      "\n" +
      content +
      "\n" +
      triple_bt.replace(old=triple_bt + "\n", new=triple_bt + " " + name + "\n")
    _ => triple_bt + "\n" + content + "\n" + triple_bt
  }
}

///|
fn render_table(headers : Array[String], rows : Array[Array[String]]) -> String {
  if headers.length() == 0 {
    return ""
  }
  let lines : Array[String] = []
  lines.push("| " + headers.join(" | ") + " |")
  lines.push("| " + Array::make(headers.length(), "---").join(" | ") + " |")
  for row in rows {
    lines.push("| " + row.join(" | ") + " |")
  }
  lines.join("\n")
}
