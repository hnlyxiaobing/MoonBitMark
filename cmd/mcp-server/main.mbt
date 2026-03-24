// MoonBitMark MCP Server - CLI Entry Point

///|
/// 打印使用说明
fn print_usage() -> Unit {
  println("MoonBitMark MCP Server v0.3.0 (experimental)")
  println("")
  println("Usage: moon run cmd/mcp-server")
  println("")
  println(
    "This command exposes a minimal STDIO MCP server for integration tests",
  )
  println("and early tool/agent experiments.")
  println("")
  println("Verified methods: initialize, tools/list, tools/call")
  println(
    "Transport: STDIO only, JSON-RPC 2.0 framing by newline-delimited requests.",
  )
  println("")
  println("Available tools:")
  println("  - convert_to_markdown: Convert documents to Markdown")
  println("")
  println("Validation:")
  println("  - powershell -File tests/integration/mcp_stdio_smoke.ps1")
  println("")
  println(
    "Current limits: no HTTP/SSE, no prompts/resources, no streaming responses.",
  )
}

///|
/// 主函数
async fn main {
  let args = @env.args()

  if args.length() > 1 && (args[1] == "--help" || args[1] == "-h") {
    print_usage()
    return
  }

  // 创建 STDIO 传输
  let transport = @transport.StdioTransport::new()

  // 创建 MCP 服务器
  let server = @handler.McpServer::new(transport)

  // 运行服务器主循环
  server.run()
}
