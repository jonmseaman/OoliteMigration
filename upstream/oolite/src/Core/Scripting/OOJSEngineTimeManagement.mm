/*

OOJSEngineTimeManagement.h


Copyright (C) 2010-2013 Jens Ayton

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

#import "OOJSEngineTimeManagement.h"
#import "OOProfilingStopwatch.h"
#import "OOJSScript.h"
#import "OOCollectionExtractors.h"
#import "OOLoggingExtended.h"
#import "OOFoundationBridge.h"
#include "oofnd/StdLib.hpp"
#include "oofnd/Thread.hpp"

#if OOLITE_LINUX
// Workaround for clang/glibc incompatibility.
#ifdef __block
#undef __block
#endif
#define __block __glibc_block
#endif
#include <unistd.h>

#if OOLITE_LINUX
#undef __block
#endif


#if OO_DEBUG
#define OOJS_DEBUG_LIMITER	1
#else
#define OOJS_DEBUG_LIMITER	0
#endif


static unsigned sLimiterStartDepth;
static int sLimiterPauseDepth;
static OOHighResTimeValue sLimiterStart;
static OOHighResTimeValue sLimiterPauseStart;
static double sLimiterTimeLimit;


#if OOJS_DEBUG_LIMITER
#define OOJS_TIME_LIMIT		(0.2)	// seconds
#else
#define OOJS_TIME_LIMIT		(1)	// seconds
#endif

static BOOL sStop;

#ifndef NDEBUG
static const char *sLastStartedFile;
static unsigned sLastStartedLine;
static const char *sLastStoppedFile;
static unsigned sLastStoppedLine;
#endif


#if OOJS_PROFILE && defined(MOZ_TRACE_JSCALLS)
static void FunctionCallback(ooscript::Function function, ooscript::Script script, ooscript::Context context, int entering);
#endif


#ifndef NDEBUG
void OOJSStartTimeLimiterWithTimeLimit_(OOTimeDelta limit, const char *file, unsigned line)
#else
void OOJSStartTimeLimiterWithTimeLimit(OOTimeDelta limit)
#endif
{
#if OOJS_DEBUG_LIMITER
	OOLog(@"script.javaScript.timeLimit.debug",@"Limiter starting: %u => %u",sLimiterStartDepth,sLimiterStartDepth+1);
#endif
	if (sLimiterStartDepth++ == 0)
	{
		if (limit <= 0.0)  limit = OOJS_TIME_LIMIT;
		sLimiterTimeLimit = limit;
		sLimiterPauseDepth = 0;
		
		OODisposeHighResTime(sLimiterStart);
		sLimiterStart = OOGetHighResTime();
	}
	
#ifndef NDEBUG
	sLastStartedFile = file;
	sLastStartedLine = line;
#endif
}


#ifndef NDEBUG
void OOJSStopTimeLimiter_(const char *file, unsigned line)
#else
void OOJSStopTimeLimiter(void)
#endif
{
#ifndef NDEBUG
	if (sLimiterStartDepth == 0)
	{
		OOLog(@"bug.javaScript.limiterDepth", @"Attempt to stop JavaScript time limiter while it is already fully stopped. This is an internal bug, please report it. (Last start: %@:%u, last valid stop: %@:%u, this stop attempt: %@:%u.)", OOLogAbbreviatedFileName(sLastStartedFile), sLastStartedLine, OOLogAbbreviatedFileName(sLastStoppedFile), sLastStoppedLine, OOLogAbbreviatedFileName(file), line);
		return;
	}
	
	sLastStoppedFile = file;
	sLastStoppedLine = line;

#if OOJS_DEBUG_LIMITER
	OOLog(@"script.javaScript.timeLimit.debug",@"Limiter ending: %u <= %u",sLimiterStartDepth-1,sLimiterStartDepth);
#endif

#endif
	
	if (--sLimiterStartDepth == 0)  sLimiterTimeLimit = 0.0;
}


void OOJSPauseTimeLimiter(void)
{
	if (sLimiterPauseDepth++ == 0)
	{
		OODisposeHighResTime(sLimiterPauseStart);
		sLimiterPauseStart = OOGetHighResTime();
	}
}


void OOJSResumeTimeLimiter(void)
{
	if (--sLimiterPauseDepth == 0)
		
	{
		OOHighResTimeValue now = OOGetHighResTime();
		OOTimeDelta elapsed = OOHighResTimeDeltaInSeconds(sLimiterPauseStart, now);
		OODisposeHighResTime(now);
		
		sLimiterTimeLimit += elapsed;
	}
}


#ifndef NDEBUG
OOHighResTimeValue OOJSCopyTimeLimiterNominalStartTime(void)
{
	return sLimiterStart;
}


void OOJSResetTimeLimiter(void)
{
	OODisposeHighResTime(sLimiterStart);
	sLimiterStart = OOGetHighResTime();
	
	sStop = NO;
}


OOTimeDelta OOJSGetTimeLimiterLimit(void)
{
	return sLimiterTimeLimit;
}


void OOJSSetTimeLimiterLimit(OOTimeDelta limit)
{
	sLimiterTimeLimit = limit;
}
#endif


@implementation OOJavaScriptEngine (WatchdogTimer)

- (void) watchdogTimerThread
{
	for (;;)
	{
#if OOLITE_WINDOWS
		Sleep(OOJS_TIME_LIMIT * 1000);
#else
		usleep(OOJS_TIME_LIMIT * 1000000);
#endif
		
		if (EXPECT(sLimiterStartDepth == 0 || sLimiterPauseDepth > 0))  continue;	// Most of the time, a script isn't running.
		
		// Note: if you add logging here, you need a manual autorelease pool.
		
		OOHighResTimeValue now = OOGetHighResTime();
		OOTimeDelta elapsed = OOHighResTimeDeltaInSeconds(sLimiterStart, now);
		OODisposeHighResTime(now);
		
		if (EXPECT_NOT(elapsed > sLimiterTimeLimit))
		{
			sStop = YES;
			ooscript::triggerAllOperationCallbacks(_runtime);
		}
	}
}

@end


static bool OperationCallback(ooscript::Context context)
{
	if (!sStop)  return YES;
	
    ooscript::clearPendingException(context);
	
	OOHighResTimeValue now = OOGetHighResTime();
	OOTimeDelta elapsed = OOHighResTimeDeltaInSeconds(sLimiterStart, now);
	OODisposeHighResTime(now);
	
	if (elapsed <= sLimiterTimeLimit)  return YES;
	
	OOLogERR(@"script.javaScript.timeLimit", @"Script \"%@\" ran for %g seconds and has been terminated.", [[OOJSScript currentlyRunningScript] name], elapsed);
#ifndef NDEBUG
	OOJSDumpStack(context);
#endif
	
	// FIXME: we really should put something in the JS log here, but since that's implemented in JS there are complications.
	
	return NO;
}


static bool ContextCallback(ooscript::Context context, ooscript::ContextOp contextOp)
{
	if (contextOp == ooscript::ContextOp::New)
	{
		ooscript::setOperationCallback(context, OperationCallback);
		
#if OOJS_PROFILE && defined(MOZ_TRACE_JSCALLS)
		ooscript::setFunctionCallback(context, FunctionCallback);
#endif
	}
	return YES;
}


void OOJSTimeManagementInit(OOJavaScriptEngine *engine, ooscript::Runtime runtime)
{
	// The watchdog holds the engine for its (endless) life, as a detached selector thread did.
	[engine retain];
	oo::thread::detach([engine]()
	{
		@autoreleasepool
		{
			[engine watchdogTimerThread];
		}
		[engine release];
	});
	
	ooscript::setContextCallback(runtime, ContextCallback);
}


#if OOJS_PROFILE
	
#ifndef MOZ_TRACE_JSCALLS
#warning Profiling is enabled, but MOZ_TRACE_JSCALLS is disabled, so only native functions will be profiled.
#endif

static BOOL						sProfiling = NO;
static BOOL						sTracing = NO;
static OOJSProfileStackFrame	*sProfileStack = NULL;
// Profile key (native name or JS function, by pointer) -> entry, retained. Was a map table with
// non-owned pointer keys and retained object values (bead oo-3rb.20).
static std::unordered_map<const void *, OOTimeProfileEntry *>	*sProfileInfo;

static OOTimeProfileEntry *ProfileEntryForKey(const void *key)
{
	auto found = sProfileInfo->find(key);
	return (found != sProfileInfo->end()) ? found->second : nil;
}
static double					sProfilerOverhead;
static double					sProfilerTotalNativeTime;
static double					sProfilerTotalJavaScriptTime;
static double					sProfilerEntryTimeLimit;
static OOHighResTimeValue		sProfilerStartTime;


@interface OOTimeProfile (Private)

- (void) setTotalTime:(double)value;
- (void) setNativeTime:(double)value;
#ifdef MOZ_TRACE_JSCALLS
- (void) setJavaScriptTime:(double)value;
#endif
- (void) setProfilerOverhead:(double)value;
- (void) setExtensionTime:(double)value;
- (void) setProfileEntries:(const std::vector<oo::ObjCRef<OOTimeProfileEntry *>> &)value;

- (oo::PList) propertyListRepresentation;

@end


@interface OOTimeProfileEntry (Private)

- (id) initWithCName:(const char *)name;
#ifdef MOZ_TRACE_JSCALLS
- (id) initWithJSFunction:(ooscript::Function)function context:(ooscript::Context)context;
#endif

- (void) addSampleWithTotalTime:(OOTimeDelta)totalTime selfTime:(OOTimeDelta)selfTime;

- (oo::PList) propertyListRepresentation;

@end


void OOJSBeginProfiling(BOOL trace)
{
	assert(sProfiling == NO);
	sProfiling = YES;
	sTracing = trace;
	sProfileInfo = new std::unordered_map<const void *, OOTimeProfileEntry *>;
	sProfileInfo->reserve(100);
	sProfilerOverhead = 0.0;
	sProfilerTotalNativeTime = 0.0;
	sProfilerTotalJavaScriptTime = 0.0;
	sProfilerEntryTimeLimit = OOJSGetTimeLimiterLimit();
	
	// This should be last for precision.
	sProfilerStartTime = OOGetHighResTime();
	
	if (trace)
	{
		OOLog(@"script.javaScript.trace", @"%@", @">>>> Beginning trace.");
		OOLogIndent();
	}
}


OOTimeProfile *OOJSEndProfiling(void)
{
	// This should be at the top for precision.
	OOHighResTimeValue now = OOGetHighResTime();
	// Time limiter should be as close to outermost as practical.
	OOJSPauseTimeLimiter();
	
	assert(sProfiling && sProfileStack == NULL);
	
	sProfiling = NO;

	OOTimeProfile *result = [[OOTimeProfile alloc] init];
	
	[result setTotalTime:OOHighResTimeDeltaInSeconds(sProfilerStartTime, now)];
	[result setNativeTime:sProfilerTotalNativeTime];
#ifdef MOZ_TRACE_JSCALLS
	[result setJavaScriptTime:sProfilerTotalJavaScriptTime];
#endif
	[result setProfilerOverhead:sProfilerOverhead];
	
	double currentTimeLimit = OOJSGetTimeLimiterLimit(); 
	[result setExtensionTime:currentTimeLimit - sProfilerEntryTimeLimit];
	
	std::vector<oo::ObjCRef<OOTimeProfileEntry *>> entries;
	entries.reserve(sProfileInfo->size());
	for (const auto &keyAndEntry : *sProfileInfo)  entries.emplace_back(keyAndEntry.second);
	std::stable_sort(entries.begin(), entries.end(), [](const auto &a, const auto &b) { return [a.get() compareBySelfTimeReverse:b.get()] == NSOrderedAscending; });
	[result setProfileEntries:entries];
	
	if (sTracing)
	{
		OOLogOutdent();
		OOLog(@"script.javaScript.trace", @"%@", @"<<<< End of trace.");
		sTracing = NO;
	}
	
	// Clean up.
	for (const auto &keyAndEntry : *sProfileInfo)  [keyAndEntry.second release];
	delete sProfileInfo;
	sProfileInfo = NULL;
	OODisposeHighResTime(sProfilerStartTime);
	
	OODisposeHighResTime(now);
	
	OOJSResumeTimeLimiter();
	return result;
}


BOOL OOJSIsProfiling(void)
{
	return sProfiling;
}

void OOJSBeginTracing(void);
void OOJSEndTracing(void);
BOOL OOJSIsTracing(void);


static void UpdateProfileForFrame(OOHighResTimeValue now, OOJSProfileStackFrame *frame);


#ifdef MOZ_TRACE_JSCALLS
static void CleanUpJSFrame(OOJSProfileStackFrame *frame)
{
	free(frame);
}


static void TraceEnterJSFunction(ooscript::Context context, ooscript::Function function, OOTimeProfileEntry *profileEntry)
{
	std::string			name = oo::str::format("%s(", oo::DescriptionOf([profileEntry function]).c_str());
	BOOL				isNative = ooscript::getFunctionNative(context, function) != NULL;
	std::string			frameTag;
	std::string			logMsgClass;
	
	if (!isNative)
	{
		// Get stack frame and find arguments.
		ooscript::StackFrame	frame = NULL;
		BOOL				first = YES;
		ooscript::Value				thisVal;
		ooscript::Object scope;
		ooscript::VariableList	properties = { 0, NULL, NULL };
		unsigned			i;
		
		// Temporarily disable profiling as we'll call out to profiled functions to get value descriptions.
		sProfiling = NO;
		
		if (ooscript::frameIterator(context, &frame) != NULL)
		{
			if (ooscript::frameIsConstructor(context, frame))
			{
				name.insert(0, "new ");
			}
			
			if (ooscript::frameThis(context, frame, &thisVal))
			{
				name += oo::str::format("this: %s", oo::DescriptionOf(OOJSDescribeValue(context, thisVal, YES)).c_str());
				first = NO;
			}
			
			scope = ooscript::frameScopeChain(context, frame);
			if (scope != NULL && ooscript::getScopeVariables(context, scope, &properties))
			{
				for (i = 0; i < properties.length; i++)
				{
					ooscript::Variable *prop = &properties.vars[i];
					if (prop->flags & static_cast<unsigned>(ooscript::VariableFlag::Argument))
					{
						if (!first)  name += ", ";
						else  first = NO;
						
						ooscript::Value propName = ooscript::undefinedValue();
						ooscript::idToValue(context, prop->id, &propName);
						name += oo::str::format("%s: %s", oo::DescriptionOf(OOStringFromJSValueEvenIfNull(context, propName)).c_str(), oo::DescriptionOf(OOJSDescribeValue(context, prop->value, YES)).c_str());
					}
				}
			}
		}
		
		sProfiling = YES;
		
		frameTag = "JS";	// JavaScript
		logMsgClass = "script.javaScript.trace.JS";
	}
	else
	{
		frameTag = "NW";	// Native Wrapper
		logMsgClass = "script.javaScript.trace.NW";
	}
	
	name += ")";
	OOLog(oo::NSStringFrom(logMsgClass), @">> %@ [%@]", oo::NSStringFrom(name), oo::NSStringFrom(frameTag));
	OOLogIndent();
}


static void FunctionCallback(ooscript::Function function, ooscript::Script script, ooscript::Context context, int entering)
{
	if (EXPECT(!sProfiling))  return;
	if (EXPECT_NOT(function == NULL))  return;
	
	// Ignore native functions. Ours get their own entries anyway, SpiderMonkey's are elided.
	if (!sTracing && ooscript::getFunctionNative(context, function) != NULL)  return;
	
	OOHighResTimeValue start = OOGetHighResTime();
	
	@autoreleasepool
	{
		if (entering > 0)
		{
			// Create profile entry up front so we can shove the JS function in it.
			OOTimeProfileEntry *entry = ProfileEntryForKey(function);
			if (entry == nil)
			{
				entry = [[OOTimeProfileEntry alloc] initWithJSFunction:function context:context];
				(*sProfileInfo)[function] = entry;	// the table's reference
			}
			
			if (EXPECT_NOT(sTracing))
			{
				// We use EXPECT_NOT here because profiles are time-critical and traces are not.
				TraceEnterJSFunction(context, function, entry);
			}
			
			// Make a stack frame on the heap.
			OOJSProfileStackFrame *frame = (OOJSProfileStackFrame *)malloc(sizeof(OOJSProfileStackFrame));
			assert(frame != NULL);
			
			*frame = (OOJSProfileStackFrame)
			{
				.back = sProfileStack,
				.key = function,
				.startTime = start,
				.subTime = 0.0,
				.total = &sProfilerTotalJavaScriptTime,
				.cleanup = CleanUpJSFrame
			};
			
			sProfileStack = frame;
		}
		else
		{
			// Exiting.
			assert(sProfileStack != NULL && sProfileStack->cleanup == CleanUpJSFrame);
			
			UpdateProfileForFrame(start, sProfileStack);
		}
	}
	
	OOHighResTimeValue end = OOGetHighResTime();
	double currentOverhead = OOHighResTimeDeltaInSeconds(start, end);
	sProfilerOverhead += currentOverhead;
	OODisposeHighResTime(start);
	OODisposeHighResTime(end);
}
#endif


void OOJSProfileEnter(OOJSProfileStackFrame *frame, const char *function)
{
	if (EXPECT(!sProfiling))  return;
	if (EXPECT_NOT(sTracing))
	{
		// We use EXPECT_NOT here because profiles are time-critical and traces are not.
		OOLog(@"script.javaScript.trace.ON", @">> %s [ON]", function);
		OOLogIndent();
	}
	
	*frame = (OOJSProfileStackFrame)
	{
		.back = sProfileStack,
		.key = function,
		.function = function,
		.startTime = OOGetHighResTime(),
		.total = &sProfilerTotalNativeTime
	};
	sProfileStack = frame;
}


void OOJSProfileExit(OOJSProfileStackFrame *frame)
{
	if (EXPECT(!sProfiling))  return;
	
	OOHighResTimeValue	now = OOGetHighResTime();
	@autoreleasepool
	{
		BOOL				done = NO;
		
		/*
			It's possible there could be JavaScript frames on top of this frame if
			a JS native returned false. Or possibly not. The semantics of
			the engine's function callback aren't specified in detail.
			-- Ahruman 2011-01-16
		*/
		for (;;)
		{
			assert(sProfileStack != NULL);
			
			done = (sProfileStack == frame);
			UpdateProfileForFrame(now, sProfileStack);
			if (EXPECT(done))  break;
		}
	}
	
	OODisposeHighResTime(frame->startTime);
	
	OOHighResTimeValue end = OOGetHighResTime();
	double currentOverhead = OOHighResTimeDeltaInSeconds(now, end);
	sProfilerOverhead += currentOverhead;
	
	/*	Equivalent of pausing/resuming time limiter, except that it guarantees
		excluded time will match profiler overhead if there are no other
		pauses happening.
	*/
	if (sLimiterPauseDepth == 0)  sLimiterTimeLimit += currentOverhead;
	
	OODisposeHighResTime(now);
	OODisposeHighResTime(end);
}


static void UpdateProfileForFrame(OOHighResTimeValue now, OOJSProfileStackFrame *frame)
{
	sProfileStack = frame->back;
	
	OOTimeProfileEntry *entry = ProfileEntryForKey(frame->key);
	if (entry == nil)
	{
		entry = [[OOTimeProfileEntry alloc] initWithCName:frame->function];
		(*sProfileInfo)[frame->key] = entry;	// the table's reference
	}
	
	OOTimeDelta time = OOHighResTimeDeltaInSeconds(frame->startTime, now);
	OOTimeDelta selfTime = time - frame->subTime;
	[entry addSampleWithTotalTime:time selfTime:selfTime];
	
	*(frame->total) += selfTime;
	if (sProfileStack != NULL)  sProfileStack->subTime += time;
	
	if (frame->cleanup != NULL)  frame->cleanup(frame);
	
	if (EXPECT_NOT(sTracing))  OOLogOutdent();
}


@implementation OOTimeProfile

- (id) description	// shared selector (proposed ADR-0043)
{
	double totalTime = [self totalTime];
	
	std::string result = oo::str::format(
							  "Total time: %g ms\n"
							   "JavaScript: %g ms, native: %g ms\n"
							   "Counted towards limit: %g ms, excluded: %g ms\n"
							   "Profiler overhead: %g ms",
							   totalTime * 1000.0,
							   [self javaScriptTime] * 1000.0, [self nativeTime] * 1000.0,
							   [self nonExtensionTime] * 1000.0, [self extensionTime] * 1000.0,
							   [self profilerOverhead] * 1000.0);
	
	const std::vector<oo::ObjCRef<OOTimeProfileEntry *>> &profileEntries = _profileEntries;
	NSUInteger i, count = profileEntries.size();
	if (count != 0)
	{
		result += "\n                                                        NAME  T  COUNT    TOTAL     SELF  TOTAL%   SELF%  SELFMAX";
		for (i = 0; i < count; i++)
		{
		//	[result appendFormat:@"\n    %@", [_profileEntries objectAtIndex:i]];
			
			OOTimeProfileEntry *entry = profileEntries[i].get();
			
			double totalPc = [entry totalTimeSum] * 100.0 / totalTime;
			double selfPc = [entry selfTimeSum] * 100.0 / totalTime;
			
			result += oo::str::format("\n%60s  %c%7lu %8.2f %8.2f   %5.1f   %5.1f %8.2f",
			 oo::DescriptionOf([entry function]).c_str(),
			 [entry isJavaScriptFrame] ? 'J' : 'N',
			 (unsigned long)[entry hitCount], [entry totalTimeSum] * 1000.0, [entry selfTimeSum] * 1000.0, totalPc, selfPc, [entry selfTimeMax] * 1000.0);
		}
	}
	
	return oo::NSStringFrom(result);
}


- (double) totalTime
{
	return _totalTime;
}


- (void) setTotalTime:(double)value
{
	_totalTime = value;
}


- (double) javaScriptTime
{
#ifdef MOZ_TRACE_JSCALLS
	return _javaScriptTime;
#else
	return _totalTime - _nativeTime;
#endif
}


#ifdef MOZ_TRACE_JSCALLS
- (void) setJavaScriptTime:(double)value
{
	_javaScriptTime = value;
}
#endif


- (double) nativeTime
{
	return _nativeTime;
}


- (void) setNativeTime:(double)value
{
	_nativeTime = value;
}


- (double) extensionTime
{
	return _extensionTime;
}


- (void) setExtensionTime:(double)value
{
	_extensionTime = value;
}


- (double) nonExtensionTime
{
	return _totalTime - _extensionTime;
}


- (double) profilerOverhead
{
	return _profilerOverhead;
}


- (void) setProfilerOverhead:(double)value
{
	_profilerOverhead = value;
}


- (std::vector<oo::ObjCRef<OOTimeProfileEntry *>>) profileEntries
{
	return _profileEntries;
}


- (void) setProfileEntries:(const std::vector<oo::ObjCRef<OOTimeProfileEntry *>> &)value
{
	_profileEntries = value;
}


- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context
{
	return OOJSValueFromNativeObject(context, oo::ObjectFromPList([self propertyListRepresentation]));
}


- (oo::PList) propertyListRepresentation
{
	// "profiles" holds the entry objects themselves, as it always did (the converted forms the old
	// code built were never used; converting each entry to JavaScript calls this method on it).
	oo::PList::Array profiles;
	profiles.reserve(_profileEntries.size());
	for (const auto &entry : _profileEntries)  profiles.push_back(oo::PListObject(entry.get()));
	
	oo::PList::Dict result;
	result.emplace("profiles", oo::PList(std::move(profiles)));
	result.emplace("totalTime", oo::PList([self totalTime]));
	result.emplace("javaScriptTime", oo::PList([self javaScriptTime]));
	result.emplace("nativeTime", oo::PList([self nativeTime]));
	result.emplace("extensionTime", oo::PList([self extensionTime]));
	result.emplace("nonExtensionTime", oo::PList([self nonExtensionTime]));
	result.emplace("profilerOverhead", oo::PList([self profilerOverhead]));
	return oo::PList(std::move(result));
}

@end


@implementation OOTimeProfileEntry

- (id) initWithCName:(const char *)name
{
	NSAssert(sProfiling, @"Can't create profile entries while not profiling.");
	
	if ((self = [super init]))
	{
		if (name != NULL)
		{
			_function = std::string(name);
		}
	}
	
	return self;
}


#if MOZ_TRACE_JSCALLS
- (id) initWithJSFunction:(ooscript::Function)function context:(ooscript::Context)context
{
	if ((self = [self initWithCName:NULL]))
	{
		// Temporarily disable profiling so we don't profile the profiler while it's profiling the profilee.
		sProfiling = NO;
		_jsFunction = function;
		
		std::string funcName;
		ooscript::String jsName = ooscript::getFunctionId(_jsFunction);
		if (jsName != NULL)  funcName = oo::StdString(OOStringFromJSString(context, jsName));
		else  funcName = "<anonymous>";
		
		// If it's a non-native function, get its source location.
		std::optional<std::string> location;
		if (ooscript::getFunctionNative(context, function) == NULL)
		{
			ooscript::StackFrame frame = NULL;
			if (ooscript::frameIterator(context, &frame) != NULL)
			{
				location = OOJSDescribeLocation(context, frame);
			}
		}
		
		if (location.has_value())
		{
			_function = oo::str::format("(%s) %s", location->c_str(), funcName.c_str());
		}
		else  _function = funcName;
		
		sProfiling = YES;
	}
	
	return self;
}
#endif


- (void) addSampleWithTotalTime:(OOTimeDelta)totalTime selfTime:(OOTimeDelta)selfTime
{
	_hitCount++;
	_totalTimeSum += totalTime;
	_selfTimeSum += selfTime;
	_totalTimeMax = fmax(_totalTimeMax, totalTime);
	_selfTimeMax = fmax(_selfTimeMax, selfTime);
}


- (id) description	// shared selector (proposed ADR-0043)
{
	const char *function = _function.has_value() ? _function->c_str() : "(null)";	// as %@ printed nil
	if (_hitCount == 0)  return oo::NSStringFrom(oo::str::format("%s: --", function));
	
	// Convert everything to milliseconds.
	float totalTimeSum = _totalTimeSum * 1000.0;
	float selfTimeSum = _selfTimeSum * 1000.0;
	float totalTimeMax = _totalTimeMax * 1000.0;
	float selfTimeMax = _selfTimeMax * 1000.0;
	
	if (totalTimeSum == selfTimeSum && totalTimeMax == selfTimeMax)
	{
		if (_hitCount == 1)
		{
			return oo::NSStringFrom(oo::str::format("%s: 1 time, %g ms", function, totalTimeSum));
		}
		else
		{
			return oo::NSStringFrom(oo::str::format("%s: %lu times, total %g ms, avg %g ms, max %g ms", function, _hitCount, totalTimeSum, totalTimeSum / _hitCount, totalTimeMax));
		}
	}
	else
	{
		if (_hitCount == 1)
		{
			return oo::NSStringFrom(oo::str::format("%s: 1 time, %g ms (self %g ms)", function, totalTimeSum, selfTimeSum));
		}
		else
		{
			return oo::NSStringFrom(oo::str::format("%s: %lu times, total %g ms (self %g ms), avg %g ms (self %g ms), max %g ms, max self %g ms", function, _hitCount, totalTimeSum, selfTimeSum, totalTimeSum / _hitCount, selfTimeSum / _hitCount, totalTimeMax, selfTimeMax));
		}
	}
}


- (id) function	// shared selector (proposed ADR-0043)
{
	return oo::NSStringOrNil(_function);
}


- (NSUInteger) hitCount
{
	return _hitCount;
}


- (double) totalTimeSum
{
	return _totalTimeSum;
}


- (double) selfTimeSum
{
	return _selfTimeSum;
}


- (double) totalTimeAverage
{
	return _hitCount ? (_totalTimeSum / _hitCount) : 0.0;
}


- (double) selfTimeAverage
{
	return _hitCount ? (_selfTimeSum / _hitCount) : 0.0;
}


- (double) totalTimeMax
{
	return _totalTimeMax;
}


- (double) selfTimeMax
{
	return _selfTimeMax;
}


- (BOOL) isJavaScriptFrame
{
#if MOZ_TRACE_JSCALLS
	return _jsFunction != NULL;
#else
	return NO;
#endif
}


- (NSComparisonResult) compareByTotalTime:(OOTimeProfileEntry *)other
{
	return (NSComparisonResult)-[self compareByTotalTimeReverse:other];
}


- (NSComparisonResult) compareByTotalTimeReverse:(OOTimeProfileEntry *)other
{
	double selfTotal = [self totalTimeSum];
	double otherTotal = [other totalTimeSum];
	
	if (selfTotal < otherTotal)  return NSOrderedDescending;
	if (selfTotal > otherTotal)  return NSOrderedAscending;
	return NSOrderedSame;
}


- (NSComparisonResult) compareBySelfTime:(OOTimeProfileEntry *)other
{
	return (NSComparisonResult)-[self compareBySelfTimeReverse:other];
}


- (NSComparisonResult) compareBySelfTimeReverse:(OOTimeProfileEntry *)other
{
	double selfTotal = [self selfTimeSum];
	double otherTotal = [other selfTimeSum];
	
	if (selfTotal < otherTotal)  return NSOrderedDescending;
	if (selfTotal > otherTotal)  return NSOrderedAscending;
	return NSOrderedSame;
}


- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context
{
	return OOJSValueFromNativeObject(context, oo::ObjectFromPList([self propertyListRepresentation]));
}


- (oo::PList) propertyListRepresentation
{
	oo::PList::Dict result;
	// A nameless entry gave an empty dictionary: its nil name ended the object/key list.
	if (_function.has_value())
	{
		result.emplace("name", oo::PList(*_function));
		result.emplace("hitCount", oo::PList::unsignedInteger([self hitCount]));
		result.emplace("totalTimeSum", oo::PList([self totalTimeSum]));
		result.emplace("selfTimeSum", oo::PList([self selfTimeSum]));
		result.emplace("totalTimeAverage", oo::PList([self totalTimeAverage]));
		result.emplace("selfTimeAverage", oo::PList([self selfTimeAverage]));
		result.emplace("totalTimeMax", oo::PList([self totalTimeMax]));
		result.emplace("selfTimeMax", oo::PList([self selfTimeMax]));
		result.emplace("isJavaScriptFrame", oo::PList(static_cast<bool>([self isJavaScriptFrame])));
	}
	return oo::PList(std::move(result));
}

@end

#endif
