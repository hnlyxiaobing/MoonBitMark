# MCP Integration Checks

`tests/integration/mcp_stdio_smoke.ps1` verifies the minimum supported STDIO loop and launcher boundary:

- start the public Windows launchers
- verify the wrapper still works when `moon` is not on the child `PATH` and the release binary is present
- force the launcher fallback path to `moon run --target native --release -q cmd/mcp-server`
- verify initialize instructions stay agent-facing
- send `initialize`
- send `tools/list`
- send `inspect_document`
- send `convert_to_markdown` in default preview mode and explicit full mode
- cover a negative `mode` validation path

`tests/integration/mcp_resources_smoke.ps1` verifies the first static resource tranche:

- initialize advertises the `resources` capability
- `resources/list` exposes the documented `moonbitmark://...` URIs
- `resources/read` returns text/markdown content for static resources
- missing resources return a `-32002` JSON-RPC error without polluting stdout/stderr

`tests/integration/mcp_prompts_smoke.ps1` verifies the first prompt tranche:

- initialize advertises the `prompts` capability
- `prompts/list` exposes `convert-document` and `diagnose-conversion-failure`
- `prompts/get` returns guided message payloads for both prompts
- missing prompts and missing required prompt arguments return structured JSON-RPC errors without polluting stdout/stderr

`tests/integration/mcp_security_smoke.ps1` verifies the first runtime boundary tranche:

- `MOONBITMARK_MCP_ALLOW_HTTP` blocks URL inspection/conversion by default
- `MOONBITMARK_MCP_ALLOWED_ROOTS` restricts file access to configured roots
- `MOONBITMARK_MCP_ENABLE_OCR` is surfaced in tool summaries and enables the MCP OCR opt-in path
- `MOONBITMARK_MCP_MAX_OUTPUT_CHARS` clamps returned Markdown even in `mode=full`

These are existence checks for the public MCP entrypoint. They do not claim HTTP/SSE support, streaming responses, or broad protocol coverage.
