/*

OOStringParsing+FoundationBridge.mm

TRANSITIONAL: see OOStringParsing+FoundationBridge.h. Each function forwards to its cxx_
counterpart and converts the result exactly as the old function produced it (nil for nil,
the same mutable/immutable collections).

*/

#import "OOStringParsing.h"	// declares the bridge at its end
#import "OOCocoa.h"
#import "OOFoundationBridge.h"


// oo-3rb.124: scanners, points, random seeds

NSMutableArray *ScanTokensFromString(NSString *values)
{
	// a nil string has no tokens, as before
	return [NSMutableArray arrayWithArray:oo::NSArrayFromStrings(oo::str::tokens(oo::StdString(values)))];
}


BOOL ScanVectorFromString(NSString *xyzString, Vector *outVector)
{
	return cxx_ScanVectorFromString(oo::OptionalString(xyzString), outVector);
}


BOOL ScanHPVectorFromString(NSString *xyzString, HPVector *outVector)
{
	return cxx_ScanHPVectorFromString(oo::OptionalString(xyzString), outVector);
}


BOOL ScanQuaternionFromString(NSString *wxyzString, Quaternion *outQuaternion)
{
	return cxx_ScanQuaternionFromString(oo::OptionalString(wxyzString), outQuaternion);
}


BOOL ScanVectorAndQuaternionFromString(NSString *xyzwxyzString, Vector *outVector, Quaternion *outQuaternion)
{
	return cxx_ScanVectorAndQuaternionFromString(oo::OptionalString(xyzwxyzString), outVector, outQuaternion);
}


Vector VectorFromString(NSString *xyzString, Vector defaultValue)
{
	return cxx_VectorFromString(oo::OptionalString(xyzString), defaultValue);
}


Quaternion QuaternionFromString(NSString *wxyzString, Quaternion defaultValue)
{
	return cxx_QuaternionFromString(oo::OptionalString(wxyzString), defaultValue);
}


NSString *StringFromPoint(NSPoint point)
{
	return oo::NSStringFrom(cxx_StringFromPoint(point));
}


NSPoint PointFromString(NSString *xyString)
{
	// nil has no tokens, as the empty string has none: the zero point either way
	return cxx_PointFromString(oo::StdString(xyString));
}


Random_Seed RandomSeedFromString(NSString *abcdefString)
{
	return cxx_RandomSeedFromString(oo::OptionalString(abcdefString));
}


NSString *StringFromRandomSeed(Random_Seed seed)
{
	return oo::NSStringFrom(cxx_StringFromRandomSeed(seed));
}


// oo-3rb.124: the NSString (OOUtilities) category, moved here verbatim

@implementation NSString (OOUtilities)

- (BOOL)pathHasExtension:(NSString *)extension
{
	return [[self pathExtension] caseInsensitiveCompare:extension] == NSOrderedSame;
}


- (BOOL)pathHasExtensionInArray:(NSArray *)extensions
{
	NSString		*extension = nil;

	foreach (extension, extensions)
	{
		if ([[self pathExtension] caseInsensitiveCompare:extension] == NSOrderedSame) return YES;
	}

	return NO;
}

@end
