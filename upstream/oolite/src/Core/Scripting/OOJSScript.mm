/*

OOJSScript.mm

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

#ifndef OO_CACHE_JS_SCRIPTS
#define OO_CACHE_JS_SCRIPTS		1
#endif


#import "OOJSScript.h"
#import "OOJavaScriptEngine.h"
#import "OOJSEngineTimeManagement.h"

#import "OOLogging.h"
#import "OOConstToString.h"
#import "Entity.h"
#import "NSStringOOExtensions.h"
#import "EntityOOJavaScriptExtensions.h"
#import "OOConstToJSString.h"
#import "OOManifestProperties.h"
#import "OOCollectionExtractors.h"
#import "OOPListParsing.h"
#import "OODebugStandards.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>
#include <jsxdrapi.h>

#if OO_CACHE_JS_SCRIPTS
#import "OOCacheManager.h"
#endif

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar): the class dispatch table becomes a static ooscript::ClassDef
	(the stub hooks are nullptr), the engine's InitClass call becomes ooscript::initClass, and
	the directly spelled engine calls (NewObject, SetPrivate, IsExceptionPending,
	ClearPendingException, ReportPendingException, RemoveObjectRoot, IsInRequest,
	GetMethodById, CallFunctionValue, GetPropertyById, SetPropertyById, StringEqualsAscii) go
	through ooscript:: instead. `this` is renamed to `thisObj` because it is a reserved word
	once this file compiles as Objective-C++ (ADR-0001).

	OOJSAcquireContext, OOJSRelinquishContext, OOJSAddGCObjectRoot, OOJSStartTimeLimiter*,
	OOJSStopTimeLimiter and the OOJS_PROP_* flag macros are OOJS_*-spelled, not directly spelled
	engine calls, so they are untouched and out of scope for this bead (see JSEngine.hpp's own
	header comment and OOJSVector.mm's exemplar comment).

	Left un-retargeted, deliberately: JS_DefinePropertyById (the class's own defineProperty:
	method) and the compiled-script cache (JS_CompileUCScript / JS_NewScriptObject /
	JS_ExecuteScript / JS_DestroyScript and the JS_XDR* serialisation family, all confined to
	this file's LoadScriptWithName/CompiledScriptData/ScriptWithCompiledData). Neither has a
	façade equivalent, ooscript/README.md's "Not in the façade" list calls the JS_XDR* family
	out by name as engine-private, and this bead's sizing caps it at "no new interfaces": it
	must not extend JSEngine.hpp/JSEngine_spidermonkey.cpp itself. Filed as dedicated seam bead
	oo-1gc.1 (same pattern as oo-whgj for OORegExpMatcher.m/oo-1cl) and blocked on it; these
	call sites keep their literal JS_ names below and are excluded from the acceptance grep's
	`\bJS_[A-Za-z]+` scan only via the seam bead landing first, not via any suppression added
	by this bead.

	toString() is a shared native (OOJSObjectWrapperToString, OOJavaScriptEngine.m) that still
	speaks the engine's own native signature; ScriptToStringFacade adapts it to the façade's
	NativeFn signature exactly as OOJSTimer.mm's TimerToStringFacade adapts the same shared
	native. ScriptAddProperty (the class's addProperty hook, used to warn about the removed
	tickle() handler) is a PropertyGetter in façade terms; ScriptUnconstructableConstruct
	adapts the shared jsapi OOJSUnconstructableConstruct to the façade's NativeFn signature the
	same way OOJSStation.mm's StationUnconstructableConstruct does, and ScriptFinalizeFacade
	adapts the shared jsapi OOJSObjectWrapperFinalize to the façade's FinalizeHook signature the
	same way OOJSStation.mm's StationFinalize does.
*/

namespace ooscript { }
using ooscript::Context;
using ooscript::Object;
using ooscript::Value;
using ooscript::PropertyId;
using ooscript::CallArgs;
using ooscript::ClassDef;
using ooscript::ClassFlag;
using ooscript::FunctionSpec;

// Byte-identical façade <-> jsapi views, local to this call site (JSEngine.hpp: Value/PropertyId
// and the handle types are byte copies of jsval/jsid/JS*; see OOJSVector.mm for the same,
// non-exported, pattern).
namespace {
static inline Context    OOJSFCX(JSContext *cx)   { return reinterpret_cast<Context>(cx); }
} // namespace
namespace {
static inline JSContext *OOJSRCX(Context cx)      { return reinterpret_cast<JSContext*>(cx); }
} // namespace
namespace {
static inline Object     OOJSFOBJ(JSObject *o)    { return reinterpret_cast<Object>(o); }
} // namespace
namespace {
static inline JSObject  *OOJSROBJ(Object o)       { return reinterpret_cast<JSObject*>(o); }
} // namespace
namespace {
static inline Object    *OOJSFOBJP(JSObject **o)  { return reinterpret_cast<Object*>(o); }
} // namespace
namespace {
static inline jsval     *OOJSRVAL(Value *v)       { return reinterpret_cast<jsval*>(v); }
} // namespace
namespace {
static inline Value     *OOJSFVALP(jsval *v)      { return reinterpret_cast<Value*>(v); }
} // namespace
namespace {
static inline Value      OOJSFVAL(jsval v)        { Value r; std::memcpy(&r, &v, sizeof r); return r; }
} // namespace
namespace {
static inline PropertyId OOJSFJSID(jsid id)       { PropertyId r; std::memcpy(&r, &id, sizeof r); return r; }
} // namespace


typedef struct RunningStack RunningStack;
struct RunningStack
{
	RunningStack		*back;
	OOJSScript			*current;
};


namespace {
static JSObject			*sScriptPrototype;
static RunningStack		*sRunningStack = NULL;


static void AddStackToArrayReversed(NSMutableArray *array, RunningStack *stack);

static JSScript *LoadScriptWithName(JSContext *context, NSString *path, JSObject *object, JSObject **outScriptObject, NSString **outErrorMessage);

#if OO_CACHE_JS_SCRIPTS
static NSData *CompiledScriptData(JSContext *context, JSScript *script);
static JSScript *ScriptWithCompiledData(JSContext *context, NSData *data);
#endif

static NSString *StrippedName(NSString *string);
} // namespace


namespace {
static bool ScriptAddProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace


// Adapts the shared jsapi OOJSObjectWrapperFinalize (OOJavaScriptEngine.m) to the façade's
// FinalizeHook signature, exactly as OOJSStation.mm's StationFinalize does.
namespace {
static void ScriptFinalizeFacade(Context cx, Object obj)
{
	OOJSObjectWrapperFinalize(OOJSRCX(cx), OOJSROBJ(obj));
}
} // namespace


// Adapts the shared jsapi OOJSUnconstructableConstruct (OOJavaScriptEngine.m) to the façade's
// NativeFn signature, exactly as OOJSStation.mm's StationUnconstructableConstruct does.
namespace {
static bool ScriptUnconstructableConstruct(Context cx, CallArgs &oojsArgs)
{
	return OOJSUnconstructableConstruct(OOJSRCX(cx), oojsArgs.count(), OOJSRVAL(oojsArgs.rawVp()));
}
} // namespace


// Adapts the shared jsapi OOJSObjectWrapperToString (OOJavaScriptEngine.m) to the façade's
// NativeFn signature, exactly as OOJSTimer.mm's TimerToStringFacade does.
namespace {
static bool ScriptToStringFacade(Context cx, CallArgs &oojsArgs)
{
	return OOJSObjectWrapperToString(OOJSRCX(cx), oojsArgs.count(), OOJSRVAL(oojsArgs.rawVp()));
}
} // namespace


namespace {
static ClassDef sScriptClass =
{
	"Script",
	ClassFlag::HasPrivate,

	ScriptAddProperty,		// addProperty
	nullptr,				// delProperty (engine default: PropertyStub)
	nullptr,				// getProperty (engine default: PropertyStub)
	nullptr,				// setProperty (engine default: StrictPropertyStub)
	nullptr,				// enumerate (engine default: EnumerateStub)
	nullptr,				// newEnumerate (JSCLASS_NEW_ENUMERATE not used)
	nullptr,				// resolve (engine default: ResolveStub)
	nullptr,				// convert (engine default: ConvertStub)
	ScriptFinalizeFacade,	// finalize
	nullptr,				// call
	nullptr,				// construct
	nullptr,				// backend: owned by the façade backend, must start null
};
} // namespace


namespace {
static FunctionSpec sScriptMethods[] =
{
	// JS name					Function					min args
	{ "toString",				ScriptToStringFacade,		0,			0 },
	{ 0 }
};
} // namespace


@interface OOJSScript (OOPrivate)

- (NSString *)scriptNameFromPath:(NSString *)path;
- (NSDictionary *)defaultPropertiesFromPath:(NSString *)path;

@end


@implementation OOJSScript

+ (id) scriptWithPath:(NSString *)path properties:(NSDictionary *)properties
{
	return [[[self alloc] initWithPath:path properties:properties] autorelease];
}


- (id) initWithPath:(NSString *)path properties:(NSDictionary *)properties
{
	JSContext				*context = NULL;
	NSString				*problem = nil;	// Acts as error flag.
	JSScript					*script = NULL;
	JSObject				*scriptObject = NULL;
	jsval					returnValue = JSVAL_VOID;
	NSString				*key = nil;
	id						property = nil;
	
	self = [super init];
	if (self == nil) problem = @"allocation failure";
	else
	{
		context = OOJSAcquireContext();
		
		if (ooscript::isExceptionPending(OOJSFCX(context)))
		{
			ooscript::clearPendingException(OOJSFCX(context));
			OOLogERR(@"script.javaScript.load.waitingException", @"Prior to loading script %@, there was a pending JavaScript exception, which has been cleared. This is an internal error, please report it.", path);
		}
		
		// Set up JS object
		if (!problem)
		{
			_jsSelf = OOJSROBJ(ooscript::newObject(OOJSFCX(context), &sScriptClass, OOJSFOBJ(sScriptPrototype), nullptr));
			if (_jsSelf == NULL) problem = @"allocation failure";
		}
		
		if (!problem && !OOJSAddGCObjectRoot(context, &_jsSelf, "Script object"))
		{
			problem = @"could not add JavaScript root object";
		}
		
		if (!problem && !OOJSAddGCObjectRoot(context, &scriptObject, "Script GC holder"))
		{
			problem = @"could not add JavaScript root object";
		}
		
		if (!problem)
		{
			if (!ooscript::setPrivate(OOJSFCX(context), OOJSFOBJ(_jsSelf), OOConsumeReference([self weakRetain])))
			{
				problem = @"could not set private backreference";
			}
		}
		
		// Push self on stack of running scripts.
		RunningStack stackElement =
		{
			.back = sRunningStack,
			.current = self
		};
		sRunningStack = &stackElement;
		
		filePath = [path retain];
		
		if (!problem)
		{
			OOLog(@"script.javaScript.willLoad", @"About to load JavaScript %@", path);
			script = LoadScriptWithName(context, path, _jsSelf, &scriptObject, &problem);
		}
		OOLogIndentIf(@"script.javaScript.willLoad");
		
		// Set default properties from manifest.plist
		NSDictionary *defaultProperties = [self defaultPropertiesFromPath:path];
		foreachkey (key, defaultProperties)
		{
			if ([key isKindOfClass:[NSString class]])
			{
				property = [defaultProperties objectForKey:key];
				if ([key isEqualToString:kLocalManifestProperty])
				{
					// this must not be editable
					[self defineProperty:property named:key];
				}
				else
				{
					// can be overwritten by script itself
					[self setProperty:property named:key];
				}
			}
		}

		// Set properties. (read-only)
		if (!problem && properties != nil)
		{
			foreachkey (key, properties)
			{
				if ([key isKindOfClass:[NSString class]])
				{
					property = [properties objectForKey:key];
					[self defineProperty:property named:key];
				}
			}
		}
		
		/*	Set initial name (in case of script error during initial run).
			The "name" ivar is not set here, so the property can be fetched from JS
			if we fail during setup. However, the "name" ivar is set later so that
			the script object can't be renamed after the initial run. This could
			probably also be achieved by fiddling with JS property attributes.
		*/
		jsid nameID = OOJSID("name");
		[self setProperty:[self scriptNameFromPath:path] withID:nameID inContext:context];
		
		// Run the script (allowing it to set up the properties we need, as well as setting up those event handlers)
		if (!problem)
		{
			OOJSStartTimeLimiterWithTimeLimit(kOOJSLongTimeLimit);
			if (!JS_ExecuteScript(context, _jsSelf, script, &returnValue))
			{
				problem = @"could not run script";
			}
			OOJSStopTimeLimiter();
			
			// We don't need the script any more - the event handlers hang around as long as the JS object exists.
			JS_DestroyScript(context, script);
		}
		
		ooscript::removeObjectRoot(OOJSFCX(context), OOJSFOBJP(&scriptObject));
		
		sRunningStack = stackElement.back;
		
		if (!problem)
		{
			// Get display attributes from script
			DESTROY(name);
			name = [StrippedName([[self propertyWithID:nameID inContext:context] description]) copy];
			if (name == nil)
			{
				name = [[self scriptNameFromPath:path] retain];
				[self setProperty:name withID:nameID inContext:context];
			}
			
			version = [[[self propertyWithID:OOJSID("version") inContext:context] description] copy];
			description = [[[self propertyWithID:OOJSID("description") inContext:context] description] copy];
			
			OOLog(@"script.javaScript.load.success", @"Loaded JavaScript: %@ -- %@", [self displayName], description ? description : (NSString *)@"(no description)");
		}
		
		OOLogOutdentIf(@"script.javaScript.willLoad");
		
		DESTROY(filePath);	// Only used for error reporting during startup.
	}
	
	if (problem)
	{
		OOLog(@"script.javaScript.load.failed", @"***** Error loading JavaScript script %@ -- %@", path, problem);
		ooscript::reportPendingException(OOJSFCX(context));
		DESTROY(self);
	}
	
	OOJSRelinquishContext(context);
	
	if (self != nil)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self
												   selector:@selector(javaScriptEngineWillReset:)
													   name:kOOJavaScriptEngineWillResetNotification
													 object:[OOJavaScriptEngine sharedEngine]];
	}
	
	return self;
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self
													   name:kOOJavaScriptEngineWillResetNotification
													 object:[OOJavaScriptEngine sharedEngine]];
	
	DESTROY(name);
	DESTROY(description);
	DESTROY(version);
	DESTROY(filePath);
	
	if (_jsSelf != NULL)
	{
		JSContext *context = OOJSAcquireContext();
		
		OOJSObjectWrapperFinalize(context, _jsSelf);	// Release weakref to self
		ooscript::removeObjectRoot(OOJSFCX(context), OOJSFOBJP(&_jsSelf));		// Unroot jsSelf
		
		OOJSRelinquishContext(context);
	}
	
	[weakSelf weakRefDrop];
	
	[super dealloc];
}


- (NSString *) oo_jsClassName
{
	return @"Script";
}


- (NSString *)descriptionComponents
{
	if (_jsSelf != NULL)  return [super descriptionComponents];
	else  return @"invalid script";
}


- (void) javaScriptEngineWillReset:(NSNotification *)notification
{
	// All scripts become invalid when the JS engine resets.
	if (_jsSelf != NULL)
	{
		_jsSelf = NULL;
		JSContext *context = OOJSAcquireContext();
		ooscript::removeObjectRoot(OOJSFCX(context), OOJSFOBJP(&_jsSelf));
		OOJSRelinquishContext(context);
	}
}


+ (OOJSScript *) currentlyRunningScript
{
	if (sRunningStack == NULL)  return NULL;
	return sRunningStack->current;
}


+ (NSArray *) scriptStack
{
	NSMutableArray			*result = nil;
	
	result = [NSMutableArray array];
	AddStackToArrayReversed(result, sRunningStack);
	return result;
}


- (id) weakRetain
{
	if (weakSelf == nil)  weakSelf = [OOWeakReference weakRefWithObject:self];
	return [weakSelf retain];
}


- (void) weakRefDied:(OOWeakReference *)weakRef
{
	if (weakRef == weakSelf)  weakSelf = nil;
}


- (NSString *) name
{
	if (name == nil)  name = [[self propertyNamed:@"name"] copy];
	if (name == nil)  return [self scriptNameFromPath:filePath];	// Special case for parse errors during load.
	return name;
}


- (NSString *) scriptDescription
{
	return description;
}


- (NSString *) version
{
	return version;
}


- (void)runWithTarget:(Entity *)target
{
	
}


- (BOOL) callMethod:(jsid)methodID
		  inContext:(JSContext *)context
	  withArguments:(jsval *)argv count:(intN)argc
			 result:(jsval *)outResult
{
	NSParameterAssert(name != NULL && (argv != NULL || argc == 0) && context != NULL && ooscript::isInRequest(OOJSFCX(context)));
	if (_jsSelf == NULL)  return NO;
	
	JSObject				*root = NULL;
	BOOL					OK = NO;
	jsval					method = JSVAL_VOID;
	jsval					ignoredResult = JSVAL_VOID;
	
	if (outResult == NULL)  outResult = &ignoredResult;
	OOJSAddGCObjectRoot(context, &root, "OOJSScript method root");
	
	if (EXPECT(ooscript::getMethodById(OOJSFCX(context), OOJSFOBJ(_jsSelf), OOJSFJSID(methodID), OOJSFOBJP(&root), OOJSFVALP(&method)) && !JSVAL_IS_VOID(method)))
	{
#ifndef NDEBUG
		if (ooscript::isExceptionPending(OOJSFCX(context)))
		{
			OOLog(@"script.internalBug", @"Exception pending on context before calling method in %s, clearing. This is an internal error, please report it.", __PRETTY_FUNCTION__);
			ooscript::clearPendingException(OOJSFCX(context));
		}
		
		OOLog(@"script.javaScript.call", @"Calling [%@].%@()", [self name], OOStringFromJSID(methodID));
		OOLogIndentIf(@"script.javaScript.call");
#endif
		
		// Push self on stack of running scripts.
		RunningStack stackElement =
		{
			.back = sRunningStack,
			.current = self
		};
		sRunningStack = &stackElement;
		
		// Call the method.
		OOJSStartTimeLimiter();
		OK = ooscript::callFunctionValue(OOJSFCX(context), OOJSFOBJ(_jsSelf), OOJSFVAL(method), argc, OOJSFVALP(argv), OOJSFVALP(outResult));
		OOJSStopTimeLimiter();
		
		if (ooscript::isExceptionPending(OOJSFCX(context)))
		{
			ooscript::reportPendingException(OOJSFCX(context));
			OK = NO;
		}
		
		// Pop running scripts stack
		sRunningStack = stackElement.back;
		
#ifndef NDEBUG
		OOLogOutdentIf(@"script.javaScript.call");
#endif
	}
	
	ooscript::removeObjectRoot(OOJSFCX(context), OOJSFOBJP(&root));
	
	return OK;
}


- (id) propertyWithID:(jsid)propID inContext:(JSContext *)context
{
	NSParameterAssert(context != NULL && ooscript::isInRequest(OOJSFCX(context)));
	if (_jsSelf == NULL)  return nil;
	
	jsval jsValue = JSVAL_VOID;
	if (ooscript::getPropertyById(OOJSFCX(context), OOJSFOBJ(_jsSelf), OOJSFJSID(propID), OOJSFVALP(&jsValue)))
	{
		return OOJSNativeObjectFromJSValue(context, jsValue);
	}
	return nil;
}


- (BOOL) setProperty:(id)value withID:(jsid)propID inContext:(JSContext *)context
{
	NSParameterAssert(context != NULL && ooscript::isInRequest(OOJSFCX(context)));
	if (_jsSelf == NULL)  return NO;
	
	jsval jsValue = OOJSValueFromNativeObject(context, value);
	return ooscript::setPropertyById(OOJSFCX(context), OOJSFOBJ(_jsSelf), OOJSFJSID(propID), OOJSFVALP(&jsValue));
}


- (BOOL) defineProperty:(id)value withID:(jsid)propID inContext:(JSContext *)context
{
	NSParameterAssert(context != NULL && ooscript::isInRequest(OOJSFCX(context)));
	if (_jsSelf == NULL)  return NO;
	
	jsval jsValue = OOJSValueFromNativeObject(context, value);
	return JS_DefinePropertyById(context, _jsSelf, propID, jsValue, NULL, NULL, OOJS_PROP_READONLY);
}


- (id) propertyNamed:(NSString *)propName
{
	if (propName == nil)  return nil;
	if (_jsSelf == NULL)  return nil;
	
	JSContext *context = OOJSAcquireContext();
	id result = [self propertyWithID:OOJSIDFromString(propName) inContext:context];
	OOJSRelinquishContext(context);
	
	return result;
}


- (BOOL) setProperty:(id)value named:(NSString *)propName
{
	if (value == nil || propName == nil)  return NO;
	if (_jsSelf == NULL)  return NO;
	
	JSContext *context = OOJSAcquireContext();
	BOOL result = [self setProperty:value withID:OOJSIDFromString(propName) inContext:context];
	OOJSRelinquishContext(context);
	
	return result;
}


- (BOOL) defineProperty:(id)value named:(NSString *)propName
{
	if (value == nil || propName == nil)  return NO;
	if (_jsSelf == NULL)  return NO;
	
	JSContext *context = OOJSAcquireContext();
	BOOL result = [self defineProperty:value withID:OOJSIDFromString(propName) inContext:context];
	OOJSRelinquishContext(context);
	
	return result;
}


- (jsval)oo_jsValueInContext:(JSContext *)context
{
	if (_jsSelf == NULL)  return JSVAL_VOID;
	return OBJECT_TO_JSVAL(_jsSelf);
}


+ (void)pushScript:(OOJSScript *)script
{
	RunningStack			*element = NULL;
	
	element = static_cast<RunningStack*>(malloc(sizeof *element));
	if (element == NULL)  exit(EXIT_FAILURE);
	
	element->back = sRunningStack;
	element->current = script;
	sRunningStack = element;
}


+ (void)popScript:(OOJSScript *)script
{
	RunningStack			*element = NULL;
	
	assert(sRunningStack->current == script);
	
	element = sRunningStack;
	sRunningStack = sRunningStack->back;
	free(element);
}

@end


@implementation OOScript (JavaScriptEvents)

- (BOOL) callMethod:(jsid)methodID
		  inContext:(JSContext *)context
	  withArguments:(jsval *)argv count:(intN)argc
			 result:(jsval *)outResult
{
	return NO;
}

@end


void InitOOJSScript(JSContext *context, JSObject *global)
{
	Object proto = ooscript::initClass(OOJSFCX(context), OOJSFOBJ(global), nullptr, &sScriptClass, ScriptUnconstructableConstruct, 0, nullptr, sScriptMethods, nullptr, nullptr);
	sScriptPrototype = OOJSROBJ(proto);
	OOJSRegisterObjectConverter(reinterpret_cast<JSClass*>(sScriptClass.backend), OOJSBasicPrivateObjectConverter);
}


namespace {
static bool ScriptAddProperty(Context cx, Object obj, PropertyId propID, Value * /*value*/)
{
	// Complain about attempts to set the property tickle.
	if (ooscript::isStringId(propID))
	{
		JSContext *context = OOJSRCX(cx);
		JSObject *thisObj = OOJSROBJ(obj);
		ooscript::String propNameStr = ooscript::idToString(propID);
		bool match = false;
		if (ooscript::stringEqualsAscii(cx, propNameStr, "tickle", &match) && match)
		{
			OOJSScript *thisScript = OOJSNativeObjectOfClassFromJSObject(context, thisObj, [OOJSScript class]);
			OOJSReportWarning(context, @"Script %@ appears to use the tickle() event handler, which is no longer supported.", [thisScript name]);
		}
	}
	
	return YES;
}
} // namespace


namespace {
static void AddStackToArrayReversed(NSMutableArray *array, RunningStack *stack)
{
	if (stack != NULL)
	{
		AddStackToArrayReversed(array, stack->back);
		[array addObject:stack->current];
	}
}
} // namespace


namespace {
static JSScript *LoadScriptWithName(JSContext *context, NSString *path, JSObject *object, JSObject **outScriptObject, NSString **outErrorMessage)
{
#if OO_CACHE_JS_SCRIPTS
	OOCacheManager				*cache = nil;
#endif
	NSString					*fileContents = nil;
	NSData						*data = nil;
	JSScript					*script = NULL;
	
	NSCParameterAssert(outScriptObject != NULL && outErrorMessage != NULL);
	*outErrorMessage = nil;
	
#if OO_CACHE_JS_SCRIPTS
	// Look for cached compiled script
	cache = [OOCacheManager sharedCache];
	data = [cache objectForKey:path inCache:@"compiled JavaScript scripts"];
	if (data != nil)
	{
		script = ScriptWithCompiledData(context, data);
	}
#endif
	
	if (script == NULL)
	{
		fileContents = [NSString stringWithContentsOfUnicodeFile:path];

		if (fileContents != nil) 
		{
#ifndef NDEBUG
		/* FIXME: this isn't strictly the right test, since strict
		 * mode can be enabled with this string within a function
		 * definition, but it seems unlikely anyone is actually doing
		 * that here. */
		if ([fileContents rangeOfString:@"\"use strict\";"].location == NSNotFound && [fileContents rangeOfString:@"'use strict';"].location == NSNotFound)
		{
			OOStandardsDeprecated([NSString stringWithFormat:@"Script %@ does not \"use strict\";",path]);
			if (OOEnforceStandards())
			{
				// prepend it anyway
				// TODO: some time after 1.82, make this required
				fileContents = [@"\"use strict\";\n" stringByAppendingString:fileContents];
			}
		}
#endif
			data = [fileContents utf16DataWithBOM:NO];
		}
		if (data == nil)  *outErrorMessage = @"could not load file";
		else
		{
			script = JS_CompileUCScript(context, object, static_cast<const jschar*>([data bytes]), [data length] / sizeof(unichar), [path UTF8String], 1);
			if (script != NULL)  *outScriptObject = JS_NewScriptObject(context, script);
			else  *outErrorMessage = @"compilation failed";
		}
		
#if OO_CACHE_JS_SCRIPTS
		if (script != NULL)
		{
			// Write compiled script to cache
			data = CompiledScriptData(context, script);
			[cache setObject:data forKey:path inCache:@"compiled JavaScript scripts"];
		}
#endif
	}
	
	return script;
}


#if OO_CACHE_JS_SCRIPTS
static NSData *CompiledScriptData(JSContext *context, JSScript *script)
{
	JSXDRState					*xdr = NULL;
	NSData						*result = nil;
	uint32						length;
	void						*bytes = NULL;
	
	xdr = JS_XDRNewMem(context, JSXDR_ENCODE);
	if (xdr != NULL)
	{
		if (JS_XDRScript(xdr, &script))
		{
			bytes = JS_XDRMemGetData(xdr, &length);
			if (bytes != NULL)
			{
				result = [NSData dataWithBytes:bytes length:length];
			}
		}
		JS_XDRDestroy(xdr);
	}
	
	return result;
}


static JSScript *ScriptWithCompiledData(JSContext *context, NSData *data)
{
	JSXDRState					*xdr = NULL;
	JSScript					*result = NULL;
	
	if (data == nil)  return NULL;
	
	xdr = JS_XDRNewMem(context, JSXDR_DECODE);
	if (xdr != NULL)
	{
		NSUInteger length = [data length];
		if (EXPECT_NOT(length > UINT32_MAX))  return NULL;
		
		JS_XDRMemSetData(xdr, (void *)[data bytes], (uint32_t)length);
		if (!JS_XDRScript(xdr, &result))  result = NULL;
		
		JS_XDRMemSetData(xdr, NULL, 0);	// Don't let it be freed by XDRDestroy
		JS_XDRDestroy(xdr);
	}
	
	return result;
}
#endif


static NSString *StrippedName(NSString *string)
{
	static NSCharacterSet *invalidSet = nil;
	if (invalidSet == nil)  invalidSet = [[NSCharacterSet characterSetWithCharactersInString:@"_ 	\n\r\v"] retain];
	
	return [string stringByTrimmingCharactersInSet:invalidSet];
}
} // namespace
