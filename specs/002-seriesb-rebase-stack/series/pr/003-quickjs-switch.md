# Put the game's JavaScript behind an engine façade on QuickJS-ng, replacing the PRs' binding; compile as Objective-C++

**Series:** step 3 of 25 · base `seriesb/002-safety-net` · next `seriesb/004-oofnd-core` **(gen)**

**Replays:** `series/005-quickjs-switch` (old 3, 4, 5 of the master-based series) · 30.6k src, 920 tests, 7.0k other changed lines; 21.6k lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

This step replaces the scripting layer that steps 1 and 2 inherit from upstream #768's branch
with the fork's own: `src/Core/Scripting/ooscript/JSEngine.hpp`, a C++ interface to the JavaScript
engine (namespace `ooscript`: `Value`, `Object`, `Context`, `ClassDef`, `PropertySpec`,
`FunctionSpec`, `CallArgs`, rooting and exceptions), with one backend,
`ooscript/JSEngine_quickjs.cpp`, on QuickJS-ng. The binding files under `src/Core/Scripting/` use
the `ooscript` types instead of calling QuickJS-ng directly, and #768's proof-of-concept tree
(`src/Core/Scripting/poc/`), `oolite-quickjs-compat.js` and its QuickJS-ng patch are removed.

The step also renames every Objective-C source file in `src/` from `.m` to `.mm` (207 renames), so
the whole game compiles as Objective-C++. It squashes three steps of the master-based series (the
façade, Objective-C++, and the engine switch), because on #768's base the engine is already
QuickJS-ng and the intermediate SpiderMonkey backend has nothing to run on. Upstream's two
stand-alone tools, `tools/js-parity/` and `tools/oxp-upgrade/`, are kept as #768 has them.

## Why

Steps 4 to 24 replay the fork's migration, which was written against this façade: the Foundation
and Objective-C conversions call `ooscript` types, not an engine API. Putting the façade back here
lets those steps replay as they were built and tested, with their own tests unchanged. Step 25
then moves the finished C++ game onto #768's binding in one step, where the binding and its tests
can be reviewed together.

Objective-C++ comes in the same step because the façade is C++ and the later steps put C++ types
inside Objective-C classes.

## Behaviour changes

Measured against the master-based series' step 5, none intended: this step's tree is that step's
tree, with #768's two tools kept. Against its parent, which runs #768's binding, the differences
are the ones step 25 reverses; the plan's Notes ("Behaviour changes that follow #768") list them.
The main ones: game classes keep their `[object Vector3D]`-style tags, and assignments that
#768 rejects (an invalid manifest value, a strict-mode write to a read-only property) are reported
and ignored instead of throwing. The step-2 component and GUI tiers run against this step
unchanged.

## How to review

1. Read `src/Core/Scripting/ooscript/JSEngine.hpp`, then `ooscript/README.md`, whose retarget map
   lists the façade call for each engine function.
2. Read `src/Core/Scripting/OOJSVector.mm` as the worked example; the other binding files repeat
   its pattern.
3. Review `ooscript/JSEngine_quickjs.cpp` as the mapping onto QuickJS-ng.

The `.m` → `.mm` renames are mechanical. To see only the renamed files that changed, run
`git diff -M --name-status seriesb/002-safety-net seriesb/003-quickjs-switch | grep -v '^R100'`.
To check that nothing outside the façade calls the engine, run
`git grep -nE '\bJS_[A-Z]' -- src ':!src/Core/Scripting/ooscript'`.

## Differences from the old step **(gen)**

Where this step's change differs from `series/005-quickjs-switch`'s, and why:

- `.eslintrc.json`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `.github/workflows/build-all.yaml`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `.github/workflows/test_builds.yaml`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `.gitignore`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `README.md`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `Resources/Config/logcontrol.plist`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `Resources/Scripts/oolite-quickjs-compat.js`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `ShellScripts/Linux/install_mozilla_js.sh`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `ShellScripts/Linux/install_package_fn.sh`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `ShellScripts/Linux/install_packages_root.sh`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `ShellScripts/Windows/install_deps.sh`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `ShellScripts/macOS/build_mozilla_js.sh`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `ShellScripts/macOS/install_packages.sh`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `ShellScripts/macOS/mozilla_js_arm64.patch`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `installers/flatpak/space.oolite.Oolite.yaml`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `meson.build`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `meson.options`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/Debug/OODebugMonitor.h`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/Debug/OODebugMonitor.m`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/Debug/OOJSConsole.h`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/Debug/OOJSConsole.m`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/Debug/meson.build`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/Entities/DockEntity.m`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/Entities/Entity.h`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/Entities/OOECMBlastEntity.m`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/Entities/OOVisualEffectEntity.h`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/Entities/OOVisualEffectEntity.m`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/Entities/PlayerEntity.h`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/Entities/PlayerEntity.m`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/Entities/PlayerEntityLoadSave.m`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/Entities/ShipEntity.h`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/Entities/ShipEntity.m`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/Entities/ShipEntityAI.m`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/Entities/StationEntity.m`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/GameController.m`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/GuiDisplayGen.h`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/GuiDisplayGen.m`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/OOCharacter.h`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/OOCharacter.m`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- `src/Core/OOCommodities.m`: the step takes the old step's tree whole: the end tree is develop (spec D1): the fork's façade and QuickJS-ng replace #767/#768's binding and #780's engine-neutral layer, which develop dropped when it merged #780; upstream's two stand-alone tools are kept (research R5)
- ... and 125 more (the manifest lists them all)

## Verified **(gen)**

Windows x64, `a6e785314d`, 2026-11-02.

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
