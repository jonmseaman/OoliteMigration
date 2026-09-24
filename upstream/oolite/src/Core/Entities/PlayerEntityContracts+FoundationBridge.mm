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


// oo-3rb.181 (chunk 3): passengers (a nil name arrives as "": OOJSPlayerShip validates it first)

- (BOOL) addPassenger:(NSString*)Name start:(unsigned)start destination:(unsigned)destination eta:(double)eta fee:(double)fee advance:(double)advance risk:(unsigned)risk
{
	return [self cxx_addPassenger:oo::StdString(Name) start:start destination:destination eta:eta fee:fee advance:advance risk:risk];
}


- (BOOL) removePassenger:(NSString*)Name
{
	return [self cxx_removePassenger:oo::StdString(Name)];
}

@end
