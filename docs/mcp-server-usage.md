# MoonBitMark MCP 服务器使用指南

**版本:** 0.1.0
**日期:** 2026-03-12
**状态:** 开发中 (MVP 阶段)

---

## 概述

MoonBitMark MCP 服务器实现了 Model Context Protocol (MCP) 协议,使 MoonBitMark 文档转换工具能够作为 MCP 服务器运行,供 AI 助手(如 Claude Desktop)直接调用。

---

## 编译和运行

### 前置要求

- **MoonBit 工具链**: https://docs.moonbitlang.com
- **MSVC (Windows)**: Visual Studio Build Tools 2022

### 编译

```bash
# 编译整个项目
moon build --target native --release

# 或使用构建脚本
scripts\build_msvc.bat
```

编译完成后,MCP 服务器可执行文件位于:

```
_build\native\release\build\cmd\mcp-server\main.exe
```

### 运行

```bash
# 运行 MCP 服务器
_build\native\release\build\cmd\mcp-server\main.exe

# 或使用 moon run
moon run cmd/mcp-server

# 查看帮助
_build\native\release\build\cmd\mcp-server\main.exe --help
```

---

## 配置 Claude Desktop

### 1. 找到 Claude Desktop 配置文件

**Windows:**
```
%APPDATA%\Claude\claude_desktop_config.json
```

**macOS:**
```
~/Library/Application Support/Claude/claude_desktop_config.json
```

**Linux:**
```
~/.config/Claude/claude_desktop_config.json
```

### 2. 添加 MCP 服务器配置

编辑配置文件,添加 MoonBitMark MCP 服务器:

```json
{
  "mcpServers": {
    "moonbitmark": {
      "command": "path/to/moonbitmark/mcp-server.exe",
      "env": {}
    }
  }
}
```

**完整示例:**

```json
{
  "mcpServers": {
    "moonbitmark": {
      "command": "D:\\MySoftware\\MoonBitMark\\_build\\native\\release\\build\\cmd\\mcp-server\\main.exe",
      "env": {}
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "D:\\Documents"]
    }
  }
}
```

### 3. 重启 Claude Desktop

重启 Claude Desktop 后,MoonBitMark MCP 服务器将自动连接。

---

## 使用示例

### 在 Claude Desktop 中使用

连接成功后,您可以在 Claude Desktop 中直接调用 MoonBitMark 的文档转换功能:

```
用户: 请帮我把桌面上的 report.pdf 转换为 Markdown 格式

Claude: 我将使用 MoonBitMark 工具来转换这个 PDF 文件。
[调用 convert_to_markdown 工具]

转换完成!以下是转换后的 Markdown 内容:

# Report

...

用户: 能否帮我转换这个网页吗? https://example.com/documentation.html

Claude: 我可以使用 MoonBitMark 工具来转换这个网页。
[调用 convert_to_markdown 工具]

转换完成!网页内容已转换为 Markdown 格式。
```

### 直接通过 STDIO 测试

您也可以直接通过命令行测试 MCP 服务器:

```bash
# 启动服务器(在 PowerShell 中)
$server = Start-Process -FilePath "mcp-server.exe" -NoNewWindow -PassThru -RedirectStandardInput "stdin.txt" -RedirectStandardOutput "stdout.txt"

# 发送初始化请求
echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}},"id":1}' | .\mcp-server.exe

# 查询可用工具
echo '{"jsonrpc":"2.0","method":"tools/list","id":2}' | .\mcp-server.exe
```

---

## 可用工具

### convert_to_markdown

将文档转换为 Markdown 格式。

**参数:**

| 参数 | 类型 | 必需 | 说明 |
|------|------|------|------|
| uri | string | 是 | 文档 URI,支持: `file://`, `http://`, `https://` |

**支持的格式:**

| 格式 | 扩展名 | 状态 |
|------|--------|------|
| PDF | `.pdf` | ✅ |
| Word | `.docx` | ✅ |
| HTML | `.html`, `.htm` | ✅ |
| PowerPoint | `.pptx` | ✅ |
| Excel | `.xlsx` | ✅ |
| EPUB | `.epub` | ✅ |
| 文本 | `.txt`, `.csv`, `.json` | ✅ |

**示例请求:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "convert_to_markdown",
    "arguments": {
      "uri": "file:///path/to/document.pdf"
    }
  },
  "id": 3
}
```

**示例响应:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "# Converted Markdown\n\n..."
      }
    ]
  },
  "id": 3
}
```

---

## MCP 协议方法

### initialize

初始化 MCP 会话。

**请求:**

```json
{
  "jsonrpc": "2.0",
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "capabilities": {},
    "clientInfo": {
      "name": "client-name",
      "version": "1.0.0"
    }
  },
  "id": 1
}
```

**响应:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": {
      "tools": {}
    },
    "serverInfo": {
      "name": "moonbitmark",
      "version": "0.6.0",
      "protocolVersion": "2024-11-05"
    }
  },
  "id": 1
}
```

### tools/list

列出所有可用工具。

**请求:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/list",
  "id": 2
}
```

**响应:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "tools": [
      {
        "name": "convert_to_markdown",
        "description": "Convert a document (PDF, DOCX, HTML, etc.) to Markdown format",
        "inputSchema": {
          "type": "object",
          "properties": {
            "uri": {
              "type": "string",
              "description": "URI of the document to convert"
            }
          },
          "required": ["uri"]
        }
      }
    ]
  },
  "id": 2
}
```

### tools/call

调用指定工具。

**请求:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "convert_to_markdown",
    "arguments": {
      "uri": "file:///path/to/document.pdf"
    }
  },
  "id": 3
}
```

**响应:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "# Document\n\nContent..."
      }
    ]
  },
  "id": 3
}
```

---

## 故障排查

### 问题: Claude Desktop 无法连接到 MCP 服务器

**可能原因:**
1. 可执行文件路径不正确
2. 可执行文件没有执行权限
3. 配置文件 JSON 格式错误

**解决方案:**
1. 检查路径是否正确,使用绝对路径
2. 确保可执行文件已编译并存在
3. 使用 JSON 验证工具检查配置文件格式
4. 查看 Claude Desktop 日志(菜单 > Help > Show Logs)

### 问题: 工具调用返回错误

**可能原因:**
1. 文件路径不正确
2. 文件格式不支持
3. 文件损坏或加密

**解决方案:**
1. 检查文件路径是否正确,使用完整的 URI 格式
2. 确认文件格式在支持列表中
3. 尝试用其他工具打开文件确认文件完整性

### 问题: MCP 服务器崩溃

**可能原因:**
1. JSON 解析错误
2. 内存不足
3. 文件 I/O 错误

**解决方案:**
1. 检查发送的 JSON 请求格式是否正确
2. 尝试转换较小的文件
3. 检查文件权限

---

## 性能优化建议

### 1. 使用本地文件

尽可能使用本地文件而非 URL 转换,因为本地转换速度更快:

```json
{
  "uri": "file:///path/to/file.pdf"  // 优先
}
```

```json
{
  "uri": "https://example.com/file.pdf"  // 较慢
}
```

### 2. 批量处理

对于多个文件,可以并行调用工具:

```json
// 并行调用多个转换
[
  {"name": "convert_to_markdown", "arguments": {"uri": "file:///file1.pdf"}},
  {"name": "convert_to_markdown", "arguments": {"uri": "file:///file2.pdf"}}
]
```

### 3. 缓存结果

如果频繁转换相同文件,可以考虑在客户端缓存结果。

---

## 开发信息

### 项目结构

```
MoonBitMark/
├── src/mcp/
│   ├── types/           # MCP 和 JSON-RPC 类型定义
│   ├── transport/       # 传输层实现 (STDIO)
│   └── handler/         # MCP 请求处理和工具注册
└── cmd/mcp-server/      # MCP 服务器 CLI 入口
```

### 添加新工具

要添加新的 MCP 工具:

1. 在 `src/mcp/handler/tools.mbt` 中添加工具处理函数
2. 在 `ToolRegistry::register_convert_tools()` 中注册新工具
3. 重新编译项目

### 调试

启用调试模式:

1. 在命令行运行服务器
2. 查看标准输出的调试信息
3. 使用 MCP Inspector 工具进行调试

---

## 参考资源

- **MCP 官方文档**: https://modelcontextprotocol.io
- **MCP 规范**: https://modelcontextprotocol.io/specification
- **Claude Desktop 文档**: https://claude.ai/download
- **MoonBitMark README**: [项目根目录 README.md](../README.md)
- **MCP 设计文档**: [mcp-service-design.md](mcp-service-design.md)

---

## 更新日志

### v0.1.0 (2026-03-12)

**新增:**
- MCP 协议实现
- STDIO 传输支持
- convert_to_markdown 工具
- 基础 JSON-RPC 2.0 处理

**已知限制:**
- JSON 解析器为简化实现,可能不支持所有 JSON 特性
- 仅支持 STDIO 传输,HTTP/SSE 传输待实现
- 工具转换逻辑为占位符,需要集成现有转换器

---

## 反馈和贡献

如有问题或建议,请:
1. 查看已知问题文档: [KNOWN_ISSUES.md](KNOWN_ISSUES.md)
2. 提交 Issue 到项目仓库
3. 参考开发文档: [mcp-service-design.md](mcp-service-design.md)

---

**最后更新:** 2026-03-12 | **版本:** 0.1.0 | **状态:** MVP 阶段
