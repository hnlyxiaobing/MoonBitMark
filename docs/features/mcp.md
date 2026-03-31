# MCP Support

## Status

MCP is still **experimental** as a capability surface, but the local STDIO entrypoint is now treated as a productized integration boundary.

What is verified today:

- Windows launchers exist at `scripts/mcp/moonbitmark-mcp.cmd` and `scripts/mcp/moonbitmark-mcp.ps1`
- the launchers prefer the native release binary at `_build/native/release/build/cmd/mcp-server/mcp-server.exe`
- if that release binary is missing, the PowerShell launcher falls back to `moon run --target native --release -q cmd/mcp-server`
- STDIO transport is newline-delimited JSON-RPC 2.0
- `initialize`, `tools/list`, `tools/call`, and `notifications/initialized` are smoke-checked
- stdout stays reserved for protocol responses on the smoke-checked path

What is not claimed:

- HTTP / SSE transport
- prompts / resources support
- streaming responses
- broad protocol compatibility beyond the smoke-checked path

## Recommended Local Entry Point

Windows `cmd.exe` / wrapper path:

```bat
scripts\mcp\moonbitmark-mcp.cmd
```

Windows PowerShell path:

```powershell
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts\mcp\moonbitmark-mcp.ps1
```

Direct MoonBit fallback:

```bash
moon run --target native --release -q cmd/mcp-server
```

The wrapper path is the recommended integration surface because it keeps client configuration stable while preferring the release binary when available.

## Claude Code Configuration

Project-level `.mcp.json` example for Windows:

```json
{
  "mcpServers": {
    "moonbitmark": {
      "command": "cmd",
      "args": [
        "/d",
        "/c",
        "scripts\\mcp\\moonbitmark-mcp.cmd"
      ]
    }
  }
}
```

PowerShell variant:

```json
{
  "mcpServers": {
    "moonbitmark": {
      "command": "powershell",
      "args": [
        "-NoLogo",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "scripts\\mcp\\moonbitmark-mcp.ps1"
      ]
    }
  }
}
```

The `.cmd` form is the primary recommendation on Windows because it matches the smoke-checked `cmd /c` path.

## Codex Configuration

Registration command example from the repository root:

```powershell
codex mcp add moonbitmark -- cmd /d /c scripts\mcp\moonbitmark-mcp.cmd
```

Equivalent `config.toml` snippet:

```toml
[mcp_servers.moonbitmark]
command = "cmd"
args = ["/d", "/c", "scripts\\mcp\\moonbitmark-mcp.cmd"]
```

This keeps the integration pinned to the wrapper instead of the build output path.

## Automated validation

```powershell
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_stdio_smoke.ps1
```

That script is the authoritative P0-A contract check for the public local STDIO entrypoint. It verifies:

- `cmd /c scripts\mcp\moonbitmark-mcp.cmd`
- `powershell -File scripts\mcp\moonbitmark-mcp.ps1`
- notification handling without stdout response
- `initialize`
- `tools/list`
- `tools/call`

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
scripts/mcp/*
  -> _build/native/release/build/cmd/mcp-server/mcp-server.exe
  -> or moon run --target native --release -q cmd/mcp-server
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
- Prefer configuring clients against the wrapper, not directly against `_build/.../mcp-server.exe`.
