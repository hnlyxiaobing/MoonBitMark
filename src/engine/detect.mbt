///|
fn stream_info_of_input(input : @core.InputSource) -> @core.StreamInfo {
  match input {
    @core.FileInput(path, _) =>
      @core.StreamInfo::{
        mimetype: None,
        extension: file_extension(path),
        filename: file_name(path),
        url: None,
        charset: None,
      }
    @core.UrlInput(url, _) =>
      @core.StreamInfo::{
        mimetype: Some("text/html"),
        extension: file_extension(url),
        filename: file_name(url),
        url: Some(url),
        charset: None,
      }
    @core.BytesInput(name, _, mimetype) =>
      @core.StreamInfo::{
        mimetype,
        extension: option_extension(name),
        filename: name,
        url: None,
        charset: None,
      }
  }
}

///|
async fn detect_stream_info(input : @core.InputSource) -> @core.StreamInfo {
  let base = stream_info_of_input(input)
  match input {
    @core.FileInput(_, Some(bytes)) => enrich_stream_info(base, bytes)
    @core.FileInput(path, None) =>
      match read_input_bytes(path) {
        Some(bytes) => enrich_stream_info(base, bytes)
        None => base
      }
    @core.BytesInput(_, bytes, _) => enrich_stream_info(base, bytes)
    @core.UrlInput(_, _) => base
  }
}

///|
fn enrich_stream_info(
  base : @core.StreamInfo,
  bytes : Bytes,
) -> @core.StreamInfo {
  match detect_container_signature(bytes) {
    Some((extension, mimetype)) =>
      @core.StreamInfo::{
        ..base,
        extension: Some(extension),
        mimetype: Some(mimetype),
      }
    None =>
      match detect_magic_mimetype(bytes) {
        Some(mimetype) => @core.StreamInfo::{ ..base, mimetype: Some(mimetype) }
        None => base
      }
  }
}

///|
fn detect_magic_mimetype(bytes : Bytes) -> String? {
  if has_prefix(bytes, b"%PDF-") {
    Some("application/pdf")
  } else {
    None
  }
}

///|
fn detect_container_signature(bytes : Bytes) -> (String, String)? {
  if has_prefix(bytes, b"PK\x03\x04") {
    if contains_ascii(bytes, "word/document.xml") {
      Some(
        (
          ".docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        ),
      )
    } else if contains_ascii(bytes, "ppt/presentation.xml") ||
      contains_ascii(bytes, "ppt/slides/slide1.xml") {
      Some(
        (
          ".pptx", "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        ),
      )
    } else if contains_ascii(bytes, "xl/workbook.xml") {
      Some(
        (
          ".xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        ),
      )
    } else if contains_ascii(bytes, "META-INF/container.xml") {
      Some((".epub", "application/epub+zip"))
    } else {
      Some((".zip", "application/zip"))
    }
  } else if @ole2.cfb_is_ole2_signature(bytes) {
    // OLE2 containers: only claim .doc/.wps when a WordDocument stream exists;
    // otherwise fall through so the original extension/mimetype is kept.
    match @ole2.CfbArchive::open(bytes) {
      Some(archive) if archive.has_stream("WordDocument") =>
        Some((".doc", "application/msword"))
      _ => None
    }
  } else {
    None
  }
}

///|
fn has_prefix(bytes : Bytes, prefix : Bytes) -> Bool {
  if bytes.length() < prefix.length() {
    return false
  }
  for i in 0..<prefix.length() {
    if bytes[i] != prefix[i] {
      return false
    }
  }
  true
}

///|
fn contains_ascii(bytes : Bytes, needle : String) -> Bool {
  let needle_bytes = @utf8.encode(needle)
  if bytes.length() < needle_bytes.length() {
    return false
  }
  for start in 0..<=(bytes.length() - needle_bytes.length()) {
    let mut matched = true
    for offset in 0..<needle_bytes.length() {
      if bytes[start + offset] != needle_bytes[offset] {
        matched = false
        break
      }
    }
    if matched {
      return true
    }
  }
  false
}
