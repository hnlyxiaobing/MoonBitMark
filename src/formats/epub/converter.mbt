// EPUB Converter
// Converts EPUB files to Markdown

///|
/// 将 Array[Byte] 转换为 Bytes
fn bytes_from_array(arr : Array[Byte]) -> Bytes {
  let buf = @buffer.new()
  for b in arr {
    buf.write_byte(b)
  }
  buf.to_bytes()
}

///|
/// 从 Option[String] 获取标题，默认为空字符串
fn get_title(title : String?) -> String {
  match title {
    Some(t) => t
    None => ""
  }
}

///|
/// Helper function to find the last occurrence of a character

///|
fn find_last_char(s : String, c : Char) -> Int? {
  let mut idx = -1
  let mut i = 0
  for ch in s {
    if ch == c {
      idx = i
    }
    i = i + 1
  }
  if idx >= 0 {
    Some(idx)
  } else {
    None
  }
}

///|
pub fn EpubConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.extension {
    Some(ext) => {
      let ext_lower = ext.to_lower().to_string()
      ext_lower == ".epub"
    }
    None => false
  }
}

///|
pub async fn EpubConverter::convert(file_path : String) -> @core.ConvertResult {
  // 读取 EPUB 文件内容
  let file = @fs.open(file_path, mode=ReadOnly)
  let all_bytes : Array[Byte] = Array::new()

  // 读取文件内容
  while true {
    let buffer : FixedArray[Byte] = FixedArray::make(4096, b'\x00')
    let bytes_read = file.read(buffer)
    if bytes_read == 0 {
      break
    }
    // 将读取的数据添加到数组
    let mut i = 0
    while i < bytes_read {
      all_bytes.push(buffer[i])
      i = i + 1
    }
  }
  file.close()

  // 将 Array[Byte] 转换为 Bytes
  let epub_data = bytes_from_array(all_bytes)

  // 使用纯 MoonBit libzip 打开 ZIP
  match @libzip.ZipArchive::open(epub_data) {
    Some(zip) =>
      // Parse container.xml to find OPF file
      match
        @libzip.read_file_entry_decompressed(zip, "META-INF/container.xml") {
        Some(container_data) => {
          let opf_path = parse_container_xml(container_data)

          // Get OPF directory
          let opf_dir = match find_last_char(opf_path, '/') {
            Some(idx) => opf_path[0:idx].to_string()
            None => ""
          }

          // Parse OPF file
          match @libzip.read_file_entry_decompressed(zip, opf_path) {
            Some(opf_data) => {
              let epub_pkg = parse_opf(opf_data)

              // Build content
              let mut result = "# "
              result = result + get_title(epub_pkg.metadata.title) + "\n\n"

              // Add metadata
              match epub_pkg.metadata.authors {
                authors if authors.length() > 0 =>
                  result = result + "**Author:** " + authors[0] + "\n\n"
                _ => ignore(())
              }
              match epub_pkg.metadata.language {
                Some(lang) => result = result + "**Language:** " + lang + "\n\n"
                None => ignore(())
              }

              // Process spine items
              for item in epub_pkg.spine {
                let href = epub_pkg.manifest.get(item.idref)
                match href {
                  Some(manifest_item) => {
                    let full_path = if opf_dir == "" {
                      manifest_item.href
                    } else {
                      opf_dir + "/" + manifest_item.href
                    }
                    match @libzip.read_file_entry_decompressed(zip, full_path) {
                      Some(content) =>
                        result = result + parse_xhtml(content) + "\n\n"
                      None => ignore(())
                    }
                  }
                  None => ignore(())
                }
              }

              @core.ConvertResult::markdown_only(result, "epub")
            }
            None => fail("Failed to read OPF file")
          }
        }
        None => fail("Failed to read container.xml")
      }
    None => fail("Failed to open EPUB file as ZIP archive")
  }
}

///|
fn parse_container_xml(data : Bytes) -> String raise {
  // 使用 UTF-8 解码
  let xml_string = @utf8.decode(data) catch {
    _ => {
      // 回退：逐字节转换（ASCII 兼容）
      let mut result = ""
      let mut i = 0
      while i < data.length() {
        let b = data[i]
        result = result + Char::from_int(b.to_int()).to_string()
        i = i + 1
      }
      result
    }
  }

  match @xml.parse_xml(xml_string) {
    Ok(events) => {
      let mut opf_path = ""

      for event in events {
        match event {
          @xml.ElementStart(evt) =>
            if evt.name == "rootfile" {
              match evt.attributes.get("full-path") {
                Some(path) => opf_path = path
                None => ignore(())
              }
            }
          _ => ignore(())
        }
      }

      if opf_path == "" {
        fail("Could not find OPF path in container.xml")
      }

      opf_path
    }
    Err(_) => fail("Failed to parse container.xml: parse error")
  }
}

///|
fn parse_opf(data : Bytes) -> EpubPackage raise {
  // 使用 UTF-8 解码
  let xml_string = @utf8.decode(data) catch {
    _ => {
      // 回退：逐字节转换
      let mut result = ""
      let mut i = 0
      while i < data.length() {
        let b = data[i]
        result = result + Char::from_int(b.to_int()).to_string()
        i = i + 1
      }
      result
    }
  }
  match @xml.parse_xml(xml_string) {
    Ok(events) => {
      let metadata = EpubMetadata::default()
      let manifest : Map[String, ManifestItem] = Map::new()
      let spine : Array[SpineItem] = Array::new()
      let mut current_element = ""
      let mut in_metadata = false

      for event in events {
        match event {
          @xml.ElementStart(evt) => {
            current_element = evt.name
            if evt.name == "metadata" {
              in_metadata = true
            }
            if evt.name == "item" {
              let id = evt.attributes.get("id")
              let href = evt.attributes.get("href")
              let media_type = evt.attributes.get("media-type")
              match (id, href, media_type) {
                (Some(id_val), Some(href_val), Some(mt_val)) =>
                  manifest.set(id_val, {
                    id: id_val,
                    href: href_val,
                    media_type: mt_val,
                    properties: None,
                  })
                _ => ignore(())
              }
            }
            if evt.name == "itemref" {
              match evt.attributes.get("idref") {
                Some(idref) => spine.push({ idref, linear: true })
                None => ignore(())
              }
            }
          }
          @xml.ElementEnd(evt) => {
            if evt.name == "metadata" {
              in_metadata = false
            }
            current_element = ""
          }
          @xml.TextContent(evt) =>
            if in_metadata {
              if current_element == "dc:title" {
                metadata.title = Some(evt.content)
              }
              if current_element == "dc:creator" {
                metadata.authors.push(evt.content)
              }
              if current_element == "dc:language" {
                metadata.language = Some(evt.content)
              }
              if current_element == "dc:description" {
                metadata.description = Some(evt.content)
              }
            }
        }
      }

      { metadata, manifest, spine, opf_dir: "" }
    }
    Err(_) => fail("Failed to parse OPF file")
  }
}

///|
fn parse_xhtml(data : Bytes) -> String {
  // 使用 UTF-8 解码
  let xml_string = @utf8.decode(data) catch {
    _ => {
      // 回退：逐字节转换
      let mut result = ""
      let mut i = 0
      while i < data.length() {
        let b = data[i]
        result = result + Char::from_int(b.to_int()).to_string()
        i = i + 1
      }
      result
    }
  }
  match @xml.parse_xml(xml_string) {
    Ok(events) => {
      let mut result = ""
      let mut in_body = false

      for event in events {
        match event {
          @xml.ElementStart(evt) => {
            if evt.name == "body" {
              in_body = true
            }
            if in_body {
              match evt.name {
                "h1" => result = result + "\n# "
                "h2" => result = result + "\n## "
                "h3" => result = result + "\n### "
                "p" => result = result + "\n\n"
                "br" => result = result + "\n"
                _ => ignore(())
              }
            }
          }
          @xml.ElementEnd(evt) => if evt.name == "body" { in_body = false }
          @xml.TextContent(evt) => if in_body { result = result + evt.content }
        }
      }

      result.trim().to_string()
    }
    Err(_) => ""
  }
}
