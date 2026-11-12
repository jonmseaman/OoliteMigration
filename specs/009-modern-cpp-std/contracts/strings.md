# Contract: strings and casts (US6, US7; M5, M6)

Rules the fan-out steps follow. Research: R16, R17.

## Casts

| The C-style cast did | Write |
|---|---|
| an arithmetic, enum or class conversion | `static_cast<T>(x)` |
| `void*` from a C callback back to its type | `static_cast<T*>(p)` |
| removed `const` | `const_cast<T>(x)` |
| reinterpreted a pointer | `reinterpret_cast<T>(p)` |
| reinterpreted bytes through `memcpy` | `std::bit_cast<T>(x)` |
| `(Entity*)nullptr` in a ternary | `static_cast<Entity*>(nullptr)` |

The replacement performs the same conversion. If spelling it out reveals a bug, the cast is
converted unchanged and the bug is recorded (a separate commit fixes it, with a test).

## Text

| Use | Type |
|---|---|
| text a function only reads | `std::string_view` |
| text a function keeps, builds or returns | `std::string` |
| text that may be absent (was a null `const char*`) | `std::optional<std::string>` or `std::optional<std::string_view>` |
| a literal returned by a function | `std::string_view` (`constexpr` where possible) |
| a table of literals | `constexpr std::array<std::string_view, N>` |
| a buffer a C function fills | `std::array<char, N>` or a sized `std::string`, at that call only |

Boundary rules:

1. A pointer passed to a C interface comes from `std::string::c_str()` or a string literal, never
   from `std::string_view::data()`.
2. No `std::string_view` data member, except one initialised from a literal.
3. No `std::string_view` returned that views a local or a temporary.
4. Formatting uses `std::format` (or `OO_LOG`), converted call by call so the output bytes are the
   base's; data formats (`DESC` strings) keep `oo::str::formatRuntime`.
5. Comparison and search use `std::string_view`'s operators and members; GNUstep-specific
   comparisons keep their `oo::str` helpers (research R7).
6. Number parsing uses `std::from_chars` only where it gives today's answer; otherwise an
   `oo::str` helper that reproduces it.

## Guards

- `google-readability-casting`: fatal at the end of M5, with `-Wold-style-cast` added to
  `src/meson.build`'s game warning flags in the same commit.
- `bugprone-unsafe-functions.CustomFunctions`: set at the end of M6 (the check is already fatal):

  ```yaml
  bugprone-unsafe-functions.CustomFunctions: >
    ^::strcpy$,std::string,;^::strncpy$,std::string,;^::strcat$,std::string::append,;
    ^::strncat$,std::string::append,;^::strcmp$,std::string_view comparison,;
    ^::strncmp$,std::string_view::compare,;^::strcasecmp$,oo::str::caseInsensitiveCompare,;
    ^::strlen$,std::string_view::size,;^::strdup$,std::string,;^::strchr$,std::string_view::find,;
    ^::strrchr$,std::string_view::rfind,;^::strstr$,std::string_view::find,;
    ^::strtok$,oo::str::split,;^::sprintf$,std::format,;^::snprintf$,std::format,;
    ^::vsnprintf$,std::vformat,;^::atoi$,std::from_chars,;^::atof$,std::from_chars,
  ```

  The exact regular expressions (with or without `std::`) are confirmed against clang-tidy
  22 when the option is added.
