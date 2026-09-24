/*

OOLogOutputHandler+FoundationBridge.h

TRANSITIONAL (proposed ADR-0043, "Transitional bridges"; made by bead oo-vjts, Amendment 2 item
18(a)). Two things live here:

  * gnustep-base's NSLog hook (_NSLog_printf_handler, whose type is void (*)(NSString *)), which
    OOLogOutputHandlerInit() / OOLogOutputHandlerClose() install and remove through the two C
    functions below. It goes with gnustep-base (oo-qps).
  * OOLogOutputHandler's Foundation-typed API as it was before its sweep, with the same names and
    types, forwarding to the cxx_ functions in OOLogOutputHandler.h, so that its callers compile
    unchanged; each caller moves to the cxx_ API in its own sweep bead. When `git grep` finds no
    caller of them outside this bridge, oo-vors deletes them from it.

Never add to it; never call its Foundation-typed functions from migrated code. oo-qps (the removal
of gnustep-base) deletes this file, OOLogOutputHandler+FoundationBridge.mm, its line in
Core/meson.build and the #import at the end of OOLogOutputHandler.h.

Registry: src/oofnd/README.md, "Transitional bridges".

Copyright (C) 2007-2013 Jens Ayton (OOLogOutputHandler.h)

*/

// Imported only from the end of OOLogOutputHandler.h (which declares everything used here); never
// import it directly, and never import OOLogOutputHandler.h from it (a cycle).
#ifndef OOLOGOUTPUTHANDLER_FOUNDATIONBRIDGE_H
#define OOLOGOUTPUTHANDLER_FOUNDATIONBRIDGE_H


// gnustep-base's NSLog hook: route NSLog() into the "gnustep" log class. No-ops elsewhere.
void OOLogOutputHandlerInstallNSLogHook(void);
void OOLogOutputHandlerRemoveNSLogHook(void);

// This will attempt to ensure the containing directory exists. If it fails, it will return nil.
NSString *OOLogHandlerGetLogPath(void);	// -> cxx_OOLogHandlerGetLogPath()
NSString *OOLogHandlerGetLogBasePath(void);	// -> cxx_OOLogHandlerGetLogBasePath()
void OOLogOutputHandlerChangeLogFile(NSString *newLogName);	// -> cxx_OOLogOutputHandlerChangeLogFile()

#endif	// OOLOGOUTPUTHANDLER_FOUNDATIONBRIDGE_H
