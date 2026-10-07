/*

OOJSShip+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056, amendments oo-ppc, oo-luhd and oo-9ht.139; beads oo-18mg2 and
the later slices of docs/phases/3-slices/OOJSShip.md): the sends of the Ship binding's converted
natives to classes that are still Objective-C (the player, the universe, ...), one function per
send, named after the file and the selector, the body the send verbatim. The ship itself is
reached as cxx::ShipEntity, and the converted classes it hands out (AI, OORoleSet, OOShipGroup,
OOColor, OONativeVector) through oo::ToCxx/oo::ToObjC. OOJSShip.mm has no class of its own and
the ship's JavaScript glue is EntityOOJavaScriptExtensions.mm's, so there is no facade here.
Imported by OOJSShip.mm only.

Never add to this file except a send of that kind. Each function goes with its class's conversion
(PlayerEntity, Universe, ...); the file is deleted by its deletion bead once none is left.

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

#ifndef OOJSSHIP_OBJCBRIDGE_H
#define OOJSSHIP_OBJCBRIDGE_H

#import "PlayerEntity.h"


// A player's ship, as ShipGetProperty() reads it.
OOWeaponFacingSet OOJSShipPlayerAvailableFacings(PlayerEntity *player);
OOPlayerFleeingStatus OOJSShipPlayerFleeingStatus(PlayerEntity *player);

#endif	// OOJSSHIP_OBJCBRIDGE_H
