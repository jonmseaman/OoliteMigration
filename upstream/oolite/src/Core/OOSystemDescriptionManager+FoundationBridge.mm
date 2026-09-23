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


// oo-3rb.108: storage and write side

- (void) setUniversalProperties:(NSDictionary *)properties
{
	[self cxx_setUniversalProperties:oo::PListFrom(properties)];
}


- (void) setInterstellarProperties:(NSDictionary *)properties
{
	[self cxx_setInterstellarProperties:oo::PListFrom(properties)];
}


- (void) setProperties:(NSDictionary *)properties forSystemKey:(NSString *)key
{
	[self cxx_setProperties:oo::PListFrom(properties) forSystemKey:oo::StdString(key)];
}


- (void) setProperty:(NSString *)property forSystemKey:(NSString *)key andLayer:(OOSystemLayer)layer toValue:(id)value fromManifest:(NSString *)manifest
{
	[self cxx_setProperty:oo::StdString(property) forSystemKey:oo::StdString(key) andLayer:layer toValue:oo::PListFrom(value) fromManifest:oo::OptionalString(manifest)];
}

@end
