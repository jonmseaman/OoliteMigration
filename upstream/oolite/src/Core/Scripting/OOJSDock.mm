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
	oo-sdz, the sweep exemplar): the class dispatch table becomes a static ooscript::ClassDef
	(the stub hooks are nullptr), InitClass becomes ooscript::initClass, native methods and
	class hooks take the façade's hook signature (Context/Object/PropertyId/Value pointer/
	CallArgs reference), and the directly spelled numeric-conversion calls (NewNumberValue,
	ValueToBoolean) become their ooscript:: façade equivalents. A tiny shim at the top of each
	native method recovers the old JSContext pointer, uintN and jsval pointer locals so the
	OOJS_* argument-marshalling macros and the rest of each function body are UNCHANGED,
	because ooscript::Value/Object/PropertyId are byte copies of jsval, JSObject*, and jsid
	(JSEngine.hpp's own contract) and views onto them are therefore reinterpret_cast, not
	conversion. `this` is renamed to `thisObj` because it is a reserved word once this file
	compiles as Objective-C++ (ADR-0001).

	Dock is registered as a Ship subclass and object converter with the ENGINE's own JSClass*
	(OOJSRegisterSubclass/OOJSRegisterObjectConverter and getJSClass:andPrototype: are shared,
	not-yet-retargeted plumbing that still speaks jsapi's JSClass); ClassDef's `backend` slot
	is filled in by ooscript::initClass() before InitOOJSDock() makes those calls, so
	RawDockClass() below is a reinterpret_cast onto already-attached storage, not a conversion
	(see OOJSVector.mm/OOJSStation.mm for the same pattern).
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

// Byte-identical façade <-> jsapi views, local to this call site (see OOJSVector.mm).
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
static JSObject		*sDockPrototype;
} // namespace

namespace {
static BOOL JSDockGetDockEntity(JSContext *context, JSObject *stationObj, DockEntity **outEntity);
} // namespace
namespace {
static BOOL JSDockGetShipEntity(JSContext *context, JSObject *shipObj, ShipEntity **outEntity);
} // namespace

namespace {
static bool DockIsQueued(Context cx, CallArgs &oojsArgs);
} // namespace


namespace {
static bool DockGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool DockSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace


// Adapts the shared jsapi finalizer (OOJavaScriptEngine.m) to the façade's FinalizeHook
// signature; the finalizer itself is untouched, shared plumbing outside this bead's scope.
namespace {
static void DockFinalize(Context cx, Object obj)
{
	OOJSObjectWrapperFinalize(reinterpret_cast<JSContext*>(cx), reinterpret_cast<JSObject*>(obj));
}
} // namespace


// Adapts the shared jsapi OOJSUnconstructableConstruct (OOJavaScriptEngine.m) to the façade's
// NativeFn signature, so `new Dock()` keeps throwing "Dock cannot be used as a constructor."
// as it did before retargeting (see OOJSStation.mm for the same pattern).
namespace {
static bool DockUnconstructableConstruct(Context cx, CallArgs &oojsArgs)
{
	return OOJSUnconstructableConstruct(reinterpret_cast<JSContext*>(cx), oojsArgs.count(), reinterpret_cast<jsval*>(oojsArgs.rawVp()));
}
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
	nullptr,			// newEnumerate (JSCLASS_NEW_ENUMERATE not used)
	nullptr,			// resolve (engine default: ResolveStub)
	nullptr,			// convert (engine default: ConvertStub)
	DockFinalize,		// finalize
	nullptr,			// call
	nullptr,			// construct
	nullptr,			// backend: owned by the façade backend, must start null
};
} // namespace


// The engine's own JSClass* for sDockClass, for the not-yet-retargeted plumbing
// (OOJSRegisterSubclass/OOJSRegisterObjectConverter, getJSClass:andPrototype:) that still
// takes one; see OOJSStation.mm for the same pattern. Valid only after InitOOJSDock() has
// called ooscript::initClass(), which is the only thing that attaches sDockClass.backend.
namespace {
static inline JSClass *RawDockClass(void)
{
	return reinterpret_cast<JSClass*>(sDockClass.backend);
}
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
	{ "dockingQueueLength",				kDock_dockingQueueLength,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "launchingQueueLength",				kDock_launchingQueueLength,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ 0 }
};
} // namespace


// A raw jsapi mirror of sDockProperties, used only for the two bad-property error reporters
// in OOJavaScriptEngine.m (OOJSReportBadPropertySelector/Value): those helpers are outside
// this bead's scope (shared across every binding file) and still take a JSPropertySpec*, not
// ooscript::PropertySpec* (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static JSPropertySpec sDockPropertiesRaw[] =
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


void InitOOJSDock(JSContext *context, JSObject *global)
{
	Object proto = ooscript::initClass(OOJSFCX(context), OOJSFOBJ(global), OOJSFOBJ(JSShipPrototype()), &sDockClass, DockUnconstructableConstruct, 0, sDockProperties, sDockMethods, nullptr, nullptr);
	sDockPrototype = OOJSROBJ(proto);
	OOJSRegisterObjectConverter(RawDockClass(), OOJSBasicPrivateObjectConverter);
	OOJSRegisterSubclass(RawDockClass(), JSShipClass());
}


namespace {
static BOOL JSDockGetDockEntity(JSContext *context, JSObject *dockObj, DockEntity **outEntity)
{
	OOJS_PROFILE_ENTER
	
	BOOL						result;
	Entity						*entity = nil;
	
	if (outEntity == NULL)  return NO;
	*outEntity = nil;
	
	result = OOJSEntityGetEntity(context, dockObj, &entity);
	if (!result)  return NO;
	
	if (![entity isKindOfClass:[DockEntity class]])  return NO;
	
	*outEntity = (DockEntity *)entity;
	return YES;
	
	OOJS_PROFILE_EXIT
}
} // namespace


namespace {
static BOOL JSDockGetShipEntity(JSContext *context, JSObject *shipObj, ShipEntity **outEntity)
{
	OOJS_PROFILE_ENTER
	
	BOOL						result;
	Entity						*entity = nil;
	
	if (outEntity == NULL)  return NO;
	*outEntity = nil;
	
	result = OOJSEntityGetEntity(context, shipObj, &entity);
	if (!result)  return NO;
	
	if (![entity isKindOfClass:[ShipEntity class]])  return NO;
	
	*outEntity = (ShipEntity *)entity;
	return YES;
	
	OOJS_PROFILE_EXIT
}
} // namespace


@implementation DockEntity (OOJavaScriptExtensions)

- (void)getJSClass:(JSClass **)outClass andPrototype:(JSObject **)outPrototype
{
	*outClass = RawDockClass();
	*outPrototype = sDockPrototype;
}


- (NSString *) oo_jsClassName
{
	return @"Dock";
}

@end


namespace {
static bool DockGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *value_raw = OOJSRVAL(value);
	
	OOJS_NATIVE_ENTER(context)
	
	DockEntity				*entity = nil;
	
	if (!JSDockGetDockEntity(context, thisObj, &entity))  return NO;
	if (entity == nil)  { *value_raw = JSVAL_VOID; return YES; }
	
	switch (ooscript::idToInt32(propID))
	{
		case kDock_allowsDocking:
			*value_raw = OOJSValueFromBOOL([entity allowsDocking]);
			return YES;

		case kDock_disallowedDockingCollides:
			*value_raw = OOJSValueFromBOOL([entity disallowedDockingCollides]);
			return YES;

		case kDock_allowsLaunching:
			*value_raw = OOJSValueFromBOOL([entity allowsLaunching]);
			return YES;
		
		case kDock_dockingQueueLength:
			return ooscript::newNumberValue(cx, [entity countOfShipsInDockingQueue], value);

		case kDock_launchingQueueLength:
			return ooscript::newNumberValue(cx, [entity countOfShipsInLaunchQueue], value);
			
		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sDockPropertiesRaw);
			return NO;
	}
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool DockSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *value_raw = OOJSRVAL(value);
	
	OOJS_NATIVE_ENTER(context)
	
	DockEntity				*entity = nil;
	bool						bValue;
	
	if (!JSDockGetDockEntity(context, thisObj, &entity)) return NO;
	if (entity == nil)  return YES;
	
	switch (ooscript::idToInt32(propID))
	{
		case kDock_allowsDocking:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[entity setAllowsDocking:bValue];
				return YES;
			}
			break;

		case kDock_allowsLaunching:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[entity setAllowsLaunching:bValue];
				return YES;
			}
			break;

		case kDock_disallowedDockingCollides:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[entity setDisallowedDockingCollides:bValue];
				return YES;
			}
			break;

		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sDockPropertiesRaw);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, OOJSRJSID(propID), sDockPropertiesRaw, *value_raw);
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// *** Methods ***

namespace {
static bool DockIsQueued(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	BOOL result = NO;
	DockEntity *dock = nil;

	JSDockGetDockEntity(context, OOJS_THIS, &dock); 
	if (argc == 0)
	{
		OOJSReportBadArguments(context, @"Dock", @"isQueued", MIN(argc, 1U), OOJS_ARGV, nil, @"ship");
		return NO;
	}
	ShipEntity *ship = nil;
	JSDockGetShipEntity(context, JSVAL_TO_OBJECT(OOJS_ARGV[0]), &ship);
	if (ship != nil)
	{
		result = [dock shipIsInDockingQueue:ship];
	}
	
	OOJS_RETURN_BOOL(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace
