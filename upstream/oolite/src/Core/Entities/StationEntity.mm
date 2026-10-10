/*

	StationEntity.m

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

#import "StationEntity.h"
#import "DockEntity.h"
#import "OOJSStation.h"
#import "EntityOOJavaScriptExtensions.h"
#import "ShipEntityAI.h"
#import "OOStringParsing.h"

#import "Universe.h"
#import "GameController.h"
#import "HeadUpDisplay.h"
#import "OOConstToString.h"

#import "PlayerEntityLegacyScriptEngine.h"
#import "OOLegacyScriptWhitelist.h"
#import "OOPlanetEntity.h"
#import "OOShipGroup.h"
#import "OOQuiriumCascadeEntity.h"

#import "AI.h"
#import "OOCharacter.h"

#import "OOJSScript.h"
#import "OODebugGLDrawing.h"
#import "OODebugFlags.h"
#import "OODebugStandards.h"
#import "OOWeakSet.h"
#import "OOPListGameTypes.h"
#import "OOObjCPList.h"
#include "oofnd/Log.hpp"
#include "oofnd/String.hpp"


// -oo_stringForKey:'s value without the Foundation type (proposed ADR-0043): a string as is, a
// number's -stringValue, anything else (or nothing) nullopt, as it gave nil.
namespace
{

std::optional<std::string> OptionalStringValue(const oo::PList *value)
{
	if (value == nullptr)  return std::nullopt;
	if (const std::string *string = value->getIf<std::string>())  return *string;
	if (value->isNumber())  return oo::plist_get::numberStringValue(*value);
	return std::nullopt;
}

}	// namespace


oo::PList cxx_OOMakeDockingInstructions(StationEntity *station, HPVector coords, float speed, float range, const std::optional<std::string> &ai_message, const std::optional<std::string> &comms_message, BOOL match_rotation, int docking_stage)
{
	oo::PList::Dict acc;
	// destination as OOPropertyListFromHPVector built it (doubles); speed and range as -oo_setFloat:
	// stored them (+numberWithDouble:); docking_stage as -oo_setInteger: (signed)
	acc["destination"] = oo::PList(oo::PList::Dict{ { "x", oo::PList(coords.x) }, { "y", oo::PList(coords.y) }, { "z", oo::PList(coords.z) } });
	acc["speed"] = oo::PList(static_cast<double>(speed));
	acc["range"] = oo::PList(static_cast<double>(range));
	acc["station"] = oo::PListObject([[oo::ToObjC(station) weakRetain] autorelease]);
	acc["match_rotation"] = oo::PList(static_cast<bool>(match_rotation));
	acc["docking_stage"] = oo::PList::signedInteger(docking_stage);
	if (ai_message)
	{
		acc["ai_message"] = oo::PList(*ai_message);
	}
	if (comms_message)
	{
		acc["comms_message"] = oo::PList(*comms_message);
	}
	return oo::PList(std::move(acc));
}


// Slice 4 of docs/phases/3-slices/StationEntity.md (bead oo-tqem7): NPC launchers. Several are sent
// by name (ADR-0055 item 5), which the ship's facade answers for a station's part (bead oo-9ht.175).


// Exposed to AI
oo::PList StationEntity::launchIndependentShip(const std::string &role)	// called by name (ADR-0055 item 5): the ship launched, as an Object node (null: none)
{
	::ShipEntity *self = oo::ToObjC(this);
	if (!hasLaunchDock())
	{
		OO_LOG("station.launchShip.impossible", "Cancelled launch for a ship with role {}, as the {} has no launch docks.",
			  role, getDisplayName().value_or("(null)"));
		return oo::PList();
	}

	std::string		shipRole = role;
	BOOL			trader = shipRole == "trader";
	BOOL			sunskimmer = (shipRole == "sunskim-trader");
	::ShipEntity		*ship = nil;

	if((trader && (randf() < 0.1)) || sunskimmer)
	{
		ship = [UNIVERSE cxx_newShipWithRole:"sunskim-trader"];
		sunskimmer = true;
		trader = true;
		shipRole = "trader"; // make sure also sunskimmers get trader role.
	}
	else
	{
		ship = [UNIVERSE cxx_newShipWithRole:shipRole];
	}

	if (!fitsInDock(ship))
	{
		[ship release];
		return oo::PList();
	}
	
	if (ship)
	{
		if (![ship cxx_crew].has_value())
		{
			[ship cxx_setSingleCrewWithRole:shipRole];
		}
		[ship setPrimaryRole:shipRole];

		if(trader || ship->_cxxEntity->scanClass == CLASS_NOT_SET)  [ship setScanClass: CLASS_NEUTRAL]; // keep defined scanclasses for non-traders.
		
		if (trader)
		{
			[ship setBounty:0 withReason:kOOLegalStatusReasonSetup];
			[ship setCargoFlag:CARGO_FLAG_FULL_PLENTIFUL];
			if (sunskimmer) 
			{
				[ship setFuel:(Ranrot()&31)];
				[UNIVERSE makeSunSkimmer:ship andSetAI:YES];
			}
			else
			{
// JSAI: not needed - oolite-traderAI.js handles exiting if full fuel and plentiful cargo
//				[ship switchAITo:@"exitingTraderAI.plist"];
				if([ship fuel] == 0) [ship setFuel:70];
//				if ([ship hasRole:"sunskim-trader"]) [UNIVERSE makeSunSkimmer:ship andSetAI:NO];
			}
		}
		
		addShipToLaunchQueue(ship, NO);

		::OOShipGroup *escortGroup = [ship escortGroup];
		if ([ship group] == nil) [ship setGroup:escortGroup];
		// Eric: Escorts are defined both as _group and as _escortGroup because friendly attacks are only handled within _group.
		if (escortGroup != nullptr)  escortGroup->setLeader(ship);
				
		// add escorts to the trader
		unsigned escorts = [ship pendingEscortCount];
		if(escorts > 0)
		{
			[ship setOwner:self]; // makes escorts get added to station launch queue
			[ship setUpEscorts];
			[ship setOwner:ship];
		}
		
		[ship setPendingEscortCount:0];
		[ship autorelease];
	}
	return oo::PListObject(ship);
}


// Exposed to AI
oo::PList StationEntity::launchPolice()	// called by name (ADR-0055 item 5)
{
	std::vector<oo::ObjCRef<::ShipEntity *>>	result;
	if (!hasLaunchDock())
	{
		OO_LOG("station.launchShip.impossible", "Cancelled launch for a police ship, as the {} has no launch docks.",
			  getDisplayName().value_or("(null)"));
		return oo::PListFromObjects(result);
	}

	OOUniversalID	police_target = [primaryTarget() universalID];
	unsigned		i;
	OOTechLevelID	techlevel = getEquivalentTechLevel();
	if (techlevel == NSNotFound)  techlevel = 6;

	result.reserve(4);

	for (i = 0; (i < 4)&&(defenders_launched < max_police) ; i++)
	{
		::ShipEntity  *police_ship = nil;
		if (![UNIVERSE entityForUniversalID:police_target])
		{
			noteLostTarget();
			return oo::PListFromObjects(std::vector<oo::ObjCRef<::ShipEntity *>>());
		}
		/* this is more likely to give interceptors than the
		 * equivalent populator function: save them for defense
		 * ships */
		if ((Ranrot() & 3) + 9 < techlevel)
		{
			police_ship = [UNIVERSE cxx_newShipWithRole:"interceptor"];   // retain count = 1
		}
		else
		{
			police_ship = [UNIVERSE cxx_newShipWithRole:"police"];   // retain count = 1
		}
		
		if (police_ship && fitsInDock(police_ship))
		{
			if (![police_ship cxx_crew].has_value())
			{
				[police_ship cxx_setSingleCrewWithRole:"police"];
			}
			
			[police_ship setGroup:stationGroup()];	// who's your Daddy
			[police_ship setPrimaryRole:"police"];
			[police_ship addTarget:[UNIVERSE entityForUniversalID:police_target]];
			if ([police_ship scanClass] == CLASS_NOT_SET)
				[police_ship setScanClass: CLASS_POLICE];
			[police_ship setBounty:0 withReason:kOOLegalStatusReasonSetup];
			if ([police_ship heatInsulation] < heatInsulation())
				[police_ship setHeatInsulation:heatInsulation()];
			[police_ship switchAITo:"oolite-defenseShipAI.js"];
			addShipToLaunchQueue(police_ship, YES);
			defenders_launched++;
			result.push_back(oo::ObjCRef<::ShipEntity *>(police_ship));
		}
		[police_ship autorelease];
	}
	abortAllDockings();
	return oo::PListFromObjects(result);
}


// Exposed to AI
::ShipEntity *StationEntity::launchDefenseShip()
{
	::ShipEntity *self = oo::ToObjC(this);
	if (!hasLaunchDock())
	{
		OO_LOG("station.launchShip.impossible", "Cancelled launch for a defense ship, as the {} has no launch docks.",
			  getDisplayName().value_or("(null)"));
		return nil;
	}

	OOUniversalID	defense_target = [primaryTarget() universalID];
	::ShipEntity	*defense_ship = nil;
	std::string	default_defense_ship_role;
	const std::string	defense_ship_ai = "oolite-defenseShipAI.js";
	
	OOTechLevelID	techlevel;
	
	techlevel = getEquivalentTechLevel();
	if (techlevel == NSNotFound)  techlevel = 6;
	if ((Ranrot() & 7) + 6 <= techlevel)
		default_defense_ship_role	= "interceptor";
	else
		default_defense_ship_role	= "police";

	if (scanClass == CLASS_ROCK)
		default_defense_ship_role	= "hermit-ship";
	
	if (defenders_launched >= max_defense_ships)   // shuttles are to rockhermits what police ships are to stations
		return nil;
	
	if (![UNIVERSE entityForUniversalID:defense_target])
	{
		noteLostTarget();
		return nil;
	}
	
	const std::optional<std::string> defense_ship_key = OptionalStringValue(shipinfoDictionary.find("defense_ship"));	// -oo_stringForKey:
	if (defense_ship_key)
	{
		defense_ship = [UNIVERSE cxx_newShipWithName:*defense_ship_key];
	}
	// The retry below was a pointer comparison of the role with the default role string: it ran
	// exactly when shipdata supplied defense_ship_role (-oo_stringForKey:defaultValue: returned the
	// default object itself otherwise).
	bool shipdataSuppliedRole = false;
	if (!defense_ship)
	{
		const std::optional<std::string> defense_ship_role = OptionalStringValue(shipinfoDictionary.find("defense_ship_role"));
		shipdataSuppliedRole = defense_ship_role.has_value();
		defense_ship = [UNIVERSE cxx_newShipWithRole:defense_ship_role.value_or(default_defense_ship_role)];
	}

	if (!defense_ship && shipdataSuppliedRole)
		defense_ship = [UNIVERSE cxx_newShipWithRole:default_defense_ship_role];

	if (!defense_ship || !fitsInDock(defense_ship))
	{
		[defense_ship release];
		return nil;
	}
	
	if ([defense_ship isPolice] || [defense_ship cxx_hasPrimaryRole:"hermit-ship"])
	{
		[defense_ship switchAITo:defense_ship_ai];
	}
	
	[defense_ship setPrimaryRole:"defense_ship"];
	
	defenders_launched++;
	
	if (![defense_ship cxx_crew].has_value())
	{
		if ([defense_ship isPolice])
		{
			[defense_ship cxx_setSingleCrewWithRole:"police"];
		}
		else
		{
			[defense_ship cxx_setSingleCrewWithRole:"hunter"];
		}
	}
				
	[defense_ship setOwner: self];
	if (group() == nil)
	{
		setGroup(stationGroup());	
	}
	[defense_ship setGroup:stationGroup()];	// who's your Daddy
	
	[defense_ship addTarget:[UNIVERSE entityForUniversalID:defense_target]];

	if ((scanClass != CLASS_ROCK)&&(scanClass != CLASS_STATION))
	{
		[defense_ship setScanClass: scanClass];	// same as self
	}
	else if ([defense_ship scanClass] == CLASS_NOT_SET)
	{
		[defense_ship setScanClass: CLASS_NEUTRAL];
	}

	if ([defense_ship heatInsulation] < heatInsulation())
	{
		[defense_ship setHeatInsulation:heatInsulation()];
	}

	addShipToLaunchQueue(defense_ship, YES);
	[defense_ship autorelease];
	abortAllDockings();
	
	return defense_ship;
}


// Exposed to AI
::ShipEntity *StationEntity::launchScavenger()
{
	::ShipEntity *self = oo::ToObjC(this);
	if (!hasLaunchDock())
	{
		OO_LOG("station.launchShip.impossible", "Cancelled launch for a scavenger ship, as the {} has no launch docks.",
			  getDisplayName().value_or("(null)"));
		return nil;
	}

	::ShipEntity  *scavenger_ship;
	
	unsigned scavs = [UNIVERSE cxx_countShipsWithPrimaryRole:"scavenger" inRange:SCANNER_MAX_RANGE ofEntity:self] + countOfShipsInLaunchQueueWithPrimaryRole("scavenger");
	
	if (scavs >= max_scavengers)  return nil;
	if (scavengers_launched >= max_scavengers)  return nil;
			
	scavenger_ship = [UNIVERSE cxx_newShipWithRole:"scavenger"];   // retain count = 1
	
	if (!fitsInDock(scavenger_ship))
	{
		[scavenger_ship release];
		return nil;
	}
	
	if (scavenger_ship)
	{
		if (![scavenger_ship cxx_crew].has_value())
		{
			[scavenger_ship cxx_setSingleCrewWithRole:"miner"];
		}
				
		scavengers_launched++;
		[scavenger_ship setScanClass: CLASS_NEUTRAL];
		if ([scavenger_ship heatInsulation] < heatInsulation())
			[scavenger_ship setHeatInsulation:heatInsulation()];
		[scavenger_ship setGroup:stationGroup()];	// who's your Daddy -- FIXME: should we have a separate group for non-escort auxiliaires?
		[scavenger_ship switchAITo:"oolite-scavengerAI.js"];
		addShipToLaunchQueue(scavenger_ship, NO);
		[scavenger_ship autorelease];
	}
	return scavenger_ship;
}


// Exposed to AI
::ShipEntity *StationEntity::launchMiner()
{
	::ShipEntity *self = oo::ToObjC(this);
	if (!hasLaunchDock())
	{
		OO_LOG("station.launchShip.impossible", "Cancelled launch for a miner ship, as the {} has no launch docks.",
			  getDisplayName().value_or("(null)"));
		return nil;
	}

	::ShipEntity  *miner_ship;
	
	int		n_miners = [UNIVERSE cxx_countShipsWithPrimaryRole:"miner" inRange:SCANNER_MAX_RANGE ofEntity:self] + countOfShipsInLaunchQueueWithPrimaryRole("miner");
	
	if (n_miners >= 1)	// just the one
		return nil;
	
	// count miners as scavengers...
	if (scavengers_launched >= max_scavengers)  return nil;
	
	miner_ship = [UNIVERSE cxx_newShipWithRole:"miner"];   // retain count = 1

	if (!fitsInDock(miner_ship))
	{
		[miner_ship release];
		return nil;
	}
	
	if (miner_ship)
	{
		if (![miner_ship cxx_crew].has_value())
		{
			[miner_ship cxx_setSingleCrewWithRole:"miner"];
		}
				
		scavengers_launched++;
		[miner_ship setScanClass:CLASS_NEUTRAL];
		if ([miner_ship heatInsulation] < heatInsulation())
			[miner_ship setHeatInsulation:heatInsulation()];
		[miner_ship setGroup:stationGroup()];	// who's your Daddy -- FIXME: should we have a separate group for non-escort auxiliaires?
		[miner_ship switchAITo:"oolite-scavengerAI.js"];
		addShipToLaunchQueue(miner_ship, NO);
		[miner_ship autorelease];
	}
	return miner_ship;
}

/**Lazygun** added the following method. A complete rip-off of launchDefenseShip. 
 */
// Exposed to AI
::ShipEntity *StationEntity::launchPirateShip()
{
	::ShipEntity *self = oo::ToObjC(this);
	if (!hasLaunchDock())
	{
		OO_LOG("station.launchShip.impossible", "Cancelled launch for a pirate ship, as the {} has no launch docks.",
			  getDisplayName().value_or("(null)"));
		return nil;
	}
	//Pirate ships are launched from the same pool as defence ships.
	OOUniversalID	defense_target = [primaryTarget() universalID];
	::ShipEntity		*pirate_ship = nil;
	
	if (defenders_launched >= max_defense_ships)  return nil;   // shuttles are to rockhermits what police ships are to stations
	
	if (![UNIVERSE entityForUniversalID:defense_target])
	{
		noteLostTarget();
		return nil;
	}
	
	// Yep! The standard hermit defence ships, even if they're the aggressor.
	pirate_ship = [UNIVERSE cxx_newShipWithRole:"pirate"];   // retain count = 1
	// Nope, use standard pirates in a generic method.
	
	if (!fitsInDock(pirate_ship))
	{
		[pirate_ship release];
		return nil;
	}
		
	if (pirate_ship)
	{
		if (![pirate_ship cxx_crew].has_value())
		{
			[pirate_ship cxx_setSingleCrewWithRole:"pirate"];
		}
				
		defenders_launched++;
		
		// set the owner of the ship to the station so that it can check back for docking later
		[pirate_ship setOwner:self];
		[pirate_ship setGroup:stationGroup()];	// who's your Daddy
		[pirate_ship setPrimaryRole:"defense_ship"];
		[pirate_ship addTarget:[UNIVERSE entityForUniversalID:defense_target]];
		[pirate_ship setScanClass: CLASS_NEUTRAL];
		if ([pirate_ship heatInsulation] < heatInsulation())
			[pirate_ship setHeatInsulation:heatInsulation()];
		//**Lazygun** added 30 Nov 04 to put a bounty on those pirates' heads.
		[pirate_ship setBounty: 10 + floor(randf() * 20) withReason:kOOLegalStatusReasonSetup];	// modified for variety

		addShipToLaunchQueue(pirate_ship, NO);
		[pirate_ship autorelease];
		abortAllDockings();
	}
	return pirate_ship;
}


// Exposed to AI
::ShipEntity *StationEntity::launchShuttle()
{
	if (!hasLaunchDock())
	{
		OO_LOG("station.launchShip.impossible", "Cancelled launch for a shuttle ship, as the {} has no launch docks.",
			  getDisplayName().value_or("(null)"));
		return nil;
	}
	::ShipEntity  *shuttle_ship;
		
	shuttle_ship = [UNIVERSE cxx_newShipWithRole:"shuttle"];   // retain count = 1
	
	if (!fitsInDock(shuttle_ship))
	{
		[shuttle_ship release];
		return nil;
	}
	
	if (shuttle_ship)
	{
		if (![shuttle_ship cxx_crew].has_value())
		{
			[shuttle_ship cxx_setSingleCrewWithRole:"trader"];
		}
		
		docked_shuttles--;
		[shuttle_ship setScanClass: CLASS_NEUTRAL];
		[shuttle_ship setCargoFlag:CARGO_FLAG_FULL_SCARCE];
		[shuttle_ship switchAITo:"oolite-shuttleAI.js"];
		addShipToLaunchQueue(shuttle_ship, NO);
		
		[shuttle_ship autorelease];
	}
	return shuttle_ship;
}


// Exposed to AI
::ShipEntity *StationEntity::launchEscort()
{
	if (!hasLaunchDock())
	{
		OO_LOG("station.launchShip.impossible", "Cancelled launch for an escort ship, as the {} has no launch docks.",
			  getDisplayName().value_or("(null)"));
		return nil;
	}
	::ShipEntity  *escort_ship;
		
	escort_ship = [UNIVERSE cxx_newShipWithRole:"escort"];   // retain count = 1
	
	if (escort_ship && fitsInDock(escort_ship))
	{
		if (![escort_ship cxx_crew].has_value())
		{
			[escort_ship cxx_setSingleCrewWithRole:"hunter"];
		}
				
		[escort_ship setScanClass: CLASS_NEUTRAL];
		[escort_ship setCargoFlag: CARGO_FLAG_FULL_PLENTIFUL];
		[escort_ship switchAITo:"oolite-escortAI.js"];
		addShipToLaunchQueue(escort_ship, NO);
		
	}
	[escort_ship release];
	return escort_ship;
}


// Exposed to AI
::ShipEntity *StationEntity::launchPatrol()
{
	if (!hasLaunchDock())
	{
		OO_LOG("station.launchShip.impossible", "Cancelled launch for a patrol ship, as the {} has no launch docks.",
			  getDisplayName().value_or("(null)"));
		return nil;
	}
	if (defenders_launched < max_police)
	{
		::ShipEntity		*patrol_ship = nil;
		OOTechLevelID	techlevel;
		
		techlevel = getEquivalentTechLevel();
		if (techlevel == NSNotFound)
			techlevel = 6;
			
		if ((Ranrot() & 7) + 6 <= techlevel)
			patrol_ship = [UNIVERSE cxx_newShipWithRole:"interceptor"];   // retain count = 1
		else
			patrol_ship = [UNIVERSE cxx_newShipWithRole:"police"];   // retain count = 1

		if (!fitsInDock(patrol_ship))
		{
			[patrol_ship release];
			return nil;
		}
		
		if (patrol_ship)
		{
			if (![patrol_ship cxx_crew].has_value())
			{
				[patrol_ship cxx_setSingleCrewWithRole:"police"];
			}
			
			defenders_launched++;
			[patrol_ship switchLightsOff];
			if ([patrol_ship scanClass] == CLASS_NOT_SET)
				[patrol_ship setScanClass: CLASS_POLICE];
			if ([patrol_ship heatInsulation] < heatInsulation())
				[patrol_ship setHeatInsulation:heatInsulation()];
			[patrol_ship setPrimaryRole:"police-station-patrol"];
			[patrol_ship setBounty:0 withReason:kOOLegalStatusReasonSetup];
			[patrol_ship setGroup:stationGroup()];	// who's your Daddy
			[patrol_ship switchAITo:"oolite-policeAI.js"];
			addShipToLaunchQueue(patrol_ship, NO);
			acceptPatrolReportFrom(patrol_ship);
			[patrol_ship autorelease];
			return patrol_ship;
		}
	}
	return nil;
}


// Exposed to AI
void StationEntity::launchShipWithRole(const std::string &role)	// called by name (ADR-0055 item 5)
{
	if (!hasLaunchDock())
	{
		OO_LOG("station.launchShip.impossible", "Cancelled launch for a ship with role {}, as the {} has no launch docks.",
			  role, getDisplayName().value_or("(null)"));
		return;
	}
	const std::string &shipRole = role;
	::ShipEntity  *ship = [UNIVERSE cxx_newShipWithRole:shipRole];   // retain count = 1
	if (ship && fitsInDock(ship))
	{
		if (![ship cxx_crew].has_value())
		{
			[ship cxx_setSingleCrewWithRole:shipRole];
		}
		if (ship->_cxxEntity->scanClass == CLASS_NOT_SET) [ship setScanClass: CLASS_NEUTRAL];
		[ship setPrimaryRole:shipRole];
		[ship setGroup:stationGroup()];	// who's your Daddy
		addShipToLaunchQueue(ship, NO);
	}
	[ship release];
}



// Slice 1 of docs/phases/3-slices/StationEntity.md (bead oo-64ako): class shell, market and
// shipyard, flags and accessors. The facade's initialiser and -dealloc are members since bead
// oo-9ht.175 deleted the facade (ADR-0056 amendment oo-9ht.175).


::ShipEntity *StationEntity::newStationObject(const std::string &key, const oo::PList &dict)
{
	::ShipEntity *object = oo::NewShipObject(oo::makeRef<StationEntity>(), key, dict);	// [super cxx_initWithKey:key definition:dict]
	if (object != nil)  static_cast<StationEntity *>(oo::ToCxx(object))->initStationDefaults();
	return object;
}


void StationEntity::initStationDefaults()
{
	OOJS_PROFILE_ENTER

	isStation = YES;
	_shipsOnHold = ::OOWeakSet::set();
	hasBreakPattern = YES;

	OOJS_PROFILE_EXIT_VOID
}


void StationEntity::willDealloc()
{
	_shipsOnHold = nullptr;
	localMarket = nullptr;
//	DESTROY(localPassengers);
//	DESTROY(localContracts);
}


/* Override ShipEntity: stations of CLASS_ROCK or CLASS_CARGO are not automatically unpiloted. */
bool StationEntity::isUnpiloted()
{
	return isExplicitlyUnpiloted() || getIsHulk();
}


void StationEntity::getJSClass(ooscript::ClassDef **outClass, ooscript::Object *outPrototype)
{
	::OOJSStationGetJSClass(outClass, outPrototype);
}


bool StationEntity::isVisibleToScripts()
{
	return ::ShipEntityJSIsVisibleToScripts();
}


std::optional<std::string> StationEntity::jsClassName()
{
	return ::OOJSStationJSClassName();
}


OOTechLevelID StationEntity::getEquivalentTechLevel()
{
	if (equivalentTechLevel == NSNotFound)
	{
		return [UNIVERSE cxx_currentSystemData].get<int>(std::string(KEY_TECHLEVEL));
	}
	else
	{
		return equivalentTechLevel;
	}
}


void StationEntity::setEquivalentTechLevel(OOTechLevelID value)
{
	equivalentTechLevel = value;
}


Vector StationEntity::virtualPortDimensions()
{
	return port_dimensions;
}


::DockEntity *StationEntity::playerReservedDock()
{
	return player_reserved_dock;
}


HPVector StationEntity::beaconPosition()
{
	double buoy_distance = 10000.0;				// distance from station entrance
	Vector v_f = vector_forward_from_quaternion(getOrientation());
	HPVector result = HPvector_add(getPosition(), vectorToHPVector(vector_multiply_scalar(v_f, buoy_distance)));
	
	return result;
}


float StationEntity::getEquipmentPriceFactor()
{
	return equipmentPriceFactor;
}


OOCargoQuantity StationEntity::getMarketCapacity()
{
	return marketCapacity;
}


oo::PList StationEntity::getMarketDefinition()
{
	return marketDefinition;
}


std::optional<std::string> StationEntity::getMarketScriptName()
{
	return marketScriptName;
}


bool StationEntity::getMarketMonitored()
{
	if (this == [UNIVERSE station])
	{
		return YES;
	}
	return marketMonitored;
}


bool StationEntity::getMarketBroadcast()
{
	if (this == [UNIVERSE station])
	{
		return YES;
	}
	return marketBroadcast;
}


OOCreditsQuantity StationEntity::legalStatusOfManifest(::OOCommodityMarket *manifest, bool isExport)
{
	OOCreditsQuantity penalty, status = 0;
	::OOCommodityMarket *market = getLocalMarket();
	for (const std::string &good : market->goods())
	{
		if (isExport)
		{
			penalty = market->exportLegalityForGood(good);
		}
		else
		{
			penalty = market->importLegalityForGood(good);
		}
		status += penalty * manifest->quantityForGood(good);
	}
	return status;
}


::OOCommodityMarket *StationEntity::getLocalMarket()
{
	if (this == [UNIVERSE station])
	{
		// main stations use the system market
		// just return a reference
		return [UNIVERSE commodityMarket];
	}
	if (!localMarket)
	{
		initialiseLocalMarket();
	}
	return localMarket.get();
}


void StationEntity::setLocalMarket(const oo::PList &some_market)
{
	OOCommodityMarket *market = getLocalMarket();	// null: nothing set, as a message to nil
	if (market != nullptr)  market->loadStationAmounts(some_market);
}


oo::PList StationEntity::localMarketForScripting()
{
	OOCommodityMarket *market = getLocalMarket();	// null: null, as a message to nil
	return (market != nullptr) ? market->dictionaryForScripting() : oo::PList();
}


void StationEntity::setPrice(OOCreditsQuantity price, const std::string &commodity)
{
	OOCommodityMarket *market = getLocalMarket();	// null: nothing set, as a message to nil
	if (market != nullptr)  market->setPrice(price, commodity);
}


void StationEntity::setQuantity(OOCargoQuantity quantity, const std::string &commodity)
{
	OOCommodityMarket *market = getLocalMarket();	// null: nothing set, as a message to nil
	if (market != nullptr)  market->setQuantity(quantity, commodity);
}


std::vector<oo::PList> *StationEntity::getLocalShipyard()
{
	return localShipyard ? &*localShipyard : nullptr;
}


void StationEntity::setLocalShipyard(const std::vector<oo::PList> &some_market)
{
	localShipyard = some_market;
}


std::map<std::string, oo::Ref<::OOJSInterfaceDefinition>, std::less<>> *StationEntity::getLocalInterfaces()
{
	return &localInterfaces;
}


void StationEntity::setInterfaceDefinition(::OOJSInterfaceDefinition *definition, const std::string &key)
{
	if (definition == nullptr)
	{
		localInterfaces.erase(key);
	}
	else
	{
		localInterfaces[key] = oo::Ref<::OOJSInterfaceDefinition>(definition);
	}
}


::OOCommodityMarket *StationEntity::initialiseLocalMarket()
{
	localMarket = ([UNIVERSE commodities] != nullptr ? [UNIVERSE commodities]->generateMarketForStation(this) : oo::Ref<OOCommodityMarket>());
	return localMarket.get();
}


void StationEntity::setPlanet(::OOPlanetEntity *planet_entity)
{
	if (planet_entity)
		planet = (planet_entity != nullptr ? planet_entity->getUniversalID() : OOUniversalID{});
	else
		planet = NO_TARGET;
}


::OOPlanetEntity *StationEntity::getPlanet()
{
	// The planet is C++ since bead oo-9ht.129: null for any other entity (and for none, as nil).
	return dynamic_cast<::OOPlanetEntity *>(oo::ToCxx((::Entity *)[UNIVERSE entityForUniversalID:planet]));
}


unsigned StationEntity::countOfDockedContractors()
{
	return max_scavengers > scavengers_launched ? max_scavengers - scavengers_launched : 0;
}


unsigned StationEntity::countOfDockedPolice()
{
	return max_police > defenders_launched ? max_police - defenders_launched : 0;
}


unsigned StationEntity::countOfDockedDefenders()
{
	return max_defense_ships > defenders_launched ? max_defense_ships - defenders_launched : 0;
}


std::vector<oo::ObjCRef<::DockEntity *>> StationEntity::dockSubEntities()
{
	std::vector<oo::ObjCRef<::DockEntity *>> result;
	for (const auto &subRef : getSubEntities())
	{
		::Entity *sub = subRef.get();
		if (![sub isDock])  continue;
		result.push_back(oo::ObjCRef<::DockEntity *>((::DockEntity *)sub));
	}
	return result;
}


bool StationEntity::setUpShipFromDictionary(const oo::PList &dict)
{
	OOJS_PROFILE_ENTER
	
		isShip = YES;
	isStation = YES;
	alertLevel = STATION_ALERT_LEVEL_GREEN;
	
	port_radius = dict.get<oo::NonNegative<double>>("port_radius", 500.0);
	
	// port_dimensions is deprecated
	port_dimensions = make_vector(69, 69, 250);
	const std::optional<std::string> portDimensionsStr = OptionalStringValue(dict.find("port_dimensions"));	// -oo_stringForKey:
	if (portDimensionsStr)
	{
		cxx_OOStandardsDeprecated("The port_dimensions key is deprecated");
		if (!OOEnforceStandards())
		{
			const std::vector<std::string> tokens = oo::str::split(*portDimensionsStr, "x");
			if (tokens.size() == 3)
			{
				// -floatValue
				port_dimensions = make_vector((float)oo::str::doubleValue(tokens[0]),
											  (float)oo::str::doubleValue(tokens[1]),
											  (float)oo::str::doubleValue(tokens[2]));
			}
		}
	}
	
	if (!ShipEntity::setUpShipFromDictionary(dict))  return NO;
	
	equivalentTechLevel = dict.get<NSUInteger>("equivalent_tech_level", NSNotFound);
	max_scavengers = dict.get<unsigned int>("max_scavengers", 3);
	max_defense_ships = dict.get<unsigned int>("max_defense_ships", 3);
	max_police = dict.get<unsigned int>("max_police", STATION_MAX_POLICE);
	equipmentPriceFactor = dict.get<oo::NonNegative<float>>("equipment_price_factor", 1.0);
	equipmentPriceFactor = fmax(equipmentPriceFactor, 0.5f);
	hasNPCTraffic = (unsigned char)OOFuzzyBooleanFromPList(dict.find("has_npc_traffic"), (maxFlightSpeed == 0)); // carriers default to NO
	hasPatrolShips = OOFuzzyBooleanFromPList(dict.find("has_patrol_ships"), NO);
	suppress_arrival_reports = (unsigned char)dict.get<bool>("suppress_arrival_reports", NO);
	setAllegiance(OptionalStringValue(dict.find("allegiance")));

	marketCapacity = dict.get<unsigned int>("market_capacity", MAIN_SYSTEM_MARKET_LIMIT);
	const oo::PList *marketDefinitionValue = dict.get<oo::PList::Array>("market_definition");
	marketDefinition = (marketDefinitionValue != nullptr) ? *marketDefinitionValue : oo::PList();	// oo_arrayForKey:
	marketScriptName = OptionalStringValue(dict.find("market_script"));
	marketMonitored = (unsigned char)dict.get<bool>("market_monitored", NO);
	marketBroadcast = (unsigned char)dict.get<bool>("market_broadcast", YES);

	// Non main stations may have requiresDockingClearance set to yes as a result of the code below,
	// but this variable should be irrelevant for them, as they do not make use of it anyway.
	requiresDockingClearance = (unsigned char)dict.get<bool>("requires_docking_clearance", [UNIVERSE dockingClearanceProtocolActive]);
	
	allowsFastDocking = (unsigned char)dict.get<bool>("allows_fast_docking", NO);
	
	allowsAutoDocking = (unsigned char)dict.get<bool>("allows_auto_docking", YES);
	
	allowsSaving = [UNIVERSE deterministicPopulation];

	interstellarUndockingAllowed = (unsigned char)dict.get<bool>("interstellar_undocking", NO);
	
	double unitime = [UNIVERSE getTime];

	if (getHasNPCTraffic())  // removed the 'isRotatingStation' restriction.
	{
		docked_shuttles = ranrot_rand() & 3;   // 0..3;
		shuttle_launch_interval = 15.0 * 60.0;  // every 15 minutes
		last_shuttle_launch_time = unitime - (ranrot_rand() & 63) * shuttle_launch_interval / 60.0;
			
		docked_traders = 3 + (ranrot_rand() & 7);   // 1..3;
		trader_launch_interval = 3600.0 / docked_traders;  // every few minutes
		last_trader_launch_time = unitime + 60.0 - trader_launch_interval; // in one minute's time
	}
	else
	{
		docked_shuttles = 0;
		docked_traders = 0;   // 1..3;
	}
	
	patrol_launch_interval = 300.0;	// 5 minutes
	last_patrol_report_time = unitime - patrol_launch_interval;
	
	if (!getCrew().has_value())
	{
		setSingleCrewWithRole("police");
	}
	
	if (group() == nil)
	{
		setGroup(stationGroup());
	}
	return YES;
	
	OOJS_PROFILE_EXIT
}


// used to set up a virtual dock if necessary
bool StationEntity::setUpSubEntities()
{
	::ShipEntity *self = oo::ToObjC(this);
	if (!ShipEntity::setUpSubEntities())
	{
		return NO;
	}


#ifndef NDEBUG
	for (const auto &subRef : getSubEntities())
	{
		::Entity *sub = subRef.get();
		if (![sub isShip])  continue;
		::ShipEntity *subEntity = (::ShipEntity *)sub;
		if ([subEntity isStation])
		{
			OO_LOG("setup.ship.badType.subentities", "Subentity {} ({}) of station {} is itself a StationEntity. This is an internal error - please report it. ", oo::DescriptionOf(subEntity), [subEntity cxx_shipDataKey].value_or("(null)"), getDisplayName().value_or("(null)"));
		}
	}
#endif

	// and now check for docks
	if (!dockSubEntities().empty())
	{
		return YES;
	}

	cxx_OOStandardsDeprecated(oo::str::format("No docks set up for %s", oo::DescriptionOf(self).c_str()));
	OO_LOG("ship.setup.docks", "No docks set up for {}, making virtual dock", oo::DescriptionOf(self));

	// no real docks, make a virtual one
	// position and orientation as OOPropertyListFromVector / OOPropertyListFromQuaternion built them (floats)
	Vector dockPosition = make_vector(0,0,port_radius);
	oo::PList::Dict virtualDockDict;
	virtualDockDict["type"] = oo::PList("standard");
	virtualDockDict["subentity_key"] = oo::PList("oolite-dock-virtual");
	virtualDockDict["position"] = oo::PList(oo::PList::Dict{ { "x", oo::PList::singleReal(dockPosition.x) }, { "y", oo::PList::singleReal(dockPosition.y) }, { "z", oo::PList::singleReal(dockPosition.z) } });
	virtualDockDict["orientation"] = oo::PList(oo::PList::Dict{ { "w", oo::PList::singleReal(kIdentityQuaternion.w) }, { "x", oo::PList::singleReal(kIdentityQuaternion.x) }, { "y", oo::PList::singleReal(kIdentityQuaternion.y) }, { "z", oo::PList::singleReal(kIdentityQuaternion.z) } });
	virtualDockDict["is_dock"] = oo::PList(true);
	virtualDockDict["dock_label"] = oo::PList("the docking bay");
	virtualDockDict["allow_docking"] = oo::PList(true);
	virtualDockDict["disallowed_docking_collides"] = oo::PList(false);
	virtualDockDict["allow_launching"] = oo::PList(true);
	virtualDockDict["_is_virtual_dock"] = oo::PList(true);

	if (!setUpOneStandardSubentity(oo::PList(std::move(virtualDockDict)), NO))
	{
		return NO;
	}
	return YES;
}


bool StationEntity::getInterstellarUndockingAllowed()
{
	return interstellarUndockingAllowed;
}


bool StationEntity::getHasNPCTraffic()
{
	return hasNPCTraffic;
}


void StationEntity::setHasNPCTraffic(bool flag)
{
	hasNPCTraffic = flag != NO;
}


bool StationEntity::getRequiresDockingClearance()
{
	return requiresDockingClearance;
}


void StationEntity::setRequiresDockingClearance(bool newValue)
{
	requiresDockingClearance = !!newValue;	// Ensure yes or no
}


bool StationEntity::getAllowsFastDocking()
{
	return allowsFastDocking;
}


void StationEntity::setAllowsFastDocking(bool newValue)
{
	allowsFastDocking = !!newValue;	// Ensure yes or no
}


bool StationEntity::getAllowsAutoDocking()
{
	return allowsAutoDocking;
}


void StationEntity::setAllowsAutoDocking(bool newValue)
{
	allowsAutoDocking = !!newValue; // Ensure yes or no
}


bool StationEntity::getAllowsSaving()
{
	// fixed stations only, not carriers!
	return allowsSaving && (getMaxFlightSpeed() == 0);
}


bool StationEntity::isRotatingStation()
{
	if (shipinfoDictionary.get<bool>("rotating", false))  return YES;
	// legacy. -rangeOfString: of the roles string; absent, a message to nil gave a zeroed range, which is not NSNotFound.
	const oo::PList *roles = shipinfoDictionary.find("roles");
	if (roles == nullptr)  return YES;
	const std::string *rolesString = roles->getIf<std::string>();
	return rolesString != nullptr && rolesString->find("rotating-station") != std::string::npos;
}


std::optional<std::string> StationEntity::marketOverrideName()
{
	// 2010.06.14 - Micha - we can't default to the primary role as otherwise the logic
	//				generating the market in [Universe commodityDataForEconomy:] doesn't
	//				work properly with the various overrides.  The primary role will get
	//				used if either there is no market override, or the market wasn't
	//				defined.
	return OptionalStringValue(shipinfoDictionary.find("market"));
}


bool StationEntity::hasShipyard()
{
	if ([UNIVERSE station] == this)
		return YES;
	const oo::PList	*determinantValue = shipinfoDictionary.find("has_shipyard");

	if (determinantValue == nullptr)
		determinantValue = shipinfoDictionary.find("hasShipyard");
	
	// NOTE: non-standard capitalization is documented and entrenched.
	if (determinantValue != nullptr && !determinantValue->isNull())
	{
		if (determinantValue->isArray())
		{
			return (PLAYER != nullptr ? PLAYER->scriptTestConditions(OOSanitizeLegacyScriptConditions(*determinantValue, std::nullopt)) : false);
		}
		else
		{
			return OOFuzzyBooleanFromPList(determinantValue, 0.0f);
		}
	}
	else
	{
		return NO;
	}
}


void StationEntity::generateShipyard()
{
	generateShipyard(getEquivalentTechLevel());
}


void StationEntity::generateShipyard(OOTechLevelID stationTechLevel)
{
	unsigned		i;

	if (getLocalShipyard() == nullptr)
	{
		const oo::PList forSale = [UNIVERSE cxx_shipsForSaleForSystem:[UNIVERSE currentSystemID] withTL:stationTechLevel atTime:(PLAYER != nullptr ? PLAYER->clockTime() : 0.0)];
		const oo::PList::Array *entries = forSale.getIf<oo::PList::Array>();
		setLocalShipyard(entries != nullptr ? *entries : oo::PList::Array());	// nil gave an empty shipyard
	}

	std::vector<oo::PList> *shipyard = getLocalShipyard();
	const oo::PList::Dict *shipyardRecord = (PLAYER != nullptr ? PLAYER->shipyardRecord() : (oo::PList::Dict *)nullptr);
		
	// remove ships that the player has already bought
	for (i = 0; i < shipyard->size(); i++)
	{
		const std::optional<std::string> shipID = OptionalStringValue((*shipyard)[i].find("id"));	// SHIPYARD_KEY_ID
		if (shipID && shipyardRecord != nullptr && shipyardRecord->contains(*shipID))
		{
			shipyard->erase(shipyard->begin() + i--);
		}
	}
}


bool StationEntity::suppressArrivalReports()
{
	return suppress_arrival_reports;
}


void StationEntity::setSuppressArrivalReports(bool newValue)
{
	suppress_arrival_reports = !!newValue;	// ensure YES or NO
}


bool StationEntity::getHasBreakPattern()
{
	return hasBreakPattern;
}


void StationEntity::setHasBreakPattern(bool newValue)
{
	hasBreakPattern = !!newValue;
}


std::optional<std::string> StationEntity::descriptionComponents() const
{
	return oo::str::format("\"%s\" %s", name.value_or("(null)").c_str(), ShipEntity::descriptionComponents().value_or("(null)").c_str());
}


void StationEntity::dumpSelfState()
{
	std::vector<std::string>	flags;
	std::string					flagsString;
	std::string					alertString = "*** ERROR: UNKNOWN ALERT LEVEL ***";
	
	ShipEntity::dumpSelfState();
	
	switch (alertLevel)
	{
		case STATION_ALERT_LEVEL_GREEN:
			alertString = "green";
			break;
		
		case STATION_ALERT_LEVEL_YELLOW:
			alertString = "yellow";
			break;
		
		case STATION_ALERT_LEVEL_RED:
			alertString = "red";
			break;
	}
	
	OO_LOG("dumpState.stationEntity", "Alert level: {}", alertString);
	OO_LOG("dumpState.stationEntity", "Max police: {}", static_cast<unsigned>(max_police));
	OO_LOG("dumpState.stationEntity", "Max defense ships: {}", static_cast<unsigned>(max_defense_ships));
	OO_LOG("dumpState.stationEntity", "Defenders launched: {}", static_cast<unsigned>(defenders_launched));
	OO_LOG("dumpState.stationEntity", "Max scavengers: {}", static_cast<unsigned>(max_scavengers));
	OO_LOG("dumpState.stationEntity", "Scavengers launched: {}", static_cast<unsigned>(scavengers_launched));
	OO_LOG("dumpState.stationEntity", "Docked shuttles: {}", static_cast<unsigned>(docked_shuttles));
	OO_LOG("dumpState.stationEntity", "Docked traders: {}", static_cast<unsigned>(docked_traders));
	OO_LOG("dumpState.stationEntity", "Equivalent tech level: {}", equivalentTechLevel);
	OO_LOG("dumpState.stationEntity", "Equipment price factor: {:g}", equipmentPriceFactor);
	
	#define ADD_FLAG_IF_SET(x)		if (x) { flags.push_back(#x); }
	ADD_FLAG_IF_SET(no_docking_while_launching);
	if (isRotatingStation()) { flags.push_back("rotatingStation"); }
	if (!dockingCorridorIsEmpty()) { flags.push_back("dockingCorridorIsBusy"); }
	for (const std::string &flag : flags)
	{
		if (!flagsString.empty())  flagsString += ", ";	// -componentsJoinedByString:
		flagsString += flag;
	}
	if (flags.empty())  flagsString = "none";
	OO_LOG("dumpState.stationEntity", "Flags: {}", flagsString);
	
	// approach and hold lists.
	
	// Ships on hold list, only used with moving stations (= carriers)
	if(_shipsOnHold->count() > 0)
	{
		OO_LOG("dumpState.stationEntity", "{} Ships on hold (unsorted):", _shipsOnHold->count());
		
		oo::log::indent();
		unsigned		i = 1;
		for (const oo::ObjCRef<id> &shipRef : _shipsOnHold->objectEnumerator())
		{
			::ShipEntity *ship = static_cast<::ShipEntity *>(shipRef.get());
			OO_LOG("dumpState.stationEntity", "Nr {}: {} at distance {:g} with role: {}", i++, [ship displayName].value_or("(null)"), HPdistance(getPosition(), [ship position]), [ship cxx_primaryRole].value_or("(null)"));
		}
		oo::log::outdent();
	}
}



// Slice 2 of docs/phases/3-slices/StationEntity.md (bead oo-9j462): docking traffic control and the
// launch queue.


void StationEntity::sanityCheckShipsOnApproach()
{

	unsigned soa = 0;
	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		soa += [sub pruneAndCountShipsOnApproach];
	}

	if (soa == 0)
	{
		// if all docks have no ships on approach
		[shipAI message:"DOCKING_COMPLETE"];
		doScriptEvent(OOJSID("stationDockingQueuesAreEmpty"));	
	}
}


// only used by player - everything else ends up in a Dock's launch queue
void StationEntity::launchShip(::ShipEntity *ship)
{
	
	// try to find an unused dock first
	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		if ([sub allowsLaunching] && [sub countOfShipsInLaunchQueue] == 0) 
		{
			[sub launchShip:ship];
			return;
		}
	}
	// otherwise any launchable dock will do
	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		if ([sub allowsLaunching]) 
		{
			[sub launchShip:ship];
			return;
		}
	}

	// ship has no launch docks specified; just use the last one
	// (the enumerator loop this replaced left its variable nil when it ran out, so this never fires)
	::DockEntity *sub = nil;
	if (sub != nil)
	{
		[sub launchShip:ship];
		return;
	}
	// guaranteed to always be a dock as virtual dock will suffice
}


// Exposed to AI
void StationEntity::abortAllDockings()
{
	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		[sub abortAllDockings];
	}
	
	// -makeObjectsPerformSelector:withObject: of the live ships on hold, in order
	for (const oo::ObjCRef<id> &holdRef : _shipsOnHold->objectEnumerator())  [static_cast<::ShipEntity *>(holdRef.get()) sendAIMessage:"DOCKING_ABORTED"];
	for (const oo::ObjCRef<id> &holdRef : _shipsOnHold->objectEnumerator())
	{
		::ShipEntity *hold = static_cast<::ShipEntity *>(holdRef.get());
		[hold doScriptEvent:OOJSID("stationWithdrewDockingClearance")];
	}

	::PlayerEntity *player = PLAYER;

	if ((player != nullptr ? player->getTargetDockStation() : (::StationEntity *)nullptr) == this && (player != nullptr ? player->getDockingClearanceStatus() : OODockingClearanceStatus{}) >= DOCKING_CLEARANCE_STATUS_REQUESTED)
	{
		// then docking clearance is requested but hasn't been cancelled
		// yet by a DockEntity
		sendExpandedMessage("[station-docking-clearance-abort-cancelled]", oo::ToObjC(player));
		if (player != nullptr)  player->setDockingClearanceStatus(DOCKING_CLEARANCE_STATUS_NONE);
		if (player != nullptr)  player->doScriptEvent(OOJSID("stationWithdrewDockingClearance"));
	}

	_shipsOnHold->removeAllObjects();
	
	[shipAI message:"DOCKING_COMPLETE"];
	doScriptEvent(OOJSID("stationDockingQueuesAreEmpty"));

}


void StationEntity::autoDockShipsOnHold()
{
	for (const oo::ObjCRef<id> &shipRef : _shipsOnHold->objectEnumerator())
	{
		::ShipEntity *ship = static_cast<::ShipEntity *>(shipRef.get());
		pullInShipIfPermitted(ship);
	}
	
	_shipsOnHold->removeAllObjects();
}


void StationEntity::autoDockShipsOnApproach()
{
	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		[sub autoDockShipsOnApproach];
	}

	autoDockShipsOnHold();
	
	[shipAI message:"DOCKING_COMPLETE"];
	doScriptEvent(OOJSID("stationDockingQueuesAreEmpty"));

}


Vector StationEntity::portUpVectorForShip(::ShipEntity *ship)
{
	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		if ([sub shipIsInDockingQueue:ship])
		{
			return [sub portUpVectorForShipsBoundingBox:[ship totalBoundingBox]];
		}
	}
	return kZeroVector;
}


// this method does initial traffic control, before passing the ship
// to an appropriate dock for docking coordinates and instructions.
// used for NPCs, and the player when they use the docking computer
oo::PList StationEntity::dockingInstructionsForShip(::ShipEntity *ship)
{
	if (ship == nil)  return oo::PList();

	doScriptEvent(OOJSID("stationReceivedDockingRequest"), ship);

	if ([ship isPlayer])
	{
		player_reserved_dock = nil; // clear any dock reservation for manual docking
	}

	if ([ship isPlayer] && [ship legalStatus] > 50)	// note: non-player fugitives dock as normal
	{
		// refuse docking to the fugitive player
		return cxx_OOMakeDockingInstructions(this, [ship position], 0, 100, "DOCKING_REFUSED", "[station-docking-refused-to-fugitive]", NO, -1);
	}
	
	if	(magnitude2(velocity) > 1.0 ||
			 fabs(flightPitch) > 0.01 ||
			 fabs(flightYaw) > 0.01)
	{
		// no docking while station is moving, pitching or yawing
		return holdPositionInstructionForShip(ship);
	}
	::PlayerEntity *player = PLAYER;
	BOOL player_is_ahead = (![ship isPlayer] && (player != nullptr ? player->getDockingClearanceStatus() : OODockingClearanceStatus{}) == DOCKING_CLEARANCE_STATUS_REQUESTED && (this == (player != nullptr ? player->getTargetDockStation() : (::StationEntity *)nullptr)));

	::DockEntity		*chosenDock = nil;
	std::optional<std::string>	docking;	// nullopt: no dock asked yet (was nil)
	NSUInteger		queue = 100;
	
	BOOL alldockstoosmall = YES;
	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		if ([sub shipIsInDockingQueue:ship]) 
		{
			// if already claimed a docking queue, use that one
			chosenDock = sub;
			alldockstoosmall = NO;
			break;
		}
		if (player_is_ahead) {
			// can't allocate a new queue while player is manually docking
			continue;
		}
		if (sub != player_reserved_dock || [ship isPlayer])
		{
			docking = [sub canAcceptShipForDocking:ship];
			if (docking == "DOCK_CLOSED")
			{
				ooscript::Context context = OOJSAcquireContext();
				ooscript::Value		rval = ooscript::undefinedValue();
				ooscript::Value		args[] = { OOJSValueFromNativeObject(context, sub),
													 OOJSValueFromNativeObject(context, ship) };
				bool tempreject = NO;

				BOOL OK = (getScript() != nullptr ? getScript()->callMethod(OOJSID("willOpenDockingPortFor"), context, args, 2, &rval) : false);
				if (OK)  OK = ooscript::valueToBoolean(context, rval, &tempreject);
				if (!OK)  tempreject = NO; // default to permreject
				if (tempreject)
				{
					docking = "TRY_AGAIN_LATER";
				}
				else
				{
					docking = "TOO_BIG_TO_DOCK";
				}

				OOJSRelinquishContext(context);
			}

			if (docking == "DOCKING_POSSIBLE" && [sub countOfShipsInDockingQueue] < queue) {
				// try to select the dock with the fewest ships already enqueued
				chosenDock = sub;
				queue = [sub countOfShipsInDockingQueue];
				alldockstoosmall = NO;
			}
			else if (!(docking == "TOO_BIG_TO_DOCK"))
			{
				alldockstoosmall = NO;
			}
		}
		else
		{
			alldockstoosmall = NO;
		}
	}	
	if (chosenDock == nil)
	{
		if (player_is_ahead || (docking == "TOO_BIG_TO_DOCK" && !alldockstoosmall) || !docking)
		{
			// either player is manually docking and we can't allocate new docks,
			// or the last dock was too small, and there may be an acceptable one
			// not tested yet or returning TRY_AGAIN_LATER
			docking = "TRY_AGAIN_LATER";
		}
		// no docks accept this ship (or the player is blocking them)
		return cxx_OOMakeDockingInstructions(this, [ship position], 200, 100, docking, std::nullopt, NO, -1);
	}


	// rolling is okay for some
	if	(fabs(flightRoll) > 0.01 && [chosenDock isOffCentre])
	{
		return holdPositionInstructionForShip(ship);
	}
	
	// we made it through holding!
	_shipsOnHold->removeObject(ship);
	
	[shipAI cxx_reactToMessage:"DOCKING_REQUESTED" context:"requestDockingCoordinates"];	// react to the request	
	doScriptEvent(OOJSID("stationAcceptedDockingRequest"), ship);

	return [chosenDock dockingInstructionsForShip:ship];
}


oo::PList StationEntity::holdPositionInstructionForShip(::ShipEntity *ship)
{
	if (!_shipsOnHold->containsObject(ship))
	{
		sendExpandedMessage("[station-acknowledges-hold-position]", ship);
		_shipsOnHold->addObject(ship);
	}
	
	return cxx_OOMakeDockingInstructions(this, [ship position], 0, 100, "HOLD_POSITION", std::nullopt, NO, -1);
}


void StationEntity::abortDockingForShip(::ShipEntity *ship)
{
	[ship sendAIMessage:"DOCKING_ABORTED"];
	[ship doScriptEvent:OOJSID("stationWithdrewDockingClearance")];
	
	_shipsOnHold->removeObject(ship);
	
	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		[sub abortDockingForShip:ship];
	}
	
	if ([ship isPlayer])
	{
		player_reserved_dock = nil;
	}

	sanityCheckShipsOnApproach();
}


//////////////////////////////////////////////// from superclass


bool StationEntity::shipIsInDockingCorridor(::ShipEntity *ship)
{
	if (![ship isShip])  return NO;
	if ([ship isPlayer] && [ship status] == STATUS_DEAD)  return NO;

	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		if ([sub shipIsInDockingCorridor:ship])
		{
			return YES;
		}
	}
	return NO;
}


void StationEntity::pullInShipIfPermitted(::ShipEntity *ship)
{
	[ship enterDock:this]; // dock performs permitted checks
}


bool StationEntity::dockingCorridorIsEmpty()
{
	if (!UNIVERSE)
		return NO;

	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		if ([sub dockingCorridorIsEmpty])
		{
			return YES; // if any are
		}
	}
	return NO;
}


void StationEntity::clearDockingCorridor()
{
	if (!UNIVERSE)
		return;

	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		[sub clearDockingCorridor];
	}		

	return;
}


void StationEntity::update(OOTimeDelta delta_t)
{
	BOOL isRockHermit = (scanClass == CLASS_ROCK);
	BOOL isMainStation = (this == [UNIVERSE station]);
	
	double unitime = [UNIVERSE getTime];
	
	if (!isMainStation && localMarket == nil)
	{
		initialiseLocalMarket();
	}

	ShipEntity::update(delta_t);	// [super update:delta_t]

	::PlayerEntity *player = PLAYER;

	BOOL isDockingStation = (this == (player != nullptr ? player->getTargetDockStation() : (::StationEntity *)nullptr));
	if (isDockingStation && (player != nullptr ? player->status() : OOEntityStatus{}) == STATUS_IN_FLIGHT)
	{
		if ((player != nullptr ? player->getDockingClearanceStatus() : OODockingClearanceStatus{}) >= DOCKING_CLEARANCE_STATUS_GRANTED)
		{
			if (last_launch_time-30 < unitime && (player != nullptr ? player->getDockingClearanceStatus() : OODockingClearanceStatus{}) != DOCKING_CLEARANCE_STATUS_TIMING_OUT)
			{
				sendExpandedMessage("[station-docking-clearance-about-to-expire]", oo::ToObjC(player));
				if (player != nullptr)  player->setDockingClearanceStatus(DOCKING_CLEARANCE_STATUS_TIMING_OUT);
			}
			else if (last_launch_time < unitime)
			{
				sendExpandedMessage("[station-docking-clearance-expired]", oo::ToObjC(player));
				if (player != nullptr)  player->setDockingClearanceStatus(DOCKING_CLEARANCE_STATUS_NONE);	// Docking clearance for player has expired.
				if (player != nullptr)  player->doScriptEvent(OOJSID("playerDockingClearanceExpired"));
				if (currentlyInDockingQueues() == 0) 
				{
					[getAI() message:"DOCKING_COMPLETE"];
					doScriptEvent(OOJSID("stationDockingQueuesAreEmpty"));
				}
				player_reserved_dock = nil;
			}
		}

		else if ((player != nullptr ? player->getDockingClearanceStatus() : OODockingClearanceStatus{}) == DOCKING_CLEARANCE_STATUS_NOT_REQUIRED)
		{
			if (last_launch_time < unitime)
			{
				if (player != nullptr)  player->setDockingClearanceStatus(DOCKING_CLEARANCE_STATUS_NONE);
				if (currentlyInDockingQueues() == 0) 
				{
					[getAI() message:"DOCKING_COMPLETE"];
					doScriptEvent(OOJSID("stationDockingQueuesAreEmpty"));
				}
			}
		}

		else if ((player != nullptr ? player->getDockingClearanceStatus() : OODockingClearanceStatus{}) == DOCKING_CLEARANCE_STATUS_REQUESTED &&
				hasClearDock())
		{
			::DockEntity *dock = selectDockForDocking();
			last_launch_time = unitime + DOCKING_CLEARANCE_WINDOW;
			if (hasMultipleDocks()) 
			{
				sendExpandedMessage(oo::str::formatRuntime(OO_DESC("station-docking-clearance-granted-in-@-until-@"), { [dock displayName].value_or("(null)"), cxx_ClockToString((player != nullptr ? player->clockTime() : 0.0) + DOCKING_CLEARANCE_WINDOW, NO) }), oo::ToObjC(player));
			}
			else
			{
				sendExpandedMessage(oo::str::formatRuntime(OO_DESC("station-docking-clearance-granted-until-@"), { cxx_ClockToString((player != nullptr ? player->clockTime() : 0.0) + DOCKING_CLEARANCE_WINDOW, NO) }), oo::ToObjC(player));
			}
			player_reserved_dock = dock;
			if (player != nullptr)  player->setDockingClearanceStatus(DOCKING_CLEARANCE_STATUS_GRANTED);
			if (player != nullptr)  player->doScriptEvent(OOJSID("playerDockingClearanceGranted"));

		}
	}
	
	
	if (approach_spacing > 0.0)
	{
		approach_spacing -= delta_t * 10.0;	// reduce by 10 m/s
		if (approach_spacing < 0.0)   approach_spacing = 0.0;
	}

	/* JSAI: JS-based AIs handle their own traffic either alone or 
	 * in conjunction with the system repopulator */
	if (!hasNewAI())
	{
		// begin launch of shuttles, traders, patrols
		if ((docked_shuttles > 0)&&(!isRockHermit))
		{
			if (unitime > last_shuttle_launch_time + shuttle_launch_interval)
			{
				if ((getHasNPCTraffic())&&(aegis_status != AEGIS_NONE))
				{
					launchShuttle();
				}
				last_shuttle_launch_time = unitime;
			}
		}

		if ((docked_traders > 0)&&(!isRockHermit))
		{
			if (unitime > last_trader_launch_time + trader_launch_interval)
			{
				if (getHasNPCTraffic())
				{
					launchIndependentShip("trader");
					docked_traders--;
				}
				last_trader_launch_time = unitime;
			}
		}
	
		// testing patrols
		if (unitime > (last_patrol_report_time + patrol_launch_interval))
		{
			if (!((isMainStation && getHasNPCTraffic()) || hasPatrolShips) || launchPatrol() != nil)
				last_patrol_report_time = unitime;
		}

	}
}


void StationEntity::clear()
{
	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		[sub clear];
	}
	
	_shipsOnHold->removeAllObjects();
}


bool StationEntity::hasMultipleDocks()
{
	return dockSubEntities().size() > 1;
}


// is there a dock free for the player to dock manually?
// not used for NPCs
bool StationEntity::hasClearDock()
{
	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		if ([sub allowsDocking] && [sub countOfShipsInLaunchQueue] == 0 && [sub countOfShipsInDockingQueue] == 0)
		{
			if ([sub canAcceptShipForDocking:oo::ToObjC(PLAYER)] == "DOCKING_POSSIBLE")
			{
				return YES;
			}
		}
	}
	return NO;
}


bool StationEntity::hasEligibleDock()
{
	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		// TRY_AGAIN_LATER in this context means "ships launching now"
		if ([sub allowsDocking] && ([sub canAcceptShipForDocking:oo::ToObjC(PLAYER)] == "DOCKING_POSSIBLE" || [sub canAcceptShipForDocking:oo::ToObjC(PLAYER)] == "TRY_AGAIN_LATER"))
		{
			return YES;
		}
	}
	return NO;
}


// is there any dock which may launch ships?
bool StationEntity::hasLaunchDock()
{
	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		if ([sub allowsLaunching])
		{
			return YES;
		}
	}
	return NO;
}


// only used to pick a dock for the player
::DockEntity * StationEntity::selectDockForDocking()
{
	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		if ([sub allowsDocking] && [sub countOfShipsInLaunchQueue] == 0 && [sub countOfShipsInDockingQueue] == 0)
		{
			return sub;
		}
	}
	return nil;
}


void StationEntity::addShipToLaunchQueue(::ShipEntity *ship, bool priority)
{
	unsigned			threshold = 0;

	// quickest launch if we assign ships to those bays with no incoming ships
	// and spread the ships evenly around those bays
	// much easier if the station has at least one launch-only dock
	while (threshold < 16)
	{
		for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
		{
			::DockEntity *sub = dock.get();
			if (sub != player_reserved_dock)
			{
				if ([sub countOfShipsInDockingQueue] == 0)
				{
					if ([sub allowsLaunching] && [sub countOfShipsInLaunchQueue] <= threshold)
					{
						if ([sub allowsLaunchingOf:ship])
						{
							[sub addShipToLaunchQueue:ship withPriority:priority];
							return;
						}
					}
				}
			}
		}
		threshold++;
	}
	// if we get this far, all docks have at least some incoming traffic.
	// usually most efficient (since launching is far faster than docking)
	// to assign all ships to the *same* dock with the smallest incoming queue
	// rather than to try spreading them out across several queues
	// also stops escorts being launched before their mothership 
	threshold = 0;
	while (threshold < 16)
	{
		for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
		{
			::DockEntity *sub = dock.get();
			/* so this time as long as it allows launching only check
			 * the docking queue size so long as enumerator order is
			 * deterministic, this will assign every launch this
			 * update to the same dock (edge case where new docking
			 * ship appears in the middle, probably not a problem) */
			if ([sub allowsLaunching] && [sub countOfShipsInDockingQueue] <= threshold)
			{
				if ([sub allowsLaunchingOf:ship])
				{
					[sub addShipToLaunchQueue:ship withPriority:priority];
					return;
				}
			}

		}
		threshold++;
	}
	
	OO_LOG("station.launchShip.failed", "Cancelled launch for a {} with role {}, as the {} has too many ships in its launch queue(s) or no suitable launch docks.",
			  [ship displayName].value_or("(null)"), [ship cxx_primaryRole].value_or("(null)"), getDisplayName().value_or("(null)"));
}


unsigned StationEntity::countOfShipsInLaunchQueueWithPrimaryRole(const std::string &role)
{
	unsigned result = 0;
	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		result += [sub countOfShipsInLaunchQueueWithPrimaryRole:role];
	}
	return result;
}


bool StationEntity::fitsInDock(::ShipEntity *ship)
{
   return fitsInDock(ship, YES);
}


bool StationEntity::fitsInDock(::ShipEntity *ship, bool logNoFit)
{
	::ShipEntity *self = oo::ToObjC(this);
	if (![ship isShip])  return NO;
	
	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		if ([sub allowsLaunchingOf:ship])
		{
			return YES;
		}
	}

	if (logNoFit) OO_LOG("station.launchShip.failed", "Cancelled launch for a {} with role {}, as it is too large for the docking port of the {}.",
			  [ship displayName].value_or("(null)"), [ship cxx_primaryRole].value_or("(null)"), oo::DescriptionOf(self));
	return NO;
}


void StationEntity::noteDockedShip(::ShipEntity *ship)
{
	if (ship == nil)  return;	
	
	::PlayerEntity *player = PLAYER;
	// set last launch time to avoid clashes with outgoing ships
	if ((player != nullptr ? player->getDockingClearanceStatus() : OODockingClearanceStatus{}) != DOCKING_CLEARANCE_STATUS_GRANTED)
	{
		// avoid interfering with docking clearance on another bay
		last_launch_time = [UNIVERSE getTime];
	}
	addShipToStationCount(ship);
	
	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		[sub noteDockingForShip:ship];
	}
	sanityCheckShipsOnApproach();
	
	doScriptEvent(OOJSID("otherShipDocked"), ship);
	
	BOOL isDockingStation = (this == (player != nullptr ? player->getTargetDockStation() : (::StationEntity *)nullptr));
	if (isDockingStation && (player != nullptr ? player->status() : OOEntityStatus{}) == STATUS_IN_FLIGHT &&
			(player != nullptr ? player->getDockingClearanceStatus() : OODockingClearanceStatus{}) == DOCKING_CLEARANCE_STATUS_REQUESTED)
	{
		if (!hasClearDock())
		{
			// then say why
			if (currentlyInDockingQueues())
			{
				sendExpandedMessage(oo::str::formatRuntime(OO_DESC("station-docking-clearance-holding-d-ships-approaching"), { currentlyInDockingQueues()+1 }), oo::ToObjC(player));
			}
			else if(currentlyInLaunchingQueues())
			{
				sendExpandedMessage(oo::str::formatRuntime(OO_DESC("station-docking-clearance-holding-d-ships-departing"), { currentlyInLaunchingQueues()+1 }), oo::ToObjC(player));
			}
		} 
	}


	if ([ship isPlayer])
	{
		player_reserved_dock = nil;
	}
}


void StationEntity::addShipToStationCount(::ShipEntity *ship)
{
 	if ([ship isShuttle])  docked_shuttles++;
	else if ([ship isTrader] && ![ship isPlayer])  docked_traders++;
	else if (([ship isPolice] && ![ship isEscort]) || [ship cxx_hasPrimaryRole:"defense_ship"])
	{
		if (0 < defenders_launched)  defenders_launched--;
	}
	else if ([ship cxx_hasPrimaryRole:"scavenger"] || [ship cxx_hasPrimaryRole:"miner"])	// treat miners and scavengers alike!
	{
		if (0 < scavengers_launched)  scavengers_launched--;
	}
}




// Slice 3 of docs/phases/3-slices/StationEntity.md (bead oo-hjzwk): docking clearance, damage,
// allegiance and alert level.


bool StationEntity::collideWithShip(::ShipEntity *other)
{
	/*
		There used to be a [self abortAllDockings] here. Removed as there
		doesn't appear to be a good reason for it and it interferes with
		docking clearance.
		-- Micha 2010-06-10
	       Reformatted, Ahruman 2012-08-26
	*/
	return ShipEntity::collideWithShip(other);	// [super collideWithShip:other]
}


bool StationEntity::hasHostileTarget()
{
	return ShipEntity::hasHostileTarget() || (primaryTarget() != nil && ((alertLevel == STATION_ALERT_LEVEL_YELLOW) || (alertLevel == STATION_ALERT_LEVEL_RED)));
}


void StationEntity::takeEnergyDamage(double amount, cxx::Entity *entPart, cxx::Entity *otherPart, const std::string &weaponIdentifier)
{
	::ShipEntity *self = oo::ToObjC(this);
	::Entity *ent = oo::ToObjC(entPart);
	::Entity *other = oo::ToObjC(otherPart);
	// stations must ignore friendly fire, otherwise the defenders' AI gets stuck.
	BOOL			isFriend = NO;
	::OOShipGroup		*group = this->group();
	
	if ([other isShip] && group != nil)
	{
		::OOShipGroup *otherGroup = [(::ShipEntity *)other group];
		isFriend = otherGroup == group || (otherGroup != nullptr ? otherGroup->leader() : (::ShipEntity *)nil) == self;
	}
	
	// If this is the system's main station...
	if (this == [UNIVERSE station] && !isFriend)
	{
		//...get angry
		BOOL isEnergyMine = [ent isCascadeWeapon];

		// JSAIs might ignore friendly fire from conventional weapons
		if (hasNewAI() || isEnergyMine)
		{
			unsigned b=isEnergyMine ? 96 : 64;
			if ([(::ShipEntity*)other bounty] >= b)	//already a hardened criminal?
			{
				b *= 1.5; //bigger bounty!
			}
			[(::ShipEntity*)other markAsOffender:b withReason:kOOLegalStatusReasonAttackedMainStation];
			setPrimaryAggressor(other);
			setFoundTarget(other);
			launchPolice();
		}

		if (isEnergyMine) //don't blow up!
		{
			increaseAlertLevel();
			respondToAttackFrom(ent, other);
			return;
		}
	}
	// Stop damage if main station & close to death!
	if (!isFriend && (this != [UNIVERSE station] || amount < energy) )
	{
		// Handle damage like a ship.
		ShipEntity::takeEnergyDamage(amount, entPart, otherPart, weaponIdentifier);	// [super takeEnergyDamage:...]
	}
}


void StationEntity::adjustVelocity(Vector xVel)
{
	if (this != [UNIVERSE station])  ShipEntity::adjustVelocity(xVel); //dont get moved
}


void StationEntity::takeScrapeDamage(double amount, ::Entity *ent)
{
	// Stop damage if main station
	if (this != [UNIVERSE station])  ShipEntity::takeScrapeDamage(amount, ent);
}


void StationEntity::takeHeatDamage(double amount)
{
	// Stop damage if main station
	if (this != [UNIVERSE station])  ShipEntity::takeHeatDamage(amount);
}


std::optional<std::string> StationEntity::getAllegiance()
{
	return allegiance;
}


void StationEntity::setAllegiance(const std::optional<std::string> &newAllegiance)
{
	allegiance = newAllegiance;
}


OOStationAlertLevel StationEntity::getAlertLevel()
{
	return alertLevel;
}


void StationEntity::setAlertLevel(OOStationAlertLevel level, bool signallingScript)
{
	::ShipEntity *self = oo::ToObjC(this);
	if (level < STATION_ALERT_LEVEL_GREEN)  level = STATION_ALERT_LEVEL_GREEN;
	if (level > STATION_ALERT_LEVEL_RED)  level = STATION_ALERT_LEVEL_RED;
	
	if (alertLevel != level)
	{
		OOStationAlertLevel oldLevel = alertLevel;
		alertLevel = level;
		if (signallingScript)
		{
			ShipScriptEventNoCx(self, "alertConditionChanged", ooscript::int32Value(level), ooscript::int32Value(oldLevel));
		}
		switch (level)
		{
			case STATION_ALERT_LEVEL_GREEN:
				[shipAI cxx_reactToMessage:"GREEN_ALERT" context:std::nullopt];
				break;
				
			case STATION_ALERT_LEVEL_YELLOW:
				[shipAI cxx_reactToMessage:"YELLOW_ALERT" context:std::nullopt];
				break;
				
			case STATION_ALERT_LEVEL_RED:
				[shipAI cxx_reactToMessage:"RED_ALERT" context:std::nullopt];
				break;
		}
	}
}


//////////////////////////////////////////////// extra AI routines


// Exposed to AI
void StationEntity::increaseAlertLevel()
{
	setAlertLevel((OOStationAlertLevel)(getAlertLevel() + 1), YES);
}


// Exposed to AI
void StationEntity::decreaseAlertLevel()
{
	setAlertLevel((OOStationAlertLevel)(getAlertLevel() - 1), YES);
}


// Exposed to AI
void StationEntity::becomeExplosion()
{
	if (this == [UNIVERSE station])  return;
	
	// launch docked ships if possible
	::PlayerEntity* player = PLAYER;
	if ((player)&&((player != nullptr ? player->status() : OOEntityStatus{}) == STATUS_DOCKED || (player != nullptr ? player->status() : OOEntityStatus{}) == STATUS_DOCKING)&&((player != nullptr ? player->dockedStation() : (::StationEntity *)nullptr) == this))
	{
		// undock the player!
		if (player != nullptr)  player->leaveDock(this);
		[UNIVERSE setViewDirection:VIEW_FORWARD];
		[[UNIVERSE gameController] setMouseInteractionModeForFlight];
		if (player != nullptr)  player->warnAboutHostiles();	// sound a klaxon
	}
	
	if (scanClass == CLASS_ROCK)	// ie we're a rock hermit or similar
	{
		// set the role so that we break up into rocks!
		setPrimaryRole("asteroid");
		being_mined = YES;
	}
	
	// finally bite the bullet
	ShipEntity::becomeExplosion();	// [super becomeExplosion]
}


// Exposed to AI
void StationEntity::becomeEnergyBlast()
{
	if (this == [UNIVERSE station])  return;
	ShipEntity::becomeEnergyBlast();	// [super becomeEnergyBlast]
}


void StationEntity::becomeLargeExplosion(double factor)
{
	if (this == [UNIVERSE station])  return;
	ShipEntity::becomeLargeExplosion(factor);	// [super becomeLargeExplosion:factor]
}


void StationEntity::acceptPatrolReportFrom(::ShipEntity * /* patrol_ship */)
{
	last_patrol_report_time = [UNIVERSE getTime];
}


// used by player - "other" should always be a reference to the player
// there are some checks in the function from possibly when this wasn't true?
std::optional<std::string> StationEntity::acceptDockingClearanceRequestFrom(::ShipEntity *other)
{
	std::optional<std::string>	result;	// nullopt: no answer yet (was nil)
	double		timeNow = [UNIVERSE getTime];
	::PlayerEntity	*player = PLAYER;
	
	doScriptEvent(OOJSID("stationReceivedDockingRequest"), other);


	[UNIVERSE clearPreviousMessage];

	sanityCheckShipsOnApproach();

	// Docking clearance not required - clear it just in case it's been
	// set for another nearby station.
	if (!getRequiresDockingClearance())
	{
		// TODO: We're potentially cancelling docking at another station, so
		//       ensure we clear the timer to allow NPC traffic.  If we
		//       don't, normal traffic will resume once the timer runs out.
		// No clearance is needed, but don't send friendly messages to hostile ships!
		if (!(([other isPlayer] && [other hasHostileTarget]) || (this == [UNIVERSE station] && [other bounty] > 50)))
		{
			sendExpandedMessage("[station-docking-clearance-not-required]", other);
		}
		if ([other isPlayer])
		{
			if (player != nullptr)  player->setDockingClearanceStatus(DOCKING_CLEARANCE_STATUS_NOT_REQUIRED);
		}
		[shipAI cxx_reactToMessage:"DOCKING_REQUESTED" context:std::nullopt];	// react to the request	
		doScriptEvent(OOJSID("stationAcceptedDockingRequest"), other);

		last_launch_time = timeNow + DOCKING_CLEARANCE_WINDOW;
		result = "DOCKING_CLEARANCE_NOT_REQUIRED";
	}

	// Docking clearance already granted for this station - check for
	// time-out or cancellation (but only for the Player).
	if( !result && [other isPlayer] && this == (player != nullptr ? player->getTargetDockStation() : (::StationEntity *)nullptr))
	{
		switch( (player != nullptr ? player->getDockingClearanceStatus() : OODockingClearanceStatus{}) )
		{
			case DOCKING_CLEARANCE_STATUS_TIMING_OUT:
				if (!no_docking_while_launching)
				{
					last_launch_time = timeNow + DOCKING_CLEARANCE_WINDOW;
					sendExpandedMessage(oo::str::formatRuntime(OO_DESC("station-docking-clearance-extended-until-@"), { cxx_ClockToString((player != nullptr ? player->clockTime() : 0.0) + DOCKING_CLEARANCE_WINDOW, NO) }), other);
					if (player != nullptr)  player->setDockingClearanceStatus(DOCKING_CLEARANCE_STATUS_GRANTED);
					result = "DOCKING_CLEARANCE_EXTENDED";
					break;
				}
				// else, continue with canceling.
			case DOCKING_CLEARANCE_STATUS_REQUESTED:
			case DOCKING_CLEARANCE_STATUS_GRANTED:
				last_launch_time = timeNow;
				sendExpandedMessage("[station-docking-clearance-cancelled]", other);
				if (player != nullptr)  player->setDockingClearanceStatus(DOCKING_CLEARANCE_STATUS_NONE);
				result = "DOCKING_CLEARANCE_CANCELLED";
				player_reserved_dock = nil;
				if (currentlyInDockingQueues() == 0)
				{
					[shipAI message:"DOCKING_COMPLETE"];
					doScriptEvent(OOJSID("stationDockingQueuesAreEmpty"));
				}
				break;
			case DOCKING_CLEARANCE_STATUS_NONE:
			case DOCKING_CLEARANCE_STATUS_NOT_REQUIRED:
				break;
		}
	}

	// First we must set the status to REQUESTED to avoid problems when 
	// switching docking targets - even if we later set it back to NONE.
	if (!result && [other isPlayer] && this != (player != nullptr ? player->getTargetDockStation() : (::StationEntity *)nullptr))
	{
		player_reserved_dock = nil; // and clear any previously reserved dock
		if (player != nullptr)  player->setDockingClearanceStatus(DOCKING_CLEARANCE_STATUS_REQUESTED);
	}

	// Deny docking for fugitives at the main station
	// TODO: Should this be another key in shipdata.plist and/or should this
	//  apply to all stations?
	if (!result && this == [UNIVERSE station] && [other bounty] > 50)	// do not grant docking clearance to fugitives
	{
		sendExpandedMessage("[station-docking-clearance-H-clearance-refused]", other);
		if ([other isPlayer])
			if (player != nullptr)  player->setDockingClearanceStatus(DOCKING_CLEARANCE_STATUS_NONE);
		result = "DOCKING_CLEARANCE_DENIED_SHIP_FUGITIVE";
	}
	
	if (!result && [other hasHostileTarget]) // do not grant docking clearance to hostile ships.
	{
		sendExpandedMessage("[station-docking-clearance-denied]", other);
		if ([other isPlayer])
			if (player != nullptr)  player->setDockingClearanceStatus(DOCKING_CLEARANCE_STATUS_NONE);
		result = "DOCKING_CLEARANCE_DENIED_SHIP_HOSTILE";
	}

	if (!hasEligibleDock()) // make sure at least one dock could plausibly accept the player
	{
		if ([other isPlayer])
		{
			if (player != nullptr)  player->setDockingClearanceStatus(DOCKING_CLEARANCE_STATUS_NONE);
		}
		sendExpandedMessage("[station-docking-clearance-denied-no-docks]", other);

		result = "DOCKING_CLEARANCE_DENIED_NO_DOCKS";
	}
	else if (!hasClearDock()) // skip check if at least one dock clear
	{
		// Put ship in queue if we've got incoming or outgoing traffic or
		// if the player is waiting for manual clearance and we are not
		// the player
		if (!result && ((currentlyInDockingQueues() && last_launch_time < timeNow) || (![other isPlayer] && (player != nullptr ? player->getDockingClearanceStatus() : OODockingClearanceStatus{}) == DOCKING_CLEARANCE_STATUS_REQUESTED)))
		{
			sendExpandedMessage(oo::str::formatRuntime(OO_DESC("station-docking-clearance-acknowledged-d-ships-approaching"), { currentlyInDockingQueues()+1 }), other);
			// No need to set status to REQUESTED as we've already done that earlier.
			result = "DOCKING_CLEARANCE_DENIED_TRAFFIC_INBOUND";
		}

		if (!result && currentlyInLaunchingQueues())
		{
			sendExpandedMessage(oo::str::formatRuntime(OO_DESC("station-docking-clearance-acknowledged-d-ships-departing"), { currentlyInLaunchingQueues()+1 }), other);
			// No need to set status to REQUESTED as we've already done that earlier.
			result = "DOCKING_CLEARANCE_DENIED_TRAFFIC_OUTBOUND";
		}
		if (!result)
		{
			// if this happens, the station has no docks which allow
			// docking, so deny clearance
			if ([other isPlayer])
			{
				if (player != nullptr)  player->setDockingClearanceStatus(DOCKING_CLEARANCE_STATUS_NONE);
			}
			result = "DOCKING_CLEARANCE_DENIED_NO_DOCKS";
			// but can check to see if we'll open some for later.
			BOOL openLater = NO;
			for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
			{
				::DockEntity *sub = dock.get();
				std::string docking = [sub canAcceptShipForDocking:other].value_or("");
				if (docking == "DOCK_CLOSED")
				{
					ooscript::Context context = OOJSAcquireContext();
					ooscript::Value		rval = ooscript::undefinedValue();
					ooscript::Value		args[] = { OOJSValueFromNativeObject(context, sub),
														 OOJSValueFromNativeObject(context, other) };
					bool tempreject = NO;

					BOOL OK = (getScript() != nullptr ? getScript()->callMethod(OOJSID("willOpenDockingPortFor"), context, args, 2, &rval) : false);
					if (OK)  OK = ooscript::valueToBoolean(context, rval, &tempreject);
					if (!OK)  tempreject = NO; // default to permreject
					if (tempreject)
					{
						openLater = YES;
					}
					OOJSRelinquishContext(context);			
				}
				if (openLater) break;
			}

			if (openLater)
			{
				sendExpandedMessage("[station-docking-clearance-denied-no-docks-yet]", other);
			} 
			else
			{
				sendExpandedMessage("[station-docking-clearance-denied-no-docks]", other);
			}

		}
	}

	// Ship has passed all checks - grant docking!
	if (!result)
	{
		last_launch_time = timeNow + DOCKING_CLEARANCE_WINDOW;
		if ([other isPlayer]) 
		{
			if (player != nullptr)  player->setDockingClearanceStatus(DOCKING_CLEARANCE_STATUS_GRANTED);
			player_reserved_dock = selectDockForDocking();
		}

		if (hasMultipleDocks() && [other isPlayer])
		{
			sendExpandedMessage(oo::str::formatRuntime(OO_DESC("station-docking-clearance-granted-in-@-until-@"), { [player_reserved_dock displayName].value_or("(null)"), cxx_ClockToString((player != nullptr ? player->clockTime() : 0.0) + DOCKING_CLEARANCE_WINDOW, NO) }), other);
		}
		else
		{
			sendExpandedMessage(oo::str::formatRuntime(OO_DESC("station-docking-clearance-granted-until-@"), { cxx_ClockToString((player != nullptr ? player->clockTime() : 0.0) + DOCKING_CLEARANCE_WINDOW, NO) }), other);
		}

		result = "DOCKING_CLEARANCE_GRANTED";
		[shipAI cxx_reactToMessage:"DOCKING_REQUESTED" context:std::nullopt];	// react to the request	
		doScriptEvent(OOJSID("stationAcceptedDockingRequest"), other);
	}
	return result;
}


unsigned StationEntity::currentlyInDockingQueues()
{
	unsigned soa = 0;
	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		soa += [sub countOfShipsInDockingQueue];
	}
	soa += _shipsOnHold->count();
	return soa;
}


unsigned StationEntity::currentlyInLaunchingQueues()
{
	unsigned soa = 0;
	for (const oo::ObjCRef<::DockEntity *> &dock : dockSubEntities())
	{
		::DockEntity *sub = dock.get();
		soa += [sub countOfShipsInLaunchQueue];
	}
	return soa;
}


