/*	test_OOJSShip.mm
	Unit tests for the ship JS binding (src/Core/Scripting/OOJSShip.h/.mm): the test-first half of
	its slice beads (oo-18mg2, slice 1 of docs/phases/3-slices/OOJSShip.md, and the slices after
	it), converted the way bead oo-ppc converted OOJSVector (proposed ADR-0056, amendments oo-ppc,
	oo-luhd, oo-ft5n and oo-9ht.139).

	The Ship object is made by the real engine for a real ship, so the test links every game object
	but main's (tests/unit/core/meson.build entry ['*'], as test_OOJSPlayerShip does) and runs the
	binding in the engine's own context. The ship is a ShipEntity set up by ShipEntity's own
	-setUpShipFromDictionary: from a definition in the test (PlainShip, as test_ShipEntity.mm's),
	in a Universe that was never initialised and with a plain entity as PLAYER (amendment oo-bj8
	item 11); the player branches of the getter read the engine's own player, whose class the test
	swaps for a subclass that answers -availableFacings and -fleeingStatus itself. The expectations
	were written against the Objective-C file and run on it first; slice 1 pins the property
	getter (every property) and the weapon offsets and colours its helpers give JavaScript.
	Run: bash tools/check-core-tests.sh test_OOJSShip
*/

#import "OOJavaScriptEngine.h"
#import "OOJSShip.h"
#import "OOJSPlayer.h"
#import "Universe.h"
#import "ShipEntity.h"
#import "PlayerEntity.h"
#import "ResourceManager.h"
#import "EntityOOJavaScriptExtensions.h"
#include "oofnd/FileSystem.hpp"
#include "oofnd/String.hpp"
#include "oo_test.hpp"

#include <objc/runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <process.h>
#include <string>


// What UNIVERSE and PLAYER read (Universe.mm, PlayerEntity.mm).
extern Universe *gSharedUniverse;
extern PlayerEntity *gOOPlayer;


// main.mm defines the debug flags, and the test has its own main.
#ifndef NDEBUG
uint32_t gDebugFlags = 0;
#endif


// MARK: The stand-ins -----------------------------------------------------------------------------

// PLAYER while ships are made (test_ShipEntity.mm's).
@interface TestPlayer: Entity
@end


@implementation TestPlayer

- (HPVector) viewpointPosition	{ return kZeroHPVector; }

@end


// A ship that keeps ShipEntity's own set-up (test_ShipEntity.mm's).
@interface PlainShip: ShipEntity
@end


@implementation PlainShip
@end


namespace {

OOWeaponFacingSet sAvailableFacings = 0;
OOPlayerFleeingStatus sFleeingStatus = PLAYER_FLEEING_NONE;

}	// namespace


// The engine's player, with the two answers the getter's player branches ask for set by the test.
@interface TestPlayerShip: PlayerEntity
@end


@implementation TestPlayerShip

- (OOWeaponFacingSet) availableFacings  { return sAvailableFacings; }
- (OOPlayerFleeingStatus) fleeingStatus  { return sFleeingStatus; }

@end


namespace {

namespace stdfs = std::filesystem;

stdfs::path sRoot;
PlayerEntity *sRealPlayer = nil;
PlainShip *sShip = nil;


// The definition the test's ship is set up from.
oo::PList ShipDefinition()
{
	return oo::PList(oo::PList::Dict{
		{ "name", oo::PList(std::string("Viper")) },
		{ "ship_name", oo::PList(std::string("Bob")) },
		{ "display_name", oo::PList(std::string("Police Viper")) },
		{ "roles", oo::PList(std::string("police trader")) },
		{ "scan_class", oo::PList(std::string("CLASS_POLICE")) },
		{ "scan_description", oo::PList(std::string("Cop")) },
		{ "max_flight_speed", oo::PList(300.0) },
		{ "max_flight_roll", oo::PList(3.0) },
		{ "max_flight_pitch", oo::PList(1.5) },
		{ "max_flight_yaw", oo::PList(0.5) },
		{ "thrust", oo::PList(20.0) },
		{ "injector_burn_rate", oo::PList(0.5) },
		{ "injector_speed_factor", oo::PList(4.0) },
		{ "max_energy", oo::PList(500.0) },
		{ "energy_recharge_rate", oo::PList(4.0) },
		{ "weapon_facings", oo::PList(5) },
		{ "max_missiles", oo::PList(3) },
		{ "max_cargo", oo::PList(20) },
		{ "extra_cargo", oo::PList(5) },
		{ "accuracy", oo::PList(3.0) },
		{ "fuel", oo::PList(70) },
		{ "heat_insulation", oo::PList(1.5) },
		{ "beacon", oo::PList(std::string("B")) },
		{ "beacon_label", oo::PList(std::string("Beacon B")) },
		{ "reaction_time", oo::PList(2.0) },
		{ "sun_glare_filter", oo::PList(0.5) },
		{ "scanner_range", oo::PList(30000.0) },
		{ "hyperspace_motor_spin_time", oo::PList(10.0) },
		{ "escorts", oo::PList(4) },
		{ "script_info", oo::PList(oo::PList::Dict{ { "a", oo::PList(1) } }) },
		{ "weapon_mount_mode", oo::PList(std::string("multiply")) },
		{ "weapon_position_forward", oo::PList(oo::PList::Array{ oo::PList(std::string("1 0 0")), oo::PList(std::string("-1 0 0")) }) },
		{ "weapon_position_aft", oo::PList(std::string("0 0 -2")) },
		{ "scanner_display_color1", oo::PList(std::string("redColor")) },
		{ "scanner_display_color2", oo::PList(oo::PList::Array{ oo::PList(0.0), oo::PList(0.5), oo::PList(1.0) }) },
		{ "exhaust_emissive_color", oo::PList(std::string("greenColor")) },
	});
}


// The scratch home and game folder, the engine, the universe, PLAYER and the ship; made once.
void SetUp()
{
	if (!sRoot.empty())  return;
	std::setvbuf(stdout, nullptr, _IONBF, 0);	// a crash keeps the results so far
	sRoot = stdfs::temp_directory_path() / ("oo-test-jsship-" + std::to_string(static_cast<unsigned long>(::_getpid())));
	stdfs::remove_all(sRoot);
	stdfs::create_directories(sRoot / "Resources");
	OO_CHECK(::_putenv_s("HOMEPATH", sRoot.string().c_str()) == 0);
	stdfs::current_path(sRoot);
	const std::string info = "{ CFBundleVersion = \"9.9.9-test\"; }";
	OO_CHECK(oo::fs::writeFile(sRoot / "Resources" / "Info-gnustep.plist", oo::Data(info.data(), info.size()), oo::fs::WriteMode::direct).has_value());
	[ResourceManager cxx_setUseAddOns:std::string(SCENARIO_OXP_DEFINITION_NONE)];	// strict: the built-in Resources alone
	(void)[OOJavaScriptEngine sharedEngine];

	sRealPlayer = gOOPlayer;	// the one InitOOJSPlayerShip() made, which player.ship holds
	object_setClass(sRealPlayer, [TestPlayerShip class]);
	sRealPlayer->_cxxEntity->isPlayer = true;	// what the player's set-up sets, which the engine's player has not run

	Universe *universe = (Universe *)class_createInstance([Universe class], 0);	// never released
	universe->_cxxUniverse = oo::makeRef<cxx::Universe>(universe);	// what -initWithGameView: makes first (ADR-0056 amendment oo-riqmz)
	gSharedUniverse = universe;
	gOOPlayer = (PlayerEntity *)[[TestPlayer alloc] init];

	sShip = [[PlainShip alloc] cxx_initWithKey:"jsship" definition:ShipDefinition()];
	OO_CHECK(sShip != nil);
	[sShip setTemperature:64.0f];
	[sShip setDestination:make_HPvector(1, 2, 3)];
	[sShip setDesiredSpeed:100];
	[sShip setDesiredRange:500];
	[sShip setVelocity:make_vector(4, 5, 6)];
	[sShip setHomeSystem:7];
	[sShip setDestinationSystem:9];
	[sShip setScriptedMisjump:YES];
	[sShip setScriptedMisjumpRange:0.75f];
	[sShip setSpeed:50];
	[sShip setReportAIMessages:YES];
	[sShip setTrackCloseContacts:YES];
	[sShip setAIScriptWakeTime:12.5];
	[sShip setBounty:25 withReason:kOOLegalStatusReasonSetup];
}


// Evaluates src in the engine's context, with the test's ship as the global `ship`, and gives its
// result as a string ("undefined", "null", ...), or "threw: <message>".
std::string Eval(const std::string &src)
{
	SetUp();
	ooscript::Context context = OOJSAcquireContext();
	ooscript::Object global = [[OOJavaScriptEngine sharedEngine] globalObject];
	ooscript::Value shipValue = OOJSValueFromNativeObject(context, sShip);
	ooscript::setProperty(context, global, "ship", &shipValue);
	std::string wrapped = "(function () { try { return String(" + src + "); } catch (e) { return 'threw: ' + (e && e.message !== undefined ? e.message : e); } })()";
	ooscript::Value result = ooscript::undefinedValue();
	std::string text;
	if (!ooscript::evaluateScript(context, global, wrapped.c_str(), static_cast<unsigned>(wrapped.size()), "test.js", 1, &result))
	{
		ooscript::clearPendingException(context);
		text = "<evaluation failed>";
	}
	else
	{
		text = cxx_OOStringFromJSValue(context, result).value_or("<not a string>");
	}
	OOJSRelinquishContext(context);
	return text;
}


std::string EvalShown(const std::string &src, const std::string &expected)
{
	std::string result = Eval(src);
	if (result != expected)  std::printf("    %s\n    gave: %s\n", src.c_str(), result.c_str());
	return result;
}
#define OO_CHECK_EVAL(src, expected)  OO_CHECK_EQ(EvalShown(src, expected), expected)

}	// namespace


// MARK: Slice 1: the property getter and its helpers (bead oo-18mg2) -----------------------------

OO_TEST(registration)
{
	SetUp();
	OO_CHECK(std::strcmp(JSShipClass()->name, "Ship") == 0);
	OO_CHECK(JSShipPrototype() != nullptr);
	OO_CHECK_EVAL("typeof ship", "object");
	OO_CHECK_EVAL("ship instanceof Ship", "true");
	OO_CHECK_EVAL("Ship.prototype.name", "undefined");	// the prototype has no ship
}


OO_TEST(getterNamesAndRoles)
{
	SetUp();
	OO_CHECK_EVAL("ship.name", "Viper");
	OO_CHECK_EVAL("ship.displayName", "Police Viper");
	OO_CHECK_EVAL("ship.shipUniqueName", "Bob");
	OO_CHECK_EVAL("ship.shipClassName", "Viper");
	OO_CHECK_EVAL("ship.scanDescription", "Cop");
	OO_CHECK_EVAL("JSON.stringify(ship.roles)", "[\"[jsship]\",\"police\",\"trader\"]");	// the ship's key is one of its roles
	OO_CHECK_EVAL("JSON.stringify(ship.roleWeights)", "{\"[jsship]\":1,\"police\":1,\"trader\":1}");
	OO_CHECK_EVAL("ship.primaryRole", "police");
	OO_CHECK_EVAL("ship.dataKey", "jsship");
	OO_CHECK_EVAL("ship.beaconCode", "B");
	OO_CHECK_EVAL("ship.beaconLabel", "Beacon B");
	OO_CHECK_EVAL("ship.isBeacon", "true");
	OO_CHECK_EVAL("ship.entityPersonality === ship.entityPersonality && typeof ship.entityPersonality", "number");
}


OO_TEST(getterAIAndTargets)
{
	SetUp();
	OO_CHECK_EVAL("ship.AI", "<no AI>");	// no AI plist to load in the test's game
	OO_CHECK_EVAL("ship.AIState", "null");
	OO_CHECK_EVAL("ship.AIFoundTarget", "null");
	OO_CHECK_EVAL("ship.AIPrimaryAggressor", "null");
	OO_CHECK_EVAL("ship.hasSuspendedAI", "false");
	OO_CHECK_EVAL("ship.alertCondition", "2");
	OO_CHECK_EVAL("ship.autoAI", "true");
	OO_CHECK_EVAL("ship.autoWeapons", "false");
	OO_CHECK_EVAL("ship.target", "null");
	OO_CHECK_EVAL("JSON.stringify(ship.defenseTargets)", "[]");
	OO_CHECK_EVAL("ship.potentialCollider", "null");
	OO_CHECK_EVAL("ship.hasHostileTarget", "false");
	OO_CHECK_EVAL("ship.reportAIMessages", "true");
	OO_CHECK_EVAL("ship.script", "null");
	OO_CHECK_EVAL("ship.AIScript", "null");
	OO_CHECK_EVAL("ship.AIScriptWakeTime", "12.5");
	OO_CHECK_EVAL("JSON.stringify(ship.scriptInfo)", "{\"a\":1}");
	OO_CHECK_EVAL("ship.trackCloseContacts", "true");
	OO_CHECK_EVAL("ship.markedForFines", "false");
	OO_CHECK_EVAL("ship.withinStationAegis", "false");
}


OO_TEST(getterFlight)
{
	SetUp();
	OO_CHECK_EVAL("ship.accuracy", "3");
	OO_CHECK_EVAL("ship.fuel", "7");
	OO_CHECK_EVAL("ship.fuelChargeRate", "1");
	OO_CHECK_EVAL("ship.bounty", "0");	// a police ship keeps no bounty
	OO_CHECK_EVAL("ship.temperature", "0.25");
	OO_CHECK_EVAL("ship.heatInsulation", "1.5");
	OO_CHECK_EVAL("ship.heading", "(0, 0, 1)");
	OO_CHECK_EVAL("ship.energyRechargeRate", "4");
	OO_CHECK_EVAL("ship.speed", "50");
	OO_CHECK_EVAL("ship.cruiseSpeed", "240");
	OO_CHECK_EVAL("ship.desiredRange", "500");
	OO_CHECK_EVAL("ship.desiredSpeed", "100");
	OO_CHECK_EVAL("ship.destination", "(1, 2, 3)");
	OO_CHECK_EVAL("ship.maxEscorts", "4");
	OO_CHECK_EVAL("ship.maxPitch", "1.5");
	OO_CHECK_EVAL("ship.maxSpeed", "300");
	OO_CHECK_EVAL("ship.maxRoll", "3");
	OO_CHECK_EVAL("ship.maxYaw", "0.5");
	OO_CHECK_EVAL("ship.injectorBurnRate", "0.5");
	OO_CHECK_EVAL("ship.injectorSpeedFactor", "4");
	OO_CHECK_EVAL("ship.maxThrust", "20");
	OO_CHECK_EVAL("ship.thrust", "20");
	OO_CHECK_EVAL("ship.lightsActive", "true");
	OO_CHECK_EVAL("ship.vectorRight", "(1, 0, 0)");
	OO_CHECK_EVAL("ship.vectorForward", "(0, 0, 1)");
	OO_CHECK_EVAL("ship.vectorUp", "(0, 1, 0)");
	OO_CHECK_EVAL("ship.velocity", "(4, 5, 56)");	// with the thrust of its speed
	OO_CHECK_EVAL("ship.thrustVector", "(0, 0, 50)");
	OO_CHECK_EVAL("ship.pitch", "0");
	OO_CHECK_EVAL("ship.roll", "0");
	OO_CHECK_EVAL("ship.yaw", "0");
	OO_CHECK_EVAL("ship.boundingBox", "(0, 0, 0)");
	OO_CHECK_EVAL("ship.savedCoordinates", "(0, 0, 0)");
	OO_CHECK_EVAL("ship.subEntityRotation", "(1 + 0i + 0j + 0k)");
	OO_CHECK_EVAL("ship.hasHyperspaceMotor", "true");
	OO_CHECK_EVAL("ship.hyperspaceSpinTime", "10");
	OO_CHECK_EVAL("ship.scriptedMisjump", "true");
	OO_CHECK_EVAL("ship.scriptedMisjumpRange", "0.75");
	OO_CHECK_EVAL("ship.sunGlareFilter", "0.5");
	OO_CHECK_EVAL("ship.destinationSystem", "9");
	OO_CHECK_EVAL("ship.homeSystem", "7");
	OO_CHECK_EVAL("ship.scannerRange", "30000");
	OO_CHECK_EVAL("ship.reactionTime", "2");
}


OO_TEST(getterKind)
{
	SetUp();
	OO_CHECK_EVAL("ship.isPirate", "false");
	OO_CHECK_EVAL("ship.isPolice", "true");
	OO_CHECK_EVAL("ship.isThargoid", "false");
	OO_CHECK_EVAL("ship.isTurret", "false");
	OO_CHECK_EVAL("ship.isTrader", "false");
	OO_CHECK_EVAL("ship.isPirateVictim", "false");
	OO_CHECK_EVAL("ship.isMissile", "false");
	OO_CHECK_EVAL("ship.isMine", "false");
	OO_CHECK_EVAL("ship.isWeapon", "false");
	OO_CHECK_EVAL("ship.isRock", "false");
	OO_CHECK_EVAL("ship.isMinable", "false");
	OO_CHECK_EVAL("ship.isBoulder", "false");
	OO_CHECK_EVAL("ship.isFleeing", "false");
	OO_CHECK_EVAL("ship.isCargo", "false");
	OO_CHECK_EVAL("ship.isDerelict", "false");
	OO_CHECK_EVAL("ship.isPiloted", "false");	// no crew
	OO_CHECK_EVAL("ship.isFrangible", "true");
	OO_CHECK_EVAL("ship.isCloaked", "false");
	OO_CHECK_EVAL("ship.cloakAutomatic", "true");
	OO_CHECK_EVAL("ship.isJamming", "false");
}


OO_TEST(getterCargoAndCrew)
{
	SetUp();
	OO_CHECK_EVAL("ship.cargoSpaceCapacity", "20");
	OO_CHECK_EVAL("ship.cargoSpaceUsed", "0");
	OO_CHECK_EVAL("ship.cargoSpaceAvailable", "20");
	OO_CHECK_EVAL("JSON.stringify(ship.cargoList)", "[]");
	OO_CHECK_EVAL("ship.extraCargo", "5");
	OO_CHECK_EVAL("ship.commodity", "null");
	OO_CHECK_EVAL("ship.commodityAmount", "0");
	OO_CHECK_EVAL("JSON.stringify(ship.crew)", "null");
	OO_CHECK_EVAL("ship.passengerCount", "0");
	OO_CHECK_EVAL("ship.parcelCount", "0");
	OO_CHECK_EVAL("ship.passengerCapacity", "0");
	OO_CHECK_EVAL("JSON.stringify(ship.passengers)", "[]");
	OO_CHECK_EVAL("JSON.stringify(ship.parcels)", "[]");
	OO_CHECK_EVAL("JSON.stringify(ship.contracts)", "[]");
	OO_CHECK_EVAL("ship.dockingInstructions", "null");
}


OO_TEST(getterGroupsAndSubentities)
{
	SetUp();
	OO_CHECK_EVAL("JSON.stringify(ship.escorts)", "[]");	// its escort group holds only itself
	OO_CHECK_EVAL("ship.group", "null");
	OO_CHECK_EVAL("ship.escortGroup.name + ' ' + ship.escortGroup.count + ' ' + (ship.escortGroup.leader === ship)", "escort group 1 true");
	OO_CHECK_EVAL("JSON.stringify(ship.subEntities)", "[]");
	OO_CHECK_EVAL("JSON.stringify(ship.exhausts)", "[]");
	OO_CHECK_EVAL("JSON.stringify(ship.flashers)", "[]");
	OO_CHECK_EVAL("ship.subEntityCapacity", "0");
	OO_CHECK_EVAL("JSON.stringify(ship.collisionExceptions)", "[]");
}


OO_TEST(getterWeaponsAndEquipment)
{
	SetUp();
	OO_CHECK_EVAL("ship.weaponRange", "0");
	OO_CHECK_EVAL("ship.weaponFacings", "5");
	OO_CHECK_EVAL("String(ship.weaponPositionAft)", "(0, 0, 0)");	// a lone string is not a mount list in multiply mode
	OO_CHECK_EVAL("String(ship.weaponPositionForward)", "(1, 0, 0),(-1, 0, 0)");
	OO_CHECK_EVAL("String(ship.weaponPositionPort)", "(0, 0, 0)");
	OO_CHECK_EVAL("String(ship.weaponPositionStarboard)", "(0, 0, 0)");
	OO_CHECK_EVAL("ship.weaponPositionForward[1] instanceof Vector3D", "true");
	OO_CHECK_EVAL("JSON.stringify(ship.equipment)", "[]");
	OO_CHECK_EVAL("ship.currentWeapon", "null");
	OO_CHECK_EVAL("ship.forwardWeapon", "null");
	OO_CHECK_EVAL("ship.aftWeapon", "null");
	OO_CHECK_EVAL("ship.portWeapon", "null");
	OO_CHECK_EVAL("ship.starboardWeapon", "null");
	OO_CHECK_EVAL("ship.laserHeatLevel", "0");
	OO_CHECK_EVAL("ship.laserHeatLevelAft", "0");
	OO_CHECK_EVAL("ship.laserHeatLevelForward", "0");
	OO_CHECK_EVAL("ship.laserHeatLevelPort", "0");
	OO_CHECK_EVAL("ship.laserHeatLevelStarboard", "0");
	OO_CHECK_EVAL("JSON.stringify(ship.missiles)", "[]");
	OO_CHECK_EVAL("ship.missileCapacity", "3");
	OO_CHECK_EVAL("ship.missileLoadTime", "2");
}


OO_TEST(getterColours)
{
	SetUp();
	OO_CHECK_EVAL("JSON.stringify(ship.scannerDisplayColor1)", "[1,0,0,1]");
	OO_CHECK_EVAL("JSON.stringify(ship.scannerDisplayColor2)", "[0,0.5,1,1]");
	OO_CHECK_EVAL("ship.scannerHostileDisplayColor1", "null");
	OO_CHECK_EVAL("ship.scannerHostileDisplayColor2", "null");
	OO_CHECK_EVAL("JSON.stringify(ship.exhaustEmissiveColor)", "[0,1,0,1]");
}


// The player's ship reads two answers of PlayerEntity's own.
OO_TEST(getterPlayerBranches)
{
	SetUp();
	sAvailableFacings = WEAPON_FACING_FORWARD | WEAPON_FACING_AFT;
	OO_CHECK_EVAL("player.ship.weaponFacings", "3");
	sFleeingStatus = PLAYER_FLEEING_CARGO;
	OO_CHECK_EVAL("player.ship.isFleeing", "true");
	sFleeingStatus = PLAYER_FLEEING_MAYBE;
	OO_CHECK_EVAL("player.ship.isFleeing", "false");
	sFleeingStatus = PLAYER_FLEEING_NONE;
	OO_CHECK_EVAL("player.ship.isPiloted", "true");
}


OO_TEST(cleanUp)
{
	stdfs::current_path(stdfs::temp_directory_path());
	std::error_code ignored;
	stdfs::remove_all(sRoot, ignored);
	OO_CHECK(true);
}


OO_TEST_MAIN()
