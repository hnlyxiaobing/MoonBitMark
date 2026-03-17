///|
test "text converter helpers" {
  inspect(count_lines("a\nb\n"), content="3")
  inspect(file_stem("docs/readme.txt"), content="Some(\"readme\")")
}
