/*	test_OOJSFlasher.mm
	Unit tests for the Flasher JS binding (src/Core/Scripting/OOJSFlasher.h/.mm) and its
	OOFlasherEntity category (OOJSFlasher+ObjCBridge.mm): bead oo-ub2g, converted the way bead
	oo-ppc converted OOJSVector (proposed ADR-0056 amendments oo-ppc and oo-ykoy).

	As test_OOJSWormhole.mm does (amendment oo-ykoy, item 4), it runs the JS class in a real
	context on the game's own façade backend (ooscript/JSEngine_quickjs.cpp), links the game's own
	objects for the binding, its bridge, the engine's exception translator
	(OOJSEngineNativeWrappers.mm) and OOColor (a converted class, reached through its façade), and
	stands in for the entity classes (Entity, ShipEntity, OOVisualEffectEntity and OOFlasherEntity
	answer only the selectors the binding sends) and for the engine functions the binding links
	against, with the engine headers' linkage. The binding header is not imported, because until
	this bead it imported OOFlasherEntity.h; InitOOJSFlasher is declared here. The expectations
	were written against the Objective-C file and run on it first; they pin the JS-visible
	behaviour (the six properties and their ranges, the colour both ways, remove() from a ship and
	from a visual effect, a stale flasher, a native's exception) and what the category answers the
	engine. Run: bash tools/check-core-tests.sh
*/

#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"
#include <objc/runtime.h>
#import "OOColor.h"
#include "ooscript/JSEngine.hpp"
#include "oofnd/objc/OOException.h"
#include "oofnd/PList.hpp"
#include "oofnd/String.hpp"


// MARK: The entity classes, as far as the binding sees them ---------------------------------------

@class OOFlasherEntity;

@interface Entity: OOObject
{
@public
	id _owner;
	id _removed;
}
- (id) weakRefUnderlyingObject;
- (id) owner;
- (BOOL) isShip;
@end

@interface ShipEntity: Entity
- (void) removeFlasher:(OOFlasherEntity *)flasher;
@end

@interface OOVisualEffectEntity: Entity
- (void) removeSubEntity:(Entity *)sub;
@end

/*	A flasher whose frequency is 99 raises from -frequency, one whose frequency is 98 throws a C++
	exception, so the test sees what an exception under a native becomes.
*/
@interface OOFlasherEntity: Entity
{
@public
	BOOL _active;
	OOColor *_color;
	float _frequency;
	float _fraction;
	float _phase;
	float _diameter;
}
- (BOOL) isActive;
- (void) setActive:(BOOL)active;
- (OOColor *) color;
- (void) setColor:(OOColor *)color;
- (float) frequency;
- (void) setFrequency:(float)frequency;
- (float) fraction;
- (void) setFraction:(float)fraction;
- (float) phase;
- (void) setPhase:(float)phase;
- (float) diameter;
- (void) setDiameter:(float)diameter;
@end

@interface Entity (OOJavaScriptExtensions)
- (void) getJSClass:(ooscript::ClassDef **)outClass andPrototype:(ooscript::Object *)outPrototype;
- (std::optional<std::string>) cxx_oo_jsClassName;
- (BOOL) isVisibleToScripts;
@end

extern "C" void InitOOJSFlasher(ooscript::Context context, ooscript::Object global);


#include "oo_test.hpp"

#include <cstdarg>
#include <cstdint>
#include <cstring>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>


@implementation Entity

- (id) weakRefUnderlyingObject  { return self; }
- (id) owner  { return _owner; }
- (BOOL) isShip  { return NO; }

@end


@implementation ShipEntity

- (BOOL) isShip  { return YES; }
- (void) removeFlasher:(OOFlasherEntity *)flasher  { _removed = flasher; }

@end


@implementation OOVisualEffectEntity

- (void) removeSubEntity:(Entity *)sub  { _removed = sub; }

@end


@implementation OOFlasherEntity

- (BOOL) isActive  { return _active; }
- (void) setActive:(BOOL)active  { _active = active; }
- (OOColor *) color  { return _color; }
- (void) setColor:(OOColor *)color  { [_color release]; _color = [color retain]; }
- (void) setFrequency:(float)frequency  { _frequency = frequency; }
- (float) fraction  { return _fraction; }
- (void) setFraction:(float)fraction  { _fraction = fraction; }
- (float) phase  { return _phase; }
- (void) setPhase:(float)phase  { _phase = phase; }
- (float) diameter  { return _diameter; }
- (void) setDiameter:(float)diameter  { _diameter = diameter; }

- (float) frequency
{
	if (_frequency == 99)  [OOException raise:OOInvalidArgumentException format:"frequency %s", "boom"];
	if (_frequency == 98)  throw std::runtime_error("cxx boom");
	return _frequency;
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
Entity *gOOJSPlayerIfStale = nil;


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


// A JS value's plist form, as far as a colour description needs one: a string, a number, an array
// of those, or null.
oo::PList cxx_OOJSPListFromJSValue(ooscript::Context context, ooscript::Value value)
{
	double number = 0;
	if (ooscript::isString(value))  return oo::PList(cxx_OOStringFromJSValue(context, value).value_or(""));
	if (ooscript::isNumber(value) && ooscript::valueToNumber(context, value, &number))  return oo::PList(number);
	if (ooscript::isObject(value) && ooscript::isArrayObject(context, ooscript::toObject(value)))
	{
		std::uint32_t length = 0;
		ooscript::getArrayLength(context, ooscript::toObject(value), &length);
		oo::PList::Array array;
		for (std::uint32_t i = 0; i < length; i++)
		{
			ooscript::Value element;
			if (ooscript::getElement(context, ooscript::toObject(value), i, &element))  array.push_back(cxx_OOJSPListFromJSValue(context, element));
		}
		return oo::PList(std::move(array));
	}
	return oo::PList();
}


oo::PList OOJSBasicPrivateObjectConverter(ooscript::Context, ooscript::Object)
{
	return oo::PList();
}


// MARK: The context -------------------------------------------------------------------------------

namespace {

ooscript::Runtime sRuntime;
ooscript::Context sContext;
ooscript::Object sGlobal;
OOFlasherEntity *sFlasher = nil;
ShipEntity *sShip = nil;
OOVisualEffectEntity *sEffect = nil;


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
	InitOOJSFlasher(sContext, sGlobal);

	sShip = [[ShipEntity alloc] init];	// kept for the life of the test
	sEffect = [[OOVisualEffectEntity alloc] init];
	sFlasher = [[OOFlasherEntity alloc] init];
	sFlasher->_active = YES;
	sFlasher->_color = [[OOColor colorWithRed:1 green:0.5f blue:0.25f alpha:1] retain];
	sFlasher->_frequency = 2;
	sFlasher->_fraction = 0.5f;
	sFlasher->_phase = 0.25f;
	sFlasher->_diameter = 10;
	sFlasher->_owner = sShip;
	Define("flasher", JSValueForEntity(sFlasher));
	Define("ship", JSValueForObject(&sFakeEntityClass, gOOEntityJSPrototype, sShip));
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
	ooscript::ClassDef *flasherClass = nullptr;
	ooscript::Object prototype = nullptr;
	[sFlasher getJSClass:&flasherClass andPrototype:&prototype];
	OO_CHECK(flasherClass != nullptr && std::strcmp(flasherClass->name, "Flasher") == 0);
	OO_CHECK(prototype != nullptr);
	OO_CHECK(OOJSIsSubclass(flasherClass, &sFakeEntityClass));
	OO_CHECK_EQ(sConverters[flasherClass], 1);
	OO_CHECK([sFlasher cxx_oo_jsClassName] == std::optional<std::string>("Flasher"));
	OO_CHECK([sFlasher isVisibleToScripts]);
	OO_CHECK_EVAL("typeof Flasher", "function");
	OO_CHECK_EVAL("new Flasher()", "threw: unconstructable");
	OO_CHECK_EVAL("Object.getPrototypeOf(Flasher.prototype) === Entity.prototype", "true");
	OO_CHECK_EVAL("flasher instanceof Flasher", "true");
}


OO_TEST(properties)
{
	OO_CHECK_EVAL("flasher.active", "true");
	OO_CHECK_EVAL("flasher.color", "1,0.5,0.25,1");
	OO_CHECK_EVAL("flasher.frequency", "2");
	OO_CHECK_EVAL("flasher.fraction", "0.5");
	OO_CHECK_EVAL("flasher.phase", "0.25");
	OO_CHECK_EVAL("flasher.size", "10");
	OO_CHECK_EVAL("Object.keys(Flasher.prototype).join()", "active,color,fraction,frequency,phase,size");
}


OO_TEST(setters)
{
	OO_CHECK_EVAL("(function () { flasher.active = 0; return flasher.active; })()", "false");
	OO_CHECK_EVAL("(function () { flasher.active = 'yes'; return flasher.active; })()", "true");
	OO_CHECK_EVAL("(function () { flasher.frequency = 3.5; return flasher.frequency; })()", "3.5");
	OO_CHECK_EVAL("(function () { flasher.frequency = 0; return flasher.frequency; })()", "0");
	OO_CHECK_EVAL("(function () { flasher.frequency = -1; return flasher.frequency; })()", "threw: bad property value");
	OO_CHECK_EVAL("(function () { flasher.fraction = 1; return flasher.fraction; })()", "1");
	OO_CHECK_EVAL("(function () { flasher.fraction = 0; return flasher.fraction; })()", "threw: bad property value");
	OO_CHECK_EVAL("(function () { flasher.fraction = 1.5; return flasher.fraction; })()", "threw: bad property value");
	OO_CHECK_EVAL("(function () { flasher.phase = -0.75; return flasher.phase; })()", "-0.75");
	OO_CHECK_EVAL("(function () { flasher.size = 4; return flasher.size; })()", "4");
	OO_CHECK_EVAL("(function () { flasher.size = 0; return flasher.size; })()", "threw: bad property value");
	OO_CHECK_EVAL("(function () { flasher.size = 'abc'; return flasher.size; })()", "threw: bad property value");
	OO_CHECK(sFlasher->_frequency == 0 && sFlasher->_fraction == 1 && sFlasher->_phase == -0.75f && sFlasher->_diameter == 4);
}


OO_TEST(color)
{
	OO_CHECK_EVAL("(function () { flasher.color = [0, 1, 0]; return flasher.color; })()", "0,1,0,1");
	OO_CHECK_EVAL("(function () { flasher.color = 'redColor'; return flasher.color; })()", "1,0,0,1");
	OO_CHECK_EVAL("(function () { flasher.color = null; return flasher.color; })()", "null");
	OO_CHECK(sFlasher->_color == nil);
	OO_CHECK_EVAL("(function () { flasher.color = 'not a colour'; return flasher.color; })()", "threw: bad property value");
	OO_CHECK_EVAL("(function () { flasher.color = [0.25, 0.5, 0.75, 0.5]; return flasher.color; })()", "0.25,0.5,0.75,0.5");
	OO_CHECK(sFlasher->_color != nil && [sFlasher->_color alphaComponent] == 0.5f);
}


OO_TEST(remove)
{
	SetUpContext();
	sShip->_removed = nil;
	sFlasher->_owner = sShip;
	OO_CHECK_EVAL("flasher.remove()", "undefined");
	OO_CHECK(sShip->_removed == sFlasher);
	sFlasher->_owner = sEffect;
	OO_CHECK_EVAL("flasher.remove()", "undefined");
	OO_CHECK(sEffect->_removed == sFlasher);
	sFlasher->_owner = sShip;
	// The prototype has no entity: the binding's getter fails without reporting an error, which
	// ends the script uncatchably, and nothing is removed.
	sShip->_removed = nil;
	OO_CHECK_EVAL("Flasher.prototype.remove()", "<evaluation failed>");
	OO_CHECK(sShip->_removed == nil);
}


OO_TEST(otherObjects)
{
	// An entity that is not a flasher, and the prototype: the binding's getter fails without
	// reporting an error, which ends the script uncatchably.
	OO_CHECK_EVAL("Object.getOwnPropertyDescriptor(Flasher.prototype, 'size').get.call(ship)", "<evaluation failed>");
	OO_CHECK_EVAL("Flasher.prototype.size", "<evaluation failed>");
	// Something that is not an entity: the engine's getter reports it.
	OO_CHECK_EVAL("Object.getOwnPropertyDescriptor(Flasher.prototype, 'size').get.call({})", "threw: Native method expected Entity, got [object Object].");
	OO_CHECK_EVAL("flasher.active", "true");
}


OO_TEST(nativeExceptions)
{
	SetUpContext();
	// The property getter is a native (OOJS_NATIVE_ENTER): a raise from the entity is a JS error,
	// and so is a C++ exception.
	sFlasher->_frequency = 99;
	OO_CHECK_EVAL("flasher.frequency", "threw: Native exception: frequency boom");
	sFlasher->_frequency = 98;
	OO_CHECK_EVAL("flasher.frequency", "threw: Native exception: cxx boom");
	sFlasher->_frequency = 2;
	OO_CHECK_EVAL("flasher.frequency", "2");
	OO_CHECK_EQ(sLimiterPauses, 0);
	OO_CHECK_EQ(sProfileDepth, 0);
	OO_CHECK(ooscript::isInRequest(sContext));
}


OO_TEST_MAIN()
