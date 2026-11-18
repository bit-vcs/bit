#define _GNU_SOURCE
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

// Create an OS pipe whose ends are close-on-exec, so a child receives one
// only through an explicit redirect. On Linux the flag is set atomically by
// pipe2(); elsewhere (e.g. macOS, which has no pipe2) it is set right after
// pipe(), so a child spawned concurrently by another thread in that window
// can still inherit an end.
MOONBIT_FFI_EXPORT int mizchi_x_pipe_open(int *fds) {
  int p[2];
#if defined(__linux__)
  // Atomic close-on-exec: no window where a concurrently spawned child could
  // inherit an end.
  if (pipe2(p, O_CLOEXEC) != 0) {
    return errno;
  }
#else
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
#endif
  fds[0] = p[0];
  fds[1] = p[1];
  return 0;
}

MOONBIT_FFI_EXPORT int mizchi_x_pipe_close(int fd) {
  return close(fd);
}
#endif
