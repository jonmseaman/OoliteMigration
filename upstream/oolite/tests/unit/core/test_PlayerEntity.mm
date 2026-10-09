/*	test_PlayerEntity.mm
	Unit tests for PlayerEntity (src/Core/Entities/PlayerEntity.h), the player's ship: slice 1 of
	its slice plan (docs/phases/3-slices/PlayerEntity.md, bead oo-jx5np), the class shell, which
	moves the player's state into cxx::PlayerEntity and keeps the Objective-C PlayerEntity as its
	facade, a subclass of the ship's (proposed ADR-0056, amendments oo-bj8, oo-60fwo and
	oo-jx5np).

	Like the ship's, the player's object needs the game graph, so the test links the whole game but
	main (['*']) and uses a Universe that was never initialised and an empty JavaScript context for
	the events the ship sends its scripts. The player is made in two steps, as the game makes it:
	-init (+sharedPlayer) early in start-up, before there is ship data, and -deferredInit once there
	is. Setting the player up from shipdata, the session and the controls (slice 5 and
	PlayerEntityControls) need the game's data, so a subclass stands in for those three and only
	counts; the cases test the slice's own units: +sharedPlayer, -init (the ship made the player's
	way, and the only player), -deferredInit (the ship's initialiser sent again over the same
	object, and the player's own defaults), and -dealloc (it releases what the player held, and a
	player released before its initialiser ran). The expectations were written against the
	Objective-C API and run on the unconverted class first. Ivars the test reads or sets go through
	the category below, the one place that knows where they live. The tests after those pin the
	crossing: an Objective-C player's C++ part is a cxx::PlayerEntity, and the facade's _cxxPlayer
	is that part.
	Run: bash tools/check-core-tests.sh test_PlayerEntity
*/

#import "PlayerEntity.h"
#import "MyOpenGLView.h"
#import "OOConstToString.h"
#import "OODescription.h"
#import "Universe.h"
#import "PlayerEntityContracts.h"
#import "PlayerEntityControls.h"
#import "PlayerEntityKeyMapper.h"
#import "PlayerEntityLegacyScriptEngine.h"
#import "PlayerEntityLoadSave.h"
#import "PlayerEntitySound.h"
#import "PlayerEntityStickMapper.h"
#import "OOJoystickManager.h"

#include "oo_test.hpp"

#include <cmath>
#include <string>


// main.mm defines the debug flags, and the test has its own main.
#ifndef NDEBUG
uint32_t gDebugFlags = 0;
#endif

extern PlayerEntity *gOOPlayer;
extern Universe *gSharedUniverse;
extern ooscript::Context gOOJSMainThreadContext;


// --- Ivars the test reads or sets, and nothing else ------------------------------------------------

@interface PlayerEntity (TestIvars)
- (double) testMaxFieldOfView;
- (BOOL) testScoopsActive;
- (NSUInteger) testTargetMemoryIndex;
- (ShipEntity *) testMissileAtPylon:(int)pylon;
- (void) testSetMissile:(ShipEntity *)missile atPylon:(int)pylon;
- (void) testSetSavePath:(const std::string &)path;
- (BOOL) testHasSavePath;
@end


@implementation PlayerEntity (TestIvars)

- (double) testMaxFieldOfView	{ return _cxxPlayer->maxFieldOfView; }
- (BOOL) testScoopsActive	{ return _cxxPlayer->scoopsActive; }
- (NSUInteger) testTargetMemoryIndex	{ return _cxxPlayer->target_memory_index; }
- (ShipEntity *) testMissileAtPylon:(int)pylon	{ return _cxxPlayer->missile_entity[pylon]; }
- (void) testSetMissile:(ShipEntity *)missile atPylon:(int)pylon	{ _cxxPlayer->missile_entity[pylon] = [missile retain]; }
- (void) testSetSavePath:(const std::string &)path	{ _cxxPlayer->save_path = path; }
- (BOOL) testHasSavePath	{ return _cxxPlayer->save_path.has_value(); }

@end

// --------------------------------------------------------------------------------------------------


namespace {

// What the stand-ins were sent.
int sShipSetUps = 0;
oo::PList sShipSetUpDict;
int sPlayerSetUps = 0;
BOOL sPlayerSetUpStopOnError = YES;
int sInitControls = 0;

}	// namespace


// A player whose set-up from shipdata, session set-up and controls only count (slice 5's units and
// PlayerEntityControls', which need the game's data).
@interface TestPlayer: PlayerEntity
@end


@implementation TestPlayer

- (BOOL) setUpShipFromDictionary:(const oo::PList &)dict
{
	sShipSetUps++;
	sShipSetUpDict = dict;
	return YES;
}


- (BOOL) setUpAndConfirmOK:(BOOL)stopOnError
{
	sPlayerSetUps++;
	sPlayerSetUpStopOnError = stopOnError;
	return YES;
}


- (void) initControls
{
	sInitControls++;
}

@end


// A ship that stands in for a missile on a pylon.
@interface TestMissile: ShipEntity
@end


@implementation TestMissile

- (BOOL) setUpShipFromDictionary:(const oo::PList &)dict	{ return YES; }

@end


namespace {

void SetUp()
{
	static Universe *universe = nil;
	if (universe == nil)
	{
		universe = (Universe *)class_createInstance([Universe class], 0);	// never released
		universe->_cxxUniverse = oo::makeRef<cxx::Universe>(universe);	// what -initWithGameView: makes first (ADR-0056 amendment oo-riqmz)
	}
	gSharedUniverse = universe;
	gOOPlayer = nil;	// -init expects to make the only player
	// The ship's -dealloc sends its (absent) scripts entityDestroyed in a request on the main
	// thread's context, so there is one, with nothing in it.
	if (gOOJSMainThreadContext == nullptr)  gOOJSMainThreadContext = ooscript::newContext(ooscript::newRuntime(8u * 1024u * 1024u), 8192);
	sShipSetUps = 0;
	sShipSetUpDict = oo::PList();
	sPlayerSetUps = 0;
	sPlayerSetUpStopOnError = YES;
	sInitControls = 0;
}


#ifndef NDEBUG
// -deferredInit sends the ship's initialiser, and so the root's -init, a second time, which counts
// the entity again, as it did.
void UncountSecondInit(Class cls)
{
	gLiveEntityCount--;
	gTotalEntityMemory -= class_getInstanceSize(cls);
}
#endif

}	// namespace


// -init: the ship made the player's way (-initBypassForPlayer), not set up from shipdata, not yet
// the player, and not yet the shared player.
OO_TEST(initIsTheShipMadeThePlayersWay)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = [[TestPlayer alloc] init];
		OO_CHECK(player != nil);
		OO_CHECK(sShipSetUps == 0 && sPlayerSetUps == 0 && sInitControls == 0);
		OO_CHECK(![player isShip] && ![player isPlayer]);
		OO_CHECK([player status] == STATUS_COCKPIT_DISPLAY);
		OO_CHECK([player cxx_shipDataKey] == std::nullopt);
		OO_CHECK([player temperature] == 0 && [player weaponRechargeRate] == 0);
		OO_CHECK([player testMaxFieldOfView] == 0);
		OO_CHECK(gOOPlayer == nil);
		[player release];
	}
}


// +sharedPlayer: made once, by -init, and kept.
OO_TEST(sharedPlayer)
{
	PlayerEntity *player = nil;
	@autoreleasepool
	{
		SetUp();
		player = [PlayerEntity sharedPlayer];
		OO_CHECK(player != nil && [player class] == [PlayerEntity class]);
		OO_CHECK(gOOPlayer == player);
		OO_CHECK([PlayerEntity sharedPlayer] == player);
		OO_CHECK(![player isPlayer] && [player status] == STATUS_COCKPIT_DISPLAY);
	}
	gOOPlayer = nil;
	[player release];
}


// -deferredInit: the ship's initialiser sent again with the player's ship key and an empty
// definition, which keeps the object (and its C++ part) and runs the ship's body over it; then
// the player's own defaults, the session set-up, and the controls.
OO_TEST(deferredInit)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = [[TestPlayer alloc] init];
		gOOPlayer = player;
		Entity *asEntity = player;
		void *part = oo::ToCxx(asEntity);
		[player setFuel:5];
		[player testSetSavePath:"some.oolite-save"];

		[player deferredInit];
		OO_CHECK((void *)oo::ToCxx(asEntity) == part);
		OO_CHECK(sShipSetUps == 1 && sShipSetUpDict.isDict() && sShipSetUpDict.getIf<oo::PList::Dict>()->empty());
		OO_CHECK([player cxx_shipDataKey] == std::optional<std::string>(std::string(PLAYER_SHIP_DESC)));
		OO_CHECK([player isShip] && [player isPlayer]);
		OO_CHECK([player status] == STATUS_START_GAME);
		OO_CHECK([player temperature] == SHIP_MIN_CABIN_TEMP && [player weaponRechargeRate] == 6.0f);
		OO_CHECK([player fuel] == 5);	// what the bodies do not set stays
		OO_CHECK(std::fabs([player testMaxFieldOfView] - MAX_FOV) < 1e-6);
		OO_CHECK([player compassMode] == COMPASS_MODE_BASIC);
		OO_CHECK(![player testScoopsActive] && [player testTargetMemoryIndex] == 0);
		OO_CHECK(![player testHasSavePath]);
		for (int i = 0; i < PLAYER_MAX_MISSILES; i++)  OO_CHECK([player testMissileAtPylon:i] == nil);
		OO_CHECK(sPlayerSetUps == 1 && sPlayerSetUpStopOnError == NO);
		OO_CHECK(sInitControls == 1);

		gOOPlayer = nil;
		[player release];
#ifndef NDEBUG
		UncountSecondInit([TestPlayer class]);
#endif
	}
}


// -dealloc releases what the player held (here, a missile on a pylon), and the ship's -dealloc
// runs after it.
OO_TEST(deallocReleasesWhatThePlayerHeld)
{
	TestMissile *missile = nil;
	@autoreleasepool
	{
		SetUp();
		missile = [[TestMissile alloc] cxx_initWithKey:"missile" definition:oo::PList()];
		TestPlayer *player = [[TestPlayer alloc] init];
		[player testSetMissile:missile atPylon:2];
		OO_CHECK([missile retainCount] == 2);
		OO_CHECK([player testMissileAtPylon:2] == missile);
		[player release];
	}
	OO_CHECK([missile retainCount] == 1);
	[missile release];
}


// A player released before its initialiser ran (alloc, then release): -dealloc runs without
// having been set up, as the ship's and the root's do (oo-s6ic6).
OO_TEST(releasedBeforeInit)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = [TestPlayer alloc];
		[player release];
		OO_CHECK(gOOPlayer == nil);
	}
}


// The crossing: an Objective-C player's C++ part is a cxx::PlayerEntity, the facade's _cxxPlayer,
// beside the ship's _cxxShip, and the ship's adapter lines reach the player's overrides.
OO_TEST(objCPlayerPartIsAPlayer)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = [[TestPlayer alloc] init];
		Entity *asEntity = player;
		cxx::PlayerEntity *part = oo::ToCxx(player);
		OO_CHECK(part != nullptr && part == player->_cxxPlayer);
		OO_CHECK(static_cast<cxx::ShipEntity *>(part) == player->_cxxShip);
		OO_CHECK(dynamic_cast<cxx::PlayerEntity *>(oo::ToCxx(asEntity)) == part);
		OO_CHECK(oo::AsObjCEntity(part) != nullptr && oo::ToObjC(part) == player);

		cxx::ShipEntity *asShip = part;
		OO_CHECK(asShip->setUpShipFromDictionary(oo::PList()) && sShipSetUps == 1);
		[player release];
	}
}


// Every member starts zeroed, as the runtime zeroed the ivars.
OO_TEST(membersStartZeroed)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = [[TestPlayer alloc] init];
		cxx::PlayerEntity *part = player->_cxxPlayer;
		OO_CHECK(part->hud == nil && part->compassTarget == nil && part->wormhole == nil);
		OO_CHECK(part->system_id == 0 && part->ship_clock == 0 && part->scoopsActive == NO);
		for (int i = 0; i < PLAYER_MAX_MISSILES; i++)  OO_CHECK(part->missile_entity[i] == nil);
		OO_CHECK(!part->save_path.has_value() && part->worldScripts.empty());
		[player release];
	}
}


// --- Slice 2: cargo pods, commodity data and credits, galaxy and chart coordinates, the current and
// previous system (bead oo-m4tfc) ------------------------------------------------------------------

namespace {

// A player made the way +sharedPlayer makes one, but not the shared player (no ship data).
TestPlayer *MakePlayer()
{
	gOOPlayer = nil;
	return [[[TestPlayer alloc] init] autorelease];
}

bool Near(NSPoint a, NSPoint b)	{ return std::fabs(a.x - b.x) < 1e-4 && std::fabs(a.y - b.y) < 1e-4; }

}	// namespace


// The player's ship can't be renamed; the base mass falls back to the Cobra III's while the ship has
// none.
OO_TEST(slice2NameAndBaseMass)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = MakePlayer();
		const std::optional<std::string> before = [player cxx_name];
		[player cxx_setName:std::string("Renamed")];
		OO_CHECK([player cxx_name] == before);
		OO_CHECK([player baseMass] == 185580.0f);
	}
}


// The plain accessors read and write the members.
OO_TEST(slice2Accessors)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = MakePlayer();
		cxx::PlayerEntity *part = player->_cxxPlayer;
		OO_CHECK([player shipCommodityData] == nil);
		part->credits = 1234;
		OO_CHECK([player deciCredits] == 1234);
		[player setRandom_factor:77];
		OO_CHECK([player random_factor] == 77 && part->market_rnd == 77);
		part->galaxy_number = 3;
		OO_CHECK([player galaxyNumber] == 3);
		[player setGalaxyCoordinates:NSMakePoint(12.5, 99.0)];
		OO_CHECK(Near([player galaxy_coordinates], NSMakePoint(12.5, 99.0)));
		part->cursor_coordinates = NSMakePoint(4, 5);
		part->chart_centre_coordinates = NSMakePoint(6, 7);
		OO_CHECK(Near([player cursor_coordinates], NSMakePoint(4, 5)) && Near([player chart_centre_coordinates], NSMakePoint(6, 7)));
		[player setCustomChartZoom:2.5];
		OO_CHECK([player custom_chart_zoom] == 2.5);
		[player setCustomChartCentre:NSMakePoint(30, 40)];
		OO_CHECK(Near([player custom_chart_centre_coordinates], NSMakePoint(30, 40)));
		part->ANA_mode = OPTIMIZED_BY_TIME;
		OO_CHECK([player ANAMode] == OPTIMIZED_BY_TIME);
		part->system_id = 42;
		OO_CHECK([player systemID] == 42);
		[player setPreviousSystemID:17];
		OO_CHECK([player previousSystemID] == 17);
	}
}


// The chart's zoom and centre follow a mission screen's chart background.
OO_TEST(slice2ChartZoomAndCentre)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = MakePlayer();
		cxx::PlayerEntity *part = player->_cxxPlayer;
		part->chart_zoom = 1.0;
		part->custom_chart_zoom = 3.0;
		part->galaxy_coordinates = NSMakePoint(20, 30);
		part->custom_chart_centre_coordinates = NSMakePoint(50, 60);
		part->chart_centre_coordinates = NSMakePoint(100, 110);
		part->chart_focus_coordinates = NSMakePoint(100, 110);

		part->_missionBackgroundSpecial = GUI_BACKGROUND_SPECIAL_NONE;
		OO_CHECK([player chart_zoom] == 1.0);
		OO_CHECK(Near([player adjusted_chart_centre], NSMakePoint(100, 110)));
		part->_missionBackgroundSpecial = GUI_BACKGROUND_SPECIAL_SHORT;
		OO_CHECK([player chart_zoom] == 1.0);
		OO_CHECK(Near([player adjusted_chart_centre], NSMakePoint(20, 30)));
		part->_missionBackgroundSpecial = GUI_BACKGROUND_SPECIAL_LONG_ANA_QUICKEST;
		OO_CHECK([player chart_zoom] == (OOScalar)CHART_MAX_ZOOM);
		OO_CHECK(Near([player adjusted_chart_centre], NSMakePoint(128, 128)));
		part->_missionBackgroundSpecial = GUI_BACKGROUND_SPECIAL_CUSTOM;
		OO_CHECK([player chart_zoom] == 3.0);
		OO_CHECK(Near([player adjusted_chart_centre], NSMakePoint(50, 60)));
	}
}


// Unloading a commodity with no pods in the hold takes it from the manifest (here, none).
OO_TEST(slice2UnloadWithNoPods)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = MakePlayer();
		[player unloadCargoPodsForType:"food" amount:3];
		[player unloadAllCargoPodsForType:"food" toManifest:nil];
		OO_CHECK(player->_cxxShip->cargo.empty());
	}
}

// --- Slice 3: target, next-hop and info systems, the wormhole, the commander data dictionary
// (bead oo-7pa3t) ---------------------------------------------------------------------------------

// The target and info systems; with no advanced navigational array the next hop is the target.
OO_TEST(slice3TargetAndInfoSystems)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = MakePlayer();
		cxx::PlayerEntity *part = player->_cxxPlayer;
		part->system_id = 7;
		part->target_system_id = 9;
		part->info_system_id = 11;
		part->ANA_mode = OPTIMIZED_BY_JUMPS;
		OO_CHECK([player targetSystemID] == 9);
		OO_CHECK([player nextHopTargetSystemID] == 9);
		OO_CHECK([player infoSystemID] == 11);
		[player setInfoSystemID:11 moveChart:YES];	// the same system: nothing changes
		OO_CHECK([player infoSystemID] == 11);
	}
}


// The wormhole is retained while the player holds it, and released when replaced.
OO_TEST(slice3Wormhole)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = MakePlayer();
		OO_CHECK([player wormhole] == nil);
		WormholeEntity *hole = (WormholeEntity *)[[Entity alloc] init];	// any object: the player only retains it
		NSUInteger count = [hole retainCount];
		[player setWormhole:hole];
		OO_CHECK([player wormhole] == hole && [hole retainCount] == count + 1);
		[player setWormhole:nil];
		OO_CHECK([player wormhole] == nil && [hole retainCount] == count);
		[hole release];
	}
}

// --- Slice 4: setting the commander data from a dictionary (bead oo-qvnwb) ---------------------

// The multi-function displays and dials are reset first; a dictionary without the required keys
// is refused.
OO_TEST(slice4RefusesADictionaryWithoutTheRequiredKeys)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = MakePlayer();
		cxx::PlayerEntity *part = player->_cxxPlayer;
		part->multiFunctionDisplayText["mfd"] = "text";
		part->multiFunctionDisplaySettings.push_back(std::string("mfd"));
		part->customDialSettings["dial"] = oo::PList(1);
		OO_CHECK(![player cxx_setCommanderDataFromDictionary:oo::PList(oo::PList::Dict{})]);
		OO_CHECK(part->multiFunctionDisplayText.empty() && part->multiFunctionDisplaySettings.empty() && part->customDialSettings.empty());
		OO_CHECK(![player cxx_setCommanderDataFromDictionary:oo::PList(oo::PList::Dict{ { "ship_desc", oo::PList(std::string("cobra3-player")) } })]);
	}
}

// --- Slice 5: set-up and start-up, ship set-up from the dictionary, the session, warning about
// hostiles (bead oo-mmcfq) -----------------------------------------------------------------------

// The player always belongs to the current session, and collides only in flight.
OO_TEST(slice5SessionAndCollisions)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = MakePlayer();
		OO_CHECK([player sessionID] == [UNIVERSE sessionID]);
		[player setStatus:STATUS_IN_FLIGHT];
		OO_CHECK([player canCollide]);
		[player setStatus:STATUS_DOCKED];
		OO_CHECK(![player canCollide]);
		[player setStatus:STATUS_DEAD];
		OO_CHECK(![player canCollide]);
		[player setStatus:STATUS_EXITING_WITCHSPACE];
		OO_CHECK([player canCollide]);
	}
}

// --- Slice 6: sun glare, the atmosphere, update: (bead oo-vzjco) --------------------------------

// The player is always the nearest entity and may always be added; outside an atmosphere the
// fraction inside it is zero.
OO_TEST(slice6NearestValidAndAtmosphere)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = MakePlayer();
		OO_CHECK([player compareZeroDistance:player] == OOOrderedDescending);
		OO_CHECK([player validForAddToUniverse]);
		OO_CHECK([player insideAtmosphereFraction] == 0.0f);
		OO_CHECK([player lookingAtSunWithThresholdAngleCos:0.5f] == 0.0f);	// no sun
	}
}

// --- Slice 7: the bookkeeping tick, movement flags (bead oo-5c466) ------------------------------

// A step of -update: the class declared only in its file (PlayerEntity (OOPrivate)).
@interface PlayerEntity (TestSlice7)
- (void) updateMovementFlags;
@end


// The movement flags compare the position and orientation with the last frame's, which they then
// become.
OO_TEST(slice7MovementFlags)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = MakePlayer();
		cxx::Entity *entity = player->_cxxEntity.get();
		entity->position = make_HPvector(1, 2, 3);
		entity->lastPosition = kZeroHPVector;
		entity->orientation = kIdentityQuaternion;
		entity->lastOrientation = kIdentityQuaternion;
		[player updateMovementFlags];
		OO_CHECK(entity->hasMoved && !entity->hasRotated);
		OO_CHECK(HPvector_equal(entity->lastPosition, entity->position));
		[player updateMovementFlags];
		OO_CHECK(!entity->hasMoved && !entity->hasRotated);
	}
}

// --- Slice 8: alert conditions, mass lock, fuel scoops, clocks, script and trumble ticks, the
// autopilot and docking requests (bead oo-ijf0s) ---------------------------------------------------

// The flight limits also set the player's control rates; without the autopilot engaged or a
// station, disengaging and cancelling a docking request change nothing.
OO_TEST(slice8FlightLimitsAndAutopilot)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = MakePlayer();
		cxx::PlayerEntity *part = player->_cxxPlayer;
		[player setMaxFlightPitch:1.5f];
		[player setMaxFlightRoll:2.0f];
		[player setMaxFlightYaw:0.5f];
		OO_CHECK(player->_cxxShip->max_flight_pitch == 1.5f && part->pitch_delta == 3.0f);
		OO_CHECK(player->_cxxShip->max_flight_roll == 2.0f && part->roll_delta == 4.0f);
		OO_CHECK(player->_cxxShip->max_flight_yaw == 0.5f && part->yaw_delta == 1.0f);
		[player setStatus:STATUS_IN_FLIGHT];
		[player disengageAutopilot];
		OO_CHECK(!part->autopilot_engaged && [player status] == STATUS_IN_FLIGHT);
		[player cancelDockingRequest:nil];
		OO_CHECK([player status] == STATUS_IN_FLIGHT);
	}
}

// --- Slice 9: the autopilot AI, hyperspeed, the per-status updates, game over, targeting
// (bead oo-qyjcv) ----------------------------------------------------------------------------------

// The injector and hyperspeed flags and the hyperspeed factor read the members.
OO_TEST(slice9HyperspeedFlags)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = MakePlayer();
		cxx::PlayerEntity *part = player->_cxxPlayer;
		OO_CHECK(![player injectorsEngaged] && ![player hyperspeedEngaged]);
		part->afterburner_engaged = YES;
		part->hyperspeed_engaged = YES;
		OO_CHECK([player injectorsEngaged] && [player hyperspeedEngaged]);
#if OO_VARIABLE_TORUS_SPEED
		part->hyperspeedFactor = 4.5f;
		OO_CHECK([player hyperspeedFactor] == 4.5f);
#endif
	}
}

// --- Slice 10: attitude, view matrices and viewpoints, drawing, mass lock, the docked station, the
// HUD and its custom dials, shield levels (bead oo-9u9w6) ----------------------------------------

// The normal orientation is the orientation with w negated, both ways; the flags and levels read and
// write the members; the shield level is clamped to its maximum.
OO_TEST(slice10OrientationFlagsAndShields)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = MakePlayer();
		cxx::PlayerEntity *part = player->_cxxPlayer;
		Quaternion q = make_quaternion(0.5, 0.5, 0.5, 0.5);
		[player setNormalOrientation:q];
		Quaternion n = [player normalOrientation];
		OO_CHECK(n.w == q.w && n.x == q.x && n.y == q.y && n.z == q.z);
		OO_CHECK([player orientation].w == -q.w);
		[player setOcclusionLevel:0.75f];
		OO_CHECK([player occlusionLevel] == 0.75f);
		[player setShowDemoShips:YES];
		OO_CHECK([player showDemoShips]);
		part->travelling_at_hyperspeed = YES;
		OO_CHECK([player atHyperspeed]);
		part->alertFlags = ALERT_FLAG_MASS_LOCK;
		OO_CHECK([player massLocked]);
		part->alertFlags = 0;
		OO_CHECK(![player massLocked]);
		OO_CHECK(![player massLockable]);
		[player setMaxForwardShieldLevel:100.0f];
		OO_CHECK([player maxForwardShieldLevel] == 100.0f);
		[player setForwardShieldLevel:250.0f];
		OO_CHECK([player forwardShieldLevel] == 100.0f);
		[player setForwardShieldLevel:-5.0f];
		OO_CHECK([player forwardShieldLevel] == 0.0f);
	}
}


// The roll and speed dials are fractions of the maxima, clamped.
OO_TEST(slice10Dials)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = MakePlayer();
		player->_cxxShip->max_flight_roll = 2.0f;
		player->_cxxShip->flightRoll = 1.0f;
		OO_CHECK([player dialRoll] == 0.5f);
		player->_cxxShip->flightRoll = -5.0f;
		OO_CHECK([player dialRoll] == -1.0f);
		player->_cxxShip->maxFlightSpeed = 100.0f;
		player->_cxxShip->flightSpeed = 250.0f;
		OO_CHECK([player dialSpeed] == 1.0f);
		player->_cxxShip->flightSpeed = 25.0f;
		OO_CHECK([player dialSpeed] == 0.25f);
	}
}

// --- Slice 11: the dials, fuel leak, the comm log, player roles, system memory, the compass target
// (bead oo-zxg1h) ---------------------------------------------------------------------------------

// The clock, its adjustment, the rescue time and the fuel leak (never negative) read and write the
// members; the number of player roles grows with the kills.
OO_TEST(slice11ClockFuelLeakAndRoles)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = MakePlayer();
		cxx::PlayerEntity *part = player->_cxxPlayer;
		part->ship_clock = 1000.0;
		OO_CHECK([player clockTime] == 1000.0 && ![player clockAdjusting]);
		[player addToAdjustTime:60.0];
		OO_CHECK([player clockAdjusting] && [player clockTimeAdjusted] == 1060.0);
		[player setEscapePodRescueTime:42.0];
		OO_CHECK([player escapePodRescueTime] == 42.0);
		[player setFuelLeakRate:-1.0f];
		OO_CHECK([player fuelLeakRate] == 0.0f);
		[player setFuelLeakRate:3.0f];
		OO_CHECK([player fuelLeakRate] == 3.0f);
		part->ship_kills = 0;
		OO_CHECK([player maxPlayerRoles] == 8);
		part->ship_kills = 128;
		OO_CHECK([player maxPlayerRoles] == 16);
		part->ship_kills = 6400;
		OO_CHECK([player maxPlayerRoles] == 32);
	}
}


// The missile count counts the occupied pylons up to the ship's maximum.
OO_TEST(slice11CountMissiles)
{
	TestMissile *missile = nil;
	@autoreleasepool
	{
		SetUp();
		missile = [[TestMissile alloc] cxx_initWithKey:"missile" definition:oo::PList()];
		TestPlayer *player = MakePlayer();
		player->_cxxShip->max_missiles = 4;
		OO_CHECK([player countMissiles] == 0);
		[player testSetMissile:missile atPylon:1];
		[player testSetMissile:missile atPylon:3];
		OO_CHECK([player countMissiles] == 2);
		player->_cxxShip->max_missiles = 2;
		OO_CHECK([player countMissiles] == 1);
	}
	[missile release];
}

// --- Slice 12: compass mode, missiles and pylons, special cargo, the multi-function displays, alert
// flags (bead oo-rqcfz) ---------------------------------------------------------------------------

// The compass mode, the ident flag, the maximum missiles and the alert flags read and write the
// members.
OO_TEST(slice12CompassIdentAndAlertFlags)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = MakePlayer();
		[player setCompassMode:COMPASS_MODE_TARGET];
		OO_CHECK([player compassMode] == COMPASS_MODE_TARGET);
		[player setDialIdentEngaged:(BOOL)3];
		OO_CHECK([player dialIdentEngaged]);
		player->_cxxShip->max_missiles = 5;
		OO_CHECK([player dialMaxMissiles] == 5);
		[player setAlertFlag:ALERT_FLAG_MASS_LOCK to:YES];
		OO_CHECK(([player alertFlags] & ALERT_FLAG_MASS_LOCK) != 0);
		[player setAlertFlag:ALERT_FLAG_MASS_LOCK to:NO];
		OO_CHECK(([player alertFlags] & ALERT_FLAG_MASS_LOCK) == 0);
		player->_cxxPlayer->alertFlags = 0x7;
		[player clearAlertFlags];
		OO_CHECK([player alertFlags] == 0);
	}
}

// --- Slice 13: alert condition, AI messages, missiles and mines, the cloak, ECM, energy units, the
// main weapons (bead oo-30g73) ---------------------------------------------------------------------

// The fleeing status reads the member; taking the weapons offline makes every missile safe.
OO_TEST(slice13FleeingAndWeaponsOnline)
{
	@autoreleasepool
	{
		SetUp();
		TestPlayer *player = MakePlayer();
		cxx::PlayerEntity *part = player->_cxxPlayer;
		part->fleeing_status = PLAYER_FLEEING_CARGO;
		OO_CHECK([player fleeingStatus] == PLAYER_FLEEING_CARGO);
		[player setWeaponsOnline:YES];
		OO_CHECK([player weaponsOnline]);
		[player setWeaponsOnline:NO];
		OO_CHECK(![player weaponsOnline]);
	}
}

// --- Slices 14-28: a player whose sends to itself are recorded (beads oo-m8x1y ... oo-zn1vy) --------

namespace {

// What a RecordingPlayer was sent.
struct Sent
{
	int count = 0;
	OOCreditsQuantity amount = 0;
	std::string text;
	int number = 0;
	bool flag = false;
	std::optional<std::string> optionalText;
};
Sent sSent;

}	// namespace


@interface PlayerEntity (TestPrivate)
- (OOFuelQuantity) fuelRequiredForJump;
@end


/*	A player whose sends to itself that lead to the game's data (scripts, the GUI, the market) only
	record what they were sent, so that a slice's own logic is what the test sees, before and after
	the slice moves it into cxx::PlayerEntity (sends to self stay sends).
*/
@interface RecordingPlayer: TestPlayer
@end


@implementation RecordingPlayer

- (void) setBounty:(OOCreditsQuantity)amount withReasonAsString:(const std::string &)reason
{
	sSent.count++; sSent.amount = amount; sSent.text = reason;
}


- (void) markAsOffender:(int)offence_value withReason:(OOLegalStatusReason)reason
{
	sSent.count++; sSent.number = offence_value; sSent.text = cxx_OOStringFromLegalStatusReason(reason);
}


- (OOFuelQuantity) fuelRequiredForJump
{
	return (OOFuelQuantity)sSent.number;
}


- (void) setGuiToSystemDataScreenRefreshBackground:(BOOL)refreshBackground
{
	sSent.count++; sSent.flag = refreshBackground;
}


- (void) cxx_setGuiToEquipShipScreen:(int)skip selectingFacingFor:(const std::optional<std::string> &)eqKey
{
	sSent.count++; sSent.number = skip; sSent.optionalText = eqKey;
}


- (void) cxx_showInformationForSelectedUpgradeWithFormatString:(const std::optional<std::string> &)formatString
{
	sSent.count++; sSent.optionalText = formatString;
}


- (void) noteGUIDidChangeFrom:(OOGUIScreenID)fromScreen to:(OOGUIScreenID)toScreen refresh:(BOOL)refresh
{
	sSent.count++; sSent.number = (int)fromScreen * 100 + (int)toScreen; sSent.flag = refresh;
}


- (void) noteSwitchToView:(OOViewID)toView fromView:(OOViewID)fromView
{
	sSent.count++; sSent.number = (int)fromView * 100 + (int)toView;
}


- (BOOL) cxx_setWeaponMount:(OOWeaponFacing)facing toWeapon:(const std::string &)eqKey inContext:(const std::optional<std::string> &)context
{
	sSent.count++; sSent.number = (int)facing; sSent.text = eqKey; sSent.optionalText = context;
	return YES;
}


- (OOCargoQuantity) cargoQuantityOnBoard
{
	return 7;
}


- (BOOL) addEquipmentItem:(const std::string &)equipmentKey withValidation:(BOOL)validateAddition inContext:(const std::string &)context
{
	sSent.count++; sSent.text = equipmentKey + "/" + context; sSent.flag = validateAddition;
	return YES;
}


- (void) setScoopsActive
{
	sSent.count++;
	[super setScoopsActive];
}

@end


namespace {

RecordingPlayer *MakeRecordingPlayer()
{
	sSent = Sent();
	gOOPlayer = nil;
	return [[[RecordingPlayer alloc] init] autorelease];
}

bool NearV(Vector a, Vector b)	{ return std::fabs(a.x - b.x) < 1e-4 && std::fabs(a.y - b.y) < 1e-4 && std::fabs(a.z - b.z) < 1e-4; }

}	// namespace


// --- Slice 14: hit testing, damage, the doppelganger, the escape capsule, dumping cargo, bounty
// (bead oo-m8x1y) ---------------------------------------------------------------------------------

// Setting the bounty with no reason sends the unknown reason's string; rotating an empty hold does
// nothing.
OO_TEST(slice14BountyAndRotateCargo)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		[player setBounty:25];
		OO_CHECK(sSent.count == 1 && sSent.amount == 25);
		OO_CHECK(sSent.text == cxx_OOStringFromLegalStatusReason(kOOLegalStatusReasonUnknown));
		[player setBounty:30 withReason:kOOLegalStatusReasonUnknown];
		OO_CHECK(sSent.count == 2 && sSent.amount == 30);
		[player rotateCargo];
		OO_CHECK(player->_cxxShip->cargo.empty());
	}
}

// --- Slice 15: legal status, offences, bounties collected, internal damage, destruction, ending a
// scenario, docking and leaving dock (bead oo-2lpiu) ------------------------------------------------

// The bounty is the legal status; an offence with no reason sends the unknown reason; a scenario
// ends only with its own key.
OO_TEST(slice15LegalStatusOffenceAndScenario)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		player->_cxxPlayer->legalStatus = 64;
		OO_CHECK([player bounty] == 64 && [player legalStatus] == 64);
		[player markAsOffender:8];
		OO_CHECK(sSent.count == 1 && sSent.number == 8);
		OO_CHECK(sSent.text == cxx_OOStringFromLegalStatusReason(kOOLegalStatusReasonUnknown));
		OO_CHECK(![player cxx_endScenario:"some-scenario"]);
		player->_cxxPlayer->scenarioKey = std::string("other-scenario");
		OO_CHECK(![player cxx_endScenario:"some-scenario"]);
	}
}

// --- Slice 16: witchspace: start, end, checklist, jump type and distance, fuel, galactic and
// wormhole jumps (bead oo-vqjjb) -------------------------------------------------------------------

// The jump type sets the galactic flag; the fuel suffices when it reaches what the jump needs.
OO_TEST(slice16JumpTypeAndFuel)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		[player setJumpType:YES];
		OO_CHECK(player->_cxxPlayer->galactic_witchjump);
		[player setJumpType:NO];
		OO_CHECK(!player->_cxxPlayer->galactic_witchjump);
		player->_cxxShip->fuel = 70;
		sSent.number = 50;
		OO_CHECK([player hasSufficientFuelForJump]);
		sSent.number = 70;
		OO_CHECK([player hasSufficientFuelForJump]);
		sSent.number = 71;
		OO_CHECK(![player hasSufficientFuelForJump]);
	}
}

// --- Slice 17: leaving witchspace, the status screen, the equipment list, primed and fast
// equipment, weapon types (bead oo-6tuef) ----------------------------------------------------------

// With no primable equipment nothing is primed; the fast equipment keys read and write the members.
OO_TEST(slice17PrimedAndFastEquipment)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		OO_CHECK([player primedEquipmentCount] == 0);
		OO_CHECK([player cxx_currentPrimedEquipment].empty());
		OO_CHECK(![player cxx_fastEquipmentA].has_value() && ![player cxx_fastEquipmentB].has_value());
		[player cxx_setFastEquipmentA:std::string("EQ_FUEL_INJECTION")];
		[player cxx_setFastEquipmentB:std::string("EQ_ECM")];
		OO_CHECK([player cxx_fastEquipmentA] == std::optional<std::string>("EQ_FUEL_INJECTION"));
		OO_CHECK([player cxx_fastEquipmentB] == std::optional<std::string>("EQ_ECM"));
	}
}

// --- Slice 18: scripting lists, the system data screen, marked destinations, the chart screens
// (bead oo-3fzv5) ---------------------------------------------------------------------------------

// With no passengers, parcels or contracts the scripting lists are empty arrays; the system data
// screen is shown without refreshing the background.
OO_TEST(slice18ScriptingListsAndSystemData)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		const oo::PList passengers = [player passengerListForScripting];
		const oo::PList parcels = [player parcelListForScripting];
		const oo::PList contracts = [player contractListForScripting];
		OO_CHECK(passengers.isArray() && passengers.getIf<oo::PList::Array>()->empty());
		OO_CHECK(parcels.isArray() && parcels.getIf<oo::PList::Array>()->empty());
		OO_CHECK(contracts.isArray() && contracts.getIf<oo::PList::Array>()->empty());
		sSent.flag = true;
		[player setGuiToSystemDataScreen];
		OO_CHECK(sSent.count == 1 && !sSent.flag);
	}
}

// Slice 19 (the game options and load / save screens, the equip-screen key highlight, the available
// facings; bead oo-4tqku) has no unit case: every unit reads the GUI, the ship registry or the
// game's data, which the goldens cover.

// --- Slice 20: the equip-ship screen and upgrade information (bead oo-dycza) ------------------------

// The short forms send the long ones with no facing selection and no format string.
OO_TEST(slice20EquipShipScreenShortForms)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		sSent.optionalText = std::string("unset");
		[player setGuiToEquipShipScreen:3];
		OO_CHECK(sSent.count == 1 && sSent.number == 3 && !sSent.optionalText.has_value());
		sSent.optionalText = std::string("unset");
		[player showInformationForSelectedUpgrade];
		OO_CHECK(sSent.count == 2 && !sSent.optionalText.has_value());
	}
}

// --- Slice 21: the interfaces screen, the start screen and intro, the OXZ manager, GUI and view
// change notes (bead oo-a602n) ---------------------------------------------------------------------

// The short GUI change note sends the long one without a refresh; the view change note is the
// controls' view switch, arguments swapped.
OO_TEST(slice21ChangeNotes)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		sSent.flag = true;
		[player noteGUIDidChangeFrom:GUI_SCREEN_STATUS to:GUI_SCREEN_MARKET];
		OO_CHECK(sSent.count == 1 && sSent.number == (int)GUI_SCREEN_STATUS * 100 + (int)GUI_SCREEN_MARKET && !sSent.flag);
		[player noteViewDidChangeFrom:VIEW_AFT toView:VIEW_FORWARD];
		OO_CHECK(sSent.count == 2 && sSent.number == (int)VIEW_AFT * 100 + (int)VIEW_FORWARD);
	}
}

// --- Slice 22: buying equipment, script price adjustment, weapon mounts, passenger berths, removing
// missiles, trade-in (bead oo-mv49m) ---------------------------------------------------------------

// Mounting a weapon is a purchase; no berth changes by zero, and none is removed when there is none.
OO_TEST(slice22WeaponMountAndBerths)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		OO_CHECK([player setWeaponMount:WEAPON_FACING_AFT toWeapon:"EQ_WEAPON_PULSE_LASER"]);
		OO_CHECK(sSent.count == 1 && sSent.number == (int)WEAPON_FACING_AFT && sSent.text == "EQ_WEAPON_PULSE_LASER");
		OO_CHECK(sSent.optionalText == std::optional<std::string>("purchase"));
		OO_CHECK(![player changePassengerBerths:0]);
		player->_cxxPlayer->max_passengers = 0;
		OO_CHECK(![player changePassengerBerths:-1]);
		OO_CHECK(player->_cxxPlayer->max_passengers == 0);
	}
}

// --- Slice 23: cargo quantities, the local market, market filters and sorters, market screen rows
// (bead oo-wt5jv) ---------------------------------------------------------------------------------

// The current cargo is what is on board.
OO_TEST(slice23CalculateCurrentCargo)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		player->_cxxPlayer->current_cargo = 0;
		[player calculateCurrentCargo];
		OO_CHECK(player->_cxxPlayer->current_cargo == 7);
	}
}

// --- Slice 24: the market screens, buying and selling commodities, mining and speech flags, adding
// equipment (bead oo-bj7u8) ------------------------------------------------------------------------

// The screen, mining and speech flags read the members; adding equipment validates it.
OO_TEST(slice24FlagsAndAddEquipment)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		cxx::PlayerEntity *part = player->_cxxPlayer;
		part->gui_screen = GUI_SCREEN_MARKET;
		OO_CHECK([player guiScreen] == GUI_SCREEN_MARKET);
		part->using_mining_laser = YES;
		OO_CHECK([player isMining]);
		part->using_mining_laser = NO;
		OO_CHECK(![player isMining]);
		part->isSpeechOn = OOSPEECHSETTINGS_ALL;
		OO_CHECK([player isSpeechOn] == OOSPEECHSETTINGS_ALL);
		OO_CHECK([player addEquipmentItem:"EQ_ECM" inContext:"purchase"]);
		OO_CHECK(sSent.count == 1 && sSent.text == "EQ_ECM/purchase" && sSent.flag);
	}
}

// --- Slice 25: equipment, pylons, parcels and passengers, comms, fines, trade-in factor, renovation,
// view offsets, trumbles (bead oo-hu1xk) -----------------------------------------------------------

// The counts read the members; the trade-in factor stays within 75..100; the view offsets come from
// the bounding box, and the weapon view offset follows the facing.
OO_TEST(slice25CountsTradeInAndViewOffsets)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		cxx::PlayerEntity *part = player->_cxxPlayer;
		OO_CHECK([player parcelCount] == 0 && [player passengerCount] == 0 && [player trumbleCount] == 0);
		part->max_passengers = 3;
		OO_CHECK([player passengerCapacity] == 3);
		part->ship_trade_in_factor = 90;
		[player adjustTradeInFactorBy:5];
		OO_CHECK([player tradeInFactor] == 95);
		[player adjustTradeInFactorBy:50];
		OO_CHECK([player tradeInFactor] == 100);
		[player adjustTradeInFactorBy:-50];
		OO_CHECK([player tradeInFactor] == 75);
		player->_cxxEntity->boundingBox.min = make_vector(-10.0f, -2.0f, -20.0f);
		player->_cxxEntity->boundingBox.max = make_vector(10.0f, 2.0f, 40.0f);
		[player setDefaultViewOffsets];
		OO_CHECK(NearV(part->forwardViewOffset, make_vector(0.0f, 0.0f, 10.0f)));
		OO_CHECK(NearV(part->aftViewOffset, make_vector(0.0f, 0.0f, 10.0f)));
		OO_CHECK(NearV(part->portViewOffset, make_vector(0.0f, 0.0f, 0.0f)));
		OO_CHECK(NearV(part->customViewOffset, kZeroVector));
		part->aftViewOffset = make_vector(1.0f, 2.0f, 3.0f);
		player->_cxxShip->currentWeaponFacing = WEAPON_FACING_AFT;
		OO_CHECK(NearV([player weaponViewOffset], make_vector(1.0f, 2.0f, 3.0f)));
	}
}

// --- Slice 26: trumble values, checksums, screen modes, target memory, missile ident, rotating and
// panning the custom view (bead oo-cpam5) ----------------------------------------------------------

// The appetite and the flags read and write the members; clearing the target memory fills it with
// empty slots; zooming the custom view out scales its offset about the rotation centre, limited by
// the collision radius.
OO_TEST(slice26TargetMemoryAndCustomViewZoom)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		cxx::PlayerEntity *part = player->_cxxPlayer;
		[player setTrumbleAppetiteAccumulator:2.5f];
		OO_CHECK([player trumbleAppetiteAccumulator] == 2.5f);
		[player suppressTargetLost];
		OO_CHECK(part->suppressTargetLost);
		[player setScoopsActive];
		OO_CHECK([player testScoopsActive]);
		[player clearTargetMemory];
		OO_CHECK([player cxx_targetMemory].size() == PLAYER_TARGET_MEMORY_SIZE && [player testTargetMemoryIndex] == 0);
		[player setCustomViewRotationCenter:make_vector(0.0f, 0.0f, 1.0f)];
		[player setCustomViewOffset:make_vector(0.0f, 0.0f, 3.0f)];
		OO_CHECK(NearV([player customViewRotationCenter], make_vector(0.0f, 0.0f, 1.0f)));
		player->_cxxEntity->collision_radius = 10.0f;
		[player customViewZoomOut:2.0f];
		OO_CHECK(NearV([player customViewOffset], make_vector(0.0f, 0.0f, 5.0f)));
		player->_cxxEntity->collision_radius = 0.01f;
		[player customViewZoomOut:2.0f];
		OO_CHECK(NearV([player customViewOffset], make_vector(0.0f, 0.0f, 1.0f + CUSTOM_VIEW_MAX_ZOOM_OUT * 0.01f)));
	}
}

// --- Slice 27: custom view vectors and data, the mission overlay and background, world scripts and
// script events, galactic hyperspace, jump cause, names (bead oo-u1e9m) ------------------------------

// The custom view data follow the quaternion; the galactic hyperspace behaviour accepts only known
// values; the fixed coordinates are clamped; scoop override turns the scoops on; the names read and
// write the members.
OO_TEST(slice27CustomViewHyperspaceAndNames)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		[player setCustomViewQuaternion:kIdentityQuaternion];
		OO_CHECK(NearV([player customViewForwardVector], vector_forward_from_quaternion(kIdentityQuaternion)));
		OO_CHECK(NearV([player customViewUpVector], vector_up_from_quaternion(kIdentityQuaternion)));
		OO_CHECK(NearV([player customViewRightVector], vector_right_from_quaternion(kIdentityQuaternion)));
		OO_CHECK(![player scriptsLoaded] && [player cxx_worldScriptNames].empty());
		[player setGalacticHyperspaceBehaviour:GALACTIC_HYPERSPACE_BEHAVIOUR_FIXED_COORDINATES];
		OO_CHECK([player galacticHyperspaceBehaviour] == GALACTIC_HYPERSPACE_BEHAVIOUR_FIXED_COORDINATES);
		[player setGalacticHyperspaceBehaviour:GALACTIC_HYPERSPACE_BEHAVIOUR_UNKNOWN];
		OO_CHECK([player galacticHyperspaceBehaviour] == GALACTIC_HYPERSPACE_BEHAVIOUR_FIXED_COORDINATES);
		[player setGalacticHyperspaceFixedCoords:NSMakePoint(300.0, 12.4)];
		OO_CHECK(Near([player galacticHyperspaceFixedCoords], NSMakePoint(255, 12)));
		[player setMissionExitScreen:GUI_SCREEN_STATUS];
		OO_CHECK([player missionExitScreen] == GUI_SCREEN_STATUS);
		[player setScoopOverride:YES];
		OO_CHECK([player scoopOverride] && sSent.count == 1);
		[player cxx_setCommanderName:std::string("Jameson")];
		[player cxx_setLastsaveName:std::string("save1")];
		[player cxx_setJumpCause:std::string("standard jump")];
		OO_CHECK([player cxx_commanderName] == std::optional<std::string>("Jameson"));
		OO_CHECK([player cxx_lastsaveName] == std::optional<std::string>("save1"));
		OO_CHECK([player cxx_jumpCause] == std::optional<std::string>("standard jump"));
	}
}

// --- Slice 28: docking clearance, scanned wormholes, mission destinations, the shipyard record, extra
// mission and GUI-screen keys, the state dump (bead oo-zn1vy) ---------------------------------------

// Cleared to dock once granted or not required; a marker's key is its system and name; the extra
// mission keys are cleared.
OO_TEST(slice28ClearanceMarkerKeyAndExtraKeys)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		cxx::PlayerEntity *part = player->_cxxPlayer;
		part->dockingClearanceStatus = DOCKING_CLEARANCE_STATUS_REQUESTED;
		OO_CHECK(![player clearedToDock] && [player getDockingClearanceStatus] == DOCKING_CLEARANCE_STATUS_REQUESTED);
		part->dockingClearanceStatus = DOCKING_CLEARANCE_STATUS_GRANTED;
		OO_CHECK([player clearedToDock]);
		part->dockingClearanceStatus = DOCKING_CLEARANCE_STATUS_NOT_REQUIRED;
		OO_CHECK([player clearedToDock]);
		const oo::PList marker(oo::PList::Dict{ { "system", oo::PList(7) }, { "name", oo::PList(std::string("beacon")) } });
		OO_CHECK([player markerKey:marker] == std::optional<std::string>("7-beacon"));
		OO_CHECK([player markerKey:oo::PList(oo::PList::Dict{})] == std::optional<std::string>("0-(null)"));
		part->extraMissionKeys["oolite-mission-key"] = oo::PList();
		[player clearExtraMissionKeys];
		OO_CHECK(part->extraMissionKeys.empty());
		OO_CHECK([player cxx_shipyardRecord] == &part->shipyard_record);
		OO_CHECK([player cxx_scannedWormholes].empty());
	}
}

// --- The category files (the Convert-to-C++20 batch, bead oo-lmdi8): PlayerEntitySound.mm,
// PlayerEntityStickMapper.mm, PlayerEntityControls.mm, PlayerEntityKeyMapper.mm,
// PlayerEntityLegacyScriptEngine.mm, PlayerEntityContracts.mm, PlayerEntityLoadSave.mm. Each case
// pins units a player in a never-initialised universe can answer, written against the Objective-C
// categories and run on them first; the screens, the controls' polling and the load / save panels
// read the GUI, the keyboard or the game's files, which the goldens cover. ------------------------

@interface PlayerEntity (TestCategories)
- (std::string) hwToString:(int)hwFlags;
- (BOOL) entryIsCustomEquip:(const std::string &)entry;
- (BOOL) entryIsDictCustomEquip:(const oo::PList &)dict;
- (std::optional<std::string>) getCustomEquipKeyDefType:(const std::string &)key_def;
- (BOOL) compareKeyEntries:(const oo::PList &)first second:(const oo::PList &)second;
- (int) findIndexOfCommander:(const std::string &)cdrName;
- (void) set:(const std::string &)missionvariable_value;
- (void) reset:(const std::string &)missionvariable;
- (void) increment:(const std::string &)missionVariableObject;
- (void) decrement:(const std::string &)missionVariableObject;
- (oo::PList) credits_number;
- (void) cxx_setMissionScreenID:(const std::optional<std::string> &)msid;
- (std::optional<std::string>) cxx_missionScreenID;
- (void) clearMissionScreenID;
- (NSUInteger) cxx_eqScriptIndexForKey:(const std::string &)eq_key;
- (void) handleButtonIdent;
@end


namespace {
Entity *sCategoryTarget = nil;	// what a CategoryPlayer answers as its primary target (not retained)
}


/*	A recording player whose script events, roles, missiles and ident sounds only count, so that a
	category unit's own logic is what the case sees (sends to self stay sends after the move).
*/
@interface CategoryPlayer: RecordingPlayer
@end


@implementation CategoryPlayer

- (void) cxx_doScriptEvent:(ooscript::PropertyId)message withPListArguments:(const std::vector<oo::PList> &)arguments
{
	sSent.count++; sSent.number = (int)arguments.size();
}


- (void) cxx_addRoleToPlayer:(const std::string &)role
{
	sSent.count++; sSent.text = role;
}


- (void) safeAllMissiles	{ sSent.count++; }
- (void) noteLostTarget	{ sSent.count++; }
- (void) playIdentOn	{ sSent.count++; sSent.flag = true; }
- (void) playIdentLockedOn	{ sSent.count++; }
- (void) printIdentLockedOnForMissile:(BOOL)missile	{ sSent.count++; sSent.number = missile ? 1 : 2; }

// The target the ident button finds: the unit test's universe has no descriptions to expand the
// "ident-on" message with (expanding one exits), so the case keeps a target.
- (id) primaryTarget	{ return sCategoryTarget; }

@end


namespace {

// A string value's text; a value that is not a string never matches.
std::string StringOf(const oo::PList &value)
{
	const std::string *text = value.getIf<std::string>();
	return text != nullptr ? *text : std::string("<not a string>");
}


CategoryPlayer *MakeCategoryPlayer()
{
	sSent = Sent();
	gOOPlayer = nil;
	return [[[CategoryPlayer alloc] init] autorelease];
}

}	// namespace


// PlayerEntitySound.mm (bead oo-xowh): with no interface source playing, the player is not beeping.
OO_TEST(soundIsNotBeepingWithNothingPlaying)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		OO_CHECK(![player isBeeping]);
	}
}


// PlayerEntityStickMapper.mm (bead oo-ibm8): hardware flags as words, and the GUI entries the
// function list is made of (a long description cut to 28 units and "...", absent functions left out).
OO_TEST(stickMapperHardwareAndGuiDicts)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		OO_CHECK([player hwToString:HW_AXIS] == "axis");
		OO_CHECK([player hwToString:HW_BUTTON] == "button");
		OO_CHECK([player hwToString:HW_AXIS | HW_BUTTON] == "axis/button");
		const oo::PList dict = [player makeStickGuiDict:"Roll" allowable:HW_AXIS axisfn:3 butfn:-1];
		OO_CHECK(dict.get<std::string>(std::string(KEY_GUIDESC)) == "Roll");
		OO_CHECK(dict.get<long long>(std::string(KEY_ALLOWABLE)) == HW_AXIS && dict.get<long long>(std::string(KEY_AXISFN)) == 3);
		OO_CHECK(dict.find(KEY_BUTTONFN) == nullptr);
		const std::string longName(60, 'x');
		const oo::PList cut = [player makeStickGuiDict:longName allowable:HW_BUTTON axisfn:-1 butfn:4];
		OO_CHECK(cut.get<std::string>(std::string(KEY_GUIDESC)) == std::string(28, 'x') + "...");
		OO_CHECK(cut.find(KEY_AXISFN) == nullptr && cut.get<long long>(std::string(KEY_BUTTONFN)) == 4);
		const oo::PList header = [player makeStickGuiDictHeader:"Flight"];
		OO_CHECK(header.get<std::string>(std::string(KEY_HEADER)) == "Flight" && header.get<std::string>(std::string(KEY_AXISFN)).empty());
	}
}


// PlayerEntityControls.mm slice 1 (bead oo-hsilb): the first key code of a definition (0 for none),
// and clearing the planet search string.
OO_TEST(controlsSlice1FirstKeyCodeAndPlanetSearch)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		const oo::PList keyDef(oo::PList::Array{ oo::PList(oo::PList::Dict{ { "key", oo::PList(65) } }), oo::PList(oo::PList::Dict{ { "key", oo::PList(66) } }) });
		OO_CHECK([player getFirstKeyCode:keyDef] == 65);
		OO_CHECK([player getFirstKeyCode:oo::PList(oo::PList::Array{})] == 0);
		player->_cxxPlayer->planetSearchString = std::string("Lave");
		[player clearPlanetSearchString];
		OO_CHECK(!player->_cxxPlayer->planetSearchString.has_value());
	}
}

// PlayerEntityControls.mm slices 2-6 (beads oo-56tmj, oo-4216h, oo-n8wn2, oo-uq8px, oo-fz3l8) have
// no unit case: every unit polls the keyboard, the joystick or the GUI, which the goldens cover.

// PlayerEntityControls.mm slice 7 (bead oo-lmdi8): the ident button safes the missiles, engages
// ident and, with a target, plays the locked-on sound and prints the lock (not for a missile);
// pressed again it first drops the target.
OO_TEST(controlsSlice7IdentButton)
{
	@autoreleasepool
	{
		SetUp();
		CategoryPlayer *player = MakeCategoryPlayer();
		sCategoryTarget = player;
		[player handleButtonIdent];
		OO_CHECK(player->_cxxPlayer->ident_engaged);
		OO_CHECK(sSent.count == 3 && !sSent.flag && sSent.number == 2);
		sSent = Sent();
		[player handleButtonIdent];
		OO_CHECK(sSent.count == 4 && !sSent.flag);
		sCategoryTarget = nil;
	}
}


// PlayerEntityKeyMapper.mm slice 1 (bead oo-5uo7): the key-function list's GUI entries (a long
// description cut to 48 units and "...").
OO_TEST(keyMapperSlice1GuiDicts)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		const oo::PList dict = [player makeKeyGuiDict:"Fire laser" keyDef:"key_fire_lasers"];
		OO_CHECK(dict.get<std::string>(std::string(KEY_KC_GUIDESC)) == "Fire laser");
		OO_CHECK(dict.get<std::string>(std::string(KEY_KC_DEFINITION)) == "key_fire_lasers");
		const oo::PList cut = [player makeKeyGuiDict:std::string(51, 'y') keyDef:"k"];
		OO_CHECK(cut.get<std::string>(std::string(KEY_KC_GUIDESC)) == std::string(48, 'y') + "...");
		const oo::PList header = [player makeKeyGuiDictHeader:"Navigation"];
		OO_CHECK(header.get<std::string>(std::string(KEY_KC_HEADER)) == "Navigation");
		OO_CHECK(header.get<std::string>(std::string(KEY_KC_DEFINITION)).empty());
	}
}


// PlayerEntityKeyMapper.mm slice 2 (bead oo-10jz): custom-equipment entries are activate_ and mode_
// keys, and their key-definition type.
OO_TEST(keyMapperSlice2CustomEquipEntries)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		OO_CHECK([player entryIsCustomEquip:"activate_EQ_ECM"] && [player entryIsCustomEquip:"mode_EQ_ECM"]);
		OO_CHECK(![player entryIsCustomEquip:"key_ecm"]);
		OO_CHECK([player entryIsDictCustomEquip:oo::PList(oo::PList::Dict{ { std::string(KEY_KC_DEFINITION), oo::PList(std::string("mode_EQ_X")) } })]);
		OO_CHECK(![player entryIsDictCustomEquip:oo::PList(oo::PList::Dict{})]);
		OO_CHECK([player getCustomEquipKeyDefType:"activate_EQ_ECM"] == std::optional<std::string>(std::string(CUSTOMEQUIP_KEYACTIVATE)));
		OO_CHECK([player getCustomEquipKeyDefType:"mode_EQ_ECM"] == std::optional<std::string>(std::string(CUSTOMEQUIP_KEYMODE)));
		OO_CHECK([player getCustomEquipKeyDefType:"key_ecm"] == std::optional<std::string>(std::string()));
	}
}


// PlayerEntityKeyMapper.mm slice 3 (bead oo-mofd): two key entries are the same when the key and
// the three modifiers are.
OO_TEST(keyMapperSlice3CompareKeyEntries)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		const oo::PList a(oo::PList::Dict{ { "key", oo::PList(65) }, { "shift", oo::PList(true) } });
		const oo::PList b(oo::PList::Dict{ { "key", oo::PList(std::string("65")) }, { "shift", oo::PList(true) } });
		const oo::PList c(oo::PList::Dict{ { "key", oo::PList(65) } });
		OO_CHECK([player compareKeyEntries:a second:a]);
		OO_CHECK([player compareKeyEntries:a second:b]);
		OO_CHECK(![player compareKeyEntries:a second:c]);
		OO_CHECK(![player compareKeyEntries:c second:oo::PList(oo::PList::Dict{ { "key", oo::PList(66) } })]);
	}
}


// PlayerEntityLegacyScriptEngine.mm slice 1 (bead oo-130j): mission variables need the store
// (nothing is kept before set-up); a null value removes one; local variables are per mission.
OO_TEST(legacyScriptSlice1MissionAndLocalVariables)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		player->_cxxPlayer->mission_variables = oo::PList();
		[player cxx_setMissionVariable:oo::PList(std::string("1")) forKey:"mission_x"];
		OO_CHECK([player cxx_missionVariableForKey:"mission_x"].isNull());
		player->_cxxPlayer->mission_variables = oo::PList(oo::PList::Dict{});
		[player cxx_setMissionVariable:oo::PList(std::string("1")) forKey:"mission_x"];
		OO_CHECK(StringOf([player cxx_missionVariableForKey:"mission_x"]) == "1");
		OO_CHECK([player cxx_missionVariables].count() == 1);
		[player cxx_setMissionVariable:oo::PList() forKey:"mission_x"];
		OO_CHECK([player cxx_missionVariableForKey:"mission_x"].isNull());
		[player setLocalVariable:std::string("7") forKey:"local_y" andMission:std::string("m1")];
		OO_CHECK([player localVariableForKey:"local_y" andMission:std::string("m1")] == std::optional<std::string>("7"));
		OO_CHECK(![player localVariableForKey:"local_y" andMission:std::string("m2")].has_value());
		OO_CHECK(![player localVariableForKey:"local_y" andMission:std::nullopt].has_value());
		OO_CHECK([player localVariablesForMission:std::nullopt].isNull());
	}
}


// PlayerEntityLegacyScriptEngine.mm slice 2 (bead oo-ng9h): the credits query answers the balance.
OO_TEST(legacyScriptSlice2CreditsQuery)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		[player setCreditBalance:42.5];
		const oo::PList credits = [player credits_number];
		OO_CHECK(credits.isNumber() && credits.doubleValue() == 42.5);
	}
}


// PlayerEntityLegacyScriptEngine.mm slice 3 (bead oo-z1nv): set:, increment:, decrement: and reset:
// on a mission variable, and the mission title.
OO_TEST(legacyScriptSlice3VariableArithmeticAndTitle)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		player->_cxxPlayer->mission_variables = oo::PList(oo::PList::Dict{});
		[player set:"mission_count 5"];
		OO_CHECK(StringOf([player cxx_missionVariableForKey:"mission_count"]) == "5");
		[player increment:"mission_count"];
		OO_CHECK(StringOf([player cxx_missionVariableForKey:"mission_count"]) == "6");
		[player decrement:"mission_count"];
		[player decrement:"mission_count"];
		OO_CHECK(StringOf([player cxx_missionVariableForKey:"mission_count"]) == "4");
		[player set:"no_prefix 1"];
		OO_CHECK([player cxx_missionVariableForKey:"no_prefix"].isNull());
		[player reset:"mission_count"];
		OO_CHECK([player cxx_missionVariableForKey:"mission_count"].isNull());
		[player cxx_setMissionTitle:std::string("A title")];
		OO_CHECK([player cxx_missionTitle] == std::optional<std::string>("A title"));
		[player cxx_setMissionTitle:std::nullopt];
		OO_CHECK(![player cxx_missionTitle].has_value());
	}
}


// PlayerEntityLegacyScriptEngine.mm slice 4 (bead oo-vn3o): the mission screen's identifier, and
// the index of an equipment script that is not there (the count).
OO_TEST(legacyScriptSlice4MissionScreenIDAndEqScripts)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		[player cxx_setMissionScreenID:std::string("screen-1")];
		OO_CHECK([player cxx_missionScreenID] == std::optional<std::string>("screen-1"));
		[player clearMissionScreenID];
		OO_CHECK(![player cxx_missionScreenID].has_value());
		OO_CHECK([player cxx_eqScriptIndexForKey:"EQ_NONE"] == player->_cxxPlayer->eqScripts.size());
	}
}


// PlayerEntityContracts.mm slice 1 (bead oo-6e3h): a passenger is added once (a risky one adds the
// courier role, and the event is sent with two arguments) and removed by name; contracted volume
// counts a good's contracts; the docking report joins messages with a blank line.
OO_TEST(contractsSlice1PassengersVolumeAndReport)
{
	@autoreleasepool
	{
		SetUp();
		CategoryPlayer *player = MakeCategoryPlayer();
		player->_cxxPlayer->max_passengers = 2;
		OO_CHECK([player cxx_addPassenger:"Ann" start:1 destination:2 eta:100.0 fee:10.0 advance:1.0 risk:2]);
		OO_CHECK(sSent.count == 2 && sSent.text == "trader-courier+" && sSent.number == 2);
		OO_CHECK(![player cxx_addPassenger:"Ann" start:1 destination:2 eta:100.0 fee:10.0 advance:1.0 risk:0]);
		OO_CHECK(player->_cxxPlayer->passengers.size() == 1);
		OO_CHECK(![player cxx_removePassenger:"Bob"]);
		OO_CHECK([player cxx_removePassenger:"Ann"] && player->_cxxPlayer->passengers.empty());
		player->_cxxPlayer->contracts.push_back(oo::PList(oo::PList::Dict{ { std::string(CARGO_KEY_TYPE), oo::PList(std::string("food")) }, { std::string(CARGO_KEY_AMOUNT), oo::PList(3) } }));
		player->_cxxPlayer->contracts.push_back(oo::PList(oo::PList::Dict{ { std::string(CARGO_KEY_TYPE), oo::PList(std::string("food")) }, { std::string(CARGO_KEY_AMOUNT), oo::PList(4) } }));
		OO_CHECK([player cxx_contractedVolumeForGood:"food"] == 7 && [player cxx_contractedVolumeForGood:"gold"] == 0);
		player->_cxxPlayer->dockingReport.clear();
		[player cxx_addMessageToReport:"one"];
		[player cxx_addMessageToReport:""];
		[player cxx_addMessageToReport:"two"];
		OO_CHECK(player->_cxxPlayer->dockingReport == "one\n\ntwo");
	}
}


// PlayerEntityContracts.mm slice 2 (bead oo-t2t5): with no record each reputation is the middle of
// its range (unknown counts as the maximum), and the record is a dictionary.
OO_TEST(contractsSlice2Reputation)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		player->_cxxPlayer->reputation.clear();
		OO_CHECK([player passengerReputation] == MAX_CONTRACT_REP / 2);
		OO_CHECK([player parcelReputation] == MAX_CONTRACT_REP / 2);
		OO_CHECK([player contractReputation] == MAX_CONTRACT_REP / 2);
		OO_CHECK([player reputation].isDict());
	}
}


// PlayerEntityContracts.mm slice 3 (bead oo-oo99): a ship with all its subentities loses nothing.
OO_TEST(contractsSlice3MissingSubEntities)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		OO_CHECK([player missingSubEntitiesAdjustment] == 0);
	}
}


// PlayerEntityLoadSave.mm slice 1 (bead oo-xmvt) has no unit case: its units read the save files,
// the scenarios and the GUI, which the goldens cover.

// PlayerEntityLoadSave.mm slice 2 (bead oo-rczn): a commander is found by its save name, else its
// name; one not in the list is not found.
OO_TEST(loadSaveSlice2FindCommander)
{
	@autoreleasepool
	{
		SetUp();
		RecordingPlayer *player = MakeRecordingPlayer();
		player->_cxxPlayer->cdrDetailArray.clear();
		OO_CHECK([player findIndexOfCommander:"Jameson"] == -1);
		player->_cxxPlayer->cdrDetailArray.push_back(oo::PList(oo::PList::Dict{ { "player_name", oo::PList(std::string("Jameson")) } }));
		player->_cxxPlayer->cdrDetailArray.push_back(oo::PList(oo::PList::Dict{ { "player_save_name", oo::PList(std::string("Other")) }, { "player_name", oo::PList(std::string("Jameson")) } }));
		OO_CHECK([player findIndexOfCommander:"Jameson"] == 0);
		OO_CHECK([player findIndexOfCommander:"Other"] == 1);
		player->_cxxPlayer->cdrDetailArray.clear();
	}
}


OO_TEST_MAIN()
