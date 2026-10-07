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
#import "OOColor.h"

#include "oo_test.hpp"

#include <cmath>
#include <initializer_list>
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
void SetFrustration(ShipEntity *s, GLfloat value)	{ s->_cxxShip->frustration = value; }
void SetPlanetForLanding(ShipEntity *s, OOUniversalID uid)	{ s->_cxxShip->planetForLanding = uid; }
void SetPreviousCondition(ShipEntity *s, const oo::PList &condition)	{ s->_cxxShip->previousCondition = condition; }
unsigned NextNavpoint(ShipEntity *s)	{ return s->_cxxShip->next_navpoint_index; }

void SetPrimaryTarget(ShipEntity *s, Entity *target)
{
	[s->_cxxShip->_primaryTarget release];
	s->_cxxShip->_primaryTarget = [target weakRetain];
}

void SetNavpoints(ShipEntity *s, std::initializer_list<HPVector> points, unsigned next)
{
	unsigned n = 0;
	for (HPVector p : points)  s->_cxxShip->navpoints[n++] = p;
	s->_cxxShip->number_of_navpoints = n;
	s->_cxxShip->next_navpoint_index = next;
}

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


// --- Slice 4: standard subentities, cargo pods, descriptions, mesh, vectors, misjump, lists (oo-ln2m1)

OO_TEST(cargoTypeAndTemplatePod)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"pod" definition:Definition()] autorelease];
		OO_CHECK(![ship isTemplateCargoPod]);
		[ship setUpCargoType:"CARGO_ALLOY"];
		OO_CHECK(Part(ship)->cargo_type == CARGO_RANDOM && Part(ship)->commodity_type == std::optional<std::string>("alloys") && Part(ship)->commodity_amount == 1);
		[ship setUpCargoType:"CARGO_SCRIPTED_ITEM"];
		OO_CHECK(Part(ship)->cargo_type == CARGO_SCRIPTED_ITEM && Part(ship)->commodity_type == std::nullopt && Part(ship)->commodity_amount == 1);
		[ship setUpCargoType:"CARGO_NOT_CARGO"];
		OO_CHECK(Part(ship)->cargo_type == CARGO_NOT_CARGO);
	}
}


OO_TEST(simpleAccessors)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"acc" definition:Definition()] autorelease];
		[ship setSunGlareFilter:2.0f];
		OO_CHECK([ship sunGlareFilter] == 1.0f);
		[ship setSunGlareFilter:0.25f];
		OO_CHECK([ship sunGlareFilter] == 0.25f);

		[ship setAccuracy:20.0f];
		OO_CHECK([ship accuracy] == 10.0f);
		OO_CHECK(Part(ship)->pitch_tolerance == (GLfloat)(0.01 * (85.0f + 10.0f)) && Part(ship)->aim_tolerance == (GLfloat)(240.0 - 18.0f * 10.0f));
		OO_CHECK(Part(ship)->missile_load_time == 2.0);
		[ship setAccuracy:-9.0f];
		OO_CHECK([ship accuracy] == -5.0f);

		Quaternion q = { 0.5f, 0.5f, 0.5f, 0.5f };
		[ship setSubEntityRotationalVelocity:q];
		OO_CHECK(quaternion_equal([ship subEntityRotationalVelocity], q));

		[ship setScriptedMisjump:YES];
		[ship setScriptedMisjumpRange:0.75f];
		OO_CHECK([ship scriptedMisjump] && [ship scriptedMisjumpRange] == 0.75f);

		OO_CHECK([ship mesh] == nil && [ship octree] == nil);
		OO_CHECK([ship shipScript] == nil && [ship shipAIScript] == nil);
		[ship setAIScriptWakeTime:12.5];
		OO_CHECK([ship shipAIScriptWakeTime] == 12.5);
		[ship removeScript];
		OO_CHECK([ship shipScript] == nil);

		BoundingBox box = [ship totalBoundingBox];
		OO_CHECK(box.min.x == 0 && box.max.x == 0);
	}
}


OO_TEST(descriptions)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"desc" definition:Definition()] autorelease];
		OO_CHECK([ship cxx_setUpFromDictionary:oo::PList(oo::PList::Dict{ { "name", oo::PList(std::string("Viper")) } })]);
		OO_CHECK([ship cxx_shortDescriptionComponents] == std::optional<std::string>("\"Viper\""));
		const std::optional<std::string> desc = [ship cxx_descriptionComponents];
		OO_CHECK(desc.has_value() && desc->rfind("\"Viper\" ", 0) == 0);
	}
}


// The subentity lists, the ship / flasher / exhaust filters, and the subentity taking damage.
OO_TEST(subEntityLists)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"mother" definition:Definition()] autorelease];
		TestShip *sub = [[[TestShip alloc] cxx_initWithKey:"sub" definition:Definition()] autorelease];
		OO_CHECK([ship subEntityCount] == 0 && [ship subEntities].empty());
		[ship addSubEntity:sub];
		OO_CHECK([ship subEntityCount] == 1 && [ship hasSubEntity:sub]);
		OO_CHECK([ship subEntities].size() == 1 && [ship subEntities][0].get() == sub);
		OO_CHECK([ship subEntityEnumerator].size() == 1);
		OO_CHECK([ship cxx_shipSubEntities].size() == 1 && [ship cxx_shipSubEntities][0].get() == sub);
		OO_CHECK([ship flasherEnumerator].empty() && [ship cxx_exhausts].empty());
		[ship setSubEntityTakingDamage:sub];
		OO_CHECK([ship subEntityTakingDamage] == sub);
		[ship setSubEntityTakingDamage:ship];	// not a subentity: refused (debug builds)
#ifndef NDEBUG
		OO_CHECK([ship subEntityTakingDamage] == nil);
#endif
		[ship clearSubEntities];
		OO_CHECK([ship subEntityCount] == 0 && [sub owner] == nil);
	}
}


// --- Slice 5: bounding boxes, octree hit tests, universe add / remove, beacons, boulders (oo-ddnn8)

OO_TEST(octreeAndTractorWithoutAModel)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"nomodel" definition:Definition()] autorelease];
		OO_CHECK([ship cxx_setUpFromDictionary:oo::PList(oo::PList::Dict{ { "scoop_position", oo::PList(std::string("0 0 10")) } })]);
		OO_CHECK([ship octree] == nil && [ship volume] == 0.0f);
		OO_CHECK([ship doesHitLine:kZeroHPVector :make_HPvector(0, 0, 100)] == 0.0f);
		[ship setPosition:make_HPvector(1, 2, 3)];
		[ship setOrientation:kIdentityQuaternion];
		HPVector tractor = [ship absoluteTractorPosition];
		OO_CHECK(tractor.x == 1 && tractor.y == 2 && tractor.z == 13);
	}
}


OO_TEST(beacons)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"beacon" definition:Definition()] autorelease];
		TestShip *other = [[[TestShip alloc] cxx_initWithKey:"other" definition:Definition()] autorelease];
		OO_CHECK(![ship isBeacon] && [ship beaconCode] == std::nullopt && [ship beaconLabel] == std::nullopt);
		[ship setBeaconCode:std::string()];	// empty is none
		OO_CHECK(![ship isBeacon]);
		[ship setBeaconCode:std::string("X")];
		OO_CHECK([ship isBeacon] && [ship beaconCode] == std::optional<std::string>("X"));
		OO_CHECK([ship beaconLabel] == std::optional<std::string>("X"));	// the label defaults to the code
		[ship setBeaconLabel:std::string()];
		OO_CHECK([ship beaconLabel] == std::nullopt);
		[ship setBeaconCode:std::nullopt];
		OO_CHECK(![ship isBeacon]);

		OO_CHECK([ship nextBeacon] == nil && [ship prevBeacon] == nil);
		[ship setNextBeacon:other];
		[ship setPrevBeacon:other];
		OO_CHECK([ship nextBeacon] == other && [ship prevBeacon] == other);
		[ship setNextBeacon:nil];
		OO_CHECK([ship nextBeacon] == nil && [ship prevBeacon] == other);
	}
}


OO_TEST(visibilityBouldersAndKills)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"rock" definition:Definition()] autorelease];
		OO_CHECK([ship cxx_setUpFromDictionary:oo::PList()]);
		MutablePart(ship)->no_draw_distance = 100.0f;
		MutablePart(ship)->cam_zero_distance = 50.0f;
		OO_CHECK([ship isVisible]);
		MutablePart(ship)->cam_zero_distance = 150.0f;
		OO_CHECK(![ship isVisible]);

		OO_CHECK(![ship isBoulder] && ![ship isMinable]);
		[ship setIsBoulder:YES];
		OO_CHECK([ship isBoulder] && [ship isMinable]);
		MutablePart(ship)->noRocks = 1;
		OO_CHECK(![ship isMinable]);
		[ship setIsBoulder:NO];
		OO_CHECK(![ship isBoulder]);

		OO_CHECK([ship countsAsKill]);
		OO_CHECK([ship cxx_setUpFromDictionary:oo::PList(oo::PList::Dict{ { "counts_as_kill", oo::PList(false) } })]);
		OO_CHECK(![ship countsAsKill]);
	}
}


// --- Slice 6: ship data key, weapon offsets, collision checks, subentity geometry (oo-5z5wd) --------

OO_TEST(shipDataKeyAndInfo)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"keyed" definition:Definition()] autorelease];
		OO_CHECK([ship cxx_shipDataKey] == std::optional<std::string>("keyed"));
		OO_CHECK([ship cxx_shipDataKeyAutoRole] == std::optional<std::string>("[keyed]"));
		[ship cxx_setShipDataKey:std::nullopt];
		OO_CHECK([ship cxx_shipDataKey] == std::nullopt && [ship cxx_shipDataKeyAutoRole] == std::optional<std::string>("[(null)]"));
		OO_CHECK([ship cxx_shipInfoDictionary].isNull());	// the test ship's set-up kept none
		OO_CHECK([ship cxx_setUpFromDictionary:oo::PList(oo::PList::Dict{
			{ "frangible", oo::PList(false) },
			{ "model_scale_factor", oo::PList(2.0) },
			{ "weapon_position_aft", oo::PList(std::string("0 0 -5")) },
		})]);
		OO_CHECK([ship cxx_shipInfoDictionary].get<bool>("frangible", true) == false);
		OO_CHECK(![ship isFrangible]);
		OO_CHECK([ship cxx_aftWeaponOffset].size() == 1 && vector_equal([ship cxx_aftWeaponOffset][0], make_vector(0, 0, -10)));
		OO_CHECK([ship cxx_forwardWeaponOffset].size() == 1 && vector_equal([ship cxx_forwardWeaponOffset][0], kZeroVector));
		OO_CHECK([ship cxx_portWeaponOffset].size() == 1 && [ship cxx_starboardWeaponOffset].size() == 1);

		// The modes: "single" is one scaled vector; otherwise an array of them, or one zero vector.
		const oo::PList mounts(oo::PList::Dict{ { "k", oo::PList(oo::PList::Array{ oo::PList(std::string("1 0 0")), oo::PList(std::string("0 1 0")) }) } });
		const std::vector<Vector> multi = [ship cxx_weaponOffsetsFrom:mounts withKey:"k" inMode:"multiply"];
		OO_CHECK(multi.size() == 2 && vector_equal(multi[1], make_vector(0, 2, 0)));
		const std::vector<Vector> none = [ship cxx_weaponOffsetsFrom:mounts withKey:"absent" inMode:"multiply"];
		OO_CHECK(none.size() == 1 && vector_equal(none[0], kZeroVector));
	}
}


OO_TEST(scanClassAndCollisionFlags)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"flags" definition:Definition()] autorelease];
		[ship setScanClass:CLASS_NEUTRAL];
		OO_CHECK([ship scanClass] == CLASS_NEUTRAL);
		MutablePart(ship)->cloaking_device_active = 1;
		OO_CHECK([ship scanClass] == CLASS_NO_DRAW);
		MutablePart(ship)->cloaking_device_active = 0;

		OO_CHECK(![ship suppressFlightNotifications]);
		MutablePart(ship)->suppressAegisMessages = 1;
		OO_CHECK([ship suppressFlightNotifications]);

		OO_CHECK([ship status] == STATUS_IN_FLIGHT && [ship canCollide]);
		MutablePart(ship)->isWreckage = 1;
		OO_CHECK(![ship canCollide]);
		MutablePart(ship)->isWreckage = 0;
		[ship setStatus:STATUS_DEAD];
		OO_CHECK(![ship canCollide]);
		[ship setStatus:STATUS_IN_FLIGHT];
		OO_CHECK([ship canCollide]);
	}
}


// -checkCloseCollisionWith: nil, an entity already colliding, a plain entity (a collision), and a
// ship (the octrees decide; with no model, no collision). -absoluteIJKForSubentity of a free ship is
// its frame.
OO_TEST(closeCollisionAndFrame)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"hull" definition:Definition()] autorelease];
		TestShip *other = [[[TestShip alloc] cxx_initWithKey:"other" definition:Definition()] autorelease];
		Entity *plain = [[[Entity alloc] init] autorelease];
		OO_CHECK(![ship checkCloseCollisionWith:nil]);
		OO_CHECK([ship checkCloseCollisionWith:plain] && Part(ship)->collider == plain);
		MutablePart(ship)->collider = nil;
		OO_CHECK(![ship checkCloseCollisionWith:other] && Part(ship)->collider == nil);

		[ship setOrientation:kIdentityQuaternion];
		Triangle ijk = [ship absoluteIJKForSubentity];
		OO_CHECK(vector_equal(ijk.v[0], kBasisXVector) && vector_equal(ijk.v[1], kBasisYVector) && vector_equal(ijk.v[2], kBasisZVector));
	}
}


// --- Slice 7: -update: (bead oo-k2q1f) -------------------------------------------------------------

// A ship whose -update: only counts: a subentity that a demo ship updates.
@interface CountingShip: TestShip
{
@public
	int		_updates;
}
@end


@implementation CountingShip

- (void) update:(OOTimeDelta)delta_t
{
	_updates++;
}

@end


// A demo ship (the ship library's) turns at its demo rate, has its subentities updated, and has an
// infinite top speed clamped first.
OO_TEST(updateDemoShip)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"demo" definition:Definition()] autorelease];
		CountingShip *sub = [[[CountingShip alloc] cxx_initWithKey:"sub" definition:Definition()] autorelease];
		OO_CHECK([ship cxx_setUpFromDictionary:oo::PList()]);
		[ship addSubEntity:sub];
		MutablePart(ship)->isDemoShip = YES;
		MutablePart(ship)->demoRate = 0;
		[ship setMaxFlightSpeed:INFINITY];
		[ship update:0.1];
		OO_CHECK([ship maxFlightSpeed] == 300.0f);
		OO_CHECK(sub->_updates == 1);
		[ship clearSubEntities];
	}
}


// From C++, update() reaches an Objective-C subclass's override (the root's adapter line).
OO_TEST(updateReachesTheSubclass)
{
	@autoreleasepool
	{
		SetUp();
		CountingShip *ship = [[[CountingShip alloc] cxx_initWithKey:"counted" definition:Definition()] autorelease];
		cxx::Entity *part = oo::ToCxx(static_cast<Entity *>(ship));
		part->update(0.1);
		OO_CHECK(ship->_updates == 1);
	}
}


// --- Slice 8: behaviour dispatch, attack response, equipment queries (bead oo-vxdsc) ---------------

// The equipment queries over the ship's equipment keys (no equipment data is loaded, so no type is
// known: a key provides only itself).
OO_TEST(equipmentQueries)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"kit" definition:Definition()] autorelease];
		OO_CHECK(![ship hasEquipmentItem:oo::PList(std::string("EQ_A"))]);
		OO_CHECK(![ship hasAllEquipment:oo::PList(std::string("EQ_A"))]);	// none at all
		MutablePart(ship)->_equipment = { "EQ_A", "EQ_B_DAMAGED", "EQ_A" };
		OO_CHECK([ship cxx_countEquipmentItem:"EQ_A"] == 2 && [ship cxx_countEquipmentItem:"EQ_B"] == 0);
		OO_CHECK([ship cxx_hasOneEquipmentItem:"EQ_A" includeWeapons:NO whileLoading:NO]);
		OO_CHECK(![ship cxx_hasOneEquipmentItem:"EQ_B" includeWeapons:NO whileLoading:NO]);
		OO_CHECK([ship cxx_hasOneEquipmentItem:"EQ_B" includeWeapons:NO whileLoading:YES]);	// damaged counts while loading
		OO_CHECK([ship cxx_hasOneEquipmentItem:"EQ_B" includeMissiles:NO whileLoading:YES]);
		OO_CHECK(![ship cxx_hasOneEquipmentItem:"EQ_C" includeMissiles:YES whileLoading:NO]);
		OO_CHECK([ship hasEquipmentItem:oo::PList(std::string("EQ_A"))]);
		OO_CHECK([ship hasEquipmentItem:oo::PList(oo::PList::Array{ oo::PList(std::string("EQ_X")), oo::PList(std::string("EQ_A")) })]);
		OO_CHECK(![ship hasEquipmentItem:oo::PList(oo::PList::Array{ oo::PList(std::string("EQ_X")), oo::PList(1) })]);
		OO_CHECK([ship hasAllEquipment:oo::PList(oo::PList::Array{ oo::PList(std::string("EQ_A")) })]);
		OO_CHECK(![ship hasAllEquipment:oo::PList(oo::PList::Array{ oo::PList(std::string("EQ_A")), oo::PList(std::string("EQ_B")) })]);
		OO_CHECK([ship hasAllEquipment:oo::PList(oo::PList::Array{ oo::PList(std::string("EQ_A")), oo::PList(std::string("EQ_B")) }) includeWeapons:NO whileLoading:YES]);
		OO_CHECK(![ship hasAllEquipment:oo::PList(oo::PList::Array{ oo::PList(std::string("EQ_A")), oo::PList(2) })]);
		OO_CHECK([ship cxx_hasEquipmentItemProviding:"EQ_A"] && ![ship cxx_hasEquipmentItemProviding:"EQ_Z"]);
		OO_CHECK([ship cxx_equipmentItemProviding:"EQ_A"] == std::optional<std::string>("EQ_A"));
		OO_CHECK([ship cxx_equipmentItemProviding:"EQ_Z"] == std::nullopt);
		OO_CHECK(![ship hasPrimaryWeapon:nil]);
	}
}


OO_TEST(hyperspaceMotor)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"motor" definition:Definition()] autorelease];
		[ship setHyperspaceSpinTime:12.0f];
		OO_CHECK([ship hyperspaceSpinTime] == 12.0f && [ship hasHyperspaceMotor]);
		[ship setHyperspaceSpinTime:-1.0f];
		OO_CHECK(![ship hasHyperspaceMotor]);
	}
}


// --- Slice 9: equipment validity and adding, weapon mounts, scripting lists (bead oo-ke13m) ---------

OO_TEST(weaponMountsAndLists)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"mounts" definition:Definition()] autorelease];
		OO_CHECK([ship cxx_setUpFromDictionary:oo::PList(oo::PList::Dict{ { "weapon_facings", oo::PList(WEAPON_FACING_FORWARD | WEAPON_FACING_AFT) } })]);
		OO_CHECK([ship weaponFacings] == (WEAPON_FACING_FORWARD | WEAPON_FACING_AFT));
		// No weapon data is loaded: every mount is empty, and a facing the ship lacks has nothing.
		OO_CHECK(isWeaponNone([ship weaponTypeIDForFacing:WEAPON_FACING_FORWARD strict:YES]));
		OO_CHECK([ship weaponTypeIDForFacing:WEAPON_FACING_PORT strict:NO] == nil);
		OO_CHECK([ship weaponTypeForFacing:WEAPON_FACING_STARBOARD strict:NO] == nil);
		OO_CHECK([ship missilesList].empty());
		const oo::PList passengers = [ship passengerListForScripting];
		OO_CHECK(passengers.isArray() && passengers.count() == 0);
		OO_CHECK([ship parcelListForScripting].isArray() && [ship contractListForScripting].isArray());
	}
}


OO_TEST(equipmentKeysAndUnknownEquipment)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"keys" definition:Definition()] autorelease];
		OO_CHECK([ship cxx_equipmentKeys].empty() && [ship equipmentCount] == 0);
		MutablePart(ship)->_equipment = { "EQ_A", "EQ_B" };
		OO_CHECK([ship cxx_equipmentKeys] == std::vector<std::string>({ "EQ_A", "EQ_B" }) && [ship equipmentCount] == 2);
		// An equipment key with no equipment type is never valid, and is not added.
		OO_CHECK(![ship cxx_equipmentValidToAdd:"EQ_UNKNOWN" inContext:"npc"]);
		OO_CHECK(![ship canAddEquipment:"EQ_UNKNOWN" inContext:"npc"]);
		OO_CHECK(![ship addEquipmentItem:"EQ_UNKNOWN" inContext:"npc"]);
		OO_CHECK([ship equipmentCount] == 2);
	}
}


// --- Slice 10: equipment removal, missiles, capacities, has-equipment predicates, shields (oo-wvcs2)

OO_TEST(capacitiesAndPredicates)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"preds" definition:Definition()] autorelease];
		OO_CHECK([ship cxx_setUpFromDictionary:oo::PList(oo::PList::Dict{
			{ "missiles", oo::PList(2) }, { "max_missiles", oo::PList(4) }, { "extra_cargo", oo::PList(7) } })]);
		OO_CHECK([ship missileCount] == 2 && [ship missileCapacity] == 4 && [ship extraCargo] == 7);
		OO_CHECK([ship parcelCount] == 0 && [ship passengerCount] == 0 && [ship passengerCapacity] == 0);
		OO_CHECK([ship maxHyperspaceDistance] == MAX_JUMP_RANGE);

		OO_CHECK(![ship hasScoop] && ![ship hasECM] && ![ship hasShieldBooster] && ![ship hasEscapePod]);
		OO_CHECK([ship shieldBoostFactor] == 1.0f && [ship shieldRechargeRate] == 2.0f);
		OO_CHECK([ship maxForwardShieldLevel] == BASELINE_SHIELD_LEVEL && [ship maxAftShieldLevel] == BASELINE_SHIELD_LEVEL);

		// Each predicate is "some equipment provides the key" (a key provides itself).
		MutablePart(ship)->_equipment = { "EQ_FUEL_SCOOPS", "EQ_ECM", "EQ_SHIELD_BOOSTER", "EQ_NAVAL_SHIELD_BOOSTER",
			"EQ_CLOAKING_DEVICE", "EQ_MILITARY_SCANNER_FILTER", "EQ_MILITARY_JAMMER", "EQ_CARGO_BAY", "EQ_HEAT_SHIELD",
			"EQ_FUEL_INJECTION", "EQ_QC_MINE", "EQ_ESCAPE_POD", "EQ_DOCK_COMP", "EQ_GAL_DRIVE" };
		OO_CHECK([ship hasScoop] && [ship hasFuelScoop] && ![ship hasCargoScoop]);
		OO_CHECK([ship hasECM] && [ship hasCloakingDevice] && [ship hasMilitaryScannerFilter] && [ship hasMilitaryJammer]);
		OO_CHECK([ship hasExpandedCargoBay] && [ship hasShieldBooster] && [ship hasMilitaryShieldEnhancer]);
		OO_CHECK([ship hasHeatShield] && [ship hasFuelInjection] && [ship hasEscapePod] && [ship hasCascadeMine]);
		OO_CHECK([ship hasDockingComputer] && [ship hasGalacticHyperdrive]);
		OO_CHECK([ship shieldBoostFactor] == 3.0f && [ship shieldRechargeRate] == 3.0f);
		OO_CHECK([ship maxForwardShieldLevel] == BASELINE_SHIELD_LEVEL * 3.0f);

		// An unknown equipment type is not removed; -removeAllEquipment clears the keys.
		[ship removeEquipmentItem:"EQ_ECM"];
		OO_CHECK([ship hasECM]);
		[ship removeAllEquipment];
		OO_CHECK([ship equipmentCount] == 0 && ![ship hasECM]);
	}
}


OO_TEST(removeMissiles)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"launcher" definition:Definition()] autorelease];
		OO_CHECK([ship removeMissiles] == 0 && [ship missileCount] == 0);
	}
}


// --- Slice 11: thrust and afterburner; idle, tumble, tractored, track, intercept, dogfight (oo-eh955)

OO_TEST(thrustAndAfterburner)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"burner" definition:Definition()] autorelease];
		[ship setAfterburnerFactor:4.0f];
		[ship setAfterburnerRate:0.5f];
		[ship setMaxThrust:30.0f];
		OO_CHECK([ship afterburnerFactor] == 4.0f && [ship afterburnerRate] == 0.5f && [ship maxThrust] == 30.0f);
		OO_CHECK([ship thrust] == 0.0f);	// the thrust itself is the set-up's, not -setMaxThrust:'s
	}
}


// -behaviour_stop_still: and -behaviour_idle: centre the sticks (a buoy keeps rolling), and the
// sticks move the flight controls at their rate (-applySticks:).
OO_TEST(behaviourStopStillAndIdle)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"still" definition:Definition()] autorelease];
		MutablePart(ship)->flightRoll = 1.0f;
		MutablePart(ship)->stick_roll = 1.0f;
		MutablePart(ship)->stick_pitch = 1.0f;
		[ship behaviour_stop_still:0.1];
		OO_CHECK(Part(ship)->stick_roll == 0 && Part(ship)->stick_pitch == 0 && Part(ship)->stick_yaw == 0);
		OO_CHECK(fabs(Part(ship)->flightRoll - 0.8f) < 1e-5f);

		[ship setScanClass:CLASS_BUOY];
		MutablePart(ship)->flightRoll = 0.5f;
		MutablePart(ship)->flightPitch = 0.25f;
		[ship behaviour_idle:0.1];
		OO_CHECK(Part(ship)->stick_roll == 0.5f && Part(ship)->stick_pitch == 0.25f && Part(ship)->stick_yaw == 0);
		OO_CHECK(Part(ship)->flightRoll == 0.5f && Part(ship)->flightPitch == 0.25f);

		[ship setScanClass:CLASS_NEUTRAL];
		[ship behaviour_idle:0.1];
		OO_CHECK(Part(ship)->stick_roll == 0 && Part(ship)->stick_pitch == 0);

		MutablePart(ship)->stick_roll = 0.5f;
		MutablePart(ship)->flightRoll = 0.0f;
		[ship behaviour_tumble:0.1];	// the sticks as they are
		OO_CHECK(Part(ship)->stick_roll == 0.5f && fabs(Part(ship)->flightRoll - 0.2f) < 1e-5f);
	}
}


// Behaviours that need a target, with none: the ship notes the lost target and goes idle.
OO_TEST(behavioursWithoutATarget)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"hunter" definition:Definition()] autorelease];
		MutablePart(ship)->behaviour = BEHAVIOUR_ATTACK_SLOW_DOGFIGHT;
		[ship behaviour_attack_slow_dogfight:0.1];
		OO_CHECK(Part(ship)->behaviour == BEHAVIOUR_IDLE);
		MutablePart(ship)->behaviour = BEHAVIOUR_ATTACK_BREAK_OFF_TARGET;
		[ship behaviour_attack_break_off_target:0.1];
		OO_CHECK(Part(ship)->behaviour == BEHAVIOUR_IDLE);
	}
}


// --- Slice 12: behaviours: attack target, broadside, close with target (bead oo-0akes) --------------

// With no target the attack behaviours note the lost target and go idle.
OO_TEST(attackBehavioursWithoutATarget)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"attacker" definition:Definition()] autorelease];
		MutablePart(ship)->behaviour = BEHAVIOUR_ATTACK_BROADSIDE;
		[ship behaviour_attack_broadside:0.1];
		OO_CHECK(Part(ship)->behaviour == BEHAVIOUR_IDLE);
		MutablePart(ship)->behaviour = BEHAVIOUR_ATTACK_BROADSIDE_LEFT;
		[ship behaviour_attack_broadside_left:0.1];
		OO_CHECK(Part(ship)->behaviour == BEHAVIOUR_IDLE);
		MutablePart(ship)->behaviour = BEHAVIOUR_ATTACK_BROADSIDE_RIGHT;
		[ship behaviour_attack_broadside_right:0.1];
		OO_CHECK(Part(ship)->behaviour == BEHAVIOUR_IDLE);
		MutablePart(ship)->behaviour = BEHAVIOUR_CLOSE_TO_BROADSIDE_RANGE;
		[ship behaviour_close_to_broadside_range:0.1];
		OO_CHECK(Part(ship)->behaviour == BEHAVIOUR_IDLE);
		MutablePart(ship)->behaviour = BEHAVIOUR_CLOSE_WITH_TARGET;
		[ship behaviour_close_with_target:0.1];
		OO_CHECK(Part(ship)->behaviour == BEHAVIOUR_IDLE);
	}
}


// -behaviour_attack_target: chooses the next attack behaviour: an unarmed ship (no weapon on any
// mount or subentity) flies from its target, and the choice resets the ship's frustration. The
// broadside on either side, with no target, notes the lost target and goes idle.
OO_TEST(attackTargetChoiceAndBroadsideSides)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = [[[TestShip alloc] cxx_initWithKey:"unarmed" definition:Definition()] autorelease];
		MutablePart(ship)->behaviour = BEHAVIOUR_ATTACK_TARGET;
		MutablePart(ship)->frustration = 5.0f;
		[ship behaviour_attack_target:0.1];
		OO_CHECK(Part(ship)->behaviour == BEHAVIOUR_ATTACK_FLY_FROM_TARGET);
		OO_CHECK(Part(ship)->frustration == 0.0f);

		MutablePart(ship)->behaviour = BEHAVIOUR_ATTACK_BROADSIDE_LEFT;
		[ship behaviour_attack_broadside_target:0.1 leftside:YES];
		OO_CHECK(Part(ship)->behaviour == BEHAVIOUR_IDLE);
		MutablePart(ship)->behaviour = BEHAVIOUR_ATTACK_BROADSIDE_RIGHT;
		[ship behaviour_attack_broadside_target:0.1 leftside:NO];
		OO_CHECK(Part(ship)->behaviour == BEHAVIOUR_IDLE);
	}
}


// --- Slices 13-15: the behaviours (the expectations were run on the Objective-C methods first) ----

namespace {

// A ship in flight at the origin, with a top speed and a scanner, and nothing else.
TestShip *FlyingShip(const char *key)
{
	TestShip *ship = [[[TestShip alloc] cxx_initWithKey:key definition:Definition()] autorelease];
	[ship setMaxFlightSpeed:200];
	[ship setScannerRange:25600];
	[ship setPosition:kZeroHPVector];
	return ship;
}


// A ship the first one targets, at (0, 0, z).
// (Not -addTarget:, which tells the ship's scripts, and a ship has no JavaScript object here.)
TestShip *TargetAt(TestShip *ship, double z)
{
	TestShip *target = FlyingShip("target");
	[target setPosition:make_HPvector(0, 0, z)];
	SetPrimaryTarget(ship, target);
	return target;
}

}	// namespace


// Slices 13 and 14: an attack behaviour with no target to track notes the lost target and goes idle.
OO_TEST(attackBehavioursWithoutATargetGoIdle)
{
	@autoreleasepool
	{
		SetUp();
		const struct { OOBehaviour behaviour; void (*run)(TestShip *); } cases[] =
		{
			{ BEHAVIOUR_ATTACK_SNIPER, [](TestShip *s) { [s behaviour_attack_sniper:0.1]; } },
			{ BEHAVIOUR_ATTACK_FLY_TO_TARGET_SIX, [](TestShip *s) { [s behaviour_fly_to_target_six:0.1]; } },
			{ BEHAVIOUR_ATTACK_MINING_TARGET, [](TestShip *s) { [s behaviour_attack_mining_target:0.1]; } },
			{ BEHAVIOUR_ATTACK_FLY_TO_TARGET, [](TestShip *s) { [s behaviour_attack_fly_to_target:0.1]; } },
			{ BEHAVIOUR_ATTACK_FLY_FROM_TARGET, [](TestShip *s) { [s behaviour_attack_fly_from_target:0.1]; } },
			{ BEHAVIOUR_RUNNING_DEFENSE, [](TestShip *s) { [s behaviour_running_defense:0.1]; } },
			{ BEHAVIOUR_FLEE_TARGET, [](TestShip *s) { [s behaviour_flee_target:0.1]; } },
		};
		for (const auto &c : cases)
		{
			TestShip *ship = FlyingShip("lonely");
			[ship setBehaviour:c.behaviour];
			SetFrustration(ship, 2);
			c.run(ship);
			OO_CHECK(Behaviour(ship) == BEHAVIOUR_IDLE && [ship frustration] == 0);
		}

		// The miner also slows to three eighths of its top speed.
		TestShip *miner = FlyingShip("miner");
		[miner behaviour_attack_mining_target:0.1];
		OO_CHECK([miner desiredSpeed] == 200 * 0.375);
	}
}


// Slice 13: the sniper closes in to attack inside 15 km, and outside it flies at top speed while
// out of weapon range.
OO_TEST(sniper)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = FlyingShip("sniper");
		TargetAt(ship, 1000);
		[ship setBehaviour:BEHAVIOUR_ATTACK_SNIPER];
		[ship behaviour_attack_sniper:0.1];
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_ATTACK_TARGET);

		TestShip *distant = FlyingShip("distant sniper");
		TargetAt(distant, 20000);
		[distant setBehaviour:BEHAVIOUR_ATTACK_SNIPER];
		[distant behaviour_attack_sniper:0.1];
		OO_CHECK(Behaviour(distant) == BEHAVIOUR_ATTACK_SNIPER && [distant desiredSpeed] == 200);
	}
}


// Slice 13: a ship already at the point it was heading for vectors in to attack at 0.4 of its top
// speed (the target is at a standstill); the miner closes on a rock at seven eighths of it; and an
// attacker inside its weapon range starts its attack run.
OO_TEST(attackApproaches)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *six = FlyingShip("six");
		TargetAt(six, 2000);
		[six setBehaviour:BEHAVIOUR_ATTACK_FLY_TO_TARGET_SIX];
		[six behaviour_fly_to_target_six:0.1];
		OO_CHECK(Behaviour(six) == BEHAVIOUR_ATTACK_FLY_TO_TARGET && [six desiredSpeed] == 200 * 0.4);

		TestShip *miner = FlyingShip("miner");
		TargetAt(miner, 2000);
		[miner setBehaviour:BEHAVIOUR_ATTACK_MINING_TARGET];
		[miner behaviour_attack_mining_target:0.1];
		OO_CHECK(Behaviour(miner) == BEHAVIOUR_ATTACK_MINING_TARGET && [miner desiredSpeed] == 200 * 0.875);

		TestShip *attacker = FlyingShip("attacker");
		TargetAt(attacker, 1000);
		[attacker setWeaponRange:30000];
		[attacker setBehaviour:BEHAVIOUR_ATTACK_FLY_TO_TARGET];
		[attacker behaviour_attack_fly_to_target:0.1];
		OO_CHECK(Behaviour(attacker) == BEHAVIOUR_ATTACK_TARGET);
	}
}


// Slice 14: the destination behaviours that only decide.
OO_TEST(destinationDecisions)
{
	@autoreleasepool
	{
		SetUp();
		// Inside the range it should keep: fly away from the destination, at least at top speed.
		TestShip *ship = FlyingShip("ranger");
		[ship setDestination:make_HPvector(0, 0, 100)];
		[ship setDesiredRange:500];
		[ship setDesiredSpeed:10];
		SetFrustration(ship, 3);
		[ship behaviour_fly_range_from_destination:0.1];
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_FLY_FROM_DESTINATION && [ship desiredSpeed] == 200 && [ship frustration] == 0);

		// Outside it: fly to the destination.
		[ship setDesiredRange:50];
		[ship behaviour_fly_range_from_destination:0.1];
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_FLY_TO_DESTINATION);

		// Facing a destination stops the ship.
		TestShip *facer = FlyingShip("facer");
		[facer setDestination:make_HPvector(0, 1000, 0)];
		[facer setDesiredSpeed:50];
		[facer setBehaviour:BEHAVIOUR_FACE_DESTINATION];
		[facer behaviour_face_destination:0.1];
		OO_CHECK([facer desiredSpeed] == 0);

		// Landing with no planet to land on: idle, and the JS AI is woken to reconsider.
		TestShip *lander = FlyingShip("lander");
		SetPlanetForLanding(lander, NO_TARGET);
		[lander setBehaviour:BEHAVIOUR_LAND_ON_PLANET];
		[lander behaviour_land_on_planet:0.1];
		OO_CHECK(Behaviour(lander) == BEHAVIOUR_IDLE && [lander shipAIScriptWakeTime] == 1 && [lander desiredSpeed] == 0);

		// Forming up with no leader: top speed.
		TestShip *escort = FlyingShip("escort");
		[escort setDestination:make_HPvector(0, 0, 3000)];
		[escort setBehaviour:BEHAVIOUR_FORMATION_FORM_UP];
		[escort behaviour_formation_form_up:0.1];
		OO_CHECK([escort desiredSpeed] == 200);
	}
}


// Slice 15: arriving, leaving, resuming after a proximity alert, and the navpoints.
OO_TEST(destinationArrivals)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = FlyingShip("arriving");
		[ship setDestination:make_HPvector(0, 0, 10)];
		[ship setDesiredRange:100];
		[ship setDesiredSpeed:50];
		SetFrustration(ship, 3);
		[ship setBehaviour:BEHAVIOUR_FLY_TO_DESTINATION];
		[ship behaviour_fly_to_destination:0.1];
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_IDLE && [ship desiredSpeed] == 0 && [ship frustration] == 0);

		TestShip *leaving = FlyingShip("leaving");
		[leaving setDestination:make_HPvector(0, 0, 1000)];
		[leaving setDesiredRange:100];
		[leaving setDesiredSpeed:50];
		[leaving setBehaviour:BEHAVIOUR_FLY_FROM_DESTINATION];
		[leaving behaviour_fly_from_destination:0.1];
		OO_CHECK(Behaviour(leaving) == BEHAVIOUR_IDLE && [leaving desiredSpeed] == 0);

		// Clear of the obstacle: what the ship did before the alert resumes.
		TestShip *avoider = FlyingShip("avoider");
		[avoider setDestination:make_HPvector(0, 0, 1000)];
		[avoider setDesiredRange:100];
		[avoider setBehaviour:BEHAVIOUR_AVOID_COLLISION];
		SetFrustration(avoider, 3);
		SetPreviousCondition(avoider, oo::PList(oo::PList::Dict{
			{ "behaviour", oo::PList((double)BEHAVIOUR_FLY_TO_DESTINATION) },
			{ "desired_range", oo::PList(300.0) },
			{ "desired_speed", oo::PList(12.0) } }));
		[avoider behaviour_avoid_collision:0.1];
		OO_CHECK(Behaviour(avoider) == BEHAVIOUR_FLY_TO_DESTINATION && [avoider desiredRange] == 300 && [avoider desiredSpeed] == 12 && [avoider frustration] == 0);

		// A turret with no mount and no targets does nothing.
		TestShip *turret = FlyingShip("turret");
		[turret setBehaviour:BEHAVIOUR_TRACK_AS_TURRET];
		[turret behaviour_track_as_turret:0.1];
		OO_CHECK(Behaviour(turret) == BEHAVIOUR_TRACK_AS_TURRET);

		// Reaching a navpoint moves on to the next; reaching the last one is the end of the route.
		TestShip *nav = FlyingShip("navigator");
		[nav setDesiredRange:50];
		[nav setBehaviour:BEHAVIOUR_FLY_THRU_NAVPOINTS];
		SetNavpoints(nav, { make_HPvector(0, 0, 10), make_HPvector(0, 0, 5000), make_HPvector(0, 5000, 5000) }, 0);
		[nav behaviour_fly_thru_navpoints:0.1];
		OO_CHECK(NextNavpoint(nav) == 1 && Behaviour(nav) == BEHAVIOUR_FLY_THRU_NAVPOINTS);
		SetNavpoints(nav, { make_HPvector(0, 5000, 5000), make_HPvector(0, 0, 10) }, 1);
		[nav behaviour_fly_thru_navpoints:0.1];
		OO_CHECK(NextNavpoint(nav) == 0 && Behaviour(nav) == BEHAVIOUR_IDLE);
	}
}


// Slice 15: a scripted AI with no ship script reverts to idle; the reaction time, and the target
// position it leads by.
OO_TEST(scriptedAIAndReactionTime)
{
	@autoreleasepool
	{
		SetUp();
		TestShip *ship = FlyingShip("scripted");
		[ship setBehaviour:BEHAVIOUR_SCRIPTED_AI];
		[ship behaviour_scripted_ai:0.1];
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_IDLE);

		OO_CHECK([ship reactionTime] == 0);
		[ship setReactionTime:0.75f];
		OO_CHECK([ship reactionTime] == 0.75f);

		OO_CHECK(HPvector_equal([ship calculateTargetPosition], kZeroHPVector));		// no target
		TestShip *hunter = FlyingShip("hunter");
		TargetAt(hunter, 1234);
		OO_CHECK(HPvector_equal([hunter calculateTargetPosition], make_HPvector(0, 0, 1234)));	// no reaction time: where it is
	}
}


OO_TEST_MAIN()
