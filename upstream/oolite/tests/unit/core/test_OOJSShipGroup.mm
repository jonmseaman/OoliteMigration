/*	test_OOJSShipGroup.mm
	Unit tests for the ShipGroup JS binding (src/Core/Scripting/OOJSShipGroup.h/.mm) and the JS glue
	of OOShipGroup: bead oo-n64m, converted the way bead oo-ppc converted OOJSVector (proposed
	ADR-0056 amendments oo-ppc and oo-ykoy); the group's façade was deleted by bead oo-9ht.19, so a
	group reaches the engine as a PList Object node holding the C++ group, and the stand-in ship
	holds its groups as oo::Ref where it held the autoreleased façades.

	As test_OOJSWormhole.mm does (amendment oo-ykoy, item 4), it runs the JS class in a real
	context on the game's own façade backend (ooscript/JSEngine_quickjs.cpp), links the game's own
	objects for the binding, its bridge, the engine's exception translator
	(OOJSEngineNativeWrappers.mm) and OOShipGroup (a converted class, reached through its façade,
	as test_OOShipGroup.mm links it), and stands in for ShipEntity (a weakly referenced object
	answering only the selectors the binding and the group send, with a JS object of its own; a C++
	ship under a stand-in root object since bead oo-9ht.144),
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
	ship named "boom" raises from acceptAsEscort(), so the test sees what an exception under a
	native becomes. C++ since bead oo-9ht.144 deleted the Objective-C ship this stood in for: a
	ship's object is the root's (a weakly referenced object with a JS object of its own), which
	holds the C++ part (oo::ToCxx reads it) and which oo::ToObjC answers for it; declared as
	Entity.h and ShipEntity.h declare them (the test imports neither).
*/
@class Entity;

namespace cxx {
class Entity : public oo::RefCounted
{
public:
	virtual ~Entity();

	::Entity *_object = nil;	// its object (not retained)
};
}	// namespace cxx

class ShipEntity : public cxx::Entity
{
public:
	::OOShipGroup *group();
	void setGroup(::OOShipGroup *group);
	void setOwner(cxx::Entity *who_owns_entity);
	::OOShipGroup *escortGroup();
	bool acceptAsEscort(::ShipEntity *other_ship);

	std::string _name;
	oo::Ref<OOShipGroup> _group;
	oo::Ref<OOShipGroup> _escortGroup;
	BOOL _acceptsEscorts = NO;
	int _accepted = 0;
};

@interface Entity: OOWeakRefObject
{
@public
	oo::Ref<cxx::Entity> _cxxEntity;
	std::string _name;
	ooscript::Object _jsSelf;
}
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


cxx::Entity::~Entity() = default;
OOShipGroup *ShipEntity::group()  { return _group.get(); }
void ShipEntity::setGroup(OOShipGroup *group)  { _group = oo::Ref<OOShipGroup>(group); }
void ShipEntity::setOwner(cxx::Entity *who_owns_entity)  { (void)who_owns_entity; }
OOShipGroup *ShipEntity::escortGroup()  { return _escortGroup.get(); }

bool ShipEntity::acceptAsEscort(::ShipEntity *other_ship)
{
	if (other_ship->_name == "boom")  [OOException raise:OOInvalidArgumentException format:"escort %s", "boom"];
	if (!_acceptsEscorts)  return NO;
	_accepted++;
	return YES;
}

namespace oo { ::Entity *ToObjC(cxx::Entity *entity); }	// Entity+ObjCBridge.mm's, which the test does not link
::Entity *oo::ToObjC(cxx::Entity *entity)  { return entity != nullptr ? entity->_object : nil; }


@implementation Entity

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
	if (const oo::PList::Object *node = plist.getIf<oo::PList::Object>())	// a C++ object that is its own JS glue, as the engine asks it
	{
		if (OOJSPrivateObject *glue = dynamic_cast<OOJSPrivateObject *>(node->get()))  return OOJSValueFromCxxObject(context, glue);
	}
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


// The JS class check of the engine's C++ getter (OOJSPrivateObject.cpp, linked since bead
// oo-6symp.1, whose slot holds the C++ group): no subclass of ShipGroup is registered.
BOOL OOJSIsSubclass(ooscript::ClassDef *putativeSubclass, ooscript::ClassDef *superclass)
{
	return putativeSubclass == superclass;
}


// (No longer reached for a group, whose toString() is OOJSCxxObjectWrapperToString.)
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


// A ship and its object (kept for the life of the test), defined by name.
ShipEntity *NewShip(const char *name)
{
	::Entity *object = [[::Entity alloc] init];
	oo::Ref<ShipEntity> ship = oo::makeRef<ShipEntity>();
	ship->_object = object;
	ship->_name = name;
	object->_cxxEntity = ship;
	object->_name = name;
	Define(name, [object oo_jsValueInContext:sContext]);
	return ship.get();
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
	oo::Ref<OOShipGroup> group = OOShipGroup::groupWithName(std::string("cat"));
	ooscript::Value first = group->jsValueInContext(sContext);
	OO_CHECK(ooscript::isObject(first));
	OO_CHECK(ooscript::toObject(group->jsValueInContext(sContext)) == ooscript::toObject(first));
	OO_CHECK(static_cast<oo::RefCounted *>(ooscript::getPrivate(sContext, ooscript::toObject(first))) == static_cast<oo::RefCounted *>(group.get()));
	Define("catGroup", first);
	OO_CHECK_EVAL("catGroup.name", "cat");
	// Clearing with another object leaves it; clearing with its own makes the next one new.
	group->clearJSSelf(nullptr);
	OO_CHECK(ooscript::toObject(group->jsValueInContext(sContext)) == ooscript::toObject(first));
	group->clearJSSelf(ooscript::toObject(first));
	ooscript::Value second = group->jsValueInContext(sContext);
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
	OO_CHECK_EVAL("String(new ShipGroup('wing')).replace(/0x[0-9a-f]+/, 'ADDR')", "[OOShipGroup \"wing\", 0 ships]");
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
	oo::Ref<OOShipGroup> escorts = OOShipGroup::groupWithName(std::string("escorts"), leader);
	escorts->addShip(NewShip("first"));
	leader->_escortGroup = escorts;
	leader->_group = escorts;
	Define("escorts", escorts->jsValueInContext(sContext));
	leader->_acceptsEscorts = NO;
	OO_CHECK_EVAL("[escorts.addShip(escort), escorts.containsShip(escort)].join()", "false,false");
	leader->_acceptsEscorts = YES;
	OO_CHECK_EVAL("[escorts.addShip(escort), escorts.containsShip(escort)].join()", "true,true");
	OO_CHECK_EQ(leader->_accepted, 1);
	// A ship that already escorts someone else is refused, with a warning.
	oo::Ref<OOShipGroup> otherEscorts = OOShipGroup::groupWithName(std::string("other"), other);
	otherEscorts->addShip(taken);
	other->_escortGroup = otherEscorts;
	taken->_group = otherEscorts;
	sLastWarning.clear();
	OO_CHECK_EVAL("escorts.addShip(taken)", "false");
	OO_CHECK_EQ(sLastWarning, "ShipGroup.addShip: Ship " + oo::DescriptionOf(oo::ToObjC(taken)) + " cannot be assigned to two escort groups, ignoring.");
	OO_CHECK(oo::DescriptionOf(oo::ToObjC(taken)).find("{taken}") != std::string::npos);
	// A lone leader whose escort group is its own group gets a new group, and the ship joins that.
	ShipEntity *lone = NewShip("lone");
	oo::Ref<OOShipGroup> loneGroup = OOShipGroup::groupWithName(std::string("alone"), lone);
	lone->_escortGroup = loneGroup;
	lone->_group = loneGroup;
	Define("loneGroup", loneGroup->jsValueInContext(sContext));
	OO_CHECK_EVAL("[loneGroup.addShip(escort), loneGroup.containsShip(escort)].join()", "true,false");
	OO_CHECK(lone->_group != loneGroup && lone->_group->containsShip(escort));
	OO_CHECK(lone->_group->name() == std::optional<std::string>("ship group"));
	// A lone leader with a group of its own: it is asked to accept the escort.
	ShipEntity *custom = NewShip("custom");
	oo::Ref<OOShipGroup> customGroup = OOShipGroup::groupWithName(std::string("custom"), custom);
	custom->_escortGroup = customGroup;
	custom->_group = OOShipGroup::groupWithName(std::string("elsewhere"));
	Define("customGroup", customGroup->jsValueInContext(sContext));
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
	oo::Ref<OOShipGroup> group = OOShipGroup::groupWithName(std::string("ex"), chief);
	group->addShip(NewShip("wingman"));
	chief->_escortGroup = group;
	chief->_group = group;
	Define("exGroup", group->jsValueInContext(sContext));
	OO_CHECK_EVAL("exGroup.addShip(boom)", "threw: Native exception: escort boom");
	OO_CHECK_EVAL("exGroup.count", "2");
	OO_CHECK_EQ(sLimiterPauses, 0);
	OO_CHECK_EQ(sProfileDepth, 0);
	OO_CHECK(ooscript::isInRequest(sContext));
}


OO_TEST_MAIN()
