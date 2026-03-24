# MCP Support

## Status

MCP is currently **experimental**.

What is verified today:

- package entrypoint exists at `cmd/mcp-server`
- transport is STDIO only
- newline-delimited JSON-RPC requests work for:
  - `initialize`
  - `tools/list`
  - `tools/call`

What is not claimed:

- HTTP / SSE transport
- prompts / resources support
- streaming responses
- broad protocol compatibility beyond the smoke-checked path

## Run

```bash
moon run cmd/mcp-server
```

## Automated validation

```powershell
powershell -File tests/integration/mcp_stdio_smoke.ps1
```

That script is the authoritative first-phase existence check for the public MCP entrypoint.

## Tool surface

Registered tool:

- `convert_to_markdown`

Accepted `uri` forms:

- normal file path string
- `http://...`
- `https://...`
- `file://...` (best-effort; plain paths are simpler on Windows)

## Implementation path

```text
cmd/mcp-server
  -> src/mcp/transport/stdio
  -> src/mcp/handler/server
  -> src/mcp/handler/tools
  -> src/engine
```

## Operational notes

- Keep stdout reserved for protocol responses.
- Do not treat `conversion_eval` quality scores as proof that MCP is fully implemented.
- If this entrypoint expands later, add integration checks before upgrading its documentation maturity.
