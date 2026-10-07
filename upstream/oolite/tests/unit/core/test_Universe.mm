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


// Slice 14 (bead oo-7jhs5): demo ships, safe vectors, hazards on route, laser hits. Written against
// the Objective-C API and run on the unconverted class first. The entities sit in the universe's
// sorted list by hand (no -addEntity:, which needs the whole game).

// PLAYER: a stand-in (OOGetPlayer() asserts there is a player, and an entity's position is kept
// relative to the player's viewpoint, as test_Entity's TestPlayer). It answers the player
// messages the tests reach as an absent player's nil did.
@interface UniverseTestPlayer: Entity
@end

@implementation UniverseTestPlayer
- (HPVector) viewpointPosition	{ return kZeroHPVector; }
- (id) dockedStation			{ return nil; }
@end


@class PlayerEntity;
extern PlayerEntity *gOOPlayer;

namespace {

void SetUpTestPlayer()
{
	static Entity *player = nil;
	if (player == nil)  player = [[UniverseTestPlayer alloc] init];	// never released, as the player is not
	gOOPlayer = (PlayerEntity *)player;
}


void SetSortedEntities(Universe *u, std::initializer_list<Entity *> list)
{
	unsigned n = 0;
	for (Entity *e : list)  u->_cxxUniverse->sortedEntities[n++] = e;
	u->_cxxUniverse->sortedEntities[n] = nil;
	u->_cxxUniverse->n_entities = n;
}


Entity *MakeEntity(HPVector position, GLfloat radius)
{
	SetUpTestPlayer();
	Entity *entity = [[[Entity alloc] init] autorelease];
	[entity setPosition:position];
	[entity setCollisionRadius:radius];
	return entity;
}

}	// namespace


@interface Slice14GhostEntity: Entity	// an entity nothing collides with
@end

@implementation Slice14GhostEntity
- (BOOL) canCollide	{ return NO; }
@end


OO_TEST(slice14NoEntity)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		HPVector p2 = make_HPvector(0, 0, 1000);

		OO_CHECK(![u isVectorClearFromEntity:nil toDistance:0 fromPoint:p2]);
		OO_CHECK([u hazardOnRouteFromEntity:nil toDistance:0 fromPoint:p2] == nil);
		OO_CHECK(HPvector_equal([u getSafeVectorFromEntity:nil toDistance:0 fromPoint:p2], kZeroHPVector));
		OO_CHECK([u firstShipHitByLaserFromShip:nil inDirection:WEAPON_FACING_FORWARD offset:kZeroVector gettingRangeFound:NULL] == nil);
		// The demo ship needs a docked player; with none there is no ship.
		SetUpTestPlayer();
		OO_CHECK([u cxx_makeDemoShipWithRole:"oolite-test" spinning:YES] == nil);
	}
}


OO_TEST(slice14ClearRoute)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		Entity *e1 = MakeEntity(make_HPvector(0, 0, 0), 10);
		HPVector p2 = make_HPvector(0, 0, 1000);

		// Nothing else in the universe: clear, no hazard, the destination is safe as it is.
		SetSortedEntities(u, { e1 });
		OO_CHECK([u isVectorClearFromEntity:e1 toDistance:0 fromPoint:p2]);
		OO_CHECK([u hazardOnRouteFromEntity:e1 toDistance:0 fromPoint:p2] == nil);
		OO_CHECK(HPvector_equal([u getSafeVectorFromEntity:e1 toDistance:0 fromPoint:p2], p2));

		// An entity off the route, behind the start, or beyond the destination is no hazard.
		Entity *aside = MakeEntity(make_HPvector(500, 0, 500), 50);
		Entity *behind = MakeEntity(make_HPvector(0, 0, -300), 50);
		Entity *beyond = MakeEntity(make_HPvector(0, 0, 1500), 50);
		SetSortedEntities(u, { e1, aside, behind, beyond });
		OO_CHECK([u isVectorClearFromEntity:e1 toDistance:0 fromPoint:p2]);
		OO_CHECK([u hazardOnRouteFromEntity:e1 toDistance:0 fromPoint:p2] == nil);
		OO_CHECK(HPvector_equal([u getSafeVectorFromEntity:e1 toDistance:0 fromPoint:p2], p2));

		// An entity nothing collides with is no hazard either.
		Entity *ghost = [[[Slice14GhostEntity alloc] init] autorelease];
		[ghost setPosition:make_HPvector(0, 0, 500)];
		[ghost setCollisionRadius:50];
		SetSortedEntities(u, { e1, ghost });
		OO_CHECK([u isVectorClearFromEntity:e1 toDistance:0 fromPoint:p2]);
		OO_CHECK([u hazardOnRouteFromEntity:e1 toDistance:0 fromPoint:p2] == nil);
		u->_cxxUniverse->n_entities = 0;
	}
}


OO_TEST(slice14Hazard)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		Entity *e1 = MakeEntity(make_HPvector(0, 0, 0), 10);
		Entity *rock = MakeEntity(make_HPvector(20, 0, 500), 50);
		HPVector p2 = make_HPvector(0, 0, 1000);
		SetSortedEntities(u, { e1, rock });

		OO_CHECK(![u isVectorClearFromEntity:e1 toDistance:0 fromPoint:p2]);
		OO_CHECK([u hazardOnRouteFromEntity:e1 toDistance:0 fromPoint:p2] == rock);

		// The safe vector steers short of the rock and away from the side it is on.
		HPVector safe = [u getSafeVectorFromEntity:e1 toDistance:0 fromPoint:p2];
		OO_CHECK(!HPvector_equal(safe, p2));
		OO_CHECK(safe.z < 500 && safe.x < 20);

		// Within range of the destination already: clear, whatever is in the way.
		OO_CHECK([u isVectorClearFromEntity:e1 toDistance:2000 fromPoint:p2]);
		OO_CHECK([u hazardOnRouteFromEntity:e1 toDistance:2000 fromPoint:p2] == nil);

		// Stopping short of the rock: the route is clear.
		OO_CHECK([u isVectorClearFromEntity:e1 toDistance:600 fromPoint:p2]);
		OO_CHECK([u hazardOnRouteFromEntity:e1 toDistance:600 fromPoint:p2] == nil);
		u->_cxxUniverse->n_entities = 0;
	}
}


// Slice 15 (bead oo-dg9d1): counting and finding entities by predicate, time, collisions, the view
// direction. Written against the Objective-C API and run on the unconverted class first; the
// entities sit in the sorted list by hand, as slice 14's.
@interface Slice15ShipLike: Entity	// counts as a ship for the ship predicates
@end

@implementation Slice15ShipLike
- (BOOL) isShip	{ return YES; }
@end


namespace {

Entity *MakeShipLike(HPVector position, GLfloat radius)
{
	Entity *entity = [[[Slice15ShipLike alloc] init] autorelease];
	[entity setPosition:position];
	[entity setCollisionRadius:radius];
	return entity;
}


BOOL IsFarPredicate(Entity *entity, void *parameter)	// x beyond *(double *)parameter
{
	return [entity position].x > *(double *)parameter;
}

}	// namespace


OO_TEST(slice15CountAndFind)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		Entity *a = MakeEntity(make_HPvector(0, 0, 0), 10);
		Entity *b = MakeEntity(make_HPvector(100, 0, 0), 10);
		Entity *c = MakeShipLike(make_HPvector(1000, 0, 0), 10);
		SetSortedEntities(u, { a, b, c });

		// No predicate is every entity; no entity counts from the origin; the reference itself never counts.
		OO_CHECK([u countEntitiesMatchingPredicate:NULL parameter:NULL inRange:-1 ofEntity:nil] == 3);
		OO_CHECK([u countEntitiesMatchingPredicate:NULL parameter:NULL inRange:-1 ofEntity:a] == 2);
		// The range reaches the other entity's surface: b's is 90 away from a, c's 990.
		OO_CHECK([u countEntitiesMatchingPredicate:NULL parameter:NULL inRange:95 ofEntity:a] == 1);
		OO_CHECK([u countEntitiesMatchingPredicate:NULL parameter:NULL inRange:85 ofEntity:a] == 0);
		double limit = 50;
		OO_CHECK([u countEntitiesMatchingPredicate:IsFarPredicate parameter:&limit inRange:-1 ofEntity:nil] == 2);

		// Ships: only c.
		OO_CHECK([u countShipsMatchingPredicate:NULL parameter:NULL inRange:-1 ofEntity:a] == 1);
		OO_CHECK([u countShipsMatchingPredicate:IsFarPredicate parameter:&limit inRange:-1 ofEntity:nil] == 1);
		OO_CHECK([u countShipsMatchingPredicate:NULL parameter:NULL inRange:500 ofEntity:a] == 0);

		std::vector<oo::ObjCRef<Entity *>> found = [u cxx_findEntitiesMatchingPredicate:NULL parameter:NULL inRange:-1 ofEntity:a];
		OO_CHECK(found.size() == 2 && found[0].get() == b && found[1].get() == c);	// in the sorted list's order
		found = [u cxx_findEntitiesMatchingPredicate:IsFarPredicate parameter:&limit inRange:95 ofEntity:a];
		OO_CHECK(found.size() == 1 && found[0].get() == b);
		found = [u cxx_findShipsMatchingPredicate:NULL parameter:NULL inRange:-1 ofEntity:nil];
		OO_CHECK(found.size() == 1 && found[0].get() == c);
		OO_CHECK([u cxx_findVisualEffectsMatchingPredicate:NULL parameter:NULL inRange:-1 ofEntity:nil].empty());

		// Within range of an entity: the ships only; none for no entity.
		OO_CHECK([u cxx_entitiesWithinRange:2000 ofEntity:a].size() == 1);
		OO_CHECK([u cxx_entitiesWithinRange:500 ofEntity:a].empty());
		OO_CHECK([u cxx_entitiesWithinRange:2000 ofEntity:nil].empty());

		// The scan class.
		[c setScanClass:CLASS_ROCK];
		OO_CHECK([u countShipsWithScanClass:CLASS_ROCK inRange:-1 ofEntity:nil] == 1);
		OO_CHECK([u countShipsWithScanClass:CLASS_NEUTRAL inRange:-1 ofEntity:nil] == 0);

		u->_cxxUniverse->n_entities = 0;
	}
}


OO_TEST(slice15FindOneAndNearest)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		Entity *a = MakeEntity(make_HPvector(0, 0, 0), 10);
		Entity *b = MakeEntity(make_HPvector(300, 0, 0), 10);
		Entity *c = MakeShipLike(make_HPvector(200, 0, 0), 10);
		Entity *d = MakeShipLike(make_HPvector(-500, 0, 0), 10);
		SetSortedEntities(u, { a, b, c, d });
		double limit = 250;

		OO_CHECK([u findOneEntityMatchingPredicate:NULL parameter:NULL] == a);
		OO_CHECK([u findOneEntityMatchingPredicate:IsFarPredicate parameter:&limit] == b);
		limit = 5000;
		OO_CHECK([u findOneEntityMatchingPredicate:IsFarPredicate parameter:&limit] == nil);

		OO_CHECK([u nearestEntityMatchingPredicate:NULL parameter:NULL relativeToEntity:a] == c);
		OO_CHECK([u nearestEntityMatchingPredicate:NULL parameter:NULL relativeToEntity:nil] == a);
		limit = 250;
		OO_CHECK([u nearestEntityMatchingPredicate:IsFarPredicate parameter:&limit relativeToEntity:a] == b);
		OO_CHECK([u nearestShipMatchingPredicate:NULL parameter:NULL relativeToEntity:b] == c);
		OO_CHECK([u nearestShipMatchingPredicate:IsFarPredicate parameter:&limit relativeToEntity:a] == nil);
		limit = -1000;
		OO_CHECK([u nearestShipMatchingPredicate:IsFarPredicate parameter:&limit relativeToEntity:c] == d);

		u->_cxxUniverse->n_entities = 0;
	}
}


OO_TEST(slice15TimeAndCollisions)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		u->_cxxUniverse->universal_time = 12.5;
		u->_cxxUniverse->time_delta = 0.25;
		OO_CHECK([u getTime] == 12.5 && [u getTimeDelta] == 0.25);

		// No collision region yet: the description is a dash.
		OO_CHECK([u collisionDescription] == "-");
		[u dumpCollisions];
		OO_CHECK(u->_cxxUniverse->dumpCollisionInfo);

		u->_cxxUniverse->viewDirection = VIEW_AFT;
		OO_CHECK([u viewDirection] == VIEW_AFT);
	}
}


// Slice 16 (bead oo-focfo): the view direction, custom sounds, screen
// backgrounds, messages. Written against the Objective-C API and run on the unconverted class
// first. A headless universe has no GUIs and no player (the messages that reach the player's
// script events are left to the goldens), so the messages are seen in the members that remember
// them (the current message and its repeat times).
namespace {

std::optional<std::string> CurrentMessage(Universe *u)	{ return u->_cxxUniverse->currentMessage; }
OOTimeAbsolute MessageRepeatTime(Universe *u)			{ return u->_cxxUniverse->messageRepeatTime; }
OOTimeAbsolute CountdownRepeatTime(Universe *u)		{ return u->_cxxUniverse->countdown_messageRepeatTime; }

}	// namespace


OO_TEST(slice16Messages)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		u->_cxxUniverse->universal_time = 10.0;

		[u cxx_displayMessage:std::string("a") forCount:3];
		OO_CHECK(CurrentMessage(u) == "a" && MessageRepeatTime(u) == 16.0);
		u->_cxxUniverse->universal_time = 12.0;
		[u cxx_displayMessage:std::string("a") forCount:3];	// the same message, too soon: nothing
		OO_CHECK(MessageRepeatTime(u) == 16.0);
		[u cxx_displayMessage:std::string("b") forCount:3];
		OO_CHECK(CurrentMessage(u) == "b" && MessageRepeatTime(u) == 18.0);
		u->_cxxUniverse->universal_time = 20.0;
		[u cxx_displayMessage:std::string("b") forCount:3];	// the same, once the repeat time has passed
		OO_CHECK(CurrentMessage(u) == "b" && MessageRepeatTime(u) == 26.0);

		// A countdown message waits for its own repeat time, whatever the message.
		[u cxx_displayCountdownMessage:std::string("c") forCount:5];
		OO_CHECK(CurrentMessage(u) == "c" && CountdownRepeatTime(u) == 25.0);
		[u cxx_displayCountdownMessage:std::string("d") forCount:5];
		OO_CHECK(CurrentMessage(u) == "c" && CountdownRepeatTime(u) == 25.0);
		[u cxx_displayCountdownMessage:std::string("c") forCount:5];	// the same message: nothing
		OO_CHECK(CountdownRepeatTime(u) == 25.0);

		[u clearPreviousMessage];
		OO_CHECK(!CurrentMessage(u).has_value());
	}
}


OO_TEST(slice16ViewDirection)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();

		// The view it already has, with no GUI shown: nothing changes and nothing is said. (A
		// change speaks through the player's script events, which need the whole game.)
		u->_cxxUniverse->viewDirection = VIEW_AFT;
		[u setViewDirection:VIEW_AFT];
		OO_CHECK([u viewDirection] == VIEW_AFT && !CurrentMessage(u).has_value() && ![u displayGUI]);
	}
}


OO_TEST(slice16SoundsAndBackgrounds)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		u->_cxxUniverse->customSounds = oo::PList(oo::PList::Dict{
			{ "[slice16-boom]", oo::PList("boom.ogg") },
			{ "[slice16-alias]", oo::PList("[slice16-boom]") },
			{ "[slice16-loop1]", oo::PList("[slice16-loop2]") },
			{ "[slice16-loop2]", oo::PList("[slice16-loop1]") },
		});

		OO_CHECK([u soundNameForCustomSoundKey:"[slice16-boom]"] == "boom.ogg");
		OO_CHECK([u soundNameForCustomSoundKey:"[slice16-alias]"] == "boom.ogg");
		OO_CHECK(![u soundNameForCustomSoundKey:"[slice16-missing]"].has_value());
		OO_CHECK(![u soundNameForCustomSoundKey:"[slice16-loop1]"].has_value());	// recursion: no sound

		// Backgrounds: none loaded, setting changes nothing; loaded, set and remove by key.
		[u cxx_setScreenTextureDescriptorForKey:"slice16" descriptor:oo::PList("x.png")];
		OO_CHECK(u->_cxxUniverse->screenBackgrounds.isNull());
		u->_cxxUniverse->screenBackgrounds = oo::PList(oo::PList::Dict{});
		[u cxx_setScreenTextureDescriptorForKey:"slice16" descriptor:oo::PList("x.png")];
		const oo::PList *set = u->_cxxUniverse->screenBackgrounds.find("slice16");
		OO_CHECK(set != nullptr && set->isString());
		[u cxx_setScreenTextureDescriptorForKey:"slice16" descriptor:oo::PList()];
		OO_CHECK(u->_cxxUniverse->screenBackgrounds.find("slice16") == nullptr);
		// With no GUI to preload it, no descriptor is answered.
		[u cxx_setScreenTextureDescriptorForKey:"slice16" descriptor:oo::PList("x.png")];
		OO_CHECK([u cxx_screenTextureDescriptorForKey:"slice16"].isNull());
	}
}


// Slice 17 (bead oo-gr7a2): update:, time acceleration, ECM visual effects. Written against the
// Objective-C API and run on the unconverted class first. A full update needs the whole game (the
// player, the JavaScript engine); a universe whose updates are off only lets go of the dead.
OO_TEST(slice17UpdateOff)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		SetUpTestPlayer();	// a player that is not dead: no dead player's update
		u->_cxxUniverse->no_update = YES;
		u->_cxxUniverse->universal_time = 5.0;
		u->_cxxUniverse->time_delta = 0.5;
		Entity *dead = [[Entity alloc] init];
		u->_cxxUniverse->entitiesDeadThisUpdate.emplace_back(dead);
		[dead release];

		@autoreleasepool
		{
			[u update:1.0];
			OO_CHECK([u getTime] == 5.0 && [u getTimeDelta] == 0.5);	// no time passes
			OO_CHECK(u->_cxxUniverse->entitiesDeadThisUpdate.empty());
			OO_CHECK([dead retainCount] == 1);	// alive until the pool drains
		}
	}
}


OO_TEST(slice17Settings)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();

		[u setECMVisualFXEnabled:YES];
		OO_CHECK([u ECMVisualFXEnabled] && u->_cxxUniverse->ECMVisualFXEnabled);
		[u setECMVisualFXEnabled:NO];
		OO_CHECK(![u ECMVisualFXEnabled]);

		[u setTimeAccelerationFactor:4.0];
#ifndef NDEBUG
		OO_CHECK([u timeAccelerationFactor] == 4.0);
		[u setTimeAccelerationFactor:100.0];
		OO_CHECK([u timeAccelerationFactor] == TIME_ACCELERATION_FACTOR_DEFAULT);
#else
		OO_CHECK([u timeAccelerationFactor] == 1.0);
#endif
	}
}


// Slice 18 (bead oo-tail0): filterSortedLists, which marks the entities that cannot meet another
// on the z axis and chains the rest for the collision test. Written against the Objective-C API
// and run on the unconverted class first. The x, y and z lists are linked by hand in one order.
namespace {

void LinkLists(Universe *u, std::initializer_list<Entity *> list)
{
	Entity *previous = nil;
	for (Entity *e : list)
	{
		cxx::Entity *part = e->_cxxEntity.get();
		part->x_previous = part->y_previous = part->z_previous = previous;
		part->x_next = part->y_next = part->z_next = nil;
		if (previous != nil)  previous->_cxxEntity->x_next = previous->_cxxEntity->y_next = previous->_cxxEntity->z_next = e;
		previous = e;
	}
	Entity *first = list.size() > 0 ? *list.begin() : nil;
	u->_cxxUniverse->x_list_start = u->_cxxUniverse->y_list_start = u->_cxxUniverse->z_list_start = first;
}

}	// namespace


OO_TEST(slice18FilterSortedLists)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		Entity *a = MakeEntity(make_HPvector(0, 0, 0), 10);
		Entity *ghost = [[[Slice14GhostEntity alloc] init] autorelease];
		[ghost setPosition:make_HPvector(0, 0, 5)];
		[ghost setCollisionRadius:10];
		Entity *b = MakeEntity(make_HPvector(0, 0, 15), 10);
		Entity *c = MakeEntity(make_HPvector(0, 0, 1000), 10);
		a->_cxxEntity->collision_chain = c;	// stale chains are cleared
		c->_cxxEntity->collision_chain = a;
		LinkLists(u, { a, ghost, b, c });

		[u filterSortedLists];

		// a and b overlap on z: chained, past the entity that cannot collide; c is alone.
		OO_CHECK(a->_cxxEntity->collision_chain == b);
		OO_CHECK(b->_cxxEntity->collision_chain == nil);
		OO_CHECK(c->_cxxEntity->collision_chain == nil && ghost->_cxxEntity->collision_chain == nil);
		OO_CHECK(a->_cxxEntity->collisionTestFilter == 0 && b->_cxxEntity->collisionTestFilter == 0);
		OO_CHECK(c->_cxxEntity->collisionTestFilter == 1);
		OO_CHECK(ghost->_cxxEntity->collisionTestFilter == 3);

		LinkLists(u, {});
		[u filterSortedLists];	// no entities: nothing to do
		OO_CHECK(u->_cxxUniverse->z_list_start == nil);
	}
}


// Slice 19 (bead oo-z3u03): galaxy and system changes, descriptions, scenarios, characters, mission
// text, system data and names, finding systems. Written against the Objective-C API and run on the
// unconverted class first. A headless universe has no system manager, so the state these answer
// is set in the members by hand.
OO_TEST(slice19Descriptions)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		u->_cxxUniverse->_descriptions = oo::PList(oo::PList::Dict{
			{ "slice19-text", oo::PList("Hello") },
			{ "slice19-array", oo::PList(oo::PList::Array{ oo::PList("zero"), oo::PList("one") }) },
			{ "slice19-flag", oo::PList(true) },
		});
		u->_cxxUniverse->_descriptionsGeneration = 7;

		const oo::PList *descriptions = [u cxx_descriptions];
		OO_CHECK(descriptions == &u->_cxxUniverse->_descriptions);
		OO_CHECK([u cxx_descriptionsGeneration] == 7);
		OO_CHECK([u cxx_descriptionForKey:"slice19-text"] == "Hello");
		OO_CHECK(![u cxx_descriptionForKey:"slice19-missing"].has_value());
		OO_CHECK([u cxx_descriptionForArrayKey:"slice19-array" index:1] == "one");
		OO_CHECK(![u cxx_descriptionForArrayKey:"slice19-array" index:2].has_value());
		OO_CHECK(![u cxx_descriptionForArrayKey:"slice19-text" index:0].has_value());
		OO_CHECK([u descriptionBooleanForKey:"slice19-flag"]);
		OO_CHECK(![u descriptionBooleanForKey:"slice19-missing"]);
		OO_CHECK(cxx_OOLookUpDescriptionPRIV("slice19-text") == "Hello");
	}
}


OO_TEST(slice19DataAndNames)
{
	@autoreleasepool
	{
		Universe *u = NewUniverse();
		u->_cxxUniverse->explosionSettings = oo::PList(oo::PList::Dict{ { "slice19-boom", oo::PList(oo::PList::Dict{ { "size", oo::PList(2.0) } }) } });
		u->_cxxUniverse->_scenarios = oo::PList(oo::PList::Array{ oo::PList("s") });
		u->_cxxUniverse->characters = oo::PList(oo::PList::Dict{ { "c", oo::PList("x") } });
		u->_cxxUniverse->missiontext = oo::PList(oo::PList::Dict{ { "m", oo::PList("y") } });
		u->_cxxUniverse->systemID = 42;

		OO_CHECK([u cxx_explosionSetting:"slice19-boom"].get<double>("size") == 2.0);
		OO_CHECK([u cxx_explosionSetting:"slice19-missing"].isNull());
		OO_CHECK([u cxx_scenarios].count() == 1);
		OO_CHECK([u cxx_characters].get<std::string>("c") == "x");
		OO_CHECK([u cxx_missiontext].get<std::string>("m") == "y");
		OO_CHECK([u currentSystemID] == 42);
		OO_CHECK([u systemManager] == nil);

		OO_CHECK([u cxx_keyForPlanetOverridesForSystem:7 inGalaxy:2] == "2 7");
		OO_CHECK([u keyForInterstellarOverridesForSystems:3 :4 inGalaxy:2] == "interstellar: 2 3 4");

		// Names are found whatever their case; a missing name matches nothing.
		u->_cxxUniverse->system_names[5] = std::string("Lave");
		u->_cxxUniverse->system_names[9] = std::string("Diso");
		OO_CHECK([u cxx_findSystemFromName:"lave"] == 5);
		OO_CHECK([u cxx_findSystemFromName:"DISO"] == 9);
		OO_CHECK([u cxx_findSystemFromName:"Zaonce"] == -1);

		// No sun in the universe: interstellar space.
		OO_CHECK([u inInterstellarSpace]);
	}
}


OO_TEST_MAIN()
