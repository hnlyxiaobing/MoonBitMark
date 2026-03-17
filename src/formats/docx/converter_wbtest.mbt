///|
test "docx file stem helper" {
  inspect(file_stem("book/chapter1.docx"), content="Some(\"chapter1\")")
}
