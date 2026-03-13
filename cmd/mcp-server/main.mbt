// MoonBitMark MCP Server - CLI Entry Point

use @handler.*
use @transport.*

///|
/// 打印使用说明
fn print_usage() -> Unit {
  println("MoonBitMark MCP Server v0.1.0")
  println("")
  println("Usage: moon run cmd/mcp-server")
  println("")
  println("This server implements the Model Context Protocol (MCP)")
  println("and provides document conversion tools.")
  println("")
  println("The server communicates via STDIO, following JSON-RPC 2.0.")
  println("")
  println("Available tools:")
  println("  - convert_to_markdown: Convert documents to Markdown")
  println("")
  println("Supported formats:")
  println("  - PDF (.pdf)")
  println("  - Word (.docx)")
  println("  - HTML (.html, .htm)")
  println("  - PowerPoint (.pptx)")
  println("  - Excel (.xlsx)")
  println("  - EPUB (.epub)")
  println("  - Text (.txt, .csv, .json)")
  println("")
  println("See https://modelcontextprotocol.io for more information.")
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
  let transport = StdioTransport::new()

  // 创建 MCP 服务器
  let server = McpServer::new(transport)

  // 运行服务器主循环
  server.run()
}
