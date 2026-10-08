/*

OOJSShip+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, amendments oo-ppc, oo-luhd and oo-9ht.139): the sends of the
Ship binding's converted natives to classes that are still Objective-C, one per function. See
OOJSShip+ObjCBridge.h.

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

#import "OOJSShip+ObjCBridge.h"


// MARK: The player (slice 1, bead oo-18mg2)

OOWeaponFacingSet OOJSShipPlayerAvailableFacings(PlayerEntity *player)	{ return [player availableFacings]; }
OOPlayerFleeingStatus OOJSShipPlayerFleeingStatus(PlayerEntity *player)	{ return [player fleeingStatus]; }
