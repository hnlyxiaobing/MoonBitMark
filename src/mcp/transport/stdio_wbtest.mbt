///|
test "sanitize input line trims bom and crlf" {
  inspect(
    sanitize_input_line("\u{feff}{\"jsonrpc\":\"2.0\"}\r"),
    content="{\"jsonrpc\":\"2.0\"}",
  )
}
