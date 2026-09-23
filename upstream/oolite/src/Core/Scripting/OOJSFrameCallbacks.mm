/*

OOJSFrameCallbacks.m


Copyright (C) 2011-2013 Jens Ayton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

#import "OOJSFrameCallbacks.h"
#import "OOJSEngineTimeManagement.h"
#import "OOPListView.h"
#include "oofnd/Date.hpp"


/*
	By default, tracking IDs are scrambled to discourage people from trying to
	be clever or making assumptions about them. If DEBUG_FCB_SIMPLE_TRACKING_IDS
	is non-zero, tracking IDs starting from 1 and rising monotonously are used
	instead. Additionally, the next ID is reset to 1 when all frame callbacks
	are removed.
*/
#ifndef DEBUG_FCB_SIMPLE_TRACKING_IDS
#define DEBUG_FCB_SIMPLE_TRACKING_IDS	0
#endif

#ifndef DEBUG_FCB_VERBOSE_LOGGING
#define DEBUG_FCB_VERBOSE_LOGGING		0
#endif



#if defined (NDEBUG) && DEBUG_FCB_SIMPLE_TRACKING_IDS
#error Deployment builds may not be built with DEBUG_FCB_SIMPLE_TRACKING_IDS.
#endif

#if DEBUG_FCB_VERBOSE_LOGGING
#define FCBLog					OOLog
#define FCBLogIndentIf			OOLogIndentIf
#define FCBLogOutdentIf			OOLogOutdentIf
#else
#define FCBLog(...)				do {} while (0)
#define FCBLogIndentIf(key)		do {} while (0)
#define FCBLogOutdentIf(key)	do {} while (0)
#endif


enum
{
	kMinCount					= 16,
	
#if DEBUG_FCB_SIMPLE_TRACKING_IDS
	kIDScrambleMask				= 0,
	kIDIncrement				= 1
#else
	kIDScrambleMask				= 0x2315EB16,	// Just a random number.
	kIDIncrement				= 992699		// A large prime number, to produce a non-obvious sequence which still uses all 2^32 values.
#endif
};


typedef struct
{
	ooscript::Value					callback;
	uint32_t					trackingID;
	uint32_t					_padding;
} CallbackEntry;


static CallbackEntry	*sCallbacks;
static NSUInteger		sCount;			// Number of slots in use.
static NSUInteger		sSpace;			// Number of slots allocated.
static NSUInteger		sHighWaterMark;	// Number of slots which are GC roots.
static NSMutableArray	*sDeferredOps;	// Deferred adds/removes while running.
static uint32_t			sNextID;
static BOOL				sRunning;


// Methods
static bool GlobalAddFrameCallback(ooscript::Context context, ooscript::CallArgs &oojsArgs);
static bool GlobalRemoveFrameCallback(ooscript::Context context, ooscript::CallArgs &oojsArgs);
static bool GlobalIsValidFrameCallback(ooscript::Context context, ooscript::CallArgs &oojsArgs);


// Internals
static BOOL AddCallback(ooscript::Context context, ooscript::Value callback, uint32_t trackingID, NSString **errorString);
static BOOL GrowCallbackList(ooscript::Context context, NSString **errorString);

static BOOL GetIndexForTrackingID(uint32_t trackingID, NSUInteger *outIndex);

static BOOL RemoveCallbackWithTrackingID(ooscript::Context context, uint32_t trackingID);
static void RemoveCallbackAtIndex(ooscript::Context context, NSUInteger index);

static void QueueDeferredOperation(NSString *opType, uint32_t trackingID, OOJSValue *value);
static void RunDeferredOperations(ooscript::Context context);


// MARK: Public

void InitOOJSFrameCallbacks(ooscript::Context context, ooscript::Object global)
{
	ooscript::defineFunction(context, global, "addFrameCallback", GlobalAddFrameCallback, 1, OOJS_METHOD_READONLY);
	ooscript::defineFunction(context, global, "removeFrameCallback", GlobalRemoveFrameCallback, 1, OOJS_METHOD_READONLY);
	ooscript::defineFunction(context, global, "isValidFrameCallback", GlobalIsValidFrameCallback, 1, OOJS_METHOD_READONLY);
	
#if DEBUG_FCB_SIMPLE_TRACKING_IDS
	sNextID = 1;
#else
	// Set randomish initial ID to catch bad habits.
	sNextID =  oo::date::timeIntervalSinceReferenceDate();
#endif
}


void OOJSFrameCallbacksInvoke(OOTimeDelta inDeltaT)
{
	NSCAssert1(!sRunning, @"%s cannot be called while frame callbacks are running.", __PRETTY_FUNCTION__);
	
	if (sCount != 0)
	{
		const OOTimeDelta	delta = inDeltaT * [UNIVERSE timeAccelerationFactor];
		ooscript::Context context = OOJSAcquireContext();
		ooscript::Value				deltaVal, result;
		NSUInteger			i;
		
		if (EXPECT(ooscript::newNumberValue(context, delta, &deltaVal)))
		{
			// Block mutations.
			sRunning = YES;
			
			/*
				The watchdog timer only fires once per second in deployment builds,
				but in testrelease builds at least we can keep them on a short leash.
			*/
			OOJSStartTimeLimiterWithTimeLimit(0.1);
			
			for (i = 0; i < sCount; i++)
			{
				// TODO: remove out of scope callbacks - post MNSR!
				ooscript::callFunctionValue(context, NULL, sCallbacks[i].callback, 1, &deltaVal, &result);
				ooscript::reportPendingException(context);
			}
			
			OOJSStopTimeLimiter();
			sRunning = NO;
			
			if (EXPECT_NOT(sDeferredOps != NULL))
			{
				RunDeferredOperations(context);
				DESTROY(sDeferredOps);
			}
		}
		OOJSRelinquishContext(context);
	}
}


void OOJSFrameCallbacksRemoveAll(void)
{
	NSCAssert1(!sRunning, @"%s cannot be called while frame callbacks are running.", __PRETTY_FUNCTION__);
	
	if (sCount != 0)
	{
		ooscript::Context context = OOJSAcquireContext();
		while (sCount != 0)  RemoveCallbackAtIndex(context, sCount - 1);
		OOJSRelinquishContext(context);
	}
}


// MARK: Methods

// addFrameCallback(callback : Function) : Number
static bool GlobalAddFrameCallback(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	// Get callback argument and verify that it's a function.
	ooscript::Value callback = OOJS_ARGV[0];
	if (EXPECT_NOT(oojsArgs.count() < 1 || !OOJSValueIsFunction(context, callback)))
	{
		OOJSReportBadArguments(context, nil, @"addFrameCallback", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"function");
		return NO;
	}
	
	// Assign a tracking ID.
	uint32_t trackingID = sNextID ^ kIDScrambleMask;
	sNextID += kIDIncrement;
	
	if (EXPECT(!sRunning))
	{
		// Add to list immediately.
		NSString *errorString = nil;
		if (EXPECT_NOT(!AddCallback(context, callback, trackingID, &errorString)))
		{
			OOJSReportError(context, @"%@", errorString);
			return NO;
		}
	}
	else
	{
		// Defer mutations during callback invocation.
		FCBLog(@"script.frameCallback.debug.add.deferred", @"Deferring addition of frame callback with tracking ID %u.", trackingID);
		QueueDeferredOperation(@"add", trackingID, [OOJSValue valueWithJSValue:callback inContext:context]);
	}
	
	OOJS_RETURN_INT(trackingID);
	
	OOJS_NATIVE_EXIT
}


// removeFrameCallback(trackingID : Number)
static bool GlobalRemoveFrameCallback(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	// Get tracking ID argument.
	uint32_t trackingID;
	if (EXPECT_NOT(oojsArgs.count() < 1 || !ooscript::valueToECMAUint32(context, OOJS_ARGV[0], &trackingID)))
	{
		OOJSReportBadArguments(context, nil, @"removeFrameCallback", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"frame callback tracking ID");
		return NO;
	}
	
	if (EXPECT(!sRunning))
	{
		// Remove it.
		if (EXPECT_NOT(!RemoveCallbackWithTrackingID(context, trackingID)))
		{
			OOJSReportWarning(context, @"removeFrameCallback(): invalid tracking ID.");
		}
	}
	else
	{
		// Defer mutations during callback invocation.
		FCBLog(@"script.frameCallback.debug.remove.deferred", @"Deferring removal of frame callback with tracking ID %u.", trackingID);
		QueueDeferredOperation(@"remove", trackingID, nil);
	}
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}


// isValidFrameCallback(trackingID : Number)
static bool GlobalIsValidFrameCallback(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(oojsArgs.count() < 1))
	{
		OOJSReportBadArguments(context, nil, @"isValidFrameCallback", 0, OOJS_ARGV, nil, @"frame callback tracking ID");
		return NO;
	}
	
	// Get tracking ID argument.
	uint32_t trackingID;
	if (EXPECT_NOT(!ooscript::valueToECMAUint32(context, OOJS_ARGV[0], &trackingID)))
	{
		OOJS_RETURN_BOOL(NO);
	}
	
	NSUInteger index;
	OOJS_RETURN_BOOL(GetIndexForTrackingID(trackingID, &index));
	
	OOJS_NATIVE_EXIT
}


// MARK: Internals

static BOOL AddCallback(ooscript::Context context, ooscript::Value callback, uint32_t trackingID, NSString **errorString)
{
	NSCParameterAssert(context != NULL && ooscript::isInRequest(context));
	NSCParameterAssert(errorString != NULL);
	NSCAssert1(!sRunning, @"%s cannot be called while frame callbacks are running.", __PRETTY_FUNCTION__);
	
	if (EXPECT_NOT(sCount == sSpace))
	{
		if (!GrowCallbackList(context, errorString))  return NO;
	}
	
	FCBLog(@"script.frameCallback.debug.add", @"Adding frame callback with tracking ID %u.", trackingID);
	
	sCallbacks[sCount].callback = callback;
	if (sCount >= sHighWaterMark)
	{
		// If we haven't used this slot before, root it.
		
		if (EXPECT_NOT(!OOJSAddGCValueRoot(context, &sCallbacks[sCount].callback, "frame callback")))
		{
			*errorString = @"Failed to add GC root for frame callback.";
			return NO;
		}
		
		sHighWaterMark = sCount + 1;
	}
	
	sCallbacks[sCount].trackingID = trackingID;
	sCount++;
	
	return YES;
}


static BOOL GrowCallbackList(ooscript::Context context, NSString **errorString)
{
	NSCParameterAssert(context != NULL && ooscript::isInRequest(context));
	NSCParameterAssert(errorString != NULL);
	
	NSUInteger newSpace = MAX(sSpace * 2, (NSUInteger)kMinCount);
	
	CallbackEntry *newCallbacks = (CallbackEntry *)calloc(sizeof (CallbackEntry), newSpace);
	if (newCallbacks == NULL)  return NO;
	
	CallbackEntry *oldCallbacks = sCallbacks;
	
	// Root and copy occupied slots.
	NSUInteger newHighWaterMark = sCount;
	NSUInteger i;
	for (i = 0; i < newHighWaterMark; i++)
	{
		if (EXPECT_NOT(!OOJSAddGCValueRoot(context, &newCallbacks[i].callback, "frame callback")))
		{
			// If we can't root them all, we fail; unroot all entries to date, free the buffer and return NO.
			NSUInteger j;
			for (j = 0; j < i; j++)
			{
				ooscript::removeValueRoot(context, &newCallbacks[j].callback);
			}
			free(newCallbacks);
			
			*errorString = @"Failed to add GC root for frame callback.";
			return NO;
		}
		newCallbacks[i] = oldCallbacks[i];
	}
	
	// Unroot old array's slots.
	for (i = 0; i < sHighWaterMark; i++)
	{
		ooscript::removeValueRoot(context, &oldCallbacks[i].callback);
	}
	
	// We only rooted the occupied slots, so reset high water mark.
	sHighWaterMark = newHighWaterMark;
	
	// Replace array.
	sCallbacks = newCallbacks;
	free(oldCallbacks);
	sSpace = newSpace;
	
	return YES;
}


static BOOL GetIndexForTrackingID(uint32_t trackingID, NSUInteger *outIndex)
{
	NSCParameterAssert(outIndex != NULL);
	
	/*	It is assumed that few frame callbacks will be active at once, so a
		linear search is reasonable. If they become unexpectedly popular, we
		can switch to a sorted list or a separate lookup table without changing
		the API.
	*/
	NSUInteger i;
	for (i = 0; i < sCount; i++)
	{
		if (sCallbacks[i].trackingID == trackingID)
		{
			*outIndex = i;
			return YES;
		}
	}
	
	return NO;
}


static BOOL RemoveCallbackWithTrackingID(ooscript::Context context, uint32_t trackingID)
{
	NSCParameterAssert(context != NULL && ooscript::isInRequest(context));
	NSCAssert1(!sRunning, @"%s cannot be called while frame callbacks are running.", __PRETTY_FUNCTION__);
	
	NSUInteger index = 0;
	if (GetIndexForTrackingID(trackingID, &index))
	{
		RemoveCallbackAtIndex(context, index);
		return YES;
	}
	
	return NO;
}


static void RemoveCallbackAtIndex(ooscript::Context context, NSUInteger index)
{
	NSCParameterAssert(context != NULL && ooscript::isInRequest(context));
	NSCParameterAssert(index < sCount && sCallbacks != NULL);
	NSCAssert1(!sRunning, @"%s cannot be called while frame callbacks are running.", __PRETTY_FUNCTION__);
	
	FCBLog(@"script.frameCallback.debug.remove", @"Removing frame callback with tracking ID %u.", sCallbacks[index].trackingID);
	
	// Overwrite entry to be removed with last entry, and decrement count.
	sCount--;
	sCallbacks[index] = sCallbacks[sCount];
	sCallbacks[sCount].callback = ooscript::nullValue();
	
#if DEBUG_FCB_SIMPLE_TRACKING_IDS
	if (sCount == 0)
	{
		OOLog(@"script.frameCallback.debug.reset", @"All frame callbacks removed, resetting next ID to 1.");
		sNextID = 1;
	}
#endif
}


static void QueueDeferredOperation(NSString *opType, uint32_t trackingID, OOJSValue *value)
{
	NSCAssert1(sRunning, @"%s can only be called while frame callbacks are running.", __PRETTY_FUNCTION__);
	
	if (sDeferredOps == nil)  sDeferredOps = [[NSMutableArray alloc] init];
	[sDeferredOps addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							 opType, @"operation",
							 [NSNumber numberWithInt:trackingID], @"trackingID",
							 value, @"value",
							 nil]];
}


static void RunDeferredOperations(ooscript::Context context)
{
	NSDictionary		*operation = nil;
	
	FCBLog(@"script.frameCallback.debug.run-deferred", @"Running %zu deferred frame callback operations.", (long)[sDeferredOps count]);
	FCBLogIndentIf(@"script.frameCallback.debug.run-deferred");
	
	foreach (operation, sDeferredOps)
	{
		NSString	*opType = [operation objectForKey:@"operation"];
		uint32_t		trackingID = oo::PListView(operation).get<int>(@"trackingID");
		
		if ([opType isEqualToString:@"add"])
		{
			OOJSValue	*callbackObj = [operation objectForKey:@"value"];
			NSString	*errorString = nil;
			
			if (!AddCallback(context, OOJSValueFromNativeObject(context, callbackObj), trackingID, &errorString))
			{
				OOLogWARN(@"script.frameCallback.deferredAdd.failed", @"Deferred frame callback insertion failed: %@", errorString);
			}
		}
		else if ([opType isEqualToString:@"remove"])
		{
			RemoveCallbackWithTrackingID(context, trackingID);
		}
	}
	
	FCBLogOutdentIf(@"script.frameCallback.debug.run-deferred");
}
