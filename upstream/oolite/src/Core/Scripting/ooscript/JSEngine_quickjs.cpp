/*

ooscript/JSEngine_quickjs.cpp

A QuickJS-ng backend for the façade in JSEngine.hpp (Phase 1 seam 1.4b, bead oo-0kq). Scope, by
design (the full façade surface is a later bead's job once this seam is proven):

  * Runtime/Context lifecycle (newRuntime/newContext/destroyContext/destroyRuntime/shutDown and
    the small set of accessors the tests exercise).
  * Value construction and inspection for the primitives Oolite actually threads through the
    façade in a resolve/enumerate demo: undefined, null, booleans, int32, doubles, objects.
  * ClassDef lifecycle (attach-on-first-use, exactly as the SpiderMonkey backend does) with
    HasPrivate, finalize, and — the point of this bead — resolve and enumerate mapped onto
    QuickJS-ng's JSClassExoticMethods (has_property and get_own_property_names respectively).
  * Private-pointer attach/retrieve (setPrivate/getPrivate/getInstancePrivate) via JS_SetOpaque
    and JS_GetOpaque/JS_GetAnyOpaque.

Anything else the façade declares (strings, arrays, GC parameters, error reporting, roots, the
full property-definition surface, …) is out of scope here: nothing in the tree calls into this
backend yet (retargeting call sites is separate beads, and this backend is not the meson default),
so an unimplemented façade function simply has no definition in this translation unit and stays
unreferenced. tests/unit/test_jsengine_quickjs.cpp only calls what is implemented below.

Value representation
	ooscript::Value must stay an 8-byte POD (JSEngine.hpp is not ours to change), but QuickJS-ng's
	own JSValue is 16 bytes on a 64-bit build (JS_NAN_BOXING is only forced under 32-bit; forcing
	it here would require rebuilding the vendored library with a matching define, which is bead
	oo-kte's vendoring, not this one). So Value uses its own NaN-boxing, independent of the
	engine's internal layout: genuine doubles are stored as their literal 64-bit pattern; anything
	else uses a reserved quiet-NaN payload (0x7FFC...) that ordinary arithmetic never produces,
	with a 3-bit tag and a 48-bit payload (fits a pointer on every platform Oolite ships for).
	toJS()/fromJS() translate to and from a real (16-byte) JSValue at the point of an engine call.

Property dispatch
	Oolite's façade classes describe properties by tinyid (see JSEngine.hpp's PropertySpec), and
	QuickJS-ng's exotic methods hand back the accessed property as a JSAtom, not a tinyid. The
	glue is `registerResolvableProperty()` below: a per-class (name -> tinyid) table, consulted by
	the has_property and get_own_property_names trampolines to reconstruct the PropertyId the
	façade's resolve/enumerate hooks expect. It is not part of the façade — it is this backend's
	analogue of what JS_InitClass + JSPropertySpec wire up for SpiderMonkey — and is exported only
	for the unit test to call; a future bead that adds initClass() for this backend would fold it
	into that instead.

Copyright (C) 2026 the Oolite migration project. GPL-2.0-or-later, as the rest of Oolite.

*/

#include "JSEngine.hpp"

#include <quickjs.h>

#include <cmath>
#include <cstring>
#include <string>
#include <unordered_map>
#include <vector>

namespace ooscript {

namespace {

inline JSContext* CX(Context cx) { return reinterpret_cast<JSContext*>(cx); }
inline Context     wrap(JSContext* cx) { return reinterpret_cast<Context>(cx); }
inline JSRuntime*  RT(Runtime rt) { return reinterpret_cast<JSRuntime*>(rt); }
inline Runtime     wrap(JSRuntime* rt) { return reinterpret_cast<Runtime>(rt); }
inline Object      wrapObj(JSValueConst v) { return reinterpret_cast<Object>(JS_VALUE_GET_PTR(v)); }
inline JSValue     OBJVAL(Object o) { return JS_MKPTR(JS_TAG_OBJECT, o); }

// MARK: Value NaN-boxing -------------------------------------------------------------------------

// Negative-signed quiet NaN (sign=1, exponent all-ones, mantissa top bit set): ordinary doubles,
// including the positive quiet NaN std::nan("") produces, never land here, so bits 48-50 are free
// for a tag and bits 0-47 for a payload (a pointer or a 32-bit int) without touching the marker.
constexpr std::uint64_t kQNanMask = 0xFFF8000000000000ULL;
constexpr std::uint64_t kPtrMask  = 0x0000FFFFFFFFFFFFULL;   // 48-bit pointer/int payload
constexpr int kTagUndefined = 1, kTagNull = 2, kTagFalse = 3, kTagTrue = 4, kTagInt32 = 5, kTagObject = 6;

inline bool     isBoxed(Value v)      { return (v.bits & kQNanMask) == kQNanMask; }
inline int      tagOf(Value v)        { return static_cast<int>((v.bits >> 48) & 0x7); }
inline Value    boxed(int tag, std::uint64_t payload) { Value v; v.bits = kQNanMask | (static_cast<std::uint64_t>(tag) << 48) | (payload & kPtrMask); return v; }

} // namespace

Value undefinedValue()  { return boxed(kTagUndefined, 0); }
Value nullValue()       { return boxed(kTagNull, 0); }
Value trueValue()       { return boxed(kTagTrue, 0); }
Value falseValue()      { return boxed(kTagFalse, 0); }
Value booleanValue(bool b) { return b ? trueValue() : falseValue(); }
Value int32Value(std::int32_t i) { return boxed(kTagInt32, static_cast<std::uint32_t>(i)); }
Value objectValue(Object obj)    { return boxed(kTagObject, reinterpret_cast<std::uint64_t>(obj)); }

Value numberValue(double d)
{
	// Mirrors JS_NewNumberValue's canonicalisation choice (store an int32 where exact), without
	// depending on QuickJS-ng's own value layout: see the file banner for why.
	const std::int32_t i = static_cast<std::int32_t>(d);
	if (static_cast<double>(i) == d && !(d == 0.0 && std::signbit(d)))  return int32Value(i);
	Value v;
	std::memcpy(&v.bits, &d, sizeof v.bits);
	return v;
}

bool isUndefined(Value v)  { return isBoxed(v) && tagOf(v) == kTagUndefined; }
bool isNull(Value v)       { return isBoxed(v) && tagOf(v) == kTagNull; }
bool isNullOrUndefined(Value v) { return isNull(v) || isUndefined(v); }
bool isObjectOrNull(Value v) { return isBoxed(v) && (tagOf(v) == kTagObject || tagOf(v) == kTagNull); }
bool isObject(Value v)     { return isObjectOrNull(v) && (v.bits & kPtrMask) != 0; }
bool isBoolean(Value v)    { return isBoxed(v) && (tagOf(v) == kTagTrue || tagOf(v) == kTagFalse); }
bool isInt32(Value v)      { return isBoxed(v) && tagOf(v) == kTagInt32; }
bool isDouble(Value v)     { return !isBoxed(v); }
bool isNumber(Value v)     { return isInt32(v) || isDouble(v); }
bool isString(Value v)     { (void)v; return false; }   // strings are out of scope for this seam
bool isPrimitive(Value v)  { return !isObjectOrNull(v); }

Object       toObject(Value v)  { return reinterpret_cast<Object>(static_cast<std::uintptr_t>(v.bits & kPtrMask)); }
std::int32_t toInt32(Value v)   { return static_cast<std::int32_t>(v.bits & 0xFFFFFFFFu); }
double       toDouble(Value v)  { double d; std::memcpy(&d, &v.bits, sizeof d); return d; }
bool         toBoolean(Value v) { return tagOf(v) == kTagTrue; }

// MARK: Property ids ------------------------------------------------------------------------

PropertyId   int32Id(std::int32_t i)  { PropertyId id; id.bits = (1ULL << 63) | static_cast<std::uint32_t>(i); return id; }
PropertyId   voidId()                 { PropertyId id; id.bits = 0; return id; }
bool         isInt32Id(PropertyId id) { return (id.bits >> 63) == 1; }
bool         isVoidId(PropertyId id)  { return id.bits == 0; }
std::int32_t idToInt32(PropertyId id) { return static_cast<std::int32_t>(id.bits & 0xFFFFFFFFu); }
bool         idsEqual(PropertyId a, PropertyId b) { return a.bits == b.bits; }

namespace {

// MARK: Engine <-> façade value translation --------------------------------------------------

JSValue toJS(Value v)
{
	if (!isBoxed(v))
	{
		double d; std::memcpy(&d, &v.bits, sizeof d);
		return __JS_NewFloat64(d);
	}
	switch (tagOf(v))
	{
		case kTagUndefined: return JS_UNDEFINED;
		case kTagNull:      return JS_NULL;
		case kTagFalse:     return JS_FALSE;
		case kTagTrue:      return JS_TRUE;
		case kTagInt32:     return JS_MKVAL(JS_TAG_INT, toInt32(v));
		case kTagObject:    return OBJVAL(toObject(v));
	}
	return JS_UNDEFINED;
}

Value fromJS(JSValueConst v)
{
	const int tag = JS_VALUE_GET_TAG(v);
	if (tag == JS_TAG_UNDEFINED)  return undefinedValue();
	if (tag == JS_TAG_NULL)       return nullValue();
	if (tag == JS_TAG_BOOL)       return booleanValue(JS_VALUE_GET_BOOL(v) != 0);
	if (tag == JS_TAG_INT)        return int32Value(JS_VALUE_GET_INT(v));
	if (tag == JS_TAG_OBJECT)     return objectValue(wrapObj(v));
	if (JS_TAG_IS_FLOAT64(tag))   return numberValue(JS_VALUE_GET_FLOAT64(v));
	return undefinedValue();
}

// MARK: Classes: attach-on-first-use, exotic methods for resolve/enumerate ------------------

struct BackendClass
{
	JSClassID              id = 0;
	ClassDef*              def = nullptr;
	JSClassExoticMethods    exotic{};
	std::vector<std::pair<std::string, std::int32_t>> tinyidProps;   // name -> tinyid, declaration order
};

std::unordered_map<JSClassID, BackendClass*>  gClasses;
std::unordered_map<JSRuntime*, JSContext*>    gCtxForRuntime;   // finalizers get only a Runtime*

BackendClass* classOf(JSValueConst obj)
{
	const JSClassID cid = JS_GetClassID(obj);
	auto it = gClasses.find(cid);
	return it == gClasses.end() ? nullptr : it->second;
}

bool tinyidForAtom(BackendClass* bc, JSContext* ctx, JSAtom atom, std::int32_t* out)
{
	const char* name = JS_AtomToCString(ctx, atom);
	if (name == nullptr)  return false;
	bool found = false;
	for (const auto& p : bc->tinyidProps)
	{
		if (p.first == name)  { *out = p.second; found = true; break; }
	}
	JS_FreeCString(ctx, name);
	return found;
}

int HasPropertyTramp(JSContext* ctx, JSValueConst obj, JSAtom atom)
{
	BackendClass* bc = classOf(obj);
	std::int32_t tinyid = 0;
	if (bc == nullptr || bc->def->resolve == nullptr || !tinyidForAtom(bc, ctx, atom, &tinyid))  return 0;
	if (!bc->def->resolve(wrap(ctx), wrapObj(obj), int32Id(tinyid)))  return -1;   // exception pending
	return 1;
}

// for-in (and any JS_GPN_ENUM_ONLY walk) asks this to learn whether a name get_own_property_names
// handed back is enumerable; without it every tinyid property looks non-enumerable and for-in
// silently skips them even though has_property/get_own_property_names both answered for them.
int GetOwnPropertyTramp(JSContext* ctx, JSPropertyDescriptor* desc, JSValueConst obj, JSAtom atom)
{
	BackendClass* bc = classOf(obj);
	std::int32_t tinyid = 0;
	if (bc == nullptr || !tinyidForAtom(bc, ctx, atom, &tinyid))  return 0;
	if (desc != nullptr)
	{
		desc->flags  = JS_PROP_ENUMERABLE;
		desc->value  = JS_UNDEFINED;
		desc->getter = JS_UNDEFINED;
		desc->setter = JS_UNDEFINED;
	}
	return 1;
}

int GetOwnPropertyNamesTramp(JSContext* ctx, JSPropertyEnum** ptab, std::uint32_t* plen, JSValueConst obj)
{
	BackendClass* bc = classOf(obj);
	if (bc == nullptr)  { *ptab = nullptr; *plen = 0; return 0; }
	if (bc->def->enumerate != nullptr && !bc->def->enumerate(wrap(ctx), wrapObj(obj)))  return -1;
	const std::size_t n = bc->tinyidProps.size();
	auto* tab = static_cast<JSPropertyEnum*>(js_mallocz(ctx, sizeof(JSPropertyEnum) * (n > 0 ? n : 1)));
	if (tab == nullptr)  return -1;
	for (std::size_t i = 0; i < n; ++i)
	{
		tab[i].atom = JS_NewAtom(ctx, bc->tinyidProps[i].first.c_str());
		tab[i].is_enumerable = true;
	}
	*ptab = tab;
	*plen = static_cast<std::uint32_t>(n);
	return 0;
}

void FinalizeTramp(JSRuntime* rt, JSValueConst val)
{
	BackendClass* bc = classOf(val);
	if (bc == nullptr || bc->def->finalize == nullptr)  return;
	auto it = gCtxForRuntime.find(rt);
	if (it == gCtxForRuntime.end())  return;   // no live context to hand the hook; nothing we can do
	bc->def->finalize(wrap(it->second), wrapObj(val));
}

BackendClass* attach(ClassDef* def, JSContext* ctx)
{
	if (def == nullptr)  return nullptr;
	if (def->backend != nullptr)  return static_cast<BackendClass*>(def->backend);

	auto* bc = new BackendClass();
	bc->def = def;
	JS_NewClassID(JS_GetRuntime(ctx), &bc->id);

	JSClassDef cdef{};
	cdef.class_name = def->name;
	cdef.finalizer  = def->finalize != nullptr ? FinalizeTramp : nullptr;
	if (def->resolve != nullptr || def->enumerate != nullptr)
	{
		bc->exotic.has_property          = def->resolve   != nullptr ? HasPropertyTramp          : nullptr;
		bc->exotic.get_own_property      = def->resolve   != nullptr ? GetOwnPropertyTramp        : nullptr;
		bc->exotic.get_own_property_names = def->enumerate != nullptr ? GetOwnPropertyNamesTramp   : nullptr;
		cdef.exotic = &bc->exotic;
	}
	JS_NewClass(JS_GetRuntime(ctx), bc->id, &cdef);

	gClasses.emplace(bc->id, bc);
	def->backend = bc;
	return bc;
}

} // namespace

// MARK: Objects -----------------------------------------------------------------------------

Object newObject(Context cx, ClassDef* def, Object proto, Object /*parent*/)
{
	JSContext* ctx = CX(cx);
	BackendClass* bc = attach(def, ctx);
	if (bc == nullptr)  return nullptr;
	JSValue v = proto != nullptr ? JS_NewObjectProtoClass(ctx, OBJVAL(proto), bc->id)
	                             : JS_NewObjectClass(ctx, bc->id);
	if (JS_IsException(v))  { JS_FreeValue(ctx, JS_GetException(ctx)); return nullptr; }
	return wrapObj(v);
}

Object getGlobalObject(Context cx)
{
	// The context keeps its own reference to the global for as long as it lives; ours is a
	// second, independent one (JS_GetGlobalObject's normal contract) that must be dropped here,
	// not kept, or the global — and everything reachable from it, including every façade object
	// a caller ever attaches to it — would never reach a zero refcount and would never finalize.
	JSContext* ctx = CX(cx);
	JSValue g = JS_GetGlobalObject(ctx);
	Object out = wrapObj(g);
	JS_FreeValue(ctx, g);
	return out;
}

bool initStandardClasses(Context /*cx*/, Object /*global*/) { return true; }   // JS_NewContext already added them

const ClassDef* getClass(Context /*cx*/, Object obj)
{
	BackendClass* bc = classOf(OBJVAL(obj));
	return bc != nullptr ? bc->def : nullptr;
}

bool instanceOf(Context cx, Object obj, ClassDef* def, Value* /*argv*/)
{
	BackendClass* bc = attach(def, CX(cx));
	return bc != nullptr && classOf(OBJVAL(obj)) == bc;
}

bool  setPrivate(Context /*cx*/, Object obj, void* data) { return JS_SetOpaque(OBJVAL(obj), data) == 0; }
void* getPrivate(Context /*cx*/, Object obj)              { JSClassID cid = 0; return JS_GetAnyOpaque(OBJVAL(obj), &cid); }
void* getInstancePrivate(Context cx, Object obj, ClassDef* def, Value* /*argv*/)
{
	BackendClass* bc = attach(def, CX(cx));
	return bc != nullptr ? JS_GetOpaque(OBJVAL(obj), bc->id) : nullptr;
}

bool setProperty(Context cx, Object obj, const char* name, Value* vp)
{
	return JS_SetPropertyStr(CX(cx), OBJVAL(obj), name, toJS(*vp)) >= 0;
}
bool getProperty(Context cx, Object obj, const char* name, Value* vp)
{
	JSValue v = JS_GetPropertyStr(CX(cx), OBJVAL(obj), name);
	if (JS_IsException(v))  { JS_FreeValue(CX(cx), JS_GetException(CX(cx))); return false; }
	*vp = fromJS(v);
	JS_FreeValue(CX(cx), v);
	return true;
}

bool evaluateScript(Context cx, Object /*scope*/, const char* src, unsigned length, const char* filename, unsigned /*lineno*/, Value* rval)
{
	JSContext* ctx = CX(cx);
	JSValue result = JS_Eval(ctx, src, length, filename, JS_EVAL_TYPE_GLOBAL);
	if (JS_IsException(result))
	{
		JS_FreeValue(ctx, JS_GetException(ctx));
		JS_FreeValue(ctx, result);
		*rval = undefinedValue();
		return false;
	}
	*rval = fromJS(result);
	JS_FreeValue(ctx, result);
	return true;
}

// MARK: Runtime, contexts ---------------------------------------------------------------------

Runtime newRuntime(std::uint32_t maxBytes)
{
	JSRuntime* rt = JS_NewRuntime();
	if (rt != nullptr && maxBytes != 0)  JS_SetMemoryLimit(rt, maxBytes);
	return wrap(rt);
}
void destroyRuntime(Runtime rt)
{
	// Erase after freeing, not before: JS_FreeRuntime is what drops the runtime's last references
	// and runs pending finalizers, and FinalizeTramp needs gCtxForRuntime's entry to still be
	// there when it looks up which façade Context to hand the hook.
	JS_FreeRuntime(RT(rt));
	gCtxForRuntime.erase(RT(rt));
}
void shutDown() {}

Context newContext(Runtime rt, std::size_t /*stackChunkSize*/)
{
	JSContext* ctx = JS_NewContext(RT(rt));
	if (ctx != nullptr)  gCtxForRuntime[RT(rt)] = ctx;
	return wrap(ctx);
}
void destroyContext(Context cx) { JS_FreeContext(CX(cx)); }
Runtime getRuntime(Context cx)  { return wrap(JS_GetRuntime(CX(cx))); }
void*   getContextPrivate(Context cx)          { return JS_GetContextOpaque(CX(cx)); }
void    setContextPrivate(Context cx, void* d) { JS_SetContextOpaque(CX(cx), d); }

// MARK: Backend identity ----------------------------------------------------------------------

const char* backendName() { return "quickjs-ng-0.16.2"; }

// MARK: Test-only glue (not part of the façade) ------------------------------------------------
//
// The name -> tinyid table that HasPropertyTramp/GetOwnPropertyNamesTramp consult (see the file
// banner). A future initClass() for this backend folds this into PropertySpec handling instead.

void registerResolvableProperty(Context cx, ClassDef* def, const char* name, std::int32_t tinyid)
{
	BackendClass* bc = attach(def, CX(cx));
	if (bc != nullptr)  bc->tinyidProps.emplace_back(name, tinyid);
}

} // namespace ooscript
