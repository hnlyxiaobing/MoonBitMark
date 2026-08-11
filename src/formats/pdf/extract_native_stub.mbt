///|
/// Targets without filesystem/process access (wasm, js) cannot run the
/// mbtpdf-based native extraction or the Python bridge; PDF conversion is
/// unavailable there.
async fn extract_pdf_native(file_path : String) -> PdfNativeExtraction {
  ignore(file_path)
  @async.pause()
  abort("PDF extraction is only supported on the native target")
}
