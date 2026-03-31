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

///|
test "read resource params require a uri string" {
  let parsed = parse_read_resource_params(
    @types.Object({ "uri": @types.String("moonbitmark://capabilities") }),
  )
  match parsed {
    Ok(value) => inspect(value.uri, content="moonbitmark://capabilities")
    Err(message) => fail("unexpected parse error: " + message)
  }
}

///|
test "get prompt params default arguments to an empty object" {
  let parsed = parse_get_prompt_params(
    @types.Object({ "name": @types.String("convert-document") }),
  )
  match parsed {
    Ok(value) => {
      inspect(value.name, content="convert-document")
      inspect(value.arguments is @types.Object(_), content="true")
    }
    Err(message) => fail("unexpected parse error: " + message)
  }
}

///|
async test "handle jsonrpc request supports resources list and read" {
  let server = McpServer::new(@transport.StdioTransport::new())
  let list_response = server.handle_jsonrpc_request(
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"resources/list\"}",
  )
  match list_response {
    Some(response) =>
      match response.result {
        Some(@types.Object(map)) =>
          match map.get("resources") {
            Some(@types.Array(resources)) =>
              assert_true(resources.length() >= 5)
            _ => fail("expected resources array in resources/list result")
          }
        _ => fail("expected object result from resources/list")
      }
    None => fail("expected resources/list to return a response")
  }

  let read_response = server.handle_jsonrpc_request(
    "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"resources/read\",\"params\":{\"uri\":\"moonbitmark://capabilities\"}}",
  )
  match read_response {
    Some(response) =>
      match response.result {
        Some(@types.Object(map)) =>
          match map.get("contents") {
            Some(@types.Array(contents)) => assert_true(contents.length() == 1)
            _ => fail("expected contents array in resources/read result")
          }
        _ => fail("expected object result from resources/read")
      }
    None => fail("expected resources/read to return a response")
  }
}

///|
async test "handle jsonrpc request supports prompts list and get" {
  let server = McpServer::new(@transport.StdioTransport::new())
  let list_response = server.handle_jsonrpc_request(
    "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"prompts/list\"}",
  )
  match list_response {
    Some(response) =>
      match response.result {
        Some(@types.Object(map)) =>
          match map.get("prompts") {
            Some(@types.Array(prompts)) => assert_true(prompts.length() >= 2)
            _ => fail("expected prompts array in prompts/list result")
          }
        _ => fail("expected object result from prompts/list")
      }
    None => fail("expected prompts/list to return a response")
  }

  let get_response = server.handle_jsonrpc_request(
    "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"prompts/get\",\"params\":{\"name\":\"convert-document\",\"arguments\":{\"uri\":\"docs/sample.pdf\"}}}",
  )
  match get_response {
    Some(response) =>
      match response.result {
        Some(@types.Object(map)) =>
          match map.get("messages") {
            Some(@types.Array(messages)) => assert_true(messages.length() == 1)
            _ => fail("expected messages array in prompts/get result")
          }
        _ => fail("expected object result from prompts/get")
      }
    None => fail("expected prompts/get to return a response")
  }
}
