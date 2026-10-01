/*	test_OOJSTimer.mm
	Unit tests for the Timer JS binding (src/Core/Scripting/OOJSTimer.h/.mm): bead oo-kdyh, which
	converts OOScriptTimer and its one subclass OOJSTimer (proposed ADR-0056, amendment oo-ppc for
	the binding).

	The binding's test runs its JS class in a real context on the game's own façade backend
	(ooscript/JSEngine_quickjs.cpp), and links the game's own objects for the binding, its base
	class OOScriptTimer, the priority queue that schedules it and the engine's exception
	translator (OOJSEngineNativeWrappers.mm). What the rest of the engine would provide is defined
	below as the smallest stand-in that does the same thing (amendment oo-ppc item 6): the error
	and warning reporters, the object getter and converters, the JS glue that OOObject gets from
	OOJavaScriptEngine.mm, the engine object (which calls the timer's function), the script stack
	and the universe's clock. The engine's and OOJSScript's headers are not imported, because the
	test defines those classes (amendment oo-z1s4 item 4). The expectations were written against
	the Objective-C files and run on them first; they pin the JS-visible behaviour: the
	constructor and its errors, the three properties, start() and stop(), toString(), firing with
	the right `this`, a timer whose `this` is null, and what an engine reset does. A timer that is
	garbage-collected while running (unrootedRunningTimerGC, bead oo-r1ci7) must not call back into
	the engine from its finalizer: describing it for the warning did, and on QuickJS that corrupted
	the heap (the test crashed at exit about one run in six with a single collection).
	Run: bash tools/check-core-tests.sh
*/

#import "OOScriptTimer.h"
#import "oofnd/objc/OOObject.h"
#import "OODescription.h"
#include "ooscript/JSEngine.hpp"
#import "OOJSEngineNativeWrappers.h"
#include "oofnd/Notification.hpp"
#include "oofnd/PList.hpp"
#include "oofnd/String.hpp"

#include "oo_test.hpp"

#include <cstdarg>
#include <string>
#include <vector>


extern "C" void InitOOJSTimer(ooscript::Context context, ooscript::Object global);


// MARK: What the rest of the engine provides ------------------------------------------------------

namespace {
std::vector<std::string> sWarnings;
int sScriptDepth = 0;
int sScriptPushes = 0;
int sCalls = 0;
bool sConverterRegistered = false;
} // namespace

ooscript::Context gOOJSMainThreadContext = nullptr;
extern const char * const kOOJavaScriptEngineWillResetNotificationName;
const char * const kOOJavaScriptEngineWillResetNotificationName = "org.aegidian.oolite OOJavaScriptEngine will reset";


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


void cxx_OOJSReportWarning(ooscript::Context context, const char *format, ...)
{
	(void)context;
	va_list args;
	va_start(args, format);
	sWarnings.push_back(oo::str::vformat(format, args));
	va_end(args);
}


void cxx_OOJSReportBadArguments(ooscript::Context context, const std::optional<std::string> &scriptClass, const std::optional<std::string> &function, unsigned argc, ooscript::Value *, const std::optional<std::string> &message, const std::optional<std::string> &expectedArgsDescription)
{
	cxx_OOJSReportError(context, "bad arguments: %s.%s (%u): %s; expected %s", scriptClass.value_or("").c_str(), function.value_or("").c_str(), argc, message.value_or("").c_str(), expectedArgsDescription.value_or("").c_str());
}


extern "C" void OOJSReportBadPropertySelector(ooscript::Context context, ooscript::Object, ooscript::PropertyId, ooscript::PropertySpec *)
{
	cxx_OOJSReportError(context, "bad property selector");
}


extern "C" void OOJSReportBadPropertyValue(ooscript::Context context, ooscript::Object, ooscript::PropertyId, ooscript::PropertySpec *, ooscript::Value)
{
	cxx_OOJSReportError(context, "bad property value");
}


std::optional<std::string> cxx_OOStringFromJSString(ooscript::Context context, ooscript::String string)
{
	if (string == nullptr)  return std::nullopt;
	std::size_t length = 0;
	const ooscript::Char16 *chars = ooscript::getStringCharsAndLength(context, string, &length);
	std::string result;
	for (std::size_t i = 0; i < length; i++)  result += static_cast<char>(chars[i]);	// the test's strings are ASCII
	return result;
}


std::optional<std::string> cxx_OOStringFromJSValue(ooscript::Context context, ooscript::Value value)
{
	if (ooscript::isNullOrUndefined(value))  return std::nullopt;
	return cxx_OOStringFromJSString(context, ooscript::valueToString(context, value));
}


// A JS object as a property list: the test's `this` objects are plain, so any object is a
// non-null value and no object is null (what the engine's conversion gives them).
oo::PList cxx_OOJSPListFromJSObject(ooscript::Context, ooscript::Object object)
{
	if (object == nullptr)  return oo::PList();
	return oo::PList(std::string("object"));
}


typedef oo::PList (*OOJSClassConverterCallback)(ooscript::Context context, ooscript::Object object);

extern "C" void OOJSRegisterObjectConverter(ooscript::ClassDef *theClass, OOJSClassConverterCallback converter)
{
	sConverterRegistered = theClass != nullptr && std::string(theClass->name) == "Timer" && converter != nullptr;
}


oo::PList OOJSBasicPrivateObjectConverter(ooscript::Context, ooscript::Object)
{
	return oo::PList();
}


@interface OOObject (OOJavaScriptConversion)
- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context;
- (std::optional<std::string>) cxx_oo_jsClassName;
- (std::optional<std::string>) cxx_oo_jsDescription;
@end

// OOJavaScriptEngine.mm's glue for OOObject-rooted classes, as it is there.
@implementation OOObject (OOJavaScriptConversion)

- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context
{
	(void)context;
	return ooscript::undefinedValue();
}


- (std::optional<std::string>) cxx_oo_jsClassName
{
	return std::nullopt;
}


- (std::optional<std::string>) cxx_oo_jsDescription
{
	const std::optional<std::string> components = [self cxx_descriptionComponents];
	std::optional<std::string> name = [self cxx_oo_jsClassName];
	if (!name.has_value())  name = oo::DescriptionOf([self class]);
	if (components.has_value())  return oo::str::format("[%s %s]", name->c_str(), components->c_str());
	return oo::str::format("[object %s]", name->c_str());
}

@end


extern "C" ooscript::Value OOJSValueFromNativeObject(ooscript::Context context, id object)
{
	if (object == nil)  return ooscript::nullValue();
	return [object oo_jsValueInContext:context];
}


// The class check of the engine's getter: the JS class, then the Objective-C class.
extern "C" BOOL OOJSObjectGetterImplPRIVATE(ooscript::Context context, ooscript::Object object, ooscript::ClassDef *requiredJSClass,
#ifndef NDEBUG
	Class requiredObjCClass, const char *name,
#endif
	id *outObject)
{
#ifndef NDEBUG
	(void)name;
#endif
	if (ooscript::getClass(context, object) != requiredJSClass)
	{
		std::optional<std::string> got = cxx_OOStringFromJSValue(context, ooscript::objectValue(object));
		cxx_OOJSReportError(context, "Native method expected %s, got %s.", requiredJSClass->name, got ? got->c_str() : "(null)");
		return NO;
	}
	*outObject = (id)ooscript::getPrivate(context, object);
#ifndef NDEBUG
	if (*outObject != nil && ![*outObject isKindOfClass:requiredObjCClass])
	{
		cxx_OOJSReportError(context, "wrong native object");
		return NO;
	}
#endif
	return YES;
}


// OOJavaScriptEngine.mm's toString() for object wrappers.
extern "C" bool OOJSObjectWrapperToString(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	id object = (id)ooscript::getPrivate(context, ooscript::toObject(oojsArgs.thisValue()));
	std::string description = object != nil ? [object cxx_oo_jsDescription].value_or("(null)") : std::string("[object]");
	ooscript::String str = ooscript::newStringCopyN(context, description.data(), description.size());
	oojsArgs.setRval(ooscript::stringValue(str));
	return true;
}


#if OOJS_PROFILE
extern "C" void OOJSProfileEnter(OOJSProfileStackFrame *, const char *)  {}
extern "C" void OOJSProfileExit(OOJSProfileStackFrame *)  {}
#endif

void OOJSPauseTimeLimiter(void)  {}
void OOJSResumeTimeLimiter(void)  {}

#ifndef NDEBUG
void OOJSUnreachable(const char *function, const char *, unsigned)
{
	std::printf("unreachable reached in %s\n", function);
	abort();
}
#endif


/*	The engine object: the one method the timer sends it (-callJSFunction:...), which calls the
	function as the engine does, and the script stack the timer pushes its owner on.
*/
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
	ooscript::Context context = gOOJSMainThreadContext;
	bool OK = ooscript::callFunctionValue(context, jsThis, function, argc, argv, outResult);
	if (!OK)  ooscript::clearPendingException(context);
	return OK;
}

@end


@interface OOJSScript: OOObject
+ (OOJSScript *) currentlyRunningScript;
+ (void) pushScript:(OOJSScript *)script;
+ (void) popScript:(OOJSScript *)script;
@end

@implementation OOJSScript
+ (OOJSScript *) currentlyRunningScript  { return nil; }
+ (void) pushScript:(OOJSScript *)script  { (void)script; sScriptDepth++; sScriptPushes++; }
+ (void) popScript:(OOJSScript *)script  { (void)script; sScriptDepth--; }
@end


// The universe's clock, which the test sets.
namespace {
double sNow = 100.0;
} // namespace

@interface FakeUniverse: OOObject
- (double) getTime;
@end

@implementation FakeUniverse
- (double) getTime  { return sNow; }
@end

@class Universe;
Universe *gSharedUniverse = nil;


extern const char *const cxx_kOOLogException;
const char *const cxx_kOOLogException = "exception";

void OOLogGenericSubclassResponsibilityForFunction(const char *inFunction)
{
	(void)inFunction;
}


// MARK: The context -------------------------------------------------------------------------------

namespace {

ooscript::Runtime sRuntime;
ooscript::Object sGlobal;


void SetUpContext()
{
	if (gOOJSMainThreadContext != nullptr)  return;
	sRuntime = ooscript::newRuntime(8u * 1024u * 1024u);
	gOOJSMainThreadContext = ooscript::newContext(sRuntime, 8192);
	ooscript::beginRequest(gOOJSMainThreadContext);
	sGlobal = ooscript::getGlobalObject(gOOJSMainThreadContext);
	ooscript::initStandardClasses(gOOJSMainThreadContext, sGlobal);
	InitOOJSTimer(gOOJSMainThreadContext, sGlobal);
	gSharedUniverse = (Universe *)[[FakeUniverse alloc] init];
}


// Evaluates src (statements; the value of the last one) and gives its result as a string
// ("undefined", "null", ...), or "threw: <message>".
std::string Eval(const char *src)
{
	SetUpContext();
	std::string quoted;
	for (const char *c = src; *c != '\0'; c++)
	{
		if (*c == '\\' || *c == '"')  quoted += '\\';
		quoted += *c;
	}
	std::string wrapped = std::string("(function () { try { return String((0, eval)(\"") + quoted + "\")); } catch (e) { return 'threw: ' + (e && e.message !== undefined ? e.message : e); } })()";
	ooscript::Value result = ooscript::undefinedValue();
	bool OK = false;
	@autoreleasepool	// as the game's frame loop drains: nothing is left to the thread's pool at exit
	{
		OK = ooscript::evaluateScript(gOOJSMainThreadContext, sGlobal, wrapped.c_str(), static_cast<unsigned>(wrapped.size()), "test.js", 1, &result);
	}
	if (!OK)
	{
		ooscript::clearPendingException(gOOJSMainThreadContext);
		return "<evaluation failed>";
	}
	return cxx_OOStringFromJSValue(gOOJSMainThreadContext, result).value_or("<not a string>");
}


void Update(double now)
{
	sNow = now;
	@autoreleasepool
	{
		[OOScriptTimer updateTimers];
	}
}

}	// namespace


// MARK: Tests -------------------------------------------------------------------------------------

OO_TEST(classSetUp)
{
	OO_CHECK_EQ(Eval("typeof Timer"), "function");
	OO_CHECK(sConverterRegistered);
	OO_CHECK_EQ(Eval("Object.keys(Timer.prototype).sort().join()"), "interval,isRunning,nextTime");
}


OO_TEST(constructorErrors)
{
	OO_CHECK_EQ(Eval("Timer({}, function () {}, 1)"), "threw: Timer() cannot be called as a function, it must be used as a constructor (as in new Timer(...)).");
	OO_CHECK_EQ(Eval("new Timer({}, function () {})"), "threw: bad arguments: .Timer (2): Invalid arguments in constructor; expected (object, function, number [, number])");
	OO_CHECK_EQ(Eval("new Timer({}, 5, 1)"), "threw: bad arguments: .Timer (1): Invalid argument in constructor; expected function");
	OO_CHECK_EQ(Eval("new Timer({}, function () {}, 'x')"), "threw: bad arguments: .Timer (1): Invalid argument in constructor; expected number");
	OO_CHECK_EQ(Eval("new Timer({}, function () {}, NaN)"), "threw: bad arguments: .Timer (1): Invalid argument in constructor; expected number");
}


OO_TEST(properties)
{
	sNow = 100.0;
	OO_CHECK_EQ(Eval("globalThis.t1 = new Timer({}, function () {}, 5); t1.nextTime"), "105");
	OO_CHECK_EQ(Eval("t1.interval"), "-1");
	OO_CHECK_EQ(Eval("t1.isRunning"), "true");
	OO_CHECK_EQ(Eval("t1 instanceof Timer"), "true");

	// The interval: at least 0.25; a fourth argument that is not a number is ignored.
	OO_CHECK_EQ(Eval("globalThis.t2 = new Timer({}, function () {}, 1, 0.1); t2.interval"), "0.25");
	OO_CHECK_EQ(Eval("new Timer({}, function () {}, 1, 3).interval"), "3");
	OO_CHECK_EQ(Eval("new Timer({}, function () {}, 1, 'x').interval"), "NaN");
	OO_CHECK_EQ(Eval("new Timer({}, function () {}, 1, {}).interval"), "NaN");
	OO_CHECK_EQ(Eval("new Timer({}, function () {}, 1, -4).interval"), "-1");

	// A negative delay leaves a repeating timer stopped. A one-shot timer whose time has passed
	// cannot be made: the constructor fails without an exception, which ends the script.
	OO_CHECK_EQ(Eval("globalThis.t3 = new Timer({}, function () {}, -1, 5); t3.isRunning"), "false");
	OO_CHECK_EQ(Eval("t3.nextTime + ',' + t3.interval"), "99,5");
	OO_CHECK_EQ(Eval("new Timer({}, function () {}, -1)"), "<evaluation failed>");

	// The next time cannot change while the timer runs: a warning, and the old time stays.
	sWarnings.clear();
	OO_CHECK_EQ(Eval("t1.nextTime = 200; t1.nextTime"), "105");
	OO_CHECK_EQ(sWarnings.size(), 1u);
	if (sWarnings.size() == 1)  OO_CHECK(sWarnings[0].find("Ignoring attempt to change next fire time for running timer <OOJSTimer") == 0);
	OO_CHECK_EQ(Eval("t3.nextTime = 200; t3.nextTime"), "200");
	OO_CHECK_EQ(Eval("t3.interval = 7; t3.interval"), "7");
	OO_CHECK_EQ(Eval("t3.interval = -7; t3.interval"), "-1");
	OO_CHECK_EQ(Eval("t3.interval = 'abc'; t3.interval"), "NaN");
	OO_CHECK_EQ(Eval("t3.isRunning = true; t3.isRunning"), "false");
	OO_CHECK_EQ(Eval("(function () { 'use strict'; t3.isRunning = true; return t3.isRunning; })()"), "false");	// ignored even in strict code

	OO_CHECK_EQ(Eval("t1.stop(); t2.stop(); t1.isRunning"), "false");
	OO_CHECK_EQ(Eval("Timer.prototype.nextTime"), "0");	// the prototype is a Timer with no timer: nil answered 0
}


OO_TEST(startAndStop)
{
	sNow = 100.0;
	OO_CHECK_EQ(Eval("globalThis.s = new Timer({}, function () {}, -1, 1); s.isRunning"), "false");
	OO_CHECK_EQ(Eval("s.start()"), "true");
	OO_CHECK_EQ(Eval("s.isRunning"), "true");
	OO_CHECK_EQ(Eval("s.start()"), "true");
	OO_CHECK_EQ(Eval("s.stop()"), "undefined");
	OO_CHECK_EQ(Eval("s.isRunning"), "false");
	OO_CHECK_EQ(Eval("Timer.prototype.start.call({})"), "threw: Native method expected Timer, got [object Object].");
	OO_CHECK_EQ(Eval("Timer.prototype.stop.call(new Date(0)) === undefined").rfind("threw: Native method expected Timer, got ", 0), 0u);
}


OO_TEST(toString)
{
	sNow = 100.0;
	OO_CHECK_EQ(Eval("new Timer({}, function tick() {}, 1)"), "[Timer nextTime: 101, one-shot, running, function: tick]");
	OO_CHECK_EQ(Eval("new Timer({}, function () {}, 2, 5)"), "[Timer nextTime: 102, interval: 5, running, function: anonymous]");
	OO_CHECK_EQ(Eval("new Timer({}, function () {}, -2, 5)"), "[Timer nextTime: 98, interval: 5, not running, function: anonymous]");
	OO_CHECK_EQ(Eval("(function () { var t = new Timer({}, function tock() {}, 1); t.stop(); return t; })()"), "[Timer nextTime: 101, one-shot, not running, function: tock]");
	OO_CHECK_EQ(Eval("Timer.prototype.toString.call({})"), "[object]");
	// Stop the running ones above, so that later tests do not fire them.
	Update(100.0);
	[OOScriptTimer noteGameReset];
}


OO_TEST(firing)
{
	sNow = 100.0;
	OO_CHECK_EQ(Eval("globalThis.log = []; globalThis.owner = { name: 'owner' }; "
					 "globalThis.once = new Timer(owner, function () { log.push('once:' + this.name); }, 1); "
					 "globalThis.rep = new Timer(owner, function () { log.push('rep:' + this.name); }, 0.5, 2); "
					 "log.length"), "0");
	sCalls = 0;
	sScriptPushes = 0;
	Update(100.4);
	OO_CHECK_EQ(Eval("log.join()"), "");
	Update(101.0);
	OO_CHECK_EQ(Eval("log.join()"), "rep:owner,once:owner");
	OO_CHECK_EQ(Eval("once.isRunning + ',' + rep.isRunning + ',' + rep.nextTime"), "false,true,102.5");
	Update(105.0);
	OO_CHECK_EQ(Eval("log.join()"), "rep:owner,once:owner,rep:owner");
	OO_CHECK_EQ(Eval("rep.nextTime"), "106.5");
	OO_CHECK_EQ(sCalls, 3);
	OO_CHECK_EQ(sScriptPushes, 3);
	OO_CHECK_EQ(sScriptDepth, 0);

	// A timer that stops itself when it fires.
	OO_CHECK_EQ(Eval("rep.stop(); globalThis.self = new Timer(owner, function () { log.push('self'); self.stop(); }, 1, 1); self.isRunning"), "true");
	Update(106.0);
	OO_CHECK_EQ(Eval("log.join() + ';' + self.isRunning"), "rep:owner,once:owner,rep:owner,self;false");
	Update(110.0);
	OO_CHECK_EQ(Eval("log.length"), "4");
}


OO_TEST(nullThis)
{
	// A timer whose `this` is null or undefined is stopped when it is due, without a call.
	sNow = 100.0;
	OO_CHECK_EQ(Eval("globalThis.log2 = []; globalThis.orphan = new Timer(null, function () { log2.push('x'); }, 1, 1); orphan.isRunning"), "true");
	sCalls = 0;
	Update(101.0);
	OO_CHECK_EQ(sCalls, 0);
	OO_CHECK_EQ(Eval("log2.length + ',' + orphan.isRunning"), "0,false");
	OO_CHECK_EQ(Eval("orphan.start()"), "true");
	Update(103.0);
	OO_CHECK_EQ(Eval("orphan.isRunning"), "false");
}


OO_TEST(engineReset)
{
	sNow = 100.0;
	OO_CHECK_EQ(Eval("globalThis.log3 = []; globalThis.r = new Timer({}, function () { log3.push('r'); }, 1, 1); r.isRunning"), "true");
	oo::NotificationCenter::defaultCenter().post(kOOJavaScriptEngineWillResetNotificationName, [OOJavaScriptEngine sharedEngine]);
	OO_CHECK_EQ(Eval("r.isRunning"), "false");
	OO_CHECK_EQ(Eval("String(r)"), "[Timer invalid]");
	Update(105.0);
	OO_CHECK_EQ(Eval("log3.length"), "0");
}


OO_TEST(unrootedRunningTimerGC)
{
	// A script drops its last reference to a running timer and the engine collects it: the
	// finalizer warns and lets go of the timer, without re-entering the engine (bead oo-r1ci7).
	// The function's name is a getter that counts its calls: reading it from the finalizer would
	// run script inside the collection, which is the defect.
	sNow = 100.0;
	OO_CHECK_EQ(Eval("globalThis.nameReads = 0; (function () { var f = function () {}; Object.defineProperty(f, 'name', { get: function () { nameReads++; return 'spy'; } }); new Timer({}, f, 1, 1); })(); 'dropped'"), "dropped");
	ooscript::gc(gOOJSMainThreadContext);
	OO_CHECK_EQ(Eval("nameReads"), "0");

	// Many collections in one process, then more script, so a corrupted heap shows up here or
	// at exit rather than one run in six.
	for (int i = 0; i < 40; i++)
	{
		OO_CHECK_EQ(Eval("(function () { new Timer({}, function tick() {}, 1, 1); new Timer({}, function () {}, 2); })(); 'dropped'"), "dropped");
		ooscript::gc(gOOJSMainThreadContext);
	}
	OO_CHECK_EQ(Eval("var a = []; for (var i = 0; i < 1000; i++) a.push({ n: String(i) }); a.length"), "1000");
	ooscript::gc(gOOJSMainThreadContext);
	OO_CHECK_EQ(Eval("String(new Timer({}, function after() {}, 1))"), "[Timer nextTime: 101, one-shot, running, function: after]");
}


OO_TEST_MAIN()
