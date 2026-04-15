///|
test "json file stem helper" {
  inspect(@core.file_stem("fixtures/data.json"), content="Some(\"data\")")
}

///|
async test "json converter supports bytes input source" {
  ignore(@async.now())
  let result = JsonConverter::convert_source(
    @core.BytesInput(
      Some("bytes-data.json"),
      @utf8.encode("{\"demo\":1}"),
      Some("application/json"),
    ),
  )
  inspect(result.title, content="Some(\"bytes-data\")")
  assert_true(result.markdown.contains("``` json"))
}
