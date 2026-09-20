///|
async test "recognize image bytes with mock backend" {
  ignore(@async.now())
  // The OCR bridge (including the mock backend) runs through
  // `python scripts/ocr/bridge.py`; without a Python interpreter the
  // bridge cannot start, so skip the backend assertions here.
  if @python.resolve_python() is None {
    return
  }
  let config = @ocr.OcrConfig::{
    ..@ocr.OcrConfig::default(),
    mode: Force,
    backend: Some("mock"),
  }
  let result = @ocr.recognize_image_bytes(
    b"dummy",
    "scan.png",
    config,
    temp_stem="ocr-test-mock",
  )
  inspect(
    result.available,
    content=(
      #|true
    ),
  )
  debug_inspect(
    result.provider,
    content=(
      #|Some("mock")
    ),
  )
  inspect(
    result.text,
    content=(
      #|MOCK OCR scan
    ),
  )
  inspect(
    result.layout_json is Some(_),
    content=(
      #|true
    ),
  )
}

///|
async test "recognize image bytes reports unsupported backend" {
  let config = @ocr.OcrConfig::{
    ..@ocr.OcrConfig::default(),
    mode: Force,
    backend: Some("missing"),
  }
  let result = @ocr.recognize_image_bytes(
    b"dummy",
    "scan.png",
    config,
    temp_stem="ocr-test-missing",
  )
  inspect(result.available, content="false")
  inspect(result.warnings.length(), content="1")
}
