/*

ProxyPlayerEntity+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, amendments oo-64ako and oo-amwj): the Objective-C
ProxyPlayerEntity facade (see ProxyPlayerEntity+ObjCBridge.h). Its initialiser needs the
Objective-C object as self (amendment oo-bj8 item 6), and makes the proxy's C++ part by overriding
the ship's -initShipPart (amendment oo-64ako item 2); every other method forwards to
cxx::ProxyPlayerEntity. The file's categories on Entity and PlayerEntity, which answer
-isPlayerLikeShip, are here too (amendment oo-bj8 item 12). Deleted with
ProxyPlayerEntity+ObjCBridge.h.

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

#import "ProxyPlayerEntity.h"
#import "ShipEntity+ObjCAdapter.h"
#include "oofnd/objc/OOAssert.h"


@implementation ProxyPlayerEntity

- (id)cxx_initWithKey:(const std::string &)key definition:(const oo::PList &)dict
{
	self = [super cxx_initWithKey:key definition:dict];
	if (self != nil)
	{
		_cxxProxyPlayer->initProxyDefaults();
	}
	
	return self;
}


/*	What [super init] did in ShipEntity's initialisers, with the proxy's adapter: a proxy's C++ part
	is a cxx::ProxyPlayerEntity (amendment oo-64ako), with the ship's adapter lines.
*/
- (id) initShipPart
{
	// -init sent again to an initialised ship keeps its C++ part (the root's -initWithCxxEntity:).
	if (_cxxEntity != nullptr)  return [self initWithCxxEntity:_cxxEntity.get()];
	return [self initWithCxxEntity:oo::makeRef<oo::ObjCShipEntity<cxx::ProxyPlayerEntity>>(self).get()];
}


// The root's designated initialiser, which also sets the typed alias of the part it stores.
- (id) initWithCxxEntity:(cxx::Entity *)entity
{
	self = [super initWithCxxEntity:entity];
	if (EXPECT_NOT(self == nil))  return nil;

	_cxxProxyPlayer = dynamic_cast<cxx::ProxyPlayerEntity *>(_cxxEntity.get());
	OOCParameterAssert(_cxxProxyPlayer != nullptr);
	return self;
}


- (void) copyValuesFromPlayer:(PlayerEntity *)player	{ _cxxProxyPlayer->copyValuesFromPlayer(player); }
- (BOOL) isPlayerLikeShip	{ return _cxxProxyPlayer->isPlayerLikeShip(); }
- (float) fuelLeakRate	{ return _cxxProxyPlayer->fuelLeakRate(); }
- (void) setFuelLeakRate:(float)value	{ _cxxProxyPlayer->setFuelLeakRate(value); }
- (BOOL) massLocked	{ return _cxxProxyPlayer->massLocked(); }
- (void) setMassLocked:(BOOL)value	{ _cxxProxyPlayer->setMassLocked(value); }
- (BOOL) atHyperspeed	{ return _cxxProxyPlayer->atHyperspeed(); }
- (void) setAtHyperspeed:(BOOL)value	{ _cxxProxyPlayer->setAtHyperspeed(value); }
- (GLfloat) dialForwardShield	{ return _cxxProxyPlayer->dialForwardShield(); }
- (void) setDialForwardShield:(GLfloat)value	{ _cxxProxyPlayer->setDialForwardShield(value); }
- (GLfloat) dialAftShield	{ return _cxxProxyPlayer->dialAftShield(); }
- (void) setDialAftShield:(GLfloat)value	{ _cxxProxyPlayer->setDialAftShield(value); }
- (OOMissileStatus) dialMissileStatus	{ return _cxxProxyPlayer->dialMissileStatus(); }
- (void) setDialMissileStatus:(OOMissileStatus)value	{ _cxxProxyPlayer->setDialMissileStatus(value); }
- (OOFuelScoopStatus) dialFuelScoopStatus	{ return _cxxProxyPlayer->dialFuelScoopStatus(); }
- (void) setDialFuelScoopStatus:(OOFuelScoopStatus)value	{ _cxxProxyPlayer->setDialFuelScoopStatus(value); }
- (OOCompassMode) compassMode	{ return _cxxProxyPlayer->compassMode(); }
- (void) setCompassMode:(OOCompassMode)value	{ _cxxProxyPlayer->setCompassMode(value); }
- (BOOL) dialIdentEngaged	{ return _cxxProxyPlayer->dialIdentEngaged(); }
- (void) setDialIdentEngaged:(BOOL)value	{ _cxxProxyPlayer->setDialIdentEngaged(value); }
- (OOAlertCondition) alertCondition	{ return _cxxProxyPlayer->cxx::ProxyPlayerEntity::alertCondition(); }
- (void) setAlertCondition:(OOAlertCondition)value	{ _cxxProxyPlayer->setAlertCondition(value); }
- (NSUInteger) trumbleCount	{ return _cxxProxyPlayer->trumbleCount(); }
- (void) setTrumbleCount:(NSUInteger)value	{ _cxxProxyPlayer->setTrumbleCount(value); }
- (void) setTradeInFactor:(int)tif	{ _cxxProxyPlayer->setTradeInFactor(tif); }
- (int) tradeInFactor	{ return _cxxProxyPlayer->tradeInFactor(); }

@end


@implementation Entity (ProxyPlayer)

- (BOOL) isPlayerLikeShip
{
	return NO;
}

@end


@implementation PlayerEntity (ProxyPlayer)

- (BOOL) isPlayerLikeShip
{
	return YES;
}

@end
