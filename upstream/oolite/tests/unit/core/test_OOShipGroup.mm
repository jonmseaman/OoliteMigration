/*	test_OOShipGroup.mm
	Unit tests for OOShipGroup and OOShipGroupCursor (src/Core/OOShipGroup.h): bead oo-bwrq,
	converted in the Phase 3 house style (proposed ADR-0056).

	A group holds weak references to its ships (and to its leader), so a ship that dies leaves it.
	The group's own objects are linked; ShipEntity, which reaches the whole game, is replaced by a
	minimal weak-referenceable class of the same name that records what the group asks of it
	(amendment oo-z1s4 item 4). The expectations were written against the Objective-C API and run
	on the unconverted class first: naming, adding (no duplicates, growth past the initial
	capacity), the leader (added as a member, dropped when it dies), removing (the ship is told to
	leave), dead members leaving, the two member arrays, the cursor (and its mutation check), and
	the description text. The C++ test then pins the same through OOShipGroup. A dying group lets
	go of its weak reference to its leader as it does of its members' (bead oo-9ht.24). The
	group's facade was deleted by bead oo-9ht.19: the cases ask the C++ group, holding the
	factory's oo::Ref where the autoreleased facade was; the facade-contract case went with it
	(standing approval oo-9n5p9), and objectNode pins how a group now travels in plist data.
	Run: bash tools/check-core-tests.sh
*/

#import "OOShipGroup.h"
#import "OOWeakReference.h"

#include "oo_test.hpp"
#include "oofnd/objc/OOException.h"
#include "OODescription.h"

#include <algorithm>
#include <string>
#include <vector>


// The JS glue of OOShipGroup, which OOJSShipGroup.mm defines (bead oo-6symp.1) and this test
// does not link: the vtable names them. Nothing here reaches the JS engine.
ooscript::Value OOShipGroup::jsValueInContext(ooscript::Context)  { return ooscript::nullValue(); }
void OOShipGroup::clearJSSelf(ooscript::Object)  {}
std::optional<std::string> OOShipGroup::jsDescription()  { return std::nullopt; }


// --- A stand-in for ShipEntity (see the banner) ---------------------------------------------------

@interface ShipEntity: OOWeakRefObject
{
@public
	id		lastGroup;
	id		lastOwner;
	int		setGroupCalls;
}
- (void) setGroup:(id)group;
- (void) setOwner:(id)owner;
@end

@implementation ShipEntity

- (void) setGroup:(id)group
{
	setGroupCalls++;
	lastGroup = group;
}


- (void) setOwner:(id)owner
{
	lastOwner = owner;
}

@end


// A ship that says whether a weak reference to it is still alive: OOWeakRefObject keeps one
// (weakSelf) while any -weakRetain is unbalanced, and clears it when the reference deallocates.
@interface WatchedShip: ShipEntity
- (BOOL) hasLiveWeakReference;
@end

@implementation WatchedShip
- (BOOL) hasLiveWeakReference  { return weakSelf != nil; }
@end


namespace {

ShipEntity *NewShip()
{
	return [[[ShipEntity alloc] init] autorelease];
}


bool HasMembers(const std::vector<oo::ObjCRef<ShipEntity *>> &members, std::vector<ShipEntity *> expected)
{
	std::vector<ShipEntity *> got;
	for (const oo::ObjCRef<ShipEntity *> &ship : members)  got.push_back(ship.get());
	std::sort(got.begin(), got.end());
	std::sort(expected.begin(), expected.end());
	return got == expected;
}

}	// namespace


OO_TEST(namesAndEmptyGroups)
{
	@autoreleasepool
	{
		oo::Ref<OOShipGroup> unnamed = OOShipGroup::groupWithName(std::nullopt);	// -init
		OO_CHECK(unnamed != nil && !unnamed->name().has_value());
		OO_CHECK(unnamed->count() == 0 && unnamed->isEmpty() && unnamed->leader() == nil);
		OO_CHECK(unnamed->memberArray().empty() && unnamed->memberArrayExcludingLeader().empty());

		oo::Ref<OOShipGroup> named = OOShipGroup::groupWithName(std::string("escort group"));
		OO_CHECK(named->name() == std::optional<std::string>("escort group"));
		named->setName(std::string("renamed"));
		OO_CHECK(named->name() == std::optional<std::string>("renamed"));
		named->setName(std::nullopt);
		OO_CHECK(!named->name().has_value());

		oo::Ref<OOShipGroup> made = OOShipGroup::groupWithName(std::string("ship group"));	// -cxx_initWithName:
		OO_CHECK(made->name() == std::optional<std::string>("ship group") && made->isEmpty());
	}
}


OO_TEST(addingAndGrowing)
{
	@autoreleasepool
	{
		oo::Ref<OOShipGroup> group = OOShipGroup::groupWithName(std::nullopt);
		std::vector<ShipEntity *> ships;
		for (int i = 0; i < 20; i++)  ships.push_back(NewShip());	// past kMinSize (4): the array grows

		for (ShipEntity *ship : ships)  OO_CHECK(group->addShip(ship));
		OO_CHECK(group->count() == 20 && !group->isEmpty());
		OO_CHECK(group->addShip(ships[3]));	// already in: YES, and not added twice
		OO_CHECK(group->count() == 20);
		OO_CHECK(group->containsShip(ships[19]) && !group->containsShip(NewShip()));
		OO_CHECK(HasMembers(group->memberArray(), ships));
		OO_CHECK(HasMembers(group->memberArrayExcludingLeader(), ships));	// no leader
	}
}


OO_TEST(leader)
{
	@autoreleasepool
	{
		ShipEntity *leader = NewShip();
		ShipEntity *wingman = NewShip();
		oo::Ref<OOShipGroup> group = OOShipGroup::groupWithName(std::string("g"), leader);
		OO_CHECK(group->leader() == leader && group->containsShip(leader) && group->count() == 1);
		group->addShip(wingman);
		OO_CHECK(HasMembers(group->memberArrayExcludingLeader(), { wingman }));
		OO_CHECK(HasMembers(group->memberArray(), { leader, wingman }));

		group->setLeader(wingman);
		OO_CHECK(group->leader() == wingman && group->count() == 2);
		group->setLeader(nullptr);
		OO_CHECK(group->leader() == nil && group->count() == 2);	// still members
	}
}


OO_TEST(removing)
{
	@autoreleasepool
	{
		ShipEntity *a = NewShip(), *b = NewShip(), *c = NewShip();
		oo::Ref<OOShipGroup> group = OOShipGroup::groupWithName(std::nullopt, a);
		group->addShip(b);
		group->addShip(c);

		OO_CHECK(group->removeShip(b));
		OO_CHECK(!group->containsShip(b) && group->count() == 2);
		OO_CHECK(b->setGroupCalls == 1 && b->lastGroup == nil && b->lastOwner == b);	// told to leave
		OO_CHECK(!group->removeShip(b));	// not a member

		OO_CHECK(group->removeShip(a));	// the leader: no longer leads
		OO_CHECK(group->leader() == nil && group->count() == 1 && group->containsShip(c));
	}
}


OO_TEST(deadShipsLeave)
{
	@autoreleasepool
	{
		oo::Ref<OOShipGroup> group = OOShipGroup::groupWithName(std::nullopt);
		ShipEntity *survivor = NewShip();
		ShipEntity *doomed = [[ShipEntity alloc] init];
		ShipEntity *doomedLeader = [[ShipEntity alloc] init];
		group->addShip(survivor);
		group->addShip(doomed);
		group->setLeader(doomedLeader);
		OO_CHECK(group->count() == 3);

		[doomed release];
		[doomedLeader release];
		OO_CHECK(group->leader() == nil);
		OO_CHECK(group->count() == 1 && !group->isEmpty());
		OO_CHECK(HasMembers(group->memberArray(), { survivor }));
	}
}


OO_TEST(cursor)
{
	@autoreleasepool
	{
		oo::Ref<OOShipGroup> group = OOShipGroup::groupWithName(std::nullopt);
		std::vector<ShipEntity *> ships = { NewShip(), NewShip(), NewShip() };
		for (ShipEntity *ship : ships)  group->addShip(ship);

		std::vector<ShipEntity *> seen;
		OOShipGroupCursor cursor(group.get());
		while (ShipEntity *ship = cursor.next())  seen.push_back(ship);
		OO_CHECK(seen == ships);	// internal order: the order added
		OO_CHECK(cursor.index() == 3);

		OOShipGroupCursor mutated(group.get());
		OO_CHECK(mutated.next() == ships[0]);
		group->addShip(NewShip());
		bool raised = false;
		@try
		{
			mutated.next();
		}
		@catch (OOException *exception)
		{
			raised = true;
		}
		OO_CHECK(raised);
	}
}


OO_TEST(description)
{
	@autoreleasepool
	{
		oo::Ref<OOShipGroup> group = OOShipGroup::groupWithName(std::string("pirates"));
		group->addShip(NewShip());
		OO_CHECK(group->descriptionComponents() == std::optional<std::string>("\"pirates\", 1 ships"));
		ShipEntity *leader = NewShip();
		group->setLeader(leader);
		std::optional<std::string> text = group->descriptionComponents();
		OO_CHECK(text.has_value() && *text == "\"pirates\", 2 ships, leader: " + oo::ShortDescriptionOf(leader));
		OO_CHECK(OOShipGroup::groupWithName(std::nullopt)->descriptionComponents() == std::optional<std::string>("0 ships"));
	}
}


OO_TEST(cxxGroup)
{
	@autoreleasepool
	{
		ShipEntity *leader = NewShip(), *wingman = NewShip();
		oo::Ref<OOShipGroup> group = OOShipGroup::groupWithName(std::string("g"), leader);
		OO_CHECK(group != nullptr && group->name() == std::optional<std::string>("g"));
		OO_CHECK(group->leader() == leader && group->count() == 1);
		OO_CHECK(group->addShip(wingman) && group->addShip(wingman) && group->count() == 2);
		OO_CHECK(HasMembers(group->memberArray(), { leader, wingman }));
		OO_CHECK(HasMembers(group->memberArrayExcludingLeader(), { wingman }));
		OO_CHECK(group->descriptionComponents() == std::optional<std::string>("\"g\", 2 ships, leader: " + oo::ShortDescriptionOf(leader)));

		std::vector<ShipEntity *> seen;
		OOShipGroupCursor cursor(group.get());
		while (ShipEntity *ship = cursor.next())  seen.push_back(ship);
		OO_CHECK(seen == std::vector<ShipEntity *>({ leader, wingman }));

		OO_CHECK(group->removeShip(leader) && group->leader() == nullptr && wingman->setGroupCalls == 0);
		OO_CHECK(leader->setGroupCalls == 1 && leader->lastOwner == leader);
		group->setName(std::nullopt);
		OO_CHECK(!group->name().has_value() && !group->isEmpty());
	}
}


OO_TEST(objectNode)
{
	// A group is its own PList Object node payload (bead oo-9ht.19), as its facade was the node's
	// object: the node gives the same group back, and describes it as "%@" printed the facade.
	@autoreleasepool
	{
		oo::Ref<OOShipGroup> group = OOShipGroup::groupWithName(std::string("node"));
		const oo::PList node = OOShipGroupObjectNode(group.get());
		OO_CHECK(OOShipGroupInObjectNode(node) == group.get());
		OO_CHECK(OOShipGroupObjectNode(nullptr).isNull() && OOShipGroupInObjectNode(oo::PList("node")) == nullptr);
		OO_CHECK(group->className() == "OOShipGroup");
		const std::string text = group->description();
		OO_CHECK(text.rfind("<OOShipGroup 0x", 0) == 0 && text.find(">{\"node\", 0 ships}") != std::string::npos);
		OO_CHECK(OOShipGroup::groupWithName(std::nullopt) != OOShipGroup::groupWithName(std::nullopt));	// distinct groups, as before
	}
}


OO_TEST(dyingGroupReleasesLeaderReference)
{
	// The group weak-retains its leader (setLeader) as it does each member (addShip); its
	// destructor must balance both, or every group that dies with a leader leaks one
	// OOWeakReference (bead oo-9ht.24).
	WatchedShip *leader = [[WatchedShip alloc] init];
	WatchedShip *member = [[WatchedShip alloc] init];
	@autoreleasepool
	{
		oo::Ref<OOShipGroup> group = OOShipGroup::groupWithName(std::string("doomed"));
		group->addShip(member);
		group->setLeader(leader);
		OO_CHECK(group->leader() == leader && group->count() == 2);
		OO_CHECK([leader hasLiveWeakReference] && [member hasLiveWeakReference]);
	}
	OO_CHECK(![member hasLiveWeakReference]);
	OO_CHECK(![leader hasLiveWeakReference]);
	[leader release];
	[member release];
}


OO_TEST_MAIN()
