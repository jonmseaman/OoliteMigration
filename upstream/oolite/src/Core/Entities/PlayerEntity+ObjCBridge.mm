/*

PlayerEntity+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, amendments oo-bj8, oo-60fwo and oo-jx5np): the Objective-C
PlayerEntity facade (see PlayerEntity+ObjCBridge.h). The shared player, its initialisers and
-dealloc are here, in a category while the class's @implementation is still PlayerEntity.mm,
because they need the Objective-C object as self (amendment oo-bj8 item 7), as is the override of
the ship's -initShipPart that makes the player's part (amendment oo-64ako item 2); the other methods are
still in PlayerEntity.mm and its category files until their slices move them. Deleted with
PlayerEntity+ObjCBridge.h.

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
#import "PlayerEntityControls.h"
#import "PlayerEntitySound.h"
#import "PlayerEntityStickProfile.h"
#import "HeadUpDisplay.h"
#import "MyOpenGLView.h"
#import "OOTrumble.h"
#import "OOWeakReference.h"
#import "ShipEntity+ObjCAdapter.h"
#include "oofnd/objc/OOAssert.h"


PlayerEntity		*gOOPlayer = nil;


// The ship's initialiser for the player's -init (moved with it from PlayerEntity.mm).
@interface ShipEntity (Hax)

- (id) initBypassForPlayer;

@end


// The class's @implementation, empty since PlayerEntity.mm's last slice (slice 28, bead oo-zn1vy) moved
// its methods into cxx::PlayerEntity; every selector is forwarded by a category below.
@implementation PlayerEntity
@end


@implementation PlayerEntity (OOObjCBridge)

+ (PlayerEntity *) sharedPlayer
{
	if (EXPECT_NOT(gOOPlayer == nil))
	{
		gOOPlayer = [[PlayerEntity alloc] init];
	}
	return gOOPlayer;
}


/////////////////////////////////////////////////////////


/*	Nasty initialization mechanism:
	PlayerEntity is alloced and inited on demand by +sharedPlayer. This
	initialization doesn't actually set anything up -- apart from the
	assertion, it's like doing a bare alloc. -deferredInit does the work
	that -init "should" be doing. It assumes that -[ShipEntity cxx_initWithKey:
	definition:] will not return an object other than self.
	This is necessary because we need a pointer to the PlayerEntity early in
	startup, when ship data hasn't been loaded yet. In particular, we need
	a pointer to the player to set up the JavaScript environment, we need the
	JavaScript environment to set up OpenGL, and we need OpenGL set up to load
	ships.
*/
- (id) init
{
	OOAssert(gOOPlayer == nil, "Expected only one PlayerEntity to exist at a time.");
	return [super initBypassForPlayer];
}


/*	What [super init] did in ShipEntity's initialisers, with the player's adapter: a player's C++
	part is a cxx::PlayerEntity, with the ship's adapter lines (amendments oo-64ako and oo-jx5np).
	-deferredInit's second ship initialiser keeps the part that is there.
*/
- (id) initShipPart
{
	// -init sent again to an initialised ship keeps its C++ part (the root's -initWithCxxEntity:).
	if (_cxxEntity != nullptr)  return [self initWithCxxEntity:_cxxEntity.get()];
	return [self initWithCxxEntity:oo::makeRef<oo::ObjCShipEntity<cxx::PlayerEntity>>(self).get()];
}


// The root's designated initialiser, which also sets the typed alias of the part it stores, beside
// the ship's.
- (id) initWithCxxEntity:(cxx::Entity *)entity
{
	self = [super initWithCxxEntity:entity];
	if (EXPECT_NOT(self == nil))  return nil;

	_cxxPlayer = dynamic_cast<cxx::PlayerEntity *>(_cxxEntity.get());
	OOCParameterAssert(_cxxPlayer != nullptr);
	return self;
}


- (void) deferredInit
{
	OOAssert(gOOPlayer == self, "Expected only one PlayerEntity to exist at a time.");
	OOAssert([super cxx_initWithKey:std::string(PLAYER_SHIP_DESC) definition:oo::PList(oo::PList::Dict{})] == self, "PlayerEntity requires -[ShipEntity cxx_initWithKey:definition:] to return unmodified self.");

	_cxxPlayer->maxFieldOfView = MAX_FOV;
#if OO_FOV_INFLIGHT_CONTROL_ENABLED
	_cxxPlayer->fov_delta = 2.0; // multiply by 2 each second
#endif

	_cxxPlayer->compassMode = COMPASS_MODE_BASIC;

	_cxxPlayer->afterburnerSoundLooping = NO;

	_cxxEntity->isPlayer = YES;

	[self setStatus:STATUS_START_GAME];

	int i;
	for (i = 0; i < PLAYER_MAX_MISSILES; i++)
	{
		_cxxPlayer->missile_entity[i] = nil;
	}
	[self setUpAndConfirmOK:NO];

	_cxxPlayer->save_path.reset();

	_cxxPlayer->scoopsActive = NO;

	_cxxPlayer->target_memory_index = 0;

	_cxxPlayer->dockingReport.clear();
	[_cxxPlayer->hud cxx_resetGuis:oo::PList(oo::PList::Dict{ { "message_gui", oo::PList(oo::PList::Dict()) },
											{ "comm_log_gui", oo::PList(oo::PList::Dict()) } })];

	[self initControls];
}


- (void) dealloc
{
	/*	Released before its initialiser ran (alloc, then release): there is no C++ part, as in the
		ship's and the root's -dealloc (oo-s6ic6).
	*/
	if (_cxxPlayer == nullptr)
	{
		[super dealloc];
		return;
	}

	DESTROY(_cxxPlayer->compassTarget);
	DESTROY(_cxxPlayer->hud);



	_cxxPlayer->worldScripts.clear();
	_cxxPlayer->worldScriptsRequiringTickle.reset();
	_cxxPlayer->commodityScripts.clear();
	_cxxPlayer->mission_variables = oo::PList();

	_cxxPlayer->localVariables.clear();




	DESTROY(_cxxPlayer->shipCommodityData);


	_cxxPlayer->save_path.reset();
	_cxxPlayer->scenarioKey.reset();




	[self destroySound];

	DESTROY(_cxxPlayer->wormhole);

	int i;
	for (i = 0; i < PLAYER_MAX_MISSILES; i++)  DESTROY(_cxxPlayer->missile_entity[i]);
	for (i = 0; i < PLAYER_MAX_TRUMBLES; i++)  DESTROY(_cxxPlayer->trumble[i]);



	[super dealloc];
}

@end


// Slice 2 of docs/phases/3-slices/PlayerEntity.md (bead oo-m4tfc).
@implementation PlayerEntity (OOSlice2)

- (void) cxx_setName:(const std::optional<std::string> &)inName	{ _cxxPlayer->cxx::PlayerEntity::setName(inName); }
- (GLfloat) baseMass	{ return _cxxPlayer->baseMass(); }
- (void) unloadAllCargoPodsForType:(const std::string &)type toManifest:(OOCommodityMarket *) manifest	{ _cxxPlayer->unloadAllCargoPodsForType(type, manifest); }
- (void) unloadCargoPodsForType:(const std::string &)type amount:(OOCargoQuantity)quantity	{ _cxxPlayer->unloadCargoPodsForType(type, quantity); }
- (void) unloadCargoPods	{ _cxxPlayer->unloadCargoPods(); }
- (void) createCargoPodWithType:(const std::string &)type andAmount:(OOCargoQuantity)amount	{ _cxxPlayer->createCargoPodWithType(type, amount); }
- (void) loadCargoPodsForType:(const std::string &)type fromManifest:(OOCommodityMarket *) manifest	{ _cxxPlayer->loadCargoPodsForType(type, manifest); }
- (void) loadCargoPodsForType:(const std::string &)type amount:(OOCargoQuantity)quantity	{ _cxxPlayer->loadCargoPodsForType(type, quantity); }
- (void) loadCargoPods	{ _cxxPlayer->loadCargoPods(); }
- (OOCommodityMarket *) shipCommodityData	{ return _cxxPlayer->getShipCommodityData(); }
- (OOCreditsQuantity) deciCredits	{ return _cxxPlayer->deciCredits(); }
- (int) random_factor	{ return _cxxPlayer->random_factor(); }
- (void) setRandom_factor:(int)rf	{ _cxxPlayer->setRandom_factor(rf); }
- (OOGalaxyID) galaxyNumber	{ return _cxxPlayer->galaxyNumber(); }
- (NSPoint) galaxy_coordinates	{ return _cxxPlayer->getGalaxy_coordinates(); }
- (void) setGalaxyCoordinates:(NSPoint)newPosition	{ _cxxPlayer->setGalaxyCoordinates(newPosition); }
- (NSPoint) cursor_coordinates	{ return _cxxPlayer->getCursor_coordinates(); }
- (NSPoint) chart_centre_coordinates	{ return _cxxPlayer->getChart_centre_coordinates(); }
- (OOScalar) chart_zoom	{ return _cxxPlayer->getChart_zoom(); }
- (OOScalar) custom_chart_zoom	{ return _cxxPlayer->getCustom_chart_zoom(); }
- (void) setCustomChartZoom:(OOScalar)zoom	{ _cxxPlayer->setCustomChartZoom(zoom); }
- (NSPoint) custom_chart_centre_coordinates	{ return _cxxPlayer->getCustom_chart_centre_coordinates(); }
- (void) setCustomChartCentre:(NSPoint)coords	{ _cxxPlayer->setCustomChartCentre(coords); }
- (NSPoint) adjusted_chart_centre	{ return _cxxPlayer->adjusted_chart_centre(); }
- (OORouteType) ANAMode	{ return _cxxPlayer->ANAMode(); }
- (OOSystemID) systemID	{ return _cxxPlayer->systemID(); }
- (void) setSystemID:(OOSystemID) sid	{ _cxxPlayer->setSystemID(sid); }
- (OOSystemID) previousSystemID	{ return _cxxPlayer->previousSystemID(); }
- (void) setPreviousSystemID:(OOSystemID) sid	{ _cxxPlayer->setPreviousSystemID(sid); }

@end


// Slice 3 of docs/phases/3-slices/PlayerEntity.md (bead oo-7pa3t).
@implementation PlayerEntity (OOSlice3)

- (OOSystemID) targetSystemID	{ return _cxxPlayer->targetSystemID(); }
- (void) setTargetSystemID:(OOSystemID) sid	{ _cxxPlayer->setTargetSystemID(sid); }
- (OOSystemID) nextHopTargetSystemID	{ return _cxxPlayer->nextHopTargetSystemID(); }
- (OOSystemID) infoSystemID	{ return _cxxPlayer->infoSystemID(); }
- (void) setInfoSystemID: (OOSystemID) sid moveChart: (BOOL) moveChart	{ _cxxPlayer->setInfoSystemID(sid, moveChart); }
- (void) nextInfoSystem	{ _cxxPlayer->nextInfoSystem(); }
- (void) previousInfoSystem	{ _cxxPlayer->previousInfoSystem(); }
- (void) homeInfoSystem	{ _cxxPlayer->homeInfoSystem(); }
- (void) targetInfoSystem	{ _cxxPlayer->targetInfoSystem(); }
- (BOOL) infoSystemOnRoute	{ return _cxxPlayer->infoSystemOnRoute(); }
- (WormholeEntity *) wormhole	{ return _cxxPlayer->getWormhole(); }
- (void) setWormhole:(WormholeEntity*)newWormhole	{ _cxxPlayer->setWormhole(newWormhole); }
- (oo::PList) cxx_commanderDataDictionary	{ return _cxxPlayer->commanderDataDictionary(); }

@end


// Slice 4 of docs/phases/3-slices/PlayerEntity.md (bead oo-qvnwb).
@implementation PlayerEntity (OOSlice4)

- (BOOL) cxx_setCommanderDataFromDictionary:(const oo::PList &) dict	{ return _cxxPlayer->setCommanderDataFromDictionary(dict); }

@end


// Slice 5 of docs/phases/3-slices/PlayerEntity.md (bead oo-mmcfq).
@implementation PlayerEntity (OOSlice5)

- (BOOL) setUpAndConfirmOK:(BOOL)stopOnError	{ return _cxxPlayer->setUpAndConfirmOK(stopOnError); }
- (BOOL) setUpAndConfirmOK:(BOOL)stopOnError saveGame:(BOOL)saveGame	{ return _cxxPlayer->setUpAndConfirmOK(stopOnError, saveGame); }
- (void) completeSetUp	{ _cxxPlayer->completeSetUp(); }
- (void) completeSetUpAndSetTarget:(BOOL)setTarget	{ _cxxPlayer->completeSetUpAndSetTarget(setTarget); }
- (void) startUpComplete	{ _cxxPlayer->startUpComplete(); }
- (BOOL) setUpShipFromDictionary:(const oo::PList &) shipDict	{ return _cxxPlayer->cxx::PlayerEntity::setUpShipFromDictionary(shipDict); }
- (NSUInteger) sessionID	{ return _cxxPlayer->cxx::PlayerEntity::sessionID(); }
- (void) warnAboutHostiles	{ _cxxPlayer->cxx::PlayerEntity::warnAboutHostiles(); }
- (BOOL) canCollide	{ return _cxxPlayer->cxx::PlayerEntity::canCollide(); }

@end


// Slice 6 of docs/phases/3-slices/PlayerEntity.md (bead oo-vzjco).
@implementation PlayerEntity (OOSlice6)

- (OOComparisonResult) compareZeroDistance:(Entity *)otherEntity	{ return _cxxPlayer->cxx::PlayerEntity::compareZeroDistance(oo::ToCxx(otherEntity)); }
- (BOOL) validForAddToUniverse	{ return _cxxPlayer->cxx::PlayerEntity::validForAddToUniverse(); }
- (GLfloat) lookingAtSunWithThresholdAngleCos:(GLfloat) thresholdAngleCos	{ return _cxxPlayer->cxx::PlayerEntity::lookingAtSunWithThresholdAngleCos(thresholdAngleCos); }
- (GLfloat) insideAtmosphereFraction	{ return _cxxPlayer->insideAtmosphereFraction(); }
- (void) update:(OOTimeDelta)delta_t	{ _cxxPlayer->cxx::PlayerEntity::update(delta_t); }

@end


// Slice 7 of docs/phases/3-slices/PlayerEntity.md (bead oo-5c466).
@implementation PlayerEntity (OOSlice7)

- (void) doBookkeeping:(double) delta_t	{ _cxxPlayer->doBookkeeping(delta_t); }
- (void) updateMovementFlags	{ _cxxPlayer->updateMovementFlags(); }

@end


// Slice 8 of docs/phases/3-slices/PlayerEntity.md (bead oo-ijf0s).
@implementation PlayerEntity (OOSlice8)

- (void) updateAlertConditionForNearbyEntities	{ _cxxPlayer->updateAlertConditionForNearbyEntities(); }
- (void) setMaxFlightPitch:(GLfloat)newValue	{ _cxxPlayer->cxx::PlayerEntity::setMaxFlightPitch(newValue); }
- (void) setMaxFlightRoll:(GLfloat)newValue	{ _cxxPlayer->cxx::PlayerEntity::setMaxFlightRoll(newValue); }
- (void) setMaxFlightYaw:(GLfloat)newValue	{ _cxxPlayer->cxx::PlayerEntity::setMaxFlightYaw(newValue); }
- (BOOL) checkEntityForMassLock:(Entity *)ent withScanClass:(int)theirClass	{ return _cxxPlayer->checkEntityForMassLock(ent, theirClass); }
- (void) updateAlertCondition	{ _cxxPlayer->updateAlertCondition(); }
- (void) updateFuelScoops:(OOTimeDelta)delta_t	{ _cxxPlayer->updateFuelScoops(delta_t); }
- (void) updateClocks:(OOTimeDelta)delta_t	{ _cxxPlayer->updateClocks(delta_t); }
- (void) checkScriptsIfAppropriate	{ _cxxPlayer->checkScriptsIfAppropriate(); }
- (void) updateTrumbles:(OOTimeDelta)delta_t	{ _cxxPlayer->updateTrumbles(delta_t); }
- (void) performAutopilotUpdates:(OOTimeDelta)delta_t	{ _cxxPlayer->performAutopilotUpdates(delta_t); }
- (void) performDockingRequest:(StationEntity *)stationForDocking	{ _cxxPlayer->performDockingRequest(stationForDocking); }
- (void) requestDockingClearance:(StationEntity *)stationForDocking	{ _cxxPlayer->requestDockingClearance(stationForDocking); }
- (void) cancelDockingRequest:(StationEntity *)stationForDocking	{ _cxxPlayer->cancelDockingRequest(stationForDocking); }
- (BOOL) engageAutopilotToStation:(StationEntity *)stationForDocking	{ return _cxxPlayer->engageAutopilotToStation(stationForDocking); }
- (void) disengageAutopilot	{ _cxxPlayer->cxx::PlayerEntity::disengageAutopilot(); }

@end


// Slice 9 of docs/phases/3-slices/PlayerEntity.md (bead oo-qyjcv).
@implementation PlayerEntity (OOSlice9)

- (void) resetAutopilotAI	{ _cxxPlayer->resetAutopilotAI(); }
#if OO_VARIABLE_TORUS_SPEED
- (GLfloat) hyperspeedFactor	{ return _cxxPlayer->getHyperspeedFactor(); }
#endif
- (BOOL) injectorsEngaged	{ return _cxxPlayer->injectorsEngaged(); }
- (BOOL) hyperspeedEngaged	{ return _cxxPlayer->hyperspeedEngaged(); }
- (void) performInFlightUpdates:(OOTimeDelta)delta_t	{ _cxxPlayer->performInFlightUpdates(delta_t); }
- (void) performWitchspaceCountdownUpdates:(OOTimeDelta)delta_t	{ _cxxPlayer->performWitchspaceCountdownUpdates(delta_t); }
- (void) performWitchspaceExitUpdates:(OOTimeDelta)delta_t	{ _cxxPlayer->performWitchspaceExitUpdates(delta_t); }
- (void) performLaunchingUpdates:(OOTimeDelta)delta_t	{ _cxxPlayer->performLaunchingUpdates(delta_t); }
- (void) performDockingUpdates:(OOTimeDelta)delta_t	{ _cxxPlayer->performDockingUpdates(delta_t); }
- (void) performDeadUpdates:(OOTimeDelta)delta_t	{ _cxxPlayer->performDeadUpdates(delta_t); }
- (void) gameOverFadeToBW	{ _cxxPlayer->gameOverFadeToBW(); }
- (BOOL)isValidTarget:(Entity*)target	{ return _cxxPlayer->cxx::PlayerEntity::isValidTarget(target); }
- (void) showGameOver	{ _cxxPlayer->showGameOver(); }
- (void) cxx_showShipModelWithKey:(const std::string &)shipKey shipData:(const oo::PList &)shipDataIn personality:(uint16_t)personality factorX:(GLfloat)factorX factorY:(GLfloat)factorY factorZ:(GLfloat)factorZ inContext:(const std::optional<std::string> &)context	{ _cxxPlayer->showShipModelWithKey(shipKey, shipDataIn, personality, factorX, factorY, factorZ, context); }
- (void) updateTargeting	{ _cxxPlayer->updateTargeting(); }

@end


// Slice 10 of docs/phases/3-slices/PlayerEntity.md (bead oo-9u9w6).
@implementation PlayerEntity (OOSlice10)

- (void) orientationChanged	{ _cxxPlayer->cxx::PlayerEntity::orientationChanged(); }
- (void) applyAttitudeChanges:(double) delta_t	{ _cxxPlayer->cxx::PlayerEntity::applyAttitudeChanges(delta_t); }
- (void) applyRoll:(GLfloat) roll1 andClimb:(GLfloat) climb1	{ _cxxPlayer->cxx::PlayerEntity::applyRoll(roll1, climb1); }
- (void) applyYaw:(GLfloat) yaw	{ _cxxPlayer->applyYaw(yaw); }
- (OOMatrix) drawRotationMatrix	{ return _cxxPlayer->cxx::PlayerEntity::drawRotationMatrix(); }
- (OOMatrix) drawTransformationMatrix	{ return _cxxPlayer->cxx::PlayerEntity::drawTransformationMatrix(); }
- (Quaternion) normalOrientation	{ return _cxxPlayer->cxx::PlayerEntity::normalOrientation(); }
- (void) setNormalOrientation:(Quaternion) quat	{ _cxxPlayer->cxx::PlayerEntity::setNormalOrientation(quat); }
- (void) moveForward:(double) amount	{ _cxxPlayer->cxx::PlayerEntity::moveForward(amount); }
- (HPVector) breakPatternPosition	{ return _cxxPlayer->breakPatternPosition(); }
- (Vector) viewpointOffset	{ return _cxxPlayer->viewpointOffset(); }
- (Vector) viewpointOffsetAft	{ return _cxxPlayer->viewpointOffsetAft(); }
- (Vector) viewpointOffsetForward	{ return _cxxPlayer->viewpointOffsetForward(); }
- (Vector) viewpointOffsetPort	{ return _cxxPlayer->viewpointOffsetPort(); }
- (Vector) viewpointOffsetStarboard	{ return _cxxPlayer->viewpointOffsetStarboard(); }
- (HPVector) viewpointPosition	{ return _cxxPlayer->viewpointPosition(); }
- (void) drawImmediate:(bool)immediate translucent:(bool)translucent	{ _cxxPlayer->cxx::PlayerEntity::drawImmediate(immediate, translucent); }
- (void) setMassLockable:(BOOL)newValue	{ _cxxPlayer->setMassLockable(newValue); }
- (BOOL) massLockable	{ return _cxxPlayer->getMassLockable(); }
- (BOOL) massLocked	{ return _cxxPlayer->massLocked(); }
- (BOOL) atHyperspeed	{ return _cxxPlayer->atHyperspeed(); }
- (float) occlusionLevel	{ return _cxxPlayer->occlusionLevel(); }
- (void) setOcclusionLevel:(float)level	{ _cxxPlayer->setOcclusionLevel(level); }
- (void) setDockedAtMainStation	{ _cxxPlayer->setDockedAtMainStation(); }
- (StationEntity *) dockedStation	{ return _cxxPlayer->dockedStation(); }
- (void) setDockedStation:(StationEntity *)station	{ _cxxPlayer->setDockedStation(station); }
- (void) setTargetDockStationTo:(StationEntity *) value	{ _cxxPlayer->setTargetDockStationTo(value); }
- (StationEntity *) getTargetDockStation	{ return _cxxPlayer->getTargetDockStation(); }
- (HeadUpDisplay *) hud	{ return _cxxPlayer->getHud(); }
- (void) resetHud	{ _cxxPlayer->resetHud(); }
- (BOOL) cxx_switchHudTo:(const std::string &)hudFileName	{ return _cxxPlayer->switchHudTo(hudFileName); }
- (float) cxx_dialCustomFloat:(const std::string &)dialKey	{ return _cxxPlayer->dialCustomFloat(dialKey); }
- (std::string) cxx_dialCustomString:(const std::string &)dialKey	{ return _cxxPlayer->dialCustomString(dialKey); }
- (OOColor *) cxx_dialCustomColor:(const std::string &)dialKey	{ return _cxxPlayer->dialCustomColor(dialKey); }
- (void) cxx_setDialCustom:(const oo::PList &)value forKey:(const std::string &)dialKey	{ _cxxPlayer->setDialCustom(value, dialKey); }
- (void) setShowDemoShips:(BOOL)value	{ _cxxPlayer->setShowDemoShips(value); }
- (BOOL) showDemoShips	{ return _cxxPlayer->getShowDemoShips(); }
- (float) maxForwardShieldLevel	{ return _cxxPlayer->cxx::PlayerEntity::maxForwardShieldLevel(); }
- (float) maxAftShieldLevel	{ return _cxxPlayer->cxx::PlayerEntity::maxAftShieldLevel(); }
- (float) forwardShieldRechargeRate	{ return _cxxPlayer->forwardShieldRechargeRate(); }
- (float) aftShieldRechargeRate	{ return _cxxPlayer->aftShieldRechargeRate(); }
- (void) setMaxForwardShieldLevel:(float)newValue	{ _cxxPlayer->setMaxForwardShieldLevel(newValue); }
- (void) setMaxAftShieldLevel:(float)newValue	{ _cxxPlayer->setMaxAftShieldLevel(newValue); }
- (void) setForwardShieldRechargeRate:(float)newValue	{ _cxxPlayer->setForwardShieldRechargeRate(newValue); }
- (void) setAftShieldRechargeRate:(float)newValue	{ _cxxPlayer->setAftShieldRechargeRate(newValue); }
- (GLfloat) forwardShieldLevel	{ return _cxxPlayer->forwardShieldLevel(); }
- (GLfloat) aftShieldLevel	{ return _cxxPlayer->aftShieldLevel(); }
- (void) setForwardShieldLevel:(GLfloat)level	{ _cxxPlayer->setForwardShieldLevel(level); }
- (void) setAftShieldLevel:(GLfloat)level	{ _cxxPlayer->setAftShieldLevel(level); }
- (oo::PList) cxx_keyConfig	{ return _cxxPlayer->keyConfig(); }
- (BOOL) isMouseControlOn	{ return _cxxPlayer->isMouseControlOn(); }
- (GLfloat) dialRoll	{ return _cxxPlayer->dialRoll(); }
- (GLfloat) dialPitch	{ return _cxxPlayer->dialPitch(); }
- (GLfloat) dialYaw	{ return _cxxPlayer->dialYaw(); }
- (GLfloat) dialSpeed	{ return _cxxPlayer->dialSpeed(); }
- (GLfloat) dialHyperSpeed	{ return _cxxPlayer->dialHyperSpeed(); }
- (GLfloat) dialForwardShield	{ return _cxxPlayer->dialForwardShield(); }

@end


// Slice 11 of docs/phases/3-slices/PlayerEntity.md (bead oo-zxg1h).
@implementation PlayerEntity (OOSlice11)

- (GLfloat) dialAftShield	{ return _cxxPlayer->dialAftShield(); }
- (GLfloat) dialEnergy	{ return _cxxPlayer->dialEnergy(); }
- (GLfloat) dialMaxEnergy	{ return _cxxPlayer->dialMaxEnergy(); }
- (GLfloat) dialFuel	{ return _cxxPlayer->dialFuel(); }
- (GLfloat) dialHyperRange	{ return _cxxPlayer->dialHyperRange(); }
- (GLfloat) laserHeatLevel	{ return _cxxPlayer->cxx::PlayerEntity::laserHeatLevel(); }
- (GLfloat)laserHeatLevelAft	{ return _cxxPlayer->cxx::PlayerEntity::laserHeatLevelAft(); }
- (GLfloat)laserHeatLevelForward	{ return _cxxPlayer->cxx::PlayerEntity::laserHeatLevelForward(); }
- (GLfloat)laserHeatLevelPort	{ return _cxxPlayer->cxx::PlayerEntity::laserHeatLevelPort(); }
- (GLfloat)laserHeatLevelStarboard	{ return _cxxPlayer->cxx::PlayerEntity::laserHeatLevelStarboard(); }
- (GLfloat) dialAltitude	{ return _cxxPlayer->dialAltitude(); }
- (double) clockTime	{ return _cxxPlayer->clockTime(); }
- (double) clockTimeAdjusted	{ return _cxxPlayer->clockTimeAdjusted(); }
- (BOOL) clockAdjusting	{ return _cxxPlayer->clockAdjusting(); }
- (void) addToAdjustTime:(double)seconds	{ _cxxPlayer->addToAdjustTime(seconds); }
- (double) escapePodRescueTime	{ return _cxxPlayer->escapePodRescueTime(); }
- (void) setEscapePodRescueTime:(double)seconds	{ _cxxPlayer->setEscapePodRescueTime(seconds); }
- (std::string) cxx_dial_clock	{ return _cxxPlayer->dial_clock(); }
- (std::string) cxx_dial_clock_adjusted	{ return _cxxPlayer->dial_clock_adjusted(); }
- (std::string) cxx_dial_fpsinfo	{ return _cxxPlayer->dial_fpsinfo(); }
- (std::string) cxx_dial_objinfo	{ return _cxxPlayer->dial_objinfo(); }
- (unsigned) countMissiles	{ return _cxxPlayer->countMissiles(); }
- (OOMissileStatus) dialMissileStatus	{ return _cxxPlayer->dialMissileStatus(); }
- (BOOL) canScoop:(ShipEntity *)other	{ return _cxxPlayer->cxx::PlayerEntity::canScoop(other); }
- (OOFuelScoopStatus) dialFuelScoopStatus	{ return _cxxPlayer->dialFuelScoopStatus(); }
- (float) fuelLeakRate	{ return _cxxPlayer->fuelLeakRate(); }
- (void) setFuelLeakRate:(float)value	{ _cxxPlayer->setFuelLeakRate(value); }
- (std::vector<std::string> *) cxx_commLog	{ return _cxxPlayer->getCommLog(); }
- (std::vector<std::string>) cxx_roleWeights	{ return _cxxPlayer->getRoleWeights(); }
- (void) addRoleForAggression:(ShipEntity *)victim	{ _cxxPlayer->addRoleForAggression(victim); }
- (void) addRoleForMining	{ _cxxPlayer->addRoleForMining(); }
- (void) cxx_addRoleToPlayer:(const std::string &)role	{ _cxxPlayer->addRoleToPlayer(role); }
- (void) cxx_addRoleToPlayer:(const std::string &)role inSlot:(NSUInteger)slot	{ _cxxPlayer->addRoleToPlayer(role, slot); }
- (void) clearRoleFromPlayer:(BOOL)includingLongRange	{ _cxxPlayer->clearRoleFromPlayer(includingLongRange); }
- (void) clearRolesFromPlayer:(float)chance	{ _cxxPlayer->clearRolesFromPlayer(chance); }
- (NSUInteger) maxPlayerRoles	{ return _cxxPlayer->maxPlayerRoles(); }
- (void) updateSystemMemory	{ _cxxPlayer->updateSystemMemory(); }
- (Entity *) compassTarget	{ return _cxxPlayer->getCompassTarget(); }
- (void) setCompassTarget:(Entity *)value	{ _cxxPlayer->setCompassTarget(value); }
- (void) validateCompassTarget	{ _cxxPlayer->validateCompassTarget(); }
- (std::optional<std::string>) cxx_compassTargetLabel	{ return _cxxPlayer->compassTargetLabel(); }

@end


// Slice 12 of docs/phases/3-slices/PlayerEntity.md (bead oo-rqcfz).
@implementation PlayerEntity (OOSlice12)

- (OOCompassMode) compassMode	{ return _cxxPlayer->getCompassMode(); }
- (void) setCompassMode:(OOCompassMode) value	{ _cxxPlayer->setCompassMode(value); }
- (void) setPrevCompassMode	{ _cxxPlayer->setPrevCompassMode(); }
- (void) setNextCompassMode	{ _cxxPlayer->setNextCompassMode(); }
- (NSUInteger) activeMissile	{ return _cxxPlayer->getActiveMissile(); }
- (void) setActiveMissile:(NSUInteger)value	{ _cxxPlayer->setActiveMissile(value); }
- (NSUInteger) dialMaxMissiles	{ return _cxxPlayer->dialMaxMissiles(); }
- (BOOL) dialIdentEngaged	{ return _cxxPlayer->dialIdentEngaged(); }
- (void) setDialIdentEngaged:(BOOL)newValue	{ _cxxPlayer->setDialIdentEngaged(newValue); }
- (std::optional<std::string>) cxx_specialCargo	{ return _cxxPlayer->getSpecialCargo(); }
- (std::optional<std::string>) cxx_dialTargetName	{ return _cxxPlayer->dialTargetName(); }
- (std::vector<std::optional<std::string>>) cxx_multiFunctionDisplayList	{ return _cxxPlayer->multiFunctionDisplayList(); }
- (std::optional<std::string>) cxx_multiFunctionText:(NSUInteger)i	{ return _cxxPlayer->multiFunctionText(i); }
- (void) cxx_setMultiFunctionText:(const std::optional<std::string> &)text forKey:(const std::optional<std::string> &)key	{ _cxxPlayer->setMultiFunctionText(text, key); }
- (BOOL) cxx_setMultiFunctionDisplay:(NSUInteger)index toKey:(const std::optional<std::string> &)key	{ return _cxxPlayer->setMultiFunctionDisplay(index, key); }
- (void) cycleNextMultiFunctionDisplay:(NSUInteger) index	{ _cxxPlayer->cycleNextMultiFunctionDisplay(index); }
- (void) cyclePreviousMultiFunctionDisplay:(NSUInteger) index	{ _cxxPlayer->cyclePreviousMultiFunctionDisplay(index); }
- (void) selectNextMultiFunctionDisplay	{ _cxxPlayer->selectNextMultiFunctionDisplay(); }
- (void) selectPreviousMultiFunctionDisplay	{ _cxxPlayer->selectPreviousMultiFunctionDisplay(); }
- (NSUInteger) activeMFD	{ return _cxxPlayer->getActiveMFD(); }
- (ShipEntity *) missileForPylon:(NSUInteger)value	{ return _cxxPlayer->missileForPylon(value); }
- (void) safeAllMissiles	{ _cxxPlayer->safeAllMissiles(); }
- (void) tidyMissilePylons	{ _cxxPlayer->tidyMissilePylons(); }
- (void) selectNextMissile	{ _cxxPlayer->selectNextMissile(); }
- (void) clearAlertFlags	{ _cxxPlayer->clearAlertFlags(); }
- (int) alertFlags	{ return _cxxPlayer->getAlertFlags(); }
- (void) setAlertFlag:(int)flag to:(BOOL)value	{ _cxxPlayer->setAlertFlag(flag, value); }
- (OOAlertCondition) realAlertCondition	{ return _cxxPlayer->cxx::PlayerEntity::realAlertCondition(); }

@end


// Slice 13 of docs/phases/3-slices/PlayerEntity.md (bead oo-30g73).
@implementation PlayerEntity (OOSlice13)

- (OOAlertCondition) alertCondition	{ return _cxxPlayer->getAlertCondition(); }
- (OOPlayerFleeingStatus) fleeingStatus	{ return _cxxPlayer->fleeingStatus(); }
- (void) interpretAIMessage:(const std::string &)message	{ _cxxPlayer->cxx::PlayerEntity::interpretAIMessage(message); }
- (BOOL) mountMissile:(ShipEntity *)missile	{ return _cxxPlayer->mountMissile(missile); }
- (BOOL) cxx_mountMissileWithRole:(const std::string &)role	{ return _cxxPlayer->mountMissileWithRole(role); }
- (ShipEntity *) fireMissile	{ return _cxxPlayer->cxx::PlayerEntity::fireMissile(); }
- (ShipEntity *) launchMine:(ShipEntity*) mine	{ return _cxxPlayer->launchMine(mine); }
- (BOOL) cxx_assignToActivePylon:(const std::string &)equipmentKey	{ return _cxxPlayer->assignToActivePylon(equipmentKey); }
- (BOOL) activateCloakingDevice	{ return _cxxPlayer->cxx::PlayerEntity::activateCloakingDevice(); }
- (void) deactivateCloakingDevice	{ _cxxPlayer->cxx::PlayerEntity::deactivateCloakingDevice(); }
- (double) scannerFuzziness	{ return _cxxPlayer->scannerFuzziness(); }
- (void) noticeECM	{ _cxxPlayer->cxx::PlayerEntity::noticeECM(); }
- (BOOL) fireECM	{ return _cxxPlayer->cxx::PlayerEntity::fireECM(); }
- (OOEnergyUnitType) installedEnergyUnitType	{ return _cxxPlayer->installedEnergyUnitType(); }
- (OOEnergyUnitType) energyUnitType	{ return _cxxPlayer->energyUnitType(); }
- (void) currentWeaponStats	{ _cxxPlayer->currentWeaponStats(); }
- (BOOL) weaponsOnline	{ return _cxxPlayer->weaponsOnline(); }
- (void) setWeaponsOnline:(BOOL)newValue	{ _cxxPlayer->setWeaponsOnline(newValue); }
- (std::vector<Vector>) cxx_currentLaserOffset	{ return _cxxPlayer->currentLaserOffset(); }
- (BOOL) fireMainWeapon	{ return _cxxPlayer->fireMainWeapon(); }
- (OOWeaponType) weaponForFacing:(OOWeaponFacing)facing	{ return _cxxPlayer->weaponForFacing(facing); }
- (OOWeaponType) currentWeapon	{ return _cxxPlayer->currentWeapon(); }

@end


// Slice 14 of docs/phases/3-slices/PlayerEntity.md (bead oo-m8x1y).
@implementation PlayerEntity (OOSlice14)

- (GLfloat) doesHitLine:(HPVector)v0 :(HPVector)v1 :(ShipEntity **)hitEntity	{ return _cxxPlayer->cxx::PlayerEntity::doesHitLine(v0, v1, hitEntity); }
- (void) takeEnergyDamage:(double)amount from:(Entity *)ent becauseOf:(Entity *)other weaponIdentifier:(const std::string &)weaponIdentifier	{ _cxxPlayer->cxx::PlayerEntity::takeEnergyDamage(amount, oo::ToCxx(ent), oo::ToCxx(other), weaponIdentifier); }
- (void) takeScrapeDamage:(double) amount from:(Entity *) ent	{ _cxxPlayer->cxx::PlayerEntity::takeScrapeDamage(amount, ent); }
- (void) takeHeatDamage:(double) amount	{ _cxxPlayer->cxx::PlayerEntity::takeHeatDamage(amount); }
- (ProxyPlayerEntity *) createDoppelganger	{ return _cxxPlayer->createDoppelganger(); }
- (ShipEntity *) launchEscapeCapsule	{ return _cxxPlayer->cxx::PlayerEntity::launchEscapeCapsule(); }
- (void) dumpCargo	{ _cxxPlayer->cxx::PlayerEntity::dumpCargo(); }
- (void) rotateCargo	{ _cxxPlayer->rotateCargo(); }
- (void) setBounty:(OOCreditsQuantity) amount	{ _cxxPlayer->cxx::PlayerEntity::setBounty(amount); }
- (void) setBounty:(OOCreditsQuantity)amount withReason:(OOLegalStatusReason)reason	{ _cxxPlayer->cxx::PlayerEntity::setBounty(amount, reason); }
- (void) setBounty:(OOCreditsQuantity)amount withReasonAsString:(const std::string &)reason	{ _cxxPlayer->cxx::PlayerEntity::setBounty(amount, reason); }

@end


// Slice 15 of docs/phases/3-slices/PlayerEntity.md (bead oo-2lpiu).
@implementation PlayerEntity (OOSlice15)

- (OOCreditsQuantity) bounty	{ return _cxxPlayer->cxx::PlayerEntity::getBounty(); }
- (int) legalStatus	{ return _cxxPlayer->getLegalStatus(); }
- (void) markAsOffender:(int)offence_value	{ _cxxPlayer->cxx::PlayerEntity::markAsOffender(offence_value); }
- (void) markAsOffender:(int)offence_value withReason:(OOLegalStatusReason)reason	{ _cxxPlayer->cxx::PlayerEntity::markAsOffender(offence_value, reason); }
- (void) collectBountyFor:(ShipEntity *)other	{ _cxxPlayer->cxx::PlayerEntity::collectBountyFor(other); }
- (BOOL) takeInternalDamage	{ return _cxxPlayer->takeInternalDamage(); }
- (void) getDestroyedBy:(Entity *)whom damageType:(OOShipDamageType)type	{ _cxxPlayer->cxx::PlayerEntity::getDestroyedBy(whom, type); }
- (void) loseTargetStatus	{ _cxxPlayer->loseTargetStatus(); }
- (BOOL) cxx_endScenario:(const std::string &)key	{ return _cxxPlayer->endScenario(key); }
- (void) enterDock:(StationEntity *)station	{ _cxxPlayer->cxx::PlayerEntity::enterDock(station); }
- (void) docked	{ _cxxPlayer->docked(); }
- (void) leaveDock:(StationEntity *)station	{ _cxxPlayer->cxx::PlayerEntity::leaveDock(station); }

@end


// Slice 16 of docs/phases/3-slices/PlayerEntity.md (bead oo-vqjjb).
@implementation PlayerEntity (OOSlice16)

- (void) witchStart	{ _cxxPlayer->witchStart(); }
- (void) witchEnd	{ _cxxPlayer->witchEnd(); }
- (BOOL) witchJumpChecklist:(BOOL)isGalacticJump	{ return _cxxPlayer->witchJumpChecklist(isGalacticJump); }
- (void) setJumpType:(BOOL)isGalacticJump	{ _cxxPlayer->setJumpType(isGalacticJump); }
- (double) hyperspaceJumpDistance	{ return _cxxPlayer->hyperspaceJumpDistance(); }
- (OOFuelQuantity) fuelRequiredForJump	{ return _cxxPlayer->fuelRequiredForJump(); }
- (BOOL) hasSufficientFuelForJump	{ return _cxxPlayer->hasSufficientFuelForJump(); }
- (void) noteCompassLostTarget	{ _cxxPlayer->noteCompassLostTarget(); }
- (void) enterGalacticWitchspace	{ _cxxPlayer->enterGalacticWitchspace(); }
- (void) enterWormhole:(WormholeEntity *) w_hole	{ _cxxPlayer->cxx::PlayerEntity::enterWormhole(w_hole); }
- (void) enterWitchspace	{ _cxxPlayer->cxx::PlayerEntity::enterWitchspace(); }
- (void) witchJumpTo:(OOSystemID)sTo misjump:(BOOL)misjump	{ _cxxPlayer->witchJumpTo(sTo, misjump); }

@end


// Slice 17 of docs/phases/3-slices/PlayerEntity.md (bead oo-6tuef).
@implementation PlayerEntity (OOSlice17)

- (void) leaveWitchspace	{ _cxxPlayer->cxx::PlayerEntity::leaveWitchspace(); }
- (void) setGuiToStatusScreen	{ _cxxPlayer->setGuiToStatusScreen(); }
- (std::vector<oo::PList>) cxx_equipmentList	{ return _cxxPlayer->equipmentList(); }
- (NSUInteger) primedEquipmentCount	{ return _cxxPlayer->primedEquipmentCount(); }
- (std::optional<std::string>) cxx_primedEquipmentName:(NSInteger)offset	{ return _cxxPlayer->primedEquipmentName(offset); }
- (std::string) cxx_currentPrimedEquipment	{ return _cxxPlayer->currentPrimedEquipment(); }
- (BOOL) cxx_setPrimedEquipment:(const std::string &)eqKey showMessage:(BOOL)showMsg	{ return _cxxPlayer->setPrimedEquipment(eqKey, showMsg); }
- (void) activatePrimableEquipment:(NSUInteger)index withMode:(OOPrimedEquipmentMode)mode	{ _cxxPlayer->activatePrimableEquipment(index, mode); }
- (std::optional<std::string>) cxx_fastEquipmentA	{ return _cxxPlayer->fastEquipmentA(); }
- (std::optional<std::string>) cxx_fastEquipmentB	{ return _cxxPlayer->fastEquipmentB(); }
- (void) cxx_setFastEquipmentA:(const std::optional<std::string> &)eqKey	{ _cxxPlayer->setFastEquipmentA(eqKey); }
- (void) cxx_setFastEquipmentB:(const std::optional<std::string> &)eqKey	{ _cxxPlayer->setFastEquipmentB(eqKey); }
- (OOEquipmentType *) weaponTypeForFacing:(OOWeaponFacing)facing strict:(BOOL)strict	{ return _cxxPlayer->cxx::PlayerEntity::weaponTypeForFacing(facing, strict); }

@end


// Slice 18 of docs/phases/3-slices/PlayerEntity.md (bead oo-3fzv5).
@implementation PlayerEntity (OOSlice18)

- (std::vector<oo::ObjCRef<OOEquipmentType *>>) missilesList	{ return _cxxPlayer->cxx::PlayerEntity::missilesList(); }
- (std::vector<std::string>) cxx_cargoList	{ return _cxxPlayer->cargoList(); }
- (oo::PList) cargoListForScripting	{ return _cxxPlayer->cxx::PlayerEntity::cargoListForScripting(); }
- (unsigned) legalStatusOfCargoList	{ return _cxxPlayer->legalStatusOfCargoList(); }
- (oo::PList::Array) contractsListForScriptingFromArray:(const oo::PList::Array &) contracts_array forCargo:(BOOL)forCargo	{ return _cxxPlayer->contractsListForScriptingFromArray(contracts_array, forCargo); }
- (oo::PList) passengerListForScripting	{ return _cxxPlayer->cxx::PlayerEntity::passengerListForScripting(); }
- (oo::PList) parcelListForScripting	{ return _cxxPlayer->cxx::PlayerEntity::parcelListForScripting(); }
- (oo::PList) contractListForScripting	{ return _cxxPlayer->cxx::PlayerEntity::contractListForScripting(); }
- (void) setGuiToSystemDataScreen	{ _cxxPlayer->setGuiToSystemDataScreen(); }
- (void) setGuiToSystemDataScreenRefreshBackground: (BOOL) refreshBackground	{ _cxxPlayer->setGuiToSystemDataScreenRefreshBackground(refreshBackground); }
- (std::optional<std::map<int, std::vector<oo::PList>>>) cxx_markedDestinations	{ return _cxxPlayer->markedDestinations(); }
- (void) setGuiToLongRangeChartScreen	{ _cxxPlayer->setGuiToLongRangeChartScreen(); }
- (void) setGuiToShortRangeChartScreen	{ _cxxPlayer->setGuiToShortRangeChartScreen(); }
- (void) setGuiToChartScreenFrom: (OOGUIScreenID) oldScreen	{ _cxxPlayer->setGuiToChartScreenFrom(oldScreen); }

@end


// Slice 19 of docs/phases/3-slices/PlayerEntity.md (bead oo-4tqku).
@implementation PlayerEntity (OOSlice19)

- (void) setGuiToGameOptionsScreen	{ _cxxPlayer->setGuiToGameOptionsScreen(); }
- (void) setGuiToLoadSaveScreen	{ _cxxPlayer->setGuiToLoadSaveScreen(); }
- (void) highlightEquipShipScreenKey:(const std::string &)highlightKey	{ _cxxPlayer->highlightEquipShipScreenKey(highlightKey); }
- (OOWeaponFacingSet) availableFacings	{ return _cxxPlayer->availableFacings(); }

@end


// Slice 20 of docs/phases/3-slices/PlayerEntity.md (bead oo-dycza).
@implementation PlayerEntity (OOSlice20)

- (void) cxx_setGuiToEquipShipScreen:(int)skipParam selectingFacingFor:(const std::optional<std::string> &)eqKeyForSelectFacing	{ _cxxPlayer->setGuiToEquipShipScreen(skipParam, eqKeyForSelectFacing); }
- (void) setGuiToEquipShipScreen:(int)skip	{ _cxxPlayer->setGuiToEquipShipScreen(skip); }
- (void) showInformationForSelectedUpgrade	{ _cxxPlayer->showInformationForSelectedUpgrade(); }
- (void) cxx_showInformationForSelectedUpgradeWithFormatString:(const std::optional<std::string> &)formatString	{ _cxxPlayer->showInformationForSelectedUpgradeWithFormatString(formatString); }

@end


// Slice 21 of docs/phases/3-slices/PlayerEntity.md (bead oo-a602n).
@implementation PlayerEntity (OOSlice21)

- (void) setGuiToInterfacesScreen:(int)skip	{ _cxxPlayer->setGuiToInterfacesScreen(skip); }
- (void) showInformationForSelectedInterface	{ _cxxPlayer->showInformationForSelectedInterface(); }
- (void) activateSelectedInterface	{ _cxxPlayer->activateSelectedInterface(); }
- (void) setupStartScreenGui	{ _cxxPlayer->setupStartScreenGui(); }
- (void) setGuiToIntroFirstGo:(BOOL)justCobra	{ _cxxPlayer->setGuiToIntroFirstGo(justCobra); }
- (void) setGuiToOXZManager	{ _cxxPlayer->setGuiToOXZManager(); }
- (void) noteGUIWillChangeTo:(OOGUIScreenID)toScreen	{ _cxxPlayer->noteGUIWillChangeTo(toScreen); }
- (void) noteGUIDidChangeFrom:(OOGUIScreenID)fromScreen to:(OOGUIScreenID)toScreen	{ _cxxPlayer->noteGUIDidChangeFrom(fromScreen, toScreen); }
- (void) noteGUIDidChangeFrom:(OOGUIScreenID)fromScreen to:(OOGUIScreenID)toScreen refresh: (BOOL) refresh	{ _cxxPlayer->noteGUIDidChangeFrom(fromScreen, toScreen, refresh); }
- (void) noteViewDidChangeFrom:(OOViewID)fromView toView:(OOViewID)toView	{ _cxxPlayer->noteViewDidChangeFrom(fromView, toView); }

@end


// Slice 22 of docs/phases/3-slices/PlayerEntity.md (bead oo-mv49m).
@implementation PlayerEntity (OOSlice22)

- (void) buySelectedItem	{ _cxxPlayer->buySelectedItem(); }
- (OOCreditsQuantity) cxx_adjustPriceByScriptForEqKey:(const std::string &)eqKey withCurrent:(OOCreditsQuantity)price	{ return _cxxPlayer->adjustPriceByScriptForEqKey(eqKey, price); }
- (BOOL) tryBuyingItem:(const std::string &)eqKey	{ return _cxxPlayer->tryBuyingItem(eqKey); }
- (BOOL) setWeaponMount:(OOWeaponFacing)facing toWeapon:(const std::string &)eqKey	{ return _cxxPlayer->cxx::PlayerEntity::setWeaponMount(facing, eqKey); }
- (BOOL) cxx_setWeaponMount:(OOWeaponFacing)facing toWeapon:(const std::string &)eqKey inContext:(const std::optional<std::string> &) context	{ return _cxxPlayer->cxx::PlayerEntity::setWeaponMount(facing, eqKey, context); }
- (BOOL) changePassengerBerths:(int) addRemove	{ return _cxxPlayer->changePassengerBerths(addRemove); }
- (OOCreditsQuantity) removeMissiles	{ return _cxxPlayer->cxx::PlayerEntity::removeMissiles(); }
- (void) doTradeIn:(OOCreditsQuantity)tradeInValue forPriceFactor:(double)priceFactor	{ _cxxPlayer->doTradeIn(tradeInValue, priceFactor); }

@end


// Slice 23 of docs/phases/3-slices/PlayerEntity.md (bead oo-wt5jv).
@implementation PlayerEntity (OOSlice23)

- (OOCargoQuantity) cxx_cargoQuantityForType:(const std::string &)type	{ return _cxxPlayer->cargoQuantityForType(type); }
- (OOCargoQuantity) cxx_setCargoQuantityForType:(const std::string &)type amount:(OOCargoQuantity)amount	{ return _cxxPlayer->setCargoQuantityForType(type, amount); }
- (void) calculateCurrentCargo	{ _cxxPlayer->calculateCurrentCargo(); }
- (OOCargoQuantity) cargoQuantityOnBoard	{ return _cxxPlayer->cxx::PlayerEntity::cargoQuantityOnBoard(); }
- (OOCommodityMarket *) localMarket	{ return _cxxPlayer->localMarket(); }
- (std::vector<std::string>) cxx_applyMarketFilter:(const std::vector<std::string> &)goods onMarket:(OOCommodityMarket *)market	{ return _cxxPlayer->applyMarketFilter(goods, market); }
- (std::vector<std::string>) cxx_applyMarketSorter:(const std::vector<std::string> &)goods onMarket:(OOCommodityMarket *)market	{ return _cxxPlayer->applyMarketSorter(goods, market); }
- (void) showMarketScreenHeaders	{ _cxxPlayer->showMarketScreenHeaders(); }
- (void) showMarketScreenDataLine:(OOGUIRow)row forGood:(const std::string &)good inMarket:(OOCommodityMarket *)localMarket holdQuantity:(OOCargoQuantity)quantity	{ _cxxPlayer->showMarketScreenDataLine(row, good, localMarket, quantity); }
- (std::optional<std::string>) marketScreenTitle	{ return _cxxPlayer->marketScreenTitle(); }

@end


// Slice 24 of docs/phases/3-slices/PlayerEntity.md (bead oo-bj7u8).
@implementation PlayerEntity (OOSlice24)

- (void) setGuiToMarketScreen	{ _cxxPlayer->setGuiToMarketScreen(); }
- (void) setGuiToMarketInfoScreen	{ _cxxPlayer->setGuiToMarketInfoScreen(); }
- (void) showMarketCashAndLoadLine	{ _cxxPlayer->showMarketCashAndLoadLine(); }
- (OOGUIScreenID) guiScreen	{ return _cxxPlayer->guiScreen(); }
- (BOOL) cxx_tryBuyingCommodity:(const std::string &)index all:(BOOL)all	{ return _cxxPlayer->tryBuyingCommodity(index, all); }
- (BOOL) cxx_trySellingCommodity:(const std::string &)index all:(BOOL)all	{ return _cxxPlayer->trySellingCommodity(index, all); }
- (BOOL) isMining	{ return _cxxPlayer->cxx::PlayerEntity::isMining(); }
- (OOSpeechSettings) isSpeechOn	{ return _cxxPlayer->getIsSpeechOn(); }
- (BOOL) canAddEquipment:(const std::string &)equipmentKey inContext:(const std::string &)context	{ return _cxxPlayer->cxx::PlayerEntity::canAddEquipment(equipmentKey, context); }
- (BOOL) addEquipmentItem:(const std::string &)equipmentKey inContext:(const std::string &)context	{ return _cxxPlayer->cxx::PlayerEntity::addEquipmentItem(equipmentKey, context); }

@end


// Slice 25 of docs/phases/3-slices/PlayerEntity.md (bead oo-hu1xk).
@implementation PlayerEntity (OOSlice25)

- (BOOL) addEquipmentItem:(const std::string &)equipmentKey withValidation:(BOOL)validateAddition inContext:(const std::string &)context	{ return _cxxPlayer->cxx::PlayerEntity::addEquipmentItem(equipmentKey, validateAddition, context); }
- (std::vector<oo::PList> *) cxx_customEquipmentActivation	{ return _cxxPlayer->customEquipmentActivation(); }
- (void) addEquipmentWithScriptToCustomKeyArray:(const std::string &)equipmentKey	{ _cxxPlayer->addEquipmentWithScriptToCustomKeyArray(equipmentKey); }
- (void) validateCustomEquipActivationArray	{ _cxxPlayer->validateCustomEquipActivationArray(); }
- (void) removeEquipmentItem:(const std::string &)equipmentKey	{ _cxxPlayer->cxx::PlayerEntity::removeEquipmentItem(equipmentKey); }
- (void) addEquipmentFromCollection:(const oo::PList &)equipment	{ _cxxPlayer->addEquipmentFromCollection(equipment); }
- (BOOL) hasOneEquipmentItem:(const std::string &)itemKey includeMissiles:(BOOL)includeMissiles	{ return _cxxPlayer->hasOneEquipmentItem(itemKey, includeMissiles); }
- (BOOL) hasPrimaryWeapon:(OOWeaponType)weaponType	{ return _cxxPlayer->cxx::PlayerEntity::hasPrimaryWeapon(weaponType); }
- (BOOL) removeExternalStore:(OOEquipmentType *)eqType	{ return _cxxPlayer->cxx::PlayerEntity::removeExternalStore(eqType); }
- (BOOL) removeFromPylon:(NSUInteger)pylon	{ return _cxxPlayer->removeFromPylon(pylon); }
- (NSUInteger) parcelCount	{ return _cxxPlayer->cxx::PlayerEntity::parcelCount(); }
- (NSUInteger) passengerCount	{ return _cxxPlayer->cxx::PlayerEntity::passengerCount(); }
- (NSUInteger) passengerCapacity	{ return _cxxPlayer->cxx::PlayerEntity::passengerCapacity(); }
- (BOOL) hasHostileTarget	{ return _cxxPlayer->cxx::PlayerEntity::hasHostileTarget(); }
- (void) receiveCommsMessage:(const std::string &) message_text from:(ShipEntity *) other	{ _cxxPlayer->cxx::PlayerEntity::receiveCommsMessage(message_text, other); }
- (void) getFined	{ _cxxPlayer->getFined(); }
- (void) adjustTradeInFactorBy:(int)value	{ _cxxPlayer->adjustTradeInFactorBy(value); }
- (int) tradeInFactor	{ return _cxxPlayer->tradeInFactor(); }
- (double) renovationCosts	{ return _cxxPlayer->renovationCosts(); }
- (double) renovationFactor	{ return _cxxPlayer->renovationFactor(); }
- (void) setDefaultViewOffsets	{ _cxxPlayer->setDefaultViewOffsets(); }
- (void) setDefaultCustomViews	{ _cxxPlayer->setDefaultCustomViews(); }
- (Vector) weaponViewOffset	{ return _cxxPlayer->weaponViewOffset(); }
- (void) setUpTrumbles	{ _cxxPlayer->setUpTrumbles(); }
- (void) addTrumble:(OOTrumble *)papaTrumble	{ _cxxPlayer->addTrumble(papaTrumble); }
- (void) removeTrumble:(OOTrumble *)deadTrumble	{ _cxxPlayer->removeTrumble(deadTrumble); }
- (OOTrumble**) trumbleArray	{ return _cxxPlayer->trumbleArray(); }
- (NSUInteger) trumbleCount	{ return _cxxPlayer->getTrumbleCount(); }

@end


// Slice 26 of docs/phases/3-slices/PlayerEntity.md (bead oo-cpam5).
@implementation PlayerEntity (OOSlice26)

- (oo::PList)trumbleValue	{ return _cxxPlayer->trumbleValue(); }
- (void) setTrumbleValueFrom:(const oo::PList &) trumbleValue	{ _cxxPlayer->setTrumbleValueFrom(trumbleValue); }
- (float) trumbleAppetiteAccumulator	{ return _cxxPlayer->trumbleAppetiteAccumulator(); }
- (void) setTrumbleAppetiteAccumulator:(float)value	{ _cxxPlayer->setTrumbleAppetiteAccumulator(value); }
- (void) mungChecksumWithString:(const std::optional<std::string> &)str	{ _cxxPlayer->mungChecksumWithString(str); }
- (std::optional<std::string>) cxx_screenModeStringForWidth:(unsigned)width height:(unsigned)height refreshRate:(float)refreshRate	{ return _cxxPlayer->screenModeStringForWidth(width, height, refreshRate); }
- (void) suppressTargetLost	{ _cxxPlayer->getSuppressTargetLost(); }
- (void) setScoopsActive	{ _cxxPlayer->setScoopsActive(); }
- (void) setFoundTarget:(Entity *) targetEntity	{ _cxxPlayer->cxx::PlayerEntity::setFoundTarget(targetEntity); }
- (void) addTarget:(Entity *) targetEntity	{ _cxxPlayer->cxx::PlayerEntity::addTarget(targetEntity); }
- (void) clearTargetMemory	{ _cxxPlayer->clearTargetMemory(); }
- (std::vector<oo::ObjCRef<OOWeakReference *>>) cxx_targetMemory	{ return _cxxPlayer->targetMemory(); }
- (BOOL) moveTargetMemoryBy:(NSInteger)delta	{ return _cxxPlayer->moveTargetMemoryBy(delta); }
- (void) printIdentLockedOnForMissile:(BOOL)missile	{ _cxxPlayer->printIdentLockedOnForMissile(missile); }
- (Quaternion) customViewQuaternion	{ return _cxxPlayer->getCustomViewQuaternion(); }
- (void) setCustomViewQuaternion:(Quaternion)q	{ _cxxPlayer->setCustomViewQuaternion(q); }
- (OOMatrix) customViewMatrix	{ return _cxxPlayer->getCustomViewMatrix(); }
- (Vector) customViewOffset	{ return _cxxPlayer->getCustomViewOffset(); }
- (void) setCustomViewOffset:(Vector) offset	{ _cxxPlayer->setCustomViewOffset(offset); }
- (Vector) customViewRotationCenter	{ return _cxxPlayer->getCustomViewRotationCenter(); }
- (void) setCustomViewRotationCenter:(Vector) center	{ _cxxPlayer->setCustomViewRotationCenter(center); }
- (void) customViewZoomIn:(OOScalar) rate	{ _cxxPlayer->customViewZoomIn(rate); }
- (void) customViewZoomOut:(OOScalar) rate	{ _cxxPlayer->customViewZoomOut(rate); }
- (void) customViewRotateLeft:(OOScalar) angle	{ _cxxPlayer->customViewRotateLeft(angle); }
- (void) customViewRotateRight:(OOScalar) angle	{ _cxxPlayer->customViewRotateRight(angle); }
- (void) customViewRotateUp:(OOScalar) angle	{ _cxxPlayer->customViewRotateUp(angle); }
- (void) customViewRotateDown:(OOScalar) angle	{ _cxxPlayer->customViewRotateDown(angle); }
- (void) customViewRollRight:(OOScalar) angle	{ _cxxPlayer->customViewRollRight(angle); }
- (void) customViewRollLeft:(OOScalar) angle	{ _cxxPlayer->customViewRollLeft(angle); }
- (void) customViewPanUp:(OOScalar) angle	{ _cxxPlayer->customViewPanUp(angle); }
- (void) customViewPanDown:(OOScalar) angle	{ _cxxPlayer->customViewPanDown(angle); }

@end


// Slice 27 of docs/phases/3-slices/PlayerEntity.md (bead oo-u1e9m).
@implementation PlayerEntity (OOSlice27)

- (void) customViewPanLeft:(OOScalar) angle	{ _cxxPlayer->customViewPanLeft(angle); }
- (void) customViewPanRight:(OOScalar) angle	{ _cxxPlayer->customViewPanRight(angle); }
- (Vector) customViewForwardVector	{ return _cxxPlayer->getCustomViewForwardVector(); }
- (Vector) customViewUpVector	{ return _cxxPlayer->getCustomViewUpVector(); }
- (Vector) customViewRightVector	{ return _cxxPlayer->getCustomViewRightVector(); }
- (std::optional<std::string>) cxx_customViewDescription	{ return _cxxPlayer->getCustomViewDescription(); }
- (void) resetCustomView	{ _cxxPlayer->resetCustomView(); }
- (void) setCustomViewData	{ _cxxPlayer->setCustomViewData(); }
- (void) cxx_setCustomViewDataFromDictionary:(const oo::PList &)viewDict withScaling:(BOOL)withScaling	{ _cxxPlayer->setCustomViewDataFromDictionary(viewDict, withScaling); }
- (BOOL) showInfoFlag	{ return _cxxPlayer->showInfoFlag(); }
- (oo::PList) cxx_missionOverlayDescriptor	{ return _cxxPlayer->missionOverlayDescriptor(); }
- (oo::PList) cxx_missionOverlayDescriptorOrDefault	{ return _cxxPlayer->missionOverlayDescriptorOrDefault(); }
- (void) cxx_setMissionOverlayDescriptor:(const oo::PList &)descriptor	{ _cxxPlayer->setMissionOverlayDescriptor(descriptor); }
- (oo::PList) cxx_missionBackgroundDescriptor	{ return _cxxPlayer->missionBackgroundDescriptor(); }
- (oo::PList) cxx_missionBackgroundDescriptorOrDefault	{ return _cxxPlayer->missionBackgroundDescriptorOrDefault(); }
- (void) cxx_setMissionBackgroundDescriptor:(const oo::PList &)descriptor	{ _cxxPlayer->setMissionBackgroundDescriptor(descriptor); }
- (OOGUIBackgroundSpecial) missionBackgroundSpecial	{ return _cxxPlayer->missionBackgroundSpecial(); }
- (void) cxx_setMissionBackgroundSpecial:(const std::string &)special	{ _cxxPlayer->setMissionBackgroundSpecial(special); }
- (void) setMissionExitScreen:(OOGUIScreenID)screen	{ _cxxPlayer->setMissionExitScreen(screen); }
- (OOGUIScreenID) missionExitScreen	{ return _cxxPlayer->missionExitScreen(); }
- (oo::PList) cxx_equipScreenBackgroundDescriptor	{ return _cxxPlayer->equipScreenBackgroundDescriptor(); }
- (void) cxx_setEquipScreenBackgroundDescriptor:(const oo::PList &)descriptor	{ _cxxPlayer->setEquipScreenBackgroundDescriptor(descriptor); }
- (BOOL) scriptsLoaded	{ return _cxxPlayer->scriptsLoaded(); }
- (std::vector<std::string>) cxx_worldScriptNames	{ return _cxxPlayer->worldScriptNames(); }
- (std::vector<std::pair<std::string, oo::ObjCRef<OOScript *>>>) cxx_worldScriptsByName	{ return _cxxPlayer->worldScriptsByName(); }
- (OOScript *) cxx_commodityScriptNamed:(const std::optional<std::string> &)scriptName	{ return _cxxPlayer->commodityScriptNamed(scriptName); }
- (void) doScriptEvent:(ooscript::PropertyId)message inContext:(ooscript::Context)context withArguments:(ooscript::Value *)argv count:(unsigned)argc	{ _cxxPlayer->cxx::PlayerEntity::doScriptEvent(message, context, argv, argc); }
- (BOOL) doWorldEventUntilMissionScreen:(ooscript::PropertyId)message	{ return _cxxPlayer->doWorldEventUntilMissionScreen(message); }
- (void) doWorldScriptEvent:(ooscript::PropertyId)message inContext:(ooscript::Context)context withArguments:(ooscript::Value *)argv count:(unsigned)argc timeLimit:(OOTimeDelta)limit	{ _cxxPlayer->doWorldScriptEvent(message, context, argv, argc, limit); }
- (void) setGalacticHyperspaceBehaviour:(OOGalacticHyperspaceBehaviour)inBehaviour	{ _cxxPlayer->setGalacticHyperspaceBehaviour(inBehaviour); }
- (OOGalacticHyperspaceBehaviour) galacticHyperspaceBehaviour	{ return _cxxPlayer->getGalacticHyperspaceBehaviour(); }
- (void) setGalacticHyperspaceFixedCoords:(NSPoint)point	{ _cxxPlayer->setGalacticHyperspaceFixedCoords(point); }
- (void) setGalacticHyperspaceFixedCoordsX:(unsigned char)x y:(unsigned char)y	{ _cxxPlayer->setGalacticHyperspaceFixedCoordsX(x, y); }
- (NSPoint) galacticHyperspaceFixedCoords	{ return _cxxPlayer->getGalacticHyperspaceFixedCoords(); }
- (void) setWitchspaceCountdown:(int)spin_time	{ _cxxPlayer->setWitchspaceCountdown(spin_time); }
- (OOLongRangeChartMode) longRangeChartMode	{ return _cxxPlayer->getLongRangeChartMode(); }
- (void) setLongRangeChartMode:(OOLongRangeChartMode) mode	{ _cxxPlayer->setLongRangeChartMode(mode); }
- (BOOL) scoopOverride	{ return _cxxPlayer->getScoopOverride(); }
- (void) setScoopOverride:(BOOL)newValue	{ _cxxPlayer->setScoopOverride(newValue); }
- (GLfloat) fuelChargeRate	{ return _cxxPlayer->cxx::PlayerEntity::fuelChargeRate(); }
- (void) setDockTarget:(ShipEntity *)entity	{ _cxxPlayer->setDockTarget(entity); }
- (std::optional<std::string>) cxx_jumpCause	{ return _cxxPlayer->jumpCause(); }
- (void) cxx_setJumpCause:(const std::optional<std::string> &)value	{ _cxxPlayer->setJumpCause(value); }
- (std::optional<std::string>) cxx_commanderName	{ return _cxxPlayer->commanderName(); }
- (std::optional<std::string>) cxx_lastsaveName	{ return _cxxPlayer->lastsaveName(); }
- (void) cxx_setCommanderName:(const std::optional<std::string> &)value	{ _cxxPlayer->setCommanderName(value); }
- (void) cxx_setLastsaveName:(const std::optional<std::string> &)value	{ _cxxPlayer->setLastsaveName(value); }

@end


// Slice 28 of docs/phases/3-slices/PlayerEntity.md (bead oo-zn1vy).
@implementation PlayerEntity (OOSlice28)

- (BOOL) isDocked	{ return _cxxPlayer->isDocked(); }
- (BOOL)clearedToDock	{ return _cxxPlayer->clearedToDock(); }
- (void)setDockingClearanceStatus:(OODockingClearanceStatus)newValue	{ _cxxPlayer->setDockingClearanceStatus(newValue); }
- (OODockingClearanceStatus)getDockingClearanceStatus	{ return _cxxPlayer->getDockingClearanceStatus(); }
- (void)penaltyForUnauthorizedDocking	{ _cxxPlayer->penaltyForUnauthorizedDocking(); }
- (void)addScannedWormhole:(WormholeEntity*)whole	{ _cxxPlayer->addScannedWormhole(whole); }
- (void)updateWormholes	{ _cxxPlayer->updateWormholes(); }
- (std::vector<oo::ObjCRef<WormholeEntity *>>) cxx_scannedWormholes	{ return _cxxPlayer->getScannedWormholes(); }
- (void) initialiseMissionDestinations:(const oo::PList &)destinations andLegacy:(const oo::PList &)legacy	{ _cxxPlayer->initialiseMissionDestinations(destinations, legacy); }
- (std::optional<std::string>)markerKey:(const oo::PList &)marker	{ return _cxxPlayer->markerKey(marker); }
- (void) cxx_addMissionDestinationMarker:(const oo::PList &)marker	{ _cxxPlayer->addMissionDestinationMarker(marker); }
- (BOOL) cxx_removeMissionDestinationMarker:(const oo::PList &)marker	{ return _cxxPlayer->removeMissionDestinationMarker(marker); }
- (oo::PList) cxx_getMissionDestinations	{ return _cxxPlayer->getMissionDestinations(); }
- (oo::PList::Dict *) cxx_shipyardRecord	{ return _cxxPlayer->shipyardRecord(); }
- (void) cxx_setLastShot:(const std::vector<oo::Ref<OOLaserShotEntity>> &)shot	{ _cxxPlayer->setLastShot(shot); }
- (void) clearExtraMissionKeys	{ _cxxPlayer->clearExtraMissionKeys(); }
- (void) cxx_setExtraMissionKeys:(const oo::PList &)keys	{ _cxxPlayer->setExtraMissionKeys(keys); }
- (void) cxx_clearExtraGuiScreenKeys:(OOGUIScreenID)gui key:(const std::string &)key	{ _cxxPlayer->clearExtraGuiScreenKeys(gui, key); }
- (BOOL) setExtraGuiScreenKeys:(OOGUIScreenID)gui definition:(OOJSGuiScreenKeyDefinition *)definition	{ return _cxxPlayer->setExtraGuiScreenKeys(gui, definition); }
#ifndef NDEBUG
- (void)dumpSelfState	{ _cxxPlayer->cxx::PlayerEntity::dumpSelfState(); }
#endif

@end


// The category PlayerEntity (ScriptMethods) of PlayerEntityScriptMethods.mm (bead oo-50zg), whose
// members are cxx::PlayerEntity's, defined in that file.
@implementation PlayerEntity (ScriptMethods)

- (unsigned) score	{ return _cxxPlayer->score(); }
- (void) setScore:(unsigned)value	{ _cxxPlayer->setScore(value); }
- (double) creditBalance	{ return _cxxPlayer->creditBalance(); }
- (void) setCreditBalance:(double)value	{ _cxxPlayer->setCreditBalance(value); }
- (std::optional<std::string>) cxx_dockedStationName	{ return _cxxPlayer->dockedStationName(); }
- (std::optional<std::string>) cxx_dockedStationDisplayName	{ return _cxxPlayer->dockedStationDisplayName(); }
- (BOOL) dockedAtMainStation	{ return _cxxPlayer->dockedAtMainStation(); }
- (void) cxx_awardCommodityType:(const std::string &)type amount:(OOCargoQuantity)amount	{ _cxxPlayer->awardCommodityType(type, amount); }
- (void) resetScannerZoom	{ _cxxPlayer->resetScannerZoom(); }
- (OOGalaxyID) currentGalaxyID	{ return _cxxPlayer->currentGalaxyID(); }
- (OOSystemID) currentSystemID	{ return _cxxPlayer->currentSystemID(); }
- (void) cxx_setMissionChoice:(const std::optional<std::string> &)newChoice	{ _cxxPlayer->setMissionChoice(newChoice); }
- (void) cxx_setMissionChoice:(const std::optional<std::string> &)newChoice withEvent:(BOOL)withEvent	{ _cxxPlayer->setMissionChoice(newChoice, withEvent); }
- (void) cxx_setMissionChoice:(const std::optional<std::string> &)newChoice keyPress:(const std::optional<std::string> &)keyPress	{ _cxxPlayer->setMissionChoice(newChoice, keyPress); }
- (void) cxx_setMissionChoice:(const std::optional<std::string> &)newChoice keyPress:(const std::optional<std::string> &)keyPress withEvent:(BOOL)withEvent	{ _cxxPlayer->setMissionChoice(newChoice, keyPress, withEvent); }
- (void) allowMissionInterrupt	{ _cxxPlayer->allowMissionInterrupt(); }
- (OOTimeDelta) scriptTimer	{ return _cxxPlayer->scriptTimer(); }
- (unsigned) systemPseudoRandom100	{ return _cxxPlayer->systemPseudoRandom100(); }
- (unsigned) systemPseudoRandom256	{ return _cxxPlayer->systemPseudoRandom256(); }
- (double) systemPseudoRandomFloat	{ return _cxxPlayer->systemPseudoRandomFloat(); }
- (oo::PList) cxx_passengerContractMarker:(OOSystemID)system	{ return _cxxPlayer->passengerContractMarker(system); }
- (oo::PList) cxx_parcelContractMarker:(OOSystemID)system	{ return _cxxPlayer->parcelContractMarker(system); }
- (oo::PList) cxx_cargoContractMarker:(OOSystemID)system	{ return _cxxPlayer->cargoContractMarker(system); }
- (oo::PList) cxx_defaultMarker:(OOSystemID)system	{ return _cxxPlayer->defaultMarker(system); }
- (oo::PList) cxx_validatedMarker:(const oo::PList &)marker	{ return _cxxPlayer->validatedMarker(marker); }
- (std::optional<std::string>) cxx_keyBindingDescription2:(const std::string &)binding	{ return _cxxPlayer->keyBindingDescription2(binding); }
- (std::optional<std::string>) cxx_getKeyBindingDescription:(const oo::PList &)keyList	{ return _cxxPlayer->getKeyBindingDescription(keyList); }
- (std::optional<std::string>) cxx_keyCodeDescription:(OOKeyCode)code	{ return _cxxPlayer->keyCodeDescription(code); }
- (std::optional<std::string>) cxx_keyCodeDescriptionShort:(OOKeyCode)code	{ return _cxxPlayer->keyCodeDescriptionShort(code); }
- (std::optional<std::string>) cxx_commanderKillsAsString	{ return _cxxPlayer->commanderKillsAsString(); }
- (std::optional<std::string>) cxx_commanderBountyAsString	{ return _cxxPlayer->commanderBountyAsString(); }
- (std::optional<std::string>) cxx_creditsFormattedForSubstitution	{ return _cxxPlayer->creditsFormattedForSubstitution(); }
- (std::optional<std::string>) cxx_creditsFormattedForLegacySubstitution	{ return _cxxPlayer->creditsFormattedForLegacySubstitution(); }

// OOStringExpander's special substitution table sends these by name (ADR-0043 item 21).
- (oo::PList) commanderKillsAsString	{ const auto result = _cxxPlayer->commanderKillsAsString(); return result.has_value() ? oo::PList(*result) : oo::PList(); }
- (oo::PList) commanderBountyAsString	{ const auto result = _cxxPlayer->commanderBountyAsString(); return result.has_value() ? oo::PList(*result) : oo::PList(); }
- (oo::PList) creditsFormattedForSubstitution	{ const auto result = _cxxPlayer->creditsFormattedForSubstitution(); return result.has_value() ? oo::PList(*result) : oo::PList(); }
- (oo::PList) creditsFormattedForLegacySubstitution	{ const auto result = _cxxPlayer->creditsFormattedForLegacySubstitution(); return result.has_value() ? oo::PList(*result) : oo::PList(); }

@end
