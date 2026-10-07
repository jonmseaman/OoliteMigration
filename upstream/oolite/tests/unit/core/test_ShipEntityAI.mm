/*	test_ShipEntityAI.mm
	Unit tests for ShipEntityAI.mm, the legacy plist-AI surface of ShipEntity: its slices
	(docs/phases/3-slices/ShipEntityAI.md, beads oo-iebuz, oo-xurzn, oo-wc9o3, oo-lqyhf) move the
	categories' methods into cxx::ShipEntity members, defined in the category's file, and leave
	forwarders on the Objective-C ShipEntity facade (proposed ADR-0056, amendments oo-o89 item 4 and
	oo-mvzmb).

	As test_ShipEntity's, the ship's object needs the game graph, so the test links the whole game
	but main (['*']) and uses a Universe that was never initialised (no entities, so every scan finds
	nothing), a plain entity as PLAYER and an empty JavaScript context. Its ships have no AI and are
	invisible to scripts, so the AI messages and script events the methods send go nowhere. Each
	slice adds its cases under a comment naming it, written against the Objective-C API and run on
	the unconverted class first. Ivars go through the helpers below.
	Run: bash tools/check-core-tests.sh test_ShipEntityAI
*/

#import "ShipEntity.h"
#import "ShipEntityAI.h"
#import "StationEntity.h"
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


@interface TestAIPlayer: Entity
@end


@implementation TestAIPlayer

- (HPVector) viewpointPosition	{ return kZeroHPVector; }

@end


// The private categories of ShipEntityAI.mm.
@interface ShipEntity (TestAIPrivate)
- (void) checkFoundTarget;
- (BOOL) performHyperSpaceExitReplace:(BOOL)replace;
- (BOOL) performHyperSpaceExitReplace:(BOOL)replace toSystem:(OOSystemID)systemID;
- (void) scanForNearestShipWithPredicate:(EntityFilterPredicate)predicate parameter:(void *)parameter;
- (void) scanForNearestShipWithNegatedPredicate:(EntityFilterPredicate)predicate parameter:(void *)parameter;
- (void) acceptDistressMessageFrom:(ShipEntity *)other;
- (void) performBuoyTumble;	// defined by the AI category, declared nowhere
@end


// A ship whose set-up from shipdata does nothing, and that scripts cannot see.
@interface TestAIShip: ShipEntity
@end


@implementation TestAIShip

- (BOOL) setUpShipFromDictionary:(const oo::PList &)dict	{ return YES; }
- (BOOL) isVisibleToScripts	{ return NO; }

@end


// A station whose virtual dock is not made (the dock is a shipdata entry), invisible to scripts.
@interface TestAIStation: StationEntity
@end


@implementation TestAIStation

- (BOOL) cxx_setUpOneStandardSubentity:(const oo::PList &)subentDict asTurret:(BOOL)asTurret	{ return YES; }
- (BOOL) isVisibleToScripts	{ return NO; }

@end


namespace {

OOBehaviour Behaviour(ShipEntity *s)			{ return s->_cxxShip->behaviour; }
void SetBehaviour(ShipEntity *s, OOBehaviour b)	{ s->_cxxShip->behaviour = b; }
GLfloat Frustration(ShipEntity *s)				{ return s->_cxxShip->frustration; }
void SetFrustration(ShipEntity *s, GLfloat f)	{ s->_cxxShip->frustration = f; }
GLfloat DesiredSpeed(ShipEntity *s)				{ return s->_cxxShip->desired_speed; }
void SetDesiredSpeed(ShipEntity *s, GLfloat v)	{ s->_cxxShip->desired_speed = v; }
GLfloat DesiredRange(ShipEntity *s)				{ return s->_cxxShip->desired_range; }
GLfloat StickRoll(ShipEntity *s)				{ return s->_cxxShip->stick_roll; }
GLfloat StickPitch(ShipEntity *s)				{ return s->_cxxShip->stick_pitch; }
void SetMaxFlight(ShipEntity *s, GLfloat speed, GLfloat roll, GLfloat pitch)	{ s->_cxxShip->maxFlightSpeed = speed; s->_cxxShip->max_flight_roll = roll; s->_cxxShip->max_flight_pitch = pitch; }
HPVector Destination(ShipEntity *s)				{ return s->_cxxShip->_destination; }
bool MatchRotation(ShipEntity *s)				{ return s->_cxxShip->docking_match_rotation; }
void SetDockingInstructions(ShipEntity *s, const oo::PList &instructions)	{ s->_cxxShip->dockingInstructions = instructions; }
void SetScannerRange(ShipEntity *s, GLfloat r)	{ s->_cxxShip->scannerRange = r; }
void SetAccuracy(ShipEntity *s, GLfloat a)		{ s->_cxxShip->accuracy = a; }
void SetNearPlanetSurface(ShipEntity *s, bool v)	{ s->_cxxShip->isNearPlanetSurface = v; }
void SetPrimaryTarget(ShipEntity *s, Entity *target)
{
	[s->_cxxShip->_primaryTarget release];
	s->_cxxShip->_primaryTarget = [target weakRetain];
}


void SetUp()
{
	static Universe *universe = nil;
	if (universe == nil)
	{
		universe = (Universe *)class_createInstance([Universe class], 0);	// never released
		universe->_cxxUniverse = oo::makeRef<cxx::Universe>(universe);	// what -initWithGameView: makes first (ADR-0056 amendment oo-riqmz)
	}
	gSharedUniverse = universe;
	static TestAIPlayer *player = nil;
	if (player == nil)  player = [[TestAIPlayer alloc] init];
	gOOPlayer = (PlayerEntity *)player;
	if (gOOJSMainThreadContext == nullptr)  gOOJSMainThreadContext = ooscript::newContext(ooscript::newRuntime(8u * 1024u * 1024u), 8192);
}


TestAIShip *MakeShip(const char *key)
{
	return [[[TestAIShip alloc] cxx_initWithKey:key definition:oo::PList(oo::PList::Dict{})] autorelease];
}


BOOL AlwaysYes(Entity *, void *)	{ return YES; }

}	// namespace


// --- Slice 1: the AI category, OOAIPrivate (ship and station), the station stubs (bead oo-iebuz) ---

// The perform* behaviours: each sets its behaviour and resets the frustration.
OO_TEST(slice1Behaviours)
{
	@autoreleasepool
	{
		SetUp();
		TestAIShip *ship = MakeShip("pilot");
		struct { void (*perform)(TestAIShip *); OOBehaviour behaviour; } cases[] = {
			{ [](TestAIShip *s) { [s performCollect]; }, BEHAVIOUR_COLLECT_TARGET },
			{ [](TestAIShip *s) { [s performFaceDestination]; }, BEHAVIOUR_FACE_DESTINATION },
			{ [](TestAIShip *s) { [s performFlyToRangeFromDestination]; }, BEHAVIOUR_FLY_RANGE_FROM_DESTINATION },
			{ [](TestAIShip *s) { [s performIdle]; }, BEHAVIOUR_IDLE },
			{ [](TestAIShip *s) { [s performIntercept]; }, BEHAVIOUR_INTERCEPT_TARGET },
			{ [](TestAIShip *s) { [s performScriptedAI]; }, BEHAVIOUR_SCRIPTED_AI },
			{ [](TestAIShip *s) { [s performScriptedAttackAI]; }, BEHAVIOUR_SCRIPTED_ATTACK_AI },
		};
		for (const auto &c : cases)
		{
			SetBehaviour(ship, BEHAVIOUR_TUMBLE);
			SetFrustration(ship, 5);
			c.perform(ship);
			OO_CHECK(Behaviour(ship) == c.behaviour && Frustration(ship) == 0);
		}

		SetDesiredSpeed(ship, 50);
		SetFrustration(ship, 5);
		[ship performHold];
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_TRACK_TARGET && DesiredSpeed(ship) == 0 && Frustration(ship) == 0);

		SetDesiredSpeed(ship, 50);
		[ship performStop];
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_STOP_STILL && DesiredSpeed(ship) == 0);

		[ship performBuoyTumble];
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_TUMBLE && StickRoll(ship) == 0.10f && StickPitch(ship) == 0.15f);

		SetMaxFlight(ship, 100, 2, 1);
		[ship performTumble];
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_TUMBLE && std::fabs(StickRoll(ship)) <= 2.0f && std::fabs(StickPitch(ship)) <= 1.0f);

		SetBehaviour(ship, BEHAVIOUR_IDLE);
		[ship performEscort];
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_FORMATION_FORM_UP && Frustration(ship) == 0);
		SetFrustration(ship, 5);
		[ship performEscort];		// already forming up: nothing changes
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_FORMATION_FORM_UP && Frustration(ship) == 5);
	}
}


OO_TEST(slice1AttackFleeMiningLanding)
{
	@autoreleasepool
	{
		SetUp();
		TestAIShip *ship = MakeShip("fighter");
		SetBehaviour(ship, BEHAVIOUR_IDLE);
		[ship performAttack];
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_ATTACK_TARGET && DesiredRange(ship) >= 750 && DesiredRange(ship) <= 2000);
		SetBehaviour(ship, BEHAVIOUR_EVASIVE_ACTION);
		[ship performAttack];		// evading: carries on
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_EVASIVE_ACTION);

		SetAccuracy(ship, COMBAT_AI_ISNT_AWFUL);	// no aspect check
		SetBehaviour(ship, BEHAVIOUR_IDLE);
		[ship performFlee];
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_FLEE_TARGET && Frustration(ship) == 0);
		SetBehaviour(ship, BEHAVIOUR_FLEE_EVASIVE_ACTION);
		[ship performFlee];
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_FLEE_EVASIVE_ACTION);

		// Mining a target that is not a rock: lost target, idle.
		SetBehaviour(ship, BEHAVIOUR_TUMBLE);
		[ship performMining];
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_IDLE);

		// Landing away from any planet's surface: idle.
		SetNearPlanetSurface(ship, false);
		SetBehaviour(ship, BEHAVIOUR_TUMBLE);
		SetFrustration(ship, 5);
		[ship performLandOnPlanet];
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_IDLE && Frustration(ship) == 0);
	}
}


// The docking instructions a ship remembers: destination, speed (at most the ship's top speed),
// range and rotation matching.
OO_TEST(slice1RecallDockingInstructions)
{
	@autoreleasepool
	{
		SetUp();
		TestAIShip *ship = MakeShip("docker");
		SetMaxFlight(ship, 100, 1, 1);
		[ship recallDockingInstructions];		// none: nothing changes
		OO_CHECK(DesiredSpeed(ship) == 0);

		SetDockingInstructions(ship, oo::PList(oo::PList::Dict{
			{ "destination", oo::PList(oo::PList::Dict{ { "x", oo::PList(1.0) }, { "y", oo::PList(2.0) }, { "z", oo::PList(3.0) } }) },
			{ "speed", oo::PList(250.0) },
			{ "range", oo::PList(40.0) },
			{ "match_rotation", oo::PList(true) },
		}));
		[ship recallDockingInstructions];
		OO_CHECK(HPdistance2(Destination(ship), make_HPvector(1, 2, 3)) < 1e-9);
		OO_CHECK(DesiredSpeed(ship) == 100 && DesiredRange(ship) == 40 && MatchRotation(ship));
	}
}


// Scans in an empty universe find nothing, and forget what was found before.
OO_TEST(slice1ScansFindNothing)
{
	@autoreleasepool
	{
		SetUp();
		TestAIShip *ship = MakeShip("scanner");
		TestAIShip *other = MakeShip("other");
		SetScannerRange(ship, 25000);

		[ship setFoundTarget:other];
		[ship scanForHostiles];
		OO_CHECK([ship foundTarget] == nil);

		[ship setFoundTarget:other];
		[ship scanForNearestShipWithPredicate:AlwaysYes parameter:NULL];
		OO_CHECK([ship foundTarget] == nil);

		[ship setFoundTarget:other];
		[ship scanForNearestShipWithNegatedPredicate:AlwaysYes parameter:NULL];
		OO_CHECK([ship foundTarget] == nil);

		[ship setFoundTarget:other];
		[ship scanForNearestShipWithPredicate:NULL parameter:NULL];
		OO_CHECK([ship foundTarget] == nil);

		[ship setFoundTarget:other];
		[ship scanForNearestIncomingMissile];
		OO_CHECK([ship foundTarget] == nil);

		[ship checkFoundTarget];		// no AI: nothing to tell
	}
}


// What the AI category does when there is nothing to act on.
OO_TEST(slice1NothingToActOn)
{
	@autoreleasepool
	{
		SetUp();
		TestAIShip *ship = MakeShip("loner");
		TestAIShip *other = MakeShip("other");

		// No escort to suggest to: the ship is its own owner.
		OO_CHECK(![ship suggestEscortTo:nil]);
		OO_CHECK([ship owner] == ship);

		// No aggressor: no distress call.
		[ship broadcastDistressMessage];
		[ship broadcastDistressMessageWithDumping:NO];
		OO_CHECK([ship foundTarget] == nil);

		// No primary target: no group attack, and a target that is not a wormhole: no escorts sent.
		[ship groupAttackTarget];
		OO_CHECK([ship foundTarget] == nil);
		SetPrimaryTarget(ship, other);
		[ship wormholeEscorts];
		OO_CHECK([ship primaryTarget] == other);

		// A ship that alone answers a request for help: it takes the target as found.
		[ship groupAttackTarget];
		OO_CHECK([ship foundTarget] == other);

		// Already entering witchspace: no second jump (the universe's destinations are not asked).
		[ship setStatus:STATUS_ENTERING_WITCHSPACE];
		OO_CHECK(![ship performHyperSpaceToSpecificSystem:7]);
		OO_CHECK(![ship performHyperSpaceExitReplace:NO]);
		OO_CHECK(![ship performHyperSpaceExitReplace:YES toSystem:3]);
		OO_CHECK([ship status] == STATUS_ENTERING_WITCHSPACE);
		[ship setStatus:STATUS_IN_FLIGHT];
	}
}


// A distress call accepted: the caller's attacker is the found target. A station that is not the
// main station ignores it.
OO_TEST(slice1AcceptDistressMessage)
{
	@autoreleasepool
	{
		SetUp();
		TestAIShip *ship = MakeShip("helper");
		TestAIShip *caller = MakeShip("caller");
		TestAIShip *attacker = MakeShip("attacker");
		SetPrimaryTarget(caller, attacker);
		[ship acceptDistressMessageFrom:caller];
		OO_CHECK([ship foundTarget] == attacker);

		TestAIStation *station = [[[TestAIStation alloc] cxx_initWithKey:"station" definition:oo::PList(oo::PList::Dict{ { "unpiloted", oo::PList(true) } })] autorelease];
		OO_CHECK(station != nil);
		[station acceptDistressMessageFrom:caller];
		OO_CHECK([station foundTarget] == nil);
	}
}


// The station AI methods on a ship that is not a station only log.
OO_TEST(slice1StationStubs)
{
	@autoreleasepool
	{
		SetUp();
		TestAIShip *ship = MakeShip("notastation");
		[(id)ship increaseAlertLevel];
		[(id)ship decreaseAlertLevel];
		[(id)ship abortAllDockings];
		[(id)ship launchShipWithRole:std::string("trader")];
		OO_CHECK([(id)ship launchPolice].isNull());
		OO_CHECK([ship status] == STATUS_IN_FLIGHT);
	}
}


// From C++ (after the conversion): the members, and the station's override of the virtual one.
OO_TEST(slice1MembersFromCxx)
{
	@autoreleasepool
	{
		SetUp();
		TestAIShip *ship = MakeShip("member");
		cxx::ShipEntity *part = ship->_cxxShip;
		part->performStop();
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_STOP_STILL);
		OO_CHECK(part->launchPolice().isNull() && !part->launchPatrol());

		TestAIShip *caller = MakeShip("caller");
		TestAIShip *attacker = MakeShip("attacker");
		SetPrimaryTarget(caller, attacker);
		part->acceptDistressMessageFrom(caller);
		OO_CHECK([ship foundTarget] == attacker);

		TestAIStation *station = [[[TestAIStation alloc] cxx_initWithKey:"station" definition:oo::PList(oo::PList::Dict{ { "unpiloted", oo::PList(true) } })] autorelease];
		cxx::ShipEntity *stationAsShip = station->_cxxShip;
		stationAsShip->acceptDistressMessageFrom(caller);		// the station's: not the main station, so nothing
		OO_CHECK([station foundTarget] == nil);
	}
}


// --- Slice 2: PureAI part 1: state, speed, scans for prey and loot, planets, legal status (bead
// oo-xurzn) ------------------------------------------------------------------------------------

// The private category PureAI of ShipEntityAI.mm.
@interface ShipEntity (TestPureAI1)
- (void) setStateTo:(const std::string &)state;
- (void) pauseAI:(const std::string &)intervalString;
- (void) randomPauseAI:(const std::string &)intervalString;
- (void) dropMessages:(const std::string &)messageString;
- (void) debugDumpPendingMessages;
- (void) setDestinationToCurrentLocation;
- (void) setDestinationToJinkPosition;
- (void) setDesiredRangeTo:(const std::string &)rangeString;
- (void) setDesiredRangeForWaypoint;
- (void) setSpeedTo:(const std::string &)speedString;
- (void) setSpeedFactorTo:(const std::string &)speedString;
- (void) setSpeedToCruiseSpeed;
- (void) setThrustFactorTo:(const std::string &)thrustFactorString;
- (void) setTargetToPrimaryAggressor;
- (void) addPrimaryAggressorAsDefenseTarget;
- (void) scanForNearestMerchantman;
- (void) scanForRandomMerchantman;
- (void) scanForLoot;
- (void) scanForRandomLoot;
- (void) setTargetToFoundTarget;
- (void) addFoundTargetAsDefenseTarget;
- (void) checkForFullHold;
- (void) getWitchspaceEntryCoordinates;
- (void) setDestinationFromCoordinates;
- (void) setCoordinatesFromPosition;
- (void) fightOrFleeMissile;
- (void) setCourseToPlanet;
- (void) setTakeOffFromPlanet;
- (void) checkTargetLegalStatus;
- (void) checkOwnLegalStatus;
- (void) exitAIWithMessage:(const std::string &)message;
- (void) setDestinationToTarget;
- (void) setDestinationWithinTarget;
@end


namespace {

void SetPosition2(Entity *e, HPVector p)			{ e->_cxxEntity->position = p; }
HPVector Coordinates2(ShipEntity *s)				{ return s->_cxxShip->coordinates; }
void SetCoordinates2(ShipEntity *s, HPVector c)	{ s->_cxxShip->coordinates = c; }
void SetCruiseSpeed2(ShipEntity *s, GLfloat v)	{ s->_cxxShip->cruiseSpeed = v; }
void SetMaxThrust2(ShipEntity *s, GLfloat v)		{ s->_cxxShip->max_thrust = v; }
GLfloat Thrust2(ShipEntity *s)					{ return s->_cxxShip->thrust; }
bool PitchingOver2(ShipEntity *s)				{ return s->_cxxShip->pitching_over; }
void SetCollisionRadius2(Entity *e, GLfloat r)	{ e->_cxxEntity->collision_radius = r; }

}	// namespace


OO_TEST(slice2SpeedAndRange)
{
	@autoreleasepool
	{
		SetUp();
		TestAIShip *ship = MakeShip("speedy");
		SetMaxFlight(ship, 600, 1, 1);
		[ship setDesiredRangeTo:"123.5"];
		OO_CHECK(DesiredRange(ship) == 123.5f);
		[ship setDesiredRangeForWaypoint];
		OO_CHECK(DesiredRange(ship) == 100.0f);		// top speed / pitch / 6
		SetMaxFlight(ship, 60, 1, 1);
		[ship setDesiredRangeForWaypoint];
		OO_CHECK(DesiredRange(ship) == 50.0f);			// at least 50

		[ship setSpeedTo:"42"];
		OO_CHECK(DesiredSpeed(ship) == 42.0f);
		SetMaxFlight(ship, 100, 1, 1);
		[ship setSpeedFactorTo:"0.5"];
		OO_CHECK(DesiredSpeed(ship) == 50.0f);
		SetCruiseSpeed2(ship, 80);
		[ship setSpeedToCruiseSpeed];
		OO_CHECK(DesiredSpeed(ship) == 80.0f);

		SetMaxThrust2(ship, 20);
		[ship setThrustFactorTo:"0.25"];
		OO_CHECK(Thrust2(ship) == 5.0f);
		[ship setThrustFactorTo:"3"];					// clamped to 1
		OO_CHECK(Thrust2(ship) == 20.0f);
	}
}


OO_TEST(slice2Destinations)
{
	@autoreleasepool
	{
		SetUp();
		TestAIShip *ship = MakeShip("navigator");
		TestAIShip *target = MakeShip("target");
		SetPosition2(ship, make_HPvector(10, 20, 30));
		[ship setDestinationToCurrentLocation];
		OO_CHECK(HPdistance(Destination(ship), make_HPvector(10, 20, 30)) <= 0.5 + 1e-6);

		[ship setCoordinatesFromPosition];
		OO_CHECK(HPdistance2(Coordinates2(ship), make_HPvector(10, 20, 30)) == 0);
		SetCoordinates2(ship, make_HPvector(1, 2, 3));
		[ship setDestinationFromCoordinates];
		OO_CHECK(HPdistance2(Destination(ship), make_HPvector(1, 2, 3)) == 0);

		// No target: the destination stays.
		[ship setDestinationToTarget];
		[ship setDestinationWithinTarget];
		OO_CHECK(HPdistance2(Destination(ship), make_HPvector(1, 2, 3)) == 0);
		SetPosition2(target, make_HPvector(500, 0, 0));
		SetCollisionRadius2(target, 20);
		SetPrimaryTarget(ship, target);
		[ship setDestinationToTarget];
		OO_CHECK(HPdistance2(Destination(ship), make_HPvector(500, 0, 0)) == 0);
		[ship setDestinationWithinTarget];
		OO_CHECK(HPdistance(Destination(ship), make_HPvector(500, 0, 0)) <= 20 + 1e-3);

		[ship setOrientation:kIdentityQuaternion];
		[ship setDestinationToJinkPosition];
		OO_CHECK(PitchingOver2(ship));

		// No station in the universe: ten seconds of flight forward.
		SetMaxFlight(ship, 100, 1, 1);
		SetPosition2(ship, make_HPvector(0, 0, 0));
		[ship getWitchspaceEntryCoordinates];
		OO_CHECK(HPdistance(Coordinates2(ship), make_HPvector(0, 0, 1000)) < 1e-3);
	}
}


OO_TEST(slice2TargetsAndScans)
{
	@autoreleasepool
	{
		SetUp();
		TestAIShip *ship = MakeShip("hunter");
		TestAIShip *other = MakeShip("other");
		SetScannerRange(ship, 25000);

		// No aggressor: nothing to target or defend against.
		[ship setTargetToPrimaryAggressor];
		[ship addPrimaryAggressorAsDefenseTarget];
		OO_CHECK([ship primaryTarget] == nil && ![ship isDefenseTarget:other]);

		// The found target becomes the primary target; none found, none taken.
		[ship setTargetToFoundTarget];
		OO_CHECK([ship primaryTarget] == nil);
		[ship setFoundTarget:other];
		[ship setTargetToFoundTarget];
		OO_CHECK([ship primaryTarget] == other);

		// Scans in an empty universe forget the found target.
		[ship setFoundTarget:other];
		[ship scanForNearestMerchantman];
		OO_CHECK([ship foundTarget] == nil);
		[ship setFoundTarget:other];
		[ship scanForRandomMerchantman];
		OO_CHECK([ship foundTarget] == nil);
		[ship setFoundTarget:other];
		[ship scanForRandomLoot];			// no scoop: gives up before the scan
		OO_CHECK([ship foundTarget] == other);
		[ship scanForLoot];				// no scoop: gives up before the scan
		OO_CHECK([ship foundTarget] == other);
		[ship fightOrFleeMissile];		// no missile coming
		OO_CHECK([ship foundTarget] == other && [ship primaryTarget] == other);
	}
}


// The methods that only tell the AI (the test's ships have none) or log run without effect.
OO_TEST(slice2MessagesOnly)
{
	@autoreleasepool
	{
		SetUp();
		TestAIShip *ship = MakeShip("quiet");
		SetBehaviour(ship, BEHAVIOUR_IDLE);
		[ship setStateTo:"GLOBAL"];
		[ship pauseAI:"2.5"];
		[ship randomPauseAI:"1 2"];
		[ship randomPauseAI:"1"];			// a syntax error: logged
		[ship dropMessages:"A, B ,C"];
		[ship debugDumpPendingMessages];
		[ship checkForFullHold];
		[ship checkTargetLegalStatus];
		[ship checkOwnLegalStatus];
		[ship exitAIWithMessage:""];
		[ship setCourseToPlanet];			// no planet
		[ship setTakeOffFromPlanet];		// no planet: logged
		OO_CHECK(Behaviour(ship) == BEHAVIOUR_IDLE && [ship status] == STATUS_IN_FLIGHT);
	}
}


// From C++ (after the conversion): the members.
OO_TEST(slice2MembersFromCxx)
{
	@autoreleasepool
	{
		SetUp();
		TestAIShip *ship = MakeShip("member2");
		cxx::ShipEntity *part = ship->_cxxShip;
		part->setSpeedTo("7");
		OO_CHECK(DesiredSpeed(ship) == 7.0f);
		SetPosition2(ship, make_HPvector(4, 5, 6));
		part->setCoordinatesFromPosition();
		part->setDestinationFromCoordinates();
		OO_CHECK(HPdistance2(Destination(ship), make_HPvector(4, 5, 6)) == 0);
	}
}


OO_TEST_MAIN()
