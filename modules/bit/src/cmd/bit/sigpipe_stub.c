/* Ignore SIGPIPE to prevent process termination when writing to closed pipes.
 * On Linux, SIGPIPE kills the process with exit 141 when piped output
 * is consumed partially (e.g., `git log | head -1`).
 * Git itself ignores SIGPIPE at startup. */
#include <signal.h>

void bit_ignore_sigpipe(void) {
    signal(SIGPIPE, SIG_IGN);
}
