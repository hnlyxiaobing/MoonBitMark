///|
/// XML 解析器测试
test "parse simple element" {
  let xml = "<root></root>"
  let events = @xml.parse_xml(xml) catch {
    e =>
      match e {
        @xml.XMLParseError::SyntaxError(line, msg) =>
          fail("SyntaxError at line \{line}: \{msg}")
        @xml.XMLParseError::UnclosedTag(tag) => fail("UnclosedTag: \{tag}")
        @xml.XMLParseError::MismatchedTag(expected, actual) =>
          fail("MismatchedTag: expected \{expected}, got \{actual}")
        @xml.XMLParseError::InvalidAttributeFormat(msg) =>
          fail("InvalidAttributeFormat: \{msg}")
        @xml.XMLParseError::InvalidEntity(entity) =>
          fail("InvalidEntity: \{entity}")
        @xml.XMLParseError::IOError(msg) => fail("IOError: \{msg}")
        _ => fail("unexpected non-XML parse error")
      }
  }
  // 首先检查是否有事件
  assert_eq(events.length(), 2)
}

///|
test "parse self-closing tag" {
  let xml = "<root/>"
  let events = @xml.parse_xml(xml) catch {
    e =>
      match e {
        @xml.XMLParseError::SyntaxError(line, msg) =>
          fail("SyntaxError at line \{line}: \{msg}")
        @xml.XMLParseError::UnclosedTag(tag) => fail("UnclosedTag: \{tag}")
        @xml.XMLParseError::MismatchedTag(expected, actual) =>
          fail("MismatchedTag: expected \{expected}, got \{actual}")
        @xml.XMLParseError::InvalidAttributeFormat(msg) =>
          fail("InvalidAttributeFormat: \{msg}")
        @xml.XMLParseError::InvalidEntity(entity) =>
          fail("InvalidEntity: \{entity}")
        @xml.XMLParseError::IOError(msg) => fail("IOError: \{msg}")
        _ => fail("unexpected non-XML parse error")
      }
  }
  assert_eq(events.length(), 2)
}

///|
test "parse element with text" {
  let xml = "<root>hello</root>"
  let events = @xml.parse_xml(xml) catch {
    e =>
      match e {
        @xml.XMLParseError::SyntaxError(line, msg) =>
          fail("SyntaxError at line \{line}: \{msg}")
        @xml.XMLParseError::UnclosedTag(tag) => fail("UnclosedTag: \{tag}")
        @xml.XMLParseError::MismatchedTag(expected, actual) =>
          fail("MismatchedTag: expected \{expected}, got \{actual}")
        @xml.XMLParseError::InvalidAttributeFormat(msg) =>
          fail("InvalidAttributeFormat: \{msg}")
        @xml.XMLParseError::InvalidEntity(entity) =>
          fail("InvalidEntity: \{entity}")
        @xml.XMLParseError::IOError(msg) => fail("IOError: \{msg}")
        _ => fail("unexpected non-XML parse error")
      }
  }
  assert_eq(events.length(), 3)
}

///|
test "parse nested elements" {
  let xml = "<root><child>text</child></root>"
  let events = @xml.parse_xml(xml) catch {
    e =>
      match e {
        @xml.XMLParseError::SyntaxError(line, msg) =>
          fail("SyntaxError at line \{line}: \{msg}")
        @xml.XMLParseError::UnclosedTag(tag) => fail("UnclosedTag: \{tag}")
        @xml.XMLParseError::MismatchedTag(expected, actual) =>
          fail("MismatchedTag: expected \{expected}, got \{actual}")
        @xml.XMLParseError::InvalidAttributeFormat(msg) =>
          fail("InvalidAttributeFormat: \{msg}")
        @xml.XMLParseError::InvalidEntity(entity) =>
          fail("InvalidEntity: \{entity}")
        @xml.XMLParseError::IOError(msg) => fail("IOError: \{msg}")
        _ => fail("unexpected non-XML parse error")
      }
  }
  // <root> + <child> + text + </child> + </root> = 5 events
  assert_eq(events.length(), 5)
}

///|
test "error on mismatched tags" {
  let xml = "<root></other>"
  // 预期解析失败并抛出 XMLParseError
  try @xml.parse_xml(xml) catch {
    _ => ()
  } noraise {
    _ => fail("should have failed")
  }
}

///|
test "error on unclosed tag" {
  let xml = "<root><child></root>"
  // 预期解析失败并抛出 XMLParseError
  try @xml.parse_xml(xml) catch {
    _ => ()
  } noraise {
    _ => fail("should have failed")
  }
}

///|
test "parse namespace prefixed elements" {
  let xml = "<p:root xmlns:p=\"http://example.com\"><p:child id=\"1\" r:id=\"rId1\"/></p:root>"
  let events = @xml.parse_xml(xml) catch {
    e =>
      match e {
        @xml.XMLParseError::SyntaxError(line, msg) =>
          fail("SyntaxError at line \{line}: \{msg}")
        @xml.XMLParseError::UnclosedTag(tag) => fail("UnclosedTag: \{tag}")
        @xml.XMLParseError::MismatchedTag(expected, actual) =>
          fail("MismatchedTag: expected \{expected}, got \{actual}")
        @xml.XMLParseError::InvalidAttributeFormat(msg) =>
          fail("InvalidAttributeFormat: \{msg}")
        @xml.XMLParseError::InvalidEntity(entity) =>
          fail("InvalidEntity: \{entity}")
        @xml.XMLParseError::IOError(msg) => fail("IOError: \{msg}")
        _ => fail("unexpected non-XML parse error")
      }
  }
  // <p:root> + <p:child/> + </p:root> = 4 events (self-close generates 2)
  assert_eq(events.length(), 4)
}

///|
test "parse presentation.xml style" {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\r\n<p:presentation xmlns:p=\"http://example.com\"><p:sldIdLst><p:sldId id=\"256\" r:id=\"rId1\"/></p:sldIdLst></p:presentation>"
  let events = @xml.parse_xml(xml) catch {
    e =>
      match e {
        @xml.XMLParseError::SyntaxError(line, msg) =>
          fail("SyntaxError at line \{line}: \{msg}")
        @xml.XMLParseError::UnclosedTag(tag) => fail("UnclosedTag: \{tag}")
        @xml.XMLParseError::MismatchedTag(expected, actual) =>
          fail("MismatchedTag: expected \{expected}, got \{actual}")
        @xml.XMLParseError::InvalidAttributeFormat(msg) =>
          fail("InvalidAttributeFormat: \{msg}")
        @xml.XMLParseError::InvalidEntity(entity) =>
          fail("InvalidEntity: \{entity}")
        @xml.XMLParseError::IOError(msg) => fail("IOError: \{msg}")
        _ => fail("unexpected non-XML parse error")
      }
  }
  // Should parse without errors
  assert_true(events.length() > 0)
}

///|
test "parse complex presentation.xml" {
  // This is a simplified version of the actual test.pptx presentation.xml
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\r\n<p:presentation xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" saveSubsetFonts=\"1\"><p:sldIdLst><p:sldId id=\"256\" r:id=\"rId3\"/><p:sldId id=\"264\" r:id=\"rId4\"/></p:sldIdLst></p:presentation>"
  let events = @xml.parse_xml(xml) catch {
    e =>
      match e {
        @xml.XMLParseError::SyntaxError(line, msg) =>
          fail("SyntaxError at line \{line}: \{msg}")
        @xml.XMLParseError::UnclosedTag(tag) => fail("UnclosedTag: \{tag}")
        @xml.XMLParseError::MismatchedTag(expected, actual) =>
          fail("MismatchedTag: expected \{expected}, got \{actual}")
        @xml.XMLParseError::InvalidAttributeFormat(msg) =>
          fail("InvalidAttributeFormat: \{msg}")
        @xml.XMLParseError::InvalidEntity(entity) =>
          fail("InvalidEntity: \{entity}")
        @xml.XMLParseError::IOError(msg) => fail("IOError: \{msg}")
        _ => fail("unexpected non-XML parse error")
      }
  }
  // Should parse without errors
  assert_true(events.length() > 0)
}

///|
test "parse curly braces in attribute value" {
  let xml = "<p:ext uri=\"{EFAFB233-063F-42B5-8137-9DF3F51BA10A}\"><child/></p:ext>"
  let events = @xml.parse_xml(xml) catch {
    e =>
      match e {
        @xml.XMLParseError::SyntaxError(line, msg) =>
          fail("SyntaxError at line \{line}: \{msg}")
        @xml.XMLParseError::UnclosedTag(tag) => fail("UnclosedTag: \{tag}")
        @xml.XMLParseError::MismatchedTag(expected, actual) =>
          fail("MismatchedTag: expected \{expected}, got \{actual}")
        @xml.XMLParseError::InvalidAttributeFormat(msg) =>
          fail("InvalidAttributeFormat: \{msg}")
        @xml.XMLParseError::InvalidEntity(entity) =>
          fail("InvalidEntity: \{entity}")
        @xml.XMLParseError::IOError(msg) => fail("IOError: \{msg}")
        _ => fail("unexpected non-XML parse error")
      }
  }
  // Should parse without errors
  assert_eq(events.length(), 4)
}

///|
test "parse xmlns empty" {
  // Test empty namespace declaration
  let xml = "<p15:notesGuideLst xmlns:p15=\"http://schemas.microsoft.com/office/powerpoint/2012/main\" xmlns=\"\"><p15:guide id=\"1\"/></p15:notesGuideLst>"
  let events = @xml.parse_xml(xml) catch {
    e =>
      match e {
        @xml.XMLParseError::SyntaxError(line, msg) =>
          fail("SyntaxError at line \{line}: \{msg}")
        @xml.XMLParseError::UnclosedTag(tag) => fail("UnclosedTag: \{tag}")
        @xml.XMLParseError::MismatchedTag(expected, actual) =>
          fail("MismatchedTag: expected \{expected}, got \{actual}")
        @xml.XMLParseError::InvalidAttributeFormat(msg) =>
          fail("InvalidAttributeFormat: \{msg}")
        @xml.XMLParseError::InvalidEntity(entity) =>
          fail("InvalidEntity: \{entity}")
        @xml.XMLParseError::IOError(msg) => fail("IOError: \{msg}")
        _ => fail("unexpected non-XML parse error")
      }
  }
  // Should parse without errors
  assert_true(events.length() > 0)
}

///|
test "parse actual presentation.xml excerpt" {
  // This is the actual content from test.pptx presentation.xml
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\r\n<p:presentation xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" saveSubsetFonts=\"1\"><p:sldMasterIdLst><p:sldMasterId id=\"2147483660\" r:id=\"rId1\"/></p:sldMasterIdLst></p:presentation>"
  let events = @xml.parse_xml(xml) catch {
    e =>
      match e {
        @xml.XMLParseError::SyntaxError(line, msg) =>
          fail("SyntaxError at line \{line}: \{msg}")
        @xml.XMLParseError::UnclosedTag(tag) => fail("UnclosedTag: \{tag}")
        @xml.XMLParseError::MismatchedTag(expected, actual) =>
          fail("MismatchedTag: expected \{expected}, got \{actual}")
        @xml.XMLParseError::InvalidAttributeFormat(msg) =>
          fail("InvalidAttributeFormat: \{msg}")
        @xml.XMLParseError::InvalidEntity(entity) =>
          fail("InvalidEntity: \{entity}")
        @xml.XMLParseError::IOError(msg) => fail("IOError: \{msg}")
        _ => fail("unexpected non-XML parse error")
      }
  }
  // Should parse without errors
  assert_true(events.length() > 0)
}

///|
test "skip DOCTYPE declaration" {
  let xml = "<!DOCTYPE html><html><body>text</body></html>"
  let events = @xml.parse_xml(xml) catch {
    e =>
      match e {
        @xml.XMLParseError::SyntaxError(line, msg) =>
          fail("SyntaxError at line \{line}: \{msg}")
        @xml.XMLParseError::UnclosedTag(tag) => fail("UnclosedTag: \{tag}")
        @xml.XMLParseError::MismatchedTag(expected, actual) =>
          fail("MismatchedTag: expected \{expected}, got \{actual}")
        @xml.XMLParseError::InvalidAttributeFormat(msg) =>
          fail("InvalidAttributeFormat: \{msg}")
        @xml.XMLParseError::InvalidEntity(entity) =>
          fail("InvalidEntity: \{entity}")
        @xml.XMLParseError::IOError(msg) => fail("IOError: \{msg}")
        _ => fail("unexpected non-XML parse error")
      }
  }
  // <html> + <body> + text + </body> + </html> = 5 events
  assert_eq(events.length(), 5)
}

///|
test "skip DOCTYPE with internal subset containing '>'" {
  // 内部子集中的 `>` 不得截断 DOCTYPE
  let xml = "<!DOCTYPE r [ <!ENTITY x \"a>b\"> ]><r>ok</r>"
  let events = @xml.parse_xml(xml) catch {
    e =>
      match e {
        @xml.XMLParseError::SyntaxError(line, msg) =>
          fail("SyntaxError at line \{line}: \{msg}")
        @xml.XMLParseError::UnclosedTag(tag) => fail("UnclosedTag: \{tag}")
        @xml.XMLParseError::MismatchedTag(expected, actual) =>
          fail("MismatchedTag: expected \{expected}, got \{actual}")
        @xml.XMLParseError::InvalidAttributeFormat(msg) =>
          fail("InvalidAttributeFormat: \{msg}")
        @xml.XMLParseError::InvalidEntity(entity) =>
          fail("InvalidEntity: \{entity}")
        @xml.XMLParseError::IOError(msg) => fail("IOError: \{msg}")
        _ => fail("unexpected non-XML parse error")
      }
  }
  // <r> + text + </r> = 3 events
  assert_eq(events.length(), 3)
}

///|
test "parse CDATA section as text" {
  let xml = "<root><![CDATA[a < b]]></root>"
  let events = @xml.parse_xml(xml) catch {
    e =>
      match e {
        @xml.XMLParseError::SyntaxError(line, msg) =>
          fail("SyntaxError at line \{line}: \{msg}")
        @xml.XMLParseError::UnclosedTag(tag) => fail("UnclosedTag: \{tag}")
        @xml.XMLParseError::MismatchedTag(expected, actual) =>
          fail("MismatchedTag: expected \{expected}, got \{actual}")
        @xml.XMLParseError::InvalidAttributeFormat(msg) =>
          fail("InvalidAttributeFormat: \{msg}")
        @xml.XMLParseError::InvalidEntity(entity) =>
          fail("InvalidEntity: \{entity}")
        @xml.XMLParseError::IOError(msg) => fail("IOError: \{msg}")
        _ => fail("unexpected non-XML parse error")
      }
  }
  // <root> + text + </root> = 3 events
  assert_eq(events.length(), 3)
  match events[1] {
    TextContent(event) => assert_eq(event.content, "a < b")
    _ => fail("expected TextContent event")
  }
}

///|
test "error on invalid markup declaration" {
  let xml = "<root><!foo bar></root>"
  // 预期解析失败并抛出 XMLParseError
  try @xml.parse_xml(xml) catch {
    _ => ()
  } noraise {
    _ => fail("should have failed")
  }
}

///|
test "parser keeps greater-than inside quoted attribute value" {
  let xml = "<a b=\"x>y\">t</a>"
  let events = @xml.parse_xml(xml) catch {
    e =>
      match e {
        @xml.XMLParseError::SyntaxError(line, msg) =>
          fail("SyntaxError at line \{line}: \{msg}")
        @xml.XMLParseError::UnclosedTag(tag) => fail("UnclosedTag: \{tag}")
        @xml.XMLParseError::MismatchedTag(expected, actual) =>
          fail("MismatchedTag: expected \{expected}, got \{actual}")
        @xml.XMLParseError::InvalidAttributeFormat(msg) =>
          fail("InvalidAttributeFormat: \{msg}")
        @xml.XMLParseError::InvalidEntity(entity) =>
          fail("InvalidEntity: \{entity}")
        @xml.XMLParseError::IOError(msg) => fail("IOError: \{msg}")
        _ => fail("unexpected non-XML parse error")
      }
  }
  match events[0] {
    ElementStart(event) => assert_eq(event.attributes.get("b"), Some("x>y"))
    _ => fail("expected ElementStart event")
  }
}
