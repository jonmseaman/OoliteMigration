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


/*	The root's description family (bead oo-8sql7: the bodies of the deleted category OOObject
	(OODescription); oo::ObjectDescription & co.) and the string literal's text went with OOObject and
	OOConstantString (bead oo-4aq6a.8): no object is rooted on OOObject and no literal is compiled.
	What is left describes any other Objective-C object (none in the game) as it did.
*/
namespace oo {

std::string DescriptionOf(id object)
{
	if (object == nil)  return "(null)";
	if (class_isMetaClass(object_getClass(object)))  return class_getName((Class)object);
	// An object on another root (nothing in the game since oo-3rb.4 made every literal an
	// OOConstantString and oo-qps.18 unlinked gnustep-base; OOObject and OOConstantString went with
	// bead oo-4aq6a.8): <ClassName 0xnnnnnnnn>.
	return DescriptionWithComponents(object, std::nullopt);
}


std::string ShortDescriptionOf(id object)
{
	if (object == nil)  return "(null)";
	if (class_isMetaClass(object_getClass(object)))  return class_getName((Class)object);
	return DescriptionWithComponents(object, std::nullopt);	// another root, as DescriptionOf
}


std::string DescriptionWithComponents(id object, const std::optional<std::string> &components)
{
	std::string result = str::format("<%s %s>", class_getName(object_getClass(object))	/* [object class]: no root declares -class since bead oo-4aq6a.8 */, str::pointerDescription(object).c_str());
	if (components.has_value())  result += "{" + *components + "}";
	return result;
}

}	// namespace oo
