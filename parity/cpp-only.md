# Parity findings: C++-only files

Files with no upstream counterpart. Each is reviewed against the upstream code it replaces or factors out.
Upstream paths are relative to `upstream/oolite/src/`; port paths relative to `src/`.

Audited against seriesb/028-upstream-772-tests @ bf01f1b49 on 2026-11-16 (previous run: 2026-10-27).
Markers: (still open), (fixed since 2026-10-27), (new).

## EntityHelpers.cpp
<a id="entityhelpers"></a>

Replaces: ObjC nil-messaging on entities, `+alloc/-init` live-entity counting
(`Core/Entities/Entity.m:90`), `NSObject (OODescriptionComponents)` `-description`/`-shortDescription`
(`Core/OOFoundation.m:44-68`), `Entity (SubEntityRelationship)` (`Core/Entities/ShipEntity.m:12945`) and the
`<OOBeaconEntity>` protocol dispatch (`Core/Entities/Entity.h:299`). Since 2026-10-27 the retain/release/autorelease
helpers have left this file: entity ownership is now `std::shared_ptr` holds in `Core/Entities/OOEntityHold.h`
(see [ooentityhold](#ooentityhold)). The header is `Core/Entities/EntityHelpers.h`.

| Port function | Upstream behaviour replaced | C++ line | Verdict |
|---|---|---|---|
| `oo::WithObject` | nil-messaging guard (an entity without its object answers as nil) | `Core/Entities/EntityHelpers.cpp:60` | ➖ port-internal guard |
| `oo::detail::EntityHasObject` | `entity != nil` | `:67` | ✅ |
| `EntityRetain`/`EntityRelease`/`RetainEntity`/`ReleaseEntity`/`AutoreleaseEntity` | `[entity retain]`/`release`/`autorelease` | gone from this file; now `oo::Hold`/`AutoreleaseHold`/`LeakHold` in `Core/Entities/OOEntityHold.h:64-108` | ➖ moved to OOEntityHold.h |
| `oo::MadeEntityRetained` | `+alloc`/`-init`: `gLiveEntityCount++`, `gTotalEntityMemory += oo_objectSize` (`Entity.m:90-91`) | `:71` | ❌ |
| `oo::MadeEntity` | `[[[X alloc] init…] autorelease]` | `:83` | ✅ |
| `oo::EntityInitAgain` | second `-init` from `PlayerEntity` (`PlayerEntity.m:1604`), counting the entity again | `:88` | ✅ (same size caveat as MadeEntityRetained) |
| `oo::EntityClassName` | `NSStringFromClass([self class])` — now the demangled `typeid` name with `cxx::` stripped | `:100` | ✅ |
| `oo::EntityOwnDescription` | `-description`: `<Class %p>{components}` (`OOFoundation.m:44`) | `:106` | ✅ real class + `descriptionComponents()` |
| `oo::EntityDescription` | `-description`, `"(null)"` for nil | `:117` | ✅ |
| `oo::EntityShortDescription` | `-shortDescription`: `<Class %p>{shortDescriptionComponents}` (`OOFoundation.m:59`; ShipEntity's components `"name"`, `ShipEntity.m:1106`) | `:122` | ❌ |
| `oo::InspectEntity` | `[entity inspect]` | `:128` | ✅ |
| `oo::EntityIsShipWithSubEntityShip` | `Entity (SubEntityRelationship)` NO / ShipEntity / OOVisualEffectEntity | `:135` | ✅ |
| `oo::EntityIsBeacon` | `-isBeacon` on a beacon-protocol class | `:142` | ✅ |
| `oo::PrevBeacon` / `NextBeacon` | `-prevBeacon` / `-nextBeacon` (+0 links) | `:156`, `:167` | ✅ |
| `oo::SetPrevBeacon` / `SetNextBeacon` | `-setPrevBeacon:` / `-setNextBeacon:` | `:178`, `:189` | ✅ |
| `oo::BeaconCode` / `SetBeaconCode` | `-beaconCode` / `-setBeaconCode:` | `:200`, `:210` | ✅ |
| `oo::CompareBeaconCodes` | `-compareBeaconCodeWith:` | `:220` | ✅ |
| `oo::BeaconIsJammingScanning` | `-isJammingScanning` | `:232` | ✅ |
| `oo::BeaconDrawable` / `BeaconLabel` | `-beaconDrawable` / `-beaconLabel` | `:242`, `:252` | ✅ |

**Differences:**
- ❌ **med** (still open) — `EntityShortDescription` still prints `<Entity 0x…>` with no components. Upstream `-shortDescription` used the real class and `shortDescriptionComponents`, e.g. `<ShipEntity 0x…>{"Cobra Mk III"}`. `ShipEntity::shortDescriptionComponents()` exists (`Core/Entities/ShipEntity.cpp:1477`), and `EntityClassName` (`:100`) now gives the real class, but neither is used here. This changes every log line that uses it, e.g. `AI.cpp:242,455,767` (`ai.error.stackOverflow`, `ai.load.failed.unknownAI`), `ShipEntity.cpp:584,1605`, `OOVisualEffectEntity.cpp:654`, `Entity.cpp:183`, `PlayerEntityLegacyScriptEngine.cpp:498` and the debug-monitor memory dump (`OODebugMonitor.cpp:417`) — upstream `Core/OOFoundation.m:59-68`, `Core/Entities/ShipEntity.m:1106` ↔ port `Core/Entities/EntityHelpers.cpp:122-126`
- ❌ **low** (new) — `EntityObjectSize()` is a constant `3 * sizeof(void*)`. Upstream added `oo_objectSize` (`[[self class] oo_instanceSize]`, `NSObjectOOExtensions.m:43-46`), which is the real instance size of each class (hundreds of bytes for a ship). `gTotalEntityMemory` and the debug monitor's memory dump therefore under-report. This affects debug-monitor builds only — upstream `Core/Entities/Entity.m:90-91` ↔ port `Core/Entities/EntityHelpers.h:71`, `EntityHelpers.cpp:78,92`
- ✅ subtle — `EntityIsBeacon` and the beacon accessors answer NO/nil for a non-beacon entity. Upstream would raise "unrecognized selector", but its callers only send these to protocol conformers.
- ✅ subtle — `EntityInitAgain` increments `gLiveEntityCount` a second time for the player, as upstream's nested `-init` did (`PlayerEntity.m:1604`).

**Status:** done — 19 rows: 15 ✅ 0 ⚠️ 2 ❌ 2 ➖

## OOEntityCalledByName.cpp
<a id="ooentitycalledbyname"></a>

Replaces: `-respondsToSelector:` + `-performSelector:` / `-performSelector:withObject:` /
`-performSelector:withObject:afterDelay:` on entities, called from `AI.m:447,488-495`,
`PlayerEntityLegacyScriptEngine.m:191-205,434-517,563,707-709`, `OOJSCall.m:97-170` (callObjC) and
`ShipEntityAI.m:1457` / `PlayerEntitySound.m:420` (deferred). The by-name rows are in the generated
`Core/Entities/OOEntityCalledByNameTable.h` (now 965 rows, was 968). `OOEntityObjectNamesTable.h` holds 159 root/NSObject
names (was 162). The API is documented in `Core/OOCallByName.h`.

| Port function | Upstream behaviour replaced | C++ line | Verdict |
|---|---|---|---|
| `OOEntityByNameAdaptNone/String/PList`, `OOEntityByNameTyped` | IMP call by signature; `OOCallIntegerMethod` sign handling for BOOL | `Core/Entities/OOEntityCalledByName.cpp:88-149` | ✅ |
| `Facade_*` (72 functions) and `kOOEntityFacadeRows` (89 rows) | Entity's own methods and their `-respondsToSelector:` answer; `AnswersPlanet`/`AnswersBeacon` gate the planet-only and beacon-protocol names | `:168-627` | ✅ |
| `oo::EntityObjectNames` / `EntityObjectNameNamed` | NSObject/root selectors the object answered | `:630-644` | ➖ answered, but logged instead of called |
| `oo::EntityFacadeRows` / `EntityFacadeRowNamed` | (lookup) | `:646-660` | ✅ |
| `oo::EntityByNameRows` / `EntityByNameRowNamed` | `NSSelectorFromString` | `:662-676` | ✅ |
| `oo::EntityByNameRowApplies` | `-respondsToSelector:` by class. Checked against the upstream classes for every whitelisted name, including the `ShipEntity (OOAIStationStubs)` stubs (`ShipEntityAI.m:2535-2556`) | `:682` | ✅ |
| `oo::CallEntityByNameTyped` | callObjC typed path (`OOJSCall.m:123-150`) | `:702` | ✅ |
| `ResultKind` | `GetMethodType` signature classification (`OOJSCall.m:196`) | `:730` | ✅ |
| `ApplyingRow` | (glue: lookup + applies) | `:747` | ✅ |
| `CallRow` | `-performSelector:` / `-performSelector:withObject:` | `:755` | ❌ |
| `ObjectClassName` | `[object class]` in log text | `:788` | ⚠️ always `"Entity"` (comment `:785-787`: "of class Entity (not asked)") |
| `LogBadSignature` | none (new log class `callByName.badSignature`) | `:796` | ➖ |
| `CallTabled` | (glue) | `:811` | ✅ |
| `AnsweredObjectName` / `CallObjectName` | an unknown selector raised NSInvalidArgumentException; the port logs `callByName.unknownSelector` instead | `:823-859` | ➖ |
| `oo::EntityRespondsToName` | `-respondsToSelector:` | `:863` | ✅ |
| `oo::CallEntityByName` (3 overloads) | `-performSelector:[withObject:]` | `:874-897` | ✅ |
| `oo::ScheduleEntityCall` | `-performSelector:withObject:afterDelay:`, which retains the target until it fires (port: `oo::share` captured in the deferred call) | `:899` | ✅ |

**Differences:**
- ❌ **low** (still open) — **Argument-count mismatch.** Upstream `performSelector:withObject:` called a no-argument method and ignored the extra argument. For example, an AI action `"setSpeedToCruiseSpeed 0.5"` passes the whitelist on its selector alone, and the method ran. In the port, `CallRow` returns `nullopt` when `hasArgument != (row.argument != kNone)`, so it logs `callByName.badSignature` and does **not** call the method. The reverse case (a colon method with no data) called the method with an undefined argument upstream; the port logs and skips — upstream `Core/AI.m:489-493` ↔ port `Core/Entities/OOEntityCalledByName.cpp:760-763`, `Core/AI.cpp:561-565`
- ❌ **low** (still open) — **Failed expansion with a string parameter.** When description expansion fails, a legacy action passes `oo::PList()` (`PlayerEntityLegacyScriptEngine.cpp:351`). For a String-argument row, `CallRow` returns `nullopt` because the PList is not a string, so the port logs badSignature and does not call the method. Upstream called the method with `nil` (`PlayerEntityLegacyScriptEngine.m:202`) — port `Core/Entities/OOEntityCalledByName.cpp:767-771`
- ⚠️ **low** (still open) — `callByName.unknownSelector` / `callByName.badSignature` are port-only log classes. They print `-[Entity name]` rather than the real class, although `oo::EntityClassName` (`EntityHelpers.cpp:100`) could now supply it. Upstream `performSelector` on an unanswered selector raised an exception. The dispatchers check `EntityRespondsToName` first and the whitelist bounds the names, so these logs are unreachable from legacy scripts and AIs (see [legacy-dispatch](#legacy-dispatch)).
- ✅ subtle — In `EntityByNameRowApplies`, a row flagged only `kEffect` (e.g. `shaderFloat1`) answers YES for every entity (`:686-689`), as the root facade did. Upstream only `OOVisualEffectEntity` responded. This is not observable through the whitelisted dispatchers, because the shader path applies `OOUniformBindingPermitted` (`ShipEntity.cpp:14039`) and no effect name is in an action or query list.
- ✅ subtle — callObjC (`OOJSCall.cpp:87`) can reach only names in `OOJSCallEntityMethods.h`. Upstream could call *any* entity method with a supported signature. That table is reviewed in scripting.md (see [oojscallentitymethods](#oojscallentitymethods)).

**Status:** done — 17 rows: 12 ✅ 1 ⚠️ 1 ❌ 3 ➖

## OODataFromOXZFile.cpp
<a id="oodatafromoxzfile"></a>

Replaces `+[NSData oo_dataWithOXZFile:]` (`Core/NSDataOOExtensions.m:37`) and
`-[NSFileManager oo_oxzFileExistsAtPath:]` (`Core/NSFileManagerOOExtensions.m:215`).

| Port function | Upstream | C++ line | Verdict |
|---|---|---|---|
| `OODataFromOXZFile` | `+[NSData oo_dataWithOXZFile:]` `NSDataOOExtensions.m:37-149` | `Core/OODataFromOXZFile.cpp:39` | ✅ |
| `OOOxzFileExistsAtPath` | `-[NSFileManager oo_oxzFileExistsAtPath:]` `NSFileManagerOOExtensions.m:215-260` | `:147` | ✅ |

**Differences:**
- ✅ subtle **low** (still open) — Upstream's empty-file test used `fileAttributesAtPath:traverseLink:NO`, which reads the size of a symlink itself. `oo::fs::fileSize` follows the link. A symlink to an empty file therefore logs "Expected file but found empty file" and returns nullopt, where upstream returned empty data. Edge case only — upstream `NSDataOOExtensions.m:59` ↔ port `Core/OODataFromOXZFile.cpp:54`
- ✅ — Everything else matches. Compared: the log texts (`kOOLogFileNotFound`), the split at the first `*.oxz` component (case-insensitive extension), case-sensitive `unzLocateFile`, the 8192-byte read loop, the partial data returned after a read error, and the same close/error ordering. The directory test in `OOOxzFileExistsAtPath` also matches.

**Status:** done — 2 rows: 2 ✅ 0 ⚠️ 0 ❌ 0 ➖

## OOPListGameTypes.cpp
<a id="ooplistgametypes"></a>

Replaces the game-type functions of `Core/OOCollectionExtractors.m`. The string forms delegate to
`ScanVectorFromString` / `ScanHPVectorFromString` / `ScanQuaternionFromString` (OOStringParsing; the `cxx_` prefix was dropped
since 2026-10-27). Colour parsing is not in this file (it lives in `OOColor`).

| Port function | Upstream | C++ line | Verdict |
|---|---|---|---|
| `OOVectorFromPList` | `OOVectorFromObject` `OOCollectionExtractors.m:1236` | `Core/OOPListGameTypes.cpp:45` | ✅ |
| `OOHPVectorFromPList` | `OOHPVectorFromObject` `:1266` | `:78` | ✅ |
| `OOQuaternionFromPList` | `OOQuaternionFromObject` `:1294` | `:102` | ✅ |
| `OOPListFromVector` | `OOPropertyListFromVector` `:1325` (`numberWithFloat`) | `:127` | ✅ |
| `OOPListFromHPVector` | `OOPropertyListFromHPVector` `:1334` (`numberWithDouble`) | `:131` | ✅ |
| `OOPListFromQuaternion` | `OOPropertyListFromQuaternion` `:1343` | `:136` | ✅ |
| `OOFuzzyBooleanFromPList` | `OOFuzzyBooleanFromObject` `:1143` (+ `FuzzyBooleanProbabilityFromString` `:1111`); port `oofnd/PListGet.hpp:500` | `:141` | ✅ |

**Differences:**
- ✅ subtle **low** (still open, reworded) — `tupleFrom` skips null *array elements* (`oofnd/PListGet.hpp:452-453`). Upstream's JS→native conversion kept a JS `null` element as `NSNull` (`OOJavaScriptEngine.m:2286-2287`), which `[array count] == 3` counted. So `[1, null, 2, 3]` gives (1,2,3) in the port and the default upstream, and `[1, null, 3]` gives the default in the port and (1,0,3) upstream. The *dictionary* case matches: upstream dropped null values when converting (`OOJavaScriptEngine.m:2090-2092`), so the previous run's `{x: null}` example was wrong. Reachable only from JS-converted arrays — upstream `OOCollectionExtractors.m:1245` ↔ port `oofnd/PListGet.hpp:444-475`
- ✅ — The rest matches. Compared: the OONativeVector box is read only for Vector, never for HPVector or Quaternion; dictionary components missing from a present set default to 0, not to the default's component; the order is x,y,z and w,x,y,z; fuzzy strings go through `floatValue` then the yes/true/on / no/false/off / zero-string fallback; and the test is still `randf() < p`.

**Status:** done — 7 rows: 7 ✅ 0 ⚠️ 0 ❌ 0 ➖

## OOJSEngineNativeWrappers.cpp
<a id="oojsenginenativewrappers"></a>

Replaces the `@catch (id exception)` arm of `OOJS_NATIVE_EXIT` (`Core/Scripting/OOJSEngineNativeWrappers.h:96-103`)
and `OOJSReportWrappedException` (`Core/Scripting/OOJavaScriptEngine.m:973`). The port macro is a `catch (...)` (`OOJSEngineNativeWrappers.h:142-165`).

| Port function | Upstream | C++ line | Verdict |
|---|---|---|---|
| `OOJSReportCurrentException` | `OOJSReportWrappedException`: `NSException` → `"Native exception: %@"` with `reason`, other → `"Unidentified native exception"`, nothing if an exception is pending | `Core/Scripting/OOJSEngineNativeWrappers.cpp:40` | ⚠️ |

**Differences:**
- ⚠️ **low** (still open) — A `std::exception` is caught and reported as `"Native exception: <what()>"` (`:47-49`; the intent is stated at `:35-38` and in the header `:169-175`). Upstream could not catch a C++ exception. Foundation-raised NSExceptions no longer exist; their port equivalents are either fallbacks, which raise nothing, or `std::exception`s whose `what()` text differs from Foundation's reason (e.g. `vector::_M_range_check…` versus `*** -[NSArray objectAtIndex:]: index … beyond bounds`) — upstream `Core/Scripting/OOJavaScriptEngine.m:973-981` ↔ port `Core/Scripting/OOJSEngineNativeWrappers.cpp:40-53`
- ✅ — Matches upstream: the game's exception reason, the pending-exception check, the fallback text, and `return JS_EXCEPTION` (upstream `return NO`).

**Status:** done — 1 row: 0 ✅ 1 ⚠️ 0 ❌ 0 ➖

## OOJSPrivateObject.cpp
<a id="oojsprivateobject"></a>

C++ versions of the `id`-private-slot helpers in `Core/Scripting/OOJavaScriptEngine.m` / `.h`. Header `Core/Scripting/OOJSPrivateObject.h`.

| Port function | Upstream | C++ line | Verdict |
|---|---|---|---|
| `OOJSValueFromCxxObject` | `OOJSValueFromNativeObject` `OOJavaScriptEngine.h:229` (nil → null) | `Core/Scripting/OOJSPrivateObject.cpp:41` | ✅ |
| `OOJSSetCxxPrivate` | `JS_SetPrivate(ctx, obj, [object retain])` | `:47` | ⚠️ releases on failure |
| `OOJSGetCxxPrivateImpl` | `OOJSObjectGetterImplPRIVATE` `OOJavaScriptEngine.m:1990` | `:59` | ⚠️ |
| `OOJSCxxObjectWrapperFinalize` | `OOJSObjectWrapperFinalize` `OOJavaScriptEngine.m:1826` (`oo_clearJSSelf:`, release, clear slot) | `:91` | ✅ |
| `OOJSCxxObjectWrapperToString` | `OOJSObjectWrapperToString` `OOJavaScriptEngine.m:1840` | `:112` | ✅ |

**Differences:**
- ⚠️ **low** (still open) — `OOJSGetCxxPrivateImpl` drops the debug-only check that the native object is of the expected ObjC class ("Native method expected %@ from %s and got correct JS type but incorrect native object %@"). It no longer unwraps a weak reference either: entities unwrap theirs in `OOJSEntityHolder` (see [oojsentityholder](#oojsentityholder); the comment at `:57-58` says so). The JS-class check and its error text are unchanged — upstream `OOJavaScriptEngine.m:2016-2031` ↔ port `Core/Scripting/OOJSPrivateObject.cpp:59-85`
- ⚠️ **low** (still open) — `OOJSSetCxxPrivate` deletes the holder when `JS_SetOpaque` fails, where upstream leaked the retain. The comment at `:46` states the intent — port `:47-56`
- ✅ subtle — In `toString`, upstream fell back to `-oo_jsDescription`, then `-description`, then `"[object <JS class>]"`, then `"[object]"`. Upstream's default `-oo_jsDescription` was never nil, so the port's `jsDescription()` → `"[object <JS class>]"` reproduces it. The port prints `"[object ]"` where upstream printed `"[object]"` for a class with no name, which is unreachable because every registered class has a name.

**Status:** done — 5 rows: 3 ✅ 2 ⚠️ 0 ❌ 0 ➖

## Exception.cpp
<a id="exception"></a>

Replaces `+[NSException raise:format:]`, Foundation's exception name constants, and the
`@catch (NSException *)` / `@catch (id)` classification. Port `oofnd/Exception.cpp` + `oofnd/Exception.hpp`.

| Port function | Upstream | C++ line | Verdict |
|---|---|---|---|
| `OOGenericException` … `OOMallocException` | `NSGenericException` … `NSMallocException` (same text) | `oofnd/Exception.cpp:12-17` | ✅ |
| `FormatReason` | `-[NSString initWithFormat:arguments:]` (`%s` only; `%@` no longer meaningful) | `:22` | ✅ |
| `OORaiseException` | `+[NSException raise:format:]` | `:38` | ✅ |
| `oo::CurrentOOException` | the test that `@catch (NSException *)` / `@catch (id)` made | `:51` | ❌ |

**Differences:**
- ❌ **med** (still open) — `CurrentOOException()` treats only `oo::Exception` as "the game's exception", and every catch site rethrows anything else ("not an OOException: it goes on up, as before"). Upstream's handlers were `@catch (NSException *)` or `@catch (id)`, which caught **every** NSException, including those Foundation raised, then logged and carried on. Re-checked on this commit:
  - the main loop catches only `const oo::Exception&` (`Core/GameController.cpp:404`), and its screen-update arm rethrows (`:415-416`). Upstream had `@catch (id)` on both (`GameController.m:356,363`).
  - AI `Core/AI.cpp:502-504` rethrows. Upstream `AI.m:440` logged "Squashing exception…".
  - PlayerEntityControls `:771,1202,2173,2760,5321` rethrow. Upstream logged "***** Exception in poll…Controls" (`PlayerEntityControls.m:691,1040,1792,2266,4185`).
  - the legacy script engine `PlayerEntityLegacyScriptEngine.cpp:464,489,519` rethrows. Upstream `PlayerEntityLegacyScriptEngine.m:311,336,363` logged.
  - the root handler `SDL/main.cpp:311-313` rethrows too, and no `std::set_terminate` is installed.
  So a `std::exception` (`out_of_range`, `bad_alloc`, `length_error`, `bad_variant_access`) inside any of these regions reaches `std::terminate` with no log line. A live example: `currentLaserOffset().at(0)` (`PlayerEntity.cpp:6225`, `PlayerEntityControls.cpp:1403`) throws `out_of_range` for an empty weapon-offset list, where upstream `oo_vectorAtIndex:0` returned the zero vector and raised nothing (`PlayerEntity.m:5461`). The previous run's "negative-size vector in addShipsAt" example no longer applies: `Universe::addShipsAt` takes `unsigned count` (`Universe.cpp:3415`), and its callers validate the count (`OOJSSystem.cpp` 1..64, legacy `number < 1`, `PlayerEntityLegacyScriptEngine.cpp:1686`) — upstream `Core/AI.m:440`, `Core/GameController.m:356` ↔ port `oofnd/Exception.cpp:51-60`, `Core/GameController.cpp:404`
- ❌ **low** (new, outside this file) — The main loop's `exception.backtrace` line now prints `"<name> : <reason>"`. Upstream printed `[exception callStackSymbols]`, an array of frames, which gnustep's NSException answers. The port comment ("an OOException did not answer it") does not match upstream, where game exceptions were plain NSExceptions — upstream `Core/GameController.m:356-357` ↔ port `Core/GameController.cpp:404-410`
- ✅ subtle — A null format gives an empty reason, where upstream printed `"(null)"` for a nil reason. Every caller passes a format, so this is not reachable.

**Status:** done — 4 rows: 3 ✅ 0 ⚠️ 1 ❌ 0 ➖

## OOAssert.cpp
<a id="ooassert"></a>

Replaces gnustep-base `NSAssert*/NSCAssert*/NSParameterAssert` failure handling
(`NSAssertionHandler -handleFailureInFunction:` / `-handleFailureInMethod:`). Port `oofnd/objc/OOAssert.cpp` + `OOAssert.h`.

| Port function | Upstream | C++ line | Verdict |
|---|---|---|---|
| `FormatV` | `NSString` format of the assertion message | `oofnd/objc/OOAssert.cpp:15` | ✅ |
| `Fail` | `NSLogv` (→ `gnustep` log class via the NSLog hook) + raise `NSInternalInconsistencyException` | `:30` | ✅ |
| `OOAssertFailedInFunction` | `-handleFailureInFunction:file:lineNumber:description:` reason `"<file>:<line>  Assertion failed in <func>.  <msg>"` | `:41` | ⚠️ |
| `OOCAssert` / `OOCParameterAssert` macros | `NSAssert`/`NSCAssert`/`NSParameterAssert`, live in deployment builds | `oofnd/objc/OOAssert.h:43-51` | ✅ |

**Differences:**
- ⚠️ **low** (still open) — Only the C-function form remains. Upstream's *method* asserts read `"<file>:<line>  Assertion failed in <Class>(instance), method <sel>.  <msg>"`. The port prints `__PRETTY_FUNCTION__` (e.g. `void ShipEntity::foo()`) in the function form. `OOAssert.h:27-30` documents that the method forms were removed — upstream gnustep-base `NSAssertionHandler` ↔ port `oofnd/objc/OOAssert.cpp:48-50`
- ✅ (new) — The assertions are now live in every flavour, `NDEBUG` included (`OOAssert.h:8-14`). This matches upstream. `OOFoundation.h:47` defines `NS_BLOCK_ASSERTIONS` only *after* `#import <Foundation/Foundation.h>` (`:35`), and `meson.build:56,70` passes `-DNDEBUG` but not `NS_BLOCK_ASSERTIONS`, so upstream's deployment asserts were never blocked. The previous run's premise ("blocked under NDEBUG exactly as NS_BLOCK_ASSERTIONS was") was wrong.
- ✅ subtle — The NSLog date/process prefix is not reproduced. Because the raised exception is `oo::Exception`, a failed assertion is caught by the game's handlers. The catch-site issue in [exception](#exception) does not apply to it.

**Status:** done — 4 rows: 3 ✅ 1 ⚠️ 0 ❌ 0 ➖

## Legacy script dispatch-table completeness
<a id="legacy-dispatch"></a>

**Method:** `Resources/Config/whitelist.plist` and `shader-uniform-bindings.plist` are byte-identical to upstream
(`diff --strip-trailing-cr`). A throwaway script parsed both, plus the rows of `kOOEntityByNameRows`
(`Core/Entities/OOEntityCalledByNameTable.h:2035`, 965 rows), `kOOEntityFacadeRows` (`Core/Entities/OOEntityCalledByName.cpp:503`, 89 rows) and
`kEntityShaderBindings` (`Core/Entities/EntityShaderBindings.cpp:150`, 86 rows). For every name it checked four things: (a) a row exists; (b) the row's
applies-to flags match the upstream classes whose `@implementation` defines the selector, with the `STATION_STUB_*` macros checked by hand; (c) the
argument kind matches the colon in the name; (d) the result kind is one the dispatcher can use. I then read the bodies of the station-stub rows by hand
(e.g. `ByName_294` `launchPolice`: station → `station->launchPolice()`, else `ship->launchPolice()`, the stub).

Upstream applies aliases *before* the whitelist test (`AI.m:844-861`, `OOLegacyScriptWhitelist.m:417-421,465-469`), so the
names a dispatcher can actually receive are exactly the whitelisted ones.

### Actions and conditions (`PlayerEntityLegacyScriptEngine`, `AI`, string expander)

| List | Names | Tabled | Missing |
|---|---|---|---|
| `action_methods` | 59 | 59 | — |
| `ai_methods` | 157 | 156 | `clearDefenseTargets` (unreachable, see below) |
| `ai_and_action_methods` | 10 | 10 | — |
| `query_methods` | 39 | 39 (all `kPlayer`, result `oo::PList`) | — |
| `action_method_aliases` targets | 2 entries → 1 name | 1 (`doNothing`) | — |
| `query_method_aliases` targets | 3 | 3 | — |
| `ai_method_aliases` targets | 16 entries → 14 names | 14 | — |

- (still open, unchanged) **No reachable gap.** `clearDefenseTargets` is listed in `ai_methods`, but `ai_method_aliases` rewrites it to
  `removeAllDefenseTargets` (tabled) before the whitelist test. Upstream has no such ObjC method either. Five alias sources are also whitelisted
  (`launchTrader`, `setUpEscorts`, `becomeExplosion`, `clearDefenseTargets`, `debugMessage:`). All but `clearDefenseTargets` are tabled
  anyway, and `launchTrader` matches upstream's `STATION_STUB_NOARG(launchTrader)` (`ShipEntityAI.m:2548`).
- **Applies-to sets match upstream** for every tabled whitelisted entry. The only flag/class mismatches the script reported are the twelve
  `STATION_STUB_*` names (`increaseAlertLevel` … `abortAllDockings`, `ShipEntityAI.m:2540-2556`). They are flagged `kShip`, which matches
  upstream's `ShipEntity (OOAIStationStubs)`.
- **Signatures:** every tabled entry has the argument kind its colon implies (0 mismatches). The 225 action/AI entries break down as 89 String
  and 136 None (the previous run reported 88/137 over the same names; no row now disagrees with its colon). Their results are void (214), `OOObjCId` (8), `oo::PList` (2)
  and bool (1), all of which `CallRow` accepts. All 39 query rows return `oo::PList`.
- **Behavioural caveat** (still open): a whitelisted AI action written with a stray argument is not called in the port
  (see [ooentitycalledbyname](#ooentitycalledbyname), ❌ low).
- `hud_dial_methods` (37 names) are HUD selectors, not entity ones (`HeadUpDisplay.cpp` table; not re-checked here).

### Shader bindings (`EntityShaderBindings.cpp`)

Names checked: the union of `shader-uniform-bindings.plist` (`entity`/`ship`/`player`/`visualEffect`) and the four `shader_*_binding_methods`
lists (87 distinct names, plus `$inherit`).

| Missing name | Lists | Upstream | Effect |
|---|---|---|---|
| `laserColor` | `shader_ship_binding_methods`; `ship` = `"color"` | `-(OOColor*)laserColor` `ShipEntity.m:10152` (an `id` return, a supported uniform type via `idMethod`, `OOShaderUniformMethodType.m:96`) | (still open) A shader binding `laserColor` binds upstream and fails in the port (no row) — **known** |

- **No other gaps.** The remaining 86 names each have a row, and every row is in one of the lists.
- (new) The table comment says "laserColor has no method and no row" (`EntityShaderBindings.cpp:98`). The method exists in the port
  (`ShipEntity.h:873`), so only the row is missing. A row would close the gap.
- **Predicates match** the upstream implementing classes (spot-read on this commit). Ship-only rows use `ShipPart`, `viewpointOffset` uses `PlayerEntityPart`,
  `isBeacon`/`isJammingScanning` use the beacon classes, and `hullHeatLevel` is effect-or-ship. `OOUniformBindingPermitted`
  (`Core/Entities/ShipEntity.cpp:14039`) still restricts the `shaderFloat/Int/Vector` names to effects.
- **Encodings** match the upstream return types (`position` HPVector, `damage` int, `escortCount` uint8_t, `fuel` OOFuelQuantity, `fogUniform` OOColor*).
- **Log text (out of file scope, still open):** `ShaderClassName` (`EntityShaderBindings.cpp:944`) answers `"Entity"`. So
  `shader.uniform.unpermittedMethod` / `shader.uniform.bind.failed` print `-[Entity laserColor]` where upstream printed `-[ShipEntity laserColor]`.

**Status:** done — legacy actions/conditions: 0 reachable gaps (1 unreachable whitelisted name); shader bindings: 1 gap (`laserColor`, known), 0 others.

## New C++-only source files
<a id="new-files"></a>

**Method:** every port `.cpp/.hpp/.h` under `src/` whose stem has no upstream `.m`/`.c`/`.h` (outside `src/oofnd`), plus the `.cpp` files whose
stem has an upstream header but no upstream implementation file. All entries are (new): the previous run reviewed only the eight files above.

| Port file | Covered in | Verdict |
|---|---|---|
| `src/oofnd/` (30 entries: Foundation replacement) | its own `src/oofnd/README.md` and audit; `Exception.cpp`, `objc/OOAssert.cpp` above | — |
| `Core/Entities/EntityHelpers.cpp` / `.h` | [entityhelpers](#entityhelpers) | ❌ |
| `Core/Entities/OOEntityCalledByName.cpp` / `.h`, `OOEntityCalledByNameTable.h`, `OOEntityObjectNamesTable.h`, `Core/OOCallByName.h` | [ooentitycalledbyname](#ooentitycalledbyname), [legacy-dispatch](#legacy-dispatch) | ❌ |
| `Core/OODataFromOXZFile.cpp` | [oodatafromoxzfile](#oodatafromoxzfile) | ✅ |
| `Core/OOPListGameTypes.cpp` / `.h` | [ooplistgametypes](#ooplistgametypes) | ✅ |
| `Core/Scripting/OOJSEngineNativeWrappers.cpp` | [oojsenginenativewrappers](#oojsenginenativewrappers) | ⚠️ |
| `Core/Scripting/OOJSPrivateObject.cpp` / `.h` | [oojsprivateobject](#oojsprivateobject) | ⚠️ |
| `Core/Entities/OOEntityHold.h` | [ooentityhold](#ooentityhold) | ✅ |
| `Core/Entities/EntityPListForeign.h` | [entityplistforeign](#entityplistforeign) | ✅ |
| `Core/Entities/EntityVirtualMembers.h`, `Core/UniverseVirtualMembers.h` | [virtualmembers](#virtualmembers) | ➖ |
| `Core/OODemangle.h` | [oodemangle](#oodemangle) | ✅ |
| `Core/OODescription.h` | [oodescription](#oodescription) | ✅ |
| `Core/OOTypeEncodings.h` | [ootypeencodings](#ootypeencodings) | ✅ |
| `Core/Scripting/OOJSCallEntityMethods.h` | [oojscallentitymethods](#oojscallentitymethods) | ⚠️ |
| `Core/Scripting/OOJSClasses.cpp` | [oojsclasses](#oojsclasses) | ⚠️ |
| `Core/Scripting/OOJSEngineCore.h` | [split-headers](#split-headers) | ✅ |
| `Core/Scripting/OOJSEntityHolder.h` | [oojsentityholder](#oojsentityholder) | ✅ |
| `Core/Scripting/OOJavaScriptEngineMonitor.h` | [oojavascriptenginemonitor](#oojavascriptenginemonitor) | ⚠️ |
| `Core/Scripting/poc/OOJavaScriptEnginePoc.cpp`, `poc/OOLogStub.cpp` / `.h` | [poc](#poc) | ➖ |
| `Core/Debug/OOTCPStreamDecoderFormat.hpp` | [ootcpstreamdecoderformat](#ootcpstreamdecoderformat) | ✅ |
| `Core/Materials/OOMaterialState.h`, `Core/Materials/OOTextureFlags.h`, `Core/OOCPUInfoEndian.h`, `Core/OOEntityEnums.h`, `Core/OOMathsBase.h`, `Core/OOOpenGLCheck.h`, `Core/OOOpenGLExtensionPointers.h`, `Core/OOStringWidth.h` | [split-headers](#split-headers) | ✅ |
| `Core/OOEnumFlags.h`, `Core/OOEnumTable.h` | [enum-infra](#enum-infra) | ✅ |
| `Core/Tables/*.h` (10 files) | [tables](#tables) | ✅ |
| `SDL/EXRSnapshotSupport/tinyexr.cpp`, `SDL/stb_image_write.cpp` | [impl-tus](#impl-tus) | ✅ |

Not C++-only, so excluded: `SDL/EXRSnapshotSupport/OOSaveEXRSnapshot.cpp` has an upstream `.cpp`. Its diff is formatting, casts and a
`std::string` signature buffer in place of a fixed `char[255]`. The port also frees `custom_attributes`, which upstream leaked. No behaviour change.

**Status:** done — 24 inventory rows (23 file groups + `src/oofnd/`); 1 excluded file noted.

## OOEntityHold.h
<a id="ooentityhold"></a>

Replaces `-retain`/`-release`/`-autorelease` on entities and `NSMutableArray` membership of entities (`containsObject:`/`removeObject:`).
`oo::Hold` is a `shared_ptr` that is null for an entity without its object (nil-messaging). `AutoreleaseHold` hands the hold to the innermost
`oo::AutoreleaseScope` (pool drain order). `FindHold`/`EraseHold` remove *every* hold of the entity, as `-removeObject:` did. `LeakHold` keeps the
deliberate leaks — `Core/Entities/OOEntityHold.h:64-108`.

**Status:** done — ✅ equivalent (ownership model replaced; no observable difference found)

## EntityPListForeign.h
<a id="entityplistforeign"></a>

Replaces an entity stored directly as an `id` in a Foundation collection. The PList Object node holds the entity (keeping it alive, as the
collection's retain did). It describes itself with `oo::EntityDescription` (real class + components) and converts to the entity's JS value.
The node's class name is `"Entity"`, but that name is only used for dispatch; it is not printed — `Core/Entities/EntityPListForeign.h:45-66`.

**Status:** done — ✅

## EntityVirtualMembers.h / UniverseVirtualMembers.h
<a id="virtualmembers"></a>

Port-only test seams: X-macro lists of the virtual members of `Entity` and `Universe`, so that unit-test stand-ins have the same vtable. They replace
nothing behavioural (ObjC dispatch was dynamic).

**Status:** done — ➖ port infrastructure, no upstream behaviour

## OODemangle.h
<a id="oodemangle"></a>

Replaces `NSStringFromClass` for C++ classes: `abi::__cxa_demangle(typeid(x).name())`, or the mangled name if demangling fails. `EntityClassName`
then strips `cxx::`. The result is the upstream class name for the global-namespace entity classes — `Core/OODemangle.h:30-36`.

**Status:** done — ✅

## OODescription.h
<a id="oodescription"></a>

Replaces `%@` formatting of property lists (`-[NSArray/NSDictionary description]`, gnustep-base text via `oofnd/PListDescription.hpp`) and the
`OODescriptionComponents` pattern (`OOFoundation.m:44-57`): `<Class 0x…>{components}`. This is the mechanism `EntityShortDescription` should
use (see [entityhelpers](#entityhelpers)).

**Status:** done — ✅ (gnustep byte-for-byte text is covered by oofnd tests; not re-derived here)

## OOTypeEncodings.h
<a id="ootypeencodings"></a>

Replaces `@encode()`. It is a hand-maintained table of the encodings clang produced on the last ObjC++ build (eae8c876d). `ResultKind`
(by-name dispatch), `LogBadSignature` and `OOShaderUniformTypeFromEncoding` use it. The dispatch check above found every whitelisted row's
encoding to be one the dispatcher accepts.

**Status:** done — ✅

## OOJSCallEntityMethods.h
<a id="oojscallentitymethods"></a>

Replaces callObjC's ability to call any entity method with a supported signature (`OOJSCall.m:97-170`). It is a hand-maintained list of the
by-name rows callObjC may call (`OOJSCall.cpp:87`).

**Differences:**
- ⚠️ **low** — callObjC is bounded by this list. Upstream bounded it only by the signature, so a method missing here is "cannot be called"
  in the port. The header documents the design (`:3-10`); its contents are reviewed in scripting.md.

**Status:** done — ⚠️ intentional (documented)

## OOJSClasses.cpp
<a id="oojsclasses"></a>

Replaces SpiderMonkey `JSClass` registration and `JS_InitClass`, plus `OOJSRegisterSubclass` / `OOJSIsSubclass` (`OOJavaScriptEngine.m:1954-1988`).
It also emulates SpiderMonkey's "shared permanent" prototype accessors as own properties of instances (`:36-45`, `:115-198`).

**Differences:**
- ⚠️ **low** — Own-property emulation: QuickJS defines accessors on the prototype, so the port adds exotic `get_own_property(_names)` to make
  `Object.keys()` / `hasOwnProperty` answer as SpiderMonkey did (direct prototype only, first duplicate kept). The comment (`:42-45`) says this was
  checked against SpiderMonkey with tools/js-parity — port `Core/Scripting/OOJSClasses.cpp:115-198`
- ✅ subtle — `OOJSRegisterSubclass` accepts re-registration with the *same* superclass (`:98-100`), where upstream asserted the slot was empty.
  Upstream cleared the map on engine shutdown, so a re-init raised nothing in either.
- ✅ — The constructor is defined on the global as writable, configurable and non-enumerable (`:240-241`), as `JS_InitClass` did. `OOJSIsSubclass`
  walks the same chain (`:105-113`).

**Status:** done — ⚠️ intentional engine-forced emulation

## OOJSEntityHolder.h
<a id="oojsentityholder"></a>

Replaces the `OOWeakReference` that upstream stored in an entity's JS private slot (`-weakRetain`, `weakRefUnderlyingObject`). The holder keeps a
`std::weak_ptr`, so a JS object for a dead entity reads as stale. This matches upstream's weak ref going nil — `Core/Scripting/OOJSEntityHolder.h:3-12`.

**Status:** done — ✅

## OOJavaScriptEngineMonitor.h
<a id="oojavascriptenginemonitor"></a>

Replaces `@protocol OOJavaScriptEngineMonitor` (`OOJavaScriptEngine.h:558-575`) with a C++ interface with the same two messages.

**Differences:**
- ⚠️ **low** — QuickJS has no `JSErrorReport`, so errors reach the monitor as severity ("exception"/"warning") + the innermost stack location
  rather than a report with flags and line text. The header (`:43-46`) documents this. It affects the debug console's error presentation.

**Status:** done — ⚠️ intentional (engine-forced)

## QuickJS proof of concept (poc/)
<a id="poc"></a>

`Core/Scripting/poc/OOJavaScriptEnginePoc.cpp`, `OOLogStub.cpp/.h` are built only with `-Dquickjs_poc` (`meson.build:106-107`), never into the game.

**Status:** done — ➖ not shipped

## OOTCPStreamDecoderFormat.hpp
<a id="ootcpstreamdecoderformat"></a>

Replaces `-[NSString initWithFormat:arguments:]` in `OOTCPStreamDecoderAbstractionLayer.m` for the conversions `OOTCPStreamDecoder.c` uses
(`%u`, `%zu`, `%@`, `%%`). Anything else is copied verbatim, and a trailing lone `%` is kept. The decoder uses nothing else, and the formatter has a unit test
(`tests/unit/oofnd/test_tcp_stream_format.cpp`).

**Status:** done — ✅

## Split headers
<a id="split-headers"></a>

Each of these is a verbatim or near-verbatim split of an upstream header, made so that plain C++ units can include it. Spot-checked:

| Port file | Split out of | Verdict |
|---|---|---|
| `Core/OOCPUInfoEndian.h` | `OOCPUInfo.h` endian block (preprocessor lines identical) | ✅ |
| `Core/Materials/OOTextureFlags.h` | `OOTexture.h` `kOOTexture*` options (every value identical; `kDefinedFlags` same members). `kFlagsMask` is now 32-bit, which is enough for the 32-bit flag set | ✅ |
| `Core/OOOpenGLCheck.h` | `OOOpenGL.h` error checking (`OO_GL_STATE_VERIFICATION`, `OO_CHECK_GL_HEAVY` same) | ✅ |
| `Core/OOOpenGLExtensionPointers.h` | `OOOpenGLExtensionManager.h` switches (`OO_SHADERS`, `OO_USE_VBO`=0, `OO_USE_FBO`, `OO_MULTITEXTURE`, `OO_TEXTURE_CUBE_MAP` same conditions) | ✅ |
| `Core/OOMathsBase.h` | `OOMaths.h` scalar types / MIN/MAX/ABS (constants compared in headers.md) | ✅ |
| `Core/OOEntityEnums.h` | `Entity.h`/`PlayerEntity.h`/`ShipEntity.h` enums (now includes `Core/Tables/*.h`) | ✅ |
| `Core/Materials/OOMaterialState.h` | `OOMaterial` current-material save/restore declarations | ✅ |
| `Core/OOStringWidth.h` | `OOStringWidthInEm` declaration from `HeadUpDisplay.h` | ✅ |
| `Core/Scripting/OOJSEngineCore.h` | `OOJavaScriptEngine.h` plain part (QuickJS API; reviewed with the engine in scripting.md) | ✅ |

**Status:** done — 9 rows: 9 ✅

## OOEnumFlags.h / OOEnumTable.h
<a id="enum-infra"></a>

Port infrastructure for `enum class`: bit operators, and name tables replacing the `OOConstToString.m` `CASE`/`REVERSE_CASE` macros. `EnumTable::value`
is exact and case-sensitive, as `-isEqualToString:` was (`OOConstToString.m:35-37`). How an unknown value is answered (`""` from `OOEnumName` against
upstream's `"UNDEFINED"`) is decided at the `OOConstToString`/`OOConstToJSString` callers, which this run did not re-check.

**Status:** done — ✅

## Core/Tables/*.h
<a id="tables"></a>

The ten `.tbl` X-macro tables (`OOBehaviour`, `OOCompassMode`, `OOEntityStatus`, `OOGUIScreenID`, `OOGalacticHyperspaceBehaviour`,
`OOLegalStatusReason`, `OOLongRangeChartMode`, `OOScanClass`, `OOShipDamageType`, `OOViewID`) are now `enum class` + `OOEnumName` headers.
`OOOpenGLStates.tbl` stays a `.tbl`. A throwaway script compared each upstream `.tbl`'s order, names (`#label`, or the `DIFF_STRING_ENTRY` string)
and effective values (`label = value` where upstream's `ENTRY` used it, otherwise sequential) with the port enum values, `static_assert`s and
`OOEnumName` strings. All ten match in name, order and value, including `BEHAVIOUR_UNKNOWN = -1` and the sequential `OOViewID`
(`VIEW_NONE` = 5, so `vdir > VIEW_STARBOARD` at `PlayerEntity.cpp:2921` behaves as upstream).

**Status:** done — 10 rows: 10 ✅

## Implementation translation units
<a id="impl-tus"></a>

`SDL/EXRSnapshotSupport/tinyexr.cpp` (`TINYEXR_IMPLEMENTATION`, WIN32 only, as before) and `SDL/stb_image_write.cpp` (`STB_IMAGE_WRITE_IMPLEMENTATION`,
upstream defined it in `MyOpenGLView.m:44`). They move the header-library implementations into their own units so they build without the game's warning flags.

**Status:** done — ✅
