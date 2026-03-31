# MCP Support

## Status

MCP is still **experimental** as a capability surface, but the local STDIO entrypoint is now treated as a productized integration boundary.

What is verified today:

- Windows launchers exist at `scripts/mcp/moonbitmark-mcp.cmd` and `scripts/mcp/moonbitmark-mcp.ps1`
- the launchers prefer the native release binary at `_build/native/release/build/cmd/mcp-server/mcp-server.exe`
- if that release binary is missing, the PowerShell launcher falls back to `moon run --target native --release -q cmd/mcp-server`
- the smoke check forces both the release-preferred path and the `moon run` fallback path
- STDIO transport is newline-delimited JSON-RPC 2.0
- `initialize`, `tools/list`, `tools/call`, and `notifications/initialized` are smoke-checked
- `resources/list` and `resources/read` are smoke-checked
- `prompts/list` and `prompts/get` are smoke-checked
- the server exposes agent-facing initialize instructions
- `inspect_document` and `convert_to_markdown` are both smoke-checked
- the server exposes five static `moonbitmark://...` resources for capability and boundary discovery
- the server exposes two static guided prompts for conversion and failure diagnosis
- MCP runtime boundaries can be controlled with `MOONBITMARK_MCP_ALLOWED_ROOTS`, `MOONBITMARK_MCP_ALLOW_HTTP`, `MOONBITMARK_MCP_ENABLE_OCR`, and `MOONBITMARK_MCP_MAX_OUTPUT_CHARS`
- `convert_to_markdown` defaults to preview mode so large documents do not dump full Markdown by accident
- stdout stays reserved for protocol responses on the smoke-checked path

What is not claimed:

- HTTP / SSE transport
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
      "env": {
        "MOONBITMARK_MCP_ALLOWED_ROOTS": ".;tests",
        "MOONBITMARK_MCP_ALLOW_HTTP": "0",
        "MOONBITMARK_MCP_ENABLE_OCR": "0",
        "MOONBITMARK_MCP_MAX_OUTPUT_CHARS": "12000"
      },
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
env = { MOONBITMARK_MCP_ALLOWED_ROOTS = ".;tests", MOONBITMARK_MCP_ALLOW_HTTP = "0", MOONBITMARK_MCP_ENABLE_OCR = "0", MOONBITMARK_MCP_MAX_OUTPUT_CHARS = "12000" }
```

This keeps the integration pinned to the wrapper instead of the build output path.

## Automated validation

```powershell
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_stdio_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_resources_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_prompts_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_security_smoke.ps1
```

These scripts are the current contract checks for the public local STDIO entrypoint. They verify:

- `cmd /c scripts\mcp\moonbitmark-mcp.cmd`
- `powershell -File scripts\mcp\moonbitmark-mcp.ps1`
- release-binary preference on the wrapper path
- forced fallback to `moon run --target native --release -q cmd/mcp-server`
- notification handling without stdout response
- `initialize`
- `tools/list`
- agent-facing `instructions`
- `inspect_document`
- `convert_to_markdown` preview mode
- `convert_to_markdown` full mode with `max_chars`
- invalid `mode` rejection path
- `resources/list`
- `resources/read`
- static `moonbitmark://...` resource discovery
- missing-resource error handling
- `prompts/list`
- `prompts/get`
- static `convert-document` and `diagnose-conversion-failure` prompt discovery
- missing-prompt and missing-argument prompt error handling
- `MOONBITMARK_MCP_ALLOW_HTTP` URL denial path
- `MOONBITMARK_MCP_ALLOWED_ROOTS` file-root denial path
- `MOONBITMARK_MCP_ENABLE_OCR` env surfacing and OCR auto opt-in context
- `MOONBITMARK_MCP_MAX_OUTPUT_CHARS` output clamping

## Tool surface

Registered tools:

- `inspect_document`
- `convert_to_markdown`

Accepted `uri` forms:

- normal file path string
- `http://...`
- `https://...`
- `file://...` (best-effort; plain paths are simpler on Windows)

`inspect_document` returns:

- detected format
- file size for local files
- whether OCR / bridge behavior is relevant for that format
- whether preview is recommended before full conversion

`convert_to_markdown` accepts:

- `mode=preview|full`
- `max_chars`
- `format_hint` (advisory only in the current MCP path)

Runtime boundary envs:

- `MOONBITMARK_MCP_ALLOWED_ROOTS`
  Current default: current working directory only.
  Semantics: file inputs outside these semicolon-separated roots are rejected before detect/convert.
- `MOONBITMARK_MCP_ALLOW_HTTP`
  Current default: disabled.
  Semantics: `http://` and `https://` inputs are rejected unless this env is `1` or `true`.
- `MOONBITMARK_MCP_ENABLE_OCR`
  Current default: disabled.
  Semantics: MCP only opts into OCR auto mode when this env is `1` or `true`.
- `MOONBITMARK_MCP_MAX_OUTPUT_CHARS`
  Current default: unset.
  Semantics: when set, it clamps returned Markdown even in `mode=full`.

Tool response pattern:

- first text item: compact `key: value` summary for agents
- second text item on conversion: Markdown body

Recommended agent flow:

1. call `prompts/list` when you want a guided conversion or diagnosis template
2. call `prompts/get` for `convert-document` or `diagnose-conversion-failure`
3. call `resources/list` when you need server capability or boundary context
4. call `resources/read` for the specific `moonbitmark://...` resource you need
5. call `inspect_document`
6. call `convert_to_markdown` without `mode` for preview
7. re-run with `mode=full` only when the preview shows the document is worth expanding

## Resources

Static resources exposed today:

- `moonbitmark://capabilities`
- `moonbitmark://supported-formats`
- `moonbitmark://known-issues`
- `moonbitmark://ocr-boundaries`
- `moonbitmark://mcp-usage`

These resources are intentionally static and conservative. They summarize the current verified capability surface and boundaries without claiming HTTP transport or broader protocol features that do not exist yet.

## Prompts

Static prompts exposed today:

- `convert-document`
- `diagnose-conversion-failure`

These prompts are workflow templates, not autonomous execution. They return guided message payloads that point agents back to the actual MoonBitMark tools and resources.

## Implementation path

```text
scripts/mcp/*
  -> _build/native/release/build/cmd/mcp-server/mcp-server.exe
  -> or moon run --target native --release -q cmd/mcp-server
  -> src/mcp/transport/stdio
  -> src/mcp/handler/server
  -> src/mcp/handler/tools
  -> src/mcp/handler/resources
  -> src/mcp/handler/prompts
  -> src/engine
```

## Operational notes

- Keep stdout reserved for protocol responses.
- If logging is reintroduced later, route it outside the live STDIO protocol path before expanding MCP scope.
- Reject unsupported `jsonrpc` versions instead of guessing.
- Notifications without `id` must not emit JSON-RPC responses.
- Prefer configuring clients against the wrapper, not directly against `_build/.../mcp-server.exe`.
