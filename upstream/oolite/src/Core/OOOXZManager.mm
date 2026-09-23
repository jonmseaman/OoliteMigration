/*

OOOXZManager.m

Responsible for installing and uninstalling OXZs

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

#import "OOOXZManager.h"
#import <objc/runtime.h>
#import <objc/objc-arc.h>
#import "OOPListParsing.h"
#import "OOStringParsing.h"
#import "ResourceManager.h"
#import "OOCacheManager.h"
#import "Universe.h"
#import "GuiDisplayGen.h"
#import "PlayerEntity.h"
#import "PlayerEntitySound.h"
#import "OOPListView.h"
#import "NSFileManagerOOExtensions.h"
#import "NSDataOOExtensions.h"
#import "OOStringBridge.h"
#import "OOFoundationBridge.h"
#import "OOColor.h"
#import "OOStringExpander.h"
#import "MyOpenGLView.h"
#import "GameController.h"

#import "unzip.h"
#include "oofnd/FileSystem.hpp"
#include "oofnd/ResourcePaths.hpp"
#include "oofnd/String.hpp"

#import "OOManifestProperties.h"

/* The URL for the manifest.plist array. */
/* switching (temporarily maybe) to oolite.space - Nikos 20230507 */
namespace {
/*const char *const kOOOXZDataURL = "http://addons.oolite.org/api/1.0/overview";*/
const char *const kOOOXZDataURL = "https://addons.oolite.space/api/1.0/overview";
/* The config parameter to use a non-default URL at runtime */
const char *const kOOOXZDataConfig = "oxz-index-url";
/* The filename to store the downloaded manifest.plist array */
const char *const kOOOXZManifestCache = "Oolite-manifests.plist";
/* The filename to temporarily store the downloaded OXZ. Has an OXZ extension since we might want to read its manifest.plist out of it;  */
const char *const kOOOXZTmpPath = "Oolite-download.oxz";
/* The filename to temporarily store the downloaded plists. */
const char *const kOOOXZTmpPlistPath = "Oolite-download.plist";
} // namespace

/* Log file record types */
static NSString * const kOOOXZErrorLog = @"oxz.manager.error";
static NSString * const kOOOXZDebugLog = @"oxz.manager.debug";


/* Filter components */
namespace {
constexpr std::string_view kOOOXZFilterAll = "*";
constexpr std::string_view kOOOXZFilterUpdates = "u";
constexpr std::string_view kOOOXZFilterInstallable = "i";
constexpr std::string_view kOOOXZFilterKeyword = "k:";
constexpr std::string_view kOOOXZFilterAuthor = "a:";
constexpr std::string_view kOOOXZFilterCategory = "c:";
constexpr std::string_view kOOOXZFilterDays = "d:";
constexpr std::string_view kOOOXZFilterTag = "t:";
} // namespace


typedef enum {
	OXZ_INSTALLABLE_OKAY,
	OXZ_INSTALLABLE_UPDATE,
	OXZ_INSTALLABLE_DEPENDENCIES,
	OXZ_INSTALLABLE_CONFLICTS,
	// for things to work, _ALREADY must be the first UNINSTALLABLE state
	// and all the INSTALLABLE ones must be before all the UNINSTALLABLE ones
	OXZ_UNINSTALLABLE_ALREADY,
	OXZ_UNINSTALLABLE_NOREMOTE,
	OXZ_UNINSTALLABLE_VERSION,
	OXZ_UNINSTALLABLE_MANUAL
} OXZInstallableState;


enum {
	OXZ_GUI_ROW_LISTHEAD	= 0,
	OXZ_GUI_ROW_FIRSTRUN	= 1,
	OXZ_GUI_ROW_PROGRESS	= 1,
	OXZ_GUI_ROW_FILTERHELP	= 1,
	OXZ_GUI_ROW_LISTPREV	= 1,
	OXZ_GUI_ROW_LISTSTART	= 2,
	OXZ_GUI_NUM_LISTROWS	= 10,
	OXZ_GUI_ROW_LISTNEXT	= 12,
	OXZ_GUI_ROW_LISTSTATUS	= 14,
	OXZ_GUI_ROW_LISTDESC	= 16,
	OXZ_GUI_ROW_LISTINFO1	= 19,
	OXZ_GUI_ROW_LISTINFO2	= 20,
	OXZ_GUI_ROW_LISTFILTER	= 21,
	OXZ_GUI_ROW_INSTALL		= 22,
	OXZ_GUI_ROW_INSTALLED	= 23,
	OXZ_GUI_ROW_UPDATE_ALL	= 24,
	OXZ_GUI_ROW_REMOVE		= 25,
	OXZ_GUI_ROW_PROCEED		= 25,
	OXZ_GUI_ROW_UPDATE		= 26,
	OXZ_GUI_ROW_CANCEL		= 26,
	OXZ_GUI_ROW_FILTERCURRENT = 26,
	OXZ_GUI_ROW_INPUT		= 27,
	OXZ_GUI_ROW_EXIT		= 27
};

namespace {

// -[NSDictionary oo_stringForKey:] (a string, or a number's -stringValue); nullopt (nil) otherwise.
std::optional<std::string> ManifestString(const oo::PList &manifest, const std::string &key)
{
	const oo::PList *value = manifest.find(key);
	if (value == nullptr || !(value->isString() || value->isNumber()))  return std::nullopt;
	return manifest.get<std::string>(key);
}

// [haystack rangeOfString:needle options:NSCaseInsensitiveSearch].location != NSNotFound, each
// UTF-16 unit folded with oo::str::toLower as -caseInsensitiveCompare: folds. An empty needle is
// found (location 0, captured), and so is anything in a nil haystack: the nil message's range is
// zero-filled, location 0 (captured on GNUstep 1.31.1).
bool FoundIgnoringCase(const std::optional<std::string> &haystack, const std::string &needle)
{
	if (!haystack.has_value())  return true;
	std::u16string h = oo::utf8ToUtf16(*haystack), n = oo::utf8ToUtf16(needle);
	for (char16_t &u : h)  u = oo::str::toLower(u);
	for (char16_t &u : n)  u = oo::str::toLower(u);
	return h.find(n) != std::u16string::npos;
}

// The tags filter: any string tag containing the needle. (A non-string tag raised on
// -rangeOfString:options:; it is skipped.)
bool TagFoundIgnoringCase(const oo::PList &manifest, const std::string &needle)
{
	const oo::PList *tags = manifest.get<oo::PList::Array>(oo::StdString(kOOManifestTags));
	if (tags == nullptr)  return false;
	for (const oo::PList &tag : *tags->getIf<oo::PList::Array>())
	{
		if (const std::string *string = tag.getIf<std::string>())
		{
			if (FoundIgnoringCase(*string, needle))  return true;
		}
	}
	return false;
}


// The elements of an Array node (none for anything else, as messaging nil gave).
const oo::PList::Array &Elements(const oo::PList &list)
{
	static const oo::PList::Array empty;
	const oo::PList::Array *elements = list.getIf<oo::PList::Array>();
	return (elements != nullptr) ? *elements : empty;
}

// Element index of an Array node; null when out of range.
oo::PList ElementAt(const oo::PList &list, NSUInteger index)
{
	const oo::PList *element = list.at(index);
	return (element != nullptr) ? *element : oo::PList();
}

// -[NSString localizedCompare:]: GNUstep collates with ICU in the current locale (captured on
// GNUstep 1.31.1, en_US: "_x" < "1.10" < "a" < "A" < "Alpha" < "b", "e" < "E" < "\u00e9"). oofnd has
// no collation yet, so GNUstep still does this one comparison, on the two strings.
int LocalizedCompare(const std::string &a, const std::string &b)
{
	return (int)[oo::NSStringFrom(a) localizedCompare:oo::NSStringFrom(b)];
}

/* Sort by category, then title, then version - and that should be unique (was the C function
   oxzSort, an NSComparisonResult sort function). The version orders descending. */
bool OXZOrderedBefore(const oo::PList &m1, const oo::PList &m2)
{
	int result = LocalizedCompare(ManifestString(m1, oo::StdString(kOOManifestCategory)).value_or("zz"), ManifestString(m2, oo::StdString(kOOManifestCategory)).value_or("zz"));
	if (result == 0)
	{
		result = LocalizedCompare(ManifestString(m1, oo::StdString(kOOManifestTitle)).value_or("zz"), ManifestString(m2, oo::StdString(kOOManifestTitle)).value_or("zz"));
		if (result == 0)
		{
			result = LocalizedCompare(ManifestString(m2, oo::StdString(kOOManifestVersion)).value_or("0"), ManifestString(m1, oo::StdString(kOOManifestVersion)).value_or("0"));
		}
	}
	return result < 0;
}
} // namespace

static OOOXZManager *sSingleton = nil;

// protocol was only formalised in 10.7
#if OOLITE_MAC_OS_X_10_7 

@interface OOOXZManager (OOPrivate) <NSURLConnectionDataDelegate> 
#else
@interface OOOXZManager (NSURLConnectionDataDelegate) 
#endif

- (std::optional<std::string>) manifestPath;	// nullopt: no cache directory
- (std::optional<std::string>) downloadPath;	// nullopt: no cache directory
- (std::optional<std::string>) extractionBasePathForIdentifier:(const std::string &)identifier andVersion:(const std::string &)version;	// nullopt: no user root
- (std::optional<std::string>) dataURL;
- (std::optional<std::string>) humanSize:(NSUInteger)bytes;	// nullopt: the missing-field description is missing

- (BOOL) ensureInstallPath;

- (BOOL) beginDownload:(NSMutableURLRequest *)request;
- (BOOL) processDownloadedManifests;
- (BOOL) processDownloadedOXZ;

- (OXZInstallableState) installableState:(const oo::PList &)manifest;
- (OOColor *) colorForManifest:(const oo::PList &)manifest;
- (std::optional<std::string>) installStatusForManifest:(const oo::PList &)manifest;	// nullopt: its description is missing

- (BOOL) validateFilter:(const std::string &)input;

- (void) setOXZList:(const oo::PList &)list;	// an Array (sorted here), or null
- (void) setFilteredList:(const oo::PList &)list;
- (oo::PList) applyCurrentFilter:(const oo::PList &)list;	// an Array

- (void) setCurrentDownload:(NSURLConnection *)download withLabel:(NSString *)label;
- (void) setProgressStatus:(NSString *)newStatus;

- (BOOL) installOXZ:(NSUInteger)item;
- (BOOL) updateAllOXZ;
- (BOOL) removeOXZ:(NSUInteger)item;
- (NSArray *) installOptions;
- (NSArray *) removeOptions;

- (NSString *) extractOXZ:(NSUInteger)item;

/* Delegates for URL downloader */
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;

@end

@interface OOOXZManager (OOFilterRules)
- (BOOL) applyFilterByNoFilter:(const oo::PList &)manifest;
- (BOOL) applyFilterByUpdateRequired:(const oo::PList &)manifest;
- (BOOL) applyFilterByInstallable:(const oo::PList &)manifest;
- (BOOL) applyFilterByKeyword:(const oo::PList &)manifest keyword:(const std::string &)keyword;
- (BOOL) applyFilterByAuthor:(const oo::PList &)manifest author:(const std::string &)author;
- (BOOL) applyFilterByDays:(const oo::PList &)manifest days:(const std::string &)days;
- (BOOL) applyFilterByTag:(const oo::PList &)manifest tag:(const std::string &)tag;
- (BOOL) applyFilterByCategory:(const oo::PList &)manifest category:(const std::string &)category;

@end 



@implementation OOOXZManager

+ (OOOXZManager *)sharedManager
{
	// NOTE: assumes single-threaded first access.
	if (sSingleton == nil)  sSingleton = [[self alloc] init];
	return sSingleton;
}


- (id) init
{
	self = [super init];
	if (self != nil)
	{
		_downloadStatus = OXZ_DOWNLOAD_NONE;
		// if the file has not been downloaded, this will be nil
		[self setOXZList:oo::PListFrom(OOArrayFromFile(oo::NSStringOrNil([self manifestPath])))];
		OOLog(kOOOXZDebugLog,@"Initialised with %@",oo::ObjectFromPList(_oxzList));
		_interfaceState = OXZ_STATE_NODATA;
		_currentFilter = "*";
		
		_interfaceShowingOXZDetail = NO;
		_changesMade = NO;
		_downloadAllDependencies = NO;
		_dependencyStack = [[NSMutableSet alloc] initWithCapacity:8];
		[self setProgressStatus:@""];
	}
	return self;
}


- (void)dealloc
{
	if (sSingleton == self)  sSingleton = nil;

	[self setCurrentDownload:nil withLabel:nil];

	[super dealloc];
}


/* The install path for OXZs downloaded by
 * Oolite. Library/ApplicationSupport seems to be the most appropriate
 * location. */
- (std::optional<std::string>) installPath
{
	// OO_MANAGEDADDONSDIR, else <ApplicationSupport>/Oolite/ManagedAddOns (GNUstep uses
	// "ApplicationSupport" rather than "Application Support", so no space in "ManagedAddOns"
	// either): oo::ResourcePaths reproduces the NSSearchPathForDirectoriesInDomains result.
	return oo::fs::utf8String(oo::ResourcePaths::current().managedAddOnsDirectory());
}

/* The extract path for OXZs . */
- (std::optional<std::string>) extractAddOnsPath
{
	// OO_ADDONSEXTRACTDIR, else "../AddOns" on Windows (%LOCALAPPDATA%\Oolite\AddOns with
	// OO_GAME_DATA_TO_USER_FOLDER), else ~/.Oolite/AddOns.
	return oo::fs::utf8String(oo::ResourcePaths::current().extractAddOnsDirectory());
}

/* Add additional AddOns paths */
- (std::vector<std::string>) additionalAddOnsPaths
{
	// OO_ADDITIONALADDONSDIRS split on ',' (empty components kept, as before).
	std::vector<std::string> result;
	for (const oo::fs::Path &path : oo::ResourcePaths::current().additionalAddOnsDirectories())  result.push_back(oo::fs::utf8String(path));
	return result;
}


- (std::optional<std::string>) extractionBasePathForIdentifier:(const std::string &)identifier andVersion:(const std::string &)version
{
	const std::vector<std::string> userRootPaths = [ResourceManager cxx_userRootPaths];
	if (userRootPaths.empty())  return std::nullopt;
	const std::string &basePath = userRootPaths.back();
	std::string mainDir = identifier + "-" + version + ".off";

	// The blacklisted characters (all ASCII) are removed.
	std::erase_if(mainDir, [](char c) { return std::string_view("'#%^&{}[]/~|\\?<,:\" ").find(c) != std::string_view::npos; });
	return oo::str::appendingPathComponent(basePath, mainDir);
}


- (BOOL) ensureInstallPath
{
	const std::optional<std::string> path = [self installPath];
	const oo::fs::Path fsPath = oo::fs::pathFromUTF8(path.value_or(std::string()));
	const bool exists = path.has_value() && oo::fs::fileExists(fsPath);

	if (exists && !oo::fs::isDirectory(fsPath))
	{
		OOLog(kOOOXZErrorLog, @"Expected %@ to be a folder, but it is a file.", oo::NSStringOrNil(path));
		return NO;
	}
	if (!exists)
	{
		if (!path.has_value() || !oo::fs::createDirectories(fsPath))
		{
			OOLog(kOOOXZErrorLog, @"Could not create folder %@.", oo::NSStringOrNil(path));
			return NO;
		}
	}

	return YES;
}


- (std::optional<std::string>) manifestPath
{
	const std::optional<std::string> cacheDirectory = [[OOCacheManager sharedCache] cxx_cacheDirectoryPathCreatingIfNecessary:YES];
	if (!cacheDirectory.has_value())  return std::nullopt;
	return oo::str::appendingPathComponent(*cacheDirectory, kOOOXZManifestCache);
}


/* Download mechanism could destroy a correct file if it failed
 * half-way and was downloaded on top of the old one. So this loads it
 * off to the side a bit */
- (std::optional<std::string>) downloadPath
{
	const std::optional<std::string> cacheDirectory = [[OOCacheManager sharedCache] cxx_cacheDirectoryPathCreatingIfNecessary:YES];
	if (!cacheDirectory.has_value())  return std::nullopt;
	if (_interfaceState == OXZ_STATE_UPDATING)
	{
		return oo::str::appendingPathComponent(*cacheDirectory, kOOOXZTmpPlistPath);
	}
	else
	{
		return oo::str::appendingPathComponent(*cacheDirectory, kOOOXZTmpPath);
	}
}


- (std::optional<std::string>) dataURL
{
	/* Not expected to be set in general, but might be useful for some users */
	const std::optional<std::string> url = oo::OptionalString([[NSUserDefaults standardUserDefaults] stringForKey:oo::NSStringFrom(kOOOXZDataConfig)]);
	if (url.has_value())
	{
		return url;
	}
	return kOOOXZDataURL;
}


- (std::optional<std::string>) humanSize:(NSUInteger)bytes
{
	if (bytes == 0)
	{
		return oo::OptionalString(DESC(@"oolite-oxzmanager-missing-field"));
	}
	else if (bytes < 1024)
	{
		return "<1 kB";
	}
	else if (bytes < 1024*1024)
	{
		return oo::str::format("%zu kB", (size_t)(bytes>>10));
	}
	else
	{
		return oo::str::format("%.2f MB", ((float)(bytes>>10))/1024);
	}
}


- (void) setOXZList:(const oo::PList &)list
{
	_oxzList = oo::PList();
	if (list)
	{
		// category, then title, then version descending (OXZOrderedBefore); ties keep list order
		oo::PList::Array sorted = Elements(list);
		std::stable_sort(sorted.begin(), sorted.end(), OXZOrderedBefore);
		_oxzList = oo::PList(std::move(sorted));
		// needed for update to available versions
		_managedList = oo::PList();
	}
}


- (void) setFilteredList:(const oo::PList &)list
{
	_filteredList = list;
}


- (void) setFilter:(const std::string &)filter
{
	_currentFilter = oo::str::lowercase(filter);
}


- (oo::PList) applyCurrentFilter:(const oo::PList &)list
{
	SEL filterSelector = @selector(applyFilterByNoFilter:);
	std::string parameter;
	if (_currentFilter == kOOOXZFilterUpdates)
	{
		filterSelector = @selector(applyFilterByUpdateRequired:);
	}
	else if (_currentFilter == kOOOXZFilterInstallable)
	{
		filterSelector = @selector(applyFilterByInstallable:);
	}
	else if (oo::str::hasPrefix(_currentFilter, kOOOXZFilterKeyword))
	{
		filterSelector = @selector(applyFilterByKeyword:keyword:);
		parameter = _currentFilter.substr(kOOOXZFilterKeyword.size());
	}
	else if (oo::str::hasPrefix(_currentFilter, kOOOXZFilterAuthor))
	{
		filterSelector = @selector(applyFilterByAuthor:author:);
		parameter = _currentFilter.substr(kOOOXZFilterAuthor.size());
	}
	else if (oo::str::hasPrefix(_currentFilter, kOOOXZFilterDays))
	{
		filterSelector = @selector(applyFilterByDays:days:);
		parameter = _currentFilter.substr(kOOOXZFilterDays.size());
	}
	else if (oo::str::hasPrefix(_currentFilter, kOOOXZFilterTag))
	{
		filterSelector = @selector(applyFilterByTag:tag:);
		parameter = _currentFilter.substr(kOOOXZFilterTag.size());
	}
 	else if (oo::str::hasPrefix(_currentFilter, kOOOXZFilterCategory))
	{
		filterSelector = @selector(applyFilterByCategory:category:);
		parameter = _currentFilter.substr(kOOOXZFilterCategory.size());
	}

	oo::PList::Array filteredList;
	/*	A typed call through the filter's IMP (bead oo-3rb.53; was a Foundation invocation object). The
		one-argument filters take the manifest; the rest take the manifest and the
		parameter (the prefixes are ASCII, so the byte offset is the old character offset).
	*/
	typedef BOOL (*OneArgumentFilter)(id, SEL, const oo::PList &);
	typedef BOOL (*TwoArgumentFilter)(id, SEL, const oo::PList &, const std::string &);
	IMP filterIMP = [self methodForSelector:filterSelector];
	BOOL twoArguments = !(sel_isEqual(filterSelector, @selector(applyFilterByNoFilter:)) ||
						  sel_isEqual(filterSelector, @selector(applyFilterByUpdateRequired:)) ||
						  sel_isEqual(filterSelector, @selector(applyFilterByInstallable:)));

	for (const oo::PList &manifest : Elements(list))
	{
		BOOL filterAccepted = NO;
		if (twoArguments)
		{
			filterAccepted = ((TwoArgumentFilter)filterIMP)(self, filterSelector, manifest, parameter);
		}
		else
		{
			filterAccepted = ((OneArgumentFilter)filterIMP)(self, filterSelector, manifest);
		}
		if (filterAccepted)
		{
			filteredList.push_back(manifest);
		}
	}
	// any bad filter that gets this far is also treated as '*'
	// so don't need to explicitly test for '*' or ''
	return oo::PList(std::move(filteredList));
}


/*** Start filters ***/
- (BOOL) applyFilterByNoFilter:(const oo::PList &)manifest
{
	return YES;
}


- (BOOL) applyFilterByUpdateRequired:(const oo::PList &)manifest
{
	return ([self installableState:manifest] == OXZ_INSTALLABLE_UPDATE);
}


- (BOOL) applyFilterByInstallable:(const oo::PList &)manifest
{
	return ([self installableState:manifest] < OXZ_UNINSTALLABLE_ALREADY);
}


- (BOOL) applyFilterByKeyword:(const oo::PList &)manifest keyword:(const std::string &)keyword
{
  	// trim any eventual leading whitespace from input string
	const std::string trimmed = oo::str::trimLeadingWhitespaceAndNewlines(keyword);
	const std::string parameters[] = { oo::StdString(kOOManifestTitle), oo::StdString(kOOManifestDescription), oo::StdString(kOOManifestCategory) };

	for (const std::string &parameter : parameters)
	{
		if (FoundIgnoringCase(ManifestString(manifest, parameter), trimmed))
		{
			return YES;
		}
	}
	// tags are slightly different
	return TagFoundIgnoringCase(manifest, trimmed);
}


- (BOOL) applyFilterByAuthor:(const oo::PList &)manifest author:(const std::string &)author
{
	// trim any eventual leading whitespace from input string
	const std::string trimmed = oo::str::trimLeadingWhitespaceAndNewlines(author);

	return FoundIgnoringCase(ManifestString(manifest, oo::StdString(kOOManifestAuthor)), trimmed);
}


- (BOOL) applyFilterByDays:(const oo::PList &)manifest days:(const std::string &)days
{
	NSInteger i = (NSInteger)oo::str::longLongValue(days);	// -integerValue
	if (i < 1)
	{
		return NO;
	}
	else
	{
		NSUInteger updated = manifest.get<unsigned long long>(oo::StdString(kOOManifestUploadDate));
		NSUInteger now = (NSUInteger)[[NSDate date] timeIntervalSince1970];
		return (updated + (86400 * i) > now);
	}
}


- (BOOL) applyFilterByTag:(const oo::PList &)manifest tag:(const std::string &)tag
{
  	// trim any eventual leading whitespace from input string
	return TagFoundIgnoringCase(manifest, oo::str::trimLeadingWhitespaceAndNewlines(tag));
}


- (BOOL) applyFilterByCategory:(const oo::PList &)manifest category:(const std::string &)category
{
	// trim any eventual leading whitespace from input string
	const std::string trimmed = oo::str::trimLeadingWhitespaceAndNewlines(category);

	return FoundIgnoringCase(ManifestString(manifest, oo::StdString(kOOManifestCategory)), trimmed);
}


/*** End filters ***/

- (BOOL) validateFilter:(const std::string &)input
{
	const std::string filter = oo::str::lowercase(input);
	// The prefixes are ASCII: a byte count past one is a character past it.
	if ((filter.empty()) // empty is valid
		|| (filter == kOOOXZFilterAll)
		|| (filter == kOOOXZFilterUpdates)
		|| (filter == kOOOXZFilterInstallable)
		|| (oo::str::hasPrefix(filter, kOOOXZFilterKeyword) && filter.size() > kOOOXZFilterKeyword.size())
		|| (oo::str::hasPrefix(filter, kOOOXZFilterAuthor) && filter.size() > kOOOXZFilterAuthor.size())
		|| (oo::str::hasPrefix(filter, kOOOXZFilterDays) && oo::str::intValue(filter.substr(kOOOXZFilterDays.size())) > 0)
		|| (oo::str::hasPrefix(filter, kOOOXZFilterTag) && filter.size() > kOOOXZFilterTag.size())
  		|| (oo::str::hasPrefix(filter, kOOOXZFilterCategory) && filter.size() > kOOOXZFilterCategory.size())
		)
	{
		return YES;
	}

	return NO;
}


- (void) setCurrentDownload:(NSURLConnection *)download withLabel:(NSString *)label
{
	if (_currentDownload != nil)
	{
		[_currentDownload cancel]; // releases via delegate
	}
	_currentDownload = [download retain];
	DESTROY(_currentDownloadName);
	_currentDownloadName = [label copy];
}


- (void) setProgressStatus:(NSString *)newValue
{
	DESTROY(_progressStatus);
	_progressStatus = [newValue copy];
}

- (BOOL) updateManifests
{
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:oo::NSStringOrNil([self dataURL])]];
	if (_downloadStatus != OXZ_DOWNLOAD_NONE)
	{
		return NO;
	}
	_downloadStatus = OXZ_DOWNLOAD_STARTED;
	_interfaceState = OXZ_STATE_UPDATING;
	[self setProgressStatus:@""];

	return [self beginDownload:request];
}


- (BOOL) beginDownload:(NSMutableURLRequest *)request
{
	NSString *userAgent = [NSString stringWithFormat:@"Oolite/%@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
	[request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
	[request setHTTPShouldHandleCookies:NO];
	NSURLConnection *download = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (download)
	{
		_downloadProgress = 0;
		_downloadExpected = 0;
		NSString *label = DESC(@"oolite-oxzmanager-download-label-list");
		if (_interfaceState != OXZ_STATE_UPDATING)
		{
			NSDictionary *expectedManifest = nil;
			expectedManifest = oo::ObjectFromPList(ElementAt(_filteredList, _item));

			label = oo::PListView(expectedManifest).get<NSString *>(kOOManifestTitle, DESC(@"oolite-oxzmanager-download-label-oxz"));
		}

		[self setCurrentDownload:download withLabel:label]; // retains it
		[download release];
		OOLog(kOOOXZDebugLog,@"Download request received, using %@ and downloading to %@",[request URL],oo::NSStringOrNil([self downloadPath]));
		return YES;
	}
	else
	{
		OOLog(kOOOXZErrorLog,@"Unable to start downloading file at %@",[request URL]);
		_downloadStatus = OXZ_DOWNLOAD_ERROR;
		return NO;
	}
}


- (BOOL) cancelUpdate
{
	if (!(_interfaceState == OXZ_STATE_UPDATING || _interfaceState == OXZ_STATE_INSTALLING) || _downloadStatus == OXZ_DOWNLOAD_NONE)
	{
		return NO;
	}
	OOLog(kOOOXZDebugLog, @"%@", @"Trying to cancel file download");
	if (_currentDownload != nil)
	{
		[_currentDownload cancel];
	}
	else if (_downloadStatus == OXZ_DOWNLOAD_COMPLETE)
	{
		NSString *path = oo::NSStringOrNil([self downloadPath]);
		[[NSFileManager defaultManager] oo_removeItemAtPath:path];
	}
	_downloadStatus = OXZ_DOWNLOAD_NONE;
	if (_interfaceState == OXZ_STATE_INSTALLING)
	{
		_interfaceState = OXZ_STATE_PICK_INSTALL;
	}
	else
	{
		_interfaceState = OXZ_STATE_MAIN;
	}
	[self gui];
	return YES;
}


- (oo::PList) manifests
{
	return _oxzList;
}


- (oo::PList) managedOXZs
{
	if (!_managedList)
	{
		// if this list is being reset, also reset the current install list
		[ResourceManager resetManifestKnowledgeForOXZManager];
		const std::optional<std::string> installPath = [self installPath];
		std::vector<std::string> filenames;
		if (installPath.has_value())
		{
			auto contents = oo::fs::directoryContents(oo::fs::pathFromUTF8(*installPath));
			if (contents)  filenames = std::move(*contents);
		}
		oo::PList::Array manifests;
		for (const std::string &filename : filenames)
		{
			const std::string fullpath = oo::str::appendingPathComponent(*installPath, filename);
			// OODictionaryFromFile is unmigrated: its dictionary arrives through oo::PListFrom.
			const oo::PList manifest = oo::PListFrom(OODictionaryFromFile(oo::NSStringFrom(oo::str::appendingPathComponent(fullpath, "manifest.plist"))));
			if (manifest)
			{
				oo::PList adjManifest = manifest;
				oo::PList::Dict &adjEntries = *adjManifest.getIf<oo::PList::Dict>();
				adjEntries[oo::StdString(kOOManifestFilePath)] = oo::PList(fullpath);

				const std::optional<std::string> identifier = ManifestString(manifest, oo::StdString(kOOManifestIdentifier));
				/* The list is already sorted to put the latest
				 * versions first. This flag means that it stops
				 * checking the list for versions once it finds one
				 * that is plausibly installable */
				BOOL foundInstallable = NO;
				for (const oo::PList &stored : Elements(_oxzList))
				{
					const std::optional<std::string> storedIdentifier = ManifestString(stored, oo::StdString(kOOManifestIdentifier));
					if (storedIdentifier.has_value() && identifier.has_value() && *storedIdentifier == *identifier)
					{
						if (foundInstallable == NO)
						{
							// (A missing value raised on -setObject:forKey:; it is now not set.)
							if (const std::optional<std::string> version = ManifestString(stored, oo::StdString(kOOManifestVersion)))
							{
								adjEntries[oo::StdString(kOOManifestAvailableVersion)] = oo::PList(*version);
							}
							if (const std::optional<std::string> url = ManifestString(stored, oo::StdString(kOOManifestDownloadURL)))
							{
								adjEntries[oo::StdString(kOOManifestDownloadURL)] = oo::PList(*url);
							}
							if ([ResourceManager cxx_checkVersionCompatibility:manifest forOXP:std::nullopt])
							{
								foundInstallable = YES;
							}
						}
					}
				}

				manifests.push_back(std::move(adjManifest));
			}
		}
		std::stable_sort(manifests.begin(), manifests.end(), OXZOrderedBefore);

		_managedList = oo::PList(std::move(manifests));
	}
	return _managedList;
}


- (BOOL) processDownloadedManifests
{
	if (_downloadStatus != OXZ_DOWNLOAD_COMPLETE)
	{
		return NO;
	}
	[self setOXZList:oo::PListFrom(OOArrayFromFile(oo::NSStringOrNil([self downloadPath])))];
	if (_oxzList)
	{
		// GNUstep's property-list writer still writes the cache file.
		[oo::ObjectFromPList(_oxzList) writeToFile:oo::NSStringOrNil([self manifestPath]) atomically:YES];
		// and clean up the temp file
		[[NSFileManager defaultManager] oo_removeItemAtPath:oo::NSStringOrNil([self downloadPath])];
		// invalidate the managed list
		_managedList = oo::PList();
		_interfaceState = OXZ_STATE_TASKDONE;
		[self gui];
		return YES;
	}
	else
	{
		_downloadStatus = OXZ_DOWNLOAD_ERROR;
		OOLog(kOOOXZErrorLog,@"Downloaded manifest was not a valid plist, has been left in %@",oo::NSStringOrNil([self downloadPath]));
		// revert to the old one
		[self setOXZList:oo::PListFrom(OOArrayFromFile(oo::NSStringOrNil([self manifestPath])))];
		_interfaceState = OXZ_STATE_TASKDONE;
		[self gui];
		return NO;
	}
}


- (BOOL) processDownloadedOXZ
{
	if (_downloadStatus != OXZ_DOWNLOAD_COMPLETE)
	{
		return NO;
	}

	NSDictionary *downloadedManifest = OODictionaryFromFile([oo::NSStringOrNil([self downloadPath]) stringByAppendingPathComponent:@"manifest.plist"]);
	if (downloadedManifest == nil)
	{
		_downloadStatus = OXZ_DOWNLOAD_ERROR;
		OOLog(kOOOXZErrorLog,@"Downloaded OXZ does not contain a manifest.plist, has been left in %@",oo::NSStringOrNil([self downloadPath]));
		_interfaceState = OXZ_STATE_TASKDONE;
		[self gui];
		return NO;
	}
	NSDictionary *expectedManifest = nil;
	expectedManifest = oo::ObjectFromPList(ElementAt(_filteredList, _item));

	if (expectedManifest == nil || 
		(![oo::PListView(downloadedManifest).get<NSString *>(kOOManifestIdentifier) isEqualToString:oo::PListView(expectedManifest).get<NSString *>(kOOManifestIdentifier)]) || 
		(![oo::PListView(downloadedManifest).get<NSString *>(kOOManifestVersion) isEqualToString:oo::PListView(expectedManifest).get<NSString *>(kOOManifestAvailableVersion, oo::PListView(expectedManifest).get<NSString *>(kOOManifestVersion))])
		)
	{
		_downloadStatus = OXZ_DOWNLOAD_ERROR;
		OOLog(kOOOXZErrorLog, @"%@", @"Downloaded OXZ does not have the same identifer and version as expected. This might be due to your manifests list being out of date - try updating it.");
		_interfaceState = OXZ_STATE_TASKDONE;
		[self gui];
		return NO;
	}
	// this appears to be the OXZ we expected
	// filename is going to be identifier.oxz
	NSString *filename = [oo::PListView(downloadedManifest).get<NSString *>(kOOManifestIdentifier) stringByAppendingString:@".oxz"];

	if (![self ensureInstallPath])
	{
		_downloadStatus = OXZ_DOWNLOAD_ERROR;
		OOLog(kOOOXZErrorLog, @"%@", @"Unable to create installation folder.");
		_interfaceState = OXZ_STATE_TASKDONE;
		[self gui];
		return NO;
	}

	// delete filename if it exists from OXZ folder
	NSString *destination = [oo::NSStringOrNil([self installPath]) stringByAppendingPathComponent:filename];
	[[NSFileManager defaultManager] oo_removeItemAtPath:destination];

	// move the temp file on to it
	if (![[NSFileManager defaultManager] oo_moveItemAtPath:oo::NSStringOrNil([self downloadPath]) toPath:destination])
	{
		_downloadStatus = OXZ_DOWNLOAD_ERROR;
		OOLog(kOOOXZErrorLog, @"%@", @"Downloaded OXZ could not be installed.");
		_interfaceState = OXZ_STATE_TASKDONE;
		[self gui];
		return NO;
	}
	_changesMade = YES;
	_managedList = oo::PList(); // will need updating
	// do this now to cope with circular dependencies on download
	[ResourceManager resetManifestKnowledgeForOXZManager];

	/** 
	 * If downloadedManifest is in _dependencyStack, remove it
	 * Get downloadedManifest requires_oxp list
	 * Add entries ones to _dependencyStack
	 * If _dependencyStack has contents, update _progressStatus
	 * ...and start the download of the 'first' item in _dependencyStack
	 * ...which isn't already installed (_dependencyStack is unordered
	 * ...so 'first' isn't really defined)
	 *
	 * ...if the item in _dependencyStack is not findable (e.g. wrong
	 * ...version) then stop here.
	 */
	NSArray *requiredOXPs = oo::PListView(downloadedManifest).get<NSArray *>(kOOManifestRequiresOXPs, nil);
	if (requiredOXPs == nil)
	{
		// just in case the requirements are only specified in the online copy
		requiredOXPs = oo::PListView(expectedManifest).get<NSArray *>(kOOManifestRequiresOXPs, nil);
	}
	NSDictionary *requirement = nil;
	NSMutableString *progress = [NSMutableString stringWithCapacity:2048];
	OOLog(kOOOXZDebugLog,@"Dependency stack has %zu elements",[_dependencyStack count]);

	if ([_dependencyStack count] > 0)
	{
		// will remove as iterate, so create a temp copy to iterate over
		NSSet *tempStack = [NSSet setWithSet:_dependencyStack];
		foreach (requirement, tempStack)
		{
			OOLog(kOOOXZDebugLog,@"Dependency stack: checking %@",oo::PListView(requirement).get<NSString *>(kOOManifestRelationIdentifier));
			if (![ResourceManager manifest:downloadedManifest HasUnmetDependency:requirement logErrors:NO]
				&& requiredOXPs != nil && [requiredOXPs containsObject:requirement])
			{
				// it was unmet, but now it's met					
				[progress appendFormat:DESC(@"oolite-oxzmanager-progress-now-has-@"),oo::PListView(requirement).get<NSString *>(kOOManifestRelationDescription, oo::PListView(requirement).get<NSString *>(kOOManifestRelationIdentifier))];
				[_dependencyStack removeObject:requirement];
				OOLog(kOOOXZDebugLog, @"%@", @"Dependency stack: requirement met");
			} else if ([oo::PListView(requirement).get<NSString *>(kOOManifestRelationIdentifier) isEqualToString:oo::PListView(downloadedManifest).get<NSString *>(kOOManifestIdentifier)]) {
				// remove the requirement for the just downloaded OXP
				[_dependencyStack removeObject:requirement];
			}
		}
	}
	if (requiredOXPs != nil)
	{
		foreach (requirement, requiredOXPs)
		{
			if ([ResourceManager manifest:downloadedManifest HasUnmetDependency:requirement logErrors:NO])
			{
				OOLog(kOOOXZDebugLog,@"Dependency stack: adding %@",oo::PListView(requirement).get<NSString *>(kOOManifestRelationIdentifier));
				[_dependencyStack addObject:requirement];
				[progress appendFormat:DESC(@"oolite-oxzmanager-progress-requires-@"),oo::PListView(requirement).get<NSString *>(kOOManifestRelationDescription, oo::PListView(requirement).get<NSString *>(kOOManifestRelationIdentifier))];
			}
		}
	}
	if ([_dependencyStack count] > 0)
	{
		// get an object from the requirements list, and download it
		// if it can be found
		BOOL undownloadedRequirement = NO;
		BOOL foundDownload = NO;
		NSUInteger index = 0;
		NSString *needsIdentifier = nil;

		do
		{
			undownloadedRequirement = YES;
			requirement = [_dependencyStack anyObject];
			OOLog(kOOOXZDebugLog,@"Dependency stack: next is %@",oo::PListView(requirement).get<NSString *>(kOOManifestRelationIdentifier));

			if (!_downloadAllDependencies)
			{
				[progress appendString:DESC(@"oolite-oxzmanager-progress-get-required")];
			}
			needsIdentifier = oo::PListView(requirement).get<NSString *>(kOOManifestRelationIdentifier);
		
			for (NSUInteger i = 0; i < _oxzList.count(); i++)
			{
				const oo::PList &availableDownload = *_oxzList.at(i);
				const std::optional<std::string> availableIdentifier = ManifestString(availableDownload, oo::StdString(kOOManifestIdentifier));
				if (availableIdentifier.has_value() && needsIdentifier != nil && *availableIdentifier == oo::StdString(needsIdentifier))
				{
					if ([ResourceManager matchVersions:requirement withVersion:oo::NSStringOrNil(ManifestString(availableDownload, oo::StdString(kOOManifestVersion)))])
					{
						OOLog(kOOOXZDebugLog, @"%@", @"Dependency stack: found download for next item");
						foundDownload = YES;
						index = i;	// the first equal manifest, as -indexOfObject: found
						break;
					}
				}
			}
			
			if (foundDownload)
			{
				if ([self installableState:ElementAt(_oxzList, index)] == OXZ_UNINSTALLABLE_ALREADY)
				{
					OOLog(kOOOXZDebugLog,@"Dependency stack: %@ is downloaded but not yet loadable, removing from list.",oo::PListView(requirement).get<NSString *>(kOOManifestRelationIdentifier));
					// then this has already been downloaded, but
					// can't be configured yet presumably because
					// another dependency is still to be loaded
					[_dependencyStack removeObject:requirement];
					if ([_dependencyStack count] > 0)
					{
						// try again
						undownloadedRequirement = NO;
					}
					else
					{
						// this case should probably never happen
						// is handled below just in case
						foundDownload = NO;
					}
				}
			}
		}
		while (!undownloadedRequirement);

		if (foundDownload)
		{
			// must clear filters entirely at this point
			[self setFilteredList:_oxzList];
			// then download that item
			_downloadStatus = OXZ_DOWNLOAD_NONE;
			if (_downloadAllDependencies)
			{
				OOLog(kOOOXZDebugLog,@"Dependency stack: installing %zu from list",index);
				if (![self installOXZ:index]) {
					// if a required dependency is somehow uninstallable
					// e.g. required+maximum version don't match this Oolite
					[progress appendFormat:DESC(@"oolite-oxzmanager-progress-required-@-not-found"),oo::PListView(requirement).get<NSString *>(kOOManifestRelationDescription, oo::PListView(requirement).get<NSString *>(kOOManifestRelationIdentifier))];
					[self setProgressStatus:progress];
					OOLog(kOOOXZErrorLog,@"OXZ dependency %@ could not be found for automatic download.",needsIdentifier);
					_downloadStatus = OXZ_DOWNLOAD_ERROR;
					OOLog(kOOOXZErrorLog, @"%@", @"Downloaded OXZ could not be installed.");
					_interfaceState = OXZ_STATE_TASKDONE;
					[self gui];
					return NO;
				}
			}
			else
			{
				_interfaceState = OXZ_STATE_DEPENDENCIES;
				_item = index;
			}
			[self setProgressStatus:progress];
			[self gui];
			return YES;
		}
		// this is probably always the case, see above
		else if ([_dependencyStack count] > 0)
		{
			[progress appendFormat:DESC(@"oolite-oxzmanager-progress-required-@-not-found"),oo::PListView(requirement).get<NSString *>(kOOManifestRelationDescription, oo::PListView(requirement).get<NSString *>(kOOManifestRelationIdentifier))];
			[self setProgressStatus:progress];
			OOLog(kOOOXZErrorLog,@"OXZ dependency %@ could not be found for automatic download.",needsIdentifier);
			_downloadStatus = OXZ_DOWNLOAD_ERROR;
			OOLog(kOOOXZErrorLog, @"%@", @"Downloaded OXZ could not be installed.");
			_interfaceState = OXZ_STATE_TASKDONE;
			[self gui];
			return NO;
		}
	}

	[self setProgressStatus:@""];
	_interfaceState = OXZ_STATE_TASKDONE;
	[_dependencyStack removeAllObjects]; // just in case
	_downloadAllDependencies = NO;
	[self gui];
	return YES;
}


- (oo::PList) installedManifestForIdentifier:(const std::string &)identifier
{
	const oo::PList installed = [self managedOXZs];
	if (const oo::PList::Array *manifests = installed.getIf<oo::PList::Array>())
	{
		for (const oo::PList &manifest : *manifests)
		{
			if (ManifestString(manifest, oo::StdString(kOOManifestIdentifier)) == identifier)
			{
				return manifest;
			}
		}
	}
	return oo::PList();
}


- (OXZInstallableState) installableState:(const oo::PList &)manifest
{
	const std::optional<std::string> title = ManifestString(manifest, oo::StdString(kOOManifestTitle));
	const std::optional<std::string> identifier = ManifestString(manifest, oo::StdString(kOOManifestIdentifier));
	/* Check Oolite version */
	if (![ResourceManager cxx_checkVersionCompatibility:manifest forOXP:title])
	{
		return OXZ_UNINSTALLABLE_VERSION;
	}
	/* Check for current automated install (a missing identifier matched nothing) */
	oo::PList installed = identifier.has_value() ? [self installedManifestForIdentifier:*identifier] : oo::PList();
	if (!installed)
	{
		// check for manual install
		installed = [ResourceManager cxx_manifestForIdentifier:identifier.value_or(std::string())];
	}

	// available_version, else version (the fallback of the old string read)
	std::optional<std::string> availableVersion = ManifestString(manifest, oo::StdString(kOOManifestAvailableVersion));
	if (!availableVersion.has_value())
	{
		availableVersion = ManifestString(manifest, oo::StdString(kOOManifestVersion));
	}
	if (installed)
	{
		const std::optional<std::string> filePath = ManifestString(installed, oo::StdString(kOOManifestFilePath));
		const std::optional<std::string> installPath = [self installPath];
		if (!(filePath.has_value() && installPath.has_value() && oo::str::hasPrefix(*filePath, *installPath)))
		{
			// installed manually
			return OXZ_UNINSTALLABLE_MANUAL;
		}
		const std::optional<std::string> installedVersion = ManifestString(installed, oo::StdString(kOOManifestVersion));
		if (installedVersion.has_value() && availableVersion.has_value() && *installedVersion == *availableVersion
			&& oo::fs::fileExists(oo::fs::pathFromUTF8(*filePath)))
		{
			// installed this exact version already, and haven't
			// uninstalled it since entering the manager, and it's
			// still available
			return OXZ_UNINSTALLABLE_ALREADY;
		}
		else if (!ManifestString(installed, oo::StdString(kOOManifestAvailableVersion)).has_value())
		{
			// installed, but no remote copy is indexed any more
			return OXZ_UNINSTALLABLE_NOREMOTE;
		}
	}
	/* Check for dependencies being met */
	if ([ResourceManager cxx_manifestHasConflicts:manifest logErrors:NO])
	{
		return OXZ_INSTALLABLE_CONFLICTS;
	}
	if (installed)
	{
		const std::optional<std::string> installedVersion = ManifestString(installed, oo::StdString(kOOManifestVersion));
		OOLog(@"version.debug",@"%@ mv:%@ mav:%@",oo::NSStringOrNil(identifier),oo::NSStringOrNil(installedVersion),oo::NSStringOrNil(availableVersion));
		// CompareVersions / ComponentsFromVersionString are unmigrated: strings at the call.
		if (CompareVersions(ComponentsFromVersionString(oo::NSStringOrNil(installedVersion)),ComponentsFromVersionString(oo::NSStringOrNil(availableVersion))) == NSOrderedDescending)
		{
			// the installed copy is more recent than the server copy
			return OXZ_UNINSTALLABLE_NOREMOTE;
		}
		return OXZ_INSTALLABLE_UPDATE;
	}
	if ([ResourceManager cxx_manifestHasMissingDependencies:manifest logErrors:NO])
	{
		return OXZ_INSTALLABLE_DEPENDENCIES;
	}
	return OXZ_INSTALLABLE_OKAY;
}


- (OOColor *) colorForManifest:(const oo::PList &)manifest
{
	switch ([self installableState:manifest])
	{
	case OXZ_INSTALLABLE_OKAY:
		return [OOColor yellowColor];
	case OXZ_INSTALLABLE_UPDATE:
		return [OOColor cyanColor];
	case OXZ_INSTALLABLE_DEPENDENCIES:
		return [OOColor orangeColor];
	case OXZ_INSTALLABLE_CONFLICTS:
		return [OOColor brownColor];
	case OXZ_UNINSTALLABLE_ALREADY:
		return [OOColor whiteColor];
	case OXZ_UNINSTALLABLE_MANUAL:
		return [OOColor redColor];
	case OXZ_UNINSTALLABLE_VERSION:
		return [OOColor grayColor];
	case OXZ_UNINSTALLABLE_NOREMOTE:
		return [OOColor blueColor];
	}
	return [OOColor yellowColor]; // never
}


- (std::optional<std::string>) installStatusForManifest:(const oo::PList &)manifest
{
	switch ([self installableState:manifest])
	{
	case OXZ_INSTALLABLE_OKAY:
		return oo::OptionalString(DESC(@"oolite-oxzmanager-installable-okay"));
	case OXZ_INSTALLABLE_UPDATE:
		return oo::OptionalString(DESC(@"oolite-oxzmanager-installable-update"));
	case OXZ_INSTALLABLE_DEPENDENCIES:
		return oo::OptionalString(DESC(@"oolite-oxzmanager-installable-depend"));
	case OXZ_INSTALLABLE_CONFLICTS:
		return oo::OptionalString(DESC(@"oolite-oxzmanager-installable-conflicts"));
	case OXZ_UNINSTALLABLE_ALREADY:
		return oo::OptionalString(DESC(@"oolite-oxzmanager-installable-already"));
	case OXZ_UNINSTALLABLE_MANUAL:
		return oo::OptionalString(DESC(@"oolite-oxzmanager-installable-manual"));
	case OXZ_UNINSTALLABLE_VERSION:
		return oo::OptionalString(DESC(@"oolite-oxzmanager-installable-version"));
	case OXZ_UNINSTALLABLE_NOREMOTE:
		return oo::OptionalString(DESC(@"oolite-oxzmanager-installable-noremote"));
	}
	return std::nullopt; // never
}



- (void) gui
{
	GuiDisplayGen	*gui = [UNIVERSE gui];
	OOGUIRow		startRow = OXZ_GUI_ROW_EXIT;

#if OOLITE_WINDOWS
	/* unlock OXZs ahead of potential changes by making sure sound
	 * files aren't being held open */
	[ResourceManager clearCaches];
	[PLAYER destroySound];
#endif

	[gui clearAndKeepBackground:YES];
	[gui setTitle:DESC(@"oolite-oxzmanager-title")];

	/* This switch will give warnings unless all states are
	 * covered. */
	switch (_interfaceState)
	{
	case OXZ_STATE_SETFILTER:
		[gui setTitle:DESC(@"oolite-oxzmanager-title-setfilter")];
		{
			id currentFilter = oo::NSStringFrom(_currentFilter);	// the GUI is chunk 4
			[gui setText:[NSString stringWithFormat:DESC(@"oolite-oxzmanager-currentfilter-is-@"),currentFilter] forRow:OXZ_GUI_ROW_FILTERCURRENT align:GUI_ALIGN_LEFT];
		}
		[gui addLongText:DESC(@"oolite-oxzmanager-filterhelp") startingAtRow:OXZ_GUI_ROW_FILTERHELP align:GUI_ALIGN_LEFT];

		
		return; // don't do normal row selection stuff
	case OXZ_STATE_NODATA:
		if (!_oxzList)
		{
			[gui addLongText:DESC(@"oolite-oxzmanager-firstrun") startingAtRow:OXZ_GUI_ROW_FIRSTRUN align:GUI_ALIGN_LEFT];
			[gui setText:DESC(@"oolite-oxzmanager-download-list") forRow:OXZ_GUI_ROW_UPDATE align:GUI_ALIGN_CENTER];
			[gui setKey:@"_UPDATE" forRow:OXZ_GUI_ROW_UPDATE];

			startRow = OXZ_GUI_ROW_UPDATE;
		}
		else
		{
			// update data	
			[gui addLongText:DESC(@"oolite-oxzmanager-secondrun") startingAtRow:OXZ_GUI_ROW_FIRSTRUN align:GUI_ALIGN_LEFT];
			[gui setText:DESC(@"oolite-oxzmanager-download-noupdate") forRow:OXZ_GUI_ROW_PROCEED align:GUI_ALIGN_CENTER];
			[gui setKey:@"_MAIN" forRow:OXZ_GUI_ROW_PROCEED];

			[gui setText:DESC(@"oolite-oxzmanager-update-list") forRow:OXZ_GUI_ROW_UPDATE align:GUI_ALIGN_CENTER];
			[gui setKey:@"_UPDATE" forRow:OXZ_GUI_ROW_UPDATE];

			startRow = OXZ_GUI_ROW_PROCEED;
		}
		break;
	case OXZ_STATE_RESTARTING:
		[gui addLongText:DESC(@"oolite-oxzmanager-restart") startingAtRow:OXZ_GUI_ROW_FIRSTRUN align:GUI_ALIGN_LEFT];
		return; // yes, return, not break: controls are pointless here
	case OXZ_STATE_MAIN:
		[gui addLongText:DESC(@"oolite-oxzmanager-intro") startingAtRow:OXZ_GUI_ROW_FIRSTRUN align:GUI_ALIGN_LEFT];
		// fall through
	case OXZ_STATE_PICK_INSTALL:
	case OXZ_STATE_PICK_INSTALLED:
	case OXZ_STATE_PICK_REMOVE:
		if (_interfaceState != OXZ_STATE_MAIN)
		{
			id currentFilter = oo::NSStringFrom(_currentFilter);	// the GUI is chunk 4
			[gui setText:[NSString stringWithFormat:DESC(@"oolite-oxzmanager-currentfilter-is-@-@"),OOExpand(@"[oolite_key_oxzmanager_setfilter]"),currentFilter] forRow:OXZ_GUI_ROW_LISTFILTER align:GUI_ALIGN_LEFT];
			[gui setColor:[OOColor greenColor] forRow:OXZ_GUI_ROW_LISTFILTER];
		}

		[gui setText:DESC(@"oolite-oxzmanager-install") forRow:OXZ_GUI_ROW_INSTALL align:GUI_ALIGN_CENTER];
		[gui setKey:@"_INSTALL" forRow:OXZ_GUI_ROW_INSTALL];
		[gui setText:DESC(@"oolite-oxzmanager-installed") forRow:OXZ_GUI_ROW_INSTALLED align:GUI_ALIGN_CENTER];
		[gui setKey:@"_INSTALLED" forRow:OXZ_GUI_ROW_INSTALLED];
		[gui setText:DESC(@"oolite-oxzmanager-remove") forRow:OXZ_GUI_ROW_REMOVE align:GUI_ALIGN_CENTER];
		[gui setKey:@"_REMOVE" forRow:OXZ_GUI_ROW_REMOVE];
		[gui setText:DESC(@"oolite-oxzmanager-update-list") forRow:OXZ_GUI_ROW_UPDATE align:GUI_ALIGN_CENTER];
		[gui setKey:@"_UPDATE" forRow:OXZ_GUI_ROW_UPDATE];
		[gui setText:DESC(@"oolite-oxzmanager-update-all") forRow:OXZ_GUI_ROW_UPDATE_ALL align:GUI_ALIGN_CENTER];
		[gui setKey:@"_UPDATE_ALL" forRow:OXZ_GUI_ROW_UPDATE_ALL];

		startRow = OXZ_GUI_ROW_INSTALL;
		break;
	case OXZ_STATE_UPDATING:
	case OXZ_STATE_INSTALLING:
		[gui setTitle:DESC(@"oolite-oxzmanager-title-downloading")];

		if (_downloadStatus == OXZ_DOWNLOAD_ERROR)
		{
			[gui addLongText:OOExpandKey(@"oolite-oxzmanager-progress-error") startingAtRow:OXZ_GUI_ROW_PROGRESS align:GUI_ALIGN_LEFT];
		}
		else
		{
			[gui addLongText:[NSString stringWithFormat:DESC(@"oolite-oxzmanager-progress-@-is-@-of-@"),_currentDownloadName,oo::NSStringOrNil([self humanSize:_downloadProgress]),oo::NSStringOrNil([self humanSize:_downloadExpected])] startingAtRow:OXZ_GUI_ROW_PROGRESS align:GUI_ALIGN_LEFT];
		}
		[gui addLongText:_progressStatus startingAtRow:OXZ_GUI_ROW_PROGRESS+2 align:GUI_ALIGN_LEFT];

		[gui setText:DESC(@"oolite-oxzmanager-cancel") forRow:OXZ_GUI_ROW_CANCEL align:GUI_ALIGN_CENTER];
		[gui setKey:@"_CANCEL" forRow:OXZ_GUI_ROW_CANCEL];
		startRow = OXZ_GUI_ROW_UPDATE;
		break;
	case OXZ_STATE_DEPENDENCIES:
		[gui setTitle:DESC(@"oolite-oxzmanager-title-dependencies")];

		[gui setText:DESC(@"oolite-oxzmanager-dependencies-decision") forRow:OXZ_GUI_ROW_PROGRESS align:GUI_ALIGN_LEFT];

		[gui addLongText:_progressStatus startingAtRow:OXZ_GUI_ROW_PROGRESS+2 align:GUI_ALIGN_LEFT];

		startRow = OXZ_GUI_ROW_INSTALLED;
		[gui setText:DESC(@"oolite-oxzmanager-dependencies-yes-all") forRow:OXZ_GUI_ROW_INSTALLED align:GUI_ALIGN_CENTER];
		[gui setKey:@"_PROCEED_ALL" forRow:OXZ_GUI_ROW_INSTALLED];

		[gui setText:DESC(@"oolite-oxzmanager-dependencies-yes") forRow:OXZ_GUI_ROW_PROCEED align:GUI_ALIGN_CENTER];
		[gui setKey:@"_PROCEED" forRow:OXZ_GUI_ROW_PROCEED];

		[gui setText:DESC(@"oolite-oxzmanager-dependencies-no") forRow:OXZ_GUI_ROW_CANCEL align:GUI_ALIGN_CENTER];
		[gui setKey:@"_CANCEL" forRow:OXZ_GUI_ROW_CANCEL];
		break;

	case OXZ_STATE_REMOVING:
		[gui addLongText:DESC(@"oolite-oxzmanager-removal-done") startingAtRow:OXZ_GUI_ROW_PROGRESS align:GUI_ALIGN_LEFT];
		[gui setText:DESC(@"oolite-oxzmanager-acknowledge") forRow:OXZ_GUI_ROW_UPDATE align:GUI_ALIGN_CENTER];
		[gui setKey:@"_ACK" forRow:OXZ_GUI_ROW_UPDATE];
		startRow = OXZ_GUI_ROW_UPDATE;
		break;
	case OXZ_STATE_TASKDONE:
		if (_downloadStatus == OXZ_DOWNLOAD_COMPLETE)
		{
			[gui addLongText:[NSString stringWithFormat:DESC(@"oolite-oxzmanager-progress-done-%u-%u"),_oxzList.count(),[self managedOXZs].count()] startingAtRow:OXZ_GUI_ROW_PROGRESS align:GUI_ALIGN_LEFT];
		}
		else
		{
			[gui addLongText:OOExpandKey(@"oolite-oxzmanager-progress-error") startingAtRow:OXZ_GUI_ROW_PROGRESS align:GUI_ALIGN_LEFT];
		}
		[gui addLongText:_progressStatus startingAtRow:OXZ_GUI_ROW_PROGRESS+4 align:GUI_ALIGN_LEFT];

		[gui setText:DESC(@"oolite-oxzmanager-acknowledge") forRow:OXZ_GUI_ROW_UPDATE align:GUI_ALIGN_CENTER];
		[gui setKey:@"_ACK" forRow:OXZ_GUI_ROW_UPDATE];
		startRow = OXZ_GUI_ROW_UPDATE;
		break;
	case OXZ_STATE_EXTRACT:
		{
			NSDictionary *manifest = oo::ObjectFromPList(ElementAt(_filteredList, _item));
			NSString *title = oo::PListView(manifest).get<NSString *>(kOOManifestTitle);
			NSString *version = oo::PListView(manifest).get<NSString *>(kOOManifestVersion);
			NSString *identifier = oo::PListView(manifest).get<NSString *>(kOOManifestIdentifier);
			[gui setTitle:DESC(@"oolite-oxzmanager-title-extract")];
			[gui setText:[NSString stringWithFormat:DESC(@"oolite-oxzmanager-infopage-title-@-version-@"),
								   title,
								   version]
				  forRow:0 align:GUI_ALIGN_LEFT];
			[gui addLongText:DESC(@"oolite-oxzmanager-extract-info") startingAtRow:2 align:GUI_ALIGN_LEFT];
#ifdef NDEBUG
			[gui addLongText:DESC(@"oolite-oxzmanager-extract-releasebuild") startingAtRow:7 align:GUI_ALIGN_LEFT];
			[gui setColor:[OOColor orangeColor] forRow:7];
			[gui setColor:[OOColor orangeColor] forRow:8];
#endif
			NSString *path = oo::NSStringOrNil([self extractionBasePathForIdentifier:oo::DescriptionOf(identifier) andVersion:oo::DescriptionOf(version)]);
			if ([[NSFileManager defaultManager] fileExistsAtPath:path])
			{
				[gui addLongText:[NSString stringWithFormat:DESC(@"oolite-oxzmanager-extract-@-already-exists"), path]
				  startingAtRow:10 align:GUI_ALIGN_LEFT];
				startRow = OXZ_GUI_ROW_CANCEL;
				[gui setText:DESC(@"oolite-oxzmanager-extract-unavailable") forRow:OXZ_GUI_ROW_PROCEED align:GUI_ALIGN_CENTER];
				[gui setColor:[OOColor grayColor] forRow:OXZ_GUI_ROW_PROCEED];
			}
			else
			{
				[gui addLongText:[NSString stringWithFormat:DESC(@"oolite-oxzmanager-extract-to-@"), path]
				  startingAtRow:10 align:GUI_ALIGN_LEFT];
				startRow = OXZ_GUI_ROW_PROCEED;
				[gui setText:DESC(@"oolite-oxzmanager-extract-proceed") forRow:OXZ_GUI_ROW_PROCEED align:GUI_ALIGN_CENTER];
				[gui setKey:@"_PROCEED" forRow:OXZ_GUI_ROW_PROCEED];

			}
			[gui setText:DESC(@"oolite-oxzmanager-extract-cancel") forRow:OXZ_GUI_ROW_CANCEL align:GUI_ALIGN_CENTER];
			[gui setKey:@"_CANCEL" forRow:OXZ_GUI_ROW_CANCEL];

		}	
		break;
	case OXZ_STATE_EXTRACTDONE:
		[gui addLongText:_progressStatus startingAtRow:1 align:GUI_ALIGN_LEFT];
		[gui setText:DESC(@"oolite-oxzmanager-acknowledge") forRow:OXZ_GUI_ROW_UPDATE align:GUI_ALIGN_CENTER];
		[gui setKey:@"_ACK" forRow:OXZ_GUI_ROW_UPDATE];
		startRow = OXZ_GUI_ROW_UPDATE;
		break;

	}

	if (_interfaceState == OXZ_STATE_PICK_INSTALL)
	{
		[gui setTitle:DESC(@"oolite-oxzmanager-title-install")];
		[self setFilteredList:[self applyCurrentFilter:_oxzList]];
		startRow = [self showInstallOptions];
	}
	else if (_interfaceState == OXZ_STATE_PICK_INSTALLED)
	{
		[gui setTitle:DESC(@"oolite-oxzmanager-title-installed")];
		[self setFilteredList:[self applyCurrentFilter:[self managedOXZs]]];
		startRow = [self showInstallOptions];
	}
	else if (_interfaceState == OXZ_STATE_PICK_REMOVE)
	{
		[gui setTitle:DESC(@"oolite-oxzmanager-title-remove")];
		[self setFilteredList:[self applyCurrentFilter:[self managedOXZs]]];
		startRow = [self showRemoveOptions];
	}


	if (_changesMade)
	{
		[gui setText:DESC(@"oolite-oxzmanager-exit-restart") forRow:OXZ_GUI_ROW_EXIT align:GUI_ALIGN_CENTER];
	}
	else
	{
		[gui setText:DESC(@"oolite-oxzmanager-exit") forRow:OXZ_GUI_ROW_EXIT align:GUI_ALIGN_CENTER];
	}
	[gui setKey:@"_EXIT" forRow:OXZ_GUI_ROW_EXIT];
	[gui setSelectableRange:NSMakeRange(startRow,2+(OXZ_GUI_ROW_EXIT-startRow))];
	if (startRow < OXZ_GUI_ROW_INSTALL)
	{
		[gui setSelectedRow:OXZ_GUI_ROW_INSTALL];
	}
	else if (_interfaceState == OXZ_STATE_NODATA)
	{
		[gui setSelectedRow:OXZ_GUI_ROW_UPDATE];
	}
	else
	{
		[gui setSelectedRow:startRow];
	}
	
}


- (BOOL) isRestarting
{
	// for the restart
	if (EXPECT_NOT(_interfaceState == OXZ_STATE_RESTARTING))
	{
		// Rebuilds OXP search
		[ResourceManager reset];
		[UNIVERSE reinitAndShowDemo:YES];
		_changesMade = NO;
		_interfaceState = OXZ_STATE_MAIN;
		_downloadStatus = OXZ_DOWNLOAD_NONE; // clear error state
		return YES;
	}
	else
	{
		return NO;
	}
}


- (void) processSelection
{
	GuiDisplayGen	*gui = [UNIVERSE gui];
	OOGUIRow selection = [gui selectedRow];

	if (selection == OXZ_GUI_ROW_EXIT)
	{
		[self cancelUpdate]; // doesn't hurt if no update in progress
		[_dependencyStack removeAllObjects]; // cleanup
		_downloadAllDependencies = NO;
		_downloadStatus = OXZ_DOWNLOAD_NONE; // clear error state
		if (_changesMade)
		{
			_interfaceState = OXZ_STATE_RESTARTING;
		}
		else
		{
			[PLAYER setGuiToIntroFirstGo:YES];
			if (_oxzList)
			{
				_interfaceState = OXZ_STATE_MAIN;
			}
			else
			{
				_interfaceState = OXZ_STATE_NODATA;
			}
			return;
		}
	}
	else if (selection == OXZ_GUI_ROW_UPDATE) // also == _CANCEL
	{
		if (_interfaceState == OXZ_STATE_REMOVING)
		{
			_interfaceState = OXZ_STATE_PICK_REMOVE;
			_downloadStatus = OXZ_DOWNLOAD_NONE;
		}
		else if (_interfaceState == OXZ_STATE_TASKDONE || _interfaceState == OXZ_STATE_DEPENDENCIES)
		{
			[_dependencyStack removeAllObjects];
			_downloadAllDependencies = NO;
			_interfaceState = OXZ_STATE_PICK_INSTALL;
			_downloadStatus = OXZ_DOWNLOAD_NONE;
		}
		else if (_interfaceState == OXZ_STATE_EXTRACTDONE)
		{
			[_dependencyStack removeAllObjects];
			_downloadAllDependencies = NO;
			_interfaceState = OXZ_STATE_PICK_INSTALLED;
			_downloadStatus = OXZ_DOWNLOAD_NONE;
		}
		else if (_interfaceState == OXZ_STATE_INSTALLING || _interfaceState == OXZ_STATE_UPDATING)
		{
			[self cancelUpdate]; // sets interface state and download status
		}
		else if (_interfaceState == OXZ_STATE_EXTRACT)
		{
			_interfaceState = OXZ_STATE_MAIN;
		}
		else
		{
			[self updateManifests];
		}
	}
	else if (selection == OXZ_GUI_ROW_INSTALL)
	{
		_interfaceState = OXZ_STATE_PICK_INSTALL;
	}
	else if (selection == OXZ_GUI_ROW_INSTALLED)
	{
		if (_interfaceState == OXZ_STATE_DEPENDENCIES) // also == _PROCEED_ALL
		{
			_downloadAllDependencies = YES;
			[self installOXZ:_item];
		}
		else 
		{
			_interfaceState = OXZ_STATE_PICK_INSTALLED;
		}
	}
	else if (selection == OXZ_GUI_ROW_REMOVE) // also == _PROCEED
	{
		if (_interfaceState == OXZ_STATE_DEPENDENCIES)
		{
			[self installOXZ:_item];
		}
		else if (_interfaceState == OXZ_STATE_NODATA)
		{
			_interfaceState = OXZ_STATE_MAIN;
		}
		else if (_interfaceState == OXZ_STATE_EXTRACT)
		{
			[self setProgressStatus:[self extractOXZ:_item]];
			_interfaceState = OXZ_STATE_EXTRACTDONE;
		}
		else
		{
			_interfaceState = OXZ_STATE_PICK_REMOVE;
		}
	}
	else if (selection == OXZ_GUI_ROW_UPDATE_ALL)
	{
		OOLog(kOOOXZDebugLog, @"%@", @"Trying to update all managed OXPs");
		[self updateAllOXZ];
	}
	else if (selection == OXZ_GUI_ROW_LISTPREV)
	{
		[self processOptionsPrev];
		return;
	}
	else if (selection == OXZ_GUI_ROW_LISTNEXT)
	{
		[self processOptionsNext];
		return;
	}
	else
	{
		NSUInteger item = _offset + selection - OXZ_GUI_ROW_LISTSTART;
		if (_interfaceState == OXZ_STATE_PICK_REMOVE)
		{
			[self removeOXZ:item];
		}
		else if (_interfaceState == OXZ_STATE_PICK_INSTALL)
		{
			OOLog(kOOOXZDebugLog, @"Trying to install index %zu", item);
			[self installOXZ:item];
		}
		else if (_interfaceState == OXZ_STATE_PICK_INSTALLED)
		{
			OOLog(kOOOXZDebugLog, @"Trying to install index %zu", item);
			[self installOXZ:item];
		}

	}

	[self gui]; // update GUI
}


- (BOOL) isAcceptingTextInput
{
	return (_interfaceState == OXZ_STATE_SETFILTER);
}


- (BOOL) isAcceptingGUIInput
{
	return !_interfaceShowingOXZDetail;
}


- (void) processTextInput:(NSString *)input
{
	if ([self validateFilter:oo::StdString(input)])
	{
		if ([input length] > 0)
		{
			[self setFilter:oo::StdString(input)];
		} // else keep previous filter
		_interfaceState = OXZ_STATE_PICK_INSTALL;
		[self gui];
	}
	// else nothing
}


- (void) refreshTextInput:(NSString *)input
{
	GuiDisplayGen	*gui = [UNIVERSE gui];
	[gui setText:[NSString stringWithFormat:DESC(@"oolite-oxzmanager-text-prompt-@"), input] forRow:OXZ_GUI_ROW_INPUT align:GUI_ALIGN_LEFT];
	if ([self validateFilter:oo::StdString(input)])
	{
		[gui setColor:[OOColor cyanColor] forRow:OXZ_GUI_ROW_INPUT];
	}
	else
	{
		[gui setColor:[OOColor orangeColor] forRow:OXZ_GUI_ROW_INPUT];
	}
}


- (void) processFilterKey
{
	if (_interfaceShowingOXZDetail)
	{
		_interfaceShowingOXZDetail = NO;
	}
	if (_interfaceState == OXZ_STATE_PICK_INSTALL || _interfaceState == OXZ_STATE_PICK_INSTALLED || _interfaceState == OXZ_STATE_PICK_REMOVE || _interfaceState == OXZ_STATE_MAIN)
	{
		_interfaceState = OXZ_STATE_SETFILTER;
		[[UNIVERSE gameView] resetTypedString];
		[self gui];
	}
	// else this key does nothing
}


- (void) processShowInfoKey
{
	if (_interfaceState == OXZ_STATE_PICK_INSTALL || _interfaceState == OXZ_STATE_PICK_INSTALLED || _interfaceState == OXZ_STATE_PICK_REMOVE)
	{
		GuiDisplayGen	*gui = [UNIVERSE gui];

		if (_interfaceShowingOXZDetail)
		{
			_interfaceShowingOXZDetail = NO;
			[self gui]; // restore screen
			// reset list selection position
			[gui setSelectedRow:(_item - _offset + OXZ_GUI_ROW_LISTSTART)];
			// and do the GUI again with the correct positions
			[self showOptionsUpdate]; // restore screen
		}
		else
		{
			OOGUIRow selection = [gui selectedRow];
			
			if (selection < OXZ_GUI_ROW_LISTSTART || selection >= OXZ_GUI_ROW_LISTSTART + OXZ_GUI_NUM_LISTROWS)
			{
				// not on an OXZ
				return;
			}


			_item = _offset + selection - OXZ_GUI_ROW_LISTSTART;

			NSDictionary *manifest = oo::ObjectFromPList(ElementAt(_filteredList, _item));
			_interfaceShowingOXZDetail = YES;

			[gui clearAndKeepBackground:YES];
			[gui setTitle:DESC(@"oolite-oxzmanager-title-infopage")];

// title, version			
			[gui setText:[NSString stringWithFormat:DESC(@"oolite-oxzmanager-infopage-title-@-version-@"),
								   oo::PListView(manifest).get<NSString *>(kOOManifestTitle),
								   oo::PListView(manifest).get<NSString *>(kOOManifestVersion)]
				  forRow:0 align:GUI_ALIGN_LEFT];

// author
			[gui setText:[NSString stringWithFormat:DESC(@"oolite-oxzmanager-infopage-author-@"),
								   oo::PListView(manifest).get<NSString *>(kOOManifestAuthor)]
				  forRow:1 align:GUI_ALIGN_LEFT];

// license
			[gui addLongText:[NSString stringWithFormat:DESC(@"oolite-oxzmanager-infopage-license-@"),
								   oo::PListView(manifest).get<NSString *>(kOOManifestLicense)]
				  startingAtRow:2 align:GUI_ALIGN_LEFT];
// tags
			
			[gui addLongText:[NSString stringWithFormat:DESC(@"oolite-oxzmanager-infopage-tags-@"),[oo::PListView(manifest).get<NSArray *>(kOOManifestTags) componentsJoinedByString: @", "]]
				  startingAtRow:4  align:GUI_ALIGN_LEFT];
// description
			[gui addLongText:[NSString stringWithFormat:DESC(@"oolite-oxzmanager-infopage-description-@"),oo::PListView(manifest).get<NSString *>(kOOManifestDescription)]
				  startingAtRow:7  align:GUI_ALIGN_LEFT];

// infoURL		
			NSString *infoURLString = oo::PListView(manifest).get<NSString *>(kOOManifestInformationURL);
			[gui setText:[NSString stringWithFormat:DESC(@"oolite-oxzmanager-infopage-infourl-@"),
								   infoURLString]
				  forRow:25 align:GUI_ALIGN_LEFT];
			// copy url info text to clipboard automatically once we are in the oxz info page
			[[UNIVERSE gameView] stringToClipboard:infoURLString];	  
				  
// instructions
			[gui setText:OOExpand(DESC(@"oolite-oxzmanager-infopage-return")) forRow:27 align:GUI_ALIGN_CENTER];
			[gui setColor:[OOColor greenColor] forRow:27];

		}
	}
}


- (void) processExtractKey
{
	// TODO: Extraction functionality - converts an installed OXZ to
	// an OXP in the main AddOns folder if it's safe to do so.
	if (!_interfaceShowingOXZDetail && (_interfaceState == OXZ_STATE_PICK_INSTALLED || _interfaceState == OXZ_STATE_PICK_REMOVE))
	{
		GuiDisplayGen	*gui = [UNIVERSE gui];
		OOGUIRow selection = [gui selectedRow];
		
		if (selection < OXZ_GUI_ROW_LISTSTART || selection >= OXZ_GUI_ROW_LISTSTART + OXZ_GUI_NUM_LISTROWS)
		{
			// not on an OXZ
			return;
		}
		
		_item = _offset + selection - OXZ_GUI_ROW_LISTSTART;
		_interfaceState = OXZ_STATE_EXTRACT;
		[self gui];
	}
}


- (BOOL) installOXZ:(NSUInteger)item 
{
	if (_filteredList.count() <= item)
	{
		return NO;
	}
	NSDictionary *manifest = oo::ObjectFromPList(ElementAt(_filteredList, item));	// the download is chunk 5
	_item = item;

	if ([self installableState:ElementAt(_filteredList, item)] >= OXZ_UNINSTALLABLE_ALREADY)
	{
		OOLog(kOOOXZDebugLog,@"Cannot install %@",manifest);
		// can't be installed on this version of Oolite, or already is installed
		return NO;
	}
	NSString *url = [manifest objectForKey:kOOManifestDownloadURL];
	if (url == nil)
	{
		OOLog(kOOOXZErrorLog, @"%@", @"Manifest does not have a download URL - cannot install");
		return NO;
	}
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
	if (_downloadStatus != OXZ_DOWNLOAD_NONE)
	{
		return NO;
	}
	_downloadStatus = OXZ_DOWNLOAD_STARTED;
	_interfaceState = OXZ_STATE_INSTALLING;
	
	[self setProgressStatus:@""];
	return [self beginDownload:request];
}


- (BOOL) updateAllOXZ
{
	[_dependencyStack removeAllObjects];
	_downloadAllDependencies = YES;
	[self setFilteredList:_oxzList];

	for (const oo::PList &entry : Elements(_oxzList))
	{
		if ([self installableState:entry] == OXZ_INSTALLABLE_UPDATE)
		{
			id manifest = oo::ObjectFromPList(entry);	// the dependency stack is chunk 5
			OOLog(kOOOXZDebugLog, @"Queuing in for update: %@", manifest);
			[_dependencyStack addObject:manifest];
		}
	}
	NSDictionary *first = [_dependencyStack anyObject];
	NSString* identifier = oo::PListView(first).get<NSString *>(kOOManifestRelationIdentifier);
	NSUInteger item = NSUIntegerMax;
	for (NSUInteger i = 0; i < _oxzList.count(); i++)
	{
		const std::optional<std::string> availableIdentifier = ManifestString(*_oxzList.at(i), oo::StdString(kOOManifestIdentifier));
		if (availableIdentifier.has_value() && identifier != nil && *availableIdentifier == oo::StdString(identifier))
		{
			item = i;	// the first equal manifest, as -indexOfObject: found
			break;
		}
	}
	return [self installOXZ:item];
}


- (NSArray *) installOptions
{
	NSUInteger start = _offset;
	if (start >= _filteredList.count())
	{
		start = 0;
		_offset = 0;
	}
	NSUInteger end = start + OXZ_GUI_NUM_LISTROWS;
	if (end > _filteredList.count())
	{
		end = _filteredList.count();
	}
	const oo::PList::Array &all = Elements(_filteredList);
	return oo::ObjectFromPList(oo::PList(oo::PList::Array(all.begin() + start, all.begin() + end)));	// the GUI is chunk 4
}


- (OOGUIRow) showInstallOptions
{
	// shows the current installation options page
	OOGUIRow startRow = OXZ_GUI_ROW_LISTPREV;
	NSArray *options = [self installOptions];
	NSUInteger optCount = _filteredList.count();
	GuiDisplayGen	*gui = [UNIVERSE gui];
	OOGUITabSettings tab_stops;
	tab_stops[0] = 0;
	tab_stops[1] = 100;
	tab_stops[2] = 320;
	tab_stops[3] = 400;
	[gui setTabStops:tab_stops];
	

	[gui setArray:[NSArray arrayWithObjects:DESC(@"oolite-oxzmanager-heading-category"),
						   DESC(@"oolite-oxzmanager-heading-title"), 
						   DESC(@"oolite-oxzmanager-heading-installed"), 
						   DESC(@"oolite-oxzmanager-heading-downloadable"), 
								nil] forRow:OXZ_GUI_ROW_LISTHEAD];

	if (_offset > 0)
	{
		[gui setColor:[OOColor greenColor] forRow:OXZ_GUI_ROW_LISTPREV];
		[gui setArray:[NSArray arrayWithObjects:DESC(@"gui-back"), @"",@"",@" <-- ", nil] forRow:OXZ_GUI_ROW_LISTPREV];
		[gui setKey:@"_BACK" forRow:OXZ_GUI_ROW_LISTPREV];
	}
	else
	{
		if ([gui selectedRow] == OXZ_GUI_ROW_LISTPREV)
		{
			[gui setSelectedRow:OXZ_GUI_ROW_LISTSTART];
		}
		[gui setText:@"" forRow:OXZ_GUI_ROW_LISTPREV align:GUI_ALIGN_LEFT];
		[gui setKey:GUI_KEY_SKIP forRow:OXZ_GUI_ROW_LISTPREV];
	}
	if (_offset + 10 < optCount)
	{
		[gui setColor:[OOColor greenColor] forRow:OXZ_GUI_ROW_LISTNEXT];
		[gui setArray:[NSArray arrayWithObjects:DESC(@"gui-more"), @"",@"",@" --> ", nil] forRow:OXZ_GUI_ROW_LISTNEXT];
		[gui setKey:@"_NEXT" forRow:OXZ_GUI_ROW_LISTNEXT];
	}
	else
	{
		if ([gui selectedRow] == OXZ_GUI_ROW_LISTNEXT)
		{
			[gui setSelectedRow:OXZ_GUI_ROW_LISTSTART];
		}
		[gui setText:@"" forRow:OXZ_GUI_ROW_LISTNEXT align:GUI_ALIGN_LEFT];
		[gui setKey:GUI_KEY_SKIP forRow:OXZ_GUI_ROW_LISTNEXT];
	}

	// clear any previous longtext
	for (NSUInteger i = OXZ_GUI_ROW_LISTSTATUS; i < OXZ_GUI_ROW_INSTALL-1; i++)
	{
		[gui setText:@"" forRow:i align:GUI_ALIGN_LEFT];
		[gui setKey:GUI_KEY_SKIP forRow:i];
	}
	// and any previous listed entries
	for (NSUInteger i = OXZ_GUI_ROW_LISTSTART; i < OXZ_GUI_ROW_LISTNEXT; i++)
	{
		[gui setText:@"" forRow:i align:GUI_ALIGN_LEFT];
		[gui setKey:GUI_KEY_SKIP forRow:i];
	}

	OOGUIRow row = OXZ_GUI_ROW_LISTSTART;
	NSDictionary *manifest = nil;
	BOOL oxzLineSelected = NO;

	foreach (manifest, options)
	{
		NSDictionary *installed = [ResourceManager manifestForIdentifier:oo::PListView(manifest).get<NSString *>(kOOManifestIdentifier)];
		NSString *localPath = [[oo::NSStringOrNil([self installPath]) stringByAppendingPathComponent:oo::PListView(manifest).get<NSString *>(kOOManifestIdentifier)] stringByAppendingPathExtension:@"oxz"];
		if (installed == nil)
		{
			// check that there's not one just been downloaded
			installed = OODictionaryFromFile([localPath stringByAppendingPathComponent:@"manifest.plist"]);
		}
		else
		{
			// check for a more recent download
			if ([[NSFileManager defaultManager] fileExistsAtPath:localPath])
			{
				
				installed = OODictionaryFromFile([localPath stringByAppendingPathComponent:@"manifest.plist"]);
			}
			else
			{
				// check if this was a managed OXZ which has been deleted
				if ([oo::PListView(installed).get<NSString *>(kOOManifestFilePath) hasPrefix:oo::NSStringOrNil([self installPath])])
				{
					installed = nil;
				}
			}
		}

		NSString *installedVersion = DESC(@"oolite-oxzmanager-version-none");
		if (installed != nil)
		{
			installedVersion = oo::PListView(installed).get<NSString *>(kOOManifestVersion, DESC(@"oolite-oxzmanager-version-none"));
		}

		/* If the filter is in use, the available_version key will
		 * contain the version which can be downloaded. */
		[gui setArray:[NSArray arrayWithObjects:
			 oo::PListView(manifest).get<NSString *>(kOOManifestCategory, DESC(@"oolite-oxzmanager-missing-field")),
			 oo::PListView(manifest).get<NSString *>(kOOManifestTitle, DESC(@"oolite-oxzmanager-missing-field")),
			 installedVersion,
		 	 oo::PListView(manifest).get<NSString *>(kOOManifestAvailableVersion, oo::PListView(manifest).get<NSString *>(kOOManifestVersion, DESC(@"oolite-oxzmanager-version-none"))),
		  nil] forRow:row];

		[gui setKey:oo::PListView(manifest).get<NSString *>(kOOManifestIdentifier) forRow:row];
		/* yellow for installable, orange for dependency issues, grey and unselectable for version issues, white and unselectable for already installed (manually or otherwise) at the current version, red and unselectable for already installed manually at a different version. */
		[gui setColor:[self colorForManifest:oo::PListFrom(manifest)] forRow:row];

		if (row == [gui selectedRow])
		{
			oxzLineSelected = YES;
			
			[gui setText:oo::NSStringOrNil([self installStatusForManifest:oo::PListFrom(manifest)]) forRow:OXZ_GUI_ROW_LISTSTATUS];
			[gui setColor:[OOColor greenColor] forRow:OXZ_GUI_ROW_LISTSTATUS];

			[gui addLongText:oo::PListView([oo::PListView(manifest).get<NSString *>(kOOManifestDescription) componentsSeparatedByString:@"\n"]).at<NSString *>(0) startingAtRow:OXZ_GUI_ROW_LISTDESC align:GUI_ALIGN_LEFT];
			
			NSString *infoUrl = oo::PListView(manifest).get<NSString *>(kOOManifestInformationURL);
			if (infoUrl != nil)
			{
				[gui setArray:[NSArray arrayWithObjects:DESC(@"oolite-oxzmanager-infoline-url"),infoUrl,nil] forRow:OXZ_GUI_ROW_LISTINFO1];
			}
			NSUInteger size = oo::PListView(manifest).get<unsigned int>(kOOManifestFileSize, 0);
			NSString *updatedDesc = nil;

			NSUInteger timestamp = oo::PListView(manifest).get<NSUInteger>(kOOManifestUploadDate, 0);
			if (timestamp > 0)
			{
				// list of installable OXZs
				NSDate *updated = [NSDate dateWithTimeIntervalSince1970:timestamp];
			
				//keep only the first part of the date string description, which should be in YYYY-MM-DD format
				updatedDesc = oo::PListView([[updated description] componentsSeparatedByString:@" "]).at<NSString *>(0);
				
				[gui setArray:[NSArray arrayWithObjects:DESC(@"oolite-oxzmanager-infoline-size"),oo::NSStringOrNil([self humanSize:size]),DESC(@"oolite-oxzmanager-infoline-date"),updatedDesc,nil] forRow:OXZ_GUI_ROW_LISTINFO2];
			} 
			else if (size > 0)
			{
				// list of installed/removable OXZs
				[gui setArray:[NSArray arrayWithObjects:DESC(@"oolite-oxzmanager-infoline-size"),oo::NSStringOrNil([self humanSize:size]),nil] forRow:OXZ_GUI_ROW_LISTINFO2];
			}
			

		}
		

		row++;
	}

	if (!oxzLineSelected)
	{
		if (_interfaceState == OXZ_STATE_PICK_INSTALLED)
		{
			// installeD
			[gui addLongText:OOExpand(DESC(@"oolite-oxzmanager-installed-nonepicked")) startingAtRow:OXZ_GUI_ROW_LISTDESC align:GUI_ALIGN_LEFT];
		}
		else
		{
			// installeR
			[gui addLongText:OOExpand(DESC(@"oolite-oxzmanager-installer-nonepicked")) startingAtRow:OXZ_GUI_ROW_LISTDESC align:GUI_ALIGN_LEFT];
		}
		
	}


	return startRow;
}


- (BOOL) removeOXZ:(NSUInteger)item
{
	if (_filteredList.count() <= item)
	{
		OOLog(kOOOXZDebugLog, @"Unable to remove item %zu as only %zu in list", item, _filteredList.count());
		return NO;
	}
	NSString *filename = oo::NSStringOrNil(ManifestString(ElementAt(_filteredList, item), oo::StdString(kOOManifestFilePath)));
	if (filename == nil)
	{
		OOLog(kOOOXZDebugLog, @"Unable to remove item %zu as filename not found", item);
		return NO;
	}

	if (![[NSFileManager defaultManager] oo_removeItemAtPath:filename])
	{
		OOLog(kOOOXZErrorLog, @"Unable to remove file %@", filename);
		return NO;
	}
	_changesMade = YES;
	_managedList = oo::PList(); // will need updating
	_interfaceState = OXZ_STATE_REMOVING;
	[self gui];
	return YES;
}


- (NSArray *) removeOptions
{
	if (_filteredList.count() == 0)
	{
		return nil;
	}
	NSUInteger start = _offset;
	if (start >= _filteredList.count())
	{
		start = 0;
		_offset = 0;
	}
	NSUInteger end = start + OXZ_GUI_NUM_LISTROWS;
	if (end > _filteredList.count())
	{
		end = _filteredList.count();
	}
	const oo::PList::Array &all = Elements(_filteredList);
	return oo::ObjectFromPList(oo::PList(oo::PList::Array(all.begin() + start, all.begin() + end)));	// the GUI is chunk 4
}


- (OOGUIRow) showRemoveOptions
{
	// shows the current installation options page
	OOGUIRow startRow = OXZ_GUI_ROW_LISTPREV;
	NSArray *options = [self removeOptions];
	GuiDisplayGen	*gui = [UNIVERSE gui];
	if (options == nil)
	{
		[gui addLongText:DESC(@"oolite-oxzmanager-nothing-removable") startingAtRow:OXZ_GUI_ROW_PROGRESS align:GUI_ALIGN_LEFT];
		return startRow;
	}

	OOGUITabSettings tab_stops;
	tab_stops[0] = 0;
	tab_stops[1] = 100;
	tab_stops[2] = 400;
	[gui setTabStops:tab_stops];
	
	[gui setArray:[NSArray arrayWithObjects:DESC(@"oolite-oxzmanager-heading-category"),
						   DESC(@"oolite-oxzmanager-heading-title"), 
						   DESC(@"oolite-oxzmanager-heading-version"), 
								nil] forRow:OXZ_GUI_ROW_LISTHEAD];
	if (_offset > 0)
	{
		[gui setColor:[OOColor greenColor] forRow:OXZ_GUI_ROW_LISTPREV];
		[gui setArray:[NSArray arrayWithObjects:DESC(@"gui-back"), @"",@" <-- ", nil] forRow:OXZ_GUI_ROW_LISTPREV];
		[gui setKey:@"_BACK" forRow:OXZ_GUI_ROW_LISTPREV];
	}
	else
	{
		if ([gui selectedRow] == OXZ_GUI_ROW_LISTPREV)
		{
			[gui setSelectedRow:OXZ_GUI_ROW_LISTSTART];
		}
		[gui setText:@"" forRow:OXZ_GUI_ROW_LISTPREV align:GUI_ALIGN_LEFT];
		[gui setKey:GUI_KEY_SKIP forRow:OXZ_GUI_ROW_LISTPREV];
	}
	if (_offset + OXZ_GUI_NUM_LISTROWS < [self managedOXZs].count())
	{
		[gui setColor:[OOColor greenColor] forRow:OXZ_GUI_ROW_LISTNEXT];
		[gui setArray:[NSArray arrayWithObjects:DESC(@"gui-more"), @"",@" --> ", nil] forRow:OXZ_GUI_ROW_LISTNEXT];
		[gui setKey:@"_NEXT" forRow:OXZ_GUI_ROW_LISTNEXT];
	}
	else
	{
		if ([gui selectedRow] == OXZ_GUI_ROW_LISTNEXT)
		{
			[gui setSelectedRow:OXZ_GUI_ROW_LISTSTART];
		}
		[gui setText:@"" forRow:OXZ_GUI_ROW_LISTNEXT align:GUI_ALIGN_LEFT];
		[gui setKey:GUI_KEY_SKIP forRow:OXZ_GUI_ROW_LISTNEXT];
	}

	// clear any previous longtext
	for (NSUInteger i = OXZ_GUI_ROW_LISTDESC; i < OXZ_GUI_ROW_INSTALL-1; i++)
	{
		[gui setText:@"" forRow:i align:GUI_ALIGN_LEFT];
		[gui setKey:GUI_KEY_SKIP forRow:i];
	}
	// and any previous listed entries
	for (NSUInteger i = OXZ_GUI_ROW_LISTSTART; i < OXZ_GUI_ROW_LISTNEXT; i++)
	{
		[gui setText:@"" forRow:i align:GUI_ALIGN_LEFT];
		[gui setKey:GUI_KEY_SKIP forRow:i];
	}


	OOGUIRow row = OXZ_GUI_ROW_LISTSTART;
	NSDictionary *manifest = nil;
	BOOL oxzSelected = NO;

	foreach (manifest, options)
	{

		[gui setArray:[NSArray arrayWithObjects:
								   oo::PListView(manifest).get<NSString *>(kOOManifestCategory, DESC(@"oolite-oxzmanager-missing-field")),
							   oo::PListView(manifest).get<NSString *>(kOOManifestTitle, DESC(@"oolite-oxzmanager-missing-field")),
							   oo::PListView(manifest).get<NSString *>(kOOManifestVersion, DESC(@"oolite-oxzmanager-missing-field")),
									nil] forRow:row];
		NSString *identifier = oo::PListView(manifest).get<NSString *>(kOOManifestIdentifier);
		[gui setKey:identifier forRow:row];
		
		[gui setColor:[self colorForManifest:oo::PListFrom(manifest)] forRow:row];
		
		if (row == [gui selectedRow])
		{
			[gui setText:oo::NSStringOrNil([self installStatusForManifest:oo::PListFrom(manifest)]) forRow:OXZ_GUI_ROW_LISTSTATUS];
			[gui setColor:[OOColor greenColor] forRow:OXZ_GUI_ROW_LISTSTATUS];

			[gui addLongText:oo::PListView([oo::PListView(manifest).get<NSString *>(kOOManifestDescription) componentsSeparatedByString:@"\n"]).at<NSString *>(0) startingAtRow:OXZ_GUI_ROW_LISTDESC align:GUI_ALIGN_LEFT];
			
			oxzSelected = YES;
		}
		row++;
	}

	if (!oxzSelected)
	{
		[gui addLongText:DESC(@"oolite-oxzmanager-remover-nonepicked") startingAtRow:OXZ_GUI_ROW_LISTDESC align:GUI_ALIGN_LEFT];
	}

	return startRow;	
}


- (void) showOptionsUpdate
{

	if (_interfaceState == OXZ_STATE_PICK_INSTALL)
	{
		[self setFilteredList:[self applyCurrentFilter:_oxzList]];
		[self showInstallOptions];
	}
	else if (_interfaceState == OXZ_STATE_PICK_INSTALLED)
	{
		[self setFilteredList:[self applyCurrentFilter:[self managedOXZs]]];
		[self showInstallOptions];
	}
	else if (_interfaceState == OXZ_STATE_PICK_REMOVE)
	{
		[self setFilteredList:[self applyCurrentFilter:[self managedOXZs]]];
		[self showRemoveOptions];
	}
	// else nothing necessary
}


- (void) showOptionsPrev
{
	GuiDisplayGen	*gui = [UNIVERSE gui];
	if (_interfaceState == OXZ_STATE_PICK_INSTALL || _interfaceState == OXZ_STATE_PICK_REMOVE || _interfaceState == OXZ_STATE_PICK_INSTALLED)
	{
		if ([gui selectedRow] == OXZ_GUI_ROW_LISTPREV)
		{
			[self processSelection];
		}
	}
}


- (void) processOptionsPrev
{
	if (_offset < OXZ_GUI_NUM_LISTROWS)  
	{
		_offset = 0;
	}
	else
	{
		_offset -= OXZ_GUI_NUM_LISTROWS;
	}
	[self showOptionsUpdate];
}


- (void) processOptionsNext
{
	if (_offset + OXZ_GUI_NUM_LISTROWS < _filteredList.count())
	{
		_offset += OXZ_GUI_NUM_LISTROWS;
	}
	[self showOptionsUpdate];
	return;
}


- (void) showOptionsNext
{
	GuiDisplayGen	*gui = [UNIVERSE gui];
	if (_interfaceState == OXZ_STATE_PICK_INSTALL || _interfaceState == OXZ_STATE_PICK_REMOVE || _interfaceState == OXZ_STATE_PICK_INSTALLED)
	{
		if ([gui selectedRow] == OXZ_GUI_ROW_LISTNEXT)
		{
			[self processSelection];
		}
	}
}


- (NSString *) extractOXZ:(NSUInteger)item
{
	NSFileManager *fmgr 			= [NSFileManager defaultManager];
	NSMutableString *extractionLog	= [[NSMutableString alloc] init];
	NSDictionary *manifest 			= oo::ObjectFromPList(ElementAt(_filteredList, item));
	NSString *version 				= oo::PListView(manifest).get<NSString *>(kOOManifestVersion);
	NSString *identifier 			= oo::PListView(manifest).get<NSString *>(kOOManifestIdentifier);
	NSString *path 					= oo::NSStringOrNil([self extractionBasePathForIdentifier:oo::DescriptionOf(identifier) andVersion:oo::DescriptionOf(version)]);

	// OXZ errors should really never happen unless someone is messing
	// directly with the managed folder while Oolite is running, but
	// it's possible.

	NSString *oxzfile = oo::PListView(manifest).get<NSString *>(kOOManifestFilePath);
	if (![fmgr fileExistsAtPath:oxzfile])
	{
		OOLog(kOOOXZErrorLog,@"OXZ %@ could not be found",oxzfile);
		[extractionLog appendString:DESC(@"oolite-oxzmanager-extract-log-no-original")];
		return [extractionLog autorelease];
	}
	const char* zipname = [oxzfile UTF8String];
	unzFile uf = NULL;
	uf = unzOpen64(zipname);
	if (uf == NULL)
	{
		OOLog(kOOOXZErrorLog,@"Could not open .oxz at %@ as zip file",path);
		[extractionLog appendString:DESC(@"oolite-oxzmanager-extract-log-bad-original")];
		return [extractionLog autorelease];
	}	

	if ([fmgr fileExistsAtPath:path])
	{
		OOLog(kOOOXZErrorLog,@"Path %@ already exists",path);
		[extractionLog appendString:DESC(@"oolite-oxzmanager-extract-log-main-exists")];
		unzClose(uf);
		return [extractionLog autorelease];
	}
	if (![fmgr oo_createDirectoryAtPath:path attributes:nil])
	{
		OOLog(kOOOXZErrorLog,@"Path %@ could not be created",path);
		[extractionLog appendString:DESC(@"oolite-oxzmanager-extract-log-main-unmakeable")];
		unzClose(uf);
		return [extractionLog autorelease];
	}
	[extractionLog appendString:DESC(@"oolite-oxzmanager-extract-log-main-created")];
	NSUInteger counter = 0;
	char rawComponentName[512];
	BOOL error = NO;
	unz_file_info64 file_info = {0};
	if (unzGoToFirstFile(uf) == UNZ_OK)
	{
		do 
		{
			unzGetCurrentFileInfo64(uf, &file_info,
									rawComponentName, 512,
									NULL, 0,
									NULL, 0);
			NSString *componentName = [NSString stringWithUTF8String:rawComponentName];
			if ([componentName hasSuffix:@"/"])
			{
				// folder
				if (![fmgr oo_createDirectoryAtPath:[path stringByAppendingPathComponent:componentName] attributes:nil])
				{
					OOLog(kOOOXZErrorLog,@"Subpath %@ could not be created",componentName);
					[extractionLog appendString:DESC(@"oolite-oxzmanager-extract-log-sub-failed")];
					error = YES;
					break;
				}
				else
				{
					OOLog(kOOOXZDebugLog,@"Subpath %@ created OK",componentName);
				}
			}
			else
			{
				// file
				// usually folder must now exist, but just in case...
				NSString *folder = [[path stringByAppendingPathComponent:componentName] stringByDeletingLastPathComponent];
				if ([folder length] > 0 && ![fmgr fileExistsAtPath:folder] && ![fmgr oo_createDirectoryAtPath:folder attributes:nil])
				{
					OOLog(kOOOXZErrorLog,@"Subpath %@ could not be created",folder);
					[extractionLog appendString:DESC(@"oolite-oxzmanager-extract-log-sub-failed")];
					error = YES;
					break;
				}
				

				// This is less efficient in memory use than just
				// streaming out of the ZIP file onto disk
				// but it makes error handling easier
				void *pool = objc_autoreleasePoolPush();
				NSData *tmp = [NSData oo_dataWithOXZFile:[oxzfile stringByAppendingPathComponent:componentName]];
				if (tmp == nil)
				{
					OOLog(kOOOXZErrorLog,@"Sub file %@ could not be extracted from the OXZ",componentName);
					[extractionLog appendString:DESC(@"oolite-oxzmanager-extract-log-sub-failed")];
					error = YES;
					objc_autoreleasePoolPop(pool);
					break;
				}
				else
				{
					if (![tmp writeToFile:[path stringByAppendingPathComponent:componentName] atomically:YES])
					{
						OOLog(kOOOXZErrorLog,@"Sub file %@ could not be created",componentName);
						[extractionLog appendString:DESC(@"oolite-oxzmanager-extract-log-sub-failed")];
						error = YES;
						objc_autoreleasePoolPop(pool);
						break;
					}
					else
					{
						++counter;
					}
				}
				objc_autoreleasePoolPop(pool);

			}
		}
		while (unzGoToNextFile(uf) == UNZ_OK);
	}
	unzClose(uf);

	if (!error)
	{
		[extractionLog appendFormat:DESC(@"oolite-oxzmanager-extract-log-num-u-extracted"),counter];
		[extractionLog appendFormat:DESC(@"oolite-oxzmanager-extract-log-extracted-to-@"),path];
	}

	return [extractionLog autorelease];
}




- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	_downloadStatus = OXZ_DOWNLOAD_RECEIVING;
	OOLog(kOOOXZDebugLog, @"%@", @"Download receiving");
	_downloadExpected = [response expectedContentLength];
	_downloadProgress = 0;
	DESTROY(_fileWriter);
	[[NSFileManager defaultManager] createFileAtPath:oo::NSStringOrNil([self downloadPath]) contents:nil attributes:nil];
	_fileWriter = [[NSFileHandle fileHandleForWritingAtPath:oo::NSStringOrNil([self downloadPath])] retain];
	if (_fileWriter == nil)
	{
		// file system is full or read-only or something
		OOLog(kOOOXZErrorLog, @"%@", @"Unable to create download file");
		[self cancelUpdate];
	}
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	OOLog(kOOOXZDebugLog,@"Downloaded %zu bytes",[data length]);
	[_fileWriter seekToEndOfFile];
	[_fileWriter writeData:data];
	_downloadProgress += [data length];
	[self gui]; // update GUI
#if OOLITE_WINDOWS
	/* Irritating fix to issue https://github.com/OoliteProject/oolite/issues/95
	 *
	 * The problem is that on MINGW, GNUStep makes all socket streams
	 * blocking, which causes problems with the run loop. Calling this
	 * method of the run loop forces it to execute all already
	 * scheduled items with a time in the past, before any more items
	 * are placed on it, which means that the main game update gets a
	 * chance to run.
	 *
	 * This stops the interface freezing - and Oolite appearing to
	 * have stopped responding to the OS - when downloading large
	 * (>20Mb) OXZ files.
	 *
	 * CIM 6 July 2014
	 *
	 * The game tick is no longer a run-loop timer, so GameController fires
	 * it (and the run loop's own due timers) here, as the run loop did.
	 * Proposed ADR-0033.
	 */
	[[GameController sharedController] fireDueTimers];
#endif
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	_downloadStatus = OXZ_DOWNLOAD_COMPLETE;
	OOLog(kOOOXZDebugLog, @"%@", @"Download complete");
	[_fileWriter synchronizeFile];
	[_fileWriter closeFile];
	DESTROY(_fileWriter);
	DESTROY(_currentDownload);
	if (_interfaceState == OXZ_STATE_UPDATING)
	{
		if (![self processDownloadedManifests])
		{
			_downloadStatus = OXZ_DOWNLOAD_ERROR;
		}
	}
	else if (_interfaceState == OXZ_STATE_INSTALLING)
	{
		if (![self processDownloadedOXZ])
		{
			_downloadStatus = OXZ_DOWNLOAD_ERROR;
		}
	}
	else
	{
		OOLog(kOOOXZErrorLog,@"Error: download completed in unexpected state %d. This is an internal error - please report it.",_interfaceState);
		_downloadStatus = OXZ_DOWNLOAD_ERROR;
	}
}


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	_downloadStatus = OXZ_DOWNLOAD_ERROR;
	OOLog(kOOOXZErrorLog,@"Error downloading file: %@",[error description]);
	[_fileWriter closeFile];
	DESTROY(_fileWriter);
	DESTROY(_currentDownload);
}




@end

