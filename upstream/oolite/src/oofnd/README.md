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
| `src/oofnd/Ref.hpp` | `oo::RefCounted`, `oo::Ref<T>`, `oo::WeakRef<T>`, `oo::AutoreleaseScope`: ObjC retain/release/autorelease and `OOWeakReference` 1:1 ([ADR-0003](../../../../docs/decisions/0003-intrusive-refcount.md), [ADR-0026](../../../../docs/decisions/0026-oofnd-ref-semantics.md)); the banner maps each ObjC idiom |
| `src/oofnd/WeakSet.hpp` | `oo::WeakSet<T>`: `OOWeakSet` |
| `src/oofnd/Data.hpp` | `oo::Data`: `NSData` / `NSMutableData` as a value type ([ADR-0028](../../../../docs/decisions/0028-oofnd-filesystem-paths-data.md)) |
| `src/oofnd/FileSystem.hpp` | `oo::fs`: `NSFileManager` + its OOExtensions category + NSData file I/O, on `std::filesystem` with GNUstep semantics |
| `src/oofnd/ResourcePaths.hpp` | `oo::ResourcePaths`: the game's Resources/AddOns/saves/logs/caches locations, exactly as computed today on Windows and Linux |
| `src/oofnd/objc/OOObject.h`, `.mm` | `OOObject`: the Foundation-free Objective-C root class on libobjc2's own refcount and pool; `OOObjCInstallFloor()` ([ADR-0029](../../../../docs/decisions/0029-objc-floor-without-foundation.md)). Objective-C++; linked into the game by bead oo-3rb.2 (exemplar reroot: `Core/OORoleSet`), but `OOObjCInstallFloor()` is not called until the constant-string flip |
| `src/oofnd/objc/OOConstantString.h`, `.mm` | `OOConstantString`/`OOTinyString`: the classes behind `@"..."` under `-fconstant-string-class=OOConstantString` (ADR-0029) |
| `src/oofnd/meson.build` | `oofnd_dep` (include path `src/`, so consumers write `#include "oofnd/X.hpp"`) |
| `tests/unit/oofnd/test_*.cpp` | one executable per component, plain C++20 |
| `tests/unit/oofnd/oo_test.hpp` | the whole test harness: `OO_TEST`, `OO_CHECK`, `OO_CHECK_EQ`, `OO_TEST_MAIN` |
| `tests/unit/oofnd/test_*.mm` | Objective-C++ tests of `src/oofnd/objc`, linked against libobjc2 alone; `tools/check-oofnd-objc.sh` builds them and proves the import table has no gnustep-base |
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

Objective-C++ game code builds as `gnu++20` and sees OOCocoa.h's `#define true 1` / `#define false 0`:
a header that game code includes must suspend them with `#pragma push_macro`/`pop_macro` as
`Data.hpp` does (ADR-0028; `tests/unit/oofnd/test_cocoa_macros.cpp` checks it).

Adding a component: put `Foo.hpp` here, write `tests/unit/oofnd/test_foo.cpp` ending in
`OO_TEST_MAIN()`, and add `'test_foo'` to `tests/unit/oofnd/meson.build`.
