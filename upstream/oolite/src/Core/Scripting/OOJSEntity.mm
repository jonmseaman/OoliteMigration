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
#import "OOFoundationBridge.h"

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, exemplar for this sweep, bead oo-oap): the class table is a static ooscript::ClassDef
	(stub hooks become nullptr), initClass replaces the engine's InitClass, and the
	getProperty/setProperty class hooks and the natives take the façade's
	Context/Object/PropertyId/Value pointer/CallArgs signature directly.

	The Entity class, sEntityClass, is the shared base for every other entity binding file's
	OOJSRegisterSubclass()/DEFINE_JS_OBJECT_GETTER() call; JSEntityClass() returns it.

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

namespace {
static bool EntityGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool EntitySetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace
#ifndef NDEBUG
namespace {
static bool EntityDumpState(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
#endif


ooscript::Object gOOEntityJSPrototype;


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
	nullptr,				// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,				// resolve (engine default: ResolveStub)
	nullptr,				// convert (engine default: ConvertStub)
	OOJSObjectWrapperFinalize,			// finalize
	nullptr,				// call
	nullptr,				// construct
	nullptr,				// backend: owned by the façade backend, must start null
};
} // namespace


ooscript::ClassDef *JSEntityClass(void)
{
	return &sEntityClass;
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


namespace {
static FunctionSpec sEntityMethods[] =
{
	// JS name					Function					min args
	{ "toString",				OOJSObjectWrapperToString,				0,	0 },
#ifndef NDEBUG
	{ "dumpState",				EntityDumpState,			0,	0 },
#endif
	{ 0 }
};
} // namespace


void InitOOJSEntity(ooscript::Context context, ooscript::Object global)
{
	Object proto = ooscript::initClass((context), (global), nullptr, &sEntityClass,
										OOJSUnconstructableConstruct, 0, sEntityProperties, sEntityMethods,
										nullptr, nullptr);
	gOOEntityJSPrototype = (proto);
	OOJSRegisterObjectConverter(&sEntityClass, OOJSBasicPrivateObjectConverter);
}


BOOL JSValueToEntity(ooscript::Context context, ooscript::Value value, Entity **outEntity)
{
	if (ooscript::isObjectOrNull(value))
	{
		return OOJSEntityGetEntity(context, ooscript::toObject(value), outEntity);
	}
	
	return NO;
}


BOOL EntityFromArgumentList(ooscript::Context context, const std::optional<std::string> &scriptClass, const std::optional<std::string> &function, unsigned argc, ooscript::Value *argv, Entity **outEntity, unsigned *outConsumed)
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
		if (scriptClass.has_value() && function.has_value())
		{
			// The argument described as +stringWithJavaScriptParameters:count:1 described it: "(value)".
			const std::string parameters = "(" + oo::StdString(OOJSDescribeValue(context, argv[0], NO)) + ")";
			OOJSReportWarning(context, @"%@.%@(): expected entity, got %@.", oo::NSStringFrom(*scriptClass), oo::NSStringFrom(*function), oo::NSStringFrom(parameters));
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
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	
	OOJS_NATIVE_ENTER(context)
	
	Entity						*entity = nil;
	id							result = nil;
	
	if (EXPECT_NOT(!OOJSEntityGetEntity(context, thisObj, &entity))) return NO;
	if (OOIsStaleEntity(entity))
	{ 
		if (ooscript::idToInt32(propID) == kEntity_isValid)  *value = ooscript::falseValue();
		else  { *value = ooscript::undefinedValue(); }
		return YES;
	}
	
	switch (ooscript::idToInt32(propID))
	{
		case kEntity_collisionRadius:
			return ooscript::newNumberValue(cx, [entity collisionRadius], value);
	
		case kEntity_position:
			return HPVectorToJSValue(context, [entity position], value);
		
		case kEntity_orientation:
			return QuaternionToJSValue(context, [entity normalOrientation], value);
		
		case kEntity_heading:
			return VectorToJSValue(context, vector_forward_from_quaternion([entity normalOrientation]), value);
		
		case kEntity_status:
			*value = OOJSValueFromEntityStatus(context, [entity status]);
			return YES;
		
		case kEntity_scanClass:
			*value = OOJSValueFromScanClass(context, [entity scanClass]);
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
			*value = [entity status] == STATUS_DEAD ? ooscript::falseValue() : ooscript::trueValue();
			return YES;

		case kEntity_isInSpace:
			*value = OOJSValueFromBOOL([entity isInSpace]);
			return YES;
		
		case kEntity_isShip:
			*value = OOJSValueFromBOOL([entity isShip]);
			return YES;
		
		case kEntity_isStation:
			*value = OOJSValueFromBOOL([entity isStation]);
			return YES;

		case kEntity_isDock:
			*value = OOJSValueFromBOOL([entity isDock]);
			return YES;
			
		case kEntity_isSubEntity:
			*value = OOJSValueFromBOOL([entity isSubEntity]);
			return YES;
		
		case kEntity_isPlayer:
			*value = OOJSValueFromBOOL([entity isPlayer]);
			return YES;
			
		case kEntity_isPlanet:
			*value = OOJSValueFromBOOL([entity isPlanet]);
			return YES;
			
		case kEntity_isSun:
			*value = OOJSValueFromBOOL([entity isSun]);
			return YES;
		
		case kEntity_isSunlit:
			*value = OOJSValueFromBOOL([entity isSunlit]);
			return YES;
			
		case kEntity_isVisible:
			*value = OOJSValueFromBOOL([entity isVisible]);
			return YES;

		case kEntity_isVisualEffect:
			*value = OOJSValueFromBOOL([entity isVisualEffect]);
			return YES;

		case kEntity_isWormhole:
			*value = OOJSValueFromBOOL([entity isWormhole]);
			return YES;
			
		case kEntity_distanceTravelled:
			return ooscript::newNumberValue(cx, [entity distanceTravelled], value);
		
		case kEntity_spawnTime:
			return ooscript::newNumberValue(cx, [entity spawnTime], value);
		
		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sEntityProperties);
	}
	
	*value = OOJSValueFromNativeObject(context, result);
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool EntitySetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	
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
			if (JSValueToHPVector(context, *value, &hpvValue))
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
			if (JSValueToQuaternion(context, *value, &qValue))
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
				OOScanClass newClass = OOScanClassFromJSValue(context, *value);
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
			OOJSReportBadPropertySelector(context, thisObj, (propID), sEntityProperties);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, (propID), sEntityProperties, *value);
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace


#ifndef NDEBUG
namespace {
static bool EntityDumpState(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_PROFILE_ENTER
	
	Entity *thisEnt = nil;
	OOJSEntityGetEntity(context, OOJS_THIS, &thisEnt);
	[thisEnt dumpState];
	
	OOJS_RETURN_VOID;
	
	OOJS_PROFILE_EXIT	
}
} // namespace
#endif
