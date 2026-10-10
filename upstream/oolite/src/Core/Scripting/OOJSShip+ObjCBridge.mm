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
#import "OOShipGroup.h"
#import "StationEntity.h"
#import "PlayerEntityLegacyScriptEngine.h"
#import "GameController.h"
#import "PlayerEntityScriptMethods.h"


// MARK: The player (slice 1, bead oo-18mg2)

OOWeaponFacingSet OOJSShipPlayerAvailableFacings(PlayerEntity *player)	{ return (player != nullptr ? player->availableFacings() : OOWeaponFacingSet{}); }
OOPlayerFleeingStatus OOJSShipPlayerFleeingStatus(PlayerEntity *player)	{ return (player != nullptr ? player->fleeingStatus() : OOPlayerFleeingStatus{}); }


// MARK: The player, the universe and the group class (slice 2, bead oo-chjz4)

bool OOJSShipPlayerSetWeaponMount(PlayerEntity *player, OOWeaponFacing facing, const std::string &eqKey, const std::optional<std::string> &context)	{ return (player != nullptr ? player->setWeaponMount(facing, eqKey, context) : false); }
Entity *OOJSShipPlayerNextBeacon()	{ return (PLAYER != nullptr ? (Entity <OOBeaconEntity> *)PLAYER->nextBeacon() : (Entity <OOBeaconEntity> *)nullptr); }
void OOJSShipPlayerSetCompassMode(OOCompassMode mode)	{ if (PLAYER != nullptr)  PLAYER->setCompassMode(mode); }
void OOJSShipUniverseClearBeacon(ShipEntity *beacon)	{ [UNIVERSE clearBeacon:beacon]; }
void OOJSShipUniverseSetNextBeacon(ShipEntity *beacon)	{ [UNIVERSE setNextBeacon:beacon]; }


// MARK: The player, the universe and a deferred send (slice 3, bead oo-08plt)

bool OOJSShipPlayerIsDocked(PlayerEntity *player)	{ return (player != nullptr ? player->isDocked() : false); }
void OOJSShipPlayerSetScriptTarget(PlayerEntity *player, ShipEntity *ship)	{ if (player != nullptr)  player->setScriptTarget(ship); }
void OOJSShipPlayerRunUnsanitizedScriptActions(PlayerEntity *player, const oo::PList &actions, bool allowAIMethods, const std::optional<std::string> &contextName, ShipEntity *target)	{ if (player != nullptr)  player->runUnsanitizedScriptActions(actions, allowAIMethods, contextName, target); }
::ShipEntity *OOJSShipUniverseStation()	{ return oo::ToObjC([UNIVERSE station]); }
void OOJSShipUniverseUnMagicMainStation()	{ [UNIVERSE unMagicMainStation]; }
void OOJSShipScheduleDumpCargo(ShipEntity *ship, OOTimeDelta delay)	{ OOScheduleDeferredCall(ship, @selector(dumpCargo), nil, delay); }


// MARK: The player and the universe (slice 4, bead oo-hqe5l)

bool OOJSShipPlayerMountMissileWithRole(PlayerEntity *player, const std::string &role)	{ return (player != nullptr ? player->mountMissileWithRole(role) : false); }
bool OOJSShipPlayerChangePassengerBerths(PlayerEntity *player, int addRemove)	{ return (player != nullptr ? player->changePassengerBerths(addRemove) : false); }
void OOJSShipPlayerAdjustTradeInFactorBy(PlayerEntity *player, int value)	{ if (player != nullptr)  player->adjustTradeInFactorBy(value); }
std::vector<oo::ObjCRef<::ShipEntity *>> OOJSShipUniverseStations()	{ return [UNIVERSE cxx_stations]; }
OOCommodities *OOJSShipUniverseCommodities()	{ return [UNIVERSE commodities]; }


// MARK: The player and the universe (slice 5, bead oo-qzn25)

OOEntityStatus OOJSShipPlayerStatus()	{ return (PLAYER != nullptr ? PLAYER->status() : OOEntityStatus{}); }
Entity *OOJSShipUniverseHazardOnRoute(Entity *entity, double distance, HPVector point)	{ return [UNIVERSE hazardOnRouteFromEntity:entity toDistance:distance fromPoint:point]; }
HPVector OOJSShipUniverseSafeVector(Entity *entity, double distance, HPVector point)	{ return [UNIVERSE getSafeVectorFromEntity:entity toDistance:distance fromPoint:point]; }


// MARK: The player and the universe (slice 6, bead oo-ljuy1)

unsigned OOJSShipPlayerScore()	{ return (PLAYER != nullptr ? PLAYER->score() : unsigned{}); }
std::vector<oo::ObjCRef<ShipEntity *>> OOJSShipUniverseContainersOfCommodity(const std::string &commodity, OOCargoQuantity howMany)	{ return [UNIVERSE cxx_getContainersOfCommodity:commodity :howMany]; }
bool OOJSShipUniverseRoleIsInCategory(const std::string &role, const std::string &category)	{ return [UNIVERSE cxx_role:role isInCategory:category]; }
