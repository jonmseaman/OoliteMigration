/*

OOSystemDescriptionManager+FoundationBridge.mm

TRANSITIONAL: see OOSystemDescriptionManager+FoundationBridge.h. Each method forwards to its cxx_
counterpart and converts the result exactly as the old method produced it (nil for nil, immutable
collections, the property values' own objects and NSNumber types).

*/

#import "OOSystemDescriptionManager.h"	// declares the bridge category at its end
#import "OOFoundationBridge.h"


@implementation OOSystemDescriptionManager (OOFoundationBridge)

// oo-3rb.107: scripted changes

- (void) importScriptedChanges:(NSDictionary *)scripted
{
	[self cxx_importScriptedChanges:oo::PListFrom(scripted)];
}


- (void) importLegacyScriptedChanges:(NSDictionary *)scripted
{
	[self cxx_importLegacyScriptedChanges:oo::PListFrom(scripted)];
}


- (NSDictionary *) exportScriptedChanges
{
	// an immutable copy (never nil), as -copy of the dictionary was
	return oo::ObjectFromPList([self cxx_exportScriptedChanges]);
}

@end
