/*

AI.m

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

#import "AI.h"
#import <objc/runtime.h>
#import <objc/objc-arc.h>
#import "ResourceManager.h"
#import "OOStringParsing.h"
#import "OOWeakReference.h"
#import "OOCacheManager.h"
#import "OOPListView.h"
#import "OOPListParsing.h"

#import "ShipEntity.h"
#import "ShipEntityAI.h"
#import "oofnd/objc/OOObject.h"
#import "OOFoundationBridge.h"

#include "oofnd/String.hpp"


enum
{
	kRecursionLimiter		= 32,	// reactToMethod: recursion
	kStackLimiter			= 32	// setAITo: stack overflow
};


typedef struct
{
	AI				*ai;
	SEL				selector;
	id				parameter;
} OOAIDeferredCallTrampolineInfo;


/*	Carries the trampoline info through -performSelector:withObject:afterDelay:,
	which retains it until the call fires, as it did the value box that held the
	struct before (bead oo-3rb.48).
*/
@interface OOAIDeferredCallTrampolineInfoHolder: OOObject
{
@public
	OOAIDeferredCallTrampolineInfo	info;
}
@end


@implementation OOAIDeferredCallTrampolineInfoHolder
@end


static AI *sCurrentlyRunningAI = nil;


@interface AI (OOPrivate)

// Wrapper for performSelector:withObject:afterDelay: to catch/fix bugs.
- (void) performDeferredCall:(SEL)selector withObject:(id)object afterDelay:(NSTimeInterval)delay;
+ (void) deferredCallTrampolineWithInfo:(OOAIDeferredCallTrampolineInfoHolder *)info;
// The target of -cxx_setState:afterDelay:'s deferred call: stateName is an Objective-C string.
- (void) deferredSetState:(id)stateName;

- (void) refreshOwnerDesc;

// Set state machine and state without side effects.
- (void) directSetStateMachine:(NSDictionary *)newSM name:(NSString *)name;
- (void) directSetState:(NSString *)state;

// Loading/whitelisting
- (NSDictionary *) loadStateMachine:(NSString *)smName jsName:(NSString *)script;
- (NSDictionary *) cleanHandlers:(NSDictionary *)handlers forState:(NSString *)stateKey stateMachine:(NSString *)smName;
- (NSArray *) cleanActions:(NSArray *)actions forHandler:(NSString *)handlerKey state:(NSString *)stateKey stateMachine:(NSString *)smName;

@end


#if DEBUG_GRAPHVIZ
extern void GenerateGraphVizForAIStateMachine(NSDictionary *stateMachine, NSString *name);
#endif


@interface OOPreservedAIStateMachine: OOObject
{
@private
	NSDictionary		*_stateMachine;
	NSString			*_name;
	NSString			*_state;
	NSMutableSet		*_pendingMessages;
	NSString      *_jsScript;
}

- (id) initWithStateMachine:(NSDictionary *)stateMachine
					   name:(NSString *)name
					  state:(NSString *)state
			pendingMessages:(NSSet *)pendingMessages
									 jsScript:(NSString *)script;

- (NSDictionary *) stateMachine;
- (NSString *) name;
- (NSString *) state;
- (NSSet *) pendingMessages;
- (NSString *) jsScript;

@end


@implementation AI

+ (AI *) currentlyRunningAI
{
	return sCurrentlyRunningAI;
}


+ (std::optional<std::string>) cxx_currentlyRunningAIDescription
{
	if (sCurrentlyRunningAI != nil)
	{
		return oo::str::format("%s in state %s", oo::DescriptionOf([sCurrentlyRunningAI name]).c_str(), oo::DescriptionOf([sCurrentlyRunningAI state]).c_str());
	}
	else
	{
		return "<no AI running>";
	}
}


- (id) init
{
	if ((self = [super init]))
	{
		nextThinkTime = INFINITY;	// don't think for a while
		thinkTimeInterval = AI_THINK_INTERVAL;
		
		stateMachineName = @"<no AI>";	// no initial brain
	}
	
	return self;
}


- (id) cxx_initWithStateMachine:(const std::optional<std::string> &)smName andState:(const std::optional<std::string> &)stateName
{
	if ((self = [self init]))
	{
		if (smName.has_value())  [self cxx_setStateMachine:*smName withJSScript:"oolite-nullAI.js"];
		if (stateName.has_value())  currentState = [oo::NSStringFrom(*stateName) retain];
	}

	return self;
}


- (void) dealloc
{
	if (sCurrentlyRunningAI == self)
	{
		sCurrentlyRunningAI = nil;
	}
	
	DESTROY(_owner);
	DESTROY(ownerDesc);
	DESTROY(aiStack);
	DESTROY(stateMachine);
	DESTROY(stateMachineName);
	DESTROY(currentState);
	DESTROY(pendingMessages);
	DESTROY(jsScript);
	
	[super dealloc];
}


- (NSString *) descriptionComponents
{
	return [NSString stringWithFormat:@"\"%@\" in state: \"%@\" for %@", stateMachineName, currentState, ownerDesc];
}


- (NSString *) shortDescriptionComponents
{
	return [NSString stringWithFormat:@"%@:%@ / %@", stateMachineName, currentState, [stateMachine objectForKey:@"jsScript"]];
}


- (ShipEntity *)owner
{
	ShipEntity		*owner = [_owner weakRefUnderlyingObject];
	if (owner == nil)
	{
		[_owner release];
		_owner = nil;
	}
	
	return owner;
}


- (void) setOwner:(ShipEntity *)ship
{
	[_owner release];
	_owner = [ship weakRetain];
	[self refreshOwnerDesc];
}


- (void) reportStackOverflow
{
	if (OOLogWillDisplayMessagesInClass(@"ai.error.stackOverflow"))
	{
		BOOL stackDump = OOLogWillDisplayMessagesInClass(@"ai.error.stackOverflow.dump");
		
		NSString *trailer = stackDump ? @" -- stack:" : @".";
		OOLogERR(@"ai.error.stackOverflow", @"AI stack overflow for %@ in %@: %@%@\n", [_owner shortDescription], stateMachineName, currentState, trailer);
		
		if (stackDump)
		{
			OOLogIndent();
			
			NSUInteger count = [aiStack count];
			while (count--)
			{
				OOPreservedAIStateMachine *preservedMachine = [aiStack objectAtIndex:count];
				OOLog(@"ai.error.stackOverflow.dump", @"%3zu: %@: %@", count, [preservedMachine name], [preservedMachine state]);
			}
			
			OOLogOutdent();
		}
	}
}


- (void) preserveCurrentStateMachine
{
	if (stateMachine == nil)  return;
	
	if (aiStack == nil)
	{
		aiStack = [[NSMutableArray alloc] init];
	}
	
	if ([aiStack count] >= kStackLimiter)
	{
		[self reportStackOverflow];
		
		[NSException raise:@"OoliteException"
					format:@"AI stack overflow for %@", _owner];
	}
	
	OOPreservedAIStateMachine *preservedMachine = [[OOPreservedAIStateMachine alloc]
												   initWithStateMachine:stateMachine
																   name:stateMachineName
																  state:currentState
														pendingMessages:pendingMessages
																									jsScript:[stateMachine objectForKey:@"jsScript"]];
	
#ifndef NDEBUG
	if ([[self owner] reportAIMessages])  OOLog(@"ai.stack.push", @"Pushing state machine for %@", self);
#endif
	
	[aiStack addObject:preservedMachine];  // PUSH
	
	[preservedMachine release];
}


- (void) restorePreviousStateMachine
{
	if ([aiStack count] == 0)  return;
	
	OOPreservedAIStateMachine *preservedMachine = [aiStack lastObject];
	
#ifndef NDEBUG
	if ([[self owner] reportAIMessages])  OOLog(@"ai.stack.pop", @"Popping previous state machine for %@", self);
#endif
	
	[self directSetStateMachine:[preservedMachine stateMachine]
						   name:[preservedMachine name]];
	
	[self directSetState:[preservedMachine state]];
	
	// restore JS script
	[[self owner] setAIScript:[preservedMachine jsScript]];

	[pendingMessages release];
	pendingMessages = [[preservedMachine pendingMessages] mutableCopy];  // restore a MUTABLE set
	
	[aiStack removeLastObject];  //  POP
}


- (BOOL) hasSuspendedStateMachines
{
	return [aiStack count] != 0;
}


- (void) cxx_exitStateMachineWithMessage:(const std::optional<std::string> &)message
{
	if ([aiStack count] != 0)
	{
		[self restorePreviousStateMachine];
		[self cxx_reactToMessage:message.value_or("RESTARTED") context:"suspended AI restart"];
	}
}


- (void) cxx_setStateMachine:(const std::string &)smName withJSScript:(const std::string &)script
{
	NSDictionary *newSM = [self loadStateMachine:oo::NSStringFrom(smName) jsName:oo::NSStringFrom(script)];

	if (newSM)
	{
		[self preserveCurrentStateMachine];
		[self directSetStateMachine:newSM name:oo::NSStringFrom(smName)];
		[self directSetState:@"GLOBAL"];
		
		nextThinkTime = 0.0;	// think at next tick

		/*	CRASH in objc_msgSend, apparently on [self reactToMessage:@"ENTER"] (1.69, OS X/x86).
			Analysis: self corrupted. We're being called by __NSFireDelayedPerform, which doesn't go
			through -[NSObject performSelector:withObject:], suggesting it's using IMP caching. An
			invalid self is therefore possible.
			Attempted fix: new delayed dispatch with trampoline, see -[AI setStateMachine:afterDelay:].
			 -- Ahruman, 20070706
		*/
		[self cxx_reactToMessage:"ENTER" context:"changing AI"];
		
		// refresh name
		[self refreshOwnerDesc];
	}
}


- (void) cxx_setState:(const std::string &) stateName
{
	if ([stateMachine objectForKey:oo::NSStringFrom(stateName)])
	{
		/*	CRASH in objc_msgSend, apparently on [self reactToMessage:@"EXIT"] (1.69, OS X/x86).
			Analysis: self corrupted. We're being called by __NSFireDelayedPerform, which doesn't go
			through -[NSObject performSelector:withObject:], suggesting it's using IMP caching. An
			invalid self is therefore possible.
			Attempted fix: new delayed dispatch with trampoline, see -[AI setState:afterDelay:].
			 -- Ahruman, 20070706
		*/
		[self cxx_reactToMessage:"EXIT" context:"changing state"];
		[self directSetState:oo::NSStringFrom(stateName)];
		[self cxx_reactToMessage:"ENTER" context:"changing state"];
	}
}


/*	The deferred call's parameter is retained here and released by the trampoline (which released
	the caller's string before: harmless for the literals callers passed, and now balanced for the
	string made here).
*/
- (void) cxx_setStateMachine:(const std::string &)smName afterDelay:(NSTimeInterval)delay
{
	[self performDeferredCall:@selector(setStateMachine:) withObject:[oo::NSStringFrom(smName) retain] afterDelay:delay];
}


- (void) cxx_setState:(const std::string &)stateName afterDelay:(NSTimeInterval)delay
{
	[self performDeferredCall:@selector(deferredSetState:) withObject:[oo::NSStringFrom(stateName) retain] afterDelay:delay];
}


- (NSString *) name
{
	return [[stateMachineName retain] autorelease];
}


- (std::optional<std::string>) cxx_associatedJS
{
	return oo::OptionalString([stateMachine objectForKey:@"jsScript"]);
}


- (NSString *) state
{
	return [[currentState retain] autorelease];
}


- (NSUInteger) stackDepth
{
	return [aiStack count];
}


#ifndef NDEBUG
typedef struct AIStackElement AIStackElement;
struct AIStackElement
{
	AIStackElement			*back;
	ShipEntity				*owner;
	NSString				*aiName;
	NSString				*state;
	const std::string		*message;
	const std::string		*context;
};

static AIStackElement *sStack = NULL;
#endif


- (void) cxx_reactToMessage:(const std::string &) message context:(const std::optional<std::string> &)debugContextArgument
{
	unsigned		i;
	NSArray			*actions = nil;
	NSDictionary	*messagesForState = nil;
	ShipEntity		*owner = [self owner];
	static unsigned	recursionLimiter = 0;
	AI				*previousRunning = sCurrentlyRunningAI;
	
	/*	CRASH in _freedHandler when called via -setState: __NSFireDelayedPerform (1.69, OS X/x86).
		Analysis: owner invalid.
		Fix: make owner an OOWeakReference.
		 -- Ahruman, 20070706
	*/
	if (owner == nil || [owner universalID] == NO_TARGET)  return;

#ifndef NDEBUG
	// Push debug stack frame.
	const std::optional<std::string> debugContext = debugContextArgument.has_value() ? debugContextArgument : std::optional<std::string>("unspecified");
	AIStackElement stackElement =
	{
		.back = sStack,
		.owner = owner,
		.aiName = [[stateMachineName retain] autorelease],
		.state = [[currentState retain] autorelease],
		.message = &message,
		.context = &*debugContext
	};
	sStack = &stackElement;
#endif
	
	/*	CRASH when calling reactToMessage: FOO in state FOO causes infinite
		recursion. (NB: there are other ways of triggering this.)
		FIX: recursion limiter. Alternative is to explicitly catch this case
		in takeAction:, but that could potentially miss indirect recursion via
		scripts.
	*/
	if (recursionLimiter > kRecursionLimiter)
	{
#ifdef NDEBUG
		const std::optional<std::string> &debugContext = debugContextArgument;
#endif
		OOLogERR(@"ai.error.recursion", @"AI dispatch: hit stack depth limit in AI %@, state %@ handling message %@ in context \"%@\", aborting.", stateMachineName, currentState, oo::NSStringFrom(message), oo::NSStringOrNil(debugContext));
		
#ifndef NDEBUG
		AIStackElement *stack = sStack;
		unsigned depth = 0;
		while (stack != NULL)
		{
			OOLog(@"ai.error.recursion.stackTrace", @"%4u  %@ - %@:%@.%@ (%@)", depth++, [stack->owner shortDescription], stack->aiName, stack->state, oo::NSStringFrom(*stack->message), oo::NSStringFrom(*stack->context));
			stack = stack->back;
		}
		
		// unwind.
		if (sStack != NULL)  sStack = sStack->back;
#endif
		
		return;
	}
	
	messagesForState = [stateMachine objectForKey:currentState];
	if (messagesForState == nil)  return;
	
#ifndef NDEBUG
	if (currentState != nil && message != "UPDATE" && [owner reportAIMessages])
	{
		OOLog(@"ai.message.receive", @"AI %@ for %@ in state '%@' receives message '%@'. Context: %@, stack depth: %u", stateMachineName, ownerDesc, currentState, oo::NSStringFrom(message), oo::NSStringOrNil(debugContext), recursionLimiter);
	}
#endif
	
	actions = [[[messagesForState objectForKey:oo::NSStringFrom(message)] copy] autorelease];
	
	sCurrentlyRunningAI = self;
	if ([actions count] > 0)
	{
		++recursionLimiter;
		@try
		{
			for (i = 0; i < [actions count]; i++)
			{
				[self cxx_takeAction:oo::StdString([actions objectAtIndex:i])];
			}
		}
		@catch (NSException *exception)
		{
			OOLog(kOOLogException, @"Squashing exception %@:%@ in AI handler %@:%@.%@", [exception name], [exception reason], stateMachineName, currentState, oo::NSStringFrom(message));
		}
		
		--recursionLimiter;
	}
	else
	{
		if (currentState != nil)
		{
			if ([owner respondsToSelector:@selector(interpretAIMessage:)])
			{
				[owner performSelector:@selector(interpretAIMessage:) withObject:oo::NSStringFrom(message)];
			}
		}
	}
	
	sCurrentlyRunningAI = previousRunning;
#ifndef NDEBUG
	// Unwind stack.
	if (sStack != NULL)  sStack = sStack->back;
#endif
}


- (void) cxx_takeAction:(const std::string &)action
{
	ShipEntity *owner = [self owner];

#ifndef NDEBUG
	BOOL report = [owner reportAIMessages];
	if (report)
	{
		OOLog(@"ai.takeAction", @"%@ to take action %@", ownerDesc, oo::NSStringFrom(action));
		OOLogIndent();
	}
#endif

	const std::vector<std::string> tokens = oo::str::tokens(action);
	const std::size_t tokenCount = tokens.size();

	if (tokenCount != 0)
	{
		const std::string &selectorStr = tokens[0];

		if (owner != nil)
		{
			std::optional<std::string> dataString;

			if (tokenCount == 2)
			{
				dataString = tokens[1];
			}
			else if (tokenCount > 1)
			{
				std::string joined;
				for (std::size_t i = 1; i < tokenCount; i++)
				{
					if (i > 1)  joined += " ";
					joined += tokens[i];
				}
				dataString = std::move(joined);
			}

			SEL selector = NSSelectorFromString(oo::NSStringFrom(selectorStr));
			if ([owner respondsToSelector:selector])
			{
				if (dataString.has_value())  [owner performSelector:selector withObject:oo::NSStringFrom(*dataString)];
				else  [owner performSelector:selector];
			}
			else
			{
				OOLogERR(@"ai.takeAction.badSelector", @"in AI %@ in state %@: %@ does not respond to %@", stateMachineName, currentState, ownerDesc, oo::NSStringFrom(selectorStr));
			}
		}
		else
		{
			OOLog(@"ai.takeAction.orphaned", @"***** AI %@, trying to perform %@, is orphaned (no owner)", stateMachineName, oo::NSStringFrom(selectorStr));
		}
	}
	else
	{
#ifndef NDEBUG
		if (report)  OOLog(@"ai.takeAction.noAction", @"DEBUG: - no action '%@'", oo::NSStringFrom(action));
#endif
	}

#ifndef NDEBUG
	if (report)
	{
		OOLogOutdent();
	}
#endif
}


- (void) think
{
	NSArray			*ms_list = nil;
	unsigned		i;
	
	if ([[self owner] universalID] == NO_TARGET || stateMachine == nil)  return;  // don't think until launched
	
	[self cxx_reactToMessage:"UPDATE" context:"periodic update"];

	if ([pendingMessages count] > 0)
	{
		ms_list = [pendingMessages allObjects];
		[pendingMessages removeAllObjects];
	}
	
	if (ms_list != nil)
	{
		for (i = 0; i < [ms_list count]; i++)
		{
			[self cxx_reactToMessage:oo::StdString([ms_list objectAtIndex:i]) context:"handling deferred message"];
		}
	}
}


- (void) message:(NSString *)ms
{
	if ([[self owner] universalID] == NO_TARGET)  return;  // don't think until launched

	if (EXPECT_NOT([pendingMessages count] > 32))
	{
		// Generate the error, but don't crash Oolite! Fixes bug #18055 - Pending message overflow for thargoids, -> crash !
		OOLogERR(@"ai.message.failed.overflow", @"AI message \"%@\" received by '%@' AI while pending messages stack full; message discarded. Pending messages:\n%@", ms, ownerDesc, pendingMessages);
	}
	else
	{
		if (pendingMessages == nil)
		{
			pendingMessages = [[NSMutableSet alloc] init];
		}
		[pendingMessages addObject:ms];
	}
}


- (void) cxx_dropMessage:(const std::string &)ms
{
	[pendingMessages removeObject:oo::NSStringFrom(ms)];
}
	

- (NSSet *) pendingMessages
{
	if (pendingMessages != nil)
	{
		return [[pendingMessages copy] autorelease];
	}
	else
	{
		return [NSSet set];
	}
}


- (void) debugDumpPendingMessages
{
	NSArray				*sortedMessages = nil;
	NSString			*displayMessages = nil;
	
	if ([pendingMessages count] > 0)
	{
		sortedMessages = [[pendingMessages allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
		displayMessages = [sortedMessages componentsJoinedByString:@", "];
	}
	else
	{
		displayMessages = @"none";
	}
	
	OOLog(@"ai.debug.pendingMessages", @"Pending messages for AI %@: %@", [self descriptionComponents], displayMessages);
}


- (void) setNextThinkTime:(OOTimeAbsolute) ntt
{
	nextThinkTime = ntt;
}


- (OOTimeAbsolute) nextThinkTime
{
	if (!stateMachine)
		return INFINITY;

	return nextThinkTime;
}


- (void) setThinkTimeInterval:(OOTimeDelta) tti
{
	thinkTimeInterval = tti;
}


- (OOTimeDelta) thinkTimeInterval
{
	return thinkTimeInterval;
}


- (void) clearStack
{
	[aiStack removeAllObjects];
}


- (void) clearAllData
{
	[aiStack removeAllObjects];
	[pendingMessages removeAllObjects];
	
	nextThinkTime += 36000.0;	// should dealloc in under ten hours!
}


- (void)dumpState
{
	OOLog(@"dumpState.ai", @"State machine name: %@", stateMachineName);
	OOLog(@"dumpState.ai", @"Current state: %@", currentState);
	OOLog(@"dumpState.ai", @"Next think time: %g", nextThinkTime);
	OOLog(@"dumpState.ai", @"Next think interval: %g", thinkTimeInterval);
}

@end


/*	This is an attempt to fix the bugs referred to above regarding calls from
	__NSFireDelayedPerform with a corrupt self. I'm not certain whether this
	will fix the issue or merely cause a less weird crash in
	+deferredCallTrampolineWithInfo:.
	-- Ahruman 20070706
*/
@implementation AI (OOPrivate)

- (void)performDeferredCall:(SEL)selector withObject:(id)object afterDelay:(NSTimeInterval)delay
{
	OOAIDeferredCallTrampolineInfo	infoStruct;
	OOAIDeferredCallTrampolineInfoHolder	*info = nil;
	
	if (selector != NULL)
	{
		infoStruct.ai = [self retain];
		infoStruct.selector = selector;
		infoStruct.parameter = object;
		
		info = [[OOAIDeferredCallTrampolineInfoHolder alloc] init];
		info->info = infoStruct;
		
		[[AI class] performSelector:@selector(deferredCallTrampolineWithInfo:)
						 withObject:info
						 afterDelay:delay];
		[info release];
	}
}


- (void) deferredSetState:(id)stateName
{
	[self cxx_setState:oo::StdString(stateName)];
}


+ (void)deferredCallTrampolineWithInfo:(OOAIDeferredCallTrampolineInfoHolder *)info
{
	OOAIDeferredCallTrampolineInfo	infoStruct;
	
	if (info != nil)
	{
		infoStruct = info->info;
		
		[infoStruct.ai performSelector:infoStruct.selector withObject:infoStruct.parameter];
		
		[infoStruct.ai release];
		[infoStruct.parameter release];
	}
}


- (void)refreshOwnerDesc
{
	ShipEntity *owner = [self owner];
	[ownerDesc release];
	if ([owner isPlayer])
	{
		ownerDesc = @"player autopilot";
	}
	else if (owner != nil)
	{
		ownerDesc = [[NSString alloc] initWithFormat:@"%@ %d", [owner name], [owner universalID]];
	}
	else
	{
		ownerDesc = @"no owner";
	}
}


- (void) directSetStateMachine:(NSDictionary *)newSM name:(NSString *)name
{
	if (stateMachine != newSM)
	{
		[stateMachine release];
		stateMachine = [newSM copy];
	}
	if (stateMachineName != name)
	{
		[stateMachineName release];
		stateMachineName = [name copy];
	}
}


- (void) directSetState:(NSString *)state
{
	if (currentState != state)
	{
		[currentState release];
		currentState = [state copy];
	}
}


- (NSDictionary *) loadStateMachine:(NSString *)smName jsName:(NSString *)script
{
	NSDictionary			*newSM = nil;
	NSMutableDictionary		*cleanSM = nil;
	OOCacheManager			*cacheMgr = [OOCacheManager sharedCache];
	NSString				*stateKey = nil;
	NSDictionary			*stateHandlers = nil;
	void					*pool = NULL;
	
	if (![smName isEqualToString:@"nullAI.plist"])
	{
		// don't cache nullAI since they're different depending on associated JS AI
		newSM = [cacheMgr objectForKey:smName inCache:@"AIs"];
		if (newSM != nil && ![newSM isKindOfClass:[NSDictionary class]])  return nil;	// catches use of @"nil" to indicate no AI found.
	}
	
	if (newSM == nil)
	{
		pool = objc_autoreleasePoolPush();
		OOLog(@"ai.load", @"Loading and sanitizing AI \"%@\"", smName);
		OOLogPushIndent();
		OOLogIndentIf(@"ai.load");
		
		@try
		{
			// Load state machine and validate against whitelist.
			NSString *aiPath = [ResourceManager pathForFileNamed:smName inFolder:@"AIs"];
			if (aiPath != nil)
			{
				newSM = OODictionaryFromFile(aiPath);
			}
			if (newSM == nil)
			{
				[cacheMgr setObject:@"nil" forKey:smName inCache:@"AIs"];
				NSString *fromString = @"";
				if ([self state] != nil)
				{
					fromString = [NSString stringWithFormat:@" from %@:%@", [self name], [self state]];
				}
				OOLog(@"ai.load.failed.unknownAI", @"Can't switch AI for %@%@ to \"%@\" - could not load file.", [[self owner] shortDescription], fromString, smName);
				return nil;
			}
			
			cleanSM = [NSMutableDictionary dictionaryWithCapacity:[newSM count]];
			
			foreachkey (stateKey, newSM)
			{
				stateHandlers = [newSM objectForKey:stateKey];
				if (![stateHandlers isKindOfClass:[NSDictionary class]])
				{
					OOLogWARN(@"ai.invalidFormat.state", @"State \"%@\" in AI \"%@\" is not a dictionary, ignoring.", stateKey, smName);
					continue;
				}
				
				stateHandlers = [self cleanHandlers:stateHandlers forState:stateKey stateMachine:smName];
				[cleanSM setObject:stateHandlers forKey:stateKey];
			}
			[cleanSM setObject:script forKey:@"jsScript"];

			// Make immutable.
			newSM = [[cleanSM copy] autorelease];
			
#if DEBUG_GRAPHVIZ
			if ([[NSUserDefaults standardUserDefaults] boolForKey:@"generate-ai-graphviz"])
			{
				GenerateGraphVizForAIStateMachine(newSM, smName);
			}
#endif
			
			// Cache.
			[cacheMgr setObject:newSM forKey:smName inCache:@"AIs"];
		}
		@finally
		{
			OOLogPopIndent();
		}
		
		[newSM retain];
		objc_autoreleasePoolPop(pool);
		[newSM autorelease];
	}
	
	return newSM;
}


- (NSDictionary *) cleanHandlers:(NSDictionary *)handlers forState:(NSString *)stateKey stateMachine:(NSString *)smName
{
	NSString				*handlerKey = nil;
	NSArray					*handlerActions = nil;
	NSMutableDictionary		*result = nil;
	
	result = [NSMutableDictionary dictionaryWithCapacity:[handlers count]];
	foreachkey (handlerKey, handlers)
	{
		handlerActions = [handlers objectForKey:handlerKey];
		if (![handlerActions isKindOfClass:[NSArray class]])
		{
			OOLogWARN(@"ai.invalidFormat.handler", @"Handler \"%@\" for state \"%@\" in AI \"%@\" is not an array, ignoring.", handlerKey, stateKey, smName);
			continue;
		}
		
		handlerActions = [self cleanActions:handlerActions forHandler:handlerKey state:stateKey stateMachine:smName];
		[result setObject:handlerActions forKey:handlerKey];
	}
	
	// Return immutable copy.
	return [[result copy] autorelease];
}


- (NSArray *) cleanActions:(NSArray *)actions forHandler:(NSString *)handlerKey state:(NSString *)stateKey stateMachine:(NSString *)smName
{
	NSString				*action = nil;
	NSRange					spaceRange;
	NSString				*selector = nil;
	id						aliasedSelector = nil;
	NSMutableArray			*result = nil;
	static NSSet			*whitelist = nil;
	static NSDictionary		*aliases = nil;
	NSArray					*whitelistArray1 = nil;
	NSArray					*whitelistArray2 = nil;
	
	if (whitelist == nil)
	{
		whitelistArray1 = oo::PListView([ResourceManager whitelistDictionary]).get<NSArray *>(@"ai_methods");
		if (whitelistArray1 == nil)  whitelistArray1 = [NSArray array];
		whitelistArray2 = oo::PListView([ResourceManager whitelistDictionary]).get<NSArray *>(@"ai_and_action_methods");
		if (whitelistArray2 != nil)  whitelistArray1 = [whitelistArray1 arrayByAddingObjectsFromArray:whitelistArray2];
		
		whitelist = [[NSSet alloc] initWithArray:whitelistArray1];
		aliases = [oo::PListView([ResourceManager whitelistDictionary]).get<NSDictionary *>(@"ai_method_aliases") retain];
	}
	
	result = [NSMutableArray arrayWithCapacity:[actions count]];
	foreach (action, actions)
	{
		if (![action isKindOfClass:[NSString class]])
		{
			OOLogWARN(@"ai.invalidFormat.action", @"An action in handler \"%@\" for state \"%@\" in AI \"%@\" is not a string, ignoring.", handlerKey, stateKey, smName);
			continue;
		}
		
		// Trim spaces from beginning and end.
		action = [action stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		// Cut off parameters.
		spaceRange = [action rangeOfString:@" "];
		if (spaceRange.location == NSNotFound)  selector = action;
		else  selector = [action substringToIndex:spaceRange.location];
		
		// Look in alias table.
		aliasedSelector = [aliases objectForKey:selector];
		if (aliasedSelector != nil)
		{
			if ([aliasedSelector isKindOfClass:[NSString class]])
			{
				// Change selector and action to use real method name.
				selector = aliasedSelector;
				if (spaceRange.location == NSNotFound)  action = aliasedSelector;
				else action = [aliasedSelector stringByAppendingString:[action substringFromIndex:spaceRange.location]];
			}
			else if ([aliasedSelector isKindOfClass:[NSArray class]] && [aliasedSelector count] != 0)
			{
				// Alias is complete expression, pretokenized in anticipation of a tokenized future.
				action = [aliasedSelector componentsJoinedByString:@" "];
				selector = [[aliasedSelector objectAtIndex:0] description];
			}
		}
		
		// Check for selector in whitelist.
		if (![whitelist containsObject:selector])
		{
			OOLog(@"ai.unpermittedMethod", @"Handler \"%@\" for state \"%@\" in AI \"%@\" uses \"%@\", which is not a permitted AI method.", handlerKey, stateKey, smName, selector);
			continue;
		}
		
		[result addObject:action];
	}
	
	// Return immutable copy.
	return [[result copy] autorelease];
}

@end


@implementation OOPreservedAIStateMachine

- (id) initWithStateMachine:(NSDictionary *)stateMachine
					   name:(NSString *)name
					  state:(NSString *)state
			pendingMessages:(NSSet *)pendingMessages
									 jsScript:(NSString *)script
{
	if ((self = [super init]))
	{
		_stateMachine = [stateMachine copy];
		_name = [name copy];
		_state = [state copy];
		_pendingMessages = [pendingMessages copy];
		_jsScript = [script copy];
	}
	
	return self;
}


- (void) dealloc
{
	[_stateMachine autorelease];
	[_name autorelease];
	[_state autorelease];
	[_pendingMessages autorelease];
	[_jsScript autorelease];
	
	[super dealloc];
}


- (NSDictionary *) stateMachine
{
	return _stateMachine;
}


- (NSString *) name
{
	return _name;
}


- (NSString *) state
{
	return _state;
}


- (NSSet *) pendingMessages
{
	return _pendingMessages;
}

- (NSString *) jsScript
{
	return _jsScript;
}

@end
