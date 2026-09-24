/*

PlayerEntity+FoundationBridge.h

TRANSITIONAL (proposed ADR-0043, "Transitional bridges"; bead oo-3rb.164, a chunk of oo-3rb.75).
PlayerEntity's Foundation-typed API as it was before its sweep, with the same selector names and
types, forwarding to the cxx_ API in PlayerEntity.h. It exists so that the callers (GuiDisplayGen
for -markedDestinations) compile unchanged; each caller moves to the cxx_ API in its own sweep
bead. When `git grep` finds no caller of anything declared here, the bridge bead deletes this
file, PlayerEntity+FoundationBridge.mm, its line in Core/Entities/meson.build and the #import at
the end of PlayerEntity.h. Never add to it outside the PlayerEntity chunks; never call it from
migrated code. oo-qps (the removal of gnustep-base) cannot compile while it exists.

Registry: src/oofnd/README.md, "Transitional bridges".

Copyright (C) 2004-2013 Giles C Williams and contributors (PlayerEntity.h)

*/

// Imported only from the end of PlayerEntity.h (which declares everything used here); never
// import it directly, and never import PlayerEntity.h from it (a cycle).
#ifndef PLAYERENTITY_FOUNDATIONBRIDGE_H
#define PLAYERENTITY_FOUNDATIONBRIDGE_H


@interface PlayerEntity (FoundationBridge)

// oo-3rb.164: marked destinations
- (NSDictionary *) markedDestinations;	// -> -cxx_markedDestinations

@end

#endif	// PLAYERENTITY_FOUNDATIONBRIDGE_H
