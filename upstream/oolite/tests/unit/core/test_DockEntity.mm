/*	test_DockEntity.mm
	Unit tests for DockEntity (src/Core/Entities/DockEntity.h), a station's dock: slice 1 of its
	slice plan (docs/phases/3-slices/DockEntity.md, bead oo-ao2d), the class shell, which moves the
	dock's state and its flags, geometry and lifecycle into cxx::DockEntity and keeps the
	Objective-C DockEntity as its facade (proposed ADR-0056, amendments oo-60fwo and oo-64ako).

	As test_StationEntity's, the dock's object needs the game graph, so the test links the whole
	game but main (['*']) and uses a Universe that was never initialised and a plain entity as
	PLAYER (answering the one player query a dock makes when it aborts its dockings). A dock's
	station is a StationEntity whose virtual dock only records its definition, with the dock added
	as its subentity. The cases test the slice's own units through the Objective-C API, written
	against it and run on the unconverted class first; the cases after "The crossing" pin the C++
	part once it exists.
	Run: bash tools/check-core-tests.sh test_DockEntity
*/

#import "DockEntity.h"
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


// PLAYER: docked at no station.
@interface TestDockPlayer: Entity
@end


@implementation TestDockPlayer

- (HPVector) viewpointPosition			{ return kZeroHPVector; }
- (StationEntity *) getTargetDockStation	{ return nil; }

@end


// A station whose virtual dock is not made (the dock is a shipdata entry).
@interface TestDockStation: StationEntity
@end


@implementation TestDockStation

- (BOOL) cxx_setUpOneStandardSubentity:(const oo::PList &)subentDict asTurret:(BOOL)asTurret	{ return YES; }

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
	static TestDockPlayer *player = nil;
	if (player == nil)  player = [[TestDockPlayer alloc] init];
	gOOPlayer = (PlayerEntity *)player;
	// The ship's -dealloc sends its (absent) scripts entityDestroyed in a request on the main
	// thread's context, so there is one, with nothing in it.
	if (gOOJSMainThreadContext == nullptr)  gOOJSMainThreadContext = ooscript::newContext(ooscript::newRuntime(8u * 1024u * 1024u), 8192);
}


// Unpiloted (a crewed ship would ask the universe for a pilot).
oo::PList Definition()
{
	return oo::PList(oo::PList::Dict{ { "unpiloted", oo::PList(true) } });
}


DockEntity *MakeDock(const std::string &key)
{
	return [[[DockEntity alloc] cxx_initWithKey:key definition:Definition()] autorelease];
}


// A dock that is a subentity of a station, so its parent is the station.
DockEntity *MakeDockOfStation(TestDockStation **outStation)
{
	TestDockStation *station = [[[TestDockStation alloc] cxx_initWithKey:"dock-station" definition:Definition()] autorelease];
	DockEntity *dock = MakeDock("dock");
	[station addSubEntity:dock];
	*outStation = station;
	return dock;
}


bool Near(Vector a, Vector b)	{ return std::fabs(a.x - b.x) < 1e-5 && std::fabs(a.y - b.y) < 1e-5 && std::fabs(a.z - b.z) < 1e-5; }


BoundingBox Box(float width, float height)
{
	BoundingBox bb;
	bb.min = make_vector(0, 0, 0);
	bb.max = make_vector(width, height, 1);
	return bb;
}

}	// namespace


// --- Slice 1: the class shell (bead oo-ao2d) --------------------------------------------------------

// The initialiser and the set-up from the definition: a dock is a ship that is not a station, open
// for docking and launching, with empty queues.
OO_TEST(initAndSetUp)
{
	@autoreleasepool
	{
		SetUp();
		DockEntity *dock = MakeDock("dock");
		OO_CHECK(dock != nil);
		OO_CHECK([dock isDock] && [dock isShip] && ![dock isStation] && ![dock isPlayer]);
		OO_CHECK([dock cxx_shipDataKey] == std::optional<std::string>("dock"));
		OO_CHECK([dock allowsDocking] && [dock allowsLaunching] && ![dock disallowedDockingCollides]);
		OO_CHECK([dock countOfShipsInDockingQueue] == 0 && [dock countOfShipsInLaunchQueue] == 0);
		OO_CHECK([dock parentEntity] == nil);
	}
}


// The flags: closing to docking or launching aborts what is queued (nothing here).
OO_TEST(flags)
{
	@autoreleasepool
	{
		SetUp();
		DockEntity *dock = MakeDock("flags");
		[dock setAllowsDocking:NO];
		OO_CHECK(![dock allowsDocking]);
		[dock setAllowsDocking:YES];
		OO_CHECK([dock allowsDocking]);
		[dock setAllowsLaunching:NO];
		OO_CHECK(![dock allowsLaunching]);
		[dock setAllowsLaunching:YES];
		OO_CHECK([dock allowsLaunching]);
		[dock setDisallowedDockingCollides:YES];
		OO_CHECK([dock disallowedDockingCollides]);
		[dock clear];
		OO_CHECK([dock countOfShipsInDockingQueue] == 0 && [dock countOfShipsInLaunchQueue] == 0);
	}
}


// Off centre: away from the station's axis, or not facing along it.
OO_TEST(isOffCentre)
{
	@autoreleasepool
	{
		SetUp();
		DockEntity *dock = MakeDock("centre");
		OO_CHECK(![dock isOffCentre]);
		[dock setPosition:make_HPvector(0, 0, 500)];
		OO_CHECK(![dock isOffCentre]);
		[dock setPosition:make_HPvector(3, 3, 0)];
		OO_CHECK([dock isOffCentre]);
		[dock setPosition:kZeroHPVector];
		Quaternion q = kIdentityQuaternion;
		quaternion_rotate_about_y(&q, M_PI_2);
		[dock setOrientation:q];
		OO_CHECK([dock isOffCentre]);
	}
}


// The geometry from the station: a virtual dock takes the station's virtual port; the port's up
// vector turns with a ship whose box is the other way round.
OO_TEST(dimensionsAndPortUpVector)
{
	@autoreleasepool
	{
		SetUp();
		TestDockStation *station = nil;
		DockEntity *dock = MakeDockOfStation(&station);
		OO_CHECK([dock parentEntity] == station);

		[dock setVirtual];
		[dock setDimensionsAndCorridor:NO :YES :NO];
		OO_CHECK(![dock allowsDocking] && [dock disallowedDockingCollides] && ![dock allowsLaunching]);

		// The virtual port is 69 x 69: square, so only the ship's box decides.
		OO_CHECK(Near([dock portUpVectorForShipsBoundingBox:Box(20, 10)], make_vector(0, 1, 0)));
		OO_CHECK(Near([dock portUpVectorForShipsBoundingBox:Box(10, 20)], make_vector(1, 0, 0)));

		[dock setDimensionsAndCorridor:YES :NO :YES];
		OO_CHECK([dock allowsDocking] && ![dock disallowedDockingCollides] && [dock allowsLaunching]);
	}
}


// A virtual dock takes no damage.
OO_TEST(virtualDockTakesNoDamage)
{
	@autoreleasepool
	{
		SetUp();
		DockEntity *dock = MakeDock("virtual");
		[dock setVirtual];
		const double energy = [dock energy];
		[dock takeEnergyDamage:50.0 from:nil becauseOf:nil weaponIdentifier:""];
		OO_CHECK([dock energy] == energy);
		[dock noteTakingDamage:50.0 from:nil type:kOODamageTypeEnergy];
		OO_CHECK([dock energy] == energy);
		[dock drawImmediate:false translucent:false];	// not drawn: nothing to check but that it returns
	}
}


// A failing initialiser that releases the dock before [super init]: -dealloc runs without the
// ship's set-up.
OO_TEST(dockReleasedBeforeInit)
{
	@autoreleasepool
	{
		SetUp();
		DockEntity *dock = [DockEntity alloc];
		[dock release];
		OO_CHECK(true);
	}
}


// --- Slice 2: docking guidance (bead oo-9ht.178) ---------------------------------------------------
// These cases reach only the approach queue and the dock's flags: no player, no ship in the
// universe, no clock.

namespace {

// A ship with the universal ID the approach queue keys it by.
ShipEntity *MakeQueuedShip(OOUniversalID shipID)
{
	ShipEntity *ship = [[[ShipEntity alloc] cxx_initWithKey:"queued" definition:Definition()] autorelease];
	ship->_cxxEntity->universalID = shipID;
	return ship;
}

}	// namespace


// A dock that is closed rejects a ship outright, before it asks the ship or its script anything
// (the later tests of an open dock call the script engine, which this test does not start).
OO_TEST(canAcceptShipForDocking)
{
	@autoreleasepool
	{
		SetUp();
		DockEntity *dock = MakeDock("accept");
		ShipEntity *ship = MakeQueuedShip(11);
		[dock setAllowsDocking:NO];
		OO_CHECK([dock canAcceptShipForDocking:ship] == std::optional<std::string>("DOCK_CLOSED"));
		OO_CHECK(oo::ToCxx(dock)->canAcceptShipForDocking(ship) == std::optional<std::string>("DOCK_CLOSED"));
	}
}


// The approach queue: a ship is in it by its ID, and aborting its docking takes it out again.
OO_TEST(approachQueue)
{
	@autoreleasepool
	{
		SetUp();
		DockEntity *dock = MakeDock("queue");
		ShipEntity *ship = MakeQueuedShip(12);
		OO_CHECK(![dock shipIsInDockingQueue:nil] && ![dock shipIsInDockingQueue:ship]);
		dock->_cxxDock->shipsOnApproach[12] = std::vector<oo::PList>();
		OO_CHECK([dock shipIsInDockingQueue:ship]);
		OO_CHECK([dock countOfShipsInDockingQueue] == 1);
		[dock abortDockingForShip:ship];
		OO_CHECK(![dock shipIsInDockingQueue:ship]);
		OO_CHECK([dock countOfShipsInDockingQueue] == 0);
	}
}


// Docking instructions for no ship are none.
OO_TEST(dockingInstructionsForNoShip)
{
	@autoreleasepool
	{
		SetUp();
		DockEntity *dock = MakeDock("instructions");
		OO_CHECK([dock dockingInstructionsForShip:nil].isNull());
	}
}


// Nothing in the queue: nothing to pull in, and the queue stays empty. The C++ part does the same.
OO_TEST(autoDockEmptyQueue)
{
	@autoreleasepool
	{
		SetUp();
		DockEntity *dock = MakeDock("autodock");
		[dock autoDockShipsOnApproach];
		OO_CHECK([dock countOfShipsInDockingQueue] == 0);
		cxx::DockEntity *part = oo::ToCxx(dock);
		part->shipsOnApproach[13] = std::vector<oo::PList>();
		part->autoDockShipsOnApproach();	// no ship has ID 13 in the (never initialised) universe's lookup: dropped
		OO_CHECK(part->countOfShipsInDockingQueue() == 0);
	}
}


// --- The crossing (after the conversion) ---------------------------------------------------------

// A dock's C++ part is a cxx::DockEntity, the facade's typed alias is that part, and from C++ the
// entity's virtual members reach the dock's.
OO_TEST(objCDockPartIsADock)
{
	@autoreleasepool
	{
		SetUp();
		DockEntity *dock = MakeDock("crossing");
		cxx::DockEntity *part = oo::ToCxx(dock);
		OO_CHECK(part != nullptr && part == dock->_cxxDock);
		OO_CHECK(static_cast<cxx::ShipEntity *>(part) == dock->_cxxShip);
		OO_CHECK(oo::ToObjC(part) == dock);

		cxx::Entity *asEntity = part;
		OO_CHECK(asEntity->isDock());
		OO_CHECK(part->allowsDocking() && part->allowsLaunching() && !part->disallowedDockingCollides());
		part->setAllowsDocking(false);
		OO_CHECK(![dock allowsDocking]);
		OO_CHECK(part->countOfShipsInDockingQueue() == 0 && part->countOfShipsInLaunchQueue() == 0);

		part->setVirtual();
		OO_CHECK(part->virtual_dock);
		const double energy = [dock energy];
		asEntity->takeEnergyDamage(10.0, nullptr, nullptr, "");
		OO_CHECK([dock energy] == energy);
	}
}


// A dock released before its initialiser: the facade's -dealloc runs without a C++ part.
OO_TEST(dockWithoutPart)
{
	@autoreleasepool
	{
		SetUp();
		DockEntity *dock = [DockEntity alloc];
		OO_CHECK(dock->_cxxDock == nullptr);
		[dock release];
	}
}


OO_TEST_MAIN()
