/*

Entity+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056, amendment oo-bj8): the Objective-C Entity, a facade over the C++
cxx::Entity (Entity.h), for the code that messages entities, the entity subclasses not converted
yet (ShipEntity, PlanetEntity, the effects, ...), and everything that holds an entity as an
Objective-C object: the universe's lists, weak references, the JavaScript wrappers. Its interface
is the one Entity.h declared before the conversion, copied exactly (same selectors, same types),
so they compile and behave unchanged. Imported as the last line of Entity.h; do not import it
directly.

It is a hierarchy root's facade, as OODrawable+ObjCBridge.h is, with two differences.

1.	The Objective-C object is the entity's identity, and it owns the C++ part in both cases. Its
	superclass, OOWeakRefObject, keeps state (the weak reference), and callers keep and compare
	the object. So oo::ToObjC answers the entity's Objective-C object and never makes one, and
	C++ code that keeps an entity keeps that object (oo::ObjCRef<Entity *>, amendment oo-smy
	item 4).

	Every entity is a C++ one (the Objective-C subclasses' adapter, oo::ObjCEntity, went with the
	tests' last Objective-C stand-ins, bead oo-j12i2): its object is the facade oo::NewEntityFacade
	made when the entity was made, and virtual calls reach the C++ overrides.

2.	The state is the C++ part's. _cxxEntity is @public, and unconverted code that read an ivar
	directly reads the C++ member through it, by the same name: ent->_cxxEntity->position, and
	_cxxEntity->position in an Objective-C subclass's method. When that code converts, deleting
	"_cxxEntity->" gives its body back verbatim.

The protocol the header declared (OOBeaconEntity) is here, unchanged. Never add to this file;
converted code does not message the facade. Deleted by its deletion bead once every caller and
every entity class is C++.

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

#ifndef ENTITY_OBJCBRIDGE_H
#define ENTITY_OBJCBRIDGE_H

#import "OOObjCPList.h"	// the entity's Object node (oo::EntityPListForeign)
#import "OOEntityHold.h"	// the universe's owning references (bead oo-9ht.39.26)


@interface Entity: OOWeakRefObject
{
@public
	oo::Ref<cxx::Entity>	_cxxEntity;		// the entity's state and behaviour; set by the initialiser
}

// The session in which the entity was created.
- (NSUInteger) sessionID;

- (BOOL) isShip;
- (BOOL) isDock;
- (BOOL) isStation;
- (BOOL) isSubEntity;
- (BOOL) isPlayer;
- (BOOL) isPlanet;
- (BOOL) isSun;
- (BOOL) isSunlit;
- (BOOL) isStellarObject;
- (BOOL) isSky;
- (BOOL) isWormhole;
- (BOOL) isEffect;
- (BOOL) isVisualEffect;
- (BOOL) isWaypoint;

- (BOOL) validForAddToUniverse;
- (void) addToLinkedLists;
- (void) removeFromLinkedLists;

- (void) updateLinkedLists;

- (void) wasAddedToUniverse;
- (void) wasRemovedFromUniverse;

- (void) warnAboutHostiles;

- (void) setUniversalID:(OOUniversalID)uid;
- (OOUniversalID) universalID;

- (BOOL) throwingSparks;
- (void) setThrowSparks:(BOOL)value;
- (void) throwSparks;

- (void) setOwner:(Entity *)ent;
- (id) owner;
- (Entity *) parentEntity;		// owner if self is subentity of owner, otherwise nil.
- (Entity *) rootShipEntity;	// like parentEntity, but recursive.

- (void) setPosition:(HPVector)posn;
- (void) setPositionX:(OOHPScalar)x y:(OOHPScalar)y z:(OOHPScalar)z;
- (HPVector) position;
- (Vector) cameraRelativePosition;
- (GLfloat) cameraRangeFront;
- (GLfloat) cameraRangeBack;

- (void) updateCameraRelativePosition;
// gets a low-position relative vector
- (Vector) vectorTo:(Entity *)entity;

- (HPVector) absolutePositionForSubentity;
- (HPVector) absolutePositionForSubentityOffset:(HPVector) offset;

- (double) zeroDistance;
- (double) camZeroDistance;
- (OOComparisonResult) compareZeroDistance:(Entity *)otherEntity;

- (BoundingBox) boundingBox;

- (GLfloat) mass;

- (Quaternion) orientation;
- (void) setOrientation:(Quaternion) quat;
- (Quaternion) normalOrientation;	// Historical wart: orientation.w is reversed for player; -normalOrientation corrects this.
- (void) setNormalOrientation:(Quaternion) quat;
- (void) orientationChanged;

- (void) setVelocity:(Vector)vel;
- (Vector) velocity;
- (double) speed;

- (GLfloat) distanceTravelled;
- (void) setDistanceTravelled:(GLfloat)value;


- (void) setStatus:(OOEntityStatus)stat;
- (OOEntityStatus) status;

- (void) setScanClass:(OOScanClass)sClass;
- (OOScanClass) scanClass;

- (void) setEnergy:(GLfloat)amount;
- (GLfloat) energy;

- (void) setMaxEnergy:(GLfloat)amount;
- (GLfloat) maxEnergy;

- (void) applyRoll:(GLfloat)roll andClimb:(GLfloat)climb;
- (void) applyRoll:(GLfloat)roll climb:(GLfloat) climb andYaw:(GLfloat)yaw;
- (void) moveForward:(double)amount;

- (OOMatrix) rotationMatrix;
- (OOMatrix) drawRotationMatrix;
- (OOMatrix) transformationMatrix;
- (OOMatrix) drawTransformationMatrix;

- (BOOL) canCollide;
- (GLfloat) collisionRadius;
- (GLfloat) frustumRadius;
- (void) setCollisionRadius:(GLfloat)amount;
- (std::vector<oo::EntityHold> *) cxx_collidingEntities;	// the live list (ADR-0043 item 22); nullptr on nil

- (void) update:(OOTimeDelta)delta_t;

- (void) applyVelocity:(OOTimeDelta)delta_t;
- (BOOL) checkCloseCollisionWith:(Entity *)other;

- (void) takeEnergyDamage:(double)amount from:(Entity *)ent becauseOf:(Entity *)other weaponIdentifier:(const std::string &)weaponIdentifier;

- (void) dumpState;		// General "describe situtation verbosely in log" command.
- (void) dumpSelfState;	// Subclasses should override this, not -dumpState, and call throught to super first.

- (NSUInteger) lastDrawCounter;
- (void) setLastDrawCounter: (NSUInteger) drawCounter;

// Subclass repsonsibilities
- (double) findCollisionRadius;
- (void) drawImmediate:(bool)immediate translucent:(bool)translucent;
- (BOOL) isVisible;
- (BOOL) isInSpace;
- (BOOL) isImmuneToBreakPatternHide;

// For shader bindings.
- (GLfloat) universalTime;
- (GLfloat) spawnTime;
- (GLfloat) timeElapsedSinceSpawn;
- (void) setAtmosphereFogging: (OOColor *) fogging;
- (OOColor *) fogUniform;

#ifndef NDEBUG
- (std::optional<std::string>) descriptionForObjDumpBasic;
- (std::optional<std::string>) descriptionForObjDump;	// flipped with its family (bead oo-3rb.278)

- (std::vector<oo::Ref<OOTexture>>) cxx_allTextures;
#endif

@end

class OOHUDBeaconIcon;	// OOPolygonSprite.h (the protocol until bead oo-7ae4p)

// Methods that must be supported by entities with beacons, regardless of type.
// Methods that must be supported by subentities, regardless of type (moved here from the deleted
// OOEntityWithDrawable+ObjCBridge.h, bead oo-9ht.40). Every adopter is C++ and answers them through
// cxx::OOSubEntityInterface; the protocol stays a type qualifier (Entity<OOSubEntity> *) until the
// root's facade goes (oo-9ht.39).
@protocol OOSubEntity

- (void) rescaleBy:(GLfloat)factor;
- (void) rescaleBy:(GLfloat)factor writeToCache:(BOOL)writeToCache;

// Separate drawing path for subentities of ships.
- (void) drawSubEntityImmediate:(bool)immediate translucent:(bool)translucent;

@end


@protocol OOBeaconEntity

- (OOComparisonResult) compareBeaconCodeWith:(Entity <OOBeaconEntity>*) other;
- (std::optional<std::string>) beaconCode;	// flipped with its family (bead oo-3rb.260)
- (void) setBeaconCode:(const std::optional<std::string> &)bcode;	// flipped with its family (bead oo-3rb.260)
- (std::optional<std::string>) beaconLabel;	// flipped with its family (bead oo-3rb.260)
- (void) setBeaconLabel:(const std::optional<std::string> &)blabel;	// flipped with its family (bead oo-3rb.260)
- (BOOL) isBeacon;
- (OOHUDBeaconIcon *) beaconDrawable;
- (Entity <OOBeaconEntity> *) prevBeacon;
- (Entity <OOBeaconEntity> *) nextBeacon;
- (void) setPrevBeacon:(Entity <OOBeaconEntity> *)beaconShip;
- (void) setNextBeacon:(Entity <OOBeaconEntity> *)beaconShip;
- (BOOL) isJammingScanning;

@end


@interface Entity (OOObjCBridge)

/*	The designated initialiser: stores the entity's C++ part (retained) and counts the entity.
	-init passes a new adapter over cxx::Entity (an Objective-C entity); the facade of a converted
	intermediate class passes an adapter over its own C++ class (OOEntityWithDrawable's -init);
	oo::NewEntityFacade passes a C++ entity. Answers self.
*/
- (id) initWithCxxEntity:(cxx::Entity *)entity;

// Not declared by the header before: ShipEntity overrides it, and the adapter sends it.
- (void) subEntityReallyDied:(ShipEntity *)sub;

@end


// Declared by ShipEntity+ObjCBridge.h until bead oo-9ht.144, which deleted it.
@interface Entity (SubEntityRelationship)

/*	For the common case of testing whether foo is a ship, bar is a ship, bar
	is a subentity of foo and this relationship is represented sanely.
*/
- (BOOL) isShipWithSubEntityShip:(Entity *)other;

@end


/*	The informal protocols a shader binding target implements, categories of the Objective-C root
	that the entities implement (Entity's facade, ShipEntity). They are not the material's: they
	stay Objective-C until the entities convert (ADR-0056 amendment of bead oo-3kqi, item 5), moved
	here unchanged from the shader material's facade header when bead oo-9ht.46 deleted it.
*/
@interface OOObject (ShaderBindingHierarchy)

/*	Informal protocol for objects to "forward" their shader bindings up a
	hierarchy (for instance, subentities to parent entities).
*/
- (id<OOWeakReferenceSupport>) superShaderBindingTarget;

@end


@interface OOObject (OOShaderMaterialTargetOptional)

- (uint32_t) randomSeedForShaders;

@end


/*	The category Entity (OOJavaScriptExtensions) (bead oo-9ht.128) is deleted (bead oo-9ht.39.8.9,
	ADR-0056 amendment oo-9ht.39.8.9): the engine asks an entity's object's C++ entity
	(OOJSEntityJSValue(), OOJSEntityJSClassName(), OOJSEntityIsVisibleToScripts(),
	OOJSEntityGetJSClass(): EntityOOJavaScriptExtensions.h), which its selectors forwarded to.
*/


namespace oo {

// The entity's Objective-C object: an Objective-C entity itself, else a C++ entity's facade.
// Borrowed (the Objective-C object owns the C++ part, so it lives while the entity does); nil for
// null, and for an adapter whose object has been deallocated.
::Entity *ToObjC(cxx::Entity *entity);
inline ::Entity *ToObjC(const Ref<cxx::Entity> &entity)  { return ToObjC(entity.get()); }

// The C++ entity behind an Objective-C one, borrowed; null for nil.
inline cxx::Entity *ToCxx(::Entity *entity)  { return entity != nil ? entity->_cxxEntity.get() : nullptr; }

// What -weakRetain of an entity's object made, held by a C++ holder as a weak reference to the
// object's C++ part (bead oo-9ht.39.5.2): it reads null exactly when the object's weak reference
// did, because the facade's -dealloc drops the part's weak references where it dropped weakSelf.
// Empty for nil.
inline WeakRef<cxx::Entity> WeakEntityRef(::Entity *entity)  { return WeakRef<cxx::Entity>(ToCxx(entity)); }

// What -weakRefUnderlyingObject answered for such a reference: the entity's object, unretained and
// not autoreleased (+0, as the proxy answered it; oo::ToObjC() would autorelease it and so keep it
// alive to the end of the pool), nil once the entity has gone.
::Entity *WeakEntityObject(const WeakRef<cxx::Entity> &ref);

/*	An entity carried through plist data as a PList::Object node (bead oo-9ht.39.5.3): the node's
	payload holds the entity's object, retained, as oo::PListObject()'s did (the object owns the
	part, so the node keeps the entity alive as before), and answers its C++ part. It is an
	ObjCPListForeign, so the class name, the description ("%@" of the object), the identity,
	oo::ObjectIn() and the JS value (the object's -oo_jsValueInContext:, which forwards to the part)
	are what they were. With the facade's deletion (oo-9ht.39 step 4) the payload holds
	Ref<cxx::Entity> and is the part's own JS glue (not before: the tests' stand-in parts have none).
*/
class EntityPListForeign final : public ObjCPListForeign
{
public:
	explicit EntityPListForeign(::Entity *object) : ObjCPListForeign(object) {}
	cxx::Entity *entity() const noexcept  { return ToCxx(static_cast<::Entity *>(object())); }
};

// The entity's Object node (what PListObject(ToObjC(entity)) made); null PList for null.
inline PList EntityObjectNode(::Entity *object)
{
	if (object == nil)  return PList();
	return PList(PList::Object(makeRef<EntityPListForeign>(object)));
}
inline PList EntityObjectNode(cxx::Entity *entity)  { return EntityObjectNode(ToObjC(entity)); }
inline PList EntityObjectNode(const Ref<cxx::Entity> &entity)  { return EntityObjectNode(entity.get()); }

// What oo::ShortDescriptionOf(ToObjC(entity)) printed (bead oo-9ht.39.24): the entity's object's
// short description, whose text holds the object's address; "(null)" for null. callObjC()'s
// "does not respond" error prints it; it goes with the facade (oo-9ht.39 step 5k).
std::string EntityShortDescription(cxx::Entity *entity);

// What oo::DescriptionOf(ToObjC(entity)) printed (bead oo-9ht.39.16): the entity's object's
// description, which holds the object's address; "(null)" for null. Goes with the facade (5k).
std::string EntityDescription(cxx::Entity *entity);

// The C++ entity of what WeakEntityObject(ref) answers (bead oo-9ht.39.16): null once the entity's
// object has gone, as the object read +0 was nil.
inline cxx::Entity *LiveEntity(const WeakRef<cxx::Entity> &ref)  { return ToCxx(WeakEntityObject(ref)); }

// The C++ entity of what an entity's owner() answers (its owner's object, +0; bead oo-9ht.39.16):
// null for none, or once the owner's object has gone.
inline cxx::Entity *LiveOwner(cxx::Entity *entity)  { return entity != nullptr ? ToCxx(static_cast<::Entity *>(entity->owner())) : nullptr; }

// The C++ entity of an entity's Object node, borrowed; null for any other node. A plain Object node
// of an entity's object (oo::PListObject(), still made by Objective-C callers and the tests'
// stand-ins) answers the same entity until the facade goes.
inline cxx::Entity *EntityIn(const PList &plist)
{
	const PList::Object *node = plist.getIf<PList::Object>();
	if (node == nullptr)  return nullptr;
	if (const auto *payload = dynamic_cast<const EntityPListForeign *>(node->get()))  return payload->entity();
	id object = ObjectIn(plist);
	return [object isKindOfClass:[::Entity class]] ? ToCxx(static_cast<::Entity *>(object)) : nullptr;
}

// An array of entities' Object nodes, one per non-nil element, in order (what PListFromObjects()
// made of them).
template <class T>
PList EntityNodesFrom(const std::vector<ObjCRef<T>> &objects)
{
	PList::Array result;
	result.reserve(objects.size());
	for (const auto &object : objects)
	{
		if (object)  result.push_back(EntityObjectNode(static_cast<::Entity *>(object.get())));
	}
	return PList(std::move(result));
}

// The same of held entities (bead oo-9ht.39.26).
inline PList EntityNodesFrom(const std::vector<EntityHold> &entities)
{
	PList::Array result;
	result.reserve(entities.size());
	for (const EntityHold &entity : entities)
	{
		if (entity)  result.push_back(EntityObjectNode(entity.get()));
	}
	return PList(std::move(result));
}

// The C++ entities of an array's entity nodes, borrowed, in order; other elements are skipped.
inline std::vector<cxx::Entity *> EntitiesIn(const PList &plist)
{
	std::vector<cxx::Entity *> result;
	if (const PList::Array *array = plist.getIf<PList::Array>())
	{
		for (const PList &element : *array)
		{
			if (cxx::Entity *entity = EntityIn(element))  result.push_back(entity);
		}
	}
	return result;
}

// The Objective-C object of an entity made in C++ (a converted subclass): a new facade that owns
// it and is its identity from then on, autoreleased. Call it once, where the entity is made. Its
// class is the facade of the entity's nearest converted class that has one (OOEntityWithDrawable,
// OOLightParticleEntity, and the leaves with a facade; else Entity).
::Entity *NewEntityFacade(const Ref<cxx::Entity> &entity);

// The class name "%@" and the debug dumps print: the C++ class's name ("cxx::" dropped).
std::string EntityClassName(cxx::Entity *entity);


/*	What the root facade's -isShip, -isSubEntity, -isPlayer, -isPlanet and -status answered for an entity's
	object (bead oo-9ht.39.16): the C++ member each forwarded to; nil's answer for none. (An Objective-C
	entity, a test's stand-in, was messaged until bead oo-j12i2 deleted the adapter.)
*/
inline bool EntityIsShip(cxx::Entity *entity)
{
	return entity != nullptr && entity->getIsShip();
}

inline bool EntityIsSubEntity(cxx::Entity *entity)
{
	return entity != nullptr && entity->getIsSubEntity();
}

inline bool EntityIsPlayer(cxx::Entity *entity)
{
	return entity != nullptr && entity->getIsPlayer();
}

inline bool EntityIsPlanet(cxx::Entity *entity)
{
	return entity != nullptr && entity->isPlanet();
}

inline OOEntityStatus EntityStatus(cxx::Entity *entity)
{
	return entity != nullptr ? entity->status() : OOEntityStatus{};
}

// What the category SubEntityRelationship's -isShipWithSubEntityShip: answered for an entity's object
// (bead oo-w9pi2): the ship's or the visual effect's member, NO for anything else (and for none).
bool EntityIsShipWithSubEntityShip(cxx::Entity *entity, cxx::Entity *other);

// What the facade's -isBeacon answered for an entity's object (bead oo-9ht.39.26): the ship's,
// effect's or waypoint's member, NO for anything else.
bool EntityIsBeacon(cxx::Entity *entity);

/*	The beacon list's links and code, of the C++ entities (bead oo-9ht.39.26): what the protocol's
	-prevBeacon, -nextBeacon, -setPrevBeacon:, -setNextBeacon:, -beaconCode, -setBeaconCode: and
	-compareBeaconCodeWith: answered and did for the entities' objects (the same messages, sent to
	them here: a ship's, effect's or waypoint's member, or an Objective-C entity's own), answered as
	C++ entities; nil's answer, and nothing, for none.
*/
cxx::Entity *PrevBeacon(cxx::Entity *beacon);
cxx::Entity *NextBeacon(cxx::Entity *beacon);
void SetPrevBeacon(cxx::Entity *beacon, cxx::Entity *other);
void SetNextBeacon(cxx::Entity *beacon, cxx::Entity *other);
std::optional<std::string> BeaconCode(cxx::Entity *beacon);
void SetBeaconCode(cxx::Entity *beacon, const std::optional<std::string> &code);
OOComparisonResult CompareBeaconCodes(cxx::Entity *beacon, cxx::Entity *other);
bool BeaconIsJammingScanning(cxx::Entity *beacon);	// -isJammingScanning, the same way (bead oo-9ht.39.18)
OOHUDBeaconIcon *BeaconDrawable(cxx::Entity *beacon);	// -beaconDrawable, the same way (bead oo-w9pi2)
std::optional<std::string> BeaconLabel(cxx::Entity *beacon);	// -beaconLabel, the same way (bead oo-w9pi2)

}	// namespace oo

#endif	// ENTITY_OBJCBRIDGE_H
