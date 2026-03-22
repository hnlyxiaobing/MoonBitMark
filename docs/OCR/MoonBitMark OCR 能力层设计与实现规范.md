MoonBitMark OCR 能力层设计与实现规范

1. 设计结论

基于当前仓库现状，原方案中以下假设不成立，需要直接修正：

- 仓库当前不存在 `src/capabilities/ocr`、`fusion.mbt`、独立 `pipeline.mbt` 等目录与执行链。
- 现有主链路是 `ConvertContext -> engine.MarkItDown -> formats/* -> AST -> renderer -> ConvertResult`，不是“各 converter 自建上下文 + 独立 OCR AST”。
- 当前 PDF 仅接入 `mbtpdf` 文本提取，没有页渲染能力；在不新增重型本地依赖的前提下，无法把“整页 PDF 渲染后 OCR”作为第一阶段的默认交付物。
- 当前 diagnostics / metadata / stats 已经是统一协议，因此 OCR 必须复用 `ConvertContext`、`ConvertResult.diagnostics`、`ConvertResult.metadata`，不能平行造一套输出协议。

因此，本规范将 OCR MVP 调整为：

- 先交付一个真正可落地的 OCR 能力层，挂接到现有 engine / converter 架构。
- 第一阶段优先支持：
  - 独立图片文件 OCR
  - DOCX / PPTX / EPUB 中已提取图片资产的 OCR 补充
- PDF OCR 在本轮只保留接口与 diagnostics 协议，不把“内建 PDF 页渲染”写成已实现能力。
- OCR 结果必须进入现有 AST / Markdown 渲染路径，不允许直接字符串拼接绕过 `ConvertResult`。

2. 与现有架构的对齐方式

2.1 目录布局

实际落地目录如下：

```text
src/
├── capabilities/
│   └── ocr/
│       ├── moon.pkg
│       ├── types.mbt
│       └── provider.mbt
├── core/
│   └── types.mbt          # 扩展 ConvertContext
├── engine/
│   └── engine.mbt         # 把 ctx 继续透传给 converter
├── formats/
│   ├── image/             # 新增独立图片 OCR converter
│   ├── docx/
│   ├── pptx/
│   └── epub/
└── ...

scripts/
└── ocr/
    └── bridge.py          # OCR 桥接脚本
```

2.2 调用链

```text
CLI
  -> parse_args
  -> ConvertContext.ocr
  -> engine.MarkItDown::convert(...)
  -> concrete converter(input, ctx)
  -> capabilities/ocr provider
  -> AST blocks / diagnostics / metadata
  -> renderer
  -> ConvertResult
```

3. OCR MVP 能力范围

3.1 已实现范围

- 独立图片输入：`.png/.jpg/.jpeg/.bmp/.gif/.tif/.tiff/.webp`
- 文档嵌图补充 OCR：
  - DOCX `word/media/*`
  - PPTX `ppt/media/*`
  - EPUB manifest 中的图片资源
- CLI 开关：
  - `--ocr <off|auto|force>`
  - `--ocr-lang <lang>`
  - `--ocr-images`
  - `--ocr-backend <backend>`
  - `--ocr-timeout <ms>`

3.2 明确不在本轮默认交付的范围

- 内建 PDF 页渲染
- 区域级 bbox 融合
- 表格 / 版面结构 OCR
- 云端 OCR API
- 对 HTML 外链图片的主动下载与 OCR

这些能力仍然保留扩展位，但不再在设计文档中伪装成已具备的前提。

4. 核心类型设计

4.1 `src/capabilities/ocr/types.mbt`

统一定义与具体格式无关的 OCR 类型：

- `OcrMode`
  - `Off`
  - `Auto`
  - `Force`
- `OcrConfig`
  - `mode`
  - `language`
  - `enable_embedded_images`
  - `backend`
  - `timeout_ms`
- `OcrResult`
  - `attempted`
  - `available`
  - `provider`
  - `text`
  - `warnings`

设计取舍：

- 第一版不追求 bbox / confidence，因为当前仓库没有版面模型，强行引入只会增加虚假抽象。
- 结果只保留当前主链路确实会消费的最小字段。

4.2 `ConvertContext`

`ConvertContext` 新增 `ocr : OcrConfig` 字段，作为 OCR 全局配置入口。所有 converter 都通过已有 ctx 透传，不新建平行上下文类型。

5. Provider 设计

5.1 总体原则

- MoonBit 主体不直接绑定某个 OCR 引擎。
- 第一版通过仓库内置 `scripts/ocr/bridge.py` 作为适配桥。
- MoonBit 只负责：
  - 写入临时输入文件
  - 调用桥接脚本
  - 读取 JSON 结果
  - 产出 typed diagnostics

5.2 桥接脚本协议

桥接脚本输入：

- `--input <path>`
- `--output-json <path>`
- `--lang <lang>`
- `--backend <backend>`
- `--timeout-ms <ms>`

桥接脚本输出 JSON：

```json
{
  "available": true,
  "provider": "tesseract",
  "text": "recognized text",
  "warnings": []
}
```

桥接策略：

- `backend=auto`：
  - 若系统存在 `tesseract`，优先使用
  - 否则返回 `available=false`
- `backend=mock`：
  - 供测试使用，返回可预测文本
- `backend=tesseract`：
  - 强制调用 `tesseract`

6. 各格式接入策略

6.1 图片文件

新增 `src/formats/image/converter.mbt`：

- 直接把图片文件作为 OCR 输入
- 输出 Markdown 包含：
  - 原图引用（复用 `OutputAsset`）
  - OCR 文本段落
- 当 OCR 不可用时：
  - 不报致命错误
  - 保留图片资产
  - 在 diagnostics 中明确记录未执行原因

6.2 DOCX / PPTX / EPUB

对于已提取的图片资产：

- 仅在 `ctx.ocr.enable_embedded_images == true` 且 `mode != Off` 时尝试 OCR
- OCR 结果以补充块的形式进入现有 AST
- 推荐渲染样式：
  - 增加 `Image OCR` / `OCR Notes` 二级标题
  - 每张图一个三级标题或普通段落
- 若 OCR 不可用或识别结果为空：
  - 不影响原转换结果
  - 记录 warning / diagnostics

6.3 PDF

本轮对 PDF 的策略是：

- 保持现有 `mbtpdf` 文本提取主路径不变
- 当用户传入 OCR 开关时，若当前运行时不具备 PDF OCR 条件，只输出明确 diagnostics
- 不在本轮内伪造“已实现 PDF fallback”

后续若要实现 PDF OCR，需要至少新增一种能力：

- 页渲染器（如 poppler / mupdf / 系统组件）
- 或接受 PDF 输入的 OCR provider

7. Diagnostics 与 metadata 规范

7.1 diagnostics 约定

OCR 相关 diagnostics 统一复用现有 `ConversionDiagnostic`，消息语义采用以下前缀：

- `OCR requested but no available backend was found.`
- `OCR backend returned empty text.`
- `OCR executed for embedded image asset: ...`
- `OCR skipped for PDF because no page-rendering backend is configured.`
- `OCR backend execution failed: ...`

7.2 metadata 约定

当本次转换实际使用 OCR 时，可补充：

- `ocr_mode`
- `ocr_backend`
- `ocr_provider`
- `ocr_embedded_image_count`

不新增并行的 OCR report 结构。

8. 测试策略

8.1 自动化测试

本轮测试以 mock backend 为主，覆盖：

- CLI 参数解析
- OCR provider JSON 解析
- 图片 converter 的主链路
- DOCX / PPTX / EPUB 嵌图 OCR 块拼装
- diagnostics / metadata 生成

8.2 为什么使用 mock backend

当前 CI / 本地环境无法假设一定存在 `tesseract`、PDF 渲染器或额外模型。mock backend 可以稳定验证主链路，而真实引擎验证留给手工验收。

9. 手工验收标准

在系统已安装 `tesseract` 的前提下：

1. `main.exe --ocr force sample.png`
   - 输出包含 OCR 文本
   - metadata 中有 `ocr_provider`
2. `main.exe --ocr auto --ocr-images sample.docx`
   - 文中嵌图出现 OCR Notes 块
3. `main.exe --ocr force sample.pdf`
   - 若无 PDF OCR backend，输出明确 diagnostics，不崩溃

10. 后续扩展路线

阶段二可以继续做：

- PDF 页渲染 + OCR fallback
- 更细的 Auto 策略
- OCR 结果去重与版面融合
- HTML data URI / 本地图片 OCR
- 更丰富的结构化结果（lines / bbox / confidence）

但这些扩展必须建立在本轮已经交付的统一 OCR capability layer 之上，而不是重新引入一套并行架构。
