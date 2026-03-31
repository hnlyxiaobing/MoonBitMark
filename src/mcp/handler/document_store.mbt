// MoonBitMark MCP Handler - Dynamic Document Store

///|
priv struct StoredDocument {
  resource_uri : String
  filename : String
  mime_type : String?
  byte_size : Int
  blob_path : String
}

///|
async fn store_document_resource(
  filename : String,
  bytes : Bytes,
  mime_type : String?,
) -> StoredDocument {
  ensure_document_store_dirs()
  sweep_stale_document_resources()
  let id = new_document_resource_id(filename)
  let blob_path = document_blob_path(id)
  let meta_path = document_meta_path(id)
  write_document_blob(blob_path, bytes)
  write_document_meta(meta_path, id, filename, mime_type, bytes.length())
  StoredDocument::{
    resource_uri: document_resource_uri(id),
    filename,
    mime_type,
    byte_size: bytes.length(),
    blob_path,
  }
}

///|
async fn load_document_resource(
  resource_uri : String,
) -> Result[StoredDocument, String] {
  sweep_stale_document_resources()
  let id = match parse_document_resource_id(resource_uri) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let meta_path = document_meta_path(id)
  let blob_path = document_blob_path(id)
  if !@fs.exists(meta_path) || !@fs.exists(blob_path) {
    return Err("Resource not found")
  }
  let metadata = match read_document_meta(meta_path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let filename = match metadata.get("filename") {
    Some(value) if value != "" => value
    _ => return Err("Stored document metadata is missing filename")
  }
  let byte_size = match metadata.get("byte_size") {
    Some(value) =>
      @strconv.from_str(value[:]) catch {
        _ => return Err("Stored document metadata has invalid byte_size")
      }
    None => return Err("Stored document metadata is missing byte_size")
  }
  let mime_type = match metadata.get("mime_type") {
    Some(value) if value != "" => Some(value)
    _ => None
  }
  Ok(StoredDocument::{ resource_uri, filename, mime_type, byte_size, blob_path })
}

///|
async fn read_document_resource_bytes(
  resource_uri : String,
) -> Result[Bytes, String] {
  let stored = match load_document_resource(resource_uri) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(@core.read_file_bytes(stored.blob_path)) catch {
    err => Err("Failed to read stored document bytes: " + err.to_string())
  }
}

///|
async fn read_document_resource_contents(
  resource_uri : String,
) -> Result[@types.McpResourceContents, String] {
  let stored = match load_document_resource(resource_uri) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(@types.McpResourceContents::{
    uri: resource_uri,
    mime_type: Some("text/markdown"),
    text: render_document_resource_text(stored),
  })
}

///|
fn render_document_resource_text(stored : StoredDocument) -> String {
  [
    "# Uploaded document resource",
    "",
    "- resource_uri: " + stored.resource_uri,
    "- source_filename: " + stored.filename,
    "- mime_type: " + optional_string(stored.mime_type),
    "- byte_size: " + stored.byte_size.to_string(),
    "- storage_kind: local_blob",
    "- next_step: call inspect_document or convert_to_markdown with resource_uri.",
  ].join("\n")
}

///|
async fn sweep_stale_document_resources() -> Unit {
  let meta_dir = document_meta_dir()
  if !@fs.exists(meta_dir) {
    return
  }
  let cutoff = (@async.now() - 86400000).to_string()
  let entries = @fs.readdir(
    meta_dir,
    include_hidden=true,
    include_special=false,
    sort=false,
  ) catch {
    _ => return
  }
  for entry in entries {
    if !entry.has_suffix(".meta.txt") {
      continue
    }
    let id = entry[:entry.length() - 9].to_string()
    if document_timestamp_prefix(id) < cutoff {
      ignore(@fs.remove(document_meta_path(id)) catch { _ => () })
      ignore(@fs.remove(document_blob_path(id)) catch { _ => () })
    }
  }
}

///|
async fn ensure_document_store_dirs() -> Unit {
  ignore(
    @fs.mkdir(document_store_root(), permission=0o755, recursive=true) catch {
      _ => ()
    },
  )
  ignore(
    @fs.mkdir(document_blob_dir(), permission=0o755, recursive=true) catch {
      _ => ()
    },
  )
  ignore(
    @fs.mkdir(document_meta_dir(), permission=0o755, recursive=true) catch {
      _ => ()
    },
  )
}

///|
fn document_store_root() -> String {
  "_build/mcp-document-store"
}

///|
fn document_blob_dir() -> String {
  document_store_root() + "/blobs"
}

///|
fn document_meta_dir() -> String {
  document_store_root() + "/meta"
}

///|
fn document_blob_path(id : String) -> String {
  document_blob_dir() + "/" + id + ".bin"
}

///|
fn document_meta_path(id : String) -> String {
  document_meta_dir() + "/" + id + ".meta.txt"
}

///|
fn document_resource_uri(id : String) -> String {
  "moonbitmark://document/" + id
}

///|
fn parse_document_resource_id(resource_uri : String) -> Result[String, String] {
  let prefix = "moonbitmark://document/"
  if !resource_uri.has_prefix(prefix) {
    return Err("Resource not found")
  }
  let id = resource_uri[prefix.length():].to_string()
  if id.trim() == "" {
    Err("Resource not found")
  } else {
    Ok(id)
  }
}

///|
fn new_document_resource_id(filename : String) -> String {
  @async.now().to_string() + "-" + sanitize_document_stem(filename)
}

///|
fn sanitize_document_stem(name : String) -> String {
  let mut result = ""
  for ch in @core.file_name_only(name) {
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
    "document"
  } else {
    trimmed
  }
}

///|
fn document_timestamp_prefix(id : String) -> String {
  match @core.find_last_char(id, '-') {
    Some(index) if index > 0 => id[:index].to_string()
    _ => id
  }
}

///|
async fn write_document_blob(path : String, bytes : Bytes) -> Unit {
  let file = @fs.open(path, mode=WriteOnly, create=0o644, truncate=true)
  file.write(bytes)
  file.close()
}

///|
async fn write_document_meta(
  path : String,
  id : String,
  filename : String,
  mime_type : String?,
  byte_size : Int,
) -> Unit {
  let lines : Array[String] = [
    "id: " + id,
    "filename: " + sanitize_meta_value(filename),
    "mime_type: " + sanitize_meta_value(optional_string(mime_type)),
    "byte_size: " + byte_size.to_string(),
  ]
  let file = @fs.open(path, mode=WriteOnly, create=0o644, truncate=true)
  file.write(@utf8.encode(lines.join("\n") + "\n"))
  file.close()
}

///|
async fn read_document_meta(
  path : String,
) -> Result[Map[String, String], String] {
  let text = @core.read_utf8_file(path) catch {
    err =>
      return Err("Failed to read stored document metadata: " + err.to_string())
  }
  let values : Map[String, String] = Map::new()
  for line in text.split("\n") {
    let rendered = line.trim().to_string()
    if rendered == "" {
      continue
    }
    match rendered.find(": ") {
      Some(index) => {
        let key = rendered[:index].to_string()
        let value = rendered[index + 2:].to_string()
        values[key] = if value == "null" { "" } else { value }
      }
      None => return Err("Stored document metadata is malformed")
    }
  }
  Ok(values)
}

///|
fn sanitize_meta_value(value : String) -> String {
  value.replace(old="\r", new=" ").replace(old="\n", new=" ").trim().to_string()
}
