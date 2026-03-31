// MoonBitMark MCP Handler - Shared Document Input Resolution

///|
priv struct UploadedBytesPayload {
  bytes : Bytes
  encoding : String
}

///|
priv struct ResolvedMcpDocument {
  request_uri : String
  input_kind : String
  input_source : @core.InputSource
  source_filename : String?
  mime_type : String?
  byte_size : Int?
  upload_encoding : String?
}

///|
async fn resolve_request_document_arg(
  args : @types.JsonValue,
  config : McpSecurityConfig,
) -> Result[ResolvedMcpDocument, String] {
  let uri = args.get("uri")
  let resource_uri = args.get("resource_uri")
  match (uri, resource_uri) {
    (Some(@types.String(value)), None) => resolve_uri_document(value, config)
    (None, Some(@types.String(value))) =>
      resolve_resource_document(value, config)
    (Some(_), Some(_)) =>
      Err("Error: provide exactly one of 'uri' or 'resource_uri'")
    (None, None) => Err("Error: one of 'uri' or 'resource_uri' is required")
    (Some(_), None) => Err("Error: 'uri' must be a string")
    (None, Some(_)) => Err("Error: 'resource_uri' must be a string")
  }
}

///|
async fn resolve_uri_document(
  uri : String,
  config : McpSecurityConfig,
) -> Result[ResolvedMcpDocument, String] {
  let request_uri = uri.trim().to_string()
  if request_uri == "" {
    return Err("Error: 'uri' parameter is required")
  }
  let input = match enforce_mcp_input_boundary(request_uri, config) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let byte_size = file_size_bytes(input)
  let source_filename = if is_http_input(input) {
    None
  } else {
    let name = @core.file_name_only(input)
    if name == "" {
      None
    } else {
      Some(name)
    }
  }
  Ok(ResolvedMcpDocument::{
    request_uri,
    input_kind: if is_http_input(input) {
      "url"
    } else {
      "file"
    },
    input_source: @core.InputSource::from_string(input),
    source_filename,
    mime_type: None,
    byte_size,
    upload_encoding: None,
  })
}

///|
async fn resolve_resource_document(
  resource_uri : String,
  config : McpSecurityConfig,
) -> Result[ResolvedMcpDocument, String] {
  ignore(config)
  let stored = match load_document_resource(resource_uri) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let bytes = match read_document_resource_bytes(resource_uri) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(ResolvedMcpDocument::{
    request_uri: resource_uri,
    input_kind: "resource",
    input_source: @core.BytesInput(
      Some(stored.filename),
      bytes,
      stored.mime_type,
    ),
    source_filename: Some(stored.filename),
    mime_type: stored.mime_type,
    byte_size: Some(stored.byte_size),
    upload_encoding: Some("stored_resource"),
  })
}

///|
fn resolve_inline_upload_document(
  args : @types.JsonValue,
  config : McpSecurityConfig,
  request_uri : String,
) -> Result[ResolvedMcpDocument, String] {
  let filename = match required_string_arg(args, "filename") {
    Ok(value) => uploaded_filename(value)
    Err(message) => return Err(message)
  }
  let upload = match uploaded_payload_arg(args) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let mime_type = optional_raw_string_arg(args, "mime_type")
  match enforce_upload_size(upload.bytes.length(), config) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(ResolvedMcpDocument::{
    request_uri,
    input_kind: "uploaded_document",
    input_source: @core.BytesInput(Some(filename), upload.bytes, mime_type),
    source_filename: Some(filename),
    mime_type,
    byte_size: Some(upload.bytes.length()),
    upload_encoding: Some(upload.encoding),
  })
}

///|
fn uploaded_payload_arg(
  args : @types.JsonValue,
) -> Result[UploadedBytesPayload, String] {
  let base64_value = args.get("data_base64")
  let bytes_value = args.get("data_bytes")
  match (base64_value, bytes_value) {
    (Some(@types.String(value)), None) =>
      if value.trim() == "" {
        Err("Error: 'data_base64' must not be empty")
      } else {
        Ok(UploadedBytesPayload::{
          bytes: decode_uploaded_base64(value),
          encoding: "base64",
        }) catch {
          _ => Err("Error: 'data_base64' must be valid base64")
        }
      }
    (None, Some(@types.Array(values))) =>
      decode_uploaded_bytes_array(values).map(bytes => UploadedBytesPayload::{
        bytes,
        encoding: "bytes",
      })
    (Some(_), Some(_)) =>
      Err("Error: provide exactly one of 'data_base64' or 'data_bytes'")
    (None, None) =>
      Err("Error: one of 'data_base64' or 'data_bytes' is required")
    (Some(_), None) => Err("Error: 'data_base64' must be a string")
    (None, Some(_)) => Err("Error: 'data_bytes' must be an array of integers")
  }
}

///|
fn decode_uploaded_base64(value : String) -> Bytes raise {
  @base64.decode(value.trim(), ignore_whitespace=true)
}

///|
fn decode_uploaded_bytes_array(
  values : Array[@types.JsonValue],
) -> Result[Bytes, String] {
  let items : Array[Byte] = []
  for value in values {
    match value {
      @types.Number(number) =>
        if number >= 0 && number <= 255 {
          items.push(number.to_byte())
        } else {
          return Err(
            "Error: 'data_bytes' values must be integers between 0 and 255",
          )
        }
      @types.Float(_) =>
        return Err(
          "Error: 'data_bytes' values must be integers between 0 and 255",
        )
      _ =>
        return Err(
          "Error: 'data_bytes' values must be integers between 0 and 255",
        )
    }
  }
  if items.length() == 0 {
    Err("Error: uploaded content must not be empty")
  } else {
    Ok(Bytes::from_array(items))
  }
}

///|
fn uploaded_filename(raw_name : String) -> String {
  let name = sanitize_meta_value(
    @core.file_name_only(raw_name.trim().to_string()),
  )
  if name == "" {
    "upload.bin"
  } else {
    name
  }
}

///|
fn uploaded_request_uri(filename : String) -> String {
  "upload://" + filename
}

///|
fn optional_raw_string_arg(args : @types.JsonValue, key : String) -> String? {
  match args.get(key) {
    Some(@types.String(value)) if value.trim() != "" =>
      Some(value.trim().to_string())
    _ => None
  }
}

///|
fn enforce_upload_size(
  size : Int,
  config : McpSecurityConfig,
) -> Result[Unit, String] {
  if size <= config.max_upload_bytes {
    Ok(())
  } else {
    Err(
      "Uploaded content exceeds MOONBITMARK_MCP_MAX_UPLOAD_BYTES: " +
      size.to_string() +
      " > " +
      config.max_upload_bytes.to_string(),
    )
  }
}
