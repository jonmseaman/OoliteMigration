/*
OOJSVisualEffect.mm

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

#import "OOVisualEffectEntity.h"
#import "OOJSVisualEffect.h"
#import "OOJSEntity.h"
#import "OOJSVector.h"
#import "OOJavaScriptEngine.h"
#import "OOMesh.h"
#import "OOCollectionExtractors.h"
#import "ResourceManager.h"
#import "EntityOOJavaScriptExtensions.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>
#include <cstdint>

// Retargeted onto the ooscript facade (JSEngine.hpp), the way OOJSVector.mm and
// OOJSFlasher.mm do it (bead oo-sdz exemplar): stub hooks become nullptr, InitClass
// becomes ooscript::initClass, numeric/boolean conversion becomes
// ooscript::newNumberValue/valueToNumber/valueToInt32, and `this` is renamed to `thisObj`
// (reserved word in Objective-C++, ADR-0001).
namespace ooscript { }
using ooscript::Context;
using ooscript::Object;
using ooscript::Value;
using ooscript::PropertyId;
using ooscript::ClassDef;
using ooscript::ClassFlag;
using ooscript::PropertyFlag;
using ooscript::PropertySpec;
using ooscript::FunctionSpec;
using ooscript::CallArgs;

// Byte-identical facade <-> jsapi views, local to this call site (see OOJSVector.mm).
namespace {
static inline Context    OOJSFCX(JSContext *cx)   { return reinterpret_cast<Context>(cx); }
} // namespace
namespace {
static inline Object     OOJSFOBJ(JSObject *o)    { return reinterpret_cast<Object>(o); }
} // namespace
namespace {
static inline JSObject  *OOJSROBJ(Object o)       { return reinterpret_cast<JSObject*>(o); }
} // namespace
namespace {
static inline jsid       OOJSRJSID(PropertyId id) { jsid r; std::memcpy(&r, &id, sizeof r); return r; }
} // namespace
namespace {
static inline Value      OOJSFVAL(jsval v)        { Value r; std::memcpy(&r, &v, sizeof r); return r; }
} // namespace


namespace {
static JSObject		*sVisualEffectPrototype;
} // namespace

namespace {
static BOOL JSVisualEffectGetVisualEffectEntity(JSContext *context, JSObject *visualEffectObj, OOVisualEffectEntity **outEntity);
} // namespace


namespace {
static bool VisualEffectGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool VisualEffectSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace

namespace {
static bool VisualEffectRemove(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VisualEffectGetShaders(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VisualEffectSetShaders(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VisualEffectGetMaterials(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VisualEffectSetMaterials(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VisualEffectScale(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VisualEffectRestoreSubEntities(Context cx, CallArgs &oojsArgs);
} // namespace

namespace {
static JSBool VisualEffectSetMaterialsInternal(JSContext *context, uintN argc, jsval *vp, OOVisualEffectEntity *thisEnt, BOOL fromShaders);
} // namespace


// Adapts the shared jsapi finalizer to the facade's FinalizeHook signature (see OOJSFlasher.mm).
namespace {
static void VisualEffectFinalize(Context cx, Object obj)
{
	OOJSObjectWrapperFinalize(reinterpret_cast<JSContext*>(cx), reinterpret_cast<JSObject*>(obj));
}
} // namespace


// Adapts the shared jsapi OOJSUnconstructableConstruct to the facade's NativeFn signature
// (see OOJSFlasher.mm).
namespace {
static bool VisualEffectUnconstructableConstruct(Context cx, CallArgs &oojsArgs)
{
	return OOJSUnconstructableConstruct(reinterpret_cast<JSContext*>(cx), oojsArgs.count(), reinterpret_cast<jsval*>(oojsArgs.rawVp()));
}
} // namespace


namespace {
static ClassDef sVisualEffectClass =
{
	"VisualEffect",
	ClassFlag::HasPrivate,
	
	nullptr,			// addProperty (engine default: PropertyStub)
	nullptr,			// delProperty (engine default: PropertyStub)
	VisualEffectGetProperty,		// getProperty
	VisualEffectSetProperty,		// setProperty
	nullptr,			// enumerate (engine default: EnumerateStub)
	nullptr,			// newEnumerate (JSCLASS_NEW_ENUMERATE not used)
	nullptr,			// resolve (engine default: ResolveStub)
	nullptr,			// convert (engine default: ConvertStub)
	VisualEffectFinalize,// finalize
	nullptr,			// call
	nullptr,			// construct
	nullptr,			// backend: owned by the facade backend, must start null
};
} // namespace


// The engine's own JSClass* for sVisualEffectClass, needed by shared jsapi plumbing that has
// not yet been retargeted (see OOJSFlasher.mm's RawFlasherClass).
namespace {
static inline JSClass *RawVisualEffectClass(void)
{
	return reinterpret_cast<JSClass*>(sVisualEffectClass.backend);
}
} // namespace


enum : std::uint8_t
{
	// Property IDs
	kVisualEffect_beaconCode,
	kVisualEffect_beaconLabel,
	kVisualEffect_dataKey,
	kVisualEffect_hullHeatLevel,
	kVisualEffect_isBreakPattern,
	kVisualEffect_scaleX,
	kVisualEffect_scaleY,
	kVisualEffect_scaleZ,
	kVisualEffect_scannerDisplayColor1,
	kVisualEffect_scannerDisplayColor2,
	kVisualEffect_script,
	kVisualEffect_scriptInfo,
	kVisualEffect_shaderFloat1,
	kVisualEffect_shaderFloat2,
	kVisualEffect_shaderInt1,
	kVisualEffect_shaderInt2,
	kVisualEffect_shaderVector1,
	kVisualEffect_shaderVector2,
	kVisualEffect_subEntities,
	kVisualEffect_vectorForward,
	kVisualEffect_vectorRight,
	kVisualEffect_vectorUp
};


namespace {
static PropertySpec sVisualEffectProperties[] =
{
	// JS name						ID									flags																			getter		setter
	{ "beaconCode",	   kVisualEffect_beaconCode,	  PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "beaconLabel",   kVisualEffect_beaconLabel,	  PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "dataKey",	     kVisualEffect_dataKey,	      PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "isBreakPattern",	kVisualEffect_isBreakPattern,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "scaleX", kVisualEffect_scaleX, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "scaleY", kVisualEffect_scaleY, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },	
	{ "scaleZ", kVisualEffect_scaleZ, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "scannerDisplayColor1", kVisualEffect_scannerDisplayColor1, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "scannerDisplayColor2", kVisualEffect_scannerDisplayColor2, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "hullHeatLevel", kVisualEffect_hullHeatLevel, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "script",				 kVisualEffect_script,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "scriptInfo", 	 kVisualEffect_scriptInfo,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "shaderFloat1",  kVisualEffect_shaderFloat1,  PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "shaderFloat2",  kVisualEffect_shaderFloat2,  PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "shaderInt1",    kVisualEffect_shaderInt1,    PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "shaderInt2",    kVisualEffect_shaderInt2,    PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "shaderVector1", kVisualEffect_shaderVector1, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "shaderVector2", kVisualEffect_shaderVector2, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "subEntities",			kVisualEffect_subEntities,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "vectorForward", kVisualEffect_vectorForward,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "vectorRight",	 kVisualEffect_vectorRight,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "vectorUp",			 kVisualEffect_vectorUp,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ 0 }
};
} // namespace


// Raw jsapi mirror of sVisualEffectProperties for the shared error reporters that still take a
// JSPropertySpec* (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static JSPropertySpec sVisualEffectPropertiesRaw[] =
{
	// JS name						ID									flags
	{ "beaconCode",	   kVisualEffect_beaconCode,	  OOJS_PROP_READWRITE_CB },
	{ "beaconLabel",   kVisualEffect_beaconLabel,	  OOJS_PROP_READWRITE_CB },
	{ "dataKey",	     kVisualEffect_dataKey,	      OOJS_PROP_READONLY_CB },
	{ "isBreakPattern",	kVisualEffect_isBreakPattern,	OOJS_PROP_READWRITE_CB },
	{ "scaleX", kVisualEffect_scaleX, OOJS_PROP_READWRITE_CB },
	{ "scaleY", kVisualEffect_scaleY, OOJS_PROP_READWRITE_CB },	
	{ "scaleZ", kVisualEffect_scaleZ, OOJS_PROP_READWRITE_CB },
	{ "scannerDisplayColor1", kVisualEffect_scannerDisplayColor1, OOJS_PROP_READWRITE_CB },
	{ "scannerDisplayColor2", kVisualEffect_scannerDisplayColor2, OOJS_PROP_READWRITE_CB },
	{ "hullHeatLevel", kVisualEffect_hullHeatLevel, OOJS_PROP_READWRITE_CB },
	{ "script",				 kVisualEffect_script,				OOJS_PROP_READONLY_CB },
	{ "scriptInfo", 	 kVisualEffect_scriptInfo,		OOJS_PROP_READONLY_CB },
	{ "shaderFloat1",  kVisualEffect_shaderFloat1,  OOJS_PROP_READWRITE_CB },
	{ "shaderFloat2",  kVisualEffect_shaderFloat2,  OOJS_PROP_READWRITE_CB },
	{ "shaderInt1",    kVisualEffect_shaderInt1,    OOJS_PROP_READWRITE_CB },
	{ "shaderInt2",    kVisualEffect_shaderInt2,    OOJS_PROP_READWRITE_CB },
	{ "shaderVector1", kVisualEffect_shaderVector1, OOJS_PROP_READWRITE_CB },
	{ "shaderVector2", kVisualEffect_shaderVector2, OOJS_PROP_READWRITE_CB },
	{ "subEntities",			kVisualEffect_subEntities,			OOJS_PROP_READONLY_CB },
	{ "vectorForward", kVisualEffect_vectorForward,	OOJS_PROP_READONLY_CB },
	{ "vectorRight",	 kVisualEffect_vectorRight,		OOJS_PROP_READONLY_CB },
	{ "vectorUp",			 kVisualEffect_vectorUp,			OOJS_PROP_READONLY_CB },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sVisualEffectMethods[] =
{
	// JS name					Function						min args	flags
	{ "getMaterials",   VisualEffectGetMaterials,    0,	0 },
	{ "getShaders",     VisualEffectGetShaders,    0,	0 },
	{ "remove",         VisualEffectRemove,    0,	0 },
	{ "restoreSubEntities", VisualEffectRestoreSubEntities, 0,	0 },
	{ "scale",				  VisualEffectScale, 1,	0 },
	{ "setMaterials",   VisualEffectSetMaterials,    1,	0 },
	{ "setShaders",     VisualEffectSetShaders,    2,	0 },

	{ 0 }
};
} // namespace


void InitOOJSVisualEffect(JSContext *context, JSObject *global)
{
	Object proto = ooscript::initClass(OOJSFCX(context), OOJSFOBJ(global), OOJSFOBJ(JSEntityPrototype()), &sVisualEffectClass, VisualEffectUnconstructableConstruct, 0, sVisualEffectProperties, sVisualEffectMethods, nullptr, nullptr);
	sVisualEffectPrototype = OOJSROBJ(proto);
	OOJSRegisterObjectConverter(RawVisualEffectClass(), OOJSBasicPrivateObjectConverter);
	OOJSRegisterSubclass(RawVisualEffectClass(), JSEntityClass());
}


namespace {
static BOOL JSVisualEffectGetVisualEffectEntity(JSContext *context, JSObject *visualEffectObj, OOVisualEffectEntity **outEntity)
{
	OOJS_PROFILE_ENTER
	
	BOOL						result;
	Entity						*entity = nil;
	
	if (outEntity == NULL)  return NO;
	*outEntity = nil;
	
	result = OOJSEntityGetEntity(context, visualEffectObj, &entity);
	if (!result)  return NO;
	
	if (![entity isKindOfClass:[OOVisualEffectEntity class]])  return NO;
	
	*outEntity = (OOVisualEffectEntity *)entity;
	return YES;
	
	OOJS_PROFILE_EXIT
}
} // namespace


@implementation OOVisualEffectEntity (OOJavaScriptExtensions)

- (void)getJSClass:(JSClass **)outClass andPrototype:(JSObject **)outPrototype
{
	*outClass = RawVisualEffectClass();
	*outPrototype = sVisualEffectPrototype;
}


- (NSString *) oo_jsClassName
{
	return @"VisualEffect";
}

- (BOOL) isVisibleToScripts
{
	return YES;
}

- (NSArray *) subEntitiesForScript
{
	return [[self visualEffectSubEntityEnumerator] allObjects];
}

@end


namespace {
static bool VisualEffectGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = reinterpret_cast<JSContext*>(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *value_raw = reinterpret_cast<jsval*>(value);
	
	OOJS_NATIVE_ENTER(context)
	
	OOVisualEffectEntity				*entity = nil;
	id result = nil;
	
	if (!JSVisualEffectGetVisualEffectEntity(context, thisObj, &entity))  return NO;
	if (entity == nil)  { *value_raw = JSVAL_VOID; return YES; }
	
	switch (ooscript::idToInt32(propID))
	{
		case kVisualEffect_beaconCode:
			result = [entity beaconCode];
			break;

		case kVisualEffect_beaconLabel:
			result = [entity beaconLabel];
			break;

		case kVisualEffect_dataKey:
			result = [entity effectKey];
			break;

		case kVisualEffect_isBreakPattern:
			*value_raw = OOJSValueFromBOOL([entity isBreakPattern]);

			return YES;

		case kVisualEffect_vectorRight:
			return VectorToJSValue(context, [entity rightVector], value_raw);
			
		case kVisualEffect_vectorForward:
			return VectorToJSValue(context, [entity forwardVector], value_raw);
			
		case kVisualEffect_vectorUp:
			return VectorToJSValue(context, [entity upVector], value_raw);

		case kVisualEffect_scaleX:
			return ooscript::newNumberValue(cx, [entity scaleX], value);

		case kVisualEffect_scaleY:
			return ooscript::newNumberValue(cx, [entity scaleY], value);

		case kVisualEffect_scaleZ:
			return ooscript::newNumberValue(cx, [entity scaleZ], value);

		case kVisualEffect_scannerDisplayColor1:
			result = [[entity scannerDisplayColor1] normalizedArray];
			break;
			
		case kVisualEffect_scannerDisplayColor2:
			result = [[entity scannerDisplayColor2] normalizedArray];
			break;

		case kVisualEffect_hullHeatLevel:
			return ooscript::newNumberValue(cx, [entity hullHeatLevel], value);

		case kVisualEffect_shaderFloat1:
			return ooscript::newNumberValue(cx, [entity shaderFloat1], value);

		case kVisualEffect_shaderFloat2:
			return ooscript::newNumberValue(cx, [entity shaderFloat2], value);

		case kVisualEffect_shaderInt1:
			*value_raw = INT_TO_JSVAL([entity shaderInt1]);
			return YES;

		case kVisualEffect_shaderInt2:
			*value_raw = INT_TO_JSVAL([entity shaderInt2]);
			return YES;

		case kVisualEffect_shaderVector1:
			return VectorToJSValue(context, [entity shaderVector1], value_raw);

		case kVisualEffect_shaderVector2:
			return VectorToJSValue(context, [entity shaderVector2], value_raw);

		case kVisualEffect_subEntities:
			result = [entity subEntitiesForScript];
			break;
			
			
		case kVisualEffect_script:
			result = [entity script];
			break;

		case kVisualEffect_scriptInfo:
			result = [entity scriptInfo];
			if (result == nil)  result = [NSDictionary dictionary];	// empty rather than null
			break;

		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sVisualEffectPropertiesRaw);
			return NO;
	}

	*value_raw = OOJSValueFromNativeObject(context, result);
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool VisualEffectSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = reinterpret_cast<JSContext*>(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *value_raw = reinterpret_cast<jsval*>(value);
	
	OOJS_NATIVE_ENTER(context)
	
	OOVisualEffectEntity				*entity = nil;
	bool						bValue;
	OOColor *colorForScript;
	std::int32_t						iValue;
	jsdouble        fValue;
	Vector          vValue;
	NSString					*sValue = nil;

	
	if (!JSVisualEffectGetVisualEffectEntity(context, thisObj, &entity)) return NO;
	if (entity == nil)  return YES;
	
	switch (ooscript::idToInt32(propID))
	{
		case kVisualEffect_beaconCode:
			sValue = OOStringFromJSValue(context,*value_raw);
			if (sValue == nil || [sValue length] == 0) 
			{
				if ([entity isBeacon]) 
				{
					[UNIVERSE clearBeacon:entity];
					if ([PLAYER nextBeacon] == entity)
					{
						[PLAYER setCompassMode:COMPASS_MODE_PLANET];
					}
				}
			}
			else 
			{
				if ([entity isBeacon]) 
				{
					[entity setBeaconCode:sValue];
				}
				else // Universe needs to update beacon lists in this case only
				{
					[entity setBeaconCode:sValue];
					[UNIVERSE setNextBeacon:entity];
				}
			}
			return YES;
			break;

		case kVisualEffect_beaconLabel:
			sValue = OOStringFromJSValue(context,*value_raw);
			if (sValue != nil)
			{
				[entity setBeaconLabel:sValue];
				return YES;
			}
			break;

		case kVisualEffect_isBreakPattern:
			if (ooscript::valueToBoolean(cx, OOJSFVAL(*value_raw), &bValue))
			{
				[entity setIsBreakPattern:bValue];
				return YES;
			}
			break;

		case kVisualEffect_scannerDisplayColor1:
			colorForScript = [OOColor colorWithDescription:OOJSNativeObjectFromJSValue(context, *value_raw)];
			if (colorForScript != nil || JSVAL_IS_NULL(*value_raw))
			{
				[entity setScannerDisplayColor1:colorForScript];
				return YES;
			}
			break;
			
		case kVisualEffect_scannerDisplayColor2:
			colorForScript = [OOColor colorWithDescription:OOJSNativeObjectFromJSValue(context, *value_raw)];
			if (colorForScript != nil || JSVAL_IS_NULL(*value_raw))
			{
				[entity setScannerDisplayColor2:colorForScript];
				return YES;
			}
			break;

		case kVisualEffect_scaleX:
			if (ooscript::valueToNumber(cx, OOJSFVAL(*value_raw), &fValue))
			{
				if (fValue > 0.0)
				{
					[entity setScaleX:fValue];
					return YES;
				}
			}
			break;

		case kVisualEffect_scaleY:
			if (ooscript::valueToNumber(cx, OOJSFVAL(*value_raw), &fValue))
			{
				if (fValue > 0.0)
				{
					[entity setScaleY:fValue];
					return YES;
				}
			}
			break;

		case kVisualEffect_scaleZ:
			if (ooscript::valueToNumber(cx, OOJSFVAL(*value_raw), &fValue))
			{
				if (fValue > 0.0)
				{
					[entity setScaleZ:fValue];
					return YES;
				}
			}
			break;

		case kVisualEffect_hullHeatLevel:
			if (ooscript::valueToNumber(cx, OOJSFVAL(*value_raw), &fValue))
			{
				[entity setHullHeatLevel:fValue];
				return YES;
			}
			break;

		case kVisualEffect_shaderFloat1:
			if (ooscript::valueToNumber(cx, OOJSFVAL(*value_raw), &fValue))
			{
				[entity setShaderFloat1:fValue];
				return YES;
			}
			break;

		case kVisualEffect_shaderFloat2:
			if (ooscript::valueToNumber(cx, OOJSFVAL(*value_raw), &fValue))
			{
				[entity setShaderFloat2:fValue];
				return YES;
			}
			break;

		case kVisualEffect_shaderInt1:
			if (ooscript::valueToInt32(cx, OOJSFVAL(*value_raw), &iValue))
			{
				[entity setShaderInt1:iValue];
				return YES;
			}
			break;

		case kVisualEffect_shaderInt2:
			if (ooscript::valueToInt32(cx, OOJSFVAL(*value_raw), &iValue))
			{
				[entity setShaderInt2:iValue];
				return YES;
			}
			break;

		case kVisualEffect_shaderVector1:
			if (JSValueToVector(context, *value_raw, &vValue))
			{
				[entity setShaderVector1:vValue];
				return YES;
			}
			break;

		case kVisualEffect_shaderVector2:
			if (JSValueToVector(context, *value_raw, &vValue))
			{
				[entity setShaderVector2:vValue];
				return YES;
			}
			break;

		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sVisualEffectPropertiesRaw);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, OOJSRJSID(propID), sVisualEffectPropertiesRaw, *value_raw);
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// *** Methods ***

#define GET_THIS_EFFECT(THISENT) do { \
	if (EXPECT_NOT(!JSVisualEffectGetVisualEffectEntity(context, OOJS_THIS, &(THISENT))))  return NO; /* Exception */ \
	if (OOIsStaleEntity(THISENT))  OOJS_RETURN_VOID; \
} while (0)


namespace {
static bool VisualEffectRemove(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = reinterpret_cast<JSContext*>(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = reinterpret_cast<jsval*>(oojsArgs.rawVp());
	(void)argc;
	(void)vp;
	
	OOJS_NATIVE_ENTER(context)
	
	OOVisualEffectEntity				*thisEnt = nil;
	GET_THIS_EFFECT(thisEnt);
	
	if ([thisEnt isSubEntity])
	{
		OOVisualEffectEntity				*parent = [thisEnt owner];
		[parent removeSubEntity:thisEnt];
	}
	else
	{
		[thisEnt remove];
	}

	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


//getMaterials()
namespace {
static bool VisualEffectGetMaterials(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = reinterpret_cast<JSContext*>(cx);
	jsval *vp = reinterpret_cast<jsval*>(oojsArgs.rawVp());
	(void)vp;

	OOJS_PROFILE_ENTER

	NSObject			*result = nil;
	OOVisualEffectEntity				*thisEnt = nil;

	GET_THIS_EFFECT(thisEnt);
	
	result = [[thisEnt mesh] materials];
	if (result == nil)  result = [NSDictionary dictionary];
	OOJS_RETURN_OBJECT(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace

//getShaders()
namespace {
static bool VisualEffectGetShaders(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = reinterpret_cast<JSContext*>(cx);
	jsval *vp = reinterpret_cast<jsval*>(oojsArgs.rawVp());
	(void)vp;
	
	OOJS_PROFILE_ENTER
	
	NSObject			*result = nil;
	OOVisualEffectEntity				*thisEnt = nil;

	GET_THIS_EFFECT(thisEnt);
	
	result = [[thisEnt mesh] shaders];
	if (result == nil)  result = [NSDictionary dictionary];
	OOJS_RETURN_OBJECT(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// setMaterials(params: dict, [shaders: dict])  // sets materials dictionary. Optional parameter sets the shaders dictionary too.
namespace {
static bool VisualEffectSetMaterials(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = reinterpret_cast<JSContext*>(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = reinterpret_cast<jsval*>(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	OOVisualEffectEntity				*thisEnt = nil;
	
	if (argc < 1)
	{
		OOJSReportBadArguments(context, @"VisualEffect", @"setMaterials", 0, OOJS_ARGV, nil, @"parameter object");
		return NO;
	}
	
	GET_THIS_EFFECT(thisEnt);
	
	return VisualEffectSetMaterialsInternal(context, argc, vp, thisEnt, NO);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// setShaders(params: dict) 
namespace {
static bool VisualEffectSetShaders(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = reinterpret_cast<JSContext*>(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = reinterpret_cast<jsval*>(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	OOVisualEffectEntity				*thisEnt = nil;
	
	GET_THIS_EFFECT(thisEnt);
	
	if (argc < 1)
	{
		OOJSReportBadArguments(context, @"VisualEffect", @"setShaders", 0, OOJS_ARGV, nil, @"parameter object");
		return NO;
	}
	
	if (JSVAL_IS_NULL(OOJS_ARGV[0]) || (!JSVAL_IS_NULL(OOJS_ARGV[0]) && !JSVAL_IS_OBJECT(OOJS_ARGV[0])))
	{
		// EMMSTRAN: valueToObject() and normal error handling here.
		OOJSReportWarning(context, @"VisualEffect.%@: expected %@ instead of '%@'.", @"setShaders", @"object", OOStringFromJSValueEvenIfNull(context, OOJS_ARGV[0]));
		OOJS_RETURN_BOOL(NO);
	}
	
	OOJS_ARGV[1] = OOJS_ARGV[0];
	return VisualEffectSetMaterialsInternal(context, argc, vp, thisEnt, YES);
	
	OOJS_NATIVE_EXIT
}
} // namespace




/* **  helper functions ** */

namespace {
static JSBool VisualEffectSetMaterialsInternal(JSContext *context, uintN argc, jsval *vp, OOVisualEffectEntity *thisEnt, BOOL fromShaders)
{
	OOJS_PROFILE_ENTER
	
	JSObject				*params = NULL;
	NSDictionary			*materials;
	NSDictionary			*shaders;
	BOOL					withShaders = NO;
	BOOL					success = NO;
	
	GET_THIS_EFFECT(thisEnt);
	
	if (JSVAL_IS_NULL(OOJS_ARGV[0]) || (!JSVAL_IS_NULL(OOJS_ARGV[0]) && !JSVAL_IS_OBJECT(OOJS_ARGV[0])))
	{
		OOJSReportWarning(context, @"VisualEffect.%@: expected %@ instead of '%@'.", @"setMaterials", @"object", OOStringFromJSValueEvenIfNull(context, OOJS_ARGV[0]));
		OOJS_RETURN_BOOL(NO);
	}
	
	if (argc > 1)
	{
		withShaders = YES;
		if (JSVAL_IS_NULL(OOJS_ARGV[1]) || (!JSVAL_IS_NULL(OOJS_ARGV[1]) && !JSVAL_IS_OBJECT(OOJS_ARGV[1])))
		{
			OOJSReportWarning(context, @"VisualEffect.%@: expected %@ instead of '%@'.",  @"setMaterials", @"object as second parameter", OOStringFromJSValueEvenIfNull(context, OOJS_ARGV[1]));
			withShaders = NO;
		}
	}
	
	if (fromShaders)
	{
		materials = [[thisEnt mesh] materials];
		params = JSVAL_TO_OBJECT(OOJS_ARGV[0]);
		shaders = OOJSNativeObjectFromJSObject(context, params);
	}
	else
	{
		params = JSVAL_TO_OBJECT(OOJS_ARGV[0]);
		materials = OOJSNativeObjectFromJSObject(context, params);
		if (withShaders)
		{
			params = JSVAL_TO_OBJECT(OOJS_ARGV[1]);
			shaders = OOJSNativeObjectFromJSObject(context, params);
		}
		else
		{
			shaders = [[thisEnt mesh] shaders];
		}
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	NSDictionary 			*effectDict = [thisEnt effectInfoDictionary];
	
	// First we test to see if we can create the mesh.
	OOMesh *mesh = [OOMesh meshWithName:[effectDict oo_stringForKey:@"model"]
							   cacheKey:nil
					 materialDictionary:materials
					  shadersDictionary:shaders
								 smooth:[effectDict oo_boolForKey:@"smooth" defaultValue:NO]
						   shaderMacros:[[ResourceManager materialDefaults] oo_dictionaryForKey:@"ship-prefix-macros"]
					shaderBindingTarget:thisEnt];
	
	if (mesh != nil)
	{
		[thisEnt setMesh:mesh];
		success = YES;
	}
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_BOOL(success);
	
	OOJS_PROFILE_EXIT
}
} // namespace

namespace {
static bool VisualEffectScale(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = reinterpret_cast<JSContext*>(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = reinterpret_cast<jsval*>(oojsArgs.rawVp());
	(void)vp;

	OOJS_NATIVE_ENTER(context)

	OOVisualEffectEntity *thisEnt = nil;
	GET_THIS_EFFECT(thisEnt);
	jsdouble scale;
	BOOL gotScale;
 
	if (argc < 1)
	{
		OOJSReportBadArguments(context, @"VisualEffect", @"scale", argc, OOJS_ARGV, nil, @"scale factor needed");
		return NO;
	}
 
	gotScale = ooscript::valueToNumber(cx, OOJSFVAL(OOJS_ARGV[0]), &scale);
	if (EXPECT_NOT(scale <= 0.0 || !gotScale))
	{
		OOJSReportBadArguments(context, @"VisualEffect", @"scale", argc, OOJS_ARGV, nil, @"scale factor must be positive");
		return NO;
	}
 
	// set all three scales
	[thisEnt setScaleX:scale];
	[thisEnt setScaleY:scale];
	[thisEnt setScaleZ:scale];
 
	return YES;
	OOJS_NATIVE_EXIT
		
}
} // namespace


// restoreSubEntities(): boolean
namespace {
static bool VisualEffectRestoreSubEntities(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = reinterpret_cast<JSContext*>(cx);
	jsval *vp = reinterpret_cast<jsval*>(oojsArgs.rawVp());
	(void)vp;
	
	OOJS_NATIVE_ENTER(context)
	
	OOVisualEffectEntity				*thisEnt = nil;
	NSUInteger				numSubEntitiesRestored = 0U;
	
	GET_THIS_EFFECT(thisEnt);
	
	NSUInteger subCount = [[thisEnt subEntitiesForScript] count];
	
	[thisEnt clearSubEntities];
	[thisEnt setUpSubEntities];
	
	if ([[thisEnt subEntitiesForScript] count] - subCount > 0)  numSubEntitiesRestored = [[thisEnt subEntitiesForScript] count] - subCount;
	
	OOJS_RETURN_BOOL(numSubEntitiesRestored > 0);
	
	OOJS_NATIVE_EXIT
}
} // namespace
