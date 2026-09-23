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
#import "OOPListView.h"
#import "OOTexture.h"
#import "GuiDisplayGen.h"
#import "MyOpenGLView.h"
#import "ResourceManager.h"
#import "OOSystemDescriptionManager.h"
#import "NSFileManagerOOExtensions.h"
#import "OOJSGuiScreenKeyDefinition.h"
#import "OOFoundationBridge.h"
#include "oofnd/FileSystem.hpp"

#include "ooscript/JSEngine.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) per bead oo-8yi, the same way bead oo-sdz
	retargeted OOJSVector.mm (the exemplar for this sweep; see its header comment for the full
	rationale). This file's directly-spelled engine calls -- the ooscript::ClassDef hook-stub family
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
	DefineFunctions take those, not the engine's ooscript::PropertySpec / ooscript::FunctionSpec pointers),
	every JS global method to take the façade's NativeFn hook signature
	(Context, CallArgs&) rather than the engine's (ooscript::Context, unsigned argc, ooscript::Value *vp). A small
	shim at the top of each recovers the old ooscript::Context, unsigned, and ooscript::Value * locals so the
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
// and the handle types are byte copies of ooscript::Value/ooscript::PropertyId/JS*; see OOJSVector.mm for the same,
// non-exported, pattern).


#if OOJSENGINE_MONITOR_SUPPORT

@interface OOJavaScriptEngine (OOMonitorSupportInternal)

// Implemented in OOJavaScriptEngine.mm, whose bead decides its types: Objective-C strings until then.
- (void)sendMonitorLogMessage:(id)message
			 withMessageClass:(id)messageClass
					inContext:(ooscript::Context)context;

@end

#endif


static const char * const kOOLogDebugMessage = "script.debug.message";


namespace {
static bool GlobalGetProperty(Context cx, Object obj, PropertyId propID, Value *value);

// What -oo_stringForKey: made of the value it found: a string, or a number's text; nullopt (was
// nil) for no value or any other kind of value.
static std::optional<std::string> StringFromObject(id object)
{
	const oo::PList value = oo::PListFrom(object);
	if (!(value.isString() || value.isNumber()))  return std::nullopt;
	return oo::PListGet<std::string>::from(&value, std::string());
}
} // namespace
#ifndef NDEBUG
namespace {
static bool GlobalSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace
#endif

namespace {
static bool GlobalLog(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalExpandDescription(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalKeyBindingDescription(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalExpandMissionText(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalDisplayNameForCommodity(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalRandomName(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalRandomInhabitantsDescription(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalSetScreenBackground(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalSetScreenOverlay(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalGetScreenBackgroundForKey(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalSetScreenBackgroundForKey(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalAutoAIForRole(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalPauseGame(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalQuitGame(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalGetGuiColorSettingForKey(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalSetGuiColorSettingForKey(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalSetExtraGuiScreenKeys(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool GlobalClearExtraGuiScreenKeys(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace

#ifndef NDEBUG
namespace {
static bool GlobalTakeSnapShot(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
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
	nullptr,			// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
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
// bead's scope (they are shared across every binding file) and still take a ooscript::PropertySpec*,
// not ooscript::PropertySpec*, the same as OOJSVector.mm's sVectorPropertiesRaw.
namespace {
static ooscript::PropertySpec sGlobalPropertiesRaw[] =
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


void CreateOOJSGlobal(ooscript::Context context, ooscript::Object *outGlobal)
{
	assert(outGlobal != NULL);
	
	Context cx = (context);
	Object global = ooscript::newGlobalObject(cx, &sGlobalClass);
	*outGlobal = (global);
	
	ooscript::setGlobalObject(cx, global);
	ooscript::defineProperty(cx, global, "global", ooscript::objectValue(global), nullptr, nullptr,
							  kGlobalSelfPropertyFlags);
}


void SetUpOOJSGlobal(ooscript::Context context, ooscript::Object global)
{
	Context cx = (context);
	Object obj = (global);
	ooscript::defineProperties(cx, obj, sGlobalProperties);
	ooscript::defineFunctions(cx, obj, sGlobalMethods);
}


namespace {
static bool GlobalGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity				*player = OOPlayerForScripting();
	
	switch (ooscript::idToInt32(propID))
	{
		case kGlobal_galaxyNumber:
			*value = ooscript::int32Value([player currentGalaxyID]);
			return YES;
			
		case kGlobal_guiScreen:
			*value = (OOJSValueFromGUIScreenID(context, [player guiScreen]));
			return YES;
			
#ifndef NDEBUG
		case kGlobal_timeAccelerationFactor:
			return ooscript::newNumberValue(cx, [UNIVERSE timeAccelerationFactor], value);
#endif
			
		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sGlobalPropertiesRaw);
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
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	
	OOJS_NATIVE_ENTER(context)
	
	double					fValue;
	
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
			OOJSReportBadPropertySelector(context, thisObj, (propID), sGlobalPropertiesRaw);
	}
	
	OOJSReportBadPropertyValue(context, thisObj, (propID), sGlobalPropertiesRaw, *(value));
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace
#endif


// *** Methods ***

// log([messageClass : String,] message : string, ...)
namespace {
static bool GlobalLog(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	std::optional<std::string>	message;
	std::string			messageClass;
	
	if (EXPECT_NOT(oojsArgs.count() < 1))
	{
		OOJS_RETURN_VOID;
	}
	if (oojsArgs.count() < 2)
	{
		messageClass = kOOLogDebugMessage;
		message = oo::OptionalString(OOStringFromJSValue(context, OOJS_ARGV[0]));
	}
	else
	{
		messageClass = oo::StdString(OOStringFromJSValueEvenIfNull(context, OOJS_ARGV[0]));
		if (!OOLogWillDisplayMessagesInClass(oo::NSStringFrom(messageClass)))
		{
			// Do nothing (and short-circuit) if message class is filtered out.
			OOJS_RETURN_VOID;
		}
		
		// The remaining arguments as strings, joined with ", " (as +concatenationOfStringsFromJavaScriptValues:... did).
		std::string joined;
		for (unsigned i = 1; i < oojsArgs.count(); i++)
		{
			if (i > 1)  joined += ", ";
			joined += oo::StdString(OOStringFromJSValueEvenIfNull(context, OOJS_ARGV[i]));
		}
		message = joined;
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	OOLog(oo::NSStringFrom(messageClass), @"%@", oo::NSStringOrNil(message));
	
#if OOJSENGINE_MONITOR_SUPPORT
	[[OOJavaScriptEngine sharedEngine] sendMonitorLogMessage:oo::NSStringOrNil(message)
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
static bool GlobalExpandDescription(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	std::optional<std::string>	string;
	oo::PList			overrides;
	
	if (oojsArgs.count() > 0)  string = oo::OptionalString(OOStringFromJSValue(context, OOJS_ARGV[0]));
	if (!string.has_value())
	{
		OOJSReportBadArguments(context, nil, @"expandDescription", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string");
		return NO;
	}
	if (oojsArgs.count() > 1)
	{
		overrides = oo::PListFrom(OOJSDictionaryFromStringTable(context, OOJS_ARGV[1]));
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	string = oo::OptionalString(OOExpandDescriptionString(kNilRandomSeed, oo::NSStringFrom(*string), oo::ObjectFromPList(overrides), nil, nil, kOOExpandForJavaScript | kOOExpandGoodRNG));
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_OBJECT(oo::NSStringOrNil(string));
	
	OOJS_NATIVE_EXIT
}
} // namespace

namespace {
static bool GlobalKeyBindingDescription(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	std::optional<std::string>	string;
	PlayerEntity				*player = OOPlayerForScripting();
	
	if (oojsArgs.count() > 0)  string = oo::OptionalString(OOStringFromJSValue(context, OOJS_ARGV[0]));
	if (!string.has_value())
	{
		OOJSReportBadArguments(context, nil, @"keyBindingDescription", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string");
		return NO;
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	string = oo::OptionalString([player keyBindingDescription2:oo::NSStringFrom(*string)]);
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_OBJECT(oo::NSStringOrNil(string));
	
	OOJS_NATIVE_EXIT
}
} // namespace


// expandMissionText(textKey : String [, overrides : object (dictionary)]) : String
namespace {
static bool GlobalExpandMissionText(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	std::optional<std::string>	string;
	oo::PList			overrides;
	
	if (oojsArgs.count() > 0)  string = oo::OptionalString(OOStringFromJSValue(context, OOJS_ARGV[0]));
	if (!string.has_value())
	{
		OOJSReportBadArguments(context, nil, @"expandMissionText", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string");
		return NO;
	}
	if (oojsArgs.count() > 1)
	{
		overrides = oo::PListFrom(OOJSDictionaryFromStringTable(context, OOJS_ARGV[1]));
	}
	
	string = StringFromObject([[UNIVERSE missiontext] objectForKey:oo::NSStringFrom(*string)]);
	string = oo::OptionalString(OOExpandDescriptionString(kNilRandomSeed, oo::NSStringOrNil(string), oo::ObjectFromPList(overrides), nil, nil, kOOExpandForJavaScript | kOOExpandBackslashN | kOOExpandGoodRNG));
	
	OOJS_RETURN_OBJECT(oo::NSStringOrNil(string));
	
	OOJS_NATIVE_EXIT
}
} // namespace


// displayNameForCommodity(commodityName : String) : String
namespace {
static bool GlobalDisplayNameForCommodity(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	std::optional<std::string>	string;
	
	if (oojsArgs.count() > 0)  string = oo::OptionalString(OOStringFromJSValue(context,OOJS_ARGV[0]));
	if (!string.has_value())
	{
		OOJSReportBadArguments(context, nil, @"displayNameForCommodity", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string");
		return NO;
	}
	OOJS_RETURN_OBJECT(CommodityDisplayNameForSymbolicName(oo::NSStringFrom(*string)));
	
	OOJS_NATIVE_EXIT
}
} // namespace


// randomName() : String
namespace {
static bool GlobalRandomName(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	/*	Temporarily set the system generation seed to a "really random" seed,
		so randomName() isn't repeatable.
	*/
	RNG_Seed savedSeed = currentRandomSeed();
	setRandomSeed((RNG_Seed){ (int32_t)Ranrot(), (int32_t)Ranrot(), (int32_t)Ranrot(), (int32_t)Ranrot() });
	
	std::optional<std::string> result = oo::OptionalString(OOExpand(@"%N"));
	
	// Restore seed.
	setRandomSeed(savedSeed);
	
	OOJS_RETURN_OBJECT(oo::NSStringOrNil(result));
	
	OOJS_NATIVE_EXIT
}
} // namespace


// randomInhabitantsDescription() : String
namespace {
static bool GlobalRandomInhabitantsDescription(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	std::optional<std::string>	string;
	Random_Seed			aSeed;
	bool				isPlural = true;
	
	if (oojsArgs.count() > 0 && !ooscript::valueToBoolean(context, (OOJS_ARGV[0]), &isPlural))
	{
		OOJSReportBadArguments(context, nil, @"randomInhabitantsDescription", 1, OOJS_ARGV, nil, @"boolean");
		return NO;
	}
	
	make_pseudo_random_seed(&aSeed);
	string = oo::OptionalString([UNIVERSE getSystemInhabitants:Ranrot()%OO_SYSTEMS_PER_GALAXY plural:(isPlural ? YES : NO)]);
	OOJS_RETURN_OBJECT(oo::NSStringOrNil(string));
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool GlobalClearExtraGuiScreenKeys(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)

	BOOL				result = NO;
	PlayerEntity		*player = OOPlayerForScripting();

	if (EXPECT_NOT(oojsArgs.count() < 2))
	{
		OOJSReportBadArguments(context, nil, @"setExtraGuiScreenKeys", 0, OOJS_ARGV, nil, @"missing arguments");
		return NO;
	}

	std::optional<std::string> key = oo::OptionalString(OOStringFromJSValue(context, OOJS_ARGV[0]));
	if (EXPECT_NOT(!key.has_value() || key->empty()))
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

	[player clearExtraGuiScreenKeys:gui key:oo::NSStringFrom(*key)];

	result = YES;
	OOJS_RETURN_BOOL(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace

namespace {
static bool GlobalSetExtraGuiScreenKeys(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)

	BOOL				result = NO;
	ooscript::Value				callback = ooscript::nullValue();
	ooscript::Object callbackThis = NULL;
	ooscript::Value				value = ooscript::nullValue();
	std::optional<std::string>	key;
	OOGUIScreenID 		gui;
	oo::PList			keydefs;
	ooscript::Object params = NULL;
	PlayerEntity		*player = OOPlayerForScripting();

	if (EXPECT_NOT(oojsArgs.count() < 1))
	{
		OOJSReportBadArguments(context, nil, @"setExtraGuiScreenKeys", 0, OOJS_ARGV, nil, @"key, definition");
		return NO;
	}
	key = oo::OptionalString(OOStringFromJSValue(context, OOJS_ARGV[0]));

	// Validate arguments.
	{
		Object paramsObj = nullptr;
		if (oojsArgs.count() < 2 || !ooscript::valueToObject(context, (OOJS_ARGV[1]), &paramsObj))
		{
			OOJSReportBadArguments(context, @"global", @"setExtraGuiScreenKeys", 2, &OOJS_ARGV[1], nil, @"key, definition: definition is not a valid dictionary.");
			return NO;
		}
		params = (paramsObj);
	}

	if (!ooscript::getProperty(context, (params), "guiScreen", (&value)) || ooscript::isUndefined(value))
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

	if (!ooscript::getProperty(context, (params), "registerKeys", (&value)) || ooscript::isUndefined(value))
	{
		OOJSReportBadArguments(context, @"global", @"setExtraGuiScreenKeys", 2, &OOJS_ARGV[1], nil, @"key, definition: must have a 'registerKeys' property.");
		return NO;
	}
	if (!ooscript::isNull(value))
	{
		if (ooscript::isObjectOrNull(value))
		{
			keydefs = oo::PListFrom(OOJSNativeObjectFromJSObject(context, ooscript::toObject(value)));
		}
		else 
		{
			OOJSReportBadArguments(context, @"global", @"setExtraGuiScreenKeys", 2, &OOJS_ARGV[1], nil, @"key, definition: registerKeys is not a valid dictionary.");
			return NO;
		}
	}

	if (!ooscript::getProperty(context, (params), "callback", (&callback)) || ooscript::isUndefined(callback))
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
	[definition setName:oo::NSStringOrNil(key)];
	[definition setRegisterKeys:keydefs];
	[definition setCallback:callback];

	// get callback 'this'
	if (ooscript::getProperty(context, (params), "cbThis", (&value)) && !ooscript::isUndefined(value))
	{
		Object callbackThisObj = nullptr;
		ooscript::valueToObject(context, (value), &callbackThisObj);
		callbackThis = (callbackThisObj);
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
static bool GlobalSetScreenBackground(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	BOOL			result = NO;
	ooscript::Value			value = (oojsArgs.count() > 0) ? OOJS_ARGV[0] : ooscript::nullValue();
	
	if (EXPECT_NOT(oojsArgs.count() == 0))
	{
		OOJSReportWarning(context, @"Usage error: %@() called with no arguments. Treating as %@(null). This call may fail in a future version of Oolite.", @"setScreenBackground", @"setScreenBackground");
	}
	else if (EXPECT_NOT(ooscript::isUndefined(value)))
	{
		OOJSReportBadArguments(context, nil, @"setScreenBackground", 1, &value, nil, @"GUI texture descriptor");
		return NO;
	}
	
	if ([UNIVERSE viewDirection] == VIEW_GUI_DISPLAY)
	{
		GuiDisplayGen	*gui = [UNIVERSE gui];
		oo::PList		descriptor = oo::PListFrom([gui textureDescriptorFromJSValue:value inContext:context callerDescription:@"setScreenBackground()"]);
		
		result = [gui setBackgroundTextureDescriptor:oo::ObjectFromPList(descriptor)];
		
		// add some permanence to the override if we're in the equip ship screen
		if (result && [PLAYER guiScreen] == GUI_SCREEN_EQUIP_SHIP)  [PLAYER setEquipScreenBackgroundDescriptor:oo::ObjectFromPList(descriptor)];
	}
	
	OOJS_RETURN_BOOL(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool GlobalGetScreenBackgroundForKey(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(oojsArgs.count() == 0))
	{
		OOJSReportBadArguments(context, nil, @"getScreenBackgroundDefault", 0, OOJS_ARGV, nil, @"missing arguments");
		return NO;
	}
	std::optional<std::string>	key = oo::OptionalString(OOStringFromJSValue(context, OOJS_ARGV[0]));
	if (EXPECT_NOT(!key.has_value() || key->empty()))
	{
		OOJSReportBadArguments(context, nil, @"getScreenBackgroundDefault", 0, OOJS_ARGV, nil, @"key");
		return NO;
	}
	OOJS_RETURN_OBJECT([UNIVERSE screenTextureDescriptorForKey:oo::NSStringFrom(*key)]);
	
	OOJS_NATIVE_EXIT
} 
} // namespace

// setScreenBackgroundDefault (key : String, descriptor : guiTextureDescriptor) : boolean
namespace {
static bool GlobalSetScreenBackgroundForKey(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	BOOL			result = NO;
	
	if (EXPECT_NOT(oojsArgs.count() < 2))
	{
		OOJSReportBadArguments(context, nil, @"setScreenBackgroundDefault", 0, OOJS_ARGV, nil, @"missing arguments");
		return NO;
	}

	std::optional<std::string>	key = oo::OptionalString(OOStringFromJSValue(context, OOJS_ARGV[0]));
	ooscript::Value			value = OOJS_ARGV[1];
	if (EXPECT_NOT(!key.has_value() || key->empty()))
	{
		OOJSReportBadArguments(context, nil, @"setScreenBackgroundDefault", 0, OOJS_ARGV, nil, @"key");
		return NO;
	}

	GuiDisplayGen	*gui = [UNIVERSE gui];
	oo::PList		descriptor = oo::PListFrom([gui textureDescriptorFromJSValue:value inContext:context callerDescription:@"setScreenBackgroundDefault()"]);
	
	[UNIVERSE setScreenTextureDescriptorForKey:oo::NSStringFrom(*key) descriptor:oo::ObjectFromPList(descriptor)];
	result = YES;
	
	OOJS_RETURN_BOOL(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// setScreenOverlay(descriptor : guiTextureDescriptor) : Boolean
namespace {
static bool GlobalSetScreenOverlay(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	BOOL			result = NO;
	ooscript::Value			value = (oojsArgs.count() > 0) ? OOJS_ARGV[0] : ooscript::nullValue();
	
	if (EXPECT_NOT(oojsArgs.count() == 0))
	{
		OOJSReportWarning(context, @"Usage error: %@() called with no arguments. Treating as %@(null). This call may fail in a future version of Oolite.", @"setScreenOverlay", @"setScreenOverlay");
	}
	else if (EXPECT_NOT(ooscript::isUndefined(value)))
	{
		OOJSReportBadArguments(context, nil, @"setScreenOverlay", 1, &value, nil, @"GUI texture descriptor");
		return NO;
	}
	
	if ([UNIVERSE viewDirection] == VIEW_GUI_DISPLAY)
	{
		GuiDisplayGen	*gui = [UNIVERSE gui];
		oo::PList		descriptor = oo::PListFrom([gui textureDescriptorFromJSValue:value inContext:context callerDescription:@"setScreenOverlay()"]);
		
		result = [gui setForegroundTextureDescriptor:oo::ObjectFromPList(descriptor)];
	}
	
	OOJS_RETURN_BOOL(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool GlobalGetGuiColorSettingForKey(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(oojsArgs.count() == 0))
	{
		OOJSReportBadArguments(context, nil, @"getGuiColorForKey", 0, OOJS_ARGV, nil, @"missing arguments");
		return NO;
	}
	std::optional<std::string>	key = oo::OptionalString(OOStringFromJSValue(context, OOJS_ARGV[0]));
	if (EXPECT_NOT(!key.has_value() || key->empty()))
	{
		OOJSReportBadArguments(context, nil, @"getGuiColorForKey", 0, OOJS_ARGV, nil, @"key");
		return NO;
	}
	if (key->find("color") == std::string::npos)
	{
		OOJSReportBadArguments(context, nil, @"getGuiColorForKey", 0, OOJS_ARGV, nil, @"valid color key setting");
		return NO;
	}

	GuiDisplayGen	*gui = [UNIVERSE gui];
	OOColor *col = [gui colorFromSetting:oo::NSStringFrom(*key) defaultValue:nil];

	// The components as the colour's -normalizedArray gave them: floats, nil for no colour.
	oo::PList::Array components;
	for (float component : [col cxx_normalizedArray])  components.push_back(oo::PList::singleReal(component));
	OOJS_RETURN_OBJECT(col != nil ? oo::ObjectFromPList(oo::PList(std::move(components))) : nil);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// setGuiColorForKey(descriptor : OOColor) : boolean
namespace {
static bool GlobalSetGuiColorSettingForKey(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	BOOL			result = NO;
	OOColor			*col = nil;
	
	if (EXPECT_NOT(oojsArgs.count() != 2))
	{
		OOJSReportBadArguments(context, nil, @"setGuiColorForKey", 0, OOJS_ARGV, nil, @"missing arguments");
		return NO;
	}

	std::optional<std::string>	key = oo::OptionalString(OOStringFromJSValue(context, OOJS_ARGV[0]));
	ooscript::Value			value = OOJS_ARGV[1];
	if (EXPECT_NOT(!key.has_value() || key->empty()))
	{
		OOJSReportBadArguments(context, nil, @"setGuiColorForKey", 0, OOJS_ARGV, nil, @"key");
		return NO;
	}
	if (key->find("color") == std::string::npos)
	{
		OOJSReportBadArguments(context, nil, @"setGuiColorForKey", 0, OOJS_ARGV, nil, @"valid color key setting");
		return NO;
	}

	if (!ooscript::isNull(value))
	{
		col = [OOColor colorWithDescription:OOJSNativeObjectFromJSValue(context, value)];
		if (col == nil)
		{
			OOJSReportBadArguments(context, nil, @"setGuiColorForKey", 1, OOJS_ARGV, nil, @"color descriptor");
			return NO;
		}
	}

	GuiDisplayGen	*gui = [UNIVERSE gui];
	[gui setGuiColorSettingFromKey:oo::NSStringFrom(*key) color:col];
	result = YES;
	
	OOJS_RETURN_BOOL(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


#ifndef NDEBUG
// takeSnapShot([name : alphanumeric String]) : Boolean
namespace {
static bool GlobalTakeSnapShot(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	std::optional<std::string>	value;
	NSCharacterSet			*alphanumerics = [NSCharacterSet alphanumericCharacterSet];
	BOOL					result = NO;	
	
	// Allowed: the alphanumeric character set plus "_-", tested per UTF-16 unit as -rangeOfCharacterFromSet: did.
	auto isAllowed = [alphanumerics](const std::string &name) {
		for (char16_t unit : oo::utf8ToUtf16(name))
		{
			if (unit != u'_' && unit != u'-' && ![alphanumerics characterIsMember:unit])  return false;
		}
		return true;
	};
	
	if (oojsArgs.count() > 0)
	{
		value = oo::OptionalString(OOStringFromJSValue(context, OOJS_ARGV[0]));
		if (EXPECT_NOT(!value.has_value() || !isAllowed(*value)))
		{
			OOJSReportBadArguments(context, nil, @"takeSnapShot", oojsArgs.count(), OOJS_ARGV, nil, @"alphanumeric string");
			return NO;
		}
	}
	
	std::string				playerFileDirectory = oo::StdString([[NSFileManager defaultManager] defaultCommanderPath]);
	const auto				freeBytes = oo::fs::freeSpace(oo::fs::pathFromUTF8(playerFileDirectory));
	
	if (freeBytes.has_value())
	{
		double freeSpace = static_cast<double>(*freeBytes);
		if (freeSpace < 1073741824) // less than 1 GB free on disk?
		{
			OOJSReportWarning(context, @"takeSnapShot: function disabled when free disk space is less than 1GB.");
			OOJS_RETURN_BOOL(NO);
		}
	}
	
	
	OOJS_BEGIN_FULL_NATIVE(context)
	result = [[UNIVERSE gameView] cxx_snapShot:value];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_BOOL(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace
#endif

// autoAIForRole(role : String) : String
namespace {
static bool GlobalAutoAIForRole(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	std::optional<std::string>	string;
	
	if (oojsArgs.count() > 0)  string = oo::OptionalString(OOStringFromJSValue(context,OOJS_ARGV[0]));
	if (!string.has_value())
	{
		OOJSReportBadArguments(context, nil, @"autoAIForRole", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string");
		return NO;
	}

	std::optional<std::string> autoAI = StringFromObject([[ResourceManager dictionaryFromFilesNamed:@"autoAImap.plist" inFolder:@"Config" andMerge:YES] objectForKey:oo::NSStringFrom(*string)]);

	OOJS_RETURN_OBJECT(oo::NSStringOrNil(autoAI));
	
	OOJS_NATIVE_EXIT
}
} // namespace

// pauseGame() : Boolean
namespace {
static bool GlobalPauseGame(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
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
static bool GlobalQuitGame(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)

	OOLog(@"script.debug.quit", @"%@", @"Quit requested via JavaScript global.quitGame()");

	[UNIVERSE quitGame];

	OOJS_RETURN_BOOL(YES);

	OOJS_NATIVE_EXIT
}
} // namespace
