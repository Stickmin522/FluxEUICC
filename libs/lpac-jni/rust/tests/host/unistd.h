#pragma once
#include <io.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#define strdup _strdup
static inline int asprintf(char **out, const char *format, ...) {
    va_list args;
    va_start(args, format);
    int size = _vscprintf(format, args);
    va_end(args);
    if (size < 0 || !(*out = malloc((size_t)size + 1))) return -1;
    va_start(args, format);
    vsnprintf(*out, (size_t)size + 1, format, args);
    va_end(args);
    return size;
}
