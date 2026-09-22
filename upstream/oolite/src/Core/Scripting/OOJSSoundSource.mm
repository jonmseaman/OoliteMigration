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

	SoundSource has its own private-object getter (originally built by
	DEFINE_JS_OBJECT_GETTER(), OOJavaScriptEngine.h) the way OOJSEquipmentInfo.mm's
	JSEquipmentInfoGetEquipmentType does, because the macro still speaks jsapi's JSClass*.
	RawSoundSourceClass() below is a reinterpret_cast onto sSoundSourceClass.backend, attached
	by ooscript::initClass() in InitOOJSSoundSource(), not a conversion.

	toString() is a shared native (OOJSObjectWrapperToString) adapted to the façade's NativeFn
	signature exactly as OOJSEquipmentInfo.mm's EquipmentInfoToString does.
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
static inline jsid       OOJSRJSID(PropertyId id) { jsid r; std::memcpy(&r, &id, sizeof r); return r; }
} // namespace
namespace {
static inline Value      OOJSFVAL(jsval v)        { Value r; std::memcpy(&r, &v, sizeof r); return r; }
} // namespace


namespace {
static JSObject *sSoundSourcePrototype;
} // namespace


namespace {
static bool SoundSourceGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool SoundSourceSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace
namespace {
static bool SoundSourceConstruct(Context cx, CallArgs &oojsArgs);
} // namespace

// Methods
namespace {
static bool SoundSourcePlay(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool SoundSourceStop(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool SoundSourcePlayOrRepeat(Context cx, CallArgs &oojsArgs);
} // namespace


// Adapts the shared jsapi finalizer (OOJavaScriptEngine.m) to the façade's FinalizeHook
// signature; the finalizer itself is untouched, shared plumbing outside this bead's scope
// (see OOJSWaypoint.mm's WaypointFinalize).
namespace {
static void SoundSourceFinalize(Context cx, Object obj)
{
	OOJSObjectWrapperFinalize(OOJSRCX(cx), OOJSROBJ(obj));
}
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
	nullptr,				// newEnumerate (JSCLASS_NEW_ENUMERATE not used)
	nullptr,				// resolve (engine default: ResolveStub)
	nullptr,				// convert (engine default: ConvertStub)
	SoundSourceFinalize,	// finalize
	nullptr,				// call
	nullptr,				// construct
	nullptr,				// backend: owned by the façade backend, must start null
};
} // namespace


// The engine's own JSClass* for sSoundSourceClass, for the not-yet-retargeted plumbing
// (OOJSObjectGetterImplPRIVATE, via the getter below, and OOJSRegisterObjectConverter) that
// still takes one; see the file-top comment and OOJSWaypoint.mm's RawWaypointClass(). Valid
// only after InitOOJSSoundSource() has called ooscript::initClass(), which is the only thing
// that attaches sSoundSourceClass.backend.
namespace {
static inline JSClass *RawSoundSourceClass(void)
{
	return reinterpret_cast<JSClass*>(sSoundSourceClass.backend);
}
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


// A raw jsapi mirror of sSoundSourceProperties, used only for the two bad-property error
// reporters in OOJavaScriptEngine.m (OOJSReportBadPropertySelector/Value): those helpers are
// outside this bead's scope (shared across every binding file) and still take a
// JSPropertySpec*, not ooscript::PropertySpec* (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static JSPropertySpec sSoundSourcePropertiesRaw[] =
{
	// JS name					ID							flags
	{ "isPlaying",				kSoundSource_isPlaying,		OOJS_PROP_READONLY_CB },
	{ "loop",					kSoundSource_loop,			OOJS_PROP_READWRITE_CB },
	{ "position",				kSoundSource_position,		OOJS_PROP_READWRITE_CB },
	{ "positional",				kSoundSource_positional,	OOJS_PROP_READWRITE_CB },
	{ "repeatCount",			kSoundSource_repeatCount,	OOJS_PROP_READWRITE_CB },
	{ "sound",					kSoundSource_sound,			OOJS_PROP_READWRITE_CB },
	{ "volume",					kSoundSource_volume,		OOJS_PROP_READWRITE_CB },
	{ 0 }
};
} // namespace


// Adapts the shared jsapi OOJSObjectWrapperToString (OOJavaScriptEngine.m) to the façade's
// NativeFn signature, the way OOJSEquipmentInfo.mm's EquipmentInfoToString does.
namespace {
static bool SoundSourceToString(Context cx, CallArgs &oojsArgs)
{
	return OOJSObjectWrapperToString(OOJSRCX(cx), oojsArgs.count(), OOJSRVAL(oojsArgs.rawVp()));
}
} // namespace


namespace {
static FunctionSpec sSoundSourceMethods[] =
{
	// JS name					Function					min args	flags
	{ "toString",				SoundSourceToString,		0,			0 },
	{ "play",					SoundSourcePlay,			0,			0 },
	{ "playOrRepeat",			SoundSourcePlayOrRepeat,	0,			0 },
	// playSound is defined in oolite-global-prefix.js.
	{ "stop",					SoundSourceStop,			0,			0 },
	{ 0 }
};
} // namespace


// Equivalent of DEFINE_JS_OBJECT_GETTER(JSSoundSourceGetSoundSource, &sSoundSourceClass,
// sSoundSourcePrototype, OOSoundSource), hand-written because the macro (and the shared
// OOJSObjectGetterImplPRIVATE() helper it expands to) still take the engine's own JSClass*
// (see the file-top comment and OOJSEquipmentInfo.mm's JSEquipmentInfoGetEquipmentType).
namespace {
#ifndef NDEBUG
static BOOL JSSoundSourceGetSoundSource(JSContext *context, JSObject *inObject, OOSoundSource **outObject)  GCC_ATTR((unused));
static BOOL JSSoundSourceGetSoundSource(JSContext *context, JSObject *inObject, OOSoundSource **outObject)
{
	NSCParameterAssert(outObject != NULL);
	static Class cls = Nil;
	if (EXPECT_NOT(cls == Nil))  cls = [OOSoundSource class];
	return OOJSObjectGetterImplPRIVATE(context, inObject, RawSoundSourceClass(), cls, "JSSoundSourceGetSoundSource", (id *)outObject);
}
#else
OOINLINE BOOL JSSoundSourceGetSoundSource(JSContext *context, JSObject *inObject, OOSoundSource **outObject)
{
	return OOJSObjectGetterImplPRIVATE(context, inObject, RawSoundSourceClass(), (id *)outObject);
}
#endif
} // namespace


// *** Public ***

void InitOOJSSoundSource(JSContext *context, JSObject *global)
{
	Object proto = ooscript::initClass(OOJSFCX(context), OOJSFOBJ(global), nullptr, &sSoundSourceClass, SoundSourceConstruct, 0, sSoundSourceProperties, sSoundSourceMethods, nullptr, nullptr);
	sSoundSourcePrototype = OOJSROBJ(proto);
	OOJSRegisterObjectConverter(RawSoundSourceClass(), OOJSBasicPrivateObjectConverter);
}


namespace {
static bool SoundSourceConstruct(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

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

	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *value_raw = OOJSRVAL(value);

	OOJS_NATIVE_ENTER(context)

	OOSoundSource				*soundSource = nil;

	if (!JSSoundSourceGetSoundSource(context, thisObj, &soundSource))  return NO;

	switch (ooscript::idToInt32(propID))
	{
		case kSoundSource_sound:
			*value_raw = OOJSValueFromNativeObject(context, [soundSource sound]);
			return YES;

		case kSoundSource_isPlaying:
			*value_raw = OOJSValueFromBOOL([soundSource isPlaying]);
			return YES;

		case kSoundSource_loop:
			*value_raw = OOJSValueFromBOOL([soundSource loop]);
			return YES;

		case kSoundSource_repeatCount:
			*value_raw = INT_TO_JSVAL([soundSource repeatCount]);
			return YES;

		case kSoundSource_position:
			return VectorToJSValue(context, [soundSource position], value_raw);

		case kSoundSource_positional:
			*value_raw = OOJSValueFromBOOL([soundSource positional]);
			return YES;

		case kSoundSource_volume:
			return ooscript::newNumberValue(cx, [soundSource gain], value);


		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sSoundSourcePropertiesRaw);
			return NO;
	}

	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool SoundSourceSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;

	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *value_raw = OOJSRVAL(value);

	OOJS_NATIVE_ENTER(context)

	OOSoundSource				*soundSource = nil;
	int32						iValue;
	bool						bValue;
	Vector						vValue;
	double						fValue;

	if (!JSSoundSourceGetSoundSource(context, thisObj, &soundSource)) return NO;

	switch (ooscript::idToInt32(propID))
	{
		case kSoundSource_sound:
			[soundSource setSound:SoundFromJSValue(context, *value_raw)];
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
			if (JSValueToVector(context, *value_raw, &vValue))
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
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sSoundSourcePropertiesRaw);
			return NO;
	}

	OOJSReportBadPropertyValue(context, thisObj, OOJSRJSID(propID), sSoundSourcePropertiesRaw, *value_raw);
	return NO;

	OOJS_NATIVE_EXIT
}
} // namespace


// *** Methods ***

// play([count : Number])
namespace {
static bool SoundSourcePlay(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	unsigned argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	OOJS_NATIVE_ENTER(context)

	OOSoundSource			*thisv = nil;
	int32					count = 0;

	if (EXPECT_NOT(!JSSoundSourceGetSoundSource(context, OOJS_THIS, &thisv)))  return NO;
	if (argc > 0 && !JSVAL_IS_VOID(OOJS_ARGV[0]) && !ooscript::valueToInt32(cx, OOJSFVAL(OOJS_ARGV[0]), &count))
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
static bool SoundSourceStop(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

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
static bool SoundSourcePlayOrRepeat(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

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

- (jsval) oo_jsValueInContext:(JSContext *)context
{
	JSObject					*jsSelf = NULL;
	jsval						result = JSVAL_NULL;

	jsSelf = OOJSROBJ(ooscript::newObject(OOJSFCX(context), &sSoundSourceClass, OOJSFOBJ(sSoundSourcePrototype), nullptr));
	if (jsSelf != NULL)
	{
		if (!ooscript::setPrivate(OOJSFCX(context), OOJSFOBJ(jsSelf), [self retain]))  jsSelf = NULL;
	}
	if (jsSelf != NULL)  result = OBJECT_TO_JSVAL(jsSelf);

	return result;
}


- (NSString *) oo_jsClassName
{
	return @"SoundSource";
}

@end
