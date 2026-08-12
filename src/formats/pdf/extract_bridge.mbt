///|
priv struct PdfBridgeResponse {
  available : Bool
  provider : String?
  pages : Array[String]
  layout_json : String?
  warnings : Array[String]
} derive(FromJson)

///|
async fn try_extract_pdf_bridge_pages(file_path : String) -> PdfBridgeResponse {
  let temp_dir = pdf_bridge_temp_dir()
  ensure_pdf_bridge_temp_dir(temp_dir)
  let temp_stem = "pdf-bridge-" + @async.now().to_string()
  let output_path = temp_dir + "/" + temp_stem + ".json"
  let stderr_path = temp_dir + "/" + temp_stem + ".stderr.txt"

  // Resolve the bridge script: explicit env override -> probe upward from
  // the executable -> CWD relative path. A missing script is reported as a
  // warning, never raised.
  let script_path = match
    @python.resolve_bridge_script(
      "scripts/pdf/bridge.py", "MOONBITMARK_PDF_BRIDGE",
    ) {
    Found(path~, ..) => path
    resolution =>
      return PdfBridgeResponse::{
        available: false,
        provider: None,
        pages: [],
        layout_json: None,
        warnings: [
          "PDF bridge unavailable: " +
          @python.bridge_script_diagnostic(resolution),
        ],
      }
  }
  let args : Array[String] = [
    script_path, "--input", file_path, "--output-json", output_path,
  ]

  // Resolve a real interpreter path: spawning bare "python" fails on Windows
  // pyenv-win setups (async appends ".exe" and calls CreateProcessW directly,
  // with no PATHEXT matching for shims).
  let (program, prefix_args) = match @python.resolve_python() {
    Some(resolved) => resolved
    None =>
      return PdfBridgeResponse::{
        available: false,
        provider: None,
        pages: [],
        layout_json: None,
        warnings: [
          "PDF bridge unavailable: " + @python.python_not_found_diagnostic(),
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

  let response = match exit_code_result {
    Ok(exit_code) =>
      parse_pdf_bridge_response(output_path, stderr_path, exit_code)
    Err(err) =>
      PdfBridgeResponse::{
        available: false,
        provider: None,
        pages: [],
        layout_json: None,
        warnings: ["PDF bridge execution failed: " + err.to_string()],
      }
  }
  cleanup_pdf_bridge_file(output_path)
  cleanup_pdf_bridge_file(stderr_path)
  response
}

///|
async fn parse_pdf_bridge_response(
  output_path : String,
  stderr_path : String,
  exit_code : Int,
) -> PdfBridgeResponse {
  let json_text_result : Result[String, Error] = Ok(
    @core.read_utf8_file(output_path),
  ) catch {
    err => Err(err)
  }
  let json_text = match json_text_result {
    Ok(text) => text
    Err(_) => {
      let stderr_text_result : Result[String, Error] = Ok(
        @core.read_utf8_file(stderr_path),
      ) catch {
        err => Err(err)
      }
      let warning = match stderr_text_result {
        Ok(text) if text.trim() != "" =>
          "PDF bridge execution failed: " + text.trim().to_owned()
        _ =>
          "PDF bridge execution failed with exit code " +
          exit_code.to_string() +
          "."
      }
      return PdfBridgeResponse::{
        available: false,
        provider: None,
        pages: [],
        layout_json: None,
        warnings: [warning],
      }
    }
  }

  let parsed_result : Result[PdfBridgeResponse, Error] = try {
    let parsed_json = @json.parse(json_text)
    let response : PdfBridgeResponse = @json.from_json(parsed_json)
    Ok(response)
  } catch {
    err => Err(err)
  }
  match parsed_result {
    Ok(response) =>
      PdfBridgeResponse::{
        ..response,
        provider: normalize_bridge_optional(response.provider),
        layout_json: normalize_bridge_optional(response.layout_json),
      }
    Err(err) =>
      PdfBridgeResponse::{
        available: false,
        provider: None,
        pages: [],
        layout_json: None,
        warnings: ["PDF bridge returned invalid JSON: " + err.to_string()],
      }
  }
}

///|
/// Bridge 侧对可选字段以 "" 代替 null（见 e625524）；解码后统一归一为 None，
/// 消除 Some("")/None 的语义漂移。
fn normalize_bridge_optional(value : String?) -> String? {
  match value {
    Some("") => None
    other => other
  }
}

///|
fn pdf_bridge_temp_dir() -> String {
  "_build/pdf-bridge-tmp"
}

///|
async fn ensure_pdf_bridge_temp_dir(path : String) -> Unit {
  ignore(@fs.mkdir(path, permission=0o755, recursive=true) catch { _ => () })
}

///|
async fn cleanup_pdf_bridge_file(path : String) -> Unit {
  ignore(@fs.remove(path) catch { _ => () })
}
