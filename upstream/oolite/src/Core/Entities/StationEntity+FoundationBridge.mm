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

@end


NSDictionary *OOMakeDockingInstructions(StationEntity *station, HPVector coords, float speed, float range, NSString *ai_message, NSString *comms_message, BOOL match_rotation, int docking_stage)
{
	return oo::ObjectFromPList(cxx_OOMakeDockingInstructions(station, coords, speed, range, oo::OptionalString(ai_message), oo::OptionalString(comms_message), match_rotation, docking_stage));
}
