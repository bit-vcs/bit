#include <stdint.h>
#include <sys/stat.h>
#include <moonbit.h>
#ifndef _WIN32
#include <unistd.h>
#endif

/* bit_symlink: symlink(target, path); 0 on success, -1 on failure. */
MOONBIT_FFI_EXPORT int bit_symlink(const char *target, const char *path) {
#ifdef _WIN32
  (void)target;
  (void)path;
  return -1;
#else
  return symlink(target, path) == 0 ? 0 : -1;
#endif
}

/* bit_chmod: chmod a regular file (never a symlink's target). */
MOONBIT_FFI_EXPORT int bit_chmod(const char *path, int mode) {
#ifdef _WIN32
  (void)path;
  (void)mode;
  return 0;
#else
  struct stat st;
  if (lstat(path, &st) != 0) return -1;
  if (S_ISLNK(st.st_mode)) return 0;
  return chmod(path, (mode_t)mode) == 0 ? 0 : -1;
#endif
}
