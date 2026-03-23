# MoonBitMark 最新转换评测解读报告

日期：`2026-03-23`

## 1. 报告依据

本报告综合解读两份报告：

- 当前最新 MoonBitMark 自测结果：
  - `tests/conversion_eval/reports/latest/summary.md`
  - `tests/conversion_eval/reports/latest/report.json`
  - 生成时间：`2026-03-23T14:29:35.028261+00:00`
- 最近一份包含 baseline 对比的完整报告：
  - `tests/conversion_eval/reports/history/20260323T073613Z/summary.md`
  - `tests/conversion_eval/reports/history/20260323T073613Z/report.json`
  - 生成时间：`2026-03-23T07:36:13.481767+00:00`

需要特别说明：

- `2026-03-23T14:29:35Z` 这份最新报告里，`markitdown` 和 `docling` baseline 在当前环境中不可用，因此没有直接跑出新的 baseline 分数。
- 但同一天稍早的 `2026-03-23T07:36:13Z` 报告已经包含完整 baseline，因此足够用于判断 MoonBitMark 当前大致处于什么水平。
- 由于两次 MoonBitMark 运行的输入集相同，可以把最新结果看作“MoonBitMark 当前状态”，把 `07:36` 的 baseline 看作“最近可比的同口径对照组”。

## 2. 一句话结论

如果只看当前这套本地 benchmark 子集，MoonBitMark 已经处于第一梯队。

更具体地说：

- 在 `PDF / PPTX / XLSX / HTML / DOCX / EPUB / JSON` 这些格式上，MoonBitMark 明显强于当前这套对照中的 `markitdown`，并且在 `docling` 参与的格式里也大多领先。
- 在 `CSV` 上，MoonBitMark 也已经明显领先 `markitdown`，并且高于当前 `docling` 的这套样本结果。
- 在 `Text` 上，MoonBitMark 已经非常接近 `markitdown`，但在当前样本集里仍略低一点。
- 在 `Image` 上，MoonBitMark 当前评测结果很好，但 baseline 不支持该格式，所以只能说明“自测通过且质量稳定”，不能做同口径横向胜负判断。

如果要更谨慎地表述：

- MoonBitMark 在“当前支持的文档类型 + 当前这套本地样本集”上，已经有很强竞争力。
- 但还不能直接推出“在所有真实世界文档上全面超过成熟工具”，因为当前每个格式的样本数仍然偏少，尤其是 `CSV / JSON / HTML / EPUB / Image` 还需要更大样本继续验证。

## 3. 当前最新结果

最新 MoonBitMark 评测结果如下：

- 生成时间：`2026-03-23T14:29:35.028261+00:00`
- Runner 过期状态：`False`
- 通过率：`29/29`
- 平均分：`0.9894`
- 新增簇视图：`archive / web / ocr`
- 新增 tier 视图：`smoke / quality / regression / edge`
- OCR evidence：`relevant 3 / attempted 3 / available 3 / forced 3 / fallback used 1`

按格式汇总：

| 格式 | case 数 | 平均分 |
| --- | ---: | ---: |
| `csv` | 2 | `1.0000` |
| `docx` | 3 | `0.9763` |
| `epub` | 2 | `0.9197` |
| `html` | 3 | `0.9965` |
| `image` | 2 | `1.0000` |
| `json` | 2 | `0.9996` |
| `pdf` | 8 | `0.9990` |
| `pptx` | 2 | `0.9980` |
| `text` | 3 | `0.9981` |
| `xlsx` | 2 | `0.9772` |

按簇汇总：

| 簇 | case 数 | 平均分 |
| --- | ---: | ---: |
| `archive` | 9 | `0.9687` |
| `ocr` | 3 | `1.0000` |
| `web` | 3 | `0.9965` |

这说明当前项目已经没有“某个已支持格式在评测里直接掉线”的问题，所有纳入评测的格式都能稳定通过。

## 4. 与主流类似工具相比处于什么水平

这里的“主流类似工具”以当前本地 harness 已接入的两类 baseline 为准：

- `markitdown`
- `docling`

最近一份完整 baseline 报告显示：

- MoonBitMark：`0.9800`
- `markitdown`：`0.7373`
- `docling`：`0.6388`

而 MoonBitMark 在当天后续优化后，已经进一步提升到：

- MoonBitMark：`0.9894`

也就是说，按这套 benchmark 子集看：

- MoonBitMark 整体明显高于 `markitdown`
- MoonBitMark 整体明显高于 `docling`
- 优势不是“勉强领先”，而是有比较明显的分差

从平均耗时看，最近一份 baseline 报告还显示：

- `markitdown` 平均耗时：`2827.4 ms`
- `docling` 平均耗时：`11424.5 ms`

这意味着在当前样本集下，MoonBitMark 不仅质量分更高，而且其本地 native 路径在工程形态上也更轻。

## 5. 按文档类型逐项判断

下表用“当前 MoonBitMark 最新分数”对比“最近可比 baseline 报告中的分数”：

| 格式 | MoonBitMark 当前 | MarkItDown | Docling | 判断 |
| --- | ---: | ---: | ---: | --- |
| `csv` | `1.0000` | `0.6313` | `0.7884` | MoonBitMark 领先，当前 CSV 主路径已经很强 |
| `docx` | `0.9763` | `0.8808` | `0.5785` | MoonBitMark 明显领先 |
| `epub` | `0.9197` | `0.4428` | 不支持 | MoonBitMark 明显领先，但仍是相对薄弱项 |
| `html` | `0.9965` | `0.8684` | `0.6409` | MoonBitMark 明显领先，且最近第二轮提质继续生效 |
| `image` | `1.0000` | 不支持 | 不支持 | 自测稳定，但暂无同口径 baseline |
| `json` | `0.9996` | `0.8271` | 不支持 | MoonBitMark 领先，且当前 pretty-print 路径更稳定 |
| `pdf` | `0.9990` | `0.6660` | `0.7600` | MoonBitMark 显著领先 |
| `pptx` | `0.9980` | `0.6086` | `0.7043` | MoonBitMark 显著领先 |
| `text` | `0.9981` | `0.9928` | 不支持 | 当前样本下已反超 MarkItDown |
| `xlsx` | `0.9772` | `0.7091` | `0.3441` | MoonBitMark 显著领先 |

### 5.1 PDF

`PDF` 是当前 MoonBitMark 最强的格式之一。

- 当前分数：`0.9990`
- 对比 `markitdown`：`0.6660`
- 对比 `docling`：`0.7600`

这说明在当前样本集里，MoonBitMark 已经不只是“能用”，而是处于明显领先状态。无论是右到左文本、表格、图文混排还是双栏样本，当前都已经能稳定通过。

### 5.2 PPTX

`PPTX` 也是明显优势项。

- 当前分数：`0.9980`
- `markitdown`：`0.6086`
- `docling`：`0.7043`

说明 MoonBitMark 在幻灯片顺序、文本块恢复和图片相关输出上已经非常有竞争力。

### 5.3 XLSX

`XLSX` 当前也处于强势区间。

- 当前分数：`0.9772`
- `markitdown`：`0.7091`
- `docling`：`0.3441`

这意味着 MoonBitMark 在表格型 Office 文档上，已经有比较明显的结构化优势。

### 5.4 DOCX

`DOCX` 当前表现稳定且强。

- 当前分数：`0.9763`
- `markitdown`：`0.8808`
- `docling`：`0.5785`

MoonBitMark 在标题层级、段落顺序和列表类样本上已经达到很高水平。

### 5.5 HTML / XHTML / URL

`HTML` 是这轮最值得关注的提质点之一。

- 最近可比结果：`0.9571`
- 当前最新结果：`0.9965`
- `markitdown`：`0.8684`
- `docling`：`0.6409`

这说明最近补入的 `<title>` 注入和常见容器展开逻辑是有效的，而且已经把 HTML 从“表现不错”推到了“当前样本上几乎接近满分”的水平。

### 5.6 EPUB

`EPUB` 仍然是相对较弱的一组，但已经从“明显短板”进入“可用且领先 baseline”的阶段。

- 最近可比结果：`0.9105`
- 当前最新结果：`0.9197`
- `markitdown`：`0.4428`

这意味着：

- MoonBitMark 在 EPUB 上已经明显优于当前这套 baseline
- 但和 `PDF / PPTX / HTML` 相比，EPUB 仍然是最需要继续深挖结构整理的一类格式之一

### 5.7 CSV

`CSV` 当前已经很强，并且是这轮新增收益最明确的格式之一。

- 最近可比结果：`0.9763`
- 当前最新结果：`1.0000`
- `markitdown`：`0.6313`
- `docling`：`0.7884`

在当前样本上，MoonBitMark 已经领先两类 baseline。结合最近刚完成的 quoted / escaped / multiline 语义补强，可以判断 CSV 当前已经从“基础可用”进入“质量较强”的阶段。

### 5.8 JSON

`JSON` 当前表现稳定。

- 当前分数：`0.9996`
- `markitdown`：`0.8271`

这类格式本身结构目标较简单，当前主要是“稳定、完整、少噪声”，MoonBitMark 已经达标并领先 baseline。

### 5.9 TXT

`TXT` 是少数当前没有明显领先 baseline 的格式。

- 当前分数：`0.9981`
- `markitdown`：`0.9928`

这说明 MoonBitMark 在纯文本上的段落归并和空白处理已经把当前样本推到领先 baseline 的位置，但大样本覆盖仍然值得继续扩大。

### 5.10 Image

`Image` 当前分数是 `1.0000`，表现很好。

但需要强调：

- 当前 image case 是在 `--ocr force --ocr-backend mock` 的可控测试模式下完成的
- `markitdown` 和 `docling` 在这套 harness 中都不支持 image baseline

因此，当前能得出的结论是：

- MoonBitMark 的 image 主路径是稳定的
- OCR 能力和 diagnostics 路径在测试环境里可预测
- 但“相比主流工具处于什么水平”目前还不能做严格横向判断

## 6. 当前项目整体处于什么阶段

按当前结果，MoonBitMark 已经不是“实验性原型”，而是已经进入“主体能力成熟，局部格式继续深挖”的阶段。

可以把当前状态概括成三层：

- 第一梯队：`pdf`、`pptx`、`html`、`csv`、`image`
- 稳定可用且已经领先多数 baseline：`docx`、`xlsx`、`json`
- 可用但仍值得继续提质：`epub`
- 接近成熟基线、仍可继续打磨：`text`

如果用户问“MoonBitMark 现在和主流工具比，算什么水平”，更准确的回答是：

- 在这套本地 benchmark 子集上，MoonBitMark 已经达到明显领先于 `markitdown`、`docling` 的水平
- 在 `PDF / PPTX / XLSX / HTML / DOCX` 这些高价值格式上，已经体现出很强竞争力
- 当前最像“还需要继续追求更高上限”的方向主要是 `EPUB`，以及真实世界更复杂网页场景和更广覆盖的文本样本

## 7. 需要保持清醒的边界

当前成绩非常好，但仍有几个边界要说明清楚：

1. 每个格式的样本数仍偏少。
   - `PDF` 有 7 个 case，信息量相对更高
   - 但 `CSV / JSON` 只有 1 个 case，`HTML / EPUB / PPTX / XLSX / Image / Text` 多数只有 2 个 case

2. baseline 的“不可用格式”不能算 MoonBitMark 自动获胜。
   - 例如 `Image` 暂时没有同口径 baseline
   - `Docling` 也不支持 `epub/json/text/image`

3. 当前报告代表的是“这套固定评测集下的水平”。
   - 它足以说明 MoonBitMark 已经很强
   - 但还不足以推出“所有真实文档场景都全面领先”

## 8. 下一步最值得投入的方向

基于当前结果，后续优先级建议如下：

1. 继续补强 `EPUB`
   - 它已经可用，但仍是当前整体分数里最低的一类

2. 扩大 `HTML / CSV / JSON / Text` 的真实样本覆盖
   - 当前实现已经明显变好，但样本数还偏少

3. 为 `Image` 增加更多真实 OCR 样本
   - 让 image 不只是“mock backend 下通过”，而是能更好反映真实 OCR 水平
   - 同时把 image consumer 完全对齐到新的 OCR metadata 字段

4. 保持 `PDF / PPTX / XLSX / DOCX` 的领先优势
   - 这些已经是 MoonBitMark 当前最有竞争力的格式，应优先守住回归

## 9. 最终结论

截至 `2026-03-23`，MoonBitMark 在当前支持的各类文档格式上，已经表现出很高的整体完成度。

如果只按当前本地 benchmark 来判断：

- MoonBitMark 已经显著强于 `markitdown`
- MoonBitMark 已经显著强于 `docling`
- 在高价值格式上已经具备“可以拿来正面对比”的实力

目前最贴切的结论不是“还有很多格式没法用”，而是：

- 大多数已支持格式已经很好用
- 少数格式还需要继续深挖结构化质量
- 项目整体已经进入“从强可用走向强竞争力”的阶段
