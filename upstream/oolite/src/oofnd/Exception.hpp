/*	oofnd/Exception.hpp
	oo::Exception: the game's exception as a C++ type (bead oo-rskgl.1, ADR-0056 amendments
	oo-rskgl and oo-rskgl.1). It replaces the Objective-C OOException as the thing
	OORaiseException() throws.

	    OOException                                   oofnd
	    --------------------------------------------  ----------------------------------------------
	    [OOException raise:N format:F, ...]            OORaiseException(N, F, ...)  (unchanged)
	    [OOException exceptionWithName:N reason:R]     oo::Exception(N, R)
	    @catch (OOException *e)                        catch (const oo::Exception &e)
	    [e name], [e reason]                           e.name(), e.reason()  (const char *, UTF-8)

	The name and reason are copied; a null one becomes "", as -initWithName:reason: did. It is
	deliberately NOT a std::exception: a handler for std::exception never caught an OOException,
	so it must not catch this one either.

	Header-only, C++20.
*/

#ifndef OOFND_EXCEPTION_HPP
#define OOFND_EXCEPTION_HPP

// Objective-C++ callers see OOCocoa.h's `#define true 1` / `#define false 0`; suspend them for the
// standard headers (as oofnd/Data.hpp does, proposed ADR-0028).
#pragma push_macro("true")
#pragma push_macro("false")
#undef true
#undef false

#include <string>

namespace oo {

class Exception
{
public:
	Exception(const char *name, const char *reason)
		: _name(name != nullptr ? name : ""), _reason(reason != nullptr ? reason : "")  {}

	// UTF-8, owned by the exception: valid while it is alive.
	const char *name() const noexcept  { return _name.c_str(); }
	const char *reason() const noexcept  { return _reason.c_str(); }

private:
	std::string		_name;
	std::string		_reason;
};

}	// namespace oo

#pragma pop_macro("false")
#pragma pop_macro("true")

#endif	// OOFND_EXCEPTION_HPP
