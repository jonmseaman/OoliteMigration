/*

OOJSOolite.h

JavaScript proxy for Oolite (for version checking and similar).


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

#import "OOJSOolite.h"
#import "OOJavaScriptEngine.h"
#import "OOStringParsing.h"
#import "OOJSPlayer.h"
#import "ResourceManager.h"
#import "MyOpenGLView.h"
#import "OOConstToString.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>

// Retargeted onto the ooscript facade (JSEngine.hpp), the way OOJSWormhole.mm and
// OOJSClock.mm do it (bead oo-sdz exemplar): the class dispatch table becomes a static
// ooscript::ClassDef (stub hooks become nullptr), InitClass becomes ooscript::initClass,
// numeric conversion becomes ooscript::newNumberValue/ooscript::valueToNumber, and `this` is
// renamed to `thisObj` (reserved word in Objective-C++, ADR-0001).
namespace ooscript { }
using ooscript::Context;
using ooscript::Object;
using ooscript::Value;
using ooscript::PropertyId;
using ooscript::ClassDef;
using ooscript::ClassFlag;
using ooscript::PropertyFlag;
using ooscript::PropertySpec;
using ooscript::FunctionSpec;
using ooscript::CallArgs;

namespace {
static bool OoliteGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool OoliteSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace

namespace {
static NSString *VersionString(void);
} // namespace
namespace {
static NSArray *VersionComponents(void);
} // namespace

namespace {
static bool OoliteCompareVersion(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace



namespace {
static ClassDef sOoliteClass =
{
	"Oolite",
	ClassFlag::None,
	
	nullptr,		// addProperty (engine default: PropertyStub)
	nullptr,		// delProperty (engine default: PropertyStub)
	OoliteGetProperty,		// getProperty
	OoliteSetProperty,		// setProperty
	nullptr,		// enumerate (engine default: EnumerateStub)
	nullptr,			// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,			// resolve (engine default: ResolveStub)
	nullptr,			// convert (engine default: ConvertStub)
	nullptr,			// finalize (engine default: FinalizeStub)
	nullptr,			// call
	nullptr,			// construct
	nullptr,			// backend: owned by the facade backend, must start null
};
} // namespace


enum : std::uint8_t
{
	// Property IDs
	kOolite_version,			// version number components, array, read-only
	kOolite_versionString,		// version number as string, string, read-only
	kOolite_jsVersion,			// JavaScript version, integer, read-only
	kOolite_jsVersionString,	// JavaScript version as string, string, read-only
	kOolite_gameSettings,		// Various game settings, object, read-only
	kOolite_resourcePaths,		// Paths containing resources, built-in plus oxp/oxz, read-only
	kOolite_colorSaturation,	// Color saturation, integer, read/write
	kOolite_postFX,				// current post processing effect, integer, read/write
	kOolite_hdrToneMapper,		// currently active HDR tone mapper, string, read/write
	kOolite_sdrToneMapper,		// currently active SDR tone mapper, string, read/write
#ifndef NDEBUG
	kOolite_timeAccelerationFactor,	// time acceleration, float, read/write
#endif
};


namespace {
constexpr PropertyFlag kOolitePropertyFlagsRO = PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared;
constexpr PropertyFlag kOolitePropertyFlagsRW = PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared;
} // namespace


namespace {
static PropertySpec sOoliteProperties[] =
{
	// JS name					ID							flags						getter	setter
	{ "gameSettings",			kOolite_gameSettings,		kOolitePropertyFlagsRO, nullptr, nullptr },
	{ "jsVersion",				kOolite_jsVersion,			kOolitePropertyFlagsRO, nullptr, nullptr },
	{ "jsVersionString",		kOolite_jsVersionString,	kOolitePropertyFlagsRO, nullptr, nullptr },
	{ "version",				kOolite_version,			kOolitePropertyFlagsRO, nullptr, nullptr },
	{ "versionString",			kOolite_versionString,		kOolitePropertyFlagsRO, nullptr, nullptr },
	{ "resourcePaths",			kOolite_resourcePaths,		kOolitePropertyFlagsRO, nullptr, nullptr },
	{ "colorSaturation",		kOolite_colorSaturation,	kOolitePropertyFlagsRW, nullptr, nullptr },
	{ "postFX",					kOolite_postFX,				kOolitePropertyFlagsRW, nullptr, nullptr },
	{ "hdrToneMapper",			kOolite_hdrToneMapper, 		kOolitePropertyFlagsRW, nullptr, nullptr },
	{ "sdrToneMapper",			kOolite_sdrToneMapper, 		kOolitePropertyFlagsRW, nullptr, nullptr },
#ifndef NDEBUG
	{ "timeAccelerationFactor",	kOolite_timeAccelerationFactor,	kOolitePropertyFlagsRW, nullptr, nullptr },
#endif
	{ 0 }
};
} // namespace


// Mirror of sOoliteProperties with the read-only/read-write flags the shared error reporters
// describe the properties by (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static ooscript::PropertySpec sOolitePropertiesRaw[] =
{
	// JS name					ID							flags
	{ "gameSettings",			kOolite_gameSettings,		OOJS_PROP_READONLY_CB },
	{ "jsVersion",				kOolite_jsVersion,			OOJS_PROP_READONLY_CB },
	{ "jsVersionString",		kOolite_jsVersionString,	OOJS_PROP_READONLY_CB },
	{ "version",				kOolite_version,			OOJS_PROP_READONLY_CB },
	{ "versionString",			kOolite_versionString,		OOJS_PROP_READONLY_CB },
	{ "resourcePaths",			kOolite_resourcePaths,		OOJS_PROP_READONLY_CB },
	{ "colorSaturation",		kOolite_colorSaturation,	OOJS_PROP_READWRITE_CB },
	{ "postFX",					kOolite_postFX,				OOJS_PROP_READWRITE_CB },
	{ "hdrToneMapper",			kOolite_hdrToneMapper, 		OOJS_PROP_READWRITE_CB },
	{ "sdrToneMapper",			kOolite_sdrToneMapper, 		OOJS_PROP_READWRITE_CB },
#ifndef NDEBUG
	{ "timeAccelerationFactor",	kOolite_timeAccelerationFactor,	OOJS_PROP_READWRITE_CB },
#endif
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sOoliteMethods[] =
{
	// JS name					Function					min args
	{ "compareVersion",			OoliteCompareVersion,		1 },
	{ 0 }
};
} // namespace


namespace {
constexpr PropertyFlag kOoliteObjectFlags = PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly;
} // namespace


void InitOOJSOolite(ooscript::Context context, ooscript::Object global)
{
	Object oolitePrototype = ooscript::initClass((context), (global), nullptr, &sOoliteClass, OOJSUnconstructableConstruct, 0, sOoliteProperties, sOoliteMethods, nullptr, nullptr);
	ooscript::defineObject((context), (global), "oolite", &sOoliteClass, oolitePrototype, kOoliteObjectFlags);
}


namespace {
static bool OoliteGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = value;
	
	OOJS_NATIVE_ENTER(context)
	
	id						result = nil;
	MyOpenGLView			*gameView = [UNIVERSE gameView];
	
	switch (ooscript::idToInt32(propID))
	{
		case kOolite_version:
			result = VersionComponents();
			break;
		
		case kOolite_versionString:
			result = VersionString();
			break;
		
		case kOolite_jsVersion:
			*value_raw = ooscript::int32Value(static_cast<int>(ooscript::getVersion(cx)));
			return YES;
		
		case kOolite_jsVersionString:
			*value_raw = ooscript::stringValue((ooscript::newStringCopyZ(cx, ooscript::versionToString(ooscript::getVersion(cx)))));
			return YES;
		
		case kOolite_gameSettings:
			result = [UNIVERSE gameSettings];
			break;
			
		case kOolite_resourcePaths:
			// user name in displayed paths masked for privacy - remember that the console can be run remotely too
			result = [ResourceManager maskUserNameInPathArray:[ResourceManager paths]];
			break;
			
		case kOolite_colorSaturation:
			return ooscript::newNumberValue(cx, [gameView colorSaturation], value);
			
		case kOolite_postFX:
			*value_raw = ooscript::int32Value([UNIVERSE currentPostFX]);
			return YES;
			
		case kOolite_hdrToneMapper:
		{
			NSString *toneMapperStr = @"OOHDR_TONEMAPPER_UNDEFINED";
#if OOLITE_WINDOWS
			if ([gameView hdrOutput])
			{
				toneMapperStr = OOStringFromHDRToneMapper([gameView hdrToneMapper]);
			}
#endif
			result = toneMapperStr;
			break;
		}
		
		case kOolite_sdrToneMapper:
		{
			NSString *toneMapperStr = @"OOSDR_TONEMAPPER_UNDEFINED";
			if (![gameView hdrOutput])
			{
				toneMapperStr = OOStringFromSDRToneMapper([gameView sdrToneMapper]);
			}
			result = toneMapperStr;
			break;
		}
			
#ifndef NDEBUG
		case kOolite_timeAccelerationFactor:
			return ooscript::newNumberValue(cx, [UNIVERSE timeAccelerationFactor], value);
#endif
		
		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sOolitePropertiesRaw);
			return NO;
	}
	
	*value_raw = OOJSValueFromNativeObject(context, result);
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool OoliteSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = value;
	
	OOJS_NATIVE_ENTER(context)
	
	double					fValue;
	int32_t					iValue;
	NSString				*sValue = nil;
	MyOpenGLView 			*gameView = [UNIVERSE gameView];
	
	switch (ooscript::idToInt32(propID))
	{
		case kOolite_colorSaturation:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				float currentColorSaturation = [gameView colorSaturation];
				[gameView adjustColorSaturation:fValue - currentColorSaturation];
				return YES;
			}
			break;
			
		case kOolite_postFX:
			if (ooscript::valueToInt32(cx, *value, &iValue))
			{
				iValue = MAX(iValue, 0);
				[UNIVERSE setCurrentPostFX:iValue];
				return YES;
			}
			break;
			
		case kOolite_hdrToneMapper:
			if (!ooscript::isString(*value_raw))  break; // non-string is not allowed
			sValue = OOStringFromJSValue(context,*value_raw);
			if (sValue != nil)
			{
#if OOLITE_WINDOWS
				if ([gameView hdrOutput])  [gameView setHDRToneMapper:OOHDRToneMapperFromString(sValue)];
				else  OOJSReportWarning(context, @"hdrToneMapper cannot be set if not running in HDR mode");
#endif
				return YES;
			}
			break;
			
		case kOolite_sdrToneMapper:
			if (!ooscript::isString(*value_raw))  break; // non-string is not allowed
			sValue = OOStringFromJSValue(context,*value_raw);
			if (sValue != nil)
			{
				if (![gameView hdrOutput])  [gameView setSDRToneMapper:OOSDRToneMapperFromString(sValue)];
				else  OOJSReportWarning(context, @"sdrToneMapper cannot be set if not running in SDR mode");
				return YES;
			}
			break;
			
#ifndef NDEBUG
		case kOolite_timeAccelerationFactor:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				[UNIVERSE setTimeAccelerationFactor:fValue];
				return YES;
			}
			break;
#endif
			
		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sOolitePropertiesRaw);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, (propID), sOolitePropertiesRaw, *value_raw);
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static NSString *VersionString(void)
{
	return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
}
} // namespace


namespace {
static NSArray *VersionComponents(void)
{
	return ComponentsFromVersionString(VersionString());
}
} // namespace


/*	oolite.compareVersion(versionSpec) : Number
	returns -1 if the current version of Oolite is less than versionSpec, 0 if
	they are equal, and 1 if the current version is newer. versionSpec may be
	a string or an array. Example:
	if (0 < oolite.compareVersion("1.70"))  log("Old version of Oolite!")
	else  this.doStuffThatRequires170()
*/
namespace {
static bool OoliteCompareVersion(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	id						components = nil;
	NSEnumerator			*componentEnum = nil;
	id						component = nil;
	
	if (oojsArgs.count() == 0)  OOJS_RETURN_VOID;	// Backwards-compatibility: be overly lenient.
	
	components = OOJSNativeObjectFromJSValue(context, OOJS_ARGV[0]);
	if ([components isKindOfClass:[NSArray class]])
	{
		// Require each element to be a number
		for (componentEnum = [components objectEnumerator]; (component = [componentEnum nextObject]); )
		{
			if (![component isKindOfClass:[NSNumber class]])
			{
				components = nil;
				break;
			}
		}
	}
	else if ([components isKindOfClass:[NSString class]])
	{
		components = ComponentsFromVersionString(components);
	}
	else  components = nil;
	
	if (components != nil)
	{
		OOJS_RETURN_INT((int32_t)CompareVersions(components, VersionComponents()));
	}
	else
	{
		OOJS_RETURN_VOID;
	}
	
	OOJS_NATIVE_EXIT
}
} // namespace
