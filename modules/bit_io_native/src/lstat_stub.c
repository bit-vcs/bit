#include <sys/stat.h>
#include <stdint.h>
#include <string.h>
#include <moonbit.h>
#include "windows_path.h"
#ifdef _WIN32
#include <winioctl.h>
#endif
#ifndef _WIN32
#include <unistd.h>
#endif

/*
 * bit_lstat: single-syscall file metadata for worktree scanning.
 *
 * Calls lstat() and packs results into a 44-byte buffer:
 *   bytes 0-3:   st_mode   (uint32, little-endian) — includes file type + perms
 *   bytes 4-11:  st_size   (int64, little-endian)
 *   bytes 12-19: mtime_sec (int64, little-endian)
 *   bytes 20-27: mtime_nsec (int64, little-endian)
 *   bytes 28-31: st_dev    (uint32, little-endian)
 *   bytes 32-35: st_ino    (uint32, little-endian)
 *   bytes 36-39: st_uid    (uint32, little-endian)
 *   bytes 40-43: st_gid    (uint32, little-endian)
 *
 * Returns 0 on success, -1 on failure.
 */
MOONBIT_FFI_EXPORT int bit_lstat(const char *path, uint8_t *buf) {
#ifdef _WIN32
  wchar_t *wide = bit_windows_path(path);
  if (wide == NULL) return -1;
  HANDLE handle = CreateFileW(wide, 0,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING,
      FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, NULL);
  free(wide);
  if (handle == INVALID_HANDLE_VALUE) return -1;
  BY_HANDLE_FILE_INFORMATION info;
  FILE_ATTRIBUTE_TAG_INFO tag;
  int ok = GetFileInformationByHandle(handle, &info) &&
      GetFileInformationByHandleEx(handle, FileAttributeTagInfo, &tag, sizeof(tag));
  CloseHandle(handle);
  if (!ok) return -1;
  uint32_t mode;
  if (tag.ReparseTag == IO_REPARSE_TAG_SYMLINK || tag.ReparseTag == IO_REPARSE_TAG_MOUNT_POINT) {
    mode = 0120000;
  } else if (info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
    mode = 0040000;
  } else {
    mode = 0100000;
  }
  mode |= (info.dwFileAttributes & FILE_ATTRIBUTE_READONLY) ? 0444 : 0666;
  int64_t size = ((int64_t)info.nFileSizeHigh << 32) | info.nFileSizeLow;
  uint64_t ticks = ((uint64_t)info.ftLastWriteTime.dwHighDateTime << 32) |
      info.ftLastWriteTime.dwLowDateTime;
  int64_t mtime_sec = (int64_t)(ticks / 10000000) - 11644473600LL;
  int64_t mtime_nsec = (int64_t)(ticks % 10000000) * 100;
  uint32_t dev = info.dwVolumeSerialNumber;
  uint32_t ino = info.nFileIndexLow;
  uint32_t uid = 0, gid = 0;
#else
  struct stat st;
  if (lstat(path, &st) != 0) {
    return -1;
  }

  uint32_t mode = (uint32_t)st.st_mode;
  int64_t size = (int64_t)st.st_size;

#ifdef __APPLE__
  int64_t mtime_sec = (int64_t)st.st_mtimespec.tv_sec;
  int64_t mtime_nsec = (int64_t)st.st_mtimespec.tv_nsec;
#else
  int64_t mtime_sec = (int64_t)st.st_mtim.tv_sec;
  int64_t mtime_nsec = (int64_t)st.st_mtim.tv_nsec;
#endif
  uint32_t dev = (uint32_t)st.st_dev;
  uint32_t ino = (uint32_t)st.st_ino;
  uint32_t uid = (uint32_t)st.st_uid;
  uint32_t gid = (uint32_t)st.st_gid;
#endif

  memcpy(buf + 0, &mode, 4);
  memcpy(buf + 4, &size, 8);
  memcpy(buf + 12, &mtime_sec, 8);
  memcpy(buf + 20, &mtime_nsec, 8);
  memcpy(buf + 28, &dev, 4);
  memcpy(buf + 32, &ino, 4);
  memcpy(buf + 36, &uid, 4);
  memcpy(buf + 40, &gid, 4);
  return 0;
}

/* Return UTF-8 bytes without a terminator, like POSIX readlink. */
MOONBIT_FFI_EXPORT int bit_readlink(const char *path, uint8_t *buf, int size) {
#ifdef _WIN32
  if (size <= 0) return -1;
  wchar_t *wide = bit_windows_path(path);
  if (wide == NULL) return -1;
  HANDLE handle = CreateFileW(wide, 0,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING,
      FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, NULL);
  free(wide);
  if (handle == INVALID_HANDLE_VALUE) return -1;
  /* REPARSE_DATA_BUFFER is a kernel header type; use the documented wire
   * offsets rather than importing ntifs.h into a user-mode program. */
  union { DWORD align; uint8_t bytes[MAXIMUM_REPARSE_DATA_BUFFER_SIZE]; } data;
  DWORD returned;
  BOOL ok = DeviceIoControl(handle, FSCTL_GET_REPARSE_POINT, NULL, 0,
      data.bytes, sizeof(data.bytes), &returned, NULL);
  CloseHandle(handle);
  if (!ok || returned < 8) return -1;
  DWORD tag;
  USHORT offset, length;
  memcpy(&tag, data.bytes, 4);
  size_t base;
  if (tag == IO_REPARSE_TAG_SYMLINK) base = 20;
  else if (tag == IO_REPARSE_TAG_MOUNT_POINT) base = 16;
  else return -1;
  if (returned < base) return -1;
  /* Prefer the print name; fall back to the substitute name when absent. */
  memcpy(&offset, data.bytes + 12, 2);
  memcpy(&length, data.bytes + 14, 2);
  int substitute = length == 0;
  if (substitute) {
    memcpy(&offset, data.bytes + 8, 2);
    memcpy(&length, data.bytes + 10, 2);
  }
  if ((offset | length) & 1 || base + offset + length > returned) return -1;
  const wchar_t *target = (const wchar_t *)(data.bytes + base + offset);
  int chars = length / 2;
  /* Convert NT namespace paths to their ordinary Windows spelling. */
  int unc = 0;
  if (substitute && chars >= 4 && wcsncmp(target, L"\\??\\", 4) == 0) {
    target += 4;
    chars -= 4;
    if (chars >= 4 && wcsncmp(target, L"UNC\\", 4) == 0) {
      target += 4;
      chars -= 4;
      unc = 2;
    }
  }
  int bytes = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, target, chars,
      NULL, 0, NULL, NULL);
  if (bytes <= 0) return -1;
  char *utf8 = (char *)malloc((size_t)bytes + unc);
  if (utf8 == NULL) return -1;
  if (unc) { utf8[0] = '\\'; utf8[1] = '\\'; }
  if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, target, chars,
      utf8 + unc, bytes, NULL, NULL) == 0) { free(utf8); return -1; }
  int count = bytes + unc < size ? bytes + unc : size;
  memcpy(buf, utf8, count);
  free(utf8);
  return count;
#else
  return (int)readlink(path, (char *)buf, (size_t)size);
#endif
}
