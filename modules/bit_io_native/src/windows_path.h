#ifndef BIT_WINDOWS_PATH_H
#define BIT_WINDOWS_PATH_H

#ifdef _WIN32
#include <windows.h>
#include <stdlib.h>
#include <wchar.h>

/* MoonBit paths are UTF-8 regardless of the Windows ANSI code page. */
static wchar_t *bit_windows_path(const char *path) {
  if (path[0] == '\0') return NULL;
  int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, NULL, 0);
  if (length == 0) return NULL;
  wchar_t *wide = (wchar_t *)malloc((size_t)length * sizeof(wchar_t));
  if (wide == NULL) return NULL;
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, wide, length) == 0) {
    free(wide);
    return NULL;
  }
  return wide;
}
#endif
#endif
