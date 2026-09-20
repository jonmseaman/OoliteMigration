/*

OOJSGlobal.m


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

#import "OOJSGlobal.h"
#import "OOJavaScriptEngine.h"

#import "OOJSPlayer.h"
#import "PlayerEntityScriptMethods.h"
#import "OOStringExpander.h"
#import "OOConstToString.h"
#import "OOConstToJSString.h"
#import "OOCollectionExtractors.h"
#import "OOTexture.h"
#import "GuiDisplayGen.h"
#import "MyOpenGLView.h"
#import "ResourceManager.h"
#import "OOSystemDescriptionManager.h"
#import "NSFileManagerOOExtensions.h"
#import "OOJSGuiScreenKeyDefinition.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) per bead oo-8yi, the same way bead oo-sdz
	retargeted OOJSVector.mm (the exemplar for this sweep; see its header comment for the full
	rationale). This file's directly-spelled engine calls -- the JSClass hook-stub family
	(PropertyStub/EnumerateStub/ResolveStub/ConvertStub), NewNumberValue, ValueToNumber,
	ValueToBoolean, ValueToObject, GetProperty, DefineProperty, DefineProperties,
	DefineFunctions, NewCompartmentAndGlobalObject and SetGlobalObject -- become their
	ooscript:: façade equivalents per ooscript/README.md's retarget map; the OOJS_*
	argument-marshalling macros (OOJS_ARGV, OOJS_THIS, OOJS_NATIVE_ENTER/EXIT, OOJS_RETURN_*)
	are OOJS_*-spelled, not themselves the engine's own prefix at these call sites, and stay
	exactly as before, out of scope for the sweep.

	SetGlobalObject had no façade equivalent yet; ooscript::setGlobalObject is added to
	JSEngine.hpp/JSEngine_spidermonkey.cpp by this bead following the existing
	newGlobalObject/getGlobalObject pattern (the engine's SetGlobalObject entry point's only call site in the tree).

	Retargeting DefineProperties/DefineFunctions requires sGlobalProperties/sGlobalMethods to
	become ooscript::PropertySpec/FunctionSpec tables (the façade's DefineProperties and
	DefineFunctions take those, not the engine's JSPropertySpec / JSFunctionSpec pointers),
	every JS global method to take the façade's NativeFn hook signature
	(Context, CallArgs&) rather than the engine's (JSContext *, uintN argc, jsval *vp). A small
	shim at the top of each recovers the old JSContext *, uintN, and jsval * locals so the
	OOJS_* argument-marshalling macros and the rest of each body are UNCHANGED, exactly as
	OOJSVector.mm's own retarget does it. GlobalGetProperty/GlobalSetProperty take the façade's
	PropertyGetter/PropertySetter hook signature for the same reason (they are wired into
	sGlobalClass, now a ClassDef). `this` is renamed to `thisObj` because it is a reserved word
	once this file compiles as Objective-C++ (ADR-0001).
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
static inline jsval     *OOJSRVAL(Value *v)       { return reinterpret_cast<jsval*>(v); }
} // namespace
namespace {
static inline Value     *OOJSFVALP(jsval *v)      { return reinterpret_cast<Value*>(v); }
} // namespace
namespace {
static inline Value      OOJSFVAL(jsval v)        { Value r; std::memcpy(&r, &v, sizeof r); return r; }
} // namespace
namespace {
static inline jsid       OOJSRJSID(PropertyId id) { jsid r; std::memcpy(&r, &id, sizeof r); return r; }
} // namespace


#if OOJSENGINE_MONITOR_SUPPORT

@interface OOJavaScriptEngine (OOMonitorSupportInternal)

- (void)sendMonitorLogMessage:(NSString *)message
			 withMessageClass:(NSString *)messageClass
					inContext:(JSContext *)context;

@end

#endif


static NSString * const kOOLogDebugMessage = @"script.debug.message";


namespace {
static bool GlobalGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
#ifndef NDEBUG
namespace {
static bool GlobalSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace
#endif

namespace {
static bool GlobalLog(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalExpandDescription(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalKeyBindingDescription(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalExpandMissionText(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalDisplayNameForCommodity(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalRandomName(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalRandomInhabitantsDescription(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalSetScreenBackground(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalSetScreenOverlay(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalGetScreenBackgroundForKey(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalSetScreenBackgroundForKey(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalAutoAIForRole(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalPauseGame(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalQuitGame(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalGetGuiColorSettingForKey(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalSetGuiColorSettingForKey(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalSetExtraGuiScreenKeys(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalClearExtraGuiScreenKeys(Context cx, CallArgs &oojsArgs);
} // namespace

#ifndef NDEBUG
namespace {
static bool GlobalTakeSnapShot(Context cx, CallArgs &oojsArgs);
} // namespace
#endif


namespace {
static ClassDef sGlobalClass =
{
	"Global",
	ClassFlag::Global,

	nullptr,			// addProperty (engine default: PropertyStub)
	nullptr,			// delProperty (engine default: PropertyStub)
	GlobalGetProperty,	// getProperty
#ifndef NDEBUG
	GlobalSetProperty,	// setProperty
#else
	// No writeable properties in non-debug builds
	nullptr,			// setProperty (engine default: StrictPropertyStub)
#endif
	nullptr,			// enumerate (engine default: EnumerateStub)
	nullptr,			// newEnumerate (JSCLASS_NEW_ENUMERATE not used)
	nullptr,			// resolve (engine default: ResolveStub)
	nullptr,			// convert (engine default: ConvertStub)
	nullptr,			// finalize (engine default: FinalizeStub)
	nullptr,			// call
	nullptr,			// construct
	nullptr,			// backend: owned by the façade backend, must start null
};
} // namespace


enum : std::int8_t
{
	// Property IDs
	kGlobal_galaxyNumber,		// galaxy number, integer, read-only
	kGlobal_global,				// global.global.global.global, integer, read-only
	kGlobal_guiScreen,			// current GUI screen, string, read-only
#ifndef NDEBUG
	kGlobal_timeAccelerationFactor	// time acceleration, float, read/write
#endif
};


namespace {
static constexpr PropertyFlag kGlobalROPropFlags  = PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared;
#ifndef NDEBUG
static constexpr PropertyFlag kGlobalRWPropFlags  = PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared;
#endif
static PropertySpec sGlobalProperties[] =
{
	// JS name					ID							flags									getter	setter
	{ "galaxyNumber",			kGlobal_galaxyNumber,		kGlobalROPropFlags,	nullptr, nullptr },
	{ "guiScreen",				kGlobal_guiScreen,			kGlobalROPropFlags,	nullptr, nullptr },
#ifndef NDEBUG
	{ "timeAccelerationFactor",	kGlobal_timeAccelerationFactor,	kGlobalRWPropFlags,	nullptr, nullptr },
#endif
	{ 0 }
};
} // namespace


// A raw jsapi mirror of sGlobalProperties, used only for the two bad-property error reporters
// in OOJavaScriptEngine.m (OOJSReportBadPropertySelector/Value): those helpers are outside this
// bead's scope (they are shared across every binding file) and still take a JSPropertySpec*,
// not ooscript::PropertySpec*, the same as OOJSVector.mm's sVectorPropertiesRaw.
namespace {
static JSPropertySpec sGlobalPropertiesRaw[] =
{
	// JS name					ID							flags
	{ "galaxyNumber",			kGlobal_galaxyNumber,		OOJS_PROP_READONLY_CB },
	{ "guiScreen",				kGlobal_guiScreen,			OOJS_PROP_READONLY_CB },
#ifndef NDEBUG
	{ "timeAccelerationFactor",	kGlobal_timeAccelerationFactor,	OOJS_PROP_READWRITE_CB },
#endif
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sGlobalMethods[] =
{
	// JS name								Function								min args	flags
	{ "log",								GlobalLog,							1,			0 },
	{ "autoAIForRole",						GlobalAutoAIForRole,				1,			0 },
	{ "expandDescription",					GlobalExpandDescription,			1,			0 },
	{ "expandMissionText",					GlobalExpandMissionText,			1,			0 },
	{ "displayNameForCommodity",			GlobalDisplayNameForCommodity,		1,			0 },
	{ "randomName",							GlobalRandomName,					0,			0 },
	{ "randomInhabitantsDescription",		GlobalRandomInhabitantsDescription,	1,			0 },
	{ "setScreenBackground",				GlobalSetScreenBackground,			1,			0 },
	{ "getScreenBackgroundForKey",      GlobalGetScreenBackgroundForKey,    1,			0 },
	{ "setScreenBackgroundForKey",      GlobalSetScreenBackgroundForKey,    2,			0 },
	{ "setScreenOverlay",					GlobalSetScreenOverlay,				1,			0 },
	{ "getGuiColorSettingForKey",       GlobalGetGuiColorSettingForKey,     1,			0 },
	{ "setGuiColorSettingForKey",       GlobalSetGuiColorSettingForKey,     2,			0 },
	{ "keyBindingDescription",       	GlobalKeyBindingDescription,		1,			0 },
	{ "setExtraGuiScreenKeys",			GlobalSetExtraGuiScreenKeys,		2,			0 },
	{ "clearExtraGuiScreenKeys",		GlobalClearExtraGuiScreenKeys,		2,			0 },

#ifndef NDEBUG
	{ "takeSnapShot",					GlobalTakeSnapShot,					1,			0 },
	{ "quitGame",						GlobalQuitGame,						0,			0 },
#endif
	{ "pauseGame",						GlobalPauseGame,					0,			0 },
	{ 0 }
};
} // namespace


namespace {
static constexpr PropertyFlag kGlobalSelfPropertyFlags = PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly;
} // namespace


void CreateOOJSGlobal(JSContext *context, JSObject **outGlobal)
{
	assert(outGlobal != NULL);
	
	Context cx = OOJSFCX(context);
	Object global = ooscript::newGlobalObject(cx, &sGlobalClass);
	*outGlobal = OOJSROBJ(global);
	
	ooscript::setGlobalObject(cx, global);
	ooscript::defineProperty(cx, global, "global", ooscript::objectValue(global), nullptr, nullptr,
							  kGlobalSelfPropertyFlags);
}


void SetUpOOJSGlobal(JSContext *context, JSObject *global)
{
	Context cx = OOJSFCX(context);
	Object obj = OOJSFOBJ(global);
	ooscript::defineProperties(cx, obj, sGlobalProperties);
	ooscript::defineFunctions(cx, obj, sGlobalMethods);
}


namespace {
static bool GlobalGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity				*player = OOPlayerForScripting();
	
	switch (ooscript::idToInt32(propID))
	{
		case kGlobal_galaxyNumber:
			*value = ooscript::int32Value([player currentGalaxyID]);
			return YES;
			
		case kGlobal_guiScreen:
			*value = OOJSFVAL(OOJSValueFromGUIScreenID(context, [player guiScreen]));
			return YES;
			
#ifndef NDEBUG
		case kGlobal_timeAccelerationFactor:
			return ooscript::newNumberValue(cx, [UNIVERSE timeAccelerationFactor], value);
#endif
			
		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sGlobalPropertiesRaw);
			return NO;
	}
	
	OOJS_NATIVE_EXIT
}
} // namespace


#ifndef NDEBUG
namespace {
static bool GlobalSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	
	OOJS_NATIVE_ENTER(context)
	
	jsdouble					fValue;
	
	switch (ooscript::idToInt32(propID))
	{
		case kGlobal_timeAccelerationFactor:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				[UNIVERSE setTimeAccelerationFactor:fValue];
				return YES;
			}
			break;
	
		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sGlobalPropertiesRaw);
	}
	
	OOJSReportBadPropertyValue(context, thisObj, OOJSRJSID(propID), sGlobalPropertiesRaw, *OOJSRVAL(value));
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace
#endif


// *** Methods ***

// log([messageClass : String,] message : string, ...)
namespace {
static bool GlobalLog(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	NSString			*message = nil;
	NSString			*messageClass = nil;
	
	if (EXPECT_NOT(argc < 1))
	{
		OOJS_RETURN_VOID;
	}
	if (argc < 2)
	{
		messageClass = kOOLogDebugMessage;
		message = OOStringFromJSValue(context, OOJS_ARGV[0]);
	}
	else
	{
		messageClass = OOStringFromJSValueEvenIfNull(context, OOJS_ARGV[0]);
		if (!OOLogWillDisplayMessagesInClass(messageClass))
		{
			// Do nothing (and short-circuit) if message class is filtered out.
			OOJS_RETURN_VOID;
		}
		
		message = [NSString concatenationOfStringsFromJavaScriptValues:OOJS_ARGV + 1 count:argc - 1 separator:@", " inContext:context];
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	OOLog(messageClass, @"%@", message);
	
#if OOJSENGINE_MONITOR_SUPPORT
	[[OOJavaScriptEngine sharedEngine] sendMonitorLogMessage:message
											withMessageClass:nil
												   inContext:context];
#endif
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// expandDescription(description : String [, overrides : object (dictionary)]) : String
namespace {
static bool GlobalExpandDescription(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	NSString			*string = nil;
	NSDictionary		*overrides = nil;
	
	if (argc > 0)  string = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (string == nil)
	{
		OOJSReportBadArguments(context, nil, @"expandDescription", MIN(argc, 1U), OOJS_ARGV, nil, @"string");
		return NO;
	}
	if (argc > 1)
	{
		overrides = OOJSDictionaryFromStringTable(context, OOJS_ARGV[1]);
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	string = OOExpandDescriptionString(kNilRandomSeed, string, overrides, nil, nil, kOOExpandForJavaScript | kOOExpandGoodRNG);
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_OBJECT(string);
	
	OOJS_NATIVE_EXIT
}
} // namespace

namespace {
static bool GlobalKeyBindingDescription(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	NSString			*string = nil;
	PlayerEntity				*player = OOPlayerForScripting();
	
	if (argc > 0)  string = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (string == nil)
	{
		OOJSReportBadArguments(context, nil, @"keyBindingDescription", MIN(argc, 1U), OOJS_ARGV, nil, @"string");
		return NO;
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	string = [player keyBindingDescription2:string];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_OBJECT(string);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// expandMissionText(textKey : String [, overrides : object (dictionary)]) : String
namespace {
static bool GlobalExpandMissionText(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	NSString			*string = nil;
	NSDictionary		*overrides = nil;
	
	if (argc > 0)  string = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (string == nil)
	{
		OOJSReportBadArguments(context, nil, @"expandMissionText", MIN(argc, 1U), OOJS_ARGV, nil, @"string");
		return NO;
	}
	if (argc > 1)
	{
		overrides = OOJSDictionaryFromStringTable(context, OOJS_ARGV[1]);
	}
	
	string = [[UNIVERSE missiontext] oo_stringForKey:string];
	string = OOExpandDescriptionString(kNilRandomSeed, string, overrides, nil, nil, kOOExpandForJavaScript | kOOExpandBackslashN | kOOExpandGoodRNG);
	
	OOJS_RETURN_OBJECT(string);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// displayNameForCommodity(commodityName : String) : String
namespace {
static bool GlobalDisplayNameForCommodity(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	NSString			*string = nil;
	
	if (argc > 0)  string = OOStringFromJSValue(context,OOJS_ARGV[0]);
	if (string == nil)
	{
		OOJSReportBadArguments(context, nil, @"displayNameForCommodity", MIN(argc, 1U), OOJS_ARGV, nil, @"string");
		return NO;
	}
	OOJS_RETURN_OBJECT(CommodityDisplayNameForSymbolicName(string));
	
	OOJS_NATIVE_EXIT
}
} // namespace


// randomName() : String
namespace {
static bool GlobalRandomName(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	/*	Temporarily set the system generation seed to a "really random" seed,
		so randomName() isn't repeatable.
	*/
	RNG_Seed savedSeed = currentRandomSeed();
	setRandomSeed((RNG_Seed){ (int32_t)Ranrot(), (int32_t)Ranrot(), (int32_t)Ranrot(), (int32_t)Ranrot() });
	
	NSString *result = OOExpand(@"%N");
	
	// Restore seed.
	setRandomSeed(savedSeed);
	
	OOJS_RETURN_OBJECT(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// randomInhabitantsDescription() : String
namespace {
static bool GlobalRandomInhabitantsDescription(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	NSString			*string = nil;
	Random_Seed			aSeed;
	bool				isPlural = true;
	
	if (argc > 0 && !ooscript::valueToBoolean(cx, OOJSFVAL(OOJS_ARGV[0]), &isPlural))
	{
		OOJSReportBadArguments(context, nil, @"randomInhabitantsDescription", 1, OOJS_ARGV, nil, @"boolean");
		return NO;
	}
	
	make_pseudo_random_seed(&aSeed);
	string = [UNIVERSE getSystemInhabitants:Ranrot()%OO_SYSTEMS_PER_GALAXY plural:(isPlural ? YES : NO)];
	OOJS_RETURN_OBJECT(string);
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool GlobalClearExtraGuiScreenKeys(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)

	BOOL				result = NO;
	PlayerEntity		*player = OOPlayerForScripting();

	if (EXPECT_NOT(argc < 2))
	{
		OOJSReportBadArguments(context, nil, @"setExtraGuiScreenKeys", 0, OOJS_ARGV, nil, @"missing arguments");
		return NO;
	}

	NSString *key = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(key == nil || [key isEqualToString:@""]))
	{
		OOJSReportBadArguments(context, nil, @"clearExtraGuiScreenKeys", 1, OOJS_ARGV, nil, @"key");
		return NO;
	}

	OOGUIScreenID gui = OOGUIScreenIDFromJSValue(context, OOJS_ARGV[1]);
	if (!gui)
	{
		OOJSReportBadArguments(context, nil, @"clearExtraGuiScreenKeys", 0, OOJS_ARGV, nil, @"guiScreen invalid entry");
		return NO;
	}

	[player clearExtraGuiScreenKeys:gui key:key];

	result = YES;
	OOJS_RETURN_BOOL(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace

namespace {
static bool GlobalSetExtraGuiScreenKeys(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)

	BOOL				result = NO;
	jsval				callback = JSVAL_NULL;
	JSObject			*callbackThis = NULL;
	jsval				value = JSVAL_NULL;
	NSString			*key = nil;
	OOGUIScreenID 		gui;
	NSDictionary		*keydefs = NULL;
	JSObject			*params = NULL;
	PlayerEntity		*player = OOPlayerForScripting();

	if (EXPECT_NOT(argc < 1))
	{
		OOJSReportBadArguments(context, nil, @"setExtraGuiScreenKeys", 0, OOJS_ARGV, nil, @"key, definition");
		return NO;
	}
	key = OOStringFromJSValue(context, OOJS_ARGV[0]);

	// Validate arguments.
	{
		Object paramsObj = nullptr;
		if (argc < 2 || !ooscript::valueToObject(cx, OOJSFVAL(OOJS_ARGV[1]), &paramsObj))
		{
			OOJSReportBadArguments(context, @"global", @"setExtraGuiScreenKeys", 2, &OOJS_ARGV[1], nil, @"key, definition: definition is not a valid dictionary.");
			return NO;
		}
		params = OOJSROBJ(paramsObj);
	}

	if (!ooscript::getProperty(cx, OOJSFOBJ(params), "guiScreen", OOJSFVALP(&value)) || JSVAL_IS_VOID(value))
	{
		OOJSReportBadArguments(context, @"global", @"setExtraGuiScreenKeys", 2, &OOJS_ARGV[1], nil, @"key, definition: must have a 'guiScreen' property.");
		return NO;
	}

	gui = OOGUIScreenIDFromJSValue(context, value);
	// gui will be 0 for invalid screen id's as well as GUI_SCREEN_MAIN
	if (gui == 0 || gui == GUI_SCREEN_LOAD || gui == GUI_SCREEN_SAVE || gui == GUI_SCREEN_STICKMAPPER || gui == GUI_SCREEN_OXZMANAGER || 
		gui == GUI_SCREEN_NEWGAME || gui == GUI_SCREEN_SAVE_OVERWRITE || gui == GUI_SCREEN_KEYBOARD || gui == GUI_SCREEN_STICKPROFILE || gui == GUI_SCREEN_KEYBOARD_CONFIRMCLEAR ||
		gui == GUI_SCREEN_KEYBOARD_CONFIG || gui == GUI_SCREEN_KEYBOARD_ENTRY || gui == GUI_SCREEN_KEYBOARD_LAYOUT)
	{
		OOJSReportBadArguments(context, @"global", @"setExtraGuiScreenKeys", 2, &OOJS_ARGV[1], nil, @"key, definition: 'guiScreen' property must be a permitted and valid GUI_SCREEN idenfifier.");
		return NO;
	}

	if (!ooscript::getProperty(cx, OOJSFOBJ(params), "registerKeys", OOJSFVALP(&value)) || JSVAL_IS_VOID(value))
	{
		OOJSReportBadArguments(context, @"global", @"setExtraGuiScreenKeys", 2, &OOJS_ARGV[1], nil, @"key, definition: must have a 'registerKeys' property.");
		return NO;
	}
	if (!JSVAL_IS_NULL(value))
	{
		if (JSVAL_IS_OBJECT(value))
		{
			keydefs = OOJSNativeObjectFromJSObject(context, JSVAL_TO_OBJECT(value));
		}
		else 
		{
			OOJSReportBadArguments(context, @"global", @"setExtraGuiScreenKeys", 2, &OOJS_ARGV[1], nil, @"key, definition: registerKeys is not a valid dictionary.");
			return NO;
		}
	}

	if (!ooscript::getProperty(cx, OOJSFOBJ(params), "callback", OOJSFVALP(&callback)) || JSVAL_IS_VOID(callback))
	{
		OOJSReportBadArguments(context, @"global", @"setExtraGuiScreenKeys", 2, &OOJS_ARGV[1], NULL, @"key, definition; must have a 'callback' property.");
		return NO;
	}
	if (!OOJSValueIsFunction(context,callback))
	{
		OOJSReportBadArguments(context, @"global", @"setExtraGuiScreenKeys", 2, &OOJS_ARGV[1], NULL, @"key, definition; 'callback' property must be a function.");
		return NO;
	}

	OOJSGuiScreenKeyDefinition* definition = [[OOJSGuiScreenKeyDefinition alloc] init];
	[definition setName:key];
	[definition setRegisterKeys:keydefs];
	[definition setCallback:callback];

	// get callback 'this'
	if (ooscript::getProperty(cx, OOJSFOBJ(params), "cbThis", OOJSFVALP(&value)) && !JSVAL_IS_VOID(value))
	{
		Object callbackThisObj = nullptr;
		ooscript::valueToObject(cx, OOJSFVAL(value), &callbackThisObj);
		callbackThis = OOJSROBJ(callbackThisObj);
		[definition setCallbackThis:callbackThis];
		// can do .bind(this) for callback instead
	}

	result = [player setExtraGuiScreenKeys:gui definition:definition];
	[definition release];

	OOJS_RETURN_BOOL(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// setScreenBackground(descriptor : guiTextureDescriptor) : Boolean
namespace {
static bool GlobalSetScreenBackground(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	BOOL			result = NO;
	jsval			value = (argc > 0) ? OOJS_ARGV[0] : JSVAL_NULL;
	
	if (EXPECT_NOT(argc == 0))
	{
		OOJSReportWarning(context, @"Usage error: %@() called with no arguments. Treating as %@(null). This call may fail in a future version of Oolite.", @"setScreenBackground", @"setScreenBackground");
	}
	else if (EXPECT_NOT(JSVAL_IS_VOID(value)))
	{
		OOJSReportBadArguments(context, nil, @"setScreenBackground", 1, &value, nil, @"GUI texture descriptor");
		return NO;
	}
	
	if ([UNIVERSE viewDirection] == VIEW_GUI_DISPLAY)
	{
		GuiDisplayGen	*gui = [UNIVERSE gui];
		NSDictionary	*descriptor = [gui textureDescriptorFromJSValue:value inContext:context callerDescription:@"setScreenBackground()"];
		
		result = [gui setBackgroundTextureDescriptor:descriptor];
		
		// add some permanence to the override if we're in the equip ship screen
		if (result && [PLAYER guiScreen] == GUI_SCREEN_EQUIP_SHIP)  [PLAYER setEquipScreenBackgroundDescriptor:descriptor];
	}
	
	OOJS_RETURN_BOOL(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool GlobalGetScreenBackgroundForKey(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(argc == 0))
	{
		OOJSReportBadArguments(context, nil, @"getScreenBackgroundDefault", 0, OOJS_ARGV, nil, @"missing arguments");
		return NO;
	}
	NSString		*key = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(key == nil || [key isEqualToString:@""]))
	{
		OOJSReportBadArguments(context, nil, @"getScreenBackgroundDefault", 0, OOJS_ARGV, nil, @"key");
		return NO;
	}
	NSDictionary *descriptor = [UNIVERSE screenTextureDescriptorForKey:key];

	OOJS_RETURN_OBJECT(descriptor);
	
	OOJS_NATIVE_EXIT
} 
} // namespace

// setScreenBackgroundDefault (key : NSString, descriptor : guiTextureDescriptor) : boolean
namespace {
static bool GlobalSetScreenBackgroundForKey(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	BOOL			result = NO;
	
	if (EXPECT_NOT(argc < 2))
	{
		OOJSReportBadArguments(context, nil, @"setScreenBackgroundDefault", 0, OOJS_ARGV, nil, @"missing arguments");
		return NO;
	}

	NSString		*key = OOStringFromJSValue(context, OOJS_ARGV[0]);
	jsval			value = OOJS_ARGV[1];
	if (EXPECT_NOT(key == nil || [key isEqualToString:@""]))
	{
		OOJSReportBadArguments(context, nil, @"setScreenBackgroundDefault", 0, OOJS_ARGV, nil, @"key");
		return NO;
	}

	GuiDisplayGen	*gui = [UNIVERSE gui];
	NSDictionary	*descriptor = [gui textureDescriptorFromJSValue:value inContext:context callerDescription:@"setScreenBackgroundDefault()"];
	
	[UNIVERSE setScreenTextureDescriptorForKey:key descriptor:descriptor];
	result = YES;
	
	OOJS_RETURN_BOOL(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// setScreenOverlay(descriptor : guiTextureDescriptor) : Boolean
namespace {
static bool GlobalSetScreenOverlay(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	BOOL			result = NO;
	jsval			value = (argc > 0) ? OOJS_ARGV[0] : JSVAL_NULL;
	
	if (EXPECT_NOT(argc == 0))
	{
		OOJSReportWarning(context, @"Usage error: %@() called with no arguments. Treating as %@(null). This call may fail in a future version of Oolite.", @"setScreenOverlay", @"setScreenOverlay");
	}
	else if (EXPECT_NOT(JSVAL_IS_VOID(value)))
	{
		OOJSReportBadArguments(context, nil, @"setScreenOverlay", 1, &value, nil, @"GUI texture descriptor");
		return NO;
	}
	
	if ([UNIVERSE viewDirection] == VIEW_GUI_DISPLAY)
	{
		GuiDisplayGen	*gui = [UNIVERSE gui];
		NSDictionary	*descriptor = [gui textureDescriptorFromJSValue:value inContext:context callerDescription:@"setScreenOverlay()"];
		
		result = [gui setForegroundTextureDescriptor:descriptor];
	}
	
	OOJS_RETURN_BOOL(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool GlobalGetGuiColorSettingForKey(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(argc == 0))
	{
		OOJSReportBadArguments(context, nil, @"getGuiColorForKey", 0, OOJS_ARGV, nil, @"missing arguments");
		return NO;
	}
	NSString		*key = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(key == nil || [key isEqualToString:@""]))
	{
		OOJSReportBadArguments(context, nil, @"getGuiColorForKey", 0, OOJS_ARGV, nil, @"key");
		return NO;
	}
	if ([key rangeOfString:@"color"].location == NSNotFound)
	{
		OOJSReportBadArguments(context, nil, @"getGuiColorForKey", 0, OOJS_ARGV, nil, @"valid color key setting");
		return NO;
	}

	GuiDisplayGen	*gui = [UNIVERSE gui];
	OOColor *col = [gui colorFromSetting:key defaultValue:nil];

	OOJS_RETURN_OBJECT([col normalizedArray]);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// setGuiColorForKey(descriptor : OOColor) : boolean
namespace {
static bool GlobalSetGuiColorSettingForKey(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	BOOL			result = NO;
	OOColor			*col = nil;
	
	if (EXPECT_NOT(argc != 2))
	{
		OOJSReportBadArguments(context, nil, @"setGuiColorForKey", 0, OOJS_ARGV, nil, @"missing arguments");
		return NO;
	}

	NSString		*key = OOStringFromJSValue(context, OOJS_ARGV[0]);
	jsval			value = OOJS_ARGV[1];
	if (EXPECT_NOT(key == nil || [key isEqualToString:@""]))
	{
		OOJSReportBadArguments(context, nil, @"setGuiColorForKey", 0, OOJS_ARGV, nil, @"key");
		return NO;
	}
	if ([key rangeOfString:@"color"].location == NSNotFound)
	{
		OOJSReportBadArguments(context, nil, @"setGuiColorForKey", 0, OOJS_ARGV, nil, @"valid color key setting");
		return NO;
	}

	if (!JSVAL_IS_NULL(value))
	{
		col = [OOColor colorWithDescription:OOJSNativeObjectFromJSValue(context, value)];
		if (col == nil)
		{
			OOJSReportBadArguments(context, nil, @"setGuiColorForKey", 1, OOJS_ARGV, nil, @"color descriptor");
			return NO;
		}
	}

	GuiDisplayGen	*gui = [UNIVERSE gui];
	[gui setGuiColorSettingFromKey:key color:col];
	result = YES;
	
	OOJS_RETURN_BOOL(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


#ifndef NDEBUG
// takeSnapShot([name : alphanumeric String]) : Boolean
namespace {
static bool GlobalTakeSnapShot(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	NSString				*value = nil;
	NSMutableCharacterSet	*allowedChars = (NSMutableCharacterSet *)[NSMutableCharacterSet alphanumericCharacterSet];
	BOOL					result = NO;	
	
	[allowedChars addCharactersInString:@"_-"];
	
	if (argc > 0)
	{
		value = OOStringFromJSValue(context, OOJS_ARGV[0]);
		if (EXPECT_NOT(value == nil || [value rangeOfCharacterFromSet:[allowedChars invertedSet]].location != NSNotFound))
		{
			OOJSReportBadArguments(context, nil, @"takeSnapShot", argc, OOJS_ARGV, nil, @"alphanumeric string");
			return NO;
		}
	}
	
	NSString				*playerFileDirectory = [[NSFileManager defaultManager] defaultCommanderPath];
	NSDictionary			*attr = [[NSFileManager defaultManager] oo_fileSystemAttributesAtPath:playerFileDirectory];
	
	if (attr != nil)
	{
		double freeSpace = [attr oo_doubleForKey:NSFileSystemFreeSize];
		if (freeSpace < 1073741824) // less than 1 GB free on disk?
		{
			OOJSReportWarning(context, @"takeSnapShot: function disabled when free disk space is less than 1GB.");
			OOJS_RETURN_BOOL(NO);
		}
	}
	
	
	OOJS_BEGIN_FULL_NATIVE(context)
	result = [[UNIVERSE gameView] snapShot:value];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_BOOL(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace
#endif

// autoAIForRole(role : String) : String
namespace {
static bool GlobalAutoAIForRole(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	NSString			*string = nil;
	
	if (argc > 0)  string = OOStringFromJSValue(context,OOJS_ARGV[0]);
	if (string == nil)
	{
		OOJSReportBadArguments(context, nil, @"autoAIForRole", MIN(argc, 1U), OOJS_ARGV, nil, @"string");
		return NO;
	}

	NSDictionary *autoAIMap = [ResourceManager dictionaryFromFilesNamed:@"autoAImap.plist" inFolder:@"Config" andMerge:YES];
	NSString *autoAI = [autoAIMap oo_stringForKey:string];

	OOJS_RETURN_OBJECT(autoAI);
	
	OOJS_NATIVE_EXIT
}
} // namespace

// pauseGame() : Boolean
namespace {
static bool GlobalPauseGame(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	BOOL			result = NO;
	PlayerEntity	*player = PLAYER;
	
	if (player)
	{
		OOGUIScreenID guiScreen = [player guiScreen];
		
		if 	(guiScreen != GUI_SCREEN_LONG_RANGE_CHART &&
			 guiScreen != GUI_SCREEN_MISSION &&
			 guiScreen != GUI_SCREEN_REPORT &&
			 guiScreen != GUI_SCREEN_KEYBOARD_ENTRY &&
			 guiScreen != GUI_SCREEN_SAVE)
		{
			[UNIVERSE pauseGame];
			result = YES;
		}
	}
	
	OOJS_RETURN_BOOL(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace

// quitGame() : Boolean
namespace {
static bool GlobalQuitGame(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)

	OOLog(@"script.debug.quit", @"%@", @"Quit requested via JavaScript global.quitGame()");

	[UNIVERSE quitGame];

	OOJS_RETURN_BOOL(YES);

	OOJS_NATIVE_EXIT
}
} // namespace
