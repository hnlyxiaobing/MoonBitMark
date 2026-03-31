///|
fn print_usage() -> Unit {
  println("MoonBitMark MCP HTTP Server v0.3.0")
  println("")
  println("Usage:")
  println(
    "  moon run --target native --release -q cmd/mcp-http-server -- [--host 127.0.0.1] [--port 8765]",
  )
  println("")
  println("Routes:")
  println("  - POST /mcp")
  println("  - GET /healthz")
  println("")
  println("JSON-RPC over HTTP:")
  println("  - request with id -> 200 + JSON-RPC response")
  println("  - notification without id -> 204 No Content")
  println("  - parse / invalid request -> 400 + JSON-RPC error")
  println("")
  println("Runtime boundary environment variables:")
  println("  - MOONBITMARK_MCP_ALLOWED_ROOTS")
  println("  - MOONBITMARK_MCP_ALLOW_HTTP")
  println("  - MOONBITMARK_MCP_ENABLE_OCR")
  println("  - MOONBITMARK_MCP_MAX_OUTPUT_CHARS")
  println("  - MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL")
  println("")
  println("Defaults:")
  println("  - host: 127.0.0.1")
  println("  - port: 8765")
  println(
    "  - non-loopback binding: disabled unless MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL=1",
  )
  println("")
  println(
    "Current limits: no SSE, no streaming responses, no auth, no file upload.",
  )
}

///|
fn parse_server_args(
  args : Array[String],
) -> @mcp_http.McpHttpServerConfig raise {
  let mut host = @mcp_http.default_mcp_http_bind_host()
  let mut port = @mcp_http.default_mcp_http_port()
  let mut index = 1
  while index < args.length() {
    match args[index] {
      "--help" | "-h" => {
        print_usage()
        return @mcp_http.McpHttpServerConfig::new(bind_host=host, port~)
      }
      "--host" => {
        if index + 1 >= args.length() {
          fail("Missing value after --host")
        }
        host = args[index + 1]
        index = index + 2
      }
      "--port" => {
        if index + 1 >= args.length() {
          fail("Missing value after --port")
        }
        port = @strconv.from_str(args[index + 1]) catch {
          _ => fail("Invalid --port value: " + args[index + 1])
        }
        index = index + 2
      }
      other => fail("Unsupported argument: " + other)
    }
  }
  @mcp_http.McpHttpServerConfig::new(bind_host=host, port~)
}

///|
async fn main {
  let args = @env.args()
  if args.length() > 1 && (args[1] == "--help" || args[1] == "-h") {
    print_usage()
    return
  }

  let config = parse_server_args(args)
  let server = @mcp_http.McpHttpServer::new(config)
  server.run()
}
