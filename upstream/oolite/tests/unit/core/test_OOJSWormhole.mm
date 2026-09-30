/*	test_OOJSWormhole.mm
	Unit tests for the Wormhole JS binding (src/Core/Scripting/OOJSWormhole.h/.mm) and its
	WormholeEntity category (OOJSWormhole+ObjCBridge.mm): bead oo-ykoy, converted the way bead
	oo-ppc converted OOJSVector (proposed ADR-0056 amendments oo-ppc and oo-ykoy).

	It runs the JS class in a real context on the game's own façade backend
	(ooscript/JSEngine_quickjs.cpp) and links the game's own objects for the binding, its bridge
	and the engine's exception translator (OOJSEngineNativeWrappers.mm). The entity classes it
	reads are stand-ins of the same names (amendment oo-z1s4, item 4), so the test imports neither
	their headers nor OOJavaScriptEngine.h (which imports them): Entity and WormholeEntity answer
	only the selectors the binding sends, and the JS side of an entity is a JS object of the
	binding's class whose private slot is the entity. What the engine provides (the Entity JS
	class, the subclass table, the object getter, error reporting) is defined below as the
	smallest stand-in that does the same thing, with the engine header's linkage. The expectations
	were written against the Objective-C file and run on it first; they pin the JS-visible
	behaviour (the four properties, read-only, a stale entity, the wrong kind of object, a native's
	exception) and what the category answers the engine.
	Run: bash tools/check-core-tests.sh
*/

#import "oofnd/objc/OOObject.h"
#include <objc/runtime.h>
#include "OOTypes.h"
#include "ooscript/JSEngine.hpp"
#include "oofnd/objc/OOException.h"
#include "oofnd/PList.hpp"
#include "oofnd/String.hpp"


// MARK: The entity classes, as far as the binding sees them ---------------------------------------

/*	A wormhole whose arrival time is -1 raises from -arrivalTime, one whose arrival time is -2
	throws a C++ exception, so the test sees what an exception under a native becomes.
*/
@interface Entity: OOObject
- (id) weakRefUnderlyingObject;
@end

@interface WormholeEntity: Entity
{
@public
	double _arrivalTime;
	double _expiryTime;
	OOSystemID _origin;
	OOSystemID _destination;
}
- (double) arrivalTime;
- (double) expiryTime;
- (OOSystemID) origin;
- (OOSystemID) destination;
@end

@interface Entity (OOJavaScriptExtensions)
- (void) getJSClass:(ooscript::ClassDef **)outClass andPrototype:(ooscript::Object *)outPrototype;
- (std::optional<std::string>) cxx_oo_jsClassName;
- (BOOL) isVisibleToScripts;
@end


#import "OOJSWormhole.h"

#include "oo_test.hpp"

#include <cstdarg>
#include <cstring>
#include <map>
#include <stdexcept>
#include <string>


@implementation Entity

- (id) weakRefUnderlyingObject
{
	return self;
}

@end


@implementation WormholeEntity

- (double) arrivalTime
{
	if (_arrivalTime == -1)  [OOException raise:OOInvalidArgumentException format:"arrival %s", "boom"];
	if (_arrivalTime == -2)  throw std::runtime_error("cxx boom");
	return _arrivalTime;
}

- (double) expiryTime  { return _expiryTime; }
- (OOSystemID) origin  { return _origin; }
- (OOSystemID) destination  { return _destination; }

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


namespace {
ooscript::ClassDef sFakeEntityClass = { "Entity", ooscript::ClassFlag::HasPrivate };
std::map<ooscript::ClassDef *, ooscript::ClassDef *> sSuperclasses;
std::map<ooscript::ClassDef *, int> sConverters;
int sFinalized = 0;
} // namespace

ooscript::Object gOOEntityJSPrototype = nullptr;


extern "C" {

ooscript::ClassDef *JSEntityClass(void)
{
	return &sFakeEntityClass;
}


void OOJSReportBadPropertySelector(ooscript::Context context, ooscript::Object, ooscript::PropertyId, ooscript::PropertySpec *)
{
	cxx_OOJSReportError(context, "bad property selector");
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
	sFinalized++;
}


int sLimiterPauses = 0;

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
WormholeEntity *sWormhole = nil;


// A JS object for an entity, as -[Entity oo_jsValueInContext:] makes it: the class and prototype
// the entity's category names, and the entity in the private slot.
ooscript::Value JSValueForEntity(Entity *entity)
{
	ooscript::ClassDef *jsClass = nullptr;
	ooscript::Object prototype = nullptr;
	[entity getJSClass:&jsClass andPrototype:&prototype];
	ooscript::Object object = ooscript::newObject(sContext, jsClass, prototype, nullptr);
	if (object == nullptr || !ooscript::setPrivate(sContext, object, entity))  return ooscript::nullValue();
	return ooscript::objectValue(object);
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
	InitOOJSWormhole(sContext, sGlobal);

	sWormhole = [[WormholeEntity alloc] init];	// kept for the life of the test
	sWormhole->_arrivalTime = 1000.5;
	sWormhole->_expiryTime = 900.25;
	sWormhole->_origin = 7;
	sWormhole->_destination = 129;
	ooscript::Value wormhole = JSValueForEntity(sWormhole);
	ooscript::setProperty(sContext, sGlobal, "wormhole", &wormhole);
	ooscript::Value entity = ooscript::nullValue();
	ooscript::Object plain = ooscript::newObject(sContext, &sFakeEntityClass, gOOEntityJSPrototype, nullptr);
	if (plain != nullptr && ooscript::setPrivate(sContext, plain, [[Entity alloc] init]))  entity = ooscript::objectValue(plain);
	ooscript::setProperty(sContext, sGlobal, "plainEntity", &entity);
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
	ooscript::ClassDef *wormholeClass = nullptr;
	ooscript::Object prototype = nullptr;
	[sWormhole getJSClass:&wormholeClass andPrototype:&prototype];
	OO_CHECK(wormholeClass != nullptr && std::strcmp(wormholeClass->name, "Wormhole") == 0);
	OO_CHECK(prototype != nullptr);
	OO_CHECK(OOJSIsSubclass(wormholeClass, &sFakeEntityClass));
	OO_CHECK_EQ(sConverters[wormholeClass], 1);
	OO_CHECK([sWormhole cxx_oo_jsClassName] == std::optional<std::string>("Wormhole"));
	OO_CHECK([sWormhole isVisibleToScripts]);
	OO_CHECK_EVAL("typeof Wormhole", "function");
	OO_CHECK_EVAL("new Wormhole()", "threw: unconstructable");
	OO_CHECK_EVAL("Object.getPrototypeOf(Wormhole.prototype) === Entity.prototype", "true");
	OO_CHECK_EVAL("wormhole instanceof Wormhole", "true");
}


OO_TEST(properties)
{
	OO_CHECK_EVAL("wormhole.arrivalTime", "1000.5");
	OO_CHECK_EVAL("wormhole.expiryTime", "900.25");
	OO_CHECK_EVAL("wormhole.origin", "7");
	OO_CHECK_EVAL("wormhole.destination", "129");
	OO_CHECK_EVAL("Object.keys(Wormhole.prototype).join()", "arrivalTime,destination,expiryTime,origin");
	// Read-only.
	OO_CHECK_EVAL("(function () { wormhole.origin = 3; return wormhole.origin; })()", "7");
	OO_CHECK_EVAL("(function () { 'use strict'; try { wormhole.origin = 3; return 'no throw'; } catch (e) { return e instanceof TypeError; } })()", "true");
}


OO_TEST(otherObjects)
{
	// An Entity that is not a wormhole: the getter fails without a JS error, so the property is
	// undefined... as far as the engine's getter says the object is not a wormhole.
	OO_CHECK_EVAL("Object.getOwnPropertyDescriptor(Wormhole.prototype, 'origin').get.call(plainEntity)", "threw: Native method expected WormholeEntity from Entity.");
	OO_CHECK_EVAL("Object.getOwnPropertyDescriptor(Wormhole.prototype, 'origin').get.call({})", "threw: Native method expected Entity, got [object Object].");
	// The prototype has no entity: it reads undefined.
	OO_CHECK_EVAL("Wormhole.prototype.origin", "undefined");
}


OO_TEST(nativeExceptions)
{
	SetUpContext();
	// The property getter is a native (OOJS_NATIVE_ENTER): a raise from the entity is a JS error,
	// and so is a C++ exception.
	sWormhole->_arrivalTime = -1;
	OO_CHECK_EVAL("wormhole.arrivalTime", "threw: Native exception: arrival boom");
	sWormhole->_arrivalTime = -2;
	OO_CHECK_EVAL("wormhole.arrivalTime", "threw: Native exception: cxx boom");
	sWormhole->_arrivalTime = 1000.5;
	OO_CHECK_EVAL("wormhole.arrivalTime", "1000.5");
	OO_CHECK_EQ(sLimiterPauses, 0);
	OO_CHECK(ooscript::isInRequest(sContext));
}


OO_TEST_MAIN()
