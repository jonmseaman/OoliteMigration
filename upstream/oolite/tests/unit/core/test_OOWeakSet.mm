/*	test_OOWeakSet.mm
	Unit tests for OOWeakSet (src/Core/OOWeakSet.h): bead oo-cc8a, a Phase 3 conversion in the
	OOColor house style (proposed ADR-0056).

	Pins what the set did before the conversion, through the Objective-C API its callers
	(ShipEntity, StationEntity) use: nil is ignored; members are unique by identity and kept in
	insertion order; a member that is deallocated leaves the set silently; removing a non-member
	is fine; the snapshots and the perform-selector calls see the live members; enumerating adds;
	copies are new sets of the live members; -isEqual: compares membership; and the description.
	Run: bash tools/check-core-tests.sh
*/

#import "OOWeakSet.h"
#import "OODescription.h"

#include "oo_test.hpp"
#include "ooscript/JSEngine.hpp"
#include "oofnd/String.hpp"

#include <vector>


// The script engine's (JSEngine_quickjs.cpp would link the engine in): OOWeakReference.mm names
// it for a dead reference's -oo_jsValueInContext:, which these tests never send.
ooscript::Value ooscript::undefinedValue()
{
	return {};
}


@interface TestMember: OOWeakRefObject
{
@public
	int		frobs;
	id		lastArgument;
	int		tag;
}
- (void) frob;
- (void) frobWith:(id)argument;
@end


@implementation TestMember

- (void) frob
{
	frobs++;
}


- (void) frobWith:(id)argument
{
	frobs++;
	lastArgument = argument;
}


- (std::optional<std::string>) cxx_shortDescriptionComponents
{
	return oo::str::format("member %d", tag);
}

@end


// Anything answering -nextObject, as -addObjectsByEnumerating: requires.
@interface TestEnumerator: OOObject
{
@public
	std::vector<id>	objects;
	size_t			next;
}
- (id) nextObject;
@end


@implementation TestEnumerator

- (id) nextObject
{
	return (next < objects.size()) ? objects[next++] : nil;
}

@end


namespace {

TestMember *NewMember(int tag)
{
	TestMember *member = [[TestMember alloc] init];
	member->tag = tag;
	return member;
}


std::vector<id> Members(const std::vector<oo::ObjCRef<id>> &snapshot)
{
	std::vector<id> result;
	for (const oo::ObjCRef<id> &object : snapshot)  result.push_back(object.get());
	return result;
}

}	// namespace


OO_TEST(emptyAndNil)
{
	@autoreleasepool
	{
		OOWeakSet *set = [OOWeakSet set];
		OO_CHECK(set != nil);
		OO_CHECK_EQ([set count], 0u);
		[set addObject:nil];	// fails silently
		OO_CHECK_EQ([set count], 0u);
		OO_CHECK(![set containsObject:nil]);
		OO_CHECK([set cxx_allObjects].empty());
		OO_CHECK_EQ([[OOWeakSet setWithCapacity:10] count], 0u);
		OO_CHECK_EQ([[[[OOWeakSet alloc] initWithCapacity:3] autorelease] count], 0u);
	}
}


OO_TEST(uniqueByIdentityInInsertionOrder)
{
	TestMember *a = NewMember(1), *b = NewMember(2), *c = NewMember(3);
	@autoreleasepool
	{
		OOWeakSet *set = [[[OOWeakSet alloc] init] autorelease];
		[set addObject:b];
		[set addObject:a];
		[set addObject:b];
		[set addObject:c];
		OO_CHECK_EQ([set count], 3u);
		OO_CHECK([set containsObject:a] && [set containsObject:b] && [set containsObject:c]);
		OO_CHECK(Members([set cxx_allObjects]) == std::vector<id>({ b, a, c }));
		OO_CHECK(Members([set cxx_objectEnumerator]) == std::vector<id>({ b, a, c }));
		OO_CHECK_EQ([a retainCount], 1u);	// weakly held

		[set removeObject:a];
		[set removeObject:a];	// not a member: no complaint
		OO_CHECK_EQ([set count], 2u);
		OO_CHECK(![set containsObject:a]);
		OO_CHECK(Members([set cxx_allObjects]) == std::vector<id>({ b, c }));

		[set removeAllObjects];
		OO_CHECK_EQ([set count], 0u);
		OO_CHECK(![set containsObject:b]);
	}
	[a release];
	[b release];
	[c release];
}


OO_TEST(aDeallocatedMemberLeavesSilently)
{
	TestMember *a = NewMember(1), *b = NewMember(2);
	@autoreleasepool
	{
		OOWeakSet *set = [OOWeakSet set];
		[set addObject:a];
		[set addObject:b];
		OO_CHECK_EQ([set count], 2u);
		[a release];
		OO_CHECK_EQ([set count], 1u);
		OO_CHECK(Members([set cxx_allObjects]) == std::vector<id>({ b }));
		OO_CHECK([set containsObject:b]);
	}
	[b release];
}


OO_TEST(makeObjectsPerformSelector)
{
	TestMember *a = NewMember(1), *b = NewMember(2);
	id argument = [[OOObject alloc] init];
	@autoreleasepool
	{
		OOWeakSet *set = [OOWeakSet set];
		[set addObject:a];
		[set addObject:b];
		[set makeObjectsPerformSelector:@selector(frob)];
		OO_CHECK(a->frobs == 1 && b->frobs == 1);
		[set makeObjectsPerformSelector:@selector(frobWith:) withObject:argument];
		OO_CHECK(a->frobs == 2 && b->frobs == 2);
		OO_CHECK(a->lastArgument == argument && b->lastArgument == argument);
	}
	[a release];
	[b release];
	[argument release];
}


OO_TEST(addObjectsByEnumerating)
{
	TestMember *a = NewMember(1), *b = NewMember(2);
	@autoreleasepool
	{
		OOWeakSet *set = [OOWeakSet set];
		[set addObject:b];
		TestEnumerator *enumerator = [[[TestEnumerator alloc] init] autorelease];
		enumerator->objects = { a, b, a };
		[set addObjectsByEnumerating:enumerator];
		OO_CHECK(Members([set cxx_allObjects]) == std::vector<id>({ b, a }));
	}
	[a release];
	[b release];
}


OO_TEST(copiesAndEquality)
{
	TestMember *a = NewMember(1), *b = NewMember(2), *c = NewMember(3);
	@autoreleasepool
	{
		OOWeakSet *set = [OOWeakSet set];
		[set addObject:a];
		[set addObject:b];
		OOWeakSet *copy = [[set copy] autorelease];
		OOWeakSet *mutableCopy = [[set mutableCopy] autorelease];
		OO_CHECK(copy != set && mutableCopy != set && copy != mutableCopy);	// new sets
		OO_CHECK(Members([copy cxx_allObjects]) == std::vector<id>({ a, b }));
		OO_CHECK([copy isEqual:set] && [set isEqual:copy] && [mutableCopy isEqual:set]);

		[copy addObject:c];	// independent of the original
		OO_CHECK_EQ([set count], 2u);
		OO_CHECK(![copy isEqual:set]);

		OOWeakSet *other = [OOWeakSet set];
		[other addObject:b];
		[other addObject:a];	// same members, another order
		OO_CHECK([other isEqual:set]);
		[other removeObject:a];
		[other addObject:c];	// same count, another member
		OO_CHECK(![other isEqual:set]);
		OO_CHECK(![set isEqual:[[[OOObject alloc] init] autorelease]]);
		OO_CHECK(![set isEqual:nil]);
	}
	[a release];
	[b release];
	[c release];
}


OO_TEST(description)
{
	TestMember *a = NewMember(1), *b = NewMember(2);
	@autoreleasepool
	{
		OOWeakSet *set = [OOWeakSet set];
		const std::string prefix = "<OOWeakSet " + oo::str::pointerDescription(set) + ">{";
		OO_CHECK_EQ(oo::DescriptionOf(set), prefix + "}");
		[set addObject:a];
		[set addObject:b];
		OO_CHECK_EQ(oo::DescriptionOf(set), prefix + oo::ShortDescriptionOf(a) + ", " + oo::ShortDescriptionOf(b) + "}");
	}
	[a release];
	[b release];
}


OO_TEST_MAIN()
