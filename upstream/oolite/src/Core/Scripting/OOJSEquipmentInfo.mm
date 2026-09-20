/*

OOJSEquipmentInfo.mm


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

#import "OOJSEquipmentInfo.h"
#import "OOJavaScriptEngine.h"
#import "OOEquipmentType.h"
#import "OOJSPlayer.h"
#import "OODebugStandards.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar): the class dispatch table becomes a static ooscript::ClassDef
	(the stub hooks are nullptr), InitClass becomes ooscript::initClass, and the directly
	spelled instance-check, private-storage, object-construction and numeric/integer-conversion
	calls become ooscript::instanceOf / ooscript::getPrivate / ooscript::setPrivate /
	ooscript::newObject / ooscript::newNumberValue / ooscript::valueToInt32. `this` is renamed
	to `thisObj` because it is a reserved word once this file compiles as Objective-C++
	(ADR-0001). The OOJS_* argument-marshalling macros (OOJS_NATIVE_ENTER, OOJS_ARGV,
	OOJS_RETURN_*) are unchanged, byte-identical façade views as in OOJSVector.mm.

	EquipmentInfo has its own private-object getter (originally built by
	DEFINE_JS_OBJECT_GETTER(), OOJavaScriptEngine.h) rather than using that macro directly,
	because the macro and the shared OOJSObjectGetterImplPRIVATE() helper it calls into
	(OOJavaScriptEngine.m) are shared, not-yet-retargeted plumbing that still speaks jsapi's
	JSClass*, exactly as OOJSWaypoint.mm's RawWaypointClass() comment explains for its own
	class. ClassDef's `backend` slot is a BackendClass* whose first member is the real JSClass
	(JSEngine_spidermonkey.cpp: "JSClass is the first member ... so a JSClass* the engine hands
	back converts to its BackendClass*"), and it is filled in by ooscript::initClass() before
	InitOOJSEquipmentInfo() runs, so RawEquipmentInfoClass() below is a reinterpret_cast onto
	already-attached storage, not a conversion.
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
static inline jsid       OOJSRJSID(PropertyId id) { jsid r; std::memcpy(&r, &id, sizeof r); return r; }
} // namespace


namespace {
static JSObject *sEquipmentInfoPrototype;
} // namespace


namespace {
static bool EquipmentInfoGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool EquipmentInfoSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace

namespace {
static bool EquipmentInfoGetAllEqipment(Context cx, Object /*obj*/, PropertyId /*propID*/, Value *value);
} // namespace


// Methods
namespace {
static bool EquipmentInfoStaticInfoForKey(Context cx, CallArgs &oojsArgs);
} // namespace

// Adapts the shared jsapi OOJSUnconstructableConstruct (OOJavaScriptEngine.m) to the façade's
// NativeFn signature, the way OOJSClock.mm's OOJSUnconstructableConstructFacade does it.
namespace {
static bool EquipmentInfoUnconstructableConstruct(Context cx, CallArgs &oojsArgs);
} // namespace


enum : std::uint8_t
{
	// Property IDs
	kEquipmentInfo_calculatedPrice,
	kEquipmentInfo_canBeDamaged,
	kEquipmentInfo_canCarryMultiple,
	kEquipmentInfo_damageProbability,
	kEquipmentInfo_description,
	kEquipmentInfo_displayColor,
	kEquipmentInfo_effectiveTechLevel,
	kEquipmentInfo_equipmentKey,
	kEquipmentInfo_fastAffinityDefensive,
	kEquipmentInfo_fastAffinityOffensive,
	kEquipmentInfo_defaultActivateKey,
	kEquipmentInfo_defaultModeKey,
	kEquipmentInfo_incompatibleEquipment,
	kEquipmentInfo_installationTime,
	kEquipmentInfo_isAvailableToAll,
	kEquipmentInfo_isAvailableToNPCs,
	kEquipmentInfo_isAvailableToPlayer,
	kEquipmentInfo_isExternalStore,				// is missile or mine
	kEquipmentInfo_isPortableBetweenShips,
	kEquipmentInfo_isVisible,
	kEquipmentInfo_name,
	kEquipmentInfo_price,
	kEquipmentInfo_provides,
	kEquipmentInfo_repairTime,
	kEquipmentInfo_requiredCargoSpace,
	kEquipmentInfo_requiresAnyEquipment,
	kEquipmentInfo_requiresCleanLegalRecord,
	kEquipmentInfo_requiresEmptyPylon,
	kEquipmentInfo_requiresEquipment,
	kEquipmentInfo_requiresFreePassengerBerth,
	kEquipmentInfo_requiresFullFuel,
	kEquipmentInfo_requiresMountedPylon,
	kEquipmentInfo_requiresNonCleanLegalRecord,
	kEquipmentInfo_requiresNonFullFuel,
	kEquipmentInfo_scriptInfo,					// arbitrary data for scripts, dictionary, read-only
	kEquipmentInfo_scriptName,
	kEquipmentInfo_techLevel,
	kEquipmentInfo_weaponInfo
};


namespace {
constexpr PropertyFlag kEquipmentInfoPropertyFlags = PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared;
} // namespace
namespace {
constexpr PropertyFlag kEquipmentInfoPropertyFlagsReadOnly = kEquipmentInfoPropertyFlags | PropertyFlag::ReadOnly;
} // namespace


namespace {
static PropertySpec sEquipmentInfoProperties[] =
{
	// JS name								ID											flags								getter	setter
	{ "calculatedPrice",				kEquipmentInfo_calculatedPrice,			kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "canBeDamaged",					kEquipmentInfo_canBeDamaged,				kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "canCarryMultiple",				kEquipmentInfo_canCarryMultiple,			kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "damageProbability",				kEquipmentInfo_damageProbability,			kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "description",					kEquipmentInfo_description,				kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "displayColor",					kEquipmentInfo_displayColor,				kEquipmentInfoPropertyFlags,		nullptr, nullptr },
	{ "effectiveTechLevel",				kEquipmentInfo_effectiveTechLevel,			kEquipmentInfoPropertyFlags,		nullptr, nullptr },
	{ "equipmentKey",					kEquipmentInfo_equipmentKey,				kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "fastAffinityDefensive",			kEquipmentInfo_fastAffinityDefensive,		kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "fastAffinityOffensive",			kEquipmentInfo_fastAffinityOffensive,		kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "defaultActivateKey",				kEquipmentInfo_defaultActivateKey,			kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "defaultModeKey",					kEquipmentInfo_defaultModeKey,				kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "incompatibleEquipment",			kEquipmentInfo_incompatibleEquipment,		kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "installationTime",				kEquipmentInfo_installationTime,           kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "isAvailableToAll",				kEquipmentInfo_isAvailableToAll,			kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "isAvailableToNPCs",				kEquipmentInfo_isAvailableToNPCs,			kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "isAvailableToPlayer",			kEquipmentInfo_isAvailableToPlayer,		kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "isExternalStore",				kEquipmentInfo_isExternalStore,			kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "isPortableBetweenShips",			kEquipmentInfo_isPortableBetweenShips,		kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "isVisible",						kEquipmentInfo_isVisible,					kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "name",							kEquipmentInfo_name,						kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "price",							kEquipmentInfo_price,						kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "provides",						kEquipmentInfo_provides,					kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "repairTime",                     kEquipmentInfo_repairTime,                  kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "requiredCargoSpace",				kEquipmentInfo_requiredCargoSpace,			kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "requiresAnyEquipment",			kEquipmentInfo_requiresAnyEquipment,		kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "requiresCleanLegalRecord",		kEquipmentInfo_requiresCleanLegalRecord,	kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "requiresEmptyPylon",				kEquipmentInfo_requiresEmptyPylon,			kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "requiresEquipment",				kEquipmentInfo_requiresEquipment,			kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "requiresFreePassengerBerth",		kEquipmentInfo_requiresFreePassengerBerth,	kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "requiresFullFuel",				kEquipmentInfo_requiresFullFuel,			kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "requiresMountedPylon",			kEquipmentInfo_requiresMountedPylon,		kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "requiresNonCleanLegalRecord",	kEquipmentInfo_requiresNonCleanLegalRecord,	kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "requiresNonFullFuel",			kEquipmentInfo_requiresNonFullFuel,		kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "scriptInfo",						kEquipmentInfo_scriptInfo,					kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "scriptName",						kEquipmentInfo_scriptName,					kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "techLevel",						kEquipmentInfo_techLevel,					kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ "weaponInfo",						kEquipmentInfo_weaponInfo,					kEquipmentInfoPropertyFlagsReadOnly, nullptr, nullptr },
	{ 0 }
};
} // namespace

// A raw jsapi mirror of sEquipmentInfoProperties, used only for the bad-property error
// reporters in OOJavaScriptEngine.m (OOJSReportBadPropertySelector/Value): those helpers are
// outside this bead's scope (shared across every binding file) and still take a
// JSPropertySpec*, not ooscript::PropertySpec* (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static JSPropertySpec sEquipmentInfoPropertiesRaw[] =
{
	// JS name								ID											flags
	{ "calculatedPrice",				kEquipmentInfo_calculatedPrice,			OOJS_PROP_READONLY_CB },
	{ "canBeDamaged",					kEquipmentInfo_canBeDamaged,				OOJS_PROP_READONLY_CB },
	{ "canCarryMultiple",				kEquipmentInfo_canCarryMultiple,			OOJS_PROP_READONLY_CB },
	{ "damageProbability",				kEquipmentInfo_damageProbability,			OOJS_PROP_READONLY_CB },
	{ "description",					kEquipmentInfo_description,				OOJS_PROP_READONLY_CB },
	{ "displayColor",					kEquipmentInfo_displayColor,				OOJS_PROP_READWRITE_CB },
	{ "effectiveTechLevel",				kEquipmentInfo_effectiveTechLevel,			OOJS_PROP_READWRITE_CB },
	{ "equipmentKey",					kEquipmentInfo_equipmentKey,				OOJS_PROP_READONLY_CB },
	{ "fastAffinityDefensive",			kEquipmentInfo_fastAffinityDefensive,		OOJS_PROP_READONLY_CB },
	{ "fastAffinityOffensive",			kEquipmentInfo_fastAffinityOffensive,		OOJS_PROP_READONLY_CB },
	{ "defaultActivateKey",				kEquipmentInfo_defaultActivateKey,			OOJS_PROP_READONLY_CB },
	{ "defaultModeKey",					kEquipmentInfo_defaultModeKey,				OOJS_PROP_READONLY_CB },
	{ "incompatibleEquipment",			kEquipmentInfo_incompatibleEquipment,		OOJS_PROP_READONLY_CB },
	{ "installationTime",				kEquipmentInfo_installationTime,            OOJS_PROP_READONLY_CB },
	{ "isAvailableToAll",				kEquipmentInfo_isAvailableToAll,			OOJS_PROP_READONLY_CB },
	{ "isAvailableToNPCs",				kEquipmentInfo_isAvailableToNPCs,			OOJS_PROP_READONLY_CB },
	{ "isAvailableToPlayer",			kEquipmentInfo_isAvailableToPlayer,		OOJS_PROP_READONLY_CB },
	{ "isExternalStore",				kEquipmentInfo_isExternalStore,				OOJS_PROP_READONLY_CB },
	{ "isPortableBetweenShips",			kEquipmentInfo_isPortableBetweenShips,		OOJS_PROP_READONLY_CB },
	{ "isVisible",						kEquipmentInfo_isVisible,					OOJS_PROP_READONLY_CB },
	{ "name",							kEquipmentInfo_name,						OOJS_PROP_READONLY_CB },
	{ "price",							kEquipmentInfo_price,						OOJS_PROP_READONLY_CB },
	{ "provides",						kEquipmentInfo_provides,					OOJS_PROP_READONLY_CB },
	{ "repairTime",                     kEquipmentInfo_repairTime,                  OOJS_PROP_READONLY_CB },
	{ "requiredCargoSpace",				kEquipmentInfo_requiredCargoSpace,			OOJS_PROP_READONLY_CB },
	{ "requiresAnyEquipment",			kEquipmentInfo_requiresAnyEquipment,		OOJS_PROP_READONLY_CB },
	{ "requiresCleanLegalRecord",		kEquipmentInfo_requiresCleanLegalRecord,	OOJS_PROP_READONLY_CB },
	{ "requiresEmptyPylon",				kEquipmentInfo_requiresEmptyPylon,			OOJS_PROP_READONLY_CB },
	{ "requiresEquipment",				kEquipmentInfo_requiresEquipment,			OOJS_PROP_READONLY_CB },
	{ "requiresFreePassengerBerth",		kEquipmentInfo_requiresFreePassengerBerth,	OOJS_PROP_READONLY_CB },
	{ "requiresFullFuel",				kEquipmentInfo_requiresFullFuel,			OOJS_PROP_READONLY_CB },
	{ "requiresMountedPylon",			kEquipmentInfo_requiresMountedPylon,		OOJS_PROP_READONLY_CB },
	{ "requiresNonCleanLegalRecord",	kEquipmentInfo_requiresNonCleanLegalRecord,	OOJS_PROP_READONLY_CB },
	{ "requiresNonFullFuel",			kEquipmentInfo_requiresNonFullFuel,		OOJS_PROP_READONLY_CB },
	{ "scriptInfo",						kEquipmentInfo_scriptInfo,					OOJS_PROP_READONLY_CB },
	{ "scriptName",						kEquipmentInfo_scriptName,					OOJS_PROP_READONLY_CB },
	{ "techLevel",						kEquipmentInfo_techLevel,					OOJS_PROP_READONLY_CB },
	{ "weaponInfo",						kEquipmentInfo_weaponInfo,					OOJS_PROP_READONLY_CB },
	{ 0 }
};
} // namespace


namespace {
static PropertySpec sEquipmentInfoStaticProperties[] =
{
	{ "allEquipment",					0, kEquipmentInfoPropertyFlagsReadOnly, EquipmentInfoGetAllEqipment, nullptr },
	{ 0 }
};
} // namespace


namespace {
static bool EquipmentInfoToString(Context cx, CallArgs &oojsArgs)
{
	return OOJSObjectWrapperToString(OOJSRCX(cx), oojsArgs.count(), reinterpret_cast<jsval*>(oojsArgs.rawVp()));
}
} // namespace


namespace {
static FunctionSpec sEquipmentInfoMethods[] =
{
	// JS name					Function						min args
	{ "toString",				EquipmentInfoToString,		0,	0 },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sEquipmentInfoStaticMethods[] =
{
	// JS name					Function						min args
	{ "infoForKey",				EquipmentInfoStaticInfoForKey,	0,	0 },
	{ 0 }
};
} // namespace


// Adapts the shared jsapi finalizer (OOJavaScriptEngine.m) to the façade's FinalizeHook
// signature; the finalizer itself is untouched, shared plumbing outside this bead's scope.
namespace {
static void EquipmentInfoFinalize(Context cx, Object obj)
{
	OOJSObjectWrapperFinalize(OOJSRCX(cx), OOJSROBJ(obj));
}
} // namespace


namespace {
static ClassDef sEquipmentInfoClass =
{
	"EquipmentInfo",
	ClassFlag::HasPrivate,

	nullptr,					// addProperty (engine default: PropertyStub)
	nullptr,					// delProperty (engine default: PropertyStub)
	EquipmentInfoGetProperty,	// getProperty
	EquipmentInfoSetProperty,	// setProperty
	nullptr,					// enumerate (engine default: EnumerateStub)
	nullptr,					// newEnumerate (JSCLASS_NEW_ENUMERATE not used)
	nullptr,					// resolve (engine default: ResolveStub)
	nullptr,					// convert (engine default: ConvertStub)
	EquipmentInfoFinalize,		// finalize
	nullptr,					// call
	nullptr,					// construct
	nullptr,					// backend: owned by the façade backend, must start null
};
} // namespace


// The engine's own JSClass* for sEquipmentInfoClass, for the not-yet-retargeted plumbing
// (OOJSObjectGetterImplPRIVATE, via the getter below) that still takes one; see the comment
// at the top of the file. Valid only after InitOOJSEquipmentInfo() has called
// ooscript::initClass(), which is the only thing that attaches sEquipmentInfoClass.backend.
namespace {
static inline JSClass *RawEquipmentInfoClass(void)
{
	return reinterpret_cast<JSClass*>(sEquipmentInfoClass.backend);
}
} // namespace


// Equivalent of DEFINE_JS_OBJECT_GETTER(JSEquipmentInfoGetEquipmentType, &sEquipmentInfoClass,
// sEquipmentInfoPrototype, OOEquipmentType), hand-written because the macro (and the shared
// OOJSObjectGetterImplPRIVATE() helper it expands to) still take the engine's own JSClass*
// (see the file-top comment and OOJSWaypoint.mm's RawWaypointClass()).
namespace {
#ifndef NDEBUG
static BOOL JSEquipmentInfoGetEquipmentType(JSContext *context, JSObject *inObject, OOEquipmentType **outObject)  GCC_ATTR((unused));
static BOOL JSEquipmentInfoGetEquipmentType(JSContext *context, JSObject *inObject, OOEquipmentType **outObject)
{
	NSCParameterAssert(outObject != NULL);
	static Class cls = Nil;
	if (EXPECT_NOT(cls == Nil))  cls = [OOEquipmentType class];
	return OOJSObjectGetterImplPRIVATE(context, inObject, RawEquipmentInfoClass(), cls, "JSEquipmentInfoGetEquipmentType", (id *)outObject);
}
#else
OOINLINE BOOL JSEquipmentInfoGetEquipmentType(JSContext *context, JSObject *inObject, OOEquipmentType **outObject)
{
	return OOJSObjectGetterImplPRIVATE(context, inObject, RawEquipmentInfoClass(), (id *)outObject);
}
#endif
} // namespace


namespace {
static bool EquipmentInfoUnconstructableConstruct(Context cx, CallArgs &oojsArgs)
{
	return OOJSUnconstructableConstruct(OOJSRCX(cx), oojsArgs.count(), reinterpret_cast<jsval*>(oojsArgs.rawVp()));
}
} // namespace


// *** Public ***

void InitOOJSEquipmentInfo(JSContext *context, JSObject *global)
{
	Object proto = ooscript::initClass(OOJSFCX(context), OOJSFOBJ(global), nullptr, &sEquipmentInfoClass, EquipmentInfoUnconstructableConstruct, 0, sEquipmentInfoProperties, sEquipmentInfoMethods, sEquipmentInfoStaticProperties, sEquipmentInfoStaticMethods);
	sEquipmentInfoPrototype = OOJSROBJ(proto);
	
	OOJSRegisterObjectConverter(RawEquipmentInfoClass(), OOJSBasicPrivateObjectConverter);
}


OOEquipmentType *JSValueToEquipmentType(JSContext *context, jsval value)
{
	OOJS_PROFILE_ENTER
	
	if (JSVAL_IS_OBJECT(value))
	{
		JSObject *object = JSVAL_TO_OBJECT(value);
		if (ooscript::instanceOf(OOJSFCX(context), OOJSFOBJ(JSVAL_TO_OBJECT(value)), &sEquipmentInfoClass, nullptr))
		{
			return (OOEquipmentType *)ooscript::getPrivate(OOJSFCX(context), OOJSFOBJ(object));
		}
	}
	
	NSString *string = OOStringFromJSValue(context, value);
	if (string != nil)  return [OOEquipmentType equipmentTypeWithIdentifier:string];
	return nil;
	
	OOJS_PROFILE_EXIT
}


NSString *JSValueToEquipmentKey(JSContext *context, jsval value)
{
	return [JSValueToEquipmentType(context, value) identifier];
}


NSString *JSValueToEquipmentKeyRelaxed(JSContext *context, jsval value, BOOL *outExists)
{
	OOJS_PROFILE_ENTER
	
	NSString *result = nil;
	BOOL exists = NO;
	id objValue = OOJSNativeObjectFromJSValue(context, value);
	
	if ([objValue isKindOfClass:[OOEquipmentType class]])
	{
		result = [objValue identifier];
		exists = YES;
	}
	else if ([objValue isKindOfClass:[NSString class]])
	{
		/*	To enforce deliberate backwards incompatibility, reject strings
			ending with _DAMAGED unless someone actually named an equip that
			way.
		 */
		exists = [OOEquipmentType equipmentTypeWithIdentifier:objValue] != nil;
		if (exists || ![objValue hasSuffix:@"_DAMAGED"])
		{
			result = objValue;
		}
	}
	
	if (outExists != NULL)  *outExists = exists;
	return result;
	
	OOJS_PROFILE_EXIT
}


// *** Implementation stuff ***

namespace {
static bool EquipmentInfoGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *value_raw = reinterpret_cast<jsval*>(value);
	
	OOJS_NATIVE_ENTER(context)
	
	OOEquipmentType				*eqType = nil;
	id							result = nil;
	NSUInteger 					inst_time;
	
	if (EXPECT_NOT(!JSEquipmentInfoGetEquipmentType(context, thisObj, &eqType)))  return NO;
	
	switch (ooscript::idToInt32(propID))
	{
		case kEquipmentInfo_equipmentKey:
			result = [eqType identifier];
			break;
			
		case kEquipmentInfo_name:
			result = [eqType name];
			break;

		case kEquipmentInfo_calculatedPrice:
			if ([[eqType identifier] isEqual:@"EQ_FUEL"]) 
			{
				return ooscript::newNumberValue(cx, (PLAYER_MAX_FUEL - [OOPlayerForScripting() fuel]) * [eqType price] * [OOPlayerForScripting() fuelChargeRate], value);
			}
			else if ([[eqType identifier] isEqual:@"EQ_RENOVATION"]) 
			{
				return ooscript::newNumberValue(cx, [OOPlayerForScripting() renovationCosts], value);
			}
			else 
			{
				return ooscript::newNumberValue(cx, [OOPlayerForScripting() adjustPriceByScriptForEqKey:[eqType identifier] withCurrent:[eqType price]], value);
			}
		case kEquipmentInfo_canCarryMultiple:
			*value_raw = OOJSValueFromBOOL([eqType canCarryMultiple]);
			return YES;
			
		case kEquipmentInfo_canBeDamaged:
			*value_raw = OOJSValueFromBOOL([eqType canBeDamaged]);
			return YES;
			
		case kEquipmentInfo_description:
			result = [eqType descriptiveText];
			break;
			
		case kEquipmentInfo_damageProbability:
			return ooscript::newNumberValue(cx, [eqType damageProbability], value);

		case kEquipmentInfo_displayColor:
			result = [[eqType displayColor] normalizedArray];
			break;

		case kEquipmentInfo_fastAffinityDefensive:
			*value_raw = OOJSValueFromBOOL([eqType fastAffinityDefensive]);
			return YES;

		case kEquipmentInfo_fastAffinityOffensive:
			*value_raw = OOJSValueFromBOOL([eqType fastAffinityOffensive]);
			return YES;

		case kEquipmentInfo_defaultActivateKey:
			result = [eqType defaultActivateKey];
			break;		

		case kEquipmentInfo_defaultModeKey:
			result = [eqType defaultModeKey];
			break;		

		case kEquipmentInfo_techLevel:
			*value_raw = INT_TO_JSVAL((int32_t)[eqType techLevel]);
			return YES;
			
		case kEquipmentInfo_effectiveTechLevel:
			*value_raw = INT_TO_JSVAL((int32_t)[eqType effectiveTechLevel]);
			return YES;
			
		case kEquipmentInfo_price:
			return ooscript::newNumberValue(cx, [eqType price], value);

		case kEquipmentInfo_provides:
			result = [eqType providesForScripting];
			break;
		
		case kEquipmentInfo_installationTime:
			inst_time = [eqType installTime];
			if (inst_time == 0) 
			{
				inst_time = [eqType price] + 600;
			}
			*value_raw = INT_TO_JSVAL((int32_t)inst_time);
			return YES;

		case kEquipmentInfo_isAvailableToAll:
			*value_raw = OOJSValueFromBOOL([eqType isAvailableToAll]);
			return YES;
			
		case kEquipmentInfo_isAvailableToNPCs:
			*value_raw = OOJSValueFromBOOL([eqType isAvailableToNPCs]);
			return YES;
			
		case kEquipmentInfo_isAvailableToPlayer:
			*value_raw = OOJSValueFromBOOL([eqType isAvailableToPlayer]);
			return YES;

		case kEquipmentInfo_repairTime:
			*value_raw = INT_TO_JSVAL((int32_t)[eqType repairTime]);
			return YES;

		case kEquipmentInfo_requiresEmptyPylon:
			*value_raw = OOJSValueFromBOOL([eqType requiresEmptyPylon]);
			return YES;
			
		case kEquipmentInfo_requiresMountedPylon:
			*value_raw = OOJSValueFromBOOL([eqType requiresMountedPylon]);
			return YES;
			
		case kEquipmentInfo_requiresCleanLegalRecord:
			*value_raw = OOJSValueFromBOOL([eqType requiresCleanLegalRecord]);
			return YES;
			
		case kEquipmentInfo_requiresNonCleanLegalRecord:
			*value_raw = OOJSValueFromBOOL([eqType requiresNonCleanLegalRecord]);
			return YES;
			
		case kEquipmentInfo_requiresFreePassengerBerth:
			*value_raw = OOJSValueFromBOOL([eqType requiresFreePassengerBerth]);
			return YES;
			
		case kEquipmentInfo_requiresFullFuel:
			*value_raw = OOJSValueFromBOOL([eqType requiresFullFuel]);
			return YES;
			
		case kEquipmentInfo_requiresNonFullFuel:
			*value_raw = OOJSValueFromBOOL([eqType requiresNonFullFuel]);
			return YES;
			
		case kEquipmentInfo_isExternalStore:
			*value_raw = OOJSValueFromBOOL([eqType isMissileOrMine]);
			return YES;
			
		case kEquipmentInfo_isPortableBetweenShips:
			*value_raw = OOJSValueFromBOOL([eqType isPortableBetweenShips]);
			return YES;
			
		case kEquipmentInfo_isVisible:
			*value_raw = OOJSValueFromBOOL([eqType isVisible]);
			return YES;
			
		case kEquipmentInfo_requiredCargoSpace:
			*value_raw = INT_TO_JSVAL((int32_t)[eqType requiredCargoSpace]);
			return YES;
			
		case kEquipmentInfo_requiresEquipment:
			result = [[eqType requiresEquipment] allObjects];
			break;
			
		case kEquipmentInfo_requiresAnyEquipment:
			result = [[eqType requiresAnyEquipment] allObjects];
			break;
			
		case kEquipmentInfo_incompatibleEquipment:
			result = [[eqType incompatibleEquipment] allObjects];
			break;
			
		case kEquipmentInfo_scriptInfo:
			result = [eqType scriptInfo];
			if (result == nil)  result = [NSDictionary dictionary];	// empty rather than null
			break;
			
		case kEquipmentInfo_scriptName:
			result = [eqType scriptName];
			if (result == nil) result = @"";
			break;
			
		case kEquipmentInfo_weaponInfo:
			result = [eqType weaponInfo];
			if (result == nil)  result = [NSDictionary dictionary];	// empty rather than null
			break;
			
		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sEquipmentInfoPropertiesRaw);
			return NO;
	}
	
	*value_raw = OOJSValueFromNativeObject(context, result);
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool EquipmentInfoSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *value_raw = reinterpret_cast<jsval*>(value);
	
	OOJS_NATIVE_ENTER(context)
	
	OOEquipmentType				*eqType = nil;
	int32						iValue;
	OOColor						*colorForScript = nil;
	
	if (EXPECT_NOT(!JSEquipmentInfoGetEquipmentType(context, thisObj, &eqType)))  return NO;
	
	switch (ooscript::idToInt32(propID))
	{
		case kEquipmentInfo_displayColor:
			colorForScript = [OOColor colorWithDescription:OOJSNativeObjectFromJSValue(context, *value_raw)];
			if (colorForScript != nil || JSVAL_IS_NULL(*value_raw))
			{
				[eqType setDisplayColor:colorForScript];
				return YES;
			}
			break;
		case kEquipmentInfo_effectiveTechLevel:
			OOStandardsDeprecated([NSString stringWithFormat:@"TL99 for variable tech level is deprecated for %@",[eqType identifier]]);
			if (!OOEnforceStandards() && [eqType techLevel] == kOOVariableTechLevel)
			{
				if (JSVAL_IS_NULL(*value_raw)) 
				{
					// reset mission variable
					[OOPlayerForScripting() setMissionVariable:nil
														  forKey:[@"mission_TL_FOR_" stringByAppendingString:[eqType identifier]]];
					return YES;
				}
				if (ooscript::valueToInt32(cx, *value, &iValue))
				{
					if (iValue < 0)  iValue = 0;
					if (15 < iValue && iValue != kOOVariableTechLevel)  iValue = 15;
					[OOPlayerForScripting() setMissionVariable:[NSString stringWithFormat:@"%u", iValue]
														  forKey:[@"mission_TL_FOR_" stringByAppendingString:[eqType identifier]]];
					return YES;
				}
			}
			else
			{
				OOJSReportWarning(context, @"Cannot modify effective tech level for %@, because its base tech level is not 99.", [eqType identifier]);
				return YES;
			}
			break;
			
		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sEquipmentInfoPropertiesRaw);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, OOJSRJSID(propID), sEquipmentInfoPropertiesRaw, *value_raw);
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool EquipmentInfoGetAllEqipment(Context cx, Object /*obj*/, PropertyId /*propID*/, Value *value)
{
	JSContext *context = OOJSRCX(cx);
	jsval *value_raw = reinterpret_cast<jsval*>(value);
	
	OOJS_NATIVE_ENTER(context)
	
	*value_raw = OOJSValueFromNativeObject(context, [OOEquipmentType allEquipmentTypes]);
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace
	

@implementation OOEquipmentType (OOJavaScriptExtensions)

- (jsval) oo_jsValueInContext:(JSContext *)context
{
	if (_jsSelf == NULL)
	{
		_jsSelf = OOJSROBJ(ooscript::newObject(OOJSFCX(context), &sEquipmentInfoClass, OOJSFOBJ(sEquipmentInfoPrototype), nullptr));
		if (_jsSelf != NULL)
		{
			if (!ooscript::setPrivate(OOJSFCX(context), OOJSFOBJ(_jsSelf), [self retain]))  _jsSelf = NULL;
		}
	}
	
	return OBJECT_TO_JSVAL(_jsSelf);
}


- (NSString *) oo_jsClassName
{
	return @"EquipmentInfo";
}


- (void) oo_clearJSSelf:(JSObject *)selfVal
{
	if (_jsSelf == selfVal)  _jsSelf = NULL;
}

@end


// *** Static methods ***

// infoForKey(key : String): EquipmentInfo
namespace {
static bool EquipmentInfoStaticInfoForKey(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = reinterpret_cast<jsval*>(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	NSString					*key = nil;
	
	if (argc > 0)  key = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (key == nil)
	{
		OOJSReportBadArguments(context, @"EquipmentInfo", @"infoForKey", MIN(argc, 1U), OOJS_ARGV, nil, @"string");
		return NO;
	}
	
	OOJS_RETURN_OBJECT([OOEquipmentType equipmentTypeWithIdentifier:key]);
	
	OOJS_NATIVE_EXIT
}
} // namespace
