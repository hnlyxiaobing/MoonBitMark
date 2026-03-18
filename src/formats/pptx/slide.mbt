// PPTX Slide Processing - Process slides and generate Markdown

///|
/// 处理幻灯片并生成 Markdown
pub fn process_slides(
  archive : @libzip.ZipArchive,
  slide_refs : Array[SlideRef],
) -> (Array[@ast.Block], Array[String]) {
  let blocks : Array[@ast.Block] = []
  let warnings : Array[String] = []

  if slide_refs.length() == 0 {
    return (blocks, warnings)
  }

  for slide_ref in slide_refs {
    let slide_path = slide_ref.slide_path
    match @libzip.read_file_entry_decompressed(archive, slide_path) {
      Some(xml_bytes) => {
        let xml_string = @utf8.decode(xml_bytes) catch {
          _ => "__PPTX_SLIDE_DECODE_ERROR__"
        }
        if xml_string == "__PPTX_SLIDE_DECODE_ERROR__" {
          warnings.push(
            "Failed to decode slide XML as UTF-8: Slide \{slide_ref.slide_num} (\{slide_path}).",
          )
        } else {
          let (slide_blocks, slide_warning) = process_slide_xml(
            xml_string,
            slide_ref.slide_num,
            slide_path,
          )
          match slide_warning {
            Some(warning) => warnings.push(warning)
            None => ()
          }
          for block in slide_blocks {
            blocks.push(block)
          }
        }
      }
      None =>
        warnings.push(
          "Failed to read slide XML: Slide \{slide_ref.slide_num} (\{slide_path}).",
        )
    }
  }

  (blocks, warnings)
}

///|
/// 处理单个幻灯片 XML
fn process_slide_xml(
  xml : String,
  slide_num : Int,
  slide_path : String,
) -> (Array[@ast.Block], String?) {
  match @xml.parse_xml(xml) {
    Ok(events) => {
      let blocks = extract_slide_blocks(events, slide_num)
      (blocks, None)
    }
    Err(_) =>
      (
        [],
        Some("Failed to parse slide XML: Slide \{slide_num} (\{slide_path})."),
      )
  }
}

///|
/// 幻灯片解析上下文
priv struct SlideContext {
  mut in_text : Bool
  mut current_text : String
  mut is_title : Bool
  blocks : Array[@ast.Block]
}

///|
fn extract_slide_blocks(
  events : Array[@xml.ParseEvent],
  slide_num : Int,
) -> Array[@ast.Block] {
  let ctx = SlideContext::{
    in_text: false,
    current_text: "",
    is_title: false,
    blocks: [@ast.Heading(2, "Slide " + slide_num.to_string())],
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

  ctx.blocks
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
        ctx.blocks.push(@ast.Heading(3, ctx.current_text))
      } else {
        ctx.blocks.push(@ast.text_paragraph(ctx.current_text))
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
