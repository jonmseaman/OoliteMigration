/*	test_plist.cpp
	Unit tests for oofnd/PList.hpp (bead oo-075): the oo::PList value type - the nine kinds a
	parsed property list can hold, their accessors, NSNumber's conversions, value semantics, and
	the UTF-16 <-> UTF-8 conversion the parsers and writers use for NSString's code units.
	meson test --suite oofnd-plist
*/

#include "oofnd/PList.hpp"

#include "oo_test.hpp"
#include "plist_dump.hpp"

#include <cmath>
#include <cstdint>
#include <limits>
#include <string>
#include <utility>

using oo::PList;

OO_TEST(defaultIsNull)
{
	PList p;
	OO_CHECK(p.isNull());
	OO_CHECK(p.type() == PList::Type::Null);
	OO_CHECK(!p);
	OO_CHECK(PList(nullptr).isNull());
	OO_CHECK_EQ(p.count(), 0u);
	OO_CHECK(p.find("x") == nullptr);
	OO_CHECK(p.at(0) == nullptr);
	OO_CHECK(p.getIf<std::string>() == nullptr);
	OO_CHECK_EQ(oo_test::dump(p), "nil");
}

OO_TEST(eachKindHasItsType)
{
	OO_CHECK(PList(true).type() == PList::Type::Bool);
	OO_CHECK(PList(42).type() == PList::Type::Integer);
	OO_CHECK(PList(std::uint64_t{42}).type() == PList::Type::Integer);
	OO_CHECK(PList(1.5).type() == PList::Type::Real);
	OO_CHECK(PList(1.5f).type() == PList::Type::Real);
	OO_CHECK(PList("s").type() == PList::Type::String);
	OO_CHECK(PList(std::string("s")).type() == PList::Type::String);
	OO_CHECK(PList(std::string_view("s")).type() == PList::Type::String);
	OO_CHECK(PList(PList::Data{1, 2}).type() == PList::Type::Data);
	OO_CHECK(PList(PList::Date{3.0}).type() == PList::Type::Date);
	OO_CHECK(PList(PList::Array{}).type() == PList::Type::Array);
	OO_CHECK(PList(PList::Dict{}).type() == PList::Type::Dict);
	OO_CHECK(PList(true).isNumber() && PList(1).isNumber() && PList(1.0).isNumber());
	OO_CHECK(!PList("1").isNumber());
	OO_CHECK_EQ(std::string(oo::typeName(PList::Type::Dict)), "dict");
	OO_CHECK_EQ(std::string(oo::typeName(PList::Type::Null)), "null");
}

OO_TEST(getIfReturnsPayloadOnlyForItsType)
{
	PList s("hello");
	OO_CHECK(s.getIf<std::string>() != nullptr && *s.getIf<std::string>() == "hello");
	OO_CHECK(s.getIf<PList::Dict>() == nullptr);
	OO_CHECK(s.getIf<bool>() == nullptr);

	PList b(false);
	OO_CHECK(b.getIf<bool>() != nullptr && *b.getIf<bool>() == false);
	OO_CHECK(b);   // a false boolean is still a value, not nil

	PList i(-7);
	OO_CHECK(i.getIf<PList::Integer>() != nullptr);
	OO_CHECK_EQ(i.getIf<PList::Integer>()->value, -7);
	OO_CHECK(!i.getIf<PList::Integer>()->isUnsigned);

	PList d(PList::Data{0xde, 0xad});
	OO_CHECK(d.getIf<PList::Data>()->size() == 2 && (*d.getIf<PList::Data>())[1] == 0xad);
	OO_CHECK_EQ(PList(PList::Date{12.5}).getIf<PList::Date>()->sinceReferenceDate, 12.5);
}

OO_TEST(integerSignednessIsKept)
{
	PList u = PList::unsignedInteger(std::numeric_limits<std::uint64_t>::max());
	OO_CHECK(u.getIf<PList::Integer>()->isUnsigned);
	OO_CHECK_EQ(u.uint64Value(), std::numeric_limits<std::uint64_t>::max());
	OO_CHECK_EQ(u.int64Value(), -1);   // NSNumber longLongValue of ULLONG_MAX
	OO_CHECK_EQ(oo_test::dump(u), "U18446744073709551615");

	PList s = PList::signedInteger(std::numeric_limits<std::int64_t>::min());
	OO_CHECK(!s.getIf<PList::Integer>()->isUnsigned);
	OO_CHECK_EQ(oo_test::dump(s), "I-9223372036854775808");

	OO_CHECK(PList(5u).getIf<PList::Integer>()->isUnsigned);
	OO_CHECK(!PList(5).getIf<PList::Integer>()->isUnsigned);
	OO_CHECK_EQ(oo_test::dump(PList(5u)), "I5");   // small unsigned values read like GNUstep's
	OO_CHECK(PList::unsignedInteger(5) != PList::signedInteger(5));
}

OO_TEST(numberConversionsFollowNSNumber)
{
	OO_CHECK_EQ(PList(true).int64Value(), 1);
	OO_CHECK_EQ(PList(true).doubleValue(), 1.0);
	OO_CHECK_EQ(PList(false).uint64Value(), 0u);
	OO_CHECK(PList(2).boolValue());
	OO_CHECK(!PList(0).boolValue());
	OO_CHECK(PList(0.5).boolValue());
	OO_CHECK_EQ(PList(-3).doubleValue(), -3.0);
	OO_CHECK_EQ(PList::unsignedInteger(1ull << 63).doubleValue(), 9223372036854775808.0);
	OO_CHECK_EQ(PList(2.9).int64Value(), 2);
	OO_CHECK_EQ(PList(-2.9).int64Value(), -2);
	// Out-of-range and NaN reals saturate instead of hitting undefined behaviour.
	OO_CHECK_EQ(PList(1e300).int64Value(), std::numeric_limits<std::int64_t>::max());
	OO_CHECK_EQ(PList(-1e300).int64Value(), std::numeric_limits<std::int64_t>::min());
	OO_CHECK_EQ(PList(std::nan("")).int64Value(), 0);
	OO_CHECK_EQ(PList(1e300).uint64Value(), std::numeric_limits<std::uint64_t>::max());
	// Non-numbers answer 0, as a message to nil does.
	OO_CHECK_EQ(PList("12").int64Value(), 0);
	OO_CHECK_EQ(PList().doubleValue(), 0.0);
	OO_CHECK(!PList(PList::Array{1}).boolValue());
}

OO_TEST(arrayAccess)
{
	PList a(PList::Array{1, "two", 3.0});
	OO_CHECK_EQ(a.count(), 3u);
	OO_CHECK(a.at(1) != nullptr && a.at(1)->isString());
	OO_CHECK(a.at(3) == nullptr);
	OO_CHECK(a.find("two") == nullptr);   // not a dictionary
	a.getIf<PList::Array>()->push_back(PList(true));
	OO_CHECK_EQ(a.count(), 4u);
	OO_CHECK_EQ(oo_test::dump(a), "[I1,S\"two\",R3,B1]");
}

OO_TEST(dictAccess)
{
	PList d(PList::Dict{{"b", 2}, {"a", "x"}});
	OO_CHECK_EQ(d.count(), 2u);
	OO_CHECK(d.find("a") != nullptr && *d.find("a")->getIf<std::string>() == "x");
	OO_CHECK(d.find("c") == nullptr);
	OO_CHECK(d.at(0) == nullptr);   // not an array
	*d.find("b") = PList(PList::Array{});
	OO_CHECK(d.find("b")->isArray());
	(*d.getIf<PList::Dict>())["c"] = PList(false);
	OO_CHECK_EQ(oo_test::dump(d), "{\"a\"=S\"x\";\"b\"=[];\"c\"=B0;}");
	// Iteration is in byte order of the UTF-8 key: deterministic.
	std::string order;
	for (const auto& kv : *d.getIf<PList::Dict>()) order += kv.first;
	OO_CHECK_EQ(order, "abc");
}

OO_TEST(valueSemanticsDeepCopy)
{
	PList inner(PList::Dict{{"k", PList(PList::Array{1, 2})}});
	PList outer(PList::Array{inner, inner});
	PList copy = outer;
	OO_CHECK(copy == outer);
	copy.getIf<PList::Array>()->at(0).find("k")->getIf<PList::Array>()->push_back(3);
	OO_CHECK(copy != outer);
	OO_CHECK_EQ(outer.at(0)->find("k")->count(), 2u);
	OO_CHECK_EQ(copy.at(0)->find("k")->count(), 3u);
	OO_CHECK_EQ(copy.at(1)->find("k")->count(), 2u);

	PList moved = std::move(copy);
	OO_CHECK_EQ(moved.at(0)->find("k")->count(), 3u);
}

OO_TEST(equalityIsStructuralAndTypeStrict)
{
	OO_CHECK(PList("a") == PList(std::string("a")));
	OO_CHECK(PList("a") != PList("b"));
	OO_CHECK(PList(1) != PList(1.0));
	OO_CHECK(PList(1) != PList(true));
	OO_CHECK(PList() == PList(nullptr));
	OO_CHECK(PList(PList::Array{1, "x"}) == PList(PList::Array{1, "x"}));
	OO_CHECK(PList(PList::Array{1, "x"}) != PList(PList::Array{"x", 1}));
	OO_CHECK(PList(PList::Dict{{"a", 1}}) == PList(PList::Dict{{"a", 1}}));
	OO_CHECK(PList(PList::Dict{{"a", 1}}) != PList(PList::Dict{{"a", 2}}));
	OO_CHECK(PList(PList::Data{1}) != PList(PList::Data{1, 0}));
	OO_CHECK(PList(PList::Date{1.0}) == PList(PList::Date{1.0}));
}

OO_TEST(utf16RoundTripsThroughUtf8)
{
	// ASCII, 2-, 3- and 4-byte UTF-8.
	const std::u16string s = u"a\u00E9\u20AC\U0001F600z";
	const std::string u8 = oo::utf16ToUtf8(s);
	OO_CHECK_EQ(u8, std::string("a\xC3\xA9\xE2\x82\xAC\xF0\x9F\x98\x80z"));
	OO_CHECK(oo::utf8ToUtf16(u8) == s);
	// Embedded U+0000 survives.
	const std::u16string nul(u"x\0y", 3);
	OO_CHECK_EQ(oo::utf16ToUtf8(nul).size(), 3u);
	OO_CHECK(oo::utf8ToUtf16(oo::utf16ToUtf8(nul)) == nul);
}

OO_TEST(loneSurrogatesAreKeptAsWtf8)
{
	const std::u16string lone(1, static_cast<char16_t>(0xD800));
	const std::string w = oo::utf16ToUtf8(lone);
	OO_CHECK_EQ(w, std::string("\xED\xA0\x80"));
	OO_CHECK(oo::utf8ToUtf16(w) == lone);
	const std::u16string swapped{static_cast<char16_t>(0xDC00), static_cast<char16_t>(0xD800)};
	OO_CHECK(oo::utf8ToUtf16(oo::utf16ToUtf8(swapped)) == swapped);
	OO_CHECK_EQ(oo_test::dump(PList(w)), "S\"\\uD800\"");
}

OO_TEST(malformedUtf8ReadsAsLatin1Units)
{
	// A stray continuation byte and a truncated sequence each become one code unit.
	const std::u16string u = oo::utf8ToUtf16(std::string("a\x80" "b\xC3", 4));
	OO_CHECK(u == (std::u16string{u'a', static_cast<char16_t>(0x80), u'b', static_cast<char16_t>(0xC3)}));
	// Overlong encodings are not decoded.
	OO_CHECK_EQ(oo::utf8ToUtf16(std::string("\xC0\xAF")).size(), 2u);
}

OO_TEST_MAIN()
