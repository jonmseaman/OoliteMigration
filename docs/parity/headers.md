# Parity findings: header constants sweep

`#define`s, enums, `static const` values and inline functions in paired `.h` files, compared upstream ↔ port.

Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

**Status:** done — 46 items: 30 ✅ 4 ⚠️ 0 ❌ 12 ➖

**Method.** A script (`.agent-tmp/header_consts.py`, not committed) paired each upstream `src/<path>.h` with the port's `src/<path>.h` or `.hpp`: 238 pairs, and 28 upstream headers with no counterpart. For each header it:

- stripped comments and joined `\` continuations;
- expanded the `.tbl` X-macro includes (`ENTRY(label, value)`, `DIFF_STRING_ENTRY`) inside enum bodies;
- evaluated `#if`/`#ifdef`/`#elif`/`#else` where the result could be decided from macros defined earlier in the same file, plus the upstream build's `OOLITE_MAC_OS_X=0`, `OOLITE_SDL=1`, `GNUSTEP=1` and `NEW_PLANETS=1` (that last one comes from `OOStellarBody.h`). Where a condition could not be decided, it kept every branch as an alternative;
- extracted object-like `#define NAME value`, every enumerator (implicit values computed, initialisers evaluated against earlier enumerators and macros), and namespace-scope `const`/`constexpr`/`static const` scalars and strings that have initialisers.

Before comparing it normalised the values: `@"x"`→`"x"`, `YES`/`NO`→`true`/`false`, `nil`/`NULL`/`nullptr`, float and integer suffixes, whitespace and redundant outer parentheses. It compared numerically wherever an expression could be evaluated.

A name missing from its paired header was then looked up in every other port header ("moved") and in the port's `.cpp` files. A port-only name was looked up in the upstream `.m` files: upstream declared many keys `extern` in the header and defined them in the implementation. The port's `cxx_` prefix was stripped before matching.

Inline functions (`OOINLINE`, `static inline`, `inline`, `NS_INLINE`) were extracted from every upstream header and their bodies compared after normalisation. That skips the maths headers covered by [math.md](math.md): `OOMaths`, `OOFastArithmetic`, `OOVector`, `OOHPVector`, `OOQuaternion`, `OOMatrix` and `OOVoxel`. I read every differing or missing body by hand, on both sides.

Script artefacts that turned out to be false positives, and are not listed as items:
- `OOStellarBody`'s `STELLAR_TYPE_ATMOSPHERE` and `PlayerEntity`'s `GUI_ROW_GAMEOPTIONS_PROCEDURALLYTEXTUREDPLANETS`. Both sit under `#if !NEW_PLANETS`, which upstream compiles out, so the later enumerators have the same values on both sides.
- `OO_PROFILING_STOPWATCH_GETTIMEOFDAY`, which is present in the port.
- `OOVoxel`'s `CUBE_FACE_*`, which are identical.
- `OOFullScreenController`'s `kOODisplay*`, whose upstream `kCGDisplay*` forms are Mac-only.

## Summary

Totals: 238 pairs; 857 `#define`s, 948 enumerator values and 173 constants compared by name and value; 105 non-maths inline functions compared by body.

- **Value differences:** none in any numeric value, string key or enum order, apart from the ⚠️ items below. The only enum renumbering is `kOOShaderUniformTypeObject`/`kOOShaderUniformTypeCount` (+1); the type is internal and never persisted.
- **Moved, values identical:** 106 names now live in a different port header: `OOEntityEnums.h` (78, from `Entity.h`, `PlayerEntity.h` and `ShipEntity.h`), `OOJSEngineCore.h` (14), `OOOpenGLExtensionPointers.h` (8), `OOOpenGLCheck.h` (4) and `OOCPUInfoEndian.h` (2). The moved `OOJS_*` macros map JSAPI flags onto `ooscript` flags with the same bit values.
- **New port names that shadow upstream ones:** the 119 `cxx_k…` string keys in `GuiDisplayGen.h`, `OOMaterialSpecifier.h` and `OOTexture.h`, and 9 keys in `OOShaderMaterial.h`. All of them equal upstream's values character for character.

| Header pair (upstream → port, under `src/`) | #defines | #enum values | #consts | #inlines | Differences |
|---|---:|---:|---:|---:|---|
| `Core/AI.h` | 1 | 0 | 0 | 0 | — |
| `Core/CollisionRegion.h` | 3 | 0 | 0 | 0 | — |
| `Core/Debug/OODebugFlags.h` | 2 | 11 | 0 | 0 | — |
| `Core/Debug/OODebugTCPConsoleClient.h` | 0 | 6 | 0 | 0 | — |
| `Core/Debug/OODebugTCPConsoleProtocol.h` | 23 | 6 | 0 | 0 | — |
| `Core/Debug/OOTCPStreamDecoderAbstractionLayer.h` | 1 | 0 | 0 | 0 | — |
| `Core/Entities/DustEntity.h` | 2 | 0 | 0 | 0 | — |
| `Core/Entities/Entity.h` | 5 | 38 | 0 | 0 | — (38 moved → `Core/OOEntityEnums.h`, same) |
| `Core/Entities/OOBreakPatternEntity.h` | 2 | 2 | 0 | 0 | — |
| `Core/Entities/OOExhaustPlumeEntity.h` | 0 | 1 | 0 | 0 | — |
| `Core/Entities/OOParticleSystem.h` | 0 | 2 | 0 | 0 | — |
| `Core/Entities/OOStellarBody.h` | 3 | 4 | 0 | 0 | [1 ➖](#oostellarbody) |
| `Core/Entities/OOSunEntity.h` | 6 | 0 | 0 | 0 | — |
| `Core/Entities/PlayerEntity.h` | 71 | 129 | 0 | 1 | [5 ✅ (32 more moved → `Core/OOEntityEnums.h`, same)](#playerentity) |
| `Core/Entities/PlayerEntityContracts.h` | 25 | 0 | 0 | 0 | — |
| `Core/Entities/PlayerEntityKeyMapper.h` | 24 | 0 | 0 | 0 | — |
| `Core/Entities/PlayerEntityLegacyScriptEngine.h` | 0 | 13 | 0 | 0 | — |
| `Core/Entities/PlayerEntityLoadSave.h` | 13 | 0 | 0 | 0 | — |
| `Core/Entities/PlayerEntityStickMapper.h` | 12 | 0 | 0 | 0 | — |
| `Core/Entities/ShipEntity.h` | 66 | 51 | 0 | 0 | — (8 moved → `Core/OOEntityEnums.h`, same) |
| `Core/Entities/StationEntity.h` | 5 | 3 | 0 | 0 | — |
| `Core/Entities/WormholeEntity.h` | 3 | 6 | 0 | 0 | — |
| `Core/GameController.h` | 3 | 0 | 0 | 0 | — |
| `Core/GuiDisplayGen.h` | 11 | 13 | 75 | 0 | [1 ✅ (75 keys renamed `cxx_`)](#guidisplaygen) |
| `Core/HeadUpDisplay.h` | 156 | 3 | 0 | 0 | [1 ✅](#headupdisplay) |
| `Core/Materials/OOConcreteTexture.h` | 1 | 0 | 0 | 0 | — |
| `Core/Materials/OOMaterialSpecifier.h` | 1 | 0 | 0 | 0 | [1 ✅ (28 new `cxx_` keys)](#oomaterialspecifier) |
| `Core/Materials/OOPixMap.h` | 1 | 4 | 0 | 5 | — |
| `Core/Materials/OOShaderMaterial.h` | 0 | 6 | 0 | 0 | [1 ✅ (9 keys moved in from `.m`)](#ooshadermaterial) |
| `Core/Materials/OOShaderUniformMethodType.h` | 0 | 20 | 0 | 0 | [1 ⚠️](#ooshaderuniformmethodtype) |
| `Core/Materials/OOTexture.h` | 2 | 33 | 0 | 0 | [1 ✅ (16 new `cxx_` keys)](#ootexture) |
| `Core/Materials/OOTextureInternal.h` | 5 | 0 | 0 | 0 | — |
| `Core/MiniZip/ioapi.h` | 14 | 0 | 0 | 0 | — |
| `Core/MiniZip/unzip.h` | 9 | 0 | 0 | 0 | — |
| `Core/OOALSoundDecoder.h` | 1 | 0 | 0 | 0 | — |
| `Core/OOALSoundMixer.h` | 0 | 1 | 0 | 0 | — |
| `Core/OOAsyncWorkManager.h` | 0 | 3 | 0 | 0 | — |
| `Core/OOBoundingBox.h` | 0 | 0 | 0 | 6 | — |
| `Core/OOCPUInfo.h` | 3 | 0 | 0 | 0 | — (2 moved → `Core/OOCPUInfoEndian.h`, same) |
| `Core/OOCache.h` | 0 | 3 | 0 | 0 | — |
| `Core/OOCommodities.h` | 1 | 0 | 36 | 0 | [2 ✅ (36 keys moved to `.cpp`)](#oocommodities) |
| `Core/OOConstToString.h` | 0 | 3 | 0 | 0 | — |
| `Core/OODebugGLDrawing.h` | 2 | 0 | 0 | 11 | [1 ✅](#oodebugdrawing) |
| `Core/OOFastArithmetic.h` | 0 | 0 | 0 | 0 | — (inlines: math.md) |
| `Core/OOFoundation.h` | 18 | 72 | 0 | 0 | [2 ✅ 1 ➖](#oofoundation) |
| `Core/OOFullScreenController.h` | 8 | 0 | 0 | 0 | — |
| `Core/OOFunctionAttributes.h` | 12 | 0 | 0 | 1 | [1 ➖](#oofunctionattributes) |
| `Core/OOHPVector.h` | 0 | 0 | 0 | 0 | — (inlines: math.md) |
| `Core/OOJoystickManager.h` | 24 | 60 | 0 | 0 | [1 ✅](#oojoystickmanager) |
| `Core/OOJoystickProfile.h` | 3 | 0 | 0 | 0 | — |
| `Core/OOLogging.h` | 8 | 0 | 0 | 0 | [1 ✅ 2 ➖](#oologging) |
| `Core/OOMacroOpenGL.h` | 1 | 0 | 0 | 0 | — |
| `Core/OOManifestProperties.h` | 0 | 0 | 24 | 0 | — |
| `Core/OOMaths.h` | 8 | 0 | 0 | 0 | — (inlines: math.md) |
| `Core/OOMatrix.h` | 0 | 0 | 0 | 0 | — (inlines: math.md) |
| `Core/OOMesh.h` | 1 | 1 | 0 | 0 | — |
| `Core/OOMeshToOctreeConverter.h` | 0 | 1 | 0 | 0 | — |
| `Core/OOMouseInteractionMode.h` | 0 | 4 | 0 | 0 | — |
| `Core/OOMusicController.h` | 1 | 4 | 0 | 0 | — |
| `Core/OOOXZManager.h` | 0 | 19 | 0 | 0 | [1 ✅](#oooxzmanager) |
| `Core/OOOpenALController.h` | 0 | 0 | 3 | 0 | — |
| `Core/OOOpenGL.h` | 5 | 10 | 0 | 0 | — (4 moved → `Core/OOOpenGLCheck.h`, same) |
| `Core/OOOpenGLExtensionManager.h` | 9 | 0 | 0 | 1 | [1 ✅ (8 moved → `OOOpenGLExtensionPointers.h`, same)](#ooopenglextensionmanager) |
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
| `Core/OOStringExpander.h` | 0 | 7 | 0 | 5 | [1 ➖](#oostringexpander) |
| `Core/OOStringParsing.h` | 0 | 0 | 0 | 3 | [1 ✅](#oostringparsing) |
| `Core/OOSystemDescriptionManager.h` | 5 | 8 | 0 | 0 | — |
| `Core/OOTextureSprite.h` | 2 | 0 | 0 | 0 | — |
| `Core/OOTriangle.h` | 0 | 0 | 0 | 4 | — |
| `Core/OOTrumble.h` | 3 | 19 | 0 | 0 | — |
| `Core/OOTypes.h` | 2 | 99 | 0 | 0 | [1 ⚠️](#ootypes) |
| `Core/OOVector.h` | 0 | 0 | 0 | 0 | — (inlines: math.md) |
| `Core/OOVoxel.h` | 6 | 0 | 0 | 0 | — (inlines: math.md) |
| `Core/OXPVerifier/OOOXPVerifier.h` | 1 | 0 | 0 | 0 | — |
| `Core/OXPVerifier/OOPListSchemaVerifier.h` | 0 | 23 | 0 | 1 | — |
| `Core/Octree.h` | 2 | 1 | 0 | 0 | — |
| `Core/ResourceManager.h` | 5 | 3 | 0 | 0 | — |
| `Core/Scripting/OOConstToJSString.h` | 0 | 0 | 0 | 28 | [1 ✅](#ooconsttojsstring) |
| `Core/Scripting/OOJSEngineNativeWrappers.h` | 8 | 0 | 0 | 0 | [2 ✅ 1 ⚠️](#oojsenginenativewrappers) |
| `Core/Scripting/OOJSEngineTimeManagement.h` | 1 | 0 | 0 | 0 | — |
| `Core/Scripting/OOJSEntity.h` | 0 | 0 | 0 | 4 | [1 ✅ 1 ➖](#oojsentity) |
| `Core/Scripting/OOJSScript.h` | 0 | 0 | 1 | 0 | — |
| `Core/Scripting/OOJavaScriptEngine.h` | 15 | 0 | 0 | 8 | [3 ✅ 1 ➖ (14 macros moved → `OOJSEngineCore.h`)](#oojavascriptengine) |
| `Core/Universe.h` | 59 | 26 | 0 | 1 | — |
| `Core/legacy_random.h` | 0 | 0 | 0 | 6 | — |
| `SDL/EXRSnapshotSupport/miniz.h` | 88 | 135 | 0 | 0 | — |
| `SDL/EXRSnapshotSupport/tinyexr.h` | 47 | 4 | 18 | 11 | — |
| `SDL/MyOpenGLView.h` | 23 | 75 | 0 | 0 | — |
| `SDL/OOResourcesWin/OOResourcesWin.h` | 3 | 0 | 0 | 0 | — |
| `SDL/stb_image_write.h` | 3 | 0 | 0 | 0 | — |
| **Total (238 pairs)** | **857** | **948** | **173** | **105** | |

These pairs have no object-like `#define`, enumerator, constant or non-maths inline function on the upstream side, so there was nothing to compare: `Core/Debug/OODebugMonitor.h`, `Core/Debug/OODebugStandards.h`, `Core/Debug/OODebugSupport.h`, `Core/Debug/OODebuggerInterface.h`, `Core/Debug/OOJSConsole.h`, `Core/Debug/OOTCPStreamDecoder.h`, `Core/Entities/DockEntity.h`, `Core/Entities/OOECMBlastEntity.h`, `Core/Entities/OOEntityWithDrawable.h`, `Core/Entities/OOExplosionCloudEntity.h`, `Core/Entities/OOFlashEffectEntity.h`, `Core/Entities/OOFlasherEntity.h`, `Core/Entities/OOLaserShotEntity.h`, `Core/Entities/OOLightParticleEntity.h`, `Core/Entities/OOPlanetEntity.h`, `Core/Entities/OOPlasmaBurstEntity.h`, `Core/Entities/OOPlasmaShotEntity.h`, `Core/Entities/OOQuiriumCascadeEntity.h`, `Core/Entities/OORingEffectEntity.h`, `Core/Entities/OOSparkEntity.h`, `Core/Entities/OOVisualEffectEntity.h`, `Core/Entities/OOWaypointEntity.h`, `Core/Entities/PlayerEntityControls.h`, `Core/Entities/PlayerEntityScriptMethods.h`, `Core/Entities/PlayerEntitySound.h`, `Core/Entities/PlayerEntityStickProfile.h`, `Core/Entities/ProxyPlayerEntity.h`, `Core/Entities/ShipEntityAI.h`, `Core/Entities/ShipEntityLoadRestore.h`, `Core/Entities/ShipEntityScriptMethods.h`, `Core/Entities/SkyEntity.h`, `Core/Materials/OOBasicMaterial.h`, `Core/Materials/OOCombinedEmissionMapGenerator.h`, `Core/Materials/OODefaultShaderSynthesizer.h`, `Core/Materials/OOMaterial.h`, `Core/Materials/OOMaterialConvenienceCreators.h`, `Core/Materials/OOMultiTextureMaterial.h`, `Core/Materials/OONullTexture.h`, `Core/Materials/OOPNGTextureLoader.h`, `Core/Materials/OOPixMapChannelOperations.h`, `Core/Materials/OOPixMapTextureLoader.h`, `Core/Materials/OOPlanetTextureGenerator.h`, `Core/Materials/OOShaderProgram.h`, `Core/Materials/OOShaderUniform.h`, `Core/Materials/OOSingleTextureMaterial.h`, `Core/Materials/OOStandaloneAtmosphereGenerator.h`, `Core/Materials/OOTextureGenerator.h`, `Core/Materials/OOTextureLoader.h`, `Core/OOALBufferedSound.h`, `Core/OOALMusic.h`, `Core/OOALSound.h`, `Core/OOALSoundChannel.h`, `Core/OOALStreamedSound.h`, `Core/OOBasicSoundReferencePoint.h`, `Core/OOCacheManager.h`, `Core/OOCharacter.h`, `Core/OOColor.h`, `Core/OOCommodityMarket.h`, `Core/OOConvertCubeMapToLatLong.h`, `Core/OOConvertSystemDescriptions.h`, `Core/OOCrosshairs.h`, `Core/OODrawable.h`, `Core/OOEncodingConverter.h`, `Core/OOEntityFilterPredicate.h`, `Core/OOEquipmentType.h`, `Core/OOGraphicsResetManager.h`, `Core/OOIsNumberLiteral.h`, `Core/OOLogHeader.h`, `Core/OOLogOutputHandler.h`, `Core/OOLoggingExtended.h`, `Core/OOOpenAL.h`, `Core/OOOpenGLOnly.h`, `Core/OOPListParsing.h`, `Core/OOPlanetDrawable.h`, `Core/OOPolygonSprite.h`, `Core/OOProbabilisticTextureManager.h`, `Core/OOProbabilitySet.h`, `Core/OORoleSet.h`, `Core/OOShipGroup.h`, `Core/OOShipRegistry.h`, `Core/OOSkyDrawable.h`, `Core/OOSoundInternal.h`, `Core/OOSoundSourcePool.h`, `Core/OOTextureScaling.h`, `Core/OOXMLExtensions.h`, `Core/OXPVerifier/OOAIStateMachineVerifierStage.h`, `Core/OXPVerifier/OOCheckDemoShipsPListVerifierStage.h`, `Core/OXPVerifier/OOCheckEquipmentPListVerifierStage.h`, `Core/OXPVerifier/OOCheckJSSyntaxVerifierStage.h`, `Core/OXPVerifier/OOCheckPListSyntaxVerifierStage.h`, `Core/OXPVerifier/OOCheckRequiresPListVerifierStage.h`, `Core/OXPVerifier/OOCheckShipDataPListVerifierStage.h`, `Core/OXPVerifier/OOFileScannerVerifierStage.h`, `Core/OXPVerifier/OOModelVerifierStage.h`, `Core/OXPVerifier/OOOXPVerifierStage.h`, `Core/OXPVerifier/OOTextureVerifierStage.h`, `Core/Scripting/EntityOOJavaScriptExtensions.h`, `Core/Scripting/OOJSCall.h`, `Core/Scripting/OOJSClock.h`, `Core/Scripting/OOJSDock.h`, `Core/Scripting/OOJSEquipmentInfo.h`, `Core/Scripting/OOJSExhaustPlume.h`, `Core/Scripting/OOJSFlasher.h`, `Core/Scripting/OOJSFont.h`, `Core/Scripting/OOJSFrameCallbacks.h`, `Core/Scripting/OOJSFunction.h`, `Core/Scripting/OOJSGlobal.h`, `Core/Scripting/OOJSGuiScreenKeyDefinition.h`, `Core/Scripting/OOJSInterfaceDefinition.h`, `Core/Scripting/OOJSManifest.h`, `Core/Scripting/OOJSMission.h`, `Core/Scripting/OOJSMissionVariables.h`, `Core/Scripting/OOJSOolite.h`, `Core/Scripting/OOJSPlanet.h`, `Core/Scripting/OOJSPlayer.h`, `Core/Scripting/OOJSPlayerShip.h`, `Core/Scripting/OOJSPopulatorDefinition.h`, `Core/Scripting/OOJSPropID.h`, `Core/Scripting/OOJSQuaternion.h`, `Core/Scripting/OOJSShip.h`, `Core/Scripting/OOJSShipGroup.h`, `Core/Scripting/OOJSSound.h`, `Core/Scripting/OOJSSoundSource.h`, `Core/Scripting/OOJSSpecialFunctions.h`, `Core/Scripting/OOJSStation.h`, `Core/Scripting/OOJSSun.h`, `Core/Scripting/OOJSSystem.h`, `Core/Scripting/OOJSSystemInfo.h`, `Core/Scripting/OOJSTimer.h`, `Core/Scripting/OOJSVector.h`, `Core/Scripting/OOJSVisualEffect.h`, `Core/Scripting/OOJSWaypoint.h`, `Core/Scripting/OOJSWorldScripts.h`, `Core/Scripting/OOJSWormhole.h`, `Core/Scripting/OOLegacyScriptWhitelist.h`, `Core/Scripting/OOPListScript.h`, `Core/Scripting/OOScript.h`, `Core/Scripting/OOScriptTimer.h`, `SDL/OOSDLJoystickManager.h`.

**Upstream headers with no port counterpart (28):** `Core/Entities/PlanetEntity.h`, `Core/NSBundle+Override.h`, `Core/NSDataOOExtensions.h`, `Core/NSDictionaryOOExtensions.h`, `Core/NSFileManagerOOExtensions.h`, `Core/NSMutableDictionaryOOExtensions.h`, `Core/NSNumberOOExtensions.h`, `Core/NSObjectOOExtensions.h`, `Core/NSScannerOOExtensions.h`, `Core/NSStringOOExtensions.h`, `Core/NSThreadOOExtensions.h`, `Core/NSUserDefaults+Override.h`, `Core/OOAsyncQueue.h`, `Core/OOCollectionExtractors.h`, `Core/OODeepCopy.h`, `Core/OOEnvironmentCubeMap.h`, `Core/OOExcludeObjectEnumerator.h`, `Core/OOFilteringEnumerator.h`, `Core/OONSOperation.h`, `Core/OOSpatialReference.h`, `Core/OOWeakReference.h`, `Core/OOWeakSet.h`, `Core/OXPVerifier/OOOXPVerifierStageInternal.h`, `Core/OldSchoolPropertyListWriting.h`, `Core/ReleaseLockProxy.h`, `Core/TextureStore.h`, `SDL/Comparison.h`, `SDL/MyOpenGLView+Input.h`. Only four of them carry constants or inline functions; see [Unpaired headers](#unpaired).

---

## Core/Entities/PlayerEntity.h

<a id="playerentity"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `HYPERSPEED_FACTOR` | `[PLAYER hyperspeedFactor]` (295) | `(PLAYER != nullptr ? PLAYER->getHyperspeedFactor() : 0.0f)` (293) | ✅ |
| `MANIFEST_SCREEN_ROW_NEXT` | `([[PLAYER hud] isHidden] ? 27 : 20)` (336) | null-guarded, so a nil player or HUD gives 20 (334) | ✅ |
| `FORWARD/AFT/PORT/STARBOARD_FACING_STRING` | `DESC(@"…-facing-string")` (306-309) | `OO_DESC("…-facing-string")` (304-307), same keys | ✅ |
| `GUI_ROW_GAMEOPTIONS_*` | `PROCEDURALLYTEXTUREDPLANETS` under `#if !NEW_PLANETS` (191-193) | row dropped (192) | ✅ |
| `OOGetPlayer()` inline | `NSCAssert` + `return gOOPlayer` (1285) | `OOCAssert` + `return gOOPlayer` (1865) | ✅ |

**Differences:**

- ✅ **low** — the two macros that send messages now test for null explicitly. They give what ObjC nil-messaging gave (0.0, and `NO`→20), so the values are unchanged — upstream `Core/Entities/PlayerEntity.h:295`, `:336` ↔ port `Core/Entities/PlayerEntity.h:293`, `:334`
- ✅ note — upstream defines `NEW_PLANETS 1` (`Core/Entities/OOStellarBody.h:35`), so the game-options row enum has the same 43 values on both sides. The port simply deletes the dead row. The 32 other enumerators and macros in this header moved to `Core/OOEntityEnums.h` with identical values.

## Core/Entities/OOStellarBody.h

<a id="oostellarbody"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `NEW_PLANETS` / `STELLAR_TYPE_ATMOSPHERE` | `#define NEW_PLANETS 1` and `#if !NEW_PLANETS STELLAR_TYPE_ATMOSPHERE` (33-46) | the define and the dead enumerator are gone; `SUN`/`NORMAL_PLANET`/`MOON`/`MINIATURE` = 0-3 (35-40) | ➖ |

**Differences:**

- ➖ **low** — the `NEW_PLANETS` switch is gone, and with it the legacy `PlanetEntity` path (`Core/Entities/PlanetEntity.h` is unpaired; its body was `#if !NEW_PLANETS`). The enum values that were compiled are unchanged — upstream `Core/Entities/OOStellarBody.h:33-46` ↔ port `Core/Entities/OOStellarBody.h:35-40`

## Core/HeadUpDisplay.h

<a id="headupdisplay"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `Z1` | `[(MyOpenGLView*)[[player universe] gameView] display_z]` (217) | `UNIVERSE`→`getGameView()->getDisplay_z()`, 0.0f if null (231) | ✅ |

**Differences:**

- ✅ **low** — `Z1` is unused on both sides (no `.m`/`.cpp` references it). The port reaches the universe through `UNIVERSE` rather than through `player`, but nothing calls it either way — upstream `Core/HeadUpDisplay.h:217` ↔ port `Core/HeadUpDisplay.h:231`

## Core/Materials/OOShaderUniformMethodType.h

<a id="ooshaderuniformmethodtype"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOShaderUniformType` enum | `… Point=17, Object=18, Count=19` (56-57) | `… Point=17, Color=18, Object=19, Count=20` (59-63) | ⚠️ |

**Differences:**

- ⚠️ **low** — the port inserts `kOOShaderUniformTypeColor` before `Object`, which shifts `Object` and `Count` by one. The values are only used inside the process (binding tables, switch statements, array bound) and are never saved or sent to shaders. Bead oo-9ht.1, per the code comment ("the C++ colour (OOColor *), since bead oo-9ht.1 deleted its facade") — upstream `Core/Materials/OOShaderUniformMethodType.h:37-60` ↔ port `Core/Materials/OOShaderUniformMethodType.h:40-63`

## Core/Materials/OOMaterialSpecifier.h

<a id="oomaterialspecifier"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| 28 material keys (`kOOMaterialDiffuseColorName` … `kOOMaterialLightMapsName`) | `extern` in the header; values in `Core/Materials/OOMaterialSpecifier.m:35-68` | `inline constexpr const char* cxx_k…` (71-98) | ✅ |

**Differences:**

- ✅ **low** — all 28 strings are identical (for example `"diffuse"`, `"shininess"`, `"light_map"`), and so is each legacy alias.

## Core/Materials/OOTexture.h

<a id="ootexture"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| 16 texture-specifier keys (`kOOTextureSpecifierNameKey` … `BindingKey`) | `extern`; values in `Core/Materials/OOTexture.m:44-60` | `cxx_k…` constexpr (316-333) | ✅ |

**Differences:**

- ✅ **low** — the strings are identical, including the case of `"texture_LOD_bias"`.

## Core/Materials/OOShaderMaterial.h

<a id="ooshadermaterial"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| 9 config keys (`kOOVertexShaderSourceKey` … `kOOIsSynthesizedMaterialMacrosKey`) | `NSString* const` in `Core/Materials/OOShaderMaterial.m:46-54` | `inline constexpr const char*` in the header (211-219) | ✅ |

## Core/GuiDisplayGen.h

<a id="guidisplaygen"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| 75 GUI-settings keys (`kGuiDefaultTextColor` … `kGuiDockingContinueColor`) | `static NSString* const` (67-152) | `inline constexpr const char* cxx_kGui…` (75-160) | ✅ |

**Differences:**

- ✅ **low** — the only change is the name prefix. Every key string is identical, including the format keys `"chart_economy_%zu_color"` and `"chart_government_%zu_color"`.

## Core/OOCommodities.h

<a id="oocommodities"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| 32 commodity/market keys (`kOOCommodityName` … `kOOCommodityMarketTypeValueGood`) | `static NSString* const` in the header (32-74) | `constexpr std::string_view` in `Core/OOCommodities.cpp:42-80` | ✅ |
| `kOOCommodityTrumbleOpinion`, `…SortOrder`, `…Comment`, `…ShortComment` | header (49-54); used only by `OOCommodityMarket.m` | `kTrumbleOpinion`, `kSortOrder`, `kComment`, `kShortComment` in `Core/OOCommodityMarket.cpp:38-42` | ✅ |

**Differences:**

- ✅ **low** — the keys became file-local, and the four used only by the market were renamed. All 36 strings are identical, and so are the defaults read with them (`"[oolite-commodity-no-comment]"`) — upstream `Core/OOCommodityMarket.m:163` ↔ port `Core/OOCommodityMarket.cpp:159`

## Core/OOFoundation.h

<a id="oofoundation"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `NSUpArrowFunctionKey` … `NSModeSwitchFunctionKey` (72 enumerators, 0xF700-0xF747) | GNUstep fallback enum (127-198) | gone | ➖ |
| `OOOrderedAscending/Same/Descending` | (`NSOrdered*` from Foundation, -1/0/1) | `inline constexpr OOComparisonResult … = NSOrdered*` (216-218) | ✅ |
| `BOOL`→`WinBOOL`, `__OBJC_BOOL` | (from gnustep-base `GSConfig.h`) | the same shim around `<winsock2.h>` (69-70) | ✅ |

**Differences:**

- ➖ **low** — no upstream `.m` referred to the AppKit function-key enum (`grep` finds it only in `OOFoundation.h`). Keys come from SDL key codes on both sides, so removing it has no observable effect.

## Core/OOLogging.h

<a id="oologging"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOLOG_ERROR_PREFIX`, `OOLOG_WARNING_PREFIX` | `@"***** ERROR: "`, `@"----- WARNING: "` (122-123) | `kErrorPrefix`/`kWarningPrefix` `oofnd/Log.hpp:509-510`; `kSyntaxIssuePrefix` `Core/OOStringExpander.cpp:205` | ✅ |
| `OODebugLog`, `OOExtraLog` | `OOLog` under `#if OO_DEBUG` / `#ifndef NDEBUG`, else a no-op (154, 166) | each call site is wrapped in the same guard around `OO_LOG` (for example `Core/OOCacheManager.cpp:146`, `Core/Universe.cpp:639`) | ➖ |
| `OOLOG_POISON_NSLOG` | `0` (36); gates `#pragma GCC poison NSLog` | gone (no `NSLog` exists) | ➖ |

**Differences:**

- ➖ **low** — the debug-only log macros were inlined as preprocessor guards. I checked the `OOCacheManager` and `Universe` sites: same guard, same message class, same text — upstream `Core/OOCacheManager.m:155`, `Core/Universe.m:4865` ↔ port `Core/OOCacheManager.cpp:146-148`, `Core/Universe.cpp:639-641`

## Core/OOPriorityQueue.h

<a id="oopriorityqueue"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OO_PQ_STRONG` | `__strong` GC qualifier (43-45) | gone (`oo::Ref` storage) | ➖ |

## Core/OOProfilingStopwatch.h

<a id="ooprofilingstopwatch"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OO_PROFILING_STOPWATCH_JS_NOW` | Windows, not standalone: time from `JS_Now()` (85) | `OO_PROFILING_STOPWATCH_MICROSECONDS`: a `std::chrono::steady_clock` microsecond count (102) | ⚠️ |

**Differences:**

- ⚠️ **low** — the Windows high-resolution clock changed from SpiderMonkey's calibrated `JS_Now()` to `steady_clock`. Both count in microseconds and only differences are used, so only profiling and timing logs could tell them apart. Bead oo-1gc.3, per the header comment — upstream `Core/OOProfilingStopwatch.h:80-86` ↔ port `Core/OOProfilingStopwatch.h:97-103`

## Core/OORegExpMatcher.h

<a id="ooregexpmatcher"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `kOORegExpCaseInsensitive`, `kOORegExpMultiLine` | `JSREG_FOLD` (0x01), `JSREG_MULTILINE` (0x04) (40-41) | `ooscript::RegExpFoldCase = 0x01`, `RegExpMultiline = 0x04` (`Core/Scripting/ooscript/JSEngine.hpp:589-591`) | ✅ |

## Core/Scripting/OOJSEngineNativeWrappers.h

<a id="oojsenginenativewrappers"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOJS_NATIVE_EXIT` | `@catch (id exception) { OOJSReportWrappedException(...); return NO; }` (96) | `catch (...) { OOJSReportCurrentException(...); return false; }` (135) | ⚠️ |
| `OOJS_PROFILE_ENTER_NAMED`/`_EXIT_VAL`, `OOJS_BEGIN/END_FULL_NATIVE` | `@try … @finally { OOJSProfileExit / JS_ResumeRequest; OOJSResumeTimeLimiter }` (53-70, 129-150) | RAII `OOJSProfileScope` / `OOJSFullNativeScope`, same order of the calls (94-110, 172-190) | ✅ |
| `OOJS_PROFILE_EXIT_JSVAL` | `OOJS_PROFILE_EXIT_VAL(JSVAL_VOID)` (114) | `OOJS_PROFILE_EXIT_VAL(ooscript::undefinedValue())` (159) | ✅ |

**Differences:**

- ⚠️ **low** — `catch (...)` is wider than `@catch (id)`. Any C++ exception escaping a native, including `std::bad_alloc`, now becomes a JS error ("Native exception: <what()>" or "Unidentified native exception") instead of unwinding further. Upstream could only meet ObjC exceptions here. The header comment documents this, and [scripting.md](scripting.md) records `OOJSReportCurrentException` as ➖ ("also catches `std::exception`") — upstream `Core/Scripting/OOJSEngineNativeWrappers.h:96-103` ↔ port `Core/Scripting/OOJSEngineNativeWrappers.h:135-150`
- note: the port adds `OOJS_EXTERN_C` (67), a linkage helper with no runtime effect.

## Core/Scripting/OOJavaScriptEngine.h

<a id="oojavascriptengine"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOJS_PROP_READWRITE` … `OOJS_PROP_HIDDEN_READONLY_CB` (8 macros) | `JSPROP_PERMANENT`/`ENUMERATE`/`READONLY`/`SHARED` combinations (606-621) | moved to `Core/Scripting/OOJSEngineCore.h:464-479` as `ooscript::PropertyFlag` with the same bits (Enumerate 0x01, ReadOnly 0x02, Permanent 0x04, Shared 0x40; `ooscript/JSEngine.hpp:183-189`) | ✅ |
| `OOJS_THIS`, `OOJS_ARGV`, `OOJS_RVAL`, `OOJS_RETURN_VOID`, `OOJS_RETURN_NULL` | `JS_THIS_OBJECT(context, vp)` … `OOJS_RETURN(JSVAL_NULL)` (624-636) | `oojsArgs.thisObject()` … `OOJS_RETURN(ooscript::nullValue())` (`OOJSEngineCore.h:483-495`) | ✅ |
| inlines `OOJSAcquireContext`, `OOJSRelinquishContext`, `OOJSValueFromBOOL`, `OOJSGetClass`, `OOJSValueIsFunction`, `OOJSValueIsArray` | (116, 125, 182, 346, 361, 374) | `OOJSEngineCore.h:55, 64, 129, 234, 245, 257`: the same assert, begin/end request, `b != NO`, and the same null guard before the function/array test | ✅ |
| `OOJSValueFromNativeObject()` inline | `[object oo_jsValueInContext:]`, or `JSVAL_NULL` for nil (229) | gone; callers use `Entity::jsValueInContext()` with an explicit `nullValue()` for null (for example `Core/OOCommodities.cpp:250`, `Core/Scripting/EntityOOJavaScriptExtensions.cpp:96`) | ➖ |

## Core/Scripting/OOJSEntity.h

<a id="oojsentity"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `JSEntityClass()` inline | `return &gOOEntityJSClass;` (42) | moved out of line: `Core/Scripting/OOJSEntity.cpp:114` | ➖ |
| `OOIsStaleEntity()` inline | `entity == nil || entity == gOOJSPlayerIfStale` (69) | `entity == nullptr || (gOOJSPlayerIfStale != nullptr && entity == gOOJSPlayerIfStale)` (139) | ✅ |

**Differences:**

- ✅ note — the extra `gOOJSPlayerIfStale != nullptr` test is redundant once `entity` is non-null, so the result is the same.

## Core/Scripting/OOConstToJSString.h

<a id="ooconsttojsstring"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| 8 `OOJSValueFrom<Const>()` inlines (EntityStatus, ScanClass, CompassMode, GUIScreenID, GalacticHyperspaceBehaviour, ViewID, ShipDamageType, LegalStatusReason) | `STRING_TO_JSVAL(OOJSStringFrom<Const>(context, value))` (54-245) | `ooscript::stringValue(OOJSStringFrom<Const>(context, value))` (71-262) | ✅ |

**Differences:**

- ✅ note — only the JSAPI wrapper changed. The other 20 inlines in the header (string ↔ constant, with the same `k…Default` fallbacks) match textually after normalisation. [scripting.md](scripting.md) records the same result.

## Core/OODebugGLDrawing.h

<a id="oodebugdrawing"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OODebugDrawBoundingBoxBetween`, `OODebugDrawNormal`, `OODebugDrawVector`, `OODebugDrawLine` | `[OOColor blueColor]`, `cyanColor`, `magentaColor`, `whiteColor` (77-125) | `OOColor::blueColor().get()` etc. (79-127); the temporary `Ref` lives until the end of the call | ✅ |

## Core/OOFunctionAttributes.h

<a id="oofunctionattributes"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOConsumeReference()` inline | identity on an `id`, for the static analyser (123) | gone with libobjc2 (bead oo-dbz, comment at `Core/OOFoundation.cpp:35`) | ➖ |

## Core/OOOpenGLExtensionManager.h

<a id="ooopenglextensionmanager"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOShadersSupported()` inline | `[[OOOpenGLExtensionManager sharedManager] shadersSupported]` (180) | `OOOpenGLExtensionManager::sharedManager()->shadersSupported()` (150) | ✅ |

**Differences:**

- ✅ note — the 8 Windows extension-pointer macros moved to `Core/OOOpenGLExtensionPointers.h` with identical values.

## Core/OOStringExpander.h

<a id="oostringexpander"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOCastParamObject/SignedInteger/UnsignedInteger/Float/Double` + `OO_CAST_PARAMETER` (`__builtin_choose_expr` dispatch) | `NSNumber numberWithLongLong/UnsignedLongLong/Float/Double`, or the object as is (169-219) | `cxx_OOCastParam` overload set: `std::integral` → `signedInteger`/`unsignedInteger` by signedness, `float` → `singleReal`, `double`/`long double` → real, strings → string node (277-300) | ➖ |

**Differences:**

- ➖ **low** — the overload set replaces the type-trait dispatch. It keeps the same four numeric kinds (signed and unsigned 64-bit, single-precision float, double). Two inputs differ: plain `char` and `bool` both go to the signed branch, as upstream's `char`/`BOOL` (signed char) did; and enums, which upstream's macro rejected at compile time, are now promoted to their underlying integer — upstream `Core/OOStringExpander.h:169-219` ↔ port `Core/OOStringExpander.h:274-300`

## Core/OOStringParsing.h

<a id="oostringparsing"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOStringFromIntCredits`, `OOCredits`, `OOIntCredits` inlines | `OOStringFromDeciCredits(n * 10, NO, sym)` / `(n, YES, YES)` / `(n, YES)` (52-64) | `cxx_` versions with the same arguments, returning `std::string` (56-68) | ✅ |

## Core/OOTypes.h

<a id="ootypes"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OOMassUnit` | `UNITS_TONS, UNITS_KILOGRAMS, UNITS_GRAMS` (0-2) (111-115) | adds `UNITS_UNKNOWN` = 3 after them (122-126) | ⚠️ |

**Differences:**

- ⚠️ **low** — the new enumerator is appended, so no existing value moves. A `quantity_unit` outside 0-2 now maps to `UNITS_UNKNOWN` and displays "??" (`Core/OOCommodities.h:45-48`, `Core/OOConstToString.cpp:513`). Upstream's bare cast was undefined. ADR-0036 (`oomassunit-out-of-range`) — upstream `Core/OOTypes.h:111-115` ↔ port `Core/OOTypes.h:121-126`

## Core/OOJoystickManager.h

<a id="oojoystickmanager"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `JOYAXISMOTION` … `JOYHAT_LEFTDOWN`, `JOYBUTTON_PRESSED/RELEASED` (new) | (none; `SDL/OOSDLJoystickManager.m:218-239` uses `SDL_EVENT_JOYSTICK_*` / `SDL_HAT_*` directly) | an anonymous enum aliasing the same SDL3 constants (178-194) | ✅ |

**Differences:**

- ✅ note — the aliases have the same values as the SDL3 constants. `JOYBUTTON_PRESSED/RELEASED` (implicitly 13/14) are referenced nowhere outside the header.

## Core/OOOXZManager.h

<a id="oooxzmanager"></a>

| Name | Upstream | Port | Verdict |
|---|---|---|---|
| `OXZInstallableState` (8 enumerators, new in header) | private enum in `Core/OOOXZManager.m:75-86` | the same enum in the header (81-92), same order and values 0-7 | ✅ |

## Unpaired headers

<a id="unpaired"></a>

| Upstream header | Constants / inlines | Where they went | Verdict |
|---|---|---|---|
| `Core/NSFileManagerOOExtensions.h` | `SAVEDIR "oolite-saves"`, `SNAPSHOTDIR "snapshots"` (33, 36) | the same `#define`s in `SDL/MyOpenGLView.cpp:53-54`; `oofnd/ResourcePaths.hpp:171-176` uses the same names | ✅ |
| `Core/OOCollectionExtractors.h` | inlines `OOClampInteger`, `OOIntegerFromObject`, `OOUIntegerFromObject` | `oofnd/PListGet.hpp` (audited in [foundation.md](foundation.md) rows at lines 635-638) | ✅ |
| `Core/OONSOperation.h` | `OO_HAVE_NSOPERATION`, `OO_ALLOW_NSOPERATION`, `OONSOperationQueuePriority*` (-8…8), 3 class-getter inlines | gone; the NSOperation shim has no counterpart | ➖ |
| `Core/Entities/PlanetEntity.h` | `MAX_TRI_INDICES`, `MAX_PLANET_VERTICES` (39-40) | gone; the whole header was `#if !NEW_PLANETS`, compiled out upstream | ➖ |
| the other 24 (NS…Extensions, `OOWeakReference`, `OODeepCopy`, `TextureStore`, `SDL/Comparison.h`, …) | none | — | ➖ |
