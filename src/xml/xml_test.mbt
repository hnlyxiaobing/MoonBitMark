///|
/// XML 解析器测试
test "parse simple element" {
  let xml = "<root></root>"
  match parse_xml(xml) {
    Ok(events) =>
      // 首先检查是否有事件
      assert_eq(events.length(), 2)
    Err(e) =>
      // 打印错误信息以便调试
      match e {
        SyntaxError(line, msg) => fail("SyntaxError at line \{line}: \{msg}")
        UnclosedTag(tag) => fail("UnclosedTag: \{tag}")
        MismatchedTag(expected, actual) =>
          fail("MismatchedTag: expected \{expected}, got \{actual}")
        InvalidAttributeFormat(msg) => fail("InvalidAttributeFormat: \{msg}")
        InvalidEntity(entity) => fail("InvalidEntity: \{entity}")
        IOError(msg) => fail("IOError: \{msg}")
      }
  }
}

///|
test "parse self-closing tag" {
  let xml = "<root/>"
  match parse_xml(xml) {
    Ok(events) => assert_eq(events.length(), 2)
    Err(e) =>
      match e {
        SyntaxError(line, msg) => fail("SyntaxError at line \{line}: \{msg}")
        UnclosedTag(tag) => fail("UnclosedTag: \{tag}")
        MismatchedTag(expected, actual) =>
          fail("MismatchedTag: expected \{expected}, got \{actual}")
        InvalidAttributeFormat(msg) => fail("InvalidAttributeFormat: \{msg}")
        InvalidEntity(entity) => fail("InvalidEntity: \{entity}")
        IOError(msg) => fail("IOError: \{msg}")
      }
  }
}

///|
test "parse element with text" {
  let xml = "<root>hello</root>"
  match parse_xml(xml) {
    Ok(events) => assert_eq(events.length(), 3)
    Err(e) =>
      match e {
        SyntaxError(line, msg) => fail("SyntaxError at line \{line}: \{msg}")
        UnclosedTag(tag) => fail("UnclosedTag: \{tag}")
        MismatchedTag(expected, actual) =>
          fail("MismatchedTag: expected \{expected}, got \{actual}")
        InvalidAttributeFormat(msg) => fail("InvalidAttributeFormat: \{msg}")
        InvalidEntity(entity) => fail("InvalidEntity: \{entity}")
        IOError(msg) => fail("IOError: \{msg}")
      }
  }
}

///|
test "parse nested elements" {
  let xml = "<root><child>text</child></root>"
  match parse_xml(xml) {
    Ok(events) =>
      // <root> + <child> + text + </child> + </root> = 5 events
      assert_eq(events.length(), 5)
    Err(e) =>
      match e {
        SyntaxError(line, msg) => fail("SyntaxError at line \{line}: \{msg}")
        UnclosedTag(tag) => fail("UnclosedTag: \{tag}")
        MismatchedTag(expected, actual) =>
          fail("MismatchedTag: expected \{expected}, got \{actual}")
        InvalidAttributeFormat(msg) => fail("InvalidAttributeFormat: \{msg}")
        InvalidEntity(entity) => fail("InvalidEntity: \{entity}")
        IOError(msg) => fail("IOError: \{msg}")
      }
  }
}

///|
test "error on mismatched tags" {
  let xml = "<root></other>"
  match parse_xml(xml) {
    Ok(_) => fail("should have failed")
    Err(_) =>
      // 预期错误
      assert_true(true)
  }
}

///|
test "error on unclosed tag" {
  let xml = "<root><child></root>"
  match parse_xml(xml) {
    Ok(_) => fail("should have failed")
    Err(_) =>
      // 预期错误
      assert_true(true)
  }
}
