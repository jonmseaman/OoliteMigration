/*	test_OOCache.mm
	Unit tests for OOCache (src/Core/OOCache.h): bead oo-rdfh, a Phase 3 conversion in the house
	style of the OOColor exemplar (proposed ADR-0056).

	It pins what the cache computed before the conversion, written against the Objective-C API and
	run on the unconverted class first: an empty cache's settings, storing, replacing and removing
	values (a null value is not stored), dirtiness, least-recently-used order (a lookup promotes),
	pruning (the threshold's floor, auto-pruning to 80%, manual pruning to the threshold, no
	pruning while loading), the property-list round trip, a live object held in an Object node,
	the name and the description. Run: bash tools/check-core-tests.sh
*/

#import "OOCache.h"
#import "OODescription.h"
#import "OOObjCPList.h"

#include "oo_test.hpp"


/*	The game's OOStringParsing.mm reaches the JavaScript engine, so it is not linked. The one
	function of it that the cache names (in its DEBUG_GRAPHVIZ dump, which no test calls) is
	defined here instead.
*/
std::string cxx_EscapedGraphVizString(const std::string &string)
{
	return string;
}


namespace {

oo::PList Str(const std::string &string)
{
	return oo::PList(string);
}


std::vector<std::string> Strings(const std::vector<oo::PList> &values)
{
	std::vector<std::string> result;
	for (const oo::PList &value : values)  result.push_back(value.isString() ? *value.getIf<std::string>() : std::string("?"));
	return result;
}


oo::PList Entry(const std::string &key, const oo::PList &value)
{
	oo::PList::Dict entry;
	entry.emplace("key", Str(key));
	entry.emplace("value", value);
	return oo::PList(std::move(entry));
}

}	// namespace


OO_TEST(emptyCache)
{
	@autoreleasepool
	{
		OOCache *cache = [[[OOCache alloc] init] autorelease];
		OO_CHECK(cache != nil);
		OO_CHECK([cache pruneThreshold] == kOOCacheDefaultPruneThreshold);
		OO_CHECK([cache autoPrune]);
		OO_CHECK(![cache dirty]);
		OO_CHECK(![cache cxx_name].has_value());
		OO_CHECK([cache cxx_pListRepresentation].isNull());
		OO_CHECK([cache pListsByAge].empty());
		OO_CHECK([cache cxx_pListForKey:"absent"].isNull());

		std::string text = oo::DescriptionOf(cache);
		OO_CHECK(text.starts_with("<OOCache 0x") && text.ends_with(">{\"(null)\", 0 elements, prune threshold=200, auto-prune=yes dirty=no}"));
		[cache cxx_setName:std::string("Text encoding")];
		OO_CHECK([cache cxx_name] == std::optional<std::string>("Text encoding"));
		OO_CHECK(oo::DescriptionOf(cache).ends_with(">{\"Text encoding\", 0 elements, prune threshold=200, auto-prune=yes dirty=no}"));
		[cache cxx_setName:std::nullopt];
		OO_CHECK(![cache cxx_name].has_value());
	}
}


OO_TEST(storeReplaceRemove)
{
	@autoreleasepool
	{
		OOCache *cache = [[[OOCache alloc] init] autorelease];
		[cache cxx_setPList:oo::PList() forKey:"null"];	// a null value is not stored
		OO_CHECK(![cache dirty] && [cache pListsByAge].empty());

		[cache cxx_setPList:Str("one") forKey:"a"];
		OO_CHECK([cache dirty]);
		OO_CHECK([cache cxx_pListForKey:"a"] == Str("one"));
		[cache markClean];
		OO_CHECK(![cache dirty]);

		[cache cxx_setPList:Str("uno") forKey:"a"];	// replacing marks it dirty too
		OO_CHECK([cache dirty] && [cache cxx_pListForKey:"a"] == Str("uno"));
		[cache markClean];

		[cache cxx_removePListForKey:"b"];	// absent: not dirty
		OO_CHECK(![cache dirty]);
		[cache cxx_removePListForKey:"a"];
		OO_CHECK([cache dirty] && [cache cxx_pListForKey:"a"].isNull());
		OO_CHECK(oo::DescriptionOf(cache).ends_with(">{\"(null)\", 0 elements, prune threshold=200, auto-prune=yes dirty=yes}"));
	}
}


OO_TEST(leastRecentlyUsedOrder)
{
	@autoreleasepool
	{
		OOCache *cache = [[[OOCache alloc] init] autorelease];
		for (const char *key : { "d", "b", "a", "c" })  [cache cxx_setPList:Str(std::string("value ") + key) forKey:key];
		OO_CHECK(Strings([cache pListsByAge]) == std::vector<std::string>({ "value c", "value a", "value b", "value d" }));	// youngest first

		(void)[cache cxx_pListForKey:"d"];	// a lookup promotes
		(void)[cache cxx_pListForKey:"zz"];	// a miss does not change the order
		[cache markClean];
		OO_CHECK(Strings([cache pListsByAge]) == std::vector<std::string>({ "value d", "value c", "value a", "value b" }));
		OO_CHECK(![cache dirty]);	// reordering does not dirty it

		// The property list: {key, value} entries, oldest first.
		oo::PList::Array expected = { Entry("b", Str("value b")), Entry("a", Str("value a")), Entry("c", Str("value c")), Entry("d", Str("value d")) };
		OO_CHECK([cache cxx_pListRepresentation] == oo::PList(expected));
	}
}


OO_TEST(pruning)
{
	@autoreleasepool
	{
		OOCache *cache = [[[OOCache alloc] init] autorelease];
		[cache setPruneThreshold:3];
		OO_CHECK([cache pruneThreshold] == kOOCacheMinimumPruneThreshold);	// the floor

		// Auto-pruning: past the threshold, down to 80% of it, oldest first.
		for (int i = 0; i < 25; i++)  [cache cxx_setPList:Str(std::to_string(i)) forKey:std::to_string(100 + i)];
		OO_CHECK([cache pListsByAge].size() == 25);
		[cache cxx_setPList:Str("25") forKey:"125"];
		OO_CHECK([cache pListsByAge].size() == 20);
		OO_CHECK([cache cxx_pListForKey:"105"].isNull() && [cache cxx_pListForKey:"106"] == Str("6"));

		// Manual pruning: nothing until -prune, then down to the threshold itself.
		[cache setAutoPrune:NO];
		OO_CHECK(![cache autoPrune]);
		for (int i = 26; i < 40; i++)  [cache cxx_setPList:Str(std::to_string(i)) forKey:std::to_string(100 + i)];
		OO_CHECK([cache pListsByAge].size() == 34);
		[cache prune];
		OO_CHECK([cache pListsByAge].size() == 25);

		// Raising the threshold prunes nothing; lowering it with auto-prune on prunes at once.
		[cache setPruneThreshold:30];
		OO_CHECK([cache pListsByAge].size() == 25);
		[cache setAutoPrune:YES];	// turning it on prunes (under the threshold: nothing)
		OO_CHECK([cache pListsByAge].size() == 25);
		[cache setPruneThreshold:kOOCacheMinimumPruneThreshold];
		OO_CHECK([cache pListsByAge].size() == 25);	// not over the threshold
		[cache cxx_setPList:Str("x") forKey:"x"];
		OO_CHECK([cache pListsByAge].size() == 20);

		[cache setPruneThreshold:kOOCacheNoPrune];
		for (int i = 0; i < 40; i++)  [cache cxx_setPList:Str("y") forKey:"y" + std::to_string(i)];
		[cache prune];
		OO_CHECK([cache pListsByAge].size() == 60);
	}
}


OO_TEST(propertyListRoundTrip)
{
	@autoreleasepool
	{
		oo::PList::Array entries;
		for (int i = 0; i < 250; i++)  entries.push_back(Entry("k" + std::to_string(i), oo::PList(std::int64_t(i))));
		entries.push_back(Str("not an entry"));
		entries.push_back(oo::PList(oo::PList::Dict({ { "key", oo::PList(std::int64_t(7)) }, { "value", Str("key not a string") } })));
		entries.push_back(oo::PList(oo::PList::Dict({ { "key", Str("no value") } })));

		OOCache *loaded = [[[OOCache alloc] cxx_initWithPList:oo::PList(entries)] autorelease];
		OO_CHECK(loaded != nil);
		OO_CHECK([loaded pListsByAge].size() == 250);	// loading does not prune, even past the threshold
		OO_CHECK([loaded dirty]);
		OO_CHECK([loaded pruneThreshold] == kOOCacheDefaultPruneThreshold && [loaded autoPrune]);
		OO_CHECK([loaded cxx_pListForKey:"k0"] == oo::PList(std::int64_t(0)));
		OO_CHECK([loaded cxx_pListForKey:"no value"].isNull());

		OOCache *again = [[[OOCache alloc] cxx_initWithPList:[loaded cxx_pListRepresentation]] autorelease];
		OO_CHECK([again cxx_pListRepresentation] == [loaded cxx_pListRepresentation]);

		OO_CHECK([[[[OOCache alloc] cxx_initWithPList:oo::PList()] autorelease] pListsByAge].empty());
		OO_CHECK([[OOCache alloc] cxx_initWithPList:Str("not an array")] == nil);
		OO_CHECK([[OOCache alloc] cxx_initWithPList:oo::PList(oo::PList::Dict())] == nil);
	}
}


OO_TEST(holdsALiveObject)
{
	OOObject *object = [[OOObject alloc] init];
	OOCache *cache = [[OOCache alloc] init];
	@autoreleasepool
	{
		[cache cxx_setPList:oo::PListObject(object) forKey:"texture"];
		OO_CHECK(oo::ObjectIn([cache cxx_pListForKey:"texture"]) == object);
		OO_CHECK([object retainCount] == 2);	// the cache retains it
	}
	[cache cxx_removePListForKey:"texture"];
	OO_CHECK([object retainCount] == 1);
	[cache release];
	[object release];
}


OO_TEST_MAIN()
