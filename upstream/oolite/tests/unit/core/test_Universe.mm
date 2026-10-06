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
	helpers below, the one place that knows where they live.
	Run: bash tools/check-core-tests.sh
*/

#import "Universe.h"

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
	gSharedUniverse = universe;
	return universe;
}


// The members other classes read directly.
unsigned EntityListCount(Universe *u)		{ return u->n_entities; }
Entity *SortedEntity(Universe *u, unsigned i)	{ return u->sortedEntities[i]; }
int CursorRow(Universe *u)					{ return u->cursor_row; }
GLfloat StarsAmbient(Universe *u, int i)	{ return u->stars_ambient[i]; }
bool ListHeadsEmpty(Universe *u)			{ return u->x_list_start == nil && u->y_list_start == nil && u->z_list_start == nil; }

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


OO_TEST_MAIN()
