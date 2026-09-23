/*

OOJSEntity.mm

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

#import "OOJSEntity.h"
#import "OOJSVector.h"
#import "OOJSQuaternion.h"
#import "OOJavaScriptEngine.h"
#import "OOConstToJSString.h"
#import "EntityOOJavaScriptExtensions.h"
#import "OOJSCall.h"

#import "OOJSPlayer.h"
#import "PlayerEntity.h"
#import "ShipEntity.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, exemplar for this sweep, bead oo-oap): ClassDef replaces JSClass (stub hooks
	become nullptr), initClass replaces the engine's InitClass, and the getProperty/setProperty
	class hooks take the façade's Context/Object/PropertyId/Value* signature. A tiny shim at
	the top of each recovers the old JSContext pointer and jsid/jsval locals so the OOJS_*
	argument-marshalling macros and the rest of each function body are UNCHANGED, because
	ooscript::Value and ooscript::PropertyId are byte copies of jsval and jsid (JSEngine.hpp's
	own contract).

	gOOEntityJSClass (a plain JSClass) becomes sEntityClass (an ooscript::ClassDef); its raw
	jsapi JSClass* is still needed as the shared base for every other binding file's
	OOJSRegisterSubclass()/DEFINE_JS_OBJECT_GETTER() call (still unconverted upstream JS_*
	call sites in ~15 sibling files, out of this bead's scope), so JSEntityClass() now reads
	the backend's own engine-side JSClass* through sEntityClass.backend, exactly as
	OOJSSun.mm's RawSunClass() does for its own class.

	`this` is renamed to `thisObj` because it is a reserved word once this file compiles as
	Objective-C++ (ADR-0001).
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

// Byte-identical façade <-> jsapi views, local to this call site (see OOJSVector.mm for the
// same, non-exported, pattern).
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


// Adapts the shared jsapi OOJSObjectWrapperFinalize (OOJavaScriptEngine.m) to the façade's
// FinalizeHook signature, the same shim shape as OOJSSun.mm's SunFinalize.
namespace {
static void EntityFinalize(Context cx, Object obj)
{
	OOJSObjectWrapperFinalize(OOJSRCX(cx), OOJSROBJ(obj));
}
} // namespace


namespace {
static bool EntityGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool EntitySetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace
#ifndef NDEBUG
namespace {
static bool EntityDumpState(Context cx, CallArgs &oojsArgs);
} // namespace
#endif


JSObject		*gOOEntityJSPrototype;


namespace {
static ClassDef sEntityClass =
{
	"Entity",
	ClassFlag::HasPrivate,

	nullptr,				// addProperty (engine default: PropertyStub)
	nullptr,				// delProperty (engine default: PropertyStub)
	EntityGetProperty,		// getProperty
	EntitySetProperty,		// setProperty
	nullptr,				// enumerate (engine default: EnumerateStub)
	nullptr,				// newEnumerate (JSCLASS_NEW_ENUMERATE not used)
	nullptr,				// resolve (engine default: ResolveStub)
	nullptr,				// convert (engine default: ConvertStub)
	EntityFinalize,			// finalize
	nullptr,				// call
	nullptr,				// construct
	nullptr,				// backend: owned by the façade backend, must start null
};
} // namespace


namespace {
static inline JSClass *RawEntityClass(void)
{
	return reinterpret_cast<JSClass*>(sEntityClass.backend);
}
} // namespace


JSClass *JSEntityClass(void)
{
	return RawEntityClass();
}


enum : std::uint8_t
{
	// Property IDs
	kEntity_collisionRadius,	// collision radius, double, read-only.
	kEntity_distanceTravelled,	// distance travelled, double, read-only.
	kEntity_energy,				// energy, double, read-write.
	kEntity_heading,			// heading, vector, read-only (like orientation but ignoring twist angle)
	kEntity_mass,				// mass, double, read-only
	kEntity_maxEnergy,			// maxEnergy, double, read-only.
	kEntity_orientation,		// orientation, quaternion, read/write
	kEntity_owner,				// owner, Entity, read-only. (Parent ship for subentities, station for defense ships, launching ship for missiles etc)
	kEntity_position,			// position in system space, Vector, read/write
	kEntity_scanClass,			// scan class, string, read-only
	kEntity_spawnTime,			// spawn time, double, read-only.
	kEntity_status,				// entity status, string, read-only
	kEntity_isPlanet,			// is planet, boolean, read-only.
	kEntity_isPlayer,			// is player, boolean, read-only.
	kEntity_isShip,				// is ship, boolean, read-only.
	kEntity_isStation,			// is station, boolean, read-only.
	kEntity_isDock,				// is dock, boolean, read-only.
	kEntity_isSubEntity,		// is subentity, boolean, read-only.
	kEntity_isSun,				// is sun, boolean, read-only.
	kEntity_isSunlit,           // is sunlit, boolean, read-only.
	kEntity_isValid,			// is not stale, boolean, read-only.
	kEntity_isInSpace,			// is in space, boolean, read-only.
	kEntity_isVisible,			// is within drawing distance, boolean, read-only.
	kEntity_isVisualEffect,		// is visual effect, boolean, read-only.
	kEntity_isWormhole,		// is visual effect, boolean, read-only.
};


namespace {
static PropertySpec sEntityProperties[] =
{
	// JS name					ID							flags
	{ "collisionRadius",		kEntity_collisionRadius,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "distanceTravelled",		kEntity_distanceTravelled,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "energy",					kEntity_energy,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "heading",				kEntity_heading,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "mass",					kEntity_mass,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "maxEnergy",				kEntity_maxEnergy,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "orientation",			kEntity_orientation,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "owner",					kEntity_owner,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "position",				kEntity_position,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "scanClass",				kEntity_scanClass,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "spawnTime",				kEntity_spawnTime,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "status",					kEntity_status,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "isPlanet",				kEntity_isPlanet,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "isPlayer",				kEntity_isPlayer,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "isShip",					kEntity_isShip,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "isDock",					kEntity_isDock,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "isStation",				kEntity_isStation,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "isSubEntity",			kEntity_isSubEntity,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "isSun",					kEntity_isSun,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "isSunlit",               kEntity_isSunlit,           PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "isValid",				kEntity_isValid,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "isInSpace",				kEntity_isInSpace,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "isVisible",				kEntity_isVisible,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "isVisualEffect",			kEntity_isVisualEffect,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "isWormhole",			kEntity_isWormhole,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ 0 }
};
} // namespace


// A raw jsapi mirror of sEntityProperties, used only for the two bad-property error reporters
// in OOJavaScriptEngine.m (OOJSReportBadPropertySelector/Value): those helpers are shared
// across every binding file and still take a JSPropertySpec*, not ooscript::PropertySpec*
// (see OOJSVector.mm's sVectorPropertiesRaw for the same pattern).
namespace {
static JSPropertySpec sEntityPropertiesRaw[] =
{
	// JS name					ID							flags
	{ "collisionRadius",		kEntity_collisionRadius,	OOJS_PROP_READONLY_CB },
	{ "distanceTravelled",		kEntity_distanceTravelled,	OOJS_PROP_READONLY_CB },
	{ "energy",					kEntity_energy,				OOJS_PROP_READWRITE_CB },
	{ "heading",				kEntity_heading,			OOJS_PROP_READONLY_CB },
	{ "mass",					kEntity_mass,				OOJS_PROP_READONLY_CB },
	{ "maxEnergy",				kEntity_maxEnergy,			OOJS_PROP_READWRITE_CB },
	{ "orientation",			kEntity_orientation,		OOJS_PROP_READWRITE_CB },
	{ "owner",					kEntity_owner,				OOJS_PROP_READONLY_CB },
	{ "position",				kEntity_position,			OOJS_PROP_READWRITE_CB },
	{ "scanClass",				kEntity_scanClass,			OOJS_PROP_READWRITE_CB },
	{ "spawnTime",				kEntity_spawnTime,			OOJS_PROP_READONLY_CB },
	{ "status",					kEntity_status,				OOJS_PROP_READONLY_CB },
	{ "isPlanet",				kEntity_isPlanet,			OOJS_PROP_READONLY_CB },
	{ "isPlayer",				kEntity_isPlayer,			OOJS_PROP_READONLY_CB },
	{ "isShip",					kEntity_isShip,				OOJS_PROP_READONLY_CB },
	{ "isDock",					kEntity_isDock,				OOJS_PROP_READONLY_CB },
	{ "isStation",				kEntity_isStation,			OOJS_PROP_READONLY_CB },
	{ "isSubEntity",			kEntity_isSubEntity,		OOJS_PROP_READONLY_CB },
	{ "isSun",					kEntity_isSun,				OOJS_PROP_READONLY_CB },
	{ "isSunlit",               kEntity_isSunlit,           OOJS_PROP_READONLY_CB },
	{ "isValid",				kEntity_isValid,			OOJS_PROP_READONLY_CB },
	{ "isInSpace",				kEntity_isInSpace,			OOJS_PROP_READONLY_CB },
	{ "isVisible",				kEntity_isVisible,			OOJS_PROP_READONLY_CB },
	{ "isVisualEffect",			kEntity_isVisualEffect,		OOJS_PROP_READONLY_CB },
	{ "isWormhole",			kEntity_isWormhole,		OOJS_PROP_READONLY_CB },
	{ 0 }
};
} // namespace


namespace {
static bool EntityUnconstructableConstruct(Context cx, CallArgs &oojsArgs)
{
	return OOJSUnconstructableConstruct(OOJSRCX(cx), oojsArgs.count(), reinterpret_cast<jsval*>(oojsArgs.rawVp()));
}
} // namespace


// Adapts the shared jsapi OOJSObjectWrapperToString (OOJavaScriptEngine.m) to the façade's
// NativeFn signature, exactly as OOJSTimer.mm/OOJSSoundSource.mm/OOJSSystemInfo.mm do.
namespace {
static bool EntityToString(Context cx, CallArgs &oojsArgs)
{
	return OOJSObjectWrapperToString(OOJSRCX(cx), oojsArgs.count(), reinterpret_cast<jsval*>(oojsArgs.rawVp()));
}
} // namespace


namespace {
static FunctionSpec sEntityMethods[] =
{
	// JS name					Function					min args
	{ "toString",				EntityToString,				0,	0 },
#ifndef NDEBUG
	{ "dumpState",				EntityDumpState,			0,	0 },
#endif
	{ 0 }
};
} // namespace


void InitOOJSEntity(JSContext *context, JSObject *global)
{
	Object proto = ooscript::initClass(OOJSFCX(context), OOJSFOBJ(global), nullptr, &sEntityClass,
										EntityUnconstructableConstruct, 0, sEntityProperties, sEntityMethods,
										nullptr, nullptr);
	gOOEntityJSPrototype = OOJSROBJ(proto);
	OOJSRegisterObjectConverter(RawEntityClass(), OOJSBasicPrivateObjectConverter);
}


BOOL JSValueToEntity(JSContext *context, jsval value, Entity **outEntity)
{
	if (JSVAL_IS_OBJECT(value))
	{
		return OOJSEntityGetEntity(context, JSVAL_TO_OBJECT(value), outEntity);
	}
	
	return NO;
}


BOOL EntityFromArgumentList(JSContext *context, NSString *scriptClass, NSString *function, uintN argc, jsval *argv, Entity **outEntity, uintN *outConsumed)
{
	OOJS_PROFILE_ENTER
	
	// Sanity checks.
	if (outConsumed != NULL)  *outConsumed = 0;
	if (EXPECT_NOT(argc == 0 || argv == NULL || outEntity == NULL))
	{
		OOLogGenericParameterError();
		return NO;
	}
	
	// Get value, if possible.
	if (EXPECT_NOT(!JSValueToEntity(context, argv[0], outEntity)))
	{
		// Failed; report bad parameters, if given a class and function.
		if (scriptClass != nil && function != nil)
		{
			OOJSReportWarning(context, @"%@.%@(): expected entity, got %@.", scriptClass, function, [NSString stringWithJavaScriptParameters:argv count:1 inContext:context]);
			return NO;
		}
	}
	
	// Success.
	if (outConsumed != NULL)  *outConsumed = 1;
	return YES;
	
	OOJS_PROFILE_EXIT
}


namespace {
static bool EntityGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsval *jsValue = reinterpret_cast<jsval*>(value);
	
	OOJS_NATIVE_ENTER(context)
	
	Entity						*entity = nil;
	id							result = nil;
	
	if (EXPECT_NOT(!OOJSEntityGetEntity(context, thisObj, &entity))) return NO;
	if (OOIsStaleEntity(entity))
	{ 
		if (ooscript::idToInt32(propID) == kEntity_isValid)  *jsValue = JSVAL_FALSE;
		else  { *jsValue = JSVAL_VOID; }
		return YES;
	}
	
	switch (ooscript::idToInt32(propID))
	{
		case kEntity_collisionRadius:
			return ooscript::newNumberValue(cx, [entity collisionRadius], value);
	
		case kEntity_position:
			return HPVectorToJSValue(context, [entity position], jsValue);
		
		case kEntity_orientation:
			return QuaternionToJSValue(context, [entity normalOrientation], jsValue);
		
		case kEntity_heading:
			return VectorToJSValue(context, vector_forward_from_quaternion([entity normalOrientation]), jsValue);
		
		case kEntity_status:
			*jsValue = OOJSValueFromEntityStatus(context, [entity status]);
			return YES;
		
		case kEntity_scanClass:
			*jsValue = OOJSValueFromScanClass(context, [entity scanClass]);
			return YES;
		
		case kEntity_mass:
			return ooscript::newNumberValue(cx, [entity mass], value);
		
		case kEntity_owner:
			result = [entity owner];
			if (result == entity)  result = nil;
			break;
		
		case kEntity_energy:
			return ooscript::newNumberValue(cx, [entity energy], value);
		
		case kEntity_maxEnergy:
			return ooscript::newNumberValue(cx, [entity maxEnergy], value);
		
		case kEntity_isValid:
			*jsValue = [entity status] == STATUS_DEAD ? JSVAL_FALSE : JSVAL_TRUE;
			return YES;

		case kEntity_isInSpace:
			*jsValue = OOJSValueFromBOOL([entity isInSpace]);
			return YES;
		
		case kEntity_isShip:
			*jsValue = OOJSValueFromBOOL([entity isShip]);
			return YES;
		
		case kEntity_isStation:
			*jsValue = OOJSValueFromBOOL([entity isStation]);
			return YES;

		case kEntity_isDock:
			*jsValue = OOJSValueFromBOOL([entity isDock]);
			return YES;
			
		case kEntity_isSubEntity:
			*jsValue = OOJSValueFromBOOL([entity isSubEntity]);
			return YES;
		
		case kEntity_isPlayer:
			*jsValue = OOJSValueFromBOOL([entity isPlayer]);
			return YES;
			
		case kEntity_isPlanet:
			*jsValue = OOJSValueFromBOOL([entity isPlanet]);
			return YES;
			
		case kEntity_isSun:
			*jsValue = OOJSValueFromBOOL([entity isSun]);
			return YES;
		
		case kEntity_isSunlit:
			*jsValue = OOJSValueFromBOOL([entity isSunlit]);
			return YES;
			
		case kEntity_isVisible:
			*jsValue = OOJSValueFromBOOL([entity isVisible]);
			return YES;

		case kEntity_isVisualEffect:
			*jsValue = OOJSValueFromBOOL([entity isVisualEffect]);
			return YES;

		case kEntity_isWormhole:
			*jsValue = OOJSValueFromBOOL([entity isWormhole]);
			return YES;
			
		case kEntity_distanceTravelled:
			return ooscript::newNumberValue(cx, [entity distanceTravelled], value);
		
		case kEntity_spawnTime:
			return ooscript::newNumberValue(cx, [entity spawnTime], value);
		
		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sEntityPropertiesRaw);
	}
	
	*jsValue = OOJSValueFromNativeObject(context, result);
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool EntitySetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	
	OOJS_NATIVE_ENTER(context)
	
	Entity				*entity = nil;
	double				fValue;
	HPVector				hpvValue;
	Quaternion			qValue;
	
	if (EXPECT_NOT(!OOJSEntityGetEntity(context, thisObj, &entity)))  return NO;
	if (OOIsStaleEntity(entity))  return YES;
	
	switch (ooscript::idToInt32(propID))
	{
		case kEntity_position:
			if (JSValueToHPVector(context, *reinterpret_cast<jsval*>(value), &hpvValue))
			{
				[entity setPosition:hpvValue];
				if ([entity isShip])
				{
					[(ShipEntity *)entity resetExhaustPlumes];
					[(ShipEntity *)entity forceAegisCheck];
				}
				return YES;
			}
			break;
			
		case kEntity_orientation:
			if (JSValueToQuaternion(context, *reinterpret_cast<jsval*>(value), &qValue))
			{
				[entity setNormalOrientation:qValue];
				return YES;
			}
			break;
			
		case kEntity_energy:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				fValue = OOClamp_0_max_d(fValue, [entity maxEnergy]);
				[entity setEnergy:fValue];
				return YES;
			}
			break;

		case kEntity_maxEnergy:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				if (fValue <= 0.0)
				{
					OOJSReportError(context, @"entity.maxEnergy must be positive.");
					return NO;
				}
				[entity setMaxEnergy:fValue];
				return YES;
			}
			break;


		case kEntity_scanClass:
			if ([entity isShip] && ![entity isPlayer])
			{
				OOScanClass newClass = OOScanClassFromJSValue(context, *reinterpret_cast<jsval*>(value));
				if (newClass == CLASS_NOT_SET || newClass == CLASS_NO_DRAW || newClass == CLASS_TARGET || newClass == CLASS_WORMHOLE || newClass == CLASS_PLAYER || newClass == CLASS_VISUAL_EFFECT)
				{
					OOJSReportError(context, @"entity.scanClass cannot be set to that value.");
					return NO;
				}
				[entity setScanClass:newClass];
				return YES;
			}
			else
			{
				OOJSReportError(context, @"entity.scanClass is read-only except on NPC ships.");
				return NO;
			}
		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sEntityPropertiesRaw);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, OOJSRJSID(propID), sEntityPropertiesRaw, *reinterpret_cast<jsval*>(value));
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace


#ifndef NDEBUG
namespace {
static bool EntityDumpState(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = reinterpret_cast<jsval*>(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	Entity *thisEnt = nil;
	OOJSEntityGetEntity(context, OOJS_THIS, &thisEnt);
	[thisEnt dumpState];
	
	OOJS_RETURN_VOID;
	
	OOJS_PROFILE_EXIT	
}
} // namespace
#endif
