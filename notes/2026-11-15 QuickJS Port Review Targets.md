# QuickJS port: what to review

**Date** 2026-11-15 · **Scope** the `oolite-dev` seriesb stack, by how much each branch changes
`src/Core/Scripting` and the JS console/debug monitor · **No code was changed.**

## Upstream's QuickJS-ng binding (Objective-C)

- **`seriesb/000a-upstream-767-quickjs-option`**
  ([OoliteProject/oolite#767](https://github.com/OoliteProject/oolite/pull/767)) is where the
  binding is written: about 34,700 lines added across 169 files, in `src/Core/Scripting/QuickJS/` and
  `src/Core/Debug/QuickJS/`, alongside SpiderMonkey behind a build option. Its commits are the
  "behave like SpiderMonkey" fixes (`new` on native functions, the global object's names, the
  read-only `const` rewriter, one-shot timers freed by their own callback).
- **`seriesb/000b-upstream-768-quickjs-only`**
  ([#768](https://github.com/OoliteProject/oolite/pull/768)) is mostly mechanical: it moves the
  `QuickJS/` files over the SpiderMonkey ones and deletes SpiderMonkey. Check only that
  `QuickJS/X.m` in 000a matches `X.m` in 000b.
- **`seriesb/028-upstream-772-tests`** adds about 5,400 lines of upstream binding tests, for
  checking the binding's behaviour rather than reading it.

## The fork's C++ conversion of the binding

**Start here: `seriesb/010-module-conversions`**
([#808](https://github.com/OoliteProject/oolite/pull/808), "[C++ 10/28] Convert scripting,
entities, audio and materials classes to C++"). It has the most real Scripting change of any
branch, about 5,600 lines added. The commit is `146b31628`, which touches 120 files in Scripting/Debug:

- `OOJSEngineCore.h` (new, about 570 lines): the C++ engine core, split out of
  `OOJavaScriptEngine.h`.
- The `+ObjCBridge.mm` files (`OOScript+ObjCBridge.mm`,
  `OOJSEngineTimeManagement+ObjCBridge.mm`, `OOJSSystemInfo+ObjCBridge.mm`, …): the glue that kept
  the converted C++ classes working with the Objective-C code still left.
- `OOJSSystemInfo`, `OOJSEquipmentInfo`, `OOJSEngineTimeManagement`: these change the most
  inside their own bodies.

Then:

| Branch | Why |
|---|---|
| `016-objc-runtime-out` | Removes the Objective-C runtime and renames 49 scripting files to `.cpp`, so the bridge from 010 goes away here. Has a fix that keeps `RemoveNonSpiderMonkeyGlobals`' flag a `bool`. |
| `027-modern-cpp` | Ownership changes: JS vector and quaternion private data use `new`/`delete` (T020), `OOJSClasses`' tables become `std::array`/`std::vector` (T021), and the reference-counting bridge is deleted. Lifetime bugs would show up here. |
| `014-facade-deletions` | Deletes the Objective-C facades: about 5,500 lines removed in Scripting. Breaks any caller still going through the facades. |

Skip `023-google-style-format`: about 25,000 lines, but formatting only.

## Not yet checked

- Which component tests cover the scripting paths 010 changes.
