/*

OOObject+OOJavaScript.mm

TRANSITIONAL (proposed ADR-0056, bead oo-wdqw1): see OOObject+OOJavaScript.h. The one-line
bridges of OOJavaScriptEngine.mm's free functions (amendment oo-9ht.139), moved verbatim from
OOJavaScriptEngine+ObjCBridge.mm when oo-wdqw1 deleted the engine's facade. The category on
OOObject that forwarded to the free functions holding its bodies (amendment oo-ppc item 3) is
deleted (bead oo-t7o84): the JS glue bridges send an object's own method, else call those
functions.

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

#include "OOJavaScriptEngine.h"
#include "ResourceManager.h"
#include "OOWeakReference.h"
#include "OOVector.h"
#include "oofnd/objc/OOException.h"



id OOJavaScriptEngineWeakRefUnderlyingObject(id object)
{
	return [object weakRefUnderlyingObject];
}


Class OOJavaScriptEngineClass(id object)
{
	return [object class];
}


/*	An entity's object, or a weak reference to one, was not asked by selector (bead oo-9ht.39.8.9): its
	JS value and class name were its C++ entity's. Since the root facade's deletion (bead oo-dpyk8) no
	entity has an Objective-C object, and no weak reference refers to one: every object is asked.
	Since the root's category is deleted (bead oo-t7o84) an object whose class has no method of its
	own gets OOObject's default, the C++ function the category's method called; nil gets what the
	message to nil gave.
*/
ooscript::Value OOJavaScriptEngineJSValueInContext(id object, ooscript::Context context)
{
	if (object == nil)  return ooscript::Value{};	// the message to nil's zero
	if (OOJSObjectAnswersGlue(object, @selector(oo_jsValueInContext:)))  return [object oo_jsValueInContext:context];
	return OOObjectJSValueInContext(context);
}


std::optional<std::string> OOJavaScriptEngineJSClassName(id object)
{
	if (OOJSObjectAnswersGlue(object, @selector(cxx_oo_jsClassName)))  return [object cxx_oo_jsClassName];
	return OOObjectJSClassName();	// none (nil: the message to nil's none)
}


std::optional<std::string> OOJavaScriptEngineJSDescriptionWithClassName(id object, const std::optional<std::string> &className)
{
	if (object == nil)  return std::nullopt;	// the message to nil's
	if (OOJSObjectAnswersGlue(object, @selector(cxx_oo_jsDescriptionWithClassName:)))  return [object cxx_oo_jsDescriptionWithClassName:className];
	return OOObjectJSDescriptionWithClassName(object, className);
}


std::optional<std::string> OOJavaScriptEngineDescriptionComponents(id object)
{
	return [object cxx_descriptionComponents];
}


Class OOJavaScriptEngineOOObjectClass()
{
	return [OOObject class];
}


bool OOJavaScriptEngineCaughtOOException(std::string &name, std::string &reason)
{
	const auto exception = oo::CurrentOOException();	// nullopt: not what @catch (OOException *) caught
	if (!exception)  return false;
	name = exception->name();
	reason = exception->reason();
	return true;
}


std::optional<std::string> OOJavaScriptEngineJSDescription(id object)
{
	if (object == nil)  return std::nullopt;	// the message to nil's
	if (OOJSObjectAnswersGlue(object, @selector(cxx_oo_jsDescription)))  return [object cxx_oo_jsDescription];
	return OOObjectJSDescription(object);
}


void OOJavaScriptEngineClearJSSelf(id object, ooscript::Object selfVal)
{
	if (OOJSObjectAnswersGlue(object, @selector(oo_clearJSSelf:)))  [object oo_clearJSSelf:selfVal];
	else  OOObjectClearJSSelf(selfVal);	// nothing (nil: the message to nil's nothing)
}


bool OOJavaScriptEngineIsKindOfClass(id object, Class requiredClass)
{
	return [object isKindOfClass:requiredClass];
}
