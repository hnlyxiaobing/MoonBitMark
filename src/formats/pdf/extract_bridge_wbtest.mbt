///|
/// The tag may only contain characters that are safe inside a single file
/// name component: no separators, no dots, no escapes.
fn tag_charset_is_safe(tag : String) -> Bool {
  if tag == "" {
    return false
  }
  for ch in tag {
    let ok = (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '-'
    if !ok {
      return false
    }
  }
  true
}

///|
/// Two different documents must get different tags -- that is the whole point
/// of the change: it removes the "two documents share one temp stem" class.
test "pdf bridge tag separates different documents" {
  let a = pdf_bridge_document_tag("docs/a.pdf")
  let b = pdf_bridge_document_tag("docs/b.pdf")
  assert_true(a != b)
  assert_true(tag_charset_is_safe(a))
  assert_true(tag_charset_is_safe(b))
}

///|
/// Path separators, spaces and traversal segments must not leak into the tag.
test "pdf bridge tag only keeps alphanumerics" {
  // Windows separators are normalised before the basename is taken.
  assert_eq(pdf_bridge_document_tag("C:\\Users\\me\\my report.pdf"), "my-report-pdf")
  assert_eq(pdf_bridge_document_tag("../escape.pdf"), "escape-pdf")
  // A dotfile-style basename keeps no leading dash.
  assert_eq(pdf_bridge_document_tag(".hidden.pdf"), "hidden-pdf")
  for path in [
    "C:\\Users\\me\\my report.pdf",
    "../escape.pdf",
    "/tmp/a b\tc.pdf",
    "docs/../../etc/passwd",
    ".hidden.pdf",
  ] {
    let tag = pdf_bridge_document_tag(path)
    assert_true(tag_charset_is_safe(tag), msg=path)
  }
}

///|
/// An empty or separator-only path has no usable basename, so it must fall
/// back to a fixed tag instead of producing `pdf-bridge-<ms>-` (trailing dash).
test "pdf bridge tag falls back to a fixed name" {
  assert_eq(pdf_bridge_document_tag(""), "document")
  assert_eq(pdf_bridge_document_tag("///"), "document")
  assert_eq(pdf_bridge_document_tag("..."), "document")
}

///|
/// Over-long basenames are truncated so the temp path stays bounded.
test "pdf bridge tag truncates long basenames" {
  let tag = pdf_bridge_document_tag("a".repeat(200) + ".pdf")
  assert_eq(tag.length(), 32)
  assert_true(tag_charset_is_safe(tag))
  // Truncation must not leave a dangling dash at the cut point.
  let dashed = pdf_bridge_document_tag("abcdefghij".repeat(10) + ".pdf")
  assert_true(dashed.length() <= 32)
  assert_true(tag_charset_is_safe(dashed))
  assert_true(!dashed.has_suffix("-"))
}
