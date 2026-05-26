#include <sys/stat.h>
#include <stdint.h>
#include <string.h>

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
int bit_lstat(const char *path, uint8_t *buf) {
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
