# MCP Integration Checks

`tests/integration/mcp_stdio_smoke.ps1` verifies the minimum supported STDIO loop:

- start the release `cmd/mcp-server` binary
- send `initialize`
- send `tools/list`
- send `tools/call` against a temporary text file

This is an existence check for the public MCP entrypoint. It does not claim HTTP/SSE support, streaming responses, or broad protocol coverage.
