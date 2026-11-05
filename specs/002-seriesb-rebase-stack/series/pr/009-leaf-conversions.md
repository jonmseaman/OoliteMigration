# Drop gnustep-base, then convert the first classes to C++: maths, leaf utilities, OXP verifier

**Series:** step 9 of 24 · base `seriesb/008-selector-families` · next `seriesb/010-module-conversions` **(gen)**

**Replays:** `series/011-leaf-conversions` (old 11 of the master-based series) · 29.7k src, 18.1k tests, 32 other changed lines; 1.8k lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

This step has two parts. The scripting layer is #768's QuickJS-ng binding before and after it.

The first part finishes removing Foundation:
- The game compiles with `oofnd`'s Objective-C flags, so every `@"..."` literal is an
  `OOConstantString`, and `main()` installs the runtime floor (`OOObjCInstallFloor()`) before the
  first message to a literal.
- `gnustep-base` comes off the Windows link line and out of `ShellScripts/Windows/install_deps.sh`,
  leaving libobjc2. `post_build.sh` and `run_oolite.sh` treat `GNUstep.conf` as optional.
- The last boundary headers (`OOFoundationBridge.h`, `OOStringBridge.h`, `OOPListView.h`,
  `OOObjectGNUstepBridge`) and `OOCollectionExtractors` are deleted, and so is `OOMusic.mm`, a
  stub that was not in the build.
- #768's `poc/` harness moves off GNUstep: it builds against `oofnd`, libobjc2 and the game's
  QuickJS-ng, so it now builds and runs on Windows (the "Linux only" error is gone). A new harness
  script, `poc/tests/primitive_property.js`, pins #768's QuickJS-ng patch that lets strict code
  set a property on a primitive without a TypeError.

The second part starts converting classes from Objective-C to C++20. Files with no class get a plain
suffix: `OOVoxel` becomes `.c`, and `OOQuaternion`, `OOIsNumberLiteral` and `OOMouseInteractionMode`
become `.cpp`. The first classes become C++ classes that derive from `oo::RefCounted`, held by
`oo::Ref<T>`:
- maths: `OOVector`, `Octree`, `CollisionRegion`;
- leaf utilities: `OOColor`, `OOCache`, `OORoleSet`, `OOProbabilitySet`, `OOPriorityQueue`,
  `OOCommodities`, `OOEquipmentType`, `OOCharacter`, `OOWeakReference`, `OOWeakSet` and others;
- the OXP verifier's stage hierarchy;
- the roots of the Materials hierarchy (`OODrawable`, `OOMaterial`), with #756's
  `OO_DEBUG_MONITOR_ENABLED` guards on their debug members;
- `OOSDLJoystickManager`, on #742's layout: the SDL decoders stay in the SDL subclass and take
  SDL's event types. They stay Objective-C for now, in a category of its bridge, because they use
  `OOJoystickManager`'s state;
- the first files of #768's binding: `OOJSVector`, `OOJSQuaternion`, `OOJSFunction`, `OOJSTimer`.
  As in #768, `OOJSVector` and `OOJSQuaternion` keep no conversion statistics. #768's
  native-wrapper macros (`OOJS_NATIVE_ENTER`/`EXIT` and the profiling pairs) become a C++ `try`, a
  `catch (...)` and scope guards; the handler is in the new `OOJSEngineNativeWrappers.mm`.

While unconverted code still messages a class, the C++ class is `cxx::X`. A thin Objective-C bridge
with the old name (`X+ObjCBridge.h/.mm`, 34 pairs here) forwards each method to it.
`oo::ObjCPeers` (`oofnd/objc/OOObjCPeer.h`, tested by the new `tests/unit/oofnd/test_objc_peer.mm`)
keeps one bridge object per C++ object, so identity and equality still hold.

`OOProfilingStopwatch`'s Windows `timeGetTime` path now takes a signed 32-bit difference.

A new meson suite, `core` (`tests/unit/core`), has 57 test files: one per converted class, plus
`test_OOOpenGLOnly` (#748's `OOOpenGLOnly.h`) and `test_OoliteEquipmentControlScript`, which runs
`oolite-equipment-control.js` on QuickJS-ng's own API and pins #369's fix. Like `oofnd`, the suite
is built only when `deployment_release` is off, and only on Windows.

## Why

The first part ends the Foundation removal that steps 6–8 prepared. Once gnustep-base is gone, the
only Objective-C left is the language and the libobjc2 runtime. The harness moves with it because
it linked gnustep-base too.

The class conversion starts with the leaves because nothing they depend on is still Objective-C,
so each can convert on its own behind a bridge. `OOColor` and the verifier stages set the house
style (names, `Ref` ownership, the bridge and its test) that steps 10–13 follow. The maths files and
`OXPVerifier` have few dependants and their own test data, which makes them the safest place to
settle that style.

The stopwatch fix is needed by the new `test_OOProfilingStopwatch`: on #768's code, subtracting two
unsigned `DWORD`s turned a reversed interval into about 49.7 days.

## Behaviour changes

- A C++ exception thrown inside a JavaScript native is reported to the script as
  `Native exception: <what()>`. Before, the Objective-C `@catch (id)` could not catch it and the
  process terminated. Objective-C exceptions are reported as before. Pinned by
  `tests/unit/core/test_OOJSVector.mm` (`nativeCxxExceptions`), with matching checks in
  `test_OOJSQuaternion.mm` and `test_OOJSClock.mm`.
- On Windows, `OOHighResTimeDeltaInSeconds(end, start)` with `end` before `start` is negative. It
  used to wrap to about 49.7 days. Pinned by `tests/unit/core/test_OOProfilingStopwatch.mm`
  (`deltaInSeconds`).
- In description-string expansion, a replacement of `"\x7F"` eats the character after it. At the
  very end of a string there is no such character. Upstream's expander then failed an assertion and
  raised out of `OOExpandDescriptionString`; now it eats nothing. Pinned by the `\x7F` regression
  block in `tests/unit/expander/test_string_expander.mm`, which meson does not build, so
  `tests/run.sh` does not run it.
- The warning for a string-expansion override that is neither a string nor a number, and the error
  for such a value in `descriptions.plist`, print the value itself, where they printed
  `<ClassName 0x...>` of its Foundation object. This is log text only; not pinned by a test.

## How to review

For the first part:

```
git diff seriesb/008-selector-families seriesb/009-leaf-conversions -- src/meson.build \
    src/meson/windows/meson.build src/SDL/main.mm meson.build src/Core/Scripting/poc
```

The rest of it is deletions; `git grep` for the deleted headers' names on
`seriesb/009-leaf-conversions` finds only comments. `tests/unit/oofnd/test_objc_floor.mm` (from
step 4) covers the floor that `main()` now installs.

For the conversions, start with the house-style exemplar: `src/Core/OOColor.h` / `OOColor.mm` (the
C++ class), `OOColor+ObjCBridge.h/.mm` (the bridge) and `tests/unit/core/test_OOColor.mm`. The rule
is "bodies verbatim but for message syntax":
- `[x foo:a bar:b]` becomes `x->foo(a, b)`;
- `[[X alloc] init]` becomes `oo::makeRef<X>()`;
- `BOOL`/`YES`/`NO` become `bool`/`true`/`false`;
- a message that may go to nil becomes a null-guarded call that returns what nil did.

To spot-check another class, compare its old `@implementation` on `seriesb/008-selector-families`
with its C++ member functions here, method by method. Check that its bridge is a one-line forwarder
per method of the old `@interface`, then read its `tests/unit/core/test_X.mm`. Other exemplars:
- `src/Core/OXPVerifier/OOOXPVerifierStage.*`: a class hierarchy with Objective-C subclasses;
- `src/Core/Materials/OOMaterial.*` and `src/Core/OODrawable.*`: a module of hierarchies;
- `src/Core/Scripting/OOJSVector.*`: a binding file, keeping #768's natives, class registry and
  `JSValue` ownership;
- `src/Core/Scripting/OOJavaScriptEngine.h` and `OOJSEngineNativeWrappers.mm`: the wrapper macros.

The binding tests make a QuickJS-ng runtime and context and use #768's API directly
(`JS_NewRuntime`, `JS_Eval`, `JS_FreeValue`).

Edits to existing tests:
- `tests/unit/oofnd/test_objc_description.mm` loses its cases for the forwarding to legacy id-typed
  `-description` overrides and for the foreign-root fallback, together with the code they tested.
- `tests/gui` (`test_g2`, `test_g6`, `test_g8`, `test_g9`): source-text guards accept either the
  Objective-C spelling of a line or the C++ spelling it now has. The value each guard checks is
  unchanged.
- `tests/unit/expander` and `tests/unit/sysdesc` (not built by meson) get local copies of the
  deleted bridge conversions. `test_string_expander.mm`'s two `descriptions.plist` digests are
  re-captured after #747 changed that file.

## Verified **(gen)**

Not verified at this branch's tip (`c455bb32cb`) yet: the last record is for `81a1b9d7d3` (2026-11-02), an earlier build of this step.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
