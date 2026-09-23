/*

OOJSConsole.m


Oolite
Copyright (C) 2004-2013 Giles C Williams and contributors

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

#ifndef NDEBUG

#import "OOJSConsole.h"
#import "OODebugMonitor.h"
#include <stdint.h>

#import "OOJSEngineTimeManagement.h"
#import "OOJSScript.h"
#import "OOJSVector.h"
#import "OOJSEntity.h"
#import "OOJSCall.h"
#import "OOLoggingExtended.h"
#import "OOConstToString.h"
#import "OOOpenGLExtensionManager.h"
#import "OODebugFlags.h"
#import "OODebugMonitor.h"
#import "OOProfilingStopwatch.h"
#import "ResourceManager.h"
#import "OOFoundationBridge.h"
#import "OOLogHeader.h"	// OOPlatformDescription()

#include "oofnd/String.hpp"


@interface Entity (OODebugInspector)

// Method added by inspector in Debug OXP under OS X only.
- (void) inspect;

@end




static ooscript::Object sConsolePrototype = NULL;
static ooscript::Object sConsoleSettingsPrototype = NULL;


static bool ConsoleGetProperty(ooscript::Context context, ooscript::Object thisObject, ooscript::PropertyId propID, ooscript::Value *value);
static bool ConsoleSetProperty(ooscript::Context context, ooscript::Object thisObject, ooscript::PropertyId propID, bool strict, ooscript::Value *value);
static void ConsoleFinalize(ooscript::Context context, ooscript::Object thisObject);

// Methods
static bool ConsoleConsoleMessage(ooscript::Context context, ooscript::CallArgs &oojsArgs);
static bool ConsoleClearConsole(ooscript::Context context, ooscript::CallArgs &oojsArgs);
static bool ConsoleScriptStack(ooscript::Context context, ooscript::CallArgs &oojsArgs);
static bool ConsoleInspectEntity(ooscript::Context context, ooscript::CallArgs &oojsArgs);
#if OO_DEBUG
static bool ConsoleCallObjCMethod(ooscript::Context context, ooscript::CallArgs &oojsArgs);
static bool ConsoleSetUpCallObjC(ooscript::Context context, ooscript::CallArgs &oojsArgs);
#endif
static bool ConsoleIsExecutableJavaScript(ooscript::Context context, ooscript::CallArgs &oojsArgs);
static bool ConsoleDisplayMessagesInClass(ooscript::Context context, ooscript::CallArgs &oojsArgs);
static bool ConsoleSetDisplayMessagesInClass(ooscript::Context context, ooscript::CallArgs &oojsArgs);
static bool ConsoleWriteLogMarker(ooscript::Context context, ooscript::CallArgs &oojsArgs);
static bool ConsoleWriteMemoryStats(ooscript::Context context, ooscript::CallArgs &oojsArgs);
static bool ConsoleWriteJSMemoryStats(ooscript::Context context, ooscript::CallArgs &oojsArgs);
static bool ConsoleGarbageCollect(ooscript::Context context, ooscript::CallArgs &oojsArgs);
#if DEBUG
static bool ConsoleDumpNamedRoots(ooscript::Context context, ooscript::CallArgs &oojsArgs);
static bool ConsoleDumpHeap(ooscript::Context context, ooscript::CallArgs &oojsArgs);
#endif
#if OOJS_PROFILE
static bool ConsoleProfile(ooscript::Context context, ooscript::CallArgs &oojsArgs);
static bool ConsoleGetProfile(ooscript::Context context, ooscript::CallArgs &oojsArgs);
static bool ConsoleTrace(ooscript::Context context, ooscript::CallArgs &oojsArgs);
#endif

static bool ConsoleSettingsDeleteProperty(ooscript::Context context, ooscript::Object thisObject, ooscript::PropertyId propID, ooscript::Value *value);
static bool ConsoleSettingsGetProperty(ooscript::Context context, ooscript::Object thisObject, ooscript::PropertyId propID, ooscript::Value *value);
static bool ConsoleSettingsSetProperty(ooscript::Context context, ooscript::Object thisObject, ooscript::PropertyId propID, bool strict, ooscript::Value *value);

#if OOJS_PROFILE
namespace {
bool PerformProfiling(ooscript::Context context, const char *nominalFunction, unsigned argc, ooscript::Value *argv, ooscript::Value *rval, BOOL trace, OOTimeProfile **profile);
}	// namespace
#endif


static ooscript::ClassDef sConsoleClass =
{
	"Console",
	ooscript::ClassFlag::HasPrivate,
	
	nullptr,				// addProperty
	nullptr,				// delProperty
	ConsoleGetProperty,				// getProperty
	ConsoleSetProperty,				// setProperty
	nullptr,				// enumerate
	nullptr,				// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,					// resolve
	nullptr,					// convert
	ConsoleFinalize,				// finalize
	nullptr,				// call
	nullptr,				// construct
	nullptr,				// backend: owned by the façade backend, must start null
};


enum
{
	// Property IDs
	kConsole_debugFlags,						// debug flags, integer, read/write
	kConsole_detailLevel,						// graphics detail level, symbolic string, read/write
	kConsole_maximumDetailLevel,				// maximum graphics detail level, symbolic string, read-only
	kConsole_displayFPS,						// display FPS (and related info), boolean, read/write
	kConsole_platformDescription,				// Information about system we're running on in unspecified format, string, read-only
	kConsole_ignoreDroppedPackets,				// boolean (default false), read/write
	kConsole_pedanticMode,						// JS pedantic mode (the engine's strict option, not the same as "use strict"), boolean (default true), read/write
	kConsole_showErrorLocations,				// Show error/warning source locations, boolean (default true), read/write
	kConsole_dumpStackForErrors,				// Write stack dump when reporting error/exception, boolean (default false), read/write
	kConsole_dumpStackForWarnings,				// Write stack dump when reporting warning, boolean (default false), read/write
	
	kConsole_glVendorString,					// OpenGL GL_VENDOR string, string, read-only
	kConsole_glRendererString,					// OpenGL GL_RENDERER string, string, read-only
	kConsole_glFixedFunctionTextureUnitCount,	// GL_MAX_TEXTURE_UNITS_ARB, integer, read-only
	kConsole_glFragmentShaderTextureUnitCount,	// GL_MAX_TEXTURE_IMAGE_UNITS_ARB, integer, read-only
	
	// Symbolic constants for debug flags:
	kConsole_DEBUG_LINKED_LISTS,
	kConsole_DEBUG_COLLISIONS,
	kConsole_DEBUG_DOCKING,
	kConsole_DEBUG_OCTREE_LOGGING,
	kConsole_DEBUG_BOUNDING_BOXES,
	kConsole_DEBUG_OCTREE_DRAW,
	kConsole_DEBUG_DRAW_NORMALS,
	kConsole_DEBUG_NO_DUST,
	kConsole_DEBUG_NO_SHADER_FALLBACK,
	kConsole_DEBUG_SHADER_VALIDATION,
	
	kConsole_DEBUG_MISC
};


static ooscript::PropertySpec sConsoleProperties[] =
{
	// JS name								ID											flags
	{ "debugFlags",							kConsole_debugFlags,						OOJS_PROP_READWRITE_CB },
	{ "detailLevel",						kConsole_detailLevel,						OOJS_PROP_READWRITE_CB },
	{ "maximumDetailLevel",					kConsole_maximumDetailLevel,				OOJS_PROP_READONLY_CB },
	{ "displayFPS",							kConsole_displayFPS,						OOJS_PROP_READWRITE_CB },
	{ "platformDescription",				kConsole_platformDescription,				OOJS_PROP_READONLY_CB },
	{ "pedanticMode",						kConsole_pedanticMode,						OOJS_PROP_READWRITE_CB },
	{ "ignoreDroppedPackets",				kConsole_ignoreDroppedPackets,				OOJS_PROP_READWRITE_CB },
	{ "__showErrorLocations",				kConsole_showErrorLocations,				OOJS_PROP_HIDDEN_READWRITE_CB },
	{ "__dumpStackForErrors",				kConsole_dumpStackForErrors,				OOJS_PROP_HIDDEN_READWRITE_CB },
	{ "__dumpStackForWarnings",				kConsole_dumpStackForWarnings,				OOJS_PROP_HIDDEN_READWRITE_CB },
	{ "glVendorString",						kConsole_glVendorString,					OOJS_PROP_READONLY_CB },
	{ "glRendererString",					kConsole_glRendererString,					OOJS_PROP_READONLY_CB },
	{ "glFixedFunctionTextureUnitCount",	kConsole_glFixedFunctionTextureUnitCount,	OOJS_PROP_READONLY_CB },
	{ "glFragmentShaderTextureUnitCount",	kConsole_glFragmentShaderTextureUnitCount,	OOJS_PROP_READONLY_CB },
	
#define DEBUG_FLAG_DECL(x) { #x, kConsole_##x, OOJS_PROP_READONLY_CB }
	DEBUG_FLAG_DECL(DEBUG_LINKED_LISTS),
	DEBUG_FLAG_DECL(DEBUG_COLLISIONS),
	DEBUG_FLAG_DECL(DEBUG_DOCKING),
	DEBUG_FLAG_DECL(DEBUG_OCTREE_LOGGING),
	DEBUG_FLAG_DECL(DEBUG_BOUNDING_BOXES),
	DEBUG_FLAG_DECL(DEBUG_OCTREE_DRAW),
	DEBUG_FLAG_DECL(DEBUG_DRAW_NORMALS),
	DEBUG_FLAG_DECL(DEBUG_NO_DUST),
	DEBUG_FLAG_DECL(DEBUG_NO_SHADER_FALLBACK),
	DEBUG_FLAG_DECL(DEBUG_SHADER_VALIDATION),
	
	DEBUG_FLAG_DECL(DEBUG_MISC),
#undef DEBUG_FLAG_DECL
	
	{ 0 }
};


static ooscript::FunctionSpec sConsoleMethods[] =
{
	// JS name							Function							min args
	{ "consoleMessage",					ConsoleConsoleMessage,				2 },
	{ "clearConsole",					ConsoleClearConsole,				0 },
	{ "scriptStack",					ConsoleScriptStack,					0 },
	{ "inspectEntity",					ConsoleInspectEntity,				1 },
#if OO_DEBUG
	{ "__setUpCallObjC",				ConsoleSetUpCallObjC,				1 },
#endif
	{ "isExecutableJavaScript",			ConsoleIsExecutableJavaScript,		2 },
	{ "displayMessagesInClass",			ConsoleDisplayMessagesInClass,		1 },
	{ "setDisplayMessagesInClass",		ConsoleSetDisplayMessagesInClass,	2 },
	{ "writeLogMarker",					ConsoleWriteLogMarker,				0 },
	{ "writeMemoryStats",				ConsoleWriteMemoryStats,			0 },
	{ "writeJSMemoryStats",				ConsoleWriteJSMemoryStats,			0 },
	{ "garbageCollect",					ConsoleGarbageCollect,				0 },
#if DEBUG
	{ "dumpNamedRoots",					ConsoleDumpNamedRoots,				0 },
	{ "dumpHeap",						ConsoleDumpHeap,					0 },
#endif
#if OOJS_PROFILE
	{ "profile",						ConsoleProfile,						1 },
	{ "getProfile",						ConsoleGetProfile,					1 },
	{ "trace",							ConsoleTrace,						1 },
#endif
	{ 0 }
};


static ooscript::ClassDef sConsoleSettingsClass =
{
	"ConsoleSettings",
	ooscript::ClassFlag::HasPrivate,
	
	nullptr,				// addProperty
	ConsoleSettingsDeleteProperty,	// delProperty
	ConsoleSettingsGetProperty,		// getProperty
	ConsoleSettingsSetProperty,		// setProperty
	nullptr,				// enumerate. FIXME: this should work.
	nullptr,				// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,					// resolve
	nullptr,					// convert
	ConsoleFinalize,				// finalize (same as Console)
	nullptr,				// call
	nullptr,				// construct
	nullptr,				// backend: owned by the façade backend, must start null
};


static void InitOOJSConsole(ooscript::Context context, ooscript::Object global)
{
	sConsolePrototype = ooscript::initClass(context, global, NULL, &sConsoleClass, OOJSUnconstructableConstruct, 0, sConsoleProperties, sConsoleMethods, NULL, NULL);
	OOJSRegisterObjectConverter(&sConsoleClass, OOJSBasicPrivateObjectConverter);
	
	sConsoleSettingsPrototype = ooscript::initClass(context, global, NULL, &sConsoleSettingsClass, OOJSUnconstructableConstruct, 0, NULL, NULL, NULL, NULL);
	OOJSRegisterObjectConverter(&sConsoleSettingsClass, OOJSBasicPrivateObjectConverter);
}


void OOJSConsoleDestroy(void)
{
	sConsolePrototype = NULL;
}


ooscript::Object DebugMonitorToJSConsole(ooscript::Context context, OODebugMonitor *monitor)
{
	OOJS_PROFILE_ENTER
	
	OOJavaScriptEngine		*engine = nil;
	ooscript::Object object = NULL;
	ooscript::Object settingsObject = NULL;
	ooscript::Value					value;
	
	engine = [OOJavaScriptEngine sharedEngine];
	
	if (sConsolePrototype == NULL)
	{
		InitOOJSConsole(context, [engine globalObject]);
	}
	
	// Create Console object
	object = ooscript::newObject(context, &sConsoleClass, sConsolePrototype, NULL);
	if (object != NULL)
	{
		if (!ooscript::setPrivate(context, object, [monitor weakRetain]))  object = NULL;
	}
	
	if (object != NULL)
	{
		// Create ConsoleSettings object
		settingsObject = ooscript::newObject(context, &sConsoleSettingsClass, sConsoleSettingsPrototype, NULL);
		if (settingsObject != NULL)
		{
			if (!ooscript::setPrivate(context, settingsObject, [monitor weakRetain]))  settingsObject = NULL;
		}
		if (settingsObject != NULL)
		{
			value = ooscript::objectValue(settingsObject);
			if (!ooscript::setProperty(context, object, "settings", &value))
			{
				settingsObject = NULL;
			}
		}

		if (settingsObject == NULL)  object = NULL;
	}
	
	
	return object;
	// Analyzer: object leaked. (x2) [Expected, objects are retained by JS object.]
	
	OOJS_PROFILE_EXIT
}


static bool ConsoleGetProperty(ooscript::Context context, ooscript::Object thisObject, ooscript::PropertyId propID, ooscript::Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	OOJS_NATIVE_ENTER(context)
	
	switch (ooscript::idToInt32(propID))
	{
#ifndef NDEBUG
		case kConsole_debugFlags:
			*value = ooscript::int32Value((uint32_t)gDebugFlags);
			break;
#endif		
			
		case kConsole_detailLevel:
			*value = [OOStringFromGraphicsDetail([UNIVERSE detailLevel]) oo_jsValueInContext:context];
			break;
			
		case kConsole_maximumDetailLevel:
			*value = [OOStringFromGraphicsDetail([[OOOpenGLExtensionManager sharedManager] maximumDetailLevel]) oo_jsValueInContext:context];
			break;
			
		case kConsole_displayFPS:
			*value = OOJSValueFromBOOL([UNIVERSE displayFPS]);
			break;
			
		case kConsole_platformDescription:
			*value = OOJSValueFromNativeObject(context, oo::NSStringFrom(OOPlatformDescription()));
			break;
			
		case kConsole_pedanticMode:
			{
				uint32_t options = static_cast<uint32_t>(ooscript::getOptions(context));
				*value = OOJSValueFromBOOL(options & static_cast<uint32_t>(ooscript::ContextOption::Strict));
			}
			break;
			
		case kConsole_ignoreDroppedPackets:
			*value = OOJSValueFromBOOL([[OODebugMonitor sharedDebugMonitor] TCPIgnoresDroppedPackets]);
			break;
			
		case kConsole_showErrorLocations:
			*value = OOJSValueFromBOOL([[OOJavaScriptEngine sharedEngine] showErrorLocations]);
			break;
			
		case kConsole_dumpStackForErrors:
			*value = OOJSValueFromBOOL([[OOJavaScriptEngine sharedEngine] dumpStackForErrors]);
			break;
			
		case kConsole_dumpStackForWarnings:
			*value = OOJSValueFromBOOL([[OOJavaScriptEngine sharedEngine] dumpStackForWarnings]);
			break;
			
		case kConsole_glVendorString:
			*value = OOJSValueFromNativeObject(context, oo::NSStringOrNil([[OOOpenGLExtensionManager sharedManager] vendorString]));
			break;
			
		case kConsole_glRendererString:
			*value = OOJSValueFromNativeObject(context, oo::NSStringOrNil([[OOOpenGLExtensionManager sharedManager] rendererString]));
			break;
			
		case kConsole_glFixedFunctionTextureUnitCount:
			*value = ooscript::int32Value([[OOOpenGLExtensionManager sharedManager] textureUnitCount]);
			break;
			
		case kConsole_glFragmentShaderTextureUnitCount:
			*value = ooscript::int32Value([[OOOpenGLExtensionManager sharedManager] textureImageUnitCount]);
			break;
			
#define DEBUG_FLAG_CASE(x) case kConsole_##x: *value = ooscript::int32Value(x); break;
		DEBUG_FLAG_CASE(DEBUG_LINKED_LISTS);
		DEBUG_FLAG_CASE(DEBUG_COLLISIONS);
		DEBUG_FLAG_CASE(DEBUG_DOCKING);
		DEBUG_FLAG_CASE(DEBUG_OCTREE_LOGGING);
		DEBUG_FLAG_CASE(DEBUG_BOUNDING_BOXES);
		DEBUG_FLAG_CASE(DEBUG_OCTREE_DRAW);
		DEBUG_FLAG_CASE(DEBUG_DRAW_NORMALS);
		DEBUG_FLAG_CASE(DEBUG_NO_DUST);
		DEBUG_FLAG_CASE(DEBUG_NO_SHADER_FALLBACK);
		DEBUG_FLAG_CASE(DEBUG_SHADER_VALIDATION);
		
		DEBUG_FLAG_CASE(DEBUG_MISC);
#undef DEBUG_FLAG_CASE
			
		default:
			OOJSReportBadPropertySelector(context, thisObject, propID, sConsoleProperties);
			return NO;
	}
	
	return YES;
	
	OOJS_NATIVE_EXIT
}


static bool ConsoleSetProperty(ooscript::Context context, ooscript::Object thisObject, ooscript::PropertyId propID, bool strict, ooscript::Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	OOJS_NATIVE_ENTER(context)
	
	int32_t						iValue;
	bool						bValue = NO;
	std::optional<std::string>	sValue;
	
	switch (ooscript::idToInt32(propID))
	{
#ifndef NDEBUG
		case kConsole_debugFlags:
			if (ooscript::valueToInt32(context, *value, &iValue))
			{
				gDebugFlags = iValue;
			}
			break;
#endif		
		case kConsole_detailLevel:
			sValue = oo::OptionalString(OOStringFromJSValue(context, *value));
			OOJS_BEGIN_FULL_NATIVE(context)
			[UNIVERSE setDetailLevel:OOGraphicsDetailFromString(oo::NSStringOrNil(sValue))];
			OOJS_END_FULL_NATIVE
			break;
			
		case kConsole_displayFPS:
			if (ooscript::valueToBoolean(context, *value, &bValue))
			{
				[UNIVERSE setDisplayFPS:bValue];
			}
			break;
			
		case kConsole_pedanticMode:
			if (ooscript::valueToBoolean(context, *value, &bValue))
			{
				uint32_t options = static_cast<uint32_t>(ooscript::getOptions(context));
				if (bValue)  options |= static_cast<uint32_t>(ooscript::ContextOption::Strict);
				else  options &= ~static_cast<uint32_t>(ooscript::ContextOption::Strict);
				
				ooscript::setOptions(context, static_cast<ooscript::ContextOption>(options));
			}
			break;
			
		case kConsole_ignoreDroppedPackets:
			if (ooscript::valueToBoolean(context, *value, &bValue))
			{
				[[OODebugMonitor sharedDebugMonitor] setTCPIgnoresDroppedPackets:bValue];
			}
			break;
			
		case kConsole_showErrorLocations:
			if (ooscript::valueToBoolean(context, *value, &bValue))
			{
				[[OOJavaScriptEngine sharedEngine] setShowErrorLocations:bValue];
			}
			break;
			
		case kConsole_dumpStackForErrors:
			if (ooscript::valueToBoolean(context, *value, &bValue))
			{
				[[OOJavaScriptEngine sharedEngine] setDumpStackForErrors:bValue];
			}
			break;
			
		case kConsole_dumpStackForWarnings:
			if (ooscript::valueToBoolean(context, *value, &bValue))
			{
				[[OOJavaScriptEngine sharedEngine] setDumpStackForWarnings:bValue];
			}
			break;
			
		default:
			OOJSReportBadPropertySelector(context, thisObject, propID, sConsoleProperties);
			return NO;
	}
	
	return YES;
	
	OOJS_NATIVE_EXIT
}


static BOOL DoWeDefineAllDebugFlags(enum OODebugFlags flags)  GCC_ATTR((unused));
static BOOL DoWeDefineAllDebugFlags(enum OODebugFlags flags)
{
	/*	This function doesn't do anything, but will generate a warning
		(Enumeration value 'DEBUG_FOO' not handled in switch) if a debug flag
		is added without updating it. The point is that if you get such a
		warning, you should first add a JS symbolic constant for the flag,
		then add it to the switch to suppress the warning.
		NOTE: don't add a default: to this switch, or I will have to hurt you.
		-- Ahruman 2010-04-11
	*/
	switch (flags)
	{
		case DEBUG_LINKED_LISTS:
		case DEBUG_COLLISIONS:
		case DEBUG_DOCKING:
		case DEBUG_OCTREE_LOGGING:
		case DEBUG_BOUNDING_BOXES:
		case DEBUG_OCTREE_DRAW:
		case DEBUG_DRAW_NORMALS:
		case DEBUG_NO_DUST:
		case DEBUG_NO_SHADER_FALLBACK:
		case DEBUG_SHADER_VALIDATION:
		case DEBUG_MISC:
			return YES;
	}
	
	return NO;
}


static void ConsoleFinalize(ooscript::Context context, ooscript::Object thisObject)
{
	OOJS_PROFILE_ENTER
	
	[(id)ooscript::getPrivate(context, thisObject) release];
	ooscript::setPrivate(context, thisObject, nil);
	
	OOJS_PROFILE_EXIT_VOID
}


static bool ConsoleSettingsDeleteProperty(ooscript::Context context, ooscript::Object thisObject, ooscript::PropertyId propID, ooscript::Value *value)
{
	OOJS_NATIVE_ENTER(context)
	
	std::optional<std::string>	key;
	id					monitor = nil;

	if (!ooscript::isStringId(propID))  return NO;
	key = oo::OptionalString(OOStringFromJSString(context, ooscript::idToString(propID)));
	
	monitor = OOJSNativeObjectFromJSObject(context, thisObject);
	if (![monitor isKindOfClass:[OODebugMonitor class]])
	{
		OOJSReportError(context, @"Expected OODebugMonitor, got %@ in %s. %@", [monitor class], __PRETTY_FUNCTION__, @"This is an internal error, please report it.");
		return NO;
	}
	
	[monitor setConfigurationValue:nil forKey:oo::NSStringOrNil(key)];
	*value = ooscript::trueValue();
	return YES;
	
	OOJS_NATIVE_EXIT
}


static bool ConsoleSettingsGetProperty(ooscript::Context context, ooscript::Object thisObject, ooscript::PropertyId propID, ooscript::Value *value)
{
	if (!ooscript::isStringId(propID))  return YES;
	
	OOJS_NATIVE_ENTER(context)
	
	std::optional<std::string>	key;
	id					settingValue = nil;
	id					monitor = nil;

	key = oo::OptionalString(OOStringFromJSString(context, ooscript::idToString(propID)));

	monitor = OOJSNativeObjectFromJSObject(context, thisObject);
	if (![monitor isKindOfClass:[OODebugMonitor class]])
	{
		OOJSReportError(context, @"Expected OODebugMonitor, got %@ in %s. %@", [monitor class], __PRETTY_FUNCTION__, @"This is an internal error, please report it.");
		return NO;
	}

	settingValue = [monitor configurationValueForKey:oo::NSStringOrNil(key)];
	if (settingValue != NULL)  *value = [settingValue oo_jsValueInContext:context];
	else  *value = ooscript::undefinedValue();
	
	return YES;
	
	OOJS_NATIVE_EXIT
}


static bool ConsoleSettingsSetProperty(ooscript::Context context, ooscript::Object thisObject, ooscript::PropertyId propID, bool strict, ooscript::Value *value)
{
	if (!ooscript::isStringId(propID))  return YES;
	
	OOJS_NATIVE_ENTER(context)
	
	std::optional<std::string>	key;
	id					settingValue = nil;
	id					monitor = nil;

	key = oo::OptionalString(OOStringFromJSString(context, ooscript::idToString(propID)));

	monitor = OOJSNativeObjectFromJSObject(context, thisObject);
	if (![monitor isKindOfClass:[OODebugMonitor class]])
	{
		OOJSReportError(context, @"Expected OODebugMonitor, got %@ in %s. %@", [monitor class], __PRETTY_FUNCTION__, @"This is an internal error, please report it.");
		return NO;
	}

	// Not OOJS_BEGIN_FULL_NATIVE() - we use JSAPI while paused.
	OOJSPauseTimeLimiter();
	if (ooscript::isNull(*value) || ooscript::isUndefined(*value))
	{
		[monitor setConfigurationValue:nil forKey:oo::NSStringOrNil(key)];
	}
	else
	{
		settingValue = OOJSNativeObjectFromJSValue(context, *value);
		if (settingValue != nil)
		{
			[monitor setConfigurationValue:settingValue forKey:oo::NSStringOrNil(key)];
		}
		else
		{
			OOJSReportWarning(context, @"debugConsole.settings: could not convert %@ to native object.", OOStringFromJSValue(context, *value));
		}
	}
	OOJSResumeTimeLimiter();
	
	return YES;
	
	OOJS_NATIVE_EXIT
}


// *** Methods ***

// function consoleMessage(colorCode : String, message : String [, emphasisStart : Number, emphasisLength : Number]) : void
static bool ConsoleConsoleMessage(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	NSRange				emphasisRange = {0, 0};
	
	OOJS_NATIVE_ENTER(context)
	
	id					monitor = nil;
	std::optional<std::string>	colorKey,
								message;
	double			location, length;
	
	// Not OOJS_BEGIN_FULL_NATIVE() - we use JSAPI while paused.
	OOJSPauseTimeLimiter();
	monitor = OOJSNativeObjectOfClassFromJSObject(context, OOJS_THIS, [OODebugMonitor class]);
	if (monitor == nil)
	{
		OOJSReportError(context, @"Expected OODebugMonitor, got %@ in %s. %@", [monitor class], __PRETTY_FUNCTION__, @"This is an internal error, please report it.");
		OOJSResumeTimeLimiter();
		return NO;
	}
	
	if (oojsArgs.count() > 0) colorKey = oo::OptionalString(OOStringFromJSValue(context,OOJS_ARGV[0]));
	if (oojsArgs.count() > 1) message = oo::OptionalString(OOStringFromJSValue(context,OOJS_ARGV[1]));
	
	if (oojsArgs.count() > 3)
	{
		// Attempt to get two numbers, specifying an emphasis range.
		if (ooscript::valueToNumber(context, OOJS_ARGV[2], &location) &&
			ooscript::valueToNumber(context, OOJS_ARGV[3], &length))
		{
			emphasisRange = (NSRange){(NSUInteger)location, (NSUInteger)length};
		}
	}
	
	if (!message.has_value())
	{
		if (!colorKey.has_value())
		{
			OOJSReportWarning(context, @"Console.consoleMessage() called with no parameters.");
		}
		else
		{
			message = colorKey;
			colorKey = "command-result";
		}
	}
	
	if (message.has_value())
	{
		[monitor appendJSConsoleLine:oo::NSStringFrom(*message)
							colorKey:oo::NSStringOrNil(colorKey)
					   emphasisRange:emphasisRange];
	}
	OOJSResumeTimeLimiter();
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}


// function clearConsole() : void
static bool ConsoleClearConsole(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	id					monitor = nil;
	
	monitor = OOJSNativeObjectFromJSObject(context, OOJS_THIS);
	if (![monitor isKindOfClass:[OODebugMonitor class]])
	{
		OOJSReportError(context, @"Expected OODebugMonitor, got %@ in %s. %@", [monitor class], __PRETTY_FUNCTION__, @"This is an internal error, please report it.");
		return NO;
	}
	
	[monitor clearJSConsole];
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}


// function scriptStack() : Array
static bool ConsoleScriptStack(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	OOJS_RETURN_OBJECT([OOJSScript scriptStack]);
	
	OOJS_NATIVE_EXIT
}


// function inspectEntity(entity : Entity) : void
static bool ConsoleInspectEntity(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	Entity				*entity = nil;
	
	if (JSValueToEntity(context, OOJS_ARGV[0], &entity))
	{
		OOJS_BEGIN_FULL_NATIVE(context)
		if ([entity respondsToSelector:@selector(inspect)])
		{
			[entity inspect];
		}
		OOJS_END_FULL_NATIVE
	}
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}


#if OO_DEBUG
// function callObjC(selector : String [, ...]) : Object
static bool ConsoleCallObjCMethod(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	id						object = nil;
	ooscript::Value					result;
	BOOL					OK;
	
	object = OOJSNativeObjectFromJSObject(context, OOJS_THIS);
	if (object == nil)
	{
		OOJSReportError(context, @"Attempt to call __callObjCMethod() for non-Objective-C object %@.", OOStringFromJSValueEvenIfNull(context, ooscript::objectValue(OOJS_THIS)));
		return NO;
	}
	
	OOJSPauseTimeLimiter();
	result = ooscript::undefinedValue();
	OK = OOJSCallObjCObjectMethod(context, object, oo::StdString([object oo_jsClassName]), oojsArgs.count(), OOJS_ARGV, &result);
	OOJSResumeTimeLimiter();
	
	OOJS_SET_RVAL(result);
	return OK;
	
	OOJS_NATIVE_EXIT
}


// function __setUpCallObjC(object) -- object is expected to be Object.prototye.
static bool ConsoleSetUpCallObjC(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(!ooscript::isObjectOrNull(OOJS_ARGV[0])))
	{
		OOJSReportBadArguments(context, @"Console", @"__setUpCallObjC", oojsArgs.count(), OOJS_ARGV, nil, @"Object.prototype");
		return NO;
	}
	
	ooscript::Object obj = ooscript::toObject(OOJS_ARGV[0]);
	ooscript::defineFunction(context, obj, "callObjC", ConsoleCallObjCMethod, 1, OOJS_METHOD_READONLY);
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
#endif


// function isExecutableJavaScript(this : Object, string : String) : Boolean
static bool ConsoleIsExecutableJavaScript(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	BOOL					result = NO;
	ooscript::Object target = NULL;
	
	if (oojsArgs.count() < 2 || !ooscript::valueToObject(context, OOJS_ARGV[0], &target) || !ooscript::isString(OOJS_ARGV[1]))
	{
		OOJS_RETURN_BOOL(NO);	// Fail silently
	}
	
	// Not OOJS_BEGIN_FULL_NATIVE() - we use JSAPI while paused.
	OOJSPauseTimeLimiter();
	
	// FIXME: this must be possible using just JSAPI functions.
	const std::string string = oo::StdString(OOStringFromJSValue(context, OOJS_ARGV[1]));	// its UTF-8 bytes
	result = ooscript::bufferIsCompilableUnit(context, target, string.data(), string.size());
	
	OOJSResumeTimeLimiter();
	
	OOJS_RETURN_BOOL(result);
	
	OOJS_NATIVE_EXIT
}


// function displayMessagesInClass(class : String) : Boolean
static bool ConsoleDisplayMessagesInClass(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	std::optional<std::string>	messageClass;

	messageClass = oo::OptionalString(OOStringFromJSValue(context, OOJS_ARGV[0]));
	OOJS_RETURN_BOOL(messageClass.has_value() && OOLogWillDisplayMessagesInClass(oo::NSStringFrom(*messageClass)));
	
	OOJS_NATIVE_EXIT
}


// function setDisplayMessagesInClass(class : String, flag : Boolean) : void
static bool ConsoleSetDisplayMessagesInClass(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	std::optional<std::string>	messageClass;
	bool					flag;

	messageClass = oo::OptionalString(OOStringFromJSValue(context, OOJS_ARGV[0]));
	if (messageClass.has_value() && ooscript::valueToBoolean(context, OOJS_ARGV[1], &flag))
	{
		OOLogSetDisplayMessagesInClass(oo::NSStringFrom(*messageClass), flag);
	}
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}


// function writeLogMarker() : void
static bool ConsoleWriteLogMarker(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	OOLogInsertMarker();
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}


// function writeMemoryStats() : void
static bool ConsoleWriteMemoryStats(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	OOJS_BEGIN_FULL_NATIVE(context)
	[[OODebugMonitor sharedDebugMonitor] dumpMemoryStatistics];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}


// function writeJSMemoryStats() : void
static bool ConsoleWriteJSMemoryStats(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	OOJS_BEGIN_FULL_NATIVE(context)
	[[OODebugMonitor sharedDebugMonitor] dumpJSMemoryStatistics];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}


// function garbageCollect() : string
static bool ConsoleGarbageCollect(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	uint32_t bytesBefore = ooscript::getGCParameter(ooscript::getRuntime(context), ooscript::GCParam::Bytes);
	ooscript::gc(context);
	uint32_t bytesAfter = ooscript::getGCParameter(ooscript::getRuntime(context), ooscript::GCParam::Bytes);
	
	OOJS_RETURN_OBJECT((oo::NSStringFrom(oo::str::format("Bytes before: %u Bytes after: %u", bytesBefore, bytesAfter))));
	
	OOJS_NATIVE_EXIT
}


#if DEBUG
typedef struct
{
	ooscript::Context context;
	FILE			*file;
} DumpCallbackData;

static void DumpCallback(const char *name, void *rp, ooscript::RootKind type, void *datap)
{
	assert(type == ooscript::RootKind::Value || type == ooscript::RootKind::GCThing);
	
	DumpCallbackData *data = static_cast<DumpCallbackData *>(datap);
	
	const char *typeString = "unknown type";
	ooscript::Value value;
	switch (type)
	{
		case ooscript::RootKind::Value:
			typeString = "value";
			value = *(ooscript::Value *)rp;
			break;
			
		case ooscript::RootKind::GCThing:
			typeString = "gc-thing";
			value = ooscript::objectValue(*(ooscript::Object *)rp);
	}
	
	fprintf(data->file, "%s @ %p (%s): %s\n", name, rp, typeString, [OOJSDescribeValue(data->context, value, NO) UTF8String]);
}


static bool ConsoleDumpNamedRoots(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	BOOL OK = NO;
	@autoreleasepool
	{
		const std::string path = oo::StdString([[ResourceManager diagnosticFileLocation] stringByAppendingPathComponent:@"js-roots.txt"]);
		FILE *file = fopen(path.c_str(), "w");
		if (file != NULL)
		{
			DumpCallbackData data =
			{
				.context = context,
				.file = file
			};
			ooscript::dumpNamedRoots(ooscript::getRuntime(context), DumpCallback, &data);
			fclose(file);
			OK = YES;
		}
	}
	
	OOJS_RETURN_BOOL(OK);
	
	OOJS_NATIVE_EXIT
}


static bool ConsoleDumpHeap(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	BOOL OK = NO;
	const std::string path = oo::StdString([[ResourceManager diagnosticFileLocation] stringByAppendingPathComponent:@"js-heaps.txt"]);
	FILE *file = fopen(path.c_str(), "w");
	if (file != NULL)
	{
		OK = ooscript::dumpHeap(context, file);
		fclose(file);
	}
	
	OOJS_RETURN_BOOL(OK);
	
	OOJS_NATIVE_EXIT
}
#endif


#if OOJS_PROFILE

// function profile(func : function [, Object this = debugConsole.script]) : String
static bool ConsoleProfile(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(OOJSIsProfiling()))
	{
		OOJSReportError(context, @"Profiling functions may not be called while already profiling.");
		return NO;
	}
	
	bool result;
	@autoreleasepool
	{
		OOTimeProfile		*profile = nil;
		
		result = PerformProfiling(context, "profile", oojsArgs.count(), OOJS_ARGV, NULL, NO, &profile);
		if (result)
		{
			OOJS_SET_RVAL(OOJSValueFromNativeObject(context, [profile description]));
		}
	}
	
	return result;
	
	OOJS_NATIVE_EXIT
}


// function getProfile(func : function [, Object this = debugConsole.script]) : Object { totalTime : Number, jsTime : Number, extensionTime : Number }
static bool ConsoleGetProfile(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	
	if (EXPECT_NOT(OOJSIsProfiling()))
	{
		OOJSReportError(context, @"Profiling functions may not be called while already profiling.");
		return NO;
	}
	
	bool result;
	@autoreleasepool
	{
		OOTimeProfile		*profile = nil;
		
		result = PerformProfiling(context, "getProfile", oojsArgs.count(), OOJS_ARGV, NULL, NO, &profile);
		if (result)
		{
			OOJS_SET_RVAL(OOJSValueFromNativeObject(context, profile));
		}
	}
	
	return result;
	
	OOJS_NATIVE_EXIT
}


// function trace(func : function [, Object this = debugConsole.script]) : [return type of func]
static bool ConsoleTrace(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(OOJSIsProfiling()))
	{
		OOJSReportError(context, @"Profiling functions may not be called while already profiling.");
		return NO;
	}
	
	ooscript::Value				rval;
	bool result;
	@autoreleasepool
	{
		result = PerformProfiling(context, "trace", oojsArgs.count(), OOJS_ARGV, &rval, YES, NULL);
		if (result)
		{
			OOJS_SET_RVAL(rval);
		}
	}
	
	return result;
	
	OOJS_NATIVE_EXIT
}


namespace {

bool PerformProfiling(ooscript::Context context, const char *nominalFunction, unsigned argc, ooscript::Value *argv, ooscript::Value *outRval, BOOL trace, OOTimeProfile **outProfile)
{
	// Get function.
	ooscript::Value function = argv[0];
	if (!OOJSValueIsFunction(context, function))
	{
		OOJSReportBadArguments(context, @"Console", oo::NSStringFrom(nominalFunction), 1, argv, nil, @"function");
		return NO;
	}
	
	// Get "this" object.
	ooscript::Value thisVal;
	if (argc > 1)  thisVal = argv[1];
	else
	{
		ooscript::Value debugConsole = OOJSValueFromNativeObject(context, [OODebugMonitor sharedDebugMonitor]);
		assert(ooscript::isObjectOrNull(debugConsole) && !ooscript::isNull(debugConsole));
		ooscript::getProperty(context, ooscript::toObject(debugConsole), "script", &thisVal);
	}
	
	ooscript::Object thisObj;
	if (!ooscript::valueToObject(context, thisVal, &thisObj))  thisObj = NULL;
	
	ooscript::Value ignored;
	if (outRval == NULL)  outRval = &ignored;
	
	// Fiddle with time limiter.
	// We want to save the current limit, reset the limiter, and set the time limit to a long time.
#define LONG_TIME (1e7)	// A long time - 115.7 days - but, crucially, finite.
	
	OOTimeDelta originalLimit = OOJSGetTimeLimiterLimit();
	OOJSSetTimeLimiterLimit(LONG_TIME);
	OOJSResetTimeLimiter();
	
	OOJSBeginProfiling(trace);
	
	// Call the function.
	BOOL result = ooscript::callFunctionValue(context, thisObj, function, 0, NULL, outRval);
	
	// Get results.
	OOTimeProfile *profile = OOJSEndProfiling();
	if (outProfile != NULL)  *outProfile = profile;
	
	// Restore original timer state.
	OOJSSetTimeLimiterLimit(originalLimit);
	OOJSResetTimeLimiter();
	
	ooscript::reportPendingException(context);
	
	return result;
}

}	// namespace

#endif // OOJS_PROFILE

#endif /* NDEBUG */
