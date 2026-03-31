# MCP Support

## Status

MCP is currently **experimental**, but the STDIO contract is now treated as the first hard boundary.

What is verified today:

- package entrypoint exists at `cmd/mcp-server`
- transport is STDIO only
- newline-delimited JSON-RPC requests work for:
  - `initialize`
  - `tools/list`
  - `tools/call`
  - `notifications/initialized` (no stdout response)
- stdout stays reserved for protocol responses in the smoke-checked path
- the live server path does not retain a logger, so protocol framing does not depend on a logger implementation detail

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
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_stdio_smoke.ps1
```

That script is the authoritative first-phase contract check for the public MCP entrypoint.

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
- If logging is reintroduced later, route it outside the live STDIO protocol path before expanding MCP scope.
- Reject unsupported `jsonrpc` versions instead of guessing.
- Notifications without `id` must not emit JSON-RPC responses.
- Do not treat `conversion_eval` quality scores as proof that MCP is fully implemented.
- If this entrypoint expands later, add integration checks before upgrading its documentation maturity.
