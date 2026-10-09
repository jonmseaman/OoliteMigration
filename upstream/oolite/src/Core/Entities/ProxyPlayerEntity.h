/*

ProxyPlayerEntity.h

Ship entity which, in some respects, emulates a PlayerShip. In particular, at
this time it implements the extra shader bindable methods of PlayerShip.

The class is C++ (bead oo-amwj; proposed ADR-0056, amendment oo-amwj): cxx::ProxyPlayerEntity holds
the proxy's dials and their accessors. ProxyPlayerEntity+ObjCBridge.h, imported at the end of this
header, keeps the Objective-C ProxyPlayerEntity as its facade, for the universe and the player,
which make it, and for the shader bindings, which message its dials by selector.

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

#import "PlayerEntity.h"


namespace cxx {

/*	The proxy's state and methods. Its ship part is cxx::ShipEntity's; the facade's initialiser sets
	the proxy's defaults (initProxyDefaults()) once the ship is set up from its definition.
*/
class ProxyPlayerEntity : public ShipEntity
{
public:
	// -cxx_initWithKey:definition:'s body after [super cxx_initWithKey:definition:].
	void initProxyDefaults();

	void copyValuesFromPlayer(::PlayerEntity *player);

	// True for PlayerEntity or ProxyPlayerEntity (the category Entity (ProxyPlayer)).
	bool isPlayerLikeShip();

	// Default: 0
	float fuelLeakRate();
	void setFuelLeakRate(float value);

	// Default: NO
	bool massLocked();
	void setMassLocked(bool value);

	// Default: NO
	bool atHyperspeed();
	void setAtHyperspeed(bool value);

	// Default: 1
	GLfloat dialForwardShield();
	void setDialForwardShield(GLfloat value);

	// Default: 1
	GLfloat dialAftShield();
	void setDialAftShield(GLfloat value);

	// Default: MISSILE_STATUS_SAFE
	OOMissileStatus dialMissileStatus();
	void setDialMissileStatus(OOMissileStatus value);

	// Default: SCOOP_STATUS_NOT_INSTALLED or SCOOP_STATUS_OKAY depending on equipment.
	OOFuelScoopStatus dialFuelScoopStatus();
	void setDialFuelScoopStatus(OOFuelScoopStatus value);

	// Default: COMPASS_MODE_BASIC or COMPASS_MODE_PLANET depending on equipment.
	OOCompassMode compassMode();
	void setCompassMode(OOCompassMode value);

	// Default: NO
	bool dialIdentEngaged();
	void setDialIdentEngaged(bool value);

	// Default: ALERT_CONDITION_DOCKED
	OOAlertCondition alertCondition() override;
	void setAlertCondition(OOAlertCondition value);

	// Default: 0
	NSUInteger trumbleCount();
	void setTrumbleCount(NSUInteger value);

	void setTradeInFactor(int tif);
	int tradeInFactor();

private:
	float					_fuelLeakRate = 0;
	GLfloat					_dialForwardShield = 0;
	GLfloat					_dialAftShield = 0;
	OOMissileStatus			_missileStatus = {};
	OOFuelScoopStatus		_fuelScoopStatus = {};
	OOCompassMode			_compassMode = {};
	OOAlertCondition		_alertCondition = {};
	NSUInteger				_trumbleCount = 0;
	int						_tradeInFactor = 0;
	unsigned				_massLocked: 1 = 0,
							_atHyperspeed: 1 = 0,
							_dialIdentEngaged: 1 = 0;
};

}	// namespace cxx


// Transitional: the Objective-C ProxyPlayerEntity, for its callers and the shader bindings. Deleted,
// with namespace cxx above, by the bridge's deletion bead.
#import "ProxyPlayerEntity+ObjCBridge.h"
