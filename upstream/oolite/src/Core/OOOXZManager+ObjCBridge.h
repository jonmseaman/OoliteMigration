/*

OOOXZManager+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056, bead oo-bwjb): the Objective-C OOOXZManager, a facade over the C++
cxx::OOOXZManager (OOOXZManager.h), for the code that is not converted yet: its callers
(GameController, PlayerEntity, PlayerEntityControls), and the units of slice 4 of
OOOXZManager.mm (docs/phases/3-slices/OOOXZManager.md: the install and remove option pages), which stay Objective-C methods of this facade, in OOOXZManager.mm, until
their own beads. Its interface is the one OOOXZManager.h declared before the conversion, copied
exactly (same selectors, same types): the slice 1 methods forward to their C++ members in one
line each, and the rest are declared by the OOOXZManagerSlices category below, which
OOOXZManager.mm implements. Imported as the last line of OOOXZManager.h; do not import it
directly.

	a caller that is                       holds / passes                       crosses with
	-------------------------------------  -----------------------------------  ------------------------
	still Objective-C                      OOOXZManager * (this facade)         nothing: messages as before
	converted (C++)                        cxx::OOOXZManager * (the singleton)
	  handing the manager to Objective-C                                        oo::ToObjC(manager)
	  taking it from Objective-C                                                oo::ToCxx(objcManager)

The manager is a singleton: +sharedManager answers one facade for the life of the process
(proposed ADR-0056 amendment oo-r7m0, item 5). Never add to this file; converted code does not
message the facade. Deleted by its deletion bead once slice 4 is converted and no file
outside OOOXZManager.* names the Objective-C class.

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

#ifndef OOOXZMANAGER_OBJCBRIDGE_H
#define OOOXZMANAGER_OBJCBRIDGE_H

#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"


@interface OOOXZManager: OOObject
{
@private
	oo::Ref<cxx::OOOXZManager>	_cxxManager;
}

+ (OOOXZManager *) sharedManager;

- (std::optional<std::string>) installPath;	// oo::ResourcePaths::managedAddOnsDirectory()
- (std::optional<std::string>) extractAddOnsPath;	// oo::ResourcePaths::extractAddOnsDirectory()
- (std::vector<std::string>) additionalAddOnsPaths;	// oo::ResourcePaths::additionalAddOnsDirectories()

- (BOOL) updateManifests;
- (BOOL) cancelUpdate;

/*	Deliver the current download's callbacks (response, data, finish, failure), in order,
	on the main thread: GameController's frame loop calls this where it pumps the run loop,
	which is where the old URL-connection callbacks were delivered. Proposed ADR-0044.
*/
- (void) processDownloadEvents;

- (oo::PList) manifests;	// an Array, or null before a list is loaded
- (oo::PList) managedOXZs;	// an Array

- (void) gui;
- (BOOL) isRestarting;
- (BOOL) isAcceptingTextInput;
- (BOOL) isAcceptingGUIInput;

- (void) processSelection;
- (void) processTextInput:(const std::string &)input;
- (void) refreshTextInput:(const std::string &)input;
- (void) processFilterKey;
- (void) processShowInfoKey;
- (void) processExtractKey;

@end


// The rest of the old interface: slice 4, still Objective-C, implemented in OOOXZManager.mm.
@interface OOOXZManager (OOOXZManagerSlices)

- (OOGUIRow) showInstallOptions;
- (OOGUIRow) showRemoveOptions;
- (void) showOptionsUpdate;
- (void) showOptionsPrev;
- (void) showOptionsNext;
- (void) processOptionsPrev;
- (void) processOptionsNext;

@end


// The units of slices 1 and 2 of the private category that slice 4 sends (or the unit test
// does), forwarded to their C++ members (proposed ADR-0056 amendment oo-pni4 item 1). Moved from
// OOOXZManager.mm.
@interface OOOXZManager (OOPrivateForwarded)

- (std::optional<std::string>) downloadPath;	// nullopt: no cache directory
- (std::optional<std::string>) extractionBasePathForIdentifier:(const std::string &)identifier andVersion:(const std::string &)version;	// nullopt: no user root
- (std::optional<std::string>) humanSize:(NSUInteger)bytes;	// nullopt: the missing-field description is missing

- (BOOL) ensureInstallPath;

- (BOOL) validateFilter:(const std::string &)input;

- (void) setFilteredList:(const oo::PList &)list;
- (void) setFilter:(const std::string &)filter;
- (oo::PList) applyCurrentFilter:(const oo::PList &)list;	// an Array

- (void) setProgressStatus:(const std::string &)newStatus;

- (OOColor *) colorForManifest:(const oo::PList &)manifest;
- (std::optional<std::string>) installStatusForManifest:(const oo::PList &)manifest;	// nullopt: its description is missing

- (BOOL) installOXZ:(NSUInteger)item;
- (BOOL) updateAllOXZ;
- (BOOL) removeOXZ:(NSUInteger)item;

- (std::string) extractOXZ:(NSUInteger)item;	// the extraction log

@end


namespace oo {

// The manager's Objective-C facade: its live one, else a new one; autoreleased. nil for null.
OOOXZManager *ToObjC(cxx::OOOXZManager *manager);
// The C++ manager behind a facade, borrowed; null for nil.
cxx::OOOXZManager *ToCxx(OOOXZManager *manager);

}	// namespace oo

#endif	// OOOXZMANAGER_OBJCBRIDGE_H
