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
#import "PlayerEntityLegacyScriptEngine.h"
#import "GameController.h"
#import "PlayerEntityScriptMethods.h"


// MARK: The player (slice 1, bead oo-18mg2)

OOWeaponFacingSet OOJSShipPlayerAvailableFacings(PlayerEntity *player)	{ return [player availableFacings]; }
OOPlayerFleeingStatus OOJSShipPlayerFleeingStatus(PlayerEntity *player)	{ return [player fleeingStatus]; }


// MARK: The player, the universe and the group class (slice 2, bead oo-chjz4)

bool OOJSShipPlayerSetWeaponMount(PlayerEntity *player, OOWeaponFacing facing, const std::string &eqKey, const std::optional<std::string> &context)	{ return [player cxx_setWeaponMount:facing toWeapon:eqKey inContext:context]; }
Entity *OOJSShipPlayerNextBeacon()	{ return [PLAYER nextBeacon]; }
void OOJSShipPlayerSetCompassMode(OOCompassMode mode)	{ [PLAYER setCompassMode:mode]; }
void OOJSShipUniverseClearBeacon(ShipEntity *beacon)	{ [UNIVERSE clearBeacon:beacon]; }
void OOJSShipUniverseSetNextBeacon(ShipEntity *beacon)	{ [UNIVERSE setNextBeacon:beacon]; }


// MARK: The player, the universe and a deferred send (slice 3, bead oo-08plt)

bool OOJSShipPlayerIsDocked(PlayerEntity *player)	{ return [player isDocked]; }
void OOJSShipPlayerSetScriptTarget(PlayerEntity *player, ShipEntity *ship)	{ [player setScriptTarget:ship]; }
void OOJSShipPlayerRunUnsanitizedScriptActions(PlayerEntity *player, const oo::PList &actions, bool allowAIMethods, const std::optional<std::string> &contextName, ShipEntity *target)	{ [player cxx_runUnsanitizedScriptActions:actions allowingAIMethods:allowAIMethods withContextName:contextName forTarget:target]; }
StationEntity *OOJSShipUniverseStation()	{ return [UNIVERSE station]; }
void OOJSShipUniverseUnMagicMainStation()	{ [UNIVERSE unMagicMainStation]; }
void OOJSShipScheduleDumpCargo(ShipEntity *ship, OOTimeDelta delay)	{ OOScheduleDeferredCall(ship, @selector(dumpCargo), nil, delay); }


// MARK: The player and the universe (slice 4, bead oo-hqe5l)

bool OOJSShipPlayerMountMissileWithRole(PlayerEntity *player, const std::string &role)	{ return [player cxx_mountMissileWithRole:role]; }
bool OOJSShipPlayerChangePassengerBerths(PlayerEntity *player, int addRemove)	{ return [player changePassengerBerths:addRemove]; }
void OOJSShipPlayerAdjustTradeInFactorBy(PlayerEntity *player, int value)	{ [player adjustTradeInFactorBy:value]; }
std::vector<oo::ObjCRef<StationEntity *>> OOJSShipUniverseStations()	{ return [UNIVERSE cxx_stations]; }
OOCommodities *OOJSShipUniverseCommodities()	{ return [UNIVERSE commodities]; }


// MARK: The player and the universe (slice 5, bead oo-qzn25)

OOEntityStatus OOJSShipPlayerStatus()	{ return [PLAYER status]; }
Entity *OOJSShipUniverseHazardOnRoute(Entity *entity, double distance, HPVector point)	{ return [UNIVERSE hazardOnRouteFromEntity:entity toDistance:distance fromPoint:point]; }
HPVector OOJSShipUniverseSafeVector(Entity *entity, double distance, HPVector point)	{ return [UNIVERSE getSafeVectorFromEntity:entity toDistance:distance fromPoint:point]; }


// MARK: The player and the universe (slice 6, bead oo-ljuy1)

unsigned OOJSShipPlayerScore()	{ return [PLAYER score]; }
std::vector<oo::ObjCRef<ShipEntity *>> OOJSShipUniverseContainersOfCommodity(const std::string &commodity, OOCargoQuantity howMany)	{ return [UNIVERSE cxx_getContainersOfCommodity:commodity :howMany]; }
bool OOJSShipUniverseRoleIsInCategory(const std::string &role, const std::string &category)	{ return [UNIVERSE cxx_role:role isInCategory:category]; }
