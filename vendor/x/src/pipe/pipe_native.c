#include <moonbit.h>
#include <errno.h>

#ifdef _WIN32
MOONBIT_FFI_EXPORT int mizchi_x_pipe_open(int *fds) {
  (void)fds;
  return ENOSYS;
}

MOONBIT_FFI_EXPORT int mizchi_x_pipe_close(int fd) {
  (void)fd;
  return 0;
}
#else
#include <fcntl.h>
#include <unistd.h>

// Create an OS pipe whose ends are not inherited by child processes (the
// read or write end reaches a child only through an explicit redirect).
MOONBIT_FFI_EXPORT int mizchi_x_pipe_open(int *fds) {
  int p[2];
  if (pipe(p) != 0) {
    return errno;
  }
  for (int i = 0; i < 2; i++) {
    if (fcntl(p[i], F_SETFD, FD_CLOEXEC) != 0) {
      int err = errno;
      close(p[0]);
      close(p[1]);
      return err;
    }
  }
  fds[0] = p[0];
  fds[1] = p[1];
  return 0;
}

MOONBIT_FFI_EXPORT int mizchi_x_pipe_close(int fd) {
  return close(fd);
}
#endif
