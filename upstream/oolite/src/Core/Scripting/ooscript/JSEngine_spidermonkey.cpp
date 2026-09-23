/*

ooscript/JSEngine_spidermonkey.cpp

The SpiderMonkey 1.8.5 backend of the façade in JSEngine.hpp (Phase 1 seam 1.1, bead oo-e7c).
This is the only translation unit in the migration that includes jsapi.h on purpose; when the
QuickJS-ng backend lands (seam 1.3) it is the file that gets deleted.

How the façade's hook types reach the engine
	The engine calls back through plain C function pointers with no user-data argument, and the
	façade's hook signatures are not the engine's. A hook is therefore given an engine-side
	trampoline of its own: a pool of template instantiations, one slot per distinct façade
	function, so that two classes which reuse the same tinyids with different getters (Ship and
	PlayerShip do) stay as distinct to the engine as they are today. Natives need no pool: the
	engine passes the callee in vp[0], and a map from the callee's function to the façade native
	resolves the call. Neither mechanism inspects the receiver's class, so inheritance through
	prototypes behaves exactly as before.

Representation
	Value and PropertyId are byte copies of jsval and jsid; the static_asserts below are the
	contract. numberValue() reproduces JS_NewNumberValue's int32 canonicalisation rather than
	calling it, and the unit test checks the two agree bit for bit, because a double where the
	engine would have stored an int moves a golden.

Copyright (C) 2026 the Oolite migration project. GPL-2.0-or-later, as the rest of Oolite.

*/

#include "JSEngine.hpp"

#include <jsapi.h>
#include <jsdbgapi.h>
#include <jsxdrapi.h>

#include <array>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unordered_map>
#include <utility>
#include <vector>

namespace ooscript {

namespace {

static_assert(sizeof(Value) == sizeof(jsval), "ooscript::Value must be a byte copy of jsval");
static_assert(sizeof(PropertyId) == sizeof(jsid), "ooscript::PropertyId must be a byte copy of jsid");
static_assert(sizeof(Char16) == sizeof(jschar), "ooscript::Char16 must be the engine's code unit");
static_assert(alignof(Value) >= alignof(jsval), "Value alignment");

// MARK: Handle and value conversions ------------------------------------------------------------

inline JSContext*  CX(Context cx)       { return reinterpret_cast<JSContext*>(cx); }
inline Context     wrap(JSContext* cx)  { return reinterpret_cast<Context>(cx); }
inline JSRuntime*  RT(Runtime rt)       { return reinterpret_cast<JSRuntime*>(rt); }
inline Runtime     wrap(JSRuntime* rt)  { return reinterpret_cast<Runtime>(rt); }
inline JSObject*   OBJ(Object o)        { return reinterpret_cast<JSObject*>(o); }
inline Object      wrap(JSObject* o)    { return reinterpret_cast<Object>(o); }
inline JSString*   STR(String s)        { return reinterpret_cast<JSString*>(s); }
inline String      wrap(JSString* s)    { return reinterpret_cast<String>(s); }
inline JSFunction* FUN(Function f)      { return reinterpret_cast<JSFunction*>(f); }
inline Function    wrap(JSFunction* f)  { return reinterpret_cast<Function>(f); }

inline jsval toJS(Value v)              { jsval r; std::memcpy(&r, &v, sizeof r); return r; }
inline Value fromJS(jsval v)            { Value r; std::memcpy(&r, &v, sizeof r); return r; }
inline jsid  toJS(PropertyId id)        { jsid r; std::memcpy(&r, &id, sizeof r); return r; }
inline PropertyId fromJS(jsid id)       { PropertyId r; std::memcpy(&r, &id, sizeof r); return r; }

// In-place views. Value and jsval are trivially copyable 8-byte objects with identical layout;
// the engine writes through these pointers exactly as it writes through jsval*.
inline jsval*      JSVP(Value* vp)      { return reinterpret_cast<jsval*>(vp); }
inline Value*      VP(jsval* vp)        { return reinterpret_cast<Value*>(vp); }
inline JSObject**  OBJPP(Object* pp)    { return reinterpret_cast<JSObject**>(pp); }
inline JSString**  STRPP(String* pp)    { return reinterpret_cast<JSString**>(pp); }
inline const jschar*  JSCHARS(const Char16* s) { return reinterpret_cast<const jschar*>(s); }
inline const Char16*  CHARS(const jschar* s)   { return reinterpret_cast<const Char16*>(s); }

inline JSBool B(bool b)                 { return b ? JS_TRUE : JS_FALSE; }
inline uintN  attrs(PropertyFlag f)     { return static_cast<uintN>(static_cast<std::uint8_t>(f)); }

static_assert(static_cast<int>(PropertyFlag::Enumerate) == JSPROP_ENUMERATE, "PropertyFlag::Enumerate");
static_assert(static_cast<int>(PropertyFlag::ReadOnly)  == JSPROP_READONLY,  "PropertyFlag::ReadOnly");
static_assert(static_cast<int>(PropertyFlag::Permanent) == JSPROP_PERMANENT, "PropertyFlag::Permanent");
static_assert(static_cast<int>(PropertyFlag::Shared)    == JSPROP_SHARED,    "PropertyFlag::Shared");

[[noreturn]] void fatal(const char* what)
{
	std::fprintf(stderr, "ooscript/spidermonkey: %s\n", what);
	std::abort();
}

Type fromJS(JSType t)
{
	switch (t)
	{
		case JSTYPE_VOID:     return Type::Void;
		case JSTYPE_OBJECT:   return Type::Object;
		case JSTYPE_FUNCTION: return Type::Function;
		case JSTYPE_STRING:   return Type::String;
		case JSTYPE_NUMBER:   return Type::Number;
		case JSTYPE_BOOLEAN:  return Type::Boolean;
		case JSTYPE_NULL:     return Type::Null;
		case JSTYPE_XML:      return Type::XML;
		default:              return Type::Void;
	}
}

JSType toJS(Type t)
{
	switch (t)
	{
		case Type::Void:     return JSTYPE_VOID;
		case Type::Object:   return JSTYPE_OBJECT;
		case Type::Function: return JSTYPE_FUNCTION;
		case Type::String:   return JSTYPE_STRING;
		case Type::Number:   return JSTYPE_NUMBER;
		case Type::Boolean:  return JSTYPE_BOOLEAN;
		case Type::Null:     return JSTYPE_NULL;
		case Type::XML:      return JSTYPE_XML;
	}
	return JSTYPE_VOID;
}

// MARK: Trampoline pools ------------------------------------------------------------------------

// One engine-side function per distinct façade hook. A slot, once assigned, is never reused, so
// an engine class that captured a trampoline keeps its meaning for the life of the process.
template <typename Fn, std::size_t Slots>
struct Pool
{
	std::array<Fn, Slots>          fns{};
	std::unordered_map<Fn, std::size_t> slotOf;
	std::size_t                    used = 0;
	const char*                    what;

	explicit Pool(const char* name) : what(name) {}

	std::size_t slot(Fn fn)
	{
		auto it = slotOf.find(fn);
		if (it != slotOf.end())  return it->second;
		if (used == Slots)
		{
			char buf[128];
			std::snprintf(buf, sizeof buf, "trampoline pool exhausted for %s (%zu slots); raise kSlots", what, Slots);
			fatal(buf);
		}
		fns[used] = fn;
		slotOf.emplace(fn, used);
		return used++;
	}
};

constexpr std::size_t kSlots = 256;

Pool<PropertyGetter,   kSlots> gGetters("property getters");
Pool<PropertySetter,   kSlots> gSetters("property setters");
Pool<EnumerateHook,    kSlots> gEnumerators("enumerate hooks");
Pool<NewEnumerateHook, kSlots> gNewEnumerators("new-enumerate hooks");
Pool<ResolveHook,      kSlots> gResolvers("resolve hooks");
Pool<ConvertHook,      kSlots> gConverters("convert hooks");
Pool<FinalizeHook,     kSlots> gFinalizers("finalize hooks");

template <std::size_t N> struct GetterTramp
{
	static JSBool fn(JSContext* cx, JSObject* obj, jsid id, jsval* vp)
	{
		return B(gGetters.fns[N](wrap(cx), wrap(obj), fromJS(id), VP(vp)));
	}
};
template <std::size_t N> struct SetterTramp
{
	static JSBool fn(JSContext* cx, JSObject* obj, jsid id, JSBool strict, jsval* vp)
	{
		return B(gSetters.fns[N](wrap(cx), wrap(obj), fromJS(id), strict != JS_FALSE, VP(vp)));
	}
};
template <std::size_t N> struct EnumerateTramp
{
	static JSBool fn(JSContext* cx, JSObject* obj)
	{
		return B(gEnumerators.fns[N](wrap(cx), wrap(obj)));
	}
};
template <std::size_t N> struct NewEnumerateTramp
{
	static JSBool fn(JSContext* cx, JSObject* obj, JSIterateOp op, jsval* statep, jsid* idp)
	{
		EnumerateOp eop = EnumerateOp::Init;
		switch (op)
		{
			case JSENUMERATE_INIT:     eop = EnumerateOp::Init;    break;
			case JSENUMERATE_INIT_ALL: eop = EnumerateOp::InitAll; break;
			case JSENUMERATE_NEXT:     eop = EnumerateOp::Next;    break;
			case JSENUMERATE_DESTROY:  eop = EnumerateOp::Destroy; break;
		}
		return B(gNewEnumerators.fns[N](wrap(cx), wrap(obj), eop, VP(statep), reinterpret_cast<PropertyId*>(idp)));
	}
};
template <std::size_t N> struct ResolveTramp
{
	static JSBool fn(JSContext* cx, JSObject* obj, jsid id)
	{
		return B(gResolvers.fns[N](wrap(cx), wrap(obj), fromJS(id)));
	}
};
template <std::size_t N> struct ConvertTramp
{
	static JSBool fn(JSContext* cx, JSObject* obj, JSType hint, jsval* vp)
	{
		return B(gConverters.fns[N](wrap(cx), wrap(obj), fromJS(hint), VP(vp)));
	}
};
template <std::size_t N> struct FinalizeTramp
{
	static void fn(JSContext* cx, JSObject* obj)
	{
		gFinalizers.fns[N](wrap(cx), wrap(obj));
	}
};

template <typename EngineFn, template <std::size_t> class Tramp, std::size_t... I>
constexpr std::array<EngineFn, sizeof...(I)> makeTable(std::index_sequence<I...>)
{
	return {{ &Tramp<I>::fn... }};
}

const auto gGetterTable       = makeTable<JSPropertyOp,       GetterTramp>      (std::make_index_sequence<kSlots>{});
const auto gSetterTable       = makeTable<JSStrictPropertyOp, SetterTramp>      (std::make_index_sequence<kSlots>{});
const auto gEnumerateTable    = makeTable<JSEnumerateOp,      EnumerateTramp>   (std::make_index_sequence<kSlots>{});
const auto gNewEnumerateTable = makeTable<JSNewEnumerateOp,   NewEnumerateTramp>(std::make_index_sequence<kSlots>{});
const auto gResolveTable      = makeTable<JSResolveOp,        ResolveTramp>     (std::make_index_sequence<kSlots>{});
const auto gConvertTable      = makeTable<JSConvertOp,        ConvertTramp>     (std::make_index_sequence<kSlots>{});
const auto gFinalizeTable     = makeTable<JSFinalizeOp,       FinalizeTramp>    (std::make_index_sequence<kSlots>{});

JSPropertyOp       getterFor(PropertyGetter g)     { return g ? gGetterTable[gGetters.slot(g)] : nullptr; }
JSStrictPropertyOp setterFor(PropertySetter s)     { return s ? gSetterTable[gSetters.slot(s)] : nullptr; }

// MARK: Natives ---------------------------------------------------------------------------------

// Callee function -> façade native. Entries are added when a function is defined and live as long
// as the process: Oolite defines every native at start-up on objects that live until exit.
std::unordered_map<JSFunction*, NativeFn> gNatives;

JSBool NativeTramp(JSContext* cx, uintN argc, jsval* vp)
{
	JSFunction* fn = JS_ValueToFunction(cx, JS_CALLEE(cx, vp));
	auto it = fn ? gNatives.find(fn) : gNatives.end();
	if (it == gNatives.end())
	{
		JS_ReportError(cx, "ooscript: native function is not registered with the façade");
		return JS_FALSE;
	}
	CallArgs args(wrap(cx), argc, VP(vp));
	return B(it->second(wrap(cx), args));
}

void registerNative(JSFunction* fn, NativeFn call)
{
	if (fn && call)  gNatives[fn] = call;
}

// MARK: Classes ---------------------------------------------------------------------------------

// The engine-side class for a façade ClassDef. JSClass is the first member and the struct is
// standard-layout, so a JSClass* the engine hands back converts to its BackendClass*.
struct BackendClass
{
	JSClass   clasp;
	ClassDef* def;
};
static_assert(offsetof(BackendClass, clasp) == 0, "JSClass must be the first member of BackendClass");

std::unordered_map<const JSClass*, BackendClass*> gClasses;

BackendClass* backendFor(const JSClass* clasp)
{
	auto it = gClasses.find(clasp);
	return it == gClasses.end() ? nullptr : it->second;
}

JSBool ClassCallTramp(JSContext* cx, uintN argc, jsval* vp)
{
	JSObject* callee = JSVAL_TO_OBJECT(JS_CALLEE(cx, vp));
	BackendClass* bc = backendFor(JS_GetClass(cx, callee));
	if (bc == nullptr || bc->def->call == nullptr)
	{
		JS_ReportError(cx, "ooscript: object is not callable");
		return JS_FALSE;
	}
	CallArgs args(wrap(cx), argc, VP(vp));
	return B(bc->def->call(wrap(cx), args));
}

JSBool ClassConstructTramp(JSContext* cx, uintN argc, jsval* vp)
{
	JSObject* callee = JSVAL_TO_OBJECT(JS_CALLEE(cx, vp));
	BackendClass* bc = backendFor(JS_GetClass(cx, callee));
	if (bc == nullptr || bc->def->construct == nullptr)
	{
		JS_ReportError(cx, "ooscript: object is not a constructor");
		return JS_FALSE;
	}
	CallArgs args(wrap(cx), argc, VP(vp));
	return B(bc->def->construct(wrap(cx), args));
}

BackendClass* attach(ClassDef* def)
{
	if (def == nullptr)  return nullptr;
	if (def->backend != nullptr)  return static_cast<BackendClass*>(def->backend);

	BackendClass* bc = new BackendClass{};
	bc->def = def;
	JSClass& c = bc->clasp;
	c.name  = def->name;
	c.flags = 0;
	const auto flags = static_cast<std::uint32_t>(def->flags);
	if (flags & static_cast<std::uint32_t>(ClassFlag::HasPrivate))    c.flags |= JSCLASS_HAS_PRIVATE;
	if (flags & static_cast<std::uint32_t>(ClassFlag::NewEnumerate))  c.flags |= JSCLASS_NEW_ENUMERATE;
	if (flags & static_cast<std::uint32_t>(ClassFlag::Global))        c.flags |= JSCLASS_GLOBAL_FLAGS;

	c.addProperty = def->addProperty ? gGetterTable[gGetters.slot(def->addProperty)] : JS_PropertyStub;
	c.delProperty = def->delProperty ? gGetterTable[gGetters.slot(def->delProperty)] : JS_PropertyStub;
	c.getProperty = def->getProperty ? gGetterTable[gGetters.slot(def->getProperty)] : JS_PropertyStub;
	c.setProperty = def->setProperty ? gSetterTable[gSetters.slot(def->setProperty)] : JS_StrictPropertyStub;
	if (flags & static_cast<std::uint32_t>(ClassFlag::NewEnumerate))
	{
		if (def->newEnumerate == nullptr)  fatal("ClassFlag::NewEnumerate set without a newEnumerate hook");
		// The engine's own convention: with JSCLASS_NEW_ENUMERATE the `enumerate` slot holds a
		// JSNewEnumerateOp and the engine casts it back. Copy the pointer bits rather than cast
		// between the two function types.
		const JSNewEnumerateOp newEnum = gNewEnumerateTable[gNewEnumerators.slot(def->newEnumerate)];
		static_assert(sizeof newEnum == sizeof c.enumerate, "function pointer sizes");
		std::memcpy(&c.enumerate, &newEnum, sizeof c.enumerate);
	}
	else
	{
		c.enumerate = def->enumerate ? gEnumerateTable[gEnumerators.slot(def->enumerate)] : JS_EnumerateStub;
	}
	c.resolve   = def->resolve  ? gResolveTable[gResolvers.slot(def->resolve)]    : JS_ResolveStub;
	c.convert   = def->convert  ? gConvertTable[gConverters.slot(def->convert)]   : JS_ConvertStub;
	c.finalize  = def->finalize ? gFinalizeTable[gFinalizers.slot(def->finalize)] : JS_FinalizeStub;
	c.call      = def->call      ? ClassCallTramp      : nullptr;
	c.construct = def->construct ? ClassConstructTramp : nullptr;

	gClasses.emplace(&c, bc);
	def->backend = bc;
	return bc;
}

JSClass* claspFor(ClassDef* def)
{
	BackendClass* bc = attach(def);
	return bc ? &bc->clasp : nullptr;
}

std::vector<JSPropertySpec> convertSpecs(const PropertySpec* ps)
{
	std::vector<JSPropertySpec> out;
	for (; ps != nullptr && ps->name != nullptr; ++ps)
	{
		JSPropertySpec s{};
		s.name   = ps->name;
		s.tinyid = ps->tinyid;
		s.flags  = static_cast<uint8>(ps->flags);
		s.getter = getterFor(ps->getter);
		s.setter = setterFor(ps->setter);
		out.push_back(s);
	}
	out.push_back(JSPropertySpec{});   // terminator
	return out;
}

bool defineFunctionSpecs(JSContext* cx, JSObject* obj, const FunctionSpec* fs)
{
	for (; fs != nullptr && fs->name != nullptr; ++fs)
	{
		JSFunction* fn = JS_DefineFunction(cx, obj, fs->name, NativeTramp, fs->nargs, fs->flags);
		if (fn == nullptr)  return false;
		registerNative(fn, fs->call);
	}
	return true;
}

// MARK: Per-context state ----------------------------------------------------------------------

struct ContextExtras
{
	ErrorReporter     reporter = nullptr;
	OperationCallback opcb     = nullptr;
};
std::unordered_map<JSContext*, ContextExtras> gExtras;

void ErrorReporterTramp(JSContext* cx, const char* message, JSErrorReport* report)
{
	auto it = gExtras.find(cx);
	if (it == gExtras.end() || it->second.reporter == nullptr)  return;
	ErrorReport r{};
	if (report != nullptr)
	{
		r.filename    = report->filename;
		r.lineno      = report->lineno;
		r.flags       = report->flags;
		r.errorNumber = report->errorNumber;
		r.ucmessage   = CHARS(report->ucmessage);
		r.linebuf     = CHARS(reinterpret_cast<const jschar*>(report->uclinebuf));
	}
	it->second.reporter(wrap(cx), message, report != nullptr ? &r : nullptr);
}

JSBool OperationCallbackTramp(JSContext* cx)
{
	auto it = gExtras.find(cx);
	if (it == gExtras.end() || it->second.opcb == nullptr)  return JS_TRUE;
	return B(it->second.opcb(wrap(cx)));
}

uint32 optionBits(ContextOption o)
{
	const auto v = static_cast<std::uint32_t>(o);
	uint32 bits = 0;
	if (v & static_cast<std::uint32_t>(ContextOption::Strict))      bits |= JSOPTION_STRICT;
	if (v & static_cast<std::uint32_t>(ContextOption::VarObjFix))   bits |= JSOPTION_VAROBJFIX;
	if (v & static_cast<std::uint32_t>(ContextOption::RegExpLimit)) bits |= JSOPTION_RELIMIT;
	if (v & static_cast<std::uint32_t>(ContextOption::AnonFunFix))  bits |= JSOPTION_ANONFUNFIX;
	if (v & static_cast<std::uint32_t>(ContextOption::Jit))         bits |= JSOPTION_JIT;
	if (v & static_cast<std::uint32_t>(ContextOption::MethodJit))   bits |= JSOPTION_METHODJIT;
	if (v & static_cast<std::uint32_t>(ContextOption::Profiling))   bits |= JSOPTION_PROFILING;
	return bits;
}

ContextOption optionsFrom(uint32 bits)
{
	std::uint32_t v = 0;
	if (bits & JSOPTION_STRICT)     v |= static_cast<std::uint32_t>(ContextOption::Strict);
	if (bits & JSOPTION_VAROBJFIX)  v |= static_cast<std::uint32_t>(ContextOption::VarObjFix);
	if (bits & JSOPTION_RELIMIT)    v |= static_cast<std::uint32_t>(ContextOption::RegExpLimit);
	if (bits & JSOPTION_ANONFUNFIX) v |= static_cast<std::uint32_t>(ContextOption::AnonFunFix);
	if (bits & JSOPTION_JIT)        v |= static_cast<std::uint32_t>(ContextOption::Jit);
	if (bits & JSOPTION_METHODJIT)  v |= static_cast<std::uint32_t>(ContextOption::MethodJit);
	if (bits & JSOPTION_PROFILING)  v |= static_cast<std::uint32_t>(ContextOption::Profiling);
	return static_cast<ContextOption>(v);
}

JSVersion toJS(Version v)
{
	switch (v)
	{
		case Version::Unknown: return JSVERSION_UNKNOWN;
		case Version::Default: return JSVERSION_DEFAULT;
		case Version::ECMA5:   return JSVERSION_ECMA_5;
		case Version::Latest:  return JSVERSION_LATEST;
	}
	return JSVERSION_UNKNOWN;
}

Version fromJS(JSVersion v)
{
	switch (v)
	{
		case JSVERSION_DEFAULT: return Version::Default;
		case JSVERSION_ECMA_5:  return Version::ECMA5;
		default:                return v == JSVERSION_UNKNOWN ? Version::Unknown : Version::Latest;
	}
}

JSGCParamKey toJS(GCParam k)
{
	switch (k)
	{
		case GCParam::MaxBytes:       return JSGC_MAX_BYTES;
		case GCParam::MaxMallocBytes: return JSGC_MAX_MALLOC_BYTES;
		case GCParam::Bytes:          return JSGC_BYTES;
		case GCParam::NumberOfGCs:    return JSGC_NUMBER;
	}
	return JSGC_BYTES;
}

} // namespace

// MARK: Value construction and inspection ------------------------------------------------------

Value undefinedValue()            { return fromJS(JSVAL_VOID); }
Value nullValue()                 { return fromJS(JSVAL_NULL); }
Value booleanValue(bool b)        { return fromJS(BOOLEAN_TO_JSVAL(B(b))); }
Value trueValue()                 { return fromJS(JSVAL_TRUE); }
Value falseValue()                { return fromJS(JSVAL_FALSE); }
Value int32Value(std::int32_t i)  { return fromJS(INT_TO_JSVAL(i)); }
Value objectValue(Object obj)     { return fromJS(OBJECT_TO_JSVAL(OBJ(obj))); }
Value stringValue(String str)     { return fromJS(STRING_TO_JSVAL(STR(str))); }
Value privateValue(void* p)       { return fromJS(PRIVATE_TO_JSVAL(p)); }

Value numberValue(double d)
{
	// JS_NewNumberValue stores an int32 when the double is one (and is not -0), else a double
	// with NaN canonicalised. DOUBLE_TO_JSVAL canonicalises; the int32 test is reproduced here.
	const std::int32_t i = static_cast<std::int32_t>(d);
	if (static_cast<double>(i) == d && !(d == 0.0 && std::signbit(d)))
	{
		return fromJS(INT_TO_JSVAL(i));
	}
	return fromJS(DOUBLE_TO_JSVAL(d));
}

bool isUndefined(Value v)         { return JSVAL_IS_VOID(toJS(v)); }
bool isNull(Value v)              { return JSVAL_IS_NULL(toJS(v)); }
bool isNullOrUndefined(Value v)   { const jsval j = toJS(v); return JSVAL_IS_NULL(j) || JSVAL_IS_VOID(j); }
bool isObjectOrNull(Value v)      { return JSVAL_IS_OBJECT(toJS(v)); }
bool isObject(Value v)            { const jsval j = toJS(v); return JSVAL_IS_OBJECT(j) && !JSVAL_IS_NULL(j); }
bool isString(Value v)            { return JSVAL_IS_STRING(toJS(v)); }
bool isInt32(Value v)             { return JSVAL_IS_INT(toJS(v)); }
bool isDouble(Value v)            { return JSVAL_IS_DOUBLE(toJS(v)); }
bool isNumber(Value v)            { return JSVAL_IS_NUMBER(toJS(v)); }
bool isBoolean(Value v)           { return JSVAL_IS_BOOLEAN(toJS(v)); }
bool isPrimitive(Value v)         { return JSVAL_IS_PRIMITIVE(toJS(v)); }

Object       toObject(Value v)    { return wrap(JSVAL_TO_OBJECT(toJS(v))); }
String       toString(Value v)    { return wrap(JSVAL_TO_STRING(toJS(v))); }
std::int32_t toInt32(Value v)     { return JSVAL_TO_INT(toJS(v)); }
double       toDouble(Value v)    { return JSVAL_TO_DOUBLE(toJS(v)); }
bool         toBoolean(Value v)   { return JSVAL_TO_BOOLEAN(toJS(v)) != JS_FALSE; }
void*        toPrivate(Value v)   { return JSVAL_TO_PRIVATE(toJS(v)); }

bool newNumberValue(Context cx, double d, Value* rval)   { return JS_NewNumberValue(CX(cx), d, JSVP(rval)) != JS_FALSE; }
bool valueToNumber(Context cx, Value v, double* out)     { return JS_ValueToNumber(CX(cx), toJS(v), out) != JS_FALSE; }
bool valueToBoolean(Context cx, Value v, bool* out)
{
	JSBool b = JS_FALSE;
	if (!JS_ValueToBoolean(CX(cx), toJS(v), &b))  return false;
	*out = b != JS_FALSE;
	return true;
}
bool valueToObject(Context cx, Value v, Object* out)     { return JS_ValueToObject(CX(cx), toJS(v), OBJPP(out)) != JS_FALSE; }
bool valueToInt32(Context cx, Value v, std::int32_t* out)
{
	int32 i = 0;
	if (!JS_ValueToInt32(CX(cx), toJS(v), &i))  return false;
	*out = i;
	return true;
}
bool valueToECMAInt32(Context cx, Value v, std::int32_t* out)
{
	int32 i = 0;
	if (!JS_ValueToECMAInt32(CX(cx), toJS(v), &i))  return false;
	*out = i;
	return true;
}
bool valueToECMAUint32(Context cx, Value v, std::uint32_t* out)
{
	uint32 u = 0;
	if (!JS_ValueToECMAUint32(CX(cx), toJS(v), &u))  return false;
	*out = u;
	return true;
}
String   valueToString(Context cx, Value v)              { return wrap(JS_ValueToString(CX(cx), toJS(v))); }
Function valueToFunction(Context cx, Value v)            { return wrap(JS_ValueToFunction(CX(cx), toJS(v))); }
bool     valueToId(Context cx, Value v, PropertyId* out) { return JS_ValueToId(CX(cx), toJS(v), reinterpret_cast<jsid*>(out)) != JS_FALSE; }
bool     idToValue(Context cx, PropertyId id, Value* out){ return JS_IdToValue(CX(cx), toJS(id), JSVP(out)) != JS_FALSE; }
Type     typeOfValue(Context cx, Value v)                { return fromJS(JS_TypeOfValue(CX(cx), toJS(v))); }
const char* typeName(Type t)                             { return JS_GetTypeName(nullptr, toJS(t)); }

// MARK: Property ids ----------------------------------------------------------------------------

PropertyId   int32Id(std::int32_t i)    { return fromJS(INT_TO_JSID(i)); }
PropertyId   voidId()                   { return fromJS(JSID_VOID); }
bool         isInt32Id(PropertyId id)   { return JSID_IS_INT(toJS(id)); }
bool         isStringId(PropertyId id)  { return JSID_IS_STRING(toJS(id)); }
bool         isVoidId(PropertyId id)    { return JSID_IS_VOID(toJS(id)); }
std::int32_t idToInt32(PropertyId id)   { return JSID_TO_INT(toJS(id)); }
String       idToString(PropertyId id)  { return wrap(JSID_TO_STRING(toJS(id))); }
bool         idsEqual(PropertyId a, PropertyId b) { return a.bits == b.bits; }

// MARK: Call arguments --------------------------------------------------------------------------

Object CallArgs::thisObject() const     { return wrap(JS_THIS_OBJECT(CX(cx_), JSVP(vp_))); }
bool   CallArgs::isConstructing() const { return JS_IsConstructing(CX(cx_), JSVP(vp_)) != JS_FALSE; }

// MARK: Objects ---------------------------------------------------------------------------------

Object newObject(Context cx, ClassDef* def, Object proto, Object parent)
{
	return wrap(JS_NewObject(CX(cx), claspFor(def), OBJ(proto), OBJ(parent)));
}

Object newGlobalObject(Context cx, ClassDef* def)
{
	return wrap(JS_NewCompartmentAndGlobalObject(CX(cx), claspFor(def), nullptr));
}

void setGlobalObject(Context cx, Object global)
{
	JS_SetGlobalObject(CX(cx), OBJ(global));
}

bool initStandardClasses(Context cx, Object global)
{
	return JS_InitStandardClasses(CX(cx), OBJ(global)) != JS_FALSE;
}

void clearScope(Context cx, Object obj)
{
	JS_ClearScope(CX(cx), OBJ(obj));
}

Object initClass(Context cx, Object obj, Object parentProto, ClassDef* def,
                 NativeFn constructor, unsigned nargs,
                 const PropertySpec* ps, const FunctionSpec* fs,
                 const PropertySpec* staticPs, const FunctionSpec* staticFs)
{
	JSContext* jcx = CX(cx);
	std::vector<JSPropertySpec> jps  = convertSpecs(ps);
	std::vector<JSPropertySpec> jsps = convertSpecs(staticPs);
	// Functions are defined one by one below so each callee can be registered; passing them to
	// JS_InitClass would define them without handing back the JSFunction.
	JSObject* proto = JS_InitClass(jcx, OBJ(obj), OBJ(parentProto), claspFor(def),
	                               constructor ? NativeTramp : nullptr, nargs,
	                               ps ? jps.data() : nullptr, nullptr,
	                               staticPs ? jsps.data() : nullptr, nullptr);
	if (proto == nullptr)  return nullptr;
	if (constructor != nullptr)
	{
		JSObject* ctor = JS_GetConstructor(jcx, proto);
		registerNative(ctor ? JS_ValueToFunction(jcx, OBJECT_TO_JSVAL(ctor)) : nullptr, constructor);
	}
	if (!defineFunctionSpecs(jcx, proto, fs))  return nullptr;
	if (staticFs != nullptr)
	{
		JSObject* ctor = JS_GetConstructor(jcx, proto);
		if (ctor == nullptr || !defineFunctionSpecs(jcx, ctor, staticFs))  return nullptr;
	}
	return wrap(proto);
}

Object defineObject(Context cx, Object obj, const char* name, ClassDef* def, Object proto, PropertyFlag flags)
{
	return wrap(JS_DefineObject(CX(cx), OBJ(obj), name, claspFor(def), OBJ(proto), attrs(flags)));
}

Object getConstructor(Context cx, Object proto)       { return wrap(JS_GetConstructor(CX(cx), OBJ(proto))); }
Object getPrototype(Context cx, Object obj)           { return wrap(JS_GetPrototype(CX(cx), OBJ(obj))); }
Object getParent(Context cx, Object obj)              { return wrap(JS_GetParent(CX(cx), OBJ(obj))); }
Object getGlobalObject(Context cx)                    { return wrap(JS_GetGlobalObject(CX(cx))); }
Object getGlobalForObject(Context cx, Object obj)     { return wrap(JS_GetGlobalForObject(CX(cx), OBJ(obj))); }

const ClassDef* getClass(Context cx, Object obj)
{
	JSClass* clasp = JS_GetClass(CX(cx), OBJ(obj));
	if (clasp == nullptr)  return nullptr;
	BackendClass* bc = backendFor(clasp);
	if (bc != nullptr)  return bc->def;
	// One of the engine's own classes (Object, Array, String, ...): a stable descriptor per engine
	// class, so callers can key on it and read its name exactly as they keyed on the engine's class
	// pointer (bead oo-1gc.3). Every hook is nullptr; it is never attached to anything.
	static std::unordered_map<JSClass*, ClassDef*> sForeign;
	ClassDef*& def = sForeign[clasp];
	if (def == nullptr)  def = new ClassDef { clasp->name, ClassFlag::None, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr };
	return def;
}

bool  instanceOf(Context cx, Object obj, ClassDef* def, Value* argv)
{
	return JS_InstanceOf(CX(cx), OBJ(obj), claspFor(def), JSVP(argv)) != JS_FALSE;
}
bool  setPrivate(Context cx, Object obj, void* data)  { return JS_SetPrivate(CX(cx), OBJ(obj), data) != JS_FALSE; }
void* getPrivate(Context cx, Object obj)              { return JS_GetPrivate(CX(cx), OBJ(obj)); }
void* getInstancePrivate(Context cx, Object obj, ClassDef* def, Value* argv)
{
	return JS_GetInstancePrivate(CX(cx), OBJ(obj), claspFor(def), JSVP(argv));
}
bool objectIsFunction(Context cx, Object obj)         { return JS_ObjectIsFunction(CX(cx), OBJ(obj)) != JS_FALSE; }

bool getProperty(Context cx, Object obj, const char* name, Value* vp)        { return JS_GetProperty(CX(cx), OBJ(obj), name, JSVP(vp)) != JS_FALSE; }
bool setProperty(Context cx, Object obj, const char* name, Value* vp)        { return JS_SetProperty(CX(cx), OBJ(obj), name, JSVP(vp)) != JS_FALSE; }
bool getPropertyById(Context cx, Object obj, PropertyId id, Value* vp)       { return JS_GetPropertyById(CX(cx), OBJ(obj), toJS(id), JSVP(vp)) != JS_FALSE; }
bool setPropertyById(Context cx, Object obj, PropertyId id, Value* vp)       { return JS_SetPropertyById(CX(cx), OBJ(obj), toJS(id), JSVP(vp)) != JS_FALSE; }
bool definePropertyById(Context cx, Object obj, PropertyId id, Value value,
                        PropertyGetter getter, PropertySetter setter, PropertyFlag flags)
{
	return JS_DefinePropertyById(CX(cx), OBJ(obj), toJS(id), toJS(value), getterFor(getter), setterFor(setter), attrs(flags)) != JS_FALSE;
}
bool lookupProperty(Context cx, Object obj, const char* name, Value* vp)     { return JS_LookupProperty(CX(cx), OBJ(obj), name, JSVP(vp)) != JS_FALSE; }
bool lookupPropertyById(Context cx, Object obj, PropertyId id, Value* vp)    { return JS_LookupPropertyById(CX(cx), OBJ(obj), toJS(id), JSVP(vp)) != JS_FALSE; }
bool hasProperty(Context cx, Object obj, const char* name, bool* found)
{
	JSBool f = JS_FALSE;
	if (!JS_HasProperty(CX(cx), OBJ(obj), name, &f))  return false;
	*found = f != JS_FALSE;
	return true;
}
bool deleteProperty(Context cx, Object obj, const char* name)                { return JS_DeleteProperty(CX(cx), OBJ(obj), name) != JS_FALSE; }
bool getMethodById(Context cx, Object obj, PropertyId id, Object* objp, Value* vp)
{
	return JS_GetMethodById(CX(cx), OBJ(obj), toJS(id), OBJPP(objp), JSVP(vp)) != JS_FALSE;
}
bool defineProperty(Context cx, Object obj, const char* name, Value value,
                    PropertyGetter getter, PropertySetter setter, PropertyFlag flags)
{
	return JS_DefineProperty(CX(cx), OBJ(obj), name, toJS(value), getterFor(getter), setterFor(setter), attrs(flags)) != JS_FALSE;
}
bool defineProperties(Context cx, Object obj, const PropertySpec* ps)
{
	std::vector<JSPropertySpec> jps = convertSpecs(ps);
	return JS_DefineProperties(CX(cx), OBJ(obj), jps.data()) != JS_FALSE;
}
Function defineFunction(Context cx, Object obj, const char* name, NativeFn call, unsigned nargs, PropertyFlag flags)
{
	JSFunction* fn = JS_DefineFunction(CX(cx), OBJ(obj), name, NativeTramp, nargs, attrs(flags));
	registerNative(fn, call);
	return wrap(fn);
}
bool defineFunctions(Context cx, Object obj, const FunctionSpec* fs)         { return defineFunctionSpecs(CX(cx), OBJ(obj), fs); }

bool   setElement(Context cx, Object obj, std::int32_t index, Value* vp)     { return JS_SetElement(CX(cx), OBJ(obj), index, JSVP(vp)) != JS_FALSE; }
bool   getElement(Context cx, Object obj, std::int32_t index, Value* vp)     { return JS_GetElement(CX(cx), OBJ(obj), index, JSVP(vp)) != JS_FALSE; }
bool   lookupElement(Context cx, Object obj, std::int32_t index, Value* vp)  { return JS_LookupElement(CX(cx), OBJ(obj), index, JSVP(vp)) != JS_FALSE; }
Object newArrayObject(Context cx, std::int32_t length, Value* vector)        { return wrap(JS_NewArrayObject(CX(cx), length, JSVP(vector))); }
bool   isArrayObject(Context cx, Object obj)                                 { return JS_IsArrayObject(CX(cx), OBJ(obj)) != JS_FALSE; }
bool   getArrayLength(Context cx, Object obj, std::uint32_t* length)
{
	jsuint n = 0;
	if (!JS_GetArrayLength(CX(cx), OBJ(obj), &n))  return false;
	*length = n;
	return true;
}
bool   setArrayLength(Context cx, Object obj, std::uint32_t length)          { return JS_SetArrayLength(CX(cx), OBJ(obj), length) != JS_FALSE; }

IdArray* enumerate(Context cx, Object obj)
{
	JSIdArray* ida = JS_Enumerate(CX(cx), OBJ(obj));
	if (ida == nullptr)  return nullptr;
	IdArray* out = new IdArray{};
	out->length  = static_cast<std::size_t>(ida->length);
	out->ids     = reinterpret_cast<PropertyId*>(ida->vector);
	out->backend = ida;
	return out;
}
void destroyIdArray(Context cx, IdArray* ida)
{
	if (ida == nullptr)  return;
	JS_DestroyIdArray(CX(cx), static_cast<JSIdArray*>(ida->backend));
	delete ida;
}

String   getFunctionId(Function fn)                   { return wrap(JS_GetFunctionId(FUN(fn))); }
Object   getFunctionObject(Function fn)               { return wrap(JS_GetFunctionObject(FUN(fn))); }
NativeFn getFunctionNative(Context /*cx*/, Function fn)
{
	// Only functions defined through the façade are registered; the engine's own natives and
	// script functions answer nullptr, which is the one distinction the callers draw.
	auto it = gNatives.find(FUN(fn));
	return it == gNatives.end() ? nullptr : it->second;
}
bool callFunctionValue(Context cx, Object thisObj, Value fn, unsigned argc, Value* argv, Value* rval)
{
	return JS_CallFunctionValue(CX(cx), OBJ(thisObj), toJS(fn), argc, JSVP(argv), JSVP(rval)) != JS_FALSE;
}
bool callFunctionName(Context cx, Object thisObj, const char* name, unsigned argc, Value* argv, Value* rval)
{
	return JS_CallFunctionName(CX(cx), OBJ(thisObj), name, argc, JSVP(argv), JSVP(rval)) != JS_FALSE;
}

bool evaluateScript(Context cx, Object scope, const char* src, unsigned length, const char* filename, unsigned lineno, Value* rval)
{
	return JS_EvaluateScript(CX(cx), OBJ(scope), src, length, filename, lineno, JSVP(rval)) != JS_FALSE;
}
bool evaluateUCScript(Context cx, Object scope, const Char16* src, unsigned length, const char* filename, unsigned lineno, Value* rval)
{
	return JS_EvaluateUCScript(CX(cx), OBJ(scope), JSCHARS(src), length, filename, lineno, JSVP(rval)) != JS_FALSE;
}

// MARK: Scripts -----------------------------------------------------------------------------

inline JSScript* SCR(Script s)      { return reinterpret_cast<JSScript*>(s); }
inline Script    wrap(JSScript* s)  { return reinterpret_cast<Script>(s); }

Script compileUCScript(Context cx, Object scope, const Char16* src, unsigned length, const char* filename, unsigned lineno)
{
	return wrap(JS_CompileUCScript(CX(cx), OBJ(scope), JSCHARS(src), length, filename, lineno));
}
Object newScriptObject(Context cx, Script script)     { return wrap(JS_NewScriptObject(CX(cx), SCR(script))); }
bool   executeScript(Context cx, Object obj, Script script, Value* rval)
{
	return JS_ExecuteScript(CX(cx), OBJ(obj), SCR(script), JSVP(rval)) != JS_FALSE;
}
void   destroyScript(Context cx, Script script)       { JS_DestroyScript(CX(cx), SCR(script)); }

bool serializeScript(Context cx, Script script, ByteBuffer* out)
{
	out->data   = nullptr;
	out->length = 0;
	JSXDRState* xdr = JS_XDRNewMem(CX(cx), JSXDR_ENCODE);
	if (xdr == nullptr)  return false;
	JSScript* s = SCR(script);
	bool ok = JS_XDRScript(xdr, &s) != JS_FALSE;
	if (ok)
	{
		uint32 length = 0;
		void* bytes = JS_XDRMemGetData(xdr, &length);
		if (bytes != nullptr && length > 0)
		{
			std::uint8_t* copy = static_cast<std::uint8_t*>(std::malloc(length));
			if (copy == nullptr)  { JS_XDRDestroy(xdr); return false; }
			std::memcpy(copy, bytes, length);
			out->data   = copy;
			out->length = length;
		}
		else
		{
			ok = false;
		}
	}
	JS_XDRDestroy(xdr);
	return ok;
}
Script deserializeScript(Context cx, const std::uint8_t* data, std::size_t length)
{
	JSXDRState* xdr = JS_XDRNewMem(CX(cx), JSXDR_DECODE);
	if (xdr == nullptr)  return nullptr;
	JS_XDRMemSetData(xdr, const_cast<void*>(static_cast<const void*>(data)), static_cast<uint32>(length));
	JSScript* result = nullptr;
	if (!JS_XDRScript(xdr, &result))  result = nullptr;
	JS_XDRMemSetData(xdr, nullptr, 0);   // don't let it be freed by XDRDestroy; the caller owns `data`
	JS_XDRDestroy(xdr);
	return wrap(result);
}
void destroyByteBuffer(ByteBuffer* buf)
{
	if (buf == nullptr)  return;
	std::free(buf->data);
	buf->data   = nullptr;
	buf->length = 0;
}

// MARK: Strings ---------------------------------------------------------------------------------

String        internString(Context cx, const char* s)                        { return wrap(JS_InternString(CX(cx), s)); }
String        internUCStringN(Context cx, const Char16* s, std::size_t n)    { return wrap(JS_InternUCStringN(CX(cx), JSCHARS(s), n)); }
String        newStringCopyZ(Context cx, const char* s)                      { return wrap(JS_NewStringCopyZ(CX(cx), s)); }
String        newStringCopyN(Context cx, const char* s, std::size_t n)       { return wrap(JS_NewStringCopyN(CX(cx), s, n)); }
String        newUCStringCopyN(Context cx, const Char16* s, std::size_t n)   { return wrap(JS_NewUCStringCopyN(CX(cx), JSCHARS(s), n)); }
Value         emptyStringValue(Context cx)                                   { return fromJS(JS_GetEmptyStringValue(CX(cx))); }
std::size_t   getStringLength(String str)                                    { return JS_GetStringLength(STR(str)); }
const Char16* getStringCharsAndLength(Context cx, String str, std::size_t* length)
{
	return CHARS(JS_GetStringCharsAndLength(CX(cx), STR(str), length));
}
const Char16* getInternedStringChars(String str)                             { return CHARS(JS_GetInternedStringChars(STR(str))); }
bool          stringEqualsAscii(Context cx, String str, const char* ascii, bool* match)
{
	JSBool m = JS_FALSE;
	if (!JS_StringEqualsAscii(CX(cx), STR(str), ascii, &m))  return false;
	*match = m != JS_FALSE;
	return true;
}
bool          stringHasBeenInterned(Context /*cx*/, String str)              { return JS_StringHasBeenInterned(STR(str)) != JS_FALSE; }
void          setCStringsAreUTF8()                                           { JS_SetCStringsAreUTF8(); }

// MARK: Regular expressions -----------------------------------------------------------------

Object newUCRegExpObjectNoStatics(Context cx, const Char16* chars, std::size_t length, std::uint32_t flags)
{
	return wrap(JS_NewUCRegExpObjectNoStatics(CX(cx), const_cast<jschar*>(JSCHARS(chars)), length, static_cast<uintN>(flags)));
}

// MARK: Exceptions and error reporting --------------------------------------------------------

bool isExceptionPending(Context cx)                   { return JS_IsExceptionPending(CX(cx)) != JS_FALSE; }
bool getPendingException(Context cx, Value* vp)       { return JS_GetPendingException(CX(cx), JSVP(vp)) != JS_FALSE; }
void setPendingException(Context cx, Value v)         { JS_SetPendingException(CX(cx), toJS(v)); }
void clearPendingException(Context cx)                { JS_ClearPendingException(CX(cx)); }
bool reportPendingException(Context cx)               { return JS_ReportPendingException(CX(cx)) != JS_FALSE; }
void reportError(Context cx, const char* message)     { JS_ReportError(CX(cx), "%s", message); }
bool reportWarning(Context cx, const char* message)   { return JS_ReportWarning(CX(cx), "%s", message) != JS_FALSE; }
void reportOutOfMemory(Context cx)                    { JS_ReportOutOfMemory(CX(cx)); }

ErrorReporter setErrorReporter(Context cx, ErrorReporter reporter)
{
	ContextExtras& ex = gExtras[CX(cx)];
	ErrorReporter old = ex.reporter;
	ex.reporter = reporter;
	JS_SetErrorReporter(CX(cx), reporter ? ErrorReporterTramp : nullptr);
	return old;
}

ExceptionState* saveExceptionState(Context cx)
{
	return reinterpret_cast<ExceptionState*>(JS_SaveExceptionState(CX(cx)));
}
void restoreExceptionState(Context cx, ExceptionState* state)
{
	JS_RestoreExceptionState(CX(cx), reinterpret_cast<JSExceptionState*>(state));
}
void dropExceptionState(Context cx, ExceptionState* state)
{
	JS_DropExceptionState(CX(cx), reinterpret_cast<JSExceptionState*>(state));
}

// MARK: GC roots --------------------------------------------------------------------------------

bool addNamedObjectRoot(Context cx, Object* rp, const char* name)   { return JS_AddNamedObjectRoot(CX(cx), OBJPP(rp), name) != JS_FALSE; }
bool addNamedValueRoot(Context cx, Value* vp, const char* name)     { return JS_AddNamedValueRoot(CX(cx), JSVP(vp), name) != JS_FALSE; }
bool addNamedStringRoot(Context cx, String* sp, const char* name)   { return JS_AddNamedStringRoot(CX(cx), STRPP(sp), name) != JS_FALSE; }
bool removeObjectRoot(Context cx, Object* rp)                       { return JS_RemoveObjectRoot(CX(cx), OBJPP(rp)) != JS_FALSE; }
bool removeValueRoot(Context cx, Value* vp)                         { return JS_RemoveValueRoot(CX(cx), JSVP(vp)) != JS_FALSE; }
bool removeStringRoot(Context cx, String* sp)                       { return JS_RemoveStringRoot(CX(cx), STRPP(sp)) != JS_FALSE; }

// MARK: Runtime, contexts, requests, GC ---------------------------------------------------------

Runtime newRuntime(std::uint32_t maxBytes)                 { return wrap(JS_NewRuntime(maxBytes)); }
void    destroyRuntime(Runtime rt)                         { JS_DestroyRuntime(RT(rt)); }
void    shutDown()                                         { JS_ShutDown(); }
Context newContext(Runtime rt, std::size_t stackChunkSize) { return wrap(JS_NewContext(RT(rt), stackChunkSize)); }
void    destroyContext(Context cx)
{
	gExtras.erase(CX(cx));
	JS_DestroyContext(CX(cx));
}
Runtime getRuntime(Context cx)                             { return wrap(JS_GetRuntime(CX(cx))); }
void*   getContextPrivate(Context cx)                      { return JS_GetContextPrivate(CX(cx)); }
void    setContextPrivate(Context cx, void* data)          { JS_SetContextPrivate(CX(cx), data); }

void beginRequest(Context cx)                              { JS_BeginRequest(CX(cx)); }
void endRequest(Context cx)                                { JS_EndRequest(CX(cx)); }
bool isInRequest(Context cx)                               { return JS_IsInRequest(CX(cx)) != JS_FALSE; }
bool isThreadsafeBuild()                                    { return JS_THREADSAFE ? true : false; }

ContextOption setOptions(Context cx, ContextOption options) { return optionsFrom(JS_SetOptions(CX(cx), optionBits(options))); }
ContextOption getOptions(Context cx)                        { return optionsFrom(JS_GetOptions(CX(cx))); }

Version     setVersion(Context cx, Version v)              { return fromJS(JS_SetVersion(CX(cx), toJS(v))); }
Version     getVersion(Context cx)                         { return fromJS(JS_GetVersion(CX(cx))); }
const char* versionToString(Version v)                     { return JS_VersionToString(toJS(v)); }

std::uint32_t getGCParameter(Runtime rt, GCParam key)                       { return JS_GetGCParameter(RT(rt), toJS(key)); }
void          setGCParameter(Runtime rt, GCParam key, std::uint32_t value)  { JS_SetGCParameter(RT(rt), toJS(key), value); }
void          gc(Context cx)                                                { JS_GC(CX(cx)); }
#if JS_GC_ZEAL
void          setGCZeal(Context cx, std::uint8_t zeal)                     { JS_SetGCZeal(CX(cx), zeal); }
bool          gcZealSupported()                                            { return true; }
#else
void          setGCZeal(Context, std::uint8_t)                             { }
bool          gcZealSupported()                                            { return false; }
#endif
void          maybeGC(Context cx)                                           { JS_MaybeGC(CX(cx)); }

OperationCallback setOperationCallback(Context cx, OperationCallback cb)
{
	ContextExtras& ex = gExtras[CX(cx)];
	OperationCallback old = ex.opcb;
	ex.opcb = cb;
	JS_SetOperationCallback(CX(cx), cb ? OperationCallbackTramp : nullptr);
	return old;
}
void triggerOperationCallback(Context cx)                  { JS_TriggerOperationCallback(CX(cx)); }
void triggerAllOperationCallbacks(Runtime rt)              { JS_TriggerAllOperationCallbacks(RT(rt)); }

// MARK: Completing the retarget (bead oo-1gc.3) -------------------------------------------------

#if JS_THREADSAFE
unsigned suspendRequest(Context cx)                        { return static_cast<unsigned>(JS_SuspendRequest(CX(cx))); }
void     resumeRequest(Context cx, unsigned token)         { JS_ResumeRequest(CX(cx), static_cast<jsrefcount>(token)); }
#else
unsigned suspendRequest(Context)                           { return 0; }
void     resumeRequest(Context, unsigned)                  { }
#endif

bool compareStrings(Context cx, String a, String b, std::int32_t* result)
{
	return JS_CompareStrings(CX(cx), STR(a), STR(b), result) != JS_FALSE;
}
bool freezeObject(Context cx, Object obj)                  { return JS_FreezeObject(CX(cx), OBJ(obj)) != JS_FALSE; }
Function compileUCFunction(Context cx, Object scope, const char* name, unsigned nargs, const char** argnames,
                           const Char16* chars, std::size_t length, const char* filename, unsigned lineno)
{
	return wrap(JS_CompileUCFunction(CX(cx), OBJ(scope), name, nargs, argnames, JSCHARS(chars), length, filename, lineno));
}
bool callFunction(Context cx, Object thisObj, Function fn, unsigned argc, Value* argv, Value* rval)
{
	return JS_CallFunction(CX(cx), OBJ(thisObj), FUN(fn), argc, JSVP(argv), JSVP(rval)) != JS_FALSE;
}
bool bufferIsCompilableUnit(Context cx, Object obj, const char* bytes, std::size_t length)
{
	return JS_BufferIsCompilableUnit(CX(cx), OBJ(obj), bytes, length) != JS_FALSE;
}
static_assert(RegExpFoldCase == JSREG_FOLD && RegExpGlobal == JSREG_GLOB && RegExpMultiline == JSREG_MULTILINE,
              "façade regexp flags are the engine's");

// MARK: Debugging and profiling -----------------------------------------------------------------

namespace {
inline JSStackFrame* FP(StackFrame f)       { return reinterpret_cast<JSStackFrame*>(f); }
inline StackFrame    wrap(JSStackFrame* f)  { return reinterpret_cast<StackFrame>(f); }
}

StackFrame frameIterator(Context cx, StackFrame* iter)
{
	JSStackFrame* fp = FP(*iter);
	JSStackFrame* next = JS_FrameIterator(CX(cx), &fp);
	*iter = wrap(fp);
	return wrap(next);
}
bool        frameIsScript(Context cx, StackFrame fp)       { return JS_IsScriptFrame(CX(cx), FP(fp)) != JS_FALSE; }
bool        frameIsConstructor(Context cx, StackFrame fp)  { return JS_IsConstructorFrame(CX(cx), FP(fp)) != JS_FALSE; }
bool        frameIsDebugger(Context cx, StackFrame fp)     { return JS_IsDebuggerFrame(CX(cx), FP(fp)) != JS_FALSE; }
Script      frameScript(Context cx, StackFrame fp)         { return wrap(JS_GetFrameScript(CX(cx), FP(fp))); }
const char* scriptFilename(Context cx, Script script)      { return JS_GetScriptFilename(CX(cx), SCR(script)); }
unsigned    frameLineNumber(Context cx, StackFrame fp)
{
	JSScript* script = JS_GetFrameScript(CX(cx), FP(fp));
	if (script == nullptr)  return 0;
	return JS_PCToLineNumber(CX(cx), script, JS_GetFramePC(CX(cx), FP(fp)));
}
Function    frameFunction(Context cx, StackFrame fp)       { return wrap(JS_GetFrameFunction(CX(cx), FP(fp))); }
bool        frameThis(Context cx, StackFrame fp, Value* thisv)
{
	return JS_GetFrameThis(CX(cx), FP(fp), JSVP(thisv)) != JS_FALSE;
}
Object      frameScopeChain(Context cx, StackFrame fp)     { return wrap(JS_GetFrameScopeChain(CX(cx), FP(fp))); }

bool getScopeVariables(Context cx, Object scope, VariableList* out)
{
	out->length = 0; out->vars = nullptr; out->backend = nullptr;
	JSPropertyDescArray* pda = new JSPropertyDescArray { 0, nullptr };
	if (!JS_GetPropertyDescArray(CX(cx), OBJ(scope), pda))  { delete pda; return false; }
	Variable* vars = new Variable[pda->length > 0 ? pda->length : 1];
	for (uint32 i = 0; i < pda->length; i++)
	{
		const JSPropertyDesc& d = pda->array[i];
		jsid id;
		if (!JS_ValueToId(CX(cx), d.id, &id))  id = JSID_VOID;
		unsigned flags = 0;
		if (d.flags & JSPD_ENUMERATE)  flags |= static_cast<unsigned>(VariableFlag::Enumerate);
		if (d.flags & JSPD_READONLY)   flags |= static_cast<unsigned>(VariableFlag::ReadOnly);
		if (d.flags & JSPD_PERMANENT)  flags |= static_cast<unsigned>(VariableFlag::Permanent);
		if (d.flags & JSPD_ALIAS)      flags |= static_cast<unsigned>(VariableFlag::Alias);
		if (d.flags & JSPD_ARGUMENT)   flags |= static_cast<unsigned>(VariableFlag::Argument);
		if (d.flags & JSPD_VARIABLE)   flags |= static_cast<unsigned>(VariableFlag::Variable);
		if (d.flags & JSPD_EXCEPTION)  flags |= static_cast<unsigned>(VariableFlag::Exception);
		if (d.flags & JSPD_ERROR)      flags |= static_cast<unsigned>(VariableFlag::Error);
		vars[i] = Variable { fromJS(id), fromJS(d.value), flags, fromJS(d.alias) };
	}
	out->length = pda->length; out->vars = vars; out->backend = pda;
	return true;
}
void destroyScopeVariables(Context cx, VariableList* list)
{
	if (list == nullptr || list->backend == nullptr)  return;
	JSPropertyDescArray* pda = static_cast<JSPropertyDescArray*>(list->backend);
	JS_PutPropertyDescArray(CX(cx), pda);
	delete pda;
	delete[] list->vars;
	list->length = 0; list->vars = nullptr; list->backend = nullptr;
}

namespace {
struct DebuggerHook { DebuggerHandler handler; void* closure; };
DebuggerHook gDebuggerHook { nullptr, nullptr };
JSTrapStatus DebuggerTramp(JSContext* cx, JSScript*, jsbytecode*, jsval*, void*)
{
	if (gDebuggerHook.handler != nullptr)  gDebuggerHook.handler(wrap(cx), gDebuggerHook.closure);
	return JSTRAP_CONTINUE;
}
FunctionCallback gFunctionCallback = nullptr;
#if MOZ_TRACE_JSCALLS
void FunctionCallbackTramp(const JSFunction* fun, const JSScript* scr, const JSContext* cx, int entering)
{
	if (gFunctionCallback != nullptr)
	{
		gFunctionCallback(wrap(const_cast<JSFunction*>(fun)), reinterpret_cast<Script>(const_cast<JSScript*>(scr)),
		                  wrap(const_cast<JSContext*>(cx)), entering);
	}
}
#endif
ContextCallback gContextCallback = nullptr;
JSBool ContextCallbackTramp(JSContext* cx, uintN op)
{
	if (gContextCallback == nullptr)  return JS_TRUE;
	return B(gContextCallback(wrap(cx), op == JSCONTEXT_NEW ? ContextOp::New : ContextOp::Destroy));
}
}

void setDebuggerHandler(Runtime rt, DebuggerHandler handler, void* closure)
{
	gDebuggerHook = DebuggerHook { handler, closure };
	JS_SetDebuggerHandler(RT(rt), handler != nullptr ? DebuggerTramp : nullptr, nullptr);
}
#if MOZ_TRACE_JSCALLS
bool setFunctionCallback(Context cx, FunctionCallback cb)
{
	gFunctionCallback = cb;
	JS_SetFunctionCallback(CX(cx), cb != nullptr ? FunctionCallbackTramp : nullptr);
	return true;
}
#else
bool setFunctionCallback(Context, FunctionCallback)         { return false; }
#endif
ContextCallback setContextCallback(Runtime rt, ContextCallback cb)
{
	ContextCallback old = gContextCallback;
	gContextCallback = cb;
	JS_SetContextCallback(RT(rt), cb != nullptr ? ContextCallbackTramp : nullptr);
	return old;
}

#ifdef DEBUG
namespace {
struct RootDumpData { RootDumper dump; void* data; };
void RootDumpTramp(const char* name, void* rp, JSGCRootType type, void* data)
{
	RootDumpData* d = static_cast<RootDumpData*>(data);
	d->dump(name, rp, type == JS_GC_ROOT_VALUE_PTR ? RootKind::Value : RootKind::GCThing, d->data);
}
}
bool dumpNamedRoots(Runtime rt, RootDumper dump, void* data)
{
	RootDumpData d { dump, data };
	JS_DumpNamedRoots(RT(rt), RootDumpTramp, &d);
	return true;
}
bool dumpHeap(Context cx, void* file)
{
	return JS_DumpHeap(CX(cx), static_cast<FILE*>(file), nullptr, 0, nullptr, SIZE_MAX, nullptr) != JS_FALSE;
}
#else
bool dumpNamedRoots(Runtime, RootDumper, void*)            { return false; }
bool dumpHeap(Context, void*)                              { return false; }
#endif

// MARK: Backend identity ------------------------------------------------------------------------

const char* backendName()                                  { return "spidermonkey-1.8.5"; }

} // namespace ooscript
