/*

ProxyPlayerEntity+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056, amendments oo-64ako and oo-amwj): the Objective-C
ProxyPlayerEntity, the facade over the C++ cxx::ProxyPlayerEntity (ProxyPlayerEntity.h). Its
interface is the one ProxyPlayerEntity.h declared, copied exactly, with the category Entity
(ProxyPlayer), which the header declared after it; every method forwards to the C++ part. It has
one ivar, _cxxProxyPlayer: the root's _cxxEntity, typed, borrowed (the root owns the part), set by
the initialiser. Its initialiser makes the proxy's adapter over cxx::ProxyPlayerEntity
(oo::ObjCShipEntity<cxx::ProxyPlayerEntity>, ShipEntity+ObjCAdapter.h). Imported as the last line
of ProxyPlayerEntity.h; do not import it directly. Deleted by its deletion bead once the universe
and the player make the proxy in C++ and the shader bindings no longer message it.

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

#ifndef PROXYPLAYERENTITY_OBJCBRIDGE_H
#define PROXYPLAYERENTITY_OBJCBRIDGE_H


@interface ProxyPlayerEntity: ShipEntity
{
@public
	cxx::ProxyPlayerEntity	*_cxxProxyPlayer;		// _cxxEntity, typed; borrowed, set by the initialiser
}

- (void) copyValuesFromPlayer:(PlayerEntity *)player;


// Default: 0
- (float) fuelLeakRate;
- (void) setFuelLeakRate:(float)value;

// Default: NO
- (BOOL) massLocked;
- (void) setMassLocked:(BOOL)value;

// Default: NO
- (BOOL) atHyperspeed;
- (void) setAtHyperspeed:(BOOL)value;

// Default: 1
- (GLfloat) dialForwardShield;
- (void) setDialForwardShield:(GLfloat)value;

// Default: 1
- (GLfloat) dialAftShield;
- (void) setDialAftShield:(GLfloat)value;

// Default: MISSILE_STATUS_SAFE
- (OOMissileStatus) dialMissileStatus;
- (void) setDialMissileStatus:(OOMissileStatus)value;

// Default: SCOOP_STATUS_NOT_INSTALLED or SCOOP_STATUS_OKAY depending on equipment.
- (OOFuelScoopStatus) dialFuelScoopStatus;
- (void) setDialFuelScoopStatus:(OOFuelScoopStatus)value;

// Default: COMPASS_MODE_BASIC or COMPASS_MODE_PLANET depending on equipment.
- (OOCompassMode) compassMode;
- (void) setCompassMode:(OOCompassMode)value;

// Default: NO
- (BOOL) dialIdentEngaged;
- (void) setDialIdentEngaged:(BOOL)value;

// Default: ALERT_CONDITION_DOCKED
- (OOAlertCondition) alertCondition;
- (void) setAlertCondition:(OOAlertCondition)condition;

// Default: 0
- (NSUInteger) trumbleCount;
- (void) setTrumbleCount:(NSUInteger)value;

- (void) setTradeInFactor:(int)tif;
- (int) tradeInFactor;

@end


@interface Entity (ProxyPlayer)

// True for PlayerEntity or ProxyPlayerEntity.
- (BOOL) isPlayerLikeShip;

@end


namespace oo {

// The root's crossings, typed (amendment oo-up4b item 3).
inline cxx::ProxyPlayerEntity *ToCxx(::ProxyPlayerEntity *entity)
{
	return static_cast<cxx::ProxyPlayerEntity *>(ToCxx(static_cast<::Entity *>(entity)));
}

inline ::ProxyPlayerEntity *ToObjC(cxx::ProxyPlayerEntity *entity)
{
	return (::ProxyPlayerEntity *)ToObjC(static_cast<cxx::Entity *>(entity));
}

}	// namespace oo

#endif	// PROXYPLAYERENTITY_OBJCBRIDGE_H
