#include <moonbit.h>

#ifdef _WIN32
#define _CRT_RAND_S
#include <stdlib.h>

MOONBIT_FFI_EXPORT int mizchi_x_tls_rand_bytes(unsigned char *buf, int len) {
  int i = 0;
  while (i < len) {
    unsigned int r;
    if (rand_s(&r) != 0) {
      return -1;
    }
    for (int k = 0; k < 4 && i < len; k++, i++) {
      buf[i] = (unsigned char)(r >> (8 * k));
    }
  }
  return 0;
}
#else
#include <unistd.h>
#if defined(__APPLE__)
#include <sys/random.h>
#endif

MOONBIT_FFI_EXPORT int mizchi_x_tls_rand_bytes(unsigned char *buf, int len) {
  // getentropy is limited to 256 bytes per call.
  int done = 0;
  while (done < len) {
    int chunk = len - done > 256 ? 256 : len - done;
    if (getentropy(buf + done, (size_t)chunk) != 0) {
      return -1;
    }
    done += chunk;
  }
  return 0;
}
#endif
