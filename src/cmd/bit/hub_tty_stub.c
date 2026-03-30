#include <unistd.h>

int hub_stdin_is_tty_native(void) {
  return isatty(0);
}
