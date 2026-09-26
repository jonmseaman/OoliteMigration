/*

OOJSVector.mm

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

#import "OOJSVector.h"
#import "OOJavaScriptEngine.h"

#if OOLITE_GNUSTEP
#import <GNUstepBase/GSObjCRuntime.h>
#else
#import <objc/objc-runtime.h>
#endif

#import "OOConstToString.h"
#import "OOJSEntity.h"
#import "OOJSQuaternion.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>
#import "OOFoundationBridge.h"

/*
	This is the Phase 1 seam 1.1x exemplar (bead oo-sdz): the first binding file retargeted onto
	the ooscript façade (JSEngine.hpp); every other binding file follows its style. Nothing here
	includes the engine's own header or names its types: handles are ooscript::Context /
	Object / Value / PropertyId, and OOJavaScriptEngine.h's OOJS_* argument-marshalling macros
	(OOJS_ARGV, OOJS_THIS, OOJS_RETURN_*) expand to the ooscript::CallArgs accessors.

	The class dispatch table is a static ooscript::ClassDef (the engine's PropertyStub /
	EnumerateStub / ResolveStub / ConvertStub family become nullptr hooks), and each engine call
	(InitClass, NewObject, SetPrivate, GetInstancePrivate, IsArrayObject, GetArrayLength,
	LookupElement, ValueToNumber, GetPrivate, InstanceOf, NewNumberValue, NewArrayObject,
	SetElement) is its ooscript:: equivalent with the same calling convention. Class hooks
	(VectorGetProperty, VectorSetProperty, VectorFinalize) and natives (VectorConstruct and every
	ooscript::FunctionSpec entry) take the façade's hook signature directly (ooscript::Context /
	Object / PropertyId / Value pointer / CallArgs reference); a native that consumes its
	arguments piecemeal copies oojsArgs.count() into a local argc first. `this` and `private` are
	renamed to `thisObj`/`priv` because both are reserved words once this file compiles as
	Objective-C++ (ADR-0001; JSEngine.hpp's own header comment: "Consumers that are still
	Objective-C are compiled as Objective-C++ when they are retargeted").
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
static ooscript::Object sVectorPrototype;
} // namespace


namespace {
static BOOL GetThisVector(ooscript::Context context, ooscript::Object vectorObj, HPVector *outVector, const std::string &method)  NONNULL_FUNC;
} // namespace


namespace {
static bool VectorGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool VectorSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace
namespace {
static void VectorFinalize(Context cx, Object obj);
} // namespace
namespace {
static bool VectorConstruct(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace

// Methods
namespace {
static bool VectorToString(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorToSource(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorAdd(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorSubtract(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorDistanceTo(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorSquaredDistanceTo(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorMultiply(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorDot(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorAngleTo(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorFromCoordinateSystem(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorToCoordinateSystem(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorCross(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorTripleProduct(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorDirection(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorMagnitude(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorSquaredMagnitude(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorRotationTo(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorRotateBy(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorToArray(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace

// Static methods
namespace {
static bool VectorStaticInterpolate(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorStaticRandom(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorStaticRandomDirection(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorStaticRandomDirectionAndLength(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace


namespace {
static ClassDef sVectorClass =
{
	"Vector3D",
	ClassFlag::HasPrivate,

	nullptr,			// addProperty (engine default: PropertyStub)
	nullptr,			// delProperty (engine default: PropertyStub)
	VectorGetProperty,	// getProperty
	VectorSetProperty,	// setProperty
	nullptr,			// enumerate (engine default: EnumerateStub)
	nullptr,			// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,			// resolve (engine default: ResolveStub)
	nullptr,			// convert (engine default: ConvertStub)
	VectorFinalize,		// finalize
	nullptr,			// call
	nullptr,			// construct
	nullptr,			// backend: owned by the façade backend, must start null
};
} // namespace


enum : std::uint8_t
{
	// Property IDs
	kVector_x,
	kVector_y,
	kVector_z
};


namespace {
static PropertySpec sVectorProperties[] =
{
	// JS name					ID							flags									getter		setter
	{ "x",						kVector_x,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "y",						kVector_y,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "z",						kVector_z,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ 0 }
};
} // namespace

namespace {
static FunctionSpec sVectorMethods[] =
{
	// JS name					Function					min args	flags
	{ "toSource",				VectorToSource,				0,			0 },
	{ "toString",				VectorToString,				0,			0 },
	{ "add",					VectorAdd,					1,			0 },
	{ "angleTo",				VectorAngleTo,				1,			0 },
	{ "cross",					VectorCross,				1,			0 },
	{ "direction",				VectorDirection,			0,			0 },
	{ "distanceTo",				VectorDistanceTo,			1,			0 },
	{ "dot",					VectorDot,					1,			0 },
	{ "fromCoordinateSystem",	VectorFromCoordinateSystem,	1,			0 },
	{ "magnitude",				VectorMagnitude,			0,			0 },
	{ "multiply",				VectorMultiply,				1,			0 },
	{ "rotateBy",				VectorRotateBy,				1,			0 },
	{ "rotationTo",				VectorRotationTo,			1,			0 },
	{ "squaredDistanceTo",		VectorSquaredDistanceTo,	1,			0 },
	{ "squaredMagnitude",		VectorSquaredMagnitude,		0,			0 },
	{ "subtract",				VectorSubtract,				1,			0 },
	{ "toArray",				VectorToArray,				0,			0 },
	{ "toCoordinateSystem",		VectorToCoordinateSystem,	1,			0 },
	{ "tripleProduct",			VectorTripleProduct,		2,			0 },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sVectorStaticMethods[] =
{
	// JS name							Function								min args	flags
	{ "interpolate",					VectorStaticInterpolate,				3,			0 },
	{ "random",							VectorStaticRandom,						0,			0 },
	{ "randomDirection",				VectorStaticRandomDirection, 			0,			0 },
	{ "randomDirectionAndLength",		VectorStaticRandomDirectionAndLength,	0,			0 },
	{ 0 }
};
} // namespace


// *** Public ***

void InitOOJSVector(ooscript::Context context, ooscript::Object global)
{
	Object proto = ooscript::initClass((context), (global), nullptr, &sVectorClass,
										VectorConstruct, 0, sVectorProperties, sVectorMethods,
										nullptr, sVectorStaticMethods);
	sVectorPrototype = (proto);
}


ooscript::Object JSVectorWithVector(ooscript::Context context, Vector vector)
{
	OOJS_PROFILE_ENTER
	
	ooscript::Object result = NULL;
	HPVector					*priv = NULL;
	
	priv = static_cast<HPVector*>(malloc(sizeof *priv));
	if (EXPECT_NOT(priv == NULL))  return NULL;
	
	*priv = vectorToHPVector(vector);
	
	result = (ooscript::newObject((context), &sVectorClass, (sVectorPrototype), nullptr));
	if (result != NULL)
	{
		if (EXPECT_NOT(!ooscript::setPrivate((context), (result), priv)))  result = NULL;
	}
	
	if (EXPECT_NOT(result == NULL)) free(priv);
	
	return result;
	
	OOJS_PROFILE_EXIT
}


BOOL VectorToJSValue(ooscript::Context context, Vector vector, ooscript::Value *outValue)
{
	OOJS_PROFILE_ENTER
	
	ooscript::Object object = NULL;
	
	assert(outValue != NULL);
	
	object = JSVectorWithVector(context, vector);
	if (EXPECT_NOT(object == NULL)) return NO;
	
	*outValue = ooscript::objectValue(object);
	return YES;
	
	OOJS_PROFILE_EXIT
}

ooscript::Object JSVectorWithHPVector(ooscript::Context context, HPVector vector)
{
	OOJS_PROFILE_ENTER
	
	ooscript::Object result = NULL;
	HPVector					*priv = NULL;
	
	priv = static_cast<HPVector*>(malloc(sizeof *priv));
	if (EXPECT_NOT(priv == NULL))  return NULL;
	
	*priv = vector;
	
	result = (ooscript::newObject((context), &sVectorClass, (sVectorPrototype), nullptr));
	if (result != NULL)
	{
		if (EXPECT_NOT(!ooscript::setPrivate((context), (result), priv)))  result = NULL;
	}
	
	if (EXPECT_NOT(result == NULL)) free(priv);
	
	return result;
	
	OOJS_PROFILE_EXIT
}


BOOL HPVectorToJSValue(ooscript::Context context, HPVector vector, ooscript::Value *outValue)
{
	OOJS_PROFILE_ENTER
	
	ooscript::Object object = NULL;
	
	assert(outValue != NULL);
	
	object = JSVectorWithHPVector(context, vector);
	if (EXPECT_NOT(object == NULL)) return NO;
	
	*outValue = ooscript::objectValue(object);
	return YES;
	
	OOJS_PROFILE_EXIT
}


BOOL NSPointToVectorJSValue(ooscript::Context context, NSPoint point, ooscript::Value *outValue)
{
	return VectorToJSValue(context, make_vector(point.x, point.y, 0), outValue);
}


BOOL JSValueToHPVector(ooscript::Context context, ooscript::Value value, HPVector *outVector)
{
	if (EXPECT_NOT(!ooscript::isObjectOrNull(value)))  return NO;
	
	return JSObjectGetVector(context, ooscript::toObject(value), outVector);
}

BOOL JSValueToVector(ooscript::Context context, ooscript::Value value, Vector *outVector)
{
	if (EXPECT_NOT(!ooscript::isObjectOrNull(value)))  return NO;
	HPVector tmp = kZeroHPVector;
	BOOL result = JSObjectGetVector(context, ooscript::toObject(value), &tmp);
	*outVector = HPVectorToVector(tmp);
	return result;
}


#if OO_DEBUG

typedef struct
{
	NSUInteger			vectorCount;
	NSUInteger			entityCount;
	NSUInteger			arrayCount;
	NSUInteger			protoCount;
	NSUInteger			nullCount;
	NSUInteger			failCount;
} VectorStatistics;
namespace {
static VectorStatistics sVectorConversionStats;
} // namespace


@implementation PlayerEntity (JSVectorStatistics)

// :setM vectorStats PS.callObjC("reportJSVectorStatistics")
// :vectorStats

- (id) reportJSVectorStatistics	// shared selector (proposed ADR-0043): called by name from JavaScript (callObjC)
{
	VectorStatistics *stats = &sVectorConversionStats;
	
	NSUInteger sum = stats->vectorCount + stats->entityCount + stats->arrayCount + stats->protoCount;
	double convFac = 100.0 / sum;
	if (sum == 0)  convFac = 0;
	
	return oo::NSStringFrom(oo::str::format(
		   " vector-to-vector conversions: %zu (%g %%)\n"
			" entity-to-vector conversions: %zu (%g %%)\n"
			"  array-to-vector conversions: %zu (%g %%)\n"
			"prototype-to-zero conversions: %zu (%g %%)\n"
			"             null conversions: %zu (%g %%)\n"
			"           failed conversions: %zu (%g %%)\n"
			"                        total: %zu",
			(size_t)stats->vectorCount, stats->vectorCount * convFac,
			(size_t)stats->entityCount, stats->entityCount * convFac,
			(size_t)stats->arrayCount, stats->arrayCount * convFac,
			(size_t)stats->protoCount, stats->protoCount * convFac,
			(size_t)stats->nullCount, stats->nullCount * convFac,
			(size_t)stats->failCount, stats->failCount * convFac,
			(size_t)sum));
}


- (void) clearJSVectorStatistics
{
	memset(&sVectorConversionStats, 0, sizeof sVectorConversionStats);
}

@end

#define COUNT(FIELD) do { sVectorConversionStats.FIELD++; } while (0)

#else

#define COUNT(FIELD) do {} while (0)

#endif


BOOL JSObjectGetVector(ooscript::Context context, ooscript::Object vectorObj, HPVector *outVector)
{
	OOJS_PROFILE_ENTER
	
	assert(outVector != NULL);
	
	HPVector					*priv = NULL;
	std::uint32_t			arrayLength;
	ooscript::Value					arrayX, arrayY, arrayZ;
	double				x, y, z;
	
	Context cx = (context);
	Object obj = (vectorObj);
	
	// vectorObj can legitimately be NULL, e.g. when a null value is converted to a ooscript::Object .
	if (EXPECT_NOT(vectorObj == NULL))
	{
		COUNT(nullCount);
		return NO;
	}
	
	// If this is a (JS) Vector...
	priv = static_cast<HPVector*>(ooscript::getInstancePrivate(cx, obj, &sVectorClass, nullptr));
	if (EXPECT(priv != NULL))
	{
		COUNT(vectorCount);
		*outVector = *priv;
		return YES;
	}
	
	// If it's an array...
	if (EXPECT(ooscript::isArrayObject(cx, obj)))
	{
		// ...and it has exactly three elements...
		if (ooscript::getArrayLength(cx, obj, &arrayLength) && arrayLength == 3)
		{
			if (ooscript::lookupElement(cx, obj, 0, (&arrayX)) &&
				ooscript::lookupElement(cx, obj, 1, (&arrayY)) &&
				ooscript::lookupElement(cx, obj, 2, (&arrayZ)))
			{
				// ...use the three numbers as [x, y, z]
				if (ooscript::valueToNumber(cx, (arrayX), &x) &&
					ooscript::valueToNumber(cx, (arrayY), &y) &&
					ooscript::valueToNumber(cx, (arrayZ), &z))
				{
					COUNT(arrayCount);
					*outVector = make_HPvector(x, y, z);
					return YES;
				}
			}
		}
	}
	
	// If it's an entity, use its position.
	if (OOJSIsMemberOfSubclass(context, vectorObj, JSEntityClass()))
	{
		COUNT(entityCount);
		Entity *entity = [(id)ooscript::getPrivate(cx, obj) weakRefUnderlyingObject];
		*outVector = [entity position];
		return YES;
	}
	
	/*
		If it's actually a Vector3D but with no private field (this happens for
		Vector3D.prototype)...
		
		NOTE: it would be prettier to do this at the top when we handle normal
		Vector3Ds, but it's a rare case which should be kept off the fast path.
	*/
	if (ooscript::instanceOf(cx, obj, &sVectorClass, nullptr))
	{
		COUNT(protoCount);
		*outVector = kZeroHPVector;
		return YES;
	}
	
	COUNT(failCount);
	return NO;
	
	OOJS_PROFILE_EXIT
}


namespace {
static BOOL GetThisVector(ooscript::Context context, ooscript::Object vectorObj, HPVector *outVector, const std::string &method)
{
	if (EXPECT(JSObjectGetVector(context, vectorObj, outVector)))  return YES;
	
	ooscript::Value arg = ooscript::objectValue(vectorObj);
	OOJSReportBadArguments(context, @"Vector3D", oo::NSStringFrom(method), 1, &arg, @"Invalid target object", @"Vector3D");
	return NO;
}
} // namespace


BOOL JSVectorSetVector(ooscript::Context context, ooscript::Object vectorObj, Vector vector)
{
	return JSVectorSetHPVector(context,vectorObj,vectorToHPVector(vector));
}


BOOL JSVectorSetHPVector(ooscript::Context context, ooscript::Object vectorObj, HPVector vector)
{
	OOJS_PROFILE_ENTER
	
	HPVector					*priv = NULL;
	
	if (EXPECT_NOT(vectorObj == NULL))  return NO;
	
	Context cx = (context);
	Object obj = (vectorObj);
	
	priv = static_cast<HPVector*>(ooscript::getInstancePrivate(cx, obj, &sVectorClass, nullptr));
	if (priv != NULL)	// If this is a (JS) Vector...
	{
		*priv = vector;
		return YES;
	}
	
	if (ooscript::instanceOf(cx, obj, &sVectorClass, nullptr))
	{
		// Silently fail for the prototype.
		return YES;
	}
	
	return NO;
	
	OOJS_PROFILE_EXIT
}


namespace {
static BOOL VectorFromArgumentListNoErrorInternal(ooscript::Context context, unsigned argc, ooscript::Value *argv, HPVector *outVector, unsigned *outConsumed, BOOL permitNumberList)
{
	OOJS_PROFILE_ENTER
	
	double				x, y, z;
	
	if (EXPECT_NOT(argc == 0))  return NO;
	assert(argv != NULL && outVector != NULL);
	
	if (outConsumed != NULL)  *outConsumed = 0;
	
	// Is first object a vector, array or entity?
	if (ooscript::isObjectOrNull(argv[0]))
	{
		if (JSObjectGetVector(context, ooscript::toObject(argv[0]), outVector))
		{
			if (outConsumed != NULL)  *outConsumed = 1;
			return YES;
		}
	}
	
	if (!permitNumberList)  return NO;
	
	// As a special case for VectorConstruct(), look for three numbers.
	if (argc < 3)  return NO;
	
	// Given a string, valueToNumber() returns YES but provides a NaN number.
	Context cx = (context);
	if (EXPECT_NOT(!ooscript::valueToNumber(cx, (argv[0]), &x) || isnan(x)))  return NO;
	if (EXPECT_NOT(!ooscript::valueToNumber(cx, (argv[1]), &y) || isnan(y)))  return NO;
	if (EXPECT_NOT(!ooscript::valueToNumber(cx, (argv[2]), &z) || isnan(z)))  return NO;
	
	// We got our three numbers.
	*outVector = make_HPvector(x, y, z);
	if (outConsumed != NULL)  *outConsumed = 3;
	
	return YES;
	
	OOJS_PROFILE_EXIT
}
} // namespace


// EMMSTRAN: remove outConsumed, since it can only be 1 except in failure (constructor is an exception, but it uses VectorFromArgumentListNoErrorInternal() directly).
BOOL VectorFromArgumentList(ooscript::Context context, const std::string &scriptClass, const std::string &function, unsigned argc, ooscript::Value *argv, HPVector *outVector, unsigned *outConsumed)
{
	if (VectorFromArgumentListNoErrorInternal(context, argc, argv, outVector, outConsumed, NO))  return YES;
	else
	{
		OOJSReportBadArguments(context, oo::NSStringFrom(scriptClass), oo::NSStringFrom(function), argc, argv,
							   @"Could not construct vector from parameters",
							   @"Vector, Entity or array of three numbers");
		return NO;
	}
}


BOOL VectorFromArgumentListNoError(ooscript::Context context, unsigned argc, ooscript::Value *argv, HPVector *outVector, unsigned *outConsumed)
{
	return VectorFromArgumentListNoErrorInternal(context, argc, argv, outVector, outConsumed, NO);
}


// *** Implementation stuff ***

namespace {
static bool VectorGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	
	OOJS_PROFILE_ENTER
	
	HPVector				vector;
	OOHPScalar				fValue;
	
	if (EXPECT_NOT(!JSObjectGetVector(context, thisObj, &vector)))  return NO;
	
	switch (ooscript::idToInt32(propID))
	{
		case kVector_x:
			fValue = vector.x;
			break;
		
		case kVector_y:
			fValue = vector.y;
			break;
		
		case kVector_z:
			fValue = vector.z;
			break;
		
		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sVectorProperties);
			return NO;
	}
	
	return ooscript::newNumberValue(cx, fValue, value);
	
	OOJS_PROFILE_EXIT
}
} // namespace


namespace {
static bool VectorSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	
	OOJS_PROFILE_ENTER
	
	HPVector				vector;
	double			dval;
	
	if (EXPECT_NOT(!JSObjectGetVector(context, thisObj, &vector)))  return NO;
	if (EXPECT_NOT(!ooscript::valueToNumber(cx, *value, &dval)))
	{
		OOJSReportBadPropertyValue(context, thisObj, (propID), sVectorProperties, *(value));
		return NO;
	}
	
	switch (ooscript::idToInt32(propID))
	{
		case kVector_x:
			vector.x = dval;
			break;
		
		case kVector_y:
			vector.y = dval;
			break;
		
		case kVector_z:
			vector.z = dval;
			break;
		
		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sVectorProperties);
			return NO;
	}
	
	return JSVectorSetHPVector(context, thisObj, vector);
	
	OOJS_PROFILE_EXIT
}
} // namespace


namespace {
static void VectorFinalize(Context cx, Object obj)
{
	OOJS_PROFILE_ENTER
	
	Vector					*priv = NULL;
	
	priv = static_cast<Vector*>(ooscript::getInstancePrivate(cx, obj, &sVectorClass, nullptr));
	if (priv != NULL)
	{
		free(priv);
	}
	
	OOJS_PROFILE_EXIT_VOID
}
} // namespace


namespace {
static bool VectorConstruct(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	HPVector					vector = kZeroHPVector;
	HPVector					*priv = NULL;
	ooscript::Object thisObj = NULL;
	
	priv = static_cast<HPVector*>(malloc(sizeof *priv));
	if (EXPECT_NOT(priv == NULL))  return NO;
	
	thisObj = (ooscript::newObject(context, &sVectorClass, nullptr, nullptr));
	if (EXPECT_NOT(thisObj == NULL))  return NO;
	
	if (oojsArgs.count() != 0)
	{
		if (EXPECT_NOT(!VectorFromArgumentListNoErrorInternal(context, oojsArgs.count(), OOJS_ARGV, &vector, NULL, YES)))
		{
			free(priv);
			OOJSReportBadArguments(context, NULL, NULL, oojsArgs.count(), OOJS_ARGV,
								   @"Could not construct vector from parameters",
								   @"Vector, Entity or array of three numbers");
			return NO;
		}
	}
	
	*priv = vector;
	
	if (EXPECT_NOT(!ooscript::setPrivate(context, (thisObj), priv)))
	{
		free(priv);
		return NO;
	}
	
	OOJS_RETURN_JSOBJECT(thisObj);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// *** Methods ***

// toString() : String
namespace {
static bool VectorToString(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	HPVector					thisv;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "toString"))) return NO;
	
	OOJS_RETURN_OBJECT(HPVectorDescription(thisv));
	
	OOJS_NATIVE_EXIT
}
} // namespace


// toSource() : String
namespace {
static bool VectorToSource(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	HPVector					thisv;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "toSource"))) return NO;
	
	OOJS_RETURN_OBJECT(oo::NSStringFrom(oo::str::format("Vector3D(%g, %g, %g)", thisv.x, thisv.y, thisv.z)));
	
	OOJS_NATIVE_EXIT
}
} // namespace


// add(v : vectorExpression) : Vector3D
namespace {
static bool VectorAdd(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, thatv, result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "add"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, "Vector3D", "add", oojsArgs.count(), OOJS_ARGV, &thatv, NULL)))  return NO;
	
	result = HPvector_add(thisv, thatv);
	
	OOJS_RETURN_HPVECTOR(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// subtract(v : vectorExpression) : Vector3D
namespace {
static bool VectorSubtract(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, thatv, result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "subtract"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, "Vector3D", "subtract", oojsArgs.count(), OOJS_ARGV, &thatv, NULL)))  return NO;
	
	result = HPvector_subtract(thisv, thatv);
	
	OOJS_RETURN_HPVECTOR(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// distanceTo(v : vectorExpression) : Number
namespace {
static bool VectorDistanceTo(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, thatv;
	double						result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "distanceTo"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, "Vector3D", "distanceTo", oojsArgs.count(), OOJS_ARGV, &thatv, NULL)))  return NO;
	
	result = HPdistance(thisv, thatv);
	
	OOJS_RETURN_DOUBLE(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// squaredDistanceTo(v : vectorExpression) : Number
namespace {
static bool VectorSquaredDistanceTo(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, thatv;
	double						result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "squaredDistanceTo"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, "Vector3D", "squaredDistanceTo", oojsArgs.count(), OOJS_ARGV, &thatv, NULL)))  return NO;
	
	result = HPdistance2(thisv, thatv);
	
	OOJS_RETURN_DOUBLE(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// multiply(n : Number) : Vector3D
namespace {
static bool VectorMultiply(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, result;
	double						scalar;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "multiply"))) return NO;
	if (EXPECT_NOT(!OOJSArgumentListGetNumber(context, @"Vector3D", @"multiply", oojsArgs.count(), OOJS_ARGV, &scalar, NULL)))  return NO;
	
	result = HPvector_multiply_scalar(thisv, scalar);
	
	OOJS_RETURN_HPVECTOR(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// dot(v : vectorExpression) : Number
namespace {
static bool VectorDot(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, thatv;
	double						result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "dot"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, "Vector3D", "dot", oojsArgs.count(), OOJS_ARGV, &thatv, NULL)))  return NO;
	
	result = HPdot_product(thisv, thatv);
	
	OOJS_RETURN_DOUBLE(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// angleTo(v : vectorExpression) : Number
namespace {
static bool VectorAngleTo(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, thatv;
	double						result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "angleTo"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, "Vector3D", "angleTo", oojsArgs.count(), OOJS_ARGV, &thatv, NULL)))  return NO;
	
	result = HPdot_product(HPvector_normal(thisv), HPvector_normal(thatv));
	if (result > 1.0) result = 1.0;
	if (result < -1.0) result = -1.0;
	// for identical vectors the dot_product sometimes returns a value > 1.0 because of rounding errors, resulting
	// in an undefined result for the acos.
	result = acos(result);
	
	OOJS_RETURN_DOUBLE(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// cross(v : vectorExpression) : Vector3D
namespace {
static bool VectorCross(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, thatv, result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "cross"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, "Vector3D", "cross", oojsArgs.count(), OOJS_ARGV, &thatv, NULL)))  return NO;
	
	result = HPtrue_cross_product(thisv, thatv);
	
	OOJS_RETURN_HPVECTOR(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// tripleProduct(v : vectorExpression, u : vectorExpression) : Number
namespace {
static bool VectorTripleProduct(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, thatv, theotherv;
	double						result;
	unsigned						consumed;
	unsigned						argc = oojsArgs.count();
	ooscript::Value						*argv = OOJS_ARGV;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "tripleProduct"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, "Vector3D", "tripleProduct", argc, argv, &thatv, &consumed)))  return NO;
	argc -= consumed;
	argv += consumed;
	if (EXPECT_NOT(!VectorFromArgumentList(context, "Vector3D", "tripleProduct", argc, argv, &theotherv, NULL)))  return NO;
	
	result = HPtriple_product(thisv, thatv, theotherv);
	
	OOJS_RETURN_DOUBLE(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// direction() : Vector3D
namespace {
static bool VectorDirection(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "direction"))) return NO;
	
	result = HPvector_normal(thisv);
	
	OOJS_RETURN_HPVECTOR(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// magnitude() : Number
namespace {
static bool VectorMagnitude(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv;
	double						result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "magnitude"))) return NO;
	
	result = HPmagnitude(thisv);
	
	OOJS_RETURN_DOUBLE(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// squaredMagnitude() : Number
namespace {
static bool VectorSquaredMagnitude(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv;
	double						result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "squaredMagnitude"))) return NO;
	
	result = HPmagnitude2(thisv);
	
	OOJS_RETURN_DOUBLE(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// rotationTo(v : vectorExpression [, limit : Number]) : Quaternion
namespace {
static bool VectorRotationTo(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, thatv;
	double						limit;
	BOOL						gotLimit;
	Quaternion					result;
	unsigned						consumed;
	unsigned						argc = oojsArgs.count();
	ooscript::Value						*argv = OOJS_ARGV;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "rotationTo"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, "Vector3D", "rotationTo", argc, OOJS_ARGV, &thatv, &consumed)))  return NO;
	
	argc -= consumed;
	argv += consumed;
	if (argc != 0)	// limit parameter is optional.
	{
		if (EXPECT_NOT(!OOJSArgumentListGetNumber(context, @"Vector3D", @"rotationTo", argc, argv, &limit, NULL)))  return NO;
		gotLimit = YES;
	}
	else gotLimit = NO;
	
	if (gotLimit)  result = quaternion_limited_rotation_between(HPVectorToVector(thisv), HPVectorToVector(thatv), limit);
	else  result = quaternion_rotation_between(HPVectorToVector(thisv), HPVectorToVector(thatv));
	
	OOJS_RETURN_QUATERNION(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// rotateBy(q : quaternionExpression) : Vector3D
namespace {
static bool VectorRotateBy(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, result;
	Quaternion					q;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "rotateBy"))) return NO;
	if (EXPECT_NOT(!QuaternionFromArgumentList(context, "Vector3D", "rotateBy", oojsArgs.count(), OOJS_ARGV, &q, NULL)))  return NO;
	
	result = quaternion_rotate_HPvector(q, thisv);
	
	OOJS_RETURN_HPVECTOR(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// toArray() : Array
namespace {
static bool VectorToArray(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv;
	ooscript::Object result = NULL;
	ooscript::Value					nVal;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "toArray"))) return NO;
	
	result = (ooscript::newArrayObject(context, 0, nullptr));
	if (result != NULL)
	{
		// We do this at the top because the return value slot is a GC root.
		OOJS_SET_RVAL(ooscript::objectValue(result));
		
		Object resultObj = (result);
		if (ooscript::newNumberValue(context, thisv.x, (&nVal)) && ooscript::setElement(context, resultObj, 0, (&nVal)) &&
			ooscript::newNumberValue(context, thisv.y, (&nVal)) && ooscript::setElement(context, resultObj, 1, (&nVal)) &&
			ooscript::newNumberValue(context, thisv.z, (&nVal)) && ooscript::setElement(context, resultObj, 2, (&nVal)))
		{
			return YES;
		}
		// If we get here, the conversion and stuffing in the previous condition failed.
		OOJS_SET_RVAL(ooscript::undefinedValue());
	}
	
	return YES;
	
	OOJS_PROFILE_EXIT
}
} // namespace


// toCoordinateSystem(coordScheme : String)
namespace {
static bool VectorToCoordinateSystem(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	HPVector				thisv;
	std::optional<std::string>	coordScheme;
	HPVector				result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "toCoordinateSystem"))) return NO;
	
	if (oojsArgs.count() >= 1)  coordScheme = oo::OptionalString(OOStringFromJSValue(context, OOJS_ARGV[0]));
	if (EXPECT_NOT(oojsArgs.count() < 1 || !coordScheme.has_value()))
	{
		OOJSReportBadArguments(context, @"Vector3D", @"toCoordinateSystem", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"coordinate system");
		return NO;
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	result = [UNIVERSE legacyPositionFrom:thisv asCoordinateSystem:oo::NSStringFrom(*coordScheme)];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_HPVECTOR(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// fromCoordinateSystem(coordScheme : String)
namespace {
static bool VectorFromCoordinateSystem(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	HPVector				thisv;
	std::optional<std::string>	coordScheme;
	HPVector				result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, "fromCoordinateSystem"))) return NO;
	
	if (oojsArgs.count() >= 1)  coordScheme = oo::OptionalString(OOStringFromJSValue(context, OOJS_ARGV[0]));
	if (EXPECT_NOT(oojsArgs.count() < 1 || !coordScheme.has_value()))
	{
		OOJSReportBadArguments(context, @"Vector3D", @"fromCoordinateSystem", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"coordinate system");
		return NO;
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	std::string arg = oo::str::format("%s %f %f %f", coordScheme->c_str(), thisv.x, thisv.y, thisv.z);
	result = [UNIVERSE coordinatesFromCoordinateSystemString:oo::NSStringFrom(arg)];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_HPVECTOR(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// *** Static methods ***


// interpolate(v : Vector3D, u : Vector3D, alpha : Number) : Vector3D
namespace {
static bool VectorStaticInterpolate(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	HPVector					av, bv;
	double						interp;
	HPVector					result;
	unsigned						consumed;
	unsigned						argc = oojsArgs.count();
	unsigned						inArgc = argc;
	ooscript::Value						*argv = OOJS_ARGV;
	ooscript::Value						*inArgv = argv;
	
	if (EXPECT_NOT(argc < 3))  goto INSUFFICIENT_ARGUMENTS;
	if (EXPECT_NOT(!VectorFromArgumentList(context, "Vector3D", "interpolate", argc, argv, &av, &consumed)))  return NO;
	argc -= consumed;
	argv += consumed;
	if (EXPECT_NOT(argc < 2))  goto INSUFFICIENT_ARGUMENTS;
	if (EXPECT_NOT(!VectorFromArgumentList(context, "Vector3D", "interpolate", argc, argv, &bv, &consumed)))  return NO;
	argc -= consumed;
	argv += consumed;
	if (EXPECT_NOT(argc < 1))  goto INSUFFICIENT_ARGUMENTS;
	if (EXPECT_NOT(!OOJSArgumentListGetNumber(context, @"Vector3D", @"interpolate", argc, argv, &interp, NULL)))  return NO;
	
	result = OOHPVectorInterpolate(av, bv, interp);
	
	OOJS_RETURN_HPVECTOR(result);
	
INSUFFICIENT_ARGUMENTS:
	OOJSReportBadArguments(context, @"Vector3D", @"interpolate", inArgc, inArgv, 
								   @"Insufficient parameters",
								   @"vector expression, vector expression and number");
	return NO;
	
	OOJS_PROFILE_EXIT
}
} // namespace


// random([maxLength : Number]) : Vector3D
namespace {
static bool VectorStaticRandom(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	double					maxLength;
	
	if (oojsArgs.count() == 0 || !OOJSArgumentListGetNumberNoError(context, oojsArgs.count(), OOJS_ARGV, &maxLength, NULL))  maxLength = 1.0;
	
	OOJS_RETURN_HPVECTOR(OOHPVectorRandomSpatial(maxLength));
	
	OOJS_PROFILE_EXIT
}
} // namespace


// randomDirection([scale : Number]) : Vector3D
namespace {
static bool VectorStaticRandomDirection(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	double					scale;
	
	if (oojsArgs.count() == 0 || !OOJSArgumentListGetNumberNoError(context, oojsArgs.count(), OOJS_ARGV, &scale, NULL))  scale = 1.0;
	
	OOJS_RETURN_HPVECTOR(HPvector_multiply_scalar(OORandomUnitHPVector(), scale));
	
	OOJS_PROFILE_EXIT
}
} // namespace


// randomDirectionAndLength([maxLength : Number]) : Vector3D
namespace {
static bool VectorStaticRandomDirectionAndLength(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_PROFILE_ENTER
	
	double					maxLength;
	
	if (oojsArgs.count() == 0 || !OOJSArgumentListGetNumberNoError(context, oojsArgs.count(), OOJS_ARGV, &maxLength, NULL))  maxLength = 1.0;
	
	OOJS_RETURN_HPVECTOR(OOHPVectorRandomRadial(maxLength));
	
	OOJS_PROFILE_EXIT
}
} // namespace
