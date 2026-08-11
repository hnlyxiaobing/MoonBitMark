///|
pub async fn recognize_image_file(
  file_path : String,
  config : OcrConfig,
  source_name? : String = file_path,
  page_numbers? : Array[Int] = [],
) -> OcrResult {
  if config.mode == Off {
    return OcrResult::not_attempted()
  }
  run_ocr_file_bridge(file_path, source_name, config, page_numbers)
}

///|
pub async fn recognize_image_bytes(
  bytes : Bytes,
  source_name : String,
  config : OcrConfig,
  temp_stem? : String = source_name,
) -> OcrResult {
  if config.mode == Off {
    return OcrResult::not_attempted()
  }
  run_ocr_bytes_bridge(bytes, source_name, temp_stem, config)
}
