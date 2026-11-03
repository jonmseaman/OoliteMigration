# Façade map: `ooscript` → upstream #768's QuickJS-ng binding

A dictionary for porting the game's C++ JavaScript bindings off the fork's engine façade
(`src/Core/Scripting/ooscript/JSEngine.hpp`, namespace `ooscript`, one backend
`JSEngine_quickjs.cpp`) onto the binding style of upstream PR #768, which calls QuickJS-ng
directly from Objective-C.

Sources: the façade at `feature/upstream-quickjs-binding` 3aa8d65e8 (worktree
`.agent-tmp/upstream-binding-wt`); #768 at `seriesb/000b-upstream-768-quickjs-only` db4920103 in
`oolite-dev`. In the tables, `Lnnnn` is a line of `JSEngine_quickjs.cpp`; #768 paths are relative to
`src/Core/`, with `E.h` = `Scripting/OOJavaScriptEngine.h` and `E.m` =
`Scripting/OOJavaScriptEngine.m`. "none: …" means #768 has no counterpart, and says why.
`.agent-tmp/facade_map_check.py` checks that every public name in `JSEngine.hpp` has a row.

## #768's conventions

- **Context.** One runtime and one context per process: `OOJSAcquireContext()` (E.h:188).
- **Natives** are `static JSValue F(OOJS_NATIVE_ARGS)`, i.e. `(JSContext *context, JSValueConst
  oojsThis, int argc, JSValueConst *oojsArgv)` (E.h:636), read through `OOJS_THIS` / `OOJS_ARGV`
  (E.h:639-640) and return the result (`OOJS_RETURN_*`, E.h:649-670). Example:
  `Scripting/OOJSShip.m:1775`.
- **Getters/setters** are `static JSValue G(OOJS_GETTER_ARGS)` = `(context, JSValueConst this, int
  magic)` and `S(OOJS_SETTER_ARGS)` = `(context, this, JSValueConst value, int magic)`; a setter
  returns `JS_UNDEFINED` on success (E.h:625-638). They `switch (magic)`, the old tinyid
  (`Scripting/OOJSShip.m:595`).
- **Property tables** are `static const JSCFunctionListEntry[]` of `OOJS_PROPERTY_RW(name, getter,
  setter, magic)` / `OOJS_PROPERTY_RO(name, getter, magic)` (E.h:788-789, over
  `JS_CGETSET_MAGIC_DEF2`) and `JS_CFUNC_DEF(name, length, fn)`, counted with `OOJS_COUNT` (E.h:82).
  Example: `Scripting/OOJSShip.m:315`, `:465`.
- **Classes**: a static `JSClassDef` plus a static `JSClassID` (`Scripting/OOJSShip.m:153`),
  registered once per process by `OOJSRegisterClass` (E.h:486, `Scripting/OOJSClasses.m:61`); each
  context builds the prototype with `OOJSInitClass` (E.h:522, `Scripting/OOJSClasses.m:202`);
  inheritance is recorded by `OOJSRegisterSubclass` (E.h:492). Typed private access uses
  `DEFINE_JS_OBJECT_GETTER` (E.h:543). Resolve/enumerate-style hooks are `JSClassExoticMethods`
  (`Scripting/OOJSManifest.m:57`).
- **Ownership** (E.h:27-58): refcounted. `JSValueConst` is borrowed; returned and out-parameter
  `JSValue`s are owned and freed with `JS_FreeValue`, spelled `OOJSFreeValue` outside
  `Scripting/` (E.h:207). Atoms from `OOJSID()` (`Scripting/OOJSPropID.h:40`) are immortal.
  Long-lived holders keep a reference and drop it on `kOOJavaScriptEngineWillResetNotification`
  (`OOJSValue`, E.m:1177).
- **Errors**: `OOJSReportError(context, fmt, …)` throws (E.h:251-257, `JS_ThrowPlainError` at
  E.m:821) and the native returns `JS_EXCEPTION`; a failure with nothing reported returns
  `OOJSNativeFailure(context)`, an uncatchable error (E.h:274-285, E.m:840). Callers into JS
  report with `OOJSReportPendingException` (E.h:249, E.m:749).

## Handles

| Façade name | SpiderMonkey original | How JSEngine_quickjs.cpp implements it | #768's form for the same job | #768 example |
|---|---|---|---|---|
| `RuntimeRep` | `JSRuntime` | incomplete type; `RT()` casts to `JSRuntime*` (L165) | `JSRuntime*` | E.m:163 |
| `ContextRep` | `JSContext` | incomplete type; `CX()` casts to `JSContext*` (L164) | `JSContext*` | E.h:188 |
| `ObjectRep` | `JSObject` | the `JSObject*` payload of a `JS_TAG_OBJECT` value (`objOf`/`OBJVAL`, L169-172) | none: an object is a `JSValue` with the object tag; no separate object pointer type | `Scripting/OOJSShip.m:581` |
| `StringRep` | `JSString` | the `JSString*` payload of a `JS_TAG_STRING` value (`STRVAL`, L176) | none: a string is a `JSValue`; text crosses as `NSString` | E.h:372 |
| `FunctionRep` | `JSFunction` | the function object's `JSObject*` | none: a function is a `JSValue` tested with `JS_IsFunction` | E.h:439 |
| `Runtime` | `JSRuntime*` | `RuntimeRep*` | `JSRuntime*` | E.m:163 |
| `Context` | `JSContext*` | `ContextRep*` | `JSContext*` (`context` parameter of every callback) | E.h:636 |
| `Object` | `JSObject*` | `ObjectRep*`, nullable | `JSValue` / `JSValueConst` holding an object | `Scripting/OOJSShip.m:581` |
| `String` | `JSString*` | `StringRep*` | `JSValue` string; `NSString*` at the boundary | E.h:372 |
| `Function` | `JSFunction*` | `FunctionRep*` | `JSValue` function | `Scripting/OOJSFunction.m:36` |
| `Value` | `jsval` | 8-byte NaN-boxed POD; `toJS()` rebuilds a borrowed `JSValue`, `take()`/`fromJS()` box it and park a +1 reference in the arena (L450-529) | `JSValue` (16 bytes; `JSValueConst` when borrowed), alias `OOJSVal` | `Scripting/OOJSPropID.h:33` |
| `Value::bits` | `jsval` bits (`JSVAL_TO_IMPL`) | doubles literal; else 0xFFF8 + 3-bit tag (bits 48-50) + 48-bit payload (L182-204) | none: `JSValue` is read with `JS_VALUE_GET_TAG` / `JS_VALUE_GET_*` | `Scripting/OOJSEngineDebuggerHelpers.m:111` |
| `PropertyId` | `jsid` | 64-bit: bit 63 int, bit 62 string atom, bit 61 symbol atom; low 32 bits int or `JSAtom` (L206-219) | `JSAtom`, alias `OOJSPropID` | `Scripting/OOJSPropID.h:32` |
| `PropertyId::bits` | `jsid` bits (`JSID_BITS`) | as `PropertyId` | none: a `JSAtom` is a `uint32_t` compared with `==` | `Scripting/OOJSClasses.m:150` |
| `Char16` | `jschar` | `char16_t`, asserted 16-bit (L160) | none: text crosses as UTF-8 (`JS_ToCStringLen`, `JS_NewStringLen`) | E.m:1220 |

## Value construction and inspection

| Façade name | SpiderMonkey original | How JSEngine_quickjs.cpp implements it | #768's form for the same job | #768 example |
|---|---|---|---|---|
| `undefinedValue` | `JSVAL_VOID` | boxed undefined tag (L226) | `JS_UNDEFINED` / `OOJSUndefinedValue()` | E.h:208 |
| `nullValue` | `JSVAL_NULL` | boxed null tag (L227) | `JS_NULL` / `OOJSNullValue()` | E.h:209 |
| `booleanValue` | `BOOLEAN_TO_JSVAL` | true/false tag (L230) | `OOJSValueFromBOOL(b)` (`JS_NewBool`) | E.h:300 |
| `trueValue` | `JSVAL_TRUE` | true tag (L228) | `JS_TRUE` / `OOJSValueFromBOOL(YES)` | E.h:302 |
| `falseValue` | `JSVAL_FALSE` | false tag (L229) | `JS_FALSE` / `OOJSValueFromBOOL(NO)` | E.h:302 |
| `int32Value` | `INT_TO_JSVAL` | int32 tag (L231) | `JS_NewInt32(context, i)`; `OOJS_RETURN_INT` | `Debug/OOJSConsole.m:329` |
| `numberValue` | `JS_NewNumberValue` (no success flag) / `DOUBLE_TO_JSVAL` | int32 when exact and not -0, NaN canonicalised, else the double's bits (L246) | `JS_NewNumber(context, d)` (int-canonicalising), `JS_NewFloat64`, `OOJSValueFromDouble` | `Scripting/OOJSClock.m:110` |
| `objectValue` | `OBJECT_TO_JSVAL` | object tag; nullptr gives null (L234) | none: the object already is a `JSValue`; `JS_DupValue` to hand on an owned copy | `Debug/OODebugMonitor.m:875` |
| `stringValue` | `STRING_TO_JSVAL` | string tag (L239) | none: the string already is a `JSValue` | E.m:1354 |
| `privateValue` | `PRIVATE_TO_JSVAL` | private tag, 48-bit pointer (L242) | none: native pointers live in the object's opaque slot (`JS_SetOpaque`), never in a value | `Scripting/OOJSEquipmentInfo.m:453` |
| `isUndefined` | `JSVAL_IS_VOID` | tag test (L264) | `JS_IsUndefined` / `OOJSValueIsUndefined` | E.h:210 |
| `isNull` | `JSVAL_IS_NULL` | tag test (L265) | `JS_IsNull` | `Debug/OOJSConsole.m:514` |
| `isNullOrUndefined` | `JSVAL_IS_NULL(v) \|\| JSVAL_IS_VOID(v)` | both tests (L266) | `JS_IsNull(v) \|\| JS_IsUndefined(v)` | E.m:1233 |
| `isObjectOrNull` | `JSVAL_IS_OBJECT` | object or null tag (L267) | `JS_IsObject(v) \|\| JS_IsNull(v)` | `Entities/ShipEntity.m:5324` |
| `isObject` | `!JSVAL_IS_PRIMITIVE` | object tag, non-null (L270) | `JS_IsObject` | `Debug/OODebugMonitor.m:132` |
| `isString` | `JSVAL_IS_STRING` | heap tag, symbol bit clear (L279) | `JS_IsString` | `Debug/OOJSConsole.m:461` |
| `isInt32` | `JSVAL_IS_INT` | int32 tag (L276) | `JS_VALUE_GET_TAG(v) == JS_TAG_INT` | E.m:1788 |
| `isDouble` | `JSVAL_IS_DOUBLE` | not boxed (L277) | `JS_VALUE_GET_TAG(v) == JS_TAG_FLOAT64` | `Scripting/OOJSEngineDebuggerHelpers.m:114` |
| `isNumber` | `JSVAL_IS_NUMBER` | int32 or double (L278) | `JS_IsNumber` | E.m:1792 |
| `isBoolean` | `JSVAL_IS_BOOLEAN` | true/false tag (L273) | `JS_IsBool` | E.m:1796 |
| `isPrimitive` | `JSVAL_IS_PRIMITIVE` | `!isObject` (L283) | `!JS_IsObject(v)` | E.m:1241 |
| `toObject` | `JSVAL_TO_OBJECT` | payload pointer, nullptr unless object (L287) | none: the value is the object | — |
| `toString` | `JSVAL_TO_STRING` | payload pointer (L290) | none: the value is the string; text via `OOStringFromJSValue` | E.m:1220 |
| `toInt32` | `JSVAL_TO_INT` | low 32 bits (L293) | `JS_VALUE_GET_INT(v)` | `Scripting/OOJSEngineDebuggerHelpers.m:155` |
| `toDouble` | `JSVAL_TO_DOUBLE` | memcpy of the bits (L296) | `JS_VALUE_GET_FLOAT64(v)` | `Scripting/OOJSEngineDebuggerHelpers.m:159` |
| `toBoolean` | `JSVAL_TO_BOOLEAN` | tag is true (L301) | `JS_VALUE_GET_BOOL(v)` | E.m:1797 |
| `toPrivate` | `JSVAL_TO_PRIVATE` | payload pointer (L302) | none: see `privateValue`; `JS_GetOpaque(obj, classID)` | `Scripting/OOJSTimer.m:377` |
| `newNumberValue` | `JS_NewNumberValue` | `numberValue`, always true (L2461) | `JS_NewNumber(context, d)` | `OOStringParsing.m:294` |
| `valueToNumber` | `JS_ValueToNumber` | `JS_ToFloat64` (L2466) | `JS_ToFloat64(ctx, &d, v)`, `< 0` on throw | `Scripting/OOJSClock.m:174` |
| `valueToBoolean` | `JS_ValueToBoolean` | `JS_ToBool` (L2470) | `OOJSValueToBOOL` (`JS_ToBool`, -1 on throw) | `Scripting/OOJSShip.m:2640` |
| `valueToObject` | `JS_ValueToObject` | null/undefined give a null object, else `JS_ToObject` (L2477) | `JS_ToObject` (owned) | `Scripting/OOJSGlobal.m:445` |
| `valueToInt32` | `JS_ValueToInt32` | ToNumber, round half up, error on NaN or out of range (L2498) | `OOJSValueToInt32` (same rounding and error) | `Scripting/OOJSManifest.m:218` |
| `valueToECMAInt32` | `JS_ValueToECMAInt32` | `JS_ToInt32` (L2523) | `JS_ToInt32` | E.m:1789 |
| `valueToECMAUint32` | `JS_ValueToECMAUint32` | `JS_ToInt32`, cast (L2527) | `JS_ToUint32` | `Scripting/OOJSFrameCallbacks.m:236` |
| `valueToString` | `JS_ValueToString` | `JS_ToString`, result parked in the arena (L2534) | none as a handle: `OOStringFromJSValue` (`JS_ToCStringLen`) straight to `NSString` | E.m:1220 |
| `valueToFunction` | `JS_ValueToFunction` | `JS_IsFunction`, else report "is not a function" (L2542) | `JS_IsFunction` / `OOJSValueIsFunction`; the value is the function | `Scripting/OOJSFunction.m:36` |
| `valueToId` | `JS_ValueToId` | int32 gives an int id, else `JS_ValueToAtom` (L2558) | `JS_ValueToAtom` (owned; `JS_FreeAtom`) | `Scripting/OOConstToJSString.m:221` |
| `idToValue` | `JS_IdToValue` | int id gives int32, atom `JS_AtomToValue` (L2571) | `JS_AtomToValue` | `Scripting/OOJSManifest.m:147` |
| `Type` | `JSType` | enum class (header) | none: no type enum; callers test tags (`JS_VALUE_GET_TAG`, `JS_Is*`) | `Scripting/OOJSEngineDebuggerHelpers.m:111` |
| `Type::Void` | `JSTYPE_VOID` | from `isUndefined` (L2585) | `JS_IsUndefined` | E.h:210 |
| `Type::Object` | `JSTYPE_OBJECT` | object, not callable | `JS_IsObject && !JS_IsFunction` | `Debug/OODebugMonitor.m:132` |
| `Type::Function` | `JSTYPE_FUNCTION` | `JS_IsFunction` | `JS_IsFunction` | `Scripting/OOJSFunction.m:36` |
| `Type::String` | `JSTYPE_STRING` | `isString` | `JS_IsString` | `Debug/OOJSConsole.m:461` |
| `Type::Number` | `JSTYPE_NUMBER` | `isNumber` | `JS_IsNumber` | E.m:1792 |
| `Type::Boolean` | `JSTYPE_BOOLEAN` | `isBoolean` | `JS_IsBool` | E.m:1796 |
| `Type::Null` | `JSTYPE_NULL` | `isNull` (as `typeof null` is "object", the façade keeps 1.8.5's mapping) | `JS_IsNull` | `Debug/OOJSConsole.m:514` |
| `Type::XML` | `JSTYPE_XML` | never produced | none: QuickJS-ng has no E4X | — |
| `typeOfValue` | `JS_TypeOfValue` | tag dispatch plus `JS_IsFunction` (L2585) | none: callers test tags; `JSValueTypeDbg` for debug text | `Scripting/OOJSEngineDebuggerHelpers.m:109` |
| `typeName` | `JS_GetTypeName` | static name table (L2597) | none: `JSValueTypeDbg`'s switch | `Scripting/OOJSEngineDebuggerHelpers.m:109` |

## Property ids

| Façade name | SpiderMonkey original | How JSEngine_quickjs.cpp implements it | #768's form for the same job | #768 example |
|---|---|---|---|---|
| `int32Id` | `INT_TO_JSID` | bit 63 plus the int (L307) | tinyids become the `magic` int of a `JSCFunctionListEntry`; element access uses `JS_GetPropertyUint32` | `Scripting/OOJSShip.m:317` |
| `voidId` | `JSID_VOID` | all bits 0 (L312) | `JS_ATOM_NULL` | E.m:1004 |
| `isInt32Id` | `JSID_IS_INT` | bit 63 (L317) | none: accessors receive `magic`, not an id; enumerated integer keys are recognised from the atom's text (`KeyForAtom`) | E.m:1683 |
| `isStringId` | `JSID_IS_STRING` | bit 62 (L318) | none: every `JSAtom` met is a string key | — |
| `isVoidId` | `JSID_IS_VOID` | bits == 0 (L319) | `atom == JS_ATOM_NULL` | E.m:1012 |
| `idToInt32` | `JSID_TO_INT` | low 32 bits (L320) | the `magic` parameter itself | `Scripting/OOJSShip.m:595` |
| `idToString` | `JSID_TO_STRING` | `JS_AtomToString`, kept as a string handle (L2619) | `JS_AtomToString` / `OOStringFromJSID` | E.m:1020 |
| `idsEqual` | `jsid` comparison (`JSID_BITS(a) == JSID_BITS(b)`) | bit compare (L323) | `JSAtom ==` | `Scripting/OOJSClasses.m:150` |

## Native functions

| Façade name | SpiderMonkey original | How JSEngine_quickjs.cpp implements it | #768's form for the same job | #768 example |
|---|---|---|---|---|
| `CallArgs` | `uintN argc, jsval *vp` with `JS_ARGV`/`JS_THIS`/`JS_RVAL` | the native trampoline builds `vp[2 + max(argc, nargs)]`: callee, this, args, undefined padding (L1867) | the native's parameters `OOJS_NATIVE_ARGS` | E.h:636 |
| `CallArgs::context` | `cx` parameter | stored `cx` | `context` parameter | E.h:636 |
| `CallArgs::count` | `argc` | stored `argc` | `argc` | `Scripting/OOJSShip.m:1783` |
| `CallArgs::argv` | `JS_ARGV(cx, vp)` | `vp + 2` | `OOJS_ARGV` | E.h:640 |
| `CallArgs::operator[]` | `JS_ARGV(cx, vp)[i]` | `vp[2 + i]` | `OOJS_ARGV[i]`, after checking `argc` | `Scripting/OOJSShip.m:1784` |
| `CallArgs::callee` | `JS_CALLEE(cx, vp)` | `vp[0]` | none: a `JSCFunction` is not given its callee (`JS_NewCFunctionData`'s data is the nearest) | — |
| `CallArgs::thisValue` | `JS_THIS(cx, vp)` (raw slot) | `vp[1]` | `OOJS_THIS` | E.h:639 |
| `CallArgs::thisObject` | `JS_THIS_OBJECT(cx, vp)` | object as is; null/undefined give the global; primitives boxed by `valueToObject` (L2631) | `OOJS_THIS` (QuickJS supplies the receiver; natives check its class) | E.h:639 |
| `CallArgs::rval` | `JS_RVAL(cx, vp)` | `vp[0]` | none: the native's return value is the result | E.h:649 |
| `CallArgs::setRval` | `JS_SET_RVAL(cx, vp, v)` | `vp[0] = v` | `return v;` / `OOJS_RETURN(v)` (hands ownership to QuickJS) | `Scripting/OOJSShip.m:1795` |
| `CallArgs::rawVp` | `vp` | `vp` | none: there is no `vp` array | — |
| `CallArgs::isConstructing` | `JS_IsConstructing` | `vp` is on the `gConstructing` list the trampoline pushes for `JS_CALL_FLAG_CONSTRUCTOR` (L2639) | `OOJS_IS_CONSTRUCTING` (`!JS_IsUndefined(OOJS_THIS)`; constructors made `JS_CFUNC_constructor_or_func`) | `Scripting/OOJSShipGroup.m:166` |
| `NativeFn` | `JSNative` | an object of the backend's own callable class; `NativeCallTramp` calls `runNative` (L1919) | `JSCFunction`: `static JSValue F(OOJS_NATIVE_ARGS)` returning a value or `JS_EXCEPTION` | `Scripting/OOJSShip.m:1775` |

## Classes

| Façade name | SpiderMonkey original | How JSEngine_quickjs.cpp implements it | #768's form for the same job | #768 example |
|---|---|---|---|---|
| `PropertyFlag` | `uintN` attrs (`JSPROP_*`) | `jsFlags()` maps to `JS_PROP_*` (L2006) | `JS_PROP_*` ints through the `OOJS_PROP_*` macros | E.h:775 |
| `PropertyFlag::None` | 0 | no flags | 0 (`OOJS_PROP_HIDDEN_READONLY`) | E.h:784 |
| `PropertyFlag::Enumerate` | `JSPROP_ENUMERATE` | `JS_PROP_ENUMERABLE` | `JS_PROP_ENUMERABLE` | E.h:775 |
| `PropertyFlag::ReadOnly` | `JSPROP_READONLY` | no `JS_PROP_WRITABLE` / no setter | no `JS_PROP_WRITABLE` (data) or a NULL setter (`OOJS_PROPERTY_RO`) | E.h:789 |
| `PropertyFlag::Permanent` | `JSPROP_PERMANENT` | no `JS_PROP_CONFIGURABLE` | no `JS_PROP_CONFIGURABLE` (no `OOJS_PROP_*` sets it) | E.h:781 |
| `PropertyFlag::Shared` | `JSPROP_SHARED` | accessor property from C closures, no slot (L2045) | getter/setter on the prototype (`JS_CGETSET_MAGIC_DEF2`), reported as own by `OOJSGetSharedPermanentOwnProperty` | `Scripting/OOJSClasses.m:161` |
| `operator\|` | C `\|` on `uintN` flags | `constexpr` OR for `PropertyFlag`, `ClassFlag`, `ContextOption` (header) | `\|` on `JS_PROP_*` ints | E.h:781 |
| `PropertyGetter` | `JSPropertyOp` | `JS_NewCClosure` trampoline `AccessorGetTramp` calls it with `int32Id(tinyid)` and `*vp` (L1980) | `static JSValue G(OOJS_GETTER_ARGS)` | `Scripting/OOJSShip.m:581` |
| `PropertySetter` | `JSStrictPropertyOp` | `AccessorSetTramp` (L1992) | `static JSValue S(OOJS_SETTER_ARGS)`, returns `JS_UNDEFINED` | `Scripting/OOJSShip.m:1122` |
| `EnumerateHook` | `JSEnumerateOp` | feeds exotic `get_own_property_names` (`ExGetOwnPropertyNames`, L1244) | `JSClassExoticMethods.get_own_property_names` | `Scripting/OOJSMissionVariables.m:79` |
| `ResolveHook` | `JSResolveOp` | run on an own-lookup miss in `ownLookup`, re-entrancy guarded (L1140) | `JSClassExoticMethods.get_own_property` answers lazily | `Scripting/OOJSManifest.m:58` |
| `ConvertHook` | `JSConvertOp` | installed as `Symbol.toPrimitive` on the prototype (`installConvert` L2239, `ToPrimitiveTramp` L2201) | none: no convert hook; wrapper classes give a `toString` method (`OOJSObjectWrapperToString`) | E.h:623 |
| `FinalizeHook` | `JSFinalizeOp` | `JSClassDef.finalizer` = `FinalizeTramp` (L1698) | `JSClassDef.finalizer` `void (JSRuntime*, JSValueConst)`, usually `OOJSObjectWrapperFinalize` | `Scripting/OOJSShip.m:155` |
| `PropertySpec` | `JSPropertySpec` | `definePropertySpecs`: accessor when it has hooks or the class does, else data (L2127) | `JSCFunctionListEntry` from `OOJS_PROPERTY_RW` / `OOJS_PROPERTY_RO` | `Scripting/OOJSShip.m:315` |
| `PropertySpec::name` | `.name` | `JS_NewAtom` | first macro argument | `Scripting/OOJSShip.m:317` |
| `PropertySpec::tinyid` | `.tinyid` | passed to the hook as `int32Id(tinyid)` | `magic`, last macro argument | `Scripting/OOJSShip.m:317` |
| `PropertySpec::flags` | `.flags` | `jsFlags` | fixed by the macro (`OOJS_PROP_READWRITE_CB` / `OOJS_PROP_READONLY_CB`) | E.h:788 |
| `PropertySpec::getter` | `.getter` | accessor closure | getter argument | `Scripting/OOJSShip.m:317` |
| `PropertySpec::setter` | `.setter` | accessor closure | setter argument; NULL in `OOJS_PROPERTY_RO` | `Scripting/OOJSShip.m:317` |
| `FunctionSpec` | `JSFunctionSpec` | `defineFunctionSpecs` → `newNativeFunction` (L2188) | `JSCFunctionListEntry` from `JS_CFUNC_DEF(name, length, fn)` | `Scripting/OOJSShip.m:465` |
| `FunctionSpec::name` | `.name` | property atom | first argument | `Debug/OOJSConsole.m:181` |
| `FunctionSpec::call` | `.call` | the native | third argument | `Debug/OOJSConsole.m:181` |
| `FunctionSpec::nargs` | `.nargs` | `length` and argument padding | second argument (`length`) | `Debug/OOJSConsole.m:181` |
| `FunctionSpec::flags` | `.flags` | `jsFlags` | none in `JS_CFUNC_DEF` (fixed attributes); explicit flags only via `JS_DefinePropertyValueStr` | `Scripting/OOJSFont.m:39` |
| `EnumerateOp` | `JSIterateOp` | `ExGetOwnPropertyNames` drives Init/Next/Destroy to build one list (L1244) | none: `get_own_property_names` returns the whole `JSPropertyEnum` array | `Scripting/OOJSMissionVariables.m:79` |
| `EnumerateOp::Init` | `JSENUMERATE_INIT` | first call of the list build | none: no iterator protocol | — |
| `EnumerateOp::InitAll` | `JSENUMERATE_INIT_ALL` | as Init, non-enumerable too | none: `JS_GPN_*` flags choose enumerable-only | E.m:1704 |
| `EnumerateOp::Next` | `JSENUMERATE_NEXT` | repeated until `*statep` is null | none: no iterator protocol | — |
| `EnumerateOp::Destroy` | `JSENUMERATE_DESTROY` | final call | none: `JS_FreePropertyEnum` frees the array | `Scripting/OOJSSystemInfo.m:591` |
| `NewEnumerateHook` | `JSNewEnumerateOp` | as `EnumerateOp` | `JSClassExoticMethods.get_own_property_names` | `Scripting/OOJSSystemInfo.m:95` |
| `ClassFlag` | `JSClass.flags` | read by `attach` and the hooks | none: `JSClassDef` has no flags | — |
| `ClassFlag::None` | 0 | no flags | none | — |
| `ClassFlag::HasPrivate` | `JSCLASS_HAS_PRIVATE` | every backend object carries an `ObjRec` opaque (L1832) | none: every class object has an opaque slot (`JS_SetOpaque` / `JS_GetOpaque`) | `Scripting/EntityOOJavaScriptExtensions.m:57` |
| `ClassFlag::NewEnumerate` | `JSCLASS_NEW_ENUMERATE` | selects `newEnumerate` over `enumerate` | none: one exotic `get_own_property_names` | — |
| `ClassFlag::Global` | `JSCLASS_GLOBAL_FLAGS` | `newGlobalObject` records the def for the context's fixed global (L2654) | none: the context's own global is used as is | E.m:191 |
| `ClassDef` | `JSClass` | `attach()` allocates a `JSClassID` and `JS_NewClass`es it per runtime on first use (L1754) | static `JSClassDef` + static `JSClassID`, `OOJSRegisterClass` | `Scripting/OOJSShip.m:153` |
| `ClassDef::name` | `.name` | `class_name` | `.class_name` | `Scripting/OOJSShip.m:154` |
| `ClassDef::flags` | `.flags` | see `ClassFlag` | none | — |
| `ClassDef::addProperty` | `.addProperty` | called by `addSlot` when a set adds an own property (L1484) | none as a hook: exotic `define_own_property` / `set_property` | `Scripting/OOJSMissionVariables.m:81` |
| `ClassDef::delProperty` | `.delProperty` | `ExDeleteProperty` (L1659) | exotic `.delete_property` | `Scripting/OOJSManifest.m:60` |
| `ClassDef::getProperty` | `.getProperty` | `ExGetProperty`; also the default tinyid getter of a class's `PropertySpec`s (L1386) | per-property getter + `switch (magic)`; class-wide, exotic `.get_property` | `Scripting/OOJSMissionVariables.m:82` |
| `ClassDef::setProperty` | `.setProperty` | `ExSetProperty` (L1505) | per-property setter; class-wide, exotic `.set_property` | `Scripting/OOJSManifest.m:61` |
| `ClassDef::enumerate` | `.enumerate` | `ExGetOwnPropertyNames` (L1244) | exotic `.get_own_property_names` | `Scripting/OOJSMissionVariables.m:79` |
| `ClassDef::newEnumerate` | `.enumerate` with `JSCLASS_NEW_ENUMERATE` | `ExGetOwnPropertyNames` (L1244) | exotic `.get_own_property_names` | `Scripting/OOJSSystemInfo.m:95` |
| `ClassDef::resolve` | `.resolve` | `ownLookup` (L1140) | exotic `.get_own_property` | `Scripting/OOJSManifest.m:58` |
| `ClassDef::convert` | `.convert` | `Symbol.toPrimitive` (L2239) | none: `toString` method instead | E.h:623 |
| `ClassDef::finalize` | `.finalize` | `FinalizeTramp` (L1698) | `.finalizer` | `Scripting/OOJSShip.m:155` |
| `ClassDef::call` | `.call` | `JSClassDef.call` → `runNative` (L1734) | none: no callable instance classes in #768 (`JSClassDef.call` unused) | — |
| `ClassDef::construct` | `.construct` | `JSClassDef.call` with `JS_CALL_FLAG_CONSTRUCTOR` (L1734) | constructor `JSCFunction` made by `JS_NewCFunction2(…, JS_CFUNC_constructor_or_func)` in `OOJSInitClass` | `Scripting/OOJSClasses.m:226` |
| `ClassDef::backend` | (no counterpart) | `BackendClass*` (class id, prototype) cached on first use | the static `JSClassID` variable | `Scripting/OOJSShip.m:564` |

## Objects

| Façade name | SpiderMonkey original | How JSEngine_quickjs.cpp implements it | #768's form for the same job | #768 example |
|---|---|---|---|---|
| `newObject` | `JS_NewObject` | `newObjectRaw`: `JS_NewObjectProtoClass` with the class's id and the given or class prototype, `ObjRec` opaque (L2647, L1832) | `JS_NewObjectClass(ctx, classID)` (class prototype) / `JS_NewObjectProtoClass` / `JS_NewObject` | `Scripting/EntityOOJavaScriptExtensions.m:52` |
| `newGlobalObject` | `JS_NewCompartmentAndGlobalObject` | returns the context's fixed global and records the def (L2654) | `JS_GetGlobalObject` after `JS_NewContext` | E.m:191 |
| `setGlobalObject` | `JS_SetGlobalObject` | no-op (L2665) | none: the global is fixed by `JS_NewContext` | — |
| `initStandardClasses` | `JS_InitStandardClasses` | returns true (L2670) | none: `JS_NewContext` adds them | E.m:183 |
| `clearScope` | `JS_ClearScope` | deletes every configurable own property, empties the slot table (L2674) | none: `-reset` frees the context and makes a new one | E.m:274 |
| `initClass` | `JS_InitClass` | `attach`; prototype `JS_NewObjectProtoClass`; `JS_SetClassProto`; native constructor; `prototype`/`constructor` links; specs (L2699) | `OOJSInitClass(context, global, classID, parentProto, ctor, nargs, props, n, methods, n, statics, n)` | `Scripting/OOJSShip.m:567` |
| `defineObject` | `JS_DefineObject` | `newObjectRaw` + `defineData` (L2762) | `JS_NewObjectProtoClass` + `JS_DefinePropertyValueStr(…, OOJS_PROP_READONLY)` | `Scripting/OOJSOolite.m:101` |
| `getConstructor` | `JS_GetConstructor` | `ctorForProto` cache, else `proto.constructor` (L2774) | `JS_GetPropertyStr(obj, "constructor")` where needed | E.m:1248 |
| `getPrototype` | `JS_GetPrototype` | `JS_GetPrototype` (L2790) | `JS_GetPrototype` (owned in QuickJS-ng) | `Scripting/OOJSClasses.m:84` |
| `getParent` | `JS_GetParent` | always the global (L2795) | none: QuickJS objects have no parent | — |
| `getGlobalObject` | `JS_GetGlobalObject` | `JS_GetGlobalObject`, reference dropped (L2802) | `JS_GetGlobalObject(context)` (owned) or `-globalObject` (borrowed) | `Scripting/OOJSFrameCallbacks.m:145` |
| `getGlobalForObject` | `JS_GetGlobalForObject` | the global (L2798) | none: one global; `JS_GetGlobalObject` | — |
| `getClass` | `JS_GetClass` | the `ClassDef` of one of our classes, else nullptr (L2850) | `JS_GetClassID(obj) == classID` | `Scripting/OOJSQuaternion.m:236` |
| `getObjectClass` | `JS_GetClass` (any object) | ours, or a cached hook-less descriptor named from `Object.prototype.toString` (L2857) | `JS_GetClassID` against `gOOJS*ClassID`; `OOJSClassNameOfValue` for names | E.h:432 |
| `instanceOf` | `JS_InstanceOf` | class identity; with `argv`, reports "X.prototype.f called on incompatible Y" (L2885) | `OOJSIsMemberOfSubclass` / `DEFINE_JS_OBJECT_GETTER` (which raises the error) | `Scripting/OOJSQuaternion.m:221` |
| `setPrivate` | `JS_SetPrivate` | `ObjRec::priv`; the global has a per-context slot (L2894) | `JS_SetOpaque(obj, ptr)` | `Scripting/OOJSEquipmentInfo.m:453` |
| `getPrivate` | `JS_GetPrivate` | `ObjRec::priv` (L2909) | `JS_GetOpaque(obj, classID)` / `JS_GetAnyOpaque` | `Scripting/OOJSTimer.m:377` |
| `getInstancePrivate` | `JS_GetInstancePrivate` | `instanceOf` then `getPrivate` (L2920) | `JS_GetOpaque(obj, classID)` (NULL for another class) or `DEFINE_JS_OBJECT_GETTER` | `Scripting/OOJSEquipmentInfo.m:162` |
| `objectIsFunction` | `JS_ObjectIsFunction` | `JS_IsFunction` (L2924) | `JS_IsFunction` / `OOJSValueIsFunction` | `Scripting/OOJSFunction.m:36` |
| `getProperty` | `JS_GetProperty` | `JS_NewAtom` + `JS_GetProperty` (L2983) | `JS_GetPropertyStr` (owned result) | `Debug/OOJSConsole.m:737` |
| `setProperty` | `JS_SetProperty` | `JS_NewAtom` + `JS_SetProperty` of a dup (L2989) | `JS_SetPropertyStr` (consumes the value) | `Scripting/OOJSMission.m:669` |
| `getPropertyById` | `JS_GetPropertyById` | `JS_GetProperty` by atom (L2995) | `JS_GetProperty(ctx, obj, OOJSID("name"))` | `OOStringParsing.m:292` |
| `setPropertyById` | `JS_SetPropertyById` | `JS_SetProperty` by atom (L3001) | `JS_SetProperty` (consumes the value) | `Scripting/OOJSScript.m:418` |
| `definePropertyById` | `JS_DefinePropertyById` | `definePropertyImpl`: accessor closures or a `JS_DefineProperty` data property (L3007) | `JS_DefinePropertyValue(ctx, obj, atom, owned value, flags)` | `Scripting/OOJSScript.m:428` |
| `lookupProperty` | `JS_LookupProperty` | own then prototype descriptor walk without running getters (`lookupByAtom`, L3025) | `JS_GetOwnProperty` on the object or its prototype | `Scripting/OOJSManifest.m:246` |
| `lookupPropertyById` | `JS_LookupPropertyById` | `lookupByAtom` (L3031) | `JS_GetOwnProperty` | `Scripting/OOJSClasses.m:171` |
| `hasProperty` | `JS_HasProperty` | `JS_HasProperty` (L3037) | `JS_HasProperty` (int, < 0 on throw) | `Scripting/OOJSMissionVariables.m:238` |
| `deleteProperty` | `JS_DeleteProperty` | `JS_DeleteProperty` (L3046) | `JS_DeleteProperty(ctx, obj, atom, 0)` | `Scripting/OOJSMission.m:673` |
| `getMethodById` | `JS_GetMethodById` | `getPropertyById` (L3054) | `JS_GetProperty`, then `JS_IsUndefined` / `JS_IsFunction` | `Scripting/OOJSScript.m:342` |
| `defineProperty` | `JS_DefineProperty` | `definePropertyImpl` (L3016) | `JS_DefinePropertyValueStr` | `Debug/OODebugMonitor.m:690` |
| `defineProperties` | `JS_DefineProperties` | `definePropertySpecs` (L3060) | `JS_SetPropertyFunctionList(ctx, obj, list, count)` | `Scripting/OOJSGlobal.m:137` |
| `defineFunction` | `JS_DefineFunction` | `defineNative`: `newNativeFunction` + `defineData` (L3064) | `JS_DefinePropertyValueStr(obj, name, JS_NewCFunction(ctx, fn, name, nargs), flags)` | `Scripting/OOJSFont.m:39` |
| `defineFunctions` | `JS_DefineFunctions` | `defineFunctionSpecs` (L3073) | `JS_SetPropertyFunctionList` with `JS_CFUNC_DEF` entries | `Scripting/OOJSClasses.m:222` |
| `setElement` | `JS_SetElement` | `setPropertyById(int32Id(i))` (L3080) | `JS_SetPropertyUint32` (consumes the value) | `Scripting/OOJSQuaternion.m:722` |
| `getElement` | `JS_GetElement` | `getPropertyById(int32Id(i))` (L3083) | `JS_GetPropertyUint32` | `Scripting/OOJSVector.m:219` |
| `lookupElement` | `JS_LookupElement` | `lookupPropertyById(int32Id(i))` (L3086) | none: not needed; `JS_GetOwnProperty` would do it | — |
| `newArrayObject` | `JS_NewArrayObject` | `JS_NewArrayFrom`, or `JS_NewArray` + `JS_SetLength` (L3090) | `JS_NewArray` then `JS_SetPropertyUint32` per element | E.m:1038 |
| `isArrayObject` | `JS_IsArrayObject` | `JS_IsArray` (L3110) | `JS_IsArray` / `OOJSValueIsArray` | `Scripting/OOJSVector.m:249` |
| `getArrayLength` | `JS_GetArrayLength` | `JS_GetLength` (L3114) | `JS_GetLength(ctx, obj, &int64)` | `Scripting/OOJSVector.m:251` |
| `setArrayLength` | `JS_SetArrayLength` | `JS_SetLength` (L3121) | none: not used by #768 (`JS_SetLength` exists) | — |
| `IdArray` | `JSIdArray` | heap struct of `PropertyId` copies (L3128) | `JSPropertyEnum*` + count | E.m:1704 |
| `IdArray::length` | `->length` | entry count | `count` out-parameter of `JS_GetOwnPropertyNames` | E.m:1704 |
| `IdArray::ids` | `->vector` | `idFromAtom` per atom | `properties[i].atom` | E.m:1711 |
| `IdArray::backend` | (no counterpart) | nullptr | none: façade bookkeeping | — |
| `enumerate` | `JS_Enumerate` | `JS_GetOwnPropertyNames(…, JS_GPN_STRING_MASK \| JS_GPN_ENUM_ONLY)` (L3128) | `JS_GetOwnPropertyNames(ctx, &tab, &n, obj, JS_GPN_STRING_MASK \| JS_GPN_ENUM_ONLY)` | E.m:1704 |
| `destroyIdArray` | `JS_DestroyIdArray` | `delete` (L3145) | `JS_FreePropertyEnum(ctx, tab, n)` | E.m:1727 |
| `getFunctionId` | `JS_GetFunctionId` | the function's `name`; empty gives null (L3154) | `JS_GetPropertyStr(fn, "name")` | E.m:1259 |
| `getFunctionObject` | `JS_GetFunctionObject` | identity cast (L3170) | none: the function already is its `JSValue` | — |
| `getFunctionNative` | `JS_GetFunctionNative` | `NativeRec` lookup for the backend's native class (L3172) | none: a `JSCFunction` pointer cannot be read back; not needed | — |
| `callFunctionValue` | `JS_CallFunctionValue` | `JS_Call`; a top-level failure is reported by `finish()` (L3180) | `JS_Call(ctx, fn, this, argc, argv)` (owned result), or `-callJSFunction:…` which reports | E.m:370 |
| `callFunctionName` | `JS_CallFunctionName` | `getProperty` + `callFunctionValue` (L3202) | `JS_GetProperty(obj, atom)` then `JS_Call` | `Scripting/OOJSScript.m:368` |
| `evaluateScript` | `JS_EvaluateScript` | `evalWithThis`: `JS_EvalThis2` with the scope as `this`, filename and line (L3213, L2401) | `JS_Eval(ctx, buf, len, filename, JS_EVAL_TYPE_GLOBAL)` on a NUL-terminated buffer | E.m:491 |
| `evaluateUCScript` | `JS_EvaluateUCScript` | UTF-16 to UTF-8, then `evalWithThis` (L3219) | `JS_Eval` of the `NSString`'s UTF-8 | E.m:491 |

## Scripts

| Façade name | SpiderMonkey original | How JSEngine_quickjs.cpp implements it | #768's form for the same job | #768 example |
|---|---|---|---|---|
| `ScriptRep` | `JSScript` | struct holding the bytecode `JSValue`, source, filename, line (L333) | none: a compiled script is a `JSValue` (bytecode) | `Scripting/OOJSScript.m:682` |
| `Script` | `JSScript*` | `ScriptRep*` | the `JSValue compiled` | `Scripting/OOJSScript.m:682` |
| `compileUCScript` | `JS_CompileUCScript` | `JS_EvalThis2` with `JS_EVAL_FLAG_COMPILE_ONLY`; keeps the source for non-global scopes (L3229) | `JS_Eval(…, JS_EVAL_TYPE_GLOBAL \| JS_EVAL_FLAG_COMPILE_ONLY)` of the wrapped `(function(){…})` | `Scripting/OOJSScript.m:691` |
| `newScriptObject` | `JS_NewScriptObject` | object of the backend's script class owning the `Script` (L3252) | none: no script object; `JS_EvalFunction` consumes the bytecode and `OOJSScript` keeps its own `_jsSelf` | `Scripting/OOJSScript.m:704` |
| `executeScript` | `JS_ExecuteScript` | global scope: `JS_EvalFunction` on a dup; any other scope re-evaluates the source with that `this` (L3262) | `JS_EvalFunction(ctx, compiled)` gives the function, then `JS_Call(function, scriptObject)` | `Scripting/OOJSScript.m:704` |
| `destroyScript` | `JS_DestroyScript` | `releaseScript` frees the bytecode (L3284) | none: `JS_EvalFunction` took ownership (else `JS_FreeValue`) | `Scripting/OOJSScript.m:704` |
| `ByteBuffer` | XDR memory buffer (`JSXDRState`) | malloc'd bytes + length | `uint8_t*` + `size_t` from `JS_WriteObject`, copied into `NSData` | `Scripting/OOJSScript.m:784` |
| `ByteBuffer::data` | `JS_XDRMemGetData` result | the bytes | `bytes` | `Scripting/OOJSScript.m:784` |
| `ByteBuffer::length` | `JS_XDRMemGetData` length | the byte count | `length` | `Scripting/OOJSScript.m:784` |
| `serializeScript` | `JS_XDRNewMem(ENCODE)` + `JS_XDRScript` + `JS_XDRMemGetData` + `JS_XDRDestroy` | header (line, filename, source) + `JS_WriteObject(JS_WRITE_OBJ_BYTECODE)` (L3288) | `JS_WriteObject(ctx, &len, compiled, JS_WRITE_OBJ_BYTECODE)`; the cache entry also keys a source hash and `JS_GetVersion()` | `Scripting/OOJSScript.m:784` |
| `deserializeScript` | `JS_XDRNewMem(DECODE)` + `JS_XDRMemSetData` + `JS_XDRScript` + `JS_XDRDestroy` | header check + `JS_ReadObject(JS_READ_OBJ_BYTECODE)` (L3315) | `JS_ReadObject(ctx, bytes, len, JS_READ_OBJ_BYTECODE)` | `Scripting/OOJSScript.m:770` |
| `destroyByteBuffer` | (freed by `JS_XDRDestroy`) | `free()` (L3349) | `js_free(context, bytes)` after the copy | `Scripting/OOJSScript.m:792` |

## Strings

| Façade name | SpiderMonkey original | How JSEngine_quickjs.cpp implements it | #768's form for the same job | #768 example |
|---|---|---|---|---|
| `internString` | `JS_InternString` | `JS_NewAtom`; the string is kept for the runtime's life (L3380) | `OOJSID("literal")` (immortal atom); `OOJSSTR()` for the string value | E.h:366 |
| `internUCStringN` | `JS_InternUCStringN` | `JS_NewStringUTF16` + `JS_ValueToAtom` (L3385) | `OOJSIDFromString(NSString)` (`JS_NewAtomLen` on UTF-8, cached) | E.m:1011 |
| `newStringCopyZ` | `JS_NewStringCopyZ` | `JS_NewStringLen` (L3395) | `JS_NewStringLen` / `-oo_jsValueInContext:` on an `NSString` | E.m:1354 |
| `newStringCopyN` | `JS_NewStringCopyN` | `JS_NewStringLen` (L3400) | `JS_NewStringLen` | E.m:1354 |
| `newUCStringCopyN` | `JS_NewUCStringCopyN` | `JS_NewStringUTF16` (L3405) | none: UTF-16 never crosses; `NSString` → UTF-8 → `JS_NewStringLen` | E.m:1354 |
| `emptyStringValue` | `JS_GetEmptyStringValue` | `JS_NewStringLen("", 0)` (L3412) | none: no helper (`OOJSID` rejects ""); `JS_NewStringLen(ctx, "", 0)` would do | — |
| `getStringLength` | `JS_GetStringLength` | length of the cached UTF-16 copy (L3417) | none: length is taken from the `NSString` | — |
| `getStringCharsAndLength` | `JS_GetStringCharsAndLength` | `JS_ToCStringLenUTF16`, cached until the next arena flush (`stringChars` L683, L3423) | `JS_ToCStringLen` (UTF-8) + `JS_FreeCString`, usually via `OOStringFromJSValue` | E.m:1220 |
| `getInternedStringChars` | `JS_GetInternedStringChars` | the same cache (L3428) | `OOStringFromJSID(atom)` | E.m:1020 |
| `stringEqualsAscii` | `JS_StringEqualsAscii` | compares the cached UTF-16 (L3432) | none: compare the `NSString`, or the atom with `OOJSID("x")` | — |
| `stringHasBeenInterned` | `JS_StringHasBeenInterned` | membership of the interned sets (L3443) | none: atoms are interned by construction | — |
| `setCStringsAreUTF8` | `JS_SetCStringsAreUTF8` | no-op (L3451) | none: QuickJS C strings are always UTF-8 | — |

## Regular expressions

| Façade name | SpiderMonkey original | How JSEngine_quickjs.cpp implements it | #768's form for the same job | #768 example |
|---|---|---|---|---|
| `newUCRegExpObjectNoStatics` | `JS_NewUCRegExpObjectNoStatics` | flags to "gimy", `JS_CallConstructor` on `RegExp` (L3456) | `JS_GetPropertyStr(global, "RegExp")` + `JS_CallConstructor` with pattern and flag strings | `OORegExpMatcher.m:116` |

## Exceptions and error reporting

| Façade name | SpiderMonkey original | How JSEngine_quickjs.cpp implements it | #768's form for the same job | #768 example |
|---|---|---|---|---|
| `isExceptionPending` | `JS_IsExceptionPending` | `JS_HasException` (L3488) | `JS_HasException` | `OOStringParsing.m:288` |
| `getPendingException` | `JS_GetPendingException` | `JS_GetException`, then re-`JS_Throw` to stay pending (L3490) | `JS_GetException` (clears; owned) | `OOStringParsing.m:290` |
| `setPendingException` | `JS_SetPendingException` | `JS_Throw` of a dup (L3500) | `JS_Throw` (consumes) | `OOStringParsing.m:311` |
| `clearPendingException` | `JS_ClearPendingException` | `JS_FreeValue(JS_GetException)` (L3505) | `JS_FreeValue(ctx, JS_GetException(ctx))` | E.m:971 |
| `reportPendingException` | `JS_ReportPendingException` | `reportPendingImpl`: `ErrorReport` from the error's fileName/lineNumber/stack, reporter called, cleared (L3510, L944) | `OOJSReportPendingException(ctx)` (logs via `LogProblem`, clears) | E.m:749 |
| `reportError` | `JS_ReportError` | with a script running, throw `Error(message)`; else call the reporter (L3512, L913) | `OOJSReportError(ctx, fmt, …)` (`JS_ThrowPlainError`), then `return JS_EXCEPTION` | E.m:821 |
| `reportWarning` | `JS_ReportWarning` | reporter with the Warning flag and current location; never throws (L3516) | `OOJSReportWarning(ctx, fmt, …)` (logs, does not throw) | E.m:851 |
| `reportOutOfMemory` | `JS_ReportOutOfMemory` | clears any pending exception, reports "out of memory", leaves nothing pending (L3528) | `JS_ThrowOutOfMemory(ctx)` (returns `JS_EXCEPTION`) | `Scripting/OOJSVector.m:159` |
| `ReportFlag` | `JSREPORT_*` | bits in `ErrorReport::flags` | none: severity is a string ("exception" / "warning") passed to `LogProblem` and the monitor | E.m:708 |
| `ReportFlag::Error` | `JSREPORT_ERROR` | 0 | none: QuickJS reports every error as an exception | `Scripting/README.md:123` |
| `ReportFlag::Warning` | `JSREPORT_WARNING` | warnings from `reportWarning` | "warning" severity | E.h:156 |
| `ReportFlag::Exception` | `JSREPORT_EXCEPTION` | set for reported pending exceptions | "exception" severity | E.m:773 |
| `ReportFlag::Strict` | `JSREPORT_STRICT` | never set | none: no strict-mode warnings | `Scripting/README.md:123` |
| `ErrorReport` | `JSErrorReport` | filled from the error's fileName/lineNumber or stack (L944) | none: QuickJS has no `JSErrorReport`; the location comes from the exception's `stack` | E.h:155 |
| `ErrorReport::filename` | `->filename` | parsed location | `inFile:` of the monitor's problem message | E.h:165 |
| `ErrorReport::lineno` | `->lineno` | parsed location | `line:` | E.h:166 |
| `ErrorReport::flags` | `->flags` | `ReportFlag` bits | `problemOfSeverity:` string | E.h:164 |
| `ErrorReport::errorNumber` | `->errorNumber` | 0 | none: log classes are named after the error type (`exception.ReferenceError`) | E.m:763 |
| `ErrorReport::ucmessage` | `->ucmessage` | UTF-16 message | `withMessage:` `NSString` | E.h:169 |
| `ErrorReport::linebuf` | `->linebuf` | null | none | — |
| `ErrorReporter` | `JSErrorReporter` | per-context hook called by `invokeReporter` (L887) | none: fixed `LogProblem`, plus the optional `OOJavaScriptEngineMonitor` | E.m:708 |
| `setErrorReporter` | `JS_SetErrorReporter` | stored in the context state (L3539) | none: not settable; a monitor is attached with `-setMonitor:` | E.h:181 |
| `ExceptionState` | `JSExceptionState` | `{hadException, owned value}` (L328) | none: a local `BOOL hadException` + `JSValue exception` | `OOStringParsing.m:288` |
| `saveExceptionState` | `JS_SaveExceptionState` | `JS_GetException` into a new state (L3547) | `hadException = JS_HasException(ctx); exception = JS_GetException(ctx)` | `OOStringParsing.m:290` |
| `restoreExceptionState` | `JS_RestoreExceptionState` | clear pending, `JS_Throw` the saved one (L3558) | `JS_Throw(ctx, exception)` | `OOStringParsing.m:311` |
| `dropExceptionState` | `JS_DropExceptionState` | free the saved value (L3567) | `JS_FreeValue(ctx, exception)` | E.m:971 |

## GC roots

| Façade name | SpiderMonkey original | How JSEngine_quickjs.cpp implements it | #768's form for the same job | #768 example |
|---|---|---|---|---|
| `addNamedObjectRoot` | `JS_AddNamedObjectRoot` | registers the address; an arena flush re-references whatever it holds (L3599) | none: refcounting; the holder owns a reference (`JS_DupValue` in, `JS_FreeValue` out, and on `kOOJavaScriptEngineWillResetNotification`) | E.m:1177 |
| `addNamedValueRoot` | `JS_AddNamedValueRoot` | as `addNamedObjectRoot` (L3603) | none: owned reference, as above | E.m:1177 |
| `addNamedStringRoot` | `JS_AddNamedStringRoot` | as `addNamedObjectRoot` (L3607) | none: owned reference, as above | E.m:1177 |
| `removeObjectRoot` | `JS_RemoveObjectRoot` | unregisters the address (L3612) | `JS_FreeValue` of the held reference | E.m:1191 |
| `removeValueRoot` | `JS_RemoveValueRoot` | unregisters the address (L3613) | `JS_FreeValue` of the held reference | E.m:1191 |
| `removeStringRoot` | `JS_RemoveStringRoot` | unregisters the address (L3614) | `JS_FreeValue` of the held reference | E.m:1191 |
| `RootedObject` | `JS_AddNamedObjectRoot` / `JS_RemoveObjectRoot` pair | RAII over the two (header) | none: locals need no rooting; an owned local is freed with `JS_FreeValue` when done | `Scripting/OOJSShip.m:570` |
| `RootedObject::get` | the rooted variable | returns it | the `JSValue` itself | — |
| `RootedObject::address` | `&variable` | returns its address | `&value` (an out-parameter) | — |
| `RootedObject::set` | assignment | assigns | assignment, freeing the previous owned value | — |
| `RootedValue` | `JS_AddNamedValueRoot` / `JS_RemoveValueRoot` pair | RAII over the two (header) | none: as `RootedObject` | `Scripting/OOJSShip.m:570` |
| `RootedValue::get` | the rooted variable | returns it | the `JSValue` itself | — |
| `RootedValue::address` | `&variable` | returns its address | `&value` | — |
| `RootedValue::set` | assignment | assigns | assignment, freeing the previous owned value | — |

## Runtime, contexts, requests, GC

| Façade name | SpiderMonkey original | How JSEngine_quickjs.cpp implements it | #768's form for the same job | #768 example |
|---|---|---|---|---|
| `newRuntime` | `JS_NewRuntime` | `JS_NewRuntime`, runtime state as opaque, `JS_SetMemoryLimit`, `JS_SetInterruptHandler`, the backend's native/script/scope-fallback classes (L3619) | `JS_NewRuntime` + `JS_SetMemoryLimit` + `JS_SetMaxStackSize` + `JS_SetInterruptHandler` in `-init` | E.m:163 |
| `destroyRuntime` | `JS_DestroyRuntime` | drops roots, scopes, arena and caches; `JS_FreeRuntime` (L3648) | `JS_FreeRuntime` in `-shutDown`; the runtime is abandoned if objects leak | E.m:337 |
| `shutDown` | `JS_ShutDown` | no-op (L3673) | none: nothing process-wide to release | — |
| `newContext` | `JS_NewContext` | `JS_NewContext`, context state, cached `Object.prototype`, scope fallback, context callback (L3675) | `JS_NewContext` in `-createMainThreadContext`, kept in `gOOJSMainThreadContext` | E.m:183 |
| `destroyContext` | `JS_DestroyContext` | context callback; roots and arena released with the last context; `JS_FreeContext` (L3696) | `JS_FreeContext` in `-destroyMainThreadContext`, then `JS_RunGC` | E.m:252 |
| `getRuntime` | `JS_GetRuntime` | `JS_GetRuntime` (L3738) | `JS_GetRuntime` | `Debug/OOJSConsole.m:880` |
| `getContextPrivate` | `JS_GetContextPrivate` | `JS_GetContextOpaque` (L3739) | none: one context; its state lives in `OOJavaScriptEngine` | — |
| `setContextPrivate` | `JS_SetContextPrivate` | `JS_SetContextOpaque` (L3740) | none: as `getContextPrivate` | — |
| `beginRequest` | `JS_BeginRequest` | request-depth count that gates the arena flush (L3745) | none: QuickJS is single-threaded; `OOJSAcquireContext()` just returns the context | E.h:188 |
| `endRequest` | `JS_EndRequest` | decrements the depth (L3749) | none: `OOJSRelinquishContext()` is a no-op | E.h:195 |
| `isInRequest` | `JS_IsInRequest` | depth > 0 (L3755) | none: no requests | — |
| `isThreadsafeBuild` | `JS_THREADSAFE` build config | false (L3760) | none: no threads | — |
| `Request` | `JSAutoRequest` | RAII begin/end (header) | none: the `OOJSAcquireContext` / `OOJSRelinquishContext` pair, both trivial | E.h:188 |
| `ContextOption` | `JSOPTION_*` bits | stored in the context state; no engine effect (L3767) | none: no context options | — |
| `ContextOption::None` | 0 | stored | none | — |
| `ContextOption::Strict` | `JSOPTION_STRICT` | stored only | none: the console's `pedanticMode` is remembered without effect | `Debug/OOJSConsole.m:119` |
| `ContextOption::VarObjFix` | `JSOPTION_VAROBJFIX` | stored only | top-level `var`s are made script-local by the script wrapper (`OOJSWrapScriptSource`) | E.h:238 |
| `ContextOption::RegExpLimit` | `JSOPTION_RELIMIT` | stored only | none: no option | — |
| `ContextOption::AnonFunFix` | `JSOPTION_ANONFUNFIX` | stored only | none: no option | — |
| `ContextOption::Jit` | `JSOPTION_JIT` | stored only | none: no JIT | — |
| `ContextOption::MethodJit` | `JSOPTION_METHODJIT` | stored only | none: no JIT | — |
| `ContextOption::Profiling` | `JSOPTION_PROFILING` | stored only | none: native profiling by `OOJS_PROFILE` instead | E.h:79 |
| `setOptions` | `JS_SetOptions` | swaps the stored set (L3767) | none: no context options | — |
| `getOptions` | `JS_GetOptions` | the stored set (L3775) | none: no context options | — |
| `Version` | `JSVersion` | stored per context | none: no language versions; `oolite.jsVersion` is the constant 185 | `Scripting/OOJSOolite.m:44` |
| `Version::Unknown` | `JSVERSION_UNKNOWN` | -1 | none | — |
| `Version::Default` | `JSVERSION_DEFAULT` | 0 | none | — |
| `Version::ECMA5` | `JSVERSION_ECMA_5` | 185 | the constant 185 of `oolite.jsVersion` | `Scripting/OOJSOolite.m:44` |
| `Version::Latest` | `JSVERSION_LATEST` | 1000 | none | — |
| `setVersion` | `JS_SetVersion` | stored only (L3780) | none: no language versions | — |
| `getVersion` | `JS_GetVersion` | the stored version (L3788) | none: QuickJS's `JS_GetVersion()` is the engine version string | `Scripting/OOJSOolite.m:124` |
| `versionToString` | `JS_VersionToString` | static strings (L3793) | none: `oolite.jsVersionString` is "QuickJS-ng " + `JS_GetVersion()` | `Scripting/OOJSOolite.m:124` |
| `GCParam` | `JSGCParamKey` | dispatched per key | none: `JS_SetMemoryLimit` / `JS_ComputeMemoryUsage` directly | — |
| `GCParam::MaxBytes` | `JSGC_MAX_BYTES` | `JS_SetMemoryLimit` | `JS_SetMemoryLimit` (`jsruntime-size-mib`) | E.m:170 |
| `GCParam::MaxMallocBytes` | `JSGC_MAX_MALLOC_BYTES` | `JS_SetGCThreshold` | none: QuickJS's default threshold | — |
| `GCParam::Bytes` | `JSGC_BYTES` | `JS_ComputeMemoryUsage` `malloc_size` | `JS_ComputeMemoryUsage(rt, &u)`, `u.malloc_size` | `Debug/OOJSConsole.m:871` |
| `GCParam::NumberOfGCs` | `JSGC_NUMBER` | the backend's own counter | none | — |
| `getGCParameter` | `JS_GetGCParameter` | per key (L3810) | `JS_ComputeMemoryUsage` | `Debug/OODebugMonitor.m:576` |
| `setGCParameter` | `JS_SetGCParameter` | per key (L3833) | `JS_SetMemoryLimit` | E.m:170 |
| `gc` | `JS_GC` | arena flush when allowed, `JS_RunGC`, count (L3851) | `JS_RunGC(runtime)` | `Debug/OOJSConsole.m:882` |
| `setGCZeal` | `JS_SetGCZeal` | no-op (L3867) | none: no GC zeal | — |
| `gcZealSupported` | `JS_GC_ZEAL` build config | false (L3868) | none: no GC zeal | — |
| `maybeGC` | `JS_MaybeGC` | arena flush only (L3859) | none: `-garbageCollectionOpportunity:` acts only when forced; refcounting frees the rest | E.m:387 |
| `OperationCallback` | `JSOperationCallback` | called from `InterruptTramp` when the context's flag is set (L2444) | `JSInterruptHandler` `int (*)(JSRuntime*, void*)`; nonzero aborts uncatchably | E.m:640 |
| `setOperationCallback` | `JS_SetOperationCallback` | stores the callback (L3873) | `JS_SetInterruptHandler(runtime, InterruptHandler, NULL)` once, at init | E.m:172 |
| `triggerOperationCallback` | `JS_TriggerOperationCallback` | sets the context's atomic flag (L3881) | none: the handler polls the time limiter's clock; no watchdog thread | E.m:640 |
| `triggerAllOperationCallbacks` | `JS_TriggerAllOperationCallbacks` | flags every context (L3885) | none: as `triggerOperationCallback` | — |

## Completing the retarget

| Façade name | SpiderMonkey original | How JSEngine_quickjs.cpp implements it | #768's form for the same job | #768 example |
|---|---|---|---|---|
| `operator==` | `jsval` / `jsid` equality (`==` on the words) | bitwise, inline in the header | `JS_IsStrictEqual` for values; `==` for atoms | `Scripting/OOJSClasses.m:170` |
| `operator!=` | `jsval` / `jsid` inequality | bitwise, inline in the header | `!JS_IsStrictEqual` for values; `!=` for atoms | `Scripting/OOJSClasses.m:170` |
| `suspendRequest` | `JS_SuspendRequest` | returns 0 (L3895) | none: `OOJS_BEGIN_FULL_NATIVE` only pauses the time limiter | E.h:758 |
| `resumeRequest` | `JS_ResumeRequest` | no-op (L3896) | none: `OOJS_END_FULL_NATIVE` resumes the limiter | E.h:764 |
| `compareStrings` | `JS_CompareStrings` | UTF-16 comparison, sign of the result (L3898) | none: compare `NSString`s | — |
| `freezeObject` | `JS_FreezeObject` | `JS_Call` of `Object.freeze` (L3909) | `JS_FreezeObject(ctx, obj)` (QuickJS-ng API) | `Scripting/OOJSSpecialFunctions.m:62` |
| `compileUCFunction` | `JS_CompileUCFunction` | `evalWithThis` of `(function name(args) {\nbody\n})` at `lineno - 1` (L3924) | `JS_Eval2` of `(function(args){body\n})` with `JSEvalOptions{filename, line_num}` | `Scripting/OOJSFunction.m:118` |
| `callFunction` | `JS_CallFunction` | `callFunctionValue` (L3950) | `JS_Call` | `Scripting/OOJSFunction.m:224` |
| `bufferIsCompilableUnit` | `JS_BufferIsCompilableUnit` | compile-only `JS_EvalThis2`; false only for "end of input" style errors (L3956) | compile-only `JS_Eval` + `IsIncompleteSyntaxError` on the exception | `Debug/OOJSConsole.m:782` |
| `RegExpFoldCase` | `JSREG_FOLD` | 0x01, mapped to "i" (L3456) | "i" in the flag string (`kOORegExpCaseInsensitive`) | `OORegExpMatcher.m:111` |
| `RegExpGlobal` | `JSREG_GLOB` | 0x02, mapped to "g" | none: #768's matcher never asks for /g | — |
| `RegExpMultiline` | `JSREG_MULTILINE` | 0x04, mapped to "m" | "m" in the flag string (`kOORegExpMultiLine`) | `OORegExpMatcher.m:112` |
| `RegExpSticky` | `JSREG_STICKY` | 0x08, mapped to "y" | none: never used | — |

## Debugging and profiling

| Façade name | SpiderMonkey original | How JSEngine_quickjs.cpp implements it | #768's form for the same job | #768 example |
|---|---|---|---|---|
| `StackFrameRep` | `JSStackFrame` | 1-based index into a snapshot of `new Error().stack` (L3994-4030) | none: no frame objects; stack text from an `Error`'s `stack` | E.m:699 |
| `StackFrame` | `JSStackFrame*` | the index as a pointer | none: as `StackFrameRep` | E.m:699 |
| `frameIterator` | `JS_FrameIterator` | snapshot on the first call, then the next index (L4041) | none: `CurrentStack` parses a new `Error`'s stack text | E.m:699 |
| `frameIsScript` | `JS_IsScriptFrame` | index valid (L4053) | none: every parsed stack line is a script frame | — |
| `frameIsConstructor` | `JS_IsConstructorFrame` | false (L4056) | none: not available | — |
| `frameIsDebugger` | `JS_IsDebuggerFrame` | false (L4057) | none: not available | — |
| `frameScript` | `JS_GetFrameScript` | a per-filename token `ScriptRep` (L4058) | none: the file name is parsed from the stack line | E.m:699 |
| `scriptFilename` | `JS_GetScriptFilename` | the token's filename (L4069) | `JS_GetScriptOrModuleName(ctx, level)` (an atom) | E.m:298 |
| `frameLineNumber` | `JS_PCToLineNumber(JS_GetFrameScript, JS_GetFramePC)` | the parsed line (L4072) | parsed from the stack text | E.m:699 |
| `frameFunction` | `JS_GetFrameFunction` | null (L4076) | none: function names only as stack text | `Scripting/README.md:22` |
| `frameThis` | `JS_GetFrameThis` | false (L4077) | none: no `this` in stack dumps | `Scripting/README.md:22` |
| `frameScopeChain` | `JS_GetFrameScopeChain` | null (L4078) | none: no scope access | `Scripting/README.md:22` |
| `VariableFlag` | `JSPD_*` | unused: `getScopeVariables` returns false | none: no local-variable inspection | `Scripting/README.md:22` |
| `VariableFlag::None` | 0 | unused | none | — |
| `VariableFlag::Enumerate` | `JSPD_ENUMERATE` | unused | none | — |
| `VariableFlag::ReadOnly` | `JSPD_READONLY` | unused | none | — |
| `VariableFlag::Permanent` | `JSPD_PERMANENT` | unused | none | — |
| `VariableFlag::Alias` | `JSPD_ALIAS` | unused | none | — |
| `VariableFlag::Argument` | `JSPD_ARGUMENT` | unused | none | — |
| `VariableFlag::Variable` | `JSPD_VARIABLE` | unused | none | — |
| `VariableFlag::Exception` | `JSPD_EXCEPTION` | unused | none | — |
| `VariableFlag::Error` | `JSPD_ERROR` | unused | none | — |
| `Variable` | `JSPropertyDesc` | never filled | none: no local-variable inspection | `Scripting/README.md:22` |
| `Variable::id` | `.id` | never filled | none | — |
| `Variable::value` | `.value` | never filled | none | — |
| `Variable::flags` | `.flags` | never filled | none | — |
| `Variable::alias` | `.alias` | never filled | none | — |
| `VariableList` | `JSPropertyDescArray` | always empty | none: no local-variable inspection | `Scripting/README.md:22` |
| `VariableList::length` | `.length` | 0 | none | — |
| `VariableList::vars` | `.array` | nullptr | none | — |
| `VariableList::backend` | (no counterpart) | nullptr | none | — |
| `getScopeVariables` | `JS_GetPropertyDescArray` | returns false with an empty list (L4080) | none: not available | `Scripting/README.md:22` |
| `destroyScopeVariables` | `JS_PutPropertyDescArray` | no-op (L4086) | none | — |
| `DebuggerHandler` | `JSDebuggerHandler` | never called | none: QuickJS has no hook; `debugger` is a no-op | E.m:430 |
| `setDebuggerHandler` | `JS_SetDebuggerHandler` | no-op (L4089) | none: `-enableDebuggerStatement` does nothing | E.m:428 |
| `FunctionCallback` | `JSFunctionCallback` | never called | none: `OOJS_PROFILE_ENTER/EXIT` profile natives only | E.h:74 |
| `setFunctionCallback` | `JS_SetFunctionCallback` | returns false (L4090) | none: as `FunctionCallback` | E.h:79 |
| `ContextOp` | `JSCONTEXT_NEW` / `JSCONTEXT_DESTROY` | argument of the context callback | none: reset notifications instead | E.h:201 |
| `ContextOp::New` | `JSCONTEXT_NEW` | from `newContext` | `kOOJavaScriptEngineDidResetNotification` | E.h:202 |
| `ContextOp::Destroy` | `JSCONTEXT_DESTROY` | from `destroyContext` | `kOOJavaScriptEngineWillResetNotification` | E.h:201 |
| `ContextCallback` | `JSContextCallback` | a global hook called by `newContext` / `destroyContext` (L3675, L3696) | none: observers of the reset notifications | E.h:201 |
| `setContextCallback` | `JS_SetContextCallback` | swaps the hook (L4091) | none: `NSNotificationCenter` observers | `Scripting/EntityOOJavaScriptExtensions.m:61` |
| `RootKind` | `JS_GC_ROOT_VALUE_PTR` / `JS_GC_ROOT_GCTHING_PTR` | unused | none: no named roots | `Debug/OOJSConsole.m:58` |
| `RootKind::Value` | `JS_GC_ROOT_VALUE_PTR` | unused | none | — |
| `RootKind::GCThing` | `JS_GC_ROOT_GCTHING_PTR` | unused | none | — |
| `RootDumper` | `JSGCRootMapFun` | never called | none: no named roots | `Debug/OOJSConsole.m:58` |
| `dumpNamedRoots` | `JS_DumpNamedRoots` | returns false (L4097) | none: the console's `dumpNamedRoots()` was removed | `Debug/OOJSConsole.m:58` |
| `dumpHeap` | `JS_DumpHeap` | `JS_ComputeMemoryUsage` + `JS_DumpMemoryUsage` to the `FILE*` (L4098) | `JS_ComputeMemoryUsage` + `JS_DumpMemoryUsage` | `Debug/OOJSConsole.m:902` |

## Backend identity

| Façade name | SpiderMonkey original | How JSEngine_quickjs.cpp implements it | #768's form for the same job | #768 example |
|---|---|---|---|---|
| `backendName` | (the façade's own; no engine call) | "quickjs-ng-0.17.0" (L4110) | `JS_GetVersion()`, the engine's version string | `Scripting/OOJSOolite.m:124` |

## What has no #768 counterpart, and why it matters for the port

- **The handle arena and rooting** (`addNamed*Root`, `remove*Root`, `RootedObject`, `RootedValue`,
  `maybeGC`). The façade fakes SpiderMonkey's conservative stack scan: every handle holds an arena
  reference until a flush. #768 uses plain ownership instead. Every ported call site must be
  re-read for ownership; no mechanical rewrite exists.
- **Requests and context options** (`beginRequest` … `Request`, `ContextOption`, `Version`):
  bookkeeping only today; they disappear.
- **Class hooks** (`addProperty`, `resolve`, `enumerate`, `newEnumerate`, `convert`, `call`, and
  `EnumerateOp`): #768 replaces them with `JSClassExoticMethods` written per class and with
  `toString` methods. Each hooked class needs its own design.
- **Native identity** (`CallArgs::callee`, `rawVp`, `getFunctionNative`): no counterpart; any call
  site that uses them needs restructuring.
- **Frames, scope variables, debugger and function hooks, named roots, error-reporter objects**:
  #768 has stack text and a fixed logger only.
