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
#include "oofnd/PList.hpp"
#import "OOJSPropID.h"

#include "oofnd/objc/OOAssert.h"

/*	The plain C++ part of the engine API (bead oo-9ht.72): reporters, converters, argument and
	return macros, the native wrappers. A binding with no Objective-C includes only that header.
*/
#include "OOJSEngineCore.h"



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



/*	The root-class JS glue for classes rooted on OOObject (ADR-0029). An object on another root
	has none: OOJSValueFromNativeObject() gives undefined for it (oo-qps.72).

	-oo_jsValueInContext:

	Return the JavaScript value representation of an object. The default
	implementation returns ooscript::undefinedValue().

	SAFETY NOTE: if this message is sent to nil, the return value depends on
	the platform and the engine's value representation. If the
	receiver may be nil, use OOJSValueFromNativeObject() instead.

	Requires a request on context.

	-cxx_oo_jsDescription
	-cxx_oo_jsDescriptionWithClassName:
	-cxx_oo_jsClassName

	They wrap -cxx_descriptionComponents (OODescription.h) as [jsClassName components]. C++ string twins on OOObject.

	oo_clearJSSelf:
	This is called by OOJSObjectWrapperFinalize() when a JS object wrapper is
	collected. The default implementation does nothing.
*/
@interface OOObject (OOJavaScript)

- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context;
- (std::optional<std::string>) cxx_oo_jsDescription;
- (std::optional<std::string>) cxx_oo_jsDescriptionWithClassName:(const std::optional<std::string> &)className;
- (std::optional<std::string>) cxx_oo_jsClassName;
- (void) oo_clearJSSelf:(ooscript::Object)selfVal;

@end



/*	OONull: the placeholder for null inside native collections, which cannot
	hold nil (was Foundation's null singleton, ADR-0029 Decision 5). A JS array
	element that is null or undefined becomes [OONull null] in the native array, and
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
	OOCParameterAssert(outObject != NULL); \
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



#if OOJSENGINE_MONITOR_SUPPORT

/*	Protocol for debugging "monitor" object.
	The monitor is an object -- in Oolite, or via Distributed Objects -- which
	is provided with debugging information by the OOJavaScriptEngine.
*/

@protocol OOJavaScriptEngineMonitor <OOObject>

// Sent for JS errors or warnings.
- (void)jsEngine:(OOJavaScriptEngine *)engine
		 context:(ooscript::Context)context
		   error:(ooscript::ErrorReport *)errorReport
	   stackSkip:(unsigned)stackSkip
 showingLocation:(BOOL)showLocation
	 withMessage:(const std::string &)message;

// Sent for JS log messages. Note: messageClass is nullopt if Log() is used rather than LogWithClass().
- (void)jsEngine:(OOJavaScriptEngine *)engine
		 context:(ooscript::Context)context
	  logMessage:(const std::string &)message
		 ofClass:(const std::optional<std::string> &)messageClass;

@end


@interface OOJavaScriptEngine (OOMonitorSupport)

- (void)setMonitor:(id<OOJavaScriptEngineMonitor>)monitor;

@end

#endif


