///|
test "pdf helper counts and file stem" {
  inspect(count_occurrences("a---a---", "---"), content="2")
  inspect(file_stem("reports/spec.pdf"), content="Some(\"spec\")")
}
