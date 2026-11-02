# Put the game's JavaScript behind an engine façade, with a QuickJS-ng backend beside SpiderMonkey

**Series:** step 2 of 25 · base `series/001-safety-net` · next `series/003-objective-cxx` **(gen)**

**Chapter:** P1 · 1.1 define the façade, 1.2 retarget call sites, 1.3 QuickJS-ng backend · history `3ca73e5a13`..`7bc686c0af` (55 merges) · 14.6k src, 1.3k tests, 7.0k other changed lines; 5.6k lines in deleted files **(gen)**

## What this changes

This step adds `src/Core/Scripting/ooscript/JSEngine.hpp`, a C++ interface to the JavaScript
engine (namespace `ooscript`: `Value`, `Object`, `Context`, `ClassDef`, `PropertySpec`,
`FunctionSpec`, `CallArgs`, rooting and exceptions). Its first backend is
`JSEngine_spidermonkey.cpp`, which is still the engine the game links. The binding files under
`src/Core/Scripting/` are retargeted onto it: class tables, property hooks and native signatures
now use the `ooscript` types, and the old `JSContext`/`jsval` locals are recovered by byte-identical
casts, so the function bodies and the `OOJS_*` macros don't change. Those files become Objective-C++
(`.m` → `.mm`) because the interface is C++. The headers they include gain `extern "C"` guards, and
parameters named `new`, `this` or `private` are renamed. A second backend, `JSEngine_quickjs.cpp`
for QuickJS-ng 0.16.2 (`subprojects/quickjs-ng.wrap`), is added beside it with its unit test, but
the game does not compile or link it yet.

## Why

The game uses a patched SpiderMonkey 1.8.5, which has no maintained build for current toolchains or
for Apple Silicon. About 3,800 call sites used its API directly. Putting them behind one interface
while SpiderMonkey is still underneath lets the retargeting be checked on its own: if the step-1
tests and gameplay don't change, the façade is faithful. The engine swap then becomes one backend
change (step 4), not a rewrite of every binding at once. This step comes straight after the safety
net because it is the first one to touch production code, and the first to bring Objective-C++ into
the build. Step 3 then extends Objective-C++ to the rest of the game.

## Behaviour changes

None intended. SpiderMonkey is still the default and only linked backend
(`js_backend=spidermonkey` in `meson.options`). The step-1 component and GUI tiers
(`tests/component/`, `tests/gui/`) run against this step unchanged.

Two build-side changes are not game behaviour:
- `ShellScripts/common/post_build.sh` now copies the full set of DLLs the Windows binary depends on,
  including DLLs needed only by other DLLs (e.g. `libtre` pulling in `libsystre`).
- `js_backend=quickjs` builds the QuickJS-ng subproject but does not link it.

## How to review

1. Read `src/Core/Scripting/ooscript/JSEngine.hpp`, then `ooscript/README.md`. The README's
   retarget map lists, for each engine function, the façade call that replaces it.
2. Read `src/Core/Scripting/OOJSVector.mm` as the worked example. Its banner explains the pattern:
   a native's new signature, the small shim at the top of each function that recovers the old
   locals, and the `this`/`private` renames. The other binding files repeat it.
3. Review `JSEngine_spidermonkey.cpp` as the mapping onto 1.8.5. Its `static_assert`s pin the
   layout equivalences the casts rely on.

The rest is mechanical:
- the `.m` → `.mm` renames in `src/Core/Scripting/meson.build`;
- `extern "C"` blocks in the shared headers;
- the `new` → `newValue` parameter renames in `ShipEntity.h`;
- casts in `PlayerEntityLoadSave.m`.

Several bindings appear as delete-plus-add, not renames. To review them as renames, use
`git diff -M30% <base> <head> -- src/Core/Scripting`. To spot-check the retargeting, run
`git grep -nE '\bJS_[A-Z][A-Za-z]*\(' -- 'src/Core/Scripting/*.mm'`: only
`OOJavaScriptEngine.mm` still calls the engine directly; step 4 retargets it.

`JSEngine_quickjs.cpp` (3.5k lines) and `tests/unit/test_jsengine_*.cpp` are not built by meson
at this step. You can review them now or when step 4 links the backend.

## Verified **(gen)**

Windows x64, `a0bc6f4a03`, 2026-11-02.

| Check | Result |
|---|---|
| build_clang | pass |
| build_gcc | n/a: Objective-C with the GNUstep runtime builds with Clang only (upstream too) |
| clang_format | pass |
| component | n/a: no component scenario touched |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | pass |
| unit | n/a: the tree has no unit suites |
| warnings_clang | pass: 0 warnings |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
