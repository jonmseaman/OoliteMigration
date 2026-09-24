/*

OOJSSound.mm

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

#import "OOJSSound.h"
#import "OOJavaScriptEngine.h"
#import "OOSound.h"
#import "OOMusicController.h"
#import "ResourceManager.h"
#import "Universe.h"
#import "OOFoundationBridge.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar): the class dispatch table becomes a static ooscript::ClassDef
	(the stub hooks are nullptr), InitClass becomes ooscript::initClass, and the directly
	spelled object-construction, private-storage and boolean-conversion calls become
	ooscript::newObject, ooscript::setPrivate and ooscript::valueToBoolean. `this` is renamed
	to `thisObj` because it is a reserved word once this file compiles as Objective-C++
	(ADR-0001).

	Natives and class hooks take the façade signature directly; the shared
	OOJSObjectWrapperToString, OOJSObjectWrapperFinalize and OOJSUnconstructableConstruct
	natives are used as-is in the class and method tables.
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
static ooscript::Object sSoundPrototype;
} // namespace


namespace {
static OOSound *GetNamedSound(const std::string &name);
} // namespace


namespace {
static bool SoundGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace

// Static methods
namespace {
static bool SoundStaticLoad(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SoundStaticMusicSoundSource(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SoundStaticPlayMusic(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SoundStaticStopMusic(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace


namespace {
static ClassDef sSoundClass =
{
	"Sound",
	ClassFlag::HasPrivate,
	
	nullptr,			// addProperty (engine default: PropertyStub)
	nullptr,			// delProperty (engine default: PropertyStub)
	SoundGetProperty,	// getProperty
	nullptr,			// setProperty (engine default: StrictPropertyStub)
	nullptr,			// enumerate (engine default: EnumerateStub)
	nullptr,			// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,			// resolve (engine default: ResolveStub)
	nullptr,			// convert (engine default: ConvertStub)
	OOJSObjectWrapperFinalize,		// finalize
	nullptr,			// call
	nullptr,			// construct
	nullptr,			// backend: owned by the façade backend, must start null
};
} // namespace


enum : std::uint8_t
{
	// Property IDs
	kSound_name
};


namespace {
static PropertySpec sSoundProperties[] =
{
	// JS name					ID							flags								getter	setter
	{ "name",					kSound_name,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared,	nullptr, nullptr },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sSoundMethods[] =
{
	// JS name					Function					min args
	{ "toString",				OOJSObjectWrapperToString,				0,	0, },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sSoundStaticMethods[] =
{
	// JS name					Function					min args
	{ "load",					SoundStaticLoad,			1,	0, },
	{ "musicSoundSource",		SoundStaticMusicSoundSource,0,	0, },
	{ "playMusic",				SoundStaticPlayMusic,		1,	0, },
	{ "stopMusic",				SoundStaticStopMusic,		0,	0, },
	{ 0 }
};
} // namespace


namespace {
DEFINE_JS_OBJECT_GETTER(JSSoundGetSound, &sSoundClass, sSoundPrototype, OOSound)
} // namespace


// *** Public ***

void InitOOJSSound(ooscript::Context context, ooscript::Object global)
{
	Object proto = ooscript::initClass((context), (global), nullptr, &sSoundClass,
										OOJSUnconstructableConstruct, 0, sSoundProperties, sSoundMethods,
										nullptr, sSoundStaticMethods);
	sSoundPrototype = (proto);
	OOJSRegisterObjectConverter(&sSoundClass, OOJSBasicPrivateObjectConverter);
}


OOSound *SoundFromJSValue(ooscript::Context context, ooscript::Value value)
{
	OOJS_PROFILE_ENTER
	
	OOJSPauseTimeLimiter();
	if ([PLAYER status] != STATUS_START_GAME && ooscript::isString(value))
	{
		return GetNamedSound(oo::StdString(OOStringFromJSValue(context, value)));
	}
	else
	{
		return OOJSNativeObjectOfClassFromJSValue(context, value, [OOSound class]);
	}
	OOJSResumeTimeLimiter();
	
	OOJS_PROFILE_EXIT
}


// *** Implementation stuff ***

namespace {
static bool SoundGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	
	OOJS_NATIVE_ENTER(context)
	
	OOSound						*sound = nil;
	
	if (EXPECT_NOT(!JSSoundGetSound(context, thisObj, &sound)))  return NO;
	
	switch (ooscript::idToInt32(propID))
	{
		case kSound_name:
			*value = OOJSValueFromNativeObject(context, [sound name]);
			return YES;
		
		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sSoundProperties);
			return NO;
	}
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static OOSound *GetNamedSound(const std::string &name)
{
	OOSound						*sound = nil;
	
	if (oo::str::hasPrefix(name, "[") && oo::str::hasSuffix(name, "]"))
	{
		sound = [OOSound soundWithCustomSoundKey:oo::NSStringFrom(name)];
	}
	else
	{
		sound = [ResourceManager ooSoundNamed:oo::NSStringFrom(name) inFolder:@"Sounds"];
	}
	
	return sound;
}
} // namespace


// *** Static methods ***

// load(name : String) : Sound
namespace {
static bool SoundStaticLoad(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	std::optional<std::string>	name;
	OOSound						*sound = nil;
	
	if (oojsArgs.count() > 0)  name = oo::OptionalString(OOStringFromJSValue(context, OOJS_ARGV[0]));
	if (!name.has_value())
	{
		OOJSReportBadArguments(context, @"Sound", @"load", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string");
		return NO;
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	sound = GetNamedSound(*name);
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_OBJECT(sound);
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool SoundStaticMusicSoundSource(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	OOSoundSource *musicSource = nil;
	OOJS_BEGIN_FULL_NATIVE(context)
	musicSource = [[OOMusicController sharedController] soundSource];
	OOJS_END_FULL_NATIVE
	OOJS_RETURN_OBJECT(musicSource);
	OOJS_NATIVE_EXIT
}
} // namespace


// playMusic(name : String [, loop : Boolean] [, gain : float])
namespace {
static bool SoundStaticPlayMusic(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	std::optional<std::string>	name;
	bool						loop = false;
	double						gain = OO_DEFAULT_SOUNDSOURCE_GAIN;
	
	if (oojsArgs.count() > 0)  name = oo::OptionalString(OOStringFromJSValue(context, OOJS_ARGV[0]));
	if (!name.has_value())
	{
		OOJSReportBadArguments(context, @"Sound", @"playMusic", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string");
		return NO;
	}
	if (oojsArgs.count() > 1)
	{
		if (!ooscript::valueToBoolean(context, (OOJS_ARGV[1]), &loop))
		{
			OOJSReportBadArguments(context, @"Sound", @"playMusic", 1, OOJS_ARGV + 1, nil, @"boolean");
			return NO;
		}
	}
	
	if (oojsArgs.count() > 2)
	{
		if (!OOJSArgumentListGetNumber(context, @"Sound", @"playMusic", 2, OOJS_ARGV + 2, &gain, NULL))
		{
			OOJSReportBadArguments(context, @"Sound", @"playMusic", 1, OOJS_ARGV + 2, nil, @"float");
			return NO;
		}
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	[[OOMusicController sharedController] playMusicNamed:*name loop:(loop ? YES : NO) gain:(float)gain];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// Sound.stopMusic([name : String])
namespace {
static bool SoundStaticStopMusic(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	std::optional<std::string>	name;
	
	if (oojsArgs.count() > 0)
	{
		name = oo::OptionalString(OOStringFromJSValue(context, OOJS_ARGV[0]));
		if (EXPECT_NOT(!name.has_value()))
		{
			OOJSReportBadArguments(context, @"Sound", @"stopMusic", oojsArgs.count(), OOJS_ARGV, nil, @"string or no argument");
			return NO;
		}
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	OOMusicController *controller = [OOMusicController sharedController];
	if (!name.has_value() || name == [controller playingMusic])
	{
		[[OOMusicController sharedController] stop];
	}
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


@implementation OOSound (OOJavaScriptExtentions)

- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context
{
	ooscript::Object jsSelf = NULL;
	ooscript::Value						result = ooscript::nullValue();
	
	jsSelf = (ooscript::newObject((context), &sSoundClass, (sSoundPrototype), nullptr));
	if (jsSelf != NULL)
	{
		if (!ooscript::setPrivate((context), (jsSelf), [self retain]))  jsSelf = NULL;
	}
	if (jsSelf != NULL)  result = ooscript::objectValue(jsSelf);
	
	return result;
}


- (id) oo_jsDescription	// shared selector (proposed ADR-0043)
{
	return oo::NSStringFrom(oo::str::format("[Sound \"%s\"]", oo::DescriptionOf([self name]).c_str()));
}


- (id) oo_jsClassName	// shared selector (proposed ADR-0043)
{
	return @"Sound";
}

@end
