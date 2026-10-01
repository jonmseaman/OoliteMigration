/*	test_OOJSSoundSource.mm
	Unit tests for the SoundSource JS binding (src/Core/Scripting/OOJSSoundSource.h/.mm) and its
	OOSoundSource category (OOJSSoundSource+ObjCBridge.mm): bead oo-cib0, converted the way bead
	oo-ppc converted OOJSVector (proposed ADR-0056 amendments oo-ppc and oo-ykoy).

	As test_OOJSWormhole.mm does (amendment oo-ykoy, item 4), it runs the JS class in a real
	context on the game's own façade backend (ooscript/JSEngine_quickjs.cpp), links the game's own
	objects for the binding, its bridge and the engine's exception translator
	(OOJSEngineNativeWrappers.mm), and stands in for the classes the binding messages (OOSoundSource
	and OOSound answer only the selectors the binding sends), for the Sound and Vector3D
	conversions (a vector is the array [x, y, z] here) and for the engine functions it links
	against, with the engine headers' linkage. The expectations were written against the
	Objective-C file and run on it first; they pin the JS-visible behaviour (construction, the seven
	properties and their clamps, play(), stop(), playOrRepeat(), a native's exception) and what the
	category answers the engine. Run: bash tools/check-core-tests.sh
*/

#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"
#include <objc/runtime.h>
#include "OOMaths.h"
#include "ooscript/JSEngine.hpp"
#include "oofnd/objc/OOException.h"
#include "oofnd/PList.hpp"
#include "oofnd/String.hpp"


// MARK: The classes, as far as the binding sees them ----------------------------------------------

@interface OOSound: OOObject
{
@public
	std::string _name;
}
@end

/*	A source whose gain is 0.99 raises from -gain, one whose gain is 0.98 throws a C++ exception,
	so the test sees what an exception under a native becomes.
*/
@interface OOSoundSource: OOObject
{
@public
	OOSound *_sound;
	BOOL _loop;
	uint8_t _repeatCount;
	BOOL _playing;
	BOOL _positional;
	Vector _position;
	float _gain;
	int _plays;
	int _playOrRepeats;
	int _stops;
}
- (OOSound *) sound;
- (void) setSound:(OOSound *)inSound;
- (BOOL) loop;
- (void) setLoop:(BOOL)inLoop;
- (uint8_t) repeatCount;
- (void) setRepeatCount:(uint8_t)inCount;
- (BOOL) isPlaying;
- (void) play;
- (void) playOrRepeat;
- (void) stop;
- (void) setPositional:(BOOL)inPositional;
- (BOOL) positional;
- (void) setPosition:(Vector)inPosition;
- (Vector) position;
- (void) setGain:(float)gain;
- (float) gain;
@end

@interface OOSoundSource (OOJavaScriptExtentions)
- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context;
- (std::optional<std::string>) cxx_oo_jsClassName;
@end


#import "OOJSSoundSource.h"

#include "oo_test.hpp"

#include <cstdarg>
#include <cstring>
#include <map>
#include <stdexcept>
#include <string>


@implementation OOSound
@end


@implementation OOSoundSource

- (OOSound *) sound  { return _sound; }
- (void) setSound:(OOSound *)inSound  { [_sound release]; _sound = [inSound retain]; }
- (BOOL) loop  { return _loop; }
- (void) setLoop:(BOOL)inLoop  { _loop = inLoop; }
- (uint8_t) repeatCount  { return _repeatCount; }
- (void) setRepeatCount:(uint8_t)inCount  { _repeatCount = inCount; }
- (BOOL) isPlaying  { return _playing; }
- (void) play  { _plays++; _playing = YES; }
- (void) playOrRepeat  { _playOrRepeats++; _playing = YES; }
- (void) stop  { _stops++; _playing = NO; }
- (void) setPositional:(BOOL)inPositional  { _positional = inPositional; }
- (BOOL) positional  { return _positional; }
- (void) setPosition:(Vector)inPosition  { _position = inPosition; }
- (Vector) position  { return _position; }
- (void) setGain:(float)gain  { _gain = gain; }

- (float) gain
{
	if (_gain == 0.99f)  [OOException raise:OOInvalidArgumentException format:"gain %s", "boom"];
	if (_gain == 0.98f)  throw std::runtime_error("cxx boom");
	return _gain;
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
std::map<ooscript::ClassDef *, int> sConverters;
ooscript::ClassDef sFakeSoundClass = { "Sound", ooscript::ClassFlag::HasPrivate };
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


// An object's JS value, as the engine gives it: its category's -oo_jsValueInContext: for a sound
// source, a JS Sound holding the sound for a sound.
ooscript::Value OOJSValueFromNativeObject(ooscript::Context context, id object)
{
	if (object == nil)  return ooscript::nullValue();
	if ([object isKindOfClass:[OOSoundSource class]])  return [(OOSoundSource *)object oo_jsValueInContext:context];
	ooscript::Object sound = ooscript::newObject(context, &sFakeSoundClass, nullptr, nullptr);
	if (sound == nullptr || !ooscript::setPrivate(context, sound, [object retain]))  return ooscript::nullValue();
	return ooscript::objectValue(sound);
}


// A JS Sound's sound, or nil for anything else (a name is not looked up here).
OOSound *SoundFromJSValue(ooscript::Context context, ooscript::Value value)
{
	if (!ooscript::isObject(value) || ooscript::toObject(value) == nullptr)  return nil;
	if (ooscript::getObjectClass(context, ooscript::toObject(value)) != &sFakeSoundClass)  return nil;
	return (OOSound *)ooscript::getPrivate(context, ooscript::toObject(value));
}


bool OOJSObjectWrapperToString(ooscript::Context context, ooscript::CallArgs &args)
{
	std::string text = "[SoundSource]";
	args.setRval(ooscript::stringValue(ooscript::newStringCopyN(context, text.data(), text.size())));
	return true;
}


void OOJSObjectWrapperFinalize(ooscript::Context, ooscript::Object)
{
}


// A vector is the array [x, y, z] here: enough to see what the binding hands over and takes.
bool VectorToJSValue(ooscript::Context context, Vector vector, ooscript::Value *outValue)
{
	ooscript::Value parts[3] = { ooscript::numberValue(vector.x), ooscript::numberValue(vector.y), ooscript::numberValue(vector.z) };
	ooscript::Object array = ooscript::newArrayObject(context, 3, parts);
	if (array == nullptr)  return false;
	*outValue = ooscript::objectValue(array);
	return true;
}


bool JSValueToVector(ooscript::Context context, ooscript::Value value, Vector *outVector)
{
	double v[3] = {};
	ooscript::Value element;
	if (!ooscript::isObject(value) || !ooscript::isArrayObject(context, ooscript::toObject(value)))  return false;
	for (int i = 0; i < 3; i++)
	{
		if (!ooscript::getElement(context, ooscript::toObject(value), i, &element) || !ooscript::valueToNumber(context, element, &v[i]))  return false;
	}
	*outVector = make_vector(v[0], v[1], v[2]);
	return true;
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
OOSoundSource *sSource = nil;
OOSound *sSound = nil;


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
	ooscript::initClass(sContext, sGlobal, nullptr, &sFakeSoundClass, nullptr, 0, nullptr, nullptr, nullptr, nullptr);
	InitOOJSSoundSource(sContext, sGlobal);

	sSound = [[OOSound alloc] init];	// kept for the life of the test
	sSound->_name = "ping";
	sSource = [[OOSoundSource alloc] init];
	sSource->_sound = [sSound retain];
	sSource->_repeatCount = 1;
	sSource->_position = make_vector(1, 2, 3);
	sSource->_gain = 0.5f;
	Define("source", [sSource oo_jsValueInContext:sContext]);
	Define("aSound", OOJSValueFromNativeObject(sContext, sSound));
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
	OO_CHECK_EVAL("typeof SoundSource", "function");
	OO_CHECK_EQ(sConverters.size(), 1u);
	OO_CHECK([sSource cxx_oo_jsClassName] == std::optional<std::string>("SoundSource"));
	// -oo_jsValueInContext: makes a new SoundSource object each time, holding the source retained.
	NSUInteger before = [sSource retainCount];
	ooscript::Value a = [sSource oo_jsValueInContext:sContext];
	ooscript::Value b = [sSource oo_jsValueInContext:sContext];
	OO_CHECK(ooscript::isObject(a) && ooscript::isObject(b) && ooscript::toObject(a) != ooscript::toObject(b));
	OO_CHECK(ooscript::getPrivate(sContext, ooscript::toObject(a)) == sSource);
	OO_CHECK_EQ([sSource retainCount], before + 2);
	OO_CHECK_EVAL("source instanceof SoundSource", "true");
	OO_CHECK_EVAL("String(source)", "[SoundSource]");
}


OO_TEST(construction)
{
	OO_CHECK_EVAL("new SoundSource() instanceof SoundSource", "true");
	OO_CHECK_EVAL("new SoundSource().volume", "0");
	OO_CHECK_EVAL("new SoundSource().sound", "null");
	OO_CHECK_EVAL("SoundSource()", "threw: SoundSource() cannot be called as a function, it must be used as a constructor (as in new SoundSource()).");
}


OO_TEST(properties)
{
	OO_CHECK_EVAL("source.isPlaying", "false");
	OO_CHECK_EVAL("source.loop", "false");
	OO_CHECK_EVAL("source.position", "1,2,3");
	OO_CHECK_EVAL("source.positional", "false");
	OO_CHECK_EVAL("source.repeatCount", "1");
	OO_CHECK_EVAL("source.volume", "0.5");
	OO_CHECK_EVAL("source.sound === undefined", "false");
	OO_CHECK_EVAL("Object.keys(SoundSource.prototype).join()", "isPlaying,loop,position,positional,repeatCount,sound,volume");
}


OO_TEST(setters)
{
	SetUpContext();
	OO_CHECK_EVAL("(function () { source.loop = 1; return source.loop; })()", "true");
	OO_CHECK_EVAL("(function () { source.positional = 'y'; return source.positional; })()", "true");
	OO_CHECK_EVAL("(function () { source.position = [4, 5, 6]; return source.position; })()", "4,5,6");
	OO_CHECK_EVAL("(function () { source.position = 'here'; return source.position; })()", "threw: bad property value");
	OO_CHECK_EVAL("(function () { source.repeatCount = 7; return source.repeatCount; })()", "7");
	OO_CHECK_EVAL("(function () { source.repeatCount = 500; return source.repeatCount; })()", "100");
	OO_CHECK_EVAL("(function () { source.volume = 0.25; return source.volume; })()", "0.25");
	OO_CHECK_EVAL("(function () { source.volume = 3; return source.volume; })()", "1");
	OO_CHECK_EVAL("(function () { source.volume = -3; return source.volume; })()", "0");
	OO_CHECK_EVAL("(function () { source.sound = null; return source.sound; })()", "null");
	OO_CHECK(sSource->_sound == nil);
	OO_CHECK_EVAL("(function () { source.sound = aSound; return source.sound === null; })()", "false");
	OO_CHECK(sSource->_sound == sSound);
	sSource->_gain = 0.5f;
}


OO_TEST(methods)
{
	SetUpContext();
	sSource->_repeatCount = 1;
	int plays = sSource->_plays;
	OO_CHECK_EVAL("source.play()", "undefined");
	OO_CHECK_EQ(sSource->_plays, plays + 1);
	OO_CHECK_EQ(static_cast<int>(sSource->_repeatCount), 1);
	OO_CHECK_EVAL("source.play(3)", "undefined");
	OO_CHECK_EQ(static_cast<int>(sSource->_repeatCount), 3);
	OO_CHECK_EVAL("source.play(1000)", "undefined");
	OO_CHECK_EQ(static_cast<int>(sSource->_repeatCount), 100);
	OO_CHECK_EVAL("source.play(0)", "undefined");	// not positive: the count is left alone
	OO_CHECK_EQ(static_cast<int>(sSource->_repeatCount), 100);
	OO_CHECK_EVAL("source.play(undefined)", "undefined");
	OO_CHECK_EQ(sSource->_plays, plays + 5);
	OO_CHECK_EVAL("source.play({ valueOf: function () { throw new Error('no count'); } })", "threw: bad arguments: SoundSource.play (1): ; expected integer count or no argument");
	OO_CHECK_EVAL("source.isPlaying", "true");
	OO_CHECK_EVAL("source.stop()", "undefined");
	OO_CHECK_EVAL("source.isPlaying", "false");
	int repeats = sSource->_playOrRepeats;
	OO_CHECK_EVAL("source.playOrRepeat()", "undefined");
	OO_CHECK_EQ(sSource->_playOrRepeats, repeats + 1);
	OO_CHECK_EVAL("SoundSource.prototype.stop.call({})", "threw: Native method expected SoundSource, got [object Object].");
	OO_CHECK_EQ(sLimiterPauses, 0);
}


OO_TEST(nativeExceptions)
{
	SetUpContext();
	// The property getter is a native (OOJS_NATIVE_ENTER): a raise from the source is a JS error,
	// and so is a C++ exception.
	sSource->_gain = 0.99f;
	OO_CHECK_EVAL("source.volume", "threw: Native exception: gain boom");
	sSource->_gain = 0.98f;
	OO_CHECK_EVAL("source.volume", "threw: Native exception: cxx boom");
	sSource->_gain = 0.5f;
	OO_CHECK_EVAL("source.volume", "0.5");
	OO_CHECK_EQ(sLimiterPauses, 0);
	OO_CHECK_EQ(sProfileDepth, 0);
	OO_CHECK(ooscript::isInRequest(sContext));
}


OO_TEST_MAIN()
