# Small fixes after the conversion; Mozilla polyfills for expansions

**Series:** step 25 of 25 · base `seriesb/024-google-style-format` · next `—` **(gen)**

**Switch:** the tree of `feature/upstream-quickjs-binding` (`531ddd6592`), with the series' exclusions and additions · 28.4k src, 11.3k tests, 285 other changed lines; 6.6k lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

Small fixes and one addition on top of step 024. The scripting layer stays upstream #768's
QuickJS-ng binding as steps 003–024 carry it: its code, its profiler macros, its time-limiter
clock, its `dependency('quickjs-ng')` build wiring and its `src/Core/Scripting/README.md`.

| File | What | Why |
|---|---|---|
| `src/Core/OOOpenGLOnly.h` | Also tests the build's `LINUX` define | A plain C++ unit (`OO_PLAIN_CPP_UNIT`) does not include `OOFoundation.h`, so on Linux it had no `GL_GLEXT_PROTOTYPES`; #748's condition is otherwise unchanged |
| `src/Core/OOHPVector.h` | Drops an empty `#if __OBJC__` / `#endif` pair | Left behind when its Objective-C declaration moved out |
| `Resources/Scripts/oolite-global-prefix.js` | Adds `String.prototype.quote()` and the Array/String generics (`Array.forEach(array, fn)`, `String.replace(string, …)`) | Mozilla extensions that SpiderMonkey-era expansions call; `oolite-quickjs-compat.js` (#768) already defines `toSource()` and `uneval()` and is not changed; each install is guarded |
| `tests/unit/core/meson.build` | The 8 tests that open OpenAL are also in suite `openal` | A sanitized run can leave them out (`--no-suite openal`); every test stays in `core` |
| `src/Core/Scripting/OOJavaScriptEngine.cpp`, `OOJSScript.cpp` | Clears the exception when a getter throws while the engine reads an error's `name`/`stack`, a value's `constructor`/`name`, a function's `name`, a described array element, the const rewriter or an unconstructable class's `name` | The exception was left pending for the next script; pinned by `test_OOJavaScriptEngine`'s `throwingAccessorsLeaveNoPendingException` (added) |
| `src/Core/Scripting/OOJSScript.cpp` | Indents the `script.javaScript.willLoad` log unconditionally | It outdented without indenting after an early load failure; upstream's `OOJSScript.m` indents unconditionally |

## Why

Jon (2026-11-04): the series uses upstream's QuickJS-ng binding as upstream wrote it, not the
fork's restyle of it. This step therefore holds only the genuine fixes found between 024 and the
end target. Left out: the restyle of #768's binding and its tests, the `subproject()` wiring (and
the `llvm-ar` it needed), and small forms that are neutral or would revert upstream (the
`OOLITE_SDL` guards, the `STRINGIFY` fallback, the `#endif`/`#ifdef` pair in `OOPlanetDrawable.cpp`,
the include sets).

## How to review

Read the four commits; each names its files. `git diff --shortstat` against 024 is under 200
lines. No existing assertion changes; one test is added.

## Test changes **(gen)**

The tests move to upstream's engine API with the code; each changed test is listed in `specs/002-seriesb-rebase-stack/series/test-changes.md` (spec FR-015).

## Verified **(gen)**

Windows x64, `57a0c89a9e`, 2026-11-03.

| Check | Result |
|---|---|
| build_clang | pass |
| build_gcc | n/a: does not build with GCC yet (exit 1); the parent does not either |
| clang_format | pass |
| component | n/a: no component scenario touched |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | pass: every changed test is in the test ledger (FR-015) |
| unit | pass: oofnd, core, headers |
| warnings_clang | pass: 0 warnings |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
