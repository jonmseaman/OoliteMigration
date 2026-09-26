/*
OOJSExhaustPlume.m

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

#import "OOExhaustPlumeEntity.h"
#import "OOJSExhaustPlume.h"
#import "OOJSEntity.h"
#import "OOJSVector.h"
#import "OOJavaScriptEngine.h"
#import "EntityOOJavaScriptExtensions.h"
#import "ShipEntity.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>
#include <cstdint>

/*
	Retargeted onto the ooscript facade (JSEngine.hpp) the way OOJSVector.mm and
	OOJSWaypoint.mm do it (bead oo-sdz, the sweep exemplar): the class dispatch table is a
	static ooscript::ClassDef (the stub hooks are nullptr), and the property getter/setter
	and native methods take the facade's own signatures (ooscript::Context / Object /
	PropertyId / Value pointer / CallArgs reference) directly. The shared OOJavaScriptEngine
	helpers (OOJSObjectWrapperFinalize, OOJSUnconstructableConstruct, OOJSRegisterSubclass,
	OOJSRegisterObjectConverter) are used as the class's hooks and registrations with
	&sExhaustPlumeClass itself. `this` is renamed to `thisObj` because it is a reserved word
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

namespace {
static ooscript::Object sExhaustPlumePrototype;
} // namespace


namespace {
static BOOL JSExhaustPlumeGetExhaustPlumeEntity(ooscript::Context context, ooscript::Object jsobj, OOExhaustPlumeEntity **outEntity);
} // namespace


namespace {
static bool ExhaustPlumeGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool ExhaustPlumeSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace

namespace {
static bool ExhaustPlumeRemove(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace


namespace {
static ClassDef sExhaustPlumeClass =
{
	"ExhaustPlume",
	ClassFlag::HasPrivate,

	nullptr,			// addProperty (engine default: PropertyStub)
	nullptr,			// delProperty (engine default: PropertyStub)
	ExhaustPlumeGetProperty,	// getProperty
	ExhaustPlumeSetProperty,	// setProperty
	nullptr,			// enumerate (engine default: EnumerateStub)
	nullptr,			// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,			// resolve (engine default: ResolveStub)
	nullptr,			// convert (engine default: ConvertStub)
	OOJSObjectWrapperFinalize,	// finalize
	nullptr,			// call
	nullptr,			// construct
	nullptr,			// backend: owned by the facade backend, must start null
};
} // namespace


enum : std::uint8_t
{
	// Property IDs
	kExhaustPlume_size
};


// A mirror of sExhaustPlumeProperties with the read-only/read-write flags the two
// bad-property error reporters in OOJavaScriptEngine.mm (OOJSReportBadPropertySelector/Value)
// describe the properties by (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static ooscript::PropertySpec sExhaustPlumePropertiesRaw[] =
{
	// JS name							ID									flags
	{ "size",	   			kExhaustPlume_size,	  		OOJS_PROP_READWRITE_CB },
	{ 0 }
};
} // namespace


namespace {
static PropertySpec sExhaustPlumeProperties[] =
{
	// JS name							ID								flags									getter		setter
	{ "size",						kExhaustPlume_size,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sExhaustPlumeMethods[] =
{
	// JS name					Function						min args	flags
	{ "remove",         ExhaustPlumeRemove,    0,	0 },

	{ 0 }
};
} // namespace


void InitOOJSExhaustPlume(ooscript::Context context, ooscript::Object global)
{
	Object proto = ooscript::initClass((context), (global), (JSEntityPrototype()), &sExhaustPlumeClass, OOJSUnconstructableConstruct, 0, sExhaustPlumeProperties, sExhaustPlumeMethods, nullptr, nullptr);
	sExhaustPlumePrototype = (proto);
	OOJSRegisterObjectConverter(&sExhaustPlumeClass, OOJSBasicPrivateObjectConverter);
	OOJSRegisterSubclass(&sExhaustPlumeClass, JSEntityClass());
}


namespace {
static BOOL JSExhaustPlumeGetExhaustPlumeEntity(ooscript::Context context, ooscript::Object jsobj, OOExhaustPlumeEntity **outEntity)
{
	OOJS_PROFILE_ENTER
	
	BOOL						result;
	Entity						*entity = nil;
	
	if (outEntity == NULL)  return NO;
	*outEntity = nil;
	
	result = OOJSEntityGetEntity(context, jsobj, &entity);
	if (!result)  return NO;
	
	if (![entity isKindOfClass:[OOExhaustPlumeEntity class]])  return NO;
	
	*outEntity = (OOExhaustPlumeEntity *)entity;
	return YES;
	
	OOJS_PROFILE_EXIT
}
} // namespace


@implementation OOExhaustPlumeEntity (OOJavaScriptExtensions)

- (void)getJSClass:(ooscript::ClassDef **)outClass andPrototype:(ooscript::Object *)outPrototype
{
	*outClass = &sExhaustPlumeClass;
	*outPrototype = sExhaustPlumePrototype;
}


- (id) oo_jsClassName	// shared selector (proposed ADR-0043)
{
	return @"ExhaustPlume";
}

- (BOOL) isVisibleToScripts
{
	return YES;
}

@end


namespace {
static bool ExhaustPlumeGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = (value);
	
	OOJS_NATIVE_ENTER(context)
	
	OOExhaustPlumeEntity				*entity = nil;
	id result = nil;
	
	if (!JSExhaustPlumeGetExhaustPlumeEntity(context, thisObj, &entity))  return NO;
	if (entity == nil)  { *value_raw = ooscript::undefinedValue(); return YES; }
	
	switch (ooscript::idToInt32(propID))
	{
		case kExhaustPlume_size:
			return VectorToJSValue(context, [entity scale], value_raw);

		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sExhaustPlumePropertiesRaw);
			return NO;
	}

	*value_raw = OOJSValueFromNativeObject(context, result);
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool ExhaustPlumeSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = (value);
	
	OOJS_NATIVE_ENTER(context)
	
	OOExhaustPlumeEntity				*entity = nil;
	Vector          vValue;
	
	if (!JSExhaustPlumeGetExhaustPlumeEntity(context, thisObj, &entity)) return NO;
	if (entity == nil)  return YES;
	
	switch (ooscript::idToInt32(propID))
	{
		case kExhaustPlume_size:
			if (JSValueToVector(context, *value_raw, &vValue))
			{
				[entity setScale:vValue];
				return YES;
			}
			break;

		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sExhaustPlumePropertiesRaw);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, (propID), sExhaustPlumePropertiesRaw, *value_raw);
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// *** Methods ***

#define GET_THIS_EXHAUSTPLUME(THISENT) do { \
	if (EXPECT_NOT(!JSExhaustPlumeGetExhaustPlumeEntity(context, OOJS_THIS, &(THISENT))))  return NO; /* Exception */ \
	if (OOIsStaleEntity(THISENT))  OOJS_RETURN_VOID; \
} while (0)


namespace {
static bool ExhaustPlumeRemove(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	OOExhaustPlumeEntity				*thisEnt = nil;
	GET_THIS_EXHAUSTPLUME(thisEnt);
	
	ShipEntity				*parent = [thisEnt owner];
	[parent removeExhaust:thisEnt];

	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace
