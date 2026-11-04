# Test changes: from the `ooscript` façade to upstream's QuickJS-ng API (FR-015)

The ledger Jon's sign-off requires (spec FR-015): every unit test changed, replaced or removed when the
tests moved off the deleted façade (task T043). A changed test keeps what it asserts. An expectation changes
only where #768's design changes the behaviour; those changes are listed in plan.md Notes, "Behaviour changes
that follow #768, for Jon to confirm". The five groups' branches were merged into
`feature/upstream-quickjs-binding` (`86e33d549`..`c977f6058`); the commit ids below are on those branches.

## Test-change ledger: group t1 (T043)

Branch `feature/upstream-quickjs-binding-t1`, commits 3692ad6d1, dac5edcac, 7b2cd9924. All six
files are in `tests/unit/core/`; each test's line in `tests/unit/core/meson.build` gains
`Core/Scripting/OOJSClasses.cpp` (class registration now goes through the real registry).

Common to every row: the test now creates a QuickJS-ng runtime and context directly
(`JS_NewRuntime`/`JS_NewContext`, `gOOJSMainThreadContext` set), evaluates with `JS_Eval`, builds
and reads values with `JS_*` calls, registers its stand-in Entity/Ship classes with
`OOJSRegisterClass`/`OOJSInitClass`, and its engine stand-ins take #768's signatures
(`JSContext*`, `JSValueConst`, `int magic`, `JSCFunctionListEntry*`, owned `JSValue` returns).
The stand-ins `OOJSRegisterSubclass`/`OOJSIsSubclass` are replaced by OOJSClasses.cpp's real
ones; `cxx_OOJSIDFromString`, `OOJSNativeFailure` (as the engine's), `OOJSReportPendingException`
(drops it) and, where the binding needs it, `OOJSValueToInt32` (as the engine's) are added. The
façade-only assertion `OO_CHECK(ooscript::isInRequest(sContext))` (QuickJS has no requests) is
removed from every file.

| path | what changed | why | assertions changed? (none, or which and why) |
|---|---|---|---|
| tests/unit/core/test_OOJSFlasher.cpp | Engine driven through QuickJS-ng; `getJSClass(ClassDef**, Object*)` stand-ins become `jsClassID()`; registration check reads `OOJSClassName()`/`JS_GetClassProto()` | The ooscript façade is deleted (T041); #768's class API | Removed `isInRequest` (façade requests). Registration checks restated on the new API: class named "Flasher", prototype is an object, subclass of Entity (same meaning). |
| tests/unit/core/test_OOJSPlanet.cpp | As Flasher; vector/quaternion stand-ins take `JSValue*` | As above | Removed `isInRequest`. `otherObjects`: `...get.call(plainEntity)` expected "got [object Entity]." now "got [object Object]."; `Object.create(Planet.prototype).radius` expected "got [object Planet]." now "got [object Object]." The façade backend tagged every class prototype with `Symbol.toStringTag` (`tagWithClassName` in the deleted JSEngine_quickjs.cpp); #768 does not, so QuickJS describes the object as "[object Object]". The refusal ("Native method expected Planet") is unchanged. |
| tests/unit/core/test_OOJSEquipmentInfo.cpp | As Flasher; `categoryAnswersTheEngine` compares owned `JSValue`s by object pointer and reads the slot with `JS_GetAnyOpaque`, freeing what it holds; `cFunctions` builds its keys with `JS_NewString`; the counting finalizer stand-in also releases the slot (OOJSCxxObjectWrapperFinalize) | As above | Removed `isInRequest`. Others restated on the new API with the same meaning (same object, slot holds the type, cleared self gives a new object). |
| tests/unit/core/test_OOJSVisualEffect.cpp | As Flasher; `OOScript::callMethod`/glue stand-ins take #768's signatures | As above | Removed `isInRequest`. `methods`: `typeof effect.scale(2)` expected "function" now "undefined": #768's `VisualEffectScale` returns `JS_UNDEFINED` (SpiderMonkey left the callee in the result slot, which the façade reproduced). |
| tests/unit/core/test_OOJSMission.cpp | As Flasher; stand-ins for `OOJavaScriptEngine::callJSFunction` (now `JS_Call`, exception reported and cleared as the engine's), `GuiDisplayGen::textureDescriptorFromJSValue` (caller description now `const std::string&`), `OOJSValueFromCxxObject`, `OOJSInternAtomPRIVATE`, `kOOJavaScriptEngineWillResetNotificationName`; demo-ship and script objects held as owned `JSValue`s instead of named roots | As above | Removed `isInRequest`. No other change. |
| tests/unit/core/test_OOJSStation.cpp | As Flasher, with a stand-in Ship class (`JSShipClassID()`); `Entity::jsClassID()` answers 0 for "no class of its own" and the object keeps the Ship class (the old `getJSClass` left its out-parameters alone); interface-callback checks compare owned `JSValue`s and free them | As above | Removed `isInRequest`. `callback()`/`callbackThis() == nullptr` restated as "callback is an object, callbackThis is not". `otherObjects`: `Station.prototype.launchMiner.call({})` expected "undefined" now "threw: Native method expected Entity, got [object Object].": #768's `GET_THIS_STATION` returns `JS_EXCEPTION` when an error is pending (a QuickJS native must not return normally with one). `Station.prototype.roll` expected "threw: Native method expected Entity, got [object Object]." now "<evaluation failed>": #768's `OOJSInitClass` makes the prototype an instance of its class with no entity (as SpiderMonkey's `JS_InitClass`), so the getter is refused without a JS error, as the Flasher test already expects for `Flasher.prototype.size`. |

## Test-change ledger, group t2 (T043)

Branch `feature/upstream-quickjs-binding-t2`, worktree `.agent-tmp/upstream-binding-t2`.

Changes common to the six binding tests (Sun, ExhaustPlume, Waypoint, SystemInfo, Entity, Global):
- The test makes a QuickJS-ng runtime and context (`JS_NewRuntime`/`JS_NewContext`) and sets `gOOJSMainThreadContext`. It evaluates with `JS_Eval`, and it frees the owned values it makes.
- The tests link `OOJSClasses.cpp` (their lines in `tests/unit/core/meson.build`) for the real `OOJSRegisterClass`/`OOJSInitClass`/`OOJSIsSubclass`. They no longer stub a subclass map.
- The stubs of `OOJavaScriptEngine.cpp`'s functions take the new signatures with the same messages. `OOJSNativeFailure` is a copy of the engine's.
- The stand-in entities answer `jsClassID()` in place of `getJSClass(ClassDef**, Object*)`.
- `OO_CHECK(ooscript::isInRequest(sContext))` is removed from each `nativeExceptions` test. Requests were the façade's own and have no counterpart in #768.

| path | what changed | why | assertions changed? (none, or which and why) |
|---|---|---|---|
| tests/unit/core/test_OOJSSun.cpp | Common changes. The stand-in Entity class gets the game's `toString()` (`OOJSCxxObjectWrapperToString`, as `OOJSEntity.cpp`). `registration` reads the class name with `OOJSClassName(id)` and the prototype with `JS_GetClassProto`. | Façade removed (FR-015) | The `isInRequest` check is removed. Otherwise none: "got [object Entity]" came from the façade's `Symbol.toStringTag`, and is kept by giving the stand-in Entity the game's toString. |
| tests/unit/core/test_OOJSExhaustPlume.cpp | Common changes, the same toString stand-in, and the vector stubs on QuickJS arrays. | Façade removed | The `isInRequest` check is removed. Otherwise none. |
| tests/unit/core/test_OOJSWaypoint.cpp | Common changes, the same toString stand-in, and the quaternion stubs on QuickJS arrays. | Façade removed | The `isInRequest` check is removed. Otherwise none. |
| tests/unit/core/test_OOJSSystemInfo.cpp | Common changes. Adds stubs for `OOJSValueToInt32` (a copy of the engine's), `OOJSInternAtomPRIVATE` (a link stub) and the reset notification name. `wrappedObject` reads the slot with `JS_GetAnyOpaque`. The universe stand-in now also writes `setSystemDataForGalaxy` into its system manager, and setup puts economy/government there too. #768's binding reads values back from the system manager and no longer keeps an own slot per assignment, so the stand-in now stores them where the game's universe does. | Façade removed; #768's SystemInfo exotic methods (plan Notes: class hooks become #768's `JSClassExoticMethods`) | `isInRequest` removed. Four expectations change to #768's SystemInfo design. #768 declares the fixed properties `OOJS_PROP_HIDDEN_READONLY_CB` ("not listed by any enumeration"): `Object.keys(SystemInfo.prototype)` becomes `""`, `Object.keys(info(0,7))` becomes `economy,government,name`, `Object.keys(info(0,-1))` becomes `economy,name`, and the fresh-snapshot keys drop the 4 fixed names (`.length` 44 → 40). The `for (var p in lave)` expectation likewise becomes `economy,government,name` (fixed properties hidden), once the game's has_property hook (feature branch `73a7aa796`) made for..in list system data keys at all; checks added for `hasOwnProperty` (false) and `in` (true for data keys and methods, false for unknown). |
| tests/unit/core/test_OOJSEntity.cpp | Common changes. The stand-in slot glue (`OOJSGetCxxPrivateImpl`, `OOJSSetCxxPrivate`, the finalizer and toString) and `OOJSValueFromCxxObject` take the new signatures. Entity objects are held as owned JSValues in place of named roots. `EntityFromArgumentList`'s argc and consumed count are `int`, as declared. | Façade removed | The `isInRequest` check is removed. `consumed == 0u/1u` becomes `0/1` (type only). Otherwise none. |
| tests/unit/core/test_OOJSGlobal.cpp | Common changes. The context's own global object gets `global` as the engine defines it (`CreateOOJSGlobal` is gone). The GUI and engine stand-ins take the new signatures. An `OOScheduleDeferredCall` stub records calls. Callback checks read the owned `callback()`/`callbackThis()`. | Façade removed; #768 changes | The `isInRequest` check is removed. Seven `setExtraGuiScreenKeys` bad-argument counts go from `(2)` to the count given: `(0)` for `('k')`, `(1)` for the other six. #768's `OOJSGlobal.m` passes `defArgc = MIN(argc - 1, 2)`. `pauseAndQuit` gets an added `_quit == 0` check, then runs the deferred call before the kept `_quit == 1` check, because #768 defers `quitGame()` until the script returns. `callbackThis() == nullptr` becomes "is not an object", and `== sGlobal` becomes object identity: the same meaning. |
| tests/unit/core/test_OOJavaScriptEngine.cpp | Uses the engine API throughout: `Owned` RAII for owned values, `JS_Eval`, `OOJSReportPendingException`, `JS_HasException`, the new monitor signature, a class registered with `OOJSRegisterClass` for the wrapper test, and `JS_GetAnyOpaque`. | Façade removed; T042 removed `objectClass()` etc. and `removeGC*Root` | `standardClasses`: `engine->xClass() != NULL` and `OOJSGetClass(...) == engine->xClass()` become `gOOJSxClassID != 0` and `JS_GetClassID(...) == gOOJSxClassID`, the same checks on #768's class IDs. `reset` changes in the same way. `gcRoots`: the two `addNamed*Root` checks are removed (façade rooting), and the test now holds owned references. `jsValueHolder`: the `valueWithJSObject` block (one check) is removed, because #768 has no separate JSObject holder. `stackDump`: the frame-format checks become #768's `OOJSDumpStack` text (`at dumpTarget (dumpstack.js:3:`, `at <eval> (dumpstack.js:6:`). The ` 0 (dumpstack.js:3)` frame-number check is removed (the façade's numbering). Under the stack skip, the line-3 frame is now expected present (1, was 0), because #768's skip is the error handler's only, and its dump ignores it. |
| tests/unit/test_jsengine_quickjs.cpp | Removed. | It tested the façade itself (Context/ClassDef, resolve/enumerate hooks, roots, the arena) and no meson file built it. #768's binding has no counterpart. The one game regression in it (delete reaching a class hook with no own slot) is `test_OOJSMissionVariables` `deletingAVariableTheScriptNeverSet` (another group). | All, with the file (FR-015: a façade test with no counterpart). |
| tests/unit/expander/OOJavaScriptEngine.h | The stub declares `struct JSContext;` and takes `JSContext*` in place of `ooscript::Context`. | Façade removed | None (stub). |
| tests/unit/expander/test_string_expander.cpp | The three engine stubs take `JSContext*`. | Façade removed | None. |
| tests/unit/core/meson.build | `Core/Scripting/OOJSClasses.cpp` is added to the source lists of test_OOJSSun, ExhaustPlume, Waypoint, SystemInfo and Entity. | The tests now use the engine's real class registration | None. |

## Test-change ledger, group t3 (T043)

Branch `feature/upstream-quickjs-binding-t3`, worktree `.agent-tmp/upstream-binding-t3`. All paths are
under `tests/unit/core/`. Every file below also had its `meson.build` line extended: each now links
`Core/Scripting/OOJSClasses.cpp` (the engine's class registry, which replaces the façade's class
setup), and Quaternion and Console also link `Core/Scripting/OOJSPrivateObject.cpp`.

Common to every row ("driving changes" below): the façade runtime/context/request calls became
`JS_NewRuntime`/`JS_NewContext`; `evaluateScript` became `JS_Eval`; values are `JSValue` with explicit
`JS_FreeValue`; classes are `JSClassDef` + `OOJSRegisterClass`/`OOJSInitClass` and are compared by
`JSClassID` and `OOJSClassName()` instead of `ClassDef*`/`->name`; engine stubs take the new
signatures (`int argc`, `JSValueConst`, getter/setter `magic` tables, `OOJSNativeFailure`,
`cxx_OOJSIDFromString`, `OOJSReportPendingException`, `gOOJSMainThreadContext` as `JSContext*`); the
façade's `gc()` became `JS_RunGC()`.

| path | what changed | why | assertions changed? (none, or which and why) |
|---|---|---|---|
| `test_OOJSPrivateObject.cpp` | Driving changes. The test's Thing keeps a weak `JSValue` self (as `OOShipGroup` does); the finalize case frees its own reference before collecting, because QuickJS finalizes on the last reference. | The façade (and its arena) is gone; the glue now takes `JSClassID` and `JSValueConst`. | Removed `OO_CHECK(ooscript::isInRequest(sContext))` (façade requests have no counterpart). Pointer-identity checks now compare `JS_VALUE_GET_PTR`; same meaning. |
| `test_OOJSDock.cpp` | Driving changes. Entity stand-ins answer `jsClassID()` (the game's replacement for `getJSClass()`); the registration case reads the class by ID (`OOJSClassName`, `JS_GetClassProto`). | `getJSClass()` and `ClassDef*` are gone (T042 replaced them with `jsClassID()`, as in #768). | Removed the `isInRequest` check. Registration checks restated on the class ID (same facts: name "Dock", a prototype, subclass of Ship, one converter). |
| `test_OOJSWormhole.cpp` | As Dock. | As Dock. | Removed the `isInRequest` check. Changed: the strict-mode write to read-only `wormhole.origin` now expects a TypeError (`"true"`), was `"no throw"`. #768 defines read-only properties without a setter (`OOJS_PROPERTY_RO`), and dropped Wormhole's setter, so strict code throws. |
| `test_OOJSShipGroup.cpp` | Driving changes. The ship stand-in's JS object is held (one owned reference) by its object; `OOJSEntityFromJSValue` reads the fake Ship class's slot; the fake Ship class gets the game Ship class's `toString` (`OOJSCxxObjectWrapperToString`), because the façade tagged every class with `Symbol.toStringTag` and QuickJS-ng/#768 does not. | The façade is gone; without a tag or a toString, `String(ship)` would be `[object Object]`. | Removed the `isInRequest` check. Category case: `clearJSSelf(nullptr)` became `clearJSSelf(JS_NULL)`; identity compared by `JS_VALUE_GET_PTR`. No expected value changed. |
| `test_OOJSSoundSource.cpp` | Driving changes; the glue stand-ins (`OOJSSetCxxPrivate`, `OOJSGetCxxPrivateImpl`, the no-op finalizer, `toString` "[SoundSource]") take the new signatures; `OOJSValueToInt32` stood in as the engine's. | The façade is gone. | Removed the `isInRequest` check. None other. |
| `test_OOJSQuaternion.cpp` | Driving changes. The binding now reads an entity's orientation from the C++ entity its holder names (`Entity::getOrientation()`), so the stand-in is an `Entity` (with a `Universe` for Vector3D) instead of the `OOJSEntityOrientationOfJSObject` hook; the test no longer includes the real `OOJSEntity.h`/`Universe.h`/`OOJavaScriptEngine.h`. `nativeInterface` uses `JSValue`s and `int consumed`. | The binding's entity path changed with the port; the façade is gone. | Removed the `isInRequest` check. `!JSObjectGetQuaternion(ctx, nullptr, &q)` became `JS_NULL` (the non-object case). No expected value changed. |
| `test_OOJSTimer.cpp` | Driving changes; `OOJavaScriptEngine::callJSFunction` stand-in takes the new signature and calls `JS_Call`. | The façade is gone. | Changed two, both #768's Timer: (1) the strict-mode write to read-only `isRunning` now expects `"threw: no setter for property"`, was `"false"` ("ignored even in strict code") — #768 defines `isRunning` with `OOJS_PROPERTY_RO`; (2) `nameReads` after the GC now expects `"1"`, was `"0"` — #768's constructor reads the function's `name` once and caches it (`_functionName`), so the one read is the constructor's; the check that the finalizer adds none is kept. |
| `test_OOJSPlayer.cpp` | Driving changes. Script event names are atoms: the stand-in `OOJSInternAtomPRIVATE` interns them and records each name, and `doScriptEvent` takes a `JSAtom`. The registration case reads the class by ID and compares the `player` global with `JSPlayerObject()` by pointer. | `ooscript::PropertyId`, `JSPlayerClass()` and `JSPlayerPrototype()` are gone. | Removed the `isInRequest` check. Registration checks restated on the class ID (same facts). No expected value changed. |
| `test_OOJSConsole.cpp` | Driving changes; the monitor's `jsEngine()` overloads and glue take the new signatures; the time limiter (now in `OOJavaScriptEngine.cpp`, not linked) is stood in for. | The façade is gone. | Changed: (1) the two internal-error texts name the native by `__PRETTY_FUNCTION__`, now `JSValue ConsoleConsoleMessage(JSContext *, JSValue, int, JSValue *)` (and `ConsoleClearConsole`), was `bool …(ooscript::Context, ooscript::CallArgs &)` — the native's signature is the engine API's; the GCC branch's text is my best rendering of GCC's format and is unverified (only Clang was built). (2) `isExecutableJavaScript(this, '1 +')` now expects `"false"`, was `"true"` ("the backend's answer") — #768's `IsIncompleteSyntaxError()` treats incomplete input as not executable, as SpiderMonkey's `JS_BufferIsCompilableUnit()` did. |

## Test-change ledger, group t4 (task T043)

Branch `feature/upstream-quickjs-binding-t4`, worktree `.agent-tmp/upstream-binding-t4`. Commits
`680bf1395`, `5f8149d75`, `39c61fbd6`, `ffbf3c0f2`, `69c941fd4`, `39f4b30ec`. All files are in
`tests/unit/core/`.

In every file, the same mechanical changes apply:

- The context is a QuickJS-ng runtime and context (`JS_NewRuntime`, `JS_NewContext`), and
  `gOOJSMainThreadContext` is set to it.
- Script runs through `JS_Eval`.
- Values are `JSValue`/`JSValueConst`, and the test frees what it owns.
- The stand-ins take the engine's new signatures (`JSContext*`, `int argc`, owned results,
  `magic` and property tables instead of `PropertyId`/`PropertySpec`, `JSClassID` instead of
  `ClassDef*`).
- Binding tests now link the game's own `OOJSClasses.cpp`, because bindings register classes
  through it. It replaces the stand-in `OOJSIsSubclass`.

| path | what changed | why | assertions changed? (none, or which and why) |
|---|---|---|---|
| `test_OOJSFunction.cpp` | Context, evaluation and values moved to QuickJS-ng. The stand-ins are `cxx_OOStringFromJSValue`, `OOJSReportPendingException`, and the time limiter without the `_` debug variants. `NULL` scope/this became `JS_UNDEFINED`; a null function became `JS_NULL`. Function identity is compared by object pointer. | The façade is gone; `OOJSFunction` now takes and returns `JSValue`s. | Removed `OO_CHECK(ooscript::isInRequest(Context()))` in `initWithName`. It checked the façade's request state, and QuickJS has no requests. `OOJSFunction::function()`, `functionValue()` and the null checks are expressed with `JSValue` (same meaning). |
| `test_OOJSGuiScreenKeyDefinition.cpp` | Context, evaluation and values moved to QuickJS-ng. The stand-in `callJSFunction` uses `JS_Call` with the engine's new signature, and `OOScript`'s virtuals take the new signatures. Evaluated values are freed at the end of the statement, so the definition holds the only reference, as the test intends. GC is `JS_RunGC`. | The façade is gone; the definition now holds owned `JSValue`s, and `callback()`/`callbackThis()` return owned values. | None removed. `callbackThis() == NULL` / `!= NULL` is now "is not / is an object" (`callbackThis` starts as `JS_UNDEFINED`, the new representation of "no `this`"). `setCallbackThis(NULL)` became `setCallbackThis(JS_UNDEFINED)`. |
| `test_OOJSInterfaceDefinition.cpp` | As for the GuiScreenKeyDefinition test. | As above. | None removed. Same `callbackThis` representation change as above. |
| `test_OOJSPopulatorDefinition.cpp` | As for the GuiScreenKeyDefinition test. The `VectorToJSValue` stand-in builds an `[x, y, z]` array with QuickJS-ng. | As above. | None removed. Same `callbackThis` representation change as above. |
| `test_OOJSVector.cpp` | The stand-ins were moved to the new signatures, and `OOJSNativeFailure`, `cxx_OOJSIDFromString`, `OOJSReportPendingException`, `Entity::getPosition` and `OOJSGetCxxPrivateImpl` were added. `getPosition` and `OOJSGetCxxPrivateImpl` are abort-only link stubs (no case makes an entity). The fake Entity class is registered with `OOJSRegisterClass`. `nativeInterface` uses `JSValue`s. The meson entry adds `Core/Scripting/OOJSClasses.cpp`. | The façade is gone; the binding registers with `OOJSClasses`. | Removed `OO_CHECK(ooscript::isInRequest(sContext))` in `nativeExceptions` (the façade's request state, as above). `JSObjectGetVector(…, nullptr, …)` now passes `JS_NULL`, the same "not an object" case. |
| `test_OOJSOolite.cpp` | The stand-ins were moved to the new signatures, with `OOJSValueToInt32` (the engine's rounding and error), `OOJSNativeFailure`, `cxx_OOJSIDFromString` and `OOJSReportPendingException` added. The meson entry adds `OOJSClasses.cpp`. | As above. | Removed `OO_CHECK(ooscript::isInRequest(sContext))` in `nativeExceptions` (the façade's request state). |
| `test_OOJSManifest.cpp` | The stand-ins were moved to the new signatures, with `OOJSValueToInt32`, `OOJSClassNameOfValue`, `cxx_OOJSDescribeValue`, `OOJSBasicPrivateObjectConverter`, `OOJSInternAtomPRIVATE` (abort-only link stub) and `JSPlayerShipObject` (now returns an owned value) added. The meson entry adds `OOJSClasses.cpp`. | As above; Manifest is now #768's exotic-method class. | Removed `OO_CHECK(ooscript::isInRequest(sContext))` in `nativeExceptions` (the façade's request state). **Behaviour change from #768, Jon to confirm** (plan.md Notes, Manifest bullet): in `quantities`, `manifest.food = 'x'` (was `"5"`) and `manifest.food = 9; delete manifest.food` (was `"9"`) now expect `threw: Cannot set property food of instance of Manifest to invalid value x.` / `... undefined.`, followed by new checks that `manifest.food` still reads `"5"` / `"9"`, so a bad value still never reaches the manifest. |
| `test_OOJSSound.cpp` | The stand-ins were moved to the new signatures. `OOJSObjectWrapperFinalize` forwards to the linked `OOJSCxxObjectWrapperFinalize`, as the engine's does. `OOJSObjectWrapperToString` and `OOJSNativeFailure` were added, and the stand-in `OOJSIsSubclass` was dropped (OOJSClasses'). The `JSValue`s the test makes are freed. The meson entry adds `OOJSClasses.cpp`. | As above. | `soundFromJSValue`: `OO_CHECK_EQ(sLimiterPauses, 1)` became `0`. Upstream #768 deliberately balances the pause in `SoundFromJSValue()` (its comment: "The SpiderMonkey version returned before resuming the time limiter, leaving it paused; the pause is balanced here"), and the port follows #768. Also removed `OO_CHECK(ooscript::isInRequest(sContext))` in `nativeExceptions` (the façade's request state). |
| `test_OOJSCall.cpp` | The stand-ins were moved to the new signatures: `cxx_OOJSReportError`, the string converters, and `OOJSValueFromPList`/`JSVectorWithVector`/`JSQuaternionWithQuaternion`, which return owned values. `CallEntity` frees its arguments, the marker and any result the call sets. | The façade is gone. | None. |

### `test_OOJSManifest.cpp` `quantities`: resolved

These two assertions failed at first and were left unchanged. The coordinator then confirmed that
the change is deliberate: it follows #768 and is recorded in plan.md's Notes ("Behaviour changes
that follow #768, for Jon to confirm"). The expectations are updated as the row above says
(commit after `39f4b30ec`). `test_OOJSManifest` passes.

## Test-change ledger, group t5 (T043)

Branch `feature/upstream-quickjs-binding-t5`. Every file below moved from the `ooscript` façade to
upstream #768's QuickJS-ng API (FR-015). "Context" means `ooscript::newContext(newRuntime(...))`
became `JS_NewContext(JS_NewRuntime())`; evaluation moved from `ooscript::evaluateScript` to
`JS_Eval`, with owned results freed.

| path | what changed | why | assertions changed? (none, or which and why) |
|---|---|---|---|
| tests/unit/core/test_DockEntity.cpp | context | façade removed | none |
| tests/unit/core/test_OOECMBlastEntity.cpp | context | façade removed | none |
| tests/unit/core/test_OOLaserShotEntity.cpp | context | façade removed | none |
| tests/unit/core/test_OOPlasmaShotEntity.cpp | context | façade removed | none |
| tests/unit/core/test_OOQuiriumCascadeEntity.cpp | context | façade removed | none |
| tests/unit/core/test_ProxyPlayerEntity.cpp | context | façade removed | none |
| tests/unit/core/test_ShipEntity.cpp | context | façade removed | none |
| tests/unit/core/test_ShipEntityAI.cpp | context | façade removed | none |
| tests/unit/core/test_PlayerEntity.cpp | context; `doScriptEvent` override takes `OOJSPropID` | façade removed; game signature changed | none |
| tests/unit/core/test_PlayerEntityStickProfile.cpp | context; `doScriptEvent` override takes `OOJSPropID`; façade include dropped | as above | none |
| tests/unit/core/test_GameController.cpp | recorded events are `OOJSPropID`; ids compared with `==` | `ooscript::PropertyId` gone | none |
| tests/unit/core/test_GuiDisplayGen.cpp | `textureDescriptorFromJSValue(JS_NULL, JSContext*, ...)` | game signature changed | none |
| tests/unit/core/test_OOShipGroup.cpp | JS glue stubs take `JSContext*`/`JSValueConst` and return `JSValue` | game signature changed | none |
| tests/unit/core/test_OOFlasherEntity.cpp, test_OOPlanetEntity.cpp, test_WormholeEntity.cpp, test_OOExhaustPlumeEntity.cpp, test_OOSunEntity.cpp, test_OOVisualEffectEntity.cpp, test_OOWaypointEntity.cpp | `jsExtensions`: the entity's class is `OOJSEntityJSClassID()`, compared with `JS<Class>ClassID()`, after the classes are registered by `InitOOJSEntity` and `InitOOJS<Class>` (helper `RegisterJSClasses`) | `getJSClass(&class, &prototype)` is `jsClassID()` in #768 | `jsClass != nullptr && jsClass == expectedClass && prototype == expectedPrototype` became `jsClass != 0 && jsClass == expectedClass`. The prototype comparison is removed: the façade returned a class/prototype pair; #768 identifies a class by its ID, and the prototype is per context (`JS_GetClassProto`) |
| tests/unit/core/test_StationEntity.cpp | `stationAnswersTheStationJSClass`: as the row above (Entity, Ship, Station registered); `asShip->getJSClass` became `asShip->jsClassID()` | as above | the two `prototype == stationPrototype` checks removed (as above); added `stationClass != 0 && stationClass != JSShipClassID()` |
| tests/unit/core/test_EntityOOJavaScriptExtensions.cpp | context (registered as the main context, with Entity and Ship classes); `_jsSelf` is a `JSValue` the test owns and frees; objects compared by pointer (`SameObject`); class checks by `JSClassID`; the test's scripted entity overrides `jsClassID()` with a class registered by `OOJSRegisterClass` | façade removed; `getJSClass` became `jsClassID` | `_jsSelf == nullptr` became `JS_IsUndefined(_jsSelf)` (same meaning). The `prototype == JSEntityPrototype()/JSShipPrototype()/nullptr` checks are removed (class IDs, as above); `jsClass == &sTestScriptedClass` became `jsClassID == sTestScriptedClassID` plus `!= 0` |
| tests/unit/core/test_OOCharacter.cpp | façade link stubs replaced by `JSContext* gOOJSMainThreadContext` | façade removed | none |
| tests/unit/core/test_OOCommodities.cpp | façade link stubs replaced by the engine functions the code now links (`OOJSInternAtomPRIVATE`, `OOJSValueFromPList`, `cxx_OOJSPListFromJSObject`), all still aborting | façade removed | none |
| tests/unit/core/test_OOShipRegistry.cpp | façade link stubs replaced by the engine functions the code now links (`OOJSInternAtomPRIVATE`, `OOJSValueFromPList`, `OOJSValueToBOOL`), all still aborting | façade removed | none |
| tests/unit/core/test_OOConstToString.cpp, test_OOEquipmentType.cpp | `OOScript`/`OOEquipmentType` glue stubs take the new signatures | game signatures changed | none |
| tests/unit/core/test_OODebugSupport.cpp, test_OODebugTCPConsoleClient.cpp | `OODebugMonitor` monitor and glue stubs take the new signatures | game signatures changed | none |
| tests/unit/core/test_OoliteEquipmentControlScript.cpp | QuickJS-ng runtime/context; `JS_Eval`; `JS_ToBool` | façade removed | `CHECK(initStandardClasses(...))` removed: a QuickJS-ng context has the standard classes from the start (no counterpart). Added an early return when no context could be made |
| tests/unit/core/test_OOJSPlayerShip.cpp | `doScriptEvent` override takes `OOJSPropID`; `JS_Eval`; objects compared by pointer; `JSPlayerShipObject()` (now owned) freed | façade removed | `strcmp(JSPlayerShipClass()->name, ...)` became `strcmp(OOJSClassName(JSPlayerShipClassID()), ...)`; `JSPlayerShipPrototype() != nullptr` became `JS_IsObject(JS_GetClassProto(context, JSPlayerShipClassID()))` (same facts). `_jsSelf == nullptr` became `JS_IsUndefined(_jsSelf)` |
| tests/unit/core/test_OOJSSystem.cpp | `JS_Eval` | façade removed | **`filteredEntities` with a throwing predicate: expected `"threw: nope"` is now `"<evaluation failed>"`.** #768 reports the predicate's exception and stops the script with `OOJSNativeFailure()` (its comment: "The predicate's exception has been reported (as before); stop the script."), so the script's own `catch` no longer sees it. This is #768's design (and SpiderMonkey Oolite's), not a port error; Jon to confirm |
| tests/unit/core/test_OOJSShip.cpp | `JS_Eval`; globals set with `JS_SetPropertyStr` | façade removed | `JSShipClass()->name`/`JSShipPrototype()` became `OOJSClassName(JSShipClassID())`/`JS_GetClassProto` (same facts) |
| tests/unit/core/test_OOJSScript.cpp | `callMethod` with `JSValue` arguments; owned values freed | façade removed | none removed. The GC root around the held Script value (`OOJSAddGCValueRoot`/`removeValueRoot`) is replaced by owning the value: rooting has no counterpart |
| tests/unit/core/test_OORegExpMatcher.cpp | stand-ins for the engine, `OOJSFunction` and `OOJSValue` written on QuickJS-ng (the function compiled as a function expression, as `OOJSFunction.cpp` does); `OOJSReportPendingException` stand-in added; the unused converter stand-in removed | façade removed | none |
| tests/unit/core/test_OOJSClock.cpp | context; engine stand-ins take the new signatures; links `OOJSClasses.cpp` (meson line) | façade removed; the binding registers its class through `OOJSClasses.cpp` | `OO_CHECK(ooscript::isInRequest(sContext))` removed: QuickJS has no requests |
| tests/unit/core/test_OOJSFrameCallbacks.cpp | context; stand-ins take the new signatures; the limiter stand-ins are the non-debug functions (the `_` debug variants are gone, as in #768); `OOJSReportPendingException` stand-in added | façade removed | `OO_CHECK(ooscript::isInRequest(...))` removed: QuickJS has no requests |
| tests/unit/core/test_OOJSMissionVariables.cpp | context; stand-ins take the new signatures; links `OOJSClasses.cpp` (meson line) | façade removed | `OO_CHECK(ooscript::isInRequest(sContext))` removed: no requests. `String(missionVariables)` expects `[object Object]`, not `[object MissionVariables]`: #768 tags no class prototype (plan Notes, Class tags, for Jon to confirm). |
| tests/unit/core/test_OODebugMonitor.cpp | context; stand-ins take the new signatures; the engine monitor is called with severity, file and line | façade removed; the monitor API changed (T038) | `engineErrorsAndLogLinesReachTheConsole`: the strict-mode exception's expected output `"exception\|Exception (strict mode): boom\|0,24"` is now `"exception\|Exception: boom\|0,10"`, and the case for a non-exception error (`"error\|Error: bad\|0,6"`) is removed: QuickJS has no strict-mode reports and no errors that are not exceptions, so the monitor API (severity `"warning"`/`"exception"`) cannot state them (#768). The log line's index moved from 4 to 3. `javaScriptValueAndEngineReset`: `sConsoleDestroys == 1` removed: #768 removes `OOJSConsoleDestroy()` (plan Notes, T042); the reset's effect is still checked by the wrapper being made again |
| tests/unit/core/test_OOJSEngineTimeManagement.cpp | now the profiler's test only, linking the file and the stopwatch, with limiter and converter stand-ins; includes the game's header | the limiter moved to `OOJavaScriptEngine.cpp` (#768), which needs the whole game | none: the `limiter`, `pauseAndResume` and `watchdog` cases moved to `test_OOJSTimeLimiter.cpp` |
| tests/unit/core/test_OOJSEngineTimeManagement.hpp | removed | it declared the profile classes because the game header could not be included beside the test's engine stand-ins; the test now includes the game's header | n/a |
| tests/unit/core/test_OOJSTimeLimiter.cpp (new) | `limiter`, `pauseAndResume` and `watchdog` from test_OOJSEngineTimeManagement, on the real engine (whole game, meson line added) | the limiter is the engine's now | the watchdog now runs a real `OOJSScript` named "test script" pushed as the running script (the stand-in answered that name), and counts `OOJSDumpStack()`'s log entry (the stack's `    at` frames) instead of a stand-in's calls; the stack-dump check is under `OO_DEBUG_MONITOR_ENABLED`, the condition the engine dumps under (was `!NDEBUG`) |
| tests/unit/core/meson.build | `test_OOJSClock`, `test_OOJSMissionVariables`: + `Core/Scripting/OOJSClasses.cpp`; new `test_OOJSTimeLimiter: ['*']` | as above | n/a |

## End target (T051b)

Upstream #742 on `feature/upstream-quickjs-poc-cxx`, commit `4f1896f10` (Jon, 2026-11-03: the
decode cases may move to OOSDLJoystickManager with SDL events; what each asserts is kept). The SDL
event decoders moved from `OOJoystickManager` to `OOSDLJoystickManager`, which takes SDL's own
`SDL_JoyAxisEvent`/`SDL_JoyButtonEvent`/`SDL_JoyHatEvent`; the core header lost `JoyAxisEvent`,
`JoyButtonEvent`, `JoyHatEvent` and the `JOY*` constants. No `OO_CHECK` line changed in any row.
Common to the `test_OOJoystickManager.cpp` rows: the file includes `OOSDLJoystickManager.h`; its
`Axis`/`Button`/`Hat` helpers build SDL's event types with `SDL_EVENT_JOYSTICK_*` (the stick index
in `which`, as `makeJoy*Event()` pass it on); a new `DecodingStickManager` (an
`OOSDLJoystickManager` answering for the hardware as the base does: no sticks, "Dummy joystick",
axes at 0) and `NewDecodingManager()` stand where the case decodes; `tests/unit/core/meson.build`
links `SDL/OOSDLJoystickManager.cpp` into `test_OOJoystickManager`.

| path | what changed | why |
|---|---|---|
| `tests/unit/core/test_OOJoystickManager.cpp` (`decodesAxes`) | The manager is a `DecodingStickManager`; events are `SDL_JoyAxisEvent`/`SDL_JoyButtonEvent`. | #742: the decoders are `OOSDLJoystickManager`'s and take SDL's events. |
| `tests/unit/core/test_OOJoystickManager.cpp` (`decodesButtonsAndHats`) | As `decodesAxes`; the hat values are `SDL_HAT_DOWN \| SDL_HAT_RIGHT` and `SDL_HAT_RIGHT` (were `JOYHAT_*`, equal to them). | #742: the `JOYHAT_*` constants left the core header. |
| `tests/unit/core/test_OOJoystickManager.cpp` (`callsBackForTheNextStickControl`) | As `decodesAxes`. | #742. |
| `tests/unit/core/test_OOJoystickManager.cpp` (`savesAndLoadsSettings`) | The reloaded manager (`loaded`), the one that decodes a press, is a `DecodingStickManager`; the others stay base managers. | #742. |
| `tests/unit/core/test_OOJoystickManager.cpp` (`subclassOverrides`, `sharedHandlerOfTheRegisteredClass`) | `TestStickManager` derives from `OOSDLJoystickManager` (was `OOJoystickManager`), so the press it decodes goes through the SDL manager's decoder; its overrides and the base's other members are unchanged. | #742: only the SDL manager decodes. |
| `tests/unit/core/test_OOJoystickManager.cpp` (`decodesGuiButtons`) | As `decodesAxes`; hat values `SDL_HAT_UP`, `SDL_HAT_CENTERED`. | #742, with #783's GUI-button decoding now in `OOSDLJoystickManager::decodeButtonEvent`. |
| `tests/unit/core/test_OOJoystickManager.cpp` (`savesAndLoadsGuiButtons`) | The reloaded manager that decodes a press is a `DecodingStickManager`. | #742. |
| `tests/unit/core/test_OOSDLJoystickManager.cpp` (`makesEvents`) | The event makers' results are held as `SDL_JoyAxisEvent`/`SDL_JoyButtonEvent`/`SDL_JoyHatEvent` (were the core header's `Joy*Event` typedefs of the same types). | #742: `makeJoy*Event()` answer SDL's types and the typedefs are gone. |

## Step 007

Step 007 (`seriesb/007-foundation-wave-2`, T053) replayed on #768's binding. One test file set uses the
façade in the old step; it is not registered in meson (the old step's PR says so), so no suite runs it.

| path | what changed | why |
|---|---|---|
| `tests/unit/expander/OOJavaScriptEngine.h`, `tests/unit/expander/test_string_expander.mm` (the three engine stubs) | The stubs of `OOJSAcquireContext`, `OOJSRelinquishContext` and `OOJSReportWarningWithArguments` take and return `JSContext*` (an incomplete `typedef struct JSContext JSContext`), where they used a stand-in `ooscript::Context` struct; `OOJSAcquireContext` returns `nullptr`. The digests and every check are unchanged. | The façade is gone; `OOStringExpander.mm` calls these functions with #768's `JSContext*`. |
