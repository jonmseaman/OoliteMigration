/*

OOEntityCalledByName.h

The entities' methods called by name, as a C++ table (bead oo-9ht.39.7.1, ADR-0056 amendment
oo-9ht.39.7.1): the rows tools/gen-entity-by-name-table.py generates from the facade's by-name
categories (OOEntityCalledByNameTable.h), one per method, with the categories' names exactly.
The callers use oo::CallEntityByName and oo::EntityRespondsToName (OOCallByName.h); the rows are
here for them and for the test that proves them equal to the facade's selectors.

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

#ifndef OOENTITYCALLEDBYNAME_H
#define OOENTITYCALLEDBYNAME_H

#include "oofnd/PList.hpp"
#include <cstdint>
#include <span>
#include <string>

namespace cxx { class Entity; }


// The name sets -[Entity respondsToSelector:] read: a row applies to an entity whose C++ part is
// of a class one of its flags names (a proxy's flag with the player's: the proxy's dials).
enum: unsigned
{
	kOOByNameShip		= 1u << 0,
	kOOByNamePlayer		= 1u << 1,
	kOOByNameProxy		= 1u << 2,
	kOOByNameStation	= 1u << 3,
	kOOByNameDock		= 1u << 4,
	kOOByNameEffect		= 1u << 5,
};

enum class OOEntityByNameArgument: std::uint8_t
{
	None,		// - (T) name
	String,		// - (T) name:(const std::string &)
	PList		// - (T) name:(const oo::PList &)
};

struct OOEntityByNameRow
{
	const char				*name;		// the selector's name
	unsigned				flags;		// kOOByName...
	const char				*result;	// @encode() of the declared result type
	OOEntityByNameArgument	argument;
	// The method's body on the entity, given the argument its kind takes; a PList result, else null.
	oo::PList				(*call)(cxx::Entity *entity, const std::string *string, const oo::PList *plist);
};


namespace oo {

std::span<const OOEntityByNameRow> EntityByNameRows();
const OOEntityByNameRow *EntityByNameRowNamed(const std::string &name);	// null if not tabled
bool EntityByNameRowApplies(const OOEntityByNameRow &row, cxx::Entity *entity);

}	// namespace oo

#endif	// OOENTITYCALLEDBYNAME_H
