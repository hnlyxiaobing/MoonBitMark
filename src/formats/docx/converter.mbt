// DOCX Converter - Pure MoonBit Implementation
// Converts Word documents (.docx) to Markdown

///|
/// Converter for DOCX files
pub(all) struct DocxConverter {
  dummy : Int
}

///|
/// Create a new DOCX converter
pub fn DocxConverter::new() -> DocxConverter {
  DocxConverter::{ dummy: 0 }
}

///|
/// Check if this converter accepts the given file
pub fn DocxConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.extension {
    Some(ext) => {
      let ext_lower = ext.to_lower().to_string()
      ext_lower == ".docx"
    }
    None => false
  }
}

///|
/// Convert a DOCX file to Markdown
pub async fn DocxConverter::convert(file_path : String) -> @core.ConvertResult {
  // 读取 DOCX 文件内容
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
      // 读取 word/document.xml
      match @libzip.read_file_entry_decompressed(archive, "word/document.xml") {
        Some(xml_bytes) => {
          // 解析 XML 并提取文本（正确 UTF-8 解码，避免 to_string() 返回调试格式）
          let xml_string = @utf8.decode(xml_bytes) catch {
            _ => fail("document.xml contains invalid UTF-8 sequence")
          }
          let markdown = extract_text_from_docx_xml(xml_string)
          @core.ConvertResult::markdown_only(
            markdown.trim().to_string(),
            "docx",
          )
        }
        None => fail("Failed to read document.xml from DOCX")
      }
    None => fail("Failed to open DOCX file as ZIP archive")
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

///|
/// 从 DOCX 的 XML 中提取文本内容
fn extract_text_from_docx_xml(xml : String) -> String {
  match @xml.parse_xml(xml) {
    Ok(events) => {
      // 解析 XML 事件，提取文本内容
      let result = process_docx_events(events)
      result
    }
    Err(_) => ""
  }
}

///|
/// DOCX 解析上下文
priv struct DocxContext {
  mut in_paragraph : Bool
  mut in_text : Bool
  mut current_text : String
  mut heading_level : Int
  mut in_list : Bool
  mut result : String
}

///|
/// 处理 DOCX XML 事件
fn process_docx_events(events : Array[@xml.ParseEvent]) -> String {
  let ctx = DocxContext::{
    in_paragraph: false,
    in_text: false,
    current_text: "",
    heading_level: 0,
    in_list: false,
    result: "",
  }

  for event in events {
    match event {
      @xml.ElementStart(evt) =>
        handle_element_start(ctx, evt.name, evt.attributes)
      @xml.ElementEnd(evt) => handle_element_end(ctx, evt.name)
      @xml.TextContent(evt) =>
        if ctx.in_text && ctx.in_paragraph {
          ctx.current_text = ctx.current_text + evt.content
        }
    }
  }

  ctx.result
}

///|
/// 处理元素开始
fn handle_element_start(
  ctx : DocxContext,
  name : String,
  attrs : Map[String, String],
) -> Unit {
  // 处理命名空间前缀 (如 w:t -> t)
  let local_name = strip_namespace(name)

  if local_name == "p" {
    ctx.in_paragraph = true
    ctx.heading_level = 0
    ctx.in_list = false

    // 检查段落样式
    match attrs.get("w:val") {
      Some(style) =>
        if style.has_prefix("Heading") {
          // 提取标题级别
          let level = parse_heading_level(style)
          ctx.heading_level = level
        } else if style.has_prefix("List") {
          ctx.in_list = true
        }
      None => ()
    }
  } else if local_name == "t" {
    ctx.in_text = true
  } else if local_name == "tab" {
    ctx.current_text = ctx.current_text + "\t"
  } else if local_name == "br" {
    ctx.current_text = ctx.current_text + "\n"
  }
}

///|
/// 解析标题级别
fn parse_heading_level(style : String) -> Int {
  // Heading1, Heading2, etc.
  if style.length() > 7 {
    // 获取第8个字符
    let ch = style[7]
    match ch {
      '1' => 1
      '2' => 2
      '3' => 3
      '4' => 4
      '5' => 5
      '6' => 6
      '7' => 7
      '8' => 8
      '9' => 9
      _ => 1
    }
  } else {
    1
  }
}

///|
/// 处理元素结束
fn handle_element_end(ctx : DocxContext, name : String) -> Unit {
  let local_name = strip_namespace(name)

  if local_name == "p" {
    ctx.in_paragraph = false

    if ctx.current_text.length() > 0 {
      // 添加标题标记
      if ctx.heading_level > 0 {
        let mut prefix = ""
        let mut i = 0
        while i < ctx.heading_level {
          prefix = prefix + "#"
          i = i + 1
        }
        ctx.result = ctx.result + prefix + " " + ctx.current_text + "\n\n"
      } else if ctx.in_list {
        // 添加列表标记
        ctx.result = ctx.result + "- " + ctx.current_text + "\n\n"
      } else {
        ctx.result = ctx.result + ctx.current_text + "\n\n"
      }
      ctx.current_text = ""
    }

    ctx.heading_level = 0
    ctx.in_list = false
  } else if local_name == "t" {
    ctx.in_text = false
  }
}

///|
/// 移除 XML 命名空间前缀
fn strip_namespace(name : String) -> String {
  match name.find(":") {
    Some(pos) => {
      // 从 pos+1 开始到结尾
      let mut result = ""
      let mut i = pos + 1
      while i < name.length() {
        let ch = name[i]
        result = result + ch.to_string()
        i = i + 1
      }
      result
    }
    None => name
  }
}
