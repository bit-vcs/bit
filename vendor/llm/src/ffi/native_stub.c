#include "moonbit.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

// Convert a UTF-8 C string to a MoonBit String (UTF-16).
static moonbit_string_t utf8_to_moonbit_string(const char *utf8, size_t utf8_len) {
    if (!utf8 || utf8_len == 0) {
        return moonbit_make_string(0, 0);
    }
    // First pass: count UTF-16 code units
    int32_t utf16_len = 0;
    size_t i = 0;
    while (i < utf8_len) {
        unsigned char c = (unsigned char)utf8[i];
        uint32_t cp;
        if (c < 0x80) {
            cp = c; i += 1;
        } else if ((c & 0xE0) == 0xC0) {
            cp = c & 0x1F;
            if (i + 1 < utf8_len) cp = (cp << 6) | (utf8[i+1] & 0x3F);
            i += 2;
        } else if ((c & 0xF0) == 0xE0) {
            cp = c & 0x0F;
            if (i + 1 < utf8_len) cp = (cp << 6) | (utf8[i+1] & 0x3F);
            if (i + 2 < utf8_len) cp = (cp << 6) | (utf8[i+2] & 0x3F);
            i += 3;
        } else if ((c & 0xF8) == 0xF0) {
            cp = c & 0x07;
            if (i + 1 < utf8_len) cp = (cp << 6) | (utf8[i+1] & 0x3F);
            if (i + 2 < utf8_len) cp = (cp << 6) | (utf8[i+2] & 0x3F);
            if (i + 3 < utf8_len) cp = (cp << 6) | (utf8[i+3] & 0x3F);
            i += 4;
        } else {
            cp = 0xFFFD; i += 1; // replacement character
        }
        if (cp >= 0x10000) {
            utf16_len += 2; // surrogate pair
        } else {
            utf16_len += 1;
        }
    }
    // Second pass: fill UTF-16 array
    moonbit_string_t result = moonbit_make_string(utf16_len, 0);
    int32_t j = 0;
    i = 0;
    while (i < utf8_len) {
        unsigned char c = (unsigned char)utf8[i];
        uint32_t cp;
        if (c < 0x80) {
            cp = c; i += 1;
        } else if ((c & 0xE0) == 0xC0) {
            cp = c & 0x1F;
            if (i + 1 < utf8_len) cp = (cp << 6) | (utf8[i+1] & 0x3F);
            i += 2;
        } else if ((c & 0xF0) == 0xE0) {
            cp = c & 0x0F;
            if (i + 1 < utf8_len) cp = (cp << 6) | (utf8[i+1] & 0x3F);
            if (i + 2 < utf8_len) cp = (cp << 6) | (utf8[i+2] & 0x3F);
            i += 3;
        } else if ((c & 0xF8) == 0xF0) {
            cp = c & 0x07;
            if (i + 1 < utf8_len) cp = (cp << 6) | (utf8[i+1] & 0x3F);
            if (i + 2 < utf8_len) cp = (cp << 6) | (utf8[i+2] & 0x3F);
            if (i + 3 < utf8_len) cp = (cp << 6) | (utf8[i+3] & 0x3F);
            i += 4;
        } else {
            cp = 0xFFFD; i += 1;
        }
        if (cp >= 0x10000) {
            cp -= 0x10000;
            result[j++] = (uint16_t)(0xD800 | (cp >> 10));
            result[j++] = (uint16_t)(0xDC00 | (cp & 0x3FF));
        } else {
            result[j++] = (uint16_t)cp;
        }
    }
    return result;
}

// Get an environment variable, returns MoonBit String.
MOONBIT_FFI_EXPORT
moonbit_string_t llm_getenv_ffi(moonbit_bytes_t key) {
    const char *val = getenv((const char *)key);
    if (!val) val = "";
    return utf8_to_moonbit_string(val, strlen(val));
}

// Run a shell command via popen, capture stdout, return as MoonBit String.
// Returns "ERROR: ..." prefix on failure.
MOONBIT_FFI_EXPORT
moonbit_string_t llm_popen_ffi(moonbit_bytes_t command) {
    const char *cmd = (const char *)command;
    FILE *fp = popen(cmd, "r");
    if (!fp) {
        const char *err = "ERROR: popen failed";
        return utf8_to_moonbit_string(err, strlen(err));
    }

    // Read all stdout into a dynamic buffer
    size_t capacity = 4096;
    size_t length = 0;
    char *buf = (char *)malloc(capacity);
    if (!buf) {
        pclose(fp);
        const char *err = "ERROR: malloc failed";
        return utf8_to_moonbit_string(err, strlen(err));
    }

    size_t n;
    while ((n = fread(buf + length, 1, capacity - length, fp)) > 0) {
        length += n;
        if (length == capacity) {
            capacity *= 2;
            char *newbuf = (char *)realloc(buf, capacity);
            if (!newbuf) {
                free(buf);
                pclose(fp);
                const char *err = "ERROR: realloc failed";
                return utf8_to_moonbit_string(err, strlen(err));
            }
            buf = newbuf;
        }
    }

    int status = pclose(fp);
    int exit_code = WEXITSTATUS(status);

    moonbit_string_t result;
    if (exit_code != 0) {
        // Prepend error prefix with exit code
        char prefix[64];
        snprintf(prefix, sizeof(prefix), "ERROR: exit code %d: ", exit_code);
        size_t prefix_len = strlen(prefix);
        size_t total = prefix_len + length;
        char *errbuf = (char *)malloc(total + 1);
        if (errbuf) {
            memcpy(errbuf, prefix, prefix_len);
            memcpy(errbuf + prefix_len, buf, length);
            errbuf[total] = '\0';
            result = utf8_to_moonbit_string(errbuf, total);
            free(errbuf);
        } else {
            result = utf8_to_moonbit_string(prefix, prefix_len);
        }
    } else {
        result = utf8_to_moonbit_string(buf, length);
    }

    free(buf);
    return result;
}
