/*

OOJSInterfaceDefinition.h


Oolite
Copyright (C) 2004-2013 Giles C Williams and contributors

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

#import "OOJSScript.h"
#include "ooscript/JSEngine.hpp"
#include "oofnd/StdLib.hpp"
@interface OOJSInterfaceDefinition: OOWeakRefObject
{
@private
	ooscript::Value				_callback;
	ooscript::Object _callbackThis;
	OOJSScript			*_owningScript;

	std::optional<std::string>	_title;		// nullopt until set (was nil)
	std::optional<std::string>	_summary;
	std::optional<std::string>	_category;
}

- (id)title;	// shared selector (proposed ADR-0043): an Objective-C string, or nil
- (void)setTitle:(id)title;	// shared selector (proposed ADR-0043): an Objective-C string, or nil
- (std::optional<std::string>)category;
- (void)setCategory:(const std::string &)category;
- (std::optional<std::string>)summary;
- (void)setSummary:(const std::string &)summary;
- (ooscript::Value)callback;
- (void)setCallback:(ooscript::Value)callback;
- (ooscript::Object)callbackThis;
- (void)setCallbackThis:(ooscript::Object)callbackthis;

- (void)runCallback:(id)key;	// shared selector (proposed ADR-0043): key is an Objective-C string

- (NSComparisonResult)interfaceCompare:(OOJSInterfaceDefinition *)other;

@end

