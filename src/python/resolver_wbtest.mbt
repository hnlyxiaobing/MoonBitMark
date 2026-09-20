///|
/// Test helper: unwrap a parsed version into a comparable tuple.
fn version_tuple(text : String) -> (Int, Int, Int)? {
  match parse_version(text) {
    Some(version) => Some((version.major, version.minor, version.patch))
    None => None
  }
}

///|
test "parse_version parses python --version output" {
  assert_eq(version_tuple("Python 3.12.9"), Some((3, 12, 9)))
  assert_eq(version_tuple("Python 3.8.0"), Some((3, 8, 0)))
  assert_eq(version_tuple("Python 2.7.18"), Some((2, 7, 18)))
}

///|
test "parse_version parses pyenv version directory names" {
  assert_eq(version_tuple("3.12.9"), Some((3, 12, 9)))
  assert_eq(version_tuple("3.13"), Some((3, 13, 0)))
  assert_eq(version_tuple("3.11.0rc1"), Some((3, 11, 0)))
}

///|
test "parse_version rejects text without digits" {
  assert_eq(version_tuple("not a version"), None)
  assert_eq(version_tuple(""), None)
}

///|
test "is_supported_version enforces >= 3.8" {
  assert_true(
    is_supported_version(PyVersion::{ major: 3, minor: 8, patch: 0, }),
  )
  assert_true(
    is_supported_version(PyVersion::{ major: 3, minor: 12, patch: 9, }),
  )
  assert_true(
    is_supported_version(PyVersion::{ major: 4, minor: 0, patch: 0, }),
  )
  assert_false(
    is_supported_version(PyVersion::{ major: 3, minor: 7, patch: 17, }),
  )
  assert_false(
    is_supported_version(PyVersion::{ major: 2, minor: 7, patch: 18, }),
  )
}

///|
test "sort_by_version_desc orders highest version first" {
  let candidates : Array[(String, PyVersion)] = [
    (
      "C:/pyenv/versions/3.8.10/python.exe",
      PyVersion::{ major: 3, minor: 8, patch: 10, },
    ),
    (
      "C:/pyenv/versions/3.12.9/python.exe",
      PyVersion::{ major: 3, minor: 12, patch: 9, },
    ),
    (
      "C:/pyenv/versions/3.11.4/python.exe",
      PyVersion::{ major: 3, minor: 11, patch: 4, },
    ),
  ]
  assert_eq(sort_by_version_desc(candidates), [
    "C:/pyenv/versions/3.12.9/python.exe", "C:/pyenv/versions/3.11.4/python.exe",
    "C:/pyenv/versions/3.8.10/python.exe",
  ])
  assert_eq(sort_by_version_desc([]), [])
}

///|
test "is_pyenv_shim_dir detects pyenv-win shims directories" {
  assert_true(is_pyenv_shim_dir(["python", "python.bat", "pyenv", "pyenv.bat"]))
  assert_true(is_pyenv_shim_dir(["pyenv.bat", "python", "python.bat", "pip"]))
  assert_true(is_pyenv_shim_dir(["pyenv"]))
}

///|
test "is_pyenv_shim_dir does not flag real interpreter directories" {
  // Real Windows installation directory.
  assert_false(is_pyenv_shim_dir(["python.exe", "pythonw.exe", "Lib", "DLLs"]))
  // POSIX bin directory: extensionless binaries alone are not shims.
  assert_false(is_pyenv_shim_dir(["python", "python3", "pip3"]))
  assert_false(is_pyenv_shim_dir([]))
}

///|
test "split_search_path splits on the platform separator" {
  assert_eq(split_search_path("C:\\Windows;C:\\Python313;"), [
    "C:\\Windows", "C:\\Python313",
  ])
  assert_eq(split_search_path("/usr/bin:/bin"), ["/usr/bin", "/bin"])
  assert_eq(split_search_path(""), [])
  assert_eq(split_search_path(" ; ; "), [])
}
