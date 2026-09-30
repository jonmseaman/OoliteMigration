/*

OOSDLJoystickManager+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056 and its amendment oo-o89): the Objective-C
OOSDLJoystickManager, a facade over the C++ cxx::OOSDLJoystickManager (OOSDLJoystickManager.h).
Its interface is the one OOSDLJoystickManager.h declared before the conversion, copied exactly
(same selectors, same types, same superclass), so its callers and its superclass compile and
behave unchanged; each method forwards to its C++ member. Imported as the last line of
OOSDLJoystickManager.h; do not import it directly.

Unlike OOColor's facade this one is not thin: its superclass OOJoystickManager is still
Objective-C, creates it (+setStickHandlerClass: / +sharedStickHandler) and keeps its own state in
it. So the facade makes and owns its C++ object in -init, and the pair lives and dies together:

	direction                      crosses with                what it gives
	-----------------------------  --------------------------  -------------------------------------
	C++ -> its superclass          oo::ToObjC(this)            the live facade; never a new one (a
	  (decodeAxisEvent: & co.)                                 new one would have fresh superclass
	                                                           state), so nil once it is gone
	Objective-C -> C++             oo::ToCxx(manager)          the borrowed C++ object; null for nil

Never add to this file; converted code does not message the facade except for the superclass's
methods. Deleted by its deletion bead once OOJoystickManager is C++ and cxx::OOSDLJoystickManager
can derive from it.

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

#ifndef OOSDLJOYSTICKMANAGER_OBJCBRIDGE_H
#define OOSDLJOYSTICKMANAGER_OBJCBRIDGE_H

#import "OOCocoa.h"
#import <SDL3/SDL_events.h>
#import "OOJoystickManager.h"

#include "oofnd/StdLib.hpp"


@interface OOSDLJoystickManager: OOJoystickManager
{
@private
	oo::Ref<cxx::OOSDLJoystickManager>	_cxxManager;
}

- (id) init;
- (void) dealloc;
- (BOOL) handleSDLEvent: (SDL_Event *)evt;
- (std::optional<std::string>) nameOfJoystick:(NSUInteger)stickNumber;	// nullopt: the device has no name
- (int16_t) getAxisWithStick:(NSUInteger) stickNum axis:(NSUInteger) axisNum ;
- (JoyAxisEvent) makeJoyAxisEvent: (SDL_JoyAxisEvent*) sdlevt;
- (JoyButtonEvent) makeJoyButtonEvent: (SDL_JoyButtonEvent*) sdlevt;
- (JoyHatEvent) makeJoyHatEvent: (SDL_JoyHatEvent*) sdlevt;
- (NSInteger) getJoystickIndexFromId: (SDL_JoystickID) joystickId;

@end


namespace oo {

// The manager's live facade (autoreleased), or nil: never a new one (see above). nil for null.
OOSDLJoystickManager *ToObjC(cxx::OOSDLJoystickManager *manager);

// The C++ manager behind a facade, borrowed (the facade owns it); null for nil.
cxx::OOSDLJoystickManager *ToCxx(OOSDLJoystickManager *manager);

}	// namespace oo

#endif	// OOSDLJOYSTICKMANAGER_OBJCBRIDGE_H
