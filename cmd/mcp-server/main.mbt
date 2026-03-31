// MoonBitMark MCP Server - CLI Entry Point

///|
/// 打印使用说明
fn print_usage() -> Unit {
  println("MoonBitMark MCP Server v0.3.0")
  println("")
  println("Recommended local entry points:")
  println("  - cmd /d /c scripts\\mcp\\moonbitmark-mcp.cmd")
  println(
    "  - powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts\\mcp\\moonbitmark-mcp.ps1",
  )
  println("")
  println("Fallback:")
  println("  - moon run --target native --release -q cmd/mcp-server")
  println("")
  println(
    "Verified STDIO methods: initialize, tools/list, tools/call, resources/list, resources/read, prompts/list, prompts/get",
  )
  println(
    "Transport: STDIO only, JSON-RPC 2.0 framing by newline-delimited requests.",
  )
  println("")
  println("Available tools:")
  println(
    "  - inspect_document: Detect format, size, OCR/bridge risk, preview recommendation",
  )
  println(
    "  - convert_to_markdown: Preview by default, full when explicitly requested",
  )
  println("  - resources/read: Static capability and boundary resources")
  println(
    "  - prompts/get: Guided prompt templates for conversion and diagnosis",
  )
  println("")
  println("Validation:")
  println("  - powershell -File tests/integration/mcp_stdio_smoke.ps1")
  println("  - powershell -File tests/integration/mcp_resources_smoke.ps1")
  println("  - powershell -File tests/integration/mcp_prompts_smoke.ps1")
  println("  - powershell -File tests/integration/mcp_security_smoke.ps1")
  println("")
  println("Security envs:")
  println("  - MOONBITMARK_MCP_ALLOWED_ROOTS")
  println("  - MOONBITMARK_MCP_ALLOW_HTTP")
  println("  - MOONBITMARK_MCP_ENABLE_OCR")
  println("  - MOONBITMARK_MCP_MAX_OUTPUT_CHARS")
  println("")
  println("Current limits: no HTTP transport, no SSE, no streaming responses.")
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
