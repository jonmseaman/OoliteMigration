/*

Universe+FoundationBridge.h

TRANSITIONAL (proposed ADR-0043, "Transitional bridges"; made by bead oo-3rb.220, chunk 1 of the
Universe sweep oo-3rb.79, and extended only by its later chunks oo-3rb.221-.231). Universe's
Foundation-typed API as it was before its sweep, with the same selector and function names and
types, forwarding to the cxx_ API in Universe.h. It exists so that Universe's callers (some 70
files, most through the UNIVERSE macro and DESC()) compile unchanged; each caller moves to the cxx_
API in its own sweep bead. When `git grep` finds no caller of anything declared here, the bridge
bead deletes this file, Universe+FoundationBridge.mm, its line in Core/meson.build and the #import
at the end of Universe.h (DESC() / DESC_PLURAL() then expand to the cxx_ lookups). Never add to it
outside the Universe chunks; never call it from migrated code. oo-qps (the removal of
gnustep-base) cannot compile while it exists.

Registry: src/oofnd/README.md, "Transitional bridges".

Copyright (C) 2004-2013 Giles C Williams and contributors (Universe.h)

*/

// Imported only from the end of Universe.h (which declares everything used here); never import it
// directly, and never import Universe.h from it (a cycle).
#ifndef UNIVERSE_FOUNDATIONBRIDGE_H
#define UNIVERSE_FOUNDATIONBRIDGE_H


@interface Universe (OOFoundationBridge)

// Chunk 1 (oo-3rb.220): descriptions, characters, mission text, scenarios, explosion settings.
- (NSDictionary *) descriptions;	// -> -cxx_descriptions (one immutable copy per -cxx_descriptionsGeneration)
- (NSDictionary *) characters;		// -> -cxx_characters
- (NSDictionary *) missiontext;		// -> -cxx_missiontext
- (NSArray *) scenarios;			// -> -cxx_scenarios
- (NSDictionary *) explosionSetting:(NSString *)explosion;	// -> -cxx_explosionSetting:

- (NSString *)descriptionForKey:(NSString *)key;	// -> -cxx_descriptionForKey:
- (NSString *)descriptionForArrayKey:(NSString *)key index:(unsigned)index;	// -> -cxx_descriptionForArrayKey:index:

@end


// Chunk 1 (oo-3rb.220): the lookups behind DESC() / DESC_PLURAL().
#ifdef __cplusplus
extern "C" {
#endif
NSString *OOLookUpDescriptionPRIV(NSString *key);	// -> cxx_OOLookUpDescriptionPRIV
#ifdef __cplusplus
}
#endif
NSString *OOLookUpPluralDescriptionPRIV(NSString *key, NSInteger count);	// -> cxx_OOLookUpPluralDescriptionPRIV

#endif	// UNIVERSE_FOUNDATIONBRIDGE_H
