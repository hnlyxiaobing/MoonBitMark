# MCP Support

## 当前实现

MoonBitMark 已提供一个基于 STDIO 的 MCP 服务入口：

```bash
moon run cmd/mcp-server
```

入口文件位于 `cmd/mcp-server/main.mbt`，核心实现位于 `src/mcp/`。

## 能力范围

当前服务实现了：

- `initialize`
- `tools/list`
- `tools/call`

当前只注册了一个工具：

- `convert_to_markdown`

工具参数：

```json
{
  "uri": "file:///path/to/file.docx"
}
```

也接受 `http://`、`https://` 和普通文件路径字符串。

## 实现结构

```text
cmd/mcp-server
  -> transport/stdio
  -> handler/server
  -> handler/tools
  -> engine conversion
```

`tools/call` 最终会调用现有转换主链路，而不是旁路实现一套单独逻辑。

## 使用建议

- 本地联调时先跑 `moon test`，再用 `scripts/test_mcp_server.ps1` 或 `scripts/test_mcp_server.sh` 做最小交互验证。
- 如果只需要 CLI 功能，不必引入 MCP；MCP 主要面向 AI agent / IDE / 工具集成场景。

## 当前限制

- 只有 STDIO 传输，没有 HTTP / SSE。
- 只有一个转换工具，没有 resources / prompts。
- 返回结果以文本 Markdown 为主，不暴露更细的 AST 或资产管理协议。
