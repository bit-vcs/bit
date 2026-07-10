/* Proper time() wrapper for MoonBit FFI */
#include <time.h>

long long bit_current_time(void) {
    return (long long)time(NULL);
}
