/*

PlayerEntity+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056, amendments oo-bj8, oo-60fwo and oo-jx5np): the Objective-C
PlayerEntity, the facade over the C++ cxx::PlayerEntity (PlayerEntity.h) while the class converts
slice by slice (docs/phases/3-slices/PlayerEntity.md). It is a subclass of the ship's facade
(ShipEntity+ObjCBridge.h), and the object's identity. Its interface is the one PlayerEntity.h
declared before slice 1, copied exactly; only +sharedPlayer and -deferredInit moved, to the
category that implements them beside -init and -dealloc. Its methods keep their Objective-C bodies
until their slice moves them to cxx::PlayerEntity and leaves a forwarder here. It has one ivar,
_cxxPlayer: the root's _cxxEntity, typed, borrowed (the root owns the part), set by the
initialiser beside the ship's _cxxShip; unconverted code reads the player's members through it by
their old names (_cxxPlayer->hud, player->_cxxPlayer->hud). Its -init makes the player's adapter
over cxx::PlayerEntity (oo::ObjCEntity<cxx::PlayerEntity>). Imported as the last line of
PlayerEntity.h; do not import it directly. Never add to this file. Deleted by its deletion bead
once every slice and the categories are C++.

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

#ifndef PLAYERENTITY_OBJCBRIDGE_H
#define PLAYERENTITY_OBJCBRIDGE_H


@interface PlayerEntity: ShipEntity
{
@public
	cxx::PlayerEntity	*_cxxPlayer;		// _cxxEntity, typed; borrowed, set by the initialiser
}

// Dumb setter; callers are responsible for sanity.

// return keyconfig.plist settings for scripting

 

// loading and saving trumbleCount

/* GILES custom viewpoints */

// custom view points

// Nasty hack to keep background textures around while on equip screens.

// *** World script events.
// In general, script events should be sent through doScriptEvent:..., which
// will forward to the world scripts.

/* Fractional expression of amount of entry inside a planet's atmosphere. 0.0f is out of atmosphere,
   1.0f is fully in and is normally associated with the point of ship destruct due to altitude.
*/

@end


// Slice 2 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice2)

- (void) cxx_setName:(const std::optional<std::string> &)inName;
- (GLfloat) baseMass;
- (void) unloadAllCargoPodsForType:(const std::string &)type toManifest:(OOCommodityMarket *) manifest;
- (void) unloadCargoPodsForType:(const std::string &)type amount:(OOCargoQuantity) quantity;
- (void) unloadCargoPods;
- (void) createCargoPodWithType:(const std::string &)type andAmount:(OOCargoQuantity)amount;
- (void) loadCargoPodsForType:(const std::string &)type fromManifest:(OOCommodityMarket *) manifest;
- (void) loadCargoPodsForType:(const std::string &)type amount:(OOCargoQuantity) quantity;
- (void) loadCargoPods;
- (OOCommodityMarket *) shipCommodityData;
- (OOCreditsQuantity) deciCredits;
- (int) random_factor;
- (void) setRandom_factor:(int)rf;
- (OOGalaxyID) galaxyNumber;
- (NSPoint) galaxy_coordinates;
- (void) setGalaxyCoordinates:(NSPoint)newPosition;
- (NSPoint) cursor_coordinates;
- (NSPoint) chart_centre_coordinates;
- (OOScalar) chart_zoom;
- (OOScalar) custom_chart_zoom;
- (void) setCustomChartZoom:(OOScalar)zoom;
- (NSPoint) custom_chart_centre_coordinates;
- (void) setCustomChartCentre:(NSPoint)coords;
- (NSPoint) adjusted_chart_centre;
- (OORouteType) ANAMode;
- (OOSystemID) systemID;
- (void) setSystemID:(OOSystemID) sid;
- (OOSystemID) previousSystemID;
- (void) setPreviousSystemID:(OOSystemID) sid;

@end


// Slice 3 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice3)

- (OOSystemID) targetSystemID;
- (void) setTargetSystemID:(OOSystemID) sid;
- (OOSystemID) nextHopTargetSystemID;
- (OOSystemID) infoSystemID;
- (void) setInfoSystemID: (OOSystemID) sid moveChart:(BOOL) moveChart;
- (void) nextInfoSystem;
- (void) previousInfoSystem;
- (void) homeInfoSystem;
- (void) targetInfoSystem;
- (BOOL) infoSystemOnRoute;
- (WormholeEntity *) wormhole;
- (void) setWormhole:(WormholeEntity *)newWormhole;
- (oo::PList) cxx_commanderDataDictionary;	// a Dict, as saved

@end


// Slice 4 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice4)

- (BOOL) cxx_setCommanderDataFromDictionary:(const oo::PList &) dict;

@end


// Slice 5 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice5)

- (BOOL) setUpAndConfirmOK:(BOOL)stopOnError;
- (BOOL) setUpAndConfirmOK:(BOOL)stopOnError saveGame:(BOOL)loadingGame;
- (void) completeSetUp;
- (void) completeSetUpAndSetTarget:(BOOL)setTarget;
- (void) startUpComplete;
- (BOOL) setUpShipFromDictionary:(const oo::PList &) shipDict;
- (NSUInteger) sessionID;
- (void) warnAboutHostiles;
- (BOOL) canCollide;

@end


// Slice 6 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice6)

- (OOComparisonResult) compareZeroDistance:(Entity *)otherEntity;
- (BOOL) validForAddToUniverse;
- (GLfloat) lookingAtSunWithThresholdAngleCos:(GLfloat) thresholdAngleCos;
- (GLfloat) insideAtmosphereFraction;
- (void) update:(OOTimeDelta)delta_t;

@end


// Slice 7 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice7)

- (void) doBookkeeping:(double) delta_t;
- (void) updateMovementFlags;

@end


// Slice 8 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice8)

- (void) updateAlertConditionForNearbyEntities;
- (void) setMaxFlightPitch:(GLfloat)newValue;
- (void) setMaxFlightRoll:(GLfloat)newValue;
- (void) setMaxFlightYaw:(GLfloat)newValue;
- (BOOL) checkEntityForMassLock:(Entity *)ent withScanClass:(int)scanClass;
- (void) updateAlertCondition;
- (void) updateFuelScoops:(OOTimeDelta)delta_t;
- (void) updateClocks:(OOTimeDelta)delta_t;
- (void) checkScriptsIfAppropriate;
- (void) updateTrumbles:(OOTimeDelta)delta_t;
- (void) performAutopilotUpdates:(OOTimeDelta)delta_t;
- (void) performDockingRequest:(StationEntity *)stationForDocking;
- (void) requestDockingClearance:(StationEntity *)stationForDocking;
- (void) cancelDockingRequest:(StationEntity *)stationForDocking;
- (BOOL) engageAutopilotToStation:(StationEntity *)stationForDocking;
- (void) disengageAutopilot;

@end


// Slice 9 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice9)

- (void) resetAutopilotAI;
#if OO_VARIABLE_TORUS_SPEED
- (GLfloat) hyperspeedFactor;
#endif
- (BOOL) injectorsEngaged;
- (BOOL) hyperspeedEngaged;
- (void) performInFlightUpdates:(OOTimeDelta)delta_t;
- (void) performWitchspaceCountdownUpdates:(OOTimeDelta)delta_t;
- (void) performWitchspaceExitUpdates:(OOTimeDelta)delta_t;
- (void) performLaunchingUpdates:(OOTimeDelta)delta_t;
- (void) performDockingUpdates:(OOTimeDelta)delta_t;
- (void) performDeadUpdates:(OOTimeDelta)delta_t;
- (void) gameOverFadeToBW;
- (BOOL) isValidTarget:(Entity*)target;
- (void) showGameOver;
- (void) cxx_showShipModelWithKey:(const std::string &)shipKey shipData:(const oo::PList &)shipData personality:(uint16_t)personality factorX:(GLfloat)factorX factorY:(GLfloat)factorY factorZ:(GLfloat)factorZ inContext:(const std::optional<std::string> &)context;	// null shipData: the registry's
- (void) updateTargeting;

@end


// Slice 10 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice10)

- (void) orientationChanged;
- (void) applyAttitudeChanges:(double) delta_t;
- (void) applyRoll:(GLfloat) roll1 andClimb:(GLfloat) climb1;
- (void) applyYaw:(GLfloat) yaw;
- (OOMatrix) drawRotationMatrix;	// override to provide the 'correct' drawing matrix
- (OOMatrix) drawTransformationMatrix;
- (Quaternion) normalOrientation;
- (void) setNormalOrientation:(Quaternion) quat;
- (void) moveForward:(double) amount;
- (HPVector) breakPatternPosition;
- (Vector) viewpointOffset;
- (Vector) viewpointOffsetAft;
- (Vector) viewpointOffsetForward;
- (Vector) viewpointOffsetPort;
- (Vector) viewpointOffsetStarboard;
- (HPVector) viewpointPosition;
- (void) drawImmediate:(bool)immediate translucent:(bool)translucent;
- (void) setMassLockable:(BOOL)newValue;
- (BOOL) massLockable;
- (BOOL) massLocked;
- (BOOL) atHyperspeed;
- (float) occlusionLevel;
- (void) setOcclusionLevel:(float)level;
- (void) setDockedAtMainStation;
- (StationEntity *) dockedStation;
- (void) setDockedStation:(StationEntity *)station;
- (void) setTargetDockStationTo:(StationEntity *) value;
- (StationEntity *) getTargetDockStation;
- (HeadUpDisplay *) hud;
- (void) resetHud;
- (BOOL) cxx_switchHudTo:(const std::string &)hudFileName;
- (float) cxx_dialCustomFloat:(const std::string &)dialKey;
- (std::string) cxx_dialCustomString:(const std::string &)dialKey;
- (oo::Ref<OOColor>) cxx_dialCustomColor:(const std::string &)dialKey;
- (void) cxx_setDialCustom:(const oo::PList &)value forKey:(const std::string &)dialKey;	// value: any script value, kept as given (live objects as Object nodes)
- (void) setShowDemoShips:(BOOL) value;
- (BOOL) showDemoShips;
- (float) maxForwardShieldLevel;
- (float) maxAftShieldLevel;
- (float) forwardShieldRechargeRate;
- (float) aftShieldRechargeRate;
- (void) setMaxForwardShieldLevel:(float)newValue;
- (void) setMaxAftShieldLevel:(float)newValue;
- (void) setForwardShieldRechargeRate:(float)newValue;
- (void) setAftShieldRechargeRate:(float)newValue;
- (GLfloat) forwardShieldLevel;
- (GLfloat) aftShieldLevel;
- (void) setForwardShieldLevel:(GLfloat)level;
- (void) setAftShieldLevel:(GLfloat)level;
- (oo::PList) cxx_keyConfig;
- (BOOL) isMouseControlOn;
- (GLfloat) dialRoll;
- (GLfloat) dialPitch;
- (GLfloat) dialYaw;
- (GLfloat) dialSpeed;
- (GLfloat) dialHyperSpeed;
- (GLfloat) dialForwardShield;

@end


// Slice 11 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice11)

- (GLfloat) dialAftShield;
- (GLfloat) dialEnergy;
- (GLfloat) dialMaxEnergy;
- (GLfloat) dialFuel;
- (GLfloat) dialHyperRange;
- (GLfloat) laserHeatLevel;
- (GLfloat)laserHeatLevelAft;
- (GLfloat)laserHeatLevelForward;
- (GLfloat)laserHeatLevelPort;
- (GLfloat)laserHeatLevelStarboard;
- (GLfloat) dialAltitude;
- (double) clockTime;			// Note that this is not an OOTimeAbsolute
- (double) clockTimeAdjusted;	// Note that this is not an OOTimeAbsolute
- (BOOL) clockAdjusting;
- (void) addToAdjustTime:(double) seconds ;
- (double) escapePodRescueTime;
- (void) setEscapePodRescueTime:(double) seconds;
- (std::string) cxx_dial_clock;
- (std::string) cxx_dial_clock_adjusted;
- (std::string) cxx_dial_fpsinfo;
- (std::string) cxx_dial_objinfo;
- (unsigned) countMissiles;
- (OOMissileStatus) dialMissileStatus;
- (BOOL) canScoop:(ShipEntity *)other;
- (OOFuelScoopStatus) dialFuelScoopStatus;
- (float) fuelLeakRate;
- (void) setFuelLeakRate:(float)value;
- (std::vector<std::string> *) cxx_commLog;	// the live log, trimmed first (ADR-0043 item 22)
- (std::vector<std::string>) cxx_roleWeights;	// a copy
- (void) addRoleForAggression:(ShipEntity *)victim;
- (void) addRoleForMining;
- (void) cxx_addRoleToPlayer:(const std::string &)role;
- (void) cxx_addRoleToPlayer:(const std::string &)role inSlot:(NSUInteger)slot;
- (void) clearRoleFromPlayer:(BOOL)includingLongRange;
- (void) clearRolesFromPlayer:(float)chance;
- (NSUInteger) maxPlayerRoles;
- (void) updateSystemMemory;
- (Entity *) compassTarget;
- (void) setCompassTarget:(Entity *)value;
- (void) validateCompassTarget;
- (std::optional<std::string>) cxx_compassTargetLabel;

@end


// Slice 12 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice12)

- (OOCompassMode) compassMode;
- (void) setCompassMode:(OOCompassMode)value;
- (void) setPrevCompassMode;
- (void) setNextCompassMode;
- (NSUInteger) activeMissile;
- (void) setActiveMissile:(NSUInteger)value;
- (NSUInteger) dialMaxMissiles;
- (BOOL) dialIdentEngaged;
- (void) setDialIdentEngaged:(BOOL)newValue;
- (std::optional<std::string>) cxx_specialCargo;
- (std::optional<std::string>) cxx_dialTargetName;
- (std::vector<std::optional<std::string>>) cxx_multiFunctionDisplayList;	// nullopt = inactive MFD
- (std::optional<std::string>) cxx_multiFunctionText:(NSUInteger) index;
- (void) cxx_setMultiFunctionText:(const std::optional<std::string> &)text forKey:(const std::optional<std::string> &)key;
- (BOOL) cxx_setMultiFunctionDisplay:(NSUInteger) index toKey:(const std::optional<std::string> &)key;
- (void) cycleNextMultiFunctionDisplay:(NSUInteger) index;
- (void) cyclePreviousMultiFunctionDisplay:(NSUInteger) index;
- (void) selectNextMultiFunctionDisplay;
- (void) selectPreviousMultiFunctionDisplay;
- (NSUInteger) activeMFD;
- (ShipEntity *) missileForPylon:(NSUInteger)value;
- (void) safeAllMissiles;
- (void) tidyMissilePylons;
- (void) selectNextMissile;
- (void) clearAlertFlags;
- (int) alertFlags;
- (void) setAlertFlag:(int)flag to:(BOOL)value;
- (OOAlertCondition) realAlertCondition;

@end


// Slice 13 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice13)

- (OOAlertCondition) alertCondition;
- (OOPlayerFleeingStatus) fleeingStatus;
- (void) interpretAIMessage:(const std::string &)message;
- (BOOL) mountMissile:(ShipEntity *)missile;
- (BOOL) cxx_mountMissileWithRole:(const std::string &)role;
- (ShipEntity *) fireMissile;
- (ShipEntity *) launchMine:(ShipEntity *)mine;
- (BOOL) cxx_assignToActivePylon:(const std::string &)identifierKey;
- (BOOL) activateCloakingDevice;
- (void) deactivateCloakingDevice;
- (double) scannerFuzziness;
- (void) noticeECM;
- (BOOL) fireECM;
- (OOEnergyUnitType) installedEnergyUnitType;
- (OOEnergyUnitType) energyUnitType;
- (void) currentWeaponStats;
- (BOOL) weaponsOnline;
- (void) setWeaponsOnline:(BOOL)newValue;
- (std::vector<Vector>) cxx_currentLaserOffset;
- (BOOL) fireMainWeapon;
- (OOWeaponType) weaponForFacing:(OOWeaponFacing)facing;
- (OOWeaponType) currentWeapon;

@end


// Slice 14 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice14)

- (GLfloat) doesHitLine:(HPVector)v0 :(HPVector)v1 :(ShipEntity **)hitEntity;
- (void) takeEnergyDamage:(double)amount from:(Entity *)ent becauseOf:(Entity *)other weaponIdentifier:(const std::string &)weaponIdentifier;
- (void) takeScrapeDamage:(double) amount from:(Entity *) ent;
- (void) takeHeatDamage:(double) amount;
- (ProxyPlayerEntity *) createDoppelganger;
- (ShipEntity *) launchEscapeCapsule;
- (void) dumpCargo;
- (void) rotateCargo;
- (void) setBounty:(OOCreditsQuantity) amount;
- (void) setBounty:(OOCreditsQuantity)amount withReason:(OOLegalStatusReason)reason;
- (void) setBounty:(OOCreditsQuantity)amount withReasonAsString:(const std::string &)reason;

@end


// Slice 15 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice15)

- (OOCreditsQuantity) bounty;
- (int) legalStatus;
- (void) markAsOffender:(int)offence_value;
- (void) markAsOffender:(int)offence_value withReason:(OOLegalStatusReason)reason;
- (void) collectBountyFor:(ShipEntity *)other;
- (BOOL) takeInternalDamage;
- (void) getDestroyedBy:(Entity *)whom damageType:(OOShipDamageType)type;
- (void) loseTargetStatus;
- (BOOL) cxx_endScenario:(const std::string &)key;
- (void) enterDock:(StationEntity *)station;
- (void) docked;
- (void) leaveDock:(StationEntity *)station;

@end


// Slice 16 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice16)

- (void) witchStart;
- (void) witchEnd;
- (BOOL) witchJumpChecklist:(BOOL)isGalacticJump;
- (void) setJumpType:(BOOL)isGalacticJump;
- (double) hyperspaceJumpDistance;
- (OOFuelQuantity) fuelRequiredForJump;
- (BOOL) hasSufficientFuelForJump;
- (void) noteCompassLostTarget;
- (void) enterGalacticWitchspace;
- (void) enterWormhole:(WormholeEntity *) w_hole;
- (void) enterWitchspace;
- (void) witchJumpTo:(OOSystemID)sTo misjump:(BOOL)misjump;

@end


// Slice 17 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice17)

- (void) leaveWitchspace;
- (void) setGuiToStatusScreen;
- (std::vector<oo::PList>) cxx_equipmentList;	// Each entry is an Array: a string, a bool for availability (false = damaged), then a colour Object (absent for the default colour).
- (NSUInteger) primedEquipmentCount;
- (std::optional<std::string>) cxx_primedEquipmentName:(NSInteger)offset;
- (std::string) cxx_currentPrimedEquipment;	// "": primed-none
- (BOOL) cxx_setPrimedEquipment:(const std::string &)eqKey showMessage:(BOOL)showMsg;
- (void) activatePrimableEquipment:(NSUInteger)index withMode:(OOPrimedEquipmentMode)mode;
- (std::optional<std::string>) cxx_fastEquipmentA;
- (std::optional<std::string>) cxx_fastEquipmentB;
- (void) cxx_setFastEquipmentA:(const std::optional<std::string> &)eqKey;
- (void) cxx_setFastEquipmentB:(const std::optional<std::string> &)eqKey;
- (OOEquipmentType *) weaponTypeForFacing:(OOWeaponFacing)facing strict:(BOOL)strict;

@end


// Slice 18 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice18)

- (std::vector<oo::Ref<OOEquipmentType>>) missilesList;
- (std::vector<std::string>) cxx_cargoList;
- (oo::PList) cargoListForScripting;
- (unsigned) legalStatusOfCargoList;
- (oo::PList::Array) contractsListForScriptingFromArray:(const oo::PList::Array &)contractsArray forCargo:(BOOL)forCargo;
- (oo::PList) passengerListForScripting;
- (oo::PList) parcelListForScripting;
- (oo::PList) contractListForScripting;
- (void) setGuiToSystemDataScreen;
- (void) setGuiToSystemDataScreenRefreshBackground: (BOOL) refreshBackground;
- (std::optional<std::map<int, std::vector<oo::PList>>>) cxx_markedDestinations;	// marker Dicts by system ID, each list in the order the markers were added
- (void) setGuiToLongRangeChartScreen;
- (void) setGuiToShortRangeChartScreen;
- (void) setGuiToChartScreenFrom: (OOGUIScreenID) oldScreen;

@end


// Slice 19 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice19)

- (void) setGuiToGameOptionsScreen;
- (void) setGuiToLoadSaveScreen;
- (void) highlightEquipShipScreenKey:(const std::string &)key;
- (OOWeaponFacingSet) availableFacings;

@end


// Slice 20 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice20)

- (void) cxx_setGuiToEquipShipScreen:(int)skip selectingFacingFor:(const std::optional<std::string> &)eqKeyForSelectFacing;	// nullopt: the normal list
- (void) setGuiToEquipShipScreen:(int)skip;
- (void) showInformationForSelectedUpgrade;
- (void) cxx_showInformationForSelectedUpgradeWithFormatString:(const std::optional<std::string> &)extraString;	// a runtime format with one %@

@end


// Slice 21 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice21)

- (void) setGuiToInterfacesScreen:(int)skip;
- (void) showInformationForSelectedInterface;
- (void) activateSelectedInterface;
- (void) setupStartScreenGui;
- (void) setGuiToIntroFirstGo:(BOOL)justCobra;
- (void) setGuiToOXZManager;
- (void) noteGUIWillChangeTo:(OOGUIScreenID)toScreen;
- (void) noteGUIDidChangeFrom:(OOGUIScreenID)fromScreen to:(OOGUIScreenID)toScreen;
- (void) noteGUIDidChangeFrom:(OOGUIScreenID)fromScreen to:(OOGUIScreenID)toScreen refresh: (BOOL) refresh;
- (void) noteViewDidChangeFrom:(OOViewID)fromView toView:(OOViewID)toView;

@end


// Slice 22 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice22)

- (void) buySelectedItem;
- (OOCreditsQuantity) cxx_adjustPriceByScriptForEqKey:(const std::string &)eqKey withCurrent:(OOCreditsQuantity)price;
- (BOOL) tryBuyingItem:(const std::string &)eqKey;
- (BOOL) setWeaponMount:(OOWeaponFacing)chosen_weapon_facing toWeapon:(const std::string &)eqKey;	// flipped with its family (bead oo-3rb.258)
- (BOOL) cxx_setWeaponMount:(OOWeaponFacing)facing toWeapon:(const std::string &)eqKey inContext:(const std::optional<std::string> &) context;
- (BOOL) changePassengerBerths:(int) addRemove;
- (OOCreditsQuantity) removeMissiles;
- (void) doTradeIn:(OOCreditsQuantity)tradeInValue forPriceFactor:(double)priceFactor;

@end


// Slice 23 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice23)

- (OOCargoQuantity) cxx_cargoQuantityForType:(const std::string &)type;
- (OOCargoQuantity) cxx_setCargoQuantityForType:(const std::string &)type amount:(OOCargoQuantity)amount;
- (void) calculateCurrentCargo;
- (OOCargoQuantity) cargoQuantityOnBoard;
- (OOCommodityMarket *) localMarket;
- (std::vector<std::string>) cxx_applyMarketFilter:(const std::vector<std::string> &)goods onMarket:(OOCommodityMarket *)market;
- (std::vector<std::string>) cxx_applyMarketSorter:(const std::vector<std::string> &)goods onMarket:(OOCommodityMarket *)market;
- (void) showMarketScreenHeaders;
- (void) showMarketScreenDataLine:(OOGUIRow)row forGood:(const std::string &)good inMarket:(OOCommodityMarket *)localMarket holdQuantity:(OOCargoQuantity)quantity;
- (std::optional<std::string>) marketScreenTitle;

@end


// Slice 24 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice24)

- (void) setGuiToMarketScreen;
- (void) setGuiToMarketInfoScreen;
- (void) showMarketCashAndLoadLine;
- (OOGUIScreenID) guiScreen;
- (BOOL) cxx_tryBuyingCommodity:(const std::string &)type all:(BOOL)all;	// "<<<" / ">>>" page the market
- (BOOL) cxx_trySellingCommodity:(const std::string &)type all:(BOOL)all;
- (BOOL) isMining;
- (OOSpeechSettings) isSpeechOn;
- (BOOL) canAddEquipment:(const std::string &)equipmentKey inContext:(const std::string &)context;
- (BOOL) addEquipmentItem:(const std::string &)equipmentKey inContext:(const std::string &)context;

@end


// Slice 25 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice25)

- (BOOL) addEquipmentItem:(const std::string &)equipmentKey withValidation:(BOOL)validateAddition inContext:(const std::string &)context;
- (std::vector<oo::PList> *) cxx_customEquipmentActivation;	// the live entries
- (void) addEquipmentWithScriptToCustomKeyArray:(const std::string &)equipmentKey;
- (void) validateCustomEquipActivationArray;
- (void) removeEquipmentItem:(const std::string &)equipmentKey;
- (void) addEquipmentFromCollection:(const oo::PList &)equipment;	// equipment may be an array, a dictionary whose values are all YES, or a string.
- (BOOL) hasOneEquipmentItem:(const std::string &)itemKey includeMissiles:(BOOL)includeMissiles;
- (BOOL) hasPrimaryWeapon:(OOWeaponType)weaponType;
- (BOOL) removeExternalStore:(OOEquipmentType *)eqType;
- (BOOL) removeFromPylon:(NSUInteger) pylon;
- (NSUInteger) parcelCount;
- (NSUInteger) passengerCount;
- (NSUInteger) passengerCapacity;
- (BOOL) hasHostileTarget;
- (void) receiveCommsMessage:(const std::string &) message_text from:(ShipEntity *) other;
- (void) getFined;
- (void) adjustTradeInFactorBy:(int)value;
- (int) tradeInFactor;
- (double) renovationCosts;
- (double) renovationFactor;
- (void) setDefaultViewOffsets;
- (void) setDefaultCustomViews;
- (Vector) weaponViewOffset;
- (void) setUpTrumbles;
- (void) addTrumble:(OOTrumble *)papaTrumble;
- (void) removeTrumble:(OOTrumble *)deadTrumble;
- (NSUInteger) trumbleCount;

@end


// Slice 26 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice26)

- (oo::PList) trumbleValue;	// [count, hash, trumble records]
- (void) setTrumbleValueFrom:(const oo::PList &)trumbleValue;	// null: none saved
- (float) trumbleAppetiteAccumulator;
- (void) setTrumbleAppetiteAccumulator:(float)value;
- (void) mungChecksumWithString:(const std::optional<std::string> &)str;	// its UTF-16 units; nullopt does nothing
- (std::optional<std::string>) cxx_screenModeStringForWidth:(unsigned)inWidth height:(unsigned)inHeight refreshRate:(float)inRate;
- (void) suppressTargetLost;
- (void) setScoopsActive;
- (void) setFoundTarget:(Entity *) targetEntity;
- (void) addTarget:(Entity *) targetEntity;
- (void) clearTargetMemory;
- (std::vector<oo::ObjCRef<OOWeakReference *>>) cxx_targetMemory;	// a copy; a null ref is an empty slot
- (BOOL) moveTargetMemoryBy:(NSInteger)delta;
- (void) printIdentLockedOnForMissile:(BOOL)missile;
- (Quaternion)customViewQuaternion;
- (void)setCustomViewQuaternion:(Quaternion)q1;
- (OOMatrix)customViewMatrix;
- (Vector)customViewOffset;
- (void)setCustomViewOffset:(Vector)offset;
- (Vector)customViewRotationCenter;
- (void)setCustomViewRotationCenter:(Vector)center;
- (void)customViewZoomIn: (OOScalar) rate;
- (void)customViewZoomOut:(OOScalar) rate;
- (void)customViewRotateLeft:(OOScalar) angle;
- (void)customViewRotateRight:(OOScalar) angle;
- (void)customViewRotateUp:(OOScalar) angle;
- (void)customViewRotateDown:(OOScalar) angle;
- (void)customViewRollRight:(OOScalar) angle;
- (void)customViewRollLeft:(OOScalar) angle;
- (void)customViewPanUp:(OOScalar) angle;
- (void)customViewPanDown:(OOScalar) angle;

@end


// Slice 27 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice27)

- (void)customViewPanLeft:(OOScalar) angle;
- (void)customViewPanRight:(OOScalar) angle;
- (Vector)customViewForwardVector;
- (Vector)customViewUpVector;
- (Vector)customViewRightVector;
- (std::optional<std::string>) cxx_customViewDescription;
- (void)resetCustomView;
- (void)setCustomViewData;
- (void)cxx_setCustomViewDataFromDictionary:(const oo::PList &) viewDict withScaling:(BOOL)withScaling;	// a null viewDict (was nil) resets the matrix and offset only
- (BOOL)showInfoFlag;
- (oo::PList) cxx_missionOverlayDescriptor;
- (oo::PList) cxx_missionOverlayDescriptorOrDefault;
- (void) cxx_setMissionOverlayDescriptor:(const oo::PList &)descriptor;
- (oo::PList) cxx_missionBackgroundDescriptor;
- (oo::PList) cxx_missionBackgroundDescriptorOrDefault;
- (void) cxx_setMissionBackgroundDescriptor:(const oo::PList &)descriptor;
- (OOGUIBackgroundSpecial) missionBackgroundSpecial;
- (void) cxx_setMissionBackgroundSpecial:(const std::string &)special;	// "" (was nil) = none
- (void) setMissionExitScreen:(OOGUIScreenID)screen;
- (OOGUIScreenID) missionExitScreen;
- (oo::PList) cxx_equipScreenBackgroundDescriptor;
- (void) cxx_setEquipScreenBackgroundDescriptor:(const oo::PList &)descriptor;
- (BOOL) scriptsLoaded;
- (std::vector<std::string>) cxx_worldScriptNames;	// in load order
- (std::vector<std::pair<std::string, oo::ObjCRef<OOScript *>>>) cxx_worldScriptsByName;	// in load order
- (OOScript *) cxx_commodityScriptNamed:(const std::optional<std::string> &)script;	// nullopt: nil
- (void) doScriptEvent:(ooscript::PropertyId)message inContext:(ooscript::Context)context withArguments:(ooscript::Value *)argv count:(unsigned)argc;
- (BOOL) doWorldEventUntilMissionScreen:(ooscript::PropertyId)message;
- (void) doWorldScriptEvent:(ooscript::PropertyId)message inContext:(ooscript::Context)context withArguments:(ooscript::Value *)argv count:(unsigned)argc timeLimit:(OOTimeDelta)limit;
- (void) setGalacticHyperspaceBehaviour:(OOGalacticHyperspaceBehaviour) galacticHyperspaceBehaviour;
- (OOGalacticHyperspaceBehaviour) galacticHyperspaceBehaviour;
- (void) setGalacticHyperspaceFixedCoords:(NSPoint)point;
- (void) setGalacticHyperspaceFixedCoordsX:(unsigned char)x y:(unsigned char)y;
- (NSPoint) galacticHyperspaceFixedCoords;
- (void) setWitchspaceCountdown:(int)spin_time;
- (OOLongRangeChartMode) longRangeChartMode;
- (void) setLongRangeChartMode:(OOLongRangeChartMode) mode;
- (BOOL) scoopOverride;
- (void) setScoopOverride:(BOOL)newValue;
- (GLfloat) fuelChargeRate;	// the ship's rate unless MASS_DEPENDENT_FUEL_PRICES (Universe.h)
- (void) setDockTarget:(ShipEntity *)entity;
- (std::optional<std::string>) cxx_jumpCause;
- (void) cxx_setJumpCause:(const std::optional<std::string> &)value;	// never nullopt
- (std::optional<std::string>) cxx_commanderName;
- (std::optional<std::string>) cxx_lastsaveName;
- (void) cxx_setCommanderName:(const std::optional<std::string> &)value;	// never nullopt
- (void) cxx_setLastsaveName:(const std::optional<std::string> &)value;	// never nullopt

@end


// Slice 28 of docs/phases/3-slices/PlayerEntity.md: members of cxx::PlayerEntity, forwarded by the
// category of the same name in PlayerEntity+ObjCBridge.mm (the class's @implementation, empty
// once slice 28 landed, is in that file too). Declared in the class's interface before the slice.
@interface PlayerEntity (OOSlice28)

- (BOOL) isDocked;
- (BOOL) clearedToDock;
- (void) setDockingClearanceStatus:(OODockingClearanceStatus) newValue;
- (OODockingClearanceStatus) getDockingClearanceStatus;
- (void) penaltyForUnauthorizedDocking;
- (void) addScannedWormhole:(WormholeEntity*)wormhole;
- (void) updateWormholes;
- (std::vector<oo::ObjCRef<WormholeEntity *>>) cxx_scannedWormholes;
- (void) initialiseMissionDestinations:(const oo::PList &)destinations andLegacy:(const oo::PList &)legacy;	// used only if a Dict / an Array
- (std::optional<std::string>)markerKey:(const oo::PList &)marker;
- (void) cxx_addMissionDestinationMarker:(const oo::PList &)marker;
- (BOOL) cxx_removeMissionDestinationMarker:(const oo::PList &)marker;
- (oo::PList) cxx_getMissionDestinations;	// a snapshot Dict
- (oo::PList::Dict *) cxx_shipyardRecord;
- (void) cxx_setLastShot:(const std::vector<oo::Ref<OOLaserShotEntity>> &)shot;
- (void) clearExtraMissionKeys;
- (void) cxx_setExtraMissionKeys:(const oo::PList &)keys;	// a Dict of key name -> key definitions
- (void) cxx_clearExtraGuiScreenKeys:(OOGUIScreenID)gui key:(const std::string &)key;
- (BOOL) setExtraGuiScreenKeys:(OOGUIScreenID)gui definition:(OOJSGuiScreenKeyDefinition *)definition;
#ifndef NDEBUG
- (void)dumpSelfState;
#endif

@end


// The category PlayerEntity (ScriptMethods) of PlayerEntityScriptMethods.mm (bead oo-50zg): members of
// cxx::PlayerEntity defined in that file (ADR-0056 amendments oo-o89 item 4 and oo-42dr), forwarded by
// the category of the same name in PlayerEntity+ObjCBridge.mm for the Objective-C callers that remain.
/*	Foundation sweep (proposed ADR-0043, bead oo-8mxr): the Foundation-typed selectors of this
	category have more direct callers than the sizing rule allows (PlayerEntity.mm,
	PlayerEntityControls.mm, PlayerEntityLegacyScriptEngine.mm, PlayerEntityKeyMapper.mm,
	OOStringExpander.mm, OOJSMission.mm, OOJSGlobal.mm, Universe.mm), so they are cxx_ twins here.
	Strings that could be nil are std::optional; a marker is an oo::PList Dict (null where it was
	nil).
*/
@interface PlayerEntity (ScriptMethods)

- (unsigned) score;
- (void) setScore:(unsigned)value;

- (double) creditBalance;
- (void) setCreditBalance:(double)value;

- (std::optional<std::string>) cxx_dockedStationName;
- (std::optional<std::string>) cxx_dockedStationDisplayName;
- (BOOL) dockedAtMainStation;

- (void) cxx_awardCommodityType:(const std::string &)type amount:(OOCargoQuantity)amount;

- (void) resetScannerZoom;

- (OOGalaxyID) currentGalaxyID;
- (OOSystemID) currentSystemID;

- (void) cxx_setMissionChoice:(const std::optional<std::string> &)newChoice;
- (void) cxx_setMissionChoice:(const std::optional<std::string> &)newChoice withEvent:(BOOL) withEvent;
- (void) cxx_setMissionChoice:(const std::optional<std::string> &)newChoice keyPress:(const std::optional<std::string> &)keyPress;
- (void) cxx_setMissionChoice:(const std::optional<std::string> &)newChoice keyPress:(const std::optional<std::string> &)keyPress withEvent:(BOOL) withEvent;
- (void) allowMissionInterrupt;

- (OOTimeDelta) scriptTimer;

- (unsigned) systemPseudoRandom100;
- (unsigned) systemPseudoRandom256;
- (double) systemPseudoRandomFloat;

- (oo::PList) cxx_passengerContractMarker:(OOSystemID)system;
- (oo::PList) cxx_parcelContractMarker:(OOSystemID)system;
- (oo::PList) cxx_cargoContractMarker:(OOSystemID)system;
- (oo::PList) cxx_defaultMarker:(OOSystemID)system;
- (oo::PList) cxx_validatedMarker:(const oo::PList &)marker;

- (std::optional<std::string>) cxx_keyBindingDescription2:(const std::string &)binding;
- (std::optional<std::string>) cxx_getKeyBindingDescription:(const oo::PList &)keyList;
- (std::optional<std::string>) cxx_keyCodeDescription:(OOKeyCode)code;
- (std::optional<std::string>) cxx_keyCodeDescriptionShort:(OOKeyCode)code;

- (std::optional<std::string>) cxx_commanderKillsAsString;
- (std::optional<std::string>) cxx_commanderBountyAsString;
- (std::optional<std::string>) cxx_creditsFormattedForSubstitution;
- (std::optional<std::string>) cxx_creditsFormattedForLegacySubstitution;
// OOStringExpander's special substitution table sends these by name: the cxx_ result above as an
// Objective-C string, or nil.
- (oo::PList) commanderKillsAsString;	// called by name (ADR-0043 item 21)
- (oo::PList) commanderBountyAsString;	// called by name (ADR-0043 item 21)
- (oo::PList) creditsFormattedForSubstitution;	// called by name (ADR-0043 item 21)
- (oo::PList) creditsFormattedForLegacySubstitution;	// called by name (ADR-0043 item 21)

@end


// Implemented by the facade's category in PlayerEntity+ObjCBridge.mm with -init and -dealloc (they
// need the Objective-C object as self), while the class's @implementation is still PlayerEntity.mm;
// declared in the class's interface before slice 1.
@interface PlayerEntity (OOObjCBridge)

+ (PlayerEntity *) sharedPlayer;
- (void) deferredInit;

@end


// Formerly the (Sound) category (PlayerEntitySound.mm, bead oo-xowh): members of cxx::PlayerEntity, forwarded by
// the category of the same name in PlayerEntity+ObjCBridge.mm.
@interface PlayerEntity (OOSound)

- (void) setUpSound;
- (void) setUpWeaponSounds;
- (void) destroySound;
- (BOOL) isBeeping;
- (void) boop;
- (void) playIdentOn;
- (void) playIdentOff;
- (void) playIdentLockedOn;
- (void) playMissileArmed;
- (void) playMineArmed;
- (void) playMissileSafe;
- (void) playMissileLockedOn;
- (void) playNextEquipmentSelected;
- (void) playNextMissileSelected;
- (void) playWeaponsOnline;
- (void) playWeaponsOffline;
- (void) playCargoJettisioned;
- (void) playAutopilotOn;
- (void) playAutopilotOff;
- (void) playAutopilotOutOfRange;
- (void) playAutopilotCannotDockWithTarget;
- (void) playSaveOverwriteYes;
- (void) playSaveOverwriteNo;
- (void) playHoldFull;
- (void) playJumpMassLocked;
- (void) playTargetLost;
- (void) playNoTargetInMemory;
- (void) playTargetSwitched;
- (void) playHyperspaceNoTarget;
- (void) playHyperspaceNoFuel;
- (void) playHyperspaceBlocked;
- (void) playHyperspaceDistanceTooGreat;
- (void) playCloakingDeviceOn;
- (void) playCloakingDeviceOff;
- (void) playMenuNavigationUp;
- (void) playMenuNavigationDown;
- (void) playMenuNavigationNot;
- (void) playMenuPagePrevious;
- (void) playMenuPageNext;
- (void) playDismissedReportScreen;
- (void) playDismissedMissionScreen;
- (void) playChangedOption;
- (void) updateFuelScoopSoundWithInterval:(OOTimeDelta)delta_t;
- (void) updateAfterburnerSound;
- (void) startAfterburnerSound;
- (void) stopAfterburnerSound;
- (void) playCloakingDeviceInsufficientEnergy;
- (void) playBuyCommodity;
- (void) playBuyShip;
- (void) playSellCommodity;
- (void) playCantBuyCommodity;
- (void) playCantSellCommodity;
- (void) playCantBuyShip;
- (void) playStandardHyperspace;
- (void) playGalacticHyperspace;
- (void) playHyperspaceAborted;
- (void) playHitByECMSound;
- (void) playFiredECMSound;
- (void) playLaunchFromStation;
- (void) playDockWithStation;
- (void) playExitWitchspace;
- (void) playHostileWarning;
- (void) playAlertConditionRed;
- (void) playIncomingMissile:(Vector)missileVector;
- (void) playEnergyLow;
- (void) playDockingDenied;
- (void) playWitchjumpFailure;
- (void) playWitchjumpMisjump;
- (void) playWitchjumpBlocked;
- (void) playWitchjumpDistanceTooGreat;
- (void) playWitchjumpInsufficientFuel;
- (void) playFuelLeak;
- (void) cxx_playShieldHit:(Vector)attackVector weaponIdentifier:(const std::string &)weaponIdentifier;
- (void) cxx_playDirectHit:(Vector)attackVector weaponIdentifier:(const std::string &)weaponIdentifier;
- (void) playScrapeDamage:(Vector)attackVector;
- (void) cxx_playLaserHit:(BOOL)hit offset:(Vector)weaponOffset weaponIdentifier:(const std::string &)weaponIdentifier;
- (void) playWeaponOverheated:(Vector)weaponOffset;
- (void) cxx_playMissileLaunched:(Vector)weaponOffset weaponIdentifier:(const std::string &)weaponIdentifier;
- (void) cxx_playMineLaunched:(Vector)weaponOffset weaponIdentifier:(const std::string &)weaponIdentifier;
- (void) playEscapePodScooped;
- (void) playAegisCloseToPlanet;
- (void) playAegisCloseToStation;
- (void) playGameOver;
- (void) playLegacyScriptSound:(const std::string &)key;
- (void) cxx_scheduleAfterburnerSoundUpdate;	// OOScheduleDeferredCall(self, -updateAfterburnerSound, 1.25 s); the C++ member cannot name the selector

@end


// The category (StickMapper) of PlayerEntityStickMapper.mm: members of cxx::PlayerEntity defined in that file, forwarded by
// the category of the same name in PlayerEntity+ObjCBridge.mm (ADR-0056 amendment oo-lmdi8).
@interface PlayerEntity (StickMapper)

   - (void) resetStickFunctions;
   - (void) setGuiToStickMapperScreen: (unsigned)skip resetCurrentRow: (BOOL) resetCurrentRow;
   - (void) setGuiToStickMapperScreen: (unsigned)skip;
   - (void) stickMapperInputHandler: (GuiDisplayGen *)gui
							   view: (MyOpenGLView *)gameView;
   // Callback method: called by name (-performSelector:withObject:) by OOJoystickManager with an
   // Objective-C dictionary, so its parameter stays an object (proposed ADR-0043).
   - (void) updateFunction: (const oo::PList &)hwDict;

   // Future: populate via plist
   - (oo::PList)makeStickGuiDictHeader:(const std::string &)header;
   - (oo::PList)makeStickGuiDict: (const std::string &)what  
							allowable: (int)allowable
							   axisfn: (int)axisfn
								butfn: (int)butfn;
                              
@end


// The private category (StickMapperInternal) of PlayerEntityStickMapper.mm, moved here with its members' forwarders.
@interface PlayerEntity (StickMapperInternal)

- (void) resetStickFunctions;
- (void) checkCustomEquipButtons:(const oo::PList &)stickFn ignore:(int)idx;
- (void) removeFunction:(int)selFunctionIdx;
- (std::vector<oo::PList>)stickFunctionList;
- (void)displayFunctionList:(GuiDisplayGen *)gui
					   skip:(NSUInteger) skip;
- (std::optional<std::string>)describeStickDict:(const oo::PList *)stickDict;	// nullptr: nil
- (std::string)hwToString:(int)hwFlags;

@end

// The category (StickProfile) of PlayerEntityStickProfile.mm: members of cxx::PlayerEntity defined in that file, forwarded by
// the category of the same name in PlayerEntity+ObjCBridge.mm (ADR-0056 amendment oo-lmdi8).
@interface PlayerEntity (StickProfile)

- (void) setGuiToStickProfileScreen: (GuiDisplayGen *) gui;
- (void) stickProfileInputHandler: (GuiDisplayGen *) gui view: (MyOpenGLView *) gameView;
- (void) stickProfileGraphAxisProfile: (GLfloat) alpha screenAt: (Vector) screenAt screenSize: (NSSize) screenSize;

@end

// The category (Controls) of PlayerEntityControls.mm: members of cxx::PlayerEntity defined in that file, forwarded by
// the category of the same name in PlayerEntity+ObjCBridge.mm (ADR-0056 amendment oo-lmdi8).
@interface PlayerEntity (Controls)

- (void) initControls;
- (void) initKeyConfigSettings;

- (void) pollControls:(double)delta_t;
- (BOOL) handleGUIUpDownArrowKeys;
- (void) clearPlanetSearchString;
- (void) targetNewSystem:(int) direction;
- (void) switchToMainView;
- (void) noteSwitchToView:(OOViewID)toView fromView:(OOViewID)fromView;
- (void) beginWitchspaceCountdown:(int)spin_time;
- (void) beginWitchspaceCountdown;
- (void) cancelWitchspaceCountdown;
- (oo::PList) cxx_processKeyCode:(const oo::PList &)key_def;	// an Array of key-definition Dicts, each fully expanded
- (BOOL) checkNavKeyPress:(const oo::PList &)key_def;
- (BOOL) checkKeyPress:(const oo::PList &)key_def;
- (BOOL) checkKeyPress:(const oo::PList &)key_def fKey_only:(BOOL)fKey_only;
- (BOOL) checkKeyPress:(const oo::PList &)key_def ignore_ctrl:(BOOL)ignore_ctrl;
- (BOOL) checkKeyPress:(const oo::PList &)key_def fKey_only:(BOOL)fKey_only ignore_ctrl:(BOOL)ignore_ctrl;
- (int) getFirstKeyCode:(const oo::PList &)key_def;


// Defined in PlayerEntityControls.mm, declared by no interface before the conversion.
- (void) targetNewSystem:(int) direction whileTyping:(BOOL) whileTyping;

@end


// The private category (OOControlsPrivate) of PlayerEntityControls.mm, moved here with its members' forwarders.
@interface PlayerEntity (OOControlsPrivate)

- (void) pollFlightControls:(double) delta_t;
- (void) pollFlightArrowKeyControls:(double) delta_t;
- (void) pollGuiArrowKeyControls:(double) delta_t;
- (void) handleGameOptionsScreenKeys;
- (void) handleKeyMapperScreenKeys;
- (void) handleKeyboardLayoutKeys;
- (void) handleStickMapperScreenKeys;
- (void) pollApplicationControls;
- (void) pollCustomViewControls;
- (void) pollViewControls;
- (void) pollGuiScreenControls;
- (void) pollGuiScreenControlsWithFKeyAlias:(BOOL)fKeyAlias;
- (void) pollMarketScreenControls;
- (void) handleUndockControl;
- (void) pollGameOverControls:(double) delta_t;
- (void) pollAutopilotControls:(double) delta_t;
- (void) pollDockedControls:(double) delta_t;
- (void) pollDemoControls:(double) delta_t;
- (void) pollMissionInterruptControls;
- (void) handleMissionCallback;
- (void) setGuiToMissionEndScreen;
- (void) switchToThisView:(OOViewID)viewDirection;
- (void) switchToThisView:(OOViewID)viewDirection andProcessWeaponFacing:(BOOL)processWeaponFacing;
- (void) switchToThisView:(OOViewID)viewDirection fromView:(OOViewID)oldViewDirection andProcessWeaponFacing:(BOOL)processWeaponFacing justNotify:(BOOL)justNotify;

- (void) handleAutopilotOn:(BOOL)fastDocking;

// Handlers for individual controls
- (void) handleButtonIdent;
- (void) handleButtonTargetMissile;
@end

// The category (KeyMapper) of PlayerEntityKeyMapper.mm: members of cxx::PlayerEntity defined in that file, forwarded by
// the category of the same name in PlayerEntity+ObjCBridge.mm (ADR-0056 amendment oo-lmdi8).
@interface PlayerEntity (KeyMapper)
   - (void) resetKeyFunctions;
   - (void) initCheckingDictionary;

   - (void) setGuiToKeyMapperScreen:(unsigned)skip resetCurrentRow:(BOOL)resetCurrentRow;
   - (void) setGuiToKeyMapperScreen:(unsigned)skip;
   - (void) keyMapperInputHandler:(GuiDisplayGen *)gui view:(MyOpenGLView *)gameView;

   - (void) setGuiToKeyConfigScreen;
   - (void) setGuiToKeyConfigScreen:(BOOL) resetSelectedRow;
   - (void) handleKeyConfigKeys:(GuiDisplayGen *)gui view:(MyOpenGLView *)gameView;
   - (void) outputKeyDefinition:(const std::string &)key shift:(const std::string &)shift mod1:(const std::string &)mod1 mod2:(const std::string &)mod2 skiprows:(NSUInteger)skiprows;

   - (void) setGuiToKeyConfigEntryScreen;
   - (void) handleKeyConfigEntryKeys:(GuiDisplayGen *)gui view:(MyOpenGLView *)gameView;

   - (void) setGuiToConfirmClearScreen;
   - (void) handleKeyMapperConfirmClearKeys:(GuiDisplayGen *)gui view:(MyOpenGLView *)gameView;

   - (void) setGuiToKeyboardLayoutScreen:(unsigned)skip;
   - (void) setGuiToKeyboardLayoutScreen:(unsigned)skip resetCurrentRow:(BOOL)resetCurrentRow;
   - (void) handleKeyboardLayoutEntryKeys:(GuiDisplayGen *)gui view:(MyOpenGLView *)gameView;

   - (std::optional<std::string>)validateKey:(const std::string &)key checkKeys:(const oo::PList &)check_keys;	// the conflicting function; nullopt: none

   - (oo::PList)makeKeyGuiDict:(const std::string &)what keyDef:(const std::string &)keyDef;	// a keyFunctions entry
   - (oo::PList)makeKeyGuiDictHeader:(const std::string &)header;


// Defined in PlayerEntityKeyMapper.mm, declared by no interface before the conversion.
- (std::vector<oo::PList>)keyboardLayoutList;

@end


// The private category (KeyMapperInternal) of PlayerEntityKeyMapper.mm, moved here with its members' forwarders.
@interface PlayerEntity (KeyMapperInternal)

- (void)resetKeyFunctions;
- (void)updateKeyDefinition:(const std::string &)keystring index:(NSUInteger)index;
- (void)updateShiftKeyDefinition:(const std::string &)key index:(NSUInteger)index;
- (void)displayKeyFunctionList:(GuiDisplayGen *)gui skip:(NSUInteger)skip;
- (std::optional<std::string>)keyboardDescription:(const std::string &)kbd;
- (void)displayKeyboardLayoutList:(GuiDisplayGen *)gui skip:(NSUInteger)skip;
- (BOOL)entryIsIndexCustomEquip:(NSUInteger)idx;
- (BOOL)entryIsDictCustomEquip:(const oo::PList &)dict;
- (BOOL)entryIsCustomEquip:(const std::string &)entry;
- (oo::PList)getCustomEquipArray:(const std::string &)key_def;	// null: none (was nil)
- (std::optional<std::string>)getCustomEquipKeyDefType:(const std::string &)key_def;	// always engaged ("" for neither)
- (std::vector<oo::PList>)keyFunctionList;
- (std::vector<std::string>)validateAllKeys;
- (std::optional<std::string>)searchArrayForMatch:(const std::vector<std::string> &)search_list key:(const std::string &)key checkKeys:(const oo::PList &)check_keys;
- (NSUInteger)getCustomEquipIndex:(const std::string &)key_def;
- (BOOL)entryIsEqualToDefault:(const std::string &)key;
- (BOOL)compareKeyEntries:(const oo::PList &)first second:(const oo::PList &)second;
- (void)saveKeySetting:(const std::string &)key;
- (void)unsetKeySetting:(const std::string &)key;
- (void)deleteKeySetting:(const std::string &)key;
- (void)deleteAllKeySettings;
- (oo::PList)loadKeySettings;
- (void) reloadPage;

@end

// The category (Scripting) of PlayerEntityLegacyScriptEngine.mm: members of cxx::PlayerEntity defined in that file, forwarded by
// the category of the same name in PlayerEntity+ObjCBridge.mm (ADR-0056 amendment oo-lmdi8).
@interface PlayerEntity (Scripting)

- (void) checkScript;

- (void) setScriptTarget:(ShipEntity *)ship;
- (ShipEntity*) scriptTarget;

/*	Foundation sweep (proposed ADR-0043, chunk 1 of oo-j924: bead oo-3rb.190): scripts and
	conditions are oo::PList trees, context names std::optional (nullopt was nil).
*/
- (void) cxx_runScriptActions:(const oo::PList &)sanitizedActions withContextName:(const std::optional<std::string> &)contextName forTarget:(ShipEntity *)target;
- (void) cxx_runUnsanitizedScriptActions:(const oo::PList &)unsanitizedActions allowingAIMethods:(BOOL)allowAIMethods withContextName:(const std::optional<std::string> &)contextName forTarget:(ShipEntity *)target;

// Test (sanitized) legacy script conditions array.
- (BOOL) cxx_scriptTestConditions:(const oo::PList &)array;

/*	The mission-variable store (bead oo-3rb.191): a variable is an oo::PList (null = unset; a
	string, an array from -setMissionInstructionsList:, or whatever JavaScript stored).
*/
- (oo::PList) cxx_missionVariables;	// a snapshot
- (oo::PList) cxx_missionVariableForKey:(const std::string &)key;
- (void) cxx_setMissionVariable:(const oo::PList &)value forKey:(const std::string &)key;	// null removes

// A mission's local variables (bead oo-3rb.192): a snapshot Dict, null for no mission.
- (oo::PList) localVariablesForMission:(const std::optional<std::string> &)missionKey;
- (std::optional<std::string>) localVariableForKey:(const std::string &)variableName andMission:(const std::optional<std::string> &)missionKey;
- (void) setLocalVariable:(const std::optional<std::string> &)value forKey:(const std::string &)variableName andMission:(const std::optional<std::string> &)missionKey;	// nullopt removes

/*-----------------------------------------------------*/

- (oo::PList) mission_string;	// called by name (ADR-0043 item 21)
- (oo::PList) status_string;	// called by name (ADR-0043 item 21)
- (oo::PList) gui_screen_string;	// called by name (ADR-0043 item 21)
- (oo::PList) galaxy_number;	// called by name (ADR-0043 item 21)
- (oo::PList) planet_number;	// called by name (ADR-0043 item 21)
- (oo::PList) score_number;	// called by name (ADR-0043 item 21)
- (oo::PList) credits_number;	// called by name (ADR-0043 item 21)
- (oo::PList) scriptTimer_number;	// called by name (ADR-0043 item 21)
- (oo::PList) shipsFound_number;	// called by name (ADR-0043 item 21)

- (oo::PList) d100_number;	// called by name (ADR-0043 item 21)
- (oo::PList) pseudoFixedD100_number;	// called by name (ADR-0043 item 21)
- (oo::PList) d256_number;	// called by name (ADR-0043 item 21)
- (oo::PList) pseudoFixedD256_number;	// called by name (ADR-0043 item 21)

- (oo::PList) clock_number;	// called by name (ADR-0043 item 21); returns the game time in seconds
- (oo::PList) clock_secs_number;	// called by name (ADR-0043 item 21); returns the game time in seconds
- (oo::PList) clock_mins_number;	// called by name (ADR-0043 item 21); returns the game time in minutes
- (oo::PList) clock_hours_number;	// called by name (ADR-0043 item 21); returns the game time in hours
- (oo::PList) clock_days_number;	// called by name (ADR-0043 item 21); returns the game time in days

- (oo::PList) fuelLevel_number;	// called by name (ADR-0043 item 21); returns the fuel level in LY

- (oo::PList) dockedAtMainStation_bool;	// called by name (ADR-0043 item 21)
- (oo::PList) foundEquipment_bool;	// called by name (ADR-0043 item 21)

- (oo::PList) sunWillGoNova_bool;	// called by name (ADR-0043 item 21); returns whether the sun is going to go nova
- (oo::PList) sunGoneNova_bool;	// called by name (ADR-0043 item 21); returns whether the sun has gone nova

- (oo::PList) missionChoice_string;	// called by name (ADR-0043 item 21); returns nil or the key for the chosen option
- (oo::PList) missionKeyPress_string;	// called by name (ADR-0043 item 21)

- (oo::PList) dockedTechLevel_number;	// called by name (ADR-0043 item 21)
- (oo::PList) dockedStationName_string;	// called by name (ADR-0043 item 21); returns 'NONE' if the player isn't docked, [station name] if it is, 'UNKNOWN' otherwise

- (oo::PList) systemGovernment_number;	// called by name (ADR-0043 item 21)
- (oo::PList) systemGovernment_string;	// called by name (ADR-0043 item 21)
- (oo::PList) systemEconomy_number;	// called by name (ADR-0043 item 21)
- (oo::PList) systemEconomy_string;	// called by name (ADR-0043 item 21)
- (oo::PList) systemTechLevel_number;	// called by name (ADR-0043 item 21)
- (oo::PList) systemPopulation_number;	// called by name (ADR-0043 item 21)
- (oo::PList) systemProductivity_number;	// called by name (ADR-0043 item 21)

- (oo::PList) commanderName_string;	// called by name (ADR-0043 item 21)
- (oo::PList) commanderRank_string;	// called by name (ADR-0043 item 21)
- (oo::PList) commanderShip_string;	// called by name (ADR-0043 item 21)
- (oo::PList) commanderShipDisplayName_string;	// called by name (ADR-0043 item 21)
- (oo::PList) commanderLegalStatus_string;	// called by name (ADR-0043 item 21)
- (oo::PList) commanderLegalStatus_number;	// called by name (ADR-0043 item 21)

/*-----------------------------------------------------*/

// The F5 manifest (bead oo-3rb.193): strings first, then arrays of a header and its entries.
- (oo::PList) cxx_missionsList;

- (void) setMissionDescription:(const std::string &)textKey;	// called by name (ADR-0043 item 21)
- (void) clearMissionDescription;
- (void) cxx_setMissionInstructions:(const std::string &)text forMission:(const std::optional<std::string> &)key;	// nullopt key: logged, ignored
- (void) cxx_setMissionInstructionsList:(const oo::PList &)list forMission:(const std::optional<std::string> &)key;
- (void) setMissionDescription:(const std::string &)textKey forMission:(const std::optional<std::string> &)key;
- (void) clearMissionDescriptionForMission:(const std::string &)key;	// called by name (ADR-0043 item 21)

- (void) commsMessage:(const std::string &)valueString;	// called by name (ADR-0055 item 5); shared selector (proposed ADR-0043)
- (void) commsMessageByUnpiloted:(const std::string &)valueString;	// called by name (ADR-0055 item 5); shared selector (proposed ADR-0043)// Enabled 02-May-2008 - Nikos. Same as commsMessage, but
							   // can be used by scripts to have unpiloted ships sending
							   // commsMessages, if we want to.

- (void) consoleMessage3s:(const std::string &)valueString;	// called by name (ADR-0043 item 21)
- (void) consoleMessage6s:(const std::string &)valueString;	// called by name (ADR-0043 item 21)

- (void) setLegalStatus:(const std::string &)valueString;	// called by name (ADR-0043 item 21)
- (void) awardCredits:(const std::string &)valueString;	// called by name (ADR-0043 item 21)
- (void) awardShipKills:(const std::string &)valueString;	// called by name (ADR-0043 item 21)
- (void) awardEquipment:(const std::string &)equipString;	// called by name (ADR-0043 item 21); eg. EQ_NAVAL_ENERGY_UNIT
- (void) removeEquipment:(const std::string &)equipString;	// called by name (ADR-0043 item 21); eg. EQ_NAVAL_ENERGY_UNIT

- (void) setPlanetinfo:(const std::string &)key_valueString;	// called by name (ADR-0043 item 21); uses key=value format
- (void) setSpecificPlanetInfo:(const std::string &)key_valueString;	// called by name (ADR-0043 item 21); uses galaxy#=planet#=key=value

- (void) awardCargo:(const std::string &)amount_typeString;	// called by name (ADR-0043 item 21)
- (void) removeAllCargo;
- (void) removeAllCargo:(BOOL)forceRemoval;

- (void) useSpecialCargo:(const std::string &)descriptionString;	// called by name (ADR-0043 item 21)

- (void) testForEquipment:(const std::string &)equipString;	// called by name (ADR-0043 item 21); eg. EQ_NAVAL_ENERGY_UNIT

- (void) awardFuel:(const std::string &)valueString;	// called by name (ADR-0043 item 21); add to fuel up to 7.0 LY

- (void) messageShipAIs:(const std::string &)roles_message;	// called by name (ADR-0043 item 21)
- (void) ejectItem:(const std::string &)item_key;	// called by name (ADR-0043 item 21)
- (void) addShips:(const std::string &)roles_number;	// called by name (ADR-0043 item 21)
- (void) addSystemShips:(const std::string &)roles_number_position;	// called by name (ADR-0043 item 21)
- (void) addShipsAt:(const std::string &)roles_number_system_x_y_z;	// called by name (ADR-0043 item 21)
- (void) addShipsAtPrecisely:(const std::string &)roles_number_system_x_y_z;	// called by name (ADR-0043 item 21)
- (void) addShipsWithinRadius:(const std::string &)roles_number_system_x_y_z_r;	// called by name (ADR-0043 item 21)
- (void) spawnShip:(const std::string &)ship_key;	// called by name (ADR-0055 item 5)
- (void) set:(const std::string &)missionvariable_value;	// called by name (ADR-0043 item 21)
- (void) reset:(const std::string &)missionvariable;	// called by name (ADR-0043 item 21)
/*
	set:missionvariable_value
	add:missionvariable_value
	subtract:missionvariable_value

	the value may be a string constant or one of the above calls
	ending in _bool, _number, or _string

	egs.
		set: mission_my_mission_status MISSION_START
		set: mission_my_mission_value 12.345
		set: mission_my_mission_clock clock_number
		add: mission_my_mission_clock 86400
		subtract: mission_my_mission_clock d100_number
*/

- (void) increment:(const std::string &)missionVariableString;	// called by name (ADR-0043 item 21)
- (void) decrement:(const std::string &)missionVariableString;	// called by name (ADR-0043 item 21)

- (void) add:(const std::string &)missionVariableString_value;	// called by name (ADR-0043 item 21)
- (void) subtract:(const std::string &)missionVariableString_value;	// called by name (ADR-0043 item 21)

- (void) checkForShips:(const std::string &)roleString;	// called by name (ADR-0043 item 21)
- (void) resetScriptTimer;
- (void) addMissionText:(const std::string &)textKey;	// called by name (ADR-0043 item 21)
- (void) addLiteralMissionText:(const std::string &)text;	// called by name (ADR-0043 item 21)

- (void) setMissionChoiceByTextEntry:(BOOL)enable;
- (void) setMissionChoices:(const std::string &)choicesKey;	// called by name (ADR-0043 item 21); choicesKey is a key for a dictionary of
													// choices/choice phrases in missiontext.plist and also..
- (void) cxx_setMissionChoicesDictionary:(const oo::PList &)choicesDict;	// keys are strings (bead oo-3rb.194)
- (void) resetMissionChoice;						// resets MissionChoice to nil

- (void) clearMissionScreen;

- (void) addMissionDestination:(const std::string &)destinations;	// called by name (ADR-0043 item 21); mark a system on the star charts
- (void) removeMissionDestination:(const std::string &)destinations;	// called by name (ADR-0043 item 21); stop a system being marked on star charts

- (void) showShipModel:(const std::string &)shipKey;	// called by name (ADR-0043 item 21)
- (void) setMissionMusic:(const std::string &)value;	// called by name (ADR-0043 item 21)

- (std::optional<std::string>) cxx_missionTitle;
- (void) cxx_setMissionTitle:(const std::optional<std::string> &)value;

- (void) setFuelLeak:(const std::string &)value;	// called by name (ADR-0043 item 21)
- (oo::PList) fuelLeakRate_number;	// called by name (ADR-0043 item 21)
- (void) setSunNovaIn:(const std::string &)time_value;	// called by name (ADR-0043 item 21)
- (void) launchFromStation;
- (void) blowUpStation;
- (void) sendAllShipsAway;

- (void) addPlanet:(const std::string &)planetKey;	// called by name (ADR-0043 item 21)
- (void) addMoon:(const std::string &)moonKey;	// called by name (ADR-0043 item 21)
- (OOPlanetEntity *) cxx_addPlanet:(const std::string &)planetKey;	// system.addPlanet(): the planet added, or nil
- (OOPlanetEntity *) cxx_addMoon:(const std::string &)moonKey;	// system.addMoon(): the moon added, or nil

- (void) debugOn;
- (void) debugOff;
- (void) debugMessage:(const std::string &)args;	// called by name (ADR-0043 item 21)

- (std::optional<std::string>) replaceVariablesInString:(const std::string &)args;

- (void) playSound:(const std::string &)soundName;	// called by name (ADR-0043 item 21)

// Equipment scripts (bead oo-3rb.195): no equipment has an empty key.
- (BOOL) cxx_addEqScriptForKey:(const std::string &)eq_key;
- (void) cxx_removeEqScriptForKey:(const std::string &)eq_key;
- (NSUInteger) cxx_eqScriptIndexForKey:(const std::string &)eq_key;	// the count of scripts if none

- (void) targetNearestHostile;
- (void) targetNearestIncomingMissile;

- (void) setGalacticHyperspaceBehaviourTo:(const std::string &)galacticHyperspaceBehaviourString;	// called by name (ADR-0043 item 21)
- (void) setGalacticHyperspaceFixedCoordsTo:(const std::string &)galacticHyperspaceFixedCoordsString;	// called by name (ADR-0043 item 21)

/*-----------------------------------------------------*/

- (void) clearMissionScreenID;
- (void) cxx_setMissionScreenID:(const std::optional<std::string> &)msid;
- (std::optional<std::string>) cxx_missionScreenID;
- (void) setGuiToMissionScreen;
- (void) refreshMissionScreenTextEntry;
- (void) setGuiToMissionScreenWithCallback:(BOOL) callback;
- (void) doMissionCallback;
- (void) endMissionScreenAndNoteOpportunity;
- (void) cxx_setBackgroundFromDescriptionsKey:(const std::string &)d_key;
// Scenes (bead oo-3rb.197): a scene is an array of strings, arrays and couplet dictionaries.
- (void) addScene:(const oo::PList &)items atOffset:(Vector)off;
- (BOOL) processSceneDictionary:(const oo::PList &)couplet atOffset:(Vector)off;
- (BOOL) processSceneString:(const std::string &)item atOffset:(Vector)off;


// Defined in PlayerEntityLegacyScriptEngine.mm, declared by no interface before the conversion.
- (std::vector<std::pair<std::string, oo::ObjCRef<OOScript *>>>) worldScriptsRequiringTickle;
- (void) setMissionImage:(const std::string &)value;
- (void) setMissionBackground:(const std::string &)value;

@end


// The private category (ScriptingPrivate) of PlayerEntityLegacyScriptEngine.mm, moved here with its members' forwarders.
@interface PlayerEntity (ScriptingPrivate)

- (BOOL) scriptTestCondition:(const oo::PList &)scriptCondition;
- (std::optional<std::string>) expandScriptRightHandSide:(const oo::PList &)rhsComponents;

- (std::optional<std::string>) expandMessage:(const std::string &)valueString;

@end

// The category (Contracts) of PlayerEntityContracts.mm: members of cxx::PlayerEntity defined in that file, forwarded by
// the category of the same name in PlayerEntity+ObjCBridge.mm (ADR-0056 amendment oo-lmdi8).
@interface PlayerEntity (Contracts)

- (std::optional<std::string>) cxx_processEscapePods;		// removes pods from cargo bay and treats categories of characters carried (never nullopt)
- (std::optional<std::string>) cxx_checkPassengerContracts;	// returns messages from any passengers whose status have changed (nullopt: none)

- (oo::PList) reputation;	// a Dict of signed integers; null on nil

- (int) passengerReputation;
- (void) increasePassengerReputation:(unsigned)amount;
- (void) decreasePassengerReputation:(unsigned)amount;

- (int) parcelReputation;
- (void) increaseParcelReputation:(unsigned)amount;
- (void) decreaseParcelReputation:(unsigned)amount;

- (int) contractReputation;
- (void) increaseContractReputation:(unsigned)amount;
- (void) decreaseContractReputation:(unsigned)amount;
- (OOCargoQuantity) cxx_contractedVolumeForGood:(const std::string &) good;

- (void) erodeReputation;
- (void) normaliseReputation;

- (void) cxx_addMessageToReport:(const std::string &) report;

// - (void) setGuiToContractsScreen;
//- (BOOL) pickFromGuiContractsScreen;
//- (void) highlightSystemFromGuiContractsScreen;

- (BOOL) cxx_addPassenger:(const std::string &)Name start:(unsigned)start destination:(unsigned)destination eta:(double)eta fee:(double)fee advance:(double)advance risk:(unsigned)risk;	// for js scripting
- (BOOL) cxx_removePassenger:(const std::string &)Name;	// for js scripting
- (BOOL) cxx_addParcel:(const std::string &)Name start:(unsigned)start destination:(unsigned)destination eta:(double)eta fee:(double)fee premium:(double)premium risk:(unsigned)risk;	// for js scripting
- (BOOL) cxx_removeParcel:(const std::string &)Name;	// for js scripting
- (BOOL) cxx_awardContract:(unsigned)qty commodity:(const std::string &)commodity start:(unsigned)start destination:(unsigned)destination eta:(double)eta fee:(double)fee premium:(double)premium;	// for js scripting.
- (BOOL) cxx_removeContract:(const std::string &)commodity destination:(unsigned)destination;	// for js scripting

// The manifest lines ("oolite-manifest-person-travelling" / "-item-delivery" expanded per entry).
- (std::vector<std::string>) cxx_passengerList;
- (std::vector<std::string>) cxx_parcelList;
- (std::vector<std::string>) cxx_contractList;
- (void) setGuiToManifestScreen;
- (void) setManifestScreenRow:(const oo::PList &)object inColor:(OOColor*)color forRow:(OOGUIRow)row ofRows:(OOGUIRow)max_rows andOffset:(OOGUIRow)offset inMultipage:(BOOL)multi;


- (void) setGuiToDockingReportScreen;

// ---------------------------------------------------------------------- //

- (void) setGuiToShipyardScreen:(NSUInteger)skip;

- (void) cxx_showShipyardModel:(const std::string &)shipKey shipData:(const oo::PList &)shipDict personality:(uint16_t)personality;
- (void) showShipyardInfoForSelection;
- (NSInteger) missingSubEntitiesAdjustment;
- (void) showTradeInInformationFooter;

- (OOCreditsQuantity) cxx_priceForShipKey:(const std::string &)key;
- (BOOL) buySelectedShip;
- (BOOL) cxx_replaceShipWithNamedShip:(const std::string &)shipName;
- (void) newShipCommonSetup:(const std::string &)shipKey yardInfo:(const oo::PList &)ship_info baseInfo:(const oo::PList &)ship_base_dict;

@end


// The private category (ContractsPrivate) of PlayerEntityContracts.mm, moved here with its members' forwarders.
@interface PlayerEntity (ContractsPrivate)

- (OOCreditsQuantity) tradeInValue;
- (std::vector<std::string>) cxx_contractsListFromEntries:(const oo::PList::Array &) contracts_array forCargo:(BOOL) forCargo forParcels:(BOOL)forParcels;

@end

// The category (LoadSave) of PlayerEntityLoadSave.mm: members of cxx::PlayerEntity defined in that file, forwarded by
// the category of the same name in PlayerEntity+ObjCBridge.mm (ADR-0056 amendment oo-lmdi8).
@interface PlayerEntity (LoadSave)

- (BOOL) loadPlayer;	// Returns NO on immediate failure, i.e. when using an OS X modal open panel which is cancelled.
- (void) savePlayer;
- (void) quicksavePlayer;
- (void) autosavePlayer;

- (void) setGuiToScenarioScreen:(int)page;
- (void) addScenarioModel:(const std::string &)shipKey;
- (void) showScenarioDetails;
- (BOOL) startScenario;


#if OO_USE_CUSTOM_LOAD_SAVE

// Interface for PlayerEntityControls
- (std::optional<std::string>) commanderSelector;	// the saved game chosen, nullopt when none
- (void) saveCommanderInputHandler;
- (void) overwriteCommanderInputHandler;

#endif

- (BOOL) loadPlayerFromFile:(const std::string &)fileToOpen asNew:(BOOL)asNew;

@end


// The private category (OOLoadSavePrivate) of PlayerEntityLoadSave.mm, moved here with its members' forwarders.
@interface PlayerEntity (OOLoadSavePrivate)

#if OOLITE_USE_APPKIT_LOAD_SAVE

- (BOOL) loadPlayerWithPanel;
- (void) savePlayerWithPanel;

#endif

#if OO_USE_CUSTOM_LOAD_SAVE

- (void) setGuiToLoadCommanderScreen;
- (void) setGuiToSaveCommanderScreen: (const std::string &)cdrName;
- (void) setGuiToOverwriteScreen: (const std::string &)cdrName;
- (void) lsCommanders: (GuiDisplayGen *)gui directory: (const std::string &)directory pageNumber: (int)page highlightName: (const std::optional<std::string> &)highlightName;
- (void) showCommanderShip: (int)cdrArrayIndex;
- (int) findIndexOfCommander: (const std::string &)cdrName;
- (void) nativeSavePlayer: (const std::string &)cdrName;
- (BOOL) existingNativeSave: (const std::string &)cdrName;

#endif

- (void) writePlayerToPath:(const std::string &)path;

@end

namespace oo {

// The root's crossings, typed (amendment oo-up4b item 3).
inline cxx::PlayerEntity *ToCxx(::PlayerEntity *entity)
{
	return static_cast<cxx::PlayerEntity *>(ToCxx(static_cast<::ShipEntity *>(entity)));
}

inline ::PlayerEntity *ToObjC(cxx::PlayerEntity *entity)
{
	return (::PlayerEntity *)ToObjC(static_cast<cxx::ShipEntity *>(entity));
}

}	// namespace oo

#endif	// PLAYERENTITY_OBJCBRIDGE_H
