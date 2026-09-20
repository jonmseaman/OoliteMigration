/*
OOJSStation.m

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

#import "OOJSStation.h"
#import "OOJSEntity.h"
#import "OOJSShip.h"
#import "OOJSPlayer.h"
#import "PlayerEntityContracts.h"
#import "OOJavaScriptEngine.h"
#import "OOJSInterfaceDefinition.h"

#import "OOCollectionExtractors.h"
#import "OOEquipmentType.h"
#import "OOShipRegistry.h"
#import "OOConstToString.h"
#import "StationEntity.h"
#import "GameController.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>
#include <cstdint>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar): the class dispatch table becomes a static ooscript::ClassDef
	(the stub hooks are nullptr), InitClass becomes ooscript::initClass, native methods and
	class hooks take the façade's hook signature (Context/Object/PropertyId/Value pointer/
	CallArgs reference), and the directly spelled numeric-conversion / object-conversion /
	property-lookup calls (NewNumberValue, ValueToBoolean, ValueToNumber, ValueToInt32,
	ValueToObject, GetProperty) become their ooscript:: façade equivalents. A tiny shim at the
	top of each native method recovers the old JSContext pointer, uintN and jsval pointer
	locals so the OOJS_* argument-marshalling macros and the rest of each function body are
	UNCHANGED, because ooscript::Value/Object/PropertyId are byte copies of jsval, JSObject*, and jsid
	(JSEngine.hpp's own contract) and views onto them are therefore reinterpret_cast, not
	conversion. `this` is renamed to `thisObj` because it is a reserved word once this file
	compiles as Objective-C++ (ADR-0001).

	Station is registered as a Ship subclass and object converter with the ENGINE's own
	JSClass* (OOJSRegisterSubclass/OOJSRegisterObjectConverter and getJSClass:andPrototype:
	are shared, not-yet-retargeted plumbing that still speaks jsapi's JSClass); ClassDef's
	`backend` slot is filled in by ooscript::initClass() before InitOOJSStation() makes those
	calls, so RawStationClass() below is a reinterpret_cast onto already-attached storage, not
	a conversion (see OOJSVector.mm/OOJSWaypoint.mm for the same pattern).
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
static inline Value     *OOJSFVALP(jsval *v)      { return reinterpret_cast<Value*>(v); }
} // namespace
namespace {
static inline Value      OOJSFVAL(jsval v)        { Value r; std::memcpy(&r, &v, sizeof r); return r; }
} // namespace
namespace {
static inline jsid       OOJSRJSID(PropertyId id) { jsid r; std::memcpy(&r, &id, sizeof r); return r; }
} // namespace
namespace {
static inline Object    *OOJSFOBJP(JSObject **o)  { return reinterpret_cast<Object*>(o); }
} // namespace


namespace {
static JSObject		*sStationPrototype;
} // namespace

namespace {
static BOOL JSStationGetStationEntity(JSContext *context, JSObject *stationObj, StationEntity **outEntity);
} // namespace


namespace {
static bool StationGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool StationSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace

namespace {
static bool StationAbortAllDockings(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationAbortDockingForShip(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationCanDockShip(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationDockPlayer(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationIncreaseAlertLevel(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationDecreaseAlertLevel(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationLaunchShipWithRole(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationLaunchDefenseShip(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationLaunchEscort(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationLaunchScavenger(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationLaunchMiner(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationLaunchPirateShip(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationLaunchShuttle(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationLaunchPatrol(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationLaunchPolice(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationSetInterface(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationSetMarketPrice(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationSetMarketQuantity(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationAddShipToShipyard(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationRemoveShipFromShipyard(Context cx, CallArgs &oojsArgs);
} // namespace

// Adapts the shared jsapi finalizer (OOJavaScriptEngine.m) to the façade's FinalizeHook
// signature; the finalizer itself is untouched, shared plumbing outside this bead's scope.
namespace {
static void StationFinalize(Context cx, Object obj)
{
	OOJSObjectWrapperFinalize(reinterpret_cast<JSContext*>(cx), reinterpret_cast<JSObject*>(obj));
}
} // namespace


// Adapts the shared jsapi OOJSUnconstructableConstruct (OOJavaScriptEngine.m) to the façade's
// NativeFn signature, so `new Station()` keeps throwing "Station cannot be used as a
// constructor." as it did before retargeting (see OOJSWaypoint.mm for the same pattern).
namespace {
static bool StationUnconstructableConstruct(Context cx, CallArgs &oojsArgs)
{
	return OOJSUnconstructableConstruct(reinterpret_cast<JSContext*>(cx), oojsArgs.count(), reinterpret_cast<jsval*>(oojsArgs.rawVp()));
}
} // namespace


namespace {
static ClassDef sStationClass =
{
	"Station",
	ClassFlag::HasPrivate,
	
	nullptr,				// addProperty (engine default: PropertyStub)
	nullptr,				// delProperty (engine default: PropertyStub)
	StationGetProperty,		// getProperty
	StationSetProperty,		// setProperty
	nullptr,				// enumerate (engine default: EnumerateStub)
	nullptr,				// newEnumerate (JSCLASS_NEW_ENUMERATE not used)
	nullptr,				// resolve (engine default: ResolveStub)
	nullptr,				// convert (engine default: ConvertStub)
	StationFinalize,		// finalize
	nullptr,				// call
	nullptr,				// construct
	nullptr,				// backend: owned by the façade backend, must start null
};
} // namespace


// The engine's own JSClass* for sStationClass, for the not-yet-retargeted plumbing
// (OOJSRegisterSubclass/OOJSRegisterObjectConverter, getJSClass:andPrototype:) that still
// takes one; see OOJSWaypoint.mm for the same pattern. Valid only after InitOOJSStation() has
// called ooscript::initClass(), which is the only thing that attaches sStationClass.backend.
namespace {
static inline JSClass *RawStationClass(void)
{
	return reinterpret_cast<JSClass*>(sStationClass.backend);
}
} // namespace


enum : std::uint8_t
{
	// Property IDs
	kStation_alertCondition,
	kStation_allegiance,
	kStation_allowsAutoDocking,
	kStation_allowsFastDocking,
	kStation_breakPattern,
	kStation_dockedContractors, // miners and scavengers.
	kStation_dockedDefenders,
	kStation_dockedPolice,
	kStation_equipmentPriceFactor,
	kStation_equivalentTechLevel,
	kStation_hasNPCTraffic,
	kStation_hasShipyard,
	kStation_isMainStation,		// Is [UNIVERSE station], boolean, read-only
	kStation_market,
	kStation_requiresDockingClearance,
	kStation_roll,
	kStation_suppressArrivalReports,
	kStation_shipyard,
};


namespace {
static PropertySpec sStationProperties[] =
{
	// JS name									ID									flags							getter	setter
	{ "alertCondition",				kStation_alertCondition,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "allegiance",					kStation_allegiance,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "allowsAutoDocking",			kStation_allowsAutoDocking,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "allowsFastDocking",			kStation_allowsFastDocking,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "breakPattern",				kStation_breakPattern,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "dockedContractors",			kStation_dockedContractors,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "dockedDefenders",			kStation_dockedDefenders,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "dockedPolice",				kStation_dockedPolice,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "equipmentPriceFactor",		kStation_equipmentPriceFactor,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "equivalentTechLevel",		kStation_equivalentTechLevel,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "hasNPCTraffic",				kStation_hasNPCTraffic,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "hasShipyard",				kStation_hasShipyard,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "isMainStation",				kStation_isMainStation,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "market",						kStation_market,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "requiresDockingClearance",	kStation_requiresDockingClearance,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "roll",						kStation_roll,						PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "suppressArrivalReports",		kStation_suppressArrivalReports,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "shipyard",					kStation_shipyard,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ 0 }
};
} // namespace


// A raw jsapi mirror of sStationProperties, used only for the two bad-property error
// reporters in OOJavaScriptEngine.m (OOJSReportBadPropertySelector/Value): those helpers are
// outside this bead's scope (shared across every binding file) and still take a
// JSPropertySpec*, not ooscript::PropertySpec* (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static JSPropertySpec sStationPropertiesRaw[] =
{
	// JS name									ID									flags
	{ "alertCondition",				kStation_alertCondition,			OOJS_PROP_READWRITE_CB },
	{ "allegiance",					kStation_allegiance,				OOJS_PROP_READWRITE_CB },
	{ "allowsAutoDocking",			kStation_allowsAutoDocking,			OOJS_PROP_READWRITE_CB },
	{ "allowsFastDocking",			kStation_allowsFastDocking,			OOJS_PROP_READWRITE_CB },
	{ "breakPattern",				kStation_breakPattern,				OOJS_PROP_READWRITE_CB },
	{ "dockedContractors",			kStation_dockedContractors,			OOJS_PROP_READONLY_CB },
	{ "dockedDefenders",			kStation_dockedDefenders,			OOJS_PROP_READONLY_CB },
	{ "dockedPolice",				kStation_dockedPolice,				OOJS_PROP_READONLY_CB },
	{ "equipmentPriceFactor",		kStation_equipmentPriceFactor,		OOJS_PROP_READONLY_CB },
	{ "equivalentTechLevel",		kStation_equivalentTechLevel,		OOJS_PROP_READONLY_CB },
	{ "hasNPCTraffic",				kStation_hasNPCTraffic,				OOJS_PROP_READWRITE_CB },
	{ "hasShipyard",				kStation_hasShipyard,				OOJS_PROP_READONLY_CB },
	{ "isMainStation",				kStation_isMainStation,				OOJS_PROP_READONLY_CB },
	{ "market",        kStation_market,     OOJS_PROP_READONLY_CB },
	{ "requiresDockingClearance",	kStation_requiresDockingClearance,	OOJS_PROP_READWRITE_CB },
	{ "roll",						kStation_roll,						OOJS_PROP_READWRITE_CB },
	{ "suppressArrivalReports",		kStation_suppressArrivalReports,	OOJS_PROP_READWRITE_CB },
	{ "shipyard",                   kStation_shipyard,                  OOJS_PROP_READONLY_CB },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sStationMethods[] =
{
	// JS name					Function						min args	flags
	{ "abortAllDockings",		StationAbortAllDockings,		0,			0 },
	{ "abortDockingForShip",	StationAbortDockingForShip,		1,			0 },
	{ "canDockShip",            StationCanDockShip,				1,			0 },
	{ "dockPlayer",				StationDockPlayer,				0,			0 },
	{ "increaseAlertLevel",     StationIncreaseAlertLevel,      0,			0 },
	{ "decreaseAlertLevel",     StationDecreaseAlertLevel,      0,			0 },
	{ "launchDefenseShip",		StationLaunchDefenseShip,		0,			0 },
	{ "launchEscort",			StationLaunchEscort,			0,			0 },
	{ "launchMiner",			StationLaunchMiner,				0,			0 },
	{ "launchPatrol",			StationLaunchPatrol,			0,			0 },
	{ "launchPirateShip",		StationLaunchPirateShip,		0,			0 },
	{ "launchPolice",			StationLaunchPolice,			0,			0 },
	{ "launchScavenger",		StationLaunchScavenger,			0,			0 },
	{ "launchShipWithRole",		StationLaunchShipWithRole,		1,			0 },
	{ "launchShuttle",			StationLaunchShuttle,			0,			0 },
	{ "setInterface",			StationSetInterface,			0,			0 },
	{ "setMarketPrice",			StationSetMarketPrice,			2,			0 },
	{ "setMarketQuantity",		StationSetMarketQuantity,		2,			0 },
	{ "addShipToShipyard",      StationAddShipToShipyard,       1,			0 },
	{ "removeShipFromShipyard", StationRemoveShipFromShipyard,  1,			0 },
	{ 0 }
};
} // namespace


void InitOOJSStation(JSContext *context, JSObject *global)
{
	Object proto = ooscript::initClass(OOJSFCX(context), OOJSFOBJ(global), OOJSFOBJ(JSShipPrototype()), &sStationClass, StationUnconstructableConstruct, 0, sStationProperties, sStationMethods, NULL, NULL);
	sStationPrototype = OOJSROBJ(proto);
	OOJSRegisterObjectConverter(RawStationClass(), OOJSBasicPrivateObjectConverter);
	OOJSRegisterSubclass(RawStationClass(), JSShipClass());
}


namespace {
static BOOL JSStationGetStationEntity(JSContext *context, JSObject *stationObj, StationEntity **outEntity)
{
	OOJS_PROFILE_ENTER
	
	BOOL						result;
	Entity						*entity = nil;
	
	if (outEntity == NULL)  return NO;
	*outEntity = nil;
	
	result = OOJSEntityGetEntity(context, stationObj, &entity);
	if (!result)  return NO;
	
	if (![entity isKindOfClass:[StationEntity class]])  return NO;
	
	*outEntity = (StationEntity *)entity;
	return YES;
	
	OOJS_PROFILE_EXIT
}
} // namespace

namespace {
static BOOL JSStationGetShipEntity(JSContext *context, JSObject *shipObj, ShipEntity **outEntity)
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


@implementation StationEntity (OOJavaScriptExtensions)

- (void)getJSClass:(JSClass **)outClass andPrototype:(JSObject **)outPrototype
{
	*outClass = RawStationClass();
	*outPrototype = sStationPrototype;
}


- (NSString *) oo_jsClassName
{
	return @"Station";
}

@end


namespace {
static bool StationGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *value_raw = OOJSRVAL(value);
	
	OOJS_NATIVE_ENTER(context)
	
	StationEntity				*entity = nil;
	
	if (!JSStationGetStationEntity(context, thisObj, &entity))  return NO;
	if (entity == nil)  { *value_raw = JSVAL_VOID; return YES; }
	
	switch (ooscript::idToInt32(propID))
	{
		case kStation_isMainStation:
			*value_raw = OOJSValueFromBOOL(entity == [UNIVERSE station]);
			return YES;
		
		case kStation_hasNPCTraffic:
			*value_raw = OOJSValueFromBOOL([entity hasNPCTraffic]);
			return YES;
			
		case kStation_hasShipyard:
			*value_raw = OOJSValueFromBOOL([entity hasShipyard]);
			return YES;
		
		case kStation_alertCondition:
			*value_raw = INT_TO_JSVAL([entity alertLevel]);
			return YES;

		case kStation_allegiance:
		{
			NSString *result = [entity allegiance];
			*value_raw = OOJSValueFromNativeObject(context, result);
			return YES;
		}
			
		case kStation_requiresDockingClearance:
			*value_raw = OOJSValueFromBOOL([entity requiresDockingClearance]);
			return YES;
			
		case kStation_roll:
			// same as in ship definition, but this time read/write below
			return ooscript::newNumberValue(cx, [entity flightRoll], value);
			
		case kStation_allowsFastDocking:
			*value_raw = OOJSValueFromBOOL([entity allowsFastDocking]);
			return YES;
			
		case kStation_allowsAutoDocking:
			*value_raw = OOJSValueFromBOOL([entity allowsAutoDocking]);
			return YES;

		case kStation_dockedContractors:
			*value_raw = INT_TO_JSVAL([entity countOfDockedContractors]);
			return YES;
			
		case kStation_dockedPolice:
			*value_raw = INT_TO_JSVAL([entity countOfDockedPolice]);
			return YES;
			
		case kStation_dockedDefenders:
			*value_raw = INT_TO_JSVAL([entity countOfDockedDefenders]);
			return YES;
			
		case kStation_equivalentTechLevel:
			*value_raw = INT_TO_JSVAL((int32_t)[entity equivalentTechLevel]);
			return YES;
			
		case kStation_equipmentPriceFactor:
			return ooscript::newNumberValue(cx, [entity equipmentPriceFactor], value);
			
		case kStation_suppressArrivalReports:
			*value_raw = OOJSValueFromBOOL([entity suppressArrivalReports]);
			return YES;
			
		case kStation_breakPattern:
			*value_raw = OOJSValueFromBOOL([entity hasBreakPattern]);
			return YES;

		case kStation_shipyard:
		{
			if (![entity hasShipyard]) 
			{
				// return null if station has no shipyard
				*value_raw = OOJSValueFromNativeObject(context, nil);
			} 
			else 
			{
				if ([entity localShipyard] == nil) [entity generateShipyard];
				NSMutableArray *shipyard = [entity localShipyard];
				*value_raw = OOJSValueFromNativeObject(context, shipyard);
			}
			return YES;
		}

		case kStation_market:
		{
			NSDictionary *market = [entity localMarketForScripting];
			*value_raw = OOJSValueFromNativeObject(context, market);
			return YES;
		}

		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sStationPropertiesRaw);
			return NO;
	}
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool StationSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *value_raw = OOJSRVAL(value);
	
	OOJS_NATIVE_ENTER(context)
	
	StationEntity				*entity = nil;
	bool						bValue;
	int32						iValue;
	jsdouble					fValue;
	NSString					*sValue = nil;
	
	if (!JSStationGetStationEntity(context, thisObj, &entity)) return NO;
	if (entity == nil)  return YES;
	
	switch (ooscript::idToInt32(propID))
	{
		case kStation_hasNPCTraffic:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[entity setHasNPCTraffic:bValue];
				return YES;
			}
			break;
		
		case kStation_alertCondition:
			if (ooscript::valueToInt32(cx, *value, &iValue))
			{
				[entity setAlertLevel:(OOStationAlertLevel)iValue signallingScript:NO];	// Performs range checking
				return YES;
			}
			break;

		case kStation_allegiance:
			sValue = OOStringFromJSValue(context,*value_raw);
			if (sValue != nil)
			{
				[entity setAllegiance:sValue];
				return YES;
			}
			break;

			
		case kStation_requiresDockingClearance:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[entity setRequiresDockingClearance:bValue];
				return YES;
			}
			break;
			
		case kStation_roll:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
/*				if (fValue < -2.0)  fValue = -2.0;
				if (fValue > 2.0)  fValue = 2.0;	// clamping to -2.0...2.0 gives us ±M_PI actual maximum rotation
				[entity setRoll:fValue]; */
				// use setRawRoll to make the units here equal to those in kShip_roll
				if (fValue < -M_PI)  fValue = -M_PI;
				else if (fValue > M_PI)  fValue = M_PI;
				[entity setRawRoll:fValue];
				return YES;
			}
			break;

		case kStation_allowsFastDocking:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[entity setAllowsFastDocking:bValue];
				return YES;
			}
			break;
			
		case kStation_allowsAutoDocking:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[entity setAllowsAutoDocking:bValue];
				return YES;
			}
			break;

		case kStation_suppressArrivalReports:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[entity setSuppressArrivalReports:bValue];
				return YES;
			}
			break;

		case kStation_breakPattern:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[entity setHasBreakPattern:bValue];
				return YES;
			}
			break;
		
		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sStationPropertiesRaw);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, OOJSRJSID(propID), sStationPropertiesRaw, *value_raw);
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// *** Methods ***

namespace {
static bool StationAbortAllDockings(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count(); (void)argc;

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)
	
	StationEntity *station = nil;
	JSStationGetStationEntity(context, OOJS_THIS, &station); 
	[station abortAllDockings];
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace

namespace {
static bool StationAbortDockingForShip(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count();

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)
	
	StationEntity *station = nil;
	JSStationGetStationEntity(context, OOJS_THIS, &station); 
	if (argc == 0)
	{
		OOJSReportBadArguments(context, @"Station", @"abortDockingForShip", MIN(argc, 1U), OOJS_ARGV, nil, @"ship in docking queue");
		return NO;
	}
	if (!JSVAL_IS_OBJECT(OOJS_ARGV[0]))  return NO;
	ShipEntity *ship = nil;
	JSStationGetShipEntity(context, JSVAL_TO_OBJECT(OOJS_ARGV[0]), &ship);
	if (ship != nil)
	{
		[station abortDockingForShip:ship];
	}
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace

// canDockShip(shipEntity) : boolean
// Proposed by phkb (Nick Rogers) 20161206
namespace {
static bool StationCanDockShip(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count();

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

   OOJS_NATIVE_ENTER(context)

   BOOL         result = YES;
   ShipEntity      *shipToCheck = nil;

   if (argc > 0)
   {
      if (!JSVAL_IS_OBJECT(OOJS_ARGV[0]) || !JSStationGetShipEntity(context, JSVAL_TO_OBJECT(OOJS_ARGV[0]), &shipToCheck))
      {
         return NO;
      }
   }
   if (EXPECT_NOT(shipToCheck == nil))
   {
      OOJSReportBadArguments(context, @"Station", @"canDockShip", MIN(argc, 1U), OOJS_ARGV, nil, @"shipEntity");
      return NO;
   }
   
   StationEntity *station = nil;
   if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op
   
   OOJS_BEGIN_FULL_NATIVE(context)
   result = [station fitsInDock:shipToCheck andLogNoFit:NO];
   OOJS_END_FULL_NATIVE

   OOJS_RETURN_BOOL(result);
   OOJS_NATIVE_EXIT
}
} // namespace


// dockPlayer()
// Proposed and written by Frame 20090729
namespace {
static bool StationDockPlayer(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count(); (void)argc;

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity	*player = OOPlayerForScripting();
	GameController	*gameController = [UNIVERSE gameController];
	
	if (EXPECT_NOT([gameController isGamePaused]))
	{
		/*	Station.dockPlayer() was executed while the game was in pause.
			Do we want to return an error or just unpause and continue?
			I think unpausing is the sensible thing to do here - Nikos 20110208
		*/
		[gameController setGamePaused:NO];
	}
	
	if (EXPECT(![player isDocked]))
	{
		StationEntity *stationForDockingPlayer = nil;
		JSStationGetStationEntity(context, OOJS_THIS, &stationForDockingPlayer); 
		[player setDockingClearanceStatus:DOCKING_CLEARANCE_STATUS_GRANTED];
		[player safeAllMissiles];
		[UNIVERSE setViewDirection:VIEW_FORWARD];
		[player enterDock:stationForDockingPlayer];
	}
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool StationIncreaseAlertLevel(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count(); (void)argc;

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)
	StationEntity	*station = nil;

	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op

	OOJS_BEGIN_FULL_NATIVE(context)
	if ([station alertCondition] < 3)
	{
		[station increaseAlertLevel];
	}
	OOJS_END_FULL_NATIVE
	OOJS_RETURN_VOID;
	OOJS_NATIVE_EXIT
}
} // namespace

namespace {
static bool StationDecreaseAlertLevel(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count(); (void)argc;

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)
	StationEntity	*station = nil;

	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op

	OOJS_BEGIN_FULL_NATIVE(context)
	if ([station alertCondition] > 1)
	{
		[station decreaseAlertLevel];
	}
	OOJS_END_FULL_NATIVE
	OOJS_RETURN_VOID;
	OOJS_NATIVE_EXIT
}
} // namespace

// launchShipWithRole(role : String [, abortAllDockings : boolean]) : shipEntity
namespace {
static bool StationLaunchShipWithRole(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count();

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)
	
	NSString		*shipRole = nil;
	StationEntity	*station = nil;
	ShipEntity		*result = nil;
	bool			abortAllDockings = NO;
	
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op
	
	if (argc > 0)  shipRole = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(shipRole == nil))
	{
		OOJSReportBadArguments(context, @"Station", @"launchShipWithRole", MIN(argc, 1U), OOJS_ARGV, nil, @"string (role)");
		return NO;
	}
	
	if (argc > 1)  ooscript::valueToBoolean(OOJSFCX(context), OOJSFVAL(OOJS_ARGV[1]), &abortAllDockings);

	OOJS_BEGIN_FULL_NATIVE(context)
	result = [station launchIndependentShip:shipRole];
	if (abortAllDockings) [station abortAllDockings];
	OOJS_END_FULL_NATIVE

	OOJS_RETURN_OBJECT(result);
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool StationLaunchDefenseShip(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count(); (void)argc;

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)
	
	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op

	ShipEntity *launched = nil;
	OOJS_BEGIN_FULL_NATIVE(context)
	launched = [station launchDefenseShip];
	OOJS_END_FULL_NATIVE
	OOJS_RETURN_OBJECT(launched);

	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool StationLaunchEscort(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count(); (void)argc;

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)
	
	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op
	
	ShipEntity *launched = nil;
	OOJS_BEGIN_FULL_NATIVE(context)
	launched = [station launchEscort];
	OOJS_END_FULL_NATIVE
	OOJS_RETURN_OBJECT(launched);

	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool StationLaunchScavenger(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count(); (void)argc;

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)
	
	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op

	ShipEntity *launched = nil;
	OOJS_BEGIN_FULL_NATIVE(context)
	launched = [station launchScavenger];
	OOJS_END_FULL_NATIVE
	OOJS_RETURN_OBJECT(launched);

	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool StationLaunchMiner(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count(); (void)argc;

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)
	
	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op
	
	ShipEntity *launched = nil;
	OOJS_BEGIN_FULL_NATIVE(context)
	launched = [station launchMiner];
	OOJS_END_FULL_NATIVE
	OOJS_RETURN_OBJECT(launched);
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool StationLaunchPirateShip(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count(); (void)argc;

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)
	
	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op
	
	ShipEntity *launched = nil;
	OOJS_BEGIN_FULL_NATIVE(context)
	launched = [station launchPirateShip];
	OOJS_END_FULL_NATIVE
	OOJS_RETURN_OBJECT(launched);

	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool StationLaunchShuttle(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count(); (void)argc;

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)
	
	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op
	
	ShipEntity *launched = nil;
	OOJS_BEGIN_FULL_NATIVE(context)
	launched = [station launchShuttle];
	OOJS_END_FULL_NATIVE
	OOJS_RETURN_OBJECT(launched);
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool StationLaunchPatrol(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count(); (void)argc;

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)
	
	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op
	
	ShipEntity *launched = nil;
	OOJS_BEGIN_FULL_NATIVE(context)
	launched = [station launchPatrol];
	OOJS_END_FULL_NATIVE
	OOJS_RETURN_OBJECT(launched);
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool StationLaunchPolice(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count(); (void)argc;

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)
	
	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op
	
	NSArray *launched = nil;
	OOJS_BEGIN_FULL_NATIVE(context)
	launched = [station launchPolice];
	OOJS_END_FULL_NATIVE
	OOJS_RETURN_OBJECT(launched);
	OOJS_NATIVE_EXIT
}
} // namespace

namespace {
static bool StationSetInterface(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count();

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)

	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op

	if (argc < 1)
	{
		OOJSReportBadArguments(context, @"Station", @"setInterface", MIN(argc, 1U), OOJS_ARGV, NULL, @"key [, definition]");
		return NO;
	}
	NSString *key = OOStringFromJSValue(context, OOJS_ARGV[0]);

	if (argc < 2 || JSVAL_IS_NULL(OOJS_ARGV[1]))
	{
		[station setInterfaceDefinition:nil forKey:key];
		OOJS_RETURN_VOID;
	}
	

	jsval				value = JSVAL_NULL;
	jsval				callback = JSVAL_NULL;
	JSObject				*callbackThis = NULL;
	JSObject			*params = NULL;

	NSString      *title = nil;
	NSString      *summary = nil;
	NSString      *category = nil;

	if (!ooscript::valueToObject(cx, OOJSFVAL(OOJS_ARGV[1]), OOJSFOBJP(&params)))
	{
		OOJSReportBadArguments(context, @"Station", @"setInterface", MIN(argc, 1U), OOJS_ARGV, NULL, @"key [, definition]");
		return NO;
	}

	// get and validate title
	if (!ooscript::getProperty(cx, OOJSFOBJ(params), "title", OOJSFVALP(&value)) || JSVAL_IS_VOID(value))
	{
		OOJSReportBadArguments(context, @"Station", @"setInterface", MIN(argc, 1U), OOJS_ARGV, NULL, @"key [, definition]; if definition is set, it must have a 'title' property.");
		return NO;
	}
	title = OOStringFromJSValue(context, value);
	if (title == nil || [title length] == 0) 
	{
		OOJSReportBadArguments(context, @"Station", @"setInterface", MIN(argc, 1U), OOJS_ARGV, NULL, @"key [, definition]; if definition is set, 'title' property must be a non-empty string.");
		return NO;
	}

	// get category with default
	if (!ooscript::getProperty(cx, OOJSFOBJ(params), "category", OOJSFVALP(&value)) || JSVAL_IS_VOID(value))
	{
		category = [NSString stringWithString:DESC(@"interfaces-category-uncategorised")];
	}
	else
	{
		category = OOStringFromJSValue(context, value);
		if (category == nil || [category length] == 0) {
			category = [NSString stringWithString:DESC(@"interfaces-category-uncategorised")];
		}
	}

	// get and validate summary
	if (!ooscript::getProperty(cx, OOJSFOBJ(params), "summary", OOJSFVALP(&value)) || JSVAL_IS_VOID(value))
	{
		OOJSReportBadArguments(context, @"Station", @"setInterface", MIN(argc, 1U), OOJS_ARGV, NULL, @"key [, definition]; if definition is set, it must have a 'summary' property.");
		return NO;
	}
	summary = OOStringFromJSValue(context, value);
	if (summary == nil || [summary length] == 0) 
	{
		OOJSReportBadArguments(context, @"Station", @"setInterface", MIN(argc, 1U), OOJS_ARGV, NULL, @"key [, definition]; if definition is set, 'summary' property must be a non-empty string.");
		return NO;
	}

	// get and validate callback
	if (!ooscript::getProperty(cx, OOJSFOBJ(params), "callback", OOJSFVALP(&callback)) || JSVAL_IS_VOID(callback))
	{
		OOJSReportBadArguments(context, @"Station", @"setInterface", MIN(argc, 1U), OOJS_ARGV, NULL, @"key [, definition]; if definition is set, it must have a 'callback' property.");
		return NO;
	}
	if (!OOJSValueIsFunction(context,callback))
	{
		OOJSReportBadArguments(context, @"Station", @"setInterface", MIN(argc, 1U), OOJS_ARGV, NULL, @"key [, definition]; 'callback' property must be a function.");
		return NO;
	}

	OOJSInterfaceDefinition* definition = [[OOJSInterfaceDefinition alloc] init];
	[definition setTitle:title];
	[definition setCategory:category];
	[definition setSummary:summary];
	[definition setCallback:callback];

	// get callback 'this'
	if (ooscript::getProperty(cx, OOJSFOBJ(params), "cbThis", OOJSFVALP(&value)) && !JSVAL_IS_VOID(value))
	{
		ooscript::valueToObject(cx, OOJSFVAL(value), OOJSFOBJP(&callbackThis));
		[definition setCallbackThis:callbackThis];
		// can do .bind(this) for callback instead
	}
	
	[station setInterfaceDefinition:definition forKey:key];

	[definition release];

	OOJS_RETURN_VOID;

	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool StationSetMarketPrice(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count();

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)

	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op

	if (argc < 2)
	{
		OOJSReportBadArguments(context, @"Station", @"setMarketPrice", MIN(argc, 2U), OOJS_ARGV, NULL, @"commodity, credits");
		return NO;
	}
	
	OOCommodityType commodity = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(![[UNIVERSE commodities] goodDefined:commodity]))
	{
		OOJSReportBadArguments(context, @"Station", @"setMarketPrice", MIN(argc, 2U), OOJS_ARGV, NULL, @"Unrecognised commodity type");
		return NO;
	}

	int32 price;
	BOOL gotPrice = ooscript::valueToInt32(OOJSFCX(context), OOJSFVAL(OOJS_ARGV[1]), &price);
	if (EXPECT_NOT(!gotPrice || price < 0))
	{
		OOJSReportBadArguments(context, @"Station", @"setMarketPrice", MIN(argc, 2U), OOJS_ARGV, NULL, @"Price must be at least 0 decicredits");
		return NO;
	}

	[station setPrice:(NSUInteger)price forCommodity:commodity];

	if (station == [PLAYER dockedStation] && [PLAYER guiScreen] == GUI_SCREEN_MARKET)
	{
		[PLAYER setGuiToMarketScreen]; // refresh screen
	}

	OOJS_RETURN_BOOL(YES);

	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool StationSetMarketQuantity(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count();

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)

	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op

	if (argc < 2)
	{
		OOJSReportBadArguments(context, @"Station", @"setMarketQuantity", MIN(argc, 2U), OOJS_ARGV, NULL, @"commodity, units");
		return NO;
	}
	
	OOCommodityType commodity = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(![[UNIVERSE commodities] goodDefined:commodity]))
	{
		OOJSReportBadArguments(context, @"Station", @"setMarketQuantity", MIN(argc, 2U), OOJS_ARGV, NULL, @"Unrecognised commodity type");
		return NO;
	}

	int32 quantity;
	BOOL gotQuantity = ooscript::valueToInt32(OOJSFCX(context), OOJSFVAL(OOJS_ARGV[1]), &quantity);
	if (EXPECT_NOT(!gotQuantity || quantity < 0 || (OOCargoQuantity)quantity > [[station localMarket] capacityForGood:commodity]))
	{
		OOJSReportBadArguments(context, @"Station", @"setMarketQuantity", MIN(argc, 2U), OOJS_ARGV, NULL, @"Quantity must be between 0 and the station market capacity");
		return NO;
	}

	[station setQuantity:(OOCargoQuantity)quantity forCommodity:commodity];
	
	if (station == [PLAYER dockedStation] && [PLAYER guiScreen] == GUI_SCREEN_MARKET)
	{
		[PLAYER setGuiToMarketScreen]; // refresh screen
	}

	OOJS_RETURN_BOOL(YES);

	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool StationAddShipToShipyard(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count();

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)

	JSObject *params = NULL;
	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op

	if (argc != 1 || (!JSVAL_IS_NULL(OOJS_ARGV[0]) && !ooscript::valueToObject(OOJSFCX(context), OOJSFVAL(OOJS_ARGV[0]), OOJSFOBJP(&params))))
	{
		OOJSReportBadArguments(context, @"Station", @"addShipToShipyard", MIN(argc, 1U), OOJS_ARGV, NULL, @"shipyard item definition");
		return NO;
	}

	// make sure the station has a shipyard
	if (![station hasShipyard]) {
		OOJSReportWarningForCaller(context, @"Station", @"removeShipFromShipyard", @"Station does not have shipyard.");
		return NO;
	}
	// make sure the shipyard has been generated
	if (![station localShipyard]) [station generateShipyard];
	NSMutableArray *shipyard = [station localShipyard];

	if (JSVAL_IS_NULL(OOJS_ARGV[0]))  OOJS_RETURN_VOID;	// OK, do nothing for null ship.

	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	NSDictionary *shipyardDefinition = OOJSNativeObjectFromJSObject(context, JSVAL_TO_OBJECT(OOJS_ARGV[0]));
	// validate each element of the dictionary
	if (!shipyardDefinition) 
	{
		OOJSReportBadArguments(context, @"Station", @"addShipToShipyard", MIN(argc, 1U), OOJS_ARGV, nil, @"valid dictionary object");
		return NO;
	}
	if (![shipyardDefinition objectForKey:KEY_SHORT_DESCRIPTION]) 
	{
		OOJSReportBadArguments(context, @"Station", @"addShipToShipyard", MIN(argc, 1U), OOJS_ARGV, nil, @"'short_description' in dictionary");
		return NO;
	}
	[result setObject:[shipyardDefinition oo_stringForKey:@"short_description"] forKey:KEY_SHORT_DESCRIPTION];
	if (![shipyardDefinition objectForKey:SHIPYARD_KEY_SHIPDATA_KEY]) 
	{
		OOJSReportBadArguments(context, @"Station", @"addShipToShipyard", MIN(argc, 1U), OOJS_ARGV, nil, @"'shipdata_key' in dictionary");
		return NO;
	}
	// get the shipInfo and shipyardInfo for this key
	NSString 			*shipKey = [shipyardDefinition oo_stringForKey:SHIPYARD_KEY_SHIPDATA_KEY defaultValue:nil];
	OOShipRegistry		*registry = [OOShipRegistry sharedRegistry];
	NSMutableDictionary	*shipInfo = [NSMutableDictionary dictionaryWithDictionary:[registry shipInfoForKey:shipKey]];
	NSDictionary		*shipyardInfo = [registry shipyardInfoForKey:shipKey];
	if (!shipInfo) 
	{
		OOJSReportWarningForCaller(context, @"Station", @"addShipToShipyard", @"Invalid shipdata_key provided.");
		return NO;
	}
	// make sure the ship is a player ship
	if ([[shipInfo oo_stringForKey:@"roles"] rangeOfString:@"player"].location == NSNotFound)
	{
		OOJSReportWarningForCaller(context, @"Station", @"addShipToShipyard", @"shipdata_key not suitable for player role.");
		return NO;
	}
	if (!shipyardInfo) 
	{
		OOJSReportWarningForCaller(context, @"Station", @"addShipToShipyard", @"No shipyard information found for shipdata_key.");
		return NO;
	}
	// ok, feel pretty safe to include this ship now
	[result setObject:shipKey forKey:SHIPYARD_KEY_SHIPDATA_KEY];

	// add an ID
	Random_Seed ship_seed = [UNIVERSE marketSeed];
	int superRand1 = ship_seed.a * 0x10000 + ship_seed.c * 0x100 + ship_seed.e;
	uint32_t superRand2 = ship_seed.b * 0x10000 + ship_seed.d * 0x100 + ship_seed.f;
	superRand2 &= Ranrot();
	NSString *shipID = [NSString stringWithFormat:@"%06x-%06x", superRand1, superRand2];
	[result setObject:shipID forKey:SHIPYARD_KEY_ID];

	if (![shipyardDefinition objectForKey:SHIPYARD_KEY_PRICE]) 
	{
		// if not provided, get the price from the registry
		OOCreditsQuantity price = [shipyardInfo oo_unsignedIntForKey:KEY_PRICE];
		[result setObject:[NSNumber numberWithUnsignedLongLong:price] forKey:SHIPYARD_KEY_PRICE];
	}
	else 
	{
		OOCreditsQuantity price = [shipyardDefinition oo_unsignedIntForKey:SHIPYARD_KEY_PRICE];
		if (price > 0)
		{
			[result setObject:[NSNumber numberWithUnsignedLongLong:price] forKey:SHIPYARD_KEY_PRICE];
		}
		else
		{
			OOJSReportBadArguments(context, @"Station", @"addShipToShipyard", MIN(argc, 1U), OOJS_ARGV, nil, @"'price' in dictionary");
			return NO;
		}
	}

	if (![shipyardDefinition objectForKey:SHIPYARD_KEY_PERSONALITY]) 
	{
		// default to 0 if not supplied
		[result setObject:0 forKey:SHIPYARD_KEY_PERSONALITY];
	} 
	else
	{
		[result setObject:[NSNumber numberWithUnsignedLongLong:[shipyardDefinition oo_unsignedIntForKey:SHIPYARD_KEY_PERSONALITY]] forKey:SHIPYARD_KEY_PERSONALITY];
	}

	NSArray	*extras = [shipyardDefinition oo_arrayForKey:KEY_EQUIPMENT_EXTRAS];
	if (!extras) 
	{
		// pick up defaults if extras not supplied
		extras = [NSArray arrayWithArray:[[shipyardInfo oo_dictionaryForKey:KEY_STANDARD_EQUIPMENT] oo_arrayForKey:KEY_EQUIPMENT_EXTRAS]];
	}
	if ([extras count] > 0) {
		// go looking for lasers and add them directly to our shipInfo
		NSString* fwdWeaponString = [[shipyardInfo oo_dictionaryForKey:KEY_STANDARD_EQUIPMENT] oo_stringForKey:KEY_EQUIPMENT_FORWARD_WEAPON];
		NSString* aftWeaponString = [[shipyardInfo oo_dictionaryForKey:KEY_STANDARD_EQUIPMENT] oo_stringForKey:KEY_EQUIPMENT_AFT_WEAPON];
		OOWeaponFacingSet availableFacings = [shipyardInfo oo_unsignedIntForKey:KEY_WEAPON_FACINGS defaultValue:VALID_WEAPON_FACINGS] & VALID_WEAPON_FACINGS;

		OOWeaponType fwdWeapon = OOWeaponTypeFromEquipmentIdentifierSloppy(fwdWeaponString);
		OOWeaponType aftWeapon = OOWeaponTypeFromEquipmentIdentifierSloppy(aftWeaponString);

		unsigned int i;
		NSString *equipmentKey = nil;
		for (i = 0; i < [extras count]; i++) {
			equipmentKey = [extras oo_stringAtIndex:i];
			if ([equipmentKey hasPrefix:@"EQ_WEAPON"])
			{
				OOWeaponType new_weapon = OOWeaponTypeFromEquipmentIdentifierSloppy(equipmentKey);
				//fit best weapon forward
				if (availableFacings & WEAPON_FACING_FORWARD && [new_weapon weaponThreatAssessment] > [fwdWeapon weaponThreatAssessment])
				{
					//again remember to divide price by 10 to get credits from tenths of credit
					fwdWeaponString = equipmentKey;
					fwdWeapon = new_weapon;
					[shipInfo setObject:fwdWeaponString forKey:KEY_EQUIPMENT_FORWARD_WEAPON];
				}
				else 
				{
					//if less good than current forward, try fitting is to rear
					if (availableFacings & WEAPON_FACING_AFT && (isWeaponNone(aftWeapon) || [new_weapon weaponThreatAssessment] > [aftWeapon weaponThreatAssessment]))
					{
						aftWeaponString = equipmentKey;
						aftWeapon = new_weapon;
						[shipInfo setObject:aftWeaponString forKey:KEY_EQUIPMENT_AFT_WEAPON];
					}
				}
			}
		}
	}
	// add the extras
	[result setObject:extras forKey:KEY_EQUIPMENT_EXTRAS];
	// add the ship spec
	[result setObject:shipInfo forKey:SHIPYARD_KEY_SHIP];
	// add it to the station's shipyard
	[shipyard addObject:result];

	// refresh the screen if the shipyard is currently being displayed
	if(station == [PLAYER dockedStation] && [PLAYER guiScreen] == GUI_SCREEN_SHIPYARD)
	{
		[PLAYER setGuiToShipyardScreen:0];
	}	

	OOJS_RETURN_BOOL(YES);

	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool StationRemoveShipFromShipyard(Context cx, CallArgs &oojsArgs)

{

	JSContext *context = OOJSRCX(cx);

	uintN argc = oojsArgs.count();

	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	

	OOJS_NATIVE_ENTER(context)

	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op

	// make sure the station has a shipyard
	if (![station hasShipyard]) {
		OOJSReportWarningForCaller(context, @"Station", @"removeShipFromShipyard", @"Station does not have shipyard.");
		return NO;
	}
	// make sure the shipyard has been generated
	if (![station localShipyard]) [station generateShipyard];
	NSMutableArray *shipyard = [station localShipyard];
	
	int32 shipIndex = -1;
	BOOL gotIndex = YES;
	gotIndex = ooscript::valueToInt32(OOJSFCX(context), OOJSFVAL(OOJS_ARGV[0]), &shipIndex);

	if (argc != 1 || (!JSVAL_IS_NULL(OOJS_ARGV[0]) && !gotIndex) || shipIndex < 0 || (shipIndex + 1) > [shipyard count]) 
	{
		OOJSReportBadArguments(context, @"Station", @"removeShipFromShipyard", MIN(argc, 1U), OOJS_ARGV, NULL, @"valid ship index");
		return NO;
	}

	[shipyard removeObjectAtIndex:shipIndex];

	// refresh the screen if the shipyard is currently being displayed
	if(station == [PLAYER dockedStation] && [PLAYER guiScreen] == GUI_SCREEN_SHIPYARD)
	{
		[PLAYER setGuiToShipyardScreen:0];
	}

	OOJS_RETURN_BOOL(YES);

	OOJS_NATIVE_EXIT
}
} // namespace

