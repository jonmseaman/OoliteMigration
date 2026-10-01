/*	test_OOJSSound.mm
	Unit tests for the Sound JS binding (src/Core/Scripting/OOJSSound.h/.mm) and its OOSound
	category (OOJSSound+ObjCBridge.mm): bead oo-crq2, converted the way bead oo-ppc converted
	OOJSVector (proposed ADR-0056 amendments oo-ppc and oo-ykoy).

	As test_OOJSWormhole.mm does (amendment oo-ykoy, item 4), it runs the JS class in a real
	context on the game's own façade backend (ooscript/JSEngine_quickjs.cpp), links the game's own
	objects for the binding, its bridge and the engine's exception translator
	(OOJSEngineNativeWrappers.mm), and stands in for the classes the binding messages (OOSound,
	ResourceManager, OOMusicController, OOSoundSource and the player answer only the selectors the
	binding sends) and for the engine functions it links against, with the engine headers' linkage.
	The expectations were written against the Objective-C file and run on it first; they pin the
	JS-visible behaviour (name, toString(), the four static methods and their errors,
	SoundFromJSValue() for a Sound and for a name, a native's exception) and what the category
	answers the engine. Run: bash tools/check-core-tests.sh
*/

#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"
#include <objc/runtime.h>
#include "OOTypes.h"
#include "ooscript/JSEngine.hpp"
#include "oofnd/objc/OOException.h"
#include "oofnd/PList.hpp"
#include "oofnd/String.hpp"


// MARK: The classes, as far as the binding sees them ----------------------------------------------

@class PlayerEntity;

// The player's status, as Entity.h defines it.
#undef ENTRY
#define ENTRY(label, value) label = value,
typedef enum OOEntityStatus
{
	#include "OOEntityStatus.tbl"
} OOEntityStatus;
#undef ENTRY

/*	A sound named "raise" raises from -cxx_name, one named "throw" throws a C++ exception, so the
	test sees what an exception under a native becomes.
*/
@interface OOSound: OOObject
{
@public
	std::optional<std::string> _name;
}
+ (id) cxx_soundWithCustomSoundKey:(const std::string &)key;
- (std::optional<std::string>) cxx_name;
@end

@interface OOSoundSource: OOObject
@end

@interface ResourceManager: OOObject
+ (OOSound *) cxx_ooSoundNamed:(const std::string &)fileName inFolder:(const std::optional<std::string> &)folderName;
@end

@interface OOMusicController: OOObject
{
@public
	std::optional<std::string> _playing;
	BOOL _loop;
	float _gain;
	int _stops;
}
+ (OOMusicController *) sharedController;
- (void) playMusicNamed:(const std::string &)name loop:(BOOL)loop gain:(float)gain;
- (void) stop;
- (OOSoundSource *) soundSource;
- (std::optional<std::string>) playingMusic;
@end

@interface FakePlayer: OOObject
{
@public
	OOEntityStatus _status;
}
- (OOEntityStatus) status;
@end

@interface OOSound (OOJavaScriptExtentions)
- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context;
- (std::optional<std::string>) cxx_oo_jsDescription;
- (std::optional<std::string>) cxx_oo_jsClassName;
@end


#import "OOJSSound.h"

#include "oo_test.hpp"

#include <cmath>
#include <cstdarg>
#include <cstring>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>


namespace {
std::vector<OOSound *> sLoaded;
OOMusicController *sMusic = nil;
OOSoundSource *sMusicSource = nil;
} // namespace


@implementation OOSound

+ (id) cxx_soundWithCustomSoundKey:(const std::string &)key
{
	OOSound *sound = [[[OOSound alloc] init] autorelease];
	sound->_name = "custom:" + key;
	sLoaded.push_back([sound retain]);
	return sound;
}


- (std::optional<std::string>) cxx_name
{
	if (_name == "raise")  [OOException raise:OOInvalidArgumentException format:"name %s", "boom"];
	if (_name == "throw")  throw std::runtime_error("cxx boom");
	return _name;
}

@end


@implementation OOSoundSource
@end


@implementation ResourceManager

+ (OOSound *) cxx_ooSoundNamed:(const std::string &)fileName inFolder:(const std::optional<std::string> &)folderName
{
	if (fileName == "missing.ogg")  return nil;
	OOSound *sound = [[[OOSound alloc] init] autorelease];
	sound->_name = (fileName == "raise" || fileName == "throw") ? fileName : folderName.value_or("") + "/" + fileName;
	sLoaded.push_back([sound retain]);
	return sound;
}

@end


@implementation OOMusicController

+ (OOMusicController *) sharedController  { return sMusic; }
- (OOSoundSource *) soundSource  { return sMusicSource; }
- (std::optional<std::string>) playingMusic  { return _playing; }
- (void) stop  { _playing = std::nullopt; _stops++; }

- (void) playMusicNamed:(const std::string &)name loop:(BOOL)loop gain:(float)gain
{
	_playing = name;
	_loop = loop;
	_gain = gain;
}

@end


@implementation FakePlayer

- (OOEntityStatus) status  { return _status; }

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


ooscript::Value OOJSValueFromPList(ooscript::Context context, const oo::PList &plist)
{
	const std::string *str = plist.getIf<std::string>();
	ooscript::String js = str != nullptr ? ooscript::newStringCopyN(context, str->data(), str->size()) : nullptr;
	return js != nullptr ? ooscript::stringValue(js) : ooscript::nullValue();
}


BOOL cxx_OOJSArgumentListGetNumber(ooscript::Context context, const std::optional<std::string> &scriptClass, const std::optional<std::string> &function, unsigned argc, ooscript::Value *argv, double *outNumber, unsigned *outConsumed)
{
	if (argc > 0 && ooscript::valueToNumber(context, argv[0], outNumber) && !std::isnan(*outNumber))
	{
		if (outConsumed != NULL)  *outConsumed = 1;
		return YES;
	}
	cxx_OOJSReportBadArguments(context, scriptClass, function, argc, argv, "Expected number, got", std::nullopt);
	return NO;
}


namespace {
std::map<ooscript::ClassDef *, int> sConverters;
} // namespace

PlayerEntity *gOOPlayer = nil;


extern "C" {

void OOJSReportBadPropertySelector(ooscript::Context context, ooscript::Object, ooscript::PropertyId, ooscript::PropertySpec *)
{
	cxx_OOJSReportError(context, "bad property selector");
}


void OOJSRegisterObjectConverter(ooscript::ClassDef *theClass, oo::PList (*)(ooscript::Context, ooscript::Object))
{
	sConverters[theClass]++;
}


BOOL OOJSIsSubclass(ooscript::ClassDef *putativeSubclass, ooscript::ClassDef *superclass)
{
	return putativeSubclass == superclass;
}


// The engine's object getter: the JS class must be the required one, and the private slot holds
// the object itself.
BOOL OOJSObjectGetterImplPRIVATE(ooscript::Context context, ooscript::Object object, ooscript::ClassDef *requiredJSClass, Class requiredObjCClass, const char *, id *outObject)
{
	ooscript::ClassDef *actualClass = const_cast<ooscript::ClassDef *>(ooscript::getObjectClass(context, object));
	if (!OOJSIsSubclass(actualClass, requiredJSClass))
	{
		cxx_OOJSReportError(context, "Native method expected %s, got %s.", requiredJSClass->name, cxx_OOStringFromJSValue(context, ooscript::objectValue(object)).value_or("(null)").c_str());
		return NO;
	}
	*outObject = (id)ooscript::getPrivate(context, object);
	if (*outObject != nil && ![*outObject isKindOfClass:requiredObjCClass])
	{
		*outObject = nil;
		return NO;
	}
	return YES;
}


// An object's JS value, as the engine gives it: its category's -oo_jsValueInContext: for a sound,
// a string naming the class for anything else here.
ooscript::Value OOJSValueFromNativeObject(ooscript::Context context, id object)
{
	if (object == nil)  return ooscript::nullValue();
	if ([object isKindOfClass:[OOSound class]])  return [(OOSound *)object oo_jsValueInContext:context];
	std::string name = std::string("native ") + class_getName([object class]);
	return ooscript::stringValue(ooscript::newStringCopyN(context, name.data(), name.size()));
}


id OOJSNativeObjectOfClassFromJSValue(ooscript::Context context, ooscript::Value value, Class requiredClass)
{
	if (!ooscript::isObject(value) || ooscript::toObject(value) == nullptr)  return nil;
	id object = (id)ooscript::getPrivate(context, ooscript::toObject(value));
	return [object isKindOfClass:requiredClass] ? object : nil;
}


bool OOJSObjectWrapperToString(ooscript::Context context, ooscript::CallArgs &args)
{
	id object = (id)ooscript::getPrivate(context, args.thisObject());
	std::optional<std::string> description;
	if ([object isKindOfClass:[OOSound class]])  description = [(OOSound *)object cxx_oo_jsDescription];
	std::string text = description.value_or("[object]");
	args.setRval(ooscript::stringValue(ooscript::newStringCopyN(context, text.data(), text.size())));
	return true;
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
FakePlayer *sPlayer = nil;


void SetUpContext()
{
	if (sContext != nullptr)  return;
	sRuntime = ooscript::newRuntime(8u * 1024u * 1024u);
	sContext = ooscript::newContext(sRuntime, 8192);
	ooscript::beginRequest(sContext);
	sGlobal = ooscript::getGlobalObject(sContext);
	ooscript::initStandardClasses(sContext, sGlobal);
	InitOOJSSound(sContext, sGlobal);

	sPlayer = [[FakePlayer alloc] init];	// kept for the life of the test
	sPlayer->_status = STATUS_IN_FLIGHT;
	gOOPlayer = (PlayerEntity *)sPlayer;
	sMusic = [[OOMusicController alloc] init];
	sMusicSource = [[OOSoundSource alloc] init];
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


std::optional<std::string> NameOf(OOSound *sound)
{
	return sound != nil ? sound->_name : std::optional<std::string>("<nil>");
}

}	// namespace


// MARK: Tests -------------------------------------------------------------------------------------

OO_TEST(registration)
{
	SetUpContext();
	OO_CHECK_EVAL("typeof Sound", "function");
	OO_CHECK_EVAL("new Sound()", "threw: unconstructable");
	OO_CHECK_EQ(sConverters.size(), 1u);
	OOSound *sound = [[[OOSound alloc] init] autorelease];
	sound->_name = "a.ogg";
	OO_CHECK([sound cxx_oo_jsClassName] == std::optional<std::string>("Sound"));
	OO_CHECK([sound cxx_oo_jsDescription] == std::optional<std::string>("[Sound \"a.ogg\"]"));
	sound->_name = std::nullopt;
	OO_CHECK([sound cxx_oo_jsDescription] == std::optional<std::string>("[Sound \"(null)\"]"));
	// -oo_jsValueInContext: makes a new Sound object each time, holding the sound retained.
	NSUInteger before = [sound retainCount];
	ooscript::Value a = [sound oo_jsValueInContext:sContext];
	ooscript::Value b = [sound oo_jsValueInContext:sContext];
	OO_CHECK(ooscript::isObject(a) && ooscript::isObject(b) && ooscript::toObject(a) != ooscript::toObject(b));
	OO_CHECK(ooscript::getPrivate(sContext, ooscript::toObject(a)) == sound);
	OO_CHECK_EQ([sound retainCount], before + 2);
}


OO_TEST(load)
{
	OO_CHECK_EVAL("Sound.load('bang.ogg').name", "Sounds/bang.ogg");
	OO_CHECK_EVAL("Sound.load('[custom-key]').name", "custom:[custom-key]");
	OO_CHECK_EVAL("Sound.load('bang.ogg') instanceof Sound", "true");
	OO_CHECK_EVAL("String(Sound.load('bang.ogg'))", "[Sound \"Sounds/bang.ogg\"]");
	OO_CHECK_EVAL("Sound.load('missing.ogg')", "null");
	OO_CHECK_EVAL("Sound.load()", "threw: bad arguments: Sound.load (0): ; expected string");
	OO_CHECK_EVAL("Sound.load(null)", "threw: bad arguments: Sound.load (1): ; expected string");
	OO_CHECK_EQ(sLimiterPauses, 0);
}


OO_TEST(music)
{
	SetUpContext();
	OO_CHECK_EVAL("Sound.musicSoundSource()", "native OOSoundSource");
	OO_CHECK_EVAL("Sound.playMusic('theme.ogg')", "undefined");
	OO_CHECK(sMusic->_playing == std::optional<std::string>("theme.ogg") && !sMusic->_loop && sMusic->_gain == 1.0f);
	OO_CHECK_EVAL("Sound.playMusic('loop.ogg', true, 0.5)", "undefined");
	OO_CHECK(sMusic->_playing == std::optional<std::string>("loop.ogg") && sMusic->_loop && sMusic->_gain == 0.5f);
	OO_CHECK_EVAL("Sound.playMusic('x.ogg', true, 'loud')", "threw: bad arguments: Sound.playMusic (1): ; expected float");
	OO_CHECK_EVAL("Sound.playMusic()", "threw: bad arguments: Sound.playMusic (0): ; expected string");
	int stops = sMusic->_stops;
	OO_CHECK_EVAL("Sound.stopMusic('other.ogg')", "undefined");	// not the one playing
	OO_CHECK_EQ(sMusic->_stops, stops);
	OO_CHECK_EVAL("Sound.stopMusic('loop.ogg')", "undefined");
	OO_CHECK_EQ(sMusic->_stops, stops + 1);
	OO_CHECK_EVAL("Sound.stopMusic()", "undefined");
	OO_CHECK_EQ(sMusic->_stops, stops + 2);
	OO_CHECK_EVAL("Sound.stopMusic(null)", "threw: bad arguments: Sound.stopMusic (1): ; expected string or no argument");
	OO_CHECK_EQ(sLimiterPauses, 0);
}


OO_TEST(soundFromJSValue)
{
	SetUpContext();
	ooscript::Value value = ooscript::undefinedValue();
	ooscript::String name = ooscript::newStringCopyN(sContext, "ping.ogg", 8);
	value = ooscript::stringValue(name);
	OO_CHECK(NameOf(SoundFromJSValue(sContext, value)) == std::optional<std::string>("Sounds/ping.ogg"));
	OO_CHECK_EQ(sLimiterPauses, 1);	// a named sound pauses the time limiter and returns without resuming it
	sLimiterPauses = 0;
	OOSound *sound = [[[OOSound alloc] init] autorelease];
	sound->_name = "object.ogg";
	value = [sound oo_jsValueInContext:sContext];
	OO_CHECK(SoundFromJSValue(sContext, value) == sound);
	sLimiterPauses = 0;
	// At the start screen a name is not looked up: a string is not a Sound object.
	sPlayer->_status = STATUS_START_GAME;
	value = ooscript::stringValue(name);
	OO_CHECK(SoundFromJSValue(sContext, value) == nil);
	sPlayer->_status = STATUS_IN_FLIGHT;
	sLimiterPauses = 0;
}


OO_TEST(nativeExceptions)
{
	SetUpContext();
	// The property getter is a native (OOJS_NATIVE_ENTER): a raise from the sound is a JS error,
	// and so is a C++ exception.
	OO_CHECK_EVAL("Sound.load('raise').name", "threw: Native exception: name boom");
	OO_CHECK_EVAL("Sound.load('throw').name", "threw: Native exception: cxx boom");
	OO_CHECK_EVAL("Sound.load('fine').name", "Sounds/fine");
	OO_CHECK_EQ(sLimiterPauses, 0);
	OO_CHECK_EQ(sProfileDepth, 0);
	OO_CHECK(ooscript::isInRequest(sContext));
}


OO_TEST_MAIN()
