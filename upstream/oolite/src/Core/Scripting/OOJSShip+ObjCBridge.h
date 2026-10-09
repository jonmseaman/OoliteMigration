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
#import "Universe.h"


// A player's ship, as ShipGetProperty() reads it.
OOWeaponFacingSet OOJSShipPlayerAvailableFacings(PlayerEntity *player);
OOPlayerFleeingStatus OOJSShipPlayerFleeingStatus(PlayerEntity *player);
// ... and as ShipSetProperty() arms it.
bool OOJSShipPlayerSetWeaponMount(PlayerEntity *player, OOWeaponFacing facing, const std::string &eqKey, const std::optional<std::string> &context);

// The player, as ShipSetProperty() reads and tells it (PLAYER).
Entity *OOJSShipPlayerNextBeacon();
void OOJSShipPlayerSetCompassMode(OOCompassMode mode);

// The universe's beacon list, as ShipSetProperty() keeps it (UNIVERSE).
void OOJSShipUniverseClearBeacon(ShipEntity *beacon);
void OOJSShipUniverseSetNextBeacon(ShipEntity *beacon);


// The player (a player's ship, or OOPlayerForScripting()), as the slice 3 natives ask and tell it.
bool OOJSShipPlayerIsDocked(PlayerEntity *player);
void OOJSShipPlayerSetScriptTarget(PlayerEntity *player, ShipEntity *ship);
void OOJSShipPlayerRunUnsanitizedScriptActions(PlayerEntity *player, const oo::PList &actions, bool allowAIMethods, const std::optional<std::string> &contextName, ShipEntity *target);

// The universe's main station, as RemoveOrExplodeShip() checks for it (UNIVERSE).
StationEntity *OOJSShipUniverseStation();
void OOJSShipUniverseUnMagicMainStation();

// The ship's -dumpCargo, sent after delay (ShipDumpCargo(): an NPC's queued canisters).
void OOJSShipScheduleDumpCargo(ShipEntity *ship, OOTimeDelta delay);

// A player's ship, as the equipment natives arm and refit it (slice 4).
bool OOJSShipPlayerMountMissileWithRole(PlayerEntity *player, const std::string &role);
bool OOJSShipPlayerChangePassengerBerths(PlayerEntity *player, int addRemove);
void OOJSShipPlayerAdjustTradeInFactorBy(PlayerEntity *player, int value);

// The universe's stations and commodities (ShipFindNearestStation(), ShipSetCargo()).
std::vector<oo::ObjCRef<StationEntity *>> OOJSShipUniverseStations();
OOCommodities *OOJSShipUniverseCommodities();

// The player's status (ShipEnterWormhole(): only while it enters witchspace) (PLAYER).
OOEntityStatus OOJSShipPlayerStatus();

// The universe's course checks (ShipCheckCourseToDestination(), ShipGetSafeCourseToDestination()).
Entity *OOJSShipUniverseHazardOnRoute(Entity *entity, double distance, HPVector point);
HPVector OOJSShipUniverseSafeVector(Entity *entity, double distance, HPVector point);

// The player's score (ShipThreatAssessment(): a player's skill) (PLAYER).
unsigned OOJSShipPlayerScore();

// The universe's cargo templates and role categories (ShipAdjustCargo(), Ship.roleIsInCategory()).
std::vector<oo::ObjCRef<ShipEntity *>> OOJSShipUniverseContainersOfCommodity(const std::string &commodity, OOCargoQuantity howMany);
bool OOJSShipUniverseRoleIsInCategory(const std::string &role, const std::string &category);

#endif	// OOJSSHIP_OBJCBRIDGE_H
