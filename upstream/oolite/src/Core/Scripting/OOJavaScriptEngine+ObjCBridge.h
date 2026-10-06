/*

OOJavaScriptEngine+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056, beads oo-10qz and oo-903c): the Objective-C OOJavaScriptEngine, a
facade over the C++ cxx::OOJavaScriptEngine (OOJavaScriptEngine.h), for the code that is not
converted yet: nearly every scripting file, the debug support, the player and the universe. Its
interface is the one OOJavaScriptEngine.h declared before the conversion, copied exactly (same
selectors, same types, same root); every method forwards to its C++ member in one line
(OOJavaScriptEngine+ObjCBridge.mm). The monitor protocol and the OOMonitorSupport category moved
here from OOJavaScriptEngine.h. Below them are the one-line bridges through which
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

#endif	// OOJAVASCRIPTENGINE_OBJCBRIDGE_H
