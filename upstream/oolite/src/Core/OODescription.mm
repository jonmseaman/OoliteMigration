/*

OODescription.mm

The description family on the Objective-C root (proposed ADR-0055 item 1, bead oo-qps.31). See
OODescription.h. Foundation-free: this file imports nothing from gnustep-base (the unit test
tests/unit/oofnd/test_objc_plist.mm links it against libobjc2 alone). Since bead oo-8sql7 it holds
no Objective-C class or category: the root's defaults are the C++ functions below.

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

#include "OODescription.h"

#include "oofnd/String.hpp"

#include <objc/runtime.h>


namespace {

// Whether <object>'s class is <root> or a subclass of it.
bool IsKindOf(id object, Class root)
{
	for (Class cls = object_getClass(object); cls != Nil; cls = class_getSuperclass(cls))
	{
		if (cls == root)  return true;
	}
	return false;
}


// Whether <object> is rooted on OOObject (so it answers the C++ family).
bool IsOOObject(id object)
{
	return IsKindOf(object, [OOObject class]);
}


// A string literal (OOConstantString, OOTinyString) describes itself as its text, in both forms:
// what the category OOConstantString (OODescription) answered until bead oo-8sql7.
bool IsLiteral(id object)
{
	return IsKindOf(object, [OOConstantString class]);
}

// Whether <object>'s class (or a superclass, or a category on one) has its own method for
// <selector>, so the object answers it rather than the root's default. false for nil.
bool AnswersItself(id object, SEL selector)
{
	return object != nil && class_respondsToSelector(object_getClass(object), selector);
}

}	// namespace


/*	The root's description family (bead oo-8sql7): the bodies of the deleted category
	OOObject (OODescription), for an object whose class has no method of its own. A class that has
	one is sent it, as the message was; nil answers nullopt, as the message to nil did.
*/
namespace oo {

std::optional<std::string> ObjectDescriptionComponents(id object)
{
	if (AnswersItself(object, @selector(cxx_descriptionComponents)))  return [object cxx_descriptionComponents];
	return std::nullopt;
}


std::optional<std::string> ObjectShortDescriptionComponents(id object)
{
	if (AnswersItself(object, @selector(cxx_shortDescriptionComponents)))  return [object cxx_shortDescriptionComponents];
	return std::nullopt;
}


std::optional<std::string> ObjectDescription(id object)
{
	if (object == nil)  return std::nullopt;
	if (AnswersItself(object, @selector(cxx_description)))  return [object cxx_description];
	return DescriptionWithComponents(object, ObjectDescriptionComponents(object));
}


std::optional<std::string> ObjectShortDescription(id object)
{
	if (object == nil)  return std::nullopt;
	if (AnswersItself(object, @selector(cxx_shortDescription)))  return [object cxx_shortDescription];
	return DescriptionWithComponents(object, ObjectShortDescriptionComponents(object));
}


std::string DescriptionOf(id object)
{
	if (object == nil)  return "(null)";
	if (class_isMetaClass(object_getClass(object)))  return class_getName((Class)object);
	if (IsLiteral(object))  return [(OOConstantString *)object UTF8String];
	if (IsOOObject(object))
	{
		return ObjectDescription(object).value_or("(null)");
	}
	// An object on another root (nothing in the game since oo-3rb.4 made every literal an
	// OOConstantString and oo-qps.18 unlinked gnustep-base): <ClassName 0xnnnnnnnn>.
	return DescriptionWithComponents(object, std::nullopt);
}


std::string ShortDescriptionOf(id object)
{
	if (object == nil)  return "(null)";
	if (class_isMetaClass(object_getClass(object)))  return class_getName((Class)object);
	if (IsLiteral(object))  return [(OOConstantString *)object UTF8String];
	if (IsOOObject(object))
	{
		return ObjectShortDescription(object).value_or("(null)");
	}
	return DescriptionWithComponents(object, std::nullopt);	// another root, as DescriptionOf
}


std::string DescriptionWithComponents(id object, const std::optional<std::string> &components)
{
	std::string result = str::format("<%s %s>", class_getName([object class]), str::pointerDescription(object).c_str());
	if (components.has_value())  result += "{" + *components + "}";
	return result;
}

}	// namespace oo
