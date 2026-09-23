/*

ShipEntity+FoundationBridge.mm

TRANSITIONAL: see ShipEntity+FoundationBridge.h. Each method forwards to its cxx_ counterpart and
converts arguments and results at the boundary, as the old method produced them (nil for nil).

*/

#import "ShipEntity.h"	// declares the bridge category at its end
#import "OOExhaustPlumeEntity.h"
#import "OOFoundationBridge.h"


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

@end
