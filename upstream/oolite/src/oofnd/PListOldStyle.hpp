/*	oofnd/PListOldStyle.hpp
	The old-style (OpenStep / GNUstep text) property-list scanner: a port of GNUstep base
	1.31.1's parsePlItem() and helpers (Source/NSPropertyList.m), which is what
	+[NSPropertyListSerialization propertyListFromData:...] runs - and so what
	OOPropertyListFromData runs - on any data that does not start with "<?" (XML) or look binary.

	    oo::Expected<oo::PList, oo::PListError> r = oo::parseOldStylePList(bytes);
	    if (!r) OOLog(..., "%s", r.error().description().c_str());

	It reproduces GNUstep quirk-for-quirk (ADR-0027), including the odd parts:

	  * Whitespace is the bytes 0x08-0x0D and space (GNUstep's fixed table: backspace counts).
	    "//" and "/" "*" comments are whitespace; an unterminated one is an error, except after the
	    top-level item, where running off the end is how a plist is supposed to end.
	  * An unquoted string is a run of bytes outside GNUstep's `quotables` table (letters, digits
	    and !#$%&*+-./:?@^_|~); bytes >= 0x80 end it. It may be EMPTY: "=" parses as "" and then
	    fails with "extra data after parsed string".
	  * A quoted string is UTF-8 (strictly: overlong forms and encoded surrogates are errors).
	    Escapes: \a \b \t \r \n \v \f; \ followed by 1-3 octal digits; \U or \u followed by 0-4
	    hex digits (so "\u4x" is U+0004 then 'x', and "\u" alone is U+0000); any other escaped
	    character is itself. An octal or hex escape still open at the closing quote is DROPPED
	    ("a\u12" is "a"). Lone surrogates survive (as WTF-8, see PList.hpp).
	  * Line numbers in error messages count newlines, and a newline that terminates an octal or
	    hex escape is counted twice (GNUstep rescans it); "char" is the byte offset + 1.
	  * After the top-level item only whitespace and comments may follow.

	Error messages are GNUstep's, formatted as its propertyListWithData formats them:
	"Parse failed at line L (char C) - <reason>".
*/

#ifndef OOFND_PLISTOLDSTYLE_HPP
#define OOFND_PLISTOLDSTYLE_HPP

#include "oofnd/Expected.hpp"
#include "oofnd/PList.hpp"

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <optional>
#include <string>
#include <string_view>
#include <utility>

namespace oo {

namespace plist_detail {

// GNUstep's `quotables` and `whitespace` bitmaps (NSPropertyList.m), bit (c % 8) of byte c / 8.
inline constexpr unsigned char kQuotables[32] = {
	0xff, 0xff, 0xff, 0xff, 0x85, 0x13, 0x00, 0x78, 0x00, 0x00, 0x00, 0x38, 0x01, 0x00, 0x00, 0xa8,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
};
inline constexpr unsigned char kWhitespace[32] = {
	0x00, 0x3f, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};

constexpr bool isQuotable(unsigned char c) noexcept { return (kQuotables[c / 8] & (1u << (c % 8))) != 0; }
constexpr bool isPListSpace(unsigned char c) noexcept { return (kWhitespace[c / 8] & (1u << (c % 8))) != 0; }

// isxdigit()/char2num() in the C locale, total over all code units.
constexpr bool isHexDigit(std::uint32_t c) noexcept
{
	return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}
constexpr unsigned hexValue(std::uint32_t c) noexcept
{
	return c <= '9' ? c - '0' : (c >= 'a' ? c - 'a' + 10 : c - 'A' + 10);
}

// Strict UTF-8 -> UTF-16 (GSToUnicode's NSUTF8StringEncoding): false on any malformed sequence,
// overlong form, encoded surrogate or code point above U+10FFFF.
inline bool decodeUtf8Strict(const unsigned char* p, std::size_t n, std::u16string& out)
{
	std::size_t i = 0;
	while (i < n)
	{
		const unsigned char b = p[i];
		std::uint32_t c;
		std::size_t len;
		if (b < 0x80) { c = b; len = 1; }
		else if (b >= 0xC2 && b <= 0xDF) { c = b & 0x1Fu; len = 2; }
		else if (b >= 0xE0 && b <= 0xEF) { c = b & 0x0Fu; len = 3; }
		else if (b >= 0xF0 && b <= 0xF4) { c = b & 0x07u; len = 4; }
		else return false;
		if (i + len > n) return false;
		for (std::size_t k = 1; k < len; ++k)
		{
			if ((p[i + k] & 0xC0) != 0x80) return false;
			c = (c << 6) | (p[i + k] & 0x3Fu);
		}
		if ((len == 3 && c < 0x800) || (len == 4 && (c < 0x10000 || c > 0x10FFFF))) return false;
		if (c >= 0xD800 && c <= 0xDFFF) return false;
		if (c >= 0x10000)
		{
			out += static_cast<char16_t>(0xD800 + ((c - 0x10000) >> 10));
			out += static_cast<char16_t>(0xDC00 + ((c - 0x10000) & 0x3FF));
		}
		else
		{
			out += static_cast<char16_t>(c);
		}
		i += len;
	}
	return true;
}

// GNUstep's `pldata` plus the parse functions that take it.
class OldStyleScanner
{
public:
	explicit OldStyleScanner(std::string_view bytes) noexcept
		: ptr_(reinterpret_cast<const unsigned char*>(bytes.data())), end_(bytes.size())
	{
	}

	// parsePlItem(). nullopt is GNUstep's nil; err_ says whether that was an error.
	std::optional<PList> parseItem()
	{
		const bool start = (pos_ == 0);
		if (!skipSpace()) return std::nullopt;

		std::optional<PList> result;
		switch (ptr_[pos_])
		{
			case '{':
			case '(':
			case '<':
				// Dictionaries, arrays and data are bead oo-6rj.
				err_ = "unexpected character (arrays, dictionaries and data are not parsed yet)";
				return std::nullopt;

			case '"':
				result = parseQuotedString();
				break;

			default:
				result = parseUnquotedString();
				break;
		}
		if (start && result && err_ == nullptr)
		{
			if (skipSpace())
			{
				err_ = "extra data after parsed string";
				result.reset();
			}
			else
			{
				err_ = nullptr;   // reaching the end is expected here
			}
		}
		return result;
	}

	const char* error() const noexcept { return err_; }
	bool usedGNUstepExtensions() const noexcept { return !old_; }

	std::string errorMessage() const
	{
		char buf[64];
		std::snprintf(buf, sizeof buf, "Parse failed at line %u (char %zu) - ", lin_ + 1, pos_ + 1);
		return std::string(buf) + err_;
	}

private:
	// skipSpace(): skips whitespace and comments, counting lines. True if anything is left.
	bool skipSpace()
	{
		unsigned char c;
		while (pos_ < end_)
		{
			c = ptr_[pos_];
			if (!isPListSpace(c))
			{
				if (c == '/' && pos_ < end_ - 1)
				{
					if (ptr_[pos_ + 1] == '/')
					{
						pos_ += 2;
						while (pos_ < end_)
						{
							c = ptr_[pos_];
							if (c == '\n') break;
							pos_++;
						}
						if (pos_ >= end_)
						{
							err_ = "reached end of string in comment";
							return false;
						}
					}
					else if (ptr_[pos_ + 1] == '*')
					{
						pos_ += 2;
						while (pos_ < end_)
						{
							c = ptr_[pos_];
							if (c == '\n')
							{
								lin_++;
							}
							else if (c == '*' && pos_ < end_ - 1 && ptr_[pos_ + 1] == '/')
							{
								pos_++;   // skip past '*'
								break;
							}
							pos_++;
						}
						if (pos_ >= end_)
						{
							err_ = "reached end of string in comment";
							return false;
						}
					}
					else
					{
						return true;
					}
				}
				else
				{
					return true;
				}
			}
			if (c == '\n') lin_++;
			pos_++;
		}
		err_ = "reached end of string";
		return false;
	}

	std::optional<PList> parseQuotedString()
	{
		const std::size_t start = ++pos_;
		unsigned escaped = 0;
		std::size_t shrink = 0;
		bool hex = false;

		// Pass 1, over the bytes: find the closing quote.
		while (pos_ < end_)
		{
			const unsigned char c = ptr_[pos_];
			if (escaped)
			{
				if (escaped == 1 && c >= '0' && c <= '7')
				{
					escaped = 2;
					hex = false;
				}
				else if (escaped == 1 && (c == 'u' || c == 'U'))
				{
					escaped = 2;
					hex = true;
				}
				else if (escaped > 1)
				{
					if (hex && isHexDigit(c))
					{
						shrink++;
						if (++escaped == 6) escaped = 0;
					}
					else if (c >= '0' && c <= '7')
					{
						shrink++;
						if (++escaped == 4) escaped = 0;
					}
					else
					{
						pos_--;   // rescan this character (its newline is counted twice)
						escaped = 0;
					}
				}
				else
				{
					escaped = 0;
				}
			}
			else
			{
				if (c == '\\')
				{
					escaped = 1;
					shrink++;
				}
				else if (c == '"')
				{
					break;
				}
			}
			if (c == '\n') lin_++;
			pos_++;
		}
		if (pos_ >= end_)
		{
			err_ = "reached end of string while parsing quoted string";
			return std::nullopt;
		}

		std::string text;
		if (pos_ - start - shrink != 0)
		{
			std::u16string temp;
			if (!decodeUtf8Strict(ptr_ + start, pos_ - start, temp))
			{
				err_ = "invalid utf8 data while parsing quoted string";
				return std::nullopt;
			}
			// Pass 2, over the UTF-16 units: apply the escapes.
			std::u16string chars;
			chars.reserve(temp.size());
			char16_t pending = 0;
			escaped = 0;
			hex = false;
			for (std::size_t j = 0; j < temp.size(); j++)
			{
				const char16_t c = temp[j];
				if (escaped)
				{
					if (escaped == 1 && c >= '0' && c <= '7')
					{
						pending = static_cast<char16_t>(c - '0');
						hex = false;
						escaped++;
					}
					else if (escaped == 1 && (c == 'u' || c == 'U'))
					{
						pending = 0;
						hex = true;
						escaped++;
					}
					else if (escaped > 1)
					{
						if (hex && isHexDigit(c))
						{
							pending = static_cast<char16_t>((pending << 4) | hexValue(c));
							if (++escaped == 6)
							{
								escaped = 0;
								chars += pending;
							}
						}
						else if (c >= '0' && c <= '7')
						{
							pending = static_cast<char16_t>((pending << 3) | (c - '0'));
							if (++escaped == 4)
							{
								escaped = 0;
								chars += pending;
							}
						}
						else
						{
							escaped = 0;
							j--;   // rescan
							chars += pending;
						}
					}
					else
					{
						escaped = 0;
						switch (c)
						{
							case 'a': chars += u'\a'; break;
							case 'b': chars += u'\b'; break;
							case 't': chars += u'\t'; break;
							case 'r': chars += u'\r'; break;
							case 'n': chars += u'\n'; break;
							case 'v': chars += u'\v'; break;
							case 'f': chars += u'\f'; break;
							default: chars += c; break;
						}
					}
				}
				else if (c == '\\')
				{
					escaped = 1;
				}
				else
				{
					chars += c;
				}
			}
			// An escape still open here is dropped, as GNUstep's length = k drops it.
			appendUtf16AsUtf8(text, chars.data(), chars.size());
		}
		pos_++;
		return PList(std::move(text));
	}

	std::optional<PList> parseUnquotedString()
	{
		const std::size_t start = pos_;
		while (pos_ < end_ && !isQuotable(ptr_[pos_])) pos_++;
		// Every byte here is < 0x80 (the rest are quotable), so this is ASCII.
		return PList(std::string(reinterpret_cast<const char*>(ptr_ + start), pos_ - start));
	}

	const unsigned char* ptr_;
	std::size_t end_;
	std::size_t pos_ = 0;
	unsigned lin_ = 0;
	const char* err_ = nullptr;
	bool old_ = true;    // no GNUstep <*...> / <[...]> extension seen
};

} // namespace plist_detail

// The OpenStep-format branch of -[NSPropertyListSerialization propertyListWithData:...].
// An error has GNUstep's message; a parse that GNUstep finishes with nil and no error yields a
// null PList. *format, if given, receives OpenStep, or GNUstep if an extension was used.
inline Expected<PList, PListError> parseOldStylePList(std::string_view bytes, PListFormat* format = nullptr)
{
	plist_detail::OldStyleScanner scanner(bytes);
	std::optional<PList> result = scanner.parseItem();
	if (format != nullptr) *format = scanner.usedGNUstepExtensions() ? PListFormat::GNUstep : PListFormat::OpenStep;
	if (scanner.error() != nullptr) return Unexpected(PListError{scanner.errorMessage()});
	return result ? std::move(*result) : PList();
}

} // namespace oo

#endif // OOFND_PLISTOLDSTYLE_HPP
