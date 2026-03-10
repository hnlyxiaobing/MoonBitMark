// HTML Converter - Converts HTML files to Markdown (with URL support)

///|
/// Converter for HTML files
pub(all) struct HtmlConverter {
  dummy : Int
}

///|
/// Create a new HTML converter
pub fn HtmlConverter::new() -> HtmlConverter {
  HtmlConverter::{ dummy: 0 }
}

///|
/// Accepts function - checks if file is HTML
pub fn HtmlConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.mimetype {
    Some(mt) => {
      let mt_lower = mt.to_lower().to_string()
      mt_lower.has_prefix("text/html") ||
      mt_lower.has_prefix("application/xhtml")
    }
    None =>
      match info.extension {
        Some(ext) => {
          let ext_lower = ext.to_lower().to_string()
          ext_lower == ".html" || ext_lower == ".htm"
        }
        _ => false
      }
  }
}

///|
/// Convert function - converts HTML to Markdown (supports files and URLs)
pub async fn HtmlConverter::convert(input : String) -> String {
  // Check if input is a URL
  if input.has_prefix("http://") || input.has_prefix("https://") {
    convert_from_url(input)
  } else {
    convert_from_file(input)
  }
}

///|
/// Convert from URL
pub async fn convert_from_url(url : String) -> String {
  // Fetch HTML from URL using @http.get()
  let (response, data) = @http.get(url)

  // Check response status
  if response.code != 200 {
    fail("HTTP request failed with status code: " + response.code.to_string())
  }

  // Convert Data to String using .text() method (UTF-8 decoded)
  let html = data.text()

  // Convert to Markdown
  html_to_markdown(html)
}

///|
/// Convert from local file
pub async fn convert_from_file(file_path : String) -> String {
  let file = @fs.open(file_path, mode=ReadOnly)
  let mut content = ""
  while file.read_until("\n") is Some(line) {
    content = content + line + "\n"
  }
  file.close()

  html_to_markdown(content)
}

///|
/// Main HTML to Markdown conversion function
fn html_to_markdown(html : String) -> String raise {
  let mut result = html

  // Remove script and style blocks
  result = remove_tag_block(result, "script")
  result = remove_tag_block(result, "style")

  // Remove comments
  result = remove_comments(result)

  // Convert block elements
  result = convert_headings(result)
  result = convert_paragraphs(result)
  result = convert_line_breaks(result)
  result = convert_lists(result)
  result = convert_links(result)
  result = convert_images(result)
  result = convert_emphasis(result)
  result = convert_strong(result)
  result = convert_code(result)
  result = convert_blockquote(result)
  result = convert_pre(result)
  result = convert_tables(result)
  result = convert_divs(result)

  // Remove remaining HTML tags
  result = strip_remaining_tags(result)

  // Clean up whitespace
  result = cleanup_whitespace(result)

  result
}

// ============================================================================
// Helper functions
// ============================================================================

///|
/// Find substring from a starting position
fn find_from(haystack : String, needle : String, start : Int) -> Int? raise {
  if start >= haystack.length() {
    None
  } else {
    let substring = haystack[start:].to_string()
    match substring.find(needle[:]) {
      Some(pos) => Some(start + pos)
      None => None
    }
  }
}

///|
/// Remove script/style blocks with content
fn remove_tag_block(html : String, tag_name : String) -> String raise {
  let open_tag = "<" + tag_name
  let close_tag = "</" + tag_name
  let mut result = html
  let mut found = true

  while found {
    let lower_result = result.to_lower()
    match lower_result.find(open_tag[:]) {
      Some(start) =>
        match find_from(lower_result, close_tag, start) {
          Some(end_idx) => {
            let close_end = end_idx + close_tag.length()
            let before = result[:start].to_string()
            let after = result[close_end:].to_string()
            result = before + after
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
/// Remove HTML comments
fn remove_comments(html : String) -> String raise {
  let mut result = html
  let mut found = true

  while found {
    match result.find("<!--") {
      Some(idx) =>
        match find_from(result, "-->", idx) {
          Some(end_idx) => {
            let close_end = end_idx + 3
            let before = result[:idx].to_string()
            let after = result[close_end:].to_string()
            result = before + after
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
/// Convert headings (h1-h6)
fn convert_headings(html : String) -> String raise {
  let mut result = html

  for i in 1..<=6 {
    let tag = "h" + i.to_string()
    let open_pattern = "<" + tag
    let close_pattern = "</" + tag
    let mut found = true

    while found {
      let lower_result = result.to_lower()
      match lower_result.find(open_pattern[:]) {
        Some(idx) =>
          match find_from(result, ">", idx) {
            Some(tag_end_idx) => {
              let content_start = tag_end_idx + 1
              match find_from(lower_result, close_pattern, content_start) {
                Some(end_idx) => {
                  let prefix = "\n" + "#".repeat(i) + " "
                  let content = result[content_start:end_idx].to_string()
                  let before = result[:idx].to_string()
                  let after = result[end_idx + close_pattern.length():].to_string()
                  result = before + prefix + content + "\n" + after
                }
                None => found = false
              }
            }
            None => found = false
          }
        None => found = false
      }
    }
  }

  result
}

///|
/// Convert paragraphs
fn convert_paragraphs(html : String) -> String raise {
  let mut result = html
  let mut found = true

  while found {
    let lower_result = result.to_lower()
    match lower_result.find("<p") {
      Some(idx) =>
        match find_from(result, ">", idx) {
          Some(tag_end_idx) => {
            let content_start = tag_end_idx + 1
            match find_from(lower_result, "</p>", content_start) {
              Some(end_idx) => {
                let content = result[content_start:end_idx].to_string()
                let before = result[:idx].to_string()
                let after = result[end_idx + 4:].to_string()
                result = before + "\n\n" + content + "\n\n" + after
              }
              None => found = false
            }
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
/// Convert line breaks
fn convert_line_breaks(html : String) -> String raise {
  let mut result = html
  result = result.replace(old="<br>", new="\n")
  result = result.replace(old="<br/>", new="\n")
  result = result.replace(old="<br />", new="\n")
  result
}

///|
/// Convert lists (ul, ol, li)
fn convert_lists(html : String) -> String raise {
  let mut result = html
  result = convert_ul(result)
  result = convert_ol(result)
  result
}

///|
fn convert_ul(html : String) -> String raise {
  let mut result = html
  let mut found = true

  while found {
    let lower_result = result.to_lower()
    match lower_result.find("<ul") {
      Some(idx) =>
        match find_from(result, ">", idx) {
          Some(tag_end_idx) => {
            let content_start = tag_end_idx + 1
            match find_from(lower_result, "</ul>", content_start) {
              Some(end_idx) => {
                let list_content = result[content_start:end_idx].to_string()
                let converted = convert_li(list_content, "-")
                let before = result[:idx].to_string()
                let after = result[end_idx + 5:].to_string()
                result = before + "\n" + converted + "\n" + after
              }
              None => found = false
            }
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
fn convert_ol(html : String) -> String raise {
  let mut result = html
  let mut found = true
  let mut counter = 1

  while found {
    let lower_result = result.to_lower()
    match lower_result.find("<ol") {
      Some(idx) =>
        match find_from(result, ">", idx) {
          Some(tag_end_idx) => {
            let content_start = tag_end_idx + 1
            match find_from(lower_result, "</ol>", content_start) {
              Some(end_idx) => {
                let list_content = result[content_start:end_idx].to_string()
                let converted = convert_li_ordered(list_content)
                let before = result[:idx].to_string()
                let after = result[end_idx + 5:].to_string()
                result = before + "\n" + converted + "\n" + after
              }
              None => found = false
            }
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
fn convert_li(html : String, prefix : String) -> String raise {
  let mut result = html
  let mut found = true

  while found {
    let lower_result = result.to_lower()
    match lower_result.find("<li") {
      Some(idx) =>
        match find_from(result, ">", idx) {
          Some(tag_end_idx) => {
            let content_start = tag_end_idx + 1
            match find_from(lower_result, "</li>", content_start) {
              Some(end_idx) => {
                let content = result[content_start:end_idx]
                  .to_string()
                  .trim()
                  .to_string()
                let before = result[:idx].to_string()
                let after = result[end_idx + 5:].to_string()
                result = before + "\n" + prefix + " " + content + after
              }
              None => found = false
            }
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
fn convert_li_ordered(html : String) -> String raise {
  let mut result = html
  let mut found = true
  let mut counter = 1

  while found {
    let lower_result = result.to_lower()
    match lower_result.find("<li") {
      Some(idx) =>
        match find_from(result, ">", idx) {
          Some(tag_end_idx) => {
            let content_start = tag_end_idx + 1
            match find_from(lower_result, "</li>", content_start) {
              Some(end_idx) => {
                let content = result[content_start:end_idx]
                  .to_string()
                  .trim()
                  .to_string()
                let prefix = counter.to_string() + ". "
                counter = counter + 1
                let before = result[:idx].to_string()
                let after = result[end_idx + 5:].to_string()
                result = before + "\n" + prefix + content + after
              }
              None => found = false
            }
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
/// Convert links
fn convert_links(html : String) -> String raise {
  let mut result = html
  let mut found = true

  while found {
    let lower_result = result.to_lower()
    match lower_result.find("<a ") {
      Some(idx) =>
        match find_from(result, ">", idx) {
          Some(tag_end_idx) => {
            let tag_content = result[idx:tag_end_idx + 1].to_string()
            let href = extract_attribute(tag_content, "href")
            let content_start = tag_end_idx + 1
            match find_from(lower_result, "</a>", content_start) {
              Some(end_idx) => {
                let link_text = result[content_start:end_idx].to_string()
                let markdown_link = if href != "" {
                  "[" + link_text + "](" + href + ")"
                } else {
                  link_text
                }
                let before = result[:idx].to_string()
                let after = result[end_idx + 4:].to_string()
                result = before + markdown_link + after
              }
              None => found = false
            }
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
/// Convert images
fn convert_images(html : String) -> String raise {
  let mut result = html
  let mut found = true

  while found {
    let lower_result = result.to_lower()
    match lower_result.find("<img") {
      Some(idx) =>
        match find_from(result, ">", idx) {
          Some(tag_end_idx) => {
            let tag_content = result[idx:tag_end_idx + 1].to_string()
            let src = extract_attribute(tag_content, "src")
            let alt = extract_attribute(tag_content, "alt")
            let title = extract_attribute(tag_content, "title")

            let mut img_markdown = "!" + "[" + alt + "](" + src
            if title != "" {
              img_markdown = img_markdown + " \"" + title + "\""
            }
            img_markdown = img_markdown + ")"

            let before = result[:idx].to_string()
            let after = result[tag_end_idx + 1:].to_string()
            result = before + img_markdown + after
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
/// Convert emphasis (italic)
fn convert_emphasis(html : String) -> String raise {
  let mut result = html
  result = convert_em_tag(result, "<em>", "</em>")
  result = convert_em_tag(result, "<i>", "</i>")
  result
}

///|
fn convert_em_tag(html : String, open : String, close : String) -> String raise {
  let mut result = html
  let mut found = true

  while found {
    let lower_result = result.to_lower()
    match lower_result.find(open[:]) {
      Some(idx) =>
        match find_from(lower_result, close, idx) {
          Some(end_idx) => {
            let content = result[idx + open.length():end_idx].to_string()
            let before = result[:idx].to_string()
            let after = result[end_idx + close.length():].to_string()
            result = before + "*" + content + "*" + after
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
/// Convert strong (bold)
fn convert_strong(html : String) -> String raise {
  let mut result = html
  result = convert_em_tag(result, "<strong>", "</strong>")
  result = convert_em_tag(result, "<b>", "</b>")
  result
}

///|
/// Convert code
fn convert_code(html : String) -> String raise {
  let mut result = html
  let mut found = true

  while found {
    let lower_result = result.to_lower()
    match lower_result.find("<code>") {
      Some(idx) =>
        match find_from(lower_result, "</code>", idx) {
          Some(end_idx) => {
            let content = result[idx + 7:end_idx].to_string()
            let before = result[:idx].to_string()
            let after = result[end_idx + 8:].to_string()
            result = before + "`" + content + "`" + after
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
/// Convert blockquote
fn convert_blockquote(html : String) -> String raise {
  let mut result = html
  let mut found = true

  while found {
    let lower_result = result.to_lower()
    match lower_result.find("<blockquote>") {
      Some(idx) =>
        match find_from(lower_result, "</blockquote>", idx) {
          Some(end_idx) => {
            let content = result[idx + 13:end_idx]
              .to_string()
              .trim()
              .to_string()
            let lines = content.split("\n")
            let lines_array = lines.to_array()
            let quoted_lines : Array[String] = Array::new()
            for line in lines_array {
              quoted_lines.push("> " + line.to_string())
            }
            let quoted = quoted_lines.join("\n")
            let before = result[:idx].to_string()
            let after = result[end_idx + 14:].to_string()
            result = before + "\n" + quoted + "\n\n" + after
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
/// Convert pre (code blocks)
fn convert_pre(html : String) -> String raise {
  let mut result = html
  let mut found = true

  while found {
    let lower_result = result.to_lower()
    match lower_result.find("<pre>") {
      Some(idx) =>
        match find_from(lower_result, "</pre>", idx) {
          Some(end_idx) => {
            let content = result[idx + 5:end_idx].to_string()
            let bt = "\u{0060}"
            let triple_bt = bt + bt + bt
            let before = result[:idx].to_string()
            let after = result[end_idx + 7:].to_string()
            result = before +
              "\n" +
              triple_bt +
              "\n" +
              content +
              "\n" +
              triple_bt +
              "\n" +
              after
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
/// Convert tables
fn convert_tables(html : String) -> String raise {
  let mut result = html
  let mut found = true

  while found {
    let lower_result = result.to_lower()
    match lower_result.find("<table>") {
      Some(idx) =>
        match find_from(lower_result, "</table>", idx) {
          Some(end_idx) => {
            let table_content = result[idx + 7:end_idx].to_string()
            let markdown_table = convert_table_content(table_content)
            let before = result[:idx].to_string()
            let after = result[end_idx + 9:].to_string()
            result = before + "\n" + markdown_table + "\n" + after
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
fn convert_table_content(table_html : String) -> String raise {
  let mut result = ""
  let mut header_done = false
  let mut remaining = table_html
  let mut found = true

  while found {
    let lower_remaining = remaining.to_lower()
    match lower_remaining.find("<tr>") {
      Some(idx) =>
        match find_from(lower_remaining, "</tr>", idx) {
          Some(tr_end) => {
            let row_content = remaining[idx + 4:tr_end].to_string()
            let cells = extract_table_cells(row_content)

            if cells.length() > 0 {
              if !header_done {
                // Header row
                result = result + "| " + cells.join(" | ") + " |\n"
                let separators : Array[String] = Array::new()
                for _ in 0..<cells.length() {
                  separators.push("---")
                }
                result = result + "| " + separators.join(" | ") + " |\n"
                header_done = true
              } else {
                // Data row
                result = result + "| " + cells.join(" | ") + " |\n"
              }
            }

            remaining = remaining[tr_end + 5:].to_string()
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
fn extract_table_cells(row_html : String) -> Array[String] raise {
  let cells : Array[String] = Array::new()

  // Try th first, then td
  let th_cells = extract_cells_by_tag(row_html, "th")
  if th_cells.length() > 0 {
    th_cells
  } else {
    extract_cells_by_tag(row_html, "td")
  }
}

///|
fn extract_cells_by_tag(html : String, tag : String) -> Array[String] raise {
  let cells : Array[String] = Array::new()
  let open_tag = "<" + tag
  let close_tag = "</" + tag
  let mut remaining = html
  let mut found = true

  while found {
    let lower_remaining = remaining.to_lower()
    match lower_remaining.find(open_tag[:]) {
      Some(idx) =>
        match find_from(remaining, ">", idx) {
          Some(tag_end_idx) => {
            let content_start = tag_end_idx + 1
            match find_from(lower_remaining, close_tag, content_start) {
              Some(end_idx) => {
                let content = remaining[content_start:end_idx]
                  .to_string()
                  .trim()
                  .to_string()
                cells.push(content)
                remaining = remaining[end_idx + close_tag.length():].to_string()
              }
              None => found = false
            }
          }
          None => found = false
        }
      None => found = false
    }
  }

  cells
}

///|
/// Convert divs to line breaks
fn convert_divs(html : String) -> String raise {
  let mut result = html
  result = result.replace(old="<div>", new="\n")
  result = result.replace(old="</div>", new="\n")
  result
}

///|
/// Strip remaining HTML tags
fn strip_remaining_tags(html : String) -> String raise {
  let mut result = html
  let mut found = true

  while found {
    match result.find("<") {
      Some(idx) =>
        match find_from(result, ">", idx) {
          Some(end_idx) => {
            let before = result[:idx].to_string()
            let after = result[end_idx + 1:].to_string()
            result = before + after
          }
          None => found = false
        }
      None => found = false
    }
  }

  result
}

///|
/// Clean up whitespace
fn cleanup_whitespace(html : String) -> String raise {
  let mut result = html

  // Replace multiple newlines with double newline
  result = result.replace(old="\n\n\n", new="\n\n")
  result = result.replace(old="\n\n\n", new="\n\n")
  result = result.replace(old="\n\n\n", new="\n\n")

  result.trim().to_string()
}

///|
/// Extract attribute value from HTML tag
fn extract_attribute(tag : String, attr_name : String) -> String raise {
  let attr_pattern = attr_name + "=\""
  let attr_pattern_single = attr_name + "='"

  match tag.find(attr_pattern[:]) {
    Some(idx) => {
      let start = idx + attr_pattern.length()
      let remaining = tag[start:].to_string()
      match remaining.find("\"") {
        Some(end) => remaining[:end].to_string()
        None => ""
      }
    }
    None =>
      match tag.find(attr_pattern_single[:]) {
        Some(idx) => {
          let start = idx + attr_pattern_single.length()
          let remaining = tag[start:].to_string()
          match remaining.find("'") {
            Some(end) => remaining[:end].to_string()
            None => ""
          }
        }
        None => ""
      }
  }
}
