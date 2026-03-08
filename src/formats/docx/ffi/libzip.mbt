// libzip FFI Bindings
// C library for reading ZIP archives (DOCX files)

///|
/// ZIP archive handle
type ZipHandle

///|
/// ZIP file handle
type ZipFileHandle

///|
/// File statistics
struct ZipStat {
  name : String
  size : Int
  comp_size : Int
  comp_method : Int
}

// ============================================================================
// Archive operations
// ============================================================================

///|
/// Open a ZIP archive from memory buffer
extern "c" fn zip_open_from_buffer(buffer : Bytes, len : Int, flags : Int) -> ZipHandle = "moonbit_zip_open_from_buffer"

///|
/// Close a ZIP archive
extern "c" fn zip_close(archive : ZipHandle) -> Unit = "moonbit_zip_close"

///|
/// Get number of entries in archive
extern "c" fn zip_get_num_entries(archive : ZipHandle, flags : Int) -> Int = "moonbit_zip_get_num_entries"

// ============================================================================
// File operations
// ============================================================================

///|
/// Open a file within the archive
extern "c" fn zip_fopen(archive : ZipHandle, name : Bytes) -> ZipFileHandle = "moonbit_zip_fopen"

///|
/// Read data from an open file
extern "c" fn zip_fread(file : ZipFileHandle, buffer : Bytes, len : Int) -> Int = "moonbit_zip_fread"

///|
/// Close an open file
extern "c" fn zip_fclose(file : ZipFileHandle) -> Int = "moonbit_zip_fclose"

///|
/// Get file statistics
extern "c" fn zip_stat(archive : ZipHandle, name : Bytes, flags : Int, stat : Ref[ZipStat]) -> Int = "moonbit_zip_stat"

// ============================================================================
// Constants
// ============================================================================

///|
/// Flag: do not follow symlinks
pub let ZIP_FL_NOCASE : Int = 1

///|
/// Flag: case insensitive lookup
pub let ZIP_FL_NODIR : Int = 2

///|
/// Error: no error
pub let ZIP_ER_OK : Int = 0

///|
/// Error: no such file
pub let ZIP_ER_NOENT : Int = 1

///|
/// Error: file already exists
pub let ZIP_ER_EXISTS : Int = 2

// ============================================================================
// Safe wrappers
// ============================================================================

///|
/// Open ZIP archive and check for errors
pub fn ZipHandle::open(buffer : Bytes) -> ZipHandle? {
  let handle = zip_open_from_buffer(buffer, buffer.length(), 0)
  if handle != Nil {
    Some(handle)
  } else {
    None
  }
}

///|
/// Read entire file from ZIP archive
pub fn read_file_entry(archive : ZipHandle, name : String) -> Bytes? {
  let name_bytes = name.to_bytes()
  let file = zip_fopen(archive, name_bytes)
  
  if file == Nil {
    None
  } else {
    // Get file size
    let mut stat = ZipStat::{ name: "", size: 0, comp_size: 0, comp_method: 0 }
    let stat_ref = { val: stat }
    zip_stat(archive, name_bytes, 0, stat_ref)
    let file_size = stat_ref.val.size
    
    // Read file content
    let buffer : Bytes = @buffer.T::make(file_size, 0).contents()
    let bytes_read = zip_fread(file, buffer, file_size)
    zip_fclose(file)
    
    if bytes_read > 0 {
      Some(buffer)
    } else {
      None
    }
  }
}
