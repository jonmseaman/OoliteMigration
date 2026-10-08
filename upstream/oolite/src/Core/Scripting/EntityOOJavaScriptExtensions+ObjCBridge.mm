/*

EntityOOJavaScriptExtensions+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, amendments oo-ppc and oo-ykoy): the categories Entity
(OOJavaScriptExtensions) and ShipEntity (OOJavaScriptExtensions), which the engine and the
bindings reach by selector and which subclasses override. Each method forwards to the free
function that holds its body (EntityOOJavaScriptExtensions.mm). Deleted with
EntityOOJavaScriptExtensions+ObjCBridge.h.

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

#import "EntityOOJavaScriptExtensions.h"
#import "ShipEntity.h"


@implementation Entity (OOJavaScriptExtensions)

// The class questions go to the C++ part, whose defaults are these bodies and which a C++ subclass
// without a façade of its own overrides (ADR-0056 amendment oo-9ht.107).
- (BOOL) isVisibleToScripts													{ return _cxxEntity->isVisibleToScripts(); }
- (std::optional<std::string>) cxx_oo_jsClassName							{ return _cxxEntity->jsClassName(); }
- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context			{ return EntityJSValueInContext(self, context); }

- (void) getJSClass:(ooscript::ClassDef **)outClass andPrototype:(ooscript::Object *)outPrototype
{
	_cxxEntity->getJSClass(outClass, outPrototype);
}

- (void) deleteJSSelf														{ EntityJSDeleteJSSelf(self); }

@end


@implementation ShipEntity (OOJavaScriptExtensions)

- (BOOL) isVisibleToScripts													{ return ShipEntityJSIsVisibleToScripts(); }

// To the C++ part, whose ShipEntity bodies are ShipEntityJS* and which cxx::StationEntity overrides.
- (void) getJSClass:(ooscript::ClassDef **)outClass andPrototype:(ooscript::Object *)outPrototype
{
	_cxxEntity->getJSClass(outClass, outPrototype);
}

- (std::optional<std::string>) cxx_oo_jsClassName							{ return _cxxEntity->jsClassName(); }
- (std::vector<oo::ObjCRef<Entity *>>) subEntitiesForScript				{ return ShipEntityJSSubEntitiesForScript(self); }
- (void) setTargetForScript:(ShipEntity *)target							{ ShipEntityJSSetTargetForScript(self, target); }

@end
