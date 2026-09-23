/*	oofnd/PList.hpp
	oo::PList: one property-list value, the replacement for the Foundation object graph that
	NSPropertyListSerialization hands to Oolite (NSString / NSNumber / NSData / NSDate /
	NSArray / NSDictionary, and nil). A value type: copying a PList copies the tree, as
	-mutableCopy / -copy of an immutable plist yields an equal tree.

	    Foundation (what the GNUstep parsers produce)       oo::PList
	    --------------------------------------------------  ---------------------------------------
	    nil (no plist, or the parse produced nothing)        PList()                 Type::Null
	    [NSNumber numberWithBool:] (the boolY/boolN          PList(true)             Type::Bool
	        singletons: XML <true/>, old-style <*BY>)
	    NSNumber of a signed integer type (XML <integer>     PList(std::int64_t)     Type::Integer
	        with a '-', old-style <*I-...>)
	    NSNumber of an unsigned type (XML <integer>          PList(std::uint64_t)    Type::Integer,
	        without '-', old-style <*I...>)                                          isUnsigned
	    NSNumber of double/float (XML <real>, <*R...>)       PList(double)           Type::Real
	    NSString                                             PList("text")           Type::String
	    NSData                                               PList(PList::Data{..})  Type::Data
	    NSDate / NSCalendarDate                              PList(PList::Date{..})  Type::Date
	    NSArray                                              PList(PList::Array{..}) Type::Array
	    NSDictionary                                         PList(PList::Dict{..})  Type::Dict

	Representation choices (ADR-0013 decision 4 and proposed ADR-0027):

	  * Strings are std::string holding UTF-8. NSString is UTF-16; a lone surrogate (which an
	    old-style "\UD800" escape can produce) is kept as its 3-byte generalised-UTF-8 form
	    (WTF-8), so no parsed value is lost. utf8ToUtf16()/utf16ToUtf8() below convert.
	  * Integers keep NSNumber's signedness: GNUstep stores a non-negative XML <integer> as
	    unsigned long long and a negative one as long long, and the writers print them with
	    %llu / %lld. Integer::value holds the bits; isUnsigned says which reading is meant.
	  * Dict keys are strings only (every plist the game reads has string keys; a parser that
	    meets a non-string key reports an error, see the parsers). Iteration is in byte order of
	    the UTF-8 key, i.e. deterministic; NSDictionary's order was hash order (unspecified).
	    The writers sort keys the way GNUstep does, so output never depends on this order.
	  * Date is NSDate's timeIntervalSinceReferenceDate: seconds since 2001-01-01T00:00:00Z.
	  * Equality (==) is structural and type-strict: PList(1) != PList(1.0) != PList(true),
	    although -[NSNumber isEqual:] would say they are equal. Nothing in the parsers or writers
	    relies on the looser rule.

	Accessors mirror std::variant: getIf<T>() returns a pointer to the payload, or nullptr when the
	value is another type - the shape of Oolite's `ValueIfClass(value, [NSDictionary class])`.
	T is one of bool, PList::Integer, double, std::string, PList::Data, PList::Date,
	PList::Array, PList::Dict. The typed, converting accessor that replaces
	OOCollectionExtractors (PList::get<T>) is a later seam; this header has no conversions
	beyond NSNumber's own (boolValue / longLongValue / unsignedLongLongValue / doubleValue).

	Also here, shared by the parsers: oo::PListFormat (NSPropertyListFormat) and oo::PListError
	(the error string GNUstep reports, and the -[NSError description] Oolite logged).
*/

#ifndef OOFND_PLIST_HPP
#define OOFND_PLIST_HPP

#include <cmath>
#include <compare>
#include <concepts>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <limits>
#include <map>
#include <string>
#include <string_view>
#include <type_traits>
#include <utility>
#include <variant>
#include <vector>

namespace oo {

class PList
{
public:
	enum class Type
	{
		Null,
		Bool,
		Integer,
		Real,
		String,
		Data,
		Date,
		Array,
		Dict,
	};

	struct Integer
	{
		std::int64_t value = 0;   // two's-complement bits; read as uint64 when isUnsigned
		bool isUnsigned = false;

		std::uint64_t unsignedValue() const noexcept { return static_cast<std::uint64_t>(value); }
		friend bool operator==(const Integer&, const Integer&) = default;
	};

	struct Date
	{
		double sinceReferenceDate = 0.0;   // seconds since 2001-01-01T00:00:00Z

		friend bool operator==(const Date&, const Date&) = default;
	};

	using Data = std::vector<std::uint8_t>;
	using Array = std::vector<PList>;
	using Dict = std::map<std::string, PList, std::less<>>;

	// --- construction ---------------------------------------------------------------------

	PList() noexcept = default;
	PList(std::nullptr_t) noexcept {}

	template <class B>
		requires std::same_as<B, bool>
	PList(B b) noexcept : v_(std::in_place_type<bool>, b) {}

	template <class I>
		requires(std::integral<I> && !std::same_as<I, bool> && !std::same_as<I, char>)
	PList(I i) noexcept : v_(std::in_place_type<Integer>, makeInteger(i)) {}

	template <class F>
		requires std::floating_point<F>
	PList(F d) noexcept : v_(std::in_place_type<double>, static_cast<double>(d)) {}

	PList(const char* s) : v_(std::in_place_type<std::string>, s) {}
	PList(std::string s) noexcept : v_(std::in_place_type<std::string>, std::move(s)) {}
	PList(std::string_view s) : v_(std::in_place_type<std::string>, s) {}
	PList(Integer i) noexcept : v_(std::in_place_type<Integer>, i) {}
	PList(Data d) noexcept : v_(std::in_place_type<Data>, std::move(d)) {}
	PList(Date d) noexcept : v_(std::in_place_type<Date>, d) {}
	PList(Array a) noexcept : v_(std::in_place_type<Array>, std::move(a)) {}
	PList(Dict d) noexcept : v_(std::in_place_type<Dict>, std::move(d)) {}

	static PList signedInteger(std::int64_t i) noexcept { return PList(Integer{i, false}); }
	static PList unsignedInteger(std::uint64_t u) noexcept { return PList(Integer{static_cast<std::int64_t>(u), true}); }

	// --- type queries ---------------------------------------------------------------------

	Type type() const noexcept { return static_cast<Type>(v_.index()); }
	bool isNull() const noexcept { return type() == Type::Null; }
	bool isBool() const noexcept { return type() == Type::Bool; }
	bool isInteger() const noexcept { return type() == Type::Integer; }
	bool isReal() const noexcept { return type() == Type::Real; }
	bool isNumber() const noexcept { return isBool() || isInteger() || isReal(); }   // NSNumber
	bool isString() const noexcept { return type() == Type::String; }
	bool isData() const noexcept { return type() == Type::Data; }
	bool isDate() const noexcept { return type() == Type::Date; }
	bool isArray() const noexcept { return type() == Type::Array; }
	bool isDict() const noexcept { return type() == Type::Dict; }
	explicit operator bool() const noexcept { return !isNull(); }   // "!= nil"

	// --- payload access -------------------------------------------------------------------

	template <class T>
	T* getIf() noexcept
	{
		return std::get_if<T>(&v_);
	}
	template <class T>
	const T* getIf() const noexcept
	{
		return std::get_if<T>(&v_);
	}

	// Dictionary lookup (-objectForKey:): nullptr if this is not a dict or has no such key.
	const PList* find(std::string_view key) const noexcept
	{
		const Dict* d = getIf<Dict>();
		if (d == nullptr) return nullptr;
		auto it = d->find(key);
		return it == d->end() ? nullptr : &it->second;
	}
	PList* find(std::string_view key) noexcept
	{
		return const_cast<PList*>(std::as_const(*this).find(key));
	}

	// Array element (-objectAtIndex:, but nullptr instead of a range exception).
	const PList* at(std::size_t index) const noexcept
	{
		const Array* a = getIf<Array>();
		return (a == nullptr || index >= a->size()) ? nullptr : &(*a)[index];
	}

	// -count of an array or dictionary; 0 for anything else (as messaging nil gives 0).
	std::size_t count() const noexcept
	{
		if (const Array* a = getIf<Array>()) return a->size();
		if (const Dict* d = getIf<Dict>()) return d->size();
		return 0;
	}

	// NSNumber's conversions. Only meaningful when isNumber(); anything else gives 0 / false,
	// as messaging nil does. Real -> integer saturates and maps NaN to 0 (a C cast, which is
	// what GNUstep does, is undefined behaviour out of range).
	bool boolValue() const noexcept
	{
		if (const bool* b = getIf<bool>()) return *b;
		if (const Integer* i = getIf<Integer>()) return i->value != 0;
		if (const double* d = getIf<double>()) return *d != 0.0;
		return false;
	}
	std::int64_t int64Value() const noexcept
	{
		if (const bool* b = getIf<bool>()) return *b ? 1 : 0;
		if (const Integer* i = getIf<Integer>()) return i->value;
		if (const double* d = getIf<double>()) return saturate<std::int64_t>(*d);
		return 0;
	}
	std::uint64_t uint64Value() const noexcept
	{
		if (const bool* b = getIf<bool>()) return *b ? 1 : 0;
		if (const Integer* i = getIf<Integer>()) return i->unsignedValue();
		if (const double* d = getIf<double>())
		{
			return *d < 0.0 ? static_cast<std::uint64_t>(saturate<std::int64_t>(*d)) : saturate<std::uint64_t>(*d);
		}
		return 0;
	}
	double doubleValue() const noexcept
	{
		if (const bool* b = getIf<bool>()) return *b ? 1.0 : 0.0;
		if (const Integer* i = getIf<Integer>())
		{
			return i->isUnsigned ? static_cast<double>(i->unsignedValue()) : static_cast<double>(i->value);
		}
		if (const double* d = getIf<double>()) return *d;
		return 0.0;
	}

	friend bool operator==(const PList&, const PList&) = default;

private:
	template <class I>
	static Integer makeInteger(I i) noexcept
	{
		if constexpr (std::is_signed_v<I>) return Integer{static_cast<std::int64_t>(i), false};
		else return Integer{static_cast<std::int64_t>(static_cast<std::uint64_t>(i)), true};
	}

	template <class I>
	static I saturate(double d) noexcept
	{
		if (std::isnan(d)) return 0;
		if (d <= static_cast<double>(std::numeric_limits<I>::min())) return std::numeric_limits<I>::min();
		if (d >= static_cast<double>(std::numeric_limits<I>::max())) return std::numeric_limits<I>::max();
		return static_cast<I>(d);
	}

	// Order matches Type.
	std::variant<std::monostate, bool, Integer, double, std::string, Data, Date, Array, Dict> v_;
};

// NSPropertyListFormat, with GNUstep's numeric values: what a parser found (GNUstep reports
// GNUstep for an old-style plist that uses a <*...> or <[...]> extension).
enum class PListFormat
{
	OpenStep = 1,
	XML = 100,
	Binary = 200,
	GNUstep = 1000,
	GNUstepBinary = 1001,
};

// Why a parse failed. `message` is GNUstep's own text (the error string of
// -[NSPropertyListSerialization propertyListWithData:options:format:error:]), e.g.
// "Parse failed at line 2 (char 17) - unexpected character (wanted '=')"; description() is the
// -[NSError description] that OOPropertyListFromData logged. ADR-0027 item 9.
struct PListError
{
	std::string message;

	std::string description() const
	{
		return "Error Domain=NSPropertyListSerialization Code=0 \"" + message + "\"";
	}
	friend bool operator==(const PListError&, const PListError&) = default;
};

inline const char* typeName(PList::Type t) noexcept
{
	switch (t)
	{
		case PList::Type::Null: return "null";
		case PList::Type::Bool: return "bool";
		case PList::Type::Integer: return "integer";
		case PList::Type::Real: return "real";
		case PList::Type::String: return "string";
		case PList::Type::Data: return "data";
		case PList::Type::Date: return "date";
		case PList::Type::Array: return "array";
		case PList::Type::Dict: return "dict";
	}
	return "?";
}

// --- UTF-16 <-> UTF-8 (NSString's code units <-> PList strings) ------------------------------

// Appends UTF-16 code units as UTF-8. A valid surrogate pair becomes one 4-byte sequence; a lone
// surrogate becomes its own 3-byte sequence (WTF-8), so the conversion is lossless.
inline void appendUtf16AsUtf8(std::string& out, const char16_t* units, std::size_t n)
{
	for (std::size_t i = 0; i < n; ++i)
	{
		std::uint32_t c = units[i];
		if (c >= 0xD800 && c <= 0xDBFF && i + 1 < n && units[i + 1] >= 0xDC00 && units[i + 1] <= 0xDFFF)
		{
			c = 0x10000 + ((c - 0xD800) << 10) + (static_cast<std::uint32_t>(units[i + 1]) - 0xDC00);
			++i;
		}
		if (c < 0x80)
		{
			out += static_cast<char>(c);
		}
		else if (c < 0x800)
		{
			out += static_cast<char>(0xC0 | (c >> 6));
			out += static_cast<char>(0x80 | (c & 0x3F));
		}
		else if (c < 0x10000)
		{
			out += static_cast<char>(0xE0 | (c >> 12));
			out += static_cast<char>(0x80 | ((c >> 6) & 0x3F));
			out += static_cast<char>(0x80 | (c & 0x3F));
		}
		else
		{
			out += static_cast<char>(0xF0 | (c >> 18));
			out += static_cast<char>(0x80 | ((c >> 12) & 0x3F));
			out += static_cast<char>(0x80 | ((c >> 6) & 0x3F));
			out += static_cast<char>(0x80 | (c & 0x3F));
		}
	}
}

inline std::string utf16ToUtf8(std::u16string_view s)
{
	std::string out;
	out.reserve(s.size());
	appendUtf16AsUtf8(out, s.data(), s.size());
	return out;
}

// The inverse of utf16ToUtf8 for the strings a PList holds (UTF-8, or WTF-8 with lone
// surrogates). A byte that does not start a well-formed sequence is taken as Latin-1, one unit.
inline std::u16string utf8ToUtf16(std::string_view s)
{
	std::u16string out;
	out.reserve(s.size());
	const auto* p = reinterpret_cast<const unsigned char*>(s.data());
	const std::size_t n = s.size();
	std::size_t i = 0;
	auto cont = [&](std::size_t k) { return i + k < n && (p[i + k] & 0xC0) == 0x80; };
	while (i < n)
	{
		const unsigned char b = p[i];
		if (b < 0x80)
		{
			out += static_cast<char16_t>(b);
			i += 1;
		}
		else if (b >= 0xC2 && b <= 0xDF && cont(1))
		{
			out += static_cast<char16_t>(((b & 0x1F) << 6) | (p[i + 1] & 0x3F));
			i += 2;
		}
		else if (b >= 0xE0 && b <= 0xEF && cont(1) && cont(2) && !(b == 0xE0 && p[i + 1] < 0xA0))
		{
			out += static_cast<char16_t>(((b & 0x0F) << 12) | ((p[i + 1] & 0x3F) << 6) | (p[i + 2] & 0x3F));
			i += 3;
		}
		else if (b >= 0xF0 && b <= 0xF4 && cont(1) && cont(2) && cont(3) && !(b == 0xF0 && p[i + 1] < 0x90)
				 && !(b == 0xF4 && p[i + 1] > 0x8F))
		{
			const std::uint32_t c = ((b & 0x07u) << 18) | ((p[i + 1] & 0x3Fu) << 12) | ((p[i + 2] & 0x3Fu) << 6)
									| (p[i + 3] & 0x3Fu);
			out += static_cast<char16_t>(0xD800 + ((c - 0x10000) >> 10));
			out += static_cast<char16_t>(0xDC00 + ((c - 0x10000) & 0x3FF));
			i += 4;
		}
		else
		{
			out += static_cast<char16_t>(b);
			i += 1;
		}
	}
	return out;
}

} // namespace oo

#endif // OOFND_PLIST_HPP
