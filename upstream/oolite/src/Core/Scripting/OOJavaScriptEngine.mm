/*

OOJavaScriptEngine.m

JavaScript support for Oolite
Copyright (C) 2007-2013 David Taylor and Jens Ayton.

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

#import "OOJavaScriptEngine.h"
#import "OOJSEngineTimeManagement.h"
#import "OOJSScript.h"

#include "ooscript/JSEngine.hpp"
#include "oofnd/Notification.hpp"
#include "oofnd/PList.hpp"
#include "oofnd/String.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar): every engine call goes through its ooscript:: equivalent, and
	the natives shared with the class files (OOJSUnconstructableConstruct,
	OOJSObjectWrapperToString, OOJSObjectWrapperFinalize) take the façade signatures directly.

	The debugging support below -- the stack walk in OOJSDumpStack, GetLocationNameAndLine and
	DumpVariable, and the `debugger` statement hook -- uses the façade's "Debugging and
	profiling" section (frameIterator / frameScript / frameScopeChain / getScopeVariables /
	setDebuggerHandler, bead oo-1gc.3). The engine's local root scopes around
	the array and dictionary value converters (now in OOJavaScriptEngine+FoundationBridge.mm)
	are superseded by explicit roots, as
	ooscript/README.md describes: ooscript::RootedValue roots the value about to be handed to
	the caller.

	Three façade functions were added for this file (ooscript::internUCStringN,
	ooscript::clearScope, ooscript::setCStringsAreUTF8), each a 1:1 wrap of the engine call of
	the same name. Two more, ooscript::isThreadsafeBuild and ooscript::gcZealSupported, report
	the engine build-configuration values this file used to test with preprocessor guards, so
	the two guarded blocks below are runtime `if`s with identical behaviour.
*/

namespace {
// NSString wants unichar (unsigned short); the façade's ooscript::Char16 is char16_t. Both are
// 16-bit code units, but Objective-C++ does not implicitly convert between distinct pointee types.
static inline const unichar *OOJSRUCHARS(const ooscript::Char16 *s)  { return reinterpret_cast<const unichar*>(s); }
} // namespace

#import "OOPListView.h"
#import "OOFoundationBridge.h"
#import "Universe.h"
#import "OOPlanetEntity.h"
#import "NSStringOOExtensions.h"
#import "OOWeakReference.h"
#import "EntityOOJavaScriptExtensions.h"
#import "ResourceManager.h"
#import "NSNumberOOExtensions.h"
#import "OOConstToJSString.h"
#import "OOVisualEffectEntity.h"
#import "OOWaypointEntity.h"

#import "OOJSGlobal.h"
#import "OOJSMissionVariables.h"
#import "OOJSMission.h"
#import "OOJSVector.h"
#import "OOJSQuaternion.h"
#import "OOJSEntity.h"
#import "OOJSShip.h"
#import "OOJSStation.h"
#import "OOJSDock.h"
#import "OOJSVisualEffect.h"
#import "OOJSExhaustPlume.h"
#import "OOJSFlasher.h"
#import "OOJSWormhole.h"
#import "OOJSWaypoint.h"
#import "OOJSPlayer.h"
#import "OOJSPlayerShip.h"
#import "OOJSManifest.h"
#import "OOJSPlanet.h"
#import "OOJSSystem.h"
#import "OOJSOolite.h"
#import "OOJSTimer.h"
#import "OOJSClock.h"
#import "OOJSSun.h"
#import "OOJSWorldScripts.h"
#import "OOJSSound.h"
#import "OOJSSoundSource.h"
#import "OOJSSpecialFunctions.h"
#import "OOJSSystemInfo.h"
#import "OOJSEquipmentInfo.h"
#import "OOJSShipGroup.h"
#import "OOJSFrameCallbacks.h"
#import "OOJSFont.h"

#import "OOProfilingStopwatch.h"
#import "OOLoggingExtended.h"
#import "OOFoundationException.h"
#import "OOStringBridge.h"

#include <stdlib.h>


#define OOJSENGINE_JSVERSION		ooscript::Version::ECMA5
#ifdef DEBUG
#define JIT_OPTIONS					ooscript::ContextOption::None
#else
#define JIT_OPTIONS					(ooscript::ContextOption::Jit | ooscript::ContextOption::MethodJit | ooscript::ContextOption::Profiling)
#endif
#define OOJSENGINE_CONTEXT_OPTIONS	(ooscript::ContextOption::VarObjFix | ooscript::ContextOption::RegExpLimit | ooscript::ContextOption::AnonFunFix | JIT_OPTIONS)


#define OOJS_STACK_SIZE				8192
#define OOJS_RUNTIME_SIZE_MiB			256


namespace {
static OOJavaScriptEngine	*sSharedEngine = nil;
} // namespace
namespace {
static unsigned				sErrorHandlerStackSkip = 0;
} // namespace

ooscript::Context gOOJSMainThreadContext = NULL;


const char * const kOOJavaScriptEngineWillResetNotificationName = "org.aegidian.oolite OOJavaScriptEngine will reset";
const char * const kOOJavaScriptEngineDidResetNotificationName = "org.aegidian.oolite OOJavaScriptEngine did reset";


#if OOJSENGINE_MONITOR_SUPPORT

@interface OOJavaScriptEngine (OOMonitorSupportInternal)

- (void)sendMonitorError:(ooscript::ErrorReport *)errorReport
			 withMessage:(NSString *)message
			   inContext:(ooscript::Context)context;

- (void)sendMonitorLogMessage:(NSString *)message
			 withMessageClass:(NSString *)messageClass
					inContext:(ooscript::Context)context;

@end

#endif


@interface OOJavaScriptEngine (Private)

- (BOOL) lookUpStandardClassPointers;
- (void) registerStandardObjectConverters;

- (void) createMainThreadContext;
- (void) destroyMainThreadContext;

@end


namespace {
static void ReportJSError(ooscript::Context context, const char *message, const ooscript::ErrorReport *report);
} // namespace

namespace {
static id JSArrayConverter(ooscript::Context context, ooscript::Object object);
} // namespace
namespace {
static id JSStringConverter(ooscript::Context context, ooscript::Object object);
} // namespace
namespace {
static id JSNumberConverter(ooscript::Context context, ooscript::Object object);
} // namespace
namespace {
static id JSBooleanConverter(ooscript::Context context, ooscript::Object object);
} // namespace


namespace {
static void UnregisterObjectConverters(void);
} // namespace
namespace {
static void UnregisterSubclasses(void);
} // namespace


namespace {
static void ReportJSError(ooscript::Context context, const char *message, const ooscript::ErrorReport *report)
{
	NSString			*severity = @"error";
	NSString			*messageText = nil;
	NSString			*lineBuf = nil;
	NSString			*messageClass = nil;
	NSString			*highlight = @"*****";
	NSString			*activeScript = nil;
	OOJavaScriptEngine	*jsEng = [OOJavaScriptEngine sharedEngine];
	BOOL				showLocation = [jsEng showErrorLocations];
	
	// Not OOJS_BEGIN_FULL_NATIVE() - we use the engine while paused.
	OOJSPauseTimeLimiter();
	
	static const ooscript::Char16 emptyUC[1] = { 0 };
	ooscript::ErrorReport blankReport =
	{
		.filename = "<unspecified file>",
		.lineno = 0,
		.flags = 0,
		.errorNumber = 0,
		.ucmessage = emptyUC,
		.linebuf = emptyUC
	};
	if (EXPECT_NOT(report == NULL))  report = &blankReport;
	if (EXPECT_NOT(message == NULL || *message == '\0'))  message = "<unspecified error>";
	
	// Type of problem: error, warning or exception? (Strict flag wilfully ignored.)
	if (report->flags & static_cast<unsigned>(ooscript::ReportFlag::Exception)) severity = @"exception";
	else if (report->flags & static_cast<unsigned>(ooscript::ReportFlag::Warning))
	{
		severity = @"warning";
		highlight = @"-----";
	}
	
	// The error message itself
	messageText = [NSString stringWithUTF8String:message];
	
	// Get offending line, if present, and trim trailing line breaks
	lineBuf = [NSString stringWithUTF16String:OOJSRUCHARS(report->linebuf)];
	while ([lineBuf hasSuffix:@"\n"] || [lineBuf hasSuffix:@"\r"])  lineBuf = [lineBuf substringToIndex:[lineBuf length] - 1];
	
	// Get string for error number, for useful log message classes
	NSDictionary *errorNames = [ResourceManager dictionaryFromFilesNamed:@"javascript-errors.plist" inFolder:@"Config" andMerge:YES];
	NSString *errorNumberStr = [NSString stringWithFormat:@"%u", report->errorNumber];
	NSString *errorName = oo::PListView(errorNames).get<NSString *>(errorNumberStr);
	if (errorName == nil)  errorName = errorNumberStr;
	
	// Log message class
	messageClass = [NSString stringWithFormat:@"script.javaScript.%@.%@", severity, errorName];
	
	// Skip the rest if this is a warning being ignored.
	if ((report->flags & static_cast<unsigned>(ooscript::ReportFlag::Warning)) == 0 || OOLogWillDisplayMessagesInClass(messageClass))
	{
		// First line: problem description
		// avoid windows DEP exceptions!
		OOJSScript *thisScript = [[OOJSScript currentlyRunningScript] weakRetain];
		activeScript = [[thisScript weakRefUnderlyingObject] displayName];
		[thisScript release];
		
		if (activeScript == nil)  activeScript = @"<unidentified script>";
		OOLog(messageClass, @"%@ JavaScript %@ (%@): %@", highlight, severity, activeScript, messageText);
		
		if (showLocation && sErrorHandlerStackSkip == 0 && report->filename != NULL)
		{
			// Second line: where error occured, and line if provided. (The line is only provided for compile-time errors, not run-time errors.)
			if ([lineBuf length] != 0)
			{
				OOLog(messageClass, @"      %s, line %d: %@", report->filename, report->lineno, lineBuf);
			}
			else
			{
				OOLog(messageClass, @"      %s, line %d.", report->filename, report->lineno);
			}
		}
		
#ifndef NDEBUG
		BOOL dump;
		if (report->flags & static_cast<unsigned>(ooscript::ReportFlag::Warning))  dump = [jsEng dumpStackForWarnings];
		else  dump = [jsEng dumpStackForErrors];
		if (dump)  OOJSDumpStack((context));
#endif
		
#if OOJSENGINE_MONITOR_SUPPORT
		ooscript::ExceptionState *exState = ooscript::saveExceptionState(context);
		ooscript::ErrorReport nativeReport = *report;
		[[OOJavaScriptEngine sharedEngine] sendMonitorError:&nativeReport
														withMessage:messageText
														  inContext:(context)];
		ooscript::restoreExceptionState(context, exState);
#endif
	}
	
	OOJSResumeTimeLimiter();
}
} // namespace


//===========================================================================
// JavaScript engine initialisation and shutdown
//===========================================================================

@implementation OOJavaScriptEngine

+ (OOJavaScriptEngine *) sharedEngine
{
	if (sSharedEngine == nil)  sSharedEngine = [[self alloc] init];
	
	return sSharedEngine;
}


- (void) runMissionCallback
{
	MissionRunCallback();
}


- (id) init
{
	NSAssert(sSharedEngine == nil, @"Attempt to create multiple OOJavaScriptEngines.");
	
	self = [super init];
	if (!self)  { return nil; }
	sSharedEngine = self;
	
	ooscript::setCStringsAreUTF8();
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
#ifndef NDEBUG
	/*	Set stack trace preferences from preferences. These will be overriden
		by the debug OXP script if installed, but being able to enable traces
		without setting up the debug console could be useful for debugging
		users' problems.
	*/
	[self setDumpStackForErrors:[defaults boolForKey:@"dump-stack-for-errors"]];
	[self setDumpStackForWarnings:[defaults boolForKey:@"dump-stack-for-warnings"]];
#endif
	
	assert(sizeof(ooscript::Char16) == sizeof(unichar));
	
	// initialize the JS run time, and return result in runtime.
	uint32_t jsRuntimeInMiB = oo::PListView(defaults).get<int>(@"jsruntime-size-mib", OOJS_RUNTIME_SIZE_MiB);
	_runtime = ooscript::newRuntime(jsRuntimeInMiB * 1024L * 1024L);
	
	// if runtime creation failed, end the program here.
	if (_runtime == NULL)
	{
		OOLog(@"script.javaScript.init.error", @"***** FATAL ERROR: failed to create JavaScript runtime with size %uMiB.", jsRuntimeInMiB);
		exit(1);
	}
	
	// OOJSTimeManagementInit() must be called before any context is created!
	OOJSTimeManagementInit(self, _runtime);
	
	[self createMainThreadContext];
	
	return self;
}


- (void) createMainThreadContext
{
	NSAssert(gOOJSMainThreadContext == NULL, @"-[OOJavaScriptEngine createMainThreadContext] called while the main thread context exists.");
	
	// create a context and associate it with the JS runtime.
	gOOJSMainThreadContext = (ooscript::newContext(_runtime, OOJS_STACK_SIZE));
	
	// if context creation failed, end the program here.
	if (gOOJSMainThreadContext == NULL)
	{
		OOLog(@"script.javaScript.init.error", @"%@", @"***** FATAL ERROR: failed to create JavaScript context.");
		exit(1);
	}
	
	ooscript::beginRequest((gOOJSMainThreadContext));
	
	ooscript::setOptions((gOOJSMainThreadContext), OOJSENGINE_CONTEXT_OPTIONS);  // NOLINT(clang-analyzer-optin.core.EnumCastOutOfRange): OOJSENGINE_CONTEXT_OPTIONS ORs ContextOption flag bits through JSEngine.hpp's own constexpr operator|; the enum is a bitmask, not a closed set, so the analyzer's "value not a declared enumerator" is a false positive on every legitimate flag combination -- see JSEngine.hpp's own operator| for the same pattern used by OOJSVector.mm's PropertyFlag/ClassFlag tables.
	ooscript::setVersion((gOOJSMainThreadContext), OOJSENGINE_JSVERSION);
	
	if (ooscript::gcZealSupported())
	{
		uint8_t gcZeal = oo::PListView([NSUserDefaults standardUserDefaults]).get<unsigned char>(@"js-gc-zeal");
		if (gcZeal > 0)
		{
			// Useful js-gc-zeal values are 0 (off), 1 and 2.
			OOLog(@"script.javaScript.debug.gcZeal", @"Setting JavaScript garbage collector zeal to %u.", gcZeal);
			ooscript::setGCZeal((gOOJSMainThreadContext), gcZeal);
		}
	}
	
	ooscript::setErrorReporter((gOOJSMainThreadContext), ReportJSError);
	
	// Create the global object.
	CreateOOJSGlobal(gOOJSMainThreadContext, &_globalObject);
	
	// Initialize the built-in JS objects and the global object.
	ooscript::initStandardClasses((gOOJSMainThreadContext), (_globalObject));
	if (![self lookUpStandardClassPointers])
	{
		OOLog(@"script.javaScript.init.error", @"%@", @"***** FATAL ERROR: failed to look up standard JavaScript classes.");
		exit(1);
	}
	[self registerStandardObjectConverters];
	
	SetUpOOJSGlobal(gOOJSMainThreadContext, _globalObject);
	OOConstToJSStringInit(gOOJSMainThreadContext);
	
	// Initialize Oolite classes.
	InitOOJSMissionVariables(gOOJSMainThreadContext, _globalObject);
	InitOOJSMission(gOOJSMainThreadContext, _globalObject);
	InitOOJSOolite(gOOJSMainThreadContext, _globalObject);
	InitOOJSVector(gOOJSMainThreadContext, _globalObject);
	InitOOJSQuaternion(gOOJSMainThreadContext, _globalObject);
	InitOOJSSystem(gOOJSMainThreadContext, _globalObject);
	InitOOJSEntity(gOOJSMainThreadContext, _globalObject);
	InitOOJSShip(gOOJSMainThreadContext, _globalObject);
	InitOOJSStation(gOOJSMainThreadContext, _globalObject);
	InitOOJSDock(gOOJSMainThreadContext, _globalObject);
	InitOOJSVisualEffect(gOOJSMainThreadContext, _globalObject);
	InitOOJSExhaustPlume(gOOJSMainThreadContext, _globalObject);
	InitOOJSFlasher(gOOJSMainThreadContext, _globalObject);
	InitOOJSWormhole(gOOJSMainThreadContext, _globalObject);
	InitOOJSWaypoint(gOOJSMainThreadContext, _globalObject);
	InitOOJSPlayer(gOOJSMainThreadContext, _globalObject);
	InitOOJSPlayerShip(gOOJSMainThreadContext, _globalObject);
	InitOOJSManifest(gOOJSMainThreadContext, _globalObject);
	InitOOJSSun(gOOJSMainThreadContext, _globalObject);
	InitOOJSPlanet(gOOJSMainThreadContext, _globalObject);
	InitOOJSScript(gOOJSMainThreadContext, _globalObject);
	InitOOJSTimer(gOOJSMainThreadContext, _globalObject);
	InitOOJSClock(gOOJSMainThreadContext, _globalObject);
	InitOOJSWorldScripts(gOOJSMainThreadContext, _globalObject);
	InitOOJSSound(gOOJSMainThreadContext, _globalObject);
	InitOOJSSoundSource(gOOJSMainThreadContext, _globalObject);
	InitOOJSSpecialFunctions(gOOJSMainThreadContext, _globalObject);
	InitOOJSSystemInfo(gOOJSMainThreadContext, _globalObject);
	InitOOJSEquipmentInfo(gOOJSMainThreadContext, _globalObject);
	InitOOJSShipGroup(gOOJSMainThreadContext, _globalObject);
	InitOOJSFrameCallbacks(gOOJSMainThreadContext, _globalObject);
	InitOOJSFont(gOOJSMainThreadContext, _globalObject);
	
	// Run prefix scripts.
	[OOJSScript jsScriptFromFileNamed:@"oolite-global-prefix.js"
						   properties:[NSDictionary dictionaryWithObject:JSSpecialFunctionsObjectWrapper(gOOJSMainThreadContext)
																  forKey:@"special"]];
	
	ooscript::endRequest((gOOJSMainThreadContext));
	
	OOLog(@"script.javaScript.init.success", @"%@", @"Set up JavaScript context.");
}


- (void) destroyMainThreadContext
{
	if (gOOJSMainThreadContext != NULL)
	{
		ooscript::Context context = OOJSAcquireContext();
		ooscript::clearScope((gOOJSMainThreadContext), (_globalObject));
		
		_globalObject = NULL;
		_objectClass = NULL;
		_stringClass = NULL;
		_arrayClass = NULL;
		_numberClass = NULL;
		_booleanClass = NULL;
		
		UnregisterObjectConverters();
		UnregisterSubclasses();
		OOConstToJSStringDestroy();
		
		OOJSRelinquishContext(context);
		
		_globalObject = NULL;
		ooscript::destroyContext((gOOJSMainThreadContext));	// Forces unconditional GC.
		gOOJSMainThreadContext = NULL;
	}
}


- (BOOL) reset
{
	NSAssert(gOOJSMainThreadContext != NULL, @"JavaScript engine not active. Can't reset.");
	
	OOJSFrameCallbacksRemoveAll();
	
# if 0
	// deferred JS reset - test harness.
	static int counter = 3;		// loading a savegame with different strict mode calls js reset twice
	if (counter-- == 0) {
	counter = 3;
	OOLog(@"script.javascript.init.error", @"%@", @"JavaScript processes still pending. Can't reset JavaScript engine.");
		return NO;
	}
	else
	{
		OOLog(@"script.javascript.init", @"%@", @"JavaScript reset successful.");
	}
#endif
		
	if (ooscript::isThreadsafeBuild())
	{
		//NSAssert(!ooscript::isInRequest((gOOJSMainThreadContext)), @"JavaScript processes still pending. Can't reset JavaScript engine.");
		
		if (ooscript::isInRequest((gOOJSMainThreadContext)))
		{
			// some threads are still pending, this should mean timers are still being removed.
			OOLog(@"script.javascript.init.error", @"%@", @"JavaScript processes still pending. Can't reset JavaScript engine.");
			return NO;
		}
		else
		{
			OOLog(@"script.javascript.init", @"%@", @"JavaScript reset successful.");
		}
	}
	
	ooscript::Context context = OOJSAcquireContext();
	oo::NotificationCenter::defaultCenter().post(kOOJavaScriptEngineWillResetNotificationName, self);
OOJSRelinquishContext(context);
	
	[self destroyMainThreadContext];
	[self createMainThreadContext];
	
	context = OOJSAcquireContext();
	oo::NotificationCenter::defaultCenter().post(kOOJavaScriptEngineDidResetNotificationName, self);
OOJSRelinquishContext(context);
	
	[self garbageCollectionOpportunity:YES];
	return YES;
}


- (void) dealloc
{
	sSharedEngine = nil;
	
	OOJSFrameCallbacksRemoveAll();
	
	[self destroyMainThreadContext];
	ooscript::destroyRuntime(_runtime);
	
	[super dealloc];
}


- (ooscript::Object) globalObject
{
	return _globalObject;
}


- (BOOL) callJSFunction:(ooscript::Value)function
			  forObject:(ooscript::Object)jsThis
				   argc:(unsigned)argc
				   argv:(ooscript::Value *)argv
				 result:(ooscript::Value *)outResult
{
	ooscript::Context context = NULL;
	BOOL						result;
	
	NSParameterAssert(OOJSValueIsFunction(context, function));
	
	context = OOJSAcquireContext();
	
	OOJSStartTimeLimiter();
	result = ooscript::callFunctionValue((context), (jsThis), (function), argc, (argv), (outResult));
	OOJSStopTimeLimiter();
	
	ooscript::reportPendingException((context));
	OOJSRelinquishContext(context);
	
	return result;
}


- (void) removeGCObjectRoot:(ooscript::Object *)rootPtr
{
	ooscript::Context context = OOJSAcquireContext();
	ooscript::removeObjectRoot((context), rootPtr);
	OOJSRelinquishContext(context);
}


- (void) removeGCValueRoot:(ooscript::Value *)rootPtr
{
	ooscript::Context context = OOJSAcquireContext();
	ooscript::removeValueRoot((context), (rootPtr));
	OOJSRelinquishContext(context);
}


- (void) garbageCollectionOpportunity:(BOOL)force
{
	ooscript::Context context = OOJSAcquireContext();
	if (force)
	{
		ooscript::gc((context));
	}
	else
	{
		ooscript::maybeGC((context));
	}
	OOJSRelinquishContext(context);
}


- (BOOL) showErrorLocations
{
	return _showErrorLocations;
}


- (void) setShowErrorLocations:(BOOL)value
{
	_showErrorLocations = !!value;
}


- (ooscript::ClassDef *) objectClass
{
	return _objectClass;
}


- (ooscript::ClassDef *) stringClass
{
	return _stringClass;
}


- (ooscript::ClassDef *) arrayClass
{
	return _arrayClass;
}


- (ooscript::ClassDef *) numberClass
{
	return _numberClass;
}


- (ooscript::ClassDef *) booleanClass
{
	return _booleanClass;
}


- (BOOL) lookUpStandardClassPointers
{
	ooscript::Object templateObject = NULL;
	
	templateObject = (ooscript::newObject((gOOJSMainThreadContext), NULL, NULL, NULL));
	if (EXPECT_NOT(templateObject == NULL))  return NO;
	_objectClass = OOJSGetClass(gOOJSMainThreadContext, templateObject);
	
	{
		ooscript::Object obj = (templateObject);
		if (EXPECT_NOT(!ooscript::valueToObject((gOOJSMainThreadContext), ooscript::emptyStringValue((gOOJSMainThreadContext)), &obj)))  return NO;
		templateObject = (obj);
	}
	_stringClass = OOJSGetClass(gOOJSMainThreadContext, templateObject);
	
	templateObject = (ooscript::newArrayObject((gOOJSMainThreadContext), 0, NULL));
	if (EXPECT_NOT(templateObject == NULL))  return NO;
	_arrayClass = OOJSGetClass(gOOJSMainThreadContext, templateObject);
	
	{
		ooscript::Object obj = (templateObject);
		if (EXPECT_NOT(!ooscript::valueToObject((gOOJSMainThreadContext), ooscript::int32Value(0), &obj)))  return NO;
		templateObject = (obj);
	}
	_numberClass = OOJSGetClass(gOOJSMainThreadContext, templateObject);
	
	{
		ooscript::Object obj = (templateObject);
		if (EXPECT_NOT(!ooscript::valueToObject((gOOJSMainThreadContext), ooscript::falseValue(), &obj)))  return NO;
		templateObject = (obj);
	}
	_booleanClass = OOJSGetClass(gOOJSMainThreadContext, templateObject);
	
	return YES;
}


- (void) registerStandardObjectConverters
{
	OOJSRegisterFoundationObjectConverter([self objectClass]);	// the Foundation converter, in the bridge (bead oo-3rb.202)
OOJSRegisterObjectConverter([self stringClass], JSStringConverter);
	OOJSRegisterObjectConverter([self arrayClass], JSArrayConverter);
	OOJSRegisterObjectConverter([self numberClass], JSNumberConverter);
	OOJSRegisterObjectConverter([self booleanClass], JSBooleanConverter);
}


#ifndef NDEBUG
namespace {
static void DebuggerHook(ooscript::Context context, void * /*closure*/)
{
	OOJSPauseTimeLimiter();
	
	OOLog(@"script.javaScript.debugger", @"debugger invoked during %@:", [[OOJSScript currentlyRunningScript] displayName]);
	OOJSDumpStack(context);
	
	OOJSResumeTimeLimiter();
}
} // namespace


- (BOOL) dumpStackForErrors
{
	return _dumpStackForErrors;
}


- (void) setDumpStackForErrors:(BOOL)value
{
	_dumpStackForErrors = !!value;
}


- (BOOL) dumpStackForWarnings
{
	return _dumpStackForWarnings;
}


- (void) setDumpStackForWarnings:(BOOL)value
{
	_dumpStackForWarnings = !!value;
}


- (void) enableDebuggerStatement
{
	ooscript::setDebuggerHandler(_runtime, DebuggerHook, self);
}
#endif

@end


#if OOJSENGINE_MONITOR_SUPPORT

@implementation OOJavaScriptEngine (OOMonitorSupport)

- (void) setMonitor:(id<OOJavaScriptEngineMonitor>)inMonitor
{
	[_monitor autorelease];
	_monitor = [inMonitor retain];
}

@end


@implementation OOJavaScriptEngine (OOMonitorSupportInternal)

- (void) sendMonitorError:(ooscript::ErrorReport *)errorReport
			  withMessage:(NSString *)message
				inContext:(ooscript::Context)theContext
{
	if ([_monitor respondsToSelector:@selector(jsEngine:context:error:stackSkip:showingLocation:withMessage:)])
	{
		[_monitor jsEngine:self context:theContext error:errorReport stackSkip:sErrorHandlerStackSkip showingLocation:[self showErrorLocations] withMessage:message];
	}
}


- (void) sendMonitorLogMessage:(NSString *)message
			  withMessageClass:(NSString *)messageClass
					 inContext:(ooscript::Context)theContext
{
	if ([_monitor respondsToSelector:@selector(jsEngine:context:logMessage:ofClass:)])
	{
		[_monitor jsEngine:self context:theContext logMessage:message ofClass:messageClass];
	}
}

@end

#endif


#ifndef NDEBUG

namespace {
static void DumpVariable(ooscript::Context context, ooscript::Variable *prop)
{
	ooscript::Value nameVal = ooscript::undefinedValue();
	ooscript::idToValue(context, prop->id, &nameVal);
	NSString *name = OOStringFromJSValueEvenIfNull(context, nameVal);
	NSString *value = OOJSDescribeValue(context, prop->value, YES);
	
	enum   // NOLINT(performance-enum-size): kInterestingFlags is a bitwise complement of small flag values; forcing a narrow base type would truncate the ~ result.
	{
		kInterestingFlags = ~(static_cast<unsigned>(ooscript::VariableFlag::Enumerate) | static_cast<unsigned>(ooscript::VariableFlag::Permanent) | static_cast<unsigned>(ooscript::VariableFlag::Variable) | static_cast<unsigned>(ooscript::VariableFlag::Argument))
	};
	
	NSString *flagStr = @"";
	if ((prop->flags & kInterestingFlags) != 0)
	{
		NSMutableArray *flags = [NSMutableArray array];
		if (prop->flags & static_cast<unsigned>(ooscript::VariableFlag::ReadOnly))  [flags addObject:@"read-only"];
		if (prop->flags & static_cast<unsigned>(ooscript::VariableFlag::Alias))  [flags addObject:[NSString stringWithFormat:@"alias (%@)", OOJSDescribeValue(context, prop->alias, YES)]];
		if (prop->flags & static_cast<unsigned>(ooscript::VariableFlag::Exception))  [flags addObject:@"exception"];
		if (prop->flags & static_cast<unsigned>(ooscript::VariableFlag::Error))  [flags addObject:@"error"];
		
		flagStr = [NSString stringWithFormat:@" [%@]", [flags componentsJoinedByString:@", "]];
	}
	
	OOLog(@"script.javaScript.stackTrace", @"    %@: %@%@", name, value, flagStr);
}
} // namespace


void OOJSDumpStack(ooscript::Context context)
{
	@autoreleasepool
	{
		@try
		{
			ooscript::StackFrame	frame = NULL;
			unsigned		idx = 0;
			unsigned		skip = sErrorHandlerStackSkip;
			
			while (ooscript::frameIterator(context, &frame) != NULL)
			{
				ooscript::Script script = ooscript::frameScript(context, frame);
				NSString			*desc = nil;
				ooscript::VariableList	properties = { 0, NULL, NULL };
				BOOL				gotProperties = NO;
				
				idx++;
				
				if (!ooscript::frameIsScript(context, frame))
				{
					continue;
				}
				
				if (skip != 0)
				{
					skip--;
					continue;
				}
				
				if (script != NULL)
				{
					NSString	*location = OOJSDescribeLocation(context, frame);
					ooscript::Object scope = ooscript::frameScopeChain(context, frame);
					
					if (scope != NULL)  gotProperties = ooscript::getScopeVariables(context, scope, &properties);
					
					NSString *funcDesc = nil;
					ooscript::Function function = ooscript::frameFunction(context, frame);
					if (function != NULL)
					{
						ooscript::String funcName = ooscript::getFunctionId(function);
						if (funcName != NULL)
						{
							funcDesc = OOStringFromJSString(context, funcName);
							if (!ooscript::frameIsConstructor(context, frame))
							{
								funcDesc = [funcDesc stringByAppendingString:@"()"];
							}
							else
							{
								funcDesc = [NSString stringWithFormat:@"new %@()", funcDesc];
							}
							
						}
						else
						{
							funcDesc = @"<anonymous function>";
						}
					}
					else
					{
						funcDesc = @"<not a function frame>";
					}
					
					desc = [NSString stringWithFormat:@"(%@) %@", location, funcDesc];
				}
				else if (ooscript::frameIsDebugger(context, frame))
				{
					desc = @"<debugger frame>";
				}
				else
				{
					desc = @"<Oolite native>";
				}
				
				OOLog(@"script.javaScript.stackTrace", @"%2u %@", idx - 1, desc);
				
				if (gotProperties)
				{
					ooscript::Value thisVal;
					if (ooscript::frameThis(context, frame, &thisVal))
					{
						static BOOL haveThis = NO;
						static ooscript::PropertyId thisAtom;
						if (EXPECT_NOT(!haveThis))
						{
							ooscript::valueToId(context, ooscript::stringValue((ooscript::internString((context), "this"))), &thisAtom);
							haveThis = YES;
						}
						ooscript::Variable thisDesc = { .id = thisAtom, .value = thisVal, .flags = 0, .alias = ooscript::undefinedValue() };
						DumpVariable(context, &thisDesc);
					}
					
					// Dump arguments.
					unsigned i;
					for (i = 0; i < properties.length; i++)
					{
						ooscript::Variable *prop = &properties.vars[i];
						if (prop->flags & static_cast<unsigned>(ooscript::VariableFlag::Argument))  DumpVariable(context, prop);
					}
					
					// Dump locals.
					for (i = 0; i < properties.length; i++)
					{
						ooscript::Variable *prop = &properties.vars[i];
						if (prop->flags & static_cast<unsigned>(ooscript::VariableFlag::Variable))  DumpVariable(context, prop);
					}
					
					// Dump anything else.
					for (i = 0; i < properties.length; i++)
					{
						ooscript::Variable *prop = &properties.vars[i];
						if (!(prop->flags & (static_cast<unsigned>(ooscript::VariableFlag::Argument) | static_cast<unsigned>(ooscript::VariableFlag::Variable))))  DumpVariable(context, prop);
					}
					
					ooscript::destroyScopeVariables(context, &properties);
				}
			}
		}
		@catch (OOException *exception)
		{
			OOLog(kOOLogException, @"Exception during JavaScript stack trace: %@:%@", oo::NSStringFrom([exception name]), oo::NSStringFrom([exception reason]));
		}
		@catch (OOFoundationException *exception)
		{
			OOLog(kOOLogException, @"Exception during JavaScript stack trace: %@:%@", [exception name], [exception reason]);
		}
	}
}


namespace {
static const char *sConsoleScriptName;	// Lifetime is lifetime of script object, which is forever.
} // namespace
namespace {
static NSUInteger sConsoleEvalLineNo;
} // namespace


namespace {
static void GetLocationNameAndLine(ooscript::Context context, ooscript::StackFrame stackFrame, const char **name, NSUInteger *line)
{
	NSCParameterAssert(context != NULL && stackFrame != NULL && name != NULL && line != NULL);
	
	*name = NULL;
	*line = 0;
	
	ooscript::Script script = ooscript::frameScript(context, stackFrame);
	if (script != NULL)
	{
		*name = ooscript::scriptFilename(context, script);
		if (name != NULL)
		{
			*line = ooscript::frameLineNumber(context, stackFrame);
		}
	}
	else if (ooscript::frameIsDebugger(context, stackFrame))
	{
		*name = "<debugger frame>";
	}
}
} // namespace


NSString *OOJSDescribeLocation(ooscript::Context context, ooscript::StackFrame stackFrame)
{
	NSCParameterAssert(context != NULL && stackFrame != NULL);
	
	const char	*fileName;
	NSUInteger	lineNo;
	GetLocationNameAndLine(context, stackFrame, &fileName, &lineNo);
	if (fileName == NULL)  return nil;
	
	// If this stops working, we probably need to switch to strcmp().
	if (fileName == sConsoleScriptName && lineNo >= sConsoleEvalLineNo)  return @"<console input>";
	
	// Objectify it.
	NSString	*fileNameObj = [NSString stringWithUTF8String:fileName];
	if (fileNameObj == nil)  fileNameObj = [NSString stringWithCString:fileName encoding:NSISOLatin1StringEncoding];
	if (fileNameObj == nil)  return nil;
	
	NSString	*shortFileName = [fileNameObj lastPathComponent];
	if (![[shortFileName lowercaseString] isEqualToString:@"script.js"])  fileNameObj = shortFileName;
	
	return [NSString stringWithFormat:@"%@:%zu", fileNameObj, lineNo];
}


void OOJSMarkConsoleEvalLocation(ooscript::Context context, ooscript::StackFrame stackFrame)
{
	GetLocationNameAndLine(context, stackFrame, &sConsoleScriptName, &sConsoleEvalLineNo);
}
#endif


void OOJSInitJSIDCachePRIVATE(const char *name, ooscript::PropertyId *idCache)
{
	NSCParameterAssert(name != NULL && name[0] != '\0' && idCache != NULL);
	
	ooscript::Context context = OOJSAcquireContext();
	
	ooscript::String string = (ooscript::internString((context), name));
	if (EXPECT_NOT(string == NULL))
	{
		[OOException raise:OOGenericException format:"Failed to initialize JS ID cache for \"%s\".", name];
	}
	
	// The string is interned, so the engine's value-to-id conversion returns its atom id unchanged.
	if (EXPECT_NOT(!ooscript::valueToId(context, ooscript::stringValue(string), idCache)))
	{
		[OOException raise:OOGenericException format:"Failed to initialize JS ID cache for \"%s\".", name];
	}
	
	OOJSRelinquishContext(context);
}


ooscript::PropertyId cxx_OOJSIDFromString(const std::string &string)
{
	ooscript::Context context = OOJSAcquireContext();
	
	const std::u16string units = oo::utf8ToUtf16(string);
	ooscript::String jsString = (ooscript::internUCStringN((context), units.data(), units.size()));
	
	// The string is interned, so the engine's value-to-id conversion returns its atom id unchanged.
	ooscript::PropertyId result = ooscript::voidId();
	if (EXPECT(jsString != NULL) && !ooscript::valueToId(context, ooscript::stringValue(jsString), &result))  result = ooscript::voidId();
	
	OOJSRelinquishContext(context);
	
	return result;
}


std::optional<std::string> cxx_OOStringFromJSID(ooscript::PropertyId propID)
{
	ooscript::Context context = OOJSAcquireContext();
	
	ooscript::Value	value;
	std::optional<std::string>	result;
	if (ooscript::idToValue((context), (propID), &value))
	{
		result = cxx_OOStringFromJSString(context, (ooscript::valueToString((context), value)));
	}
	
	OOJSRelinquishContext(context);
	
	return result;
}


namespace {
static std::string CallerPrefix(const std::optional<std::string> &scriptClass, const std::optional<std::string> &function)
{
	if (!function)  return std::string();
	if (!scriptClass)  return *function + ": ";
	return *scriptClass + "." + *function + ": ";
}
} // namespace


void cxx_OOJSReportError(ooscript::Context context, const char *format, ...)
{
	va_list					args;

	va_start(args, format);
	cxx_OOJSReportErrorWithArguments(context, format, args);
	va_end(args);
}


void cxx_OOJSReportErrorForCaller(ooscript::Context context, const std::optional<std::string> &scriptClass, const std::optional<std::string> &function, const char *format, ...)
{
	va_list					args;

	@try
	{
		va_start(args, format);
		std::string msg = oo::str::vformat(format, args);
		va_end(args);

		cxx_OOJSReportError(context, "%s%s", CallerPrefix(scriptClass, function).c_str(), msg.c_str());
	}
	@catch (id exception)
	{
		// Squash any secondary errors during error handling.
	}
}


void cxx_OOJSReportErrorWithArguments(ooscript::Context context, const char *format, va_list args)
{
	NSCParameterAssert(ooscript::isInRequest((context)));

	@try
	{
		std::string msg = oo::str::vformat(format, args);
		ooscript::reportError((context), msg.c_str());
	}
	@catch (id exception)
	{
		// Squash any secondary errors during error handling.
	}
}


void OOJSReportWrappedException(ooscript::Context context, id exception)
{
	if (!ooscript::isExceptionPending((context)))
	{
		if ([exception isKindOfClass:[OOException class]])  cxx_OOJSReportError(context, "Native exception: %s", [(OOException *)exception reason]);
		else if ([exception isKindOfClass:[OOFoundationException class]])  cxx_OOJSReportError(context, "Native exception: %s", oo::DescriptionOf([(OOFoundationException *)exception reason]).c_str());
		else  cxx_OOJSReportError(context, "Unidentified native exception");
	}
	// Else, let the pending exception propagate.
}


#ifndef NDEBUG

void OOJSUnreachable(const char *function, const char *file, unsigned line)
{
	OOLog(@"fatal.unreachable", @"Supposedly unreachable statement reached in %s (%@:%u) -- terminating.", function, OOLogAbbreviatedFileName(file), line);
	abort();
}

#endif


void cxx_OOJSReportWarning(ooscript::Context context, const char *format, ...)
{
	va_list					args;

	va_start(args, format);
	cxx_OOJSReportWarningWithArguments(context, format, args);
	va_end(args);
}


void cxx_OOJSReportWarningForCaller(ooscript::Context context, const std::optional<std::string> &scriptClass, const std::optional<std::string> &function, const char *format, ...)
{
	va_list					args;

	@try
	{
		va_start(args, format);
		std::string msg = oo::str::vformat(format, args);
		va_end(args);

		cxx_OOJSReportWarning(context, "%s%s", CallerPrefix(scriptClass, function).c_str(), msg.c_str());
	}
	@catch (id exception)
	{
		// Squash any secondary errors during error handling.
	}
}


void cxx_OOJSReportWarningWithArguments(ooscript::Context context, const char *format, va_list args)
{
	@try
	{
		std::string msg = oo::str::vformat(format, args);
		ooscript::reportWarning((context), msg.c_str());
	}
	@catch (id exception)
	{
		// Squash any secondary errors during error handling.
	}
}


void OOJSReportBadPropertySelector(ooscript::Context context, ooscript::Object thisObj, ooscript::PropertyId propID, ooscript::PropertySpec *propertySpec)
{
	std::optional<std::string>	propName = cxx_OOStringFromJSPropertyIDAndSpec(context, propID, propertySpec);
	const char	*className = OOJSGetClass(context, thisObj)->name;

	// %@ of a nil name printed "(null)".
	cxx_OOJSReportError(context, "Invalid property identifier %s for instance of %s.", propName ? propName->c_str() : "(null)", className);
}


void OOJSReportBadPropertyValue(ooscript::Context context, ooscript::Object thisObj, ooscript::PropertyId propID, ooscript::PropertySpec *propertySpec, ooscript::Value value)
{
	std::optional<std::string>	propName = cxx_OOStringFromJSPropertyIDAndSpec(context, propID, propertySpec);
	const char	*className = OOJSGetClass(context, thisObj)->name;
	std::string	valueDesc = cxx_OOJSDescribeValue(context, value, YES);

	cxx_OOJSReportError(context, "Cannot set property %s of instance of %s to invalid value %s.", propName ? propName->c_str() : "(null)", className, valueDesc.c_str());
}


void cxx_OOJSReportBadArguments(ooscript::Context context, const std::optional<std::string> &scriptClass, const std::optional<std::string> &function, unsigned argc, ooscript::Value *argv, const std::optional<std::string> &message, const std::optional<std::string> &expectedArgsDescription)
{
	@try
	{
		std::string text = message ? *message : std::string("Invalid arguments");
		std::optional<std::string> parameters = cxx_OOJSStringWithJavaScriptParameters(argv, argc, context);
		text += " " + (parameters ? *parameters : std::string("(null)"));
		if (expectedArgsDescription)  text += " -- expected " + *expectedArgsDescription;

		cxx_OOJSReportErrorForCaller(context, scriptClass, function, "%s.", text.c_str());
	}
	@catch (id exception)
	{
		// Squash any secondary errors during error handling.
	}
}


void OOJSSetWarningOrErrorStackSkip(unsigned skip)
{
	sErrorHandlerStackSkip = skip;
}


BOOL cxx_OOJSArgumentListGetNumber(ooscript::Context context, const std::optional<std::string> &scriptClass, const std::optional<std::string> &function, unsigned argc, ooscript::Value *argv, double *outNumber, unsigned *outConsumed)
{
	if (OOJSArgumentListGetNumberNoError(context, argc, argv, outNumber, outConsumed))
	{
		return YES;
	}
	else
	{
		cxx_OOJSReportBadArguments(context, scriptClass, function, argc, argv,
									   std::string("Expected number, got"), std::nullopt);
		return NO;
	}
}


BOOL OOJSArgumentListGetNumberNoError(ooscript::Context context, unsigned argc, ooscript::Value *argv, double *outNumber, unsigned *outConsumed)
{
	OOJS_PROFILE_ENTER
	
	double					value;
	
	NSCParameterAssert(context != NULL && (argv != NULL || argc == 0) && outNumber != NULL);
	
	// Get value, if possible.
	if (EXPECT_NOT(!ooscript::valueToNumber((context), (argv[0]), &value) || isnan(value)))
	{
		if (outConsumed != NULL)  *outConsumed = 0;
		return NO;
	}
	
	// Success.
	*outNumber = value;
	if (outConsumed != NULL)  *outConsumed = 1;
	return YES;
	
	OOJS_PROFILE_EXIT
}


// The root-class JS glue for classes rooted on OOObject (ADR-0029); the same methods on the
// Foundation root class live in OOJavaScriptEngine+FoundationBridge.mm until gnustep-base goes.
@implementation OOObject (OOJavaScriptConversion)

- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context
{
	return ooscript::undefinedValue();
}


- (id) oo_jsClassName
{
	return nil;
}


- (id) oo_jsDescription
{
	return [self oo_jsDescriptionWithClassName:[self oo_jsClassName]];
}


- (id) oo_jsDescriptionWithClassName:(id)className
{
	OOJS_PROFILE_ENTER

	id						components = [self descriptionComponents];
	if (className == nil)  className = [[self class] description];

	// "%@" of each: oo::DescriptionOf prints the same text.
	if (components != nil)
	{
		return oo::NSStringFrom(oo::str::format("[%s %s]", oo::DescriptionOf(className).c_str(), oo::DescriptionOf(components).c_str()));
	}
	else
	{
		return oo::NSStringFrom(oo::str::format("[object %s]", oo::DescriptionOf(className).c_str()));
	}

	OOJS_PROFILE_EXIT
}


- (void) oo_clearJSSelf:(ooscript::Object)selfVal
{

}

@end


ooscript::Object OOJSObjectFromNativeObject(ooscript::Context context, id object)
{
	ooscript::Value value = OOJSValueFromNativeObject(context, object);
	ooscript::Object result = nullptr;
	if (ooscript::valueToObject((context), (value), &result))  return (result);
	return NULL;
}


@implementation OOJSValue

+ (id) valueWithJSValue:(ooscript::Value)value inContext:(ooscript::Context)context
{
	OOJS_PROFILE_ENTER
	
	return [[[self alloc] initWithJSValue:value inContext:context] autorelease];
	
	OOJS_PROFILE_EXIT
}


+ (id) valueWithJSObject:(ooscript::Object)object inContext:(ooscript::Context)context
{
	OOJS_PROFILE_ENTER
	
	return [[[self alloc] initWithJSObject:object inContext:context] autorelease];
	
	OOJS_PROFILE_EXIT
}


- (id) initWithJSValue:(ooscript::Value)value inContext:(ooscript::Context)context
{
	OOJS_PROFILE_ENTER
	
	self = [super init];
	if (self != nil)
	{
		BOOL tempCtxt = NO;
		if (context == NULL)
		{
			context = OOJSAcquireContext();
			tempCtxt = YES;
		}
		
		_val = value;
		if (!ooscript::isUndefined(_val))
		{
			ooscript::addNamedValueRoot((context), (&_val), "OOJSValue");
			
			oo::NotificationCenter::defaultCenter().addObserver(self, kOOJavaScriptEngineWillResetNotificationName,
																[OOJavaScriptEngine sharedEngine],
																[self](const oo::Notification &) { [self deleteJSValue]; });
		}
		
		if (tempCtxt)  OOJSRelinquishContext(context);
	}
	return self;
	
	OOJS_PROFILE_EXIT
}


- (id) initWithJSObject:(ooscript::Object)object inContext:(ooscript::Context)context
{
	return [self initWithJSValue:ooscript::objectValue(object) inContext:context];
}


- (void) deleteJSValue
{
	if (!ooscript::isUndefined(_val))
	{
		ooscript::Context context = OOJSAcquireContext();
		ooscript::removeValueRoot((context), (&_val));
		OOJSRelinquishContext(context);
		
		_val = ooscript::undefinedValue();
		oo::NotificationCenter::defaultCenter().removeObserver(self, kOOJavaScriptEngineWillResetNotificationName,
																[OOJavaScriptEngine sharedEngine]);
	}
}


- (void) dealloc
{
	[self deleteJSValue];
	[super dealloc];
}


- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context
{
	return _val;
}

@end


void OOJSStrLiteralCachePRIVATE(const char *string, ooscript::Value *strCache, BOOL *inited)
{
	NSCParameterAssert(string != NULL && strCache != NULL && inited != NULL && !*inited);
	
	ooscript::Context context = OOJSAcquireContext();
	
	ooscript::String jsString = (ooscript::internString((context), string));
	if (EXPECT_NOT(string == NULL))
	{
		[OOException raise:OOGenericException format:"Failed to initialize JavaScript string literal cache for \"%s\".", cxx_OOJSEscapedForJavaScriptLiteral(string != NULL ? std::string_view(string) : std::string_view()).c_str()];
	}
	
	*strCache = ooscript::stringValue(jsString);
	*inited = YES;
	
	OOJSRelinquishContext(context);
}


std::optional<std::string> cxx_OOStringFromJSString(ooscript::Context context, ooscript::String string)
{
	OOJS_PROFILE_ENTER
	
	if (EXPECT_NOT(string == NULL))  return std::nullopt;
	
	size_t length;
	const ooscript::Char16 *chars = ooscript::getStringCharsAndLength((context), (string), &length);
	
	if (EXPECT(chars != NULL))
	{
		return oo::utf16ToUtf8(std::u16string_view(chars, length));
	}
	else
	{
		return std::nullopt;
	}
	
	OOJS_PROFILE_EXIT_VAL(std::nullopt)
}


std::optional<std::string> cxx_OOStringFromJSValueEvenIfNull(ooscript::Context context, ooscript::Value value)
{
	OOJS_PROFILE_ENTER
	
	NSCParameterAssert(context != NULL && ooscript::isInRequest((context)));
	
	ooscript::String string = (ooscript::valueToString((context), (value)));	// Calls the value's toString method if needed.
	return cxx_OOStringFromJSString(context, string);
	
	OOJS_PROFILE_EXIT_VAL(std::nullopt)
}


std::optional<std::string> cxx_OOStringFromJSValue(ooscript::Context context, ooscript::Value value)
{
	OOJS_PROFILE_ENTER
	
	if (EXPECT(!ooscript::isNull(value) && !ooscript::isUndefined(value)))
	{
		return cxx_OOStringFromJSValueEvenIfNull(context, value);
	}
	return std::nullopt;
	
	OOJS_PROFILE_EXIT_VAL(std::nullopt)
}


std::optional<std::string> cxx_OOStringFromJSPropertyIDAndSpec(ooscript::Context context, ooscript::PropertyId propID, ooscript::PropertySpec *propertySpec)
{
	if (ooscript::isStringId(propID))
	{
		return cxx_OOStringFromJSString(context, ooscript::idToString(propID));
	}
	else if (ooscript::isInt32Id(propID) && propertySpec != NULL)
	{
		int tinyid = ooscript::idToInt32(propID);
		
		while (propertySpec->name != NULL)
		{
			if (propertySpec->tinyid == tinyid)  return std::string(propertySpec->name);
			propertySpec++;
		}
	}
	
	ooscript::Value value;
	if (!ooscript::idToValue((context), (propID), (&value)))  return std::string("unknown");
	return cxx_OOStringFromJSString(context, (ooscript::valueToString((context), (value))));
}


namespace {
static std::string DescribeValue(ooscript::Context context, ooscript::Value value, BOOL abbreviateObjects, BOOL recursing)
{
	OOJS_PROFILE_ENTER
	
	NSCParameterAssert(context != NULL && ooscript::isInRequest((context)));
	
	if (OOJSValueIsFunction(context, value))
	{
		ooscript::String name = (ooscript::getFunctionId(ooscript::valueToFunction((context), (value))));
		if (name != NULL)
		{
			// "function %@": a nil name printed "(null)".
			std::optional<std::string> nameString = cxx_OOStringFromJSString(context, name);
			return "function " + (nameString ? *nameString : std::string("(null)"));
		}
		else  return "function";
	}
	
	std::optional<std::string>	result;
	ooscript::ClassDef				*valueClass = NULL;
	OOJavaScriptEngine	*jsEng = [OOJavaScriptEngine sharedEngine];
	
	if (ooscript::isObjectOrNull(value) && !ooscript::isNull(value))
	{
		valueClass = OOJSGetClass(context, ooscript::toObject(value));
	}
	
	// Convert String objects to strings.
	if (valueClass == [jsEng stringClass])
	{
		value = ooscript::stringValue((ooscript::valueToString((context), (value))));
	}
	
	if (ooscript::isString(value))
	{
		enum : std::uint8_t { kMaxLength = 200 };
		
		ooscript::String string = ooscript::toString(value);
		size_t length;
		const ooscript::Char16 *chars = ooscript::getStringCharsAndLength((context), (string), &length);
		
		// Truncated to kMaxLength UTF-16 units before conversion, as the old code cut its string.
		std::string truncated = (chars != NULL) ? oo::utf16ToUtf8(std::u16string_view(chars, MIN(length, (size_t)kMaxLength))) : std::string();
		result = "\"" + cxx_OOJSEscapedForJavaScriptLiteral(truncated) + ((length > kMaxLength) ? "..." : "") + "\"";
	}
	else if (valueClass == [jsEng arrayClass])
	{
		// Descibe up to four elements of an array.
		uint32_t count;
		ooscript::Object obj = ooscript::toObject(value);
		if (ooscript::getArrayLength((context), (obj), &count))
		{
			if (!recursing)
			{
				std::string arrayDesc = "[";
				uint32_t i, effectiveCount = MIN(count, (uint32_t)4);
				for (i = 0; i < effectiveCount; i++)
				{
					ooscript::Value item;
					std::string itemDesc = "?";
					if (ooscript::getElement((context), (obj), i, (&item)))
					{
						itemDesc = DescribeValue(context, item, YES /* always abbreviate objects in arrays */, YES);
					}
					if (i != 0)  arrayDesc += ", ";
					arrayDesc += itemDesc;
				}
				if (effectiveCount != count)
				{
					arrayDesc += oo::str::format(", ... <%u items total>]", count);
				}
				else
				{
					arrayDesc += "]";
				}
				
				result = arrayDesc;
			}
			else
			{
				result = oo::str::format("[<%u items>]", count);
			}
		}
		else
		{
			result = "[...]";
		}

	}
	
	if (!result)
	{
		result = cxx_OOStringFromJSValueEvenIfNull(context, value);
		
		if (abbreviateObjects && valueClass == [jsEng objectClass] && result && *result == "[object Object]")
		{
			result = "{...}";
		}
		
		if (!result)  result = "?";
	}
	
	return *result;
	
	OOJS_PROFILE_EXIT_VAL(std::string())
}
} // namespace


std::string cxx_OOJSDescribeValue(ooscript::Context context, ooscript::Value value, BOOL abbreviateObjects)
{
	return DescribeValue(context, value, abbreviateObjects, NO);
}


std::optional<std::string> cxx_OOJSStringWithJavaScriptParameters(ooscript::Value *params, unsigned count, ooscript::Context context)
{
	OOJS_PROFILE_ENTER
	
	if (params == NULL && count != 0) return std::nullopt;
	
	unsigned					i;
	std::string				result = "(";
	
	for (i = 0; i < count; ++i)
	{
		if (i != 0)  result += ", ";
		result += cxx_OOJSDescribeValue(context, params[i], NO);
	}
	
	result += ")";
	return result;
	
	OOJS_PROFILE_EXIT_VAL(std::nullopt)
}


std::optional<std::string> cxx_OOJSConcatenationOfStringsFromJavaScriptValues(ooscript::Value *values, size_t count, const std::string &separator, ooscript::Context context)
{
	OOJS_PROFILE_ENTER
	
	size_t					i;
	std::optional<std::string>	result;
	
	if (count < 1) return std::nullopt;
	if (values == NULL) return std::nullopt;
	
	for (i = 0; i != count; ++i)
	{
		std::optional<std::string> element = cxx_OOStringFromJSValueEvenIfNull(context, values[i]);
		if (!result)  result = element;	// a nil element left the result nil, as -mutableCopy of nil did
		else
		{
			*result += separator;
			if (element)  *result += *element;
		}
	}
	
	return result;
	
	OOJS_PROFILE_EXIT_VAL(std::nullopt)
}


std::string cxx_OOJSEscapedForJavaScriptLiteral(std::string_view string)
{
	// Byte-wise over UTF-8: every escaped character is ASCII, so multi-byte sequences pass through
	// unchanged, as the UTF-16 units they encode did.
	std::string result;
	result.reserve(string.size());
	
	for (char c : string)
	{
		switch (c)
		{
			case '\\':
				result += "\\\\";
				break;

			case '\b':
				result += "\\b";
				break;

			case '\f':
				result += "\\f";
				break;

			case '\n':
				result += "\\n";
				break;

			case '\r':
				result += "\\r";
				break;

			case '\t':
				result += "\\t";
				break;

			case '\v':
				result += "\\v";
				break;

			case '\'':
				result += "\\\'";
				break;
				
			case '\"':
				result += "\\\"";
				break;
			
			default:
				result += c;
		}
	}
	return result;
}


@implementation OONativeVector (OOJavaScriptConversion)

- (ooscript::Value)oo_jsValueInContext:(ooscript::Context)context
{
	ooscript::Value value = ooscript::undefinedValue();
	VectorToJSValue(context, v, &value);
	return value;
}

@end


@implementation OONull

+ (OONull *) null
{
	static OONull *sNull = nil;
	if (sNull == nil)  sNull = [[OONull alloc] init];
	return sNull;
}


- (id) copyWithZone:(OOZone *)zone
{
	return [self retain];
}


- (id) description	// shared selector (proposed ADR-0043)
{
	return oo::NSStringFrom("<null>");
}


- (ooscript::Value)oo_jsValueInContext:(ooscript::Context)context
{
	return ooscript::nullValue();
}

@end


bool OOJSUnconstructableConstruct(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	ooscript::Function function = ooscript::valueToFunction((context), oojsArgs.callee());
	std::optional<std::string> name = cxx_OOStringFromJSString(context, (ooscript::getFunctionId(function)));

	// %@ of a nil name printed "(null)".
	cxx_OOJSReportError(context, "%s cannot be used as a constructor.", name ? name->c_str() : "(null)");
	return NO;
	
	OOJS_NATIVE_EXIT
}


void OOJSObjectWrapperFinalize(ooscript::Context context, ooscript::Object thisObj)
{
	OOJS_PROFILE_ENTER
	
	id object = (id)ooscript::getPrivate((context), (thisObj));
	if (object != nil)
	{
		[[object weakRefUnderlyingObject] oo_clearJSSelf:thisObj];
		[object release];
		ooscript::setPrivate((context), (thisObj), nil);
	}
	
	OOJS_PROFILE_EXIT_VOID
}


bool OOJSObjectWrapperToString(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	id						object = nil;
	id						description = nil;	// the object's own -oo_jsDescription / -description
	ooscript::ClassDef					*jsClass = NULL;

	object = OOJSNativeObjectFromJSObject(context, OOJS_THIS);
	if (object != nil)
	{
		description = [object oo_jsDescription];
		if (description == nil)  description = [object description];
	}
	if (description == nil)
	{
		jsClass = OOJSGetClass(context, OOJS_THIS);
		if (jsClass != NULL)
		{
			description = oo::NSStringFrom(oo::str::format("[object %s]", jsClass->name));
		}
	}
	if (description == nil)  description = oo::NSStringFrom("[object]");
	
	OOJS_RETURN_OBJECT(description);
	
	OOJS_NATIVE_EXIT
}


BOOL JSFunctionPredicate(Entity *entity, void *parameter)
{
	OOJS_PROFILE_ENTER
	
	JSFunctionPredicateParameter	*param = static_cast<JSFunctionPredicateParameter*>(parameter);
	ooscript::Value							args[1];
	ooscript::Value							rval = ooscript::undefinedValue();
	bool							result = NO;
	
	NSCParameterAssert(entity != nil && param != NULL);
	NSCParameterAssert(param->context != NULL && ooscript::isInRequest((param->context)));
	NSCParameterAssert(OOJSValueIsFunction(param->context, param->function));
	
	if (EXPECT_NOT(param->errorFlag))  return NO;
	
	args[0] = [entity oo_jsValueInContext:param->context];	// entity is required to be non-nil (asserted above), so oo_jsValueInContext: is safe.
	
	OOJSStartTimeLimiter();
	OOJSResumeTimeLimiter();
	BOOL success = ooscript::callFunctionValue((param->context), (param->jsThis), (param->function), 1, (args), (&rval));
	OOJSPauseTimeLimiter();
	OOJSStopTimeLimiter();
	
	if (success)
	{
		bool boolResult = false;
		if (!ooscript::valueToBoolean((param->context), (rval), &boolResult))  boolResult = false;
		result = static_cast<bool>(static_cast<unsigned char>(boolResult));
		if (ooscript::isExceptionPending((param->context)))
		{
			ooscript::reportPendingException((param->context));
			param->errorFlag = YES;
		}
	}
	else
	{
		param->errorFlag = YES;
	}
	
	return result;
	
	OOJS_PROFILE_EXIT
}


BOOL JSEntityIsJavaScriptVisiblePredicate(Entity *entity, void * /*parameter*/)
{
	OOJS_PROFILE_ENTER
	
	return [entity isVisibleToScripts];
	
	OOJS_PROFILE_EXIT
}


BOOL JSEntityIsJavaScriptSearchablePredicate(Entity *entity, void * /*parameter*/)
{
	OOJS_PROFILE_ENTER
	
	if (![entity isVisibleToScripts])  return NO;
	if ([entity isShip])
	{
		if ([entity isSubEntity])  return NO;
		if ([entity status] == STATUS_COCKPIT_DISPLAY)  return NO;	// Demo ship
		return YES;
	}
	else if ([entity isPlanet])
	{
		switch ([(OOPlanetEntity *)entity planetType])
		{
			case STELLAR_TYPE_MOON:
			case STELLAR_TYPE_NORMAL_PLANET:
			case STELLAR_TYPE_SUN:
				return YES;
				
#if !NEW_PLANETS
			case STELLAR_TYPE_ATMOSPHERE:
#endif
			case STELLAR_TYPE_MINIATURE:
				return NO;
		}
	}
	
	return YES;	// would happen if we added a new script-visible class
	
	OOJS_PROFILE_EXIT
}


BOOL JSEntityIsDemoShipPredicate(Entity *entity, void * /*parameter*/)
{
	return ([entity isVisibleToScripts] && [entity isShip] && [entity status] == STATUS_COCKPIT_DISPLAY && ![entity isSubEntity]);
}

namespace {
// JS subclass -> superclass, by pointer. Was a non-owned pointer map table (bead oo-3rb.20).
static std::unordered_map<const ooscript::ClassDef *, ooscript::ClassDef *> *sRegisteredSubClasses;
} // namespace

void OOJSRegisterSubclass(ooscript::ClassDef *subclass, ooscript::ClassDef *superclass)
{
	NSCParameterAssert(subclass != NULL && superclass != NULL);
	
	if (sRegisteredSubClasses == NULL)
	{
		sRegisteredSubClasses = new std::unordered_map<const ooscript::ClassDef *, ooscript::ClassDef *>;
	}

	NSCAssert(sRegisteredSubClasses->count(subclass) == 0, @"A JS class cannot be registered as a subclass of multiple classes.");

	sRegisteredSubClasses->emplace(subclass, superclass);
}


namespace {
static void UnregisterSubclasses(void)
{
	delete sRegisteredSubClasses;
	sRegisteredSubClasses = NULL;
}
} // namespace


BOOL OOJSIsSubclass(ooscript::ClassDef *putativeSubclass, ooscript::ClassDef *superclass)
{
	NSCParameterAssert(putativeSubclass != NULL && superclass != NULL);
	NSCAssert(sRegisteredSubClasses != NULL, @"OOJSIsSubclass() called before any subclasses registered (disallowed for hot path efficiency).");
	
	do
	{
		if (putativeSubclass == superclass)  return YES;
		
		auto registered = sRegisteredSubClasses->find(putativeSubclass);
		putativeSubclass = (registered != sRegisteredSubClasses->end()) ? registered->second : NULL;
	}
	while (putativeSubclass != NULL);
	
	return NO;
}


BOOL OOJSObjectGetterImplPRIVATE(ooscript::Context context, ooscript::Object object, ooscript::ClassDef *requiredJSClass,
#ifndef NDEBUG
	Class requiredObjCClass, const char *name,
#endif
	id *outObject)
{
#ifndef NDEBUG
	OOJS_PROFILE_ENTER_NAMED(name)
	NSCParameterAssert(requiredObjCClass != Nil);
	NSCParameterAssert(context != NULL && object != NULL && requiredJSClass != NULL && outObject != NULL);
#else
	OOJS_PROFILE_ENTER
#endif
	
	/*
		Ensure it's a valid type of JS object. This is absolutely necessary,
		because if we don't check it we'll crash trying to get the private
		field of something that isn't an ObjC object wrapper - for example,
		Ship.setAI.call(new Vector3D, "") is valid JavaScript.
		
		Alternatively, we could abuse JSCLASS_PRIVATE_IS_NSISUPPORTS as a
		flag for ObjC object wrappers (SpiderMonkey only uses it internally
		in a debug function we don't use), but we'd still need to do an
		Objective-C class test, and I don't think that's any faster.
		TODO: profile.
	*/
	ooscript::ClassDef *actualClass = OOJSGetClass(context, object);
	if (EXPECT_NOT(!OOJSIsSubclass(actualClass, requiredJSClass)))
	{
		std::optional<std::string> got = cxx_OOStringFromJSValue(context, ooscript::objectValue(object));
		cxx_OOJSReportError(context, "Native method expected %s, got %s.", requiredJSClass->name, got ? got->c_str() : "(null)");
		return NO;
	}
	NSCAssert(static_cast<std::uint32_t>(actualClass->flags) & static_cast<std::uint32_t>(ooscript::ClassFlag::HasPrivate), @"Native object accessor requires JS class with private storage.");
	
	// Get the underlying object.
	*outObject = [(id)ooscript::getPrivate((context), (object)) weakRefUnderlyingObject];
	
#ifndef NDEBUG
	// Double-check that the underlying object is of the expected ObjC class.
	if (EXPECT_NOT(*outObject != nil && ![*outObject isKindOfClass:requiredObjCClass]))
	{
		cxx_OOJSReportError(context, "Native method expected %s from %s and got correct JS type but incorrect native object %s", oo::DescriptionOf(requiredObjCClass).c_str(), requiredJSClass->name, oo::DescriptionOf(*outObject).c_str());
		return NO;
	}
#endif
	
	return YES;
	
	OOJS_PROFILE_EXIT
}


oo::PList OOJSDictionaryFromJSValue(ooscript::Context context, ooscript::Value value)
{
	OOJS_PROFILE_ENTER

	ooscript::Object object = nullptr;
	if (EXPECT_NOT(!ooscript::valueToObject((context), (value), &object) || object == nullptr))
	{
		return oo::PList();
	}
	return cxx_OOJSDictionaryFromJSObject(context, (object));

	OOJS_PROFILE_EXIT_VAL(oo::PList())
}


oo::PList cxx_OOJSDictionaryFromJSObject(ooscript::Context context, ooscript::Object object)
{
	OOJS_PROFILE_ENTER

	ooscript::IdArray			*ids = NULL;
	std::size_t					i;
	oo::PList::Dict				result;
	bool						hasIntegerKey = false;
	ooscript::Value						value = ooscript::undefinedValue();

	ids = ooscript::enumerate((context), (object));
	if (EXPECT_NOT(ids == NULL))
	{
		return oo::PList();
	}

	for (i = 0; i != ids->length; ++i)
	{
		ooscript::PropertyId thisID = (ids->ids[i]);
		std::optional<std::string>	key;
		bool						isIntegerKey = false;

		if (ooscript::isStringId(thisID))
		{
			key = cxx_OOStringFromJSString(context, ooscript::idToString(thisID));
		}
		else if (ooscript::isInt32Id(thisID))
		{
			/*	The Foundation form (OOJSDictionaryFromJSObject, in the bridge) keeps
				an int32 property id as a number key; oo::PListFrom() made a dictionary
				with a number key a null PList, so such an entry makes the whole result
				null here. (CIM 15/2/13 asked whether the key should be a string.)
			*/
			isIntegerKey = true;
		}

		const bool hasKey = key.has_value() || isIntegerKey;
		value = ooscript::undefinedValue();
		if (hasKey && !ooscript::lookupPropertyById((context), (object), (thisID), (&value)))  value = ooscript::undefinedValue();

		if (hasKey && !ooscript::isUndefined(value))
		{
			id objValue = OOJSNativeObjectFromJSValue(context, value);
			if (objValue != nil)
			{
				if (isIntegerKey)  hasIntegerKey = true;
				else  result.insert_or_assign(*key, oo::PListFrom(objValue));
			}
		}
	}

	ooscript::destroyIdArray((context), ids);
	if (hasIntegerKey)  return oo::PList();
	return oo::PList(std::move(result));

	OOJS_PROFILE_EXIT_VAL(oo::PList())
}


oo::PList OOJSDictionaryFromStringTable(ooscript::Context context, ooscript::Value tableValue)
{
	OOJS_PROFILE_ENTER

	ooscript::Object				tableObject = nullptr;
	ooscript::IdArray			*ids;
	std::size_t					i;
	oo::PList::Dict				result;
	ooscript::Value						value = ooscript::undefinedValue();

	if (EXPECT_NOT(ooscript::isNull(tableValue) || !ooscript::valueToObject((context), (tableValue), &tableObject)))
	{
		return oo::PList();
	}

	ids = ooscript::enumerate((context), tableObject);
	if (EXPECT_NOT(ids == NULL))
	{
		return oo::PList();
	}

	for (i = 0; i != ids->length; ++i)
	{
		ooscript::PropertyId thisID = (ids->ids[i]);
		std::optional<std::string>	key;

		if (ooscript::isStringId(thisID))
		{
			key = cxx_OOStringFromJSString(context, ooscript::idToString(thisID));
		}

		value = ooscript::undefinedValue();
		if (key && !ooscript::lookupPropertyById((context), tableObject, (thisID), (&value)))  value = ooscript::undefinedValue();

		if (key && !ooscript::isUndefined(value))
		{
			std::optional<std::string> string = cxx_OOStringFromJSValueEvenIfNull(context, value);

			if (string)
			{
				result.insert_or_assign(*key, oo::PList(std::move(*string)));
			}
		}
	}

	ooscript::destroyIdArray((context), ids);
	return oo::PList(std::move(result));

	OOJS_PROFILE_EXIT_VAL(oo::PList())
}


namespace {
static std::unordered_map<const ooscript::ClassDef *, OOJSClassConverterCallback> *sObjectConverters;
} // namespace


id OOJSNativeObjectFromJSValue(ooscript::Context context, ooscript::Value value)
{
	OOJS_PROFILE_ENTER
	
	if (ooscript::isNull(value) || ooscript::isUndefined(value))  return nil;
	
	if (ooscript::isInt32(value))
	{
		// +numberWithLongLong: where this was +numberWithInt: (same value; bead oo-3rb.202).
		return oo::ObjectFromPList(oo::PList::signedInteger(ooscript::toInt32(value)));
	}
	if (ooscript::isDouble(value))
	{
		return oo::ObjectFromPList(oo::PList(ooscript::toDouble(value)));
	}
	if (ooscript::isBoolean(value))
	{
		return oo::ObjectFromPList(oo::PList(static_cast<bool>(ooscript::toBoolean(value))));
	}
	if (ooscript::isString(value))
	{
		return oo::NSStringOrNil(cxx_OOStringFromJSValue(context, value));
	}
if (ooscript::isObjectOrNull(value))
	{
		return OOJSNativeObjectFromJSObject(context, ooscript::toObject(value));
	}
	return nil;
	
	OOJS_PROFILE_EXIT
}


id OOJSNativeObjectFromJSObject(ooscript::Context context, ooscript::Object tableObject)
{
	OOJS_PROFILE_ENTER
	
	OOJSClassConverterCallback converter = NULL;
	ooscript::ClassDef					*tableClass = NULL;

	if (tableObject == NULL)  return nil;

	tableClass = OOJSGetClass(context, tableObject);
	if (sObjectConverters != NULL)
	{
		auto found = sObjectConverters->find(tableClass);
		if (found != sObjectConverters->end())  converter = found->second;
	}
	if (converter != NULL)
	{
		return converter(context, tableObject);
	}
	return nil;

	OOJS_PROFILE_EXIT
}


id OOJSNativeObjectOfClassFromJSValue(ooscript::Context context, ooscript::Value value, Class requiredClass)
{
	id result = OOJSNativeObjectFromJSValue(context, value);
	if (![result isKindOfClass:requiredClass])  result = nil;
	return result;
}


id OOJSNativeObjectOfClassFromJSObject(ooscript::Context context, ooscript::Object object, Class requiredClass)
{
	id result = OOJSNativeObjectFromJSObject(context, object);
	if (![result isKindOfClass:requiredClass])  result = nil;
	return result;
}


id OOJSBasicPrivateObjectConverter(ooscript::Context context, ooscript::Object object)
{
	id						result;
	
	/*	This will do the right thing - for non-OOWeakReferences,
		weakRefUnderlyingObject returns the object itself. For nil, of course,
		it returns nil.
	*/
	result = (id)ooscript::getPrivate((context), (object));
	return [result weakRefUnderlyingObject];
}


void OOJSRegisterObjectConverter(ooscript::ClassDef *theClass, OOJSClassConverterCallback converter)
{
	if (theClass == NULL)  return;
	if (sObjectConverters == NULL)  sObjectConverters = new std::unordered_map<const ooscript::ClassDef *, OOJSClassConverterCallback>;

	if (converter != NULL)
	{
		(*sObjectConverters)[theClass] = converter;
	}
	else
	{
		sObjectConverters->erase(theClass);
	}
}


namespace {
static void UnregisterObjectConverters(void)
{
	delete sObjectConverters;
	sObjectConverters = NULL;
}
} // namespace


namespace {
static id JSArrayConverter(ooscript::Context context, ooscript::Object array)
{
	uint32_t						i, count;
	std::vector<id>				values;
	ooscript::Value						value = ooscript::undefinedValue();
	id							object = nil;

	// Convert a JS array to a native array by calling OOJSNativeObjectFromJSValue() on all its elements.
	if (!ooscript::isArrayObject((context), (array))) return nil;
	if (!ooscript::getArrayLength((context), (array), &count)) return nil;

	values.reserve(count);
	for (i = 0; i != count; ++i)
	{
		value = ooscript::undefinedValue();
		if (!ooscript::getElement((context), (array), i, (&value)))  value = ooscript::undefinedValue();

		object = OOJSNativeObjectFromJSValue(context, value);
		if (object == nil)  object = [OONull null];
		values.push_back(object);
	}

	return oo::NSArrayFromObjects(values);
}
} // namespace


namespace {
static id JSStringConverter(ooscript::Context context, ooscript::Object object)
{
	return oo::NSStringOrNil(cxx_OOStringFromJSValue(context, ooscript::objectValue(object)));
}
} // namespace


namespace {
static id JSNumberConverter(ooscript::Context context, ooscript::Object object)
{
	double value;
	if (ooscript::valueToNumber((context), (ooscript::objectValue(object)), &value))
	{
		return oo::ObjectFromPList(oo::PList(value));
	}
	return nil;
}
} // namespace


namespace {
static id JSBooleanConverter(ooscript::Context context, ooscript::Object object)
{
	/*	Fun With JavaScript: Boolean(false) is a truthy value, since it's a
		non-null object. valueToBoolean() therefore reports true.
		However, Boolean objects are transformed to numbers sanely, so this
		works.
	*/
	double value;
	if (ooscript::valueToNumber((context), (ooscript::objectValue(object)), &value))
	{
		return oo::ObjectFromPList(oo::PList(value != 0));
}
	return nil;
}
} // namespace
