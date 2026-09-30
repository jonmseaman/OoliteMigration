/*

OOJSFunction+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056, bead oo-3smy): the Objective-C OOJSFunction, a facade over the
C++ cxx::OOJSFunction (OOJSFunction.h), for the callers that are not converted yet: ShipEntityAI,
which makes one with alloc/-initWithName:... and caches it, and OORegExpMatcher (converted, in
namespace cxx), which names it ::OOJSFunction and keeps its messages until this facade is
deleted (amendment oo-rmd7 item 3). Its interface is the one OOJSFunction.h declared before the
conversion, copied exactly (same selectors and types; the ivar is the C++ object). Imported as
the last line of OOJSFunction.h; do not import it directly.

	a caller that is                       holds / passes                  crosses with
	-------------------------------------  ------------------------------  -------------------------
	still Objective-C                      OOJSFunction *                  nothing: messages as before
	converted (C++)                        oo::Ref<cxx::OOJSFunction>
	  handing a function to Objective-C                                     oo::ToObjC(function)
	  taking one from Objective-C                                           oo::ToCxx(objcFunction)

The initialisers make the C++ object and record the facade as its one peer (oo::ObjCPeers);
oo::ToObjC gives that live facade, or a new one. Never add to this file; converted code does not
message the facade. Deleted by its deletion bead once ShipEntityAI and OORegExpMatcher hold the
C++ object.


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

#ifndef OOJSFUNCTION_OBJCBRIDGE_H
#define OOJSFUNCTION_OBJCBRIDGE_H

#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"


@interface OOJSFunction: OOObject
{
@private
	oo::Ref<cxx::OOJSFunction>	_cxxFunction;
}

- (id) initWithFunction:(ooscript::Function)function context:(ooscript::Context)context;
- (id) initWithName:(const std::optional<std::string> &)name
			  scope:(ooscript::Object)scope		// may be NULL, in which case global object is used.
			   code:(const std::optional<std::string> &)code		// full JS code for function, including function declaration.
	  argumentCount:(NSUInteger)argCount
	  argumentNames:(const char **)argNames
		   fileName:(const std::optional<std::string> &)fileName
		 lineNumber:(NSUInteger)lineNumber
			context:(ooscript::Context)context;	// may be NULL. If not null, must be in a request.

- (std::optional<std::string>) cxx_name;	// nullopt: anonymous (bead oo-3rb.289.7)
- (ooscript::Function) function;
- (ooscript::Value) functionValue;

// Raw evaluation. Context may not be NULL and must be in a request.
- (BOOL) evaluateWithContext:(ooscript::Context)context
					   scope:(ooscript::Object)jsThis
						argc:(unsigned)argc
						argv:(ooscript::Value *)argv
					  result:(ooscript::Value *)result;

// Object-wrapper evaluation, converting the result to a boolean.
- (BOOL) evaluatePredicateWithContext:(ooscript::Context)context
								scope:(id)jsThis
							arguments:(const std::vector<oo::ObjCRef<id>> &)arguments;

@end


namespace oo {

// A function's Objective-C facade: its live one, else a new one; autoreleased. nil for null.
::OOJSFunction *ToObjC(cxx::OOJSFunction *function);
inline ::OOJSFunction *ToObjC(const Ref<cxx::OOJSFunction> &function)  { return ToObjC(function.get()); }

// The C++ function behind a facade, borrowed (the facade retains it); null for nil.
cxx::OOJSFunction *ToCxx(::OOJSFunction *function);

}	// namespace oo

#endif	// OOJSFUNCTION_OBJCBRIDGE_H
