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
	getProperty, setProperty) and the finalizer now take the façade's Context/Object/
	PropertyId/Value/FinalizeHook signature instead of the engine's; a tiny shim at the top of
	each recovers the old JSContext/JSObject/jsid/jsval locals so the rest of each function
	body (including the OOJS_* macros) is UNCHANGED, because ooscript::Value and
	ooscript::PropertyId are byte copies of jsval and jsid (JSEngine.hpp's own contract,
	verified by the backend's static_asserts). The manual jsval construction in
	oo_jsValueInContext: (the engine's NewObject/SetPrivate) is retargeted the same way
	JSVectorWithVector() retargets it in OOJSVector.mm. The shared jsapi
	OOJSObjectWrapperFinalize (OOJavaScriptEngine.m) is adapted to the façade's FinalizeHook
	signature exactly as OOJSPlayer.mm's PlayerFinalize does it.
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
static JSObject *sManifestPrototype;
} // namespace
namespace {
static JSObject	*sManifestObject;
} // namespace


namespace {
static bool ManifestComment(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool ManifestSetComment(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool ManifestShortComment(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool ManifestSetShortComment(Context cx, CallArgs &oojsArgs);
} // namespace


namespace {
static bool ManifestDeleteProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool ManifestGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool ManifestSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace

// Adapts the shared jsapi OOJSObjectWrapperFinalize (OOJavaScriptEngine.m) to the façade's
// FinalizeHook signature; the finalizer itself is untouched, shared plumbing outside this
// bead's scope (see OOJSPlayer.mm's PlayerFinalize for the same pattern).
namespace {
static void ManifestFinalize(Context cx, Object obj)
{
	OOJSObjectWrapperFinalize(OOJSRCX(cx), OOJSROBJ(obj));
}
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
	nullptr,				// newEnumerate (JSCLASS_NEW_ENUMERATE not used)
	nullptr,				// resolve (engine default: ResolveStub)
	nullptr,				// convert (engine default: ConvertStub)
	ManifestFinalize,		// finalize
	nullptr,				// call
	nullptr,				// construct
	nullptr,				// backend: owned by the façade backend, must start null
};
} // namespace


enum : std::uint8_t
{
	kManifest_list				// manifest list, array of commodities: name, unit, quantity, displayName - read-only	
};


// A raw jsapi mirror of sManifestPropertiesFacade, used only for the two bad-property error
// reporters in OOJavaScriptEngine.m (OOJSReportBadPropertySelector/Value): those helpers are
// outside this bead's scope (shared across every binding file) and still take a
// JSPropertySpec*, not ooscript::PropertySpec* (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static JSPropertySpec sManifestProperties[] =
{
	// JS name					ID							flags
	{ "list",				kManifest_list,				OOJS_PROP_READONLY_CB },
	{ 0 }
};
} // namespace


namespace {
static PropertySpec sManifestPropertiesFacade[] =
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


- (jsval) oo_jsValueInContext:(JSContext *)context
{
	JSObject					*jsSelf = NULL;
	jsval						result = JSVAL_NULL;
	
	jsSelf = OOJSROBJ(ooscript::newObject(OOJSFCX(context), &sManifestClass, OOJSFOBJ(sManifestPrototype), nullptr));
	if (jsSelf != NULL)
	{
		if (!ooscript::setPrivate(OOJSFCX(context), OOJSFOBJ(jsSelf), [self retain]))  jsSelf = NULL;
	}
	if (jsSelf != NULL)  result = OBJECT_TO_JSVAL(jsSelf);
	
	return result;
}

@end


// Adapts the shared jsapi OOJSUnconstructableConstruct (OOJavaScriptEngine.m) to the façade's
// NativeFn signature, the way OOJSClock.mm's OOJSUnconstructableConstructFacade does it.
namespace {
static bool ManifestUnconstructableConstruct(Context cx, CallArgs &oojsArgs)
{
	return OOJSUnconstructableConstruct(OOJSRCX(cx), oojsArgs.count(), reinterpret_cast<jsval*>(oojsArgs.rawVp()));
}
} // namespace


void InitOOJSManifest(JSContext *context, JSObject *global)
{
	Object proto = ooscript::initClass(OOJSFCX(context), OOJSFOBJ(global), nullptr, &sManifestClass, ManifestUnconstructableConstruct, 0, sManifestPropertiesFacade, sManifestMethods, nullptr, nullptr);
	sManifestPrototype = OOJSROBJ(proto);
	
	// Create manifest object as a property of the player.ship object.
	Object manifestObj = ooscript::defineObject(OOJSFCX(context), OOJSFOBJ(JSPlayerShipObject()), "manifest", &sManifestClass, proto, PropertyFlag::ReadOnly);
	sManifestObject = OOJSROBJ(manifestObj);
	ooscript::setPrivate(OOJSFCX(context), manifestObj, NULL);
	
	// Also define manifest object as a property of the global object.
	// Wait, what? Why? Oh well, too late now. Deprecate for EMMSTRAN? -- Ahruman 2011-02-10
	ooscript::defineObject(OOJSFCX(context), OOJSFOBJ(global), "manifest", &sManifestClass, proto, PropertyFlag::ReadOnly);
	
}


namespace {
static bool ManifestDeleteProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	(void)value;
	jsval v = JSVAL_VOID;
	return ManifestSetProperty(cx, obj, propID, NO, reinterpret_cast<Value*>(&v));
}
} // namespace


namespace {
static bool ManifestGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsid jsPropID = OOJSRJSID(propID);
	jsval *jsvalue = OOJSRVAL(value);
	(void)thisObj;
	
	OOJS_NATIVE_ENTER(context)
	
	id							result = nil;
	PlayerEntity				*entity = OOPlayerForScripting();
	
	if (JSID_IS_INT(jsPropID))
	{
		switch (JSID_TO_INT(jsPropID))
		{
			case kManifest_list:
				result = [entity cargoListForScripting];
				break;
				
			default:
				OOJSReportBadPropertySelector(context, thisObj, jsPropID, sManifestProperties);
				return NO;
		}
	}
	else if (JSID_IS_STRING(jsPropID))
	{
		/* 'list' property is hard-coded
		 * others map to the commodity keys in trade-goods.plist
		 * compatible-ish with 1.80 and earlier except that
		 * alienItems and similar aliases don't work */
		NSString *key = OOStringFromJSString(context, JSID_TO_STRING(jsPropID));
		if ([[UNIVERSE commodities] goodDefined:key])
		{
			*jsvalue = INT_TO_JSVAL([entity cargoQuantityForType:key]);
			return YES;
		}
		else
		{
			return YES;
		}
	}
	
	*jsvalue = OOJSValueFromNativeObject(context, result);
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool ManifestSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value)
{
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsid jsPropID = OOJSRJSID(propID);
	jsval *jsvalue = OOJSRVAL(value);
	(void)thisObj;
	(void)strict;
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity				*entity = OOPlayerForScripting();
	int32						iValue;
	
	if (JSID_IS_STRING(jsPropID))
	{
		NSString *key = OOStringFromJSString(context, JSID_TO_STRING(jsPropID));

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
			iValue = (int32)iValue32;
			if (iValue < 0)  iValue = 0;
			[entity setCargoQuantityForType:key amount:iValue];
		}
		else
		{
			OOJSReportBadPropertyValue(context, thisObj, jsPropID, sManifestProperties, *jsvalue);
		}
	}
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// comment(good : String) : String
namespace {
static bool ManifestComment(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	OOJS_NATIVE_ENTER(context)

	OOCommodityType	good = nil;
	NSString *		information = nil;

	if (argc > 0)
	{
		good = OOStringFromJSValue(context, OOJS_ARGV[0]);
	}
	if (good == nil)
	{
		OOJSReportBadArguments(context, @"Manifest", @"comment", MIN(argc, 1U), OOJS_ARGV, nil, @"good");
		return NO;
	}

	information = [[PLAYER shipCommodityData] commentForGood:good];

	OOJS_RETURN_OBJECT(information);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// setComment(good : String, information : String) : Boolean
namespace {
static bool ManifestSetComment(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	OOJS_NATIVE_ENTER(context)

	BOOL 			OK;
	OOCommodityType	good = nil;
	NSString *		information = nil;

	if (argc > 1)
	{
		good = OOStringFromJSValue(context, OOJS_ARGV[0]);
		information = OOStringFromJSValue(context, OOJS_ARGV[1]);
	}
	if (good == nil || information == nil)
	{
		OOJSReportBadArguments(context, @"Manifest", @"setComment", MIN(argc, 2U), OOJS_ARGV, nil, @"good and information text");
		return NO;
	}

	OK = [[PLAYER shipCommodityData] setComment:information forGood:good];

	OOJS_RETURN_BOOL(OK);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// shortComment(good : String) : String
namespace {
static bool ManifestShortComment(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	OOJS_NATIVE_ENTER(context)

	OOCommodityType	good = nil;
	NSString *		information = nil;

	if (argc > 0)
	{
		good = OOStringFromJSValue(context, OOJS_ARGV[0]);
	}
	if (good == nil)
	{
		OOJSReportBadArguments(context, @"Manifest", @"shortComment", MIN(argc, 1U), OOJS_ARGV, nil, @"good");
		return NO;
	}

	information = [[PLAYER shipCommodityData] shortCommentForGood:good];

	OOJS_RETURN_OBJECT(information);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// setShortComment(good : String, information : String) : Boolean
namespace {
static bool ManifestSetShortComment(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());

	OOJS_NATIVE_ENTER(context)

	BOOL 			OK;
	OOCommodityType	good = nil;
	NSString *		information = nil;

	if (argc > 1)
	{
		good = OOStringFromJSValue(context, OOJS_ARGV[0]);
		information = OOStringFromJSValue(context, OOJS_ARGV[1]);
	}
	if (good == nil || information == nil)
	{
		OOJSReportBadArguments(context, @"Manifest", @"setShortComment", MIN(argc, 2U), OOJS_ARGV, nil, @"good and information text");
		return NO;
	}

	OK = [[PLAYER shipCommodityData] setShortComment:information forGood:good];

	OOJS_RETURN_BOOL(OK);
	
	OOJS_NATIVE_EXIT
}
} // namespace
