/*

OOJSManifest.m

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

#import "OOJSManifest.h"
#import "OOJavaScriptEngine.h"
#import "PlayerEntity.h"
#import "PlayerEntityScriptMethods.h"
#import "PlayerEntityContracts.h"
#import "Universe.h"
#import "OOJSPlayer.h"
#import "OOJSPlayerShip.h"
#import "OOIsNumberLiteral.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar; see also OOJSClock.mm/OOJSMissionVariables.mm): the class
	dispatch table becomes a static ooscript::ClassDef (the stub hook is nullptr), the
	class-creation call becomes ooscript::initClass, the two class-as-property registrations
	become ooscript::defineObject, and the directly spelled numeric-conversion call becomes
	ooscript::valueToInt32. `this` is renamed to `thisObj` because it is a reserved word once
	this file compiles as Objective-C++ (ADR-0001). The class hooks (deleteProperty,
	getProperty, setProperty) take the façade's Context/Object/PropertyId/Value signature
	directly, and the shared OOJSObjectWrapperFinalize is the class's finalize hook. The manual
	object construction in oo_jsValueInContext: (the engine's NewObject/SetPrivate) is
	retargeted the same way JSVectorWithVector() retargets it in OOJSVector.mm.
*/
namespace ooscript { }
using ooscript::Context;
using ooscript::Object;
using ooscript::Value;
using ooscript::PropertyId;
using ooscript::ClassDef;
using ooscript::ClassFlag;
using ooscript::PropertyFlag;
using ooscript::CallArgs;
using ooscript::PropertySpec;
using ooscript::FunctionSpec;


namespace {
static ooscript::Object sManifestPrototype;
} // namespace
namespace {
static ooscript::Object sManifestObject;
} // namespace


namespace {
static bool ManifestComment(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool ManifestSetComment(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool ManifestShortComment(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool ManifestSetShortComment(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace


namespace {
static bool ManifestDeleteProperty(Context cx, Object obj, PropertyId propID, Value * /*value*/);
} // namespace
namespace {
static bool ManifestGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool ManifestSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value);
} // namespace

namespace {
static ClassDef sManifestClass =
{
	"Manifest",
	ClassFlag::HasPrivate,

	nullptr,				// addProperty (engine default: PropertyStub)
	ManifestDeleteProperty,	// delProperty
	ManifestGetProperty,	// getProperty
	ManifestSetProperty,	// setProperty
	nullptr,				// enumerate (engine default: EnumerateStub)
	nullptr,				// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,				// resolve (engine default: ResolveStub)
	nullptr,				// convert (engine default: ConvertStub)
	OOJSObjectWrapperFinalize,		// finalize
	nullptr,				// call
	nullptr,				// construct
	nullptr,				// backend: owned by the façade backend, must start null
};
} // namespace


enum : std::uint8_t
{
	kManifest_list				// manifest list, array of commodities: name, unit, quantity, displayName - read-only	
};


namespace {
static PropertySpec sManifestProperties[] =
{
	// JS name					ID							flags					getter	setter
	{ "list",				kManifest_list,				PropertyFlag::ReadOnly | PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sManifestMethods[] =
{
	// JS name					Function					min args	flags
	{ "shortComment",			ManifestShortComment,			1,		0 },
	{ "setShortComment",		ManifestSetShortComment,		2,		0 },
	{ "comment",				ManifestComment,				1,		0 },
	{ "setComment",				ManifestSetComment,			2,		0 },
	{ 0 }
};
} // namespace


// Helper class wrapped by JS Manifest objects
@interface OOManifest: NSObject
@end


@implementation OOManifest

- (void) dealloc
{
	[super dealloc];
}


- (NSString *) oo_jsClassName
{
	return @"Manifest";
}


- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context
{
	ooscript::Object jsSelf = NULL;
	ooscript::Value						result = ooscript::nullValue();
	
	jsSelf = (ooscript::newObject((context), &sManifestClass, (sManifestPrototype), nullptr));
	if (jsSelf != NULL)
	{
		if (!ooscript::setPrivate((context), (jsSelf), [self retain]))  jsSelf = NULL;
	}
	if (jsSelf != NULL)  result = ooscript::objectValue(jsSelf);
	
	return result;
}

@end


void InitOOJSManifest(ooscript::Context context, ooscript::Object global)
{
	Object proto = ooscript::initClass((context), (global), nullptr, &sManifestClass, OOJSUnconstructableConstruct, 0, sManifestProperties, sManifestMethods, nullptr, nullptr);
	sManifestPrototype = (proto);
	
	// Create manifest object as a property of the player.ship object.
	Object manifestObj = ooscript::defineObject((context), (JSPlayerShipObject()), "manifest", &sManifestClass, proto, PropertyFlag::ReadOnly);
	sManifestObject = (manifestObj);
	ooscript::setPrivate((context), manifestObj, NULL);
	
	// Also define manifest object as a property of the global object.
	// Wait, what? Why? Oh well, too late now. Deprecate for EMMSTRAN? -- Ahruman 2011-02-10
	ooscript::defineObject((context), (global), "manifest", &sManifestClass, proto, PropertyFlag::ReadOnly);
	
}


namespace {
static bool ManifestDeleteProperty(Context cx, Object obj, PropertyId propID, Value * /*value*/)
{
	ooscript::Value v = ooscript::undefinedValue();
	return ManifestSetProperty(cx, obj, propID, NO, &v);
}
} // namespace


namespace {
static bool ManifestGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	
	OOJS_NATIVE_ENTER(context)
	
	id							result = nil;
	PlayerEntity				*entity = OOPlayerForScripting();
	
	if (ooscript::isInt32Id(propID))
	{
		switch (ooscript::idToInt32(propID))
		{
			case kManifest_list:
				result = [entity cargoListForScripting];
				break;
				
			default:
				OOJSReportBadPropertySelector(context, thisObj, propID, sManifestProperties);
				return NO;
		}
	}
	else if (ooscript::isStringId(propID))
	{
		/* 'list' property is hard-coded
		 * others map to the commodity keys in trade-goods.plist
		 * compatible-ish with 1.80 and earlier except that
		 * alienItems and similar aliases don't work */
		NSString *key = OOStringFromJSString(context, ooscript::idToString(propID));
		if ([[UNIVERSE commodities] goodDefined:key])
		{
			*value = ooscript::int32Value([entity cargoQuantityForType:key]);
			return YES;
		}
		else
		{
			return YES;
		}
	}
	
	*value = OOJSValueFromNativeObject(context, result);
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool ManifestSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity				*entity = OOPlayerForScripting();
	int32_t						iValue;
	
	if (ooscript::isStringId(propID))
	{
		NSString *key = OOStringFromJSString(context, ooscript::idToString(propID));

		OOMassUnit unit = [[UNIVERSE commodityMarket] massUnitForGood:key];
		// we can always change gold, platinum & gem-stones quantities, even with special cargo
		if (unit == UNITS_TONS && [entity specialCargo])
		{
			OOJSReportWarning(context, @"PlayerShip.manifest['foo'] - cannot modify cargo tonnage when Special Cargo is in use.");
			return YES;
		}
	
		std::int32_t iValue32 = 0;
		if (ooscript::valueToInt32(cx, *value, &iValue32))
		{
			iValue = (int32_t)iValue32;
			if (iValue < 0)  iValue = 0;
			[entity setCargoQuantityForType:key amount:iValue];
		}
		else
		{
			OOJSReportBadPropertyValue(context, thisObj, propID, sManifestProperties, *value);
		}
	}
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// comment(good : String) : String
namespace {
static bool ManifestComment(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)

	OOCommodityType	good = nil;
	NSString *		information = nil;

	if (oojsArgs.count() > 0)
	{
		good = OOStringFromJSValue(context, OOJS_ARGV[0]);
	}
	if (good == nil)
	{
		OOJSReportBadArguments(context, @"Manifest", @"comment", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"good");
		return NO;
	}

	information = [[PLAYER shipCommodityData] commentForGood:good];

	OOJS_RETURN_OBJECT(information);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// setComment(good : String, information : String) : Boolean
namespace {
static bool ManifestSetComment(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)

	BOOL 			OK;
	OOCommodityType	good = nil;
	NSString *		information = nil;

	if (oojsArgs.count() > 1)
	{
		good = OOStringFromJSValue(context, OOJS_ARGV[0]);
		information = OOStringFromJSValue(context, OOJS_ARGV[1]);
	}
	if (good == nil || information == nil)
	{
		OOJSReportBadArguments(context, @"Manifest", @"setComment", MIN(oojsArgs.count(), 2U), OOJS_ARGV, nil, @"good and information text");
		return NO;
	}

	OK = [[PLAYER shipCommodityData] setComment:information forGood:good];

	OOJS_RETURN_BOOL(OK);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// shortComment(good : String) : String
namespace {
static bool ManifestShortComment(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)

	OOCommodityType	good = nil;
	NSString *		information = nil;

	if (oojsArgs.count() > 0)
	{
		good = OOStringFromJSValue(context, OOJS_ARGV[0]);
	}
	if (good == nil)
	{
		OOJSReportBadArguments(context, @"Manifest", @"shortComment", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"good");
		return NO;
	}

	information = [[PLAYER shipCommodityData] shortCommentForGood:good];

	OOJS_RETURN_OBJECT(information);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// setShortComment(good : String, information : String) : Boolean
namespace {
static bool ManifestSetShortComment(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)

	BOOL 			OK;
	OOCommodityType	good = nil;
	NSString *		information = nil;

	if (oojsArgs.count() > 1)
	{
		good = OOStringFromJSValue(context, OOJS_ARGV[0]);
		information = OOStringFromJSValue(context, OOJS_ARGV[1]);
	}
	if (good == nil || information == nil)
	{
		OOJSReportBadArguments(context, @"Manifest", @"setShortComment", MIN(oojsArgs.count(), 2U), OOJS_ARGV, nil, @"good and information text");
		return NO;
	}

	OK = [[PLAYER shipCommodityData] setShortComment:information forGood:good];

	OOJS_RETURN_BOOL(OK);
	
	OOJS_NATIVE_EXIT
}
} // namespace
