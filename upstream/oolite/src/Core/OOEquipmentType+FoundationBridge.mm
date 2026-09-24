/*

OOEquipmentType+FoundationBridge.mm

TRANSITIONAL: see OOEquipmentType+FoundationBridge.h. Each method forwards to its cxx_
counterpart and converts arguments and results at the boundary (nil for nil).

*/

#import "OOEquipmentType.h"	// declares the bridge category at its end
#import "OOFoundationBridge.h"


@implementation OOEquipmentType (OOFoundationBridge)

+ (NSString *) getMissileRegistryRoleForShip:(NSString *)shipKey
{
	if (shipKey == nil)  return nil;
	return oo::NSStringOrNil([self cxx_getMissileRegistryRoleForShip:oo::StdString(shipKey)]);
}


+ (void) setMissileRegistryRole:(NSString *)role forShip:(NSString *)shipKey
{
	if (role != nil && shipKey != nil)
	{
		[self cxx_setMissileRegistryRole:oo::StdString(role) forShip:oo::StdString(shipKey)];
	}
}


+ (OOEquipmentType *) equipmentTypeWithIdentifier:(NSString *)identifier
{
	if (identifier == nil)  return nil;
	return [self cxx_equipmentTypeWithIdentifier:oo::StdString(identifier)];
}


- (NSString *) identifier
{
	return oo::NSStringOrNil([self cxx_identifier]);
}


- (NSString *) damagedIdentifier
{
	return oo::NSStringOrNil([self cxx_damagedIdentifier]);
}


- (NSString *) descriptiveText
{
	return oo::NSStringOrNil([self cxx_descriptiveText]);
}

@end
