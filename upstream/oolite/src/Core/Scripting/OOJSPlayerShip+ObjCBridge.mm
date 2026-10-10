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
#import "PlayerEntitySound.h"
#import "StationEntity.h"


// The engine and the player as InitOOJSPlayerShip() and the category's bodies reach them.
OOJavaScriptEngine *OOJSPlayerShipSharedEngine()	{ return [OOJavaScriptEngine sharedEngine]; }
PlayerEntity *OOJSPlayerShipSharedPlayer()	{ return PlayerEntity::sharedPlayer(); }
id OOJSPlayerShipPlayerWeakRetain(PlayerEntity *player)	{ return [oo::ToObjC(player) weakRetain]; }

// [OONull null] (PlayerShipGetProperty(): an inactive MFD).
id OOJSPlayerShipNull()	{ return [OONull null]; }

// The player, as PlayerShipGetProperty() reads it.
NSUInteger OOJSPlayerShipPlayerActiveMissile(PlayerEntity *player)	{ return (player != nullptr ? player->getActiveMissile() : 0); }
float OOJSPlayerShipPlayerFuelLeakRate(PlayerEntity *player)	{ return (player != nullptr ? player->fuelLeakRate() : 0.0f); }
bool OOJSPlayerShipPlayerIsDocked(PlayerEntity *player)	{ return (player != nullptr ? player->isDocked() : false); }
StationEntity *OOJSPlayerShipPlayerDockedStation(PlayerEntity *player)	{ return (player != nullptr ? player->dockedStation() : (StationEntity *)nullptr); }
std::optional<std::string> OOJSPlayerShipPlayerSpecialCargo(PlayerEntity *player)	{ return (player != nullptr ? player->getSpecialCargo() : std::optional<std::string>()); }
HeadUpDisplay *OOJSPlayerShipPlayerHud(PlayerEntity *player)	{ return (player != nullptr ? player->getHud() : (HeadUpDisplay *)nullptr); }
OOGalacticHyperspaceBehaviour OOJSPlayerShipPlayerGalacticHyperspaceBehaviour(PlayerEntity *player)	{ return (player != nullptr ? player->getGalacticHyperspaceBehaviour() : OOGalacticHyperspaceBehaviour{}); }
NSPoint OOJSPlayerShipPlayerGalacticHyperspaceFixedCoords(PlayerEntity *player)	{ return (player != nullptr ? player->getGalacticHyperspaceFixedCoords() : NSPoint{}); }
std::optional<std::string> OOJSPlayerShipPlayerFastEquipmentA(PlayerEntity *player)	{ return (player != nullptr ? player->fastEquipmentA() : std::optional<std::string>()); }
std::optional<std::string> OOJSPlayerShipPlayerFastEquipmentB(PlayerEntity *player)	{ return (player != nullptr ? player->fastEquipmentB() : std::optional<std::string>()); }
std::string OOJSPlayerShipPlayerCurrentPrimedEquipment(PlayerEntity *player)	{ return (player != nullptr ? player->currentPrimedEquipment() : std::string()); }
GLfloat OOJSPlayerShipPlayerForwardShieldLevel(PlayerEntity *player)	{ return (player != nullptr ? player->forwardShieldLevel() : 0.0f); }
GLfloat OOJSPlayerShipPlayerAftShieldLevel(PlayerEntity *player)	{ return (player != nullptr ? player->aftShieldLevel() : 0.0f); }
float OOJSPlayerShipPlayerMaxForwardShieldLevel(PlayerEntity *player)	{ return (player != nullptr ? player->maxForwardShieldLevel() : 0.0f); }
float OOJSPlayerShipPlayerMaxAftShieldLevel(PlayerEntity *player)	{ return (player != nullptr ? player->maxAftShieldLevel() : 0.0f); }
float OOJSPlayerShipPlayerForwardShieldRechargeRate(PlayerEntity *player)	{ return (player != nullptr ? player->forwardShieldRechargeRate() : 0.0f); }
float OOJSPlayerShipPlayerAftShieldRechargeRate(PlayerEntity *player)	{ return (player != nullptr ? player->aftShieldRechargeRate() : 0.0f); }
std::vector<std::optional<std::string>> OOJSPlayerShipPlayerMultiFunctionDisplayList(PlayerEntity *player)	{ return (player != nullptr ? player->multiFunctionDisplayList() : std::vector<std::optional<std::string>>()); }
bool OOJSPlayerShipPlayerDialIdentEngaged(PlayerEntity *player)	{ return (player != nullptr ? player->dialIdentEngaged() : false); }
OOLongRangeChartMode OOJSPlayerShipPlayerLongRangeChartMode(PlayerEntity *player)	{ return (player != nullptr ? player->getLongRangeChartMode() : OOLongRangeChartMode{}); }
NSPoint OOJSPlayerShipPlayerGalaxyCoordinates(PlayerEntity *player)	{ return (player != nullptr ? player->getGalaxy_coordinates() : NSPoint{}); }
NSPoint OOJSPlayerShipPlayerCursorCoordinates(PlayerEntity *player)	{ return (player != nullptr ? player->getCursor_coordinates() : NSPoint{}); }
OOSystemID OOJSPlayerShipPlayerTargetSystemID(PlayerEntity *player)	{ return (player != nullptr ? player->targetSystemID() : 0); }
OOSystemID OOJSPlayerShipPlayerNextHopTargetSystemID(PlayerEntity *player)	{ return (player != nullptr ? player->nextHopTargetSystemID() : 0); }
OOSystemID OOJSPlayerShipPlayerInfoSystemID(PlayerEntity *player)	{ return (player != nullptr ? player->infoSystemID() : 0); }
OOSystemID OOJSPlayerShipPlayerPreviousSystemID(PlayerEntity *player)	{ return (player != nullptr ? player->previousSystemID() : 0); }
OORouteType OOJSPlayerShipPlayerANAMode(PlayerEntity *player)	{ return (player != nullptr ? player->ANAMode() : OORouteType{}); }
bool OOJSPlayerShipPlayerScoopOverride(PlayerEntity *player)	{ return (player != nullptr ? player->getScoopOverride() : false); }
bool OOJSPlayerShipPlayerInjectorsEngaged(PlayerEntity *player)	{ return (player != nullptr ? player->injectorsEngaged() : false); }
bool OOJSPlayerShipPlayerMassLockable(PlayerEntity *player)	{ return (player != nullptr ? player->getMassLockable() : false); }
bool OOJSPlayerShipPlayerHyperspeedEngaged(PlayerEntity *player)	{ return (player != nullptr ? player->hyperspeedEngaged() : false); }
Entity *OOJSPlayerShipPlayerCompassTarget(PlayerEntity *player)	{ return (player != nullptr ? player->getCompassTarget() : (Entity *)nullptr); }
OOCompassMode OOJSPlayerShipPlayerCompassMode(PlayerEntity *player)	{ return (player != nullptr ? player->getCompassMode() : OOCompassMode{}); }
bool OOJSPlayerShipPlayerWeaponsOnline(PlayerEntity *player)	{ return (player != nullptr ? player->weaponsOnline() : false); }
Vector OOJSPlayerShipPlayerViewpointOffsetAft(PlayerEntity *player)	{ return (player != nullptr ? player->viewpointOffsetAft() : Vector{}); }
Vector OOJSPlayerShipPlayerViewpointOffsetForward(PlayerEntity *player)	{ return (player != nullptr ? player->viewpointOffsetForward() : Vector{}); }
Vector OOJSPlayerShipPlayerViewpointOffsetPort(PlayerEntity *player)	{ return (player != nullptr ? player->viewpointOffsetPort() : Vector{}); }
Vector OOJSPlayerShipPlayerViewpointOffsetStarboard(PlayerEntity *player)	{ return (player != nullptr ? player->viewpointOffsetStarboard() : Vector{}); }
OOWeaponFacing OOJSPlayerShipPlayerCurrentWeaponFacing(PlayerEntity *player)	{ return (player != nullptr ? player->getCurrentWeaponFacing() : OOWeaponFacing{}); }
OOEquipmentType *OOJSPlayerShipPlayerWeaponTypeForFacing(PlayerEntity *player, OOWeaponFacing facing, bool strict)	{ return (player != nullptr ? player->weaponTypeForFacing(facing, strict) : (OOEquipmentType *)nullptr); }
oo::PList OOJSPlayerShipPlayerCommanderDataDictionary(PlayerEntity *player)	{ return (player != nullptr ? player->commanderDataDictionary() : oo::PList()); }
int OOJSPlayerShipPlayerTradeInFactor(PlayerEntity *player)	{ return (player != nullptr ? player->tradeInFactor() : int{}); }
double OOJSPlayerShipPlayerRenovationCosts(PlayerEntity *player)	{ return (player != nullptr ? player->renovationCosts() : 0.0); }
double OOJSPlayerShipPlayerRenovationFactor(PlayerEntity *player)	{ return (player != nullptr ? player->renovationFactor() : 0.0); }
GLfloat OOJSPlayerShipPlayerFlightPitch(PlayerEntity *player)	{ return (player != nullptr ? player->getFlightPitch() : 0.0f); }
GLfloat OOJSPlayerShipPlayerFlightRoll(PlayerEntity *player)	{ return (player != nullptr ? player->getFlightRoll() : 0.0f); }
GLfloat OOJSPlayerShipPlayerFlightYaw(PlayerEntity *player)	{ return (player != nullptr ? player->getFlightYaw() : 0.0f); }

// The universe and its message GUI, as PlayerShipGetProperty() reads them.
OOViewID OOJSPlayerShipUniverseViewDirection()	{ return [UNIVERSE viewDirection]; }
OOCreditsQuantity OOJSPlayerShipUniverseTradeInValueForCommanderDictionary(const oo::PList &cmdrDict)	{ return [UNIVERSE cxx_tradeInValueForCommanderDictionary:cmdrDict]; }
OOColor *OOJSPlayerShipUniverseMessageGUITextColor()	{ return [UNIVERSE messageGUI]->getTextColor(); }
OOColor *OOJSPlayerShipUniverseMessageGUITextCommsColor()	{ return [UNIVERSE messageGUI]->getTextCommsColor(); }

// The player's passengers, parcels and contracts (the contract methods and ValidateContracts()).
NSUInteger OOJSPlayerShipPlayerPassengerCount(PlayerEntity *player)	{ return (player != nullptr ? player->passengerCount() : 0); }
NSUInteger OOJSPlayerShipPlayerPassengerCapacity(PlayerEntity *player)	{ return (player != nullptr ? player->passengerCapacity() : 0); }
NSUInteger OOJSPlayerShipPlayerParcelCount(PlayerEntity *player)	{ return (player != nullptr ? player->parcelCount() : 0); }
bool OOJSPlayerShipPlayerAddPassenger(PlayerEntity *player, const std::string &name, unsigned start, unsigned destination, double eta, double fee, double advance, unsigned risk)	{ return (player != nullptr ? player->addPassenger(name, start, destination, eta, fee, advance, risk) : false); }
bool OOJSPlayerShipPlayerRemovePassenger(PlayerEntity *player, const std::string &name)	{ return (player != nullptr ? player->removePassenger(name) : false); }
bool OOJSPlayerShipPlayerAddParcel(PlayerEntity *player, const std::string &name, unsigned start, unsigned destination, double eta, double fee, double premium, unsigned risk)	{ return (player != nullptr ? player->addParcel(name, start, destination, eta, fee, premium, risk) : false); }
bool OOJSPlayerShipPlayerRemoveParcel(PlayerEntity *player, const std::string &name)	{ return (player != nullptr ? player->removeParcel(name) : false); }
bool OOJSPlayerShipPlayerAwardContract(PlayerEntity *player, unsigned qty, const std::string &commodity, unsigned start, unsigned destination, double eta, double fee, double premium)	{ return (player != nullptr ? player->awardContract(qty, commodity, start, destination, eta, fee, premium) : false); }
bool OOJSPlayerShipPlayerRemoveContract(PlayerEntity *player, const std::string &commodity, unsigned destination)	{ return (player != nullptr ? player->removeContract(commodity, destination) : false); }
double OOJSPlayerShipPlayerClockTime(PlayerEntity *player)	{ return (player != nullptr ? player->clockTime() : 0.0); }


// The player, the universe and the message GUI as the property setter, launch, cargo, autopilot, docking and pylon methods reach them (slice 2).
void OOJSPlayerShipPlayerSetFuelLeakRate(PlayerEntity *player, float value)	{ if (player != nullptr)  player->setFuelLeakRate(value); }
void OOJSPlayerShipPlayerSetMassLockable(PlayerEntity *player, bool newValue)	{ if (player != nullptr)  player->setMassLockable(newValue); }
void OOJSPlayerShipPlayerSetLongRangeChartMode(PlayerEntity *player, OOLongRangeChartMode mode)	{ if (player != nullptr)  player->setLongRangeChartMode(mode); }
void OOJSPlayerShipPlayerDoScriptEvent(PlayerEntity *player, ooscript::PropertyId message, const std::vector<oo::PList> &arguments)	{ if (player != nullptr)  player->doScriptEvent(message, arguments); }
void OOJSPlayerShipPlayerSetCompassMode(PlayerEntity *player, OOCompassMode value)	{ if (player != nullptr)  player->setCompassMode(value); }
void OOJSPlayerShipPlayerValidateCompassTarget(PlayerEntity *player)	{ if (player != nullptr)  player->validateCompassTarget(); }
void OOJSPlayerShipPlayerSetNextCompassMode(PlayerEntity *player)	{ if (player != nullptr)  player->setNextCompassMode(); }
bool OOJSPlayerShipPlayerHasEquipmentItemProviding(PlayerEntity *player, const std::string &equipmentType)	{ return (player != nullptr ? player->hasEquipmentItemProviding(equipmentType) : false); }
void OOJSPlayerShipPlayerSetGalacticHyperspaceBehaviour(PlayerEntity *player, OOGalacticHyperspaceBehaviour galacticHyperspaceBehaviour)	{ if (player != nullptr)  player->setGalacticHyperspaceBehaviour(galacticHyperspaceBehaviour); }
void OOJSPlayerShipPlayerSetGalacticHyperspaceFixedCoords(PlayerEntity *player, NSPoint point)	{ if (player != nullptr)  player->setGalacticHyperspaceFixedCoords(point); }
void OOJSPlayerShipPlayerSetFastEquipmentA(PlayerEntity *player, const std::optional<std::string> &eqKey)	{ if (player != nullptr)  player->setFastEquipmentA(eqKey); }
void OOJSPlayerShipPlayerSetFastEquipmentB(PlayerEntity *player, const std::optional<std::string> &eqKey)	{ if (player != nullptr)  player->setFastEquipmentB(eqKey); }
bool OOJSPlayerShipPlayerSetPrimedEquipment(PlayerEntity *player, const std::string &eqKey, bool showMsg)	{ return (player != nullptr ? player->setPrimedEquipment(eqKey, showMsg) : false); }
void OOJSPlayerShipPlayerDecreaseFlightPitch(PlayerEntity *player, double delta)	{ if (player != nullptr)  player->decrease_flight_pitch(delta); }
void OOJSPlayerShipPlayerDecreaseFlightRoll(PlayerEntity *player, double delta)	{ if (player != nullptr)  player->decrease_flight_roll(delta); }
void OOJSPlayerShipPlayerDecreaseFlightYaw(PlayerEntity *player, double delta)	{ if (player != nullptr)  player->decrease_flight_yaw(delta); }
void OOJSPlayerShipPlayerSetForwardShieldLevel(PlayerEntity *player, GLfloat level)	{ if (player != nullptr)  player->setForwardShieldLevel(level); }
void OOJSPlayerShipPlayerSetAftShieldLevel(PlayerEntity *player, GLfloat level)	{ if (player != nullptr)  player->setAftShieldLevel(level); }
void OOJSPlayerShipPlayerSetMaxForwardShieldLevel(PlayerEntity *player, float newValue)	{ if (player != nullptr)  player->setMaxForwardShieldLevel(newValue); }
void OOJSPlayerShipPlayerSetMaxAftShieldLevel(PlayerEntity *player, float newValue)	{ if (player != nullptr)  player->setMaxAftShieldLevel(newValue); }
void OOJSPlayerShipPlayerSetForwardShieldRechargeRate(PlayerEntity *player, float newValue)	{ if (player != nullptr)  player->setForwardShieldRechargeRate(newValue); }
void OOJSPlayerShipPlayerSetAftShieldRechargeRate(PlayerEntity *player, float newValue)	{ if (player != nullptr)  player->setAftShieldRechargeRate(newValue); }
void OOJSPlayerShipPlayerSetScoopOverride(PlayerEntity *player, bool newValue)	{ if (player != nullptr)  player->setScoopOverride(newValue); }
bool OOJSPlayerShipPlayerSwitchHudTo(PlayerEntity *player, const std::string &hudFileName)	{ return (player != nullptr ? player->switchHudTo(hudFileName) : false); }
void OOJSPlayerShipPlayerResetHud(PlayerEntity *player)	{ if (player != nullptr)  player->resetHud(); }
void OOJSPlayerShipPlayerAdjustTradeInFactorBy(PlayerEntity *player, int value)	{ if (player != nullptr)  player->adjustTradeInFactorBy(value); }
bool OOJSPlayerShipPlayerSetWeaponMount(PlayerEntity *player, OOWeaponFacing facing, const std::string &eqKey, const std::optional<std::string> &context)	{ return (player != nullptr ? player->setWeaponMount(facing, eqKey, context) : false); }
OOEntityStatus OOJSPlayerShipPlayerStatus(PlayerEntity *player)	{ return (player != nullptr ? player->status() : OOEntityStatus{}); }
void OOJSPlayerShipPlayerSetTargetSystemID(PlayerEntity *player, OOSystemID sid)	{ if (player != nullptr)  player->setTargetSystemID(sid); }
void OOJSPlayerShipPlayerSetInfoSystemID(PlayerEntity *player, OOSystemID sid, bool moveChart)	{ if (player != nullptr)  player->setInfoSystemID(sid, moveChart); }
void OOJSPlayerShipUniverseMessageGUISetTextColor(OOColor *color)	{ [UNIVERSE messageGUI]->setTextColor(color); }
void OOJSPlayerShipUniverseMessageGUISetTextCommsColor(OOColor *color)	{ [UNIVERSE messageGUI]->setTextCommsColor(color); }
void OOJSPlayerShipPlayerLaunchFromStation(PlayerEntity *player)	{ if (player != nullptr)  player->launchFromStation(); }
void OOJSPlayerShipPlayerRemoveAllCargo(PlayerEntity *player)	{ if (player != nullptr)  player->removeAllCargo(); }
void OOJSPlayerShipPlayerUseSpecialCargo(PlayerEntity *player, const std::string &descriptionString)	{ if (player != nullptr)  player->useSpecialCargo(descriptionString); }
Class OOJSPlayerShipShipEntityClass()	{ return [ShipEntity class]; }
bool OOJSPlayerShipPlayerEngageAutopilotToStation(PlayerEntity *player, StationEntity *stationForDocking)	{ return (player != nullptr ? player->engageAutopilotToStation(stationForDocking) : false); }
void OOJSPlayerShipPlayerDisengageAutopilot(PlayerEntity *player)	{ if (player != nullptr)  player->disengageAutopilot(); }
void OOJSPlayerShipPlayerRequestDockingClearance(PlayerEntity *player, StationEntity *stationForDocking)	{ if (player != nullptr)  player->requestDockingClearance(stationForDocking); }
void OOJSPlayerShipPlayerCancelDockingRequest(PlayerEntity *player, StationEntity *stationForDocking)	{ if (player != nullptr)  player->cancelDockingRequest(stationForDocking); }
bool OOJSPlayerShipPlayerAssignToActivePylon(PlayerEntity *player, const std::string &identifierKey)	{ return (player != nullptr ? player->assignToActivePylon(identifierKey) : false); }


// The views, the hyperspace countdowns, the MFDs, primed equipment and the HUD dials (slice 3).
void OOJSPlayerShipPlayerSetCustomViewDataFromDictionary(PlayerEntity *player, const oo::PList &viewDict, bool withScaling)	{ if (player != nullptr)  player->setCustomViewDataFromDictionary(viewDict, withScaling); }
void OOJSPlayerShipPlayerNoteSwitchToView(PlayerEntity *player, OOViewID toView, OOViewID fromView)	{ if (player != nullptr)  player->noteSwitchToView(toView, fromView); }
void OOJSPlayerShipPlayerResetCustomView(PlayerEntity *player)	{ if (player != nullptr)  player->resetCustomView(); }
void OOJSPlayerShipPlayerResetScannerZoom(PlayerEntity *player)	{ if (player != nullptr)  player->resetScannerZoom(); }
bool OOJSPlayerShipPlayerTakeInternalDamage(PlayerEntity *player)	{ return (player != nullptr ? player->takeInternalDamage() : false); }
bool OOJSPlayerShipPlayerHasHyperspaceMotor(PlayerEntity *player)	{ return (player != nullptr ? player->hasHyperspaceMotor() : false); }
void OOJSPlayerShipPlayerSetStatus(PlayerEntity *player, OOEntityStatus stat)	{ if (player != nullptr)  player->setStatus(stat); }
bool OOJSPlayerShipPlayerWitchJumpChecklist(PlayerEntity *player, bool isGalacticJump)	{ return (player != nullptr ? player->witchJumpChecklist(isGalacticJump) : false); }
void OOJSPlayerShipPlayerBeginWitchspaceCountdown(PlayerEntity *player, int spinTime)	{ if (player != nullptr)  player->beginWitchspaceCountdown(spinTime); }
void OOJSPlayerShipPlayerCancelWitchspaceCountdown(PlayerEntity *player)	{ if (player != nullptr)  player->cancelWitchspaceCountdown(); }
void OOJSPlayerShipPlayerSetJumpType(PlayerEntity *player, bool isGalacticJump)	{ if (player != nullptr)  player->setJumpType(isGalacticJump); }
void OOJSPlayerShipPlayerSetWitchspaceCountdown(PlayerEntity *player, int spinTime)	{ if (player != nullptr)  player->setWitchspaceCountdown(spinTime); }
void OOJSPlayerShipPlayerPlayGalacticHyperspace(PlayerEntity *player)	{ if (player != nullptr)  player->playGalacticHyperspace(); }
bool OOJSPlayerShipPlayerSetMultiFunctionDisplay(PlayerEntity *player, NSUInteger index, const std::optional<std::string> &key)	{ return (player != nullptr ? player->setMultiFunctionDisplay(index, key) : false); }
void OOJSPlayerShipPlayerSetMultiFunctionText(PlayerEntity *player, const std::optional<std::string> &text, const std::optional<std::string> &key)	{ if (player != nullptr)  player->setMultiFunctionText(text, key); }
void OOJSPlayerShipPlayerSetDialCustom(PlayerEntity *player, const oo::PList &value, const std::string &dialKey)	{ if (player != nullptr)  player->setDialCustom(value, dialKey); }
void OOJSPlayerShipUniverseAddMessage(const std::optional<std::string> &text, OOTimeDelta count)	{ [UNIVERSE cxx_addMessage:text forCount:count]; }
GuiDisplayGen *OOJSPlayerShipUniverseGui()	{ return [UNIVERSE gui]; }
std::optional<std::string> OOJSPlayerShipGuiReflowTextForMFD(GuiDisplayGen *gui, const std::optional<std::string> &input)	{ return gui->reflowTextForMFD(input); }
