// PPTX Parser - Parse presentation.xml and slides

///|
/// 幻灯片引用信息
pub struct SlideRef {
  slide_num : Int
  r_id : String
}

///|
/// 解析结果类型
pub enum ParseResult {
  Ok(Array[SlideRef])
  Err(String)
}

///|
/// 解析 presentation.xml 获取幻灯片顺序
pub fn parse_presentation(archive : @libzip.ZipArchive) -> ParseResult {
  // 读取 presentation.xml
  match @libzip.read_file_entry_decompressed(archive, "ppt/presentation.xml") {
    Some(xml_bytes) => {
      let xml_string = xml_bytes.to_string()
      // 解析 XML 获取幻灯片 ID 列表
      match @xml.parse_xml(xml_string) {
        Ok(events) => {
          let slide_refs = extract_slide_refs(events)
          Ok(slide_refs)
        }
        Err(_) => Err("Failed to parse presentation.xml")
      }
    }
    None => Err("Failed to read ppt/presentation.xml")
  }
}

///|
/// PPTX 解析上下文
priv struct PresentationContext {
  mut in_sld_id_lst : Bool
  slide_refs : Array[SlideRef]
}

///|
/// 从 XML 事件中提取幻灯片引用列表
fn extract_slide_refs(events : Array[@xml.ParseEvent]) -> Array[SlideRef] {
  let ctx = PresentationContext::{
    in_sld_id_lst: false,
    slide_refs: Array::new(),
  }

  for event in events {
    match event {
      @xml.ElementStart(evt) => handle_presentation_element_start(ctx, evt)
      @xml.ElementEnd(evt) => handle_presentation_element_end(ctx, evt.name)
      @xml.TextContent(_) => () // 忽略文本内容
    }
  }

  ctx.slide_refs
}

///|
/// 处理 presentation.xml 元素开始
fn handle_presentation_element_start(
  ctx : PresentationContext,
  evt : @xml.ElementStartEvent,
) -> Unit {
  let local_name = strip_ns_prefix(evt.name)

  if local_name == "sldIdLst" {
    ctx.in_sld_id_lst = true
  } else if local_name == "sldId" && ctx.in_sld_id_lst {
    // 提取 r:id 属性
    match evt.attributes.get("r:id") {
      Some(r_id) =>
        ctx.slide_refs.push(SlideRef::{
          slide_num: ctx.slide_refs.length() + 1,
          r_id: r_id.to_string(),
        })
      None => ()
    }
  }
}

///|
/// 处理 presentation.xml 元素结束
fn handle_presentation_element_end(
  ctx : PresentationContext,
  name : String,
) -> Unit {
  let local_name = strip_ns_prefix(name)
  if local_name == "sldIdLst" {
    ctx.in_sld_id_lst = false
  }
}

///|
/// 移除 XML 命名空间前缀
fn strip_ns_prefix(name : String) -> String {
  match name.find(":") {
    Some(pos) => {
      let mut result = ""
      let mut i = pos + 1
      while i < name.length() {
        result = result + name[i].to_string()
        i = i + 1
      }
      result
    }
    None => name
  }
}
