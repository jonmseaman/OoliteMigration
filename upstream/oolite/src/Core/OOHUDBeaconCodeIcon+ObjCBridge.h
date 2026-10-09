/*

OOHUDBeaconCodeIcon+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056, bead oo-2p1ug; moved out of HeadUpDisplay+ObjCBridge.h verbatim
by bead oo-mwd58, which deleted the HUD's facade): the OOHUDBeaconIcon protocol the entities'
beacon drawables are held by, and the Objective-C facade of cxx::OOHUDBeaconCodeIcon
(HeadUpDisplay.h), which the entities make and hold by that protocol. Imported as the last line of
HeadUpDisplay.h; do not import it directly. Deleted with the protocol, when the entities hold
their beacon drawables as C++ objects.

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

#ifndef OOHUDBEACONCODEICON_OBJCBRIDGE_H
#define OOHUDBEACONCODEICON_OBJCBRIDGE_H

#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"


// Moved verbatim from HeadUpDisplay.h (bead oo-2p1ug, amendment oo-jpd8 item 1): adopted by the
// facades below and by OOPolygonSprite's category, held by the entities' beacon drawables.
/*
	Protocol for things that can be used as HUD compass items. Really ought
	to grow into a general protocol for HUD elements.
*/
@protocol OOHUDBeaconIcon <OOObject>

- (void) oo_drawHUDBeaconIconAt:(NSPoint)where size:(NSSize)size alpha:(GLfloat)alpha z:(GLfloat)z;

@end


/*	The compass icon of a beacon whose code names no icon: the code's first character, drawn as
	text. It replaces the string class's OOHUDBeaconIcon category (bead oo-f9rf) the entities' beacon
	drawables used; the drawing is the category's.
*/
@interface OOHUDBeaconCodeIcon: OOObject <OOHUDBeaconIcon>
{
@private
	oo::Ref<cxx::OOHUDBeaconCodeIcon>	_cxxIcon;
}

- (id) initWithText:(const std::string &)text;

@end


namespace oo {

// The beacon code icon's Objective-C facade: its live one, else a new one; autoreleased. nil for null.
OOHUDBeaconCodeIcon *ToObjC(cxx::OOHUDBeaconCodeIcon *icon);
inline OOHUDBeaconCodeIcon *ToObjC(const Ref<cxx::OOHUDBeaconCodeIcon> &icon)  { return ToObjC(icon.get()); }
cxx::OOHUDBeaconCodeIcon *ToCxx(OOHUDBeaconCodeIcon *icon);

}	// namespace oo

#endif	// OOHUDBEACONCODEICON_OBJCBRIDGE_H
