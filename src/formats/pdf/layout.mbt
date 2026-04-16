///|
fn parse_pdf_layout_json(layout_json : String?) -> Array[PdfLayoutPage] {
  match layout_json {
    Some(raw) if raw.trim() != "" => {
      let parsed_result : Result[PdfLayoutPayload, Error] = try {
        let parsed_json = @json.parse(raw)
        let payload : PdfLayoutPayload = @json.from_json(parsed_json)
        Ok(payload)
      } catch {
        err => Err(err)
      }
      match parsed_result {
        Ok(payload) => payload.pages
        Err(_) => []
      }
    }
    _ => []
  }
}

///|
fn page_layout_at(
  layouts : Array[PdfLayoutPage],
  page_no : Int,
) -> PdfLayoutPage? {
  for layout in layouts {
    if layout.page_no == page_no {
      return Some(layout)
    }
  }
  None
}

///|
fn layout_page_to_chunks(layout : PdfLayoutPage) -> Array[String] {
  let ordered_lines = layout_lines_in_reading_order(layout)
  let chunks : Array[String] = []
  let mut previous : PdfLayoutLine? = None
  for line in ordered_lines {
    let text = collapse_inline_whitespace(line.text)
    if text == "" {
      continue
    }
    match previous {
      Some(existing) =>
        if layout_lines_switch_column(existing, line, layout) ||
          line.top - existing.bottom >= 32 {
          if chunks.length() > 0 && chunks[chunks.length() - 1] != "" {
            chunks.push("")
          }
        }
      None => ()
    }
    chunks.push(text)
    previous = Some(line)
  }
  chunks
}

///|
fn layout_lines_in_reading_order(
  layout : PdfLayoutPage,
) -> Array[PdfLayoutLine] {
  let lines : Array[PdfLayoutLine] = []
  for line in layout.lines {
    if collapse_inline_whitespace(line.text) != "" {
      insert_layout_line_sorted(lines, line, false)
    }
  }

  match detect_layout_column_split(lines) {
    Some(split) => reorder_layout_lines_by_columns(lines, split, layout.width)
    None => lines
  }
}

///|
fn detect_layout_column_split(lines : Array[PdfLayoutLine]) -> Int? {
  if lines.length() < 4 {
    return None
  }
  let sorted = copy_layout_lines(lines)

  let mut best_gap = 0
  let mut best_split = -1
  let mut index = 0
  while index + 1 < sorted.length() {
    let gap = sorted[index + 1].left - sorted[index].right
    if gap >= 120 {
      let split = sorted[index].right + gap / 2
      let left_count = count_layout_lines_on_side(lines, split, true)
      let right_count = count_layout_lines_on_side(lines, split, false)
      if left_count >= 2 && right_count >= 2 && gap > best_gap {
        best_gap = gap
        best_split = split
      }
    }
    index = index + 1
  }

  if best_split >= 0 {
    Some(best_split)
  } else {
    None
  }
}

///|
fn reorder_layout_lines_by_columns(
  lines : Array[PdfLayoutLine],
  split : Int,
  page_width : Int,
) -> Array[PdfLayoutLine] {
  let preamble : Array[PdfLayoutLine] = []
  let left : Array[PdfLayoutLine] = []
  let right : Array[PdfLayoutLine] = []
  let trailer : Array[PdfLayoutLine] = []
  let mut column_start_top = 1001

  for line in lines {
    if !layout_line_crosses_split(line, split, page_width) {
      if line.top < column_start_top {
        column_start_top = line.top
      }
    }
  }

  for line in lines {
    if layout_line_crosses_split(line, split, page_width) {
      if line.top < column_start_top {
        preamble.push(line)
      } else {
        trailer.push(line)
      }
      continue
    }
    if layout_line_center(line) <= split {
      left.push(line)
    } else {
      right.push(line)
    }
  }

  let ordered : Array[PdfLayoutLine] = []
  for group in [preamble, left, right, trailer] {
    for line in group {
      ordered.push(line)
    }
  }
  ordered
}

///|
fn count_layout_lines_on_side(
  lines : Array[PdfLayoutLine],
  split : Int,
  left_side : Bool,
) -> Int {
  let mut count = 0
  for line in lines {
    if layout_line_crosses_split(line, split, 1000) {
      continue
    }
    if left_side && layout_line_center(line) <= split {
      count = count + 1
    }
    if !left_side && layout_line_center(line) > split {
      count = count + 1
    }
  }
  count
}

///|
fn layout_line_center(line : PdfLayoutLine) -> Int {
  line.left + (line.right - line.left) / 2
}

///|
fn layout_line_crosses_split(
  line : PdfLayoutLine,
  split : Int,
  page_width : Int,
) -> Bool {
  (line.left < split && line.right > split) ||
  line.right - line.left >= page_width * 6 / 10
}

///|
fn layout_lines_switch_column(
  left : PdfLayoutLine,
  right : PdfLayoutLine,
  layout : PdfLayoutPage,
) -> Bool {
  match detect_layout_column_split(layout.lines) {
    Some(split) =>
      !layout_line_crosses_split(left, split, layout.width) &&
      !layout_line_crosses_split(right, split, layout.width) &&
      (
        (layout_line_center(left) <= split && layout_line_center(right) > split) ||
        (layout_line_center(left) > split && layout_line_center(right) <= split)
      )
    None => false
  }
}

///|
fn copy_layout_lines(lines : Array[PdfLayoutLine]) -> Array[PdfLayoutLine] {
  let copied : Array[PdfLayoutLine] = []
  for line in lines {
    insert_layout_line_sorted(copied, line, true)
  }
  copied
}

///|
fn insert_layout_line_sorted(
  lines : Array[PdfLayoutLine],
  line : PdfLayoutLine,
  by_left : Bool,
) -> Unit {
  let mut index = 0
  while index < lines.length() &&
        compare_layout_lines(lines[index], line, by_left) <= 0 {
    index = index + 1
  }
  lines.insert(index, line)
}

///|
fn compare_layout_lines(
  left : PdfLayoutLine,
  right : PdfLayoutLine,
  by_left : Bool,
) -> Int {
  if by_left {
    if left.left == right.left {
      left.top - right.top
    } else {
      left.left - right.left
    }
  } else if left.top == right.top {
    left.left - right.left
  } else {
    left.top - right.top
  }
}
