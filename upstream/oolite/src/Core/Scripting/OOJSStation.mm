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

#import "OOPListView.h"
#import "OOEquipmentType.h"
#import "OOShipRegistry.h"
#import "OOConstToString.h"
#import "StationEntity.h"
#import "GameController.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>
#include <cstdint>
#import "OOStringBridge.h"
#import "OOFoundationBridge.h"

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar): the class dispatch table becomes a static ooscript::ClassDef
	(the stub hooks are nullptr), InitClass becomes ooscript::initClass, native methods and
	class hooks take the façade's hook signature (Context/Object/PropertyId/Value pointer/
	CallArgs reference), and the directly spelled numeric-conversion / object-conversion /
	property-lookup calls (NewNumberValue, ValueToBoolean, ValueToNumber, ValueToInt32,
	ValueToObject, GetProperty) become their ooscript:: façade equivalents. Natives take the
	façade signature directly (ooscript::Context and a CallArgs reference) and the OOJS_*
	argument-marshalling macros expand to the CallArgs accessors, so the rest of each function
	body is UNCHANGED. `this` is renamed to `thisObj` because it is a reserved word once this file
	compiles as Objective-C++ (ADR-0001).

	Station is registered as a Ship subclass and object converter with &sStationClass, the same
	ooscript::ClassDef that ooscript::getClass() reports for its instances.
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
static inline Object    *OOJSFOBJP(ooscript::Object *o)  { return reinterpret_cast<Object*>(o); }
} // namespace


namespace {
static ooscript::Object sStationPrototype;
} // namespace

namespace {
static BOOL JSStationGetStationEntity(ooscript::Context context, ooscript::Object stationObj, StationEntity **outEntity);
} // namespace


namespace {
static bool StationGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool StationSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace

namespace {
static bool StationAbortAllDockings(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationAbortDockingForShip(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationCanDockShip(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationDockPlayer(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationIncreaseAlertLevel(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationDecreaseAlertLevel(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationLaunchShipWithRole(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationLaunchDefenseShip(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationLaunchEscort(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationLaunchScavenger(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationLaunchMiner(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationLaunchPirateShip(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationLaunchShuttle(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationLaunchPatrol(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationLaunchPolice(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationSetInterface(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationSetMarketPrice(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationSetMarketQuantity(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationAddShipToShipyard(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool StationRemoveShipFromShipyard(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
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
	nullptr,				// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,				// resolve (engine default: ResolveStub)
	nullptr,				// convert (engine default: ConvertStub)
	OOJSObjectWrapperFinalize,		// finalize
	nullptr,				// call
	nullptr,				// construct
	nullptr,				// backend: owned by the façade backend, must start null
};
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
	{ "dockedContractors",			kStation_dockedContractors,			OOJS_PROP_READONLY_CB, nullptr, nullptr },
	{ "dockedDefenders",			kStation_dockedDefenders,			OOJS_PROP_READONLY_CB, nullptr, nullptr },
	{ "dockedPolice",				kStation_dockedPolice,				OOJS_PROP_READONLY_CB, nullptr, nullptr },
	{ "equipmentPriceFactor",		kStation_equipmentPriceFactor,		OOJS_PROP_READONLY_CB, nullptr, nullptr },
	{ "equivalentTechLevel",		kStation_equivalentTechLevel,		OOJS_PROP_READONLY_CB, nullptr, nullptr },
	{ "hasNPCTraffic",				kStation_hasNPCTraffic,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "hasShipyard",				kStation_hasShipyard,				OOJS_PROP_READONLY_CB, nullptr, nullptr },
	{ "isMainStation",				kStation_isMainStation,				OOJS_PROP_READONLY_CB, nullptr, nullptr },
	{ "market",						kStation_market,					OOJS_PROP_READONLY_CB, nullptr, nullptr },
	{ "requiresDockingClearance",	kStation_requiresDockingClearance,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "roll",						kStation_roll,						PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "suppressArrivalReports",		kStation_suppressArrivalReports,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "shipyard",					kStation_shipyard,					OOJS_PROP_READONLY_CB, nullptr, nullptr },
	{ 0 }
};
} // namespace


// A raw jsapi mirror of sStationProperties, used only for the two bad-property error
// reporters in OOJavaScriptEngine.m (OOJSReportBadPropertySelector/Value): those helpers are
// outside this bead's scope (shared across every binding file) and still take a
// ooscript::PropertySpec*, not ooscript::PropertySpec* (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static ooscript::PropertySpec sStationPropertiesRaw[] =
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


void InitOOJSStation(ooscript::Context context, ooscript::Object global)
{
	Object proto = ooscript::initClass((context), (global), (JSShipPrototype()), &sStationClass, OOJSUnconstructableConstruct, 0, sStationProperties, sStationMethods, NULL, NULL);
	sStationPrototype = (proto);
	OOJSRegisterObjectConverter(&sStationClass, OOJSBasicPrivateObjectConverter);
	OOJSRegisterSubclass(&sStationClass, JSShipClass());
}


namespace {
static BOOL JSStationGetStationEntity(ooscript::Context context, ooscript::Object stationObj, StationEntity **outEntity)
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
static BOOL JSStationGetShipEntity(ooscript::Context context, ooscript::Object shipObj, ShipEntity **outEntity)
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

- (void)getJSClass:(ooscript::ClassDef **)outClass andPrototype:(ooscript::Object *)outPrototype
{
	*outClass = &sStationClass;
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
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = (value);
	
	OOJS_NATIVE_ENTER(context)
	
	StationEntity				*entity = nil;
	
	if (!JSStationGetStationEntity(context, thisObj, &entity))  return NO;
	if (entity == nil)  { *value_raw = ooscript::undefinedValue(); return YES; }
	
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
			*value_raw = ooscript::int32Value([entity alertLevel]);
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
			*value_raw = ooscript::int32Value([entity countOfDockedContractors]);
			return YES;
			
		case kStation_dockedPolice:
			*value_raw = ooscript::int32Value([entity countOfDockedPolice]);
			return YES;
			
		case kStation_dockedDefenders:
			*value_raw = ooscript::int32Value([entity countOfDockedDefenders]);
			return YES;
			
		case kStation_equivalentTechLevel:
			*value_raw = ooscript::int32Value((int32_t)[entity equivalentTechLevel]);
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
				if ([entity cxx_localShipyard] == nullptr) [entity generateShipyard];
				std::vector<oo::PList> *shipyard = [entity cxx_localShipyard];
				*value_raw = OOJSValueFromNativeObject(context, shipyard != nullptr ? oo::ObjectFromPList(oo::PList(*shipyard)) : nil);
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
			OOJSReportBadPropertySelector(context, thisObj, (propID), sStationPropertiesRaw);
			return NO;
	}
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool StationSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = (value);
	
	OOJS_NATIVE_ENTER(context)
	
	StationEntity				*entity = nil;
	bool						bValue;
	int32_t						iValue;
	double					fValue;
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
			OOJSReportBadPropertySelector(context, thisObj, (propID), sStationPropertiesRaw);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, (propID), sStationPropertiesRaw, *value_raw);
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// *** Methods ***

namespace {
static bool StationAbortAllDockings(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	StationEntity *station = nil;
	JSStationGetStationEntity(context, OOJS_THIS, &station); 
	[station abortAllDockings];
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace

namespace {
static bool StationAbortDockingForShip(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	StationEntity *station = nil;
	JSStationGetStationEntity(context, OOJS_THIS, &station); 
	if (oojsArgs.count() == 0)
	{
		OOJSReportBadArguments(context, @"Station", @"abortDockingForShip", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"ship in docking queue");
		return NO;
	}
	if (!ooscript::isObjectOrNull(OOJS_ARGV[0]))  return NO;
	ShipEntity *ship = nil;
	JSStationGetShipEntity(context, ooscript::toObject(OOJS_ARGV[0]), &ship);
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
static bool StationCanDockShip(ooscript::Context context, ooscript::CallArgs &oojsArgs)

{




	

   OOJS_NATIVE_ENTER(context)

   BOOL         result = YES;
   ShipEntity      *shipToCheck = nil;

   if (oojsArgs.count() > 0)
   {
      if (!ooscript::isObjectOrNull(OOJS_ARGV[0]) || !JSStationGetShipEntity(context, ooscript::toObject(OOJS_ARGV[0]), &shipToCheck))
      {
         return NO;
      }
   }
   if (EXPECT_NOT(shipToCheck == nil))
   {
      OOJSReportBadArguments(context, @"Station", @"canDockShip", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"shipEntity");
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
static bool StationDockPlayer(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
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
static bool StationIncreaseAlertLevel(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
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
static bool StationDecreaseAlertLevel(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
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
static bool StationLaunchShipWithRole(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	NSString		*shipRole = nil;
	StationEntity	*station = nil;
	ShipEntity		*result = nil;
	bool			abortAllDockings = NO;
	
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op
	
	if (oojsArgs.count() > 0)  shipRole = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(shipRole == nil))
	{
		OOJSReportBadArguments(context, @"Station", @"launchShipWithRole", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string (role)");
		return NO;
	}
	
	if (oojsArgs.count() > 1)  ooscript::valueToBoolean((context), (OOJS_ARGV[1]), &abortAllDockings);

	OOJS_BEGIN_FULL_NATIVE(context)
	result = [station launchIndependentShip:shipRole];
	if (abortAllDockings) [station abortAllDockings];
	OOJS_END_FULL_NATIVE

	OOJS_RETURN_OBJECT(result);
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool StationLaunchDefenseShip(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
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
static bool StationLaunchEscort(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
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
static bool StationLaunchScavenger(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
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
static bool StationLaunchMiner(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
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
static bool StationLaunchPirateShip(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
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
static bool StationLaunchShuttle(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
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
static bool StationLaunchPatrol(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
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
static bool StationLaunchPolice(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
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
static bool StationSetInterface(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)

	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op

	if (oojsArgs.count() < 1)
	{
		OOJSReportBadArguments(context, @"Station", @"setInterface", MIN(oojsArgs.count(), 1U), OOJS_ARGV, NULL, @"key [, definition]");
		return NO;
	}
	NSString *key = OOStringFromJSValue(context, OOJS_ARGV[0]);

	if (oojsArgs.count() < 2 || ooscript::isNull(OOJS_ARGV[1]))
	{
		[station cxx_setInterfaceDefinition:nil forKey:oo::StdString(key)];
		OOJS_RETURN_VOID;
	}
	

	ooscript::Value				value = ooscript::nullValue();
	ooscript::Value				callback = ooscript::nullValue();
	ooscript::Object callbackThis = NULL;
	ooscript::Object params = NULL;

	NSString      *title = nil;
	NSString      *summary = nil;
	NSString      *category = nil;

	if (!ooscript::valueToObject(context, (OOJS_ARGV[1]), OOJSFOBJP(&params)))
	{
		OOJSReportBadArguments(context, @"Station", @"setInterface", MIN(oojsArgs.count(), 1U), OOJS_ARGV, NULL, @"key [, definition]");
		return NO;
	}

	// get and validate title
	if (!ooscript::getProperty(context, (params), "title", (&value)) || ooscript::isUndefined(value))
	{
		OOJSReportBadArguments(context, @"Station", @"setInterface", MIN(oojsArgs.count(), 1U), OOJS_ARGV, NULL, @"key [, definition]; if definition is set, it must have a 'title' property.");
		return NO;
	}
	title = OOStringFromJSValue(context, value);
	if (title == nil || [title length] == 0) 
	{
		OOJSReportBadArguments(context, @"Station", @"setInterface", MIN(oojsArgs.count(), 1U), OOJS_ARGV, NULL, @"key [, definition]; if definition is set, 'title' property must be a non-empty string.");
		return NO;
	}

	// get category with default
	if (!ooscript::getProperty(context, (params), "category", (&value)) || ooscript::isUndefined(value))
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
	if (!ooscript::getProperty(context, (params), "summary", (&value)) || ooscript::isUndefined(value))
	{
		OOJSReportBadArguments(context, @"Station", @"setInterface", MIN(oojsArgs.count(), 1U), OOJS_ARGV, NULL, @"key [, definition]; if definition is set, it must have a 'summary' property.");
		return NO;
	}
	summary = OOStringFromJSValue(context, value);
	if (summary == nil || [summary length] == 0) 
	{
		OOJSReportBadArguments(context, @"Station", @"setInterface", MIN(oojsArgs.count(), 1U), OOJS_ARGV, NULL, @"key [, definition]; if definition is set, 'summary' property must be a non-empty string.");
		return NO;
	}

	// get and validate callback
	if (!ooscript::getProperty(context, (params), "callback", (&callback)) || ooscript::isUndefined(callback))
	{
		OOJSReportBadArguments(context, @"Station", @"setInterface", MIN(oojsArgs.count(), 1U), OOJS_ARGV, NULL, @"key [, definition]; if definition is set, it must have a 'callback' property.");
		return NO;
	}
	if (!OOJSValueIsFunction(context,callback))
	{
		OOJSReportBadArguments(context, @"Station", @"setInterface", MIN(oojsArgs.count(), 1U), OOJS_ARGV, NULL, @"key [, definition]; 'callback' property must be a function.");
		return NO;
	}

	OOJSInterfaceDefinition* definition = [[OOJSInterfaceDefinition alloc] init];
	[definition setTitle:title];
	[definition setCategory:oo::StdString(category)];
	[definition setSummary:oo::StdString(summary)];
	[definition setCallback:callback];

	// get callback 'this'
	if (ooscript::getProperty(context, (params), "cbThis", (&value)) && !ooscript::isUndefined(value))
	{
		ooscript::valueToObject(context, (value), OOJSFOBJP(&callbackThis));
		[definition setCallbackThis:callbackThis];
		// can do .bind(this) for callback instead
	}
	
	[station cxx_setInterfaceDefinition:definition forKey:oo::StdString(key)];

	[definition release];

	OOJS_RETURN_VOID;

	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool StationSetMarketPrice(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)

	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op

	if (oojsArgs.count() < 2)
	{
		OOJSReportBadArguments(context, @"Station", @"setMarketPrice", MIN(oojsArgs.count(), 2U), OOJS_ARGV, NULL, @"commodity, credits");
		return NO;
	}
	
	OOCommodityType commodity = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(![[UNIVERSE commodities] goodDefined:commodity]))
	{
		OOJSReportBadArguments(context, @"Station", @"setMarketPrice", MIN(oojsArgs.count(), 2U), OOJS_ARGV, NULL, @"Unrecognised commodity type");
		return NO;
	}

	int32_t price;
	BOOL gotPrice = ooscript::valueToInt32((context), (OOJS_ARGV[1]), &price);
	if (EXPECT_NOT(!gotPrice || price < 0))
	{
		OOJSReportBadArguments(context, @"Station", @"setMarketPrice", MIN(oojsArgs.count(), 2U), OOJS_ARGV, NULL, @"Price must be at least 0 decicredits");
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
static bool StationSetMarketQuantity(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)

	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op

	if (oojsArgs.count() < 2)
	{
		OOJSReportBadArguments(context, @"Station", @"setMarketQuantity", MIN(oojsArgs.count(), 2U), OOJS_ARGV, NULL, @"commodity, units");
		return NO;
	}
	
	OOCommodityType commodity = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(![[UNIVERSE commodities] goodDefined:commodity]))
	{
		OOJSReportBadArguments(context, @"Station", @"setMarketQuantity", MIN(oojsArgs.count(), 2U), OOJS_ARGV, NULL, @"Unrecognised commodity type");
		return NO;
	}

	int32_t quantity;
	BOOL gotQuantity = ooscript::valueToInt32((context), (OOJS_ARGV[1]), &quantity);
	if (EXPECT_NOT(!gotQuantity || quantity < 0 || (OOCargoQuantity)quantity > [[station localMarket] capacityForGood:commodity]))
	{
		OOJSReportBadArguments(context, @"Station", @"setMarketQuantity", MIN(oojsArgs.count(), 2U), OOJS_ARGV, NULL, @"Quantity must be between 0 and the station market capacity");
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
static bool StationAddShipToShipyard(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)

	ooscript::Object params = NULL;
	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op

	if (oojsArgs.count() != 1 || (!ooscript::isNull(OOJS_ARGV[0]) && !ooscript::valueToObject((context), (OOJS_ARGV[0]), OOJSFOBJP(&params))))
	{
		OOJSReportBadArguments(context, @"Station", @"addShipToShipyard", MIN(oojsArgs.count(), 1U), OOJS_ARGV, NULL, @"shipyard item definition");
		return NO;
	}

	// make sure the station has a shipyard
	if (![station hasShipyard]) {
		OOJSReportWarningForCaller(context, @"Station", @"removeShipFromShipyard", @"Station does not have shipyard.");
		return NO;
	}
	// make sure the shipyard has been generated
	if (![station cxx_localShipyard]) [station generateShipyard];
	std::vector<oo::PList> *shipyard = [station cxx_localShipyard];

	if (ooscript::isNull(OOJS_ARGV[0]))  OOJS_RETURN_VOID;	// OK, do nothing for null ship.

	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	NSDictionary *shipyardDefinition = OOJSNativeObjectFromJSObject(context, ooscript::toObject(OOJS_ARGV[0]));
	// validate each element of the dictionary
	if (!shipyardDefinition) 
	{
		OOJSReportBadArguments(context, @"Station", @"addShipToShipyard", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"valid dictionary object");
		return NO;
	}
	if (![shipyardDefinition objectForKey:KEY_SHORT_DESCRIPTION]) 
	{
		OOJSReportBadArguments(context, @"Station", @"addShipToShipyard", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"'short_description' in dictionary");
		return NO;
	}
	[result setObject:oo::PListView(shipyardDefinition).get<NSString *>(@"short_description") forKey:KEY_SHORT_DESCRIPTION];
	if (![shipyardDefinition objectForKey:SHIPYARD_KEY_SHIPDATA_KEY]) 
	{
		OOJSReportBadArguments(context, @"Station", @"addShipToShipyard", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"'shipdata_key' in dictionary");
		return NO;
	}
	// get the shipInfo and shipyardInfo for this key
	NSString 			*shipKey = oo::PListView(shipyardDefinition).get<NSString *>(SHIPYARD_KEY_SHIPDATA_KEY, nil);
	OOShipRegistry		*registry = [OOShipRegistry sharedRegistry];
	NSMutableDictionary	*shipInfo = [NSMutableDictionary dictionaryWithDictionary:[registry shipInfoForKey:shipKey]];
	NSDictionary		*shipyardInfo = [registry shipyardInfoForKey:shipKey];
	if (!shipInfo) 
	{
		OOJSReportWarningForCaller(context, @"Station", @"addShipToShipyard", @"Invalid shipdata_key provided.");
		return NO;
	}
	// make sure the ship is a player ship
	if ([oo::PListView(shipInfo).get<NSString *>(@"roles") rangeOfString:@"player"].location == NSNotFound)
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
		OOCreditsQuantity price = oo::PListView(shipyardInfo).get<unsigned int>(KEY_PRICE);
		[result setObject:[NSNumber numberWithUnsignedLongLong:price] forKey:SHIPYARD_KEY_PRICE];
	}
	else 
	{
		OOCreditsQuantity price = oo::PListView(shipyardDefinition).get<unsigned int>(SHIPYARD_KEY_PRICE);
		if (price > 0)
		{
			[result setObject:[NSNumber numberWithUnsignedLongLong:price] forKey:SHIPYARD_KEY_PRICE];
		}
		else
		{
			OOJSReportBadArguments(context, @"Station", @"addShipToShipyard", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"'price' in dictionary");
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
		[result setObject:[NSNumber numberWithUnsignedLongLong:oo::PListView(shipyardDefinition).get<unsigned int>(SHIPYARD_KEY_PERSONALITY)] forKey:SHIPYARD_KEY_PERSONALITY];
	}

	NSArray	*extras = oo::PListView(shipyardDefinition).get<NSArray *>(KEY_EQUIPMENT_EXTRAS);
	if (!extras) 
	{
		// pick up defaults if extras not supplied
		extras = [NSArray arrayWithArray:oo::PListView(oo::PListView(shipyardInfo).get<NSDictionary *>(KEY_STANDARD_EQUIPMENT)).get<NSArray *>(KEY_EQUIPMENT_EXTRAS)];
	}
	if ([extras count] > 0) {
		// go looking for lasers and add them directly to our shipInfo
		NSString* fwdWeaponString = oo::PListView(oo::PListView(shipyardInfo).get<NSDictionary *>(KEY_STANDARD_EQUIPMENT)).get<NSString *>(KEY_EQUIPMENT_FORWARD_WEAPON);
		NSString* aftWeaponString = oo::PListView(oo::PListView(shipyardInfo).get<NSDictionary *>(KEY_STANDARD_EQUIPMENT)).get<NSString *>(KEY_EQUIPMENT_AFT_WEAPON);
		OOWeaponFacingSet availableFacings = oo::PListView(shipyardInfo).get<unsigned int>(KEY_WEAPON_FACINGS, VALID_WEAPON_FACINGS) & VALID_WEAPON_FACINGS;

		OOWeaponType fwdWeapon = OOWeaponTypeFromEquipmentIdentifierSloppy(fwdWeaponString);
		OOWeaponType aftWeapon = OOWeaponTypeFromEquipmentIdentifierSloppy(aftWeaponString);

		unsigned int i;
		NSString *equipmentKey = nil;
		for (i = 0; i < [extras count]; i++) {
			equipmentKey = oo::PListView(extras).at<NSString *>(i);
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
	if (shipyard != nullptr)  shipyard->push_back(oo::PListFrom(result));

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
static bool StationRemoveShipFromShipyard(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)

	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op

	// make sure the station has a shipyard
	if (![station hasShipyard]) {
		OOJSReportWarningForCaller(context, @"Station", @"removeShipFromShipyard", @"Station does not have shipyard.");
		return NO;
	}
	// make sure the shipyard has been generated
	if (![station cxx_localShipyard]) [station generateShipyard];
	std::vector<oo::PList> *shipyard = [station cxx_localShipyard];
	
	int32_t shipIndex = -1;
	BOOL gotIndex = YES;
	gotIndex = ooscript::valueToInt32((context), (OOJS_ARGV[0]), &shipIndex);

	if (oojsArgs.count() != 1 || (!ooscript::isNull(OOJS_ARGV[0]) && !gotIndex) || shipIndex < 0 || (shipIndex + 1) > (shipyard != nullptr ? shipyard->size() : 0)) 
	{
		OOJSReportBadArguments(context, @"Station", @"removeShipFromShipyard", MIN(oojsArgs.count(), 1U), OOJS_ARGV, NULL, @"valid ship index");
		return NO;
	}

	shipyard->erase(shipyard->begin() + shipIndex);

	// refresh the screen if the shipyard is currently being displayed
	if(station == [PLAYER dockedStation] && [PLAYER guiScreen] == GUI_SCREEN_SHIPYARD)
	{
		[PLAYER setGuiToShipyardScreen:0];
	}

	OOJS_RETURN_BOOL(YES);

	OOJS_NATIVE_EXIT
}
} // namespace

