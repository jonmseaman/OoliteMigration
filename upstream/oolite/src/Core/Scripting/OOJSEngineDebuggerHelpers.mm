/*

OOJSEngineDebuggerHelpers.mm

JavaScript support for Oolite
Copyright (C) 2007-2013 David Taylor and Jens Ayton.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
MA 02110-1301, USA.

*/


/*
	These functions exist to help debugging JavaScript code. They can be called
	directly from gdb, for example:
	
		call (char *)JSValueToStrDbg(someValue)
	
	The functions are:
	
		const char *JSValueToStrDbg(jsval)
		const char *JSObjectToStrDbg(JSObject *)
		const char *JSStringToStrDbg(JSString *)
		Converts any JS value/object/JSString to a string, using the complete
		process and potentially calling into SpiderMonkey with a secondory
		context and invoking JS toString() methods. This might mess up
		SpiderMonkey internal state in some cases.
		
		const char *JSValueToStrSafeDbg(jsval)
		const char *JSObjectToStrSafeDbg(JSObject *)
		const char *JSStringToStrSafeDbg(JSString *)
		As above, but without calling into SpiderMonkey functions that require
		a context. In particular, as of the FF4b9 version of SpiderMonkey only
		interned strings can be converted, and for objects only the class name
		is provided.
		
		const char *JSIDToStrSafeDbg(jsid)
		Like JSValueToStrSafeDbg() for jsids. (String jsids must always be
		interned, so this is generally sufficient.)
		
		const char *JSValueTypeDbg(jsval)
		Returns the type of the jsval, or the class name if it's an object.
	
	All dynamic strings are autoreleased.
 
	 Another useful function is OOJSDumpStack (results are found in the log):
		
		call OOJSDumpStack(context)
	
	A set of macros can be found in tools/gdb-macros.txt.
	In almost all Oolite functions that deal with JavaScript, there is a single
	JSContext called "context". In SpiderMonkey functions, it's called "cx".
	
	
	In addition to calling them from the debug console, Xcode users might want
	to use them in data formatters (by double-clicking the "Summary" field for
	a variable of the appropriate type). I recommend the following:
	
		jsval:		{JSValueToStrSafeDbg($VAR)}:s
		jsval*:		{JSValueToStrSafeDbg(*$VAR)}:s
		jsid:		{JSIDToStrSafeDbg($VAR)}:s
		JSObject*:	{JSObjectToStrSafeDbg($VAR)}:s
		JSString*:	{JSStringToStrSafeDbg($VAR)}:s
	
	These, and a variety of Oolite type formatters, can be set up using
	Mac-specific/DataFormatters.
*/


#ifndef NDEBUG

#import "OOJavaScriptEngine.h"

#include "ooscript/JSEngine.hpp"

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) per bead oo-4kf, the same way bead oo-sdz
	retargeted OOJSVector.mm (the exemplar for this sweep; see its header comment for the full
	rationale) and bead oo-45g retargeted OOJSQuaternion.mm.

	Only the string-inspection helpers (StringHasBeenInterned / GetStringLength /
	GetInternedStringChars) go through the façade here: every other engine-spelled identifier in
	this file is a jsval/jsid bit-layout macro (JSVAL_IS_*, JSID_IS_*, ...) that already compiles
	as C and is out of the sweep's scope (see OOJSVector.mm's header comment), or the debug-build
	struct-typed-jsval magic-value switch below, which is engine ABI detail with no façade
	equivalent (ooscript/README.md's "Not in the façade" list: the debugger-frame family in this
	same file is called out there for the identical reason). That switch is rewritten to compare
	against the raw numeric values of the engine's magic-value enumeration, in the enumeration's
	declaration order, instead of spelling the enumerators; the strings it returns, and the
	engine build configuration it is compiled under (a debug build using the struct-typed jsval
	representation, and only that configuration), are unchanged.

	The public functions keep external linkage on purpose: they are called by name from gdb and
	Xcode data formatters, per this file's own header comment above, never through a declaration
	in a header that clang-tidy's misc-use-internal-linkage could see.
*/

namespace ooscript { }
using ooscript::String;

// Byte-identical façade <-> jsapi views, local to this call site (JSEngine.hpp: the handle types
// are byte copies of the engine's own pointers; see OOJSVector.mm for the same, non-exported,
// pattern).
namespace {
static inline String  OOJSFSTR(JSString *s)     { return reinterpret_cast<String>(s); }
} // namespace
namespace {
static inline const jschar *OOJSRCHARS(const ooscript::Char16 *s)  { return reinterpret_cast<const jschar*>(s); }
} // namespace
namespace {
// NSString's -stringWithCharacters:length: wants unichar (uint16_t); on this Windows build the
// engine's jschar is wchar_t (both are 16-bit code units, jspubtd.h's WIN32 branch), and
// Objective-C++ does not implicitly convert between distinct pointee types the way Objective-C
// does, so this byte-identical view, local to this call site, makes the two spellings
// interchangeable exactly as OOJSVector.mm's OOJSRVAL/OOJSFVALP pair does for jsval/Value.
static inline const unichar *OOJSRUCHARS(const jschar *s)  { return reinterpret_cast<const unichar*>(s); }
} // namespace


const char *JSValueToStrDbg(jsval val)  // NOLINT(misc-use-internal-linkage): called by name from gdb, see file header.
{
	JSContext *context = OOJSAcquireContext();
	const char *result = [OOStringFromJSValueEvenIfNull(context, val) UTF8String];
	OOJSRelinquishContext(context);
	
	return result;
}


const char *JSObjectToStrDbg(JSObject *obj)  // NOLINT(misc-use-internal-linkage): called by name from gdb, see file header.
{
	if (obj == NULL)  return "null";
	return JSValueToStrDbg(OBJECT_TO_JSVAL(obj));
}


const char *JSStringToStrDbg(JSString *str)  // NOLINT(misc-use-internal-linkage): called by name from gdb, see file header.
{
	if (str == NULL)  return "null";
	return JSValueToStrDbg(STRING_TO_JSVAL(str));
}


const char *JSValueTypeDbg(jsval val)  // NOLINT(misc-use-internal-linkage): called by name from gdb, see file header.
{
	if (JSVAL_IS_INT(val))		return "integer";
	if (JSVAL_IS_DOUBLE(val))	return "double";
	if (JSVAL_IS_STRING(val))	return "string";
	if (JSVAL_IS_BOOLEAN(val))	return "boolean";
	if (JSVAL_IS_NULL(val))		return "null";
	if (JSVAL_IS_VOID(val))	return "void";
#if defined(DEBUG)
	// Only the debug build's struct-typed jsval representation supports this predicate; see
	// this file's header comment above. The cases are the engine's magic-value enumeration in
	// its declaration order: array hole, args hole, native enumerate, no iter value, generator
	// closing, no constant, this poison, arg poison, serialize no node, generic.
	if (JSVAL_IS_MAGIC_IMPL(val))
	{
		switch(val.s.payload.why)
		{
			case 0:		return "magic (array hole)";
			case 1:		return "magic (args hole)";
			case 2:		return "magic (native enumerate)";
			case 3:		return "magic (no iter value)";
			case 4:		return "magic (generator closing)";
			case 5:		return "magic (no constant)";
			case 6:		return "magic (this poison)";
			case 7:		return "magic (arg poison)";
			case 8:		return "magic (serialize no node)";
			case 9:		return "magic (generic)";
		};
		return "magic";
	}
#endif
	if (JSVAL_IS_OBJECT(val))  return OOJSGetClass(NULL, JSVAL_TO_OBJECT(val))->name;	// Fun fact: although a context is required if the engine is built thread-safe, it isn't actually used.
	return "unknown";
}


// Doesn't follow pointers, mess with requests or otherwise poke the SpiderMonkey.
const char *JSValueToStrSafeDbg(jsval val)  // NOLINT(misc-use-internal-linkage): called by name from gdb, see file header.
{
	NSString *formatted = nil;
	
	if (JSVAL_IS_INT(val))			formatted = [NSString stringWithFormat:@"%i", JSVAL_TO_INT(val)];
	else if (JSVAL_IS_DOUBLE(val))	formatted = [NSString stringWithFormat:@"%g", JSVAL_TO_DOUBLE(val)];
	else if (JSVAL_IS_BOOLEAN(val))	formatted = (JSVAL_TO_BOOLEAN(val)) ? @"true" : @"false";
	else if (JSVAL_IS_STRING(val))
	{
		JSString		*string = JSVAL_TO_STRING(val);
		const jschar	*chars = NULL;
		size_t			length = ooscript::getStringLength(OOJSFSTR(string));
		
		if (ooscript::stringHasBeenInterned(nullptr, OOJSFSTR(string)))
		{
			chars = OOJSRCHARS(ooscript::getInternedStringChars(OOJSFSTR(string)));
		}
		// Flat strings can be extracted without a context, but cannot be detected.
		
		if (chars == NULL)  formatted = [NSString stringWithFormat:@"string [%zu chars]", length];
		else  formatted = [NSString stringWithCharacters:OOJSRUCHARS(chars) length:length];
	}
	else if (JSVAL_IS_VOID(val))	return "undefined";
	else							return JSValueTypeDbg(val);
	
	return [formatted UTF8String];
}


const char *JSObjectToStrSafeDbg(JSObject *obj)  // NOLINT(misc-use-internal-linkage): called by name from gdb, see file header.
{
	if (obj == NULL)  return "null";
	return JSValueToStrSafeDbg(OBJECT_TO_JSVAL(obj));
}


const char *JSStringToStrSafeDbg(JSString *str)  // NOLINT(misc-use-internal-linkage): called by name from gdb, see file header.
{
	if (str == NULL)  return "null";
	return JSValueToStrSafeDbg(STRING_TO_JSVAL(str));
}


const char *JSIDToStrSafeDbg(jsid anID)  // NOLINT(misc-use-internal-linkage): called by name from gdb, see file header.
{
	NSString *formatted = nil;
	
	if (JSID_IS_INT(anID))			formatted = [NSString stringWithFormat:@"%i", JSID_TO_INT(anID)];
	else if (JSID_IS_VOID(anID))	return "void";
	else if (JSID_IS_EMPTY(anID))	return "empty";
	else if (JSID_IS_ZERO(anID))	return "0";
	else if (JSID_IS_OBJECT(anID))	return OOJSGetClass(NULL, JSID_TO_OBJECT(anID))->name;
	else if (JSID_IS_DEFAULT_XML_NAMESPACE(anID))  return "default XML namespace";
	else if (JSID_IS_STRING(anID))
	{
		JSString		*string = JSID_TO_STRING(anID);
		const jschar	*chars = NULL;
		size_t			length = ooscript::getStringLength(OOJSFSTR(string));
		
		if (ooscript::stringHasBeenInterned(nullptr, OOJSFSTR(string)))
		{
			chars = OOJSRCHARS(ooscript::getInternedStringChars(OOJSFSTR(string)));
		}
		else
		{
			// Bug; jsid strings must be interned.
			return "*** uninterned string in jsid! ***";
		}
		formatted = [NSString stringWithCharacters:OOJSRUCHARS(chars) length:length];
	}
	else
	{
		formatted = [NSString stringWithFormat:@"unknown <0x%llX>", (long long)JSID_BITS(anID)];
	}
	
	return [formatted UTF8String];
}
#endif
