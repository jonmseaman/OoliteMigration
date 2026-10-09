/*	test_OOJSCall.mm
	Unit tests for OOJSCallObjCObjectMethod() (src/Core/Scripting/OOJSCall.h/.mm): bead oo-81hy,
	a Phase 3 scripting file (proposed ADR-0056 amendment oo-ppc).

	OOJSCallObjCObjectMethod() implements the debug-build callObjC(): it calls an Objective-C
	method by name on an object, choosing how by the method's signature, which it matches against
	the type encodings of a template class's methods. The test runs it in a real context on the
	game's own façade backend (ooscript/JSEngine_quickjs.cpp) and links the game's own objects for
	the file, the by-name dispatcher (OOCallByName.mm) and the signature reader
	(OOShaderUniformMethodType.mm). What the rest of the engine would provide is defined below as
	the smallest stand-in that does the same thing (amendment oo-ppc item 6): the error reporter,
	the string and property-list converters, Vector3D and Quaternion (plain arrays here), and the
	ship and player classes (the call makes a ship the player's script target). The game's
	headers for those are not imported, because the test defines those classes (amendment oo-z1s4
	item 4). The expectations were written against the Objective-C file and run on it first; they
	pin every signature it calls (void, string parameter, property-list result, integers, floats,
	vector, quaternion, object, "_bool" objects), the joined parameter string, and each error.
	Run: bash tools/check-core-tests.sh
*/

#import "OOJSCall.h"
#import "oofnd/objc/OOObject.h"
#import "OOMaths.h"
#include "ooscript/JSEngine.hpp"
#import "OOJSEngineNativeWrappers.h"
#include "oofnd/PList.hpp"
#include "oofnd/String.hpp"
#import "OOObjCPList.h"
#import "OODescription.h"
#include <cstring>

#include "oo_test.hpp"

#include <cstdarg>
#include <string>
#include <vector>


#ifndef NDEBUG

// MARK: What the rest of the engine provides ------------------------------------------------------

namespace {
ooscript::Context sContext = nullptr;
std::string sLastError;
} // namespace


void cxx_OOJSReportError(ooscript::Context context, const char *format, ...)
{
	(void)context;
	va_list args;
	va_start(args, format);
	sLastError = oo::str::vformat(format, args);
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


std::optional<std::string> cxx_OOStringFromJSValueEvenIfNull(ooscript::Context context, ooscript::Value value)
{
	if (ooscript::isNull(value))  return std::string("null");
	if (ooscript::isUndefined(value))  return std::string("undefined");
	return cxx_OOStringFromJSValue(context, value);
}


// A property list as JS: strings, numbers and booleans as themselves; an object node as the
// string "<object CLASS>", which is enough to see which object came back.
ooscript::Value OOJSValueFromPList(ooscript::Context context, const oo::PList &plist)
{
	std::string text;
	switch (plist.type())
	{
		case oo::PList::Type::Bool:  return ooscript::booleanValue(plist.boolValue());
		case oo::PList::Type::Integer:
		case oo::PList::Type::Real:  return ooscript::numberValue(plist.doubleValue());
		case oo::PList::Type::String:  text = *plist.getIf<std::string>();  break;
		case oo::PList::Type::Object:  text = "<object " + oo::DescriptionOf([oo::ObjectIn(plist) class]) + ">";  break;
		default:  return ooscript::nullValue();
	}
	return ooscript::stringValue(ooscript::newStringCopyN(context, text.data(), text.size()));
}


namespace {

ooscript::Object ArrayOf(ooscript::Context context, std::vector<double> numbers)
{
	std::vector<ooscript::Value> values;
	for (double n : numbers)  values.push_back(ooscript::numberValue(n));
	return ooscript::newArrayObject(context, static_cast<unsigned>(values.size()), values.data());
}

} // namespace

extern "C" ooscript::Object JSVectorWithVector(ooscript::Context context, Vector vector)
{
	return ArrayOf(context, { vector.x, vector.y, vector.z });
}


extern "C" ooscript::Object JSQuaternionWithQuaternion(ooscript::Context context, Quaternion quaternion)
{
	return ArrayOf(context, { quaternion.w, quaternion.x, quaternion.y, quaternion.z });
}


// Link stub (amendment oo-zffj item 2): OOShaderUniformMethodType.mm's matrix reader answers it for
// a nil object; the test calls no matrix method, and OOMatrix.mm would bring OpenGL.
extern "C" const OOMatrix kZeroMatrix = {};


#if OOJS_PROFILE
extern "C" void OOJSProfileEnter(OOJSProfileStackFrame *, const char *)  {}
extern "C" void OOJSProfileExit(OOJSProfileStackFrame *)  {}
#endif

extern "C" void OOJSUnreachable(const char *function, const char *, unsigned)
{
	std::printf("unreachable reached in %s\n", function);
	abort();
}


// The ship and player classes, as far as the call sees them: a ship becomes the player's script
// target.
@interface ShipEntity: OOObject
@end

@implementation ShipEntity
@end

@interface PlayerEntity: ShipEntity
{
@public
	id scriptTarget;
}
- (void) setScriptTarget:(id)target;
@end

@implementation PlayerEntity
- (void) setScriptTarget:(id)target  { scriptTarget = target; }
@end

PlayerEntity *gOOPlayer = nil;


#if OO_DEBUG
// The C++ player's statistics members, which callObjC's name table calls by name (bead oo-9ht.15),
// as far as the table sees them: each records its call and answers a marker.
namespace cxx {
class PlayerEntity
{
public:
	static oo::PList reportJSVectorStatistics();
	static void clearJSVectorStatistics();
	static oo::PList reportJSQuaternionStatistics();
	static void clearJSQuaternionStatistics();
};
}	// namespace cxx

namespace {
std::vector<std::string> sStatisticsCalls;
}	// namespace

oo::PList cxx::PlayerEntity::reportJSVectorStatistics()		{ sStatisticsCalls.push_back("reportJSVectorStatistics"); return oo::PList(std::string("vector statistics")); }
void cxx::PlayerEntity::clearJSVectorStatistics()			{ sStatisticsCalls.push_back("clearJSVectorStatistics"); }
oo::PList cxx::PlayerEntity::reportJSQuaternionStatistics()	{ sStatisticsCalls.push_back("reportJSQuaternionStatistics"); return oo::PList(std::string("quaternion statistics")); }
void cxx::PlayerEntity::clearJSQuaternionStatistics()		{ sStatisticsCalls.push_back("clearJSQuaternionStatistics"); }
#endif


// MARK: The object called -------------------------------------------------------------------------

@interface TestBoolean: OOObject
{
@public
	BOOL value;
}
- (BOOL) boolValue;
@end

@implementation TestBoolean
- (BOOL) boolValue  { return value; }
@end

@interface TestInteger: OOObject
{
@public
	int value;
}
- (int) intValue;
@end

@implementation TestInteger
- (int) intValue  { return value; }
@end


@interface TestTarget: OOObject
{
@public
	std::vector<std::string> calls;
}
@end

@implementation TestTarget

- (void) poke  { calls.push_back("poke"); }
- (void) say:(const std::string &)text  { calls.push_back("say:" + text); }
- (oo::PList) echo:(const std::string &)text  { return oo::PList("echo " + text); }
- (oo::PList) plist  { return oo::PList(12.5); }
- (oo::PList) plist_bool  { return oo::PList(std::string("yes")); }
- (oo::PList) nothing  { return oo::PList(); }
- (int) answer  { return 42; }
- (int) negative  { return -7; }
- (unsigned long) big  { return 4000000000UL; }
- (float) half  { return 0.5f; }
- (double) third  { return 1.0 / 4.0; }
- (Vector) vector  { return make_vector(1, 2, 3); }
- (Quaternion) quaternion  { return make_quaternion(1, 0, 0, 0); }
- (id) selfObject  { return self; }
- (id) nilObject  { return nil; }
- (id) true_bool  { TestBoolean *b = [[[TestBoolean alloc] init] autorelease]; b->value = YES; return b; }
- (id) false_bool  { TestBoolean *b = [[[TestBoolean alloc] init] autorelease]; b->value = NO; return b; }
- (id) seven_bool  { TestInteger *i = [[[TestInteger alloc] init] autorelease]; i->value = 7; return i; }
- (id) plain_bool  { return [[[OOObject alloc] init] autorelease]; }
- (NSPoint) point  { return NSMakePoint(1, 2); }
- (void) takesInt:(int)value  { calls.push_back(oo::str::format("int %d", value)); }

@end


@interface TestShip: ShipEntity
- (int) answer;
@end

@implementation TestShip
- (int) answer  { return 1; }
@end


// MARK: Calling -----------------------------------------------------------------------------------

namespace {

ooscript::Context Context()
{
	if (sContext == nullptr)
	{
		ooscript::Runtime runtime = ooscript::newRuntime(8u * 1024u * 1024u);
		sContext = ooscript::newContext(runtime, 8192);
		ooscript::beginRequest(sContext);
		ooscript::initStandardClasses(sContext, ooscript::getGlobalObject(sContext));
		gOOPlayer = [[PlayerEntity alloc] init];
	}
	return sContext;
}


ooscript::Value StringValue(const char *text)
{
	return ooscript::stringValue(ooscript::newStringCopyN(Context(), text, std::strlen(text)));
}


// Calls selector (and arguments) on object; gives the result as a string ("<unchanged>" when the
// call left it alone), or "error: <message>".
std::string Call(id object, std::vector<ooscript::Value> argv)
{
	sLastError.clear();
	ooscript::Value result = StringValue("<unchanged>");	// a marker no call writes
	bool OK = OOJSCallObjCObjectMethod(Context(), object, "Test", static_cast<unsigned>(argv.size()), argv.data(), &result);
	if (!OK)  return "error: " + sLastError;
	return cxx_OOStringFromJSValueEvenIfNull(Context(), result).value_or("<none>");
}


std::string Call(id object, const char *selector)
{
	return Call(object, std::vector<ooscript::Value>{ StringValue(selector) });
}

}	// namespace


// MARK: Tests -------------------------------------------------------------------------------------

OO_TEST(voidAndStringMethods)
{
	@autoreleasepool
	{
		TestTarget *target = [[[TestTarget alloc] init] autorelease];
		OO_CHECK_EQ(Call(target, "poke"), "<unchanged>");
		OO_CHECK_EQ(Call(target, { StringValue("say:"), StringValue("hello"), ooscript::int32Value(3), ooscript::nullValue() }), "<unchanged>");
		OO_CHECK_EQ(target->calls.size(), 2u);
		if (target->calls.size() == 2)
		{
			OO_CHECK_EQ(target->calls[0], "poke");
			OO_CHECK_EQ(target->calls[1], "say:hello 3 null");	// the parameters joined with spaces
		}
		OO_CHECK_EQ(Call(target, { StringValue("echo:"), StringValue("a"), StringValue("b") }), "echo a b");
		OO_CHECK_EQ(Call(target, "plist"), "12.5");
		OO_CHECK_EQ(Call(target, "plist_bool"), "true");	// a string read as a boolean
		OO_CHECK_EQ(Call(target, "nothing"), "<unchanged>");	// a null result leaves it
	}
}


OO_TEST(scalarMethods)
{
	@autoreleasepool
	{
		TestTarget *target = [[[TestTarget alloc] init] autorelease];
		OO_CHECK_EQ(Call(target, "answer"), "42");
		OO_CHECK_EQ(Call(target, "negative"), "-7");
		OO_CHECK_EQ(Call(target, "big"), "4000000000");
		OO_CHECK_EQ(Call(target, "half"), "0.5");
		OO_CHECK_EQ(Call(target, "third"), "0.25");
		OO_CHECK_EQ(Call(target, "vector"), "1,2,3");
		OO_CHECK_EQ(Call(target, "quaternion"), "1,0,0,0");
	}
}


OO_TEST(objectMethods)
{
	@autoreleasepool
	{
		TestTarget *target = [[[TestTarget alloc] init] autorelease];
		OO_CHECK_EQ(Call(target, "selfObject"), "<object TestTarget>");
		OO_CHECK_EQ(Call(target, "nilObject"), "<unchanged>");
		OO_CHECK_EQ(Call(target, "true_bool"), "true");
		OO_CHECK_EQ(Call(target, "false_bool"), "false");
		OO_CHECK_EQ(Call(target, "seven_bool"), "true");
		OO_CHECK_EQ(Call(target, "plain_bool"), "false");
	}
}


OO_TEST(errors)
{
	@autoreleasepool
	{
		TestTarget *target = [[[TestTarget alloc] init] autorelease];
		OO_CHECK_EQ(Call(target, std::vector<ooscript::Value>{}), "error: Test.callObjC(): no selector specified.");
		OO_CHECK_EQ(Call(target, "say:"), "error: Test.callObjC(): method say: requires a parameter.");
		OO_CHECK_EQ(Call(target, "point"), "error: Test.callObjC(): method point cannot be called from JavaScript.");
		OO_CHECK_EQ(Call(target, { StringValue("takesInt:"), ooscript::int32Value(1) }), "error: Test.callObjC(): method takesInt: cannot be called from JavaScript.");
		OO_CHECK(Call(target, "noSuchMethod").rfind("error: Test.callObjC(): <TestTarget ", 0) == 0);
		OO_CHECK(Call(target, "noSuchMethod").find("> does not respond to method noSuchMethod.") != std::string::npos);
		// Parameters after a selector with no colon are ignored.
		OO_CHECK_EQ(Call(target, { StringValue("answer"), StringValue("x") }), "42");
		OO_CHECK(target->calls.empty());
	}
}


OO_TEST(shipBecomesScriptTarget)
{
	@autoreleasepool
	{
		Context();
		TestShip *ship = [[[TestShip alloc] init] autorelease];
		gOOPlayer->scriptTarget = nil;
		OO_CHECK_EQ(Call(ship, "answer"), "1");
		OO_CHECK(gOOPlayer->scriptTarget == ship);
		TestTarget *target = [[[TestTarget alloc] init] autorelease];
		OO_CHECK_EQ(Call(target, "answer"), "42");
		OO_CHECK(gOOPlayer->scriptTarget == ship);	// not a ship: unchanged
	}
}


#if OO_DEBUG
// The player's conversion statistics by name (PS.callObjC("reportJSVectorStatistics")): the
// categories' selectors, now C++ members reached through callObjC's name table (bead oo-9ht.15),
// with the categories' signatures; only the player answers them.
OO_TEST(playerStatisticsByName)
{
	@autoreleasepool
	{
		Context();
		sStatisticsCalls.clear();
		OO_CHECK_EQ(Call(gOOPlayer, "reportJSVectorStatistics"), "vector statistics");
		OO_CHECK_EQ(Call(gOOPlayer, "clearJSVectorStatistics"), "<unchanged>");	// void
		OO_CHECK_EQ(Call(gOOPlayer, "reportJSQuaternionStatistics"), "quaternion statistics");
		OO_CHECK_EQ(Call(gOOPlayer, { StringValue("clearJSQuaternionStatistics"), StringValue("x") }), "<unchanged>");	// parameters ignored
		OO_CHECK_EQ(sStatisticsCalls.size(), 4u);
		if (sStatisticsCalls.size() == 4)
		{
			OO_CHECK_EQ(sStatisticsCalls[0], "reportJSVectorStatistics");
			OO_CHECK_EQ(sStatisticsCalls[1], "clearJSVectorStatistics");
			OO_CHECK_EQ(sStatisticsCalls[2], "reportJSQuaternionStatistics");
			OO_CHECK_EQ(sStatisticsCalls[3], "clearJSQuaternionStatistics");
		}
		OO_CHECK(gOOPlayer->scriptTarget == gOOPlayer);	// the player is a ship: its own script target

		TestShip *ship = [[[TestShip alloc] init] autorelease];
		OO_CHECK(Call(ship, "reportJSVectorStatistics").find("> does not respond to method reportJSVectorStatistics.") != std::string::npos);
		TestTarget *target = [[[TestTarget alloc] init] autorelease];
		OO_CHECK(Call(target, "clearJSQuaternionStatistics").find("> does not respond to method clearJSQuaternionStatistics.") != std::string::npos);
		OO_CHECK_EQ(sStatisticsCalls.size(), 4u);
	}
}
#endif

#else

OO_TEST(releaseBuild)
{
	OO_CHECK(true);	// callObjC() is debug-only
}

#endif


OO_TEST_MAIN()
