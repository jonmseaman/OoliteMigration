/*

AI.h

Core NPC behaviour/artificial intelligence class.

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

#import <Foundation/Foundation.h>
#import "OOWeakReference.h"
#import "OOTypes.h"

#include "oofnd/StdLib.hpp"

#define AI_THINK_INTERVAL					0.125


@class ShipEntity;


@interface AI: OOWeakRefObject
{
@private
	id					_owner;						// OOWeakReference to the ShipEntity this is the AI for
	NSString			*ownerDesc;					// describes the object this is the AI for
	
	NSDictionary		*stateMachine;
	NSString			*stateMachineName;
	NSString			*currentState;
	NSMutableSet		*pendingMessages;
	
	NSMutableArray		*aiStack;
	
	OOTimeAbsolute		nextThinkTime;
	OOTimeDelta			thinkTimeInterval;
	
	NSString      *jsScript;
}

+ (AI *) currentlyRunningAI;
+ (NSString *) currentlyRunningAIDescription;

- (NSString *) name;
- (NSString *) associatedJS;
- (NSString *) state;

- (void) cxx_setStateMachine:(const std::string &)smName withJSScript:(const std::string &)script;
- (void) cxx_setState:(const std::string &)stateName;

- (void) cxx_setStateMachine:(const std::string &)smName afterDelay:(NSTimeInterval)delay;
- (void) cxx_setState:(const std::string &)stateName afterDelay:(NSTimeInterval)delay;

// std::nullopt where the Foundation version took nil (no state machine / no initial state). An
// initializer outside the init family by name, so the ownership it returns (+1) is declared.
- (id) cxx_initWithStateMachine:(const std::optional<std::string> &)smName andState:(const std::optional<std::string> &)stateName OO_RETURNS_RETAINED;

- (ShipEntity *)owner;
- (void) setOwner:(ShipEntity *)ship;

- (void) preserveCurrentStateMachine;

- (void) restorePreviousStateMachine;

- (BOOL) hasSuspendedStateMachines;
- (void) cxx_exitStateMachineWithMessage:(const std::optional<std::string> &)message;	// nullopt: "RESTARTED"

- (NSUInteger) stackDepth;

// Immediately handle a message. This is the core dispatcher. DebugContext is a textual hint for diagnostics.
- (void) reactToMessage:(NSString *) message context:(NSString *)debugContext;

- (void) takeAction:(NSString *) action;

- (void) think;

- (void) message:(NSString *) ms;
- (void) dropMessage:(NSString *) ms;
- (NSSet *) pendingMessages;
- (void) debugDumpPendingMessages;

- (void) setNextThinkTime:(OOTimeAbsolute) ntt;
- (OOTimeAbsolute) nextThinkTime;

- (void) setThinkTimeInterval:(OOTimeDelta) tti;
- (OOTimeDelta) thinkTimeInterval;

- (void) clearStack;

- (void) clearAllData;

- (void)dumpState;

@end


/*	TRANSITIONAL (proposed ADR-0043, "Transitional bridges"): the Foundation-typed API this header
	declared before the AI.mm sweep (beads oo-3rb.84-87, oo-gtl8), forwarding to the cxx_ methods
	above, so unmigrated callers compile unchanged. Callers move to the cxx_ API in their own sweep
	beads; the bridge goes in its own bead.
*/
#import "AI+FoundationBridge.h"
