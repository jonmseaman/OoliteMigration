/*	test_OOJSInterfaceDefinition.mm
	Unit tests for OOJSInterfaceDefinition (src/Core/Scripting/OOJSInterfaceDefinition.h/.mm):
	bead oo-8fpc, a Phase 3 conversion in the house style of the OOColor exemplar (proposed
	ADR-0056; amendment oo-o89, as its superclass OOWeakRefObject is still Objective-C).

	An interface definition is a station's F4 interface entry made by a script: a title, category
	and summary, and a JS callback and its `this` that it keeps alive (GC roots) and runs with the
	entry's key, pushing the script that made it. The test runs it in a real context on the game's
	own façade backend (ooscript/JSEngine_quickjs.cpp) and links the game's own objects for the
	class and its superclass (OOWeakReference.mm and its bridge). What the rest of the engine would
	provide is defined below as the smallest stand-in that does the same thing: the engine object
	(which calls the function), the script stack (OOJSScript) and the property-list converter. The
	engine's and OOJSScript's headers are not imported, because the test defines those classes
	(amendment oo-z1s4 item 4); the class's header names OOJSScript with @class for that (amendment
	oo-fg7i item 5). The expectations were written against the Objective-C class and run on it
	first (they now run through the facade, its forwarding test; the facade's own contract is
	checked last); they pin the initial state and the text properties, the callback and its `this` (kept
	alive across a garbage collection), the run, the sort order (-interfaceCompare:, with its nil
	cases), an engine reset, and the weak reference to a definition.
	Run: bash tools/check-core-tests.sh
*/

#import "OOJSInterfaceDefinition.h"
#import "OOWeakReference.h"
#import "OODescription.h"
#include "ooscript/JSEngine.hpp"
#include "oofnd/Notification.hpp"
#include "oofnd/String.hpp"

#include "oo_test.hpp"

#include <cstring>
#include <string>
#include <vector>


// MARK: What the rest of the engine provides ------------------------------------------------------

namespace {
ooscript::Object sGlobal;
std::vector<id> sPushed;
int sScriptDepth = 0;
int sCalls = 0;
} // namespace

ooscript::Context gOOJSMainThreadContext = nullptr;
extern const char * const kOOJavaScriptEngineWillResetNotificationName;
const char * const kOOJavaScriptEngineWillResetNotificationName = "org.aegidian.oolite OOJavaScriptEngine will reset";


// A property list as JS, as far as the definition hands one over: a string.
ooscript::Value OOJSValueFromPList(ooscript::Context context, const oo::PList &plist)
{
	const std::string *string = plist.getIf<std::string>();
	if (string == nullptr)  return ooscript::nullValue();
	return ooscript::stringValue(ooscript::newStringCopyN(context, string->data(), string->size()));
}


@interface OOJavaScriptEngine: OOObject
+ (OOJavaScriptEngine *) sharedEngine;
- (BOOL) callJSFunction:(ooscript::Value)function forObject:(ooscript::Object)jsThis argc:(unsigned)argc argv:(ooscript::Value *)argv result:(ooscript::Value *)outResult;
@end

@implementation OOJavaScriptEngine

+ (OOJavaScriptEngine *) sharedEngine
{
	static OOJavaScriptEngine *engine = nil;
	if (engine == nil)  engine = [[OOJavaScriptEngine alloc] init];
	return engine;
}


- (BOOL) callJSFunction:(ooscript::Value)function forObject:(ooscript::Object)jsThis argc:(unsigned)argc argv:(ooscript::Value *)argv result:(ooscript::Value *)outResult
{
	sCalls++;
	bool OK = ooscript::callFunctionValue(gOOJSMainThreadContext, jsThis, function, argc, argv, outResult);
	if (!OK)  ooscript::clearPendingException(gOOJSMainThreadContext);
	return OK;
}

@end


// The script stack: the running script (set by the test) and what was pushed.
@interface OOJSScript: OOWeakRefObject
+ (OOJSScript *) currentlyRunningScript;
+ (void) pushScript:(OOJSScript *)script;
+ (void) popScript:(OOJSScript *)script;
@end

namespace {
OOJSScript *sRunningScript = nil;
} // namespace

@implementation OOJSScript
+ (OOJSScript *) currentlyRunningScript  { return sRunningScript; }
+ (void) pushScript:(OOJSScript *)script  { sPushed.push_back([script weakRefUnderlyingObject]); sScriptDepth++; }
+ (void) popScript:(OOJSScript *)script  { (void)script; sScriptDepth--; }
@end


// MARK: The context -------------------------------------------------------------------------------

namespace {

ooscript::Context Context()
{
	if (gOOJSMainThreadContext == nullptr)
	{
		ooscript::Runtime runtime = ooscript::newRuntime(8u * 1024u * 1024u);
		gOOJSMainThreadContext = ooscript::newContext(runtime, 8192);
		ooscript::beginRequest(gOOJSMainThreadContext);
		sGlobal = ooscript::getGlobalObject(gOOJSMainThreadContext);
		ooscript::initStandardClasses(gOOJSMainThreadContext, sGlobal);
	}
	return gOOJSMainThreadContext;
}


ooscript::Value Evaluate(const char *src)
{
	ooscript::Value result = ooscript::undefinedValue();
	if (!ooscript::evaluateScript(Context(), sGlobal, src, static_cast<unsigned>(std::strlen(src)), "test.js", 1, &result))  ooscript::clearPendingException(Context());
	return result;
}


std::string String(ooscript::Value value)
{
	if (ooscript::isNullOrUndefined(value))  return ooscript::isNull(value) ? "null" : "undefined";
	ooscript::String str = ooscript::valueToString(Context(), value);
	std::size_t length = 0;
	const ooscript::Char16 *chars = ooscript::getStringCharsAndLength(Context(), str, &length);
	std::string result;
	for (std::size_t i = 0; i < length; i++)  result += static_cast<char>(chars[i]);
	return result;
}

}	// namespace


// MARK: Tests -------------------------------------------------------------------------------------

OO_TEST(initialState)
{
	@autoreleasepool
	{
		Context();
		OOJSInterfaceDefinition *definition = [[[OOJSInterfaceDefinition alloc] init] autorelease];
		OO_CHECK(definition != nil);
		OO_CHECK(ooscript::isUndefined([definition callback]));
		OO_CHECK([definition callbackThis] == NULL);
		OO_CHECK([definition isKindOfClass:[OOWeakRefObject class]]);
		OO_CHECK(oo::DescriptionOf(definition).find("OOJSInterfaceDefinition") != std::string::npos);
		OO_CHECK(![definition cxx_title].has_value());
		OO_CHECK(![definition category].has_value());
		OO_CHECK(![definition summary].has_value());
		[definition cxx_setTitle:std::string("Title")];
		[definition setCategory:"Cat"];
		[definition setSummary:"Sum"];
		OO_CHECK_EQ([definition cxx_title].value_or("<none>"), "Title");
		OO_CHECK_EQ([definition category].value_or("<none>"), "Cat");
		OO_CHECK_EQ([definition summary].value_or("<none>"), "Sum");
		[definition cxx_setTitle:std::nullopt];
		OO_CHECK(![definition cxx_title].has_value());
	}
}


OO_TEST(runCallback)
{
	@autoreleasepool
	{
		OOJSScript *owner = [[[OOJSScript alloc] init] autorelease];
		sRunningScript = owner;
		OOJSInterfaceDefinition *definition = [[[OOJSInterfaceDefinition alloc] init] autorelease];
		sRunningScript = nil;

		// Neither the function nor `this` has another reference: the definition keeps them alive.
		[definition setCallback:Evaluate("(function (key) { globalThis.ran = this.tag + ':' + key + ':' + arguments.length; })")];
		[definition setCallbackThis:ooscript::toObject(Evaluate("({ tag: 'me' })"))];
		OO_CHECK(ooscript::isObject([definition callback]));
		OO_CHECK([definition callbackThis] != NULL);
		ooscript::gc(Context());

		sPushed.clear();
		sCalls = 0;
		[definition runCallback:"dock"];
		OO_CHECK_EQ(String(Evaluate("globalThis.ran")), "me:dock:1");
		OO_CHECK_EQ(sCalls, 1);
		OO_CHECK_EQ(sScriptDepth, 0);
		OO_CHECK(sPushed.size() == 1 && sPushed[0] == owner);	// the script that made it

		// Replacing the callback and `this`: the new ones run.
		[definition setCallback:Evaluate("(function (key) { globalThis.ran = 'second ' + key + ' ' + (this === globalThis); })")];
		[definition setCallbackThis:NULL];
		[definition runCallback:"k"];
		OO_CHECK_EQ(String(Evaluate("globalThis.ran")), "second k true");
	}
}


namespace {
OOJSInterfaceDefinition *Interface(std::optional<std::string> category, std::optional<std::string> title)
{
	OOJSInterfaceDefinition *definition = [[[OOJSInterfaceDefinition alloc] init] autorelease];
	if (category.has_value())  [definition setCategory:*category];
	[definition cxx_setTitle:title];
	return definition;
}
} // namespace


OO_TEST(interfaceCompare)
{
	@autoreleasepool
	{
		// By category, then by title, ignoring case.
		OO_CHECK_EQ([Interface("alpha", "z") interfaceCompare:Interface("Beta", "a")], OOOrderedAscending);
		OO_CHECK_EQ([Interface("beta", "a") interfaceCompare:Interface("ALPHA", "z")], OOOrderedDescending);
		OO_CHECK_EQ([Interface("same", "apple") interfaceCompare:Interface("SAME", "Banana")], OOOrderedAscending);
		OO_CHECK_EQ([Interface("same", "Banana") interfaceCompare:Interface("same", "apple")], OOOrderedDescending);
		OO_CHECK_EQ([Interface("same", "x") interfaceCompare:Interface("same", "X")], OOOrderedSame);
		// No category of its own: the same category as anything (a message to nil); then the titles.
		OO_CHECK_EQ([Interface(std::nullopt, "b") interfaceCompare:Interface("cat", "a")], OOOrderedDescending);
		// The other's missing category or title is the empty string.
		OO_CHECK_EQ([Interface("cat", "a") interfaceCompare:Interface(std::nullopt, "a")], OOOrderedDescending);
		OO_CHECK_EQ([Interface("", "a") interfaceCompare:Interface(std::nullopt, std::nullopt)], OOOrderedDescending);
		OO_CHECK_EQ([Interface("", std::nullopt) interfaceCompare:Interface(std::nullopt, "a")], OOOrderedSame);
		// nil: its category and title are missing.
		OO_CHECK_EQ([Interface("cat", "a") interfaceCompare:nil], OOOrderedDescending);
	}
}


OO_TEST(engineReset)
{
	@autoreleasepool
	{
		OOJSInterfaceDefinition *definition = [[[OOJSInterfaceDefinition alloc] init] autorelease];
		[definition setCallback:Evaluate("(function () {})")];
		[definition setCallbackThis:ooscript::toObject(Evaluate("({})"))];
		oo::NotificationCenter::defaultCenter().post(kOOJavaScriptEngineWillResetNotificationName, [OOJavaScriptEngine sharedEngine]);
		OO_CHECK(ooscript::isUndefined([definition callback]));
		OO_CHECK([definition callbackThis] == NULL);
	}
	// A definition that is gone no longer observes: another reset is harmless.
	oo::NotificationCenter::defaultCenter().post(kOOJavaScriptEngineWillResetNotificationName, [OOJavaScriptEngine sharedEngine]);
	OO_CHECK(true);
}


OO_TEST(weakReference)
{
	id reference = nil;
	@autoreleasepool
	{
		OOJSInterfaceDefinition *definition = [[OOJSInterfaceDefinition alloc] init];
		reference = [definition weakRetain];
		OO_CHECK([reference weakRefUnderlyingObject] == definition);
		[definition release];
	}
	OO_CHECK([reference weakRefUnderlyingObject] == nil);
	[reference release];
}


OO_TEST(facade)
{
	@autoreleasepool
	{
		OOJSInterfaceDefinition *facade = Interface("cat", "title");
		cxx::OOJSInterfaceDefinition *definition = oo::ToCxx(facade);
		OO_CHECK(definition != nullptr);
		OO_CHECK(oo::ToObjC(definition) == facade);
		OO_CHECK(oo::ToCxx(static_cast<OOJSInterfaceDefinition *>(nil)) == nullptr);

		// The facade forwards: what the C++ object holds is what the facade answers.
		OO_CHECK_EQ(definition->category().value_or("<none>"), "cat");
		definition->setSummary("summary");
		OO_CHECK_EQ([facade summary].value_or("<none>"), "summary");
		OO_CHECK_EQ(definition->interfaceCompare(oo::ToCxx(Interface("cat", "Title"))), OOOrderedSame);
		OO_CHECK_EQ(definition->interfaceCompare(nullptr), OOOrderedDescending);

		// ToObjC never makes a facade: a C++ definition with none answers nil.
		const oo::Ref<cxx::OOJSInterfaceDefinition> bare = oo::makeRef<cxx::OOJSInterfaceDefinition>();
		OO_CHECK(oo::ToObjC(bare.get()) == nil);
		OO_CHECK(!bare->title().has_value());
	}
}


OO_TEST_MAIN()
