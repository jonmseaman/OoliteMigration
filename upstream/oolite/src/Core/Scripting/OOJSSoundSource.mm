/*

OOJSSoundSource.mm

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

#import "OOJSSoundSource.h"
#import "OOJSSound.h"
#import "OOJSVector.h"
#import "OOJavaScriptEngine.h"
#import "OOSound.h"
#import "ResourceManager.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar): the class dispatch table becomes a static ooscript::ClassDef
	(the stub hooks are nullptr), InitClass becomes ooscript::initClass, and the directly
	spelled construction-check, object-construction, private-storage and boolean/integer/
	numeric-conversion calls become ooscript::isConstructing (via CallArgs), ooscript::newObject,
	ooscript::setPrivate, ooscript::valueToBoolean, ooscript::valueToInt32 and
	ooscript::newNumberValue/valueToNumber. `this` is renamed to `thisObj` because it is a
	reserved word once this file compiles as Objective-C++ (ADR-0001).

	Natives and class hooks take the façade signature directly; the shared
	OOJSObjectWrapperToString and OOJSObjectWrapperFinalize natives are used as-is in the class
	and method tables.
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


namespace {
static ooscript::Object sSoundSourcePrototype;
} // namespace


namespace {
static bool SoundSourceGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool SoundSourceSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace
namespace {
static bool SoundSourceConstruct(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace

// Methods
namespace {
static bool SoundSourcePlay(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SoundSourceStop(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SoundSourcePlayOrRepeat(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace


namespace {
static ClassDef sSoundSourceClass =
{
	"SoundSource",
	ClassFlag::HasPrivate,

	nullptr,				// addProperty (engine default: PropertyStub)
	nullptr,				// delProperty (engine default: PropertyStub)
	SoundSourceGetProperty,	// getProperty
	SoundSourceSetProperty,	// setProperty
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


enum : std::uint8_t
{
	// Property IDs
	kSoundSource_sound,
	kSoundSource_isPlaying,
	kSoundSource_loop,
	kSoundSource_position,
	kSoundSource_positional,
	kSoundSource_repeatCount,
	kSoundSource_volume
};


namespace {
static PropertySpec sSoundSourceProperties[] =
{
	// JS name					ID							flags								getter	setter
	{ "isPlaying",				kSoundSource_isPlaying,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "loop",					kSoundSource_loop,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "position",				kSoundSource_position,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "positional",				kSoundSource_positional,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "repeatCount",			kSoundSource_repeatCount,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "sound",					kSoundSource_sound,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "volume",					kSoundSource_volume,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sSoundSourceMethods[] =
{
	// JS name					Function					min args	flags
	{ "toString",				OOJSObjectWrapperToString,		0,			0 },
	{ "play",					SoundSourcePlay,			0,			0 },
	{ "playOrRepeat",			SoundSourcePlayOrRepeat,	0,			0 },
	// playSound is defined in oolite-global-prefix.js.
	{ "stop",					SoundSourceStop,			0,			0 },
	{ 0 }
};
} // namespace


namespace {
DEFINE_JS_OBJECT_GETTER(JSSoundSourceGetSoundSource, &sSoundSourceClass, sSoundSourcePrototype, OOSoundSource)
} // namespace


// *** Public ***

void InitOOJSSoundSource(ooscript::Context context, ooscript::Object global)
{
	Object proto = ooscript::initClass((context), (global), nullptr, &sSoundSourceClass, SoundSourceConstruct, 0, sSoundSourceProperties, sSoundSourceMethods, nullptr, nullptr);
	sSoundSourcePrototype = (proto);
	OOJSRegisterObjectConverter(&sSoundSourceClass, OOJSBasicPrivateObjectConverter);
}


namespace {
static bool SoundSourceConstruct(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)

	if (EXPECT_NOT(!oojsArgs.isConstructing()))
	{
		OOJSReportError(context, @"SoundSource() cannot be called as a function, it must be used as a constructor (as in new SoundSource()).");
		return NO;
	}

	OOJS_RETURN_OBJECT([[[OOSoundSource alloc] init] autorelease]);

	OOJS_NATIVE_EXIT
}
} // namespace


// *** Implementation stuff ***

namespace {
static bool SoundSourceGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;

	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);

	OOJS_NATIVE_ENTER(context)

	OOSoundSource				*soundSource = nil;

	if (!JSSoundSourceGetSoundSource(context, thisObj, &soundSource))  return NO;

	switch (ooscript::idToInt32(propID))
	{
		case kSoundSource_sound:
			*value = OOJSValueFromNativeObject(context, [soundSource sound]);
			return YES;

		case kSoundSource_isPlaying:
			*value = OOJSValueFromBOOL([soundSource isPlaying]);
			return YES;

		case kSoundSource_loop:
			*value = OOJSValueFromBOOL([soundSource loop]);
			return YES;

		case kSoundSource_repeatCount:
			*value = ooscript::int32Value([soundSource repeatCount]);
			return YES;

		case kSoundSource_position:
			return VectorToJSValue(context, [soundSource position], value);

		case kSoundSource_positional:
			*value = OOJSValueFromBOOL([soundSource positional]);
			return YES;

		case kSoundSource_volume:
			return ooscript::newNumberValue(cx, [soundSource gain], value);


		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sSoundSourceProperties);
			return NO;
	}

	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool SoundSourceSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;

	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);

	OOJS_NATIVE_ENTER(context)

	OOSoundSource				*soundSource = nil;
	int32_t						iValue;
	bool						bValue;
	Vector						vValue;
	double						fValue;

	if (!JSSoundSourceGetSoundSource(context, thisObj, &soundSource)) return NO;

	switch (ooscript::idToInt32(propID))
	{
		case kSoundSource_sound:
			[soundSource setSound:SoundFromJSValue(context, *value)];
			return YES;
			break;

		case kSoundSource_loop:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[soundSource setLoop:bValue];
				return YES;
			}
			break;

		case kSoundSource_repeatCount:
			if (ooscript::valueToInt32(cx, *value, &iValue))
			{
				if (iValue > 100)  iValue = 100;
				if (100 < 1)  iValue = 1;
				[soundSource setRepeatCount:iValue];
				return YES;
			}
			break;


		case kSoundSource_position:
			if (JSValueToVector(context, *value, &vValue))
			{
				[soundSource setPosition:vValue];
				return YES;
			}
			break;

		case kSoundSource_positional:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[soundSource setPositional:bValue];
				return YES;
			}
			break;

		case kSoundSource_volume:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				fValue = OOClamp_0_max_d(fValue, 1);
				[soundSource setGain:fValue];
				return YES;
			}
			break;

		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sSoundSourceProperties);
			return NO;
	}

	OOJSReportBadPropertyValue(context, thisObj, (propID), sSoundSourceProperties, *value);
	return NO;

	OOJS_NATIVE_EXIT
}
} // namespace


// *** Methods ***

// play([count : Number])
namespace {
static bool SoundSourcePlay(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)

	OOSoundSource			*thisv = nil;
	int32_t					count = 0;

	if (EXPECT_NOT(!JSSoundSourceGetSoundSource(context, OOJS_THIS, &thisv)))  return NO;
	if (oojsArgs.count() > 0 && !ooscript::isUndefined(OOJS_ARGV[0]) && !ooscript::valueToInt32(context, (OOJS_ARGV[0]), &count))
	{
		OOJSReportBadArguments(context, @"SoundSource", @"play", 1, OOJS_ARGV, nil, @"integer count or no argument");
		return NO;
	}

	if (count > 0)
	{
		if (count > 100)  count = 100;
		[thisv setRepeatCount:count];
	}

	OOJS_BEGIN_FULL_NATIVE(context)
	[thisv play];
	OOJS_END_FULL_NATIVE

	OOJS_RETURN_VOID;

	OOJS_NATIVE_EXIT
}
} // namespace


// stop()
namespace {
static bool SoundSourceStop(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)

	OOSoundSource			*thisv = nil;

	if (EXPECT_NOT(!JSSoundSourceGetSoundSource(context, OOJS_THIS, &thisv)))  return NO;

	OOJS_BEGIN_FULL_NATIVE(context)
	[thisv stop];
	OOJS_END_FULL_NATIVE

	OOJS_RETURN_VOID;

	OOJS_NATIVE_EXIT
}
} // namespace


// playOrRepeat()
namespace {
static bool SoundSourcePlayOrRepeat(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)

	OOSoundSource			*thisv = nil;

	if (EXPECT_NOT(!JSSoundSourceGetSoundSource(context, OOJS_THIS, &thisv)))  return NO;

	OOJS_BEGIN_FULL_NATIVE(context)
	[thisv playOrRepeat];
	OOJS_END_FULL_NATIVE

	OOJS_RETURN_VOID;

	OOJS_NATIVE_EXIT
}
} // namespace


@implementation OOSoundSource (OOJavaScriptExtentions)

- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context
{
	ooscript::Object jsSelf = NULL;
	ooscript::Value						result = ooscript::nullValue();

	jsSelf = (ooscript::newObject((context), &sSoundSourceClass, (sSoundSourcePrototype), nullptr));
	if (jsSelf != NULL)
	{
		if (!ooscript::setPrivate((context), (jsSelf), [self retain]))  jsSelf = NULL;
	}
	if (jsSelf != NULL)  result = ooscript::objectValue(jsSelf);

	return result;
}


- (id) oo_jsClassName	// shared selector (proposed ADR-0043)
{
	return @"SoundSource";
}

@end
