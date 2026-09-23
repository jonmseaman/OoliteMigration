/*

ResourceManager.m

Oolite
Copyright (C) 2004-2013 Giles C Williams and contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
MA 02110-1301, USA.

*/

#import "ResourceManager.h"
#import "NSScannerOOExtensions.h"
#import "NSMutableDictionaryOOExtensions.h"
#import "NSStringOOExtensions.h"
#import "OOSound.h"
#import "OOCacheManager.h"
#import "Universe.h"
#import "OOStringParsing.h"
#import "OOPListParsing.h"
#import "MyOpenGLView.h"
#import "OOPListView.h"
#import "OOLogOutputHandler.h"
#import "NSFileManagerOOExtensions.h"
#import "OldSchoolPropertyListWriting.h"
#import "OOOXZManager.h"
#import "unzip.h"
#import "HeadUpDisplay.h"
#import "OODebugStandards.h"
#import "OOSystemDescriptionManager.h"

#import "OOJSScript.h"
#import "OOPListScript.h"

#import "OOManifestProperties.h"
#import "OOFoundationBridge.h"

#include "oofnd/StdLib.hpp"
#include "oofnd/String.hpp"
#include "oofnd/ResourcePaths.hpp"

namespace {

// OOCacheManager cache and keys for the search-path modification dates (the log classes are
// literals at their OOLog calls).
constexpr const char *kOOCacheSearchPathModDates	= "search path modification dates";
constexpr const char *kOOCacheKeySearchPaths		= "search paths";
constexpr const char *kOOCacheKeyModificationDates	= "modification dates";

}	// namespace



extern NSDictionary* ParseOOSScripts(NSString* script);


@interface ResourceManager (OOPrivate)

+ (void) checkOXPMessagesInPath:(const std::string &)path;
+ (void) checkPotentialPath:(const std::string &)path :(std::vector<std::string> &)searchPaths;
+ (BOOL) validateManifest:(const oo::PList &)manifest forOXP:(const std::string &)path;
+ (BOOL) areRequirementsFulfilled:(const oo::PList &)requirements forOXP:(const std::optional<std::string> &)path andFile:(const std::string &)file;
+ (void) filterSearchPathsForConflicts:(std::vector<std::string> &)searchPaths;
+ (BOOL) filterSearchPathsForRequirements:(std::vector<std::string> &)searchPaths;
+ (void) filterSearchPathsToExcludeScenarioOnlyPaths:(std::vector<std::string> &)searchPaths;
+ (void) filterSearchPathsByScenario:(std::vector<std::string> &)searchPaths;
+ (BOOL) manifestAllowedByScenario:(const oo::PList &)manifest;
+ (BOOL) manifestAllowedByScenario:(const oo::PList &)manifest withIdentifier:(const std::string &)identifier;
+ (BOOL) manifestAllowedByScenario:(const oo::PList &)manifest withTag:(const std::string &)tag;

+ (void) addErrorWithKey:(const std::string &)descriptionKey param1:(const std::string &)param1 param2:(const std::string &)param2;
+ (BOOL) checkCacheUpToDateForPaths:(const std::vector<std::string> &)searchPaths;
+ (void) logPaths;
+ (void) mergeRoleCategories:(NSDictionary *)catData intoDictionary:(NSMutableDictionary *)category;
+ (void) preloadFileLists;
+ (void) preloadFileListFromOXZ:(const std::string &)path forFolders:(const std::vector<std::string> &)folders;
+ (void) preloadFileListFromFolder:(const std::string &)path forFolders:(const std::vector<std::string> &)folders;
+ (void) preloadFilePathFor:(const std::string &)fileName inFolder:(const std::string &)subFolder atPath:(const std::string &)path;

@end


namespace {

// A path-scan error: a descriptions.plist key and the text of its two %@ parameters ("" for nil).
struct ResourceManagerError
{
	std::string key;
	std::string param1;
	std::string param2;
};

std::optional<std::string>	sUseAddOns;		// nullopt before the first scan (was nil)
std::vector<std::string>	sUseAddOnsParts;
std::vector<std::string>	sOXPsWithMessagesFound;
std::vector<std::string>	sExternalPaths;
std::vector<ResourceManagerError>	sErrors;
std::map<std::string, oo::PList, std::less<>>	sOXPManifests;	// identifier -> manifest (+ file_path, required_by)
std::optional<std::vector<std::string>>	sSearchPaths;	// empty and nullopt both mean "scan again" (was [sSearchPaths count] > 0)


// A manifest string property as get<NSString *>(key) answered it: nullopt where that was nil
// (missing, or neither a string nor a number).
std::optional<std::string> ManifestString(const oo::PList &manifest, const std::string &key)
{
	const oo::PList *value = manifest.find(key);
	if (value == nullptr || !(value->isString() || value->isNumber()))  return std::nullopt;
	return manifest.get<std::string>(key);
}


// -containsObject: of a string on the array (or set, held as an array) under key.
bool ManifestListContains(const oo::PList &manifest, const std::string &key, std::string_view string)
{
	const oo::PList *list = manifest.get<oo::PList::Array>(key);
	if (list == nullptr)  return false;
	for (const oo::PList &element : *list->getIf<oo::PList::Array>())
	{
		const std::string *elementString = element.getIf<std::string>();
		if (elementString != nullptr && *elementString == string)  return true;
	}
	return false;
}


// The strings of a required_by set (held as a sorted array of unique strings).
std::set<std::string> ManifestRequiredBy(const oo::PList &manifest)
{
	std::set<std::string> result;
	const oo::PList *list = manifest.get<oo::PList::Array>(oo::StdString(kOOManifestRequiredBy));
	if (list == nullptr)  return result;
	for (const oo::PList &element : *list->getIf<oo::PList::Array>())
	{
		if (const std::string *elementString = element.getIf<std::string>())  result.insert(*elementString);
	}
	return result;
}


// Whether a string is in searchPaths (-containsObject:).
bool PathListContains(const std::vector<std::string> &searchPaths, const std::string &path)
{
	return std::find(searchPaths.begin(), searchPaths.end(), path) != searchPaths.end();
}


// -removeObject: of a nil-able path: every equal element goes.
void RemovePath(std::vector<std::string> &searchPaths, const std::optional<std::string> &path)
{
	if (!path.has_value())  return;
	searchPaths.erase(std::remove(searchPaths.begin(), searchPaths.end(), *path), searchPaths.end());
}


// Whether +[NSString stringWithUTF8String:] would have accepted these bytes (it returns nil for
// malformed UTF-8): they survive the round trip through UTF-16 unchanged.
bool IsWellFormedUTF8(const std::string &bytes)
{
	return oo::utf16ToUtf8(oo::utf8ToUtf16(bytes)) == bytes;
}


// [path lastPathComponent] of a nil-able path, as %@ printed it.
std::optional<std::string> LastPathComponent(const std::optional<std::string> &path)
{
	if (!path.has_value())  return std::nullopt;
	return oo::str::lastPathComponent(*path);
}

}	// namespace

static BOOL				sFirstRun = YES;
static BOOL				sAllMet = NO;



// caches allow us to load any given file once only
//
static NSMutableDictionary *sSoundCache;
static NSMutableDictionary *sStringCache;



@implementation ResourceManager

+ (void) reset
{
	sFirstRun = YES;
	sUseAddOns.reset();
	sUseAddOnsParts.clear();
	sSearchPaths.reset();
	sOXPsWithMessagesFound.clear();
	sExternalPaths.clear();
	sErrors.clear();
	sOXPManifests.clear();
}


+ (void) resetManifestKnowledgeForOXZManager
{
	sUseAddOns.reset();
	sUseAddOnsParts.clear();
	sSearchPaths.reset();
	sOXPManifests.clear();
	[ResourceManager cxx_pathsWithAddOns];
}


+ (std::optional<std::string>) cxx_errors
{
	if (sErrors.empty())  return std::nullopt;
	
	// Expand error messages. This is deferred for localizability.
	std::vector<std::string> result;
	result.reserve(sErrors.size());
	for (const ResourceManagerError &error : sErrors)
	{
		std::optional<std::string> errStr = oo::OptionalString([UNIVERSE descriptionForKey:oo::NSStringFrom(error.key)]);
		if (errStr.has_value())
		{
			// The descriptions.plist format's %@ conversions take strings: %s with the same text.
			const std::string format = oo::str::replaceOccurrences(*errStr, "%@", "%s", oo::str::Search::literal);
			result.push_back(oo::str::format(format.c_str(), error.param1.c_str(), error.param2.c_str()));
		}
	}
	
	sErrors.clear();
	
	std::string joined;
	for (std::size_t i = 0; i != result.size(); ++i)
	{
		if (i != 0)  joined += "\n";
		joined += result[i];
	}
	return joined;
}


+ (std::vector<std::string>) cxx_rootPaths
{
	/* Built-in data, then managed OXZs, then manually installed ones,
	 * which may be useful for debugging/testing purposes.
	 * oo::ResourcePaths computes the same paths as [self builtInPath] and
	 * [[OOOXZManager sharedManager] installPath]. */
	static std::optional<std::vector<std::string>> sRootPaths;
	if (!sRootPaths.has_value())
	{
		const oo::ResourcePaths resourcePaths = oo::ResourcePaths::current();
		std::vector<std::string> paths{ oo::fs::utf8String(resourcePaths.builtInResourcesDirectory()), oo::fs::utf8String(resourcePaths.managedAddOnsDirectory()) };
		for (const std::string &path : [self cxx_userRootPaths])  paths.push_back(path);
		sRootPaths = std::move(paths);
	}
	return *sRootPaths;
}


+ (std::vector<std::string>) cxx_userRootPaths
{
	// the paths are now in order of preference as per yesterday's talk. -- Kaks 2010-05-05
	// (additional add-ons paths, <cwd>/../share/oolite/AddOns, <cwd>/AddOns, the extract path:
	// oo::ResourcePaths reproduces the list OOOXZManager and the current directory gave)
	static std::optional<std::vector<std::string>> sUserRootPaths;
	if (!sUserRootPaths.has_value())
	{
		std::vector<std::string> paths;
		for (const oo::fs::Path &path : oo::ResourcePaths::current().userRootDirectories())  paths.push_back(oo::fs::utf8String(path));
		sUserRootPaths = std::move(paths);
	}
	OOLog(@"searchPaths.debug",@"%@",oo::NSStringFrom(oo::DescriptionOf(oo::NSArrayFromStrings(*sUserRootPaths))));
	return *sUserRootPaths;
}


+ (std::optional<std::string>) cxx_builtInPath
{
	// Look for a "Resources" folder in the cwd, else cwd/../share/oolite/Resources (Windows & Linux)
	return oo::fs::utf8String(oo::ResourcePaths::current().builtInResourcesDirectory());
}

+ (std::vector<std::string>) cxx_pathsWithAddOns
{
	if (sSearchPaths.has_value() && !sSearchPaths->empty())  return *sSearchPaths;

	if (!sUseAddOns.has_value())
	{
		sUseAddOns = oo::StdString(SCENARIO_OXP_DEFINITION_ALL);
		sUseAddOnsParts = oo::str::split(*sUseAddOns, ";");
	}

	/* Handle special case of 'strict mode' efficiently */
	// testing actual string
	if (sUseAddOns == oo::StdString(SCENARIO_OXP_DEFINITION_NONE))
	{
		return { *[self cxx_builtInPath] };
	}

	sErrors.clear();

	// Copy those root paths that actually exist to search paths.
	const std::vector<std::string> rootPaths = [self cxx_rootPaths];
	std::vector<std::string> existingRootPaths;
	existingRootPaths.reserve(rootPaths.size());
	for (const std::string &root : rootPaths)
	{
		if (oo::fs::isDirectory(oo::fs::pathFromUTF8(root)))
		{
			existingRootPaths.push_back(root);
		}
	}

	// validate default search paths
	sSearchPaths.emplace();
	std::vector<std::string> &searchPaths = *sSearchPaths;
	for (const std::string &path : existingRootPaths)
	{
		[self checkPotentialPath:path :searchPaths];
	}

	// Iterate over root paths.
	for (const std::string &root : existingRootPaths)
	{
		// Iterate over each root path's contents.
		if (oo::fs::isDirectory(oo::fs::pathFromUTF8(root)))
		{
			// NSFileManager's recursive enumerator (with -skipDescendents) has no oo::fs form yet:
			// it lists, converted at the boundary, as it always did.
			NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:oo::NSStringFrom(root)];
			for (;;)
			{
				const std::optional<std::string> subPath = oo::OptionalString([dirEnum nextObject]);
				if (!subPath.has_value())  break;

				// Check if it's a directory.
				const std::string path = oo::str::appendingPathComponent(root, *subPath);
				const oo::fs::FileType type = oo::fs::fileType(oo::fs::pathFromUTF8(path));
				if (type != oo::fs::FileType::none)
				{
					if (type == oo::fs::FileType::directory)
					{
						// If it is, is it an OXP?.
						if (oo::str::lowercase(oo::str::pathExtension(path)) == "oxp")
						{
							[self checkPotentialPath:path :searchPaths];
							if (PathListContains(searchPaths, path))  [self checkOXPMessagesInPath:path];
						}
						else
						{
							// If not, don't search subdirectories.
							[dirEnum skipDescendents];
						}
					}
					else
					{
						// If not a directory, is it an OXZ?
						if (oo::str::lowercase(oo::str::pathExtension(path)) == "oxz")
						{
							[self checkPotentialPath:path :searchPaths];
							if (PathListContains(searchPaths, path))  [self checkOXPMessagesInPath:path];
						}
					}
				}
			}
		}
	}

	for (const std::string &path : sExternalPaths)
	{
		[self checkPotentialPath:path :searchPaths];
		if (PathListContains(searchPaths, path))  [self checkOXPMessagesInPath:path];
	}

	/* If a scenario restriction is *not* in place, remove
	 * scenario-only OXPs. */
	// test string
	if (sUseAddOns == oo::StdString(SCENARIO_OXP_DEFINITION_ALL))
	{
		[self filterSearchPathsToExcludeScenarioOnlyPaths:searchPaths];
	}

	/* This is a conservative filter. It probably gets rid of more
	 * OXPs than it technically needs to in certain situations with
	 * dependency chains, but really any conflict here needs to be
	 * resolved by the user rather than Oolite. The point is to avoid
	 * loading OXPs which we shouldn't; if doing so takes out other
	 * OXPs which would have been safe, that's not important. */
	[self filterSearchPathsForConflicts:searchPaths];

	/* This one needs to be run repeatedly to be sure. Take the chain
	 * A depends on B depends on C. A and B are installed. A is
	 * checked first, and depends on B, which is thought to be
	 * okay. So A is kept. Then B is checked and removed. A must then
	 * be rechecked. This function therefore is run repeatedly until a
	 * run of it removes no further items.
	 *
	 * There may well be more elegant and efficient ways to do this
	 * but this is already fast enough for most purposes.
	 */
	while (![self filterSearchPathsForRequirements:searchPaths]) {}

	/* If a scenario restriction is in place, restrict OXPs to the
	 * ones valid for the scenario only. */
	// test string
	if (sUseAddOns != oo::StdString(SCENARIO_OXP_DEFINITION_ALL))
	{
		[self filterSearchPathsByScenario:searchPaths];
	}

	[self checkCacheUpToDateForPaths:searchPaths];

	return searchPaths;
}


+ (void) preloadFileLists
{
	// folders which may contain files to be cached
	const std::vector<std::string> folders = { "AIs", "Images", "Models", "Music", "Scenarios", "Scripts", "Shaders", "Sounds", "Textures" };

	const std::vector<std::string> paths = [ResourceManager cxx_paths];
	for (auto pathIt = paths.rbegin(); pathIt != paths.rend(); ++pathIt)
	{
		const std::string &path = *pathIt;
		if (oo::str::hasSuffix(path, ".oxz"))
		{
			[self preloadFileListFromOXZ:path forFolders:folders];
		}
		else
		{
			[self preloadFileListFromFolder:path forFolders:folders];
		}
	}
}


+ (void) preloadFileListFromOXZ:(const std::string &)path forFolders:(const std::vector<std::string> &)folders
{
	unzFile uf = NULL;
	const char* zipname = path.c_str();
	char componentName[512];

	if (zipname != NULL)
	{
		uf = unzOpen64(zipname);
	}
	if (uf == NULL)
	{
		OOLog(@"resourceManager.error",@"Could not open .oxz at %@ as zip file",oo::NSStringFrom(path));
		return;
	}
	if (unzGoToFirstFile(uf) == UNZ_OK)
	{
		do
		{
			unzGetCurrentFileInfo64(uf, NULL,
									componentName, 512,
									NULL, 0,
									NULL, 0);
			const std::string zipEntry = componentName;
			// A name that is not UTF-8 was nil, and had no components.
			const std::vector<std::string> pathBits = IsWellFormedUTF8(zipEntry) ? oo::str::pathComponents(zipEntry) : std::vector<std::string>();
			if (pathBits.size() >= 2)
			{
				const std::string &folder = pathBits[0];
				if (std::find(folders.begin(), folders.end(), folder) != folders.end())
				{
					const std::string file = oo::str::pathWithComponents(std::vector<std::string>(pathBits.begin() + 1, pathBits.end()));
					const std::string fullPath = oo::str::appendingPathComponent(oo::str::appendingPathComponent(path, folder), file);

					[self preloadFilePathFor:file inFolder:folder atPath:fullPath];
				}
			}

		}
		while (unzGoToNextFile(uf) == UNZ_OK);
	}
	unzClose(uf);
}


+ (void) preloadFileListFromFolder:(const std::string &)path forFolders:(const std::vector<std::string> &)folders
{
	// search each subfolder for files
	for (const std::string &subFolder : folders)
	{
		const std::string subFolderPath = oo::str::appendingPathComponent(path, subFolder);
		const std::vector<std::string> fileList = oo::fs::directoryContents(oo::fs::pathFromUTF8(subFolderPath)).value_or(std::vector<std::string>());
		for (const std::string &fileName : fileList)
		{
			[self preloadFilePathFor:fileName inFolder:subFolder atPath:oo::str::appendingPathComponent(subFolderPath, fileName)];
		}
	}
}


+ (void) preloadFilePathFor:(const std::string &)fileName inFolder:(const std::string &)subFolder atPath:(const std::string &)path
{
	OOCacheManager	*cache = [OOCacheManager sharedCache];
	const std::string cacheKey = subFolder + "/" + fileName;
	// if nil, not found in another OXP already
	if ([cache cxx_objectForKey:cacheKey inCache:"resolved paths"] == nil)
	{
		OOLog(@"resourceManager.foundFile.preLoad", @"Found %@/%@ at %@", oo::NSStringFrom(subFolder), oo::NSStringFrom(fileName), oo::NSStringFrom(path));
		[cache cxx_setObject:oo::NSStringFrom(path) forKey:cacheKey inCache:"resolved paths"];	// the cache holds Foundation objects (an unmigrated callee)
	}
}


+ (std::vector<std::string>) cxx_paths
{
	if (EXPECT_NOT(!sSearchPaths.has_value()))
	{
		sSearchPaths.emplace();
	}
	return [self cxx_pathsWithAddOns];
}


+ (std::vector<std::string>) cxx_maskUserNameInPathArray:(const std::vector<std::string> &)inputPathArray
{
	std::vector<std::string> maskedArray;
	maskedArray.reserve(inputPathArray.size());
	const char *userNamePathEnvVar = 
#if OOLITE_WINDOWS
		SDL_getenv("USERPROFILE");
#else
		SDL_getenv("HOME");
#endif
	const std::string userName = oo::str::lastPathComponent(oo::str::format("%s", userNamePathEnvVar));
	for (const std::string &path : inputPathArray)
	{
		maskedArray.push_back(*[self cxx_maskUserName:userName inPath:path]);
	}
	return maskedArray;
}


+ (std::optional<std::string>) cxx_maskUserName:(const std::string &)name inPath:(const std::string &)path
{
	return oo::str::replaceOccurrences(path, name, "*", oo::str::Search::literal);
}


+ (std::optional<std::string>) cxx_useAddOns
{
	return sUseAddOns;
}


+ (void) cxx_setUseAddOns:(const std::string &)useAddOns
{
	if (sFirstRun || useAddOns != sUseAddOns)
	{
		[self reset];
		sFirstRun = NO;
		sUseAddOns = useAddOns;
		sUseAddOnsParts = oo::str::split(*sUseAddOns, ";");

		[ResourceManager clearCaches];
		OOHUDResetTextEngine();

		OOCacheManager *cmgr = [OOCacheManager sharedCache];
		/* only allow cache writes for the "all OXPs" default
		 *
		 * cache should be less necessary for restricted sets anyway */
		// testing the actual string here
		if (sUseAddOns == oo::StdString(SCENARIO_OXP_DEFINITION_ALL))
		{
			[cmgr reloadAllCaches];
			[cmgr setAllowCacheWrites:YES];
		}
		else
		{
			[cmgr clearAllCaches];
			[cmgr setAllowCacheWrites:NO];
		}
		
		[self checkCacheUpToDateForPaths:[self cxx_paths]];
		[self logPaths];
		/* preloading the file lists at this stage helps efficiency a
		 * lot when many OXZs are installed */
		[self preloadFileLists];

	}
}


+ (void) cxx_addExternalPath:(const std::string &)path
{
	if (!sSearchPaths.has_value())  sSearchPaths.emplace();
	if (!PathListContains(*sSearchPaths, path))
	{
		sSearchPaths->push_back(path);
		
		sExternalPaths.push_back(path);
	}
}


+ (std::vector<std::string>) cxx_OXPsWithMessagesFound
{
	return sOXPsWithMessagesFound;
}


+ (oo::PList) cxx_manifestForIdentifier:(const std::string &)identifier
{
	auto it = sOXPManifests.find(identifier);
	if (it == sOXPManifests.end())  return oo::PList();
	return it->second;
}


+ (void) checkOXPMessagesInPath:(const std::string &)path
{
	// OOArrayFromFile (OOPListParsing) is an unmigrated callee: its array arrives through oo::PListFrom.
	const oo::PList OXPMessageArray = oo::PListFrom(OOArrayFromFile(oo::NSStringFrom(oo::str::appendingPathComponent(path, "OXPMessages.plist"))));

	if (OXPMessageArray.count() > 0)
	{
		unsigned i;
		for (i = 0; i < OXPMessageArray.count(); i++)
		{
			// what the string extractor answered: a string (or a number's text); nil for anything else
			const oo::PList *oxpMessage = OXPMessageArray.at(i);
			if (oxpMessage != nullptr && (oxpMessage->isString() || oxpMessage->isNumber()))
			{
				OOLog(@"oxp.message", @"%@: %@", oo::NSStringFrom(path), oo::NSStringFrom(OXPMessageArray.at<std::string>(i)));
			}
		}
		sOXPsWithMessagesFound.push_back(oo::str::lastPathComponent(path));
	}
}


// Given a path to an assumed OXP (or other location where files are permissible), check for a requires.plist or manifest.plist and add to search paths if acceptable.
+ (void)checkPotentialPath:(const std::string &)path :(std::vector<std::string> &)searchPaths
{
	oo::PList				requirements;
	oo::PList				manifest;
	BOOL					requirementsMet = YES;
	const std::string		extension = oo::str::lowercase(oo::str::pathExtension(path));

	// OODictionaryFromFile (OOPListParsing) is an unmigrated callee: its dictionaries arrive through oo::PListFrom.
	if (extension != "oxz")
	{
		// OXZ format ignores requires.plist
		requirements = oo::PListFrom(OODictionaryFromFile(oo::NSStringFrom(oo::str::appendingPathComponent(path, "requires.plist"))));
		requirementsMet = [self areRequirementsFulfilled:requirements forOXP:path andFile:"requires.plist"];
	}
	if (!requirementsMet)
	{
		id version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
		OOLog(@"oxp.versionMismatch", @"OXP %@ is incompatible with version %@ of Oolite.", oo::NSStringFrom(path), version);
		[self addErrorWithKey:"oxp-is-incompatible" param1:oo::str::lastPathComponent(path) param2:oo::StdString(version)];
		return;
	}

	manifest = oo::PListFrom(OODictionaryFromFile(oo::NSStringFrom(oo::str::appendingPathComponent(path, "manifest.plist"))));
	if (manifest.isNull())
	{
		if (extension == "oxz")
		{
			OOLog(@"oxp.noManifest", @"OXZ %@ has no manifest.plist", oo::NSStringFrom(path));
			[self addErrorWithKey:"oxz-lacks-manifest" param1:oo::str::lastPathComponent(path) param2:""];
			return;
		}
		else
		{
			if (extension == "oxp")
			{
				cxx_OOStandardsError(oo::str::format("OXP %s has no manifest.plist", path.c_str()));
				if (OOEnforceStandards())
				{
					[self addErrorWithKey:"oxp-lacks-manifest" param1:oo::str::lastPathComponent(path) param2:""];
					return;
				}
			}
			// make up a basic manifest in relaxed mode or for base folders
			oo::PList::Dict basicManifest;
			basicManifest[oo::StdString(kOOManifestIdentifier)] = oo::PList("__oolite.tmp." + path);
			basicManifest[oo::StdString(kOOManifestVersion)] = oo::PList("1");
			basicManifest[oo::StdString(kOOManifestTitle)] = oo::PList("OXP without manifest");
			basicManifest[oo::StdString(kOOManifestRequiredOoliteVersion)] = oo::PList("1");
			manifest = oo::PList(std::move(basicManifest));
		}
	}

	requirementsMet = [self validateManifest:manifest forOXP:path];


	if (requirementsMet)
	{
		searchPaths.push_back(path);
	}
}


+ (BOOL) validateManifest:(const oo::PList &)manifest forOXP:(const std::string &)path
{
	BOOL 		OK = YES;
	const std::optional<std::string> identifier = ManifestString(manifest, oo::StdString(kOOManifestIdentifier));
	const std::optional<std::string> version = ManifestString(manifest, oo::StdString(kOOManifestVersion));
	const std::optional<std::string> required = ManifestString(manifest, oo::StdString(kOOManifestRequiredOoliteVersion));
	const std::optional<std::string> title = ManifestString(manifest, oo::StdString(kOOManifestTitle));

	if (!identifier.has_value())
	{
		OOLog(@"oxp.noManifest", @"OXZ %@ manifest.plist has no '%@' field.", oo::NSStringFrom(path), kOOManifestIdentifier);
		[self addErrorWithKey:"oxp-manifest-incomplete" param1:title.value_or("") param2:oo::StdString(kOOManifestIdentifier)];
		OK = NO;
	}
	if (!version.has_value())
	{
		OOLog(@"oxp.noManifest", @"OXZ %@ manifest.plist has no '%@' field.", oo::NSStringFrom(path), kOOManifestVersion);
		[self addErrorWithKey:"oxp-manifest-incomplete" param1:title.value_or("") param2:oo::StdString(kOOManifestVersion)];
		OK = NO;
	}
	if (!required.has_value())
	{
		OOLog(@"oxp.noManifest", @"OXZ %@ manifest.plist has no '%@' field.", oo::NSStringFrom(path), kOOManifestRequiredOoliteVersion);
		[self addErrorWithKey:"oxp-manifest-incomplete" param1:title.value_or("") param2:oo::StdString(kOOManifestRequiredOoliteVersion)];
		OK = NO;
	}
	if (!title.has_value())
	{
		OOLog(@"oxp.noManifest", @"OXZ %@ manifest.plist has no '%@' field.", oo::NSStringFrom(path), kOOManifestTitle);
		[self addErrorWithKey:"oxp-manifest-incomplete" param1:title.value_or("") param2:oo::StdString(kOOManifestTitle)];
		OK = NO;
	}
	if (!OK)
	{
		return NO;
	}
	OK = [self cxx_checkVersionCompatibility:manifest forOXP:title];

	if (!OK)
	{
		id ooliteVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
		OOLog(@"oxp.versionMismatch", @"OXP %@ is incompatible with version %@ of Oolite.", oo::NSStringFrom(path), ooliteVersion);
		[self addErrorWithKey:"oxp-is-incompatible" param1:oo::str::lastPathComponent(path) param2:oo::StdString(ooliteVersion)];
		return NO;
	}

	auto duplicate = sOXPManifests.find(*identifier);
	if (duplicate != sOXPManifests.end())
	{
		const std::optional<std::string> duplicatePath = ManifestString(duplicate->second, oo::StdString(kOOManifestFilePath));
		OOLog(@"oxp.duplicate", @"OXP %@ has the same identifier (%@) as %@ which has already been loaded.",oo::NSStringFrom(path),oo::NSStringFrom(*identifier),oo::NSStringOrNil(duplicatePath));
		[self addErrorWithKey:"oxp-manifest-duplicate" param1:path param2:duplicatePath.value_or("")];
		return NO;
	}
	oo::PList mData = manifest;
	// add an extra key
	if (oo::PList::Dict *dict = mData.getIf<oo::PList::Dict>())  (*dict)[oo::StdString(kOOManifestFilePath)] = oo::PList(path);
	sOXPManifests[*identifier] = std::move(mData);
	return YES;
}


+ (BOOL) cxx_checkVersionCompatibility:(const oo::PList &)manifest forOXP:(const std::optional<std::string> &)title
{
	const std::optional<std::string> required = ManifestString(manifest, oo::StdString(kOOManifestRequiredOoliteVersion));
	const std::optional<std::string> maxRequired = ManifestString(manifest, oo::StdString(kOOManifestMaximumOoliteVersion));
	// A nil required version ended the old key/value list at once: an empty requirements dictionary.
	oo::PList::Dict requirements;
	if (required.has_value())
	{
		requirements["version"] = oo::PList(*required);
		// ignore empty max version string rather than treating as "version 0"
		if (maxRequired.has_value() && !maxRequired->empty())  requirements["max_version"] = oo::PList(*maxRequired);
	}
	return [self areRequirementsFulfilled:oo::PList(std::move(requirements)) forOXP:title andFile:"manifest.plist"];
}


+ (BOOL) areRequirementsFulfilled:(const oo::PList &)requirements forOXP:(const std::optional<std::string> &)path andFile:(const std::string &)file
{
	BOOL				OK = YES;
	unsigned			conditionsHandled = 0;
	static std::optional<std::vector<unsigned>>	ooVersionComponents;

	if (requirements.isNull())  return YES;

	if (!ooVersionComponents.has_value())
	{
		ooVersionComponents = oo::str::versionComponents(oo::StdString([[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]));
	}

	// Check "version" (minimum version)
	if (OK)
	{
		// Not get<std::string>, because we need to be able to complain about non-strings.
		const oo::PList *requiredVersion = requirements.find("version");
		if (requiredVersion != nullptr)
		{
			++conditionsHandled;
			if (const std::string *requiredString = requiredVersion->getIf<std::string>())
			{
				if (oo::str::compareVersions(*ooVersionComponents, oo::str::versionComponents(*requiredString)) < 0)  OK = NO;
			}
			else
			{
				// %@ of [requirements class]: the class of the dictionary the old code was handed, which the bridge rebuilds
				OOLog(@"requirements.wrongType", @"Expected %@ entry \"%@\" to be string, but got %@ in OXP %@.", oo::NSStringFrom(file), @"version", [oo::ObjectFromPList(requirements) class], oo::NSStringOrNil(LastPathComponent(path)));
				OK = NO;
			}
		}
	}

	// Check "max_version" (minimum max_version)
	if (OK)
	{
		// Not get<std::string>, because we need to be able to complain about non-strings.
		const oo::PList *maxVersion = requirements.find("max_version");
		if (maxVersion != nullptr)
		{
			++conditionsHandled;
			if (const std::string *maxString = maxVersion->getIf<std::string>())
			{
				if (oo::str::compareVersions(*ooVersionComponents, oo::str::versionComponents(*maxString)) > 0)  OK = NO;
			}
			else
			{
				OOLog(@"requirements.wrongType", @"Expected %@ entry \"%@\" to be string, but got %@ in OXP %@.", oo::NSStringFrom(file), @"max_version", [oo::ObjectFromPList(requirements) class], oo::NSStringOrNil(LastPathComponent(path)));
				OK = NO;
			}
		}
	}

	if (OK && conditionsHandled < requirements.count())
	{
		// There are unknown requirement keys - don't support. NOTE: this check was not made pre 1.69!
		OOLog(@"requirements.unknown", @"requires.plist for OXP %@ contains unknown keys, rejecting.", oo::NSStringOrNil(LastPathComponent(path)));
		OK = NO;
	}

	return OK;
}


+ (BOOL) cxx_manifestHasConflicts:(const oo::PList &)manifest logErrors:(BOOL)logErrors
{
	const oo::PList *conflicts = manifest.get<oo::PList::Array>(oo::StdString(kOOManifestConflictOXPs), nullptr);
	// if it has a non-empty conflict_oxps list
	if (conflicts != nullptr && conflicts->count() > 0)
	{
		// iterate over that list
		for (const oo::PList &conflicting : *conflicts->getIf<oo::PList::Array>())
		{
			const std::optional<std::string> conflictID = ManifestString(conflicting, oo::StdString(kOOManifestRelationIdentifier));
			auto conflictManifest = conflictID.has_value() ? sOXPManifests.find(*conflictID) : sOXPManifests.end();
			// if the other OXP is in the list
			if (conflictManifest != sOXPManifests.end())
			{
				// then check versions
				if ([self cxx_matchVersions:conflicting withVersion:ManifestString(conflictManifest->second, oo::StdString(kOOManifestVersion)).value_or("")])
				{
					if (logErrors)
					{
						[self addErrorWithKey:"oxp-conflict" param1:ManifestString(manifest, oo::StdString(kOOManifestTitle)).value_or("") param2:ManifestString(conflictManifest->second, oo::StdString(kOOManifestTitle)).value_or("")];
						OOLog(@"oxp.conflict",@"OXP %@ conflicts with %@ and was removed from the loading list",oo::NSStringOrNil(LastPathComponent(ManifestString(manifest, oo::StdString(kOOManifestFilePath)))),oo::NSStringOrNil(LastPathComponent(ManifestString(conflictManifest->second, oo::StdString(kOOManifestFilePath)))));
					}
					return YES;
				}
			}
		}
	}
	return NO;
}


+ (void) filterSearchPathsForConflicts:(std::vector<std::string> &)searchPaths
{
	std::vector<std::string>	identifiers;	// identifier order (was hash order)
	identifiers.reserve(sOXPManifests.size());
	for (const auto &[identifier, manifest] : sOXPManifests)  identifiers.push_back(identifier);

	// take a copy because we'll mutate the original
	// foreach identified add-on
	for (const std::string &identifier : identifiers)
	{
		auto entry = sOXPManifests.find(identifier);
		if (entry != sOXPManifests.end())
		{
			const oo::PList manifest = entry->second;
			if ([self cxx_manifestHasConflicts:manifest logErrors:YES])
			{
				// then we have a conflict, so remove this path
				RemovePath(searchPaths, ManifestString(manifest, oo::StdString(kOOManifestFilePath)));
				sOXPManifests.erase(identifier);
			}
		}
	}
}


+ (BOOL) cxx_manifestHasMissingDependencies:(const oo::PList &)manifest logErrors:(BOOL)logErrors
{
	const oo::PList *requireds = manifest.get<oo::PList::Array>(oo::StdString(kOOManifestRequiresOXPs), nullptr);
	// if it has a non-empty required_oxps list
	if (requireds != nullptr && requireds->count() > 0)
	{
		// iterate over that list
		for (const oo::PList &required : *requireds->getIf<oo::PList::Array>())
		{
			if ([ResourceManager cxx_manifest:manifest HasUnmetDependency:required logErrors:logErrors])
			{
				return YES;
			}
		}
	}
	return NO;
}


+ (BOOL) cxx_manifest:(const oo::PList &)manifest HasUnmetDependency:(const oo::PList &)required logErrors:(BOOL)logErrors
{
	const std::optional<std::string> requiredID = ManifestString(required, oo::StdString(kOOManifestRelationIdentifier));
	auto requiredManifest = requiredID.has_value() ? sOXPManifests.find(*requiredID) : sOXPManifests.end();
	// if the other OXP is in the list
	BOOL requirementsMet = NO;
	if (requiredManifest != sOXPManifests.end())
	{
		// then check versions
		if ([self cxx_matchVersions:required withVersion:ManifestString(requiredManifest->second, oo::StdString(kOOManifestVersion)).value_or("")])
		{
			requirementsMet = YES;
			/* Mark the requiredManifest as a dependency of the
			 * requiring manifest */
			std::set<std::string> reqby = ManifestRequiredBy(requiredManifest->second);
			const std::size_t reqbycount = reqby.size();
			/* then add this manifest to its required set. This is
			 * done without checking if it's already there, because
			 * the list of nested requirements may have changed. */
			if (std::optional<std::string> identifier = ManifestString(manifest, oo::StdString(kOOManifestIdentifier)))  reqby.insert(*identifier);
			// *and* anything that requires this OXP to be installed
			const std::set<std::string> manifestReqby = ManifestRequiredBy(manifest);
			reqby.insert(manifestReqby.begin(), manifestReqby.end());
			if (reqbycount < reqby.size())
			{
				/* Then the set has increased in size. To handle
				 * potential cases with nested dependencies, need to
				 * re-run the requirement filter until all the sets
				 * stabilise. */
				sAllMet = NO;
			}
			// and push back into the requiring manifest (the set as a sorted array of unique strings)
			oo::PList::Array reqbyList;
			for (const std::string &identifier : reqby)  reqbyList.emplace_back(identifier);
			if (oo::PList::Dict *dict = requiredManifest->second.getIf<oo::PList::Dict>())  (*dict)[oo::StdString(kOOManifestRequiredBy)] = oo::PList(std::move(reqbyList));
		}
	}
	if (!requirementsMet)
	{
		if (logErrors)
		{
			const std::optional<std::string> requiredDescription = ManifestString(required, oo::StdString(kOOManifestRelationDescription));
			[self addErrorWithKey:"oxp-required" param1:ManifestString(manifest, oo::StdString(kOOManifestTitle)).value_or("") param2:requiredDescription.has_value() ? *requiredDescription : requiredID.value_or("")];
			OOLog(@"oxp.requirementMissing",@"OXP %@ had unmet requirements and was removed from the loading list",oo::NSStringOrNil(LastPathComponent(ManifestString(manifest, oo::StdString(kOOManifestFilePath)))));
		}
		return YES;
	}
	return NO;
}


+ (BOOL) filterSearchPathsForRequirements:(std::vector<std::string> &)searchPaths
{
	std::vector<std::string>	identifiers;	// identifier order (was hash order)
	identifiers.reserve(sOXPManifests.size());
	for (const auto &[identifier, manifest] : sOXPManifests)  identifiers.push_back(identifier);

	sAllMet = YES;

	// take a copy because we'll mutate the original
	// foreach identified add-on
	for (const std::string &identifier : identifiers)
	{
		auto entry = sOXPManifests.find(identifier);
		if (entry != sOXPManifests.end())
		{
			const oo::PList manifest = entry->second;
			if ([self cxx_manifestHasMissingDependencies:manifest logErrors:YES])
			{
				// then we have a missing requirement, so remove this path
				RemovePath(searchPaths, ManifestString(manifest, oo::StdString(kOOManifestFilePath)));
				sOXPManifests.erase(identifier);
				sAllMet = NO;
			}
		}
	}

	return sAllMet;
}


+ (BOOL) cxx_matchVersions:(const oo::PList &)rangeDict withVersion:(const std::string &)version
{
	const std::optional<std::string> minimum = ManifestString(rangeDict, oo::StdString(kOOManifestRelationVersion));
	const std::optional<std::string> maximum = ManifestString(rangeDict, oo::StdString(kOOManifestRelationMaxVersion));
	const std::vector<unsigned> isVersionComponents = oo::str::versionComponents(version);	// "" (was nil) compares as the empty version
	if (minimum.has_value())
	{
		if (oo::str::compareVersions(isVersionComponents, oo::str::versionComponents(*minimum)) < 0)
		{
			// earlier than minimum version
			return NO;
		}
	}
	if (maximum.has_value())
	{
		if (oo::str::compareVersions(isVersionComponents, oo::str::versionComponents(*maximum)) > 0)
		{
			// later than maximum version
			return NO;
		}
	}
	// either version was okay, or no version info so an unconditional match
	return YES;
}


+ (void) filterSearchPathsToExcludeScenarioOnlyPaths:(std::vector<std::string> &)searchPaths
{
	std::vector<std::string>	identifiers;	// identifier order (was hash order)
	identifiers.reserve(sOXPManifests.size());
	for (const auto &[identifier, manifest] : sOXPManifests)  identifiers.push_back(identifier);

	// take a copy because we'll mutate the original
	// foreach identified add-on
	for (const std::string &identifier : identifiers)
	{
		auto entry = sOXPManifests.find(identifier);
		if (entry != sOXPManifests.end())
		{
			const oo::PList manifest = entry->second;
			if (ManifestListContains(manifest, oo::StdString(kOOManifestTags), oo::StdString(kOOManifestTagScenarioOnly)))
			{
				RemovePath(searchPaths, ManifestString(manifest, oo::StdString(kOOManifestFilePath)));
				sOXPManifests.erase(identifier);
			}
		}
	}
}



+ (void) filterSearchPathsByScenario:(std::vector<std::string> &)searchPaths
{
	std::vector<std::string>	identifiers;	// identifier order (was hash order)
	identifiers.reserve(sOXPManifests.size());
	for (const auto &[identifier, manifest] : sOXPManifests)  identifiers.push_back(identifier);

	// take a copy because we'll mutate the original
	// foreach identified add-on
	for (const std::string &identifier : identifiers)
	{
		auto entry = sOXPManifests.find(identifier);
		if (entry != sOXPManifests.end())
		{
			const oo::PList manifest = entry->second;
			if (![ResourceManager manifestAllowedByScenario:manifest])
			{
				// then we don't need this one
				RemovePath(searchPaths, ManifestString(manifest, oo::StdString(kOOManifestFilePath)));
				sOXPManifests.erase(identifier);
			}
		}
	}
}


+ (BOOL) manifestAllowedByScenario:(const oo::PList &)manifest
{
	/* Checks for a couple of "never happens" cases */
#ifndef NDEBUG
	// test string
	if (sUseAddOns == oo::StdString(SCENARIO_OXP_DEFINITION_ALL))
	{
		OOLog(@"scenario.check", @"%@", @"Checked scenario allowances in all state - this is an internal error; please report this");
		return YES;
	}
	if (sUseAddOns == oo::StdString(SCENARIO_OXP_DEFINITION_NONE))
	{
		OOLog(@"scenario.check", @"%@", @"Checked scenario allowances in none state - this is an internal error; please report this");
		return NO;
	}
#endif
	if (ManifestString(manifest, oo::StdString(kOOManifestIdentifier)) == "org.oolite.oolite")
	{
		// the core data is always allowed!
		return YES;
	}

	const std::string byID = oo::StdString(SCENARIO_OXP_DEFINITION_BYID);
	const std::string byTag = oo::StdString(SCENARIO_OXP_DEFINITION_BYTAG);
	BOOL result = NO;
	for (const std::string &uaoBit : sUseAddOnsParts)
	{
		if (oo::str::hasPrefix(uaoBit, byID))
		{
			result |= [ResourceManager manifestAllowedByScenario:manifest withIdentifier:uaoBit.substr(byID.size())];
		}
		else if (oo::str::hasPrefix(uaoBit, byTag))
		{
			result |= [ResourceManager manifestAllowedByScenario:manifest withTag:uaoBit.substr(byTag.size())];
		}
	}
	return result;
}


+ (BOOL) manifestAllowedByScenario:(const oo::PList &)manifest withIdentifier:(const std::string &)identifier
{
	if (ManifestString(manifest, oo::StdString(kOOManifestIdentifier)) == identifier)
	{
		// manifest has the identifier - easy
		return YES;
	}
	// manifest is also allowed if a manifest with that identifier
	// requires it to be installed
	if (ManifestListContains(manifest, oo::StdString(kOOManifestRequiredBy), identifier))
	{
		return YES;
	}
	// otherwise, no
	return NO;
}


+ (BOOL) manifestAllowedByScenario:(const oo::PList &)manifest withTag:(const std::string &)tag
{
	if (ManifestListContains(manifest, oo::StdString(kOOManifestTags), tag))
	{
		// manifest has the tag - easy
		return YES;
	}
	// manifest is also allowed if a manifest with that tag
	// requires it to be installed
	for (const std::string &identifier : ManifestRequiredBy(manifest))
	{
		auto reqManifest = sOXPManifests.find(identifier);
		// need to check for nil as this one may already have been ruled out
		if (reqManifest != sOXPManifests.end() && ManifestListContains(reqManifest->second, oo::StdString(kOOManifestTags), tag))
		{
			return YES;
		}
	}
	// otherwise, no
	return NO;
}



+ (void) addErrorWithKey:(const std::string &)descriptionKey param1:(const std::string &)param1 param2:(const std::string &)param2
{
	// Every caller passes a key; a nil parameter arrives as "" (was `param ?: @""`).
	sErrors.push_back({ descriptionKey, param1, param2 });
}


+ (BOOL)checkCacheUpToDateForPaths:(const std::vector<std::string> &)searchPaths
{
	/*	Check if caches are up to date.
		The strategy is to use a two-entry cache. One entry is an array
		containing the search paths, the other an array of modification dates
		(in the same order). If either fails to match the correct settings,
		we delete both.
		OOCacheManager holds Foundation objects (an unmigrated callee): the two
		arrays are built for it at each call and compared with -isEqual:, as before.
	*/
	OOCacheManager		*cacheMgr = [OOCacheManager sharedCache];
	NSFileManager		*fmgr = [NSFileManager defaultManager];
	BOOL				upToDate = YES;
	id					oldPaths = nil;
	id					modDate = nil;

	if (EXPECT_NOT([[NSUserDefaults standardUserDefaults] boolForKey:@"always-flush-cache"]))
	{
		OOLog(@"dataCache.rebuild.explicitFlush", @"%@", @"Cache explicitly flushed with always-flush-cache preference. Rebuilding from scratch.");
		upToDate = NO;
	}
	else if ([MyOpenGLView pollShiftKey])
	{
		OOLog(@"dataCache.rebuild.explicitFlush", @"%@", @"Cache explicitly flushed with shift key. Rebuilding from scratch.");
		upToDate = NO;
	}

	oldPaths = [cacheMgr cxx_objectForKey:kOOCacheKeySearchPaths inCache:kOOCacheSearchPathModDates];
	if (upToDate && ![oldPaths isEqual:oo::NSArrayFromStrings(searchPaths)])
	{
		// OXPs added/removed
		if (oldPaths != nil) OOLog(@"dataCache.rebuild.pathsChanged", @"%@", @"Cache is stale (search paths have changed). Rebuilding from scratch.");
		upToDate = NO;
	}

	// Build modification date list. (We need this regardless of whether the search paths matched.)
	// The dates come from NSFileManager's attributes (oo::fs has no modification date yet).
	oo::PList::Array modDates;
	modDates.reserve(searchPaths.size());
	for (const std::string &path : searchPaths)
	{
		modDate = [[fmgr oo_fileAttributesAtPath:oo::NSStringFrom(path) traverseLink:YES] objectForKey:NSFileModificationDate];
		if (modDate != nil)
		{
			// Converts to double because I'm not sure the cache can deal with dates under GNUstep.
			modDates.emplace_back([modDate timeIntervalSince1970]);
		}
	}
	const oo::PList modDateList(std::move(modDates));

	if (upToDate && ![[cacheMgr cxx_objectForKey:kOOCacheKeyModificationDates inCache:kOOCacheSearchPathModDates] isEqual:oo::ObjectFromPList(modDateList)])
	{
		OOLog(@"dataCache.rebuild.datesChanged", @"%@", @"Cache is stale (modification dates have changed). Rebuilding from scratch.");
		upToDate = NO;
	}

	if (!upToDate)
	{
		[cacheMgr clearAllCaches];
		[cacheMgr cxx_setObject:oo::NSArrayFromStrings(searchPaths) forKey:kOOCacheKeySearchPaths inCache:kOOCacheSearchPathModDates];
		[cacheMgr cxx_setObject:oo::ObjectFromPList(modDateList) forKey:kOOCacheKeyModificationDates inCache:kOOCacheSearchPathModDates];
	}
	else OOLog(@"dataCache.upToDate", @"%@", @"Data cache is up to date.");

	return upToDate;
}


/* This method allows the exclusion of particular files from the plist
 * building when they're in builtInPath. The point of this is to allow
 * scenarios to avoid merging in core files without having to override
 * every individual entry (which may not always be possible
 * anyway). It only works on plists, but of course worldscripts can be
 * excluded by not including the plists which reference them, and
 * everything else can be excluded by not referencing it from a plist.
 */
+ (BOOL) corePlist:(NSString *)fileName excludedAt:(NSString *)path
{
	if (![path isEqualToString:oo::NSStringOrNil([self cxx_builtInPath])])
	{
		// non-core paths always okay
		return NO;
	}
	for (const std::string &uaoPart : sUseAddOnsParts)
	{
		NSString *uaoBit = oo::NSStringFrom(uaoPart);	// corePlist:excludedAt: converts in oo-3rb.101
		if ([uaoBit hasPrefix:SCENARIO_OXP_DEFINITION_NOPLIST])
		{
			NSString *plist = [uaoBit substringFromIndex:[SCENARIO_OXP_DEFINITION_NOPLIST length]];
			if ([plist isEqualToString:fileName])
			{
				// this core plist file should not be loaded at all
				return YES;
			}
		}
	}
	// then not excluded
	return NO;
}


+ (NSDictionary *)dictionaryFromFilesNamed:(NSString *)fileName
								  inFolder:(NSString *)folderName
								  andMerge:(BOOL) mergeFiles
{
	return [ResourceManager dictionaryFromFilesNamed:fileName inFolder:folderName mergeMode:mergeFiles ? MERGE_BASIC : MERGE_NONE cache:YES];
}


+ (NSDictionary *)dictionaryFromFilesNamed:(NSString *)fileName
								  inFolder:(NSString *)folderName
								 mergeMode:(OOResourceMergeMode)mergeMode
									 cache:(BOOL)cache
{
	id				result = nil;
	NSMutableArray	*results = nil;
	NSString		*cacheKey = nil;
	NSString		*mergeType = nil;
	OOCacheManager	*cacheMgr = [OOCacheManager sharedCache];
	NSEnumerator	*enumerator = nil;
	NSString		*path = nil;
	NSString		*dictPath = nil;
	NSDictionary	*dict = nil;
	
	if (fileName == nil)  return nil;
	
	switch (mergeMode)
	{
		case MERGE_NONE:
			mergeType = @"none";
			break;
		
		case MERGE_BASIC:
			mergeType = @"basic";
			break;
		
		case MERGE_SMART:
			mergeType = @"smart";
			break;
	}
	if (mergeType == nil)
	{
		OOLog(kOOLogParameterError, @"Unknown dictionary merge mode %u for %@. (This is an internal programming error, please report it.)", mergeMode, fileName);
		return nil;
	}
	
	if (cache)
	{
	
		if (folderName != nil)
		{
			cacheKey = [NSString stringWithFormat:@"%@/%@ merge:%@", folderName, fileName, mergeType];
		}
		else
		{
			cacheKey = [NSString stringWithFormat:@"%@ merge:%@", fileName, mergeType];
		}
		result = [cacheMgr objectForKey:cacheKey inCache:@"dictionaries"];
		if (result != nil)  return result;
	}
	
	if (mergeMode == MERGE_NONE)
	{
		// Find "last" matching dictionary
		for (enumerator = [oo::NSArrayFromStrings([ResourceManager cxx_paths]) reverseObjectEnumerator]; (path = [enumerator nextObject]); )
		{
			if (folderName != nil)
			{
				dictPath = [[path stringByAppendingPathComponent:folderName] stringByAppendingPathComponent:fileName];
				dict = OODictionaryFromFile(dictPath);
				if (dict != nil)  break;
			}
			dictPath = [path stringByAppendingPathComponent:fileName];
			dict = OODictionaryFromFile(dictPath);
			if (dict != nil)  break;
		}
		result = dict;
	}
	else
	{
		// Find all matching dictionaries
		results = [NSMutableArray array];
		for (enumerator = [oo::NSArrayFromStrings([ResourceManager cxx_paths]) objectEnumerator]; (path = [enumerator nextObject]); )
		{
			if ([ResourceManager corePlist:fileName excludedAt:path])
			{
				continue;
			}
			dictPath = [path stringByAppendingPathComponent:fileName];
			dict = OODictionaryFromFile(dictPath);
			if (dict != nil)  [results addObject:dict];
			if (folderName != nil)
			{
				dictPath = [[path stringByAppendingPathComponent:folderName] stringByAppendingPathComponent:fileName];
				dict = OODictionaryFromFile(dictPath);
				if (dict != nil)  [results addObject:dict];
			}
		}
		
		if ([results count] == 0)  return nil;
		
		// Merge result
		result = [NSMutableDictionary dictionary];
		
		for (enumerator = [results objectEnumerator]; (dict = [enumerator nextObject]); )
		{
			if (mergeMode == MERGE_SMART)  [result mergeEntriesFromDictionary:dict];
			else  [result addEntriesFromDictionary:dict];
		}
		result = [[result copy] autorelease];	// Make immutable
	}
	
	if (cache && result != nil)  [cacheMgr setObject:result forKey:cacheKey inCache:@"dictionaries"];
	
	return result;
}


+ (NSArray *) arrayFromFilesNamed:(NSString *)fileName inFolder:(NSString *)folderName andMerge:(BOOL) mergeFiles
{
	return [self arrayFromFilesNamed:fileName inFolder:folderName andMerge:mergeFiles cache:YES];
}


+ (NSArray *) arrayFromFilesNamed:(NSString *)fileName inFolder:(NSString *)folderName andMerge:(BOOL) mergeFiles cache:(BOOL)useCache
{
	id				result = nil;
	NSMutableArray	*results = nil;
	NSString		*cacheKey = nil;
	OOCacheManager	*cache = [OOCacheManager sharedCache];
	NSEnumerator	*enumerator = nil;
	NSString		*path = nil;
	NSString		*arrayPath = nil;
	NSMutableArray	*array = nil;
	NSArray			*arrayNonEditable = nil;
	
	if (fileName == nil)  return nil;
	
	if (useCache)
	{
		cacheKey = [NSString stringWithFormat:@"%@%@ merge:%@", (folderName != nil) ? [folderName stringByAppendingString:@"/"] : (NSString *)@"", fileName, mergeFiles ? @"yes" : @"no"];
		result = [cache objectForKey:cacheKey inCache:@"arrays"];
		if (result != nil)  return result;
	}
	
	if (!mergeFiles)
	{
		// Find "last" matching array
		for (enumerator = [oo::NSArrayFromStrings([ResourceManager cxx_paths]) reverseObjectEnumerator]; (path = [enumerator nextObject]); )
		{
			if (folderName != nil)
			{
				arrayPath = [[path stringByAppendingPathComponent:folderName] stringByAppendingPathComponent:fileName];
				arrayNonEditable = OOArrayFromFile(arrayPath);
				if (arrayNonEditable != nil)  break;
			}
			arrayPath = [path stringByAppendingPathComponent:fileName];
			arrayNonEditable = OOArrayFromFile(arrayPath);
			if (arrayNonEditable != nil)  break;
		}
		result = arrayNonEditable;
	}
	else
	{
		// Find all matching arrays
		results = [NSMutableArray array];
		for (enumerator = [oo::NSArrayFromStrings([ResourceManager cxx_paths]) objectEnumerator]; (path = [enumerator nextObject]); )
		{
			if ([ResourceManager corePlist:fileName excludedAt:path])
			{
				continue;
			}

			arrayPath = [path stringByAppendingPathComponent:fileName];
			array = [[OOArrayFromFile(arrayPath) mutableCopy] autorelease];
			if (array != nil) [results addObject:array];
	
			// Special handling for arrays merging. Currently, only equipment.plist, nebulatextures.plist and 
			// startextures.plist gets their objects merged.
			// A lookup index is required. For the equipment.plist items, this is the index corresponding to the
			// EQ_* string, which describes the role of an equipment item and is unique.
			// For nebula and star textures, this is the texture filename, although it can be overridden with a 
			// "key" property
			if ([array count] != 0 && ([[fileName lowercaseString] isEqualToString:@"nebulatextures.plist"] || 
				[[fileName lowercaseString] isEqualToString:@"startextures.plist"]))
				[self handleStarNebulaListMerging:results];

			if ([array count] != 0 && [[array objectAtIndex:0] isKindOfClass:[NSArray class]])
			{
				if ([[fileName lowercaseString] isEqualToString:@"equipment.plist"])
					[self handleEquipmentListMerging:results forLookupIndex:3]; // Index 3 is the role string (EQ_*).
			}
			if (folderName != nil)
			{
				arrayPath = [[path stringByAppendingPathComponent:folderName] stringByAppendingPathComponent:fileName];
				array = [[OOArrayFromFile(arrayPath) mutableCopy] autorelease];
				if (array != nil)  [results addObject:array];

				if ([array count] != 0 && ([[fileName lowercaseString] isEqualToString:@"nebulatextures.plist"] || 
					[[fileName lowercaseString] isEqualToString:@"startextures.plist"]))
					[self handleStarNebulaListMerging:results];

				if ([array count] != 0 && [[array objectAtIndex:0] isKindOfClass:[NSArray class]])
				{
					if ([[fileName lowercaseString] isEqualToString:@"equipment.plist"])
						[self handleEquipmentListMerging:results forLookupIndex:3]; // Index 3 is the role string (EQ_*).
				}
			}
		}
		
		if ([results count] == 0)  return nil;
		
		// Merge result
		result = [NSMutableArray array];
		
		for (enumerator = [results objectEnumerator]; (array = [enumerator nextObject]); )
		{
			[result addObjectsFromArray:array];
		}
		// if we're doing equipment.plist, do equipment overrides now, while the array is still mutable
		if ([[fileName lowercaseString] isEqualToString:@"equipment.plist"]) 
		{
			[self handleEquipmentOverrides:result];
		}
		result = [[result copy] autorelease];	// Make immutable
	}
	
	if (useCache && result != nil)  [cache setObject:result forKey:cacheKey inCache:@"arrays"];
	
	return [NSArray arrayWithArray:result];
}


// A method for handling merging of arrays. Currently used with the equipment.plist entries.
// The arrayToProcess array is scanned for repetitions of the item at lookup index location and, if found,
// the latest entry replaces the earliest.
+ (void) handleEquipmentListMerging: (NSMutableArray *)arrayToProcess forLookupIndex:(unsigned)lookupIndex
{
	NSUInteger i,j,k;
	NSMutableArray *refArray = [arrayToProcess objectAtIndex:[arrayToProcess count] - 1];
	
	// Any change to refArray will directly modify arrayToProcess.
	
	for (i = 0; i < [refArray count]; i++)
	{
		for (j = 0; j < [arrayToProcess count] - 1; j++)
		{
			NSUInteger count = [oo::PListView(arrayToProcess).at<NSArray *>(j) count];
			if (count == 0)  continue;
			
			for (k=0; k < count; k++)
			{
				id processValue = oo::PListView(oo::PListView(oo::PListView(arrayToProcess).at<NSArray *>(j)).at<NSArray *>(k)).at<id>(lookupIndex, nil);
				id refValue = oo::PListView(oo::PListView(refArray).at<NSArray *>(i)).at<id>(lookupIndex, nil);
				
				if ([processValue isEqual:refValue])
				{
					[[arrayToProcess objectAtIndex:j] replaceObjectAtIndex:k withObject:[refArray objectAtIndex:i]];
					[refArray removeObjectAtIndex:i];
				}
			}
		}
	}
	// arrayToProcess has been processed at this point. Any necessary merging has been done.
}


// handles processing of equipment-overrides.plist files, updating the source array with values found.
// format of file is slightly different to the standard equipment.plist file, in that it is a 
// dictionary of dictionary objects (rather than an array of arrays). this allows properties like
// techlevel, price, name/short_description and description/long_description to be updated via the overrides file.
+ (void) handleEquipmentOverrides: (NSMutableArray *)arrayToProcess
{
	NSEnumerator			*equipKeyEnum = nil;
	NSString				*equipKey = nil;
	NSDictionary			*overrides = nil;
	NSDictionary			*overridesEntry = nil;
	int 					i;

	overrides = [ResourceManager dictionaryFromFilesNamed:@"equipment-overrides.plist"
												 inFolder:@"Config"
												mergeMode:MERGE_SMART
													cache:NO];

	// cycle through all the equipment keys found in override files
	for (equipKeyEnum = [overrides keyEnumerator]; (equipKey = [equipKeyEnum nextObject]); )
	{
		overridesEntry = [overrides objectForKey:equipKey];
		// loop through our data array to find a match
		for (i = 0; i < [arrayToProcess count]; i++)
		{
			NSMutableArray	*equipArray = [[[arrayToProcess objectAtIndex:i] mutableCopy] autorelease];
			id refValue = oo::PListView(equipArray).at<id>(EQUIPMENT_KEY_INDEX, nil);
			// does the overridden equipment item exist in the equipment array? if so, get working
			if ([equipKey isEqual:refValue])
			{
				NSEnumerator 			*infoKeyEnum = nil;
				NSString				*infoKey;
				// cycle through all the properties found for this equipment key in the overrides file
				for (infoKeyEnum = [overridesEntry keyEnumerator]; (infoKey = [infoKeyEnum nextObject]); )
				{
					// special cases for the array items that don't have a direct keyname
					if ([infoKey isEqualToString:@"techlevel"]) 
						[equipArray replaceObjectAtIndex:EQUIPMENT_TECH_LEVEL_INDEX withObject:[overridesEntry objectForKey:infoKey]];
					else if ([infoKey isEqualToString:@"price"]) 
						[equipArray replaceObjectAtIndex:EQUIPMENT_PRICE_INDEX withObject:[overridesEntry objectForKey:infoKey]];
					else if ([infoKey isEqualToString:@"short_description"]) 
						[equipArray replaceObjectAtIndex:EQUIPMENT_SHORT_DESC_INDEX withObject:[overridesEntry objectForKey:infoKey]];
					else if ([infoKey isEqualToString:@"name"]) 
						[equipArray replaceObjectAtIndex:EQUIPMENT_SHORT_DESC_INDEX withObject:[overridesEntry objectForKey:infoKey]];
					else if ([infoKey isEqualToString:@"long_description"]) 
						[equipArray replaceObjectAtIndex:EQUIPMENT_LONG_DESC_INDEX withObject:[overridesEntry objectForKey:infoKey]];
					else if ([infoKey isEqualToString:@"description"]) 
						[equipArray replaceObjectAtIndex:EQUIPMENT_LONG_DESC_INDEX withObject:[overridesEntry objectForKey:infoKey]];
					else 
					{
						NSMutableDictionary		*extra = nil;
						// for everything else
						// do we actually have an extras dictionary?
						if (!oo::PListView(equipArray).at<NSDictionary *>(EQUIPMENT_EXTRA_INFO_INDEX)) 
						{
							// if not, create a blank one we can add to
							extra = [NSMutableDictionary dictionary];
						}
						else
						{
							extra = [oo::PListView(equipArray).at<NSDictionary *>(EQUIPMENT_EXTRA_INFO_INDEX) mutableCopy];
						}
						// special case for weapon_info && script_info, which are child dictionaries
						if ([infoKey isEqualToString:@"weapon_info"] || [infoKey isEqualToString:@"script_info"])
						{
							NSEnumerator			*subEnum = nil;
							NSString				*subKey;
							NSMutableDictionary		*subInfo = nil;
							NSDictionary			*subOverrides = nil;
							// do we actually have a weapon_info/script_info dictionary?
							if (!oo::PListView(extra).get<NSDictionary *>(infoKey)) 
							{
								// if not, create a blank dictionary we can add to
								subInfo = [NSMutableDictionary dictionary];
							} 
							else 
							{
								subInfo = [oo::PListView(extra).get<NSDictionary *>(infoKey) mutableCopy];
							}
							subOverrides = oo::PListView(overridesEntry).get<NSDictionary *>(infoKey);
							// cycle through all the sub keys found in the overrides file for this equipment key item
							for (subEnum = [subOverrides keyEnumerator]; (subKey = [subEnum nextObject]); )
							{
								[subInfo setObject:[subOverrides objectForKey:subKey] forKey:subKey];
							}
							[extra setObject:[[subInfo copy] autorelease] forKey:infoKey];
						}
						else
						{
							// for all other keys in the extras dictionary
							[extra setObject:[overridesEntry objectForKey:infoKey] forKey:infoKey];
						}
						[equipArray replaceObjectAtIndex:EQUIPMENT_EXTRA_INFO_INDEX withObject:[[extra copy] autorelease]];
					}
				}
				[arrayToProcess replaceObjectAtIndex:i withObject:equipArray];
			}
		}
	}
}


// A method for handling merging of arrays. Currently used with the nebulatextures.plist and startextures.plist entries.
// uses the "texture" filename as the key value, or "key" if found
+ (void) handleStarNebulaListMerging: (NSMutableArray *)arrayToProcess
{
	NSUInteger i,j,k;
	NSMutableArray *refArray = [arrayToProcess objectAtIndex:[arrayToProcess count] - 1];

	// Any change to refArray will directly modify arrayToProcess.	
	for (i = 0; i < [refArray count]; i++)
	{
		for (j = 0; j < [arrayToProcess count] - 1; j++)
		{
			NSUInteger count = [oo::PListView(arrayToProcess).at<NSArray *>(j) count];
			if (count == 0)  continue;

			for (k = 0; k < count; k++) 
			{
				id processValue = oo::PListView(oo::PListView(arrayToProcess).at<NSArray *>(j)).at<id>(k, nil);
				id refValue = oo::PListView(refArray).at<id>(i, nil);
				NSString *key1 = nil;
				NSString *key2 = nil;

				if ([processValue isKindOfClass:[NSString class]]) 
				{
					key1 = processValue;
				}
				else if ([processValue isKindOfClass:[NSDictionary class]])
				{
					if (![processValue objectForKey:@"key"]) 
					{
						key1 = [processValue objectForKey:@"texture"];
					}
					else
					{
						key1 = [processValue objectForKey:@"key"];
					}
				}
				if (!key1) continue;

				if ([refValue isKindOfClass:[NSString class]]) 
				{
					key2 = refValue;
				}
				else if ([refValue isKindOfClass:[NSDictionary class]])
				{
					if (![refValue objectForKey:@"key"])
					{
						key2 = [refValue objectForKey:@"texture"];
					}
					else
					{
						key2 = [refValue objectForKey:@"key"];
					}
				}
				if (!key2) continue;

				if ([key1 isEqual:key2])
				{
					[[arrayToProcess objectAtIndex:j] replaceObjectAtIndex:k withObject:[refArray objectAtIndex:i]];
					[refArray removeObjectAtIndex:i];
				}

			}
		}
	}
	// arrayToProcess has been processed at this point. Any necessary merging has been done.
}


+ (NSDictionary *) whitelistDictionary
{
	static NSDictionary *whitelistDictionary = nil;
	static BOOL loaded = NO;	// a missing whitelist is remembered as nil, not retried
	
	if (!loaded)
	{
		NSString *path = [[oo::NSStringOrNil([ResourceManager cxx_builtInPath]) stringByAppendingPathComponent:@"Config"] stringByAppendingPathComponent:@"whitelist.plist"];
		whitelistDictionary = [NSDictionary dictionaryWithContentsOfFile:path];
		loaded = YES;
		
		[whitelistDictionary retain];
	}
	
	return whitelistDictionary;
}


static NSString *LogClassKeyRoot(NSString *key)
{
	NSRange dot = [key rangeOfString:@"."];
	if (dot.location != NSNotFound)
	{
		return [key substringToIndex:dot.location];
	}
	else
	{
		return key;
	}
}


+ (NSDictionary *) logControlDictionary
{
	// Load built-in copy of logcontrol.plist.
	NSString *path = [[oo::NSStringOrNil([ResourceManager cxx_builtInPath]) stringByAppendingPathComponent:@"Config"]
					  stringByAppendingPathComponent:@"logcontrol.plist"];
	NSMutableDictionary *logControl = [NSMutableDictionary dictionaryWithDictionary:OODictionaryFromFile(path)];
	if (logControl == nil)  logControl = [NSMutableDictionary dictionary];
	
	// Build list of root log message classes that appear in the built-in list.
	NSMutableSet *coreRoots = [NSMutableSet set];
	NSString *key = nil;
	foreachkey (key, logControl)
	{
		[coreRoots addObject:LogClassKeyRoot(key)];
	}
	
	NSArray *rootPaths = oo::NSArrayFromStrings([self cxx_rootPaths]);
	NSString *configPath = nil;
	NSDictionary *dict = nil;
	
	// Look for logcontrol.plists inside OXPs (but not in root paths). These are not allowed to define keys in hierarchies used by the build-in one.
	foreach (path, oo::NSArrayFromStrings([self cxx_paths]))
	{
		if ([rootPaths containsObject:path])  continue;
		
		configPath = [[path stringByAppendingPathComponent:@"Config"]
					  stringByAppendingPathComponent:@"logcontrol.plist"];
		dict = OODictionaryFromFile(configPath);
		if (dict == nil)
		{
			configPath = [path stringByAppendingPathComponent:@"logcontrol.plist"];
			dict = OODictionaryFromFile(configPath);
		}
		foreachkey (key, dict)
		{
			if (![coreRoots containsObject:LogClassKeyRoot(key)])
			{
				[logControl setObject:[dict objectForKey:key] forKey:key];
			}
		}
	}
	
	// Now, look for logcontrol.plists in root paths, i.e. not within OXPs. These are allowed to override the built-in copy.
	foreach (path, rootPaths)
	{
		configPath = [[path stringByAppendingPathComponent:@"Config"]
					  stringByAppendingPathComponent:@"logcontrol.plist"];
		dict = OODictionaryFromFile(configPath);
		if (dict == nil)
		{
			configPath = [path stringByAppendingPathComponent:@"logcontrol.plist"];
			dict = OODictionaryFromFile(configPath);
		}
		foreachkey (key, dict)
		{
			[logControl setObject:[dict objectForKey:key] forKey:key];
		}
	}
	
	// Finally, look in preferences, which can override all of the above.
	dict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"logging-enable"];
	if (dict != nil)  [logControl addEntriesFromDictionary:dict];
	
	return logControl;
}


+ (NSDictionary *) roleCategoriesDictionary
{
	NSMutableDictionary *roleCategories = [NSMutableDictionary dictionaryWithCapacity:16];

	NSString *path = nil;
	NSString *configPath = nil;
	NSDictionary *categories = nil;
	
	foreach (path, oo::NSArrayFromStrings([self cxx_paths]))
	{
		if ([ResourceManager corePlist:@"role-categories.plist" excludedAt:path])
		{
			continue;
		}

		configPath = [[path stringByAppendingPathComponent:@"Config"]
					  stringByAppendingPathComponent:@"role-categories.plist"];
		categories = OODictionaryFromFile(configPath);
		if (categories != nil)
		{
			[ResourceManager mergeRoleCategories:categories intoDictionary:roleCategories];
		}
	}
	
	/* If the old pirate-victim-roles files exist, merge them in */
	NSArray *pirateVictims = [ResourceManager arrayFromFilesNamed:@"pirate-victim-roles.plist" inFolder:@"Config" andMerge:YES];
	if (OOEnforceStandards() && [pirateVictims count] > 0)
	{
		OOStandardsDeprecated(@"pirate-victim-roles.plist is still being used.");
	}
	[ResourceManager mergeRoleCategories:[NSDictionary dictionaryWithObject:pirateVictims forKey:@"oolite-pirate-victim"] intoDictionary:roleCategories];

	return [[roleCategories copy] autorelease];
}


+ (void) mergeRoleCategories:(NSDictionary *)catData intoDictionary:(NSMutableDictionary *)categories
{
	NSMutableSet *contents = nil;
	NSArray *catDataEntry = nil;
	NSString *key;
	foreachkey (key, catData)
	{
		contents = [categories objectForKey:key];
		if (contents == nil)
		{
			contents = [NSMutableSet setWithCapacity:16];
			[categories setObject:contents forKey:key];
		}
		catDataEntry = oo::PListView(catData).get<NSArray *>(key);
		OOLog(@"shipData.load.roleCategories", @"Adding %ld entries for category %@", (unsigned long)[catDataEntry count], key);
		[contents addObjectsFromArray:catDataEntry];
	}
}


+ (OOSystemDescriptionManager *) systemDescriptionManager
{
	OOLog(@"resourceManager.planetinfo.load", @"%@", @"Initialising manager");
	OOSystemDescriptionManager *manager = [[OOSystemDescriptionManager alloc] init];
	
	NSString *path = nil;
	NSString *configPath = nil;
	NSDictionary *categories = nil;
	NSString *systemKey = nil;

	foreach (path, oo::NSArrayFromStrings([self cxx_paths]))
	{
		if ([ResourceManager corePlist:@"planetinfo.plist" excludedAt:path])
		{
			continue;
		}
		configPath = [[path stringByAppendingPathComponent:@"Config"]
					  stringByAppendingPathComponent:@"planetinfo.plist"];
		categories = OODictionaryFromFile(configPath);
		if (categories != nil)
		{
			foreachkey (systemKey,categories)
			{
				NSDictionary *values = oo::PListView(categories).get<NSDictionary *>(systemKey, nil);
				if (values != nil)
				{
					if ([systemKey isEqualToString:PLANETINFO_UNIVERSAL_KEY])
					{
						[manager setUniversalProperties:values];
					}
					else if ([systemKey isEqualToString:PLANETINFO_INTERSTELLAR_KEY])
					{
						[manager setInterstellarProperties:values];
					}
					else
					{
						[manager setProperties:values forSystemKey:systemKey];
					}
				}
			}
		}
	}
	OOLog(@"resourceManager.planetinfo.load", @"%@", @"Caching routes");
	[manager buildRouteCache];
	OOLog(@"resourceManager.planetinfo.load", @"%@", @"Initialised manager");
	return [manager autorelease];
}



+ (NSDictionary *) shaderBindingTypesDictionary
{
	static id shaderBindingTypesDictionary = nil;
	
	if (shaderBindingTypesDictionary == nil)
	{
		@autoreleasepool
		{
			NSString *path = [[oo::NSStringOrNil([ResourceManager cxx_builtInPath]) stringByAppendingPathComponent:@"Config"] stringByAppendingPathComponent:@"shader-uniform-bindings.plist"];
			NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
			NSArray *keys = [dict allKeys];
			
			// Resolve all $inherit keys.
			unsigned changeCount = 0;
			do {
				changeCount = 0;
				NSString *key = nil;
				foreach (key, keys)
				{
					NSDictionary *value = oo::PListView(dict).get<NSDictionary *>(key);
					NSString *inheritKey = oo::PListView(value).get<NSString *>(@"$inherit");
					if (inheritKey != nil)
					{
						changeCount++;
						NSMutableDictionary *mutableValue = [[value mutableCopy] autorelease];
						[mutableValue removeObjectForKey:@"$inherit"];
						NSDictionary *inherited = oo::PListView(dict).get<NSDictionary *>(inheritKey);
						if (inherited != nil)
						{
							[mutableValue addEntriesFromDictionary:inherited];
						}
						
						[dict setObject:[[mutableValue copy] autorelease] forKey:key];
					}
				}
			} while (changeCount != 0);
			
			shaderBindingTypesDictionary = [dict copy];
		}
	}
	
	return shaderBindingTypesDictionary;
}


+ (NSString *) pathForFileNamed:(NSString *)fileName inFolder:(NSString *)folderName
{
	return [self pathForFileNamed:fileName inFolder:folderName cache:YES];
}


/* This is extremely expensive to call with useCache:NO */
+ (NSString *) pathForFileNamed:(NSString *)fileName inFolder:(NSString *)folderName cache:(BOOL)useCache
{
	NSString		*result = nil;
	NSString		*cacheKey = nil;
	OOCacheManager	*cache = [OOCacheManager sharedCache];
	NSString		*path = nil;
	NSString		*filePath = nil;
	NSFileManager	*fmgr = nil;
	
	if (fileName == nil)  return nil;
	
	if (cache)
	{
		if (folderName != nil)  cacheKey = [NSString stringWithFormat:@"%@/%@", folderName, fileName];
		else  cacheKey = fileName;
		result = [cache objectForKey:cacheKey inCache:@"resolved paths"];
		if (result != nil)  return result;
	}
	
	// Search for file
	fmgr = [NSFileManager defaultManager];
	// reverse object enumerator allows OXPs to override core
	foreach (path, [oo::NSArrayFromStrings([ResourceManager cxx_paths]) reverseObjectEnumerator])
	{
		filePath = [[path stringByAppendingPathComponent:folderName] stringByAppendingPathComponent:fileName];
		if ([fmgr oo_oxzFileExistsAtPath:filePath])
		{
			result = filePath;
			break;
		}
		
		filePath = [path stringByAppendingPathComponent:fileName];
		if ([fmgr oo_oxzFileExistsAtPath:filePath])
		{
			result = filePath;
			break;
		}
	}
	
	if (result != nil)
	{
		OOLog(@"resourceManager.foundFile", @"Found %@/%@ at %@", folderName, fileName, filePath);
		if (useCache)
		{
			[cache setObject:result forKey:cacheKey inCache:@"resolved paths"];
		}
	}
	return result;
}


/* use extreme caution in calling with usePathCache:NO - this can be
 * an extremely expensive operation */
+ (id) retrieveFileNamed:(NSString *)fileName
				inFolder:(NSString *)folderName
				   cache:(NSMutableDictionary **)ioCache
					 key:(NSString *)key
				   class:(Class)klass
			usePathCache:(BOOL)useCache
{
	id				result = nil;
	NSString		*path = nil;
	
	if (ioCache)
	{
		if (key == nil)  key = [NSString stringWithFormat:@"%@:%@", folderName, fileName];
		if (*ioCache != nil)
		{
			// return the cached object, if any
			result = [*ioCache objectForKey:key];
			if (result)  return result;
		}
	}
	
	path = [self pathForFileNamed:fileName inFolder:folderName cache:useCache];
	if (path != nil)  result = [[[klass alloc] initWithContentsOfFile:path] autorelease];
	
	if (result != nil && ioCache != NULL)
	{
		if (*ioCache == nil)  *ioCache = [[NSMutableDictionary alloc] init];
		[*ioCache setObject:result forKey:key];
	}
	
	return result;
}


+ (OOMusic *) ooMusicNamed:(NSString *)fileName inFolder:(NSString *)folderName
{
	return [self retrieveFileNamed:fileName
						  inFolder:folderName
							 cache:NULL	// Don't cache music objects; minimizing latency isn't really important.
							   key:[NSString stringWithFormat:@"OOMusic:%@:%@", folderName, fileName]
							 class:[OOMusic class]
					  usePathCache:YES];
}


+ (OOSound *) ooSoundNamed:(NSString *)fileName inFolder:(NSString *)folderName
{
	return [self retrieveFileNamed:fileName
						  inFolder:folderName
							 cache:&sSoundCache
							   key:[NSString stringWithFormat:@"OOSound:%@:%@", folderName, fileName]
							 class:[OOSound class]
					  usePathCache:YES];
}


+ (NSString *) stringFromFilesNamed:(NSString *)fileName inFolder:(NSString *)folderName
{
	return [self stringFromFilesNamed:fileName inFolder:folderName cache:YES];
}


+ (NSString *) stringFromFilesNamed:(NSString *)fileName inFolder:(NSString *)folderName cache:(BOOL)useCache
{
	id				result = nil;
	NSString		*path = nil;
	NSString		*key = nil;
	
	if (useCache)
	{
		key = [NSString stringWithFormat:@"%@:%@", folderName, fileName];
		if (sStringCache != nil)
		{
			// return the cached object, if any
			result = [sStringCache objectForKey:key];
			if (result)  return result;
		}
	}
	
	path = [self pathForFileNamed:fileName inFolder:folderName cache:YES];
	if (path != nil)  result = [NSString stringWithContentsOfUnicodeFile:path];
	
	if (result != nil && useCache)
	{
		if (sStringCache == nil)  sStringCache = [[NSMutableDictionary alloc] init];
		[sStringCache setObject:result forKey:key];
	}
	
	return result;
}


+ (NSDictionary *)loadScripts
{
	NSMutableDictionary			*loadedScripts = nil;
	NSArray						*results = nil;
	NSArray						*paths = nil;
	NSString					*path = nil;
	OOScript					*script = nil;
	NSString					*name = nil;
	
	OOLog(@"script.load.world.begin", @"%@", @"Loading world scripts...");
	
	loadedScripts = [NSMutableDictionary dictionary];
	paths = oo::NSArrayFromStrings([ResourceManager cxx_paths]);
	foreach (path, paths)
	{
		// excluding world-scripts.plist also excludes script.js / script.plist
		// though as those core files don't and won't exist this is not
		// a problem.
		if (![ResourceManager corePlist:@"world-scripts.plist" excludedAt:path])
		{
			@autoreleasepool
			{
				@try
				{
					results = [OOScript worldScriptsAtPath:[path stringByAppendingPathComponent:@"Config"]];
					if (results == nil) results = [OOScript worldScriptsAtPath:path];
					if (results != nil)
					{
						foreach (script, results)
						{
							name = [script name];
							if (name != nil)  [loadedScripts setObject:script forKey:name];
							else  OOLog(@"script.load.unnamed", @"Discarding anonymous script %@", script);
						}
					}
				}
				@catch (NSException *exception)
				{
					OOLog(@"script.load.exception", @"***** %s encountered exception %@ (%@) while trying to load script from %@ -- ignoring this location.", __PRETTY_FUNCTION__, [exception name], [exception reason], path);
					// Ignore exception and keep loading other scripts.
				}
			}
		}
	}
	
	if (OOLogWillDisplayMessagesInClass(@"script.load.world.listAll"))
	{
		NSUInteger count = [loadedScripts count];
		if (count != 0)
		{
			NSMutableArray		*displayNames = nil;
			OOScript			*script = nil;
			NSString			*displayString = nil;
			
			displayNames = [NSMutableArray arrayWithCapacity:count];
			
			foreach (script, [loadedScripts allValues])
			{
				[displayNames addObject:[script displayName]];
			}
			
			displayString = [[displayNames sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] componentsJoinedByString:@"\n    "];
			OOLog(@"script.load.world.listAll", @"Loaded %zu world scripts:\n    %@", count, displayString);
		}
		else
		{
			OOLog(@"script.load.world.listAll", @"%@", @"*** No world scripts loaded.");
		}
	}
	
	return loadedScripts;
}


+ (BOOL) writeDiagnosticData:(NSData *)data toFileNamed:(NSString *)name
{
	if (data == nil || name == nil)  return NO;
	
	NSString *directory = oo::NSStringOrNil([self cxx_diagnosticFileLocation]);
	if (directory == nil)  return NO;
	
	NSArray *nameComponents = [name componentsSeparatedByString:@"/"];
	NSUInteger count = [nameComponents count];
	if (count > 1)
	{
		name = [nameComponents lastObject];
		
		for (NSUInteger i = 0; i < count - 1; i++)
		{
			NSString *component = [nameComponents objectAtIndex:i];
			if ([component hasPrefix:@"."])
			{
				component = [@"!" stringByAppendingString:[component substringFromIndex:1]];
			}
			directory = [directory stringByAppendingPathComponent:component];
			[[NSFileManager defaultManager] oo_createDirectoryAtPath:directory attributes:nil];
		}
	}
	
	return [data writeToFile:[directory stringByAppendingPathComponent:name] atomically:YES];
}


+ (BOOL) writeDiagnosticString:(NSString *)string toFileNamed:(NSString *)name
{
	return [self writeDiagnosticData:[string dataUsingEncoding:NSUTF8StringEncoding] toFileNamed:name];
}


+ (BOOL) writeDiagnosticPList:(id)plist toFileNamed:(NSString *)name
{
	NSData *data = [plist oldSchoolPListFormatWithErrorDescription:NULL];
	if (data == nil)  [NSPropertyListSerialization dataFromPropertyList:plist format:NSPropertyListXMLFormat_v1_0 errorDescription:NULL];
	if (data == nil)  return NO;
	
	return [self writeDiagnosticData:data toFileNamed:name];
}


+ (NSDictionary *) materialDefaults
{
	return [self dictionaryFromFilesNamed:@"material-defaults.plist" inFolder:@"Config" andMerge:YES];
}


+ (BOOL)directoryExists:(NSString *)inPath create:(BOOL)inCreate
{
	BOOL				exists, directory;
	NSFileManager		*fmgr =  [NSFileManager defaultManager];
	
	exists = [fmgr fileExistsAtPath:inPath isDirectory:&directory];
	
	if (exists && !directory)
	{
		OOLog(@"resourceManager.write.buildPath.failed", @"Expected %@ to be a folder, but it is a file.", inPath);
		return NO;
	}
	if (!exists)
	{
		if (!inCreate) return NO;
		if (![fmgr oo_createDirectoryAtPath:inPath attributes:nil])
		{
			OOLog(@"resourceManager.write.buildPath.failed", @"Could not create folder %@.", inPath);
			return NO;
		}
	}
	
	return YES;
}


+ (std::optional<std::string>) cxx_diagnosticFileLocation
{
	return oo::OptionalString(OOLogHandlerGetLogBasePath());	// an unmigrated callee (OOLogOutputHandler)
}


+ (void) logPaths
{
	// Prettify paths for logging (-stringByStandardizingPath and -stringByAbbreviatingWithTildeInPath
	// have no oo::str form yet: they run on the bridged string).
	std::string displayPaths;
	if (sSearchPaths.has_value())
	{
		bool first = true;
		for (const std::string &path : *sSearchPaths)
		{
			if (!first)  displayPaths += "\n    ";
			first = false;
			displayPaths += oo::StdString([[oo::NSStringFrom(path) stringByStandardizingPath] stringByAbbreviatingWithTildeInPath]);
		}
	}

	OOLog(@"searchPaths.dumpAll", @"Resource paths: %@\n    %@", oo::NSStringOrNil(sUseAddOns), oo::NSStringFrom(displayPaths));

}


+ (void) clearCaches
{
	[sSoundCache release];
	sSoundCache = nil;
	[sStringCache release];
	sStringCache = nil;
}

@end
