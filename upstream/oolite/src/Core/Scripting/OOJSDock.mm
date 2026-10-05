/*
OOJSDock.m

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

#import "OOJSDock.h"
#import "OOJSEntity.h"
#import "OOJSShip.h"
#import "OOJSPlayer.h"
#import "OOJavaScriptEngine.h"

#import "DockEntity.h"
#import "GameController.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar): the class dispatch table is a static ooscript::ClassDef (the
	stub hooks are nullptr), native methods and class hooks take the façade's hook signatures
	(Context/Object/PropertyId/Value pointer/CallArgs reference) directly, and the shared
	OOJavaScriptEngine helpers (OOJSObjectWrapperFinalize, OOJSUnconstructableConstruct,
	OOJSRegisterSubclass, OOJSRegisterObjectConverter) are used as the class's hooks and
	registrations with &sDockClass itself. `this` is renamed to `thisObj` because it is a
	reserved word once this file compiles as Objective-C++ (ADR-0001).
*/

/*
	C++20 since bead oo-zbx3, converted the way bead oo-ppc converted OOJSVector.mm (proposed
	ADR-0056 amendment oo-ppc). The JS class was already C++ on the ooscript façade;
	OOJS_NATIVE_ENTER/EXIT and OOJS_PROFILE_ENTER/EXIT are C++ try/catch and scope guards
	(OOJSEngineNativeWrappers.h); BOOL/YES/NO are bool/true/false. The category on DockEntity
	became two free functions, and its methods moved to OOJSDock+ObjCBridge.mm (amendment oo-
	ykoy). Messages to classes that are still Objective-C (DockEntity, ShipEntity, Entity) stay
	as they are, which is why the file is still .mm until Phase 4.
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

namespace {
static ooscript::Object sDockPrototype;
} // namespace

namespace {
static bool JSDockGetDockEntity(ooscript::Context context, ooscript::Object stationObj, DockEntity **outEntity);
} // namespace
namespace {
static bool JSDockGetShipEntity(ooscript::Context context, ooscript::Object shipObj, ShipEntity **outEntity);
} // namespace

namespace {
static bool DockIsQueued(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace


namespace {
static bool DockGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool DockSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace


namespace {
static ClassDef sDockClass =
{
	"Dock",
	ClassFlag::HasPrivate,

	nullptr,			// addProperty (engine default: PropertyStub)
	nullptr,			// delProperty (engine default: PropertyStub)
	DockGetProperty,	// getProperty
	DockSetProperty,	// setProperty
	nullptr,			// enumerate (engine default: EnumerateStub)
	nullptr,			// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,			// resolve (engine default: ResolveStub)
	nullptr,			// convert (engine default: ConvertStub)
	OOJSObjectWrapperFinalize,	// finalize
	nullptr,			// call
	nullptr,			// construct
	nullptr,			// backend: owned by the façade backend, must start null
};
} // namespace


enum : std::uint8_t
{
	// Property IDs
	kDock_allowsDocking,
	kDock_disallowedDockingCollides,
	kDock_allowsLaunching,
	kDock_dockingQueueLength,
	kDock_launchingQueueLength
};


namespace {
static PropertySpec sDockProperties[] =
{
	// JS name						ID									flags
	{ "allowsDocking",				kDock_allowsDocking,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "disallowedDockingCollides",				kDock_disallowedDockingCollides,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "allowsLaunching",				kDock_allowsLaunching,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "dockingQueueLength",				kDock_dockingQueueLength,			OOJS_PROP_READONLY_CB, nullptr, nullptr },
	{ "launchingQueueLength",				kDock_launchingQueueLength,			OOJS_PROP_READONLY_CB, nullptr, nullptr },
	{ 0 }
};
} // namespace


// A mirror of sDockProperties with the read-only/read-write flags the two bad-property error
// reporters in OOJavaScriptEngine.mm (OOJSReportBadPropertySelector/Value) describe the
// properties by (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static ooscript::PropertySpec sDockPropertiesRaw[] =
{
	{ "allowsDocking",				kDock_allowsDocking,			OOJS_PROP_READWRITE_CB },
	{ "disallowedDockingCollides",				kDock_disallowedDockingCollides,			OOJS_PROP_READWRITE_CB },
	{ "allowsLaunching",				kDock_allowsLaunching,			OOJS_PROP_READWRITE_CB },
	{ "dockingQueueLength",				kDock_dockingQueueLength,			OOJS_PROP_READONLY_CB },
	{ "launchingQueueLength",				kDock_launchingQueueLength,			OOJS_PROP_READONLY_CB },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sDockMethods[] =
{
	// JS name					Function						min args	flags
	{ "isQueued",				DockIsQueued,					1,			0 },
	{ 0 }
};
} // namespace


void InitOOJSDock(ooscript::Context context, ooscript::Object global)
{
	Object proto = ooscript::initClass((context), (global), (JSShipPrototype()), &sDockClass, OOJSUnconstructableConstruct, 0, sDockProperties, sDockMethods, nullptr, nullptr);
	sDockPrototype = (proto);
	OOJSRegisterObjectConverter(&sDockClass, OOJSBasicPrivateObjectConverter);
	OOJSRegisterSubclass(&sDockClass, JSShipClass());
}


namespace {
static bool JSDockGetDockEntity(ooscript::Context context, ooscript::Object dockObj, DockEntity **outEntity)
{
	OOJS_PROFILE_ENTER
	
	bool						result;
	Entity						*entity = nil;
	
	if (outEntity == NULL)  return false;
	*outEntity = nil;
	
	result = OOJSEntityGetEntity(context, dockObj, &entity);
	if (!result)  return false;
	
	if (![entity isKindOfClass:[DockEntity class]])  return false;
	
	*outEntity = (DockEntity *)entity;
	return true;
	
	OOJS_PROFILE_EXIT
}
} // namespace


namespace {
static bool JSDockGetShipEntity(ooscript::Context context, ooscript::Object shipObj, ShipEntity **outEntity)
{
	OOJS_PROFILE_ENTER
	
	bool						result;
	Entity						*entity = nil;
	
	if (outEntity == NULL)  return false;
	*outEntity = nil;
	
	result = OOJSEntityGetEntity(context, shipObj, &entity);
	if (!result)  return false;
	
	if (![entity isKindOfClass:[ShipEntity class]])  return false;
	
	*outEntity = (ShipEntity *)entity;
	return true;
	
	OOJS_PROFILE_EXIT
}
} // namespace


// The bodies of DockEntity (OOJavaScriptExtensions), whose methods are in OOJSDock+ObjCBridge.mm
// until DockEntity converts (proposed ADR-0056 amendments oo-ppc and oo-ykoy).
void OOJSDockGetJSClass(ooscript::ClassDef **outClass, ooscript::Object *outPrototype)
{
	*outClass = &sDockClass;
	*outPrototype = sDockPrototype;
}

std::optional<std::string> OOJSDockJSClassName(void)
{
	return std::string("Dock");
}


namespace {
static bool DockGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return true;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = (value);
	
	OOJS_NATIVE_ENTER(context)
	
	DockEntity				*entity = nil;
	
	if (!JSDockGetDockEntity(context, thisObj, &entity))  return false;
	if (entity == nil)  { *value_raw = ooscript::undefinedValue(); return true; }
	
	switch (ooscript::idToInt32(propID))
	{
		case kDock_allowsDocking:
			*value_raw = OOJSValueFromBOOL([entity allowsDocking]);
			return true;

		case kDock_disallowedDockingCollides:
			*value_raw = OOJSValueFromBOOL([entity disallowedDockingCollides]);
			return true;

		case kDock_allowsLaunching:
			*value_raw = OOJSValueFromBOOL([entity allowsLaunching]);
			return true;
		
		case kDock_dockingQueueLength:
			return ooscript::newNumberValue(cx, [entity countOfShipsInDockingQueue], value);

		case kDock_launchingQueueLength:
			return ooscript::newNumberValue(cx, [entity countOfShipsInLaunchQueue], value);
			
		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sDockPropertiesRaw);
			return false;
	}
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool DockSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return true;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = (value);
	
	OOJS_NATIVE_ENTER(context)
	
	DockEntity				*entity = nil;
	bool						bValue;
	
	if (!JSDockGetDockEntity(context, thisObj, &entity)) return false;
	if (entity == nil)  return true;
	
	switch (ooscript::idToInt32(propID))
	{
		case kDock_allowsDocking:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[entity setAllowsDocking:bValue];
				return true;
			}
			break;

		case kDock_allowsLaunching:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[entity setAllowsLaunching:bValue];
				return true;
			}
			break;

		case kDock_disallowedDockingCollides:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[entity setDisallowedDockingCollides:bValue];
				return true;
			}
			break;

		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sDockPropertiesRaw);
			return false;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, (propID), sDockPropertiesRaw, *value_raw);
	return false;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// *** Methods ***

namespace {
static bool DockIsQueued(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	bool result = false;
	DockEntity *dock = nil;

	JSDockGetDockEntity(context, OOJS_THIS, &dock); 
	if (oojsArgs.count() == 0)
	{
		cxx_OOJSReportBadArguments(context, "Dock", "isQueued", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "ship");
		return false;
	}
	ShipEntity *ship = nil;
	JSDockGetShipEntity(context, ooscript::toObject(OOJS_ARGV[0]), &ship);
	if (ship != nil)
	{
		result = [dock shipIsInDockingQueue:ship];
	}
	
	OOJS_RETURN_BOOL(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace
