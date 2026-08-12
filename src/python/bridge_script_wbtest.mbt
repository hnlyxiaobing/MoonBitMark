///|
test "parent_dir strips the last component" {
  assert_eq(parent_dir("a/b/c"), Some("a/b"))
  assert_eq(parent_dir("a/b"), Some("a"))
  assert_eq(parent_dir("a/b/"), Some("a"))
  assert_eq(parent_dir("C:\\repo\\_build\\main.exe"), Some("C:/repo/_build"))
}

///|
test "parent_dir has no parent for bare names and roots" {
  assert_eq(parent_dir("main.exe"), None)
  assert_eq(parent_dir("a"), None)
  assert_eq(parent_dir("/"), None)
  assert_eq(parent_dir("C:"), None)
  assert_eq(parent_dir("C:/"), None)
  assert_eq(parent_dir("C:\\"), None)
}

///|
test "exe_probe_candidates walks up from the executable directory" {
  let candidates = exe_probe_candidates(
    "D:/repo/_build/native/release/main.exe", "scripts/ocr/bridge.py", 6,
  )
  assert_eq(candidates, [
    "D:/repo/_build/native/release/scripts/ocr/bridge.py", "D:/repo/_build/native/scripts/ocr/bridge.py",
    "D:/repo/_build/scripts/ocr/bridge.py", "D:/repo/scripts/ocr/bridge.py", "D:/scripts/ocr/bridge.py",
  ])
}

///|
test "exe_probe_candidates stops at the level cap and at bare names" {
  assert_eq(exe_probe_candidates("a/b/c/d/main.exe", "s/x.py", 2), [
    "a/b/c/d/s/x.py", "a/b/c/s/x.py",
  ])
  assert_eq(exe_probe_candidates("main.exe", "s/x.py", 6), [])
}

///|
test "bridge_script_diagnostic explains each failure mode" {
  let missing = bridge_script_diagnostic(
    EnvOverrideMissing(
      path="C:/nope/bridge.py",
      env_var="MOONBITMARK_OCR_BRIDGE",
    ),
  )
  assert_true(missing.contains("bridge script not found: C:/nope/bridge.py"))
  assert_true(missing.contains("MOONBITMARK_OCR_BRIDGE"))
  let not_found = bridge_script_diagnostic(
    NotFound(
      relative_path="scripts/ocr/bridge.py",
      env_var="MOONBITMARK_OCR_BRIDGE",
    ),
  )
  assert_true(
    not_found.contains("bridge script not found: scripts/ocr/bridge.py"),
  )
  assert_true(not_found.contains("MOONBITMARK_OCR_BRIDGE"))
  assert_eq(
    bridge_script_diagnostic(Found(path="x", source=WorkingDirectory)),
    "",
  )
}
