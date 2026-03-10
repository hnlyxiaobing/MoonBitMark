# PPTX 转换器开发计划 (架构优化版)

## 1. 概述

本文档描述了为 MoonBitMark 项目添加 PowerPoint (PPTX) 文件转换器的开发计划。PPTX 转换器将把 `.pptx` 文件转换为 Markdown 格式，遵循项目现有架构模式。

### 1.1 参考资料

- **原项目实现**: [MarkItDown PPTX Converter](https://github.com/microsoft/markitdown/blob/main/packages/markitdown/src/markitdown/converters/_pptx_converter.py)
- **PPTX 格式规范**: ECMA-376 Office Open XML
- **项目架构参考**: `src/formats/docx/converter.mbt`, `src/core/types.mbt`

### 1.2 技术选型与架构对齐

采用纯 MoonBit 实现，复用现有基础设施：
- **libzip**: 解析 ZIP 结构 (复用现有实现)
- **xml parser**: SAX风格XML解析 (复用现有实现)
- **异步I/O**: 遵循项目async/await模式
- **统一接口**: 实现DocumentConverter trait，返回ConvertResult
- **错误处理**: 使用suberror定义PPTX特定错误

### 1.3 与现有架构的一致性

| 方面 | 现有模式 | PPTX实现方式 |
|------|----------|-------------|
| 接口 | DocumentConverter trait | 实现accepts() + convert() |
| 错误处理 | suberror + raise | 定义PPTXError suberror |
| 异步 | async函数 + raise | async convert() |
| 类型 | pub(all)/pub(open)可见性 | 遵循相同可见性规则 |
| 组织 | 块式组织(///|分隔) | 采用相同组织方式 |

---

## 2. PPTX 文件格式分析

### 2.1 PPTX 文件结构

PPTX 文件本质是一个 ZIP 压缩包，内部结构如下：

```
example.pptx
├── [Content_Types].xml          # 内容类型定义
├── _rels/.rels                  # 全局关系文件
├── docProps/
│   ├── app.xml                  # 应用程序属性
│   └── core.xml                 # 核心属性（作者、创建时间等）
├── ppt/
│   ├── presentation.xml         # 演示文稿主文件（幻灯片顺序）
│   ├── _rels/
│   │   └── presentation.xml.rels # 演示文稿关系
│   ├── slides/
│   │   ├── slide1.xml           # 幻灯片 1
│   │   ├── slide2.xml           # 幻灯片 2
│   │   └── ...
│   ├── slides/_rels/
│   │   ├── slide1.xml.rels      # 幻灯片关系（图片、链接等）
│   │   └── ...
│   ├── slideLayouts/            # 幻灯片布局模板
│   ├── slideMasters/            # 幻灯片母版
│   ├── notesSlides/             # 演讲者备注
│   ├── media/                   # 媒体文件（图片、视频等）
│   │   ├── image1.png
│   │   ├── image2.jpg
│   │   └── ...
│   └── theme/                   # 主题文件
```

### 2.2 关键 XML 命名空间

| 前缀 | 命名空间 URI | 说明 |
|------|-------------|------|
| `p:` | `http://schemas.openxmlformats.org/presentationml/2006/main` | PresentationML 主命名空间 |
| `a:` | `http://schemas.openxmlformats.org/drawingml/2006/main` | DrawingML（图形、文本） |
| `r:` | `http://schemas.openxmlformats.org/officeDocument/2006/relationships` | 关系引用 |
| `p14:` | `http://schemas.microsoft.com/office/powerpoint/2010/main` | PowerPoint 2010 扩展 |

### 2.3 核心数据结构

#### presentation.xml - 幻灯片顺序

```xml
<p:presentation>
  <p:sldIdLst>
    <p:sldId id="256" r:id="rId2"/>
    <p:sldId id="257" r:id="rId3"/>
  </p:sldIdLst>
</p:presentation>
```

#### slideN.xml - 幻灯片内容

```xml
<p:sld>
  <p:cSld>
    <p:spTree>  <!-- 形状树 -->
      <p:nvGrpSpPr/>  <!-- 非可视化属性 -->
      <p:grpSpPr/>    <!-- 组形状属性 -->

      <!-- 形状 (Shape) -->
      <p:sp>
        <p:nvSpPr>
          <p:cNvPr id="2" name="Title 1"/>
        </p:nvSpPr>
        <p:spPr/>
        <p:txBody>  <!-- 文本框 -->
          <a:bodyPr/>
          <a:lstStyle/>
          <a:p>  <!-- 段落 -->
            <a:r>  <!-- 文本运行 -->
              <a:t>Hello World</a:t>  <!-- 实际文本 -->
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>

      <!-- 图片 (Picture) -->
      <p:pic>
        <p:nvPicPr>
          <p:cNvPr id="3" name="Picture 1" descr="图片描述"/>
        </p:nvPicPr>
        <p:blipFill>
          <a:blip r:embed="rId4"/>  <!-- 引用媒体文件 -->
        </p:blipFill>
      </p:pic>

      <!-- 表格 (GraphicFrame) -->
      <p:graphicFrame>
        <a:graphic>
          <a:graphicData uri="...">
            <a:tbl>
              <a:tr>  <!-- 行 -->
                <a:tc>  <!-- 单元格 -->
                  <a:txBody>
                    <a:p><a:r><a:t>Cell Text</a:t></a:r></a:p>
                  </a:txBody>
                </a:tc>
              </a:tr>
            </a:tbl>
          </a:graphicData>
        </a:graphic>
      </p:graphicFrame>

    </p:spTree>
  </p:cSld>
  <p:clrMapOvr/>
</p:sld>
```

---

## 3. 原版 MarkItDown 实现分析

### 3.1 核心转换逻辑

原版 Python 实现的核心流程：

```python
# 1. 使用 python-pptx 库打开文件
presentation = pptx.Presentation(file_stream)

# 2. 遍历每一张幻灯片
for slide in presentation.slides:
    # 添加幻灯片分隔标记
    md_content += f"\n\n<!-- Slide number: {slide_num} -->\n"

    # 3. 按位置排序形状（从上到下，从左到右）
    sorted_shapes = sorted(slide.shapes, key=lambda x: (x.top, x.left))

    # 4. 处理每个形状
    for shape in sorted_shapes:
        # 图片
        if shape.shape_type == MSO_SHAPE_TYPE.PICTURE:
            # 提取图片，生成 ![alt](filename) 或 base64 data URI

        # 表格
        elif shape.shape_type == MSO_SHAPE_TYPE.TABLE:
            # 转换为 HTML 表格，再转 Markdown

        # 图表
        elif shape.has_chart:
            # 提取图表数据，生成 Markdown 表格

        # 文本框
        elif shape.has_text_frame:
            # 标题用 #，普通文本直接输出
            if shape == title:
                md_content += "# " + shape.text + "\n"
            else:
                md_content += shape.text + "\n"

        # 组合形状（递归处理）
        elif shape.shape_type == MSO_SHAPE_TYPE.GROUP:
            # 递归处理子形状

    # 5. 处理演讲者备注
    if slide.has_notes_slide:
        md_content += "\n\n### Notes:\n" + notes_frame.text
```

### 3.2 支持的内容类型

| 类型 | 处理方式 | Markdown 输出 |
|------|---------|--------------|
| 标题 | `# Title` | 一级标题 |
| 文本框 | 直接输出 | 普通文本 |
| 图片 | `![alt](filename)` | 图片引用 |
| 表格 | HTML → Markdown | Markdown 表格 |
| 图表 | 提取数据 | Markdown 表格 |
| 演讲者备注 | `### Notes:` | 三级标题下的文本 |

### 3.3 特色功能

1. **形状位置排序**: 按从上到下、从左到右的顺序处理形状
2. **LLM 图片描述**: 可选集成 LLM 为图片生成描述
3. **Base64 嵌入**: 可选将图片嵌入为 data URI
4. **Alt Text 提取**: 从 PPTX 元数据中提取图片替代文本

---

## 4. 纯 MoonBit 实现方案

### 4.1 项目结构

```
src/formats/pptx/
├── converter.mbt          # 主转换器实现
├── presentation.mbt       # presentation.xml 解析
├── slide.mbt              # 幻灯片解析
├── shape.mbt              # 形状解析（文本、图片、表格）
├── relations.mbt          # 关系文件解析
└── moon.pkg               # 包定义
```

### 4.2 核心数据结构 (MoonBit风格优化)

```moonbit
///| PPTX解析错误类型
suberror PPTXError {
  InvalidZipStructure,
  MissingPresentationXml,
  MalformedSlideXml(String),  // 幻灯片编号
  UnsupportedShapeType(String),
  ImageExtractionFailed(String)
}

///| 形状位置信息
priv struct Position {
  mut top : Int
  mut left : Int
}

///| 文本形状
priv struct TextShape {
  mut text : String
  mut is_title : Bool
  mut position : Position
}

///| 图片形状
priv struct PictureShape {
  mut name : String
  mut description : String
  mut media_path : String
  mut content_type : String
}

///| 表格单元格
priv struct TableCell {
  mut text : String
}

///| 表格行
priv struct TableRow {
  mut cells : Array[TableCell]
}

///| 表格形状
priv struct TableShape {
  mut rows : Array[TableRow]
}

///| 幻灯片
priv struct Slide {
  mut shapes : Array[Shape]
  mut notes : String?
}

///| 形状联合类型
priv enum Shape {
  Text(TextShape)
  Picture(PictureShape)
  Table(TableShape)
  Group(Array[Shape])
}
```

**架构对齐说明**：
- 使用`priv`修饰符隐藏内部实现细节
- 大量使用`mut`变量进行状态管理
- 采用块式注释`///|`组织代码
- 错误使用`suberror`精确定义

### 4.3 转换流程 (MoonBit异步模式)

```
┌─────────────────────────────────────────────────────────────┐
│                PPTX 文件 (异步处理)                           │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│  1. ZIP 解析 (@libzip.ZipArchive::open)                      │
│     - 验证ZIP结构                                             │
│     - 读取关键文件路径                                         │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│  2. 解析 presentation.xml (异步读取)                         │
│     - 获取幻灯片ID列表                                         │
│     - 解析关系文件                                             │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│  3. 遍历幻灯片 (并行读取XML)                                  │
│     - @fs.open() 读取 slideN.xml                             │
│     - 解析形状树 @xml.parse_xml()                             │
│     - 按位置排序形状 (Position.top/left)                      │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│  4. 生成 ConvertResult                                       │
│     - Markdown文本累加                                         │
│     - 可选：图片引用处理                                        │
│     - 返回 ConvertResult{markdown, title?, metadata}          │
└─────────────────────────────────────────────────────────────┘
```

### 4.4 关键实现细节 (MoonBit风格)

#### 4.4.1 转换器接口实现

```moonbit
///| PPTX转换器实现
pub(all) struct PptxConverter {
  priv dummy : Int
}

///| 创建PPTX转换器
pub fn PptxConverter::new() -> PptxConverter {
  PptxConverter::{ dummy: 0 }
}

///| 检查是否接受PPTX文件
pub fn PptxConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.extension {
    Some(ext) => ext.to_lower() == ".pptx"
    None => false
  }
}

///| 异步转换PPTX文件
pub async fn PptxConverter::convert(
  file_path : String
) -> ConvertResult raise PPTXError {
  // 实现转换逻辑
}
```

#### 4.4.2 XML事件处理 (仿DOCX模式)

```moonbit
///| PPTX解析上下文 (仿DOCX Context模式)
priv struct PptxContext {
  mut slide_num : Int
  mut markdown_accumulator : String
  mut current_slide_title : String?
}

///| 处理XML事件流
fn process_slide_events(
  events : Array[@xml.ParseEvent],
  ctx : PptxContext
) -> Unit raise PPTXError {
  for event in events {
    match event {
      @xml.ElementStart(evt) => handle_element_start(ctx, evt)
      @xml.ElementEnd(evt) => handle_element_end(ctx, evt)
      @xml.TextContent(evt) => accumulate_text(ctx, evt.content)
    }
  }
}
```

#### 4.4.3 流式文本提取

```moonbit
///| 提取文本内容 (处理换行和制表符)
fn extract_text_content(events : Array[@xml.ParseEvent]) -> String {
  let mut result = ""
  let mut in_text = false
  
  for event in events {
    match event {
      @xml.TextContent(evt) => {
        if in_text {
          result = result + evt.content.to_string()
        }
      }
      _ => () // 其他事件处理
    }
  }
  result.trim().to_string()
}
```

**MoonBit特性应用**：
- 使用`to_string()`而非构造函数
- 大量`mut`变量进行状态管理
- 方法调用风格：`evt.content.to_string()`
- 错误处理：`raise PPTXError`声明

---

## 5. 开发计划

### 5.1 任务分解 (MoonBit风格)

| 阶段 | 任务 | 优先级 | MoonBit特性应用 |
|------|------|--------|----------------|
| **阶段 1: 基础框架** | | | |
| 1.1 | 创建 `src/formats/pptx/converter.mbt` | P0 | 块式组织，pub/priv可见性 |
| 1.2 | 实现DocumentConverter接口 | P0 | trait实现，async/await |
| 1.3 | 注册到CLI (`cmd/main/main.mbt`) | P0 | 文件后缀匹配逻辑 |
| **阶段 2: ZIP解析** | | | |
| 2.1 | 使用@libzip读取PPTX结构 | P0 | 复用现有libzip API |
| 2.2 | 解析presentation.xml | P0 | @xml.parse_xml事件驱动 |
| 2.3 | 关系文件解析 | P0 | Map[String,String]存储 |
| **阶段 3: 形状处理** | | | |
| 3.1 | 文本形状(@p:sp)解析 | P0 | 仿DOCX事件处理模式 |
| 3.2 | 标题检测(位置+样式) | P1 | mut变量状态跟踪 |
| 3.3 | 图片(@p:pic)引用提取 | P1 | r:embed关系解析 |
| 3.4 | 表格(@a:tbl)转Markdown | P2 | 二维数组遍历 |
| **阶段 4: Markdown生成** | | | |
| 4.1 | 幻灯片分隔符生成 | P0 | f-string插值: f"<!-- Slide {num} -->" |
| 4.2 | 文本内容拼接 | P0 | mut String累加 |
| 4.3 | ConvertResult返回 | P0 | {markdown, title?, metadata} |
| **阶段 5: 测试验证** | | | |
| 5.1 | 单元测试(mock XML) | P0 | @test模块 |
| 5.2 | 快照测试(real PPTX) | P0 | moon test --update |
| 5.3 | 性能测试(大文件) | P1 | 流式处理优化 |

### 5.2 文件创建清单 (MoonBit模块化)

```
src/formats/pptx/
├── moon.pkg                 # 包定义，依赖core, libzip, xml
├── converter.mbt            # 主转换器，实现DocumentConverter
├── parser.mbt               # XML解析器封装 (presentation, slide)
├── shapes.mbt               # 形状处理统一入口
├── types.mbt                # 内部类型定义 (priv struct/enum)
└── converter_test.mbt       # 测试，使用@Test注解

moon.pkg.json 示例:
{
  "import": [
    "moonbitlang/moonbitmark/src/core",
    "moonbitlang/moonbitmark/src/libzip",
    "moonbitlang/moonbitmark/src/xml",
    "moonbitlang/async/fs"
  ]
}
```

### 5.3 测试策略 (MoonBit测试模式)

1. **单元测试**: 使用`@test`注解，mock XML事件流
2. **快照测试**: `moon test --update`更新期望输出
3. **集成测试**: 真实PPTX文件，验证ConvertResult结构
4. **错误路径测试**: 损坏ZIP、缺失XML、无效格式

### 5.4 测试用例设计

```moonbit
///| 简单文本测试
@Test
test simple_pptx() {
  let result = PptxConverter::convert("test/simple.pptx")
  @expect(result.markdown.contains("# Title"))
}

///| 表格转换测试  
@Test
test table_conversion() {
  let result = PptxConverter::convert("test/table.pptx")
  @expect(result.markdown.contains("|---"))
}
```

---

## 6. Markdown 输出格式 (ConvertResult结构)

### 6.1 标准输出格式

```moonbit
// 返回的ConvertResult结构
ConvertResult{
  markdown: """
<!-- Slide number: 1 -->

# 演示文稿标题

这是第一张幻灯片的正文内容...

![图片描述](media/image1.jpg)

| 列1 | 列2 | 列3 |
|-----|-----|-----|
| A   | B   | C   |

<!-- Slide number: 2 -->

## 第二张幻灯片

更多内容...

### Notes:
演讲者备注内容。
""",
  title: Some("演示文稿标题"),  // 第一张幻灯片的标题
  metadata: Map::from([
    ("slide_count", "2"),
    ("has_images", "true")
  ])
}
```

### 6.2 MoonBit字符串处理特性

```moonbit
// 使用f-string风格拼接
let slide_header = f"\n\n<!-- Slide number: {ctx.slide_num} -->\n"

// 方法调用链式风格
result.markdown = result.markdown
  .append(title_line)
  .append(content_lines.join("\n"))
  .append(image_ref)

// 数组map/reduce风格处理表格
let table_md = table.rows.map(row_to_md).join("\n")
```

**图片策略**: 第一阶段仅输出相对路径引用，保持与DOCX转换器一致

---

## 7. 架构优势与设计决策

### 7.1 与原版实现的差异对比

| 维度 | 原版 Python | 本项目 MoonBit |
|------|------------|---------------|
| **架构模式** | 面向对象 + 外部库 | Trait-based + 纯MoonBit |
| **解析方式** | python-pptx高层API | ZIP+XML底层解析 |
| **异步支持** | 同步阻塞 | async/await原生异步 |
| **错误处理** | try/except | suberror + raise |
| **内存管理** | GC垃圾回收 | 编译时优化 |
| **部署方式** | Python环境依赖 | 单文件原生二进制 |

### 7.2 MoonBit架构优势

1. **零外部依赖**: 复用libzip/xml，无需python-pptx
2. **编译时优化**: 生成高效原生代码
3. **强类型安全**: suberror精确错误分类
4. **并发友好**: async I/O支持高并发处理
5. **跨平台部署**: 单一可执行文件

### 7.3 功能优先级决策

**Phase 1 (MVP)**: 文本 + 图片引用 + 基本表格
**Phase 2**: 组合形状 + 演讲者备注
**Phase 3**: 样式保留 + 高级表格
**Phase 4**: 图表解析 + LLM集成 (可选)

---

## 8. 后续增强 (MoonBit特性延伸)

1. **流式处理**: 大文件分块读取，降低内存占用
2. **并行解析**: 多幻灯片并发XML解析
3. **样式提取**: 解析<a:rPr>提取粗体/斜体样式
4. **图表支持**: 解析DrawingML图表为数据表格
5. **插件架构**: 支持自定义形状处理器
6. **性能监控**: 内置转换耗时统计

---

## 9. 参考资料与最佳实践

- **格式规范**: [ECMA-376 Office Open XML](https://www.ecma-international.org/publications-and-standards/standards/ecma-376/)
- **项目参考**: `src/formats/docx/converter.mbt` (相似ZIP+XML解析模式)
- **解析库**: `@libzip`, `@xml` 模块源码
- **MoonBit模式**: AGENTS.md 中的编码约定

## 10. 变更历史

| 日期 | 版本 | 说明 |
|------|------|------|
| 2026-03-10 | v1.0 | 初始版本 |
| 2026-03-10 | v1.1 | 架构优化版：对齐MoonBit项目模式，强化错误处理，优化数据结构 |
