///|
fn extract_resource_text(content : @types.McpResourceContents) -> String {
  content.text
}

///|
test "resource registry lists the documented static resources" {
  let registry = ResourceRegistry::new().register_static_resources()
  let resources = registry.list()
  inspect(resources.length(), content="5")
  inspect(resources[0].uri, content="moonbitmark://capabilities")
  inspect(resources[4].uri, content="moonbitmark://mcp-usage")
  inspect(resources[0].mime_type == Some("text/markdown"), content="true")
}

///|
test "resource registry reads capabilities resource text" {
  let registry = ResourceRegistry::new().register_static_resources()
  let content = registry.read("moonbitmark://capabilities")
  match content {
    Ok(value) => {
      inspect(value.uri, content="moonbitmark://capabilities")
      inspect(value.mime_type == Some("text/markdown"), content="true")
      inspect(
        extract_resource_text(value).contains("resources/list"),
        content="true",
      )
    }
    Err(message) => fail("unexpected resource read error: " + message)
  }
}

///|
test "resource registry rejects unknown resource uri" {
  let registry = ResourceRegistry::new().register_static_resources()
  let content = registry.read("moonbitmark://missing")
  match content {
    Ok(_) => fail("expected missing resource to return an error")
    Err(message) => inspect(message, content="Resource not found")
  }
}
