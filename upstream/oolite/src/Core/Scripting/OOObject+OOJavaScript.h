/*

OOObject+OOJavaScript.h

TRANSITIONAL (proposed ADR-0056, bead oo-wdqw1): the JS glue selectors an Objective-C object may
answer, and the one-line bridges through which OOJavaScriptEngine.mm's free functions send to
objects that are still Objective-C. Both were in the engine's facade file
(OOJavaScriptEngine+ObjCBridge.h), which oo-wdqw1 deleted with the engine's, OONull's and
OOJSValue's facades. The root's category OOObject (OOJavaScriptConversion), which answered the
defaults, is deleted (bead oo-t7o84): the defaults are OOJavaScriptEngine.mm's C++ functions, and
an object is sent a selector only when its class has its own method for it. The rest goes with
the root class and the runtime (Phase 4). Since bead oo-4aq6a.6 no JS object's private slot
holds an Objective-C object; what is left serves OOJSValueFromNativeObject() of an Objective-C
object, which only plist Object nodes of one and the tests make (ADR-0062, oo-8kdkl). Imported as
the last line of OOJavaScriptEngine.h; do not import it directly. Never add to this file.

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

#ifndef OOOBJECT_OOJAVASCRIPT_H
#define OOOBJECT_OOJAVASCRIPT_H

#include "OOCocoa.h"
#include "oofnd/objc/OOObject.h"

#include <objc/runtime.h>


/*	The JS glue selectors a class rooted on OOObject (ADR-0029) may answer itself (weak references
	and the tests' stand-ins do). An object whose class has no method for one has OOObject's
	default, the C++ function named beside it (OOJavaScriptEngine.h), which the deleted category
	OOObject (OOJavaScriptConversion) answered (bead oo-t7o84); the bridges below choose. An object
	on another root has none: OOJSValueFromNativeObject() gives undefined for it (oo-qps.72).

	-oo_jsValueInContext:					default OOObjectJSValueInContext()

	Return the JavaScript value representation of an object. The default is
	ooscript::undefinedValue().

	SAFETY NOTE: if this message is sent to nil, the return value depends on
	the platform and the engine's value representation. If the
	receiver may be nil, use OOJSValueFromNativeObject() instead.

	Requires a request on context.

	-cxx_oo_jsDescription					default OOObjectJSDescription()
	-cxx_oo_jsDescriptionWithClassName:		default OOObjectJSDescriptionWithClassName()
	-cxx_oo_jsClassName						default OOObjectJSClassName()

	They wrap -cxx_descriptionComponents (OODescription.h) as [jsClassName components].

	(-oo_clearJSSelf:, which OOJSObjectWrapperFinalize() sent to the slot's object, went with the
	slot's Objective-C objects, bead oo-4aq6a.6: the slot holds a C++ object, told by its
	OOJSPrivateObject::clearJSSelf().)
*/
@protocol OOJSObjectGlue

@optional
- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context;
- (std::optional<std::string>) cxx_oo_jsDescription;
- (std::optional<std::string>) cxx_oo_jsDescriptionWithClassName:(const std::optional<std::string> &)className;
- (std::optional<std::string>) cxx_oo_jsClassName;

@end


// Whether <object>'s class (or a superclass, or a category on one) has its own method for one of
// the selectors above, so the object answers it rather than OOObject's default. false for nil.
inline bool OOJSObjectAnswersGlue(id object, SEL selector)
{
	return object != nil && class_respondsToSelector(object_getClass(object), selector);
}


/*	One-line bridges for OOJavaScriptEngine.mm's free functions (amendment oo-9ht.139 item 3): each
	is the one message it is named after, verbatim, to a class that is still Objective-C (the root
	class, the entity's object, OOException). Each goes with the conversion of the
	class it messages.
*/
// The JS glue of any object: its class's own method, else OOObject's default (above).
ooscript::Value OOJavaScriptEngineJSValueInContext(id object, ooscript::Context context);
std::optional<std::string> OOJavaScriptEngineJSClassName(id object);
std::optional<std::string> OOJavaScriptEngineJSDescriptionWithClassName(id object, const std::optional<std::string> &className);
// -cxx_descriptionComponents (OODescription.h) and -class of any object.
std::optional<std::string> OOJavaScriptEngineDescriptionComponents(id object);
Class OOJavaScriptEngineClass(id object);
// [OOObject class]
Class OOJavaScriptEngineOOObjectClass();
// -cxx_oo_jsDescription of any object, as the glue above. (The -oo_clearJSSelf: and
// -isKindOfClass: bridges went with the slot's Objective-C objects, bead oo-4aq6a.6.)
std::optional<std::string> OOJavaScriptEngineJSDescription(id object);
// The entity predicates' questions (amendment oo-nge8 item 5) ask the C++ entity and are in
// OOJavaScriptEngine.mm since bead oo-t7o84 (ADR-0056 amendment oo-9ht.184).
/*	Inside a catch (...) handler: true, with the exception's name and reason, if the exception
	being handled is an OOException (what @catch (OOException *) caught); false for anything else,
	which the handler rethrows.
*/
bool OOJavaScriptEngineCaughtOOException(std::string &name, std::string &reason);

#endif	// OOOBJECT_OOJAVASCRIPT_H
