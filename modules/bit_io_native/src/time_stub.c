/* Wall-clock seconds for the object-store SigV4 clock.
 *
 * Named distinctly from cmd/bit's bit_current_time so both stubs can be
 * linked into the same binary.
 */
#include <time.h>

long long bit_objstore_current_time(void) {
    return (long long)time(NULL);
}
