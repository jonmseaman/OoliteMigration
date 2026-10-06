/*	test_OOJSWaypoint.mm
	Unit tests for the Waypoint JS binding (src/Core/Scripting/OOJSWaypoint.h/.mm) and its
	OOWaypointEntity category (whose forwarders are on the OOWaypointEntity facade since bead
	oo-9ht.50; this test's stand-in OOWaypointEntity forwards the same way): bead oo-mae5, converted
	the way bead oo-ppc converted OOJSVector (proposed ADR-0056 amendments oo-ppc and oo-ykoy).

	As test_OOJSWormhole.mm does (amendment oo-ykoy, item 4), it runs the JS class in a real
	context on the game's own façade backend (ooscript/JSEngine_quickjs.cpp), links the game's own
	objects for the binding and the engine's exception translator
	(OOJSEngineNativeWrappers.mm), and stands in for the classes the binding messages (Entity and
	OOWaypointEntity, and the universe's beacon list and the player's compass, answer only the
	selectors the binding sends), for the Quaternion conversions (a quaternion is the array
	[w, x, y, z] here) and for the engine functions the binding links against, with the engine
	headers' linkage. The expectations were written against the Objective-C file and run on it
	first; they pin the JS-visible behaviour (the four properties, a beacon code that registers or
	clears a beacon, an unoriented waypoint, a non-waypoint, a native's exception) and what the
	category answers the engine. Run: bash tools/check-core-tests.sh
*/

#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"
#include <objc/runtime.h>
#include "OOMaths.h"
#include "OOTypes.h"
#include "ooscript/JSEngine.hpp"
#include "oofnd/objc/OOException.h"
#include "oofnd/PList.hpp"
#include "oofnd/String.hpp"


// MARK: The classes, as far as the binding sees them ----------------------------------------------

@class Universe, PlayerEntity;

@interface Entity: OOObject
{
@public
	std::optional<std::string> _beaconCode;
	std::optional<std::string> _beaconLabel;
	Quaternion _orientation;
}
- (id) weakRefUnderlyingObject;
- (std::optional<std::string>) beaconCode;
- (void) setBeaconCode:(const std::optional<std::string> &)bcode;
- (std::optional<std::string>) beaconLabel;
- (void) setBeaconLabel:(const std::optional<std::string> &)blabel;
- (BOOL) isBeacon;
- (Quaternion) orientation;
- (void) setNormalOrientation:(Quaternion)quat;
@end

/*	A waypoint whose size is 99 raises from -size, one whose size is 98 throws a C++ exception, so
	the test sees what an exception under a native becomes.
*/
@interface OOWaypointEntity: Entity
{
@public
	BOOL _oriented;
	OOScalar _size;
}
- (BOOL) oriented;
- (OOScalar) size;
- (void) setSize:(OOScalar)newSize;
@end

// The universe's beacon list and the player's compass: what the binding tells them.
@interface FakeGame: OOObject
{
@public
	id _nextBeacon;
	int _cleared;
	int _added;
	int _compassMode;
}
- (void) setNextBeacon:(Entity *)beacon;
- (void) clearBeacon:(Entity *)beacon;
- (Entity *) nextBeacon;
- (void) setCompassMode:(OOCompassMode)mode;
@end

@interface Entity (OOJavaScriptExtensions)
- (void) getJSClass:(ooscript::ClassDef **)outClass andPrototype:(ooscript::Object *)outPrototype;
- (std::optional<std::string>) cxx_oo_jsClassName;
- (BOOL) isVisibleToScripts;
@end


#import "OOJSWaypoint.h"

#include "oo_test.hpp"

#include <cstdarg>
#include <cstring>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>


@implementation Entity

- (id) weakRefUnderlyingObject  { return self; }
- (std::optional<std::string>) beaconCode  { return _beaconCode; }
- (void) setBeaconCode:(const std::optional<std::string> &)bcode  { _beaconCode = bcode; }
- (std::optional<std::string>) beaconLabel  { return _beaconLabel; }
- (void) setBeaconLabel:(const std::optional<std::string> &)blabel  { _beaconLabel = blabel; }
- (BOOL) isBeacon  { return _beaconCode.has_value() && !_beaconCode->empty(); }
- (Quaternion) orientation  { return _orientation; }
- (void) setNormalOrientation:(Quaternion)quat  { _orientation = quat; }

@end


@implementation OOWaypointEntity

- (BOOL) oriented  { return _oriented; }
- (void) setSize:(OOScalar)newSize  { _size = newSize; }

- (OOScalar) size
{
	if (_size == 99)  [OOException raise:OOInvalidArgumentException format:"size %s", "boom"];
	if (_size == 98)  throw std::runtime_error("cxx boom");
	return _size;
}


// The binding's category, as the OOWaypointEntity facade forwards it
// (OOWaypointEntity+ObjCBridge.mm, bead oo-9ht.50): the engine sends these selectors to the wrapped
// object.
- (void) getJSClass:(ooscript::ClassDef **)outClass andPrototype:(ooscript::Object *)outPrototype  { ::OOJSWaypointGetJSClass(outClass, outPrototype); }
- (std::optional<std::string>) cxx_oo_jsClassName  { return ::OOJSWaypointJSClassName(); }
- (BOOL) isVisibleToScripts  { return ::OOJSWaypointIsVisibleToScripts(); }

@end


@implementation FakeGame

- (void) setNextBeacon:(Entity *)beacon  { _added++; (void)beacon; }
- (void) clearBeacon:(Entity *)beacon  { _cleared++; beacon->_beaconCode = std::nullopt; }
- (Entity *) nextBeacon  { return _nextBeacon; }
- (void) setCompassMode:(OOCompassMode)mode  { _compassMode = static_cast<int>(mode); }

@end


// MARK: What the rest of the engine provides ------------------------------------------------------

void cxx_OOJSReportErrorWithArguments(ooscript::Context context, const char *format, va_list args)
{
	std::string msg = oo::str::vformat(format, args);
	ooscript::reportError(context, msg.c_str());
}


void cxx_OOJSReportError(ooscript::Context context, const char *format, ...)
{
	va_list args;
	va_start(args, format);
	cxx_OOJSReportErrorWithArguments(context, format, args);
	va_end(args);
}


std::optional<std::string> cxx_OOStringFromJSValue(ooscript::Context context, ooscript::Value value)
{
	if (ooscript::isNullOrUndefined(value))  return std::nullopt;
	ooscript::String str = ooscript::valueToString(context, value);
	if (str == nullptr)  return std::nullopt;
	std::size_t length = 0;
	const ooscript::Char16 *chars = ooscript::getStringCharsAndLength(context, str, &length);
	std::string result;
	for (std::size_t i = 0; i < length; i++)  result += static_cast<char>(chars[i]);	// the test's strings are ASCII
	return result;
}


// A property list as JavaScript, as far as the binding hands one over: null, a string, a number,
// or an array of those.
ooscript::Value OOJSValueFromPList(ooscript::Context context, const oo::PList &plist)
{
	if (const std::string *str = plist.getIf<std::string>())
	{
		ooscript::String js = ooscript::newStringCopyN(context, str->data(), str->size());
		return js != nullptr ? ooscript::stringValue(js) : ooscript::nullValue();
	}
	if (const double *number = plist.getIf<double>())  return ooscript::numberValue(*number);
	if (const oo::PList::Array *array = plist.getIf<oo::PList::Array>())
	{
		std::vector<ooscript::Value> values;
		for (const oo::PList &element : *array)  values.push_back(OOJSValueFromPList(context, element));
		ooscript::Object object = ooscript::newArrayObject(context, static_cast<unsigned>(values.size()), values.data());
		return object != nullptr ? ooscript::objectValue(object) : ooscript::nullValue();
	}
	return ooscript::nullValue();
}


namespace {
ooscript::ClassDef sFakeEntityClass = { "Entity", ooscript::ClassFlag::HasPrivate };
std::map<ooscript::ClassDef *, ooscript::ClassDef *> sSuperclasses;
std::map<ooscript::ClassDef *, int> sConverters;
} // namespace

ooscript::Object gOOEntityJSPrototype = nullptr;
Universe *gSharedUniverse = nil;
PlayerEntity *gOOPlayer = nil;


extern "C" {

ooscript::ClassDef *JSEntityClass(void)
{
	return &sFakeEntityClass;
}


void OOJSReportBadPropertySelector(ooscript::Context context, ooscript::Object, ooscript::PropertyId, ooscript::PropertySpec *)
{
	cxx_OOJSReportError(context, "bad property selector");
}


void OOJSReportBadPropertyValue(ooscript::Context context, ooscript::Object, ooscript::PropertyId, ooscript::PropertySpec *, ooscript::Value)
{
	cxx_OOJSReportError(context, "bad property value");
}


void OOJSRegisterSubclass(ooscript::ClassDef *subclass, ooscript::ClassDef *superclass)
{
	sSuperclasses[subclass] = superclass;
}


BOOL OOJSIsSubclass(ooscript::ClassDef *putativeSubclass, ooscript::ClassDef *superclass)
{
	for (ooscript::ClassDef *c = putativeSubclass; c != nullptr; c = sSuperclasses.count(c) != 0 ? sSuperclasses[c] : nullptr)
	{
		if (c == superclass)  return YES;
	}
	return NO;
}


void OOJSRegisterObjectConverter(ooscript::ClassDef *theClass, oo::PList (*)(ooscript::Context, ooscript::Object))
{
	sConverters[theClass]++;
}


// The engine's object getter: the JS class must be a subclass of the required one, and the
// underlying object must be of the required Objective-C class.
BOOL OOJSObjectGetterImplPRIVATE(ooscript::Context context, ooscript::Object object, ooscript::ClassDef *requiredJSClass, Class requiredObjCClass, const char *, id *outObject)
{
	ooscript::ClassDef *actualClass = const_cast<ooscript::ClassDef *>(ooscript::getObjectClass(context, object));
	if (!OOJSIsSubclass(actualClass, requiredJSClass))
	{
		cxx_OOJSReportError(context, "Native method expected %s, got %s.", requiredJSClass->name, cxx_OOStringFromJSValue(context, ooscript::objectValue(object)).value_or("(null)").c_str());
		return NO;
	}
	*outObject = [(id)ooscript::getPrivate(context, object) weakRefUnderlyingObject];
	if (*outObject != nil && ![*outObject isKindOfClass:requiredObjCClass])
	{
		cxx_OOJSReportError(context, "Native method expected %s from %s.", class_getName(requiredObjCClass), requiredJSClass->name);
		*outObject = nil;
		return NO;
	}
	return YES;
}


ooscript::Value OOJSValueFromNativeObject(ooscript::Context, id)
{
	return ooscript::undefinedValue();
}


bool OOJSUnconstructableConstruct(ooscript::Context context, ooscript::CallArgs &)
{
	cxx_OOJSReportError(context, "unconstructable");
	return false;
}


void OOJSObjectWrapperFinalize(ooscript::Context, ooscript::Object)
{
}


// A quaternion is the array [w, x, y, z] here: enough to see what the binding hands over and takes.
bool QuaternionToJSValue(ooscript::Context context, Quaternion quaternion, ooscript::Value *outValue)
{
	ooscript::Value parts[4] = { ooscript::numberValue(quaternion.w), ooscript::numberValue(quaternion.x), ooscript::numberValue(quaternion.y), ooscript::numberValue(quaternion.z) };
	ooscript::Object array = ooscript::newArrayObject(context, 4, parts);
	if (array == nullptr)  return false;
	*outValue = ooscript::objectValue(array);
	return true;
}


bool JSValueToQuaternion(ooscript::Context context, ooscript::Value value, Quaternion *outQuaternion)
{
	double q[4] = {};
	ooscript::Value element;
	if (!ooscript::isObject(value) || !ooscript::isArrayObject(context, ooscript::toObject(value)))  return false;
	for (int i = 0; i < 4; i++)
	{
		if (!ooscript::getElement(context, ooscript::toObject(value), i, &element) || !ooscript::valueToNumber(context, element, &q[i]))  return false;
	}
	*outQuaternion = make_quaternion(q[0], q[1], q[2], q[3]);
	return true;
}


int sLimiterPauses = 0;
int sProfileDepth = 0;

void OOJSProfileEnter(struct OOJSProfileStackFrame *, const char *)  { sProfileDepth++; }
void OOJSProfileExit(struct OOJSProfileStackFrame *)  { sProfileDepth--; }

void OOJSPauseTimeLimiter(void)  { sLimiterPauses++; }
void OOJSResumeTimeLimiter(void)  { sLimiterPauses--; }


#ifndef NDEBUG
void OOJSUnreachable(const char *function, const char *, unsigned)
{
	std::printf("unreachable reached in %s\n", function);
	abort();
}
#endif

}	// extern "C"


oo::PList OOJSBasicPrivateObjectConverter(ooscript::Context, ooscript::Object)
{
	return oo::PList();
}


// MARK: The context -------------------------------------------------------------------------------

namespace {

ooscript::Runtime sRuntime;
ooscript::Context sContext;
ooscript::Object sGlobal;
OOWaypointEntity *sWaypoint = nil;
FakeGame *sGame = nil;


ooscript::Value JSValueForObject(ooscript::ClassDef *jsClass, ooscript::Object prototype, Entity *entity)
{
	ooscript::Object object = ooscript::newObject(sContext, jsClass, prototype, nullptr);
	if (object == nullptr || !ooscript::setPrivate(sContext, object, entity))  return ooscript::nullValue();
	return ooscript::objectValue(object);
}


// A JS object for an entity, as -[Entity oo_jsValueInContext:] makes it: the class and prototype
// the entity's category names, and the entity in the private slot.
ooscript::Value JSValueForEntity(Entity *entity)
{
	ooscript::ClassDef *jsClass = nullptr;
	ooscript::Object prototype = nullptr;
	[entity getJSClass:&jsClass andPrototype:&prototype];
	return JSValueForObject(jsClass, prototype, entity);
}


void Define(const char *name, ooscript::Value value)
{
	ooscript::setProperty(sContext, sGlobal, name, &value);
}


void SetUpContext()
{
	if (sContext != nullptr)  return;
	sRuntime = ooscript::newRuntime(8u * 1024u * 1024u);
	sContext = ooscript::newContext(sRuntime, 8192);
	ooscript::beginRequest(sContext);
	sGlobal = ooscript::getGlobalObject(sContext);
	ooscript::initStandardClasses(sContext, sGlobal);
	gOOEntityJSPrototype = ooscript::initClass(sContext, sGlobal, nullptr, &sFakeEntityClass, OOJSUnconstructableConstruct, 0, nullptr, nullptr, nullptr, nullptr);
	InitOOJSWaypoint(sContext, sGlobal);

	sGame = [[FakeGame alloc] init];	// kept for the life of the test
	gSharedUniverse = (Universe *)sGame;
	gOOPlayer = (PlayerEntity *)sGame;
	sWaypoint = [[OOWaypointEntity alloc] init];
	sWaypoint->_beaconLabel = "Label";
	sWaypoint->_orientation = make_quaternion(0, 1, 0, 0);
	sWaypoint->_oriented = YES;
	sWaypoint->_size = 20;
	Define("waypoint", JSValueForEntity(sWaypoint));
	Define("plainEntity", JSValueForObject(&sFakeEntityClass, gOOEntityJSPrototype, [[Entity alloc] init]));
}


// Evaluates src and gives its result as a string ("undefined", "null", ...), or "threw: <message>".
std::string Eval(const char *src)
{
	SetUpContext();
	std::string wrapped = std::string("(function () { try { return String(") + src + "); } catch (e) { return 'threw: ' + (e && e.message !== undefined ? e.message : e); } })()";
	ooscript::Value result = ooscript::undefinedValue();
	if (!ooscript::evaluateScript(sContext, sGlobal, wrapped.c_str(), static_cast<unsigned>(wrapped.size()), "test.js", 1, &result))
	{
		ooscript::clearPendingException(sContext);
		return "<evaluation failed>";
	}
	return cxx_OOStringFromJSValue(sContext, result).value_or("<not a string>");
}


// Eval, and print what came back when it is not what the check expects.
std::string EvalShown(const char *src, const char *expected)
{
	std::string result = Eval(src);
	if (result != expected)  std::printf("    %s\n    gave: %s\n", src, result.c_str());
	return result;
}
#define OO_CHECK_EVAL(src, expected)  OO_CHECK_EQ(EvalShown(src, expected), expected)

}	// namespace


// MARK: Tests -------------------------------------------------------------------------------------

OO_TEST(registration)
{
	SetUpContext();
	ooscript::ClassDef *waypointClass = nullptr;
	ooscript::Object prototype = nullptr;
	[sWaypoint getJSClass:&waypointClass andPrototype:&prototype];
	OO_CHECK(waypointClass != nullptr && std::strcmp(waypointClass->name, "Waypoint") == 0);
	OO_CHECK(prototype != nullptr);
	OO_CHECK(OOJSIsSubclass(waypointClass, &sFakeEntityClass));
	OO_CHECK_EQ(sConverters[waypointClass], 1);
	OO_CHECK([sWaypoint cxx_oo_jsClassName] == std::optional<std::string>("Waypoint"));
	OO_CHECK([sWaypoint isVisibleToScripts]);
	OO_CHECK_EVAL("typeof Waypoint", "function");
	OO_CHECK_EVAL("new Waypoint()", "threw: unconstructable");
	OO_CHECK_EVAL("Object.getPrototypeOf(Waypoint.prototype) === Entity.prototype", "true");
	OO_CHECK_EVAL("waypoint instanceof Waypoint", "true");
}


OO_TEST(properties)
{
	OO_CHECK_EVAL("waypoint.beaconCode", "null");
	OO_CHECK_EVAL("waypoint.beaconLabel", "Label");
	OO_CHECK_EVAL("waypoint.orientation", "0,1,0,0");
	OO_CHECK_EVAL("waypoint.size", "20");
	OO_CHECK_EVAL("Object.keys(Waypoint.prototype).join()", "beaconCode,beaconLabel,orientation,size");
	sWaypoint->_oriented = NO;
	OO_CHECK_EVAL("waypoint.orientation", "0,0,0,0");	// unoriented: the zero quaternion
	sWaypoint->_oriented = YES;
}


OO_TEST(setters)
{
	OO_CHECK_EVAL("(function () { waypoint.beaconLabel = 'Other'; return waypoint.beaconLabel; })()", "Other");
	OO_CHECK_EVAL("(function () { waypoint.beaconLabel = null; return waypoint.beaconLabel; })()", "threw: bad property value");
	OO_CHECK_EVAL("(function () { waypoint.orientation = [1, 0, 0, 0]; return waypoint.orientation; })()", "1,0,0,0");
	OO_CHECK_EVAL("(function () { waypoint.orientation = 'up'; return waypoint.orientation; })()", "threw: bad property value");
	OO_CHECK_EVAL("(function () { waypoint.size = 5.5; return waypoint.size; })()", "5.5");
	OO_CHECK_EVAL("(function () { waypoint.size = 0; return waypoint.size; })()", "threw: bad property value");
	OO_CHECK_EVAL("waypoint.size", "5.5");
}


OO_TEST(beaconCode)
{
	SetUpContext();
	// Not a beacon yet: setting a code makes it one and tells the universe.
	int added = sGame->_added;
	OO_CHECK_EVAL("(function () { waypoint.beaconCode = 'W'; return waypoint.beaconCode; })()", "W");
	OO_CHECK_EQ(sGame->_added, added + 1);
	// Already a beacon: a new code is just set.
	OO_CHECK_EVAL("(function () { waypoint.beaconCode = 'X'; return waypoint.beaconCode; })()", "X");
	OO_CHECK_EQ(sGame->_added, added + 1);
	// An empty code clears the beacon; the compass leaves it if it pointed there.
	sGame->_nextBeacon = sWaypoint;
	sGame->_compassMode = -1;
	int cleared = sGame->_cleared;
	OO_CHECK_EVAL("(function () { waypoint.beaconCode = ''; return waypoint.beaconCode; })()", "null");
	OO_CHECK_EQ(sGame->_cleared, cleared + 1);
	OO_CHECK_EQ(sGame->_compassMode, static_cast<int>(COMPASS_MODE_PLANET));
	// Clearing a waypoint that is not a beacon does nothing.
	OO_CHECK_EVAL("(function () { waypoint.beaconCode = null; return waypoint.beaconCode; })()", "null");
	OO_CHECK_EQ(sGame->_cleared, cleared + 1);
	sGame->_nextBeacon = nil;
}


OO_TEST(otherObjects)
{
	OO_CHECK_EVAL("Object.getOwnPropertyDescriptor(Waypoint.prototype, 'size').get.call(plainEntity)", "<evaluation failed>");
	OO_CHECK_EVAL("Object.getOwnPropertyDescriptor(Waypoint.prototype, 'size').get.call({})", "threw: Native method expected Entity, got [object Object].");
	OO_CHECK_EVAL("Waypoint.prototype.size", "<evaluation failed>");
}


OO_TEST(nativeExceptions)
{
	SetUpContext();
	// The property getter is a native (OOJS_NATIVE_ENTER): a raise from the entity is a JS error,
	// and so is a C++ exception.
	sWaypoint->_size = 99;
	OO_CHECK_EVAL("waypoint.size", "threw: Native exception: size boom");
	sWaypoint->_size = 98;
	OO_CHECK_EVAL("waypoint.size", "threw: Native exception: cxx boom");
	sWaypoint->_size = 20;
	OO_CHECK_EVAL("waypoint.size", "20");
	OO_CHECK_EQ(sLimiterPauses, 0);
	OO_CHECK_EQ(sProfileDepth, 0);
	OO_CHECK(ooscript::isInRequest(sContext));
}


OO_TEST_MAIN()
