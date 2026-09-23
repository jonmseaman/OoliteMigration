/*

ResourceManager+FoundationBridge.mm

TRANSITIONAL: see ResourceManager+FoundationBridge.h. Each method forwards to its cxx_ counterpart
and converts the result exactly as the old method produced it (nil for nil, immutable collections).

*/

#import "ResourceManager.h"	// declares the bridge category at its end
#import "OOFoundationBridge.h"


@implementation ResourceManager (OOFoundationBridge)

// oo-3rb.98: search paths and add-on selection

+ (NSArray *)rootPaths
{
	return oo::NSArrayFromStrings([self cxx_rootPaths]);
}


+ (NSArray *)userRootPaths
{
	return oo::NSArrayFromStrings([self cxx_userRootPaths]);
}


+ (NSString *)builtInPath
{
	return oo::NSStringOrNil([self cxx_builtInPath]);
}


+ (NSArray *)pathsWithAddOns
{
	return oo::NSArrayFromStrings([self cxx_pathsWithAddOns]);
}


+ (NSArray *)paths
{
	return oo::NSArrayFromStrings([self cxx_paths]);
}


+ (NSArray *)maskUserNameInPathArray:(NSArray *)inputPathArray
{
	return oo::NSArrayFromStrings([self cxx_maskUserNameInPathArray:oo::StringsFrom(inputPathArray)]);
}


+ (NSString *)maskUserName:(NSString *)name inPath:(NSString *)path
{
	return oo::NSStringOrNil([self cxx_maskUserName:oo::StdString(name) inPath:oo::StdString(path)]);
}


+ (NSString *)useAddOns
{
	return oo::NSStringOrNil([self cxx_useAddOns]);
}


+ (NSArray *)OXPsWithMessagesFound
{
	const std::vector<std::string> found = [self cxx_OXPsWithMessagesFound];
	if (found.empty())  return nil;	// the array was created by the first message
	return oo::NSArrayFromStrings(found);
}


+ (void)setUseAddOns:(NSString *)useAddOns
{
	[self cxx_setUseAddOns:oo::StdString(useAddOns)];
}


+ (void)addExternalPath:(NSString *)fileName
{
	[self cxx_addExternalPath:oo::StdString(fileName)];
}


+ (NSEnumerator *)pathEnumerator
{
	return [oo::NSArrayFromStrings([self cxx_paths]) objectEnumerator];
}


+ (NSEnumerator *)reversePathEnumerator
{
	return [oo::NSArrayFromStrings([self cxx_paths]) reverseObjectEnumerator];
}


+ (NSString *)errors
{
	return oo::NSStringOrNil([self cxx_errors]);
}


+ (NSString *) diagnosticFileLocation
{
	return oo::NSStringOrNil([self cxx_diagnosticFileLocation]);
}

@end
