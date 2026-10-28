/*
 * tools/oxp-js-parse/parse.c -- compile-only host for the expansion compatibility scan (ADR-0069).
 *
 * Compiles JavaScript with the game's own pinned QuickJS-ng exactly as the game's script loader
 * does (oolite-dev src/Core/Scripting/ooscript/JSEngine_quickjs.cpp compileUCScript:
 * JS_EVAL_TYPE_GLOBAL | JS_EVAL_FLAG_COMPILE_ONLY, line 1) and reports whether it parses. Nothing
 * is ever executed: the compiled function is freed unevaluated.
 *
 * Input on stdin, any number of records:
 *     <source byte length>\n<source bytes>
 * Output on stdout, one line per record:
 *     ok
 *     err <line> <column> <message>
 * The message is QuickJS-ng's own, truncated to 160 bytes, with control characters replaced, so
 * the line is always one line. The file name is fixed ("oxp.js") so nothing from the expansion
 * reaches the output except what the engine puts in its message.
 *
 * The driver (run.js) owns decoding, the "use strict" variant, zip reading and the report.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "quickjs.h"

#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

#define MAX_MESSAGE 160
#define FILENAME "oxp.js"

static int readLength(size_t* out) {
  char buf[32];
  size_t n = 0;
  int c;
  while ((c = getchar()) != EOF) {
    if (c == '\n') {
      if (n == 0) continue; /* blank line between records */
      break;
    }
    if (c < '0' || c > '9' || n + 1 >= sizeof buf) return -1;
    buf[n++] = (char)c;
  }
  if (c == EOF && n == 0) return 0;
  if (n == 0) return -1;
  buf[n] = '\0';
  *out = (size_t)strtoull(buf, NULL, 10);
  return 1;
}

static void printMessage(const char* msg) {
  size_t i;
  for (i = 0; msg != NULL && msg[i] != '\0' && i < MAX_MESSAGE; i++) {
    unsigned char c = (unsigned char)msg[i];
    putchar(c < 0x20 || c == 0x7f ? ' ' : c);
  }
}

/* QuickJS-ng puts the position in the stack: "    at oxp.js:LINE:COL". */
static void positionFromStack(const char* stack, int* line, int* column) {
  const char* p = stack != NULL ? strstr(stack, FILENAME ":") : NULL;
  *line = 0;
  *column = 0;
  if (p == NULL) return;
  p += strlen(FILENAME ":");
  *line = atoi(p);
  p = strchr(p, ':');
  if (p != NULL) *column = atoi(p + 1);
}

static void report(JSContext* ctx) {
  JSValue exc = JS_GetException(ctx);
  const char* msg = JS_ToCString(ctx, exc);
  JSValue stackVal = JS_GetPropertyStr(ctx, exc, "stack");
  const char* stack = JS_IsString(stackVal) ? JS_ToCString(ctx, stackVal) : NULL;
  int line, column;
  positionFromStack(stack, &line, &column);
  printf("err %d %d ", line, column);
  printMessage(msg != NULL ? msg : "(no message)");
  putchar('\n');
  if (stack != NULL) JS_FreeCString(ctx, stack);
  JS_FreeValue(ctx, stackVal);
  if (msg != NULL) JS_FreeCString(ctx, msg);
  JS_FreeValue(ctx, exc);
}

int main(void) {
  JSRuntime* rt = JS_NewRuntime();
  JSContext* ctx;
  size_t length;
  int status;

#ifdef _WIN32
  /* byte lengths must survive CRLF sources and stray Ctrl-Z bytes */
  _setmode(_fileno(stdin), _O_BINARY);
  _setmode(_fileno(stdout), _O_BINARY);
#endif
  if (rt == NULL) return 2;
  ctx = JS_NewContext(rt);
  if (ctx == NULL) return 2;

  while ((status = readLength(&length)) == 1) {
    char* src = malloc(length + 1);
    JSValue fn;
    if (src == NULL || fread(src, 1, length, stdin) != length) {
      fprintf(stderr, "oxp-js-parse: short record\n");
      return 2;
    }
    src[length] = '\0';
    fn = JS_Eval(ctx, src, length, FILENAME, JS_EVAL_TYPE_GLOBAL | JS_EVAL_FLAG_COMPILE_ONLY);
    if (JS_IsException(fn))
      report(ctx);
    else
      puts("ok");
    JS_FreeValue(ctx, fn);
    free(src);
    fflush(stdout);
  }

  JS_FreeContext(ctx);
  JS_FreeRuntime(rt);
  if (status < 0) {
    fprintf(stderr, "oxp-js-parse: malformed record header\n");
    return 2;
  }
  return 0;
}
