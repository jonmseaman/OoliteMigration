/*

OOJSPlayerShip+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, amendments oo-ppc, oo-ykoy and oo-9ht.139): the PlayerShip
binding's category on PlayerEntity, whose methods the engine and the player send, as one-line
forwarders to the free functions in OOJSPlayerShip.mm, and the sends of the binding's converted
natives to classes that are still Objective-C, one per function. See OOJSPlayerShip+ObjCBridge.h.

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

#import "OOJSPlayerShip.h"
#import "OOJSPlayerShip+ObjCBridge.h"
#import "OOJavaScriptEngine.h"
#import "EntityOOJavaScriptExtensions.h"
#import "PlayerEntityContracts.h"
#import "PlayerEntityControls.h"
#import "PlayerEntityScriptMethods.h"
#import "GuiDisplayGen.h"


@implementation PlayerEntity (OOJavaScriptExtensions)

- (std::optional<std::string>) cxx_oo_jsClassName
{
	return ::OOJSPlayerShipJSClassName();
}


- (void) setJSSelf:(ooscript::Object)val context:(ooscript::Context)context
{
	::OOJSPlayerShipSetJSSelf(self, val, context);
}


- (void) javaScriptEngineWillReset:(const oo::Notification &)notification
{
	::OOJSPlayerShipJavaScriptEngineWillReset(self, notification);
}

@end


// The engine and the player as InitOOJSPlayerShip() and the category's bodies reach them.
OOJavaScriptEngine *OOJSPlayerShipSharedEngine()	{ return [OOJavaScriptEngine sharedEngine]; }
PlayerEntity *OOJSPlayerShipSharedPlayer()	{ return [PlayerEntity sharedPlayer]; }
id OOJSPlayerShipPlayerWeakRetain(PlayerEntity *player)	{ return [player weakRetain]; }

// [OONull null] (PlayerShipGetProperty(): an inactive MFD).
id OOJSPlayerShipNull()	{ return [OONull null]; }

// The player, as PlayerShipGetProperty() reads it.
NSUInteger OOJSPlayerShipPlayerActiveMissile(PlayerEntity *player)	{ return [player activeMissile]; }
float OOJSPlayerShipPlayerFuelLeakRate(PlayerEntity *player)	{ return [player fuelLeakRate]; }
bool OOJSPlayerShipPlayerIsDocked(PlayerEntity *player)	{ return [player isDocked]; }
StationEntity *OOJSPlayerShipPlayerDockedStation(PlayerEntity *player)	{ return [player dockedStation]; }
std::optional<std::string> OOJSPlayerShipPlayerSpecialCargo(PlayerEntity *player)	{ return [player cxx_specialCargo]; }
HeadUpDisplay *OOJSPlayerShipPlayerHud(PlayerEntity *player)	{ return [player hud]; }
OOGalacticHyperspaceBehaviour OOJSPlayerShipPlayerGalacticHyperspaceBehaviour(PlayerEntity *player)	{ return [player galacticHyperspaceBehaviour]; }
NSPoint OOJSPlayerShipPlayerGalacticHyperspaceFixedCoords(PlayerEntity *player)	{ return [player galacticHyperspaceFixedCoords]; }
std::optional<std::string> OOJSPlayerShipPlayerFastEquipmentA(PlayerEntity *player)	{ return [player cxx_fastEquipmentA]; }
std::optional<std::string> OOJSPlayerShipPlayerFastEquipmentB(PlayerEntity *player)	{ return [player cxx_fastEquipmentB]; }
std::string OOJSPlayerShipPlayerCurrentPrimedEquipment(PlayerEntity *player)	{ return [player cxx_currentPrimedEquipment]; }
GLfloat OOJSPlayerShipPlayerForwardShieldLevel(PlayerEntity *player)	{ return [player forwardShieldLevel]; }
GLfloat OOJSPlayerShipPlayerAftShieldLevel(PlayerEntity *player)	{ return [player aftShieldLevel]; }
float OOJSPlayerShipPlayerMaxForwardShieldLevel(PlayerEntity *player)	{ return [player maxForwardShieldLevel]; }
float OOJSPlayerShipPlayerMaxAftShieldLevel(PlayerEntity *player)	{ return [player maxAftShieldLevel]; }
float OOJSPlayerShipPlayerForwardShieldRechargeRate(PlayerEntity *player)	{ return [player forwardShieldRechargeRate]; }
float OOJSPlayerShipPlayerAftShieldRechargeRate(PlayerEntity *player)	{ return [player aftShieldRechargeRate]; }
std::vector<std::optional<std::string>> OOJSPlayerShipPlayerMultiFunctionDisplayList(PlayerEntity *player)	{ return [player cxx_multiFunctionDisplayList]; }
bool OOJSPlayerShipPlayerDialIdentEngaged(PlayerEntity *player)	{ return [player dialIdentEngaged]; }
OOLongRangeChartMode OOJSPlayerShipPlayerLongRangeChartMode(PlayerEntity *player)	{ return [player longRangeChartMode]; }
NSPoint OOJSPlayerShipPlayerGalaxyCoordinates(PlayerEntity *player)	{ return [player galaxy_coordinates]; }
NSPoint OOJSPlayerShipPlayerCursorCoordinates(PlayerEntity *player)	{ return [player cursor_coordinates]; }
OOSystemID OOJSPlayerShipPlayerTargetSystemID(PlayerEntity *player)	{ return [player targetSystemID]; }
OOSystemID OOJSPlayerShipPlayerNextHopTargetSystemID(PlayerEntity *player)	{ return [player nextHopTargetSystemID]; }
OOSystemID OOJSPlayerShipPlayerInfoSystemID(PlayerEntity *player)	{ return [player infoSystemID]; }
OOSystemID OOJSPlayerShipPlayerPreviousSystemID(PlayerEntity *player)	{ return [player previousSystemID]; }
OORouteType OOJSPlayerShipPlayerANAMode(PlayerEntity *player)	{ return [player ANAMode]; }
bool OOJSPlayerShipPlayerScoopOverride(PlayerEntity *player)	{ return [player scoopOverride]; }
bool OOJSPlayerShipPlayerInjectorsEngaged(PlayerEntity *player)	{ return [player injectorsEngaged]; }
bool OOJSPlayerShipPlayerMassLockable(PlayerEntity *player)	{ return [player massLockable]; }
bool OOJSPlayerShipPlayerHyperspeedEngaged(PlayerEntity *player)	{ return [player hyperspeedEngaged]; }
Entity *OOJSPlayerShipPlayerCompassTarget(PlayerEntity *player)	{ return [player compassTarget]; }
OOCompassMode OOJSPlayerShipPlayerCompassMode(PlayerEntity *player)	{ return [player compassMode]; }
bool OOJSPlayerShipPlayerWeaponsOnline(PlayerEntity *player)	{ return [player weaponsOnline]; }
Vector OOJSPlayerShipPlayerViewpointOffsetAft(PlayerEntity *player)	{ return [player viewpointOffsetAft]; }
Vector OOJSPlayerShipPlayerViewpointOffsetForward(PlayerEntity *player)	{ return [player viewpointOffsetForward]; }
Vector OOJSPlayerShipPlayerViewpointOffsetPort(PlayerEntity *player)	{ return [player viewpointOffsetPort]; }
Vector OOJSPlayerShipPlayerViewpointOffsetStarboard(PlayerEntity *player)	{ return [player viewpointOffsetStarboard]; }
OOWeaponFacing OOJSPlayerShipPlayerCurrentWeaponFacing(PlayerEntity *player)	{ return [player currentWeaponFacing]; }
OOEquipmentType *OOJSPlayerShipPlayerWeaponTypeForFacing(PlayerEntity *player, OOWeaponFacing facing, bool strict)	{ return [player weaponTypeForFacing:facing strict:strict]; }
oo::PList OOJSPlayerShipPlayerCommanderDataDictionary(PlayerEntity *player)	{ return [player cxx_commanderDataDictionary]; }
int OOJSPlayerShipPlayerTradeInFactor(PlayerEntity *player)	{ return [player tradeInFactor]; }
double OOJSPlayerShipPlayerRenovationCosts(PlayerEntity *player)	{ return [player renovationCosts]; }
double OOJSPlayerShipPlayerRenovationFactor(PlayerEntity *player)	{ return [player renovationFactor]; }
GLfloat OOJSPlayerShipPlayerFlightPitch(PlayerEntity *player)	{ return [player flightPitch]; }
GLfloat OOJSPlayerShipPlayerFlightRoll(PlayerEntity *player)	{ return [player flightRoll]; }
GLfloat OOJSPlayerShipPlayerFlightYaw(PlayerEntity *player)	{ return [player flightYaw]; }

// The universe and its message GUI, as PlayerShipGetProperty() reads them.
OOViewID OOJSPlayerShipUniverseViewDirection()	{ return [UNIVERSE viewDirection]; }
OOCreditsQuantity OOJSPlayerShipUniverseTradeInValueForCommanderDictionary(const oo::PList &cmdrDict)	{ return [UNIVERSE cxx_tradeInValueForCommanderDictionary:cmdrDict]; }
OOColor *OOJSPlayerShipUniverseMessageGUITextColor()	{ return [[UNIVERSE messageGUI] textColor]; }
OOColor *OOJSPlayerShipUniverseMessageGUITextCommsColor()	{ return [[UNIVERSE messageGUI] textCommsColor]; }

// The player's passengers, parcels and contracts (the contract methods and ValidateContracts()).
NSUInteger OOJSPlayerShipPlayerPassengerCount(PlayerEntity *player)	{ return [player passengerCount]; }
NSUInteger OOJSPlayerShipPlayerPassengerCapacity(PlayerEntity *player)	{ return [player passengerCapacity]; }
NSUInteger OOJSPlayerShipPlayerParcelCount(PlayerEntity *player)	{ return [player parcelCount]; }
bool OOJSPlayerShipPlayerAddPassenger(PlayerEntity *player, const std::string &name, unsigned start, unsigned destination, double eta, double fee, double advance, unsigned risk)	{ return [player cxx_addPassenger:name start:start destination:destination eta:eta fee:fee advance:advance risk:risk]; }
bool OOJSPlayerShipPlayerRemovePassenger(PlayerEntity *player, const std::string &name)	{ return [player cxx_removePassenger:name]; }
bool OOJSPlayerShipPlayerAddParcel(PlayerEntity *player, const std::string &name, unsigned start, unsigned destination, double eta, double fee, double premium, unsigned risk)	{ return [player cxx_addParcel:name start:start destination:destination eta:eta fee:fee premium:premium risk:risk]; }
bool OOJSPlayerShipPlayerRemoveParcel(PlayerEntity *player, const std::string &name)	{ return [player cxx_removeParcel:name]; }
bool OOJSPlayerShipPlayerAwardContract(PlayerEntity *player, unsigned qty, const std::string &commodity, unsigned start, unsigned destination, double eta, double fee, double premium)	{ return [player cxx_awardContract:qty commodity:commodity start:start destination:destination eta:eta fee:fee premium:premium]; }
bool OOJSPlayerShipPlayerRemoveContract(PlayerEntity *player, const std::string &commodity, unsigned destination)	{ return [player cxx_removeContract:commodity destination:destination]; }
double OOJSPlayerShipPlayerClockTime(PlayerEntity *player)	{ return [player clockTime]; }
