///|
async test "recognize image bytes with mock backend" {
  ignore(@async.now())
  let config = OcrConfig::{
    ..OcrConfig::default(),
    mode: Force,
    backend: Some("mock"),
  }
  let result = recognize_image_bytes(
    b"dummy",
    "scan.png",
    config,
    temp_stem="ocr-test-mock",
  )
  inspect(result.available, content=(
    #|false
  ))
  inspect(result.provider, content=(
    #|None
  ))
  inspect(result.text, content=(
    #|
  ))
  inspect(result.layout_json is Some(_), content=(
    #|false
  ))
}

///|
async test "recognize image bytes reports unsupported backend" {
  let config = OcrConfig::{
    ..OcrConfig::default(),
    mode: Force,
    backend: Some("missing"),
  }
  let result = recognize_image_bytes(
    b"dummy",
    "scan.png",
    config,
    temp_stem="ocr-test-missing",
  )
  inspect(result.available, content="false")
  inspect(result.warnings.length(), content="1")
}
