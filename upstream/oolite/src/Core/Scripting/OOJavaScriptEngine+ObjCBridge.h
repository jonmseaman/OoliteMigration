/*

OOJavaScriptEngine+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056, beads oo-10qz, oo-903c and oo-elta): the Objective-C OOJavaScriptEngine, a
facade over the C++ cxx::OOJavaScriptEngine (OOJavaScriptEngine.h), for the code that is not
converted yet: nearly every scripting file, the debug support, the player and the universe. Its
interface is the one OOJavaScriptEngine.h declared before the conversion, copied exactly (same
selectors, same types, same root); every method forwards to its C++ member in one line
(OOJavaScriptEngine+ObjCBridge.mm). The monitor protocol and the OOMonitorSupport category moved
here from OOJavaScriptEngine.h, and so did the root class's JS glue (the category OOObject
(OOJavaScript), whose default methods forward to free functions in OOJavaScriptEngine.mm) and
OONull, the facade of cxx::OONull. Below them are the one-line bridges through which
OOJavaScriptEngine.mm's free functions send to classes that are still Objective-C (amendment
oo-9ht.139 item 3). Imported as the last line of OOJavaScriptEngine.h; do not import it directly.

	a caller that is                       holds / passes                       crosses with
	-------------------------------------  -----------------------------------  ------------------------
	still Objective-C                      OOJavaScriptEngine * (this facade)   nothing: messages as before
	converted (C++)                        cxx::OOJavaScriptEngine * (the singleton)
	  handing the engine to Objective-C                                         oo::ToObjC(engine)
	  taking it from Objective-C                                                oo::ToCxx(objcEngine)

The engine is a singleton: +sharedEngine answers one facade for the life of the process
(proposed ADR-0056 amendment oo-r7m0, item 5), and that facade is the sender of the engine's
reset notifications, as the engine was. Never add to this file; converted code does not message
the facade. Deleted by its deletion bead once slices 2-4 are converted and no file outside
OOJavaScriptEngine.* names the Objective-C class.

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

#ifndef OOJAVASCRIPTENGINE_OBJCBRIDGE_H
#define OOJAVASCRIPTENGINE_OBJCBRIDGE_H

#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"


@interface OOJavaScriptEngine: OOObject
{
@private
	oo::Ref<cxx::OOJavaScriptEngine>	_cxxEngine;
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
	predecessor did, and -copy returns itself. The facade of cxx::OONull
	(OOJavaScriptEngine.h): there is one, made by +null, for the life of the process.
*/
@interface OONull: OOObject <OOCopying>
{
@private
	oo::Ref<cxx::OONull>	_cxxNull;
}

+ (OONull *) null;

@end


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


namespace oo {

// The engine's Objective-C facade: its live one, else a new one; autoreleased. nil for null.
OOJavaScriptEngine *ToObjC(cxx::OOJavaScriptEngine *engine);
// The C++ engine behind a facade, borrowed; null for nil.
cxx::OOJavaScriptEngine *ToCxx(OOJavaScriptEngine *engine);

// The one null's facade, the same object every time (+[OONull null]); nil for null.
OONull *ToObjC(cxx::OONull *null);
// The C++ null behind the facade, borrowed; null for nil.
cxx::OONull *ToCxx(OONull *null);

}	// namespace oo


/*	One-line bridges for OOJavaScriptEngine.mm's free functions (amendment oo-9ht.139 item 3): each
	is the one message it is named after, verbatim, to a class that is still Objective-C. Each goes
	with the conversion of the class it messages.
*/
// +[ResourceManager cxx_dictionaryFromFilesNamed:inFolder:andMerge:]
oo::PList OOJavaScriptEngineDictionaryFromFilesNamed(const std::string &fileName, const std::optional<std::string> &folderName, bool mergeFiles);
// -weakRefUnderlyingObject (OOWeakReferenceSupport): the object itself for a non-weakref, nil for nil.
id OOJavaScriptEngineWeakRefUnderlyingObject(id object);
// -displayName of a script (OOScript); nullopt for nil.
std::optional<std::string> OOJavaScriptEngineDisplayName(id script);
// The JS glue of any object (OOObject (OOJavaScript)), as the object's class answers it.
ooscript::Value OOJavaScriptEngineJSValueInContext(id object, ooscript::Context context);
std::optional<std::string> OOJavaScriptEngineJSClassName(id object);
std::optional<std::string> OOJavaScriptEngineJSDescriptionWithClassName(id object, const std::optional<std::string> &className);
// -cxx_descriptionComponents (OODescription.h) and -class of any object.
std::optional<std::string> OOJavaScriptEngineDescriptionComponents(id object);
Class OOJavaScriptEngineClass(id object);
// [OOObject class]
Class OOJavaScriptEngineOOObjectClass();
/*	Inside a catch (...) handler: true, with the exception's name and reason, if the exception
	being handled is an OOException (what @catch (OOException *) caught); false for anything else,
	which the handler rethrows.
*/
bool OOJavaScriptEngineCaughtOOException(std::string &name, std::string &reason);

#endif	// OOJAVASCRIPTENGINE_OBJCBRIDGE_H
