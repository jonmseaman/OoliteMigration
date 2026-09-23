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
// oo-sdz, exemplar): a static ClassDef is the class table (stub hooks nullptr), initClass replaces
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


namespace {
static ooscript::Object sSunPrototype;
}


namespace {
static bool SunGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
static bool SunGoNova(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
static bool SunCancelNova(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
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
	OOJSObjectWrapperFinalize,	// finalize
	nullptr,				// call
	nullptr,				// construct
	nullptr,				// backend
};
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
DEFINE_JS_OBJECT_GETTER(JSSunGetSunEntity, &sSunClass, sSunPrototype, OOSunEntity)
}


void InitOOJSSun(ooscript::Context context, ooscript::Object global)
{
	Object proto = ooscript::initClass((context), (global), (JSEntityPrototype()), &sSunClass, OOJSUnconstructableConstruct, 0, sSunProperties, sSunMethods, NULL, NULL);
	sSunPrototype = (proto);
	OOJSRegisterObjectConverter(&sSunClass, OOJSBasicPrivateObjectConverter);
	OOJSRegisterSubclass(&sSunClass, JSEntityClass());
}


@implementation OOSunEntity (OOJavaScriptExtensions)

- (BOOL) isVisibleToScripts
{
	return YES;
}


- (void)getJSClass:(ooscript::ClassDef **)outClass andPrototype:(ooscript::Object *)outPrototype
{
	*outClass = &sSunClass;
	*outPrototype = sSunPrototype;
}


- (id) oo_jsClassName	// shared selector (proposed ADR-0043)
{
	return @"Sun";
}

@end


namespace {
static bool SunGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	
	OOJS_NATIVE_ENTER(context)
	
	OOSunEntity					*sun = nil;
	
	if (EXPECT_NOT(!JSSunGetSunEntity(context, thisObj, &sun)))  return NO;
	
	switch (ooscript::idToInt32(propID))
	{
		case kSun_radius:
			return ooscript::newNumberValue(cx, [sun radius], value);

		case kSun_name:
			*value = OOJSValueFromNativeObject(context, [sun name]);
			return YES;
			
		case kSun_hasGoneNova:
			*value = OOJSValueFromBOOL([sun goneNova]);
			return YES;
			
		case kSun_isGoingNova:
			*value = OOJSValueFromBOOL([sun willGoNova] && ![sun goneNova]);
			return YES;
			
		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sSunProperties);
			return NO;
	}
	
	OOJS_NATIVE_EXIT
}
}


// *** Methods ***

// goNova([delay : Number])
namespace {
static bool SunGoNova(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	OOSunEntity					*sun = nil;
	double					delay = 0;
	
	if (EXPECT_NOT(!JSSunGetSunEntity(context, OOJS_THIS, &sun)))  return NO;
	if (oojsArgs.count() > 0 && EXPECT_NOT(!ooscript::valueToNumber(context, (OOJS_ARGV[0]), &delay)))  return NO;
	
	[sun setGoingNova:YES inTime:delay];
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
}


// cancelNova()
namespace {
static bool SunCancelNova(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
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
