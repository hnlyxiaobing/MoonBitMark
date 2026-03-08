// DOCX Converter - Main Module
// Converts Word documents (.docx) to Markdown

///|
/// Converter for DOCX files
pub(all) struct DocxConverter {
  dummy : Int
}

///|
/// Create a new DOCX converter
pub fn DocxConverter::new() -> DocxConverter {
  DocxConverter::{
    dummy: 0
  }
}

///|
/// Check if this converter accepts the given file
pub fn DocxConverter::accepts(info : @core.StreamInfo) -> Bool {
  match info.extension {
    Some(ext) => {
      let ext_lower = ext.to_lower().to_string()
      ext_lower == ".docx"
    }
    None => false
  }
}

///|
/// Convert a DOCX file to Markdown
pub async fn DocxConverter::convert(file_path : String) -> String raise {
  // Use FFI function to directly convert DOCX file
  let result = @expat.convert_docx_file(file_path)
  
  if result.length() > 0 {
    result.trim().to_string()
  } else {
    fail("No text content found in DOCX")
  }
}
