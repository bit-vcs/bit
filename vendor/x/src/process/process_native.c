#include <moonbit.h>

#ifdef _WIN32
// Windows has neither setpgid nor POSIX kill — process groups work
// through Job Objects, which the underlying spawn helper doesn't
// expose. These stubs let the package still compile on Windows; the
// new-process-group flag is a no-op there and `kill_tree` falls back
// to a regular TerminateProcess on the leaf PID via the caller's own
// signal logic.
#include <windows.h>

MOONBIT_FFI_EXPORT int mizchi_x_process_setpgid_self(int pid) {
  (void)pid;
  return 0;
}

MOONBIT_FFI_EXPORT int mizchi_x_process_kill(int pid, int signal) {
  HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, (DWORD)pid);
  if (h == NULL) {
    return -1;
  }
  int rc = TerminateProcess(h, (UINT)signal) ? 0 : -1;
  CloseHandle(h);
  return rc;
}

#else
#include <signal.h>
#include <unistd.h>
#include <errno.h>

// Make `pid` its own process-group leader. Called by `spawn` shortly
// after the child is forked, when the caller asked for a new process
// group. The race window (child runs with the parent's PGID until
// this call lands) is tiny — typical posix_spawn returns before the
// child runs more than a few instructions. Returns 0 on success or
// the errno on failure (we tolerate EACCES / EPERM because the child
// may have already exec'd / setpgid'd itself).
MOONBIT_FFI_EXPORT int mizchi_x_process_setpgid_self(int pid) {
  if (setpgid(pid, pid) == 0) {
    return 0;
  }
  // EACCES / EPERM mean the child has already exec'd; treat as soft
  // success — the caller still gets a pgid-leader child, just by a
  // different code path.
  if (errno == EACCES || errno == EPERM) {
    return 0;
  }
  return errno;
}

// Send `signal` to `pid`. Pass a negative `pid` to target the entire
// process group whose pgid equals `-pid` — this is the standard way
// to kill a subtree once the leader was set via setpgid above.
MOONBIT_FFI_EXPORT int mizchi_x_process_kill(int pid, int signal) {
  if (kill((pid_t)pid, signal) == 0) {
    return 0;
  }
  return errno;
}
#endif
