// MoonBitMark MCP Transport - STDIO Implementation

///|
/// STDIO 传输实现
pub(all) struct StdioTransport {
  // 无需状态,直接使用标准输入输出
}

///|
/// 创建 STDIO 传输
pub fn StdioTransport::new() -> StdioTransport {
  StdioTransport::{  }
}

///|
/// 读取一行 JSON 字符串
pub async fn StdioTransport::read_line(self : StdioTransport) -> String? {
  ignore(self)
  match @stdio.stdin.read_until("\n") {
    Some(line) => Some(sanitize_input_line(line))
    None => None
  }
}

///|
/// 写入一行 JSON 字符串
pub async fn StdioTransport::write_line(
  self : StdioTransport,
  line : String,
) -> Unit {
  ignore(self)
  @stdio.stdout.write(line + "\n")
}

///|
fn trim_line_end(line : String) -> String {
  if line.has_suffix("\r") {
    line.trim_end(chars="\r").to_string()
  } else {
    line
  }
}

///|
fn sanitize_input_line(line : String) -> String {
  trim_line_end(strip_utf8_bom_prefix(line))
}

///|
fn strip_utf8_bom_prefix(line : String) -> String {
  let mut result = ""
  let mut is_first = true
  for ch in line {
    if is_first && ch == '\u{feff}' {
      is_first = false
      continue
    }
    result = result + ch.to_string()
    is_first = false
  }
  result
}
