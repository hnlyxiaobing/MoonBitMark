// Python interpreter resolution, shared across targets.
//
// `moonbitlang/async` on Windows appends `.exe` to a bare program name and
// calls CreateProcessW directly, without PATHEXT matching, so spawning
// `"python"` fails on pyenv-win setups where the shims directory only
// contains an extensionless shim plus `python.bat`. This package resolves the
// real interpreter up front (native target) so callers can spawn an absolute
// `python.exe` path instead.
//
// This file holds the target-independent pure logic (version parsing and
// comparison, shim directory detection, search path splitting); the probing
// itself lives in `resolver_native.mbt` / `resolver_stub.mbt`.

///|
/// A parsed `major.minor.patch` version. Missing components default to 0.
pub struct PyVersion {
  major : Int
  minor : Int
  patch : Int
}

///|
/// The minimum interpreter version accepted by the bridges.
let min_supported_version : PyVersion = PyVersion::{
  major: 3,
  minor: 8,
  patch: 0,
}

///|
/// Diagnostic shared by all call sites when no interpreter can be resolved.
pub fn python_not_found_diagnostic() -> String {
  "未找到可用的 Python 解释器，请安装 Python ≥3.8 或设置 MOONBITMARK_PYTHON (no usable Python interpreter found; install Python >= 3.8 or set MOONBITMARK_PYTHON to a valid interpreter path)"
}

///|
/// Parse a version out of free-form text such as `Python 3.12.9` (the output
/// of `python --version`) or a pyenv versions directory name like `3.12.9`.
/// Scanning starts at the first ASCII digit and stops at the first character
/// that is neither a digit nor a dot. Returns `None` when no digits are found.
pub fn parse_version(text : String) -> PyVersion? {
  let chars = text.to_array()
  let mut index = 0
  while index < chars.length() && !chars[index].is_ascii_digit() {
    index = index + 1
  }
  if index >= chars.length() {
    return None
  }
  let parts : Array[Int] = []
  let mut value = 0
  let mut has_digit = false
  while index < chars.length() {
    let ch = chars[index]
    if ch.is_ascii_digit() {
      value = value * 10 + (ch.to_int() - '0'.to_int())
      has_digit = true
      index = index + 1
    } else if ch == '.' && has_digit {
      parts.push(value)
      value = 0
      has_digit = false
      index = index + 1
    } else {
      break
    }
  }
  if has_digit {
    parts.push(value)
  }
  if parts.length() == 0 {
    return None
  }
  Some(PyVersion::{
    major: parts[0],
    minor: if parts.length() > 1 {
      parts[1]
    } else {
      0
    },
    patch: if parts.length() > 2 {
      parts[2]
    } else {
      0
    },
  })
}

///|
/// Compare two versions by major, then minor, then patch. Returns a negative
/// number, zero, or a positive number like other comparison primitives.
pub fn compare_version(a : PyVersion, b : PyVersion) -> Int {
  if a.major != b.major {
    return a.major - b.major
  }
  if a.minor != b.minor {
    return a.minor - b.minor
  }
  a.patch - b.patch
}

///|
/// Whether a parsed version satisfies the bridges' `>= 3.8` requirement.
pub fn is_supported_version(version : PyVersion) -> Bool {
  compare_version(version, min_supported_version) >= 0
}

///|
/// Order `(path, version)` candidates by version, highest first, returning
/// only the paths. Used by the pyenv versions fallback, which prefers the
/// highest installed version.
pub fn sort_by_version_desc(
  candidates : Array[(String, PyVersion)],
) -> Array[String] {
  let sorted = candidates.copy()
  sorted.sort_by(fn(a, b) { compare_version(b.1, a.1) })
  sorted.map(fn(candidate) { candidate.0 })
}

///|
/// Detect a pyenv-win shims directory from its listing. Markers: a `pyenv` /
/// `pyenv.bat` entry, or the shim pair of an extensionless `python` plus
/// `python.bat`. A plain POSIX `bin` directory containing only extensionless
/// `python`/`python3` binaries is NOT treated as a shims directory.
pub fn is_pyenv_shim_dir(entries : Array[String]) -> Bool {
  let mut has_pyenv = false
  let mut has_bare_python = false
  let mut has_python_bat = false
  for entry in entries {
    let lower = entry.to_lower()
    if lower == "pyenv" || lower == "pyenv.bat" {
      has_pyenv = true
    }
    if lower == "python" {
      has_bare_python = true
    }
    if lower == "python.bat" {
      has_python_bat = true
    }
  }
  has_pyenv || (has_bare_python && has_python_bat)
}

///|
/// Split a PATH-style search path into entries. Windows uses `;`, POSIX uses
/// `:`; the separator is chosen by presence of `;` (Windows drive letters
/// contain `:` but never `;`). Empty and whitespace-only entries are dropped.
pub fn split_search_path(value : String) -> Array[String] {
  let separator = if value.contains(";") { ';' } else { ':' }
  let entries : Array[String] = []
  let mut current = ""
  for ch in value {
    if ch == separator {
      push_search_entry(entries, current)
      current = ""
    } else {
      current = current + ch.to_string()
    }
  }
  push_search_entry(entries, current)
  entries
}

///|
fn push_search_entry(entries : Array[String], entry : String) -> Unit {
  let trimmed = entry.trim().to_owned()
  if trimmed != "" {
    entries.push(trimmed)
  }
}
