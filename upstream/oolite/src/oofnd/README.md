# oofnd — the Foundation replacement

`oofnd` is the C++20 library that replaces GNUstep Foundation (`libgnustep-base`) during the
migration (Phase 2, [architecture §3.4](../../../../docs/architecture.md)). It is built bottom-up,
one component per seam, each with its own unit tests, and adopted by Objective-C++ call sites
while the classes are still Objective-C. Namespace `oo`.

Rules that hold for every component:

- **C++20 only** until Phase 6 ([ADR-0011](../../../../docs/decisions/0011-cpp20-then-cpp23.md)).
  Where C++23 has the thing (`std::expected`), oofnd provides a same-API polyfill so the
  Phase 6 upgrade is a rename.
- **No exceptions across oofnd APIs.** Fallible operations return `oo::Expected<T, E>`.
  Headers must compile with `-fno-exceptions` (the canary checks it).
- **Header-first.** A component is a header in this directory until it needs a `.cpp`; then
  `meson.build` here grows an `oofnd` static library (the recipe is in that file).
- **No Foundation, no `JS_*`** (the deny-list); no third-party code unless an ADR says so.

## Layout

| Path | What |
|---|---|
| `src/oofnd/Expected.hpp` | `oo::Expected<T, E>`, `oo::Unexpected<E>`, `oo::unexpect`, `oo::BadExpectedAccess<E>`: `std::expected`'s C++23 API |
| `src/oofnd/meson.build` | `oofnd_dep` (include path `src/`, so consumers write `#include "oofnd/X.hpp"`) |
| `tests/unit/oofnd/test_*.cpp` | one executable per component, plain C++20 |
| `tests/unit/oofnd/oo_test.hpp` | the whole test harness: `OO_TEST`, `OO_CHECK`, `OO_CHECK_EQ`, `OO_TEST_MAIN` |
| `tests/unit/oofnd/meson.build` | registers each test in `meson test --suite oofnd` |

## Testing

From the repo root, in the MSYS2 UCRT64 shell:

```bash
bash tools/check-oofnd.sh      # no build dir needed; ~10 s. The bead acceptance.
```

It compiles every header alone and together (the canary TU, also under `-fno-exceptions`), then
builds and runs every `tests/unit/oofnd/test_*.cpp` at `-std=c++20 -Wall -Wextra -Werror`, then
again under AddressSanitizer. It fails on zero tests and on a test file missing from
`tests/unit/oofnd/meson.build`.

Inside a game build directory the same tests run through meson:

```bash
cd upstream/oolite && ./mk.sh build test
meson test -C build/meson_test --suite oofnd
```

Adding a component: put `Foo.hpp` here, write `tests/unit/oofnd/test_foo.cpp` ending in
`OO_TEST_MAIN()`, and add `'test_foo'` to `tests/unit/oofnd/meson.build`.
