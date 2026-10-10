/*

EntityOOJavaScriptExtensions.m

C++20 since bead oo-g223 (proposed ADR-0056, amendments oo-ppc and oo-ykoy): the bodies of the
categories Entity (OOJavaScriptExtensions) and ShipEntity (OOJavaScriptExtensions) as free
functions (EntityOOJavaScriptExtensions.h). A method that used self takes the object as its first
parameter, and its messages to the object stay messages: the categories are overridden by
subclasses that are still Objective-C. The categories' forwarders are in
EntityOOJavaScriptExtensions+ObjCBridge.mm.

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
#import "OOJSEntity.h"
#import "OOJSShip.h"
#import "OOJSStation.h"
#import "StationEntity.h"
#import "OOJSDock.h"
#import "DockEntity.h"
#import "OOPlanetEntity.h"
#import "OOVisualEffectEntity.h"
#import "OOJSVisualEffect.h"
#import "WormholeEntity.h"
#import "OOJSWormhole.h"
#include "oofnd/Notification.hpp"
#include "oofnd/String.hpp"
#include "OOJSPrivateObject.h"


// MARK: Entity (OOJavaScriptExtensions)

bool EntityJSIsVisibleToScripts(void)
{
	return false;
}


std::optional<std::string> EntityJSClassName(void)
{
	return std::string("Entity");
}


/*	The entity's JS object (bead oo-9ht.39.3, ADR-0056 amendment oo-9ht.39.3): made on first use
	for an entity that scripts can see, of the class and prototype the entity names, its private
	slot an OOJSEntityHolder (a weak reference to the entity, as the slot held the facade's weak
	reference: the JS object does not keep the entity alive), rooted while the entity lives and
	dropped when the engine resets. The body is the one the facade's JS value selector ran, asking the
	C++ entity what it asked the facade (whose selectors answered from the C++ part).
*/
/*	The class questions the facade's JS value selector asked by selector: an Objective-C entity's
	own override answered first (the adapter does not forward them), a C++ entity's members answered
	through the root facade's category. Exported since bead oo-9ht.39.5.1 for the engine's generic
	paths that asked an entity's object (OOJSSystem's planets filter, callObjC()'s class name).
*/
bool OOJSEntityIsVisibleToScripts(cxx::Entity *entity)
{
	if (entity == nullptr)  return false;	// nil's answer
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return [link->objcOwner() isVisibleToScripts];
	return entity->isVisibleToScripts();
}


std::optional<std::string> OOJSEntityJSClassName(cxx::Entity *entity)
{
	if (entity == nullptr)  return std::nullopt;	// nil's answer
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return [link->objcOwner() cxx_oo_jsClassName];
	return entity->jsClassName();
}


namespace {

void GetJSClass(cxx::Entity *entity, ooscript::ClassDef **outClass, ooscript::Object *outPrototype)
{
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  [link->objcOwner() getJSClass:outClass andPrototype:outPrototype];
	else  entity->getJSClass(outClass, outPrototype);
}

}	// namespace


ooscript::Value EntityJSValueInContext(cxx::Entity *entity, ooscript::Context context)
{
	ooscript::ClassDef					*jsClass = NULL;
	ooscript::Object prototype = NULL;
	ooscript::Value					result = ooscript::nullValue();
	
	if (entity->_jsSelf == NULL && OOJSEntityIsVisibleToScripts(entity))
	{
		// Create JS object
		GetJSClass(entity, &jsClass, &prototype);
		
		entity->_jsSelf = ooscript::newObject(context, jsClass, prototype, NULL);
		if (entity->_jsSelf != NULL)
		{
			const oo::Ref<OOJSEntityHolder> holder = oo::makeRef<OOJSEntityHolder>(entity);
			if (!OOJSSetCxxPrivate(context, entity->_jsSelf, holder.get()))  entity->_jsSelf = NULL;
		}
		
		if (entity->_jsSelf != NULL)
		{
			OOJSAddGCObjectRoot(context, &entity->_jsSelf, "Entity jsSelf");
			oo::NotificationCenter::defaultCenter().addObserver(entity, kOOJavaScriptEngineWillResetNotificationName,
																[OOJavaScriptEngine sharedEngine],
																[entity](const oo::Notification &) { entity->deleteJSSelf(); });
		}
	}
	
	if (entity->_jsSelf != NULL)  result = ooscript::objectValue(entity->_jsSelf);
	
	return result;
}


void EntityJSGetJSClass(ooscript::ClassDef **outClass, ooscript::Object *outPrototype)
{
	*outClass = JSEntityClass();
	*outPrototype = JSEntityPrototype();
}


void EntityJSDeleteJSSelf(cxx::Entity *entity)
{
	if (entity->_jsSelf != NULL)
	{
		entity->_jsSelf = NULL;
		ooscript::Context context = OOJSAcquireContext();
		ooscript::removeObjectRoot(context, &entity->_jsSelf);
		OOJSRelinquishContext(context);
		
		oo::NotificationCenter::defaultCenter().removeObserver(entity, kOOJavaScriptEngineWillResetNotificationName,
																[OOJavaScriptEngine sharedEngine]);
	}
}


/*	What the facade's -cxx_oo_jsDescription answered (OOObject (OOJavaScriptConversion)'s
	OOObjectJSDescription): "[<JS class name> <components>]", or "[object <JS class name>]" with no
	components; the JS class name is -cxx_oo_jsClassName's (the C++ entity's jsClassName()), else
	the Objective-C class's name, the root facade's ("Entity") for a C++ entity. An Objective-C
	entity is still asked by selector.
*/
std::optional<std::string> EntityJSDescription(cxx::Entity *entity)
{
	if (entity == nullptr)  return std::nullopt;	// (the holder asks only a live entity)
	if (oo::ObjCEntityLink *link = oo::AsObjCEntity(entity))  return OOJavaScriptEngineJSDescription(link->objcOwner());	// its own selectors, as before
	std::optional<std::string> name = entity->jsClassName();
	if (!name.has_value())  name = std::string("Entity");	// the root facade's class
	if (const std::optional<std::string> components = entity->descriptionComponents())
	{
		return oo::str::format("[%s %s]", name->c_str(), components->c_str());
	}
	return oo::str::format("[object %s]", name->c_str());
}


// MARK: ShipEntity (OOJavaScriptExtensions)

bool ShipEntityJSIsVisibleToScripts(void)
{
	return true;
}


void ShipEntityJSGetJSClass(ooscript::ClassDef **outClass, ooscript::Object *outPrototype)
{
	*outClass = JSShipClass();
	*outPrototype = JSShipPrototype();
}


std::optional<std::string> ShipEntityJSClassName(void)
{
	return std::string("Ship");
}


std::vector<oo::ObjCRef<::Entity *>> ShipEntityJSSubEntitiesForScript(ShipEntity *ship)
{
	std::vector<oo::ObjCRef<::Entity *>> result;
	for (const auto &sub : (ship != nullptr ? ship->shipSubEntities() : std::vector<oo::ObjCRef<::Entity *>>()))
	{
		result.emplace_back(sub.get());
	}
	return result;
}


void ShipEntityJSSetTargetForScript(ShipEntity *ship, ShipEntity *target)
{
	ShipEntity *me = ship;
	
	// Ensure coherence by not fiddling with subentities.
	while ((me != nullptr ? me->getIsSubEntity() : false))
	{
		if (oo::ToObjC(me) == (me != nullptr ? me->owner() : id{}) || (me != nullptr ? me->owner() : id{}) == nil)  break;
		me = oo::ToShip((me != nullptr ? me->owner() : id{}));
	}
	while ((target != nullptr ? target->getIsSubEntity() : false))
	{
		if (oo::ToObjC(target) == (target != nullptr ? target->owner() : id{}) || (target != nullptr ? target->owner() : id{}) == nil)  break;
		target = oo::ToShip((target != nullptr ? target->owner() : id{}));
	}
	if (!(oo::ToShip(oo::ToObjC(me)) != nullptr))  return;
	if (target != nil)
	{
		if (me != nullptr)  me->addTarget(oo::ToObjC(target));
	}
	else  { if (me != nullptr)  me->removeTarget((me != nullptr ? me->primaryTarget() : id{})); }
}
