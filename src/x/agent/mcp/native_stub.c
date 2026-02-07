#include "moonbit.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

static moonbit_string_t utf8_to_moonbit_string(const char *utf8, size_t utf8_len) {
    if (!utf8 || utf8_len == 0) {
        return moonbit_make_string(0, 0);
    }
    int32_t utf16_len = 0;
    size_t i = 0;
    while (i < utf8_len) {
        unsigned char c = (unsigned char)utf8[i];
        uint32_t cp;
        if (c < 0x80) { cp = c; i += 1; }
        else if ((c & 0xE0) == 0xC0) { cp = c & 0x1F; if (i+1 < utf8_len) cp = (cp<<6)|(utf8[i+1]&0x3F); i += 2; }
        else if ((c & 0xF0) == 0xE0) { cp = c & 0x0F; if (i+1 < utf8_len) cp = (cp<<6)|(utf8[i+1]&0x3F); if (i+2 < utf8_len) cp = (cp<<6)|(utf8[i+2]&0x3F); i += 3; }
        else if ((c & 0xF8) == 0xF0) { cp = c & 0x07; if (i+1 < utf8_len) cp = (cp<<6)|(utf8[i+1]&0x3F); if (i+2 < utf8_len) cp = (cp<<6)|(utf8[i+2]&0x3F); if (i+3 < utf8_len) cp = (cp<<6)|(utf8[i+3]&0x3F); i += 4; }
        else { cp = 0xFFFD; i += 1; }
        utf16_len += (cp >= 0x10000) ? 2 : 1;
    }
    moonbit_string_t result = moonbit_make_string(utf16_len, 0);
    int32_t j = 0; i = 0;
    while (i < utf8_len) {
        unsigned char c = (unsigned char)utf8[i];
        uint32_t cp;
        if (c < 0x80) { cp = c; i += 1; }
        else if ((c & 0xE0) == 0xC0) { cp = c & 0x1F; if (i+1 < utf8_len) cp = (cp<<6)|(utf8[i+1]&0x3F); i += 2; }
        else if ((c & 0xF0) == 0xE0) { cp = c & 0x0F; if (i+1 < utf8_len) cp = (cp<<6)|(utf8[i+1]&0x3F); if (i+2 < utf8_len) cp = (cp<<6)|(utf8[i+2]&0x3F); i += 3; }
        else if ((c & 0xF8) == 0xF0) { cp = c & 0x07; if (i+1 < utf8_len) cp = (cp<<6)|(utf8[i+1]&0x3F); if (i+2 < utf8_len) cp = (cp<<6)|(utf8[i+2]&0x3F); if (i+3 < utf8_len) cp = (cp<<6)|(utf8[i+3]&0x3F); i += 4; }
        else { cp = 0xFFFD; i += 1; }
        if (cp >= 0x10000) { cp -= 0x10000; result[j++] = (uint16_t)(0xD800|(cp>>10)); result[j++] = (uint16_t)(0xDC00|(cp&0x3FF)); }
        else { result[j++] = (uint16_t)cp; }
    }
    return result;
}

/* Read one MCP message (Content-Length framed) from stdin. Returns empty on EOF. */
MOONBIT_FFI_EXPORT
moonbit_string_t mcp_read_message_ffi(void) {
    char header[256];
    int content_length = -1;

    while (fgets(header, sizeof(header), stdin)) {
        size_t len = strlen(header);
        while (len > 0 && (header[len-1] == '\r' || header[len-1] == '\n'))
            header[--len] = '\0';
        if (len == 0) break;
        if (strncmp(header, "Content-Length:", 15) == 0) {
            content_length = atoi(header + 15);
        }
    }

    if (content_length <= 0) {
        return utf8_to_moonbit_string("", 0);
    }

    char *body = (char *)malloc(content_length + 1);
    if (!body) return utf8_to_moonbit_string("", 0);
    size_t total = 0;
    while (total < (size_t)content_length) {
        size_t n = fread(body + total, 1, content_length - total, stdin);
        if (n == 0) break;
        total += n;
    }
    body[content_length] = '\0';

    moonbit_string_t result = utf8_to_moonbit_string(body, total);
    free(body);
    return result;
}

/* Write one MCP message (Content-Length framed) to stdout. */
MOONBIT_FFI_EXPORT
void mcp_write_message_ffi(moonbit_bytes_t msg) {
    const char *s = (const char *)msg;
    size_t len = strlen(s);
    fprintf(stdout, "Content-Length: %zu\r\n\r\n%s", len, s);
    fflush(stdout);
}

/* Write a log line to stderr. */
MOONBIT_FFI_EXPORT
void mcp_log_ffi(moonbit_bytes_t msg) {
    const char *s = (const char *)msg;
    fprintf(stderr, "%s\n", s);
    fflush(stderr);
}

/* Shell command via popen (same as llm_popen_ffi). */
MOONBIT_FFI_EXPORT
moonbit_string_t mcp_exec_ffi(moonbit_bytes_t command) {
    const char *cmd = (const char *)command;
    FILE *fp = popen(cmd, "r");
    if (!fp) {
        const char *err = "ERROR: popen failed";
        return utf8_to_moonbit_string(err, strlen(err));
    }
    size_t capacity = 4096, length = 0;
    char *buf = (char *)malloc(capacity);
    if (!buf) { pclose(fp); return utf8_to_moonbit_string("", 0); }
    size_t n;
    while ((n = fread(buf + length, 1, capacity - length, fp)) > 0) {
        length += n;
        if (length == capacity) {
            capacity *= 2;
            char *newbuf = (char *)realloc(buf, capacity);
            if (!newbuf) { free(buf); pclose(fp); return utf8_to_moonbit_string("", 0); }
            buf = newbuf;
        }
    }
    pclose(fp);
    moonbit_string_t result = utf8_to_moonbit_string(buf, length);
    free(buf);
    return result;
}
