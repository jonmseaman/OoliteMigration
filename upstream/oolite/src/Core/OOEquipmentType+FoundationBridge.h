/*

OOEquipmentType+FoundationBridge.h

TRANSITIONAL (proposed ADR-0043, "Transitional bridges"; bead oo-fvnu, made by its chunk
oo-3rb.156, and chunks oo-3rb.157..159 move their own selectors in). OOEquipmentType's
Foundation-typed API as it was before its sweep, with the same selector names and types,
forwarding to the cxx_ API in OOEquipmentType.h. It exists so that OOEquipmentType's callers
compile unchanged; each caller moves to the cxx_ API in its own sweep bead. When `git grep` finds
no caller of anything declared here, the bridge bead deletes this file,
OOEquipmentType+FoundationBridge.mm, its line in Core/meson.build and the #import at the end of
OOEquipmentType.h. Never add to it; never call it from migrated code. oo-qps (the removal of
gnustep-base) cannot compile while it exists.

Registry: src/oofnd/README.md, "Transitional bridges".

Copyright (C) 2008-2013 Jens Ayton and contributors (OOEquipmentType.h)

*/

// Imported only from the end of OOEquipmentType.h (which declares everything used here); never
// import it directly, and never import OOEquipmentType.h from it (a cycle).
#ifndef OOEQUIPMENTTYPE_FOUNDATIONBRIDGE_H
#define OOEQUIPMENTTYPE_FOUNDATIONBRIDGE_H


@interface OOEquipmentType (OOFoundationBridge)

+ (NSString *) getMissileRegistryRoleForShip:(NSString *)shipKey;				// -> +cxx_getMissileRegistryRoleForShip:
+ (void) setMissileRegistryRole:(NSString *)roles forShip:(NSString *)shipKey;	// -> +cxx_setMissileRegistryRole:forShip:

+ (OOEquipmentType *) equipmentTypeWithIdentifier:(NSString *)identifier;		// -> +cxx_equipmentTypeWithIdentifier:

- (NSString *) identifier;			// -> -cxx_identifier
- (NSString *) damagedIdentifier;	// -> -cxx_damagedIdentifier
- (NSString *) descriptiveText;		// -> -cxx_descriptiveText

- (NSSet *) requiresEquipment;		// Set of equipment identifiers; all items required		-> -cxx_requiresEquipment
- (NSSet *) requiresAnyEquipment;	// Set of equipment identifiers; any item required		-> -cxx_requiresAnyEquipment
- (NSSet *) incompatibleEquipment;	// Set of equipment identifiers; all items prohibited	-> -cxx_incompatibleEquipment

- (NSArray *) conditions;			// -> -cxx_conditions
- (NSString *) conditionScript;		// -> -cxx_conditionScript

@end

#endif	// OOEQUIPMENTTYPE_FOUNDATIONBRIDGE_H
