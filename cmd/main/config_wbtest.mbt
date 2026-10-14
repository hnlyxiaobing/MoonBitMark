// Whitebox tests for default-output configuration and path derivation.

///|
fn restore_cli_env(name : String, old_value : String?) -> Unit {
  match old_value {
    Some(value) => @env.set_env_var(name, value)
    None => @env.unset_env_var(name)
  }
}

///|
test "out_dir_from_config parses a string out_dir" {
  assert_eq(
    out_dir_from_config("{\"out_dir\": \"D:/docs/md\"}", "cfg"),
    Some("D:/docs/md"),
  )
  assert_eq(
    out_dir_from_config("{\"out_dir\": \"  spaced  \"}", "cfg"),
    Some("spaced"),
  )
}

///|
test "out_dir_from_config treats missing or empty out_dir as disabled" {
  assert_eq(out_dir_from_config("{}", "cfg"), None)
  assert_eq(out_dir_from_config("{\"out_dir\": \"\"}", "cfg"), None)
  assert_eq(out_dir_from_config("{\"out_dir\": \"  \"}", "cfg"), None)
  assert_eq(out_dir_from_config("{\"other\": 1}", "cfg"), None)
}

///|
test "out_dir_from_config tolerates a leading BOM" {
  assert_eq(
    out_dir_from_config("\u{FEFF}{\"out_dir\": \"D:/md\"}", "cfg"),
    Some("D:/md"),
  )
}

///|
test "out_dir_from_config rejects invalid JSON and non-string out_dir" {
  let bad_json = try {
    ignore(out_dir_from_config("{oops", "cfg"))
    false
  } catch {
    _ => true
  }
  assert_true(bad_json)
  let bad_type = try {
    ignore(out_dir_from_config("{\"out_dir\": 3}", "cfg"))
    false
  } catch {
    _ => true
  }
  assert_true(bad_type)
}

///|
async test "load_default_out_dir prefers the env var" {
  let old_env = @env.get_env_var("MOONBITMARK_OUT_DIR")
  @env.set_env_var("MOONBITMARK_OUT_DIR", "D:/from-env")
  let resolved = load_default_out_dir()
  restore_cli_env("MOONBITMARK_OUT_DIR", old_env)
  assert_eq(resolved, Some("D:/from-env"))
}

///|
async test "load_default_out_dir ignores an empty env var value" {
  let old_env = @env.get_env_var("MOONBITMARK_OUT_DIR")
  @env.set_env_var("MOONBITMARK_OUT_DIR", "")
  let resolved = load_default_out_dir()
  restore_cli_env("MOONBITMARK_OUT_DIR", old_env)
  // The config-file tier may still supply a directory on this machine; the
  // env tier must not produce an empty directory.
  assert_true(resolved != Some(""))
}

///|
test "derive_output_path maps inputs to out_dir basename.md" {
  assert_eq(
    derive_output_path("C:/docs/report.docx", "D:/md"),
    "D:/md/report.md",
  )
  assert_eq(derive_output_path("report.docx", "D:/md/"), "D:/md/report.md")
  assert_eq(derive_output_path("a.b.c.pdf", "D:/md"), "D:/md/a.b.c.md")
  assert_eq(
    derive_output_path("C:\\docs\\notes.html", "D:/md"),
    "D:/md/notes.md",
  )
  assert_eq(
    derive_output_path("https://x.com/a/page.html?q=1", "D:/md"),
    "D:/md/page.md",
  )
  assert_eq(derive_output_path("https://x.com/", "D:/md"), "D:/md/index.md")
  assert_eq(derive_output_path("report.docx", ""), "report.md")
}

///|
test "derive_output_basename sanitizes illegal characters" {
  assert_eq(derive_output_basename("we:ird?.docx"), "we_ird_")
  assert_eq(derive_output_basename("name with spaces.txt"), "name with spaces")
  assert_eq(derive_output_basename(".hidden"), ".hidden")
  assert_eq(derive_output_basename(""), "output")
  assert_eq(derive_output_basename("   "), "output")
}

///|
test "default_config_path joins home and relative config path" {
  assert_eq(
    default_config_path("C:\\Users\\demo"),
    "C:/Users/demo/.moonbitmark/config.json",
  )
  assert_eq(
    default_config_path("/home/demo"),
    "/home/demo/.moonbitmark/config.json",
  )
}
