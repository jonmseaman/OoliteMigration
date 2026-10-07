/*

ShipEntity+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, amendments oo-bj8 and oo-60fwo): the Objective-C ShipEntity
facade (see ShipEntity+ObjCBridge.h). Its initialisers and -dealloc are here, in a category while
the class's @implementation is still ShipEntity.mm, because they need the Objective-C object as
self (amendment oo-bj8 items 6 and 7), and so are the two SubEntityRelationship categories (item
12); the other methods are still in ShipEntity.mm until their slices move them. Deleted with
ShipEntity+ObjCBridge.h.

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

#include <cmath>


namespace {

/*	The C++ part of an Objective-C ship (ShipEntity, StationEntity, DockEntity, PlayerEntity, ...):
	the root's adapter over cxx::ShipEntity, plus the members cxx::ShipEntity added that the
	Objective-C subclasses override, which message the Objective-C object (ADR-0056 amendments
	oo-vl43 item 1 and oo-mvzmb). Each slice that makes such a member virtual adds its line
	(docs/phases/3-slices/ShipEntity.md); the facade's forwarder calls cxx::ShipEntity's own
	member, which is what [super ...] (or not overriding) reached.
*/
class ObjCShipEntity final : public oo::ObjCEntity<cxx::ShipEntity>
{
public:
	explicit ObjCShipEntity(::Entity *objcOwner) : oo::ObjCEntity<cxx::ShipEntity>(objcOwner) {}

	// Slice 3 (bead oo-mvzmb).
	bool setUpShipFromDictionary(const oo::PList &shipDict) override	{ return [(::ShipEntity *)_objcOwner setUpShipFromDictionary:shipDict]; }
	bool setUpSubEntities() override	{ return [(::ShipEntity *)_objcOwner setUpSubEntities]; }

	// Slice 5 (bead oo-ddnn8).
	GLfloat doesHitLine(HPVector v0, HPVector v1, ::ShipEntity **hitEntity) override	{ return [(::ShipEntity *)_objcOwner doesHitLine:v0 :v1 :hitEntity]; }

	// Slice 8 (bead oo-vxdsc).
	bool hasPrimaryWeapon(OOWeaponType weaponType) override	{ return [(::ShipEntity *)_objcOwner hasPrimaryWeapon:weaponType]; }
};

}	// namespace


@interface ShipEntity (OOObjCBridgePrivate)

- (id) initShipPart;

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
	OOJS_PROFILE_ENTER

	self = [self initShipPart];	// [super init]
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
	return [self initWithCxxEntity:oo::makeRef<ObjCShipEntity>(self).get()];
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
	DESTROY(_cxxShip->roleSet);
DESTROY(_cxxShip->laser_color);
	DESTROY(_cxxShip->default_laser_color);
	DESTROY(_cxxShip->exhaust_emissive_color);
	DESTROY(_cxxShip->scanner_display_color1);
	DESTROY(_cxxShip->scanner_display_color2);
	DESTROY(_cxxShip->scanner_display_color_hostile1);
	DESTROY(_cxxShip->scanner_display_color_hostile2);
	DESTROY(_cxxShip->script);
	DESTROY(_cxxShip->aiScript);
	DESTROY(_cxxShip->octree);
	DESTROY(_cxxShip->_defenseTargets);
	DESTROY(_cxxShip->_collisionExceptions);

	[self setSubEntityTakingDamage:nil];
	[self removeAllEquipment];

	[_cxxShip->_group removeShip:self];
	DESTROY(_cxxShip->_group);
	[_cxxShip->_escortGroup removeShip:self];
	DESTROY(_cxxShip->_escortGroup);

	DESTROY(_cxxShip->_lastAegisLock);

	DESTROY(_cxxShip->_beaconDrawable);


	[super dealloc];
}

@end


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

- (BOOL) setUpShipFromDictionary:(const oo::PList &)shipDict	{ return _cxxShip->cxx::ShipEntity::setUpShipFromDictionary(shipDict); }
- (void) setSubIdx:(NSUInteger)value	{ _cxxShip->setSubIdx(value); }
- (NSUInteger) subIdx	{ return _cxxShip->subIdx(); }
- (NSUInteger) maxShipSubEntities	{ return _cxxShip->maxShipSubEntities(); }
- (std::optional<std::string>) cxx_serializeShipSubEntities	{ return _cxxShip->serializeShipSubEntities(); }
- (void) cxx_deserializeShipSubEntitiesFrom:(const std::string &)string	{ _cxxShip->deserializeShipSubEntitiesFrom(string); }
- (BOOL) setUpSubEntities	{ return _cxxShip->cxx::ShipEntity::setUpSubEntities(); }
- (GLfloat) frustumRadius	{ return _cxxShip->cxx::ShipEntity::frustumRadius(); }
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
- (std::vector<oo::ObjCRef<OOFlasherEntity *>>) flasherEnumerator	{ return _cxxShip->flasherEnumerator(); }
- (std::vector<oo::ObjCRef<OOExhaustPlumeEntity *>>) cxx_exhausts	{ return _cxxShip->exhausts(); }
- (ShipEntity *) subEntityTakingDamage	{ return _cxxShip->subEntityTakingDamage(); }
- (void) setSubEntityTakingDamage:(ShipEntity *)sub	{ _cxxShip->setSubEntityTakingDamage(sub); }
- (OOScript *) shipScript	{ return _cxxShip->shipScript(); }
- (OOScript *) shipAIScript	{ return _cxxShip->shipAIScript(); }
- (OOTimeAbsolute) shipAIScriptWakeTime	{ return _cxxShip->shipAIScriptWakeTime(); }
- (void) setAIScriptWakeTime:(OOTimeAbsolute)t	{ _cxxShip->setAIScriptWakeTime(t); }
- (std::optional<std::string>) cxx_descriptionComponents	{ return _cxxShip->cxx::ShipEntity::descriptionComponents(); }

@end


@implementation ShipEntity (OOSlice5)

- (BoundingBox) findBoundingBoxRelativeToPosition:(HPVector)opv InVectors:(Vector)_i :(Vector)_j :(Vector)_k	{ return _cxxShip->findBoundingBoxRelativeToPosition(opv, _i, _j, _k); }
- (Octree *) octree	{ return _cxxShip->getOctree(); }
- (float) volume	{ return _cxxShip->volume(); }
- (GLfloat) doesHitLine:(HPVector)v0 :(HPVector)v1	{ return _cxxShip->doesHitLine(v0, v1); }
- (GLfloat) doesHitLine:(HPVector)v0 :(HPVector)v1 :(ShipEntity **)hitEntity	{ return _cxxShip->cxx::ShipEntity::doesHitLine(v0, v1, hitEntity); }
- (GLfloat) doesHitLine:(HPVector)v0 :(HPVector)v1 withPosition:(HPVector)o andIJK:(Vector)i :(Vector)j :(Vector)k	{ return _cxxShip->doesHitLine(v0, v1, o, i, j, k); }
- (void) wasAddedToUniverse	{ _cxxShip->cxx::ShipEntity::wasAddedToUniverse(); }
- (void) wasRemovedFromUniverse	{ _cxxShip->cxx::ShipEntity::wasRemovedFromUniverse(); }
- (HPVector) absoluteTractorPosition	{ return _cxxShip->absoluteTractorPosition(); }
- (std::optional<std::string>) beaconCode	{ return _cxxShip->beaconCode(); }
- (void) setBeaconCode:(const std::optional<std::string> &)bcode	{ _cxxShip->setBeaconCode(bcode); }
- (std::optional<std::string>) beaconLabel	{ return _cxxShip->beaconLabel(); }
- (void) setBeaconLabel:(const std::optional<std::string> &)blabel	{ _cxxShip->setBeaconLabel(blabel); }
- (BOOL) isVisible	{ return _cxxShip->cxx::ShipEntity::isVisible(); }
- (BOOL) isBeacon	{ return _cxxShip->isBeacon(); }
- (id <OOHUDBeaconIcon>) beaconDrawable	{ return _cxxShip->beaconDrawable(); }
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
- (OOScanClass) scanClass	{ return _cxxShip->cxx::ShipEntity::getScanClass(); }
- (BOOL) canCollide	{ return _cxxShip->cxx::ShipEntity::canCollide(); }
- (BOOL) checkCloseCollisionWith:(Entity *)other	{ return _cxxShip->cxx::ShipEntity::checkCloseCollisionWith(oo::ToCxx(other)); }
- (BoundingBox) findSubentityBoundingBox	{ return _cxxShip->findSubentityBoundingBox(); }
- (Triangle) absoluteIJKForSubentity	{ return _cxxShip->absoluteIJKForSubentity(); }
- (void) addSubentityToCollisionRadius:(Entity<OOSubEntity> *)subent	{ _cxxShip->addSubentityToCollisionRadius(subent); }
- (ShipEntity *) launchPodWithCrew:(const std::vector<oo::ObjCRef<OOCharacter *>> &)podCrew	{ return _cxxShip->launchPodWithCrew(podCrew); }
- (BOOL) validForAddToUniverse	{ return _cxxShip->cxx::ShipEntity::validForAddToUniverse(); }

@end


@implementation ShipEntity (OOSlice7)

- (void) update:(OOTimeDelta)delta_t	{ _cxxShip->cxx::ShipEntity::update(delta_t); }

@end


@implementation ShipEntity (OOSlice8)

- (void) processBehaviour:(OOTimeDelta)delta_t	{ _cxxShip->processBehaviour(delta_t); }
- (void) noteFrustration:(const std::string &)context	{ _cxxShip->noteFrustration(context); }
- (void) respondToAttackFrom:(Entity *)from becauseOf:(Entity *)other	{ _cxxShip->respondToAttackFrom(from, other); }
- (BOOL) cxx_hasOneEquipmentItem:(const std::string &)itemKey includeWeapons:(BOOL)includeWeapons whileLoading:(BOOL)loading	{ return _cxxShip->hasOneEquipmentItem(itemKey, includeWeapons, loading); }
- (BOOL) cxx_hasOneEquipmentItem:(const std::string &)itemKey includeMissiles:(BOOL)includeMissiles whileLoading:(BOOL)loading	{ return _cxxShip->hasOneEquipmentItemIncludingMissiles(itemKey, includeMissiles, loading); }
- (BOOL) hasPrimaryWeapon:(OOWeaponType)weaponType	{ return _cxxShip->cxx::ShipEntity::hasPrimaryWeapon(weaponType); }
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
