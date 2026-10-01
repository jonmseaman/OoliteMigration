/*	test_OOJSSun.mm
	Unit tests for the Sun JS binding (src/Core/Scripting/OOJSSun.h/.mm) and its OOSunEntity
	category (OOJSSun+ObjCBridge.mm): bead oo-hgfh, converted the way bead oo-ppc converted
	OOJSVector (proposed ADR-0056 amendments oo-ppc and oo-ykoy).

	As test_OOJSWormhole.mm does (amendment oo-ykoy, item 4), it runs the JS class in a real
	context on the game's own façade backend (ooscript/JSEngine_quickjs.cpp), links the game's own
	objects for the binding, its bridge and the engine's exception translator
	(OOJSEngineNativeWrappers.mm), and stands in for the entity classes (Entity and OOSunEntity
	answer only the selectors the binding sends) and for the engine functions the binding links
	against, with the engine headers' linkage. The expectations were written against the
	Objective-C file and run on it first; they pin the JS-visible behaviour (the four properties,
	goNova() and cancelNova(), a non-sun, a native's exception) and what the category answers the
	engine. Run: bash tools/check-core-tests.sh
*/

#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"
#include <objc/runtime.h>
#include "ooscript/JSEngine.hpp"
#include "oofnd/objc/OOException.h"
#include "oofnd/PList.hpp"
#include "oofnd/String.hpp"


// MARK: The entity classes, as far as the binding sees them ---------------------------------------

@interface Entity: OOObject
- (id) weakRefUnderlyingObject;
@end

/*	A sun whose radius is 99 raises from -radius, one whose radius is 98 throws a C++ exception, so
	the test sees what an exception under a native becomes.
*/
@interface OOSunEntity: Entity
{
@public
	double _radius;
	std::optional<std::string> _name;
	BOOL _willGoNova;
	BOOL _goneNova;
	double _novaTime;
	int _novaCalls;
}
- (double) radius;
- (std::optional<std::string>) cxx_name;
- (BOOL) willGoNova;
- (BOOL) goneNova;
- (void) setGoingNova:(BOOL)yesno inTime:(double)interval;
@end

@interface Entity (OOJavaScriptExtensions)
- (void) getJSClass:(ooscript::ClassDef **)outClass andPrototype:(ooscript::Object *)outPrototype;
- (std::optional<std::string>) cxx_oo_jsClassName;
- (BOOL) isVisibleToScripts;
@end


#import "OOJSSun.h"

#include "oo_test.hpp"

#include <cstdarg>
#include <cstring>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>


@implementation Entity

- (id) weakRefUnderlyingObject  { return self; }

@end


@implementation OOSunEntity

- (std::optional<std::string>) cxx_name  { return _name; }
- (BOOL) willGoNova  { return _willGoNova; }
- (BOOL) goneNova  { return _goneNova; }

- (double) radius
{
	if (_radius == 99)  [OOException raise:OOInvalidArgumentException format:"radius %s", "boom"];
	if (_radius == 98)  throw std::runtime_error("cxx boom");
	return _radius;
}

- (void) setGoingNova:(BOOL)yesno inTime:(double)interval
{
	_willGoNova = yesno;
	_novaTime = interval;
	_novaCalls++;
}

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
OOSunEntity *sSun = nil;


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
	InitOOJSSun(sContext, sGlobal);

	sSun = [[OOSunEntity alloc] init];	// kept for the life of the test
	sSun->_radius = 250000.5;
	sSun->_name = "Lave";
	Define("sun", JSValueForEntity(sSun));
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
	ooscript::ClassDef *sunClass = nullptr;
	ooscript::Object prototype = nullptr;
	[sSun getJSClass:&sunClass andPrototype:&prototype];
	OO_CHECK(sunClass != nullptr && std::strcmp(sunClass->name, "Sun") == 0);
	OO_CHECK(prototype != nullptr);
	OO_CHECK(OOJSIsSubclass(sunClass, &sFakeEntityClass));
	OO_CHECK_EQ(sConverters[sunClass], 1);
	OO_CHECK([sSun cxx_oo_jsClassName] == std::optional<std::string>("Sun"));
	OO_CHECK([sSun isVisibleToScripts]);
	OO_CHECK_EVAL("typeof Sun", "function");
	OO_CHECK_EVAL("new Sun()", "threw: unconstructable");
	OO_CHECK_EVAL("Object.getPrototypeOf(Sun.prototype) === Entity.prototype", "true");
	OO_CHECK_EVAL("sun instanceof Sun", "true");
}


OO_TEST(properties)
{
	SetUpContext();
	OO_CHECK_EVAL("sun.radius", "250000.5");
	OO_CHECK_EVAL("sun.name", "Lave");
	OO_CHECK_EVAL("sun.hasGoneNova", "false");
	OO_CHECK_EVAL("sun.isGoingNova", "false");
	OO_CHECK_EVAL("Object.keys(Sun.prototype).join()", "hasGoneNova,isGoingNova,name,radius");
	sSun->_name = std::nullopt;
	OO_CHECK_EVAL("sun.name", "null");
	sSun->_name = "Lave";
	// Read-only.
	OO_CHECK_EVAL("(function () { sun.radius = 1; return sun.radius; })()", "250000.5");
}


OO_TEST(nova)
{
	SetUpContext();
	sSun->_novaCalls = 0;
	OO_CHECK_EVAL("sun.goNova(30)", "undefined");
	OO_CHECK(sSun->_willGoNova && sSun->_novaTime == 30 && sSun->_novaCalls == 1);
	OO_CHECK_EVAL("sun.isGoingNova", "true");
	OO_CHECK_EVAL("sun.goNova()", "undefined");
	OO_CHECK(sSun->_novaTime == 0 && sSun->_novaCalls == 2);
	OO_CHECK_EVAL("sun.cancelNova()", "undefined");
	OO_CHECK(!sSun->_willGoNova && sSun->_novaCalls == 3);
	OO_CHECK_EVAL("sun.cancelNova()", "undefined");	// not going nova: nothing to cancel
	OO_CHECK_EQ(sSun->_novaCalls, 3);
	// Gone nova: isGoingNova is false, and cancelNova() does nothing.
	sSun->_willGoNova = YES;
	sSun->_goneNova = YES;
	OO_CHECK_EVAL("sun.hasGoneNova", "true");
	OO_CHECK_EVAL("sun.isGoingNova", "false");
	OO_CHECK_EVAL("sun.cancelNova()", "undefined");
	OO_CHECK_EQ(sSun->_novaCalls, 3);
	sSun->_willGoNova = NO;
	sSun->_goneNova = NO;
}


OO_TEST(otherObjects)
{
	OO_CHECK_EVAL("Object.getOwnPropertyDescriptor(Sun.prototype, 'radius').get.call(plainEntity)", "threw: Native method expected Sun, got [object Entity].");
	OO_CHECK_EVAL("Sun.prototype.goNova.call({})", "threw: Native method expected Sun, got [object Object].");
	OO_CHECK_EVAL("Sun.prototype.radius", "0");	// the prototype has no sun: a message to nil
}


OO_TEST(nativeExceptions)
{
	SetUpContext();
	// The property getter is a native (OOJS_NATIVE_ENTER): a raise from the entity is a JS error,
	// and so is a C++ exception.
	sSun->_radius = 99;
	OO_CHECK_EVAL("sun.radius", "threw: Native exception: radius boom");
	sSun->_radius = 98;
	OO_CHECK_EVAL("sun.radius", "threw: Native exception: cxx boom");
	sSun->_radius = 250000.5;
	OO_CHECK_EVAL("sun.radius", "250000.5");
	OO_CHECK_EQ(sLimiterPauses, 0);
	OO_CHECK_EQ(sProfileDepth, 0);
	OO_CHECK(ooscript::isInRequest(sContext));
}


OO_TEST_MAIN()
