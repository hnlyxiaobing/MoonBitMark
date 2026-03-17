///|
test "xlsx file stem helper" {
  inspect(file_stem("sheets/demo.xlsx"), content="Some(\"demo\")")
}
