///|
/// Fallback used on targets without a filesystem/process bridge (wasm, js):
/// the OCR bridge cannot spawn `python scripts/ocr/bridge.py` there, so OCR
/// is reported as attempted but unavailable.
fn ocr_bridge_unsupported() -> OcrResult {
  OcrResult::{
    attempted: true,
    available: false,
    provider: None,
    text: "",
    layout_json: None,
    warnings: ["OCR backend is not supported on this target."],
  }
}

///|
async fn run_ocr_file_bridge(
  file_path : String,
  source_name : String,
  config : OcrConfig,
  page_numbers : Array[Int],
) -> OcrResult {
  ignore(file_path)
  ignore(source_name)
  ignore(config)
  ignore(page_numbers)
  @async.pause()
  ocr_bridge_unsupported()
}

///|
async fn run_ocr_bytes_bridge(
  bytes : Bytes,
  source_name : String,
  temp_stem : String,
  config : OcrConfig,
) -> OcrResult {
  ignore(bytes)
  ignore(source_name)
  ignore(temp_stem)
  ignore(config)
  @async.pause()
  ocr_bridge_unsupported()
}
