/*

OOJSEntity.h

JavaScript proxy for entities.

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

#import "OOCocoa.h"
#import "OOJavaScriptEngine.h"
#import "Universe.h"
#include "oofnd/StdLib.hpp"
#import "Entity.h"
#include "OOJSEntityHolder.h"

@class Entity;

#ifdef __cplusplus
extern "C" {
#endif

void InitOOJSEntity(ooscript::Context context, ooscript::Object global);

// The C++ entity (bead oo-9ht.39.3: the slot holds it; the facade before), or null for a stale one.
bool JSValueToEntity(ooscript::Context context, ooscript::Value value, cxx::Entity **outEntity);

// The Entity class is an ooscript::ClassDef owned by OOJSEntity.mm (bead oo-oap); JSEntityClass()
// returns it. Declared as a real function rather than OOINLINE so the class definition stays
// private to OOJSEntity.mm.
ooscript::ClassDef *JSEntityClass(void);

#ifdef __cplusplus
}
#endif

extern ooscript::Object gOOEntityJSPrototype;


/*	OOJSEntityGetEntity was DEFINE_JS_OBJECT_GETTER's getter of the Entity class until
	bead oo-9ht.39.3 (ADR-0056 amendment oo-9ht.39.3): the slot holds an OOJSEntityHolder, so the
	getter is OOJSGetCxxPrivate's (the same JS class check and error) and answers the C++ entity,
	null for a stale one (or a prototype). The JS class fixes what the slot holds, so the
	Objective-C class check of the debug build has nothing left to check. A binding's own class
	(Ship, Planet, Sun) passes its JS class as DEFINE_JS_OBJECT_GETTER did.
*/
OOINLINE bool OOJSEntityGetEntityOfClass(ooscript::Context context, ooscript::Object inObject, ooscript::ClassDef *jsClass, cxx::Entity **outEntity)
{
	OOJSEntityHolder *holder = nullptr;
	if (!OOJSGetCxxPrivate(context, inObject, jsClass, &holder))  return false;
	*outEntity = (holder != nullptr) ? holder->entity() : nullptr;
	return true;
}

OOINLINE bool OOJSEntityGetEntity(ooscript::Context context, ooscript::Object inObject, cxx::Entity **outEntity)
{
	return OOJSEntityGetEntityOfClass(context, inObject, JSEntityClass(), outEntity);
}


/*	OOJSNativeObjectOfClassFromJSValue(context, value, [Entity class]) for a C++ caller (bead
	oo-9ht.39.3): the entity an entity's JS object holds, else null, with no error (another value,
	another object, a stale entity), as that answered nil.
*/
cxx::Entity *OOJSEntityFromJSValue(ooscript::Context context, ooscript::Value value);

// The object of the entity an entity's JS object (of any entity class) holds, nil for a stale one:
// what the slot's weak reference answered until bead oo-9ht.39.3, for the conversions that take an
// entity's position or orientation (OOJSVector, OOJSQuaternion), which still message the object.
// The object must be of the Entity class or a subclass.
Entity *OOJSEntityObjectFromJSObject(ooscript::Context context, ooscript::Object object);

// OOJSBasicPrivateObjectConverter for the entity classes (each registers it): the entity's object
// (its facade, which code converting a JS value still expects) as an Object node, a null PList
// once the entity has gone, as the slot's weak reference answered.
oo::PList OOJSEntityObjectConverter(ooscript::Context context, ooscript::Object object);

// toString() of the entity classes: OOJSCxxObjectWrapperToString for the Entity class and its
// subclasses (the entity's jsDescription(), else "[object <JS class name>]").
bool OOJSEntityToString(ooscript::Context context, ooscript::CallArgs &oojsArgs);

OOINLINE ooscript::Object JSEntityPrototype(void)  { return gOOEntityJSPrototype; }

/*	EntityFromArgumentList()
	
	Construct a entity from an argument list containing a JS Entity object.
	The optional outConsumed argument can be used to find out how many
	parameters were used (currently, this will be 0 on failure, otherwise 1).
	
	On failure, it will return false, annd the entity will be unaltered. If
	scriptClass and function are non-nil, a warning will be reported to the
	log.
*/
#ifdef __cplusplus
extern "C" {
#endif
extern "C++" {	// C++ parameters (proposed ADR-0043, bead oo-emib); nullopt class or function: no warning (was nil)
bool EntityFromArgumentList(ooscript::Context context, const std::optional<std::string> &scriptClass, const std::optional<std::string> &function, unsigned argc, ooscript::Value *argv, cxx::Entity **outEntity, unsigned *outConsumed);
}
#ifdef __cplusplus
}
#endif

/*
	For scripting purposes, a JS entity object is a stale reference if its
	underlying ObjC object is nil, or if it refers to the player and the
	blockJSPlayerShipProps flag is in effect (i.e., the escape pod sequence is
	active).
*/
OOINLINE bool OOIsPlayerStale(void)
{
	extern Entity *gOOJSPlayerIfStale;
	return gOOJSPlayerIfStale != nil;
}

OOINLINE bool OOIsStaleEntity(Entity *entity)
{
	extern Entity *gOOJSPlayerIfStale;
	return entity == nil || (entity == gOOJSPlayerIfStale);
}

// The same of the C++ entity a getter answers (bead oo-9ht.39.3); the player's object is the global.
OOINLINE bool OOIsStaleEntity(cxx::Entity *entity)
{
	extern Entity *gOOJSPlayerIfStale;
	return entity == nullptr || (gOOJSPlayerIfStale != nil && entity == oo::ToCxx(gOOJSPlayerIfStale));
}
