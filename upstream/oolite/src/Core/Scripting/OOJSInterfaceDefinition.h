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

#import "OOWeakReference.h"
#include "ooscript/JSEngine.hpp"
#include "oofnd/StdLib.hpp"
@class OOJSScript;	// imported by the .mm, so that a test can stand in for it (ADR-0056 amendment oo-fg7i item 5)

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

- (std::optional<std::string>)cxx_title;	// nullopt: none (bead oo-3rb.290)
- (void)cxx_setTitle:(const std::optional<std::string> &)title;	// bead oo-3rb.290
- (std::optional<std::string>)category;
- (void)setCategory:(const std::string &)category;
- (std::optional<std::string>)summary;
- (void)setSummary:(const std::string &)summary;
- (ooscript::Value)callback;
- (void)setCallback:(ooscript::Value)callback;
- (ooscript::Object)callbackThis;
- (void)setCallbackThis:(ooscript::Object)callbackthis;

- (void)runCallback:(const std::string &)key;

- (OOComparisonResult)interfaceCompare:(OOJSInterfaceDefinition *)other;

@end

