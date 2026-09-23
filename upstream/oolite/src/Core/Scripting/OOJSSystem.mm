/*
 
 OOJSSystem.mm
 
 
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

#import "OOJSSystem.h"
#import "OOJavaScriptEngine.h"

#import "OOJSVector.h"
#import "OOJSQuaternion.h"
#import "OOJSEntity.h"
#import "OOJSPlayer.h"
#import "Universe.h"
#import "OOPlanetEntity.h"
#import "PlayerEntityScriptMethods.h"
#import "OOJSSystemInfo.h"

#import "OOCollectionExtractors.h"
#import "OOConstToString.h"
#import "OOConstToJSString.h"
#import "OOEntityFilterPredicate.h"
#import "OOFilteringEnumerator.h"
#import "OOJSPopulatorDefinition.h"
#import "OODebugStandards.h"
#import "EntityOOJavaScriptExtensions.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar): the class dispatch table becomes a static ooscript::ClassDef
	(the stub hooks are nullptr), InitClass becomes ooscript::initClass, the engine's
	DefineObject call becomes ooscript::defineObject (see OOJSClock.mm/OOJSPlayer.mm for the
	same InitClass-then-defineObject pairing), native methods and class hooks take the
	façade's hook signature (Context/Object/PropertyId/Value pointer/CallArgs reference), and
	the directly spelled numeric- and object-conversion calls (NewNumberValue, ValueToNumber,
	ValueToBoolean, ValueToInt32, ValueToObject, GetProperty) become their ooscript::
	equivalents. Natives take the
	façade signature directly (ooscript::Context and a CallArgs reference) and the OOJS_*
	argument-marshalling macros expand to the CallArgs accessors, so the rest of each function
	body is UNCHANGED. `this` is renamed to `thisObj`
	because it is a reserved word once this file compiles as Objective-C++ (ADR-0001).

	System's constructor is unconstructable, the same as Vector's and Station's: the shared
	OOJSUnconstructableConstruct native is passed to ooscript::initClass directly.
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
static ooscript::Object sSystemPrototype;
} // namespace


// Support functions for entity search methods.
namespace {
static BOOL GetRelativeToAndRange(ooscript::Context context, NSString *methodName, unsigned *ioArgc, ooscript::Value **ioArgv, Entity **outRelativeTo, double *outRange);
} // namespace
namespace {
static NSArray *FindJSVisibleEntities(EntityFilterPredicate predicate, void *parameter, Entity *relativeTo, double range);
} // namespace
namespace {
static NSArray *FindShips(EntityFilterPredicate predicate, void *parameter, Entity *relativeTo, double range);
} // namespace
namespace {
static NSComparisonResult CompareEntitiesByDistance(id a, id b, void *relativeTo);
} // namespace

namespace {
static bool SystemAddShipsOrGroup(Context cx, CallArgs &oojsArgs, BOOL isGroup);
} // namespace
namespace {
static bool SystemAddShipsOrGroupToRoute(Context cx, CallArgs &oojsArgs, BOOL isGroup);
} // namespace


namespace {
static bool SystemGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool SystemSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace

namespace {
static bool SystemToString(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemAddPlanet(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemAddMoon(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemSendAllShipsAway(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemCountShipsWithPrimaryRole(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemCountShipsWithRole(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemCountEntitiesWithScanClass(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemShipsWithPrimaryRole(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemShipsWithRole(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemEntitiesWithScanClass(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemFilteredEntities(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace

namespace {
static bool SystemLocationFromCode(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemAddShips(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemAddGroup(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemAddShipsToRoute(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemAddGroupToRoute(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemAddVisualEffect(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemSetPopulator(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemSetWaypoint(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace

namespace {
static bool SystemLegacyAddShips(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemLegacyAddSystemShips(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemLegacyAddShipsAt(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemLegacyAddShipsAtPrecisely(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemLegacyAddShipsWithinRadius(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemLegacySpawnShip(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace

namespace {
static bool SystemStaticSystemNameForID(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemStaticSystemIDForName(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemStaticInfoForSystem(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace


namespace {
static ClassDef sSystemClass =
{
	"System",
	ClassFlag::None,

	nullptr,			// addProperty (engine default: PropertyStub)
	nullptr,			// delProperty (engine default: PropertyStub)
	SystemGetProperty,	// getProperty
	SystemSetProperty,	// setProperty
	nullptr,			// enumerate (engine default: EnumerateStub)
	nullptr,			// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,			// resolve (engine default: ResolveStub)
	nullptr,			// convert (engine default: ConvertStub)
	nullptr,			// finalize (engine default: FinalizeStub)
	nullptr,			// call
	nullptr,			// construct
	nullptr,			// backend: owned by the façade backend, must start null
};
} // namespace


enum : std::uint8_t
{
	// Property IDs
	kSystem_allDemoShips,				// demo ships, array of Ship, read-only
	kSystem_allShips,				// ships in system, array of Ship, read-only
	kSystem_allVisualEffects,			// VEs in system, array of VEs, read-only
	kSystem_ambientLevel,			// ambient light level, float, read/write
	kSystem_breakPattern, // witchspace break pattern shown
	kSystem_description,			// description, string, read/write
	kSystem_economy,				// economy ID, integer, read/write
	kSystem_economyDescription,		// economy ID description, string, read-only
	kSystem_government,				// government ID, integer, read/write
	kSystem_governmentDescription,	// government ID description, string, read-only
	kSystem_ID,						// planet number, integer, read-only
	kSystem_info,					// system info dictionary, SystemInfo, read/write
	kSystem_inhabitantsDescription,	// description of inhabitant species, string, read/write
	kSystem_isInterstellarSpace,	// is interstellar space, boolean, read-only
	kSystem_mainPlanet,				// system's main planet, Planet, read-only
	kSystem_mainStation,			// system's main station, Station, read-only
	kSystem_name,					// name, string, read/write
	kSystem_planets,				// planets in system, array of Planet, read-only
	kSystem_population,				// population, integer, read/write
	kSystem_populatorSettings,			// populator settings, dictionary, read-only
	kSystem_productivity,			// productivity, integer, read/write
	kSystem_pseudoRandom100,		// constant-per-system pseudorandom number in [0..100), integer, read-only
	kSystem_pseudoRandom256,		// constant-per-system pseudorandom number in [0..256), integer, read-only
	kSystem_pseudoRandomNumber,		// constant-per-system pseudorandom number in [0..1), double, read-only
	kSystem_sun,					// system's sun, Planet, read-only
	kSystem_stations,     // list of dockable entities, read-only
	kSystem_techLevel,				// tech level ID, integer, read/write
	kSystem_waypoints,     // dictionary of current player waypoints, read-only
	kSystem_wormholes,     // list of active entry wormholes, read-only

};


namespace {
constexpr PropertyFlag kSystemPropertyFlagsRO = PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared;
constexpr PropertyFlag kSystemPropertyFlagsRW = PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared;
} // namespace


namespace {
static PropertySpec sSystemProperties[] =
{
	// JS name						ID							flags					getter	setter
	{ "allDemoShips",			kSystem_allDemoShips,			kSystemPropertyFlagsRO,	nullptr, nullptr },
	{ "allShips",				kSystem_allShips,				kSystemPropertyFlagsRO,	nullptr, nullptr },
	{ "allVisualEffects",		kSystem_allVisualEffects,		kSystemPropertyFlagsRO,	nullptr, nullptr },
	{ "ambientLevel",			kSystem_ambientLevel,			kSystemPropertyFlagsRW,	nullptr, nullptr },
	{ "breakPattern",			kSystem_breakPattern,			kSystemPropertyFlagsRW,	nullptr, nullptr },
	{ "description",			kSystem_description,			kSystemPropertyFlagsRW,	nullptr, nullptr },
	{ "economy",				kSystem_economy,				kSystemPropertyFlagsRW,	nullptr, nullptr },
	{ "economyDescription",		kSystem_economyDescription,		kSystemPropertyFlagsRO,	nullptr, nullptr },
	{ "government",				kSystem_government,				kSystemPropertyFlagsRW,	nullptr, nullptr },
	{ "governmentDescription",	kSystem_governmentDescription,	kSystemPropertyFlagsRO,	nullptr, nullptr },
	{ "ID",						kSystem_ID,						kSystemPropertyFlagsRO,	nullptr, nullptr },
	{ "info",					kSystem_info,					kSystemPropertyFlagsRO,	nullptr, nullptr },
	{ "inhabitantsDescription",	kSystem_inhabitantsDescription,	kSystemPropertyFlagsRW,	nullptr, nullptr },
	{ "isInterstellarSpace",	kSystem_isInterstellarSpace,	kSystemPropertyFlagsRO, nullptr, nullptr },
	{ "mainPlanet",				kSystem_mainPlanet,				kSystemPropertyFlagsRO,	nullptr, nullptr },
	{ "mainStation",			kSystem_mainStation,			kSystemPropertyFlagsRO,	nullptr, nullptr },
	{ "name",					kSystem_name,					kSystemPropertyFlagsRW,	nullptr, nullptr },
	{ "planets",				kSystem_planets,				kSystemPropertyFlagsRO,	nullptr, nullptr },
	{ "population",				kSystem_population,				kSystemPropertyFlagsRW,	nullptr, nullptr },
	{ "populatorSettings",			kSystem_populatorSettings,			kSystemPropertyFlagsRO,	nullptr, nullptr },
	{ "productivity",			kSystem_productivity,			kSystemPropertyFlagsRW,	nullptr, nullptr },
	{ "pseudoRandom100",		kSystem_pseudoRandom100,		kSystemPropertyFlagsRO,	nullptr, nullptr },
	{ "pseudoRandom256",		kSystem_pseudoRandom256,		kSystemPropertyFlagsRO,	nullptr, nullptr },
	{ "pseudoRandomNumber",		kSystem_pseudoRandomNumber,		kSystemPropertyFlagsRO,	nullptr, nullptr },
	{ "stations",					kSystem_stations,					kSystemPropertyFlagsRO,	nullptr, nullptr },
	{ "sun",					kSystem_sun,					kSystemPropertyFlagsRO,	nullptr, nullptr },
	{ "techLevel",				kSystem_techLevel,				kSystemPropertyFlagsRW,	nullptr, nullptr },
	{ "waypoints",					kSystem_waypoints,					kSystemPropertyFlagsRO,	nullptr, nullptr },
	{ "wormholes",					kSystem_wormholes,					kSystemPropertyFlagsRO,	nullptr, nullptr },
	{ 0 }
};
} // namespace


// A raw jsapi mirror of sSystemProperties, used only for the two bad-property error
// reporters in OOJavaScriptEngine.m (OOJSReportBadPropertySelector/Value): those helpers are
// outside this bead's scope (shared across every binding file and are retargeted, if at all,
// by a later seam) and still take a ooscript::PropertySpec*, not ooscript::PropertySpec* (see
// OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static ooscript::PropertySpec sSystemPropertiesRaw[] =
{
	// JS name						ID								flags
	{ "allDemoShips",			kSystem_allDemoShips,			OOJS_PROP_READONLY_CB },
	{ "allShips",				kSystem_allShips,				OOJS_PROP_READONLY_CB },
	{ "allVisualEffects",	 kSystem_allVisualEffects,		OOJS_PROP_READONLY_CB },
	{ "ambientLevel",			kSystem_ambientLevel,			OOJS_PROP_READWRITE_CB },
	{ "breakPattern",			kSystem_breakPattern,			OOJS_PROP_READWRITE_CB },
	{ "description",			kSystem_description,			OOJS_PROP_READWRITE_CB },
	{ "economy",				kSystem_economy,				OOJS_PROP_READWRITE_CB },
	{ "economyDescription",		kSystem_economyDescription,		OOJS_PROP_READONLY_CB },
	{ "government",				kSystem_government,				OOJS_PROP_READWRITE_CB },
	{ "governmentDescription",	kSystem_governmentDescription,	OOJS_PROP_READONLY_CB },
	{ "ID",						kSystem_ID,						OOJS_PROP_READONLY_CB },
	{ "info",					kSystem_info,					OOJS_PROP_READONLY_CB },
	{ "inhabitantsDescription",	kSystem_inhabitantsDescription,	OOJS_PROP_READWRITE_CB },
	{ "isInterstellarSpace",	kSystem_isInterstellarSpace,	OOJS_PROP_READONLY_CB},
	{ "mainPlanet",				kSystem_mainPlanet,				OOJS_PROP_READONLY_CB },
	{ "mainStation",			kSystem_mainStation,			OOJS_PROP_READONLY_CB },
	{ "name",					kSystem_name,					OOJS_PROP_READWRITE_CB },
	{ "planets",				kSystem_planets,				OOJS_PROP_READONLY_CB },
	{ "population",				kSystem_population,				OOJS_PROP_READWRITE_CB },
	{ "populatorSettings",				kSystem_populatorSettings,				OOJS_PROP_READONLY_CB },
	{ "productivity",			kSystem_productivity,			OOJS_PROP_READWRITE_CB },
	{ "pseudoRandom100",		kSystem_pseudoRandom100,		OOJS_PROP_READONLY_CB },
	{ "pseudoRandom256",		kSystem_pseudoRandom256,		OOJS_PROP_READONLY_CB },
	{ "pseudoRandomNumber",		kSystem_pseudoRandomNumber,		OOJS_PROP_READONLY_CB },
	{ "stations",					kSystem_stations,					OOJS_PROP_READONLY_CB },
	{ "sun",					kSystem_sun,					OOJS_PROP_READONLY_CB },
	{ "techLevel",				kSystem_techLevel,				OOJS_PROP_READWRITE_CB },
	{ "waypoints",					kSystem_waypoints,					OOJS_PROP_READONLY_CB },
	{ "wormholes",					kSystem_wormholes,					OOJS_PROP_READONLY_CB },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sSystemMethods[] =
{
	// JS name								Function								min args
	{ "toString",							SystemToString,						0,			0 },
	{ "addGroup",							SystemAddGroup,						3,			0 },
	{ "addGroupToRoute",					SystemAddGroupToRoute,				2,			0 },
	{ "addMoon",							SystemAddMoon,						1,			0 },
	{ "addPlanet",							SystemAddPlanet,					1,			0 },
	{ "addShips",							SystemAddShips,						3,			0 },
	{ "addShipsToRoute",					SystemAddShipsToRoute,				2,			0 },
	{ "addVisualEffect",						SystemAddVisualEffect,						2,			0 },
	{ "countEntitiesWithScanClass",		SystemCountEntitiesWithScanClass,	1,			0 },
	{ "countShipsWithPrimaryRole",		SystemCountShipsWithPrimaryRole,	1,			0 },
	{ "countShipsWithRole",				SystemCountShipsWithRole,			1,			0 },
	{ "entitiesWithScanClass",			SystemEntitiesWithScanClass,		1,			0 },
	{ "filteredEntities",				SystemFilteredEntities,				2,			0 },
	{ "locationFromCode",				SystemLocationFromCode,				1,			0 },
	// scrambledPseudoRandomNumber is implemented in oolite-global-prefix.js
	{ "sendAllShipsAway",				SystemSendAllShipsAway,				1,			0 },
	{ "setPopulator",						SystemSetPopulator,					2,			0 },
	{ "setWaypoint",						SystemSetWaypoint,					4,			0 },
	{ "shipsWithPrimaryRole",			SystemShipsWithPrimaryRole,			1,			0 },
	{ "shipsWithRole",					SystemShipsWithRole,				1,			0 },

	{ "legacy_addShips",					SystemLegacyAddShips,				2,			0 },
	{ "legacy_addSystemShips",			SystemLegacyAddSystemShips,			3,			0 },
	{ "legacy_addShipsAt",				SystemLegacyAddShipsAt,				6,			0 },
	{ "legacy_addShipsAtPrecisely",		SystemLegacyAddShipsAtPrecisely,	6,			0 },
	{ "legacy_addShipsWithinRadius",	SystemLegacyAddShipsWithinRadius,	7,			0 },
	{ "legacy_spawnShip",				SystemLegacySpawnShip,				1,			0 },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sSystemStaticMethods[] =
{
	{ "infoForSystem",			SystemStaticInfoForSystem,					2,			0 },
	{ "systemIDForName",		SystemStaticSystemIDForName,				1,			0 },
	{ "systemNameForID",		SystemStaticSystemNameForID,				1,			0 },
	{ 0 }
};
} // namespace


void InitOOJSSystem(ooscript::Context context, ooscript::Object global)
{
	Object proto = ooscript::initClass((context), (global), nullptr, &sSystemClass,
										OOJSUnconstructableConstruct, 0, sSystemProperties, sSystemMethods,
										nullptr, sSystemStaticMethods);
	sSystemPrototype = (proto);

	// Create system object as a property of the global object.
	ooscript::defineObject((context), (global), "system", &sSystemClass, proto, OOJS_PROP_READONLY);
}


namespace {
static bool SystemGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;

	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = (value);

	OOJS_NATIVE_ENTER(context)
	
	id							result = nil;
	PlayerEntity				*player = nil;
	NSDictionary				*systemData = nil;
	BOOL						handled = NO;
	
	player = OOPlayerForScripting();
	
	// Handle cases which don't require systemData.
	switch (ooscript::idToInt32(propID))
	{
		case kSystem_ID:
			*value_raw = ooscript::int32Value([player currentSystemID]);
			return YES;
			
		case kSystem_isInterstellarSpace:
			*value_raw = OOJSValueFromBOOL([UNIVERSE inInterstellarSpace]);
			return YES;
			
		case kSystem_mainStation:
			result = [UNIVERSE station];
			handled = YES;
			break;
			
		case kSystem_mainPlanet:
			result = [UNIVERSE planet];
			handled = YES;
			break;
			
		case kSystem_sun:
			result = [UNIVERSE sun];
			handled = YES;
			break;
			
		case kSystem_planets:
			result = [[[UNIVERSE planets] objectEnumeratorFilteredWithSelector:@selector(isVisibleToScripts)] allObjects];
			handled = YES;
			break;
			
		case kSystem_stations:
			result = [UNIVERSE stations];
			handled = YES;
			break;

		case kSystem_waypoints:
			result = [UNIVERSE currentWaypoints];
			handled = YES;
			break;

		case kSystem_wormholes:
			result = [UNIVERSE wormholes];
			handled = YES;
			break;

		case kSystem_allShips:
			OOJS_BEGIN_FULL_NATIVE(context)
			result = [UNIVERSE findShipsMatchingPredicate:JSEntityIsJavaScriptSearchablePredicate parameter:NULL inRange:-1 ofEntity:nil];
			OOJS_END_FULL_NATIVE
			handled = YES;
			break;

		case kSystem_allDemoShips:
			OOJS_BEGIN_FULL_NATIVE(context)
			result = [UNIVERSE findShipsMatchingPredicate:JSEntityIsDemoShipPredicate parameter:NULL inRange:-1 ofEntity:nil];
			OOJS_END_FULL_NATIVE
			handled = YES;
			break;


		case kSystem_allVisualEffects:
			OOJS_BEGIN_FULL_NATIVE(context)
			result = [UNIVERSE findVisualEffectsMatchingPredicate:JSEntityIsJavaScriptSearchablePredicate parameter:NULL inRange:-1 ofEntity:nil];
			OOJS_END_FULL_NATIVE
			handled = YES;
			break;
			
		case kSystem_ambientLevel:
			return ooscript::newNumberValue(cx, [UNIVERSE ambientLightLevel], value);
			
		case kSystem_info:
			*value_raw = GetJSSystemInfoForSystem(context, [player currentGalaxyID], [player currentSystemID]);
			return YES;
		
		case kSystem_pseudoRandomNumber:
			return ooscript::newNumberValue(cx, [player systemPseudoRandomFloat], value);
			
		case kSystem_pseudoRandom100:
			*value_raw = ooscript::int32Value([player systemPseudoRandom100]);
			return YES;
			
		case kSystem_pseudoRandom256:
			*value_raw = ooscript::int32Value([player systemPseudoRandom256]);
			return YES;

		case kSystem_breakPattern:
			*value_raw = OOJSValueFromBOOL([UNIVERSE witchspaceBreakPattern]);
			return YES;

		case kSystem_populatorSettings:
			*value_raw = OOJSValueFromNativeObject(context, [UNIVERSE getPopulatorSettings]);
			return YES;
	}
	
	if (!handled)
	{
		// Handle cases which do require systemData.
		if (EXPECT (![UNIVERSE inInterstellarSpace]))
		{
			systemData = [UNIVERSE currentSystemData];
			
			switch (ooscript::idToInt32(propID))
			{
				case kSystem_name:
					result = [systemData objectForKey:KEY_NAME];
					break;
					
				case kSystem_description:
					result = [systemData objectForKey:KEY_DESCRIPTION];
					break;
					
				case kSystem_inhabitantsDescription:
					result = [systemData objectForKey:KEY_INHABITANTS];
					break;
					
				case kSystem_government:
					*value_raw = ooscript::int32Value([systemData oo_intForKey:KEY_GOVERNMENT]);
					return YES;
					
				case kSystem_governmentDescription:
					result = OODisplayStringFromGovernmentID([systemData oo_intForKey:KEY_GOVERNMENT]);
					if (result == nil)  result = DESC(@"not-applicable");
					break;
					
				case kSystem_economy:
					*value_raw = ooscript::int32Value([systemData oo_intForKey:KEY_ECONOMY]);
					return YES;
					
				case kSystem_economyDescription:
					result = OODisplayStringFromEconomyID([systemData oo_intForKey:KEY_ECONOMY]);
					if (result == nil)  result = DESC(@"not-applicable");
					break;
				
				case kSystem_techLevel:
					*value_raw = ooscript::int32Value([systemData oo_intForKey:KEY_TECHLEVEL]);
					return YES;
					
				case kSystem_population:
					*value_raw = ooscript::int32Value([systemData oo_intForKey:KEY_POPULATION]);
					return YES;
					
				case kSystem_productivity:
					*value_raw = ooscript::int32Value([systemData oo_intForKey:KEY_PRODUCTIVITY]);
					return YES;
					
				default:
					OOJSReportBadPropertySelector(context, thisObj, (propID), sSystemPropertiesRaw);
					return NO;
			}
		}
		else
		{
			// if in interstellar space, systemData values are null & void!
			switch (ooscript::idToInt32(propID))
			{
				case kSystem_name:
					result = DESC(@"interstellar-space");
					break;
					
				case kSystem_description:
					result = @"";
					break;
					
				case kSystem_inhabitantsDescription:
					result = DESC(@"not-applicable");
					break;
					
				case kSystem_government:
					*value_raw = ooscript::int32Value(-1);
					return YES;
					
				case kSystem_governmentDescription:
					result = DESC(@"not-applicable");
					break;
					
				case kSystem_economy:
					*value_raw = ooscript::int32Value(-1);
					return YES;
					
				case kSystem_economyDescription:
					result = DESC(@"not-applicable");
					break;
				
				case kSystem_techLevel:
					*value_raw = ooscript::int32Value(-1);
					return YES;
					
				case kSystem_population:
				case kSystem_productivity:
					*value_raw = ooscript::int32Value(0);
					return YES;
					
				default:
					OOJSReportBadPropertySelector(context, thisObj, (propID), sSystemPropertiesRaw);
					return NO;
			}
		}
	}
	
	*value_raw = OOJSValueFromNativeObject(context, result);
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool SystemSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;

	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = (value);

	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity				*player = nil;
	OOGalaxyID					galaxy;
	OOSystemID					system;
	NSString					*stringValue = nil;
	NSString					*manifest = nil;
	double					fValue;
	int32_t						iValue;
	bool						bValue;
	
	player = OOPlayerForScripting();
	
	galaxy = [player currentGalaxyID];
	system = [player currentSystemID];

	switch (ooscript::idToInt32(propID))
	{
		case kSystem_ambientLevel:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				[UNIVERSE setAmbientLightLevel:fValue];
				[UNIVERSE setLighting];
				return YES;
			}
			break;
			
		case kSystem_breakPattern:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[UNIVERSE setWitchspaceBreakPattern:bValue];
				return YES;
			}

			break;
		default:
		{}// do nothing yet
	}

	
	if (system == -1)  return YES;	// Can't change anything else in interstellar space.

	manifest = [[OOJSScript currentlyRunningScript] propertyNamed:kLocalManifestProperty];
	
	switch (ooscript::idToInt32(propID))
	{
		case kSystem_name:
			stringValue = OOStringFromJSValue(context, *value_raw);
			if (stringValue != nil)
			{
				[UNIVERSE setSystemDataForGalaxy:galaxy planet:system key:KEY_NAME value:stringValue fromManifest:manifest forLayer:OO_LAYER_OXP_DYNAMIC];
				return YES;
			}
			break;
			
		case kSystem_description:
			stringValue = OOStringFromJSValue(context, *value_raw);
			if (stringValue != nil)
			{
				[UNIVERSE setSystemDataForGalaxy:galaxy planet:system key:KEY_DESCRIPTION value:stringValue fromManifest:manifest forLayer:OO_LAYER_OXP_DYNAMIC];
				return YES;
			}
			break;
			
		case kSystem_inhabitantsDescription:
			stringValue = OOStringFromJSValue(context, *value_raw);
			if (stringValue != nil)
			{
				[UNIVERSE setSystemDataForGalaxy:galaxy planet:system key:KEY_INHABITANTS value:stringValue fromManifest:manifest forLayer:OO_LAYER_OXP_DYNAMIC];
				return YES;
			}
			break;
			
		case kSystem_government:
			if (ooscript::valueToInt32(cx, *value, &iValue))
			{
				if (iValue < 0)  iValue = 0;
				if (7 < iValue)  iValue = 7;
				[UNIVERSE setSystemDataForGalaxy:galaxy planet:system key:KEY_GOVERNMENT value:[NSNumber numberWithInt:iValue] fromManifest:manifest forLayer:OO_LAYER_OXP_DYNAMIC];
				return YES;
			}
			break;
			
		case kSystem_economy:
			if (ooscript::valueToInt32(cx, *value, &iValue))
			{
				if (iValue < 0)  iValue = 0;
				if (7 < iValue)  iValue = 7;
				[UNIVERSE setSystemDataForGalaxy:galaxy planet:system key:KEY_ECONOMY value:[NSNumber numberWithInt:iValue] fromManifest:manifest forLayer:OO_LAYER_OXP_DYNAMIC];
				return YES;
			}
			break;
			
		case kSystem_techLevel:
			if (ooscript::valueToInt32(cx, *value, &iValue))
			{
				if (iValue < 0)  iValue = 0;
				if (15 < iValue)  iValue = 15;
				[UNIVERSE setSystemDataForGalaxy:galaxy planet:system key:KEY_TECHLEVEL value:[NSNumber numberWithInt:iValue] fromManifest:manifest forLayer:OO_LAYER_OXP_DYNAMIC];
				return YES;
			}
			break;
			
		case kSystem_population:
			if (ooscript::valueToInt32(cx, *value, &iValue))
			{
				[UNIVERSE setSystemDataForGalaxy:galaxy planet:system key:KEY_POPULATION value:[NSNumber numberWithInt:iValue] fromManifest:manifest forLayer:OO_LAYER_OXP_DYNAMIC];
				return YES;
			}
			break;
			
		case kSystem_productivity:
			if (ooscript::valueToInt32(cx, *value, &iValue))
			{
				[UNIVERSE setSystemDataForGalaxy:galaxy planet:system key:KEY_PRODUCTIVITY value:[NSNumber numberWithInt:iValue] fromManifest:manifest forLayer:OO_LAYER_OXP_DYNAMIC];
				return YES;
			}
			break;
			
		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sSystemPropertiesRaw);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, (propID), sSystemPropertiesRaw, *value_raw);
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// *** Methods ***

// toString() : String
namespace {
static bool SystemToString(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	NSString			*systemDesc = nil;
	
	systemDesc = [NSString stringWithFormat:@"[System %u:%u \"%@\"]", [player currentGalaxyID], [player currentSystemID], [[UNIVERSE currentSystemData] objectForKey:KEY_NAME]];
	OOJS_RETURN_OBJECT(systemDesc);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// addPlanet(key : String) : Planet
namespace {
static bool SystemAddPlanet(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	NSString			*key = nil;
	OOPlanetEntity		*planet = nil;
	
	if (oojsArgs.count() > 0)  key = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(key == nil))
	{
		OOJSReportBadArguments(context, @"System", @"addPlanet", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string (planet key)");
		return NO;
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	planet = [player addPlanet:key];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_OBJECT(planet);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// addMoon(key : String) : Planet
namespace {
static bool SystemAddMoon(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	NSString			*key = nil;
	OOPlanetEntity		*planet = nil;
	
	if (oojsArgs.count() > 0)  key = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(key == nil))
	{
		OOJSReportBadArguments(context, @"System", @"addMoon", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string (planet key)");
		return NO;
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	planet = [player addMoon:key];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_OBJECT(planet);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// sendAllShipsAway()
namespace {
static bool SystemSendAllShipsAway(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity *player = OOPlayerForScripting();
	
	[player sendAllShipsAway];
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// countShipsWithPrimaryRole(role : String [, relativeTo : Entity [, range : Number]]) : Number
namespace {
static bool SystemCountShipsWithPrimaryRole(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	NSString			*role = nil;
	Entity				*relativeTo = nil;
	double				range = -1;
	unsigned			result;
	
	if (oojsArgs.count() > 0)  role = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(role == nil))
	{
		OOJSReportBadArguments(context, @"System", @"countShipsWithPrimaryRole", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string (role)");
		return NO;
	}
	
	// Get optional arguments
	unsigned argc = oojsArgs.count() - 1;
	ooscript::Value *argv = OOJS_ARGV + 1;
	if (EXPECT_NOT(!GetRelativeToAndRange(context, @"countShipsWithPrimaryRole", &argc, &argv, &relativeTo, &range)))  return NO;
	
	OOJS_BEGIN_FULL_NATIVE(context)
	result = [UNIVERSE countShipsWithPrimaryRole:role inRange:range ofEntity:relativeTo];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_INT(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// countShipsWithRole(role : String [, relativeTo : Entity [, range : Number]]) : Number
namespace {
static bool SystemCountShipsWithRole(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	NSString			*role = nil;
	Entity				*relativeTo = nil;
	double				range = -1;
	unsigned			result;
	
	if (oojsArgs.count() > 0)  role = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(role == nil))
	{
		OOJSReportBadArguments(context, @"System", @"countShipsWithRole", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string (role)");
		return NO;
	}
	
	// Get optional arguments
	unsigned argc = oojsArgs.count() - 1;
	ooscript::Value *argv = OOJS_ARGV + 1;
	if (EXPECT_NOT(!GetRelativeToAndRange(context, @"countShipsWithRole", &argc, &argv, &relativeTo, &range)))  return NO;
	
	OOJS_BEGIN_FULL_NATIVE(context)
	result = [UNIVERSE countShipsWithRole:role inRange:range ofEntity:relativeTo];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_INT(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// shipsWithPrimaryRole(role : String [, relativeTo : Entity [, range : Number]]) : Array (Entity)
namespace {
static bool SystemShipsWithPrimaryRole(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	NSString			*role = nil;
	Entity				*relativeTo = nil;
	double				range = -1;
	NSArray				*result = nil;
	
	if (oojsArgs.count() > 0)  role = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(role == nil))
	{
		OOJSReportBadArguments(context, @"System", @"countShipsWithRole", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string (role)");
		return NO;
	}
	
	// Get optional arguments
	unsigned argc = oojsArgs.count() - 1;
	ooscript::Value *argv = OOJS_ARGV + 1;
	if (EXPECT_NOT(!GetRelativeToAndRange(context, @"shipsWithPrimaryRole", &argc, &argv, &relativeTo, &range)))  return NO;
	
	// Search for entities
	OOJS_BEGIN_FULL_NATIVE(context)
	result = FindShips(HasPrimaryRolePredicate, role, relativeTo, range);
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_OBJECT(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// shipsWithRole(role : String [, relativeTo : Entity [, range : Number]]) : Array (Entity)
namespace {
static bool SystemShipsWithRole(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	NSString			*role = nil;
	Entity				*relativeTo = nil;
	double				range = -1;
	NSArray				*result = nil;
	
	if (oojsArgs.count() > 0)  role = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(role == nil))
	{
		OOJSReportBadArguments(context, @"System", @"shipsWithRole", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string (role)");
		return NO;
	}
	
	// Get optional arguments
	unsigned argc = oojsArgs.count() - 1;
	ooscript::Value *subargv = OOJS_ARGV + 1;
	if (EXPECT_NOT(!GetRelativeToAndRange(context, @"shipsWithRole", &argc, &subargv, &relativeTo, &range)))  return NO;
	
	// Search for entities
	OOJS_BEGIN_FULL_NATIVE(context)
	result = FindShips(HasRolePredicate, role, relativeTo, range);
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_OBJECT(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// countEntitiesWithScanClass(scanClass : String [, relativeTo : Entity [, range : Number]]) : Number
namespace {
static bool SystemCountEntitiesWithScanClass(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	OOScanClass			scanClass = CLASS_NOT_SET;
	Entity				*relativeTo = nil;
	double				range = -1;
	unsigned			result;
	
	if (oojsArgs.count() > 0)  scanClass = OOScanClassFromJSValue(context, OOJS_ARGV[0]);
	if (scanClass == CLASS_NOT_SET)
	{
		OOJSReportBadArguments(context, @"System", @"countEntitiesWithScanClass", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string (scan class)");
		return NO;
	}
	
	// Get optional arguments
	unsigned argc = oojsArgs.count() - 1;
	ooscript::Value *argv = OOJS_ARGV + 1;
	if (EXPECT_NOT(!GetRelativeToAndRange(context, @"countEntitiesWithScanClass", &argc, &argv, &relativeTo, &range)))  return NO;
	
	OOJS_BEGIN_FULL_NATIVE(context)
	result = [UNIVERSE countShipsWithScanClass:scanClass inRange:range ofEntity:relativeTo];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_INT(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// entitiesWithScanClass(scanClass : String [, relativeTo : Entity [, range : Number]]) : Array (Entity)
namespace {
static bool SystemEntitiesWithScanClass(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	OOScanClass			scanClass = CLASS_NOT_SET;
	Entity				*relativeTo = nil;
	double				range = -1;
	NSArray				*result = nil;
	
	if (oojsArgs.count() > 0)  scanClass = OOScanClassFromJSValue(context, OOJS_ARGV[0]);
	if (scanClass == CLASS_NOT_SET)
	{
		OOJSReportBadArguments(context, @"System", @"countEntitiesWithScanClass", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string (scan class)");
		return NO;
	}
	
	// Get optional arguments
	unsigned argc = oojsArgs.count() - 1;
	ooscript::Value *argv = OOJS_ARGV + 1;
	if (EXPECT_NOT(!GetRelativeToAndRange(context, @"entitiesWithScanClass", &argc, &argv, &relativeTo, &range)))  return NO;
	
	// Search for entities
	OOJS_BEGIN_FULL_NATIVE(context)
	result = FindJSVisibleEntities(HasScanClassPredicate, [NSNumber numberWithInt:scanClass], relativeTo, range);
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_OBJECT(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// filteredEntities(this : Object, predicate : Function [, relativeTo : Entity [, range : Number]]) : Array (Entity)
namespace {
static bool SystemFilteredEntities(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	ooscript::Object jsThis = NULL;
	ooscript::Value				predicate;
	Entity				*relativeTo = nil;
	double				range = -1;
	NSArray				*result = nil;
	
	// Get this and predicate arguments
	if (oojsArgs.count() < 2 || !OOJSValueIsFunction(context, OOJS_ARGV[1]) || !ooscript::valueToObject(context, (OOJS_ARGV[0]), OOJSFOBJP(&jsThis)))
	{
		OOJSReportBadArguments(context, @"System", @"filteredEntities", oojsArgs.count(), OOJS_ARGV, nil, @"this, predicate function, and optional reference entity and range");
		return NO;
	}
	predicate = OOJS_ARGV[1];
	
	// Get optional arguments
	unsigned argc = oojsArgs.count() - 2;
	ooscript::Value *argv = OOJS_ARGV + 2;
	if (EXPECT_NOT(!GetRelativeToAndRange(context, @"filteredEntities", &argc, &argv, &relativeTo, &range)))  return NO;
	
	// Search for entities
	JSFunctionPredicateParameter param = { context, predicate, jsThis, NO };
	OOJSPauseTimeLimiter();
	result = FindJSVisibleEntities(JSFunctionPredicate, &param, relativeTo, range);
	OOJSResumeTimeLimiter();
	
	if (EXPECT_NOT(param.errorFlag))  return NO;
	
	OOJS_RETURN_OBJECT(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// locationFromCode(populator_named_region : String)
namespace {
static bool SystemLocationFromCode(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	NSString			*code = nil;
	if (oojsArgs.count() > 0)  
	{
		code = OOStringFromJSValue(context, OOJS_ARGV[0]);
	}
	if (EXPECT_NOT(code == nil))
	{
		OOJSReportBadArguments(context, @"System", @"locationFromCode", oojsArgs.count(), OOJS_ARGV, nil, @"location code");
		return NO;
	}
	OOSunEntity *sun = [UNIVERSE sun];
	OOPlanetEntity *planet = [UNIVERSE planet];
	HPVector position = kZeroHPVector;
	if (sun == nil || planet == nil)
	{
		position = [UNIVERSE locationByCode:@"WITCHPOINT" withSun:nil andPlanet:nil];
	}
	else
	{
		position = [UNIVERSE locationByCode:code withSun:sun andPlanet:planet];
	}

	OOJS_RETURN_HPVECTOR(position);

	OOJS_NATIVE_EXIT
}
} // namespace


// addShips(role : String, count : Number [, position: Vector [, radius: Number]]) : Array
namespace {
static bool SystemAddShips(ooscript::Context cx, ooscript::CallArgs &oojsArgs)
{
	return SystemAddShipsOrGroup(cx, oojsArgs, NO);
}
} // namespace


// addGroup(role : String, count : Number [, position: Vector [, radius: Number]]) : Array
namespace {
static bool SystemAddGroup(ooscript::Context cx, ooscript::CallArgs &oojsArgs)
{
	return SystemAddShipsOrGroup(cx, oojsArgs, YES);
}
} // namespace


// addShipsToRoute(role : String, count : Number [, position: Number [, route: String]])
namespace {
static bool SystemAddShipsToRoute(ooscript::Context cx, ooscript::CallArgs &oojsArgs)
{
	return SystemAddShipsOrGroupToRoute(cx, oojsArgs, NO);
}
} // namespace


// addGroupToRoute(role : String, count : Number,  position: Number[, route: String])
namespace {
static bool SystemAddGroupToRoute(ooscript::Context cx, ooscript::CallArgs &oojsArgs)
{
	return SystemAddShipsOrGroupToRoute(cx, oojsArgs, YES);
}
} // namespace


// legacy_addShips(role : String, count : Number)
namespace {
static bool SystemLegacyAddShips(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOStandardsDeprecated(@"system.legacy_addShips() is deprecated");


	OOJS_NATIVE_ENTER(context)
		
	NSString			*role = nil;
	int32_t				count;
	
	if (oojsArgs.count() > 0)  role = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(role == nil ||
				   !ooscript::valueToInt32(context, (OOJS_ARGV[1]), &count) ||
				   oojsArgs.count() < 2 ||
				   count < 1 || 64 < count))
	{
		OOJSReportBadArguments(context, @"System", @"legacy_addShips", oojsArgs.count(), OOJS_ARGV, nil, @"role and positive count no greater than 64");
		return NO;
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	while (count--)  [UNIVERSE witchspaceShipWithPrimaryRole:role];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// legacy_addSystemShips(role : String, count : Number, location : Number)
namespace {
static bool SystemLegacyAddSystemShips(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOStandardsDeprecated(@"system.legacy_addSystemShips() is deprecated");


	OOJS_NATIVE_ENTER(context)
	
	double			position;
	NSString			*role = nil;
	int32_t				count;
	
	if (oojsArgs.count() > 0)  role = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(role == nil ||
				   !ooscript::valueToInt32(context, (OOJS_ARGV[1]), &count) ||
				   count < 1 || 64 < count ||
				   oojsArgs.count() < 3 ||
				   !ooscript::valueToNumber(context, (OOJS_ARGV[2]), &position)))
	{
		OOJSReportBadArguments(context, @"System", @"legacy_addSystemShips", oojsArgs.count(), OOJS_ARGV, nil, @"role, positive count no greater than 64, and position along route");
		return NO;
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	while (count--)  [UNIVERSE addShipWithRole:role nearRouteOneAt:position];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// legacy_addShipsAt(role : String, count : Number, coordScheme : String, coords : vectorExpression)
namespace {
static bool SystemLegacyAddShipsAt(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOStandardsDeprecated(@"system.legacy_addShipsAt() is deprecated");


	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	HPVector				where;
	NSString			*role = nil;
	int32_t				count;
	NSString			*coordScheme = nil;
	NSString			*arg = nil;
	
	if (oojsArgs.count() > 0)  role = OOStringFromJSValue(context, OOJS_ARGV[0]);
	coordScheme = OOStringFromJSValue(context, OOJS_ARGV[2]);
	if (EXPECT_NOT(role == nil ||
				   !ooscript::valueToInt32(context, (OOJS_ARGV[1]), &count) ||
				   count < 1 || 64 < count ||
				   coordScheme == nil ||
				   oojsArgs.count() < 4 ||
				   !VectorFromArgumentListNoError(context, oojsArgs.count() - 3, OOJS_ARGV + 3, &where, NULL)))
	{
		OOJSReportBadArguments(context, @"System", @"legacy_addShipsAt", oojsArgs.count(), OOJS_ARGV, nil, @"role, positive count no greater than 64, coordinate scheme and coordinates");
		return NO;
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	arg = [NSString stringWithFormat:@"%@ %d %@ %f %f %f", role, count, coordScheme, where.x, where.y, where.z];
	[player addShipsAt:arg];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// legacy_addShipsAtPrecisely(role : String, count : Number, coordScheme : String, coords : vectorExpression)
namespace {
static bool SystemLegacyAddShipsAtPrecisely(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOStandardsDeprecated(@"system.legacy_addShipsAtPrecisely() is deprecated");


	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	HPVector				where;
	NSString			*role = nil;
	int32_t				count;
	NSString			*coordScheme = nil;
	NSString			*arg = nil;
	
	if (oojsArgs.count() > 0)  role = OOStringFromJSValue(context, OOJS_ARGV[0]);
	coordScheme = OOStringFromJSValue(context, OOJS_ARGV[2]);
	if (EXPECT_NOT(role == nil ||
				   !ooscript::valueToInt32(context, (OOJS_ARGV[1]), &count) ||
				   count < 1 || 64 < count ||
				   coordScheme == nil ||
				   oojsArgs.count() < 4 ||
				   !VectorFromArgumentListNoError(context, oojsArgs.count() - 3, OOJS_ARGV + 3, &where, NULL)))
	{
		OOJSReportBadArguments(context, @"System", @"legacy_addShipsAtPrecisely", oojsArgs.count(), OOJS_ARGV, nil, @"role, positive count no greater than 64, coordinate scheme and coordinates");
		return NO;
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	arg = [NSString stringWithFormat:@"%@ %d %@ %f %f %f", role, count, coordScheme, where.x, where.y, where.z];
	[player addShipsAtPrecisely:arg];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// legacy_addShipsWithinRadius(role : String, count : Number, coordScheme : String, coords : vectorExpression, radius : Number)
namespace {
static bool SystemLegacyAddShipsWithinRadius(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOStandardsDeprecated(@"system.legacy_addShipsWithinRadius() is deprecated");


	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	HPVector				where;
	double			radius;
	NSString			*role = nil;
	int32_t				count;
	NSString			*coordScheme = nil;
	NSString			*arg = nil;
	unsigned				consumed = 0;
	
	if (oojsArgs.count() > 0)  role = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (oojsArgs.count() > 2)  coordScheme = OOStringFromJSValue(context, OOJS_ARGV[2]);
	if (EXPECT_NOT(role == nil ||
				   !ooscript::valueToInt32(context, (OOJS_ARGV[1]), &count) ||
				   count < 1 || 64 < count ||
				   coordScheme == nil ||
				   oojsArgs.count() < 5 ||
				   !VectorFromArgumentListNoError(context, oojsArgs.count() - 3, OOJS_ARGV + 3, &where, &consumed) ||
				   !ooscript::valueToNumber(context, (OOJS_ARGV[3 + consumed]), &radius)))
	{
		OOJSReportBadArguments(context, @"System", @"legacy_addShipWithinRadius", oojsArgs.count(), OOJS_ARGV, nil, @"role, positive count no greater than 64, coordinate scheme, coordinates and radius");
		return NO;
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	arg = [NSString stringWithFormat:@"%@ %d %@ %f %f %f %f", role, count, coordScheme, where.x, where.y, where.z, radius];
	[player addShipsWithinRadius:arg];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// legacy_spawnShip(key : string)
namespace {
static bool SystemLegacySpawnShip(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOStandardsDeprecated(@"system.legacy_spawnShip() is deprecated");


	OOJS_NATIVE_ENTER(context)
	
	NSString			*key = nil;
	OOPlayerForScripting();	// For backwards-compatibility
	
	if (oojsArgs.count() > 0)  key = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (key == nil)
	{
		OOJSReportBadArguments(context, @"System", @"legacy_spawnShip", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string (ship key)");
		return NO;
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	[UNIVERSE spawnShip:key];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// *** Static methods ***

// systemNameForID(ID : Number) : String
namespace {
static bool SystemStaticSystemNameForID(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	int32_t				systemID;
	
	if (oojsArgs.count() < 1 || !ooscript::valueToInt32(context, (OOJS_ARGV[0]), &systemID) || systemID < -1 || kOOMaximumSystemID < systemID)	// -1 interstellar space!
	{
		OOJSReportBadArguments(context, @"System", @"systemNameForID", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"system ID");
		return NO;
	}
	
	if (systemID == -1)
		OOJS_RETURN_OBJECT(DESC(@"interstellar-space"));
	else
		OOJS_RETURN_OBJECT([UNIVERSE getSystemName:systemID]);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// systemIDForName(name : String) : Number
namespace {
static bool SystemStaticSystemIDForName(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	NSString			*name = nil;
	unsigned			result;
	
	if (oojsArgs.count() > 0)  name = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (name == nil)
	{
		OOJSReportBadArguments(context, @"System", @"systemIDForName", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string");
		return NO;
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)

	result = [UNIVERSE findSystemFromName:name];

	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_INT(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// infoForSystem(galaxyID : Number, systemID : Number) : SystemInfo
namespace {
static bool SystemStaticInfoForSystem(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	int32_t				galaxyID;
	int32_t				systemID;
	
	if (oojsArgs.count() < 2 || !ooscript::valueToInt32(context, (OOJS_ARGV[0]), &galaxyID) || !ooscript::valueToInt32(context, (OOJS_ARGV[1]), &systemID))
	{
		OOJSReportBadArguments(context, @"System", @"infoForSystem", oojsArgs.count(), OOJS_ARGV, nil, @"galaxy ID and system ID");
		return NO;
	}
	
	if (galaxyID < 0 || galaxyID > kOOMaximumGalaxyID)
	{
		OOJSReportBadArguments(context, @"System", @"infoForSystem", 1, OOJS_ARGV, @"Invalid galaxy ID", [NSString stringWithFormat:@"number in the range 0 to %u", kOOMaximumGalaxyID]);
		return NO;
	}
	
	if (systemID < kOOMinimumSystemID || systemID > kOOMaximumSystemID)
	{
		OOJSReportBadArguments(context, @"System", @"infoForSystem", 1, OOJS_ARGV + 1, @"Invalid system ID", [NSString stringWithFormat:@"number in the range %i to %i", kOOMinimumSystemID, kOOMaximumSystemID]);
		return NO;
	}
	
	OOJS_RETURN(GetJSSystemInfoForSystem(context, galaxyID, systemID));
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool SystemAddVisualEffect(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	NSString			*key = nil;
	HPVector         where;
	
	unsigned				consumed = 0;

	if (oojsArgs.count() > 0)  key = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (key == nil)
	{
		OOJSReportBadArguments(context, @"System", @"addVisualEffect", MIN(oojsArgs.count(), 1U), &OOJS_ARGV[0], nil, @"string (key)");
		return NO;
	}

	if (!VectorFromArgumentListNoError(context, oojsArgs.count() - 1, OOJS_ARGV + 1, &where, &consumed))
	{
		OOJSReportBadArguments(context, @"System", @"addVisualEffect", MIN(oojsArgs.count() - 1, 1U), &OOJS_ARGV[1], nil, @"vector");
		return NO;
	}

	OOVisualEffectEntity *result = nil;

	OOJS_BEGIN_FULL_NATIVE(context)

	result = [UNIVERSE addVisualEffectAt:where withKey:key];

	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_OBJECT(result);

	OOJS_NATIVE_EXIT
}
} // namespace

namespace {
static bool SystemSetPopulator(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)

	NSString *key;
	NSMutableDictionary *settings;
	ooscript::Object params = NULL;

	if (oojsArgs.count() < 1) 
	{
		OOJSReportBadArguments(context, @"System", @"setPopulator", MIN(oojsArgs.count(), 0U), &OOJS_ARGV[0], nil, @"string (key), object (settings)");
		return NO;
	}
	key = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (key == nil)
	{
		OOJSReportBadArguments(context, @"System", @"setPopulator", MIN(oojsArgs.count(), 0U), &OOJS_ARGV[0], nil, @"key, settings");
		return NO;
	}
	if (oojsArgs.count() < 2 || ooscript::isNull(OOJS_ARGV[1]))
	{
		// clearing
		[UNIVERSE setPopulatorSetting:key to:nil];
	}
	else
	{
		// adding
		if (!ooscript::valueToObject(context, (OOJS_ARGV[1]), OOJSFOBJP(&params)))
		{
			OOJSReportBadArguments(context, @"System", @"setPopulator", MIN(oojsArgs.count(), 1U), OOJS_ARGV, NULL, @"key, settings");
			return NO;
		}
		ooscript::Value				callback = ooscript::nullValue();
		if (!ooscript::getProperty(context, (params), "callback", (&callback)) || ooscript::isUndefined(callback))
		{
			OOJSReportBadArguments(context, @"System", @"setPopulator", MIN(oojsArgs.count(), 1U), OOJS_ARGV, NULL, @"settings must have a 'callback' property.");
			return NO;
		}

		OOJSPopulatorDefinition *populator = [[OOJSPopulatorDefinition alloc] init];
		[populator setCallback:callback];

		settings = OOJSNativeObjectFromJSObject(context, ooscript::toObject(OOJS_ARGV[1]));
		[settings setObject:populator forKey:@"callbackObj"];

		ooscript::Value				coords = ooscript::nullValue();
		if (ooscript::getProperty(context, (params), "coordinates", (&coords)) && !ooscript::isUndefined(coords))
		{
			Vector coordinates = kZeroVector;
			if (JSValueToVector(context, coords, &coordinates))
			{
				// convert vector in NS-storable form
				[settings setObject:[NSArray arrayWithObjects:[NSNumber numberWithFloat:coordinates.x],[NSNumber numberWithFloat:coordinates.y],[NSNumber numberWithFloat:coordinates.z],nil] forKey:@"coordinates"];
			}
		}

		[populator release];

		[UNIVERSE setPopulatorSetting:key to:settings];
	}	

	OOJS_RETURN_VOID;

	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool SystemSetWaypoint(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)

	NSString *key;
	NSMutableDictionary *settings;
	HPVector position;
	Quaternion orientation;

	if (oojsArgs.count() < 1) 
	{
		OOJSReportBadArguments(context, @"System", @"setWaypoint", MIN(oojsArgs.count(), 0U), &OOJS_ARGV[0], nil, @"key, position, orientation, definition");
		return NO;
	}
	key = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (key == nil)
	{
		OOJSReportBadArguments(context, @"System", @"setWaypoint", MIN(oojsArgs.count(), 0U), &OOJS_ARGV[0], nil, @"key, position, orientation, definition");
		return NO;
	}
	if (oojsArgs.count() < 4 || ooscript::isNull(OOJS_ARGV[3]))
	{
		// clearing
		[UNIVERSE defineWaypoint:nil forKey:key];
	}
	else
	{
		// adding
		if (!JSValueToHPVector(context, OOJS_ARGV[1], &position))
		{
			OOJSReportBadArguments(context, @"System", @"setWaypoint", MIN(oojsArgs.count(), 2U), OOJS_ARGV, NULL, @"key, position, orientation, definition");
			return NO;
		}
		if (!JSValueToQuaternion(context, OOJS_ARGV[2], &orientation))
		{
			OOJSReportBadArguments(context, @"System", @"setWaypoint", MIN(oojsArgs.count(), 3U), OOJS_ARGV, NULL, @"key, position, orientation, definition");
			return NO;
		}
		if (!ooscript::isObjectOrNull(OOJS_ARGV[3]) || ooscript::isNull(OOJS_ARGV[3]))
		{
			OOJSReportBadArguments(context, @"System", @"setWaypoint", MIN(oojsArgs.count(), 4U), OOJS_ARGV, NULL, @"key, position, orientation, definition");
			return NO;
		}
		
		settings = [[OOJSNativeObjectFromJSObject(context, ooscript::toObject(OOJS_ARGV[3])) mutableCopy] autorelease];
		[settings setObject:[NSArray arrayWithObjects:[NSNumber numberWithDouble:position.x],[NSNumber numberWithDouble:position.y],[NSNumber numberWithDouble:position.z],nil] forKey:@"position"];
		[settings setObject:[NSArray arrayWithObjects:[NSNumber numberWithDouble:orientation.w],[NSNumber numberWithDouble:orientation.x],[NSNumber numberWithDouble:orientation.y],[NSNumber numberWithDouble:orientation.z],nil] forKey:@"orientation"];

		[UNIVERSE defineWaypoint:settings forKey:key];
	}	

	OOJS_RETURN_VOID;

	OOJS_NATIVE_EXIT
}
} // namespace

// *** Helper functions ***

// Shared implementation of addShips() and addGroup().
namespace {
static bool SystemAddShipsOrGroup(Context cx, CallArgs &oojsArgs, BOOL isGroup)
{
	ooscript::Context context = (cx);
	unsigned argc = oojsArgs.count();

	OOJS_NATIVE_ENTER(context)
	
	NSString			*role = nil;
	int32_t				count = 0;
	unsigned				consumed = 0;
	HPVector				where;
	double				radius = NSNotFound;	// a negative value means 
	id					result = nil;
	
	NSString			*func = isGroup ? @"addGroup" : @"addShips";
	
	if (argc > 0)  role = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (role == nil)
	{
		OOJSReportBadArguments(context, @"System", func, MIN(argc, 1U), &OOJS_ARGV[0], nil, @"string (role)");
		return NO;
	}
	if (argc < 2 || !ooscript::valueToInt32(cx, (OOJS_ARGV[1]), &count) || count < 1 || 64 < count)
	{
		OOJSReportBadArguments(context, @"System", func, MIN(argc - 1, 1U), &OOJS_ARGV[1], nil, @"number (positive count no greater than 64)");
		return NO;
	}
	
	if (argc < 3)
	{
		where = [UNIVERSE getWitchspaceExitPosition];
		radius = SCANNER_MAX_RANGE;
	}
	else
	{
		if (!VectorFromArgumentListNoError(context, argc - 2, OOJS_ARGV + 2, &where, &consumed))
		{
			OOJSReportBadArguments(context, @"System", func, MIN(argc - 2, 1U), &OOJS_ARGV[2], nil, @"vector");
			return NO;
		}
		
		if (argc > 2 + consumed)
		{
			if (!ooscript::valueToNumber(cx, (OOJS_ARGV[2 + consumed]), &radius))
			{
				OOJSReportBadArguments(context, @"System", func, MIN(argc - 2 - consumed, 1U), &OOJS_ARGV[2 + consumed], nil, @"number (radius)");
				return NO;
			}
		}
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	// Note: the use of witchspace-in effects (as in legacy_addShips) depends on proximity to the witchpoint.
	result = [UNIVERSE addShipsAt:where withRole:role quantity:count withinRadius:radius asGroup:isGroup];
	
	if (isGroup)
	{
		NSArray *array = result;
		if ([array count] > 0)  result = [(ShipEntity *)[array objectAtIndex:0] group];
		else  result = nil;
	}
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_OBJECT(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool SystemAddShipsOrGroupToRoute(Context cx, CallArgs &oojsArgs, BOOL isGroup)
{
	ooscript::Context context = (cx);
	unsigned argc = oojsArgs.count();

	OOJS_NATIVE_ENTER(context)
	
	NSString			*role = nil;
	NSString			*route = @"st"; // default route witchpoint -> station. ("st" itself is not selectable by script)
	static NSSet		*validRoutes = nil;
	int32_t				count = 0;
	double				where = NSNotFound;		// a negative value means random positioning!
	id					result = nil;
	
	NSString			*func = isGroup ? @"addGroup" : @"addShips";
	
	if (argc > 0)  role = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (role == nil)
	{
		OOJSReportBadArguments(context, @"System", func, MIN(argc, 1U), &OOJS_ARGV[0], nil, @"string (role)");
		return NO;
	}
	if (argc < 2 || !ooscript::valueToInt32(cx, (OOJS_ARGV[1]), &count) || count < 1 || 64 < count)
	{
		OOJSReportBadArguments(context, @"System", func, MIN(argc - 1, 1U), &OOJS_ARGV[1], nil, @"number (positive count no greater than 64)");
		return NO;
	}
	
	if (argc > 2)
	{
		if (!ooscript::valueToNumber(cx, (OOJS_ARGV[2]), &where) || !isfinite(where) || where < 0.0f || where > 1.0f)
		{
			OOJSReportBadArguments(context, @"System", func, MIN(argc - 2, 1U), &OOJS_ARGV[2], nil, @"number (position along route)");
			return NO;
		}
		
		if (argc > 3)
		{
			route = [OOStringFromJSValue(context, OOJS_ARGV[3]) lowercaseString];
			
			if (validRoutes == nil)
			{
				validRoutes = [[NSSet alloc] initWithObjects:@"wp", @"pw", @"ws", @"sw", @"sp", @"ps", nil];
			}
			
			if (route == nil || ![validRoutes containsObject:route])
			{
				OOJSReportBadArguments(context, @"System", func, MIN(argc - 3, 1U), &OOJS_ARGV[3], nil, @"string (route specifier)");
				return NO;
			}
		}
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	// Note: the use of witchspace-in effects (as in legacy_addShips) depends on proximity to the witchpoint.	
	result = [UNIVERSE addShipsToRoute:route withRole:role quantity:count routeFraction:where asGroup:isGroup];
	
	if (isGroup)
	{
		NSArray *array = result;
		if ([array count] > 0)  result = [(ShipEntity *)[array objectAtIndex:0] group];
		else  result = nil;
	}
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_OBJECT(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static BOOL GetRelativeToAndRange(ooscript::Context context, NSString *methodName, unsigned *ioArgc, ooscript::Value **ioArgv, Entity **outRelativeTo, double *outRange)
{
	OOJS_PROFILE_ENTER
	
	// No NULL arguments accepted.
	assert(ioArgc && ioArgv && outRelativeTo && outRange);
	
	// Get optional argument relativeTo : Entity
	if (*ioArgc != 0)
	{
		if (EXPECT_NOT(ooscript::isNull(**ioArgv) || !JSValueToEntity(context, **ioArgv, outRelativeTo)))
		{
			OOJSReportBadArguments(context, @"System", methodName, 1, *ioArgv, nil, @"entity");
			return NO;
		}
		(*ioArgv)++; (*ioArgc)--;
	}
	
	// Get optional argument range : Number
	if (*ioArgc != 0)
	{
		if (!EXPECT_NOT(ooscript::valueToNumber((context), (**ioArgv), outRange)))
		{
			OOJSReportBadArguments(context, @"System", methodName, 1, *ioArgv, nil, @"number");
			return NO;
		}
		(*ioArgv)++; (*ioArgc)--;
	}
	
	return YES;
	
	OOJS_PROFILE_EXIT
}
} // namespace


namespace {
static NSArray *FindJSVisibleEntities(EntityFilterPredicate predicate, void *parameter, Entity *relativeTo, double range)
{
	OOJS_PROFILE_ENTER
	
	NSMutableArray						*result = nil;
	BinaryOperationPredicateParameter	param =
	{
		JSEntityIsJavaScriptSearchablePredicate, NULL,
		predicate, parameter
	};
	
	result = [UNIVERSE findEntitiesMatchingPredicate:ANDPredicate
										   parameter:&param
											 inRange:range
											ofEntity:relativeTo];
	
	if (result != nil && relativeTo != nil && ![relativeTo isPlayer])
	{
		[result sortUsingFunction:CompareEntitiesByDistance context:relativeTo];
	}
	if (result == nil)  return [NSArray array];
	return result;
	
	OOJS_PROFILE_EXIT
}
} // namespace


namespace {
static NSArray *FindShips(EntityFilterPredicate predicate, void *parameter, Entity *relativeTo, double range)
{
	OOJS_PROFILE_ENTER
	
	BinaryOperationPredicateParameter	param =
	{
		IsShipPredicate, NULL,
		predicate, parameter
	};
	return FindJSVisibleEntities(ANDPredicate, &param, relativeTo, range);
	
	OOJS_PROFILE_EXIT
}
} // namespace


namespace {
static NSComparisonResult CompareEntitiesByDistance(id a, id b, void *relativeTo)
{
	OOJS_PROFILE_ENTER
	
	Entity				*ea = a,
	*eb = b,
	*r = (id)relativeTo;
	float				d1, d2;
	
	d1 = HPdistance2(ea->position, r->position);
	d2 = HPdistance2(eb->position, r->position);
	
	if (d1 < d2)  return NSOrderedAscending;
	else if (d1 > d2)  return NSOrderedDescending;
	else return NSOrderedSame;
	
	OOJS_PROFILE_EXIT_VAL(NSOrderedSame)
}
} // namespace
