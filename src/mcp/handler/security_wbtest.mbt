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
  let old_upload = @env.get_env_var("MOONBITMARK_MCP_MAX_UPLOAD_BYTES")
  @env.unset_env_var("MOONBITMARK_MCP_ALLOWED_ROOTS")
  @env.unset_env_var("MOONBITMARK_MCP_ALLOW_HTTP")
  @env.unset_env_var("MOONBITMARK_MCP_ENABLE_OCR")
  @env.unset_env_var("MOONBITMARK_MCP_MAX_OUTPUT_CHARS")
  @env.unset_env_var("MOONBITMARK_MCP_MAX_UPLOAD_BYTES")

  let config = load_mcp_security_config()
  restore_env_var("MOONBITMARK_MCP_ALLOWED_ROOTS", old_roots)
  restore_env_var("MOONBITMARK_MCP_ALLOW_HTTP", old_http)
  restore_env_var("MOONBITMARK_MCP_ENABLE_OCR", old_ocr)
  restore_env_var("MOONBITMARK_MCP_MAX_OUTPUT_CHARS", old_max)
  restore_env_var("MOONBITMARK_MCP_MAX_UPLOAD_BYTES", old_upload)

  match config {
    Ok(value) => {
      inspect(value.allow_http, content="false")
      inspect(value.enable_ocr, content="false")
      inspect(value.max_output_chars == None, content="true")
      inspect(value.max_upload_bytes, content="10485760")
      // unset 时默认 root 为 cwd，同包其它用例依赖这一点。
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
  let old_upload = @env.get_env_var("MOONBITMARK_MCP_MAX_UPLOAD_BYTES")
  // 这里必须把 cwd 一起纳入 roots：同包的 tools_wbtest 有两条
  // compare_with_baseline 用例要走 load_mcp_security_config() 读进程环境，
  // 而本用例在窗口期把 roots 改成了 docs;tests，会让 _build/test-tmp 下的
  // 临时文件越界、偶发失败。加 "." 后竞态窗口命中也不影响它们。
  // 断言 allowed_roots 顺带覆盖了 "." 被归一化成 cwd 这一行为。
  @env.set_env_var("MOONBITMARK_MCP_ALLOWED_ROOTS", ".;docs;tests")
  @env.set_env_var("MOONBITMARK_MCP_ALLOW_HTTP", "true")
  @env.set_env_var("MOONBITMARK_MCP_ENABLE_OCR", "1")
  @env.set_env_var("MOONBITMARK_MCP_MAX_OUTPUT_CHARS", "120")
  @env.set_env_var("MOONBITMARK_MCP_MAX_UPLOAD_BYTES", "512")

  let config = load_mcp_security_config()
  restore_env_var("MOONBITMARK_MCP_ALLOWED_ROOTS", old_roots)
  restore_env_var("MOONBITMARK_MCP_ALLOW_HTTP", old_http)
  restore_env_var("MOONBITMARK_MCP_ENABLE_OCR", old_ocr)
  restore_env_var("MOONBITMARK_MCP_MAX_OUTPUT_CHARS", old_max)
  restore_env_var("MOONBITMARK_MCP_MAX_UPLOAD_BYTES", old_upload)

  match config {
    Ok(value) => {
      inspect(value.allow_http, content="true")
      inspect(value.enable_ocr, content="true")
      debug_inspect(value.max_output_chars, content="Some(120)")
      inspect(value.max_upload_bytes, content="512")
      inspect(value.allowed_roots.length(), content="3")
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
    allow_private_http: false,
    enable_ocr: false,
    max_output_chars: None,
    max_upload_bytes: 10485760,
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
    allow_private_http: false,
    enable_ocr: false,
    max_output_chars: Some(80),
    max_upload_bytes: 10485760,
  }
  debug_inspect(clamp_mcp_output_chars(Some(4000), config), content="Some(80)")
}

///|
fn boundary_config(allow_http : Bool, allow_private_http : Bool) -> McpSecurityConfig {
  McpSecurityConfig::{
    allowed_roots: [resolve_file_path(".")],
    allow_http,
    allow_private_http,
    enable_ocr: false,
    max_output_chars: None,
    max_upload_bytes: 10485760,
  }
}

///|
test "canonicalize strips win32 trailing dots and spaces per segment" {
  // Win32 打开文件时会剥掉每段末尾的点和空格，词法层不同步剥就会放行越界路径。
  inspect(canonicalize_path("C:/allowed/.. /Windows/x"), content="C:/Windows/x")
  inspect(canonicalize_path("C:/allowed/.. ./Windows"), content="C:/Windows")
  inspect(canonicalize_path("C:/allowed/..  /x"), content="C:/x")
  inspect(canonicalize_path("C:/allowed/sub/. /x"), content="C:/allowed/sub/x")
  inspect(canonicalize_path("C:/allowed/a.../b"), content="C:/allowed/a/b")
  // 既有 `..` / `.` 语义不能破坏
  inspect(canonicalize_path("C:/allowed/sub/../x"), content="C:/allowed/x")
  inspect(canonicalize_path("C:/allowed/./x"), content="C:/allowed/x")
  inspect(canonicalize_path("C:/allowed/sub/"), content="C:/allowed/sub")
}

///|
test "security boundary blocks private http targets by default" {
  let config = boundary_config(true, false)
  let blocked = [
    "http://127.0.0.1/x",
    "http://localhost/x",
    "http://127.0.0.1:8080/x",
    "http://169.254.169.254/latest/meta-data/iam/security-credentials/",
    "http://10.1.2.3/x",
    "http://192.168.0.1/x",
    "http://172.20.0.1/x",
    "http://100.64.0.1/x",
    "http://[::1]:8080/x",
    "http://example.com@127.0.0.1/x",
    "http://2130706433/x",
    "http://127.1/x",
    "http://nas.local/x",
    "http://metadata.google.internal/x",
    // FQDN 根点（尾随 '.'）：与不带点的同一个目标等义，必须同样拦下，
    // 否则整层私网判定可被一个点绕过。
    "http://127.0.0.1./x",
    "http://localhost./x",
    "http://169.254.169.254./x",
    "http://10.1.2.3./x",
    "http://127.0.0.1.:8080/x",
    "http://metadata.google.internal./x",
    // 剥掉根点后为空：真实目标完全不可判定，按私有处理（fail closed）。
    "http://./x",
    // 尾随空格同一类：畸形 authority 若被下游容错就会绕过末段纯数字判定。
    "http://127.0.0.1 /x",
    "http://localhost /x",
    // 字符集白名单：含 '%' 编码、控制字符、非 ASCII 的主机名一律拒绝，
    // 且不依赖"下游客户端到底解不解码"——解码之前就已经被挡在分类逻辑之外。
    "http://127%2e0%2e0%2e1/x",
    "http://127.0.0.1%00/x",
    "http://例子.测试/x",
    "http://127.0.0.1\u{3002}x",
  ]
  for url in blocked {
    match enforce_mcp_input_boundary(url, config) {
      Ok(value) => fail("expected private http target to be blocked: " + url + " -> " + value)
      Err(message) =>
        inspect(
          message.contains("MOONBITMARK_MCP_ALLOW_PRIVATE_HTTP"), content="true",
        )
    }
  }
  let allowed = [
    "http://8.8.8.8/x",
    "https://example.com/demo.html",
    "http://172.32.0.1/x",
    // 根点剥离必须只剥点、不能因此变成「带点就拦」：公网目标带根点仍要放行。
    "http://8.8.8.8./x",
  ]
  for url in allowed {
    match enforce_mcp_input_boundary(url, config) {
      Ok(_) => ()
      Err(message) =>
        fail("expected public http target to pass: " + url + " -> " + message)
    }
  }
}

///|
test "private http allowance is opt-in" {
  let config = boundary_config(true, true)
  match enforce_mcp_input_boundary("http://127.0.0.1:8080/health", config) {
    Ok(value) => inspect(value, content="http://127.0.0.1:8080/health")
    Err(message) => fail("expected private http to pass when enabled: " + message)
  }
}

///|
test "http switch keeps its own error message" {
  let config = boundary_config(false, false)
  match enforce_mcp_input_boundary("http://127.0.0.1/x", config) {
    Ok(_) => fail("expected http to be disabled")
    Err(message) => {
      inspect(message.contains("MOONBITMARK_MCP_ALLOW_HTTP"), content="true")
      inspect(message.contains("MOONBITMARK_MCP_ALLOW_PRIVATE_HTTP"), content="false")
    }
  }
}

///|
async test "verify_mcp_real_path tolerates missing leaves and skips http" {
  let config = boundary_config(false, false)
  match verify_mcp_real_path("https://example.com/x", config) {
    Ok(_) => ()
    Err(message) => fail("expected http input to skip the real path check: " + message)
  }
  // 已存在的仓内文件必须通过
  match verify_mcp_real_path("src/mcp/handler/security.mbt", config) {
    Ok(_) => ()
    Err(message) => fail("expected in-repo file to pass: " + message)
  }
  // 尚不存在的叶子文件：退化为「父目录 realpath + 末段」，不得因为 realpath
  // 抛错就整体失败（输出路径属于这种形态）。
  let missing = "_build/mcp-realpath-missing-" + @async.now().to_string() + ".md"
  match verify_mcp_real_path(missing, config) {
    Ok(_) => ()
    Err(message) => fail("expected missing leaf to be tolerated: " + message)
  }
}

///|
async test "verify_mcp_real_path rejects a junction that escapes the roots" {
  let config = boundary_config(false, false)
  let stamp = @async.now().to_string()
  let link = "_build/mbm-escape-" + stamp
  let target = if @fs.exists("C:/Windows") { "C:/Windows" } else { "/" }
  @fs.symlink(target=target, link, force_symlink=false) catch { _ => () }
  let created = @fs.exists(link)
  // Windows 上建 junction 需要目录目标且同卷 NTFS，通常无需管理员权限；
  // 实测本机 `created == true`，越界断言确实执行过。这里保留容错分支是为了
  // 不在缺少权限的机器上把环境问题变成红测试。
  if created {
    let probe = link + "/mbm-probe-" + stamp + "/x.md"
    match verify_mcp_real_path(probe, config) {
      Ok(_) => fail("expected junction escape to be rejected: " + probe)
      Err(message) =>
        inspect(message.contains("after symlink resolution"), content="true")
    }
    @fs.rmdir(link) catch { _ => () }
  }
  inspect(true, content="true")
}

///|
/// Windows 专属硬断言版本：本机实测 `@fs.symlink(target=<已存在目录>)` 会建出
/// NTFS junction 且不需要管理员权限，所以这条用例要求「链接必须建成 + 越界必须被拒」。
/// 非 Windows 平台在 Linux 上走通用容错版本（见上一条 async test）。
#cfg(platform="windows")
async test "verify_mcp_real_path rejects a junction that escapes the roots (strict)" {
  let config = boundary_config(false, false)
  let stamp = @async.now().to_string()
  let link = "_build/mbm-escape-strict-" + stamp
  let target = if @fs.exists("C:/Windows") { "C:/Windows" } else { "/" }
  @fs.symlink(target=target, link, force_symlink=false) catch { _ => () }
  let created = @fs.exists(link)
  inspect(created, content="true")
  let probe = link + "/mbm-probe-" + stamp + "/x.md"
  match verify_mcp_real_path(probe, config) {
    Ok(_) => fail("expected junction escape to be rejected: " + probe)
    Err(message) =>
      inspect(message.contains("after symlink resolution"), content="true")
  }
  @fs.rmdir(link) catch { _ => () }
}
