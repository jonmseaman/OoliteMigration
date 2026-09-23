/*

OOJSTimer.mm


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

#import "OOJSTimer.h"
#import "OOJavaScriptEngine.h"
#import "Universe.h"

#include "ooscript/JSEngine.hpp"
#include "oofnd/Notification.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar): the class dispatch table becomes a static ooscript::ClassDef
	(the stub hooks are nullptr), the engine's InitClass call becomes ooscript::initClass, and
	the directly spelled engine calls (NewObject, SetPrivate, GetPrivate, RemoveObjectRoot,
	RemoveValueRoot, ValueToObject, ValueToFunction, GetFunctionId, IsConstructing,
	ValueToNumber, NewNumberValue) go through ooscript:: instead. `this` is renamed to `thisObj`
	because it is a reserved word once this file compiles as Objective-C++ (ADR-0001).

	OOJSAddGCObjectRoot, OOJSAddGCValueRoot, OOJSAcquireContext and OOJSRelinquishContext are
	OOJS_* macros, not directly spelled engine calls, so they are untouched and out of scope for
	this bead (see JSEngine.hpp's own header comment and OOJSVector.mm's exemplar comment); the
	same is true of the OOJS_ARGV, OOJS_THIS, OOJS_RETURN_ family and OOJS_NATIVE_ENTER.

	Because ooscript::ClassDef, unlike the engine's old plain-C class struct, does not tolerate the old file's
	"forward-declared-then-defined" tentative-definition trick under Objective-C++'s stricter
	one-definition rule, sTimerClass's forward-declared consumer (-initWithDelay:...) is placed
	after the ClassDef's single full definition, so the whole file is reordered relative to the
	old .m layout: forward declarations, the ClassDef and its spec tables come first, then the
	OOJSTimer Objective-C implementation, then InitOOJSTimer() and the native hook bodies.

	toString() is the shared native OOJSObjectWrapperToString (OOJavaScriptEngine.mm), which
	takes the façade's NativeFn signature, and DEFINE_JS_OBJECT_GETTER() and
	OOJSRegisterObjectConverter() are given &sTimerClass itself.
*/

namespace ooscript { }
using ooscript::Context;
using ooscript::Object;
using ooscript::Value;
using ooscript::PropertyId;
using ooscript::CallArgs;
using ooscript::ClassDef;
using ooscript::ClassFlag;
using ooscript::PropertyFlag;
using ooscript::PropertySpec;
using ooscript::FunctionSpec;

// Minimum allowable interval for repeating timers.
#define kMinInterval 0.25


namespace {
static ooscript::Object sTimerPrototype;
} // namespace


namespace {
static bool TimerGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool TimerSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace
namespace {
static void TimerFinalize(Context cx, Object obj);
} // namespace
namespace {
static bool TimerConstruct(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace

// Methods
namespace {
static bool TimerStart(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool TimerStop(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace


namespace {
static ClassDef sTimerClass =
{
	"Timer",
	ClassFlag::HasPrivate,
	
	nullptr,				// addProperty (engine default: PropertyStub)
	nullptr,				// delProperty (engine default: PropertyStub)
	TimerGetProperty,		// getProperty
	TimerSetProperty,		// setProperty
	nullptr,				// enumerate (engine default: EnumerateStub)
	nullptr,				// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,				// resolve (engine default: ResolveStub)
	nullptr,				// convert (engine default: ConvertStub)
	TimerFinalize,			// finalize
	nullptr,				// call
	nullptr,				// construct
	nullptr,				// backend: owned by the façade backend, must start null
};
} // namespace


enum : std::uint8_t
{
	// Property IDs
	kTimer_nextTime,			// next fire time, double, read/write
	kTimer_interval,			// interval, double, read/write
	kTimer_isRunning			// is scheduled, boolean, read-only
};


namespace {
static PropertySpec sTimerProperties[] =
{
	// JS name					ID						flags																getter		setter
	{ "interval",				kTimer_interval,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,								nullptr, nullptr },
	{ "isRunning",				kTimer_isRunning,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared,	nullptr, nullptr },
	{ "nextTime",				kTimer_nextTime,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,								nullptr, nullptr },
	{ 0 }
};
} // namespace

// A mirror of sTimerProperties with the read-only/read-write flags the two bad-property error
// reporters in OOJavaScriptEngine.mm (OOJSReportBadPropertySelector/Value) describe the
// properties by (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static ooscript::PropertySpec sTimerPropertiesRaw[] =
{
	{ "interval",				kTimer_interval,		OOJS_PROP_READWRITE_CB },
	{ "isRunning",				kTimer_isRunning,		OOJS_PROP_READONLY_CB },
	{ "nextTime",				kTimer_nextTime,		OOJS_PROP_READWRITE_CB },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sTimerMethods[] =
{
	// JS name					Function					min args	flags
	{ "toString",				OOJSObjectWrapperToString,	0,			0 },
	{ "start",					TimerStart,					0,			0 },
	{ "stop",					TimerStop,					0,			0 },
	{ 0 }
};
} // namespace


namespace {
DEFINE_JS_OBJECT_GETTER(JSTimerGetTimer, &sTimerClass, sTimerPrototype, OOJSTimer);
} // namespace


@interface OOJSTimer (Private)

- (id) initWithDelay:(OOTimeAbsolute)delay
			interval:(OOTimeDelta)interval
			 context:(ooscript::Context)context
			function:(ooscript::Value)function
				this:(ooscript::Object)jsThis;

@end


@implementation OOJSTimer

- (id) initWithDelay:(OOTimeAbsolute)delay
			interval:(OOTimeDelta)interval
			 context:(ooscript::Context)context
			function:(ooscript::Value)function
				this:(ooscript::Object)jsThis
{
	self = [super initWithNextTime:[UNIVERSE getTime] + delay interval:interval];
	if (self != nil)
	{
		NSAssert(OOJSValueIsFunction(context, function), @"Attempt to init OOJSTimer with a function that isn't.");
		
		_jsThis = jsThis;
		OOJSAddGCObjectRoot(context, &_jsThis, "OOJSTimer this");
		
		_function = function;
		OOJSAddGCValueRoot(context, &_function, "OOJSTimer function");
		
		_jsSelf = (ooscript::newObject((context), &sTimerClass, (sTimerPrototype), nullptr));
		if (_jsSelf != NULL)
		{
			if (!ooscript::setPrivate((context), (_jsSelf), [self retain]))  _jsSelf = NULL;
		}
		if (_jsSelf == NULL)
		{
			[self release];
			return nil;
		}
		
		_owningScript = [[OOJSScript currentlyRunningScript] weakRetain];
		
		oo::NotificationCenter::defaultCenter().addObserver(self, kOOJavaScriptEngineWillResetNotificationName,
															[OOJavaScriptEngine sharedEngine],
															[self](const oo::Notification &) { [self deleteJSPointers]; });
	}
	
	return self;
}


- (void) deleteJSPointers
{
	[self unscheduleTimer];
	
	if (_jsThis != NULL)
	{
		_jsThis = NULL;
		_function = ooscript::undefinedValue();
		
		ooscript::Context context = OOJSAcquireContext();
		ooscript::removeObjectRoot((context), &_jsThis);
		ooscript::removeValueRoot((context), (&_function));
		OOJSRelinquishContext(context);
		
		oo::NotificationCenter::defaultCenter().removeObserver(self, kOOJavaScriptEngineWillResetNotificationName,
																[OOJavaScriptEngine sharedEngine]);
	}
}


- (void) dealloc
{
	[_owningScript release];
	
	[self deleteJSPointers];
	
	[super dealloc];
}


- (NSString *) descriptionComponents
{
	NSString				*funcName = nil;
	ooscript::Context context = NULL;
	
	if (ooscript::isUndefined(_function) || ooscript::isNull(_function))
	{
		return @"invalid";
	}
	
	context = OOJSAcquireContext();
	funcName = OOStringFromJSString(context, (ooscript::getFunctionId(ooscript::valueToFunction((context), (_function)))));
	OOJSRelinquishContext(context);
	
	if (funcName == nil)
	{
		funcName = @"anonymous";
	}
	
	return [NSString stringWithFormat:@"%@, function: %@", [super descriptionComponents], funcName];
}


- (NSString *) oo_jsClassName
{
	return @"Timer";
}


- (void) timerFired
{
	ooscript::Value					rval = ooscript::undefinedValue();
	NSString				*description = nil;
	
	OOJavaScriptEngine *engine = [OOJavaScriptEngine sharedEngine];
	ooscript::Context context = OOJSAcquireContext();
	
	// stop and remove the timer if _jsThis (the first parameter in the constructor) dies.
	id object = OOJSNativeObjectFromJSObject(context, _jsThis);
	if (object != nil)
	{
		description = [object oo_jsDescription];
		if (description == nil)  description = [object description];
	}
	
	if (description == nil)
	{
		[self unscheduleTimer];
		OOJSRelinquishContext(context);
		return;
	}
	
	[OOJSScript pushScript:_owningScript];
	[engine callJSFunction:_function
				 forObject:_jsThis
					  argc:0
					  argv:NULL
					result:&rval];
	[OOJSScript popScript:_owningScript];
	
	OOJSRelinquishContext(context);
}


- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context
{
	return ooscript::objectValue(_jsSelf);
}

@end


void InitOOJSTimer(ooscript::Context context, ooscript::Object global)
{
	Object proto = ooscript::initClass((context), (global), nullptr, &sTimerClass, TimerConstruct, 0, sTimerProperties, sTimerMethods, nullptr, nullptr);
	sTimerPrototype = (proto);
	OOJSRegisterObjectConverter(&sTimerClass, OOJSBasicPrivateObjectConverter);
}


namespace {
static bool TimerGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	
	OOJS_NATIVE_ENTER(context)
	
	OOJSTimer				*timer = nil;
	
	if (EXPECT_NOT(!JSTimerGetTimer(context, thisObj, &timer))) return NO;
	
	switch (ooscript::idToInt32(propID))
	{
		case kTimer_nextTime:
			return ooscript::newNumberValue(cx, [timer nextTime], value);
			
		case kTimer_interval:
			return ooscript::newNumberValue(cx, [timer interval], value);
			
		case kTimer_isRunning:
			*value = (OOJSValueFromBOOL([timer isScheduled]));
			return YES;
			
		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sTimerPropertiesRaw);
			return NO;
	}
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool TimerSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	
	OOJS_NATIVE_ENTER(context)
	
	OOJSTimer				*timer = nil;
	double					fValue;
	
	if (EXPECT_NOT(!JSTimerGetTimer(context, thisObj, &timer))) return NO;
	
	switch (ooscript::idToInt32(propID))
	{
		case kTimer_nextTime:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				if (![timer setNextTime:fValue])
				{
					OOJSReportWarning(context, @"Ignoring attempt to change next fire time for running timer %@.", timer);
				}
				return YES;
			}
			break;
			
		case kTimer_interval:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				[timer setInterval:fValue];
				return YES;
			}
			break;
			
		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sTimerPropertiesRaw);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, (propID), sTimerPropertiesRaw, *(value));
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static void TimerFinalize(Context cx, Object obj)
{
	OOJS_PROFILE_ENTER
	
	// Can't use JSTimerGetTimer() here - potential chicken-and-egg problem manifesting as a crash.
	OOJSTimer *timer = (OOJSTimer *)ooscript::getPrivate(cx, obj);
	
	if (timer != nil)
	{
		if ([timer isScheduled])
		{
			OOLogWARN(@"script.javaScript.unrootedTimer", @"Timer %@ is being garbage-collected while still running. You must keep a reference to all running timers, or they will stop unpredictably!", timer);
		}
		[timer release];
		ooscript::setPrivate(cx, obj, NULL);
	}
	
	OOJS_PROFILE_EXIT_VOID
}
} // namespace


// new Timer(this : Object, function : Function, delay : Number [, interval : Number]) : Timer
namespace {
static bool TimerConstruct(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	ooscript::Value					function = ooscript::undefinedValue();
	double					delay;
	double					interval = -1.0;
	OOJSTimer				*timer = nil;
	ooscript::Object callbackThis = NULL;
	
	if (EXPECT_NOT(!oojsArgs.isConstructing()))
	{
		OOJSReportError(context, @"Timer() cannot be called as a function, it must be used as a constructor (as in new Timer(...)).");
		return NO;
	}
	
	if (oojsArgs.count() < 3)
	{
		OOJSReportBadArguments(context, nil, @"Timer", oojsArgs.count(), OOJS_ARGV, @"Invalid arguments in constructor", @"(object, function, number [, number])");
		return NO;
	}
	
	if (!ooscript::isNull(OOJS_ARGV[0]) && !ooscript::isUndefined(OOJS_ARGV[0]))
	{
		if (!ooscript::valueToObject(context, (OOJS_ARGV[0]), &callbackThis))
		{
			OOJSReportBadArguments(context, nil, @"Timer", 1, OOJS_ARGV, @"Invalid argument in constructor", @"object");
			return NO;
		}
	}
	
	function = OOJS_ARGV[1];
	if (ooscript::valueToFunction(context, (function)) == nullptr)
	{
		OOJSReportBadArguments(context, nil, @"Timer", 1, OOJS_ARGV + 1, @"Invalid argument in constructor", @"function");
		return NO;
	}
	
	if (!ooscript::valueToNumber(context, (OOJS_ARGV[2]), &delay) || isnan(delay))
	{
		OOJSReportBadArguments(context, nil, @"Timer", 1, OOJS_ARGV + 2, @"Invalid argument in constructor", @"number");
		return NO;
	}
	
	// Fourth argument is optional.
	if (3 < oojsArgs.count() && !ooscript::valueToNumber(context, (OOJS_ARGV[3]), &interval))  interval = -1;
	
	// Ensure interval is not too small.
	if (0.0 < interval && interval < kMinInterval)  interval = kMinInterval;
	
	timer = [[OOJSTimer alloc] initWithDelay:delay
									interval:interval
									 context:context
									function:function
										this:callbackThis];
	if (EXPECT_NOT(!timer))  return NO;
	
	if (delay >= 0)	// Leave in stopped state if delay is negative
	{
		[timer scheduleTimer];
	}
	[timer autorelease];
	OOJS_RETURN_OBJECT(timer);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// *** Methods ***

// start() : Boolean
namespace {
static bool TimerStart(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	OOJSTimer					*thisTimer = nil;
	
	if (EXPECT_NOT(!JSTimerGetTimer(context, OOJS_THIS, &thisTimer)))  return NO;
	
	OOJS_RETURN_BOOL([thisTimer scheduleTimer]);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// stop()
namespace {
static bool TimerStop(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	OOJSTimer					*thisTimer = nil;
	
	if (EXPECT_NOT(!JSTimerGetTimer(context, OOJS_THIS, &thisTimer)))  return NO;
	
	[thisTimer unscheduleTimer];
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace
