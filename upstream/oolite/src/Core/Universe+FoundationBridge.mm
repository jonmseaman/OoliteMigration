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
