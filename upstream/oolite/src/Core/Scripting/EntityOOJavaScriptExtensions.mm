/*

EntityOOJavaScriptExtensions.m

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
#import "OOFoundationBridge.h"
#include "oofnd/Notification.hpp"


@implementation Entity (OOJavaScriptExtensions)

- (BOOL) isVisibleToScripts
{
	return NO;
}


- (std::optional<std::string>) cxx_oo_jsClassName
{
	return std::string("Entity");
}


- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context
{
	ooscript::ClassDef					*jsClass = NULL;
	ooscript::Object prototype = NULL;
	ooscript::Value					result = ooscript::nullValue();
	
	if (_cxxEntity->_jsSelf == NULL && [self isVisibleToScripts])
	{
		// Create JS object
		[self getJSClass:&jsClass andPrototype:&prototype];
		
		_cxxEntity->_jsSelf = ooscript::newObject(context, jsClass, prototype, NULL);
		if (_cxxEntity->_jsSelf != NULL)
		{
			if (!ooscript::setPrivate(context, _cxxEntity->_jsSelf, OOConsumeReference([self weakRetain])))  _cxxEntity->_jsSelf = NULL;
		}
		
		if (_cxxEntity->_jsSelf != NULL)
		{
			OOJSAddGCObjectRoot(context, &_cxxEntity->_jsSelf, "Entity jsSelf");
			oo::NotificationCenter::defaultCenter().addObserver(self, kOOJavaScriptEngineWillResetNotificationName,
																[OOJavaScriptEngine sharedEngine],
																[self](const oo::Notification &) { [self deleteJSSelf]; });
		}
	}
	
	if (_cxxEntity->_jsSelf != NULL)  result = ooscript::objectValue(_cxxEntity->_jsSelf);
	
	return result;
	// Analyzer: object leaked. [Expected, object is retained by JS object.]
}


- (void) getJSClass:(ooscript::ClassDef **)outClass andPrototype:(ooscript::Object *)outPrototype
{
	*outClass = JSEntityClass();
	*outPrototype = JSEntityPrototype();
}


- (void) deleteJSSelf
{
	if (_cxxEntity->_jsSelf != NULL)
	{
		_cxxEntity->_jsSelf = NULL;
		ooscript::Context context = OOJSAcquireContext();
		ooscript::removeObjectRoot(context, &_cxxEntity->_jsSelf);
		OOJSRelinquishContext(context);
		
		oo::NotificationCenter::defaultCenter().removeObserver(self, kOOJavaScriptEngineWillResetNotificationName,
																[OOJavaScriptEngine sharedEngine]);
	}
}

@end


@implementation ShipEntity (OOJavaScriptExtensions)

- (BOOL) isVisibleToScripts
{
	return YES;
}


- (void) getJSClass:(ooscript::ClassDef **)outClass andPrototype:(ooscript::Object *)outPrototype
{
	*outClass = JSShipClass();
	*outPrototype = JSShipPrototype();
}


- (std::optional<std::string>) cxx_oo_jsClassName
{
	return std::string("Ship");
}


- (std::vector<oo::ObjCRef<Entity *>>) subEntitiesForScript
{
	std::vector<oo::ObjCRef<Entity *>> result;
	for (const auto &sub : [self cxx_shipSubEntities])
	{
		result.emplace_back(sub.get());
	}
	return result;
}


- (void) setTargetForScript:(ShipEntity *)target
{
	ShipEntity *me = self;
	
	// Ensure coherence by not fiddling with subentities.
	while ([me isSubEntity])
	{
		if (me == [me owner] || [me owner] == nil)  break;
		me = (ShipEntity *)[me owner];
	}
	while ([target isSubEntity])
	{
		if (target == [target owner] || [target owner] == nil)  break;
		target = (ShipEntity *)[target owner];
	}
	if (![me isKindOfClass:[ShipEntity class]])  return;
	if (target != nil)
	{
		[me addTarget:target];
	}
	else  [me removeTarget:[me primaryTarget]];
}

@end

