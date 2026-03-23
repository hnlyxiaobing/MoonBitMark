///|
test "json file stem helper" {
  inspect(@core.file_stem("fixtures/data.json"), content="Some(\"data\")")
}
