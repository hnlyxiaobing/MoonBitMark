// Native-only tests for PATH-based executable probe resolution.

///|
async fn write_probe_exe(path : String) -> Unit {
  let file = @fs.open(path, mode=WriteOnly, create_mode=@fs.CreateOrTruncate)
  file.write(b"x")
  file.close()
}

///|
fn restore_path_env(old_path : String?) -> Unit {
  match old_path {
    Some(value) => @env.set_env_var("PATH", value)
    None => @env.unset_env_var("PATH")
  }
}

///|
test "has_path_separator detects both separators" {
  assert_true(has_path_separator("a/b"))
  assert_true(has_path_separator("a\\b"))
  assert_true(has_path_separator("/abs"))
  assert_true(has_path_separator("C:\\bin"))
  assert_true(!has_path_separator("moonbitmark"))
  assert_true(!has_path_separator(""))
}

///|
test "exe_name_candidates appends .exe only when missing" {
  assert_eq(exe_name_candidates("C:/bin", "moonbitmark"), [
    "C:/bin/moonbitmark", "C:/bin/moonbitmark.exe",
  ])
  assert_eq(exe_name_candidates("C:/bin", "moonbitmark.exe"), [
    "C:/bin/moonbitmark.exe",
  ])
  assert_eq(exe_name_candidates("C:/bin", "MOONBITMARK.EXE"), [
    "C:/bin/MOONBITMARK.EXE",
  ])
}

///|
async test "resolve_probe_base keeps paths that already carry a directory" {
  assert_eq(
    resolve_probe_base("C:/repo/_build/main.exe"),
    Some("C:/repo/_build/main.exe"),
  )
  assert_eq(resolve_probe_base("a/b/main"), Some("a/b/main"))
}

///|
async test "resolve_probe_base locates a bare name via PATH" {
  let old_path = @env.get_env_var("PATH")
  let dir = "_build/test-tmp/probe-bin"
  ignore(@fs.mkdir(dir, permission=0o755, recursive=true) catch { _ => () })
  let exe = dir + "/moonbitmark-probe-test.exe"
  write_probe_exe(exe)
  @env.set_env_var("PATH", dir)
  let resolved = resolve_probe_base("moonbitmark-probe-test")
  restore_path_env(old_path)
  ignore(@fs.remove(exe) catch { _ => () })
  assert_eq(resolved, Some(exe))
}

///|
async test "resolve_probe_base returns None when the bare name is not on PATH" {
  let old_path = @env.get_env_var("PATH")
  @env.set_env_var("PATH", "_build/test-tmp/definitely-missing-bin")
  let resolved = resolve_probe_base("moonbitmark-probe-missing")
  restore_path_env(old_path)
  assert_eq(resolved, None)
}
