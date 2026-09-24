/*

PlayerEntity+FoundationBridge.mm

TRANSITIONAL: see PlayerEntity+FoundationBridge.h. Each method forwards to its cxx_ counterpart
and converts the result exactly as the old method produced it.

*/

#import "PlayerEntity.h"	// declares the bridge category at its end
#import "OOFoundationBridge.h"


@implementation PlayerEntity (FoundationBridge)

// oo-3rb.164: a dictionary of arrays keyed by +numberWithInt: of the system ID, each array's
// markers in the order they were added (as -prepareMarkedDestination:: built it).
- (NSDictionary *) markedDestinations
{
	NSMutableDictionary *destinations = [NSMutableDictionary dictionaryWithCapacity:256];
	const std::optional<std::map<int, std::vector<oo::PList>>> markers = [self cxx_markedDestinations];
	if (markers.has_value())
	{
		for (const auto &[system, list] : *markers)
		{
			NSMutableArray *array = [NSMutableArray arrayWithCapacity:list.size()];
			for (const oo::PList &marker : list)
			{
				id object = oo::ObjectFromPList(marker);
				if (object != nil)  [array addObject:object];
			}
			[destinations setObject:array forKey:[NSNumber numberWithInt:system]];
		}
	}
	return destinations;
}

@end
