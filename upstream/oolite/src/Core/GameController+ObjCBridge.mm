/*

GameController+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, bead oo-zkpmt): the Objective-C GameController façade's own
methods: the crossings, the singleton façade and one-line forwarders to cxx::GameController for
slice 1's selectors. See GameController+ObjCBridge.h.

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

#import "GameController.h"

#include "oofnd/objc/OOObjCPeer.h"
#include "oofnd/objc/OOException.h"
#include "oofnd/Log.hpp"
#include "oofnd/String.hpp"


namespace {

// Never destroyed: a façade may be released while the process exits.
oo::ObjCPeers &Peers()
{
	static oo::ObjCPeers *peers = new oo::ObjCPeers;
	return *peers;
}

}	// namespace


@interface GameController (OOObjCBridgePrivate)

- (id) initWithCxxController:(cxx::GameController *)controller;

@end


@implementation GameController (OOObjCBridge)

// Inside the @implementation, as the façade's crossings are elsewhere.
GameController *oo::ToObjC(cxx::GameController *controller)
{
	return Peers().peerFor(controller, [controller] { return [[GameController alloc] initWithCxxController:controller]; });
}


cxx::GameController *oo::ToCxx(GameController *controller)
{
	if (controller == nil)  return nullptr;
	return controller->_cxxController.get();
}


- (id) initWithCxxController:(cxx::GameController *)controller
{
	self = [super init];
	if (self != nil)  _cxxController = oo::Ref<cxx::GameController>(controller);
	return self;
}


- (void) dealloc
{
	Peers().forget(_cxxController.get());
	[super dealloc];
}


+ (GameController *) sharedController
{
	// One façade for the life of the process, as there was one object (amendment oo-r7m0, item 5).
	static GameController *facade = nil;
	if (facade == nil)  facade = [oo::ToObjC(cxx::GameController::sharedController()) retain];
	return facade;
}


- (BOOL) finishedLaunching													{ return _cxxController->finishedLaunching(); }
- (BOOL) isGamePaused														{ return _cxxController->isGamePaused(); }
- (void) setGamePaused:(BOOL)value											{ _cxxController->setGamePaused(value); }
- (void) setEcoQoS:(BOOL)efficiencyModeRequested							{ _cxxController->setEcoQoS(efficiencyModeRequested); }
- (OOMouseInteractionMode) mouseInteractionMode								{ return _cxxController->mouseInteractionMode(); }
- (void) setMouseInteractionMode:(OOMouseInteractionMode)mode				{ _cxxController->setMouseInteractionMode(mode); }
- (void) setMouseInteractionModeForFlight									{ _cxxController->setMouseInteractionModeForFlight(); }
- (void) setMouseInteractionModeForUIWithMouseInteraction:(BOOL)interaction	{ _cxxController->setMouseInteractionModeForUIWithMouseInteraction(interaction); }
- (MyOpenGLView *) gameView													{ return _cxxController->gameView(); }
- (void) setGameView:(MyOpenGLView *)view									{ _cxxController->setGameView(view); }

#if !OOLITE_MAC_OS_X	// the Mac -performGameTick: is in GameController (MacOSX), in GameController.mm
- (void) performGameTick:(id)sender											{ _cxxController->performGameTick(sender); }
#endif
- (void) startAnimationTimer												{ _cxxController->startAnimationTimer(); }
- (void) stopAnimationTimer													{ _cxxController->stopAnimationTimer(); }
- (void) fireDueTimers														{ _cxxController->fireDueTimers(); }

@end


@implementation GameController (OOPrivateForwarded)

- (void) runFrameLoop														{ _cxxController->runFrameLoop(); }

@end


bool GameControllerPerformSelectorWithObject(id target, SEL selector, id argument)
{
	@try
	{
		[target performSelector:selector withObject:argument];
	}
	@catch (OOException *exception)
	{
		// The game's own exceptions (ADR-0037): the same line, name and reason bridged.
		OO_LOG("unclassified", "*** NSTimer ignoring exception '{}' (reason '{}') raised during posting of timer with target {} and selector 'fire'", [exception name], [exception reason], oo::str::pointerDescription(target));
		return false;
	}
	return true;
}
