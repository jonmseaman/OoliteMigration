# Parity findings: header constants sweep

`#define`s, enums, `static const` values and inline functions in paired `.h` files, compared upstream ↔ port.

Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

**Status:** done — 70 items: 48 ✅ 4 ⚠️ 0 ❌ 18 ➖

Audited against seriesb/028-upstream-772-tests @ bf01f1b49 on 2026-11-16.

**Method.** A script (`.agent-tmp/parity-run/extra/header_consts.py`, not committed) paired each upstream `src/<path>.h` with the port's `src/<path>.h` or `.hpp`: 238 pairs, and 28 upstream headers with no counterpart. For each header it:

- stripped comments and joined `\` continuations;
- expanded the `.tbl` X-macro includes (`ENTRY(label, value)`, `GALACTIC_HYPERSPACE_ENTRY`, `DIFF_STRING_ENTRY`, with `#` and `##` handled) inside enum bodies, using the `ENTRY` definition in force at the include;
- evaluated `#if`/`#ifdef`/`#elif`/`#else` where the result could be decided from macros defined earlier in the same file, plus the upstream build's `OOLITE_MAC_OS_X=0`, `OOLITE_SDL=1`, `GNUSTEP=1` and `NEW_PLANETS=1` (that last one comes from `OOStellarBody.h`). Where a condition could not be decided, it kept every branch as an alternative;
- extracted object-like `#define NAME value`, every enumerator (implicit values computed, initialisers evaluated against earlier enumerators and macros), and namespace-scope `const`/`constexpr`/`static const` scalars and strings that have initialisers.

Before comparing it normalised the values: `@"x"`→`"x"`, `YES`/`NO`→`true`/`false`, `nil`/`NULL`/`nullptr`, float and integer suffixes, whitespace and redundant outer parentheses. It compared numerically wherever an expression could be evaluated.

A name missing from its paired header was then looked up in every other port header ("moved") and in the port's `.cpp` files. A port-only name was looked up in the upstream `.m` files, because upstream declared many keys `extern` in the header and defined them in the implementation (53 such keys, all identical). No `cxx_` prefix is left to strip: T107 (`0d2f6072c`) dropped it from every identifier, so names now match upstream's directly. The drop of the `OO` prefix has not reached 028.

New since the previous run are the scoped enums. T101 (`8acad438c`) renamed every `enum class` constant to `kPascalCase`, and spec 009 turned the `.tbl` X-macro tables into `Core/Tables/*.h` enum headers. An upstream enumerator of a named enum was matched to the port's `Type::kName` through the `OOEnumName()` switch where there is one (it holds the name upstream stringified), otherwise by the longest name suffix within the same type. An enumerator of an anonymous enum (for example the `kOOTexture*` flags) was matched by type prefix plus suffix. I listed every heuristic match (258 of them) and checked each by eye. A second script (`tables_check.py`) also checked the ten table headers against the `.tbl` files: order, values, `OOEnumName()` strings, the `MakeEnumTable` order and the `static_assert` pins.

Inline functions (`OOINLINE`, `static inline`, `inline`, `NS_INLINE`, `constexpr`) were extracted from every upstream header and their bodies compared after normalisation. That skips the maths headers covered by [math.md](math.md): `OOMaths`, `OOFastArithmetic`, `OOVector`, `OOHPVector`, `OOQuaternion`, `OOMatrix` and `OOVoxel`. I read every differing or missing item by hand, on both sides.

Script artefacts that turned out to be false positives, and are not listed as items:
- `PlayerEntity`'s `GUI_ROW_OPTIONS_*`/`GUI_ROW_GAMEOPTIONS_*` and `OOJoystickManager`'s `AXIS_*`/`BUTTON_*` (off by 1-3). The port writes these enums as `inline constexpr int` chains with an `#if`/`#else` per conditional row, and the script kept the last alternative. Read by hand, both sides have the same rows under the same conditions (`OOLITE_SDL`, `OOLITE_SPEECH_SYNTH`, `OO_RESOLUTION_OPTION`, `OO_FOV_INFLIGHT_CONTROL_ENABLED`).
- `miniz.h`'s `TDEFL_LZ_*` sizes. The script could not pin `TDEFL_LESS_MEMORY 0` (it is defined inside a guarded block). The port's values are those of upstream's `#else` branch.
- `OLD_ENERGY_UNIT_NORMAL`/`NAVAL`, which the script matched to `kNormal`/`kNaval` by suffix. The port has `kOldNormal = 15` and `kOldNaval = 20`.
- `kOOMusicModeMax`. Upstream's `OOLITE_ITUNES_SUPPORT` is `OOLITE_MAC_COCOA_UI`, which is 0, so the value is `kOOMusicOn`, as in the port.
- `STATION_ALERT_LEVEL_*`, `kOOTextureData*`, the `k…Default` aliases, `kOOTCPProtocolVersion_1_1_0`, `SHADERS_MIN`, `NULL_SHADER` and `OO_ENTER_OPENGL`. The script could not evaluate their initialisers; read by hand, the values are the same.
- `OOStellarBody`'s `STELLAR_TYPE_ATMOSPHERE` and `PlayerEntity`'s `GUI_ROW_GAMEOPTIONS_PROCEDURALLYTEXTUREDPLANETS`. Both sit under `#if !NEW_PLANETS`, which upstream compiles out.

## Summary

Totals: 238 pairs; 889 `#define`s, 966 enumerator values and 173 constants compared by name and value; 110 non-maths inline functions compared by body. The previous run counted 857/948/173/105 with a different script. The differences come from counting rules: for example, `constexpr` inlines now count, and the `GALACTIC_HYPERSPACE_*` table is now expanded.

- **Value differences:** none in any numeric value, string key or enum order, apart from the ⚠️ items below. The only enum renumbering is still `kOOShaderUniformTypeObject`/`kOOShaderUniformTypeCount` (+1). The type is internal and never persisted.
- **Moved, values identical:** 686 enumerators were found by name or through their scoped form, 150 `#define`s became `constexpr` constants, and 38 `#define`s and 32 constants now live in other files. The biggest moves are to `Core/Tables/*.h` (160 enumerators from `Entity.h`, `PlayerEntity.h`, `ShipEntity.h` and `OOTypes.h`), `Materials/OOTextureFlags.h` (29), `OOCommodities.cpp` (32 keys), `OOJSEngineCore.h` (14), `OOOpenGLExtensionPointers.h` (8), `OOMathsBase.h` (8 `M_*`), `OOOpenGLCheck.h` (5) and `OOCPUInfoEndian.h` (2).
- **Port-only names:** 345 in paired headers, mostly the scoped `k…` enumerators and the tables that `static_assert`s pin. The 53 string keys among them (28 in `OOMaterialSpecifier.h`, 16 in `OOTexture.h`, 9 in `OOShaderMaterial.h`) equal upstream's `.m` values character for character.

| Header pair (upstream → port, under `src/`) | #defines | #enum values | #consts | #inlines | Differences |
|---|---:|---:|---:|---:|---|
| `Core/AI.h` | 1 | 0 | 0 | 0 | — |
| `Core/CollisionRegion.h` | 3 | 0 | 0 | 0 | — |
| `Core/Debug/OODebugFlags.h` | 2 | 11 | 0 | 0 | — (`DEBUG_ALL` → `OODebugFlags::kAll`, 0xffffffff) |
| `Core/Debug/OODebugTCPConsoleClient.h` | 0 | 6 | 0 | 0 | — |
| `Core/Debug/OODebugTCPConsoleProtocol.h` | 23 | 6 | 0 | 0 | [1 ✅](#oodebugtcpconsoleprotocol) |
| `Core/Debug/OOTCPStreamDecoderAbstractionLayer.h` | 1 | 0 | 0 | 0 | [Mac-only](#maconly) |
| `Core/Entities/DustEntity.h` | 2 | 0 | 0 | 0 | — |
| `Core/Entities/Entity.h` | 6 | 38 | 0 | 0 | — (38 moved → `Core/Tables/OOEntityStatus.h`, `OOScanClass.h`; see [Tables](#tables)) |
| `Core/Entities/OOBreakPatternEntity.h` | 2 | 2 | 0 | 0 | — |
| `Core/Entities/OOExhaustPlumeEntity.h` | 0 | 1 | 0 | 0 | — |
| `Core/Entities/OOParticleSystem.h` | 0 | 2 | 0 | 0 | — |
| `Core/Entities/OOStellarBody.h` | 3 | 4 | 0 | 0 | [1 ➖](#oostellarbody) |
| `Core/Entities/OOSunEntity.h` | 6 | 0 | 0 | 0 | — |
| `Core/Entities/PlayerEntity.h` | 71 | 133 | 0 | 1 | [7 ✅](#playerentity) (34 moved → `Core/Tables/OOGUIScreenID.h`, `OOGalacticHyperspaceBehaviour.h`) |
| `Core/Entities/PlayerEntityContracts.h` | 25 | 0 | 0 | 0 | — |
| `Core/Entities/PlayerEntityKeyMapper.h` | 24 | 0 | 0 | 0 | — |
| `Core/Entities/PlayerEntityLegacyScriptEngine.h` | 0 | 13 | 0 | 0 | — |
| `Core/Entities/PlayerEntityLoadSave.h` | 13 | 0 | 0 | 0 | — |
| `Core/Entities/PlayerEntityStickMapper.h` | 12 | 0 | 0 | 0 | — |
| `Core/Entities/ShipEntity.h` | 66 | 51 | 0 | 0 | — (47 moved → `Core/Tables/OOBehaviour.h`, `OOShipDamageType.h`) |
| `Core/Entities/StationEntity.h` | 5 | 3 | 0 | 0 | — |
| `Core/Entities/WormholeEntity.h` | 3 | 6 | 0 | 0 | — |
| `Core/GameController.h` | 3 | 0 | 0 | 0 | [Mac-only](#maconly) |
| `Core/GuiDisplayGen.h` | 11 | 13 | 75 | 0 | [1 ✅](#guidisplaygen) |
| `Core/HeadUpDisplay.h` | 156 | 3 | 0 | 0 | [1 ✅](#headupdisplay) |
| `Core/Materials/OOConcreteTexture.h` | 1 | 0 | 0 | 0 | — |
| `Core/Materials/OOMaterialSpecifier.h` | 1 | 0 | 0 | 0 | [1 ✅ (28 port-only keys)](#oomaterialspecifier) |
| `Core/Materials/OOPixMap.h` | 1 | 4 | 0 | 5 | — |
| `Core/Materials/OOShaderMaterial.h` | 0 | 6 | 0 | 0 | [2 ✅](#ooshadermaterial) |
| `Core/Materials/OOShaderUniformMethodType.h` | 0 | 20 | 0 | 0 | [1 ⚠️](#ooshaderuniformmethodtype) |
| `Core/Materials/OOTexture.h` | 2 | 33 | 0 | 0 | [2 ✅](#ootexture) (29 moved → `Core/Materials/OOTextureFlags.h`) |
| `Core/Materials/OOTextureInternal.h` | 5 | 0 | 0 | 0 | — |
| `Core/MiniZip/ioapi.h` | 14 | 0 | 0 | 0 | — |
| `Core/MiniZip/unzip.h` | 9 | 0 | 0 | 0 | — |
| `Core/OOALSoundDecoder.h` | 1 | 0 | 0 | 0 | — |
| `Core/OOALSoundMixer.h` | 0 | 1 | 0 | 0 | — |
| `Core/OOAsyncWorkManager.h` | 0 | 3 | 0 | 0 | — |
| `Core/OOBoundingBox.h` | 0 | 0 | 0 | 6 | — |
| `Core/OOCPUInfo.h` | 3 | 0 | 0 | 0 | — (2 moved → `Core/OOCPUInfoEndian.h`, same) |
| `Core/OOCache.h` | 0 | 3 | 0 | 0 | — |
| `Core/OOCommodities.h` | 1 | 0 | 36 | 0 | [2 ✅ (32 keys moved to `.cpp`)](#oocommodities) |
| `Core/OOConstToString.h` | 0 | 3 | 0 | 0 | — |
| `Core/OODebugGLDrawing.h` | 2 | 0 | 0 | 11 | [1 ✅](#oodebugdrawing) |
| `Core/OOFastArithmetic.h` | 0 | 0 | 0 | 0 | — (inlines: math.md) |
| `Core/OOFoundation.h` | 18 | 72 | 0 | 0 | [1 ✅ 2 ➖](#oofoundation) |
| `Core/OOFullScreenController.h` | 8 | 0 | 0 | 0 | [Mac-only](#maconly) |
| `Core/OOFunctionAttributes.h` | 12 | 0 | 0 | 1 | [1 ✅ 1 ➖](#oofunctionattributes) |
| `Core/OOHPVector.h` | 0 | 0 | 0 | 0 | — (inlines: math.md) |
| `Core/OOJoystickManager.h` | 24 | 60 | 0 | 0 | [2 ✅](#oojoystickmanager) |
| `Core/OOJoystickProfile.h` | 3 | 0 | 0 | 0 | — |
| `Core/OOLogging.h` | 8 | 0 | 0 | 0 | [1 ✅ 2 ➖](#oologging) |
| `Core/OOMacroOpenGL.h` | 2 | 0 | 0 | 0 | [Mac-only](#maconly) |
| `Core/OOManifestProperties.h` | 0 | 0 | 24 | 0 | — |
| `Core/OOMaths.h` | 8 | 0 | 0 | 0 | — (8 `M_*` moved → `Core/OOMathsBase.h`, same; inlines: math.md) |
| `Core/OOMatrix.h` | 0 | 0 | 0 | 0 | — (inlines: math.md) |
| `Core/OOMesh.h` | 1 | 1 | 0 | 0 | — |
| `Core/OOMeshToOctreeConverter.h` | 0 | 1 | 0 | 0 | — |
| `Core/OOMouseInteractionMode.h` | 0 | 4 | 0 | 0 | — |
| `Core/OOMusicController.h` | 1 | 4 | 0 | 0 | [Mac-only](#maconly) |
| `Core/OOOXZManager.h` | 0 | 19 | 0 | 0 | [1 ✅](#oooxzmanager) |
| `Core/OOOpenALController.h` | 0 | 0 | 3 | 0 | — |
| `Core/OOOpenGL.h` | 6 | 10 | 0 | 0 | — (5 moved → `Core/OOOpenGLCheck.h`, same) |
| `Core/OOOpenGLExtensionManager.h` | 9 | 0 | 0 | 1 | [2 ✅ (8 moved → `OOOpenGLExtensionPointers.h`, same)](#ooopenglextensionmanager) |
| `Core/OOOpenGLMatrixManager.h` | 0 | 14 | 0 | 0 | — |
| `Core/OOPlanetData.h` | 2 | 0 | 0 | 0 | — |
| `Core/OOPointMaths.h` | 0 | 0 | 0 | 8 | — |
| `Core/OOPriorityQueue.h` | 1 | 0 | 0 | 0 | [1 ➖](#oopriorityqueue) |
| `Core/OOProfilingStopwatch.h` | 4 | 0 | 0 | 1 | [1 ⚠️](#ooprofilingstopwatch) |
| `Core/OOQuaternion.h` | 0 | 0 | 0 | 0 | — (inlines: math.md) |
| `Core/OORegExpMatcher.h` | 0 | 2 | 0 | 0 | [1 ✅](#ooregexpmatcher) |
| `Core/OOShipLibraryDescriptions.h` | 0 | 0 | 16 | 0 | — |
| `Core/OOSound.h` | 1 | 0 | 0 | 0 | — |
| `Core/OOSoundSource.h` | 1 | 0 | 0 | 0 | — |
| `Core/OOStringExpander.h` | 0 | 7 | 0 | 5 | [1 ✅ 1 ➖](#oostringexpander) |
| `Core/OOStringParsing.h` | 0 | 0 | 0 | 3 | [1 ✅](#oostringparsing) |
| `Core/OOSystemDescriptionManager.h` | 5 | 8 | 0 | 0 | — |
| `Core/OOTextureSprite.h` | 2 | 0 | 0 | 0 | — |
| `Core/OOTriangle.h` | 0 | 0 | 0 | 4 | — |
| `Core/OOTrumble.h` | 3 | 19 | 0 | 0 | — |
| `Core/OOTypes.h` | 2 | 99 | 0 | 0 | [1 ✅ 1 ⚠️](#ootypes) (41 moved → `Core/Tables/*.h`) |
| `Core/OOVector.h` | 0 | 0 | 0 | 0 | — (inlines: math.md) |
| `Core/OOVoxel.h` | 6 | 0 | 0 | 0 | — (inlines: math.md) |
| `Core/OXPVerifier/OOOXPVerifier.h` | 1 | 0 | 0 | 0 | — |
| `Core/OXPVerifier/OOPListSchemaVerifier.h` | 0 | 23 | 0 | 1 | — (`kPListError*` → `OOPListSchemaVerifierErrorCode::k*`, same values; the inline compares the same bounds) |
| `Core/Octree.h` | 2 | 1 | 0 | 0 | — |
| `Core/ResourceManager.h` | 5 | 3 | 0 | 0 | — |
| `Core/Scripting/OOConstToJSString.h` | 0 | 0 | 0 | 28 | [1 ✅ 1 ➖](#ooconsttojsstring) |
| `Core/Scripting/OOJSEngineNativeWrappers.h` | 8 | 0 | 0 | 0 | [1 ✅ 1 ⚠️ 1 ➖](#oojsenginenativewrappers) |
| `Core/Scripting/OOJSEngineTimeManagement.h` | 1 | 0 | 0 | 0 | — (`kOOJSLongTimeLimit` moved → `OOJSEngineCore.h`, 5.0) |
| `Core/Scripting/OOJSEntity.h` | 0 | 0 | 0 | 4 | [1 ✅ 1 ➖](#oojsentity) |
| `Core/Scripting/OOJSScript.h` | 0 | 0 | 1 | 0 | — |
| `Core/Scripting/OOJavaScriptEngine.h` | 15 | 0 | 0 | 13 | [3 ✅ 3 ➖ (14 macros moved → `OOJSEngineCore.h`)](#oojavascriptengine) |
| `Core/Universe.h` | 59 | 26 | 0 | 1 | — (30 `KEY_*`/`SHIPYARD_KEY_*` macros became `constexpr` strings, same) |
| `Core/legacy_random.h` | 0 | 0 | 0 | 6 | — |
| `SDL/EXRSnapshotSupport/miniz.h` | 88 | 135 | 0 | 0 | — |
| `SDL/EXRSnapshotSupport/tinyexr.h` | 47 | 4 | 18 | 11 | — |
| `SDL/MyOpenGLView.h` | 23 | 75 | 0 | 0 | — |
| `SDL/OOResourcesWin/OOResourcesWin.h` | 3 | 0 | 0 | 0 | — |
| `SDL/stb_image_write.h` | 3 | 0 | 0 | 0 | — |
| **Total (238 pairs)** | **889** | **966** | **173** | **110** | |

The other 143 pairs have no object-like `#define`, enumerator, constant or non-maths inline function on the upstream side, so there was nothing to compare. They are the same pairs as in the previous run: the `OOJS*` binding headers, the entity subclasses, the material and sound classes, the OXP verifier stages and so on.

**Upstream headers with no port counterpart (28):** `Core/Entities/PlanetEntity.h`, `Core/NSBundle+Override.h`, `Core/NSDataOOExtensions.h`, `Core/NSDictionaryOOExtensions.h`, `Core/NSFileManagerOOExtensions.h`, `Core/NSMutableDictionaryOOExtensions.h`, `Core/NSNumberOOExtensions.h`, `Core/NSObjectOOExtensions.h`, `Core/NSScannerOOExtensions.h`, `Core/NSStringOOExtensions.h`, `Core/NSThreadOOExtensions.h`, `Core/NSUserDefaults+Override.h`, `Core/OOAsyncQueue.h`, `Core/OOCollectionExtractors.h`, `Core/OODeepCopy.h`, `Core/OOEnvironmentCubeMap.h`, `Core/OOExcludeObjectEnumerator.h`, `Core/OOFilteringEnumerator.h`, `Core/OONSOperation.h`, `Core/OOSpatialReference.h`, `Core/OOWeakReference.h`, `Core/OOWeakSet.h`, `Core/OXPVerifier/OOOXPVerifierStageInternal.h`, `Core/OldSchoolPropertyListWriting.h`, `Core/ReleaseLockProxy.h`, `Core/TextureStore.h`, `SDL/Comparison.h`, `SDL/MyOpenGLView+Input.h`. Only four of them carry constants or inline functions; see [Unpaired headers](#unpaired).

---

## Core/Tables (spec 009)

<a id="tables"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOEntityStatus` (20) | `OOEntityStatus.tbl`, `label = value` in `Entity.h:54-58`; default `STATUS_INACTIVE` (318) | `Core/Tables/OOEntityStatus.h`, the same values -10…999 and names, default `kInactive` | ✅ |
| `OOScanClass` (16) | `OOScanClass.tbl`, `label = value` in `Entity.h:65-67`; default `CLASS_NOT_SET` | `Core/Tables/OOScanClass.h:17-34`, the same values, including 444/100/999/333 and their order | ✅ |
| `OOBehaviour` (39) | `OOBehaviour.tbl`, `label = value` in `ShipEntity.h:145-149` | `Core/Tables/OOBehaviour.h`, the same 0…811; no default (none upstream) | ✅ |
| `OOCompassMode` (7) | `label = value`, `OOTypes.h:127-134`; default `COMPASS_MODE_BASIC` | `Core/Tables/OOCompassMode.h`, -1…6, default `kBasic` | ✅ |
| `OOGalacticHyperspaceBehaviour` (4) | `GALACTIC_HYPERSPACE_##label = value`, `PlayerEntity.h:65-71`; names stringified without the prefix (`OOConstToString.m:43`) | `Core/Tables/OOGalacticHyperspaceBehaviour.h:16-21`, 0/1/2/-1, names `"BEHAVIOUR_STANDARD"` …, default `kUnknown` | ✅ |
| `OOGUIScreenID` (29) | `label,` (sequential 0-28; the table's -1 is ignored), `PlayerEntity.h:59-63`; default `GUI_SCREEN_MAIN` | `Core/Tables/OOGUIScreenID.h`, 0-28 in the same order, default `kMain` | ✅ |
| `OOViewID` (8) | `label,` in `OOTypes.h:37-43`; default `VIEW_NONE` | `Core/Tables/OOViewID.h`, the same order, default `kNone` | ✅ |
| `OOLongRangeChartMode` (5) | `label,` in `OOTypes.h:45-49`; default `OOLRC_MODE_UNKNOWN` | `Core/Tables/OOLongRangeChartMode.h`, 0-4, default `kUnknown` | ✅ |
| `OOLegalStatusReason` (17) | `DIFF_STRING_ENTRY(label, string)` → `label,` in `OOTypes.h:139-144`; the names are the strings | `Core/Tables/OOLegalStatusReason.h`, 0-16, `OOEnumName` = `"unknown"` … `"police are clean"` | ✅ |
| `OOShipDamageType` (7) | `DIFF_STRING_ENTRY` → `label,` in `ShipEntity.h:175-180`; default `kOODamageTypeEnergy` | `Core/Tables/OOShipDamageType.h`, 0-6, identical strings, default `kEnergy` | ✅ |

**Differences:**

- ✅ note (new) — `tables_check.py` matched all ten tables entry for entry: values, order, the `OOEnumName()` strings (each the name upstream's `ENTRY` stringified, or the `DIFF_STRING_ENTRY` string), the `MakeEnumTable<>` order, and every `static_assert` pin. Lookups by name are exact and case-sensitive, like upstream's `isEqualToString:` chains — upstream `Core/Tables/*.tbl`, `Core/OOConstToString.m:40-48` ↔ port `Core/Tables/*.h`, `Core/OOEnumTable.h:24-44`
- note — `OOOpenGLStates.tbl` became the `kStateItems` table (spec 011 T004, `e729cc4ec`). Upstream includes it only from `OOOpenGL.m`, so it is not a header item here; see c-and-tables.md.

## Core/Entities/PlayerEntity.h

<a id="playerentity"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `HYPERSPEED_FACTOR` | `[PLAYER hyperspeedFactor]` (295) | `(PLAYER != nullptr ? PLAYER->getHyperspeedFactor() : 0.0f)` (382-383) | ✅ |
| `MANIFEST_SCREEN_ROW_NEXT` | `([[PLAYER hud] isHidden] ? 27 : 20)` (336) | null-guarded, so a nil player or HUD gives 20 (426) | ✅ |
| `FORWARD/AFT/PORT/STARBOARD_FACING_STRING` | `DESC(@"…-facing-string")` (306-309) | `OO_DESC("…-facing-string")` (394-397), same keys | ✅ |
| `GUI_ROW_OPTIONS_*`, `GUI_ROW_GAMEOPTIONS_*` | anonymous enums with `#if` rows (124-211) | `inline constexpr int` chains, one `#if`/`#else` per conditional row; `PROCEDURALLYTEXTUREDPLANETS` dropped (133-255) | ✅ |
| `OOGetPlayer()` inline | `NSCAssert` + `return gOOPlayer` (1285) | `OOCAssert` + `return gOOPlayer` (2090) | ✅ |
| `MARKET_FILTER_MODE_MAX`, `MARKET_SORTER_MODE_MAX` (= 5) | (256, 267); `PlayerEntityControls.m:2438-2448` wraps at `>= MAX` | `kOOMarketFilterModeCount`/`kOOMarketSorterModeCount` = 6 (332, 349); `PlayerEntityControls.cpp:3015-3028` wraps at `v + 1 >= 6` | ✅ |
| `GALACTIC_HYPERSPACE_MAX` | `= …FIXED_COORDINATES` (70); `PlayerEntity.m:11359` | `kOOGalacticHyperspaceBehaviourMax = kFixedCoordinates` (`Core/Tables/OOGalacticHyperspaceBehaviour.h:30-32`); `PlayerEntity.cpp:13525-13526`, the same test | ✅ |

**Differences:**

- ✅ **low** (still open, unchanged) — the two macros that send messages test for null explicitly. They give what ObjC nil-messaging gave (0.0, and `NO`→20) — upstream `Core/Entities/PlayerEntity.h:295`, `:336` ↔ port `Core/Entities/PlayerEntity.h:382`, `:426`
- ✅ note (new) — the row enums became `constexpr int` chains. Read by hand, they have the same rows, the same `OOLITE_SDL`/`OOLITE_SPEECH_SYNTH`/`OO_RESOLUTION_OPTION` conditions and the same HDR aliases. Upstream's `#if GUI_FIRST_ROW() < 0` was a no-op, because enumerators are 0 in the preprocessor; the port's `static_assert`s now really check it — upstream `Core/Entities/PlayerEntity.h:124-211` ↔ port `Core/Entities/PlayerEntity.h:133-255`
- ✅ note (new) — each `…_MAX` enumerator became a count (`v + 1 >= Count` ⇔ `v >= MAX`) or a named alias. The observable wrap points are unchanged.

## Core/Entities/OOStellarBody.h

<a id="oostellarbody"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `NEW_PLANETS` / `STELLAR_TYPE_ATMOSPHERE` | `#define NEW_PLANETS 1` and `#if !NEW_PLANETS STELLAR_TYPE_ATMOSPHERE` (33-46) | the define and the dead enumerator are gone; `OOStellarBodyType::kSun/kNormalPlanet/kMoon/kMiniature` = 0-3 (35-40) | ➖ |

**Differences:**

- ➖ **low** (still open) — the `NEW_PLANETS` switch is gone, and with it the legacy `PlanetEntity` path. The compiled enum values are unchanged; the enumerators are now scoped (T101) — upstream `Core/Entities/OOStellarBody.h:33-46` ↔ port `Core/Entities/OOStellarBody.h:35-40`

## Core/HeadUpDisplay.h

<a id="headupdisplay"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `Z1` | `[(MyOpenGLView*)[[player universe] gameView] display_z]` (217) | `UNIVERSE`→`getGameView()->getDisplay_z()`, 0.0f if null (245) | ✅ |

**Differences:**

- ✅ **low** (still open, unchanged) — nothing uses `Z1` on either side — upstream `Core/HeadUpDisplay.h:217` ↔ port `Core/HeadUpDisplay.h:245`

## Core/Materials/OOShaderUniformMethodType.h

<a id="ooshaderuniformmethodtype"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOShaderUniformType` | enum `… Point=17, Object=18, Count=19` (56-57) | `using OOShaderUniformType = int` constants `… Point=17, Color=18, Object=19, Count=20` (45-87, pinned at 106-107) | ⚠️ |

**Differences:**

- ⚠️ **low** (still open) — `kOOShaderUniformTypeColor` is inserted before `Object`, which shifts `Object` and `Count` by one. The values are used only inside the process (binding tables, switches, an array bound) and are never saved or sent to shaders. The code comment documents the change ("Binding only: the C++ colour (OOColor *)"); `c3d79d42f` removed the bead id oo-9ht.1 from the comment — upstream `Core/Materials/OOShaderUniformMethodType.h:37-60` ↔ port `Core/Materials/OOShaderUniformMethodType.h:82-87`

## Core/Materials/OOMaterialSpecifier.h

<a id="oomaterialspecifier"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| 28 material keys (`kOOMaterialDiffuseColorName` … `kOOMaterialLightMapsName`) | `extern` in the header; values in `Core/Materials/OOMaterialSpecifier.m:35-68` | `inline constexpr const char* k…` (79-118), now without `cxx_` (T107) | ✅ |

**Differences:**

- ✅ **low** (still open, renamed) — all 28 strings are identical, checked by script against the `.m` and by eye, and so are the legacy aliases.

## Core/Materials/OOTexture.h

<a id="ootexture"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| 16 texture-specifier keys (`kOOTextureSpecifierNameKey` … `BindingKey`) | `extern`; values in `Core/Materials/OOTexture.m:44-60` | `inline constexpr const char*` (297-316), no `cxx_` | ✅ |
| `kOOTexture*` option flags (29, an anonymous enum + `typedef uint32_t OOTextureFlags`) | `OOTexture.h` (0x1 … 0x700000, masks and derived sets) | `enum class OOTextureFlags : std::uint32_t` in `Core/Materials/OOTextureFlags.h:37-…`; every value equal, including `kFlagsMask` = ~7 and `kDefinedFlags` = 0x703FF7 | ✅ |

**Differences:**

- ✅ **low** — the strings are identical, including the case of `"texture_LOD_bias"`.
- ✅ note (new) — the flags are now scoped (spec 009/T101). The script matched all 29 to upstream's values.

## Core/Materials/OOShaderMaterial.h

<a id="ooshadermaterial"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| 9 config keys (`kOOVertexShaderSourceKey` … `kOOIsSynthesizedMaterialMacrosKey`) | `NSString* const` in `Core/Materials/OOShaderMaterial.m:46-54` | `inline constexpr const char*` in the header (212-223) | ✅ |
| `kOOUniformConvert*`, `kOOUniformBindToSuperTarget` (anonymous enum) | 1, 2, 4, 8; defaults 12 | `enum class OOUniformConvertOptions : std::uint16_t` (49-…), same bits | ✅ |

## Core/GuiDisplayGen.h

<a id="guidisplaygen"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| 75 GUI-settings keys (`kGuiDefaultTextColor` … `kGuiDockingContinueColor`) | `static NSString* const` (67-152) | `inline constexpr const char* kGui…` (112-234), with the `cxx_` prefix dropped (T107) | ✅ |

**Differences:**

- ✅ **low** (still open, renamed) — the names now equal upstream's. Every key string is identical, including the format keys `"chart_economy_%zu_color"` and `"chart_government_%zu_color"`.

## Core/OOCommodities.h

<a id="oocommodities"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| 32 commodity/market keys (`kOOCommodityName` … `kOOCommodityMarketTypeValueGood`) | `static NSString* const` in the header (32-74) | `constexpr std::string_view` in `Core/OOCommodities.cpp:57-…` | ✅ |
| `kOOCommodityTrumbleOpinion`, `…SortOrder`, `…Comment`, `…ShortComment` | header (49-54); used only by `OOCommodityMarket.m` | `kTrumbleOpinion`, `kSortOrder`, `kComment`, `kShortComment` in `Core/OOCommodityMarket.cpp:40-44` | ✅ |

**Differences:**

- ✅ **low** (still open, unchanged) — the keys became file-local, and the four used only by the market were renamed. All 36 strings are identical, and so are the defaults read with them (`"[oolite-commodity-no-comment]"`) — upstream `Core/OOCommodityMarket.m:163` ↔ port `Core/OOCommodityMarket.cpp:159`

## Core/OOFoundation.h

<a id="oofoundation"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `NSUpArrowFunctionKey` … `NSModeSwitchFunctionKey` (72 enumerators, 0xF700-0xF747) | GNUstep fallback enum (127-198) | gone | ➖ |
| `NSOrdered*` / `OOComparisonResult` | (`NSOrdered*` from Foundation, -1/0/1) | `enum class OOComparisonResult : std::ptrdiff_t { kAscending = -1, kSame, kDescending }`, pinned (162-170) | ✅ |
| ObjC/Cocoa switches: `OOLITE_GNUSTEP`, `OOLITE_MAC_OS_X`, `true`/`false`, `IBOutlet`/`IBAction`, `OOLITE_PROPERTY_SYNTAX`, `OOLITE_RELEASE_PLIST_ERROR_STRINGS`; the `BOOL`→`WinBOOL` shim | (51-279; `BOOL` from gnustep-base) | gone with the Objective-C runtime (`74a2dd118`); an undefined name in `#if` is 0, the SDL value | ➖ |

**Differences:**

- ➖ **low** (still open) — no upstream `.m` used the AppKit function-key enum. Keys come from SDL key codes on both sides.
- ➖ **low** (new) — on GNUstep/SDL the platform macros were 0 or C keywords that C++ has natively, so dropping them changes no compiled branch. `OOOrdered*`, which the previous run marked ✅ as `inline constexpr`, is now the scoped `OOComparisonResult` with the same values — upstream `Core/OOFoundation.h:50-279` ↔ port `Core/OOFoundation.h:162-170`

## Core/OOLogging.h

<a id="oologging"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOLOG_ERROR_PREFIX`, `OOLOG_WARNING_PREFIX` | `@"***** ERROR: "`, `@"----- WARNING: "` (122-123) | `kErrorPrefix`/`kWarningPrefix` `oofnd/Log.hpp:527-528`; `kSyntaxIssuePrefix` `Core/OOStringExpander.cpp:250` | ✅ |
| `OODebugLog`, `OOExtraLog` | `OOLog` under `#if OO_DEBUG` / `#ifndef NDEBUG`, otherwise a no-op (154, 166) | each call site wrapped in the same guard around `OO_LOG` (for example `Core/OOCacheManager.cpp:141-153`) | ➖ |
| `OOLOG_POISON_NSLOG` | `0` (36) | gone (no `NSLog` exists) | ➖ |

**Differences:**

- ➖ **low** (still open) — the debug-only log macros were inlined as preprocessor guards. The sites I checked have the same message class and text — upstream `Core/OOCacheManager.m:155` ↔ port `Core/OOCacheManager.cpp:141-153`

## Core/OOPriorityQueue.h

<a id="oopriorityqueue"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OO_PQ_STRONG` | `__strong` GC qualifier (43-45) | gone (standard ownership) | ➖ |

## Core/OOProfilingStopwatch.h

<a id="ooprofilingstopwatch"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OO_PROFILING_STOPWATCH_JS_NOW` / `OOGetHighResTime` on Windows | when not standalone, `JS_Now()`: microseconds, calibrated against the performance counter (75-85) | `timeGetTime`, `DWORD` milliseconds: upstream's standalone branch (65-89) | ⚠️ |

**Differences:**

- ⚠️ **low** (still open, changed since 2026-10-27) — the previous run found a `steady_clock` microsecond count. On this branch the Windows clock is `timeGetTime()`, so Windows profiling has millisecond resolution. That affects the totals of the JS profiler's `profile()`/`getProfile()` and the OOMesh/OOCacheManager timing logs; Linux keeps `gettimeofday`, and the JS time limiter does not use this clock. Commit `c66ff5259` (#580: "removes the JS_Now() profiling stopwatch") documents the change, and the port keeps upstream's comment on the lower resolution — upstream `Core/OOProfilingStopwatch.h:70-86` ↔ port `Core/OOProfilingStopwatch.h:65-89`

## Core/OORegExpMatcher.h

<a id="ooregexpmatcher"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `kOORegExpCaseInsensitive`, `kOORegExpMultiLine` | `JSREG_FOLD` (0x01), `JSREG_MULTILINE` (0x04) (40-41) | `OORegExpFlags::kCaseInsensitive = 0x01`, `kMultiLine = 0x04` (62-66), turned into the `"i"`/`"m"` flag string for QuickJS (`Core/OORegExpMatcher.cpp:109-110`) | ✅ |

**Differences:**

- ✅ note (changed) — the previous run mapped these to an `ooscript::` façade. The façade is gone, and the flags now build a QuickJS flag string: same values, same two flags.

## Core/Scripting/OOJSEngineNativeWrappers.h

<a id="oojsenginenativewrappers"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOJS_NATIVE_EXIT` | `@catch (id exception) { OOJSReportWrappedException(...); return NO; }` (96-103) | `catch (...) { OOJSReportCurrentException(...); return JS_EXCEPTION; }` (142-148, 159-165) | ⚠️ |
| `OOJS_PROFILE_ENTER(_NAMED)`/`_EXIT(_VOID)`, `OOJS_BEGIN/END_FULL_NATIVE` | `@try … @finally { OOJSProfileExit / JS_ResumeRequest; OOJSResumeTimeLimiter }` (53-70, 129-150) | RAII `OOJSProfileScope` / `OOJSFullNativeScope`, with the calls in the same order; QuickJS has no request to suspend (116-135, 178-202) | ✅ |
| `OOJS_PROFILE_EXIT_VAL`, `OOJS_PROFILE_EXIT_JSVAL`, `OOJS_PROFILE_ENTER_FOR_NATIVE`, `OOJSUnreachable` | after the block, `OOJSUnreachable(…)` then `return rval` (62-91, 109-113) | gone; `OOJS_PROFILE_EXIT` just closes the scopes (133-135, 153) | ➖ |

**Differences:**

- ⚠️ **low** (still open) — `catch (...)` is wider than `@catch (id)`. Any C++ exception escaping a native, including `std::bad_alloc`, becomes a JS error ("Native exception: <what()>" or "Unidentified native exception"). The header comment documents this (102-109) — upstream `Core/Scripting/OOJSEngineNativeWrappers.h:96-103` ↔ port `Core/Scripting/OOJSEngineNativeWrappers.h:142-165`
- ➖ **low** (new) — when a native fell off the end of an `OOJS_…_ENTER/EXIT` pair, upstream trapped it with `OOJSUnreachable()`, which logs and aborts in debug builds. The port relies on the compiler's missing-return warning, since the build is warning-free; a fall-through would be undefined behaviour at run time instead of a logged abort. The header comment (17-22) still mentions `OOJS_PROFILE_EXIT_VAL`, which no longer exists — upstream `Core/Scripting/OOJSEngineNativeWrappers.h:62-91` ↔ port `Core/Scripting/OOJSEngineNativeWrappers.h:133-153`

## Core/Scripting/OOJavaScriptEngine.h

<a id="oojavascriptengine"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOJS_PROP_READWRITE` … `OOJS_PROP_HIDDEN_READONLY_CB`, `OOJS_METHOD_READONLY` (9 macros) | `JSPROP_PERMANENT`/`ENUMERATE`/`READONLY`/`SHARED` combinations (606-621) | `Core/Scripting/OOJSEngineCore.h:649-659`, as QuickJS flags: permanent = no `JS_PROP_CONFIGURABLE`, `ENUMERATE` → `JS_PROP_ENUMERABLE`, not `READONLY` → `JS_PROP_WRITABLE`. The `_CB` (shared, accessor) forms carry only enumerability; whether there is a setter decides writability (`OOJS_PROPERTY_RW/RO`, 674-679) | ✅ |
| `OOJS_THIS`, `OOJS_ARGV`, `OOJS_RETURN_VOID`, `OOJS_RETURN_NULL` | `JS_THIS_OBJECT(context, vp)` … `OOJS_RETURN(JSVAL_NULL)` (624-636) | `oojsThis`, `oojsArgv` (native parameters), `OOJS_RETURN(JS_UNDEFINED)`, `OOJS_RETURN(JS_NULL)` (`OOJSEngineCore.h:590-605`) | ✅ |
| inlines `OOJSAcquireContext`, `OOJSRelinquishContext`, `OOJSValueFromBOOL`, `OOJSValueIsUndefined`, `OOJSValueFromDouble`, `OOJSValueIsFunction`, `OOJSValueIsArray`, `OOJSIsMemberOfSubclass` | (116-374) | `OOJSEngineCore.h:105-417`: the same assert; no request begin/end; `JS_NewBool(b != 0)`; `JS_NewNumber`; `JS_IsFunction`/`JS_IsArray` (false for non-objects, like upstream's null guard); a `JS_IsObject` guard before the class test | ✅ |
| `OOJSValueFromNativeObject()` inline | `[object oo_jsValueInContext:]`, or `JSVAL_NULL` for nil (229) | gone; callers use the entity's `jsValueInContext()` with an explicit `JS_NULL` for null (for example `Core/Scripting/EntityOOJavaScriptExtensions.cpp:73`) | ➖ |
| `OOJSValueToBOOL`, `OOJSValueToInt32`, `OOJSReportPendingException`, `OOJSGetClass` inlines | `JS_ValueToBoolean`, `JS_ValueToInt32`, `JS_ReportPendingException`, `JS_GET_CLASS` (162-176, 346) | out of line in `Core/Scripting/OOJavaScriptEngine.cpp:598-620, 840-…` (declared at `OOJSEngineCore.h:128-…`). `ToInt32` re-implements SpiderMonkey's `floor(d + 0.5)` and range error; `JS_GetClassID` replaces `OOJSGetClass` | ➖ |
| `OOJS_RVAL` | `JS_RVAL(context, vp)` (666) | gone: natives return their value | ➖ |

**Differences:**

- ✅ note (changed) — the previous run checked these flags against an `ooscript::PropertyFlag` façade. This branch uses QuickJS-ng directly (`88c674cbb`, `c66ff5259`). I re-checked the flags by hand against QuickJS's meanings: property enumerability and read-only behaviour are the same.
- ➖ **low** (new) — the value-conversion helpers have left the header, and their bodies belong to [scripting.md](scripting.md). What I compared: `OOJSValueToBOOL` returns false on a conversion exception (upstream `NO`); `OOJSValueToInt32` rounds half up and reports "can't convert … to an integer" outside the int32 range, as SpiderMonkey 1.8.5's `JS_ValueToInt32` did — upstream `Core/Scripting/OOJavaScriptEngine.h:162-176` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:598-620`

## Core/Scripting/OOJSEntity.h

<a id="oojsentity"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `JSEntityClass()`, `JSEntityPrototype()` inlines | `return &gOOEntityJSClass;` / `return gOOEntityJSPrototype;` (42-43) | replaced by the out-of-line `JSEntityClassID()` (`Core/Scripting/OOJSEntity.cpp:146`), a QuickJS class id | ➖ |
| `OOIsStaleEntity()` inline | `entity == nil` or `entity == gOOJSPlayerIfStale` (69) | `entity == nullptr` or (`gOOJSPlayerIfStale != nullptr` and `entity == gOOJSPlayerIfStale`) (140-143) | ✅ |

**Differences:**

- ✅ note (still open, unchanged) — the extra `gOOJSPlayerIfStale != nullptr` test is redundant once `entity` is non-null.

## Core/Scripting/OOConstToJSString.h

<a id="ooconsttojsstring"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOJSValueFrom<Const>()` (8) and `OO<Const>FromJSValue()` (6) inlines | `STRING_TO_JSVAL(OOJSStringFrom<Const>(…))`; `OOConstantFromJSValuePRIVATE(…, k…Default)` (54-245) | `OOJSValueFromConstantPRIVATE(context, oo::ToUnderlying(value), &g…ConstTable)`; `static_cast<…>(OOConstantFromJSValuePRIVATE(…, oo::ToUnderlying(k…Default)))` (64-197) | ✅ |
| `OOJSStringFrom<Const>()` (8) and `OO<Const>FromJSString()` (6) inlines | `JSString*` variants (54-245) | gone, because QuickJS has no `JSString` type (comment 46-50); callers use the `JSValue` forms | ➖ |

**Differences:**

- ✅ note — the const tables and the `k…Default` fallbacks are the same; all ten defaults are checked in [Tables](#tables). [scripting.md](scripting.md) covers the PRIVATE helpers.
- ➖ **low** (new) — the `JSString` variants are gone. The value forms return the same strings.

## Core/OODebugGLDrawing.h

<a id="oodebugdrawing"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OODebugDrawBoundingBoxBetween`, `OODebugDrawNormal`, `OODebugDrawVector`, `OODebugDrawLine` | `[OOColor blueColor]`, `cyanColor`, `magentaColor`, `whiteColor` (77-125) | `OOColor::blueColor().get()` etc. (85-127); the temporary `shared_ptr` lives until the end of the call | ✅ |

## Core/OOFunctionAttributes.h

<a id="oofunctionattributes"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOConsumeReference()` inline | identity on an `id`, for the static analyser (123) | gone with the Objective-C runtime | ➖ |
| `OOINLINE` | `static inline` | `inline` | ✅ |

**Differences:**

- ✅ note (new) — `inline` instead of `static inline` only changes linkage: one definition instead of one per translation unit. None of these inlines has a `static` local.

## Core/OOOpenGLExtensionManager.h

<a id="ooopenglextensionmanager"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOShadersSupported()` inline | `[[OOOpenGLExtensionManager sharedManager] shadersSupported]` (180) | `OOOpenGLExtensionManager::sharedManager()->shadersSupported()` (167) | ✅ |
| `OOOPENGLEXTMGR_LOCK_SET_ACCESS` | `(!OOLITE_MAC_COCOA_UI)`, which is 1 on SDL (107); an `NSLock` around the extension-set lookup | always on: `std::mutex lock` (132), `lock()`/`unlock()` at `OOOpenGLExtensionManager.cpp:433-437` | ✅ |

**Differences:**

- ✅ note — the 8 Windows extension-pointer macros are still in `Core/OOOpenGLExtensionPointers.h` with identical values.

## Core/OOStringExpander.h

<a id="oostringexpander"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOCastParamObject/SignedInteger/UnsignedInteger/Float/Double` + `OO_CAST_PARAMETER` (`__builtin_choose_expr` dispatch) | `NSNumber numberWithLongLong/UnsignedLongLong/Float/Double`, or the object as is (169-219) | `OOCastParam` overload set (373-…), used by the macro at 371 | ➖ |
| `kOOExpand*` option flags (7) | anonymous enum, 0x01…0x20, `kOOExpandNoOptions = 0` (31-40) | `enum class OOExpandOptions : std::size_t`, the same bits, `kNone = 0` (37-50) | ✅ |

**Differences:**

- ➖ **low** (still open) — the overload set keeps the four numeric kinds (signed and unsigned 64-bit, float, double). `char` and `bool` go to the signed branch, as upstream's `char`/`BOOL` did. Enums are promoted to their underlying integer, where upstream's macro rejected them at compile time — upstream `Core/OOStringExpander.h:169-219` ↔ port `Core/OOStringExpander.h:371-…`

## Core/OOStringParsing.h

<a id="oostringparsing"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOStringFromIntCredits`, `OOCredits`, `OOIntCredits` inlines | `OOStringFromDeciCredits(n * 10, NO, sym)` / `(n, YES, YES)` / `(n, YES)` (52-64) | the same arguments, returning `std::string`, now without `cxx_` (84-93) | ✅ |

## Core/OOTypes.h

<a id="ootypes"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOMassUnit` | `UNITS_TONS, UNITS_KILOGRAMS, UNITS_GRAMS` (0-2) (111-115) | `enum class OOMassUnit { kTons, kKilograms, kGrams, kUnknown }` (161-166) | ⚠️ |
| `VALID_WEAPON_FACINGS`, `DETAIL_LEVEL_MAXIMUM` | a `#define` of the five facings = 0x0F (206); an enumerator `= 3` (214) | `kOOValidWeaponFacings` (301-303), the same OR; `kOOGraphicsDetailMaximum = kExtras` (317-318) | ✅ |

**Differences:**

- ⚠️ **low** (still open) — the new enumerator is appended, so no existing value moves. A `quantity_unit` outside 0-2 maps to `kUnknown` and displays "??" (`Core/OOCommodities.h:42-50`, `Core/OOConstToString.cpp:390-395`). Upstream's bare cast was undefined, and its switch also fell through to `@"??"` (`Core/OOConstToString.m:482-490`). The comment at `Core/OOCommodities.h:42-44` documents the change; ADR-0036, which the previous run cited, is not in this worktree — upstream `Core/OOTypes.h:111-115` ↔ port `Core/OOTypes.h:161-166`
- ✅ note (new) — the `VALID_WEAPON_FACINGS` uses apply the same masks: upstream `ShipEntity.m:298`, `PlayerEntity.m:8201` ↔ port `ShipEntity.cpp:672`, `PlayerEntity.cpp:9730`.

## Core/OOJoystickManager.h

<a id="oojoystickmanager"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `AXIS_*` (8), `BUTTON_*` (58) | anonymous enums with `OO_FOV_INFLIGHT_CONTROL_ENABLED` rows | `inline constexpr int` chains with the same `#if`/`#else`, pinned by `static_assert` for both settings (75-174) | ✅ |
| `JOYAXISMOTION` … `JOYBUTTON_RELEASED` (port-only aliases) | (none; `SDL/OOSDLJoystickManager.m` uses `SDL_EVENT_JOYSTICK_*` directly) | gone; `SDL/OOSDLJoystickManager.cpp:125-152` uses the SDL3 constants directly too | ✅ |

**Differences:**

- ✅ note (fixed since 2026-10-27) — the port-only alias enum that the previous run listed no longer exists, so the header now has the same set of names as upstream.

## Core/OOOXZManager.h

<a id="oooxzmanager"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OXZInstallableState` (8 enumerators) | private enum in `Core/OOOXZManager.m:75-86` | `enum class OXZInstallableState` in the header (97-…), the same order, pinned 0-7 | ✅ |

## Core/Debug/OODebugTCPConsoleProtocol.h

<a id="oodebugtcpconsoleprotocol"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOTCP_ENCODE_VERSION` / `kOOTCPProtocolVersion_1_1_0` | a macro that shifts the format, not the major number, into bits 8-15 (300-315) | `constexpr OOTCPEncodeVersion` with the same slip kept (311-316); `static_assert(kOOTCPProtocolVersion_1_1_0 == 0x00010100)` (329-331) | ✅ |

**Differences:**

- ✅ note (new) — the port keeps upstream's encoder bug on purpose (comment at 309-310), so the wire value 0x00010100 is unchanged.

## Mac-only switches

<a id="maconly"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OO_USE_FULLSCREEN_CONTROLLER` (`GameController.h`), `CGL_MACRO_CACHE_RENDERER` (`OOMacroOpenGL.h`), `kOODisplayBitsPerPixel`/`IOFlags` (`OOFullScreenController.h`), `OOTCPSTREAM_USE_COREFOUNDATION`, `OOLITE_ITUNES_SUPPORT` | all `OOLITE_MAC_COCOA_UI` / CoreGraphics forms, 0 or absent on SDL | gone; the port has the SDL branches (`OO_ENTER_OPENGL()` as an empty statement, `kOOMusicModeMax = kOn`) | ➖ |

## Unpaired headers

<a id="unpaired"></a>

| Upstream header | Constants / inlines | Where they went | Verdict |
|---|---|---|---|
| `Core/NSFileManagerOOExtensions.h` | `SAVEDIR "oolite-saves"`, `SNAPSHOTDIR "snapshots"` (33, 36) | the same `#define`s in `SDL/MyOpenGLView.cpp:51-52`; `oofnd/ResourcePaths.hpp:178` uses the same default | ✅ |
| `Core/OOCollectionExtractors.h` | inlines `OOClampInteger`, `OOIntegerFromObject`, `OOUIntegerFromObject` | `oofnd/PListGet.hpp` (audited in [foundation.md](foundation.md)) | ✅ |
| `Core/OONSOperation.h` | `OO_HAVE_NSOPERATION`, `OO_ALLOW_NSOPERATION`, `OONSOperationQueuePriority*` (-8…8), 3 class-getter inlines | gone; `OOAsyncWorkManager` owns its own queue (`3616632fa`) | ➖ |
| `Core/Entities/PlanetEntity.h` | `MAX_TRI_INDICES`, `MAX_PLANET_VERTICES` (39-40) | gone; the whole header was `#if !NEW_PLANETS`, which upstream compiles out | ➖ |
| the other 24 (NS…Extensions, `OOWeakReference`, `OODeepCopy`, `TextureStore`, `SDL/Comparison.h`, …) | none (only include guards) | — | ➖ |
