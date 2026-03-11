# EPUB 转换器开发计划

## 1. 概述

本文档描述了为 MoonBitMark 项目添加 EPUB 电子书转换器的开发计划。EPUB 转换器将把 `.epub` 文件转换为 Markdown 格式，遵循项目现有架构模式。

### 1.1 参考资料

- **原项目实现**: [MarkItDown EPUB Converter](https://github.com/microsoft/markitdown/blob/main/packages/markitdown/src/markitdown/converters/_epub_converter.py)
- **本地参考代码**: `C:\Users\hnlyh\.openclaw\workspace\moonbitmark_prj_ws\moonbitmark_code_ref\markitdown\packages\markitdown\src\markitdown\converters\_epub_converter.py`
- **EPUB 格式规范**: [EPUB 3.2 Specification](https://www.w3.org/publishing/epub32/epub-spec.html)
- **项目架构参考**: `src/formats/docx/converter.mbt`, `src/formats/html/converter.mbt`, `src/core/types.mbt`

### 1.2 技术选型与架构对齐

采用纯 MoonBit 实现，复用现有基础设施：
- **libzip**: 解析 ZIP 结构 (复用现有实现)
- **xml parser**: SAX风格XML解析 (复用现有实现)
- **html converter**: 复用现有 HTML 转 Markdown 功能
- **异步I/O**: 遵循项目async/await模式
- **统一接口**: 实现DocumentConverter trait，返回ConvertResult

### 1.3 与现有架构的一致性

| 方面 | 现有模式 | EPUB实现方式 |
|------|----------|-------------|
| 接口 | DocumentConverter trait | 实现accepts() + convert() |
| 错误处理 | fail() 宏 | 使用 fail() 处理错误 |
| 异步 | async函数 + raise | async convert() |
| 类型 | pub(all)/pub(open)可见性 | 遵循相同可见性规则 |
| 组织 | 块式组织(///|分隔) | 采用相同组织方式 |

---

## 2. EPUB 文件格式分析

### 2.1 EPUB 文件结构

EPUB 文件本质是一个 ZIP 压缩包，内部结构如下：

```
example.epub
├── mimetype                          # MIME 类型声明 (application/epub+zip)
├── META-INF/
│   └── container.xml                 # 入口文件，指向 OPF 文件路径
├── EPUB/                             # 内容目录（名称可变）
│   ├── content.opf                   # OPF 文件：元数据 + 资源清单 + 阅读顺序
│   ├── toc.ncx                       # 导航控制文件 (NCX)
│   ├── nav.xhtml                     # EPUB3 导航文档
│   ├── Styles/                       # 样式文件
│   │   └── stylesheet.css
│   ├── Text/                         # 章节内容
│   │   ├── chapter1.xhtml
│   │   ├── chapter2.xhtml
│   │   └── ...
│   └── Images/                       # 图片资源
│       ├── cover.jpg
│       └── ...
```

### 2.2 关键文件详解

#### 2.2.1 `META-INF/container.xml` - 入口文件

EPUB 的入口文件，指向 OPF (Open Package Format) 文件路径：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
  <rootfiles>
    <rootfile media-type="application/oebps-package+xml" full-path="EPUB/content.opf"/>
  </rootfiles>
</container>
```

**关键信息**：`full-path` 属性指向 OPF 文件的路径。

#### 2.2.2 `content.opf` - 包文件

包含书籍的元数据、资源清单 (manifest) 和阅读顺序 (spine)：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="id" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>书名</dc:title>
    <dc:creator>作者</dc:creator>
    <dc:language>zh</dc:language>
    <dc:publisher>出版社</dc:publisher>
    <dc:date>2024</dc:date>
    <dc:description>书籍简介...</dc:description>
    <meta property="dcterms:modified">2024-01-01T00:00:00Z</meta>
  </metadata>

  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="chapter1" href="Text/chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="chapter2" href="Text/chapter2.xhtml" media-type="application/xhtml+xml"/>
    <item id="cover" href="Images/cover.jpg" media-type="image/jpeg"/>
    <!-- 其他资源... -->
  </manifest>

  <spine toc="ncx">
    <itemref idref="chapter1"/>
    <itemref idref="chapter2"/>
    <!-- 按阅读顺序排列... -->
  </spine>
</package>
```

**关键组件**：
- **metadata**: 书籍元数据（标题、作者、语言等）
- **manifest**: 资源清单，ID → href 映射
- **spine**: 阅读顺序，定义章节排列顺序

#### 2.2.3 章节文件 (XHTML)

EPUB 章节内容使用 XHTML 格式：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head>
  <title>第一章</title>
  <link rel="stylesheet" type="text/css" href="../Styles/stylesheet.css"/>
</head>
<body>
  <h1>第一章 标题</h1>
  <p>段落内容...</p>
  <img src="../Images/figure1.png" alt="图片描述"/>
</body>
</html>
```

### 2.3 EPUB 版本差异

| 特性 | EPUB 2.0 | EPUB 3.0/3.2 |
|------|----------|--------------|
| 导航 | NCX (toc.ncx) | nav.xhtml (HTML导航) |
| 内容格式 | XHTML 1.1 | HTML5/XHTML5 |
| 脚本 | 不支持 | 支持 JavaScript |
| 多媒体 | 有限支持 | 原生支持音视频 |

**本实现策略**: 优先支持 EPUB 3.x，兼容 EPUB 2.x 的核心内容提取。

---

## 3. 原版 MarkItDown 实现分析

### 3.1 核心转换逻辑

原版 Python 实现的核心流程：

```python
class EpubConverter(HtmlConverter):
    def convert(self, file_stream, stream_info, **kwargs):
        with zipfile.ZipFile(file_stream, "r") as z:
            # 1. 解析 container.xml 获取 OPF 路径
            container_dom = minidom.parse(z.open("META-INF/container.xml"))
            opf_path = container_dom.getElementsByTagName("rootfile")[0].getAttribute("full-path")

            # 2. 解析 OPF 文件
            opf_dom = minidom.parse(z.open(opf_path))

            # 3. 提取元数据
            metadata = {
                "title": get_text(opf_dom, "dc:title"),
                "authors": get_all_texts(opf_dom, "dc:creator"),
                "language": get_text(opf_dom, "dc:language"),
                "publisher": get_text(opf_dom, "dc:publisher"),
                "date": get_text(opf_dom, "dc:date"),
                "description": get_text(opf_dom, "dc:description"),
            }

            # 4. 构建 manifest 映射 (id -> href)
            manifest = {}
            for item in opf_dom.getElementsByTagName("item"):
                manifest[item.getAttribute("id")] = item.getAttribute("href")

            # 5. 提取 spine 顺序
            spine_ids = []
            for itemref in opf_dom.getElementsByTagName("itemref"):
                spine_ids.append(itemref.getAttribute("idref"))

            # 6. 按 spine 顺序转换章节
            markdown_content = []
            for idref in spine_ids:
                href = manifest[idref]
                opf_dir = os.path.dirname(opf_path)
                full_path = os.path.join(opf_dir, href) if opf_dir else href

                with z.open(full_path) as chapter_file:
                    # 使用 HtmlConverter 转换 XHTML
                    result = self._html_converter.convert(chapter_file, ...)
                    markdown_content.append(result.markdown.strip())

            # 7. 组装最终输出
            output = format_metadata(metadata)
            output += "\n\n".join(markdown_content)

            return DocumentConverterResult(markdown=output, title=metadata["title"])
```

### 3.2 关键设计决策

1. **继承 HtmlConverter**: 复用 HTML 转 Markdown 的逻辑
2. **元数据提取**: 从 OPF 的 `<metadata>` 元素提取 Dublin Core 元数据
3. **路径处理**: OPF 文件可能在子目录，需要正确处理相对路径
4. **章节顺序**: 严格按照 spine 定义的顺序处理章节

### 3.3 输出格式示例

```markdown
**Title:** 书名
**Authors:** 作者1, 作者2
**Language:** zh
**Publisher:** 出版社
**Date:** 2024
**Description:** 书籍简介...

# 第一章 标题

这是第一章的内容...

## 1.1 小节

更多内容...

# 第二章 标题

这是第二章的内容...
```

---

## 4. 纯 MoonBit 实现方案

### 4.1 项目结构

```
src/formats/epub/
├── moon.pkg.json          # 包定义，依赖core, libzip, xml, html
├── converter.mbt          # 主转换器，实现DocumentConverter接口
├── types.mbt              # EPUB特定类型定义
├── parser.mbt             # OPF/Container XML解析
└── converter_test.mbt     # 测试文件
```

### 4.2 核心数据结构

```moonbit
///| EPUB 元数据
pub(all) struct EpubMetadata {
  pub title : Option[String]
  pub authors : Array[String]
  pub language : Option[String]
  pub publisher : Option[String]
  pub date : Option[String]
  pub description : Option[String]
  pub identifier : Option[String]
} derive(Show, Eq)

///| Manifest 项
pub(all) struct ManifestItem {
  pub id : String
  pub href : String
  pub media_type : String
  pub properties : Option[String]
} derive(Show, Eq)

///| Spine 项
pub(all) struct SpineItem {
  pub idref : String
  pub linear : Bool  // 是否按顺序阅读
} derive(Show, Eq)

///| EPUB 包信息
pub(all) struct EpubPackage {
  pub metadata : EpubMetadata
  pub manifest : Map[String, ManifestItem]  // id -> item
  pub spine : Array[SpineItem]
  pub opf_dir : String  // OPF 文件所在目录，用于路径拼接
} derive(Show)

///| EPUB 转换器
pub(all) struct EpubConverter {
  dummy : Int
}
```

### 4.3 转换流程

```
┌─────────────────────────────────────────────────────────────────────┐
│                         EPUB 文件                                    │
└─────────────────────────────┬───────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  1. ZIP 解析 (@libzip.ZipArchive::open)                              │
│     - 读取文件为 Bytes                                                │
│     - 打开 ZIP 归档                                                   │
└─────────────────────────────┬───────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  2. 解析 container.xml                                               │
│     - 读取 META-INF/container.xml                                    │
│     - 提取 OPF 文件路径 (full-path 属性)                              │
└─────────────────────────────┬───────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  3. 解析 OPF 文件                                                    │
│     - 提取 metadata (dc:title, dc:creator, ...)                      │
│     - 构建 manifest (id -> href 映射)                                │
│     - 提取 spine (阅读顺序)                                           │
│     - 记录 OPF 文件目录路径                                           │
└─────────────────────────────┬───────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  4. 按 spine 顺序转换章节                                             │
│     - 遍历 spine 中的每个 idref                                       │
│     - 从 manifest 获取对应的 href                                     │
│     - 拼接完整路径 (opf_dir + href)                                   │
│     - 读取 XHTML 文件内容                                             │
│     - 调用 html_to_markdown() 转换                                    │
└─────────────────────────────┬───────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  5. 组装输出                                                          │
│     - 格式化元数据为 Markdown 表头                                     │
│     - 用分隔线连接各章节                                               │
│     - 返回 ConvertResult { markdown, title, metadata }               │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.4 关键实现代码

#### 4.4.1 转换器接口实现

```moonbit
///| EPUB转换器实现
pub(all) struct EpubConverter {
  dummy : Int
}

///| 创建EPUB转换器
pub fn EpubConverter::new() -> EpubConverter {
  EpubConverter::{ dummy: 0 }
}

///| 检查是否接受EPUB文件
pub fn EpubConverter::accepts(info : @core.StreamInfo) -> Bool {
  // 检查扩展名
  match info.extension {
    Some(ext) => {
      let ext_lower = ext.to_lower().to_string()
      if ext_lower == ".epub" {
        return true
      }
    }
    None => ()
  }

  // 检查 MIME 类型
  match info.mimetype {
    Some(mt) => {
      let mt_lower = mt.to_lower().to_string()
      mt_lower.has_prefix("application/epub") ||
      mt_lower == "application/epub+zip"
    }
    None => false
  }
}

///| 异步转换EPUB文件
pub async fn EpubConverter::convert(file_path : String) -> String {
  // 读取文件内容
  let file = @fs.open(file_path, mode=ReadOnly)
  let all_bytes : Array[Byte] = Array::new()

  while true {
    let buffer : FixedArray[Byte] = FixedArray::make(4096, b'\x00')
    let bytes_read = file.read(buffer)
    if bytes_read == 0 {
      break
    }
    let mut i = 0
    while i < bytes_read {
      all_bytes.push(buffer[i])
      i = i + 1
    }
  }
  file.close()

  let bytes = bytes_from_array(all_bytes)

  // 使用 libzip 打开 ZIP
  match @libzip.ZipArchive::open(bytes) {
    Some(archive) => {
      let result = process_epub(archive)
      result
    }
    None => fail("Failed to open EPUB file as ZIP archive")
  }
}
```

#### 4.4.2 Container.xml 解析

```moonbit
///| 解析 container.xml 获取 OPF 文件路径
fn parse_container_xml(archive : @libzip.ZipArchive) -> String {
  match @libzip.read_file_entry_decompressed(archive, "META-INF/container.xml") {
    Some(xml_bytes) => {
      let xml_string = xml_bytes.to_string()
      match @xml.parse_xml(xml_string) {
        Ok(events) => extract_opf_path(events)
        Err(_) => fail("Failed to parse container.xml")
      }
    }
    None => fail("META-INF/container.xml not found in EPUB")
  }
}

///| 从 XML 事件中提取 OPF 路径
fn extract_opf_path(events : Array[@xml.ParseEvent]) -> String {
  let mut in_rootfile = false
  let mut opf_path = ""

  for event in events {
    match event {
      @xml.ElementStart(evt) => {
        let local_name = strip_namespace(evt.name)
        if local_name == "rootfile" {
          in_rootfile = true
          // 从属性中获取 full-path
          match evt.attributes.get("full-path") {
            Some(path) => opf_path = path
            None => ()
          }
        }
      }
      _ => ()
    }
  }

  if opf_path == "" {
    fail("full-path attribute not found in container.xml")
  }
  opf_path
}
```

#### 4.4.3 OPF 解析

```moonbit
///| OPF 解析上下文
priv struct OpfParseContext {
  mut in_metadata : Bool
  mut in_manifest : Bool
  mut in_spine : Bool
  mut current_dc_element : String
  mut current_text : String
  mut metadata : EpubMetadata
  mut manifest_items : Array[ManifestItem]
  mut spine_items : Array[SpineItem]
}

///| 解析 OPF 文件
fn parse_opf(archive : @libzip.ZipArchive, opf_path : String) -> EpubPackage {
  match @libzip.read_file_entry_decompressed(archive, opf_path) {
    Some(xml_bytes) => {
      let xml_string = xml_bytes.to_string()
      match @xml.parse_xml(xml_string) {
        Ok(events) => {
          let ctx = OpfParseContext::{
            in_metadata: false,
            in_manifest: false,
            in_spine: false,
            current_dc_element: "",
            current_text: "",
            metadata: EpubMetadata::default(),
            manifest_items: Array::new(),
            spine_items: Array::new(),
          }
          process_opf_events(events, ctx)

          // 构建 manifest map
          let manifest_map : Map[String, ManifestItem] = Map::new()
          for item in ctx.manifest_items {
            manifest_map.insert(item.id, item)
          }

          // 获取 OPF 目录路径
          let opf_dir = get_parent_dir(opf_path)

          EpubPackage::{
            metadata: ctx.metadata,
            manifest: manifest_map,
            spine: ctx.spine_items,
            opf_dir: opf_dir,
          }
        }
        Err(_) => fail("Failed to parse OPF file")
      }
    }
    None => fail("OPF file not found: " + opf_path)
  }
}

///| 处理 OPF XML 事件
fn process_opf_events(events : Array[@xml.ParseEvent], ctx : OpfParseContext) -> Unit {
  for event in events {
    match event {
      @xml.ElementStart(evt) => handle_opf_element_start(ctx, evt)
      @xml.ElementEnd(evt) => handle_opf_element_end(ctx, evt.name)
      @xml.TextContent(evt) => {
        if ctx.current_dc_element != "" {
          ctx.current_text = ctx.current_text + evt.content.to_string()
        }
      }
    }
  }
}

///| 处理 OPF 元素开始
fn handle_opf_element_start(ctx : OpfParseContext, evt : @xml.ElementStartEvent) -> Unit {
  let local_name = strip_namespace(evt.name)

  if local_name == "metadata" {
    ctx.in_metadata = true
  } else if local_name == "manifest" {
    ctx.in_manifest = true
  } else if local_name == "spine" {
    ctx.in_spine = true
  } else if ctx.in_metadata {
    // Dublin Core 元素
    if local_name == "title" || local_name == "creator" ||
       local_name == "language" || local_name == "publisher" ||
       local_name == "date" || local_name == "description" ||
       local_name == "identifier" {
      ctx.current_dc_element = local_name
      ctx.current_text = ""
    }
  } else if ctx.in_manifest && local_name == "item" {
    // Manifest item
    let id = evt.attributes.get("id").or("")
    let href = evt.attributes.get("href").or("")
    let media_type = evt.attributes.get("media-type").or("")
    let properties = evt.attributes.get("properties")

    ctx.manifest_items.push(ManifestItem::{
      id: id,
      href: href,
      media_type: media_type,
      properties: properties,
    })
  } else if ctx.in_spine && local_name == "itemref" {
    // Spine item
    let idref = evt.attributes.get("idref").or("")
    let linear = evt.attributes.get("linear").or("yes") == "yes"

    ctx.spine_items.push(SpineItem::{
      idref: idref,
      linear: linear,
    })
  }
}

///| 处理 OPF 元素结束
fn handle_opf_element_end(ctx : OpfParseContext, name : String) -> Unit {
  let local_name = strip_namespace(name)

  if local_name == "metadata" {
    ctx.in_metadata = false
  } else if local_name == "manifest" {
    ctx.in_manifest = false
  } else if local_name == "spine" {
    ctx.in_spine = false
  } else if ctx.in_metadata && ctx.current_dc_element != "" {
    // 保存 DC 元素值
    let text = ctx.current_text.trim().to_string()
    if local_name == "title" {
      ctx.metadata.title = Some(text)
    } else if local_name == "creator" {
      ctx.metadata.authors.push(text)
    } else if local_name == "language" {
      ctx.metadata.language = Some(text)
    } else if local_name == "publisher" {
      ctx.metadata.publisher = Some(text)
    } else if local_name == "date" {
      ctx.metadata.date = Some(text)
    } else if local_name == "description" {
      ctx.metadata.description = Some(text)
    } else if local_name == "identifier" {
      ctx.metadata.identifier = Some(text)
    }
    ctx.current_dc_element = ""
    ctx.current_text = ""
  }
}
```

#### 4.4.4 章节转换

```moonbit
///| 处理 EPUB 转换
fn process_epub(archive : @libzip.ZipArchive) -> String {
  // 1. 解析 container.xml
  let opf_path = parse_container_xml(archive)

  // 2. 解析 OPF
  let package = parse_opf(archive, opf_path)

  // 3. 构建输出
  let mut result = format_metadata(package.metadata)

  // 4. 按 spine 顺序转换章节
  for spine_item in package.spine {
    // 跳过非线性项（可选）
    if !spine_item.linear {
      continue
    }

    match package.manifest.get(spine_item.idref) {
      Some(manifest_item) => {
        // 只处理 HTML/XHTML 内容
        if is_html_content(manifest_item.media_type) {
          // 拼接完整路径
          let full_path = if package.opf_dir == "" {
            manifest_item.href
          } else {
            package.opf_dir + "/" + manifest_item.href
          }

          // 读取并转换章节
          match @libzip.read_file_entry_decompressed(archive, full_path) {
            Some(content_bytes) => {
              let html = content_bytes.to_string()
              let chapter_md = @html.html_to_markdown(html)
              result = result + "\n\n---\n\n" + chapter_md.trim().to_string()
            }
            None => () // 跳过无法读取的章节
          }
        }
      }
      None => ()
    }
  }

  result
}

///| 格式化元数据
fn format_metadata(metadata : EpubMetadata) -> String {
  let mut lines : Array[String] = Array::new()

  match metadata.title {
    Some(t) => lines.push("**Title:** " + t)
    None => ()
  }

  if metadata.authors.length() > 0 {
    lines.push("**Authors:** " + metadata.authors.join(", "))
  }

  match metadata.language {
    Some(l) => lines.push("**Language:** " + l)
    None => ()
  }

  match metadata.publisher {
    Some(p) => lines.push("**Publisher:** " + p)
    None => ()
  }

  match metadata.date {
    Some(d) => lines.push("**Date:** " + d)
    None => ()
  }

  match metadata.description {
    Some(d) => lines.push("**Description:** " + d)
    None => ()
  }

  lines.join("\n")
}

///| 检查是否为 HTML 内容类型
fn is_html_content(media_type : String) -> Bool {
  let mt_lower = media_type.to_lower().to_string()
  mt_lower == "application/xhtml+xml" ||
  mt_lower == "text/html" ||
  mt_lower.has_prefix("application/xhtml") ||
  mt_lower.has_prefix("text/html")
}

///| 获取父目录路径
fn get_parent_dir(path : String) -> String {
  match path.find_last("/") {
    Some(pos) => path[:pos].to_string()
    None => ""
  }
}
```

---

## 5. 开发计划

### 5.1 任务分解

| 阶段 | 任务 | 优先级 | 依赖 |
|------|------|--------|------|
| **阶段 1: 基础框架** | | | |
| 1.1 | 创建 `src/formats/epub/` 目录结构 | P0 | - |
| 1.2 | 实现 `moon.pkg.json` 包定义 | P0 | - |
| 1.3 | 实现 `types.mbt` 类型定义 | P0 | - |
| 1.4 | 实现 `EpubConverter::new()` 和 `accepts()` | P0 | - |
| **阶段 2: ZIP 和 XML 解析** | | | |
| 2.1 | 实现 container.xml 解析 | P0 | libzip, xml |
| 2.2 | 实现 OPF 元数据解析 | P0 | 阶段2.1 |
| 2.3 | 实现 OPF manifest 解析 | P0 | 阶段2.1 |
| 2.4 | 实现 OPF spine 解析 | P0 | 阶段2.1 |
| **阶段 3: 内容转换** | | | |
| 3.1 | 实现章节路径拼接逻辑 | P0 | 阶段2 |
| 3.2 | 集成 HtmlConverter 转换章节 | P0 | 阶段3.1 |
| 3.3 | 实现元数据格式化输出 | P0 | 阶段2.2 |
| 3.4 | 实现完整转换流程 | P0 | 阶段3.1-3.3 |
| **阶段 4: CLI 集成** | | | |
| 4.1 | 注册 EPUB 格式到 CLI | P0 | 阶段3 |
| 4.2 | 测试基本转换功能 | P0 | 阶段4.1 |
| **阶段 5: 测试与优化** | | | |
| 5.1 | 编写单元测试 | P1 | 阶段4 |
| 5.2 | 添加测试用 EPUB 文件 | P1 | - |
| 5.3 | 快照测试 | P1 | 阶段5.1-5.2 |
| 5.4 | 处理边缘情况 | P2 | 阶段5.3 |

### 5.2 文件创建清单

```
src/formats/epub/
├── moon.pkg.json          # 包定义
├── converter.mbt          # 主转换器实现
├── types.mbt              # 类型定义
├── parser.mbt             # XML解析逻辑
└── converter_test.mbt     # 测试

moon.pkg.json 内容:
{
  "import": [
    "moonbitlang/moonbitmark/src/core",
    "moonbitlang/moonbitmark/src/libzip",
    "moonbitlang/moonbitmark/src/xml",
    "moonbitlang/moonbitmark/src/formats/html",
    "moonbitlang/async/fs"
  ]
}
```

### 5.3 CLI 注册示例

在 `cmd/main/main.mbt` 中添加：

```moonbit
// 在 convert_file 函数中添加 EPUB 格式检测
if @epub.EpubConverter::accepts(info) {
  let markdown = @epub.EpubConverter::convert(file_path)
  // ...
}
```

### 5.4 测试策略

1. **单元测试**: 测试 container.xml 和 OPF 解析逻辑
2. **集成测试**: 使用真实 EPUB 文件测试完整转换流程
3. **快照测试**: 验证输出格式符合预期
4. **边缘情况测试**:
   - OPF 在根目录 vs 子目录
   - 缺失的元数据字段
   - 空的 spine
   - 非线性章节处理

---

## 6. Markdown 输出格式

### 6.1 标准输出格式

```markdown
**Title:** 书名
**Authors:** 作者1, 作者2
**Language:** zh
**Publisher:** 出版社
**Date:** 2024
**Description:** 书籍简介...

---

# 第一章 标题

第一章的内容...

## 1.1 小节

更多内容...

---

# 第二章 标题

第二章的内容...
```

### 6.2 ConvertResult 结构

```moonbit
ConvertResult {
  markdown: "...",  // 完整的 Markdown 内容
  title: Some("书名"),  // 从元数据提取的标题
  metadata: Map::from([
    ("authors", "作者1, 作者2"),
    ("language", "zh"),
    ("publisher", "出版社"),
    ("date", "2024"),
    // ...
  ])
}
```

---

## 7. 与原版实现的差异

| 维度 | 原版 Python | 本项目 MoonBit |
|------|------------|---------------|
| **ZIP 处理** | zipfile 标准库 | 自实现 libzip |
| **XML 解析** | xml.dom.minidom | 自实现 SAX 解析器 |
| **HTML 转换** | markdownify | 自实现 html_to_markdown |
| **错误处理** | try/except | fail() 宏 |
| **异步** | 同步 | async/await |
| **部署** | Python 环境 | 单一原生二进制 |

---

## 8. 已知限制与后续增强

### 8.1 当前限制

1. **不支持图片嵌入**: 仅输出图片路径引用
2. **不支持 CSS 样式**: 不解析样式文件
3. **不支持字体**: 忽略字体信息
4. **有限的多媒体支持**: 暂不支持音视频

### 8.2 后续增强方向

1. **图片处理**: 提取并保存图片，或转为 base64 嵌入
2. **封面提取**: 识别并处理封面图片
3. **目录生成**: 从 NCX/nav.xhtml 生成目录
4. **脚注处理**: 处理 EPUB 脚注引用
5. **样式保留**: 尽量保留格式化信息
6. **EPUB 2.x 兼容**: 增强 NCX 解析

---

## 9. 参考资料

- **EPUB 3.2 规范**: https://www.w3.org/publishing/epub32/epub-spec.html
- **OPF 规范**: https://www.w3.org/publishing/epub32/epub-packages.html
- **Dublin Core 元数据**: https://www.dublincore.org/specifications/dublin-core/dces/
- **原版实现**: `markitdown/packages/markitdown/src/markitdown/converters/_epub_converter.py`

---

## 10. 变更历史

| 日期 | 版本 | 说明 |
|------|------|------|
| 2026-03-11 | v1.0 | 初始版本 |
