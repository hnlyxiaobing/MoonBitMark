# Architecture Refactor Lessons Learned

> 这份文档记录这轮 MoonBitMark 架构改造过程中，值得长期保留的经验、约束和判断标准。

## 1. 先统一主链路，再补单点功能

这轮改造最重要的收益，不是某一个格式能力增强，而是把真实运行路径改成：

```text
Frontend -> Engine -> Converter -> Normalize / Render -> Postprocess
```

经验结论：

- 先让 engine 接管主流程，比先补更多 converter 功能更重要
- 如果 CLI 还直接判断格式和调 converter，后续的 diagnostics、metadata、asset、frontmatter 都会变成到处散落的特判
- 架构改造的第一优先级，应始终是“把能力放在正确层级”，而不是“先把功能做出来”

## 2. warning / error 必须源头 typed 化，不要依赖字符串约定

早期最容易滑坡的做法，是直接在 converter 或 helper 里拼字符串 warning，然后指望 engine 猜测它属于哪个阶段、哪个来源。

这轮改造确认下来的原则：

- `phase/source/hint` 应尽量在错误产生源头就确定
- engine 可以做默认值补齐，但不应该替代源头建模
- 统一渲染格式是 engine 的职责，统一语义来源是 converter / parser / helper 的职责

这也是为什么后续改造会优先清理 archive 类格式里“次级 helper 吞错”的原因。

## 3. “可降级”不等于“静默吞错”

DOCX / PPTX / XLSX / EPUB 这类 archive 格式里，很多 helper 天然会面对局部损坏、缺失 rels、坏 XML、空 sheet、空 slide 等情况。

正确做法不是一律 fail，也不是一律静默吃掉，而是：

- 能继续产出主结果时：降级，并生成 typed warning / diagnostic
- 会破坏主结果可信度时：生成 typed failure，让 engine 透传

经验判断标准：

- “局部丢失但主体仍可读” -> warning
- “主文档结构无法建立” -> error

## 4. 后处理能力应该收敛在 engine，而不是散落在 converter

`frontmatter`、输出模式切换、资产路径回写、data URI 图片落盘，这些都不是某个格式私有的解析逻辑，而是“结果后处理”。

因此它们应该放在 engine：

- converter 负责产出统一内容结果
- engine 负责统一包装、重写、落盘和 metadata 补充

这次 `asset_output_dir` 的落地验证了这条判断是对的。若把资源落盘分散到各 converter，后面会很难统一路径规则、命名规则、diagnostics 和 metadata。

## 5. AST 改造要先抓代表性格式，不要平均用力

不是所有格式都值得第一时间切到 AST。

当前更有效的推进顺序是：

1. 先抓 HTML、DOCX、EPUB 这种结构信息最丰富、最能体现 AST 价值的格式
2. 再考虑 CSV / JSON / TXT / PPTX / XLSX 这类更偏“结构化文本导出”的格式

原因很简单：

- HTML / DOCX / EPUB 能更快验证 block / inline / renderer 设计是否合理
- 低复杂格式直接产出 Markdown 的收益损失相对小
- AST 不是目标本身，统一内容模型和后续可扩展性才是目标

## 6. MoonBit 项目里，`moon info` 不只是生成接口摘要，也是重构安全网

这轮实践下来，`pkg.generated.mbti` 很有价值：

- 可以快速确认某次重构是否意外改变了公开接口
- 可以帮助识别“死类型”、“未使用公开 API”和不必要暴露的 helper
- 在 warning 清理阶段，`moon info` 往往比肉眼扫文件更可靠

因此对这类架构改造，建议把 `moon info` 当成常规校验步骤，而不是最后补跑一下。

## 7. warning 清理不是面子工程，它直接影响后续迭代成本

warning 多的时候，新的真实问题很容易被淹没。尤其在 typed diagnostics 改造阶段，如果代码里同时堆着大量 `unused_error_type`、过时 API、死分支 warning，会严重影响判断。

经验上，warning 清理值得在这些时机做：

- 某条改造链路已经收口，准备转下一条主线时
- 需要判断“当前还有哪些问题是真缺口，哪些只是噪声”时
- 要开始做资产、AST、MCP 这类新工作前

## 8. MoonBit async / package warning 仍有工具链边角，需要实事求是记录

当前 `src/engine/moon.pkg` 中保留 `moonbitlang/async`，是因为 async wbtest 需要它；但 MoonBit 仍会将其判为 `unused_package`。这类 warning 不属于业务架构问题，而是工具链边角。

经验上应这样处理：

- 如果它确实影响运行或校验，就解决
- 如果它是工具链误判，但依赖真实必需，就在文档中明确记录，不要为了“表面 0 warning”去做反直觉代码

## 9. 后续推进建议

下一阶段最值得做的，不是继续机械清理细枝末节，而是：

1. 统一 archive 类格式的原生资源提取，把图片/附件真正接入 `assets`
2. 把 AST 接入继续推广到更多格式
3. 在主链路稳定后，再考虑 Web / MCP 展示层

## 10. 提交前建议校验顺序

推荐顺序：

```bash
moon info
moon fmt
moon check
moon test src/engine
```

如果本次改动涉及具体格式，再补对应 package 的 targeted `moon test`。
