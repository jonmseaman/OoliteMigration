/*	test_OOJSDock.mm
	Unit tests for the Dock JS binding (src/Core/Scripting/OOJSDock.h/.mm) and its DockEntity
	category (OOJSDock+ObjCBridge.mm): bead oo-zbx3, converted the way bead oo-ppc converted
	OOJSVector (proposed ADR-0056 amendments oo-ppc and oo-ykoy).

	As test_OOJSWormhole.mm does (amendment oo-ykoy, item 4), it runs the JS class in a real
	context on the game's own façade backend (ooscript/JSEngine_quickjs.cpp), links the game's own
	objects for the binding, its bridge and the engine's exception translator
	(OOJSEngineNativeWrappers.mm), and stands in for the entity classes (Entity, ShipEntity,
	DockEntity answer only the selectors the binding sends) and for the engine functions the
	binding links against, with the engine header's linkage. The expectations were written against
	the Objective-C file and run on it first; they pin the JS-visible behaviour (the five
	properties, the three writable ones, isQueued(), a non-dock, a native's exception) and what the
	category answers the engine. Run: bash tools/check-core-tests.sh
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

@interface ShipEntity: Entity
@end

/*	A dock whose docking queue holds 99 ships raises from -countOfShipsInDockingQueue, one whose
	queue holds 98 throws a C++ exception, so the test sees what an exception under a native
	becomes.
*/
@interface DockEntity: ShipEntity
{
@public
	BOOL _allowsDocking;
	BOOL _disallowedDockingCollides;
	BOOL _allowsLaunching;
	NSUInteger _dockingQueue;
	NSUInteger _launchQueue;
	ShipEntity *_queued;
}
- (BOOL) allowsDocking;
- (void) setAllowsDocking:(BOOL)allow;
- (BOOL) disallowedDockingCollides;
- (void) setDisallowedDockingCollides:(BOOL)ddc;
- (BOOL) allowsLaunching;
- (void) setAllowsLaunching:(BOOL)allow;
- (NSUInteger) countOfShipsInDockingQueue;
- (NSUInteger) countOfShipsInLaunchQueue;
- (BOOL) shipIsInDockingQueue:(ShipEntity *)ship;
@end

@interface Entity (OOJavaScriptExtensions)
- (void) getJSClass:(ooscript::ClassDef **)outClass andPrototype:(ooscript::Object *)outPrototype;
- (std::optional<std::string>) cxx_oo_jsClassName;
@end


#import "OOJSDock.h"

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


@implementation ShipEntity
@end


@implementation DockEntity

- (BOOL) allowsDocking  { return _allowsDocking; }
- (void) setAllowsDocking:(BOOL)allow  { _allowsDocking = allow; }
- (BOOL) disallowedDockingCollides  { return _disallowedDockingCollides; }
- (void) setDisallowedDockingCollides:(BOOL)ddc  { _disallowedDockingCollides = ddc; }
- (BOOL) allowsLaunching  { return _allowsLaunching; }
- (void) setAllowsLaunching:(BOOL)allow  { _allowsLaunching = allow; }
- (NSUInteger) countOfShipsInLaunchQueue  { return _launchQueue; }
- (BOOL) shipIsInDockingQueue:(ShipEntity *)ship  { return ship == _queued; }

- (NSUInteger) countOfShipsInDockingQueue
{
	if (_dockingQueue == 99)  [OOException raise:OOInvalidArgumentException format:"queue %s", "boom"];
	if (_dockingQueue == 98)  throw std::runtime_error("cxx boom");
	return _dockingQueue;
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


void cxx_OOJSReportBadArguments(ooscript::Context context, const std::optional<std::string> &scriptClass, const std::optional<std::string> &function, unsigned argc, ooscript::Value *, const std::optional<std::string> &message, const std::optional<std::string> &expectedArgsDescription)
{
	cxx_OOJSReportError(context, "bad arguments: %s.%s (%u): %s; expected %s", scriptClass.value_or("").c_str(), function.value_or("").c_str(), argc, message.value_or("").c_str(), expectedArgsDescription.value_or("").c_str());
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
ooscript::ClassDef sFakeShipClass = { "Ship", ooscript::ClassFlag::HasPrivate };
ooscript::Object sShipPrototype = nullptr;
std::map<ooscript::ClassDef *, ooscript::ClassDef *> sSuperclasses;
std::map<ooscript::ClassDef *, int> sConverters;
} // namespace

ooscript::Object gOOEntityJSPrototype = nullptr;


extern "C" {

ooscript::ClassDef *JSEntityClass(void)
{
	return &sFakeEntityClass;
}


ooscript::ClassDef *JSShipClass(void)
{
	return &sFakeShipClass;
}


ooscript::Object JSShipPrototype(void)
{
	return sShipPrototype;
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
DockEntity *sDock = nil;
ShipEntity *sShip = nil;


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
	sShipPrototype = ooscript::initClass(sContext, sGlobal, gOOEntityJSPrototype, &sFakeShipClass, OOJSUnconstructableConstruct, 0, nullptr, nullptr, nullptr, nullptr);
	OOJSRegisterSubclass(&sFakeShipClass, &sFakeEntityClass);
	InitOOJSDock(sContext, sGlobal);

	sDock = [[DockEntity alloc] init];	// kept for the life of the test
	sDock->_allowsDocking = YES;
	sDock->_disallowedDockingCollides = NO;
	sDock->_allowsLaunching = YES;
	sDock->_dockingQueue = 3;
	sDock->_launchQueue = 2;
	sShip = [[ShipEntity alloc] init];
	Define("dock", JSValueForEntity(sDock));
	Define("ship", JSValueForObject(&sFakeShipClass, sShipPrototype, sShip));
	Define("otherShip", JSValueForObject(&sFakeShipClass, sShipPrototype, [[ShipEntity alloc] init]));
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
	ooscript::ClassDef *dockClass = nullptr;
	ooscript::Object prototype = nullptr;
	[sDock getJSClass:&dockClass andPrototype:&prototype];
	OO_CHECK(dockClass != nullptr && std::strcmp(dockClass->name, "Dock") == 0);
	OO_CHECK(prototype != nullptr);
	OO_CHECK(OOJSIsSubclass(dockClass, &sFakeShipClass));
	OO_CHECK_EQ(sConverters[dockClass], 1);
	OO_CHECK([sDock cxx_oo_jsClassName] == std::optional<std::string>("Dock"));
	OO_CHECK_EVAL("typeof Dock", "function");
	OO_CHECK_EVAL("new Dock()", "threw: unconstructable");
	OO_CHECK_EVAL("Object.getPrototypeOf(Dock.prototype) === Ship.prototype", "true");
	OO_CHECK_EVAL("dock instanceof Dock && dock instanceof Ship", "true");
}


OO_TEST(properties)
{
	OO_CHECK_EVAL("dock.allowsDocking", "true");
	OO_CHECK_EVAL("dock.disallowedDockingCollides", "false");
	OO_CHECK_EVAL("dock.allowsLaunching", "true");
	OO_CHECK_EVAL("dock.dockingQueueLength", "3");
	OO_CHECK_EVAL("dock.launchingQueueLength", "2");
	OO_CHECK_EVAL("Object.keys(Dock.prototype).join()", "allowsDocking,disallowedDockingCollides,allowsLaunching,dockingQueueLength,launchingQueueLength");
	// The three flags are writable, and a value converts to a boolean.
	OO_CHECK_EVAL("(function () { dock.allowsDocking = false; return dock.allowsDocking; })()", "false");
	OO_CHECK(sDock->_allowsDocking == NO);
	OO_CHECK_EVAL("(function () { dock.allowsLaunching = 0; return dock.allowsLaunching; })()", "false");
	OO_CHECK_EVAL("(function () { dock.disallowedDockingCollides = 'yes'; return dock.disallowedDockingCollides; })()", "true");
	OO_CHECK_EVAL("(function () { dock.allowsDocking = true; dock.allowsLaunching = 1; return dock.allowsDocking && dock.allowsLaunching; })()", "true");
	// The queue lengths are read-only.
	OO_CHECK_EVAL("(function () { dock.dockingQueueLength = 7; return dock.dockingQueueLength; })()", "3");
}


OO_TEST(isQueued)
{
	SetUpContext();
	sDock->_queued = sShip;
	OO_CHECK_EVAL("dock.isQueued(ship)", "true");
	OO_CHECK_EVAL("dock.isQueued(otherShip)", "false");
	OO_CHECK_EVAL("dock.isQueued()", "threw: bad arguments: Dock.isQueued (0): ; expected ship");
	sDock->_queued = nil;
	OO_CHECK_EVAL("dock.isQueued(ship)", "false");
}


OO_TEST(otherObjects)
{
	// A ship that is not a dock, and the prototype (no entity at all): the binding's getter and
	// setter fail without reporting an error, which ends the script uncatchably.
	OO_CHECK_EVAL("Object.getOwnPropertyDescriptor(Dock.prototype, 'allowsDocking').get.call(ship)", "<evaluation failed>");
	OO_CHECK_EVAL("Dock.prototype.allowsDocking", "<evaluation failed>");
	OO_CHECK_EVAL("(function () { Dock.prototype.allowsDocking = false; return 'ok'; })()", "<evaluation failed>");
	// Something that is not an entity: the engine's getter reports it.
	OO_CHECK_EVAL("Object.getOwnPropertyDescriptor(Dock.prototype, 'allowsDocking').get.call({})", "threw: Native method expected Entity, got [object Object].");
	OO_CHECK_EVAL("dock.allowsLaunching", "true");
}


OO_TEST(nativeExceptions)
{
	SetUpContext();
	// The property getter is a native (OOJS_NATIVE_ENTER): a raise from the entity is a JS error,
	// and so is a C++ exception.
	sDock->_dockingQueue = 99;
	OO_CHECK_EVAL("dock.dockingQueueLength", "threw: Native exception: queue boom");
	sDock->_dockingQueue = 98;
	OO_CHECK_EVAL("dock.dockingQueueLength", "threw: Native exception: cxx boom");
	sDock->_dockingQueue = 3;
	OO_CHECK_EVAL("dock.dockingQueueLength", "3");
	OO_CHECK_EQ(sLimiterPauses, 0);
	OO_CHECK_EQ(sProfileDepth, 0);
	OO_CHECK(ooscript::isInRequest(sContext));
}


OO_TEST_MAIN()
