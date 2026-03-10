// PPTX Slide Processing - Process slides and generate Markdown

///|
/// 处理幻灯片并生成 Markdown
pub fn process_slides(
  archive : @libzip.ZipArchive,
  slide_refs : Array[SlideRef],
) -> String {
  let mut markdown = ""

  // 如果没有幻灯片，返回提示
  if slide_refs.length() == 0 {
    return "<!-- No slides found in presentation -->"
  }

  for slide_ref in slide_refs {
    // 使用关系文件中获取的路径
    let slide_path = slide_ref.slide_path

    // 读取幻灯片内容
    match @libzip.read_file_entry_decompressed(archive, slide_path) {
      Some(xml_bytes) => {
        let xml_string = try {
          @utf8.decode(xml_bytes)
        } catch {
          _ => return "<!-- Failed to decode slide \{slide_ref.slide_num} -->"
        }
        let slide_md = process_slide_xml(xml_string, slide_ref.slide_num)
        markdown = markdown + slide_md
      }
      None => {
        // 幻灯片文件不存在，跳过
        markdown = markdown + "\n\n<!-- Slide \{slide_ref.slide_num}: Unable to read \{slide_path} -->\n"
      }
    }
  }

  markdown
}

///|
/// 处理单个幻灯片 XML
fn process_slide_xml(xml : String, slide_num : Int) -> String {
  match @xml.parse_xml(xml) {
    Ok(events) => {
      // 添加幻灯片分隔符
      let header = "\n\n<!-- Slide number: \{slide_num} -->\n"
      let content = extract_slide_content(events)
      header + content
    }
    Err(_) => "<!-- Slide \{slide_num}: Parse error -->\n"
  }
}

///|
/// 幻灯片解析上下文
priv struct SlideContext {
  mut in_text : Bool
  mut current_text : String
  mut result : String
  mut is_title : Bool
}

///|
/// 从幻灯片 XML 事件中提取内容
fn extract_slide_content(events : Array[@xml.ParseEvent]) -> String {
  let ctx = SlideContext::{
    in_text: false,
    current_text: "",
    result: "",
    is_title: false,
  }

  for event in events {
    match event {
      @xml.ElementStart(evt) => handle_slide_element_start(ctx, evt)
      @xml.ElementEnd(evt) => handle_slide_element_end(ctx, evt.name)
      @xml.TextContent(evt) =>
        if ctx.in_text {
          ctx.current_text = ctx.current_text + evt.content
        }
    }
  }

  ctx.result
}

///|
/// 处理幻灯片元素开始
fn handle_slide_element_start(
  ctx : SlideContext,
  evt : @xml.ElementStartEvent,
) -> Unit {
  let local_name = remove_ns_prefix(evt.name)

  // <a:t> - 文本内容
  if local_name == "t" {
    ctx.in_text = true
    // <a:p> - 段落
  } else if local_name == "p" {
    ctx.current_text = ""
    ctx.is_title = false
    // 检查是否为标题形状 (通过 p:nvSpPr/p:cNvPr 的 name 属性)
  } else if local_name == "cNvPr" {
    match evt.attributes.get("name") {
      Some(name) => {
        let name_lower = name.to_lower()
        if name_lower.has_prefix("title") {
          ctx.is_title = true
        }
      }
      None => ()
    }
  }
}

///|
/// 处理幻灯片元素结束
fn handle_slide_element_end(ctx : SlideContext, name : String) -> Unit {
  let local_name = remove_ns_prefix(name)

  if local_name == "t" {
    ctx.in_text = false
  } else if local_name == "p" {
    if ctx.current_text.length() > 0 {
      if ctx.is_title {
        ctx.result = ctx.result + "# " + ctx.current_text + "\n\n"
      } else {
        ctx.result = ctx.result + ctx.current_text + "\n\n"
      }
    }
    ctx.current_text = ""
    ctx.is_title = false
  }
}

///|
/// 移除 XML 命名空间前缀
fn remove_ns_prefix(name : String) -> String {
  match name.find(":") {
    Some(pos) => {
      // 从 pos+1 开始截取子字符串
      let start = pos + 1
      // 使用 iter 跳过前缀
      let chars = name.iter()
      let mut result = ""
      let mut i = 0
      for ch in chars {
        if i >= start {
          result = result + ch.to_string()
        }
        i = i + 1
      }
      result
    }
    None => name
  }
}
