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

///|
test "parse namespace prefixed elements" {
  let xml = "<p:root xmlns:p=\"http://example.com\"><p:child id=\"1\" r:id=\"rId1\"/></p:root>"
  match parse_xml(xml) {
    Ok(events) =>
      // <p:root> + <p:child/> + </p:root> = 4 events (self-close generates 2)
      assert_eq(events.length(), 4)
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
test "parse presentation.xml style" {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\r\n<p:presentation xmlns:p=\"http://example.com\"><p:sldIdLst><p:sldId id=\"256\" r:id=\"rId1\"/></p:sldIdLst></p:presentation>"
  match parse_xml(xml) {
    Ok(events) =>
      // Should parse without errors
      assert_true(events.length() > 0)
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
test "parse complex presentation.xml" {
  // This is a simplified version of the actual test.pptx presentation.xml
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\r\n<p:presentation xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" saveSubsetFonts=\"1\"><p:sldIdLst><p:sldId id=\"256\" r:id=\"rId3\"/><p:sldId id=\"264\" r:id=\"rId4\"/></p:sldIdLst></p:presentation>"
  match parse_xml(xml) {
    Ok(events) =>
      // Should parse without errors
      assert_true(events.length() > 0)
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
test "parse curly braces in attribute value" {
  let xml = "<p:ext uri=\"{EFAFB233-063F-42B5-8137-9DF3F51BA10A}\"><child/></p:ext>"
  match parse_xml(xml) {
    Ok(events) =>
      // Should parse without errors
      assert_eq(events.length(), 4)
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
test "parse xmlns empty" {
  // Test empty namespace declaration
  let xml = "<p15:notesGuideLst xmlns:p15=\"http://schemas.microsoft.com/office/powerpoint/2012/main\" xmlns=\"\"><p15:guide id=\"1\"/></p15:notesGuideLst>"
  match parse_xml(xml) {
    Ok(events) =>
      // Should parse without errors
      assert_true(events.length() > 0)
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
test "parse actual presentation.xml excerpt" {
  // This is the actual content from test.pptx presentation.xml
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\r\n<p:presentation xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" saveSubsetFonts=\"1\"><p:sldMasterIdLst><p:sldMasterId id=\"2147483660\" r:id=\"rId1\"/></p:sldMasterIdLst></p:presentation>"
  match parse_xml(xml) {
    Ok(events) =>
      // Should parse without errors
      assert_true(events.length() > 0)
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
