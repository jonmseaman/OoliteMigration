/*

StationEntity+FoundationBridge.mm

TRANSITIONAL: see StationEntity+FoundationBridge.h. Each method forwards to its cxx_ counterpart
and converts the result exactly as the old method produced it (the same NSNumber type, nil for nil).

*/

#import "StationEntity.h"	// declares the bridge category at its end
#import "DockEntity.h"
#import "OOFoundationBridge.h"


@implementation StationEntity (OOFoundationBridge)

// The old method filtered a snapshot of -subEntities (-subEntities returns a copy); so does the
// twin. ADR-0043 item 16: an enumerator over a snapshot array.
- (NSEnumerator *) dockSubEntityEnumerator
{
	return [oo::NSArrayFromObjects([self cxx_dockSubEntities]) objectEnumerator];
}


// oo-3rb.173 (chunk 2): market, allegiance, docking clearance

// A fresh immutable array per call (the old method returned the ivar); the same NSNumber types.
- (NSArray *) marketDefinition
{
	return oo::ObjectFromPList([self cxx_marketDefinition]);
}


- (NSString *) marketScriptName
{
	return oo::NSStringOrNil([self cxx_marketScriptName]);
}


- (void) setLocalMarket:(NSArray *)market
{
	[self cxx_setLocalMarket:oo::PListFrom(market)];
}


// oo::ObjectFromPList rebuilds -dictionaryForScripting's dictionary with the same NSNumber types.
- (NSDictionary *) localMarketForScripting
{
	return oo::ObjectFromPList([self cxx_localMarketForScripting]);
}


- (void) setPrice:(OOCreditsQuantity) price forCommodity:(OOCommodityType) commodity
{
	[self cxx_setPrice:price forCommodity:oo::StdString(commodity)];
}


- (void) setQuantity:(OOCargoQuantity) quantity forCommodity:(OOCommodityType) commodity
{
	[self cxx_setQuantity:quantity forCommodity:oo::StdString(commodity)];
}


- (void) setAllegiance:(NSString *)newAllegiance
{
	[self cxx_setAllegiance:oo::OptionalString(newAllegiance)];
}


- (NSString *)allegiance
{
	return oo::NSStringOrNil([self cxx_allegiance]);
}


- (NSString *) acceptDockingClearanceRequestFrom:(ShipEntity *)other
{
	return oo::NSStringOrNil([self cxx_acceptDockingClearanceRequestFrom:other]);
}

@end


NSDictionary *OOMakeDockingInstructions(StationEntity *station, HPVector coords, float speed, float range, NSString *ai_message, NSString *comms_message, BOOL match_rotation, int docking_stage)
{
	return oo::ObjectFromPList(cxx_OOMakeDockingInstructions(station, coords, speed, range, oo::OptionalString(ai_message), oo::OptionalString(comms_message), match_rotation, docking_stage));
}
