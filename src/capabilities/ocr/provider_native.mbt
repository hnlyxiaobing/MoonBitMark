///|
priv struct BridgeResponse {
  available : Bool
  provider : String?
  text : String
  layout_json : String?
  warnings : Array[String]
} derive(FromJson)

///|
async fn run_ocr_file_bridge(
  file_path : String,
  source_name : String,
  config : OcrConfig,
  page_numbers : Array[Int],
) -> OcrResult {
  run_bridge(file_path, source_name, source_name, config, page_numbers)
}

///|
async fn run_ocr_bytes_bridge(
  bytes : Bytes,
  source_name : String,
  temp_stem : String,
  config : OcrConfig,
) -> OcrResult {
  let temp_dir = ocr_temp_dir()
  ensure_ocr_temp_dir(temp_dir)
  let input_path = temp_dir +
    "/" +
    sanitize_file_stem(temp_stem) +
    input_extension(source_name)
  write_bytes_file(input_path, bytes)
  let result = run_bridge(input_path, source_name, temp_stem, config, [])
  cleanup_file(input_path)
  result
}

///|
async fn run_bridge(
  input_path : String,
  _source_name : String,
  temp_name : String,
  config : OcrConfig,
  page_numbers : Array[Int],
) -> OcrResult {
  let temp_dir = ocr_temp_dir()
  ensure_ocr_temp_dir(temp_dir)
  let temp_stem = sanitize_file_stem(temp_name) + "-" + @async.now().to_string()
  let output_path = temp_dir + "/" + temp_stem + ".json"
  let stderr_path = temp_dir + "/" + temp_stem + ".stderr.txt"
  // Resolve the bridge script: explicit env override -> probe upward from
  // the executable -> CWD relative path. A missing script is reported as a
  // warning, never raised.
  let script_path = match
    @python.resolve_bridge_script(
      "scripts/ocr/bridge.py", "MOONBITMARK_OCR_BRIDGE",
    ) {
    Found(path~, ..) => path
    resolution =>
      return OcrResult::{
        attempted: true,
        available: false,
        provider: None,
        text: "",
        layout_json: None,
        warnings: [
          "OCR bridge unavailable: " +
          @python.bridge_script_diagnostic(resolution),
        ],
      }
  }
  let args : Array[String] = [
    script_path,
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
  if page_numbers.length() > 0 {
    args.push("--page-numbers")
    args.push(page_numbers.map(n => n.to_string()).join(","))
  }

  // Resolve a real interpreter path: spawning bare "python" fails on Windows
  // pyenv-win setups (async appends ".exe" and calls CreateProcessW directly,
  // with no PATHEXT matching for shims).
  let (program, prefix_args) = match @python.resolve_python() {
    Some(resolved) => resolved
    None =>
      return OcrResult::{
        attempted: true,
        available: false,
        provider: None,
        text: "",
        layout_json: None,
        warnings: [
          "OCR backend unavailable: " + @python.python_not_found_diagnostic(),
        ],
      }
  }
  let run_args = prefix_args.copy()
  for arg in args {
    run_args.push(arg)
  }

  let exit_code_result : Result[Int, Error] = try {
    let stderr = @process.redirect_to_file(
      stderr_path,
      create_mode=@fs.CreateOrTruncate,
    )
    Ok(@process.run(program, run_args, stderr~))
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
        layout_json: None,
        warnings: [
          "OCR bridge process failed to start (" +
          err.to_string() +
          "). The resolved Python interpreter may be unavailable; set MOONBITMARK_PYTHON to a valid interpreter path.",
        ],
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
        Ok(text) => text.trim().to_owned()
        Err(_) => ""
      }
      let warning = if stderr_text != "" {
        classify_bridge_stderr(stderr_text)
      } else {
        "OCR bridge exited with code " +
        exit_code.to_string() +
        " without producing output. Re-run from a terminal to see the bridge's error, or report this as a bridge bug."
      }
      return OcrResult::{
        attempted: true,
        available: false,
        provider: None,
        text: "",
        layout_json: None,
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
        layout_json: None,
        warnings: [
          "OCR bridge returned invalid JSON: " +
          err.to_string() +
          ". The bridge script may be out of sync with this build.",
        ],
      }
  }

  let warnings : Array[String] = []
  for warning in response.warnings {
    warnings.push(enrich_backend_warning(warning))
  }
  if exit_code != 0 && warnings.length() == 0 {
    warnings.push(
      "OCR bridge exited with code " +
      exit_code.to_string() +
      " but produced no diagnostic. Re-run from a terminal to see the bridge's error.",
    )
  }
  OcrResult::{
    attempted: true,
    available: response.available,
    provider: response.provider,
    text: response.text.trim().to_owned(),
    layout_json: response.layout_json,
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
  let file = @fs.open(path, mode=WriteOnly, create_mode=@fs.CreateOrTruncate)
  file.write(bytes)
  file.close()
}

///|
async fn read_utf8_file(path : String) -> String {
  let file = @fs.open(path, mode=ReadOnly)
  let buffer = Buffer()
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
  let normalized = source_name.replace_all(old="\\", new="/")
  match find_last_char(normalized, '.') {
    Some(index) =>
      if index < normalized.length() {
        normalized[index:].to_lower().to_owned()
      } else {
        ".bin"
      }
    None => ".bin"
  }
}

///|
fn sanitize_file_stem(name : String) -> String {
  let mut result = ""
  for ch in name.replace_all(old="\\", new="/") {
    if (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') {
      result = result + ch.to_string()
    } else {
      result = result + "-"
    }
  }
  let trimmed = result.trim().to_owned()
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

///|
/// First non-empty line of a multi-line bridge stderr dump, used to keep
/// warnings single-line.
fn first_stderr_line(stderr_text : String) -> String {
  for line in stderr_text.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed != "" {
      return trimmed
    }
  }
  stderr_text.trim().to_owned()
}

///|
/// First stderr line containing `needle` (compared case-insensitively on the
/// already-lowercased haystack), falling back to the first non-empty line.
fn stderr_excerpt(stderr_text : String, needle : String) -> String {
  for line in stderr_text.split("\n") {
    if line.to_owned().to_lower().contains(needle) {
      return line.trim().to_owned()
    }
  }
  first_stderr_line(stderr_text)
}

///|
/// Classify stderr from a bridge that died before writing its JSON output,
/// returning an actionable warning that names the failure layer.
fn classify_bridge_stderr(stderr_text : String) -> String {
  let lower = stderr_text.to_lower()
  if lower.contains("modulenotfounderror") ||
    lower.contains("importerror") ||
    lower.contains("no module named") {
    return "OCR bridge failed: a Python dependency is missing (" +
      stderr_excerpt(stderr_text, "error") +
      "). Install the missing package into the resolved interpreter, or use --ocr-backend mock which needs no extra dependencies."
  }
  if lower.contains("syntaxerror") {
    return "OCR bridge failed: the bridge script could not be parsed by the resolved Python interpreter (" +
      stderr_excerpt(stderr_text, "syntaxerror") +
      "). Set MOONBITMARK_PYTHON to a newer Python (>= 3.8)."
  }
  "OCR bridge failed before producing output: " + stderr_text
}

///|
/// Attach an actionable remedy to well-known bridge-reported failures
/// (missing backend, timeout, unsupported backend). Unknown warnings pass
/// through unchanged.
fn enrich_backend_warning(warning : String) -> String {
  let lower = warning.to_lower()
  if lower.contains("tesseract executable was not found") ||
    lower.contains("no ocr backend is available") {
    return warning +
      " Install tesseract (https://github.com/tesseract-ocr/tesseract) or re-run with --ocr-backend mock."
  }
  if lower.contains("timed out") {
    return warning + " Increase the limit via --ocr-timeout <ms>."
  }
  if lower.contains("unsupported ocr backend") {
    return warning +
      " Supported backends: auto, mock, tesseract (select via --ocr-backend)."
  }
  warning
}
