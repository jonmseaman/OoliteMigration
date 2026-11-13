# Convert scripting, entities, audio and materials classes to C++

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 10/28. Replays `series/012-module-conversions`.

## What this changes

- Converts Materials (incl. #766's GLSL 3.30 -> 1.20 translator, now `std::regex` in
  `OOShaderProgram`), audio (`OOAL*`, `OOSoundSource`, `OOMusicController`), `Entity` and the leaf
  entities, the debug monitor and consoles, `AI`, `OOShipRegistry`, the rest of the OXP verifier,
  and `OOJoystickManager` (#742's decoders and #783's GUI-button map become members).
- Converts #768's binding files and script classes, keeping its natives, `JSClassID` registry,
  exotic hooks and `JSValue` ownership. `OOJavaScriptEngine.h` is split: plain C++ in the new
  `OOJSEngineCore.h`, wrapper macros in `OOJSEngineNativeWrappers.h`.
- 73 new bridges (58 with a header) and 99 new tests in `tests/unit/core`, incl.
  `test_OOJSTimeLimiter` and `test_OOJoystickDecoding`. #756's guards kept; `GameController`
  untouched.
- Deletes unused `PlanetEntity`, `TextureStore` (`!NEW_PLANETS`), `OOEnvironmentCubeMap`,
  `OOSpatialReference`.

## Why

These depend only on step 9's leaves, and the large classes converted in steps 11-13 depend on them.

## Behaviour changes

- SDL double-click is timed from the mouse-up events' timestamps (was poll start, so a slow frame
  split a double-click). Pinned by `tests/gui/test_double_click_timing.py` (source-text checks).
- `for (p in info)` on `SystemInfo` lists the system keys and `'economy' in info` is `true` (was
  nothing listed; SpiderMonkey gave `false`); `hasOwnProperty` stays `false`. Pinned by
  `test_OOJSSystemInfo.mm` (`systemData`).
- A C++ exception in the `Manifest`/`MissionVariables` hooks is a script error (was a process
  abort). Pinned by `test_OOJSManifest.mm`, `test_OOJSMissionVariables.mm` (`nativeExceptions`).
- `clearMappings()` resets the GUI-button table (was all `BUTTON_INCTHRUST`, so save/reload unbound
  the player's thrust button; upstream bug too). Pinned by `savesAndLoadsSettings` in
  `test_OOJoystickManager.mm`.

## How to review

Read one exemplar per module first: `Entity.h` + `Entity+ObjCBridge.h` (`_cxxEntity`),
`OOLightParticleEntity.*`, `OOALSound.*`, `OODebugMonitor.*`, `OOJSEngineCore.h`,
`OOJSSystemInfo.*` and `EntityOOJavaScriptExtensions.*`; other bindings follow `OOJSVector`. Rule
as step 9. In callers, `ent->_cxxEntity->field` replaces direct ivar reads (the compiler finds
each).
Compare `OOTranslateGLSL330To120` with the Objective-C original. The behaviour fixes are the
`timeOfClick`/`SDL_GetTicksNS()` hunks in `MyOpenGLView*.mm` and the `memset` in `clearMappings()`.

`git diff --stat seriesb/009-leaf-conversions seriesb/010-module-conversions`

Test edits:
- `tests/component/steps/world_steps.py`, `test_world_setup_clear.py`: fix a harness race
  (clear-then-count repeats until only the player is left); no game change.

## Verified

Not verified at `d4bbf9e343`.
