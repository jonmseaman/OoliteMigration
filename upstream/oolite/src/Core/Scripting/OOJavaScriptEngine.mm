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

#include <jsdbgapi.h>
#import "OOJavaScriptEngine.h"
#import "OOJSEngineTimeManagement.h"
#import "OOJSScript.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar): every directly spelled JS_* call becomes its ooscript::
	equivalent, byte-identical façade <-> jsapi views local to this translation unit stand in
	for the reinterpret_casts the exemplar uses, and the OOJS_* argument-marshalling macros
	(OOJS_ARGV, OOJS_THIS, OOJS_RVAL, OOJS_NATIVE_ENTER/EXIT) are unchanged, since they are
	spelled "OOJS_...", never literally "JS_...", and are out of scope for this sweep.

	Left untouched, per ooscript/README.md's "Not in the façade, and why" (engine names below are
	spelled per that header's own convention, without their engine prefix): the debugger
	stack-frame walk (FrameIterator, GetFrame*, Is*Frame, GetPropertyDescArray /
	PutPropertyDescArray, GetScriptFilename, PCToLineNumber) inside OOJSDumpStack,
	GetLocationNameAndLine and DumpVariable -- engine-specific by nature, called out by name in
	that list alongside OOJSEngineDebuggerHelpers.mm and OOJSEngineTimeManagement.m, which the
	same functions are shared with. SetDebuggerHandler and its JSTrapStatus/JSDebuggerHandler
	callback type are the same debugger-frame family for the identical reason.
	EnterLocalRootScope / LeaveLocalRootScopeWithResult are also called out there as superseded
	by explicit roots; both call sites (JSNewNSArrayValue, JSNewNSDictionaryValue) are retired
	in this bead the way README's own note describes: ooscript::RootedValue replaces the
	root-the-return-value bracket around the value about to be handed to the caller.
	The struct-typed-jsval / jschar / uintN / jsdouble / value-macro bit-layout
	macros, JSClass/JSPropertySpec/JSFunctionSpec (JSObjectGetterImplPRIVATE and friends, not
	yet on ClassDef/PropertySpec/FunctionSpec) and the debug-build magic-value switch are all,
	per the exemplar's own scope note, engine ABI detail that already compiles as C and is out
	of scope for this bead.

	Three façade functions did not exist before this bead and are added alongside it
	(ooscript::internUCStringN, ooscript::clearScope, ooscript::setCStringsAreUTF8): each is a
	1:1, no-behaviour-change wrap of the JS_* function of the same name this file calls, using
	the same calling convention, exactly as JSEngine.hpp's header comment requires of every
	façade function. Two more, ooscript::isThreadsafeBuild and ooscript::gcZealSupported, are
	added for a different reason: this file used engine-macro preprocessor guards around its
	thread-safety and GC-zeal branches, which the deny-list forbids spelling directly in a
	retargeted file; each new function reports the same build-time true/false value the macro
	had, implemented in JSEngine_spidermonkey.cpp (the one translation unit exempt from the
	deny-list, since its job is to call the engine), so the two guarded blocks below become
	runtime `if`s with identical behaviour rather than being deleted or left spelling the macro.
*/

// Byte-identical façade <-> jsapi views, local to this translation unit (JSEngine.hpp: Value/
// PropertyId and the handle types are byte copies of jsval/jsid/JS*; see OOJSVector.mm's
// OOJSFCX/OOJSFVALP/OOJSFOBJ for the same, non-exported, pattern).
namespace {
static inline ooscript::Context   OOJSFCX(JSContext *cx)   { return reinterpret_cast<ooscript::Context>(cx); }
} // namespace
namespace {
static inline JSContext          *OOJSRCX(ooscript::Context cx)   { return reinterpret_cast<JSContext*>(cx); }
} // namespace
namespace {
static inline ooscript::Object    OOJSFOBJ(JSObject *o)    { return reinterpret_cast<ooscript::Object>(o); }
} // namespace
namespace {
static inline JSObject           *OOJSROBJ(ooscript::Object o) { return reinterpret_cast<JSObject*>(o); }
} // namespace
namespace {
static inline ooscript::Value    *OOJSFVALP(jsval *v)      { return reinterpret_cast<ooscript::Value*>(v); }
} // namespace
namespace {
static inline ooscript::Value     OOJSFVAL(jsval v)        { ooscript::Value r; std::memcpy(&r, &v, sizeof r); return r; }
} // namespace
namespace {
static inline jsval               OOJSRVALV(ooscript::Value v) { jsval r; std::memcpy(&r, &v, sizeof r); return r; }
} // namespace
namespace {
static inline ooscript::String    OOJSFSTR(JSString *s)    { return reinterpret_cast<ooscript::String>(s); }
} // namespace
namespace {
static inline const unichar *OOJSRUCHARS(const ooscript::Char16 *s)  { return reinterpret_cast<const unichar*>(s); }
} // namespace
namespace {
static inline const jschar *OOJSRCHARS(const ooscript::Char16 *s)  { return reinterpret_cast<const jschar*>(s); }
} // namespace
namespace {
static inline JSString           *OOJSRSTR(ooscript::String s) { return reinterpret_cast<JSString*>(s); }
} // namespace
namespace {
static inline ooscript::Runtime   OOJSFRT(JSRuntime *rt)   { return reinterpret_cast<ooscript::Runtime>(rt); }
} // namespace
namespace {
static inline JSRuntime          *OOJSRRT(ooscript::Runtime rt) { return reinterpret_cast<JSRuntime*>(rt); }
} // namespace
namespace {
static inline ooscript::PropertyId OOJSFJSID(jsid id)      { ooscript::PropertyId r; std::memcpy(&r, &id, sizeof r); return r; }
} // namespace
namespace {
static inline jsid                OOJSRJSID(ooscript::PropertyId id) { jsid r; std::memcpy(&r, &id, sizeof r); return r; }
} // namespace

#import "OOCollectionExtractors.h"
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

JSContext					*gOOJSMainThreadContext = NULL;


NSString * const kOOJavaScriptEngineWillResetNotification = @"org.aegidian.oolite OOJavaScriptEngine will reset";
NSString * const kOOJavaScriptEngineDidResetNotification = @"org.aegidian.oolite OOJavaScriptEngine did reset";


#if OOJSENGINE_MONITOR_SUPPORT

@interface OOJavaScriptEngine (OOMonitorSupportInternal)

- (void)sendMonitorError:(JSErrorReport *)errorReport
			 withMessage:(NSString *)message
			   inContext:(JSContext *)context;

- (void)sendMonitorLogMessage:(NSString *)message
			 withMessageClass:(NSString *)messageClass
					inContext:(JSContext *)context;

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
static id JSArrayConverter(JSContext *context, JSObject *object);
} // namespace
namespace {
static id JSStringConverter(JSContext *context, JSObject *object);
} // namespace
namespace {
static id JSNumberConverter(JSContext *context, JSObject *object);
} // namespace
namespace {
static id JSBooleanConverter(JSContext *context, JSObject *object);
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
	
	// Not OOJS_BEGIN_FULL_NATIVE() - we use JSAPI while paused.
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
	NSString *errorName = [errorNames oo_stringForKey:errorNumberStr];
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
		if (dump)  OOJSDumpStack(OOJSRCX(context));
#endif
		
#if OOJSENGINE_MONITOR_SUPPORT
		ooscript::ExceptionState *exState = ooscript::saveExceptionState(context);
		JSErrorReport nativeReport =
		{
			.filename = report->filename,
			.lineno = report->lineno,
			.uclinebuf = reinterpret_cast<const jschar*>(report->linebuf),
			.flags = report->flags,
			.errorNumber = report->errorNumber,
			.ucmessage = reinterpret_cast<const jschar*>(report->ucmessage),
		};
		[[OOJavaScriptEngine sharedEngine] sendMonitorError:&nativeReport
														withMessage:messageText
														  inContext:OOJSRCX(context)];
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
	
	assert(sizeof(jschar) == sizeof(unichar));
	
	// initialize the JS run time, and return result in runtime.
	uint32_t jsRuntimeInMiB = [defaults oo_intForKey:@"jsruntime-size-mib" defaultValue:OOJS_RUNTIME_SIZE_MiB];
	_runtime = OOJSRRT(ooscript::newRuntime(jsRuntimeInMiB * 1024L * 1024L));
	
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
	gOOJSMainThreadContext = OOJSRCX(ooscript::newContext(OOJSFRT(_runtime), OOJS_STACK_SIZE));
	
	// if context creation failed, end the program here.
	if (gOOJSMainThreadContext == NULL)
	{
		OOLog(@"script.javaScript.init.error", @"%@", @"***** FATAL ERROR: failed to create JavaScript context.");
		exit(1);
	}
	
	ooscript::beginRequest(OOJSFCX(gOOJSMainThreadContext));
	
	ooscript::setOptions(OOJSFCX(gOOJSMainThreadContext), OOJSENGINE_CONTEXT_OPTIONS);  // NOLINT(clang-analyzer-optin.core.EnumCastOutOfRange): OOJSENGINE_CONTEXT_OPTIONS ORs ContextOption flag bits through JSEngine.hpp's own constexpr operator|; the enum is a bitmask, not a closed set, so the analyzer's "value not a declared enumerator" is a false positive on every legitimate flag combination -- see JSEngine.hpp's own operator| for the same pattern used by OOJSVector.mm's PropertyFlag/ClassFlag tables.
	ooscript::setVersion(OOJSFCX(gOOJSMainThreadContext), OOJSENGINE_JSVERSION);
	
	if (ooscript::gcZealSupported())
	{
		uint8_t gcZeal = [[NSUserDefaults standardUserDefaults]  oo_unsignedCharForKey:@"js-gc-zeal"];
		if (gcZeal > 0)
		{
			// Useful js-gc-zeal values are 0 (off), 1 and 2.
			OOLog(@"script.javaScript.debug.gcZeal", @"Setting JavaScript garbage collector zeal to %u.", gcZeal);
			ooscript::setGCZeal(OOJSFCX(gOOJSMainThreadContext), gcZeal);
		}
	}
	
	ooscript::setErrorReporter(OOJSFCX(gOOJSMainThreadContext), ReportJSError);
	
	// Create the global object.
	CreateOOJSGlobal(gOOJSMainThreadContext, &_globalObject);
	
	// Initialize the built-in JS objects and the global object.
	ooscript::initStandardClasses(OOJSFCX(gOOJSMainThreadContext), OOJSFOBJ(_globalObject));
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
	
	ooscript::endRequest(OOJSFCX(gOOJSMainThreadContext));
	
	OOLog(@"script.javaScript.init.success", @"%@", @"Set up JavaScript context.");
}


- (void) destroyMainThreadContext
{
	if (gOOJSMainThreadContext != NULL)
	{
		JSContext *context = OOJSAcquireContext();
		ooscript::clearScope(OOJSFCX(gOOJSMainThreadContext), OOJSFOBJ(_globalObject));
		
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
		ooscript::destroyContext(OOJSFCX(gOOJSMainThreadContext));	// Forces unconditional GC.
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
		//NSAssert(!ooscript::isInRequest(OOJSFCX(gOOJSMainThreadContext)), @"JavaScript processes still pending. Can't reset JavaScript engine.");
		
		if (ooscript::isInRequest(OOJSFCX(gOOJSMainThreadContext)))
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
	
	JSContext *context = OOJSAcquireContext();
	[[NSNotificationCenter defaultCenter] postNotificationName:kOOJavaScriptEngineWillResetNotification object:self];
	OOJSRelinquishContext(context);
	
	[self destroyMainThreadContext];
	[self createMainThreadContext];
	
	context = OOJSAcquireContext();
	[[NSNotificationCenter defaultCenter] postNotificationName:kOOJavaScriptEngineDidResetNotification object:self];
	OOJSRelinquishContext(context);
	
	[self garbageCollectionOpportunity:YES];
	return YES;
}


- (void) dealloc
{
	sSharedEngine = nil;
	
	OOJSFrameCallbacksRemoveAll();
	
	[self destroyMainThreadContext];
	ooscript::destroyRuntime(OOJSFRT(_runtime));
	
	[super dealloc];
}


- (JSObject *) globalObject
{
	return _globalObject;
}


- (BOOL) callJSFunction:(jsval)function
			  forObject:(JSObject *)jsThis
				   argc:(uintN)argc
				   argv:(jsval *)argv
				 result:(jsval *)outResult
{
	JSContext					*context = NULL;
	BOOL						result;
	
	NSParameterAssert(OOJSValueIsFunction(context, function));
	
	context = OOJSAcquireContext();
	
	OOJSStartTimeLimiter();
	result = ooscript::callFunctionValue(OOJSFCX(context), OOJSFOBJ(jsThis), OOJSFVAL(function), argc, OOJSFVALP(argv), OOJSFVALP(outResult));
	OOJSStopTimeLimiter();
	
	ooscript::reportPendingException(OOJSFCX(context));
	OOJSRelinquishContext(context);
	
	return result;
}


- (void) removeGCObjectRoot:(JSObject **)rootPtr
{
	JSContext *context = OOJSAcquireContext();
	ooscript::removeObjectRoot(OOJSFCX(context), reinterpret_cast<ooscript::Object*>(rootPtr));
	OOJSRelinquishContext(context);
}


- (void) removeGCValueRoot:(jsval *)rootPtr
{
	JSContext *context = OOJSAcquireContext();
	ooscript::removeValueRoot(OOJSFCX(context), OOJSFVALP(rootPtr));
	OOJSRelinquishContext(context);
}


- (void) garbageCollectionOpportunity:(BOOL)force
{
	JSContext *context = OOJSAcquireContext();
	if (force)
	{
		ooscript::gc(OOJSFCX(context));
	}
	else
	{
		ooscript::maybeGC(OOJSFCX(context));
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


- (JSClass *) objectClass
{
	return _objectClass;
}


- (JSClass *) stringClass
{
	return _stringClass;
}


- (JSClass *) arrayClass
{
	return _arrayClass;
}


- (JSClass *) numberClass
{
	return _numberClass;
}


- (JSClass *) booleanClass
{
	return _booleanClass;
}


- (BOOL) lookUpStandardClassPointers
{
	JSObject				*templateObject = NULL;
	
	templateObject = OOJSROBJ(ooscript::newObject(OOJSFCX(gOOJSMainThreadContext), NULL, NULL, NULL));
	if (EXPECT_NOT(templateObject == NULL))  return NO;
	_objectClass = OOJSGetClass(gOOJSMainThreadContext, templateObject);
	
	{
		ooscript::Object obj = OOJSFOBJ(templateObject);
		if (EXPECT_NOT(!ooscript::valueToObject(OOJSFCX(gOOJSMainThreadContext), ooscript::emptyStringValue(OOJSFCX(gOOJSMainThreadContext)), &obj)))  return NO;
		templateObject = OOJSROBJ(obj);
	}
	_stringClass = OOJSGetClass(gOOJSMainThreadContext, templateObject);
	
	templateObject = OOJSROBJ(ooscript::newArrayObject(OOJSFCX(gOOJSMainThreadContext), 0, NULL));
	if (EXPECT_NOT(templateObject == NULL))  return NO;
	_arrayClass = OOJSGetClass(gOOJSMainThreadContext, templateObject);
	
	{
		ooscript::Object obj = OOJSFOBJ(templateObject);
		if (EXPECT_NOT(!ooscript::valueToObject(OOJSFCX(gOOJSMainThreadContext), ooscript::int32Value(0), &obj)))  return NO;
		templateObject = OOJSROBJ(obj);
	}
	_numberClass = OOJSGetClass(gOOJSMainThreadContext, templateObject);
	
	{
		ooscript::Object obj = OOJSFOBJ(templateObject);
		if (EXPECT_NOT(!ooscript::valueToObject(OOJSFCX(gOOJSMainThreadContext), ooscript::falseValue(), &obj)))  return NO;
		templateObject = OOJSROBJ(obj);
	}
	_booleanClass = OOJSGetClass(gOOJSMainThreadContext, templateObject);
	
	return YES;
}


- (void) registerStandardObjectConverters
{
	OOJSRegisterObjectConverter([self objectClass], (OOJSClassConverterCallback)OOJSDictionaryFromJSObject);
	OOJSRegisterObjectConverter([self stringClass], JSStringConverter);
	OOJSRegisterObjectConverter([self arrayClass], JSArrayConverter);
	OOJSRegisterObjectConverter([self numberClass], JSNumberConverter);
	OOJSRegisterObjectConverter([self booleanClass], JSBooleanConverter);
}


#ifndef NDEBUG
namespace {
static JSTrapStatus DebuggerHook(JSContext *context, JSScript * /*script*/, jsbytecode * /*pc*/, jsval * /*rval*/, void * /*closure*/)
{
	OOJSPauseTimeLimiter();
	
	OOLog(@"script.javaScript.debugger", @"debugger invoked during %@:", [[OOJSScript currentlyRunningScript] displayName]);
	OOJSDumpStack(context);
	
	OOJSResumeTimeLimiter();
	
	return JSTRAP_CONTINUE;
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
	JS_SetDebuggerHandler(_runtime, DebuggerHook, self);
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

- (void) sendMonitorError:(JSErrorReport *)errorReport
			  withMessage:(NSString *)message
				inContext:(JSContext *)theContext
{
	if ([_monitor respondsToSelector:@selector(jsEngine:context:error:stackSkip:showingLocation:withMessage:)])
	{
		[_monitor jsEngine:self context:theContext error:errorReport stackSkip:sErrorHandlerStackSkip showingLocation:[self showErrorLocations] withMessage:message];
	}
}


- (void) sendMonitorLogMessage:(NSString *)message
			  withMessageClass:(NSString *)messageClass
					 inContext:(JSContext *)theContext
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
static void DumpVariable(JSContext *context, JSPropertyDesc *prop)
{
	NSString *name = OOStringFromJSValueEvenIfNull(context, prop->id);
	NSString *value = OOJSDescribeValue(context, prop->value, YES);
	
	enum   // NOLINT(performance-enum-size): kInterestingFlags is a bitwise complement of small flag values; forcing a narrow base type would truncate the ~ result.
	{
		kInterestingFlags = ~(JSPD_ENUMERATE | JSPD_PERMANENT | JSPD_VARIABLE | JSPD_ARGUMENT)
	};
	
	NSString *flagStr = @"";
	if ((prop->flags & kInterestingFlags) != 0)
	{
		NSMutableArray *flags = [NSMutableArray array];
		if (prop->flags & JSPD_READONLY)  [flags addObject:@"read-only"];
		if (prop->flags & JSPD_ALIAS)  [flags addObject:[NSString stringWithFormat:@"alias (%@)", OOJSDescribeValue(context, prop->alias, YES)]];
		if (prop->flags & JSPD_EXCEPTION)  [flags addObject:@"exception"];
		if (prop->flags & JSPD_ERROR)  [flags addObject:@"error"];
		
		flagStr = [NSString stringWithFormat:@" [%@]", [flags componentsJoinedByString:@", "]];
	}
	
	OOLog(@"script.javaScript.stackTrace", @"    %@: %@%@", name, value, flagStr);
}
} // namespace


void OOJSDumpStack(JSContext *context)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	@try
	{
		JSStackFrame	*frame = NULL;
		unsigned		idx = 0;
		unsigned		skip = sErrorHandlerStackSkip;
		
		while (JS_FrameIterator(context, &frame) != NULL)
		{
			JSScript			*script = JS_GetFrameScript(context, frame);
			NSString			*desc = nil;
			JSPropertyDescArray	properties = { 0 , NULL };
			BOOL				gotProperties = NO;
			
			idx++;
			
			if (!JS_IsScriptFrame(context, frame))
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
				JSObject	*scope = JS_GetFrameScopeChain(context, frame);
				
				if (scope != NULL)  gotProperties = JS_GetPropertyDescArray(context, scope, &properties);
				
				NSString *funcDesc = nil;
				JSFunction *function = JS_GetFrameFunction(context, frame);
				if (function != NULL)
				{
					JSString *funcName = JS_GetFunctionId(function);
					if (funcName != NULL)
					{
						funcDesc = OOStringFromJSString(context, funcName);
						if (!JS_IsConstructorFrame(context, frame))
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
			else if (JS_IsDebuggerFrame(context, frame))
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
				jsval thisVal;
				if (JS_GetFrameThis(context, frame, &thisVal))
				{
					static BOOL haveThis = NO;
					static jsval thisAtom;
					if (EXPECT_NOT(!haveThis))
					{
						thisAtom = STRING_TO_JSVAL(OOJSRSTR(ooscript::internString(OOJSFCX(context), "this")));
						haveThis = YES;
					}
					JSPropertyDesc thisDesc = { .id = thisAtom, .value = thisVal };
					DumpVariable(context, &thisDesc);
				}
				
				// Dump arguments.
				unsigned i;
				for (i = 0; i < properties.length; i++)
				{
					JSPropertyDesc *prop = &properties.array[i];
					if (prop->flags & JSPD_ARGUMENT)  DumpVariable(context, prop);
				}
				
				// Dump locals.
				for (i = 0; i < properties.length; i++)
				{
					JSPropertyDesc *prop = &properties.array[i];
					if (prop->flags & JSPD_VARIABLE)  DumpVariable(context, prop);
				}
				
				// Dump anything else.
				for (i = 0; i < properties.length; i++)
				{
					JSPropertyDesc *prop = &properties.array[i];
					if (!(prop->flags & (JSPD_ARGUMENT | JSPD_VARIABLE)))  DumpVariable(context, prop);
				}
				
				JS_PutPropertyDescArray(context, &properties);
			}
		}
	}
	@catch (NSException *exception)
	{
		OOLog(kOOLogException, @"Exception during JavaScript stack trace: %@:%@", [exception name], [exception reason]);
	}
	
	[pool release];
}


namespace {
static const char *sConsoleScriptName;	// Lifetime is lifetime of script object, which is forever.
} // namespace
namespace {
static NSUInteger sConsoleEvalLineNo;
} // namespace


namespace {
static void GetLocationNameAndLine(JSContext *context, JSStackFrame *stackFrame, const char **name, NSUInteger *line)
{
	NSCParameterAssert(context != NULL && stackFrame != NULL && name != NULL && line != NULL);
	
	*name = NULL;
	*line = 0;
	
	JSScript *script = JS_GetFrameScript(context, stackFrame);
	if (script != NULL)
	{
		*name = JS_GetScriptFilename(context, script);
		if (name != NULL)
		{
			jsbytecode *PC = JS_GetFramePC(context, stackFrame);
			*line = JS_PCToLineNumber(context, script, PC);
		}
	}
	else if (JS_IsDebuggerFrame(context, stackFrame))
	{
		*name = "<debugger frame>";
	}
}
} // namespace


NSString *OOJSDescribeLocation(JSContext *context, JSStackFrame *stackFrame)
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


void OOJSMarkConsoleEvalLocation(JSContext *context, JSStackFrame *stackFrame)
{
	GetLocationNameAndLine(context, stackFrame, &sConsoleScriptName, &sConsoleEvalLineNo);
}
#endif


void OOJSInitJSIDCachePRIVATE(const char *name, jsid *idCache)
{
	NSCParameterAssert(name != NULL && name[0] != '\0' && idCache != NULL);
	
	JSContext *context = OOJSAcquireContext();
	
	JSString *string = OOJSRSTR(ooscript::internString(OOJSFCX(context), name));
	if (EXPECT_NOT(string == NULL))
	{
		[NSException raise:NSGenericException format:@"Failed to initialize JS ID cache for \"%s\".", name];
	}
	
	*idCache = INTERNED_STRING_TO_JSID(string);
	
	OOJSRelinquishContext(context);
}


jsid OOJSIDFromString(NSString *string)
{
	if (EXPECT_NOT(string == nil))  return JSID_VOID;
	
	JSContext *context = OOJSAcquireContext();
	
	enum : std::uint16_t { kStackBufSize = 1024 };
	unichar stackBuf[kStackBufSize];
	unichar *buffer;
	size_t length = [string length];
	if (length < kStackBufSize)
	{
		buffer = stackBuf;
	}
	else
	{
		buffer = static_cast<unichar*>(malloc(sizeof (unichar) * length));
		if (EXPECT_NOT(buffer == NULL))  return JSID_VOID;
	}
	[string getCharacters:buffer];
	
	JSString *jsString = OOJSRSTR(ooscript::internUCStringN(OOJSFCX(context), reinterpret_cast<const ooscript::Char16*>(buffer), length));
	
	if (EXPECT_NOT(buffer != stackBuf))  free(buffer);
	
	OOJSRelinquishContext(context);
	
	if (EXPECT(jsString != NULL))  return INTERNED_STRING_TO_JSID(jsString);
	else  return JSID_VOID;
}


NSString *OOStringFromJSID(jsid propID)
{
	JSContext *context = OOJSAcquireContext();
	
	ooscript::Value	value;
	NSString	*result = nil;
	if (ooscript::idToValue(OOJSFCX(context), OOJSFJSID(propID), &value))
	{
		result = OOStringFromJSString(context, OOJSRSTR(ooscript::valueToString(OOJSFCX(context), value)));
	}
	
	OOJSRelinquishContext(context);
	
	return result;
}


namespace {
static NSString *CallerPrefix(NSString *scriptClass, NSString *function)
{
	if (function == nil)  return @"";
	if (scriptClass == nil)  return [function stringByAppendingString:@": "];
	return  [NSString stringWithFormat:@"%@.%@: ", scriptClass, function];
}
} // namespace


void OOJSReportError(JSContext *context, NSString *format, ...)
{
	va_list					args;
	
	va_start(args, format);
	OOJSReportErrorWithArguments(context, format, args);
	va_end(args);
}


void OOJSReportErrorForCaller(JSContext *context, NSString *scriptClass, NSString *function, NSString *format, ...)
{
	va_list					args;
	NSString				*msg = nil;
	
	@try
	{
		va_start(args, format);
		msg = [[NSString alloc] initWithFormat:format arguments:args];
		va_end(args);
		
		OOJSReportError(context, @"%@%@", CallerPrefix(scriptClass, function), msg);
	}
	@catch (id exception)
	{
		// Squash any secondary errors during error handling.
	}
	[msg release];
}


void OOJSReportErrorWithArguments(JSContext *context, NSString *format, va_list args)
{
	NSString				*msg = nil;
	
	NSCParameterAssert(ooscript::isInRequest(OOJSFCX(context)));
	
	@try
	{
		msg = [[NSString alloc] initWithFormat:format arguments:args];
		ooscript::reportError(OOJSFCX(context), [msg UTF8String]);
	}
	@catch (id exception)
	{
		// Squash any secondary errors during error handling.
	}
	[msg release];
}


void OOJSReportWrappedException(JSContext *context, id exception)
{
	if (!ooscript::isExceptionPending(OOJSFCX(context)))
	{
		if ([exception isKindOfClass:[NSException class]])  OOJSReportError(context, @"Native exception: %@", [exception reason]);
		else  OOJSReportError(context, @"Unidentified native exception");
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


void OOJSReportWarning(JSContext *context, NSString *format, ...)
{
	va_list					args;
	
	va_start(args, format);
	OOJSReportWarningWithArguments(context, format, args);
	va_end(args);
}


void OOJSReportWarningForCaller(JSContext *context, NSString *scriptClass, NSString *function, NSString *format, ...)
{
	va_list					args;
	NSString				*msg = nil;
	
	@try
	{
		va_start(args, format);
		msg = [[NSString alloc] initWithFormat:format arguments:args];
		va_end(args);
		
		OOJSReportWarning(context, @"%@%@", CallerPrefix(scriptClass, function), msg);
	}
	@catch (id exception)
	{
		// Squash any secondary errors during error handling.
	}
	[msg release];
}


void OOJSReportWarningWithArguments(JSContext *context, NSString *format, va_list args)
{
	NSString				*msg = nil;
	
	@try
	{
		msg = [[NSString alloc] initWithFormat:format arguments:args];
		ooscript::reportWarning(OOJSFCX(context), [msg UTF8String]);
	}
	@catch (id exception)
	{
		// Squash any secondary errors during error handling.
	}
	[msg release];
}


void OOJSReportBadPropertySelector(JSContext *context, JSObject *thisObj, jsid propID, JSPropertySpec *propertySpec)
{
	NSString	*propName = OOStringFromJSPropertyIDAndSpec(context, propID, propertySpec);
	const char	*className = OOJSGetClass(context, thisObj)->name;
	
	OOJSReportError(context, @"Invalid property identifier %@ for instance of %s.", propName, className);
}


void OOJSReportBadPropertyValue(JSContext *context, JSObject *thisObj, jsid propID, JSPropertySpec *propertySpec, jsval value)
{
	NSString	*propName = OOStringFromJSPropertyIDAndSpec(context, propID, propertySpec);
	const char	*className = OOJSGetClass(context, thisObj)->name;
	NSString	*valueDesc = OOJSDescribeValue(context, value, YES);
	
	OOJSReportError(context, @"Cannot set property %@ of instance of %s to invalid value %@.", propName, className, valueDesc);
}


void OOJSReportBadArguments(JSContext *context, NSString *scriptClass, NSString *function, uintN argc, jsval *argv, NSString *message, NSString *expectedArgsDescription)
{
	@try
	{
		if (message == nil)  message = @"Invalid arguments";
		message = [NSString stringWithFormat:@"%@ %@", message, [NSString stringWithJavaScriptParameters:argv count:argc inContext:context]];
		if (expectedArgsDescription != nil)  message = [NSString stringWithFormat:@"%@ -- expected %@", message, expectedArgsDescription];
		
		OOJSReportErrorForCaller(context, scriptClass, function, @"%@.", message);
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


BOOL OOJSArgumentListGetNumber(JSContext *context, NSString *scriptClass, NSString *function, uintN argc, jsval *argv, double *outNumber, uintN *outConsumed)
{
	if (OOJSArgumentListGetNumberNoError(context, argc, argv, outNumber, outConsumed))
	{
		return YES;
	}
	else
	{
		OOJSReportBadArguments(context, scriptClass, function, argc, argv,
									   @"Expected number, got", NULL);
		return NO;
	}
}


BOOL OOJSArgumentListGetNumberNoError(JSContext *context, uintN argc, jsval *argv, double *outNumber, uintN *outConsumed)
{
	OOJS_PROFILE_ENTER
	
	double					value;
	
	NSCParameterAssert(context != NULL && (argv != NULL || argc == 0) && outNumber != NULL);
	
	// Get value, if possible.
	if (EXPECT_NOT(!ooscript::valueToNumber(OOJSFCX(context), OOJSFVAL(argv[0]), &value) || isnan(value)))
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


namespace {
static JSObject *JSArrayFromNSArray(JSContext *context, NSArray *array)
{
	OOJS_PROFILE_ENTER
	
	JSObject				*result = NULL;
	
	if (array == nil)  return NULL;
	
	@try
	{
		NSUInteger fullCount = [array count];
		if (EXPECT_NOT(fullCount > INT32_MAX))
		{
			return NULL;
		}
		
		uint32_t i, count = (int32_t)fullCount;
		
		result = OOJSROBJ(ooscript::newArrayObject(OOJSFCX(context), 0, NULL));
		if (result != NULL)
		{
			for (i = 0; i != count; ++i)
			{
				jsval value = [[array objectAtIndex:i] oo_jsValueInContext:context];
				ooscript::Value fval = OOJSFVAL(value);
				BOOL OK = ooscript::setElement(OOJSFCX(context), OOJSFOBJ(result), i, &fval);
				
				if (EXPECT_NOT(!OK))
				{
					result = NULL;
					break;
				}
			}
		}
	}
	@catch (id ex)
	{
		result = NULL;
	}
	
	return (JSObject *)result;
	
	OOJS_PROFILE_EXIT
}
} // namespace


namespace {
static BOOL JSNewNSArrayValue(JSContext *context, NSArray *array, jsval *value)
{
	OOJS_PROFILE_ENTER
	
	JSObject				*object = NULL;
	BOOL					OK = YES;
	
	if (value == NULL)  return NO;
	
	// NOTE: rooted for GC reasons for the duration of the conversion, per ooscript/README.md's
	// "Not in the façade" note on EnterLocalRootScope / LeaveLocalRootScopeWithResult.
	ooscript::RootedValue rootedResult(OOJSFCX(context), ooscript::Value{0}, "JSNewNSArrayValue.result");
	
	object = JSArrayFromNSArray(context, array);
	if (object == NULL)
	{
		*value = JSVAL_VOID;
		OK = NO;
	}
	else
	{
		*value = OBJECT_TO_JSVAL(object);
	}
	
	rootedResult.set(OOJSFVAL(*value));
	return OK;
	
	OOJS_PROFILE_EXIT
}
} // namespace


/*	Convert an NSDictionary to a JavaScript Object.
	Only properties whose keys are either strings or non-negative NSNumbers,
	and	whose values have a non-void JS representation, are converted.
*/
namespace {
static JSObject *JSObjectFromNSDictionary(JSContext *context, NSDictionary *dictionary)
{
	OOJS_PROFILE_ENTER
	
	JSObject				*result = NULL;
	BOOL					OK = YES;
	id						key = nil;
	jsval					value;
	jsint					index;
	
	if (dictionary == nil)  return NULL;
	
	@try
	{
		result = OOJSROBJ(ooscript::newObject(OOJSFCX(context), NULL, NULL, NULL));	// create object of class Object
		if (result != NULL)
		{
			foreachkey (key, dictionary)
			{
				if ([key isKindOfClass:[NSString class]] && [key length] != 0)
				{
#ifndef __GNUC__
					value = [[dictionary objectForKey:key] oo_jsValueInContext:context];
#else
#if __GNUC__ > 4 || __GNUC_MINOR__ > 6
					value = [[dictionary objectForKey:key] oo_jsValueInContext:context];
#else
					// GCC before 4.7 seems to have problems with this
					// bit if the object is a weakref, causing crashes
					// in docking code.
					id tmp = [dictionary objectForKey:key];
					if ([tmp respondsToSelector:@selector(weakRefUnderlyingObject)])
					{
						tmp = [tmp weakRefUnderlyingObject];
					}
					value = [tmp oo_jsValueInContext:context];
#endif
#endif
					if (!JSVAL_IS_VOID(value))
					{
						OK = ooscript::setPropertyById(OOJSFCX(context), OOJSFOBJ(result), OOJSFJSID(OOJSIDFromString(key)), OOJSFVALP(&value));
						if (EXPECT_NOT(!OK))  break;
					}
				}
				else if ([key isKindOfClass:[NSNumber class]])
				{
					index = [key intValue];
					if (0 < index)
					{
						value = [[dictionary objectForKey:key] oo_jsValueInContext:context];
						if (!JSVAL_IS_VOID(value))
						{
							OK = ooscript::setElement(OOJSFCX(context), OOJSFOBJ((JSObject *)result), index, OOJSFVALP(&value));
							if (EXPECT_NOT(!OK))  break;
						}
					}
				}
				
				if (EXPECT_NOT(!OK))  break;
			}
		}
	}
	@catch (id exception)
	{
		OK = NO;
	}
	
	if (EXPECT_NOT(!OK))
	{
		result = NULL;
	}
	
	return (JSObject *)result;
	
	OOJS_PROFILE_EXIT
}
} // namespace


namespace {
static BOOL JSNewNSDictionaryValue(JSContext *context, NSDictionary *dictionary, jsval *value)
{
	OOJS_PROFILE_ENTER
	
	JSObject				*object = NULL;
	BOOL					OK = YES;
	
	if (value == NULL)  return NO;
	
	// NOTE: rooted for GC reasons for the duration of the conversion, per ooscript/README.md's
	// "Not in the façade" note on EnterLocalRootScope / LeaveLocalRootScopeWithResult.
	ooscript::RootedValue rootedResult(OOJSFCX(context), ooscript::Value{0}, "JSNewNSDictionaryValue.result");
	
	object = JSObjectFromNSDictionary(context, dictionary);
	if (object == NULL)
	{
		*value = JSVAL_VOID;
		OK = NO;
	}
	else
	{
		*value = OBJECT_TO_JSVAL(object);
	}
	
	rootedResult.set(OOJSFVAL(*value));
	return OK;
	
	OOJS_PROFILE_EXIT
}
} // namespace


@implementation NSObject (OOJavaScriptConversion)

- (jsval) oo_jsValueInContext:(JSContext *)context
{
	return JSVAL_VOID;
}


- (NSString *) oo_jsClassName
{
	return nil;
}


- (NSString *) oo_jsDescription
{
	return [self oo_jsDescriptionWithClassName:[self oo_jsClassName]];
}


- (NSString *) oo_jsDescriptionWithClassName:(NSString *)className
{
	OOJS_PROFILE_ENTER
	
	NSString				*components = nil;
	NSString				*description = nil;
	
	components = [self descriptionComponents];
	if (className == nil)  className = [[self class] description];
	
	if (components != nil)
	{
		description = [NSString stringWithFormat:@"[%@ %@]", className, components];
	}
	else
	{
		description = [NSString stringWithFormat:@"[object %@]", className];
	}
	
	return description;
	
	OOJS_PROFILE_EXIT
}


- (void) oo_clearJSSelf:(JSObject *)selfVal
{
	
}

@end


JSObject *OOJSObjectFromNativeObject(JSContext *context, id object)
{
	jsval value = OOJSValueFromNativeObject(context, object);
	ooscript::Object result = nullptr;
	if (ooscript::valueToObject(OOJSFCX(context), OOJSFVAL(value), &result))  return OOJSROBJ(result);
	return NULL;
}


@implementation OOJSValue

+ (id) valueWithJSValue:(jsval)value inContext:(JSContext *)context
{
	OOJS_PROFILE_ENTER
	
	return [[[self alloc] initWithJSValue:value inContext:context] autorelease];
	
	OOJS_PROFILE_EXIT
}


+ (id) valueWithJSObject:(JSObject *)object inContext:(JSContext *)context
{
	OOJS_PROFILE_ENTER
	
	return [[[self alloc] initWithJSObject:object inContext:context] autorelease];
	
	OOJS_PROFILE_EXIT
}


- (id) initWithJSValue:(jsval)value inContext:(JSContext *)context
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
		if (!JSVAL_IS_VOID(_val))
		{
			ooscript::addNamedValueRoot(OOJSFCX(context), OOJSFVALP(&_val), "OOJSValue");
			
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(deleteJSValue)
														 name:kOOJavaScriptEngineWillResetNotification
													   object:[OOJavaScriptEngine sharedEngine]];
		}
		
		if (tempCtxt)  OOJSRelinquishContext(context);
	}
	return self;
	
	OOJS_PROFILE_EXIT
}


- (id) initWithJSObject:(JSObject *)object inContext:(JSContext *)context
{
	return [self initWithJSValue:OBJECT_TO_JSVAL(object) inContext:context];
}


- (void) deleteJSValue
{
	if (!JSVAL_IS_VOID(_val))
	{
		JSContext *context = OOJSAcquireContext();
		ooscript::removeValueRoot(OOJSFCX(context), OOJSFVALP(&_val));
		OOJSRelinquishContext(context);
		
		_val = JSVAL_VOID;
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:kOOJavaScriptEngineWillResetNotification
													  object:[OOJavaScriptEngine sharedEngine]];
	}
}


- (void) dealloc
{
	[self deleteJSValue];
	[super dealloc];
}


- (jsval) oo_jsValueInContext:(JSContext *)context
{
	return _val;
}

@end


void OOJSStrLiteralCachePRIVATE(const char *string, jsval *strCache, BOOL *inited)
{
	NSCParameterAssert(string != NULL && strCache != NULL && inited != NULL && !*inited);
	
	JSContext *context = OOJSAcquireContext();
	
	JSString *jsString = OOJSRSTR(ooscript::internString(OOJSFCX(context), string));
	if (EXPECT_NOT(string == NULL))
	{
		[NSException raise:NSGenericException format:@"Failed to initialize JavaScript string literal cache for \"%@\".", [[NSString stringWithUTF8String:string] escapedForJavaScriptLiteral]];
	}
	
	*strCache = STRING_TO_JSVAL(jsString);
	*inited = YES;
	
	OOJSRelinquishContext(context);
}


NSString *OOStringFromJSString(JSContext *context, JSString *string)
{
	OOJS_PROFILE_ENTER
	
	if (EXPECT_NOT(string == NULL))  return nil;
	
	size_t length;
	const jschar *chars = OOJSRCHARS(ooscript::getStringCharsAndLength(OOJSFCX(context), OOJSFSTR(string), &length));
	
	if (EXPECT(chars != NULL))
	{
		return [NSString stringWithCharacters:OOJSRUCHARS(reinterpret_cast<const ooscript::Char16*>(chars)) length:length];
	}
	else
	{
		return nil;
	}
	
	OOJS_PROFILE_EXIT
}


NSString *OOStringFromJSValueEvenIfNull(JSContext *context, jsval value)
{
	OOJS_PROFILE_ENTER
	
	NSCParameterAssert(context != NULL && ooscript::isInRequest(OOJSFCX(context)));
	
	JSString *string = OOJSRSTR(ooscript::valueToString(OOJSFCX(context), OOJSFVAL(value)));	// Calls the value's toString method if needed.
	return OOStringFromJSString(context, string);
	
	OOJS_PROFILE_EXIT
}


NSString *OOStringFromJSValue(JSContext *context, jsval value)
{
	OOJS_PROFILE_ENTER
	
	if (EXPECT(!JSVAL_IS_NULL(value) && !JSVAL_IS_VOID(value)))
	{
		return OOStringFromJSValueEvenIfNull(context, value);
	}
	return nil;
	
	OOJS_PROFILE_EXIT
}


NSString *OOStringFromJSPropertyIDAndSpec(JSContext *context, jsid propID, JSPropertySpec *propertySpec)
{
	if (JSID_IS_STRING(propID))
	{
		return OOStringFromJSString(context, JSID_TO_STRING(propID));
	}
	else if (JSID_IS_INT(propID) && propertySpec != NULL)
	{
		int tinyid = JSID_TO_INT(propID);
		
		while (propertySpec->name != NULL)
		{
			if (propertySpec->tinyid == tinyid)  return [NSString stringWithUTF8String:propertySpec->name];
			propertySpec++;
		}
	}
	
	jsval value;
	if (!ooscript::idToValue(OOJSFCX(context), OOJSFJSID(propID), OOJSFVALP(&value)))  return @"unknown";
	return OOStringFromJSString(context, OOJSRSTR(ooscript::valueToString(OOJSFCX(context), OOJSFVAL(value))));
}


namespace {
static NSString *DescribeValue(JSContext *context, jsval value, BOOL abbreviateObjects, BOOL recursing)
{
	OOJS_PROFILE_ENTER
	
	NSCParameterAssert(context != NULL && ooscript::isInRequest(OOJSFCX(context)));
	
	if (OOJSValueIsFunction(context, value))
	{
		JSString *name = OOJSRSTR(ooscript::getFunctionId(ooscript::valueToFunction(OOJSFCX(context), OOJSFVAL(value))));
		if (name != NULL)  return [NSString stringWithFormat:@"function %@", OOStringFromJSString(context, name)];
		else  return @"function";
	}
	
	NSString		*result = nil;
	JSClass				*valueClass = NULL;
	OOJavaScriptEngine	*jsEng = [OOJavaScriptEngine sharedEngine];
	
	if (JSVAL_IS_OBJECT(value) && !JSVAL_IS_NULL(value))
	{
		valueClass = OOJSGetClass(context, JSVAL_TO_OBJECT(value));
	}
	
	// Convert String objects to strings.
	if (valueClass == [jsEng stringClass])
	{
		value = STRING_TO_JSVAL(OOJSRSTR(ooscript::valueToString(OOJSFCX(context), OOJSFVAL(value))));
	}
	
	if (JSVAL_IS_STRING(value))
	{
		enum : std::uint8_t { kMaxLength = 200 };
		
		JSString *string = JSVAL_TO_STRING(value);
		size_t length;
		const jschar *chars = OOJSRCHARS(ooscript::getStringCharsAndLength(OOJSFCX(context), OOJSFSTR(string), &length));
		
		result = [NSString stringWithCharacters:OOJSRUCHARS(reinterpret_cast<const ooscript::Char16*>(chars)) length:MIN(length, (size_t)kMaxLength)];
		result = [NSString stringWithFormat:@"\"%@%@\"", [result escapedForJavaScriptLiteral], (length > kMaxLength) ? @"..." : @""];
	}
	else if (valueClass == [jsEng arrayClass])
	{
		// Descibe up to four elements of an array.
		jsuint count;
		JSObject *obj = JSVAL_TO_OBJECT(value);
		if (ooscript::getArrayLength(OOJSFCX(context), OOJSFOBJ(obj), &count))
		{
			if (!recursing)
			{
				NSMutableString *arrayDesc = [NSMutableString stringWithString:@"["];
				jsuint i, effectiveCount = MIN(count, (jsuint)4);
				for (i = 0; i < effectiveCount; i++)
				{
					jsval item;
					NSString *itemDesc = @"?";
					if (ooscript::getElement(OOJSFCX(context), OOJSFOBJ(obj), i, OOJSFVALP(&item)))
					{
						itemDesc = DescribeValue(context, item, YES /* always abbreviate objects in arrays */, YES);
					}
					if (i != 0)  [arrayDesc appendString:@", "];
					[arrayDesc appendString:itemDesc];
				}
				if (effectiveCount != count)
				{
					[arrayDesc appendFormat:@", ... <%u items total>]", count];
				}
				else
				{
					[arrayDesc appendString:@"]"];
				}
				
				result = arrayDesc;
			}
			else
			{
				result = [NSString stringWithFormat:@"[<%u items>]", count];
			}
		}
		else
		{
			result = @"[...]";
		}

	}
	
	if (result == nil)
	{
		result = OOStringFromJSValueEvenIfNull(context, value);
		
		if (abbreviateObjects && valueClass == [jsEng objectClass] && [result isEqualToString:@"[object Object]"])
		{
			result = @"{...}";
		}
		
		if (result == nil)  result = @"?";
	}
	
	return result;
	
	OOJS_PROFILE_EXIT
}
} // namespace


NSString *OOJSDescribeValue(JSContext *context, jsval value, BOOL abbreviateObjects)
{
	return DescribeValue(context, value, abbreviateObjects, NO);
}


@implementation NSString (OOJavaScriptExtensions)

+ (NSString *) stringWithJavaScriptParameters:(jsval *)params count:(uintN)count inContext:(JSContext *)context
{
	OOJS_PROFILE_ENTER
	
	if (params == NULL && count != 0) return nil;
	
	uintN					i;
	NSMutableString			*result = [NSMutableString stringWithString:@"("];
	
	for (i = 0; i < count; ++i)
	{
		if (i != 0)  [result appendString:@", "];
		[result appendString:OOJSDescribeValue(context, params[i], NO)];
	}
	
	[result appendString:@")"];
	return result;
	
	OOJS_PROFILE_EXIT
}


- (jsval) oo_jsValueInContext:(JSContext *)context
{
	OOJS_PROFILE_ENTER
	
	size_t					length = [self length];
	unichar					*buffer = NULL;
	JSString				*string = NULL;
	
	if (length == 0)
	{
		jsval result = OOJSRVALV(ooscript::emptyStringValue(OOJSFCX(context)));
		return result;
	}
	else
	{
		buffer = static_cast<unichar*>(malloc(length * sizeof *buffer));
		if (buffer == NULL) return JSVAL_VOID;
		
		[self getCharacters:buffer];
		
		string = OOJSRSTR(ooscript::newUCStringCopyN(OOJSFCX(context), reinterpret_cast<const ooscript::Char16*>(buffer), length));
		
		free(buffer);
		return STRING_TO_JSVAL(string);
	}
	
	OOJS_PROFILE_EXIT_JSVAL
}


+ (NSString *) concatenationOfStringsFromJavaScriptValues:(jsval *)values count:(size_t)count separator:(NSString *)separator inContext:(JSContext *)context
{
	OOJS_PROFILE_ENTER
	
	size_t					i;
	NSMutableString			*result = nil;
	NSString				*element = nil;
	
	if (count < 1) return nil;
	if (values == NULL) return NULL;
	
	for (i = 0; i != count; ++i)
	{
		element = OOStringFromJSValueEvenIfNull(context, values[i]);
		if (result == nil)  result = [[element mutableCopy] autorelease];
		else
		{
			if (separator != nil)  [result appendString:separator];
			[result appendString:element];
		}
	}
	
	return result;
	
	OOJS_PROFILE_EXIT
}


- (NSString *)escapedForJavaScriptLiteral
{
	OOJS_PROFILE_ENTER
	
	NSMutableString			*result = nil;
	NSUInteger				i, length;
	unichar					c;
	NSAutoreleasePool		*pool = nil;
	
	length = [self length];
	result = [NSMutableString stringWithCapacity:length];
	
	// Not hugely efficient.
	pool = [[NSAutoreleasePool alloc] init];
	for (i = 0; i != length; ++i)
	{
		c = [self characterAtIndex:i];
		switch (c)
		{
			case '\\':
				[result appendString:@"\\\\"];
				break;
				
			case '\b':
				[result appendString:@"\\b"];
				break;
				
			case '\f':
				[result appendString:@"\\f"];
				break;
				
			case '\n':
				[result appendString:@"\\n"];
				break;
				
			case '\r':
				[result appendString:@"\\r"];
				break;
				
			case '\t':
				[result appendString:@"\\t"];
				break;
				
			case '\v':
				[result appendString:@"\\v"];
				break;
				
			case '\'':
				[result appendString:@"\\\'"];
				break;
				
			case '\"':
				[result appendString:@"\\\""];
				break;
			
			default:
				[result appendString:[NSString stringWithCharacters:&c length:1]];
		}
	}
	[pool release];
	return result;
	
	OOJS_PROFILE_EXIT
}


- (NSString *) oo_jsClassName
{
	return @"String";
}

@end


@implementation NSArray (OOJavaScriptConversion)

- (jsval)oo_jsValueInContext:(JSContext *)context
{
	jsval value = JSVAL_VOID;
	JSNewNSArrayValue(context, self, &value);
	return value;
}

@end

@implementation OONativeVector (OOJavaScriptConversion)

- (jsval)oo_jsValueInContext:(JSContext *)context
{
	jsval value = JSVAL_VOID;
	VectorToJSValue(context, v, &value);
	return value;
}

@end


@implementation NSDictionary (OOJavaScriptConversion)

- (jsval)oo_jsValueInContext:(JSContext *)context
{
	jsval value = JSVAL_VOID;
	JSNewNSDictionaryValue(context, self, &value);
	return value;
}

@end


@implementation NSNumber (OOJavaScriptConversion)

- (jsval)oo_jsValueInContext:(JSContext *)context
{
	OOJS_PROFILE_ENTER
	
	jsval					result;
	BOOL					isFloat = NO;
	long long				longLongValue;
	
	isFloat = [self oo_isFloatingPointNumber];
	if (!isFloat)
	{
		longLongValue = [self longLongValue];
		if (longLongValue < (long long)JSVAL_INT_MIN || (long long)JSVAL_INT_MAX < longLongValue)
		{
			// values outside JSVAL_INT range are returned as doubles.
			isFloat = YES;
		}
	}
	
	if (isFloat)
	{
		if (!ooscript::newNumberValue(OOJSFCX(context), [self doubleValue], OOJSFVALP(&result))) result = JSVAL_VOID;
	}
	else
	{
		result = INT_TO_JSVAL((int32_t)longLongValue);
	}
	
	return result;
	
	OOJS_PROFILE_EXIT_JSVAL
}


- (NSString *) oo_jsClassName
{
	return @"Number";
}

@end


@implementation NSNull (OOJavaScriptConversion)

- (jsval)oo_jsValueInContext:(JSContext *)context
{
	return JSVAL_NULL;
}

@end


JSBool OOJSUnconstructableConstruct(JSContext *context, uintN /*argc*/, jsval *vp)
{
	OOJS_NATIVE_ENTER(context)
	
	ooscript::Function function = ooscript::valueToFunction(OOJSFCX(context), OOJSFVAL(vp[0]));	// vp[0] is the callee slot (ooscript::CallArgs::callee()'s own layout)
	NSString *name = OOStringFromJSString(context, OOJSRSTR(ooscript::getFunctionId(function)));
	
	OOJSReportError(context, @"%@ cannot be used as a constructor.", name);
	return NO;
	
	OOJS_NATIVE_EXIT
}


void OOJSObjectWrapperFinalize(JSContext *context, JSObject *thisObj)
{
	OOJS_PROFILE_ENTER
	
	id object = (id)ooscript::getPrivate(OOJSFCX(context), OOJSFOBJ(thisObj));
	if (object != nil)
	{
		[[object weakRefUnderlyingObject] oo_clearJSSelf:thisObj];
		[object release];
		ooscript::setPrivate(OOJSFCX(context), OOJSFOBJ(thisObj), nil);
	}
	
	OOJS_PROFILE_EXIT_VOID
}


JSBool OOJSObjectWrapperToString(JSContext *context, uintN /*argc*/, jsval *vp)
{
	OOJS_NATIVE_ENTER(context)
	
	id						object = nil;
	NSString				*description = nil;
	JSClass					*jsClass = NULL;
	
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
			description = [NSString stringWithFormat:@"[object %@]", [NSString stringWithUTF8String:jsClass->name]];
		}
	}
	if (description == nil)  description = @"[object]";
	
	OOJS_RETURN_OBJECT(description);
	
	OOJS_NATIVE_EXIT
}


BOOL JSFunctionPredicate(Entity *entity, void *parameter)
{
	OOJS_PROFILE_ENTER
	
	JSFunctionPredicateParameter	*param = static_cast<JSFunctionPredicateParameter*>(parameter);
	jsval							args[1];
	jsval							rval = JSVAL_VOID;
	JSBool							result = NO;
	
	NSCParameterAssert(entity != nil && param != NULL);
	NSCParameterAssert(param->context != NULL && ooscript::isInRequest(OOJSFCX(param->context)));
	NSCParameterAssert(OOJSValueIsFunction(param->context, param->function));
	
	if (EXPECT_NOT(param->errorFlag))  return NO;
	
	args[0] = [entity oo_jsValueInContext:param->context];	// entity is required to be non-nil (asserted above), so oo_jsValueInContext: is safe.
	
	OOJSStartTimeLimiter();
	OOJSResumeTimeLimiter();
	BOOL success = ooscript::callFunctionValue(OOJSFCX(param->context), OOJSFOBJ(param->jsThis), OOJSFVAL(param->function), 1, OOJSFVALP(args), OOJSFVALP(&rval));
	OOJSPauseTimeLimiter();
	OOJSStopTimeLimiter();
	
	if (success)
	{
		bool boolResult = false;
		if (!ooscript::valueToBoolean(OOJSFCX(param->context), OOJSFVAL(rval), &boolResult))  boolResult = false;
		result = static_cast<JSBool>(static_cast<unsigned char>(boolResult));
		if (ooscript::isExceptionPending(OOJSFCX(param->context)))
		{
			ooscript::reportPendingException(OOJSFCX(param->context));
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
static NSMapTable *sRegisteredSubClasses;
} // namespace

void OOJSRegisterSubclass(JSClass *subclass, JSClass *superclass)
{
	NSCParameterAssert(subclass != NULL && superclass != NULL);
	
	if (sRegisteredSubClasses == NULL)
	{
		sRegisteredSubClasses = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks, NSNonOwnedPointerMapValueCallBacks, 0);
	}
	
	NSCAssert(NSMapGet(sRegisteredSubClasses, subclass) == NULL, @"A JS class cannot be registered as a subclass of multiple classes.");
	
	NSMapInsertKnownAbsent(sRegisteredSubClasses, subclass, superclass);
}


namespace {
static void UnregisterSubclasses(void)
{
	NSFreeMapTable(sRegisteredSubClasses);
	sRegisteredSubClasses = NULL;
}
} // namespace


BOOL OOJSIsSubclass(JSClass *putativeSubclass, JSClass *superclass)
{
	NSCParameterAssert(putativeSubclass != NULL && superclass != NULL);
	NSCAssert(sRegisteredSubClasses != NULL, @"OOJSIsSubclass() called before any subclasses registered (disallowed for hot path efficiency).");
	
	do
	{
		if (putativeSubclass == superclass)  return YES;
		
		putativeSubclass = static_cast<JSClass*>(NSMapGet(sRegisteredSubClasses, putativeSubclass));
	}
	while (putativeSubclass != NULL);
	
	return NO;
}


BOOL OOJSObjectGetterImplPRIVATE(JSContext *context, JSObject *object, JSClass *requiredJSClass,
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
	JSClass *actualClass = OOJSGetClass(context, object);
	if (EXPECT_NOT(!OOJSIsSubclass(actualClass, requiredJSClass)))
	{
		OOJSReportError(context, @"Native method expected %s, got %@.", requiredJSClass->name, OOStringFromJSValue(context, OBJECT_TO_JSVAL(object)));
		return NO;
	}
	NSCAssert(actualClass->flags & JSCLASS_HAS_PRIVATE, @"Native object accessor requires JS class with private storage.");
	
	// Get the underlying object.
	*outObject = [(id)ooscript::getPrivate(OOJSFCX(context), OOJSFOBJ(object)) weakRefUnderlyingObject];
	
#ifndef NDEBUG
	// Double-check that the underlying object is of the expected ObjC class.
	if (EXPECT_NOT(*outObject != nil && ![*outObject isKindOfClass:requiredObjCClass]))
	{
		OOJSReportError(context, @"Native method expected %@ from %s and got correct JS type but incorrect native object %@", requiredObjCClass, requiredJSClass->name, *outObject);
		return NO;
	}
#endif
	
	return YES;
	
	OOJS_PROFILE_EXIT
}


NSDictionary *OOJSDictionaryFromJSValue(JSContext *context, jsval value)
{
	OOJS_PROFILE_ENTER
	
	ooscript::Object object = nullptr;
	if (EXPECT_NOT(!ooscript::valueToObject(OOJSFCX(context), OOJSFVAL(value), &object) || object == nullptr))
	{
		return nil;
	}
	return OOJSDictionaryFromJSObject(context, OOJSROBJ(object));
	
	OOJS_PROFILE_EXIT
}


NSDictionary *OOJSDictionaryFromJSObject(JSContext *context, JSObject *object)
{
	OOJS_PROFILE_ENTER
	
	ooscript::IdArray			*ids = NULL;
	std::size_t					i;
	NSMutableDictionary			*result = nil;
	jsval						value = JSVAL_VOID;
	id							objKey = nil;
	id							objValue = nil;
	
	ids = ooscript::enumerate(OOJSFCX(context), OOJSFOBJ(object));
	if (EXPECT_NOT(ids == NULL))
	{
		return nil;
	}
	
	result = [NSMutableDictionary dictionaryWithCapacity:ids->length];
	for (i = 0; i != ids->length; ++i)
	{
		jsid thisID = OOJSRJSID(ids->ids[i]);
		
		if (JSID_IS_STRING(thisID))
		{
			objKey = OOStringFromJSString(context, JSID_TO_STRING(thisID));
		}
		else if (JSID_IS_INT(thisID))
		{
			/* this causes problems with native functions which expect string keys
			 * e.g. in mission.runScreen with the 'choices' parameter
			 * should this instead be making the objKey a string?
			 * is there anything that relies on the current behaviour?
			 * - CIM 15/2/13 */
			objKey = [NSNumber numberWithInt:JSID_TO_INT(thisID)];
		}
		else
		{
			objKey = nil;
		}
		
		value = JSVAL_VOID;
		if (objKey != nil && !ooscript::lookupPropertyById(OOJSFCX(context), OOJSFOBJ(object), OOJSFJSID(thisID), OOJSFVALP(&value)))  value = JSVAL_VOID;
		
		if (objKey != nil && !JSVAL_IS_VOID(value))
		{
			objValue = OOJSNativeObjectFromJSValue(context, value);
			if (objValue != nil)
			{
				[result setObject:objValue forKey:objKey];
			}
		}
	}
	
	ooscript::destroyIdArray(OOJSFCX(context), ids);
	return result;
	
	OOJS_PROFILE_EXIT
}


NSDictionary *OOJSDictionaryFromStringTable(JSContext *context, jsval tableValue)
{
	OOJS_PROFILE_ENTER
	
	ooscript::Object				tableObject = nullptr;
	ooscript::IdArray			*ids;
	std::size_t					i;
	NSMutableDictionary			*result = nil;
	jsval						value = JSVAL_VOID;
	id							objKey = nil;
	id							objValue = nil;
	
	if (EXPECT_NOT(JSVAL_IS_NULL(tableValue) || !ooscript::valueToObject(OOJSFCX(context), OOJSFVAL(tableValue), &tableObject)))
	{
		return nil;
	}
	
	ids = ooscript::enumerate(OOJSFCX(context), tableObject);
	if (EXPECT_NOT(ids == NULL))
	{
		return nil;
	}
	
	result = [NSMutableDictionary dictionaryWithCapacity:ids->length];
	for (i = 0; i != ids->length; ++i)
	{
		jsid thisID = OOJSRJSID(ids->ids[i]);
		
		if (JSID_IS_STRING(thisID))
		{
			objKey = OOStringFromJSString(context, JSID_TO_STRING(thisID));
		}
		else
		{
			objKey = nil;
		}
		
		value = JSVAL_VOID;
		if (objKey != nil && !ooscript::lookupPropertyById(OOJSFCX(context), tableObject, OOJSFJSID(thisID), OOJSFVALP(&value)))  value = JSVAL_VOID;
		
		if (objKey != nil && !JSVAL_IS_VOID(value))
		{
			objValue = OOStringFromJSValueEvenIfNull(context, value);
			
			if (objValue != nil)
			{
				[result setObject:objValue forKey:objKey];
			}
		}
	}
	
	ooscript::destroyIdArray(OOJSFCX(context), ids);
	return result;
	
	OOJS_PROFILE_EXIT
}


namespace {
static NSMutableDictionary *sObjectConverters;
} // namespace


id OOJSNativeObjectFromJSValue(JSContext *context, jsval value)
{
	OOJS_PROFILE_ENTER
	
	if (JSVAL_IS_NULL(value) || JSVAL_IS_VOID(value))  return nil;
	
	if (JSVAL_IS_INT(value))
	{
		return [NSNumber numberWithInt:JSVAL_TO_INT(value)];
	}
	if (JSVAL_IS_DOUBLE(value))
	{
		return [NSNumber numberWithDouble:JSVAL_TO_DOUBLE(value)];
	}
	if (JSVAL_IS_BOOLEAN(value))
	{
		return [NSNumber numberWithBool:JSVAL_TO_BOOLEAN(value)];
	}
	if (JSVAL_IS_STRING(value))
	{
		return OOStringFromJSValue(context, value);
	}
	if (JSVAL_IS_OBJECT(value))
	{
		return OOJSNativeObjectFromJSObject(context, JSVAL_TO_OBJECT(value));
	}
	return nil;
	
	OOJS_PROFILE_EXIT
}


id OOJSNativeObjectFromJSObject(JSContext *context, JSObject *tableObject)
{
	OOJS_PROFILE_ENTER
	
	NSValue					*wrappedClass = nil;
	NSValue					*wrappedConverter = nil;
	OOJSClassConverterCallback converter = NULL;
	JSClass					*tableClass = NULL;
	
	if (tableObject == NULL)  return nil;
	
	tableClass = OOJSGetClass(context, tableObject);
	wrappedClass = [NSValue valueWithPointer:tableClass];
	if (wrappedClass != nil)  wrappedConverter = [sObjectConverters objectForKey:wrappedClass];
	if (wrappedConverter != nil)
	{
		converter = reinterpret_cast<OOJSClassConverterCallback>([wrappedConverter pointerValue]);
		return converter(context, tableObject);
	}
	return nil;
	
	OOJS_PROFILE_EXIT
}


id OOJSNativeObjectOfClassFromJSValue(JSContext *context, jsval value, Class requiredClass)
{
	id result = OOJSNativeObjectFromJSValue(context, value);
	if (![result isKindOfClass:requiredClass])  result = nil;
	return result;
}


id OOJSNativeObjectOfClassFromJSObject(JSContext *context, JSObject *object, Class requiredClass)
{
	id result = OOJSNativeObjectFromJSObject(context, object);
	if (![result isKindOfClass:requiredClass])  result = nil;
	return result;
}


id OOJSBasicPrivateObjectConverter(JSContext *context, JSObject *object)
{
	id						result;
	
	/*	This will do the right thing - for non-OOWeakReferences,
		weakRefUnderlyingObject returns the object itself. For nil, of course,
		it returns nil.
	*/
	result = (id)ooscript::getPrivate(OOJSFCX(context), OOJSFOBJ(object));
	return [result weakRefUnderlyingObject];
}


void OOJSRegisterObjectConverter(JSClass *theClass, OOJSClassConverterCallback converter)
{
	NSValue					*wrappedClass = nil;
	NSValue					*wrappedConverter = nil;
	
	if (theClass == NULL)  return;
	if (sObjectConverters == nil)  sObjectConverters = [[NSMutableDictionary alloc] init];
	
	wrappedClass = [NSValue valueWithPointer:theClass];
	if (converter != NULL)
	{
		wrappedConverter = [NSValue valueWithPointer:reinterpret_cast<const void*>(converter)];
		[sObjectConverters setObject:wrappedConverter forKey:wrappedClass];
	}
	else
	{
		[sObjectConverters removeObjectForKey:wrappedClass];
	}
}


namespace {
static void UnregisterObjectConverters(void)
{
	DESTROY(sObjectConverters);
}
} // namespace


namespace {
static id JSArrayConverter(JSContext *context, JSObject *array)
{
	jsuint						i, count;
	id							*values = NULL;
	jsval						value = JSVAL_VOID;
	id							object = nil;
	NSArray						*result = nil;
	
	// Convert a JS array to an NSArray by calling OOJSNativeObjectFromJSValue() on all its elements.
	if (!ooscript::isArrayObject(OOJSFCX(context), OOJSFOBJ(array))) return nil;
	if (!ooscript::getArrayLength(OOJSFCX(context), OOJSFOBJ(array), &count)) return nil;
	
	if (count == 0)  return [NSArray array];
	
	values = static_cast<id*>(calloc(count, sizeof *values));
	if (values == NULL)  return nil;
	
	for (i = 0; i != count; ++i)
	{
		value = JSVAL_VOID;
		if (!ooscript::getElement(OOJSFCX(context), OOJSFOBJ(array), i, OOJSFVALP(&value)))  value = JSVAL_VOID;
		
		object = OOJSNativeObjectFromJSValue(context, value);
		if (object == nil)  object = [NSNull null];
		values[i] = object;
	}
	
	result = [NSArray arrayWithObjects:values count:count];
	free(values);
	return result;
}
} // namespace


namespace {
static id JSStringConverter(JSContext *context, JSObject *object)
{
	return OOStringFromJSValue(context, OBJECT_TO_JSVAL(object));
}
} // namespace


namespace {
static id JSNumberConverter(JSContext *context, JSObject *object)
{
	double value;
	if (ooscript::valueToNumber(OOJSFCX(context), OOJSFVAL(OBJECT_TO_JSVAL(object)), &value))
	{
		return [NSNumber numberWithDouble:value];
	}
	return nil;
}
} // namespace


namespace {
static id JSBooleanConverter(JSContext *context, JSObject *object)
{
	/*	Fun With JavaScript: Boolean(false) is a truthy value, since it's a
		non-null object. valueToBoolean() therefore reports true.
		However, Boolean objects are transformed to numbers sanely, so this
		works.
	*/
	double value;
	if (ooscript::valueToNumber(OOJSFCX(context), OOJSFVAL(OBJECT_TO_JSVAL(object)), &value))
	{
		return [NSNumber numberWithBool:(value != 0)];
	}
	return nil;
}
} // namespace
