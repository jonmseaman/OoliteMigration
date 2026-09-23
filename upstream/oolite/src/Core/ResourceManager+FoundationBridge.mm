/*

ResourceManager+FoundationBridge.mm

TRANSITIONAL: see ResourceManager+FoundationBridge.h. Each method forwards to its cxx_ counterpart
and converts the result exactly as the old method produced it (nil for nil, immutable collections).

*/

#import "ResourceManager.h"	// declares the bridge category at its end
#import "OOFoundationBridge.h"
#import "OOCacheManager.h"


/*	The loaders' cache keys (the same text +cxx_dictionaryFromFilesNamed:... and
	+cxx_arrayFromFilesNamed:... build). With cache:YES the old methods returned the object held in
	OOCacheManager, the same object on every call; the bridge returns that object too (for arrays,
	the fresh +arrayWithArray: copy of it the old method made), so a cached load is never rebuilt
	as a Foundation graph per call, and the cache's own clearing drops it.
*/
namespace {

NSString *DictionaryCacheKey(NSString *fileName, NSString *folderName, OOResourceMergeMode mergeMode)
{
	NSString *mergeType = nil;
	switch (mergeMode)
	{
		case MERGE_NONE:	mergeType = @"none";	break;
		case MERGE_BASIC:	mergeType = @"basic";	break;
		case MERGE_SMART:	mergeType = @"smart";	break;
	}
	if (mergeType == nil)  return nil;
	if (folderName != nil)  return [NSString stringWithFormat:@"%@/%@ merge:%@", folderName, fileName, mergeType];
	return [NSString stringWithFormat:@"%@ merge:%@", fileName, mergeType];
}


NSString *ArrayCacheKey(NSString *fileName, NSString *folderName, BOOL mergeFiles)
{
	return [NSString stringWithFormat:@"%@%@ merge:%@", (folderName != nil) ? [folderName stringByAppendingString:@"/"] : (NSString *)@"", fileName, mergeFiles ? @"yes" : @"no"];
}

}	// namespace


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


// oo-3rb.99: OXP manifests and compatibility

+ (NSDictionary *)manifestForIdentifier:(NSString *)identifier
{
	// The manifest as a Foundation graph (nil when there is none); its required_by set is an array.
	return oo::ObjectFromPList([self cxx_manifestForIdentifier:oo::StdString(identifier)]);
}


+ (BOOL) checkVersionCompatibility:(NSDictionary *)manifest forOXP:(NSString *)title
{
	return [self cxx_checkVersionCompatibility:oo::PListFrom(manifest) forOXP:oo::OptionalString(title)];
}


+ (BOOL) manifestHasConflicts:(NSDictionary *)manifest logErrors:(BOOL)logErrors
{
	return [self cxx_manifestHasConflicts:oo::PListFrom(manifest) logErrors:logErrors];
}


+ (BOOL) manifestHasMissingDependencies:(NSDictionary *)manifest logErrors:(BOOL)logErrors
{
	return [self cxx_manifestHasMissingDependencies:oo::PListFrom(manifest) logErrors:logErrors];
}


+ (BOOL) manifest:(NSDictionary *)manifest HasUnmetDependency:(NSDictionary *)required logErrors:(BOOL)logErrors
{
	return [self cxx_manifest:oo::PListFrom(manifest) HasUnmetDependency:oo::PListFrom(required) logErrors:logErrors];
}


+ (BOOL) matchVersions:(NSDictionary *)rangeDict withVersion:(NSString *)version
{
	return [self cxx_matchVersions:oo::PListFrom(rangeDict) withVersion:oo::StdString(version)];
}


// oo-3rb.101: merged plist loading

+ (BOOL) corePlist:(NSString *)fileName excludedAt:(NSString *)path
{
	if (path == nil || fileName == nil)  return NO;	// messaging nil answered NO: not excluded
	return [self cxx_corePlist:oo::StdString(fileName) excludedAt:oo::StdString(path)];
}


+ (NSDictionary *)dictionaryFromFilesNamed:(NSString *)fileName
								  inFolder:(NSString *)folderName
								  andMerge:(BOOL) mergeFiles
{
	return [self dictionaryFromFilesNamed:fileName inFolder:folderName mergeMode:mergeFiles ? MERGE_BASIC : MERGE_NONE cache:YES];
}


+ (NSDictionary *)dictionaryFromFilesNamed:(NSString *)fileName
								  inFolder:(NSString *)folderName
								 mergeMode:(OOResourceMergeMode)mergeMode
									 cache:(BOOL)useCache
{
	if (fileName == nil)  return nil;

	NSString *cacheKey = useCache ? DictionaryCacheKey(fileName, folderName, mergeMode) : nil;
	OOCacheManager *cacheMgr = [OOCacheManager sharedCache];
	if (cacheKey != nil)
	{
		id cached = [cacheMgr objectForKey:cacheKey inCache:@"dictionaries"];
		if (cached != nil)  return cached;
	}

	const oo::PList result = [self cxx_dictionaryFromFilesNamed:oo::StdString(fileName) inFolder:oo::OptionalString(folderName) mergeMode:mergeMode cache:useCache];
	if (cacheKey != nil)
	{
		id cached = [cacheMgr objectForKey:cacheKey inCache:@"dictionaries"];	// what the load just cached
		if (cached != nil)  return cached;
	}
	return oo::ObjectFromPList(result);
}


+ (NSArray *)arrayFromFilesNamed:(NSString *)fileName
						inFolder:(NSString *)folderName
						andMerge:(BOOL) mergeFiles
{
	return [self arrayFromFilesNamed:fileName inFolder:folderName andMerge:mergeFiles cache:YES];
}


+ (NSArray *)arrayFromFilesNamed:(NSString *)fileName
						inFolder:(NSString *)folderName
						andMerge:(BOOL) mergeFiles
						   cache:(BOOL)useCache
{
	if (fileName == nil)  return nil;

	NSString *cacheKey = useCache ? ArrayCacheKey(fileName, folderName, mergeFiles) : nil;
	OOCacheManager *cacheMgr = [OOCacheManager sharedCache];
	if (cacheKey != nil)
	{
		id cached = [cacheMgr objectForKey:cacheKey inCache:@"arrays"];
		if (cached != nil)  return [NSArray arrayWithArray:cached];
	}

	const oo::PList result = [self cxx_arrayFromFilesNamed:oo::StdString(fileName) inFolder:oo::OptionalString(folderName) andMerge:mergeFiles cache:useCache];
	if (cacheKey != nil)
	{
		id cached = [cacheMgr objectForKey:cacheKey inCache:@"arrays"];	// what the load just cached
		if (cached != nil)  return [NSArray arrayWithArray:cached];
	}
	// No file to merge was nil; a missing unmerged array went through +arrayWithArray: of nil, an empty array.
	if (result.isNull() && mergeFiles)  return nil;
	return [NSArray arrayWithArray:oo::ObjectFromPList(result)];
}


+ (NSString *) stringFromFilesNamed:(NSString *)fileName inFolder:(NSString *)folderName
{
	return [self stringFromFilesNamed:fileName inFolder:folderName cache:YES];
}


+ (NSString *) stringFromFilesNamed:(NSString *)fileName inFolder:(NSString *)folderName cache:(BOOL)useCache
{
	if (fileName == nil)  return nil;	// no path was found for a nil name
	return oo::NSStringOrNil([self cxx_stringFromFilesNamed:oo::StdString(fileName) inFolder:oo::OptionalString(folderName) cache:useCache]);
}

@end
