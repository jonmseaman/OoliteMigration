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

/*
	This is the Phase 1 seam 1.1x exemplar (bead oo-sdz): the first binding file retargeted onto
	the ooscript façade (JSEngine.hpp). Oolite's remaining ~110 binding files still speak jsapi
	(JSContext *, JSObject *, jsval, jsid) at their call sites and through OOJavaScriptEngine.h's
	OOJS_* argument-marshalling macros (OOJS_ARGV, OOJS_THIS, OOJS_RETURN_*), none of which are
	touched here or by later retarget beads: those macros are textually spelled "OOJS_...", never
	literally "JS_...", so they carry no engine name of their own and are out of scope for the
	sweep (docs/phases/1-js-engine.md work item 2 - "mechanical ... goldens must not move").

	What actually changes at each retargeted call site is only the small set of DIRECTLY spelled
	engine calls (InitClass, NewObject, SetPrivate, GetInstancePrivate, IsArrayObject,
	GetArrayLength, LookupElement, ValueToNumber, GetPrivate, InstanceOf, NewNumberValue,
	NewArrayObject, SetElement) and the class dispatch table (the PropertyStub / EnumerateStub /
	ResolveStub / ConvertStub family, replaced by nullptr hooks in ooscript::ClassDef per
	JSEngine.hpp). Native methods and class hooks that the
	façade's ClassDef/PropertySpec/FunctionSpec now dispatch through (VectorGetProperty,
	VectorSetProperty, VectorFinalize, VectorConstruct, and every JSFunctionSpec entry) take the
	façade's hook signature (ooscript::Context / Object / PropertyId / Value pointer / CallArgs
	reference) rather than the
	engine's; a tiny shim at the top of each recovers the old JSContext pointer, uintN and jsval
	pointer locals so the
	OOJS_* macros and the rest of each function body are UNCHANGED, because ooscript::Value and
	ooscript::PropertyId are byte copies of jsval and jsid (JSEngine.hpp's own contract, verified
	by the backend's static_asserts) and views onto them are therefore reinterpret_cast, not
	conversion. `this` and `private` are renamed to `thisObj`/`priv` because both are reserved
	words once this file compiles as Objective-C++ (ADR-0001; JSEngine.hpp's own header comment:
	"Consumers that are still Objective-C are compiled as Objective-C++ when they are retargeted").
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

// Byte-identical façade <-> jsapi views, local to this call site (JSEngine.hpp: Value/PropertyId
// and the handle types are byte copies of jsval/jsid/JS*; see the backend's own JSVP/OBJ/CX for
// the same, non-exported, pattern).
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
static inline Value     *OOJSFVALP(jsval *v)      { return reinterpret_cast<Value*>(v); }
} // namespace
namespace {
static inline Value      OOJSFVAL(jsval v)        { Value r; std::memcpy(&r, &v, sizeof r); return r; }
} // namespace
namespace {
static inline jsid       OOJSRJSID(PropertyId id) { jsid r; std::memcpy(&r, &id, sizeof r); return r; }
} // namespace


namespace {
static JSObject *sVectorPrototype;
} // namespace


namespace {
static BOOL GetThisVector(JSContext *context, JSObject *vectorObj, HPVector *outVector, NSString *method)  NONNULL_FUNC;
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
static bool VectorConstruct(Context cx, CallArgs &oojsArgs);
} // namespace

// Methods
namespace {
static bool VectorToString(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorToSource(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorAdd(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorSubtract(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorDistanceTo(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorSquaredDistanceTo(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorMultiply(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorDot(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorAngleTo(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorFromCoordinateSystem(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorToCoordinateSystem(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorCross(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorTripleProduct(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorDirection(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorMagnitude(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorSquaredMagnitude(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorRotationTo(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorRotateBy(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorToArray(Context cx, CallArgs &oojsArgs);
} // namespace

// Static methods
namespace {
static bool VectorStaticInterpolate(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorStaticRandom(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorStaticRandomDirection(Context cx, CallArgs &oojsArgs);
} // namespace
namespace {
static bool VectorStaticRandomDirectionAndLength(Context cx, CallArgs &oojsArgs);
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
	nullptr,			// newEnumerate (JSCLASS_NEW_ENUMERATE not used)
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

// A raw jsapi mirror of sVectorProperties, used only for the two bad-property error reporters
// in OOJavaScriptEngine.m (OOJSReportBadPropertySelector/Value): those helpers are outside this
// bead's scope (they are shared across every binding file and are retargeted, if at all, by a
// later seam) and still take a JSPropertySpec*, not ooscript::PropertySpec*.
namespace {
static JSPropertySpec sVectorPropertiesRaw[] =
{
	{ "x",						kVector_x,					OOJS_PROP_READWRITE_CB },
	{ "y",						kVector_y,					OOJS_PROP_READWRITE_CB },
	{ "z",						kVector_z,					OOJS_PROP_READWRITE_CB },
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

void InitOOJSVector(JSContext *context, JSObject *global)
{
	Object proto = ooscript::initClass(OOJSFCX(context), OOJSFOBJ(global), nullptr, &sVectorClass,
										VectorConstruct, 0, sVectorProperties, sVectorMethods,
										nullptr, sVectorStaticMethods);
	sVectorPrototype = OOJSROBJ(proto);
}


JSObject *JSVectorWithVector(JSContext *context, Vector vector)
{
	OOJS_PROFILE_ENTER
	
	JSObject				*result = NULL;
	HPVector					*priv = NULL;
	
	priv = static_cast<HPVector*>(malloc(sizeof *priv));
	if (EXPECT_NOT(priv == NULL))  return NULL;
	
	*priv = vectorToHPVector(vector);
	
	result = OOJSROBJ(ooscript::newObject(OOJSFCX(context), &sVectorClass, OOJSFOBJ(sVectorPrototype), nullptr));
	if (result != NULL)
	{
		if (EXPECT_NOT(!ooscript::setPrivate(OOJSFCX(context), OOJSFOBJ(result), priv)))  result = NULL;
	}
	
	if (EXPECT_NOT(result == NULL)) free(priv);
	
	return result;
	
	OOJS_PROFILE_EXIT
}


BOOL VectorToJSValue(JSContext *context, Vector vector, jsval *outValue)
{
	OOJS_PROFILE_ENTER
	
	JSObject				*object = NULL;
	
	assert(outValue != NULL);
	
	object = JSVectorWithVector(context, vector);
	if (EXPECT_NOT(object == NULL)) return NO;
	
	*outValue = OBJECT_TO_JSVAL(object);
	return YES;
	
	OOJS_PROFILE_EXIT
}

JSObject *JSVectorWithHPVector(JSContext *context, HPVector vector)
{
	OOJS_PROFILE_ENTER
	
	JSObject				*result = NULL;
	HPVector					*priv = NULL;
	
	priv = static_cast<HPVector*>(malloc(sizeof *priv));
	if (EXPECT_NOT(priv == NULL))  return NULL;
	
	*priv = vector;
	
	result = OOJSROBJ(ooscript::newObject(OOJSFCX(context), &sVectorClass, OOJSFOBJ(sVectorPrototype), nullptr));
	if (result != NULL)
	{
		if (EXPECT_NOT(!ooscript::setPrivate(OOJSFCX(context), OOJSFOBJ(result), priv)))  result = NULL;
	}
	
	if (EXPECT_NOT(result == NULL)) free(priv);
	
	return result;
	
	OOJS_PROFILE_EXIT
}


BOOL HPVectorToJSValue(JSContext *context, HPVector vector, jsval *outValue)
{
	OOJS_PROFILE_ENTER
	
	JSObject				*object = NULL;
	
	assert(outValue != NULL);
	
	object = JSVectorWithHPVector(context, vector);
	if (EXPECT_NOT(object == NULL)) return NO;
	
	*outValue = OBJECT_TO_JSVAL(object);
	return YES;
	
	OOJS_PROFILE_EXIT
}


BOOL NSPointToVectorJSValue(JSContext *context, NSPoint point, jsval *outValue)
{
	return VectorToJSValue(context, make_vector(point.x, point.y, 0), outValue);
}


BOOL JSValueToHPVector(JSContext *context, jsval value, HPVector *outVector)
{
	if (EXPECT_NOT(!JSVAL_IS_OBJECT(value)))  return NO;
	
	return JSObjectGetVector(context, JSVAL_TO_OBJECT(value), outVector);
}

BOOL JSValueToVector(JSContext *context, jsval value, Vector *outVector)
{
	if (EXPECT_NOT(!JSVAL_IS_OBJECT(value)))  return NO;
	HPVector tmp = kZeroHPVector;
	BOOL result = JSObjectGetVector(context, JSVAL_TO_OBJECT(value), &tmp);
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

- (NSString *) reportJSVectorStatistics
{
	VectorStatistics *stats = &sVectorConversionStats;
	
	NSUInteger sum = stats->vectorCount + stats->entityCount + stats->arrayCount + stats->protoCount;
	double convFac = 100.0 / sum;
	if (sum == 0)  convFac = 0;
	
	return [NSString stringWithFormat:
		   @" vector-to-vector conversions: %zu (%g %%)\n"
			" entity-to-vector conversions: %zu (%g %%)\n"
			"  array-to-vector conversions: %zu (%g %%)\n"
			"prototype-to-zero conversions: %zu (%g %%)\n"
			"             null conversions: %zu (%g %%)\n"
			"           failed conversions: %zu (%g %%)\n"
			"                        total: %zu",
			(long)stats->vectorCount, stats->vectorCount * convFac,
			(long)stats->entityCount, stats->entityCount * convFac,
			(long)stats->arrayCount, stats->arrayCount * convFac,
			(long)stats->protoCount, stats->protoCount * convFac,
			(long)stats->nullCount, stats->nullCount * convFac,
			(long)stats->failCount, stats->failCount * convFac,
			(long)sum];
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


BOOL JSObjectGetVector(JSContext *context, JSObject *vectorObj, HPVector *outVector)
{
	OOJS_PROFILE_ENTER
	
	assert(outVector != NULL);
	
	HPVector					*priv = NULL;
	std::uint32_t			arrayLength;
	jsval					arrayX, arrayY, arrayZ;
	jsdouble				x, y, z;
	
	Context cx = OOJSFCX(context);
	Object obj = OOJSFOBJ(vectorObj);
	
	// vectorObj can legitimately be NULL, e.g. when a null value is converted to a JSObject *.
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
			if (ooscript::lookupElement(cx, obj, 0, OOJSFVALP(&arrayX)) &&
				ooscript::lookupElement(cx, obj, 1, OOJSFVALP(&arrayY)) &&
				ooscript::lookupElement(cx, obj, 2, OOJSFVALP(&arrayZ)))
			{
				// ...use the three numbers as [x, y, z]
				if (ooscript::valueToNumber(cx, OOJSFVAL(arrayX), &x) &&
					ooscript::valueToNumber(cx, OOJSFVAL(arrayY), &y) &&
					ooscript::valueToNumber(cx, OOJSFVAL(arrayZ), &z))
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
static BOOL GetThisVector(JSContext *context, JSObject *vectorObj, HPVector *outVector, NSString *method)
{
	if (EXPECT(JSObjectGetVector(context, vectorObj, outVector)))  return YES;
	
	jsval arg = OBJECT_TO_JSVAL(vectorObj);
	OOJSReportBadArguments(context, @"Vector3D", method, 1, &arg, @"Invalid target object", @"Vector3D");
	return NO;
}
} // namespace


BOOL JSVectorSetVector(JSContext *context, JSObject *vectorObj, Vector vector)
{
	return JSVectorSetHPVector(context,vectorObj,vectorToHPVector(vector));
}


BOOL JSVectorSetHPVector(JSContext *context, JSObject *vectorObj, HPVector vector)
{
	OOJS_PROFILE_ENTER
	
	HPVector					*priv = NULL;
	
	if (EXPECT_NOT(vectorObj == NULL))  return NO;
	
	Context cx = OOJSFCX(context);
	Object obj = OOJSFOBJ(vectorObj);
	
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
static BOOL VectorFromArgumentListNoErrorInternal(JSContext *context, uintN argc, jsval *argv, HPVector *outVector, uintN *outConsumed, BOOL permitNumberList)
{
	OOJS_PROFILE_ENTER
	
	double				x, y, z;
	
	if (EXPECT_NOT(argc == 0))  return NO;
	assert(argv != NULL && outVector != NULL);
	
	if (outConsumed != NULL)  *outConsumed = 0;
	
	// Is first object a vector, array or entity?
	if (JSVAL_IS_OBJECT(argv[0]))
	{
		if (JSObjectGetVector(context, JSVAL_TO_OBJECT(argv[0]), outVector))
		{
			if (outConsumed != NULL)  *outConsumed = 1;
			return YES;
		}
	}
	
	if (!permitNumberList)  return NO;
	
	// As a special case for VectorConstruct(), look for three numbers.
	if (argc < 3)  return NO;
	
	// Given a string, valueToNumber() returns YES but provides a NaN number.
	Context cx = OOJSFCX(context);
	if (EXPECT_NOT(!ooscript::valueToNumber(cx, OOJSFVAL(argv[0]), &x) || isnan(x)))  return NO;
	if (EXPECT_NOT(!ooscript::valueToNumber(cx, OOJSFVAL(argv[1]), &y) || isnan(y)))  return NO;
	if (EXPECT_NOT(!ooscript::valueToNumber(cx, OOJSFVAL(argv[2]), &z) || isnan(z)))  return NO;
	
	// We got our three numbers.
	*outVector = make_HPvector(x, y, z);
	if (outConsumed != NULL)  *outConsumed = 3;
	
	return YES;
	
	OOJS_PROFILE_EXIT
}
} // namespace


// EMMSTRAN: remove outConsumed, since it can only be 1 except in failure (constructor is an exception, but it uses VectorFromArgumentListNoErrorInternal() directly).
BOOL VectorFromArgumentList(JSContext *context, NSString *scriptClass, NSString *function, uintN argc, jsval *argv, HPVector *outVector, uintN *outConsumed)
{
	if (VectorFromArgumentListNoErrorInternal(context, argc, argv, outVector, outConsumed, NO))  return YES;
	else
	{
		OOJSReportBadArguments(context, scriptClass, function, argc, argv,
							   @"Could not construct vector from parameters",
							   @"Vector, Entity or array of three numbers");
		return NO;
	}
}


BOOL VectorFromArgumentListNoError(JSContext *context, uintN argc, jsval *argv, HPVector *outVector, uintN *outConsumed)
{
	return VectorFromArgumentListNoErrorInternal(context, argc, argv, outVector, outConsumed, NO);
}


// *** Implementation stuff ***

namespace {
static bool VectorGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	
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
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sVectorPropertiesRaw);
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
	
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	
	OOJS_PROFILE_ENTER
	
	HPVector				vector;
	jsdouble			dval;
	
	if (EXPECT_NOT(!JSObjectGetVector(context, thisObj, &vector)))  return NO;
	if (EXPECT_NOT(!ooscript::valueToNumber(cx, *value, &dval)))
	{
		OOJSReportBadPropertyValue(context, thisObj, OOJSRJSID(propID), sVectorPropertiesRaw, *OOJSRVAL(value));
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
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sVectorPropertiesRaw);
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
static bool VectorConstruct(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	HPVector					vector = kZeroHPVector;
	HPVector					*priv = NULL;
	JSObject				*thisObj = NULL;
	
	priv = static_cast<HPVector*>(malloc(sizeof *priv));
	if (EXPECT_NOT(priv == NULL))  return NO;
	
	thisObj = OOJSROBJ(ooscript::newObject(cx, &sVectorClass, nullptr, nullptr));
	if (EXPECT_NOT(thisObj == NULL))  return NO;
	
	if (argc != 0)
	{
		if (EXPECT_NOT(!VectorFromArgumentListNoErrorInternal(context, argc, OOJS_ARGV, &vector, NULL, YES)))
		{
			free(priv);
			OOJSReportBadArguments(context, NULL, NULL, argc, OOJS_ARGV,
								   @"Could not construct vector from parameters",
								   @"Vector, Entity or array of three numbers");
			return NO;
		}
	}
	
	*priv = vector;
	
	if (EXPECT_NOT(!ooscript::setPrivate(cx, OOJSFOBJ(thisObj), priv)))
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
static bool VectorToString(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	HPVector					thisv;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"toString"))) return NO;
	
	OOJS_RETURN_OBJECT(HPVectorDescription(thisv));
	
	OOJS_NATIVE_EXIT
}
} // namespace


// toSource() : String
namespace {
static bool VectorToSource(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	HPVector					thisv;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"toSource"))) return NO;
	
	NSString *str = [NSString stringWithFormat:@"Vector3D(%g, %g, %g)", thisv.x, thisv.y, thisv.z];
	OOJS_RETURN_OBJECT(str);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// add(v : vectorExpression) : Vector3D
namespace {
static bool VectorAdd(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, thatv, result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"add"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, @"Vector3D", @"add", argc, OOJS_ARGV, &thatv, NULL)))  return NO;
	
	result = HPvector_add(thisv, thatv);
	
	OOJS_RETURN_HPVECTOR(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// subtract(v : vectorExpression) : Vector3D
namespace {
static bool VectorSubtract(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, thatv, result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"subtract"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, @"Vector3D", @"subtract", argc, OOJS_ARGV, &thatv, NULL)))  return NO;
	
	result = HPvector_subtract(thisv, thatv);
	
	OOJS_RETURN_HPVECTOR(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// distanceTo(v : vectorExpression) : Number
namespace {
static bool VectorDistanceTo(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, thatv;
	double						result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"distanceTo"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, @"Vector3D", @"distanceTo", argc, OOJS_ARGV, &thatv, NULL)))  return NO;
	
	result = HPdistance(thisv, thatv);
	
	OOJS_RETURN_DOUBLE(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// squaredDistanceTo(v : vectorExpression) : Number
namespace {
static bool VectorSquaredDistanceTo(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, thatv;
	double						result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"squaredDistanceTo"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, @"Vector3D", @"squaredDistanceTo", argc, OOJS_ARGV, &thatv, NULL)))  return NO;
	
	result = HPdistance2(thisv, thatv);
	
	OOJS_RETURN_DOUBLE(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// multiply(n : Number) : Vector3D
namespace {
static bool VectorMultiply(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, result;
	double						scalar;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"multiply"))) return NO;
	if (EXPECT_NOT(!OOJSArgumentListGetNumber(context, @"Vector3D", @"multiply", argc, OOJS_ARGV, &scalar, NULL)))  return NO;
	
	result = HPvector_multiply_scalar(thisv, scalar);
	
	OOJS_RETURN_HPVECTOR(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// dot(v : vectorExpression) : Number
namespace {
static bool VectorDot(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, thatv;
	double						result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"dot"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, @"Vector3D", @"dot", argc, OOJS_ARGV, &thatv, NULL)))  return NO;
	
	result = HPdot_product(thisv, thatv);
	
	OOJS_RETURN_DOUBLE(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// angleTo(v : vectorExpression) : Number
namespace {
static bool VectorAngleTo(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, thatv;
	double						result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"angleTo"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, @"Vector3D", @"angleTo", argc, OOJS_ARGV, &thatv, NULL)))  return NO;
	
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
static bool VectorCross(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, thatv, result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"cross"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, @"Vector3D", @"cross", argc, OOJS_ARGV, &thatv, NULL)))  return NO;
	
	result = HPtrue_cross_product(thisv, thatv);
	
	OOJS_RETURN_HPVECTOR(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// tripleProduct(v : vectorExpression, u : vectorExpression) : Number
namespace {
static bool VectorTripleProduct(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, thatv, theotherv;
	double						result;
	uintN						consumed;
	jsval						*argv = OOJS_ARGV;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"tripleProduct"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, @"Vector3D", @"tripleProduct", argc, argv, &thatv, &consumed)))  return NO;
	argc -= consumed;
	argv += consumed;
	if (EXPECT_NOT(!VectorFromArgumentList(context, @"Vector3D", @"tripleProduct", argc, argv, &theotherv, NULL)))  return NO;
	
	result = HPtriple_product(thisv, thatv, theotherv);
	
	OOJS_RETURN_DOUBLE(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// direction() : Vector3D
namespace {
static bool VectorDirection(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"direction"))) return NO;
	
	result = HPvector_normal(thisv);
	
	OOJS_RETURN_HPVECTOR(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// magnitude() : Number
namespace {
static bool VectorMagnitude(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv;
	double						result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"magnitude"))) return NO;
	
	result = HPmagnitude(thisv);
	
	OOJS_RETURN_DOUBLE(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// squaredMagnitude() : Number
namespace {
static bool VectorSquaredMagnitude(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv;
	double						result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"squaredMagnitude"))) return NO;
	
	result = HPmagnitude2(thisv);
	
	OOJS_RETURN_DOUBLE(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// rotationTo(v : vectorExpression [, limit : Number]) : Quaternion
namespace {
static bool VectorRotationTo(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, thatv;
	double						limit;
	BOOL						gotLimit;
	Quaternion					result;
	uintN						consumed;
	jsval						*argv = OOJS_ARGV;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"rotationTo"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, @"Vector3D", @"rotationTo", argc, OOJS_ARGV, &thatv, &consumed)))  return NO;
	
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
static bool VectorRotateBy(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv, result;
	Quaternion					q;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"rotateBy"))) return NO;
	if (EXPECT_NOT(!QuaternionFromArgumentList(context, @"Vector3D", @"rotateBy", argc, OOJS_ARGV, &q, NULL)))  return NO;
	
	result = quaternion_rotate_HPvector(q, thisv);
	
	OOJS_RETURN_HPVECTOR(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// toArray() : Array
namespace {
static bool VectorToArray(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	HPVector					thisv;
	JSObject				*result = NULL;
	jsval					nVal;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"toArray"))) return NO;
	
	result = OOJSROBJ(ooscript::newArrayObject(cx, 0, nullptr));
	if (result != NULL)
	{
		// We do this at the top because the return value slot is a GC root.
		OOJS_SET_RVAL(OBJECT_TO_JSVAL(result));
		
		Object resultObj = OOJSFOBJ(result);
		if (ooscript::newNumberValue(cx, thisv.x, OOJSFVALP(&nVal)) && ooscript::setElement(cx, resultObj, 0, OOJSFVALP(&nVal)) &&
			ooscript::newNumberValue(cx, thisv.y, OOJSFVALP(&nVal)) && ooscript::setElement(cx, resultObj, 1, OOJSFVALP(&nVal)) &&
			ooscript::newNumberValue(cx, thisv.z, OOJSFVALP(&nVal)) && ooscript::setElement(cx, resultObj, 2, OOJSFVALP(&nVal)))
		{
			return YES;
		}
		// If we get here, the conversion and stuffing in the previous condition failed.
		OOJS_SET_RVAL(JSVAL_VOID);
	}
	
	return YES;
	
	OOJS_PROFILE_EXIT
}
} // namespace


// toCoordinateSystem(coordScheme : String)
namespace {
static bool VectorToCoordinateSystem(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	HPVector				thisv;
	NSString			*coordScheme = nil;
	HPVector				result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"toCoordinateSystem"))) return NO;
	
	coordScheme = (argc >= 1) ? OOStringFromJSValue(context, OOJS_ARGV[0]) : nil;
	if (EXPECT_NOT(argc < 1 || coordScheme == nil))
	{
		OOJSReportBadArguments(context, @"Vector3D", @"toCoordinateSystem", MIN(argc, 1U), OOJS_ARGV, nil, @"coordinate system");
		return NO;
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	result = [UNIVERSE legacyPositionFrom:thisv asCoordinateSystem:coordScheme];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_HPVECTOR(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// fromCoordinateSystem(coordScheme : String)
namespace {
static bool VectorFromCoordinateSystem(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	HPVector				thisv;
	NSString			*coordScheme = nil;
	HPVector				result;
	
	if (EXPECT_NOT(!GetThisVector(context, OOJS_THIS, &thisv, @"fromCoordinateSystem"))) return NO;
	
	coordScheme = (argc >= 1) ? OOStringFromJSValue(context, OOJS_ARGV[0]) : nil;
	if (EXPECT_NOT(argc < 1 || coordScheme == nil))
	{
		OOJSReportBadArguments(context, @"Vector3D", @"fromCoordinateSystem", MIN(argc, 1U), OOJS_ARGV, nil, @"coordinate system");
		return NO;
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	NSString *arg = [NSString stringWithFormat:@"%@ %f %f %f", coordScheme, thisv.x, thisv.y, thisv.z];
	result = [UNIVERSE coordinatesFromCoordinateSystemString:arg];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_HPVECTOR(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// *** Static methods ***


// interpolate(v : Vector3D, u : Vector3D, alpha : Number) : Vector3D
namespace {
static bool VectorStaticInterpolate(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	HPVector					av, bv;
	double						interp;
	HPVector					result;
	uintN						consumed;
	uintN						inArgc = argc;
	jsval						*argv = OOJS_ARGV;
	jsval						*inArgv = argv;
	
	if (EXPECT_NOT(argc < 3))  goto INSUFFICIENT_ARGUMENTS;
	if (EXPECT_NOT(!VectorFromArgumentList(context, @"Vector3D", @"interpolate", argc, argv, &av, &consumed)))  return NO;
	argc -= consumed;
	argv += consumed;
	if (EXPECT_NOT(argc < 2))  goto INSUFFICIENT_ARGUMENTS;
	if (EXPECT_NOT(!VectorFromArgumentList(context, @"Vector3D", @"interpolate", argc, argv, &bv, &consumed)))  return NO;
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
static bool VectorStaticRandom(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	double					maxLength;
	
	if (argc == 0 || !OOJSArgumentListGetNumberNoError(context, argc, OOJS_ARGV, &maxLength, NULL))  maxLength = 1.0;
	
	OOJS_RETURN_HPVECTOR(OOHPVectorRandomSpatial(maxLength));
	
	OOJS_PROFILE_EXIT
}
} // namespace


// randomDirection([scale : Number]) : Vector3D
namespace {
static bool VectorStaticRandomDirection(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	double					scale;
	
	if (argc == 0 || !OOJSArgumentListGetNumberNoError(context, argc, OOJS_ARGV, &scale, NULL))  scale = 1.0;
	
	OOJS_RETURN_HPVECTOR(HPvector_multiply_scalar(OORandomUnitHPVector(), scale));
	
	OOJS_PROFILE_EXIT
}
} // namespace


// randomDirectionAndLength([maxLength : Number]) : Vector3D
namespace {
static bool VectorStaticRandomDirectionAndLength(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	double					maxLength;
	
	if (argc == 0 || !OOJSArgumentListGetNumberNoError(context, argc, OOJS_ARGV, &maxLength, NULL))  maxLength = 1.0;
	
	OOJS_RETURN_HPVECTOR(OOHPVectorRandomRadial(maxLength));
	
	OOJS_PROFILE_EXIT
}
} // namespace
