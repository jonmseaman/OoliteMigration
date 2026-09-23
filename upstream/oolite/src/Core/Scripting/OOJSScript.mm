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
#include "oofnd/Notification.hpp"

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

	The class's own defineProperty: method and the compiled-script cache (LoadScriptWithName /
	CompiledScriptData / ScriptWithCompiledData) used to spell out the engine's read-only
	property definition and precompiled-script/XDR calls directly, with no façade equivalent to
	retarget onto. Seam bead oo-1gc.1 (same pattern as oo-whgj for OORegExpMatcher.m/oo-1cl)
	added that equivalent to the façade -- ooscript::definePropertyById, the opaque
	ooscript::Script handle plus compileUCScript/newScriptObject/executeScript/destroyScript,
	and ooscript::serializeScript/deserializeScript wrapping the engine's XDR family (the serialised
	format itself stays backend-private, per ooscript/README.md's "Not in the façade" note) --
	so this rework moves those call sites onto it too, same as everything else in this file.

	toString() (OOJSObjectWrapperToString), the constructor (OOJSUnconstructableConstruct) and
	the finalizer (OOJSObjectWrapperFinalize) are shared natives in OOJavaScriptEngine.mm that
	take the façade signatures directly, so the class tables name them without adapters.
	ScriptAddProperty (the class's addProperty hook, used to warn about the removed tickle()
	handler) is a PropertyGetter in façade terms.
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
using ooscript::Script;
using ooscript::ByteBuffer;
using ooscript::PropertyFlag;

typedef struct RunningStack RunningStack;
struct RunningStack
{
	RunningStack		*back;
	OOJSScript			*current;
};


namespace {
static ooscript::Object sScriptPrototype;
static RunningStack		*sRunningStack = NULL;


static void AddStackToArrayReversed(NSMutableArray *array, RunningStack *stack);

static Script LoadScriptWithName(ooscript::Context context, NSString *path, ooscript::Object object, ooscript::Object *outScriptObject, NSString **outErrorMessage);

#if OO_CACHE_JS_SCRIPTS
static NSData *CompiledScriptData(ooscript::Context context, Script script);
static Script ScriptWithCompiledData(ooscript::Context context, NSData *data);
#endif

static NSString *StrippedName(NSString *string);
} // namespace


namespace {
static bool ScriptAddProperty(Context cx, Object obj, PropertyId propID, Value *value);
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
	nullptr,				// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,				// resolve (engine default: ResolveStub)
	nullptr,				// convert (engine default: ConvertStub)
	OOJSObjectWrapperFinalize,	// finalize
	nullptr,				// call
	nullptr,				// construct
	nullptr,				// backend: owned by the façade backend, must start null
};
} // namespace


namespace {
static FunctionSpec sScriptMethods[] =
{
	// JS name					Function					min args
	{ "toString",				OOJSObjectWrapperToString,	0,			0 },
	{ 0 }
};
} // namespace


// Same flag combination OOJS_PROP_READONLY expands to (ooscript::PropertyFlag::Permanent | ooscript::PropertyFlag::Enumerate |
// ooscript::PropertyFlag::ReadOnly), for the defineProperty:withID:inContext: call site below.
static constexpr PropertyFlag kScriptDefinePropertyFlags = PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly;


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
	ooscript::Context context = NULL;
	NSString				*problem = nil;	// Acts as error flag.
	Script					script = NULL;
	ooscript::Object scriptObject = NULL;
	ooscript::Value					returnValue = ooscript::undefinedValue();
	NSString				*key = nil;
	id						property = nil;
	
	self = [super init];
	if (self == nil) problem = @"allocation failure";
	else
	{
		context = OOJSAcquireContext();
		
		if (ooscript::isExceptionPending((context)))
		{
			ooscript::clearPendingException((context));
			OOLogERR(@"script.javaScript.load.waitingException", @"Prior to loading script %@, there was a pending JavaScript exception, which has been cleared. This is an internal error, please report it.", path);
		}
		
		// Set up JS object
		if (!problem)
		{
			_jsSelf = (ooscript::newObject((context), &sScriptClass, (sScriptPrototype), nullptr));
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
			if (!ooscript::setPrivate((context), (_jsSelf), OOConsumeReference([self weakRetain])))
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
		ooscript::PropertyId nameID = OOJSID("name");
		[self setProperty:[self scriptNameFromPath:path] withID:nameID inContext:context];
		
		// Run the script (allowing it to set up the properties we need, as well as setting up those event handlers)
		if (!problem)
		{
			OOJSStartTimeLimiterWithTimeLimit(kOOJSLongTimeLimit);
			if (!ooscript::executeScript((context), (_jsSelf), script, (&returnValue)))
			{
				problem = @"could not run script";
			}
			OOJSStopTimeLimiter();
			
			// We don't need the script any more - the event handlers hang around as long as the JS object exists.
			ooscript::destroyScript((context), script);
		}
		
		ooscript::removeObjectRoot((context), &scriptObject);
		
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
		ooscript::reportPendingException((context));
		DESTROY(self);
	}
	
	OOJSRelinquishContext(context);
	
	if (self != nil)
	{
		oo::NotificationCenter::defaultCenter().addObserver(self, kOOJavaScriptEngineWillResetNotificationName,
															[OOJavaScriptEngine sharedEngine],
															[self](const oo::Notification &notification) { [self javaScriptEngineWillReset:notification]; });
	}
	
	return self;
}


- (void) dealloc
{
	oo::NotificationCenter::defaultCenter().removeObserver(self, kOOJavaScriptEngineWillResetNotificationName,
															[OOJavaScriptEngine sharedEngine]);
	
	DESTROY(name);
	DESTROY(description);
	DESTROY(version);
	DESTROY(filePath);
	
	if (_jsSelf != NULL)
	{
		ooscript::Context context = OOJSAcquireContext();
		
		OOJSObjectWrapperFinalize(context, _jsSelf);	// Release weakref to self
		ooscript::removeObjectRoot((context), &_jsSelf);		// Unroot jsSelf
		
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


- (void) javaScriptEngineWillReset:(const oo::Notification &)notification
{
	// All scripts become invalid when the JS engine resets.
	if (_jsSelf != NULL)
	{
		_jsSelf = NULL;
		ooscript::Context context = OOJSAcquireContext();
		ooscript::removeObjectRoot((context), &_jsSelf);
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


- (BOOL) callMethod:(ooscript::PropertyId)methodID
		  inContext:(ooscript::Context)context
	  withArguments:(ooscript::Value *)argv count:(int)argc
			 result:(ooscript::Value *)outResult
{
	NSParameterAssert(name != NULL && (argv != NULL || argc == 0) && context != NULL && ooscript::isInRequest((context)));
	if (_jsSelf == NULL)  return NO;
	
	ooscript::Object root = NULL;
	BOOL					OK = NO;
	ooscript::Value					method = ooscript::undefinedValue();
	ooscript::Value					ignoredResult = ooscript::undefinedValue();
	
	if (outResult == NULL)  outResult = &ignoredResult;
	OOJSAddGCObjectRoot(context, &root, "OOJSScript method root");
	
	if (EXPECT(ooscript::getMethodById((context), (_jsSelf), (methodID), &root, (&method)) && !ooscript::isUndefined(method)))
	{
#ifndef NDEBUG
		if (ooscript::isExceptionPending((context)))
		{
			OOLog(@"script.internalBug", @"Exception pending on context before calling method in %s, clearing. This is an internal error, please report it.", __PRETTY_FUNCTION__);
			ooscript::clearPendingException((context));
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
		OK = ooscript::callFunctionValue((context), (_jsSelf), (method), argc, (argv), (outResult));
		OOJSStopTimeLimiter();
		
		if (ooscript::isExceptionPending((context)))
		{
			ooscript::reportPendingException((context));
			OK = NO;
		}
		
		// Pop running scripts stack
		sRunningStack = stackElement.back;
		
#ifndef NDEBUG
		OOLogOutdentIf(@"script.javaScript.call");
#endif
	}
	
	ooscript::removeObjectRoot((context), &root);
	
	return OK;
}


- (id) propertyWithID:(ooscript::PropertyId)propID inContext:(ooscript::Context)context
{
	NSParameterAssert(context != NULL && ooscript::isInRequest((context)));
	if (_jsSelf == NULL)  return nil;
	
	ooscript::Value jsValue = ooscript::undefinedValue();
	if (ooscript::getPropertyById((context), (_jsSelf), (propID), (&jsValue)))
	{
		return OOJSNativeObjectFromJSValue(context, jsValue);
	}
	return nil;
}


- (BOOL) setProperty:(id)value withID:(ooscript::PropertyId)propID inContext:(ooscript::Context)context
{
	NSParameterAssert(context != NULL && ooscript::isInRequest((context)));
	if (_jsSelf == NULL)  return NO;
	
	ooscript::Value jsValue = OOJSValueFromNativeObject(context, value);
	return ooscript::setPropertyById((context), (_jsSelf), (propID), (&jsValue));
}


- (BOOL) defineProperty:(id)value withID:(ooscript::PropertyId)propID inContext:(ooscript::Context)context
{
	NSParameterAssert(context != NULL && ooscript::isInRequest((context)));
	if (_jsSelf == NULL)  return NO;
	
	ooscript::Value jsValue = OOJSValueFromNativeObject(context, value);
	return ooscript::definePropertyById((context), (_jsSelf), (propID), (jsValue), nullptr, nullptr, kScriptDefinePropertyFlags);
}


- (id) propertyNamed:(NSString *)propName
{
	if (propName == nil)  return nil;
	if (_jsSelf == NULL)  return nil;
	
	ooscript::Context context = OOJSAcquireContext();
	id result = [self propertyWithID:OOJSIDFromString(propName) inContext:context];
	OOJSRelinquishContext(context);
	
	return result;
}


- (BOOL) setProperty:(id)value named:(NSString *)propName
{
	if (value == nil || propName == nil)  return NO;
	if (_jsSelf == NULL)  return NO;
	
	ooscript::Context context = OOJSAcquireContext();
	BOOL result = [self setProperty:value withID:OOJSIDFromString(propName) inContext:context];
	OOJSRelinquishContext(context);
	
	return result;
}


- (BOOL) defineProperty:(id)value named:(NSString *)propName
{
	if (value == nil || propName == nil)  return NO;
	if (_jsSelf == NULL)  return NO;
	
	ooscript::Context context = OOJSAcquireContext();
	BOOL result = [self defineProperty:value withID:OOJSIDFromString(propName) inContext:context];
	OOJSRelinquishContext(context);
	
	return result;
}


- (ooscript::Value)oo_jsValueInContext:(ooscript::Context)context
{
	if (_jsSelf == NULL)  return ooscript::undefinedValue();
	return ooscript::objectValue(_jsSelf);
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


@implementation OOJSScript (OOPrivate)



/*	Generate default name for script which doesn't set its name property when
	first run.
 
	The generated name is <name>.anon-script, where <name> is selected as
	follows:
	* If path is nil (futureproofing), use the address of the script object.
	* If the file's name is something other than script.*, use the file name.
	* If the containing directory is something other than Config, use the
	containing directory's name.
	* Otherwise, use the containing directory's parent (which will generally
											be an OXP root directory).
	* If either of the two previous steps results in an empty string, fall
	back on the full path.
*/
- (NSString *)scriptNameFromPath:(NSString *)path
{
	NSString		*lastComponent = nil;
	NSString		*truncatedPath = nil;
	NSString		*theName = nil;
	
	if (path == nil) theName = [NSString stringWithFormat:@"%p", self];
	else
	{
		lastComponent = [path lastPathComponent];
		if (![lastComponent hasPrefix:@"script."]) theName = lastComponent;
		else
		{
			truncatedPath = [path stringByDeletingLastPathComponent];
			if (NSOrderedSame == [[truncatedPath lastPathComponent] caseInsensitiveCompare:@"Config"])
			{
				truncatedPath = [truncatedPath stringByDeletingLastPathComponent];
			}
			if (NSOrderedSame == [[truncatedPath pathExtension] caseInsensitiveCompare:@"oxp"])
			{
				truncatedPath = [truncatedPath stringByDeletingPathExtension];
			}
			
			lastComponent = [truncatedPath lastPathComponent];
			theName = lastComponent;
		}
	}
	
	if (0 == [theName length]) theName = path;
	
	return StrippedName([theName stringByAppendingString:@".anon-script"]);
}


- (NSDictionary *) defaultPropertiesFromPath:(NSString *)path
{
	// remove file name, remove OXP subfolder, add manifest.plist
	NSString *manifestPath = [[[path stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"manifest.plist"];
	NSDictionary *manifest = OODictionaryFromFile(manifestPath);
	NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithCapacity:3];
	/* __oolite.tmp.* is allocated for OXPs without manifests. Its
	 * values are meaningless and shouldn't be used here */
	if (manifest != nil && ![[manifest oo_stringForKey:kOOManifestIdentifier] hasPrefix:@"__oolite.tmp."])
	{
		if ([manifest objectForKey:kOOManifestVersion] != nil)
		{
			[properties setObject:[manifest oo_stringForKey:kOOManifestVersion] forKey:@"version"];
		}
		if ([manifest objectForKey:kOOManifestIdentifier] != nil)
		{
			// used for system info
			[properties setObject:[manifest oo_stringForKey:kOOManifestIdentifier] forKey:kLocalManifestProperty];
		}
		if ([manifest objectForKey:kOOManifestAuthor] != nil)
		{
			[properties setObject:[manifest oo_stringForKey:kOOManifestAuthor] forKey:@"author"];
		}
		if ([manifest objectForKey:kOOManifestLicense] != nil)
		{
			[properties setObject:[manifest oo_stringForKey:kOOManifestLicense] forKey:@"license"];
		}
	}
	return properties;
}

@end


@implementation OOScript (JavaScriptEvents)

- (BOOL) callMethod:(ooscript::PropertyId)methodID
		  inContext:(ooscript::Context)context
	  withArguments:(ooscript::Value *)argv count:(int)argc
			 result:(ooscript::Value *)outResult
{
	return NO;
}

@end


void InitOOJSScript(ooscript::Context context, ooscript::Object global)
{
	Object proto = ooscript::initClass((context), (global), nullptr, &sScriptClass, OOJSUnconstructableConstruct, 0, nullptr, sScriptMethods, nullptr, nullptr);
	sScriptPrototype = (proto);
	OOJSRegisterObjectConverter(&sScriptClass, OOJSBasicPrivateObjectConverter);
}


namespace {
static bool ScriptAddProperty(Context cx, Object obj, PropertyId propID, Value * /*value*/)
{
	// Complain about attempts to set the property tickle.
	if (ooscript::isStringId(propID))
	{
		ooscript::Context context = (cx);
		ooscript::Object thisObj = (obj);
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
static Script LoadScriptWithName(ooscript::Context context, NSString *path, ooscript::Object object, ooscript::Object *outScriptObject, NSString **outErrorMessage)
{
#if OO_CACHE_JS_SCRIPTS
	OOCacheManager				*cache = nil;
#endif
	NSString					*fileContents = nil;
	NSData						*data = nil;
	Script						script = NULL;
	
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
			script = ooscript::compileUCScript((context), (object), static_cast<const ooscript::Char16*>([data bytes]), [data length] / sizeof(unichar), [path UTF8String], 1);
			if (script != NULL)  *outScriptObject = (ooscript::newScriptObject((context), script));
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
static NSData *CompiledScriptData(ooscript::Context context, Script script)
{
	NSData						*result = nil;
	ByteBuffer					buffer = { NULL, 0 };
	
	if (ooscript::serializeScript((context), script, &buffer))
	{
		result = [NSData dataWithBytes:buffer.data length:buffer.length];
	}
	ooscript::destroyByteBuffer(&buffer);
	
	return result;
}


static Script ScriptWithCompiledData(ooscript::Context context, NSData *data)
{
	if (data == nil)  return NULL;
	
	NSUInteger length = [data length];
	if (EXPECT_NOT(length > UINT32_MAX))  return NULL;
	
	return ooscript::deserializeScript((context), static_cast<const std::uint8_t*>([data bytes]), (std::size_t)length);
}
#endif


static NSString *StrippedName(NSString *string)
{
	static NSCharacterSet *invalidSet = nil;
	if (invalidSet == nil)  invalidSet = [[NSCharacterSet characterSetWithCharactersInString:@"_ 	\n\r\v"] retain];
	
	return [string stringByTrimmingCharactersInSet:invalidSet];
}
} // namespace
