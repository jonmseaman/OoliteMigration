## Create Windows setup/clion install guide

Instruction to setup the clion build, .run files, etc.
## Clean up references to beads

There are many references to beads.

Example:
tests/unit/core/test_OOWaypointEntity.cpp
```cpp
/*  test_OOWaypointEntity.mm  
    Unit tests for OOWaypointEntity (src/Core/Entities/OOWaypointEntity.h), the scripted beacon    waypoints: bead oo-zsid, a leaf of the Entities seam with a facade (proposed ADR-0056,    amendments oo-bj8 item 12 and oo-0mxi).
    ...
*/
```

I would rather not reference the beads or the ADRs in the new code. The comments should just be good comments that describe that the file is for like normal comments. No history lesson is needed.

## Component tests organization

- `tests/unit` --> Unit tests should normally go alongside the files they test.
- `tests/component`
	- feature folder files should be moved up one with step definitions in subfolders or a different folder alongside.
## `oolite.exe.manifest`
`src/SDL/OOResourcesWin/oolite.exe.manifest`
Should this file include windows 11?

## GnuStep macros

Many instances of macros with GNUSTEP in it. Are these obsolete and can they be deleted?
```cpp
#elif (OOLITE_GNUSTEP && defined(OO_DEBUG_MONITOR_ENABLED))  
#include "OODebugMonitor.h"  
#endif
```

`ShellScripts/Linux/build_gnustep.sh` --> Should this file even exist?

## Better autoformat

There are functions that don't have spaces between them.

Stuff like this:
```cpp
int func1() {
}
int func2() {
}
```

Readability prefers spaces between functions. There should be readability rules generated and such.

## Heavy macro use

There are a ton of macros. Some are debug only, some are windows only.
I'm not a huge fan of macros. I'd like to go through and see if these should be replaced in some cases.
