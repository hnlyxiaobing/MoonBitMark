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
  inspect(result.available, content="true")
  inspect(result.provider, content="Some(\"mock\")")
  inspect(result.text, content="MOCK OCR scan")
  inspect(result.layout_json is Some(_), content="true")
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
