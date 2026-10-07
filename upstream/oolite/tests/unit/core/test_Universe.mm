/*	test_Universe.mm
	Unit tests for Universe (src/Core/Universe.h), the game's world: bead oo-riqmz, slice 1 of
	docs/phases/3-slices/Universe.md (the class shell).

	-initWithGameView: needs the whole game (a window, the resources, the player), so the test links
	the whole game but main (tests/unit/core/meson.build entry ['*'], ADR-0056 amendment oo-44gg)
	and uses Universes that were never initialised, as the entity tests do: zeroed, as the runtime
	zeroed the ivars. The drawing is pinned by the goldens, not here. The expectations were written
	against the Objective-C API and run on the unconverted class first: the state a universe starts
	with, the settings and flags a headless universe can answer and their clamping, the post-FX and
	colour-blind modes, and the public members other classes read directly (the entity list, the
	collision lists, the cursor row, the ambient star light), which go through the small block of
	helpers below, the one place that knows where they live. The conversion ported two things:
	those helpers, which read the members through the facade's _cxxUniverse, and the set-up, which
	gives each never-initialised universe the C++ part -initWithGameView: makes first (ADR-0056
	amendment oo-riqmz). The last case pins the crossing: oo::ToCxx / oo::ToObjC, the accessors
	over the members, a new part's zeroes, and a universe released with no part.
	Run: bash tools/check-core-tests.sh
*/

#import "Universe.h"
#import "PlayerEntity.h"

#include "oo_test.hpp"


// main.mm defines the debug flags, and the test has its own main.
#ifndef NDEBUG
uint32_t gDebugFlags = 0;
#endif

extern Universe *gSharedUniverse;


namespace {

// A Universe that was never initialised, made UNIVERSE (-setAmbientLightLevel: asserts there is one).
Universe *NewUniverse()
{
	Universe *universe = (Universe *)class_createInstance([Universe class], 0);	// never released
	universe->_cxxUniverse = oo::makeRef<cxx::Universe>(universe);	// what -initWithGameView: makes first
	gSharedUniverse = universe;
	return universe;
}


// The members other classes read directly: since the conversion, through the facade's _cxxUniverse
// (ADR-0056 amendment oo-riqmz).
unsigned EntityListCount(Universe *u)		{ return u->_cxxUniverse->n_entities; }
Entity *SortedEntity(Universe *u, unsigned i)	{ return u->_cxxUniverse->sortedEntities[i]; }
int CursorRow(Universe *u)					{ return u->_cxxUniverse->cursor_row; }
GLfloat StarsAmbient(Universe *u, int i)	{ return u->_cxxUniverse->stars_ambient[i]; }
bool ListHeadsEmpty(Universe *u)			{ return u->_cxxUniverse->x_list_start == nil && u->_cxxUniverse->y_list_start == nil && u->_cxxUniverse->z_list_start == nil; }

}	// namespace


OO_TEST(defaults)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();

		OO_CHECK([u sessionID] == 0);
		OO_CHECK(![u doingStartUp]);
		OO_CHECK([u entityCount] == 0);
		OO_CHECK([u getTime] == 0.0 && [u getTimeDelta] == 0.0);
		OO_CHECK([u currentSystemID] == 0);
		OO_CHECK([u viewDirection] == VIEW_FORWARD);
		OO_CHECK([u ambientLightLevel] == 0.0f);
		OO_CHECK([u airResistanceFactor] == 0.0f);
		GLfloat *sky = [u skyClearColor];
		OO_CHECK(sky[0] == 0.0f && sky[1] == 0.0f && sky[2] == 0.0f && sky[3] == 0.0f);

		OO_CHECK([u detailLevel] == DETAIL_LEVEL_MINIMUM);
		OO_CHECK([u reducedDetail] && ![u useShaders]);
		OO_CHECK(![u bloom]);
		OO_CHECK([u currentPostFX] == OO_POSTFX_NONE && [u colorblindMode] == OO_POSTFX_NONE);

		OO_CHECK(![u displayGUI] && ![u displayFPS]);
		OO_CHECK(![u autoSave] && ![u autoSaveNow] && ![u wireframeGraphics]);
		OO_CHECK(![u doProcedurallyTexturedPlanets]);
		OO_CHECK(![u ECMVisualFXEnabled]);
		OO_CHECK([u framesDoneThisUpdate] == 0);
		OO_CHECK(![u pauseMessageVisible]);
		OO_CHECK(![u permanentCommLog] && ![u permanentMessageLog] && ![u autoMessageLogBg]);
		OO_CHECK(![u witchspaceBreakPattern] && ![u dockingClearanceProtocolActive]);
		OO_CHECK([u breakPatternOver]);
#ifndef NDEBUG
		OO_CHECK([u timeAccelerationFactor] == 0.0);	// the zeroed ivar; -initWithGameView: never set it
#else
		OO_CHECK([u timeAccelerationFactor] == 1.0);
#endif
	}
}


OO_TEST(publicMembers)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();

		OO_CHECK(EntityListCount(u) == 0);
		OO_CHECK(SortedEntity(u, 0) == nil && SortedEntity(u, UNIVERSE_MAX_ENTITIES) == nil);
		OO_CHECK(ListHeadsEmpty(u));
		OO_CHECK(CursorRow(u) == 0);
		OO_CHECK(StarsAmbient(u, 0) == 0.0f && StarsAmbient(u, 3) == 0.0f);
	}
}


OO_TEST(lightAndAir)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();

		[u setAmbientLightLevel:3.5f];
		OO_CHECK([u ambientLightLevel] == 3.5f);
		[u setAmbientLightLevel:12.0f];
		OO_CHECK([u ambientLightLevel] == 10.0f);	// clamped to 0 ... 10
		[u setAmbientLightLevel:-1.0f];
		OO_CHECK([u ambientLightLevel] == 0.0f);

		[u setAirResistanceFactor:0.25f];
		OO_CHECK([u airResistanceFactor] == 0.25f);
		[u setAirResistanceFactor:2.0f];
		OO_CHECK([u airResistanceFactor] == 1.0f);	// clamped to 0 ... 1
		[u setAirResistanceFactor:-1.0f];
		OO_CHECK([u airResistanceFactor] == 0.0f);

		// The sky colour's alpha is also the air resistance, clamped there but not in the colour.
		[u setSkyColorRed:0.1f green:0.2f blue:0.3f alpha:0.5f];
		GLfloat *sky = [u skyClearColor];
		OO_CHECK(sky[0] == 0.1f && sky[1] == 0.2f && sky[2] == 0.3f && sky[3] == 0.5f);
		OO_CHECK([u airResistanceFactor] == 0.5f);
		[u setSkyColorRed:0.0f green:0.0f blue:0.0f alpha:3.0f];
		OO_CHECK(sky[3] == 3.0f && [u airResistanceFactor] == 1.0f);
		OO_CHECK(sky == [u skyClearColor]);	// the live array
	}
}


OO_TEST(postFX)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();

		[u setCurrentPostFX:OO_POSTFX_COLORBLINDNESS_DEUTER];
		OO_CHECK([u currentPostFX] == OO_POSTFX_COLORBLINDNESS_DEUTER && [u colorblindMode] == OO_POSTFX_COLORBLINDNESS_DEUTER);

		// A non-colour-blind effect leaves the colour-blind mode, which ending the effect restores.
		[u setCurrentPostFX:OO_POSTFX_CLOAK];
		OO_CHECK([u currentPostFX] == OO_POSTFX_CLOAK && [u colorblindMode] == OO_POSTFX_COLORBLINDNESS_DEUTER);
		[u terminatePostFX:OO_POSTFX_GRAYSCALE];	// not the current one: nothing
		OO_CHECK([u currentPostFX] == OO_POSTFX_CLOAK);
		[u terminatePostFX:OO_POSTFX_CLOAK];
		OO_CHECK([u currentPostFX] == OO_POSTFX_COLORBLINDNESS_DEUTER);

		// Out of range (and 0) is none, which is also the colour-blind mode none.
		[u setCurrentPostFX:OO_POSTFX_ENDOFLIST];
		OO_CHECK([u currentPostFX] == OO_POSTFX_NONE && [u colorblindMode] == OO_POSTFX_NONE);
		[u setCurrentPostFX:OO_POSTFX_CRT];
		[u setCurrentPostFX:-3];
		OO_CHECK([u currentPostFX] == OO_POSTFX_NONE && [u colorblindMode] == OO_POSTFX_NONE);

		// The colour-blind modes cycle through none, protan, deuter, tritan.
		OO_CHECK([u nextColorblindMode:OO_POSTFX_NONE] == OO_POSTFX_COLORBLINDNESS_PROTAN);
		OO_CHECK([u nextColorblindMode:OO_POSTFX_COLORBLINDNESS_TRITAN] == OO_POSTFX_NONE);
		OO_CHECK([u prevColorblindMode:OO_POSTFX_NONE] == OO_POSTFX_COLORBLINDNESS_TRITAN);
		OO_CHECK([u prevColorblindMode:OO_POSTFX_COLORBLINDNESS_DEUTER] == OO_POSTFX_COLORBLINDNESS_PROTAN);

		// Bloom needs the extras detail level; a universe never initialised is at the minimum.
		[u setBloom:YES];
		OO_CHECK(![u bloom]);
	}
}


OO_TEST(flags)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();

		[u setDisplayFPS:7];
		OO_CHECK([u displayFPS] == YES);	// normalised
		[u setAutoSaveNow:YES];
		OO_CHECK([u autoSaveNow]);
		[u setPauseMessageVisible:YES];
		OO_CHECK([u pauseMessageVisible]);
		[u setPermanentMessageLog:YES];
		[u setAutoMessageLogBg:2];
		[u setPermanentCommLog:YES];
		OO_CHECK([u permanentMessageLog] && [u autoMessageLogBg] == YES && [u permanentCommLog]);
		[u setWitchspaceBreakPattern:2];
		OO_CHECK([u witchspaceBreakPattern] == YES);
		[u setECMVisualFXEnabled:YES];
		OO_CHECK([u ECMVisualFXEnabled]);
		[u resetFramesDoneThisUpdate];
		OO_CHECK([u framesDoneThisUpdate] == 0);

#ifndef NDEBUG
		[u setTimeAccelerationFactor:2.0];
		OO_CHECK([u timeAccelerationFactor] == 2.0);
		[u setTimeAccelerationFactor:TIME_ACCELERATION_FACTOR_MAX * 2];
		OO_CHECK([u timeAccelerationFactor] == TIME_ACCELERATION_FACTOR_DEFAULT);
		[u setTimeAccelerationFactor:TIME_ACCELERATION_FACTOR_MIN / 2];
		OO_CHECK([u timeAccelerationFactor] == TIME_ACCELERATION_FACTOR_DEFAULT);
#endif

		// Each universe has its own state.
		Universe *other = NewUniverse();
		OO_CHECK(![other displayFPS] && ![other pauseMessageVisible] && [u displayFPS]);
	}
}


// Since the conversion: the facade and its C++ part (ADR-0056 amendment oo-riqmz).
OO_TEST(facadeAndPart)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		cxx::Universe *part = oo::ToCxx(u);
		OO_CHECK(part != nullptr && part == u->_cxxUniverse.get());
		OO_CHECK(oo::ToObjC(part) == u);
		OO_CHECK(oo::ToCxx(static_cast<Universe *>(nil)) == nullptr && oo::ToObjC(static_cast<cxx::Universe *>(nullptr)) == nil);

		// The accessors answer the part's members, and the setters set them.
		[u setAmbientLightLevel:2.5f];
		OO_CHECK(part->ambientLightLevel == 2.5f);
		part->universal_time = 42.0;
		part->_sessionID = 3;
		OO_CHECK([u getTime] == 42.0 && [u sessionID] == 3);
		[u setCurrentPostFX:OO_POSTFX_COLORBLINDNESS_TRITAN];
		OO_CHECK(part->_currentPostFX == OO_POSTFX_COLORBLINDNESS_TRITAN && part->_colorblindMode == OO_POSTFX_COLORBLINDNESS_TRITAN);

		// A new part is zeroed, as the runtime zeroed the ivars.
		oo::Ref<cxx::Universe> fresh = oo::makeRef<cxx::Universe>(nil);
		OO_CHECK(fresh->n_entities == 0 && fresh->x_list_start == nil && fresh->gameView == nil);
		OO_CHECK(fresh->sortedEntities[UNIVERSE_MAX_ENTITIES] == nil && fresh->frustum[5][3] == 0.0f);
		OO_CHECK(fresh->entities.empty() && fresh->demo_ships.isNull() && !fresh->currentMessage.has_value());
		OO_CHECK(oo::ToObjC(fresh.get()) == nil);

		// A universe released before -initWithGameView: made its part tears nothing down (oo-s6ic6):
		// the shared universe stays.
		Universe *unused = [Universe alloc];
		OO_CHECK(oo::ToCxx(unused) == nullptr);
		[unused release];
		OO_CHECK(gSharedUniverse == u);
	}
}


// Slices 2-13 of docs/phases/3-slices/Universe.md (beads oo-27jxj ... oo-0uz9w): the units a
// universe that was never initialised can answer, written against the Objective-C API and run on
// the unconverted class first. Slice 3 (pausing, quitting and the set-up from a station or
// witchspace) needs the player, the GUI and the game controller, and is pinned by the goldens.

OO_TEST(slice2StartUpFlagsAddOnsAndEntityList)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		cxx::Universe *part = oo::ToCxx(u);

		part->_doingStartUp = YES;
		part->_sessionID = 7;
		OO_CHECK([u doingStartUp] && [u sessionID] == 7);

		// The add-ons in use: a universe never initialised has the empty string, not none.
		std::optional<std::string> addOns = [u cxx_useAddOns];
		OO_CHECK(addOns.has_value() && addOns->empty());
		part->useAddOns = "strict";
		OO_CHECK([u cxx_useAddOns] == std::optional<std::string>("strict"));
		// The same add-ons without forcing: nothing to reinitialise, YES.
		OO_CHECK([u cxx_setUseAddOns:"strict" fromSaveGame:YES]);
		OO_CHECK([u cxx_setUseAddOns:"strict" fromSaveGame:NO forceReinit:NO]);
		OO_CHECK(part->useAddOns == "strict");

		OO_CHECK([u entityCount] == 0 && [u cxx_entityList].empty());

		// The colour-blind modes step through the four in both directions, and wrap.
		int mode = OO_POSTFX_NONE;
		for (int i = 0; i < 4; i++)  mode = [u nextColorblindMode:mode];
		OO_CHECK(mode == OO_POSTFX_NONE);
		for (int i = 0; i < 4; i++)  mode = [u prevColorblindMode:mode];
		OO_CHECK(mode == OO_POSTFX_NONE);
		OO_CHECK([u nextColorblindMode:OO_POSTFX_COLORBLINDNESS_PROTAN] == OO_POSTFX_COLORBLINDNESS_DEUTER);

		// Bloom is the flag at the extras detail level only.
		[u setBloom:YES];
		OO_CHECK(part->_bloom == YES && ![u bloom]);
	}
}


OO_TEST(slice4PopulatorSettings)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		cxx::Universe *part = oo::ToCxx(u);

		OO_CHECK([u cxx_getPopulatorSettings].isNull());	// none until cleared or set
		OO_CHECK(![u deterministicPopulation]);
		part->deterministic_population = YES;
		OO_CHECK([u deterministicPopulation]);

		[u cxx_setPopulatorSetting:"pirates" to:oo::PList(std::string("some"))];
		oo::PList settings = [u cxx_getPopulatorSettings];
		OO_CHECK(settings.isDict() && settings.getIf<oo::PList::Dict>()->size() == 1);
		OO_CHECK(settings.find("pirates") != nullptr && settings.get<std::string>("pirates") == "some");

		// A null setting removes the key.
		[u cxx_setPopulatorSetting:"traders" to:oo::PList(std::string("more"))];
		[u cxx_setPopulatorSetting:"pirates" to:oo::PList()];
		settings = [u cxx_getPopulatorSettings];
		OO_CHECK(settings.getIf<oo::PList::Dict>()->size() == 1 && settings.find("pirates") == nullptr && settings.find("traders") != nullptr);

		[u clearSystemPopulator];
		settings = [u cxx_getPopulatorSettings];
		OO_CHECK(settings.isDict() && settings.getIf<oo::PList::Dict>()->empty());
	}
}


OO_TEST(slice5MainLightPosition)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		cxx::Universe *part = oo::ToCxx(u);

		[u setMainLightPosition:make_vector(1.0f, -2.0f, 3.5f)];
		OO_CHECK(part->main_light_position[0] == 1.0f && part->main_light_position[1] == -2.0f);
		OO_CHECK(part->main_light_position[2] == 3.5f && part->main_light_position[3] == 1.0f);

		[u setAmbientLightLevel:4.0f];
		OO_CHECK([u ambientLightLevel] == 4.0f && part->ambientLightLevel == 4.0f);
	}
}


OO_TEST(slice6CoordinateSystemStrings)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();

		// Anything but four tokens is the origin, not an error.
		HPVector v = [u cxx_coordinatesFromCoordinateSystemString:"wpu 1 2"];
		OO_CHECK(v.x == 0.0 && v.y == 0.0 && v.z == 0.0);
		v = [u cxx_coordinatesFromCoordinateSystemString:""];
		OO_CHECK(v.x == 0.0 && v.y == 0.0 && v.z == 0.0);
		v = [u cxx_coordinatesFromCoordinateSystemString:"wpu 1 2 3 4"];
		OO_CHECK(v.x == 0.0 && v.y == 0.0 && v.z == 0.0);
	}
}


OO_TEST(slice7RoleCategoriesAndFlags)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		cxx::Universe *part = oo::ToCxx(u);

		OO_CHECK(![u cxx_roleIsPirateVictim:"trader"]);	// no categories loaded
		part->roleCategories = oo::PList(oo::PList::Dict{
			{"oolite-pirate-victim", oo::PList(oo::PList::Array{oo::PList(std::string("trader")), oo::PList(std::string("courier"))})},
			{"oolite-hunters", oo::PList(oo::PList::Array{oo::PList(std::string("hunter"))})},
		});
		OO_CHECK([u cxx_roleIsPirateVictim:"trader"] && [u cxx_roleIsPirateVictim:"courier"]);
		OO_CHECK(![u cxx_roleIsPirateVictim:"hunter"] && ![u cxx_roleIsPirateVictim:""]);
		OO_CHECK([u cxx_role:"hunter" isInCategory:"oolite-hunters"]);
		OO_CHECK(![u cxx_role:"hunter" isInCategory:"oolite-nothing"]);

		// No witchpoint buoy among no entities: the minimum.
		OO_CHECK([u safeWitchspaceExitDistance] == MIN_DISTANCE_TO_BUOY);

		part->_dockingClearanceProtocolActive = YES;
		OO_CHECK([u dockingClearanceProtocolActive]);
		[u setWitchspaceBreakPattern:NO];
		OO_CHECK(![u witchspaceBreakPattern]);
	}
}


OO_TEST(slice8StationsAndPlanets)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();

		// No sun: no main station is looked for; no planets, no stations.
		OO_CHECK([u station] == nil && [u planet] == nil);
		OO_CHECK([u cxx_planets].empty() && [u cxx_stations].empty());
		OO_CHECK([u cxx_stationWithRole:"" andPosition:make_HPvector(0, 0, 0)] == nil);
		OO_CHECK([u cxx_stationWithRole:"coriolis" andPosition:make_HPvector(0, 0, 0)] == nil);
	}
}


OO_TEST(slice9BeaconsWaypointsBreakPatternAndAIs)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		cxx::Universe *part = oo::ToCxx(u);

		OO_CHECK([u firstBeacon] == nil && [u lastBeacon] == nil);
		[u resetBeacons];
		OO_CHECK([u firstBeacon] == nil && [u lastBeacon] == nil);
		OO_CHECK([u cxx_wormholes].empty() && [u cxx_currentWaypoints].empty());

		part->breakPatternCounter = 3;
		OO_CHECK(![u breakPatternOver]);
		OO_CHECK([u breakPatternHide]);	// no player
		part->breakPatternCounter = 0;
		OO_CHECK([u breakPatternOver]);

		OO_CHECK(![u defaultAIForRole:"pirate"].has_value());
		part->autoAIMap = oo::PList(oo::PList::Dict{{"pirate", oo::PList(std::string("pirateAI.plist"))}});
		OO_CHECK([u defaultAIForRole:"pirate"] == std::optional<std::string>("pirateAI.plist"));
		OO_CHECK(![u defaultAIForRole:"trader"].has_value());

		[u setSkyColorRed:0.5f green:0.25f blue:0.125f alpha:0.75f];
		OO_CHECK(part->skyClearColor[0] == 0.5f && part->skyClearColor[3] == 0.75f && [u airResistanceFactor] == 0.75f);
	}
}


OO_TEST(slice10GameViewAndCommodities)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();

		OO_CHECK([u gameView] == nil && [u gameController] == nil);
		[u setGameView:nil];
		OO_CHECK([u gameView] == nil);
		OO_CHECK([u commodities] == nil);
	}
}


OO_TEST(slice11ViewFrustum)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		cxx::Universe *part = oo::ToCxx(u);

		// A zeroed frustum: every plane's distance is 0, which a sphere of radius r > 0 is not behind.
		OO_CHECK([u viewFrustumIntersectsSphereAt:make_vector(1.0f, 2.0f, 3.0f) withRadius:1.0f]);
		OO_CHECK(![u viewFrustumIntersectsSphereAt:make_vector(1.0f, 2.0f, 3.0f) withRadius:0.0f]);

		// One plane, x >= 0 (the others pass everything): a sphere is outside only when wholly behind it.
		for (int p = 0; p < 6; p++)
		{
			part->frustum[p][0] = part->frustum[p][1] = part->frustum[p][2] = 0.0f;
			part->frustum[p][3] = 1000.0f;
		}
		part->frustum[2][0] = 1.0f;
		part->frustum[2][3] = 0.0f;
		OO_CHECK([u viewFrustumIntersectsSphereAt:make_vector(5.0f, 0.0f, 0.0f) withRadius:1.0f]);
		OO_CHECK([u viewFrustumIntersectsSphereAt:make_vector(-0.5f, 0.0f, 0.0f) withRadius:1.0f]);
		OO_CHECK(![u viewFrustumIntersectsSphereAt:make_vector(-5.0f, 0.0f, 0.0f) withRadius:1.0f]);
	}
}


OO_TEST(slice12FrameCounterAndViewMatrix)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		cxx::Universe *part = oo::ToCxx(u);

		part->framesDoneThisUpdate = 4;
		OO_CHECK([u framesDoneThisUpdate] == 4);
		[u resetFramesDoneThisUpdate];
		OO_CHECK([u framesDoneThisUpdate] == 0 && part->framesDoneThisUpdate == 0);

		part->viewMatrix = kIdentityMatrix;
		OO_CHECK(OOMatrixEqual([u viewMatrix], kIdentityMatrix));
	}
}


OO_TEST(slice13EntityLookUp)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();

		// No target, an empty slot and out of range are nil; 100 is the player's.
		OO_CHECK([u entityForUniversalID:NO_TARGET] == nil);
		OO_CHECK([u entityForUniversalID:MIN_ENTITY_UID + 1] == nil);
		OO_CHECK([u entityForUniversalID:MAX_ENTITY_UID + 1] == nil);
		OO_CHECK([u entityForUniversalID:100] == PLAYER);

		// No demo ships among no entities: the demo ship is cleared.
		[u removeDemoShips];
		OO_CHECK(oo::ToCxx(u)->demo_ship == nil && [u entityCount] == 0);
	}
}


OO_TEST_MAIN()
