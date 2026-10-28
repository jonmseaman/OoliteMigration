# Objective-C → C++ behavioural parity audit

Method-by-method comparison of the C++ port in this tree (`src/`) against the original
Objective-C in `upstream/oolite/src` (OoliteProject, unmodified). One row per upstream `.m` file;
a row is checked when every method in its coverage table has been compared and its findings written.

**Legend:** ✅ equivalent · ⚠️ intentional divergence (cited) · ❌ suspected behaviour difference · ➖ removed/replaced

**Progress:** 241 / 241 upstream `.m` files, plus C/table files, C++-only files and the header sweep: **complete**.

**Totals across all coverage tables:** 7,476 rows: 6,518 ✅ · 263 ⚠️ · 170 ❌ · 525 ➖. The header sweep separately compared 857 `#define`s, 948 enum values and 173 constants and found 0 ❌.
Of the 170 ❌, 2 are high and about 12 medium (below); the rest are low (log text, nil-messaging edge cases, iteration order).

**Method:** each file was read side by side, method by method, by an auditor following [AUDIT-BRIEF.md](AUDIT-BRIEF.md). Every high finding and most medium ones (✔) were then re-verified by the coordinator against both sources.

## Cross-cutting findings

Patterns that recur across files. Each instance is also recorded in its own file's section.

1. **Preference defaults: `oo_*ForKey:defaultValue:` → `isNull() ? default : xForKey()`** (❌ **med** in Universe, where a malformed pref gives FOV→MIN, procedural planets off, ECM FX off and detail level 0; low elsewhere; about 15 sites; see [foundation.md#oocollectionextractors](foundation.md#oocollectionextractors)). Upstream's extractor returned `defaultValue` whenever the stored value could not be converted, such as a non-numeric or unrecognised string. The port returns the default only when the key is absent; otherwise the converter yields 0/NO. Sites:
   - `OOALSound.cpp:62` (volume_control → 0 mutes the game)
   - `OOLogging.cpp:262-267` (logging-show-time/class → NO drops the log prefixes)
   - `GameController.cpp:235` (a malformed `animation_timer_interval` → 0 → the frame loop spins at ~10 kHz instead of 240 Hz, **med**), `:303` (`ecoqos`)
   - `Universe.cpp:308,333,338,344`

   Bools also differ in parsing. `Defaults::boolForKey` uses GNUstep `-[NSString boolValue]`, where "on" and ".5" read NO; upstream's `OOBooleanFromObject` read them as YES or fell back to the default. Fix candidate: a `Defaults::get<T>(key, fallback)` with `oo_*ForKey` semantics (cf. `PListGet.hpp`).
2. **Hash-order → sorted-order iteration.** Dictionaries and sets that upstream walked in GNUstep hash order are walked in key/byte order. This reorders log lines and warnings: OXP verifier stages, shipdata key warnings, AI states, OOEncodingConverter substitutions. It is intentional where cited (oo-qps.51), unintended elsewhere, and visible only where order reaches output or RNG.
3. **Two `doubleValue` ports.** `PListGet.hpp:149` (NSScanner style) and `Defaults.hpp:163` (`from_chars`) disagree on long mantissas and huge exponents, so at most one matches GNUstep (❌ low).
4. **Log text drift.** Some log messages lost an argument or changed class:
   - `verifyOXP.scanFiles.nonStandardFile` lost "(type)";
   - log-setup NSLog calls became `OO_LOG("unclassified")`;
   - `plist.wrongType` is no longer emitted;
   - `savedGame.defaultPath.*` and `NSUserDefaultsOverride` failure logs are gone.

## Suspected divergences (ranked)

*Final. ✔ = verified by the coordinator against both sources; unmarked = auditor finding with cited lines, not independently re-read.*

### High
- ✔ **NPC subentity flashers and exhaust plumes are never updated.** `ShipEntity::update` calls `update()` only on subentities that cast to `ShipEntity` (`oo::ToShip`). Upstream sent `-update:` to every subentity. As a result, `OOFlasherEntity` lights don't animate and `OOExhaustPlumeEntity` trails don't track on NPC and demo ships. Affects all three loops: upstream `ShipEntity.m:2113,2382,2469` ↔ port `ShipEntity.cpp:2500,2773,2866`. [details](entities-ship.md#shipentity)

- ✔ **JS `delete` on native-backed properties is a no-op.** The QuickJS bridge's `ExDeleteProperty` (`ooscript/JSEngine_quickjs.cpp:1599-1604`) calls the class `delProperty` hook only when the object has an own slot for the name; SpiderMonkey always called it. Effects:
  - `delete missionVariables.x` returns true but leaves the variable when it came from a save or a legacy script, and the stale value is re-saved;
  - `delete systemInfo.x` no longer clears the OXP_DYNAMIC layer;
  - `delete manifest.<good>` succeeds silently.

  [scripting.md#oojsmissionvariables](scripting.md#oojsmissionvariables)

### Medium
- ✔ **Every JS error/warning is logged under class `script.javaScript.<sev>.notAnError`.** The QuickJS backend never passes an `errorNumber` to `invokeReporter` (`JSEngine_quickjs.cpp:878,936,3507,3519`), so the `javascript-errors.plist` lookup always resolves error 0. Message text also follows QuickJS-ng wording, and compile errors no longer print the source line (`linebuf` is always null). [scripting.md#oojavascriptengine](scripting.md#oojavascriptengine)
- **SpiderMonkey language extensions are gone** (`for each`, expression closures, `toSource`, Array generics). `setVersion(ECMA5)` and the context options are stored but ignored. No built-in script uses these extensions; OXPs may.
- **Missile ident lock on a wormhole shows an empty name.** `printIdentLockedOnForMissile` requires `oo::ToShip`, but `WormholeEntity` has its own `identFromShip` (`PlayerEntity.cpp:11504`). [entities-player.md#playerentity](entities-player.md#playerentity)
- ✔ **Standard-library exceptions now crash where upstream logged and continued.** Catch sites were narrowed from `@catch (id)` / `@catch (NSException*)` to `catch (const oo::Exception&)` (bead oo-rskgl.1: "the game throws only oo::Exception"). Affected: the main loop (`GameController.cpp:425`), `AI.cpp`, `PlayerEntityControls`, and the legacy script engine. But the port can throw `std::` exceptions, which then reach `std::terminate`:
  - `currentLaserOffset().at(0)` on an empty list, in `PlayerEntity.cpp:5821` and `PlayerEntityControls.cpp:1194`;
  - `std::vector(howMany)` with a negative count from the legacy `addShipsAt` action (`Universe.cpp:2679`).

  [cpp-only.md](cpp-only.md)
- **`oo::EntityShortDescription` loses the class and ship name** (`EntityHelpers.cpp:154`). This changes `ai.error.stackOverflow`, `ship.subentity.sanityCheck.failed`, `entity.invalidSession` and other log text. [cpp-only.md](cpp-only.md)
- ✔ **`laserColor` shader uniform can no longer be bound.** It has no row in `EntityShaderBindings.cpp`, whose comment wrongly says it "fails as before". Upstream bound `-[ShipEntity laserColor]` (an OOColor) via `OOShaderUniform.m:511`. [graphics.md#ooshaderuniform](graphics.md#ooshaderuniform)
- ✔ **Symlinked `.oxp` folders are not found.** The OXP scan uses `symlink_status` (`ResourceManager.cpp:498`). [gamedata.md#resourcemanager](gamedata.md#resourcemanager)
- ✔ **Data cache likely rebuilt every launch.** File mod-times are converted using two separate `now()` readings, which jitter (`oofnd/FileSystem.hpp:180-182`), so `dataCache.rebuild.datesChanged` fires. [gamedata.md#resourcemanager](gamedata.md#resourcemanager)
- ✔ **JS `ship.speed` became writable.** `OOJSShip.cpp:504`; it was read-only upstream. No ADR. [scripting.md#oojsship](scripting.md#oojsship)
- **`EquipmentInfo.provides` returns `[]` instead of `null`** for equipment with no extra-info dict (`OOEquipmentType.cpp:603`). [scripting.md#oojsequipmentinfo](scripting.md#oojsequipmentinfo)
- ✔ **`OORoleSet::anyRole` walks roles in sorted order**, so the same random draw picks a different role (`OORoleSet.cpp:172`). [gamedata.md#ooroleset](gamedata.md#ooroleset)
- ⚠️ *(intentional, ADR-0043 / oo-3rb.154)* Populator blocks with equal priority (most of them) run in key order (`Universe.cpp:2055`), so populated ship positions differ for the same seed. Role probability sets, the pending-AI-message order and commodity generation now iterate in key order. Ship picks, AI transitions, and market prices/quantities differ from upstream for the same seed.
- ⚠️ *(intentional, oo-9ht.115)* `SqueezeVertically1` changes output pixels for 1-channel textures (`OOTextureScaling.cpp:1272`).
- ⚠️ *(intentional, ADR-0002)* JS syntax and semantics now follow QuickJS-ng, not SpiderMonkey 1.8.5. This affects the OXP verifier's JS check and every script.

### Low
- ✔ *Memory safety:* `setGuiToMarketInfoScreen` indexes `quantityInHold[IndexOfGood(...)]` with no not-found guard (`PlayerEntity.cpp:10485`). Upstream had the same out-of-bounds write on a stack array; the port's lands on the heap.

Other low findings are recorded per file. The bulk falls into three groups:
- the cross-cutting patterns above;
- log-text drift;
- missing null guards where upstream relied on nil-messaging (`UNIVERSE` lookups in OOConstToString/OOStringExpander, `drawTrumbles`, `behaviour_attack_slow_dogfight`).

## Suggested follow-ups

These are proposals, not filed beads. Each would want a test that fails before the fix and passes after it.

1. Update every subentity in `ShipEntity::update` (all three loops), not only `ShipEntity` ones.
2. In `ExDeleteProperty`, call the class `delProperty` hook even when no own slot exists. Add a unit test for deleting a mission variable loaded from a save.
3. Pass SpiderMonkey-equivalent error numbers through `invokeReporter`, or map QuickJS error kinds onto `javascript-errors.plist` classes.
4. Add a `Defaults::get<T>(key, fallback)` with `oo_*ForKey:defaultValue:` semantics and replace the ~15 `isNull() ? … : xForKey()` sites.
5. Widen the main-loop and AI/legacy catch sites to `std::exception` (log and continue), or replace the `.at()` and negative-size call sites that can throw.
6. Add the `laserColor` row to `EntityShaderBindings.cpp`, and correct the comment saying it "fails as before".
7. Follow symlinks in the OXP scan, and compute mod-times from a single clock reading so the data cache stays valid.
8. Decide intentionally on `ship.speed` writability and on `EquipmentInfo.provides` returning null. Record each as an ADR either way.
9. Restore `EntityShortDescription`'s class and name text, and the dropped log arguments listed under cross-cutting item 4.

## Checklist

### Foundation replacements, logging, collections, async — [foundation.md](foundation.md)

- [x] `Core/NSBundle+Override.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 1➖ — [findings](foundation.md#nsbundleoverride)
- [x] `Core/NSDataOOExtensions.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 1✅ — [findings](foundation.md#nsdataooextensions)
- [x] `Core/NSDictionaryOOExtensions.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 3➖ — [findings](foundation.md#nsdictionaryooextensions)
- [x] `Core/NSFileManagerOOExtensions.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 9✅ 1❌ 6➖ — [findings](foundation.md#nsfilemanagerooextensions)
- [x] `Core/NSMutableDictionaryOOExtensions.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 1✅ — [findings](foundation.md#nsmutabledictionaryooextensions)
- [x] `Core/NSNumberOOExtensions.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 2➖ — [findings](foundation.md#nsnumberooextensions)
- [x] `Core/NSObjectOOExtensions.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 2➖ — [findings](foundation.md#nsobjectooextensions)
- [x] `Core/NSScannerOOExtensions.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 2✅ — [findings](foundation.md#nsscannerooextensions)
- [x] `Core/NSStringOOExtensions.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 8✅ 2⚠️ 3➖ — [findings](foundation.md#nsstringooextensions)
- [x] `Core/NSThreadOOExtensions.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 1✅ — [findings](foundation.md#nsthreadooextensions)
- [x] `Core/NSUserDefaults+Override.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 1❌ — [findings](foundation.md#nsuserdefaultsoverride)
- [x] `Core/OOAsyncQueue.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 4✅ 10➖ — [findings](foundation.md#ooasyncqueue)
- [x] `Core/OOAsyncWorkManager.m` → `Core/OOAsyncWorkManager.cpp` (423 / 481 lines) — 15✅ 4⚠️ 5➖ — [findings](foundation.md#ooasyncworkmanager)
- [x] `Core/OOCPUInfo.m` → `Core/OOCPUInfo.cpp` (226 / 228 lines) — 7✅ — [findings](foundation.md#oocpuinfo)
- [x] `Core/OOCache.m` → `Core/OOCache.cpp` (1048 / 994 lines) — 44✅ 3⚠️ 1➖ — [findings](foundation.md#oocache)
- [x] `Core/OOCacheManager.m` → `Core/OOCacheManager.cpp` (668 / 561 lines) — 28✅ 2⚠️ 6➖ — [findings](foundation.md#oocachemanager)
- [x] `Core/OOCollectionExtractors.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 120✅ 2⚠️ 5❌ 76➖ — [findings](foundation.md#oocollectionextractors)
- [x] `Core/OODeepCopy.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 1❌ 6➖ — [findings](foundation.md#oodeepcopy)
- [x] `Core/OOEncodingConverter.m` → `Core/OOEncodingConverter.cpp` (242 / 214 lines) — 8✅ 2⚠️ — [findings](foundation.md#ooencodingconverter)
- [x] `Core/OOExcludeObjectEnumerator.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 5➖ — [findings](foundation.md#ooexcludeobjectenumerator)
- [x] `Core/OOFilteringEnumerator.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 19➖ — [findings](foundation.md#oofilteringenumerator)
- [x] `Core/OOFoundation.m` → `Core/OOFoundation.cpp` (92 / 35 lines) — 6➖ — [findings](foundation.md#oofoundation)
- [x] `Core/OOIsNumberLiteral.m` → `Core/OOIsNumberLiteral.cpp` (135 / 134 lines) — 1✅ — [findings](foundation.md#ooisnumberliteral)
- [x] `Core/OOLogHeader.m` → `Core/OOLogHeader.cpp` (355 / 370 lines) — 7✅ — [findings](foundation.md#oologheader)
- [x] `Core/OOLogOutputHandler.m` → `Core/OOLogOutputHandler.cpp` (649 / 567 lines) — 17✅ 2⚠️ 4❌ 1➖ — [findings](foundation.md#oologoutputhandler)
- [x] `Core/OOLogging.m` → `Core/OOLogging.cpp` (832 / 289 lines) — 40✅ 2⚠️ 2❌ — [findings](foundation.md#oologging)
- [x] `Core/OOPListParsing.m` → `Core/OOPListParsing.cpp` (233 / 74 lines) — 3✅ 1⚠️ 5➖ — [findings](foundation.md#ooplistparsing)
- [x] `Core/OOPriorityQueue.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 13✅ 1⚠️ 23➖ — [findings](foundation.md#oopriorityqueue)
- [x] `Core/OOProfilingStopwatch.m` → `Core/OOProfilingStopwatch.cpp` (129 / 120 lines) — 7✅ 1⚠️ — [findings](foundation.md#ooprofilingstopwatch)
- [x] `Core/OORegExpMatcher.m` → `Core/OORegExpMatcher.cpp` (140 / 164 lines) — 5✅ 1➖ — [findings](foundation.md#ooregexpmatcher)
- [x] `Core/OOWeakReference.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 6✅ 2⚠️ 12➖ — [findings](foundation.md#ooweakreference)
- [x] `Core/OOWeakSet.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 15✅ 4⚠️ 5➖ — [findings](foundation.md#ooweakset)
- [x] `Core/OOXMLExtensions.m` → `Core/OOXMLExtensions.cpp` (55 / 48 lines) — 1❌ — [findings](foundation.md#ooxmlextensions)
- [x] `Core/OldSchoolPropertyListWriting.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 5✅ 3⚠️ — [findings](foundation.md#oldschoolpropertylistwriting)
- [x] `Core/ReleaseLockProxy.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 17➖ — [findings](foundation.md#releaselockproxy)
- [x] `SDL/Comparison.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 6➖ — [findings](foundation.md#comparison)

### Maths, geometry, collision — [math.md](math.md)

- [x] `Core/CollisionRegion.m` → `Core/CollisionRegion.cpp` (633 / 670 lines) — 19✅ 1⚠️ — [findings](math.md#collisionregion)
- [x] `Core/OOHPVector.m` → `Core/OOHPVector.cpp` (129 / 139 lines) — 36✅ — [findings](math.md#oohpvector)
- [x] `Core/OOMatrix.m` → `Core/OOMatrix.cpp` (424 / 435 lines) — 44✅ — [findings](math.md#oomatrix)
- [x] `Core/OOMeshToOctreeConverter.m` → `Core/OOMeshToOctreeConverter.cpp` (825 / 821 lines) — 19✅ — [findings](math.md#oomeshtooctreeconverter)
- [x] `Core/OOQuaternion.m` → `Core/OOQuaternion.cpp` (408 / 412 lines) — 26✅ — [findings](math.md#ooquaternion)
- [x] `Core/OOSpatialReference.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 1✅ 2➖ — [findings](math.md#oospatialreference)
- [x] `Core/OOVector.m` → `Core/OOVector.cpp` (139 / 151 lines) — 33✅ — [findings](math.md#oovector)
- [x] `Core/OOVoxel.m` → `Core/OOVoxel.c` (197 / 197 lines) — 7✅ — [findings](math.md#oovoxel)
- [x] `Core/Octree.m` → `Core/Octree.cpp` (906 / 866 lines) — 34✅ 2⚠️ 2➖ — [findings](math.md#octree)

### OXP verifier — [oxpverifier.md](oxpverifier.md)

- [x] `Core/OXPVerifier/OOAIStateMachineVerifierStage.m` → `Core/OXPVerifier/OOAIStateMachineVerifierStage.cpp` (201 / 199 lines) — 5✅ 1❌ 1➖ — [findings](oxpverifier.md#ooaistatemachineverifierstage)
- [x] `Core/OXPVerifier/OOCheckDemoShipsPListVerifierStage.m` → `Core/OXPVerifier/OOCheckDemoShipsPListVerifierStage.cpp` (114 / 93 lines) — 4✅ — [findings](oxpverifier.md#oocheckdemoshipsplistverifierstage)
- [x] `Core/OXPVerifier/OOCheckEquipmentPListVerifierStage.m` → `Core/OXPVerifier/OOCheckEquipmentPListVerifierStage.cpp` (158 / 153 lines) — 4✅ — [findings](oxpverifier.md#oocheckequipmentplistverifierstage)
- [x] `Core/OXPVerifier/OOCheckJSSyntaxVerifierStage.m` → `Core/OXPVerifier/OOCheckJSSyntaxVerifierStage.cpp` (90 / 96 lines) — 2✅ 1⚠️ — [findings](oxpverifier.md#oocheckjssyntaxverifierstage)
- [x] `Core/OXPVerifier/OOCheckPListSyntaxVerifierStage.m` → `Core/OXPVerifier/OOCheckPListSyntaxVerifierStage.cpp` (91 / 102 lines) — 3✅ — [findings](oxpverifier.md#oocheckplistsyntaxverifierstage)
- [x] `Core/OXPVerifier/OOCheckRequiresPListVerifierStage.m` → `Core/OXPVerifier/OOCheckRequiresPListVerifierStage.cpp` (143 / 168 lines) — 2✅ 1❌ — [findings](oxpverifier.md#oocheckrequiresplistverifierstage)
- [x] `Core/OXPVerifier/OOCheckShipDataPListVerifierStage.m` → `Core/OXPVerifier/OOCheckShipDataPListVerifierStage.cpp` (363 / 359 lines) — 12✅ 2❌ — [findings](oxpverifier.md#oocheckshipdataplistverifierstage)
- [x] `Core/OXPVerifier/OOFileScannerVerifierStage.m` → `Core/OXPVerifier/OOFileScannerVerifierStage.cpp` (701 / 662 lines) — 20✅ 1⚠️ 3❌ 2➖ — [findings](oxpverifier.md#oofilescannerverifierstage)
- [x] `Core/OXPVerifier/OOModelVerifierStage.m` → `Core/OXPVerifier/OOModelVerifierStage.cpp` (191 / 114 lines) — 4✅ 2❌ 3➖ — [findings](oxpverifier.md#oomodelverifierstage)
- [x] `Core/OXPVerifier/OOOXPVerifier.m` → `Core/OXPVerifier/OOOXPVerifier.cpp` (690 / 733 lines) — 15✅ 3⚠️ 4❌ 1➖ — [findings](oxpverifier.md#oooxpverifier)
- [x] `Core/OXPVerifier/OOOXPVerifierStage.m` → `Core/OXPVerifier/OOOXPVerifierStage.cpp` (211 / 237 lines) — 18✅ 1⚠️ 2➖ — [findings](oxpverifier.md#oooxpverifierstage)
- [x] `Core/OXPVerifier/OOPListSchemaVerifier.m` → `Core/OXPVerifier/OOPListSchemaVerifier.cpp` (1393 / 1456 lines) — 39✅ 5⚠️ 1❌ 6➖ — [findings](oxpverifier.md#ooplistschemaverifier)
- [x] `Core/OXPVerifier/OOTextureVerifierStage.m` → `Core/OXPVerifier/OOTextureVerifierStage.cpp` (187 / 143 lines) — 5✅ 2❌ 3➖ — [findings](oxpverifier.md#ootextureverifierstage)

### Scripting (JS engine, OOJS*, legacy scripts, JS console) — [scripting.md](scripting.md)

- [x] `Core/Debug/OOJSConsole.m` → `Core/Debug/OOJSConsole.cpp` (1053 / 1294 lines) — 24✅ 5⚠️ 2❌ — [findings](scripting.md#oojsconsole)
- [x] `Core/Entities/PlayerEntityLegacyScriptEngine.m` → `Core/Entities/PlayerEntityLegacyScriptEngine.cpp` (2625 / 2772 lines) — 146✅ 6⚠️ 1❌ — [findings](scripting.md#playerentitylegacyscriptengine)
- [x] `Core/Scripting/EntityOOJavaScriptExtensions.m` → `Core/Scripting/EntityOOJavaScriptExtensions.cpp` (149 / 219 lines) — 9✅ 1❌ — [findings](scripting.md#entityoojavascriptextensions)
- [x] `Core/Scripting/OOConstToJSString.m` → `Core/Scripting/OOConstToJSString.cpp` (240 / 248 lines) — 9✅ — [findings](scripting.md#ooconsttojsstring)
- [x] `Core/Scripting/OOJSCall.m` → `Core/Scripting/OOJSCall.cpp` (229 / 333 lines) — 1✅ 1⚠️ 5➖ — [findings](scripting.md#oojscall)
- [x] `Core/Scripting/OOJSClock.m` → `Core/Scripting/OOJSClock.cpp` (229 / 324 lines) — 8✅ — [findings](scripting.md#oojsclock)
- [x] `Core/Scripting/OOJSDock.m` → `Core/Scripting/OOJSDock.cpp` (267 / 363 lines) — 11✅ — [findings](scripting.md#oojsdock)
- [x] `Core/Scripting/OOJSEngineDebuggerHelpers.m` → `Core/Scripting/OOJSEngineDebuggerHelpers.cpp` (235 / 240 lines) — 6✅ 2⚠️ — [findings](scripting.md#oojsenginedebuggerhelpers)
- [x] `Core/Scripting/OOJSEngineTimeManagement.m` → `Core/Scripting/OOJSEngineTimeManagement.cpp` (923 / 916 lines) — 49✅ 7⚠️ 1❌ 2➖ — [findings](scripting.md#oojsenginetimemanagement)
- [x] `Core/Scripting/OOJSEntity.m` → `Core/Scripting/OOJSEntity.cpp` (388 / 531 lines) — 14✅ — [findings](scripting.md#oojsentity)
- [x] `Core/Scripting/OOJSEquipmentInfo.m` → `Core/Scripting/OOJSEquipmentInfo.cpp` (528 / 700 lines) — 15✅ 1⚠️ 1❌ — [findings](scripting.md#oojsequipmentinfo)
- [x] `Core/Scripting/OOJSExhaustPlume.m` → `Core/Scripting/OOJSExhaustPlume.cpp` (214 / 306 lines) — 10✅ — [findings](scripting.md#oojsexhaustplume)
- [x] `Core/Scripting/OOJSFlasher.m` → `Core/Scripting/OOJSFlasher.cpp` (290 / 399 lines) — 10✅ — [findings](scripting.md#oojsflasher)
- [x] `Core/Scripting/OOJSFont.m` → `Core/Scripting/OOJSFont.cpp` (57 / 92 lines) — 2✅ — [findings](scripting.md#oojsfont)
- [x] `Core/Scripting/OOJSFrameCallbacks.m` → `Core/Scripting/OOJSFrameCallbacks.cpp` (435 / 468 lines) — 13✅ — [findings](scripting.md#oojsframecallbacks)
- [x] `Core/Scripting/OOJSFunction.m` → `Core/Scripting/OOJSFunction.cpp` (241 / 180 lines) — 8✅ 1❌ 3➖ — [findings](scripting.md#oojsfunction)
- [x] `Core/Scripting/OOJSGlobal.m` → `Core/Scripting/OOJSGlobal.cpp` (789 / 1043 lines) — 24✅ 2❌ — [findings](scripting.md#oojsglobal)
- [x] `Core/Scripting/OOJSGuiScreenKeyDefinition.m` → `Core/Scripting/OOJSGuiScreenKeyDefinition.cpp` (150 / 172 lines) — 13✅ — [findings](scripting.md#oojsguiscreenkeydefinition)
- [x] `Core/Scripting/OOJSInterfaceDefinition.m` → `Core/Scripting/OOJSInterfaceDefinition.cpp` (166 / 178 lines) — 15✅ — [findings](scripting.md#oojsinterfacedefinition)
- [x] `Core/Scripting/OOJSManifest.m` → `Core/Scripting/OOJSManifest.cpp` (292 / 364 lines) — 10✅ 1❌ 3➖ — [findings](scripting.md#oojsmanifest)
- [x] `Core/Scripting/OOJSMission.m` → `Core/Scripting/OOJSMission.cpp` (668 / 858 lines) — 17✅ 1⚠️ — [findings](scripting.md#oojsmission)
- [x] `Core/Scripting/OOJSMissionVariables.m` → `Core/Scripting/OOJSMissionVariables.cpp` (205 / 309 lines) — 6✅ 1⚠️ 1❌ — [findings](scripting.md#oojsmissionvariables)
- [x] `Core/Scripting/OOJSOolite.m` → `Core/Scripting/OOJSOolite.cpp` (311 / 469 lines) — 8✅ 1❌ — [findings](scripting.md#oojsoolite)
- [x] `Core/Scripting/OOJSPlanet.m` → `Core/Scripting/OOJSPlanet.cpp` (293 / 428 lines) — 8✅ — [findings](scripting.md#oojsplanet)
- [x] `Core/Scripting/OOJSPlayer.m` → `Core/Scripting/OOJSPlayer.cpp` (683 / 894 lines) — 25✅ — [findings](scripting.md#oojsplayer)
- [x] `Core/Scripting/OOJSPlayerShip.m` → `Core/Scripting/OOJSPlayerShip.cpp` (1751 / 2149 lines) — 38✅ 1⚠️ 1❌ — [findings](scripting.md#oojsplayership)
- [x] `Core/Scripting/OOJSPopulatorDefinition.m` → `Core/Scripting/OOJSPopulatorDefinition.cpp` (125 / 171 lines) — 8✅ — [findings](scripting.md#oojspopulatordefinition)
- [x] `Core/Scripting/OOJSQuaternion.m` → `Core/Scripting/OOJSQuaternion.cpp` (925 / 980 lines) — 32✅ — [findings](scripting.md#oojsquaternion)
- [x] `Core/Scripting/OOJSScript.m` → `Core/Scripting/OOJSScript.cpp` (761 / 889 lines) — 29✅ 4⚠️ 2➖ — [findings](scripting.md#oojsscript)
- [x] `Core/Scripting/OOJSShip.m` → `Core/Scripting/OOJSShip.cpp` (4015 / 4311 lines) — 95✅ 2⚠️ 3❌ — [findings](scripting.md#oojsship)
- [x] `Core/Scripting/OOJSShipGroup.m` → `Core/Scripting/OOJSShipGroup.cpp` (347 / 510 lines) — 13✅ — [findings](scripting.md#oojsshipgroup)
- [x] `Core/Scripting/OOJSSound.m` → `Core/Scripting/OOJSSound.cpp` (299 / 452 lines) — 14✅ 1⚠️ — [findings](scripting.md#oojssound)
- [x] `Core/Scripting/OOJSSoundSource.m` → `Core/Scripting/OOJSSoundSource.cpp` (345 / 483 lines) — 12✅ 1⚠️ — [findings](scripting.md#oojssoundsource)
- [x] `Core/Scripting/OOJSSpecialFunctions.m` → `Core/Scripting/OOJSSpecialFunctions.cpp` (101 / 104 lines) — 5✅ — [findings](scripting.md#oojsspecialfunctions)
- [x] `Core/Scripting/OOJSStation.m` → `Core/Scripting/OOJSStation.cpp` (1085 / 1396 lines) — 29✅ 2❌ — [findings](scripting.md#oojsstation)
- [x] `Core/Scripting/OOJSSun.m` → `Core/Scripting/OOJSSun.cpp` (179 / 253 lines) — 10✅ — [findings](scripting.md#oojssun)
- [x] `Core/Scripting/OOJSSystem.m` → `Core/Scripting/OOJSSystem.cpp` (1535 / 1869 lines) — 40✅ 2❌ — [findings](scripting.md#oojssystem)
- [x] `Core/Scripting/OOJSSystemInfo.m` → `Core/Scripting/OOJSSystemInfo.cpp` (738 / 1009 lines) — 30✅ 1⚠️ 2❌ 2➖ — [findings](scripting.md#oojssysteminfo)
- [x] `Core/Scripting/OOJSTimer.m` → `Core/Scripting/OOJSTimer.cpp` (419 / 545 lines) — 17✅ 1⚠️ 1❌ — [findings](scripting.md#oojstimer)
- [x] `Core/Scripting/OOJSVector.m` → `Core/Scripting/OOJSVector.cpp` (1225 / 1343 lines) — 42✅ 3⚠️ — [findings](scripting.md#oojsvector)
- [x] `Core/Scripting/OOJSVisualEffect.m` → `Core/Scripting/OOJSVisualEffect.cpp` (682 / 915 lines) — 18✅ — [findings](scripting.md#oojsvisualeffect)
- [x] `Core/Scripting/OOJSWaypoint.m` → `Core/Scripting/OOJSWaypoint.cpp` (250 / 345 lines) — 9✅ — [findings](scripting.md#oojswaypoint)
- [x] `Core/Scripting/OOJSWorldScripts.m` → `Core/Scripting/OOJSWorldScripts.cpp` (110 / 164 lines) — 3✅ 1⚠️ — [findings](scripting.md#oojsworldscripts)
- [x] `Core/Scripting/OOJSWormhole.m` → `Core/Scripting/OOJSWormhole.cpp` (196 / 272 lines) — 9✅ — [findings](scripting.md#oojswormhole)
- [x] `Core/Scripting/OOJavaScriptEngine.m` → `Core/Scripting/OOJavaScriptEngine.cpp` (2322 / 2206 lines) — 89✅ 11⚠️ 5❌ 13➖ — [findings](scripting.md#oojavascriptengine)
- [x] `Core/Scripting/OOLegacyScriptWhitelist.m` → `Core/Scripting/OOLegacyScriptWhitelist.cpp` (515 / 587 lines) — 14✅ 2❌ — [findings](scripting.md#oolegacyscriptwhitelist)
- [x] `Core/Scripting/OOPListScript.m` → `Core/Scripting/OOPListScript.cpp` (193 / 185 lines) — 4✅ 4⚠️ 1❌ 1➖ — [findings](scripting.md#ooplistscript)
- [x] `Core/Scripting/OOScript.m` → `Core/Scripting/OOScript.cpp` (271 / 339 lines) — 12✅ 1⚠️ — [findings](scripting.md#ooscript)
- [x] `Core/Scripting/OOScriptTimer.m` → `Core/Scripting/OOScriptTimer.cpp` (244 / 280 lines) — 18✅ — [findings](scripting.md#ooscripttimer)

### Player entity and its categories — [entities-player.md](entities-player.md)

- [x] `Core/Entities/PlayerEntity.m` → `Core/Entities/PlayerEntity.cpp` (11911 / 12466 lines) — 468✅ 14⚠️ 7❌ 3➖ — [findings](entities-player.md#playerentity)
- [x] `Core/Entities/PlayerEntityContracts.m` → `Core/Entities/PlayerEntityContracts.cpp` (1775 / 1898 lines) — 40✅ 1⚠️ — [findings](entities-player.md#playerentitycontracts)
- [x] `Core/Entities/PlayerEntityControls.m` → `Core/Entities/PlayerEntityControls.cpp` (4813 / 4962 lines) — 40✅ 6⚠️ 4❌ — [findings](entities-player.md#playerentitycontrols)
- [x] `Core/Entities/PlayerEntityKeyMapper.m` → `Core/Entities/PlayerEntityKeyMapper.cpp` (1611 / 1719 lines) — 40✅ 1⚠️ 2❌ — [findings](entities-player.md#playerentitykeymapper)
- [x] `Core/Entities/PlayerEntityLoadSave.m` → `Core/Entities/PlayerEntityLoadSave.cpp` (1181 / 1287 lines) — 23✅ 2⚠️ 1❌ — [findings](entities-player.md#playerentityloadsave)
- [x] `Core/Entities/PlayerEntityScriptMethods.m` → `Core/Entities/PlayerEntityScriptMethods.cpp` (576 / 608 lines) — 35✅ — [findings](entities-player.md#playerentityscriptmethods)
- [x] `Core/Entities/PlayerEntitySound.m` → `Core/Entities/PlayerEntitySound.cpp` (654 / 706 lines) — 86✅ — [findings](entities-player.md#playerentitysound)
- [x] `Core/Entities/PlayerEntityStickMapper.m` → `Core/Entities/PlayerEntityStickMapper.cpp` (856 / 747 lines) — 12✅ 1❌ — [findings](entities-player.md#playerentitystickmapper)
- [x] `Core/Entities/PlayerEntityStickProfile.m` → `Core/Entities/PlayerEntityStickProfile.cpp` (597 / 566 lines) — 26✅ 1➖ — [findings](entities-player.md#playerentitystickprofile)
- [x] `Core/Entities/ProxyPlayerEntity.m` → `Core/Entities/ProxyPlayerEntity.cpp` (208 / 194 lines) — 27✅ 2➖ — [findings](entities-player.md#proxyplayerentity)

### Ship, station, dock entities — [entities-ship.md](entities-ship.md)

- [x] `Core/Entities/DockEntity.m` → `Core/Entities/DockEntity.cpp` (1170 / 1278 lines) — 41✅ 1⚠️ 1❌ — [findings](entities-ship.md#dockentity)
- [x] `Core/Entities/ShipEntity.m` → `Core/Entities/ShipEntity.cpp` (13041 / 13775 lines) — 627✅ 5⚠️ 11❌ 8➖ — [findings](entities-ship.md#shipentity)
- [x] `Core/Entities/ShipEntityAI.m` → `Core/Entities/ShipEntityAI.cpp` (2558 / 2563 lines) — 154✅ 2⚠️ — [findings](entities-ship.md#shipentityai)
- [x] `Core/Entities/ShipEntityLoadRestore.m` → `Core/Entities/ShipEntityLoadRestore.cpp` (358 / 412 lines) — 6✅ 1❌ — [findings](entities-ship.md#shipentityloadrestore)
- [x] `Core/Entities/ShipEntityScriptMethods.m` → `Core/Entities/ShipEntityScriptMethods.cpp` (92 / 97 lines) — 3✅ — [findings](entities-ship.md#shipentityscriptmethods)
- [x] `Core/Entities/StationEntity.m` → `Core/Entities/StationEntity.cpp` (2185 / 2338 lines) — 107✅ 2⚠️ 1❌ 2➖ — [findings](entities-ship.md#stationentity)

### Other entities (planets, effects, particles, base Entity) — [entities-other.md](entities-other.md)

- [x] `Core/Entities/DustEntity.m` → `Core/Entities/DustEntity.cpp` (418 / 430 lines) — 13✅ 1❌ — [findings](entities-other.md#dustentity)
- [x] `Core/Entities/Entity.m` → `Core/Entities/Entity.cpp` (1055 / 1152 lines) — 105✅ 1❌ — [findings](entities-other.md#entity)
- [x] `Core/Entities/EntityShaderBindings.m` → `Core/Entities/EntityShaderBindings.cpp` (77 / 421 lines) — 12✅ 2❌ — [findings](entities-other.md#entityshaderbindings)
- [x] `Core/Entities/OOBreakPatternEntity.m` → `Core/Entities/OOBreakPatternEntity.cpp` (169 / 151 lines) — 8✅ 2➖ — [findings](entities-other.md#oobreakpatternentity)
- [x] `Core/Entities/OOECMBlastEntity.m` → `Core/Entities/OOECMBlastEntity.cpp` (123 / 118 lines) — 4✅ 1➖ — [findings](entities-other.md#ooecmblastentity)
- [x] `Core/Entities/OOEntityWithDrawable.m` → `Core/Entities/OOEntityWithDrawable.cpp` (122 / 120 lines) — 5✅ 1➖ — [findings](entities-other.md#ooentitywithdrawable)
- [x] `Core/Entities/OOExhaustPlumeEntity.m` → `Core/Entities/OOExhaustPlumeEntity.cpp` (681 / 694 lines) — 16✅ 1❌ 1➖ — [findings](entities-other.md#ooexhaustplumeentity)
- [x] `Core/Entities/OOExplosionCloudEntity.m` → `Core/Entities/OOExplosionCloudEntity.cpp` (252 / 247 lines) — 5✅ 1➖ — [findings](entities-other.md#ooexplosioncloudentity)
- [x] `Core/Entities/OOFlashEffectEntity.m` → `Core/Entities/OOFlashEffectEntity.cpp` (140 / 144 lines) — 8✅ 1❌ — [findings](entities-other.md#ooflasheffectentity)
- [x] `Core/Entities/OOFlasherEntity.m` → `Core/Entities/OOFlasherEntity.cpp` (217 / 217 lines) — 19✅ 1⚠️ 2➖ — [findings](entities-other.md#ooflasherentity)
- [x] `Core/Entities/OOLaserShotEntity.m` → `Core/Entities/OOLaserShotEntity.cpp` (315 / 316 lines) — 14✅ 1❌ 1➖ — [findings](entities-other.md#oolasershotentity)
- [x] `Core/Entities/OOLightParticleEntity.m` → `Core/Entities/OOLightParticleEntity.cpp` (329 / 334 lines) — 13✅ 1❌ — [findings](entities-other.md#oolightparticleentity)
- [x] `Core/Entities/OOParticleSystem.m` → `Core/Entities/OOParticleSystem.cpp` (353 / 354 lines) — 14✅ 1⚠️ 1➖ — [findings](entities-other.md#ooparticlesystem)
- [x] `Core/Entities/OOPlanetEntity.m` → `Core/Entities/OOPlanetEntity.cpp` (1052 / 1164 lines) — 49✅ 2⚠️ — [findings](entities-other.md#ooplanetentity)
- [x] `Core/Entities/OOPlasmaBurstEntity.m` → `Core/Entities/OOPlasmaBurstEntity.cpp` (62 / 67 lines) — 2✅ — [findings](entities-other.md#ooplasmaburstentity)
- [x] `Core/Entities/OOPlasmaShotEntity.m` → `Core/Entities/OOPlasmaShotEntity.cpp` (113 / 128 lines) — 4✅ — [findings](entities-other.md#ooplasmashotentity)
- [x] `Core/Entities/OOQuiriumCascadeEntity.m` → `Core/Entities/OOQuiriumCascadeEntity.cpp` (165 / 161 lines) — 9✅ 1➖ — [findings](entities-other.md#ooquiriumcascadeentity)
- [x] `Core/Entities/OORingEffectEntity.m` → `Core/Entities/OORingEffectEntity.cpp` (157 / 170 lines) — 9✅ — [findings](entities-other.md#ooringeffectentity)
- [x] `Core/Entities/OOSparkEntity.m` → `Core/Entities/OOSparkEntity.cpp` (81 / 86 lines) — 3✅ — [findings](entities-other.md#oosparkentity)
- [x] `Core/Entities/OOSunEntity.m` → `Core/Entities/OOSunEntity.cpp` (738 / 775 lines) — 29✅ 1➖ — [findings](entities-other.md#oosunentity)
- [x] `Core/Entities/OOVisualEffectEntity.m` → `Core/Entities/OOVisualEffectEntity.cpp` (875 / 985 lines) — 81✅ 1❌ 1➖ — [findings](entities-other.md#oovisualeffectentity)
- [x] `Core/Entities/OOWaypointEntity.m` → `Core/Entities/OOWaypointEntity.cpp` (289 / 284 lines) — 20✅ 1❌ 1➖ — [findings](entities-other.md#oowaypointentity)
- [x] `Core/Entities/PlanetEntity.m` → *(no counterpart; check whether upstream builds it)* (1498 / — 51➖ — [findings](entities-other.md#planetentity)
- [x] `Core/Entities/SkyEntity.m` → `Core/Entities/SkyEntity.cpp` (313 / 319 lines) — 13✅ — [findings](entities-other.md#skyentity)
- [x] `Core/Entities/WormholeEntity.m` → `Core/Entities/WormholeEntity.cpp` (802 / 857 lines) — 38✅ — [findings](entities-other.md#wormholeentity)

### Sound and music — [sound.md](sound.md)

- [x] `Core/OOALBufferedSound.m` → `Core/OOALBufferedSound.cpp` (94 / 91 lines) — 4✅ — [findings](sound.md#ooalbufferedsound)
- [x] `Core/OOALMusic.m` → `Core/OOALMusic.cpp` (117 / 113 lines) — 9✅ 1➖ — [findings](sound.md#ooalmusic)
- [x] `Core/OOALSound.m` → `Core/OOALSound.cpp` (164 / 191 lines) — 10✅ 1❌ 1➖ — [findings](sound.md#ooalsound)
- [x] `Core/OOALSoundChannel.m` → `Core/OOALSoundChannel.cpp` (223 / 215 lines) — 14✅ — [findings](sound.md#ooalsoundchannel)
- [x] `Core/OOALSoundDecoder.m` → `Core/OOALSoundDecoder.cpp` (461 / 482 lines) — 21✅ 1➖ — [findings](sound.md#ooalsounddecoder)
- [x] `Core/OOALSoundMixer.m` → `Core/OOALSoundMixer.cpp` (158 / 124 lines) — 5✅ 1⚠️ 6➖ — [findings](sound.md#ooalsoundmixer)
- [x] `Core/OOALStreamedSound.m` → `Core/OOALStreamedSound.cpp` (114 / 111 lines) — 6✅ — [findings](sound.md#ooalstreamedsound)
- [x] `Core/OOBasicSoundReferencePoint.m` → `Core/OOBasicSoundReferencePoint.cpp` (41 / 37 lines) — 3✅ — [findings](sound.md#oobasicsoundreferencepoint)
- [x] `Core/OOMusic.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 1➖ — [findings](sound.md#oomusic)
- [x] `Core/OOMusicController.m` → `Core/OOMusicController.cpp` (361 / 305 lines) — 25✅ 6➖ — [findings](sound.md#oomusiccontroller)
- [x] `Core/OOOpenALController.m` → `Core/OOOpenALController.cpp` (102 / 96 lines) — 5✅ — [findings](sound.md#ooopenalcontroller)
- [x] `Core/OOSoundSource.m` → `Core/OOSoundSource.cpp` (299 / 333 lines) — 31✅ 1⚠️ — [findings](sound.md#oosoundsource)
- [x] `Core/OOSoundSourcePool.m` → `Core/OOSoundSourcePool.cpp` (249 / 238 lines) — 12✅ — [findings](sound.md#oosoundsourcepool)

### Materials, textures, meshes, drawables, OpenGL — [graphics.md](graphics.md)

- [x] `Core/Materials/OOBasicMaterial.m` → `Core/Materials/OOBasicMaterial.cpp` (314 / 320 lines) — 32✅ 1⚠️ — [findings](graphics.md#oobasicmaterial)
- [x] `Core/Materials/OOCombinedEmissionMapGenerator.m` → `Core/Materials/OOCombinedEmissionMapGenerator.cpp` (446 / 441 lines) — 12✅ 1❌ — [findings](graphics.md#oocombinedemissionmapgenerator)
- [x] `Core/Materials/OOConcreteTexture.m` → `Core/Materials/OOConcreteTexture.cpp` (641 / 638 lines) — 26✅ — [findings](graphics.md#ooconcretetexture)
- [x] `Core/Materials/OODefaultShaderSynthesizer.m` → `Core/Materials/OODefaultShaderSynthesizer.cpp` (1451 / 1265 lines) — 46✅ 1⚠️ — [findings](graphics.md#oodefaultshadersynthesizer)
- [x] `Core/Materials/OOMaterial.m` → `Core/Materials/OOMaterial.cpp` (140 / 184 lines) — 15✅ 1⚠️ — [findings](graphics.md#oomaterial)
- [x] `Core/Materials/OOMaterialConvenienceCreators.m` → `Core/Materials/OOMaterialConvenienceCreators.cpp` (539 / 575 lines) — 14✅ 1❌ — [findings](graphics.md#oomaterialconveniencecreators)
- [x] `Core/Materials/OOMaterialSpecifier.m` → `Core/Materials/OOMaterialSpecifier.cpp` (256 / 246 lines) — 24✅ — [findings](graphics.md#oomaterialspecifier)
- [x] `Core/Materials/OOMultiTextureMaterial.m` → `Core/Materials/OOMultiTextureMaterial.cpp` (204 / 221 lines) — 7✅ 1⚠️ 1❌ — [findings](graphics.md#oomultitexturematerial)
- [x] `Core/Materials/OONullTexture.m` → `Core/Materials/OONullTexture.cpp` (116 / 78 lines) — 6✅ 6➖ — [findings](graphics.md#oonulltexture)
- [x] `Core/Materials/OOPNGTextureLoader.m` → `Core/Materials/OOPNGTextureLoader.cpp` (221 / 225 lines) — 7✅ — [findings](graphics.md#oopngtextureloader)
- [x] `Core/Materials/OOPixMap.m` → `Core/Materials/OOPixMap.cpp` (242 / 235 lines) — 12✅ — [findings](graphics.md#oopixmap)
- [x] `Core/Materials/OOPixMapChannelOperations.m` → `Core/Materials/OOPixMapChannelOperations.cpp` (331 / 353 lines) — 11✅ — [findings](graphics.md#oopixmapchanneloperations)
- [x] `Core/Materials/OOPixMapTextureLoader.m` → `Core/Materials/OOPixMapTextureLoader.cpp` (86 / 91 lines) — 4✅ — [findings](graphics.md#oopixmaptextureloader)
- [x] `Core/Materials/OOPlanetTextureGenerator.m` → `Core/Materials/OOPlanetTextureGenerator.cpp` (1261 / 1258 lines) — 50✅ 1⚠️ 1❌ — [findings](graphics.md#ooplanettexturegenerator)
- [x] `Core/Materials/OOShaderMaterial.m` → `Core/Materials/OOShaderMaterial.cpp` (794 / 770 lines) — 20✅ 3⚠️ 1❌ — [findings](graphics.md#ooshadermaterial)
- [x] `Core/Materials/OOShaderProgram.m` → `Core/Materials/OOShaderProgram.cpp` (472 / 553 lines) — 12✅ — [findings](graphics.md#ooshaderprogram)
- [x] `Core/Materials/OOShaderUniform.m` → `Core/Materials/OOShaderUniform.cpp` (542 / 554 lines) — 10✅ 2⚠️ 2❌ — [findings](graphics.md#ooshaderuniform)
- [x] `Core/Materials/OOShaderUniformMethodType.m` → `Core/Materials/OOShaderUniformMethodType.cpp` (280 / 125 lines) — 2⚠️ 19➖ — [findings](graphics.md#ooshaderuniformmethodtype)
- [x] `Core/Materials/OOSingleTextureMaterial.m` → `Core/Materials/OOSingleTextureMaterial.cpp` (115 / 129 lines) — 9✅ 1⚠️ — [findings](graphics.md#oosingletexturematerial)
- [x] `Core/Materials/OOStandaloneAtmosphereGenerator.m` → `Core/Materials/OOStandaloneAtmosphereGenerator.cpp` (753 / 758 lines) — 24✅ 1⚠️ 1❌ — [findings](graphics.md#oostandaloneatmospheregenerator)
- [x] `Core/Materials/OOTexture.m` → `Core/Materials/OOTexture.cpp` (884 / 889 lines) — 41✅ 1⚠️ 2❌ 8➖ — [findings](graphics.md#ootexture)
- [x] `Core/Materials/OOTextureGenerator.m` → `Core/Materials/OOTextureGenerator.cpp` (58 / 55 lines) — 5✅ — [findings](graphics.md#ootexturegenerator)
- [x] `Core/Materials/OOTextureLoader.m` → `Core/Materials/OOTextureLoader.cpp` (505 / 554 lines) — 18✅ 1❌ — [findings](graphics.md#ootextureloader)
- [x] `Core/OOConvertCubeMapToLatLong.m` → `Core/OOConvertCubeMapToLatLong.cpp` (146 / 148 lines) — 1✅ — [findings](graphics.md#ooconvertcubemaptolatlong)
- [x] `Core/OODebugGLDrawing.m` → `Core/OODebugGLDrawing.cpp` (160 / 164 lines) — 7✅ — [findings](graphics.md#oodebuggldrawing)
- [x] `Core/OODrawable.m` → `Core/OODrawable.cpp` (86 / 116 lines) — 10✅ 1⚠️ — [findings](graphics.md#oodrawable)
- [x] `Core/OOEnvironmentCubeMap.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 10➖ — [findings](graphics.md#ooenvironmentcubemap)
- [x] `Core/OOGraphicsResetManager.m` → `Core/OOGraphicsResetManager.cpp` (136 / 99 lines) — 4✅ 1⚠️ 6➖ — [findings](graphics.md#oographicsresetmanager)
- [x] `Core/OOMesh.m` → `Core/OOMesh.cpp` (2078 / 1973 lines) — 62✅ 3⚠️ 1❌ — [findings](graphics.md#oomesh)
- [x] `Core/OOOpenGL.m` → `Core/OOOpenGL.cpp` (552 / 574 lines) — 24✅ — [findings](graphics.md#ooopengl)
- [x] `Core/OOOpenGLExtensionManager.m` → `Core/OOOpenGLExtensionManager.cpp` (818 / 775 lines) — 33✅ 1⚠️ 6➖ — [findings](graphics.md#ooopenglextensionmanager)
- [x] `Core/OOOpenGLMatrixManager.m` → `Core/OOOpenGLMatrixManager.cpp` (591 / 597 lines) — 60✅ — [findings](graphics.md#ooopenglmatrixmanager)
- [x] `Core/OOOpenGLStateManager.m` → `Core/OOOpenGLStateManager.cpp` (629 / 648 lines) — 18✅ — [findings](graphics.md#ooopenglstatemanager)
- [x] `Core/OOPlanetDrawable.m` → `Core/OOPlanetDrawable.cpp` (389 / 374 lines) — 29✅ 1➖ — [findings](graphics.md#ooplanetdrawable)
- [x] `Core/OOPolygonSprite.m` → `Core/OOPolygonSprite.cpp` (862 / 874 lines) — 27✅ 1❌ — [findings](graphics.md#oopolygonsprite)
- [x] `Core/OOProbabilisticTextureManager.m` → `Core/OOProbabilisticTextureManager.cpp` (229 / 239 lines) — 8✅ 1❌ — [findings](graphics.md#ooprobabilistictexturemanager)
- [x] `Core/OOSkyDrawable.m` → `Core/OOSkyDrawable.cpp` (685 / 679 lines) — 23✅ 1⚠️ — [findings](graphics.md#ooskydrawable)
- [x] `Core/OOTextureScaling.m` → `Core/OOTextureScaling.cpp` (1578 / 1605 lines) — 23✅ 6⚠️ 1❌ — [findings](graphics.md#ootexturescaling)
- [x] `Core/OOTextureSprite.m` → `Core/OOTextureSprite.cpp` (115 / 106 lines) — 7✅ — [findings](graphics.md#ootexturesprite)
- [x] `Core/TextureStore.m` → *(absorbed into `src/oofnd/` or callers; see findings)* — 9➖ — [findings](graphics.md#texturestore)

### HUD, GUI, crosshairs — [hud-gui.md](hud-gui.md)

- [x] `Core/GuiDisplayGen.m` → `Core/GuiDisplayGen.cpp` (2318 / 2407 lines) — 84✅ 2⚠️ 2❌ — [findings](hud-gui.md#guidisplaygen)
- [x] `Core/HeadUpDisplay.m` → `Core/HeadUpDisplay.cpp` (4172 / 4302 lines) — 133✅ 2❌ 4➖ — [findings](hud-gui.md#headupdisplay)
- [x] `Core/OOCrosshairs.m` → `Core/OOCrosshairs.cpp` (188 / 150 lines) — 5✅ — [findings](hud-gui.md#oocrosshairs)
- [x] `Core/OOMouseInteractionMode.m` → `Core/OOMouseInteractionMode.cpp` (74 / 77 lines) — 3✅ — [findings](hud-gui.md#oomouseinteractionmode)

### Universe and GameController — [universe.md](universe.md)

- [x] `Core/GameController.m` → `Core/GameController.cpp` (902 / 1193 lines) — 50✅ 5⚠️ 3❌ 2➖ — [findings](universe.md#gamecontroller)
- [x] `Core/Universe.m` → `Core/Universe.cpp` (10137 / 10879 lines) — 351✅ 10⚠️ 10❌ 3➖ — [findings](universe.md#universe)

### SDL platform, input devices, debug support — [platform.md](platform.md)

- [x] `Core/Debug/OODebugMonitor.m` → `Core/Debug/OODebugMonitor.cpp` (932 / 873 lines) — 33✅ 3⚠️ 8➖ — [findings](platform.md#oodebugmonitor)
- [x] `Core/Debug/OODebugStandards.m` → `Core/Debug/OODebugStandards.cpp` (122 / 137 lines) — 7✅ — [findings](platform.md#oodebugstandards)
- [x] `Core/Debug/OODebugSupport.m` → `Core/Debug/OODebugSupport.cpp` (135 / 87 lines) — 1✅ 1➖ — [findings](platform.md#oodebugsupport)
- [x] `Core/Debug/OODebugTCPConsoleClient.m` → `Core/Debug/OODebugTCPConsoleClient.cpp` (674 / 998 lines) — 28✅ 4⚠️ 1❌ 1➖ — [findings](platform.md#oodebugtcpconsoleclient)
- [x] `Core/Debug/OOTCPStreamDecoderAbstractionLayer.m` → `Core/Debug/OOTCPStreamDecoderAbstractionLayer.cpp` (112 / 192 lines) — 12✅ 1⚠️ 1❌ — [findings](platform.md#ootcpstreamdecoderabstractionlayer)
- [x] `Core/OOFullScreenController.m` → `Core/OOFullScreenController.cpp` (95 / 88 lines) — 9✅ 1❌ 1➖ — [findings](platform.md#oofullscreencontroller)
- [x] `Core/OOJoystickManager.m` → `Core/OOJoystickManager.cpp` (525 / 629 lines) — 31✅ 2⚠️ — [findings](platform.md#oojoystickmanager)
- [x] `Core/OOJoystickProfile.m` → `Core/OOJoystickProfile.cpp` (549 / 509 lines) — 40✅ — [findings](platform.md#oojoystickprofile)
- [x] `SDL/GameController+SDLFullScreen.m` → `SDL/GameController+SDLFullScreen.cpp` (155 / 155 lines) — 8✅ 1⚠️ — [findings](platform.md#gamecontrollersdlfullscreen)
- [x] `SDL/MyOpenGLView+Input.m` → `SDL/MyOpenGLView+Input.cpp` (889 / 914 lines) — 33✅ 1❌ — [findings](platform.md#myopenglviewinput)
- [x] `SDL/MyOpenGLView.m` → `SDL/MyOpenGLView.cpp` (1397 / 1387 lines) — 62✅ 2⚠️ 1❌ — [findings](platform.md#myopenglview)
- [x] `SDL/OOSDLJoystickManager.m` → `SDL/OOSDLJoystickManager.cpp` (290 / 165 lines) — 11✅ 1⚠️ 1➖ — [findings](platform.md#oosdljoystickmanager)
- [x] `SDL/main.m` → `SDL/main.cpp` (232 / 256 lines) — 1❌ — [findings](platform.md#main)

### Game data, resources, registries, AI, strings — [gamedata.md](gamedata.md)

- [x] `Core/AI.m` → `Core/AI.cpp` (930 / 948 lines) — 41✅ 6⚠️ 2❌ 2➖ — [findings](gamedata.md#ai)
- [x] `Core/AIGraphViz.m` → `Core/AIGraphViz.cpp` (233 / 243 lines) — 4✅ 2⚠️ — [findings](gamedata.md#aigraphviz)
- [x] `Core/OOCharacter.m` → `Core/OOCharacter.cpp` (450 / 491 lines) — 29✅ 1⚠️ 1➖ — [findings](gamedata.md#oocharacter)
- [x] `Core/OOColor.m` → `Core/OOColor.cpp` (497 / 550 lines) — 47✅ 1⚠️ 1➖ — [findings](gamedata.md#oocolor)
- [x] `Core/OOCommodities.m` → `Core/OOCommodities.cpp` (534 / 581 lines) — 16✅ 6⚠️ 1➖ — [findings](gamedata.md#oocommodities)
- [x] `Core/OOCommodityMarket.m` → `Core/OOCommodityMarket.cpp` (354 / 350 lines) — 25✅ 3⚠️ 1➖ — [findings](gamedata.md#oocommoditymarket)
- [x] `Core/OOConstToString.m` → `Core/OOConstToString.cpp` (592 / 621 lines) — 43✅ 5❌ — [findings](gamedata.md#ooconsttostring)
- [x] `Core/OOConvertSystemDescriptions.m` → `Core/OOConvertSystemDescriptions.cpp` (352 / 305 lines) — 8✅ 3⚠️ — [findings](gamedata.md#ooconvertsystemdescriptions)
- [x] `Core/OOEntityFilterPredicate.m` → `Core/OOEntityFilterPredicate.cpp` (169 / 185 lines) — 19✅ 1➖ — [findings](gamedata.md#ooentityfilterpredicate)
- [x] `Core/OOEquipmentType.m` → `Core/OOEquipmentType.cpp` (748 / 704 lines) — 59✅ 1⚠️ 6❌ 6➖ — [findings](gamedata.md#ooequipmenttype)
- [x] `Core/OOOXZManager.m` → `Core/OOOXZManager.cpp` (2066 / 2256 lines) — 61✅ 5⚠️ 3❌ 3➖ — [findings](gamedata.md#oooxzmanager)
- [x] `Core/OOProbabilitySet.m` → `Core/OOProbabilitySet.cpp` (957 / 753 lines) — 53✅ 2⚠️ 1❌ 25➖ — [findings](gamedata.md#ooprobabilityset)
- [x] `Core/OORoleSet.m` → `Core/OORoleSet.cpp` (331 / 280 lines) — 14✅ 4⚠️ 1❌ 3➖ — [findings](gamedata.md#ooroleset)
- [x] `Core/OOShipGroup.m` → `Core/OOShipGroup.cpp` (481 / 440 lines) — 24✅ 1⚠️ 7➖ — [findings](gamedata.md#ooshipgroup)
- [x] `Core/OOShipLibraryDescriptions.m` → `Core/OOShipLibraryDescriptions.cpp` (156 / 174 lines) — 11✅ — [findings](gamedata.md#ooshiplibrarydescriptions)
- [x] `Core/OOShipRegistry.m` → `Core/OOShipRegistry.cpp` (1626 / 1541 lines) — 36✅ 7⚠️ 8➖ — [findings](gamedata.md#ooshipregistry)
- [x] `Core/OOStringExpander.m` → `Core/OOStringExpander.cpp` (1191 / 1452 lines) — 33✅ 5⚠️ 3❌ — [findings](gamedata.md#oostringexpander)
- [x] `Core/OOStringParsing.m` → `Core/OOStringParsing.cpp` (528 / 443 lines) — 21✅ 1⚠️ 2❌ — [findings](gamedata.md#oostringparsing)
- [x] `Core/OOSystemDescriptionManager.m` → `Core/OOSystemDescriptionManager.cpp` (615 / 616 lines) — 28✅ 1⚠️ 2➖ — [findings](gamedata.md#oosystemdescriptionmanager)
- [x] `Core/OOTrumble.m` → `Core/OOTrumble.cpp` (970 / 957 lines) — 39✅ 1❌ 1➖ — [findings](gamedata.md#ootrumble)
- [x] `Core/ResourceManager.m` → `Core/ResourceManager.cpp` (1996 / 2129 lines) — 58✅ 8⚠️ 3❌ 2➖ — [findings](gamedata.md#resourcemanager)

### Extra rows

- [x] C sources and tables (`*.c`, `Tables/*.tbl`, `OOSaveEXRSnapshot.cpp`) verbatim check — ✅ identical except include/NDEBUG plumbing — [c-and-tables.md](c-and-tables.md)
- [x] C++-only files (`EntityHelpers`, `OOEntityCalledByName`, `OODataFromOXZFile`, `OOPListGameTypes`, `OOJSEngineNativeWrappers`, `OOJSPrivateObject`, `ooscript/JSEngine_quickjs.cpp`, `oofnd/Exception.cpp`, `oofnd/objc/OOAssert.cpp`) reviewed against what they replace — 8 files + dispatch-table completeness; 2 med ❌ (exception narrowing, `EntityShortDescription`) — [cpp-only.md](cpp-only.md)
- [x] Maths headers (`OOMaths.h`, `OOFastArithmetic.h`, inline functions in `OOVector.h`/`OOHPVector.h`/`OOQuaternion.h`/`OOMatrix.h`) — 11✅ 2⚠️ — [findings](math.md#oomaths)
- [x] Header constants sweep (`#define`, enums, default values across paired `.h`) — 238 header pairs, 857 defines, 948 enum values, 173 consts, 105 inlines: 0 ❌, 4 ⚠️ — [headers.md](headers.md)
