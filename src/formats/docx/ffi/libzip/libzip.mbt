// libzip FFI Bindings
// C library for reading ZIP archives (DOCX files)

///|
/// ZIP archive handle
type ZipHandle

priv type ZipFileHandle

// ============================================================================
// Archive operations
// ============================================================================

///|
/// Open a ZIP archive from memory buffer
extern "c" fn moonbit_zip_open_from_buffer(buffer : Bytes, len : Int, flags : Int) -> ZipHandle? = "moonbit_zip_open_from_buffer"

///|
/// Close a ZIP archive
extern "c" fn moonbit_zip_close(archive : ZipHandle) -> Unit = "moonbit_zip_close"

///|
/// Read entire file from ZIP archive - returns Bytes directly
extern "c" fn moonbit_zip_read_file(archive : ZipHandle, name : Bytes) -> Bytes? = "moonbit_zip_read_file"

// ============================================================================
// Safe wrappers
// ============================================================================

///|
/// Open ZIP archive and check for errors
pub fn ZipHandle::open(buffer : Bytes) -> ZipHandle? {
  moonbit_zip_open_from_buffer(buffer, buffer.length(), 0)
}

///|
/// Read entire file from ZIP archive (simplified)
pub fn read_file_entry(archive : ZipHandle, name : String) -> Bytes? {
  let name_bytes = name.to_bytes()
  moonbit_zip_read_file(archive, name_bytes)
}

///|
/// Close a ZIP archive (wrapper)
pub fn zip_close(archive : ZipHandle) -> Unit {
  moonbit_zip_close(archive)
}
