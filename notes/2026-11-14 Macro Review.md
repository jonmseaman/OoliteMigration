# Macro Review — `oolite-dev/src`

2026-11-14. Every `#define` in `oolite-dev/src`, with one sentence on what it is for and one on whether it could be a feature flag. Read-only review; no code changed.

**Feature flag** here means a switch that turns behaviour or a capability on or off, either as a meson option or as a runtime setting. Verdicts:
- **Yes**: gates optional behaviour (a debug aid, an experimental path, a hard-coded `#if 0/1`).
- **Already**: already driven by a meson option, the buildtype or `NDEBUG`.
- **No**: a constant, key string, helper or guard. The suggested replacement, such as `constexpr` or an inline function, is given where it is obvious.

## Summary

| | Count |
|---|---|
| Files with `#define` | 173 |
| `#define` lines (all) | 1,545 |
| Project macro names (vendored excluded) | 997 |
| Vendored macro names (miniz, tinyexr, stb_image_write, MiniZip) | ~290 |
| Verdict **Yes** | 77 |
| Verdict **Already** | 40 |
| Verdict **No** | 886 |
| Marked unused (no use besides the define) | 68 |

Some names occur in two areas, so the verdict total (1,003) is slightly above 997.

### Findings worth acting on
- **Dead build flags.** `OOLITE_SDL_MAC` is set in `src/meson/darwin/meson.build` but nothing tests it. `OO_EXCLUDE_DEBUG_SUPPORT` is never referenced; the `oo_exclude_debug_support` option only adds `-DNDEBUG`.
- **Obsolete guards that only emit `#warning`.** `ALLOW_PROCEDURAL_PLANETS`, `DOCKING_CLEARANCE_ENABLED`, `WORMHOLE_SCANNER` and `TARGET_INCOMING_MISSILES` in `Core/OOLogHeader.cpp`. These can be deleted.
- **Never-set gates over dead code.** `CACHE_ROUTE_FROM_SYSTEM_RESULTS`, `OOLITE_HAVE_FIXED_THE_ABOVE_DESCRIBED_BUG_WHICH_WE_HAVENT`, `OOMATHS_EXTERNAL_VECTOR_TYPES`, `OOSTOPWATCH_STANDALONE` and `OO_PROFILING_STOPWATCH_MACH_ABSOLUTE_TIME`.
- **Real feature-flag candidates.** These are hard-coded toggles of behaviour, not debug aids: `MASS_DEPENDENT_FUEL_PRICES`, `OO_CACHE_JS_SCRIPTS`, `OO_USE_VBO`, `USE_NEW_SHADER_SYNTHESIZER`, `OOTEXTURE_RELOADABLE`, `SNAPSHOTS_PNG_FORMAT`, `OO_VARIABLE_TORUS_SPEED`, `ALLOW_CUSTOM_VIEWS_WHILE_PAUSED`, `OO_RESOLUTION_OPTION`, `PIRATES_PREFER_PLAYER` and `OO_GAME_DATA_TO_USER_FOLDER`.
- **Runtime checks, not build flags.** `OO_USE_FBO`, `OO_MULTITEXTURE` and `OO_TEXTURE_CUBE_MAP` are derived from GL extension headers and fit a runtime capability check better.
- **Debug-dump clusters.** Many local `DUMP_*`, `DEBUG_*`, `PROFILE*` and `SCRIBBLE` toggles are scattered across files. One meson `oo_debug_dumps` option, or a runtime debug flag, could replace them.
- **Caveats on Yes verdicts.** Some are values chosen by a flag rather than flags themselves: `MAX_JUMP_RANGE`, `PLAYER_MAX_FUEL`, `HYPERSPEED_FACTOR`, `kBaseCharge`, `kMassCharge`, and the `SVGDump*` and `DUMP_*` helpers. The gating symbol is the flag; the macro itself is a `No`.
- **Most macros are constants or key strings.** Of the 886 `No` rows, the bulk are tuning constants and plist key strings (156 in `HeadUpDisplay.h` alone), better as `constexpr` / `constexpr std::string_view`. The `OOEXPAND_MAP_IMPL_n` and JS binding boilerplate are code-generation macros.

Method: `grep` for `#define` across `src/`; vendored code was excluded per hard rule 7. Each project macro was checked against its uses with `grep`. The B chunk (HUD) was classified from name patterns plus a usage grep; its "(unused)" claims were spot-checked and hold.

## File → macro count

Count of `#define` lines per file, highest first. *Vendored* files are third-party C, left as is.

| File | `#define`s |
|---|---|
| `Core/HeadUpDisplay.h` | 156 |
| `SDL/EXRSnapshotSupport/miniz.h` *(vendored)* | 126 |
| `SDL/EXRSnapshotSupport/miniz.cpp` *(vendored)* | 104 |
| `Core/OOStringExpander.h` | 79 |
| `Core/Entities/ShipEntity.h` | 68 |
| `SDL/EXRSnapshotSupport/tinyexr.h` *(vendored)* | 60 |
| `Core/Entities/PlayerEntity.h` | 55 |
| `SDL/stb_image_write.h` *(vendored)* | 40 |
| `Core/Scripting/OOJSEngineCore.h` | 37 |
| `Core/MiniZip/ioapi.h` *(vendored)* | 32 |
| `Core/OOFunctionAttributes.h` | 30 |
| `Core/Universe.h` | 29 |
| `Core/OOFoundation.h` | 24 |
| `Core/Materials/OOPlanetTextureGenerator.cpp` | 23 |
| `Core/Debug/OODebugTCPConsoleProtocol.h` | 23 |
| `SDL/MyOpenGLView.h` | 21 |
| `Core/OOLogHeader.cpp` | 20 |
| `Core/Entities/ShipEntityLoadRestore.cpp` | 20 |
| `Core/OOTextureScaling.cpp` | 17 |
| `Core/Materials/OOStandaloneAtmosphereGenerator.cpp` | 16 |
| `Core/Scripting/OOJSEngineNativeWrappers.h` | 15 |
| `Core/OOJoystickManager.h` | 15 |
| `SDL/main.cpp` | 14 |
| `Core/OXPVerifier/OOPListSchemaVerifier.cpp` | 14 |
| `Core/OOOpenGLExtensionPointers.h` | 14 |
| `Core/OOMathsBase.h` | 14 |
| `Core/Universe.cpp` | 13 |
| `Core/OOOpenGLCheck.h` | 13 |
| `Core/MiniZip/unzip.cpp` *(vendored)* | 13 |
| `Core/HeadUpDisplay.cpp` | 13 |
| `Core/OODebugGLDrawing.h` | 12 |
| `Core/Entities/PlayerEntity.cpp` | 11 |
| `Core/OOStringExpander.cpp` | 10 |
| `Core/Materials/OOTextureInternal.h` | 10 |
| `Core/Entities/OOExhaustPlumeEntity.cpp` | 10 |
| `Core/OOPolygonSprite.cpp` | 9 |
| `Core/MiniZip/unzip.h` *(vendored)* | 9 |
| `Core/GuiDisplayGen.h` | 9 |
| `Core/Entities/OOLaserShotEntity.cpp` | 9 |
| `Core/Scripting/OOJSFrameCallbacks.cpp` | 8 |
| `Core/OOProfilingStopwatch.h` | 8 |
| `Core/OOOpenGLOnly.h` | 8 |
| `Core/OOLogging.h` | 8 |
| `Core/OOCPUInfoEndian.h` | 8 |
| `Core/GameController.h` | 8 |
| `Core/Entities/OORingEffectEntity.cpp` | 8 |
| `Core/OOOpenGL.cpp` | 7 |
| `Core/Entities/OOSunEntity.h` | 7 |
| `Core/OOMatrix.h` | 6 |
| `Core/Entities/OOFlashEffectEntity.cpp` | 6 |
| `Core/OOSystemDescriptionManager.h` | 5 |
| `Core/OOMesh.cpp` | 5 |
| `Core/OOFullScreenController.h` | 5 |
| `Core/Entities/StationEntity.h` | 5 |
| `Core/Entities/SkyEntity.cpp` | 5 |
| `Core/Entities/PlayerEntityStickMapper.h` | 5 |
| `Core/Entities/OOWaypointEntity.cpp` | 5 |
| `Core/Entities/OOExplosionCloudEntity.cpp` | 5 |
| `Core/Entities/Entity.h` | 5 |
| `Core/Scripting/OOJavaScriptEngine.cpp` | 4 |
| `Core/Octree.cpp` | 4 |
| `Core/OOSkyDrawable.cpp` | 4 |
| `Core/OOOpenGL.h` | 4 |
| `Core/OOCache.cpp` | 4 |
| `Core/OOCPUInfo.h` | 4 |
| `Core/MiniZip/ioapi.cpp` *(vendored)* | 4 |
| `Core/Entities/ShipEntity.cpp` | 4 |
| `Core/Entities/PlayerEntityControls.cpp` | 4 |
| `Core/Entities/OOPlanetEntity.cpp` | 4 |
| `Core/Entities/OOECMBlastEntity.cpp` | 4 |
| `Core/Debug/OOJSConsole.cpp` | 4 |
| `oofnd/PrintfFormat.h` | 3 |
| `oofnd/Log.hpp` | 3 |
| `SDL/OOResourcesWin/OOResourcesWin.h` | 3 |
| `Core/OOVector.h` | 3 |
| `Core/OOTrumble.h` | 3 |
| `Core/OOIsNumberLiteral.cpp` | 3 |
| `Core/OOHPVector.h` | 3 |
| `Core/Materials/OOCombinedEmissionMapGenerator.cpp` | 3 |
| `Core/Entities/WormholeEntity.h` | 3 |
| `Core/Entities/PlayerEntityContracts.h` | 3 |
| `Core/Entities/OOStellarBody.h` | 3 |
| `Core/Entities/OOPlasmaShotEntity.cpp` | 3 |
| `Core/Entities/OOPlasmaBurstEntity.cpp` | 3 |
| `Core/Entities/EntityVirtualMembers.h` | 3 |
| `Core/Debug/OODebugTCPConsoleClient.cpp` | 3 |
| `Core/CollisionRegion.h` | 3 |
| `oofnd/objc/OOAssert.h` | 2 |
| `SDL/MyOpenGLView.cpp` | 2 |
| `Core/Scripting/poc/OOJavaScriptEnginePoc.cpp` | 2 |
| `Core/Scripting/OOJSSystemInfo.cpp` | 2 |
| `Core/Octree.h` | 2 |
| `Core/OXPVerifier/OOOXPVerifier.h` | 2 |
| `Core/OOTextureSprite.h` | 2 |
| `Core/OOSoundInternal.h` | 2 |
| `Core/OOPlanetDrawable.cpp` | 2 |
| `Core/OOPlanetData.h` | 2 |
| `Core/OOEncodingConverter.cpp` | 2 |
| `Core/OOConvertCubeMapToLatLong.cpp` | 2 |
| `Core/OOCacheManager.cpp` | 2 |
| `Core/Materials/OOTexture.h` | 2 |
| `Core/Materials/OOTexture.cpp` | 2 |
| `Core/Materials/OOPixMap.h` | 2 |
| `Core/Materials/OOPNGTextureLoader.cpp` | 2 |
| `Core/Materials/OODefaultShaderSynthesizer.cpp` | 2 |
| `Core/Materials/OOConcreteTexture.cpp` | 2 |
| `Core/Entities/WormholeEntity.cpp` | 2 |
| `Core/Entities/PlayerEntityLegacyScriptEngine.cpp` | 2 |
| `Core/Entities/OOQuiriumCascadeEntity.cpp` | 2 |
| `Core/Entities/OOParticleSystem.cpp` | 2 |
| `Core/Entities/OOLightParticleEntity.cpp` | 2 |
| `Core/Entities/OOBreakPatternEntity.h` | 2 |
| `Core/Entities/DustEntity.h` | 2 |
| `Core/Entities/DustEntity.cpp` | 2 |
| `Core/Debug/OOTCPStreamDecoder.cpp` | 2 |
| `Core/Debug/OODebugStandards.cpp` | 2 |
| `oofnd/PList.hpp` | 1 |
| `SDL/stb_image_write.cpp` *(vendored)* | 1 |
| `SDL/EXRSnapshotSupport/tinyexr.cpp` *(vendored)* | 1 |
| `Core/legacy_random.h` | 1 |
| `Core/UniverseVirtualMembers.h` | 1 |
| `Core/Scripting/OOLegacyScriptWhitelist.cpp` | 1 |
| `Core/Scripting/OOJavaScriptEngine.h` | 1 |
| `Core/Scripting/OOJSVisualEffect.cpp` | 1 |
| `Core/Scripting/OOJSTimer.cpp` | 1 |
| `Core/Scripting/OOJSStation.cpp` | 1 |
| `Core/Scripting/OOJSSpecialFunctions.cpp` | 1 |
| `Core/Scripting/OOJSShip.cpp` | 1 |
| `Core/Scripting/OOJSScript.cpp` | 1 |
| `Core/Scripting/OOJSPropID.h` | 1 |
| `Core/Scripting/OOJSPrivateObject.cpp` | 1 |
| `Core/Scripting/OOJSFont.cpp` | 1 |
| `Core/Scripting/OOJSFlasher.cpp` | 1 |
| `Core/Scripting/OOJSExhaustPlume.cpp` | 1 |
| `Core/Scripting/OOConstToJSString.cpp` | 1 |
| `Core/OXPVerifier/OOOXPVerifier.cpp` | 1 |
| `Core/OOTypes.h` | 1 |
| `Core/OOSystemDescriptionManager.cpp` | 1 |
| `Core/OOSoundSourcePool.cpp` | 1 |
| `Core/OOSoundSource.h` | 1 |
| `Core/OOSound.h` | 1 |
| `Core/OOShipRegistry.cpp` | 1 |
| `Core/OOQuaternion.cpp` | 1 |
| `Core/OOOpenAL.h` | 1 |
| `Core/OOMouseInteractionMode.cpp` | 1 |
| `Core/OOMeshToOctreeConverter.cpp` | 1 |
| `Core/OOMesh.h` | 1 |
| `Core/OOMatrix.cpp` | 1 |
| `Core/OOMacroOpenGL.h` | 1 |
| `Core/OOLogOutputHandler.cpp` | 1 |
| `Core/OOJoystickProfile.h` | 1 |
| `Core/OOJoystickProfile.cpp` | 1 |
| `Core/OODebugGLDrawing.cpp` | 1 |
| `Core/OODataFromOXZFile.cpp` | 1 |
| `Core/OOCommodities.h` | 1 |
| `Core/OOCPUInfo.cpp` | 1 |
| `Core/OOALSoundDecoder.h` | 1 |
| `Core/Materials/OOTextureLoader.cpp` | 1 |
| `Core/Materials/OOShaderUniformMethodType.cpp` | 1 |
| `Core/Materials/OOShaderMaterial.h` | 1 |
| `Core/Materials/OOPixMapChannelOperations.cpp` | 1 |
| `Core/Materials/OOMaterialSpecifier.h` | 1 |
| `Core/Materials/OOMaterialConvenienceCreators.cpp` | 1 |
| `Core/Materials/OOConcreteTexture.h` | 1 |
| `Core/Materials/OOBasicMaterial.cpp` | 1 |
| `Core/Entities/StationEntity.cpp` | 1 |
| `Core/Entities/PlayerEntityLoadSave.cpp` | 1 |
| `Core/Entities/PlayerEntityContracts.cpp` | 1 |
| `Core/Entities/Entity.cpp` | 1 |
| `Core/Debug/OOTCPStreamDecoderAbstractionLayer.h` | 1 |
| `Core/Debug/OODebugSupport.h` | 1 |
| `Core/Debug/OODebugFlags.h` | 1 |
| `Core/AI.h` | 1 |

## Build-set and never-set conditional symbols

Symbols tested by `#if`/`#ifdef` but not `#define`d in `src/`, plus the meson-driven project flags.

| Macro                                                       | Where                                                                                                                                    | Purpose                                                                                           | Feature flag?                                                                          |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `ALLOW_PROCEDURAL_PLANETS`                                  | never set — dead; gated at Core/OOLogHeader.cpp:43                                                                                       | Only triggers a #warning; feature no longer optional.                                             | No — never set; obsolete guard, delete the #ifdef.                                     |
| `CACHE_ROUTE_FROM_SYSTEM_RESULTS`                           | never set — dead (Universe.cpp #undefs it); gated at Core/Universe.cpp:9012                                                              | Gates route-result caching in route search.                                                       | Yes — gated code is dead and flagged too slow; delete, not worth an option.            |
| `DEBUG`                                                     | meson.build buildtype (is_debug: -O0 or debug=true); gated at Core/Debug/OOJSConsole.cpp:105                                             | Gates debug-console code in debug builds.                                                         | Already — set by meson in debug builds.                                                |
| `DEBUG_GRAPHVIZ`                                            | meson option `debug_graphviz` (forced 0 by deployment_release); gated at Core/AI.cpp:120                                                 | Gates AI state-machine GraphViz output.                                                           | Already — driven by meson option `debug_graphviz`.                                     |
| `DEV_RELEASE`                                               | meson option `dev_release`; gated at Core/Universe.cpp:5723                                                                              | Draws development-version watermark; log header tag.                                              | Already — driven by meson option `dev_release`.                                        |
| `DOCKING_CLEARANCE_ENABLED`                                 | never set — dead; gated at Core/OOLogHeader.cpp:47                                                                                       | Only triggers a #warning; feature no longer optional.                                             | No — never set; obsolete guard, delete the #ifdef.                                     |
| `HAVE_BZIP2`                                                | never set — dead; gated at Core/MiniZip/unzip.cpp:142                                                                                    | Enables bzip2 decompression in vendored minizip.                                                  | Yes — dead vendored-C gate; leave as is, not worth an option.                          |
| `HAVE_LIBESPEAK`                                            | meson option `espeak` (when enabled, via dependency args); gated at Core/OOFoundation.h:114                                              | Turns on speech synthesis (OOLITE_SPEECH_SYNTH/ESPEAK).                                           | Already — driven by meson option `espeak`.                                             |
| `INSTRUMENT_TEXTURE_LOADING`                                | never set — dead; gated at Core/Materials/OOTextureLoader.cpp:210                                                                        | Adds loaded state to texture description.                                                         | Yes — dead debug aid; tiny, could be a meson option but low value.                     |
| `LINUX`                                                     | src/meson/linux/meson.build (-DLINUX); gated at Core/OOFoundation.h:92                                                                   | Platform macro mapped to OOLITE_LINUX.                                                            | No — platform define set by meson, not a feature.                                      |
| `MSG_NOSIGNAL`                                              | platform header (socket.h); gated at Core/Debug/OODebugTCPConsoleClient.cpp:181                                                          | Suppresses SIGPIPE on socket send where available.                                                | No — platform capability test.                                                         |
| `NDEBUG`                                                    | meson b_ndebug, deployment_release, option `oo_exclude_debug_support`; gated at Core/AI.cpp:387                                          | Disables asserts and debug-only checks.                                                           | Already — driven by meson b_ndebug and options.                                        |
| `NOUNCRYPT`                                                 | set in unzip.cpp itself before include; gated at Core/MiniZip/unzip.cpp:74                                                               | Excludes minizip encryption support.                                                              | No — vendored C library setting.                                                       |
| `NO_SHADERS`                                                | meson option `no_shaders` (-DNO_SHADERS=1); gated at Core/OOOpenGLExtensionPointers.h:48                                                 | Disables shader support at compile time.                                                          | Already — driven by meson option `no_shaders`.                                         |
| `OOJS_POC_HARNESS`                                          | src/Core/Scripting/poc/meson.build (quickjs_poc option); gated at Core/Scripting/OOJavaScriptEngine.h:56                                 | Strips game dependencies for QuickJS proof-of-concept harness.                                    | Already — driven by meson option `quickjs_poc`.                                        |
| `OOLITE_DEBUG_SOUND_FILE_OPENING`                           | never set — dead; gated at Core/OOALSoundDecoder.cpp:242                                                                                 | Logs sound retain events.                                                                         | Yes — dead debug aid; could be a meson option but low value.                           |
| `OOLITE_HAVE_FIXED_THE_ABOVE_DESCRIBED_BUG_WHICH_WE_HAVENT` | never set — dead; gated at Core/Entities/OOPlanetEntity.cpp:884                                                                          | Close-range atmosphere drawing, disabled due to a known bug.                                      | Yes — dead code behind a known bug; delete or fix, not an option.                      |
| `OOLOG_NO_FILE_NAME`                                        | never set — dead; gated at Core/OOLogging.h:52                                                                                           | Strips file names from log calls.                                                                 | Yes — dead; could become an option for smaller binaries, low value.                    |
| `OOMATHS_EXTERNAL_VECTOR_TYPES`                             | never set — dead; gated at Core/OOVector.h:32                                                                                            | Lets another header supply Vector types.                                                          | No — dead include-guard style hook; delete.                                            |
| `OOSTOPWATCH_STANDALONE`                                    | never set — dead; gated at Core/OOProfilingStopwatch.h:33                                                                                | Builds stopwatch without OOFoundation.h.                                                          | No — dead standalone-build hook; delete.                                               |
| `OOTEXTURE_NO_CACHE`                                        | never set — dead; gated at Core/Materials/OOTexture.cpp:246                                                                              | Disables the texture cache.                                                                       | Yes — dead debug aid; could be a meson option but low value.                           |
| `OO_DEBUG_MONITOR_ENABLED`                                  | meson option `oo_debug_monitor_enabled` (always on in deployment_release); gated at Core/AI.cpp:279                                      | Compiles in the debug console/monitor hooks.                                                      | Already — driven by meson option `oo_debug_monitor_enabled`.                           |
| `OO_DUMP_PLANETINFO`                                        | never set — dead; gated at Core/Entities/OOPlanetEntity.cpp:382                                                                          | Logs planetinfo records for planets and suns.                                                     | Yes — dead debug aid; could be a meson option but low value.                           |
| `OO_FOV_INFLIGHT_CONTROL_ENABLED`                           | meson option `oo_fov_inflight_control_enabled`; gated at Core/Entities/PlayerEntity.cpp:467                                              | Enables in-flight field-of-view control.                                                          | Already — driven by meson option `oo_fov_inflight_control_enabled`.                    |
| `OO_LOG_DEBUG_PROTOCOL_PACKETS`                             | never set — dead; gated at Core/Debug/OODebugTCPConsoleClient.cpp:76                                                                     | Logs debug-console protocol packets.                                                              | Yes — dead debug aid; could be a meson option but low value.                           |
| `OO_PROFILING_STOPWATCH_MACH_ABSOLUTE_TIME`                 | never set — dead; gated at Core/OOProfilingStopwatch.cpp:88                                                                              | Mach absolute-time stopwatch backend (Mac).                                                       | No — dead platform shim; delete.                                                       |
| `STRICTUNZIP`                                               | never set — dead; gated at Core/MiniZip/unzip.h:61                                                                                       | Strict typing of unzFile in vendored minizip.                                                     | No — vendored C compat macro; leave.                                                   |
| `STRICTZIPUNZIP`                                            | never set — dead; gated at Core/MiniZip/unzip.h:61                                                                                       | Strict typing of unzFile in vendored minizip.                                                     | No — vendored C compat macro; leave.                                                   |
| `TARGET_INCOMING_MISSILES`                                  | never set — dead; gated at Core/OOLogHeader.cpp:55                                                                                       | Only triggers a #warning; feature no longer optional.                                             | No — never set; obsolete guard, delete the #ifdef.                                     |
| `TEXGEN_TEST_RIG`                                           | never set — dead; gated at Core/Materials/OOPlanetTextureGenerator.cpp:53                                                                | Builds planet texture generator test rig with 4096 scale.                                         | Yes — dead test hook; delete or make option, low value.                                |
| `USE_FILE32API`                                             | never set — dead; gated at Core/MiniZip/ioapi.h:56                                                                                       | Uses 32-bit file API in vendored minizip.                                                         | No — vendored C compat macro; leave.                                                   |
| `WIN32`                                                     | src/meson/windows/meson.build (-DWIN32); gated at Core/OOFoundation.h:85                                                                 | Platform macro mapped to OOLITE_WINDOWS.                                                          | No — platform define set by meson, not a feature.                                      |
| `WIN32_LEAN_AND_MEAN`                                       | set in vendored miniz/tinyexr headers; gated at SDL/EXRSnapshotSupport/tinyexr.h:611                                                     | Trims windows.h includes.                                                                         | No — vendored platform shim.                                                           |
| `WORMHOLE_SCANNER`                                          | never set — dead; gated at Core/OOLogHeader.cpp:51                                                                                       | Only triggers a #warning; feature no longer optional.                                             | No — never set; obsolete guard, delete the #ifdef.                                     |
| `OO_CHECK_GL_HEAVY`                                         | meson option `oo_check_gl_heavy` (on in debug builds, 0 in deployment_release); gated at Core/OOOpenGL.cpp:97                            | Heavy OpenGL error checking.                                                                      | Already — driven by meson option `oo_check_gl_heavy`.                                  |
| `OO_DEBUG`                                                  | meson.build is_debug (-O0 or debug=true); gated at Core/Debug/OOJSConsole.cpp:57                                                         | Gates debug-only code and progress logging.                                                       | Already — set by meson in debug builds.                                                |
| `OO_OXP_VERIFIER_ENABLED`                                   | meson option `oo_oxp_verifier_enabled` (always on in deployment_release); gated at Core/GameController.cpp:569                           | Compiles OXP verification stages.                                                                 | Already — driven by meson option `oo_oxp_verifier_enabled`.                            |
| `OO_LOCALIZATION_TOOLS`                                     | meson option `oo_localization_tools` (0 in deployment_release); gated at Core/Universe.cpp:110                                           | Compiles localization extraction tools.                                                           | Already — driven by meson option `oo_localization_tools`.                              |
| `OO_EXCLUDE_DEBUG_SUPPORT`                                  | meson option `oo_exclude_debug_support` (only adds -DNDEBUG; macro itself never referenced in src); gated at meson.build:73 (no src use) | Option name only; adds NDEBUG, no src gate.                                                       | Already — meson option exists; the option name is the only trace, no src gate to flag. |
| `OOLITE_SDL_MAC`                                            | src/meson/darwin/meson.build (-DOOLITE_SDL_MAC=1); gated at none in src — dead                                                           | Set on macOS builds; nothing in src tests it.                                                     | No — set but unreferenced; delete the -D.                                              |
| `deployment_release (option)`                               | meson option `deployment_release` (adds NDEBUG and fixes the OO_* flags); gated at meson.build:58                                        | Forces strict production flags: NDEBUG, debug monitor/verifier on, localization/graphviz/FOV off. | Already — meson option `deployment_release`; no src macro.                             |

## Entities (`Core/Entities`)

| Macro | Where | Purpose | Feature flag? |
|---|---|---|---|
| `FAR_PLANE` | `Core/Entities/DustEntity.cpp:46` | Far clip plane for dust rendering. | No — tuning constant; could be constexpr. |
| `NEAR_PLANE` | `Core/Entities/DustEntity.cpp:47` | Near clip plane for dust rendering. | No — tuning constant; could be constexpr. |
| `DUST_SCALE` | `Core/Entities/DustEntity.h:57` | Size scale of the dust field. | No — tuning constant; could be constexpr. |
| `DUST_N_PARTICLES` | `Core/Entities/DustEntity.h:58` | Number of space dust particles. | No — tuning constant; could be constexpr. |
| `ADD_FLAG_IF_SET` | `Core/Entities/Entity.cpp:826`, `Core/Entities/PlayerEntity.cpp:13984` | Appends stringified field name to a flags list when set. | No — stringizing helper; could be a lambda or inline function. |
| `NO_DRAW_DISTANCE_FACTOR` | `Core/Entities/Entity.h:77` | Scale factor for entity no-draw distance. | No — tuning constant; could be constexpr. |
| `ABSOLUTE_NO_DRAW_DISTANCE2` | `Core/Entities/Entity.h:78` | Squared distance beyond which entities are never drawn. | No — tuning constant; could be constexpr. |
| `SCANNER_MAX_RANGE` | `Core/Entities/Entity.h:83` | Maximum scanner range. | No — tuning constant; could be constexpr. |
| `SCANNER_MAX_RANGE2` | `Core/Entities/Entity.h:84` | Square of maximum scanner range. | No — tuning constant; could be constexpr. |
| `CLOSE_COLLISION_CHECK_MAX_RANGE2` | `Core/Entities/Entity.h:86` | Squared range limit for close collision checks. | No — tuning constant; could be constexpr. |
| `OO_ENTITY_VIRTUAL_MEMBERS` | `Core/Entities/EntityVirtualMembers.h:60` | X-macro list of entity virtual members. | No — X-macro code generator; could be CRTP/templates or explicit declarations. |
| `OO_ENTITY_DEBUG_VIRTUAL_MEMBERS` | `Core/Entities/EntityVirtualMembers.h:150`, `Core/Entities/EntityVirtualMembers.h:155` | X-macro list of debug-only entity virtual members. | No — X-macro code generator; could be CRTP/templates or explicit declarations. |
| `BREAK_PATTERN_RING_SPACING` | `Core/Entities/OOBreakPatternEntity.h:35` | Spacing between break-pattern rings. | No — tuning constant; could be constexpr. |
| `BREAK_PATTERN_RING_SPEED` | `Core/Entities/OOBreakPatternEntity.h:36` | Speed of break-pattern rings. | No — tuning constant; could be constexpr. |
| `ECM_EFFECT_DURATION` | `Core/Entities/OOECMBlastEntity.cpp:36` | ECM blast effect duration. | No — tuning constant; could be constexpr. |
| `ECM_PULSE_COUNT` | `Core/Entities/OOECMBlastEntity.cpp:37` | Number of ECM blast pulses. | No — tuning constant; could be constexpr. |
| `ECM_PULSE_INTERVAL` | `Core/Entities/OOECMBlastEntity.cpp:38` | Time between ECM blast pulses. | No — tuning constant; could be constexpr. |
| `ECM_DEBUG_DRAW` | `Core/Entities/OOECMBlastEntity.cpp:41` | Debug drawing of ECM blast (hard-wired off). | Yes — #if debug aid, compile-time off. |
| `kOverallAlpha` | `Core/Entities/OOExhaustPlumeEntity.cpp:37` | Overall exhaust plume alpha. | No — tuning constant; could be constexpr. |
| `kTimeStep` | `Core/Entities/OOExhaustPlumeEntity.cpp:38` | Exhaust animation time step. | No — tuning constant; could be constexpr. |
| `kFadeLevel1` | `Core/Entities/OOExhaustPlumeEntity.cpp:39` | Exhaust fade level 1. | No — tuning constant; could be constexpr. |
| `kFadeLevel2` | `Core/Entities/OOExhaustPlumeEntity.cpp:40` | Exhaust fade level 2. | No — tuning constant; could be constexpr. |
| `kFadeLevel3` | `Core/Entities/OOExhaustPlumeEntity.cpp:41` | Exhaust fade level 3. | No — tuning constant; could be constexpr. |
| `kScaleLevel1` | `Core/Entities/OOExhaustPlumeEntity.cpp:42` | Exhaust scale level 1. | No — tuning constant; could be constexpr. |
| `kScaleLevel2` | `Core/Entities/OOExhaustPlumeEntity.cpp:43` | Exhaust scale level 2. | No — tuning constant; could be constexpr. |
| `kScaleLevel3` | `Core/Entities/OOExhaustPlumeEntity.cpp:44` | Exhaust scale level 3. | No — tuning constant; could be constexpr. |
| `PREV` | `Core/Entities/OOExhaustPlumeEntity.cpp:533` | Previous frame index in exhaust animation ring. | No — function-like helper; could be inline function. |
| `NEXT` | `Core/Entities/OOExhaustPlumeEntity.cpp:534` | Next frame index in exhaust animation ring. | No — function-like helper; could be inline function. |
| `kExplosionCloudDuration` | `Core/Entities/OOExplosionCloudEntity.cpp:35` | Explosion cloud duration. | No — tuning constant; could be constexpr. |
| `kGrowthRateFactor` | `Core/Entities/OOExplosionCloudEntity.cpp:36`, `Core/Entities/OOFlashEffectEntity.cpp:36` | Effect growth rate factor. | No — tuning constant; could be constexpr. |
| `kExplosionCloudAlpha` | `Core/Entities/OOExplosionCloudEntity.cpp:37` | Explosion cloud alpha. | No — tuning constant; could be constexpr. |
| `kExplosionBrightnessMult` | `Core/Entities/OOExplosionCloudEntity.cpp:38` | Explosion cloud brightness multiplier. | No — tuning constant; could be constexpr. |
| `kExplosionDefaultSize` | `Core/Entities/OOExplosionCloudEntity.cpp:39` | Default explosion cloud size. | No — tuning constant; could be constexpr. |
| `kLaserFlashDuration` | `Core/Entities/OOFlashEffectEntity.cpp:34` | Laser flash effect duration. | No — tuning constant; could be constexpr. |
| `kExplosionFlashDuration` | `Core/Entities/OOFlashEffectEntity.cpp:35` | Explosion flash duration. | No — tuning constant; could be constexpr. |
| `kMinExplosionGrowth` | `Core/Entities/OOFlashEffectEntity.cpp:38` | Minimum explosion flash growth. | No — tuning constant; could be constexpr. |
| `kLaserFlashInitialSize` | `Core/Entities/OOFlashEffectEntity.cpp:39` | Laser flash initial size. | No — tuning constant; could be constexpr. |
| `kExplosionFlashAlpha` | `Core/Entities/OOFlashEffectEntity.cpp:40` | Explosion flash alpha. | No — tuning constant; could be constexpr. |
| `kLaserDuration` | `Core/Entities/OOLaserShotEntity.cpp:38` | Laser shot duration. | No — tuning constant; could be constexpr. |
| `kLaserRed` | `Core/Entities/OOLaserShotEntity.cpp:41` | Laser red component. | No — tuning constant; could be constexpr. |
| `kLaserGreen` | `Core/Entities/OOLaserShotEntity.cpp:42` | Laser green component. | No — tuning constant; could be constexpr. |
| `kLaserBlue` | `Core/Entities/OOLaserShotEntity.cpp:43` | Laser blue component. | No — tuning constant; could be constexpr. |
| `kLaserBrightness` | `Core/Entities/OOLaserShotEntity.cpp:46` | Laser brightness. | No — tuning constant; could be constexpr. |
| `kLaserAlpha` | `Core/Entities/OOLaserShotEntity.cpp:49` | Laser shot alpha. | No — tuning constant; could be constexpr. |
| `kLaserCoreWidth` | `Core/Entities/OOLaserShotEntity.cpp:51` | Laser core width. | No — tuning constant; could be constexpr. |
| `kLaserFlareWidth` | `Core/Entities/OOLaserShotEntity.cpp:52` | Laser flare width. | No — tuning constant; could be constexpr. |
| `kLaserHalfWidth` | `Core/Entities/OOLaserShotEntity.cpp:53` | Laser half width. | No — tuning constant; could be constexpr. |
| `PARTICLE_DISTANCE_SCALE_LOW` | `Core/Entities/OOLightParticleEntity.cpp:36` | Particle distance scale at low detail. | No — tuning constant; could be constexpr. |
| `PARTICLE_DISTANCE_SCALE_HIGH` | `Core/Entities/OOLightParticleEntity.cpp:37` | Particle distance scale at high detail. | No — tuning constant; could be constexpr. |
| `FREEZE_PARTICLES` | `Core/Entities/OOParticleSystem.cpp:41` | Debug switch freezing particle motion (hard-wired off). | Yes — #if debug aid, compile-time off. |
| `DrawQuadForView` | `Core/Entities/OOParticleSystem.cpp:123` | Emits a textured quad for particle drawing. | No — function-like helper; could be inline function. |
| `NEW_ATMOSPHERE` | `Core/Entities/OOPlanetEntity.cpp:41` | Selects new atmosphere rendering path (hard-wired on). | Yes — #if toggle between old and new atmosphere code. |
| `OO_TERMINATOR_THRESHOLD_VECTOR_DEFAULT` | `Core/Entities/OOPlanetEntity.cpp:69` | Default planet day/night terminator threshold vector. | No — tuning constant; could be constexpr. |
| `CPROP` | `Core/Entities/OOPlanetEntity.cpp:383` | Logs a planet-info colour property by name. | No — logging helper; could be inline function or lambda. |
| `FPROP` | `Core/Entities/OOPlanetEntity.cpp:389` | Logs a planet-info float property by name. | No — logging helper; could be inline function or lambda. |
| `kPlasmaBurstInitialSize` | `Core/Entities/OOPlasmaBurstEntity.cpp:30` | Plasma burst initial size. | No — tuning constant; could be constexpr. |
| `kPlasmaBurstGrowthRate` | `Core/Entities/OOPlasmaBurstEntity.cpp:31` | Plasma burst growth rate. | No — tuning constant; could be constexpr. |
| `kPlasmaBurstDuration` | `Core/Entities/OOPlasmaBurstEntity.cpp:32` | Plasma burst duration. | No — tuning constant; could be constexpr. |
| `kPlasmaShotSize` | `Core/Entities/OOPlasmaShotEntity.cpp:34` | Plasma shot size. | No — tuning constant; could be constexpr. |
| `kPlasmaShotActivationDelay` | `Core/Entities/OOPlasmaShotEntity.cpp:35` | Plasma shot activation delay. | No — tuning constant; could be constexpr. |
| `PLASMA_ATTENUATION` | `Core/Entities/OOPlasmaShotEntity.cpp:41` | Plasma shot attenuation code path (hard-wired off). | Yes — #if toggle for optional plasma attenuation. |
| `kQuiriumCascadeDuration` | `Core/Entities/OOQuiriumCascadeEntity.cpp:34` | Quirium cascade duration. | No — tuning constant; could be constexpr. |
| `kQuiriumCollisionDelay` | `Core/Entities/OOQuiriumCascadeEntity.cpp:35` | Quirium cascade collision start delay. | No — tuning constant; could be constexpr. |
| `kRingDuration` | `Core/Entities/OORingEffectEntity.cpp:34` | Ring effect duration. | No — tuning constant; could be constexpr. |
| `kRingAttack` | `Core/Entities/OORingEffectEntity.cpp:35` | Ring effect fade-up time. | No — tuning constant; could be constexpr. |
| `kInnerRingInitialSizeFactor` | `Core/Entities/OORingEffectEntity.cpp:38` | Inner ring initial size. | No — tuning constant; could be constexpr. |
| `kOuterRingInitialSizeFactor` | `Core/Entities/OORingEffectEntity.cpp:39` | Outer ring initial size. | No — tuning constant; could be constexpr. |
| `kInnerRingGrowthRateFactor` | `Core/Entities/OORingEffectEntity.cpp:40` | Inner ring growth rate. | No — tuning constant; could be constexpr. |
| `kOuterRingGrowthRateFactor` | `Core/Entities/OORingEffectEntity.cpp:41` | Outer ring growth rate. | No — tuning constant; could be constexpr. |
| `kShrinkingRingInnerGrowthFactor` | `Core/Entities/OORingEffectEntity.cpp:45` | Shrinking inner ring growth. | No — tuning constant; could be constexpr. |
| `kShrinkingRingOuterGrowthFactor` | `Core/Entities/OORingEffectEntity.cpp:46` | Shrinking outer ring growth. | No — tuning constant; could be constexpr. |
| `ATMOSPHERE_DEPTH` | `Core/Entities/OOStellarBody.h:42` | Planet atmosphere shell depth. | No — tuning constant; could be constexpr. |
| `PLANET_MINIATURE_FACTOR` | `Core/Entities/OOStellarBody.h:43` | Scale of planet miniature in chart view. | No — tuning constant; could be constexpr. |
| `MAX_SUBDIVIDE` | `Core/Entities/OOStellarBody.h:44` | Max planet mesh subdivision level. | No — tuning constant; could be constexpr. |
| `SUN_CORONA_SAMPLES` | `Core/Entities/OOSunEntity.h:57` | Number of corona samples around sun. | No — tuning constant; could be constexpr. |
| `MAX_CORONAFLARE` | `Core/Entities/OOSunEntity.h:59` | Maximum nova corona flare size (unused). | No — tuning constant; could be constexpr. |
| `SUN_DIRECT_VISION_GLARE` | `Core/Entities/OOSunEntity.h:62` | Enables glare when looking directly at sun. | Yes — #ifndef/#if toggle for optional glare effect. |
| `SUN_GLARE_MULT_FACTOR` | `Core/Entities/OOSunEntity.h:66` | Sun glare multiplicative factor. | No — tuning constant; could be constexpr. |
| `SUN_GLARE_ADD_FACTOR` | `Core/Entities/OOSunEntity.h:67` | Sun glare additive factor. | No — tuning constant; could be constexpr. |
| `SUN_GLARE_CORONA_FACTOR` | `Core/Entities/OOSunEntity.h:68`, `Core/Entities/OOSunEntity.h:70` | Sun glare corona factor. | No — tuning constant; could be constexpr. |
| `OOWAYPOINT_KEY_POSITION` | `Core/Entities/OOWaypointEntity.cpp:40` | Waypoint dictionary key for position. | No — dictionary key string; could be constexpr std::string_view. |
| `OOWAYPOINT_KEY_ORIENTATION` | `Core/Entities/OOWaypointEntity.cpp:41` | Waypoint dictionary key for orientation. | No — dictionary key string; could be constexpr std::string_view. |
| `OOWAYPOINT_KEY_SIZE` | `Core/Entities/OOWaypointEntity.cpp:42` | Waypoint dictionary key for size. | No — dictionary key string; could be constexpr std::string_view. |
| `OOWAYPOINT_KEY_CODE` | `Core/Entities/OOWaypointEntity.cpp:43` | Waypoint dictionary key for beacon code. | No — dictionary key string; could be constexpr std::string_view. |
| `OOWAYPOINT_KEY_LABEL` | `Core/Entities/OOWaypointEntity.cpp:44` | Waypoint dictionary key for beacon label. | No — dictionary key string; could be constexpr std::string_view. |
| `STAGE_TRACKING_BEGIN` | `Core/Entities/PlayerEntity.cpp:346`, `Core/Entities/PlayerEntity.cpp:367` | Opens try-block tracking update stage; plain brace in release. | Yes — #ifndef NDEBUG debug aid. |
| `STAGE_TRACKING_END` | `Core/Entities/PlayerEntity.cpp:350`, `Core/Entities/PlayerEntity.cpp:368` | Closes stage-tracking try/catch and logs exception. | Yes — #ifndef NDEBUG debug aid. |
| `UPDATE_STAGE` | `Core/Entities/PlayerEntity.cpp:362`, `Core/Entities/PlayerEntity.cpp:369` | Records current update stage for exception logging. | Yes — #ifndef NDEBUG debug aid. |
| `VELOCITY_CLEANUP_MIN` | `Core/Entities/PlayerEntity.cpp:375` | Minimum speed for power braking. | No — tuning constant; could be constexpr. |
| `VELOCITY_CLEANUP_FULL` | `Core/Entities/PlayerEntity.cpp:376` | Speed for full power braking. | No — tuning constant; could be constexpr. |
| `VELOCITY_CLEANUP_RATE` | `Core/Entities/PlayerEntity.cpp:378` | Factor for full power braking. | No — tuning constant; could be constexpr. |
| `OO_SETACCESSCONDITIONFORROW` | `Core/Entities/PlayerEntity.cpp:9155` | Sets GUI row key/colour by access condition. | No — function-like helper; could be inline function. |
| `ALLOW_CUSTOM_VIEWS_WHILE_PAUSED` | `Core/Entities/PlayerEntity.h:77` | Enables custom view controls while game is paused. | Yes — compile-time #if toggle (hard-wired on). |
| `SCRIPT_TIMER_INTERVAL` | `Core/Entities/PlayerEntity.h:78` | Interval between script timer ticks. | No — tuning constant; could be constexpr. |
| `OO_VARIABLE_TORUS_SPEED` | `Core/Entities/PlayerEntity.h:81` | Enables player-adjustable torus-drive speed. | Yes — compile-time #if toggle (hard-wired on). |
| `GUI_ROW_INIT` | `Core/Entities/PlayerEntity.h:84` | Legacy no-op row-count initialiser (unused). | No — empty legacy macro; could be removed. |
| `CUSTOM_VIEW_MAX_ZOOM_IN` | `Core/Entities/PlayerEntity.h:86` | Max zoom-in factor for custom views. | No — tuning constant; could be constexpr. |
| `CUSTOM_VIEW_MAX_ZOOM_OUT` | `Core/Entities/PlayerEntity.h:87` | Max zoom-out factor for custom views. | No — tuning constant; could be constexpr. |
| `CHART_WIDTH_AT_MAX_ZOOM` | `Core/Entities/PlayerEntity.h:103` | Chart view width at maximum zoom. | No — tuning constant; could be constexpr. |
| `CHART_HEIGHT_AT_MAX_ZOOM` | `Core/Entities/PlayerEntity.h:104` | Chart view height at maximum zoom. | No — tuning constant; could be constexpr. |
| `CHART_MAX_ZOOM` | `Core/Entities/PlayerEntity.h:106` | Maximum chart zoom factor. | No — tuning constant; could be constexpr. |
| `CHART_SCROLL_AT_X` | `Core/Entities/PlayerEntity.h:108` | Horizontal chart scroll trigger threshold. | No — tuning constant; could be constexpr. |
| `CHART_SCROLL_AT_Y` | `Core/Entities/PlayerEntity.h:109` | Vertical chart scroll trigger threshold. | No — tuning constant; could be constexpr. |
| `CHART_CLIP_BORDER` | `Core/Entities/PlayerEntity.h:110` | Border width when clipping the galactic chart. | No — tuning constant; could be constexpr. |
| `CHART_SCREEN_VERTICAL_CENTRE` | `Core/Entities/PlayerEntity.h:111` | Vertical centre of chart screen in GUI rows. | No — tuning constant; could be constexpr. |
| `CHART_SCREEN_VERTICAL_CENTRE_COMPACT` | `Core/Entities/PlayerEntity.h:112` | Vertical chart centre for compact HUD layout. | No — tuning constant; could be constexpr. |
| `CHART_ZOOM_SPEED_FACTOR` | `Core/Entities/PlayerEntity.h:113` | Per-step chart zoom speed multiplier. | No — tuning constant; could be constexpr. |
| `CHART_ZOOM_SHOW_LABELS` | `Core/Entities/PlayerEntity.h:115` | Zoom level at which chart labels appear. | No — tuning constant; could be constexpr. |
| `OO_RESOLUTION_OPTION` | `Core/Entities/PlayerEntity.h:118` | Enables resolution option in options screen. | Yes — compile-time #if toggle (hard-wired on). |
| `ECM_ENERGY_DRAIN_FACTOR` | `Core/Entities/PlayerEntity.h:357` | Player ECM energy drain factor. | No — tuning constant; could be constexpr. |
| `ECM_DURATION` | `Core/Entities/PlayerEntity.h:358` | Player ECM active duration. | No — tuning constant; could be constexpr. |
| `ROLL_DAMPING_FACTOR` | `Core/Entities/PlayerEntity.h:360` | Player roll damping. | No — tuning constant; could be constexpr. |
| `PITCH_DAMPING_FACTOR` | `Core/Entities/PlayerEntity.h:361` | Player pitch damping. | No — tuning constant; could be constexpr. |
| `YAW_DAMPING_FACTOR` | `Core/Entities/PlayerEntity.h:362` | Player yaw damping. | No — tuning constant; could be constexpr. |
| `PLAYER_MAX_WEAPON_TEMP` | `Core/Entities/PlayerEntity.h:364` | Player max weapon temperature. | No — tuning constant; could be constexpr. |
| `PLAYER_MAX_FUEL` | `Core/Entities/PlayerEntity.h:367`, `Core/Entities/PlayerEntity.h:369` | Player max fuel (70, or 7000 in planetinfo debug). | Yes — switched by #ifdef OO_DUMP_PLANETINFO debug build. |
| `PLAYER_MAX_MISSILES` | `Core/Entities/PlayerEntity.h:371` | Player max missile slots. | No — tuning constant; could be constexpr. |
| `PLAYER_STARTING_MAX_MISSILES` | `Core/Entities/PlayerEntity.h:372` | Starting max missile capacity. | No — tuning constant; could be constexpr. |
| `PLAYER_STARTING_MISSILES` | `Core/Entities/PlayerEntity.h:373` | Starting missile count. | No — tuning constant; could be constexpr. |
| `PLAYER_DIAL_MAX_ALTITUDE` | `Core/Entities/PlayerEntity.h:374` | Max altitude shown on player dial. | No — tuning constant; could be constexpr. |
| `PLAYER_SUPER_ALTITUDE2` | `Core/Entities/PlayerEntity.h:375` | Squared altitude for super-cruise threshold (unused). | No — tuning constant; could be constexpr. |
| `PLAYER_MAX_TRUMBLES` | `Core/Entities/PlayerEntity.h:377` | Player max trumbles. | No — tuning constant; could be constexpr. |
| `PLAYER_TARGET_MEMORY_SIZE` | `Core/Entities/PlayerEntity.h:379` | Player target memory slots. | No — tuning constant; could be constexpr. |
| `HYPERSPEED_FACTOR` | `Core/Entities/PlayerEntity.h:382`, `Core/Entities/PlayerEntity.h:387` | Torus-drive speed multiplier (variable or fixed 32). | Yes — selected by OO_VARIABLE_TORUS_SPEED #if. |
| `MIN_HYPERSPEED_FACTOR` | `Core/Entities/PlayerEntity.h:384` | Min variable torus speed multiplier. | No — tuning constant; could be constexpr. |
| `MAX_HYPERSPEED_FACTOR` | `Core/Entities/PlayerEntity.h:385` | Max variable torus speed multiplier. | No — tuning constant; could be constexpr. |
| `ESCAPE_SEQUENCE_TIME` | `Core/Entities/PlayerEntity.h:392` | Duration of escape pod sequence. | No — tuning constant; could be constexpr. |
| `FORWARD_FACING_STRING` | `Core/Entities/PlayerEntity.h:394` | Localised description string for forward-facing view. | No — description lookup shorthand; could be inline function. |
| `AFT_FACING_STRING` | `Core/Entities/PlayerEntity.h:395` | Localised description string for aft-facing view. | No — description lookup shorthand; could be inline function. |
| `PORT_FACING_STRING` | `Core/Entities/PlayerEntity.h:396` | Localised description string for port-facing view. | No — description lookup shorthand; could be inline function. |
| `STARBOARD_FACING_STRING` | `Core/Entities/PlayerEntity.h:397` | Localised description string for starboard-facing view. | No — description lookup shorthand; could be inline function. |
| `KEY_REPEAT_INTERVAL` | `Core/Entities/PlayerEntity.h:399` | Key auto-repeat interval in seconds. | No — tuning constant; could be constexpr. |
| `PLAYER_SHIP_CLOCK_START` | `Core/Entities/PlayerEntity.h:401` | Starting game clock in seconds. | No — tuning constant; could be constexpr. |
| `PLAYER_SHIP_SUBENTITY_TRADE_IN_VALUE` | `Core/Entities/PlayerEntity.h:404` | Trade-in value of ship subentities. | No — tuning constant; could be constexpr. |
| `SCANNER_ZOOM_RATE_UP` | `Core/Entities/PlayerEntity.h:416` | Scanner zoom-in rate. | No — tuning constant; could be constexpr. |
| `SCANNER_ZOOM_RATE_DOWN` | `Core/Entities/PlayerEntity.h:417` | Scanner zoom-out rate. | No — tuning constant; could be constexpr. |
| `SCANNER_ECM_FUZZINESS` | `Core/Entities/PlayerEntity.h:418` | Scanner fuzziness during ECM. | No — tuning constant; could be constexpr. |
| `PLAYER_INTERNAL_DAMAGE_FACTOR` | `Core/Entities/PlayerEntity.h:420` | Internal damage probability factor. | No — tuning constant; could be constexpr. |
| `MANIFEST_SCREEN_ROW_BACK` | `Core/Entities/PlayerEntity.h:425` | Manifest screen row index of Back item. | No — tuning constant; could be constexpr. |
| `MANIFEST_SCREEN_ROW_NEXT` | `Core/Entities/PlayerEntity.h:426` | Manifest screen row index of Next item (HUD-dependent). | No — expression with runtime state; could be inline function. |
| `PLAYER` | `Core/Entities/PlayerEntity.h:2099` | Shorthand for current player entity accessor. | No — accessor shorthand; could be inline function. |
| `KILOGRAMS_PER_POD` | `Core/Entities/PlayerEntity.h:2101` | Kilograms in one cargo pod. | No — tuning constant; could be constexpr. |
| `MAX_KILOGRAMS_IN_SAFE` | `Core/Entities/PlayerEntity.h:2102` | Max kilograms storable in safe. | No — tuning constant; could be constexpr. |
| `GRAMS_PER_POD` | `Core/Entities/PlayerEntity.h:2103` | Grams in one cargo pod. | No — tuning constant; could be constexpr. |
| `MAX_GRAMS_IN_SAFE` | `Core/Entities/PlayerEntity.h:2104` | Max grams storable in safe. | No — tuning constant; could be constexpr. |
| `SET_MANIFEST_ROW` | `Core/Entities/PlayerEntityContracts.cpp:1213` | Shorthand for setManifestScreenRow with local paging state. | No — function-like helper; could be inline function. |
| `CONTRACT_KEY_DESTINATION_NAME` | `Core/Entities/PlayerEntityContracts.h:48` | Contract dictionary key for destination name (unused). | No — dictionary key string; could be constexpr std::string_view. |
| `CONTRACT_KEY_LONG_DESCRIPTION` | `Core/Entities/PlayerEntityContracts.h:49` | Contract dictionary key for long description (unused). | No — dictionary key string; could be constexpr std::string_view. |
| `MAX_CONTRACT_REP` | `Core/Entities/PlayerEntityContracts.h:57` | Maximum contract reputation. | No — tuning constant; could be constexpr. |
| `CUSTOM_VIEW_ROTATE_SPEED` | `Core/Entities/PlayerEntityControls.cpp:104` | Custom view rotation speed. | No — tuning constant; could be constexpr. |
| `CUSTOM_VIEW_ZOOM_SPEED` | `Core/Entities/PlayerEntityControls.cpp:105` | Custom view zoom speed. | No — tuning constant; could be constexpr. |
| `CUSTOM_VIEW_SPEED_REDUCTION_FACTOR` | `Core/Entities/PlayerEntityControls.cpp:106` | Custom view speed reduction factor. | No — tuning constant; could be constexpr. |
| `LOAD_KEY_SETTING2` | `Core/Entities/PlayerEntityControls.cpp:358` | Loads a named key binding with defaults. | No — stringizing helper; could be inline function. |
| `ACTIONS_TEMP_PREFIX` | `Core/Entities/PlayerEntityLegacyScriptEngine.cpp:126` | Prefix for temporary legacy-script action variable names. | No — string constant; could be constexpr std::string_view. |
| `DOUBLEVAL` | `Core/Entities/PlayerEntityLegacyScriptEngine.cpp:599` | Shorthand for optional string to double, defaulting to 0. | No — function-like helper; could be inline function. |
| `COMMAND_MODIFIER_KEY` | `Core/Entities/PlayerEntityLoadSave.cpp:49` | Display name of the command modifier key. | No — platform string; could be constexpr std::string_view. |
| `KEY_HEADER` | `Core/Entities/PlayerEntityStickMapper.h:72` | Stick mapper key for header. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_GUIDESC` | `Core/Entities/PlayerEntityStickMapper.h:73` | Stick mapper key for GUI description. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_ALLOWABLE` | `Core/Entities/PlayerEntityStickMapper.h:74` | Stick mapper key for allowable values. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_AXISFN` | `Core/Entities/PlayerEntityStickMapper.h:75` | Stick mapper key for axis function. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_BUTTONFN` | `Core/Entities/PlayerEntityStickMapper.h:76` | Stick mapper key for button function. | No — dictionary key string; could be constexpr std::string_view. |
| `USEMASC` | `Core/Entities/ShipEntity.cpp:99` | Enables MASC code paths (hard-wired on). | Yes — compile-time #if toggle (hard-wired on). |
| `kMassCharge` | `Core/Entities/ShipEntity.cpp:106` | Fuel price share dependent on ship mass. | Yes — only inside #if MASS_DEPENDENT_FUEL_PRICES; constant could be constexpr. |
| `kBaseCharge` | `Core/Entities/ShipEntity.cpp:109` | Fuel price share independent of ship mass. | Yes — only inside #if MASS_DEPENDENT_FUEL_PRICES; constant could be constexpr. |
| `MAX_TARGETS` | `Core/Entities/ShipEntity.h:74` | Max targets a ship tracks. | No — tuning constant; could be constexpr. |
| `RAIDER_MAX_CARGO` | `Core/Entities/ShipEntity.h:75` | Max cargo for raider ships (unused). | No — tuning constant; could be constexpr. |
| `MERCHANTMAN_MAX_CARGO` | `Core/Entities/ShipEntity.h:76` | Max cargo for merchantman ships (unused). | No — tuning constant; could be constexpr. |
| `PIRATES_PREFER_PLAYER` | `Core/Entities/ShipEntity.h:78` | Pirates favour attacking the player. | Yes — boolean gate on pirate targeting (hard-wired true). |
| `TURRET_MINIMUM_COS` | `Core/Entities/ShipEntity.h:80` | Min cosine for turret firing arc. | No — tuning constant; could be constexpr. |
| `SHIP_THRUST_FACTOR` | `Core/Entities/ShipEntity.h:82` | Ship thrust scaling factor. | No — tuning constant; could be constexpr. |
| `AFTERBURNER_BURNRATE` | `Core/Entities/ShipEntity.h:83` | Fuel burn rate of the afterburner. | No — tuning constant; could be constexpr. |
| `CLOAKING_DEVICE_ENERGY_RATE` | `Core/Entities/ShipEntity.h:85` | Energy drain rate of the cloaking device. | No — tuning constant; could be constexpr. |
| `CLOAKING_DEVICE_MIN_ENERGY` | `Core/Entities/ShipEntity.h:86` | Minimum energy needed to engage cloak. | No — tuning constant; could be constexpr. |
| `CLOAKING_DEVICE_START_ENERGY` | `Core/Entities/ShipEntity.h:87` | Energy fraction consumed when cloak starts. | No — tuning constant; could be constexpr. |
| `MILITARY_JAMMER_ENERGY_RATE` | `Core/Entities/ShipEntity.h:89` | Energy drain rate of military jammer. | No — tuning constant; could be constexpr. |
| `MILITARY_JAMMER_MIN_ENERGY` | `Core/Entities/ShipEntity.h:90` | Min energy to engage military jammer. | No — tuning constant; could be constexpr. |
| `COMBAT_IN_RANGE_FACTOR` | `Core/Entities/ShipEntity.h:92` | Combat in-range factor. | No — tuning constant; could be constexpr. |
| `COMBAT_BROADSIDE_IN_RANGE_FACTOR` | `Core/Entities/ShipEntity.h:93` | Broadside in-range factor for combat. | No — tuning constant; could be constexpr. |
| `COMBAT_OUT_RANGE_FACTOR` | `Core/Entities/ShipEntity.h:94` | Combat out-of-range factor. | No — tuning constant; could be constexpr. |
| `COMBAT_BROADSIDE_RANGE_FACTOR` | `Core/Entities/ShipEntity.h:95` | Broadside range factor for combat. | No — tuning constant; could be constexpr. |
| `COMBAT_WEAPON_RANGE_FACTOR` | `Core/Entities/ShipEntity.h:96` | Combat weapon range factor. | No — tuning constant; could be constexpr. |
| `COMBAT_JINK_OFFSET` | `Core/Entities/ShipEntity.h:97` | Offset distance used when jinking in combat. | No — tuning constant; could be constexpr. |
| `SHIP_COOLING_FACTOR` | `Core/Entities/ShipEntity.h:99` | Ship passive cooling rate. | No — tuning constant; could be constexpr. |
| `SHIP_ENERGY_DAMAGE_TO_HEAT_FACTOR` | `Core/Entities/ShipEntity.h:103` | Heat from energy damage, mass-dependent. | No — tuning constant; could be constexpr. |
| `SHIP_INSULATION_FACTOR` | `Core/Entities/ShipEntity.h:105` | Ship hull insulation factor. | No — tuning constant; could be constexpr. |
| `SHIP_MAX_CABIN_TEMP` | `Core/Entities/ShipEntity.h:106` | Max cabin temperature. | No — tuning constant; could be constexpr. |
| `SHIP_MIN_CABIN_TEMP` | `Core/Entities/ShipEntity.h:107` | Min cabin temperature. | No — tuning constant; could be constexpr. |
| `EJECTA_TEMP_FACTOR` | `Core/Entities/ShipEntity.h:108` | Temperature factor for ejected debris (unused). | No — tuning constant; could be constexpr. |
| `DEFAULT_HYPERSPACE_SPIN_TIME` | `Core/Entities/ShipEntity.h:109` | Default hyperspace spin-up time. | No — tuning constant; could be constexpr. |
| `SUN_TEMPERATURE` | `Core/Entities/ShipEntity.h:111` | Ambient temperature near a sun. | No — tuning constant; could be constexpr. |
| `MAX_ESCORTS` | `Core/Entities/ShipEntity.h:113` | Max escorts per ship. | No — tuning constant; could be constexpr. |
| `ESCORT_SPACING_FACTOR` | `Core/Entities/ShipEntity.h:114` | Spacing factor between escorts (unused). | No — tuning constant; could be constexpr. |
| `SHIPENTITY_MAX_MISSILES` | `Core/Entities/ShipEntity.h:116` | Max missiles a ship can carry. | No — tuning constant; could be constexpr. |
| `TURRET_TYPICAL_ENERGY` | `Core/Entities/ShipEntity.h:118` | Typical turret shot energy. | No — tuning constant; could be constexpr. |
| `TURRET_SHOT_SPEED` | `Core/Entities/ShipEntity.h:119` | Turret shot speed. | No — tuning constant; could be constexpr. |
| `TURRET_SHOT_DURATION` | `Core/Entities/ShipEntity.h:120` | Turret shot lifetime. | No — tuning constant; could be constexpr. |
| `TURRET_SHOT_RANGE` | `Core/Entities/ShipEntity.h:121` | Turret shot range. | No — tuning constant; could be constexpr. |
| `TURRET_SHOT_FREQUENCY` | `Core/Entities/ShipEntity.h:122` | Turret shot repeat interval. | No — tuning constant; could be constexpr. |
| `NPC_PLASMA_SPEED` | `Core/Entities/ShipEntity.h:125` | NPC plasma shot speed (only used by unused range macro). | No — tuning constant; could be constexpr. |
| `MAIN_PLASMA_DURATION` | `Core/Entities/ShipEntity.h:126` | Lifetime of plasma shots. | No — tuning constant; could be constexpr. |
| `NPC_PLASMA_RANGE` | `Core/Entities/ShipEntity.h:127` | NPC plasma shot range (unused). | No — tuning constant; could be constexpr. |
| `PLAYER_PLASMA_SPEED` | `Core/Entities/ShipEntity.h:129` | Player plasma shot speed (only used by unused range macro). | No — tuning constant; could be constexpr. |
| `PLAYER_PLASMA_RANGE` | `Core/Entities/ShipEntity.h:130` | Player plasma shot range (unused). | No — tuning constant; could be constexpr. |
| `TRACTOR_FORCE` | `Core/Entities/ShipEntity.h:132` | Tractor beam force. | No — tuning constant; could be constexpr. |
| `MAX_SCAN_NUMBER` | `Core/Entities/ShipEntity.h:138` | Max entities tracked by scanner. | No — tuning constant; could be constexpr. |
| `BASELINE_SHIELD_LEVEL` | `Core/Entities/ShipEntity.h:140` | Max shield level with no boosters. | No — tuning constant; could be constexpr. |
| `INITIAL_SHOT_TIME` | `Core/Entities/ShipEntity.h:141` | Initial shot timer value for weapons. | No — tuning constant; could be constexpr. |
| `MIN_FUEL` | `Core/Entities/ShipEntity.h:143` | Minimum fuel needed for afterburner. | No — tuning constant; could be constexpr. |
| `MAX_JUMP_RANGE` | `Core/Entities/ShipEntity.h:146`, `Core/Entities/ShipEntity.h:148` | Max hyperspace jump range in light years. | Yes — switched by #ifdef OO_DUMP_PLANETINFO debug build. |
| `ENTITY_PERSONALITY_MAX` | `Core/Entities/ShipEntity.h:151` | Maximum entity personality value. | No — tuning constant; could be constexpr. |
| `ENTITY_PERSONALITY_INVALID` | `Core/Entities/ShipEntity.h:152` | Sentinel for invalid entity personality. | No — sentinel constant; could be constexpr. |
| `WEAPON_COOLING_FACTOR` | `Core/Entities/ShipEntity.h:154` | Weapon cooling rate. | No — tuning constant; could be constexpr. |
| `NPC_MAX_WEAPON_TEMP` | `Core/Entities/ShipEntity.h:155` | Max NPC weapon temperature. | No — tuning constant; could be constexpr. |
| `WEAPON_COOLING_CUTOUT` | `Core/Entities/ShipEntity.h:156` | Weapon temp fraction triggering cut-out. | No — tuning constant; could be constexpr. |
| `COMBAT_AI_WEAPON_TEMP_READY` | `Core/Entities/ShipEntity.h:158` | Weapon temperature below which AI deems weapon ready. | No — tuning constant; could be constexpr. |
| `COMBAT_AI_WEAPON_TEMP_USABLE` | `Core/Entities/ShipEntity.h:159` | Weapon temperature below which AI deems weapon usable. | No — tuning constant; could be constexpr. |
| `COMBAT_AI_CONFIDENCE_FACTOR` | `Core/Entities/ShipEntity.h:162` | AI combat confidence scaling factor. | No — tuning constant; could be constexpr. |
| `COMBAT_AI_ISNT_AWFUL` | `Core/Entities/ShipEntity.h:163` | AI skill threshold above hopeless. | No — tuning constant; could be constexpr. |
| `COMBAT_AI_IS_SMART` | `Core/Entities/ShipEntity.h:165` | AI skill threshold for smart behaviour. | No — tuning constant; could be constexpr. |
| `COMBAT_AI_FLEES_BETTER` | `Core/Entities/ShipEntity.h:167` | AI skill threshold for better fleeing. | No — tuning constant; could be constexpr. |
| `COMBAT_AI_DOGFIGHTER` | `Core/Entities/ShipEntity.h:169` | AI skill threshold for dogfighting. | No — tuning constant; could be constexpr. |
| `COMBAT_AI_TRACKS_CLOSER` | `Core/Entities/ShipEntity.h:171` | AI skill threshold for closer tracking. | No — tuning constant; could be constexpr. |
| `COMBAT_AI_USES_SNIPING` | `Core/Entities/ShipEntity.h:172` | AI skill threshold for sniping (unused). | No — tuning constant; could be constexpr. |
| `COMBAT_AI_FLEES_BETTER_2` | `Core/Entities/ShipEntity.h:174` | AI skill threshold for best fleeing. | No — tuning constant; could be constexpr. |
| `COMBAT_AI_STANDARD_REACTION_TIME` | `Core/Entities/ShipEntity.h:176` | Standard AI combat reaction time. | No — tuning constant; could be constexpr. |
| `MAX_LANDING_SPEED` | `Core/Entities/ShipEntity.h:178` | Max speed allowed when landing. | No — tuning constant; could be constexpr. |
| `MAX_LANDING_SPEED2` | `Core/Entities/ShipEntity.h:179` | Square of MAX_LANDING_SPEED. | No — tuning constant; could be constexpr. |
| `MAX_COS` | `Core/Entities/ShipEntity.h:181` | Cosine threshold for aligned-enough navigation. | No — tuning constant; could be constexpr. |
| `MAX_COS2` | `Core/Entities/ShipEntity.h:183` | Square of MAX_COS. | No — tuning constant; could be constexpr. |
| `ShipScriptEvent` | `Core/Entities/ShipEntity.h:1591` | Dispatches ship script event with JS args. | No — variadic helper; could be inline variadic template. |
| `ShipScriptEventNoCx` | `Core/Entities/ShipEntity.h:1602` | Dispatches ship script event without context (unused). | No — variadic helper; could be inline variadic template. |
| `KEY_SHIP_KEY` | `Core/Entities/ShipEntityLoadRestore.cpp:43` | Save-state key for ship key. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_SHIPDATA_OVERRIDES` | `Core/Entities/ShipEntityLoadRestore.cpp:44` | Save-state key for shipdata overrides. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_SHIPDATA_DELETES` | `Core/Entities/ShipEntityLoadRestore.cpp:45` | Save-state key for shipdata deletions. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_PRIMARY_ROLE` | `Core/Entities/ShipEntityLoadRestore.cpp:46` | Save-state key for primary role. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_POSITION` | `Core/Entities/ShipEntityLoadRestore.cpp:47` | Save-state key for position. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_ORIENTATION` | `Core/Entities/ShipEntityLoadRestore.cpp:48` | Save-state key for orientation. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_ROLES` | `Core/Entities/ShipEntityLoadRestore.cpp:49` | Save-state key for roles. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_FUEL` | `Core/Entities/ShipEntityLoadRestore.cpp:50` | Save-state key for fuel. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_BOUNTY` | `Core/Entities/ShipEntityLoadRestore.cpp:51` | Save-state key for bounty. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_ENERGY_LEVEL` | `Core/Entities/ShipEntityLoadRestore.cpp:52` | Save-state key for energy level. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_EQUIPMENT` | `Core/Entities/ShipEntityLoadRestore.cpp:53` | Save-state key for equipment. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_MISSILES` | `Core/Entities/ShipEntityLoadRestore.cpp:54` | Save-state key for missiles. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_FORWARD_WEAPON` | `Core/Entities/ShipEntityLoadRestore.cpp:55` | Save-state key for forward weapon type. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_AFT_WEAPON` | `Core/Entities/ShipEntityLoadRestore.cpp:56` | Save-state key for aft weapon type. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_SCAN_CLASS` | `Core/Entities/ShipEntityLoadRestore.cpp:57` | Save-state key for scan class. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_AI` | `Core/Entities/ShipEntityLoadRestore.cpp:60` | Save-state key for AI name. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_GROUP_ID` | `Core/Entities/ShipEntityLoadRestore.cpp:63` | Save-state key for group id. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_GROUP_NAME` | `Core/Entities/ShipEntityLoadRestore.cpp:64` | Save-state key for group name. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_IS_GROUP_LEADER` | `Core/Entities/ShipEntityLoadRestore.cpp:65` | Save-state key for group-leader flag. | No — dictionary key string; could be constexpr std::string_view. |
| `KEY_ESCORT_GROUP_ID` | `Core/Entities/ShipEntityLoadRestore.cpp:66` | Save-state key for escort group id. | No — dictionary key string; could be constexpr std::string_view. |
| `SKY_BASIS_STARS` | `Core/Entities/SkyEntity.cpp:44` | Number of stars in sky basis. | No — tuning constant; could be constexpr. |
| `SKY_BASIS_BLOBS` | `Core/Entities/SkyEntity.cpp:45` | Number of nebula blobs in sky basis. | No — tuning constant; could be constexpr. |
| `SKY_clusterChance` | `Core/Entities/SkyEntity.cpp:46` | Probability of star cluster in sky. | No — tuning constant; could be constexpr. |
| `SKY_alpha` | `Core/Entities/SkyEntity.cpp:47` | Sky blob alpha. | No — tuning constant; could be constexpr. |
| `SKY_scale` | `Core/Entities/SkyEntity.cpp:48` | Sky layer scale. | No — tuning constant; could be constexpr. |
| `STATION_MAX_POLICE` | `Core/Entities/StationEntity.h:66` | Max police ships per station. | No — tuning constant; could be constexpr. |
| `STATION_DELAY_BETWEEN_LAUNCHES` | `Core/Entities/StationEntity.h:68` | Delay between station launches. | No — tuning constant; could be constexpr. |
| `STATION_LAUNCH_RETRY_INTERVAL` | `Core/Entities/StationEntity.h:70` | Retry interval for blocked launches. | No — tuning constant; could be constexpr. |
| `MAX_DOCKING_STAGES` | `Core/Entities/StationEntity.h:72` | Max docking stages for a station. | No — tuning constant; could be constexpr. |
| `DOCKING_CLEARANCE_WINDOW` | `Core/Entities/StationEntity.h:74` | Time window for station docking clearance. | No — tuning constant; could be constexpr. |
| `OO_WORMHOLE_COLOR_BOOST` | `Core/Entities/WormholeEntity.cpp:56` | Wormhole colour brightness boost. | No — tuning constant; could be constexpr. |
| `OO_WORMHOLE_COLOR_FVEC4` | `Core/Entities/WormholeEntity.cpp:57` | Wormhole base RGBA colour. | No — tuning constant; could be constexpr. |
| `WORMHOLE_EXPIRES_TIMEINTERVAL` | `Core/Entities/WormholeEntity.h:53` | Wormhole lifetime (unused). | No — tuning constant; could be constexpr. |
| `WORMHOLE_SHRINK_RATE` | `Core/Entities/WormholeEntity.h:54` | Wormhole shrink rate. | No — tuning constant; could be constexpr. |
| `WORMHOLE_LEADER_SPEED_FACTOR` | `Core/Entities/WormholeEntity.h:55` | Leader speed factor in wormhole. | No — tuning constant; could be constexpr. |

## HUD and GUI (`HeadUpDisplay`, `GuiDisplayGen`)

| Macro | Where | Purpose | Feature flag? |
|---|---|---|---|
| GUI_DEFAULT_COLUMNS | Core/GuiDisplayGen.h:59 | GUI grid default columns. | No — tuning constant; could be constexpr. |
| GUI_DEFAULT_ROWS | Core/GuiDisplayGen.h:60 | GUI grid default rows. | No — tuning constant; could be constexpr. |
| GUI_MAX_ROWS | Core/GuiDisplayGen.h:62 | GUI grid max rows. | No — tuning constant; could be constexpr. |
| GUI_MAX_COLUMNS | Core/GuiDisplayGen.h:63 | GUI grid max columns. | No — tuning constant; could be constexpr. |
| MAIN_GUI_PIXEL_HEIGHT | Core/GuiDisplayGen.h:64 | Main GUI height in pixels. | No — tuning constant; could be constexpr. |
| MAIN_GUI_PIXEL_WIDTH | Core/GuiDisplayGen.h:65 | Main GUI width in pixels. | No — tuning constant; could be constexpr. |
| MAIN_GUI_ROW_HEIGHT | Core/GuiDisplayGen.h:66 | Main GUI row height in pixels. | No — tuning constant; could be constexpr. |
| MAIN_GUI_ROW_WIDTH | Core/GuiDisplayGen.h:67 | Main GUI row width in pixels (unused). | No — tuning constant; could be constexpr. |
| MAIN_GUI_PIXEL_ROW_START | Core/GuiDisplayGen.h:68 | Main GUI row start in pixels. | No — tuning constant; could be constexpr. |
| ONE_SIXTEENTH | Core/HeadUpDisplay.cpp:69 | Fractional constant 0.0625. | No — numeric constant; could be constexpr. |
| ONE_SIXTYFOURTH | Core/HeadUpDisplay.cpp:70 | Fractional constant 0.015625. | No — numeric constant; could be constexpr. |
| DEFAULT_OVERALL_ALPHA | Core/HeadUpDisplay.cpp:71 | Default overall HUD alpha. | No — tuning constant; could be constexpr. |
| GLYPH_SCALE_FACTOR | Core/HeadUpDisplay.cpp:72 | Glyph scale factor for HUD text. | No — tuning constant; could be constexpr. |
| IDENTIFY_SCANNER_LOLLIPOPS | Core/HeadUpDisplay.cpp:73 | Debug aid to identify scanner lollipops; hard-disabled. | Yes — debug aid compiled out via 0 && OOLITE_DEBUG. |
| NOT_DEFINED | Core/HeadUpDisplay.cpp:75 | Sentinel for an unset HUD value. | No — sentinel; could be constexpr float. |
| DO_SET_COLOR | Core/HeadUpDisplay.cpp:80 | Sets GL colour from HUD info for a key. | No — function-like helper; could be inline function. |
| SET_COLOR | Core/HeadUpDisplay.cpp:81 | Shorthand for setting GL colour from a colour key. | No — function-like helper; could be inline function. |
| SET_COLOR_LOW | Core/HeadUpDisplay.cpp:82 | Shorthand for setting GL colour from a colour key. | No — function-like helper; could be inline function. |
| SET_COLOR_MEDIUM | Core/HeadUpDisplay.cpp:83 | Shorthand for setting GL colour from a colour key. | No — function-like helper; could be inline function. |
| SET_COLOR_HIGH | Core/HeadUpDisplay.cpp:84 | Shorthand for setting GL colour from a colour key. | No — function-like helper; could be inline function. |
| SET_COLOR_CRITICAL | Core/HeadUpDisplay.cpp:85 | Shorthand for setting GL colour from a colour key. | No — function-like helper; could be inline function. |
| SET_COLOR_SURROUND | Core/HeadUpDisplay.cpp:86 | Shorthand for setting GL colour from a colour key. | No — function-like helper; could be inline function. |
| SCANNER_CENTRE_X | Core/HeadUpDisplay.h:67 | Scanner default centre X. | No — tuning constant; could be constexpr. |
| SCANNER_CENTRE_Y | Core/HeadUpDisplay.h:68 | Scanner default centre Y. | No — tuning constant; could be constexpr. |
| SCANNER_SCALE | Core/HeadUpDisplay.h:69 | Scanner scale. | No — tuning constant; could be constexpr. |
| SCANNER_WIDTH | Core/HeadUpDisplay.h:70 | Scanner default width. | No — tuning constant; could be constexpr. |
| SCANNER_HEIGHT | Core/HeadUpDisplay.h:71 | Scanner default height. | No — tuning constant; could be constexpr. |
| SCANNER_MAX_ZOOM | Core/HeadUpDisplay.h:73 | Scanner max zoom (unused). | No — tuning constant; could be constexpr. |
| SCANNER_ZOOM_LEVELS | Core/HeadUpDisplay.h:74 | Scanner zoom level count. | No — tuning constant; could be constexpr. |
| ZOOM_INDICATOR_CENTRE_X | Core/HeadUpDisplay.h:75 | Zoom indicator default centre X. | No — tuning constant; could be constexpr. |
| ZOOM_INDICATOR_CENTRE_Y | Core/HeadUpDisplay.h:76 | Zoom indicator default centre Y. | No — tuning constant; could be constexpr. |
| ZOOM_INDICATOR_WIDTH | Core/HeadUpDisplay.h:77 | Zoom indicator default width. | No — tuning constant; could be constexpr. |
| ZOOM_INDICATOR_HEIGHT | Core/HeadUpDisplay.h:78 | Zoom indicator default height. | No — tuning constant; could be constexpr. |
| ZOOM_LEVELS_IMAGE | Core/HeadUpDisplay.h:79 | Default image file name "zoom.png" (unused). | No — filename string; could be constexpr std::string_view. |
| COMPASS_IMAGE | Core/HeadUpDisplay.h:81 | Default image file name "compass.png" (unused). | No — filename string; could be constexpr std::string_view. |
| COMPASS_CENTRE_X | Core/HeadUpDisplay.h:82 | Compass default centre X. | No — tuning constant; could be constexpr. |
| COMPASS_CENTRE_Y | Core/HeadUpDisplay.h:83 | Compass default centre Y. | No — tuning constant; could be constexpr. |
| COMPASS_SIZE | Core/HeadUpDisplay.h:84 | Compass size (unused). | No — tuning constant; could be constexpr. |
| COMPASS_HALF_SIZE | Core/HeadUpDisplay.h:85 | Compass half size. | No — tuning constant; could be constexpr. |
| COMPASS_REDDOT_IMAGE | Core/HeadUpDisplay.h:86 | Default image file name "reddot.png" (unused). | No — filename string; could be constexpr std::string_view. |
| COMPASS_GREENDOT_IMAGE | Core/HeadUpDisplay.h:87 | Default image file name "greendot.png" (unused). | No — filename string; could be constexpr std::string_view. |
| COMPASS_DOT_SIZE | Core/HeadUpDisplay.h:88 | Compass dot size (unused). | No — tuning constant; could be constexpr. |
| COMPASS_HALF_DOT_SIZE | Core/HeadUpDisplay.h:89 | Compass half dot size (unused). | No — tuning constant; could be constexpr. |
| AEGIS_IMAGE | Core/HeadUpDisplay.h:91 | Default image file name "aegis.png" (unused). | No — filename string; could be constexpr std::string_view. |
| AEGIS_CENTRE_X | Core/HeadUpDisplay.h:92 | Aegis default centre X. | No — tuning constant; could be constexpr. |
| AEGIS_CENTRE_Y | Core/HeadUpDisplay.h:93 | Aegis default centre Y. | No — tuning constant; could be constexpr. |
| AEGIS_WIDTH | Core/HeadUpDisplay.h:94 | Aegis default width. | No — tuning constant; could be constexpr. |
| AEGIS_HEIGHT | Core/HeadUpDisplay.h:95 | Aegis default height. | No — tuning constant; could be constexpr. |
| SPEED_BAR_CENTRE_X | Core/HeadUpDisplay.h:97 | Speed bar default centre X. | No — tuning constant; could be constexpr. |
| SPEED_BAR_CENTRE_Y | Core/HeadUpDisplay.h:98 | Speed bar default centre Y. | No — tuning constant; could be constexpr. |
| SPEED_BAR_WIDTH | Core/HeadUpDisplay.h:99 | Speed bar default width. | No — tuning constant; could be constexpr. |
| SPEED_BAR_HEIGHT | Core/HeadUpDisplay.h:100 | Speed bar default height. | No — tuning constant; could be constexpr. |
| SPEED_BAR_DRAW_SURROUND | Core/HeadUpDisplay.h:101 | Speed bar default draw-surround flag. | No — default flag; could be constexpr bool. |
| ROLL_BAR_CENTRE_X | Core/HeadUpDisplay.h:103 | Roll bar default centre X. | No — tuning constant; could be constexpr. |
| ROLL_BAR_CENTRE_Y | Core/HeadUpDisplay.h:104 | Roll bar default centre Y. | No — tuning constant; could be constexpr. |
| ROLL_BAR_WIDTH | Core/HeadUpDisplay.h:105 | Roll bar default width. | No — tuning constant; could be constexpr. |
| ROLL_BAR_HEIGHT | Core/HeadUpDisplay.h:106 | Roll bar default height. | No — tuning constant; could be constexpr. |
| ROLL_BAR_DRAW_SURROUND | Core/HeadUpDisplay.h:107 | Roll bar default draw-surround flag. | No — default flag; could be constexpr bool. |
| PITCH_BAR_CENTRE_X | Core/HeadUpDisplay.h:109 | Pitch bar default centre X. | No — tuning constant; could be constexpr. |
| PITCH_BAR_CENTRE_Y | Core/HeadUpDisplay.h:110 | Pitch bar default centre Y. | No — tuning constant; could be constexpr. |
| PITCH_BAR_WIDTH | Core/HeadUpDisplay.h:111 | Pitch bar default width. | No — tuning constant; could be constexpr. |
| PITCH_BAR_HEIGHT | Core/HeadUpDisplay.h:112 | Pitch bar default height. | No — tuning constant; could be constexpr. |
| PITCH_BAR_DRAW_SURROUND | Core/HeadUpDisplay.h:113 | Pitch bar default draw-surround flag. | No — default flag; could be constexpr bool. |
| ENERGY_GAUGE_CENTRE_X | Core/HeadUpDisplay.h:115 | Energy gauge default centre X. | No — tuning constant; could be constexpr. |
| ENERGY_GAUGE_CENTRE_Y | Core/HeadUpDisplay.h:116 | Energy gauge default centre Y. | No — tuning constant; could be constexpr. |
| ENERGY_GAUGE_WIDTH | Core/HeadUpDisplay.h:117 | Energy gauge default width. | No — tuning constant; could be constexpr. |
| ENERGY_GAUGE_HEIGHT | Core/HeadUpDisplay.h:118 | Energy gauge default height. | No — tuning constant; could be constexpr. |
| ENERGY_GAUGE_DRAW_SURROUND | Core/HeadUpDisplay.h:119 | Energy gauge default draw-surround flag. | No — default flag; could be constexpr bool. |
| FORWARD_SHIELD_BAR_CENTRE_X | Core/HeadUpDisplay.h:121 | Forward shield bar default centre X. | No — tuning constant; could be constexpr. |
| FORWARD_SHIELD_BAR_CENTRE_Y | Core/HeadUpDisplay.h:122 | Forward shield bar default centre Y. | No — tuning constant; could be constexpr. |
| FORWARD_SHIELD_BAR_WIDTH | Core/HeadUpDisplay.h:123 | Forward shield bar default width. | No — tuning constant; could be constexpr. |
| FORWARD_SHIELD_BAR_HEIGHT | Core/HeadUpDisplay.h:124 | Forward shield bar default height. | No — tuning constant; could be constexpr. |
| FORWARD_SHIELD_BAR_DRAW_SURROUND | Core/HeadUpDisplay.h:125 | Forward shield bar default draw-surround flag. | No — default flag; could be constexpr bool. |
| AFT_SHIELD_BAR_CENTRE_X | Core/HeadUpDisplay.h:127 | Aft shield bar default centre X. | No — tuning constant; could be constexpr. |
| AFT_SHIELD_BAR_CENTRE_Y | Core/HeadUpDisplay.h:128 | Aft shield bar default centre Y. | No — tuning constant; could be constexpr. |
| AFT_SHIELD_BAR_WIDTH | Core/HeadUpDisplay.h:129 | Aft shield bar default width. | No — tuning constant; could be constexpr. |
| AFT_SHIELD_BAR_HEIGHT | Core/HeadUpDisplay.h:130 | Aft shield bar default height. | No — tuning constant; could be constexpr. |
| AFT_SHIELD_BAR_DRAW_SURROUND | Core/HeadUpDisplay.h:131 | Aft shield bar default draw-surround flag. | No — default flag; could be constexpr bool. |
| FUEL_BAR_CENTRE_X | Core/HeadUpDisplay.h:133 | Fuel bar default centre X. | No — tuning constant; could be constexpr. |
| FUEL_BAR_CENTRE_Y | Core/HeadUpDisplay.h:134 | Fuel bar default centre Y. | No — tuning constant; could be constexpr. |
| FUEL_BAR_WIDTH | Core/HeadUpDisplay.h:135 | Fuel bar default width. | No — tuning constant; could be constexpr. |
| FUEL_BAR_HEIGHT | Core/HeadUpDisplay.h:136 | Fuel bar default height. | No — tuning constant; could be constexpr. |
| WITCHDEST_CENTRE_X | Core/HeadUpDisplay.h:138 | Witchdest default centre X. | No — tuning constant; could be constexpr. |
| WITCHDEST_CENTRE_Y | Core/HeadUpDisplay.h:139 | Witchdest default centre Y. | No — tuning constant; could be constexpr. |
| WITCHDEST_WIDTH | Core/HeadUpDisplay.h:140 | Witchdest default width. | No — tuning constant; could be constexpr. |
| WITCHDEST_HEIGHT | Core/HeadUpDisplay.h:141 | Witchdest default height. | No — tuning constant; could be constexpr. |
| CABIN_TEMP_BAR_CENTRE_X | Core/HeadUpDisplay.h:143 | Cabin temp bar default centre X. | No — tuning constant; could be constexpr. |
| CABIN_TEMP_BAR_CENTRE_Y | Core/HeadUpDisplay.h:144 | Cabin temp bar default centre Y. | No — tuning constant; could be constexpr. |
| CABIN_TEMP_BAR_WIDTH | Core/HeadUpDisplay.h:145 | Cabin temp bar default width. | No — tuning constant; could be constexpr. |
| CABIN_TEMP_BAR_HEIGHT | Core/HeadUpDisplay.h:146 | Cabin temp bar default height. | No — tuning constant; could be constexpr. |
| WEAPON_TEMP_BAR_CENTRE_X | Core/HeadUpDisplay.h:148 | Weapon temp bar default centre X. | No — tuning constant; could be constexpr. |
| WEAPON_TEMP_BAR_CENTRE_Y | Core/HeadUpDisplay.h:149 | Weapon temp bar default centre Y. | No — tuning constant; could be constexpr. |
| WEAPON_TEMP_BAR_WIDTH | Core/HeadUpDisplay.h:150 | Weapon temp bar default width. | No — tuning constant; could be constexpr. |
| WEAPON_TEMP_BAR_HEIGHT | Core/HeadUpDisplay.h:151 | Weapon temp bar default height. | No — tuning constant; could be constexpr. |
| ALTITUDE_BAR_CENTRE_X | Core/HeadUpDisplay.h:153 | Altitude bar default centre X. | No — tuning constant; could be constexpr. |
| ALTITUDE_BAR_CENTRE_Y | Core/HeadUpDisplay.h:154 | Altitude bar default centre Y. | No — tuning constant; could be constexpr. |
| ALTITUDE_BAR_WIDTH | Core/HeadUpDisplay.h:155 | Altitude bar default width. | No — tuning constant; could be constexpr. |
| ALTITUDE_BAR_HEIGHT | Core/HeadUpDisplay.h:156 | Altitude bar default height. | No — tuning constant; could be constexpr. |
| MISSILES_DISPLAY_X | Core/HeadUpDisplay.h:158 | Missiles default X. | No — tuning constant; could be constexpr. |
| MISSILES_DISPLAY_Y | Core/HeadUpDisplay.h:159 | Missiles default Y. | No — tuning constant; could be constexpr. |
| MISSILES_DISPLAY_SPACING | Core/HeadUpDisplay.h:160 | Missiles default spacing. | No — tuning constant; could be constexpr. |
| MISSILE_ICON_WIDTH | Core/HeadUpDisplay.h:161 | Missile icon default width. | No — tuning constant; could be constexpr. |
| MISSILE_ICON_HEIGHT | Core/HeadUpDisplay.h:162 | Missile icon default height. | No — tuning constant; could be constexpr. |
| PRIMED_DISPLAY_X | Core/HeadUpDisplay.h:164 | Primed default X. | No — tuning constant; could be constexpr. |
| PRIMED_DISPLAY_Y | Core/HeadUpDisplay.h:165 | Primed default Y. | No — tuning constant; could be constexpr. |
| PRIMED_DISPLAY_WIDTH | Core/HeadUpDisplay.h:166 | Primed default width. | No — tuning constant; could be constexpr. |
| PRIMED_DISPLAY_HEIGHT | Core/HeadUpDisplay.h:167 | Primed default height. | No — tuning constant; could be constexpr. |
| ASCTARGET_DISPLAY_X | Core/HeadUpDisplay.h:169 | Asctarget default X. | No — tuning constant; could be constexpr. |
| ASCTARGET_DISPLAY_Y | Core/HeadUpDisplay.h:170 | Asctarget default Y. | No — tuning constant; could be constexpr. |
| ASCTARGET_DISPLAY_WIDTH | Core/HeadUpDisplay.h:171 | Asctarget default width. | No — tuning constant; could be constexpr. |
| ASCTARGET_DISPLAY_HEIGHT | Core/HeadUpDisplay.h:172 | Asctarget default height. | No — tuning constant; could be constexpr. |
| CLOCK_DISPLAY_X | Core/HeadUpDisplay.h:174 | Clock default X. | No — tuning constant; could be constexpr. |
| CLOCK_DISPLAY_Y | Core/HeadUpDisplay.h:175 | Clock default Y. | No — tuning constant; could be constexpr. |
| CLOCK_DISPLAY_WIDTH | Core/HeadUpDisplay.h:176 | Clock default width. | No — tuning constant; could be constexpr. |
| CLOCK_DISPLAY_HEIGHT | Core/HeadUpDisplay.h:177 | Clock default height. | No — tuning constant; could be constexpr. |
| WEAPONSOFFLINETEXT_DISPLAY_X | Core/HeadUpDisplay.h:179 | Weaponsofflinetext default X. | No — tuning constant; could be constexpr. |
| WEAPONSOFFLINETEXT_DISPLAY_Y | Core/HeadUpDisplay.h:180 | Weaponsofflinetext default Y. | No — tuning constant; could be constexpr. |
| WEAPONSOFFLINETEXT_WIDTH | Core/HeadUpDisplay.h:181 | Weaponsofflinetext default width. | No — tuning constant; could be constexpr. |
| WEAPONSOFFLINETEXT_HEIGHT | Core/HeadUpDisplay.h:182 | Weaponsofflinetext default height. | No — tuning constant; could be constexpr. |
| FPSINFO_DISPLAY_X | Core/HeadUpDisplay.h:184 | Fpsinfo default X. | No — tuning constant; could be constexpr. |
| FPSINFO_DISPLAY_Y | Core/HeadUpDisplay.h:185 | Fpsinfo default Y. | No — tuning constant; could be constexpr. |
| FPSINFO_DISPLAY_WIDTH | Core/HeadUpDisplay.h:186 | Fpsinfo default width. | No — tuning constant; could be constexpr. |
| FPSINFO_DISPLAY_HEIGHT | Core/HeadUpDisplay.h:187 | Fpsinfo default height. | No — tuning constant; could be constexpr. |
| STATUS_LIGHT_CENTRE_X | Core/HeadUpDisplay.h:189 | Status light default centre X. | No — tuning constant; could be constexpr. |
| STATUS_LIGHT_CENTRE_Y | Core/HeadUpDisplay.h:190 | Status light default centre Y. | No — tuning constant; could be constexpr. |
| STATUS_LIGHT_WIDTH | Core/HeadUpDisplay.h:191 | Status light default width (unused). | No — tuning constant; could be constexpr. |
| STATUS_LIGHT_HEIGHT | Core/HeadUpDisplay.h:192 | Status light default height. | No — tuning constant; could be constexpr. |
| HIT_INDICATOR_CENTRE_X | Core/HeadUpDisplay.h:194 | Hit indicator default centre X (unused). | No — tuning constant; could be constexpr. |
| HIT_INDICATOR_CENTRE_Y | Core/HeadUpDisplay.h:195 | Hit indicator default centre Y (unused). | No — tuning constant; could be constexpr. |
| SCOOPSTATUS_CENTRE_X | Core/HeadUpDisplay.h:197 | Scoopstatus default centre X. | No — tuning constant; could be constexpr. |
| SCOOPSTATUS_CENTRE_Y | Core/HeadUpDisplay.h:198 | Scoopstatus default centre Y. | No — tuning constant; could be constexpr. |
| SCOOPSTATUS_WIDTH | Core/HeadUpDisplay.h:199 | Scoopstatus default width. | No — tuning constant; could be constexpr. |
| SCOOPSTATUS_HEIGHT | Core/HeadUpDisplay.h:200 | Scoopstatus default height. | No — tuning constant; could be constexpr. |
| MFD_TEXT_WIDTH | Core/HeadUpDisplay.h:202 | Mfd text default width. | No — tuning constant; could be constexpr. |
| MFD_TEXT_HEIGHT | Core/HeadUpDisplay.h:203 | Mfd text default height. | No — tuning constant; could be constexpr. |
| DIALS_KEY | Core/HeadUpDisplay.h:205 | HUD plist key "dials". | No — dictionary key string; could be constexpr std::string_view. |
| LEGENDS_KEY | Core/HeadUpDisplay.h:206 | HUD plist key "legends". | No — dictionary key string; could be constexpr std::string_view. |
| MFDS_KEY | Core/HeadUpDisplay.h:207 | HUD plist key "multi_function_displays". | No — dictionary key string; could be constexpr std::string_view. |
| X_KEY | Core/HeadUpDisplay.h:208 | HUD plist key "x". | No — dictionary key string; could be constexpr std::string_view. |
| Y_KEY | Core/HeadUpDisplay.h:209 | HUD plist key "y". | No — dictionary key string; could be constexpr std::string_view. |
| X_ORIGIN_KEY | Core/HeadUpDisplay.h:210 | HUD plist key "x_origin". | No — dictionary key string; could be constexpr std::string_view. |
| Y_ORIGIN_KEY | Core/HeadUpDisplay.h:211 | HUD plist key "y_origin". | No — dictionary key string; could be constexpr std::string_view. |
| SPACING_KEY | Core/HeadUpDisplay.h:212 | HUD plist key "spacing". | No — dictionary key string; could be constexpr std::string_view. |
| ALPHA_KEY | Core/HeadUpDisplay.h:213 | HUD plist key "alpha". | No — dictionary key string; could be constexpr std::string_view. |
| SELECTOR_KEY | Core/HeadUpDisplay.h:214 | HUD plist key "selector". | No — dictionary key string; could be constexpr std::string_view. |
| IMAGE_KEY | Core/HeadUpDisplay.h:215 | HUD plist key "image". | No — dictionary key string; could be constexpr std::string_view. |
| WIDTH_KEY | Core/HeadUpDisplay.h:216 | HUD plist key "width". | No — dictionary key string; could be constexpr std::string_view. |
| HEIGHT_KEY | Core/HeadUpDisplay.h:217 | HUD plist key "height". | No — dictionary key string; could be constexpr std::string_view. |
| SPRITE_KEY | Core/HeadUpDisplay.h:218 | HUD plist key "sprite" (unused). | No — dictionary key string; could be constexpr std::string_view. |
| DRAW_SURROUND_KEY | Core/HeadUpDisplay.h:219 | HUD plist key "draw_surround". | No — dictionary key string; could be constexpr std::string_view. |
| EQUIPMENT_REQUIRED_KEY | Core/HeadUpDisplay.h:220 | HUD plist key "equipment_required". | No — dictionary key string; could be constexpr std::string_view. |
| ALERT_CONDITIONS_KEY | Core/HeadUpDisplay.h:221 | HUD plist key "alert_conditions". | No — dictionary key string; could be constexpr std::string_view. |
| VIEWSCREEN_KEY | Core/HeadUpDisplay.h:222 | HUD plist key "viewscreen_only". | No — dictionary key string; could be constexpr std::string_view. |
| DIAL_REQUIRED_KEY | Core/HeadUpDisplay.h:223 | HUD plist key "with_dial". | No — dictionary key string; could be constexpr std::string_view. |
| LABELLED_KEY | Core/HeadUpDisplay.h:224 | HUD plist key "labelled". | No — dictionary key string; could be constexpr std::string_view. |
| TEXT_KEY | Core/HeadUpDisplay.h:225 | HUD plist key "text". | No — dictionary key string; could be constexpr std::string_view. |
| RGB_COLOR_KEY | Core/HeadUpDisplay.h:226 | HUD plist key "rgb_color". | No — dictionary key string; could be constexpr std::string_view. |
| COLOR_KEY | Core/HeadUpDisplay.h:227 | HUD plist key "color". | No — dictionary key string; could be constexpr std::string_view. |
| COLOR_KEY_LOW | Core/HeadUpDisplay.h:228 | HUD plist key "color_low". | No — dictionary key string; could be constexpr std::string_view. |
| COLOR_KEY_MEDIUM | Core/HeadUpDisplay.h:229 | HUD plist key "color_medium". | No — dictionary key string; could be constexpr std::string_view. |
| COLOR_KEY_HIGH | Core/HeadUpDisplay.h:230 | HUD plist key "color_high". | No — dictionary key string; could be constexpr std::string_view. |
| COLOR_KEY_CRITICAL | Core/HeadUpDisplay.h:231 | HUD plist key "color_critical". | No — dictionary key string; could be constexpr std::string_view. |
| COLOR_KEY_SURROUND | Core/HeadUpDisplay.h:232 | HUD plist key "color_surround". | No — dictionary key string; could be constexpr std::string_view. |
| N_BARS_KEY | Core/HeadUpDisplay.h:233 | HUD plist key "n_bars". | No — dictionary key string; could be constexpr std::string_view. |
| CUSTOM_DIAL_KEY | Core/HeadUpDisplay.h:234 | HUD plist key "data_source". | No — dictionary key string; could be constexpr std::string_view. |
| ROWS_KEY | Core/HeadUpDisplay.h:236 | HUD plist key "rows" (unused). | No — dictionary key string; could be constexpr std::string_view. |
| COLUMNS_KEY | Core/HeadUpDisplay.h:237 | HUD plist key "columns" (unused). | No — dictionary key string; could be constexpr std::string_view. |
| ROW_HEIGHT_KEY | Core/HeadUpDisplay.h:238 | HUD plist key "row_height". | No — dictionary key string; could be constexpr std::string_view. |
| ROW_START_KEY | Core/HeadUpDisplay.h:239 | HUD plist key "row_start" (unused). | No — dictionary key string; could be constexpr std::string_view. |
| TITLE_KEY | Core/HeadUpDisplay.h:240 | HUD plist key "title". | No — dictionary key string; could be constexpr std::string_view. |
| BACKGROUND_RGBA_KEY | Core/HeadUpDisplay.h:241 | HUD plist key "background_rgba". | No — dictionary key string; could be constexpr std::string_view. |
| OVERALL_ALPHA_KEY | Core/HeadUpDisplay.h:242 | HUD plist key "overall_alpha" (unused). | No — dictionary key string; could be constexpr std::string_view. |
| NONLINEAR_SCANNER | Core/HeadUpDisplay.h:243 | Plist key "nonlinear_scanner" (unused). | No — dictionary key string; could be constexpr std::string_view. |
| Z1 | Core/HeadUpDisplay.h:245 | Current display Z depth from game view (unused). | No — function-like helper; could be inline function. |
| ONE_EIGHTH | Core/HeadUpDisplay.h:250 | Fractional constant 0.125. | No — numeric constant; could be constexpr. |
| MAX_ACCURACY_RANGE | Core/HeadUpDisplay.h:252 | Max range (m) for accuracy falloff. | No — tuning constant; could be constexpr. |
| ACCURACY_PROBABILITY_DECREASE_FACTOR | Core/HeadUpDisplay.h:253 | Accuracy probability decrease per distance. | No — tuning constant; could be constexpr. |
| MIN_PROBABILITY_ACCURACY | Core/HeadUpDisplay.h:255 | Minimum probability of high accuracy. | No — tuning constant; could be constexpr. |

## Scripting, string expander, Universe, OXP verifier, debug console

| Macro | Where | Purpose | Feature flag? |
|---|---|---|---|
| gDebugFlags | Core/Debug/OODebugFlags.h:89 | Debug flag bits, or constant 0 when disabled. | Already — stubbed out when meson debug-monitor option is off. |
| STANDARDS_ENFORCEMENT_DEFAULT | Core/Debug/OODebugStandards.cpp:73, Core/Debug/OODebugStandards.cpp:75 | Default standards-enforcement level. | Already — default follows debug-monitor meson option; runtime-adjustable. |
| OOInitDebugSupport | Core/Debug/OODebugSupport.h:38 | Initialise debug support, or no-op. | Already — compiled in by meson OO_DEBUG_MONITOR_ENABLED option. |
| OOALSTR | Core/Debug/OODebugTCPConsoleClient.cpp:34, Core/Debug/OOTCPStreamDecoderAbstractionLayer.h:38 | Spell a string literal for the abstraction layer. | No — string wrapper; could be inline function. |
| LogSendPacket | Core/Debug/OODebugTCPConsoleClient.cpp:79 | Log a sent TCP packet, or no-op. | Yes — compiled out unless OO_LOG_DEBUG_PROTOCOL_PACKETS defined. |
| PACKET_CASE | Core/Debug/OODebugTCPConsoleClient.cpp:770 | Switch case for TCP console packet type. | No — code-generation helper. |
| kOOTCPPacket_RequestConnection | Core/Debug/OODebugTCPConsoleProtocol.h:76 | Debug console packet type "RequestConnection". | No — protocol key string; could be constexpr string_view. |
| kOOTCPPacket_ApproveConnection | Core/Debug/OODebugTCPConsoleProtocol.h:86 | Debug console packet type "ApproveConnection". | No — protocol key string; could be constexpr string_view. |
| kOOTCPPacket_RejectConnection | Core/Debug/OODebugTCPConsoleProtocol.h:99 | Debug console packet type "RejectConnection". | No — protocol key string; could be constexpr string_view. |
| kOOTCPPacket_CloseConnection | Core/Debug/OODebugTCPConsoleProtocol.h:110 | Debug console packet type "CloseConnection". | No — protocol key string; could be constexpr string_view. |
| kOOTCPPacket_ConsoleOutput | Core/Debug/OODebugTCPConsoleProtocol.h:122 | Debug console packet type "ConsoleOutput". | No — protocol key string; could be constexpr string_view. |
| kOOTCPPacket_ClearConsole | Core/Debug/OODebugTCPConsoleProtocol.h:128 | Debug console packet type "ClearConsole". | No — protocol key string; could be constexpr string_view. |
| kOOTCPPacket_ShowConsole | Core/Debug/OODebugTCPConsoleProtocol.h:135 | Debug console packet type "ShowConsole". | No — protocol key string; could be constexpr string_view. |
| kOOTCPPacket_NoteConfiguration | Core/Debug/OODebugTCPConsoleProtocol.h:145 | Debug console packet type "NoteConfiguration". | No — protocol key string; could be constexpr string_view. |
| kOOTCPPacket_NoteConfigurationChange | Core/Debug/OODebugTCPConsoleProtocol.h:165 | Debug console packet type "NoteConfigurationChange". | No — protocol key string; could be constexpr string_view. |
| kOOTCPPacket_PerformCommand | Core/Debug/OODebugTCPConsoleProtocol.h:175 | Debug console packet type "PerformCommand". | No — protocol key string; could be constexpr string_view. |
| kOOTCPPacket_RequestConfigurationValue | Core/Debug/OODebugTCPConsoleProtocol.h:189 | Debug console packet type "RequestConfigurationValue". | No — protocol key string; could be constexpr string_view. |
| kOOTCPPacket_Ping | Core/Debug/OODebugTCPConsoleProtocol.h:202 | Debug console packet type "Ping". | No — protocol key string; could be constexpr string_view. |
| kOOTCPPacket_Pong | Core/Debug/OODebugTCPConsoleProtocol.h:213 | Debug console packet type "Pong". | No — protocol key string; could be constexpr string_view. |
| kOOTCPPacketType | Core/Debug/OODebugTCPConsoleProtocol.h:221 | Debug console protocol key "packet type". | No — protocol key string; could be constexpr string_view. |
| kOOTCPProtocolVersion | Core/Debug/OODebugTCPConsoleProtocol.h:229 | Debug console protocol key "protocol version". | No — protocol key string; could be constexpr string_view. |
| kOOTCPOoliteVersion | Core/Debug/OODebugTCPConsoleProtocol.h:237 | Debug console protocol key "Oolite version". | No — protocol key string; could be constexpr string_view. |
| kOOTCPMessage | Core/Debug/OODebugTCPConsoleProtocol.h:242 | Debug console protocol key "message". | No — protocol key string; could be constexpr string_view. |
| kOOTCPConsoleIdentity | Core/Debug/OODebugTCPConsoleProtocol.h:247 | Debug console protocol key "console identity". | No — protocol key string; could be constexpr string_view. |
| kOOTCPColorKey | Core/Debug/OODebugTCPConsoleProtocol.h:266 | Debug console protocol key "color key". | No — protocol key string; could be constexpr string_view. |
| kOOTCPEmphasisRanges | Core/Debug/OODebugTCPConsoleProtocol.h:273 | Debug console protocol key "emphasis ranges". | No — protocol key string; could be constexpr string_view. |
| kOOTCPConfiguration | Core/Debug/OODebugTCPConsoleProtocol.h:280 | Debug console protocol key "configuration". | No — protocol key string; could be constexpr string_view. |
| kOOTCPRemovedConfigurationKeys | Core/Debug/OODebugTCPConsoleProtocol.h:286 | Debug console protocol key "removed configuration keys". | No — protocol key string; could be constexpr string_view. |
| kOOTCPConfigurationKey | Core/Debug/OODebugTCPConsoleProtocol.h:292 | Debug console protocol key "configuration key". | No — protocol key string; could be constexpr string_view. |
| OOJS_PROPERTY_HIDDEN_RW | Core/Debug/OOJSConsole.cpp:193 | Declare hidden read-write JS property entry. | No — JS binding boilerplate. |
| DEBUG_FLAG_DECL | Core/Debug/OOJSConsole.cpp:241 | X-macro declaration generator for debug flag properties. | No — code-generation helper. |
| DEBUG_FLAG_CASE | Core/Debug/OOJSConsole.cpp:483 | X-macro case generator for debug flag lookup. | No — code-generation helper. |
| LONG_TIME | Core/Debug/OOJSConsole.cpp:1411 | Long but finite script time limit for console. | No — tuning constant; could be constexpr. |
| OO_PLAIN_CPP_UNIT | Core/Debug/OOTCPStreamDecoder.cpp:31, Core/Scripting/OOConstToJSString.cpp:26 | Marks translation unit built without Oolite runtime. | No — translation-unit marker for conditional includes. |
| LogOOTCPStreamDecoderPacket | Core/Debug/OOTCPStreamDecoder.cpp:46 | Log a decoded TCP packet, or no-op. | Yes — compiled out unless OO_LOG_DEBUG_PROTOCOL_PACKETS defined. |
| WARNINGS | Core/OOStringExpander.cpp:73, Core/OOStringExpander.cpp:75 | Enable expander warnings in debug builds. | Yes — compile-time toggle derived from OOLITE_DEBUG/OO_DEBUG_MONITOR_ENABLED. |
| OO_EXPANDER_RANDOM | Core/OOStringExpander.cpp:78 | Random byte from context-selected RNG. | No — function-like helper; could be inline function. |
| kSyntaxIssuePrefix | Core/OOStringExpander.cpp:250 | Prefix for expander syntax-issue messages. | No — message string; could be constexpr. |
| SyntaxError | Core/OOStringExpander.cpp:252 | Report a string-expander syntax error. | No — logging helper; could be inline function. |
| SyntaxWarning | Core/OOStringExpander.cpp:257, Core/OOStringExpander.cpp:261 | Report a syntax warning, or no-op. | Yes — compiled out unless WARNINGS (debug builds). |
| OPERATOR | Core/OOStringExpander.cpp:635 | Table entry for string-expander operator name. | No — code-generation helper. |
| kInvalidGEscapeMessage | Core/OOStringExpander.cpp:1275 | Error text for bad %G escape. | No — message string; could be constexpr. |
| kInvalidJEscapeMessage | Core/OOStringExpander.cpp:1339 | Error text for bad %J escape. | No — message string; could be constexpr. |
| OOEXPAND_ARGUMENT_COUNT | Core/OOStringExpander.h:180 | Count variadic macro arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_ARGUMENT_COUNT_INNER | Core/OOStringExpander.h:183 | Inner helper for argument counting. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_ARGUMENT_COUNT_EXTRACT_64TH_ARG | Core/OOStringExpander.h:185 | Pick the 64th argument for counting. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_ARGUMENT_COUNT_63_VALUES | Core/OOStringExpander.h:192 | Descending count list for argument counting. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP | Core/OOStringExpander.h:198 | Apply a macro to each variadic argument. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_INNER | Core/OOStringExpander.h:200 | Intermediate step of OOEXPAND_MAP. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_INNER2 | Core/OOStringExpander.h:202 | Intermediate step of OOEXPAND_MAP. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_INNER3 | Core/OOStringExpander.h:204 | Dispatch to OOEXPAND_MAP_IMPL_n. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_0 | Core/OOStringExpander.h:206 | OOEXPAND_MAP expansion for 1 argument. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_1 | Core/OOStringExpander.h:207 | OOEXPAND_MAP expansion for 2 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_2 | Core/OOStringExpander.h:208 | OOEXPAND_MAP expansion for 3 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_3 | Core/OOStringExpander.h:210 | OOEXPAND_MAP expansion for 4 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_4 | Core/OOStringExpander.h:212 | OOEXPAND_MAP expansion for 5 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_5 | Core/OOStringExpander.h:214 | OOEXPAND_MAP expansion for 6 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_6 | Core/OOStringExpander.h:216 | OOEXPAND_MAP expansion for 7 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_7 | Core/OOStringExpander.h:218 | OOEXPAND_MAP expansion for 8 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_8 | Core/OOStringExpander.h:220 | OOEXPAND_MAP expansion for 9 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_9 | Core/OOStringExpander.h:222 | OOEXPAND_MAP expansion for 10 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_10 | Core/OOStringExpander.h:224 | OOEXPAND_MAP expansion for 11 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_11 | Core/OOStringExpander.h:226 | OOEXPAND_MAP expansion for 12 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_12 | Core/OOStringExpander.h:228 | OOEXPAND_MAP expansion for 13 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_13 | Core/OOStringExpander.h:230 | OOEXPAND_MAP expansion for 14 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_14 | Core/OOStringExpander.h:232 | OOEXPAND_MAP expansion for 15 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_15 | Core/OOStringExpander.h:234 | OOEXPAND_MAP expansion for 16 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_16 | Core/OOStringExpander.h:236 | OOEXPAND_MAP expansion for 17 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_17 | Core/OOStringExpander.h:238 | OOEXPAND_MAP expansion for 18 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_18 | Core/OOStringExpander.h:240 | OOEXPAND_MAP expansion for 19 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_19 | Core/OOStringExpander.h:242 | OOEXPAND_MAP expansion for 20 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_20 | Core/OOStringExpander.h:244 | OOEXPAND_MAP expansion for 21 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_21 | Core/OOStringExpander.h:246 | OOEXPAND_MAP expansion for 22 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_22 | Core/OOStringExpander.h:248 | OOEXPAND_MAP expansion for 23 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_23 | Core/OOStringExpander.h:250 | OOEXPAND_MAP expansion for 24 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_24 | Core/OOStringExpander.h:252 | OOEXPAND_MAP expansion for 25 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_25 | Core/OOStringExpander.h:254 | OOEXPAND_MAP expansion for 26 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_26 | Core/OOStringExpander.h:256 | OOEXPAND_MAP expansion for 27 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_27 | Core/OOStringExpander.h:258 | OOEXPAND_MAP expansion for 28 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_28 | Core/OOStringExpander.h:260 | OOEXPAND_MAP expansion for 29 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_29 | Core/OOStringExpander.h:262 | OOEXPAND_MAP expansion for 30 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_30 | Core/OOStringExpander.h:264 | OOEXPAND_MAP expansion for 31 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_31 | Core/OOStringExpander.h:266 | OOEXPAND_MAP expansion for 32 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_32 | Core/OOStringExpander.h:268 | OOEXPAND_MAP expansion for 33 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_33 | Core/OOStringExpander.h:270 | OOEXPAND_MAP expansion for 34 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_34 | Core/OOStringExpander.h:272 | OOEXPAND_MAP expansion for 35 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_35 | Core/OOStringExpander.h:274 | OOEXPAND_MAP expansion for 36 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_36 | Core/OOStringExpander.h:276 | OOEXPAND_MAP expansion for 37 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_37 | Core/OOStringExpander.h:278 | OOEXPAND_MAP expansion for 38 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_38 | Core/OOStringExpander.h:280 | OOEXPAND_MAP expansion for 39 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_39 | Core/OOStringExpander.h:282 | OOEXPAND_MAP expansion for 40 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_40 | Core/OOStringExpander.h:284 | OOEXPAND_MAP expansion for 41 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_41 | Core/OOStringExpander.h:286 | OOEXPAND_MAP expansion for 42 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_42 | Core/OOStringExpander.h:288 | OOEXPAND_MAP expansion for 43 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_43 | Core/OOStringExpander.h:290 | OOEXPAND_MAP expansion for 44 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_44 | Core/OOStringExpander.h:292 | OOEXPAND_MAP expansion for 45 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_45 | Core/OOStringExpander.h:294 | OOEXPAND_MAP expansion for 46 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_46 | Core/OOStringExpander.h:296 | OOEXPAND_MAP expansion for 47 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_47 | Core/OOStringExpander.h:298 | OOEXPAND_MAP expansion for 48 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_48 | Core/OOStringExpander.h:300 | OOEXPAND_MAP expansion for 49 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_49 | Core/OOStringExpander.h:302 | OOEXPAND_MAP expansion for 50 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_50 | Core/OOStringExpander.h:304 | OOEXPAND_MAP expansion for 51 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_51 | Core/OOStringExpander.h:306 | OOEXPAND_MAP expansion for 52 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_52 | Core/OOStringExpander.h:308 | OOEXPAND_MAP expansion for 53 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_53 | Core/OOStringExpander.h:310 | OOEXPAND_MAP expansion for 54 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_54 | Core/OOStringExpander.h:312 | OOEXPAND_MAP expansion for 55 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_55 | Core/OOStringExpander.h:314 | OOEXPAND_MAP expansion for 56 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_56 | Core/OOStringExpander.h:316 | OOEXPAND_MAP expansion for 57 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_57 | Core/OOStringExpander.h:318 | OOEXPAND_MAP expansion for 58 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_58 | Core/OOStringExpander.h:320 | OOEXPAND_MAP expansion for 59 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_59 | Core/OOStringExpander.h:322 | OOEXPAND_MAP expansion for 60 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_60 | Core/OOStringExpander.h:324 | OOEXPAND_MAP expansion for 61 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_61 | Core/OOStringExpander.h:326 | OOEXPAND_MAP expansion for 62 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOEXPAND_MAP_IMPL_62 | Core/OOStringExpander.h:328 | OOEXPAND_MAP expansion for 63 arguments. | No — preprocessor metaprogramming; could be variadic templates/fold expression. |
| OOExpand | Core/OOStringExpander.h:344 | Variadic-argument front end to string expander. | No — variadic wrapper; could be variadic template function. |
| OOExpandKey | Core/OOStringExpander.h:347 | Variadic-argument front end to string expander. | No — variadic wrapper; could be variadic template function. |
| OOExpandKeyRandomized | Core/OOStringExpander.h:350 | Variadic-argument front end to string expander. | No — variadic wrapper; could be variadic template function. |
| OOExpandWithSeed | Core/OOStringExpander.h:356 | Variadic-argument front end to string expander. | No — variadic wrapper; could be variadic template function. |
| OOExpandKeyWithSeed | Core/OOStringExpander.h:359 | Variadic-argument front end to string expander. | No — variadic wrapper; could be variadic template function. |
| OOExpandWithOptions | Core/OOStringExpander.h:362 | Variadic-argument front end to string expander. | No — variadic wrapper; could be variadic template function. |
| OOEXPAND_CXX_ARG_DICTIONARY | Core/OOStringExpander.h:367 | Build argument dictionary for string expander. | No — code-generation helper; could be variadic template. |
| OOEXPAND_CXX_ARG_ENTRY | Core/OOStringExpander.h:370 | Build one name/value argument entry. | No — code-generation helper; could be variadic template. |
| interface | Core/OXPVerifier/OOOXPVerifier.cpp:45 | Windows COM "interface" mapped to struct. | No — Windows header workaround; scoped push/pop macro. |
| OO_OXP_VERIFIER_ENABLED | Core/OXPVerifier/OOOXPVerifier.h:40, Core/OXPVerifier/OOOXPVerifier.h:42 | Include OXP verifier code. | Already — set via meson (-DOO_OXP_VERIFIER_ENABLED=1). |
| PLIST_VERIFIER_DEBUG_DUMP_ENABLED | Core/OXPVerifier/OOPListSchemaVerifier.cpp:54 | Enable plist verifier debug dumping. | Yes — compile-time debug toggle. |
| DebugDumpIndent | Core/OXPVerifier/OOPListSchemaVerifier.cpp:71, Core/OXPVerifier/OOPListSchemaVerifier.cpp:92 | Debug-dump indent. (no-op when disabled). | No — logging helper gated by PLIST_VERIFIER_DEBUG_DUMP_ENABLED; could be inline function. |
| DebugDumpOutdent | Core/OXPVerifier/OOPListSchemaVerifier.cpp:75, Core/OXPVerifier/OOPListSchemaVerifier.cpp:95 | Debug-dump outdent. (no-op when disabled). | No — logging helper gated by PLIST_VERIFIER_DEBUG_DUMP_ENABLED; could be inline function. |
| DebugDumpPushIndent | Core/OXPVerifier/OOPListSchemaVerifier.cpp:79, Core/OXPVerifier/OOPListSchemaVerifier.cpp:98 | Push debug-dump indent. (no-op when disabled). | No — logging helper gated by PLIST_VERIFIER_DEBUG_DUMP_ENABLED; could be inline function. |
| DebugDumpPopIndent | Core/OXPVerifier/OOPListSchemaVerifier.cpp:83, Core/OXPVerifier/OOPListSchemaVerifier.cpp:101 | Pop saved debug-dump indent. (no-op when disabled). | No — logging helper gated by PLIST_VERIFIER_DEBUG_DUMP_ENABLED; could be inline function. |
| DebugDump | Core/OXPVerifier/OOPListSchemaVerifier.cpp:87, Core/OXPVerifier/OOPListSchemaVerifier.cpp:104 | Print a formatted schema-verifier debug line. | No — logging helper gated by PLIST_VERIFIER_DEBUG_DUMP_ENABLED; could be inline function. |
| VERIFY_PROTO | Core/OXPVerifier/OOPListSchemaVerifier.cpp:272 | Declare a schema type verifier prototype. | No — code-generation helper. |
| VERIFY_CASE | Core/OXPVerifier/OOPListSchemaVerifier.cpp:482 | Switch case dispatching to schema type verifier. | No — code-generation helper. |
| REQUIRE_PLIST_TYPE | Core/OXPVerifier/OOPListSchemaVerifier.cpp:915 | Check plist value type or report error. | No — function-like helper; could be inline function. |
| OOJS_COUNT | Core/Scripting/OOJSEngineCore.h:102 | Element count of a C array. | No — could be std::size(). |
| OOJSFreeValue | Core/Scripting/OOJSEngineCore.h:118 | Free a JS value. | No — alias for JS_FreeValue; could be inline function. |
| OOJSUndefinedValue | Core/Scripting/OOJSEngineCore.h:119 | Return JS undefined value. | No — alias for JS_UNDEFINED; could be inline function. |
| OOJSNullValue | Core/Scripting/OOJSEngineCore.h:120 | Return JS null value (unused). | No — alias for JS_NULL; could be inline function. |
| OOJSSTR | Core/Scripting/OOJSEngineCore.h:279 | JS string from a literal via atom. | No — JS binding helper; could be inline function. |
| kOOJSLongTimeLimit | Core/Scripting/OOJSEngineCore.h:480 | Long script time limit, seconds. | No — tuning constant; could be constexpr. |
| OOJSStartTimeLimiter | Core/Scripting/OOJSEngineCore.h:482 | Start script time limiter with default limit. | No — function-like helper; could be inline function. |
| OOJSDumpStack | Core/Scripting/OOJSEngineCore.h:553 | Dump JS stack to log with call site. | No — debug helper; could be inline function. |
| OOJS_NATIVE_ARGS | Core/Scripting/OOJSEngineCore.h:597 | Standard JS native-function parameter list. | No — JS binding boilerplate. |
| OOJS_GETTER_ARGS | Core/Scripting/OOJSEngineCore.h:599 | Standard JS property getter parameter list. | No — JS binding boilerplate. |
| OOJS_SETTER_ARGS | Core/Scripting/OOJSEngineCore.h:600 | Standard JS property setter parameter list. | No — JS binding boilerplate. |
| OOJS_THIS | Core/Scripting/OOJSEngineCore.h:602 | Name of native-callback this-value. | No — JS binding boilerplate. |
| OOJS_ARGV | Core/Scripting/OOJSEngineCore.h:603 | Name of native-callback argument vector. | No — JS binding boilerplate. |
| OOJS_IS_CONSTRUCTING | Core/Scripting/OOJSEngineCore.h:610 | True when native is called as constructor. | No — JS binding boilerplate. |
| OOJS_RETURN | Core/Scripting/OOJSEngineCore.h:612 | Return a JS value from native callback. | No — JS binding boilerplate. |
| OOJS_RETURN_VOID | Core/Scripting/OOJSEngineCore.h:616 | Return a undefined from a JS native. | No — JS binding boilerplate. |
| OOJS_RETURN_NULL | Core/Scripting/OOJSEngineCore.h:617 | Return a null from a JS native. | No — JS binding boilerplate. |
| OOJS_RETURN_BOOL | Core/Scripting/OOJSEngineCore.h:618 | Return a bool from a JS native. | No — JS binding boilerplate. |
| OOJS_RETURN_INT | Core/Scripting/OOJSEngineCore.h:619 | Return a int from a JS native. | No — JS binding boilerplate. |
| OOJS_RETURN_DOUBLE | Core/Scripting/OOJSEngineCore.h:620 | Return a double from a JS native. | No — JS binding boilerplate. |
| OOJS_RETURN_PLIST | Core/Scripting/OOJSEngineCore.h:631 | Return a plist from a JS native. | No — JS binding boilerplate. |
| OOJS_RETURN_STRING_OR_NULL | Core/Scripting/OOJSEngineCore.h:633 | Return a string or null from a JS native. | No — JS binding boilerplate. |
| OOJS_RETURN_WITH_HELPER | Core/Scripting/OOJSEngineCore.h:641 | Return a JS value built by a helper. | No — JS binding boilerplate. |
| OOJS_RETURN_VECTOR | Core/Scripting/OOJSEngineCore.h:649 | Return a Vector from a JS native. | No — JS binding boilerplate. |
| OOJS_RETURN_HPVECTOR | Core/Scripting/OOJSEngineCore.h:651 | Return a HPVector from a JS native. | No — JS binding boilerplate. |
| OOJS_RETURN_QUATERNION | Core/Scripting/OOJSEngineCore.h:653 | Return a Quaternion from a JS native. | No — JS binding boilerplate. |
| OOJS_PROP_READWRITE_CB | Core/Scripting/OOJSEngineCore.h:661 | JS property flags: visible read-write callback. | No — constant flags; could be constexpr. |
| OOJS_PROP_READONLY_CB | Core/Scripting/OOJSEngineCore.h:662 | JS property flags: visible read-only callback. | No — constant flags; could be constexpr. |
| OOJS_PROP_HIDDEN_READWRITE_CB | Core/Scripting/OOJSEngineCore.h:663 | JS property flags: hidden read-write callback. | No — constant flags; could be constexpr. |
| OOJS_PROP_HIDDEN_READONLY_CB | Core/Scripting/OOJSEngineCore.h:664 | JS property flags: hidden read-only callback. | No — constant flags; could be constexpr. |
| OOJS_PROP_READWRITE | Core/Scripting/OOJSEngineCore.h:667 | JS property flags: visible read-write (unused). | No — constant flags; could be constexpr. |
| OOJS_PROP_READONLY | Core/Scripting/OOJSEngineCore.h:668 | JS property flags: visible read-only. | No — constant flags; could be constexpr. |
| OOJS_PROP_HIDDEN_READWRITE | Core/Scripting/OOJSEngineCore.h:669 | JS property flags: hidden read-write (unused). | No — constant flags; could be constexpr. |
| OOJS_PROP_HIDDEN_READONLY | Core/Scripting/OOJSEngineCore.h:670 | JS property flags: hidden read-only. | No — constant flags; could be constexpr. |
| OOJS_METHOD_READONLY | Core/Scripting/OOJSEngineCore.h:671 | Property flags for read-only hidden methods. | No — constant flags; could be constexpr. |
| OOJS_PROPERTY_RW | Core/Scripting/OOJSEngineCore.h:685 | Declare read-write JS property entry. | No — JS binding boilerplate. |
| OOJS_PROPERTY_RO | Core/Scripting/OOJSEngineCore.h:688 | Declare read-only JS property entry. | No — JS binding boilerplate. |
| OOLITE_DEBUG | Core/Scripting/OOJSEngineNativeWrappers.h:59, Core/Scripting/OOJSEngineNativeWrappers.h:61 | Nonzero in debug builds. | Already — derived from NDEBUG, set by meson buildtype. |
| OOJS_PROFILE | Core/Scripting/OOJSEngineNativeWrappers.h:71 | Whether native-function profiling is compiled in. | Already — derived from OOLITE_DEBUG (NDEBUG via meson buildtype). |
| OOJS_PROFILE_ENTER_NAMED | Core/Scripting/OOJSEngineNativeWrappers.h:129, Core/Scripting/OOJSEngineNativeWrappers.h:152 | Start named profiling scope. | Yes — profiling hook, compiled out unless OOJS_PROFILE. |
| OOJS_PROFILE_EXIT | Core/Scripting/OOJSEngineNativeWrappers.h:133, Core/Scripting/OOJSEngineNativeWrappers.h:153 | End profiling scope. | Yes — profiling hook, compiled out unless OOJS_PROFILE. |
| OOJS_NATIVE_ENTER | Core/Scripting/OOJSEngineNativeWrappers.h:137, Core/Scripting/OOJSEngineNativeWrappers.h:155 | Start of native function wrapper. | No — JS binding boilerplate. |
| OOJS_NATIVE_EXIT | Core/Scripting/OOJSEngineNativeWrappers.h:142, Core/Scripting/OOJSEngineNativeWrappers.h:159 | End of native function wrapper with exception handling. | No — JS binding boilerplate. |
| OOJS_PROFILE_ENTER | Core/Scripting/OOJSEngineNativeWrappers.h:178 | Start profiling a native function by name. | Yes — profiling hook, compiled out unless OOJS_PROFILE. |
| OOJS_PROFILE_EXIT_VOID | Core/Scripting/OOJSEngineNativeWrappers.h:179 | End profiling scope in void function. | Yes — profiling hook, compiled out unless OOJS_PROFILE. |
| OOJS_BEGIN_FULL_NATIVE | Core/Scripting/OOJSEngineNativeWrappers.h:181 | Begin native block with full engine access. | No — JS binding boilerplate. |
| OOJS_END_FULL_NATIVE | Core/Scripting/OOJSEngineNativeWrappers.h:185 | End native block with full engine access. | No — JS binding boilerplate. |
| GET_THIS_EXHAUSTPLUME | Core/Scripting/OOJSExhaustPlume.cpp:181 | JS binding: fetch the native exhaust plume from this-object. | No — JS binding boilerplate; could be template helper. |
| GET_THIS_FLASHER | Core/Scripting/OOJSFlasher.cpp:271 | JS binding: fetch the native flasher from this-object. | No — JS binding boilerplate; could be template helper. |
| DEBUG_FCB_SIMPLE_TRACKING_IDS | Core/Scripting/OOJSFrameCallbacks.cpp:47 | Use simple sequential frame-callback tracking IDs. | Yes — debug toggle compiled via #if (default 0). |
| DEBUG_FCB_VERBOSE_LOGGING | Core/Scripting/OOJSFrameCallbacks.cpp:51 | Enable verbose frame-callback logging. | Yes — debug logging toggle compiled via #if (default 0). |
| FCBLog | Core/Scripting/OOJSFrameCallbacks.cpp:59, Core/Scripting/OOJSFrameCallbacks.cpp:63 | Frame-callback logging; OO_LOG or no-op. | No — logging helper; verbosity gated by DEBUG_FCB_VERBOSE_LOGGING. |
| FCBLogIndentIf | Core/Scripting/OOJSFrameCallbacks.cpp:60, Core/Scripting/OOJSFrameCallbacks.cpp:66 | Conditional log indent for frame callbacks. | No — logging helper; could be inline function. |
| FCBLogOutdentIf | Core/Scripting/OOJSFrameCallbacks.cpp:61, Core/Scripting/OOJSFrameCallbacks.cpp:69 | Conditional log outdent for frame callbacks. | No — logging helper; could be inline function. |
| OOJSID | Core/Scripting/OOJSPropID.h:43 | Interned JS property atom from a string literal. | No — JS binding helper; could be inline function. |
| OO_CACHE_JS_SCRIPTS | Core/Scripting/OOJSScript.cpp:26 | Cache compiled JS scripts. | Yes — #ifndef-defaulted compile-time toggle (default 1). |
| GET_THIS_SHIP | Core/Scripting/OOJSShip.cpp:2142 | JS binding: fetch the native ship from this-object. | No — JS binding boilerplate; could be template helper. |
| GET_THIS_STATION | Core/Scripting/OOJSStation.cpp:255 | JS binding: fetch the native station from this-object. | No — JS binding boilerplate; could be template helper. |
| OOJS_EXOTIC_ENTER | Core/Scripting/OOJSSystemInfo.cpp:526 | Open try block in exotic-method wrapper. | No — JS binding boilerplate. |
| OOJS_EXOTIC_EXIT | Core/Scripting/OOJSSystemInfo.cpp:527 | Close try block, convert exception to JS error. | No — JS binding boilerplate. |
| kMinInterval | Core/Scripting/OOJSTimer.cpp:55 | Minimum JS timer interval, seconds. | No — tuning constant; could be constexpr. |
| GET_THIS_EFFECT | Core/Scripting/OOJSVisualEffect.cpp:577 | JS binding: fetch the native visual effect from this-object. | No — JS binding boilerplate; could be template helper. |
| OOJS_RUNTIME_SIZE_MiB | Core/Scripting/OOJavaScriptEngine.cpp:93, Core/Scripting/poc/OOJavaScriptEnginePoc.cpp:42 | JS runtime memory limit in MiB. | No — tuning constant; could be constexpr. |
| OOJS_STACK_SIZE | Core/Scripting/OOJavaScriptEngine.cpp:94 | JS runtime stack limit in bytes. | No — tuning constant; could be constexpr. |
| OOJS_TIME_LIMIT | Core/Scripting/OOJavaScriptEngine.cpp:97, Core/Scripting/OOJavaScriptEngine.cpp:99 | Default script time limit in seconds. | Already — value switches on OO_DEBUG (debug vs release build). |
| OOJSENGINE_MONITOR_SUPPORT | Core/Scripting/OOJavaScriptEngine.h:67 | Whether JS engine supports debug monitor. | Already — alias of OO_DEBUG_MONITOR_ENABLED set by meson. |
| INCLUDE_RAW_STRING | Core/Scripting/OOLegacyScriptWhitelist.cpp:43 | Whether raw condition strings are kept (debug builds). | Already — follows OOLITE_DEBUG, which follows NDEBUG from meson buildtype. |
| DEMO2_VANISHING_DISTANCE | Core/Universe.cpp:120 | Distance at which demo ship vanishes. | No — tuning constant; could be constexpr. |
| DEMO2_FLY_IN_STAGE_TIME | Core/Universe.cpp:121 | Duration of demo fly-in stage, seconds. | No — tuning constant; could be constexpr. |
| MAX_NUMBER_OF_ENTITIES | Core/Universe.cpp:123 | Initial entity list capacity. | No — tuning constant; could be constexpr. |
| STANDARD_STATION_ROLL | Core/Universe.cpp:124 | Default station roll rate. | No — tuning constant; could be constexpr. |
| LANE_WIDTH | Core/Universe.cpp:126 | Width of the witchpoint-to-planet lane. | No — tuning constant; could be constexpr. |
| DOCKED_AMBIENT_LEVEL | Core/Universe.cpp:524 | Ambient light level while docked. | No — tuning constant; could be constexpr. |
| DOCKED_ILLUM_LEVEL | Core/Universe.cpp:525 | Illumination level while docked. | No — tuning constant; could be constexpr. |
| SUN_AMBIENT_INFLUENCE | Core/Universe.cpp:538 | Sun colour influence on ambient light. | No — tuning constant; could be constexpr. |
| SKY_AMBIENT_ADJUSTMENT | Core/Universe.cpp:540 | Ambient light adjustment from sky colour. | No — tuning constant; could be constexpr. |
| PROFILE_SHIP_SELECTION | Core/Universe.cpp:626 | Profile ship selection timing. | Yes — compile-time debug toggle (default 0). |
| SPROP | Core/Universe.cpp:1797 | Log a string planetinfo property. | No — local logging helper; could be lambda. |
| IPROP | Core/Universe.cpp:1800 | Log an int planetinfo property. | No — local logging helper; could be lambda. |
| FPROP | Core/Universe.cpp:1802 | Log a float planetinfo property. | No — local logging helper; could be lambda. |
| OO_SCANCLASS_TYPE | Core/Universe.h:97 | Empty hook for scan-class declaration qualifier. | No — empty placeholder; can be deleted. |
| CROSSHAIR_SIZE | Core/Universe.h:100 | Crosshair size in pixels. | No — tuning constant; could be constexpr. |
| SHADERS_MIN | Core/Universe.h:134 | Lowest shader setting (unused). | No — constant; could be constexpr. |
| MAX_MESSAGES | Core/Universe.h:136 | Max queued on-screen messages (unused). | No — tuning constant; could be constexpr. |
| PROXIMITY_WARN_DISTANCE | Core/Universe.h:138 | Distance factor for proximity warning. | No — tuning constant; could be constexpr. |
| PROXIMITY_WARN_DISTANCE2 | Core/Universe.h:139 | Squared PROXIMITY_WARN_DISTANCE. | No — derived constant; could be constexpr. |
| PROXIMITY_AVOID_DISTANCE_FACTOR | Core/Universe.h:141 | Factor for ship collision-avoidance distance. | No — tuning constant; could be constexpr. |
| SAFE_ADDITION_FACTOR2 | Core/Universe.h:142 | Squared safety factor for adding ships. | No — tuning constant; could be constexpr. |
| SUN_SKIM_RADIUS_FACTOR | Core/Universe.h:145 | Radius factor for sun-skimming range. | No — tuning constant; could be constexpr. |
| SUN_SPARKS_RADIUS_FACTOR | Core/Universe.h:147 | Radius factor for sun spark effects (unused). | No — tuning constant; could be constexpr. |
| KEY_EQUIPMENT_PORT_WEAPON | Core/Universe.h:176 | Dictionary key for port weapon type (unused). | No — key string; could be constexpr string_view. |
| KEY_EQUIPMENT_STARBOARD_WEAPON | Core/Universe.h:177 | Dictionary key for starboard weapon type (unused). | No — key string; could be constexpr string_view. |
| PASSENGER_BERTH_SPACE | Core/Universe.h:189 | Cargo space used per passenger berth. | No — tuning constant; could be constexpr. |
| OOLITE_EXCEPTION_LOOPING | Core/Universe.h:195 | Exception name for looping (unused). | No — name string; could be constexpr string_view. |
| OOLITE_EXCEPTION_DATA_NOT_FOUND | Core/Universe.h:196 | Exception name for missing data. | No — name string; could be constexpr string_view. |
| OOLITE_EXCEPTION_FATAL | Core/Universe.h:197 | Exception name for fatal errors. | No — name string; could be constexpr string_view. |
| BILLBOARD_DEPTH | Core/Universe.h:201 | Depth at which billboard sprites are drawn. | No — tuning constant; could be constexpr. |
| TIME_ACCELERATION_FACTOR_MIN | Core/Universe.h:203 | Min time acceleration. | No — tuning constant; could be constexpr. |
| TIME_ACCELERATION_FACTOR_DEFAULT | Core/Universe.h:204 | Default time acceleration. | No — tuning constant; could be constexpr. |
| TIME_ACCELERATION_FACTOR_MAX | Core/Universe.h:205 | Max time acceleration. | No — tuning constant; could be constexpr. |
| DEMO_LIGHT_POSITION | Core/Universe.h:207 | Light position used in docked/demo scenes. | No — tuning constant; could be constexpr array. |
| MIN_DISTANCE_TO_BUOY | Core/Universe.h:209 | Minimum distance to buoy when adding ships. | No — tuning constant; could be constexpr. |
| MIN_DISTANCE_TO_BUOY2 | Core/Universe.h:210 | Squared MIN_DISTANCE_TO_BUOY (unused). | No — derived constant; could be constexpr. |
| SYSTEM_REPOPULATION_INTERVAL | Core/Universe.h:214 | Seconds between system repopulation passes. | No — tuning constant; could be constexpr. |
| OO_LOCALIZATION_TOOLS | Core/Universe.h:217 | Include localization tooling code. | Already — set via meson (-DOO_LOCALIZATION_TOOLS=0/1). |
| MASS_DEPENDENT_FUEL_PRICES | Core/Universe.h:221 | Make fuel price depend on ship mass. | Yes — #ifndef-defaulted compile-time toggle (default 1). |
| UNIVERSE | Core/Universe.h:1017 | Shorthand for the global Universe instance. | No — accessor shorthand; could be inline function. |
| OO_DESC | Core/Universe.h:1022 | Look up a description string by key. | No — function-like helper; could be inline function. |
| OO_DESC_PLURAL | Core/Universe.h:1023 | Look up pluralised description by key and count. | No — function-like helper; could be inline function. |
| OO_UNIVERSE_VIRTUAL_MEMBERS | Core/UniverseVirtualMembers.h:65 | X-macro list of Universe virtual members. | No — code-generation X-macro. |

## Graphics, materials, textures, OpenGL, SDL

| Macro | Where | Purpose | Feature flag? |
|---|---|---|---|
| `FACE` | `Core/Materials/OOBasicMaterial.cpp:43` | Material face selector, front and back. | No — constant; could be constexpr. |
| `DUMP_COMBINER` | `Core/Materials/OOCombinedEmissionMapGenerator.cpp:40` | Enables emission-map combiner dumps. | Yes — hard-coded debug aid; could be meson option. |
| `DUMP` | `Core/Materials/OOCombinedEmissionMapGenerator.cpp:334`, `Core/Materials/OOCombinedEmissionMapGenerator.cpp:338` | Dumps pixmap with label for combiner debugging. | Yes — debug aid; gated by DUMP_COMBINER. |
| `RGBA_IMAGE_TYPE` | `Core/Materials/OOConcreteTexture.cpp:62`, `Core/Materials/OOConcreteTexture.cpp:64` | GL pixel type for RGBA by endianness. | No — platform shim; could be constexpr. |
| `OOTEXTURE_RELOADABLE` | `Core/Materials/OOConcreteTexture.h:55` | Textures keep source data for reloading. | Yes — hard-coded compile-time toggle; could be meson option. |
| `REQUIRE_STAGE` | `Core/Materials/OODefaultShaderSynthesizer.cpp:70`, `Core/Materials/OODefaultShaderSynthesizer.cpp:76` | Requires a shader synthesizer stage. | No — code-generation helper; could be inline function. |
| `USE_NEW_SHADER_SYNTHESIZER` | `Core/Materials/OOMaterialConvenienceCreators.cpp:29` | Selects new default shader synthesizer. | Yes — hard-coded 0 experimental toggle; could be meson option. |
| `kOOMaterialDefaultParallaxScale` | `Core/Materials/OOMaterialSpecifier.h:120` | Default parallax scale. | No — constant; could be constexpr. |
| `MSG_TERMINATOR` | `Core/Materials/OOPNGTextureLoader.cpp:178`, `Core/Materials/OOPNGTextureLoader.cpp:180` | PNG error message terminator, by build. | No — build-dependent string; could be constexpr. |
| `OORoundUpToPowerOf2_PixMap` | `Core/Materials/OOPixMap.h:55` | Alias to 32-bit power-of-2 round-up. | No — alias; could be using or inline function. |
| `OODumpPixMap` | `Core/Materials/OOPixMap.h:159` | Dumps a pixmap to file, or no-op. | Already — gated by NDEBUG (meson oo_exclude_debug_support). |
| `OO_PLAIN_CPP_UNIT` | `Core/Materials/OOPixMapChannelOperations.cpp:28`, `Core/OOConvertCubeMapToLatLong.cpp:30` | Marks unit as plain C++, not game unit. | No — include-control marker; per-file. |
| `DEBUG_DUMP` | `Core/Materials/OOPlanetTextureGenerator.cpp:27`, `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:28` | Enables planet texture debug dumps. | Yes — hard-coded debug aid; could be meson option. |
| `DEBUG_DUMP_RAW` | `Core/Materials/OOPlanetTextureGenerator.cpp:28`, `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:29` | Also dump raw planet texture data. | Yes — hard-coded debug aid; gated by DEBUG_DUMP. |
| `POLAR_CAPS` | `Core/Materials/OOPlanetTextureGenerator.cpp:30` | Enables polar ice caps in planet textures. | Yes — hard-coded compile-time toggle; could be constexpr. |
| `ALBEDO_FACTOR` | `Core/Materials/OOPlanetTextureGenerator.cpp:31`, `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:31` | Overall darkening factor for planet textures. | No — tuning constant; could be constexpr. |
| `PLANET_TEXTURE_OPTIONS` | `Core/Materials/OOPlanetTextureGenerator.cpp:62`, `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:60` | Planet texture generator options list. | No — X-macro list; could be enum or table. |
| `FAIL_IF` | `Core/Materials/OOPlanetTextureGenerator.cpp:414`, `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:231` | Aborts texture generation when condition holds. | No — control-flow helper; could be inline check. |
| `AIR_ALPHA` | `Core/Materials/OOPlanetTextureGenerator.cpp:638`, `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:342` | Planet texture generator tuning constant. | No — tuning constant; could be constexpr. |
| `CLOUD_ALPHA` | `Core/Materials/OOPlanetTextureGenerator.cpp:639`, `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:343` | Planet texture generator tuning constant. | No — tuning constant; could be constexpr. |
| `POLAR_BOUNDARY` | `Core/Materials/OOPlanetTextureGenerator.cpp:641`, `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:345` | Planet texture generator tuning constant. | No — tuning constant; could be constexpr. |
| `CLOUD_BOUNDARY` | `Core/Materials/OOPlanetTextureGenerator.cpp:642`, `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:346` | Planet texture generator tuning constant. | No — tuning constant; could be constexpr. |
| `RECIP_CLOUD_BOUNDARY` | `Core/Materials/OOPlanetTextureGenerator.cpp:643`, `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:347` | Reciprocal of cloud boundary. | No — tuning constant; could be constexpr. |
| `RECIP_COASTLINE_PORTION` | `Core/Materials/OOPlanetTextureGenerator.cpp:687` | Reciprocal of coastline portion. | No — tuning constant; could be constexpr. |
| `COASTLINE_PORTION` | `Core/Materials/OOPlanetTextureGenerator.cpp:688` | Coastline width fraction of height range. | No — tuning constant; could be constexpr. |
| `SHALLOWS` | `Core/Materials/OOPlanetTextureGenerator.cpp:689` | Planet sea depth tuning constant. | No — tuning constant; could be constexpr. |
| `RECIP_SHALLOWS` | `Core/Materials/OOPlanetTextureGenerator.cpp:690` | Planet sea depth tuning constant. | No — tuning constant; could be constexpr. |
| `DEEPS` | `Core/Materials/OOPlanetTextureGenerator.cpp:692` | Planet sea depth tuning constant. | No — tuning constant; could be constexpr. |
| `RECIP_DEEPS` | `Core/Materials/OOPlanetTextureGenerator.cpp:693` | Planet sea depth tuning constant. | No — tuning constant; could be constexpr. |
| `iman_` | `Core/Materials/OOPlanetTextureGenerator.cpp:778`, `Core/Materials/OOPlanetTextureGenerator.cpp:780` | Byte index for endianness in noise code. | No — platform shim; could be constexpr. |
| `LUT_DOT` | `Core/Materials/OOPlanetTextureGenerator.cpp:818`, `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:452` | Use lookup table for gradient dot products. | Yes — hard-coded compile-time algorithm toggle. |
| `PERM` | `Core/Materials/OOPlanetTextureGenerator.cpp:864`, `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:499` | Permutation table lookup for noise. | No — function-like helper; could be inline function. |
| `DOT3` | `Core/Materials/OOPlanetTextureGenerator.cpp:887`, `Core/Materials/OOPlanetTextureGenerator.cpp:890` | Gradient dot product via lookup table or direct. | No — code-generation helper; could be inline function. |
| `OO_ENGINE_LEVEL` | `Core/Materials/OOShaderMaterial.h:87` | Example shader macro in a doc comment (unused). | No — documentation only; no real definition. |
| `GET_TEMPLATE` | `Core/Materials/OOShaderUniformMethodType.cpp:88` | Generates uniform getter template specialization. | No — code-generation helper; could be template. |
| `SET_TRACE_CONTEXT` | `Core/Materials/OOTexture.cpp:119` | Sets texture trace context; always a no-op. | No — dead no-op shim; remove. |
| `CLEAR_TRACE_CONTEXT` | `Core/Materials/OOTexture.cpp:122` | Clears texture trace context; always a no-op. | No — dead no-op shim; remove. |
| `kOOTextureDefaultAnisotropy` | `Core/Materials/OOTexture.h:65` | Default texture anisotropy. | No — constant; could be constexpr. |
| `kOOTextureDefaultLODBias` | `Core/Materials/OOTexture.h:66` | Default texture LOD bias. | No — constant; could be constexpr. |
| `GL_CLAMP_TO_EDGE` | `Core/Materials/OOTextureInternal.h:65`, `Core/Materials/OOTextureInternal.h:68` | Fallback alias for clamp-to-edge enum. | No — GL extension shim. |
| `OO_GL_CLIENT_STORAGE` | `Core/Materials/OOTextureInternal.h:73`, `Core/Materials/OOTextureInternal.h:77` | Apple client-storage availability flag. | No — platform shim; Apple only. |
| `EnableClientStorage` | `Core/Materials/OOTextureInternal.h:74`, `Core/Materials/OOTextureInternal.h:78` | Enables Apple client-storage unpack (only used in a comment). | No — Apple platform shim; effectively dead code. |
| `GL_TEXTURE_MAX_LEVEL` | `Core/Materials/OOTextureInternal.h:85`, `Core/Materials/OOTextureInternal.h:87` | Fallback alias for max mipmap level enum. | No — GL extension shim. |
| `GL_TEXTURE_CUBE_MAP` | `Core/Materials/OOTextureInternal.h:93` | Fallback alias to ARB cube map enum. | No — GL extension shim. |
| `GL_TEXTURE_CUBE_MAP_POSITIVE_X` | `Core/Materials/OOTextureInternal.h:94` | Fallback alias to ARB cube map face enum. | No — GL extension shim. |
| `DUMP_CONVERTED_CUBE_MAPS` | `Core/Materials/OOTextureLoader.cpp:56` | Enables dumping converted cube maps. | Yes — hard-coded debug aid; could be meson option. |
| `kPiF` | `Core/OOConvertCubeMapToLatLong.cpp:37` | Float pi constant. | No — constant; use std::numbers::pi_v<float>. |
| `OODEBUGLDRAWING_DISABLE` | `Core/OODebugGLDrawing.h:39`, `Core/Octree.h:41` | Disables debug GL drawing helpers. | Already — derived from OO_DEBUG_MONITOR_ENABLED (meson oo_debug_monitor_enabled). |
| `OODRAW_NOOP` | `Core/OODebugGLDrawing.h:134` | Empty statement for disabled debug draws. | No — helper; could be inline no-op function. |
| `OODebugDrawBoundingBox` | `Core/OODebugGLDrawing.h:138` | Disabled-build no-op for debug draw call. | Already — gated by OODEBUGLDRAWING_DISABLE, from OO_DEBUG_MONITOR_ENABLED. |
| `OODebugDrawBoundingBoxBetween` | `Core/OODebugGLDrawing.h:139` | Disabled-build no-op for debug draw call. | Already — gated by OODEBUGLDRAWING_DISABLE, from OO_DEBUG_MONITOR_ENABLED. |
| `OODebugDrawNormal` | `Core/OODebugGLDrawing.h:140` | Disabled-build no-op for debug draw call. | Already — gated by OODEBUGLDRAWING_DISABLE, from OO_DEBUG_MONITOR_ENABLED. |
| `OODebugDrawNormalAtOrigin` | `Core/OODebugGLDrawing.h:141` | Disabled-build no-op for debug draw call. | Already — gated by OODEBUGLDRAWING_DISABLE, from OO_DEBUG_MONITOR_ENABLED. |
| `OODebugDrawVector` | `Core/OODebugGLDrawing.h:142` | Disabled-build no-op for debug draw call. | Already — gated by OODEBUGLDRAWING_DISABLE, from OO_DEBUG_MONITOR_ENABLED. |
| `OODebugDrawColoredVector` | `Core/OODebugGLDrawing.h:143` | Disabled-build no-op for debug draw call. | Already — gated by OODEBUGLDRAWING_DISABLE, from OO_DEBUG_MONITOR_ENABLED. |
| `OODebugDrawVectorAtOrigin` | `Core/OODebugGLDrawing.h:144` | Disabled-build no-op for debug draw call. | Already — gated by OODEBUGLDRAWING_DISABLE, from OO_DEBUG_MONITOR_ENABLED. |
| `OODebugDrawColoredVectorAtOrigin` | `Core/OODebugGLDrawing.h:145` | Disabled-build no-op for debug draw call. | Already — gated by OODEBUGLDRAWING_DISABLE, from OO_DEBUG_MONITOR_ENABLED. |
| `OODebugDrawBasis` | `Core/OODebugGLDrawing.h:146` | Disabled-build no-op for debug draw call. | Already — gated by OODEBUGLDRAWING_DISABLE, from OO_DEBUG_MONITOR_ENABLED. |
| `OODebugDrawBasisAtOrigin` | `Core/OODebugGLDrawing.h:147` | Disabled-build no-op for debug draw call. | Already — gated by OODEBUGLDRAWING_DISABLE, from OO_DEBUG_MONITOR_ENABLED. |
| `DISPLAY_MIN_COLOURS` | `Core/OOFullScreenController.h:47` | Min supported colour depth (unused). | No — limit constant; could be constexpr. |
| `DISPLAY_MIN_WIDTH` | `Core/OOFullScreenController.h:48` | Min supported display width. | No — limit constant; could be constexpr. |
| `DISPLAY_MIN_HEIGHT` | `Core/OOFullScreenController.h:49` | Min supported display height. | No — limit constant; could be constexpr. |
| `DISPLAY_MAX_WIDTH` | `Core/OOFullScreenController.h:50` | Max supported display width. | No — limit constant; could be constexpr. |
| `DISPLAY_MAX_HEIGHT` | `Core/OOFullScreenController.h:51` | Max supported display height. | No — limit constant; could be constexpr. |
| `OO_ENTER_OPENGL` | `Core/OOMacroOpenGL.h:34` | Empty leftover GL-context entry marker. | No — dead no-op; remove. |
| `ADAPTIVE_OCTREE_DEPTH` | `Core/OOMesh.cpp:64` | Scales collision octree depth by mesh size. | Yes — compile-time toggle; could be a constexpr bool. |
| `SCRIBBLE` | `Core/OOMesh.cpp:67` | Scribble cache memory with FEEDFACE. | Yes — hard-coded debug aid; compile-time 0. |
| `PROFILE` | `Core/OOMesh.cpp:84`, `Core/OOMesh.cpp:97` | Records mesh load profile tag, or no-op. | Yes — gated by OOMESH_PROFILE. |
| `Scribble` | `Core/OOMesh.cpp:1422` | Fills memory with debug pattern, or no-op. | Yes — debug aid; gated by SCRIBBLE. |
| `OOMESH_PROFILE` | `Core/OOMesh.h:72` | Enables mesh load profiling. | Yes — hard-coded profiling aid; could be meson option. |
| `DECL_GEOMETRY` | `Core/OOMeshToOctreeConverter.cpp:346` | Declares a static geometry buffer with capacity. | No — code-generation helper; could be template. |
| `COLOR_EQUAL` | `Core/OOOpenGL.cpp:280` | Compares colour components to RGBA. | No — local helper; could be lambda. |
| `COLOR_CASE` | `Core/OOOpenGL.cpp:283` | Returns name string if colour matches RGBA. | No — local helper; could be lambda. |
| `DUMP_STATE_FLAG` | `Core/OOOpenGL.cpp:451` | Logs a glIsEnabled state flag. | No — local logging helper; could be lambda. |
| `DUMP_GET_FLAG` | `Core/OOOpenGL.cpp:453` | Logs a glGetBooleanv state flag. | No — local logging helper; could be lambda. |
| `CASE` | `Core/OOOpenGL.cpp:476` | Switch-case returning stringified GL enum name. | No — code-generation helper; could be a table or template. |
| `TEXCASE` | `Core/OOOpenGL.cpp:522`, `Core/OOOpenGL.cpp:524` | Case for GL texture unit enum names. | No — code-generation helper; could be table. |
| `NULL_SHADER` | `Core/OOOpenGL.h:71` | Null shader handle value. | No — constant; could be constexpr. |
| `OOSetOpenGLState` | `Core/OOOpenGL.h:160` | Sets GL state with caller location. | Already — gated by OO_GL_STATE_VERIFICATION (NDEBUG); could be inline function. |
| `OOVerifyOpenGLState` | `Core/OOOpenGL.h:161`, `Core/OOOpenGL.h:164` | Verifies GL state, or no-op. | Already — gated by OO_GL_STATE_VERIFICATION (NDEBUG). |
| `OO_GL_STATE_VERIFICATION` | `Core/OOOpenGLCheck.h:38`, `Core/OOOpenGLCheck.h:40` | Enables GL state verifier. | Already — driven by NDEBUG (meson oo_exclude_debug_support); planned to follow OO_CHECK_GL_HEAVY. |
| `OO_CHECK_GL_HEAVY` | `Core/OOOpenGLCheck.h:94` | Heavy GL error checking switch. | Already — meson oo_check_gl_heavy and debug builds. |
| `OOGLNoteCurrentFunction` | `Core/OOOpenGLCheck.h:102` | Records current function for GL state checks. | Already — meson OO_CHECK_GL_HEAVY with state verification. |
| `OOGL_PERFORM_CHECK` | `Core/OOOpenGLCheck.h:108` | Runs GL error check with location info. | Already — meson OO_CHECK_GL_HEAVY. |
| `OOGL` | `Core/OOOpenGLCheck.h:112`, `Core/OOOpenGLCheck.h:135` | Wraps a GL call with error check. | Already — meson OO_CHECK_GL_HEAVY. |
| `CheckOpenGLErrorsHeavy` | `Core/OOOpenGLCheck.h:119`, `Core/OOOpenGLCheck.h:139` | Logs GL errors, or compiled out. | Already — meson OO_CHECK_GL_HEAVY (oo_check_gl_heavy option, debug builds). |
| `OOGLBEGIN` | `Core/OOOpenGLCheck.h:120`, `Core/OOOpenGLCheck.h:142` | glBegin wrapper with error check. | Already — meson OO_CHECK_GL_HEAVY. |
| `OOGLEND` | `Core/OOOpenGLCheck.h:126`, `Core/OOOpenGLCheck.h:143` | glEnd wrapper with error check. | Already — meson OO_CHECK_GL_HEAVY. |
| `OOLITE_WINDOWS` | `Core/OOOpenGLExtensionPointers.h:42` | Fallback Windows platform flag. | No — platform shim; set by OOFoundation.h. |
| `OO_SHADERS` | `Core/OOOpenGLExtensionPointers.h:49`, `Core/OOOpenGLExtensionPointers.h:51` | Shader support compiled in. | Already — meson no_shaders option (NO_SHADERS). |
| `OO_USE_VBO` | `Core/OOOpenGLExtensionPointers.h:81`, `Core/OOOpenGLExtensionPointers.h:84` | Vertex buffer object support, hard-disabled. | Yes — hard-coded 0 (crashes on some systems); could be meson option. |
| `OO_USE_FBO` | `Core/OOOpenGLExtensionPointers.h:89`, `Core/OOOpenGLExtensionPointers.h:91` | Framebuffer object support compiled in. | Yes — derived from GL_EXT_framebuffer_object; could be runtime check. |
| `OO_MULTITEXTURE` | `Core/OOOpenGLExtensionPointers.h:102`, `Core/OOOpenGLExtensionPointers.h:105` | Multitexture support available. | Yes — derived from GL_ARB_texture_env_combine; could be runtime check. |
| `OO_TEXTURE_CUBE_MAP` | `Core/OOOpenGLExtensionPointers.h:109`, `Core/OOOpenGLExtensionPointers.h:112` | Cube map support available. | Yes — derived from GL_ARB_texture_cube_map; could be runtime check. |
| `glActiveTextureARB` | `Core/OOOpenGLExtensionPointers.h:154` | Alias to loaded ARB function pointer. | No — GL extension shim. |
| `glClientActiveTextureARB` | `Core/OOOpenGLExtensionPointers.h:160` | Alias to loaded ARB function pointer. | No — GL extension shim. |
| `glActiveTexture` | `Core/OOOpenGLExtensionPointers.h:200` | Alias to loaded extension function pointer. | No — GL extension shim. |
| `GL_GLEXT_PROTOTYPES` | `Core/OOOpenGLOnly.h:36` | Requests GL extension prototypes from headers. | No — GL header shim. |
| `__DEFINED_GL_GLEXT_PROTOTYPES` | `Core/OOOpenGLOnly.h:37` | Marks that we defined GL_GLEXT_PROTOTYPES. | No — GL header shim. |
| `glGenVertexArrays` | `Core/OOOpenGLOnly.h:57` | Maps core name to APPLE extension. | No — platform shim; Apple only. |
| `glBindVertexArray` | `Core/OOOpenGLOnly.h:58` | Maps core name to APPLE extension. | No — platform shim; Apple only. |
| `glDeleteVertexArrays` | `Core/OOOpenGLOnly.h:59` | Maps core name to APPLE extension. | No — platform shim; Apple only. |
| `glClampColor` | `Core/OOOpenGLOnly.h:60` | Maps core name to ARB extension. | No — platform shim; Apple only. |
| `OO_MSAA_COLOR_RENDERBUFFER` | `Core/OOOpenGLOnly.h:61`, `Core/OOOpenGLOnly.h:63` | Use MSAA colour renderbuffer on macOS. | No — platform shim; Apple only. |
| `kOOPlanetDataLevels` | `Core/OOPlanetData.h:14` | Number of planet mesh detail levels. | No — constant; could be constexpr. |
| `kOOPlanetDataVertexCount` | `Core/OOPlanetData.h:25` | Planet mesh vertex count. | No — constant; could be constexpr. |
| `LOD_GRANULARITY` | `Core/OOPlanetDrawable.cpp:43` | Planet LOD level count as float. | No — tuning constant; could be constexpr. |
| `LOD_FACTOR` | `Core/OOPlanetDrawable.cpp:44` | Planet level-of-detail scale factor. | No — tuning constant; could be constexpr. |
| `APIENTRY` | `Core/OOPolygonSprite.cpp:57` | Empty fallback for GL calling convention. | No — platform shim; GL headers normally define it. |
| `kCosMitreLimit` | `Core/OOPolygonSprite.cpp:60` | Mitre-join cosine limit, about 30 degrees. | No — tuning constant; could be constexpr. |
| `SVGDumpEnd` | `Core/OOPolygonSprite.cpp:115` | SVG debug dump call, or no-op. | Yes — debug aid compiled out in non-debug builds. |
| `SVGDumpBeginGroup` | `Core/OOPolygonSprite.cpp:118` | SVG debug dump call, or no-op. | Yes — debug aid compiled out in non-debug builds. |
| `SVGDumpEndGroup` | `Core/OOPolygonSprite.cpp:121` | SVG debug dump call, or no-op. | Yes — debug aid compiled out in non-debug builds. |
| `SVGDumpAppendBaseContour` | `Core/OOPolygonSprite.cpp:124` | SVG debug dump call, or no-op. | Yes — debug aid compiled out in non-debug builds. |
| `SVGDumpBeginPrimitive` | `Core/OOPolygonSprite.cpp:127` | SVG debug dump call, or no-op. | Yes — debug aid compiled out in non-debug builds. |
| `SVGDumpEndPrimitive` | `Core/OOPolygonSprite.cpp:130` | SVG debug dump call, or no-op. | Yes — debug aid compiled out in non-debug builds. |
| `SVGDumpAppendTriangle` | `Core/OOPolygonSprite.cpp:133` | SVG debug dump call, or no-op. | Yes — debug aid compiled out in non-debug builds. |
| `SKY_ELEMENT_SCALE_FACTOR` | `Core/OOSkyDrawable.cpp:42` | Scale for sky elements relative to depth. | No — tuning constant; could be constexpr. |
| `NEBULA_SHUFFLE_FACTOR` | `Core/OOSkyDrawable.cpp:43` | Sky nebula position shuffle amount. | No — tuning constant; could be constexpr. |
| `DEBUG_COLORS` | `Core/OOSkyDrawable.cpp:44` | Sky debug: colours from position xyz. | Yes — hard-coded 0 debug aid; could be meson option. |
| `SKYCOLOR_TONEMAP_COMPONENT` | `Core/OOSkyDrawable.cpp:512` | Tone-maps one sky colour component. | No — function-like helper; could be inline function. |
| `DUMP_MIP_MAPS` | `Core/OOTextureScaling.cpp:39` | Enables mipmap debug dumps. | Yes — hard-coded debug aid; could be meson option. |
| `DUMP_SCALE` | `Core/OOTextureScaling.cpp:40` | Enables scaling-stage debug dumps. | Yes — hard-coded debug aid; could be meson option. |
| `DUMP_CHANNELS` | `Core/OOTextureScaling.cpp:233` | Bitmap of channel counts to dump. | Yes — debug aid setting; hard-coded. |
| `DUMP_MIP_MAP_PREPARE` | `Core/OOTextureScaling.cpp:235`, `Core/OOTextureScaling.cpp:246` | Prepares mipmap dump state. | Yes — debug aid; gated by DUMP_MIP_MAPS. |
| `DUMP_MIP_MAP_DUMP` | `Core/OOTextureScaling.cpp:240`, `Core/OOTextureScaling.cpp:250` | Dumps a mipmap level image. | Yes — debug aid; gated by DUMP_MIP_MAPS. |
| `DUMP_SCALE_PREPARE` | `Core/OOTextureScaling.cpp:259`, `Core/OOTextureScaling.cpp:270` | Prepares scaling dump state. | Yes — debug aid; gated by DUMP_SCALE. |
| `DUMP_SCALE_DUMP` | `Core/OOTextureScaling.cpp:261`, `Core/OOTextureScaling.cpp:271` | Dumps pixmap after a scaling stage. | Yes — debug aid; gated by DUMP_SCALE. |
| `ACCUM2` | `Core/OOTextureScaling.cpp:1377` | Accumulates weighted pixel into 2-channel accumulator. | No — code-generation helper; could be inline function. |
| `CLEAR_ACCUM2` | `Core/OOTextureScaling.cpp:1386` | Resets 2-pixel accumulator. | No — code-generation helper; could be inline function. |
| `ACCUM2TOPX` | `Core/OOTextureScaling.cpp:1393` | Converts 2-pixel accumulator to output pixel. | No — code-generation helper; could be inline function. |
| `ACCUM4` | `Core/OOTextureScaling.cpp:1517` | Accumulates weighted pixel into 4-channel accumulator. | No — code-generation helper; could be inline function. |
| `CLEAR_ACCUM4` | `Core/OOTextureScaling.cpp:1530` | Resets 4-pixel accumulator. | No — code-generation helper; could be inline function. |
| `ACCUM4TOPX` | `Core/OOTextureScaling.cpp:1545` | Converts 4-channel accumulator to output pixel. | No — code-generation helper; could be inline function. |
| `OPEN_GL_SPRITE_MIN_WIDTH` | `Core/OOTextureSprite.h:34` | Minimum sprite width (unused). | No — limit constant; could be constexpr. |
| `OPEN_GL_SPRITE_MIN_HEIGHT` | `Core/OOTextureSprite.h:35` | Minimum sprite height (unused). | No — limit constant; could be constexpr. |
| `OctreeDebugLog` | `Core/Octree.cpp:37`, `Core/Octree.cpp:43` | Octree debug logging, or no-op. | Already — gated by OO_DEBUG_MONITOR_ENABLED (meson oo_debug_monitor_enabled). |
| `OCTREE_COLOR` | `Core/Octree.cpp:161`, `Core/Octree.cpp:163` | Sets debug colour when drawing octree. | Yes — hard-coded #if 0 debug aid; currently a no-op. |
| `OCTREE_MIN_HALF_WIDTH` | `Core/Octree.h:38` | Minimum octree node half-width. | No — tuning constant; could be constexpr. |
| `SAVEDIR` | `SDL/MyOpenGLView.cpp:53` | Saved games directory name. | No — constant; could be constexpr. |
| `SNAPSHOTDIR` | `SDL/MyOpenGLView.cpp:54` | Snapshots directory name. | No — constant; could be constexpr. |
| `WINDOW_SIZE_DEFAULT_WIDTH` | `SDL/MyOpenGLView.h:56` | Default window width. | No — constant; could be constexpr. |
| `WINDOW_SIZE_DEFAULT_HEIGHT` | `SDL/MyOpenGLView.h:57` | Default window height. | No — constant; could be constexpr. |
| `MIN_FOV_DEG` | `SDL/MyOpenGLView.h:59` | Field-of-view limit in degrees. | No — limit constant; could be constexpr. |
| `MAX_FOV_DEG` | `SDL/MyOpenGLView.h:60` | Field-of-view limit in degrees. | No — limit constant; could be constexpr. |
| `MIN_FOV` | `SDL/MyOpenGLView.h:61` | FOV limit as tangent of half-angle. | No — derived constant; could be constexpr. |
| `MAX_FOV` | `SDL/MyOpenGLView.h:62` | FOV limit as tangent of half-angle. | No — derived constant; could be constexpr. |
| `MIN_HDR_MAXBRIGHTNESS` | `SDL/MyOpenGLView.h:64` | HDR brightness setting limit. | No — limit constant; could be constexpr. |
| `MAX_HDR_MAXBRIGHTNESS` | `SDL/MyOpenGLView.h:65` | HDR brightness setting limit. | No — limit constant; could be constexpr. |
| `MIN_HDR_PAPERWHITE` | `SDL/MyOpenGLView.h:67` | HDR brightness setting limit. | No — limit constant; could be constexpr. |
| `MAX_HDR_PAPERWHITE` | `SDL/MyOpenGLView.h:68` | HDR brightness setting limit. | No — limit constant; could be constexpr. |
| `MAX_COLOR_SATURATION` | `SDL/MyOpenGLView.h:70` | Max colour saturation setting. | No — limit constant; could be constexpr. |
| `MOUSEX_MAXIMUM` | `SDL/MyOpenGLView.h:72` | Mouse virtual-joystick X limit. | No — tuning constant; could be constexpr. |
| `MOUSEY_MAXIMUM` | `SDL/MyOpenGLView.h:73` | Mouse virtual-joystick Y limit. | No — tuning constant; could be constexpr. |
| `MAX_CLEAR_DEPTH` | `SDL/MyOpenGLView.h:75` | Max depth-clear distance. | No — tuning constant; could be constexpr. |
| `INTERMEDIATE_CLEAR_DEPTH` | `SDL/MyOpenGLView.h:77` | Depth-clear distance for intermediate layer. | No — tuning constant; could be constexpr. |
| `NUM_KEYS` | `SDL/MyOpenGLView.h:80` | Size of key state array. | No — constant; could be constexpr. |
| `MOUSE_DOUBLE_CLICK_INTERVAL` | `SDL/MyOpenGLView.h:81` | Double-click time window in seconds. | No — tuning constant; could be constexpr. |
| `OOMOUSEWHEEL_EVENTS_DELAY_INTERVAL` | `SDL/MyOpenGLView.h:82` | Wheel event repeat delay in seconds. | No — tuning constant; could be constexpr. |
| `OOMOUSEWHEEL_DELTA` | `SDL/MyOpenGLView.h:83` | Mouse wheel delta per notch. | No — constant; could be constexpr. |
| `SNAPSHOTS_PNG_FORMAT` | `SDL/MyOpenGLView.h:85` | Save snapshots as PNG. | Yes — hard-coded compile-time format toggle. |
| `SNAPSHOTHDR_EXTENSION_DEFAULT` | `SDL/MyOpenGLView.h:88` | Default HDR snapshot file extension. | No — constant; could be constexpr. |
| `IDI_OOLITE` | `SDL/OOResourcesWin/OOResourcesWin.h:1` | Windows icon resource id. | No — Windows resource constant. |
| `CREATEPROCESS_MANIFEST_RESOURCE_ID` | `SDL/OOResourcesWin/OOResourcesWin.h:2` | Windows manifest resource id for .rc file. | No — Windows resource constant. |
| `RT_MANIFEST` | `SDL/OOResourcesWin/OOResourcesWin.h:3` | Windows RT_MANIFEST resource type id. | No — Windows resource constant. |
| `XSTRINGIFY` | `SDL/main.cpp:35` | Stringification helper (outer). | No — preprocessor helper; no C++ replacement. |
| `STRINGIFY` | `SDL/main.cpp:36`, `SDL/main.cpp:79` | Stringifies macro argument after expansion. | No — preprocessor helper; no C++ replacement. |
| `STRINGIFY_` | `SDL/main.cpp:78` | Stringification helper. | No — preprocessor helper; no C++ replacement. |
| `OO_SHOW_MSG` | `SDL/main.cpp:101`, `SDL/main.cpp:197` | Shows message box or prints to stdout. | No — platform shim; could be function. |
| `TABS1` | `SDL/main.cpp:103`, `SDL/main.cpp:198` | Tab padding for usage text, by platform. | No — platform shim; could be constexpr. |
| `TABS2` | `SDL/main.cpp:104`, `SDL/main.cpp:199` | Tab padding for usage text, by platform. | No — platform shim; could be constexpr. |
| `TABS3` | `SDL/main.cpp:105`, `SDL/main.cpp:200` | Tab padding for usage text, by platform. | No — platform shim; could be constexpr. |
| `TABS4` | `SDL/main.cpp:106`, `SDL/main.cpp:201` | Tab padding for usage text, by platform. | No — platform shim; could be constexpr. |

## Foundation, attributes, logging, maths, CPU, sound, joystick, oofnd, misc

| Macro | Where | Purpose | Feature flag? |
|---|---|---|---|
| `AI_THINK_INTERVAL` | Core/AI.h:56 | Default seconds between AI think ticks. | No — constant; could be constexpr. |
| `COLLISION_REGION_BORDER_RADIUS` | Core/CollisionRegion.h:52 | Collision region border radius. | No — constant; could be constexpr. |
| `COLLISION_MAX_ENTITIES` | Core/CollisionRegion.h:53 | Max entities tracked per collision region. | No — constant; could be constexpr. |
| `MINIMUM_SHADOWING_ENTITY_RADIUS` | Core/CollisionRegion.h:54 | Min radius for an entity to cast shadows. | No — constant; could be constexpr. |
| `MINIMUM_GAME_TICK` | Core/GameController.h:56 | Largest game time step cap per frame. | No — constant; could be constexpr. |
| `MINIMUM_ANIMATION_TICK` | Core/GameController.h:59 | Smallest frame-time step for animation. | No — constant; could be constexpr. |
| `OO_DEBUG_PROGRESS` | Core/GameController.h:313, Core/GameController.h:320 | Logs debug progress message in debug builds. | Already — gated by OO_DEBUG (meson debug builds). |
| `OO_DEBUG_PUSH_PROGRESS` | Core/GameController.h:315, Core/GameController.h:323 | Pushes debug progress message in debug builds. | Already — gated by OO_DEBUG (meson debug builds). |
| `OO_DEBUG_POP_PROGRESS` | Core/GameController.h:317, Core/GameController.h:326 | Pops debug progress message in debug builds. | Already — gated by OO_DEBUG (meson debug builds). |
| `OOAL_STREAM_CHUNK_SIZE` | Core/OOALSoundDecoder.h:61 | Byte size of streamed audio chunk. | No — constant; could be constexpr. |
| `__block` | Core/OOCPUInfo.cpp:35 | Renames glibc __block around system headers. | No — platform shim; workaround for Clang blocks keyword. |
| `OOLITE_NATIVE_64_BIT` | Core/OOCPUInfo.h:99, Core/OOCPUInfo.h:101 | 1 on 64-bit CPUs for 64-bit optimisations. | No — platform shim; could be constexpr on sizeof(void*). |
| `OOLITE_BIG_ENDIAN` | Core/OOCPUInfoEndian.h:38, Core/OOCPUInfoEndian.h:51 | Big-endian detection (1/0 or "BUG"). | No — platform shim; could be std::endian. |
| `OOLITE_LITTLE_ENDIAN` | Core/OOCPUInfoEndian.h:42, Core/OOCPUInfoEndian.h:47 | Little-endian detection (1/0 or "BUG"). | No — platform shim; could be std::endian. |
| `OOCACHE_PERFORM_INTEGRITY_CHECKS` | Core/OOCache.cpp:118 | Enables cache integrity checking on every operation. | Yes — #ifndef-guarded debug aid, default 0; could become a meson option. |
| `CHECK_INTEGRITY` | Core/OOCache.cpp:174, Core/OOCache.cpp:176 | Runs cache integrity check when enabled, else nothing. | No — helper gated by OOCACHE_PERFORM_INTEGRITY_CHECKS. |
| `AGE_LIST` | Core/OOCache.cpp:890 | Switches age-list nodes into the cache graphviz dump. | Yes — hard-coded 0 debug toggle; slow cache graph rendering when on. |
| `WRITE_ASYNC` | Core/OOCacheManager.cpp:39 | Writes cache to disk on a background thread. | Yes — hard-coded 1 toggle selecting sync or async writes. |
| `PROFILE_WRITES` | Core/OOCacheManager.cpp:40 | Enables cache write profiling output. | Yes — hard-coded 0 profiling toggle; could be a meson option. |
| `MAIN_SYSTEM_MARKET_LIMIT` | Core/OOCommodities.h:41 | Cap on main-system market quantity. | No — constant; could be constexpr. |
| `ZIP_BUFFER_SIZE` | Core/OODataFromOXZFile.cpp:37 | Buffer size for reading OXZ zip entries. | No — constant; could be constexpr. |
| `USE_COMPATIBILITY_MAPPING` | Core/OOEncodingConverter.cpp:40 | Enables compatibility mapping in encoding converter. | Yes — hard-coded 0 toggle for optional code path. |
| `PROFILE_ENCODING_CONVERTER` | Core/OOEncodingConverter.cpp:42 | Enables encoding converter profiling output. | Yes — hard-coded 0 profiling toggle; could be a meson option. |
| `OOLITE_DEBUG` | Core/OOFoundation.h:40, Core/OOFoundation.h:42 | 1 unless NDEBUG; usable in constant expressions. | No — derived from NDEBUG; could be constexpr. |
| `NS_BLOCK_ASSERTIONS` | Core/OOFoundation.h:46 | Disables Foundation-style assertions when not debug. | No — derived from NDEBUG; follows the existing build setting. |
| `OO_DEBUG` | Core/OOFoundation.h:60 | Marks debug builds; gates debug-only code. | Already — set by meson in debug/-O0 builds. |
| `OOLITE_HAVE_CLANG` | Core/OOFoundation.h:68, Core/OOFoundation.h:70 | 1 when compiled with Clang. | No — compiler detection shim. |
| `OOLITE_GCC_VERSION` | Core/OOFoundation.h:76 | GCC version number, undefined on Clang (unused) | No — compiler detection shim. |
| `OOLITE_SDL` | Core/OOFoundation.h:83, Core/OOFoundation.h:135 | Selects SDL front end (always 1). | No — constant 1; only front end, could be removed. |
| `OOLITE_WINDOWS` | Core/OOFoundation.h:86, Core/OOFoundation.h:127 | 1 on Windows builds. | No — platform shim set from -DWIN32. |
| `OOLITE_64_BIT` | Core/OOFoundation.h:88, Core/OOFoundation.h:147 | 1 on 64-bit Windows, else 0. | No — platform shim; could be constexpr on sizeof(void*). |
| `OOLITE_LINUX` | Core/OOFoundation.h:93, Core/OOFoundation.h:131 | 1 on Linux builds. | No — platform shim set from -DLINUX. |
| `MAX` | Core/OOFoundation.h:97, Core/OOMathsBase.h:93 | Maximum of two values. | No — helper; could be std::max. |
| `MIN` | Core/OOFoundation.h:106, Core/OOMathsBase.h:85 | Minimum of two values. | No — helper; could be std::min. |
| `OOLITE_SPEECH_SYNTH` | Core/OOFoundation.h:115, Core/OOFoundation.h:139 | 1 when speech synthesis is built in. | Already — set via meson option `espeak` (HAVE_LIBESPEAK). |
| `OOLITE_ESPEAK` | Core/OOFoundation.h:116, Core/OOFoundation.h:143 | 1 when eSpeak is built in. | Already — set from meson option `espeak` via HAVE_LIBESPEAK. |
| `OOLITE_MACOS` | Core/OOFoundation.h:121, Core/OOFoundation.h:123 | 1 on Apple platforms. | No — platform shim from __APPLE__. |
| `OO_GAME_DATA_TO_USER_FOLDER` | Core/OOFoundation.h:178 | Windows: keep game data in user folder. | Yes — #ifndef-guarded build switch (default 0); not a meson option. |
| `GCC_ATTR` | Core/OOFunctionAttributes.h:5, Core/OOFunctionAttributes.h:7 | Wraps __attribute__ when compiler supports it. | No — attribute shim; could be standard attributes. |
| `__has_feature` | Core/OOFunctionAttributes.h:13 | Fallback returning 0 when compiler lacks it. | No — compiler shim. |
| `__has_attribute` | Core/OOFunctionAttributes.h:17 | Fallback returning 0 when compiler lacks it. | No — compiler shim; use standard __has_cpp_attribute. |
| `__has_extension` | Core/OOFunctionAttributes.h:21 | Fallback returning 0 when compiler lacks it. | No — compiler shim. |
| `OOINLINE` | Core/OOFunctionAttributes.h:24 | Expands to inline. | No — shim; could be plain inline. |
| `ALWAYS_INLINE_FUNC` | Core/OOFunctionAttributes.h:27, Core/OOFunctionAttributes.h:30 | Forces inlining of a function (non-debug builds). | No — attribute shim; could be [[gnu::always_inline]] or plain inline. |
| `PURE_FUNC` | Core/OOFunctionAttributes.h:34 | Marks function as GCC pure. | No — attribute shim; could be [[gnu::pure]]. |
| `CONST_FUNC` | Core/OOFunctionAttributes.h:36 | Marks function as GCC const (no side effects). | No — attribute shim; could be [[gnu::const]]. |
| `NONNULL_FUNC` | Core/OOFunctionAttributes.h:38 | Marks pointer parameters as non-null. | No — attribute shim; could be [[gnu::nonnull]]. |
| `DEPRECATED_FUNC` | Core/OOFunctionAttributes.h:39 | Marks function deprecated (used only by DEPRECATED_MSG). | No — attribute shim; could be [[deprecated]]. |
| `NO_RETURN_FUNC` | Core/OOFunctionAttributes.h:40 | Marks function as never returning (unused) | No — attribute shim; could be [[noreturn]]. |
| `NO_INLINE_FUNC` | Core/OOFunctionAttributes.h:41 | Forbids inlining of a function. | No — attribute shim; could be [[gnu::noinline]]. |
| `INLINE_PURE_FUNC` | Core/OOFunctionAttributes.h:43 | Always-inline plus pure attributes combined. | No — attribute shim; could be inline [[gnu::pure]]. |
| `INLINE_CONST_FUNC` | Core/OOFunctionAttributes.h:44 | Always-inline plus const attributes combined. | No — attribute shim; could be inline [[gnu::const]]. |
| `DEPRECATED_MSG` | Core/OOFunctionAttributes.h:47, Core/OOFunctionAttributes.h:49 | Deprecation attribute with message (unused) | No — attribute shim; could be [[deprecated("msg")]]. |
| `DEPRECATED_METHOD` | Core/OOFunctionAttributes.h:53, Core/OOFunctionAttributes.h:56 | Marks method deprecated with message (unused) | No — attribute shim; could be [[deprecated("msg")]]. |
| `EXPECT` | Core/OOFunctionAttributes.h:60, Core/OOFunctionAttributes.h:63 | Branch-likely hint via __builtin_expect. | No — attribute shim; could be [[likely]]. |
| `EXPECT_NOT` | Core/OOFunctionAttributes.h:61, Core/OOFunctionAttributes.h:64 | Branch-unlikely hint via __builtin_expect. | No — attribute shim; could be [[unlikely]]. |
| `OO_RETURNS_RETAINED` | Core/OOFunctionAttributes.h:70, Core/OOFunctionAttributes.h:72 | Clang ARC returns-retained attribute shim (unused) | No — Objective-C leftover; could be removed. |
| `OO_NS_CONSUMED` | Core/OOFunctionAttributes.h:79, Core/OOFunctionAttributes.h:81 | Clang ARC ns_consumed attribute shim (unused) | No — Objective-C leftover; could be removed. |
| `OO_UNREACHABLE` | Core/OOFunctionAttributes.h:88, Core/OOFunctionAttributes.h:90 | Marks unreachable code path (unused) | No — attribute shim; could be std::unreachable. |
| `HPvector_between` | Core/OOHPVector.h:101 | Vector from a to b, high-precision. | No — helper; could be inline function. |
| `GLVertexOOHPVector` | Core/OOHPVector.h:179 | glVertex wrapper for OOHPVector (unused) | No — helper; could be inline function. |
| `GLTranslateOOHPVector` | Core/OOHPVector.h:184 | glTranslate wrapper for OOHPVector (unused) | No — helper; could be inline function. |
| `OO_PLAIN_CPP_UNIT` | Core/OOIsNumberLiteral.cpp:25, Core/OOMatrix.cpp:25 | Marks a unit as plain C++, skipping game headers. | No — guard/marker; set per translation unit. |
| `FAIL` | Core/OOIsNumberLiteral.cpp:31, Core/OOIsNumberLiteral.cpp:38 | Local early-return-false helper in number-literal parser. | No — helper; could be inline lambda. |
| `MAX_STICKS` | Core/OOJoystickManager.h:296 | Max joysticks supported. | No — constant; could be constexpr. |
| `MAX_AXES` | Core/OOJoystickManager.h:297 | Max joystick axes per stick. | No — constant; could be constexpr. |
| `MAX_REAL_BUTTONS` | Core/OOJoystickManager.h:298 | Max physical joystick buttons. | No — constant; could be constexpr. |
| `MAX_HATS` | Core/OOJoystickManager.h:299 | Max joystick hats per stick. | No — constant; could be constexpr. |
| `MAX_BUTTONS` | Core/OOJoystickManager.h:300 | Max joystick buttons including hats. | No — constant; could be constexpr. |
| `STICK_NOFUNCTION` | Core/OOJoystickManager.h:301 | Sentinel for no function assigned. | No — constant; could be constexpr. |
| `STICK_AXISUNASSIGNED` | Core/OOJoystickManager.h:302 | Sentinel for unassigned axis. | No — constant; could be constexpr. |
| `STICK_PRECISIONFAC` | Core/OOJoystickManager.h:304 | Precision-mode scaling factor. | No — constant; could be constexpr. |
| `STICK_NORMALDIV` | Core/OOJoystickManager.h:305 | Divisor normalising raw axis values. | No — constant; could be constexpr. |
| `STICK_PRECISIONDIV` | Core/OOJoystickManager.h:306 | Divisor for precision-mode axis (unused) | No — constant; could be constexpr. |
| `STICK_DEADZONE` | Core/OOJoystickManager.h:308 | Default joystick deadzone. | No — constant; could be constexpr. |
| `STICK_MAX_DEADZONE` | Core/OOJoystickManager.h:310 | Maximum joystick deadzone. | No — constant; could be constexpr. |
| `AXCBTHRESH` | Core/OOJoystickManager.h:319 | Joystick axis-to-button threshold. | No — constant; could be constexpr. |
| `STICK_FUNCTION` | Core/OOJoystickManager.h:334 | Plist key "stickFunc" (unused) | No — constant; could be constexpr. |
| `ENUMKEY` | Core/OOJoystickManager.h:343 | Formats enum value as decimal string key. | No — helper; could be inline function. |
| `SPLINE_POINT_MIN_SPACING` | Core/OOJoystickProfile.cpp:37 | Min spacing between joystick-profile spline points. | No — constant; could be constexpr. |
| `STICKPROFILE_MAX_POWER` | Core/OOJoystickProfile.h:63 | Max power exponent of stick profile. | No — constant; could be constexpr. |
| `CPU_TYPE_STRING` | Core/OOLogHeader.cpp:62, Core/OOLogHeader.cpp:64 | CPU architecture name string for log header. | No — platform shim chosen by compiler arch macros; could be constexpr. |
| `OS_TYPE_STRING` | Core/OOLogHeader.cpp:80, Core/OOLogHeader.cpp:82 | OS name string for log header. | No — platform shim; could be constexpr. |
| `RELEASE_VARIANT_STRING` | Core/OOLogHeader.cpp:92, Core/OOLogHeader.cpp:94 | Build-variant suffix for log header. | No — helper; derived from OO_DEBUG/DEV_RELEASE. |
| `systemString` | Core/OOLogHeader.cpp:152 | Log-header OS string expression. | No — helper; could be inline function. |
| `CPUFAMILY_INTEL_MEROM` | Core/OOLogHeader.cpp:225 | macOS CPU family id for log header. | No — constant; could be constexpr. |
| `CPUFAMILY_INTEL_HASWELL` | Core/OOLogHeader.cpp:229 | macOS CPU family id for log header. | No — constant; could be constexpr. |
| `CPUFAMILY_INTEL_BROADWELL` | Core/OOLogHeader.cpp:233 | macOS CPU family id for log header. | No — constant; could be constexpr. |
| `CPUFAMILY_INTEL_SKYLAKE` | Core/OOLogHeader.cpp:237 | macOS CPU family id for log header. | No — constant; could be constexpr. |
| `kFlushInterval` | Core/OOLogOutputHandler.cpp:71 | Log file flush interval. | No — constant; could be constexpr. |
| `OOLOG_FUNCTION_NAME` | Core/OOLogging.h:43, Core/OOLogging.h:45 | Function-name token for logging per compiler. | No — shim; could be __func__ or std::source_location. |
| `OOLOG_FILE_NAME` | Core/OOLogging.h:53, Core/OOLogging.h:55 | File name passed to logging, or NULL. | Yes — #ifdef OOLOG_NO_FILE_NAME strips file names; never set. |
| `OOLOG_SHORT_CIRCUIT` | Core/OOLogging.h:65 | Skips evaluating log args when class disabled. | Yes — #ifndef-guarded tunable, default 1; never overridden. |
| `OOLogGenericParameterError` | Core/OOLogging.h:80 | Logs standard bad-parameter error. | No — helper; could be inline function. |
| `OOLogGenericSubclassResponsibility` | Core/OOLogging.h:87 | Logs standard subclass-must-override error. | No — helper; could be inline function. |
| `M_PI` | Core/OOMathsBase.h:59 | Fallback pi constant. | No — platform shim; could be std::numbers::pi. |
| `M_PI_2` | Core/OOMathsBase.h:62 | Fallback pi/2 constant. | No — platform shim; could be constexpr. |
| `M_PI_4` | Core/OOMathsBase.h:65 | Fallback pi/4 constant (unused) | No — platform shim; could be constexpr. |
| `M_1_PI` | Core/OOMathsBase.h:68 | Fallback 1/pi constant (unused) | No — platform shim; could be std::numbers::inv_pi. |
| `M_2_PI` | Core/OOMathsBase.h:71 | Fallback 2/pi constant (unused) | No — platform shim; could be constexpr. |
| `M_2_SQRTPI` | Core/OOMathsBase.h:74 | Fallback 2/sqrt(pi) constant (unused) | No — platform shim; could be constexpr. |
| `M_SQRT2` | Core/OOMathsBase.h:77 | Fallback sqrt(2) constant. | No — platform shim; could be std::numbers::sqrt2. |
| `M_SQRT1_2` | Core/OOMathsBase.h:80 | Fallback 1/sqrt(2) constant. | No — platform shim; could be constexpr. |
| `ABS` | Core/OOMathsBase.h:101, Core/OOMathsBase.h:117 | Absolute-value helper for maths headers (unused) | No — helper; could be std::abs. |
| `OOMatrixValuesForOpenGL` | Core/OOMatrix.h:118 | Pointer to matrix floats for GL calls. | No — helper; could be inline function. |
| `GLMultOOMatrix` | Core/OOMatrix.h:119 | glMultMatrixf wrapper for OOMatrix (unused) | No — helper; could be inline function. |
| `GLLoadOOMatrix` | Core/OOMatrix.h:124 | glLoadMatrixf wrapper for OOMatrix. | No — helper; could be inline function. |
| `GLMultTransposeOOMatrix` | Core/OOMatrix.h:129 | glMultTransposeMatrixf wrapper for OOMatrix (unused) | No — helper; could be inline function. |
| `GLLoadTransposeOOMatrix` | Core/OOMatrix.h:134 | glLoadTransposeMatrixf wrapper for OOMatrix (unused) | No — helper; could be inline function. |
| `GLUniformMatrix` | Core/OOMatrix.h:139 | glUniformMatrix4fv wrapper for OOMatrix. | No — helper; could be inline function. |
| `OOAL` | Core/OOOpenAL.h:37 | Calls an OpenAL function and checks for errors. | No — helper; could be inline function. |
| `OO_PROFILING_STOPWATCH_WINDOWS` | Core/OOProfilingStopwatch.h:76 | Selects Windows timeGetTime stopwatch backend. | No — platform shim; could be std::chrono. |
| `OOGetHighResTime` | Core/OOProfilingStopwatch.h:85 | Reads high-res time (timeGetTime on Windows). | No — platform shim; could be std::chrono. |
| `OODisposeHighResTime` | Core/OOProfilingStopwatch.h:86, Core/OOProfilingStopwatch.h:107 | Releases a high-res time value (no-op). | No — platform shim; could be inline function. |
| `OOCopyHighResTime` | Core/OOProfilingStopwatch.h:90, Core/OOProfilingStopwatch.h:111 | Copies a high-res time value. | No — platform shim; could be inline function. |
| `OO_PROFILING_STOPWATCH_GETTIMEOFDAY` | Core/OOProfilingStopwatch.h:96 | Selects gettimeofday stopwatch backend. | No — platform shim; could be std::chrono. |
| `kDefaultFlasherColor` | Core/OOShipRegistry.cpp:1419 | Default colour name for ship flashers. | No — constant; could be constexpr. |
| `OOLITE_OPENAL` | Core/OOSound.h:48 | Selects OpenAL sound backend (only one). | No — constant 1; only implementation, could be removed. |
| `OOSoundAcquireLock` | Core/OOSoundInternal.h:10 | No-op sound lock acquire. | No — no-op shim; could be removed. |
| `OOSoundReleaseLock` | Core/OOSoundInternal.h:13 | No-op sound lock release. | No — no-op shim; could be removed. |
| `OO_DEFAULT_SOUNDSOURCE_GAIN` | Core/OOSoundSource.h:46 | Default sound source gain. | No — constant; could be constexpr. |
| `NEXT` | Core/OOSoundSourcePool.cpp:164 | Next index in circular sound-source pool. | No — helper; could be inline function. |
| `OO_LIKELY_PROPERTIES_PER_SYSTEM` | Core/OOSystemDescriptionManager.cpp:50 | Likely system property count (unused) | No — constant; could be constexpr. |
| `OO_SYSTEM_LAYERS` | Core/OOSystemDescriptionManager.h:72 | Number of system description layers. | No — constant; could be constexpr. |
| `OO_SYSTEMS_PER_GALAXY` | Core/OOSystemDescriptionManager.h:73 | Systems per galaxy. | No — constant; could be constexpr. |
| `OO_GALAXIES_AVAILABLE` | Core/OOSystemDescriptionManager.h:74 | Number of galaxies. | No — constant; could be constexpr. |
| `OO_SYSTEMS_AVAILABLE` | Core/OOSystemDescriptionManager.h:75 | Total systems across galaxies. | No — constant; could be constexpr. |
| `OO_SYSTEM_CACHE_LENGTH` | Core/OOSystemDescriptionManager.h:77 | Size of system description cache. | No — constant; could be constexpr. |
| `TRUMBLE_MAX_ROTATION` | Core/OOTrumble.h:40 | Trumble max rotation. | No — constant; could be constexpr. |
| `TRUMBLE_MAX_ROTATIONAL_VELOCITY` | Core/OOTrumble.h:41 | Trumble max rotational velocity. | No — constant; could be constexpr. |
| `TRUMBLE_GROWTH_RATE` | Core/OOTrumble.h:43 | Trumble growth rate. | No — constant; could be constexpr. |
| `kOOMaxCredits` | Core/OOTypes.h:249 | Maximum credits value. | No — constant; could be constexpr. |
| `vector_between` | Core/OOVector.h:86 | Vector from a to b. | No — helper; could be inline function. |
| `GLVertexOOVector` | Core/OOVector.h:178 | glVertex wrapper for OOVector. | No — helper; could be inline function. |
| `GLTranslateOOVector` | Core/OOVector.h:183 | glTranslate wrapper for OOVector. | No — helper; could be inline function. |
| `ranrot_rand` | Core/legacy_random.h:68 | Legacy RanRot random generator step. | No — helper; could be inline function. |
| `OO_LOG` | oofnd/Log.hpp:535 | Logs a message with class, with short-circuit check. | No — helper; wraps logging. |
| `OO_LOG_ERR` | oofnd/Log.hpp:541 | Logs an error-class message. | No — helper; wraps OO_LOG. |
| `OO_LOG_WARN` | oofnd/Log.hpp:544 | Logs a warning-class message. | No — helper; wraps OO_LOG. |
| `OOFND_PLIST_HPP` | oofnd/PList.hpp:70 | Include guard for PList.hpp. | No — guard; could be #pragma once. |
| `OO_PRINTF_FORMAT` | oofnd/PrintfFormat.h:18, oofnd/PrintfFormat.h:21 | printf-format checking attribute. | No — attribute shim; could be [[gnu::format]]. |
| `OOCAssert` | oofnd/objc/OOAssert.h:43 | Assertion with message, Objective-C-style compat. | No — helper; wraps standard assert/NDEBUG behaviour. |
| `OOCParameterAssert` | oofnd/objc/OOAssert.h:50 | Parameter-validating assertion. | No — helper; wraps standard assert/NDEBUG behaviour. |

## Vendored macros

Third-party C, left as is under hard rule 7. Configuration switches such as `MINIZ_NO_*`, `TINYEXR_USE_*` and `STBIW_*` are the libraries' own build knobs. They could be set from meson, but none of them is a game feature flag. Everything else is internal constants or helpers: **No**.

**miniz**: `MAX_MEM_LEVEL`, `MAX_WBITS`, `MINGW_HAS_SECURE_API`, `MINIZ_EXPORT`, `MINIZ_HAS_64BIT_REGISTERS`, `MINIZ_LITTLE_ENDIAN`, `MINIZ_NO_ARCHIVE_APIS`, `MINIZ_NO_ARCHIVE_WRITING_APIS`, `MINIZ_NO_TIME`, `MINIZ_UNALIGNED_USE_MEMCPY`, `MINIZ_USE_UNALIGNED_LOADS_AND_STORES`, `MINIZ_X86_OR_X64_CPU`, `MZ_ADLER32_INIT`, `MZ_ASSERT`, `MZ_CLEAR_ARR`, `MZ_CLEAR_OBJ`, `MZ_CLEAR_PTR`, `MZ_CRC32_INIT`, `MZ_DEFAULT_WINDOW_BITS`, `MZ_DEFLATED`, `MZ_DELETE_FILE`, `MZ_FALSE`, `MZ_FCLOSE`, `MZ_FFLUSH`, `MZ_FILE`, `MZ_FILE_STAT`, `MZ_FILE_STAT_STRUCT`, `MZ_FOPEN`, `MZ_FORCEINLINE`, `MZ_FREAD`, `MZ_FREE`, `MZ_FREOPEN`, `MZ_FSEEK64`, `MZ_FTELL64`, `MZ_FWRITE`, `MZ_MACRO_END`, `MZ_MALLOC`, `MZ_MAX`, `MZ_MIN`, `MZ_READ_LE16`, `MZ_READ_LE32`, `MZ_READ_LE64`, `MZ_REALLOC`, `MZ_SWAP_UINT32`, `MZ_TIME_T`, `MZ_TOLOWER`, `MZ_TRUE`, `MZ_UINT16_MAX`, `MZ_UINT32_MAX`, `MZ_VERNUM`, `MZ_VERSION`, `MZ_VER_MAJOR`, `MZ_VER_MINOR`, `MZ_VER_REVISION`, `MZ_VER_SUBREVISION`, `MZ_WRITE_LE16`, `MZ_WRITE_LE32`, `MZ_WRITE_LE64`, `MZ_ZIP64_MAX_CENTRAL_EXTRA_FIELD_SIZE`, `MZ_ZIP64_MAX_LOCAL_EXTRA_FIELD_SIZE`, `MZ_ZIP_ARRAY_ELEMENT`, `MZ_ZIP_ARRAY_SET_ELEMENT_SIZE`, `TDEFL_LESS_MEMORY`, `TDEFL_PROBE`, `TDEFL_PUT_BITS`, `TDEFL_PUT_BITS_FAST`, `TDEFL_READ_UNALIGNED_WORD`, `TDEFL_READ_UNALIGNED_WORD2`, `TDEFL_READ_UNALIGNED_WORD32`, `TDEFL_RLE_PREV_CODE_SIZE`, `TDEFL_RLE_ZERO_CODE_SIZE`, `TINFL_BITBUF_SIZE`, `TINFL_CR_BEGIN`, `TINFL_CR_FINISH`, `TINFL_CR_RETURN`, `TINFL_CR_RETURN_FOREVER`, `TINFL_DECOMPRESS_MEM_TO_MEM_FAILED`, `TINFL_GET_BITS`, `TINFL_GET_BYTE`, `TINFL_HUFF_BITBUF_FILL`, `TINFL_HUFF_DECODE`, `TINFL_LZ_DICT_SIZE`, `TINFL_MEMCPY`, `TINFL_MEMSET`, `TINFL_NEED_BITS`, `TINFL_SKIP_BITS`, `TINFL_USE_64BIT_BITBUF`, `WIN32_LEAN_AND_MEAN`, `ZLIB_VERNUM`, `ZLIB_VERSION`, `ZLIB_VER_MAJOR`, `ZLIB_VER_MINOR`, `ZLIB_VER_REVISION`, `ZLIB_VER_SUBREVISION`, `Z_BEST_COMPRESSION`, `Z_BEST_SPEED`, `Z_BLOCK`, `Z_BUF_ERROR`, `Z_DATA_ERROR`, `Z_DEFAULT_COMPRESSION`, `Z_DEFAULT_STRATEGY`, `Z_DEFAULT_WINDOW_BITS`, `Z_DEFLATED`, `Z_ERRNO`, `Z_FILTERED`, `Z_FINISH`, `Z_FIXED`, `Z_FULL_FLUSH`, `Z_HUFFMAN_ONLY`, `Z_MEM_ERROR`, `Z_NEED_DICT`, `Z_NO_COMPRESSION`, `Z_NO_FLUSH`, `Z_NULL`, `Z_OK`, `Z_PARAM_ERROR`, `Z_PARTIAL_FLUSH`, `Z_RLE`, `Z_STREAM_END`, `Z_STREAM_ERROR`, `Z_SYNC_FLUSH`, `Z_VERSION_ERROR`, `adler32`, `alloc_func`, `compress`, `compress2`, `compressBound`, `crc32`, `deflate`, `deflateBound`, `deflateEnd`, `deflateInit`, `deflateInit2`, `deflateReset`, `free_func`, `inflate`, `inflateEnd`, `inflateInit`, `inflateInit2`, `inflateReset`, `internal_state`, `tinfl_get_adler32`, `tinfl_init`, `uncompress`, `uncompress2`, `zError`, `z_stream`, `zlibVersion`, `zlib_version`

**tinyexr**: `NANOZLIB_IMPLEMENTATION`, `NOMINMAX`, `TINYEXR_CHECK_AND_RETURN_C`, `TINYEXR_CHECK_AND_RETURN_MSG`, `TINYEXR_COMPRESSIONTYPE_NONE`, `TINYEXR_COMPRESSIONTYPE_PIZ`, `TINYEXR_COMPRESSIONTYPE_RLE`, `TINYEXR_COMPRESSIONTYPE_ZFP`, `TINYEXR_COMPRESSIONTYPE_ZIP`, `TINYEXR_COMPRESSIONTYPE_ZIPS`, `TINYEXR_DIMENSION_THRESHOLD`, `TINYEXR_ERROR_CANT_OPEN_FILE`, `TINYEXR_ERROR_CANT_WRITE_FILE`, `TINYEXR_ERROR_DATA_TOO_LARGE`, `TINYEXR_ERROR_INVALID_ARGUMENT`, `TINYEXR_ERROR_INVALID_DATA`, `TINYEXR_ERROR_INVALID_EXR_VERSION`, `TINYEXR_ERROR_INVALID_FILE`, `TINYEXR_ERROR_INVALID_HEADER`, `TINYEXR_ERROR_INVALID_MAGIC_NUMBER`, `TINYEXR_ERROR_INVALID_PARAMETER`, `TINYEXR_ERROR_LAYER_NOT_FOUND`, `TINYEXR_ERROR_SERIALIZATION_FAILED`, `TINYEXR_ERROR_UNSUPPORTED_FEATURE`, `TINYEXR_ERROR_UNSUPPORTED_FORMAT`, `TINYEXR_HAS_CXX11`, `TINYEXR_H_`, `TINYEXR_IMPLEMENTATION`, `TINYEXR_IMPLEMENTATION_DEFINED`, `TINYEXR_LITTLE_ENDIAN`, `TINYEXR_MAX_CUSTOM_ATTRIBUTES`, `TINYEXR_MAX_HEADER_ATTRIBUTES`, `TINYEXR_PIXELTYPE_FLOAT`, `TINYEXR_PIXELTYPE_HALF`, `TINYEXR_PIXELTYPE_UINT`, `TINYEXR_SUCCESS`, `TINYEXR_TILE_MIPMAP_LEVELS`, `TINYEXR_TILE_ONE_LEVEL`, `TINYEXR_TILE_RIPMAP_LEVELS`, `TINYEXR_TILE_ROUND_DOWN`, `TINYEXR_TILE_ROUND_UP`, `TINYEXR_USE_MINIZ`, `TINYEXR_USE_NANOZLIB`, `TINYEXR_USE_OPENMP`, `TINYEXR_USE_PIZ`, `TINYEXR_USE_POSIX_MMAP`, `TINYEXR_USE_STB_ZLIB`, `TINYEXR_USE_THREAD`, `TINYEXR_USE_WIN32_MMAP`, `TINYEXR_USE_ZFP`, `TINYEXR_X86_OR_X64_CPU`, `TINYEXR_ZFP_COMPRESSIONTYPE_ACCURACY`, `TINYEXR_ZFP_COMPRESSIONTYPE_PRECISION`, `TINYEXR_ZFP_COMPRESSIONTYPE_RATE`, `WIN32_LEAN_AND_MEAN`, `getChar`, `getCode`

**stb_image_write**: `INCLUDE_STB_IMAGE_WRITE_H`, `STBIWDEF`, `STBIW_ASSERT`, `STBIW_EXTERN`, `STBIW_FREE`, `STBIW_MALLOC`, `STBIW_MEMMOVE`, `STBIW_REALLOC`, `STBIW_REALLOC_SIZED`, `STBIW_UCHAR`, `STBIW_WINDOWS_UTF8`, `STB_IMAGE_WRITE_IMPLEMENTATION`, `_CRT_NONSTDC_NO_DEPRECATE`, `_CRT_SECURE_NO_WARNINGS`, `stbiw__ZHASH`, `stbiw__max`, `stbiw__sbcount`, `stbiw__sbfree`, `stbiw__sbgrow`, `stbiw__sbm`, `stbiw__sbmaybegrow`, `stbiw__sbn`, `stbiw__sbneedgrow`, `stbiw__sbpush`, `stbiw__sbraw`, `stbiw__wp32`, `stbiw__wpng4`, `stbiw__wptag`, `stbiw__zlib_add`, `stbiw__zlib_flush`, `stbiw__zlib_huff`, `stbiw__zlib_huff1`, `stbiw__zlib_huff2`, `stbiw__zlib_huff3`, `stbiw__zlib_huff4`, `stbiw__zlib_huffa`, `stbiw__zlib_huffb`

**MiniZip**: `ALLOC`, `BUFREADCOMMENT`, `CASESENSITIVITYDEFAULTVALUE`, `CASESENSITIVITYDEFAULT_NO`, `NOUNCRYPT`, `OF`, `SIZECENTRALDIRITEM`, `SIZEZIPLOCALHEADER`, `STRCMPCASENOSENTIVEFUNCTION`, `TRYFREE`, `UNZ_BADZIPFILE`, `UNZ_BUFSIZE`, `UNZ_CRCERROR`, `UNZ_END_OF_LIST_OF_FILE`, `UNZ_EOF`, `UNZ_ERRNO`, `UNZ_INTERNALERROR`, `UNZ_MAXFILENAMEINZIP`, `UNZ_OK`, `UNZ_PARAMERROR`, `ZCALLBACK`, `ZCLOSE64`, `ZERROR64`, `ZLIB_FILEFUNC_MODE_CREATE`, `ZLIB_FILEFUNC_MODE_EXISTING`, `ZLIB_FILEFUNC_MODE_READ`, `ZLIB_FILEFUNC_MODE_READWRITEFILTER`, `ZLIB_FILEFUNC_MODE_WRITE`, `ZLIB_FILEFUNC_SEEK_CUR`, `ZLIB_FILEFUNC_SEEK_END`, `ZLIB_FILEFUNC_SEEK_SET`, `ZOPEN64`, `ZPOS64_T`, `ZREAD64`, `ZSEEK64`, `ZTELL64`, `ZWRITE64`, `Z_BZIP2ED`, `_CRT_SECURE_NO_WARNINGS`, `_FILE_OFFSET_BIT`, `_LARGEFILE64_SOURCE`, `__USE_FILE_OFFSET64`, `__USE_LARGEFILE64`, `fopen64`, `fseeko64`, `ftello64`, `local`
