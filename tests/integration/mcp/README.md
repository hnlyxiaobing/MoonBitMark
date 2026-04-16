# MCP Integration Checks

`tests/integration/mcp_stdio_smoke.ps1` verifies the public STDIO loop and launcher boundary:

- start the Windows launcher paths
- verify the wrapper still works when `moon` is not on the child `PATH` and the release binary is present
- force the launcher fallback path to `moon run --target native --release -q cmd/mcp-server`
- verify initialize instructions stay agent-facing
- send `initialize`
- send `tools/list`
- send `inspect_document`
- send `convert_to_markdown` in preview mode and explicit full mode
- send `upload_document` and reuse the returned `resource_uri`
- verify `response_mode=json` returns `structuredContent`
- cover a negative `mode` validation path
- verify notifications do not emit stdout responses

`tests/integration/mcp_resources_smoke.ps1` verifies static resources over STDIO:

- initialize advertises the `resources` capability
- `resources/list` exposes the documented `moonbitmark://...` URIs
- `resources/read` returns text/markdown content for static resources
- missing resources return a `-32002` JSON-RPC error without polluting stdout/stderr

`tests/integration/mcp_prompts_smoke.ps1` verifies static prompts over STDIO:

- initialize advertises the `prompts` capability
- `prompts/list` exposes `convert-document` and `diagnose-conversion-failure`
- `prompts/get` returns guided message payloads for both prompts
- missing prompts and missing required prompt arguments return structured JSON-RPC errors without polluting stdout/stderr

`tests/integration/mcp_security_smoke.ps1` verifies runtime boundaries over STDIO:

- `MOONBITMARK_MCP_ALLOW_HTTP` blocks URL inspection/conversion by default
- `MOONBITMARK_MCP_ALLOWED_ROOTS` restricts file access to configured roots
- `MOONBITMARK_MCP_ENABLE_OCR` is surfaced in tool summaries and enables the MCP OCR opt-in path
- `MOONBITMARK_MCP_MAX_OUTPUT_CHARS` clamps returned Markdown even in `mode=full`

`tests/integration/mcp_http_smoke.ps1` verifies the standalone HTTP transport:

- start `_build/native/release/build/cmd/mcp-http-server/mcp-http-server.exe`
- wait for `GET /healthz`
- verify `POST /mcp` handles notifications with `204 No Content`
- verify malformed JSON returns `400 Bad Request`
- send `initialize`
- send `tools/list` and `tools/call`
- verify `response_mode=json` returns `structuredContent`
- verify `upload_document -> resource_uri -> inspect/convert` works over both STDIO and HTTP
- send `resources/list` and `resources/read`
- send `prompts/list` and `prompts/get`

`tests/integration/mcp_http_security_smoke.ps1` verifies HTTP-specific safety and boundary reuse:

- default binding rejects `0.0.0.0` unless `MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL=1`
- explicit `0.0.0.0` opt-in still works via loopback requests
- `MOONBITMARK_MCP_ALLOW_HTTP` blocks URL inspection on the HTTP transport too
- `MOONBITMARK_MCP_ALLOWED_ROOTS`, `MOONBITMARK_MCP_ENABLE_OCR`, `MOONBITMARK_MCP_MAX_OUTPUT_CHARS`, and `MOONBITMARK_MCP_MAX_UPLOAD_BYTES` all stay effective on the HTTP path

These are contract checks for the current local MCP surface. They do not claim SSE support, streaming responses, authentication, or multipart/raw-binary upload endpoints.

For development rounds that touch OCR and MCP together, prefer the repo-level smoke entrypoint:

- `powershell -ExecutionPolicy Bypass -File scripts/run_ocr_mcp_smoke.ps1`
