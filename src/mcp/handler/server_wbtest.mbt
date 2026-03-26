///|
test "parse json request rejects unsupported jsonrpc version" {
  let request : @types.JsonValue = @types.Object({
    "jsonrpc": @types.String("1.0"),
    "method": @types.String("initialize"),
  })
  let parsed = parse_json_request(request)
  match parsed {
    Ok(_) =>
      fail("expected parse_json_request to reject unsupported jsonrpc version")
    Err(message) => inspect(message, content="Unsupported jsonrpc version: 1.0")
  }
}

///|
test "request without id is treated as notification" {
  let request = @types.JsonRequest::{
    jsonrpc: "2.0",
    method_name: "notifications/initialized",
    params: Some(@types.Object({})),
    id: None,
  }
  inspect(request_expects_response(request), content="false")
}

///|
test "tool call params default arguments to empty object" {
  let parsed = parse_tool_call_params(
    @types.Object({ "name": @types.String("convert_to_markdown") }),
  )
  match parsed {
    Ok(value) => {
      inspect(value.name, content="convert_to_markdown")
      inspect(value.arguments is @types.Object(_), content="true")
    }
    Err(message) => fail("unexpected parse error: " + message)
  }
}
