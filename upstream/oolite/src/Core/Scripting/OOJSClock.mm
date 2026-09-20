/*

OOJSClock.mm


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

#import "OOJSClock.h"
#import "OOJavaScriptEngine.h"
#import "Universe.h"
#import "OOJSPlayer.h"
#import "PlayerEntity.h"
#import "PlayerEntityScriptMethods.h"
#import "OOStringParsing.h"
#import "OODebugStandards.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar): the class dispatch table becomes a static ooscript::ClassDef
	(the stub hooks are nullptr), InitClass becomes ooscript::initClass, the engine's
	DefineObject call becomes ooscript::defineObject, and the directly spelled numeric-conversion call becomes
	ooscript::newNumberValue. `this` is renamed to `thisObj` because it is a reserved word once
	this file compiles as Objective-C++ (ADR-0001). The OOJS_* argument-marshalling macros
	(OOJS_NATIVE_ENTER, OOJS_ARGV, OOJS_RETURN_*) are unchanged, byte-identical façade views as
	in OOJSVector.mm.
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
static inline Value      OOJSFVAL(jsval v)        { Value r; std::memcpy(&r, &v, sizeof r); return r; }
} // namespace
namespace {
static inline jsid       OOJSRJSID(PropertyId id) { jsid r; std::memcpy(&r, &id, sizeof r); return r; }
} // namespace


namespace {
static bool ClockGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace

// Adapts the shared jsapi OOJSUnconstructableConstruct (OOJavaScriptEngine.m) to the façade's
// NativeFn signature, the way OOJSWaypoint.mm's WaypointUnconstructableConstruct does it.
namespace {
static bool OOJSUnconstructableConstructFacade(Context cx, CallArgs &oojsArgs);
} // namespace

// Methods
namespace {
static bool JSClockToString(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool ClockClockStringForTime(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool ClockAddSeconds(Context cx, CallArgs &oojsArgs);
} // namespace


namespace {
static ClassDef sClockClass =
{
	"Clock",
	ClassFlag::HasPrivate,

	nullptr,			// addProperty (engine default: PropertyStub)
	nullptr,			// delProperty (engine default: PropertyStub)
	ClockGetProperty,	// getProperty
	nullptr,			// setProperty (engine default: StrictPropertyStub)
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


enum : std::uint8_t
{
	// Property IDs
	kClock_absoluteSeconds,		// game real time clock, double, read-only
	kClock_seconds,				// game clock time, double, read-only
	kClock_minutes,				// game clock time minutes (rounded down), integer double, read-only
	kClock_hours,				// game clock time hours (rounded down), integer double, read-only
	kClock_days,				// game clock time days (rounded down), int, read-only
	kClock_secondsComponent,	// second component of game clock time, double, read-only
	kClock_minutesComponent,	// minute component of game clock time (rounded down), int, read-only
	kClock_hoursComponent,		// hour component of game clock time (rounded down), int, read-only
	kClock_daysComponent,		// day component of game clock time (rounded down), int, read-only
	kClock_clockString,			// game clock time as display string, string, read-only
	kClock_isAdjusting,			// clock is adjusting, boolean, read-only
	kClock_adjustedSeconds,	// game clock time, including adjustments, double, read-only
	kClock_legacy_scriptTimer	// legacy scriptTimer_number, double, read-only
};


// A raw jsapi mirror of the property table, used only for the property-selector error reporter
// in OOJavaScriptEngine.m (OOJSReportBadPropertySelector): that helper is outside this bead's
// scope (shared across every binding file) and still takes a JSPropertySpec*, not
// ooscript::PropertySpec* (see OOJSVector.mm's sVectorPropertiesRaw). Clock has no
// ooscript::PropertySpec table of its own -- InitOOJSClock() uses ooscript::defineObject(),
// which takes no property table -- so this mirror exists solely for that error reporter.
namespace {
static JSPropertySpec sClockProperties[] =
{
	// JS name					ID							flags
	{ "absoluteSeconds",		kClock_absoluteSeconds,		OOJS_PROP_READONLY_CB },
	{ "seconds",				kClock_seconds,				OOJS_PROP_READONLY_CB },
	{ "minutes",				kClock_minutes,				OOJS_PROP_READONLY_CB },
	{ "hours",					kClock_hours,				OOJS_PROP_READONLY_CB },
	{ "days",					kClock_days,				OOJS_PROP_READONLY_CB },
	{ "secondsComponent",		kClock_secondsComponent,	OOJS_PROP_READONLY_CB },
	{ "minutesComponent",		kClock_minutesComponent,	OOJS_PROP_READONLY_CB },
	{ "hoursComponent",			kClock_hoursComponent,		OOJS_PROP_READONLY_CB },
	{ "daysComponent",			kClock_daysComponent,		OOJS_PROP_READONLY_CB },
	{ "clockString",			kClock_clockString,			OOJS_PROP_READONLY_CB },
	{ "isAdjusting",			kClock_isAdjusting,			OOJS_PROP_READONLY_CB },
	{ "adjustedSeconds",			kClock_adjustedSeconds,			OOJS_PROP_READONLY_CB },
	{ "legacy_scriptTimer",		kClock_legacy_scriptTimer,	OOJS_PROP_READONLY_CB },
	{ 0 }
};
} // namespace


namespace {
constexpr PropertyFlag kClockPropertyFlags = PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared;
} // namespace


namespace {
static PropertySpec sClockPropertiesFacade[] =
{
	// JS name					ID							flags					getter	setter
	{ "absoluteSeconds",		kClock_absoluteSeconds,		kClockPropertyFlags,	nullptr, nullptr },
	{ "seconds",				kClock_seconds,				kClockPropertyFlags,	nullptr, nullptr },
	{ "minutes",				kClock_minutes,				kClockPropertyFlags,	nullptr, nullptr },
	{ "hours",					kClock_hours,				kClockPropertyFlags,	nullptr, nullptr },
	{ "days",					kClock_days,				kClockPropertyFlags,	nullptr, nullptr },
	{ "secondsComponent",		kClock_secondsComponent,	kClockPropertyFlags,	nullptr, nullptr },
	{ "minutesComponent",		kClock_minutesComponent,	kClockPropertyFlags,	nullptr, nullptr },
	{ "hoursComponent",			kClock_hoursComponent,		kClockPropertyFlags,	nullptr, nullptr },
	{ "daysComponent",			kClock_daysComponent,		kClockPropertyFlags,	nullptr, nullptr },
	{ "clockString",			kClock_clockString,			kClockPropertyFlags,	nullptr, nullptr },
	{ "isAdjusting",			kClock_isAdjusting,			kClockPropertyFlags,	nullptr, nullptr },
	{ "adjustedSeconds",			kClock_adjustedSeconds,			kClockPropertyFlags,	nullptr, nullptr },
	{ "legacy_scriptTimer",		kClock_legacy_scriptTimer,	kClockPropertyFlags,	nullptr, nullptr },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sClockMethods[] =
{
	// JS name						Function						min args
	{ "toString",				JSClockToString,			0 },
	{ "clockStringForTime",		ClockClockStringForTime,	1 },
	{ "addSeconds",				ClockAddSeconds,			1 },
	{ 0 }
};
} // namespace


namespace {
constexpr PropertyFlag kClockObjectFlags = PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly;
} // namespace


void InitOOJSClock(JSContext *context, JSObject *global)
{
	Object clockPrototype = ooscript::initClass(OOJSFCX(context), OOJSFOBJ(global), nullptr, &sClockClass, OOJSUnconstructableConstructFacade, 0, sClockPropertiesFacade, sClockMethods, nullptr, nullptr);
	ooscript::defineObject(OOJSFCX(context), OOJSFOBJ(global), "clock", &sClockClass, clockPrototype, kClockObjectFlags);
}


namespace {
static bool OOJSUnconstructableConstructFacade(Context cx, CallArgs &oojsArgs)
{
	return OOJSUnconstructableConstruct(OOJSRCX(cx), oojsArgs.count(), reinterpret_cast<jsval*>(oojsArgs.rawVp()));
}
} // namespace


namespace {
static bool ClockGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;

	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);

	OOJS_NATIVE_ENTER(context)

	PlayerEntity				*player = OOPlayerForScripting();
	double						clockTime;

	clockTime = [player clockTime];

	switch (ooscript::idToInt32(propID))
	{
		case kClock_absoluteSeconds:
			return ooscript::newNumberValue(cx, [UNIVERSE getTime], value);

		case kClock_seconds:
			return ooscript::newNumberValue(cx, clockTime, value);

		case kClock_minutes:
			return ooscript::newNumberValue(cx, floor(clockTime / 60.0), value);

		case kClock_hours:
			return ooscript::newNumberValue(cx, floor(clockTime /3600.0), value);

		case kClock_secondsComponent:
			*reinterpret_cast<jsval*>(value) = INT_TO_JSVAL(fmod(clockTime, 60.0));
			return YES;

		case kClock_minutesComponent:
			*reinterpret_cast<jsval*>(value) = INT_TO_JSVAL(fmod(floor(clockTime / 60.0), 60.0));
			return YES;

		case kClock_hoursComponent:
			*reinterpret_cast<jsval*>(value) = INT_TO_JSVAL(fmod(floor(clockTime / 3600.0), 24.0));
			return YES;

		case kClock_days:
		case kClock_daysComponent:
			*reinterpret_cast<jsval*>(value) = INT_TO_JSVAL(floor(clockTime / 86400.0));
			return YES;

		case kClock_clockString:
			*reinterpret_cast<jsval*>(value) = OOJSValueFromNativeObject(context, [player dial_clock]);
			return YES;

		case kClock_isAdjusting:
			*reinterpret_cast<jsval*>(value) = OOJSValueFromBOOL([player clockAdjusting]);
			return YES;

		case kClock_adjustedSeconds:
			return ooscript::newNumberValue(cx, [player clockTimeAdjusted], value);

		case kClock_legacy_scriptTimer:
			OOStandardsDeprecated(@"The legacy_scriptTimer property is deprecated");
			return ooscript::newNumberValue(cx, [player scriptTimer], value);

		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sClockProperties);
			return NO;
	}

	OOJS_NATIVE_EXIT
}
} // namespace


// *** Methods ***

// toString() : String
namespace {
static bool JSClockToString(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = reinterpret_cast<jsval*>(oojsArgs.rawVp());

	OOJS_NATIVE_ENTER(context)

	OOJS_RETURN_OBJECT([OOPlayerForScripting() dial_clock]);

	OOJS_NATIVE_EXIT
}
} // namespace


// clockStringForTime(time : Number) : String
namespace {
static bool ClockClockStringForTime(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = reinterpret_cast<jsval*>(oojsArgs.rawVp());

	OOJS_NATIVE_ENTER(context)

	double						time;

	if (EXPECT_NOT(argc < 1 || !ooscript::valueToNumber(cx, OOJSFVAL(OOJS_ARGV[0]), &time)))
	{
		jsval arg = JSVAL_VOID;
		if (argc > 0)  arg = OOJS_ARGV[0];
		OOJSReportBadArguments(context, @"Clock", @"clockStringForTime", 1, &arg, nil, @"number");
		return NO;
	}

	OOJS_RETURN_OBJECT(ClockToString(time, NO));

	OOJS_NATIVE_EXIT
}
} // namespace


// addSeconds(seconds : Number) : String
namespace {
static bool ClockAddSeconds(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = reinterpret_cast<jsval*>(oojsArgs.rawVp());

	OOJS_NATIVE_ENTER(context)

	double						time;
	const double				kMaxTime = 30.0 * 24.0 * 3600.0;	// 30 days

	if (EXPECT_NOT(argc < 1 || !ooscript::valueToNumber(cx, OOJSFVAL(OOJS_ARGV[0]), &time)))
	{
		jsval arg = JSVAL_VOID;
		if (argc > 0)  arg = OOJS_ARGV[0];
		OOJSReportBadArguments(context, @"Clock", @"addSeconds", 1, &arg, nil, @"number");
		return NO;
	}

	if (time > kMaxTime || time < 1.0 || !isfinite(time))
	{
		OOJS_RETURN_BOOL(NO);
	}

	[OOPlayerForScripting() addToAdjustTime:time];

	OOJS_RETURN_BOOL(YES);

	OOJS_NATIVE_EXIT
}
} // namespace
