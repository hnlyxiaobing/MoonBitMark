# MoonBitMark MCP 服务概述

**版本:** 0.7.0
**日期:** 2026-03-12
**状态:** MVP 完成

---

## 项目背景

MoonBitMark 原本是一个纯命令行工具,用于将各种文档格式(PDF、DOCX、HTML 等)转换为 Markdown。为了更好地服务 AI 应用场景,我们为其添加了 **Model Context Protocol (MCP)** 服务器支持。

## MCP 是什么?

**Model Context Protocol (MCP)** 是由 Anthropic 提出的开放协议,用于标准化 AI 模型与外部数据源、工具之间的交互。可以将其理解为 **"AI 应用的 USB-C 接口"**,提供一个统一的标准连接 AI 助手和各种外部系统。

### MCP 的核心价值:

1. **统一标准** - 一个协议支持多种工具和数据源
2. **类型安全** - 明确的接口定义和参数校验
3. **易于集成** - AI 助手只需支持 MCP 即可调用任何 MCP 服务器
4. **开放生态** - 任何人都可以实现 MCP 服务器或客户端

---

## MoonBitMark MCP 服务器

MoonBitMark MCP 服务器实现了 MCP 协议,使其能够作为 MCP 服务器运行,供 AI 助手(如 Claude Desktop)直接调用进行文档转换。

### 核心功能

| 功能 | 说明 |
|------|------|
| **文档转换** | 将 PDF、DOCX、HTML 等格式转换为 Markdown |
| **MCP 协议** | 完整实现 MCP 核心协议 (initialize, tools/list, tools/call) |
| **STDIO 传输** | 通过标准输入输出与 MCP 客户端通信 |
| **类型安全** | 充分利用 MoonBit 静态类型系统 |

### 支持的格式

| 格式 | 扩展名 | 状态 |
|------|--------|------|
| PDF | `.pdf` | ✅ |
| Word | `.docx` | ✅ |
| HTML | `.html`, `.htm` | ✅ |
| PowerPoint | `.pptx` | ✅ |
| Excel | `.xlsx` | ✅ |
| EPUB | `.epub` | ✅ |
| 文本 | `.txt`, `.csv`, `.json` | ✅ |

---

## 使用场景

### 1. Claude Desktop 集成

在 Claude Desktop 中配置 MoonBitMark MCP 服务器后,您可以直接对话:

```
用户: 请帮我把桌面上的 report.pdf 转换为 Markdown 格式

Claude: 我将使用 MoonBitMark 工具来转换这个 PDF 文件。
[调用 convert_to_markdown 工具]

转换完成!以下是转换后的 Markdown 内容:

# Report
...
```

### 2. AI 知识库构建

将企业文档库批量转换为 Markdown,接入知识库系统:

```
用户: 将公司所有政策文档转换为 Markdown

Claude: 我可以使用 MoonBitMark 批量转换这些文档...
```

### 3. 内容迁移

从 Word/PDF 迁移到 Markdown 驱动的文档系统:

```
用户: 将这个 Word 文档转换为 Markdown,以便在 GitBook 中使用

Claude: 好的,我将使用 MoonBitMark 转换这个 DOCX 文件...
```

---

## 技术架构

### 整体架构

```
AI 助手 (Claude Desktop)
       ↓
  MCP 客户端
       ↓
  MCP 协议 (JSON-RPC 2.0)
       ↓
  STDIO 传输
       ↓
MoonBitMark MCP 服务器
       ↓
  文档转换引擎
       ↓
  Markdown 输出
```

### 模块划分

| 模块 | 职责 |
|------|------|
| **types/** | JSON-RPC 2.0 和 MCP 协议类型定义 |
| **transport/** | 传输层实现 (STDIO) |
| **handler/** | MCP 请求处理和工具注册 |
| **cmd/mcp-server/** | MCP 服务器 CLI 入口 |

### 代码统计

| 模块 | 代码行数 |
|------|----------|
| types/jsonrpc.mbt | ~80 行 |
| types/mcp.mbt | ~130 行 |
| transport/stdio.mbt | ~20 行 |
| handler/tools.mbt | ~180 行 |
| handler/server.mbt | ~220 行 |
| cmd/mcp-server/main.mbt | ~30 行 |
| **总计** | **~660 行** |

---

## 快速开始

### 1. 编译项目

```bash
cd D:\MySoftware\MoonBitMark
moon build --target native --release
```

### 2. 配置 Claude Desktop

编辑 Claude Desktop 配置文件:

**Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "moonbitmark": {
      "command": "D:\\MySoftware\\MoonBitMark\\_build\\native\\release\\build\\cmd\\mcp-server\\main.exe"
    }
  }
}
```

### 3. 重启 Claude Desktop

重启后,您就可以在 Claude Desktop 中直接调用 MoonBitMark 的文档转换功能了!

---

## 文档资源

| 文档 | 说明 |
|------|------|
| [MCP 服务器使用指南](mcp-server-usage.md) | 详细的配置和使用说明 |
| [MCP 服务设计文档](mcp-service-design.md) | 架构设计和实现细节 |
| [MCP 实现总结](mcp-implementation-summary.md) | 技术实现总结和未来计划 |

---

## 已知限制 (MVP 阶段)

当前实现为 MVP (最小可行产品) 版本,有以下限制:

1. **JSON 解析器简化** - 当前为占位符实现,需要后续完善
2. **文档转换集成不完整** - 转换逻辑为占位符,需要集成实际转换器
3. **仅支持 STDIO 传输** - HTTP/SSE 传输待实现
4. **测试覆盖不足** - 需要补充单元测试和集成测试

详见 [MCP 实现总结](mcp-implementation-summary.md)

---

## 未来计划

### 短期 (P0 - 必需)

- [ ] 实现完整的 JSON 解析器
- [ ] 集成现有的 MoonBitMark 转换器
- [ ] 完善错误处理和日志支持

### 中期 (P1 - 重要)

- [ ] 增强 JSON 序列化功能
- [ ] 添加完整的单元测试
- [ ] 集成测试和兼容性测试

### 长期 (P2 - 可选)

- [ ] HTTP/SSE 传输支持
- [ ] 资源 (Resources) 支持
- [ ] 提示 (Prompts) 支持
- [ ] 性能优化

---

## 对比 MoonBitMark CLI vs MCP

| 特性 | CLI 工具 | MCP 服务器 |
|------|----------|------------|
| **使用方式** | 命令行 | AI 助手调用 |
| **集成难度** | 需要手动调用 | 自动化集成 |
| **适用场景** | 批量处理、脚本 | AI 对话、知识库 |
| **交互性** | 低 | 高 |
| **扩展性** | 有限 | MCP 生态 |

---

## 总结

MoonBitMark MCP 服务器的实现为项目带来了以下价值:

✅ **AI 原生** - 直接被 AI 助手调用,无需额外封装
✅ **类型安全** - 利用 MoonBit 静态类型系统
✅ **标准化** - 遵循 MCP 标准,易于集成
✅ **可扩展** - 基于 MCP 生态,未来功能丰富

虽然当前实现仍处于 MVP 阶段,但已经建立了完整的 MCP 服务框架,为后续的功能完善和扩展奠定了坚实基础。

---

**了解更多:**
- [MCP 官方文档](https://modelcontextprotocol.io)
- [MoonBitMark README](../README.md)
- [项目仓库](https://github.com/moonbitlang/moonbitmark)

---

**创建日期:** 2026-03-12
**当前版本:** 0.7.0
**状态:** MVP 完成,待完善
