///|
test "parse_basic_values" {
  assert_true(@types.parse_json("true") is Ok(Bool(true)))
  assert_true(@types.parse_json("false") is Ok(Bool(false)))
  assert_true(@types.parse_json("null") is Ok(Null))
  assert_true(@types.parse_json("42") is Ok(Number(42)))
  assert_true(@types.parse_json("-42") is Ok(Number(-42)))
}

///|
test "parse_float_and_scientific" {
  assert_true(@types.parse_json("3.14") is Ok(Float(_)))
  assert_true(@types.parse_json("1.5e+10") is Ok(Float(_)))
  assert_true(@types.parse_json("-1.5e-10") is Ok(Float(_)))
}

///|
test "parse_objects_and_arrays" {
  assert_true(@types.parse_json("{\"key\":\"value\"}") is Ok(Object(_)))
  assert_true(@types.parse_json("[1,2,3]") is Ok(Array(_)))
}

///|
test "parse_unicode_escape" {
  assert_true(@types.parse_json("\"\\u0041\"") is Ok(String("A")))
}

///|
test "parse_errors" {
  assert_true(@types.parse_json("{invalid}") is Err(_))
  assert_true(@types.parse_json("\"\\x\"") is Err(_))
}

///|
test "parse_objects_with_whitespace_after_commas" {
  // Standard JSON producers (for example Python's `json.dumps`) separate
  // object members with ", ". Such payloads must be accepted.
  assert_true(
    @types.parse_json("{\"a\": 1, \"b\": [2, 3], \"c\": {\"d\": \"e\"}}") is
    Ok(Object(_)),
  )
  assert_true(@types.parse_json("{ \"a\" : 1 }") is Ok(Object(_)))
}

///|
test "parse_rejects_trailing_comma_in_object" {
  assert_true(@types.parse_json("{\"a\":1,}") is Err(_))
}

///|
test "parse_rejects_excessive_nesting_depth" {
  // Deeply nested input must be rejected instead of exhausting the native
  // stack. The failure reuses the InvalidJson variant so that it travels
  // the regular parse-error path (JSON-RPC -32700).
  let mut deep = ""
  for _ in 0..<200 {
    deep = deep + "["
  }
  for _ in 0..<200 {
    deep = deep + "]"
  }
  match @types.parse_json(deep) {
    Err(InvalidJson(message)) =>
      assert_true(message.contains("depth"), msg=message)
    _ => fail("expected excessive nesting to be rejected")
  }
}

///|
test "parse_accepts_moderate_nesting_depth" {
  let mut moderate = ""
  for _ in 0..<20 {
    moderate = moderate + "["
  }
  for _ in 0..<20 {
    moderate = moderate + "]"
  }
  assert_true(@types.parse_json(moderate) is Ok(Array(_)))
}

///|
test "json_string_escapes_control_characters" {
  // RFC 8259 forbids raw C0 control characters inside JSON strings.
  let value = @types.JsonValue::String("a\u{0001}b")
  assert_true(value.to_string() == "\"a\\u0001b\"")
  // Every other C0 control character uses the uniform \u00XX form.
  let backspace = @types.JsonValue::String("\u{0008}")
  assert_true(backspace.to_string() == "\"\\u0008\"")
}
