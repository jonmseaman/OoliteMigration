# Objective-C → C++ behavioural parity audit

Method-by-method comparison of the C++ port against the original Objective-C in `upstream/oolite/src`
(OoliteProject 1.93, unmodified). One row per upstream `.m` file; each has a coverage table with one row per method, and its findings.

- **Audited commit:** oolite-dev `seriesb/028-upstream-772-tests` @ `bf01f1b49`, on **2026-11-16**. Every port line number in this folder is for that commit.
- **Previous run:** 2026-10-27, against the late-October series tip. See [Changes since 2026-10-27](#changes-since-2026-10-27).
- **How to rerun it:** [METHOD.md](METHOD.md) (runbook for a coordinator agent), [AUDIT-BRIEF.md](AUDIT-BRIEF.md) (auditor instructions), [tools/extract_coverage.py](tools/extract_coverage.py).
- **Fix plan for 028:** [028-fix-plan.md](028-fix-plan.md).

**Legend:** ✅ equivalent · ⚠️ intentional divergence (cited) · ❌ suspected behaviour difference · ➖ removed/replaced

**Progress:** 241 / 241 upstream `.m` files, plus the maths headers, C/table files, C++-only files and the header sweep: **complete**.

**Totals across all coverage tables:** 7,461 rows: 6,395 ✅ · 286 ⚠️ · 198 ❌ · 582 ➖ (2026-10-27: 7,476 rows: 6,518 ✅ · 263 ⚠️ · 170 ❌ · 525 ➖).
The header sweep separately compared 889 `#define`s, 966 enum values, 173 constants and 110 inlines over 238 header pairs, and found 0 ❌.
Of the 198 ❌, **0 are high** and **12 are medium** (below); the rest are low (log text, nil-messaging edge cases, iteration order, unreachable paths).

**Method:** 29 auditor subagents, each assigned up to about 400 rows, read both sides method by method, following [AUDIT-BRIEF.md](AUDIT-BRIEF.md), and compared every previous finding against this commit. `tools/extract_coverage.py merge` recomputed every Status line from the Verdict column. The coordinator re-read every high and medium ❌ against both sources (✔), and every claim that a finding is fixed. One part's rows were filled in by an auditor's script rather than by hand (`entities-ship.md`: ShipEntityAI, StationEntity). It was spot-checked, and its counts match the previous run.

## Changes since 2026-10-27

**Fixed** (each re-checked on 028):
- ✔ **high:** NPC and demo-ship subentities (flashers, exhaust plumes) are updated again. Commit `b5d6be770`. [entities-ship.md](entities-ship.md#shipentity)
- ✔ **high:** JS `delete` on native-backed properties (`missionVariables`, `systemInfo`, `manifest`) reaches the class hook. Test `deletingAVariableTheScriptNeverSet`. [scripting.md](scripting.md#oojsmissionvariables)
- **med:** `mission.markSystem`/`unmarkSystem` with a marker that isn't a dictionary raise again. Commit `10504da05`. [scripting.md](scripting.md#oojsmission)
- **med:** the JS log class is no longer always `notAnError`. Warnings use `ooliteDefined`, and errors are `script.javaScript.exception.<Error.name>`; the scheme is documented in `ooscript/README.md`, so it is now ⚠️. [scripting.md](scripting.md#oojavascriptengine)
- **med:** script name resolution (the `with(this)` wrapper) and compile-error line numbers. [scripting.md](scripting.md#oojsscript), [scripting.md](scripting.md#oojsfunction)
- low: the watchdog data race (the thread is gone), `OOConstToJSString` underflow, the `unrootedTimer` function name, `OOJSValueToInt32` range, the alias `JOY*` enum, and the Mac `GetAppName`/`SetUpSparkle` items (that code was deleted).
- A correction to the previous run: the `addShips…atPosition` negative-count crash can't be reached, because the only caller rejects `number < 1` (`PlayerEntityLegacyScriptEngine.cpp:1730`). The `.at(0)` triggers below still make the exception item medium.

**Still open:** every other medium from 2026-10-27 (below), at new line numbers. `notes/2026-11-07 Parity Fixes.md` had one item wrong: the market-screen `quantityInHold[IndexOfGood]` write is **not** guarded on 028 (`PlayerEntity.cpp:11924-11928`; only the selected-commodity path at :11724 is).

**New:**
- ❌ **med:** the JS time limit is enforced exactly (it used to be checked once a second), so slow scripts and frame callbacks that survived upstream are now killed. [scripting.md](scripting.md#oojsenginetimemanagement)
- ⚠️ **med:** on macOS logs go to `./Logs` under the working directory, because the Mac log-folder code was removed in `352a4772f`. [foundation.md](foundation.md#oologoutputhandler)
- ⚠️ **med:** a script's top-level `var` and `function` declarations are local to that script; `ship.speed` is writable (rationale comment, no ADR). [scripting.md](scripting.md#oojsscript), [scripting.md](scripting.md#oojsship)
- ⚠️ **med:** the debug console's TCP connect has no time limit; `clearMappings` also resets the joystick GUI button table (#783). [platform.md](platform.md#oodebugtcpconsoleclient), [platform.md](platform.md#oojoystickmanager)
- ⚠️ low: rule 9 ("C stays C") no longer holds. Commit `48cbd7abf` made every upstream `.c` a `.cpp`; it was checked token by token and is equivalent. [c-and-tables.md](c-and-tables.md)
- About 30 new low ❌, mostly in scripting:
  - native setters that return `undefined` instead of the callee;
  - `system.filteredEntities` with a predicate that throws;
  - console settings enumeration;
  - `[x|precision:N]` with a negative N throws `std::format_error`;
  - `StringFromRandomSeed` prints signed bytes (commit `b84241785`);
  - the OXP scan resolves symlinked `.oxz` files and stops at the first unreadable folder;
  - repeated BOMs;
  - `EntityObjectSize` is a constant.

  Each is marked `(new)` in its area file.

## Cross-cutting findings

Patterns that recur across files. Each instance is also recorded in its own file's section.

1. ✔ **Preference defaults: `oo_*ForKey:defaultValue:` → `isNull() ? default : xForKey()`** (❌ **med**). Upstream's extractor returned `defaultValue` whenever the stored value could not be converted, such as a non-numeric or unrecognised string. The port returns the default only when the key is absent; otherwise the `Defaults` converter yields 0/NO. About 16 sites:
   - `GameController.cpp:235-238` (a malformed `animation_timer_interval` → 0 → the frame loop spins at ~10 kHz), `:291-293` (`ecoqos`)
   - `Universe.cpp:307-361` (FOV → MIN, detail level 0, procedural planets and ECM FX off)
   - `OOALSound.cpp:65-68` (`volume_control` → 0 mutes the game and is written back)
   - `OOLogging.cpp:228-243` (`logging-show-*` → NO drops the log prefixes)

   Bools also differ in parsing: `Defaults::boolForKey` uses GNUstep `-[NSString boolValue]`, where "on" and ".5" read NO. [foundation.md](foundation.md#oocollectionextractors), [universe.md](universe.md#universe), [universe.md](universe.md#gamecontroller)
2. **Hash order → sorted or insertion order.** Dictionaries and sets that upstream walked in GNUstep hash order are walked in key, byte or insertion order. This is intentional (⚠️, ADR-0043 / oo-3rb.154 / `WeakSet.hpp`) for populators, role probability sets, commodities, AI pending messages, `script.plist` order and ships on hold. It is unintended (❌ low) where only log order or overdraw changes: OXP verifier stages, waypoints, extension logs. `OORoleSet::anyRole` is the one medium.
3. **Two `doubleValue` ports.** `PListGet.hpp:166` (NSScanner style) and `Defaults.hpp:172` (`from_chars`) still disagree on long mantissas and huge exponents (❌ low). The game also decodes text with `decodeUnicodeText`, not the GNUstep-pinned `decodeUnicodeFile` (new, low).
4. **Log text drift.**
   - `__PRETTY_FUNCTION__` now prints C++ signatures where upstream printed `-[Class method]`: `entity.bug`, `joystick.configure.error`, mipmap and texture-manager errors, `OOMesh` render exceptions.
   - Shader logs name the class `Entity`.
   - `EntityShortDescription` drops the class and name (med).
   - Log-setup failures go to `unclassified`.
   - `verifyOXP.scanFiles.nonStandardFile` lost "(type)".
   - `plist.wrongType` and `savedGame.defaultPath.*` are gone.
5. **Standard-library exceptions are fatal.** Every catch site catches only `oo::Exception` (cross-cutting; see the Medium list).
6. **Missing nil guards** where upstream relied on nil-messaging. Each is low, because the case is reached only before init or in odd states:
   - `UNIVERSE->descriptions()` in OOConstToString and OOStringExpander;
   - `drawTrumbles`;
   - `behaviour_attack_slow_dogfight` and `evasiveAction` with a wormhole target;
   - `resetCommsLogColor`;
   - `shipRestoredFromDictionary`.

## Suspected divergences (ranked)

*✔ = the coordinator re-read both sources on 028. Unmarked = an auditor finding with cited lines that wasn't independently re-read.*

### High

None open.

### Medium
- ✔ **Preference defaults** ignore wrong-kind and unparsable values (cross-cutting item 1). The worst case: `animation_timer_interval` → a 10 kHz frame loop. [universe.md](universe.md#gamecontroller)
- ✔ **Standard-library exceptions now crash where upstream logged and continued.**
  - Catch sites were narrowed to `oo::Exception`: `GameController.cpp:404-417`, `AI.cpp:502`, `PlayerEntityControls.cpp` (5 sites), `PlayerEntityLegacyScriptEngine.cpp:464,489,519`, `SDL/main.cpp:311`.
  - Live trigger: `currentLaserOffset().at(0)` on an empty list (`PlayerEntity.cpp:6225`, `PlayerEntityControls.cpp:1403`).

  [cpp-only.md](cpp-only.md#exception), [universe.md](universe.md#gamecontroller)
- ✔ **The JS time limit is enforced exactly** (new). The QuickJS interrupt handler kills at `elapsed > limit`; upstream's watchdog checked once a second (0.2 s in debug). `OOJavaScriptEngine.cpp:702-718`, `OOJSFrameCallbacks.cpp:192`. [scripting.md](scripting.md#oojsenginetimemanagement)
- ✔ **Symlinked `.oxp` folders are not found.** The scan types entries with `symlink_status` (`ResourceManager.cpp:509-528`, `oofnd/FileSystem.hpp:217,232-249`). [gamedata.md](gamedata.md#resourcemanager)
- ✔ **The data cache is rebuilt on most launches.** Mod-times are converted using two `now()` readings (`oofnd/FileSystem.hpp:183-187`, `ResourceManager.cpp:1402-1422`). [gamedata.md](gamedata.md#resourcemanager)
- ✔ **The `laserColor` shader uniform can't be bound.** It has no row in `kEntityShaderBindings`, although `ShipEntity::laserColor` exists (`ShipEntity.cpp:10937`); the comment at `EntityShaderBindings.cpp:98` is stale. [graphics.md](graphics.md#ooshaderuniform)
- ✔ **`EquipmentInfo.provides` returns `[]` instead of `null`** (`OOJSEquipmentInfo.cpp:423-427`). [scripting.md](scripting.md#oojsequipmentinfo)
- **Missile ident lock on a wormhole shows an empty name.** `printIdentLockedOnForMissile` goes through `oo::ToShip`. [entities-player.md](entities-player.md#playerentity)
- **`OORoleSet::anyRole` picks in `std::map` order** (`OORoleSet.cpp:151-173`). [gamedata.md](gamedata.md#ooroleset)
- **`oo::EntityShortDescription` loses the class and ship name** (`EntityHelpers.cpp:122-126`). [cpp-only.md](cpp-only.md#entityhelpers)
- **JS error message texts are QuickJS-ng's**, and compile errors don't print the source line. [scripting.md](scripting.md#oojavascriptengine)
- **SpiderMonkey language extensions are still missing:** `for each`, expression closures, Array generics, `watch`, E4X. `toSource`, `uneval` and legacy `const` are now shimmed. [scripting.md](scripting.md#oojavascriptengine)

Intentional (⚠️ med), listed so they stay visible:
- ADR-0043 / oo-3rb.154 key-order iteration changes populator positions, role picks, AI message order and market prices for the same seed.
- ADR-0002: QuickJS-ng semantics everywhere, including the OXP verifier's JS check.
- Script-local top-level declarations.
- `ship.speed` writable (needs a recorded decision).
- `callObjC` reaches only entities.
- `SqueezeVertically1` row weighting (oo-9ht.115).
- The macOS log folder.
- The TCP console connect wait.
- The joystick GUI button table.

### Low
- ✔ *Memory safety:* `setGuiToMarketInfoScreen`'s cargo loop indexes `quantityInHold[IndexOfGood(...)]` with no not-found guard (`PlayerEntity.cpp:11924-11928`). It is still open, despite the 11-07 note.
- Everything else is recorded per file, marked `(still open)` or `(new)`.

## Suggested follow-ups

The fixes, grouped into commits on `seriesb/028-upstream-772-tests`, are in [028-fix-plan.md](028-fix-plan.md).

## Checklist

### Foundation replacements, logging, collections, async — [foundation.md](foundation.md)
- [x] `Core/NSBundle+Override.m` → `oofnd/ResourcePaths.hpp` (`builtInResourcesDirectory`), `oofnd/Defaults.hpp` (`Defaults::forProcess`, `applicationDomainName`), and the per-caller `OoliteInfoString` readers — 1➖ — [findings](foundation.md#nsbundleoverride)
- [x] `Core/NSDataOOExtensions.m` → `Core/OODataFromOXZFile.cpp` (declared `oofnd/FileSystem.hpp:443`) — 1✅ — [findings](foundation.md#nsdataooextensions)
- [x] `Core/NSDictionaryOOExtensions.m` → *(absorbed: value copies of `oo::PList::Dict` at the call sites)* — 3➖ — [findings](foundation.md#nsdictionaryooextensions)
- [x] `Core/NSFileManagerOOExtensions.m` → `oofnd/FileSystem.hpp` (`oo::fs`), `oofnd/ResourcePaths.hpp`, `Core/OODataFromOXZFile.cpp`, and inlined call sites — 9✅ 1❌ 6➖ — [findings](foundation.md#nsfilemanagerooextensions)
- [x] `Core/NSMutableDictionaryOOExtensions.m` → `Core/ResourceManager.cpp` (`MergeEntries`) — 1✅ — [findings](foundation.md#nsmutabledictionaryooextensions)
- [x] `Core/NSNumberOOExtensions.m` → *(absorbed: `oo::PList` node kinds)* — 2➖ — [findings](foundation.md#nsnumberooextensions)
- [x] `Core/NSObjectOOExtensions.m` → *(absorbed: per-class `objectSize()` and `oo::EntityObjectSize`)* — 1❌ 1➖ — [findings](foundation.md#nsobjectooextensions)
- [x] `Core/NSScannerOOExtensions.m` → `oofnd/Scanner.hpp` — 2✅ — [findings](foundation.md#nsscannerooextensions)
- [x] `Core/NSStringOOExtensions.m` → `oofnd/String.hpp`, `oofnd/Encoding.hpp` — 8✅ 1⚠️ 1❌ 3➖ — [findings](foundation.md#nsstringooextensions)
- [x] `Core/NSThreadOOExtensions.m` → `oofnd/Thread.hpp` — 1✅ — [findings](foundation.md#nsthreadooextensions)
- [x] `Core/NSUserDefaults+Override.m` → `oofnd/Defaults.hpp` (`Defaults::synchronize`, `writeOpenStepPList`) — 1❌ — [findings](foundation.md#nsuserdefaultsoverride)
- [x] `Core/OOAsyncQueue.m` → `Core/OOAsyncWorkManager.cpp` (`TaskQueue`, anonymous namespace). The log writer's queue moved to `oofnd/LogFile.hpp` (audited under OOLogOutputHandler). — 4✅ 10➖ — [findings](foundation.md#ooasyncqueue)
- [x] `Core/OOAsyncWorkManager.m` → `Core/OOAsyncWorkManager.cpp` (423 / 503 lines) — 14✅ 5⚠️ 5➖ — [findings](foundation.md#ooasyncworkmanager)
- [x] `Core/OOCPUInfo.m` → `Core/OOCPUInfo.cpp` (226 / 235 lines) — 7✅ — [findings](foundation.md#oocpuinfo)
- [x] `Core/OOCache.m` → `Core/OOCache.cpp` (1048 / 975 lines) — 44✅ 3⚠️ 1➖ — [findings](foundation.md#oocache)
- [x] `Core/OOCacheManager.m` → `Core/OOCacheManager.cpp` (668 / 565 lines) — 27✅ 2⚠️ 7➖ — [findings](foundation.md#oocachemanager)
- [x] `OOCollectionExtractors` →  — 120✅ 2⚠️ 5❌ 76➖ — [findings](foundation.md#oocollectionextractors)
- [x] `Core/OODeepCopy.m` → *(absorbed: `oo::PList` value copies at the former call sites)* — 1❌ 6➖ — [findings](foundation.md#oodeepcopy)
- [x] `Core/OOEncodingConverter.m` → `Core/OOEncodingConverter.cpp` (242 / 213 lines) — 8✅ 2⚠️ — [findings](foundation.md#ooencodingconverter)
- [x] `Core/OOExcludeObjectEnumerator.m` → *(absorbed: its one caller, `ShipEntity::escorts`)* — 5➖ — [findings](foundation.md#ooexcludeobjectenumerator)
- [x] `Core/OOFilteringEnumerator.m` → *(absorbed: typed filter loops returning `std::vector<oo::EntityHold>` at each caller)* — 19➖ — [findings](foundation.md#oofilteringenumerator)
- [x] `Core/OOFoundation.m` → `Core/OOFoundation.cpp` (92 / 30 lines) — 6➖ — [findings](foundation.md#oofoundation)
- [x] `Core/OOIsNumberLiteral.m` → `Core/OOIsNumberLiteral.cpp` (135 / 126 lines) — 1✅ — [findings](foundation.md#ooisnumberliteral)
- [x] `Core/OOLogHeader.m` → `Core/OOLogHeader.cpp` (355 / 366 lines) — 7✅ — [findings](foundation.md#oologheader)
- [x] `Core/OOLogOutputHandler.m` → `Core/OOLogOutputHandler.cpp` (649 / 342 lines) — 11✅ 3⚠️ 3❌ 7➖ — [findings](foundation.md#oologoutputhandler)
- [x] `Core/OOLogging.m` → `Core/OOLogging.cpp` (832 / 272 lines) — 40✅ 2⚠️ 2❌ — [findings](foundation.md#oologging)
- [x] `Core/OOPListParsing.m` → `Core/OOPListParsing.cpp` (233 / 75 lines) — 3✅ 1⚠️ 5➖ — [findings](foundation.md#ooplistparsing)
- [x] `Core/OOPriorityQueue.m` → `Core/OOPriorityQueue.h` (640 / 167 lines; `OOPriorityQueueOf<T>` over `std::vector<std::shared_ptr<T>>`, header-only; sole user `Core/Scripting/OOScriptTimer.cpp`) — 13✅ 1⚠️ 23➖ — [findings](foundation.md#oopriorityqueue)
- [x] `Core/OOProfilingStopwatch.m` → `Core/OOProfilingStopwatch.cpp` (129 / 117 lines) — 7✅ 1⚠️ — [findings](foundation.md#ooprofilingstopwatch)
- [x] `Core/OORegExpMatcher.m` → `Core/OORegExpMatcher.cpp` (140 / 156 lines) — 4✅ 1⚠️ 1➖ — [findings](foundation.md#ooregexpmatcher)
- [x] `Core/OOWeakReference.m` → `std::weak_ptr<T>` over `oo::Object` (`oofnd/Object.hpp`; `oofnd/Ref.hpp` was deleted in c3d79d42f), plus the plist carrier `oo::EntityWeakPListForeign` (`Core/Entities/Entity.h:466`) — 6✅ 2⚠️ 2❌ 10➖ — [findings](foundation.md#ooweakreference)
- [x] `Core/OOWeakSet.m` → `oofnd/WeakSet.hpp` (`oo::WeakSet<T>`: `std::vector<std::weak_ptr<T>>` in insertion order + an `owner_less` index) — 15✅ 4⚠️ 5➖ — [findings](foundation.md#ooweakset)
- [x] `Core/OOXMLExtensions.m` → `Core/OOXMLExtensions.cpp` (55 / 50 lines) — 1❌ — [findings](foundation.md#ooxmlextensions)
- [x] `Core/OldSchoolPropertyListWriting.m` → `oofnd/PListWriting.hpp` (`plist_detail::OldStyleWriter` :124, `oo::writeOldStylePList` :523) — 5✅ 3⚠️ — [findings](foundation.md#oldschoolpropertylistwriting)
- [x] `Core/ReleaseLockProxy.m` → *(removed: a debugging proxy with no user in upstream or the port)* — 17➖ — [findings](foundation.md#releaselockproxy)
- [x] `SDL/Comparison.m` → *(absorbed: `==` on `std::string` / `std::optional<std::string>` at the call sites)* — 6➖ — [findings](foundation.md#comparison)

### Maths, geometry, collision — [math.md](math.md)
- [x] `Core/CollisionRegion.m` → `Core/CollisionRegion.cpp` (633 / 663 lines) — 18✅ 2⚠️ — [findings](math.md#collisionregion)
- [x] `Core/OOHPVector.m` → `Core/OOHPVector.cpp` (129 / 154 lines) — 9✅ — [findings](math.md#oohpvector)
- [x] `Core/OOMatrix.m` → `Core/OOMatrix.cpp` (424 / 419 lines) — 20✅ — [findings](math.md#oomatrix)
- [x] `Core/OOMeshToOctreeConverter.m` → `Core/OOMeshToOctreeConverter.cpp` (825 / 842 lines) — 18✅ — [findings](math.md#oomeshtooctreeconverter)
- [x] `Core/OOQuaternion.m` → `Core/OOQuaternion.cpp` (408 / 407 lines) — 17✅ — [findings](math.md#ooquaternion)
- [x] `Core/OOSpatialReference.m` → *(absorbed: no same-named file; the only method lives on `Entity`, `Core/Entities/Entity.cpp`)* — 1✅ 2➖ — [findings](math.md#oospatialreference)
- [x] `Core/OOVector.m` → `Core/OOVector.cpp` (139 / 144 lines) — 7✅ — [findings](math.md#oovector)
- [x] `Core/OOVoxel.m` → `Core/OOVoxel.cpp` (197 / 168 lines) — 7✅ — [findings](math.md#oovoxel)
- [x] `Core/Octree.m` → `Core/Octree.cpp` (906 / 901 lines) — 31✅ 4⚠️ 2➖ — [findings](math.md#octree)

### OXP verifier — [oxpverifier.md](oxpverifier.md)
- [x] `Core/OXPVerifier/OOAIStateMachineVerifierStage.m` → `Core/OXPVerifier/OOAIStateMachineVerifierStage.cpp` (201 / 219 lines) — 5✅ 1❌ 1➖ — [findings](oxpverifier.md#ooaistatemachineverifierstage)
- [x] `Core/OXPVerifier/OOCheckDemoShipsPListVerifierStage.m` → `Core/OXPVerifier/OOCheckDemoShipsPListVerifierStage.cpp` (114 / 99 lines) — 4✅ — [findings](oxpverifier.md#oocheckdemoshipsplistverifierstage)
- [x] `Core/OXPVerifier/OOCheckEquipmentPListVerifierStage.m` → `Core/OXPVerifier/OOCheckEquipmentPListVerifierStage.cpp` (158 / 181 lines) — 4✅ — [findings](oxpverifier.md#oocheckequipmentplistverifierstage)
- [x] `Core/OXPVerifier/OOCheckJSSyntaxVerifierStage.m` → `Core/OXPVerifier/OOCheckJSSyntaxVerifierStage.cpp` (90 / 102 lines) — 2✅ 1⚠️ — [findings](oxpverifier.md#oocheckjssyntaxverifierstage)
- [x] `Core/OXPVerifier/OOCheckPListSyntaxVerifierStage.m` → `Core/OXPVerifier/OOCheckPListSyntaxVerifierStage.cpp` (91 / 106 lines) — 3✅ — [findings](oxpverifier.md#oocheckplistsyntaxverifierstage)
- [x] `Core/OXPVerifier/OOCheckRequiresPListVerifierStage.m` → `Core/OXPVerifier/OOCheckRequiresPListVerifierStage.cpp` (143 / 200 lines) — 2✅ 1❌ — [findings](oxpverifier.md#oocheckrequiresplistverifierstage)
- [x] `Core/OXPVerifier/OOCheckShipDataPListVerifierStage.m` → `Core/OXPVerifier/OOCheckShipDataPListVerifierStage.cpp` (363 / 394 lines) — 12✅ 2❌ — [findings](oxpverifier.md#oocheckshipdataplistverifierstage)
- [x] `Core/OXPVerifier/OOFileScannerVerifierStage.m` → `Core/OXPVerifier/OOFileScannerVerifierStage.cpp` (701 / 703 lines) — 20✅ 1⚠️ 3❌ 2➖ — [findings](oxpverifier.md#oofilescannerverifierstage)
- [x] `Core/OXPVerifier/OOModelVerifierStage.m` → `Core/OXPVerifier/OOModelVerifierStage.cpp` (191 / 105 lines) — 4✅ 2❌ 3➖ — [findings](oxpverifier.md#oomodelverifierstage)
- [x] `Core/OXPVerifier/OOOXPVerifier.m` → `Core/OXPVerifier/OOOXPVerifier.cpp` (690 / 824 lines) — 15✅ 3⚠️ 4❌ 1➖ — [findings](oxpverifier.md#oooxpverifier)
- [x] `Core/OXPVerifier/OOOXPVerifierStage.m` → `Core/OXPVerifier/OOOXPVerifierStage.cpp` (211 / 212 lines) — 18✅ 1⚠️ 2➖ — [findings](oxpverifier.md#oooxpverifierstage)
- [x] `Core/OXPVerifier/OOPListSchemaVerifier.m` → `Core/OXPVerifier/OOPListSchemaVerifier.cpp` (1393 / 1707 lines) — 39✅ 5⚠️ 1❌ 6➖ — [findings](oxpverifier.md#ooplistschemaverifier)
- [x] `Core/OXPVerifier/OOTextureVerifierStage.m` → `Core/OXPVerifier/OOTextureVerifierStage.cpp` (187 / 162 lines) — 5✅ 2❌ 3➖ — [findings](oxpverifier.md#ootextureverifierstage)

### Scripting (JS engine, OOJS*, legacy scripts, JS console) — [scripting.md](scripting.md)
- [x] `Core/Debug/OOJSConsole.m` → `Core/Debug/OOJSConsole.cpp` (1053 / 1448 lines) — 18✅ 8⚠️ 5❌ 3➖ — [findings](scripting.md#oojsconsole)
- [x] `Core/Entities/PlayerEntityLegacyScriptEngine.m` → `Core/Entities/PlayerEntityLegacyScriptEngine.cpp` (2625 / 3175 lines) — 144✅ 6⚠️ 1❌ — [findings](scripting.md#playerentitylegacyscriptengine)
- [x] `Core/Scripting/EntityOOJavaScriptExtensions.m` → `Core/Scripting/EntityOOJavaScriptExtensions.cpp` (149 / 182 lines) — 9✅ 1❌ — [findings](scripting.md#entityoojavascriptextensions)
- [x] `Core/Scripting/OOConstToJSString.m` → `Core/Scripting/OOConstToJSString.cpp` (240 / 257 lines) — 7✅ 1⚠️ — [findings](scripting.md#ooconsttojsstring)
- [x] `Core/Scripting/OOJSCall.m` → `Core/Scripting/OOJSCall.cpp` (229 / 327 lines) — 1✅ 1⚠️ 1❌ 5➖ — [findings](scripting.md#oojscall)
- [x] `Core/Scripting/OOJSClock.m` → `Core/Scripting/OOJSClock.cpp` (229 / 255 lines) — 7✅ — [findings](scripting.md#oojsclock)
- [x] `Core/Scripting/OOJSDock.m` → `Core/Scripting/OOJSDock.cpp` (267 / 273 lines) — 9✅ 1⚠️ — [findings](scripting.md#oojsdock)
- [x] `Core/Scripting/OOJSEngineDebuggerHelpers.m` → `Core/Scripting/OOJSEngineDebuggerHelpers.cpp` (235 / 229 lines) — 5✅ 3⚠️ — [findings](scripting.md#oojsenginedebuggerhelpers)
- [x] `Core/Scripting/OOJSEngineTimeManagement.m` → `Core/Scripting/OOJSEngineTimeManagement.cpp` (923 / 460 lines) — 42✅ 5⚠️ 1❌ 10➖ — [findings](scripting.md#oojsenginetimemanagement)
- [x] `Core/Scripting/OOJSEntity.m` → `Core/Scripting/OOJSEntity.cpp` (388 / 471 lines) — 8✅ — [findings](scripting.md#oojsentity)
- [x] `Core/Scripting/OOJSEquipmentInfo.m` → `Core/Scripting/OOJSEquipmentInfo.cpp` (528 / 686 lines) — 15✅ 1⚠️ 1❌ — [findings](scripting.md#oojsequipmentinfo)
- [x] `Core/Scripting/OOJSExhaustPlume.m` → `Core/Scripting/OOJSExhaustPlume.cpp` (214 / 201 lines) — 10✅ — [findings](scripting.md#oojsexhaustplume)
- [x] `Core/Scripting/OOJSFlasher.m` → `Core/Scripting/OOJSFlasher.cpp` (290 / 297 lines) — 10✅ — [findings](scripting.md#oojsflasher)
- [x] `Core/Scripting/OOJSFont.m` → `Core/Scripting/OOJSFont.cpp` (57 / 70 lines) — 2✅ — [findings](scripting.md#oojsfont)
- [x] `Core/Scripting/OOJSFrameCallbacks.m` → `Core/Scripting/OOJSFrameCallbacks.cpp` (435 / 480 lines) — 13✅ — [findings](scripting.md#oojsframecallbacks)
- [x] `Core/Scripting/OOJSFunction.m` → `Core/Scripting/OOJSFunction.cpp` (241 / 217 lines) — 8✅ 1❌ 3➖ — [findings](scripting.md#oojsfunction)
- [x] `Core/Scripting/OOJSGlobal.m` → `Core/Scripting/OOJSGlobal.cpp` (789 / 956 lines) — 22✅ 2⚠️ 2❌ — [findings](scripting.md#oojsglobal)
- [x] `Core/Scripting/OOJSGuiScreenKeyDefinition.m` → `Core/Scripting/OOJSGuiScreenKeyDefinition.cpp` (150 / 150 lines) — 13✅ — [findings](scripting.md#oojsguiscreenkeydefinition)
- [x] `Core/Scripting/OOJSInterfaceDefinition.m` → `Core/Scripting/OOJSInterfaceDefinition.cpp` (166 / 169 lines) — 15✅ — [findings](scripting.md#oojsinterfacedefinition)
- [x] `Core/Scripting/OOJSManifest.m` → `Core/Scripting/OOJSManifest.cpp` (292 / 441 lines) — 10✅ 1❌ 3➖ — [findings](scripting.md#oojsmanifest)
- [x] `Core/Scripting/OOJSMission.m` → `Core/Scripting/OOJSMission.cpp` (668 / 938 lines) — 17✅ 1⚠️ — [findings](scripting.md#oojsmission)
- [x] `Core/Scripting/OOJSMissionVariables.m` → `Core/Scripting/OOJSMissionVariables.cpp` (205 / 348 lines) — 6✅ 1⚠️ 1❌ — [findings](scripting.md#oojsmissionvariables)
- [x] `Core/Scripting/OOJSOolite.m` → `Core/Scripting/OOJSOolite.cpp` (311 / 402 lines) — 8✅ 1⚠️ 1❌ — [findings](scripting.md#oojsoolite)
- [x] `Core/Scripting/OOJSPlanet.m` → `Core/Scripting/OOJSPlanet.cpp` (293 / 360 lines) — 9✅ — [findings](scripting.md#oojsplanet)
- [x] `Core/Scripting/OOJSPlayer.m` → `Core/Scripting/OOJSPlayer.cpp` (683 / 842 lines) — 22✅ 2❌ 1➖ — [findings](scripting.md#oojsplayer)
- [x] `Core/Scripting/OOJSPlayerShip.m` → `Core/Scripting/OOJSPlayerShip.cpp` (1751 / 2219 lines) — 36✅ 2⚠️ 1❌ 1➖ — [findings](scripting.md#oojsplayership)
- [x] `Core/Scripting/OOJSPopulatorDefinition.m` → `Core/Scripting/OOJSPopulatorDefinition.cpp` (125 / 159 lines) — 8✅ — [findings](scripting.md#oojspopulatordefinition)
- [x] `Core/Scripting/OOJSQuaternion.m` → `Core/Scripting/OOJSQuaternion.cpp` (925 / 773 lines) — 32✅ 2⚠️ 1❌ — [findings](scripting.md#oojsquaternion)
- [x] `Core/Scripting/OOJSScript.m` → `Core/Scripting/OOJSScript.cpp` (761 / 1081 lines) — 27✅ 7⚠️ 2➖ — [findings](scripting.md#oojsscript)
- [x] `Core/Scripting/OOJSShip.m` → `Core/Scripting/OOJSShip.cpp` (4015 / 4541 lines) — 92✅ 2⚠️ 4❌ 1➖ — [findings](scripting.md#oojsship)
- [x] `Core/Scripting/OOJSShipGroup.m` → `Core/Scripting/OOJSShipGroup.cpp` (347 / 454 lines) — 13✅ — [findings](scripting.md#oojsshipgroup)
- [x] `Core/Scripting/OOJSSound.m` → `Core/Scripting/OOJSSound.cpp` (299 / 341 lines) — 13✅ 2⚠️ — [findings](scripting.md#oojssound)
- [x] `Core/Scripting/OOJSSoundSource.m` → `Core/Scripting/OOJSSoundSource.cpp` (345 / 387 lines) — 12✅ 1⚠️ — [findings](scripting.md#oojssoundsource)
- [x] `Core/Scripting/OOJSSpecialFunctions.m` → `Core/Scripting/OOJSSpecialFunctions.cpp` (101 / 100 lines) — 4✅ 1⚠️ — [findings](scripting.md#oojsspecialfunctions)
- [x] `Core/Scripting/OOJSStation.m` → `Core/Scripting/OOJSStation.cpp` (1085 / 1433 lines) — 29✅ 2❌ — [findings](scripting.md#oojsstation)
- [x] `Core/Scripting/OOJSSun.m` → `Core/Scripting/OOJSSun.cpp` (179 / 183 lines) — 11✅ — [findings](scripting.md#oojssun)
- [x] `Core/Scripting/OOJSSystem.m` → `Core/Scripting/OOJSSystem.cpp` (1535 / 1920 lines) — 38✅ 3❌ — [findings](scripting.md#oojssystem)
- [x] `Core/Scripting/OOJSSystemInfo.m` → `Core/Scripting/OOJSSystemInfo.cpp` (738 / 1326 lines) — 25✅ 3⚠️ 2❌ 2➖ — [findings](scripting.md#oojssysteminfo)
- [x] `Core/Scripting/OOJSTimer.m` → `Core/Scripting/OOJSTimer.cpp` (419 / 535 lines) — 14✅ 1⚠️ 1❌ — [findings](scripting.md#oojstimer)
- [x] `Core/Scripting/OOJSVector.m` → `Core/Scripting/OOJSVector.cpp` (1225 / 1032 lines) — 40✅ 3⚠️ 2❌ 2➖ — [findings](scripting.md#oojsvector)
- [x] `Core/Scripting/OOJSVisualEffect.m` → `Core/Scripting/OOJSVisualEffect.cpp` (682 / 832 lines) — 17✅ 1❌ — [findings](scripting.md#oojsvisualeffect)
- [x] `Core/Scripting/OOJSWaypoint.m` → `Core/Scripting/OOJSWaypoint.cpp` (250 / 258 lines) — 9✅ — [findings](scripting.md#oojswaypoint)
- [x] `Core/Scripting/OOJSWorldScripts.m` → `Core/Scripting/OOJSWorldScripts.cpp` (110 / 167 lines) — 2✅ 1⚠️ 1❌ — [findings](scripting.md#oojsworldscripts)
- [x] `Core/Scripting/OOJSWormhole.m` → `Core/Scripting/OOJSWormhole.cpp` (196 / 165 lines) — 8✅ 1➖ — [findings](scripting.md#oojswormhole)
- [x] `Core/Scripting/OOJavaScriptEngine.m` → `Core/Scripting/OOJavaScriptEngine.cpp` (2322 / 2009 lines) — 74✅ 12⚠️ 9❌ 19➖ — [findings](scripting.md#oojavascriptengine)
- [x] `Core/Scripting/OOLegacyScriptWhitelist.m` → `Core/Scripting/OOLegacyScriptWhitelist.cpp` (515 / 672 lines) — 13✅ 2❌ — [findings](scripting.md#oolegacyscriptwhitelist)
- [x] `Core/Scripting/OOPListScript.m` → `Core/Scripting/OOPListScript.cpp` (193 / 194 lines) — 4✅ 4⚠️ 1❌ 1➖ — [findings](scripting.md#ooplistscript)
- [x] `Core/Scripting/OOScript.m` → `Core/Scripting/OOScript.cpp` (271 / 340 lines) — 12✅ 1⚠️ — [findings](scripting.md#ooscript)
- [x] `Core/Scripting/OOScriptTimer.m` → `Core/Scripting/OOScriptTimer.cpp` (244 / 256 lines) — 16✅ — [findings](scripting.md#ooscripttimer)

### Player entity and its categories — [entities-player.md](entities-player.md)
- [x] `Core/Entities/PlayerEntity.m` → `Core/Entities/PlayerEntity.cpp` (11911 / 14092 lines) — 466✅ 14⚠️ 8❌ 3➖ — [findings](entities-player.md#playerentity)
- [x] `Core/Entities/PlayerEntityContracts.m` → `Core/Entities/PlayerEntityContracts.cpp` (1775 / 2236 lines) — 39✅ 1⚠️ — [findings](entities-player.md#playerentitycontracts)
- [x] `Core/Entities/PlayerEntityControls.m` → `Core/Entities/PlayerEntityControls.cpp` (4831 / 6144 lines) — 38✅ 4⚠️ 4❌ — [findings](entities-player.md#playerentitycontrols)
- [x] `Core/Entities/PlayerEntityKeyMapper.m` → `Core/Entities/PlayerEntityKeyMapper.cpp` (1616 / 2188 lines) — 39✅ 1⚠️ 2❌ — [findings](entities-player.md#playerentitykeymapper)
- [x] `Core/Entities/PlayerEntityLoadSave.m` → `Core/Entities/PlayerEntityLoadSave.cpp` (1185 / 1438 lines) — 23✅ 2⚠️ 1❌ — [findings](entities-player.md#playerentityloadsave)
- [x] `Core/Entities/PlayerEntityScriptMethods.m` → `Core/Entities/PlayerEntityScriptMethods.cpp` (576 / 600 lines) — 35✅ — [findings](entities-player.md#playerentityscriptmethods)
- [x] `Core/Entities/PlayerEntitySound.m` → `Core/Entities/PlayerEntitySound.cpp` (654 / 678 lines) — 85✅ — [findings](entities-player.md#playerentitysound)
- [x] `Core/Entities/PlayerEntityStickMapper.m` → `Core/Entities/PlayerEntityStickMapper.cpp` (910 / 896 lines) — 12✅ 1❌ — [findings](entities-player.md#playerentitystickmapper)
- [x] `Core/Entities/PlayerEntityStickProfile.m` → `Core/Entities/PlayerEntityStickProfile.cpp` (597 / 601 lines) — 25✅ 1➖ — [findings](entities-player.md#playerentitystickprofile)
- [x] `Core/Entities/ProxyPlayerEntity.m` → `Core/Entities/ProxyPlayerEntity.cpp` (208 / 147 lines) — 27✅ 2➖ — [findings](entities-player.md#proxyplayerentity)

### Ship, station, dock entities — [entities-ship.md](entities-ship.md)
- [x] `Core/Entities/DockEntity.m` → `Core/Entities/DockEntity.cpp` (1176 / 1434 lines) — 40✅ 1⚠️ 1❌ — [findings](entities-ship.md#dockentity)
- [x] `Core/Entities/ShipEntity.m` → `Core/Entities/ShipEntity.cpp` (13049 / 14079 lines) — 623✅ 6⚠️ 10❌ 7➖ — [findings](entities-ship.md#shipentity)
- [x] `Core/Entities/ShipEntityAI.m` → `Core/Entities/ShipEntityAI.cpp` (2558 / 2797 lines) — 154✅ 2⚠️ — [findings](entities-ship.md#shipentityai)
- [x] `Core/Entities/ShipEntityLoadRestore.m` → `Core/Entities/ShipEntityLoadRestore.cpp` (358 / 425 lines) — 6✅ 1❌ — [findings](entities-ship.md#shipentityloadrestore)
- [x] `Core/Entities/ShipEntityScriptMethods.m` → `Core/Entities/ShipEntityScriptMethods.cpp` (92 / 99 lines) — 3✅ — [findings](entities-ship.md#shipentityscriptmethods)
- [x] `Core/Entities/StationEntity.m` → `Core/Entities/StationEntity.cpp` (2192 / 2611 lines) — 107✅ 3⚠️ 2➖ — [findings](entities-ship.md#stationentity)

### Other entities (planets, effects, particles, base Entity) — [entities-other.md](entities-other.md)
- [x] `Core/Entities/DustEntity.m` → `Core/Entities/DustEntity.cpp` (418 / 423 lines) — 13✅ 1❌ — [findings](entities-other.md#dustentity)
- [x] `Core/Entities/Entity.m` → `Core/Entities/Entity.cpp` (1055 / 956 lines) — 105✅ 1❌ — [findings](entities-other.md#entity)
- [x] `Core/Entities/EntityShaderBindings.m` → `Core/Entities/EntityShaderBindings.cpp` (77 / 976 lines) — 12✅ 2❌ — [findings](entities-other.md#entityshaderbindings)
- [x] `Core/Entities/OOBreakPatternEntity.m` → `Core/Entities/OOBreakPatternEntity.cpp` (169 / 153 lines) — 8✅ 2➖ — [findings](entities-other.md#oobreakpatternentity)
- [x] `Core/Entities/OOECMBlastEntity.m` → `Core/Entities/OOECMBlastEntity.cpp` (124 / 122 lines) — 4✅ 1➖ — [findings](entities-other.md#ooecmblastentity)
- [x] `Core/Entities/OOEntityWithDrawable.m` → `Core/Entities/OOEntityWithDrawable.cpp` (122 / 124 lines) — 5✅ 1➖ — [findings](entities-other.md#ooentitywithdrawable)
- [x] `Core/Entities/OOExhaustPlumeEntity.m` → `Core/Entities/OOExhaustPlumeEntity.cpp` (681 / 686 lines) — 16✅ 1❌ 1➖ — [findings](entities-other.md#ooexhaustplumeentity)
- [x] `Core/Entities/OOExplosionCloudEntity.m` → `Core/Entities/OOExplosionCloudEntity.cpp` (252 / 261 lines) — 5✅ 1➖ — [findings](entities-other.md#ooexplosioncloudentity)
- [x] `Core/Entities/OOFlashEffectEntity.m` → `Core/Entities/OOFlashEffectEntity.cpp` (140 / 161 lines) — 8✅ 1❌ — [findings](entities-other.md#ooflasheffectentity)
- [x] `Core/Entities/OOFlasherEntity.m` → `Core/Entities/OOFlasherEntity.cpp` (217 / 177 lines) — 19✅ 1⚠️ 2➖ — [findings](entities-other.md#ooflasherentity)
- [x] `Core/Entities/OOLaserShotEntity.m` → `Core/Entities/OOLaserShotEntity.cpp` (315 / 324 lines) — 14✅ 1❌ 1➖ — [findings](entities-other.md#oolasershotentity)
- [x] `Core/Entities/OOLightParticleEntity.m` → `Core/Entities/OOLightParticleEntity.cpp` (329 / 341 lines) — 13✅ 1❌ — [findings](entities-other.md#oolightparticleentity)
- [x] `Core/Entities/OOParticleSystem.m` → `Core/Entities/OOParticleSystem.cpp` (353 / 367 lines) — 14✅ 1⚠️ 1➖ — [findings](entities-other.md#ooparticlesystem)
- [x] `Core/Entities/OOPlanetEntity.m` → `Core/Entities/OOPlanetEntity.cpp` (1052 / 1274 lines) — 49✅ 2⚠️ — [findings](entities-other.md#ooplanetentity)
- [x] `Core/Entities/OOPlasmaBurstEntity.m` → `Core/Entities/OOPlasmaBurstEntity.cpp` (62 / 66 lines) — 2✅ — [findings](entities-other.md#ooplasmaburstentity)
- [x] `Core/Entities/OOPlasmaShotEntity.m` → `Core/Entities/OOPlasmaShotEntity.cpp` (113 / 125 lines) — 4✅ — [findings](entities-other.md#ooplasmashotentity)
- [x] `Core/Entities/OOQuiriumCascadeEntity.m` → `Core/Entities/OOQuiriumCascadeEntity.cpp` (165 / 161 lines) — 9✅ 1➖ — [findings](entities-other.md#ooquiriumcascadeentity)
- [x] `Core/Entities/OORingEffectEntity.m` → `Core/Entities/OORingEffectEntity.cpp` (157 / 161 lines) — 9✅ — [findings](entities-other.md#ooringeffectentity)
- [x] `Core/Entities/OOSparkEntity.m` → `Core/Entities/OOSparkEntity.cpp` (81 / 77 lines) — 3✅ — [findings](entities-other.md#oosparkentity)
- [x] `Core/Entities/OOSunEntity.m` → `Core/Entities/OOSunEntity.cpp` (738 / 796 lines) — 29✅ 1➖ — [findings](entities-other.md#oosunentity)
- [x] `Core/Entities/OOVisualEffectEntity.m` → `Core/Entities/OOVisualEffectEntity.cpp` (875 / 909 lines) — 81✅ 1❌ 1➖ — [findings](entities-other.md#oovisualeffectentity)
- [x] `Core/Entities/OOWaypointEntity.m` → `Core/Entities/OOWaypointEntity.cpp` (289 / 273 lines) — 20✅ 1❌ 1➖ — [findings](entities-other.md#oowaypointentity)
- [x] `Core/Entities/PlanetEntity.m` → *(no counterpart: dead upstream under `#if !NEW_PLANETS`; live planet is `Core/Entities/OOPlanetEntity.cpp`)* — 51➖ — [findings](entities-other.md#planetentity)
- [x] `Core/Entities/SkyEntity.m` → `Core/Entities/SkyEntity.cpp` (313 / 317 lines) — 13✅ — [findings](entities-other.md#skyentity)
- [x] `Core/Entities/WormholeEntity.m` → `Core/Entities/WormholeEntity.cpp` (802 / 922 lines) — 38✅ — [findings](entities-other.md#wormholeentity)

### Sound and music — [sound.md](sound.md)
- [x] `Core/OOALBufferedSound.m` → `Core/OOALBufferedSound.cpp` (94 / 85 lines) — 4✅ — [findings](sound.md#ooalbufferedsound)
- [x] `Core/OOALMusic.m` → `Core/OOALMusic.cpp` (117 / 109 lines) — 9✅ 1➖ — [findings](sound.md#ooalmusic)
- [x] `Core/OOALSound.m` → `Core/OOALSound.cpp` (164 / 176 lines) — 10✅ 1❌ 1➖ — [findings](sound.md#ooalsound)
- [x] `Core/OOALSoundChannel.m` → `Core/OOALSoundChannel.cpp` (223 / 196 lines) — 14✅ — [findings](sound.md#ooalsoundchannel)
- [x] `Core/OOALSoundDecoder.m` → `Core/OOALSoundDecoder.cpp` (461 / 445 lines) — 20✅ 1❌ 1➖ — [findings](sound.md#ooalsounddecoder)
- [x] `Core/OOALSoundMixer.m` → `Core/OOALSoundMixer.cpp` (158 / 116 lines) — 5✅ 1⚠️ 6➖ — [findings](sound.md#ooalsoundmixer)
- [x] `Core/OOALStreamedSound.m` → `Core/OOALStreamedSound.cpp` (114 / 104 lines) — 6✅ — [findings](sound.md#ooalstreamedsound)
- [x] `Core/OOBasicSoundReferencePoint.m` → `Core/OOBasicSoundReferencePoint.cpp` (41 / 31 lines) — 3✅ — [findings](sound.md#oobasicsoundreferencepoint)
- [x] `Core/OOMusic.m` → *(absorbed — the `OOMusic` class lives in `Core/OOALMusic.cpp`)* — 1➖ — [findings](sound.md#oomusic)
- [x] `Core/OOMusicController.m` → `Core/OOMusicController.cpp` (361 / 245 lines) — 23✅ 8➖ — [findings](sound.md#oomusiccontroller)
- [x] `Core/OOOpenALController.m` → `Core/OOOpenALController.cpp` (102 / 102 lines) — 5✅ — [findings](sound.md#ooopenalcontroller)
- [x] `Core/OOSoundSource.m` → `Core/OOSoundSource.cpp` (299 / 291 lines) — 31✅ 1⚠️ — [findings](sound.md#oosoundsource)
- [x] `Core/OOSoundSourcePool.m` → `Core/OOSoundSourcePool.cpp` (249 / 187 lines) — 12✅ — [findings](sound.md#oosoundsourcepool)

### Materials, textures, meshes, drawables, OpenGL — [graphics.md](graphics.md)
- [x] `Core/Materials/OOBasicMaterial.m` → `Core/Materials/OOBasicMaterial.cpp` (314 / 282 lines) — 32✅ 1⚠️ — [findings](graphics.md#oobasicmaterial)
- [x] `Core/Materials/OOCombinedEmissionMapGenerator.m` → `Core/Materials/OOCombinedEmissionMapGenerator.cpp` (446 / 431 lines) — 12✅ 1❌ — [findings](graphics.md#oocombinedemissionmapgenerator)
- [x] `Core/Materials/OOConcreteTexture.m` → `Core/Materials/OOConcreteTexture.cpp` (641 / 639 lines) — 26✅ — [findings](graphics.md#ooconcretetexture)
- [x] `Core/Materials/OODefaultShaderSynthesizer.m` → `Core/Materials/OODefaultShaderSynthesizer.cpp` (1451 / 1391 lines) — 46✅ 1⚠️ — [findings](graphics.md#oodefaultshadersynthesizer)
- [x] `Core/Materials/OOMaterial.m` → `Core/Materials/OOMaterial.cpp` (140 / 151 lines) — 15✅ 1⚠️ — [findings](graphics.md#oomaterial)
- [x] `Core/Materials/OOMaterialConvenienceCreators.m` → `Core/Materials/OOMaterialConvenienceCreators.cpp` (539 / 651 lines) — 14✅ 1❌ — [findings](graphics.md#oomaterialconveniencecreators)
- [x] `Core/Materials/OOMaterialSpecifier.m` → `Core/Materials/OOMaterialSpecifier.cpp` (256 / 259 lines) — 24✅ — [findings](graphics.md#oomaterialspecifier)
- [x] `Core/Materials/OOMultiTextureMaterial.m` → `Core/Materials/OOMultiTextureMaterial.cpp` (204 / 216 lines) — 7✅ 1⚠️ 1❌ — [findings](graphics.md#oomultitexturematerial)
- [x] `Core/Materials/OONullTexture.m` → `Core/Materials/OONullTexture.cpp` (116 / 70 lines) — 6✅ 6➖ — [findings](graphics.md#oonulltexture)
- [x] `Core/Materials/OOPNGTextureLoader.m` → `Core/Materials/OOPNGTextureLoader.cpp` (221 / 221 lines) — 7✅ — [findings](graphics.md#oopngtextureloader)
- [x] `Core/Materials/OOPixMap.m` → `Core/Materials/OOPixMap.cpp` (242 / 260 lines) — 11✅ 1⚠️ — [findings](graphics.md#oopixmap)
- [x] `Core/Materials/OOPixMapChannelOperations.m` → `Core/Materials/OOPixMapChannelOperations.cpp` (331 / 355 lines) — 11✅ — [findings](graphics.md#oopixmapchanneloperations)
- [x] `Core/Materials/OOPixMapTextureLoader.m` → `Core/Materials/OOPixMapTextureLoader.cpp` (86 / 92 lines) — 4✅ — [findings](graphics.md#oopixmaptextureloader)
- [x] `Core/Materials/OOPlanetTextureGenerator.m` → `Core/Materials/OOPlanetTextureGenerator.cpp` (1261 / 1276 lines) — 49✅ 1⚠️ 1❌ — [findings](graphics.md#ooplanettexturegenerator)
- [x] `Core/Materials/OOShaderMaterial.m` → `Core/Materials/OOShaderMaterial.cpp` (794 / 793 lines) — 21✅ 2⚠️ 1❌ — [findings](graphics.md#ooshadermaterial)
- [x] `Core/Materials/OOShaderProgram.m` → `Core/Materials/OOShaderProgram.cpp` (550 / 665 lines) — 14✅ — [findings](graphics.md#ooshaderprogram)
- [x] `Core/Materials/OOShaderUniform.m` → `Core/Materials/OOShaderUniform.cpp` (542 / 563 lines) — 10✅ 2⚠️ 2❌ — [findings](graphics.md#ooshaderuniform)
- [x] `Core/Materials/OOShaderUniformMethodType.m` → `Core/Materials/OOShaderUniformMethodType.cpp` (280 / 116 lines) — 2⚠️ 19➖ — [findings](graphics.md#ooshaderuniformmethodtype)
- [x] `Core/Materials/OOSingleTextureMaterial.m` → `Core/Materials/OOSingleTextureMaterial.cpp` (115 / 121 lines) — 9✅ 1⚠️ — [findings](graphics.md#oosingletexturematerial)
- [x] `Core/Materials/OOStandaloneAtmosphereGenerator.m` → `Core/Materials/OOStandaloneAtmosphereGenerator.cpp` (753 / 747 lines) — 24✅ 1⚠️ 1❌ — [findings](graphics.md#oostandaloneatmospheregenerator)
- [x] `Core/Materials/OOTexture.m` → `Core/Materials/OOTexture.cpp` (884 / 903 lines) — 40✅ 1⚠️ 2❌ 8➖ — [findings](graphics.md#ootexture)
- [x] `Core/Materials/OOTextureGenerator.m` → `Core/Materials/OOTextureGenerator.cpp` (58 / 48 lines) — 5✅ — [findings](graphics.md#ootexturegenerator)
- [x] `Core/Materials/OOTextureLoader.m` → `Core/Materials/OOTextureLoader.cpp` (505 / 546 lines) — 17✅ 1❌ — [findings](graphics.md#ootextureloader)
- [x] `Core/OOConvertCubeMapToLatLong.m` → `Core/OOConvertCubeMapToLatLong.cpp` (146 / 153 lines) — 1✅ — [findings](graphics.md#ooconvertcubemaptolatlong)
- [x] `Core/OODebugGLDrawing.m` → `Core/OODebugGLDrawing.cpp` (160 / 160 lines) — 7✅ — [findings](graphics.md#oodebuggldrawing)
- [x] `Core/OODrawable.m` → `Core/OODrawable.cpp` (86 / 84 lines) — 10✅ 1⚠️ — [findings](graphics.md#oodrawable)
- [x] `Core/OOEnvironmentCubeMap.m` → *(none — never in the upstream build; deleted as dead code, note at `Core/Universe.cpp:11509-11511`)* — 10➖ — [findings](graphics.md#ooenvironmentcubemap)
- [x] `Core/OOGraphicsResetManager.m` → `Core/OOGraphicsResetManager.cpp` (136 / 102 lines) — 4✅ 1⚠️ 6➖ — [findings](graphics.md#oographicsresetmanager)
- [x] `Core/OOMesh.m` → `Core/OOMesh.cpp` (2078 / 2024 lines) — 61✅ 3⚠️ 2❌ — [findings](graphics.md#oomesh)
- [x] `Core/OOOpenGL.m` → `Core/OOOpenGL.cpp` (552 / 557 lines) — 24✅ — [findings](graphics.md#ooopengl)
- [x] `Core/OOOpenGLExtensionManager.m` → `Core/OOOpenGLExtensionManager.cpp` (826 / 947 lines) — 33✅ 1⚠️ 6➖ — [findings](graphics.md#ooopenglextensionmanager)
- [x] `Core/OOOpenGLMatrixManager.m` → `Core/OOOpenGLMatrixManager.cpp` (591 / 514 lines) — 59✅ — [findings](graphics.md#ooopenglmatrixmanager)
- [x] `Core/OOOpenGLStateManager.m` → `Core/OOOpenGLStateManager.cpp` (629 / 904 lines) — 23✅ — [findings](graphics.md#ooopenglstatemanager)
- [x] `Core/OOPlanetDrawable.m` → `Core/OOPlanetDrawable.cpp` (389 / 358 lines) — 28✅ 1➖ — [findings](graphics.md#ooplanetdrawable)
- [x] `Core/OOPolygonSprite.m` → `Core/OOPolygonSprite.cpp` (862 / 834 lines) — 24✅ 1❌ 1➖ — [findings](graphics.md#oopolygonsprite)
- [x] `Core/OOProbabilisticTextureManager.m` → `Core/OOProbabilisticTextureManager.cpp` (229 / 220 lines) — 8✅ 1❌ — [findings](graphics.md#ooprobabilistictexturemanager)
- [x] `Core/OOSkyDrawable.m` → `Core/OOSkyDrawable.cpp` (685 / 677 lines) — 23✅ 1⚠️ — [findings](graphics.md#ooskydrawable)
- [x] `Core/OOTextureScaling.m` → `Core/OOTextureScaling.cpp` (1578 / 1690 lines) — 23✅ 6⚠️ 1❌ — [findings](graphics.md#ootexturescaling)
- [x] `Core/OOTextureSprite.m` → `Core/OOTextureSprite.cpp` (115 / 104 lines) — 7✅ — [findings](graphics.md#ootexturesprite)
- [x] `Core/TextureStore.m` → *(no port counterpart: upstream compiled it out with `#if !NEW_PLANETS`; planet textures come from `OOPlanetTextureGenerator`)* — 9➖ — [findings](graphics.md#texturestore)

### HUD, GUI, crosshairs — [hud-gui.md](hud-gui.md)
- [x] `Core/GuiDisplayGen.m` → `Core/GuiDisplayGen.cpp` (2318 / 2673 lines) — 84✅ 2⚠️ 2❌ — [findings](hud-gui.md#guidisplaygen)
- [x] `Core/HeadUpDisplay.m` → `Core/HeadUpDisplay.cpp` (4175 / 4936 lines) — 132✅ 2❌ 4➖ — [findings](hud-gui.md#headupdisplay)
- [x] `Core/OOCrosshairs.m` → `Core/OOCrosshairs.cpp` (188 / 153 lines) — 5✅ — [findings](hud-gui.md#oocrosshairs)
- [x] `Core/OOMouseInteractionMode.m` → `Core/OOMouseInteractionMode.cpp` (74 / 75 lines) — 3✅ — [findings](hud-gui.md#oomouseinteractionmode)

### Universe and GameController — [universe.md](universe.md)
- [x] `Core/GameController.m` → `Core/GameController.cpp` (902 / 822 lines) — 28✅ 5⚠️ 3❌ 24➖ — [findings](universe.md#gamecontroller)
- [x] `Core/Universe.m` → `Core/Universe.cpp` (10164 / 11827 lines) — 347✅ 10⚠️ 11❌ 6➖ — [findings](universe.md#universe)

### SDL platform, input devices, debug support — [platform.md](platform.md)
- [x] `Core/Debug/OODebugMonitor.m` → `Core/Debug/OODebugMonitor.cpp` (933 / 900 lines) — 32✅ 4⚠️ 8➖ — [findings](platform.md#oodebugmonitor)
- [x] `Core/Debug/OODebugStandards.m` → `Core/Debug/OODebugStandards.cpp` (122 / 133 lines) — 10✅ — [findings](platform.md#oodebugstandards)
- [x] `Core/Debug/OODebugSupport.m` → `Core/Debug/OODebugSupport.cpp` (135 / 90 lines) — 1✅ 1➖ — [findings](platform.md#oodebugsupport)
- [x] `Core/Debug/OODebugTCPConsoleClient.m` → `Core/Debug/OODebugTCPConsoleClient.cpp` (768 / 1053 lines) — 28✅ 4⚠️ 1❌ 2➖ — [findings](platform.md#oodebugtcpconsoleclient)
- [x] `Core/Debug/OOTCPStreamDecoderAbstractionLayer.m` → `Core/Debug/OOTCPStreamDecoderAbstractionLayer.cpp` (112 / 177 lines) — 12✅ 1⚠️ 1❌ — [findings](platform.md#ootcpstreamdecoderabstractionlayer)
- [x] `Core/OOFullScreenController.m` → `Core/OOFullScreenController.cpp` (95 / 77 lines) — 9✅ 1❌ 1➖ — [findings](platform.md#oofullscreencontroller)
- [x] `Core/OOJoystickManager.m` → `Core/OOJoystickManager.cpp` (598 / 560 lines) — 33✅ 3⚠️ — [findings](platform.md#oojoystickmanager)
- [x] `Core/OOJoystickProfile.m` → `Core/OOJoystickProfile.cpp` (549 / 521 lines) — 40✅ — [findings](platform.md#oojoystickprofile)
- [x] `SDL/GameController+SDLFullScreen.m` → `SDL/GameController+SDLFullScreen.cpp` (155 / 162 lines) — 8✅ 1⚠️ — [findings](platform.md#gamecontrollersdlfullscreen)
- [x] `SDL/MyOpenGLView+Input.m` → `SDL/MyOpenGLView+Input.cpp` (901 / 961 lines) — 33✅ 1❌ — [findings](platform.md#myopenglviewinput)
- [x] `SDL/MyOpenGLView.m` → `SDL/MyOpenGLView.cpp` (1465 / 1507 lines) — 62✅ 2⚠️ 1❌ — [findings](platform.md#myopenglview)
- [x] `SDL/OOSDLJoystickManager.m` → `SDL/OOSDLJoystickManager.cpp` (295 / 298 lines) — 11✅ 1⚠️ 1➖ — [findings](platform.md#oosdljoystickmanager)
- [x] `SDL/main.m` → `SDL/main.cpp` (257 / 323 lines) — 1❌ — [findings](platform.md#main)

### Game data, resources, registries, AI, strings — [gamedata.md](gamedata.md)
- [x] `Core/AI.m` → `Core/AI.cpp` (930 / 947 lines) — 41✅ 6⚠️ 2❌ 2➖ — [findings](gamedata.md#ai)
- [x] `Core/AIGraphViz.m` → `Core/AIGraphViz.cpp` (233 / 309 lines) — 4✅ 2⚠️ — [findings](gamedata.md#aigraphviz)
- [x] `Core/OOCharacter.m` → `Core/OOCharacter.cpp` (450 / 491 lines) — 29✅ 1⚠️ 1➖ — [findings](gamedata.md#oocharacter)
- [x] `Core/OOColor.m` → `Core/OOColor.cpp` (497 / 524 lines) — 47✅ 1⚠️ 1➖ — [findings](gamedata.md#oocolor)
- [x] `Core/OOCommodities.m` → `Core/OOCommodities.cpp` (540 / 681 lines) — 16✅ 6⚠️ 1➖ — [findings](gamedata.md#oocommodities)
- [x] `Core/OOCommodityMarket.m` → `Core/OOCommodityMarket.cpp` (354 / 352 lines) — 25✅ 3⚠️ 1➖ — [findings](gamedata.md#oocommoditymarket)
- [x] `Core/OOConstToString.m` → `Core/OOConstToString.cpp` (592 / 476 lines) — 42✅ 5❌ 1➖ — [findings](gamedata.md#ooconsttostring)
- [x] `Core/OOConvertSystemDescriptions.m` → `Core/OOConvertSystemDescriptions.cpp` (352 / 344 lines) — 8✅ 3⚠️ — [findings](gamedata.md#ooconvertsystemdescriptions)
- [x] `Core/OOEntityFilterPredicate.m` → `Core/OOEntityFilterPredicate.cpp` (169 / 180 lines) — 19✅ 1➖ — [findings](gamedata.md#ooentityfilterpredicate)
- [x] `Core/OOEquipmentType.m` → `Core/OOEquipmentType.cpp` (748 / 677 lines) — 59✅ 1⚠️ 6❌ 6➖ — [findings](gamedata.md#ooequipmenttype)
- [x] `Core/OOOXZManager.m` → `Core/OOOXZManager.cpp` (2066 / 2579 lines) — 62✅ 4⚠️ 3❌ 3➖ — [findings](gamedata.md#oooxzmanager)
- [x] `Core/OOProbabilitySet.m` → `Core/OOProbabilitySet.cpp` (957 / 723 lines) — 53✅ 3❌ 25➖ — [findings](gamedata.md#ooprobabilityset)
- [x] `Core/OORoleSet.m` → `Core/OORoleSet.cpp` (331 / 278 lines) — 14✅ 4⚠️ 1❌ 3➖ — [findings](gamedata.md#ooroleset)
- [x] `Core/OOShipGroup.m` → `Core/OOShipGroup.cpp` (481 / 416 lines) — 24✅ 1⚠️ 7➖ — [findings](gamedata.md#ooshipgroup)
- [x] `Core/OOShipLibraryDescriptions.m` → `Core/OOShipLibraryDescriptions.cpp` (156 / 176 lines) — 11✅ — [findings](gamedata.md#ooshiplibrarydescriptions)
- [x] `Core/OOShipRegistry.m` → `Core/OOShipRegistry.cpp` (1628 / 1700 lines) — 36✅ 7⚠️ 8➖ — [findings](gamedata.md#ooshipregistry)
- [x] `Core/OOStringExpander.m` → `Core/OOStringExpander.cpp` (1191 / 1626 lines) — 32✅ 5⚠️ 4❌ — [findings](gamedata.md#oostringexpander)
- [x] `Core/OOStringParsing.m` → `Core/OOStringParsing.cpp` (528 / 405 lines) — 20✅ 1⚠️ 3❌ — [findings](gamedata.md#oostringparsing)
- [x] `Core/OOSystemDescriptionManager.m` → `Core/OOSystemDescriptionManager.cpp` (615 / 714 lines) — 28✅ 1⚠️ 2➖ — [findings](gamedata.md#oosystemdescriptionmanager)
- [x] `Core/OOTrumble.m` → `Core/OOTrumble.cpp` (970 / 936 lines) — 39✅ 1❌ 1➖ — [findings](gamedata.md#ootrumble)
- [x] `Core/ResourceManager.m` → `Core/ResourceManager.cpp` (1996 / 2382 lines) — 57✅ 8⚠️ 4❌ 2➖ — [findings](gamedata.md#resourcemanager)


### Extra rows

- [x] C sources and tables (upstream `*.c` → `.cpp` since `48cbd7abf`; `Tables/*.tbl` → `Core/Tables/*.h` and `kStateItems`), checked token by token: 20 rows, 19✅ 1⚠️ — [c-and-tables.md](c-and-tables.md)
- [x] C++-only files (EntityHelpers, OOEntityCalledByName, OODataFromOXZFile, OOPListGameTypes, OOJSEngineNativeWrappers, OOJSPrivateObject, Exception, OOAssert, plus an inventory of 24 files new since the last run) and dispatch-table completeness: 2 med ❌ (exception narrowing, `EntityShortDescription`) — [cpp-only.md](cpp-only.md)
- [x] Maths headers (inline functions in `OOMaths.h`, `OOFastArithmetic.h`, `OOVector.h`, `OOHPVector.h`, `OOQuaternion.h`, `OOMatrix.h`): 95 rows, 93✅ 2⚠️ — [findings](math.md#oomaths)
- [x] Header constants sweep: 238 header pairs, 889 defines, 966 enum values, 173 consts, 110 inlines: 0 ❌, 4 ⚠️ — [headers.md](headers.md)
