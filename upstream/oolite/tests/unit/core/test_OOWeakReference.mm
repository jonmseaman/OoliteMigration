/*	test_OOWeakReference.mm
	Unit tests for OOWeakReference (src/Core/OOWeakReference.h): bead oo-3kqi, a Phase 3
	conversion in the OOColor house style (proposed ADR-0056).

	Pins what a weak reference did before the conversion, through the Objective-C API its
	callers use: -weakRetain gives one reference per live object; the reference forwards every
	message to the object while it lives (a method of the object's own class, -class,
	-isKindOfClass:, -respondsToSelector:, the description family) and answers like nil once the
	object has gone; -hash is the reference's address shifted right by 3; the object is told when
	its reference dies (-weakRefDied:) and then makes a new one; and a class that implements
	OOWeakReferenceSupport itself is told the same.
	Run: bash tools/check-core-tests.sh
*/

#import "OOWeakReference.h"
#import "OODescription.h"

#include "oo_test.hpp"
#include "ooscript/JSEngine.hpp"


// The script engine's (JSEngine_quickjs.cpp would link the engine in): a dead reference's
// -oo_jsValueInContext: answers it, and these tests have no script context to ask with.
ooscript::Value ooscript::undefinedValue()
{
	return {};
}


@interface TestThing: OOWeakRefObject
- (int) frob;
@end


@implementation TestThing

- (int) frob
{
	return 42;
}


- (std::optional<std::string>) cxx_descriptionComponents
{
	return std::string("thing");
}


- (std::optional<std::string>) cxx_shortDescriptionComponents
{
	return std::string("short thing");
}

@end


// Implements the protocol itself, as OOJSScript does.
@interface TestSupporter: OOObject <OOWeakReferenceSupport>
{
@public
	OOWeakReference	*weakSelf;
	id				diedWith;
	int				deaths;
}
@end


@implementation TestSupporter

- (id) weakRetain
{
	if (weakSelf == nil)  weakSelf = [OOWeakReference weakRefWithObject:self];
	return [weakSelf retain];
}


- (void) weakRefDied:(OOWeakReference *)weakRef
{
	diedWith = weakRef;
	deaths++;
	if (weakRef == weakSelf)  weakSelf = nil;
}


- (void) dealloc
{
	[weakSelf weakRefDrop];
	[super dealloc];
}

@end


// Forwarding goes through the floor's hook, which the game's start-up installs (or gnustep-base's
// while it is linked); the tests install the floor's, as the oofnd objc tests do.
OO_TEST(installTheFloor)
{
	OOObjCInstallFloor();
	OO_CHECK(true);
}


OO_TEST(nilGivesNil)
{
	OO_CHECK([OOWeakReference weakRefWithObject:nil] == nil);
	id none = nil;
	OO_CHECK([none weakRefUnderlyingObject] == nil);
}


OO_TEST(oneReferencePerLiveObject)
{
	TestThing *thing = [[TestThing alloc] init];
	@autoreleasepool
	{
		OOWeakReference *ref = [thing weakRetain];
		OO_CHECK(ref != nil);
		OO_CHECK(ref != (id)thing);
		OOWeakReference *again = [thing weakRetain];
		OO_CHECK(again == ref);
		OO_CHECK([thing weakSelf] == ref);
		OO_CHECK([ref weakRefUnderlyingObject] == thing);
		OO_CHECK([thing weakRefUnderlyingObject] == thing);	// OOObject's: itself
		OO_CHECK([ref weakRetain] == ref);	// a reference's -weakRetain is -retain
		[ref release];
		[again release];
		[ref release];
	}
	[thing release];
}


OO_TEST(forwardsWhileTheObjectLives)
{
	TestThing *thing = [[TestThing alloc] init];
	@autoreleasepool
	{
		id ref = [thing weakSelf];
		OO_CHECK([ref frob] == 42);
		OO_CHECK([ref class] == [TestThing class]);
		OO_CHECK([ref isKindOfClass:[TestThing class]]);
		OO_CHECK([ref isKindOfClass:[OOWeakRefObject class]]);
		OO_CHECK([ref isMemberOfClass:[TestThing class]]);
		OO_CHECK(![ref isMemberOfClass:[OOWeakReference class]]);
		OO_CHECK([ref isProxy]);
		OO_CHECK([ref respondsToSelector:@selector(frob)]);
		OO_CHECK(![ref respondsToSelector:@selector(noSuchMethod)]);
		OO_CHECK([ref respondsToSelector:@selector(weakRefDrop)]);	// its own
		OO_CHECK([ref respondsToSelector:@selector(weakRefUnderlyingObject)]);
		OO_CHECK([ref conformsToProtocol:@protocol(OOWeakReferenceSupport)]);
		OO_CHECK_EQ(oo::DescriptionOf(ref), oo::DescriptionOf(thing));
		OO_CHECK([ref cxx_descriptionComponents] == std::optional<std::string>("thing"));
		OO_CHECK([ref cxx_shortDescriptionComponents] == std::optional<std::string>("short thing"));
		OO_CHECK([ref cxx_shortDescription] == [thing cxx_shortDescription]);
		OO_CHECK_EQ([ref hash], reinterpret_cast<uintptr_t>(ref) >> 3);
	}
	[thing release];
}


OO_TEST(answersLikeNilOnceTheObjectHasGone)
{
	TestThing *thing = [[TestThing alloc] init];
	id ref = [thing weakRetain];
	uintptr_t hash = [ref hash];
	[thing release];	// the object drops its reference

	OO_CHECK([ref weakRefUnderlyingObject] == nil);
	OO_CHECK([ref frob] == 0);
	OO_CHECK([ref class] == Nil);
	OO_CHECK(![ref isKindOfClass:[TestThing class]]);
	OO_CHECK([ref respondsToSelector:@selector(frob)]);	// "responds to everything", as nil did
	OO_CHECK([ref respondsToSelector:@selector(noSuchMethod)]);
	OO_CHECK(![ref cxx_descriptionComponents].has_value());
	const std::string description = oo::DescriptionOf(ref);
	OO_CHECK(description.rfind("<Dead (null) 0x", 0) == 0 && description.back() == '>');
	OO_CHECK_EQ([ref hash], hash);
	[ref release];
}


OO_TEST(theObjectMakesANewReferenceWhenItsOldOneDies)
{
	TestThing *thing = [[TestThing alloc] init];
	id first = nil;
	@autoreleasepool
	{
		first = [thing weakRetain];
	}
	OO_CHECK([first weakRefUnderlyingObject] == thing);
	OO_CHECK_EQ([first retainCount], 1u);
	[first release];	// its last holder: the reference dies, and the object forgets it

	id second = nil;
	@autoreleasepool
	{
		second = [thing weakRetain];
	}
	OO_CHECK(second != nil);
	OO_CHECK([second weakRefUnderlyingObject] == thing);
	OO_CHECK([second frob] == 42);
	[thing release];
	OO_CHECK([second weakRefUnderlyingObject] == nil);
	[second release];
}


OO_TEST(anImplementerIsToldItsReferenceDied)
{
	TestSupporter *supporter = [[TestSupporter alloc] init];
	OOWeakReference *ref = nil;
	@autoreleasepool
	{
		ref = [supporter weakRetain];	// +weakRefWithObject: autoreleased it; this holds the one retain
	}
	OO_CHECK(ref == supporter->weakSelf);
	OO_CHECK([ref weakRefUnderlyingObject] == supporter);
	OO_CHECK(supporter->deaths == 0);
	[ref release];
	OO_CHECK(supporter->deaths == 1);
	OO_CHECK(supporter->diedWith == ref);	// told with the reference itself
	OO_CHECK(supporter->weakSelf == nil);

	// A reference that outlives its object tells nobody when it dies.
	ref = [supporter weakRetain];
	[supporter release];
	OO_CHECK([ref weakRefUnderlyingObject] == nil);
	[ref release];
}


OO_TEST_MAIN()
