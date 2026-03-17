// PPTX Converter - Pure MoonBit Implementation
// Converts PowerPoint presentations (.pptx) to Markdown

///|
/// Converter for PPTX files
pub(all) struct PptxConverter {
  dummy : Int
}

///|
/// Create a new PPTX converter
pub fn PptxConverter::new() -> PptxConverter {
  PptxConverter::{ dummy: 0 }
}

///|
/// Check if this converter accepts the given file
pub fn PptxConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.extension {
    Some(ext) => {
      let ext_lower = ext.to_lower().to_string()
      ext_lower == ".pptx"
    }
    None => false
  }
}

///|
/// Convert a PPTX file to Markdown
pub async fn PptxConverter::convert(file_path : String) -> @core.ConvertResult {
  // 读取 PPTX 文件内容
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
  let bytes = bytes_from_array(all_bytes)

  // 使用纯 MoonBit libzip 打开 ZIP
  match @libzip.ZipArchive::open(bytes) {
    Some(archive) =>
      // 解析 presentation.xml 获取幻灯片顺序
      match parse_presentation(archive) {
        Ok(slide_ids) => {
          if slide_ids.length() == 0 {
            // 调试：检查文件列表
            let files = archive.list_entries()
            let mut file_list = "Files: "
            for f in files {
              file_list = file_list + "[" + f + "] "
            }
            fail("No slides found. \{file_list}")
          }
          // 解析每张幻灯片并生成 Markdown
          let markdown = process_slides(archive, slide_ids)
          @core.ConvertResult::markdown_only(
            markdown.trim().to_string(),
            "pptx",
          )
        }
        Err(e) => fail("Failed to parse presentation: \{e}")
      }
    None => fail("Failed to open PPTX file as ZIP archive")
  }
}

///|
/// 将 Array[Byte] 转换为 Bytes
fn bytes_from_array(arr : Array[Byte]) -> Bytes {
  let buf = @buffer.new()
  for b in arr {
    buf.write_byte(b)
  }
  buf.to_bytes()
}
