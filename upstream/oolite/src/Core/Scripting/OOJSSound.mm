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

	Sound has its own private-object getter (originally built by DEFINE_JS_OBJECT_GETTER(),
	OOJavaScriptEngine.h) the way OOJSSoundSource.mm's JSSoundSourceGetSoundSource does,
	because the macro still speaks jsapi's JSClass*. RawSoundClass() below is a
	reinterpret_cast onto sSoundClass.backend, attached by ooscript::initClass() in
	InitOOJSSound(), not a conversion.

	toString() is a shared native (OOJSObjectWrapperToString) adapted to the façade's NativeFn
	signature exactly as OOJSSoundSource.mm's SoundSourceToString does. The unconstructable
	constructor (OOJSUnconstructableConstruct) is likewise a shared native, adapted the same
	way.
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

// Byte-identical façade <-> jsapi views, local to this call site (see OOJSVector.mm).
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
static inline Value      OOJSFVAL(jsval v)        { Value r; std::memcpy(&r, &v, sizeof r); return r; }
} // namespace
namespace {
static inline jsid       OOJSRJSID(PropertyId id) { jsid r; std::memcpy(&r, &id, sizeof r); return r; }
} // namespace


namespace {
static JSObject *sSoundPrototype;
} // namespace


namespace {
static OOSound *GetNamedSound(NSString *name);
} // namespace


namespace {
static bool SoundGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace

// Static methods
namespace {
static bool SoundStaticLoad(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool SoundStaticMusicSoundSource(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool SoundStaticPlayMusic(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool SoundStaticStopMusic(Context cx, CallArgs &oojsArgs);
} // namespace


// Adapts the shared jsapi finalizer (OOJavaScriptEngine.m) to the façade's FinalizeHook
// signature; the finalizer itself is untouched, shared plumbing outside this bead's scope
// (see OOJSSoundSource.mm's SoundSourceFinalize).
namespace {
static void SoundFinalize(Context cx, Object obj)
{
	OOJSObjectWrapperFinalize(OOJSRCX(cx), OOJSROBJ(obj));
}
} // namespace


// Adapts the shared jsapi unconstructable constructor (OOJavaScriptEngine.m) to the façade's
// NativeFn signature.
namespace {
static bool SoundUnconstructableConstruct(Context cx, CallArgs &oojsArgs)
{
	return OOJSUnconstructableConstruct(OOJSRCX(cx), oojsArgs.count(), OOJSRVAL(oojsArgs.rawVp()));
}
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
	nullptr,			// newEnumerate (JSCLASS_NEW_ENUMERATE not used)
	nullptr,			// resolve (engine default: ResolveStub)
	nullptr,			// convert (engine default: ConvertStub)
	SoundFinalize,		// finalize
	nullptr,			// call
	nullptr,			// construct
	nullptr,			// backend: owned by the façade backend, must start null
};
} // namespace


// The engine's own JSClass* for sSoundClass, for the not-yet-retargeted plumbing
// (OOJSObjectGetterImplPRIVATE, via the getter below, and OOJSRegisterObjectConverter) that
// still takes one; see OOJSSoundSource.mm's RawSoundSourceClass(). Valid only after
// InitOOJSSound() has called ooscript::initClass(), which is the only thing that attaches
// sSoundClass.backend.
namespace {
static inline JSClass *RawSoundClass(void)
{
	return reinterpret_cast<JSClass*>(sSoundClass.backend);
}
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


// A raw jsapi mirror of sSoundProperties, used only for the bad-property error reporter in
// OOJavaScriptEngine.m (OOJSReportBadPropertySelector): that helper is outside this bead's
// scope (shared across every binding file) and still takes a JSPropertySpec*, not
// ooscript::PropertySpec* (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static JSPropertySpec sSoundPropertiesRaw[] =
{
	{ "name",					kSound_name,				OOJS_PROP_READONLY_CB },
	{ 0 }
};
} // namespace


// Adapts the shared jsapi OOJSObjectWrapperToString (OOJavaScriptEngine.m) to the façade's
// NativeFn signature, the way OOJSSoundSource.mm's SoundSourceToString does.
namespace {
static bool SoundToString(Context cx, CallArgs &oojsArgs)
{
	return OOJSObjectWrapperToString(OOJSRCX(cx), oojsArgs.count(), OOJSRVAL(oojsArgs.rawVp()));
}
} // namespace


namespace {
static FunctionSpec sSoundMethods[] =
{
	// JS name					Function					min args
	{ "toString",				SoundToString,				0,	0, },
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


// Equivalent of DEFINE_JS_OBJECT_GETTER(JSSoundGetSound, &sSoundClass, sSoundPrototype,
// OOSound), hand-written because the macro (and the shared OOJSObjectGetterImplPRIVATE()
// helper it expands to) still take the engine's own JSClass* (see OOJSSoundSource.mm's
// JSSoundSourceGetSoundSource).
namespace {
#ifndef NDEBUG
static BOOL JSSoundGetSound(JSContext *context, JSObject *inObject, OOSound **outObject)  GCC_ATTR((unused));
static BOOL JSSoundGetSound(JSContext *context, JSObject *inObject, OOSound **outObject)
{
	NSCParameterAssert(outObject != NULL);
	static Class cls = Nil;
	if (EXPECT_NOT(cls == Nil))  cls = [OOSound class];
	return OOJSObjectGetterImplPRIVATE(context, inObject, RawSoundClass(), cls, "JSSoundGetSound", (id *)outObject);
}
#else
OOINLINE BOOL JSSoundGetSound(JSContext *context, JSObject *inObject, OOSound **outObject)
{
	return OOJSObjectGetterImplPRIVATE(context, inObject, RawSoundClass(), (id *)outObject);
}
#endif
} // namespace


// *** Public ***

void InitOOJSSound(JSContext *context, JSObject *global)
{
	Object proto = ooscript::initClass(OOJSFCX(context), OOJSFOBJ(global), nullptr, &sSoundClass,
										SoundUnconstructableConstruct, 0, sSoundProperties, sSoundMethods,
										nullptr, sSoundStaticMethods);
	sSoundPrototype = OOJSROBJ(proto);
	OOJSRegisterObjectConverter(RawSoundClass(), OOJSBasicPrivateObjectConverter);
}


OOSound *SoundFromJSValue(JSContext *context, jsval value)
{
	OOJS_PROFILE_ENTER
	
	OOJSPauseTimeLimiter();
	if ([PLAYER status] != STATUS_START_GAME && JSVAL_IS_STRING(value))
	{
		return GetNamedSound(OOStringFromJSValue(context, value));
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
	
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *value_raw = OOJSRVAL(value);
	
	OOJS_NATIVE_ENTER(context)
	
	OOSound						*sound = nil;
	
	if (EXPECT_NOT(!JSSoundGetSound(context, thisObj, &sound)))  return NO;
	
	switch (ooscript::idToInt32(propID))
	{
		case kSound_name:
			*value_raw = OOJSValueFromNativeObject(context, [sound name]);
			return YES;
		
		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sSoundPropertiesRaw);
			return NO;
	}
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static OOSound *GetNamedSound(NSString *name)
{
	OOSound						*sound = nil;
	
	if ([name hasPrefix:@"["] && [name hasSuffix:@"]"])
	{
		sound = [OOSound soundWithCustomSoundKey:name];
	}
	else
	{
		sound = [ResourceManager ooSoundNamed:name inFolder:@"Sounds"];
	}
	
	return sound;
}
} // namespace


// *** Static methods ***

// load(name : String) : Sound
namespace {
static bool SoundStaticLoad(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	unsigned argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	NSString					*name = nil;
	OOSound						*sound = nil;
	
	if (argc > 0)  name = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (name == nil)
	{
		OOJSReportBadArguments(context, @"Sound", @"load", MIN(argc, 1U), OOJS_ARGV, nil, @"string");
		return NO;
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	sound = GetNamedSound(name);
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_OBJECT(sound);
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool SoundStaticMusicSoundSource(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
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
static bool SoundStaticPlayMusic(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	unsigned argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	NSString					*name = nil;
	bool						loop = false;
	double						gain = OO_DEFAULT_SOUNDSOURCE_GAIN;
	
	if (argc > 0)  name = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (name == nil)
	{
		OOJSReportBadArguments(context, @"Sound", @"playMusic", MIN(argc, 1U), OOJS_ARGV, nil, @"string");
		return NO;
	}
	if (argc > 1)
	{
		if (!ooscript::valueToBoolean(cx, OOJSFVAL(OOJS_ARGV[1]), &loop))
		{
			OOJSReportBadArguments(context, @"Sound", @"playMusic", 1, OOJS_ARGV + 1, nil, @"boolean");
			return NO;
		}
	}
	
	if (argc > 2)
	{
		if (!OOJSArgumentListGetNumber(context, @"Sound", @"playMusic", 2, OOJS_ARGV + 2, &gain, NULL))
		{
			OOJSReportBadArguments(context, @"Sound", @"playMusic", 1, OOJS_ARGV + 2, nil, @"float");
			return NO;
		}
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	[[OOMusicController sharedController] playMusicNamed:name loop:(loop ? YES : NO) gain:(float)gain];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// Sound.stopMusic([name : String])
namespace {
static bool SoundStaticStopMusic(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	unsigned argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	NSString					*name = nil;
	
	if (argc > 0)
	{
		name = OOStringFromJSValue(context, OOJS_ARGV[0]);
		if (EXPECT_NOT(name == nil))
		{
			OOJSReportBadArguments(context, @"Sound", @"stopMusic", argc, OOJS_ARGV, nil, @"string or no argument");
			return NO;
		}
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	OOMusicController *controller = [OOMusicController sharedController];
	if (name == nil || [name isEqualToString:[controller playingMusic]])
	{
		[[OOMusicController sharedController] stop];
	}
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


@implementation OOSound (OOJavaScriptExtentions)

- (jsval) oo_jsValueInContext:(JSContext *)context
{
	JSObject					*jsSelf = NULL;
	jsval						result = JSVAL_NULL;
	
	jsSelf = OOJSROBJ(ooscript::newObject(OOJSFCX(context), &sSoundClass, OOJSFOBJ(sSoundPrototype), nullptr));
	if (jsSelf != NULL)
	{
		if (!ooscript::setPrivate(OOJSFCX(context), OOJSFOBJ(jsSelf), [self retain]))  jsSelf = NULL;
	}
	if (jsSelf != NULL)  result = OBJECT_TO_JSVAL(jsSelf);
	
	return result;
}


- (NSString *) oo_jsDescription
{
	return [NSString stringWithFormat:@"[Sound \"%@\"]", [self name]];
}


- (NSString *) oo_jsClassName
{
	return @"Sound";
}

@end
