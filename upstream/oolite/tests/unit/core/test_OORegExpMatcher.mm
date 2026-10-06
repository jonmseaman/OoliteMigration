/*	test_OORegExpMatcher.mm
	Unit tests for OORegExpMatcher (src/Core/OORegExpMatcher.h): bead oo-ct7c, converted in the
	Phase 3 house style (proposed ADR-0056).

	The matcher compiles a JavaScript function, "return regexp.test(string);", and runs it on a
	RegExp object it caches by pattern and flags. The test links the game's own OORegExpMatcher
	and the ooscript engine (QuickJS), so every match below is the real engine's answer. The
	Objective-C glue the matcher uses but whose files reach the whole game (the engine singleton,
	OOJSFunction, OOJSValue and the two value converters; OOJavaScriptEngine.mm links everything)
	is replaced by the minimal definitions below, which count what the matcher asks of them
	(ADR-0056 amendment 1 item 8, amendment oo-z1s4 item 4). The expectations were written against the Objective-C API and
	run on the unconverted class first: what matches, the flags, the empty pattern, the cache
	(one compiled RegExp per pattern and flags), and the pseudo-singleton (one matcher per
	autorelease pool, a new one after the pool drains; nil, and asked again, when the tester does
	not compile). The C++ tests then pinned the same answers through the C++ matcher, and the
	last test the facade's contract (one facade per matcher, nil stays nil). Bead oo-9ht.12 deleted
	the facade: see the note above the tests.
	Run: bash tools/check-core-tests.sh
*/

#import "OORegExpMatcher.h"
#import "oofnd/objc/OOObject.h"

#include "oo_test.hpp"
#include "oofnd/PList.hpp"
#include "oofnd/Encoding.hpp"

#include <string>


// --- Stand-ins for the engine glue (see the banner) ---------------------------------------------

ooscript::Context gOOJSMainThreadContext = nullptr;

namespace {

ooscript::Object sGlobal = nullptr;
unsigned sEngineCalls = 0;		// +[OOJavaScriptEngine sharedEngine]
unsigned sFunctionsMade = 0;	// OOJSFunction inits: one per matcher
unsigned sRegExpsMade = 0;		// OOJSValue inits: one per RegExp the matcher compiled
unsigned sEvaluations = 0;		// OOJSFunction evaluations: one per match
bool sFailCompile = false;		// make the next OOJSFunction init fail, as a compile error does

ooscript::ClassDef sGlobalClass = { "Global", ooscript::ClassFlag::Global, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr };

}	// namespace


@interface OOJavaScriptEngine: OOObject
+ (id) sharedEngine;
@end

@implementation OOJavaScriptEngine

+ (id) sharedEngine
{
	sEngineCalls++;
	if (gOOJSMainThreadContext == nullptr)
	{
		ooscript::Runtime runtime = ooscript::newRuntime(64L * 1024L * 1024L);
		gOOJSMainThreadContext = ooscript::newContext(runtime, 8192);
		ooscript::beginRequest(gOOJSMainThreadContext);
		sGlobal = ooscript::newGlobalObject(gOOJSMainThreadContext, &sGlobalClass);
		ooscript::setGlobalObject(gOOJSMainThreadContext, sGlobal);
		ooscript::initStandardClasses(gOOJSMainThreadContext, sGlobal);
		ooscript::endRequest(gOOJSMainThreadContext);
	}
	return nil;
}

@end


@interface OOJSFunction: OOObject
{
@private
	ooscript::Object _functionObject;
	ooscript::Function _function;
}
- (id) initWithName:(const std::optional<std::string> &)name scope:(ooscript::Object)scope code:(const std::optional<std::string> &)code argumentCount:(NSUInteger)argCount argumentNames:(const char **)argNames fileName:(const std::optional<std::string> &)fileName lineNumber:(NSUInteger)lineNumber context:(ooscript::Context)context;
- (BOOL) evaluateWithContext:(ooscript::Context)context scope:(ooscript::Object)jsThis argc:(unsigned)argc argv:(ooscript::Value *)argv result:(ooscript::Value *)result;
@end

@implementation OOJSFunction

- (id) initWithName:(const std::optional<std::string> &)name scope:(ooscript::Object)scope code:(const std::optional<std::string> &)code argumentCount:(NSUInteger)argCount argumentNames:(const char **)argNames fileName:(const std::optional<std::string> &)fileName lineNumber:(NSUInteger)lineNumber context:(ooscript::Context)context
{
	self = [super init];
	if (self == nil)  return nil;
	sFunctionsMade++;
	if (sFailCompile)
	{
		[self release];
		return nil;
	}
	const std::u16string units = oo::utf8ToUtf16(code.value_or(std::string()));
	_function = ooscript::compileUCFunction(context, (scope != nullptr) ? scope : sGlobal, name ? name->c_str() : nullptr, static_cast<unsigned>(argCount), argNames, units.data(), units.size(), fileName ? fileName->c_str() : nullptr, static_cast<unsigned>(lineNumber));
	if (_function == nullptr)
	{
		[self release];
		return nil;
	}
	_functionObject = ooscript::getFunctionObject(_function);
	ooscript::addNamedObjectRoot(context, &_functionObject, "test OOJSFunction");
	return self;
}


- (void) dealloc
{
	if (_functionObject != nullptr)  ooscript::removeObjectRoot(gOOJSMainThreadContext, &_functionObject);
	[super dealloc];
}


- (BOOL) evaluateWithContext:(ooscript::Context)context scope:(ooscript::Object)jsThis argc:(unsigned)argc argv:(ooscript::Value *)argv result:(ooscript::Value *)result
{
	sEvaluations++;
	return ooscript::callFunction(context, (jsThis != nullptr) ? jsThis : sGlobal, _function, argc, argv, result);
}

@end


@interface OOJSValue: OOObject
{
@public
	ooscript::Value _val;
}
- (id) initWithJSObject:(ooscript::Object)object inContext:(ooscript::Context)context;
@end

@implementation OOJSValue

- (id) initWithJSObject:(ooscript::Object)object inContext:(ooscript::Context)context
{
	self = [super init];
	if (self == nil)  return nil;
	sRegExpsMade++;
	_val = ooscript::objectValue(object);
	ooscript::addNamedValueRoot(context, &_val, "test OOJSValue");
	return self;
}


- (void) dealloc
{
	ooscript::removeValueRoot(gOOJSMainThreadContext, &_val);
	[super dealloc];
}

@end


extern "C" ooscript::Value OOJSValueFromNativeObject(ooscript::Context, id object)
{
	return (object != nil) ? ((OOJSValue *)object)->_val : ooscript::nullValue();
}


ooscript::Value OOJSValueFromPList(ooscript::Context context, const oo::PList &plist)
{
	const std::string *string = plist.getIf<std::string>();
	if (string == nullptr)  return ooscript::nullValue();
	const std::u16string units = oo::utf8ToUtf16(*string);
	return ooscript::stringValue(ooscript::newUCStringCopyN(context, units.data(), units.size()));
}


// --- The tests ------------------------------------------------------------------------------------
// Bead oo-9ht.12 deleted the facade. The cases that asked through its selectors ask the C++ matcher
// with the same expectations; the facade's own contract (facadeContract) and its autorelease-pool
// lifetime (oneMatcherPerAutoreleasePool) were retired with it (ADR-0049, standing approval
// oo-9n5p9). The C++ lifetime is cxxOneMatcherWhileHeld's; matchersHeldAcrossMatches pins what the
// pool gave a caller that holds its matcher.

namespace {

bool Matches(const std::string &string, const std::string &regExp, NSUInteger flags = 0)
{
	oo::Ref<OORegExpMatcher> matcher = OORegExpMatcher::regExpMatcher();
	return matcher != nullptr && matcher->string(string, regExp, flags);
}

}	// namespace


OO_TEST(matches)
{
	OO_CHECK(Matches("GeForce GTX 1080", "GeForce"));
	OO_CHECK(Matches("GeForce GTX 1080", "^GeForce GTX [0-9]+$"));
	OO_CHECK(!Matches("GeForce GTX 1080", "^GTX"));
	OO_CHECK(!Matches("geforce", "GeForce"));
	OO_CHECK(Matches("geforce", "GeForce", kOORegExpCaseInsensitive));
	OO_CHECK(!Matches("one\ntwo", "^two"));
	OO_CHECK(Matches("one\ntwo", "^two", kOORegExpMultiLine));
	OO_CHECK(Matches("", "^$"));
	OO_CHECK(Matches("caf\xC3\xA9", "\xC3\xA9$"));	// UTF-8 in, UTF-16 units to the engine
	OO_CHECK(OORegExpMatcher::regExpMatcher()->string("abc", "b"));	// flags 0
}


OO_TEST(emptyPatternMatchesNothing)
{
	unsigned evaluations = sEvaluations;
	OO_CHECK(!Matches("abc", ""));
	OO_CHECK(!Matches("", ""));
	OO_CHECK(sEvaluations == evaluations);	// returned before running anything
}


OO_TEST(regExpIsCachedByPatternAndFlags)
{
	oo::Ref<OORegExpMatcher> matcher = OORegExpMatcher::regExpMatcher();
	unsigned made = sRegExpsMade;
	OO_CHECK(matcher->string("abc", "c$", 0));
	OO_CHECK(sRegExpsMade == made + 1);
	OO_CHECK(!matcher->string("abd", "c$", 0));
	OO_CHECK(sRegExpsMade == made + 1);		// same pattern and flags: cached
	OO_CHECK(matcher->string("ABC", "c$", kOORegExpCaseInsensitive));
	OO_CHECK(sRegExpsMade == made + 2);		// new flags
	OO_CHECK(matcher->string("ABD", "d$", kOORegExpCaseInsensitive));
	OO_CHECK(sRegExpsMade == made + 3);		// new pattern
	OO_CHECK(matcher->string("abd", "d$", 0));
	OO_CHECK(sRegExpsMade == made + 4);
}


OO_TEST(matchersHeldAcrossMatches)
{
	unsigned made = sFunctionsMade;
	unsigned engineCalls = sEngineCalls;
	{
		oo::Ref<OORegExpMatcher> first = OORegExpMatcher::regExpMatcher();
		OO_CHECK(first != nullptr);
		OO_CHECK(OORegExpMatcher::regExpMatcher() == first);
		OO_CHECK(Matches("x", "x"));
		OO_CHECK(sFunctionsMade == made + 1);	// one tester compiled for the held matcher
		OO_CHECK(sEngineCalls == engineCalls + 1);	// the engine summoned once, by init()
	}
	{
		OO_CHECK(OORegExpMatcher::regExpMatcher() != nullptr);
		OO_CHECK(sFunctionsMade == made + 2);	// the first matcher went with its last Ref
	}
}


OO_TEST(failedInitGivesNilAndRetries)
{
	sFailCompile = true;
	OO_CHECK(OORegExpMatcher::regExpMatcher() == nullptr);
	sFailCompile = false;
	OO_CHECK(OORegExpMatcher::regExpMatcher() != nullptr);	// nothing was kept: asked again
	OO_CHECK(Matches("abc", "b"));
}


OO_TEST(cxxMatches)
{
	oo::Ref<OORegExpMatcher> matcher = OORegExpMatcher::regExpMatcher();
	OO_CHECK(matcher != nullptr);
	OO_CHECK(matcher->string("GeForce GTX 1080", "^GeForce GTX [0-9]+$"));
	OO_CHECK(!matcher->string("geforce", "GeForce"));
	OO_CHECK(matcher->string("geforce", "GeForce", kOORegExpCaseInsensitive));
	OO_CHECK(matcher->string("one\ntwo", "^two", kOORegExpMultiLine));
	OO_CHECK(!matcher->string("abc", ""));
}


OO_TEST(cxxOneMatcherWhileHeld)
{
	unsigned made = sFunctionsMade;
	{
		oo::Ref<OORegExpMatcher> first = OORegExpMatcher::regExpMatcher();
		OO_CHECK(OORegExpMatcher::regExpMatcher() == first);
		OO_CHECK(sFunctionsMade == made + 1);
	}
	OO_CHECK(OORegExpMatcher::regExpMatcher() != nullptr);	// the first was freed with its last Ref
	OO_CHECK(sFunctionsMade == made + 2);

	sFailCompile = true;
	OO_CHECK(OORegExpMatcher::regExpMatcher() == nullptr);
	sFailCompile = false;
}


OO_TEST_MAIN()
