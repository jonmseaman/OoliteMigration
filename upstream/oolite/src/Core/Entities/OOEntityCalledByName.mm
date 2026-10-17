/*

OOEntityCalledByName.mm

An entity's method called by name, on its C++ part (bead oo-9ht.39.7.1, ADR-0056 amendment
oo-9ht.39.7.1; declared in OOCallByName.h). The facade's by-name categories are the generated
table OOEntityCalledByNameTable.h (tools/gen-entity-by-name-table.py): a tabled name is answered
for the C++ part it applies to, exactly as -[Entity respondsToSelector:] and the category method
answered it, and called as OOCallByName called the method (the same signature rules, read from
@encode() of the declared types instead of the method's type encoding). Any other name, and a
tabled name whose signature the call cannot use, go to the entity's Objective-C object as before.
callObjC() reads a typed result through oo::CallEntityByNameTyped (bead oo-9ht.39.7.2).

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

#import "OOEntityCalledByName.h"
#import "OOCallByName.h"
#import "Entity.h"
#import "OOEntityWithDrawable.h"
#import "OOVisualEffectEntity.h"
#import "ShipEntity.h"
#import "ShipEntityAI.h"
#import "ShipEntityScriptMethods.h"
#import "PlayerEntity.h"
#import "ProxyPlayerEntity.h"
#import "StationEntity.h"
#import "DockEntity.h"
#import "GameController.h"	// OOScheduleDeferredCall (the player's selectors called by name)
#import "AI.h"
#import "Universe.h"
#import "OODescription.h"
#include "oofnd/objc/OOObjCPeer.h"
#include "oofnd/objc/OORuntime.h"
#include <cstring>
#include <string_view>
#include <type_traits>
#include <unordered_map>


namespace {

// The parts the category methods' bodies read, as the facade's (Entity+ObjCBridge.mm) are.
ShipEntity *ShipPart(cxx::Entity *entity)				{ return dynamic_cast<ShipEntity *>(entity); }
StationEntity *StationPart(cxx::Entity *entity)			{ return dynamic_cast<StationEntity *>(entity); }
DockEntity *DockPart(cxx::Entity *entity)				{ return dynamic_cast<DockEntity *>(entity); }
PlayerEntity *PlayerEntityPart(cxx::Entity *entity)		{ return dynamic_cast<PlayerEntity *>(entity); }
ProxyPlayerEntity *ProxyPart(cxx::Entity *entity)		{ return dynamic_cast<ProxyPlayerEntity *>(entity); }
OOVisualEffectEntity *EffectPart(cxx::Entity *entity)	{ return dynamic_cast<OOVisualEffectEntity *>(entity); }

}	// namespace


// The generated table's row (OOEntityCalledByName.h declares the flags and the argument kinds).
namespace {

template <auto Function>
oo::PList OOEntityByNameAdaptNone(cxx::Entity *entity, const std::string *, const oo::PList *)
{
	if constexpr (std::is_same_v<decltype(Function(entity)), oo::PList>)  return Function(entity);
	else
	{
		(void)Function(entity);
		return oo::PList();
	}
}


template <auto Function>
oo::PList OOEntityByNameAdaptString(cxx::Entity *entity, const std::string *string, const oo::PList *)
{
	if constexpr (std::is_same_v<decltype(Function(entity, *string)), oo::PList>)  return Function(entity, *string);
	else
	{
		(void)Function(entity, *string);
		return oo::PList();
	}
}


template <auto Function>
oo::PList OOEntityByNameAdaptPList(cxx::Entity *entity, const std::string *, const oo::PList *plist)
{
	if constexpr (std::is_same_v<decltype(Function(entity, *plist)), oo::PList>)  return Function(entity, *plist);
	else
	{
		(void)Function(entity, *plist);
		return oo::PList();
	}
}


template <auto Function>
void OOEntityByNameTyped(cxx::Entity *entity, OOEntityByNameValue &value)
{
	using Result = decltype(Function(entity));
	if constexpr (std::is_void_v<Result>)  Function(entity);
	else if constexpr (std::is_same_v<Result, oo::PList>)  value.plist = Function(entity);
	else if constexpr (std::is_integral_v<Result> && std::is_signed_v<Result> && sizeof(Result) == 1)
	{
		// a signed char (BOOL): its value, sign kept, as OOCallIntegerMethod() converted it
		const long long bits = static_cast<unsigned char>(Function(entity));
		value.integer = (bits > 127) ? bits - 256 : bits;
	}
	else if constexpr (std::is_integral_v<Result> || std::is_enum_v<Result>)  value.integer = static_cast<long long>(Function(entity));
	else if constexpr (std::is_floating_point_v<Result>)  value.real = static_cast<double>(Function(entity));
	else if constexpr (std::is_same_v<Result, Vector>)  value.vector = Function(entity);
	else if constexpr (std::is_same_v<Result, Quaternion>)  value.quaternion = Function(entity);
	else if constexpr (std::is_convertible_v<Result, id>)  value.object = Function(entity);
	else  (void)Function(entity);	// a result callObjC() cannot read (it does not call such a method)
}

}	// namespace


#include "OOEntityCalledByNameTable.h"


std::span<const OOEntityByNameRow> oo::EntityByNameRows()
{
	return kOOEntityByNameRows;
}


const OOEntityByNameRow *oo::EntityByNameRowNamed(const std::string &name)
{
	static const std::unordered_map<std::string_view, const OOEntityByNameRow *> rows = [] {
		std::unordered_map<std::string_view, const OOEntityByNameRow *> result;
		for (const OOEntityByNameRow &row : kOOEntityByNameRows)  result.emplace(row.name, &row);
		return result;
	}();
	auto found = rows.find(name);
	return found != rows.end() ? found->second : nullptr;
}


// As -[Entity respondsToSelector:] answered the name sets (the visual effect's first). A name only
// the effect's set holds is answered by the root (super) for any entity, as the facade did; its
// body answers zero for any part but an effect's.
bool oo::EntityByNameRowApplies(const OOEntityByNameRow &row, cxx::Entity *entity)
{
	if (entity == nullptr)  return false;
	const unsigned flags = row.flags;
	if ((flags & kOOByNameEffect) != 0 && EffectPart(entity) != nullptr)  return true;
	if ((flags & (kOOByNameShip | kOOByNamePlayer | kOOByNameStation | kOOByNameDock)) == 0)  return true;
	if ((flags & kOOByNameShip) != 0 && ShipPart(entity) != nullptr)  return true;
	if ((flags & kOOByNamePlayer) != 0 && (flags & kOOByNameProxy) != 0 && ProxyPart(entity) != nullptr)  return true;
	if ((flags & kOOByNamePlayer) != 0 && PlayerEntityPart(entity) != nullptr)  return true;
	return ((flags & kOOByNameStation) != 0 && StationPart(entity) != nullptr) || ((flags & kOOByNameDock) != 0 && DockPart(entity) != nullptr);
}


bool oo::CallEntityByNameTyped(cxx::Entity *entity, const std::string &name, OOEntityByNameValue &value)
{
	const OOEntityByNameRow *row = EntityByNameRowNamed(name);
	if (row == nullptr || row->typed == nullptr || !EntityByNameRowApplies(*row, entity))  return false;
	row->typed(entity, value);
	return true;
}


namespace {

enum class Kind: std::uint8_t
{
	Void,		// a void result, or a scalar result the call ignores
	PList,		// an oo::PList result
	Object,		// an object result, ignored (ADR-0055 Amendment 2)
	Unsupported
};


// As OOCallByName classifies a method's return type encoding (OOCallByName.mm, ResultKind()).
Kind ResultKind(const char *encoding)
{
	std::string_view type = encoding;
	while (!type.empty() && std::strchr("rnNoORV", type.front()) != nullptr)  type.remove_prefix(1);
	if (type == "v")  return Kind::Void;
	if (type == "@")  return Kind::Object;
	if (std::strcmp(encoding, @encode(oo::PList)) == 0)  return Kind::PList;
	if (type.size() == 1 && std::strchr("cCsSiIlLqQfdB", type.front()) != nullptr)  return Kind::Void;
	return Kind::Unsupported;
}


// The row's call with the argument, if OOCallByName would make it (its usable signatures); none
// if the name is not tabled, does not apply to the entity, or the signature is unusable.
std::optional<oo::PList> CallRow(cxx::Entity *entity, const std::string &name, const std::string *string, const oo::PList *plist)
{
	const OOEntityByNameRow *row = oo::EntityByNameRowNamed(name);
	if (row == nullptr || !oo::EntityByNameRowApplies(*row, entity))  return std::nullopt;

	const Kind result = ResultKind(row->result);
	const bool hasArgument = (string != nullptr || plist != nullptr);
	if (hasArgument != (row->argument != OOEntityByNameArgument::None) || result == Kind::Unsupported)  return std::nullopt;

	// A string reaches a PList parameter as a string PList; a PList reaches a string parameter
	// only when it is a string.
	oo::PList stringAsPList;
	if (row->argument == OOEntityByNameArgument::String && plist != nullptr)
	{
		string = plist->getIf<std::string>();
		if (string == nullptr)  return std::nullopt;
	}
	if (row->argument == OOEntityByNameArgument::PList)
	{
		if (result != Kind::Void && result != Kind::Object)  return std::nullopt;
		if (string != nullptr)
		{
			stringAsPList = oo::PList(*string);
			plist = &stringAsPList;
		}
	}

	oo::PList answer = row->call(entity, string, plist);
	// only a PList result is the call's result; a void, scalar or object result is ignored
	return (result == Kind::PList) ? std::move(answer) : oo::PList();
}


SEL SelectorNamed(const std::string &name)
{
	return OOSelectorFromName(name.c_str());
}

}	// namespace


bool oo::EntityRespondsToName(cxx::Entity *entity, const std::string &name)
{
	if (entity == nullptr)  return false;
	if (const OOEntityByNameRow *row = EntityByNameRowNamed(name))  return EntityByNameRowApplies(*row, entity);
	::Entity *object = oo::ToObjC(entity);
	return object != nil && [object respondsToSelector:SelectorNamed(name)];
}


oo::PList oo::CallEntityByName(cxx::Entity *entity, const std::string &name)
{
	if (entity == nullptr)  return PList();
	if (std::optional<PList> result = CallRow(entity, name, nullptr, nullptr))  return *result;
	return OOCallByName(oo::ToObjC(entity), SelectorNamed(name));
}


oo::PList oo::CallEntityByName(cxx::Entity *entity, const std::string &name, const std::string &argument)
{
	if (entity == nullptr)  return PList();
	if (std::optional<PList> result = CallRow(entity, name, &argument, nullptr))  return *result;
	return OOCallByName(oo::ToObjC(entity), SelectorNamed(name), argument);
}


oo::PList oo::CallEntityByName(cxx::Entity *entity, const std::string &name, const PList &argument)
{
	if (entity == nullptr)  return PList();
	if (std::optional<PList> result = CallRow(entity, name, nullptr, &argument))  return *result;
	return OOCallByName(oo::ToObjC(entity), SelectorNamed(name), argument);
}
