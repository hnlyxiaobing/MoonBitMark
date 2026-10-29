// MoonBitMark MCP Handler - Runtime Security Boundaries

///|
pub(all) struct McpSecurityConfig {
  allowed_roots : Array[String]
  allow_http : Bool
  allow_private_http : Bool
  enable_ocr : Bool
  max_output_chars : Int32?
  max_upload_bytes : Int32
}

///|
pub fn load_mcp_security_config() -> Result[McpSecurityConfig, String] {
  let allowed_roots = match parse_allowed_roots_env() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let allow_http = match parse_bool_env("MOONBITMARK_MCP_ALLOW_HTTP", false) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let allow_private_http = match
    parse_bool_env("MOONBITMARK_MCP_ALLOW_PRIVATE_HTTP", false) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let enable_ocr = match parse_bool_env("MOONBITMARK_MCP_ENABLE_OCR", false) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let max_output_chars = match
    parse_positive_int_env("MOONBITMARK_MCP_MAX_OUTPUT_CHARS") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let max_upload_bytes = match
    parse_positive_int_env_with_default(
      "MOONBITMARK_MCP_MAX_UPLOAD_BYTES", 10485760,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }

  Ok(McpSecurityConfig::{
    allowed_roots,
    allow_http,
    allow_private_http,
    enable_ocr,
    max_output_chars,
    max_upload_bytes,
  })
}

///|
pub fn enforce_mcp_input_boundary(
  uri : String,
  config : McpSecurityConfig,
) -> Result[String, String] {
  let input = normalize_file_uri(uri)
  if is_http_input(input) {
    if !config.allow_http {
      Err(
        "HTTP input is disabled by MOONBITMARK_MCP_ALLOW_HTTP; set it to 1 or true to allow http:// and https:// URIs.",
      )
    } else if !config.allow_private_http {
      // SSRF 防护：Agent 被提示注入后可以让 MCP 去抓云元数据、内网面板、
      // 路由器管理页，抓回的内容会直接变成 markdown 回给 Agent。默认拒绝
      // 私网/回环目标，显式设置 MOONBITMARK_MCP_ALLOW_PRIVATE_HTTP=1 才放开。
      let host = http_url_host(input)
      if is_private_http_host(host) {
        Err(
          "HTTP input to a private/loopback address is blocked: host=" +
          host +
          " ; set MOONBITMARK_MCP_ALLOW_PRIVATE_HTTP=1 to allow private-network fetches.",
        )
      } else {
        Ok(input)
      }
    } else {
      Ok(input)
    }
  } else {
    let resolved = resolve_file_path(input)
    if path_within_allowed_roots(resolved, config.allowed_roots) {
      Ok(resolved)
    } else {
      Err(
        "File input is outside MOONBITMARK_MCP_ALLOWED_ROOTS: input=" +
        input +
        " resolved=" +
        resolved +
        " allowed_roots=[" +
        config.allowed_roots.join(";") +
        "] cwd=" +
        current_dir_or_dot(),
      )
    }
  }
}

///|
/// Second layer of the MCP file boundary: resolve the input through the real
/// filesystem so that symbolic links, NTFS junctions and short (8.3) names
/// cannot be used to step outside `MOONBITMARK_MCP_ALLOWED_ROOTS`.
///
/// The lexical layer in `enforce_mcp_input_boundary` cannot see any of those,
/// so this check is required for every file-shaped input. HTTP inputs are
/// returned as `Ok(())` because they are covered by the SSRF check instead.
///
/// A target that does not exist yet is not treated as a failure: the parent
/// directory is resolved instead and the final segment is appended, so that
/// output paths (which are created later) keep working.
pub async fn verify_mcp_real_path(
  path : String,
  config : McpSecurityConfig,
) -> Result[Unit, String] {
  if is_http_input(path) {
    return Ok(())
  }
  let real = resolve_real_path(path)
  let resolved_roots : Array[String] = []
  for root in config.allowed_roots {
    resolved_roots.push(canonicalize_path(@core.normalize_path(resolve_real_path(root))))
  }
  if path_within_allowed_roots(real, resolved_roots) {
    Ok(())
  } else {
    Err(
      "File input escapes MOONBITMARK_MCP_ALLOWED_ROOTS after symlink resolution: input=" +
      path +
      " real=" +
      real +
      " allowed_roots=[" +
      resolved_roots.join(";") +
      "]",
    )
  }
}

///|
/// Resolve `path` to its canonical real form, falling back to the parent
/// directory when the leaf does not exist yet.
async fn resolve_real_path(path : String) -> String {
  let direct = @fs.realpath(path) catch { _ => "" }
  if direct != "" {
    return canonicalize_path(@core.normalize_path(strip_windows_extended_prefix(direct)))
  }
  match split_parent_and_leaf(path) {
    Some((parent, leaf)) => {
      let real_parent = @fs.realpath(parent) catch { _ => "" }
      if real_parent != "" {
        let canonical_parent = canonicalize_path(
          @core.normalize_path(strip_windows_extended_prefix(real_parent)),
        )
        if canonical_parent == "" {
          canonicalize_path(@core.normalize_path(path))
        } else if canonical_parent == "/" {
          "/" + leaf
        } else {
          canonicalize_path(canonical_parent + "/" + leaf)
        }
      } else {
        canonicalize_path(@core.normalize_path(path))
      }
    }
    None => canonicalize_path(@core.normalize_path(path))
  }
}

///|
/// Split a normalized path into its parent directory and final segment.
/// Returns `None` when there is no usable parent (bare relative name, root).
fn split_parent_and_leaf(path : String) -> (String, String)? {
  let normalized = @core.normalize_path(path)
  let leaf = @core.file_name_only(normalized)
  if leaf == "" || leaf == normalized {
    return None
  }
  let parent = @core.path_dirname(normalized)
  if parent == "" {
    return None
  }
  Some((parent, leaf))
}

///|
/// `realpath` on Windows may return an extended-length path (`\\?\C:\...`),
/// which would never match a plain allowed root prefix. Strip the prefix so
/// both sides are compared in the same form.
fn strip_windows_extended_prefix(path : String) -> String {
  if path.has_prefix("//?/UNC/") {
    "//" + path[8:].to_owned()
  } else if path.has_prefix("//?/") {
    path[4:].to_owned()
  } else {
    path
  }
}

///|
/// Extract the host (authority without userinfo and port) of an http(s) URL.
/// Returns `""` for non-http(s) input, and also for an http(s) URL whose host
/// is empty after stripping the FQDN root dot (`http://./x`). Callers in the
/// http branch treat `""` as private, so both cases fail closed.
fn http_url_host(url : String) -> String {
  let lowered = url.to_lower()
  let rest = if lowered.has_prefix("https://") {
    lowered[8:].to_owned()
  } else if lowered.has_prefix("http://") {
    lowered[7:].to_owned()
  } else {
    return ""
  }
  let mut end = rest.length()
  for marker in ["/", "?", "#"] {
    match rest.find(marker) {
      Some(index) => if index < end { end = index }
      None => ()
    }
  }
  let authority = rest[:end].to_owned()
  // `http://example.com@127.0.0.1/` 这类 userinfo 伪装：取最后一个 '@' 之后。
  let host_part = match authority.rev_find("@") {
    Some(index) => authority[index + 1:].to_owned()
    None => authority
  }
  let mut host = host_part
  if host.has_prefix("[") {
    // IPv6 字面量：[::1]:80 / [::1]
    match host.find("]") {
      Some(index) => host = host[1:index].to_owned()
      None => host = host[1:].to_owned()
    }
  } else {
    match host.rev_find(":") {
      Some(index) => {
        let port = host[index + 1:].to_owned()
        if is_all_digits(port) {
          host = host[:index].to_owned()
        }
      }
      None => ()
    }
  }
  // FQDN 根点：`127.0.0.1.` 和 `127.0.0.1` 是同一个目标（解析器与内核都按同一
  // 地址处理），所以必须剥掉**全部**尾随 '.' 再交给分类函数。否则
  // `http://127.0.0.1./x` 会以「五段、且末段为空」的普通域名身份绕过私网判定，
  // `http://localhost./x` 也不再等于 `localhost`，同为绕过。
  // 顺序有要求：必须在上面剥端口之后做（`127.0.0.1.:8080` 先得 `127.0.0.1.`）。
  // 同时剥尾随空格：`http://127.0.0.1 /x` 这类畸形 authority 若被下游客户端
  // 容错处理，就会以「末段带空格、不是纯数字」的身份绕过判定。合法主机名不可能
  // 以空格结尾，所以这一剥只会让判定更严，不会误伤真实目标。
  trim_trailing_chars(host, ". ")
}

///|
/// Reject host spellings that cannot be classified statically.
///
/// Only `a-z`, `0-9`, `.`, `-`, `_`, `:` and the IPv6 brackets are allowed.
/// Anything else -- `%` escapes (`127%2e0%2e0%2e1`), blanks, control bytes,
/// non-ASCII (IDN labels, ideographic full stop, homoglyphs) -- is refused
/// **without decoding the host**, which is what makes this stronger than
/// normalising more characters one by one: the classifier never sees them.
fn is_plausible_http_host(host : String) -> Bool {
  if host == "" {
    return false
  }
  for ch in host {
    let allowed = (ch >= 'a' && ch <= 'z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '.' ||
      ch == '-' ||
      ch == '_' ||
      ch == ':' ||
      ch == '[' ||
      ch == ']'
    if !allowed {
      return false
    }
  }
  true
}

///|
/// Decide whether a URL host can only be reached on a private network.
/// Anything that cannot be classified statically is treated as private
/// (fail closed), because the whole point is to stop the fetch before it
/// happens.
fn is_private_http_host(host : String) -> Bool {
  if host == "" {
    // 空 host（`http://./x`、`http://.../x`，或剥掉根点后为空）真实目标完全
    // 不可判定，按私有处理。调用点只在输入已判定为 http(s) 时才走到这里，
    // 因此空值只可能来自畸形 authority，不会误伤文件路径输入。
    return true
  }
  if !is_plausible_http_host(host) {
    // 字符集白名单。含 `%`（百分号编码）、空白、控制字符、非 ASCII 的主机名
    // 一律按私有处理，且**不需要解码**：`127%2e0%2e0%2e1` 里的 `%` 不在白名单，
    // 就到不了后面的分类逻辑；全角点、同形字符同理。
    return true
  }
  if host == "localhost" || host.has_suffix(".localhost") {
    return true
  }
  for suffix in [".local", ".internal", ".lan", ".home.arpa"] {
    if host.has_suffix(suffix) {
      return true
    }
  }
  if host.contains(":") {
    return is_private_ipv6_host(host)
  }
  is_private_numeric_host(host)
}

///|
fn is_private_ipv6_host(host : String) -> Bool {
  if host == "::" || host == "::1" {
    return true
  }
  if host.has_prefix("::ffff:") {
    let mapped = host[7:].to_owned()
    if mapped.contains(".") {
      return is_private_numeric_host(mapped)
    }
    // `::ffff:7f00:1` 这类十六进制映射写法无法静态判定，按私有处理。
    return true
  }
  // 唯一本地区域 fc00::/7
  if host.has_prefix("fc") || host.has_prefix("fd") {
    return true
  }
  // 链路本地 fe80::/10，即第二字节落在 0x80..0xbf
  if host.length() >= 4 && host.has_prefix("fe") {
    match parse_hex_octet(host[2:4].to_owned()) {
      Some(value) => if value >= 0x80 && value <= 0xbf { return true }
      None => ()
    }
  }
  // `0:0:0:0:0:0:0:1` 这类展开形式的回环地址
  let groups = host.split(":").to_array()
  let non_empty : Array[String] = []
  for group in groups {
    let value = group.to_owned()
    if value != "" {
      non_empty.push(value)
    }
  }
  non_empty.length() == 1 && non_empty[0] == "1"
}

///|
fn is_private_numeric_host(host : String) -> Bool {
  if is_all_digits(host) {
    // 纯十进制整数（如 2130706433 == 127.0.0.1）：无法静态判定，按私有处理。
    return true
  }
  if host.has_prefix("0x") {
    let digits = host[2:].to_owned()
    if digits != "" && is_all_hex(digits) {
      return true
    }
  }
  let parts = host.split(".").to_array()
  let mut all_numeric = true
  for part in parts {
    if !is_all_digits(part.to_owned()) {
      all_numeric = false
    }
  }
  if !all_numeric {
    // 普通域名：DNS 解析到私网 IP 的场景本层拦不住（见 docs/mcp.md 残余风险）。
    return false
  }
  if parts.length() < 4 {
    // `127.1` / `10.1` 这类点分不足四段的写法，按私有处理。
    return true
  }
  match (
    parse_ipv4_octet(parts[0].to_owned()),
    parse_ipv4_octet(parts[1].to_owned()),
    parse_ipv4_octet(parts[2].to_owned()),
  ) {
    (Some(first), Some(second), Some(_)) =>
      if first == 0 || first == 10 || first == 127 {
        true
      } else if first == 192 && second == 168 {
        true
      } else if first == 172 && second >= 16 && second <= 31 {
        true
      } else if first == 169 && second == 254 {
        true
      } else if first == 100 && second >= 64 && second <= 127 {
        true
      } else {
        // 组播（224-239）与保留段（240-255）
        first >= 224
      }
    _ => true
  }
}

///|
fn parse_ipv4_octet(text : String) -> Int32? {
  if text == "" || text.length() > 3 {
    return None
  }
  let mut value = 0
  for ch in text {
    if ch < '0' || ch > '9' {
      return None
    }
    value = value * 10 + (ch.to_int() - 48)
  }
  if value > 255 {
    None
  } else {
    Some(value)
  }
}

///|
fn parse_hex_octet(text : String) -> Int32? {
  if text.length() != 2 {
    return None
  }
  let mut value = 0
  for ch in text {
    let digit = if ch >= '0' && ch <= '9' {
      ch.to_int() - 48
    } else if ch >= 'a' && ch <= 'f' {
      ch.to_int() - 87
    } else {
      return None
    }
    value = value * 16 + digit
  }
  Some(value)
}

///|
fn is_all_digits(text : String) -> Bool {
  if text == "" {
    return false
  }
  for ch in text {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}

///|
fn is_all_hex(text : String) -> Bool {
  for ch in text {
    let is_decimal = ch >= '0' && ch <= '9'
    let is_lower_hex = ch >= 'a' && ch <= 'f'
    if !is_decimal && !is_lower_hex {
      return false
    }
  }
  true
}

///|
/// Win32 strips trailing dots and spaces from every path component when it
/// opens a file. The lexical layer must mirror that, otherwise `.. ` or `.. .`
/// look like ordinary directory names and an escaping path appears to stay
/// inside the allowed root.
fn trim_trailing_chars(text : String, chars : String) -> String {
  let mut end = text.length()
  while end > 0 {
    let last = text[end - 1:end].to_owned()
    if chars.contains(last) {
      end = end - 1
    } else {
      break
    }
  }
  text[:end].to_owned()
}

///|
fn count_dots(text : String) -> Int32 {
  let mut count = 0
  for ch in text {
    if ch == '.' {
      count = count + 1
    }
  }
  count
}

///|
pub fn build_mcp_convert_context(
  config : McpSecurityConfig,
) -> @core.ConvertContext {
  let mut ctx = @core.ConvertContext::default()
  if config.enable_ocr {
    ctx = {
      ..ctx,
      ocr: @ocr.OcrConfig::{
        ..@ocr.OcrConfig::default(),
        mode: @ocr.Auto,
        enable_embedded_images: true,
      },
    }
  }
  ctx
}

///|
pub fn clamp_mcp_output_chars(
  requested_limit : Int32?,
  config : McpSecurityConfig,
) -> Int32? {
  match (requested_limit, config.max_output_chars) {
    (Some(requested), Some(boundary)) => Some(min_int(requested, boundary))
    (Some(requested), None) => Some(requested)
    (None, Some(boundary)) => Some(boundary)
    (None, None) => None
  }
}

///|
fn parse_allowed_roots_env() -> Result[Array[String], String] {
  match @env.get_env_var("MOONBITMARK_MCP_ALLOWED_ROOTS") {
    Some(raw) if raw.trim() != "" => {
      let roots : Array[String] = []
      for segment in split_root_segments(raw) {
        if segment.trim() != "" {
          let resolved = resolve_file_path(segment.trim().to_owned())
          if resolved != "" {
            roots.push(resolved)
          }
        }
      }
      if roots.length() == 0 {
        return Err(
          "MOONBITMARK_MCP_ALLOWED_ROOTS must contain at least one non-empty path.",
        )
      }
      Ok(roots)
    }
    _ => {
      let root = resolve_file_path(current_dir_or_dot())
      if root == "" {
        Err(
          "Unable to determine the current directory for the default MOONBITMARK_MCP_ALLOWED_ROOTS.",
        )
      } else {
        Ok([root])
      }
    }
  }
}

///|
fn split_root_segments(raw : String) -> Array[String] {
  let items : Array[String] = []
  for line in raw.replace(old="\r", new="").split("\n").to_array() {
    for segment in line.split(";").to_array() {
      let value = segment.to_owned()
      if value.trim() != "" {
        items.push(value)
      }
    }
  }
  items
}

///|
fn parse_bool_env(name : String, fallback : Bool) -> Result[Bool, String] {
  match @env.get_env_var(name) {
    Some(raw) if raw.trim() != "" => {
      let normalized = raw.trim().to_lower().to_owned()
      match normalized {
        "1" => Ok(true)
        "true" => Ok(true)
        "yes" => Ok(true)
        "on" => Ok(true)
        "0" => Ok(false)
        "false" => Ok(false)
        "no" => Ok(false)
        "off" => Ok(false)
        _ => Err(name + " must be one of: 1, 0, true, false, yes, no, on, off.")
      }
    }
    _ => Ok(fallback)
  }
}

///|
fn parse_positive_int_env(name : String) -> Result[Int32?, String] {
  match @env.get_env_var(name) {
    Some(raw) if raw.trim() != "" => {
      let value : Int32 = @string.from_str(raw.trim()) catch {
        _ => return Err(name + " must be a positive integer.")
      }
      if value > 0 {
        Ok(Some(value))
      } else {
        Err(name + " must be a positive integer.")
      }
    }
    _ => Ok(None)
  }
}

///|
fn parse_positive_int_env_with_default(
  name : String,
  fallback : Int32,
) -> Result[Int32, String] {
  match parse_positive_int_env(name) {
    Ok(Some(value)) => Ok(value)
    Ok(None) => Ok(fallback)
    Err(message) => Err(message)
  }
}

///|
fn current_dir_or_dot() -> String {
  match @env.current_dir() {
    Some(dir) if dir.trim() != "" => dir
    _ => "."
  }
}

///|
fn normalize_file_uri(uri : String) -> String {
  if uri.has_prefix("file://") {
    uri[7:].to_owned()
  } else {
    uri
  }
}

///|
fn is_http_input(input : String) -> Bool {
  input.has_prefix("http://") || input.has_prefix("https://")
}

///|
fn resolve_file_path(path : String) -> String {
  let normalized = canonicalize_path(@core.normalize_path(path))
  if is_absolute_path(normalized) {
    normalized
  } else {
    let base = @core.normalize_path(current_dir_or_dot())
    let resolved = canonicalize_path(base + "/" + normalized)
    // Guard against degenerate resolution: when the current directory is
    // unavailable, both base and path can collapse to empty segments and
    // produce an empty string, which would make every boundary check fail
    // with an unhelpful blank message. Fall back to the base so downstream
    // checks always have a meaningful path to compare and report.
    if resolved == "" {
      base
    } else {
      resolved
    }
  }
}

///|
fn path_within_allowed_roots(path : String, roots : Array[String]) -> Bool {
  let compare_path = normalize_compare_path(path)
  for root in roots {
    let compare_root = normalize_compare_path(root)
    if compare_path == compare_root ||
      compare_path.has_prefix(compare_root + "/") {
      return true
    }
  }
  false
}

///|
fn canonicalize_path(path : String) -> String {
  let normalized = @core.normalize_path(path)
  let prefix = path_prefix(normalized)
  let start = prefix.length()
  let remainder = normalized[start:]
  let segments : Array[String] = []
  for raw_segment in remainder.split("/").to_array() {
    let raw = raw_segment.to_owned()
    // Windows 内核在打开文件时会剥掉每段末尾的点和空格，词法层必须同步剥离，
    // 否则 `.. ` / `.. .` 会被当成普通目录名，让越界路径在规范形式里仍然
    // 看起来位于允许根内（例如 `C:\allowed\.. \Windows` 会被放行）。
    let without_spaces = trim_trailing_chars(raw, " ")
    if without_spaces == "." {
      continue
    }
    if without_spaces == ".." {
      ignore(segments.pop())
      continue
    }
    let effective = trim_trailing_chars(without_spaces, ". ")
    if effective == "" || effective == "." {
      // 剥完只剩空的退化段（如 ".. ." / "..."）：按父目录处理，让越界路径
      // 在规范形式里保持可见，而不是被静默吞掉。
      if count_dots(raw) >= 2 {
        ignore(segments.pop())
      }
      continue
    }
    if effective == ".." {
      ignore(segments.pop())
    } else {
      segments.push(effective)
    }
  }

  match prefix {
    "/" => "/" + segments.join("/")
    "" => segments.join("/")
    _ =>
      if segments.length() == 0 {
        prefix + "/"
      } else {
        prefix + "/" + segments.join("/")
      }
  }
}

///|
fn path_prefix(path : String) -> String {
  if path.length() >= 2 &&
    is_ascii_letter(path[0]) &&
    path[1:2].to_owned() == ":" {
    path[0:2].to_owned()
  } else if path.has_prefix("/") {
    "/"
  } else {
    ""
  }
}

///|
fn is_absolute_path(path : String) -> Bool {
  path.has_prefix("/") ||
  (
    path.length() >= 2 &&
    is_ascii_letter(path[0]) &&
    path[1:2].to_owned() == ":"
  )
}

///|
fn normalize_compare_path(path : String) -> String {
  path.to_lower().to_string()
}

///|
fn is_ascii_letter(ch : UInt16) -> Bool {
  (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122)
}

///|
fn min_int(left : Int32, right : Int32) -> Int32 {
  if left <= right {
    left
  } else {
    right
  }
}
