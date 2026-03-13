///|
test "parse_basic_values" {
  assert_true(parse_json("true") is Ok(Bool(true)))
  assert_true(parse_json("false") is Ok(Bool(false)))
  assert_true(parse_json("null") is Ok(Null))
  assert_true(parse_json("42") is Ok(Number(42)))
  assert_true(parse_json("-42") is Ok(Number(-42)))
}

///|
test "parse_float_and_scientific" {
  assert_true(parse_json("3.14") is Ok(Float(_)))
  assert_true(parse_json("1.5e+10") is Ok(Float(_)))
  assert_true(parse_json("-1.5e-10") is Ok(Float(_)))
}

///|
test "parse_objects_and_arrays" {
  assert_true(parse_json("{\"key\":\"value\"}") is Ok(Object(_)))
  assert_true(parse_json("[1,2,3]") is Ok(Array(_)))
}

///|
test "parse_unicode_escape" {
  assert_true(parse_json("\"\\u0041\"") is Ok(String("A")))
}

///|
test "parse_errors" {
  assert_true(parse_json("{invalid}") is Err(_))
  assert_true(parse_json("\"\\x\"") is Err(_))
}
