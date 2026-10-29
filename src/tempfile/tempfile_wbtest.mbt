///|
async fn tempfile_test_dir() -> String {
  let dir = "_build/tempfile-wbtest"
  ignore(@fs.mkdir(dir, permission=0o755, recursive=true) catch { _ => () })
  dir
}

///|
/// Two calls with the same base (the shape a same-millisecond conversion
/// produces) must not share a path, and each must keep its own payload.
async test "create_unique_file never reuses a path" {
  let dir = tempfile_test_dir()
  let base = dir + "/same-ms-" + @async.now().to_string()
  let first = create_unique_file(base, ".txt", b"one")
  let second = create_unique_file(base, ".txt", b"two")
  assert_eq(first, base + ".txt")
  assert_eq(second, base + "-1.txt")
  assert_eq(@fs.read_file(first).text(), "one")
  assert_eq(@fs.read_file(second).text(), "two")
  ignore(@fs.remove(first) catch { _ => () })
  ignore(@fs.remove(second) catch { _ => () })
}

///|
/// The reserved name must exist so a helper process cannot pick it, and the
/// empty reservation must not be mistaken for a peer's written payload.
async test "reserve_unique_path claims distinct empty files" {
  let dir = tempfile_test_dir()
  let base = dir + "/reserved-" + @async.now().to_string()
  let first = reserve_unique_path(base, ".json")
  let second = reserve_unique_path(base, ".json")
  assert_eq(first, base + ".json")
  assert_eq(second, base + "-1.json")
  assert_true(@fs.exists(first))
  assert_true(@fs.exists(second))
  assert_eq(@fs.read_file(first).text(), "")
  assert_eq(@fs.read_file(second).text(), "")
  ignore(@fs.remove(first) catch { _ => () })
  ignore(@fs.remove(second) catch { _ => () })
}
