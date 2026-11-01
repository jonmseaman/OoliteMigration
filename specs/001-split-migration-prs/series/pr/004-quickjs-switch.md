# Run the game on QuickJS-ng and remove SpiderMonkey and NSPR

**Series:** step 4 of 25 · base `series/003-objective-cxx` · next `series/005-oofnd-core` **(gen)**

**Chapter:** P1 · 1.4 differential test, 1.5 delete SpiderMonkey · history `3b6aec8c6f`..`a7e3ed1efc` (6 merges) · 11.8k src, 4 tests, 235 other changed lines; 1.5k lines in deleted files **(gen)**

## What this changes

The game now runs its scripts on QuickJS-ng. `ooscript/JSEngine_quickjs.cpp` fills in the rest of
the façade and is compiled into the game. QuickJS-ng is linked statically from the meson subproject
added in step 2, so the build fetches it through `subprojects/quickjs-ng.wrap`. The SpiderMonkey
backend, its unit test, the `js_backend` and `oo_javascript_trace` options, the NSPR dependency, and
the Mozilla JS install steps for Windows, Linux and CI are removed.

The last direct engine users now speak only `ooscript` types: `OOJavaScriptEngine.{h,mm}`, the debug
console, and the entity methods whose signatures took `jsid`/`jsval` (`-doScriptEvent:` and its family). Step 2's
compatibility casts are gone. `OOJavaScriptEngine.h` no longer includes `jsapi.h`, and the `OOJS_*`
macros expand to `ooscript::CallArgs` accessors. `Resources/Scripts/oolite-global-prefix.js` gains
guarded polyfills for the Mozilla-only `toSource()`, `String.prototype.quote()` and `uneval()`.
Each one is installed only when the engine lacks it.

## Why

SpiderMonkey 1.8.5 is the dependency that blocks newer toolchains and Apple Silicon. Once every
call site went through the façade in step 2, replacing the engine is a backend change. This step
comes after step 3 because removing the casts means editing binding files that only became
Objective-C++ there. It also comes before the Foundation work in steps 5 and later, so those steps
are tested on the engine the game will ship with.

`-ffp-contract=off` moves from project to global arguments, so it also reaches the QuickJS-ng
subproject, whose number formatting produces floats that scripts and tests observe. The subproject
is built at the game's pinned `-O2` for the same reason.

## Behaviour changes

- **The script engine is QuickJS-ng, not SpiderMonkey.** Scripts that rely on Mozilla-only syntax,
  such as legacy generators or `for each`, no longer parse. The façade on QuickJS-ng is tested by
  `tests/unit/test_jsengine_quickjs.cpp`, which is not in the meson build at this step. Gameplay
  through the engine is tested by the step-1 tiers, e.g.
  `tests/component/features/s1_police_kills_pirate.feature` and
  `tests/gui/test_g4_start_game_hud_renders.py`.
- **`toSource()`, `quote()` and `uneval()` are available as script polyfills** (in
  `oolite-global-prefix.js`). They are best-effort formatters for logging data objects, not full
  source reflection. No test in this tree exercises them.
- **Debugger features in the debug console are reduced.** The façade's debugging section lets a
  backend do less: QuickJS-ng gives file and line frames only, no scope-variable listing and no
  debugger hook. Stack dumps carry less detail. No test pins this.
- **The `oo_javascript_trace` build option is gone**, along with `MOZ_TRACE_JSCALLS`.

## How to review

1. Start with `src/Core/Scripting/ooscript/JSEngine_quickjs.cpp`: the step-2 file plus the 600
   lines added here. Then read the `JSEngine.hpp` additions: request suspend/resume, string
   comparison, function compilation, regexp flags and the debugging section. The README's retarget
   map gains a row for each.
2. `src/Core/Scripting/OOJavaScriptEngine.mm`: runtime and context setup, error reporting and GC
   rooting on the new engine.
3. The build: `src/meson.build` (static subproject, `debugoptimized` with `b_ndebug`), `meson.build`
   (`add_global_arguments`), and `src/meson/{linux,windows}/meson.build`.

The binding files (`src/Core/Scripting/OOJS*.mm`, about 6k of the changed lines) are mechanical:
they delete the step-2 shim functions and the casts, and declare the locals with `ooscript` types.
The exception is `OOJSShip.mm`, which was still Objective-C at step 2: it is moved onto the façade
for the first time here, so read it in full.
To spot-check one, diff it against its base and confirm that every removed line is a shim or a
`reinterpret_cast`, and that the function bodies keep their logic. To check the whole tree for
leftover engine API, run
`git grep -nE '\bJS_[A-Z]|jsapi\.h' -- src ':!src/Core/Scripting/ooscript/JSEngine_quickjs.cpp'`.
It should find only `ooscript/README.md`, the façade's own engine-to-façade map.

The Linux build files are edited, but no Linux build was run for this step, and macOS is not
verified.

## Verified **(gen)**

Not verified yet.

macOS (Phase 5: not converted) and Linux are not verified by this series.
