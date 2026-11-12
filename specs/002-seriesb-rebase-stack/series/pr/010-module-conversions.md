# Convert scripting, entities, audio and materials classes to C++

**Series:** step 10 of 26 · base `seriesb/009-leaf-conversions` · next `seriesb/011-first-slices` **(gen)**

**Replays:** `series/012-module-conversions` (old 12 of the master-based series) · 38.9k src, 41.8k tests, 96 other changed lines; 2.4k lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

This step converts the next layer of classes to C++ in the house style of step 9, module by module:
- Materials: textures, texture loaders and generators, shader material, program and uniforms.
  #766's GLSL 3.30 → 1.20 translator becomes C++ (`std::regex`) in `OOShaderProgram`, and
  `OOFoundation.h` defines `OOLITE_MACOS` for it;
- audio: the `OOAL*` sound family, `OOSoundSource`, `OOMusicController`;
- #768's binding files and the script classes: `OOScript`, `OOPListScript`, the `OOJS*` bindings,
  the profiler classes, the interface, populator and GUI-key definitions, `SystemInfo` and the debug
  monitor. They keep #768's natives, `JSClassID` registry (`-oo_jsClassID` answers the class's
  registered ID), exotic property hooks, `JSValue` ownership and monitor protocol. `OOJSFont` and
  `OOConstToJSString` become plain `.cpp`;
- the entity base: `Entity`, `OOEntityWithDrawable`, and the leaf entities (the effects, planets,
  sun, sky, wormholes, waypoints);
- the debug monitor, the TCP console client and the JavaScript console;
- `AI`, `OOJoystickManager`, `OOShipRegistry` and the remaining OXP verifier stages.
  #742's SDL joystick decoders become members of the C++ `OOSDLJoystickManager`, and #783's
  GUI-button map (`guibuttonmap`, `setGuiFunctionForButton`, `unsetGuiButtonFunction`,
  `guiButtonFunctions`) becomes members of the C++ `OOJoystickManager`.

#768's `OOJavaScriptEngine.h` is split. Its plain C++ part (reporters, converters, class
registration, the time limiter, the read-only const rewriter `OOJSLegacyConstRewriter()`, return
macros) is the new `OOJSEngineCore.h`, which C++ binding
files include directly. The native-wrapper macros, with #768's names, move into
`OOJSEngineNativeWrappers.h`, which the core includes. `OOJavaScriptEngine.h` includes the core.

The converted entity, drawable, material and texture headers and the Entity, texture and debug
bridges keep #756's `OO_DEBUG_MONITOR_ENABLED` guards. `GameController` and its
`OOLITE_MAC_COCOA_UI` branches (#737, #766) are not changed by this step.

There are 73 new bridge implementations (`X+ObjCBridge.mm`), 58 with their own header, and 99 new
test files in `tests/unit/core`. Among them, `test_OOJSTimeLimiter` runs the limiter cases on the
real engine, and `test_OOJoystickDecoding` pins where #742 put the SDL decoding.

Four pieces of unused code are deleted rather than converted. The old `PlanetEntity` and
`TextureStore` sat under `#if !NEW_PLANETS`, which is off. `OOEnvironmentCubeMap` was not in the
build, and nothing used `OOSpatialReference`.

## Why

These modules depend on the leaves converted in step 9 (colours, vectors, caches, the Materials
roots). Little depends on them except the large classes (`ShipEntity`, `PlayerEntity`, `Universe`,
`HeadUpDisplay`). So they convert next, and the large classes get converted dependencies to build
on in steps 11–13. The engine header is split so that a binding file can be plain C++ when it
declares no Objective-C. Each module has its own exemplar, because each raised a pattern the leaves
didn't:
- `Entity`: a root whose ivars subclasses and callers read directly;
- `OOALSound`: a root that is a class cluster;
- `OODebugMonitor`: a singleton whose superclass is Objective-C;
- `OOJSSystemInfo`: a #768 binding with exotic property hooks.

## Behaviour changes

- The SDL double-click is timed from the mouse-up events' own SDL timestamps. It used to use the
  time the event poll started, so a slow frame between the two releases could turn a real
  double-click into two single clicks. Pinned by `tests/gui/test_double_click_timing.py` (both
  cases; they check the source text, since no offline test can stall a poll).
- `for (p in info)` over a `SystemInfo` object lists the system data keys. With #768's hooks it
  listed nothing, because QuickJS-ng 0.17's for..in drops every key `JS_HasProperty()` denies; a
  `has_property` hook now answers for them. So `'economy' in info` is `true`, where SpiderMonkey gave
  `false`; `hasOwnProperty('economy')` stays `false`. Pinned by
  `tests/unit/core/test_OOJSSystemInfo.mm` (`systemData`).
- A C++ exception thrown inside the `Manifest` and `MissionVariables` property hooks is reported to
  the script as `Native exception: <what()>`, where the `@catch (id)` it replaces let the process
  terminate. Pinned by `test_OOJSManifest.mm` and `test_OOJSMissionVariables.mm`
  (`nativeExceptions`).
- `clearMappings()` resets the GUI-button table along with the axis and button tables. #783's
  version leaves it all 0 (`BUTTON_INCTHRUST`), so every button with no GUI function also drove
  `BUTTON_INCTHRUST`, and a save and reload bound `BUTTON_INCTHRUST` to the last stick's last
  button, unbinding the player's own increase-thrust button. The bug is in upstream too. Pinned by
  `savesAndLoadsSettings` in `tests/unit/core/test_OOJoystickManager.mm`.

## How to review

```
git diff --stat seriesb/009-leaf-conversions seriesb/010-module-conversions
```

Read one exemplar per module before its files:
- `src/Core/Entities/Entity.h` and `Entity+ObjCBridge.h`: the header comment explains who owns the
  C++ part and how unconverted code reads entity state through `_cxxEntity`;
- `src/Core/Entities/OOLightParticleEntity.*`: an entity class with Objective-C subclasses;
- `src/Core/OOALSound.*`: the audio cluster;
- `src/Core/Debug/OODebugMonitor.*`: the debug singleton;
- `src/Core/Scripting/OOJSEngineCore.h` and `OOJSEngineNativeWrappers.h`: the split engine header;
- `src/Core/Scripting/OOJSSystemInfo.*` and `EntityOOJavaScriptExtensions.*`: #768's binding
  patterns (exotic hooks, class IDs, the entity's owned `_jsSelf`) in the converted form.

Other binding files follow `OOJSVector`, which step 9 converted. Every other file follows its
module's exemplar. Spot-check the same way as step 9: compare the old methods with the new
members, then read the class's `tests/unit/core/test_X.mm`. In unconverted callers, the main
mechanical edit is `ent->_cxxEntity->field` where the code used to read an ivar directly. The
compiler finds each of these, because the ivar no longer exists.

For the translator, compare `OOTranslateGLSL330To120` in `src/Core/Materials/OOShaderProgram.mm`
with the Objective-C function it replaces; `test_OOShaderProgram.mm`'s `translateGLSL330To120` and
`translateGameShadersGLSL330To120` check its output.

The double-click change is the hunk in `src/SDL/MyOpenGLView+Input.mm` that sets `timeOfClick` from
`mbtn_event->timestamp`, and the one in `MyOpenGLView.mm` that starts `timeIntervalAtLastClick` on
`SDL_GetTicksNS()`. The GUI-button reset is the one added `memset` in
`OOJoystickManager::clearMappings()` (`src/Core/OOJoystickManager.mm`). `tests/component/steps/world_steps.py` and
`tests/component/test_world_setup_clear.py` fix a harness race: clearing the system before
counting ships now repeats until a clear-then-count sees only the player. No game code changes for
that.

## Verified **(gen)**

Not verified at this branch's tip (`d4bbf9e343`) yet: the last record is for `2e613e4a44` (2026-11-02), an earlier build of this step.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
