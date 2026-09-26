/*

OOJSFunction.h

Object encapsulating a runnable JavaScript function.


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


#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"
#include "ooscript/JSEngine.hpp"
#include "oofnd/StdLib.hpp"
#include "oofnd/objc/OOObjCRef.h"
@interface OOJSFunction: OOObject
{
@private
	ooscript::Function _function;
	std::optional<std::string>	_name;	// nullopt for an anonymous function (was nil)
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

- (id) name;	// shared selector (proposed ADR-0043): an Objective-C string, or nil
- (ooscript::Function) function;
- (ooscript::Value) functionValue;

// Raw evaluation. Context may not be NULL and must be in a request.
- (BOOL) evaluateWithContext:(ooscript::Context)context
					   scope:(ooscript::Object)jsThis
						argc:(unsigned)argc
						argv:(ooscript::Value *)argv
					  result:(ooscript::Value *)result;

// Object-wrapper evaluation.
- (id) evaluateWithContext:(ooscript::Context)context
					 scope:(id)jsThis
				 arguments:(const std::vector<oo::ObjCRef<id>> &)arguments;

// As above, but converts result to a boolean.
- (BOOL) evaluatePredicateWithContext:(ooscript::Context)context
								scope:(id)jsThis
							arguments:(const std::vector<oo::ObjCRef<id>> &)arguments;

@end
