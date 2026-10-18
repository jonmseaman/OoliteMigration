/*

OOEntityHold.h

TRANSITIONAL (ADR-0056 amendment oo-9ht.39.26): how the universe owns an entity while the root
facade (Entity+ObjCBridge.h) still exists. The entity's Objective-C object owns its C++ part and is
what the JS wrappers, the weak references and oo::ToObjC()'s peer map hang on, so an owning list
keeps the OBJECT alive exactly as long as it did; the holder retains the object and answers the
C++ entity. With the facade's deletion (oo-9ht.39 step 5k) oo::EntityHold becomes
oo::Ref<cxx::Entity> here, in one place, and the retain/release helpers become the part's.

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

#ifndef OO_ENTITY_HOLD_H
#define OO_ENTITY_HOLD_H

#import "OOCocoa.h"
#include "oofnd/Ref.hpp"
#include "oofnd/objc/OOObjCRef.h"

#include <cstddef>

@class Entity;
namespace cxx { class Entity; }


namespace oo {

// Entity+ObjCBridge.h: the entity's Objective-C object, borrowed; nil for null.
::Entity *ToObjC(cxx::Entity *entity);


/*	An owning reference to an entity: retains the entity's Objective-C object (what an
	oo::ObjCRef<::Entity *> of it retained) and answers its C++ entity. Null for null, and for an
	Objective-C entity whose object has gone (oo::ToObjC() answers nil), as a reference to nil was.
*/
class EntityHold
{
public:
	EntityHold() noexcept = default;
	EntityHold(std::nullptr_t) noexcept {}
	explicit EntityHold(cxx::Entity *entity) : _object(ToObjC(entity)), _entity(_object.get() != nil ? entity : nullptr) {}

	cxx::Entity *get() const noexcept  { return _entity; }
	cxx::Entity *operator->() const noexcept  { return _entity; }
	explicit operator bool() const noexcept  { return _entity != nullptr; }

	friend bool operator==(const EntityHold &a, const EntityHold &b) noexcept  { return a._entity == b._entity; }
	friend bool operator==(const EntityHold &a, const cxx::Entity *b) noexcept  { return a._entity == b; }

private:
	ObjCRef<::Entity *>	_object;
	cxx::Entity			*_entity = nullptr;
};


/*	The entity's object's reference count, for the universe's +1 creators and the references the
	universe kept by hand (Entity+ObjCBridge.mm): -retain, -release and -autorelease of
	oo::ToObjC(entity), the same messages; nothing for null. RetainEntity() answers its argument.
*/
cxx::Entity *RetainEntity(cxx::Entity *entity);
void ReleaseEntity(cxx::Entity *entity);
cxx::Entity *AutoreleaseEntity(cxx::Entity *entity);

/*	A C++ entity just made, given its Objective-C object (oo::NewEntityFacade(), autoreleased, as
	the creators made it); answers the entity (null for null). Call it once, where it is made.
*/
cxx::Entity *MadeEntity(const Ref<cxx::Entity> &entity);

}	// namespace oo

#endif	// OO_ENTITY_HOLD_H
