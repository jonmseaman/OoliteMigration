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
#import "OOFoundationBridge.h"

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

	Waypoint is registered as an Entity subclass and object converter with &sWaypointClass, the
	same ooscript::ClassDef that ooscript::getClass() reports for its instances.
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
static ooscript::Object sWaypointPrototype;
} // namespace

namespace {
static BOOL JSWaypointGetWaypointEntity(ooscript::Context context, ooscript::Object stationObj, OOWaypointEntity **outEntity);
} // namespace


namespace {
static bool WaypointGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool WaypointSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
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
	nullptr,			// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,			// resolve (engine default: ResolveStub)
	nullptr,			// convert (engine default: ConvertStub)
	OOJSObjectWrapperFinalize,		// finalize
	nullptr,			// call
	nullptr,			// construct
	nullptr,			// backend: owned by the façade backend, must start null
};
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
// ooscript::PropertySpec*, not ooscript::PropertySpec* (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static ooscript::PropertySpec sWaypointPropertiesRaw[] =
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


void InitOOJSWaypoint(ooscript::Context context, ooscript::Object global)
{
	Object proto = ooscript::initClass((context), (global), (JSEntityPrototype()), &sWaypointClass, OOJSUnconstructableConstruct, 0, sWaypointProperties, sWaypointMethods, nullptr, nullptr);
	sWaypointPrototype = (proto);
	OOJSRegisterObjectConverter(&sWaypointClass, OOJSBasicPrivateObjectConverter);
	OOJSRegisterSubclass(&sWaypointClass, JSEntityClass());
}


namespace {
static BOOL JSWaypointGetWaypointEntity(ooscript::Context context, ooscript::Object wormholeObj, OOWaypointEntity **outEntity)
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

- (void)getJSClass:(ooscript::ClassDef **)outClass andPrototype:(ooscript::Object *)outPrototype
{
	*outClass = &sWaypointClass;
	*outPrototype = sWaypointPrototype;
}


- (id) oo_jsClassName	// shared selector (proposed ADR-0043)
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
	
	ooscript::Context context = reinterpret_cast<ooscript::Context >(cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = reinterpret_cast<ooscript::Value*>(value);
	
	OOJS_NATIVE_ENTER(context)
	
	OOWaypointEntity				*entity = nil;
	id result = nil;
	Quaternion q = kIdentityQuaternion;

	if (!JSWaypointGetWaypointEntity(context, thisObj, &entity))  return NO;
	if (entity == nil)  { *value_raw = ooscript::undefinedValue(); return YES; }
	
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
		OOJSReportBadPropertySelector(context, thisObj, (propID), sWaypointPropertiesRaw);
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
	
	ooscript::Context context = reinterpret_cast<ooscript::Context >(cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = reinterpret_cast<ooscript::Value*>(value);

	OOJS_NATIVE_ENTER(context)

	OOWaypointEntity				*entity = nil;
	double        fValue;
	std::optional<std::string>	sValue;
	Quaternion			qValue;

	if (!JSWaypointGetWaypointEntity(context, thisObj, &entity)) return NO;
	if (entity == nil)  return YES;
	
	switch (ooscript::idToInt32(propID))
	{
		case kWaypoint_beaconCode:
			sValue = oo::OptionalString(OOStringFromJSValue(context,*value_raw));
			if (!sValue.has_value() || sValue->empty()) 
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
					[entity setBeaconCode:oo::NSStringFrom(*sValue)];
				}
				else // Universe needs to update beacon lists in this case only
				{
					[entity setBeaconCode:oo::NSStringFrom(*sValue)];
					[UNIVERSE setNextBeacon:entity];
				}
			}
			return YES;
			break;

		case kWaypoint_beaconLabel:
			sValue = oo::OptionalString(OOStringFromJSValue(context,*value_raw));
			if (sValue.has_value())
			{
				[entity setBeaconLabel:oo::NSStringFrom(*sValue)];
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
			OOJSReportBadPropertySelector(context, thisObj, (propID), sWaypointPropertiesRaw);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, (propID), sWaypointPropertiesRaw, *value_raw);
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// *** Methods ***
