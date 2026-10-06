/*	test_ShipEntity.mm
	Unit tests for ShipEntity (src/Core/Entities/ShipEntity.h), the ship: slice 1 of its slice plan
	(docs/phases/3-slices/ShipEntity.md, bead oo-60fwo), the class shell, which moves the ship's
	state into cxx::ShipEntity and keeps the Objective-C ShipEntity as its facade (proposed
	ADR-0056, amendments oo-bj8 and oo-60fwo).

	Like Entity's, the ship's object needs the game graph, so the test links the whole game but
	main (['*']) and uses a Universe that was never initialised, a plain entity as PLAYER
	(amendment oo-bj8 item 11), and an empty JavaScript context for the events the ship sends its
	scripts. The ship is a subclass whose -setUpShipFromDictionary: only counts (the set-up from
	shipdata is slices 2 and 3, and needs the game's data), so the cases test the slice's own units:
	the initialisers (what -cxx_initWithKey:definition: sets before the set-up, the set-up
	failing, the top-speed sanity check, -initBypassForPlayer, and -init sent again as
	PlayerEntity's -deferredInit does), -dealloc (it leaves the ship's groups), and the two
	SubEntityRelationship categories. The expectations were written against the Objective-C API
	and run on the unconverted class first. Ivars the game reads directly go through the block of
	helpers below, the one place that knows where they live. The tests after those pin the
	crossing: an Objective-C ship's C++ part is a cxx::ShipEntity, the facade's _cxxShip is that
	part, and a ship released before its initialiser ran is deallocated without a C++ part.
	Run: bash tools/check-core-tests.sh
*/

#import "ShipEntity.h"
#import "OOShipGroup.h"
#import "OODescription.h"
#import "Universe.h"

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


@interface TestPlayer: Entity
@end


@implementation TestPlayer

- (HPVector) viewpointPosition	{ return kZeroHPVector; }

@end


// Declared by nothing public: PlayerEntity and the ship's own set-up declare them privately.
@interface ShipEntity (TestPrivate)
- (id) initBypassForPlayer;
- (void) addSubEntity:(Entity<OOSubEntity> *)subent;
@end


namespace {

// What the next ship's set-up does.
bool sFailSetUp = false;
bool sInfiniteSpeed = false;

}	// namespace


// A ship whose set-up from shipdata only counts and records what it was given.
@interface TestShip: ShipEntity
{
@public
	int			_setUps;
	oo::PList	_setUpDict;
}
@end


@implementation TestShip

- (BOOL) setUpShipFromDictionary:(const oo::PList &)dict
{
	_setUps++;
	_setUpDict = dict;
	if (sInfiniteSpeed)  [self setMaxFlightSpeed:INFINITY];
	return !sFailSetUp;
}

@end


namespace {

// --- Ivars the game reads directly (ship->shot_time), and nothing else ----------------------------

OOTimeDelta ShotTime(ShipEntity *s)		{ return s->_cxxShip->shot_time; }
OOBehaviour Behaviour(ShipEntity *s)	{ return s->_cxxShip->behaviour; }
void SetSubEntity(Entity *e, bool value)	{ e->_cxxEntity->isSubEntity = value; }

// --------------------------------------------------------------------------------------------------


void SetUp()
{
	static Universe *universe = nil;
	if (universe == nil)  universe = (Universe *)class_createInstance([Universe class], 0);	// never released
	gSharedUniverse = universe;
	static TestPlayer *player = nil;
	if (player == nil)  player = [[TestPlayer alloc] init];
	gOOPlayer = (PlayerEntity *)player;
	// The ship's -dealloc sends its (absent) scripts entityDestroyed in a request on the main
	// thread's context, so there is one, with nothing in it.
	if (gOOJSMainThreadContext == nullptr)  gOOJSMainThreadContext = ooscript::newContext(ooscript::newRuntime(8u * 1024u * 1024u), 8192);
	sFailSetUp = false;
	sInfiniteSpeed = false;
}


oo::PList Definition()
{
	return oo::PList(oo::PList::Dict{ { "max_flight_speed", oo::PList(250.0) } });
}

}	// namespace


OO_TEST(initWithKeyAndDefinition)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"test-ship" definition:Definition()] autorelease];
		OO_CHECK(ship != nil);
		OO_CHECK(ship->_setUps == 1 && ship->_setUpDict.get<double>("max_flight_speed", 0) == 250.0);
		OO_CHECK([ship isShip] && ![ship isStation] && ![ship isPlayer]);
		OO_CHECK([ship cxx_shipDataKey] == std::optional<std::string>("test-ship"));
		OO_CHECK([ship status] == STATUS_IN_FLIGHT);
		OO_CHECK([ship zeroDistance] == (GLfloat)(SCANNER_MAX_RANGE2 * 2.0));
		OO_CHECK([ship weaponRechargeRate] == 6.0f);
		OO_CHECK(ShotTime(ship) == INITIAL_SHOT_TIME);
		OO_CHECK([ship temperature] == SHIP_MIN_CABIN_TEMP);
		OO_CHECK([ship currentWeaponFacing] == WEAPON_FACING_FORWARD);
		OO_CHECK([ship laserHeatLevelForward] == 0 && [ship laserHeatLevelAft] == 0 && [ship laserHeatLevelPort] == 0 && [ship laserHeatLevelStarboard] == 0);
		OO_CHECK([ship entityPersonalityInt] >= 0 && [ship entityPersonalityInt] <= (GLint)ENTITY_PERSONALITY_MAX);
		OO_CHECK([ship maxFlightSpeed] == 0);	// the set-up did not set it
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_IDLE);
	}
}


OO_TEST(initIsAnEmptyKey)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] init] autorelease];
		OO_CHECK(ship != nil && ship->_setUps == 1 && ship->_setUpDict.isNull());
		OO_CHECK([ship cxx_shipDataKey] == std::optional<std::string>(""));
		OO_CHECK([ship isShip] && [ship status] == STATUS_IN_FLIGHT);
	}
}


OO_TEST(initFailsWhenSetUpFails)
{
	@autoreleasepool
	{
		SetUp();
		sFailSetUp = true;
		TestShip *ship = [[TestShip alloc] cxx_initWithKey:"bad" definition:Definition()];
		OO_CHECK(ship == nil);
	}
}


OO_TEST(initClampsAnInfiniteTopSpeed)
{
	@autoreleasepool
	{
		SetUp();
		sInfiniteSpeed = true;
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"fast" definition:Definition()] autorelease];
		OO_CHECK(ship != nil && [ship maxFlightSpeed] == 300.0f);
	}
}


OO_TEST(initBypassForPlayer)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] initBypassForPlayer] autorelease];
		OO_CHECK(ship != nil && ship->_setUps == 0);
		OO_CHECK(![ship isShip] && [ship status] == STATUS_COCKPIT_DISPLAY);
		OO_CHECK([ship cxx_shipDataKey] == std::nullopt);
		OO_CHECK([ship temperature] == 0 && [ship weaponRechargeRate] == 0 && ShotTime(ship) == 0);
	}
}


// PlayerEntity's -deferredInit: made by -initBypassForPlayer, then sent -[ShipEntity
// cxx_initWithKey:definition:] (and so -init) again. The ship keeps its C++ part, the body runs
// again over it, and what the body does not set stays.
OO_TEST(initSentAgain)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] initBypassForPlayer] autorelease];
		Entity *asEntity = ship;
		void *part = oo::ToCxx(asEntity);
		[ship setFuel:5];
		[ship setEnergy:42];
		OO_CHECK([ship cxx_initWithKey:"player" definition:Definition()] == ship);
		OO_CHECK((void *)oo::ToCxx(asEntity) == part);
		OO_CHECK(ship->_setUps == 1 && [ship isShip] && [ship status] == STATUS_IN_FLIGHT);
		OO_CHECK([ship cxx_shipDataKey] == std::optional<std::string>("player"));
		OO_CHECK([ship fuel] == 5 && [ship energy] == 42);
		OO_CHECK([ship temperature] == SHIP_MIN_CABIN_TEMP && ShotTime(ship) == INITIAL_SHOT_TIME);
#ifndef NDEBUG
		gLiveEntityCount--;		// the second -init counted it again, as it did
		gTotalEntityMemory -= class_getInstanceSize([TestShip class]);
#endif
	}
}


OO_TEST(deallocLeavesItsGroups)
{
	OOShipGroup *group = nil;
	OOShipGroup *escorts = nil;
	@autoreleasepool
	{
		SetUp();
		group = [[OOShipGroup alloc] init];
		TestShip *ship = [[TestShip alloc] cxx_initWithKey:"grouped" definition:Definition()];
		[ship setGroup:group];
		escorts = [[ship escortGroup] retain];
		OO_CHECK([group containsShip:ship] && [escorts containsShip:ship] && [escorts leader] == ship);
		[ship release];
	}
	OO_CHECK([group count] == 0 && [escorts count] == 0);
	[group release];
	[escorts release];
}


OO_TEST(subEntityRelationship)
{
	@autoreleasepool
	{
		SetUp();
		Entity *plain = [[[Entity alloc] init] autorelease];
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"mother" definition:Definition()] autorelease];
		TestShip *sub = [[[TestShip alloc] cxx_initWithKey:"turret" definition:Definition()] autorelease];
		TestShip *other = [[[TestShip alloc] cxx_initWithKey:"other" definition:Definition()] autorelease];

		// Entity's: never.
		OO_CHECK(![plain isShipWithSubEntityShip:ship]);
		[(Entity<OOSubEntity> *)plain drawSubEntityImmediate:true translucent:false];	// does nothing

		// The ship's: a ship that is its subentity, and that it agrees is.
		OO_CHECK(![ship isShipWithSubEntityShip:plain]);
		OO_CHECK(![ship isShipWithSubEntityShip:sub]);		// not a subentity
		[ship addSubEntity:sub];
		OO_CHECK([sub owner] == ship && [ship hasSubEntity:sub]);
		OO_CHECK([ship isShipWithSubEntityShip:sub]);
		OO_CHECK(![other isShipWithSubEntityShip:sub]);		// someone else's
#ifndef NDEBUG
		// A ship that claims the parent, which does not agree: an internal error, and it is cut loose.
		SetSubEntity(other, true);
		[other setOwner:ship];
		OO_CHECK(![ship isShipWithSubEntityShip:other]);
		OO_CHECK([other owner] == nil);
		SetSubEntity(other, false);
#endif
		[ship clearSubEntities];
		OO_CHECK([sub owner] == nil);
	}
}


// --- The crossing (after the conversion) ---------------------------------------------------------

// An Objective-C ship's C++ part is a cxx::ShipEntity, and the facade's typed alias is that part.
OO_TEST(objCShipPartIsAShip)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"crossing" definition:Definition()] autorelease];
		Entity *asEntity = ship;
		cxx::ShipEntity *part = oo::ToCxx(ship);
		OO_CHECK(part != nullptr && part == ship->_cxxShip);
		OO_CHECK(dynamic_cast<cxx::ShipEntity *>(oo::ToCxx(asEntity)) == part);
		OO_CHECK(oo::AsObjCEntity(part) != nullptr && oo::ToObjC(part) == ship);
		OO_CHECK(part->getIsShip() && part->_shipKey == std::optional<std::string>("crossing"));

		// From C++, a member that a subclass overrides reaches the Objective-C override.
		part->setStatus(STATUS_LAUNCHING);
		OO_CHECK([ship status] == STATUS_LAUNCHING);
		OO_CHECK(part->isShipWithSubEntityShip(asEntity) == false);

		// A ship made the player's way has its part as well.
		TestShip *bypass = [[[TestShip alloc] initBypassForPlayer] autorelease];
		OO_CHECK(bypass->_cxxShip != nullptr && bypass->_cxxShip == oo::ToCxx(static_cast<Entity *>(bypass)));
	}
}


// A failing initialiser that releases the ship before [super init] (the Objective-C idiom): the
// facade's -dealloc runs without a C++ part, as the root's does (oo-s6ic6).
OO_TEST(releasedBeforeInit)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [TestShip alloc];
		OO_CHECK(ship->_cxxShip == nullptr);
		[ship release];
	}
}


// --- Slice 2: -cxx_setUpFromDictionary:, the set-up players and NPCs share (bead oo-cvbe3) -------

namespace {

const cxx::ShipEntity *Part(ShipEntity *s)	{ return s->_cxxShip; }

}	// namespace


// An empty definition (nil, as PlayerEntity's -deferredInit may give) is an empty dictionary,
// and every setting takes its default.
OO_TEST(setUpFromDictionaryDefaults)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"defaults" definition:Definition()] autorelease];
		OO_CHECK([ship cxx_setUpFromDictionary:oo::PList()]);
		const cxx::ShipEntity *part = Part(ship);
		OO_CHECK([ship cxx_shipInfoDictionary].isDict() && [ship cxx_shipInfoDictionary].count() == 0);
		OO_CHECK([ship maxFlightSpeed] == 160.0f && [ship maxFlightRoll] == 2.0f && [ship maxFlightPitch] == 1.0f && [ship maxFlightYaw] == 1.0f);
		OO_CHECK([ship cruiseSpeed] == 160.0f * 0.8f);
		OO_CHECK([ship maxThrust] == 15.0f && [ship thrust] == 15.0f);
		OO_CHECK([ship afterburnerFactor] == 7.0f && [ship afterburnerRate] == AFTERBURNER_BURNRATE);
		OO_CHECK([ship maxEnergy] == 200.0f && part->energy_recharge_rate == 1.0f);
		OO_CHECK([ship weaponFacings] == VALID_WEAPON_FACINGS);
		OO_CHECK([ship missileCount] == 0 && [ship missileCapacity] == 0);
		OO_CHECK(part->cloakPassive && part->cloakAutomatic && !part->cloaking_device_active && !part->military_jammer_active);
		OO_CHECK(part->isFrangible && !part->isWreckage && part->canFragment);
		OO_CHECK(part->max_cargo == 0 && [ship extraCargo] == 15);
		OO_CHECK([ship hyperspaceSpinTime] == DEFAULT_HYPERSPACE_SPIN_TIME);
		OO_CHECK([ship cxx_name] == std::optional<std::string>("?"));
		OO_CHECK([ship cxx_shipUniqueName] == std::optional<std::string>(""));
		OO_CHECK([ship cxx_shipClassName] == std::optional<std::string>("?"));
		OO_CHECK(part->displayName == std::nullopt);
		OO_CHECK(part->_scaleFactor == 1.0f);
		OO_CHECK(![ship scriptedMisjump] && [ship scriptedMisjumpRange] == 0.5f);
		OO_CHECK(part->_lightsActive && !part->haveExecutedSpawnAction && !part->isMissile);
		OO_CHECK(quaternion_equal([ship subEntityRotationalVelocity], kIdentityQuaternion));
		OO_CHECK(!part->_multiplyWeapons && part->forwardWeaponOffset.size() == 1 && vector_equal(part->forwardWeaponOffset[0], kZeroVector));
		OO_CHECK([ship sunGlareFilter] == 0.97f);
		OO_CHECK(part->scriptInfo.isNull() && part->explosionType.isNull());
		OO_CHECK(![ship isDemoShip]);
	}
}


// Each setting from the definition, with the clamps: an injector speed factor under 1, too many
// missiles for the pylons, too many pylons; and what follows from others (scaled positions, the
// class name from the name, no hyperspace motor).
OO_TEST(setUpFromDictionaryValues)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"values" definition:Definition()] autorelease];
		const oo::PList definition(oo::PList::Dict{
			{ "max_flight_speed", oo::PList(300.0) },
			{ "max_flight_roll", oo::PList(3.0) },
			{ "max_flight_pitch", oo::PList(1.5) },
			{ "thrust", oo::PList(20.0) },
			{ "injector_burn_rate", oo::PList(0.5) },
			{ "injector_speed_factor", oo::PList(0.5) },
			{ "max_energy", oo::PList(500.0) },
			{ "energy_recharge_rate", oo::PList(4.0) },
			{ "weapon_facings", oo::PList(0xFF) },
			{ "missiles", oo::PList(40) },
			{ "max_missiles", oo::PList(50) },
			{ "cloak_passive", oo::PList(false) },
			{ "frangible", oo::PList(false) },
			{ "max_cargo", oo::PList(20) },
			{ "extra_cargo", oo::PList(5) },
			{ "hyperspace_motor", oo::PList(false) },
			{ "name", oo::PList(std::string("Viper")) },
			{ "ship_name", oo::PList(std::string("Bob")) },
			{ "display_name", oo::PList(std::string("Police Viper")) },
			{ "model_scale_factor", oo::PList(2.0) },
			{ "scoop_position", oo::PList(std::string("1 2 3")) },
			{ "weapon_mount_mode", oo::PList(std::string("multiply")) },
			{ "weapon_position_forward", oo::PList(oo::PList::Array{ oo::PList(std::string("1 0 0")), oo::PList(std::string("-1 0 0")) }) },
			{ "sun_glare_filter", oo::PList(0.5) },
			{ "script_info", oo::PList(oo::PList::Dict{ { "a", oo::PList(1) } }) },
			{ "explosion_type", oo::PList(oo::PList::Array{ oo::PList(std::string("boom")) }) },
		});
		OO_CHECK([ship cxx_setUpFromDictionary:definition]);
		const cxx::ShipEntity *part = Part(ship);
		OO_CHECK([ship cxx_shipInfoDictionary].get<std::string>("name", "") == "Viper");
		OO_CHECK([ship maxFlightSpeed] == 300.0f && [ship maxFlightRoll] == 3.0f && [ship maxFlightPitch] == 1.5f);
		OO_CHECK([ship maxFlightYaw] == 1.5f);	// yaw defaults to pitch
		OO_CHECK([ship cruiseSpeed] == 300.0f * 0.8f);
		OO_CHECK([ship maxThrust] == 20.0f && [ship thrust] == 20.0f);
		OO_CHECK([ship afterburnerFactor] == 1.0f && [ship afterburnerRate] == 0.5f);
		OO_CHECK([ship maxEnergy] == 500.0f && part->energy_recharge_rate == 4.0f);
		OO_CHECK([ship weaponFacings] == VALID_WEAPON_FACINGS);
		OO_CHECK([ship missileCapacity] == SHIPENTITY_MAX_MISSILES && part->missiles == SHIPENTITY_MAX_MISSILES);
		OO_CHECK(!part->cloakPassive && !part->isFrangible);
		OO_CHECK(part->max_cargo == 20 && [ship extraCargo] == 5);
		OO_CHECK([ship hyperspaceSpinTime] == -1);
		OO_CHECK([ship cxx_name] == std::optional<std::string>("Viper"));
		OO_CHECK([ship cxx_shipUniqueName] == std::optional<std::string>("Bob"));
		OO_CHECK([ship cxx_shipClassName] == std::optional<std::string>("Viper"));
		OO_CHECK(part->displayName == std::optional<std::string>("Police Viper"));
		OO_CHECK(part->_scaleFactor == 2.0f);
		OO_CHECK(vector_equal(part->tractor_position, make_vector(2, 4, 6)));
		OO_CHECK(part->_multiplyWeapons && part->forwardWeaponOffset.size() == 2);
		OO_CHECK(part->forwardWeaponOffset.size() == 2 && vector_equal(part->forwardWeaponOffset[1], make_vector(-2, 0, 0)));
		OO_CHECK([ship sunGlareFilter] == 0.5f);
		OO_CHECK(part->scriptInfo.get<int>("a", 0) == 1);
		OO_CHECK(part->explosionType.isArray() && part->explosionType.count() == 1);
	}
}


// --- Slice 3: -setUpShipFromDictionary:, subentity serialisation and set-up (bead oo-mvzmb) -----

// A ship that keeps ShipEntity's own set-up.
@interface PlainShip: ShipEntity
@end


@implementation PlainShip
@end


namespace {

cxx::ShipEntity *MutablePart(ShipEntity *s)	{ return s->_cxxShip; }

}	// namespace


// The NPC settings on top of the shared ones: scan class, energy, weapon damage of a missile,
// roles without "player", the escort clamp, beacons, an unpiloted ship.
OO_TEST(setUpShipFromDictionaryNPC)
{
	@autoreleasepool
	{
		SetUp();
		const oo::PList definition(oo::PList::Dict{
			{ "scan_class", oo::PList(std::string("CLASS_POLICE")) },
			{ "scan_description", oo::PList(std::string("Cop")) },
			{ "max_energy", oo::PList(300.0) },
			{ "weapon_energy", oo::PList(12.0) },
			{ "scanner_range", oo::PList(30000.0) },
			{ "fuel", oo::PList(70) },
			{ "likely_cargo", oo::PList(3) },
			{ "has_scoop_message", oo::PList(false) },
			{ "roles", oo::PList(std::string("police player")) },
			{ "accuracy", oo::PList(3.0) },
			{ "escorts", oo::PList(20) },
			{ "beacon", oo::PList(std::string("B")) },
			{ "heat_insulation", oo::PList(1.5) },
			{ "unpiloted", oo::PList(true) },
			{ "reaction_time", oo::PList(2.0) },
		});
		PlainShip *ship = [[[PlainShip alloc] cxx_initWithKey:"npc" definition:definition] autorelease];
		OO_CHECK(ship != nil);
		const cxx::ShipEntity *part = Part(ship);
		OO_CHECK([ship isShip] && [ship scanClass] == CLASS_POLICE);
		OO_CHECK(part->scan_description == std::optional<std::string>("Cop"));
		OO_CHECK([ship energy] == 300.0 && [ship maxEnergy] == 300.0f);
		OO_CHECK(part->weapon_damage == 12.0f && part->weapon_damage_override == 12.0f);
		OO_CHECK(part->scannerRange == 30000.0f && [ship fuel] == 70 && part->fuel_accumulator == 1.0f);
		OO_CHECK(part->likely_cargo == 3 && !part->hasScoopMessage);
		OO_CHECK([ship hasRole:"police"] && ![ship hasRole:"player"]);
		OO_CHECK([ship accuracy] == 3.0f);
		OO_CHECK(part->_maxEscortCount == MAX_ESCORTS && part->_pendingEscortCount == MAX_ESCORTS);
		OO_CHECK([ship beaconCode] == std::optional<std::string>("B") && [ship beaconLabel] == std::optional<std::string>("B"));
		OO_CHECK(part->_heatInsulation == 1.5f);
		OO_CHECK(part->_explicitlyUnpiloted && part->crew == std::nullopt);
		OO_CHECK(part->reactionTime == 2.0f);
		OO_CHECK(vector_equal([ship forwardVector], kBasisZVector) && vector_equal([ship upVector], kBasisYVector) && vector_equal([ship rightVector], kBasisXVector));
		OO_CHECK(part->cargo_type == CARGO_NOT_CARGO);
		OO_CHECK([ship getAI] != nil && [ship owner] == ship);
	}
}


OO_TEST(subIdxAndSerialisation)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"mother" definition:Definition()] autorelease];
		TestShip *a = [[[TestShip alloc] cxx_initWithKey:"a" definition:Definition()] autorelease];
		TestShip *b = [[[TestShip alloc] cxx_initWithKey:"b" definition:Definition()] autorelease];
		[a setSubIdx:0];
		[b setSubIdx:2];
		OO_CHECK([a subIdx] == 0 && [b subIdx] == 2);
		[ship addSubEntity:a];
		[ship addSubEntity:b];
		MutablePart(ship)->_maxShipSubIdx = 4;
		OO_CHECK([ship maxShipSubEntities] == 4);
		OO_CHECK([ship cxx_serializeShipSubEntities] == std::optional<std::string>("1010"));
		[ship cxx_deserializeShipSubEntitiesFrom:"1111"];	// every one is alive: nothing happens
		OO_CHECK([ship subEntityCount] == 2 && [a owner] == ship && [b owner] == ship);
		[ship clearSubEntities];
	}
}


// -setUpSubEntities with no exhausts or subentities: the profile radius is the collision radius,
// and the frustum radius is the profile radius (no exhaust is longer).
OO_TEST(setUpSubEntitiesAndFrustumRadius)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"bare" definition:Definition()] autorelease];
		OO_CHECK([ship cxx_setUpFromDictionary:oo::PList()]);
		MutablePart(ship)->collision_radius = 25.0f;
		OO_CHECK([ship setUpSubEntities]);
		OO_CHECK([ship maxShipSubEntities] == 0 && [ship subEntityCount] == 0);
		OO_CHECK(Part(ship)->_profileRadius == 25.0f);
		OO_CHECK([ship frustumRadius] == 25.0f);
		OO_CHECK(Part(ship)->no_draw_distance == (GLfloat)(25.0 * 25.0 * NO_DRAW_DISTANCE_FACTOR * NO_DRAW_DISTANCE_FACTOR * 2.0));
	}
}


OO_TEST_MAIN()
