/*

OOJSQuaternion.mm

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

#import "OOJSQuaternion.h"
#import "OOJavaScriptEngine.h"

#if OOLITE_GNUSTEP
#import <GNUstepBase/GSObjCRuntime.h>
#else
#import <objc/objc-runtime.h>
#endif

#import "OOConstToString.h"
#import "OOJSEntity.h"
#import "OOJSVector.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) per bead oo-45g, the same way bead oo-sdz
	retargeted OOJSVector.mm (the exemplar for this sweep; see its header comment for the full
	rationale). `this` and `private` are renamed to `thisObj`/`priv` because both are reserved
	words once this file compiles as Objective-C++ (ADR-0001).
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
// and the handle types are byte copies of jsval/jsid/JS*; see OOJSVector.mm for the same,
// non-exported, pattern).
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
static JSObject *sQuaternionPrototype;
} // namespace


namespace {
static BOOL GetThisQuaternion(JSContext *context, JSObject *quaternionObj, Quaternion *outQuaternion, NSString *method)  NONNULL_FUNC;

static bool QuaternionGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
static bool QuaternionSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
static void QuaternionFinalize(Context cx, Object obj);
static bool QuaternionConstruct(Context cx, CallArgs &oojsArgs);

// Methods
static bool QuaternionToString(Context cx, CallArgs &oojsArgs);
static bool QuaternionToSource(Context cx, CallArgs &oojsArgs);
static bool QuaternionMultiply(Context cx, CallArgs &oojsArgs);
static bool QuaternionDot(Context cx, CallArgs &oojsArgs);
static bool QuaternionRotate(Context cx, CallArgs &oojsArgs);
static bool QuaternionRotateX(Context cx, CallArgs &oojsArgs);
static bool QuaternionRotateY(Context cx, CallArgs &oojsArgs);
static bool QuaternionRotateZ(Context cx, CallArgs &oojsArgs);
static bool QuaternionNormalize(Context cx, CallArgs &oojsArgs);
static bool QuaternionConjugate(Context cx, CallArgs &oojsArgs);
static bool QuaternionVectorForward(Context cx, CallArgs &oojsArgs);
static bool QuaternionVectorUp(Context cx, CallArgs &oojsArgs);
static bool QuaternionVectorRight(Context cx, CallArgs &oojsArgs);
static bool QuaternionToArray(Context cx, CallArgs &oojsArgs);

// Static methods
static bool QuaternionStaticRandom(Context cx, CallArgs &oojsArgs);
} // namespace


namespace {
static ClassDef sQuaternionClass =
{
	"Quaternion",
	ClassFlag::HasPrivate,

	nullptr,				// addProperty (engine default: PropertyStub)
	nullptr,				// delProperty (engine default: PropertyStub)
	QuaternionGetProperty,	// getProperty
	QuaternionSetProperty,	// setProperty
	nullptr,				// enumerate (engine default: EnumerateStub)
	nullptr,				// newEnumerate (JSCLASS_NEW_ENUMERATE not used)
	nullptr,				// resolve (engine default: ResolveStub)
	nullptr,				// convert (engine default: ConvertStub)
	QuaternionFinalize,		// finalize
	nullptr,				// call
	nullptr,				// construct
	nullptr,				// backend: owned by the façade backend, must start null
};
} // namespace


enum : std::uint8_t
{
	// Property IDs
	kQuaternion_w,
	kQuaternion_x,
	kQuaternion_y,
	kQuaternion_z
};


namespace {
static PropertySpec sQuaternionProperties[] =
{
	// JS name						ID							flags										getter		setter
	{ "w",							kQuaternion_w,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "x",							kQuaternion_x,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "y",							kQuaternion_y,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "z",							kQuaternion_z,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ 0 }
};
} // namespace

// A raw jsapi mirror of sQuaternionProperties, used only for the two bad-property error reporters
// in OOJavaScriptEngine.m (OOJSReportBadPropertySelector/Value): those helpers are outside this
// bead's scope (they are shared across every binding file and are retargeted, if at all, by a
// later seam) and still take a JSPropertySpec*, not ooscript::PropertySpec*.
namespace {
static JSPropertySpec sQuaternionPropertiesRaw[] =
{
	{ "w",							kQuaternion_w,				OOJS_PROP_READWRITE_CB },
	{ "x",							kQuaternion_x,				OOJS_PROP_READWRITE_CB },
	{ "y",							kQuaternion_y,				OOJS_PROP_READWRITE_CB },
	{ "z",							kQuaternion_z,				OOJS_PROP_READWRITE_CB },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sQuaternionMethods[] =
{
	// JS name						Function					min args	flags
	{ "toString",					QuaternionToString,			0,			0 },
	{ "toSource",					QuaternionToSource,			0,			0 },
	{ "dot",						QuaternionDot,				1,			0 },
	{ "multiply",					QuaternionMultiply,			1,			0 },
	{ "normalize",					QuaternionNormalize,		0,			0 },
	{ "conjugate",					QuaternionConjugate,		0,			0 },
	{ "rotate",						QuaternionRotate,			2,			0 },
	{ "rotateX",					QuaternionRotateX,			1,			0 },
	{ "rotateY",					QuaternionRotateY,			1,			0 },
	{ "rotateZ",					QuaternionRotateZ,			1,			0 },
	{ "toArray",					QuaternionToArray,			0,			0 },
	{ "vectorForward",				QuaternionVectorForward,	0,			0 },
	{ "vectorRight",				QuaternionVectorRight,		0,			0 },
	{ "vectorUp",					QuaternionVectorUp,			0,			0 },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sQuaternionStaticMethods[] =
{
	// JS name						Function					min args	flags
	{ "random",						QuaternionStaticRandom,		0,			0 },
	{ 0 }
};
} // namespace


// *** Public ***

void InitOOJSQuaternion(JSContext *context, JSObject *global)
{
	Object proto = ooscript::initClass(OOJSFCX(context), OOJSFOBJ(global), nullptr, &sQuaternionClass,
										QuaternionConstruct, 4, sQuaternionProperties, sQuaternionMethods,
										nullptr, sQuaternionStaticMethods);
	sQuaternionPrototype = OOJSROBJ(proto);
}


JSObject *JSQuaternionWithQuaternion(JSContext *context, Quaternion quaternion)
{
	OOJS_PROFILE_ENTER
	
	JSObject				*result = NULL;
	Quaternion				*priv = NULL;
	
	priv = static_cast<Quaternion*>(malloc(sizeof *priv));
	if (EXPECT_NOT(priv == NULL))  return NULL;
	
	*priv = quaternion;
	
	result = OOJSROBJ(ooscript::newObject(OOJSFCX(context), &sQuaternionClass, OOJSFOBJ(sQuaternionPrototype), nullptr));
	if (result != NULL)
	{
		if (EXPECT_NOT(!ooscript::setPrivate(OOJSFCX(context), OOJSFOBJ(result), priv)))  result = NULL;
	}
	
	if (EXPECT_NOT(result == NULL)) free(priv);
	
	return result;
	
	OOJS_PROFILE_EXIT
}


BOOL QuaternionToJSValue(JSContext *context, Quaternion quaternion, jsval *outValue)
{
	OOJS_PROFILE_ENTER
	
	JSObject				*object = NULL;
	
	assert(outValue != NULL);
	
	object = JSQuaternionWithQuaternion(context, quaternion);
	if (EXPECT_NOT(object == NULL)) return NO;
	
	*outValue = OBJECT_TO_JSVAL(object);
	return YES;
	
	OOJS_PROFILE_EXIT
}


BOOL JSValueToQuaternion(JSContext *context, jsval value, Quaternion *outQuaternion)
{
	if (EXPECT_NOT(!JSVAL_IS_OBJECT(value)))  return NO;
	
	return JSObjectGetQuaternion(context, JSVAL_TO_OBJECT(value), outQuaternion);
}


#if OO_DEBUG

typedef struct
{
	NSUInteger			quatCount;
	NSUInteger			entityCount;
	NSUInteger			arrayCount;
	NSUInteger			protoCount;
	NSUInteger			nullCount;
	NSUInteger			failCount;
} QuaternionStatistics;
namespace {
static QuaternionStatistics sQuaternionConversionStats;
} // namespace


@implementation PlayerEntity (JSQuaternionStatistics)

// :setM quatStats PS.callObjC("reportJSQuaternionStatistics")
// :quatStats

- (NSString *) reportJSQuaternionStatistics
{
	QuaternionStatistics *stats = &sQuaternionConversionStats;
	
	NSUInteger sum = stats->quatCount + stats->entityCount + stats->arrayCount + stats->protoCount;
	double convFac = 100.0 / sum;
	
	return [NSString stringWithFormat:
		   @"quaternion-to-quaternion conversions: %zu (%g %%)\n"
			"    entity-to-quaternion conversions: %zu (%g %%)\n"
			"     array-to-quaternion conversions: %zu (%g %%)\n"
			"       prototype-to-zero conversions: %zu (%g %%)\n"
			"                    null conversions: %zu (%g %%)\n"
			"                  failed conversions: %zu (%g %%)\n"
			"                               total: %zu",
			(long)stats->quatCount, stats->quatCount * convFac,
			(long)stats->entityCount, stats->entityCount * convFac,
			(long)stats->arrayCount, stats->arrayCount * convFac,
			(long)stats->protoCount, stats->protoCount * convFac,
			(long)stats->nullCount, stats->nullCount * convFac,
			(long)stats->failCount, stats->failCount * convFac,
			(long)sum];
}


- (void) clearJSQuaternionStatistics
{
	memset(&sQuaternionConversionStats, 0, sizeof sQuaternionConversionStats);
}

@end

#define COUNT(FIELD) do { sQuaternionConversionStats.FIELD++; } while (0)

#else

#define COUNT(FIELD) do {} while (0)

#endif


BOOL JSObjectGetQuaternion(JSContext *context, JSObject *quaternionObj, Quaternion *outQuaternion)
{
	OOJS_PROFILE_ENTER
	
	assert(outQuaternion != NULL);
	
	Quaternion				*priv = NULL;
	std::uint32_t			arrayLength;
	jsval					arrayW, arrayX, arrayY, arrayZ;
	jsdouble				dVal;
	
	Context cx = OOJSFCX(context);
	Object obj = OOJSFOBJ(quaternionObj);
	
	// quaternionObj can legitimately be NULL, e.g. when a null value is converted to a JSObject *.
	if (EXPECT_NOT(quaternionObj == NULL))
	{
		COUNT(nullCount);
		return NO;
	}
	
	// If this is a (JS) Quaternion...
	priv = static_cast<Quaternion*>(ooscript::getInstancePrivate(cx, obj, &sQuaternionClass, nullptr));
	if (EXPECT(priv != NULL))
	{
		COUNT(quatCount);
		*outQuaternion = *priv;
		return YES;
	}
	
	// If it's an array...
	if (EXPECT(ooscript::isArrayObject(cx, obj)))
	{
		// ...and it has exactly four elements...
		if (ooscript::getArrayLength(cx, obj, &arrayLength) && arrayLength == 4)
		{
			if (ooscript::lookupElement(cx, obj, 0, OOJSFVALP(&arrayW)) &&
				ooscript::lookupElement(cx, obj, 1, OOJSFVALP(&arrayX)) &&
				ooscript::lookupElement(cx, obj, 2, OOJSFVALP(&arrayY)) &&
				ooscript::lookupElement(cx, obj, 3, OOJSFVALP(&arrayZ)))
			{
				// ...use the four numbers as [w, x, y, z]
				if (!ooscript::valueToNumber(cx, OOJSFVAL(arrayW), &dVal))  return NO;
				outQuaternion->w = dVal;
				if (!ooscript::valueToNumber(cx, OOJSFVAL(arrayX), &dVal))  return NO;
				outQuaternion->x = dVal;
				if (!ooscript::valueToNumber(cx, OOJSFVAL(arrayY), &dVal))  return NO;
				outQuaternion->y = dVal;
				if (!ooscript::valueToNumber(cx, OOJSFVAL(arrayZ), &dVal))  return NO;
				outQuaternion->z = dVal;
				
				COUNT(arrayCount);
				return YES;
			}
		}
	}
	
	// If it's an entity, use its orientation.
	if (OOJSIsMemberOfSubclass(context, quaternionObj, JSEntityClass()))
	{
		COUNT(entityCount);
		Entity *entity = [(id)ooscript::getPrivate(cx, obj) weakRefUnderlyingObject];
		*outQuaternion = [entity orientation];
		return YES;
	}
	
	/*
		If it's actually a Quaternion but with no private field (this happens for
		Quaternion.prototype)...
		
		NOTE: it would be prettier to do this at the top when we handle normal
		Quaternions, but it's a rare case which should be kept off the fast path.
	*/
	if (ooscript::instanceOf(cx, obj, &sQuaternionClass, nullptr))
	{
		COUNT(protoCount);
		*outQuaternion = kZeroQuaternion;
		return YES;
	}
	
	COUNT(failCount);
	return NO;
	
	OOJS_PROFILE_EXIT
}


namespace {
static BOOL GetThisQuaternion(JSContext *context, JSObject *quaternionObj, Quaternion *outQuaternion, NSString *method)
{
	if (EXPECT(JSObjectGetQuaternion(context, quaternionObj, outQuaternion)))  return YES;
	
	jsval arg = OBJECT_TO_JSVAL(quaternionObj);
	OOJSReportBadArguments(context, @"Quaternion", method, 1, &arg, @"Invalid target object", @"Quaternion");
	return NO;
}
} // namespace


BOOL JSQuaternionSetQuaternion(JSContext *context, JSObject *quaternionObj, Quaternion quaternion)
{
	OOJS_PROFILE_ENTER
	
	Quaternion				*priv = NULL;
	
	assert(quaternionObj != NULL);
	
	Context cx = OOJSFCX(context);
	Object obj = OOJSFOBJ(quaternionObj);
	
	priv = static_cast<Quaternion*>(ooscript::getInstancePrivate(cx, obj, &sQuaternionClass, nullptr));
	if (priv != NULL)	// If this is a (JS) Quaternion...
	{
		*priv = quaternion;
		return YES;
	}
	
	if (ooscript::instanceOf(cx, obj, &sQuaternionClass, nullptr))
	{
		// Silently fail for the prototype.
		return YES;
	}
	
	return NO;
	
	OOJS_PROFILE_EXIT
}


namespace {
static BOOL QuaternionFromArgumentListNoErrorInternal(JSContext *context, uintN argc, jsval *argv, Quaternion *outQuaternion, uintN *outConsumed, BOOL permitNumberList)
{
	OOJS_PROFILE_ENTER
	
	double				w, x, y, z;
	
	if (EXPECT_NOT(argc == 0))  return NO;
	assert(argv != NULL && outQuaternion != NULL);
	
	if (outConsumed != NULL)  *outConsumed = 0;
	
	// Is first object a quaternion or entity?
	if (JSVAL_IS_OBJECT(argv[0]))
	{
		if (JSObjectGetQuaternion(context, JSVAL_TO_OBJECT(argv[0]), outQuaternion))
		{
			if (outConsumed != NULL)  *outConsumed = 1;
			return YES;
		}
	}
	
	if (!permitNumberList)  return NO;
	
	// As a special case for QuaternionConstruct(), look for four numbers.
	if (EXPECT_NOT(argc < 4))  return NO;
	
	// Given a string, ooscript::valueToNumber() returns YES but provides a NaN number.
	Context cx = OOJSFCX(context);
	if (EXPECT_NOT(!ooscript::valueToNumber(cx, OOJSFVAL(argv[0]), &w) || isnan(w)))  return NO;
	if (EXPECT_NOT(!ooscript::valueToNumber(cx, OOJSFVAL(argv[1]), &x) || isnan(x)))  return NO;
	if (EXPECT_NOT(!ooscript::valueToNumber(cx, OOJSFVAL(argv[2]), &y) || isnan(y)))  return NO;
	if (EXPECT_NOT(!ooscript::valueToNumber(cx, OOJSFVAL(argv[3]), &z) || isnan(z)))  return NO;
	
	// We got our four numbers.
	*outQuaternion = make_quaternion(w, x, y, z);
	if (outConsumed != NULL)  *outConsumed = 4;

	return YES;
	
	OOJS_PROFILE_EXIT
}
} // namespace


// EMMSTRAN: remove outConsumed, since it can only be 1 except in failure (constructor is an exception, but it uses QuaternionFromArgumentListNoErrorInternal() directly).
BOOL QuaternionFromArgumentList(JSContext *context, NSString *scriptClass, NSString *function, uintN argc, jsval *argv, Quaternion *outQuaternion, uintN *outConsumed)
{
	if (QuaternionFromArgumentListNoErrorInternal(context, argc, argv, outQuaternion, outConsumed, NO))  return YES;
	else
	{
		OOJSReportBadArguments(context, scriptClass, function, argc, argv,
							   @"Could not construct quaternion from parameters",
							   @"Quaternion, Entity or four numbers");
		return NO;
	}
}


BOOL QuaternionFromArgumentListNoError(JSContext *context, uintN argc, jsval *argv, Quaternion *outQuaternion, uintN *outConsumed)
{
	return QuaternionFromArgumentListNoErrorInternal(context, argc, argv, outQuaternion, outConsumed, NO);
}


// *** Implementation stuff ***

namespace {
static bool QuaternionGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	
	OOJS_PROFILE_ENTER
	
	Quaternion			quaternion;
	GLfloat				fValue;
	
	if (EXPECT_NOT(!JSObjectGetQuaternion(context, thisObj, &quaternion))) return NO;
	
	switch (ooscript::idToInt32(propID))
	{
		case kQuaternion_w:
			fValue = quaternion.w;
			break;
		
		case kQuaternion_x:
			fValue = quaternion.x;
			break;
		
		case kQuaternion_y:
			fValue = quaternion.y;
			break;
		
		case kQuaternion_z:
			fValue = quaternion.z;
			break;
		
		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sQuaternionPropertiesRaw);
			return NO;
	}
	
	return ooscript::newNumberValue(cx, fValue, value);
	
	OOJS_PROFILE_EXIT
}
} // namespace


namespace {
static bool QuaternionSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	
	OOJS_PROFILE_ENTER
	
	Quaternion			quaternion;
	jsdouble			dval;
	
	if (EXPECT_NOT(!JSObjectGetQuaternion(context, thisObj, &quaternion))) return NO;
	if (EXPECT_NOT(!ooscript::valueToNumber(cx, *value, &dval)))
	{
		OOJSReportBadPropertyValue(context, thisObj, OOJSRJSID(propID), sQuaternionPropertiesRaw, *OOJSRVAL(value));
		return NO;
	}
	
	switch (ooscript::idToInt32(propID))
	{
		case kQuaternion_w:
			quaternion.w = dval;
			break;
		
		case kQuaternion_x:
			quaternion.x = dval;
			break;
		
		case kQuaternion_y:
			quaternion.y = dval;
			break;
		
		case kQuaternion_z:
			quaternion.z = dval;
			break;
		
		default:
			OOJSReportBadPropertySelector(context, thisObj, OOJSRJSID(propID), sQuaternionPropertiesRaw);
			return NO;
	}
	
	return JSQuaternionSetQuaternion(context, thisObj, quaternion);
	
	OOJS_PROFILE_EXIT
}
} // namespace


namespace {
static void QuaternionFinalize(Context cx, Object obj)
{
	OOJS_PROFILE_ENTER
	
	Quaternion				*priv = NULL;
	
	priv = static_cast<Quaternion*>(ooscript::getInstancePrivate(cx, obj, &sQuaternionClass, nullptr));
	if (priv != NULL)
	{
		free(priv);
	}
	
	OOJS_PROFILE_EXIT_VOID
}
} // namespace


namespace {
static bool QuaternionConstruct(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	Quaternion				quaternion = kIdentityQuaternion;
	Quaternion				*priv = NULL;
	JSObject				*thisObj = NULL;
	
	priv = static_cast<Quaternion*>(malloc(sizeof *priv));
	if (EXPECT_NOT(priv == NULL))  return NO;
	
	thisObj = OOJSROBJ(ooscript::newObject(cx, &sQuaternionClass, nullptr, nullptr));
	if (EXPECT_NOT(thisObj == NULL))  return NO;
	
	if (argc != 0)
	{
		if (EXPECT_NOT(!QuaternionFromArgumentListNoErrorInternal(context, argc, OOJS_ARGV, &quaternion, NULL, YES)))
		{
			free(priv);
			OOJSReportBadArguments(context, NULL, NULL, argc, OOJS_ARGV,
								   @"Could not construct quaternion from parameters",
								   @"Quaternion, Entity or array of four numbers");
			return NO;
		}
	}
	
	*priv = quaternion;
	
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
static bool QuaternionToString(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	Quaternion				thisq;
	
	if (EXPECT_NOT(!GetThisQuaternion(context, OOJS_THIS, &thisq, @"toString"))) return NO;
	
	OOJS_RETURN_OBJECT(QuaternionDescription(thisq));
	
	OOJS_NATIVE_EXIT
}
} // namespace


// toSource() : String
namespace {
static bool QuaternionToSource(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_NATIVE_ENTER(context)
	
	Quaternion				thisq;
	
	if (EXPECT_NOT(!GetThisQuaternion(context, OOJS_THIS, &thisq, @"toSource"))) return NO;
	
	NSString *str = [NSString stringWithFormat:@"Quaternion(%g, %g, %g, %g)", thisq.w, thisq.x, thisq.y, thisq.z];
	OOJS_RETURN_OBJECT(str);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// multiply(q : quaternionExpression) : Quaternion
namespace {
static bool QuaternionMultiply(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	Quaternion				thisq, thatq, result;
	
	if (EXPECT_NOT(!GetThisQuaternion(context, OOJS_THIS, &thisq, @"multiply"))) return NO;
	if (EXPECT_NOT(!QuaternionFromArgumentList(context, @"Quaternion", @"multiply", argc, OOJS_ARGV, &thatq, NULL)))  return NO;
	
	result = quaternion_multiply(thisq, thatq);
	
	OOJS_RETURN_QUATERNION(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// dot(q : quaternionExpression) : Number
namespace {
static bool QuaternionDot(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	Quaternion				thisq, thatq;
	OOScalar				result;
	
	if (EXPECT_NOT(!GetThisQuaternion(context, OOJS_THIS, &thisq, @"dot"))) return NO;
	if (EXPECT_NOT(!QuaternionFromArgumentList(context, @"Quaternion", @"dot", argc, OOJS_ARGV, &thatq, NULL)))  return NO;
	
	result = quaternion_dot_product(thisq, thatq);
	
	OOJS_RETURN_DOUBLE(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// rotate(axis : vectorExpression, angle : Number) : Quaternion
namespace {
static bool QuaternionRotate(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	Quaternion				thisq;
	HPVector					axis;
	double					angle;
	uintN					consumed;
	jsval					*argv = OOJS_ARGV;
	
	if (EXPECT_NOT(!GetThisQuaternion(context, OOJS_THIS, &thisq, @"rotate"))) return NO;
	if (EXPECT_NOT(!VectorFromArgumentList(context, @"Quaternion", @"rotate", argc, argv, &axis, &consumed)))  return NO;
	argv += consumed;
	argc -= consumed;
	if (argc > 0)
	{
		if (EXPECT_NOT(!OOJSArgumentListGetNumber(context, @"Quaternion", @"rotate", argc, argv, &angle, NULL)))  return NO;
		quaternion_rotate_about_axis(&thisq, HPVectorToVector(axis), angle);
	}
	// Else no angle specified, so don't rotate and pass value through unchanged.
	
	OOJS_RETURN_QUATERNION(thisq);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// rotateX(angle : Number) : Quaternion
namespace {
static bool QuaternionRotateX(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	Quaternion				quat;
	double					angle;
	
	if (EXPECT_NOT(!GetThisQuaternion(context, OOJS_THIS, &quat, @"rotateX"))) return NO;
	if (EXPECT_NOT(!OOJSArgumentListGetNumber(context, @"Quaternion", @"rotateX", argc, OOJS_ARGV, &angle, NULL)))  return NO;
	
	quaternion_rotate_about_x(&quat, angle);
	
	OOJS_RETURN_QUATERNION(quat);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// rotateY(angle : Number) : Quaternion
namespace {
static bool QuaternionRotateY(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	Quaternion				quat;
	double					angle;
	
	if (EXPECT_NOT(!GetThisQuaternion(context, OOJS_THIS, &quat, @"rotateY"))) return NO;
	if (EXPECT_NOT(!OOJSArgumentListGetNumber(context, @"Quaternion", @"rotateY", argc, OOJS_ARGV, &angle, NULL)))  return NO;
	
	quaternion_rotate_about_y(&quat, angle);
	
	OOJS_RETURN_QUATERNION(quat);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// rotateZ(angle : Number) : Quaternion
namespace {
static bool QuaternionRotateZ(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	uintN argc = oojsArgs.count();
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	Quaternion				quat;
	double					angle;
	
	if (EXPECT_NOT(!GetThisQuaternion(context, OOJS_THIS, &quat, @"rotateZ"))) return NO;
	if (EXPECT_NOT(!OOJSArgumentListGetNumber(context, @"Quaternion", @"rotateZ", argc, OOJS_ARGV, &angle, NULL)))  return NO;
	
	quaternion_rotate_about_z(&quat, angle);
	
	OOJS_RETURN_QUATERNION(quat);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// normalize() : Quaternion
namespace {
static bool QuaternionNormalize(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	Quaternion				quat;
	
	if (EXPECT_NOT(!GetThisQuaternion(context, OOJS_THIS, &quat, @"normalize"))) return NO;
	
	quaternion_normalize(&quat);
	
	OOJS_RETURN_QUATERNION(quat);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// conjugate() : Quaternion
namespace {
static bool QuaternionConjugate(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
		Quaternion				quat, result;
	
	if (EXPECT_NOT(!GetThisQuaternion(context, OOJS_THIS, &quat, @"conjugate"))) return NO;
	
	result = quaternion_conjugate(quat);
	
	OOJS_RETURN_QUATERNION(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// vectorForward() : Vector
namespace {
static bool QuaternionVectorForward(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	Quaternion				thisq;
	Vector					result;
	
	if (EXPECT_NOT(!GetThisQuaternion(context, OOJS_THIS, &thisq, @"vectorForward"))) return NO;
	
	result = vector_forward_from_quaternion(thisq);
	
	OOJS_RETURN_VECTOR(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// vectorUp() : Vector
namespace {
static bool QuaternionVectorUp(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	Quaternion				thisq;
	Vector					result;
	
	if (EXPECT_NOT(!GetThisQuaternion(context, OOJS_THIS, &thisq, @"vectorUp"))) return NO;
	
	result = vector_up_from_quaternion(thisq);
	
	OOJS_RETURN_VECTOR(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// vectorRight() : Vector
namespace {
static bool QuaternionVectorRight(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	Quaternion				thisq;
	Vector					result;
	
	if (EXPECT_NOT(!GetThisQuaternion(context, OOJS_THIS, &thisq, @"vectorRight"))) return NO;
	
	result = vector_right_from_quaternion(thisq);
	
	OOJS_RETURN_VECTOR(result);
	
	OOJS_PROFILE_EXIT
}
} // namespace


// toArray() : Array
namespace {
static bool QuaternionToArray(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	Quaternion				thisq;
	JSObject				*result = NULL;
	BOOL					OK = YES;
	jsval					nVal;
	
	if (EXPECT_NOT(!GetThisQuaternion(context, OOJS_THIS, &thisq, @"toArray"))) return NO;
	
	result = OOJSROBJ(ooscript::newArrayObject(cx, 0, nullptr));
	if (result != NULL)
	{
		// We do this at the top because *outResult is a GC root.
		OOJS_SET_RVAL(OBJECT_TO_JSVAL(result));
		
		Object resultObj = OOJSFOBJ(result);
		if (ooscript::newNumberValue(cx, thisq.w, OOJSFVALP(&nVal)))  ooscript::setElement(cx, resultObj, 0, OOJSFVALP(&nVal));
		else  OK = NO;
		if (ooscript::newNumberValue(cx, thisq.x, OOJSFVALP(&nVal)))  ooscript::setElement(cx, resultObj, 1, OOJSFVALP(&nVal));
		else  OK = NO;
		if (ooscript::newNumberValue(cx, thisq.y, OOJSFVALP(&nVal)))  ooscript::setElement(cx, resultObj, 2, OOJSFVALP(&nVal));
		else  OK = NO;
		if (ooscript::newNumberValue(cx, thisq.z, OOJSFVALP(&nVal)))  ooscript::setElement(cx, resultObj, 3, OOJSFVALP(&nVal));
		else  OK = NO;
	}
	
	if (!OK)  OOJS_SET_RVAL(JSVAL_VOID);
	return YES;
	
	OOJS_PROFILE_EXIT
}
} // namespace


// *** Static methods ***

// random() : Quaternion
namespace {
static bool QuaternionStaticRandom(Context cx, CallArgs &oojsArgs)
{
	JSContext *context = OOJSRCX(cx);
	jsval *vp = OOJSRVAL(oojsArgs.rawVp());
	
	OOJS_PROFILE_ENTER
	
	OOJS_RETURN_QUATERNION(OORandomQuaternion());
	
	OOJS_PROFILE_EXIT
}
} // namespace
