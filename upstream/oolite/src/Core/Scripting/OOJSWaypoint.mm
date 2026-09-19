/*
OOJSWaypoint.m

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

#import "OOWaypointEntity.h"
#import "OOJSWaypoint.h"
#import "OOJSEntity.h"
#import "OOJSVector.h"
#import "OOJSQuaternion.h"
#import "OOJavaScriptEngine.h"
#import "EntityOOJavaScriptExtensions.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>
#include <cstdint>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar): the class dispatch table becomes a static ooscript::ClassDef
	(the stub hooks are nullptr), InitClass becomes ooscript::initClass, and the two directly
	spelled numeric-conversion calls become ooscript::newNumberValue/valueToNumber. `this` is
	renamed to `thisObj` because it is a reserved word once this file compiles as
	Objective-C++ (ADR-0001).

	Waypoint is registered as an Entity subclass and object converter with the ENGINE's own
	JSClass* (OOJSRegisterSubclass/OOJSRegisterObjectConverter and getJSClass:andPrototype:
	are shared, not-yet-retargeted plumbing that still speaks jsapi's JSClass, and
	JSEntityClass() -- OOJSEntity.m, bead oo-oap -- still returns one too). ClassDef's
	`backend` slot is a BackendClass* whose first member is the real JSClass (JSEngine_spidermonkey.cpp:
	"JSClass is the first member ... so a JSClass* the engine hands back converts to its
	BackendClass*"), and it is filled in by ooscript::initClass() before InitOOJSWaypoint()
	makes those calls, so RawWaypointClass() below is a reinterpret_cast onto already-attached
	storage, not a conversion.
*/
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

// Byte-identical façade <-> jsapi views, local to this call site (see OOJSVector.mm).
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
static JSObject		*sWaypointPrototype;
} // namespace

namespace {
static BOOL JSWaypointGetWaypointEntity(JSContext *context, JSObject *stationObj, OOWaypointEntity **outEntity);
} // namespace


namespace {
static bool WaypointGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool WaypointSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace


// Adapts the shared jsapi finalizer (OOJavaScriptEngine.m) to the façade's FinalizeHook
// signature; the finalizer itself is untouched, shared plumbing outside this bead's scope.
namespace {
static void WaypointFinalize(Context cx, Object obj)
{
	OOJSObjectWrapperFinalize(reinterpret_cast<JSContext*>(cx), reinterpret_cast<JSObject*>(obj));
}
} // namespace


// Adapts the shared jsapi OOJSUnconstructableConstruct (OOJavaScriptEngine.m) to the façade's
// NativeFn signature, so `new Waypoint()` keeps throwing "Waypoint cannot be used as a
// constructor." as it did before retargeting (originally passed directly as the constructor
// argument to the engine's own class-init call).
namespace {
static bool WaypointUnconstructableConstruct(Context cx, CallArgs &oojsArgs)
{
	return OOJSUnconstructableConstruct(reinterpret_cast<JSContext*>(cx), oojsArgs.count(), reinterpret_cast<jsval*>(oojsArgs.rawVp()));
}
} // namespace


namespace {
static ClassDef sWaypointClass =
{
	"Waypoint",
	ClassFlag::HasPrivate,
	
	nullptr,			// addProperty (engine default: PropertyStub)
	nullptr,			// delProperty (engine default: PropertyStub)
	WaypointGetProperty,		// getProperty
	WaypointSetProperty,		// setProperty
	nullptr,			// enumerate (engine default: EnumerateStub)
	nullptr,			// newEnumerate (JSCLASS_NEW_ENUMERATE not used)
	nullptr,			// resolve (engine default: ResolveStub)
	nullptr,			// convert (engine default: ConvertStub)
	WaypointFinalize,		// finalize
	nullptr,			// call
	nullptr,			// construct
	nullptr,			// backend: owned by the façade backend, must start null
};
} // namespace


// The engine's own JSClass* for sWaypointClass, for the not-yet-retargeted plumbing
// (OOJSRegisterSubclass/OOJSRegisterObjectConverter, getJSClass:andPrototype:) that still
// takes one; see the comment above. Valid only after InitOOJSWaypoint() has called
// ooscript::initClass(), which is the only thing that attaches sWaypointClass.backend.
namespace {
static inline JSClass *RawWaypointClass(void)
{
	return reinterpret_cast<JSClass*>(sWaypointClass.backend);
}
} // namespace


enum : std::uint8_t
{
	// Property IDs
	kWaypoint_beaconCode,
	kWaypoint_beaconLabel,
	kWaypoint_orientation, // overrides entity as waypoints can be unoriented
	kWaypoint_size
};


namespace {
static PropertySpec sWaypointProperties[] =
{
	// JS name							ID						flags								getter	setter
	{ "beaconCode",	    kWaypoint_beaconCode,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "beaconLabel",	kWaypoint_beaconLabel,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "orientation",	kWaypoint_orientation,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "size",	     	kWaypoint_size,	      	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ 0 }
};
} // namespace


// A raw jsapi mirror of sWaypointProperties, used only for the two bad-property error
// reporters in OOJavaScriptEngine.m (OOJSReportBadPropertySelector/Value): those helpers are
// outside this bead's scope (shared across every binding file) and still take a
// JSPropertySpec*, not ooscript::PropertySpec* (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static JSPropertySpec sWaypointPropertiesRaw[] =
{
	// JS name							ID						flags
	{ "beaconCode",	    kWaypoint_beaconCode,	OOJS_PROP_READWRITE_CB },
	{ "beaconLabel",	kWaypoint_beaconLabel,	OOJS_PROP_READWRITE_CB },
	{ "orientation",	kWaypoint_orientation,	OOJS_PROP_READWRITE_CB },
	{ "size",	     	kWaypoint_size,	      	OOJS_PROP_READWRITE_CB },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sWaypointMethods[] =
{
	// JS name					Function						min args	flags
//	{ "",     WaypointDoStuff,    0,	0 },
	{ 0 }
};
} // namespace


void InitOOJSWaypoint(JSContext *context, JSObject *global)
{
	Object proto = ooscript::initClass(OOJSFCX(context), OOJSFOBJ(global), OOJSFOBJ(JSEntityPrototype()), &sWaypointClass, WaypointUnconstructableConstruct, 0, sWaypointProperties, sWaypointMethods, nullptr, nullptr);
	sWaypointPrototype = OOJSROBJ(proto);
	OOJSRegisterObjectConverter(RawWaypointClass(), OOJSBasicPrivateObjectConverter);
	OOJSRegisterSubclass(RawWaypointClass(), JSEntityClass());
}


namespace {
static BOOL JSWaypointGetWaypointEntity(JSContext *context, JSObject *wormholeObj, OOWaypointEntity **outEntity)
{
	OOJS_PROFILE_ENTER
	
	BOOL						result;
	Entity						*entity = nil;
	
	if (outEntity == NULL)  return NO;
	*outEntity = nil;
	
	result = OOJSEntityGetEntity(context, wormholeObj, &entity);
	if (!result)  return NO;
	
	if (![entity isKindOfClass:[OOWaypointEntity class]])  return NO;
	
	*outEntity = (OOWaypointEntity *)entity;
	return YES;
	
	OOJS_PROFILE_EXIT
}
} // namespace


@implementation OOWaypointEntity (OOJavaScriptExtensions)

- (void)getJSClass:(JSClass **)outClass andPrototype:(JSObject **)outPrototype
{
	*outClass = RawWaypointClass();
	*outPrototype = sWaypointPrototype;
}


- (NSString *) oo_jsClassName
{
	return @"Waypoint";
}

- (BOOL) isVisibleToScripts
{
	return YES;
}

@end


namespace {
static bool WaypointGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = reinterpret_cast<JSContext*>(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *value_raw = reinterpret_cast<jsval*>(value);
	
	OOJS_NATIVE_ENTER(context)
	
	OOWaypointEntity				*entity = nil;
	id result = nil;
	Quaternion q = kIdentityQuaternion;

	if (!JSWaypointGetWaypointEntity(context, thisObj, &entity))  return NO;
	if (entity == nil)  { *value_raw = JSVAL_VOID; return YES; }
	
	switch (ooscript::idToInt32(propID))
	{
	case kWaypoint_beaconCode:
		result = [entity beaconCode];
		break;

	case kWaypoint_beaconLabel:
		result = [entity beaconLabel];
		break;

	case kWaypoint_orientation:
		q = [entity orientation];
		if (![entity oriented])
		{
			q = kZeroQuaternion;
		}
		return QuaternionToJSValue(context, q, value_raw);
		
	case kWaypoint_size:
		return ooscript::newNumberValue(cx, [entity size], value);

	default:
		OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sWaypointPropertiesRaw);
		return NO;
	}

	*value_raw = OOJSValueFromNativeObject(context, result);
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool WaypointSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = reinterpret_cast<JSContext*>(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *value_raw = reinterpret_cast<jsval*>(value);

	OOJS_NATIVE_ENTER(context)

	OOWaypointEntity				*entity = nil;
	jsdouble        fValue;
	NSString					*sValue = nil;
	Quaternion			qValue;

	if (!JSWaypointGetWaypointEntity(context, thisObj, &entity)) return NO;
	if (entity == nil)  return YES;
	
	switch (ooscript::idToInt32(propID))
	{
		case kWaypoint_beaconCode:
			sValue = OOStringFromJSValue(context,*value_raw);
			if (sValue == nil || [sValue length] == 0) 
			{
				if ([entity isBeacon]) 
				{
					[UNIVERSE clearBeacon:entity];
					if ([PLAYER nextBeacon] == entity)
					{
						[PLAYER setCompassMode:COMPASS_MODE_PLANET];
					}
				}
			}
			else 
			{
				if ([entity isBeacon]) 
				{
					[entity setBeaconCode:sValue];
				}
				else // Universe needs to update beacon lists in this case only
				{
					[entity setBeaconCode:sValue];
					[UNIVERSE setNextBeacon:entity];
				}
			}
			return YES;
			break;

		case kWaypoint_beaconLabel:
			sValue = OOStringFromJSValue(context,*value_raw);
			if (sValue != nil)
			{
				[entity setBeaconLabel:sValue];
				return YES;
			}
			break;

		case kWaypoint_orientation:
			if (JSValueToQuaternion(context, *value_raw, &qValue))
			{
				[entity setNormalOrientation:qValue];
				return YES;
			}
			break;

		case kWaypoint_size:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				if (fValue > 0.0)
				{
					[entity setSize:fValue];
					return YES;
				}
			}
			break;

		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sWaypointPropertiesRaw);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, OOJSRJSID(propID), sWaypointPropertiesRaw, *value_raw);
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// *** Methods ***
