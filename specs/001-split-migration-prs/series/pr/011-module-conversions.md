# Convert scripting, entities, audio and materials classes to C++

**Series:** step 11 of 25 · base `series/010-leaf-conversions` · next `series/012-first-slices` **(gen)**

**Chapter:** P3 · 3.4 Materials, 3.5 audio, 3.6 scripting bindings, 3.7 entities · history `1964f76209`..`ab5dc6cd72` (120 merges) · 38.9k src, 40.0k tests, 112 other changed lines; 2.4k lines in deleted files **(gen)**

## What this changes

This step converts the next layer of classes to C++ in the house style of step 10, module by module:
- Materials: textures, texture loaders and generators, shader material, program and uniforms;
- audio: the `OOAL*` sound family, `OOSoundSource`, `OOMusicController`;
- the JavaScript bindings and script classes: `OOScript`, `OOPListScript`, the `OOJS*` binding
  files, and the engine's time-management and core helpers;
- the entity base: `Entity`, `OOEntityWithDrawable`, and the leaf entities (the effects, planets,
  sun, sky, wormholes, waypoints);
- the debug monitor, the TCP console client and the JavaScript console;
- `AI`, `OOJoystickManager`, `OOShipRegistry` and the remaining OXP verifier stages.

73 classes still messaged from Objective-C get an `X+ObjCBridge` facade, and 97 test files are added
to `tests/unit/core`. Three pieces of compiled-out code are deleted rather than converted. The old
`PlanetEntity` and `TextureStore` sat under `#if !NEW_PLANETS`, which is off, and
`OOEnvironmentCubeMap` was not in the build.

## Why

These modules depend on the leaves converted in step 10 (colours, vectors, caches, the Materials
roots) and nothing much depends on them except the large classes (`ShipEntity`, `PlayerEntity`,
`Universe`, `HeadUpDisplay`). So they convert next, and the large classes get converted dependencies
to build on in steps 12–14. Each module has its own exemplar, because each raised a pattern the
leaves didn't:
- `Entity`: a root whose ivars subclasses and callers read directly;
- `OOALSound`: a root that is a class cluster;
- `OODebugMonitor`: a singleton whose superclass is Objective-C;
- `OOJSEngineTimeManagement`: a category that only its own file sends.

## Behaviour changes

- The SDL double-click is timed from the mouse-up events' own SDL timestamps. It used to use the
  time the event poll started, so a slow frame between the two releases could turn a real
  double-click into two single clicks. Pinned by `tests/gui/test_double_click_timing.py`.
- macOS only, not built or verified here: upstream's `GameController` Cocoa-UI branches
  (`OOLITE_MAC_COCOA_UI`, #766) are not in this step, because the Mac methods moved into a
  `GameController (MacOSX)` category. Step 23 restores them. No test pins this.

## How to review

Read one exemplar per module before its files:
- `src/Core/Entities/Entity.h` and `Entity+ObjCBridge.h`: the header comment explains who owns the
  C++ part and how unconverted code reads entity state through `_cxxEntity`;
- `src/Core/Entities/OOLightParticleEntity.*`: an entity class with Objective-C subclasses;
- `src/Core/OOALSound.*`: the audio cluster;
- `src/Core/Debug/OODebugMonitor.*`: the debug singleton;
- `src/Core/Scripting/OOJSEngineTimeManagement.*`: a category only its own file sends, which becomes
  file-local functions.

The JavaScript binding files follow `OOJSVector`, which step 10 converted.

Every other file follows its module's exemplar. Spot-check the same way as step 10: compare
the old methods with the new members, then read the class's `tests/unit/core/test_X.mm`. In
unconverted callers, the main mechanical edit is `ent->_cxxEntity->field` where the code used to
read an ivar directly. The compiler finds each of these, because the ivar no longer exists.

The double-click change is the hunk in `src/SDL/MyOpenGLView+Input.mm` that sets `timeOfClick` from
`mbtn_event->timestamp`. `tests/component/steps/world_steps.py` and
`tests/component/test_world_setup_clear.py` fix a harness race: clearing the system before
counting ships now repeats until a clear-then-count sees only the player. No game code changes for
that.

## Verified **(gen)**

Not verified yet.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
