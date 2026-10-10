/*

EntityOOJavaScriptExtensions.h

JavaScript support methods for entities.

C++20 since bead oo-g223 (proposed ADR-0056, amendments oo-ppc and oo-ykoy): the bodies of the
categories Entity (OOJavaScriptExtensions) and ShipEntity (OOJavaScriptExtensions), which the
engine and the bindings reach by selector, are the free functions below, one per method, named
after the class the category extends and the selector's first keyword. Since bead oo-9ht.128 the
category Entity (OOJavaScriptExtensions) is the root's facade's (Entity+ObjCBridge.h/.mm, moved
unchanged from EntityOOJavaScriptExtensions+ObjCBridge.h/.mm, which it deleted); ShipEntity's
went with the ship's facade (bead oo-9ht.144) and PlayerEntity's with the player's (oo-9ht.177).
Since bead oo-9ht.39.3 (ADR-0056 amendment oo-9ht.39.3) an entity's JS object holds the C++ entity
(an OOJSEntityHolder, OOJSEntity.h, in its private slot), and the functions that made and dropped
it take the C++ entity.

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


#import "Entity.h"
#import "OOJavaScriptEngine.h"

class ShipEntity;	// C++ since bead oo-9ht.144


// Entity (OOJavaScriptExtensions). Since bead oo-9ht.39.3 the JS object's functions take the C++
// entity (cxx::Entity's JS glue members call them; the root facade's selectors forward to those).
bool EntityJSIsVisibleToScripts(void);
std::optional<std::string> EntityJSClassName(void);
ooscript::Value EntityJSValueInContext(cxx::Entity *entity, ooscript::Context context);
void EntityJSGetJSClass(ooscript::ClassDef **outClass, ooscript::Object *outPrototype);
void EntityJSDeleteJSSelf(cxx::Entity *entity);
std::optional<std::string> EntityJSDescription(cxx::Entity *entity);

// ShipEntity (OOJavaScriptExtensions)
bool ShipEntityJSIsVisibleToScripts(void);
void ShipEntityJSGetJSClass(ooscript::ClassDef **outClass, ooscript::Object *outPrototype);
std::optional<std::string> ShipEntityJSClassName(void);
std::vector<oo::ObjCRef<Entity *>> ShipEntityJSSubEntitiesForScript(ShipEntity *ship);
void ShipEntityJSSetTargetForScript(ShipEntity *ship, ShipEntity *target);

