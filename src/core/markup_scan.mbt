// Shared tag-scanning helpers for the hand-rolled HTML/EPUB fallback scanners.
// The SAX parser in src/xml already handles quoted `>` correctly; these helpers
// give the string-scanning converters the same robustness (quoted `>` inside a
// tag, and tag-name boundaries) without adopting the XML event model.

///|
/// Index of the `>` that closes the tag opened at `lt_index` (`text[lt_index]`
/// is expected to be `<`), skipping any `>` that appears inside a `"`/`'`
/// quoted attribute value. Returns `None` when the tag is unterminated.
pub fn find_tag_close(text : String, lt_index : Int32) -> Int32? {
  if lt_index < 0 || lt_index >= text.length() {
    return None
  }
  let mut index = lt_index + 1
  let mut quote : UInt16 = 0
  while index < text.length() {
    let ch = text[index]
    if quote != 0 {
      if ch == quote {
        quote = 0
      }
    } else if ch == '"' || ch == '\'' {
      quote = ch
    } else if ch == '>' {
      return Some(index)
    }
    index = index + 1
  }
  None
}

///|
/// Whether `text[start:]` begins a `<name` (or `</name` when `closing`) tag
/// whose name ends at a tag boundary. The boundary check stops a shorter tag
/// such as `table` from matching a longer name such as `tablet`.
pub fn markup_tag_matches(
  text : String,
  start : Int32,
  name : String,
  closing : Bool,
) -> Bool {
  if start < 0 || start >= text.length() {
    return false
  }
  let prefix = if closing { "</" + name } else { "<" + name }
  if !text[start:].has_prefix(prefix) {
    return false
  }
  let boundary = start + prefix.length()
  if boundary >= text.length() {
    true
  } else {
    is_markup_tag_boundary(text[boundary])
  }
}

///|
/// Index of the next `<name …>` (or `</name>` when `closing`) tag at or after
/// `from`, applying the same name-boundary rule as `markup_tag_matches`.
/// `text` must already be in the desired case; callers pass a lowercased copy
/// with a lowercase `name` for case-insensitive matching.
pub fn find_markup_tag(
  text : String,
  name : String,
  from : Int32,
  closing : Bool,
) -> Int32? {
  let prefix = if closing { "</" + name } else { "<" + name }
  let mut index = if from < 0 { 0 } else { from }
  while index < text.length() {
    match find_markup_from(text, prefix, index) {
      Some(candidate) =>
        if markup_tag_matches(text, candidate, name, closing) {
          return Some(candidate)
        } else {
          index = candidate + prefix.length()
        }
      None => return None
    }
  }
  None
}

///|
fn find_markup_from(text : String, needle : String, start : Int32) -> Int32? {
  if start >= text.length() {
    None
  } else {
    match text[start:].find(needle[:]) {
      Some(pos) => Some(start + pos)
      None => None
    }
  }
}

///|
fn is_markup_tag_boundary(ch : UInt16) -> Bool {
  ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' || ch == '>' || ch == '/'
}
