/*	test_OOProbabilitySet.mm
	Unit tests for OOProbabilitySet and OOMutableProbabilitySet (src/Core/OOProbabilitySet.h):
	bead oo-489v, a Phase 3 conversion in the house style of the OOColor exemplar (proposed
	ADR-0056).

	It pins what the class cluster computed before the conversion, written against the
	Objective-C API and run on the unconverted classes first: the empty set (one shared object),
	the one-object and general immutable sets, weights (clamped at zero), sums, probabilities,
	the weighted pick (a zero weight is never picked; all zero picks nothing), the property-list
	round trip, element identity (strings by value, Object nodes by object), the mutable set
	(including its weight lookup, which subtracts the previous entry's weight), copies both ways,
	the description, and the exception for a non-zero count with no arrays.
	Run: bash tools/check-core-tests.sh
*/

#import "OOProbabilitySet.h"
#import "OODescription.h"
#import "OOObjCPList.h"
#include "oofnd/objc/OOException.h"
#import "legacy_random.h"

#include "oo_test.hpp"

#include <cmath>
#include <cstring>


namespace {

oo::PList Str(const char *string)
{
	return oo::PList(std::string(string));
}


bool Near(float a, float b)
{
	return std::fabs(a - b) < 1e-5f;
}


std::vector<std::string> Strings(const std::vector<oo::PList> &values)
{
	std::vector<std::string> result;
	for (const oo::PList &value : values)  result.push_back(value.isString() ? *value.getIf<std::string>() : std::string("?"));
	return result;
}


const oo::PList kABC[] = { Str("a"), Str("b"), Str("c") };
const float kWeights[] = { 1.0f, 0.0f, 2.0f };

}	// namespace


OO_TEST(emptySet)
{
	@autoreleasepool
	{
		OOProbabilitySet *empty = [OOProbabilitySet probabilitySet];
		OO_CHECK(empty != nil && empty == [OOProbabilitySet probabilitySet]);	// one shared object
		OO_CHECK(empty == [[[OOProbabilitySet alloc] init] autorelease]);
		OO_CHECK(empty == [OOProbabilitySet probabilitySetWithObjects:NULL weights:NULL count:0]);
		OO_CHECK([[empty copy] autorelease] == empty);
		OO_CHECK([empty count] == 0);
		OO_CHECK([empty randomObject].isNull());
		OO_CHECK([empty weightForObject:Str("a")] == -1.0f);
		OO_CHECK([empty sumOfWeights] == 0.0f);
		OO_CHECK([empty cxx_allElements].empty());
		OO_CHECK(![empty cxx_containsObject:Str("a")]);
		OO_CHECK([empty propertyListRepresentation] == oo::PList(oo::PList::Dict({ { "objects", oo::PList(oo::PList::Array()) }, { "weights", oo::PList(oo::PList::Array()) } })));
		OO_CHECK(oo::DescriptionOf(empty).ends_with(">{count=0}"));
	}
}


OO_TEST(oneObjectSet)
{
	@autoreleasepool
	{
		const oo::PList object = Str("cobra");
		const float weight = -2.0f;
		OOProbabilitySet *one = [OOProbabilitySet probabilitySetWithObjects:&object weights:&weight count:1];
		OO_CHECK([one count] == 1);
		OO_CHECK([one weightForObject:Str("cobra")] == 0.0f);	// clamped
		OO_CHECK([one weightForObject:Str("viper")] == -1.0f);
		OO_CHECK([one randomObject] == object);	// even at weight 0
		OO_CHECK([one sumOfWeights] == 0.0f);
		OO_CHECK(Strings([one cxx_allElements]) == std::vector<std::string>({ "cobra" }));
		OO_CHECK([[one copy] autorelease] == one);	// immutable: copy is retain
		OO_CHECK(oo::DescriptionOf(one).ends_with(">{count=1}"));

		const float two = 2.0f;
		OOProbabilitySet *weighted = [OOProbabilitySet probabilitySetWithObjects:&object weights:&two count:1];
		OO_CHECK([weighted probabilityForObject:Str("cobra")] == 1.0f);
		OO_CHECK([weighted propertyListRepresentation] == oo::PList(oo::PList::Dict({ { "objects", oo::PList(oo::PList::Array({ object })) }, { "weights", oo::PList(oo::PList::Array({ oo::PList::singleReal(2.0f) })) } })));
	}
}


OO_TEST(generalSet)
{
	@autoreleasepool
	{
		OOProbabilitySet *set = [OOProbabilitySet probabilitySetWithObjects:kABC weights:kWeights count:3];
		OO_CHECK([set count] == 3);
		OO_CHECK(Strings([set cxx_allElements]) == std::vector<std::string>({ "a", "b", "c" }));
		OO_CHECK([set weightForObject:Str("a")] == 1.0f && [set weightForObject:Str("b")] == 0.0f && [set weightForObject:Str("c")] == 2.0f);
		OO_CHECK([set weightForObject:Str("d")] == -1.0f && [set weightForObject:oo::PList()] == -1.0f);
		OO_CHECK([set sumOfWeights] == 3.0f);
		OO_CHECK(Near([set probabilityForObject:Str("a")], 1.0f / 3.0f) && [set probabilityForObject:Str("b")] == 0.0f && [set probabilityForObject:Str("d")] == -1.0f);
		OO_CHECK([set cxx_containsObject:Str("b")] && ![set cxx_containsObject:Str("d")]);
		OO_CHECK([[set copy] autorelease] == set);
		OO_CHECK(oo::DescriptionOf(set).ends_with(">{count=3}"));

		ranrot_srand(12345);	// (unseeded, randf() is always 0)
		int picks[3] = { 0, 0, 0 };
		for (int i = 0; i < 300; i++)
		{
			const oo::PList pick = [set randomObject];
			for (int j = 0; j < 3; j++)  if (pick == kABC[j])  picks[j]++;
		}
		OO_CHECK(picks[0] > 0 && picks[1] == 0 && picks[2] > 0 && picks[0] + picks[2] == 300);	// weight 0: never

		const float zeros[] = { 0.0f, 0.0f, 0.0f };
		OO_CHECK([[OOProbabilitySet probabilitySetWithObjects:kABC weights:zeros count:3] randomObject].isNull());

		// The weights come back from the cumulative ones.
		oo::PList::Array weights = { oo::PList::singleReal(1.0f), oo::PList::singleReal(0.0f), oo::PList::singleReal(2.0f) };
		OO_CHECK([set propertyListRepresentation] == oo::PList(oo::PList::Dict({ { "objects", oo::PList(oo::PList::Array(std::begin(kABC), std::end(kABC))) }, { "weights", oo::PList(weights) } })));
	}
}


OO_TEST(propertyListRoundTrip)
{
	@autoreleasepool
	{
		OOProbabilitySet *set = [OOProbabilitySet probabilitySetWithObjects:kABC weights:kWeights count:3];
		OOProbabilitySet *again = [OOProbabilitySet probabilitySetWithPropertyListRepresentation:[set propertyListRepresentation]];
		OO_CHECK([again propertyListRepresentation] == [set propertyListRepresentation]);

		// Negative weights are clamped; mismatched or missing arrays give nil.
		oo::PList negative(oo::PList::Dict({ { "objects", oo::PList(oo::PList::Array({ Str("x"), Str("y") })) }, { "weights", oo::PList(oo::PList::Array({ oo::PList(-1.0), oo::PList(std::int64_t(3)) })) } }));
		OOProbabilitySet *clamped = [OOProbabilitySet probabilitySetWithPropertyListRepresentation:negative];
		OO_CHECK([clamped weightForObject:Str("x")] == 0.0f && [clamped weightForObject:Str("y")] == 3.0f);
		oo::PList mismatched(oo::PList::Dict({ { "objects", oo::PList(oo::PList::Array({ Str("x") })) }, { "weights", oo::PList(oo::PList::Array()) } }));
		OO_CHECK([OOProbabilitySet probabilitySetWithPropertyListRepresentation:mismatched] == nil);
		OO_CHECK([OOProbabilitySet probabilitySetWithPropertyListRepresentation:oo::PList()] == nil);
		OO_CHECK([OOMutableProbabilitySet probabilitySetWithPropertyListRepresentation:mismatched] == nil);

		oo::PList one(oo::PList::Dict({ { "objects", oo::PList(oo::PList::Array({ Str("x") })) }, { "weights", oo::PList(oo::PList::Array({ oo::PList(0.5) })) } }));
		OO_CHECK([[OOProbabilitySet probabilitySetWithPropertyListRepresentation:one] weightForObject:Str("x")] == 0.5f);
	}
}


OO_TEST(objectElements)
{
	@autoreleasepool
	{
		OOObject *object = [[[OOObject alloc] init] autorelease];
		const oo::PList elements[] = { oo::PListObject(object), Str("s") };
		const float weights[] = { 1.0f, 1.0f };
		OOProbabilitySet *set = [OOProbabilitySet probabilitySetWithObjects:elements weights:weights count:2];
		OO_CHECK([set weightForObject:oo::PListObject(object)] == 1.0f);	// the same object in another node
		OO_CHECK([set weightForObject:oo::PListObject([[[OOObject alloc] init] autorelease])] == -1.0f);
		OO_CHECK(oo::ObjectIn([set cxx_allElements][0]) == object);
	}
}


OO_TEST(mutableSet)
{
	@autoreleasepool
	{
		OOMutableProbabilitySet *set = [OOMutableProbabilitySet probabilitySet];
		OO_CHECK(set != nil && set != (id)[OOProbabilitySet probabilitySet] && [set count] == 0);
		OO_CHECK([set randomObject].isNull() && [set sumOfWeights] == 0.0f);
		OO_CHECK(oo::DescriptionOf(set).ends_with(">{count=0}"));

		[set setWeight:1.0f forObject:Str("a")];
		[set setWeight:3.0f forObject:Str("b")];
		[set setWeight:-1.0f forObject:Str("c")];	// clamped to 0
		[set setWeight:5.0f forObject:oo::PList()];	// ignored
		OO_CHECK([set count] == 3 && Strings([set cxx_allElements]) == std::vector<std::string>({ "a", "b", "c" }));
		OO_CHECK([set sumOfWeights] == 4.0f);
		// The mutable set's lookup subtracts the previous entry's weight, as if they were cumulative.
		OO_CHECK([set weightForObject:Str("a")] == 1.0f);
		OO_CHECK([set weightForObject:Str("b")] == 2.0f);
		OO_CHECK([set weightForObject:Str("c")] == -3.0f);
		OO_CHECK([set weightForObject:Str("d")] == -1.0f);

		[set setWeight:2.0f forObject:Str("a")];	// an update recomputes the sum on demand
		OO_CHECK([set count] == 3 && [set sumOfWeights] == 5.0f);
		[set cxx_removeObject:Str("b")];
		[set cxx_removeObject:Str("zz")];
		[set cxx_removeObject:oo::PList()];
		OO_CHECK(Strings([set cxx_allElements]) == std::vector<std::string>({ "a", "c" }) && [set sumOfWeights] == 2.0f);
		for (int i = 0; i < 100; i++)  OO_CHECK([set randomObject] == Str("a"));	// c has weight 0

		OOMutableProbabilitySet *made = [OOMutableProbabilitySet probabilitySetWithObjects:kABC weights:kWeights count:3];
		OO_CHECK([made count] == 3 && [made sumOfWeights] == 3.0f);
		[made setWeight:1.0f forObject:Str("d")];
		OO_CHECK([made count] == 4);
		OOMutableProbabilitySet *fromPList = [OOMutableProbabilitySet probabilitySetWithPropertyListRepresentation:[made propertyListRepresentation]];
		OO_CHECK([fromPList count] == 4 && [fromPList sumOfWeights] == 4.0f);
		OO_CHECK([[[[OOMutableProbabilitySet alloc] init] autorelease] count] == 0);
	}
}


OO_TEST(copies)
{
	@autoreleasepool
	{
		// Mutable to immutable: the empty set, a one-object set, a general set.
		OOMutableProbabilitySet *mutableSet = [OOMutableProbabilitySet probabilitySet];
		OO_CHECK([[mutableSet copy] autorelease] == [OOProbabilitySet probabilitySet]);
		[mutableSet setWeight:2.0f forObject:Str("a")];
		OOProbabilitySet *one = [[mutableSet copy] autorelease];
		OO_CHECK(one != mutableSet && [one count] == 1 && [one weightForObject:Str("a")] == 2.0f);
		[mutableSet setWeight:0.5f forObject:Str("b")];
		[mutableSet setWeight:1.5f forObject:Str("c")];
		OOProbabilitySet *general = [[mutableSet copy] autorelease];
		OO_CHECK([general count] == 3 && [general sumOfWeights] == 4.0f);
		OO_CHECK([general weightForObject:Str("a")] == 2.0f && [general weightForObject:Str("b")] == 0.5f && [general weightForObject:Str("c")] == 1.5f);

		// Immutable to mutable, and mutable to mutable: independent.
		OOMutableProbabilitySet *back = [[general mutableCopy] autorelease];
		OO_CHECK([back count] == 3 && [back sumOfWeights] == 4.0f);
		[back cxx_removeObject:Str("a")];
		OO_CHECK([back count] == 2 && [general count] == 3);
		// (A removal leaves the sum to be recomputed on demand, and a mutable copy asserts that it is
		// known: -sumOfWeights first, as the game never copies a mutable set it has edited.)
		OO_CHECK([back sumOfWeights] == 2.0f);
		OOMutableProbabilitySet *twin = [[back mutableCopy] autorelease];
		[twin setWeight:9.0f forObject:Str("z")];
		OO_CHECK([twin count] == 3 && [back count] == 2 && [twin sumOfWeights] == 11.0f);
		OO_CHECK([[[one mutableCopy] autorelease] count] == 1);
		OO_CHECK([[[[OOProbabilitySet probabilitySet] mutableCopy] autorelease] count] == 0);
	}
}


OO_TEST(nonZeroCountWithoutArraysRaises)
{
	@autoreleasepool
	{
		const char *name = nullptr;
		@try
		{
			(void)[OOProbabilitySet probabilitySetWithObjects:NULL weights:NULL count:2];
		}
		@catch (OOException *e)
		{
			name = [e name];
		}
		OO_CHECK(name != nullptr && std::strcmp(name, OOInvalidArgumentException) == 0);
	}
}


OO_TEST_MAIN()
