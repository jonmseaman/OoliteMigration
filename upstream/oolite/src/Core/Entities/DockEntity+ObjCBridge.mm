/*

DockEntity+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, amendments oo-60fwo, oo-64ako and oo-ao2d): the Objective-C
DockEntity facade (see DockEntity+ObjCBridge.h). Its initialiser and -dealloc are here, in a
category while the class's @implementation is still DockEntity.mm, because they need the
Objective-C object as self (amendment oo-bj8 items 6 and 7), and so are the forwarders of slice 1's
selectors to cxx::DockEntity; the other methods are still in DockEntity.mm until their slices move
them. Deleted with DockEntity+ObjCBridge.h.

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

#import "DockEntity.h"
#import "ShipEntity+ObjCAdapter.h"
#import "OOJSEngineTimeManagement.h"
#include "oofnd/objc/OOAssert.h"


@implementation DockEntity (OOObjCBridge)

- (id)cxx_initWithKey:(const std::string &)key definition:(const oo::PList &)dict
{
	OOJS_PROFILE_ENTER
	
	self = [super cxx_initWithKey:key definition:dict];
	if (self != nil)
	{
		_cxxDock->allow_docking = YES;
		_cxxDock->disallowed_docking_collides = NO;
		_cxxDock->allow_launching = YES;
		_cxxDock->virtual_dock = NO;
	}
	
	return self;
	
	OOJS_PROFILE_EXIT
}


/*	What [super init] did in ShipEntity's initialisers, with the dock's adapter: a dock's C++ part
	is a cxx::DockEntity (amendments oo-64ako and oo-ao2d), with the ship's adapter lines.
*/
- (id) initShipPart
{
	// -init sent again to an initialised ship keeps its C++ part (the root's -initWithCxxEntity:).
	if (_cxxEntity != nullptr)  return [self initWithCxxEntity:_cxxEntity.get()];
	return [self initWithCxxEntity:oo::makeRef<oo::ObjCShipEntity<cxx::DockEntity>>(self).get()];
}


// The root's designated initialiser, which also sets the typed alias of the part it stores.
- (id) initWithCxxEntity:(cxx::Entity *)entity
{
	self = [super initWithCxxEntity:entity];
	if (EXPECT_NOT(self == nil))  return nil;

	_cxxDock = dynamic_cast<cxx::DockEntity *>(_cxxEntity.get());
	OOCParameterAssert(_cxxDock != nullptr);
	return self;
}


- (void) dealloc
{
	/*	Released before its initialiser ran (a failing initialiser's [self release]; return nil;):
		there is no C++ part, as in ShipEntity's -dealloc (oo-s6ic6).
	*/
	if (_cxxDock != nullptr)  _cxxDock->clearIdLocks(nil);
	
	[super dealloc];
}

@end


// Slice 1 of docs/phases/3-slices/DockEntity.md (bead oo-ao2d).
@implementation DockEntity (OOSlice1)

- (void) clear	{ _cxxDock->clear(); }
- (BOOL) allowsDocking	{ return _cxxDock->allowsDocking(); }
- (void) setAllowsDocking:(BOOL)allowed	{ _cxxDock->setAllowsDocking(allowed); }
- (BOOL) disallowedDockingCollides	{ return _cxxDock->disallowedDockingCollides(); }
- (void) setDisallowedDockingCollides:(BOOL)ddc	{ _cxxDock->setDisallowedDockingCollides(ddc); }
- (NSUInteger) countOfShipsInDockingQueue	{ return _cxxDock->countOfShipsInDockingQueue(); }
- (BOOL) allowsLaunching	{ return _cxxDock->allowsLaunching(); }
- (void) setAllowsLaunching:(BOOL)allowed	{ _cxxDock->setAllowsLaunching(allowed); }
- (NSUInteger) countOfShipsInLaunchQueue	{ return _cxxDock->countOfShipsInLaunchQueue(); }
- (void) setDimensionsAndCorridor:(BOOL)docking :(BOOL)ddc :(BOOL)launching	{ _cxxDock->setDimensionsAndCorridor(docking, ddc, launching); }
- (Vector) portUpVectorForShipsBoundingBox:(BoundingBox)bb	{ return _cxxDock->portUpVectorForShipsBoundingBox(bb); }
- (BOOL) isOffCentre	{ return _cxxDock->isOffCentre(); }
- (void) setVirtual	{ _cxxDock->setVirtual(); }
- (void) clearIdLocks:(ShipEntity *)ship	{ _cxxDock->clearIdLocks(ship); }
- (void) clearAllIdLocks	{ _cxxDock->clearAllIdLocks(); }
- (BOOL) isDock	{ return _cxxDock->cxx::DockEntity::isDock(); }
- (BOOL) setUpShipFromDictionary:(const oo::PList &)dict	{ return _cxxDock->cxx::DockEntity::setUpShipFromDictionary(dict); }
- (void) update:(OOTimeDelta)delta_t	{ _cxxDock->cxx::DockEntity::update(delta_t); }
- (void) noteTakingDamage:(double)amount from:(Entity *)entity type:(OOShipDamageType)type	{ _cxxDock->cxx::DockEntity::noteTakingDamage(amount, entity, type); }
- (void) takeEnergyDamage:(double)amount from:(Entity *)ent becauseOf:(Entity *)other weaponIdentifier:(const std::string &)weaponIdentifier	{ _cxxDock->cxx::DockEntity::takeEnergyDamage(amount, oo::ToCxx(ent), oo::ToCxx(other), weaponIdentifier); }
- (void) drawImmediate:(bool)immediate translucent:(bool)translucent	{ _cxxDock->cxx::DockEntity::drawImmediate(immediate, translucent); }

@end


// Slice 2 of docs/phases/3-slices/DockEntity.md (bead oo-9ht.178).
@implementation DockEntity (OOSlice2)

- (oo::PList) dockingInstructionsForShip:(ShipEntity *)ship	{ return _cxxDock->dockingInstructionsForShip(ship); }
- (std::optional<std::string>) canAcceptShipForDocking:(ShipEntity *)ship	{ return _cxxDock->canAcceptShipForDocking(ship); }
- (BOOL) shipIsInDockingQueue:(ShipEntity *)ship	{ return _cxxDock->shipIsInDockingQueue(ship); }
- (void) abortDockingForShip:(ShipEntity *)ship	{ _cxxDock->abortDockingForShip(ship); }
- (void) abortAllDockings	{ _cxxDock->abortAllDockings(); }
- (void) autoDockShipsOnApproach	{ _cxxDock->autoDockShipsOnApproach(); }
- (NSUInteger) pruneAndCountShipsOnApproach	{ return _cxxDock->pruneAndCountShipsOnApproach(); }
- (void) noteDockingForShip:(ShipEntity *)ship	{ _cxxDock->noteDockingForShip(ship); }
- (void) autoDockShipsInQueue:(std::map<unsigned short, std::vector<oo::PList>> &)queue	{ _cxxDock->autoDockShipsInQueue(queue); }
- (void) addShipToShipsOnApproach:(ShipEntity *)ship	{ _cxxDock->addShipToShipsOnApproach(ship); }
- (void) pullInShipIfPermitted:(ShipEntity *)ship	{ _cxxDock->pullInShipIfPermitted(ship); }

@end
