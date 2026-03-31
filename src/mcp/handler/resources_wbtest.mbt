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
async test "resource registry reads capabilities resource text" {
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
async test "resource registry rejects unknown resource uri" {
  let registry = ResourceRegistry::new().register_static_resources()
  let content = registry.read("moonbitmark://missing")
  match content {
    Ok(_) => fail("expected missing resource to return an error")
    Err(message) => inspect(message, content="Resource not found")
  }
}

///|
async test "resource registry reads uploaded document resource text" {
  let stored = store_document_resource(
    "resource-demo.txt",
    @utf8.encode("resource demo"),
    Some("text/plain"),
  )
  let registry = ResourceRegistry::new().register_static_resources()
  let content = registry.read(stored.resource_uri)
  match content {
    Ok(value) => {
      inspect(value.uri, content=stored.resource_uri)
      inspect(
        extract_resource_text(value).contains(
          "source_filename: resource-demo.txt",
        ),
        content="true",
      )
    }
    Err(message) => fail("unexpected uploaded resource read error: " + message)
  }
}
