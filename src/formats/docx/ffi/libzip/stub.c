// MoonBit FFI Stubs for libzip and expat
// This file provides the C implementation for MoonBit FFI bindings

#include <moonbit.h>
#include <stdlib.h>
#include <string.h>

// ============================================================================
// libzip bindings
// ============================================================================

#ifdef HAS_LIBZIP

#include <zip.h>

// Open ZIP archive from memory buffer
MOONBIT_FFI_EXPORT
void *moonbit_zip_open_from_buffer(moonbit_bytes_t buffer, int32_t len, int32_t flags) {
  // Create zip source from memory
  zip_source_t *source = zip_source_buffer_create(buffer, len, 0, NULL);
  if (source == NULL) {
    return NULL;
  }
  
  // Open archive
  zip_t *archive = zip_open_from_source(source, ZIP_RDONLY, NULL);
  if (archive == NULL) {
    zip_source_free(source);
    return NULL;
  }
  
  return archive;
}

// Close ZIP archive
MOONBIT_FFI_EXPORT
void moonbit_zip_close(void *archive) {
  if (archive != NULL) {
    zip_close((zip_t *)archive);
  }
}

// Get number of entries
MOONBIT_FFI_EXPORT
int32_t moonbit_zip_get_num_entries(void *archive, int32_t flags) {
  if (archive == NULL) {
    return 0;
  }
  return (int32_t)zip_get_num_entries((zip_t *)archive, (zip_flags_t)flags);
}

// Open file within archive
MOONBIT_FFI_EXPORT
void *moonbit_zip_fopen(void *archive, moonbit_bytes_t name) {
  if (archive == NULL || name == NULL) {
    return NULL;
  }
  
  zip_file_t *file = zip_fopen((zip_t *)archive, (const char *)name, 0);
  return file;
}

// Read from open file
MOONBIT_FFI_EXPORT
int32_t moonbit_zip_fread(void *file, moonbit_bytes_t buffer, int32_t len) {
  if (file == NULL || buffer == NULL) {
    return -1;
  }
  
  zip_int64_t bytes_read = zip_fread((zip_file_t *)file, buffer, (zip_uint64_t)len);
  return (int32_t)bytes_read;
}

// Close open file
MOONBIT_FFI_EXPORT
int32_t moonbit_zip_fclose(void *file) {
  if (file == NULL) {
    return -1;
  }
  
  int result = zip_fclose((zip_file_t *)file);
  return result;
}

// Get file statistics
MOONBIT_FFI_EXPORT
int32_t moonbit_zip_stat(void *archive, moonbit_bytes_t name, int32_t flags, void *stat_out) {
  if (archive == NULL || name == NULL || stat_out == NULL) {
    return -1;
  }
  
  struct zip_stat stat_buf;
  zip_stat_init(&stat_buf);
  
  int result = zip_stat((zip_t *)archive, (const char *)name, (zip_flags_t)flags, &stat_buf);
  
  if (result == 0) {
    // Copy statistics to output structure
    // Note: This is a simplified version - full implementation would copy all fields
    ((int32_t *)stat_out)[1] = (int32_t)stat_buf.size;  // size field
  }
  
  return result;
}

#else

// Stub implementations when libzip is not available
MOONBIT_FFI_EXPORT
void *moonbit_zip_open_from_buffer(moonbit_bytes_t buffer, int32_t len, int32_t flags) {
  return NULL;
}

MOONBIT_FFI_EXPORT
void moonbit_zip_close(void *archive) {}

MOONBIT_FFI_EXPORT
int32_t moonbit_zip_get_num_entries(void *archive, int32_t flags) {
  return 0;
}

MOONBIT_FFI_EXPORT
void *moonbit_zip_fopen(void *archive, moonbit_bytes_t name) {
  return NULL;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_zip_fread(void *file, moonbit_bytes_t buffer, int32_t len) {
  return -1;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_zip_fclose(void *file) {
  return -1;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_zip_stat(void *archive, moonbit_bytes_t name, int32_t flags, void *stat_out) {
  return -1;
}

#endif

// ============================================================================
// expat bindings
// ============================================================================

#ifdef HAS_EXPAT

#include <expat.h>

// Create XML parser
MOONBIT_FFI_EXPORT
void *moonbit_xml_parser_create(moonbit_bytes_t encoding) {
  const XML_Char *enc = (encoding != NULL) ? (const XML_Char *)encoding : NULL;
  XML_Parser parser = XML_ParserCreate(enc);
  return parser;
}

// Free XML parser
MOONBIT_FFI_EXPORT
void moonbit_xml_parser_free(void *parser) {
  if (parser != NULL) {
    XML_ParserFree((XML_Parser)parser);
  }
}

// Parse XML data
MOONBIT_FFI_EXPORT
int32_t moonbit_xml_parse(void *parser, moonbit_bytes_t data, int32_t len, int32_t is_final) {
  if (parser == NULL || data == NULL) {
    return 0;  // XML_STATUS_ERROR
  }
  
  enum XML_Status status = XML_Parse(
    (XML_Parser)parser,
    (const char *)data,
    len,
    is_final
  );
  
  return (int32_t)status;
}

// Get error code
MOONBIT_FFI_EXPORT
int32_t moonbit_xml_get_error_code(void *parser) {
  if (parser == NULL) {
    return XML_ERROR_NONE;
  }
  
  return (int32_t)XML_GetErrorCode((XML_Parser)parser);
}

// Get error string
MOONBIT_FFI_EXPORT
moonbit_bytes_t moonbit_xml_error_string(int32_t code) {
  const XML_LChar *error_str = XML_ErrorString((enum XML_Error)code);
  
  if (error_str == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  
  int32_t len = (int32_t)strlen(error_str);
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  memcpy(bytes, error_str, len);
  return bytes;
}

// Get current line number
MOONBIT_FFI_EXPORT
int32_t moonbit_xml_get_current_line_number(void *parser) {
  if (parser == NULL) {
    return 0;
  }
  
  return (int32_t)XML_GetCurrentLineNumber((XML_Parser)parser);
}

// Set element handler
MOONBIT_FFI_EXPORT
void moonbit_xml_set_element_handler(void *parser, int32_t start_handler, int32_t end_handler) {
  if (parser == NULL) {
    return;
  }
  
  // Note: Full implementation would set up callback trampolines
  // This is a simplified version
  XML_SetElementHandler(
    (XML_Parser)parser,
    (XML_StartElementHandler)start_handler,
    (XML_EndElementHandler)end_handler
  );
}

// Set character data handler
MOONBIT_FFI_EXPORT
void moonbit_xml_set_character_data_handler(void *parser, int32_t handler) {
  if (parser == NULL) {
    return;
  }
  
  // Note: Full implementation would set up callback trampoline
  XML_SetCharacterDataHandler(
    (XML_Parser)parser,
    (XML_CharacterDataHandler)handler
  );
}

#else

// Stub implementations when expat is not available
MOONBIT_FFI_EXPORT
void *moonbit_xml_parser_create(moonbit_bytes_t encoding) {
  return NULL;
}

MOONBIT_FFI_EXPORT
void moonbit_xml_parser_free(void *parser) {}

MOONBIT_FFI_EXPORT
int32_t moonbit_xml_parse(void *parser, moonbit_bytes_t data, int32_t len, int32_t is_final) {
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_xml_get_error_code(void *parser) {
  return 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moonbit_xml_error_string(int32_t code) {
  return moonbit_make_bytes(0, 0);
}

MOONBIT_FFI_EXPORT
int32_t moonbit_xml_get_current_line_number(void *parser) {
  return 0;
}

MOONBIT_FFI_EXPORT
void moonbit_xml_set_element_handler(void *parser, int32_t start_handler, int32_t end_handler) {}

MOONBIT_FFI_EXPORT
void moonbit_xml_set_character_data_handler(void *parser, int32_t handler) {}

#endif

// ============================================================================
// End of FFI stubs
// ============================================================================
