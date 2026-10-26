#ifndef _WIN32
#include <dirent.h>
#endif
#include <stdint.h>
#include <string.h>
#include <moonbit.h>
#include "windows_path.h"

/*
 * bit_readdir: list directory entries with d_type (no stat needed).
 *
 * Buffer format per entry:
 *   bytes 0-1:  name_len  (uint16, little-endian)
 *   byte  2:    d_type    (DT_DIR=4, DT_REG=8, DT_LNK=10, DT_UNKNOWN=0)
 *   bytes 3..:  name      (UTF-8, NOT null-terminated)
 *
 * Returns total bytes written on success (>= 0), -1 on failure.
 * Only complete entries are written; partial entries are never included.
 */
MOONBIT_FFI_EXPORT int bit_readdir(const char *path, uint8_t *buf, int buf_size) {
#ifdef _WIN32
  wchar_t *wide = bit_windows_path(path);
  if (wide == NULL) return -1;
  size_t length = wcslen(wide);
  wchar_t *pattern = (wchar_t *)malloc((length + 3) * sizeof(wchar_t));
  if (pattern == NULL) { free(wide); return -1; }
  memcpy(pattern, wide, length * sizeof(wchar_t));
  free(wide);
  if (length > 0 && pattern[length - 1] != L'/' && pattern[length - 1] != L'\\') {
    pattern[length++] = L'\\';
  }
  pattern[length++] = L'*';
  pattern[length] = 0;
  WIN32_FIND_DATAW entry;
  HANDLE handle = FindFirstFileW(pattern, &entry);
  free(pattern);
  if (handle == INVALID_HANDLE_VALUE) return -1;
  int pos = 0;
  do {
    if (wcscmp(entry.cFileName, L".") == 0 || wcscmp(entry.cFileName, L"..") == 0) continue;
    int length = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, entry.cFileName,
        -1, NULL, 0, NULL, NULL);
    if (length == 0) { FindClose(handle); return -1; }
    int name_len = length - 1;
    if (name_len + 3 > buf_size - pos) break;
    /* Exclude the UTF-8 terminator from the packed entry. */
    if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, entry.cFileName,
        (int)wcslen(entry.cFileName), (char *)buf + pos + 3, name_len, NULL, NULL) == 0) {
      FindClose(handle);
      return -1;
    }
    buf[pos] = (uint8_t)(name_len & 0xff);
    buf[pos + 1] = (uint8_t)(name_len >> 8);
    buf[pos + 2] = (entry.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) &&
        (entry.dwReserved0 == IO_REPARSE_TAG_SYMLINK || entry.dwReserved0 == IO_REPARSE_TAG_MOUNT_POINT)
        ? 10 : (entry.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ? 4 : 8;
    pos += name_len + 3;
  } while (FindNextFileW(handle, &entry));
  FindClose(handle);
  return pos;
#else
  DIR *d = opendir(path);
  if (!d) {
    return -1;
  }

  int pos = 0;
  struct dirent *ent;
  while ((ent = readdir(d)) != NULL) {
    const char *name = ent->d_name;
    /* Skip . and .. */
    if (name[0] == '.' && (name[1] == '\0' || (name[1] == '.' && name[2] == '\0'))) {
      continue;
    }
    int name_len = (int)strlen(name);
    int entry_size = 2 + 1 + name_len; /* name_len(2) + d_type(1) + name */
    if (pos + entry_size > buf_size) {
      break;
    }
    /* name_len as uint16 LE */
    buf[pos]     = (uint8_t)(name_len & 0xFF);
    buf[pos + 1] = (uint8_t)((name_len >> 8) & 0xFF);
    /* d_type */
    buf[pos + 2] = ent->d_type;
    /* name bytes */
    memcpy(buf + pos + 3, name, name_len);
    pos += entry_size;
  }

  closedir(d);
  return pos;
#endif
}
