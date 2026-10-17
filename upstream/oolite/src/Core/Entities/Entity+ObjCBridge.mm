/*

Entity+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, amendment oo-bj8): the Objective-C Entity facade (see
Entity+ObjCBridge.h). Every method forwards to its C++ member. An Objective-C entity's C++ part
is an oo::ObjCEntity adapter, whose virtual members message the entity; for the members its
subclasses override, the facade calls the adapter's super...() member, the base's own. The
facade's -init and -dealloc keep what needs the Objective-C object as self. Deleted with
Entity+ObjCBridge.h.

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

#import "Entity.h"
#import "OOEntityWithDrawable.h"
#import "OOLightParticleEntity.h"
#import "WormholeEntity.h"
#import "OOSunEntity.h"
#import "SkyEntity.h"
#import "OOWaypointEntity.h"
#import "OOFlashEffectEntity.h"
#import "OOPlanetEntity.h"
#import "OOVisualEffectEntity.h"
#import "ShipEntity.h"
#import "ShipEntityAI.h"
#import "ShipEntityScriptMethods.h"
#import "PlayerEntity.h"
#import "ProxyPlayerEntity.h"
#import "StationEntity.h"
#import "DockEntity.h"
#import "AI.h"
#import "EntityOOJavaScriptExtensions.h"
#import "Universe.h"
#import "NSObjectOOExtensions.h"
#import "OODescription.h"
#import "OOShaderUniformMethodType.h"	// the shader binding member table (bead oo-9ht.158)
#include "oofnd/String.hpp"
#include "oofnd/objc/OOAssert.h"
#include "oofnd/objc/OOObjCPeer.h"
#include "oofnd/objc/OORuntime.h"

#include <cstdlib>
#include <cxxabi.h>
#include <typeinfo>
#include <unordered_map>
#include <array>
#include <utility>
#include <type_traits>
#include <objc/runtime.h>


namespace {

// Never destroyed: a facade may be released while the process exits.
oo::ObjCPeers &Peers()
{
	static oo::ObjCPeers *peers = new oo::ObjCPeers;
	return *peers;
}


// The ship family's parts (defined below).
ShipEntity *ShipPart(cxx::Entity *entity);
StationEntity *StationPart(cxx::Entity *entity);
DockEntity *DockPart(cxx::Entity *entity);
PlayerEntity *PlayerEntityPart(cxx::Entity *entity);


// A visual effect's part (bead oo-9ht.165): the effect's facade, a subclass of the drawable's,
// answered the selectors the beacon and subentity categories answer for it; nullptr for any other
// entity.
OOVisualEffectEntity *EffectPart(cxx::Entity *entity)
{
	return dynamic_cast<OOVisualEffectEntity *>(entity);
}


}	// namespace


::Entity *oo::ToObjC(cxx::Entity *entity)
{
	if (entity == nullptr)  return nil;
	if (ObjCEntityLink *link = AsObjCEntity(entity))  return link->objcOwner();
	// A C++ entity's facade made it and owns it (oo::NewEntityFacade): never a new one here.
	return Peers().peerFor(entity, [] { return nil; });
}


::Entity *oo::WeakEntityObject(const WeakRef<cxx::Entity> &ref)
{
	cxx::Entity *entity = ref.get();
	if (entity == nullptr)  return nil;
	if (ObjCEntityLink *link = AsObjCEntity(entity))  return link->objcOwner();
	return Peers().livePeer(entity);
}


::Entity *oo::NewEntityFacade(const Ref<cxx::Entity> &entity)
{
	if (entity == nullptr)  return nil;
	OOCParameterAssert(AsObjCEntity(entity.get()) == nullptr);
	Class facadeClass = [::Entity class];
	return [[(::Entity *)[facadeClass alloc] initWithCxxEntity:entity.get()] autorelease];
}


std::string oo::EntityClassName(cxx::Entity *entity)
{
	if (ObjCEntityLink *link = AsObjCEntity(entity))  return OOClassName([link->objcOwner() class]);
	int status = 0;
	char *demangled = abi::__cxa_demangle(typeid(*entity).name(), nullptr, nullptr, &status);
	std::string result = (status == 0 && demangled != nullptr) ? demangled : typeid(*entity).name();
	std::free(demangled);
	if (result.starts_with("cxx::"))  result.erase(0, 5);
	return result;
}


@interface Entity (OOObjCBridgePrivate)

// Found by selector (the shader bindings).
- (Vector) relativePosition;

@end


@implementation Entity

// An Objective-C entity: [[X alloc] init] of a subclass (or of this class).
- (id) init
{
	// -init sent again to an initialised entity keeps its C++ part (see -initWithCxxEntity:).
	if (_cxxEntity != nullptr)  return [self initWithCxxEntity:_cxxEntity.get()];
	return [self initWithCxxEntity:oo::makeRef<oo::ObjCEntity<cxx::Entity>>(self).get()];
}


- (id) initWithCxxEntity:(cxx::Entity *)entity
{
	self = [super init];
	if (EXPECT_NOT(self == nil))  return nil;

	if (_cxxEntity != nullptr)
	{
		/*	An initialised entity sent -init again (PlayerEntity's -deferredInit): the Objective-C
			-init re-ran its body over the same ivars, so the body runs again over the same C++
			part, and the rest of its state (the script object, the flags set since) stays.
		*/
		OOCParameterAssert(entity == _cxxEntity.get());
		_cxxEntity->init();
	}
	else
	{
		_cxxEntity = oo::Ref<cxx::Entity>(entity);
		if (oo::AsObjCEntity(entity) == nullptr)
		{
			@autoreleasepool
			{
				Peers().peerFor(entity, [self] { return [self retain]; });
			}
		}
	}

#ifndef NDEBUG
	gLiveEntityCount++;
	gTotalEntityMemory += [self oo_objectSize];
#endif
	return self;
}


- (void) dealloc
{
	/*	Released before -init ran (a failing initialiser's [self release]; return nil;): there is no
		C++ part, and nothing was counted or registered. The Objective-C body's messages went to nil
		ivars here.
	*/
	if (_cxxEntity == nullptr)
	{
		[super dealloc];
		return;
	}

	/*	A ship's -dealloc ran first: its facade was a subclass of this one until bead oo-9ht.144.
		The player's, a station's or a dock's part first, as their facades' -dealloc ran before the
		ship's (beads oo-9ht.177, oo-9ht.175, oo-9ht.180); then the weak reference, dropped before
		entityDestroyed (see ShipEntity::shipWillDealloc()); then the ship's body.
	*/
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))
	{
		if (PlayerEntity *player = PlayerEntityPart(ship))  player->willDealloc();
		if (StationEntity *station = StationPart(ship))  station->willDealloc();
		if (DockEntity *dock = DockPart(ship))  dock->willDealloc();
		[weakSelf weakRefDrop];
		weakSelf = nil;
		_cxxEntity->dropWeakReferences();	// and the C++ part's, at the same point (bead oo-9ht.39.5.2)
		ship->shipWillDealloc();
	}

	if (UNIVERSE != nullptr)  UNIVERSE->ensureEntityReallyRemoved(self);
	_cxxEntity->setCollisionRegion(nullptr);		// DESTROY(collisionRegion)
	_cxxEntity->deleteJSSelf();	// what the deleted -deleteJSSelf forwarded to (bead oo-9ht.39.8.9)
	[self setOwner:nil];
	[self setAtmosphereFogging:nil];	// [atmosphereFogging release]

#ifndef NDEBUG
	gLiveEntityCount--;
	gTotalEntityMemory -= [self oo_objectSize];
#endif

	/*	The C++ part's weak references read null from here, where OOWeakRefObject's -dealloc (the
		superclass's, below) dropped the object's: the part may outlive its object while something
		else holds it (bead oo-9ht.39.5.2).
	*/
	_cxxEntity->dropWeakReferences();
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->objcOwnerDeallocated();
	else  Peers().forget(_cxxEntity.get());
	_cxxEntity = nullptr;	// the C++ part goes with the object, before its superclass's -dealloc

	[super dealloc];
}


// A C++ entity's facade describes itself with the C++ class's name and components.
- (std::optional<std::string>) cxx_description
{
	if (oo::AsObjCEntity(_cxxEntity.get()) != nullptr)  return [super cxx_description];
	std::string result = oo::str::format("<%s %s>", oo::EntityClassName(_cxxEntity.get()).c_str(), oo::str::pointerDescription(self).c_str());
	if (const std::optional<std::string> components = _cxxEntity->descriptionComponents())  result += "{" + *components + "}";
	return result;
}


/*	The members that subclasses override are virtual. On an Objective-C entity these methods are
	reached only when the subclass does not override them, or by [super ...]: the adapter's
	super...() member, the nearest C++ base's own, answers. On a C++ entity's facade the C++
	override answers. The rest forward to their member.
*/
- (std::optional<std::string>) cxx_descriptionComponents
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superDescriptionComponents();
	return _cxxEntity->descriptionComponents();
}


- (NSUInteger) sessionID
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superSessionID();
	return _cxxEntity->sessionID();
}


- (BOOL) isShip						{ return _cxxEntity->getIsShip(); }


- (BOOL) isDock
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superIsDock();
	return _cxxEntity->isDock();
}


- (BOOL) isStation					{ return _cxxEntity->getIsStation(); }
- (BOOL) isSubEntity				{ return _cxxEntity->getIsSubEntity(); }
- (BOOL) isPlayer					{ return _cxxEntity->getIsPlayer(); }


- (BOOL) isPlanet
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superIsPlanet();
	return _cxxEntity->isPlanet();
}


- (BOOL) isSun
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superIsSun();
	return _cxxEntity->isSun();
}


- (BOOL) isSunlit					{ return _cxxEntity->getIsSunlit(); }
- (BOOL) isStellarObject			{ return _cxxEntity->isStellarObject(); }


- (BOOL) isSky
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superIsSky();
	return _cxxEntity->isSky();
}


- (BOOL) isWormhole					{ return _cxxEntity->getIsWormhole(); }


- (BOOL) isEffect
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superIsEffect();
	return _cxxEntity->isEffect();
}


- (BOOL) isVisualEffect
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superGetIsVisualEffect();
	return _cxxEntity->getIsVisualEffect();
}


- (BOOL) isWaypoint
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superIsWaypoint();
	return _cxxEntity->isWaypoint();
}


- (BOOL) validForAddToUniverse
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superValidForAddToUniverse();
	return _cxxEntity->validForAddToUniverse();
}


- (void) addToLinkedLists			{ _cxxEntity->addToLinkedLists(); }
- (void) removeFromLinkedLists		{ _cxxEntity->removeFromLinkedLists(); }
- (void) updateLinkedLists			{ _cxxEntity->updateLinkedLists(); }


- (void) wasAddedToUniverse
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superWasAddedToUniverse();
	else  _cxxEntity->wasAddedToUniverse();
}


- (void) wasRemovedFromUniverse
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superWasRemovedFromUniverse();
	else  _cxxEntity->wasRemovedFromUniverse();
}


- (void) warnAboutHostiles
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superWarnAboutHostiles();
	else  _cxxEntity->warnAboutHostiles();
}


- (void) setUniversalID:(OOUniversalID)uid				{ _cxxEntity->setUniversalID(uid); }
- (OOUniversalID) universalID							{ return _cxxEntity->getUniversalID(); }
- (BOOL) throwingSparks									{ return _cxxEntity->throwingSparks(); }
- (void) setThrowSparks:(BOOL)value						{ _cxxEntity->setThrowSparks(value); }


- (void) throwSparks
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superThrowSparks();
	else  _cxxEntity->throwSparks();
}


- (void) setOwner:(Entity *)ent
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superSetOwner(oo::ToCxx(ent));
	else  _cxxEntity->setOwner(oo::ToCxx(ent));
}


- (id) owner											{ return _cxxEntity->owner(); }
- (Entity *) parentEntity								{ return _cxxEntity->parentEntity(); }
- (id<OOWeakReferenceSupport>) superShaderBindingTarget	{ return _cxxEntity->superShaderBindingTarget(); }
- (Entity *) rootShipEntity								{ return _cxxEntity->rootShipEntity(); }


- (void) setPosition:(HPVector)posn
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superSetPosition(posn);
	else  _cxxEntity->setPosition(posn);
}


- (void) setPositionX:(OOHPScalar)x y:(OOHPScalar)y z:(OOHPScalar)z	{ _cxxEntity->setPositionX(x, y, z); }
- (HPVector) position									{ return _cxxEntity->getPosition(); }
- (Vector) cameraRelativePosition						{ return _cxxEntity->getCameraRelativePosition(); }


- (GLfloat) cameraRangeFront
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superCameraRangeFront();
	return _cxxEntity->cameraRangeFront();
}


- (GLfloat) cameraRangeBack
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superCameraRangeBack();
	return _cxxEntity->cameraRangeBack();
}


- (Vector) relativePosition								{ return _cxxEntity->relativePosition(); }


// The planet's shader binding selectors (Entity (OOPlanetShaderBindings), below) are answered for a
// planet's C++ part only (bead oo-9ht.129): the shader uniforms ask this before they bind.
// The beacon selectors (Entity (OOWaypointBeacon), below) are answered for a waypoint's, a ship's
// and a visual effect's C++ part, as before (beads oo-9ht.108, oo-9ht.144, oo-9ht.165).
// The ship family's and the visual effect's selectors found by name are the C++ table's
// (oo::EntityRespondsToName) since bead oo-9ht.39.7.3: this object no longer answers them.
- (BOOL) respondsToSelector:(SEL)selector
{
	if (selector == @selector(airColorAsVector) || selector == @selector(illuminationColorAsVector) ||
		selector == @selector(airColorMixRatio) || selector == @selector(airDensity) ||
		selector == @selector(terminatorThresholdVector))
	{
		return dynamic_cast<OOPlanetEntity *>(_cxxEntity.get()) != nullptr;
	}
	if (protocol_getMethodDescription(@protocol(OOBeaconEntity), selector, YES, YES).name != NULL)
	{
		if (dynamic_cast<OOWaypointEntity *>(_cxxEntity.get()) != nullptr || ShipPart(_cxxEntity.get()) != nullptr)  return YES;
		if (EffectPart(_cxxEntity.get()) != nullptr)  return YES;	// its facade answered them until bead oo-9ht.165
		return class_getInstanceMethod(object_getClass(self), selector) != class_getInstanceMethod([::Entity class], selector);
	}
	return [super respondsToSelector:selector];
}


- (void) updateCameraRelativePosition
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superUpdateCameraRelativePosition();
	else  _cxxEntity->updateCameraRelativePosition();
}


- (Vector) vectorTo:(Entity *)entity					{ return _cxxEntity->vectorTo(oo::ToCxx(entity)); }
- (HPVector) absolutePositionForSubentity				{ return _cxxEntity->absolutePositionForSubentity(); }
- (HPVector) absolutePositionForSubentityOffset:(HPVector)offset	{ return _cxxEntity->absolutePositionForSubentityOffset(offset); }
- (double) zeroDistance									{ return _cxxEntity->zeroDistance(); }
- (double) camZeroDistance								{ return _cxxEntity->camZeroDistance(); }


- (OOComparisonResult) compareZeroDistance:(Entity *)otherEntity
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superCompareZeroDistance(oo::ToCxx(otherEntity));
	return _cxxEntity->compareZeroDistance(oo::ToCxx(otherEntity));
}


- (BoundingBox) boundingBox								{ return _cxxEntity->getBoundingBox(); }
- (GLfloat) mass										{ return _cxxEntity->getMass(); }


- (void) setOrientation:(Quaternion)quat
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superSetOrientation(quat);
	else  _cxxEntity->setOrientation(quat);
}


- (Quaternion) orientation								{ return _cxxEntity->getOrientation(); }


- (Quaternion) normalOrientation
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superNormalOrientation();
	return _cxxEntity->normalOrientation();
}


- (void) setNormalOrientation:(Quaternion)quat
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superSetNormalOrientation(quat);
	else  _cxxEntity->setNormalOrientation(quat);
}


- (void) orientationChanged
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superOrientationChanged();
	else  _cxxEntity->orientationChanged();
}


- (void) setVelocity:(Vector)vel						{ _cxxEntity->setVelocity(vel); }


- (Vector) velocity
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superGetVelocity();
	return _cxxEntity->getVelocity();
}


- (double) speed										{ return _cxxEntity->speed(); }
- (GLfloat) distanceTravelled							{ return _cxxEntity->getDistanceTravelled(); }
- (void) setDistanceTravelled:(GLfloat)value			{ _cxxEntity->setDistanceTravelled(value); }


- (void) setStatus:(OOEntityStatus)stat
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superSetStatus(stat);
	else  _cxxEntity->setStatus(stat);
}


- (OOEntityStatus) status								{ return _cxxEntity->status(); }
- (void) setScanClass:(OOScanClass)sClass				{ _cxxEntity->setScanClass(sClass); }


- (OOScanClass) scanClass
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superGetScanClass();
	return _cxxEntity->getScanClass();
}


- (void) setEnergy:(GLfloat)amount						{ _cxxEntity->setEnergy(amount); }
- (GLfloat) energy										{ return _cxxEntity->getEnergy(); }
- (void) setMaxEnergy:(GLfloat)amount					{ _cxxEntity->setMaxEnergy(amount); }
- (GLfloat) maxEnergy									{ return _cxxEntity->getMaxEnergy(); }


- (void) applyRoll:(GLfloat)roll andClimb:(GLfloat)climb
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superApplyRoll(roll, climb);
	else  _cxxEntity->applyRoll(roll, climb);
}


- (void) applyRoll:(GLfloat)roll climb:(GLfloat)climb andYaw:(GLfloat)yaw
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superApplyRoll(roll, climb, yaw);
	else  _cxxEntity->applyRoll(roll, climb, yaw);
}


- (void) moveForward:(double)amount
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superMoveForward(amount);
	else  _cxxEntity->moveForward(amount);
}


- (OOMatrix) rotationMatrix								{ return _cxxEntity->rotationMatrix(); }


- (OOMatrix) drawRotationMatrix
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superDrawRotationMatrix();
	return _cxxEntity->drawRotationMatrix();
}


- (OOMatrix) transformationMatrix						{ return _cxxEntity->transformationMatrix(); }


- (OOMatrix) drawTransformationMatrix
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superDrawTransformationMatrix();
	return _cxxEntity->drawTransformationMatrix();
}


- (BOOL) canCollide
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superCanCollide();
	return _cxxEntity->canCollide();
}


- (GLfloat) collisionRadius
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superCollisionRadius();
	return _cxxEntity->collisionRadius();
}


- (GLfloat) frustumRadius
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superFrustumRadius();
	return _cxxEntity->frustumRadius();
}


- (void) setCollisionRadius:(GLfloat)amount				{ _cxxEntity->setCollisionRadius(amount); }
- (std::vector<oo::ObjCRef<::Entity *>> *) cxx_collidingEntities	{ return _cxxEntity->getCollidingEntities(); }


- (void) update:(OOTimeDelta)delta_t
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superUpdate(delta_t);
	else  _cxxEntity->update(delta_t);
}


- (void) applyVelocity:(OOTimeDelta)delta_t				{ _cxxEntity->applyVelocity(delta_t); }


- (BOOL) checkCloseCollisionWith:(Entity *)other
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superCheckCloseCollisionWith(oo::ToCxx(other));
	return _cxxEntity->checkCloseCollisionWith(oo::ToCxx(other));
}


- (void) takeEnergyDamage:(double)amount from:(Entity *)ent becauseOf:(Entity *)other weaponIdentifier:(const std::string &)weaponIdentifier
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superTakeEnergyDamage(amount, oo::ToCxx(ent), oo::ToCxx(other), weaponIdentifier);
	else  _cxxEntity->takeEnergyDamage(amount, oo::ToCxx(ent), oo::ToCxx(other), weaponIdentifier);
}


- (void) dumpState										{ _cxxEntity->dumpState(); }


- (void) dumpSelfState
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superDumpSelfState();
	else  _cxxEntity->dumpSelfState();
}


- (void) subEntityReallyDied:(ShipEntity *)sub
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superSubEntityReallyDied(sub);
	else  _cxxEntity->subEntityReallyDied(sub);
}


- (NSUInteger) lastDrawCounter							{ return _cxxEntity->getLastDrawCounter(); }
- (void) setLastDrawCounter:(NSUInteger)drawCounter		{ _cxxEntity->setLastDrawCounter(drawCounter); }


- (double) findCollisionRadius
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superFindCollisionRadius();
	return _cxxEntity->findCollisionRadius();
}


- (void) drawImmediate:(bool)immediate translucent:(bool)translucent
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  link->superDrawImmediate(immediate, translucent);
	else  _cxxEntity->drawImmediate(immediate, translucent);
}


- (BOOL) isVisible
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superIsVisible();
	return _cxxEntity->isVisible();
}


- (BOOL) isInSpace										{ return _cxxEntity->isInSpace(); }
- (BOOL) isImmuneToBreakPatternHide						{ return _cxxEntity->getIsImmuneToBreakPatternHide(); }
- (GLfloat) universalTime								{ return _cxxEntity->universalTime(); }
- (GLfloat) spawnTime									{ return _cxxEntity->getSpawnTime(); }
- (GLfloat) timeElapsedSinceSpawn						{ return _cxxEntity->timeElapsedSinceSpawn(); }
- (void) setAtmosphereFogging:(OOColor *)fogging		{ _cxxEntity->setAtmosphereFogging(fogging); }
- (OOColor *) fogUniform								{ return _cxxEntity->fogUniform().get(); }	// borrowed: the entity holds it


#ifndef NDEBUG
- (std::optional<std::string>) descriptionForObjDumpBasic	{ return _cxxEntity->descriptionForObjDumpBasic(); }


- (std::optional<std::string>) descriptionForObjDump
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superDescriptionForObjDump();
	return _cxxEntity->descriptionForObjDump();
}


- (std::vector<oo::Ref<OOTexture>>) cxx_allTextures
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(_cxxEntity.get()))  return link->superAllTextures();
	return _cxxEntity->allTextures();
}
#endif

@end


/*	The planet's shader binding selectors (bead oo-9ht.129, ADR-0056 amendment oo-9ht.129). The
	planet's materials bind uniforms to its Objective-C object by selector (material-defaults.plist
	planet-material and atmosphere: airColorAsVector, illuminationColorAsVector, airColorMixRatio,
	airDensity, terminatorThresholdVector), and since its facade was deleted that object is the
	root's facade. These answer the C++ planet's members; -[Entity respondsToSelector:] answers them
	for a planet's C++ part only, so a ship or any other entity still fails to bind them, as before.
*/
@implementation Entity (OOPlanetShaderBindings)

- (Vector) airColorAsVector
{
	OOPlanetEntity *planet = dynamic_cast<OOPlanetEntity *>(_cxxEntity.get());
	return planet != nullptr ? planet->airColorAsVector() : kZeroVector;
}


- (Vector) illuminationColorAsVector
{
	OOPlanetEntity *planet = dynamic_cast<OOPlanetEntity *>(_cxxEntity.get());
	return planet != nullptr ? planet->illuminationColorAsVector() : kZeroVector;
}


- (float) airColorMixRatio
{
	OOPlanetEntity *planet = dynamic_cast<OOPlanetEntity *>(_cxxEntity.get());
	return planet != nullptr ? planet->airColorMixRatio() : 0.0f;
}


- (float) airDensity
{
	OOPlanetEntity *planet = dynamic_cast<OOPlanetEntity *>(_cxxEntity.get());
	return planet != nullptr ? planet->airDensity() : 0.0f;
}


- (Vector) terminatorThresholdVector
{
	OOPlanetEntity *planet = dynamic_cast<OOPlanetEntity *>(_cxxEntity.get());
	return planet != nullptr ? planet->terminatorThresholdVector() : kZeroVector;
}

@end


/*	The category SubEntityRelationship (declared in Entity+ObjCBridge.h), whose root methods were in
	ShipEntity+ObjCBridge.mm beside the ship facade's overrides until bead oo-9ht.144: they answer
	the ship's members for a ship's C++ part, as the ship's facade did, and the root's answers (NO,
	nothing) for any other entity.
*/
@implementation Entity (SubEntityRelationship)

- (BOOL) isShipWithSubEntityShip:(Entity *)other
{
	ShipEntity *ship = ShipPart(_cxxEntity.get());
	if (ship != nullptr)  return ship->isShipWithSubEntityShip(oo::ToCxx(other));
	OOVisualEffectEntity *effect = EffectPart(_cxxEntity.get());	// its facade answered it until bead oo-9ht.165
	return effect != nullptr ? effect->isShipWithSubEntityShip(other) : NO;
}


- (void) drawSubEntityImmediate:(bool)immediate translucent:(bool)translucent
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->drawSubEntityImmediate(immediate, translucent);
	else if (OOVisualEffectEntity *effect = EffectPart(_cxxEntity.get()))  effect->drawSubEntityImmediate(immediate, translucent);	// bead oo-9ht.165
	// Otherwise do nothing.
}

@end


/*	The waypoint's and the ship's OOBeaconEntity selectors (beads oo-9ht.108, oo-9ht.144; ADR-0056
	amendments oo-9ht.106, oo-9ht.144). A waypoint or a ship is a beacon in the universe's beacon
	list, which holds and messages the beacons' Objective-C objects (ships, visual effects,
	waypoints) by the protocol, and since their facades were deleted their objects are the root's
	and the drawable's facades. These answer the C++ ship's, visual effect's (since bead oo-9ht.165,
	whose facade implemented them itself until then) or waypoint's members, as those facades did,
	and zero (a message to nil's answer) for any other entity's part. -[Entity respondsToSelector:]
	answers them as before.
*/
@implementation Entity (OOWaypointBeacon)

- (OOComparisonResult) compareBeaconCodeWith:(Entity<OOBeaconEntity> *)other
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  return ship->compareBeaconCodeWith(oo::ToCxx(other));
	if (OOVisualEffectEntity *effect = EffectPart(_cxxEntity.get()))  return effect->compareBeaconCodeWith(other);
	OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get());
	return waypoint != nullptr ? waypoint->compareBeaconCodeWith(other) : (OOComparisonResult)0;
}


- (std::optional<std::string>) beaconCode
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  return ship->beaconCode();
	if (OOVisualEffectEntity *effect = EffectPart(_cxxEntity.get()))  return effect->beaconCode();
	OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get());
	return waypoint != nullptr ? waypoint->beaconCode() : std::nullopt;
}


- (void) setBeaconCode:(const std::optional<std::string> &)bcode
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setBeaconCode(bcode);
	else if (OOVisualEffectEntity *effect = EffectPart(_cxxEntity.get()))  effect->setBeaconCode(bcode);
	else if (OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get()))  waypoint->setBeaconCode(bcode);
}


- (std::optional<std::string>) beaconLabel
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  return ship->beaconLabel();
	if (OOVisualEffectEntity *effect = EffectPart(_cxxEntity.get()))  return effect->beaconLabel();
	OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get());
	return waypoint != nullptr ? waypoint->beaconLabel() : std::nullopt;
}


- (void) setBeaconLabel:(const std::optional<std::string> &)blabel
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setBeaconLabel(blabel);
	else if (OOVisualEffectEntity *effect = EffectPart(_cxxEntity.get()))  effect->setBeaconLabel(blabel);
	else if (OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get()))  waypoint->setBeaconLabel(blabel);
}


- (BOOL) isBeacon
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  return ship->isBeacon();
	if (OOVisualEffectEntity *effect = EffectPart(_cxxEntity.get()))  return effect->isBeacon();
	OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get());
	return waypoint != nullptr ? waypoint->isBeacon() : NO;
}


- (OOHUDBeaconIcon *) beaconDrawable
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  return ship->beaconDrawable();
	if (OOVisualEffectEntity *effect = EffectPart(_cxxEntity.get()))  return effect->beaconDrawable();
	OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get());
	return waypoint != nullptr ? waypoint->beaconDrawable() : nullptr;
}


- (Entity <OOBeaconEntity> *) prevBeacon
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  return (Entity <OOBeaconEntity> *)oo::ToObjC(ship->prevBeacon());
	if (OOVisualEffectEntity *effect = EffectPart(_cxxEntity.get()))  return effect->prevBeacon();
	OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get());
	return waypoint != nullptr ? waypoint->prevBeacon() : nil;
}


- (Entity <OOBeaconEntity> *) nextBeacon
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  return (Entity <OOBeaconEntity> *)oo::ToObjC(ship->nextBeacon());
	if (OOVisualEffectEntity *effect = EffectPart(_cxxEntity.get()))  return effect->nextBeacon();
	OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get());
	return waypoint != nullptr ? waypoint->nextBeacon() : nil;
}


- (void) setPrevBeacon:(Entity <OOBeaconEntity> *)beaconShip
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setPrevBeacon(oo::ToCxx(beaconShip));
	else if (OOVisualEffectEntity *effect = EffectPart(_cxxEntity.get()))  effect->setPrevBeacon(beaconShip);
	else if (OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get()))  waypoint->setPrevBeacon(beaconShip);
}


- (void) setNextBeacon:(Entity <OOBeaconEntity> *)beaconShip
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setNextBeacon(oo::ToCxx(beaconShip));
	else if (OOVisualEffectEntity *effect = EffectPart(_cxxEntity.get()))  effect->setNextBeacon(beaconShip);
	else if (OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get()))  waypoint->setNextBeacon(beaconShip);
}


- (BOOL) isJammingScanning
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  return ship->isJammingScanning();
	if (OOVisualEffectEntity *effect = EffectPart(_cxxEntity.get()))  return effect->isJammingScanning();
	OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get());
	return waypoint != nullptr ? waypoint->isJammingScanning() : NO;
}

@end


/*	The parts the facade's forwarders ask (beads oo-9ht.144, oo-9ht.175, oo-9ht.180, oo-9ht.177): the
	ship's, the station's, the dock's and the player's facades, subclasses of this one, answered
	those forwarders until they were deleted; each is nullptr for any other entity. The five
	categories of selectors found by name that asked them too (the ship's, the player's, the
	station's, the dock's and the visual effect's) are deleted (bead oo-9ht.39.7.3, ADR-0056
	amendment oo-9ht.39.7.3): their methods are the rows of the C++ table OOEntityCalledByNameTable.h,
	which oo::EntityRespondsToName / oo::CallEntityByName answer and call on the C++ entity.
*/
namespace {

ShipEntity *ShipPart(cxx::Entity *entity)
{
	return dynamic_cast<ShipEntity *>(entity);
}


StationEntity *StationPart(cxx::Entity *entity)
{
	return dynamic_cast<StationEntity *>(entity);
}


DockEntity *DockPart(cxx::Entity *entity)
{
	return dynamic_cast<DockEntity *>(entity);
}


PlayerEntity *PlayerEntityPart(cxx::Entity *entity)
{
	return dynamic_cast<PlayerEntity *>(entity);
}

}	// namespace

// BY-NAME TABLE ROWS HERE (tools/gen-callobjc-entity-table.py reads OOEntityCalledByNameTable.h)


/*	The category Entity (OOJavaScriptExtensions) (bead oo-9ht.128) is deleted (bead oo-9ht.39.8.9,
	ADR-0056 amendment oo-9ht.39.8.9): its five selectors forwarded to the C++ part, which the
	engine now asks directly (EntityOOJavaScriptExtensions.h).
*/

#if OO_SHADERS || !defined(NDEBUG)

/*	The entities' shader binding member table is in EntityShaderBindings.mm since bead oo-9ht.39.6.1
	(ADR-0056 amendment oo-9ht.39.6.1), its rows receiving the C++ entity. A uniform bound to an
	entity's object (the root's facade) asks for its row here: for an object of the root facade's
	own class only (a subclass's object may override the method, which the selector path asks),
	the row reading the object's C++ part; any other name or object binds by selector as before.
*/
namespace {

bool EntityShaderMemberBinding(id target, SEL selector, OOShaderMemberBinding *outBinding)
{
	// The root's facade only: a subclass's object may override the method, which the selector path asks.
	if (![target isMemberOfClass:[::Entity class]])  return false;
	return EntityShaderMemberBindingFor(oo::ToCxx((::Entity *)target), sel_getName(selector), outBinding);
}


const bool sEntityShaderBindingsRegistered = (OOSetShaderMemberBindingLookup(&EntityShaderMemberBinding), true);

}	// namespace

#endif	// OO_SHADERS || !defined(NDEBUG)
