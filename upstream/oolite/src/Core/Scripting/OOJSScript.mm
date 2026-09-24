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
#import "OOPListView.h"
#import "OOPListParsing.h"
#import "OODebugStandards.h"
#import "OOFoundationBridge.h"
#import "NSDataOOExtensions.h"
#include "oofnd/Encoding.hpp"

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


static void AddStackToArrayReversed(std::vector<oo::ObjCRef<OOJSScript *>> &array, RunningStack *stack);

static Script LoadScriptWithName(ooscript::Context context, const std::optional<std::string> &path, ooscript::Object object, ooscript::Object *outScriptObject, std::optional<std::string> *outErrorMessage);

#if OO_CACHE_JS_SCRIPTS
static std::optional<oo::Data> CompiledScriptData(ooscript::Context context, Script script);
static Script ScriptWithCompiledData(ooscript::Context context, const oo::Data &data);
#endif

static std::optional<std::string> StrippedName(const std::optional<std::string> &string);

// [[object description] copy]: nil stays nil.
static std::optional<std::string> DescriptionOrNil(id object);

// -oo_stringForKey: with its nil; a string value for -setObject:forKey:, which raised on nil.
static std::optional<std::string> StringForKey(const oo::PList &dictionary, const std::string &key);
static std::string ValueForKey(const std::optional<std::string> &value, id key);
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

- (std::string)scriptNameFromPath:(const std::optional<std::string> &)path;
- (oo::PList::Dict)defaultPropertiesFromPath:(const std::optional<std::string> &)path;

@end


@implementation OOJSScript

+ (id) scriptWithPath:(const std::optional<std::string> &)path properties:(const oo::PList &)properties
{
	return [[[self alloc] initWithPath:path properties:properties] autorelease];
}


- (id) initWithPath:(const std::optional<std::string> &)path properties:(const oo::PList &)properties
{
	ooscript::Context context = NULL;
	std::optional<std::string>	problem;	// Acts as error flag.
	Script					script = NULL;
	ooscript::Object scriptObject = NULL;
	ooscript::Value					returnValue = ooscript::undefinedValue();
	
	self = [super init];
	if (self == nil) problem = "allocation failure";
	else
	{
		context = OOJSAcquireContext();
		
		if (ooscript::isExceptionPending((context)))
		{
			ooscript::clearPendingException((context));
			OOLogERR(@"script.javaScript.load.waitingException", @"Prior to loading script %@, there was a pending JavaScript exception, which has been cleared. This is an internal error, please report it.", oo::NSStringOrNil(path));
		}
		
		// Set up JS object
		if (!problem.has_value())
		{
			_jsSelf = (ooscript::newObject((context), &sScriptClass, (sScriptPrototype), nullptr));
			if (_jsSelf == NULL) problem = "allocation failure";
		}
		
		if (!problem.has_value() && !OOJSAddGCObjectRoot(context, &_jsSelf, "Script object"))
		{
			problem = "could not add JavaScript root object";
		}
		
		if (!problem.has_value() && !OOJSAddGCObjectRoot(context, &scriptObject, "Script GC holder"))
		{
			problem = "could not add JavaScript root object";
		}
		
		if (!problem.has_value())
		{
			if (!ooscript::setPrivate((context), (_jsSelf), OOConsumeReference([self weakRetain])))
			{
				problem = "could not set private backreference";
			}
		}
		
		// Push self on stack of running scripts.
		RunningStack stackElement =
		{
			.back = sRunningStack,
			.current = self
		};
		sRunningStack = &stackElement;
		
		filePath = path;
		
		if (!problem.has_value())
		{
			OOLog(@"script.javaScript.willLoad", @"About to load JavaScript %@", oo::NSStringOrNil(path));
			script = LoadScriptWithName(context, path, _jsSelf, &scriptObject, &problem);
		}
		OOLogIndentIf(@"script.javaScript.willLoad");
		
		// Set default properties from manifest.plist
		// Order-sensitive: the properties are set in key order (they were set in hash order).
		const oo::PList::Dict defaultProperties = [self defaultPropertiesFromPath:path];
		for (const auto &[key, property] : defaultProperties)
		{
			if (key == kLocalManifestProperty)
			{
				// this must not be editable
				[self defineProperty:oo::ObjectFromPList(property) named:key];
			}
			else
			{
				// can be overwritten by script itself
				[self setProperty:oo::ObjectFromPList(property) named:key];
			}
		}

		// Set properties. (read-only)
		// Order-sensitive: defined in key order (they were defined in hash order).
		if (!problem.has_value() && !properties.isNull())
		{
			if (const oo::PList::Dict *propertyDict = properties.getIf<oo::PList::Dict>())
			{
				for (const auto &[key, property] : *propertyDict)
				{
					[self defineProperty:oo::ObjectFromPList(property) named:key];
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
		[self setProperty:oo::NSStringFrom([self scriptNameFromPath:path]) withID:nameID inContext:context];
		
		// Run the script (allowing it to set up the properties we need, as well as setting up those event handlers)
		if (!problem.has_value())
		{
			OOJSStartTimeLimiterWithTimeLimit(kOOJSLongTimeLimit);
			if (!ooscript::executeScript((context), (_jsSelf), script, (&returnValue)))
			{
				problem = "could not run script";
			}
			OOJSStopTimeLimiter();
			
			// We don't need the script any more - the event handlers hang around as long as the JS object exists.
			ooscript::destroyScript((context), script);
		}
		
		ooscript::removeObjectRoot((context), &scriptObject);
		
		sRunningStack = stackElement.back;
		
		if (!problem.has_value())
		{
			// Get display attributes from script
			name.reset();
			name = StrippedName(DescriptionOrNil([self propertyWithID:nameID inContext:context]));
			if (!name.has_value())
			{
				name = [self scriptNameFromPath:path];
				[self setProperty:oo::NSStringFrom(*name) withID:nameID inContext:context];
			}
			
			version = DescriptionOrNil([self propertyWithID:OOJSID("version") inContext:context]);
			description = DescriptionOrNil([self propertyWithID:OOJSID("description") inContext:context]);
			
			OOLog(@"script.javaScript.load.success", @"Loaded JavaScript: %@ -- %@", [self displayName], oo::NSStringFrom(description.value_or("(no description)")));
		}
		
		OOLogOutdentIf(@"script.javaScript.willLoad");
		
		filePath.reset();	// Only used for error reporting during startup.
	}
	
	if (problem.has_value())
	{
		OOLog(@"script.javaScript.load.failed", @"***** Error loading JavaScript script %@ -- %@", oo::NSStringOrNil(path), oo::NSStringFrom(*problem));
		ooscript::reportPendingException((context));
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


- (id) oo_jsClassName	// shared selector (proposed ADR-0043)
{
	return @"Script";
}


- (id)descriptionComponents	// shared selector (proposed ADR-0043)
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


+ (std::vector<oo::ObjCRef<OOJSScript *>>) scriptStack
{
	std::vector<oo::ObjCRef<OOJSScript *>>	result;
	
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


- (id) name	// shared selector (proposed ADR-0043)
{
	// (the property as text: a string is itself, anything else its -description)
	if (!name.has_value())  name = DescriptionOrNil([self propertyNamed:"name"]);
	if (!name.has_value())  return oo::NSStringFrom([self scriptNameFromPath:filePath]);	// Special case for parse errors during load.
	return oo::NSStringFrom(*name);
}


- (id) scriptDescription	// shared selector (proposed ADR-0043)
{
	return oo::NSStringOrNil(description);
}


- (std::optional<std::string>) cxx_version
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
	NSParameterAssert(name.has_value() && (argv != NULL || argc == 0) && context != NULL && ooscript::isInRequest((context)));
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


- (id) propertyNamed:(const std::string &)propName
{
	if (_jsSelf == NULL)  return nil;
	
	ooscript::Context context = OOJSAcquireContext();
	id result = [self propertyWithID:OOJSIDFromString(oo::NSStringFrom(propName)) inContext:context];
	OOJSRelinquishContext(context);
	
	return result;
}


- (BOOL) setProperty:(id)value named:(const std::string &)propName
{
	if (value == nil)  return NO;
	if (_jsSelf == NULL)  return NO;
	
	ooscript::Context context = OOJSAcquireContext();
	BOOL result = [self setProperty:value withID:OOJSIDFromString(oo::NSStringFrom(propName)) inContext:context];
	OOJSRelinquishContext(context);
	
	return result;
}


- (BOOL) defineProperty:(id)value named:(const std::string &)propName
{
	if (value == nil)  return NO;
	if (_jsSelf == NULL)  return NO;
	
	ooscript::Context context = OOJSAcquireContext();
	BOOL result = [self defineProperty:value withID:OOJSIDFromString(oo::NSStringFrom(propName)) inContext:context];
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
- (std::string)scriptNameFromPath:(const std::optional<std::string> &)path
{
	std::string		lastComponent;
	std::string		truncatedPath;
	std::string		theName;
	
	if (!path.has_value()) theName = oo::str::pointerDescription(self);
	else
	{
		lastComponent = oo::str::lastPathComponent(*path);
		if (!oo::str::hasPrefix(lastComponent, "script.")) theName = lastComponent;
		else
		{
			truncatedPath = oo::str::deletingLastPathComponent(*path);
			if (0 == oo::str::caseInsensitiveCompare(oo::str::lastPathComponent(truncatedPath), "Config"))
			{
				truncatedPath = oo::str::deletingLastPathComponent(truncatedPath);
			}
			const std::string extension = oo::str::pathExtension(truncatedPath);
			if (0 == oo::str::caseInsensitiveCompare(extension, "oxp"))
			{
				// -stringByDeletingPathExtension: the ".oxp" at the end goes (the path has no trailing
				// separator, having just lost a component).
				truncatedPath.resize(truncatedPath.size() - extension.size() - 1);
			}
			
			lastComponent = oo::str::lastPathComponent(truncatedPath);
			theName = lastComponent;
		}
	}
	
	if (theName.empty()) theName = path.value_or("");
	
	return *StrippedName(theName + ".anon-script");
}


- (oo::PList::Dict) defaultPropertiesFromPath:(const std::optional<std::string> &)path
{
	// remove file name, remove OXP subfolder, add manifest.plist (a nil path messaged nil: no manifest)
	const oo::PList manifest = path.has_value() ? oo::PListFrom(OODictionaryFromFile(oo::NSStringFrom(oo::str::appendingPathComponent(oo::str::deletingLastPathComponent(oo::str::deletingLastPathComponent(*path)), "manifest.plist")))) : oo::PList();
	oo::PList::Dict properties;
	/* __oolite.tmp.* is allocated for OXPs without manifests. Its
	 * values are meaningless and shouldn't be used here */
	const std::optional<std::string> identifier = StringForKey(manifest, oo::StdString(kOOManifestIdentifier));
	if (manifest && !(identifier.has_value() && oo::str::hasPrefix(*identifier, "__oolite.tmp.")))
	{
		if (manifest.get<oo::PList>(oo::StdString(kOOManifestVersion)) != nullptr)
		{
			properties["version"] = ValueForKey(StringForKey(manifest, oo::StdString(kOOManifestVersion)), @"version");
		}
		if (manifest.get<oo::PList>(oo::StdString(kOOManifestIdentifier)) != nullptr)
		{
			// used for system info
			properties[kLocalManifestProperty] = ValueForKey(identifier, oo::NSStringFrom(kLocalManifestProperty));
		}
		if (manifest.get<oo::PList>(oo::StdString(kOOManifestAuthor)) != nullptr)
		{
			properties["author"] = ValueForKey(StringForKey(manifest, oo::StdString(kOOManifestAuthor)), @"author");
		}
		if (manifest.get<oo::PList>(oo::StdString(kOOManifestLicense)) != nullptr)
		{
			properties["license"] = ValueForKey(StringForKey(manifest, oo::StdString(kOOManifestLicense)), @"license");
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
static void AddStackToArrayReversed(std::vector<oo::ObjCRef<OOJSScript *>> &array, RunningStack *stack)
{
	if (stack != NULL)
	{
		AddStackToArrayReversed(array, stack->back);
		// -addObject: raised on the nil a script-less push leaves (GNUstep 1.31.1's text).
		if (stack->current == nil)  [NSException raise:NSInvalidArgumentException format:@"Tried to add nil to array"];
		array.emplace_back(stack->current);
	}
}
} // namespace


namespace {
static Script LoadScriptWithName(ooscript::Context context, const std::optional<std::string> &path, ooscript::Object object, ooscript::Object *outScriptObject, std::optional<std::string> *outErrorMessage)
{
#if OO_CACHE_JS_SCRIPTS
	OOCacheManager				*cache = nil;
#endif
	std::optional<std::string>	fileContents;
	std::optional<std::u16string>	data;	// the script's UTF-16 units
	Script						script = NULL;
	
	NSCParameterAssert(outScriptObject != NULL && outErrorMessage != NULL);
	outErrorMessage->reset();
	
#if OO_CACHE_JS_SCRIPTS
	// Look for cached compiled script (a nil path is the key "", as the cache read it)
	cache = [OOCacheManager sharedCache];
	const oo::PList cached = oo::PListFrom([cache cxx_objectForKey:path.value_or("") inCache:"compiled JavaScript scripts"]);
	if (const oo::Data *cachedData = cached.getIf<oo::PList::Data>())
	{
		script = ScriptWithCompiledData(context, *cachedData);
	}
#endif
	
	if (script == NULL)
	{
		// +stringWithContentsOfUnicodeFile: (it read through .oxz archives)
		if (path.has_value())
		{
			if (const std::optional<oo::Data> bytes = OODataFromOXZFile(*path))  fileContents = oo::str::decodeUnicodeText(bytes->stringView());
		}

		if (fileContents.has_value())
		{
#ifndef NDEBUG
		/* FIXME: this isn't strictly the right test, since strict
		 * mode can be enabled with this string within a function
		 * definition, but it seems unlikely anyone is actually doing
		 * that here. */
		if (fileContents->find("\"use strict\";") == std::string::npos && fileContents->find("'use strict';") == std::string::npos)
		{
			cxx_OOStandardsDeprecated("Script " + oo::DescriptionOf(oo::NSStringOrNil(path)) + " does not \"use strict\";");
			if (OOEnforceStandards())
			{
				// prepend it anyway
				// TODO: some time after 1.82, make this required
				fileContents = "\"use strict\";\n" + *fileContents;
			}
		}
#endif
			data = oo::utf8ToUtf16(*fileContents);
		}
		if (!data.has_value())  *outErrorMessage = "could not load file";
		else
		{
			script = ooscript::compileUCScript((context), (object), reinterpret_cast<const ooscript::Char16*>(data->data()), data->size(), path.has_value() ? path->c_str() : NULL, 1);
			if (script != NULL)  *outScriptObject = (ooscript::newScriptObject((context), script));
			else  *outErrorMessage = "compilation failed";
		}
		
#if OO_CACHE_JS_SCRIPTS
		if (script != NULL)
		{
			// Write compiled script to cache
			const std::optional<oo::Data> compiled = CompiledScriptData(context, script);
			[cache cxx_setObject:(compiled.has_value() ? oo::ObjectFromPList(oo::PList(*compiled)) : nil) forKey:path.value_or("") inCache:"compiled JavaScript scripts"];
		}
#endif
	}
	
	return script;
}


#if OO_CACHE_JS_SCRIPTS
static std::optional<oo::Data> CompiledScriptData(ooscript::Context context, Script script)
{
	std::optional<oo::Data>		result;
	ByteBuffer					buffer = { NULL, 0 };
	
	if (ooscript::serializeScript((context), script, &buffer))
	{
		result = oo::Data(buffer.data, buffer.length);
	}
	ooscript::destroyByteBuffer(&buffer);
	
	return result;
}


static Script ScriptWithCompiledData(ooscript::Context context, const oo::Data &data)
{
	std::size_t length = data.length();
	if (EXPECT_NOT(length > UINT32_MAX))  return NULL;
	
	return ooscript::deserializeScript((context), static_cast<const std::uint8_t*>(data.bytes()), length);
}
#endif


// -stringByTrimmingCharactersInSet: of "_", space, tab, LF, CR and VT (all ASCII, so UTF-8 bytes).
static std::optional<std::string> StrippedName(const std::optional<std::string> &string)
{
	if (!string.has_value())  return std::nullopt;
	static constexpr std::string_view kInvalid = "_ \t\n\r\v";
	const std::size_t first = string->find_first_not_of(kInvalid);
	if (first == std::string::npos)  return std::string();
	const std::size_t last = string->find_last_not_of(kInvalid);
	return string->substr(first, last - first + 1);
}


static std::optional<std::string> DescriptionOrNil(id object)
{
	if (object == nil)  return std::nullopt;
	return oo::OptionalString([object description]);
}


// -oo_stringForKey: with its nil: the string, a number's -stringValue, or nothing.
static std::optional<std::string> StringForKey(const oo::PList &dictionary, const std::string &key)
{
	const oo::PList *value = dictionary.get<oo::PList>(key);
	if (value == nullptr || !(value->isString() || value->isNumber()))  return std::nullopt;
	return dictionary.get<std::string>(key);
}


// A string value for -setObject:forKey:, which raised on nil (GNUstep 1.31.1's text).
static std::string ValueForKey(const std::optional<std::string> &value, id key)
{
	if (!value.has_value())  [NSException raise:NSInvalidArgumentException format:@"Tried to add nil value for key '%@' to dictionary", key];
	return *value;
}
} // namespace
