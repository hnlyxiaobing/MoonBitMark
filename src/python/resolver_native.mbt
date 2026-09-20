// Native implementation of Python interpreter resolution.
//
// Resolution walks a fixed priority order and returns the first candidate
// that passes validation (running `--version` successfully and reporting a
// version >= 3.8):
//
// 1. `MOONBITMARK_PYTHON` (explicit override; if set but invalid, fail fast
//    with no fallback so configuration errors surface immediately).
// 2. Activated virtual environments: `VIRTUAL_ENV` / `CONDA_PREFIX`.
// 3. PATH directories containing a real interpreter file, skipping pyenv-win
//    shims directories (their shims cannot be spawned via CreateProcessW).
// 4. The Pylauncher `py.exe` (invoked with a leading `-3` argument).
// 5. pyenv versions directories probed directly, highest version first.
//
// The result (including failure) is cached process-wide: resolution spawns
// child processes for validation and must not repeat per conversion.

///|
/// Process-wide cache: outer `None` = not resolved yet, `Some(result)` holds
/// the resolution result (which may itself be `None` for "no interpreter").
let resolve_cache : Ref[(String, Array[String])??] = { val: None, }

///|
/// Resolve a usable Python interpreter. On success returns the program path
/// plus arguments that must precede the script (e.g. `["-3"]` for the
/// Pylauncher). Returns `None` when no candidate passes validation.
pub async fn resolve_python() -> (String, Array[String])? {
  match resolve_cache.val {
    Some(result) => result
    None => {
      let result = resolve_python_uncached()
      resolve_cache.val = Some(result)
      result
    }
  }
}

///|
async fn resolve_python_uncached() -> (String, Array[String])? {
  // 1. Explicit override: fail fast when set but unusable, no fallback.
  match @env.get_env_var("MOONBITMARK_PYTHON") {
    Some(configured) => {
      let program = configured.trim().to_owned()
      if program != "" {
        return if validate_interpreter(program, []) {
          Some((program, []))
        } else {
          None
        }
      }
    }
    None => ()
  }
  // 2. Activated virtual environments (bridge dependencies such as pdfminer
  //    are typically installed there, so these outrank the system PATH).
  let venv_candidates : Array[String] = []
  for env_name in ["VIRTUAL_ENV", "CONDA_PREFIX"] {
    match @env.get_env_var(env_name) {
      Some(root) => {
        let root = root.trim().to_owned()
        if root != "" {
          venv_candidates.push(root + "/Scripts/python.exe")
          venv_candidates.push(root + "/bin/python3")
          venv_candidates.push(root + "/bin/python")
        }
      }
      None => ()
    }
  }
  match probe_candidates(venv_candidates) {
    Some(result) => return Some(result)
    None => ()
  }
  // 3. PATH scan for real interpreter files, skipping pyenv shims dirs.
  match @env.get_env_var("PATH") {
    Some(path_var) =>
      for dir in split_search_path(path_var) {
        if is_shim_directory(dir) {
          continue
        }
        let candidates : Array[String] = []
        for name in ["python.exe", "python3.exe", "python3", "python"] {
          candidates.push(dir + "/" + name)
        }
        match probe_candidates(candidates) {
          Some(result) => return Some(result)
          None => ()
        }
      }
    None => ()
  }
  // 4. Pylauncher.
  if validate_interpreter("py.exe", ["-3"]) {
    return Some(("py.exe", ["-3"]))
  }
  // 5. pyenv versions directories, highest version first.
  let pyenv_roots : Array[String] = []
  match @env.get_env_var("PYENV_ROOT") {
    Some(root) => {
      let root = root.trim().to_owned()
      if root != "" {
        pyenv_roots.push(root)
      }
    }
    None => ()
  }
  match @env.get_env_var("USERPROFILE") {
    Some(home) => pyenv_roots.push(home + "/.pyenv/pyenv-win")
    None => ()
  }
  match @env.get_env_var("HOME") {
    Some(home) => pyenv_roots.push(home + "/.pyenv")
    None => ()
  }
  for root in pyenv_roots {
    match probe_pyenv_versions(root) {
      Some(result) => return Some(result)
      None => ()
    }
  }
  None
}

///|
/// Return the first candidate that exists on disk and passes validation.
async fn probe_candidates(
  candidates : Array[String],
) -> (String, Array[String])? {
  for candidate in candidates {
    if file_exists(candidate) && validate_interpreter(candidate, []) {
      return Some((candidate, []))
    }
  }
  None
}

///|
/// Probe `<root>/versions/*` for installed interpreters, trying the highest
/// version first.
async fn probe_pyenv_versions(root : String) -> (String, Array[String])? {
  let versions_dir = root + "/versions"
  let entries = @fs.readdir(
    versions_dir,
    include_hidden=true,
    include_special=false,
    sort=false,
  ) catch {
    _ => return None
  }
  let candidates : Array[(String, PyVersion)] = []
  for entry in entries {
    match parse_version(entry) {
      Some(version) => {
        let base = versions_dir + "/" + entry
        for name in ["python.exe", "bin/python3", "bin/python"] {
          let program = base + "/" + name
          if file_exists(program) {
            candidates.push((program, version))
            break
          }
        }
      }
      None => ()
    }
  }
  for program in sort_by_version_desc(candidates) {
    if validate_interpreter(program, []) {
      return Some((program, []))
    }
  }
  None
}

///|
/// A directory is a pyenv-win shims directory when its listing matches the
/// shim markers; unreadable directories are not treated as shims.
async fn is_shim_directory(dir : String) -> Bool {
  let entries = @fs.readdir(
    dir,
    include_hidden=true,
    include_special=false,
    sort=false,
  ) catch {
    _ => return false
  }
  is_pyenv_shim_dir(entries)
}

///|
async fn file_exists(path : String) -> Bool {
  @fs.exists(path) catch {
    _ => false
  }
}

///|
/// Validate a candidate by running `<program> <prefix_args...> --version`:
/// it must exit 0 and print a parseable version >= 3.8. Python historically
/// prints the version on stderr, so both streams are considered.
async fn validate_interpreter(
  program : String,
  prefix_args : Array[String],
) -> Bool {
  let args = prefix_args.copy()
  args.push("--version")
  try {
    let (exit_code, stdout, stderr) = @process.collect_output(
      program,
      args,
      no_console_window=true,
    )
    if exit_code != 0 {
      return false
    }
    let stdout_text = stdout.text() catch { _ => "" }
    let output = if stdout_text.trim() != "" {
      stdout_text
    } else {
      stderr.text() catch {
        _ => ""
      }
    }
    match parse_version(output) {
      Some(version) => is_supported_version(version)
      None => false
    }
  } catch {
    _ => false
  }
}
