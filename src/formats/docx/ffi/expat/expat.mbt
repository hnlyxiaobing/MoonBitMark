// expat FFI Bindings
// XML parser library for DOCX conversion

priv type XML_Parser

// ============================================================================
// DOCX Conversion
// ============================================================================

///|
/// Convert DOCX file to Markdown
extern "c" fn moonbit_convert_docx_file(file_path : Bytes, file_path_len : Int) -> Bytes? = "moonbit_convert_docx_file"

// ============================================================================
// Safe wrappers
// ============================================================================

///|
/// Convert DOCX file path to Markdown
pub fn convert_docx_file(file_path : String) -> String {
  let path_bytes = @utf8.encode(file_path)
  let result = moonbit_convert_docx_file(path_bytes, path_bytes.length())
  match result {
    Some(bytes) => @utf8.decode_lossy(bytes)
    None => ""
  }
}
