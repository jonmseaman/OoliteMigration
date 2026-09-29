/*

OODescription.mm

The description family on the Objective-C root (proposed ADR-0055 item 1, bead oo-qps.31). See
OODescription.h. Foundation-free: this file imports nothing from gnustep-base (the unit test
tests/unit/oofnd/test_objc_description.mm links it against libobjc2 alone).

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

#import "OODescription.h"

#include "oofnd/String.hpp"

#include <objc/runtime.h>


/*	TRANSITIONAL (ADR-0055 item 1): the legacy id-typed family, as the forwarding below sends it
	to a class that still overrides it and to an object not rooted on OOObject. The text object
	those return answers -UTF8String. oo-qps.43 flips the overrides; oo-qps.72 deletes this.
*/
@protocol OOLegacyDescription
- (id) description;
- (id) descriptionComponents;
- (id) shortDescription;
- (id) shortDescriptionComponents;
- (const char *) UTF8String;
@end


namespace {

using LegacyObject = id<OOLegacyDescription>;


// Whether <object>'s class implements the legacy <selector> other than as the root's own default.
bool HasLegacyOverride(id object, SEL selector)
{
	Class cls = object_getClass(object);
	if (!class_respondsToSelector(cls, selector))  return false;
	return class_getMethodImplementation(cls, selector) != class_getMethodImplementation([OOObject class], selector);
}


// Whether <object> is rooted on OOObject (so it answers the C++ family).
bool IsOOObject(id object)
{
	for (Class cls = object_getClass(object); cls != Nil; cls = class_getSuperclass(cls))
	{
		if (cls == [OOObject class])  return true;
	}
	return false;
}


// "%@" of an object not rooted on OOObject: the text of its -description (a string's is itself,
// so this reads it rather than describing it again).
std::string ForeignDescription(id description)
{
	if (description == nil)  return "(null)";
	const char *text = [(LegacyObject)description UTF8String];
	return text != nullptr ? std::string(text) : std::string();
}


// A legacy method's text result: nullopt for nil, else "%@" of it (a string prints as itself).
std::optional<std::string> LegacyText(id text)
{
	if (text == nil)  return std::nullopt;
	return oo::DescriptionOf(text);
}

}	// namespace


@implementation OOObject (OODescription)

- (std::optional<std::string>) cxx_descriptionComponents
{
	if (HasLegacyOverride(self, @selector(descriptionComponents)))  return LegacyText([(LegacyObject)self descriptionComponents]);
	return std::nullopt;
}


- (std::optional<std::string>) cxx_shortDescriptionComponents
{
	if (HasLegacyOverride(self, @selector(shortDescriptionComponents)))  return LegacyText([(LegacyObject)self shortDescriptionComponents]);
	return std::nullopt;
}


- (std::optional<std::string>) cxx_description
{
	if (HasLegacyOverride(self, @selector(description)))  return LegacyText([(LegacyObject)self description]);
	return oo::DescriptionWithComponents(self, [self cxx_descriptionComponents]);
}


- (std::optional<std::string>) cxx_shortDescription
{
	if (HasLegacyOverride(self, @selector(shortDescription)))  return LegacyText([(LegacyObject)self shortDescription]);
	return oo::DescriptionWithComponents(self, [self cxx_shortDescriptionComponents]);
}

@end


@implementation OOConstantString (OODescription)

- (std::optional<std::string>) cxx_description
{
	return std::string([self UTF8String]);
}


- (std::optional<std::string>) cxx_shortDescription
{
	return std::string([self UTF8String]);
}

@end


namespace oo {

std::string DescriptionOf(id object)
{
	if (object == nil)  return "(null)";
	if (class_isMetaClass(object_getClass(object)))  return class_getName((Class)object);
	if (IsOOObject(object))
	{
		return [(OOObject *)object cxx_description].value_or("(null)");
	}
	return ForeignDescription([(LegacyObject)object description]);
}


std::string ShortDescriptionOf(id object)
{
	if (object == nil)  return "(null)";
	if (class_isMetaClass(object_getClass(object)))  return class_getName((Class)object);
	if (IsOOObject(object))
	{
		return [(OOObject *)object cxx_shortDescription].value_or("(null)");
	}
	return ForeignDescription([(LegacyObject)object shortDescription]);
}


std::string DescriptionWithComponents(id object, const std::optional<std::string> &components)
{
	std::string result = str::format("<%s %s>", class_getName([object class]), str::pointerDescription(object).c_str());
	if (components.has_value())  result += "{" + *components + "}";
	return result;
}

}	// namespace oo
