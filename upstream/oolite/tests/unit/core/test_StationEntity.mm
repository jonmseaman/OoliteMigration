/*	test_StationEntity.mm
	Unit tests for StationEntity (src/Core/Entities/StationEntity.h), the station: slice 1 of its
	slice plan (docs/phases/3-slices/StationEntity.md, bead oo-64ako), the class shell, which moves
	the station's state and its accessors, market, shipyard, flags and set-up into
	cxx::StationEntity and keeps the Objective-C StationEntity as its facade (proposed ADR-0056,
	amendments oo-60fwo and oo-64ako).

	As test_ShipEntity's, the station's object needs the game graph, so the test links the whole
	game but main (['*']) and uses a Universe that was never initialised and a plain entity as
	PLAYER. The station keeps StationEntity's and ShipEntity's own set-up from the definition; only
	the virtual dock it makes when it has no docks is a stand-in (TestStation records the dock's
	definition instead of asking the universe for the shipdata entry). The cases test the slice's
	own units through the Objective-C API, written against it and run on the unconverted class
	first; the cases after "The crossing" pin the C++ part once it exists.
	Run: bash tools/check-core-tests.sh test_StationEntity
*/

#import "StationEntity.h"
#import "DockEntity.h"
#import "Universe.h"
#import "PlayerEntity.h"

#include "oo_test.hpp"

#include <cmath>
#include <string>


// main.mm defines the debug flags, and the test has its own main.
#ifndef NDEBUG
uint32_t gDebugFlags = 0;
#endif

@class PlayerEntity;
extern PlayerEntity *gOOPlayer;
extern Universe *gSharedUniverse;
extern ooscript::Context gOOJSMainThreadContext;


@interface TestStationPlayer: Entity
@end


@implementation TestStationPlayer

- (HPVector) viewpointPosition	{ return kZeroHPVector; }

@end


namespace {

// What the next station's virtual dock does, and the definition it was given.
bool sFailVirtualDock = false;
int sVirtualDocks = 0;
oo::PList sVirtualDockDict;

}	// namespace


// A station whose virtual dock only records its definition (the dock itself is a shipdata entry).
@interface TestStation: StationEntity
@end


@implementation TestStation

- (BOOL) cxx_setUpOneStandardSubentity:(const oo::PList &)subentDict asTurret:(BOOL)asTurret
{
	if (asTurret)  return NO;
	sVirtualDocks++;
	sVirtualDockDict = subentDict;
	return !sFailVirtualDock;
}

@end


namespace {

void SetExplicitlyUnpiloted(ShipEntity *s, bool value)	{ s->_cxxShip->_explicitlyUnpiloted = value; }


void SetUp()
{
	static Universe *universe = nil;
	if (universe == nil)
	{
		universe = (Universe *)class_createInstance([Universe class], 0);	// never released
		universe->_cxxUniverse = oo::makeRef<cxx::Universe>(universe);	// what -initWithGameView: makes first (ADR-0056 amendment oo-riqmz)
	}
	gSharedUniverse = universe;
	static TestStationPlayer *player = nil;
	if (player == nil)  player = [[TestStationPlayer alloc] init];
	gOOPlayer = (PlayerEntity *)player;
	// The ship's -dealloc sends its (absent) scripts entityDestroyed in a request on the main
	// thread's context, so there is one, with nothing in it.
	if (gOOJSMainThreadContext == nullptr)  gOOJSMainThreadContext = ooscript::newContext(ooscript::newRuntime(8u * 1024u * 1024u), 8192);
	sFailVirtualDock = false;
	sVirtualDocks = 0;
	sVirtualDockDict = oo::PList();
}


// An unpiloted station (a crewed one would ask the universe for a police pilot).
oo::PList Definition(oo::PList::Dict extra = {})
{
	oo::PList::Dict dict{ { "unpiloted", oo::PList(true) } };
	for (auto &entry : extra)  dict[entry.first] = entry.second;
	return oo::PList(std::move(dict));
}


TestStation *MakeStation(const std::string &key, oo::PList::Dict extra = {})
{
	return [[[TestStation alloc] cxx_initWithKey:key definition:Definition(std::move(extra))] autorelease];
}


bool Near(HPVector a, HPVector b)	{ return std::fabs(a.x - b.x) < 1e-3 && std::fabs(a.y - b.y) < 1e-3 && std::fabs(a.z - b.z) < 1e-3; }

}	// namespace


// --- Slice 1: the class shell (bead oo-64ako) ------------------------------------------------------

// The initialiser and the set-up from the definition: every key the station reads, and the
// virtual dock it makes because it has none.
OO_TEST(initAndSetUpFromDictionary)
{
	@autoreleasepool
	{
		SetUp();
		TestStation *station = MakeStation("coriolis", {
			{ "port_radius", oo::PList(750.0) },
			{ "equivalent_tech_level", oo::PList(9) },
			{ "max_scavengers", oo::PList(2) },
			{ "max_defense_ships", oo::PList(4) },
			{ "max_police", oo::PList(5) },
			{ "equipment_price_factor", oo::PList(0.25) },
			{ "has_npc_traffic", oo::PList(false) },
			{ "suppress_arrival_reports", oo::PList(true) },
			{ "allegiance", oo::PList(std::string("pirate")) },
			{ "market_capacity", oo::PList(50) },
			{ "market_definition", oo::PList(oo::PList::Array{ oo::PList(std::string("a")), oo::PList(std::string("b")) }) },
			{ "market_script", oo::PList(std::string("market.js")) },
			{ "market_monitored", oo::PList(true) },
			{ "market_broadcast", oo::PList(false) },
			{ "requires_docking_clearance", oo::PList(true) },
			{ "allows_fast_docking", oo::PList(true) },
			{ "allows_auto_docking", oo::PList(false) },
			{ "interstellar_undocking", oo::PList(true) },
		});
		OO_CHECK(station != nil);
		OO_CHECK([station isShip] && [station isStation] && ![station isPlayer]);
		OO_CHECK([station cxx_shipDataKey] == std::optional<std::string>("coriolis"));
		OO_CHECK([station hasBreakPattern]);
		OO_CHECK([station alertLevel] == STATION_ALERT_LEVEL_GREEN);
		OO_CHECK([station equivalentTechLevel] == 9);
		OO_CHECK([station countOfDockedContractors] == 2);
		OO_CHECK([station countOfDockedPolice] == 5);
		OO_CHECK([station countOfDockedDefenders] == 4);
		OO_CHECK([station equipmentPriceFactor] == 0.5f);		// at least 0.5
		OO_CHECK(![station hasNPCTraffic]);
		OO_CHECK([station suppressArrivalReports]);
		OO_CHECK([station cxx_allegiance] == std::optional<std::string>("pirate"));
		OO_CHECK([station marketCapacity] == 50);
		OO_CHECK([station cxx_marketDefinition].isArray() && [station cxx_marketDefinition].count() == 2);
		OO_CHECK([station cxx_marketScriptName] == std::optional<std::string>("market.js"));
		OO_CHECK([station marketMonitored] && ![station marketBroadcast]);	// not the main station
		OO_CHECK([station requiresDockingClearance]);
		OO_CHECK([station allowsFastDocking] && ![station allowsAutoDocking]);
		OO_CHECK([station interstellarUndockingAllowed]);
		OO_CHECK([station allowsSaving] == [UNIVERSE deterministicPopulation]);	// a fixed station (no top speed)
		OO_CHECK(vector_equal([station virtualPortDimensions], make_vector(69, 69, 250)));
		OO_CHECK([station playerReservedDock] == nil);
		OO_CHECK([station group] != nil && [station group] == [station stationGroup]);
		OO_CHECK(![station cxx_crew].has_value());

		// No docks: a virtual one, at the port radius.
		OO_CHECK(sVirtualDocks == 1);
		OO_CHECK(sVirtualDockDict.get<std::string>("subentity_key", "") == "oolite-dock-virtual");
		OO_CHECK(sVirtualDockDict.get<bool>("is_dock", false) && sVirtualDockDict.get<bool>("_is_virtual_dock", false));
		OO_CHECK(sVirtualDockDict.get<std::string>("dock_label", "") == "the docking bay");
		const oo::PList *position = sVirtualDockDict.find("position");
		OO_CHECK(position != nullptr && position->get<double>("z", 0) == 750.0 && position->get<double>("x", 1) == 0.0);
		OO_CHECK([station cxx_dockSubEntities].empty());
	}
}


// The defaults of every key the station reads.
OO_TEST(setUpDefaults)
{
	@autoreleasepool
	{
		SetUp();
		TestStation *station = MakeStation("plain");
		OO_CHECK(station != nil);
		OO_CHECK([station countOfDockedContractors] == 3 && [station countOfDockedDefenders] == 3);
		OO_CHECK([station countOfDockedPolice] == STATION_MAX_POLICE);
		OO_CHECK([station equipmentPriceFactor] == 1.0f);
		OO_CHECK([station hasNPCTraffic]);		// a fixed station has traffic
		OO_CHECK(![station suppressArrivalReports]);
		OO_CHECK(![station cxx_allegiance].has_value());
		OO_CHECK([station marketCapacity] == MAIN_SYSTEM_MARKET_LIMIT);
		OO_CHECK([station cxx_marketDefinition].isNull());
		OO_CHECK(![station cxx_marketScriptName].has_value());
		OO_CHECK(![station marketMonitored] && [station marketBroadcast]);
		OO_CHECK([station requiresDockingClearance] == [UNIVERSE dockingClearanceProtocolActive]);
		OO_CHECK(![station allowsFastDocking] && [station allowsAutoDocking]);
		OO_CHECK(![station interstellarUndockingAllowed]);
		OO_CHECK(![station isRotatingStation] || [station cxx_shipInfoDictionary].find("roles") == nullptr);
		OO_CHECK(![station marketOverrideName].has_value());
		OO_CHECK(![station hasShipyard]);
		OO_CHECK(sVirtualDocks == 1);
	}
}


// A virtual dock that cannot be made: -setUpSubEntities answers NO, which ShipEntity's set-up
// ignores, so the station is still made.
OO_TEST(virtualDockThatFails)
{
	@autoreleasepool
	{
		SetUp();
		sFailVirtualDock = true;
		TestStation *station = MakeStation("dockless");
		OO_CHECK(station != nil && sVirtualDocks == 1);
		OO_CHECK(![station setUpSubEntities] && sVirtualDocks == 2);
		sFailVirtualDock = false;
		OO_CHECK([station setUpSubEntities] && sVirtualDocks == 3);
	}
}


// Stations of any scan class are piloted unless explicitly unpiloted or a hulk.
OO_TEST(isUnpiloted)
{
	@autoreleasepool
	{
		SetUp();
		TestStation *station = MakeStation("rock", { { "scan_class", oo::PList(std::string("CLASS_CARGO")) } });
		OO_CHECK([station isUnpiloted]);			// unpiloted = yes
		SetExplicitlyUnpiloted(station, false);
		OO_CHECK(![station isUnpiloted]);			// a ship of CLASS_CARGO would be
		[station setHulk:YES];
		OO_CHECK([station isUnpiloted]);
		[station setHulk:NO];
		OO_CHECK(![station isUnpiloted]);
	}
}


OO_TEST(flagsAndCounts)
{
	@autoreleasepool
	{
		SetUp();
		TestStation *station = MakeStation("flags");
		[station setEquivalentTechLevel:4];
		OO_CHECK([station equivalentTechLevel] == 4);

		[station setHasNPCTraffic:NO];
		OO_CHECK(![station hasNPCTraffic]);
		[station setHasNPCTraffic:(BOOL)7];
		OO_CHECK([station hasNPCTraffic] == YES);

		[station setRequiresDockingClearance:(BOOL)2];
		OO_CHECK([station requiresDockingClearance] == YES);
		[station setRequiresDockingClearance:NO];
		OO_CHECK([station requiresDockingClearance] == NO);

		[station setAllowsFastDocking:(BOOL)4];
		OO_CHECK([station allowsFastDocking] == YES);
		[station setAllowsAutoDocking:NO];
		OO_CHECK([station allowsAutoDocking] == NO);

		[station setSuppressArrivalReports:(BOOL)8];
		OO_CHECK([station suppressArrivalReports] == YES);
		[station setHasBreakPattern:NO];
		OO_CHECK([station hasBreakPattern] == NO);
		[station setHasBreakPattern:YES];
		OO_CHECK([station hasBreakPattern] == YES);
	}
}


// The shipyard is held as given and edited in place; the interfaces are a live map.
OO_TEST(shipyardAndInterfaces)
{
	@autoreleasepool
	{
		SetUp();
		TestStation *station = MakeStation("yard");
		OO_CHECK([station cxx_localShipyard] == nullptr);	// not generated yet
		const std::vector<oo::PList> given{ oo::PList(oo::PList::Dict{ { "id", oo::PList(std::string("x")) } }) };
		[station cxx_setLocalShipyard:given];
		std::vector<oo::PList> *shipyard = [station cxx_localShipyard];
		OO_CHECK(shipyard != nullptr && shipyard->size() == 1);
		shipyard->push_back(oo::PList());
		OO_CHECK([station cxx_localShipyard]->size() == 2);

		auto *interfaces = [station cxx_localInterfaces];
		OO_CHECK(interfaces != nullptr && interfaces->empty());
		[station cxx_setInterfaceDefinition:nil forKey:"absent"];	// removing nothing
		OO_CHECK([station cxx_localInterfaces]->empty());

		StationEntity *none = nil;
		OO_CHECK([none cxx_localShipyard] == nullptr && [none cxx_localInterfaces] == nullptr);
	}
}


// The shipdata keys the station reads after the set-up: rotation, the market override, the
// shipyard.
OO_TEST(shipInfoQueries)
{
	@autoreleasepool
	{
		SetUp();
		OO_CHECK([MakeStation("r1", { { "rotating", oo::PList(true) }, { "roles", oo::PList(std::string("carrier")) } }) isRotatingStation]);
		OO_CHECK([MakeStation("r2", { { "roles", oo::PList(std::string("station rotating-station")) } }) isRotatingStation]);
		OO_CHECK(![MakeStation("r3", { { "roles", oo::PList(std::string("carrier")) } }) isRotatingStation]);
		OO_CHECK([MakeStation("r4") isRotatingStation]);		// no roles at all: legacy YES

		OO_CHECK([MakeStation("m1", { { "market", oo::PList(std::string("special")) } }) marketOverrideName] == std::optional<std::string>("special"));
		OO_CHECK([MakeStation("m2", { { "market", oo::PList(3) } }) marketOverrideName] == std::optional<std::string>("3"));
		OO_CHECK(![MakeStation("m3", { { "market", oo::PList(oo::PList::Array{}) } }) marketOverrideName].has_value());

		OO_CHECK([MakeStation("s1", { { "has_shipyard", oo::PList(true) } }) hasShipyard]);
		OO_CHECK([MakeStation("s2", { { "hasShipyard", oo::PList(std::string("yes")) } }) hasShipyard]);
		OO_CHECK(![MakeStation("s3", { { "has_shipyard", oo::PList(false) }, { "hasShipyard", oo::PList(true) } }) hasShipyard]);
		OO_CHECK(![MakeStation("s4") hasShipyard]);
	}
}


OO_TEST(positionPlanetAndDescription)
{
	@autoreleasepool
	{
		SetUp();
		TestStation *station = MakeStation("where", { { "name", oo::PList(std::string("Coriolis")) } });
		[station setPosition:make_HPvector(1, 2, 3)];
		[station setOrientation:kIdentityQuaternion];
		HPVector forward = vectorToHPVector(vector_forward_from_quaternion(kIdentityQuaternion));
		OO_CHECK(Near([station beaconPosition], HPvector_add(make_HPvector(1, 2, 3), HPvector_multiply_scalar(forward, 10000.0))));

		[station setPlanet:nil];
		OO_CHECK([station planet] == nil);

		const std::optional<std::string> components = [station cxx_descriptionComponents];
		OO_CHECK(components.has_value() && components->rfind("\"Coriolis\" \"Coriolis\" ", 0) == 0);	// the ship's own after the station's name

#ifndef NDEBUG
		[station dumpSelfState];		// logs; nothing to check but that it runs
#endif
	}
}


OO_TEST_MAIN()
