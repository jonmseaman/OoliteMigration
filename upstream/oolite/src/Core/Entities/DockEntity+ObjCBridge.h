/*

DockEntity+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056, amendments oo-60fwo, oo-64ako and oo-ao2d): the Objective-C
DockEntity, the facade over the C++ cxx::DockEntity (DockEntity.h) while the class converts slice
by slice (docs/phases/3-slices/DockEntity.md). Its interface is the one DockEntity.h declared
before slice 1, copied exactly, but for the selectors slice 1 moved to cxx::DockEntity, which are
declared by the category DockEntity (OOSlice1) below and forward to the C++ part. Its methods of
slices 2 and 3 keep their Objective-C bodies in DockEntity.mm until their slice moves them. It has
one ivar, _cxxDock: the root's _cxxEntity, typed, borrowed (the root owns the part), set by the
initialiser; unconverted code reads the dock's members through it by their old names
(_cxxDock->launchQueue). Its initialiser makes the dock's adapter over cxx::DockEntity
(oo::ObjCShipEntity<cxx::DockEntity>, ShipEntity+ObjCAdapter.h). Imported as the last line of
DockEntity.h; do not import it directly. Deleted by its deletion bead once every slice and the
callers are C++.

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

#ifndef DOCKENTITY_OBJCBRIDGE_H
#define DOCKENTITY_OBJCBRIDGE_H


@interface DockEntity: ShipEntity
{
@public
	cxx::DockEntity	*_cxxDock;		// _cxxEntity, typed; borrowed, set by the initialiser
}

// Docking
- (BOOL) shipIsInDockingCorridor:(ShipEntity *)ship;
- (BOOL) dockingCorridorIsEmpty;
- (void) clearDockingCorridor;

// Launching
- (NSUInteger) countOfShipsInLaunchQueueWithPrimaryRole:(const std::string &)role;
- (BOOL) allowsLaunchingOf:(ShipEntity *)ship;
- (void) launchShip:(ShipEntity *)ship;
- (void) addShipToLaunchQueue:(ShipEntity *)ship withPriority:(BOOL)priority;

@end


// Slice 1 of docs/phases/3-slices/DockEntity.md (bead oo-ao2d): class shell, flags, geometry and
// lifecycle. Forwarders to cxx::DockEntity, in DockEntity+ObjCBridge.mm.
@interface DockEntity (OOSlice1)

- (void) clear;

// Docking
- (BOOL) allowsDocking;
- (void) setAllowsDocking:(BOOL)allow;
- (BOOL) disallowedDockingCollides; 
- (void) setDisallowedDockingCollides:(BOOL)ddc;
- (NSUInteger) countOfShipsInDockingQueue;

// Launching
- (BOOL) allowsLaunching;
- (void) setAllowsLaunching:(BOOL)allow;
- (NSUInteger) countOfShipsInLaunchQueue;

// Geometry
- (void) setDimensionsAndCorridor:(BOOL)docking :(BOOL)ddc :(BOOL)launching;
- (Vector) portUpVectorForShipsBoundingBox:(BoundingBox)bb;
- (BOOL) isOffCentre;
- (void) setVirtual;

// The private category of DockEntity.mm, for its unconverted slices.
- (void) clearIdLocks:(ShipEntity *)ship;
- (void) clearAllIdLocks;

@end


// Slice 2 of docs/phases/3-slices/DockEntity.md (bead oo-9ht.178): docking guidance, the approach
// queue and docking instructions. Forwarders to cxx::DockEntity, in DockEntity+ObjCBridge.mm.
@interface DockEntity (OOSlice2)

// Docking
/**
 * Guides a ship into the dock. 
 * <h3>Possible results:</h3>
 * <ul>
 * <li>null<br/>
 *     if no result can be computed or the last control point is reached
 * <li>Move to station (APPROACH)<br/>
 *     if ship is too far away
 * <li>Move away from station (BACKOFF)<br/>
 *     if ship is too close
 * <li>Move perpendicular to station/dock direction (APPROACH)<br/>
 *     if ship is approaching from wrong side of station
 * <li>Abort (TRY AGAIN LATER)<br/>
 *     if something went wrong until here
 * <li>Hold position (HOLD_POSITION)<br/>
 *     if coordinatesStack is empty or approach is not clear
 * <li>Move to next control point (APPROACH_COORDINATES)<br/>
 *     if control point not within collision radius
 * </ul>
 *
 * <h3>Algorithm:</h3>
 * <ol>
 * <li>If ship is not on approach list and beyond scanner range (25 km?), approach the station
 * <li>Add ship to approach list
 * <li>If ship is within distance of 1000 km between station's and ship's collision radius, move away from station
 * <li>If ship is approaching from behind, move to the side of the station (perpendicular on direction to station and launch vector)
 * <li>If ship is further away than 12000 km, approach the station
 * </ol>
 * <p>Now the ship is in the vicinity of the station in the correct hemispere. Let's guide them in.</p>
 * <ol>
 * <li>Get the coordinatesStack for this ship (the approach path?). If there is a problem, Ship shall hold position
 * <li>If next coordinates (control point) not yet within collision radius, move towards that position
 * <li>Remove control point from stack; get next control point
 * <li>If next 3 stages of approach are clear, move to next position
 * <li>otherwise hold position
 * </ol>
 * 
 * <p>TODO: Where is the detection that the ship has docked?</p>
 * <p>TODO: What are the magic number's units? Is it km (kilometers)?</p>
 */
- (oo::PList) dockingInstructionsForShip:(ShipEntity *)ship;	// a dictionary (the station an Object node); null: none (bead oo-3rb.262)
- (std::optional<std::string>) canAcceptShipForDocking:(ShipEntity *)ship;
- (BOOL) shipIsInDockingQueue:(ShipEntity *)ship;
- (void) abortDockingForShip:(ShipEntity *)ship;
- (void) abortAllDockings;
- (void) autoDockShipsOnApproach;
- (NSUInteger) pruneAndCountShipsOnApproach;
- (void) noteDockingForShip:(ShipEntity *)ship;

// The private category of DockEntity.mm, for its unconverted slices.
- (void) autoDockShipsInQueue:(std::map<unsigned short, std::vector<oo::PList>> &)queue;
- (void) addShipToShipsOnApproach:(ShipEntity *)ship;
- (void) pullInShipIfPermitted:(ShipEntity *)ship;

@end


namespace oo {

// The root's crossings, typed (amendment oo-up4b item 3).
inline cxx::DockEntity *ToCxx(::DockEntity *entity)
{
	return static_cast<cxx::DockEntity *>(ToCxx(static_cast<::Entity *>(entity)));
}

inline ::DockEntity *ToObjC(cxx::DockEntity *entity)
{
	return (::DockEntity *)ToObjC(static_cast<cxx::Entity *>(entity));
}

}	// namespace oo

#endif	// DOCKENTITY_OBJCBRIDGE_H
