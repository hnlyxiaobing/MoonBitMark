///|
priv struct BridgeResponse {
  available : Bool
  provider : String?
  text : String
  warnings : Array[String]
} derive(FromJson)

///|
pub async fn recognize_image_file(
  file_path : String,
  config : OcrConfig,
  source_name? : String = file_path,
) -> OcrResult {
  if config.mode == Off {
    return OcrResult::not_attempted()
  }
  run_bridge(file_path, source_name, source_name, config)
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
  let temp_dir = ocr_temp_dir()
  ensure_ocr_temp_dir(temp_dir)
  let input_path = temp_dir +
    "/" +
    sanitize_file_stem(temp_stem) +
    input_extension(source_name)
  write_bytes_file(input_path, bytes)
  let result = run_bridge(input_path, source_name, temp_stem, config)
  cleanup_file(input_path)
  result
}

///|
async fn run_bridge(
  input_path : String,
  _source_name : String,
  temp_name : String,
  config : OcrConfig,
) -> OcrResult {
  let temp_dir = ocr_temp_dir()
  ensure_ocr_temp_dir(temp_dir)
  let temp_stem = sanitize_file_stem(temp_name) + "-" + @async.now().to_string()
  let output_path = temp_dir + "/" + temp_stem + ".json"
  let stderr_path = temp_dir + "/" + temp_stem + ".stderr.txt"
  let args : Array[String] = [
    "scripts/ocr/bridge.py",
    "--input",
    input_path,
    "--output-json",
    output_path,
    "--source-name",
    _source_name,
    "--lang",
    config.language,
    "--backend",
    config.backend_or_auto(),
  ]
  match config.timeout_ms {
    Some(value) => {
      args.push("--timeout-ms")
      args.push(value.to_string())
    }
    None => ()
  }

  let exit_code_result : Result[Int, Error] = try {
    let stderr = @process.redirect_to_file(
      stderr_path,
      create=0o644,
      truncate=true,
    )
    Ok(@process.run("python", args, stderr~))
  } catch {
    err => Err(err)
  }

  let result = match exit_code_result {
    Ok(exit_code) => parse_bridge_response(output_path, stderr_path, exit_code)
    Err(err) =>
      OcrResult::{
        attempted: true,
        available: false,
        provider: None,
        text: "",
        warnings: ["OCR backend execution failed: " + err.to_string()],
      }
  }
  cleanup_file(output_path)
  cleanup_file(stderr_path)
  result
}

///|
async fn parse_bridge_response(
  output_path : String,
  stderr_path : String,
  exit_code : Int,
) -> OcrResult {
  let json_text_result : Result[String, Error] = Ok(read_utf8_file(output_path)) catch {
    err => Err(err)
  }
  let json_text = match json_text_result {
    Ok(text) => text
    Err(_) => {
      let stderr_text_result : Result[String, Error] = Ok(
        read_utf8_file(stderr_path),
      ) catch {
        err => Err(err)
      }
      let stderr_text = match stderr_text_result {
        Ok(text) => text.trim().to_string()
        Err(_) => ""
      }
      let warning = if stderr_text != "" {
        "OCR backend execution failed: " + stderr_text
      } else {
        "OCR backend execution failed with exit code " +
        exit_code.to_string() +
        "."
      }
      return OcrResult::{
        attempted: true,
        available: false,
        provider: None,
        text: "",
        warnings: [warning],
      }
    }
  }

  let parsed_result : Result[BridgeResponse, Error] = try {
    let parsed_json = @json.parse(json_text)
    let response : BridgeResponse = @json.from_json(parsed_json)
    Ok(response)
  } catch {
    err => Err(err)
  }
  let response = match parsed_result {
    Ok(value) => value
    Err(err) =>
      return OcrResult::{
        attempted: true,
        available: false,
        provider: None,
        text: "",
        warnings: ["OCR backend returned invalid JSON: " + err.to_string()],
      }
  }

  let warnings : Array[String] = []
  for warning in response.warnings {
    warnings.push(warning)
  }
  if exit_code != 0 && warnings.length() == 0 {
    warnings.push(
      "OCR backend execution failed with exit code " +
      exit_code.to_string() +
      ".",
    )
  }
  OcrResult::{
    attempted: true,
    available: response.available,
    provider: response.provider,
    text: response.text.trim().to_string(),
    warnings,
  }
}

///|
fn ocr_temp_dir() -> String {
  "_build/ocr-tmp"
}

///|
async fn ensure_ocr_temp_dir(path : String) -> Unit {
  ignore(@fs.mkdir(path, permission=0o755, recursive=true) catch { _ => () })
}

///|
async fn cleanup_file(path : String) -> Unit {
  ignore(@fs.remove(path) catch { _ => () })
}

///|
async fn write_bytes_file(path : String, bytes : Bytes) -> Unit {
  let file = @fs.open(path, mode=WriteOnly, create=0o644, truncate=true)
  file.write(bytes)
  file.close()
}

///|
async fn read_utf8_file(path : String) -> String {
  let file = @fs.open(path, mode=ReadOnly)
  let buffer = @buffer.new()
  while true {
    let chunk : FixedArray[Byte] = FixedArray::make(4096, b'\x00')
    let read = file.read(chunk)
    if read == 0 {
      break
    }
    for i in 0..<read {
      buffer.write_byte(chunk[i])
    }
  }
  file.close()
  @utf8.decode(buffer.to_bytes())
}

///|
fn input_extension(source_name : String) -> String {
  let normalized = source_name.replace(old="\\", new="/")
  match find_last_char(normalized, '.') {
    Some(index) =>
      if index < normalized.length() {
        normalized[index:].to_lower().to_string()
      } else {
        ".bin"
      }
    None => ".bin"
  }
}

///|
fn sanitize_file_stem(name : String) -> String {
  let mut result = ""
  for ch in name.replace(old="\\", new="/") {
    if (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') {
      result = result + ch.to_string()
    } else {
      result = result + "-"
    }
  }
  let trimmed = result.trim().to_string()
  if trimmed == "" {
    "ocr-input"
  } else {
    trimmed
  }
}

///|
fn find_last_char(s : String, target : Char) -> Int? {
  let mut found = -1
  let mut i = 0
  for ch in s {
    if ch == target {
      found = i
    }
    i = i + 1
  }
  if found >= 0 {
    Some(found)
  } else {
    None
  }
}
