# Convert scripting, entities, audio and materials classes to C++

**Series:** step 10 of 25 · base `seriesb/009-leaf-conversions` · next `seriesb/011-first-slices` **(gen)**

**Replays:** `series/012-module-conversions` (old 12 of the master-based series) · 39.0k src, 40.6k tests, 112 other changed lines; 2.4k lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

This step converts the next layer of classes to C++ in the house style of step 11, module by module:
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

These modules depend on the leaves converted in step 11 (colours, vectors, caches, the Materials
roots) and nothing much depends on them except the large classes (`ShipEntity`, `PlayerEntity`,
`Universe`, `HeadUpDisplay`). So they convert next, and the large classes get converted dependencies
to build on in steps 13–15. Each module has its own exemplar, because each raised a pattern the
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
  `GameController (MacOSX)` category. Step 25 restores them. No test pins this.

## How to review

Read one exemplar per module before its files:
- `src/Core/Entities/Entity.h` and `Entity+ObjCBridge.h`: the header comment explains who owns the
  C++ part and how unconverted code reads entity state through `_cxxEntity`;
- `src/Core/Entities/OOLightParticleEntity.*`: an entity class with Objective-C subclasses;
- `src/Core/OOALSound.*`: the audio cluster;
- `src/Core/Debug/OODebugMonitor.*`: the debug singleton;
- `src/Core/Scripting/OOJSEngineTimeManagement.*`: a category only its own file sends, which becomes
  file-local functions.

The JavaScript binding files follow `OOJSVector`, which step 11 converted.

Every other file follows its module's exemplar. Spot-check the same way as step 11: compare
the old methods with the new members, then read the class's `tests/unit/core/test_X.mm`. In
unconverted callers, the main mechanical edit is `ent->_cxxEntity->field` where the code used to
read an ivar directly. The compiler finds each of these, because the ivar no longer exists.

The double-click change is the hunk in `src/SDL/MyOpenGLView+Input.mm` that sets `timeOfClick` from
`mbtn_event->timestamp`. `tests/component/steps/world_steps.py` and
`tests/component/test_world_setup_clear.py` fix a harness race: clearing the system before
counting ships now repeats until a clear-then-count sees only the player. No game code changes for
that.

## Differences from the old step **(gen)**

None: the same change as `series/012-module-conversions`.

## Verified **(gen)**

Windows x64, `2e613e4a44`, 2026-11-02.

| Check | Result |
|---|---|
| build_clang | pass |
| build_gcc | n/a: Objective-C with the GNUstep runtime builds with Clang only (upstream too) |
| clang_format | pass |
| component | pass: s1_police_kills_pirate, s2_pirate_attacks_target_registers_attacker, s3_hostile_spawn_drives_ship_into_attack, s4_missile_armed_ship_kills_by_missile, s5_escorts_converge_on_their_mother, s6_damaged_ship_flees, s7_neutral_traffic_is_quiet, s8_destroyed_ships_leave_allships |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | pass |
| unit | pass: oofnd, core |
| warnings_clang | pass: 0 new warnings (0 inherited from the parent, 3 listed in test-warnings.md) |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
