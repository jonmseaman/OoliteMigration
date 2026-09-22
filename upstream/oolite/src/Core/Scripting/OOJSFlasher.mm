/*
OOJSFlasher.mm

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

#import "OOFlasherEntity.h"
#import "OOJSFlasher.h"
#import "OOJSEntity.h"
#import "OOJSVector.h"
#import "OOJavaScriptEngine.h"
#import "EntityOOJavaScriptExtensions.h"
#import "ShipEntity.h"
#import "OOVisualEffectEntity.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>
#include <cstdint>

// Retargeted onto the ooscript facade (JSEngine.hpp), the way OOJSVector.mm and
// OOJSWormhole.mm do it (bead oo-sdz exemplar): stub hooks become nullptr, InitClass
// becomes ooscript::initClass, numeric/boolean conversion becomes
// ooscript::newNumberValue/valueToNumber/valueToBoolean, and `this` is renamed to `thisObj`
// (reserved word in Objective-C++, ADR-0001).
namespace ooscript { }
using ooscript::Context;
using ooscript::Object;
using ooscript::Value;
using ooscript::PropertyId;
using ooscript::ClassDef;
using ooscript::ClassFlag;
using ooscript::PropertyFlag;
using ooscript::PropertySpec;
using ooscript::FunctionSpec;
using ooscript::CallArgs;

// Byte-identical facade <-> jsapi views, local to this call site (see OOJSVector.mm).
namespace {
static inline Context    OOJSFCX(JSContext *cx)   { return reinterpret_cast<Context>(cx); }
} // namespace
namespace {
static inline Object     OOJSFOBJ(JSObject *o)    { return reinterpret_cast<Object>(o); }
} // namespace
namespace {
static inline JSObject  *OOJSROBJ(Object o)       { return reinterpret_cast<JSObject*>(o); }
} // namespace
namespace {
static inline jsid       OOJSRJSID(PropertyId id) { jsid r; std::memcpy(&r, &id, sizeof r); return r; }
} // namespace
namespace {
static inline Value      OOJSFVAL(jsval v)        { Value r; std::memcpy(&r, &v, sizeof r); return r; }
} // namespace


namespace {
static JSObject		*sFlasherPrototype;
} // namespace

namespace {
static BOOL JSFlasherGetFlasherEntity(JSContext *context, JSObject *jsobj, OOFlasherEntity **outEntity);
} // namespace


namespace {
static bool FlasherGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool FlasherSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value);
} // namespace

namespace {
static bool FlasherRemove(Context cx, CallArgs &oojsArgs);
} // namespace


// Adapts the shared jsapi finalizer to the facade's FinalizeHook signature (see OOJSWormhole.mm).
namespace {
static void FlasherFinalize(Context cx, Object obj)
{
	OOJSObjectWrapperFinalize(reinterpret_cast<JSContext*>(cx), reinterpret_cast<JSObject*>(obj));
}
} // namespace


// Adapts the shared jsapi OOJSUnconstructableConstruct to the facade's NativeFn signature
// (see OOJSWormhole.mm).
namespace {
static bool FlasherUnconstructableConstruct(Context cx, CallArgs &oojsArgs)
{
	return OOJSUnconstructableConstruct(reinterpret_cast<JSContext*>(cx), oojsArgs.count(), reinterpret_cast<jsval*>(oojsArgs.rawVp()));
}
} // namespace


namespace {
static ClassDef sFlasherClass =
{
	"Flasher",
	ClassFlag::HasPrivate,
	
	nullptr,		// addProperty
	nullptr,		// delProperty
	FlasherGetProperty,		// getProperty
	FlasherSetProperty,		// setProperty
	nullptr,		// enumerate
	nullptr,			// newEnumerate (JSCLASS_NEW_ENUMERATE not used)
	nullptr,			// resolve
	nullptr,			// convert
	FlasherFinalize,// finalize
	nullptr,			// call
	nullptr,			// construct
	nullptr,			// backend: owned by the facade backend, must start null
};
} // namespace


// The engine's own JSClass* for sFlasherClass, needed by shared jsapi plumbing that has
// not yet been retargeted (see OOJSWormhole.mm's RawWormholeClass).
namespace {
static inline JSClass *RawFlasherClass(void)
{
	return reinterpret_cast<JSClass*>(sFlasherClass.backend);
}
} // namespace


enum : std::uint8_t
{
	// Property IDs
	kFlasher_active,
	kFlasher_color,
	kFlasher_fraction,
	kFlasher_frequency,
	kFlasher_phase,
	kFlasher_size
};


namespace {
static PropertySpec sFlasherProperties[] =
{
	// JS name							ID									flags
	{ "active",	   			kFlasher_active,  		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "color",	   			kFlasher_color,	  		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "fraction",  			kFlasher_fraction,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "frequency", 			kFlasher_frequency,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "phase",	   			kFlasher_phase,	  		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "size",	   			kFlasher_size,	  		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ 0 }
};
} // namespace


// Raw jsapi mirror of sFlasherProperties for the shared error reporters that still take a
// JSPropertySpec* (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static JSPropertySpec sFlasherPropertiesRaw[] =
{
	// JS name							ID									flags
	{ "active",	   			kFlasher_active,  		OOJS_PROP_READWRITE_CB },
	{ "color",	   			kFlasher_color,	  		OOJS_PROP_READWRITE_CB },
	{ "fraction",  			kFlasher_fraction,		OOJS_PROP_READWRITE_CB },
	{ "frequency", 			kFlasher_frequency,		OOJS_PROP_READWRITE_CB },
	{ "phase",	   			kFlasher_phase,	  		OOJS_PROP_READWRITE_CB },
	{ "size",	   			kFlasher_size,	  		OOJS_PROP_READWRITE_CB },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sFlasherMethods[] =
{
	// JS name					Function						min args	flags
	{ "remove",         FlasherRemove,    0,	0 },

	{ 0 }
};
} // namespace


void InitOOJSFlasher(JSContext *context, JSObject *global)
{
	Object proto = ooscript::initClass(OOJSFCX(context), OOJSFOBJ(global), OOJSFOBJ(JSEntityPrototype()), &sFlasherClass, FlasherUnconstructableConstruct, 0, sFlasherProperties, sFlasherMethods, NULL, NULL);
	sFlasherPrototype = OOJSROBJ(proto);
	OOJSRegisterObjectConverter(RawFlasherClass(), OOJSBasicPrivateObjectConverter);
	OOJSRegisterSubclass(RawFlasherClass(), JSEntityClass());
}


namespace {
static BOOL JSFlasherGetFlasherEntity(JSContext *context, JSObject *jsobj, OOFlasherEntity **outEntity)
{
	OOJS_PROFILE_ENTER
	
	BOOL						result;
	Entity						*entity = nil;
	
	if (outEntity == NULL)  return NO;
	*outEntity = nil;
	
	result = OOJSEntityGetEntity(context, jsobj, &entity);
	if (!result)  return NO;
	
	if (![entity isKindOfClass:[OOFlasherEntity class]])  return NO;
	
	*outEntity = (OOFlasherEntity *)entity;
	return YES;
	
	OOJS_PROFILE_EXIT
}
} // namespace


@implementation OOFlasherEntity (OOJavaScriptExtensions)

- (void)getJSClass:(JSClass **)outClass andPrototype:(JSObject **)outPrototype
{
	*outClass = RawFlasherClass();
	*outPrototype = sFlasherPrototype;
}


- (NSString *) oo_jsClassName
{
	return @"Flasher";
}

- (BOOL) isVisibleToScripts
{
	return YES;
}

@end


namespace {
static bool FlasherGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = reinterpret_cast<JSContext*>(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *value_raw = reinterpret_cast<jsval*>(value);
	
	OOJS_NATIVE_ENTER(context)
	
	OOFlasherEntity				*entity = nil;
	id result = nil;
	
	if (!JSFlasherGetFlasherEntity(context, thisObj, &entity))  return NO;
	if (entity == nil)  { *value_raw = JSVAL_VOID; return YES; }
	
	switch (ooscript::idToInt32(propID))
	{
		case kFlasher_active:
			*value_raw = OOJSValueFromBOOL([entity isActive]);
			return YES;

		case kFlasher_color:
			result = [[entity color] normalizedArray];
			break;

		case kFlasher_frequency:
			return ooscript::newNumberValue(cx, [entity frequency], value);

		case kFlasher_fraction:
			return ooscript::newNumberValue(cx, [entity fraction], value);

		case kFlasher_phase:
			return ooscript::newNumberValue(cx, [entity phase], value);

		case kFlasher_size:
			return ooscript::newNumberValue(cx, [entity diameter], value);

		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sFlasherPropertiesRaw);
			return NO;
	}

	*value_raw = OOJSValueFromNativeObject(context, result);
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool FlasherSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = reinterpret_cast<JSContext*>(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *value_raw = reinterpret_cast<jsval*>(value);
	
	OOJS_NATIVE_ENTER(context)
	
	OOFlasherEntity		*entity = nil;
	jsdouble          	fValue;
	bool				bValue;
	OOColor				*colorForScript = nil;
	
	if (!JSFlasherGetFlasherEntity(context, thisObj, &entity)) return NO;
	if (entity == nil)  return YES;
	
	switch (ooscript::idToInt32(propID))
	{
		case kFlasher_active:
			if (ooscript::valueToBoolean(cx, OOJSFVAL(*value_raw), &bValue))
			{
				[entity setActive:(BOOL)bValue];
				return YES;
			}
			break;

		case kFlasher_color:
			colorForScript = [OOColor colorWithDescription:OOJSNativeObjectFromJSValue(context, *value_raw)];
			if (colorForScript != nil || JSVAL_IS_NULL(*value_raw))
			{
				[entity setColor:colorForScript];
				return YES;
			}
			break;

		case kFlasher_frequency:
			if (ooscript::valueToNumber(cx, OOJSFVAL(*value_raw), &fValue))
			{
				if (fValue >= 0.0)
				{
					[entity setFrequency:fValue];
					return YES;
				}
			}
			break;

		case kFlasher_fraction:
			if (ooscript::valueToNumber(cx, OOJSFVAL(*value_raw), &fValue))
			{
				if (fValue > 0.0 && fValue <= 1.0)
				{
					[entity setFraction:fValue];
					return YES;
				}
			}
			break;

		case kFlasher_phase:
			if (ooscript::valueToNumber(cx, OOJSFVAL(*value_raw), &fValue))
			{
				[entity setPhase:fValue];
				return YES;
			}
			break;

		case kFlasher_size:
			if (ooscript::valueToNumber(cx, OOJSFVAL(*value_raw), &fValue))
			{
				if (fValue > 0.0)
				{
					[entity setDiameter:fValue];
					return YES;
				}
			}
			break;

		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sFlasherPropertiesRaw);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, OOJSRJSID(propID), sFlasherPropertiesRaw, *value_raw);
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// *** Methods ***

#define GET_THIS_FLASHER(THISENT) do { \
	if (EXPECT_NOT(!JSFlasherGetFlasherEntity(context, OOJS_THIS, &(THISENT))))  return NO; /* Exception */ \
	if (OOIsStaleEntity(THISENT))  OOJS_RETURN_VOID; \
} while (0)


namespace {
static bool FlasherRemove(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = reinterpret_cast<JSContext*>(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = reinterpret_cast<jsval*>(oojsArgs.rawVp());
	(void)argc;
	(void)vp;
	
	OOJS_NATIVE_ENTER(context)
	
	OOFlasherEntity				*thisEnt = nil;
	GET_THIS_FLASHER(thisEnt);
	
	Entity				*parent = [thisEnt owner];
	if ([parent isShip])
	{
		[(ShipEntity *)parent removeFlasher:thisEnt];
	}
	else
	{
		[(OOVisualEffectEntity *)parent removeSubEntity:thisEnt];
	}

	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace
