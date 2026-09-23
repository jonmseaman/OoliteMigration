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

#import <Foundation/Foundation.h>
#import "OOJavaScriptEngine.h"
#import "Universe.h"

@class Entity;


#ifdef __cplusplus
extern "C" {
#endif

void InitOOJSEntity(ooscript::Context context, ooscript::Object global);

BOOL JSValueToEntity(ooscript::Context context, ooscript::Value value, Entity **outEntity);

// The Entity class is an ooscript::ClassDef owned by OOJSEntity.mm (bead oo-oap); JSEntityClass()
// returns it. Declared as a real function rather than OOINLINE so the class definition stays
// private to OOJSEntity.mm.
ooscript::ClassDef *JSEntityClass(void);

#ifdef __cplusplus
}
#endif

extern ooscript::Object gOOEntityJSPrototype;
DEFINE_JS_OBJECT_GETTER(OOJSEntityGetEntity, JSEntityClass(), gOOEntityJSPrototype, Entity)

OOINLINE ooscript::Object JSEntityPrototype(void)  { return gOOEntityJSPrototype; }


/*	EntityFromArgumentList()
	
	Construct a entity from an argument list containing a JS Entity object.
	The optional outConsumed argument can be used to find out how many
	parameters were used (currently, this will be 0 on failure, otherwise 1).
	
	On failure, it will return NO, annd the entity will be unaltered. If
	scriptClass and function are non-nil, a warning will be reported to the
	log.
*/
#ifdef __cplusplus
extern "C" {
#endif
BOOL EntityFromArgumentList(ooscript::Context context, NSString *scriptClass, NSString *function, unsigned argc, ooscript::Value *argv, Entity **outEntity, unsigned *outConsumed);
#ifdef __cplusplus
}
#endif


/*
	For scripting purposes, a JS entity object is a stale reference if its
	underlying ObjC object is nil, or if it refers to the player and the
	blockJSPlayerShipProps flag is in effect (i.e., the escape pod sequence is
	active).
*/
OOINLINE BOOL OOIsPlayerStale(void)
{
	extern Entity *gOOJSPlayerIfStale;
	return gOOJSPlayerIfStale != nil;
}

OOINLINE BOOL OOIsStaleEntity(Entity *entity)
{
	extern Entity *gOOJSPlayerIfStale;
	return entity == nil || (entity == gOOJSPlayerIfStale);
}
