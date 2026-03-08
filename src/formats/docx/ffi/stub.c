// MoonBit FFI Stubs for libzip and expat
// This file provides the C implementation for MoonBit FFI bindings

#include <moonbit.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#pragma comment(lib, "C:/vcpkg/installed/x64-windows/lib/zip.lib")
#pragma comment(lib, "C:/vcpkg/installed/x64-windows/lib/libexpat.lib")

#include <zip.h>
#include <expat.h>

// ============================================================================
// libzip bindings
// ============================================================================

// Open ZIP archive from memory buffer
MOONBIT_FFI_EXPORT
void *moonbit_zip_open_from_buffer(moonbit_bytes_t buffer, int32_t len, int32_t flags) {
  zip_source_t *source = zip_source_buffer_create(buffer, len, 0, NULL);
  if (source == NULL) {
    return NULL;
  }
  
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

// Read entire file from ZIP archive and return as Bytes
MOONBIT_FFI_EXPORT
moonbit_bytes_t moonbit_zip_read_file(void *archive, moonbit_bytes_t name) {
  if (archive == NULL || name == NULL) {
    return NULL;
  }
  
  zip_file_t *file = zip_fopen((zip_t *)archive, (const char *)name, 0);
  if (file == NULL) {
    return NULL;
  }
  
  struct zip_stat stat_buf;
  zip_stat_init(&stat_buf);
  if (zip_stat((zip_t *)archive, (const char *)name, 0, &stat_buf) != 0) {
    zip_fclose(file);
    zip_close((zip_t *)archive);
    return NULL;
  }
  
  moonbit_bytes_t buffer = moonbit_make_bytes(stat_buf.size, 0);
  if (buffer == NULL) {
    zip_fclose(file);
    zip_close((zip_t *)archive);
    return NULL;
  }
  
  zip_int64_t bytes_read = zip_fread(file, buffer, stat_buf.size);
  zip_fclose(file);
  zip_close((zip_t *)archive);
  
  if (bytes_read < 0 || bytes_read != (zip_int64_t)stat_buf.size) {
    return NULL;
  }
  
  return buffer;
}

// ============================================================================
// expat bindings - DOCX XML Parser
// ============================================================================

typedef struct {
  moonbit_bytes_t output;
  int32_t output_len;
  int32_t output_capacity;
  int in_text;
  int in_paragraph;
  int in_heading;
  int heading_level;
  int in_list;
  char current_text[4096];
  int32_t current_text_len;
} DocxParserContext;

static void XMLCALL docx_start_element(void *userData, const XML_Char *name, const XML_Char **atts) {
  DocxParserContext *ctx = (DocxParserContext *)userData;
  
  // Debug output
  // fprintf(stderr, "Start element: %s\n", name);
  
  // Check both with and without namespace prefix
  const XML_Char *local_name = name;
  const XML_Char *colon = strchr(name, ':');
  if (colon) local_name = colon + 1;
  
  // Match any element ending with :t or just "t" (text element)
  if (strcmp(local_name, "t") == 0) {
    ctx->in_text = 1;
  }
  
  if (strcmp(local_name, "p") == 0) {
    ctx->in_paragraph = 1;
    ctx->heading_level = 0;
    ctx->in_list = 0;
    
    for (int i = 0; atts[i]; i += 2) {
      const XML_Char *attr_name = atts[i];
      const XML_Char *attr_colon = strchr(attr_name, ':');
      if (attr_colon) attr_name = attr_colon + 1;
      
      if (strcmp(attr_name, "val") == 0 && atts[i+1]) {
        const char *style = atts[i+1];
        if (strncmp(style, "Heading", 7) == 0) {
          ctx->in_heading = 1;
          ctx->heading_level = style[7] - '0';
          if (ctx->heading_level < 1 || ctx->heading_level > 9) ctx->heading_level = 1;
        } else if (strncmp(style, "List", 4) == 0) {
          ctx->in_list = 1;
        }
      }
    }
  }
  
  if (strcmp(local_name, "br") == 0 && ctx->current_text_len > 0 && ctx->current_text_len < 4095) {
    ctx->current_text[ctx->current_text_len++] = '\n';
  }
}

static void XMLCALL docx_end_element(void *userData, const XML_Char *name) {
  DocxParserContext *ctx = (DocxParserContext *)userData;
  
  const XML_Char *local_name = name;
  const XML_Char *colon = strchr(name, ':');
  if (colon) local_name = colon + 1;
  
  if (strcmp(local_name, "t") == 0 || strcmp(local_name, "tab") == 0) {
    ctx->in_text = 0;
  }
  
  if (strcmp(local_name, "p") == 0) {
    ctx->in_paragraph = 0;
    ctx->in_heading = 0;
    ctx->heading_level = 0;
    ctx->in_list = 0;
    
    if (ctx->current_text_len > 0) {
      ctx->current_text[ctx->current_text_len] = '\0';
      
      if (ctx->heading_level > 0) {
        for (int i = 0; i < ctx->heading_level && ctx->output_len < ctx->output_capacity - 1; i++) {
          ctx->output[ctx->output_len++] = '#';
        }
        if (ctx->output_len < ctx->output_capacity - 1) ctx->output[ctx->output_len++] = ' ';
      }
      
      if (ctx->in_list && ctx->output_len < ctx->output_capacity - 2) {
        ctx->output[ctx->output_len++] = '-';
        ctx->output[ctx->output_len++] = ' ';
      }
      
      for (int i = 0; i < ctx->current_text_len && ctx->output_len < ctx->output_capacity - 1; i++) {
        ctx->output[ctx->output_len++] = ctx->current_text[i];
      }
      
      if (ctx->output_len < ctx->output_capacity - 1) {
        ctx->output[ctx->output_len++] = '\n';
        ctx->output[ctx->output_len++] = '\n';
      }
      
      ctx->current_text_len = 0;
    }
  }
}

static void XMLCALL docx_char_data(void *userData, const XML_Char *s, int len) {
  DocxParserContext *ctx = (DocxParserContext *)userData;
  
  if (ctx->in_text && ctx->in_paragraph) {
    for (int i = 0; i < len && ctx->current_text_len < 4095; i++) {
      char c = (char)s[i];
      if (c != '\0') ctx->current_text[ctx->current_text_len++] = c;
    }
  }
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moonbit_xml_extract_text(moonbit_bytes_t data, int32_t len) {
  if (data == NULL || len <= 0) return NULL;
  
  XML_Parser parser = XML_ParserCreate(NULL);
  if (parser == NULL) return NULL;
  
  int32_t capacity = len + 1024;
  moonbit_bytes_t output = moonbit_make_bytes(capacity, 0);
  if (output == NULL) {
    XML_ParserFree(parser);
    return NULL;
  }
  
  DocxParserContext ctx;
  ctx.output = output;
  ctx.output_len = 0;
  ctx.output_capacity = capacity;
  ctx.in_text = 0;
  ctx.in_paragraph = 0;
  ctx.in_heading = 0;
  ctx.heading_level = 0;
  ctx.in_list = 0;
  ctx.current_text_len = 0;
  
  XML_SetUserData(parser, &ctx);
  XML_SetElementHandler(parser, docx_start_element, docx_end_element);
  XML_SetCharacterDataHandler(parser, docx_char_data);
  
  // Use XML_PARSE_UNKNOWN_ENCODING flag if needed
  // Default namespace processing should work
  
  enum XML_Status status = XML_Parse(parser, (const char *)data, len, 1);
  XML_ParserFree(parser);
  
  if (status == XML_STATUS_ERROR) {
    return NULL;
  }
  
  if (ctx.output_len < capacity) output[ctx.output_len] = '\0';
  return output;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moonbit_xml_parse_document(moonbit_bytes_t data, int32_t len) {
  return moonbit_xml_extract_text(data, len);
}

// ============================================================================
// DOCX File Converter - High-level API
// ============================================================================

MOONBIT_FFI_EXPORT
moonbit_bytes_t moonbit_convert_docx_file(moonbit_bytes_t file_path, int32_t file_path_len) {
  // Create null-terminated copy of file path
  char *path_cstr = (char *)malloc(file_path_len + 1);
  if (path_cstr == NULL) return NULL;
  memcpy(path_cstr, file_path, file_path_len);
  path_cstr[file_path_len] = '\0';
  
  fprintf(stderr, "[DOCX] Converting file: %s (len=%d)\n", path_cstr, file_path_len);
  
  if (path_cstr == NULL) {
    fprintf(stderr, "[DOCX] File path is NULL\n");
    free(path_cstr);
    return NULL;
  }
  
  zip_t *archive = zip_open(path_cstr, ZIP_RDONLY, NULL);
  if (archive == NULL) {
    fprintf(stderr, "[DOCX] Failed to open archive\n");
    return NULL;
  }
  fprintf(stderr, "[DOCX] Archive opened successfully\n");
  
  zip_file_t *doc_file = zip_fopen(archive, "word/document.xml", 0);
  if (doc_file == NULL) {
    fprintf(stderr, "[DOCX] Failed to open document.xml\n");
    zip_close(archive);
    return NULL;
  }
  fprintf(stderr, "[DOCX] document.xml opened\n");
  
  struct zip_stat stat_buf;
  zip_stat_init(&stat_buf);
  if (zip_stat(archive, "word/document.xml", 0, &stat_buf) != 0) {
    fprintf(stderr, "[DOCX] Failed to stat document.xml\n");
    zip_fclose(doc_file);
    zip_close(archive);
    return NULL;
  }
  fprintf(stderr, "[DOCX] File size: %lld bytes\n", stat_buf.size);
  
  moonbit_bytes_t xml_data = moonbit_make_bytes(stat_buf.size, 0);
  if (xml_data == NULL) {
    fprintf(stderr, "[DOCX] Failed to allocate buffer\n");
    zip_fclose(doc_file);
    zip_close(archive);
    return NULL;
  }
  
  zip_int64_t bytes_read = zip_fread(doc_file, xml_data, stat_buf.size);
  zip_fclose(doc_file);
  zip_close(archive);
  
  if (bytes_read < 0 || bytes_read != (zip_int64_t)stat_buf.size) {
    fprintf(stderr, "[DOCX] Failed to read file: %lld\n", bytes_read);
    return NULL;
  }
  fprintf(stderr, "[DOCX] Read %lld bytes, parsing XML...\n", bytes_read);
  
  moonbit_bytes_t result = moonbit_xml_extract_text(xml_data, stat_buf.size);
  if (result == NULL) {
    fprintf(stderr, "[DOCX] XML parsing returned NULL\n");
  } else {
    fprintf(stderr, "[DOCX] XML parsing successful\n");
  }
  free(path_cstr);
  return result;
}
