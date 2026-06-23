// MoonBitMark MCP Handler - Static Resources

///|
pub(all) struct ResourceDefinition {
  resource : @types.McpResource
  text : String
}

///|
pub(all) struct ResourceRegistry {
  resources : Array[ResourceDefinition]
  resource_templates : Array[@types.McpResourceTemplate]
}

///|
pub fn ResourceRegistry::new() -> ResourceRegistry {
  ResourceRegistry::{ resources: [], resource_templates: [] }
}

///|
pub fn ResourceRegistry::register(
  self : ResourceRegistry,
  resource : ResourceDefinition,
) -> ResourceRegistry raise {
  for existing in self.resources {
    if existing.resource.uri == resource.resource.uri {
      fail("Resource already registered: " + resource.resource.uri)
    }
  }

  let resources = self.resources
  resources.push(resource)
  ResourceRegistry::{ resources, resource_templates: self.resource_templates }
}

///|
pub fn ResourceRegistry::register_template(
  self : ResourceRegistry,
  template : @types.McpResourceTemplate,
) -> ResourceRegistry raise {
  for existing in self.resource_templates {
    if existing.uri_template == template.uri_template {
      fail("Resource template already registered: " + template.uri_template)
    }
  }

  let templates = self.resource_templates
  templates.push(template)
  ResourceRegistry::{ resources: self.resources, resource_templates: templates }
}

///|
pub fn ResourceRegistry::list(
  self : ResourceRegistry,
) -> Array[@types.McpResource] {
  let items : Array[@types.McpResource] = []
  for resource in self.resources {
    items.push(resource.resource)
  }
  items
}

///|
pub fn ResourceRegistry::list_templates(
  self : ResourceRegistry,
) -> Array[@types.McpResourceTemplate] {
  self.resource_templates
}

///|
pub async fn ResourceRegistry::read(
  self : ResourceRegistry,
  uri : String,
) -> Result[@types.McpResourceContents, String] {
  if uri.has_prefix("moonbitmark://document/") {
    return read_document_resource_contents(uri)
  }
  for resource in self.resources {
    if resource.resource.uri == uri {
      return Ok(@types.McpResourceContents::{
        uri,
        mime_type: resource.resource.mime_type,
        text: resource.text,
      })
    }
  }

  Err("Resource not found")
}

///|
pub fn ResourceRegistry::register_static_resources(
  self : ResourceRegistry,
) -> ResourceRegistry raise {
  self
  .register(
    static_text_resource(
      "moonbitmark://capabilities",
      "capabilities",
      "MoonBitMark MCP capabilities",
      "Current MCP capability surface and non-goals.",
      capabilities_resource_text(),
    ),
  )
  .register(
    static_text_resource(
      "moonbitmark://supported-formats",
      "supported-formats",
      "Supported conversion formats",
      "Formats supported by MoonBitMark and preview guidance.",
      supported_formats_resource_text(),
    ),
  )
  .register(
    static_text_resource(
      "moonbitmark://known-issues",
      "known-issues",
      "Known issues",
      "Current known issues that still affect usage or development.",
      known_issues_resource_text(),
    ),
  )
  .register(
    static_text_resource(
      "moonbitmark://ocr-boundaries",
      "ocr-boundaries",
      "OCR and bridge boundaries",
      "What OCR does, when bridges are involved, and current limits.",
      ocr_boundaries_resource_text(),
    ),
  )
  .register(
    static_text_resource(
      "moonbitmark://mcp-usage",
      "mcp-usage",
      "MCP usage guide",
      "Recommended launcher path, request flow, and validation commands.",
      mcp_usage_resource_text(),
    ),
  )
  .register(
    static_text_resource(
      "moonbitmark://server-info",
      "server-info",
      "Server runtime info",
      "Current security configuration and runtime limits.",
      server_info_resource_text(),
    ),
  )
  .register_template(@types.McpResourceTemplate::{
    uri_template: "moonbitmark://document/{id}",
    name: "stored-document",
    title: Some("Stored uploaded document"),
    description: Some(
      "Dynamic resource for an uploaded document stored via upload_document. Use with inspect_document or convert_to_markdown.",
    ),
    mime_type: Some("text/markdown"),
  })
}

///|
fn static_text_resource(
  uri : String,
  name : String,
  title : String,
  description : String,
  text : String,
) -> ResourceDefinition {
  ResourceDefinition::{
    resource: @types.McpResource::{
      uri,
      name,
      title: Some(title),
      description: Some(description),
      mime_type: Some("text/markdown"),
      size: Some(text.length()),
    },
    text,
  }
}

///|
fn capabilities_resource_text() -> String {
  [
    "# MoonBitMark MCP capabilities", "", "- Transports: local STDIO and loopback-first HTTP POST /mcp.",
    "- Verified methods: initialize, ping, tools/list, tools/call, resources/list, resources/read, prompts/list, prompts/get.",
    "- Prompts: convert-document, diagnose-conversion-failure, batch-convert.", "- Tools: inspect_document, convert_to_markdown, upload_document, convert_uploaded_document, list_documents, delete_document.",
    "- Tool annotations: each tool exposes readOnlyHint, destructiveHint, idempotentHint, and openWorldHint.",
    "- Structured mode: inspect_document, convert_to_markdown, upload_document, convert_uploaded_document, list_documents, and delete_document all accept response_mode=text|json; conversion json responses expose structuredContent with content, metadata, diagnostics, and stats.",
    "- Remote-ready input: upload_document stores bytes as moonbitmark://document/<id>, inspect_document and convert_to_markdown accept resource_uri, and convert_uploaded_document remains the one-shot bytes convenience path.",
    "- Document management: list_documents enumerates stored resources; delete_document removes a stored resource by URI.",
    "- Resource set: capabilities, supported-formats, known-issues, ocr-boundaries, mcp-usage, server-info, plus dynamic moonbitmark://document/<id> resources created by upload_document.",
    "- Resource templates: moonbitmark://document/{id} is exposed as a resource template in resources/list.",
    "- Logging: server may emit notifications/message JSON-RPC notifications for structured logging instead of writing to stdout.",
    "- Conversion default: convert_to_markdown uses preview mode unless mode=full is requested.",
    "- Runtime gates: file access is limited by MOONBITMARK_MCP_ALLOWED_ROOTS, HTTP is disabled unless MOONBITMARK_MCP_ALLOW_HTTP is enabled, OCR is disabled unless MOONBITMARK_MCP_ENABLE_OCR is enabled, uploads are capped by MOONBITMARK_MCP_MAX_UPLOAD_BYTES, and returned Markdown can be clamped by MOONBITMARK_MCP_MAX_OUTPUT_CHARS.",
    "- Current non-goals: SSE transport, streaming responses, and long-running progress channels.",
  ].join("\n")
}

///|
fn supported_formats_resource_text() -> String {
  [
    "# Supported formats", "", "- Text: txt.", "- Structured text: csv, json.", "- Documents: docx, pptx, xlsx, epub.",
    "- Web: html, xhtml, url inputs.", "- PDFs: native extraction first, optional bridge-backed fallback for some recovery paths.",
    "- Images: conversion may require OCR when text extraction is needed.", "", "Preview is recommended first for pdf, docx, pptx, xlsx, epub, html, image, url, or any large input.",
  ].join("\n")
}

///|
fn known_issues_resource_text() -> String {
  [
    "# Known issues", "", "- PDF OCR is still a bridge-backed recovery path, not a full layout understanding system.",
    "- Windows native build has a historical C4819 warning debt that is currently not reproduced locally but remains tracked.",
    "", "Read docs/KNOWN_ISSUES.md for the current authoritative wording.",
  ].join("\n")
}

///|
fn ocr_boundaries_resource_text() -> String {
  [
    "# OCR and bridge boundaries", "", "- OCR is optional, not guaranteed.", "- OCR requires python scripts/ocr/bridge.py and an available backend.",
    "- mock is the stable automated test backend.", "- tesseract depends on a system executable on PATH.",
    "- auto means use an available backend if one exists; it does not guarantee OCR.",
    "- In the MCP server, OCR stays disabled unless MOONBITMARK_MCP_ENABLE_OCR is set to 1 or true.",
    "- PDF fallback extraction and PDF OCR recovery may use Python bridge scripts.",
    "- Current limits: no bbox/layout OCR protocol, no remote-image OCR for HTML, no full document layout understanding.",
  ].join("\n")
}

///|
fn mcp_usage_resource_text() -> String {
  [
    "# MCP usage", "", "Recommended Windows STDIO launcher:", "", "- cmd /d /c scripts/mcp/moonbitmark-mcp.cmd",
    "- powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/mcp/moonbitmark-mcp.ps1",
    "", "Loopback-first HTTP server:", "", "- moon run --target native --release -q cmd/mcp-http-server -- --host 127.0.0.1 --port 8765",
    "- POST http://127.0.0.1:8765/mcp", "- GET http://127.0.0.1:8765/healthz", "",
    "Runtime boundary environment variables:", "", "- MOONBITMARK_MCP_ALLOWED_ROOTS: semicolon-separated allowed file roots. Default: current working directory only.",
    "- MOONBITMARK_MCP_ALLOW_HTTP: 1/true to allow http:// and https:// inputs. Default: disabled.",
    "- MOONBITMARK_MCP_ENABLE_OCR: 1/true to allow MCP to opt into OCR auto mode. Default: disabled.",
    "- MOONBITMARK_MCP_MAX_OUTPUT_CHARS: optional positive integer cap applied to returned Markdown.",
    "- MOONBITMARK_MCP_MAX_UPLOAD_BYTES: optional positive integer cap for upload_document and convert_uploaded_document payload size. Default: 10485760 (10 MiB).",
    "- MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL: 1/true to allow binding 0.0.0.0. Default: loopback-only binding.",
    "", "Recommended agent flow:", "", "1. Call prompts/list if you want a guided conversion or diagnosis template.",
    "2. Call resources/list when you need capability or boundary context.", "3. Call inspect_document before converting unknown or large inputs.",
    "4. If the client only has bytes and wants a reusable handle, call upload_document first and keep the returned resource_uri.",
    "5. Call inspect_document or convert_to_markdown with uri or resource_uri.",
    "6. Use convert_uploaded_document only when you want one-shot upload + convert in a single call.",
    "7. Add response_mode=json when you need structuredContent for agent/program consumption.",
    "8. Re-run convert_to_markdown with mode=full only when you need the full Markdown.",
    "", "Client registration examples:", "", "- Claude Code: claude mcp add --transport http moonbitmark-http http://127.0.0.1:8765/mcp",
    "- Codex: codex mcp add moonbitmark-http --url http://127.0.0.1:8765/mcp", "",
    "Validation commands:", "", "- powershell -ExecutionPolicy Bypass -File tests/integration/mcp_stdio_smoke.ps1",
    "- powershell -ExecutionPolicy Bypass -File tests/integration/mcp_resources_smoke.ps1",
    "- powershell -ExecutionPolicy Bypass -File tests/integration/mcp_prompts_smoke.ps1",
    "- powershell -ExecutionPolicy Bypass -File tests/integration/mcp_security_smoke.ps1",
    "- powershell -ExecutionPolicy Bypass -File tests/integration/mcp_http_smoke.ps1",
    "- powershell -ExecutionPolicy Bypass -File tests/integration/mcp_http_security_smoke.ps1",
  ].join("\n")
}

///|
fn server_info_resource_text() -> String {
  match load_mcp_security_config() {
    Ok(config) =>
      [
        "# Server runtime info",
        "",
        "- allowed_roots: " + config.allowed_roots.join(";"),
        "- allow_http: " + config.allow_http.to_string(),
        "- enable_ocr: " + config.enable_ocr.to_string(),
        "- max_output_chars: " + optional_int_string(config.max_output_chars),
        "- max_upload_bytes: " + config.max_upload_bytes.to_string(),
        "- server_version: 0.3.0",
        "- protocol_version: 2024-11-05",
        "",
        "Environment variables:",
        "",
        "- MOONBITMARK_MCP_ALLOWED_ROOTS: semicolon-separated allowed file roots.",
        "- MOONBITMARK_MCP_ALLOW_HTTP: 1/true to allow HTTP inputs.",
        "- MOONBITMARK_MCP_ENABLE_OCR: 1/true to enable OCR auto mode.",
        "- MOONBITMARK_MCP_MAX_OUTPUT_CHARS: optional positive integer cap on returned Markdown.",
        "- MOONBITMARK_MCP_MAX_UPLOAD_BYTES: optional positive integer cap for uploads. Default: 10485760.",
        "- MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL: 1/true to allow binding 0.0.0.0.",
      ].join("\n")
    Err(_) =>
      "# Server info\n\nServer configuration could not be loaded. Check environment variables.\n"
  }
}
