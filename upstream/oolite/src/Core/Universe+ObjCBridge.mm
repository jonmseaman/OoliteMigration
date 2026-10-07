/*

Universe+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, amendment oo-riqmz): the Objective-C Universe facade (see
Universe+ObjCBridge.h). Its initialiser and -dealloc are here, in a category while the class's
@implementation is still Universe.mm, because they need the Objective-C object as self; their
bodies are cxx::Universe's initWithGameView() and dealloc(), in Universe.mm. The other methods are
still in Universe.mm until their slices move them. Deleted with Universe+ObjCBridge.h.

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

#import "Universe.h"
#import "GameController.h"
#include "oofnd/objc/OOException.h"


extern Universe *gSharedUniverse;


@implementation Universe (OOObjCBridge)

- (id) initWithGameView:(MyOpenGLView *)inGameView
{
	/*	The part first: a universe refused below is released at once, and its -dealloc runs the
		whole body as it did when the ivars were the object's.
	*/
	if (_cxxUniverse == nullptr)  _cxxUniverse = oo::makeRef<cxx::Universe>(self);

	if (gSharedUniverse != nil)
	{
		[self release];
		[OOException raise:OOInternalInconsistencyException format:"%s: expected only one Universe to exist at a time.", __PRETTY_FUNCTION__];
	}

	OO_DEBUG_PROGRESS("Universe initWithGameView:");

	self = [super init];
	if (self == nil)  return nil;

	_cxxUniverse->initWithGameView(inGameView);
	return self;
}


- (void) dealloc
{
	// A universe released before -initWithGameView: made its part has nothing to tear down (oo-s6ic6).
	if (_cxxUniverse != nullptr)  _cxxUniverse->dealloc();
	_cxxUniverse = nullptr;

	[super dealloc];
}

@end


@implementation Universe (OOSlice14)

- (ShipEntity *) cxx_makeDemoShipWithRole:(const std::string &)role spinning:(BOOL)spinning	{ return _cxxUniverse->makeDemoShipWithRole(role, spinning); }
- (BOOL) isVectorClearFromEntity:(Entity *) e1 toDistance:(double)dist fromPoint:(HPVector) p2	{ return _cxxUniverse->isVectorClearFromEntity(e1, dist, p2); }
- (Entity*) hazardOnRouteFromEntity:(Entity *) e1 toDistance:(double)dist fromPoint:(HPVector) p2	{ return _cxxUniverse->hazardOnRouteFromEntity(e1, dist, p2); }
- (HPVector) getSafeVectorFromEntity:(Entity *) e1 toDistance:(double)dist fromPoint:(HPVector) p2	{ return _cxxUniverse->getSafeVectorFromEntity(e1, dist, p2); }
- (ShipEntity*) cxx_addWreckageFrom:(ShipEntity *)ship withRole:(const std::string &)wreckRole at:(HPVector)rpos scale:(GLfloat)scale lifetime:(GLfloat)lifetime	{ return _cxxUniverse->addWreckageFrom(ship, wreckRole, rpos, scale, lifetime); }
- (void) addLaserHitEffectsAt:(HPVector)pos against:(ShipEntity *)target damage:(float)damage color:(OOColor *)color	{ _cxxUniverse->addLaserHitEffectsAt(pos, target, damage, color); }
- (ShipEntity *) firstShipHitByLaserFromShip:(ShipEntity *)srcEntity inDirection:(OOWeaponFacing)direction offset:(Vector)offset gettingRangeFound:(GLfloat *)range_ptr	{ return _cxxUniverse->firstShipHitByLaserFromShip(srcEntity, direction, offset, range_ptr); }

@end
