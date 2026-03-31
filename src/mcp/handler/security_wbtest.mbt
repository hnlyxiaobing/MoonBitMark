///|
fn restore_env_var(name : String, old_value : String?) -> Unit {
  match old_value {
    Some(value) => @env.set_env_var(name, value)
    None => @env.unset_env_var(name)
  }
}

///|
test "security config defaults deny http and ocr" {
  let old_roots = @env.get_env_var("MOONBITMARK_MCP_ALLOWED_ROOTS")
  let old_http = @env.get_env_var("MOONBITMARK_MCP_ALLOW_HTTP")
  let old_ocr = @env.get_env_var("MOONBITMARK_MCP_ENABLE_OCR")
  let old_max = @env.get_env_var("MOONBITMARK_MCP_MAX_OUTPUT_CHARS")
  @env.unset_env_var("MOONBITMARK_MCP_ALLOWED_ROOTS")
  @env.unset_env_var("MOONBITMARK_MCP_ALLOW_HTTP")
  @env.unset_env_var("MOONBITMARK_MCP_ENABLE_OCR")
  @env.unset_env_var("MOONBITMARK_MCP_MAX_OUTPUT_CHARS")

  let config = load_mcp_security_config()
  restore_env_var("MOONBITMARK_MCP_ALLOWED_ROOTS", old_roots)
  restore_env_var("MOONBITMARK_MCP_ALLOW_HTTP", old_http)
  restore_env_var("MOONBITMARK_MCP_ENABLE_OCR", old_ocr)
  restore_env_var("MOONBITMARK_MCP_MAX_OUTPUT_CHARS", old_max)

  match config {
    Ok(value) => {
      inspect(value.allow_http, content="false")
      inspect(value.enable_ocr, content="false")
      inspect(value.max_output_chars == None, content="true")
      assert_true(value.allowed_roots.length() == 1)
    }
    Err(message) => fail("unexpected config error: " + message)
  }
}

///|
test "security config parses env overrides and enables ocr auto context" {
  let old_roots = @env.get_env_var("MOONBITMARK_MCP_ALLOWED_ROOTS")
  let old_http = @env.get_env_var("MOONBITMARK_MCP_ALLOW_HTTP")
  let old_ocr = @env.get_env_var("MOONBITMARK_MCP_ENABLE_OCR")
  let old_max = @env.get_env_var("MOONBITMARK_MCP_MAX_OUTPUT_CHARS")
  @env.set_env_var("MOONBITMARK_MCP_ALLOWED_ROOTS", "docs;tests")
  @env.set_env_var("MOONBITMARK_MCP_ALLOW_HTTP", "true")
  @env.set_env_var("MOONBITMARK_MCP_ENABLE_OCR", "1")
  @env.set_env_var("MOONBITMARK_MCP_MAX_OUTPUT_CHARS", "120")

  let config = load_mcp_security_config()
  restore_env_var("MOONBITMARK_MCP_ALLOWED_ROOTS", old_roots)
  restore_env_var("MOONBITMARK_MCP_ALLOW_HTTP", old_http)
  restore_env_var("MOONBITMARK_MCP_ENABLE_OCR", old_ocr)
  restore_env_var("MOONBITMARK_MCP_MAX_OUTPUT_CHARS", old_max)

  match config {
    Ok(value) => {
      inspect(value.allow_http, content="true")
      inspect(value.enable_ocr, content="true")
      inspect(value.max_output_chars, content="Some(120)")
      inspect(value.allowed_roots.length(), content="2")
      let ctx = build_mcp_convert_context(value)
      inspect(ctx.ocr.mode, content="Auto")
      inspect(ctx.ocr.enable_embedded_images, content="true")
    }
    Err(message) => fail("unexpected config error: " + message)
  }
}

///|
test "security boundary blocks http when disabled" {
  let config = McpSecurityConfig::{
    allowed_roots: [resolve_file_path(".")],
    allow_http: false,
    enable_ocr: false,
    max_output_chars: None,
  }
  let result = enforce_mcp_input_boundary(
    "https://example.com/demo.html", config,
  )
  match result {
    Ok(_) => fail("expected http boundary to reject URL input")
    Err(message) =>
      inspect(message.contains("MOONBITMARK_MCP_ALLOW_HTTP"), content="true")
  }
}

///|
test "security boundary clamps output chars to env limit" {
  let config = McpSecurityConfig::{
    allowed_roots: [resolve_file_path(".")],
    allow_http: false,
    enable_ocr: false,
    max_output_chars: Some(80),
  }
  inspect(clamp_mcp_output_chars(Some(4000), config), content="Some(80)")
}
