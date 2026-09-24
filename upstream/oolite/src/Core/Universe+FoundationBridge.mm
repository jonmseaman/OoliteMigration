/*

Universe+FoundationBridge.mm

TRANSITIONAL: see Universe+FoundationBridge.h. Each method and function forwards to its cxx_
counterpart and converts the result exactly as the old one produced it (nil for nil).

*/

#import "Universe.h"	// declares the bridge at its end
#import "OOFoundationBridge.h"


@implementation Universe (OOFoundationBridge)

// Chunk 1 (oo-3rb.220).

/*	The old method handed out the live dictionary, and callers only read it (OOStringExpander per
	key, OOConstToString, the verifier...). It is read far too often to convert per call, so one
	immutable copy is kept and rebuilt only when the descriptions are replaced; the one it replaces
	is autoreleased, as -loadDescriptions autoreleased the old dictionary.
*/
- (NSDictionary *) descriptions
{
	static NSDictionary		*sDescriptions = nil;
	static unsigned			sGeneration = 0;

	const oo::PList *descriptions = [self cxx_descriptions];
	if (sDescriptions == nil || sGeneration != [self cxx_descriptionsGeneration])
	{
		[sDescriptions autorelease];
		sDescriptions = [oo::ObjectFromPList(*descriptions) retain];
		sGeneration = [self cxx_descriptionsGeneration];
	}
	return sDescriptions;
}


// A fresh immutable copy per call (cold paths).
- (NSDictionary *) characters
{
	return oo::ObjectFromPList([self cxx_characters]);
}


- (NSDictionary *) missiontext
{
	return oo::ObjectFromPList([self cxx_missiontext]);
}


- (NSArray *) scenarios
{
	return oo::ObjectFromPList([self cxx_scenarios]);
}


// A nil name found no setting, as "" does.
- (NSDictionary *) explosionSetting:(NSString *)explosion
{
	return oo::ObjectFromPList([self cxx_explosionSetting:oo::StdString(explosion)]);
}


- (NSString *)descriptionForKey:(NSString *)key
{
	return oo::NSStringOrNil([self cxx_descriptionForKey:oo::StdString(key)]);
}


- (NSString *)descriptionForArrayKey:(NSString *)key index:(unsigned)index
{
	return oo::NSStringOrNil([self cxx_descriptionForArrayKey:oo::StdString(key) index:index]);
}


// Chunk 2 (oo-3rb.221). Dictionaries are fresh immutable copies per call (the old ones came from
// the system description manager, which also built them per call).

- (NSString *) keyForPlanetOverridesForSystem:(OOSystemID) s inGalaxy:(OOGalaxyID) g
{
	return oo::NSStringOrNil([self cxx_keyForPlanetOverridesForSystem:s inGalaxy:g]);
}


- (NSDictionary *) generateSystemData:(OOSystemID) s
{
	return oo::ObjectFromPList([self cxx_generateSystemData:s]);
}


- (NSDictionary *) generateSystemData:(OOSystemID) s useCache:(BOOL) useCache
{
	return oo::ObjectFromPList([self cxx_generateSystemData:s useCache:useCache]);
}


- (NSDictionary *) currentSystemData
{
	return oo::ObjectFromPList([self cxx_currentSystemData]);
}


// A nil key compared equal to nothing, as "" does; a nil manifest stays nullopt.
- (void) setSystemDataKey:(NSString*) key value:(NSObject*) object fromManifest:(NSString *)manifest
{
	[self cxx_setSystemDataKey:oo::StdString(key) value:object fromManifest:oo::OptionalString(manifest)];
}


- (void) setSystemDataForGalaxy:(OOGalaxyID) gnum planet:(OOSystemID) pnum key:(NSString *)key value:(id)object fromManifest:(NSString *)manifest forLayer:(OOSystemLayer)layer
{
	[self cxx_setSystemDataForGalaxy:gnum planet:pnum key:oo::StdString(key) value:object fromManifest:oo::OptionalString(manifest) forLayer:layer];
}


- (id) systemDataForGalaxy:(OOGalaxyID) gnum planet:(OOSystemID) pnum key:(NSString *)key
{
	return [self cxx_systemDataForGalaxy:gnum planet:pnum key:oo::StdString(key)];
}


- (NSArray *) systemDataKeysForGalaxy:(OOGalaxyID)gnum planet:(OOSystemID)pnum
{
	return oo::NSArrayFromStrings([self cxx_systemDataKeysForGalaxy:gnum planet:pnum]);
}


- (NSString *) getSystemName:(OOSystemID) sys
{
	return oo::NSStringOrNil([self cxx_getSystemName:sys]);
}


- (NSString *) getSystemName:(OOSystemID) sys forGalaxy:(OOGalaxyID) gnum
{
	return oo::NSStringOrNil([self cxx_getSystemName:sys forGalaxy:gnum]);
}


- (NSString *) getSystemInhabitants:(OOSystemID) sys
{
	return oo::NSStringOrNil([self cxx_getSystemInhabitants:sys]);
}


- (NSString *) getSystemInhabitants:(OOSystemID) sys plural:(BOOL)plural
{
	return oo::NSStringOrNil([self cxx_getSystemInhabitants:sys plural:plural]);
}


- (OOSystemID) findSystemFromName:(NSString *) sysName
{
	if (sysName == nil) return -1;	// no match found!
	return [self cxx_findSystemFromName:oo::StdString(sysName)];
}


- (NSString*) systemNameIndex:(OOSystemID) index
{
	return oo::NSStringOrNil([self cxx_systemNameIndex:index]);
}

@end


// Chunk 1 (oo-3rb.220). DESC() passes string literals: the key is never nil.
NSString *OOLookUpDescriptionPRIV(NSString *key)
{
	return oo::NSStringFrom(cxx_OOLookUpDescriptionPRIV(oo::StdString(key)));
}


NSString *OOLookUpPluralDescriptionPRIV(NSString *key, NSInteger count)
{
	return oo::NSStringFrom(cxx_OOLookUpPluralDescriptionPRIV(oo::StdString(key), count));
}
