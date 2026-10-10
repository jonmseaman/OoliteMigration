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
#import "GameController.h"	// OOScheduleDeferredCall (the player's selectors called by name)
#import "AI.h"
#import "EntityOOJavaScriptExtensions.h"
#import "Universe.h"
#import "NSObjectOOExtensions.h"
#import "OODescription.h"
#include "oofnd/String.hpp"
#include "oofnd/objc/OOAssert.h"
#include "oofnd/objc/OOObjCPeer.h"
#include "oofnd/objc/OORuntime.h"

#include <cstdlib>
#include <cxxabi.h>
#include <typeinfo>
#include <unordered_set>
#include <objc/runtime.h>


namespace {

// Never destroyed: a facade may be released while the process exits.
oo::ObjCPeers &Peers()
{
	static oo::ObjCPeers *peers = new oo::ObjCPeers;
	return *peers;
}


// The ship family's by-name selectors and their classes' parts (defined with their categories, below).
ShipEntity *ShipPart(cxx::Entity *entity);
StationEntity *StationPart(cxx::Entity *entity);
DockEntity *DockPart(cxx::Entity *entity);
PlayerEntity *PlayerEntityPart(cxx::Entity *entity);
ProxyPlayerEntity *ProxyPart(cxx::Entity *entity);
bool IsShipSelectorCalledByName(SEL selector);
bool IsPlayerSelectorCalledByName(SEL selector);
bool IsProxySelectorCalledByName(SEL selector);
bool IsStationSelectorCalledByName(SEL selector);
bool IsDockSelectorCalledByName(SEL selector);

}	// namespace


::Entity *oo::ToObjC(cxx::Entity *entity)
{
	if (entity == nullptr)  return nil;
	if (ObjCEntityLink *link = AsObjCEntity(entity))  return link->objcOwner();
	// A C++ entity's facade made it and owns it (oo::NewEntityFacade): never a new one here.
	return Peers().peerFor(entity, [] { return nil; });
}


::Entity *oo::NewEntityFacade(const Ref<cxx::Entity> &entity)
{
	if (entity == nullptr)  return nil;
	OOCParameterAssert(AsObjCEntity(entity.get()) == nullptr);
	Class facadeClass = [::Entity class];
	if (dynamic_cast<cxx::OOEntityWithDrawable *>(entity.get()) != nullptr)  facadeClass = [::OOEntityWithDrawable class];
	if (dynamic_cast<cxx::OOVisualEffectEntity *>(entity.get()) != nullptr)  facadeClass = [::OOVisualEffectEntity class];
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
		ship->shipWillDealloc();
	}

	[UNIVERSE ensureEntityReallyRemoved:self];
	_cxxEntity->setCollisionRegion(nullptr);		// DESTROY(collisionRegion)
	[self deleteJSSelf];
	[self setOwner:nil];
	[self setAtmosphereFogging:nil];	// [atmosphereFogging release]

#ifndef NDEBUG
	gLiveEntityCount--;
	gTotalEntityMemory -= [self oo_objectSize];
#endif

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
// The beacon selectors (Entity (OOWaypointBeacon), below) are answered for a waypoint's and a
// ship's C++ part and by a subclass facade that implements them itself (the visual effect's), as
// before (beads oo-9ht.108, oo-9ht.144).
// The ship family's selectors found by name (the categories at the end of this file) are answered
// for the C++ part of the class whose facade answered them, and by a subclass facade that
// implements one itself (the visual effect's), as before (bead oo-9ht.144; they were the ship's
// facade's until then).
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
		return class_getInstanceMethod(object_getClass(self), selector) != class_getInstanceMethod([::Entity class], selector);
	}
	const bool byShip = IsShipSelectorCalledByName(selector), byPlayer = IsPlayerSelectorCalledByName(selector);
	const bool byStation = IsStationSelectorCalledByName(selector), byDock = IsDockSelectorCalledByName(selector);
	if (byShip || byPlayer || byStation || byDock)
	{
		if (class_getInstanceMethod(object_getClass(self), selector) != class_getInstanceMethod([::Entity class], selector))  return YES;
		if (byShip && ShipPart(_cxxEntity.get()) != nullptr)  return YES;
		// a proxy's part answers its dials (its facade answered them until bead oo-9ht.183)
		if (byPlayer && IsProxySelectorCalledByName(selector) && ProxyPart(_cxxEntity.get()) != nullptr)  return YES;
		if (byPlayer && PlayerEntityPart(_cxxEntity.get()) != nullptr)  return YES;
		return (byStation && StationPart(_cxxEntity.get()) != nullptr) || (byDock && DockPart(_cxxEntity.get()) != nullptr);
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


- (std::vector<oo::ObjCRef<OOTexture *>>) cxx_allTextures
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
	return ship != nullptr ? ship->isShipWithSubEntityShip(other) : NO;
}


- (void) drawSubEntityImmediate:(bool)immediate translucent:(bool)translucent
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->drawSubEntityImmediate(immediate, translucent);
	// Otherwise do nothing.
}

@end


/*	The waypoint's and the ship's OOBeaconEntity selectors (beads oo-9ht.108, oo-9ht.144; ADR-0056
	amendments oo-9ht.106, oo-9ht.144). A waypoint or a ship is a beacon in the universe's beacon
	list, which holds and messages the beacons' Objective-C objects (ships, visual effects,
	waypoints) by the protocol, and since their facades were deleted their objects are the root's
	and the drawable's facades. These answer the C++ ship's or waypoint's members, as the ship's
	facade and the waypoint's did, and zero (a message to nil's answer) for any other entity's part;
	the visual effect's facade implements them itself, so its objects never reach these. -[Entity
	respondsToSelector:] answers them as before.
*/
@implementation Entity (OOWaypointBeacon)

- (OOComparisonResult) compareBeaconCodeWith:(Entity<OOBeaconEntity> *)other
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  return ship->compareBeaconCodeWith(other);
	OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get());
	return waypoint != nullptr ? waypoint->compareBeaconCodeWith(other) : (OOComparisonResult)0;
}


- (std::optional<std::string>) beaconCode
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  return ship->beaconCode();
	OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get());
	return waypoint != nullptr ? waypoint->beaconCode() : std::nullopt;
}


- (void) setBeaconCode:(const std::optional<std::string> &)bcode
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setBeaconCode(bcode);
	else if (OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get()))  waypoint->setBeaconCode(bcode);
}


- (std::optional<std::string>) beaconLabel
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  return ship->beaconLabel();
	OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get());
	return waypoint != nullptr ? waypoint->beaconLabel() : std::nullopt;
}


- (void) setBeaconLabel:(const std::optional<std::string> &)blabel
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setBeaconLabel(blabel);
	else if (OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get()))  waypoint->setBeaconLabel(blabel);
}


- (BOOL) isBeacon
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  return ship->isBeacon();
	OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get());
	return waypoint != nullptr ? waypoint->isBeacon() : NO;
}


- (OOHUDBeaconIcon *) beaconDrawable
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  return ship->beaconDrawable();
	OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get());
	return waypoint != nullptr ? waypoint->beaconDrawable() : nullptr;
}


- (Entity <OOBeaconEntity> *) prevBeacon
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  return (Entity <OOBeaconEntity> *)ship->prevBeacon();
	OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get());
	return waypoint != nullptr ? waypoint->prevBeacon() : nil;
}


- (Entity <OOBeaconEntity> *) nextBeacon
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  return (Entity <OOBeaconEntity> *)ship->nextBeacon();
	OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get());
	return waypoint != nullptr ? waypoint->nextBeacon() : nil;
}


- (void) setPrevBeacon:(Entity <OOBeaconEntity> *)beaconShip
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setPrevBeacon(beaconShip);
	else if (OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get()))  waypoint->setPrevBeacon(beaconShip);
}


- (void) setNextBeacon:(Entity <OOBeaconEntity> *)beaconShip
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setNextBeacon(beaconShip);
	else if (OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get()))  waypoint->setNextBeacon(beaconShip);
}


- (BOOL) isJammingScanning
{
	if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  return ship->isJammingScanning();
	OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(_cxxEntity.get());
	return waypoint != nullptr ? waypoint->isJammingScanning() : NO;
}

@end


/*	The ship family's selectors found by name (bead oo-9ht.144, ADR-0056 amendment oo-9ht.144).
	Since the ship's facade was deleted, a ship's Objective-C object is OOEntityWithDrawable's
	facade, and the game still finds selectors on it by name: AI actions, legacy-script actions and
	queries, ship.call() and callObjC(), the string expander's keys, shader bindings, deferred calls
	and the joystick callback. The ship's facade answered them with the categories below (the
	player's, the proxy's, the station's and the dock's since their facades went: beads oo-9ht.177,
	oo-9ht.183, oo-9ht.175, oo-9ht.180), which are moved here unchanged but for their receiver: each
	asks the C++ part of its class and answers nothing (zero) for any other entity, and
	-respondsToSelector: (above) answers each for that class's part only, so every other entity
	still does not respond, as before. Not declared in a header: converted code calls the C++
	members. They go with the root's facade (oo-9ht.39), when they become C++ name tables.
*/
namespace {

// A ship's part (bead oo-9ht.144): the ship's facade, a subclass of this one, answered the selectors
// the category Entity (OOShipSelectorsCalledByName) below answers for a ship; nullptr for any other
// entity.
ShipEntity *ShipPart(cxx::Entity *entity)
{
	return dynamic_cast<ShipEntity *>(entity);
}


// The selectors of the category Entity (OOShipSelectorsCalledByName) below.
bool IsShipSelectorCalledByName(SEL selector)
{
	static const std::unordered_set<std::string> names =
	{
		"cxx_setUpFromDictionary:",
		"setUpShipFromDictionary:",
		"subIdx",
		"maxShipSubEntities",
		"cxx_deserializeShipSubEntitiesFrom:",
		"setUpSubEntities",
		"setUpOneSubentity:",
		"setUpOneFlasher:",
		"isTemplateCargoPod",
		"setUpCargoType:",
		"removeScript",
		"clearSubEntities",
		"subEntityRotationalVelocity",
		"sunGlareFilter",
		"accuracy",
		"forwardVector",
		"upVector",
		"rightVector",
		"scriptedMisjump",
		"scriptedMisjumpRange",
		"subEntityCount",
		"subEntityTakingDamage",
		"shipAIScriptWakeTime",
		"volume",
		"absoluteTractorPosition",
		"isBoulder",
		"isMinable",
		"countsAsKill",
		"setUpEscorts",
		"setUpMixedEscorts",
		"cxx_shipInfoDictionary",
		"isFrangible",
		"suppressFlightNotifications",
		"noteFrustration:",
		"cxx_countEquipmentItem:",
		"hasEquipmentItem:",
		"cxx_hasEquipmentItemProviding:",
		"hasAllEquipment:",
		"hasHyperspaceMotor",
		"hyperspaceSpinTime",
		"passengerListForScripting",
		"parcelListForScripting",
		"contractListForScripting",
		"equipmentCount",
		"removeEquipmentItem:",
		"removeAllEquipment",
		"removeMissiles",
		"parcelCount",
		"passengerCount",
		"passengerCapacity",
		"missileCount",
		"missileCapacity",
		"extraCargo",
		"hasScoop",
		"hasFuelScoop",
		"hasCargoScoop",
		"hasECM",
		"hasCloakingDevice",
		"hasMilitaryScannerFilter",
		"hasMilitaryJammer",
		"hasExpandedCargoBay",
		"hasShieldBooster",
		"hasMilitaryShieldEnhancer",
		"hasHeatShield",
		"hasFuelInjection",
		"hasCascadeMine",
		"hasEscapePod",
		"hasDockingComputer",
		"hasGalacticHyperdrive",
		"shieldBoostFactor",
		"maxForwardShieldLevel",
		"maxAftShieldLevel",
		"shieldRechargeRate",
		"maxHyperspaceDistance",
		"afterburnerFactor",
		"afterburnerRate",
		"maxThrust",
		"thrust",
		"reactionTime",
		"calculateTargetPosition",
		"startTrackingCurve",
		"updateTrackingCurve",
		"calculateTrackingCurve",
#ifndef NDEBUG
		"drawDebugStuff",
#endif
		"isCloaked",
		"cloakPassive",
		"hasAutoCloak",
		"avoidCollision",
		"resumePostProximityAlert",
		"messageTime",
		"hasEscorts",
		"escortCount",
		"pendingEscortCount",
		"maxEscortCount",
		"turretCount",
		"proximityAlert",
		"hasRole:",
		"addRole:",
		"cxx_removeRole:",
		"setPrimaryRole:",
		"cxx_hasPrimaryRole:",
		"isPolice",
		"isThargoid",
		"isTrader",
		"isPirate",
		"isMissile",
		"isMine",
		"isWeapon",
		"isEscort",
		"isShuttle",
		"isTurret",
		"isPirateVictim",
		"isExplicitlyUnpiloted",
		"isUnpiloted",
		"hasHostileTarget",
		"weaponRange",
		"energyRechargeRate",
		"weaponRechargeRate",
		"currentWeaponFacing",
		"scannerRange",
		"reference",
		"reportAIMessages",
		"transitionToAegisNone",
		"findNearestStellarBody",
		"checkForAegis",
		"forceAegisCheck",
		"withinStationAegis",
		"lastAegisLock",
		"homeSystem",
		"destinationSystem",
		"cxx_setSingleCrewWithRole:",
		"setStateMachine:",
		"hasAutoAI",
		"hasNewAI",
		"hasAutoWeapons",
		"frustration",
		"fuel",
		"fuelCapacity",
		"fuelChargeRate",
		"bounty",
		"legalStatus",
		"commodityAmount",
		"maxAvailableCargoSpace",
		"availableCargoSpace",
		"cargoQuantityOnBoard",
		"cargoType",
		"cxx_cargoCount",
		"cargoListForScripting",
		"showScoopMessage",
		"desiredSpeed",
		"desiredRange",
		"cruiseSpeed",
		"flightRoll",
		"flightPitch",
		"flightYaw",
		"flightSpeed",
		"maxFlightPitch",
		"maxFlightSpeed",
		"maxFlightRoll",
		"maxFlightYaw",
		"speedFactor",
		"temperature",
		"randomEjectaTemperature",
		"heatInsulation",
		"damage",
		"dealEnergyDamageWithinDesiredRange",
		"isHulk",
		"releaseCargoPodsDebris",
		"showDamage",
		"becomeExplosion",
		"becomeEnergyBlast",
		"broadcastEnergyBlastImminent",
		"weaponRecoveryTime",
		"laserHeatLevel",
		"laserHeatLevelAft",
		"laserHeatLevelForward",
		"laserHeatLevelPort",
		"laserHeatLevelStarboard",
		"hullHeatLevel",
		"entityPersonality",
		"entityPersonalityInt",
		"randomSeedForShaders",
		"resetExhaustPlumes",
		"checkScanner",
		"checkScannerIgnoringUnpowered",
		"numberOfScannedShips",
		"foundTarget",
		"primaryAggressor",
		"lastEscortTarget",
		"thankedShip",
		"rememberedShip",
		"targetStation",
		"canStillTrackPrimaryTarget",
		"shipHitByLaser",
		"noteLostTarget",
		"noteLostTargetAndGoIdle",
		"behaviour",
		"destination",
		"coordinates",
		"rangeToDestination",
		"defenseTargetCount",
		"validateDefenseTargets",
		"removeAllDefenseTargets",
		"rangeToPrimaryTarget",
		"approachAspectToPrimaryTarget",
		"currentAimTolerance",
		"shotTime",
		"resetShotTime",
		"fireDirectLaserDefensiveShot",
		"missedShots",
		"missileLaunchPosition",
		"fireMissile",
		"isMissileFlagSet",
		"missileLoadTime",
		"noticeECM",
		"fireECM",
		"activateCloakingDevice",
		"deactivateCloakingDevice",
		"launchCascadeMine",
		"launchEscapeCapsule",
		"dumpCargo",
		"manageCollisions",
		"thrustVector",
		"suppressTargetLost",
		"abandonShip",
		"enterWitchspace",
		"leaveWitchspace",
		"witchspaceLeavingEffects",
		"switchLightsOn",
		"switchLightsOff",
		"lightsActive",
		"updateEscortFormation",
		"refreshEscortPositions",
		"deployEscorts",
		"dockEscorts",
		"setTargetToNearestFriendlyStation",
		"setTargetToNearestStation",
		"setTargetToSystemStation",
		"abortDocking",
		"cxx_dockingInstructions",
		"broadcastThargoidDestroyed",
		"broadcastAIMessage:",
		"setCommsMessageColor",
		"markedForFines",
		"markForFines",
		"isMining",
		"interpretAIMessage:",
		"spawn:",
		"checkShipsInVicinityForWitchJumpExit",
		"trackCloseContacts",
#if OO_SALVAGE_SUPPORT
		"claimAsSalvage",
		"sendCoordinatesToPilot",
#endif
#if OO_SALVAGE_SUPPORT
		"pilotArrived",
#endif
		"scriptInfo",
		"overrideScriptInfo:",
		"entityForShaderProperties",
		"isDemoShip",
		"getDemoStartTime",
		"sendAIMessage:",
		"alertCondition",
		"realAlertCondition",
		"doNothing",
		"setAITo:",
		"setAIScript:",
		"switchAITo:",
		"scanForHostiles",
		"groupAttackTarget",
		"performAttack",
		"performCollect",
		"performEscort",
		"performFaceDestination",
		"performFlee",
		"performFlyToRangeFromDestination",
		"performHold",
		"performIdle",
		"performIntercept",
		"performLandOnPlanet",
		"performMining",
		"performScriptedAI",
		"performScriptedAttackAI",
		"performBuoyTumble",
		"performStop",
		"performTumble",
		"requestDockingCoordinates",
		"recallDockingInstructions",
		"scanForNearestIncomingMissile",
		"enterPlayerWormhole",
		"enterTargetWormhole",
		"wormholeEscorts",
		"wormholeEntireGroup",
		"broadcastDistressMessage",
		"checkFoundTarget",
		"increaseAlertLevel",
		"decreaseAlertLevel",
		"launchPolice",
		"launchDefenseShip",
		"launchScavenger",
		"launchMiner",
		"launchPirateShip",
		"launchShuttle",
		"launchTrader",
		"launchEscort",
		"launchPatrol",
		"launchShipWithRole:",
		"abortAllDockings",
		"setStateTo:",
		"pauseAI:",
		"randomPauseAI:",
		"dropMessages:",
		"debugDumpPendingMessages",
		"setDestinationToCurrentLocation",
		"setDestinationToJinkPosition",
		"setDesiredRangeTo:",
		"setDesiredRangeForWaypoint",
		"setSpeedTo:",
		"setSpeedFactorTo:",
		"setSpeedToCruiseSpeed",
		"setThrustFactorTo:",
		"setTargetToPrimaryAggressor",
		"addPrimaryAggressorAsDefenseTarget",
		"scanForNearestMerchantman",
		"scanForRandomMerchantman",
		"scanForLoot",
		"scanForRandomLoot",
		"setTargetToFoundTarget",
		"addFoundTargetAsDefenseTarget",
		"checkForFullHold",
		"getWitchspaceEntryCoordinates",
		"setDestinationFromCoordinates",
		"setCoordinatesFromPosition",
		"fightOrFleeMissile",
		"setCourseToPlanet",
		"setTakeOffFromPlanet",
		"landOnPlanet",
		"checkTargetLegalStatus",
		"checkOwnLegalStatus",
		"exitAIWithMessage:",
		"setDestinationToTarget",
		"setDestinationWithinTarget",
		"checkCourseToDestination",
		"checkAegis",
		"checkEnergy",
		"checkHeatInsulation",
		"findNewDefenseTarget",
		"scanForOffenders",
		"setCourseToWitchpoint",
		"setDestinationToWitchpoint",
		"setDestinationToStationBeacon",
		"performHyperSpaceExit",
		"performHyperSpaceExitWithoutReplacing",
		"disengageAutopilot",
		"wormholeGroup",
		"commsMessage:",
		"commsMessageByUnpiloted:",
		"ejectCargo",
		"scanForThargoid",
		"scanForNonThargoid",
		"thargonCheckMother",
		"becomeUncontrolledThargon",
		"checkDistanceTravelled",
		"fightOrFleeHostiles",
		"suggestEscort",
		"escortCheckMother",
		"checkGroupOddsVersusTarget",
		"scanForFormationLeader",
		"messageMother:",
		"messageSelf:",
		"setPlanetPatrolCoordinates",
		"setSunSkimStartCoordinates",
		"setSunSkimEndCoordinates",
		"setSunSkimExitCoordinates",
		"patrolReportIn",
		"checkForMotherStation",
		"sendTargetCommsMessage:",
		"markTargetForFines",
		"markTargetForOffence:",
		"storeTarget",
		"recallStoredTarget",
		"scanForRocks",
		"setDestinationToDockingAbort",
		"requestNewTarget",
		"rollD:",
		"scanForNearestShipWithPrimaryRole:",
		"scanForNearestShipHavingRole:",
		"scanForNearestShipWithAnyPrimaryRole:",
		"scanForNearestShipHavingAnyRole:",
		"scanForNearestShipWithScanClass:",
		"scanForNearestShipWithoutPrimaryRole:",
		"scanForNearestShipNotHavingRole:",
		"scanForNearestShipWithoutAnyPrimaryRole:",
		"scanForNearestShipNotHavingAnyRole:",
		"scanForNearestShipWithoutScanClass:",
		"scanForNearestShipMatchingPredicate:",
		"setCoordinates:",
		"checkForNormalSpace",
		"setTargetToRandomStation",
		"setTargetToLastStation",
		"addFuel:",
		"scriptActionOnTarget:",
		"safeScriptActionOnTarget:",
		"sendScriptMessage:",
		"ai_throwSparks",
		"explodeSelf",
		"ai_debugMessage:",
		"targetFirstBeaconWithCode:",
		"targetNextBeaconWithCode:",
		"setRacepointsFromTarget",
		"performFlyRacepoints",
	};
	return names.contains(sel_getName(selector));
}

}	// namespace


namespace {

// A station's part (bead oo-9ht.175): its facade, a subclass of the ship's, answered the selectors the
// categories below answer for a station; nullptr for any other entity.
StationEntity *StationPart(cxx::Entity *entity)
{
	return dynamic_cast<StationEntity *>(entity);
}


// A dock's part (bead oo-9ht.180): its facade, a subclass of the ship's, answered the selectors the
// category Entity (OODockSelectorsCalledByName) below answers for a dock; nullptr for any other entity.
DockEntity *DockPart(cxx::Entity *entity)
{
	return dynamic_cast<DockEntity *>(entity);
}


// The selectors of the category ShipEntity (OODockSelectorsCalledByName) below, and those both the
// station's facade and the dock's answered (the station's category below answers them for a dock's
// part too).
bool IsDockSelectorCalledByName(SEL selector)
{
	static const std::unordered_set<std::string> names =
	{
		"allowsDocking",
		"disallowedDockingCollides",
		"countOfShipsInDockingQueue",
		"allowsLaunching",
		"countOfShipsInLaunchQueue",
		"isOffCentre",
		"setVirtual",
		"clearAllIdLocks",
		"pruneAndCountShipsOnApproach",
		"abortAllLaunches",
		"clear",
		"autoDockShipsOnApproach",
		"dockingCorridorIsEmpty",
		"clearDockingCorridor",
		"countOfShipsInLaunchQueueWithPrimaryRole:",
	};
	return names.contains(sel_getName(selector));
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


/*	The player's selectors found by name (bead oo-9ht.177, ADR-0056 amendment oo-9ht.177). Since its
	facade was deleted, the player's Objective-C object was the ship's facade (the drawable's since
	bead oo-9ht.144), and the game still finds
	selectors on it by name: legacy-script actions and queries, AI actions, ship.call() and
	callObjC(), the string expander's keys, shader bindings, deferred calls and the joystick
	callback. These are exactly the selectors only the player's facade answered whose signature a
	by-name dispatcher can call (OOCallByName.h, OOJSCall.mm, OOShaderUniformMethodType.mm): no
	argument, or one std::string or oo::PList argument, and a void, property-list, scalar, vector,
	quaternion, matrix, point or object result. Each answers the player's C++ member, and nothing
	(zero) for any other ship; -respondsToSelector: answers them for the player's C++ part only,
	so every other ship still does not respond, as before. Moved from the ship's facade by bead
	oo-9ht.144.
*/
namespace {

PlayerEntity *PlayerEntityPart(cxx::Entity *entity)
{
	return dynamic_cast<PlayerEntity *>(entity);
}


/*	The proxy's dials (bead oo-9ht.183): its facade, a subclass of the ship's, answered these itself
	(the shaders of the shipyard's and the doppelganger's ships bind them by name), so for a proxy's
	part these answer the proxy's members, and -respondsToSelector: answers them.
*/
ProxyPlayerEntity *ProxyPart(cxx::Entity *entity)
{
	return dynamic_cast<ProxyPlayerEntity *>(entity);
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


/*	The ship's own selectors found by name: exactly those the ship's facade answered, and the root's
	and the drawable's facades do not, whose signature a by-name dispatcher can call (OOCallByName.h,
	OOJSCall.mm, OOShaderUniformMethodType.mm): no argument, or one std::string or oo::PList
	argument, and a void, property-list, scalar, vector, quaternion, matrix, point or object result
	(an object result is the object, as the facade answered). Each answers the ship's C++ member, as
	the facade's forwarder did, and nothing (zero) for any other entity.
*/
@implementation Entity (OOShipSelectorsCalledByName)

- (BOOL) cxx_setUpFromDictionary:(const oo::PList &)inShipDict	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->setUpFromDictionary(inShipDict) : NO; }
- (BOOL) setUpShipFromDictionary:(const oo::PList &)shipDict	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->setUpShipFromDictionary(shipDict) : NO; }
- (NSUInteger) subIdx	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->subIdx() : NSUInteger{}; }
- (NSUInteger) maxShipSubEntities	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->maxShipSubEntities() : NSUInteger{}; }
- (void) cxx_deserializeShipSubEntitiesFrom:(const std::string &)string	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->deserializeShipSubEntitiesFrom(string); }
- (BOOL) setUpSubEntities	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->setUpSubEntities() : NO; }
- (BOOL) setUpOneSubentity:(const oo::PList &)subentDict	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->setUpOneSubentity(subentDict) : NO; }
- (BOOL) setUpOneFlasher:(const oo::PList &)subentDict	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->setUpOneFlasher(subentDict) : NO; }
- (BOOL) isTemplateCargoPod	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->isTemplateCargoPod() : NO; }
- (void) setUpCargoType:(const std::string &)cargoString	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setUpCargoType(cargoString); }
- (void) removeScript	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->removeScript(); }
- (void) clearSubEntities	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->clearSubEntities(); }
- (Quaternion) subEntityRotationalVelocity	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->subEntityRotationalVelocity() : kIdentityQuaternion; }
- (GLfloat) sunGlareFilter	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getSunGlareFilter() : GLfloat{}; }
- (GLfloat) accuracy	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getAccuracy() : GLfloat{}; }
- (Vector) forwardVector	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->forwardVector() : kZeroVector; }
- (Vector) upVector	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->upVector() : kZeroVector; }
- (Vector) rightVector	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->rightVector() : kZeroVector; }
- (BOOL) scriptedMisjump	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->scriptedMisjump() : NO; }
- (GLfloat) scriptedMisjumpRange	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->scriptedMisjumpRange() : GLfloat{}; }
- (NSUInteger) subEntityCount	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->subEntityCount() : NSUInteger{}; }
- (Entity *) subEntityTakingDamage	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? oo::ToObjC(ship->subEntityTakingDamage()) : nil; }
- (OOTimeAbsolute) shipAIScriptWakeTime	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->shipAIScriptWakeTime() : OOTimeAbsolute{}; }
- (float) volume	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->volume() : float{}; }
- (HPVector) absoluteTractorPosition	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->absoluteTractorPosition() : kZeroHPVector; }
- (BOOL) isBoulder	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->isBoulder() : NO; }
- (BOOL) isMinable	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->isMinable() : NO; }
- (BOOL) countsAsKill	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->countsAsKill() : NO; }
- (void) setUpEscorts	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setUpEscorts(); }
- (void) setUpMixedEscorts	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setUpMixedEscorts(); }
- (oo::PList) cxx_shipInfoDictionary	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->shipInfoDictionary() : oo::PList(); }
- (BOOL) isFrangible	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getIsFrangible() : NO; }
- (BOOL) suppressFlightNotifications	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->suppressFlightNotifications() : NO; }
- (void) noteFrustration:(const std::string &)context	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->noteFrustration(context); }
- (NSUInteger) cxx_countEquipmentItem:(const std::string &)eqkey	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->countEquipmentItem(eqkey) : NSUInteger{}; }
- (BOOL) hasEquipmentItem:(const oo::PList &)equipmentKeys	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasEquipmentItem(equipmentKeys) : NO; }
- (BOOL) cxx_hasEquipmentItemProviding:(const std::string &)equipmentType	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasEquipmentItemProviding(equipmentType) : NO; }
- (BOOL) hasAllEquipment:(const oo::PList &)equipmentKeys	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasAllEquipment(equipmentKeys) : NO; }
- (BOOL) hasHyperspaceMotor	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasHyperspaceMotor() : NO; }
- (float) hyperspaceSpinTime	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hyperspaceSpinTime() : float{}; }
- (oo::PList) passengerListForScripting	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->passengerListForScripting() : oo::PList(); }
- (oo::PList) parcelListForScripting	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->parcelListForScripting() : oo::PList(); }
- (oo::PList) contractListForScripting	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->contractListForScripting() : oo::PList(); }
- (NSUInteger) equipmentCount	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->equipmentCount() : NSUInteger{}; }
- (void) removeEquipmentItem:(const std::string &)equipmentKey	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->removeEquipmentItem(equipmentKey); }
- (void) removeAllEquipment	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->removeAllEquipment(); }
- (OOCreditsQuantity) removeMissiles	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->removeMissiles() : OOCreditsQuantity{}; }
- (NSUInteger) parcelCount	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->parcelCount() : NSUInteger{}; }
- (NSUInteger) passengerCount	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->passengerCount() : NSUInteger{}; }
- (NSUInteger) passengerCapacity	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->passengerCapacity() : NSUInteger{}; }
- (NSUInteger) missileCount	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->missileCount() : NSUInteger{}; }
- (NSUInteger) missileCapacity	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->missileCapacity() : NSUInteger{}; }
- (NSUInteger) extraCargo	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->extraCargo() : NSUInteger{}; }
- (BOOL) hasScoop	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasScoop() : NO; }
- (BOOL) hasFuelScoop	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasFuelScoop() : NO; }
- (BOOL) hasCargoScoop	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasCargoScoop() : NO; }
- (BOOL) hasECM	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasECM() : NO; }
- (BOOL) hasCloakingDevice	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasCloakingDevice() : NO; }
- (BOOL) hasMilitaryScannerFilter	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasMilitaryScannerFilter() : NO; }
- (BOOL) hasMilitaryJammer	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasMilitaryJammer() : NO; }
- (BOOL) hasExpandedCargoBay	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasExpandedCargoBay() : NO; }
- (BOOL) hasShieldBooster	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasShieldBooster() : NO; }
- (BOOL) hasMilitaryShieldEnhancer	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasMilitaryShieldEnhancer() : NO; }
- (BOOL) hasHeatShield	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasHeatShield() : NO; }
- (BOOL) hasFuelInjection	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasFuelInjection() : NO; }
- (BOOL) hasCascadeMine	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasCascadeMine() : NO; }
- (BOOL) hasEscapePod	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasEscapePod() : NO; }
- (BOOL) hasDockingComputer	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasDockingComputer() : NO; }
- (BOOL) hasGalacticHyperdrive	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasGalacticHyperdrive() : NO; }
- (float) shieldBoostFactor	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->shieldBoostFactor() : float{}; }
- (float) maxForwardShieldLevel	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->maxForwardShieldLevel() : float{}; }
- (float) maxAftShieldLevel	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->maxAftShieldLevel() : float{}; }
- (float) shieldRechargeRate	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->shieldRechargeRate() : float{}; }
- (double) maxHyperspaceDistance	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->maxHyperspaceDistance() : double{}; }
- (float) afterburnerFactor	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->afterburnerFactor() : float{}; }
- (float) afterburnerRate	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->afterburnerRate() : float{}; }
- (float) maxThrust	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->maxThrust() : float{}; }
- (float) thrust	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getThrust() : float{}; }
- (float) reactionTime	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getReactionTime() : float{}; }
- (HPVector) calculateTargetPosition	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->calculateTargetPosition() : kZeroHPVector; }
- (void) startTrackingCurve	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->startTrackingCurve(); }
- (void) updateTrackingCurve	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->updateTrackingCurve(); }
- (void) calculateTrackingCurve	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->calculateTrackingCurve(); }
#ifndef NDEBUG
- (void) drawDebugStuff	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->drawDebugStuff(); }
#endif
- (BOOL) isCloaked	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->isCloaked() : NO; }
- (BOOL) cloakPassive	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getCloakPassive() : NO; }
- (BOOL) hasAutoCloak	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasAutoCloak() : NO; }
- (void) avoidCollision	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->avoidCollision(); }
- (void) resumePostProximityAlert	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->resumePostProximityAlert(); }
- (double) messageTime	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getMessageTime() : double{}; }
- (BOOL) hasEscorts	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasEscorts() : NO; }
- (uint8_t) escortCount	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->escortCount() : uint8_t{}; }
- (uint8_t) pendingEscortCount	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->pendingEscortCount() : uint8_t{}; }
- (uint8_t) maxEscortCount	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->maxEscortCount() : uint8_t{}; }
- (NSUInteger) turretCount	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->turretCount() : NSUInteger{}; }
- (Entity *) proximityAlert	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->proximityAlert() : nil; }
- (BOOL) hasRole:(const std::string &)role	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasRole(role) : NO; }
- (void) addRole:(const std::string &)role	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->addRole(role); }
- (void) cxx_removeRole:(const std::string &)role	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->removeRole(role); }
- (void) setPrimaryRole:(const std::string &)role	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setPrimaryRole(role); }
- (BOOL) cxx_hasPrimaryRole:(const std::string &)role	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasPrimaryRole(role) : NO; }
- (BOOL) isPolice	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->isPolice() : NO; }
- (BOOL) isThargoid	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->isThargoid() : NO; }
- (BOOL) isTrader	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->isTrader() : NO; }
- (BOOL) isPirate	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->isPirate() : NO; }
- (BOOL) isMissile	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getIsMissile() : NO; }
- (BOOL) isMine	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->isMine() : NO; }
- (BOOL) isWeapon	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->isWeapon() : NO; }
- (BOOL) isEscort	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->isEscort() : NO; }
- (BOOL) isShuttle	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->isShuttle() : NO; }
- (BOOL) isTurret	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->isTurret() : NO; }
- (BOOL) isPirateVictim	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->isPirateVictim() : NO; }
- (BOOL) isExplicitlyUnpiloted	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->isExplicitlyUnpiloted() : NO; }
- (BOOL) isUnpiloted	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->isUnpiloted() : NO; }
- (BOOL) hasHostileTarget	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasHostileTarget() : NO; }
- (GLfloat) weaponRange	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getWeaponRange() : GLfloat{}; }
- (float) energyRechargeRate	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->energyRechargeRate() : float{}; }
- (float) weaponRechargeRate	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->weaponRechargeRate() : float{}; }
- (OOWeaponFacing) currentWeaponFacing	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getCurrentWeaponFacing() : OOWeaponFacing{}; }
- (GLfloat) scannerRange	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getScannerRange() : GLfloat{}; }
- (Vector) reference	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getReference() : kZeroVector; }
- (BOOL) reportAIMessages	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getReportAIMessages() : NO; }
- (void) transitionToAegisNone	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->transitionToAegisNone(); }
- (Entity *) findNearestStellarBody	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? (Entity<OOStellarBody> *)ship->findNearestStellarBody() : nil; }
- (OOAegisStatus) checkForAegis	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->checkForAegis() : OOAegisStatus{}; }
- (void) forceAegisCheck	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->forceAegisCheck(); }
- (BOOL) withinStationAegis	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->withinStationAegis() : NO; }
- (Entity *) lastAegisLock	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? (Entity<OOStellarBody> *)ship->lastAegisLock() : nil; }
- (OOSystemID) homeSystem	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->homeSystem() : OOSystemID{}; }
- (OOSystemID) destinationSystem	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->destinationSystem() : OOSystemID{}; }
- (void) cxx_setSingleCrewWithRole:(const std::string &)crewRole	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setSingleCrewWithRole(crewRole); }
- (void) setStateMachine:(const std::string &)smName	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setStateMachine(smName); }
- (BOOL) hasAutoAI	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasAutoAI() : NO; }
- (BOOL) hasNewAI	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasNewAI() : NO; }
- (BOOL) hasAutoWeapons	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hasAutoWeapons() : NO; }
- (double) frustration	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getFrustration() : double{}; }
- (OOFuelQuantity) fuel	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getFuel() : OOFuelQuantity{}; }
- (OOFuelQuantity) fuelCapacity	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->fuelCapacity() : OOFuelQuantity{}; }
- (GLfloat) fuelChargeRate	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->fuelChargeRate() : GLfloat{}; }
- (OOCreditsQuantity) bounty	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getBounty() : OOCreditsQuantity{}; }
- (int) legalStatus	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->legalStatus() : int{}; }
- (OOCargoQuantity) commodityAmount	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->commodityAmount() : OOCargoQuantity{}; }
- (OOCargoQuantity) maxAvailableCargoSpace	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->maxAvailableCargoSpace() : OOCargoQuantity{}; }
- (OOCargoQuantity) availableCargoSpace	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->availableCargoSpace() : OOCargoQuantity{}; }
- (OOCargoQuantity) cargoQuantityOnBoard	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->cargoQuantityOnBoard() : OOCargoQuantity{}; }
- (OOCargoType) cargoType	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->cargoType() : CARGO_NOT_CARGO; }	// (not cargo: the enum has no zero)
- (NSUInteger) cxx_cargoCount	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->cargoCount() : NSUInteger{}; }
- (oo::PList) cargoListForScripting	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->cargoListForScripting() : oo::PList(); }
- (BOOL) showScoopMessage	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->showScoopMessage() : NO; }
- (double) desiredSpeed	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->desiredSpeed() : double{}; }
- (double) desiredRange	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->desiredRange() : double{}; }
- (double) cruiseSpeed	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getCruiseSpeed() : double{}; }
- (GLfloat) flightRoll	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getFlightRoll() : GLfloat{}; }
- (GLfloat) flightPitch	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getFlightPitch() : GLfloat{}; }
- (GLfloat) flightYaw	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getFlightYaw() : GLfloat{}; }
- (GLfloat) flightSpeed	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getFlightSpeed() : GLfloat{}; }
- (GLfloat) maxFlightPitch	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->maxFlightPitch() : GLfloat{}; }
- (GLfloat) maxFlightSpeed	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getMaxFlightSpeed() : GLfloat{}; }
- (GLfloat) maxFlightRoll	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->maxFlightRoll() : GLfloat{}; }
- (GLfloat) maxFlightYaw	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->maxFlightYaw() : GLfloat{}; }
- (GLfloat) speedFactor	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->speedFactor() : GLfloat{}; }
- (GLfloat) temperature	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->temperature() : GLfloat{}; }
- (float) randomEjectaTemperature	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->randomEjectaTemperature() : float{}; }
- (GLfloat) heatInsulation	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->heatInsulation() : GLfloat{}; }
- (int) damage	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->damage() : int{}; }
- (void) dealEnergyDamageWithinDesiredRange	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->dealEnergyDamageWithinDesiredRange(); }
- (BOOL) isHulk	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getIsHulk() : NO; }
- (void) releaseCargoPodsDebris	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->releaseCargoPodsDebris(); }
- (BOOL) showDamage	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->showDamage() : NO; }
- (void) becomeExplosion	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->becomeExplosion(); }
- (void) becomeEnergyBlast	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->becomeEnergyBlast(); }
- (void) broadcastEnergyBlastImminent	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->broadcastEnergyBlastImminent(); }
- (GLfloat) weaponRecoveryTime	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->weaponRecoveryTime() : GLfloat{}; }
- (GLfloat) laserHeatLevel	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->laserHeatLevel() : GLfloat{}; }
- (GLfloat) laserHeatLevelAft	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->laserHeatLevelAft() : GLfloat{}; }
- (GLfloat) laserHeatLevelForward	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->laserHeatLevelForward() : GLfloat{}; }
- (GLfloat) laserHeatLevelPort	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->laserHeatLevelPort() : GLfloat{}; }
- (GLfloat) laserHeatLevelStarboard	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->laserHeatLevelStarboard() : GLfloat{}; }
- (GLfloat) hullHeatLevel	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->hullHeatLevel() : GLfloat{}; }
- (GLfloat) entityPersonality	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->entityPersonality() : GLfloat{}; }
- (GLint) entityPersonalityInt	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->entityPersonalityInt() : GLint{}; }
- (uint32_t) randomSeedForShaders	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->randomSeedForShaders() : uint32_t{}; }
- (void) resetExhaustPlumes	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->resetExhaustPlumes(); }
- (void) checkScanner	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->checkScanner(); }
- (void) checkScannerIgnoringUnpowered	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->checkScannerIgnoringUnpowered(); }
- (int) numberOfScannedShips	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->numberOfScannedShips() : int{}; }
- (Entity *) foundTarget	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->foundTarget() : nil; }
- (Entity *) primaryAggressor	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->primaryAggressor() : nil; }
- (Entity *) lastEscortTarget	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->lastEscortTarget() : nil; }
- (Entity *) thankedShip	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->thankedShip() : nil; }
- (Entity *) rememberedShip	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->rememberedShip() : nil; }
- (Entity *) targetStation	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->targetStation() : nil; }
- (BOOL) canStillTrackPrimaryTarget	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->canStillTrackPrimaryTarget() : NO; }
- (Entity *) shipHitByLaser	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? oo::ToObjC(ship->shipHitByLaser()) : nil; }
- (void) noteLostTarget	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->noteLostTarget(); }
- (void) noteLostTargetAndGoIdle	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->noteLostTargetAndGoIdle(); }
- (OOBehaviour) behaviour	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getBehaviour() : OOBehaviour{}; }
- (HPVector) destination	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->destination() : kZeroHPVector; }
- (HPVector) coordinates	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getCoordinates() : kZeroHPVector; }
- (GLfloat) rangeToDestination	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->rangeToDestination() : GLfloat{}; }
- (NSUInteger) defenseTargetCount	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->defenseTargetCount() : NSUInteger{}; }
- (void) validateDefenseTargets	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->validateDefenseTargets(); }
- (void) removeAllDefenseTargets	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->removeAllDefenseTargets(); }
- (double) rangeToPrimaryTarget	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->rangeToPrimaryTarget() : double{}; }
- (double) approachAspectToPrimaryTarget	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->approachAspectToPrimaryTarget() : double{}; }
- (GLfloat) currentAimTolerance	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->currentAimTolerance() : GLfloat{}; }
- (OOTimeDelta) shotTime	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->shotTime() : OOTimeDelta{}; }
- (void) resetShotTime	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->resetShotTime(); }
- (BOOL) fireDirectLaserDefensiveShot	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->fireDirectLaserDefensiveShot() : NO; }
- (int) missedShots	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->missedShots() : int{}; }
- (Vector) missileLaunchPosition	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->missileLaunchPosition() : kZeroVector; }
- (Entity *) fireMissile	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? oo::ToObjC(ship->fireMissile()) : nil; }
- (BOOL) isMissileFlagSet	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->isMissileFlagSet() : NO; }
- (OOTimeDelta) missileLoadTime	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->missileLoadTime() : OOTimeDelta{}; }
- (void) noticeECM	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->noticeECM(); }
- (BOOL) fireECM	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->fireECM() : NO; }
- (BOOL) activateCloakingDevice	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->activateCloakingDevice() : NO; }
- (void) deactivateCloakingDevice	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->deactivateCloakingDevice(); }
- (BOOL) launchCascadeMine	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->launchCascadeMine() : NO; }
- (Entity *) launchEscapeCapsule	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? oo::ToObjC(ship->launchEscapeCapsule()) : nil; }
- (void) dumpCargo	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->dumpCargo(); }
- (void) manageCollisions	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->manageCollisions(); }
- (Vector) thrustVector	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->thrustVector() : kZeroVector; }
- (void) suppressTargetLost	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->suppressTargetLost(); }
- (BOOL) abandonShip	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->abandonShip() : NO; }
- (void) enterWitchspace	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->enterWitchspace(); }
- (void) leaveWitchspace	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->leaveWitchspace(); }
- (BOOL) witchspaceLeavingEffects	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->witchspaceLeavingEffects() : NO; }
- (void) switchLightsOn	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->switchLightsOn(); }
- (void) switchLightsOff	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->switchLightsOff(); }
- (BOOL) lightsActive	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->lightsActive() : NO; }
- (void) updateEscortFormation	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->updateEscortFormation(); }
- (void) refreshEscortPositions	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->refreshEscortPositions(); }
- (void) deployEscorts	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->deployEscorts(); }
- (void) dockEscorts	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->dockEscorts(); }
- (void) setTargetToNearestFriendlyStation	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setTargetToNearestFriendlyStation(); }
- (void) setTargetToNearestStation	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setTargetToNearestStation(); }
- (void) setTargetToSystemStation	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setTargetToSystemStation(); }
- (void) abortDocking	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->abortDocking(); }
- (oo::PList) cxx_dockingInstructions	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getDockingInstructions() : oo::PList(); }
- (void) broadcastThargoidDestroyed	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->broadcastThargoidDestroyed(); }
- (void) broadcastAIMessage:(const std::string &)ai_message	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->broadcastAIMessage(ai_message); }
- (void) setCommsMessageColor	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setCommsMessageColor(); }
- (BOOL) markedForFines	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->markedForFines() : NO; }
- (BOOL) markForFines	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->markForFines() : NO; }
- (BOOL) isMining	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->isMining() : NO; }
- (void) interpretAIMessage:(const std::string &)ms	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->interpretAIMessage(ms); }
- (void) spawn:(const std::string &)roles_number	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->spawn(roles_number); }
- (int) checkShipsInVicinityForWitchJumpExit	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->checkShipsInVicinityForWitchJumpExit() : int{}; }
- (BOOL) trackCloseContacts	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getTrackCloseContacts() : NO; }
#if OO_SALVAGE_SUPPORT
- (void) claimAsSalvage	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->claimAsSalvage(); }
- (void) sendCoordinatesToPilot	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->sendCoordinatesToPilot(); }
#endif
#if OO_SALVAGE_SUPPORT
- (void) pilotArrived	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->pilotArrived(); }
#endif
- (oo::PList) scriptInfo	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getScriptInfo() : oo::PList(); }
- (void) overrideScriptInfo:(const oo::PList &)override	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->overrideScriptInfo(override); }
- (Entity *) entityForShaderProperties	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->entityForShaderProperties() : nil; }
- (BOOL) isDemoShip	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getIsDemoShip() : NO; }
- (OOTimeAbsolute) getDemoStartTime	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->getDemoStartTime() : OOTimeAbsolute{}; }
- (void) sendAIMessage:(const std::string &)message	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->sendAIMessage(message); }
- (OOAlertCondition) alertCondition	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->alertCondition() : OOAlertCondition{}; }
- (OOAlertCondition) realAlertCondition	{ ShipEntity *ship = ShipPart(_cxxEntity.get()); return ship != nullptr ? ship->realAlertCondition() : OOAlertCondition{}; }
- (void) doNothing	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->doNothing(); }
- (void) setAITo:(const std::string &)aiString	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setAITo(aiString); }
- (void) setAIScript:(const std::string &)aiString	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setAIScript(aiString); }
- (void) switchAITo:(const std::string &)aiString	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->switchAITo(aiString); }
- (void) scanForHostiles	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForHostiles(); }
- (void) groupAttackTarget	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->groupAttackTarget(); }
- (void) performAttack	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performAttack(); }
- (void) performCollect	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performCollect(); }
- (void) performEscort	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performEscort(); }
- (void) performFaceDestination	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performFaceDestination(); }
- (void) performFlee	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performFlee(); }
- (void) performFlyToRangeFromDestination	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performFlyToRangeFromDestination(); }
- (void) performHold	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performHold(); }
- (void) performIdle	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performIdle(); }
- (void) performIntercept	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performIntercept(); }
- (void) performLandOnPlanet	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performLandOnPlanet(); }
- (void) performMining	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performMining(); }
- (void) performScriptedAI	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performScriptedAI(); }
- (void) performScriptedAttackAI	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performScriptedAttackAI(); }
- (void) performBuoyTumble	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performBuoyTumble(); }
- (void) performStop	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performStop(); }
- (void) performTumble	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performTumble(); }
- (void) requestDockingCoordinates	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->requestDockingCoordinates(); }
- (void) recallDockingInstructions	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->recallDockingInstructions(); }
- (void) scanForNearestIncomingMissile	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForNearestIncomingMissile(); }
- (void) enterPlayerWormhole	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->enterPlayerWormhole(); }
- (void) enterTargetWormhole	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->enterTargetWormhole(); }
- (void) wormholeEscorts	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->wormholeEscorts(); }
- (void) wormholeEntireGroup	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->wormholeEntireGroup(); }
- (void) broadcastDistressMessage	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->broadcastDistressMessage(); }
- (void) checkFoundTarget	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->checkFoundTarget(); }
- (void) increaseAlertLevel
{
	ShipEntity *ship = ShipPart(_cxxEntity.get());
	if (ship == nullptr)  return;
 if (StationEntity *station = StationPart(_cxxEntity.get()))  station->increaseAlertLevel(); else  ship->increaseAlertLevel(); 
}

- (void) decreaseAlertLevel
{
	ShipEntity *ship = ShipPart(_cxxEntity.get());
	if (ship == nullptr)  return;
 if (StationEntity *station = StationPart(_cxxEntity.get()))  station->decreaseAlertLevel(); else  ship->decreaseAlertLevel(); 
}

- (oo::PList) launchPolice
{
	ShipEntity *ship = ShipPart(_cxxEntity.get());
	if (ship == nullptr)  return oo::PList();
 if (StationEntity *station = StationPart(_cxxEntity.get()))  return station->launchPolice(); return ship->launchPolice(); 
}

- (Entity *) launchDefenseShip
{
	ShipEntity *ship = ShipPart(_cxxEntity.get());
	if (ship == nullptr)  return nil;
 if (StationEntity *station = StationPart(_cxxEntity.get()))  return oo::ToObjC(station->launchDefenseShip()); ship->launchDefenseShip(); return nil; 
}

- (Entity *) launchScavenger
{
	ShipEntity *ship = ShipPart(_cxxEntity.get());
	if (ship == nullptr)  return nil;
 if (StationEntity *station = StationPart(_cxxEntity.get()))  return oo::ToObjC(station->launchScavenger()); ship->launchScavenger(); return nil; 
}

- (Entity *) launchMiner
{
	ShipEntity *ship = ShipPart(_cxxEntity.get());
	if (ship == nullptr)  return nil;
 if (StationEntity *station = StationPart(_cxxEntity.get()))  return oo::ToObjC(station->launchMiner()); ship->launchMiner(); return nil; 
}

- (Entity *) launchPirateShip
{
	ShipEntity *ship = ShipPart(_cxxEntity.get());
	if (ship == nullptr)  return nil;
 if (StationEntity *station = StationPart(_cxxEntity.get()))  return oo::ToObjC(station->launchPirateShip()); ship->launchPirateShip(); return nil; 
}

- (Entity *) launchShuttle
{
	ShipEntity *ship = ShipPart(_cxxEntity.get());
	if (ship == nullptr)  return nil;
 if (StationEntity *station = StationPart(_cxxEntity.get()))  return oo::ToObjC(station->launchShuttle()); ship->launchShuttle(); return nil; 
}

- (void) launchTrader	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->launchTrader(); }
- (Entity *) launchEscort
{
	ShipEntity *ship = ShipPart(_cxxEntity.get());
	if (ship == nullptr)  return nil;
 if (StationEntity *station = StationPart(_cxxEntity.get()))  return oo::ToObjC(station->launchEscort()); ship->launchEscort(); return nil; 
}

- (Entity *) launchPatrol
{
	ShipEntity *ship = ShipPart(_cxxEntity.get());
	if (ship == nullptr)  return nil;
 if (StationEntity *station = StationPart(_cxxEntity.get()))  return oo::ToObjC(station->launchPatrol()); (void)ship->launchPatrol(); return nil; 
}

- (void) launchShipWithRole:(const std::string &)param
{
	ShipEntity *ship = ShipPart(_cxxEntity.get());
	if (ship == nullptr)  return;
 if (StationEntity *station = StationPart(_cxxEntity.get()))  station->launchShipWithRole(param); else  ship->launchShipWithRole(param); 
}

- (void) abortAllDockings
{
	ShipEntity *ship = ShipPart(_cxxEntity.get());
	if (ship == nullptr)  return;
 if (StationEntity *station = StationPart(_cxxEntity.get()))  station->abortAllDockings(); else if (DockEntity *dock = DockPart(_cxxEntity.get()))  dock->abortAllDockings(); else  ship->abortAllDockings(); 
}

- (void) setStateTo:(const std::string &)state	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setStateTo(state); }
- (void) pauseAI:(const std::string &)intervalString	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->pauseAI(intervalString); }
- (void) randomPauseAI:(const std::string &)intervalString	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->randomPauseAI(intervalString); }
- (void) dropMessages:(const std::string &)messageString	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->dropMessages(messageString); }
- (void) debugDumpPendingMessages	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->debugDumpPendingMessages(); }
- (void) setDestinationToCurrentLocation	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setDestinationToCurrentLocation(); }
- (void) setDestinationToJinkPosition	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setDestinationToJinkPosition(); }
- (void) setDesiredRangeTo:(const std::string &)rangeString	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setDesiredRangeTo(rangeString); }
- (void) setDesiredRangeForWaypoint	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setDesiredRangeForWaypoint(); }
- (void) setSpeedTo:(const std::string &)speedString	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setSpeedTo(speedString); }
- (void) setSpeedFactorTo:(const std::string &)speedString	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setSpeedFactorTo(speedString); }
- (void) setSpeedToCruiseSpeed	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setSpeedToCruiseSpeed(); }
- (void) setThrustFactorTo:(const std::string &)thrustFactorString	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setThrustFactorTo(thrustFactorString); }
- (void) setTargetToPrimaryAggressor	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setTargetToPrimaryAggressor(); }
- (void) addPrimaryAggressorAsDefenseTarget	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->addPrimaryAggressorAsDefenseTarget(); }
- (void) scanForNearestMerchantman	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForNearestMerchantman(); }
- (void) scanForRandomMerchantman	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForRandomMerchantman(); }
- (void) scanForLoot	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForLoot(); }
- (void) scanForRandomLoot	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForRandomLoot(); }
- (void) setTargetToFoundTarget	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setTargetToFoundTarget(); }
- (void) addFoundTargetAsDefenseTarget	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->addFoundTargetAsDefenseTarget(); }
- (void) checkForFullHold	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->checkForFullHold(); }
- (void) getWitchspaceEntryCoordinates	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->getWitchspaceEntryCoordinates(); }
- (void) setDestinationFromCoordinates	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setDestinationFromCoordinates(); }
- (void) setCoordinatesFromPosition	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setCoordinatesFromPosition(); }
- (void) fightOrFleeMissile	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->fightOrFleeMissile(); }
- (void) setCourseToPlanet	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setCourseToPlanet(); }
- (void) setTakeOffFromPlanet	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setTakeOffFromPlanet(); }
- (void) landOnPlanet	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->landOnPlanet(); }
- (void) checkTargetLegalStatus	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->checkTargetLegalStatus(); }
- (void) checkOwnLegalStatus	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->checkOwnLegalStatus(); }
- (void) exitAIWithMessage:(const std::string &)message	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->exitAIWithMessage(message); }
- (void) setDestinationToTarget	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setDestinationToTarget(); }
- (void) setDestinationWithinTarget	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setDestinationWithinTarget(); }
- (void) checkCourseToDestination	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->checkCourseToDestination(); }
- (void) checkAegis	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->checkAegis(); }
- (void) checkEnergy	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->checkEnergy(); }
- (void) checkHeatInsulation	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->checkHeatInsulation(); }
- (void) findNewDefenseTarget	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->findNewDefenseTarget(); }
- (void) scanForOffenders	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForOffenders(); }
- (void) setCourseToWitchpoint	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setCourseToWitchpoint(); }
- (void) setDestinationToWitchpoint	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setDestinationToWitchpoint(); }
- (void) setDestinationToStationBeacon	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setDestinationToStationBeacon(); }
- (void) performHyperSpaceExit	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performHyperSpaceExit(); }
- (void) performHyperSpaceExitWithoutReplacing	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performHyperSpaceExitWithoutReplacing(); }
- (void) disengageAutopilot	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->disengageAutopilot(); }
- (void) wormholeGroup	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->wormholeGroup(); }
- (void) commsMessage:(const std::string &)valueString	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->commsMessage(valueString); }
- (void) commsMessageByUnpiloted:(const std::string &)valueString	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->commsMessageByUnpiloted(valueString); }
- (void) ejectCargo	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->ejectCargo(); }
- (void) scanForThargoid	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForThargoid(); }
- (void) scanForNonThargoid	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForNonThargoid(); }
- (void) thargonCheckMother	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->thargonCheckMother(); }
- (void) becomeUncontrolledThargon	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->becomeUncontrolledThargon(); }
- (void) checkDistanceTravelled	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->checkDistanceTravelled(); }
- (void) fightOrFleeHostiles	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->fightOrFleeHostiles(); }
- (void) suggestEscort	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->suggestEscort(); }
- (void) escortCheckMother	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->escortCheckMother(); }
- (void) checkGroupOddsVersusTarget	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->checkGroupOddsVersusTarget(); }
- (void) scanForFormationLeader	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForFormationLeader(); }
- (void) messageMother:(const std::string &)msgString	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->messageMother(msgString); }
- (void) messageSelf:(const std::string &)msgString	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->messageSelf(msgString); }
- (void) setPlanetPatrolCoordinates	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setPlanetPatrolCoordinates(); }
- (void) setSunSkimStartCoordinates	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setSunSkimStartCoordinates(); }
- (void) setSunSkimEndCoordinates	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setSunSkimEndCoordinates(); }
- (void) setSunSkimExitCoordinates	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setSunSkimExitCoordinates(); }
- (void) patrolReportIn	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->patrolReportIn(); }
- (void) checkForMotherStation	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->checkForMotherStation(); }
- (void) sendTargetCommsMessage:(const std::string &)message	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->sendTargetCommsMessage(message); }
- (void) markTargetForFines	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->markTargetForFines(); }
- (void) markTargetForOffence:(const std::string &)valueString	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->markTargetForOffence(valueString); }
- (void) storeTarget	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->storeTarget(); }
- (void) recallStoredTarget	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->recallStoredTarget(); }
- (void) scanForRocks	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForRocks(); }
- (void) setDestinationToDockingAbort	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setDestinationToDockingAbort(); }
- (void) requestNewTarget	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->requestNewTarget(); }
- (void) rollD:(const std::string &)die_number	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->rollD(die_number); }
- (void) scanForNearestShipWithPrimaryRole:(const std::string &)scanRole	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForNearestShipWithPrimaryRole(scanRole); }
- (void) scanForNearestShipHavingRole:(const std::string &)scanRole	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForNearestShipHavingRole(scanRole); }
- (void) scanForNearestShipWithAnyPrimaryRole:(const std::string &)scanRoles	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForNearestShipWithAnyPrimaryRole(scanRoles); }
- (void) scanForNearestShipHavingAnyRole:(const std::string &)scanRoles	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForNearestShipHavingAnyRole(scanRoles); }
- (void) scanForNearestShipWithScanClass:(const std::string &)scanScanClass	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForNearestShipWithScanClass(scanScanClass); }
- (void) scanForNearestShipWithoutPrimaryRole:(const std::string &)scanRole	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForNearestShipWithoutPrimaryRole(scanRole); }
- (void) scanForNearestShipNotHavingRole:(const std::string &)scanRole	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForNearestShipNotHavingRole(scanRole); }
- (void) scanForNearestShipWithoutAnyPrimaryRole:(const std::string &)scanRoles	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForNearestShipWithoutAnyPrimaryRole(scanRoles); }
- (void) scanForNearestShipNotHavingAnyRole:(const std::string &)scanRoles	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForNearestShipNotHavingAnyRole(scanRoles); }
- (void) scanForNearestShipWithoutScanClass:(const std::string &)scanScanClass	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForNearestShipWithoutScanClass(scanScanClass); }
- (void) scanForNearestShipMatchingPredicate:(const std::string &)predicateExpression	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scanForNearestShipMatchingPredicate(predicateExpression); }
- (void) setCoordinates:(const std::string &)system_x_y_z	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setCoordinates(system_x_y_z); }
- (void) checkForNormalSpace	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->checkForNormalSpace(); }
- (void) setTargetToRandomStation	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setTargetToRandomStation(); }
- (void) setTargetToLastStation	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setTargetToLastStation(); }
- (void) addFuel:(const std::string &)fuel_number	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->addFuel(fuel_number); }
- (void) scriptActionOnTarget:(const std::string &)action	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->scriptActionOnTarget(action); }
- (void) safeScriptActionOnTarget:(const std::string &)action	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->safeScriptActionOnTarget(action); }
- (void) sendScriptMessage:(const std::string &)message	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->sendScriptMessage(message); }
- (void) ai_throwSparks	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->ai_throwSparks(); }
- (void) explodeSelf	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->explodeSelf(); }
- (void) ai_debugMessage:(const std::string &)message	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->ai_debugMessage(message); }
- (void) targetFirstBeaconWithCode:(const std::string &)code	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->targetFirstBeaconWithCode(code); }
- (void) targetNextBeaconWithCode:(const std::string &)code	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->targetNextBeaconWithCode(code); }
- (void) setRacepointsFromTarget	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->setRacepointsFromTarget(); }
- (void) performFlyRacepoints	{ if (ShipEntity *ship = ShipPart(_cxxEntity.get()))  ship->performFlyRacepoints(); }

@end


@implementation Entity (OOPlayerSelectorsCalledByName)

- (GLfloat) baseMass	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->baseMass() : GLfloat{}; }
- (void) unloadCargoPods	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->unloadCargoPods(); }
- (void) loadCargoPods	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->loadCargoPods(); }
- (OOCreditsQuantity) deciCredits	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->deciCredits() : OOCreditsQuantity{}; }
- (int) random_factor	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->random_factor() : int{}; }
- (OOGalaxyID) galaxyNumber	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->galaxyNumber() : OOGalaxyID{}; }
- (NSPoint) galaxy_coordinates	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getGalaxy_coordinates() : NSMakePoint(0, 0); }
- (NSPoint) cursor_coordinates	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getCursor_coordinates() : NSMakePoint(0, 0); }
- (NSPoint) chart_centre_coordinates	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getChart_centre_coordinates() : NSMakePoint(0, 0); }
- (OOScalar) chart_zoom	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getChart_zoom() : OOScalar{}; }
- (OOScalar) custom_chart_zoom	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getCustom_chart_zoom() : OOScalar{}; }
- (NSPoint) custom_chart_centre_coordinates	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getCustom_chart_centre_coordinates() : NSMakePoint(0, 0); }
- (NSPoint) adjusted_chart_centre	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->adjusted_chart_centre() : NSMakePoint(0, 0); }
- (OORouteType) ANAMode	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->ANAMode() : OORouteType{}; }
- (OOSystemID) systemID	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->systemID() : OOSystemID{}; }
- (OOSystemID) previousSystemID	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->previousSystemID() : OOSystemID{}; }
- (OOSystemID) targetSystemID	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->targetSystemID() : OOSystemID{}; }
- (OOSystemID) nextHopTargetSystemID	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->nextHopTargetSystemID() : OOSystemID{}; }
- (OOSystemID) infoSystemID	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->infoSystemID() : OOSystemID{}; }
- (void) nextInfoSystem	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->nextInfoSystem(); }
- (void) previousInfoSystem	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->previousInfoSystem(); }
- (void) homeInfoSystem	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->homeInfoSystem(); }
- (void) targetInfoSystem	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->targetInfoSystem(); }
- (BOOL) infoSystemOnRoute	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->infoSystemOnRoute() : NO; }
- (oo::PList) cxx_commanderDataDictionary	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->commanderDataDictionary() : oo::PList(); }
- (BOOL) cxx_setCommanderDataFromDictionary:(const oo::PList &) dict	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->setCommanderDataFromDictionary(dict) : NO; }
- (void) completeSetUp	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->completeSetUp(); }
- (void) startUpComplete	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->startUpComplete(); }
- (GLfloat) insideAtmosphereFraction	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->insideAtmosphereFraction() : GLfloat{}; }
- (void) updateMovementFlags	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->updateMovementFlags(); }
- (void) updateAlertConditionForNearbyEntities	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->updateAlertConditionForNearbyEntities(); }
- (void) updateAlertCondition	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->updateAlertCondition(); }
- (void) checkScriptsIfAppropriate	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->checkScriptsIfAppropriate(); }
- (void) resetAutopilotAI	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->resetAutopilotAI(); }
#if OO_VARIABLE_TORUS_SPEED
- (GLfloat) hyperspeedFactor	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getHyperspeedFactor() : GLfloat{}; }
#endif
- (BOOL) injectorsEngaged	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->injectorsEngaged() : NO; }
- (BOOL) hyperspeedEngaged	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->hyperspeedEngaged() : NO; }
- (void) gameOverFadeToBW	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->gameOverFadeToBW(); }
- (void) showGameOver	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->showGameOver(); }
- (void) updateTargeting	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->updateTargeting(); }
- (HPVector) breakPatternPosition	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->breakPatternPosition() : kZeroHPVector; }
- (Vector) viewpointOffset	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->viewpointOffset() : kZeroVector; }
- (Vector) viewpointOffsetAft	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->viewpointOffsetAft() : kZeroVector; }
- (Vector) viewpointOffsetForward	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->viewpointOffsetForward() : kZeroVector; }
- (Vector) viewpointOffsetPort	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->viewpointOffsetPort() : kZeroVector; }
- (Vector) viewpointOffsetStarboard	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->viewpointOffsetStarboard() : kZeroVector; }
- (HPVector) viewpointPosition	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->viewpointPosition() : kZeroHPVector; }
- (BOOL) massLockable	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getMassLockable() : NO; }
- (BOOL) massLocked	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxEntity.get()))  return proxy->massLocked(); PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->massLocked() : NO; }
- (BOOL) atHyperspeed	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxEntity.get()))  return proxy->atHyperspeed(); PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->atHyperspeed() : NO; }
- (float) occlusionLevel	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->occlusionLevel() : float{}; }
- (void) setDockedAtMainStation	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setDockedAtMainStation(); }
- (Entity *) dockedStation	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? oo::ToObjC(player->dockedStation()) : nil; }	// the station's object (bead oo-9ht.175), as the facade answered it
- (Entity *) getTargetDockStation	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? oo::ToObjC(player->getTargetDockStation()) : nil; }	// the station's object (bead oo-9ht.175), as the facade answered it
- (void) resetHud	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->resetHud(); }
- (BOOL) cxx_switchHudTo:(const std::string &)hudFileName	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->switchHudTo(hudFileName) : NO; }
- (float) cxx_dialCustomFloat:(const std::string &)dialKey	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dialCustomFloat(dialKey) : float{}; }
- (BOOL) showDemoShips	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getShowDemoShips() : NO; }
- (float) forwardShieldRechargeRate	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->forwardShieldRechargeRate() : float{}; }
- (float) aftShieldRechargeRate	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->aftShieldRechargeRate() : float{}; }
- (GLfloat) forwardShieldLevel	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->forwardShieldLevel() : GLfloat{}; }
- (GLfloat) aftShieldLevel	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->aftShieldLevel() : GLfloat{}; }
- (oo::PList) cxx_keyConfig	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->keyConfig() : oo::PList(); }
- (BOOL) isMouseControlOn	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->isMouseControlOn() : NO; }
- (GLfloat) dialRoll	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dialRoll() : GLfloat{}; }
- (GLfloat) dialPitch	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dialPitch() : GLfloat{}; }
- (GLfloat) dialYaw	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dialYaw() : GLfloat{}; }
- (GLfloat) dialSpeed	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dialSpeed() : GLfloat{}; }
- (GLfloat) dialHyperSpeed	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dialHyperSpeed() : GLfloat{}; }
- (GLfloat) dialForwardShield	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxEntity.get()))  return proxy->dialForwardShield(); PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dialForwardShield() : GLfloat{}; }
- (GLfloat) dialAftShield	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxEntity.get()))  return proxy->dialAftShield(); PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dialAftShield() : GLfloat{}; }
- (GLfloat) dialEnergy	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dialEnergy() : GLfloat{}; }
- (GLfloat) dialMaxEnergy	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dialMaxEnergy() : GLfloat{}; }
- (GLfloat) dialFuel	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dialFuel() : GLfloat{}; }
- (GLfloat) dialHyperRange	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dialHyperRange() : GLfloat{}; }
- (GLfloat) dialAltitude	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dialAltitude() : GLfloat{}; }
- (double) clockTime	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->clockTime() : double{}; }
- (double) clockTimeAdjusted	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->clockTimeAdjusted() : double{}; }
- (BOOL) clockAdjusting	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->clockAdjusting() : NO; }
- (double) escapePodRescueTime	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->escapePodRescueTime() : double{}; }
- (unsigned) countMissiles	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->countMissiles() : unsigned{}; }
- (OOMissileStatus) dialMissileStatus	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxEntity.get()))  return proxy->dialMissileStatus(); PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dialMissileStatus() : OOMissileStatus{}; }
- (OOFuelScoopStatus) dialFuelScoopStatus	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxEntity.get()))  return proxy->dialFuelScoopStatus(); PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dialFuelScoopStatus() : OOFuelScoopStatus{}; }
- (float) fuelLeakRate	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxEntity.get()))  return proxy->fuelLeakRate(); PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->fuelLeakRate() : float{}; }
- (void) addRoleForMining	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->addRoleForMining(); }
- (void) cxx_addRoleToPlayer:(const std::string &)role	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->addRoleToPlayer(role); }
- (NSUInteger) maxPlayerRoles	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->maxPlayerRoles() : NSUInteger{}; }
- (void) updateSystemMemory	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->updateSystemMemory(); }
- (Entity *) compassTarget	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getCompassTarget() : nil; }
- (void) validateCompassTarget	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->validateCompassTarget(); }
- (OOCompassMode) compassMode	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxEntity.get()))  return proxy->compassMode(); PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getCompassMode() : OOCompassMode{}; }
- (void) setPrevCompassMode	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setPrevCompassMode(); }
- (void) setNextCompassMode	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setNextCompassMode(); }
- (NSUInteger) activeMissile	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getActiveMissile() : NSUInteger{}; }
- (NSUInteger) dialMaxMissiles	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dialMaxMissiles() : NSUInteger{}; }
- (BOOL) dialIdentEngaged	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxEntity.get()))  return proxy->dialIdentEngaged(); PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dialIdentEngaged() : NO; }
- (void) selectNextMultiFunctionDisplay	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->selectNextMultiFunctionDisplay(); }
- (void) selectPreviousMultiFunctionDisplay	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->selectPreviousMultiFunctionDisplay(); }
- (NSUInteger) activeMFD	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getActiveMFD() : NSUInteger{}; }
- (void) safeAllMissiles	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->safeAllMissiles(); }
- (void) tidyMissilePylons	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->tidyMissilePylons(); }
- (void) selectNextMissile	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->selectNextMissile(); }
- (void) clearAlertFlags	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->clearAlertFlags(); }
- (int) alertFlags	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getAlertFlags() : int{}; }
- (OOPlayerFleeingStatus) fleeingStatus	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->fleeingStatus() : OOPlayerFleeingStatus{}; }
- (BOOL) cxx_mountMissileWithRole:(const std::string &)role	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->mountMissileWithRole(role) : NO; }
- (BOOL) cxx_assignToActivePylon:(const std::string &)equipmentKey	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->assignToActivePylon(equipmentKey) : NO; }
- (double) scannerFuzziness	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->scannerFuzziness() : double{}; }
- (OOEnergyUnitType) installedEnergyUnitType	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->installedEnergyUnitType() : OOEnergyUnitType{}; }
- (OOEnergyUnitType) energyUnitType	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->energyUnitType() : OOEnergyUnitType{}; }
- (void) currentWeaponStats	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->currentWeaponStats(); }
- (BOOL) weaponsOnline	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->weaponsOnline() : NO; }
- (BOOL) fireMainWeapon	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->fireMainWeapon() : NO; }
- (Entity *) createDoppelganger	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? oo::ToObjC(player->createDoppelganger()) : nil; }
- (void) rotateCargo	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->rotateCargo(); }
- (BOOL) takeInternalDamage	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->takeInternalDamage() : NO; }
- (void) loseTargetStatus	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->loseTargetStatus(); }
- (BOOL) cxx_endScenario:(const std::string &)key	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->endScenario(key) : NO; }
- (void) docked	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->docked(); }
- (void) witchStart	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->witchStart(); }
- (void) witchEnd	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->witchEnd(); }
- (double) hyperspaceJumpDistance	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->hyperspaceJumpDistance() : double{}; }
- (OOFuelQuantity) fuelRequiredForJump	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->fuelRequiredForJump() : OOFuelQuantity{}; }
- (BOOL) hasSufficientFuelForJump	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->hasSufficientFuelForJump() : NO; }
- (void) noteCompassLostTarget	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->noteCompassLostTarget(); }
- (void) enterGalacticWitchspace	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->enterGalacticWitchspace(); }
- (void) setGuiToStatusScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToStatusScreen(); }
- (NSUInteger) primedEquipmentCount	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->primedEquipmentCount() : NSUInteger{}; }
- (unsigned) legalStatusOfCargoList	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->legalStatusOfCargoList() : unsigned{}; }
- (void) setGuiToSystemDataScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToSystemDataScreen(); }
- (void) setGuiToLongRangeChartScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToLongRangeChartScreen(); }
- (void) setGuiToShortRangeChartScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToShortRangeChartScreen(); }
- (void) setGuiToGameOptionsScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToGameOptionsScreen(); }
- (void) setGuiToLoadSaveScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToLoadSaveScreen(); }
- (void) highlightEquipShipScreenKey:(const std::string &)highlightKey	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->highlightEquipShipScreenKey(highlightKey); }
- (OOWeaponFacingSet) availableFacings	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->availableFacings() : OOWeaponFacingSet{}; }
- (void) showInformationForSelectedUpgrade	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->showInformationForSelectedUpgrade(); }
- (void) showInformationForSelectedInterface	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->showInformationForSelectedInterface(); }
- (void) activateSelectedInterface	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->activateSelectedInterface(); }
- (void) setupStartScreenGui	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setupStartScreenGui(); }
- (void) setGuiToOXZManager	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToOXZManager(); }
- (void) buySelectedItem	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->buySelectedItem(); }
- (BOOL) tryBuyingItem:(const std::string &)eqKey	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->tryBuyingItem(eqKey) : NO; }
- (OOCargoQuantity) cxx_cargoQuantityForType:(const std::string &)type	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->cargoQuantityForType(type) : OOCargoQuantity{}; }
- (void) calculateCurrentCargo	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->calculateCurrentCargo(); }
- (void) showMarketScreenHeaders	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->showMarketScreenHeaders(); }
- (void) setGuiToMarketScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToMarketScreen(); }
- (void) setGuiToMarketInfoScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToMarketInfoScreen(); }
- (void) showMarketCashAndLoadLine	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->showMarketCashAndLoadLine(); }
- (OOGUIScreenID) guiScreen	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->guiScreen() : OOGUIScreenID{}; }
- (OOSpeechSettings) isSpeechOn	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getIsSpeechOn() : OOSpeechSettings{}; }
- (void) addEquipmentWithScriptToCustomKeyArray:(const std::string &)equipmentKey	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->addEquipmentWithScriptToCustomKeyArray(equipmentKey); }
- (void) validateCustomEquipActivationArray	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->validateCustomEquipActivationArray(); }
- (void) addEquipmentFromCollection:(const oo::PList &)equipment	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->addEquipmentFromCollection(equipment); }
- (void) getFined	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->getFined(); }
- (int) tradeInFactor	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxEntity.get()))  return proxy->tradeInFactor(); PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->tradeInFactor() : int{}; }
- (double) renovationCosts	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->renovationCosts() : double{}; }
- (double) renovationFactor	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->renovationFactor() : double{}; }
- (void) setDefaultViewOffsets	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setDefaultViewOffsets(); }
- (void) setDefaultCustomViews	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setDefaultCustomViews(); }
- (Vector) weaponViewOffset	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->weaponViewOffset() : kZeroVector; }
- (void) setUpTrumbles	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setUpTrumbles(); }
- (NSUInteger) trumbleCount	{ if (ProxyPlayerEntity *proxy = ProxyPart(_cxxEntity.get()))  return proxy->trumbleCount(); PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getTrumbleCount() : NSUInteger{}; }
- (oo::PList)trumbleValue	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->trumbleValue() : oo::PList(); }
- (void) setTrumbleValueFrom:(const oo::PList &) trumbleValue	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setTrumbleValueFrom(trumbleValue); }
- (float) trumbleAppetiteAccumulator	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->trumbleAppetiteAccumulator() : float{}; }
- (void) setScoopsActive	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setScoopsActive(); }
- (void) clearTargetMemory	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->clearTargetMemory(); }
- (Quaternion) customViewQuaternion	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getCustomViewQuaternion() : kZeroQuaternion; }
- (OOMatrix) customViewMatrix	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getCustomViewMatrix() : kZeroMatrix; }
- (Vector) customViewOffset	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getCustomViewOffset() : kZeroVector; }
- (Vector) customViewRotationCenter	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getCustomViewRotationCenter() : kZeroVector; }
- (Vector) customViewForwardVector	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getCustomViewForwardVector() : kZeroVector; }
- (Vector) customViewUpVector	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getCustomViewUpVector() : kZeroVector; }
- (Vector) customViewRightVector	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getCustomViewRightVector() : kZeroVector; }
- (void) resetCustomView	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->resetCustomView(); }
- (void) setCustomViewData	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setCustomViewData(); }
- (BOOL) showInfoFlag	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->showInfoFlag() : NO; }
- (oo::PList) cxx_missionOverlayDescriptor	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->missionOverlayDescriptor() : oo::PList(); }
- (oo::PList) cxx_missionOverlayDescriptorOrDefault	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->missionOverlayDescriptorOrDefault() : oo::PList(); }
- (void) cxx_setMissionOverlayDescriptor:(const oo::PList &)descriptor	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setMissionOverlayDescriptor(descriptor); }
- (oo::PList) cxx_missionBackgroundDescriptor	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->missionBackgroundDescriptor() : oo::PList(); }
- (oo::PList) cxx_missionBackgroundDescriptorOrDefault	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->missionBackgroundDescriptorOrDefault() : oo::PList(); }
- (void) cxx_setMissionBackgroundDescriptor:(const oo::PList &)descriptor	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setMissionBackgroundDescriptor(descriptor); }
- (OOGUIBackgroundSpecial) missionBackgroundSpecial	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->missionBackgroundSpecial() : OOGUIBackgroundSpecial{}; }
- (void) cxx_setMissionBackgroundSpecial:(const std::string &)special	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setMissionBackgroundSpecial(special); }
- (OOGUIScreenID) missionExitScreen	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->missionExitScreen() : OOGUIScreenID{}; }
- (oo::PList) cxx_equipScreenBackgroundDescriptor	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->equipScreenBackgroundDescriptor() : oo::PList(); }
- (void) cxx_setEquipScreenBackgroundDescriptor:(const oo::PList &)descriptor	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setEquipScreenBackgroundDescriptor(descriptor); }
- (BOOL) scriptsLoaded	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->scriptsLoaded() : NO; }
- (OOGalacticHyperspaceBehaviour) galacticHyperspaceBehaviour	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getGalacticHyperspaceBehaviour() : OOGalacticHyperspaceBehaviour{}; }
- (NSPoint) galacticHyperspaceFixedCoords	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getGalacticHyperspaceFixedCoords() : NSMakePoint(0, 0); }
- (OOLongRangeChartMode) longRangeChartMode	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getLongRangeChartMode() : OOLongRangeChartMode{}; }
- (BOOL) scoopOverride	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getScoopOverride() : NO; }
- (BOOL) isDocked	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->isDocked() : NO; }
- (BOOL)clearedToDock	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->clearedToDock() : NO; }
- (OODockingClearanceStatus)getDockingClearanceStatus	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getDockingClearanceStatus() : OODockingClearanceStatus{}; }
- (void)penaltyForUnauthorizedDocking	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->penaltyForUnauthorizedDocking(); }
- (void)updateWormholes	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->updateWormholes(); }
- (void) cxx_addMissionDestinationMarker:(const oo::PList &)marker	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->addMissionDestinationMarker(marker); }
- (BOOL) cxx_removeMissionDestinationMarker:(const oo::PList &)marker	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->removeMissionDestinationMarker(marker) : NO; }
- (oo::PList) cxx_getMissionDestinations	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getMissionDestinations() : oo::PList(); }
- (void) clearExtraMissionKeys	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->clearExtraMissionKeys(); }
- (void) cxx_setExtraMissionKeys:(const oo::PList &)keys	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setExtraMissionKeys(keys); }
- (unsigned) score	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->score() : unsigned{}; }
- (double) creditBalance	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->creditBalance() : double{}; }
- (BOOL) dockedAtMainStation	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dockedAtMainStation() : NO; }
- (void) resetScannerZoom	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->resetScannerZoom(); }
- (OOGalaxyID) currentGalaxyID	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->currentGalaxyID() : OOGalaxyID{}; }
- (OOSystemID) currentSystemID	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->currentSystemID() : OOSystemID{}; }
- (void) allowMissionInterrupt	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->allowMissionInterrupt(); }
- (OOTimeDelta) scriptTimer	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->scriptTimer() : OOTimeDelta{}; }
- (unsigned) systemPseudoRandom100	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->systemPseudoRandom100() : unsigned{}; }
- (unsigned) systemPseudoRandom256	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->systemPseudoRandom256() : unsigned{}; }
- (double) systemPseudoRandomFloat	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->systemPseudoRandomFloat() : double{}; }
- (oo::PList) cxx_validatedMarker:(const oo::PList &)marker	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->validatedMarker(marker) : oo::PList(); }
- (oo::PList) commanderKillsAsString
{
	PlayerEntity *player = PlayerEntityPart(_cxxEntity.get());
	if (player == nullptr)  return oo::PList();
 const auto result = player->commanderKillsAsString(); return result.has_value() ? oo::PList(*result) : oo::PList();
}
- (oo::PList) commanderBountyAsString
{
	PlayerEntity *player = PlayerEntityPart(_cxxEntity.get());
	if (player == nullptr)  return oo::PList();
 const auto result = player->commanderBountyAsString(); return result.has_value() ? oo::PList(*result) : oo::PList();
}
- (oo::PList) creditsFormattedForSubstitution
{
	PlayerEntity *player = PlayerEntityPart(_cxxEntity.get());
	if (player == nullptr)  return oo::PList();
 const auto result = player->creditsFormattedForSubstitution(); return result.has_value() ? oo::PList(*result) : oo::PList();
}
- (oo::PList) creditsFormattedForLegacySubstitution
{
	PlayerEntity *player = PlayerEntityPart(_cxxEntity.get());
	if (player == nullptr)  return oo::PList();
 const auto result = player->creditsFormattedForLegacySubstitution(); return result.has_value() ? oo::PList(*result) : oo::PList();
}
- (void) setUpSound	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setUpSound(); }
- (void) setUpWeaponSounds	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setUpWeaponSounds(); }
- (void) destroySound	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->destroySound(); }
- (BOOL) isBeeping	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->isBeeping() : NO; }
- (void) boop	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->boop(); }
- (void) playIdentOn	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playIdentOn(); }
- (void) playIdentOff	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playIdentOff(); }
- (void) playIdentLockedOn	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playIdentLockedOn(); }
- (void) playMissileArmed	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playMissileArmed(); }
- (void) playMineArmed	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playMineArmed(); }
- (void) playMissileSafe	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playMissileSafe(); }
- (void) playMissileLockedOn	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playMissileLockedOn(); }
- (void) playNextEquipmentSelected	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playNextEquipmentSelected(); }
- (void) playNextMissileSelected	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playNextMissileSelected(); }
- (void) playWeaponsOnline	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playWeaponsOnline(); }
- (void) playWeaponsOffline	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playWeaponsOffline(); }
- (void) playCargoJettisioned	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playCargoJettisioned(); }
- (void) playAutopilotOn	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playAutopilotOn(); }
- (void) playAutopilotOff	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playAutopilotOff(); }
- (void) playAutopilotOutOfRange	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playAutopilotOutOfRange(); }
- (void) playAutopilotCannotDockWithTarget	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playAutopilotCannotDockWithTarget(); }
- (void) playSaveOverwriteYes	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playSaveOverwriteYes(); }
- (void) playSaveOverwriteNo	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playSaveOverwriteNo(); }
- (void) playHoldFull	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playHoldFull(); }
- (void) playJumpMassLocked	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playJumpMassLocked(); }
- (void) playTargetLost	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playTargetLost(); }
- (void) playNoTargetInMemory	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playNoTargetInMemory(); }
- (void) playTargetSwitched	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playTargetSwitched(); }
- (void) playHyperspaceNoTarget	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playHyperspaceNoTarget(); }
- (void) playHyperspaceNoFuel	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playHyperspaceNoFuel(); }
- (void) playHyperspaceBlocked	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playHyperspaceBlocked(); }
- (void) playHyperspaceDistanceTooGreat	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playHyperspaceDistanceTooGreat(); }
- (void) playCloakingDeviceOn	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playCloakingDeviceOn(); }
- (void) playCloakingDeviceOff	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playCloakingDeviceOff(); }
- (void) playMenuNavigationUp	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playMenuNavigationUp(); }
- (void) playMenuNavigationDown	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playMenuNavigationDown(); }
- (void) playMenuNavigationNot	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playMenuNavigationNot(); }
- (void) playMenuPagePrevious	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playMenuPagePrevious(); }
- (void) playMenuPageNext	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playMenuPageNext(); }
- (void) playDismissedReportScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playDismissedReportScreen(); }
- (void) playDismissedMissionScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playDismissedMissionScreen(); }
- (void) playChangedOption	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playChangedOption(); }
- (void) updateAfterburnerSound	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->updateAfterburnerSound(); }
- (void) startAfterburnerSound	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->startAfterburnerSound(); }
- (void) stopAfterburnerSound	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->stopAfterburnerSound(); }
- (void) playCloakingDeviceInsufficientEnergy	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playCloakingDeviceInsufficientEnergy(); }
- (void) playBuyCommodity	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playBuyCommodity(); }
- (void) playBuyShip	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playBuyShip(); }
- (void) playSellCommodity	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playSellCommodity(); }
- (void) playCantBuyCommodity	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playCantBuyCommodity(); }
- (void) playCantSellCommodity	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playCantSellCommodity(); }
- (void) playCantBuyShip	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playCantBuyShip(); }
- (void) playStandardHyperspace	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playStandardHyperspace(); }
- (void) playGalacticHyperspace	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playGalacticHyperspace(); }
- (void) playHyperspaceAborted	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playHyperspaceAborted(); }
- (void) playHitByECMSound	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playHitByECMSound(); }
- (void) playFiredECMSound	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playFiredECMSound(); }
- (void) playLaunchFromStation	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playLaunchFromStation(); }
- (void) playDockWithStation	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playDockWithStation(); }
- (void) playExitWitchspace	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playExitWitchspace(); }
- (void) playHostileWarning	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playHostileWarning(); }
- (void) playAlertConditionRed	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playAlertConditionRed(); }
- (void) playEnergyLow	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playEnergyLow(); }
- (void) playDockingDenied	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playDockingDenied(); }
- (void) playWitchjumpFailure	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playWitchjumpFailure(); }
- (void) playWitchjumpMisjump	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playWitchjumpMisjump(); }
- (void) playWitchjumpBlocked	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playWitchjumpBlocked(); }
- (void) playWitchjumpDistanceTooGreat	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playWitchjumpDistanceTooGreat(); }
- (void) playWitchjumpInsufficientFuel	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playWitchjumpInsufficientFuel(); }
- (void) playFuelLeak	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playFuelLeak(); }
- (void) playEscapePodScooped	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playEscapePodScooped(); }
- (void) playAegisCloseToPlanet	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playAegisCloseToPlanet(); }
- (void) playAegisCloseToStation	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playAegisCloseToStation(); }
- (void) playGameOver	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playGameOver(); }
- (void) playLegacyScriptSound:(const std::string &)key	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playLegacyScriptSound(key); }
- (void) cxx_scheduleAfterburnerSoundUpdate	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  OOScheduleDeferredCall(oo::ToObjC(player), @selector(updateAfterburnerSound), nil, 1.25); }
- (void) resetStickFunctions	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->resetStickFunctions(); }
- (void) updateFunction: (const oo::PList &)hwDict	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->updateFunction(hwDict); }
- (oo::PList)makeStickGuiDictHeader:(const std::string &)header	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->makeStickGuiDictHeader(header) : oo::PList(); }
- (void) initControls	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->initControls(); }
- (void) initKeyConfigSettings	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->initKeyConfigSettings(); }
- (oo::PList) cxx_processKeyCode:(const oo::PList &)key_def	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->processKeyCode(key_def) : oo::PList(); }
- (BOOL) checkNavKeyPress:(const oo::PList &)key_def	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->checkNavKeyPress(key_def) : NO; }
- (BOOL) checkKeyPress:(const oo::PList &)key_def	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->checkKeyPress(key_def) : NO; }
- (int) getFirstKeyCode:(const oo::PList &)key_def	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getFirstKeyCode(key_def) : int{}; }
- (BOOL) handleGUIUpDownArrowKeys	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->handleGUIUpDownArrowKeys() : NO; }
- (void) clearPlanetSearchString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->clearPlanetSearchString(); }
- (void) switchToMainView	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->switchToMainView(); }
-(void) beginWitchspaceCountdown	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->beginWitchspaceCountdown(); }
-(void) cancelWitchspaceCountdown	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->cancelWitchspaceCountdown(); }
- (void) pollApplicationControls	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->pollApplicationControls(); }
- (void) pollMarketScreenControls	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->pollMarketScreenControls(); }
- (void) handleGameOptionsScreenKeys	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->handleGameOptionsScreenKeys(); }
- (void) handleKeyMapperScreenKeys	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->handleKeyMapperScreenKeys(); }
- (void) handleKeyboardLayoutKeys	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->handleKeyboardLayoutKeys(); }
- (void) handleStickMapperScreenKeys	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->handleStickMapperScreenKeys(); }
- (void) pollCustomViewControls	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->pollCustomViewControls(); }
- (void) pollViewControls	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->pollViewControls(); }
- (void) pollGuiScreenControls	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->pollGuiScreenControls(); }
- (void) handleUndockControl	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->handleUndockControl(); }
- (void) pollMissionInterruptControls	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->pollMissionInterruptControls(); }
- (void) handleMissionCallback	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->handleMissionCallback(); }
- (void) setGuiToMissionEndScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToMissionEndScreen(); }
- (void) handleButtonIdent	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->handleButtonIdent(); }
- (void) handleButtonTargetMissile	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->handleButtonTargetMissile(); }
- (void) initCheckingDictionary	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->initCheckingDictionary(); }
- (void) resetKeyFunctions	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->resetKeyFunctions(); }
- (BOOL) entryIsDictCustomEquip:(const oo::PList &)dict	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->entryIsDictCustomEquip(dict) : NO; }
- (BOOL) entryIsCustomEquip:(const std::string &)entry	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->entryIsCustomEquip(entry) : NO; }
- (oo::PList) getCustomEquipArray:(const std::string &)key_def	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getCustomEquipArray(key_def) : oo::PList(); }
- (NSUInteger) getCustomEquipIndex:(const std::string &)key_def	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getCustomEquipIndex(key_def) : NSUInteger{}; }
- (void) setGuiToKeyConfigScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToKeyConfigScreen(); }
- (void) setGuiToKeyConfigEntryScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToKeyConfigEntryScreen(); }
- (void) setGuiToConfirmClearScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToConfirmClearScreen(); }
- (oo::PList)makeKeyGuiDictHeader:(const std::string &)header	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->makeKeyGuiDictHeader(header) : oo::PList(); }
- (BOOL) entryIsEqualToDefault:(const std::string &)key	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->entryIsEqualToDefault(key) : NO; }
- (void) saveKeySetting:(const std::string &)key	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->saveKeySetting(key); }
- (void) unsetKeySetting:(const std::string &)key	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->unsetKeySetting(key); }
- (void) deleteKeySetting:(const std::string &)key	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->deleteKeySetting(key); }
- (void) deleteAllKeySettings	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->deleteAllKeySettings(); }
- (oo::PList) loadKeySettings	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->loadKeySettings() : oo::PList(); }
- (void) reloadPage	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->reloadPage(); }
- (ShipEntity*) scriptTarget	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->scriptTarget() : nil; }
- (void) checkScript	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->checkScript(); }
- (BOOL) cxx_scriptTestConditions:(const oo::PList &)array	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->scriptTestConditions(array) : NO; }
- (BOOL) scriptTestCondition:(const oo::PList &)scriptCondition	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->scriptTestCondition(scriptCondition) : NO; }
- (oo::PList) cxx_missionVariables	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->missionVariables() : oo::PList(); }
- (oo::PList) cxx_missionVariableForKey:(const std::string &)key	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->missionVariableForKey(key) : oo::PList(); }
- (oo::PList) cxx_missionsList	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->missionsList() : oo::PList(); }
- (void) setMissionDescription:(const std::string &)textKey	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setMissionDescription(textKey); }
- (void) clearMissionDescription	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->clearMissionDescription(); }
- (void) clearMissionDescriptionForMission:(const std::string &)key	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->clearMissionDescriptionForMission(key); }
- (oo::PList) mission_string	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->mission_string() : oo::PList(); }
- (oo::PList) status_string	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->status_string() : oo::PList(); }
- (oo::PList) gui_screen_string	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->gui_screen_string() : oo::PList(); }
- (oo::PList) galaxy_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getGalaxy_number() : oo::PList(); }
- (oo::PList) planet_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->planet_number() : oo::PList(); }
- (oo::PList) score_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->score_number() : oo::PList(); }
- (oo::PList) credits_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->credits_number() : oo::PList(); }
- (oo::PList) scriptTimer_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->scriptTimer_number() : oo::PList(); }
- (oo::PList) shipsFound_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->shipsFound_number() : oo::PList(); }
- (oo::PList) commanderLegalStatus_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->commanderLegalStatus_number() : oo::PList(); }
- (void) setLegalStatus:(const std::string &)valueString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setLegalStatus(valueString); }
- (oo::PList) commanderLegalStatus_string	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->commanderLegalStatus_string() : oo::PList(); }
- (oo::PList) d100_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->d100_number() : oo::PList(); }
- (oo::PList) pseudoFixedD100_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->pseudoFixedD100_number() : oo::PList(); }
- (oo::PList) d256_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->d256_number() : oo::PList(); }
- (oo::PList) pseudoFixedD256_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->pseudoFixedD256_number() : oo::PList(); }
- (oo::PList) clock_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->clock_number() : oo::PList(); }
- (oo::PList) clock_secs_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->clock_secs_number() : oo::PList(); }
- (oo::PList) clock_mins_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->clock_mins_number() : oo::PList(); }
- (oo::PList) clock_hours_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->clock_hours_number() : oo::PList(); }
- (oo::PList) clock_days_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->clock_days_number() : oo::PList(); }
- (oo::PList) fuelLevel_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->fuelLevel_number() : oo::PList(); }
- (oo::PList) dockedAtMainStation_bool	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dockedAtMainStation_bool() : oo::PList(); }
- (oo::PList) foundEquipment_bool	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->foundEquipment_bool() : oo::PList(); }
- (oo::PList) sunWillGoNova_bool	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->sunWillGoNova_bool() : oo::PList(); }
- (oo::PList) sunGoneNova_bool	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->sunGoneNova_bool() : oo::PList(); }
- (oo::PList) missionChoice_string	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->missionChoice_string() : oo::PList(); }
- (oo::PList) missionKeyPress_string	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->missionKeyPress_string() : oo::PList(); }
- (oo::PList) dockedTechLevel_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dockedTechLevel_number() : oo::PList(); }
- (oo::PList) dockedStationName_string	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->dockedStationName_string() : oo::PList(); }
- (oo::PList) systemGovernment_string	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->systemGovernment_string() : oo::PList(); }
- (oo::PList) systemGovernment_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->systemGovernment_number() : oo::PList(); }
- (oo::PList) systemEconomy_string	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->systemEconomy_string() : oo::PList(); }
- (oo::PList) systemEconomy_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->systemEconomy_number() : oo::PList(); }
- (oo::PList) systemTechLevel_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->systemTechLevel_number() : oo::PList(); }
- (oo::PList) systemPopulation_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->systemPopulation_number() : oo::PList(); }
- (oo::PList) systemProductivity_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->systemProductivity_number() : oo::PList(); }
- (oo::PList) commanderName_string	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->commanderName_string() : oo::PList(); }
- (oo::PList) commanderRank_string	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->commanderRank_string() : oo::PList(); }
- (oo::PList) commanderShip_string	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->commanderShip_string() : oo::PList(); }
- (oo::PList) commanderShipDisplayName_string	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->commanderShipDisplayName_string() : oo::PList(); }
- (void) consoleMessage3s:(const std::string &)valueString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->consoleMessage3s(valueString); }
- (void) consoleMessage6s:(const std::string &)valueString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->consoleMessage6s(valueString); }
- (void) awardCredits:(const std::string &)valueString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->awardCredits(valueString); }
- (void) awardShipKills:(const std::string &)valueString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->awardShipKills(valueString); }
- (void) awardEquipment:(const std::string &)equipString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->awardEquipment(equipString); }
- (void) removeEquipment:(const std::string &)equipString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->removeEquipment(equipString); }
- (void) setPlanetinfo:(const std::string &)key_valueString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setPlanetinfo(key_valueString); }
- (void) setSpecificPlanetInfo:(const std::string &)key_valueString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setSpecificPlanetInfo(key_valueString); }
- (void) awardCargo:(const std::string &)amount_typeString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->awardCargo(amount_typeString); }
- (void) removeAllCargo	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->removeAllCargo(); }
- (void) useSpecialCargo:(const std::string &)descriptionString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->useSpecialCargo(descriptionString); }
- (void) testForEquipment:(const std::string &)equipString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->testForEquipment(equipString); }
- (void) awardFuel:(const std::string &)valueString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->awardFuel(valueString); }
- (void) messageShipAIs:(const std::string &)roles_message	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->messageShipAIs(roles_message); }
- (void) ejectItem:(const std::string &)itemKey	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->ejectItem(itemKey); }
- (void) addShips:(const std::string &)roles_number	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->addShips(roles_number); }
- (void) addSystemShips:(const std::string &)roles_number_position	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->addSystemShips(roles_number_position); }
- (void) addShipsAt:(const std::string &)roles_number_system_x_y_z	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->addShipsAt(roles_number_system_x_y_z); }
- (void) addShipsAtPrecisely:(const std::string &)roles_number_system_x_y_z	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->addShipsAtPrecisely(roles_number_system_x_y_z); }
- (void) addShipsWithinRadius:(const std::string &)roles_number_system_x_y_z_r	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->addShipsWithinRadius(roles_number_system_x_y_z_r); }
- (void) spawnShip:(const std::string &)ship_key	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->spawnShip(ship_key); }
- (void) set:(const std::string &)missionvariable_value	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->set(missionvariable_value); }
- (void) reset:(const std::string &)missionvariable	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->reset(missionvariable); }
- (void) increment:(const std::string &)missionVariableObject	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->increment(missionVariableObject); }
- (void) decrement:(const std::string &)missionVariableObject	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->decrement(missionVariableObject); }
- (void) add:(const std::string &)missionVariableString_value	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->add(missionVariableString_value); }
- (void) subtract:(const std::string &)missionVariableString_value	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->subtract(missionVariableString_value); }
- (void) checkForShips:(const std::string &)roleString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->checkForShips(roleString); }
- (void) resetScriptTimer	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->resetScriptTimer(); }
- (void) addMissionText:(const std::string &)textKey	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->addMissionText(textKey); }
- (void) addLiteralMissionText:(const std::string &)text	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->addLiteralMissionText(text); }
- (void) setMissionChoices:(const std::string &)choicesKey	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setMissionChoices(choicesKey); }
- (void) cxx_setMissionChoicesDictionary:(const oo::PList &)choicesDict	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setMissionChoicesDictionary(choicesDict); }
- (void) resetMissionChoice	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->resetMissionChoice(); }
- (void) clearMissionScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->clearMissionScreen(); }
- (void) addMissionDestination:(const std::string &)destinations	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->addMissionDestination(destinations); }
- (void) removeMissionDestination:(const std::string &)destinations	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->removeMissionDestination(destinations); }
- (void) showShipModel:(const std::string &)role	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->showShipModel(role); }
- (void) setMissionMusic:(const std::string &)value	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setMissionMusic(value); }
- (void) setMissionImage:(const std::string &)value	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setMissionImage(value); }
- (void) setMissionBackground:(const std::string &)value	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setMissionBackground(value); }
- (void) setFuelLeak:(const std::string &)value	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setFuelLeak(value); }
- (oo::PList) fuelLeakRate_number	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->fuelLeakRate_number() : oo::PList(); }
- (void) setSunNovaIn:(const std::string &)time_value	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setSunNovaIn(time_value); }
- (void) launchFromStation	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->launchFromStation(); }
- (void) blowUpStation	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->blowUpStation(); }
- (void) sendAllShipsAway	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->sendAllShipsAway(); }
- (void) addPlanet:(const std::string &)planetKey	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->addPlanet(planetKey); }
- (void) addMoon:(const std::string &)moonKey	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->addMoon(moonKey); }
- (void) debugOn	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->debugOn(); }
- (void) debugOff	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->debugOff(); }
- (void) debugMessage:(const std::string &)args	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->debugMessage(args); }
- (void) playSound:(const std::string &)soundName	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->playSound(soundName); }
- (void) doMissionCallback	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->doMissionCallback(); }
- (void) clearMissionScreenID	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->clearMissionScreenID(); }
- (void) endMissionScreenAndNoteOpportunity	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->endMissionScreenAndNoteOpportunity(); }
- (void) setGuiToMissionScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToMissionScreen(); }
- (void) refreshMissionScreenTextEntry	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->refreshMissionScreenTextEntry(); }
- (void) cxx_setBackgroundFromDescriptionsKey:(const std::string &)d_key	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setBackgroundFromDescriptionsKey(d_key); }
- (BOOL) cxx_addEqScriptForKey:(const std::string &)eq_key	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->addEqScriptForKey(eq_key) : NO; }
- (void) cxx_removeEqScriptForKey:(const std::string &)eq_key	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->removeEqScriptForKey(eq_key); }
- (NSUInteger) cxx_eqScriptIndexForKey:(const std::string &)eq_key	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->eqScriptIndexForKey(eq_key) : NSUInteger{}; }
- (void) targetNearestHostile	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->targetNearestHostile(); }
- (void) targetNearestIncomingMissile	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->targetNearestIncomingMissile(); }
- (void) setGalacticHyperspaceBehaviourTo:(const std::string &)galacticHyperspaceBehaviourString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGalacticHyperspaceBehaviourTo(galacticHyperspaceBehaviourString); }
- (void) setGalacticHyperspaceFixedCoordsTo:(const std::string &)galacticHyperspaceFixedCoordsString	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGalacticHyperspaceFixedCoordsTo(galacticHyperspaceFixedCoordsString); }
- (OOCargoQuantity) cxx_contractedVolumeForGood:(const std::string &) good	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->contractedVolumeForGood(good) : OOCargoQuantity{}; }
- (void) cxx_addMessageToReport:(const std::string &) report	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->addMessageToReport(report); }
- (oo::PList) reputation	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->getReputation() : oo::PList(); }
- (int) passengerReputation	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->passengerReputation() : int{}; }
- (int) parcelReputation	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->parcelReputation() : int{}; }
- (int) contractReputation	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->contractReputation() : int{}; }
- (void) erodeReputation	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->erodeReputation(); }
- (void) normaliseReputation	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->normaliseReputation(); }
- (BOOL) cxx_removePassenger:(const std::string &)Name	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->removePassenger(Name) : NO; }
- (BOOL) cxx_removeParcel:(const std::string &)Name	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->removeParcel(Name) : NO; }
- (void) setGuiToManifestScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToManifestScreen(); }
- (void) setGuiToDockingReportScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToDockingReportScreen(); }
- (OOCreditsQuantity) cxx_priceForShipKey:(const std::string &)key	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->priceForShipKey(key) : OOCreditsQuantity{}; }
- (void) showShipyardInfoForSelection	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->showShipyardInfoForSelection(); }
- (void) showTradeInInformationFooter	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->showTradeInInformationFooter(); }
- (NSInteger) missingSubEntitiesAdjustment	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->missingSubEntitiesAdjustment() : NSInteger{}; }
- (OOCreditsQuantity) tradeInValue	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->tradeInValue() : OOCreditsQuantity{}; }
- (BOOL) buySelectedShip	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->buySelectedShip() : NO; }
- (BOOL) cxx_replaceShipWithNamedShip:(const std::string &)shipKey	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->replaceShipWithNamedShip(shipKey) : NO; }
- (BOOL)loadPlayer	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->loadPlayer() : NO; }
- (void)savePlayer	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->savePlayer(); }
- (void) autosavePlayer	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->autosavePlayer(); }
- (void) quicksavePlayer	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->quicksavePlayer(); }
- (void) addScenarioModel:(const std::string &)shipKey	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->addScenarioModel(shipKey); }
- (void) showScenarioDetails	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->showScenarioDetails(); }
- (BOOL) startScenario	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->startScenario() : NO; }
#if OO_USE_CUSTOM_LOAD_SAVE
- (void) saveCommanderInputHandler	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->saveCommanderInputHandler(); }
#endif
#if OO_USE_CUSTOM_LOAD_SAVE
- (void) overwriteCommanderInputHandler	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->overwriteCommanderInputHandler(); }
#endif
#if OOLITE_USE_APPKIT_LOAD_SAVE
- (BOOL)loadPlayerWithPanel	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->loadPlayerWithPanel() : NO; }
#endif
#if OOLITE_USE_APPKIT_LOAD_SAVE
- (void) savePlayerWithPanel	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->savePlayerWithPanel(); }
#endif
- (void) writePlayerToPath:(const std::string &)path	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->writePlayerToPath(path); }
- (void)nativeSavePlayer:(const std::string &)cdrName	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->nativeSavePlayer(cdrName); }
#if OO_USE_CUSTOM_LOAD_SAVE
- (void) setGuiToLoadCommanderScreen	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToLoadCommanderScreen(); }
#endif
#if OO_USE_CUSTOM_LOAD_SAVE
- (void) setGuiToSaveCommanderScreen:(const std::string &)cdrName	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToSaveCommanderScreen(cdrName); }
#endif
#if OO_USE_CUSTOM_LOAD_SAVE
- (void) setGuiToOverwriteScreen:(const std::string &)cdrName	{ if (PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()))  player->setGuiToOverwriteScreen(cdrName); }
#endif
#if OO_USE_CUSTOM_LOAD_SAVE
- (BOOL) existingNativeSave: (const std::string &)cdrName	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->existingNativeSave(cdrName) : NO; }
#endif
#if OO_USE_CUSTOM_LOAD_SAVE
- (int) findIndexOfCommander: (const std::string &)cdrName	{ PlayerEntity *player = PlayerEntityPart(_cxxEntity.get()); return player != nullptr ? player->findIndexOfCommander(cdrName) : int{}; }
#endif

@end


/*	The selectors the game finds by name on a station (bead oo-9ht.175, ADR-0056 amendment
	oo-9ht.175): AI actions, legacy-script and callObjC() calls, shader bindings. The station's
	facade, a subclass of the ship's, answered them until then. These are exactly the selectors only
	the station's facade answered whose signature a by-name dispatcher can call (as the player's
	above): each answers the station's C++ member, and nothing (zero) for any other ship;
	-respondsToSelector: (above) answers them for a station's C++ part only. Moved from the ship's
	facade by bead oo-9ht.144.
*/
@implementation Entity (OOStationSelectorsCalledByName)

- (OOTechLevelID) equivalentTechLevel	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->getEquivalentTechLevel() : OOTechLevelID{}; }
- (Vector) virtualPortDimensions	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->virtualPortDimensions() : kZeroVector; }
- (Entity *) playerReservedDock	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? oo::ToObjC(station->playerReservedDock()) : nil; }	// the dock's object (bead oo-9ht.180), as the station's facade answered it
- (HPVector) beaconPosition	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->beaconPosition() : kZeroHPVector; }
- (float) equipmentPriceFactor	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->getEquipmentPriceFactor() : float{}; }
- (OOCargoQuantity) marketCapacity	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->getMarketCapacity() : OOCargoQuantity{}; }
- (oo::PList) cxx_marketDefinition	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->getMarketDefinition() : oo::PList(); }
- (BOOL) marketMonitored	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->getMarketMonitored() : NO; }
- (BOOL) marketBroadcast	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->getMarketBroadcast() : NO; }
- (void) cxx_setLocalMarket:(const oo::PList &)market	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  station->setLocalMarket(market); }
- (oo::PList) cxx_localMarketForScripting	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->localMarketForScripting() : oo::PList(); }
- (unsigned) countOfDockedContractors	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->countOfDockedContractors() : unsigned{}; }
- (unsigned) countOfDockedPolice	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->countOfDockedPolice() : unsigned{}; }
- (unsigned) countOfDockedDefenders	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->countOfDockedDefenders() : unsigned{}; }
- (BOOL) interstellarUndockingAllowed	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->getInterstellarUndockingAllowed() : NO; }
- (BOOL) hasNPCTraffic	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->getHasNPCTraffic() : NO; }
- (BOOL) requiresDockingClearance	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->getRequiresDockingClearance() : NO; }
- (BOOL) allowsFastDocking	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->getAllowsFastDocking() : NO; }
- (BOOL) allowsAutoDocking	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->getAllowsAutoDocking() : NO; }
- (BOOL) allowsSaving	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->getAllowsSaving() : NO; }
- (BOOL) isRotatingStation	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->isRotatingStation() : NO; }
- (BOOL) hasShipyard	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->hasShipyard() : NO; }
- (void) generateShipyard	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  station->generateShipyard(); }
- (BOOL) suppressArrivalReports	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->suppressArrivalReports() : NO; }
- (BOOL) hasBreakPattern	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->getHasBreakPattern() : NO; }
- (void) sanityCheckShipsOnApproach	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  station->sanityCheckShipsOnApproach(); }
- (void) autoDockShipsOnHold	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  station->autoDockShipsOnHold(); }
- (void) autoDockShipsOnApproach	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  station->autoDockShipsOnApproach(); else if (DockEntity *dock = DockPart(_cxxEntity.get()))  dock->autoDockShipsOnApproach(); }
- (BOOL) dockingCorridorIsEmpty	{ if (DockEntity *dock = DockPart(_cxxEntity.get()))  return dock->dockingCorridorIsEmpty(); StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->dockingCorridorIsEmpty() : NO; }
- (void) clearDockingCorridor	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  station->clearDockingCorridor(); else if (DockEntity *dock = DockPart(_cxxEntity.get()))  dock->clearDockingCorridor(); }
- (void) clear	{ if (StationEntity *station = StationPart(_cxxEntity.get()))  station->clear(); else if (DockEntity *dock = DockPart(_cxxEntity.get()))  dock->clear(); }
- (BOOL) hasMultipleDocks	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->hasMultipleDocks() : NO; }
- (BOOL) hasClearDock	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->hasClearDock() : NO; }
- (BOOL) hasEligibleDock	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->hasEligibleDock() : NO; }
- (BOOL) hasLaunchDock	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->hasLaunchDock() : NO; }
- (Entity *) selectDockForDocking	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? oo::ToObjC(station->selectDockForDocking()) : nil; }	// the dock's object (bead oo-9ht.180), as the station's facade answered it
- (unsigned) countOfShipsInLaunchQueueWithPrimaryRole:(const std::string &)role	{ if (DockEntity *dock = DockPart(_cxxEntity.get()))  return static_cast<unsigned>(dock->countOfShipsInLaunchQueueWithPrimaryRole(role)); StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->countOfShipsInLaunchQueueWithPrimaryRole(role) : unsigned{}; }	// the dock's facade answered an NSUInteger, which no by-name caller reads
- (OOStationAlertLevel) alertLevel	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->getAlertLevel() : STATION_ALERT_LEVEL_GREEN; }	// green for any other ship, which does not respond (the enum has no zero)
- (unsigned) currentlyInDockingQueues	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->currentlyInDockingQueues() : unsigned{}; }
- (unsigned) currentlyInLaunchingQueues	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->currentlyInLaunchingQueues() : unsigned{}; }
- (oo::PList) launchIndependentShip:(const std::string &)role	{ StationEntity *station = StationPart(_cxxEntity.get()); return station != nullptr ? station->launchIndependentShip(role) : oo::PList(); }

@end


/*	The selectors the game can find by name on a dock (bead oo-9ht.180, ADR-0056 amendment
	oo-9ht.180), which the dock's facade, a subclass of the ship's, answered until then: exactly the
	selectors only it answered whose signature a by-name dispatcher can call (as the player's and
	the station's above; those the station's facade answered too are in the station's category).
	Each answers the dock's C++ member, and nothing (zero) for any other ship; -respondsToSelector:
	(above) answers them for a dock's C++ part only. Moved from the ship's facade by bead oo-9ht.144.
*/
@implementation Entity (OODockSelectorsCalledByName)

- (BOOL) allowsDocking	{ DockEntity *dock = DockPart(_cxxEntity.get()); return dock != nullptr ? dock->allowsDocking() : NO; }
- (BOOL) disallowedDockingCollides	{ DockEntity *dock = DockPart(_cxxEntity.get()); return dock != nullptr ? dock->disallowedDockingCollides() : NO; }
- (NSUInteger) countOfShipsInDockingQueue	{ DockEntity *dock = DockPart(_cxxEntity.get()); return dock != nullptr ? dock->countOfShipsInDockingQueue() : NSUInteger{}; }
- (BOOL) allowsLaunching	{ DockEntity *dock = DockPart(_cxxEntity.get()); return dock != nullptr ? dock->allowsLaunching() : NO; }
- (NSUInteger) countOfShipsInLaunchQueue	{ DockEntity *dock = DockPart(_cxxEntity.get()); return dock != nullptr ? dock->countOfShipsInLaunchQueue() : NSUInteger{}; }
- (BOOL) isOffCentre	{ DockEntity *dock = DockPart(_cxxEntity.get()); return dock != nullptr ? dock->isOffCentre() : NO; }
- (void) setVirtual	{ if (DockEntity *dock = DockPart(_cxxEntity.get()))  dock->setVirtual(); }
- (void) clearAllIdLocks	{ if (DockEntity *dock = DockPart(_cxxEntity.get()))  dock->clearAllIdLocks(); }
- (NSUInteger) pruneAndCountShipsOnApproach	{ DockEntity *dock = DockPart(_cxxEntity.get()); return dock != nullptr ? dock->pruneAndCountShipsOnApproach() : NSUInteger{}; }
- (void) abortAllLaunches	{ if (DockEntity *dock = DockPart(_cxxEntity.get()))  dock->abortAllLaunches(); }

@end
