///|
pub(all) struct McpHttpServerConfig {
  bind_host : String
  port : Int
}

///|
pub(all) struct McpHttpServer {
  config : McpHttpServerConfig
  dispatcher : @handler.McpDispatcher
  server : @async_http.Server
}

///|
pub fn default_mcp_http_bind_host() -> String {
  "127.0.0.1"
}

///|
pub fn default_mcp_http_port() -> Int {
  8765
}

///|
pub fn McpHttpServerConfig::new(
  bind_host? : String = default_mcp_http_bind_host(),
  port? : Int = default_mcp_http_port(),
) -> McpHttpServerConfig raise {
  if port <= 0 || port > 65535 {
    fail("HTTP MCP port must be between 1 and 65535.")
  }
  let allow_nonlocal = load_http_allow_nonlocal_env()
  let normalized_bind_host = normalize_bind_host(bind_host, allow_nonlocal)
  McpHttpServerConfig::{ bind_host: normalized_bind_host, port }
}

///|
pub fn McpHttpServer::new(config : McpHttpServerConfig) -> McpHttpServer raise {
  let bind_addr = bind_addr_from_config(config)
  let server = @async_http.Server::new(bind_addr)
  McpHttpServer::{ config, dispatcher: @handler.McpDispatcher::new(), server }
}

///|
pub async fn McpHttpServer::run(self : McpHttpServer) -> Unit {
  self.server.run_forever((request, body, conn) => {
    self.handle_request(request, body, conn)
  })
}

///|
async fn McpHttpServer::handle_request(
  self : McpHttpServer,
  request : @async_http.Request,
  body : &@io.Reader,
  conn : @async_http.ServerConnection,
) -> Unit {
  match (request.meth, request.path) {
    (Get, "/healthz") =>
      send_json_response(conn, 200, "OK", "{\"status\":\"ok\"}")
    (Post, "/mcp") => self.handle_mcp_request(body, conn)
    (_, "/healthz") => send_method_not_allowed(conn, "GET")
    (_, "/mcp") => send_method_not_allowed(conn, "POST")
    _ => send_plain_response(conn, 404, "Not Found", "Not Found")
  }
}

///|
async fn McpHttpServer::handle_mcp_request(
  self : McpHttpServer,
  body : &@io.Reader,
  conn : @async_http.ServerConnection,
) -> Unit {
  let payload = body.read_all().text() catch {
      err => {
        send_jsonrpc_response(
          conn,
          400,
          "Bad Request",
          invalid_request_response("Invalid request body: " + err.to_string()),
        )
        return
      }
    }

  let response = self.dispatcher.handle_jsonrpc_request(payload)
  match response {
    Some(value) =>
      if is_http_bad_request_response(value) {
        send_jsonrpc_response(conn, 400, "Bad Request", value)
      } else {
        send_jsonrpc_response(conn, 200, "OK", value)
      }
    None => send_empty_response(conn, 204, "No Content")
  }
}

///|
fn bind_addr_from_config(config : McpHttpServerConfig) -> @socket.Addr raise {
  let host = config.bind_host
  let raw = if host == "[::1]" {
    "[::1]:\{config.port}"
  } else {
    "\{host}:\{config.port}"
  }
  @socket.Addr::parse(raw)
}

///|
fn invalid_request_response(message : String) -> @types.JsonResponse {
  @types.JsonResponse::{
    jsonrpc: "2.0",
    result: None,
    error: Some(@types.JsonError::{ code: -32700, message, data: None }),
    id: None,
  }
}

///|
fn is_http_bad_request_response(response : @types.JsonResponse) -> Bool {
  match response.error {
    Some(error) => error.code == -32700 || error.code == -32600
    None => false
  }
}

///|
async fn send_jsonrpc_response(
  conn : @async_http.ServerConnection,
  status_code : Int,
  reason : String,
  response : @types.JsonResponse,
) -> Unit {
  send_json_response(conn, status_code, reason, response.to_json().to_string())
}

///|
async fn send_json_response(
  conn : @async_http.ServerConnection,
  status_code : Int,
  reason : String,
  body : String,
) -> Unit {
  conn
  ..send_response(status_code, reason, extra_headers=json_headers())
  ..write(body)
  .end_response()
}

///|
async fn send_plain_response(
  conn : @async_http.ServerConnection,
  status_code : Int,
  reason : String,
  body : String,
) -> Unit {
  conn
  ..send_response(status_code, reason, extra_headers={
    "Content-Type": "text/plain; charset=utf-8",
  })
  ..write(body)
  .end_response()
}

///|
async fn send_method_not_allowed(
  conn : @async_http.ServerConnection,
  allow : String,
) -> Unit {
  conn
  ..send_response(405, "Method Not Allowed", extra_headers={
    "Allow": allow,
    "Content-Type": "text/plain; charset=utf-8",
  })
  ..write("Method Not Allowed")
  .end_response()
}

///|
async fn send_empty_response(
  conn : @async_http.ServerConnection,
  status_code : Int,
  reason : String,
) -> Unit {
  conn.send_response(status_code, reason)
  conn.end_response()
}

///|
fn json_headers() -> Map[String, String] {
  { "Content-Type": "application/json; charset=utf-8" }
}

///|
fn load_http_allow_nonlocal_env() -> Bool raise {
  match @env.get_env_var("MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL") {
    Some(raw) if raw.trim() != "" => parse_bool(raw.trim().to_string())
    _ => false
  }
}

///|
fn normalize_bind_host(
  bind_host : String,
  allow_nonlocal : Bool,
) -> String raise {
  let normalized = bind_host.trim().to_lower().to_string()
  match normalized {
    "" => default_mcp_http_bind_host()
    "127.0.0.1" => "127.0.0.1"
    "localhost" => "127.0.0.1"
    "::1" => "[::1]"
    "[::1]" => "[::1]"
    "0.0.0.0" =>
      if allow_nonlocal {
        "0.0.0.0"
      } else {
        fail("Binding 0.0.0.0 requires MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL=1.")
      }
    _ =>
      fail(
        "Unsupported MCP HTTP bind host: " +
        bind_host +
        ". Use 127.0.0.1, localhost, ::1, or 0.0.0.0 with MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL=1.",
      )
  }
}

///|
fn parse_bool(raw : String) -> Bool raise {
  match raw.to_lower() {
    "1" => true
    "true" => true
    "yes" => true
    "on" => true
    "0" => false
    "false" => false
    "no" => false
    "off" => false
    _ =>
      fail(
        "MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL must be one of: 1, 0, true, false, yes, no, on, off.",
      )
  }
}
