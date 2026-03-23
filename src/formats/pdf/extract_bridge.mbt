///|
priv struct PdfBridgeResponse {
  available : Bool
  provider : String?
  pages : Array[String]
  warnings : Array[String]
} derive(FromJson)

///|
async fn try_extract_pdf_bridge_pages(file_path : String) -> PdfBridgeResponse {
  let temp_dir = pdf_bridge_temp_dir()
  ensure_pdf_bridge_temp_dir(temp_dir)
  let temp_stem = "pdf-bridge-" + @async.now().to_string()
  let output_path = temp_dir + "/" + temp_stem + ".json"
  let stderr_path = temp_dir + "/" + temp_stem + ".stderr.txt"
  let args : Array[String] = [
    "scripts/pdf/bridge.py", "--input", file_path, "--output-json", output_path,
  ]

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

  let response = match exit_code_result {
    Ok(exit_code) =>
      parse_pdf_bridge_response(output_path, stderr_path, exit_code)
    Err(err) =>
      PdfBridgeResponse::{
        available: false,
        provider: None,
        pages: [],
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
          "PDF bridge execution failed: " + text.trim().to_string()
        _ =>
          "PDF bridge execution failed with exit code " +
          exit_code.to_string() +
          "."
      }
      return PdfBridgeResponse::{
        available: false,
        provider: None,
        pages: [],
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
    Ok(response) => response
    Err(err) =>
      PdfBridgeResponse::{
        available: false,
        provider: None,
        pages: [],
        warnings: ["PDF bridge returned invalid JSON: " + err.to_string()],
      }
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
