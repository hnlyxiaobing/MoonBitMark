// MoonBitMark MCP Handler - Static Prompts

///|
pub(all) struct PromptDefinition {
  prompt : @types.McpPrompt
}

///|
pub(all) struct PromptRegistry {
  prompts : Array[PromptDefinition]
}

///|
pub fn PromptRegistry::new() -> PromptRegistry {
  PromptRegistry::{ prompts: [] }
}

///|
pub fn PromptRegistry::register(
  self : PromptRegistry,
  prompt : PromptDefinition,
) -> PromptRegistry raise {
  for existing in self.prompts {
    if existing.prompt.name == prompt.prompt.name {
      fail("Prompt already registered: " + prompt.prompt.name)
    }
  }

  let prompts = self.prompts
  prompts.push(prompt)
  PromptRegistry::{ prompts, }
}

///|
pub fn PromptRegistry::list(self : PromptRegistry) -> Array[@types.McpPrompt] {
  let items : Array[@types.McpPrompt] = []
  for prompt in self.prompts {
    items.push(prompt.prompt)
  }
  items
}

///|
pub fn PromptRegistry::get(
  self : PromptRegistry,
  name : String,
  arguments : @types.JsonValue,
) -> Result[@types.McpGetPromptResult, String] {
  ignore(self)
  match name {
    "convert-document" => convert_document_prompt(arguments)
    "diagnose-conversion-failure" =>
      diagnose_conversion_failure_prompt(arguments)
    "batch-convert" => batch_convert_prompt(arguments)
    _ => Err("Prompt not found")
  }
}

///|
pub fn PromptRegistry::register_static_prompts(
  self : PromptRegistry,
) -> PromptRegistry raise {
  self
  .register(PromptDefinition::{
    prompt: @types.McpPrompt::{
      name: "convert-document",
      title: None,
      description: Some(
        "Convert a document through inspect_document and preview-first convert_to_markdown, starting from uri or resource_uri.",
      ),
      arguments: Some([
        prompt_argument("uri", "File path or URL to convert.", false),
        prompt_argument(
          "resource_uri", "Reusable uploaded document handle such as moonbitmark://document/<id>.",
          false,
        ),
        prompt_argument(
          "mode", "Optional target mode: preview or full. Default is preview.", false,
        ),
        prompt_argument(
          "max_chars", "Optional character cap for convert_to_markdown.", false,
        ),
        prompt_argument(
          "format_hint", "Optional advisory format hint such as pdf, docx, html, or text.",
          false,
        ),
      ]),
    },
  })
  .register(PromptDefinition::{
    prompt: @types.McpPrompt::{
      name: "diagnose-conversion-failure",
      title: None,
      description: Some(
        "Investigate a failed or suspicious conversion using MoonBitMark boundaries, known issues, and preview-first retry steps.",
      ),
      arguments: Some([
        prompt_argument("uri", "File path or URL that failed to convert.", true),
        prompt_argument(
          "failure_summary", "Observed failure message, symptom, or unexpected result.",
          true,
        ),
        prompt_argument(
          "last_mode", "Optional last convert_to_markdown mode such as preview or full.",
          false,
        ),
      ]),
    },
  })
  .register(PromptDefinition::{
    prompt: @types.McpPrompt::{
      name: "batch-convert",
      title: None,
      description: Some(
        "Convert multiple documents in batch: inspect each, convert with preview-first, and collect results.",
      ),
      arguments: Some([
        prompt_argument(
          "uris", "Comma-separated list of file paths or URLs to convert.", true,
        ),
        prompt_argument(
          "mode", "Target mode for all conversions: preview or full. Default is preview.",
          false,
        ),
        prompt_argument(
          "format_hint", "Optional advisory format hint applied to all inputs.",
          false,
        ),
        prompt_argument(
          "max_chars", "Optional character cap applied to each conversion.", false,
        ),
      ]),
    },
  })
}

///|
fn convert_document_prompt(
  arguments : @types.JsonValue,
) -> Result[@types.McpGetPromptResult, String] {
  let uri = optional_prompt_string(arguments, "uri")
  let resource_uri = optional_prompt_string(arguments, "resource_uri")
  let target_label = match (uri, resource_uri) {
    (Some(value), None) => "Target URI: " + value
    (None, Some(value)) => "Target resource_uri: " + value
    (Some(_), Some(_)) =>
      return Err("Provide exactly one of uri or resource_uri.")
    (None, None) =>
      return Err("Missing required prompt argument: one of uri or resource_uri")
  }
  let mode = optional_prompt_string(arguments, "mode")
  let max_chars = optional_prompt_string(arguments, "max_chars")
  let format_hint = optional_prompt_string(arguments, "format_hint")
  let effective_mode = match mode {
    Some(value) => value
    None => "preview"
  }

  Ok(@types.McpGetPromptResult::{
    description: Some(
      "Guide an agent through MoonBitMark's preview-first conversion flow.",
    ),
    messages: [
      prompt_message(
        "user",
        [
          "Convert this document with MoonBitMark.",
          "",
          target_label,
          "Requested mode: " + effective_mode,
          "Optional max_chars: " + optional_text(max_chars),
          "Optional format_hint: " + optional_text(format_hint),
          "",
          "Required flow:",
          "1. If you need server context, read moonbitmark://mcp-usage or moonbitmark://supported-formats.",
          "2. If you only have bytes, call upload_document first and keep the returned resource_uri.",
          "3. Call inspect_document with the uri or resource_uri.",
          "4. Call convert_to_markdown with mode=" +
          effective_mode +
          format_hint_segment(format_hint) +
          max_chars_segment(max_chars) +
          ".",
          "5. If mode is preview and the result looks worth expanding, re-run convert_to_markdown with mode=full.",
          "6. Use convert_uploaded_document only when you want a one-shot upload + convert path.",
          "7. Summarize detected format, truncation, warnings, diagnostics, and the returned Markdown.",
        ].join("\n"),
      ),
    ],
  })
}

///|
fn diagnose_conversion_failure_prompt(
  arguments : @types.JsonValue,
) -> Result[@types.McpGetPromptResult, String] {
  let uri = match required_prompt_string(arguments, "uri") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let failure_summary = match
    required_prompt_string(arguments, "failure_summary") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let last_mode = optional_prompt_string(arguments, "last_mode")

  Ok(@types.McpGetPromptResult::{
    description: Some(
      "Guide an agent through failure triage using MoonBitMark resources and preview-first retry steps.",
    ),
    messages: [
      prompt_message(
        "user",
        [
          "Diagnose a MoonBitMark conversion failure.",
          "",
          "Target URI: " + uri,
          "Observed failure: " + failure_summary,
          "Last mode: " + optional_text(last_mode),
          "",
          "Required flow:",
          "1. Read moonbitmark://known-issues and moonbitmark://ocr-boundaries before guessing.",
          "2. Call inspect_document with the URI.",
          "3. If the input is large or unknown, reproduce with convert_to_markdown in preview mode before using full mode.",
          "4. Check whether OCR, PDF bridge fallback, remote fetch behavior, or known format limits explain the failure.",
          "5. Return the likely root cause, the evidence from inspect/preview output, and the next safe action.",
        ].join("\n"),
      ),
    ],
  })
}

///|
fn prompt_argument(
  name : String,
  description : String,
  required : Bool,
) -> @types.McpPromptArgument {
  @types.McpPromptArgument::{
    name,
    description: Some(description),
    required: Some(required),
  }
}

///|
fn prompt_message(role : String, text : String) -> @types.McpPromptMessage {
  @types.McpPromptMessage::{
    role,
    content: @types.TextContent::{ type_: "text", text },
  }
}

///|
fn required_prompt_string(
  arguments : @types.JsonValue,
  key : String,
) -> Result[String, String] {
  match arguments.get(key) {
    Some(@types.String(value)) if value.trim() != "" => Ok(value)
    _ => Err("Missing required prompt argument: " + key)
  }
}

///|
fn optional_prompt_string(
  arguments : @types.JsonValue,
  key : String,
) -> String? {
  match arguments.get(key) {
    Some(@types.String(value)) if value.trim() != "" => Some(value)
    Some(@types.Number(value)) => Some(value.to_string())
    _ => None
  }
}

///|
fn optional_text(value : String?) -> String {
  match value {
    Some(text) => text
    None => "null"
  }
}

///|
fn format_hint_segment(format_hint : String?) -> String {
  match format_hint {
    Some(value) => ", format_hint=" + value
    None => ""
  }
}

///|
fn max_chars_segment(max_chars : String?) -> String {
  match max_chars {
    Some(value) => ", max_chars=" + value
    None => ""
  }
}

///|
fn batch_convert_prompt(
  arguments : @types.JsonValue,
) -> Result[@types.McpGetPromptResult, String] {
  let uris_text = match required_prompt_string(arguments, "uris") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let mode = optional_prompt_string(arguments, "mode")
  let format_hint = optional_prompt_string(arguments, "format_hint")
  let max_chars = optional_prompt_string(arguments, "max_chars")
  let effective_mode = match mode {
    Some(value) => value
    None => "preview"
  }
  let uris = split_and_trim_uris(uris_text)
  if uris.length() == 0 {
    return Err("No valid URIs found in the uris argument")
  }

  let uri_lines : Array[String] = []
  let mut index = 0
  while index < uris.length() {
    uri_lines.push("- [" + (index + 1).to_string() + "] " + uris[index])
    index = index + 1
  }

  let header_lines = [
    "Batch convert " +
    uris.length().to_string() +
    " document(s) with MoonBitMark.",
    "",
    "Inputs:",
  ]
  for line in uri_lines {
    header_lines.push(line)
  }
  header_lines.push("")
  header_lines.push("Mode: " + effective_mode)
  header_lines.push("Optional format_hint: " + optional_text(format_hint))
  header_lines.push("Optional max_chars: " + optional_text(max_chars))
  header_lines.push("")
  header_lines.push("Required flow:")
  header_lines.push(
    "1. For each URI, call inspect_document first to detect format and check preview recommendation.",
  )
  header_lines.push(
    "2. Call convert_to_markdown for each input with mode=" +
    effective_mode +
    format_hint_segment(format_hint) +
    max_chars_segment(max_chars) +
    ".",
  )
  header_lines.push(
    "3. If any input is large or unknown format, keep preview mode and only expand individually if needed.",
  )
  header_lines.push(
    "4. Collect and summarize: detected format, truncation status, warnings, and returned Markdown for each input.",
  )
  header_lines.push(
    "5. If any conversion fails, read moonbitmark://known-issues before retrying.",
  )

  Ok(@types.McpGetPromptResult::{
    description: Some(
      "Guide an agent through batch conversion of multiple documents with MoonBitMark.",
    ),
    messages: [prompt_message("user", header_lines.join("\n"))],
  })
}

///|
fn split_and_trim_uris(text : String) -> Array[String] {
  let result : Array[String] = []
  for part in text.split(",") {
    let trimmed = part.trim().to_owned()
    if trimmed != "" {
      result.push(trimmed)
    }
  }
  result
}
