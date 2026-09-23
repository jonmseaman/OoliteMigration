/*

OOJavaScriptEngine.h

JavaScript support for Oolite
Copyright (C) 2007-2013 David Taylor and Jens Ayton.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
MA 02110-1301, USA.

*/


#import "OOCocoa.h"
#import "Universe.h"
#import "PlayerEntity.h"
#import "PlayerEntityLegacyScriptEngine.h"
#import "oofnd/objc/OOObject.h"
#define OOJSENGINE_MONITOR_SUPPORT OOLITE_DEBUG


#include "ooscript/JSEngine.hpp"
#include "oofnd/StdLib.hpp"
#import "OOJSPropID.h"

#ifdef __cplusplus
#define OOJS_EXTERN_C extern "C"
#else
#define OOJS_EXTERN_C
#endif


@protocol OOJavaScriptEngineMonitor;


@interface OOJavaScriptEngine: OOObject
{
@private
	ooscript::Runtime _runtime;
	ooscript::Object _globalObject;
	BOOL							_showErrorLocations;
	
	ooscript::ClassDef							*_objectClass;
	ooscript::ClassDef							*_stringClass;
	ooscript::ClassDef							*_arrayClass;
	ooscript::ClassDef							*_numberClass;
	ooscript::ClassDef							*_booleanClass;
	
#ifndef NDEBUG
	BOOL							_dumpStackForErrors;
	BOOL							_dumpStackForWarnings;
#endif
#if OOJSENGINE_MONITOR_SUPPORT
	id<OOJavaScriptEngineMonitor>	_monitor;
#endif
}

+ (OOJavaScriptEngine *) sharedEngine;

- (ooscript::Object) globalObject;

- (void) runMissionCallback;

/*	Tear down context and global object and rebuild them from scratch. This
	invalidates -globalObject and the main thread context.
*/
- (BOOL) reset;

// Call a JS function, setting up new contexts as necessary. Caller is responsible for ensuring the ooscript::Value passed really is a function.
- (BOOL) callJSFunction:(ooscript::Value)function
			  forObject:(ooscript::Object)jsThis
				   argc:(unsigned)argc
				   argv:(ooscript::Value *)argv
				 result:(ooscript::Value *)outResult;

- (void) removeGCObjectRoot:(ooscript::Object *)rootPtr;
- (void) removeGCValueRoot:(ooscript::Value *)rootPtr;

- (void) garbageCollectionOpportunity:(BOOL)force;

- (BOOL) showErrorLocations;
- (void) setShowErrorLocations:(BOOL)value;

- (ooscript::ClassDef *) objectClass;
- (ooscript::ClassDef *) stringClass;
- (ooscript::ClassDef *) arrayClass;
- (ooscript::ClassDef *) numberClass;
- (ooscript::ClassDef *) booleanClass;

#ifndef NDEBUG
- (BOOL) dumpStackForErrors;
- (void) setDumpStackForErrors:(BOOL)value;

- (BOOL) dumpStackForWarnings;
- (void) setDumpStackForWarnings:(BOOL)value;

// Install handler for JS "debugger" statment.
- (void) enableDebuggerStatement;
#endif

@end




// Get the main thread's JS context, and begin a request on it.
OOINLINE ooscript::Context OOJSAcquireContext(void)
{
	extern ooscript::Context gOOJSMainThreadContext;
	NSCAssert(gOOJSMainThreadContext != NULL, @"Attempt to use JavaScript context before JavaScript engine is initialized.");
	ooscript::beginRequest(gOOJSMainThreadContext);
	return gOOJSMainThreadContext;
}


// End a request on the main thread's context.
OOINLINE void OOJSRelinquishContext(ooscript::Context context)
{
#ifndef NDEBUG
	extern ooscript::Context gOOJSMainThreadContext;
	NSCParameterAssert(context == gOOJSMainThreadContext && ooscript::isInRequest(context));
#endif
	ooscript::endRequest(context);
}


// Notifications sent when JavaScript engine is reset.
extern NSString * const kOOJavaScriptEngineWillResetNotification;
extern NSString * const kOOJavaScriptEngineDidResetNotification;

/*	The same notifications on oo::NotificationCenter (oofnd/Notification.hpp, bead oo-3rb.9),
	posted with the engine as the object. Until the last NSNotificationCenter observer is
	migrated, -reset posts each notification to both centers (oo::NotificationCenter first); the
	NSString names above go with that last observer.
*/
extern const char * const kOOJavaScriptEngineWillResetNotificationName;
extern const char * const kOOJavaScriptEngineDidResetNotificationName;


/*	Error and warning reporters.
	
	Note that after reporting an error in a JavaScript callback, the caller
	must return NO to signal an error.
	The cxx_ forms (proposed ADR-0043 item 17's pattern; bead oo-3rb.200) take printf formats
	(no %@: pass an object's text as %s with oo::DescriptionOf), formatted by oo::str::vformat.
	A nullopt function means no caller prefix; a nullopt scriptClass prefixes "function: ".
	Plain C++, not OOJS_EXTERN_C.
*/
void cxx_OOJSReportError(ooscript::Context context, const char *format, ...) __attribute__((format(printf, 2, 3)));
void cxx_OOJSReportErrorWithArguments(ooscript::Context context, const char *format, va_list args) __attribute__((format(printf, 2, 0)));
void cxx_OOJSReportErrorForCaller(ooscript::Context context, const std::optional<std::string> &scriptClass, const std::optional<std::string> &function, const char *format, ...) __attribute__((format(printf, 4, 5)));

void cxx_OOJSReportWarning(ooscript::Context context, const char *format, ...) __attribute__((format(printf, 2, 3)));
void cxx_OOJSReportWarningWithArguments(ooscript::Context context, const char *format, va_list args) __attribute__((format(printf, 2, 0)));
void cxx_OOJSReportWarningForCaller(ooscript::Context context, const std::optional<std::string> &scriptClass, const std::optional<std::string> &function, const char *format, ...) __attribute__((format(printf, 4, 5)));

OOJS_EXTERN_C void OOJSReportBadPropertySelector(ooscript::Context context, ooscript::Object thisObj, ooscript::PropertyId propID, ooscript::PropertySpec *propertySpec);
OOJS_EXTERN_C void OOJSReportBadPropertyValue(ooscript::Context context, ooscript::Object thisObj, ooscript::PropertyId propID, ooscript::PropertySpec *propertySpec, ooscript::Value value);
// A nullopt message is "Invalid arguments"; a nullopt expectedArgsDescription adds no " -- expected ..." suffix.
void cxx_OOJSReportBadArguments(ooscript::Context context, const std::optional<std::string> &scriptClass, const std::optional<std::string> &function, unsigned argc, ooscript::Value *argv, const std::optional<std::string> &message, const std::optional<std::string> &expectedArgsDescription);

/*	OOJSSetWarningOrErrorStackSkip()
	
	Indicate that the direct call site is not relevant for error handler.
	Currently, if non-zero, no call site information is provided.
	Ideally, we'd stack crawl instead.
*/
OOJS_EXTERN_C void OOJSSetWarningOrErrorStackSkip(unsigned skip);


/*	OOJSArgumentListGetNumber()
	
	Get a single number from an argument list. The optional outConsumed
	argument can be used to find out how many parameters were used (currently,
	this will be 0 on failure, otherwise 1).
	
	On failure, it will return NO and raise an error. If the caller is a JS
	callback, it must return NO to signal an error.
*/
BOOL cxx_OOJSArgumentListGetNumber(ooscript::Context context, const std::optional<std::string> &scriptClass, const std::optional<std::string> &function, unsigned argc, ooscript::Value *argv, double *outNumber, unsigned *outConsumed);

/*	OOJSArgumentListGetNumberNoError()
	
	Like cxx_OOJSArgumentListGetNumber(), but does not report an error on failure.
*/
OOJS_EXTERN_C BOOL OOJSArgumentListGetNumberNoError(ooscript::Context context, unsigned argc, ooscript::Value *argv, double *outNumber, unsigned *outConsumed);


// Typed as int rather than BOOL to work with more general expressions such as bitfield tests.
OOINLINE ooscript::Value OOJSValueFromBOOL(int b) INLINE_CONST_FUNC;
OOINLINE ooscript::Value OOJSValueFromBOOL(int b)
{
	return ooscript::booleanValue(b != NO);
}


/*	The root-class JS glue for classes rooted on OOObject (ADR-0029). The same methods on the
	Foundation root class are declared in OOJavaScriptEngine+FoundationBridge.h until
	gnustep-base goes.

	-oo_jsValueInContext:

	Return the JavaScript value representation of an object. The default
	implementation returns ooscript::undefinedValue().

	SAFETY NOTE: if this message is sent to nil, the return value depends on
	the platform and the engine's value representation. If the
	receiver may be nil, use OOJSValueFromNativeObject() instead.

	Requires a request on context.

	-oo_jsDescription
	-oo_jsDescriptionWithClassName:
	-oo_jsClassName

	See comments for -descriptionComponents in OOCocoa.h. Strings, typed id: the selectors are
	shared with the Foundation root class and every class that overrides them.

	oo_clearJSSelf:
	This is called by OOJSObjectWrapperFinalize() when a JS object wrapper is
	collected. The default implementation does nothing.
*/
@interface OOObject (OOJavaScript)

- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context;
- (id) oo_jsDescription;	// shared selector (proposed ADR-0043)
- (id) oo_jsDescriptionWithClassName:(id)className;	// shared selector (proposed ADR-0043)
- (id) oo_jsClassName;	// shared selector (proposed ADR-0043)
- (void) oo_clearJSSelf:(ooscript::Object)selfVal;

@end


/*	OOJSValueFromNativeObject()
	Return a JavaScript value representation of an object, or null if passed
	nil.
	
	Requires a request on context.
*/
OOINLINE ooscript::Value OOJSValueFromNativeObject(ooscript::Context context, id object)
{
	if (object != nil)  return [object oo_jsValueInContext:context];
	return  ooscript::nullValue();
}


/*	OOJSObjectFromNativeObject()
	Return a JavaScript object representation of an object, or null if passed
	nil. The value is boxed if necessary.
	
	Requires a request on context.
*/
OOJS_EXTERN_C ooscript::Object OOJSObjectFromNativeObject(ooscript::Context context, id object);


/*	OONull: the placeholder for null inside native collections, which cannot
	hold nil (was Foundation's null singleton, ADR-0029 Decision 5). A JS array
	element that is null or undefined becomes [OONull null] in the NSArray, and
	[OONull null] becomes JS null, so JS null round-trips as before. Game code
	uses it where a collection slot is empty (MFD settings, target memory,
	script event arguments). It describes itself as "<null>", as its
	predecessor did, and -copy returns itself.
*/
@interface OONull: OOObject <OOCopying>

+ (OONull *) null;

@end


/*	OOJSValue: an object whose purpose in life is to hold a JavaScript value.
	This is somewhat useful for putting JavaScript objects in ObjC collections,
	for instance to pass as properties to script loaders. The value is
	GC rooted for the lifetime of the OOJSValue.
	
	All methods take a context parameter, which must either be nil or a context
	in a request.
*/
@interface OOJSValue: OOObject
{
	ooscript::Value					_val;
}

+ (id) valueWithJSValue:(ooscript::Value)value inContext:(ooscript::Context)context;
+ (id) valueWithJSObject:(ooscript::Object)object inContext:(ooscript::Context)context;

- (id) initWithJSValue:(ooscript::Value)value inContext:(ooscript::Context)context;
- (id) initWithJSObject:(ooscript::Object)object inContext:(ooscript::Context)context;

@end



/**** String utilities ****/

/*	OOJSSTR(const char * [literal])
	
	Create and cache a ooscript::Value referring to an interned string literal.
*/
#define OOJSSTR(str) ({ static ooscript::Value strCache; static BOOL inited; if (EXPECT_NOT(!inited)) OOJSStrLiteralCachePRIVATE("" str, &strCache, &inited); strCache; })
OOJS_EXTERN_C void OOJSStrLiteralCachePRIVATE(const char *string, ooscript::Value *strCache, BOOL *inited);


/*	The JS-to-string converters (proposed ADR-0043; bead oo-3rb.198). Each returns
	std::nullopt where the Foundation form it replaces returned nil. Plain C++ (not
	OOJS_EXTERN_C): a C-linkage function cannot return std::optional.
*/

// Convert a JSString to a UTF-8 string (nullopt for a NULL string or no characters).
std::optional<std::string> cxx_OOStringFromJSString(ooscript::Context context, ooscript::String string);

/*	Convert an arbitrary JS object to a string, calling ooscript::valueToString.
	cxx_OOStringFromJSValue() returns nullopt if value is null or undefined,
	cxx_OOStringFromJSValueEvenIfNull() returns "null" or "undefined".
*/
std::optional<std::string> cxx_OOStringFromJSValue(ooscript::Context context, ooscript::Value value);
std::optional<std::string> cxx_OOStringFromJSValueEvenIfNull(ooscript::Context context, ooscript::Value value);


/*	cxx_OOStringFromJSPropertyIDAndSpec(context, propID, propertySpec)
	
	Returns the name of a property given either a name or a tinyid. (Intended
	for error reporting inside JSPropertyOps.)
*/
std::optional<std::string> cxx_OOStringFromJSPropertyIDAndSpec(ooscript::Context context, ooscript::PropertyId propID, ooscript::PropertySpec *propertySpec);


/*	Describe a value for debugging or error reporting. Strings are quoted,
	escaped and limited in length. Functions are described as "function foo"
	(or just "function" if they're anonymous). Up to four elements of arrays
	are included, followed by total count of there are more than four.
	If abbreviateObjects, the description "[object Object]" is replaced with
	"{...}", which may or may not be clearer depending on context. Never empty of meaning:
	the last fallback is "?".
*/
std::string cxx_OOJSDescribeValue(ooscript::Context context, ooscript::Value value, BOOL abbreviateObjects);


// Convert a ooscript::PropertyId to a UTF-8 string (nullopt if it has no string value).
std::optional<std::string> cxx_OOStringFromJSID(ooscript::PropertyId propID);

// Convert a UTF-8 string to a ooscript::PropertyId.
ooscript::PropertyId cxx_OOJSIDFromString(const std::string &string);


/*	The string helpers of the retired string category (OOJavaScriptExtensions) (bead oo-3rb.199).
	Each std::optional result is nullopt where the category method returned nil.
*/

// For diagnostic messages; produces things like "(42, true, "a string", an object description)".
// nullopt if params is NULL and count is not zero.
std::optional<std::string> cxx_OOJSStringWithJavaScriptParameters(ooscript::Value *params, unsigned count, ooscript::Context context);

// Concatenate sequence of arbitrary JS objects into string (nullopt if count < 1 or values is NULL).
std::optional<std::string> cxx_OOJSConcatenationOfStringsFromJavaScriptValues(ooscript::Value *values, size_t count, const std::string &separator, ooscript::Context context);

// Add escape codes for string so that it's a valid JavaScript literal (if you put "" or '' around it).
std::string cxx_OOJSEscapedForJavaScriptLiteral(std::string_view string);


// OOEntityFilterPredicate wrapping a JavaScript function.
typedef struct
{
	ooscript::Context context;
	ooscript::Value					function;	// Caller is responsible for ensuring this is a function object (using OOJSValueIsFunction()).
	ooscript::Object jsThis;
	BOOL					errorFlag;	// Set if a JS exception occurs. The
										// exception will have been reported.
										// This also supresses further filtering.
} JSFunctionPredicateParameter;
OOJS_EXTERN_C BOOL JSFunctionPredicate(Entity *entity, void *parameter);

// YES for ships and (normal) planets. Parameter: ignored.
OOJS_EXTERN_C BOOL JSEntityIsJavaScriptVisiblePredicate(Entity *entity, void *parameter);

// YES for ships other than sub-entities and menu-display ships, and planets other than atmospheres and menu miniatures. Parameter: ignored.
OOJS_EXTERN_C BOOL JSEntityIsJavaScriptSearchablePredicate(Entity *entity, void *parameter);

// YES for menu-display ships. Parameter: ignored
OOJS_EXTERN_C BOOL JSEntityIsDemoShipPredicate(Entity *entity, void *parameter);


// These require a request on context.
OOJS_EXTERN_C id OOJSNativeObjectFromJSValue(ooscript::Context context, ooscript::Value value);
OOJS_EXTERN_C id OOJSNativeObjectFromJSObject(ooscript::Context context, ooscript::Object object);
OOJS_EXTERN_C id OOJSNativeObjectOfClassFromJSValue(ooscript::Context context, ooscript::Value value, Class requiredClass);
OOJS_EXTERN_C id OOJSNativeObjectOfClassFromJSObject(ooscript::Context context, ooscript::Object object, Class requiredClass);


OOINLINE ooscript::ClassDef *OOJSGetClass(ooscript::Context cx, ooscript::Object obj)  ALWAYS_INLINE_FUNC;
OOINLINE ooscript::ClassDef *OOJSGetClass(ooscript::Context cx, ooscript::Object obj)
{
	return const_cast<ooscript::ClassDef *>(ooscript::getObjectClass(cx, obj));
}


/*	OOJSValueIsFunction(context, value)
	
	Test whether a ooscript::Value is a function object. The main tripping point here
	is that ooscript::isObjectOrNull() is true for ooscript::nullValue(), but ooscript::objectIsFunction()
	crashes if passed null.
*/
OOINLINE BOOL OOJSValueIsFunction(ooscript::Context context, ooscript::Value value)
{
	return ooscript::isObjectOrNull(value) && !ooscript::isNull(value) && ooscript::objectIsFunction(context, ooscript::toObject(value));
}


/*	OOJSValueIsArray(context, value)
	
	Test whether a ooscript::Value is an array object. The main tripping point here
	is that ooscript::isObjectOrNull() is true for ooscript::nullValue(), but ooscript::isArrayObject()
	crashes if passed null.
	
*/
OOINLINE BOOL OOJSValueIsArray(ooscript::Context context, ooscript::Value value)
{
	return ooscript::isObjectOrNull(value) && !ooscript::isNull(value) && ooscript::isArrayObject(context, ooscript::toObject(value));
}


/*	OOJSDictionaryFromJSValue(context, value)
	OOJSDictionaryFromJSObject(context, object)
	
	Converts a JavaScript value to a dictionary by calling
	OOJSNativeObjectFromJSValue() on each of its values.
	
	Only enumerable own (i.e., not inherited) properties with string keys are
	included.
	
	Requires a request on context.
*/
OOJS_EXTERN_C NSDictionary *OOJSDictionaryFromJSValue(ooscript::Context context, ooscript::Value value);
OOJS_EXTERN_C NSDictionary *OOJSDictionaryFromJSObject(ooscript::Context context, ooscript::Object object);


/*	OOJSDictionaryFromStringTable(context, value)
	
	Treat an arbitrary JavaScript object as a dictionary mapping strings to
	strings, and convert to a corresponding NSDictionary. The values are
	converted to strings using ooscript::valueToString().
	
	Only enumerable own (i.e., not inherited) properties with string keys are
	included.
	
	Requires a request on context.
*/
OOJS_EXTERN_C NSDictionary *OOJSDictionaryFromStringTable(ooscript::Context context, ooscript::Value value);


/*
	DEFINE_JS_OBJECT_GETTER()
	Defines a helper to extract Objective-C objects from the private field of
	JS objects, with runtime type checking. The generated accessor requires
	a request on context. Weakrefs are automatically unpacked.
	
	Types which extend other types, such as entity subtypes, must register
	their relationships with OOJSRegisterSubclass() below.
	
	The signature of the generator is:
	BOOL <name>(ooscript::Context context, ooscript::Object inObject, <class>** outObject)
	If it returns NO, inObject is of the wrong class and an error has been
	raised. Otherwise, outObject is either a native object of the specified
	class (or a subclass) or nil.
*/
#ifndef NDEBUG
#define DEFINE_JS_OBJECT_GETTER(NAME, JSCLASS, JSPROTO, OBJCCLASSNAME) \
static BOOL NAME(ooscript::Context context, ooscript::Object inObject, OBJCCLASSNAME **outObject)  GCC_ATTR((unused)); \
static BOOL NAME(ooscript::Context context, ooscript::Object inObject, OBJCCLASSNAME **outObject) \
{ \
	NSCParameterAssert(outObject != NULL); \
	static Class cls = Nil; \
	if (EXPECT_NOT(cls == Nil))  cls = [OBJCCLASSNAME class]; \
	return OOJSObjectGetterImplPRIVATE(context, inObject, JSCLASS, cls, #NAME, (id *)outObject); \
}
#else
#define DEFINE_JS_OBJECT_GETTER(NAME, JSCLASS, JSPROTO, OBJCCLASSNAME) \
OOINLINE BOOL NAME(ooscript::Context context, ooscript::Object inObject, OBJCCLASSNAME **outObject) \
{ \
	return OOJSObjectGetterImplPRIVATE(context, inObject, JSCLASS, (id *)outObject); \
}
#endif

// For DEFINE_JS_OBJECT_GETTER()'s use.
#ifndef NDEBUG
OOJS_EXTERN_C BOOL OOJSObjectGetterImplPRIVATE(ooscript::Context context, ooscript::Object object, ooscript::ClassDef *requiredJSClass, Class requiredObjCClass, const char *name, id *outObject);
#else
OOJS_EXTERN_C BOOL OOJSObjectGetterImplPRIVATE(ooscript::Context context, ooscript::Object object, ooscript::ClassDef *requiredJSClass, id *outObject);
#endif


/*
	Subclass relationships.
	
	JSAPI doesn't have a concept of subclassing, as JavaScript doesn't have a
	concept of classes, but Oolite reflects part of its class hierarchy as
	related JSClasses whose prototypes inherit each other. For instance,
	JS Entity methods work on JS Ships. In order for this to work,
	OOJSEntityGetEntity() must be able to know that Ship is a subclass of
	Entity. This is done using OOJSIsSubclass().
	
	void OOJSRegisterSubclass(ooscript::ClassDef *subclass, ooscript::ClassDef *superclass)
	Register subclass as a subclass of superclass. Subclass must not previously
	have been registered as a subclass of any class (i.e., single inheritance
	is required).
 
	BOOL OOJSIsSubclass(ooscript::ClassDef *putativeSubclass, ooscript::ClassDef *superclass)
	Test whether putativeSubclass is a equal to superclass or a registered
	subclass of superclass, recursively.
*/
OOJS_EXTERN_C void OOJSRegisterSubclass(ooscript::ClassDef *subclass, ooscript::ClassDef *superclass);
OOJS_EXTERN_C BOOL OOJSIsSubclass(ooscript::ClassDef *putativeSubclass, ooscript::ClassDef *superclass);
OOINLINE BOOL OOJSIsMemberOfSubclass(ooscript::Context context, ooscript::Object object, ooscript::ClassDef *superclass)
{
	return OOJSIsSubclass(OOJSGetClass(context, object), superclass);
}


/*	Support for OOJSNativeObjectFromJSValue() family
	
	OOJSClassConverterCallback specifies the prototype for a callback function
	which converts a JavaScript object to an Objective-C object.
	
	OOJSBasicPrivateObjectConverter() is a OOJSClassConverterCallback which
	returns the JS object's private storage value. It automatically unpacks
	OOWeakReferences if relevant.
	
	OOJSRegisterObjectConverter() registers a callback for a specific JS class.
	It is not automatically propagated to subclasses.
*/
typedef id (*OOJSClassConverterCallback)(ooscript::Context context, ooscript::Object object);
OOJS_EXTERN_C id OOJSBasicPrivateObjectConverter(ooscript::Context context, ooscript::Object object);

OOJS_EXTERN_C void OOJSRegisterObjectConverter(ooscript::ClassDef *theClass, OOJSClassConverterCallback converter);


/*	JS root handling
	
	The name parameter to the façade's addNamed*Root is assigned with no overhead, not
	copied, but the strings serve no purpose in a release build so we may as
	well strip them out.
	
	In debug builds, this will deliberately cause an error if name is not a
	string literal.
*/
#ifdef NDEBUG
#define OOJSAddGCValueRoot(context, root, name)		ooscript::addNamedValueRoot((context), (root), nullptr)
#define OOJSAddGCStringRoot(context, root, name)	ooscript::addNamedStringRoot((context), (root), nullptr)
#define OOJSAddGCObjectRoot(context, root, name)	ooscript::addNamedObjectRoot((context), (root), nullptr)
#else
#define OOJSAddGCValueRoot(context, root, name)		ooscript::addNamedValueRoot((context), (root), "" name)
#define OOJSAddGCStringRoot(context, root, name)	ooscript::addNamedStringRoot((context), (root), "" name)
#define OOJSAddGCObjectRoot(context, root, name)	ooscript::addNamedObjectRoot((context), (root), "" name)
#endif


#if OOJSENGINE_MONITOR_SUPPORT

/*	Protocol for debugging "monitor" object.
	The monitor is an object -- in Oolite, or via Distributed Objects -- which
	is provided with debugging information by the OOJavaScriptEngine.
*/

@protocol OOJavaScriptEngineMonitor <NSObject>

// Sent for JS errors or warnings.
- (oneway void)jsEngine:(in byref OOJavaScriptEngine *)engine
				context:(in ooscript::Context)context
				  error:(in ooscript::ErrorReport *)errorReport
			  stackSkip:(in unsigned)stackSkip
		showingLocation:(in BOOL)showLocation
			withMessage:(in NSString *)message;

// Sent for JS log messages. Note: messageClass will be nil if Log() is used rather than LogWithClass().
- (oneway void)jsEngine:(in byref OOJavaScriptEngine *)engine
				context:(in ooscript::Context)context
			 logMessage:(in NSString *)message
				ofClass:(in NSString *)messageClass;

@end


@interface OOJavaScriptEngine (OOMonitorSupport)

- (void)setMonitor:(id<OOJavaScriptEngineMonitor>)monitor;

@end

#endif


#import "OOJSEngineNativeWrappers.h"

/*	See comments on time limiter in OOJSEngineTimeManagement.h.
*/
OOJS_EXTERN_C void OOJSPauseTimeLimiter(void);
OOJS_EXTERN_C void OOJSResumeTimeLimiter(void);


/*	OOJSDumpStack()
	Write JavaScript stack to log.
	
	OOJSDescribeLocation()
	Get script and line number for a stack frame.
	
	OOJSMarkConsoleEvalLocation()
	Specify that a given stack frame identifies eval()ed code from the debug
	console, so that matching locations can be described specially by
	OOJSDescribeLocation().
*/
#ifndef NDEBUG
OOJS_EXTERN_C void OOJSDumpStack(ooscript::Context context);

OOJS_EXTERN_C NSString *OOJSDescribeLocation(ooscript::Context context, ooscript::StackFrame stackFrame);
OOJS_EXTERN_C void OOJSMarkConsoleEvalLocation(ooscript::Context context, ooscript::StackFrame stackFrame);
#else
#define OOJSDumpStack(cx)						do {} while (0)
#define OOJSDescribeLocation(cx, frame)			do {} while (0)
#define OOJSMarkConsoleEvalLocation(cx, frame)  do {} while (0)
#endif




/***** Reusable JS callbacks ****/

/*	OOJSUnconstructableConstruct
	
	Constructor callback for pseudo-classes which can't be constructed.
*/
OOJS_EXTERN_C bool OOJSUnconstructableConstruct(ooscript::Context context, ooscript::CallArgs &oojsArgs);


/*	OOJSObjectWrapperFinalize
	
	Finalizer for JS classes whose private storage is a retained object
	reference (generally an OOWeakReference, but doesn't have to be).
*/
OOJS_EXTERN_C void OOJSObjectWrapperFinalize(ooscript::Context context, ooscript::Object thisObj);


/*	OOJSObjectWrapperToString
	
	Implementation of toString() for JS classes whose private storage is an
	Objective-C object reference (generally an OOWeakReference).
	
	Calls -oo_jsDescription and, if that fails, -description.
*/
OOJS_EXTERN_C bool OOJSObjectWrapperToString(ooscript::Context context, ooscript::CallArgs &oojsArgs);



/***** Appropriate flags for host-defined read/write and read-only properties *****/

// Slot-based (defined with ooscript::defineProperty/defineObject/defineFunction and no callbacks)
#define OOJS_PROP_READWRITE				(ooscript::PropertyFlag::Permanent | ooscript::PropertyFlag::Enumerate)
#define OOJS_PROP_READONLY				(ooscript::PropertyFlag::Permanent | ooscript::PropertyFlag::Enumerate | ooscript::PropertyFlag::ReadOnly)

// Non-enumerable properties
#define OOJS_PROP_HIDDEN_READWRITE		(ooscript::PropertyFlag::Permanent)
#define OOJS_PROP_HIDDEN_READONLY		(ooscript::PropertyFlag::Permanent | ooscript::PropertyFlag::ReadOnly)

// Methods should be non-enumerable
#define OOJS_METHOD_READONLY			OOJS_PROP_HIDDEN_READONLY

// Callback-based (includes all properties specified in JSPropertySpecs)
#define OOJS_PROP_READWRITE_CB			(OOJS_PROP_READWRITE | ooscript::PropertyFlag::Shared)
#define OOJS_PROP_READONLY_CB			(OOJS_PROP_READONLY | ooscript::PropertyFlag::Shared)

#define OOJS_PROP_HIDDEN_READWRITE_CB	(OOJS_PROP_HIDDEN_READWRITE | ooscript::PropertyFlag::Shared)
#define OOJS_PROP_HIDDEN_READONLY_CB	(OOJS_PROP_HIDDEN_READONLY | ooscript::PropertyFlag::Shared)




/***** Helpers for native callbacks. *****/
// Every native is `bool Name(ooscript::Context context, ooscript::CallArgs &oojsArgs)`.
#define OOJS_THIS						(oojsArgs.thisObject())
#define OOJS_ARGV						(oojsArgs.argv())
#define OOJS_RVAL						(oojsArgs.rval())
#define OOJS_SET_RVAL(v)				oojsArgs.setRval(v)

#define OOJS_RETURN(v)					do { OOJS_SET_RVAL(v); return YES; } while (0)
#define OOJS_RETURN_JSOBJECT(o)			OOJS_RETURN(ooscript::objectValue(o))
#define OOJS_RETURN_VOID				OOJS_RETURN(ooscript::undefinedValue())
#define OOJS_RETURN_NULL				OOJS_RETURN(ooscript::nullValue())
#define OOJS_RETURN_BOOL(v)				OOJS_RETURN(OOJSValueFromBOOL(v))
#define OOJS_RETURN_INT(v)				OOJS_RETURN(ooscript::int32Value(v))
#define OOJS_RETURN_OBJECT(o)			OOJS_RETURN(OOJSValueFromNativeObject(context, o))

#define OOJS_RETURN_WITH_HELPER(helper, value) \
do { \
	ooscript::Value jsresult; \
	BOOL OK = helper(context, value, &jsresult); \
	oojsArgs.setRval(jsresult); return OK; \
} while (0)

#define OOJS_RETURN_VECTOR(value)		OOJS_RETURN_WITH_HELPER(VectorToJSValue, value)
#define OOJS_RETURN_HPVECTOR(value)		OOJS_RETURN_WITH_HELPER(HPVectorToJSValue, value)
#define OOJS_RETURN_QUATERNION(value)	OOJS_RETURN_WITH_HELPER(QuaternionToJSValue, value)
#define OOJS_RETURN_DOUBLE(value)		OOJS_RETURN_WITH_HELPER(ooscript::newNumberValue, value)


/*	TRANSITIONAL (proposed ADR-0043, "Transitional bridges"): the Foundation-typed API this header
	declared before its sweep (beads oo-3rb.198 onwards, chunks of oo-rbqc), forwarding to the cxx_
	functions above, so unmigrated callers compile unchanged. Callers move to the cxx_ API in their
	own sweep beads; the bridge goes in its own bead.
*/
#import "OOJavaScriptEngine+FoundationBridge.h"
