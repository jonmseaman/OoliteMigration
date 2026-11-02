# Drop gnustep-base, then convert the first classes to C++: maths, leaf utilities, OXP verifier

**Series:** step 10 of 25 · base `series/009-selector-families` · next `series/011-module-conversions` **(gen)**

**Chapter:** P3 · 2.4 delete libgnustep-base, 3.1 oomath, 3.2 OXPVerifier, 3.3 leaf utilities · history `66914fbbed`..`67027c84d1` (61 merges) · 28.5k src, 17.8k tests, 20 other changed lines; 1.8k lines in deleted files **(gen)**

## What this changes

This step has two parts.

The first part finishes removing Foundation. The game now compiles with `oofnd`'s Objective-C flags,
so every `@"..."` literal is an `OOConstantString`, and `main()` installs the runtime floor
(`OOObjCInstallFloor()`) before the first message to a literal. `gnustep-base` comes off the Windows
link line and out of `ShellScripts/Windows/install_deps.sh`, leaving only libobjc2. The last
boundary headers (`OOFoundationBridge.h`, `OOStringBridge.h`, `OOPListView.h`,
`OOObjectGNUstepBridge`) and `OOCollectionExtractors` are deleted.

The second part starts converting classes from Objective-C to C++20. Files with no class get a plain
suffix: `OOVoxel` becomes `.c`, and `OOQuaternion`, `OOIsNumberLiteral` and `OOMouseInteractionMode`
become `.cpp`. The first classes are rewritten as C++ classes that derive from `oo::RefCounted`, held
by `oo::Ref<T>`:
- maths: `OOVector`, `Octree`, `CollisionRegion`;
- leaf utilities: `OOColor`, `OOCache`, `OORoleSet`, `OOProbabilitySet`, `OOPriorityQueue`,
  `OOCommodities`, `OOEquipmentType`, `OOCharacter`, `OOWeakReference`, `OOWeakSet` and others;
- the OXP verifier's stage hierarchy;
- the roots of the Materials hierarchy (`OODrawable`, `OOMaterial`);
- the first JavaScript bindings (`OOJSVector`, `OOJSQuaternion`, `OOJSFunction`, `OOJSTimer`).

A class that unconverted code still messages is `cxx::X`. A thin Objective-C facade of the old name
(`X+ObjCBridge.h/.mm`, 36 of them here) forwards each method, and `oo::ObjCPeers`
(`oofnd/objc/OOObjCPeer.h`) keeps one facade per C++ object so identity and equality still hold. A
new meson suite, `core` (`tests/unit/core`), gets 55 test files, one per converted class.

## Why

The first part is the end of the Foundation removal that steps 7–9 prepared. Once gnustep-base is
gone, the only Objective-C left is the language and the libobjc2 runtime. The class conversion
starts with the leaves because nothing they depend on is still Objective-C, so each can convert on
its own behind a facade. `OOColor` and the verifier stages set the house style (names, `Ref`
ownership, the facade and its test) that steps 11–14 follow. The maths files and `OXPVerifier` have
few dependants and their own test data, which makes them the safest place to settle that style.

## Behaviour changes

- In description-string expansion, a replacement of `"\x7F"` eats the character after it. At the
  very end of a string there is no such character. Upstream's engine then failed an assertion and
  raised out of `OOExpandDescriptionString`; now it eats nothing. Pinned by
  `tests/unit/expander/test_string_expander.mm`, which isn't registered in meson, so
  `tests/run.sh` does not run it.
- The string-expansion warning for an override value that is neither a string nor a number prints
  the value itself, where it used to print `<ClassName 0x...>` of its Foundation object. This is
  log text only, and no test pins it.

## How to review

For the first part, read the `src/meson.build`, `src/meson/windows/meson.build` and
`src/SDL/main.mm` hunks. The rest of it is deletions, and `git grep` for the deleted headers' names
should find only comments. `tests/unit/oofnd/test_objc_floor.mm` (from step 5) covers the floor that
`main()` now installs.

For the conversions, start with the house-style exemplar: `src/Core/OOColor.h` / `OOColor.mm` (the
C++ class), `OOColor+ObjCBridge.h/.mm` (the facade) and `tests/unit/core/test_OOColor.mm`. The rule
is "bodies verbatim but for message syntax":
- `[x foo:a bar:b]` becomes `x->foo(a, b)`;
- `[[X alloc] init]` becomes `oo::makeRef<X>()`;
- `BOOL`/`YES`/`NO` become `bool`/`true`/`false`;
- a message that may go to nil becomes a null-guarded call that returns what nil did.

To spot-check another class, compare its old `@implementation` on the base with its C++ member
functions here, method by method, and check that its facade is a one-line forwarder per method of
the old `@interface`. Then read the class's `tests/unit/core/test_X.mm`. Its expectations were
written against the Objective-C class before conversion. Other exemplars worth reading are
`src/Core/OXPVerifier/OOOXPVerifierStage.*` (a class hierarchy with Objective-C subclasses),
`src/Core/Materials/OOMaterial.*` and `OODrawable.*` (a module of hierarchies) and
`src/Core/Scripting/OOJSVector.*` (a JavaScript binding).

The `tests/gui` edits (`test_g2`, `test_g6`, `test_g8`, `test_g9`) widen source-text guards so they
accept either the Objective-C spelling of a line or the C++ spelling it now has. The value each
guard checks is unchanged.

## Verified **(gen)**

Windows x64, `8607b075cf`, 2026-11-02.

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
| unit | pass: oofnd, core |
| warnings_clang | pass: 0 warnings |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
