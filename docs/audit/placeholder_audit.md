# Placeholder Audit

Audit date: `2026-03-24`

Scope:

- `src/mcp/`
- `src/capabilities/ocr/`
- `src/engine/`
- `src/formats/`
- `cmd/`
- related scripts/docs that affect public capability claims

Method:

- literal scan for `TODO` / `FIXME` / placeholder-style markers
- direct inspection of public entrypoints and package registration
- validation against `moon check`, `moon test`, and the new smoke scripts

## P0 / P1 Findings

| Severity | Area | Evidence | Status | Notes |
| --- | --- | --- | --- | --- |
| P0 | MCP transport | `src/mcp/transport/stdio.mbt` previously returned `""` from `StdioTransport::read_line()` | Resolved | Replaced with real STDIO line reading via `moonbitlang/async/stdio`, trims CRLF/BOM, exits cleanly on EOF. |
| P0 | MCP package exposure | `cmd/mcp-server/` previously had `main.mbt` but no `moon.pkg`, so `moon run cmd/mcp-server` failed | Resolved | Added `cmd/mcp-server/moon.pkg`; the entrypoint is now a real package and is exercised by `tests/integration/mcp_stdio_smoke.ps1`. |
| P0 | CLI failure signaling | CLI parse/runtime failures previously printed messages but still returned success, and output could overwrite input | Resolved | CLI now fails fast on invalid argument paths and rejects input/output path conflicts. |
| P1 | MCP legacy test scripts | `scripts/test_mcp_server.ps1` and `scripts/test_mcp_server.sh` still describe manual expectations and stale version strings | Mitigated | Repository now uses `tests/integration/mcp_stdio_smoke.ps1` as the authoritative automated smoke check. Legacy scripts should be treated as historical/manual references only. |
| P1 | MCP logger utility | `src/mcp/util/logger.mbt` still uses a fixed timestamp and would write to stdout if called directly | Mitigated | The live STDIO server path no longer retains or uses a logger, and the MCP contract docs now make stdout discipline explicit. The utility itself should still be treated as non-protocol-safe helper code until redesigned. |
| P1 | Native compiler assumption | `moonpkg.json` pins Windows native compilation to `cl.exe` | Documented | Kept intentionally; documented in `docs/architecture/external_dependencies.md` and mirrored in CI/build scripts. |
| P1 | OCR/PDF bridge boundary | OCR and PDF fallback rely on Python bridge scripts, not pure MoonBit runtime only | Documented | Boundaries are now documented consistently in README/AGENTS/OCR docs/external dependency notes. |
| P1 | External baseline comparison | `markitdown` / `docling` were unavailable in the latest local eval report | Mitigated | Added explicit documentation and an optional manual CI job path for baseline comparison. |

## Result

The highest-risk placeholder path in first phase was MCP: a public entrypoint existed, but transport/package wiring did not. That gap is now closed and backed by an integration smoke script.

Remaining P1 items are documentation or engineering-boundary issues, not hidden fake implementations. They stay visible in docs instead of being presented as fully closed capabilities, and the MCP logger item is now explicitly downgraded from a live protocol risk to an isolated utility-design debt.
