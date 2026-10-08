/*

DockEntity.h

ShipEntity subclass representing a dock.

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

#import "ShipEntity.h"
#import "StationEntity.h"	// For MAX_DOCKING_STAGES


namespace cxx {

/*	The dock's state, and the members its slices have moved (docs/phases/3-slices/DockEntity.md).

	The ivars are data members with the same names, every one zero-initialised as the runtime
	zeroed them (amendment oo-bj8 item 1). The facade's unconverted methods reach them through the
	facade's _cxxDock, by the same names (amendments oo-64ako and oo-ao2d), so each later slice gets
	its bodies back verbatim by deleting "_cxxDock->". Pointers to Objective-C objects stay what
	they were, retained by hand where they were (amendment oo-bj8 item 4).
*/
class DockEntity : public ShipEntity
{
public:
	// Slice 1: class shell, flags, geometry and lifecycle.
	void clear();

	// Docking
	bool allowsDocking();
	void setAllowsDocking(bool allowed);
	bool disallowedDockingCollides();
	void setDisallowedDockingCollides(bool ddc);
	NSUInteger countOfShipsInDockingQueue();

	// Launching
	bool allowsLaunching();
	void setAllowsLaunching(bool allowed);
	NSUInteger countOfShipsInLaunchQueue();

	// Geometry
	void setDimensionsAndCorridor(bool docking, bool ddc, bool launching);
	Vector portUpVectorForShipsBoundingBox(BoundingBox bb);
	bool isOffCentre();
	void setVirtual();

	// The ID locks (the private category of DockEntity.mm).
	void clearIdLocks(::ShipEntity *ship);
	void clearAllIdLocks();

	// Slice 2: docking guidance, the approach queue and docking instructions.
	oo::PList dockingInstructionsForShip(::ShipEntity *ship);	// a dictionary (the station an Object node); null: none (bead oo-3rb.262)
	std::optional<std::string> canAcceptShipForDocking(::ShipEntity *ship);
	bool shipIsInDockingQueue(::ShipEntity *ship);
	void abortDockingForShip(::ShipEntity *ship);
	void abortAllDockings();
	void autoDockShipsOnApproach();
	NSUInteger pruneAndCountShipsOnApproach();
	void noteDockingForShip(::ShipEntity *ship);
	void autoDockShipsInQueue(std::map<unsigned short, std::vector<oo::PList>> &queue);
	void addShipToShipsOnApproach(::ShipEntity *ship);
	void pullInShipIfPermitted(::ShipEntity *ship);

	// Slice 3: the docking corridor and launching.
	bool shipIsInDockingCorridor(::ShipEntity *ship);
	void abortAllLaunches();
	void addShipToLaunchQueue(::ShipEntity *ship, bool priority);
	void launchShip(::ShipEntity *ship);
	NSUInteger countOfShipsInLaunchQueueWithPrimaryRole(const std::string &role);
	bool allowsLaunchingOf(::ShipEntity *ship);
	bool dockingCorridorIsEmpty();
	void clearDockingCorridor();

	// From the superclass.
	bool isDock() override;
	bool setUpShipFromDictionary(const oo::PList &dict) override;
	void update(OOTimeDelta delta_t) override;
	void noteTakingDamage(double amount, ::Entity *entity, OOShipDamageType type) override;
	void takeEnergyDamage(double amount, cxx::Entity *ent, cxx::Entity *other, const std::string &weaponIdentifier) override;
	void drawImmediate(bool immediate, bool translucent) override;

	// @private in Objective-C: private once DockEntity is converted; public while the facade's
	// unconverted methods read them, since an Objective-C class cannot be a C++ friend
	std::map<unsigned short, std::vector<oo::PList>>	shipsOnApproach;	// coordinate stacks (Dicts) by ship ID (the old +numberWithUnsignedShort: key)
	std::vector<oo::ObjCRef<::ShipEntity *>>	launchQueue;
	double					last_launch_time = {};
//	double					approach_spacing; // not needed now holding pattern changed
	
	::ShipEntity			*id_lock[MAX_DOCKING_STAGES] = {};	// OOWeakReferences to a ShipEntity
	
	Vector  				port_dimensions = {};
	double					port_corridor = {};				// corridor length inside station.
	
	BOOL					no_docking_while_launching = {};
	BOOL					allow_launching = {};
	BOOL					allow_docking = {};
	BOOL					disallowed_docking_collides = {}; 
	BOOL					virtual_dock = {};
};

}	// namespace cxx


// Transitional: the Objective-C DockEntity, for its unconverted methods and its callers.
// Deleted, with namespace cxx above, by the bridge's deletion bead.
#import "DockEntity+ObjCBridge.h"
