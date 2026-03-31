///|
fn extract_prompt_text(message : @types.McpPromptMessage) -> String {
  message.content.text
}

///|
test "prompt registry lists the two documented prompts" {
  let registry = PromptRegistry::new().register_static_prompts()
  let prompts = registry.list()
  inspect(prompts.length(), content="2")
  inspect(prompts[0].name, content="convert-document")
  inspect(prompts[1].name, content="diagnose-conversion-failure")
  match prompts[0].arguments {
    Some(arguments) => inspect(arguments.length(), content="4")
    None => fail("expected convert-document arguments")
  }
}

///|
test "convert-document prompt requires uri and returns preview-first workflow" {
  let registry = PromptRegistry::new().register_static_prompts()
  let result = registry.get(
    "convert-document",
    @types.Object({
      "uri": @types.String("docs/sample.pdf"),
      "mode": @types.String("preview"),
    }),
  )
  match result {
    Ok(value) => {
      inspect(value.messages.length(), content="1")
      inspect(value.messages[0].role, content="user")
      inspect(
        extract_prompt_text(value.messages[0]).contains("inspect_document"),
        content="true",
      )
      inspect(
        extract_prompt_text(value.messages[0]).contains("mode=preview"),
        content="true",
      )
    }
    Err(message) => fail("unexpected prompt error: " + message)
  }
}

///|
test "diagnose prompt rejects missing required arguments" {
  let registry = PromptRegistry::new().register_static_prompts()
  let result = registry.get(
    "diagnose-conversion-failure",
    @types.Object({ "uri": @types.String("docs/broken.pdf") }),
  )
  match result {
    Ok(_) => fail("expected missing required prompt argument to fail")
    Err(message) =>
      inspect(
        message,
        content="Missing required prompt argument: failure_summary",
      )
  }
}
