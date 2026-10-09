/*

OOHUDBeaconCodeIcon+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, bead oo-2p1ug; moved out of HeadUpDisplay+ObjCBridge.mm verbatim
by bead oo-mwd58): the beacon code icon's facade and OOPolygonSprite's OOHUDBeaconIcon category.
See OOHUDBeaconCodeIcon+ObjCBridge.h. The drawing is in HeadUpDisplay.mm.

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

#import "HeadUpDisplay.h"
#import "OOPolygonSprite.h"

#include "oofnd/objc/OOObjCPeer.h"


// --- The beacon icons (bead oo-2p1ug) ---------------------------------------------------------

namespace {

// Never destroyed: a facade may be released while the process exits.
oo::ObjCPeers &IconPeers()
{
	static oo::ObjCPeers *peers = new oo::ObjCPeers;
	return *peers;
}

}	// namespace


@interface OOHUDBeaconCodeIcon (OOObjCBridgePrivate)

- (id) initWithCxxIcon:(cxx::OOHUDBeaconCodeIcon *)icon;

@end


@implementation OOHUDBeaconCodeIcon

OOHUDBeaconCodeIcon *oo::ToObjC(cxx::OOHUDBeaconCodeIcon *icon)
{
	return IconPeers().peerFor(icon, [icon] { return [[OOHUDBeaconCodeIcon alloc] initWithCxxIcon:icon]; });
}


cxx::OOHUDBeaconCodeIcon *oo::ToCxx(OOHUDBeaconCodeIcon *icon)
{
	if (icon == nil)  return nullptr;
	return icon->_cxxIcon.get();
}


- (id) initWithText:(const std::string &)text
{
	self = [super init];
	if (self == nil)  return nil;

	_cxxIcon = oo::makeRef<cxx::OOHUDBeaconCodeIcon>(text);
	@autoreleasepool
	{
		IconPeers().peerFor(_cxxIcon.get(), [self] { return [self retain]; });
	}
	return self;
}


- (id) initWithCxxIcon:(cxx::OOHUDBeaconCodeIcon *)icon
{
	self = [super init];
	if (self != nil)  _cxxIcon = oo::Ref<cxx::OOHUDBeaconCodeIcon>(icon);
	return self;
}


- (void) dealloc
{
	IconPeers().forget(_cxxIcon.get());
	[super dealloc];
}


- (void) oo_drawHUDBeaconIconAt:(NSPoint)where size:(NSSize)size alpha:(GLfloat)alpha z:(GLfloat)z	{ _cxxIcon->drawHUDBeaconIconAt(where, size, alpha, z); }

@end


// Declared in OOPolygonSprite+ObjCBridge.h; the drawing is OOPolygonSpriteDrawHUDBeaconIcon() in HeadUpDisplay.mm.
@implementation OOPolygonSprite (OOHUDBeaconIcon)

- (void) oo_drawHUDBeaconIconAt:(NSPoint)where size:(NSSize)size alpha:(GLfloat)alpha z:(GLfloat)z	{ OOPolygonSpriteDrawHUDBeaconIcon(oo::ToCxx(self), where, size, alpha, z); }

@end
