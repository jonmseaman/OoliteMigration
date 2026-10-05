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

#import "OOEquipmentType.h"
#import "OOCommodities.h"
#import "OOCommodityMarket.h"
#import "OOShipRegistry.h"
#import "OOConstToString.h"
#import "StationEntity.h"
#import "GameController.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>
#include <cstdint>
#include "oofnd/objc/OOException.h"
#import "OOObjCPList.h"
#include "oofnd/String.hpp"

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
/*
	C++20 since bead oo-3oxq, converted the way bead oo-ppc converted OOJSVector.mm (proposed
	ADR-0056 amendment oo-ppc). The JS class was already C++ on the ooscript façade;
	OOJS_NATIVE_ENTER/EXIT and OOJS_PROFILE_ENTER/EXIT are C++ try/catch and scope guards
	(OOJSEngineNativeWrappers.h); BOOL/YES/NO are bool/true/false. The category on StationEntity
	became two free functions, and its methods moved to OOJSStation+ObjCBridge.mm (amendment
	oo-ykoy). OOCommodities, OOCommodityMarket, OOEquipmentType and OOJSInterfaceDefinition, which
	are C++ since beads oo-fqyw, oo-ih7y, oo-fg7i and oo-8fpc, are reached as cxx:: classes through
	oo::ToCxx (amendment oo-ppc, item 4), null-guarded where a message to nil answered; an interface
	definition is still made as its façade, which the station keeps (amendment oo-q9q4 item 1).
	Messages to classes that are still Objective-C (StationEntity, ShipEntity, PlayerEntity,
	Universe, GameController, OOShipRegistry) stay as they are, which is why the file is still .mm
	until Phase 4.
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
static bool JSStationGetStationEntity(ooscript::Context context, ooscript::Object stationObj, StationEntity **outEntity);
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
// -oo_stringForKey: with its nil: the string, a number's -stringValue, or nothing.
std::optional<std::string> StringForKey(const oo::PList &dictionary, std::string_view key)
{
	const oo::PList *value = dictionary.get<oo::PList>(key);
	if (value == nullptr || !(value->isString() || value->isNumber()))  return std::nullopt;
	return dictionary.get<std::string>(key);
}


// -oo_stringAtIndex: with its nil.
std::optional<std::string> StringAtIndex(const oo::PList &array, std::size_t index)
{
	const oo::PList *value = array.at<oo::PList>(index);
	if (value == nullptr || !(value->isString() || value->isNumber()))  return std::nullopt;
	return array.at<std::string>(index);
}


// A mutable dictionary's -setObject:forKey: given a nil value raised this (GNUstep 1.31.1's text),
// and the calling script saw it as "Native exception: <reason>". (Exceptions have their own beads.)
void RaiseNilValueForKey(std::string_view key)
{
	[OOException raise:OOInvalidArgumentException format:"Tried to add nil value for key '%s' to dictionary", std::string(key).c_str()];
}


// A string value for -setObject:forKey:, which raised on nil.
std::string ValueForKey(const std::optional<std::string> &value, std::string_view key)
{
	if (!value.has_value())  RaiseNilValueForKey(key);
	return *value;
}
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
static bool JSStationGetStationEntity(ooscript::Context context, ooscript::Object stationObj, StationEntity **outEntity)
{
	OOJS_PROFILE_ENTER
	
	bool						result;
	Entity						*entity = nil;
	
	if (outEntity == NULL)  return false;
	*outEntity = nil;
	
	result = OOJSEntityGetEntity(context, stationObj, &entity);
	if (!result)  return false;
	
	if (![entity isKindOfClass:[StationEntity class]])  return false;
	
	*outEntity = (StationEntity *)entity;
	return true;
	
	OOJS_PROFILE_EXIT
}
} // namespace

namespace {
static bool JSStationGetShipEntity(ooscript::Context context, ooscript::Object shipObj, ShipEntity **outEntity)
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


// The bodies of StationEntity (OOJavaScriptExtensions), whose methods are in
// OOJSStation+ObjCBridge.mm until StationEntity converts (proposed ADR-0056 amendments oo-ppc and
// oo-ykoy).
void OOJSStationGetJSClass(ooscript::ClassDef **outClass, ooscript::Object *outPrototype)
{
	*outClass = &sStationClass;
	*outPrototype = sStationPrototype;
}

std::optional<std::string> OOJSStationJSClassName(void)
{
	return std::string("Station");
}


namespace {
static bool StationGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return true;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = (value);
	
	OOJS_NATIVE_ENTER(context)
	
	StationEntity				*entity = nil;
	
	if (!JSStationGetStationEntity(context, thisObj, &entity))  return false;
	if (entity == nil)  { *value_raw = ooscript::undefinedValue(); return true; }
	
	switch (ooscript::idToInt32(propID))
	{
		case kStation_isMainStation:
			*value_raw = OOJSValueFromBOOL(entity == [UNIVERSE station]);
			return true;
		
		case kStation_hasNPCTraffic:
			*value_raw = OOJSValueFromBOOL([entity hasNPCTraffic]);
			return true;
			
		case kStation_hasShipyard:
			*value_raw = OOJSValueFromBOOL([entity hasShipyard]);
			return true;
		
		case kStation_alertCondition:
			*value_raw = ooscript::int32Value([entity alertLevel]);
			return true;

		case kStation_allegiance:
		{
			const std::optional<std::string> allegiance = [entity cxx_allegiance];
			*value_raw = OOJSValueFromPList(context, allegiance.has_value() ? oo::PList(*allegiance) : oo::PList());	// null for none
			return true;
		}
			
		case kStation_requiresDockingClearance:
			*value_raw = OOJSValueFromBOOL([entity requiresDockingClearance]);
			return true;
			
		case kStation_roll:
			// same as in ship definition, but this time read/write below
			return ooscript::newNumberValue(cx, [entity flightRoll], value);
			
		case kStation_allowsFastDocking:
			*value_raw = OOJSValueFromBOOL([entity allowsFastDocking]);
			return true;
			
		case kStation_allowsAutoDocking:
			*value_raw = OOJSValueFromBOOL([entity allowsAutoDocking]);
			return true;

		case kStation_dockedContractors:
			*value_raw = ooscript::int32Value([entity countOfDockedContractors]);
			return true;
			
		case kStation_dockedPolice:
			*value_raw = ooscript::int32Value([entity countOfDockedPolice]);
			return true;
			
		case kStation_dockedDefenders:
			*value_raw = ooscript::int32Value([entity countOfDockedDefenders]);
			return true;
			
		case kStation_equivalentTechLevel:
			*value_raw = ooscript::int32Value((int32_t)[entity equivalentTechLevel]);
			return true;
			
		case kStation_equipmentPriceFactor:
			return ooscript::newNumberValue(cx, [entity equipmentPriceFactor], value);
			
		case kStation_suppressArrivalReports:
			*value_raw = OOJSValueFromBOOL([entity suppressArrivalReports]);
			return true;
			
		case kStation_breakPattern:
			*value_raw = OOJSValueFromBOOL([entity hasBreakPattern]);
			return true;

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
				*value_raw = OOJSValueFromPList(context, shipyard != nullptr ? oo::PList(*shipyard) : oo::PList());
			}
			return true;
		}

		case kStation_market:
		{
			*value_raw = OOJSValueFromPList(context, [entity cxx_localMarketForScripting]);
			return true;
		}

		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sStationPropertiesRaw);
			return false;
	}
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool StationSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return true;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = (value);
	
	OOJS_NATIVE_ENTER(context)
	
	StationEntity				*entity = nil;
	bool						bValue;
	int32_t						iValue;
	double					fValue;
	std::optional<std::string>	sValue;
	
	if (!JSStationGetStationEntity(context, thisObj, &entity)) return false;
	if (entity == nil)  return true;
	
	switch (ooscript::idToInt32(propID))
	{
		case kStation_hasNPCTraffic:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[entity setHasNPCTraffic:bValue];
				return true;
			}
			break;
		
		case kStation_alertCondition:
			if (ooscript::valueToInt32(cx, *value, &iValue))
			{
				[entity setAlertLevel:(OOStationAlertLevel)iValue signallingScript:false];	// Performs range checking
				return true;
			}
			break;

		case kStation_allegiance:
			sValue = cxx_OOStringFromJSValue(context,*value_raw);
			if (sValue.has_value())
			{
				[entity cxx_setAllegiance:sValue];
				return true;
			}
			break;

			
		case kStation_requiresDockingClearance:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[entity setRequiresDockingClearance:bValue];
				return true;
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
				return true;
			}
			break;

		case kStation_allowsFastDocking:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[entity setAllowsFastDocking:bValue];
				return true;
			}
			break;
			
		case kStation_allowsAutoDocking:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[entity setAllowsAutoDocking:bValue];
				return true;
			}
			break;

		case kStation_suppressArrivalReports:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[entity setSuppressArrivalReports:bValue];
				return true;
			}
			break;

		case kStation_breakPattern:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[entity setHasBreakPattern:bValue];
				return true;
			}
			break;
		
		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sStationPropertiesRaw);
			return false;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, (propID), sStationPropertiesRaw, *value_raw);
	return false;
	
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
		cxx_OOJSReportBadArguments(context, "Station", "abortDockingForShip", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "ship in docking queue");
		return false;
	}
	if (!ooscript::isObjectOrNull(OOJS_ARGV[0]))  return false;
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

   bool         result = true;
   ShipEntity      *shipToCheck = nil;

   if (oojsArgs.count() > 0)
   {
      if (!ooscript::isObjectOrNull(OOJS_ARGV[0]) || !JSStationGetShipEntity(context, ooscript::toObject(OOJS_ARGV[0]), &shipToCheck))
      {
         return false;
      }
   }
   if (EXPECT_NOT(shipToCheck == nil))
   {
      cxx_OOJSReportBadArguments(context, "Station", "canDockShip", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "shipEntity");
      return false;
   }
   
   StationEntity *station = nil;
   if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op
   
   OOJS_BEGIN_FULL_NATIVE(context)
   result = [station fitsInDock:shipToCheck andLogNoFit:false];
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
		[gameController setGamePaused:false];
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
	
	std::optional<std::string>	shipRole;
	StationEntity	*station = nil;
	ShipEntity		*result = nil;
	bool			abortAllDockings = false;
	
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op
	
	if (oojsArgs.count() > 0)  shipRole = cxx_OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(!shipRole.has_value()))
	{
		cxx_OOJSReportBadArguments(context, "Station", "launchShipWithRole", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "string (role)");
		return false;
	}
	
	if (oojsArgs.count() > 1)  ooscript::valueToBoolean((context), (OOJS_ARGV[1]), &abortAllDockings);

	OOJS_BEGIN_FULL_NATIVE(context)
	result = oo::ObjectIn([station launchIndependentShip:*shipRole]);
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
	
	std::vector<oo::ObjCRef<ShipEntity *>> launched;
	OOJS_BEGIN_FULL_NATIVE(context)
	launched = oo::ObjCRefsIn<ShipEntity *>([station launchPolice]);
	OOJS_END_FULL_NATIVE
	OOJS_RETURN_PLIST(oo::PListFromObjects(launched));
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
		cxx_OOJSReportBadArguments(context, "Station", "setInterface", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "key [, definition]");
		return false;
	}
	std::optional<std::string> key = cxx_OOStringFromJSValue(context, OOJS_ARGV[0]);

	if (oojsArgs.count() < 2 || ooscript::isNull(OOJS_ARGV[1]))
	{
		[station cxx_setInterfaceDefinition:nil forKey:key.value_or("")];
		OOJS_RETURN_VOID;
	}
	

	ooscript::Value				value = ooscript::nullValue();
	ooscript::Value				callback = ooscript::nullValue();
	ooscript::Object callbackThis = NULL;
	ooscript::Object params = NULL;

	std::optional<std::string>	title;
	std::optional<std::string>	summary;
	std::optional<std::string>	category;

	if (!ooscript::valueToObject(context, (OOJS_ARGV[1]), OOJSFOBJP(&params)))
	{
		cxx_OOJSReportBadArguments(context, "Station", "setInterface", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "key [, definition]");
		return false;
	}

	// get and validate title
	if (!ooscript::getProperty(context, (params), "title", (&value)) || ooscript::isUndefined(value))
	{
		cxx_OOJSReportBadArguments(context, "Station", "setInterface", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "key [, definition]; if definition is set, it must have a 'title' property.");
		return false;
	}
	title = cxx_OOStringFromJSValue(context, value);
	if (!title.has_value() || title->empty())  
	{
		cxx_OOJSReportBadArguments(context, "Station", "setInterface", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "key [, definition]; if definition is set, 'title' property must be a non-empty string.");
		return false;
	}

	// get category with default
	if (!ooscript::getProperty(context, (params), "category", (&value)) || ooscript::isUndefined(value))
	{
		category = OO_DESC("interfaces-category-uncategorised");
	}
	else
	{
		category = cxx_OOStringFromJSValue(context, value);
		if (!category.has_value() || category->empty()) {
			category = OO_DESC("interfaces-category-uncategorised");
		}
	}

	// get and validate summary
	if (!ooscript::getProperty(context, (params), "summary", (&value)) || ooscript::isUndefined(value))
	{
		cxx_OOJSReportBadArguments(context, "Station", "setInterface", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "key [, definition]; if definition is set, it must have a 'summary' property.");
		return false;
	}
	summary = cxx_OOStringFromJSValue(context, value);
	if (!summary.has_value() || summary->empty())  
	{
		cxx_OOJSReportBadArguments(context, "Station", "setInterface", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "key [, definition]; if definition is set, 'summary' property must be a non-empty string.");
		return false;
	}

	// get and validate callback
	if (!ooscript::getProperty(context, (params), "callback", (&callback)) || ooscript::isUndefined(callback))
	{
		cxx_OOJSReportBadArguments(context, "Station", "setInterface", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "key [, definition]; if definition is set, it must have a 'callback' property.");
		return false;
	}
	if (!OOJSValueIsFunction(context,callback))
	{
		cxx_OOJSReportBadArguments(context, "Station", "setInterface", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "key [, definition]; 'callback' property must be a function.");
		return false;
	}

	// The definition is still made as its façade (its superclass, OOWeakRefObject, is Objective-C:
	// amendment oo-q9q4 item 1), which the station keeps; its members are reached as C++.
	OOJSInterfaceDefinition* definition = [[OOJSInterfaceDefinition alloc] init];
	cxx::OOJSInterfaceDefinition *cxxDefinition = oo::ToCxx(definition);
	cxxDefinition->setTitle(title);
	cxxDefinition->setCategory(*category);
	cxxDefinition->setSummary(*summary);
	cxxDefinition->setCallback(callback);

	// get callback 'this'
	if (ooscript::getProperty(context, (params), "cbThis", (&value)) && !ooscript::isUndefined(value))
	{
		ooscript::valueToObject(context, (value), OOJSFOBJP(&callbackThis));
		cxxDefinition->setCallbackThis(callbackThis);
		// can do .bind(this) for callback instead
	}
	
	[station cxx_setInterfaceDefinition:definition forKey:key.value_or("")];

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
		cxx_OOJSReportBadArguments(context, "Station", "setMarketPrice", MIN(oojsArgs.count(), 2U), OOJS_ARGV, std::nullopt, "commodity, credits");
		return false;
	}
	
	std::optional<std::string> commodity = cxx_OOStringFromJSValue(context, OOJS_ARGV[0]);
	cxx::OOCommodities *commodities = oo::ToCxx([UNIVERSE commodities]);	// null: no good is defined, as a message to nil
	if (EXPECT_NOT(commodities == nullptr || !commodities->goodDefined(commodity.value_or(""))))
	{
		cxx_OOJSReportBadArguments(context, "Station", "setMarketPrice", MIN(oojsArgs.count(), 2U), OOJS_ARGV, std::nullopt, "Unrecognised commodity type");
		return false;
	}

	int32_t price;
	bool gotPrice = ooscript::valueToInt32((context), (OOJS_ARGV[1]), &price);
	if (EXPECT_NOT(!gotPrice || price < 0))
	{
		cxx_OOJSReportBadArguments(context, "Station", "setMarketPrice", MIN(oojsArgs.count(), 2U), OOJS_ARGV, std::nullopt, "Price must be at least 0 decicredits");
		return false;
	}

	[station cxx_setPrice:(NSUInteger)price forCommodity:commodity.value_or("")];

	if (station == [PLAYER dockedStation] && [PLAYER guiScreen] == GUI_SCREEN_MARKET)
	{
		[PLAYER setGuiToMarketScreen]; // refresh screen
	}

	OOJS_RETURN_BOOL(true);

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
		cxx_OOJSReportBadArguments(context, "Station", "setMarketQuantity", MIN(oojsArgs.count(), 2U), OOJS_ARGV, std::nullopt, "commodity, units");
		return false;
	}
	
	const std::string commodity = cxx_OOStringFromJSValue(context, OOJS_ARGV[0]).value_or("");
	cxx::OOCommodities *commodities = oo::ToCxx([UNIVERSE commodities]);	// null: no good is defined, as a message to nil
	if (EXPECT_NOT(commodities == nullptr || !commodities->goodDefined(commodity)))
	{
		cxx_OOJSReportBadArguments(context, "Station", "setMarketQuantity", MIN(oojsArgs.count(), 2U), OOJS_ARGV, std::nullopt, "Unrecognised commodity type");
		return false;
	}

	int32_t quantity;
	bool gotQuantity = ooscript::valueToInt32((context), (OOJS_ARGV[1]), &quantity);
	cxx::OOCommodityMarket *market = oo::ToCxx([station localMarket]);	// null: no capacity, as a message to nil
	if (EXPECT_NOT(!gotQuantity || quantity < 0 || (OOCargoQuantity)quantity > ((market != nullptr) ? market->capacityForGood(commodity) : 0)))
	{
		cxx_OOJSReportBadArguments(context, "Station", "setMarketQuantity", MIN(oojsArgs.count(), 2U), OOJS_ARGV, std::nullopt, "Quantity must be between 0 and the station market capacity");
		return false;
	}

	[station cxx_setQuantity:(OOCargoQuantity)quantity forCommodity:commodity];
	
	if (station == [PLAYER dockedStation] && [PLAYER guiScreen] == GUI_SCREEN_MARKET)
	{
		[PLAYER setGuiToMarketScreen]; // refresh screen
	}

	OOJS_RETURN_BOOL(true);

	OOJS_NATIVE_EXIT
}
} // namespace


namespace {

// -[OOEquipmentType weaponThreatAssessment] of a weapon, which is C++ since bead oo-fg7i: 0 for no
// weapon, as a message to nil answered.
GLfloat WeaponThreatAssessment(OOWeaponType weapon)
{
	cxx::OOEquipmentType *type = oo::ToCxx(weapon);
	return (type != nullptr) ? type->weaponThreatAssessment() : 0;
}

}	// namespace


namespace {
static bool StationAddShipToShipyard(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)

	ooscript::Object params = NULL;
	StationEntity *station = nil;
	if (!JSStationGetStationEntity(context, OOJS_THIS, &station))  OOJS_RETURN_VOID; // stale reference, no-op

	if (oojsArgs.count() != 1 || (!ooscript::isNull(OOJS_ARGV[0]) && !ooscript::valueToObject((context), (OOJS_ARGV[0]), OOJSFOBJP(&params))))
	{
		cxx_OOJSReportBadArguments(context, "Station", "addShipToShipyard", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "shipyard item definition");
		return false;
	}

	// make sure the station has a shipyard
	if (![station hasShipyard]) {
		cxx_OOJSReportWarningForCaller(context, "Station", "removeShipFromShipyard", "Station does not have shipyard.");
		return false;
	}
	// make sure the shipyard has been generated
	if (![station cxx_localShipyard]) [station generateShipyard];
	std::vector<oo::PList> *shipyard = [station cxx_localShipyard];

	if (ooscript::isNull(OOJS_ARGV[0]))  OOJS_RETURN_VOID;	// OK, do nothing for null ship.

	oo::PList::Dict result;
	const oo::PList shipyardDefinition = cxx_OOJSPListFromJSObject(context, ooscript::toObject(OOJS_ARGV[0]));
	// validate each element of the dictionary
	if (shipyardDefinition.isNull())  
	{
		cxx_OOJSReportBadArguments(context, "Station", "addShipToShipyard", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "valid dictionary object");
		return false;
	}
	// This first test is -objectForKey: on the converted object, as it was: anything but a
	// dictionary (a JavaScript array converts to an array) raised, which OOJS_NATIVE_EXIT reported.
	if (!shipyardDefinition.isDict())
	{
		cxx_OOJSReportError(context, "Unidentified native exception");
		return false;
	}
	if (shipyardDefinition.find(KEY_SHORT_DESCRIPTION) == nullptr)
	{
		cxx_OOJSReportBadArguments(context, "Station", "addShipToShipyard", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "'short_description' in dictionary");
		return false;
	}
	result[std::string(KEY_SHORT_DESCRIPTION)] = ValueForKey(StringForKey(shipyardDefinition, "short_description"), KEY_SHORT_DESCRIPTION);
	if (!shipyardDefinition.get<oo::PList>(std::string(SHIPYARD_KEY_SHIPDATA_KEY)))  
	{
		cxx_OOJSReportBadArguments(context, "Station", "addShipToShipyard", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "'shipdata_key' in dictionary");
		return false;
	}
	// get the shipInfo and shipyardInfo for this key
	const std::optional<std::string>	shipKey = StringForKey(shipyardDefinition, std::string(SHIPYARD_KEY_SHIPDATA_KEY));
	OOShipRegistry		*registry = [OOShipRegistry sharedRegistry];
	// A copy of the registry's entry: -dictionaryWithDictionary: made an empty one for an unknown
	// key, never nil, so an unknown key goes on to the tests below (its "Invalid shipdata_key" test
	// could not fire and is gone).
	oo::PList			shipInfo = (shipKey.has_value() ? [registry cxx_shipInfoForKey:*shipKey] : oo::PList());
	if (!shipInfo.isDict())  shipInfo = oo::PList(oo::PList::Dict());
	const oo::PList		shipyardInfo = (shipKey.has_value() ? [registry cxx_shipyardInfoForKey:*shipKey] : oo::PList());
	// make sure the ship is a player ship (no roles string searched as a nil receiver: found at 0)
	const std::optional<std::string> roles = StringForKey(shipInfo, "roles");
	if (roles.has_value() && roles->find("player") == std::string::npos)
	{
		cxx_OOJSReportWarningForCaller(context, "Station", "addShipToShipyard", "shipdata_key not suitable for player role.");
		return false;
	}
	if (!shipyardInfo) 
	{
		cxx_OOJSReportWarningForCaller(context, "Station", "addShipToShipyard", "No shipyard information found for shipdata_key.");
		return false;
	}
	// ok, feel pretty safe to include this ship now
	result[std::string(SHIPYARD_KEY_SHIPDATA_KEY)] = *shipKey;	// non-nil: a nil key found no shipyard information above

	// add an ID
	Random_Seed ship_seed = [UNIVERSE marketSeed];
	int superRand1 = ship_seed.a * 0x10000 + ship_seed.c * 0x100 + ship_seed.e;
	uint32_t superRand2 = ship_seed.b * 0x10000 + ship_seed.d * 0x100 + ship_seed.f;
	superRand2 &= Ranrot();
	std::string shipID = oo::str::format("%06x-%06x", superRand1, superRand2);
	result[std::string(SHIPYARD_KEY_ID)] = shipID;

	if (!shipyardDefinition.get<oo::PList>(std::string(SHIPYARD_KEY_PRICE)))
	{
		// if not provided, get the price from the registry
		OOCreditsQuantity price = shipyardInfo.get<unsigned int>(std::string(KEY_PRICE));
		result[std::string(SHIPYARD_KEY_PRICE)] = oo::PList::unsignedInteger(price);
	}
	else
	{
		OOCreditsQuantity price = shipyardDefinition.get<unsigned int>(std::string(SHIPYARD_KEY_PRICE));
		if (price > 0)
		{
			result[std::string(SHIPYARD_KEY_PRICE)] = oo::PList::unsignedInteger(price);
		}
		else
		{
			cxx_OOJSReportBadArguments(context, "Station", "addShipToShipyard", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "'price' in dictionary");
			return false;
		}
	}

	if (!shipyardDefinition.get<oo::PList>(std::string(SHIPYARD_KEY_PERSONALITY)))
	{
		// default to 0 if not supplied -- this set a nil value, which raised; the script still sees that
		RaiseNilValueForKey(SHIPYARD_KEY_PERSONALITY);
	}
	else
	{
		result[std::string(SHIPYARD_KEY_PERSONALITY)] = oo::PList::unsignedInteger(shipyardDefinition.get<unsigned int>(std::string(SHIPYARD_KEY_PERSONALITY)));
	}

	const oo::PList *standardEquipment = shipyardInfo.get<oo::PList::Dict>(std::string(KEY_STANDARD_EQUIPMENT));
	oo::PList extras;
	if (const oo::PList *definedExtras = shipyardDefinition.get<oo::PList::Array>(std::string(KEY_EQUIPMENT_EXTRAS)))  extras = *definedExtras;
	else
	{
		// pick up defaults if extras not supplied (-arrayWithArray: made an empty array of a missing one)
		const oo::PList *standardExtras = (standardEquipment != nullptr) ? standardEquipment->get<oo::PList::Array>(std::string(KEY_EQUIPMENT_EXTRAS)) : nullptr;
		extras = (standardExtras != nullptr) ? *standardExtras : oo::PList(oo::PList::Array());
	}
	if (extras.count() > 0) {
		// go looking for lasers and add them directly to our shipInfo
		std::optional<std::string> fwdWeaponString = (standardEquipment != nullptr) ? StringForKey(*standardEquipment, std::string(KEY_EQUIPMENT_FORWARD_WEAPON)) : std::nullopt;
		std::optional<std::string> aftWeaponString = (standardEquipment != nullptr) ? StringForKey(*standardEquipment, std::string(KEY_EQUIPMENT_AFT_WEAPON)) : std::nullopt;
		OOWeaponFacingSet availableFacings = shipyardInfo.get<unsigned int>(std::string(KEY_WEAPON_FACINGS), VALID_WEAPON_FACINGS) & VALID_WEAPON_FACINGS;

		OOWeaponType fwdWeapon = cxx_OOWeaponTypeFromEquipmentIdentifierSloppy(fwdWeaponString.value_or(""));
		OOWeaponType aftWeapon = cxx_OOWeaponTypeFromEquipmentIdentifierSloppy(aftWeaponString.value_or(""));

		unsigned int i;
		std::optional<std::string> equipmentKey;
		for (i = 0; i < extras.count(); i++) {
			equipmentKey = StringAtIndex(extras, i);
			if (equipmentKey.has_value() && oo::str::hasPrefix(*equipmentKey, "EQ_WEAPON"))
			{
				OOWeaponType new_weapon = cxx_OOWeaponTypeFromEquipmentIdentifierSloppy(equipmentKey.value_or(""));
				//fit best weapon forward
				if (availableFacings & WEAPON_FACING_FORWARD && WeaponThreatAssessment(new_weapon) > WeaponThreatAssessment(fwdWeapon))
				{
					//again remember to divide price by 10 to get credits from tenths of credit
					fwdWeaponString = equipmentKey;
					fwdWeapon = new_weapon;
					(*shipInfo.getIf<oo::PList::Dict>())[std::string(KEY_EQUIPMENT_FORWARD_WEAPON)] = *fwdWeaponString;
				}
				else 
				{
					//if less good than current forward, try fitting is to rear
					if (availableFacings & WEAPON_FACING_AFT && (isWeaponNone(aftWeapon) || WeaponThreatAssessment(new_weapon) > WeaponThreatAssessment(aftWeapon)))
					{
						aftWeaponString = equipmentKey;
						aftWeapon = new_weapon;
						(*shipInfo.getIf<oo::PList::Dict>())[std::string(KEY_EQUIPMENT_AFT_WEAPON)] = *aftWeaponString;
					}
				}
			}
		}
	}
	// add the extras
	result[std::string(KEY_EQUIPMENT_EXTRAS)] = extras;
	// add the ship spec
	result[std::string(SHIPYARD_KEY_SHIP)] = shipInfo;
	// add it to the station's shipyard
	if (shipyard != nullptr)  shipyard->push_back(oo::PList(std::move(result)));

	// refresh the screen if the shipyard is currently being displayed
	if(station == [PLAYER dockedStation] && [PLAYER guiScreen] == GUI_SCREEN_SHIPYARD)
	{
		[PLAYER setGuiToShipyardScreen:0];
	}	

	OOJS_RETURN_BOOL(true);

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
		cxx_OOJSReportWarningForCaller(context, "Station", "removeShipFromShipyard", "Station does not have shipyard.");
		return false;
	}
	// make sure the shipyard has been generated
	if (![station cxx_localShipyard]) [station generateShipyard];
	std::vector<oo::PList> *shipyard = [station cxx_localShipyard];
	
	int32_t shipIndex = -1;
	bool gotIndex = true;
	gotIndex = ooscript::valueToInt32((context), (OOJS_ARGV[0]), &shipIndex);

	if (oojsArgs.count() != 1 || (!ooscript::isNull(OOJS_ARGV[0]) && !gotIndex) || shipIndex < 0 || (shipIndex + 1) > (shipyard != nullptr ? shipyard->size() : 0)) 
	{
		cxx_OOJSReportBadArguments(context, "Station", "removeShipFromShipyard", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "valid ship index");
		return false;
	}

	shipyard->erase(shipyard->begin() + shipIndex);

	// refresh the screen if the shipyard is currently being displayed
	if(station == [PLAYER dockedStation] && [PLAYER guiScreen] == GUI_SCREEN_SHIPYARD)
	{
		[PLAYER setGuiToShipyardScreen:0];
	}

	OOJS_RETURN_BOOL(true);

	OOJS_NATIVE_EXIT
}
} // namespace

