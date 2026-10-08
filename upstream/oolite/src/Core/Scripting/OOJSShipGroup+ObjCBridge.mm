/*

OOJSShipGroup+ObjCBridge.mm

The Objective-C left over from OOJSShipGroup.mm (bead oo-n64m; proposed ADR-0056 amendments oo-ppc,
oo-ykoy and oo-bwrq): OOShipGroup (OOJavaScriptExtensions), the category through which the engine
asks a group's façade for its JS object by selector, and tells it that object is gone. Its methods
stay methods of the façade, each forwarding in one line to the C++ group's member in
OOJSShipGroup.mm (the JS object lives in the group, bead oo-6symp.1). Deleted with the façade
(oo-9ht.94).

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

#import "OOJSShipGroup.h"
#import "OOShipGroup.h"


@implementation OOShipGroup (OOJavaScriptExtensions)

- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context
{
	return oo::ToCxx(self)->jsValueInContext(context);
}


- (void) oo_clearJSSelf:(ooscript::Object)selfVal
{
	oo::ToCxx(self)->clearJSSelf(selfVal);
}

@end
