/*

GameController+FoundationBridge.mm

TRANSITIONAL: see GameController+FoundationBridge.h. Each method forwards to its cxx_ counterpart
and converts at the boundary (oo::StdString in: a nil file name arrives as "", which has no
.oolite-save extension, as before; nil for nullopt out).

*/

#import "GameController.h"	// declares the bridge category at its end
#import "OOFoundationBridge.h"


@implementation GameController (OOFoundationBridge)

- (void) exitAppWithContext:(NSString *)context
{
	[self cxx_exitAppWithContext:oo::StdString(context)];
}


- (NSString *) playerFileToLoad
{
	return oo::NSStringOrNil([self cxx_playerFileToLoad]);
}


- (void) setPlayerFileToLoad:(NSString *)filename
{
	[self cxx_setPlayerFileToLoad:oo::StdString(filename)];
}


- (NSString *) playerFileDirectory
{
	return oo::NSStringOrNil([self cxx_playerFileDirectory]);
}


- (void) setPlayerFileDirectory:(NSString *)filename
{
	// nil clears the directory (and the default), which "" would not.
	[self cxx_setPlayerFileDirectory:oo::OptionalString(filename)];
}

@end
