/*
OOJSExhaustPlume.m

Oolite
Copyright (C) 2004-2013 Giles C Williams and contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
MA 02110-1301, USA.

 */

#import "OOExhaustPlumeEntity.h"
#import "OOJSExhaustPlume.h"
#import "OOJSEntity.h"
#import "OOJSVector.h"
#import "OOJavaScriptEngine.h"
#import "EntityOOJavaScriptExtensions.h"
#import "ShipEntity.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>
#include <cstdint>

/*
	Retargeted onto the ooscript facade (JSEngine.hpp) the way OOJSVector.mm and
	OOJSWaypoint.mm do it (bead oo-sdz, the sweep exemplar): the class dispatch table becomes
	a static ooscript::ClassDef (the stub hooks are nullptr), InitClass becomes
	ooscript::initClass, and the property getter/setter and finalize/construct hooks take the
	facade's own signature (ooscript::Context / Object / PropertyId / Value pointer /
	CallArgs reference) rather than the engine's, with tiny shims recovering the old
	JSContext*, JSObject* and jsval* locals so the OOJS_* argument-marshalling macros and the
	rest of each function body are unchanged. `this` is renamed to `thisObj` because it is a
	reserved word once this file compiles as Objective-C++ (ADR-0001). ExhaustPlumeRemove
	similarly recovers a JSContext pointer and jsval pointer pair from its CallArgs so the
	shared GET_THIS_EXHAUSTPLUME/OOJS_NATIVE_ENTER/OOJS_RETURN_VOID macros are untouched.
*/
namespace ooscript { }
using ooscript::Context;
using ooscript::Object;
using ooscript::Value;
using ooscript::PropertyId;
using ooscript::CallArgs;
using ooscript::ClassDef;
using ooscript::ClassFlag;
using ooscript::PropertyFlag;
using ooscript::PropertySpec;
using ooscript::FunctionSpec;

// Byte-identical facade <-> jsapi views, local to this call site (see OOJSVector.mm /
// OOJSWaypoint.mm).
namespace {
static inline Context    OOJSFCX(JSContext *cx)   { return reinterpret_cast<Context>(cx); }
} // namespace
namespace {
static inline JSContext *OOJSRCX(Context cx)      { return reinterpret_cast<JSContext*>(cx); }
} // namespace
namespace {
static inline Object     OOJSFOBJ(JSObject *o)    { return reinterpret_cast<Object>(o); }
} // namespace
namespace {
static inline JSObject  *OOJSROBJ(Object o)       { return reinterpret_cast<JSObject*>(o); }
} // namespace
namespace {
static inline jsval     *OOJSRVAL(Value *v)       { return reinterpret_cast<jsval*>(v); }
} // namespace
namespace {
static inline jsid       OOJSRJSID(PropertyId id) { jsid r; std::memcpy(&r, &id, sizeof r); return r; }
} // namespace


namespace {
static JSObject *sExhaustPlumePrototype;
} // namespace


namespace {
static BOOL JSExhaustPlumeGetExhaustPlumeEntity(JSContext *context, JSObject *jsobj, OOExhaustPlumeEntity **outEntity);
} // namespace


namespace {
static bool ExhaustPlumeGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool ExhaustPlumeSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace

namespace {
static bool ExhaustPlumeRemove(Context cx, CallArgs &oojsArgs);
} // namespace


// Adapts the shared jsapi finalizer (OOJavaScriptEngine.m) to the facade's FinalizeHook
// signature; the finalizer itself is untouched, shared plumbing outside this bead's scope
// (see OOJSWaypoint.mm's WaypointFinalize).
namespace {
static void ExhaustPlumeFinalize(Context cx, Object obj)
{
	OOJSObjectWrapperFinalize(OOJSRCX(cx), OOJSROBJ(obj));
}
} // namespace


// Adapts the shared jsapi OOJSUnconstructableConstruct (OOJavaScriptEngine.m) to the
// facade's NativeFn signature (see OOJSWaypoint.mm's WaypointUnconstructableConstruct).
namespace {
static bool ExhaustPlumeUnconstructableConstruct(Context cx, CallArgs &oojsArgs)
{
	return OOJSUnconstructableConstruct(OOJSRCX(cx), oojsArgs.count(), OOJSRVAL(oojsArgs.rawVp()));
}
} // namespace


namespace {
static ClassDef sExhaustPlumeClass =
{
	"ExhaustPlume",
	ClassFlag::HasPrivate,

	nullptr,			// addProperty (engine default: PropertyStub)
	nullptr,			// delProperty (engine default: PropertyStub)
	ExhaustPlumeGetProperty,	// getProperty
	ExhaustPlumeSetProperty,	// setProperty
	nullptr,			// enumerate (engine default: EnumerateStub)
	nullptr,			// newEnumerate (JSCLASS_NEW_ENUMERATE not used)
	nullptr,			// resolve (engine default: ResolveStub)
	nullptr,			// convert (engine default: ConvertStub)
	ExhaustPlumeFinalize,		// finalize
	nullptr,			// call
	nullptr,			// construct
	nullptr,			// backend: owned by the facade backend, must start null
};
} // namespace


enum : std::uint8_t
{
	// Property IDs
	kExhaustPlume_size
};


// A raw jsapi mirror, used only for the two bad-property error reporters in
// OOJavaScriptEngine.m (OOJSReportBadPropertySelector/Value): those helpers are outside
// this bead's scope (shared across every binding file) and still take a JSPropertySpec*,
// not ooscript::PropertySpec* (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static JSPropertySpec sExhaustPlumePropertiesRaw[] =
{
	// JS name							ID									flags
	{ "size",	   			kExhaustPlume_size,	  		OOJS_PROP_READWRITE_CB },
	{ 0 }
};
} // namespace


namespace {
static PropertySpec sExhaustPlumeProperties[] =
{
	// JS name							ID								flags									getter		setter
	{ "size",						kExhaustPlume_size,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sExhaustPlumeMethods[] =
{
	// JS name					Function						min args	flags
	{ "remove",         ExhaustPlumeRemove,    0,	0 },

	{ 0 }
};
} // namespace


void InitOOJSExhaustPlume(JSContext *context, JSObject *global)
{
	Object proto = ooscript::initClass(OOJSFCX(context), OOJSFOBJ(global), OOJSFOBJ(JSEntityPrototype()), &sExhaustPlumeClass, ExhaustPlumeUnconstructableConstruct, 0, sExhaustPlumeProperties, sExhaustPlumeMethods, nullptr, nullptr);
	sExhaustPlumePrototype = OOJSROBJ(proto);
	OOJSRegisterObjectConverter(reinterpret_cast<JSClass*>(sExhaustPlumeClass.backend), OOJSBasicPrivateObjectConverter);
	OOJSRegisterSubclass(reinterpret_cast<JSClass*>(sExhaustPlumeClass.backend), JSEntityClass());
}


namespace {
static BOOL JSExhaustPlumeGetExhaustPlumeEntity(JSContext *context, JSObject *jsobj, OOExhaustPlumeEntity **outEntity)
{
	OOJS_PROFILE_ENTER
	
	BOOL						result;
	Entity						*entity = nil;
	
	if (outEntity == NULL)  return NO;
	*outEntity = nil;
	
	result = OOJSEntityGetEntity(context, jsobj, &entity);
	if (!result)  return NO;
	
	if (![entity isKindOfClass:[OOExhaustPlumeEntity class]])  return NO;
	
	*outEntity = (OOExhaustPlumeEntity *)entity;
	return YES;
	
	OOJS_PROFILE_EXIT
}
} // namespace


@implementation OOExhaustPlumeEntity (OOJavaScriptExtensions)

- (void)getJSClass:(JSClass **)outClass andPrototype:(JSObject **)outPrototype
{
	*outClass = reinterpret_cast<JSClass*>(sExhaustPlumeClass.backend);
	*outPrototype = sExhaustPlumePrototype;
}


- (NSString *) oo_jsClassName
{
	return @"ExhaustPlume";
}

- (BOOL) isVisibleToScripts
{
	return YES;
}

@end


namespace {
static bool ExhaustPlumeGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *value_raw = OOJSRVAL(value);
	
	OOJS_NATIVE_ENTER(context)
	
	OOExhaustPlumeEntity				*entity = nil;
	id result = nil;
	
	if (!JSExhaustPlumeGetExhaustPlumeEntity(context, thisObj, &entity))  return NO;
	if (entity == nil)  { *value_raw = JSVAL_VOID; return YES; }
	
	switch (ooscript::idToInt32(propID))
	{
		case kExhaustPlume_size:
			return VectorToJSValue(context, [entity scale], value_raw);

		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sExhaustPlumePropertiesRaw);
			return NO;
	}

	*value_raw = OOJSValueFromNativeObject(context, result);
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool ExhaustPlumeSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *value_raw = OOJSRVAL(value);
	
	OOJS_NATIVE_ENTER(context)
	
	OOExhaustPlumeEntity				*entity = nil;
	Vector          vValue;
	
	if (!JSExhaustPlumeGetExhaustPlumeEntity(context, thisObj, &entity)) return NO;
	if (entity == nil)  return YES;
	
	switch (ooscript::idToInt32(propID))
	{
		case kExhaustPlume_size:
			if (JSValueToVector(context, *value_raw, &vValue))
			{
				[entity setScale:vValue];
				return YES;
			}
			break;

		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sExhaustPlumePropertiesRaw);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, OOJSRJSID(propID), sExhaustPlumePropertiesRaw, *value_raw);
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// *** Methods ***

#define GET_THIS_EXHAUSTPLUME(THISENT) do { \
	if (EXPECT_NOT(!JSExhaustPlumeGetExhaustPlumeEntity(context, OOJS_THIS, &(THISENT))))  return NO; /* Exception */ \
	if (OOIsStaleEntity(THISENT))  OOJS_RETURN_VOID; \
} while (0)


namespace {
static bool ExhaustPlumeRemove(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	OOJS_NATIVE_ENTER(context)
	
	OOExhaustPlumeEntity				*thisEnt = nil;
	GET_THIS_EXHAUSTPLUME(thisEnt);
	
	ShipEntity				*parent = [thisEnt owner];
	[parent removeExhaust:thisEnt];

	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace
