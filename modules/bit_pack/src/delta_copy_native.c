#include <stdint.h>
#include <string.h>

#ifndef MOONBIT_FFI_EXPORT
#define MOONBIT_FFI_EXPORT __attribute__((visibility("default")))
#endif

/* Bounds are checked by apply_delta before this helper is called. */
MOONBIT_FFI_EXPORT void bit_pack_copy_delta_bytes(
    const uint8_t *source, int source_offset, uint8_t *destination,
    int destination_offset, int length) {
  if (length > 0) {
    memcpy(destination + destination_offset, source + source_offset,
           (size_t)length);
  }
}
