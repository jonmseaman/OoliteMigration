/*	test_OOJSGlobal.mm
	Unit tests for the JS global object (src/Core/Scripting/OOJSGlobal.h/.mm) and the engine
	monitor send it makes (bead oo-9ht.98 removed the Objective-C category it declared): bead oo-3dj2, converted
	the way bead oo-ppc converted OOJSVector (proposed ADR-0056 amendments oo-ppc and oo-6ia4).

	As the binding tests of amendment oo-ppc item 6 do, it makes the global object in a real
	context on the game's own façade backend (ooscript/JSEngine_quickjs.cpp) with the file's own
	CreateOOJSGlobal()/SetUpOOJSGlobal(), and links the game's own objects for the binding, the
	engine's exception translator (OOJSEngineNativeWrappers.mm) and the converted classes it uses
	(OOColor, reached through its façade, and OOJSGuiScreenKeyDefinition, C++ since bead oo-9ht.62
	deleted its façade, linked as their own tests link them). It stands in for the player, the universe, its GUI and game view, the resource
	manager, the script engine (its monitor and JS calls), the running script, the string
	expander, the GUI screen names and the commodity names, with the engine headers' linkage.
	The expectations were written against the Objective-C file and run on it first; they pin the
	JS-visible behaviour of the three properties and most methods (log and the monitor, the
	expanders, the screen backgrounds and overlay, the GUI colours, the extra GUI screen keys,
	autoAIForRole, pauseGame, quitGame) and a native's exception. takeSnapShot(), which reads the
	disk, is not run. Run: bash tools/check-core-tests.sh
*/

#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"
#import "OOWeakReference.h"
#import "OOColor.h"
#import "OOJSGuiScreenKeyDefinition.h"
#import "OOStringExpander.h"
#include <objc/runtime.h>
#include "OOTypes.h"
#include "OOEntityEnums.h"
#include "ooscript/JSEngine.hpp"
#include "oofnd/objc/OOException.h"
#include "oofnd/PList.hpp"
#include "oofnd/String.hpp"
#import "OODescription.h"
#import "OOConstToJSString.h"
#include "oofnd/Log.hpp"


// MARK: The classes, as far as the binding sees them ----------------------------------------------

@class GuiDisplayGen, MyOpenGLView;

/*	The player: its galaxy and screen, key binding descriptions, extra GUI screen keys and the
	equipment screen's background.
*/
@interface PlayerEntity: OOObject
{
@public
	OOGalaxyID _galaxy;
	OOGUIScreenID _screen;
	std::string _lastKeys;
	oo::Ref<OOJSGuiScreenKeyDefinition> _definition;
	oo::PList _equipBackground;
}
- (OOGalaxyID) currentGalaxyID;
- (OOGUIScreenID) guiScreen;
- (std::optional<std::string>) cxx_keyBindingDescription2:(const std::string &)binding;
- (void) cxx_clearExtraGuiScreenKeys:(OOGUIScreenID)gui key:(const std::string &)key;
- (BOOL) setExtraGuiScreenKeys:(OOGUIScreenID)gui definition:(OOJSGuiScreenKeyDefinition *)definition;
- (void) cxx_setEquipScreenBackgroundDescriptor:(const oo::PList &)descriptor;
@end

/*	The universe: time acceleration, mission text (whose lookup raises while _raise is set),
	inhabitants, the view, the GUI, screen textures by key, the game view, pause and quit.
*/
@interface Universe: OOObject
{
@public
	double _timeAcceleration;
	OOViewID _view;
	GuiDisplayGen *_gui;
	std::map<std::string, oo::PList> _screenTextures;
	int _paused;
	int _quit;
	BOOL _raise;
	BOOL _throwCxx;
}
- (double) timeAccelerationFactor;
- (void) setTimeAccelerationFactor:(double)newTimeAccelerationFactor;
- (oo::PList) cxx_missiontext;
- (std::optional<std::string>) cxx_getSystemInhabitants:(OOSystemID)sys plural:(BOOL)plural;
- (OOViewID) viewDirection;
- (GuiDisplayGen *) gui;
- (oo::PList) cxx_screenTextureDescriptorForKey:(const std::string &)key;
- (void) cxx_setScreenTextureDescriptorForKey:(const std::string &)key descriptor:(const oo::PList &)desc;
- (MyOpenGLView *) gameView;
- (void) pauseGame;
- (void) quitGame;
@end

// The GUI: a texture descriptor from JS is {name: <string>}; the backgrounds and colours it holds.
@interface GuiDisplayGen: OOObject
{
@public
	oo::PList _background;
	oo::PList _foreground;
	std::map<std::string, oo::ObjCRef<OOColor *>> _colors;
}
- (oo::PList) cxx_textureDescriptorFromJSValue:(ooscript::Value)value inContext:(ooscript::Context)context callerDescription:(const std::optional<std::string> &)callerDescription;
- (BOOL) cxx_setBackgroundTextureDescriptor:(const oo::PList &)descriptor;
- (BOOL) cxx_setForegroundTextureDescriptor:(const oo::PList &)descriptor;
- (OOColor *) cxx_colorFromSetting:(const std::optional<std::string> &)setting defaultValue:(OOColor *)def;
- (void) cxx_setGuiColorSettingFromKey:(const std::string &)key color:(OOColor *)col;
@end

@interface MyOpenGLView: OOObject
- (BOOL) cxx_snapShot:(const std::optional<std::string> &)filename;
@end

@interface ResourceManager: OOObject
+ (oo::PList) cxx_dictionaryFromFilesNamed:(const std::string &)fileName inFolder:(const std::optional<std::string> &)folderName andMerge:(BOOL)mergeFiles;
@end

// The Objective-C engine, which OOJSGuiScreenKeyDefinition.mm (linked here) still messages for its
// reset-notification observer and its JS calls; nothing more of it is needed.
@interface OOJavaScriptEngine: OOObject
+ (OOJavaScriptEngine *) sharedEngine;
@end

@interface OOJSScript: OOWeakRefObject
+ (OOJSScript *) currentlyRunningScript;
@end


#import "OOJSGlobal.h"

#include "oo_test.hpp"

#include <cstdarg>
#include <cstdint>
#include <cstring>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>


namespace {
PlayerEntity *sPlayer = nil;
Universe *sUniverse = nil;
GuiDisplayGen *sGui = nil;
}


@implementation PlayerEntity

- (OOGalaxyID) currentGalaxyID  { return _galaxy; }
- (OOGUIScreenID) guiScreen  { return _screen; }
- (std::optional<std::string>) cxx_keyBindingDescription2:(const std::string &)binding  { if (binding == "none")  return std::nullopt; return "key for " + binding; }
- (void) cxx_clearExtraGuiScreenKeys:(OOGUIScreenID)gui key:(const std::string &)key  { _lastKeys = "clear " + std::to_string(static_cast<int>(gui)) + " " + key; }
- (void) cxx_setEquipScreenBackgroundDescriptor:(const oo::PList &)descriptor  { _equipBackground = descriptor; }

- (BOOL) setExtraGuiScreenKeys:(OOGUIScreenID)gui definition:(OOJSGuiScreenKeyDefinition *)definition
{
	_lastKeys = "set " + std::to_string(static_cast<int>(gui)) + " " + definition->name().value_or("(none)") + " " + oo::DescriptionOf(definition->registerKeys());
	_definition = oo::Ref<OOJSGuiScreenKeyDefinition>(definition);
	return gui != GUI_SCREEN_SHIPYARD;	// the player refuses the shipyard here
}

@end


@implementation Universe

- (double) timeAccelerationFactor  { return _timeAcceleration; }
- (void) setTimeAccelerationFactor:(double)newTimeAccelerationFactor  { _timeAcceleration = newTimeAccelerationFactor; }
- (OOViewID) viewDirection  { return _view; }
- (GuiDisplayGen *) gui  { return _gui; }
- (MyOpenGLView *) gameView  { return nil; }
- (void) pauseGame  { _paused++; }
- (void) quitGame  { _quit++; }

- (oo::PList) cxx_missiontext
{
	if (_raise)  [OOException raise:OOInvalidArgumentException format:"missiontext %s", "boom"];
	if (_throwCxx)  throw std::runtime_error("cxx boom");
	oo::PList::Dict text;
	text["greeting"] = oo::PList(std::string("Hello [name]"));
	text["number"] = oo::PList(5.0);
	return oo::PList(std::move(text));
}

- (std::optional<std::string>) cxx_getSystemInhabitants:(OOSystemID)sys plural:(BOOL)plural
{
	(void)sys;
	return plural ? std::string("Furry Felines") : std::string("Furry Feline");
}

- (oo::PList) cxx_screenTextureDescriptorForKey:(const std::string &)key
{
	auto found = _screenTextures.find(key);
	return found != _screenTextures.end() ? found->second : oo::PList();
}

- (void) cxx_setScreenTextureDescriptorForKey:(const std::string &)key descriptor:(const oo::PList &)desc
{
	if (desc.isNull())  _screenTextures.erase(key);
	else  _screenTextures[key] = desc;
}

@end


@implementation GuiDisplayGen

- (oo::PList) cxx_textureDescriptorFromJSValue:(ooscript::Value)value inContext:(ooscript::Context)context callerDescription:(const std::optional<std::string> &)callerDescription
{
	(void)callerDescription;
	ooscript::Value name = ooscript::undefinedValue();
	if (!ooscript::isObject(value) || ooscript::isNull(value) || !ooscript::getProperty(context, ooscript::toObject(value), "name", &name) || !ooscript::isString(name))  return oo::PList();
	ooscript::String str = ooscript::valueToString(context, name);
	std::size_t length = 0;
	const ooscript::Char16 *chars = ooscript::getStringCharsAndLength(context, str, &length);
	std::string text;
	for (std::size_t i = 0; i < length; i++)  text += static_cast<char>(chars[i]);
	return oo::PList(oo::PList::Dict{ { "name", oo::PList(text) } });
}

- (BOOL) cxx_setBackgroundTextureDescriptor:(const oo::PList &)descriptor  { _background = descriptor; return !descriptor.isNull(); }
- (BOOL) cxx_setForegroundTextureDescriptor:(const oo::PList &)descriptor  { _foreground = descriptor; return !descriptor.isNull(); }

- (OOColor *) cxx_colorFromSetting:(const std::optional<std::string> &)setting defaultValue:(OOColor *)def
{
	auto found = _colors.find(setting.value_or(""));
	return found != _colors.end() ? found->second.get() : def;
}

- (void) cxx_setGuiColorSettingFromKey:(const std::string &)key color:(OOColor *)col
{
	if (col == nil)  _colors.erase(key);
	else  _colors[key] = oo::ObjCRef<OOColor *>(col);
}

@end


@implementation MyOpenGLView
- (BOOL) cxx_snapShot:(const std::optional<std::string> &)filename  { (void)filename; std::abort(); }	// never run
@end


@implementation ResourceManager

+ (oo::PList) cxx_dictionaryFromFilesNamed:(const std::string &)fileName inFolder:(const std::optional<std::string> &)folderName andMerge:(BOOL)mergeFiles
{
	if (fileName != "autoAImap.plist" || folderName != std::optional<std::string>("Config") || !mergeFiles)  return oo::PList();
	return oo::PList(oo::PList::Dict{ { "trader", oo::PList(std::string("oolite-traderAI.js")) }, { "number", oo::PList(3.0) } });
}

@end


/*	The engine, as far as log() sees it: the C++ engine's monitor member, declared with the
	engine header's signature but not its class (OOJavaScriptEngine.h pulls in the game's
	classes), the way the other stand-ins here are declared. What the monitor was sent is kept.
*/
namespace cxx {
class OOJavaScriptEngine
{
public:
	static OOJavaScriptEngine *sharedEngine();
	void sendMonitorLogMessage(const std::optional<std::string> &message, const std::optional<std::string> &messageClass, ooscript::Context context);
};
}

static std::vector<std::string> sMonitorMessages;

@implementation OOJavaScriptEngine

+ (OOJavaScriptEngine *) sharedEngine
{
	static OOJavaScriptEngine *engine = [[OOJavaScriptEngine alloc] init];
	return engine;
}

@end

cxx::OOJavaScriptEngine *cxx::OOJavaScriptEngine::sharedEngine()
{
	static cxx::OOJavaScriptEngine *engine = new cxx::OOJavaScriptEngine;
	return engine;
}

void cxx::OOJavaScriptEngine::sendMonitorLogMessage(const std::optional<std::string> &message, const std::optional<std::string> &messageClass, ooscript::Context context)
{
	(void)context;
	sMonitorMessages.push_back(messageClass.value_or("(no class)") + ": " + message.value_or("(null)"));
}


@implementation OOJSScript
+ (OOJSScript *) currentlyRunningScript  { return nil; }
@end


// MARK: What the rest of the game provides --------------------------------------------------------

// The expander: "<string>", with each override "{key=value}" after it, in key order.
std::optional<std::string> cxx_OOExpandDescriptionString(Random_Seed, const std::string &string, const oo::PList &overrides, const oo::PList &, const std::optional<std::string> &, OOExpandOptions options)
{
	std::string result = "<" + string + ">";
	if (const oo::PList::Dict *dict = overrides.getIf<oo::PList::Dict>())
	{
		for (const auto &entry : *dict)  result += "{" + entry.first + "=" + oo::DescriptionOf(entry.second) + "}";
	}
	if (options & kOOExpandBackslashN)  result += "\\n";
	return result;
}


Random_Seed OOStringExpanderDefaultRandomSeed(void)
{
	return Random_Seed{};
}


std::string cxx_CommodityDisplayNameForSymbolicName(const std::string &symbolicName)
{
	return "Name(" + symbolicName + ")";
}


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

void cxx_OOJSReportWarning(ooscript::Context, const char *format, ...)
{
	va_list args;
	va_start(args, format);
	sLastWarning = oo::str::vformat(format, args);
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


// A property list as JavaScript, as far as the binding hands one over: null, a string, a number,
// or an array or dictionary of those.
ooscript::Value OOJSValueFromPList(ooscript::Context context, const oo::PList &plist)
{
	if (const std::string *str = plist.getIf<std::string>())
	{
		ooscript::String js = ooscript::newStringCopyN(context, str->data(), str->size());
		return js != nullptr ? ooscript::stringValue(js) : ooscript::nullValue();
	}
	if (plist.isNumber())  return ooscript::numberValue(plist.doubleValue());
	if (const oo::PList::Array *array = plist.getIf<oo::PList::Array>())
	{
		std::vector<ooscript::Value> values;
		for (const oo::PList &element : *array)  values.push_back(OOJSValueFromPList(context, element));
		ooscript::Object object = ooscript::newArrayObject(context, static_cast<unsigned>(values.size()), values.data());
		return object != nullptr ? ooscript::objectValue(object) : ooscript::nullValue();
	}
	if (const oo::PList::Dict *dict = plist.getIf<oo::PList::Dict>())
	{
		ooscript::Object object = ooscript::newObject(context, nullptr, nullptr, nullptr);
		for (const auto &entry : *dict)
		{
			ooscript::Value value = OOJSValueFromPList(context, entry.second);
			ooscript::setProperty(context, object, entry.first.c_str(), &value);
		}
		return ooscript::objectValue(object);
	}
	return ooscript::nullValue();
}


// A JS value's plist form: a string, a number, an array of those, or null.
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


// An object's "keys" property, as far as the test registers keys: {keys: [names]} -> {keys: [...]}.
oo::PList cxx_OOJSPListFromJSObject(ooscript::Context context, ooscript::Object object)
{
	oo::PList::Dict dict;
	ooscript::Value value = ooscript::undefinedValue();
	if (ooscript::getProperty(context, object, "keys", &value) && !ooscript::isUndefined(value))  dict["keys"] = cxx_OOJSPListFromJSValue(context, value);
	return oo::PList(std::move(dict));
}


// A string table: an object's "name" property, if any.
oo::PList OOJSDictionaryFromStringTable(ooscript::Context context, ooscript::Value value)
{
	oo::PList::Dict dict;
	ooscript::Value name = ooscript::undefinedValue();
	if (ooscript::isObject(value) && !ooscript::isNull(value) && ooscript::getProperty(context, ooscript::toObject(value), "name", &name) && !ooscript::isUndefined(name))
	{
		dict["name"] = oo::PList(cxx_OOStringFromJSValue(context, name).value_or(""));
	}
	return oo::PList(std::move(dict));
}


ooscript::Context gOOJSMainThreadContext = nullptr;
extern const char * const kOOJavaScriptEngineWillResetNotificationName;
const char * const kOOJavaScriptEngineWillResetNotificationName = "org.aegidian.oolite OOJavaScriptEngine will reset";
PlayerEntity *gOOPlayer = nil;
Universe *gSharedUniverse = nil;


extern "C" {

PlayerEntity *OOPlayerForScripting(void)
{
	return sPlayer;
}


void OOJSReportBadPropertySelector(ooscript::Context context, ooscript::Object, ooscript::PropertyId, ooscript::PropertySpec *)
{
	cxx_OOJSReportError(context, "bad property selector");
}


void OOJSReportBadPropertyValue(ooscript::Context context, ooscript::Object, ooscript::PropertyId, ooscript::PropertySpec *, ooscript::Value)
{
	cxx_OOJSReportError(context, "bad property value");
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
	CreateOOJSGlobal(sContext, &sGlobal);
	ooscript::initStandardClasses(sContext, sGlobal);
	OOConstToJSStringInit(sContext);	// the GUI screen names, as the engine does at start-up
	SetUpOOJSGlobal(sContext, sGlobal);
	oo::log::logger().setInitialized(true);	// as OOLoggingInit() does

	sPlayer = [[PlayerEntity alloc] init];	// kept for the life of the test
	sPlayer->_galaxy = 3;
	sPlayer->_screen = GUI_SCREEN_STATUS;
	gOOPlayer = sPlayer;
	sUniverse = [[Universe alloc] init];
	sUniverse->_timeAcceleration = 1;
	sUniverse->_view = VIEW_GUI_DISPLAY;
	sGui = [[GuiDisplayGen alloc] init];
	sUniverse->_gui = sGui;
	gSharedUniverse = sUniverse;
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

OO_TEST(globalObject)
{
	SetUpContext();
	OO_CHECK_EVAL("global === this && global.global === global", "true");
	OO_CHECK_EVAL("(function () { global = 5; return global === this; }).call(this)", "true");	// read-only
	OO_CHECK_EVAL("['log', 'expandDescription', 'expandMissionText', 'displayNameForCommodity', 'randomName', 'randomInhabitantsDescription', 'setScreenBackground', 'getScreenBackgroundForKey', 'setScreenBackgroundForKey', 'setScreenOverlay', 'getGuiColorSettingForKey', 'setGuiColorSettingForKey', 'keyBindingDescription', 'setExtraGuiScreenKeys', 'clearExtraGuiScreenKeys', 'takeSnapShot', 'quitGame', 'pauseGame', 'autoAIForRole'].filter(function (f) { return typeof global[f] !== 'function'; }).join()", "");
}


OO_TEST(properties)
{
	SetUpContext();
	OO_CHECK_EVAL("galaxyNumber", "3");
	OO_CHECK_EVAL("guiScreen", "GUI_SCREEN_STATUS");
	sPlayer->_screen = GUI_SCREEN_MISSION;
	OO_CHECK_EVAL("guiScreen", "GUI_SCREEN_MISSION");
	sPlayer->_screen = GUI_SCREEN_STATUS;
	OO_CHECK_EVAL("timeAccelerationFactor", "1");
	OO_CHECK_EVAL("(function () { timeAccelerationFactor = 4; return timeAccelerationFactor; })()", "4");
	OO_CHECK_EVAL("(function () { timeAccelerationFactor = 'x'; return timeAccelerationFactor; })()", "NaN");
	sUniverse->_timeAcceleration = 1;
	OO_CHECK_EVAL("(function () { galaxyNumber = 7; return galaxyNumber; })()", "3");	// read-only
}


OO_TEST(log)
{
	SetUpContext();
	sMonitorMessages.clear();
	OO_CHECK_EVAL("log()", "undefined");
	OO_CHECK(sMonitorMessages.empty());
	OO_CHECK_EVAL("log('hello')", "undefined");
	OO_CHECK_EVAL("log(null)", "undefined");
	OO_CHECK_EVAL("log('script.debug.message', 'a', 2, null)", "undefined");
	OO_CHECK_EQ(sMonitorMessages.size(), 3u);
	if (sMonitorMessages.size() == 3)
	{
		OO_CHECK_EQ(sMonitorMessages[0], std::string("(no class): hello"));
		OO_CHECK_EQ(sMonitorMessages[1], std::string("(no class): (null)"));
		OO_CHECK_EQ(sMonitorMessages[2], std::string("(no class): a, 2, null"));
	}
}


OO_TEST(expansion)
{
	SetUpContext();
	OO_CHECK_EVAL("expandDescription('[x]')", "<[x]>");
	OO_CHECK_EVAL("expandDescription('[x]', {name: 'Bob'})", "<[x]>{name=Bob}");
	OO_CHECK_EVAL("expandDescription()", "threw: bad arguments: -.expandDescription(0) - / string");
	OO_CHECK_EVAL("expandDescription(null)", "threw: bad arguments: -.expandDescription(1) - / string");
	OO_CHECK_EVAL("expandMissionText('greeting')", "<Hello [name]>\\n");
	OO_CHECK_EVAL("expandMissionText('greeting', {name: 'Jo'})", "<Hello [name]>{name=Jo}\\n");
	OO_CHECK_EVAL("expandMissionText('number')", "<5>\\n");	// a number's text
	OO_CHECK_EVAL("expandMissionText('missing')", "null");
	OO_CHECK_EVAL("expandMissionText()", "threw: bad arguments: -.expandMissionText(0) - / string");
	OO_CHECK_EVAL("displayNameForCommodity('food')", "Name(food)");
	OO_CHECK_EVAL("displayNameForCommodity()", "threw: bad arguments: -.displayNameForCommodity(0) - / string");
	OO_CHECK_EVAL("keyBindingDescription('key_launch')", "key for key_launch");
	OO_CHECK_EVAL("keyBindingDescription('none')", "null");
	OO_CHECK_EVAL("keyBindingDescription()", "threw: bad arguments: -.keyBindingDescription(0) - / string");
	OO_CHECK_EVAL("randomName()", "<%N>");
	OO_CHECK_EVAL("randomInhabitantsDescription()", "Furry Felines");
	OO_CHECK_EVAL("randomInhabitantsDescription(false)", "Furry Feline");
	OO_CHECK_EVAL("autoAIForRole('trader')", "oolite-traderAI.js");
	OO_CHECK_EVAL("autoAIForRole('number')", "3");
	OO_CHECK_EVAL("autoAIForRole('pirate')", "null");
	OO_CHECK_EVAL("autoAIForRole()", "threw: bad arguments: -.autoAIForRole(0) - / string");
}


OO_TEST(screens)
{
	SetUpContext();
	sLastWarning.clear();
	OO_CHECK_EVAL("setScreenBackground({name: 'bg.png'})", "true");
	OO_CHECK_EQ(oo::DescriptionOf(sGui->_background), oo::DescriptionOf(oo::PList(oo::PList::Dict{ { "name", oo::PList(std::string("bg.png")) } })));
	OO_CHECK(sPlayer->_equipBackground.isNull());
	sPlayer->_screen = GUI_SCREEN_EQUIP_SHIP;
	OO_CHECK_EVAL("setScreenBackground({name: 'eq.png'})", "true");
	OO_CHECK(!sPlayer->_equipBackground.isNull());
	sPlayer->_screen = GUI_SCREEN_STATUS;
	OO_CHECK_EVAL("setScreenBackground(null)", "false");
	OO_CHECK_EVAL("setScreenBackground()", "false");
	OO_CHECK_EQ(sLastWarning, std::string("Usage error: setScreenBackground() called with no arguments. Treating as setScreenBackground(null). This call may fail in a future version of Oolite."));
	OO_CHECK_EVAL("setScreenBackground(undefined)", "threw: bad arguments: -.setScreenBackground(1) - / GUI texture descriptor");
	OO_CHECK_EVAL("setScreenOverlay({name: 'fg.png'})", "true");
	OO_CHECK(!sGui->_foreground.isNull());
	OO_CHECK_EVAL("setScreenOverlay(undefined)", "threw: bad arguments: -.setScreenOverlay(1) - / GUI texture descriptor");
	// Not on a GUI view: nothing is set.
	sUniverse->_view = VIEW_FORWARD;
	sGui->_foreground = oo::PList();
	OO_CHECK_EVAL("setScreenOverlay({name: 'fg.png'})", "false");
	OO_CHECK(sGui->_foreground.isNull());
	sUniverse->_view = VIEW_GUI_DISPLAY;
	// Backgrounds by key.
	OO_CHECK_EVAL("setScreenBackgroundForKey('long_range_chart', {name: 'lrc.png'})", "true");
	OO_CHECK_EVAL("getScreenBackgroundForKey('long_range_chart').name", "lrc.png");
	OO_CHECK_EVAL("getScreenBackgroundForKey('other')", "null");
	OO_CHECK_EVAL("setScreenBackgroundForKey('long_range_chart', null)", "true");
	OO_CHECK_EVAL("getScreenBackgroundForKey('long_range_chart')", "null");
	OO_CHECK_EVAL("setScreenBackgroundForKey('k')", "threw: bad arguments: -.setScreenBackgroundDefault(0) - / missing arguments");
	OO_CHECK_EVAL("setScreenBackgroundForKey('', {})", "threw: bad arguments: -.setScreenBackgroundDefault(0) - / key");
	OO_CHECK_EVAL("getScreenBackgroundForKey()", "threw: bad arguments: -.getScreenBackgroundDefault(0) - / missing arguments");
	OO_CHECK_EVAL("getScreenBackgroundForKey('')", "threw: bad arguments: -.getScreenBackgroundDefault(0) - / key");
}


OO_TEST(guiColors)
{
	SetUpContext();
	OO_CHECK_EVAL("getGuiColorSettingForKey('screen_title_color')", "null");
	OO_CHECK_EVAL("setGuiColorSettingForKey('screen_title_color', [0, 1, 0])", "true");
	OO_CHECK_EVAL("getGuiColorSettingForKey('screen_title_color')", "0,1,0,1");
	OO_CHECK_EVAL("setGuiColorSettingForKey('screen_title_color', 'redColor')", "true");
	OO_CHECK_EVAL("getGuiColorSettingForKey('screen_title_color')", "1,0,0,1");
	OO_CHECK_EVAL("setGuiColorSettingForKey('screen_title_color', null)", "true");
	OO_CHECK_EVAL("getGuiColorSettingForKey('screen_title_color')", "null");
	OO_CHECK_EVAL("setGuiColorSettingForKey('screen_title_color', 'not a colour')", "threw: bad arguments: -.setGuiColorForKey(1) - / color descriptor");
	OO_CHECK_EVAL("setGuiColorSettingForKey('screen_title', [0, 1, 0])", "threw: bad arguments: -.setGuiColorForKey(0) - / valid color key setting");
	OO_CHECK_EVAL("setGuiColorSettingForKey('screen_title_color')", "threw: bad arguments: -.setGuiColorForKey(0) - / missing arguments");
	OO_CHECK_EVAL("getGuiColorSettingForKey('screen_title')", "threw: bad arguments: -.getGuiColorForKey(0) - / valid color key setting");
	OO_CHECK_EVAL("getGuiColorSettingForKey()", "threw: bad arguments: -.getGuiColorForKey(0) - / missing arguments");
}


OO_TEST(extraGuiScreenKeys)
{
	SetUpContext();
	OO_CHECK_EVAL("setExtraGuiScreenKeys('myKeys', {guiScreen: 'GUI_SCREEN_STATUS', registerKeys: {keys: ['a', 'b']}, callback: function () {}})", "true");
	OO_CHECK_EQ(sPlayer->_lastKeys, std::string("set ") + std::to_string(static_cast<int>(GUI_SCREEN_STATUS)) + " myKeys " + oo::DescriptionOf(oo::PList(oo::PList::Dict{ { "keys", oo::PList(oo::PList::Array{ oo::PList(std::string("a")), oo::PList(std::string("b")) }) } })));
	OO_CHECK(sPlayer->_definition.get() != nullptr && ooscript::isObject(sPlayer->_definition->callback()) && sPlayer->_definition->callbackThis() == nullptr);
	OO_CHECK_EVAL("setExtraGuiScreenKeys('myKeys', {guiScreen: 'GUI_SCREEN_STATUS', registerKeys: null, callback: function () {}, cbThis: global})", "true");
	OO_CHECK(sPlayer->_definition->callbackThis() == sGlobal);
	OO_CHECK_EVAL("setExtraGuiScreenKeys('myKeys', {guiScreen: 'GUI_SCREEN_SHIPYARD', registerKeys: {}, callback: function () {}})", "false");
	OO_CHECK_EVAL("setExtraGuiScreenKeys('k')", "threw: bad arguments: global.setExtraGuiScreenKeys(2) - / key, definition: definition is not a valid dictionary.");
	OO_CHECK_EVAL("setExtraGuiScreenKeys()", "threw: bad arguments: -.setExtraGuiScreenKeys(0) - / key, definition");
	OO_CHECK_EVAL("setExtraGuiScreenKeys('k', {})", "threw: bad arguments: global.setExtraGuiScreenKeys(2) - / key, definition: must have a 'guiScreen' property.");
	OO_CHECK_EVAL("setExtraGuiScreenKeys('k', {guiScreen: 'GUI_SCREEN_SAVE'})", "threw: bad arguments: global.setExtraGuiScreenKeys(2) - / key, definition: 'guiScreen' property must be a permitted and valid GUI_SCREEN idenfifier.");
	OO_CHECK_EVAL("setExtraGuiScreenKeys('k', {guiScreen: 'GUI_SCREEN_STATUS'})", "threw: bad arguments: global.setExtraGuiScreenKeys(2) - / key, definition: must have a 'registerKeys' property.");
	OO_CHECK_EVAL("setExtraGuiScreenKeys('k', {guiScreen: 'GUI_SCREEN_STATUS', registerKeys: 5})", "threw: bad arguments: global.setExtraGuiScreenKeys(2) - / key, definition: registerKeys is not a valid dictionary.");
	OO_CHECK_EVAL("setExtraGuiScreenKeys('k', {guiScreen: 'GUI_SCREEN_STATUS', registerKeys: {}})", "threw: bad arguments: global.setExtraGuiScreenKeys(2) - / key, definition; must have a 'callback' property.");
	OO_CHECK_EVAL("setExtraGuiScreenKeys('k', {guiScreen: 'GUI_SCREEN_STATUS', registerKeys: {}, callback: 5})", "threw: bad arguments: global.setExtraGuiScreenKeys(2) - / key, definition; 'callback' property must be a function.");
	OO_CHECK_EVAL("clearExtraGuiScreenKeys('myKeys', 'GUI_SCREEN_STATUS')", "true");
	OO_CHECK_EQ(sPlayer->_lastKeys, "clear " + std::to_string(static_cast<int>(GUI_SCREEN_STATUS)) + " myKeys");
	OO_CHECK_EVAL("clearExtraGuiScreenKeys('myKeys', 'NOT_A_SCREEN')", "threw: bad arguments: -.clearExtraGuiScreenKeys(0) - / guiScreen invalid entry");
	OO_CHECK_EVAL("clearExtraGuiScreenKeys('', 'GUI_SCREEN_STATUS')", "threw: bad arguments: -.clearExtraGuiScreenKeys(1) - / key");
	OO_CHECK_EVAL("clearExtraGuiScreenKeys('k')", "threw: bad arguments: -.setExtraGuiScreenKeys(0) - / missing arguments");
}


OO_TEST(pauseAndQuit)
{
	SetUpContext();
	sUniverse->_paused = 0;
	OO_CHECK_EVAL("pauseGame()", "true");
	OO_CHECK_EQ(sUniverse->_paused, 1);
	sPlayer->_screen = GUI_SCREEN_MISSION;
	OO_CHECK_EVAL("pauseGame()", "false");
	OO_CHECK_EQ(sUniverse->_paused, 1);
	sPlayer->_screen = GUI_SCREEN_STATUS;
	OO_CHECK_EVAL("quitGame()", "true");
	OO_CHECK_EQ(sUniverse->_quit, 1);
	OO_CHECK_EVAL("takeSnapShot('bad name!')", "threw: bad arguments: -.takeSnapShot(1) - / alphanumeric string");
}


OO_TEST(nativeExceptions)
{
	SetUpContext();
	sUniverse->_raise = YES;
	OO_CHECK_EVAL("expandMissionText('greeting')", "threw: Native exception: missiontext boom");
	sUniverse->_raise = NO;
	sUniverse->_throwCxx = YES;
	OO_CHECK_EVAL("expandMissionText('greeting')", "threw: Native exception: cxx boom");
	sUniverse->_throwCxx = NO;
	OO_CHECK_EVAL("expandMissionText('greeting')", "<Hello [name]>\\n");
	OO_CHECK_EQ(sLimiterPauses, 0);
	OO_CHECK_EQ(sProfileDepth, 0);
	OO_CHECK(ooscript::isInRequest(sContext));
}


OO_TEST_MAIN()
