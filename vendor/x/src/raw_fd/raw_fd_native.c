#include <moonbit.h>

#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#include <sys/stat.h>
#else
#include <fcntl.h>
#include <unistd.h>
#endif

MOONBIT_FFI_EXPORT int mizchi_x_raw_fd_read(
  int fd,
  char *buf,
  int offset,
  int len
) {
#ifdef _WIN32
  return _read(fd, buf + offset, len);
#else
  return read(fd, buf + offset, len);
#endif
}

MOONBIT_FFI_EXPORT int mizchi_x_raw_fd_write(
  int fd,
  char *buf,
  int offset,
  int len
) {
#ifdef _WIN32
  return _write(fd, buf + offset, len);
#else
  return write(fd, buf + offset, len);
#endif
}

MOONBIT_FFI_EXPORT int mizchi_x_raw_fd_close(int fd) {
#ifdef _WIN32
  return _close(fd);
#else
  return close(fd);
#endif
}

MOONBIT_FFI_EXPORT int mizchi_x_raw_fd_test_open_read(void) {
  const char *path = "/tmp/mizchi_x_raw_fd_read_native.txt";
#ifdef _WIN32
  int fd = _open(path, _O_CREAT | _O_TRUNC | _O_WRONLY | _O_BINARY, _S_IREAD | _S_IWRITE);
  if (fd < 0) return fd;
  _write(fd, "rawfd", 5);
  _close(fd);
  return _open(path, _O_RDONLY | _O_BINARY);
#else
  int fd = open(path, O_CREAT | O_TRUNC | O_WRONLY, 0644);
  if (fd < 0) return fd;
  write(fd, "rawfd", 5);
  close(fd);
  return open(path, O_RDONLY);
#endif
}

MOONBIT_FFI_EXPORT int mizchi_x_raw_fd_test_open_write(void) {
  const char *path = "/tmp/mizchi_x_raw_fd_write_native.txt";
#ifdef _WIN32
  return _open(path, _O_CREAT | _O_TRUNC | _O_WRONLY | _O_BINARY, _S_IREAD | _S_IWRITE);
#else
  return open(path, O_CREAT | O_TRUNC | O_WRONLY, 0644);
#endif
}
