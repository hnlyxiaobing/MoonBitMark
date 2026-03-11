// PPTX Parser - Parse presentation.xml and slides

///|
/// 幻灯片引用信息
pub struct SlideRef {
  slide_num : Int
  r_id : String
  slide_path : String
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
  // 首先解析关系文件获取 r:id -> slide_path 映射
  let relations = parse_relations(archive)

  // 读取 presentation.xml
  match @libzip.read_file_entry_decompressed(archive, "ppt/presentation.xml") {
    Some(xml_bytes) => {
      let xml_string = @utf8.decode(xml_bytes) catch {
        _ => return Err("Failed to decode presentation.xml as UTF-8")
      }
      // 解析 XML 获取幻灯片 ID 列表
      match @xml.parse_xml(xml_string) {
        Ok(events) => {
          let slide_refs = extract_slide_refs(events, relations)
          // 如果没有找到幻灯片，返回调试信息
          if slide_refs.length() == 0 {
            Err("No sldId found in presentation.xml")
          } else {
            Ok(slide_refs)
          }
        }
        Err(_) => Err("Failed to parse presentation.xml")
      }
    }
    None => Err("Failed to read ppt/presentation.xml")
  }
}

///|
/// 解析关系文件
fn parse_relations(archive : @libzip.ZipArchive) -> Map[String, String] {
  let relations : Map[String, String] = Map::new()

  match
    @libzip.read_file_entry_decompressed(
      archive, "ppt/_rels/presentation.xml.rels",
    ) {
    Some(xml_bytes) => {
      let xml_string = @utf8.decode(xml_bytes) catch { _ => return relations }
      match @xml.parse_xml(xml_string) {
        Ok(events) => extract_relations(events, relations)
        Err(_) => ()
      }
    }
    None => ()
  }
  relations
}

///|
/// 关系解析上下文
priv struct RelationsContext {
  relations : Map[String, String]
}

///|
/// 从关系文件中提取映射
fn extract_relations(
  events : Array[@xml.ParseEvent],
  relations : Map[String, String],
) -> Unit {
  let ctx = RelationsContext::{ relations, }

  for event in events {
    match event {
      @xml.ElementStart(evt) => handle_relation_element_start(ctx, evt)
      @xml.ElementEnd(_) => ()
      @xml.TextContent(_) => ()
    }
  }
}

///|
/// 处理关系元素开始
fn handle_relation_element_start(
  ctx : RelationsContext,
  evt : @xml.ElementStartEvent,
) -> Unit {
  let local_name = strip_ns_prefix(evt.name)

  if local_name == "Relationship" {
    // 提取 Id 和 Target 属性
    let id = match evt.attributes.get("Id") {
      Some(v) => v.to_string()
      None => ""
    }
    let target = match evt.attributes.get("Target") {
      Some(v) => v.to_string()
      None => ""
    }
    let type_val = match evt.attributes.get("Type") {
      Some(v) => v.to_string()
      None => ""
    }

    // 只处理幻灯片类型的关系
    let is_slide = type_val.has_suffix("relationships/slide")

    if id.length() > 0 && target.length() > 0 && is_slide {
      // target 格式是 "slides/slide1.xml"，需要添加 "ppt/" 前缀
      ctx.relations.set(id, "ppt/\{target}")
    }
  }
}

///|
/// PPTX 解析上下文
priv struct PresentationContext {
  mut in_sld_id_lst : Bool
  mut slide_num : Int
  relations : Map[String, String]
  slide_refs : Array[SlideRef]
}

///|
/// 从 XML 事件中提取幻灯片引用列表
fn extract_slide_refs(
  events : Array[@xml.ParseEvent],
  relations : Map[String, String],
) -> Array[SlideRef] {
  let ctx = PresentationContext::{
    in_sld_id_lst: false,
    slide_num: 0,
    relations,
    slide_refs: Array::new(),
  }

  for event in events {
    match event {
      @xml.ElementStart(evt) => {
        let name = evt.name
        let local = strip_ns_prefix(name)
        // 调试：检查所有元素
        // 检查 sldIdLst 和 sldId
        if local == "sldIdLst" {
          ctx.in_sld_id_lst = true
        } else if local == "sldId" && ctx.in_sld_id_lst {
          // 处理 sldId 元素
          handle_sld_id_element(ctx, evt)
        }
      }
      @xml.ElementEnd(evt) => {
        let local = strip_ns_prefix(evt.name)
        if local == "sldIdLst" {
          ctx.in_sld_id_lst = false
        }
      }
      @xml.TextContent(_) => ()
    }
  }

  ctx.slide_refs
}

///|
/// 处理 sldId 元素
fn handle_sld_id_element(
  ctx : PresentationContext,
  evt : @xml.ElementStartEvent,
) -> Unit {
  // 提取 r:id 属性
  // 注意：属性可能存储为不同的形式
  let r_id_val = evt.attributes.get("r:id")

  match r_id_val {
    Some(r_id) => {
      ctx.slide_num = ctx.slide_num + 1
      // 从关系中获取实际路径
      let slide_path = match ctx.relations.get(r_id) {
        Some(path) => path.to_string()
        None => "ppt/slides/slide\{ctx.slide_num}.xml"
      }
      ctx.slide_refs.push(SlideRef::{
        slide_num: ctx.slide_num,
        r_id: r_id.to_string(),
        slide_path,
      })
    }
    None => ()
  }
}

///|
/// 处理 presentation.xml 元素开始 (已弃用)
fn handle_presentation_element_start(
  ctx : PresentationContext,
  evt : @xml.ElementStartEvent,
) -> Unit {
  let local_name = strip_ns_prefix(evt.name)

  if local_name == "sldIdLst" {
    ctx.in_sld_id_lst = true
  } else if local_name == "sldId" && ctx.in_sld_id_lst {
    // 提取 r:id 属性
    // 注意：r:id 可能存储为 "r:id" 而不是带命名空间的完整形式
    let r_id_val = match evt.attributes.get("r:id") {
      Some(v) => Some(v)
      None => evt.attributes.get("rId") // 有些文件可能用 rId
    }

    match r_id_val {
      Some(r_id) => {
        ctx.slide_num = ctx.slide_num + 1
        // 从关系中获取实际路径
        let slide_path = match ctx.relations.get(r_id) {
          Some(path) => path.to_string()
          None => "ppt/slides/slide\{ctx.slide_num}.xml"
        }
        ctx.slide_refs.push(SlideRef::{
          slide_num: ctx.slide_num,
          r_id: r_id.to_string(),
          slide_path,
        })
      }
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
