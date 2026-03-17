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
pub async fn HtmlConverter::convert(input : String) -> @core.ConvertResult {
  // Check if input is a URL
  let (html, source_label) = if input.has_prefix("http://") ||
    input.has_prefix("https://") {
    (convert_from_url(input), "url")
  } else {
    (convert_from_file(input), "file")
  }
  let title = extract_title(html)
  let cleaned_html = preprocess_html(html)
  let doc = html_to_document(cleaned_html, title)
  let rendered_markdown = @ast.render_markdown(doc)
  let metadata = Map::new()
  metadata["format"] = "html"
  metadata["html_source"] = source_label
  let warnings = collect_html_warnings(html)
  @core.ConvertResult::markdown_only(rendered_markdown, "html")
  .with_title(title)
  .with_metadata(metadata)
  .with_warnings(warnings)
  .with_stats(Some(@core.stats_for_markdown(rendered_markdown)))
}

///|
fn preprocess_html(html : String) -> String raise {
  let mut result = html
  result = remove_tag_block(result, "script")
  result = remove_tag_block(result, "style")
  remove_comments(result)
}

///|
fn html_to_document(html : String, title : String?) -> @ast.Document raise {
  let blocks : Array[@ast.Block] = []
  let body = extract_body_html(html)
  let mut remaining = body
  while remaining.trim() != "" {
    let trimmed = remaining.trim_start().to_string()
    remaining = trimmed
    match parse_next_html_block(remaining) {
      Some((block, rest)) => {
        blocks.push(block)
        remaining = rest
      }
      None => {
        let paragraph = plain_text_fragment(remaining)
        if paragraph != "" {
          blocks.push(@ast.text_paragraph(paragraph))
        }
        remaining = ""
      }
    }
  }
  @ast.Document::{ title, metadata: {}, blocks }
}

///|
fn extract_body_html(html : String) -> String raise {
  let lower = html.to_lower()
  match lower.find("<body") {
    Some(start) =>
      match find_from(html, ">", start) {
        Some(open_end) =>
          match find_from(lower, "</body>", open_end + 1) {
            Some(close_start) => html[open_end + 1:close_start].to_string()
            None => html
          }
        None => html
      }
    None => html
  }
}

///|
fn parse_next_html_block(html : String) -> (@ast.Block, String)? raise {
  if html == "" {
    return None
  }
  if html.has_prefix("<h1") {
    return parse_heading_html_block(html, 1)
  }
  if html.has_prefix("<h2") {
    return parse_heading_html_block(html, 2)
  }
  if html.has_prefix("<h3") {
    return parse_heading_html_block(html, 3)
  }
  if html.has_prefix("<h4") {
    return parse_heading_html_block(html, 4)
  }
  if html.has_prefix("<h5") {
    return parse_heading_html_block(html, 5)
  }
  if html.has_prefix("<h6") {
    return parse_heading_html_block(html, 6)
  }
  if html.has_prefix("<p") {
    return parse_wrapped_block(html, "p", content => {
      @ast.text_paragraph(content)
    })
  }
  if html.has_prefix("<blockquote") {
    return parse_wrapped_block(html, "blockquote", content => {
      @ast.Quote(content.split("\n").to_array().map(line => line.to_string()))
    })
  }
  if html.has_prefix("<pre") {
    return parse_wrapped_block(html, "pre", content => {
      @ast.CodeBlock(None, content)
    })
  }
  if html.has_prefix("<ul") {
    return parse_list_html_block(html, false)
  }
  if html.has_prefix("<ol") {
    return parse_list_html_block(html, true)
  }
  if html.has_prefix("<table") {
    return parse_table_html_block(html)
  }
  if html.has_prefix("<hr") {
    let rest = match find_from(html, ">", 0) {
      Some(end) => html[end + 1:].to_string()
      None => ""
    }
    return Some((@ast.HorizontalRule, rest))
  }
  if html.has_prefix("<div") {
    return parse_wrapped_block(html, "div", content => {
      @ast.text_paragraph(content)
    })
  }
  None
}

///|
fn parse_heading_html_block(
  html : String,
  level : Int,
) -> (@ast.Block, String)? raise {
  let tag = "h" + level.to_string()
  match take_tag_inner_html(html, tag) {
    Some((inner, rest)) =>
      Some((@ast.Heading(level, inline_html_to_text(inner)), rest))
    None => None
  }
}

///|
fn parse_wrapped_block(
  html : String,
  tag : String,
  build : (String) -> @ast.Block,
) -> (@ast.Block, String)? raise {
  match take_tag_inner_html(html, tag) {
    Some((inner, rest)) => {
      let content = inline_html_to_text(inner)
      Some((build(content), rest))
    }
    None => None
  }
}

///|
fn parse_list_html_block(
  html : String,
  ordered : Bool,
) -> (@ast.Block, String)? raise {
  let tag = if ordered { "ol" } else { "ul" }
  match take_tag_inner_html(html, tag) {
    Some((inner, rest)) => {
      let items = extract_list_items(inner)
      Some((@ast.List(items, ordered), rest))
    }
    None => None
  }
}

///|
fn parse_table_html_block(html : String) -> (@ast.Block, String)? raise {
  match take_tag_inner_html(html, "table") {
    Some((inner, rest)) => {
      let rows = extract_table_rows(inner)
      match rows {
        [header, .. tail] => Some((@ast.Table(header, tail.to_array()), rest))
        [] => Some((@ast.Table([], []), rest))
      }
    }
    None => None
  }
}

///|
fn take_tag_inner_html(html : String, tag : String) -> (String, String)? raise {
  let open = "<" + tag
  let close = "</" + tag + ">"
  match find_from(html.to_lower(), open, 0) {
    Some(start) if start == 0 =>
      match find_from(html, ">", start) {
        Some(open_end) =>
          match find_from(html.to_lower(), close, open_end + 1) {
            Some(close_start) => {
              let inner = html[open_end + 1:close_start].to_string()
              let rest = html[close_start + close.length():].to_string()
              Some((inner, rest))
            }
            None => None
          }
        None => None
      }
    _ => None
  }
}

///|
fn extract_list_items(inner : String) -> Array[String] raise {
  let items : Array[String] = []
  let mut remaining = inner
  while remaining.trim() != "" {
    let lower = remaining.to_lower()
    match lower.find("<li") {
      Some(start) =>
        match find_from(remaining, ">", start) {
          Some(open_end) =>
            match find_from(lower, "</li>", open_end + 1) {
              Some(close_start) => {
                let item = remaining[open_end + 1:close_start].to_string()
                items.push(inline_html_to_text(item))
                remaining = remaining[close_start + 5:].to_string()
              }
              None => break
            }
          None => break
        }
      None => break
    }
  }
  items
}

///|
fn extract_table_rows(inner : String) -> Array[Array[String]] raise {
  let rows : Array[Array[String]] = []
  let mut remaining = inner
  while remaining.trim() != "" {
    let lower = remaining.to_lower()
    match lower.find("<tr") {
      Some(start) =>
        match find_from(remaining, ">", start) {
          Some(open_end) =>
            match find_from(lower, "</tr>", open_end + 1) {
              Some(close_start) => {
                let row_html = remaining[open_end + 1:close_start].to_string()
                rows.push(extract_table_cells(row_html))
                remaining = remaining[close_start + 5:].to_string()
              }
              None => break
            }
          None => break
        }
      None => break
    }
  }
  rows
}

///|
fn inline_html_to_text(fragment : String) -> String raise {
  let mut result = fragment
  result = convert_line_breaks(result)
  result = convert_links(result)
  result = convert_images(result)
  result = convert_emphasis(result)
  result = convert_strong(result)
  result = convert_code(result)
  result = strip_remaining_tags(result)
  cleanup_whitespace(result)
}

///|
fn plain_text_fragment(fragment : String) -> String raise {
  inline_html_to_text(fragment)
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
  html
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

  content
}

///|
fn extract_title(html : String) -> String? raise {
  let lower = html.to_lower()
  match lower.find("<title") {
    Some(start) =>
      match find_from(html, ">", start) {
        Some(tag_end) =>
          match find_from(lower, "</title>", tag_end + 1) {
            Some(close_start) => {
              let title = html[tag_end + 1:close_start]
                .to_string()
                .trim()
                .to_string()
              if title == "" {
                None
              } else {
                Some(title)
              }
            }
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
fn collect_html_warnings(html : String) -> Array[String] {
  let warnings : Array[String] = []
  let lower = html.to_lower()
  if lower.contains("<script") {
    warnings.push("Dropped <script> blocks during HTML conversion.")
  }
  if lower.contains("<style") {
    warnings.push("Dropped <style> blocks during HTML conversion.")
  }
  warnings
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
/// Convert line breaks
fn convert_line_breaks(html : String) -> String raise {
  let mut result = html
  result = result.replace(old="<br>", new="\n")
  result = result.replace(old="<br/>", new="\n")
  result = result.replace(old="<br />", new="\n")
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
fn extract_table_cells(row_html : String) -> Array[String] raise {
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
