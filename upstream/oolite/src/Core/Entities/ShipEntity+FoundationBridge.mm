/*

ShipEntity+FoundationBridge.mm

TRANSITIONAL: see ShipEntity+FoundationBridge.h. Each method forwards to its cxx_ counterpart and
converts arguments and results at the boundary, as the old method produced them (nil for nil).

*/

#import "ShipEntity.h"	// declares the bridge category at its end
#import "OOExhaustPlumeEntity.h"
#import "OOVector.h"
#import "OOFoundationBridge.h"


namespace {

// The weapon offsets as the old accessors held them: an array of OONativeVector.
NSArray *NativeVectorArray(const std::vector<Vector> &vectors)
{
	std::vector<oo::ObjCRef<OONativeVector *>> result;
	result.reserve(vectors.size());
	for (Vector v : vectors)  result.push_back(oo::adoptObjC([[OONativeVector alloc] initWithVector:v]));
	return oo::NSArrayFromObjects(result);
}

}	// namespace


@implementation ShipEntity (OOFoundationBridge)

// oo-3rb.232: subentities

- (NSEnumerator *)shipSubEntityEnumerator
{
	return [oo::NSArrayFromObjects([self cxx_shipSubEntities]) objectEnumerator];
}


- (NSEnumerator *)exhaustEnumerator
{
	return [oo::NSArrayFromObjects([self cxx_exhausts]) objectEnumerator];
}


- (NSString *) serializeShipSubEntities
{
	return oo::NSStringOrNil([self cxx_serializeShipSubEntities]);
}


- (void) deserializeShipSubEntitiesFrom:(NSString *)string
{
	[self cxx_deserializeShipSubEntitiesFrom:oo::StdString(string)];
}


- (BOOL) setUpOneStandardSubentity:(NSDictionary *) subentDict asTurret:(BOOL)asTurret
{
	return [self cxx_setUpOneStandardSubentity:oo::PListFrom(subentDict) asTurret:asTurret];
}


// oo-3rb.233: equipment

- (NSUInteger) countEquipmentItem:(NSString *)eqkey
{
	return [self cxx_countEquipmentItem:oo::StdString(eqkey)];
}


- (NSString *) equipmentItemProviding:(NSString *)equipmentType
{
	return oo::NSStringOrNil([self cxx_equipmentItemProviding:oo::StdString(equipmentType)]);
}


- (BOOL) hasEquipmentItemProviding:(NSString *)equipmentType
{
	return [self cxx_hasEquipmentItemProviding:oo::StdString(equipmentType)];
}


- (BOOL) equipmentValidToAdd:(NSString *)equipmentKey inContext:(NSString *)context
{
	return [self cxx_equipmentValidToAdd:oo::StdString(equipmentKey) inContext:oo::StdString(context)];
}


- (BOOL) equipmentValidToAdd:(NSString *)equipmentKey whileLoading:(BOOL)loading inContext:(NSString *)context
{
	return [self cxx_equipmentValidToAdd:oo::StdString(equipmentKey) whileLoading:loading inContext:oo::StdString(context)];
}


- (NSEnumerator *) equipmentEnumerator
{
	return [oo::NSArrayFromStrings([self cxx_equipmentKeys]) objectEnumerator];
}


- (BOOL) hasOneEquipmentItem:(NSString *)itemKey includeWeapons:(BOOL)includeMissiles whileLoading:(BOOL)loading
{
	return [self cxx_hasOneEquipmentItem:oo::StdString(itemKey) includeWeapons:includeMissiles whileLoading:loading];
}


- (BOOL) hasOneEquipmentItem:(NSString *)itemKey includeMissiles:(BOOL)includeMissiles whileLoading:(BOOL)loading
{
	return [self cxx_hasOneEquipmentItem:oo::StdString(itemKey) includeMissiles:includeMissiles whileLoading:loading];
}


- (NSArray *) equipmentListForScripting
{
	return oo::NSArrayFromObjects([self cxx_equipmentListForScripting]);
}


// oo-3rb.234: missiles and weapon mounts

- (NSArray *) aftWeaponOffset
{
	return NativeVectorArray([self cxx_aftWeaponOffset]);
}


- (NSArray *) forwardWeaponOffset
{
	return NativeVectorArray([self cxx_forwardWeaponOffset]);
}


- (NSArray *) portWeaponOffset
{
	return NativeVectorArray([self cxx_portWeaponOffset]);
}


- (NSArray *) starboardWeaponOffset
{
	return NativeVectorArray([self cxx_starboardWeaponOffset]);
}


- (NSArray *) laserPortOffset:(OOWeaponFacing)direction
{
	return NativeVectorArray([self cxx_laserPortOffset:direction]);
}


- (BOOL) fireLaserShotInDirection:(OOWeaponFacing)direction weaponIdentifier:(NSString *)weaponIdentifier
{
	return [self cxx_fireLaserShotInDirection:direction weaponIdentifier:oo::StdString(weaponIdentifier)];
}


- (ShipEntity *) fireMissileWithIdentifier:(NSString *) identifier andTarget:(Entity *) target
{
	return [self cxx_fireMissileWithIdentifier:oo::OptionalString(identifier) andTarget:target];
}

@end


Vector positionOffsetForShipInRotationToAlignment(ShipEntity* ship, Quaternion q, NSString* align)
{
	// nil printed "(null)---" through %@, whose first three units select nothing, as "" does.
	return cxx_positionOffsetForShipInRotationToAlignment(ship, q, oo::StdString(align));
}
