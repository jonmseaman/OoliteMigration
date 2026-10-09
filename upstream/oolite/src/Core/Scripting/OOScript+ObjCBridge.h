/*

OOScript+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056, Amendment 1 of bead oo-cwz; bead oo-604l): the Objective-C
OOScript, a facade over the C++ cxx::OOScript (OOScript.h). Its interface is the one OOScript.h
declared before the conversion, copied exactly (same selectors, same types, same superclass; the
ivars are one C++ reference), so its callers compile and behave unchanged. Imported as the last
line of OOScript.h; do not import it directly.

It was also the superclass of the Objective-C OOJSScript (until bead oo-9ht.137, which made this
class's facade a JS script's object: OOJSScript::scriptWithPath() makes it with
-initWithCxxRootScript:) and of the OOPListScript facade (amendment oo-o89, until bead oo-9ht.57), so
one Objective-C class has two kinds of instance, as amendment oo-6bux's root has:

	instance                              its C++ part                 made by
	------------------------------------  ---------------------------  ------------------------------
	an Objective-C subclass's             an adapter, whose virtual    [[Sub alloc] init]
	  (OOJSScript, OOPListScript)         members message it
	the facade of a C++ script            the script                   [[OOScript alloc] init], or
	                                                                   oo::ToObjC

The Objective-C object owns its C++ part. On a subclass instance, the methods a subclass overrides
(-cxx_name, -scriptDescription, -cxx_version, -requiresTickle, -runWithTarget:,
-cxx_descriptionComponents) answer with the base's own member, as [super ...] or a subclass that
does not override did. The category OOScript (JavaScriptEvents) is declared below (bead oo-9ht.137).

	a caller that is                       holds / passes                  crosses with
	-------------------------------------  ------------------------------  --------------------------
	still Objective-C                      OOScript *                      nothing: messages as before
	converted (C++)                        cxx::OOScript *
	  handing a script to Objective-C                                      oo::ToObjC(script)
	  taking one from Objective-C                                          oo::ToCxx(objcScript)

Never add to this file; converted code does not message the facade. Deleted by its deletion bead
once no file outside OOScript.* names the Objective-C class and its subclasses derive from the C++
one. The ivar is _cxxRootScript, not _cxxScript, because the OOPListScript facade has its own.

Oolite
Copyright (C) 2004-2013 Giles C Williams and contributors

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

#ifndef OOSCRIPT_OBJCBRIDGE_H
#define OOSCRIPT_OBJCBRIDGE_H

#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"
#import "OOWeakReference.h"
#include "ooscript/JSEngine.hpp"


@interface OOScript: OOObject
{
@private
	oo::Ref<cxx::OOScript>	_cxxRootScript;
}

/*	Looks for path/world-scripts.plist, path/script.js, then path/script.plist.
	May return zero or more scripts; nullopt (was nil) when none could be loaded.
*/
+ (std::optional<std::vector<oo::ObjCRef<OOScript *>>>)cxx_worldScriptsAtPath:(const std::string &)path;

//	Load named scripts from Scripts folders. nullopt where these returned nil.
+ (std::optional<std::vector<oo::ObjCRef<OOScript *>>>)scriptsFromFileNamed:(const std::string &)fileName;
+ (std::vector<oo::ObjCRef<OOScript *>>)scriptsFromList:(const std::vector<std::string> &)fileNames;

+ (std::optional<std::vector<oo::ObjCRef<OOScript *>>>)scriptsFromFileAtPath:(const std::string &)filePath;

//	Load a single JavaScript script. The properties may hold live objects (oo::PList Object nodes).
+ (id)cxx_jsScriptFromFileNamed:(const std::string &)fileName properties:(const oo::PList &)properties;
//  As above, but load from the "AIs" directory
+ (id)cxx_jsAIScriptFromFileNamed:(const std::string &)fileName properties:(const oo::PList &)properties;

- (std::optional<std::string>)cxx_name;	// nullopt: none (bead oo-3rb.289.6)
- (std::optional<std::string>)scriptDescription;	// nullopt: none
- (std::optional<std::string>)cxx_version;	// nullopt: none (bead oo-3rb.291.1)
- (std::optional<std::string>)displayName;	// flipped with its family (bead oo-3rb.267): "name version" if version is defined, otherwise just "name".

- (BOOL) requiresTickle;
- (void)runWithTarget:(Entity *)target;

@end


@interface OOScript (OOObjCBridge)

// For a C++ script that makes its own object (OOJSScript::scriptWithPath(), bead oo-9ht.137; the
// OOJSScript facade until then): stores it and records this facade as its peer, so oo::ToObjC
// answers it while it lives.
- (id) initWithCxxRootScript:(cxx::OOScript *)script;

@end


/*	What the OOJSScript facade answered, which this facade answers for a JS script's C++ part since
	bead oo-9ht.137 deleted that facade (ADR-0056 amendment oo-9ht.137): a JS script's object is
	this facade. The category OOScript (JavaScriptEvents), which every script answers, moved here
	from the deleted facade's header; the weak reference support answers a JS script only. Every other
	script answers as before (NO; no weak references). Also answered for a JS script: the JS glue
	(-oo_jsValueInContext:, -cxx_oo_jsClassName) and -dealloc's OOJSScript::willDealloc().
*/
@interface OOScript (JavaScriptEvents)

// For simplicity, calling methods on non-JS scripts works but does nothing.
- (BOOL) callMethod:(ooscript::PropertyId)methodID
		  inContext:(ooscript::Context)context
	  withArguments:(ooscript::Value *)argv count:(int)argc
			 result:(ooscript::Value *)outResult;

@end


@interface OOScript (OOJSScriptIdentity) <OOWeakReferenceSupport>

- (id) weakRetain;	// a JS script's weak reference, retained; nil for any other script
- (void) weakRefDied:(OOWeakReference *)weakRef;

@end


namespace oo {

// The script's Objective-C object: an Objective-C subclass's instance itself, else a C++ script's
// live facade (or a new one); autoreleased. nil for null.
::OOScript *ToObjC(cxx::OOScript *script);

// The C++ script behind an Objective-C one, borrowed (the Objective-C object owns it); null for nil.
cxx::OOScript *ToCxx(::OOScript *script);

}	// namespace oo

#endif	// OOSCRIPT_OBJCBRIDGE_H
