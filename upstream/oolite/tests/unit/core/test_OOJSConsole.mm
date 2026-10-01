/*	test_OOJSConsole.mm
	Unit tests for the debug console's JS binding (src/Core/Debug/OOJSConsole.h/.mm): bead oo-jy98,
	a binding file converted the way amendment oo-ppc converts the OOJS* files, in the Debug module
	of amendment oo-kq7 (proposed ADR-0056).

	It runs the Console and ConsoleSettings classes in a real context on the game's own facade
	backend (ooscript/JSEngine_quickjs.cpp) and links the game's own objects for the binding, the
	engine's exception translator (OOJSEngineNativeWrappers.mm), the debug monitor's Objective-C
	facade (OODebugMonitor+ObjCBridge.mm, the object the console's JS objects hold) and its weak
	reference. What the rest of the game provides is defined below as the smallest stand-in that
	does the same thing (amendments oo-z1s4 item 4, oo-ppc item 6, oo-ykoy item 4): the C++ debug
	monitor's members (recording what they are asked), the JavaScript engine's flags, the universe's
	detail level and FPS display, the OpenGL extension manager's answers, an entity that can be
	inspected, the script stack, the error reporters and the string and property-list converters.
	It imports neither OOJavaScriptEngine.h nor Universe.h, which would bring in the game classes.
	The expectations were written against the Objective-C file and run on it first; they pin the
	JS-visible behaviour of every property and method that compiles in the test flavour.
	Run: bash tools/check-core-tests.sh test_OOJSConsole
*/

#import "OOCocoa.h"
#import "OOJSConsole.h"
#import "OODebugMonitor.h"
#import "OOJSEngineCore.h"
#import "OODebugFlags.h"
#include "oofnd/Log.hpp"
#include "oofnd/String.hpp"

#include "oo_test.hpp"

#include <cstdarg>
#include <cstdio>
#include <string>
#include <utility>
#include <vector>


// MARK: The debug monitor's C++ members -----------------------------------------------------------

namespace {

struct MonitorRecord
{
	std::vector<std::pair<std::string, oo::PList>>	configurationSets;
	oo::PList::Dict									configuration;
	std::vector<std::string>						lines;			// "colorKey|text|location,length"
	int												clears = 0;
	int												memoryDumps = 0;
	int												jsMemoryDumps = 0;
	bool											ignoresDroppedPackets = false;
};

MonitorRecord sMonitor;

}	// namespace


cxx::OODebugMonitor *cxx::OODebugMonitor::sharedDebugMonitor()
{
	static cxx::OODebugMonitor *monitor = nullptr;
	if (monitor == nullptr)  monitor = oo::makeRef<cxx::OODebugMonitor>().leakRef();
	return monitor;
}

bool cxx::OODebugMonitor::setDebugger(id<OODebuggerInterface>)  { return false; }
void cxx::OODebugMonitor::disconnectDebugger(id<OODebuggerInterface>, const std::optional<std::string> &)  {}
void cxx::OODebugMonitor::performJSConsoleCommand(const std::string &)  {}

void cxx::OODebugMonitor::appendJSConsoleLine(const std::string &string, const std::optional<std::string> &colorKey, NSRange emphasisRange)
{
	sMonitor.lines.push_back(colorKey.value_or("(none)") + "|" + string + "|" + std::to_string(emphasisRange.location) + "," + std::to_string(emphasisRange.length));
}

void cxx::OODebugMonitor::appendJSConsoleLine(const std::string &string, const std::optional<std::string> &colorKey)
{
	appendJSConsoleLine(string, colorKey, NSMakeRange(0, 0));
}

void cxx::OODebugMonitor::clearJSConsole()  { sMonitor.clears++; }
void cxx::OODebugMonitor::showJSConsole()  {}

oo::PList cxx::OODebugMonitor::configurationValueForKey(const std::string &key)
{
	auto found = sMonitor.configuration.find(key);
	return (found != sMonitor.configuration.end()) ? found->second : oo::PList();
}

long long cxx::OODebugMonitor::configurationIntValueForKey(const std::string &, long long value)  { return value; }

void cxx::OODebugMonitor::setConfigurationValue(const oo::PList &value, const std::string &key)
{
	sMonitor.configurationSets.emplace_back(key, value);
}

std::vector<std::string> cxx::OODebugMonitor::configurationKeys()  { return {}; }
bool cxx::OODebugMonitor::debuggerConnected()  { return false; }
void cxx::OODebugMonitor::dumpMemoryStatistics()  { sMonitor.memoryDumps++; }
size_t cxx::OODebugMonitor::dumpJSMemoryStatistics()  { sMonitor.jsMemoryDumps++; return 0; }
void cxx::OODebugMonitor::setTCPIgnoresDroppedPackets(bool flag)  { sMonitor.ignoresDroppedPackets = flag; }
bool cxx::OODebugMonitor::TCPIgnoresDroppedPackets()  { return sMonitor.ignoresDroppedPackets; }
void cxx::OODebugMonitor::setUsingPlugInController(bool)  {}
bool cxx::OODebugMonitor::usingPlugInController()  { return false; }
std::string cxx::OODebugMonitor::sourceCodeForFile(const std::string &, unsigned)  { return std::string(); }
#if OOLITE_GNUSTEP
void cxx::OODebugMonitor::applicationWillTerminate()  {}
#endif
void cxx::OODebugMonitor::jsEngine(OOJavaScriptEngine *, ooscript::Context, ooscript::ErrorReport *, unsigned, bool, const std::string &)  {}
void cxx::OODebugMonitor::jsEngine(OOJavaScriptEngine *, ooscript::Context, const std::string &, const std::optional<std::string> &)  {}
ooscript::Value cxx::OODebugMonitor::oo_jsValueInContext(ooscript::Context)  { return ooscript::undefinedValue(); }


// MARK: What the rest of the game provides ---------------------------------------------------------

#ifndef NDEBUG
uint32_t gDebugFlags = 0;
#endif

ooscript::Context gOOJSMainThreadContext = nullptr;

namespace {

std::vector<std::string> sWarnings;
int sLogMarkers = 0;
int sInspections = 0;

}	// namespace


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
	va_list args;
	va_start(args, format);
	sWarnings.push_back(oo::str::vformat(format, args));
	va_end(args);
}


void cxx_OOJSReportBadArguments(ooscript::Context context, const std::optional<std::string> &scriptClass, const std::optional<std::string> &function, unsigned argc, ooscript::Value *, const std::optional<std::string> &message, const std::optional<std::string> &expectedArgsDescription)
{
	cxx_OOJSReportError(context, "bad arguments: %s.%s (%u): %s; expected %s", scriptClass.value_or("").c_str(), function.value_or("").c_str(), argc, message.value_or("").c_str(), expectedArgsDescription.value_or("").c_str());
}


void OOJSReportBadPropertySelector(ooscript::Context context, ooscript::Object, ooscript::PropertyId, ooscript::PropertySpec *)
{
	cxx_OOJSReportError(context, "bad property selector");
}


std::optional<std::string> cxx_OOStringFromJSString(ooscript::Context context, ooscript::String str)
{
	if (str == nullptr)  return std::nullopt;
	std::size_t length = 0;
	const ooscript::Char16 *chars = ooscript::getStringCharsAndLength(context, str, &length);
	std::string result;
	for (std::size_t i = 0; i < length; i++)  result += static_cast<char>(chars[i]);	// the test's strings are ASCII
	return result;
}


std::optional<std::string> cxx_OOStringFromJSValue(ooscript::Context context, ooscript::Value value)
{
	if (ooscript::isNullOrUndefined(value))  return std::nullopt;
	return cxx_OOStringFromJSString(context, ooscript::valueToString(context, value));
}


// Strings, integers, reals and booleans, as the engine converts them; null for anything else.
ooscript::Value OOJSValueFromPList(ooscript::Context context, const oo::PList &plist)
{
	if (const std::string *str = plist.getIf<std::string>())
	{
		ooscript::String js = ooscript::newStringCopyN(context, str->data(), str->size());
		return js != nullptr ? ooscript::stringValue(js) : ooscript::nullValue();
	}
	if (plist.isBool())  return OOJSValueFromBOOL(*plist.getIf<bool>());
	if (plist.isNumber())
	{
		ooscript::Value result = ooscript::nullValue();
		ooscript::newNumberValue(context, plist.doubleValue(), &result);
		return result;
	}
	if (plist.isArray())
	{
		ooscript::Object array = ooscript::newArrayObject(context, 0, nullptr);
		return ooscript::objectValue(array);	// the script stack: its length is what the test reads
	}
	return ooscript::nullValue();
}


oo::PList cxx_OOJSPListFromJSValue(ooscript::Context context, ooscript::Value value)
{
	if (ooscript::isString(value))  return oo::PList(cxx_OOStringFromJSValue(context, value).value_or(""));
	if (ooscript::isBoolean(value))  return oo::PList(ooscript::toBoolean(value));
	double number = 0;
	if (ooscript::isNumber(value) && ooscript::valueToNumber(context, value, &number))  return oo::PList(number);
	return oo::PList();
}


namespace {
ooscript::Object sConsoleObject = nullptr;
}	// namespace


// The monitor's facade is the console object (as the monitor's -oo_jsValueInContext: makes it);
// anything else is undefined.
ooscript::Value OOJSValueFromNativeObject(ooscript::Context, id object)
{
	if ([object isKindOfClass:[OODebugMonitor class]] && sConsoleObject != nullptr)  return ooscript::objectValue(sConsoleObject);
	return ooscript::undefinedValue();
}


id OOJSNativeObjectFromJSObject(ooscript::Context context, ooscript::Object object)
{
	// The console objects' private slot holds the monitor's weak reference.
	id private_ = (id)ooscript::getPrivate(context, object);
	return [private_ weakRefUnderlyingObject];
}


id OOJSNativeObjectOfClassFromJSObject(ooscript::Context context, ooscript::Object object, Class requiredClass)
{
	id result = OOJSNativeObjectFromJSObject(context, object);
	if (![result isKindOfClass:requiredClass])  result = nil;
	return result;
}


void OOJSRegisterObjectConverter(ooscript::ClassDef *, OOJSClassConverterCallback)  {}
oo::PList OOJSBasicPrivateObjectConverter(ooscript::Context, ooscript::Object)  { return oo::PList(); }


bool OOJSUnconstructableConstruct(ooscript::Context context, ooscript::CallArgs &)
{
	cxx_OOJSReportError(context, "unconstructable");
	return false;
}


#ifndef NDEBUG
void OOJSUnreachable(const char *function, const char *, unsigned)
{
	std::printf("unreachable reached in %s\n", function);
	abort();
}
#endif


#ifndef OOJSDumpStack
void OOJSDumpStack(ooscript::Context)  {}	// the profiler's, when a time limit is hit
#endif


std::string OOPlatformDescription(void)  { return "test platform"; }
void OOLogInsertMarker(void)  { sLogMarkers++; }


std::string cxx_OOStringFromGraphicsDetail(OOGraphicsDetail detail)
{
	return "DETAIL_" + std::to_string(static_cast<int>(detail));
}


OOGraphicsDetail cxx_OOGraphicsDetailFromString(const std::string &string)
{
	return (string == "DETAIL_2") ? DETAIL_LEVEL_SHADERS : DETAIL_LEVEL_MINIMUM;
}


@interface OOJavaScriptEngine: OOObject
{
@public
	BOOL _showErrorLocations, _dumpStackForErrors, _dumpStackForWarnings;
}
+ (OOJavaScriptEngine *) sharedEngine;
@end

@implementation OOJavaScriptEngine

+ (OOJavaScriptEngine *) sharedEngine
{
	static OOJavaScriptEngine *engine = nil;
	if (engine == nil)  engine = [[OOJavaScriptEngine alloc] init];
	return engine;
}

- (ooscript::Object) globalObject  { return ooscript::getGlobalObject(gOOJSMainThreadContext); }
- (BOOL) showErrorLocations  { return _showErrorLocations; }
- (void) setShowErrorLocations:(BOOL)flag  { _showErrorLocations = flag; }
- (BOOL) dumpStackForErrors  { return _dumpStackForErrors; }
- (void) setDumpStackForErrors:(BOOL)flag  { _dumpStackForErrors = flag; }
- (BOOL) dumpStackForWarnings  { return _dumpStackForWarnings; }
- (void) setDumpStackForWarnings:(BOOL)flag  { _dumpStackForWarnings = flag; }

@end


// The OpenGL extension manager's answers.
@interface OOOpenGLExtensionManager: OOObject
+ (OOOpenGLExtensionManager *) sharedManager;
@end

@implementation OOOpenGLExtensionManager

+ (OOOpenGLExtensionManager *) sharedManager
{
	static OOOpenGLExtensionManager *manager = nil;
	if (manager == nil)  manager = [[OOOpenGLExtensionManager alloc] init];
	return manager;
}

- (OOGraphicsDetail) maximumDetailLevel  { return DETAIL_LEVEL_MAXIMUM; }
- (std::optional<std::string>) vendorString  { return std::string("Test Vendor"); }
- (std::optional<std::string>) rendererString  { return std::nullopt; }
- (int) textureUnitCount  { return 4; }
- (int) textureImageUnitCount  { return 16; }

@end


@interface FakeUniverse: OOObject
{
@public
	OOGraphicsDetail _detailLevel;
	BOOL _displayFPS;
}
@end

@implementation FakeUniverse

- (OOGraphicsDetail) detailLevel  { return _detailLevel; }
- (void) setDetailLevel:(OOGraphicsDetail)value  { _detailLevel = value; }
- (BOOL) displayFPS  { return _displayFPS; }
- (void) setDisplayFPS:(BOOL)value  { _displayFPS = value; }

@end

@class Universe;
Universe *gSharedUniverse = nil;


// An entity, as the console's inspectEntity() sees it: one answers -inspect (the Mac debug OXP's
// inspector), one does not.
@interface Entity: OOObject
@end

@implementation Entity
@end

@interface InspectableEntity: Entity
@end

@implementation InspectableEntity
- (void) inspect  { sInspections++; }
@end


namespace {

ooscript::Object sEntityProto = nullptr;	// JS objects of this prototype stand for entities
Entity *sPlainEntity = nil;
Entity *sInspectableEntity = nil;

}	// namespace


// inspectEntity(true) is the inspectable entity, inspectEntity(false) the other; anything else none.
// (OOJSEntity.h declares it with C linkage.)
extern "C" BOOL JSValueToEntity(ooscript::Context, ooscript::Value value, Entity **outEntity);
BOOL JSValueToEntity(ooscript::Context, ooscript::Value value, Entity **outEntity)
{
	if (!ooscript::isBoolean(value))  return NO;
	*outEntity = ooscript::toBoolean(value) ? sInspectableEntity : sPlainEntity;
	return YES;
}


@interface OOJSScript: OOObject
@end

@implementation OOJSScript

+ (std::vector<oo::ObjCRef<OOJSScript *>>) scriptStack
{
	return {};
}

@end


// MARK: The context -------------------------------------------------------------------------------

namespace {

ooscript::Runtime sRuntime;
ooscript::Context sContext;
ooscript::Object sGlobal;


void SetUpContext()
{
	if (sContext != nullptr)  return;
	sRuntime = ooscript::newRuntime(8u * 1024u * 1024u);
	sContext = ooscript::newContext(sRuntime, 8192);
	gOOJSMainThreadContext = sContext;
	ooscript::beginRequest(sContext);
	sGlobal = ooscript::getGlobalObject(sContext);
	ooscript::initStandardClasses(sContext, sGlobal);
	gSharedUniverse = (Universe *)[[FakeUniverse alloc] init];
	sPlainEntity = [[Entity alloc] init];
	sInspectableEntity = [[InspectableEntity alloc] init];

	sConsoleObject = DebugMonitorToJSConsole(sContext, oo::ToObjC(cxx::OODebugMonitor::sharedDebugMonitor()));
	ooscript::Value value = ooscript::objectValue(sConsoleObject);
	ooscript::setProperty(sContext, sGlobal, "console", &value);
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


std::string EvalShown(const char *src, const char *expected)
{
	std::string result = Eval(src);
	if (result != expected)  std::printf("    %s\n    gave: %s\n", src, result.c_str());
	return result;
}
#define OO_CHECK_EVAL(src, expected)  OO_CHECK_EQ(EvalShown(src, expected), expected)

}	// namespace


// MARK: Tests -------------------------------------------------------------------------------------

// The console object and its settings object are made, and are not constructible from JS.
OO_TEST(theConsoleObjects)
{
	OO_CHECK_EVAL("typeof console", "object");
	OO_CHECK_EVAL("typeof console.settings", "object");
	OO_CHECK_EVAL("Object.getPrototypeOf(console) === Object.getPrototypeOf(console.settings)", "false");
	OO_CHECK_EVAL("console.DEBUG_LINKED_LISTS", std::to_string(DEBUG_LINKED_LISTS).c_str());
	OO_CHECK_EVAL("console.DEBUG_SHADER_VALIDATION", std::to_string(DEBUG_SHADER_VALIDATION).c_str());
}


// The settings are the monitor's configuration: read, set, set to null/undefined, deleted.
OO_TEST(theSettingsAreTheMonitorsConfiguration)
{
	SetUpContext();
	sMonitor = MonitorRecord();
	sMonitor.configuration["font-size"] = oo::PList(12);

	OO_CHECK_EVAL("console.settings['font-size']", "12");
	OO_CHECK_EVAL("console.settings['missing']", "undefined");

	OO_CHECK_EVAL("console.settings['font-size'] = 14", "14");
	OO_CHECK_EVAL("console.settings['font-face'] = 'Courier'", "Courier");
	OO_CHECK_EVAL("console.settings['gone'] = null", "null");
	// delete of a setting is true, but the backend does not call the class's delete hook for a
	// property the object does not have, so the monitor is not told.
	OO_CHECK_EVAL("delete console.settings['also-gone']", "true");
	OO_CHECK(sMonitor.configurationSets.size() == 3);
	if (sMonitor.configurationSets.size() == 3)
	{
		OO_CHECK(sMonitor.configurationSets[0].first == "font-size" && sMonitor.configurationSets[0].second == oo::PList(14.0));
		OO_CHECK(sMonitor.configurationSets[1].first == "font-face" && sMonitor.configurationSets[1].second == oo::PList(std::string("Courier")));
		OO_CHECK(sMonitor.configurationSets[2].first == "gone" && sMonitor.configurationSets[2].second.isNull());
	}

	// A value the engine cannot convert is a warning, not a setting.
	sWarnings.clear();
	OO_CHECK_EVAL("console.settings['f'] = {}", "[object Object]");
	OO_CHECK(sMonitor.configurationSets.size() == 3);
	OO_CHECK(sWarnings.size() == 1);
}


// consoleMessage(colour, message[, location, length]) is a console line; one argument is a
// command result; none is a warning.
OO_TEST(consoleMessage)
{
	SetUpContext();
	sMonitor = MonitorRecord();
	sWarnings.clear();
	OO_CHECK_EVAL("console.consoleMessage('error', 'hello', 1, 3)", "undefined");
	OO_CHECK_EVAL("console.consoleMessage('general', 'plain')", "undefined");
	OO_CHECK_EVAL("console.consoleMessage('only')", "undefined");
	OO_CHECK_EVAL("console.consoleMessage()", "undefined");
	OO_CHECK(sMonitor.lines == (std::vector<std::string>{ "error|hello|1,3", "general|plain|0,0", "command-result|only|0,0" }));
	OO_CHECK(sWarnings.size() == 1);

	// Not the console: an internal error.
	OO_CHECK_EVAL("console.consoleMessage.call({}, 'x', 'y')", "threw: Expected OODebugMonitor, got (null) in bool ConsoleConsoleMessage(ooscript::Context, ooscript::CallArgs &). This is an internal error, please report it.");
}


// clearConsole(), writeMemoryStats(), writeJSMemoryStats() and writeLogMarker() reach the monitor
// and the log.
OO_TEST(theMonitorsActions)
{
	SetUpContext();
	sMonitor = MonitorRecord();
	OO_CHECK_EVAL("console.clearConsole()", "undefined");
	OO_CHECK_EVAL("console.writeMemoryStats()", "undefined");
	OO_CHECK_EVAL("console.writeJSMemoryStats()", "undefined");
	OO_CHECK_EVAL("console.writeLogMarker()", "undefined");
	OO_CHECK(sMonitor.clears == 1 && sMonitor.memoryDumps == 1 && sMonitor.jsMemoryDumps == 1);
	OO_CHECK(sLogMarkers == 1);
	OO_CHECK_EVAL("console.clearConsole.call({})", "threw: Expected OODebugMonitor, got (null) in bool ConsoleClearConsole(ooscript::Context, ooscript::CallArgs &). This is an internal error, please report it.");
}


// The read-write flags: the monitor's dropped-packet flag, the engine's error flags, the
// universe's FPS display and detail level, the context's strict option and the debug flags.
OO_TEST(theFlags)
{
	SetUpContext();
	sMonitor = MonitorRecord();
	OO_CHECK_EVAL("console.ignoreDroppedPackets", "false");
	OO_CHECK_EVAL("console.ignoreDroppedPackets = true", "true");
	OO_CHECK(sMonitor.ignoresDroppedPackets);
	OO_CHECK_EVAL("console.ignoreDroppedPackets", "true");

	OO_CHECK_EVAL("console.__showErrorLocations = true", "true");
	OO_CHECK_EVAL("console.__showErrorLocations", "true");
	OO_CHECK_EVAL("console.__dumpStackForErrors", "false");
	OO_CHECK_EVAL("console.__dumpStackForWarnings = 1", "1");
	OO_CHECK_EVAL("console.__dumpStackForWarnings", "true");

	OO_CHECK_EVAL("console.displayFPS", "false");
	OO_CHECK_EVAL("console.displayFPS = true", "true");
	OO_CHECK_EVAL("console.displayFPS", "true");
	OO_CHECK_EVAL("console.detailLevel", "DETAIL_0");
	OO_CHECK_EVAL("console.detailLevel = 'DETAIL_2'", "DETAIL_2");
	OO_CHECK_EVAL("console.detailLevel", "DETAIL_2");

	OO_CHECK_EVAL("console.pedanticMode = true", "true");
	OO_CHECK_EVAL("console.pedanticMode", "true");
	OO_CHECK_EVAL("console.pedanticMode = false", "false");
	OO_CHECK_EVAL("console.pedanticMode", "false");

#ifndef NDEBUG
	OO_CHECK_EVAL("console.debugFlags = 5", "5");
	OO_CHECK(gDebugFlags == 5);
	OO_CHECK_EVAL("console.debugFlags", "5");
#endif

	OO_CHECK_EVAL("console.platformDescription", "test platform");
}


// The OpenGL answers, from the extension manager.
OO_TEST(theOpenGLAnswers)
{
	OO_CHECK_EVAL("console.maximumDetailLevel", "DETAIL_3");
	OO_CHECK_EVAL("console.glVendorString", "Test Vendor");
	OO_CHECK_EVAL("console.glRendererString", "null");
	OO_CHECK_EVAL("console.glFixedFunctionTextureUnitCount", "4");
	OO_CHECK_EVAL("console.glFragmentShaderTextureUnitCount", "16");
}


// inspectEntity() asks an entity that can be inspected to do so; other values do nothing.
OO_TEST(inspectEntity)
{
	SetUpContext();
	sInspections = 0;
	OO_CHECK_EVAL("console.inspectEntity(true)", "undefined");
	OO_CHECK_EVAL("console.inspectEntity(false)", "undefined");
	OO_CHECK_EVAL("console.inspectEntity(42)", "undefined");
	OO_CHECK(sInspections == 1);
}


// The rest: the script stack, executable JavaScript, the log's message classes, garbage collection.
OO_TEST(theOtherMethods)
{
	OO_CHECK_EVAL("console.scriptStack().length", "0");
	OO_CHECK_EVAL("console.isExecutableJavaScript(this, '1 + 1')", "true");
	OO_CHECK_EVAL("console.isExecutableJavaScript(this, '1 +')", "true");	// the backend's answer for incomplete input
	OO_CHECK_EVAL("console.isExecutableJavaScript(this)", "false");
	// (The log is not set up in this process, so it displays nothing.)
	OO_CHECK_EVAL("console.setDisplayMessagesInClass('test.console.class', true)", "undefined");
	OO_CHECK_EVAL("typeof console.displayMessagesInClass('test.console.class')", "boolean");
	OO_CHECK_EVAL("console.displayMessagesInClass()", "false");
	OO_CHECK_EVAL("console.garbageCollect().indexOf('Bytes before: ') === 0", "true");
	OO_CHECK_EVAL("console.noSuchMethod", "undefined");
	OO_CHECK_EVAL("new (Object.getPrototypeOf(console).constructor)()", "threw: unconstructable");
}


// profile(), getProfile() and trace() run a function under the engine's profiler (this file links
// the real one), with "this" the given object or the console's script.
OO_TEST(profiling)
{
	OO_CHECK_EVAL("console.trace(function () { return 7; }, {})", "7");
	OO_CHECK_EVAL("console.trace(function () { return typeof this; })", "object");
	OO_CHECK_EVAL("typeof console.profile(function () {})", "string");
	OO_CHECK_EVAL("console.getProfile(function () {})", "undefined");
	OO_CHECK_EVAL("console.profile(42)", "threw: bad arguments: Console.profile (1): ; expected function");
}


OO_TEST_MAIN()
