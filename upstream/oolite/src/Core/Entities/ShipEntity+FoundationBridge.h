/*

ShipEntity+FoundationBridge.h

TRANSITIONAL (proposed ADR-0043, "Transitional bridges"; chunk beads oo-3rb.232-.242 of oo-3rb.73).
ShipEntity's Foundation-typed API as it was before its sweep, with the same selector names and
types, forwarding to the cxx_ API in ShipEntity.h. It exists so that ShipEntity's callers compile
unchanged; each caller moves to the cxx_ API in its own sweep bead. When `git grep` finds no caller
of anything declared here, the bridge bead deletes this file, ShipEntity+FoundationBridge.mm, its
line in Entities/meson.build and the #import at the end of ShipEntity.h. Never add to it outside the
ShipEntity.mm chunk beads; never call it from migrated code. oo-qps (the removal of gnustep-base)
cannot compile while it exists.

Registry: src/oofnd/README.md, "Transitional bridges".

Copyright (C) 2004-2013 Giles C Williams and contributors (ShipEntity.h)

*/

// Imported only from the end of ShipEntity.h (which declares everything used here); never import
// it directly, and never import ShipEntity.h from it (a cycle).
#ifndef SHIPENTITY_FOUNDATIONBRIDGE_H
#define SHIPENTITY_FOUNDATIONBRIDGE_H


@interface ShipEntity (OOFoundationBridge)

// oo-3rb.232: subentities
- (NSEnumerator *)shipSubEntityEnumerator;	// -> -cxx_shipSubEntities
- (NSEnumerator *)exhaustEnumerator;	// -> -cxx_exhausts
- (NSString *) serializeShipSubEntities;	// -> -cxx_serializeShipSubEntities
- (void) deserializeShipSubEntitiesFrom:(NSString *)string;	// -> -cxx_deserializeShipSubEntitiesFrom:
- (BOOL) setUpOneStandardSubentity:(NSDictionary *) subentDict asTurret:(BOOL)asTurret;	// -> -cxx_setUpOneStandardSubentity:asTurret:

// oo-3rb.233: equipment
- (NSUInteger) countEquipmentItem:(NSString *)eqkey;	// -> -cxx_countEquipmentItem:
- (NSString *) equipmentItemProviding:(NSString *)equipmentType;	// -> -cxx_equipmentItemProviding:
- (BOOL) hasEquipmentItemProviding:(NSString *)equipmentType;	// -> -cxx_hasEquipmentItemProviding:
- (BOOL) equipmentValidToAdd:(NSString *)equipmentKey inContext:(NSString *)context;	// -> -cxx_equipmentValidToAdd:inContext:
- (BOOL) equipmentValidToAdd:(NSString *)equipmentKey whileLoading:(BOOL)loading inContext:(NSString *)context;	// -> -cxx_equipmentValidToAdd:whileLoading:inContext:
- (NSEnumerator *) equipmentEnumerator;	// -> -cxx_equipmentKeys
- (BOOL) hasOneEquipmentItem:(NSString *)itemKey includeWeapons:(BOOL)includeMissiles whileLoading:(BOOL)loading;	// -> -cxx_hasOneEquipmentItem:includeWeapons:whileLoading:
- (BOOL) hasOneEquipmentItem:(NSString *)itemKey includeMissiles:(BOOL)includeMissiles whileLoading:(BOOL)loading;	// -> -cxx_hasOneEquipmentItem:includeMissiles:whileLoading:
- (NSArray *) equipmentListForScripting;	// -> -cxx_equipmentListForScripting

// oo-3rb.234: missiles and weapon mounts
- (NSArray *) aftWeaponOffset;	// -> -cxx_aftWeaponOffset
- (NSArray *) forwardWeaponOffset;	// -> -cxx_forwardWeaponOffset
- (NSArray *) portWeaponOffset;	// -> -cxx_portWeaponOffset
- (NSArray *) starboardWeaponOffset;	// -> -cxx_starboardWeaponOffset
- (NSArray *) laserPortOffset:(OOWeaponFacing)direction;	// -> -cxx_laserPortOffset:
- (BOOL) fireLaserShotInDirection:(OOWeaponFacing)direction weaponIdentifier:(NSString *)weaponIdentifier;	// -> -cxx_fireLaserShotInDirection:weaponIdentifier:
- (ShipEntity *) fireMissileWithIdentifier:(NSString *) identifier andTarget:(Entity *) target;	// -> -cxx_fireMissileWithIdentifier:andTarget:

@end


// oo-3rb.234
Vector positionOffsetForShipInRotationToAlignment(ShipEntity* ship, Quaternion q, NSString* align);	// -> cxx_positionOffsetForShipInRotationToAlignment

#endif	// SHIPENTITY_FOUNDATIONBRIDGE_H
