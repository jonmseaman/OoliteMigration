/*

OOShipRegistry+FoundationBridge.mm

TRANSITIONAL: see OOShipRegistry+FoundationBridge.h. Each method forwards to its cxx_ counterpart
and converts the result exactly as the old method produced it (nil for nil, immutable collections).
A ship or effect dictionary is built afresh on each call (the old methods returned the stored
dictionary).

*/

#import "OOShipRegistry.h"	// declares the bridge category at its end
#import "OOFoundationBridge.h"


@implementation OOShipRegistry (OOFoundationBridge)

// oo-3rb.114: ship and effect data

- (NSDictionary *) shipInfoForKey:(NSString *)key
{
	if (key == nil)  return nil;	// -objectForKey:nil was nil
	return oo::ObjectFromPList([self cxx_shipInfoForKey:oo::StdString(key)]);
}


- (void) setShipInfoForKey:(NSString *)key with:(NSDictionary *)newShipData
{
	[self cxx_setShipInfoForKey:oo::StdString(key) with:oo::PListFrom(newShipData)];
}


- (NSDictionary *) effectInfoForKey:(NSString *)key
{
	if (key == nil)  return nil;
	return oo::ObjectFromPList([self cxx_effectInfoForKey:oo::StdString(key)]);
}


- (NSDictionary *) shipyardInfoForKey:(NSString *)key
{
	if (key == nil)  return nil;
	return oo::ObjectFromPList([self cxx_shipyardInfoForKey:oo::StdString(key)]);
}


- (NSArray *) playerShipKeys
{
	return oo::NSArrayFromStrings([self cxx_playerShipKeys]);
}


- (NSArray *) shipKeys
{
	return oo::NSArrayFromStrings([self cxx_shipKeys]);
}

@end
