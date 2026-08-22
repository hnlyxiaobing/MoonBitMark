/*
 * Native file-read FFI for MoonBitMark.
 *
 * Why this exists:
 *   moonbitlang/async's @fs.open() requires the statx(2) syscall to obtain
 *   file kind / device id / file id. statx was introduced in Linux 4.11 and is
 *   NOT available on WSL1 (kernel 4.4) or any older kernel, where it returns
 *   ENOSYS ("Function not implemented"). That made every document conversion
 *   fail on such platforms.
 *
 * This module uses plain libc FILE* IO (fopen/fread/fclose), which works on
 * every POSIX platform including WSL1. The MoonBit side selects this
 * implementation only when NOT on Windows; on Windows the async @fs path is
 * kept (CreateFileW handles UTF-8 paths and has no statx dependency).
 */

#ifndef _WIN32

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <moonbit.h>

/* Open a file in binary read mode. Returns FILE* as int64, or 0 on failure. */
int64_t moonbitmark_ffi_fopen(moonbit_bytes_t path) {
  int len = Moonbit_array_length(path);
  if (len < 0) {
    return 0;
  }
  char *c_path = (char *)malloc((size_t)len + 1);
  if (c_path == NULL) {
    return 0;
  }
  memcpy(c_path, (const char *)path, (size_t)len);
  c_path[len] = '\0';
  FILE *fp = fopen(c_path, "rb");
  free(c_path);
  return (int64_t)(intptr_t)fp;
}

/* Read up to len bytes into buf + offset. Returns bytes read, -1 on error. */
int64_t moonbitmark_ffi_fread(
  int64_t fp,
  moonbit_bytes_t buf,
  int64_t offset,
  int64_t len
) {
  size_t n = fread((char *)buf + offset, 1, (size_t)len, (FILE *)(intptr_t)fp);
  if (n == 0 && ferror((FILE *)(intptr_t)fp)) {
    return -1;
  }
  return (int64_t)n;
}

/* Nonzero if EOF has been reached. */
int64_t moonbitmark_ffi_feof(int64_t fp) {
  return (int64_t)feof((FILE *)(intptr_t)fp);
}

/* Close the file. Returns 0 on success. */
int64_t moonbitmark_ffi_fclose(int64_t fp) {
  return (int64_t)fclose((FILE *)(intptr_t)fp);
}

#endif /* _WIN32 */
