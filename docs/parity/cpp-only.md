# Parity findings: C++-only files

Files with no upstream counterpart. Each is reviewed against the upstream code it replaces or factors out.
Upstream paths are relative to `upstream/oolite/src/`; port paths relative to `src/`.

## EntityHelpers.cpp
<a id="entityhelpers"></a>

Replaces: ObjC nil-messaging and `-retain/-release/-autorelease` on entities, `+alloc/-init` live-entity counting
(`Core/Entities/Entity.m:90`), `NSObject (OODescriptionComponents)` `-description`/`-shortDescription`
(`Core/OOFoundation.m:44-68`), `Entity (SubEntityRelationship)` (`Core/Entities/ShipEntity.m:12945`) and the
`<OOBeaconEntity>` protocol dispatch (`Core/Entities/Entity.h:299`).

| Port function | Upstream behaviour replaced | C++ line | Verdict |
|---|---|---|---|
| `oo::WithObject` | nil-messaging guard (an entity without its object answers as nil) | `Core/Entities/EntityHelpers.cpp:55` | ➖ port-internal guard |
| `oo::detail::EntityHasObject` | `entity != nil` | `:62` | ✅ |
| `oo::detail::EntityRetain` / `EntityRelease` | `[entity retain]` / `[entity release]` | `:63`, `:68` | ✅ |
| `oo::RetainEntity` / `ReleaseEntity` | `[entity retain]` / `[entity release]` (nil: no-op) | `:74`, `:81` | ✅ |
| `oo::AutoreleaseEntity` | `[entity autorelease]` (same pool drain order, beads oo-pvhrh, oo-31u.6) | `:87` | ✅ |
| `oo::MadeEntityRetained` | `+alloc`/`-init`: `gLiveEntityCount++`, `gTotalEntityMemory += oo_objectSize` (`Entity.m:90-91`) | `:96` | ✅ |
| `oo::MadeEntity` | `[[[X alloc] init…] autorelease]` | `:110` | ✅ |
| `oo::EntityInitAgain` | second `-init` from `PlayerEntity` (`PlayerEntity.m:1604`), counting the entity again | `:115` | ✅ |
| `oo::EntityClassName` | `NSStringFromClass([self class])` | `:127` | ✅ |
| `oo::EntityOwnDescription` | `-description`: `<Class %p>{components}` (`OOFoundation.m:44`) | `:138` | ✅ |
| `oo::EntityDescription` | `-description`, `"(null)"` for nil | `:149` | ✅ |
| `oo::EntityShortDescription` | `-shortDescription`: `<Class %p>{shortDescriptionComponents}` (`OOFoundation.m:59`; ShipEntity's components `"name"`, `ShipEntity.m:1106`) | `:154` | ❌ |
| `oo::InspectEntity` | `[entity inspect]` | `:163` | ✅ |
| `oo::EntityIsShipWithSubEntityShip` | `Entity (SubEntityRelationship)` NO / ShipEntity / OOVisualEffectEntity | `:171` | ✅ |
| `oo::EntityIsBeacon` | `-isBeacon` on a beacon-protocol class | `:179` | ✅ |
| `oo::PrevBeacon` / `NextBeacon` | `-prevBeacon` / `-nextBeacon` (+0 links) | `:194`, `:206` | ✅ |
| `oo::SetPrevBeacon` / `SetNextBeacon` | `-setPrevBeacon:` / `-setNextBeacon:` | `:218`, `:230` | ✅ |
| `oo::BeaconCode` / `SetBeaconCode` | `-beaconCode` / `-setBeaconCode:` | `:242`, `:254` | ✅ |
| `oo::CompareBeaconCodes` | `-compareBeaconCodeWith:` | `:265` | ✅ |
| `oo::BeaconIsJammingScanning` | `-isJammingScanning` | `:278` | ✅ |
| `oo::BeaconDrawable` / `BeaconLabel` | `-beaconDrawable` / `-beaconLabel` | `:290`, `:302` | ✅ |

**Differences:**
- ❌ **med** — `EntityShortDescription` always prints `<Entity 0x…>` with no components. Upstream `-shortDescription` used the real class and the `shortDescriptionComponents`, e.g. `<ShipEntity 0x…>{"Cobra Mk III"}`. The port has `ShipEntity::shortDescriptionComponents()` (`Core/Entities/ShipEntity.cpp:1399`), but nothing calls it from here. This changes the text of every log line that uses it: `ai.error.stackOverflow`, `ai.load.failed.unknownAI`, `ship.subentity.sanityCheck.failed`, `entity.invalidSession`, `universe.sessionIDs.verify.failed`, `script.debug.note.addShips`, the OOShipGroup description and the debug-monitor memory dump. The comment ("the facade did not override") describes an intermediate port state, not upstream — upstream `Core/OOFoundation.m:59-68`, `Core/Entities/ShipEntity.m:1106` ↔ port `Core/Entities/EntityHelpers.cpp:154-161`
- ✅ subtle — `EntityIsBeacon` and the beacon accessors answer NO/nil for a non-beacon entity. Upstream would raise "unrecognized selector", but its callers only send these to protocol conformers, so nothing observable changes.
- ✅ subtle — `EntityInitAgain` increments `gLiveEntityCount` a second time for the player. Upstream does the same through its nested `-init` (`PlayerEntity.m:1604`).

**Status:** done — 27 rows: 25 ✅ 0 ⚠️ 1 ❌ 1 ➖

## OOEntityCalledByName.cpp
<a id="ooentitycalledbyname"></a>

Replaces: `-respondsToSelector:` + `-performSelector:` / `-performSelector:withObject:` /
`-performSelector:withObject:afterDelay:` on entities, called from `AI.m:447,488-495`,
`PlayerEntityLegacyScriptEngine.m:191-205,434-517,563,707-709`, `OOJSCall.m:97-170` (callObjC) and
`ShipEntityAI.m:1457` / `PlayerEntitySound.m:420` (deferred). The by-name rows themselves are in the generated
`Core/Entities/OOEntityCalledByNameTable.h` (968 rows). `OOEntityObjectNamesTable.h` holds 162 root/NSObject names.

| Port function | Upstream behaviour replaced | C++ line | Verdict |
|---|---|---|---|
| `OOEntityByNameAdaptNone/String/PList`, `OOEntityByNameTyped` | IMP call by signature; `OOCallIntegerMethod` sign handling for BOOL | `:79-138` | ✅ |
| `Facade_*` (63 functions) and `kOOEntityFacadeRows` (90 rows) | Entity's own methods and their `-respondsToSelector:` answer. Mechanically checked: rows gated `AnswersPlanet`/`AnswersBeacon` are exactly the names upstream implements only on `OOPlanetEntity` / the three beacon classes | `:161-734` | ✅ |
| `oo::EntityObjectNames` / `EntityObjectNameNamed` | NSObject/root selectors the object answered | `:740-755` | ➖ answered, but logged instead of called |
| `oo::EntityFacadeRows` / `EntityFacadeRowNamed` | (lookup) | `:757-772` | ✅ |
| `oo::EntityByNameRows` / `EntityByNameRowNamed` | `NSSelectorFromString` | `:774-789` | ✅ |
| `oo::EntityByNameRowApplies` | `-respondsToSelector:` by class. Checked against upstream classes for every whitelisted name, including the `ShipEntity (OOAIStationStubs)` stubs (`ShipEntityAI.m:2533-2556`) | `:794` | ✅ |
| `oo::CallEntityByNameTyped` | callObjC typed path (`OOJSCall.m:123-150`) | `:812` | ✅ |
| `ResultKind` | `GetMethodType` signature classification (`OOJSCall.m:196`) | `:840` | ✅ |
| `CallRow` | `-performSelector:` / `-performSelector:withObject:` | `:865` | ❌ |
| `LogBadSignature` | none (new log class `callByName.badSignature`) | `:909` | ➖ |
| `CallTabled` | (glue) | `:920` | ✅ |
| `AnsweredObjectName` / `CallObjectName` | an unknown selector raised NSInvalidArgumentException; the port logs `callByName.unknownSelector` instead | `:932-962` | ➖ |
| `ObjectClassName` | `[object class]` in log text | `:898` | ⚠️ always `"Entity"` (bead oo-9ht.39.9) |
| `oo::EntityRespondsToName` | `-respondsToSelector:` | `:966` | ✅ |
| `oo::CallEntityByName` (3 overloads) | `-performSelector:[withObject:]` | `:979-1004` | ✅ |
| `oo::ScheduleEntityCall` | `-performSelector:withObject:afterDelay:`, which retains the target until it fires | `:1006` | ✅ |

**Differences:**
- ❌ **low** — **Argument-count mismatch.** Upstream `performSelector:withObject:` called a no-argument method and ignored the extra argument. For example, an AI action `"setSpeedToCruiseSpeed 0.5"` passes the whitelist on its selector alone (`AI.m:860`), and the method ran. In the port, `CallRow` returns `nullopt` when `hasArgument != (row.argument != None)`, so it logs `callByName.badSignature` and does **not** call the method. The reverse case (a colon method with no data) called the method with an undefined argument upstream; the port logs and skips — upstream `Core/AI.m:489-493` ↔ port `Core/Entities/OOEntityCalledByName.cpp:869-870`, `Core/AI.cpp:570-574`
- ❌ **low** — **Failed expansion with a string parameter.** When description expansion fails, a legacy action passes `oo::PList()` (`PlayerEntityLegacyScriptEngine.cpp:331`). For a String-argument row, `CallRow` returns `nullopt` because the PList is not a string, so the port logs badSignature and does not call the method. Upstream called the method with `nil` (`PlayerEntityLegacyScriptEngine.m:202`) — port `Core/Entities/OOEntityCalledByName.cpp:875-878`
- ⚠️ **low** — `callByName.unknownSelector` / `callByName.badSignature` are port-only log classes. They print `-[Entity name]` rather than the real class. Upstream `performSelector` on an unanswered selector raised an exception. The dispatchers check `EntityRespondsToName` first and the whitelist bounds the names, so these logs are unreachable from legacy scripts and AIs (see [legacy-dispatch](#legacy-dispatch)).
- ✅ subtle — In `EntityByNameRowApplies`, a row flagged only `kOOByNameEffect` (e.g. `shaderFloat1`) answers YES for every entity, as the root facade did. Upstream only `OOVisualEffectEntity` responded. This is not observable through the whitelisted dispatchers, because the shader path applies `OOUniformBindingPermitted` and no effect name is in an action or query list.
- ✅ subtle — callObjC (`OOJSCall.cpp:199`) can reach only names in `OOJSCallEntityMethods.h`. Upstream could call *any* entity method with a supported signature. That table is reviewed in scripting.md; it is outside this file.

**Status:** done — 16 rows: 11 ✅ 1 ⚠️ 1 ❌ 3 ➖

## OODataFromOXZFile.cpp
<a id="oodatafromoxzfile"></a>

Replaces `+[NSData oo_dataWithOXZFile:]` (`Core/NSDataOOExtensions.m:37`) and
`-[NSFileManager oo_oxzFileExistsAtPath:]` (`Core/NSFileManagerOOExtensions.m:215`).

| Port function | Upstream | C++ line | Verdict |
|---|---|---|---|
| `OODataFromOXZFile` | `+[NSData oo_dataWithOXZFile:]` `NSDataOOExtensions.m:37-149` | `Core/OODataFromOXZFile.cpp:38` | ✅ |
| `OOOxzFileExistsAtPath` | `-[NSFileManager oo_oxzFileExistsAtPath:]` `NSFileManagerOOExtensions.m:215-260` | `:147` | ✅ |

**Differences:**
- ✅ subtle **low** — Upstream's empty-file test used `fileAttributesAtPath:traverseLink:NO`, which reads the size of a symlink itself. `oo::fs::fileSize` uses `std::filesystem::file_size`, which follows the link. A symlink to an empty file therefore logs "Expected file but found empty file" and returns nullopt; upstream returned empty data. Edge case only — upstream `NSDataOOExtensions.m:59` ↔ port `Core/OODataFromOXZFile.cpp:62`
- ✅ — Everything else matches: the same log texts (`kOOLogFileNotFound`), the same component split at the first `*.oxz`, case-sensitive `unzLocateFile`, an 8192-byte read loop, partial data returned after a read error, and the same close/error ordering.

**Status:** done — 2 rows: 2 ✅ 0 ⚠️ 0 ❌ 0 ➖

## OOPListGameTypes.cpp
<a id="ooplistgametypes"></a>

Replaces the game-type functions of `Core/OOCollectionExtractors.m`. The string forms delegate to
`cxx_Scan*FromString` (OOStringParsing). Colour parsing is not in this file (it lives in `OOColor`).

| Port function | Upstream | C++ line | Verdict |
|---|---|---|---|
| `OOVectorFromPList` | `OOVectorFromObject` `OOCollectionExtractors.m:1236` | `Core/OOPListGameTypes.cpp:40` | ✅ |
| `OOHPVectorFromPList` | `OOHPVectorFromObject` `:1266` | `:71` | ✅ |
| `OOQuaternionFromPList` | `OOQuaternionFromObject` `:1294` | `:95` | ✅ |
| `OOPListFromVector` | `OOPropertyListFromVector` `:1325` (`numberWithFloat`) | `:120` | ✅ |
| `OOPListFromHPVector` | `OOPropertyListFromHPVector` `:1334` (`numberWithDouble`) | `:125` | ✅ |
| `OOPListFromQuaternion` | `OOPropertyListFromQuaternion` `:1343` | `:130` | ✅ |
| `OOFuzzyBooleanFromPList` | `OOFuzzyBooleanFromObject` `:1143` (+ `FuzzyBooleanProbabilityFromString` `:1111`) | `:135` | ✅ |

**Differences:**
- ✅ subtle **low** — `tupleFrom` treats a null element or value as absent (`oofnd/PListGet.hpp:450,467`). Upstream counted an `NSNull` in `[array count] == 3` and as a present dictionary key, read as 0. So `[1, null, 2, 3]` gives (1,2,3) in the port and the default upstream, and `{x: null}` keeps the default in the port but gives (0,0,0) upstream. Such values can only come from JS-converted collections — upstream `OOCollectionExtractors.m:1245-1255` ↔ port `oofnd/PListGet.hpp:440-479`
- ✅ — The rest matches: the OONativeVector box is read only for Vector, never for HPVector or Quaternion; dictionary components missing from a present set default to 0, not the default's component; the vector order is x,y,z and the quaternion order w,x,y,z; and `randf() < p` is unchanged.

**Status:** done — 7 rows: 7 ✅ 0 ⚠️ 0 ❌ 0 ➖

## OOJSEngineNativeWrappers.cpp
<a id="oojsenginenativewrappers"></a>

Replaces the `@catch (id exception)` arm of `OOJS_NATIVE_EXIT` (`Core/Scripting/OOJSEngineNativeWrappers.h:96-103`)
and `OOJSReportWrappedException` (`Core/Scripting/OOJavaScriptEngine.m:973`).

| Port function | Upstream | C++ line | Verdict |
|---|---|---|---|
| `OOJSReportCurrentException` | `OOJSReportWrappedException`: `NSException` → `"Native exception: %@"` with `reason`, other → `"Unidentified native exception"`, nothing if an exception is pending | `Core/Scripting/OOJSEngineNativeWrappers.cpp:45` | ⚠️ |

**Differences:**
- ⚠️ **low** — A `std::exception` is now caught and reported as `"Native exception: <what()>"`. Upstream could not catch a C++ exception, so the process terminated (ADR-0029 measurement 10, bead oo-ppc). Foundation-raised NSExceptions (range/argument errors from containers) no longer exist. Their port equivalents are either fallbacks, which raise nothing, or `std::exception`s whose `what()` text differs from Foundation's reason (e.g. `vector::_M_range_check…` versus `*** -[NSArray objectAtIndex:]: index … beyond bounds`) — upstream `Core/Scripting/OOJavaScriptEngine.m:973-981` ↔ port `Core/Scripting/OOJSEngineNativeWrappers.cpp:45-60`
- ✅ — Matches upstream: the game's exception reason, the pending-exception check and the fallback text.

**Status:** done — 1 row: 0 ✅ 1 ⚠️ 0 ❌ 0 ➖

## OOJSPrivateObject.cpp
<a id="oojsprivateobject"></a>

C++ versions of the `id`-private-slot helpers in `Core/Scripting/OOJavaScriptEngine.m` / `.h`.

| Port function | Upstream | C++ line | Verdict |
|---|---|---|---|
| `OOJSValueFromCxxObject` | `OOJSValueFromNativeObject` `OOJavaScriptEngine.h:229` | `Core/Scripting/OOJSPrivateObject.cpp:39` | ✅ |
| `OOJSSetCxxPrivate` | `JS_SetPrivate(ctx, obj, [object retain])` | `:47` | ⚠️ releases on failure |
| `OOJSGetCxxPrivateImpl` | `OOJSObjectGetterImplPRIVATE` `OOJavaScriptEngine.m:1990` | `:60` | ⚠️ |
| `OOJSCxxObjectWrapperFinalize` | `OOJSObjectWrapperFinalize` `OOJavaScriptEngine.m:1826` | `:81` | ✅ |
| `OOJSCxxObjectWrapperToString` | `OOJSObjectWrapperToString` `OOJavaScriptEngine.m:1840` | `:97` | ✅ |

**Differences:**
- ⚠️ **low** — `OOJSGetCxxPrivateImpl` drops the debug-only check that the native object is of the expected ObjC class ("Native method expected %@ from %s and got correct JS type but incorrect native object %@"). It also no longer unwraps a weak reference: entities now unwrap theirs in `OOJSEntityHolder` (amendment oo-6symp / oo-9ht.39.3). The JS-class check and its error text are unchanged — upstream `OOJavaScriptEngine.m:2024-2031` ↔ port `Core/Scripting/OOJSPrivateObject.cpp:74`
- ⚠️ **low** — `OOJSSetCxxPrivate` balances the retain when `setPrivate` fails, where upstream leaked it. The code comment states the intent — port `:47-56`
- ✅ subtle — In `toString`, upstream fell back to `-oo_jsDescription`, then `-description`, then `"[object <JS class>]"`, then `"[object]"`. Upstream's default `-oo_jsDescription` was never nil (`OOJavaScriptEngine.m:1289-1312`), so the port's `jsDescription()` → `"[object <JS class>]"` reproduces it when each glue's `jsDescription()` does. A wrong JS class goes to the generic `OOJSObjectWrapperToString`.

**Status:** done — 5 rows: 3 ✅ 2 ⚠️ 0 ❌ 0 ➖

## Exception.cpp
<a id="exception"></a>

Replaces `+[NSException raise:format:]` (28 upstream raise sites), Foundation's exception name constants, and
`@catch (NSException *)` / `@catch (id)` classification.

| Port function | Upstream | C++ line | Verdict |
|---|---|---|---|
| `OOGenericException` … `OOMallocException` | `NSGenericException` … `NSMallocException` (same text) | `oofnd/Exception.cpp:12-16` | ✅ |
| `FormatReason` | `-[NSString initWithFormat:arguments:]` (`%s` only; `%@` no longer meaningful) | `:21` | ✅ |
| `OORaiseException` | `+[NSException raise:format:]` | `:38` | ✅ |
| `oo::CurrentOOException` | the test `@catch (NSException *)` / `@catch (id)` made | `:51` | ❌ |

**Differences:**
- ❌ **med** — `CurrentOOException()` treats only `oo::Exception` as "the game's exception". Every catch site rethrows anything else ("not an OOException: it goes on up, as before"). Upstream's handlers are `@catch (NSException *)` or `@catch (id)`. They caught **every** NSException, including those Foundation raised (range errors, nil insertions, …), logged them, and carried on. Examples: `AI.m:440` "Squashing exception…", `PlayerEntityControls.m:1790` "***** Exception in pollFlightControls", `PlayerEntityLegacyScriptEngine.m:311`, and the main loop `GameController.m:356` `@catch (id)`. In the port, a `std::exception` (`bad_alloc`, `out_of_range`, `bad_variant_access`, `length_error`) raised inside any of these regions is not squashed and reaches `std::terminate`. The main loop catches only `const oo::Exception&` (`Core/GameController.cpp:425`). Effect: an error upstream logged and survived is now a crash — upstream `Core/AI.m:440`, `Core/GameController.m:356` ↔ port `oofnd/Exception.cpp:51-60`, `Core/AI.cpp:511-514`
- ✅ subtle — A null reason becomes `""`, where upstream printed `"(null)"` for a nil reason. Every caller passes a format, so this is not reachable.

**Status:** done — 4 rows: 3 ✅ 0 ⚠️ 1 ❌ 0 ➖

## OOAssert.cpp
<a id="ooassert"></a>

Replaces gnustep-base `NSAssert*/NSCAssert*/NSParameterAssert` failure handling
(`NSAssertionHandler -handleFailureInFunction:` / `-handleFailureInMethod:`), which is blocked under `NDEBUG`
exactly as `NS_BLOCK_ASSERTIONS` was (`Core/OOFoundation.h:47`).

| Port function | Upstream | C++ line | Verdict |
|---|---|---|---|
| `FormatV` | `NSString` format of the assertion message | `oofnd/objc/OOAssert.cpp:14` | ✅ |
| `Fail` | `NSLogv` (→ `gnustep` log class via the NSLog hook) + raise `NSInternalInconsistencyException` | `:31` | ✅ |
| `OOAssertFailedInFunction` | `-handleFailureInFunction:file:lineNumber:description:` reason `"<file>:<line>  Assertion failed in <func>.  <msg>"` | `:42` | ⚠️ |

**Differences:**
- ⚠️ **low** — Only the C-function form remains. Upstream's *method* asserts (`NSAssert`, `NSParameterAssert` in methods) read `"<file>:<line>  Assertion failed in <Class>(instance), method <sel>.  <msg>"`. The port prints `__PRETTY_FUNCTION__` (e.g. `void ShipEntity::foo()`) in the function form. This affects debug builds only. `OOAssert.h:31-33` documents the removal of the method forms (bead oo-dbz) — upstream gnustep-base `NSAssertionHandler` ↔ port `oofnd/objc/OOAssert.cpp:50-51`
- ✅ subtle — The NSLog date/process prefix is not reproduced (documented in `OOAssert.h:16-18`). Because the raised exception is now `oo::Exception`, the catch-site issue in [exception](#exception) applies to it as well.

**Status:** done — 3 rows: 2 ✅ 1 ⚠️ 0 ❌ 0 ➖

## Legacy script dispatch-table completeness
<a id="legacy-dispatch"></a>

**Method:** I parsed `Resources/Config/whitelist.plist` and `shader-uniform-bindings.plist` with a script; both are
byte-identical to upstream. I extracted the rows of `kOOEntityByNameRows` (`Core/Entities/OOEntityCalledByNameTable.h:2048`,
968 rows), `kOOEntityFacadeRows` (`Core/Entities/OOEntityCalledByName.cpp:637`) and `kEntityShaderBindings`
(`Core/Entities/EntityShaderBindings.cpp:150`, 86 rows). For every name I checked four things: (a) a row exists; (b) the row's
applies-to predicate matches the upstream classes that implement the selector, found by scanning the upstream `@implementation` blocks and
the `STATION_STUB_*` macros; (c) the argument kind matches the colon in the name; (d) the result kind is one the dispatcher can use.

Upstream applies aliases *before* the whitelist test: `AI.m:844-861` and `OOLegacyScriptWhitelist.m:417-421,465-469`. So the
names a dispatcher can actually receive are exactly the whitelisted ones.

### Actions and conditions (`PlayerEntityLegacyScriptEngine`, `AI`, string expander)

| List | Names | Tabled | Missing |
|---|---|---|---|
| `action_methods` | 59 | 59 | — |
| `ai_methods` | 157 | 156 | `clearDefenseTargets` (unreachable, see below) |
| `ai_and_action_methods` | 10 | 10 | — |
| `query_methods` | 39 | 39 (all `kOOByNamePlayer`, result `oo::PList`) | — |
| `action_method_aliases` targets | 2 | 2 (`doNothing`) | — |
| `query_method_aliases` targets | 3 | 3 | — |
| `ai_method_aliases` targets | 16 | 16 | — |

- **No reachable gap.** `clearDefenseTargets` is listed in `ai_methods`, but `ai_method_aliases` rewrites it to
  `removeAllDefenseTargets` (tabled) before the whitelist test. Upstream has no such ObjC method either; it exists only as a
  JS method (`OOJSShip.m:490`). `launchTrader` (also aliased away) is tabled anyway.
- **Applies-to sets match upstream** for every whitelisted entry (265 list entries, 264 tabled). The twelve station-only AI methods (`increaseAlertLevel`, `launchPolice`, …
  `abortAllDockings`) are flagged `kOOByNameShip`, and their bodies call the station's or dock's method, or the ship's stub. This matches
  upstream's `ShipEntity (OOAIStationStubs)` (`ShipEntityAI.m:2533-2556`), which made every ship respond and log
  `ai.invalid.notAStation`.
- **Signatures:** every tabled entry has the argument kind its colon implies. The 225 action/AI entries break down as 88 String, 0 PList and 137 None; their result kinds are void (214), `@` (8),
  `oo::PList` (2) and BOOL (1), all of which `CallRow` accepts. All query rows return `oo::PList`, so condition values are not silently dropped.
- **Behavioural caveat:** an AI action that is whitelisted but written with a stray argument is not called in the port
  (see [ooentitycalledbyname](#ooentitycalledbyname), ❌ low).
- `hud_dial_methods` (37 names) are HUD selectors, not entity ones. All are present in the `HeadUpDisplay.cpp:139…` table.

### Shader bindings (`EntityShaderBindings.cpp`)

Names checked: the union of `shader-uniform-bindings.plist` (`entity`/`ship`/`player`) and the four `shader_*_binding_methods`
lists (86 distinct names, plus `$inherit`).

| Missing name | Lists | Upstream | Effect |
|---|---|---|---|
| `laserColor` | `shader_ship_binding_methods`; `ship` = `"color"` | `-(OOColor*)laserColor` `ShipEntity.m:10148` (an `id` return, which is a supported uniform type via `idMethod`, `OOShaderUniformMethodType.m:96`) | A shader binding `laserColor` binds in upstream and fails in the port (no row) — **known** |

- **No other gaps.** All 85 remaining names have a row. No row exists that is absent from both lists.
- **Predicates match** the upstream implementing classes: planet-only for the five `air*`/`illumination`/`terminator` names,
  player/proxy for the `shader_player_ship` names, beacon classes for `isBeacon`/`isJammingScanning`, effect-or-ship for
  `hullHeatLevel`/`forwardVector`/`upVector`/`rightVector`, and player-only for `viewpointOffset`. The six `shaderFloat/Int/Vector`
  rows answer for every entity, but `OOUniformBindingPermitted` (`Core/Entities/ShipEntity.cpp:13734`) still restricts them to effects, as
  upstream did.
- **Encodings** match the upstream return types (e.g. `position` HPVector, `damage` int, `escortCount` uint8_t, `fogUniform` OOColor*).
- **Log text (out of file scope):** `ShaderClassName` (`EntityShaderBindings.cpp:388`) answers `"Entity"`. As a result,
  `shader.uniform.unpermittedMethod` / `shader.uniform.bind.failed` print `-[Entity laserColor]` where upstream printed
  `-[ShipEntity laserColor]` (`OOShaderMaterial.m:328`, `OOShaderUniform.m:356`).

**Status:** done — legacy actions/conditions: 0 reachable gaps (1 unreachable whitelisted name); shader bindings: 1 gap (`laserColor`, known), 0 others.
