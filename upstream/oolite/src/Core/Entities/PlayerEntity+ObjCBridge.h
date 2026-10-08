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
- (OOColor *) cxx_dialCustomColor:(const std::string &)dialKey;
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

- (std::vector<oo::ObjCRef<OOEquipmentType *>>) missilesList;
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
- (OOTrumble **) trumbleArray;
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
- (void) cxx_setLastShot:(const std::vector<oo::ObjCRef<OOLaserShotEntity *>> &)shot;
- (void) clearExtraMissionKeys;
- (void) cxx_setExtraMissionKeys:(const oo::PList &)keys;	// a Dict of key name -> key definitions
- (void) cxx_clearExtraGuiScreenKeys:(OOGUIScreenID)gui key:(const std::string &)key;
- (BOOL) setExtraGuiScreenKeys:(OOGUIScreenID)gui definition:(OOJSGuiScreenKeyDefinition *)definition;
#ifndef NDEBUG
- (void)dumpSelfState;
#endif

@end


// Implemented by the facade's category in PlayerEntity+ObjCBridge.mm with -init and -dealloc (they
// need the Objective-C object as self), while the class's @implementation is still PlayerEntity.mm;
// declared in the class's interface before slice 1.
@interface PlayerEntity (OOObjCBridge)

+ (PlayerEntity *) sharedPlayer;
- (void) deferredInit;

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
