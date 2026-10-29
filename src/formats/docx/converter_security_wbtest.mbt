// White-box regression tests for the DOCX converter.
//
// The case below covers the list nesting clamp: `w:ilvl` is attacker
// controlled and used to build an indent prefix with `String::repeat`, so it
// must be bounded before it reaches the string builder.

///|
test "docx list level is clamped to the maximum supported nesting depth" {
  assert_eq(docx_parse_level(Some("2147483647")), 8)
  assert_eq(docx_parse_level(Some("9999999999")), 8)
  assert_eq(docx_parse_level(Some("3")), 3)
  assert_eq(docx_parse_level(Some("0")), 0)
  assert_eq(docx_parse_level(Some("")), 0)
  assert_eq(docx_parse_level(None), 0)
}

///|
test "docx list level never produces an oversized indent prefix" {
  let level = docx_parse_level(Some("2147483647"))
  assert_true(level >= 0)
  assert_true(level <= 8)
  assert_true("  ".repeat(level).length() <= 16)
}
