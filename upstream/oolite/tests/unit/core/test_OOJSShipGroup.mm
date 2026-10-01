/*	test_OOJSShipGroup.mm
	Unit tests for the ShipGroup JS binding (src/Core/Scripting/OOJSShipGroup.h/.mm) and its
	OOShipGroup category (OOJSShipGroup+ObjCBridge.mm): bead oo-n64m, converted the way bead oo-ppc
	converted OOJSVector (proposed ADR-0056 amendments oo-ppc and oo-ykoy).

	As test_OOJSWormhole.mm does (amendment oo-ykoy, item 4), it runs the JS class in a real
	context on the game's own façade backend (ooscript/JSEngine_quickjs.cpp), links the game's own
	objects for the binding, its bridge, the engine's exception translator
	(OOJSEngineNativeWrappers.mm) and OOShipGroup (a converted class, reached through its façade,
	as test_OOShipGroup.mm links it), and stands in for ShipEntity (a weakly referenced object
	answering only the selectors the binding and the group send, with a JS object of its own),
	OONull, and the engine functions the binding links against, with the engine headers' linkage.
	The engine's native-object conversion asks the object for its JS value, as the engine does, so
	a group's JS object is the one the category makes. The expectations were written against the
	Objective-C file and run on it first; they pin the JS-visible behaviour (the constructor, the
	four properties both ways, addShip() with its escort rules, removeShip(), containsShip(), a
	non-group, a native's exception) and what the category answers the engine (one JS object per
	group until the engine clears it). Run: bash tools/check-core-tests.sh
*/

#import "OOShipGroup.h"
#import "OOWeakReference.h"
#include <objc/runtime.h>
#include "ooscript/JSEngine.hpp"
#include "oofnd/objc/OOException.h"
#include "oofnd/PList.hpp"
#include "oofnd/String.hpp"
#import "OODescription.h"
#import "OOObjCPList.h"


// MARK: The classes, as far as the binding sees them ----------------------------------------------

/*	A ship: the group it is in, the group it leads as escorts, and whether it takes an escort. A
	ship named "boom" raises from -acceptAsEscort:, so the test sees what an exception under a
	native becomes.
*/
@interface ShipEntity: OOWeakRefObject
{
@public
	std::string _name;
	OOShipGroup *_group;
	OOShipGroup *_escortGroup;
	BOOL _acceptsEscorts;
	int _accepted;
	ooscript::Object _jsSelf;
}
- (OOShipGroup *) group;
- (void) setGroup:(OOShipGroup *)group;
- (void) setOwner:(id)owner;
- (OOShipGroup *) escortGroup;
- (BOOL) acceptAsEscort:(ShipEntity *)other_ship;
@end

@interface OONull: OOObject
+ (OONull *) null;
@end

@interface OOObject (OOJSTestGlue)
- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context;
- (void) oo_clearJSSelf:(ooscript::Object)selfVal;
@end


#import "OOJSShipGroup.h"

#include "oo_test.hpp"

#include <cstdarg>
#include <cstdint>
#include <cstring>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>


namespace {
ooscript::Context sContext;
ooscript::ClassDef sFakeShipClass = { "Ship", ooscript::ClassFlag::HasPrivate };
ooscript::Object sFakeShipPrototype = nullptr;
}


@implementation ShipEntity

- (OOShipGroup *) group  { return _group; }
- (void) setGroup:(OOShipGroup *)group  { _group = group; }
- (void) setOwner:(id)owner  { (void)owner; }
- (OOShipGroup *) escortGroup  { return _escortGroup; }

- (BOOL) acceptAsEscort:(ShipEntity *)other_ship
{
	if (other_ship->_name == "boom")  [OOException raise:OOInvalidArgumentException format:"escort %s", "boom"];
	if (!_acceptsEscorts)  return NO;
	_accepted++;
	return YES;
}

- (std::optional<std::string>) cxx_descriptionComponents  { return _name; }

- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context
{
	if (_jsSelf == nullptr)
	{
		_jsSelf = ooscript::newObject(context, &sFakeShipClass, sFakeShipPrototype, nullptr);
		ooscript::setPrivate(context, _jsSelf, self);
	}
	return ooscript::objectValue(_jsSelf);
}

@end


@implementation OONull

+ (OONull *) null
{
	static OONull *null = [[OONull alloc] init];
	return null;
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


namespace {
std::string sLastWarning;
}

void cxx_OOJSReportWarningForCaller(ooscript::Context, const std::optional<std::string> &scriptClass, const std::optional<std::string> &function, const char *format, ...)
{
	va_list args;
	va_start(args, format);
	sLastWarning = scriptClass.value_or("-") + "." + function.value_or("-") + ": " + oo::str::vformat(format, args);
	va_end(args);
}


void cxx_OOJSReportBadArguments(ooscript::Context context, const std::optional<std::string> &scriptClass, const std::optional<std::string> &function, unsigned argc, ooscript::Value *, const std::optional<std::string> &message, const std::optional<std::string> &expectedArgsDescription)
{
	cxx_OOJSReportError(context, "bad arguments: %s.%s(%u) %s / %s", scriptClass.value_or("-").c_str(), function.value_or("-").c_str(), argc, message.value_or("-").c_str(), expectedArgsDescription.value_or("-").c_str());
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


std::optional<std::string> cxx_OOStringFromJSValueEvenIfNull(ooscript::Context context, ooscript::Value value)
{
	if (ooscript::isNull(value))  return std::string("null");
	if (ooscript::isUndefined(value))  return std::string("undefined");
	return cxx_OOStringFromJSValue(context, value);
}


extern "C" ooscript::Value OOJSValueFromNativeObject(ooscript::Context context, id object);


// A property list as JavaScript, as far as the binding hands one over: null, a string, a number,
// an object (its JS value; OONull is null), or an array of those.
ooscript::Value OOJSValueFromPList(ooscript::Context context, const oo::PList &plist)
{
	if (const std::string *str = plist.getIf<std::string>())
	{
		ooscript::String js = ooscript::newStringCopyN(context, str->data(), str->size());
		return js != nullptr ? ooscript::stringValue(js) : ooscript::nullValue();
	}
	if (plist.isNumber())  return ooscript::numberValue(plist.doubleValue());
	if (id object = oo::ObjectIn(plist))  return OOJSValueFromNativeObject(context, object);
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
std::map<ooscript::ClassDef *, int> sConverters;
int sFinalized = 0;
} // namespace


extern "C" {

void OOJSReportBadPropertySelector(ooscript::Context context, ooscript::Object, ooscript::PropertyId, ooscript::PropertySpec *)
{
	cxx_OOJSReportError(context, "bad property selector");
}


void OOJSReportBadPropertyValue(ooscript::Context context, ooscript::Object, ooscript::PropertyId, ooscript::PropertySpec *, ooscript::Value)
{
	cxx_OOJSReportError(context, "bad property value");
}


void OOJSRegisterObjectConverter(ooscript::ClassDef *theClass, oo::PList (*)(ooscript::Context, ooscript::Object))
{
	sConverters[theClass]++;
}


// The engine's object getter: the JS class must be the required one, and the private object
// must be of the required Objective-C class.
BOOL OOJSObjectGetterImplPRIVATE(ooscript::Context context, ooscript::Object object, ooscript::ClassDef *requiredJSClass, Class requiredObjCClass, const char *, id *outObject)
{
	if (ooscript::getObjectClass(context, object) != requiredJSClass)
	{
		cxx_OOJSReportError(context, "Native method expected %s, got %s.", requiredJSClass->name, cxx_OOStringFromJSValue(context, ooscript::objectValue(object)).value_or("(null)").c_str());
		return NO;
	}
	*outObject = (id)ooscript::getPrivate(context, object);
	if (*outObject != nil && ![*outObject isKindOfClass:requiredObjCClass])
	{
		cxx_OOJSReportError(context, "Native method expected %s from %s.", class_getName(requiredObjCClass), requiredJSClass->name);
		*outObject = nil;
		return NO;
	}
	return YES;
}


// The engine's conversion asks the object for its JS value; nil and OONull are null.
ooscript::Value OOJSValueFromNativeObject(ooscript::Context context, id object)
{
	if (object == nil || [object isKindOfClass:[OONull class]])  return ooscript::nullValue();
	return [object oo_jsValueInContext:context];
}


// The private object of a JS object, if it is of the class.
id OOJSNativeObjectOfClassFromJSValue(ooscript::Context context, ooscript::Value value, Class requiredClass)
{
	if (!ooscript::isObject(value) || ooscript::isNull(value))  return nil;
	id object = (id)ooscript::getPrivate(context, ooscript::toObject(value));
	return [object isKindOfClass:requiredClass] ? object : nil;
}


bool OOJSObjectWrapperToString(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	id object = (id)ooscript::getPrivate(context, oojsArgs.thisObject());
	std::string text = "[" + oo::DescriptionOf(object) + "]";
	oojsArgs.setRval(ooscript::stringValue(ooscript::newStringCopyN(context, text.data(), text.size())));
	return true;
}


// The engine's wrapper finalizer: the object forgets its JS self, and the wrapper's retain goes.
void OOJSObjectWrapperFinalize(ooscript::Context context, ooscript::Object object)
{
	id native = (id)ooscript::getPrivate(context, object);
	if (native != nil)
	{
		[native oo_clearJSSelf:object];
		[native release];
		sFinalized++;
	}
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
ooscript::Object sGlobal;


void Define(const char *name, ooscript::Value value)
{
	ooscript::setProperty(sContext, sGlobal, name, &value);
}


ShipEntity *NewShip(const char *name)
{
	ShipEntity *ship = [[ShipEntity alloc] init];	// kept for the life of the test
	ship->_name = name;
	Define(name, [ship oo_jsValueInContext:sContext]);
	return ship;
}


void SetUpContext()
{
	if (sContext != nullptr)  return;
	sRuntime = ooscript::newRuntime(8u * 1024u * 1024u);
	sContext = ooscript::newContext(sRuntime, 8192);
	ooscript::beginRequest(sContext);
	sGlobal = ooscript::getGlobalObject(sContext);
	ooscript::initStandardClasses(sContext, sGlobal);
	sFakeShipPrototype = ooscript::initClass(sContext, sGlobal, nullptr, &sFakeShipClass, nullptr, 0, nullptr, nullptr, nullptr, nullptr);
	InitOOJSShipGroup(sContext, sGlobal);
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
	OO_CHECK_EQ(sConverters.size(), 1u);
	OO_CHECK_EVAL("typeof ShipGroup", "function");
	OO_CHECK_EVAL("Object.keys(ShipGroup.prototype).join()", "count,leader,name,ships");
	OO_CHECK_EVAL("ShipGroup()", "threw: ShipGroup() cannot be called as a function, it must be used as a constructor (as in new ShipGroup(...)).");
	OO_CHECK_EVAL("new ShipGroup() instanceof ShipGroup", "true");
}


OO_TEST(category)
{
	SetUpContext();
	// One JS object per group, made on first use; the engine's finalizer clears it.
	OOShipGroup *group = [OOShipGroup cxx_groupWithName:std::string("cat")];
	ooscript::Value first = [group oo_jsValueInContext:sContext];
	OO_CHECK(ooscript::isObject(first));
	OO_CHECK(ooscript::toObject([group oo_jsValueInContext:sContext]) == ooscript::toObject(first));
	OO_CHECK((id)ooscript::getPrivate(sContext, ooscript::toObject(first)) == group);
	Define("catGroup", first);
	OO_CHECK_EVAL("catGroup.name", "cat");
	// Clearing with another object leaves it; clearing with its own makes the next one new.
	[group oo_clearJSSelf:nullptr];
	OO_CHECK(ooscript::toObject([group oo_jsValueInContext:sContext]) == ooscript::toObject(first));
	[group oo_clearJSSelf:ooscript::toObject(first)];
	ooscript::Value second = [group oo_jsValueInContext:sContext];
	OO_CHECK(ooscript::isObject(second) && ooscript::toObject(second) != ooscript::toObject(first));
}


OO_TEST(constructor)
{
	SetUpContext();
	NewShip("alpha");
	OO_CHECK_EVAL("new ShipGroup().name", "null");
	OO_CHECK_EVAL("new ShipGroup().count", "0");
	OO_CHECK_EVAL("new ShipGroup('wing').name", "wing");
	OO_CHECK_EVAL("(function () { var g = new ShipGroup('wing', alpha); return g.leader === alpha && g.count === 1 && g.ships[0] === alpha; })()", "true");
	OO_CHECK_EVAL("new ShipGroup('wing', null).leader", "null");
	OO_CHECK_EVAL("new ShipGroup(5)", "threw: bad arguments: -.ShipGroup()(1) Could not create ShipGroup / group name");
	OO_CHECK_EVAL("new ShipGroup('wing', {})", "threw: bad arguments: -.ShipGroup()(1) Could not create ShipGroup / ship");
	OO_CHECK_EVAL("String(new ShipGroup('wing')).replace(/0x[0-9a-f]+/, 'ADDR')", "[<OOShipGroup ADDR>{\"wing\", 0 ships}]");
}


OO_TEST(properties)
{
	SetUpContext();
	NewShip("beta");
	NewShip("gamma");
	OO_CHECK_EVAL("(function () { var g = new ShipGroup('g'); g.name = 'h'; return g.name; })()", "h");
	OO_CHECK_EVAL("(function () { var g = new ShipGroup('g'); g.name = null; return g.name; })()", "null");
	OO_CHECK_EVAL("(function () { var g = new ShipGroup('g'); g.name = 3; return g.name; })()", "3");
	OO_CHECK_EVAL("(function () { var g = new ShipGroup('g'); g.leader = beta; return g.leader === beta && g.count; })()", "1");
	OO_CHECK_EVAL("(function () { var g = new ShipGroup('g', beta); g.leader = null; return String(g.leader) + ' ' + g.count; })()", "null 1");
	OO_CHECK_EVAL("(function () { var g = new ShipGroup('g'); g.leader = 'x'; return g.leader; })()", "threw: bad property value");
	OO_CHECK_EVAL("(function () { var g = new ShipGroup('g'); g.addShip(beta); g.addShip(gamma); return g.ships.length + ' ' + g.count; })()", "2 2");
	// Read-only.
	OO_CHECK_EVAL("(function () { var g = new ShipGroup('g'); g.count = 5; return g.count; })()", "0");
	OO_CHECK_EVAL("(function () { var g = new ShipGroup('g'); g.ships = [beta]; return g.ships.length; })()", "0");
}


OO_TEST(membership)
{
	SetUpContext();
	NewShip("delta");
	NewShip("epsilon");
	OO_CHECK_EVAL("(function () { var g = new ShipGroup('m'); return [g.addShip(delta), g.containsShip(delta), g.containsShip(epsilon), g.count].join(); })()", "true,true,false,1");
	OO_CHECK_EVAL("(function () { var g = new ShipGroup('m'); g.addShip(delta); return [g.addShip(delta), g.count].join(); })()", ",1");	// already there: nothing to do
	OO_CHECK_EVAL("(function () { var g = new ShipGroup('m'); g.addShip(delta); return [g.removeShip(delta), g.containsShip(delta), g.count].join(); })()", "true,false,0");
	OO_CHECK_EVAL("(function () { var g = new ShipGroup('m'); return g.removeShip(epsilon); })()", "false");
	// null is accepted and does nothing; anything else is an error.
	OO_CHECK_EVAL("new ShipGroup('m').addShip(null)", "undefined");
	OO_CHECK_EVAL("new ShipGroup('m').removeShip(null)", "undefined");
	OO_CHECK_EVAL("new ShipGroup('m').containsShip(null)", "false");
	OO_CHECK_EVAL("new ShipGroup('m').addShip()", "threw: bad arguments: ShipGroup.addShip(0) - / ship");
	OO_CHECK_EVAL("new ShipGroup('m').removeShip({})", "threw: bad arguments: ShipGroup.removeShip(1) - / ship");
	OO_CHECK_EVAL("new ShipGroup('m').containsShip('x')", "threw: bad arguments: ShipGroup.containsShip(1) - / ship");
}


OO_TEST(escorts)
{
	SetUpContext();
	ShipEntity *leader = NewShip("leader");
	ShipEntity *escort = NewShip("escort");
	ShipEntity *other = NewShip("otherLeader");
	ShipEntity *taken = NewShip("taken");
	// The leader's escort group with escorts already: the new ship must be accepted as an escort.
	OOShipGroup *escorts = [OOShipGroup cxx_groupWithName:std::string("escorts") leader:leader];
	[escorts addShip:NewShip("first")];
	leader->_escortGroup = escorts;
	leader->_group = escorts;
	Define("escorts", [escorts oo_jsValueInContext:sContext]);
	leader->_acceptsEscorts = NO;
	OO_CHECK_EVAL("[escorts.addShip(escort), escorts.containsShip(escort)].join()", "false,false");
	leader->_acceptsEscorts = YES;
	OO_CHECK_EVAL("[escorts.addShip(escort), escorts.containsShip(escort)].join()", "true,true");
	OO_CHECK_EQ(leader->_accepted, 1);
	// A ship that already escorts someone else is refused, with a warning.
	OOShipGroup *otherEscorts = [OOShipGroup cxx_groupWithName:std::string("other") leader:other];
	[otherEscorts addShip:taken];
	other->_escortGroup = otherEscorts;
	taken->_group = otherEscorts;
	sLastWarning.clear();
	OO_CHECK_EVAL("escorts.addShip(taken)", "false");
	OO_CHECK_EQ(sLastWarning, "ShipGroup.addShip: Ship " + oo::DescriptionOf(taken) + " cannot be assigned to two escort groups, ignoring.");
	OO_CHECK(oo::DescriptionOf(taken).find("{taken}") != std::string::npos);
	// A lone leader whose escort group is its own group gets a new group, and the ship joins that.
	ShipEntity *lone = NewShip("lone");
	OOShipGroup *loneGroup = [OOShipGroup cxx_groupWithName:std::string("alone") leader:lone];
	lone->_escortGroup = loneGroup;
	lone->_group = loneGroup;
	Define("loneGroup", [loneGroup oo_jsValueInContext:sContext]);
	OO_CHECK_EVAL("[loneGroup.addShip(escort), loneGroup.containsShip(escort)].join()", "true,false");
	OO_CHECK(lone->_group != loneGroup && [lone->_group containsShip:escort]);
	OO_CHECK([lone->_group cxx_name] == std::optional<std::string>("ship group"));
	// A lone leader with a group of its own: it is asked to accept the escort.
	ShipEntity *custom = NewShip("custom");
	OOShipGroup *customGroup = [OOShipGroup cxx_groupWithName:std::string("custom") leader:custom];
	custom->_escortGroup = customGroup;
	custom->_group = [OOShipGroup cxx_groupWithName:std::string("elsewhere")];
	Define("customGroup", [customGroup oo_jsValueInContext:sContext]);
	custom->_acceptsEscorts = NO;
	OO_CHECK_EVAL("customGroup.addShip(escort)", "false");
	custom->_acceptsEscorts = YES;
	OO_CHECK_EVAL("customGroup.addShip(escort)", "true");
	OO_CHECK_EQ(custom->_accepted, 1);
}


OO_TEST(otherObjects)
{
	SetUpContext();
	NewShip("zeta");
	OO_CHECK_EVAL("ShipGroup.prototype.addShip.call(zeta, zeta)", "threw: Native method expected ShipGroup, got [object Ship].");
	OO_CHECK_EVAL("Object.getOwnPropertyDescriptor(ShipGroup.prototype, 'count').get.call({})", "threw: Native method expected ShipGroup, got [object Object].");
	OO_CHECK_EVAL("ShipGroup.prototype.count", "0");	// the prototype has no group: a message to nil
	OO_CHECK_EVAL("ShipGroup.prototype.ships.length", "0");
	OO_CHECK_EVAL("ShipGroup.prototype.name", "null");
}


OO_TEST(nativeExceptions)
{
	SetUpContext();
	ShipEntity *chief = NewShip("chief");
	NewShip("boom");
	OOShipGroup *group = [OOShipGroup cxx_groupWithName:std::string("ex") leader:chief];
	[group addShip:NewShip("wingman")];
	chief->_escortGroup = group;
	chief->_group = group;
	Define("exGroup", [group oo_jsValueInContext:sContext]);
	OO_CHECK_EVAL("exGroup.addShip(boom)", "threw: Native exception: escort boom");
	OO_CHECK_EVAL("exGroup.count", "2");
	OO_CHECK_EQ(sLimiterPauses, 0);
	OO_CHECK_EQ(sProfileDepth, 0);
	OO_CHECK(ooscript::isInRequest(sContext));
}


OO_TEST_MAIN()
