/*

OOVisualEffectEntity+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, bead oo-ukxy8): the Objective-C OOVisualEffectEntity façade's own
methods: its initialisers, which make the C++ effect and run its body, and one-line forwarders to
cxx::OOVisualEffectEntity for slice 1's selectors, the OOSubEntity protocol and the subentity
relationship. See OOVisualEffectEntity+ObjCBridge.h.

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

#import "OOVisualEffectEntity.h"
#import "OOMesh.h"
#import "OOFlasherEntity.h"
#import "ShipEntity.h"


@implementation OOVisualEffectEntity

- (id) init
{
	return [self cxx_initWithKey:std::string{} definition:oo::PList()];
}


// [[OOVisualEffectEntity alloc] cxx_initWithKey:definition:] (the universe): a C++ effect, then the
// initialiser's body (amendment oo-0mxi item 2), which may fail, as the Objective-C one did. Sent
// again, it keeps the C++ part and runs the body again.
- (id)cxx_initWithKey:(const std::string &)key definition:(const oo::PList &)dict
{
	if (_cxxEntity != nullptr)  self = [super initWithCxxEntity:_cxxEntity.get()];
	else  self = [super initWithCxxEntity:oo::makeRef<cxx::OOVisualEffectEntity>().get()];
	if (self == nil)  return nil;

	if (!oo::ToCxx(self)->initWithKey(key, dict))
	{
		[self release];
		return nil;
	}
	return self;
}


- (BOOL) setUpVisualEffectFromDictionary:(const oo::PList &) effectDict		{ return oo::ToCxx(self)->setUpVisualEffectFromDictionary(effectDict); }
- (OOMesh *)mesh															{ return oo::ToCxx(self)->mesh(); }
- (void)setMesh:(OOMesh *)mesh												{ oo::ToCxx(self)->setMesh(mesh); }
- (std::optional<std::string>)effectKey										{ return oo::ToCxx(self)->effectKey(); }
- (GLfloat)frustumRadius													{ return oo::ToCxx(self)->frustumRadius(); }
- (void) clearSubEntities													{ oo::ToCxx(self)->clearSubEntities(); }
- (BOOL) setUpSubEntities													{ return oo::ToCxx(self)->setUpSubEntities(); }
- (void) removeSubEntity:(Entity<OOSubEntity> *)sub							{ oo::ToCxx(self)->removeSubEntity(sub); }
- (void) setNoDrawDistance													{ oo::ToCxx(self)->setNoDrawDistance(); }
- (std::vector<oo::ObjCRef<Entity *>>)subEntities							{ return oo::ToCxx(self)->subEntities(); }
- (NSUInteger) subEntityCount												{ return oo::ToCxx(self)->subEntityCount(); }
- (std::optional<std::vector<oo::ObjCRef<OOVisualEffectEntity *>>>) visualEffectSubEntityEnumerator	{ return oo::ToCxx(self)->visualEffectSubEntityEnumerator(); }
- (BOOL) hasSubEntity:(Entity<OOSubEntity> *)sub							{ return oo::ToCxx(self)->hasSubEntity(sub); }
- (std::vector<oo::ObjCRef<Entity *>>)subEntityEnumerator					{ return oo::ToCxx(self)->subEntityEnumerator(); }
- (std::vector<oo::ObjCRef<OOVisualEffectEntity *>>)effectSubEntityEnumerator	{ return oo::ToCxx(self)->effectSubEntityEnumerator(); }
- (std::vector<oo::ObjCRef<OOFlasherEntity *>>)flasherEnumerator			{ return oo::ToCxx(self)->flasherEnumerator(); }
- (void) orientationChanged													{ oo::ToCxx(self)->orientationChanged(); }
- (Vector) forwardVector													{ return oo::ToCxx(self)->forwardVector(); }
- (Vector) rightVector														{ return oo::ToCxx(self)->rightVector(); }
- (Vector) upVector															{ return oo::ToCxx(self)->upVector(); }
- (GLfloat) scaleMax														{ return oo::ToCxx(self)->scaleMax(); }
- (GLfloat) scaleX															{ return oo::ToCxx(self)->scaleX(); }
- (void) setScaleX:(GLfloat)factor											{ oo::ToCxx(self)->setScaleX(factor); }
- (GLfloat) scaleY															{ return oo::ToCxx(self)->scaleY(); }
- (void) setScaleY:(GLfloat)factor											{ oo::ToCxx(self)->setScaleY(factor); }
- (GLfloat) scaleZ															{ return oo::ToCxx(self)->scaleZ(); }
- (void) setScaleZ:(GLfloat)factor											{ oo::ToCxx(self)->setScaleZ(factor); }
- (BOOL) isBreakPattern														{ return oo::ToCxx(self)->isBreakPattern(); }
- (void) setIsBreakPattern:(BOOL)bp											{ oo::ToCxx(self)->setIsBreakPattern(bp); }
- (oo::PList)effectInfoDictionary											{ return oo::ToCxx(self)->effectInfoDictionary(); }

// OOSubEntity
- (void) rescaleBy:(GLfloat)factor											{ oo::ToCxx(self)->rescaleBy(factor); }
- (void) rescaleBy:(GLfloat)factor writeToCache:(BOOL)writeToCache			{ oo::ToCxx(self)->rescaleBy(factor, writeToCache); }
- (void) drawSubEntityImmediate:(bool)immediate translucent:(bool)translucent	{ oo::ToCxx(self)->drawSubEntityImmediate(immediate, translucent); }

@end


@implementation OOVisualEffectEntity (SubEntityRelationship)

- (BOOL) isShipWithSubEntityShip:(Entity *)other							{ return oo::ToCxx(self)->isShipWithSubEntityShip(other); }

@end
