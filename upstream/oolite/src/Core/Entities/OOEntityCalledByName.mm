/*

OOEntityCalledByName.mm

An entity's method called by name, on its C++ part (bead oo-9ht.39.7.1, ADR-0056 amendment
oo-9ht.39.7.1; declared in OOCallByName.h). The facade's by-name categories are the generated
table OOEntityCalledByNameTable.h (tools/gen-entity-by-name-table.py): a tabled name is answered
for the C++ part it applies to, exactly as the root facade's -respondsToSelector: and the category method
answered it, and called as OOCallByName called the method (the same signature rules, read from
@encode() of the declared types instead of the method's type encoding). Since bead oo-9ht.39.9 any
other name, and a tabled name that does not apply, are answered without the entity's Objective-C
object, as OOCallByName answered them on it (OOEntityObjectNamesTable.h); an Objective-C entity's
(tests only) still go to its object. callObjC() reads
a typed result through oo::CallEntityByNameTyped (bead oo-9ht.39.7.2). Since bead oo-9ht.39.7.3
the categories are deleted (the table is the source): a tabled name that applies but whose
signature the call cannot use is logged here, and oo::ScheduleEntityCall holds the deferred calls.

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

#import "OOEntityCalledByName.h"
#import "OOCallByName.h"
#import "Entity.h"
#import "OOEntityWithDrawable.h"
#import "OOVisualEffectEntity.h"
#import "ShipEntity.h"
#import "ShipEntityAI.h"
#import "ShipEntityScriptMethods.h"
#import "PlayerEntity.h"
#import "ProxyPlayerEntity.h"
#import "StationEntity.h"
#import "DockEntity.h"
#import "OOPlanetEntity.h"	// the facade rows (bead oo-9ht.39.8.25)
#import "OOWaypointEntity.h"
#import "OOQuiriumCascadeEntity.h"
#import "GameController.h"	// OOScheduleDeferredCall (oo::ScheduleEntityCall, the player's selectors called by name)
#import "AI.h"
#import "Universe.h"
#import "OODescription.h"
#include "oofnd/objc/OOObjCPeer.h"
#include "oofnd/objc/OORuntime.h"
#include "oofnd/Log.hpp"
#include <objc/runtime.h>
#include <cstring>
#include <string_view>
#include <type_traits>
#include <unordered_map>


namespace {

// The parts the category methods' bodies read, as the facade's (Entity+ObjCBridge.mm) are.
ShipEntity *ShipPart(cxx::Entity *entity)				{ return dynamic_cast<ShipEntity *>(entity); }
StationEntity *StationPart(cxx::Entity *entity)			{ return dynamic_cast<StationEntity *>(entity); }
DockEntity *DockPart(cxx::Entity *entity)				{ return dynamic_cast<DockEntity *>(entity); }
PlayerEntity *PlayerEntityPart(cxx::Entity *entity)		{ return dynamic_cast<PlayerEntity *>(entity); }
ProxyPlayerEntity *ProxyPart(cxx::Entity *entity)		{ return dynamic_cast<ProxyPlayerEntity *>(entity); }
OOVisualEffectEntity *EffectPart(cxx::Entity *entity)	{ return dynamic_cast<OOVisualEffectEntity *>(entity); }

}	// namespace


// The generated table's row (OOEntityCalledByName.h declares the flags and the argument kinds).
namespace {

template <auto Function>
oo::PList OOEntityByNameAdaptNone(cxx::Entity *entity, const std::string *, const oo::PList *)
{
	if constexpr (std::is_same_v<decltype(Function(entity)), oo::PList>)  return Function(entity);
	else
	{
		(void)Function(entity);
		return oo::PList();
	}
}


template <auto Function>
oo::PList OOEntityByNameAdaptString(cxx::Entity *entity, const std::string *string, const oo::PList *)
{
	if constexpr (std::is_same_v<decltype(Function(entity, *string)), oo::PList>)  return Function(entity, *string);
	else
	{
		(void)Function(entity, *string);
		return oo::PList();
	}
}


template <auto Function>
oo::PList OOEntityByNameAdaptPList(cxx::Entity *entity, const std::string *, const oo::PList *plist)
{
	if constexpr (std::is_same_v<decltype(Function(entity, *plist)), oo::PList>)  return Function(entity, *plist);
	else
	{
		(void)Function(entity, *plist);
		return oo::PList();
	}
}


template <auto Function>
void OOEntityByNameTyped(cxx::Entity *entity, OOEntityByNameValue &value)
{
	using Result = decltype(Function(entity));
	if constexpr (std::is_void_v<Result>)  Function(entity);
	else if constexpr (std::is_same_v<Result, oo::PList>)  value.plist = Function(entity);
	else if constexpr (std::is_integral_v<Result> && std::is_signed_v<Result> && sizeof(Result) == 1)
	{
		// a signed char (BOOL): its value, sign kept, as OOCallIntegerMethod() converted it
		const long long bits = static_cast<unsigned char>(Function(entity));
		value.integer = (bits > 127) ? bits - 256 : bits;
	}
	else if constexpr (std::is_integral_v<Result> || std::is_enum_v<Result>)  value.integer = static_cast<long long>(Function(entity));
	else if constexpr (std::is_floating_point_v<Result>)  value.real = static_cast<double>(Function(entity));
	else if constexpr (std::is_same_v<Result, Vector>)  value.vector = Function(entity);
	else if constexpr (std::is_same_v<Result, Quaternion>)  value.quaternion = Function(entity);
	else if constexpr (std::is_same_v<Result, OOColor *>)  value.color = Function(entity);	// borrowed (bead oo-9ht.39.8.25)
	else if constexpr (std::is_convertible_v<Result, cxx::Entity *>)  value.entity = Function(entity);	// the C++ entity (bead oo-9ht.39.24)
	else if constexpr (std::is_convertible_v<Result, id>)  value.object = Function(entity);
	else  (void)Function(entity);	// a result callObjC() cannot read (it does not call such a method)
}

}	// namespace


#include "OOEntityCalledByNameTable.h"


/*	The root facade's own selectors that callObjC() lists and the by-name table does not (bead
	oo-9ht.39.8.25, ADR-0056 amendment oo-9ht.39.8.25), so callObjC() asks and calls an entity's C++
	part for every name of its table. Each function is the facade method's body (Entity+ObjCBridge.mm,
	and the cascade's category, deleted by bead oo-9ht.186), verbatim, with the entity for _cxxEntity.get(), after a guard
	for no entity (zero, as a message to nil answered; the calls never pass one); a name whose
	result callObjC() cannot read (a string, a vector of objects, a matrix, a high-precision vector,
	a bounding box: "cannot be called", or no result) has no function. The answers are
	the root facade's -respondsToSelector:'s: every entity but for the planet's shader selectors (a planet's
	part) and the beacon protocol's (a ship's, an effect's or a waypoint's part). The entity results
	(nextBeacon, prevBeacon, parentEntity, rootShipEntity) are the C++ entity since bead oo-9ht.39.24:
	callObjC() makes its Object node, the same as the object's.
*/
namespace {

bool AnswersPlanet(cxx::Entity *entity)	{ return dynamic_cast<OOPlanetEntity *>(entity) != nullptr; }
bool AnswersBeacon(cxx::Entity *entity)	{ return dynamic_cast<OOWaypointEntity *>(entity) != nullptr || ShipPart(entity) != nullptr || EffectPart(entity) != nullptr; }

void Facade_addToLinkedLists(cxx::Entity *entity)
{ if (entity == nullptr)  return; entity->addToLinkedLists(); }
Vector Facade_airColorAsVector(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; OOPlanetEntity *planet = dynamic_cast<OOPlanetEntity *>(entity); return planet != nullptr ? planet->airColorAsVector() : kZeroVector; }
float Facade_airColorMixRatio(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; OOPlanetEntity *planet = dynamic_cast<OOPlanetEntity *>(entity); return planet != nullptr ? planet->airColorMixRatio() : 0.0f; }
float Facade_airDensity(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; OOPlanetEntity *planet = dynamic_cast<OOPlanetEntity *>(entity); return planet != nullptr ? planet->airDensity() : 0.0f; }
OOHUDBeaconIcon * Facade_beaconDrawable(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (ShipEntity *ship = ShipPart(entity))  return ship->beaconDrawable(); if (OOVisualEffectEntity *effect = EffectPart(entity))  return effect->beaconDrawable(); OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(entity); return waypoint != nullptr ? waypoint->beaconDrawable() : nullptr; }
double Facade_camZeroDistance(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->camZeroDistance(); }
GLfloat Facade_cameraRangeBack(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superCameraRangeBack(); return entity->cameraRangeBack(); }
GLfloat Facade_cameraRangeFront(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superCameraRangeFront(); return entity->cameraRangeFront(); }
Vector Facade_cameraRelativePosition(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->getCameraRelativePosition(); }
BOOL Facade_canCollide(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superCanCollide(); return entity->canCollide(); }
GLfloat Facade_collisionRadius(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superCollisionRadius(); return entity->collisionRadius(); }
void Facade_deleteJSSelf(cxx::Entity *entity)
{ if (entity == nullptr)  return; entity->deleteJSSelf(); }
GLfloat Facade_distanceTravelled(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->getDistanceTravelled(); }
void Facade_dumpSelfState(cxx::Entity *entity)
{ if (entity == nullptr)  return; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  link->superDumpSelfState(); else  entity->dumpSelfState(); }
void Facade_dumpState(cxx::Entity *entity)
{ if (entity == nullptr)  return; entity->dumpState(); }
GLfloat Facade_energy(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->getEnergy(); }
double Facade_findCollisionRadius(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superFindCollisionRadius(); return entity->findCollisionRadius(); }
OOColor * Facade_fogUniform(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->fogUniform().get(); }
GLfloat Facade_frustumRadius(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superFrustumRadius(); return entity->frustumRadius(); }
Vector Facade_illuminationColorAsVector(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; OOPlanetEntity *planet = dynamic_cast<OOPlanetEntity *>(entity); return planet != nullptr ? planet->illuminationColorAsVector() : kZeroVector; }
BOOL Facade_isBeacon(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (ShipEntity *ship = ShipPart(entity))  return ship->isBeacon(); if (OOVisualEffectEntity *effect = EffectPart(entity))  return effect->isBeacon(); OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(entity); return waypoint != nullptr ? waypoint->isBeacon() : NO; }
BOOL Facade_isCascadeWeapon(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; OOQuiriumCascadeEntity *cascade = dynamic_cast<OOQuiriumCascadeEntity *>(entity); return cascade != nullptr ? cascade->isCascadeWeapon() : NO; }
BOOL Facade_isDock(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superIsDock(); return entity->isDock(); }
BOOL Facade_isEffect(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superIsEffect(); return entity->isEffect(); }
BOOL Facade_isImmuneToBreakPatternHide(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->getIsImmuneToBreakPatternHide(); }
BOOL Facade_isInSpace(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->isInSpace(); }
BOOL Facade_isJammingScanning(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (ShipEntity *ship = ShipPart(entity))  return ship->isJammingScanning(); if (OOVisualEffectEntity *effect = EffectPart(entity))  return effect->isJammingScanning(); OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(entity); return waypoint != nullptr ? waypoint->isJammingScanning() : NO; }
BOOL Facade_isPlanet(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superIsPlanet(); return entity->isPlanet(); }
BOOL Facade_isPlayer(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->getIsPlayer(); }
BOOL Facade_isShip(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->getIsShip(); }
BOOL Facade_isSky(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superIsSky(); return entity->isSky(); }
BOOL Facade_isStation(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->getIsStation(); }
BOOL Facade_isStellarObject(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->isStellarObject(); }
BOOL Facade_isSubEntity(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->getIsSubEntity(); }
BOOL Facade_isSun(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superIsSun(); return entity->isSun(); }
BOOL Facade_isSunlit(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->getIsSunlit(); }
BOOL Facade_isVisible(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superIsVisible(); return entity->isVisible(); }
BOOL Facade_isVisibleToScripts(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->isVisibleToScripts(); }
BOOL Facade_isVisualEffect(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superGetIsVisualEffect(); return entity->getIsVisualEffect(); }
BOOL Facade_isWaypoint(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superIsWaypoint(); return entity->isWaypoint(); }
BOOL Facade_isWormhole(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->getIsWormhole(); }
NSUInteger Facade_lastDrawCounter(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->getLastDrawCounter(); }
GLfloat Facade_mass(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->getMass(); }
GLfloat Facade_maxEnergy(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->getMaxEnergy(); }
cxx::Entity * Facade_nextBeacon(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (ShipEntity *ship = ShipPart(entity))  return ship->nextBeacon(); if (OOVisualEffectEntity *effect = EffectPart(entity))  return effect->nextBeacon(); OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(entity); return waypoint != nullptr ? waypoint->nextBeacon() : nullptr; }
Quaternion Facade_normalOrientation(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superNormalOrientation(); return entity->normalOrientation(); }
Quaternion Facade_orientation(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->getOrientation(); }
void Facade_orientationChanged(cxx::Entity *entity)
{ if (entity == nullptr)  return; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  link->superOrientationChanged(); else  entity->orientationChanged(); }
id Facade_owner(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->owner(); }
cxx::Entity * Facade_parentEntity(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->parentEntity(); }
cxx::Entity * Facade_prevBeacon(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (ShipEntity *ship = ShipPart(entity))  return ship->prevBeacon(); if (OOVisualEffectEntity *effect = EffectPart(entity))  return effect->prevBeacon(); OOWaypointEntity *waypoint = dynamic_cast<OOWaypointEntity *>(entity); return waypoint != nullptr ? waypoint->prevBeacon() : nullptr; }
Vector Facade_relativePosition(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->relativePosition(); }
void Facade_removeFromLinkedLists(cxx::Entity *entity)
{ if (entity == nullptr)  return; entity->removeFromLinkedLists(); }
cxx::Entity * Facade_rootShipEntity(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->rootShipEntity(); }
OOScanClass Facade_scanClass(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superGetScanClass(); return entity->getScanClass(); }
NSUInteger Facade_sessionID(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superSessionID(); return entity->sessionID(); }
GLfloat Facade_spawnTime(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->getSpawnTime(); }
double Facade_speed(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->speed(); }
OOEntityStatus Facade_status(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->status(); }
id<OOWeakReferenceSupport> Facade_superShaderBindingTarget(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->superShaderBindingTarget(); }
Vector Facade_terminatorThresholdVector(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; OOPlanetEntity *planet = dynamic_cast<OOPlanetEntity *>(entity); return planet != nullptr ? planet->terminatorThresholdVector() : kZeroVector; }
void Facade_throwSparks(cxx::Entity *entity)
{ if (entity == nullptr)  return; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  link->superThrowSparks(); else  entity->throwSparks(); }
BOOL Facade_throwingSparks(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->throwingSparks(); }
GLfloat Facade_timeElapsedSinceSpawn(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->timeElapsedSinceSpawn(); }
OOUniversalID Facade_universalID(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->getUniversalID(); }
GLfloat Facade_universalTime(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->universalTime(); }
void Facade_updateCameraRelativePosition(cxx::Entity *entity)
{ if (entity == nullptr)  return; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  link->superUpdateCameraRelativePosition(); else  entity->updateCameraRelativePosition(); }
void Facade_updateLinkedLists(cxx::Entity *entity)
{ if (entity == nullptr)  return; entity->updateLinkedLists(); }
BOOL Facade_validForAddToUniverse(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superValidForAddToUniverse(); return entity->validForAddToUniverse(); }
Vector Facade_velocity(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return link->superGetVelocity(); return entity->getVelocity(); }
void Facade_warnAboutHostiles(cxx::Entity *entity)
{ if (entity == nullptr)  return; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  link->superWarnAboutHostiles(); else  entity->warnAboutHostiles(); }
void Facade_wasAddedToUniverse(cxx::Entity *entity)
{ if (entity == nullptr)  return; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  link->superWasAddedToUniverse(); else  entity->wasAddedToUniverse(); }
void Facade_wasRemovedFromUniverse(cxx::Entity *entity)
{ if (entity == nullptr)  return; if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  link->superWasRemovedFromUniverse(); else  entity->wasRemovedFromUniverse(); }
double Facade_zeroDistance(cxx::Entity *entity)
{ if (entity == nullptr)  return {}; return entity->zeroDistance(); }


const OOEntityFacadeRow kOOEntityFacadeRows[] =
{
	{ "absolutePositionForSubentity",	nullptr,	nullptr },
	{ "addToLinkedLists",	nullptr,	&OOEntityByNameTyped<&Facade_addToLinkedLists> },
	{ "airColorAsVector",	&AnswersPlanet,	&OOEntityByNameTyped<&Facade_airColorAsVector> },
	{ "airColorMixRatio",	&AnswersPlanet,	&OOEntityByNameTyped<&Facade_airColorMixRatio> },
	{ "airDensity",	&AnswersPlanet,	&OOEntityByNameTyped<&Facade_airDensity> },
	{ "beaconCode",	&AnswersBeacon,	nullptr },
	{ "beaconDrawable",	&AnswersBeacon,	&OOEntityByNameTyped<&Facade_beaconDrawable> },
	{ "beaconLabel",	&AnswersBeacon,	nullptr },
	{ "boundingBox",	nullptr,	nullptr },
	{ "camZeroDistance",	nullptr,	&OOEntityByNameTyped<&Facade_camZeroDistance> },
	{ "cameraRangeBack",	nullptr,	&OOEntityByNameTyped<&Facade_cameraRangeBack> },
	{ "cameraRangeFront",	nullptr,	&OOEntityByNameTyped<&Facade_cameraRangeFront> },
	{ "cameraRelativePosition",	nullptr,	&OOEntityByNameTyped<&Facade_cameraRelativePosition> },
	{ "canCollide",	nullptr,	&OOEntityByNameTyped<&Facade_canCollide> },
	{ "collisionRadius",	nullptr,	&OOEntityByNameTyped<&Facade_collisionRadius> },
#ifndef NDEBUG
	{ "cxx_allTextures",	nullptr,	nullptr },
#endif
	{ "cxx_collidingEntities",	nullptr,	nullptr },
	{ "cxx_description",	nullptr,	nullptr },
	{ "cxx_descriptionComponents",	nullptr,	nullptr },
	{ "cxx_oo_jsClassName",	nullptr,	nullptr },
	{ "deleteJSSelf",	nullptr,	&OOEntityByNameTyped<&Facade_deleteJSSelf> },
#ifndef NDEBUG
	{ "descriptionForObjDump",	nullptr,	nullptr },
#endif
#ifndef NDEBUG
	{ "descriptionForObjDumpBasic",	nullptr,	nullptr },
#endif
	{ "distanceTravelled",	nullptr,	&OOEntityByNameTyped<&Facade_distanceTravelled> },
	{ "drawRotationMatrix",	nullptr,	nullptr },
	{ "drawTransformationMatrix",	nullptr,	nullptr },
	{ "dumpSelfState",	nullptr,	&OOEntityByNameTyped<&Facade_dumpSelfState> },
	{ "dumpState",	nullptr,	&OOEntityByNameTyped<&Facade_dumpState> },
	{ "energy",	nullptr,	&OOEntityByNameTyped<&Facade_energy> },
	{ "findCollisionRadius",	nullptr,	&OOEntityByNameTyped<&Facade_findCollisionRadius> },
	{ "fogUniform",	nullptr,	&OOEntityByNameTyped<&Facade_fogUniform> },
	{ "frustumRadius",	nullptr,	&OOEntityByNameTyped<&Facade_frustumRadius> },
	{ "illuminationColorAsVector",	&AnswersPlanet,	&OOEntityByNameTyped<&Facade_illuminationColorAsVector> },
	{ "isBeacon",	&AnswersBeacon,	&OOEntityByNameTyped<&Facade_isBeacon> },
	{ "isCascadeWeapon",	nullptr,	&OOEntityByNameTyped<&Facade_isCascadeWeapon> },
	{ "isDock",	nullptr,	&OOEntityByNameTyped<&Facade_isDock> },
	{ "isEffect",	nullptr,	&OOEntityByNameTyped<&Facade_isEffect> },
	{ "isImmuneToBreakPatternHide",	nullptr,	&OOEntityByNameTyped<&Facade_isImmuneToBreakPatternHide> },
	{ "isInSpace",	nullptr,	&OOEntityByNameTyped<&Facade_isInSpace> },
	{ "isJammingScanning",	&AnswersBeacon,	&OOEntityByNameTyped<&Facade_isJammingScanning> },
	{ "isPlanet",	nullptr,	&OOEntityByNameTyped<&Facade_isPlanet> },
	{ "isPlayer",	nullptr,	&OOEntityByNameTyped<&Facade_isPlayer> },
	{ "isShip",	nullptr,	&OOEntityByNameTyped<&Facade_isShip> },
	{ "isSky",	nullptr,	&OOEntityByNameTyped<&Facade_isSky> },
	{ "isStation",	nullptr,	&OOEntityByNameTyped<&Facade_isStation> },
	{ "isStellarObject",	nullptr,	&OOEntityByNameTyped<&Facade_isStellarObject> },
	{ "isSubEntity",	nullptr,	&OOEntityByNameTyped<&Facade_isSubEntity> },
	{ "isSun",	nullptr,	&OOEntityByNameTyped<&Facade_isSun> },
	{ "isSunlit",	nullptr,	&OOEntityByNameTyped<&Facade_isSunlit> },
	{ "isVisible",	nullptr,	&OOEntityByNameTyped<&Facade_isVisible> },
	{ "isVisibleToScripts",	nullptr,	&OOEntityByNameTyped<&Facade_isVisibleToScripts> },
	{ "isVisualEffect",	nullptr,	&OOEntityByNameTyped<&Facade_isVisualEffect> },
	{ "isWaypoint",	nullptr,	&OOEntityByNameTyped<&Facade_isWaypoint> },
	{ "isWormhole",	nullptr,	&OOEntityByNameTyped<&Facade_isWormhole> },
	{ "lastDrawCounter",	nullptr,	&OOEntityByNameTyped<&Facade_lastDrawCounter> },
	{ "mass",	nullptr,	&OOEntityByNameTyped<&Facade_mass> },
	{ "maxEnergy",	nullptr,	&OOEntityByNameTyped<&Facade_maxEnergy> },
	{ "nextBeacon",	&AnswersBeacon,	&OOEntityByNameTyped<&Facade_nextBeacon> },
	{ "normalOrientation",	nullptr,	&OOEntityByNameTyped<&Facade_normalOrientation> },
	{ "orientation",	nullptr,	&OOEntityByNameTyped<&Facade_orientation> },
	{ "orientationChanged",	nullptr,	&OOEntityByNameTyped<&Facade_orientationChanged> },
	{ "owner",	nullptr,	&OOEntityByNameTyped<&Facade_owner> },
	{ "parentEntity",	nullptr,	&OOEntityByNameTyped<&Facade_parentEntity> },
	{ "position",	nullptr,	nullptr },
	{ "prevBeacon",	&AnswersBeacon,	&OOEntityByNameTyped<&Facade_prevBeacon> },
	{ "relativePosition",	nullptr,	&OOEntityByNameTyped<&Facade_relativePosition> },
	{ "removeFromLinkedLists",	nullptr,	&OOEntityByNameTyped<&Facade_removeFromLinkedLists> },
	{ "rootShipEntity",	nullptr,	&OOEntityByNameTyped<&Facade_rootShipEntity> },
	{ "rotationMatrix",	nullptr,	nullptr },
	{ "scanClass",	nullptr,	&OOEntityByNameTyped<&Facade_scanClass> },
	{ "sessionID",	nullptr,	&OOEntityByNameTyped<&Facade_sessionID> },
	{ "spawnTime",	nullptr,	&OOEntityByNameTyped<&Facade_spawnTime> },
	{ "speed",	nullptr,	&OOEntityByNameTyped<&Facade_speed> },
	{ "status",	nullptr,	&OOEntityByNameTyped<&Facade_status> },
	{ "superShaderBindingTarget",	nullptr,	&OOEntityByNameTyped<&Facade_superShaderBindingTarget> },
	{ "terminatorThresholdVector",	&AnswersPlanet,	&OOEntityByNameTyped<&Facade_terminatorThresholdVector> },
	{ "throwSparks",	nullptr,	&OOEntityByNameTyped<&Facade_throwSparks> },
	{ "throwingSparks",	nullptr,	&OOEntityByNameTyped<&Facade_throwingSparks> },
	{ "timeElapsedSinceSpawn",	nullptr,	&OOEntityByNameTyped<&Facade_timeElapsedSinceSpawn> },
	{ "transformationMatrix",	nullptr,	nullptr },
	{ "universalID",	nullptr,	&OOEntityByNameTyped<&Facade_universalID> },
	{ "universalTime",	nullptr,	&OOEntityByNameTyped<&Facade_universalTime> },
	{ "updateCameraRelativePosition",	nullptr,	&OOEntityByNameTyped<&Facade_updateCameraRelativePosition> },
	{ "updateLinkedLists",	nullptr,	&OOEntityByNameTyped<&Facade_updateLinkedLists> },
	{ "validForAddToUniverse",	nullptr,	&OOEntityByNameTyped<&Facade_validForAddToUniverse> },
	{ "velocity",	nullptr,	&OOEntityByNameTyped<&Facade_velocity> },
	{ "warnAboutHostiles",	nullptr,	&OOEntityByNameTyped<&Facade_warnAboutHostiles> },
	{ "wasAddedToUniverse",	nullptr,	&OOEntityByNameTyped<&Facade_wasAddedToUniverse> },
	{ "wasRemovedFromUniverse",	nullptr,	&OOEntityByNameTyped<&Facade_wasRemovedFromUniverse> },
	{ "zeroDistance",	nullptr,	&OOEntityByNameTyped<&Facade_zeroDistance> },
};


#include "OOEntityObjectNamesTable.h"

}	// namespace


std::span<const OOEntityObjectName> oo::EntityObjectNames()
{
	return kOOEntityObjectNames;
}


const OOEntityObjectName *oo::EntityObjectNameNamed(const std::string &name)
{
	static const std::unordered_map<std::string_view, const OOEntityObjectName *> names = [] {
		std::unordered_map<std::string_view, const OOEntityObjectName *> result;
		for (const OOEntityObjectName &row : kOOEntityObjectNames)  result.emplace(row.name, &row);
		return result;
	}();
	auto found = names.find(name);
	return found != names.end() ? found->second : nullptr;
}


std::span<const OOEntityFacadeRow> oo::EntityFacadeRows()
{
	return kOOEntityFacadeRows;
}


const OOEntityFacadeRow *oo::EntityFacadeRowNamed(const std::string &name)
{
	static const std::unordered_map<std::string_view, const OOEntityFacadeRow *> rows = [] {
		std::unordered_map<std::string_view, const OOEntityFacadeRow *> result;
		for (const OOEntityFacadeRow &row : kOOEntityFacadeRows)  result.emplace(row.name, &row);
		return result;
	}();
	auto found = rows.find(name);
	return found != rows.end() ? found->second : nullptr;
}


std::span<const OOEntityByNameRow> oo::EntityByNameRows()
{
	return kOOEntityByNameRows;
}


const OOEntityByNameRow *oo::EntityByNameRowNamed(const std::string &name)
{
	static const std::unordered_map<std::string_view, const OOEntityByNameRow *> rows = [] {
		std::unordered_map<std::string_view, const OOEntityByNameRow *> result;
		for (const OOEntityByNameRow &row : kOOEntityByNameRows)  result.emplace(row.name, &row);
		return result;
	}();
	auto found = rows.find(name);
	return found != rows.end() ? found->second : nullptr;
}


// As the root facade's -respondsToSelector: answered the name sets (the visual effect's first). A name only
// the effect's set holds is answered by the root (super) for any entity, as the facade did; its
// body answers zero for any part but an effect's.
bool oo::EntityByNameRowApplies(const OOEntityByNameRow &row, cxx::Entity *entity)
{
	if (entity == nullptr)  return false;
	const unsigned flags = row.flags;
	if ((flags & kOOByNameEffect) != 0 && EffectPart(entity) != nullptr)  return true;
	if ((flags & (kOOByNameShip | kOOByNamePlayer | kOOByNameStation | kOOByNameDock)) == 0)  return true;
	if ((flags & kOOByNameShip) != 0 && ShipPart(entity) != nullptr)  return true;
	if ((flags & kOOByNamePlayer) != 0 && (flags & kOOByNameProxy) != 0 && ProxyPart(entity) != nullptr)  return true;
	if ((flags & kOOByNamePlayer) != 0 && PlayerEntityPart(entity) != nullptr)  return true;
	return ((flags & kOOByNameStation) != 0 && StationPart(entity) != nullptr) || ((flags & kOOByNameDock) != 0 && DockPart(entity) != nullptr);
}


bool oo::CallEntityByNameTyped(cxx::Entity *entity, const std::string &name, OOEntityByNameValue &value)
{
	if (entity == nullptr)  return false;
	if (const OOEntityByNameRow *row = EntityByNameRowNamed(name))
	{
		if (row->typed == nullptr || !EntityByNameRowApplies(*row, entity))  return false;
		row->typed(entity, value);
		return true;
	}
	// A facade row (bead oo-9ht.39.8.25): the facade method's body, for an entity that answers it.
	const OOEntityFacadeRow *facade = EntityFacadeRowNamed(name);
	if (facade == nullptr || facade->typed == nullptr || (facade->answers != nullptr && !facade->answers(entity)))  return false;
	facade->typed(entity, value);
	return true;
}


namespace {

enum class Kind: std::uint8_t
{
	Void,		// a void result, or a scalar result the call ignores
	PList,		// an oo::PList result
	Object,		// an object result, ignored (ADR-0055 Amendment 2)
	Unsupported
};


// As OOCallByName classifies a method's return type encoding (OOCallByName.mm, ResultKind()).
Kind ResultKind(const char *encoding)
{
	std::string_view type = encoding;
	while (!type.empty() && std::strchr("rnNoORV", type.front()) != nullptr)  type.remove_prefix(1);
	if (type == "v")  return Kind::Void;
	if (type == "@")  return Kind::Object;
	if (std::strcmp(encoding, @encode(oo::PList)) == 0)  return Kind::PList;
	if (type.size() == 1 && std::strchr("cCsSiIlLqQfdB", type.front()) != nullptr)  return Kind::Void;
	return Kind::Unsupported;
}


// The tabled row the name names, if it applies to the entity; null for any other name.
const OOEntityByNameRow *ApplyingRow(cxx::Entity *entity, const std::string &name)
{
	const OOEntityByNameRow *row = oo::EntityByNameRowNamed(name);
	return (row != nullptr && oo::EntityByNameRowApplies(*row, entity)) ? row : nullptr;
}


// The row's call with the argument, if OOCallByName would make it (its usable signatures); none
// if the signature is unusable.
std::optional<oo::PList> CallRow(const OOEntityByNameRow &row, cxx::Entity *entity, const std::string *string, const oo::PList *plist)
{
	const Kind result = ResultKind(row.result);
	const bool hasArgument = (string != nullptr || plist != nullptr);
	if (hasArgument != (row.argument != OOEntityByNameArgument::None) || result == Kind::Unsupported)  return std::nullopt;

	// A string reaches a PList parameter as a string PList; a PList reaches a string parameter
	// only when it is a string.
	oo::PList stringAsPList;
	if (row.argument == OOEntityByNameArgument::String && plist != nullptr)
	{
		string = plist->getIf<std::string>();
		if (string == nullptr)  return std::nullopt;
	}
	if (row.argument == OOEntityByNameArgument::PList)
	{
		if (result != Kind::Void && result != Kind::Object)  return std::nullopt;
		if (string != nullptr)
		{
			stringAsPList = oo::PList(*string);
			plist = &stringAsPList;
		}
	}

	oo::PList answer = row.call(entity, string, plist);
	// only a PList result is the call's result; a void, scalar or object result is ignored
	return (result == Kind::PList) ? std::move(answer) : oo::PList();
}


/*	The class OOCallByName's lines named: the entity's object's. A C++ entity's object is the root's
	facade, of class Entity (not asked since bead oo-9ht.39.9, ADR-0056 amendment oo-9ht.39.9); an
	Objective-C entity's (tests only) is of its own class.
*/
const char *ObjectClassName(cxx::Entity *entity)
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return class_getName(object_getClass(link->objcOwner()));
	return "Entity";
}


/*	The line OOCallByName logged for a method whose signature the call cannot use (OOCallByName.mm
	LogBadSignature), for a tabled name that applies: the class of the entity's object, as the
	category method was its; the type encoding is the row's, @encode() of the result, of self and
	_cmd and of the argument, without the frame offsets the method's encoding had (bead
	oo-9ht.39.7.3, ADR-0056 amendment oo-9ht.39.7.3: a log-text-only change).
*/
void LogBadSignature(cxx::Entity *entity, const OOEntityByNameRow &row)
{
	std::string encoding = std::string(row.result) + @encode(id) + @encode(SEL);
	if (row.argument == OOEntityByNameArgument::String)  encoding += @encode(const std::string &);
	if (row.argument == OOEntityByNameArgument::PList)  encoding += @encode(const oo::PList &);
	OO_LOG_ERR("callByName.badSignature", "-[{} {}] has no signature a by-name call can use (type encoding {}).", ObjectClassName(entity), row.name, encoding);
}


// A tabled name that applies, called or logged; none for any other name (the object's path).
std::optional<oo::PList> CallTabled(cxx::Entity *entity, const std::string &name, const std::string *string, const oo::PList *plist)
{
	const OOEntityByNameRow *row = ApplyingRow(entity, name);
	if (row == nullptr)  return std::nullopt;
	if (std::optional<oo::PList> result = CallRow(*row, entity, string, plist))  return result;
	LogBadSignature(entity, *row);
	return oo::PList();
}


SEL SelectorNamed(const std::string &name)
{
	return OOSelectorFromName(name.c_str());
}


// The name, if the entity's object answered it for this entity; else null.
const OOEntityObjectName *AnsweredObjectName(cxx::Entity *entity, const std::string &name)
{
	const OOEntityObjectName *row = oo::EntityObjectNameNamed(name);
	return (row != nullptr && (row->answers == nullptr || row->answers(entity))) ? row : nullptr;
}


/*	A C++ entity's name outside the by-name table, as OOCallByName answered it on the entity's
	object (bead oo-9ht.39.9, ADR-0056 amendment oo-9ht.39.9), without the object: a facade row's
	method with no argument that the call called is the row's body (its result ignored, as the call
	ignored it); any other name the object answered is logged as the call logged it (the method's
	type encoding), a root-class or lifetime method included, which is no longer called; any other
	name does not respond. The texts are OOCallByName's (OOCallByName.mm LogUnknown, LogBadSignature).
*/
oo::PList CallObjectName(cxx::Entity *entity, const std::string &name, bool hasArgument)
{
	const OOEntityObjectName *row = AnsweredObjectName(entity, name);
	if (row == nullptr)
	{
		OO_LOG_ERR("callByName.unknownSelector", "{} does not respond to {}.", ObjectClassName(entity), name);
		return oo::PList();
	}
	if (row->kind == kOOEntityObjectCalled && !hasArgument)
	{
		const OOEntityFacadeRow *facade = oo::EntityFacadeRowNamed(name);
		if (facade != nullptr && facade->typed != nullptr)
		{
			OOEntityByNameValue ignored;
			facade->typed(entity, ignored);
			return oo::PList();
		}
	}
	OO_LOG_ERR("callByName.badSignature", "-[{} {}] has no signature a by-name call can use (type encoding {}).", ObjectClassName(entity), name, row->encoding);
	return oo::PList();
}

}	// namespace


bool oo::EntityRespondsToName(cxx::Entity *entity, const std::string &name)
{
	if (entity == nullptr)  return false;
	if (const OOEntityByNameRow *row = EntityByNameRowNamed(name))  return EntityByNameRowApplies(*row, entity);
	// An Objective-C entity's class may answer more: it is asked, as before.
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))
	{
		return [link->objcOwner() respondsToSelector:SelectorNamed(name)];	// NO for none, as a message to nil answers
	}
	// A facade row (bead oo-9ht.39.8.25): the root facade's -respondsToSelector:'s answer for the facade's method.
	if (const OOEntityFacadeRow *facade = EntityFacadeRowNamed(name))  return facade->answers == nullptr || facade->answers(entity);
	// Any other name the entity's object answered (bead oo-9ht.39.9): the object is not asked.
	return AnsweredObjectName(entity, name) != nullptr;
}


oo::PList oo::CallEntityByName(cxx::Entity *entity, const std::string &name)
{
	if (entity == nullptr)  return PList();
	if (std::optional<PList> result = CallTabled(entity, name, nullptr, nullptr))  return *result;
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return OOCallByName(link->objcOwner(), SelectorNamed(name));
	return CallObjectName(entity, name, false);
}


oo::PList oo::CallEntityByName(cxx::Entity *entity, const std::string &name, const std::string &argument)
{
	if (entity == nullptr)  return PList();
	if (std::optional<PList> result = CallTabled(entity, name, &argument, nullptr))  return *result;
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return OOCallByName(link->objcOwner(), SelectorNamed(name), argument);
	return CallObjectName(entity, name, true);
}


oo::PList oo::CallEntityByName(cxx::Entity *entity, const std::string &name, const PList &argument)
{
	if (entity == nullptr)  return PList();
	if (std::optional<PList> result = CallTabled(entity, name, nullptr, &argument))  return *result;
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return OOCallByName(link->objcOwner(), SelectorNamed(name), argument);
	return CallObjectName(entity, name, true);
}


void oo::ScheduleEntityCall(cxx::Entity *entity, void (*call)(cxx::Entity *entity), double delay)
{
	if (entity == nullptr || call == nullptr)  return;
	// The call holds the entity, so it keeps the entity alive until it has run, as the Objective-C
	// holder OOEntityDeferredCall did (bead oo-9ht.39.7.3; a C++ call since bead oo-pvhrh).
	oo::Ref<cxx::Entity> held(entity);
	OOScheduleDeferredCall([held, call]() { call(held.get()); }, delay);
}
