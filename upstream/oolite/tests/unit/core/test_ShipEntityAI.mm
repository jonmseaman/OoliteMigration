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
	ranrot_srand(20261007);	// as the game seeds it: an unseeded generator answers one value, and OOHPVectorRandomSpatial() never ends
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


OO_TEST_MAIN()
