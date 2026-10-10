/*

ShipEntity+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, amendments oo-bj8 and oo-60fwo): the Objective-C ShipEntity
facade (see ShipEntity+ObjCBridge.h). The class's primary @implementation is here, empty: every
method has moved into cxx::ShipEntity (slices 1-34, umbrella bead oo-k8a) and the facade's methods
are its categories below. Its initialisers and -dealloc are a category because they need the
Objective-C object as self (amendment oo-bj8 items 6 and 7), and so are the two
SubEntityRelationship categories (item 12). Deleted with ShipEntity+ObjCBridge.h.

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

#import "ShipEntity.h"
#import "ShipEntityAI.h"
#import "ShipEntityScriptMethods.h"
#import "AI.h"
#import "PlayerEntity.h"
#import "ProxyPlayerEntity.h"
#import "StationEntity.h"
#import "GameController.h"	// OOScheduleDeferredCall (the player's selectors called by name)
#import "OORoleSet.h"
#import "OOShipGroup.h"
#import "OOWeakSet.h"
#import "Octree.h"
#import "OOColor.h"
#import "OOJSScript.h"
#import "OOJSEngineTimeManagement.h"
#import "OODescription.h"
#include "oofnd/Log.hpp"
#include "oofnd/objc/OOAssert.h"
#import "ShipEntity+ObjCAdapter.h"

#include "oofnd/objc/OORuntime.h"
#include <objc/runtime.h>

#include <cmath>
#include <string>
#include <unordered_set>


/*	A forwarder of a member a subclass overrides. An Objective-C ship's C++ part is the ship's adapter
	(ShipEntity+ObjCAdapter.h), whose override sends the selector back to the Objective-C object, so
	the facade calls cxx::ShipEntity's own member, which is what [super ...] reached. Any other C++
	part is a ship made in C++ (the player since bead oo-9ht.177, ADR-0056 amendment oo-9ht.177),
	whose own override is what the deleted subclass facade answered: the call is virtual.
*/
#define SHIP_PART(call)	(oo::AsObjCEntity(_cxxEntity.get()) != nullptr ? _cxxShip->cxx::ShipEntity::call : _cxxShip->call)


namespace {

// A station's part (bead oo-9ht.175): its facade, a subclass of this one, answered the selectors the
// categories below answer for a station; nullptr for any other ship. The categories that otherwise
// call the ship's member pass the root's _cxxEntity, so the analyser does not read a null answer as
// a null _cxxShip.
StationEntity *StationPart(cxx::Entity *entity)
{
	return dynamic_cast<StationEntity *>(entity);
}


// The selectors of the category ShipEntity (OOStationSelectorsCalledByName) below.
bool IsStationSelectorCalledByName(SEL selector)
{
	static const std::unordered_set<std::string> names =
	{
		"equivalentTechLevel",
		"virtualPortDimensions",
		"playerReservedDock",
		"beaconPosition",
		"equipmentPriceFactor",
		"marketCapacity",
		"cxx_marketDefinition",
		"marketMonitored",
		"marketBroadcast",
		"cxx_setLocalMarket:",
		"cxx_localMarketForScripting",
		"countOfDockedContractors",
		"countOfDockedPolice",
		"countOfDockedDefenders",
		"interstellarUndockingAllowed",
		"hasNPCTraffic",
		"requiresDockingClearance",
		"allowsFastDocking",
		"allowsAutoDocking",
		"allowsSaving",
		"isRotatingStation",
		"hasShipyard",
		"generateShipyard",
		"suppressArrivalReports",
		"hasBreakPattern",
		"sanityCheckShipsOnApproach",
		"autoDockShipsOnHold",
		"autoDockShipsOnApproach",
		"dockingCorridorIsEmpty",
		"clearDockingCorridor",
		"clear",
		"hasMultipleDocks",
		"hasClearDock",
		"hasEligibleDock",
		"hasLaunchDock",
		"selectDockForDocking",
		"countOfShipsInLaunchQueueWithPrimaryRole:",
		"alertLevel",
		"currentlyInDockingQueues",
		"currentlyInLaunchingQueues",
		"launchIndependentShip:",
	};
	return names.contains(sel_getName(selector));
}

}	// namespace


@interface ShipEntity (OOShipMadeInCxx)

- (id) cxx_initWithShipPart:(cxx::ShipEntity *)ship key:(const std::string &)key definition:(const oo::PList &)dict OO_RETURNS_RETAINED;
- (id) initShipSetUpWithKey:(const std::string &)key definition:(const oo::PList &)dict;

@end


::ShipEntity *oo::NewShipObject(const Ref<cxx::ShipEntity> &ship, const std::string &key, const oo::PList &dict)
{
	if (ship == nullptr)  return nil;
	OOCParameterAssert(AsObjCEntity(ship.get()) == nullptr);
	return [[::ShipEntity alloc] cxx_initWithShipPart:ship.get() key:key definition:dict];
}


@implementation ShipEntity
@end


@implementation ShipEntity (OOObjCBridge)

- (id) init
{
	/*	-init used to set up a bunch of defaults that were different from
		those in -reinit and -setUpShipFromDictionary:. However, it seems that
		no ships are ever used which are not -setUpShipFromDictionary: (which
		is as it should be), so these different defaults were meaningless.
	*/
	return [self cxx_initWithKey:std::string{} definition:oo::PList()];
}


- (id) initBypassForPlayer
{
	return [self initShipPart];	// [super init]
}


- (id)cxx_initWithKey:(const std::string &)key definition:(const oo::PList &)dict
{
	return [[self initShipPart] initShipSetUpWithKey:key definition:dict];	// [super init], then the body
}


// -cxx_initWithKey:definition: of a ship made in C++ (oo::NewShipObject, bead oo-9ht.183): the part
// it was made with, stored once, then the same body.
- (id) cxx_initWithShipPart:(cxx::ShipEntity *)ship key:(const std::string &)key definition:(const oo::PList &)dict
{
	return [[self initWithCxxEntity:ship] initShipSetUpWithKey:key definition:dict];
}


// -cxx_initWithKey:definition:'s body after [super init] (moved here by bead oo-9ht.183, unchanged).
- (id) initShipSetUpWithKey:(const std::string &)key definition:(const oo::PList &)dict
{
	OOJS_PROFILE_ENTER

	if (self == nil)  return nil;

	_cxxShip->initWithKey(key);

	if (![self setUpShipFromDictionary:dict])
	{
		[self release];
		self = nil;
	}

	// Problem observed in testing -- Ahruman
	if (self != nil && !isfinite(_cxxShip->maxFlightSpeed))
	{
		OO_LOG("ship.sanityCheck.failed", "Ship {} {} infinite top speed, clamped to 300.", oo::DescriptionOf(self), "generated with");
		_cxxShip->maxFlightSpeed = 300;
	}
	return self;

	OOJS_PROFILE_EXIT
}


/*	What [super init] did in the two initialisers, with the ship's adapter: an Objective-C ship, of
	this class or a subclass, has a C++ part over cxx::ShipEntity (amendment oo-bj8 item 5), as
	OOEntityWithDrawable's -init makes one over its class.
*/
- (id) initShipPart
{
	// -init sent again to an initialised ship keeps its C++ part (the root's -initWithCxxEntity:).
	if (_cxxEntity != nullptr)  return [self initWithCxxEntity:_cxxEntity.get()];
	return [self initWithCxxEntity:oo::makeRef<oo::ObjCShipEntity<cxx::ShipEntity>>(self).get()];
}


// The root's designated initialiser, which also sets the typed alias of the part it stores.
- (id) initWithCxxEntity:(cxx::Entity *)entity
{
	self = [super initWithCxxEntity:entity];
	if (EXPECT_NOT(self == nil))  return nil;

	_cxxShip = dynamic_cast<cxx::ShipEntity *>(_cxxEntity.get());
	OOCParameterAssert(_cxxShip != nullptr);
	return self;
}


- (void) dealloc
{
	/*	Released before its initialiser ran (a failing initialiser's [self release]; return nil;):
		there is no C++ part, as in the root's -dealloc (oo-s6ic6).
	*/
	if (_cxxShip == nullptr)
	{
		[super dealloc];
		return;
	}

	// The player's -dealloc ran first (its facade was a subclass of this one; bead oo-9ht.177), and
	// so did a station's (bead oo-9ht.175).
	if (PlayerEntity *player = dynamic_cast<PlayerEntity *>(_cxxShip))  player->willDealloc();
	if (StationEntity *station = StationPart(_cxxShip))  station->willDealloc();

	/*	NOTE: we guarantee that entityDestroyed is sent immediately after the
		JS ship becomes invalid (as a result of dropping the weakref), i.e.
		with no intervening script activity.
		It has to be after the invalidation so that scripts can't directly or
		indirectly cause the ship to become strong-referenced. (Actually, we
		could handle that situation by breaking out of dealloc, but that's a
		nasty abuse of framework semantics and would require special-casing in
		subclasses.)
		-- Ahruman 2011-02-27
	*/
	[weakSelf weakRefDrop];
	weakSelf = nil;
	ShipScriptEventNoCx(self, "entityDestroyed");

	[self setTrackCloseContacts:NO];	// deallocs tracking dictionary
	[[self parentEntity] subEntityReallyDied:self];	// Will do nothing if we're not really a subentity
	[self clearSubEntities];

DESTROY(_cxxShip->shipAI);
	_cxxShip->roleSet = nullptr;
_cxxShip->laser_color = nullptr;
	_cxxShip->default_laser_color = nullptr;
	_cxxShip->exhaust_emissive_color = nullptr;
	_cxxShip->scanner_display_color1 = nullptr;
	_cxxShip->scanner_display_color2 = nullptr;
	_cxxShip->scanner_display_color_hostile1 = nullptr;
	_cxxShip->scanner_display_color_hostile2 = nullptr;
	_cxxShip->script = nullptr;
	_cxxShip->aiScript = nullptr;
	_cxxShip->octree = nullptr;
	_cxxShip->_defenseTargets = nullptr;
	_cxxShip->_collisionExceptions = nullptr;

	[self setSubEntityTakingDamage:nil];
	[self removeAllEquipment];

	if (_cxxShip->_group != nullptr)  _cxxShip->_group->removeShip(self);
	_cxxShip->_group = nullptr;
	if (_cxxShip->_escortGroup != nullptr)  _cxxShip->_escortGroup->removeShip(self);
	_cxxShip->_escortGroup = nullptr;

	DESTROY(_cxxShip->_lastAegisLock);

	_cxxShip->_beaconDrawable = nullptr;


	[super dealloc];
}

@end


double ShipEntityStellarBodyRadius(Entity<OOStellarBody> *stellar)	{ return OOStellarBodyRadius(stellar); }	// the sun is C++ since bead oo-9ht.111
GLfloat ShipEntityPlayerBaseMass(void)	{ return PLAYER != nullptr ? PLAYER->baseMass() : 0.0f; }


@implementation Entity (SubEntityRelationship)

- (BOOL) isShipWithSubEntityShip:(Entity *)other
{
	return NO;
}


- (void) drawSubEntityImmediate:(bool)immediate translucent:(bool)translucent
{
	// Do nothing.
}

@end


@implementation ShipEntity (SubEntityRelationship)

- (BOOL) isShipWithSubEntityShip:(Entity *)other	{ return oo::ToCxx(self)->isShipWithSubEntityShip(other); }

@end


@implementation ShipEntity (OOSlice2)

- (BOOL) cxx_setUpFromDictionary:(const oo::PList &)inShipDict	{ return _cxxShip->setUpFromDictionary(inShipDict); }

@end


@implementation ShipEntity (OOSlice3)

- (BOOL) setUpShipFromDictionary:(const oo::PList &)shipDict	{ return SHIP_PART(setUpShipFromDictionary(shipDict)); }
- (void) setSubIdx:(NSUInteger)value	{ _cxxShip->setSubIdx(value); }
- (NSUInteger) subIdx	{ return _cxxShip->subIdx(); }
- (NSUInteger) maxShipSubEntities	{ return _cxxShip->maxShipSubEntities(); }
- (std::optional<std::string>) cxx_serializeShipSubEntities	{ return _cxxShip->serializeShipSubEntities(); }
- (void) cxx_deserializeShipSubEntitiesFrom:(const std::string &)string	{ _cxxShip->deserializeShipSubEntitiesFrom(string); }
- (BOOL) setUpSubEntities	{ return SHIP_PART(setUpSubEntities()); }
- (GLfloat) frustumRadius	{ return SHIP_PART(frustumRadius()); }
- (BOOL) setUpOneSubentity:(const oo::PList &)subentDict	{ return _cxxShip->setUpOneSubentity(subentDict); }
- (BOOL) setUpOneFlasher:(const oo::PList &)subentDict	{ return _cxxShip->setUpOneFlasher(subentDict); }

@end


@implementation ShipEntity (OOSlice4)

- (BOOL) cxx_setUpOneStandardSubentity:(const oo::PList &)subentDict asTurret:(BOOL)asTurret	{ return _cxxShip->setUpOneStandardSubentity(subentDict, asTurret); }
- (BOOL) isTemplateCargoPod	{ return _cxxShip->isTemplateCargoPod(); }
- (void) setUpCargoType:(const std::string &)cargoString	{ _cxxShip->setUpCargoType(cargoString); }
- (void) removeScript	{ _cxxShip->removeScript(); }
- (void) clearSubEntities	{ _cxxShip->clearSubEntities(); }
- (Quaternion) subEntityRotationalVelocity	{ return _cxxShip->subEntityRotationalVelocity(); }
- (void) setSubEntityRotationalVelocity:(Quaternion)rv	{ _cxxShip->setSubEntityRotationalVelocity(rv); }
- (std::optional<std::string>) cxx_shortDescriptionComponents	{ return _cxxShip->shortDescriptionComponents(); }
- (GLfloat) sunGlareFilter	{ return _cxxShip->getSunGlareFilter(); }
- (void) setSunGlareFilter:(GLfloat)newValue	{ _cxxShip->setSunGlareFilter(newValue); }
- (GLfloat) accuracy	{ return _cxxShip->getAccuracy(); }
- (void) setAccuracy:(GLfloat)new_accuracy	{ _cxxShip->setAccuracy(new_accuracy); }
- (OOMesh *) mesh	{ return _cxxShip->mesh(); }
- (void) setMesh:(OOMesh *)mesh	{ _cxxShip->setMesh(mesh); }
- (BoundingBox) totalBoundingBox	{ return _cxxShip->getTotalBoundingBox(); }
- (Vector) forwardVector	{ return _cxxShip->forwardVector(); }
- (Vector) upVector	{ return _cxxShip->upVector(); }
- (Vector) rightVector	{ return _cxxShip->rightVector(); }
- (BOOL) scriptedMisjump	{ return _cxxShip->scriptedMisjump(); }
- (void) setScriptedMisjump:(BOOL)newValue	{ _cxxShip->setScriptedMisjump(newValue); }
- (GLfloat) scriptedMisjumpRange	{ return _cxxShip->scriptedMisjumpRange(); }
- (void) setScriptedMisjumpRange:(GLfloat)newValue	{ _cxxShip->setScriptedMisjumpRange(newValue); }
- (std::vector<oo::ObjCRef<Entity *>>) subEntities	{ return _cxxShip->getSubEntities(); }
- (NSUInteger) subEntityCount	{ return _cxxShip->subEntityCount(); }
- (BOOL) hasSubEntity:(Entity<OOSubEntity> *)sub	{ return _cxxShip->hasSubEntity(sub); }
- (std::vector<oo::ObjCRef<Entity *>>) subEntityEnumerator	{ return _cxxShip->subEntityEnumerator(); }
- (std::vector<oo::ObjCRef<ShipEntity *>>) cxx_shipSubEntities	{ return _cxxShip->shipSubEntities(); }
- (std::vector<oo::ObjCRef<Entity *>>) flasherEnumerator	{ return _cxxShip->flasherEnumerator(); }
- (std::vector<oo::ObjCRef<Entity *>>) cxx_exhausts	{ return _cxxShip->exhausts(); }
- (ShipEntity *) subEntityTakingDamage	{ return _cxxShip->subEntityTakingDamage(); }
- (void) setSubEntityTakingDamage:(ShipEntity *)sub	{ _cxxShip->setSubEntityTakingDamage(sub); }
- (OOScript *) shipScript	{ return _cxxShip->shipScript(); }
- (OOScript *) shipAIScript	{ return _cxxShip->shipAIScript(); }
- (OOTimeAbsolute) shipAIScriptWakeTime	{ return _cxxShip->shipAIScriptWakeTime(); }
- (void) setAIScriptWakeTime:(OOTimeAbsolute)t	{ _cxxShip->setAIScriptWakeTime(t); }
- (std::optional<std::string>) cxx_descriptionComponents	{ return SHIP_PART(descriptionComponents()); }

@end


@implementation ShipEntity (OOSlice5)

- (BoundingBox) findBoundingBoxRelativeToPosition:(HPVector)opv InVectors:(Vector)_i :(Vector)_j :(Vector)_k	{ return _cxxShip->findBoundingBoxRelativeToPosition(opv, _i, _j, _k); }
- (float) volume	{ return _cxxShip->volume(); }
- (GLfloat) doesHitLine:(HPVector)v0 :(HPVector)v1	{ return _cxxShip->doesHitLine(v0, v1); }
- (GLfloat) doesHitLine:(HPVector)v0 :(HPVector)v1 :(ShipEntity **)hitEntity	{ return SHIP_PART(doesHitLine(v0, v1, hitEntity)); }
- (GLfloat) doesHitLine:(HPVector)v0 :(HPVector)v1 withPosition:(HPVector)o andIJK:(Vector)i :(Vector)j :(Vector)k	{ return _cxxShip->doesHitLine(v0, v1, o, i, j, k); }
- (void) wasAddedToUniverse	{ SHIP_PART(wasAddedToUniverse()); }
- (void) wasRemovedFromUniverse	{ SHIP_PART(wasRemovedFromUniverse()); }
- (HPVector) absoluteTractorPosition	{ return _cxxShip->absoluteTractorPosition(); }
- (std::optional<std::string>) beaconCode	{ return _cxxShip->beaconCode(); }
- (void) setBeaconCode:(const std::optional<std::string> &)bcode	{ _cxxShip->setBeaconCode(bcode); }
- (std::optional<std::string>) beaconLabel	{ return _cxxShip->beaconLabel(); }
- (void) setBeaconLabel:(const std::optional<std::string> &)blabel	{ _cxxShip->setBeaconLabel(blabel); }
- (BOOL) isVisible	{ return SHIP_PART(isVisible()); }
- (BOOL) isBeacon	{ return _cxxShip->isBeacon(); }
- (OOHUDBeaconIcon *) beaconDrawable	{ return _cxxShip->beaconDrawable(); }
- (Entity <OOBeaconEntity> *) prevBeacon	{ return (Entity <OOBeaconEntity> *)_cxxShip->prevBeacon(); }
- (Entity <OOBeaconEntity> *) nextBeacon	{ return (Entity <OOBeaconEntity> *)_cxxShip->nextBeacon(); }
- (void) setPrevBeacon:(Entity <OOBeaconEntity> *)beaconShip	{ _cxxShip->setPrevBeacon(beaconShip); }
- (void) setNextBeacon:(Entity <OOBeaconEntity> *)beaconShip	{ _cxxShip->setNextBeacon(beaconShip); }
- (void) setIsBoulder:(BOOL)flag	{ _cxxShip->setIsBoulder(flag); }
- (BOOL) isBoulder	{ return _cxxShip->isBoulder(); }
- (BOOL) isMinable	{ return _cxxShip->isMinable(); }
- (BOOL) countsAsKill	{ return _cxxShip->countsAsKill(); }
- (void) setUpEscorts	{ _cxxShip->setUpEscorts(); }
- (void) setUpMixedEscorts	{ _cxxShip->setUpMixedEscorts(); }

@end


@implementation ShipEntity (OOSlice6)

- (void) setUpOneEscort:(ShipEntity *)escorter inGroup:(OOShipGroup *)escortGroup withRole:(const std::string &)escortRole atPosition:(HPVector)ex_pos andCount:(uint8_t)currentEscortCount	{ _cxxShip->setUpOneEscort(escorter, escortGroup, escortRole, ex_pos, currentEscortCount); }
- (std::optional<std::string>) cxx_shipDataKey	{ return _cxxShip->shipDataKey(); }
- (std::optional<std::string>) cxx_shipDataKeyAutoRole	{ return _cxxShip->shipDataKeyAutoRole(); }
- (void) cxx_setShipDataKey:(const std::optional<std::string> &)key	{ _cxxShip->setShipDataKey(key); }
- (oo::PList) cxx_shipInfoDictionary	{ return _cxxShip->shipInfoDictionary(); }
- (std::vector<Vector>) cxx_weaponOffsetsFrom:(const oo::PList &)dict withKey:(const std::string &)key inMode:(const std::string &)mode	{ return _cxxShip->weaponOffsetsFrom(dict, key, mode); }
- (std::vector<Vector>) cxx_aftWeaponOffset	{ return _cxxShip->getAftWeaponOffset(); }
- (std::vector<Vector>) cxx_forwardWeaponOffset	{ return _cxxShip->getForwardWeaponOffset(); }
- (std::vector<Vector>) cxx_portWeaponOffset	{ return _cxxShip->getPortWeaponOffset(); }
- (std::vector<Vector>) cxx_starboardWeaponOffset	{ return _cxxShip->getStarboardWeaponOffset(); }
- (BOOL) isFrangible	{ return _cxxShip->getIsFrangible(); }
- (BOOL) suppressFlightNotifications	{ return _cxxShip->suppressFlightNotifications(); }
- (OOScanClass) scanClass	{ return SHIP_PART(getScanClass()); }
- (BOOL) canCollide	{ return SHIP_PART(canCollide()); }
- (BOOL) checkCloseCollisionWith:(Entity *)other	{ return SHIP_PART(checkCloseCollisionWith(oo::ToCxx(other))); }
- (BoundingBox) findSubentityBoundingBox	{ return _cxxShip->findSubentityBoundingBox(); }
- (Triangle) absoluteIJKForSubentity	{ return _cxxShip->absoluteIJKForSubentity(); }
- (void) addSubentityToCollisionRadius:(Entity<OOSubEntity> *)subent	{ _cxxShip->addSubentityToCollisionRadius(subent); }
- (ShipEntity *) launchPodWithCrew:(const std::vector<oo::Ref<OOCharacter>> &)podCrew	{ return _cxxShip->launchPodWithCrew(podCrew); }
- (BOOL) validForAddToUniverse	{ return SHIP_PART(validForAddToUniverse()); }

@end


@implementation ShipEntity (OOSlice7)

- (void) update:(OOTimeDelta)delta_t	{ SHIP_PART(update(delta_t)); }

@end


@implementation ShipEntity (OOSlice8)

- (void) processBehaviour:(OOTimeDelta)delta_t	{ _cxxShip->processBehaviour(delta_t); }
- (void) noteFrustration:(const std::string &)context	{ _cxxShip->noteFrustration(context); }
- (void) respondToAttackFrom:(Entity *)from becauseOf:(Entity *)other	{ _cxxShip->respondToAttackFrom(from, other); }
- (BOOL) cxx_hasOneEquipmentItem:(const std::string &)itemKey includeWeapons:(BOOL)includeWeapons whileLoading:(BOOL)loading	{ return _cxxShip->hasOneEquipmentItem(itemKey, includeWeapons, loading); }
- (BOOL) cxx_hasOneEquipmentItem:(const std::string &)itemKey includeMissiles:(BOOL)includeMissiles whileLoading:(BOOL)loading	{ return _cxxShip->hasOneEquipmentItemIncludingMissiles(itemKey, includeMissiles, loading); }
- (BOOL) hasPrimaryWeapon:(OOWeaponType)weaponType	{ return SHIP_PART(hasPrimaryWeapon(weaponType)); }
- (NSUInteger) cxx_countEquipmentItem:(const std::string &)eqkey	{ return _cxxShip->countEquipmentItem(eqkey); }
- (BOOL) hasEquipmentItem:(const oo::PList &)equipmentKeys includeWeapons:(BOOL)includeWeapons whileLoading:(BOOL)loading	{ return _cxxShip->hasEquipmentItem(equipmentKeys, includeWeapons, loading); }
- (BOOL) hasEquipmentItem:(const oo::PList &)equipmentKeys	{ return _cxxShip->hasEquipmentItem(equipmentKeys); }
- (BOOL) cxx_hasEquipmentItemProviding:(const std::string &)equipmentType	{ return _cxxShip->hasEquipmentItemProviding(equipmentType); }
- (std::optional<std::string>) cxx_equipmentItemProviding:(const std::string &)equipmentType	{ return _cxxShip->equipmentItemProviding(equipmentType); }
- (BOOL) hasAllEquipment:(const oo::PList &)equipmentKeys includeWeapons:(BOOL)includeWeapons whileLoading:(BOOL)loading	{ return _cxxShip->hasAllEquipment(equipmentKeys, includeWeapons, loading); }
- (BOOL) hasAllEquipment:(const oo::PList &)equipmentKeys	{ return _cxxShip->hasAllEquipment(equipmentKeys); }
- (BOOL) hasHyperspaceMotor	{ return _cxxShip->hasHyperspaceMotor(); }
- (float) hyperspaceSpinTime	{ return _cxxShip->hyperspaceSpinTime(); }
- (void) setHyperspaceSpinTime:(float)newValue	{ _cxxShip->setHyperspaceSpinTime(newValue); }

@end


@implementation ShipEntity (OOSlice9)

- (BOOL) canAddEquipment:(const std::string &)equipmentKeyIn inContext:(const std::string &)context	{ return SHIP_PART(canAddEquipment(equipmentKeyIn, context)); }
- (OOWeaponFacingSet) weaponFacings	{ return _cxxShip->weaponFacings(); }
- (OOWeaponType) weaponTypeIDForFacing:(OOWeaponFacing)facing strict:(BOOL)strict	{ return _cxxShip->weaponTypeIDForFacing(facing, strict); }
- (OOEquipmentType *) weaponTypeForFacing:(OOWeaponFacing)facing strict:(BOOL)strict	{ return SHIP_PART(weaponTypeForFacing(facing, strict)); }
- (std::vector<oo::Ref<OOEquipmentType>>) missilesList	{ return SHIP_PART(missilesList()); }
- (oo::PList) passengerListForScripting	{ return SHIP_PART(passengerListForScripting()); }
- (oo::PList) parcelListForScripting	{ return SHIP_PART(parcelListForScripting()); }
- (oo::PList) contractListForScripting	{ return SHIP_PART(contractListForScripting()); }
- (OOEquipmentType *) generateMissileEquipmentTypeFrom:(const std::string &)role	{ return _cxxShip->generateMissileEquipmentTypeFrom(role); }
- (std::vector<oo::Ref<OOEquipmentType>>) cxx_equipmentListForScripting	{ return _cxxShip->equipmentListForScripting(); }
- (BOOL) cxx_equipmentValidToAdd:(const std::string &)equipmentKey inContext:(const std::string &)context	{ return _cxxShip->equipmentValidToAdd(equipmentKey, context); }
- (BOOL) cxx_equipmentValidToAdd:(const std::string &)fullEquipmentKey whileLoading:(BOOL)loading inContext:(const std::string &)context	{ return _cxxShip->equipmentValidToAdd(fullEquipmentKey, loading, context); }
- (BOOL) setWeaponMount:(OOWeaponFacing)facing toWeapon:(const std::string &)eqKey	{ return SHIP_PART(setWeaponMount(facing, eqKey)); }
- (BOOL) addEquipmentItem:(const std::string &)equipmentKey inContext:(const std::string &)context	{ return SHIP_PART(addEquipmentItem(equipmentKey, context)); }
- (BOOL) addEquipmentItem:(const std::string &)equipmentKeyIn withValidation:(BOOL)validateAddition inContext:(const std::string &)context	{ return SHIP_PART(addEquipmentItem(equipmentKeyIn, validateAddition, context)); }
- (std::vector<std::string>) cxx_equipmentKeys	{ return _cxxShip->equipmentKeys(); }
- (NSUInteger) equipmentCount	{ return _cxxShip->equipmentCount(); }

@end


@implementation ShipEntity (OOSlice10)

- (void) removeEquipmentItem:(const std::string &)equipmentKey	{ SHIP_PART(removeEquipmentItem(equipmentKey)); }
- (BOOL) removeExternalStore:(OOEquipmentType *)eqType	{ return SHIP_PART(removeExternalStore(eqType)); }
- (OOEquipmentType *) verifiedMissileTypeFromRole:(const std::string &)requestedRole	{ return _cxxShip->verifiedMissileTypeFromRole(requestedRole); }
- (OOEquipmentType *) selectMissile	{ return _cxxShip->selectMissile(); }
- (void) removeAllEquipment	{ _cxxShip->removeAllEquipment(); }
- (OOCreditsQuantity) removeMissiles	{ return SHIP_PART(removeMissiles()); }
- (NSUInteger) parcelCount	{ return SHIP_PART(parcelCount()); }
- (NSUInteger) passengerCount	{ return SHIP_PART(passengerCount()); }
- (NSUInteger) passengerCapacity	{ return SHIP_PART(passengerCapacity()); }
- (NSUInteger) missileCount	{ return _cxxShip->missileCount(); }
- (NSUInteger) missileCapacity	{ return _cxxShip->missileCapacity(); }
- (NSUInteger) extraCargo	{ return _cxxShip->extraCargo(); }
- (BOOL) hasScoop	{ return _cxxShip->hasScoop(); }
- (BOOL) hasFuelScoop	{ return _cxxShip->hasFuelScoop(); }
- (BOOL) hasCargoScoop	{ return _cxxShip->hasCargoScoop(); }
- (BOOL) hasECM	{ return _cxxShip->hasECM(); }
- (BOOL) hasCloakingDevice	{ return _cxxShip->hasCloakingDevice(); }
- (BOOL) hasMilitaryScannerFilter	{ return _cxxShip->hasMilitaryScannerFilter(); }
- (BOOL) hasMilitaryJammer	{ return _cxxShip->hasMilitaryJammer(); }
- (BOOL) hasExpandedCargoBay	{ return _cxxShip->hasExpandedCargoBay(); }
- (BOOL) hasShieldBooster	{ return _cxxShip->hasShieldBooster(); }
- (BOOL) hasMilitaryShieldEnhancer	{ return _cxxShip->hasMilitaryShieldEnhancer(); }
- (BOOL) hasHeatShield	{ return _cxxShip->hasHeatShield(); }
- (BOOL) hasFuelInjection	{ return _cxxShip->hasFuelInjection(); }
- (BOOL) hasCascadeMine	{ return _cxxShip->hasCascadeMine(); }
- (BOOL) hasEscapePod	{ return _cxxShip->hasEscapePod(); }
- (BOOL) hasDockingComputer	{ return _cxxShip->hasDockingComputer(); }
- (BOOL) hasGalacticHyperdrive	{ return _cxxShip->hasGalacticHyperdrive(); }
- (float) shieldBoostFactor	{ return _cxxShip->shieldBoostFactor(); }
- (float) maxForwardShieldLevel	{ return SHIP_PART(maxForwardShieldLevel()); }
- (float) maxAftShieldLevel	{ return SHIP_PART(maxAftShieldLevel()); }
- (float) shieldRechargeRate	{ return _cxxShip->shieldRechargeRate(); }
- (double) maxHyperspaceDistance	{ return _cxxShip->maxHyperspaceDistance(); }

@end


@implementation ShipEntity (OOSlice11)

- (float) afterburnerFactor	{ return _cxxShip->afterburnerFactor(); }
- (float) afterburnerRate	{ return _cxxShip->afterburnerRate(); }
- (void) setAfterburnerFactor:(GLfloat)newValue	{ _cxxShip->setAfterburnerFactor(newValue); }
- (void) setAfterburnerRate:(GLfloat)newValue	{ _cxxShip->setAfterburnerRate(newValue); }
- (float) maxThrust	{ return _cxxShip->maxThrust(); }
- (void) setMaxThrust:(GLfloat)newValue	{ _cxxShip->setMaxThrust(newValue); }
- (float) thrust	{ return _cxxShip->getThrust(); }
- (void) behaviour_stop_still:(double)delta_t	{ _cxxShip->behaviour_stop_still(delta_t); }
- (void) behaviour_idle:(double)delta_t	{ _cxxShip->behaviour_idle(delta_t); }
- (void) behaviour_tumble:(double)delta_t	{ _cxxShip->behaviour_tumble(delta_t); }
- (void) behaviour_tractored:(double)delta_t	{ _cxxShip->behaviour_tractored(delta_t); }
- (void) behaviour_track_target:(double)delta_t	{ _cxxShip->behaviour_track_target(delta_t); }
- (void) behaviour_intercept_target:(double)delta_t	{ _cxxShip->behaviour_intercept_target(delta_t); }
- (void) behaviour_attack_break_off_target:(double)delta_t	{ _cxxShip->behaviour_attack_break_off_target(delta_t); }
- (void) behaviour_attack_slow_dogfight:(double)delta_t	{ _cxxShip->behaviour_attack_slow_dogfight(delta_t); }
- (void) behaviour_evasive_action:(double)delta_t	{ _cxxShip->behaviour_evasive_action(delta_t); }

@end


@implementation ShipEntity (OOSlice12)

- (void) behaviour_attack_target:(double)delta_t	{ _cxxShip->behaviour_attack_target(delta_t); }
- (void) behaviour_attack_broadside:(double)delta_t	{ _cxxShip->behaviour_attack_broadside(delta_t); }
- (void) behaviour_attack_broadside_left:(double)delta_t	{ _cxxShip->behaviour_attack_broadside_left(delta_t); }
- (void) behaviour_attack_broadside_right:(double)delta_t	{ _cxxShip->behaviour_attack_broadside_right(delta_t); }
- (void) behaviour_attack_broadside_target:(double)delta_t leftside:(BOOL)leftside	{ _cxxShip->behaviour_attack_broadside_target(delta_t, leftside); }
- (void) behaviour_close_to_broadside_range:(double)delta_t	{ _cxxShip->behaviour_close_to_broadside_range(delta_t); }
- (void) behaviour_close_with_target:(double)delta_t	{ _cxxShip->behaviour_close_with_target(delta_t); }

@end


@implementation ShipEntity (OOSlice13)

- (void) behaviour_attack_sniper:(double)delta_t	{ _cxxShip->behaviour_attack_sniper(delta_t); }
- (void) behaviour_fly_to_target_six:(double)delta_t	{ _cxxShip->behaviour_fly_to_target_six(delta_t); }
- (void) behaviour_attack_mining_target:(double)delta_t	{ _cxxShip->behaviour_attack_mining_target(delta_t); }
- (void) behaviour_attack_fly_to_target:(double)delta_t	{ _cxxShip->behaviour_attack_fly_to_target(delta_t); }

@end


@implementation ShipEntity (OOSlice14)

- (void) behaviour_attack_fly_from_target:(double)delta_t	{ _cxxShip->behaviour_attack_fly_from_target(delta_t); }
- (void) behaviour_running_defense:(double)delta_t	{ _cxxShip->behaviour_running_defense(delta_t); }
- (void) behaviour_flee_target:(double)delta_t	{ _cxxShip->behaviour_flee_target(delta_t); }
- (void) behaviour_fly_range_from_destination:(double)delta_t	{ _cxxShip->behaviour_fly_range_from_destination(delta_t); }
- (void) behaviour_face_destination:(double)delta_t	{ _cxxShip->behaviour_face_destination(delta_t); }
- (void) behaviour_land_on_planet:(double)delta_t	{ _cxxShip->behaviour_land_on_planet(delta_t); }
- (void) behaviour_formation_form_up:(double)delta_t	{ _cxxShip->behaviour_formation_form_up(delta_t); }

@end


@implementation ShipEntity (OOSlice15)

- (void) behaviour_fly_to_destination:(double)delta_t	{ _cxxShip->behaviour_fly_to_destination(delta_t); }
- (void) behaviour_fly_from_destination:(double)delta_t	{ _cxxShip->behaviour_fly_from_destination(delta_t); }
- (void) behaviour_avoid_collision:(double)delta_t	{ _cxxShip->behaviour_avoid_collision(delta_t); }
- (void) behaviour_track_as_turret:(double)delta_t	{ _cxxShip->behaviour_track_as_turret(delta_t); }
- (void) behaviour_fly_thru_navpoints:(double)delta_t	{ _cxxShip->behaviour_fly_thru_navpoints(delta_t); }
- (void) behaviour_scripted_ai:(double)delta_t	{ _cxxShip->behaviour_scripted_ai(delta_t); }
- (float) reactionTime	{ return _cxxShip->getReactionTime(); }
- (void) setReactionTime:(float)newReactionTime	{ _cxxShip->setReactionTime(newReactionTime); }
- (HPVector) calculateTargetPosition	{ return _cxxShip->calculateTargetPosition(); }

@end


@implementation ShipEntity (OOSlice16)

- (void) startTrackingCurve	{ _cxxShip->startTrackingCurve(); }
- (void) updateTrackingCurve	{ _cxxShip->updateTrackingCurve(); }
- (void) calculateTrackingCurve	{ _cxxShip->calculateTrackingCurve(); }
- (void) drawImmediate:(bool)immediate translucent:(bool)translucent	{ SHIP_PART(drawImmediate(immediate, translucent)); }
#ifndef NDEBUG
- (void) drawDebugStuff	{ _cxxShip->drawDebugStuff(); }
#endif
- (void) drawSubEntityImmediate:(bool)immediate translucent:(bool)translucent	{ _cxxShip->drawSubEntityImmediate(immediate, translucent); }
- (GLfloat *) scannerDisplayColorForShip:(ShipEntity*)otherShip :(BOOL)isHostile :(BOOL)flash :(OOColor *)scannerDisplayColor1 :(OOColor *)scannerDisplayColor2 :(OOColor *)scannerDisplayColorH1 :(OOColor *)scannerDisplayColorH2	{ return _cxxShip->scannerDisplayColorForShip(otherShip, isHostile, flash, scannerDisplayColor1, scannerDisplayColor2, scannerDisplayColorH1, scannerDisplayColorH2); }
- (void) setScannerDisplayColor1:(OOColor *)color	{ _cxxShip->setScannerDisplayColor1(color); }
- (void) setScannerDisplayColor2:(OOColor *)color	{ _cxxShip->setScannerDisplayColor2(color); }
- (OOColor *) scannerDisplayColor1	{ return _cxxShip->scannerDisplayColor1(); }
- (OOColor *) scannerDisplayColor2	{ return _cxxShip->scannerDisplayColor2(); }
- (void) setScannerDisplayColorHostile1:(OOColor *)color	{ _cxxShip->setScannerDisplayColorHostile1(color); }
- (void) setScannerDisplayColorHostile2:(OOColor *)color	{ _cxxShip->setScannerDisplayColorHostile2(color); }
- (OOColor *) scannerDisplayColorHostile1	{ return _cxxShip->scannerDisplayColorHostile1(); }
- (OOColor *) scannerDisplayColorHostile2	{ return _cxxShip->scannerDisplayColorHostile2(); }
- (BOOL) isCloaked	{ return _cxxShip->isCloaked(); }
- (BOOL) cloakPassive	{ return _cxxShip->getCloakPassive(); }
- (void) setCloaked:(BOOL)cloak	{ _cxxShip->setCloaked(cloak); }
- (BOOL) hasAutoCloak	{ return _cxxShip->hasAutoCloak(); }
- (void) setAutoCloak:(BOOL)automatic	{ _cxxShip->setAutoCloak(automatic); }
- (BOOL) isJammingScanning	{ return _cxxShip->isJammingScanning(); }
- (void) addSubEntity:(Entity<OOSubEntity> *)sub	{ _cxxShip->addSubEntity(sub); }
- (void) setOwner:(Entity *)who_owns_entity	{ SHIP_PART(setOwner(oo::ToCxx(who_owns_entity))); }
- (void) applyThrust:(double)delta_t	{ _cxxShip->applyThrust(delta_t); }
- (void) orientationChanged	{ SHIP_PART(orientationChanged()); }

@end


@implementation ShipEntity (OOSlice17)

- (void) applyRoll:(GLfloat)roll1 andClimb:(GLfloat)climb1	{ SHIP_PART(applyRoll(roll1, climb1)); }
- (void) applyRoll:(GLfloat)roll1 climb:(GLfloat)climb1 andYaw:(GLfloat)yaw1	{ SHIP_PART(applyRoll(roll1, climb1, yaw1)); }
- (void) applyAttitudeChanges:(double)delta_t	{ SHIP_PART(applyAttitudeChanges(delta_t)); }
- (void) avoidCollision	{ _cxxShip->avoidCollision(); }
- (void) resumePostProximityAlert	{ _cxxShip->resumePostProximityAlert(); }
- (double) messageTime	{ return _cxxShip->getMessageTime(); }
- (void) setMessageTime:(double)value	{ _cxxShip->setMessageTime(value); }
- (OOShipGroup *) group	{ return _cxxShip->group(); }
- (void) setGroup:(OOShipGroup *)group	{ _cxxShip->setGroup(group); }
- (OOShipGroup *) escortGroup	{ return _cxxShip->escortGroup(); }
- (void) setEscortGroup:(OOShipGroup *)group	{ _cxxShip->setEscortGroup(group); }
#ifndef NDEBUG
- (OOShipGroup *) rawEscortGroup	{ return _cxxShip->rawEscortGroup(); }
#endif
- (OOShipGroup *) stationGroup	{ return _cxxShip->stationGroup(); }
- (BOOL) hasEscorts	{ return _cxxShip->hasEscorts(); }
- (std::vector<oo::ObjCRef<ShipEntity *>>) cxx_escorts	{ return _cxxShip->escorts(); }
- (std::vector<oo::ObjCRef<ShipEntity *>>) escortArray	{ return _cxxShip->escortArray(); }
- (uint8_t) escortCount	{ return _cxxShip->escortCount(); }
- (uint8_t) pendingEscortCount	{ return _cxxShip->pendingEscortCount(); }
- (void) setPendingEscortCount:(uint8_t)count	{ _cxxShip->setPendingEscortCount(count); }
- (uint8_t) maxEscortCount	{ return _cxxShip->maxEscortCount(); }
- (void) setMaxEscortCount:(uint8_t)newCount	{ _cxxShip->setMaxEscortCount(newCount); }
- (NSUInteger) turretCount	{ return _cxxShip->turretCount(); }
- (Entity*) proximityAlert	{ return _cxxShip->proximityAlert(); }
- (void) setProximityAlert:(ShipEntity*)other	{ _cxxShip->setProximityAlert(other); }
- (std::optional<std::string>) cxx_name	{ return _cxxShip->getName(); }
- (std::optional<std::string>) cxx_shipUniqueName	{ return _cxxShip->getShipUniqueName(); }
- (std::optional<std::string>) cxx_shipClassName	{ return _cxxShip->getShipClassName(); }
- (std::optional<std::string>) displayName	{ return _cxxShip->getDisplayName(); }
- (std::optional<std::string>) cxx_scanDescriptionForScripting	{ return _cxxShip->scanDescriptionForScripting(); }
- (std::optional<std::string>) cxx_scanDescription	{ return _cxxShip->scanDescription(); }
- (void) cxx_setName:(const std::optional<std::string> &)inName	{ SHIP_PART(setName(inName)); }
- (void) cxx_setShipUniqueName:(const std::optional<std::string> &)inName	{ _cxxShip->setShipUniqueName(inName); }
- (void) cxx_setShipClassName:(const std::optional<std::string> &)inName	{ _cxxShip->setShipClassName(inName); }
- (void) cxx_setDisplayName:(const std::optional<std::string> &)inName	{ _cxxShip->setDisplayName(inName); }
- (void) cxx_setScanDescription:(const std::optional<std::string> &)inName	{ _cxxShip->setScanDescription(inName); }

@end


@implementation ShipEntity (OOSlice18)

- (std::optional<std::string>) identFromShip:(ShipEntity*)otherShip	{ return _cxxShip->identFromShip(otherShip); }
- (BOOL) hasRole:(const std::string &)role	{ return _cxxShip->hasRole(role); }
- (void) addRole:(const std::string &)role	{ _cxxShip->addRole(role); }
- (void) cxx_addRole:(const std::string &)role withProbability:(float)probability	{ _cxxShip->addRole(role, probability); }
- (void) cxx_removeRole:(const std::string &)role	{ _cxxShip->removeRole(role); }
- (std::optional<std::string>) cxx_primaryRole	{ return _cxxShip->getPrimaryRole(); }
- (void) setPrimaryRole:(const std::string &)role	{ _cxxShip->setPrimaryRole(role); }
- (BOOL) cxx_hasPrimaryRole:(const std::string &)role	{ return _cxxShip->hasPrimaryRole(role); }
- (BOOL) isPolice	{ return _cxxShip->isPolice(); }
- (BOOL) isThargoid	{ return _cxxShip->isThargoid(); }
- (BOOL) isTrader	{ return _cxxShip->isTrader(); }
- (BOOL) isPirate	{ return _cxxShip->isPirate(); }
- (BOOL) isMissile	{ return _cxxShip->getIsMissile(); }
- (BOOL) isMine	{ return _cxxShip->isMine(); }
- (BOOL) isWeapon	{ return _cxxShip->isWeapon(); }
- (BOOL) isEscort	{ return _cxxShip->isEscort(); }
- (BOOL) isShuttle	{ return _cxxShip->isShuttle(); }
- (BOOL) isTurret	{ return _cxxShip->isTurret(); }
- (BOOL) isPirateVictim	{ return _cxxShip->isPirateVictim(); }
- (BOOL) isExplicitlyUnpiloted	{ return _cxxShip->isExplicitlyUnpiloted(); }
- (BOOL) isUnpiloted	{ return SHIP_PART(isUnpiloted()); }
- (BOOL) hasHostileTarget	{ return SHIP_PART(hasHostileTarget()); }
- (BOOL) isHostileTo:(Entity *)entity	{ return _cxxShip->isHostileTo(entity); }
- (GLfloat) weaponRange	{ return _cxxShip->getWeaponRange(); }
- (void) setWeaponRange:(GLfloat)value	{ _cxxShip->setWeaponRange(value); }
- (void) setWeaponDataFromType:(OOWeaponType)weapon_type	{ _cxxShip->setWeaponDataFromType(weapon_type); }
- (float) energyRechargeRate	{ return _cxxShip->energyRechargeRate(); }
- (void) setEnergyRechargeRate:(GLfloat)newValue	{ _cxxShip->setEnergyRechargeRate(newValue); }
- (float) weaponRechargeRate	{ return _cxxShip->weaponRechargeRate(); }
- (void) setWeaponRechargeRate:(float)value	{ _cxxShip->setWeaponRechargeRate(value); }
- (void) setWeaponEnergy:(float)value	{ _cxxShip->setWeaponEnergy(value); }
- (OOWeaponFacing) currentWeaponFacing	{ return _cxxShip->getCurrentWeaponFacing(); }
- (GLfloat) scannerRange	{ return _cxxShip->getScannerRange(); }
- (void) setScannerRange:(GLfloat)value	{ _cxxShip->setScannerRange(value); }
- (Vector) reference	{ return _cxxShip->getReference(); }
- (void) setReference:(Vector)v	{ _cxxShip->setReference(v); }
- (BOOL) reportAIMessages	{ return _cxxShip->getReportAIMessages(); }
- (void) setReportAIMessages:(BOOL)yn	{ _cxxShip->setReportAIMessages(yn); }
- (void) transitionToAegisNone	{ _cxxShip->transitionToAegisNone(); }
- (OOPlanetEntity *) findNearestPlanet	{ return _cxxShip->findNearestPlanet(); }
- (Entity<OOStellarBody> *) findNearestStellarBody	{ return (Entity<OOStellarBody> *)_cxxShip->findNearestStellarBody(); }
- (OOPlanetEntity *) findNearestPlanetExcludingMoons	{ return _cxxShip->findNearestPlanetExcludingMoons(); }

@end


@implementation ShipEntity (OOSlice19)

- (OOAegisStatus) checkForAegis	{ return _cxxShip->checkForAegis(); }
- (void) forceAegisCheck	{ _cxxShip->forceAegisCheck(); }
- (BOOL) withinStationAegis	{ return _cxxShip->withinStationAegis(); }
- (Entity<OOStellarBody> *) lastAegisLock	{ return (Entity<OOStellarBody> *)_cxxShip->lastAegisLock(); }
- (void) setLastAegisLock:(Entity<OOStellarBody> *)lastAegisLock	{ _cxxShip->setLastAegisLock(lastAegisLock); }
- (OOSystemID) homeSystem	{ return _cxxShip->homeSystem(); }
- (OOSystemID) destinationSystem	{ return _cxxShip->destinationSystem(); }
- (void) setHomeSystem:(OOSystemID)s	{ _cxxShip->setHomeSystem(s); }
- (void) setDestinationSystem:(OOSystemID)s	{ _cxxShip->setDestinationSystem(s); }
- (void) setStatus:(OOEntityStatus)stat	{ SHIP_PART(setStatus(stat)); }
- (void) setLaunchDelay:(double)delay	{ _cxxShip->setLaunchDelay(delay); }
- (std::optional<std::vector<oo::Ref<OOCharacter>>>) cxx_crew	{ return _cxxShip->getCrew(); }
- (void) cxx_setCrew:(const std::optional<std::vector<oo::Ref<OOCharacter>>> &)crewArray	{ _cxxShip->setCrew(crewArray); }
- (void) cxx_setSingleCrewWithRole:(const std::string &)crewRole	{ _cxxShip->setSingleCrewWithRole(crewRole); }
- (std::vector<oo::PList>) cxx_crewForScripting	{ return _cxxShip->crewForScripting(); }
- (void) setStateMachine:(const std::string &)smName	{ _cxxShip->setStateMachine(smName); }
- (void) setAI:(AI *)ai	{ _cxxShip->setAI(ai); }
- (AI *) getAI	{ return _cxxShip->getAI(); }
- (BOOL) hasAutoAI	{ return _cxxShip->hasAutoAI(); }
- (BOOL) hasNewAI	{ return _cxxShip->hasNewAI(); }
- (BOOL) hasAutoWeapons	{ return _cxxShip->hasAutoWeapons(); }
- (void) cxx_setShipScript:(const std::optional<std::string> &)script_name	{ _cxxShip->setShipScript(script_name); }
- (double) frustration	{ return _cxxShip->getFrustration(); }
- (OOFuelQuantity) fuel	{ return _cxxShip->getFuel(); }
- (void) setFuel:(OOFuelQuantity)amount	{ _cxxShip->setFuel(amount); }
- (OOFuelQuantity) fuelCapacity	{ return _cxxShip->fuelCapacity(); }
- (GLfloat) fuelChargeRate	{ return SHIP_PART(fuelChargeRate()); }

@end


@implementation ShipEntity (OOSlice20)

- (void) applySticks:(double)delta_t	{ _cxxShip->applySticks(delta_t); }
- (void) setRoll:(double)amount	{ _cxxShip->setRoll(amount); }
- (void) setRawRoll:(double)amount	{ _cxxShip->setRawRoll(amount); }
- (void) setPitch:(double)amount	{ _cxxShip->setPitch(amount); }
- (void) setYaw:(double)amount	{ _cxxShip->setYaw(amount); }
- (void) setThrust:(double)amount	{ _cxxShip->setThrust(amount); }
- (void) setThrustForDemo:(float)factor	{ _cxxShip->setThrustForDemo(factor); }
- (void) setBounty:(OOCreditsQuantity)amount	{ SHIP_PART(setBounty(amount)); }
- (void) setBounty:(OOCreditsQuantity)amount withReason:(OOLegalStatusReason)reason	{ SHIP_PART(setBounty(amount, reason)); }
- (void) setBounty:(OOCreditsQuantity)amount withReasonAsString:(const std::string &)reason	{ SHIP_PART(setBounty(amount, reason)); }
- (OOCreditsQuantity) bounty	{ return SHIP_PART(getBounty()); }
- (int) legalStatus	{ return SHIP_PART(legalStatus()); }
- (void) cxx_setCommodity:(const std::string &)co_type andAmount:(OOCargoQuantity)co_amount	{ _cxxShip->setCommodity(co_type, co_amount); }
- (void) cxx_setCommodityForPod:(const std::optional<std::string> &)co_type andAmount:(OOCargoQuantity)co_amount	{ _cxxShip->setCommodityForPod(co_type, co_amount); }
- (std::optional<std::string>) cxx_commodityType	{ return _cxxShip->commodityType(); }
- (OOCargoQuantity) commodityAmount	{ return _cxxShip->commodityAmount(); }
- (OOCargoQuantity) maxAvailableCargoSpace	{ return _cxxShip->maxAvailableCargoSpace(); }
- (void) setMaxAvailableCargoSpace:(OOCargoQuantity)newValue	{ _cxxShip->setMaxAvailableCargoSpace(newValue); }
- (OOCargoQuantity) availableCargoSpace	{ return _cxxShip->availableCargoSpace(); }
- (OOCargoQuantity) cargoQuantityOnBoard	{ return SHIP_PART(cargoQuantityOnBoard()); }
- (OOCargoType) cargoType	{ return _cxxShip->cargoType(); }
- (std::vector<oo::ObjCRef<ShipEntity *>> *) cxx_cargo	{ return _cxxShip->getCargo(); }
- (NSUInteger) cxx_cargoCount	{ return _cxxShip->cargoCount(); }
- (oo::PList) cargoListForScripting	{ return SHIP_PART(cargoListForScripting()); }
- (void) setCargo:(const std::vector<oo::ObjCRef<ShipEntity *>> &)some_cargo	{ _cxxShip->setCargo(some_cargo); }
- (BOOL) cxx_addCargo:(const std::vector<oo::ObjCRef<ShipEntity *>> &)some_cargo	{ return _cxxShip->addCargo(some_cargo); }
- (BOOL) cxx_removeCargo:(const std::string &)commodity amount:(OOCargoQuantity)amount	{ return _cxxShip->removeCargo(commodity, amount); }
- (BOOL) showScoopMessage	{ return _cxxShip->showScoopMessage(); }
- (OOCargoFlag) cargoFlag	{ return _cxxShip->cargoFlag(); }
- (void) setCargoFlag:(OOCargoFlag)flag	{ _cxxShip->setCargoFlag(flag); }
- (void) setSpeed:(double)amount	{ _cxxShip->setSpeed(amount); }
- (void) setDesiredSpeed:(double)amount	{ _cxxShip->setDesiredSpeed(amount); }
- (double) desiredSpeed	{ return _cxxShip->desiredSpeed(); }

@end


@implementation ShipEntity (OOSlice21)

- (double) desiredRange	{ return _cxxShip->desiredRange(); }
- (void) setDesiredRange:(double)amount	{ _cxxShip->setDesiredRange(amount); }
- (double) cruiseSpeed	{ return _cxxShip->getCruiseSpeed(); }
- (void) increase_flight_speed:(double)delta	{ _cxxShip->increase_flight_speed(delta); }
- (void) decrease_flight_speed:(double)delta	{ _cxxShip->decrease_flight_speed(delta); }
- (void) increase_flight_roll:(double)delta	{ _cxxShip->increase_flight_roll(delta); }
- (void) decrease_flight_roll:(double)delta	{ _cxxShip->decrease_flight_roll(delta); }
- (void) increase_flight_pitch:(double)delta	{ _cxxShip->increase_flight_pitch(delta); }
- (void) decrease_flight_pitch:(double)delta	{ _cxxShip->decrease_flight_pitch(delta); }
- (void) increase_flight_yaw:(double)delta	{ _cxxShip->increase_flight_yaw(delta); }
- (void) decrease_flight_yaw:(double)delta	{ _cxxShip->decrease_flight_yaw(delta); }
- (GLfloat) flightRoll	{ return _cxxShip->getFlightRoll(); }
- (GLfloat) flightPitch	{ return _cxxShip->getFlightPitch(); }
- (GLfloat) flightYaw	{ return _cxxShip->getFlightYaw(); }
- (GLfloat) flightSpeed	{ return _cxxShip->getFlightSpeed(); }
- (GLfloat) maxFlightPitch	{ return _cxxShip->maxFlightPitch(); }
- (GLfloat) maxFlightSpeed	{ return _cxxShip->getMaxFlightSpeed(); }
- (GLfloat) maxFlightRoll	{ return _cxxShip->maxFlightRoll(); }
- (GLfloat) maxFlightYaw	{ return _cxxShip->maxFlightYaw(); }
- (void) setMaxFlightPitch:(GLfloat)newValue	{ SHIP_PART(setMaxFlightPitch(newValue)); }
- (void) setMaxFlightSpeed:(GLfloat)newValue	{ _cxxShip->setMaxFlightSpeed(newValue); }
- (void) setMaxFlightRoll:(GLfloat)newValue	{ SHIP_PART(setMaxFlightRoll(newValue)); }
- (void) setMaxFlightYaw:(GLfloat)newValue	{ SHIP_PART(setMaxFlightYaw(newValue)); }
- (GLfloat) speedFactor	{ return _cxxShip->speedFactor(); }
- (GLfloat) temperature	{ return _cxxShip->temperature(); }
- (void) setTemperature:(GLfloat)value	{ _cxxShip->setTemperature(value); }
- (float) randomEjectaTemperature	{ return _cxxShip->randomEjectaTemperature(); }
- (float) randomEjectaTemperatureWithMaxFactor:(float)factor	{ return _cxxShip->randomEjectaTemperatureWithMaxFactor(factor); }
- (GLfloat) heatInsulation	{ return _cxxShip->heatInsulation(); }
- (void) setHeatInsulation:(GLfloat)value	{ _cxxShip->setHeatInsulation(value); }
- (int) damage	{ return _cxxShip->damage(); }
- (void) dealEnergyDamage:(GLfloat)baseDamage atRange:(GLfloat)range withBias:(GLfloat)velocityBias	{ _cxxShip->dealEnergyDamage(baseDamage, range, velocityBias); }
- (void) dealEnergyDamageWithinDesiredRange	{ _cxxShip->dealEnergyDamageWithinDesiredRange(); }
- (void) dealMomentumWithinDesiredRange:(double)amount	{ _cxxShip->dealMomentumWithinDesiredRange(amount); }
- (BOOL) isHulk	{ return _cxxShip->getIsHulk(); }
- (void) setHulk:(BOOL)isNowHulk	{ _cxxShip->setHulk(isNowHulk); }
- (void) noteTakingDamage:(double)amount from:(Entity *)entity type:(OOShipDamageType)type	{ SHIP_PART(noteTakingDamage(amount, entity, type)); }
- (void) noteKilledBy:(Entity *)whom damageType:(OOShipDamageType)type	{ _cxxShip->noteKilledBy(whom, type); }

@end


@implementation ShipEntity (OOSlice22)

- (void) getDestroyedBy:(Entity *)whom damageType:(OOShipDamageType)type	{ SHIP_PART(getDestroyedBy(whom, type)); }
- (void) rescaleBy:(GLfloat)factor	{ _cxxShip->rescaleBy(factor); }
- (void) rescaleBy:(GLfloat)factor writeToCache:(BOOL)writeToCache	{ _cxxShip->rescaleBy(factor, writeToCache); }
- (void) releaseCargoPodsDebris	{ _cxxShip->releaseCargoPodsDebris(); }
- (void) setIsWreckage:(BOOL)isw	{ _cxxShip->setIsWreckage(isw); }
- (BOOL) showDamage	{ return _cxxShip->showDamage(); }
- (void) becomeExplosion	{ SHIP_PART(becomeExplosion()); }
- (void) becomeEnergyBlast	{ SHIP_PART(becomeEnergyBlast()); }
- (void) broadcastEnergyBlastImminent	{ _cxxShip->broadcastEnergyBlastImminent(); }
- (void) removeExhaust:(OOExhaustPlumeEntity *)exhaust	{ _cxxShip->removeExhaust(exhaust); }

@end


@implementation ShipEntity (OOSlice23)

- (void) removeFlasher:(OOFlasherEntity *)flasher	{ _cxxShip->removeFlasher(flasher); }
- (void) subEntityDied:(ShipEntity *)sub	{ _cxxShip->subEntityDied(sub); }
- (void) subEntityReallyDied:(ShipEntity *)sub	{ SHIP_PART(subEntityReallyDied(sub)); }
- (Vector) positionOffsetForAlignment:(const std::string &)align	{ return _cxxShip->positionOffsetForAlignment(align); }
- (void) becomeLargeExplosion:(double)factor	{ SHIP_PART(becomeLargeExplosion(factor)); }
- (void) collectBountyFor:(ShipEntity *)other	{ SHIP_PART(collectBountyFor(other)); }
- (OOComparisonResult) compareBeaconCodeWith:(Entity<OOBeaconEntity> *)other	{ return _cxxShip->compareBeaconCodeWith(other); }
- (GLfloat) weaponRecoveryTime	{ return _cxxShip->weaponRecoveryTime(); }
- (GLfloat) laserHeatLevel	{ return SHIP_PART(laserHeatLevel()); }
- (GLfloat) laserHeatLevelAft	{ return SHIP_PART(laserHeatLevelAft()); }
- (GLfloat) laserHeatLevelForward	{ return SHIP_PART(laserHeatLevelForward()); }
- (GLfloat) laserHeatLevelPort	{ return SHIP_PART(laserHeatLevelPort()); }
- (GLfloat) laserHeatLevelStarboard	{ return SHIP_PART(laserHeatLevelStarboard()); }
- (GLfloat) hullHeatLevel	{ return _cxxShip->hullHeatLevel(); }
- (GLfloat) entityPersonality	{ return _cxxShip->entityPersonality(); }
- (GLint) entityPersonalityInt	{ return _cxxShip->entityPersonalityInt(); }
- (uint32_t) randomSeedForShaders	{ return _cxxShip->randomSeedForShaders(); }
- (void) setEntityPersonalityInt:(uint16_t)value	{ _cxxShip->setEntityPersonalityInt(value); }
- (void) setSuppressExplosion:(BOOL)suppress	{ _cxxShip->setSuppressExplosion(suppress); }
- (void) resetExhaustPlumes	{ _cxxShip->resetExhaustPlumes(); }
- (void) checkScanner	{ _cxxShip->checkScanner(); }
- (void) checkScannerIgnoringUnpowered	{ _cxxShip->checkScannerIgnoringUnpowered(); }
- (ShipEntity**) scannedShips	{ return _cxxShip->scannedShips(); }
- (int) numberOfScannedShips	{ return _cxxShip->numberOfScannedShips(); }
- (Entity *) foundTarget	{ return _cxxShip->foundTarget(); }
- (void) setFoundTarget:(Entity *)targetEntity	{ SHIP_PART(setFoundTarget(targetEntity)); }
- (Entity *) primaryAggressor	{ return _cxxShip->primaryAggressor(); }
- (void) setPrimaryAggressor:(Entity *)targetEntity	{ _cxxShip->setPrimaryAggressor(targetEntity); }
- (Entity *) lastEscortTarget	{ return _cxxShip->lastEscortTarget(); }
- (void) setLastEscortTarget:(Entity *)targetEntity	{ _cxxShip->setLastEscortTarget(targetEntity); }

@end


@implementation ShipEntity (OOSlice24)

- (Entity *) thankedShip	{ return _cxxShip->thankedShip(); }
- (void) setThankedShip:(Entity *)targetEntity	{ _cxxShip->setThankedShip(targetEntity); }
- (Entity *) rememberedShip	{ return _cxxShip->rememberedShip(); }
- (void) setRememberedShip:(Entity *)targetEntity	{ _cxxShip->setRememberedShip(targetEntity); }
- (Entity *) targetStation	{ return _cxxShip->targetStation(); }
- (void) setTargetStation:(Entity *)targetEntity	{ _cxxShip->setTargetStation(targetEntity); }
- (BOOL) isValidTarget:(Entity *)target	{ return SHIP_PART(isValidTarget(target)); }
- (void) addTarget:(Entity *)targetEntity	{ SHIP_PART(addTarget(targetEntity)); }
- (void) removeTarget:(Entity *)targetEntity	{ _cxxShip->removeTarget(targetEntity); }
- (BOOL) canStillTrackPrimaryTarget	{ return _cxxShip->canStillTrackPrimaryTarget(); }
- (id) primaryTarget	{ return _cxxShip->primaryTarget(); }
- (id) primaryTargetWithoutValidityCheck	{ return _cxxShip->primaryTargetWithoutValidityCheck(); }
- (BOOL) isFriendlyTo:(ShipEntity *)otherShip	{ return _cxxShip->isFriendlyTo(otherShip); }
- (ShipEntity *) shipHitByLaser	{ return _cxxShip->shipHitByLaser(); }
- (void) setShipHitByLaser:(ShipEntity *)ship	{ _cxxShip->setShipHitByLaser(ship); }
- (void) noteLostTarget	{ _cxxShip->noteLostTarget(); }
- (void) noteLostTargetAndGoIdle	{ _cxxShip->noteLostTargetAndGoIdle(); }
- (void) noteTargetDestroyed:(ShipEntity *)target	{ _cxxShip->noteTargetDestroyed(target); }
- (OOBehaviour) behaviour	{ return _cxxShip->getBehaviour(); }
- (void) setBehaviour:(OOBehaviour)cond	{ _cxxShip->setBehaviour(cond); }
- (HPVector) destination	{ return _cxxShip->destination(); }
- (HPVector) coordinates	{ return _cxxShip->getCoordinates(); }
- (void) setCoordinate:(HPVector)coord	{ _cxxShip->setCoordinate(coord); }
- (HPVector) distance_six:(GLfloat)dist	{ return _cxxShip->distance_six(dist); }
- (HPVector) distance_twelve:(GLfloat)dist withOffset:(GLfloat)offset	{ return _cxxShip->distance_twelve(dist, offset); }
- (void) trackOntoTarget:(double)delta_t withDForward:(GLfloat)dp	{ _cxxShip->trackOntoTarget(delta_t, dp); }
- (double) ballTrackLeadingTarget:(double)delta_t atTarget:(Entity *)target	{ return _cxxShip->ballTrackLeadingTarget(delta_t, target); }

@end


@implementation ShipEntity (OOSlice25)

- (void) setEvasiveJink:(GLfloat)z	{ _cxxShip->setEvasiveJink(z); }
- (void) evasiveAction:(double)delta_t	{ _cxxShip->evasiveAction(delta_t); }
- (double) trackPrimaryTarget:(double)delta_t :(BOOL)retreat	{ return _cxxShip->trackPrimaryTarget(delta_t, retreat); }
- (double) trackSideTarget:(double)delta_t :(BOOL)leftside	{ return _cxxShip->trackSideTarget(delta_t, leftside); }

@end


@implementation ShipEntity (OOSlice26)

- (double) missileTrackPrimaryTarget:(double)delta_t	{ return _cxxShip->missileTrackPrimaryTarget(delta_t); }
- (double) trackDestination:(double)delta_t :(BOOL)retreat	{ return _cxxShip->trackDestination(delta_t, retreat); }
- (GLfloat) rollToMatchUp:(Vector)up_vec rotating:(GLfloat)match_roll	{ return _cxxShip->rollToMatchUp(up_vec, match_roll); }
- (GLfloat) rangeToDestination	{ return _cxxShip->rangeToDestination(); }
- (std::vector<oo::ObjCRef<ShipEntity *>>) cxx_collisionExceptions	{ return _cxxShip->collisionExceptions(); }
- (void) addCollisionException:(ShipEntity *)ship	{ _cxxShip->addCollisionException(ship); }
- (void) removeCollisionException:(ShipEntity *)ship	{ _cxxShip->removeCollisionException(ship); }
- (BOOL) collisionExceptedFor:(ShipEntity *)ship	{ return _cxxShip->collisionExceptedFor(ship); }
- (NSUInteger) defenseTargetCount	{ return _cxxShip->defenseTargetCount(); }
- (std::vector<oo::ObjCRef<ShipEntity *>>) allDefenseTargets	{ return _cxxShip->allDefenseTargets(); }
- (std::vector<oo::ObjCRef<ShipEntity *>>) cxx_defenseTargets	{ return _cxxShip->defenseTargets(); }
- (BOOL) addDefenseTarget:(Entity *)target	{ return _cxxShip->addDefenseTarget(target); }
- (void) validateDefenseTargets	{ _cxxShip->validateDefenseTargets(); }
- (BOOL) isDefenseTarget:(Entity *)target	{ return _cxxShip->isDefenseTarget(target); }
- (void) removeAllDefenseTargets	{ _cxxShip->removeAllDefenseTargets(); }
- (void) removeDefenseTarget:(Entity *)target	{ _cxxShip->removeDefenseTarget(target); }
- (double) rangeToPrimaryTarget	{ return _cxxShip->rangeToPrimaryTarget(); }
- (double) rangeToSecondaryTarget:(Entity *)target	{ return _cxxShip->rangeToSecondaryTarget(target); }
- (double) approachAspectToPrimaryTarget	{ return _cxxShip->approachAspectToPrimaryTarget(); }
- (BOOL) hasProximityAlertIgnoringTarget:(BOOL)ignore_target	{ return _cxxShip->hasProximityAlertIgnoringTarget(ignore_target); }

@end


@implementation ShipEntity (OOSlice27)

- (GLfloat) currentAimTolerance	{ return _cxxShip->currentAimTolerance(); }
- (GLfloat) lookingAtSunWithThresholdAngleCos:(GLfloat)thresholdAngleCos	{ return SHIP_PART(lookingAtSunWithThresholdAngleCos(thresholdAngleCos)); }
- (BOOL) onTarget:(OOWeaponFacing)direction withWeapon:(OOWeaponType)weapon_type	{ return _cxxShip->onTarget(direction, weapon_type); }
- (BOOL) fireWeapon:(OOWeaponType)weapon_type direction:(OOWeaponFacing)direction range:(double)range	{ return _cxxShip->fireWeapon(weapon_type, direction, range); }
- (BOOL) fireMainWeapon:(double)range	{ return _cxxShip->fireMainWeapon(range); }
- (BOOL) fireAftWeapon:(double)range	{ return _cxxShip->fireAftWeapon(range); }
- (BOOL) firePortWeapon:(double)range	{ return _cxxShip->firePortWeapon(range); }
- (BOOL) fireStarboardWeapon:(double)range	{ return _cxxShip->fireStarboardWeapon(range); }
- (OOTimeDelta) shotTime	{ return _cxxShip->shotTime(); }
- (void) resetShotTime	{ _cxxShip->resetShotTime(); }
- (BOOL) fireTurretCannon:(double)range	{ return _cxxShip->fireTurretCannon(range); }
- (void) setLaserColor:(OOColor *)color	{ _cxxShip->setLaserColor(color); }
- (void) setExhaustEmissiveColor:(OOColor *)color	{ _cxxShip->setExhaustEmissiveColor(color); }
- (OOColor *) laserColor	{ return _cxxShip->laserColor(); }
- (OOColor *) exhaustEmissiveColor	{ return _cxxShip->exhaustEmissiveColor(); }

@end


@implementation ShipEntity (OOSlice28)

- (BOOL) fireSubentityLaserShot:(double)range	{ return _cxxShip->fireSubentityLaserShot(range); }
- (BOOL) fireDirectLaserShot:(double)range	{ return _cxxShip->fireDirectLaserShot(range); }
- (BOOL) fireDirectLaserDefensiveShot	{ return _cxxShip->fireDirectLaserDefensiveShot(); }
- (BOOL) fireDirectLaserShotAt:(Entity *)my_target	{ return _cxxShip->fireDirectLaserShotAt(my_target); }
- (std::vector<Vector>) cxx_laserPortOffset:(OOWeaponFacing)direction	{ return _cxxShip->laserPortOffset(direction); }
- (BOOL) cxx_fireLaserShotInDirection:(OOWeaponFacing)direction weaponIdentifier:(const std::string &)weaponIdentifier	{ return _cxxShip->fireLaserShotInDirection(direction, weaponIdentifier); }
- (void) adjustMissedShots:(int)delta	{ _cxxShip->adjustMissedShots(delta); }
- (int) missedShots	{ return _cxxShip->missedShots(); }
- (void) throwSparks	{ SHIP_PART(throwSparks()); }
- (void) considerFiringMissile:(double)delta_t	{ _cxxShip->considerFiringMissile(delta_t); }
- (Vector) missileLaunchPosition	{ return _cxxShip->missileLaunchPosition(); }
- (ShipEntity *) fireMissile	{ return SHIP_PART(fireMissile()); }

@end


@implementation ShipEntity (OOSlice29)

- (ShipEntity *) cxx_fireMissileWithIdentifier:(const std::optional<std::string> &)requestedIdentifier andTarget:(Entity *)target	{ return _cxxShip->fireMissileWithIdentifier(requestedIdentifier, target); }
- (BOOL) isMissileFlagSet	{ return _cxxShip->isMissileFlagSet(); }
- (void) setIsMissileFlag:(BOOL)newValue	{ _cxxShip->setIsMissileFlag(newValue); }
- (OOTimeDelta) missileLoadTime	{ return _cxxShip->missileLoadTime(); }
- (void) setMissileLoadTime:(OOTimeDelta)newMissileLoadTime	{ _cxxShip->setMissileLoadTime(newMissileLoadTime); }
- (void) noticeECM	{ SHIP_PART(noticeECM()); }
- (BOOL) fireECM	{ return SHIP_PART(fireECM()); }
- (BOOL) activateCloakingDevice	{ return SHIP_PART(activateCloakingDevice()); }
- (void) deactivateCloakingDevice	{ SHIP_PART(deactivateCloakingDevice()); }
- (BOOL) launchCascadeMine	{ return _cxxShip->launchCascadeMine(); }
- (ShipEntity*) launchEscapeCapsule	{ return SHIP_PART(launchEscapeCapsule()); }
- (void) dumpCargo	{ SHIP_PART(dumpCargo()); }
- (ShipEntity *) cxx_dumpCargoItem:(const std::optional<std::string> &)preferred	{ return _cxxShip->dumpCargoItem(preferred); }
- (OOCargoType) dumpItem:(ShipEntity*)cargoObj	{ return _cxxShip->dumpItem(cargoObj); }

@end


@implementation ShipEntity (OOSlice30)

- (void) manageCollisions	{ _cxxShip->manageCollisions(); }
- (BOOL) collideWithShip:(ShipEntity *)other	{ return SHIP_PART(collideWithShip(other)); }
- (Vector) thrustVector	{ return _cxxShip->thrustVector(); }
- (Vector) velocity	{ return SHIP_PART(getVelocity()); }
- (void) setTotalVelocity:(Vector)vel	{ _cxxShip->setTotalVelocity(vel); }
- (void) adjustVelocity:(Vector)xVel	{ SHIP_PART(adjustVelocity(xVel)); }
- (void) addImpactMoment:(Vector)moment fraction:(GLfloat)howmuch	{ _cxxShip->addImpactMoment(moment, howmuch); }
- (BOOL) canScoop:(ShipEntity*)other	{ return SHIP_PART(canScoop(other)); }
- (void) getTractoredBy:(ShipEntity *)other	{ _cxxShip->getTractoredBy(other); }
- (void) scoopIn:(ShipEntity *)other	{ _cxxShip->scoopIn(other); }
- (void) suppressTargetLost	{ SHIP_PART(suppressTargetLost()); }
- (void) scoopUp:(ShipEntity *)other	{ _cxxShip->scoopUp(other); }
- (void) scoopUpProcess:(ShipEntity *)other processEvents:(BOOL)procEvents processMessages:(BOOL)procMessages	{ _cxxShip->scoopUpProcess(other, procEvents, procMessages); }

@end


@implementation ShipEntity (OOSlice31)

- (BOOL) cascadeIfAppropriateWithDamageAmount:(double)amount cascadeOwner:(Entity *)owner	{ return _cxxShip->cascadeIfAppropriateWithDamageAmount(amount, owner); }
- (void) takeEnergyDamage:(double)amount from:(Entity *)ent becauseOf:(Entity *)other weaponIdentifier:(const std::string &)weaponIdentifier	{ SHIP_PART(takeEnergyDamage(amount, oo::ToCxx(ent), oo::ToCxx(other), weaponIdentifier)); }
- (BOOL) abandonShip	{ return _cxxShip->abandonShip(); }
- (void) takeScrapeDamage:(double)amount from:(Entity *)ent	{ SHIP_PART(takeScrapeDamage(amount, ent)); }
- (void) takeHeatDamage:(double)amount	{ SHIP_PART(takeHeatDamage(amount)); }
- (void) enterDock:(StationEntity *)station	{ SHIP_PART(enterDock(station)); }
- (void) leaveDock:(StationEntity *)station	{ SHIP_PART(leaveDock(station)); }
- (void) enterWormhole:(WormholeEntity *)w_hole	{ SHIP_PART(enterWormhole(w_hole)); }
- (void) enterWormhole:(WormholeEntity *)w_hole replacing:(BOOL)replacing	{ _cxxShip->enterWormhole(w_hole, replacing); }
- (void) enterWitchspace	{ SHIP_PART(enterWitchspace()); }
- (void) leaveWitchspace	{ SHIP_PART(leaveWitchspace()); }

@end


@implementation ShipEntity (OOSlice32)

- (BOOL) witchspaceLeavingEffects	{ return _cxxShip->witchspaceLeavingEffects(); }
- (void) markAsOffender:(int)offence_value	{ SHIP_PART(markAsOffender(offence_value)); }
- (void) markAsOffender:(int)offence_value withReason:(OOLegalStatusReason)reason	{ SHIP_PART(markAsOffender(offence_value, reason)); }
- (void) switchLightsOn	{ _cxxShip->switchLightsOn(); }
- (void) switchLightsOff	{ _cxxShip->switchLightsOff(); }
- (BOOL) lightsActive	{ return _cxxShip->lightsActive(); }
- (void) setDestination:(HPVector)dest	{ _cxxShip->setDestination(dest); }
- (void) setEscortDestination:(HPVector)dest	{ _cxxShip->setEscortDestination(dest); }
- (BOOL) canAcceptEscort:(ShipEntity *)potentialEscort	{ return _cxxShip->canAcceptEscort(potentialEscort); }
- (BOOL) acceptAsEscort:(ShipEntity *)other_ship	{ return _cxxShip->acceptAsEscort(other_ship); }
- (void) updateEscortFormation	{ _cxxShip->updateEscortFormation(); }
- (void) refreshEscortPositions	{ _cxxShip->refreshEscortPositions(); }
- (HPVector) coordinatesForEscortPosition:(unsigned)idx	{ return _cxxShip->coordinatesForEscortPosition(idx); }
- (void) deployEscorts	{ _cxxShip->deployEscorts(); }
- (void) dockEscorts	{ _cxxShip->dockEscorts(); }
- (void) setTargetToNearestStationIncludingHostiles:(BOOL)includeHostiles	{ _cxxShip->setTargetToNearestStationIncludingHostiles(includeHostiles); }
- (void) setTargetToNearestFriendlyStation	{ _cxxShip->setTargetToNearestFriendlyStation(); }
- (void) setTargetToNearestStation	{ _cxxShip->setTargetToNearestStation(); }
- (void) setTargetToSystemStation	{ _cxxShip->setTargetToSystemStation(); }

@end


@implementation ShipEntity (OOSlice33)

- (void) landOnPlanet:(OOPlanetEntity *)planet	{ _cxxShip->landOnPlanet(planet); }
- (void) abortDocking	{ _cxxShip->abortDocking(); }
- (oo::PList) cxx_dockingInstructions	{ return _cxxShip->getDockingInstructions(); }
- (void) broadcastThargoidDestroyed	{ _cxxShip->broadcastThargoidDestroyed(); }
- (void) broadcastHitByLaserFrom:(ShipEntity *)aggressor_ship	{ _cxxShip->broadcastHitByLaserFrom(aggressor_ship); }
- (void) cxx_sendMessage:(const std::string &)message_text toShip:(ShipEntity*)other_ship withUnpilotedOverride:(BOOL)unpilotedOverride	{ _cxxShip->sendMessage(message_text, other_ship, unpilotedOverride); }
- (void) cxx_sendExpandedMessage:(const std::string &)message_text toShip:(ShipEntity *)other_ship	{ _cxxShip->sendExpandedMessage(message_text, other_ship); }
- (void) broadcastAIMessage:(const std::string &)ai_message	{ _cxxShip->broadcastAIMessage(ai_message); }
- (void) broadcastMessage:(const std::string &)message_text withUnpilotedOverride:(BOOL)unpilotedOverride	{ _cxxShip->broadcastMessage(message_text, unpilotedOverride); }
- (void) setCommsMessageColor	{ _cxxShip->setCommsMessageColor(); }
- (void) receiveCommsMessage:(const std::string &)message_text from:(ShipEntity *)other	{ SHIP_PART(receiveCommsMessage(message_text, other)); }
- (void) cxx_commsMessage:(const std::string &)valueString withUnpilotedOverride:(BOOL)unpilotedOverride	{ _cxxShip->commsMessage(valueString, unpilotedOverride); }
- (BOOL) markedForFines	{ return _cxxShip->markedForFines(); }
- (BOOL) markForFines	{ return _cxxShip->markForFines(); }
- (BOOL) isMining	{ return SHIP_PART(isMining()); }
- (void) interpretAIMessage:(const std::string &)ms	{ SHIP_PART(interpretAIMessage(ms)); }
- (BoundingBox) findBoundingBoxRelativeTo:(Entity *)other InVectors:(Vector)_i :(Vector)_j :(Vector)_k	{ return _cxxShip->findBoundingBoxRelativeTo(other, _i, _j, _k); }
- (void) spawn:(const std::string &)roles_number	{ _cxxShip->spawn(roles_number); }
- (int) checkShipsInVicinityForWitchJumpExit	{ return _cxxShip->checkShipsInVicinityForWitchJumpExit(); }
- (BOOL) trackCloseContacts	{ return _cxxShip->getTrackCloseContacts(); }
- (void) setTrackCloseContacts:(BOOL)value	{ _cxxShip->setTrackCloseContacts(value); }
#if OO_SALVAGE_SUPPORT
- (void) claimAsSalvage	{ _cxxShip->claimAsSalvage(); }
- (void) sendCoordinatesToPilot	{ _cxxShip->sendCoordinatesToPilot(); }
#endif

@end


@implementation ShipEntity (OOSlice34)

#if OO_SALVAGE_SUPPORT
- (void) pilotArrived	{ _cxxShip->pilotArrived(); }
#endif
#ifndef NDEBUG
- (void) dumpSelfState	{ SHIP_PART(dumpSelfState()); }
#endif
- (OOScript *) script	{ return _cxxShip->getScript(); }
- (oo::PList) scriptInfo	{ return _cxxShip->getScriptInfo(); }
- (void) overrideScriptInfo:(const oo::PList &)override	{ _cxxShip->overrideScriptInfo(override); }
- (Entity *) entityForShaderProperties	{ return _cxxShip->entityForShaderProperties(); }
- (void) setDemoShip:(OOScalar)rate	{ _cxxShip->setDemoShip(rate); }
- (BOOL) isDemoShip	{ return _cxxShip->getIsDemoShip(); }
- (void) setDemoStartTime:(OOTimeAbsolute)time	{ _cxxShip->setDemoStartTime(time); }
- (OOTimeAbsolute) getDemoStartTime	{ return _cxxShip->getDemoStartTime(); }
- (void) doScriptEvent:(ooscript::PropertyId)message	{ _cxxShip->doScriptEvent(message); }
- (void) doScriptEvent:(ooscript::PropertyId)message withArgument:(id)argument	{ _cxxShip->doScriptEvent(message, argument); }
- (void) doScriptEvent:(ooscript::PropertyId)message withArgument:(id)argument1 andArgument:(id)argument2	{ _cxxShip->doScriptEvent(message, argument1, argument2); }
- (void) cxx_doScriptEvent:(ooscript::PropertyId)message withPListArguments:(const std::vector<oo::PList> &)arguments	{ _cxxShip->doScriptEvent(message, arguments); }
- (void) doScriptEvent:(ooscript::PropertyId)message withArguments:(ooscript::Value *)argv count:(unsigned)argc	{ _cxxShip->doScriptEvent(message, argv, argc); }
- (void) doScriptEvent:(ooscript::PropertyId)message inContext:(ooscript::Context)context withArguments:(ooscript::Value *)argv count:(unsigned)argc	{ SHIP_PART(doScriptEvent(message, context, argv, argc)); }
- (void) cxx_reactToAIMessage:(const std::string &)message context:(const std::optional<std::string> &)debugContext	{ _cxxShip->reactToAIMessage(message, debugContext); }
- (void) sendAIMessage:(const std::string &)message	{ _cxxShip->sendAIMessage(message); }
- (void) cxx_doScriptEvent:(ooscript::PropertyId)scriptEvent andReactToAIMessage:(const std::string &)aiMessage	{ _cxxShip->doScriptEvent(scriptEvent, aiMessage); }
- (void) cxx_doScriptEvent:(ooscript::PropertyId)scriptEvent withArgument:(id)argument andReactToAIMessage:(const std::string &)aiMessage	{ _cxxShip->doScriptEvent(scriptEvent, argument, aiMessage); }
- (OOAlertCondition) alertCondition	{ return SHIP_PART(alertCondition()); }
- (OOAlertCondition) realAlertCondition	{ return SHIP_PART(realAlertCondition()); }
- (void) doNothing	{ _cxxShip->doNothing(); }
#ifndef NDEBUG
- (std::optional<std::string>) descriptionForObjDump	{ return SHIP_PART(descriptionForObjDump()); }
#endif

@end


// The category ShipEntity (ScriptMethods) of ShipEntityScriptMethods.mm (bead oo-42dr), whose
// members are cxx::ShipEntity's, defined in that file.
@implementation ShipEntity (ScriptMethods)

- (ShipEntity *) ejectShipOfType:(const std::optional<std::string> &)shipKey	{ return _cxxShip->ejectShipOfType(shipKey); }
- (ShipEntity *) ejectShipOfRole:(const std::optional<std::string> &)role	{ return _cxxShip->ejectShipOfRole(role); }
- (std::vector<oo::ObjCRef<ShipEntity *>>) spawnShipsWithRole:(const std::string &)role count:(NSUInteger)count	{ return _cxxShip->spawnShipsWithRole(role, count); }

@end


// The category ShipEntity (LoadRestore) of ShipEntityLoadRestore.mm (bead oo-kw44), whose members
// are cxx::ShipEntity's, defined in that file.
@implementation ShipEntity (LoadRestore)

- (oo::PList) savedShipDictionaryWithContext:(OOShipSaveContext *)context	{ return _cxxShip->savedShipDictionaryWithContext(context); }
+ (id) shipRestoredFromDictionary:(const oo::PList &)dictionary useFallback:(BOOL)fallback context:(OOShipSaveContext *)context	{ return cxx::ShipEntity::shipRestoredFromDictionary(dictionary, fallback, context); }

@end


// ShipEntityAI.mm slice 1 (bead oo-iebuz): the category ShipEntity (AI).
@implementation ShipEntity (AI)

- (void) setAITo:(const std::string &)aiString	{ _cxxShip->setAITo(aiString); }
- (void) setAIScript:(const std::string &)aiString	{ _cxxShip->setAIScript(aiString); }
- (void) switchAITo:(const std::string &)aiString	{ _cxxShip->switchAITo(aiString); }
- (void) scanForHostiles	{ _cxxShip->scanForHostiles(); }
- (void) groupAttackTarget	{ _cxxShip->groupAttackTarget(); }
- (void) performAttack	{ _cxxShip->performAttack(); }
- (void) performCollect	{ _cxxShip->performCollect(); }
- (void) performEscort	{ _cxxShip->performEscort(); }
- (void) performFaceDestination	{ _cxxShip->performFaceDestination(); }
- (void) performFlee	{ _cxxShip->performFlee(); }
- (void) performFlyToRangeFromDestination	{ _cxxShip->performFlyToRangeFromDestination(); }
- (void) performHold	{ _cxxShip->performHold(); }
- (void) performIdle	{ _cxxShip->performIdle(); }
- (void) performIntercept	{ _cxxShip->performIntercept(); }
- (void) performLandOnPlanet	{ _cxxShip->performLandOnPlanet(); }
- (void) performMining	{ _cxxShip->performMining(); }
- (void) performScriptedAI	{ _cxxShip->performScriptedAI(); }
- (void) performScriptedAttackAI	{ _cxxShip->performScriptedAttackAI(); }
- (void) performBuoyTumble	{ _cxxShip->performBuoyTumble(); }
- (void) performStop	{ _cxxShip->performStop(); }
- (void) performTumble	{ _cxxShip->performTumble(); }
- (BOOL) performHyperSpaceToSpecificSystem:(OOSystemID)systemID	{ return _cxxShip->performHyperSpaceToSpecificSystem(systemID); }
- (void) requestDockingCoordinates	{ _cxxShip->requestDockingCoordinates(); }
- (void) recallDockingInstructions	{ _cxxShip->recallDockingInstructions(); }
- (void) scanForNearestIncomingMissile	{ _cxxShip->scanForNearestIncomingMissile(); }
- (void) enterPlayerWormhole	{ _cxxShip->enterPlayerWormhole(); }
- (void) enterTargetWormhole	{ _cxxShip->enterTargetWormhole(); }
- (void) wormholeEscorts	{ _cxxShip->wormholeEscorts(); }
- (void) wormholeEntireGroup	{ _cxxShip->wormholeEntireGroup(); }
- (BOOL) suggestEscortTo:(ShipEntity *)mother	{ return _cxxShip->suggestEscortTo(mother); }
- (void) broadcastDistressMessage	{ _cxxShip->broadcastDistressMessage(); }
- (void) broadcastDistressMessageWithDumping:(BOOL)dumpCargo	{ _cxxShip->broadcastDistressMessageWithDumping(dumpCargo); }

@end


// ShipEntityAI.mm slice 1 (bead oo-iebuz): the category ShipEntity (OOAIPrivate).
@implementation ShipEntity (OOAIPrivate)

- (void) checkFoundTarget	{ _cxxShip->checkFoundTarget(); }
- (BOOL) performHyperSpaceExitReplace:(BOOL)replace	{ return _cxxShip->performHyperSpaceExitReplace(replace); }
- (BOOL) performHyperSpaceExitReplace:(BOOL)replace toSystem:(OOSystemID)systemID	{ return _cxxShip->performHyperSpaceExitReplace(replace, systemID); }
- (void) scanForNearestShipWithPredicate:(EntityFilterPredicate)predicate parameter:(void *)parameter	{ _cxxShip->scanForNearestShipWithPredicate(predicate, parameter); }
- (void) scanForNearestShipWithNegatedPredicate:(EntityFilterPredicate)predicate parameter:(void *)parameter	{ _cxxShip->scanForNearestShipWithNegatedPredicate(predicate, parameter); }
- (void) acceptDistressMessageFrom:(ShipEntity *)other	{ SHIP_PART(acceptDistressMessageFrom(other)); }

@end


// ShipEntityAI.mm slice 1 (bead oo-iebuz): the category ShipEntity (OOAIStationStubs), which no
// header declares. The station's facade answered these selectors itself until bead oo-9ht.175
// (ADR-0056 amendment oo-9ht.175): a station's part answers them, with the station's signatures
// (a launcher answers the ship launched); any other ship's logs, as before, and answers nil.
@implementation ShipEntity (OOAIStationStubs)

- (void) increaseAlertLevel	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  station->increaseAlertLevel(); else  _cxxShip->increaseAlertLevel(); }
- (void) decreaseAlertLevel	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  station->decreaseAlertLevel(); else  _cxxShip->decreaseAlertLevel(); }
- (oo::PList) launchPolice	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  return station->launchPolice(); return _cxxShip->launchPolice(); }
- (ShipEntity *) launchDefenseShip	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  return station->launchDefenseShip(); _cxxShip->launchDefenseShip(); return nil; }
- (ShipEntity *) launchScavenger	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  return station->launchScavenger(); _cxxShip->launchScavenger(); return nil; }
- (ShipEntity *) launchMiner	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  return station->launchMiner(); _cxxShip->launchMiner(); return nil; }
- (ShipEntity *) launchPirateShip	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  return station->launchPirateShip(); _cxxShip->launchPirateShip(); return nil; }
- (ShipEntity *) launchShuttle	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  return station->launchShuttle(); _cxxShip->launchShuttle(); return nil; }
- (void) launchTrader	{ _cxxShip->launchTrader(); }
- (ShipEntity *) launchEscort	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  return station->launchEscort(); _cxxShip->launchEscort(); return nil; }
- (ShipEntity *) launchPatrol	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  return station->launchPatrol(); (void)_cxxShip->launchPatrol(); return nil; }
- (void) launchShipWithRole:(const std::string &)param	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  station->launchShipWithRole(param); else  _cxxShip->launchShipWithRole(param); }
- (void) abortAllDockings	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  station->abortAllDockings(); else  _cxxShip->abortAllDockings(); }

@end


// ShipEntityAI.mm slice 2 (bead oo-xurzn): the category ShipEntity (PureAI).
@implementation ShipEntity (OOAISlice2)

- (void) setStateTo:(const std::string &)state	{ _cxxShip->setStateTo(state); }
- (void) pauseAI:(const std::string &)intervalString	{ _cxxShip->pauseAI(intervalString); }
- (void) randomPauseAI:(const std::string &)intervalString	{ _cxxShip->randomPauseAI(intervalString); }
- (void) dropMessages:(const std::string &)messageString	{ _cxxShip->dropMessages(messageString); }
- (void) debugDumpPendingMessages	{ _cxxShip->debugDumpPendingMessages(); }
- (void) setDestinationToCurrentLocation	{ _cxxShip->setDestinationToCurrentLocation(); }
- (void) setDestinationToJinkPosition	{ _cxxShip->setDestinationToJinkPosition(); }
- (void) setDesiredRangeTo:(const std::string &)rangeString	{ _cxxShip->setDesiredRangeTo(rangeString); }
- (void) setDesiredRangeForWaypoint	{ _cxxShip->setDesiredRangeForWaypoint(); }
- (void) setSpeedTo:(const std::string &)speedString	{ _cxxShip->setSpeedTo(speedString); }
- (void) setSpeedFactorTo:(const std::string &)speedString	{ _cxxShip->setSpeedFactorTo(speedString); }
- (void) setSpeedToCruiseSpeed	{ _cxxShip->setSpeedToCruiseSpeed(); }
- (void) setThrustFactorTo:(const std::string &)thrustFactorString	{ _cxxShip->setThrustFactorTo(thrustFactorString); }
- (void) setTargetToPrimaryAggressor	{ _cxxShip->setTargetToPrimaryAggressor(); }
- (void) addPrimaryAggressorAsDefenseTarget	{ _cxxShip->addPrimaryAggressorAsDefenseTarget(); }
- (void) scanForNearestMerchantman	{ _cxxShip->scanForNearestMerchantman(); }
- (void) scanForRandomMerchantman	{ _cxxShip->scanForRandomMerchantman(); }
- (void) scanForLoot	{ _cxxShip->scanForLoot(); }
- (void) scanForRandomLoot	{ _cxxShip->scanForRandomLoot(); }
- (void) setTargetToFoundTarget	{ _cxxShip->setTargetToFoundTarget(); }
- (void) addFoundTargetAsDefenseTarget	{ _cxxShip->addFoundTargetAsDefenseTarget(); }
- (void) checkForFullHold	{ _cxxShip->checkForFullHold(); }
- (void) getWitchspaceEntryCoordinates	{ _cxxShip->getWitchspaceEntryCoordinates(); }
- (void) setDestinationFromCoordinates	{ _cxxShip->setDestinationFromCoordinates(); }
- (void) setCoordinatesFromPosition	{ _cxxShip->setCoordinatesFromPosition(); }
- (void) fightOrFleeMissile	{ _cxxShip->fightOrFleeMissile(); }
- (void) setCourseToPlanet	{ _cxxShip->setCourseToPlanet(); }
- (void) setTakeOffFromPlanet	{ _cxxShip->setTakeOffFromPlanet(); }
- (void) landOnPlanet	{ _cxxShip->landOnPlanet(); }
- (void) checkTargetLegalStatus	{ _cxxShip->checkTargetLegalStatus(); }
- (void) checkOwnLegalStatus	{ _cxxShip->checkOwnLegalStatus(); }
- (void) exitAIWithMessage:(const std::string &)message	{ _cxxShip->exitAIWithMessage(message); }
- (void) setDestinationToTarget	{ _cxxShip->setDestinationToTarget(); }
- (void) setDestinationWithinTarget	{ _cxxShip->setDestinationWithinTarget(); }
- (void) checkCourseToDestination	{ _cxxShip->checkCourseToDestination(); }

@end


// ShipEntityAI.mm slice 3 (bead oo-wc9o3): the category ShipEntity (PureAI).
@implementation ShipEntity (OOAISlice3)

- (void) checkAegis	{ _cxxShip->checkAegis(); }
- (void) checkEnergy	{ _cxxShip->checkEnergy(); }
- (void) checkHeatInsulation	{ _cxxShip->checkHeatInsulation(); }
- (void) findNewDefenseTarget	{ _cxxShip->findNewDefenseTarget(); }
- (void) scanForOffenders	{ _cxxShip->scanForOffenders(); }
- (void) setCourseToWitchpoint	{ _cxxShip->setCourseToWitchpoint(); }
- (void) setDestinationToWitchpoint	{ _cxxShip->setDestinationToWitchpoint(); }
- (void) setDestinationToStationBeacon	{ _cxxShip->setDestinationToStationBeacon(); }
- (void) performHyperSpaceExit	{ _cxxShip->performHyperSpaceExit(); }
- (void) performHyperSpaceExitWithoutReplacing	{ _cxxShip->performHyperSpaceExitWithoutReplacing(); }
- (void) disengageAutopilot	{ SHIP_PART(disengageAutopilot()); }
- (void) wormholeGroup	{ _cxxShip->wormholeGroup(); }
- (void) commsMessage:(const std::string &)valueString	{ SHIP_PART(commsMessage(valueString)); }
- (void) commsMessageByUnpiloted:(const std::string &)valueString	{ SHIP_PART(commsMessageByUnpiloted(valueString)); }
- (void) ejectCargo	{ _cxxShip->ejectCargo(); }
- (void) scanForThargoid	{ _cxxShip->scanForThargoid(); }
- (void) scanForNonThargoid	{ _cxxShip->scanForNonThargoid(); }
- (void) thargonCheckMother	{ _cxxShip->thargonCheckMother(); }
- (void) becomeUncontrolledThargon	{ _cxxShip->becomeUncontrolledThargon(); }
- (void) checkDistanceTravelled	{ _cxxShip->checkDistanceTravelled(); }
- (void) fightOrFleeHostiles	{ _cxxShip->fightOrFleeHostiles(); }
- (void) suggestEscort	{ _cxxShip->suggestEscort(); }
- (void) escortCheckMother	{ _cxxShip->escortCheckMother(); }
- (void) checkGroupOddsVersusTarget	{ _cxxShip->checkGroupOddsVersusTarget(); }
- (void) scanForFormationLeader	{ _cxxShip->scanForFormationLeader(); }
- (void) messageMother:(const std::string &)msgString	{ _cxxShip->messageMother(msgString); }
- (void) messageSelf:(const std::string &)msgString	{ _cxxShip->messageSelf(msgString); }
- (void) setPlanetPatrolCoordinates	{ _cxxShip->setPlanetPatrolCoordinates(); }
- (void) setSunSkimStartCoordinates	{ _cxxShip->setSunSkimStartCoordinates(); }
- (void) setSunSkimEndCoordinates	{ _cxxShip->setSunSkimEndCoordinates(); }
- (void) setSunSkimExitCoordinates	{ _cxxShip->setSunSkimExitCoordinates(); }
- (void) patrolReportIn	{ _cxxShip->patrolReportIn(); }
- (void) checkForMotherStation	{ _cxxShip->checkForMotherStation(); }
- (void) sendTargetCommsMessage:(const std::string &)message	{ _cxxShip->sendTargetCommsMessage(message); }
- (void) markTargetForFines	{ _cxxShip->markTargetForFines(); }
- (void) markTargetForOffence:(const std::string &)valueString	{ _cxxShip->markTargetForOffence(valueString); }
- (void) storeTarget	{ _cxxShip->storeTarget(); }

@end


// ShipEntityAI.mm slice 4 (bead oo-lqyhf): the category ShipEntity (PureAI).
@implementation ShipEntity (PureAI)

- (void) recallStoredTarget	{ _cxxShip->recallStoredTarget(); }
- (void) scanForRocks	{ _cxxShip->scanForRocks(); }
- (void) setDestinationToDockingAbort	{ _cxxShip->setDestinationToDockingAbort(); }
- (void) requestNewTarget	{ _cxxShip->requestNewTarget(); }
- (void) rollD:(const std::string &)die_number	{ _cxxShip->rollD(die_number); }
- (void) scanForNearestShipWithPrimaryRole:(const std::string &)scanRole	{ _cxxShip->scanForNearestShipWithPrimaryRole(scanRole); }
- (void) scanForNearestShipHavingRole:(const std::string &)scanRole	{ _cxxShip->scanForNearestShipHavingRole(scanRole); }
- (void) scanForNearestShipWithAnyPrimaryRole:(const std::string &)scanRoles	{ _cxxShip->scanForNearestShipWithAnyPrimaryRole(scanRoles); }
- (void) scanForNearestShipHavingAnyRole:(const std::string &)scanRoles	{ _cxxShip->scanForNearestShipHavingAnyRole(scanRoles); }
- (void) scanForNearestShipWithScanClass:(const std::string &)scanScanClass	{ _cxxShip->scanForNearestShipWithScanClass(scanScanClass); }
- (void) scanForNearestShipWithoutPrimaryRole:(const std::string &)scanRole	{ _cxxShip->scanForNearestShipWithoutPrimaryRole(scanRole); }
- (void) scanForNearestShipNotHavingRole:(const std::string &)scanRole	{ _cxxShip->scanForNearestShipNotHavingRole(scanRole); }
- (void) scanForNearestShipWithoutAnyPrimaryRole:(const std::string &)scanRoles	{ _cxxShip->scanForNearestShipWithoutAnyPrimaryRole(scanRoles); }
- (void) scanForNearestShipNotHavingAnyRole:(const std::string &)scanRoles	{ _cxxShip->scanForNearestShipNotHavingAnyRole(scanRoles); }
- (void) scanForNearestShipWithoutScanClass:(const std::string &)scanScanClass	{ _cxxShip->scanForNearestShipWithoutScanClass(scanScanClass); }
- (void) scanForNearestShipMatchingPredicate:(const std::string &)predicateExpression	{ _cxxShip->scanForNearestShipMatchingPredicate(predicateExpression); }
- (void) setCoordinates:(const std::string &)system_x_y_z	{ _cxxShip->setCoordinates(system_x_y_z); }
- (void) checkForNormalSpace	{ _cxxShip->checkForNormalSpace(); }
- (void) setTargetToRandomStation	{ _cxxShip->setTargetToRandomStation(); }
- (void) setTargetToLastStation	{ _cxxShip->setTargetToLastStation(); }
- (void) addFuel:(const std::string &)fuel_number	{ _cxxShip->addFuel(fuel_number); }
- (void) scriptActionOnTarget:(const std::string &)action	{ _cxxShip->scriptActionOnTarget(action); }
- (void) safeScriptActionOnTarget:(const std::string &)action	{ _cxxShip->safeScriptActionOnTarget(action); }
- (void) sendScriptMessage:(const std::string &)message	{ _cxxShip->sendScriptMessage(message); }
- (void) ai_throwSparks	{ _cxxShip->ai_throwSparks(); }
- (void) explodeSelf	{ _cxxShip->explodeSelf(); }
- (void) ai_debugMessage:(const std::string &)message	{ _cxxShip->ai_debugMessage(message); }
- (void) targetFirstBeaconWithCode:(const std::string &)code	{ _cxxShip->targetFirstBeaconWithCode(code); }
- (void) targetNextBeaconWithCode:(const std::string &)code	{ _cxxShip->targetNextBeaconWithCode(code); }
- (void) setRacepointsFromTarget	{ _cxxShip->setRacepointsFromTarget(); }
- (void) performFlyRacepoints	{ _cxxShip->performFlyRacepoints(); }

@end


/*	The player's selectors found by name (bead oo-9ht.177, ADR-0056 amendment oo-9ht.177). Since its
	facade was deleted, the player's Objective-C object is this facade, and the game still finds
	selectors on it by name: legacy-script actions and queries, AI actions, ship.call() and
	callObjC(), the string expander's keys, shader bindings, deferred calls and the joystick
	callback. These are exactly the selectors only the player's facade answered whose signature a
	by-name dispatcher can call (OOCallByName.h, OOJSCall.mm, OOShaderUniformMethodType.mm): no
	argument, or one std::string or oo::PList argument, and a void, property-list, scalar, vector,
	quaternion, matrix, point or object result. Each answers the player's C++ member, and nothing
	(zero) for any other ship; -respondsToSelector: answers them for the player's C++ part only,
	so every other ship still does not respond, as before. Not declared in a header: converted
	code calls the C++ members. They go with this facade.
*/
namespace {

PlayerEntity *PlayerEntityPart(cxx::ShipEntity *ship)
{
	return dynamic_cast<PlayerEntity *>(ship);
}


/*	The proxy's dials (bead oo-9ht.183): its facade, a subclass of this one, answered these itself
	(the shaders of the shipyard's and the doppelganger's ships bind them by name), so for a proxy's
	part these answer the proxy's members, and -respondsToSelector: answers them.
*/
ProxyPlayerEntity *ProxyPart(cxx::ShipEntity *ship)
{
	return dynamic_cast<ProxyPlayerEntity *>(ship);
}


bool IsProxySelectorCalledByName(SEL selector)
{
	static const std::unordered_set<std::string> names =
	{
		"fuelLeakRate", "massLocked", "atHyperspeed", "dialForwardShield", "dialAftShield",
		"dialMissileStatus", "dialFuelScoopStatus", "compassMode", "dialIdentEngaged",
		"trumbleCount", "tradeInFactor",
	};
	return names.contains(sel_getName(selector));
}


bool IsPlayerSelectorCalledByName(SEL selector)
{
	static const std::unordered_set<std::string> names =
	{
		"baseMass",
		"unloadCargoPods",
		"loadCargoPods",
		"deciCredits",
		"random_factor",
		"galaxyNumber",
		"galaxy_coordinates",
		"cursor_coordinates",
		"chart_centre_coordinates",
		"chart_zoom",
		"custom_chart_zoom",
		"custom_chart_centre_coordinates",
		"adjusted_chart_centre",
		"ANAMode",
		"systemID",
		"previousSystemID",
		"targetSystemID",
		"nextHopTargetSystemID",
		"infoSystemID",
		"nextInfoSystem",
		"previousInfoSystem",
		"homeInfoSystem",
		"targetInfoSystem",
		"infoSystemOnRoute",
		"cxx_commanderDataDictionary",
		"cxx_setCommanderDataFromDictionary:",
		"completeSetUp",
		"startUpComplete",
		"insideAtmosphereFraction",
		"updateMovementFlags",
		"updateAlertConditionForNearbyEntities",
		"updateAlertCondition",
		"checkScriptsIfAppropriate",
		"resetAutopilotAI",
#if OO_VARIABLE_TORUS_SPEED
		"hyperspeedFactor",
#endif
		"injectorsEngaged",
		"hyperspeedEngaged",
		"gameOverFadeToBW",
		"showGameOver",
		"updateTargeting",
		"breakPatternPosition",
		"viewpointOffset",
		"viewpointOffsetAft",
		"viewpointOffsetForward",
		"viewpointOffsetPort",
		"viewpointOffsetStarboard",
		"viewpointPosition",
		"massLockable",
		"massLocked",
		"atHyperspeed",
		"occlusionLevel",
		"setDockedAtMainStation",
		"dockedStation",
		"getTargetDockStation",
		"resetHud",
		"cxx_switchHudTo:",
		"cxx_dialCustomFloat:",
		"showDemoShips",
		"forwardShieldRechargeRate",
		"aftShieldRechargeRate",
		"forwardShieldLevel",
		"aftShieldLevel",
		"cxx_keyConfig",
		"isMouseControlOn",
		"dialRoll",
		"dialPitch",
		"dialYaw",
		"dialSpeed",
		"dialHyperSpeed",
		"dialForwardShield",
		"dialAftShield",
		"dialEnergy",
		"dialMaxEnergy",
		"dialFuel",
		"dialHyperRange",
		"dialAltitude",
		"clockTime",
		"clockTimeAdjusted",
		"clockAdjusting",
		"escapePodRescueTime",
		"countMissiles",
		"dialMissileStatus",
		"dialFuelScoopStatus",
		"fuelLeakRate",
		"addRoleForMining",
		"cxx_addRoleToPlayer:",
		"maxPlayerRoles",
		"updateSystemMemory",
		"compassTarget",
		"validateCompassTarget",
		"compassMode",
		"setPrevCompassMode",
		"setNextCompassMode",
		"activeMissile",
		"dialMaxMissiles",
		"dialIdentEngaged",
		"selectNextMultiFunctionDisplay",
		"selectPreviousMultiFunctionDisplay",
		"activeMFD",
		"safeAllMissiles",
		"tidyMissilePylons",
		"selectNextMissile",
		"clearAlertFlags",
		"alertFlags",
		"fleeingStatus",
		"cxx_mountMissileWithRole:",
		"cxx_assignToActivePylon:",
		"scannerFuzziness",
		"installedEnergyUnitType",
		"energyUnitType",
		"currentWeaponStats",
		"weaponsOnline",
		"fireMainWeapon",
		"createDoppelganger",
		"rotateCargo",
		"takeInternalDamage",
		"loseTargetStatus",
		"cxx_endScenario:",
		"docked",
		"witchStart",
		"witchEnd",
		"hyperspaceJumpDistance",
		"fuelRequiredForJump",
		"hasSufficientFuelForJump",
		"noteCompassLostTarget",
		"enterGalacticWitchspace",
		"setGuiToStatusScreen",
		"primedEquipmentCount",
		"legalStatusOfCargoList",
		"setGuiToSystemDataScreen",
		"setGuiToLongRangeChartScreen",
		"setGuiToShortRangeChartScreen",
		"setGuiToGameOptionsScreen",
		"setGuiToLoadSaveScreen",
		"highlightEquipShipScreenKey:",
		"availableFacings",
		"showInformationForSelectedUpgrade",
		"showInformationForSelectedInterface",
		"activateSelectedInterface",
		"setupStartScreenGui",
		"setGuiToOXZManager",
		"buySelectedItem",
		"tryBuyingItem:",
		"cxx_cargoQuantityForType:",
		"calculateCurrentCargo",
		"showMarketScreenHeaders",
		"setGuiToMarketScreen",
		"setGuiToMarketInfoScreen",
		"showMarketCashAndLoadLine",
		"guiScreen",
		"isSpeechOn",
		"addEquipmentWithScriptToCustomKeyArray:",
		"validateCustomEquipActivationArray",
		"addEquipmentFromCollection:",
		"getFined",
		"tradeInFactor",
		"renovationCosts",
		"renovationFactor",
		"setDefaultViewOffsets",
		"setDefaultCustomViews",
		"weaponViewOffset",
		"setUpTrumbles",
		"trumbleCount",
		"trumbleValue",
		"setTrumbleValueFrom:",
		"trumbleAppetiteAccumulator",
		"setScoopsActive",
		"clearTargetMemory",
		"customViewQuaternion",
		"customViewMatrix",
		"customViewOffset",
		"customViewRotationCenter",
		"customViewForwardVector",
		"customViewUpVector",
		"customViewRightVector",
		"resetCustomView",
		"setCustomViewData",
		"showInfoFlag",
		"cxx_missionOverlayDescriptor",
		"cxx_missionOverlayDescriptorOrDefault",
		"cxx_setMissionOverlayDescriptor:",
		"cxx_missionBackgroundDescriptor",
		"cxx_missionBackgroundDescriptorOrDefault",
		"cxx_setMissionBackgroundDescriptor:",
		"missionBackgroundSpecial",
		"cxx_setMissionBackgroundSpecial:",
		"missionExitScreen",
		"cxx_equipScreenBackgroundDescriptor",
		"cxx_setEquipScreenBackgroundDescriptor:",
		"scriptsLoaded",
		"galacticHyperspaceBehaviour",
		"galacticHyperspaceFixedCoords",
		"longRangeChartMode",
		"scoopOverride",
		"isDocked",
		"clearedToDock",
		"getDockingClearanceStatus",
		"penaltyForUnauthorizedDocking",
		"updateWormholes",
		"cxx_addMissionDestinationMarker:",
		"cxx_removeMissionDestinationMarker:",
		"cxx_getMissionDestinations",
		"clearExtraMissionKeys",
		"cxx_setExtraMissionKeys:",
		"score",
		"creditBalance",
		"dockedAtMainStation",
		"resetScannerZoom",
		"currentGalaxyID",
		"currentSystemID",
		"allowMissionInterrupt",
		"scriptTimer",
		"systemPseudoRandom100",
		"systemPseudoRandom256",
		"systemPseudoRandomFloat",
		"cxx_validatedMarker:",
		"commanderKillsAsString",
		"commanderBountyAsString",
		"creditsFormattedForSubstitution",
		"creditsFormattedForLegacySubstitution",
		"setUpSound",
		"setUpWeaponSounds",
		"destroySound",
		"isBeeping",
		"boop",
		"playIdentOn",
		"playIdentOff",
		"playIdentLockedOn",
		"playMissileArmed",
		"playMineArmed",
		"playMissileSafe",
		"playMissileLockedOn",
		"playNextEquipmentSelected",
		"playNextMissileSelected",
		"playWeaponsOnline",
		"playWeaponsOffline",
		"playCargoJettisioned",
		"playAutopilotOn",
		"playAutopilotOff",
		"playAutopilotOutOfRange",
		"playAutopilotCannotDockWithTarget",
		"playSaveOverwriteYes",
		"playSaveOverwriteNo",
		"playHoldFull",
		"playJumpMassLocked",
		"playTargetLost",
		"playNoTargetInMemory",
		"playTargetSwitched",
		"playHyperspaceNoTarget",
		"playHyperspaceNoFuel",
		"playHyperspaceBlocked",
		"playHyperspaceDistanceTooGreat",
		"playCloakingDeviceOn",
		"playCloakingDeviceOff",
		"playMenuNavigationUp",
		"playMenuNavigationDown",
		"playMenuNavigationNot",
		"playMenuPagePrevious",
		"playMenuPageNext",
		"playDismissedReportScreen",
		"playDismissedMissionScreen",
		"playChangedOption",
		"updateAfterburnerSound",
		"startAfterburnerSound",
		"stopAfterburnerSound",
		"playCloakingDeviceInsufficientEnergy",
		"playBuyCommodity",
		"playBuyShip",
		"playSellCommodity",
		"playCantBuyCommodity",
		"playCantSellCommodity",
		"playCantBuyShip",
		"playStandardHyperspace",
		"playGalacticHyperspace",
		"playHyperspaceAborted",
		"playHitByECMSound",
		"playFiredECMSound",
		"playLaunchFromStation",
		"playDockWithStation",
		"playExitWitchspace",
		"playHostileWarning",
		"playAlertConditionRed",
		"playEnergyLow",
		"playDockingDenied",
		"playWitchjumpFailure",
		"playWitchjumpMisjump",
		"playWitchjumpBlocked",
		"playWitchjumpDistanceTooGreat",
		"playWitchjumpInsufficientFuel",
		"playFuelLeak",
		"playEscapePodScooped",
		"playAegisCloseToPlanet",
		"playAegisCloseToStation",
		"playGameOver",
		"playLegacyScriptSound:",
		"cxx_scheduleAfterburnerSoundUpdate",
		"resetStickFunctions",
		"updateFunction:",
		"makeStickGuiDictHeader:",
		"initControls",
		"initKeyConfigSettings",
		"cxx_processKeyCode:",
		"checkNavKeyPress:",
		"checkKeyPress:",
		"getFirstKeyCode:",
		"handleGUIUpDownArrowKeys",
		"clearPlanetSearchString",
		"switchToMainView",
		"beginWitchspaceCountdown",
		"cancelWitchspaceCountdown",
		"pollApplicationControls",
		"pollMarketScreenControls",
		"handleGameOptionsScreenKeys",
		"handleKeyMapperScreenKeys",
		"handleKeyboardLayoutKeys",
		"handleStickMapperScreenKeys",
		"pollCustomViewControls",
		"pollViewControls",
		"pollGuiScreenControls",
		"handleUndockControl",
		"pollMissionInterruptControls",
		"handleMissionCallback",
		"setGuiToMissionEndScreen",
		"handleButtonIdent",
		"handleButtonTargetMissile",
		"initCheckingDictionary",
		"resetKeyFunctions",
		"entryIsDictCustomEquip:",
		"entryIsCustomEquip:",
		"getCustomEquipArray:",
		"getCustomEquipIndex:",
		"setGuiToKeyConfigScreen",
		"setGuiToKeyConfigEntryScreen",
		"setGuiToConfirmClearScreen",
		"makeKeyGuiDictHeader:",
		"entryIsEqualToDefault:",
		"saveKeySetting:",
		"unsetKeySetting:",
		"deleteKeySetting:",
		"deleteAllKeySettings",
		"loadKeySettings",
		"reloadPage",
		"scriptTarget",
		"checkScript",
		"cxx_scriptTestConditions:",
		"scriptTestCondition:",
		"cxx_missionVariables",
		"cxx_missionVariableForKey:",
		"cxx_missionsList",
		"setMissionDescription:",
		"clearMissionDescription",
		"clearMissionDescriptionForMission:",
		"mission_string",
		"status_string",
		"gui_screen_string",
		"galaxy_number",
		"planet_number",
		"score_number",
		"credits_number",
		"scriptTimer_number",
		"shipsFound_number",
		"commanderLegalStatus_number",
		"setLegalStatus:",
		"commanderLegalStatus_string",
		"d100_number",
		"pseudoFixedD100_number",
		"d256_number",
		"pseudoFixedD256_number",
		"clock_number",
		"clock_secs_number",
		"clock_mins_number",
		"clock_hours_number",
		"clock_days_number",
		"fuelLevel_number",
		"dockedAtMainStation_bool",
		"foundEquipment_bool",
		"sunWillGoNova_bool",
		"sunGoneNova_bool",
		"missionChoice_string",
		"missionKeyPress_string",
		"dockedTechLevel_number",
		"dockedStationName_string",
		"systemGovernment_string",
		"systemGovernment_number",
		"systemEconomy_string",
		"systemEconomy_number",
		"systemTechLevel_number",
		"systemPopulation_number",
		"systemProductivity_number",
		"commanderName_string",
		"commanderRank_string",
		"commanderShip_string",
		"commanderShipDisplayName_string",
		"consoleMessage3s:",
		"consoleMessage6s:",
		"awardCredits:",
		"awardShipKills:",
		"awardEquipment:",
		"removeEquipment:",
		"setPlanetinfo:",
		"setSpecificPlanetInfo:",
		"awardCargo:",
		"removeAllCargo",
		"useSpecialCargo:",
		"testForEquipment:",
		"awardFuel:",
		"messageShipAIs:",
		"ejectItem:",
		"addShips:",
		"addSystemShips:",
		"addShipsAt:",
		"addShipsAtPrecisely:",
		"addShipsWithinRadius:",
		"spawnShip:",
		"set:",
		"reset:",
		"increment:",
		"decrement:",
		"add:",
		"subtract:",
		"checkForShips:",
		"resetScriptTimer",
		"addMissionText:",
		"addLiteralMissionText:",
		"setMissionChoices:",
		"cxx_setMissionChoicesDictionary:",
		"resetMissionChoice",
		"clearMissionScreen",
		"addMissionDestination:",
		"removeMissionDestination:",
		"showShipModel:",
		"setMissionMusic:",
		"setMissionImage:",
		"setMissionBackground:",
		"setFuelLeak:",
		"fuelLeakRate_number",
		"setSunNovaIn:",
		"launchFromStation",
		"blowUpStation",
		"sendAllShipsAway",
		"addPlanet:",
		"addMoon:",
		"debugOn",
		"debugOff",
		"debugMessage:",
		"playSound:",
		"doMissionCallback",
		"clearMissionScreenID",
		"endMissionScreenAndNoteOpportunity",
		"setGuiToMissionScreen",
		"refreshMissionScreenTextEntry",
		"cxx_setBackgroundFromDescriptionsKey:",
		"cxx_addEqScriptForKey:",
		"cxx_removeEqScriptForKey:",
		"cxx_eqScriptIndexForKey:",
		"targetNearestHostile",
		"targetNearestIncomingMissile",
		"setGalacticHyperspaceBehaviourTo:",
		"setGalacticHyperspaceFixedCoordsTo:",
		"cxx_contractedVolumeForGood:",
		"cxx_addMessageToReport:",
		"reputation",
		"passengerReputation",
		"parcelReputation",
		"contractReputation",
		"erodeReputation",
		"normaliseReputation",
		"cxx_removePassenger:",
		"cxx_removeParcel:",
		"setGuiToManifestScreen",
		"setGuiToDockingReportScreen",
		"cxx_priceForShipKey:",
		"showShipyardInfoForSelection",
		"showTradeInInformationFooter",
		"missingSubEntitiesAdjustment",
		"tradeInValue",
		"buySelectedShip",
		"cxx_replaceShipWithNamedShip:",
		"loadPlayer",
		"savePlayer",
		"autosavePlayer",
		"quicksavePlayer",
		"addScenarioModel:",
		"showScenarioDetails",
		"startScenario",
#if OO_USE_CUSTOM_LOAD_SAVE
		"saveCommanderInputHandler",
#endif
#if OO_USE_CUSTOM_LOAD_SAVE
		"overwriteCommanderInputHandler",
#endif
#if OOLITE_USE_APPKIT_LOAD_SAVE
		"loadPlayerWithPanel",
#endif
#if OOLITE_USE_APPKIT_LOAD_SAVE
		"savePlayerWithPanel",
#endif
		"writePlayerToPath:",
		"nativeSavePlayer:",
#if OO_USE_CUSTOM_LOAD_SAVE
		"setGuiToLoadCommanderScreen",
#endif
#if OO_USE_CUSTOM_LOAD_SAVE
		"setGuiToSaveCommanderScreen:",
#endif
#if OO_USE_CUSTOM_LOAD_SAVE
		"setGuiToOverwriteScreen:",
#endif
#if OO_USE_CUSTOM_LOAD_SAVE
		"existingNativeSave:",
#endif
#if OO_USE_CUSTOM_LOAD_SAVE
		"findIndexOfCommander:",
#endif
	};
	return names.contains(sel_getName(selector));
}

}	// namespace


@implementation ShipEntity (OOPlayerSelectorsCalledByName)

- (BOOL) respondsToSelector:(SEL)selector
{
	// A subclass facade that answers the selector itself still does; a proxy's part answers its dials
	// (its facade answered them until bead oo-9ht.183).
	if (IsPlayerSelectorCalledByName(selector) && class_getMethodImplementation(object_getClass(self), selector) == class_getMethodImplementation([ShipEntity class], selector))
	{
		if (IsProxySelectorCalledByName(selector) && ProxyPart(_cxxShip) != nullptr)  return YES;
		return PlayerEntityPart(_cxxShip) != nullptr;
	}
	// A station's part answers the station's (bead oo-9ht.175), as its facade did.
	if (IsStationSelectorCalledByName(selector) && class_getMethodImplementation(object_getClass(self), selector) == class_getMethodImplementation([ShipEntity class], selector))
	{
		return StationPart(_cxxShip) != nullptr;
	}
	return [super respondsToSelector:selector];
}


- (GLfloat) baseMass	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->baseMass() : GLfloat{}; }
- (void) unloadCargoPods	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->unloadCargoPods(); }
- (void) loadCargoPods	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->loadCargoPods(); }
- (OOCreditsQuantity) deciCredits	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->deciCredits() : OOCreditsQuantity{}; }
- (int) random_factor	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->random_factor() : int{}; }
- (OOGalaxyID) galaxyNumber	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->galaxyNumber() : OOGalaxyID{}; }
- (NSPoint) galaxy_coordinates	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getGalaxy_coordinates() : NSMakePoint(0, 0); }
- (NSPoint) cursor_coordinates	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getCursor_coordinates() : NSMakePoint(0, 0); }
- (NSPoint) chart_centre_coordinates	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getChart_centre_coordinates() : NSMakePoint(0, 0); }
- (OOScalar) chart_zoom	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getChart_zoom() : OOScalar{}; }
- (OOScalar) custom_chart_zoom	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getCustom_chart_zoom() : OOScalar{}; }
- (NSPoint) custom_chart_centre_coordinates	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getCustom_chart_centre_coordinates() : NSMakePoint(0, 0); }
- (NSPoint) adjusted_chart_centre	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->adjusted_chart_centre() : NSMakePoint(0, 0); }
- (OORouteType) ANAMode	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->ANAMode() : OORouteType{}; }
- (OOSystemID) systemID	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->systemID() : OOSystemID{}; }
- (OOSystemID) previousSystemID	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->previousSystemID() : OOSystemID{}; }
- (OOSystemID) targetSystemID	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->targetSystemID() : OOSystemID{}; }
- (OOSystemID) nextHopTargetSystemID	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->nextHopTargetSystemID() : OOSystemID{}; }
- (OOSystemID) infoSystemID	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->infoSystemID() : OOSystemID{}; }
- (void) nextInfoSystem	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->nextInfoSystem(); }
- (void) previousInfoSystem	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->previousInfoSystem(); }
- (void) homeInfoSystem	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->homeInfoSystem(); }
- (void) targetInfoSystem	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->targetInfoSystem(); }
- (BOOL) infoSystemOnRoute	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->infoSystemOnRoute() : NO; }
- (oo::PList) cxx_commanderDataDictionary	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->commanderDataDictionary() : oo::PList(); }
- (BOOL) cxx_setCommanderDataFromDictionary:(const oo::PList &) dict	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->setCommanderDataFromDictionary(dict) : NO; }
- (void) completeSetUp	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->completeSetUp(); }
- (void) startUpComplete	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->startUpComplete(); }
- (GLfloat) insideAtmosphereFraction	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->insideAtmosphereFraction() : GLfloat{}; }
- (void) updateMovementFlags	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->updateMovementFlags(); }
- (void) updateAlertConditionForNearbyEntities	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->updateAlertConditionForNearbyEntities(); }
- (void) updateAlertCondition	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->updateAlertCondition(); }
- (void) checkScriptsIfAppropriate	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->checkScriptsIfAppropriate(); }
- (void) resetAutopilotAI	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->resetAutopilotAI(); }
#if OO_VARIABLE_TORUS_SPEED
- (GLfloat) hyperspeedFactor	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getHyperspeedFactor() : GLfloat{}; }
#endif
- (BOOL) injectorsEngaged	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->injectorsEngaged() : NO; }
- (BOOL) hyperspeedEngaged	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->hyperspeedEngaged() : NO; }
- (void) gameOverFadeToBW	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->gameOverFadeToBW(); }
- (void) showGameOver	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->showGameOver(); }
- (void) updateTargeting	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->updateTargeting(); }
- (HPVector) breakPatternPosition	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->breakPatternPosition() : kZeroHPVector; }
- (Vector) viewpointOffset	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->viewpointOffset() : kZeroVector; }
- (Vector) viewpointOffsetAft	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->viewpointOffsetAft() : kZeroVector; }
- (Vector) viewpointOffsetForward	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->viewpointOffsetForward() : kZeroVector; }
- (Vector) viewpointOffsetPort	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->viewpointOffsetPort() : kZeroVector; }
- (Vector) viewpointOffsetStarboard	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->viewpointOffsetStarboard() : kZeroVector; }
- (HPVector) viewpointPosition	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->viewpointPosition() : kZeroHPVector; }
- (BOOL) massLockable	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getMassLockable() : NO; }
- (BOOL) massLocked	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxShip))  return proxy->massLocked(); PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->massLocked() : NO; }
- (BOOL) atHyperspeed	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxShip))  return proxy->atHyperspeed(); PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->atHyperspeed() : NO; }
- (float) occlusionLevel	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->occlusionLevel() : float{}; }
- (void) setDockedAtMainStation	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setDockedAtMainStation(); }
- (ShipEntity *) dockedStation	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? oo::ToObjC(player->dockedStation()) : nil; }	// the station's object (bead oo-9ht.175), as the facade answered it
- (ShipEntity *) getTargetDockStation	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? oo::ToObjC(player->getTargetDockStation()) : nil; }	// the station's object (bead oo-9ht.175), as the facade answered it
- (void) resetHud	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->resetHud(); }
- (BOOL) cxx_switchHudTo:(const std::string &)hudFileName	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->switchHudTo(hudFileName) : NO; }
- (float) cxx_dialCustomFloat:(const std::string &)dialKey	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dialCustomFloat(dialKey) : float{}; }
- (BOOL) showDemoShips	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getShowDemoShips() : NO; }
- (float) forwardShieldRechargeRate	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->forwardShieldRechargeRate() : float{}; }
- (float) aftShieldRechargeRate	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->aftShieldRechargeRate() : float{}; }
- (GLfloat) forwardShieldLevel	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->forwardShieldLevel() : GLfloat{}; }
- (GLfloat) aftShieldLevel	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->aftShieldLevel() : GLfloat{}; }
- (oo::PList) cxx_keyConfig	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->keyConfig() : oo::PList(); }
- (BOOL) isMouseControlOn	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->isMouseControlOn() : NO; }
- (GLfloat) dialRoll	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dialRoll() : GLfloat{}; }
- (GLfloat) dialPitch	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dialPitch() : GLfloat{}; }
- (GLfloat) dialYaw	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dialYaw() : GLfloat{}; }
- (GLfloat) dialSpeed	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dialSpeed() : GLfloat{}; }
- (GLfloat) dialHyperSpeed	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dialHyperSpeed() : GLfloat{}; }
- (GLfloat) dialForwardShield	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxShip))  return proxy->dialForwardShield(); PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dialForwardShield() : GLfloat{}; }
- (GLfloat) dialAftShield	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxShip))  return proxy->dialAftShield(); PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dialAftShield() : GLfloat{}; }
- (GLfloat) dialEnergy	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dialEnergy() : GLfloat{}; }
- (GLfloat) dialMaxEnergy	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dialMaxEnergy() : GLfloat{}; }
- (GLfloat) dialFuel	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dialFuel() : GLfloat{}; }
- (GLfloat) dialHyperRange	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dialHyperRange() : GLfloat{}; }
- (GLfloat) dialAltitude	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dialAltitude() : GLfloat{}; }
- (double) clockTime	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->clockTime() : double{}; }
- (double) clockTimeAdjusted	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->clockTimeAdjusted() : double{}; }
- (BOOL) clockAdjusting	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->clockAdjusting() : NO; }
- (double) escapePodRescueTime	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->escapePodRescueTime() : double{}; }
- (unsigned) countMissiles	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->countMissiles() : unsigned{}; }
- (OOMissileStatus) dialMissileStatus	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxShip))  return proxy->dialMissileStatus(); PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dialMissileStatus() : OOMissileStatus{}; }
- (OOFuelScoopStatus) dialFuelScoopStatus	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxShip))  return proxy->dialFuelScoopStatus(); PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dialFuelScoopStatus() : OOFuelScoopStatus{}; }
- (float) fuelLeakRate	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxShip))  return proxy->fuelLeakRate(); PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->fuelLeakRate() : float{}; }
- (void) addRoleForMining	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->addRoleForMining(); }
- (void) cxx_addRoleToPlayer:(const std::string &)role	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->addRoleToPlayer(role); }
- (NSUInteger) maxPlayerRoles	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->maxPlayerRoles() : NSUInteger{}; }
- (void) updateSystemMemory	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->updateSystemMemory(); }
- (Entity *) compassTarget	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getCompassTarget() : nil; }
- (void) validateCompassTarget	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->validateCompassTarget(); }
- (OOCompassMode) compassMode	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxShip))  return proxy->compassMode(); PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getCompassMode() : OOCompassMode{}; }
- (void) setPrevCompassMode	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setPrevCompassMode(); }
- (void) setNextCompassMode	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setNextCompassMode(); }
- (NSUInteger) activeMissile	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getActiveMissile() : NSUInteger{}; }
- (NSUInteger) dialMaxMissiles	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dialMaxMissiles() : NSUInteger{}; }
- (BOOL) dialIdentEngaged	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxShip))  return proxy->dialIdentEngaged(); PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dialIdentEngaged() : NO; }
- (void) selectNextMultiFunctionDisplay	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->selectNextMultiFunctionDisplay(); }
- (void) selectPreviousMultiFunctionDisplay	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->selectPreviousMultiFunctionDisplay(); }
- (NSUInteger) activeMFD	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getActiveMFD() : NSUInteger{}; }
- (void) safeAllMissiles	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->safeAllMissiles(); }
- (void) tidyMissilePylons	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->tidyMissilePylons(); }
- (void) selectNextMissile	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->selectNextMissile(); }
- (void) clearAlertFlags	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->clearAlertFlags(); }
- (int) alertFlags	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getAlertFlags() : int{}; }
- (OOPlayerFleeingStatus) fleeingStatus	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->fleeingStatus() : OOPlayerFleeingStatus{}; }
- (BOOL) cxx_mountMissileWithRole:(const std::string &)role	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->mountMissileWithRole(role) : NO; }
- (BOOL) cxx_assignToActivePylon:(const std::string &)equipmentKey	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->assignToActivePylon(equipmentKey) : NO; }
- (double) scannerFuzziness	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->scannerFuzziness() : double{}; }
- (OOEnergyUnitType) installedEnergyUnitType	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->installedEnergyUnitType() : OOEnergyUnitType{}; }
- (OOEnergyUnitType) energyUnitType	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->energyUnitType() : OOEnergyUnitType{}; }
- (void) currentWeaponStats	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->currentWeaponStats(); }
- (BOOL) weaponsOnline	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->weaponsOnline() : NO; }
- (BOOL) fireMainWeapon	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->fireMainWeapon() : NO; }
- (ShipEntity *) createDoppelganger	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->createDoppelganger() : nil; }
- (void) rotateCargo	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->rotateCargo(); }
- (BOOL) takeInternalDamage	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->takeInternalDamage() : NO; }
- (void) loseTargetStatus	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->loseTargetStatus(); }
- (BOOL) cxx_endScenario:(const std::string &)key	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->endScenario(key) : NO; }
- (void) docked	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->docked(); }
- (void) witchStart	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->witchStart(); }
- (void) witchEnd	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->witchEnd(); }
- (double) hyperspaceJumpDistance	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->hyperspaceJumpDistance() : double{}; }
- (OOFuelQuantity) fuelRequiredForJump	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->fuelRequiredForJump() : OOFuelQuantity{}; }
- (BOOL) hasSufficientFuelForJump	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->hasSufficientFuelForJump() : NO; }
- (void) noteCompassLostTarget	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->noteCompassLostTarget(); }
- (void) enterGalacticWitchspace	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->enterGalacticWitchspace(); }
- (void) setGuiToStatusScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToStatusScreen(); }
- (NSUInteger) primedEquipmentCount	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->primedEquipmentCount() : NSUInteger{}; }
- (unsigned) legalStatusOfCargoList	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->legalStatusOfCargoList() : unsigned{}; }
- (void) setGuiToSystemDataScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToSystemDataScreen(); }
- (void) setGuiToLongRangeChartScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToLongRangeChartScreen(); }
- (void) setGuiToShortRangeChartScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToShortRangeChartScreen(); }
- (void) setGuiToGameOptionsScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToGameOptionsScreen(); }
- (void) setGuiToLoadSaveScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToLoadSaveScreen(); }
- (void) highlightEquipShipScreenKey:(const std::string &)highlightKey	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->highlightEquipShipScreenKey(highlightKey); }
- (OOWeaponFacingSet) availableFacings	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->availableFacings() : OOWeaponFacingSet{}; }
- (void) showInformationForSelectedUpgrade	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->showInformationForSelectedUpgrade(); }
- (void) showInformationForSelectedInterface	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->showInformationForSelectedInterface(); }
- (void) activateSelectedInterface	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->activateSelectedInterface(); }
- (void) setupStartScreenGui	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setupStartScreenGui(); }
- (void) setGuiToOXZManager	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToOXZManager(); }
- (void) buySelectedItem	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->buySelectedItem(); }
- (BOOL) tryBuyingItem:(const std::string &)eqKey	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->tryBuyingItem(eqKey) : NO; }
- (OOCargoQuantity) cxx_cargoQuantityForType:(const std::string &)type	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->cargoQuantityForType(type) : OOCargoQuantity{}; }
- (void) calculateCurrentCargo	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->calculateCurrentCargo(); }
- (void) showMarketScreenHeaders	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->showMarketScreenHeaders(); }
- (void) setGuiToMarketScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToMarketScreen(); }
- (void) setGuiToMarketInfoScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToMarketInfoScreen(); }
- (void) showMarketCashAndLoadLine	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->showMarketCashAndLoadLine(); }
- (OOGUIScreenID) guiScreen	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->guiScreen() : OOGUIScreenID{}; }
- (OOSpeechSettings) isSpeechOn	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getIsSpeechOn() : OOSpeechSettings{}; }
- (void) addEquipmentWithScriptToCustomKeyArray:(const std::string &)equipmentKey	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->addEquipmentWithScriptToCustomKeyArray(equipmentKey); }
- (void) validateCustomEquipActivationArray	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->validateCustomEquipActivationArray(); }
- (void) addEquipmentFromCollection:(const oo::PList &)equipment	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->addEquipmentFromCollection(equipment); }
- (void) getFined	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->getFined(); }
- (int) tradeInFactor	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxShip))  return proxy->tradeInFactor(); PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->tradeInFactor() : int{}; }
- (double) renovationCosts	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->renovationCosts() : double{}; }
- (double) renovationFactor	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->renovationFactor() : double{}; }
- (void) setDefaultViewOffsets	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setDefaultViewOffsets(); }
- (void) setDefaultCustomViews	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setDefaultCustomViews(); }
- (Vector) weaponViewOffset	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->weaponViewOffset() : kZeroVector; }
- (void) setUpTrumbles	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setUpTrumbles(); }
- (NSUInteger) trumbleCount	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxShip))  return proxy->trumbleCount(); PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getTrumbleCount() : NSUInteger{}; }
- (oo::PList)trumbleValue	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->trumbleValue() : oo::PList(); }
- (void) setTrumbleValueFrom:(const oo::PList &) trumbleValue	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setTrumbleValueFrom(trumbleValue); }
- (float) trumbleAppetiteAccumulator	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->trumbleAppetiteAccumulator() : float{}; }
- (void) setScoopsActive	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setScoopsActive(); }
- (void) clearTargetMemory	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->clearTargetMemory(); }
- (Quaternion) customViewQuaternion	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getCustomViewQuaternion() : kZeroQuaternion; }
- (OOMatrix) customViewMatrix	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getCustomViewMatrix() : kZeroMatrix; }
- (Vector) customViewOffset	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getCustomViewOffset() : kZeroVector; }
- (Vector) customViewRotationCenter	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getCustomViewRotationCenter() : kZeroVector; }
- (Vector) customViewForwardVector	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getCustomViewForwardVector() : kZeroVector; }
- (Vector) customViewUpVector	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getCustomViewUpVector() : kZeroVector; }
- (Vector) customViewRightVector	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getCustomViewRightVector() : kZeroVector; }
- (void) resetCustomView	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->resetCustomView(); }
- (void) setCustomViewData	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setCustomViewData(); }
- (BOOL) showInfoFlag	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->showInfoFlag() : NO; }
- (oo::PList) cxx_missionOverlayDescriptor	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->missionOverlayDescriptor() : oo::PList(); }
- (oo::PList) cxx_missionOverlayDescriptorOrDefault	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->missionOverlayDescriptorOrDefault() : oo::PList(); }
- (void) cxx_setMissionOverlayDescriptor:(const oo::PList &)descriptor	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setMissionOverlayDescriptor(descriptor); }
- (oo::PList) cxx_missionBackgroundDescriptor	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->missionBackgroundDescriptor() : oo::PList(); }
- (oo::PList) cxx_missionBackgroundDescriptorOrDefault	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->missionBackgroundDescriptorOrDefault() : oo::PList(); }
- (void) cxx_setMissionBackgroundDescriptor:(const oo::PList &)descriptor	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setMissionBackgroundDescriptor(descriptor); }
- (OOGUIBackgroundSpecial) missionBackgroundSpecial	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->missionBackgroundSpecial() : OOGUIBackgroundSpecial{}; }
- (void) cxx_setMissionBackgroundSpecial:(const std::string &)special	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setMissionBackgroundSpecial(special); }
- (OOGUIScreenID) missionExitScreen	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->missionExitScreen() : OOGUIScreenID{}; }
- (oo::PList) cxx_equipScreenBackgroundDescriptor	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->equipScreenBackgroundDescriptor() : oo::PList(); }
- (void) cxx_setEquipScreenBackgroundDescriptor:(const oo::PList &)descriptor	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setEquipScreenBackgroundDescriptor(descriptor); }
- (BOOL) scriptsLoaded	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->scriptsLoaded() : NO; }
- (OOGalacticHyperspaceBehaviour) galacticHyperspaceBehaviour	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getGalacticHyperspaceBehaviour() : OOGalacticHyperspaceBehaviour{}; }
- (NSPoint) galacticHyperspaceFixedCoords	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getGalacticHyperspaceFixedCoords() : NSMakePoint(0, 0); }
- (OOLongRangeChartMode) longRangeChartMode	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getLongRangeChartMode() : OOLongRangeChartMode{}; }
- (BOOL) scoopOverride	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getScoopOverride() : NO; }
- (BOOL) isDocked	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->isDocked() : NO; }
- (BOOL)clearedToDock	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->clearedToDock() : NO; }
- (OODockingClearanceStatus)getDockingClearanceStatus	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getDockingClearanceStatus() : OODockingClearanceStatus{}; }
- (void)penaltyForUnauthorizedDocking	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->penaltyForUnauthorizedDocking(); }
- (void)updateWormholes	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->updateWormholes(); }
- (void) cxx_addMissionDestinationMarker:(const oo::PList &)marker	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->addMissionDestinationMarker(marker); }
- (BOOL) cxx_removeMissionDestinationMarker:(const oo::PList &)marker	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->removeMissionDestinationMarker(marker) : NO; }
- (oo::PList) cxx_getMissionDestinations	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getMissionDestinations() : oo::PList(); }
- (void) clearExtraMissionKeys	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->clearExtraMissionKeys(); }
- (void) cxx_setExtraMissionKeys:(const oo::PList &)keys	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setExtraMissionKeys(keys); }
- (unsigned) score	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->score() : unsigned{}; }
- (double) creditBalance	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->creditBalance() : double{}; }
- (BOOL) dockedAtMainStation	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dockedAtMainStation() : NO; }
- (void) resetScannerZoom	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->resetScannerZoom(); }
- (OOGalaxyID) currentGalaxyID	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->currentGalaxyID() : OOGalaxyID{}; }
- (OOSystemID) currentSystemID	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->currentSystemID() : OOSystemID{}; }
- (void) allowMissionInterrupt	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->allowMissionInterrupt(); }
- (OOTimeDelta) scriptTimer	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->scriptTimer() : OOTimeDelta{}; }
- (unsigned) systemPseudoRandom100	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->systemPseudoRandom100() : unsigned{}; }
- (unsigned) systemPseudoRandom256	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->systemPseudoRandom256() : unsigned{}; }
- (double) systemPseudoRandomFloat	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->systemPseudoRandomFloat() : double{}; }
- (oo::PList) cxx_validatedMarker:(const oo::PList &)marker	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->validatedMarker(marker) : oo::PList(); }
- (oo::PList) commanderKillsAsString
{
	PlayerEntity *player = PlayerEntityPart(_cxxShip);
	if (player == nullptr)  return oo::PList();
 const auto result = player->commanderKillsAsString(); return result.has_value() ? oo::PList(*result) : oo::PList();
}
- (oo::PList) commanderBountyAsString
{
	PlayerEntity *player = PlayerEntityPart(_cxxShip);
	if (player == nullptr)  return oo::PList();
 const auto result = player->commanderBountyAsString(); return result.has_value() ? oo::PList(*result) : oo::PList();
}
- (oo::PList) creditsFormattedForSubstitution
{
	PlayerEntity *player = PlayerEntityPart(_cxxShip);
	if (player == nullptr)  return oo::PList();
 const auto result = player->creditsFormattedForSubstitution(); return result.has_value() ? oo::PList(*result) : oo::PList();
}
- (oo::PList) creditsFormattedForLegacySubstitution
{
	PlayerEntity *player = PlayerEntityPart(_cxxShip);
	if (player == nullptr)  return oo::PList();
 const auto result = player->creditsFormattedForLegacySubstitution(); return result.has_value() ? oo::PList(*result) : oo::PList();
}
- (void) setUpSound	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setUpSound(); }
- (void) setUpWeaponSounds	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setUpWeaponSounds(); }
- (void) destroySound	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->destroySound(); }
- (BOOL) isBeeping	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->isBeeping() : NO; }
- (void) boop	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->boop(); }
- (void) playIdentOn	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playIdentOn(); }
- (void) playIdentOff	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playIdentOff(); }
- (void) playIdentLockedOn	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playIdentLockedOn(); }
- (void) playMissileArmed	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playMissileArmed(); }
- (void) playMineArmed	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playMineArmed(); }
- (void) playMissileSafe	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playMissileSafe(); }
- (void) playMissileLockedOn	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playMissileLockedOn(); }
- (void) playNextEquipmentSelected	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playNextEquipmentSelected(); }
- (void) playNextMissileSelected	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playNextMissileSelected(); }
- (void) playWeaponsOnline	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playWeaponsOnline(); }
- (void) playWeaponsOffline	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playWeaponsOffline(); }
- (void) playCargoJettisioned	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playCargoJettisioned(); }
- (void) playAutopilotOn	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playAutopilotOn(); }
- (void) playAutopilotOff	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playAutopilotOff(); }
- (void) playAutopilotOutOfRange	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playAutopilotOutOfRange(); }
- (void) playAutopilotCannotDockWithTarget	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playAutopilotCannotDockWithTarget(); }
- (void) playSaveOverwriteYes	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playSaveOverwriteYes(); }
- (void) playSaveOverwriteNo	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playSaveOverwriteNo(); }
- (void) playHoldFull	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playHoldFull(); }
- (void) playJumpMassLocked	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playJumpMassLocked(); }
- (void) playTargetLost	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playTargetLost(); }
- (void) playNoTargetInMemory	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playNoTargetInMemory(); }
- (void) playTargetSwitched	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playTargetSwitched(); }
- (void) playHyperspaceNoTarget	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playHyperspaceNoTarget(); }
- (void) playHyperspaceNoFuel	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playHyperspaceNoFuel(); }
- (void) playHyperspaceBlocked	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playHyperspaceBlocked(); }
- (void) playHyperspaceDistanceTooGreat	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playHyperspaceDistanceTooGreat(); }
- (void) playCloakingDeviceOn	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playCloakingDeviceOn(); }
- (void) playCloakingDeviceOff	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playCloakingDeviceOff(); }
- (void) playMenuNavigationUp	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playMenuNavigationUp(); }
- (void) playMenuNavigationDown	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playMenuNavigationDown(); }
- (void) playMenuNavigationNot	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playMenuNavigationNot(); }
- (void) playMenuPagePrevious	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playMenuPagePrevious(); }
- (void) playMenuPageNext	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playMenuPageNext(); }
- (void) playDismissedReportScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playDismissedReportScreen(); }
- (void) playDismissedMissionScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playDismissedMissionScreen(); }
- (void) playChangedOption	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playChangedOption(); }
- (void) updateAfterburnerSound	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->updateAfterburnerSound(); }
- (void) startAfterburnerSound	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->startAfterburnerSound(); }
- (void) stopAfterburnerSound	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->stopAfterburnerSound(); }
- (void) playCloakingDeviceInsufficientEnergy	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playCloakingDeviceInsufficientEnergy(); }
- (void) playBuyCommodity	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playBuyCommodity(); }
- (void) playBuyShip	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playBuyShip(); }
- (void) playSellCommodity	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playSellCommodity(); }
- (void) playCantBuyCommodity	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playCantBuyCommodity(); }
- (void) playCantSellCommodity	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playCantSellCommodity(); }
- (void) playCantBuyShip	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playCantBuyShip(); }
- (void) playStandardHyperspace	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playStandardHyperspace(); }
- (void) playGalacticHyperspace	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playGalacticHyperspace(); }
- (void) playHyperspaceAborted	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playHyperspaceAborted(); }
- (void) playHitByECMSound	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playHitByECMSound(); }
- (void) playFiredECMSound	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playFiredECMSound(); }
- (void) playLaunchFromStation	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playLaunchFromStation(); }
- (void) playDockWithStation	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playDockWithStation(); }
- (void) playExitWitchspace	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playExitWitchspace(); }
- (void) playHostileWarning	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playHostileWarning(); }
- (void) playAlertConditionRed	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playAlertConditionRed(); }
- (void) playEnergyLow	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playEnergyLow(); }
- (void) playDockingDenied	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playDockingDenied(); }
- (void) playWitchjumpFailure	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playWitchjumpFailure(); }
- (void) playWitchjumpMisjump	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playWitchjumpMisjump(); }
- (void) playWitchjumpBlocked	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playWitchjumpBlocked(); }
- (void) playWitchjumpDistanceTooGreat	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playWitchjumpDistanceTooGreat(); }
- (void) playWitchjumpInsufficientFuel	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playWitchjumpInsufficientFuel(); }
- (void) playFuelLeak	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playFuelLeak(); }
- (void) playEscapePodScooped	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playEscapePodScooped(); }
- (void) playAegisCloseToPlanet	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playAegisCloseToPlanet(); }
- (void) playAegisCloseToStation	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playAegisCloseToStation(); }
- (void) playGameOver	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playGameOver(); }
- (void) playLegacyScriptSound:(const std::string &)key	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playLegacyScriptSound(key); }
- (void) cxx_scheduleAfterburnerSoundUpdate	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  OOScheduleDeferredCall(oo::ToObjC(player), @selector(updateAfterburnerSound), nil, 1.25); }
- (void) resetStickFunctions	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->resetStickFunctions(); }
- (void) updateFunction: (const oo::PList &)hwDict	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->updateFunction(hwDict); }
- (oo::PList)makeStickGuiDictHeader:(const std::string &)header	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->makeStickGuiDictHeader(header) : oo::PList(); }
- (void) initControls	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->initControls(); }
- (void) initKeyConfigSettings	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->initKeyConfigSettings(); }
- (oo::PList) cxx_processKeyCode:(const oo::PList &)key_def	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->processKeyCode(key_def) : oo::PList(); }
- (BOOL) checkNavKeyPress:(const oo::PList &)key_def	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->checkNavKeyPress(key_def) : NO; }
- (BOOL) checkKeyPress:(const oo::PList &)key_def	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->checkKeyPress(key_def) : NO; }
- (int) getFirstKeyCode:(const oo::PList &)key_def	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getFirstKeyCode(key_def) : int{}; }
- (BOOL) handleGUIUpDownArrowKeys	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->handleGUIUpDownArrowKeys() : NO; }
- (void) clearPlanetSearchString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->clearPlanetSearchString(); }
- (void) switchToMainView	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->switchToMainView(); }
-(void) beginWitchspaceCountdown	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->beginWitchspaceCountdown(); }
-(void) cancelWitchspaceCountdown	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->cancelWitchspaceCountdown(); }
- (void) pollApplicationControls	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->pollApplicationControls(); }
- (void) pollMarketScreenControls	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->pollMarketScreenControls(); }
- (void) handleGameOptionsScreenKeys	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->handleGameOptionsScreenKeys(); }
- (void) handleKeyMapperScreenKeys	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->handleKeyMapperScreenKeys(); }
- (void) handleKeyboardLayoutKeys	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->handleKeyboardLayoutKeys(); }
- (void) handleStickMapperScreenKeys	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->handleStickMapperScreenKeys(); }
- (void) pollCustomViewControls	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->pollCustomViewControls(); }
- (void) pollViewControls	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->pollViewControls(); }
- (void) pollGuiScreenControls	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->pollGuiScreenControls(); }
- (void) handleUndockControl	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->handleUndockControl(); }
- (void) pollMissionInterruptControls	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->pollMissionInterruptControls(); }
- (void) handleMissionCallback	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->handleMissionCallback(); }
- (void) setGuiToMissionEndScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToMissionEndScreen(); }
- (void) handleButtonIdent	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->handleButtonIdent(); }
- (void) handleButtonTargetMissile	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->handleButtonTargetMissile(); }
- (void) initCheckingDictionary	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->initCheckingDictionary(); }
- (void) resetKeyFunctions	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->resetKeyFunctions(); }
- (BOOL) entryIsDictCustomEquip:(const oo::PList &)dict	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->entryIsDictCustomEquip(dict) : NO; }
- (BOOL) entryIsCustomEquip:(const std::string &)entry	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->entryIsCustomEquip(entry) : NO; }
- (oo::PList) getCustomEquipArray:(const std::string &)key_def	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getCustomEquipArray(key_def) : oo::PList(); }
- (NSUInteger) getCustomEquipIndex:(const std::string &)key_def	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getCustomEquipIndex(key_def) : NSUInteger{}; }
- (void) setGuiToKeyConfigScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToKeyConfigScreen(); }
- (void) setGuiToKeyConfigEntryScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToKeyConfigEntryScreen(); }
- (void) setGuiToConfirmClearScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToConfirmClearScreen(); }
- (oo::PList)makeKeyGuiDictHeader:(const std::string &)header	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->makeKeyGuiDictHeader(header) : oo::PList(); }
- (BOOL) entryIsEqualToDefault:(const std::string &)key	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->entryIsEqualToDefault(key) : NO; }
- (void) saveKeySetting:(const std::string &)key	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->saveKeySetting(key); }
- (void) unsetKeySetting:(const std::string &)key	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->unsetKeySetting(key); }
- (void) deleteKeySetting:(const std::string &)key	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->deleteKeySetting(key); }
- (void) deleteAllKeySettings	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->deleteAllKeySettings(); }
- (oo::PList) loadKeySettings	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->loadKeySettings() : oo::PList(); }
- (void) reloadPage	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->reloadPage(); }
- (ShipEntity*) scriptTarget	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->scriptTarget() : nil; }
- (void) checkScript	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->checkScript(); }
- (BOOL) cxx_scriptTestConditions:(const oo::PList &)array	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->scriptTestConditions(array) : NO; }
- (BOOL) scriptTestCondition:(const oo::PList &)scriptCondition	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->scriptTestCondition(scriptCondition) : NO; }
- (oo::PList) cxx_missionVariables	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->missionVariables() : oo::PList(); }
- (oo::PList) cxx_missionVariableForKey:(const std::string &)key	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->missionVariableForKey(key) : oo::PList(); }
- (oo::PList) cxx_missionsList	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->missionsList() : oo::PList(); }
- (void) setMissionDescription:(const std::string &)textKey	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setMissionDescription(textKey); }
- (void) clearMissionDescription	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->clearMissionDescription(); }
- (void) clearMissionDescriptionForMission:(const std::string &)key	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->clearMissionDescriptionForMission(key); }
- (oo::PList) mission_string	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->mission_string() : oo::PList(); }
- (oo::PList) status_string	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->status_string() : oo::PList(); }
- (oo::PList) gui_screen_string	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->gui_screen_string() : oo::PList(); }
- (oo::PList) galaxy_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getGalaxy_number() : oo::PList(); }
- (oo::PList) planet_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->planet_number() : oo::PList(); }
- (oo::PList) score_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->score_number() : oo::PList(); }
- (oo::PList) credits_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->credits_number() : oo::PList(); }
- (oo::PList) scriptTimer_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->scriptTimer_number() : oo::PList(); }
- (oo::PList) shipsFound_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->shipsFound_number() : oo::PList(); }
- (oo::PList) commanderLegalStatus_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->commanderLegalStatus_number() : oo::PList(); }
- (void) setLegalStatus:(const std::string &)valueString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setLegalStatus(valueString); }
- (oo::PList) commanderLegalStatus_string	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->commanderLegalStatus_string() : oo::PList(); }
- (oo::PList) d100_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->d100_number() : oo::PList(); }
- (oo::PList) pseudoFixedD100_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->pseudoFixedD100_number() : oo::PList(); }
- (oo::PList) d256_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->d256_number() : oo::PList(); }
- (oo::PList) pseudoFixedD256_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->pseudoFixedD256_number() : oo::PList(); }
- (oo::PList) clock_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->clock_number() : oo::PList(); }
- (oo::PList) clock_secs_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->clock_secs_number() : oo::PList(); }
- (oo::PList) clock_mins_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->clock_mins_number() : oo::PList(); }
- (oo::PList) clock_hours_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->clock_hours_number() : oo::PList(); }
- (oo::PList) clock_days_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->clock_days_number() : oo::PList(); }
- (oo::PList) fuelLevel_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->fuelLevel_number() : oo::PList(); }
- (oo::PList) dockedAtMainStation_bool	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dockedAtMainStation_bool() : oo::PList(); }
- (oo::PList) foundEquipment_bool	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->foundEquipment_bool() : oo::PList(); }
- (oo::PList) sunWillGoNova_bool	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->sunWillGoNova_bool() : oo::PList(); }
- (oo::PList) sunGoneNova_bool	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->sunGoneNova_bool() : oo::PList(); }
- (oo::PList) missionChoice_string	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->missionChoice_string() : oo::PList(); }
- (oo::PList) missionKeyPress_string	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->missionKeyPress_string() : oo::PList(); }
- (oo::PList) dockedTechLevel_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dockedTechLevel_number() : oo::PList(); }
- (oo::PList) dockedStationName_string	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->dockedStationName_string() : oo::PList(); }
- (oo::PList) systemGovernment_string	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->systemGovernment_string() : oo::PList(); }
- (oo::PList) systemGovernment_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->systemGovernment_number() : oo::PList(); }
- (oo::PList) systemEconomy_string	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->systemEconomy_string() : oo::PList(); }
- (oo::PList) systemEconomy_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->systemEconomy_number() : oo::PList(); }
- (oo::PList) systemTechLevel_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->systemTechLevel_number() : oo::PList(); }
- (oo::PList) systemPopulation_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->systemPopulation_number() : oo::PList(); }
- (oo::PList) systemProductivity_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->systemProductivity_number() : oo::PList(); }
- (oo::PList) commanderName_string	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->commanderName_string() : oo::PList(); }
- (oo::PList) commanderRank_string	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->commanderRank_string() : oo::PList(); }
- (oo::PList) commanderShip_string	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->commanderShip_string() : oo::PList(); }
- (oo::PList) commanderShipDisplayName_string	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->commanderShipDisplayName_string() : oo::PList(); }
- (void) consoleMessage3s:(const std::string &)valueString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->consoleMessage3s(valueString); }
- (void) consoleMessage6s:(const std::string &)valueString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->consoleMessage6s(valueString); }
- (void) awardCredits:(const std::string &)valueString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->awardCredits(valueString); }
- (void) awardShipKills:(const std::string &)valueString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->awardShipKills(valueString); }
- (void) awardEquipment:(const std::string &)equipString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->awardEquipment(equipString); }
- (void) removeEquipment:(const std::string &)equipString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->removeEquipment(equipString); }
- (void) setPlanetinfo:(const std::string &)key_valueString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setPlanetinfo(key_valueString); }
- (void) setSpecificPlanetInfo:(const std::string &)key_valueString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setSpecificPlanetInfo(key_valueString); }
- (void) awardCargo:(const std::string &)amount_typeString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->awardCargo(amount_typeString); }
- (void) removeAllCargo	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->removeAllCargo(); }
- (void) useSpecialCargo:(const std::string &)descriptionString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->useSpecialCargo(descriptionString); }
- (void) testForEquipment:(const std::string &)equipString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->testForEquipment(equipString); }
- (void) awardFuel:(const std::string &)valueString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->awardFuel(valueString); }
- (void) messageShipAIs:(const std::string &)roles_message	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->messageShipAIs(roles_message); }
- (void) ejectItem:(const std::string &)itemKey	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->ejectItem(itemKey); }
- (void) addShips:(const std::string &)roles_number	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->addShips(roles_number); }
- (void) addSystemShips:(const std::string &)roles_number_position	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->addSystemShips(roles_number_position); }
- (void) addShipsAt:(const std::string &)roles_number_system_x_y_z	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->addShipsAt(roles_number_system_x_y_z); }
- (void) addShipsAtPrecisely:(const std::string &)roles_number_system_x_y_z	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->addShipsAtPrecisely(roles_number_system_x_y_z); }
- (void) addShipsWithinRadius:(const std::string &)roles_number_system_x_y_z_r	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->addShipsWithinRadius(roles_number_system_x_y_z_r); }
- (void) spawnShip:(const std::string &)ship_key	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->spawnShip(ship_key); }
- (void) set:(const std::string &)missionvariable_value	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->set(missionvariable_value); }
- (void) reset:(const std::string &)missionvariable	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->reset(missionvariable); }
- (void) increment:(const std::string &)missionVariableObject	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->increment(missionVariableObject); }
- (void) decrement:(const std::string &)missionVariableObject	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->decrement(missionVariableObject); }
- (void) add:(const std::string &)missionVariableString_value	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->add(missionVariableString_value); }
- (void) subtract:(const std::string &)missionVariableString_value	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->subtract(missionVariableString_value); }
- (void) checkForShips:(const std::string &)roleString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->checkForShips(roleString); }
- (void) resetScriptTimer	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->resetScriptTimer(); }
- (void) addMissionText:(const std::string &)textKey	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->addMissionText(textKey); }
- (void) addLiteralMissionText:(const std::string &)text	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->addLiteralMissionText(text); }
- (void) setMissionChoices:(const std::string &)choicesKey	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setMissionChoices(choicesKey); }
- (void) cxx_setMissionChoicesDictionary:(const oo::PList &)choicesDict	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setMissionChoicesDictionary(choicesDict); }
- (void) resetMissionChoice	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->resetMissionChoice(); }
- (void) clearMissionScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->clearMissionScreen(); }
- (void) addMissionDestination:(const std::string &)destinations	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->addMissionDestination(destinations); }
- (void) removeMissionDestination:(const std::string &)destinations	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->removeMissionDestination(destinations); }
- (void) showShipModel:(const std::string &)role	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->showShipModel(role); }
- (void) setMissionMusic:(const std::string &)value	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setMissionMusic(value); }
- (void) setMissionImage:(const std::string &)value	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setMissionImage(value); }
- (void) setMissionBackground:(const std::string &)value	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setMissionBackground(value); }
- (void) setFuelLeak:(const std::string &)value	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setFuelLeak(value); }
- (oo::PList) fuelLeakRate_number	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->fuelLeakRate_number() : oo::PList(); }
- (void) setSunNovaIn:(const std::string &)time_value	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setSunNovaIn(time_value); }
- (void) launchFromStation	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->launchFromStation(); }
- (void) blowUpStation	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->blowUpStation(); }
- (void) sendAllShipsAway	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->sendAllShipsAway(); }
- (void) addPlanet:(const std::string &)planetKey	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->addPlanet(planetKey); }
- (void) addMoon:(const std::string &)moonKey	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->addMoon(moonKey); }
- (void) debugOn	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->debugOn(); }
- (void) debugOff	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->debugOff(); }
- (void) debugMessage:(const std::string &)args	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->debugMessage(args); }
- (void) playSound:(const std::string &)soundName	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->playSound(soundName); }
- (void) doMissionCallback	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->doMissionCallback(); }
- (void) clearMissionScreenID	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->clearMissionScreenID(); }
- (void) endMissionScreenAndNoteOpportunity	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->endMissionScreenAndNoteOpportunity(); }
- (void) setGuiToMissionScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToMissionScreen(); }
- (void) refreshMissionScreenTextEntry	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->refreshMissionScreenTextEntry(); }
- (void) cxx_setBackgroundFromDescriptionsKey:(const std::string &)d_key	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setBackgroundFromDescriptionsKey(d_key); }
- (BOOL) cxx_addEqScriptForKey:(const std::string &)eq_key	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->addEqScriptForKey(eq_key) : NO; }
- (void) cxx_removeEqScriptForKey:(const std::string &)eq_key	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->removeEqScriptForKey(eq_key); }
- (NSUInteger) cxx_eqScriptIndexForKey:(const std::string &)eq_key	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->eqScriptIndexForKey(eq_key) : NSUInteger{}; }
- (void) targetNearestHostile	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->targetNearestHostile(); }
- (void) targetNearestIncomingMissile	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->targetNearestIncomingMissile(); }
- (void) setGalacticHyperspaceBehaviourTo:(const std::string &)galacticHyperspaceBehaviourString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGalacticHyperspaceBehaviourTo(galacticHyperspaceBehaviourString); }
- (void) setGalacticHyperspaceFixedCoordsTo:(const std::string &)galacticHyperspaceFixedCoordsString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGalacticHyperspaceFixedCoordsTo(galacticHyperspaceFixedCoordsString); }
- (OOCargoQuantity) cxx_contractedVolumeForGood:(const std::string &) good	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->contractedVolumeForGood(good) : OOCargoQuantity{}; }
- (void) cxx_addMessageToReport:(const std::string &) report	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->addMessageToReport(report); }
- (oo::PList) reputation	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->getReputation() : oo::PList(); }
- (int) passengerReputation	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->passengerReputation() : int{}; }
- (int) parcelReputation	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->parcelReputation() : int{}; }
- (int) contractReputation	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->contractReputation() : int{}; }
- (void) erodeReputation	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->erodeReputation(); }
- (void) normaliseReputation	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->normaliseReputation(); }
- (BOOL) cxx_removePassenger:(const std::string &)Name	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->removePassenger(Name) : NO; }
- (BOOL) cxx_removeParcel:(const std::string &)Name	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->removeParcel(Name) : NO; }
- (void) setGuiToManifestScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToManifestScreen(); }
- (void) setGuiToDockingReportScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToDockingReportScreen(); }
- (OOCreditsQuantity) cxx_priceForShipKey:(const std::string &)key	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->priceForShipKey(key) : OOCreditsQuantity{}; }
- (void) showShipyardInfoForSelection	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->showShipyardInfoForSelection(); }
- (void) showTradeInInformationFooter	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->showTradeInInformationFooter(); }
- (NSInteger) missingSubEntitiesAdjustment	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->missingSubEntitiesAdjustment() : NSInteger{}; }
- (OOCreditsQuantity) tradeInValue	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->tradeInValue() : OOCreditsQuantity{}; }
- (BOOL) buySelectedShip	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->buySelectedShip() : NO; }
- (BOOL) cxx_replaceShipWithNamedShip:(const std::string &)shipKey	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->replaceShipWithNamedShip(shipKey) : NO; }
- (BOOL)loadPlayer	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->loadPlayer() : NO; }
- (void)savePlayer	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->savePlayer(); }
- (void) autosavePlayer	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->autosavePlayer(); }
- (void) quicksavePlayer	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->quicksavePlayer(); }
- (void) addScenarioModel:(const std::string &)shipKey	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->addScenarioModel(shipKey); }
- (void) showScenarioDetails	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->showScenarioDetails(); }
- (BOOL) startScenario	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->startScenario() : NO; }
#if OO_USE_CUSTOM_LOAD_SAVE
- (void) saveCommanderInputHandler	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->saveCommanderInputHandler(); }
#endif
#if OO_USE_CUSTOM_LOAD_SAVE
- (void) overwriteCommanderInputHandler	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->overwriteCommanderInputHandler(); }
#endif
#if OOLITE_USE_APPKIT_LOAD_SAVE
- (BOOL)loadPlayerWithPanel	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->loadPlayerWithPanel() : NO; }
#endif
#if OOLITE_USE_APPKIT_LOAD_SAVE
- (void) savePlayerWithPanel	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->savePlayerWithPanel(); }
#endif
- (void) writePlayerToPath:(const std::string &)path	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->writePlayerToPath(path); }
- (void)nativeSavePlayer:(const std::string &)cdrName	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->nativeSavePlayer(cdrName); }
#if OO_USE_CUSTOM_LOAD_SAVE
- (void) setGuiToLoadCommanderScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToLoadCommanderScreen(); }
#endif
#if OO_USE_CUSTOM_LOAD_SAVE
- (void) setGuiToSaveCommanderScreen:(const std::string &)cdrName	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToSaveCommanderScreen(cdrName); }
#endif
#if OO_USE_CUSTOM_LOAD_SAVE
- (void) setGuiToOverwriteScreen:(const std::string &)cdrName	{ if (PlayerEntity *player = PlayerEntityPart(_cxxShip))  player->setGuiToOverwriteScreen(cdrName); }
#endif
#if OO_USE_CUSTOM_LOAD_SAVE
- (BOOL) existingNativeSave: (const std::string &)cdrName	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->existingNativeSave(cdrName) : NO; }
#endif
#if OO_USE_CUSTOM_LOAD_SAVE
- (int) findIndexOfCommander: (const std::string &)cdrName	{ PlayerEntity *player = PlayerEntityPart(_cxxShip); return player != nullptr ? player->findIndexOfCommander(cdrName) : int{}; }
#endif

@end


/*	The selectors the game finds by name on a station (bead oo-9ht.175, ADR-0056 amendment
	oo-9ht.175): AI actions, legacy-script and callObjC() calls, shader bindings. The station's
	facade, a subclass of this one, answered them until then. These are exactly the selectors only
	the station's facade answered whose signature a by-name dispatcher can call (as the player's
	above): each answers the station's C++ member, and nothing (zero) for any other ship;
	-respondsToSelector: (above) answers them for a station's C++ part only. Not declared in a
	header: converted code calls the C++ members. They go with this facade.
*/
@implementation ShipEntity (OOStationSelectorsCalledByName)

- (OOTechLevelID) equivalentTechLevel	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->getEquivalentTechLevel() : OOTechLevelID{}; }
- (Vector) virtualPortDimensions	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->virtualPortDimensions() : kZeroVector; }
- (DockEntity *) playerReservedDock	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->playerReservedDock() : nil; }
- (HPVector) beaconPosition	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->beaconPosition() : kZeroHPVector; }
- (float) equipmentPriceFactor	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->getEquipmentPriceFactor() : float{}; }
- (OOCargoQuantity) marketCapacity	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->getMarketCapacity() : OOCargoQuantity{}; }
- (oo::PList) cxx_marketDefinition	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->getMarketDefinition() : oo::PList(); }
- (BOOL) marketMonitored	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->getMarketMonitored() : NO; }
- (BOOL) marketBroadcast	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->getMarketBroadcast() : NO; }
- (void) cxx_setLocalMarket:(const oo::PList &)market	{ if (StationEntity *station = StationPart(_cxxShip))  station->setLocalMarket(market); }
- (oo::PList) cxx_localMarketForScripting	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->localMarketForScripting() : oo::PList(); }
- (unsigned) countOfDockedContractors	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->countOfDockedContractors() : unsigned{}; }
- (unsigned) countOfDockedPolice	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->countOfDockedPolice() : unsigned{}; }
- (unsigned) countOfDockedDefenders	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->countOfDockedDefenders() : unsigned{}; }
- (BOOL) interstellarUndockingAllowed	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->getInterstellarUndockingAllowed() : NO; }
- (BOOL) hasNPCTraffic	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->getHasNPCTraffic() : NO; }
- (BOOL) requiresDockingClearance	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->getRequiresDockingClearance() : NO; }
- (BOOL) allowsFastDocking	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->getAllowsFastDocking() : NO; }
- (BOOL) allowsAutoDocking	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->getAllowsAutoDocking() : NO; }
- (BOOL) allowsSaving	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->getAllowsSaving() : NO; }
- (BOOL) isRotatingStation	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->isRotatingStation() : NO; }
- (BOOL) hasShipyard	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->hasShipyard() : NO; }
- (void) generateShipyard	{ if (StationEntity *station = StationPart(_cxxShip))  station->generateShipyard(); }
- (BOOL) suppressArrivalReports	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->suppressArrivalReports() : NO; }
- (BOOL) hasBreakPattern	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->getHasBreakPattern() : NO; }
- (void) sanityCheckShipsOnApproach	{ if (StationEntity *station = StationPart(_cxxShip))  station->sanityCheckShipsOnApproach(); }
- (void) autoDockShipsOnHold	{ if (StationEntity *station = StationPart(_cxxShip))  station->autoDockShipsOnHold(); }
- (void) autoDockShipsOnApproach	{ if (StationEntity *station = StationPart(_cxxShip))  station->autoDockShipsOnApproach(); }
- (BOOL) dockingCorridorIsEmpty	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->dockingCorridorIsEmpty() : NO; }
- (void) clearDockingCorridor	{ if (StationEntity *station = StationPart(_cxxShip))  station->clearDockingCorridor(); }
- (void) clear	{ if (StationEntity *station = StationPart(_cxxShip))  station->clear(); }
- (BOOL) hasMultipleDocks	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->hasMultipleDocks() : NO; }
- (BOOL) hasClearDock	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->hasClearDock() : NO; }
- (BOOL) hasEligibleDock	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->hasEligibleDock() : NO; }
- (BOOL) hasLaunchDock	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->hasLaunchDock() : NO; }
- (DockEntity *) selectDockForDocking	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->selectDockForDocking() : nil; }
- (unsigned) countOfShipsInLaunchQueueWithPrimaryRole:(const std::string &)role	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->countOfShipsInLaunchQueueWithPrimaryRole(role) : unsigned{}; }
- (OOStationAlertLevel) alertLevel	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->getAlertLevel() : STATION_ALERT_LEVEL_GREEN; }	// green for any other ship, which does not respond (the enum has no zero)
- (unsigned) currentlyInDockingQueues	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->currentlyInDockingQueues() : unsigned{}; }
- (unsigned) currentlyInLaunchingQueues	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->currentlyInLaunchingQueues() : unsigned{}; }
- (oo::PList) launchIndependentShip:(const std::string &)role	{ StationEntity *station = StationPart(_cxxShip); return station != nullptr ? station->launchIndependentShip(role) : oo::PList(); }

@end
