/*

PlayerEntityContracts+FoundationBridge.mm

TRANSITIONAL: see PlayerEntityContracts+FoundationBridge.h. Each method forwards to its cxx_
counterpart and converts the result exactly as the old method produced it (the same NSNumber
type, nil for nil).

*/

#import "PlayerEntityContracts.h"	// declares the bridge category at its end
#import "OOFoundationBridge.h"


@implementation PlayerEntity (ContractsFoundationBridge)

// oo-3rb.179 (chunk 1): report strings

- (NSString *) processEscapePods
{
	return oo::NSStringOrNil([self cxx_processEscapePods]);
}


- (NSString *) checkPassengerContracts
{
	return oo::NSStringOrNil([self cxx_checkPassengerContracts]);
}


- (void) addMessageToReport:(NSString*) report
{
	[self cxx_addMessageToReport:oo::StdString(report)];	// nil adds nothing, as an empty string
}

@end
