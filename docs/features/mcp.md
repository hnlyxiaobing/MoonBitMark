# MCP Support

## Status

MCP remains **experimental** as a product surface, but MoonBitMark now has two verified local transports:

- STDIO via `scripts/mcp/moonbitmark-mcp.cmd` and `scripts/mcp/moonbitmark-mcp.ps1`
- loopback-first HTTP via `cmd/mcp-http-server` with `POST /mcp` and `GET /healthz`

What is verified today:

- Windows STDIO launchers prefer `_build/native/release/build/cmd/mcp-server/mcp-server.exe`
- the STDIO wrapper still falls back to `moon run --target native --release -q cmd/mcp-server`
- HTTP transport is a standalone entrypoint and does not reuse the CLI entry
- HTTP defaults to `127.0.0.1` and rejects `0.0.0.0` unless `MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL=1`
- JSON-RPC over HTTP returns `200` for normal requests, `204` for notifications, and `400` for parse / invalid requests
- `initialize`, `tools/list`, `tools/call`, `resources/list`, `resources/read`, `prompts/list`, and `prompts/get` are smoke-checked on both transports
- `inspect_document`, `convert_to_markdown`, `upload_document`, and `convert_uploaded_document` stay agent-friendly, with preview-first conversion remaining the default
- `response_mode=json` returns stable `structuredContent` objects with `content`, `metadata`, `diagnostics`, and `stats`
- `upload_document` creates reusable `moonbitmark://document/<id>` resources, `inspect_document` and `convert_to_markdown` accept `resource_uri`, and `convert_uploaded_document` remains the one-shot bytes path
- the static resources and prompts remain available on both transports, and `resources/read` can also resolve uploaded `moonbitmark://document/<id>` resources
- MCP runtime boundaries are enforced by `MOONBITMARK_MCP_ALLOWED_ROOTS`, `MOONBITMARK_MCP_ALLOW_HTTP`, `MOONBITMARK_MCP_ENABLE_OCR`, `MOONBITMARK_MCP_MAX_OUTPUT_CHARS`, and `MOONBITMARK_MCP_MAX_UPLOAD_BYTES`

What is not claimed:

- SSE transport
- streaming responses
- progress channels for long-running conversions
- auth / OAuth / bearer-token flows
- direct multipart upload, SSE streaming, or a separate `resource://...` protocol

## Recommended Entry Points

STDIO wrapper:

```bat
scripts\mcp\moonbitmark-mcp.cmd
```

STDIO PowerShell variant:

```powershell
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts\mcp\moonbitmark-mcp.ps1
```

HTTP server:

```bash
moon run --target native --release -q cmd/mcp-http-server -- --host 127.0.0.1 --port 8765
```

Health check:

```bash
curl http://127.0.0.1:8765/healthz
```

## Client Registration

Claude Code STDIO project config:

```json
{
  "mcpServers": {
    "moonbitmark": {
      "command": "cmd",
      "args": ["/d", "/c", "scripts\\mcp\\moonbitmark-mcp.cmd"],
      "env": {
        "MOONBITMARK_MCP_ALLOWED_ROOTS": ".;tests",
        "MOONBITMARK_MCP_ALLOW_HTTP": "0",
        "MOONBITMARK_MCP_ENABLE_OCR": "0",
        "MOONBITMARK_MCP_MAX_OUTPUT_CHARS": "12000"
      }
    }
  }
}
```

Claude Code HTTP registration:

```bash
claude mcp add --transport http moonbitmark-http http://127.0.0.1:8765/mcp
```

Codex STDIO registration:

```bash
codex mcp add moonbitmark -- cmd /d /c scripts\mcp\moonbitmark-mcp.cmd
```

Codex HTTP registration:

```bash
codex mcp add moonbitmark-http --url http://127.0.0.1:8765/mcp
```

Equivalent Codex `config.toml` for STDIO:

```toml
[mcp_servers.moonbitmark]
command = "cmd"
args = ["/d", "/c", "scripts\\mcp\\moonbitmark-mcp.cmd"]
env = { MOONBITMARK_MCP_ALLOWED_ROOTS = ".;tests", MOONBITMARK_MCP_ALLOW_HTTP = "0", MOONBITMARK_MCP_ENABLE_OCR = "0", MOONBITMARK_MCP_MAX_OUTPUT_CHARS = "12000" }
```

## HTTP Contract

HTTP route surface:

- `POST /mcp`
- `GET /healthz`

JSON-RPC status mapping:

- request with `id` -> `200 OK` plus a JSON-RPC response body
- notification without `id` -> `204 No Content`
- malformed JSON or invalid JSON-RPC request object -> `400 Bad Request` plus JSON-RPC error body

Binding policy:

- default host: `127.0.0.1`
- allowed loopback aliases: `127.0.0.1`, `localhost`, `::1`
- `0.0.0.0` is rejected unless `MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL=1`

## Runtime Boundaries

- `MOONBITMARK_MCP_ALLOWED_ROOTS`
  Default: current working directory only.
  File inputs outside these semicolon-separated roots are rejected before inspect/convert.
- `MOONBITMARK_MCP_ALLOW_HTTP`
  Default: disabled.
  `http://` and `https://` inputs are rejected unless this env is `1` or `true`.
- `MOONBITMARK_MCP_ENABLE_OCR`
  Default: disabled.
  MCP only opts into OCR auto mode when this env is `1` or `true`.
- `MOONBITMARK_MCP_MAX_OUTPUT_CHARS`
  Default: unset.
  Returned Markdown is clamped even in `mode=full` when this env is set.
- `MOONBITMARK_MCP_MAX_UPLOAD_BYTES`
  Default: `10485760`.
  Caps the payload size for `upload_document` and `convert_uploaded_document`.
- `MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL`
  Default: disabled.
  Required to bind the HTTP server to `0.0.0.0`.

## Automated Validation

```powershell
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_stdio_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_resources_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_prompts_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_security_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_http_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_http_security_smoke.ps1
```

These scripts prove the current public local contract. They do not claim SSE support, remote upload semantics, or broader protocol compatibility beyond the smoke-checked path.

## Tool Surface

Registered tools:

- `inspect_document`
- `convert_to_markdown`
- `upload_document`
- `convert_uploaded_document`

Accepted document references:

- `uri`: normal file path string, `file://...`, `http://...`, or `https://...`
- `resource_uri`: `moonbitmark://document/<id>` returned by `upload_document`

Uploaded input surfaces:

- `upload_document.filename`
- exactly one of `upload_document.data_base64` or `upload_document.data_bytes`
- `convert_uploaded_document.filename`
- exactly one of `convert_uploaded_document.data_base64` or `convert_uploaded_document.data_bytes`

Tool response pattern today:

- first text item: compact `key: value` summary for agents
- second text item on conversion: Markdown body
- add `response_mode=json` when you want `result.structuredContent` instead of text-first parsing

Structured JSON shape:

- `content`: primary textual payload
- `metadata`: request/result identity fields
- `diagnostics`: booleans, guidance, warnings, and conversion diagnostics
- `stats`: output sizing and converter statistics

Recommended agent flow:

1. call `prompts/list` when you want a guided conversion or diagnosis template
2. call `prompts/get` for `convert-document` or `diagnose-conversion-failure`
3. call `resources/list` when you need server capability or boundary context
4. call `resources/read` for the specific `moonbitmark://...` resource you need
5. call `upload_document` when the client only has bytes and needs a reusable handle
6. call `inspect_document` with `uri` or `resource_uri`
7. use `convert_uploaded_document` only for one-shot upload + convert
8. otherwise call `convert_to_markdown` without `mode` for preview
9. add `response_mode=json` when an agent or program needs structured parsing
10. re-run with `mode=full` only when the preview shows the document is worth expanding

## Resources And Prompts

Static resources:

- `moonbitmark://capabilities`
- `moonbitmark://supported-formats`
- `moonbitmark://known-issues`
- `moonbitmark://ocr-boundaries`
- `moonbitmark://mcp-usage`

Dynamic resources:

- `moonbitmark://document/<id>` returned by `upload_document`

Static prompts:

- `convert-document`
- `diagnose-conversion-failure`

## Implementation Path

```text
STDIO
scripts/mcp/*
  -> _build/native/release/build/cmd/mcp-server/mcp-server.exe
  -> or moon run --target native --release -q cmd/mcp-server
  -> src/mcp/transport/stdio
  -> src/mcp/handler/server

HTTP
cmd/mcp-http-server
  -> src/mcp/transport/http
  -> src/mcp/handler/server
  -> src/mcp/handler/tools
  -> src/mcp/handler/resources
  -> src/mcp/handler/prompts
```

## Operational Notes

- Keep stdout reserved for protocol responses on STDIO.
- Keep the HTTP server loopback-first unless you have an explicit nonlocal requirement.
- Reject unsupported JSON-RPC versions instead of guessing.
- Notifications without `id` must not emit JSON-RPC responses.
- Prefer preview-first conversion from agents unless the full Markdown is actually needed.
