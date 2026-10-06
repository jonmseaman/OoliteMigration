/*

GameController.h

Main application controller class.

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


#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"
#import "OOFunctionAttributes.h"
#import "OOFullScreenController.h"
#import "OOMouseInteractionMode.h"

#include "oofnd/StdLib.hpp"
#include "oofnd/PList.hpp"
#include "oofnd/Ref.hpp"

#include <optional>
#include <string>
#include <vector>


#if OOLITE_MAC_OS_X
#import <Quartz/Quartz.h>	// For PDFKit.
#endif

#define MINIMUM_GAME_TICK		0.25
// * reduced from 0.5s for tgape * //

#define MINIMUM_ANIMATION_TICK	0.0041667
// 1.0 / (desired framerate cap)


@class MyOpenGLView;
class OOFullScreenController;	// C++ since bead oo-bgmb


// TEMP: whether to use separate OOFullScreenController object, will hopefully be used for all builds soon.
#define OO_USE_FULLSCREEN_CONTROLLER	OOLITE_MAC_OS_X


namespace cxx {

/*	The application controller (bead oo-zkpmt, slice 1 of docs/phases/3-slices/GameController.md):
	the class shell, its state and accessors. The frame loop and deferred calls (slice 2) and the
	start-up, splash and progress messages, exit and player-file methods (slice 3) are still
	Objective-C methods of the façade (GameController+ObjCBridge.h), in GameController.mm, as is the
	FullScreen category (SDL/GameController+SDLFullScreen.mm, bead oo-qinv); they read and write the
	state below through the façade's _cxxController.
*/
class GameController : public oo::RefCounted
{
public:
	// The shared controller, made on first use; borrowed, never released (proposed ADR-0056
	// amendment oo-r7m0).
	static GameController *sharedController();

	GameController();
	~GameController();

	bool finishedLaunching();

	bool isGamePaused();
	void setGamePaused(bool value);

	/*
	  Eco Quality of Service currently implemented only on Windows.
	  It sets the game to low power consumption mode when it loses
	  focus or is paused. When EcoQoS is active:
	  - Windows schedules the appliation on more efficient CPU cores
	  - The CPU is kept at a more efficient clock frequency
	  
	  On non-Windows platforms it is a no-op.
	*/
	void setEcoQoS(bool efficiencyModeRequested);

	OOMouseInteractionMode mouseInteractionMode();
	void setMouseInteractionMode(OOMouseInteractionMode mode);
	void setMouseInteractionModeForFlight();	// Chooses mouse control mode appropriately.
	void setMouseInteractionModeForUIWithMouseInteraction(bool interaction);

	MyOpenGLView *gameView();
	void setGameView(MyOpenGLView *view);

#ifndef NDEBUG
	bool suppressClangStuff();
#endif

	// Internal: the state, which slices 2 and 3 and the FullScreen category (still Objective-C on
	// the façade) read and write through _cxxController; it becomes private as they convert.
#if OOLITE_MAC_OS_X
	NSTextField				*splashProgressTextField = {};
	NSView					*splashView = {};
	NSWindow				*gameWindow = {};
	PDFView					*helpView = {};
	NSMenu					*dockMenu = {};
#endif
	
	MyOpenGLView			*_gameView = {};	// retained; was gameView, named like its getter
	
	NSTimeInterval			last_timeInterval = {};
	double					delta_t = {};
	
	int						my_mouse_x = {}, my_mouse_y = {};

	std::optional<std::string>	_playerFileDirectory;	// nullopt: not looked up yet, or none (was nil); named so -cxx_playerFileDirectory's member can be playerFileDirectory()
	std::optional<std::string>	_playerFileToLoad;		// nullopt: none (was nil); named so -cxx_playerFileToLoad's member can be playerFileToLoad()
	std::vector<std::string>	expansionPathsToInclude;	// expansion folders opened with the application (Mac)
	
	NSTimeInterval			_animationTimerInterval = {};
	
	NSTimeInterval			_splashStart = {};	// oo::date::monotonicSeconds() at start-up
	
	SEL						pauseSelector = {};
	OOObject				*pauseTarget = {};
	
	bool					gameIsPaused = {};
	
	OOMouseInteractionMode	_mouseMode = {};
	OOMouseInteractionMode	_resumeMode = {};
	
// Fullscreen mode stuff.
#if OO_USE_FULLSCREEN_CONTROLLER
	OOFullScreenController	*_fullScreenController = {};
#elif OOLITE_SDL
	NSRect					fsGeometry = {};
	MyOpenGLView			*switchView = {};
	
	oo::PList::Array		displayModes;			// the usable screen modes, each a mode dictionary
	
	unsigned int			width = {}, height = {};
	unsigned int			refresh = {};
	bool					fullscreen = {};
	oo::PList				originalDisplayMode;	// a mode dictionary; null: none (was nil)
	oo::PList				fullscreenDisplayMode;	// a mode dictionary; null: none (was nil)
	
	bool					stayInFullScreenMode = {};
	bool					_finishedLaunching = {};
#endif
};

}	// namespace cxx


/*	OOScheduleDeferredCall(target, selector, argument, delay): what Foundation's
	performer-after-delay did (bead oo-3rb.57, proposed ADR-0040). [target
	performSelector:selector withObject:argument] runs on the first frame-loop
	pass at least delay seconds from now (a delay <= 0 is 0.0001 s), after that
	pass's tick; target and argument are retained until then. Due calls fire in
	the order they were scheduled, at most two per pass, as the run loop fired
	its timers. Main thread only: a call scheduled on another thread never fires,
	as a performer on that thread's never-run run loop did not.
*/
void OOScheduleDeferredCall(id target, SEL selector, id argument, NSTimeInterval delay);


#if OO_DEBUG
#define OO_DEBUG_PROGRESS(message)		[[::GameController sharedController] cxx_debugLogProgress:message]
#define OO_DEBUG_PUSH_PROGRESS(message)	[[::GameController sharedController] cxx_debugPushProgressMessage:message]
#define OO_DEBUG_POP_PROGRESS()		[[::GameController sharedController] debugPopProgressMessage]
#else
#define OO_DEBUG_PROGRESS(message)		do {} while (0)
#define OO_DEBUG_PUSH_PROGRESS(message)	do {} while (0)
#define OO_DEBUG_POP_PROGRESS()		do {} while (0)
#endif


// Transitional: the Objective-C GameController, for code not yet converted. Deleted, with namespace
// cxx above, by the bridge's deletion bead.
#import "GameController+ObjCBridge.h"
