// MoonBitMark MCP Transport - STDIO Implementation

use @jsonrpc.*

///|
/// STDIO 传输实现
pub(all) struct StdioTransport {
  // 无需状态,直接使用标准输入输出
}

///|
/// 创建 STDIO 传输
pub fn StdioTransport::new() -> StdioTransport {
  StdioTransport::{}
}

///|
/// 读取一行 JSON 字符串
pub fn StdioTransport::read_line(self : StdioTransport) -> String {
  @io.stdin().read_line().unwrap()
}

///|
/// 写入一行 JSON 字符串
pub fn StdioTransport::write_line(self : StdioTransport, line : String) -> Unit {
  println(line)
}
