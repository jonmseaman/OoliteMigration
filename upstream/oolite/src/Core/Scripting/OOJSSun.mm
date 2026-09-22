/*

OOJSSun.mm


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

#import "OOJSSun.h"
#import "OOJSEntity.h"
#import "OOJavaScriptEngine.h"

#import "OOSunEntity.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>
#include <cstdint>

// Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
// oo-sdz, exemplar): ClassDef replaces JSClass (stub hooks nullptr), initClass replaces
// InitClass, natives take the façade's Context/Object/PropertyId/Value/CallArgs signature.
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

namespace { static inline Context    OOJSFCX(JSContext *cx)   { return reinterpret_cast<Context>(cx); } }
namespace { static inline JSContext *OOJSRCX(Context cx)      { return reinterpret_cast<JSContext*>(cx); } }
namespace { static inline Object     OOJSFOBJ(JSObject *o)    { return reinterpret_cast<Object>(o); } }
namespace { static inline JSObject  *OOJSROBJ(Object o)       { return reinterpret_cast<JSObject*>(o); } }
namespace { static inline jsval     *OOJSRVAL(Value *v)       { return reinterpret_cast<jsval*>(v); } }
namespace { static inline Value      OOJSFVAL(jsval v)        { Value r; std::memcpy(&r, &v, sizeof r); return r; } }
namespace { static inline jsid       OOJSRJSID(PropertyId id) { jsid r; std::memcpy(&r, &id, sizeof r); return r; } }


namespace {
static JSObject		*sSunPrototype;
}


namespace {
static bool SunGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
static bool SunGoNova(Context cx, CallArgs &oojsArgs);
static bool SunCancelNova(Context cx, CallArgs &oojsArgs);
}

namespace {
static void SunFinalize(Context cx, Object obj)
{
	OOJSObjectWrapperFinalize(OOJSRCX(cx), OOJSROBJ(obj));
}
}

namespace {
static bool SunUnconstructableConstruct(Context cx, CallArgs &oojsArgs)
{
	return OOJSUnconstructableConstruct(OOJSRCX(cx), oojsArgs.count(), OOJSRVAL(oojsArgs.rawVp()));
}
}


namespace {
static ClassDef sSunClass =
{
	"Sun",
	ClassFlag::HasPrivate,
	
	nullptr,				// addProperty
	nullptr,				// delProperty
	SunGetProperty,			// getProperty
	nullptr,				// setProperty
	nullptr,				// enumerate
	nullptr,				// newEnumerate
	nullptr,				// resolve
	nullptr,				// convert
	SunFinalize,			// finalize
	nullptr,				// call
	nullptr,				// construct
	nullptr,				// backend
};
}


namespace {
static inline JSClass *RawSunClass(void)
{
	return reinterpret_cast<JSClass*>(sSunClass.backend);
}
}


enum : std::uint8_t
{
	// Property IDs
	kSun_radius,				// Radius of sun in metres, number, read-only
	kSun_hasGoneNova,			// Has sun gone nova, boolean, read-only
	kSun_isGoingNova,			// Will sun go nova, boolean, read-only
	kSun_name					// Name of sun, string, read-only (writable via systeminfo)
};


namespace {
static PropertySpec sSunProperties[] =
{
	// JS name					ID							flags														getter	setter
	{ "hasGoneNova",			kSun_hasGoneNova,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared,	nullptr, nullptr },
	{ "isGoingNova",			kSun_isGoingNova,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared,	nullptr, nullptr },
	{ "name",					kSun_name,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared,	nullptr, nullptr },
	{ "radius",					kSun_radius,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared,	nullptr, nullptr },
	{ 0 }
};
}


// A raw jsapi mirror of sSunProperties, used only by the bad-property error reporter in
// OOJavaScriptEngine.m (OOJSReportBadPropertySelector): that helper is shared across every
// binding file and still takes a JSPropertySpec*, not ooscript::PropertySpec* (see
// OOJSVector.mm's sVectorPropertiesRaw for the same pattern).
namespace {
static JSPropertySpec sSunPropertiesRaw[] =
{
	{ "hasGoneNova",			kSun_hasGoneNova,			OOJS_PROP_READONLY_CB },
	{ "isGoingNova",			kSun_isGoingNova,			OOJS_PROP_READONLY_CB },
	{ "name",					kSun_name,					OOJS_PROP_READONLY_CB },
	{ "radius",					kSun_radius,				OOJS_PROP_READONLY_CB },
	{ 0 }
};
}


namespace {
static FunctionSpec sSunMethods[] =
{
	// JS name					Function					min args	flags
	{ "cancelNova",				SunCancelNova,				0,			0 },
	{ "goNova",					SunGoNova,					1,			0 },
	{ 0 }
};
}


namespace {
DEFINE_JS_OBJECT_GETTER(JSSunGetSunEntity, RawSunClass(), sSunPrototype, OOSunEntity)
}


void InitOOJSSun(JSContext *context, JSObject *global)
{
	Object proto = ooscript::initClass(OOJSFCX(context), OOJSFOBJ(global), OOJSFOBJ(JSEntityPrototype()), &sSunClass, SunUnconstructableConstruct, 0, sSunProperties, sSunMethods, NULL, NULL);
	sSunPrototype = OOJSROBJ(proto);
	OOJSRegisterObjectConverter(RawSunClass(), OOJSBasicPrivateObjectConverter);
	OOJSRegisterSubclass(RawSunClass(), JSEntityClass());
}


@implementation OOSunEntity (OOJavaScriptExtensions)

- (BOOL) isVisibleToScripts
{
	return YES;
}


- (void)getJSClass:(JSClass **)outClass andPrototype:(JSObject **)outPrototype
{
	*outClass = RawSunClass();
	*outPrototype = sSunPrototype;
}


- (NSString *) oo_jsClassName
{
	return @"Sun";
}

@end


namespace {
static bool SunGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *jsValue = OOJSRVAL(value);
	
	OOJS_NATIVE_ENTER(context)
	
	OOSunEntity					*sun = nil;
	
	if (EXPECT_NOT(!JSSunGetSunEntity(context, thisObj, &sun)))  return NO;
	
	switch (ooscript::idToInt32(propID))
	{
		case kSun_radius:
			return ooscript::newNumberValue(cx, [sun radius], value);

		case kSun_name:
			*jsValue = OOJSValueFromNativeObject(context, [sun name]);
			return YES;
			
		case kSun_hasGoneNova:
			*jsValue = OOJSValueFromBOOL([sun goneNova]);
			return YES;
			
		case kSun_isGoingNova:
			*jsValue = OOJSValueFromBOOL([sun willGoNova] && ![sun goneNova]);
			return YES;
			
		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sSunPropertiesRaw);
			return NO;
	}
	
	OOJS_NATIVE_EXIT
}
}


// *** Methods ***

// goNova([delay : Number])
namespace {
static bool SunGoNova(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	OOSunEntity					*sun = nil;
	jsdouble					delay = 0;
	
	if (EXPECT_NOT(!JSSunGetSunEntity(context, OOJS_THIS, &sun)))  return NO;
	if (argc > 0 && EXPECT_NOT(!ooscript::valueToNumber(cx, OOJSFVAL(OOJS_ARGV[0]), &delay)))  return NO;
	
	[sun setGoingNova:YES inTime:delay];
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
}


// cancelNova()
namespace {
static bool SunCancelNova(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	OOSunEntity					*sun = nil;
	
	if (EXPECT_NOT(!JSSunGetSunEntity(context, OOJS_THIS, &sun)))  return NO;
	
	if ([sun willGoNova] && ![sun goneNova])
	{
		[sun setGoingNova:NO inTime:0];
	}
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
}
