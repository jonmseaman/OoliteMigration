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
#import "OOPListView.h"
#import "ResourceManager.h"
#import "EntityOOJavaScriptExtensions.h"
#import "OOFoundationBridge.h"

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
static ooscript::Object sVisualEffectPrototype;
} // namespace

namespace {
static BOOL JSVisualEffectGetVisualEffectEntity(ooscript::Context context, ooscript::Object visualEffectObj, OOVisualEffectEntity **outEntity);
} // namespace


namespace {
static bool VisualEffectGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool VisualEffectSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace

namespace {
static bool VisualEffectRemove(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VisualEffectGetShaders(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VisualEffectSetShaders(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VisualEffectGetMaterials(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VisualEffectSetMaterials(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VisualEffectScale(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VisualEffectRestoreSubEntities(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace

namespace {
static bool VisualEffectSetMaterialsInternal(ooscript::Context context, ooscript::CallArgs &oojsArgs, OOVisualEffectEntity *thisEnt, BOOL fromShaders);
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
	nullptr,			// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,			// resolve (engine default: ResolveStub)
	nullptr,			// convert (engine default: ConvertStub)
	OOJSObjectWrapperFinalize,// finalize
	nullptr,			// call
	nullptr,			// construct
	nullptr,			// backend: owned by the facade backend, must start null
};
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
	{ "dataKey",	     kVisualEffect_dataKey,	      OOJS_PROP_READONLY_CB, nullptr, nullptr },
	{ "isBreakPattern",	kVisualEffect_isBreakPattern,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "scaleX", kVisualEffect_scaleX, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "scaleY", kVisualEffect_scaleY, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },	
	{ "scaleZ", kVisualEffect_scaleZ, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "scannerDisplayColor1", kVisualEffect_scannerDisplayColor1, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "scannerDisplayColor2", kVisualEffect_scannerDisplayColor2, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "hullHeatLevel", kVisualEffect_hullHeatLevel, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "script",				 kVisualEffect_script,				OOJS_PROP_READONLY_CB, nullptr, nullptr },
	{ "scriptInfo", 	 kVisualEffect_scriptInfo,		OOJS_PROP_READONLY_CB, nullptr, nullptr },
	{ "shaderFloat1",  kVisualEffect_shaderFloat1,  PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "shaderFloat2",  kVisualEffect_shaderFloat2,  PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "shaderInt1",    kVisualEffect_shaderInt1,    PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "shaderInt2",    kVisualEffect_shaderInt2,    PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "shaderVector1", kVisualEffect_shaderVector1, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "shaderVector2", kVisualEffect_shaderVector2, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "subEntities",			kVisualEffect_subEntities,			OOJS_PROP_READONLY_CB, nullptr, nullptr },
	{ "vectorForward", kVisualEffect_vectorForward,	OOJS_PROP_READONLY_CB, nullptr, nullptr },
	{ "vectorRight",	 kVisualEffect_vectorRight,		OOJS_PROP_READONLY_CB, nullptr, nullptr },
	{ "vectorUp",			 kVisualEffect_vectorUp,			OOJS_PROP_READONLY_CB, nullptr, nullptr },
	{ 0 }
};
} // namespace


// Raw jsapi mirror of sVisualEffectProperties for the shared error reporters that still take a
// ooscript::PropertySpec* (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static ooscript::PropertySpec sVisualEffectPropertiesRaw[] =
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


void InitOOJSVisualEffect(ooscript::Context context, ooscript::Object global)
{
	Object proto = ooscript::initClass((context), (global), (JSEntityPrototype()), &sVisualEffectClass, OOJSUnconstructableConstruct, 0, sVisualEffectProperties, sVisualEffectMethods, nullptr, nullptr);
	sVisualEffectPrototype = (proto);
	OOJSRegisterObjectConverter(&sVisualEffectClass, OOJSBasicPrivateObjectConverter);
	OOJSRegisterSubclass(&sVisualEffectClass, JSEntityClass());
}


namespace {
static BOOL JSVisualEffectGetVisualEffectEntity(ooscript::Context context, ooscript::Object visualEffectObj, OOVisualEffectEntity **outEntity)
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

- (void)getJSClass:(ooscript::ClassDef **)outClass andPrototype:(ooscript::Object *)outPrototype
{
	*outClass = &sVisualEffectClass;
	*outPrototype = sVisualEffectPrototype;
}


- (id) oo_jsClassName	// shared selector (proposed ADR-0043)
{
	return @"VisualEffect";
}

- (BOOL) isVisibleToScripts
{
	return YES;
}

- (id) subEntitiesForScript	// shared selector (proposed ADR-0043)
{
	return [[self visualEffectSubEntityEnumerator] allObjects];
}

@end


namespace {
static bool VisualEffectGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = reinterpret_cast<ooscript::Context >(cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = reinterpret_cast<ooscript::Value*>(value);
	
	OOJS_NATIVE_ENTER(context)
	
	OOVisualEffectEntity				*entity = nil;
	id result = nil;
	
	if (!JSVisualEffectGetVisualEffectEntity(context, thisObj, &entity))  return NO;
	if (entity == nil)  { *value_raw = ooscript::undefinedValue(); return YES; }
	
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
			*value_raw = ooscript::int32Value([entity shaderInt1]);
			return YES;

		case kVisualEffect_shaderInt2:
			*value_raw = ooscript::int32Value([entity shaderInt2]);
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
			if (result == nil)  result = oo::ObjectFromPList(oo::PList(oo::PList::Dict{}));	// empty rather than null
			break;

		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sVisualEffectPropertiesRaw);
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
	
	ooscript::Context context = reinterpret_cast<ooscript::Context >(cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = reinterpret_cast<ooscript::Value*>(value);
	
	OOJS_NATIVE_ENTER(context)
	
	OOVisualEffectEntity				*entity = nil;
	bool						bValue;
	OOColor *colorForScript;
	std::int32_t						iValue;
	double        fValue;
	Vector          vValue;
	std::optional<std::string>	sValue;

	
	if (!JSVisualEffectGetVisualEffectEntity(context, thisObj, &entity)) return NO;
	if (entity == nil)  return YES;
	
	switch (ooscript::idToInt32(propID))
	{
		case kVisualEffect_beaconCode:
			sValue = oo::OptionalString(OOStringFromJSValue(context,*value_raw));
			if (!sValue.has_value() || sValue->empty()) 
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
					[entity setBeaconCode:oo::NSStringFrom(*sValue)];
				}
				else // Universe needs to update beacon lists in this case only
				{
					[entity setBeaconCode:oo::NSStringFrom(*sValue)];
					[UNIVERSE setNextBeacon:entity];
				}
			}
			return YES;
			break;

		case kVisualEffect_beaconLabel:
			sValue = oo::OptionalString(OOStringFromJSValue(context,*value_raw));
			if (sValue.has_value())
			{
				[entity setBeaconLabel:oo::NSStringFrom(*sValue)];
				return YES;
			}
			break;

		case kVisualEffect_isBreakPattern:
			if (ooscript::valueToBoolean(cx, (*value_raw), &bValue))
			{
				[entity setIsBreakPattern:bValue];
				return YES;
			}
			break;

		case kVisualEffect_scannerDisplayColor1:
			colorForScript = [OOColor colorWithDescription:OOJSNativeObjectFromJSValue(context, *value_raw)];
			if (colorForScript != nil || ooscript::isNull(*value_raw))
			{
				[entity setScannerDisplayColor1:colorForScript];
				return YES;
			}
			break;
			
		case kVisualEffect_scannerDisplayColor2:
			colorForScript = [OOColor colorWithDescription:OOJSNativeObjectFromJSValue(context, *value_raw)];
			if (colorForScript != nil || ooscript::isNull(*value_raw))
			{
				[entity setScannerDisplayColor2:colorForScript];
				return YES;
			}
			break;

		case kVisualEffect_scaleX:
			if (ooscript::valueToNumber(cx, (*value_raw), &fValue))
			{
				if (fValue > 0.0)
				{
					[entity setScaleX:fValue];
					return YES;
				}
			}
			break;

		case kVisualEffect_scaleY:
			if (ooscript::valueToNumber(cx, (*value_raw), &fValue))
			{
				if (fValue > 0.0)
				{
					[entity setScaleY:fValue];
					return YES;
				}
			}
			break;

		case kVisualEffect_scaleZ:
			if (ooscript::valueToNumber(cx, (*value_raw), &fValue))
			{
				if (fValue > 0.0)
				{
					[entity setScaleZ:fValue];
					return YES;
				}
			}
			break;

		case kVisualEffect_hullHeatLevel:
			if (ooscript::valueToNumber(cx, (*value_raw), &fValue))
			{
				[entity setHullHeatLevel:fValue];
				return YES;
			}
			break;

		case kVisualEffect_shaderFloat1:
			if (ooscript::valueToNumber(cx, (*value_raw), &fValue))
			{
				[entity setShaderFloat1:fValue];
				return YES;
			}
			break;

		case kVisualEffect_shaderFloat2:
			if (ooscript::valueToNumber(cx, (*value_raw), &fValue))
			{
				[entity setShaderFloat2:fValue];
				return YES;
			}
			break;

		case kVisualEffect_shaderInt1:
			if (ooscript::valueToInt32(cx, (*value_raw), &iValue))
			{
				[entity setShaderInt1:iValue];
				return YES;
			}
			break;

		case kVisualEffect_shaderInt2:
			if (ooscript::valueToInt32(cx, (*value_raw), &iValue))
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
			OOJSReportBadPropertySelector(context, thisObj, (propID), sVisualEffectPropertiesRaw);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, (propID), sVisualEffectPropertiesRaw, *value_raw);
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
static bool VisualEffectRemove(ooscript::Context cx, ooscript::CallArgs &oojsArgs)
{
	ooscript::Context context = reinterpret_cast<ooscript::Context >(cx);
	
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
static bool VisualEffectGetMaterials(ooscript::Context cx, ooscript::CallArgs &oojsArgs)
{
	ooscript::Context context = reinterpret_cast<ooscript::Context >(cx);

	OOJS_PROFILE_ENTER

	NSObject			*result = nil;
	OOVisualEffectEntity				*thisEnt = nil;

	GET_THIS_EFFECT(thisEnt);
	
	result = [[thisEnt mesh] materials];
	if (result == nil)  result = oo::ObjectFromPList(oo::PList(oo::PList::Dict{}));	// an empty dictionary
	OOJS_RETURN_OBJECT(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace

//getShaders()
namespace {
static bool VisualEffectGetShaders(ooscript::Context cx, ooscript::CallArgs &oojsArgs)
{
	ooscript::Context context = reinterpret_cast<ooscript::Context >(cx);
	
	OOJS_PROFILE_ENTER
	
	NSObject			*result = nil;
	OOVisualEffectEntity				*thisEnt = nil;

	GET_THIS_EFFECT(thisEnt);
	
	result = [[thisEnt mesh] shaders];
	if (result == nil)  result = oo::ObjectFromPList(oo::PList(oo::PList::Dict{}));	// an empty dictionary
	OOJS_RETURN_OBJECT(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// setMaterials(params: dict, [shaders: dict])  // sets materials dictionary. Optional parameter sets the shaders dictionary too.
namespace {
static bool VisualEffectSetMaterials(ooscript::Context cx, ooscript::CallArgs &oojsArgs)
{
	ooscript::Context context = reinterpret_cast<ooscript::Context >(cx);
	
	OOJS_NATIVE_ENTER(context)
	
	OOVisualEffectEntity				*thisEnt = nil;
	
	if (oojsArgs.count() < 1)
	{
		OOJSReportBadArguments(context, @"VisualEffect", @"setMaterials", 0, OOJS_ARGV, nil, @"parameter object");
		return NO;
	}
	
	GET_THIS_EFFECT(thisEnt);
	
	return VisualEffectSetMaterialsInternal(context, oojsArgs, thisEnt, NO);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// setShaders(params: dict) 
namespace {
static bool VisualEffectSetShaders(ooscript::Context cx, ooscript::CallArgs &oojsArgs)
{
	ooscript::Context context = reinterpret_cast<ooscript::Context >(cx);
	
	OOJS_NATIVE_ENTER(context)
	
	OOVisualEffectEntity				*thisEnt = nil;
	
	GET_THIS_EFFECT(thisEnt);
	
	if (oojsArgs.count() < 1)
	{
		OOJSReportBadArguments(context, @"VisualEffect", @"setShaders", 0, OOJS_ARGV, nil, @"parameter object");
		return NO;
	}
	
	if (ooscript::isNull(OOJS_ARGV[0]) || (!ooscript::isNull(OOJS_ARGV[0]) && !ooscript::isObjectOrNull(OOJS_ARGV[0])))
	{
		// EMMSTRAN: valueToObject() and normal error handling here.
		OOJSReportWarning(context, @"VisualEffect.%@: expected %@ instead of '%@'.", @"setShaders", @"object", OOStringFromJSValueEvenIfNull(context, OOJS_ARGV[0]));
		OOJS_RETURN_BOOL(NO);
	}
	
	OOJS_ARGV[1] = OOJS_ARGV[0];
	return VisualEffectSetMaterialsInternal(context, oojsArgs, thisEnt, YES);
	
	OOJS_NATIVE_EXIT
}
} // namespace




/* **  helper functions ** */

namespace {
static bool VisualEffectSetMaterialsInternal(ooscript::Context context, ooscript::CallArgs &oojsArgs, OOVisualEffectEntity *thisEnt, BOOL fromShaders)
{
	OOJS_PROFILE_ENTER
	
	ooscript::Object params = NULL;
	oo::PList				materials;
	oo::PList				shaders;
	BOOL					withShaders = NO;
	BOOL					success = NO;
	
	GET_THIS_EFFECT(thisEnt);
	
	if (ooscript::isNull(OOJS_ARGV[0]) || (!ooscript::isNull(OOJS_ARGV[0]) && !ooscript::isObjectOrNull(OOJS_ARGV[0])))
	{
		OOJSReportWarning(context, @"VisualEffect.%@: expected %@ instead of '%@'.", @"setMaterials", @"object", OOStringFromJSValueEvenIfNull(context, OOJS_ARGV[0]));
		OOJS_RETURN_BOOL(NO);
	}
	
	if (oojsArgs.count() > 1)
	{
		withShaders = YES;
		if (ooscript::isNull(OOJS_ARGV[1]) || (!ooscript::isNull(OOJS_ARGV[1]) && !ooscript::isObjectOrNull(OOJS_ARGV[1])))
		{
			OOJSReportWarning(context, @"VisualEffect.%@: expected %@ instead of '%@'.",  @"setMaterials", @"object as second parameter", OOStringFromJSValueEvenIfNull(context, OOJS_ARGV[1]));
			withShaders = NO;
		}
	}
	
	if (fromShaders)
	{
		materials = oo::PListFrom([[thisEnt mesh] materials]);
		params = ooscript::toObject(OOJS_ARGV[0]);
		shaders = oo::PListFrom(OOJSNativeObjectFromJSObject(context, params));
	}
	else
	{
		params = ooscript::toObject(OOJS_ARGV[0]);
		materials = oo::PListFrom(OOJSNativeObjectFromJSObject(context, params));
		if (withShaders)
		{
			params = ooscript::toObject(OOJS_ARGV[1]);
			shaders = oo::PListFrom(OOJSNativeObjectFromJSObject(context, params));
		}
		else
		{
			shaders = oo::PListFrom([[thisEnt mesh] shaders]);
		}
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	const oo::PList		effectDict = oo::PListFrom([thisEnt effectInfoDictionary]);
	// -oo_stringForKey: / -oo_dictionaryForKey: as the mesh call read them: nil unless a string (or a
	// number's text) / a dictionary.
	const oo::PList		*model = effectDict.get<oo::PList>("model");
	std::optional<std::string>	modelName;
	if (model != nullptr && (model->isString() || model->isNumber()))  modelName = effectDict.get<std::string>("model");
	oo::PList			shaderMacros = oo::PListFrom([[ResourceManager materialDefaults] objectForKey:@"ship-prefix-macros"]);
	if (!shaderMacros.isDict())  shaderMacros = oo::PList();
	
	// First we test to see if we can create the mesh.
	OOMesh *mesh = [OOMesh meshWithName:oo::NSStringOrNil(modelName)
							   cacheKey:nil
					 materialDictionary:oo::ObjectFromPList(materials)
					  shadersDictionary:oo::ObjectFromPList(shaders)
								 smooth:effectDict.get<bool>("smooth", false)
						   shaderMacros:oo::ObjectFromPList(shaderMacros)
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
static bool VisualEffectScale(ooscript::Context cx, ooscript::CallArgs &oojsArgs)
{
	ooscript::Context context = reinterpret_cast<ooscript::Context >(cx);

	OOJS_NATIVE_ENTER(context)

	OOVisualEffectEntity *thisEnt = nil;
	GET_THIS_EFFECT(thisEnt);
	double scale;
	BOOL gotScale;
 
	if (oojsArgs.count() < 1)
	{
		OOJSReportBadArguments(context, @"VisualEffect", @"scale", oojsArgs.count(), OOJS_ARGV, nil, @"scale factor needed");
		return NO;
	}
 
	gotScale = ooscript::valueToNumber(cx, (OOJS_ARGV[0]), &scale);
	if (EXPECT_NOT(scale <= 0.0 || !gotScale))
	{
		OOJSReportBadArguments(context, @"VisualEffect", @"scale", oojsArgs.count(), OOJS_ARGV, nil, @"scale factor must be positive");
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
static bool VisualEffectRestoreSubEntities(ooscript::Context cx, ooscript::CallArgs &oojsArgs)
{
	ooscript::Context context = reinterpret_cast<ooscript::Context >(cx);
	
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
