/*

OOJSSpecialFunctions+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056): the one-line bridge from cxx_JSSpecialFunctionsObjectWrapper()
(OOJSSpecialFunctions.h, plain C++) to the Objective-C OOJSValue that its remaining callers
(OOJavaScriptEngine.mm, OODebugMonitor.mm) hand to Objective-C collections. Deleted when they
convert and take the cxx::OOJSValue directly.


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

#import "OOJavaScriptEngine.h"


extern "C" OOJSValue *JSSpecialFunctionsObjectWrapper(ooscript::Context context);
