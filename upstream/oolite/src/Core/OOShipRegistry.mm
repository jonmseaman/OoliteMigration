/*

OOShipRegistry.m


Copyright (C) 2008-2013 Jens Ayton and contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

#import "OOShipRegistry.h"
#import "OOCacheManager.h"
#import "ResourceManager.h"
#import "OOPListView.h"
#import "NSDictionaryOOExtensions.h"
#import "OOProbabilitySet.h"
#import "OORoleSet.h"
#import "OOStringParsing.h"
#import "OOMesh.h"
#import "GameController.h"
#import "OOLegacyScriptWhitelist.h"
#import "OODeepCopy.h"
#import "OOColor.h"
#import "OOStringExpander.h"
#import "OOShipLibraryDescriptions.h"
#import "Universe.h"
#import "OOJSScript.h"

#import "OODebugStandards.h"
#import "OOFoundationBridge.h"

#include "oofnd/StdLib.hpp"

#define PRELOAD 0


static void DumpStringAddrs(NSDictionary *dict, NSString *context);


static OOShipRegistry	*sSingleton = nil;


namespace {

constexpr const char *kRoleWeightsCacheKey			= "role weights";
constexpr const char *kDefaultDemoShip				= "coriolis-station";

// OOCacheManager caches and keys.
constexpr const char *kShipRegistryCacheName			= "ship registry";
constexpr const char *kShipDataCacheKey				= "ship data";
constexpr const char *kPlayerShipsCacheKey			= "player ships";
constexpr const char *kVisualEffectRegistryCacheName	= "visual effect registry";
constexpr const char *kVisualEffectDataCacheKey		= "visual effect data";


// A dictionary entry as the string extractor (oo_stringForKey:) answered it: nullopt where that
// was nil (no dictionary, no such key, or neither a string nor a number).
std::optional<std::string> StringForKey(const oo::PList *dict, const std::string &key)
{
	const oo::PList *value = dict != nullptr ? dict->find(key) : nullptr;
	if (value == nullptr || !(value->isString() || value->isNumber()))  return std::nullopt;
	return dict->get<std::string>(key);
}



// get<Vector> / get<Quaternion>: OOCollectionExtractors' readers (unmigrated) of the value,
// handed back to them as a Foundation object; the defaults of a missing key are theirs.
Vector VectorForKey(const oo::PList &dict, const char *key)
{
	const oo::PList *value = dict.find(key);
	return OOVectorFromObject(value != nullptr ? oo::ObjectFromPList(*value) : nil, kZeroVector);
}


Quaternion QuaternionForKey(const oo::PList &dict, const char *key)
{
	const oo::PList *value = dict.find(key);
	return OOQuaternionFromObject(value != nullptr ? oo::ObjectFromPList(*value) : nil, kIdentityQuaternion);
}


// oo_setVector: / oo_setQuaternion:: OOPropertyListFromVector / OOPropertyListFromQuaternion's
// dictionaries (float components), as property lists.
oo::PList VectorPList(Vector value)
{
	return oo::PListFrom(OOPropertyListFromVector(value));
}


oo::PList QuaternionPList(Quaternion value)
{
	return oo::PListFrom(OOPropertyListFromQuaternion(value));
}


// The first token of a string, as [ScanTokensFromString(s) objectAtIndex:0] read it: an empty
// token list raised.
std::string FirstToken(const std::vector<std::string> &tokens)
{
	if (tokens.empty())
	{
		[NSException raise:NSRangeException format:@"Index 0 is out of range 0 (in 'objectAtIndex:')"];
	}
	return tokens[0];
}


// The tokens joined by single spaces (-componentsJoinedByString:@" ").
std::string JoinTokens(const std::vector<std::string> &tokens)
{
	std::string joined;
	for (std::size_t i = 0; i != tokens.size(); ++i)
	{
		if (i != 0)  joined += ' ';
		joined += tokens[i];
	}
	return joined;
}

}	// namespace


@interface OOShipRegistry (OODataLoader)

- (void) loadShipData;
- (void) loadDemoShipConditions;
- (void) loadDemoShips;
- (void) loadCachedRoleProbabilitySets;
- (void) buildRoleProbabilitySets;

- (BOOL) applyLikeShips:(NSMutableDictionary *)ioData withKey:(NSString *)likeKey;
- (BOOL) loadAndMergeShipyard:(NSMutableDictionary *)ioData;
- (BOOL) stripPrivateKeys:(NSMutableDictionary *)ioData;
- (BOOL) makeShipEntriesMutable:(NSMutableDictionary *)ioData;
- (BOOL) loadAndApplyShipDataOverrides:(NSMutableDictionary *)ioData;
- (BOOL) canonicalizeAndTagSubentities:(NSMutableDictionary *)ioData;
- (BOOL) removeUnusableEntries:(NSMutableDictionary *)ioData shipMode:(BOOL)shipMode;
- (BOOL) sanitizeConditions:(NSMutableDictionary *)ioData;

#if PRELOAD
- (BOOL) preloadShipMeshes:(NSMutableDictionary *)ioData;
#endif

- (NSMutableDictionary *) mergeShip:(NSDictionary *)child withParent:(NSDictionary *)parent;
- (void) mergeShipRoles:(const std::string &)roles forShipKey:(const std::string &)shipKey intoProbabilityMap:(std::map<std::string, oo::ObjCRef<OOMutableProbabilitySet *>, std::less<>> &)probabilitySets;

// Declarations and ship data are property lists; a result is a declaration dictionary, or a
// null PList where it was nil.
- (oo::PList) canonicalizeSubentityDeclaration:(const oo::PList &)declaration
									   forShip:(const std::string &)shipKey
									  shipData:(const oo::PList &)shipData
									fatalError:(BOOL *)outFatalError;
- (oo::PList) translateOldStyleSubentityDeclaration:(const std::string &)declaration
											forShip:(const std::string &)shipKey
										   shipData:(const oo::PList &)shipData
										 fatalError:(BOOL *)outFatalError;
- (oo::PList) translateOldStyleFlasherDeclaration:(const oo::PList &)tokens
										  forShip:(const std::string &)shipKey
									   fatalError:(BOOL *)outFatalError;
- (oo::PList) translateOldStandardBasicSubentityDeclaration:(const oo::PList &)tokens
													forShip:(const std::string &)shipKey
												   shipData:(const oo::PList &)shipData
												 fatalError:(BOOL *)outFatalError;
- (oo::PList) validateNewStyleSubentityDeclaration:(const oo::PList &)declaration
										   forShip:(const std::string &)shipKey
										fatalError:(BOOL *)outFatalError;
- (oo::PList) validateNewStyleFlasherDeclaration:(const oo::PList &)declaration
										 forShip:(const std::string &)shipKey
									  fatalError:(BOOL *)outFatalError;
- (oo::PList) validateNewStyleStandardSubentityDeclaration:(const oo::PList &)declaration
												   forShip:(const std::string &)shipKey
												fatalError:(BOOL *)outFatalError;

- (BOOL) shipIsBallTurretForKey:(const std::string &)shipKey inShipData:(const oo::PList &)shipData;

@end


@implementation OOShipRegistry

+ (OOShipRegistry *) sharedRegistry
{
	if (sSingleton == nil)
	{
		sSingleton = [[self alloc] init];
	}
	
	return sSingleton;
}


+ (void) reload
{
	if (sSingleton != nil)
	{
		/* CIM: 'release' doesn't work - the class definition
		 * overrides it, so this leaks memory. Needs a proper reset
		 * method for reloading the ship registry data instead */
		[sSingleton release];
		sSingleton = nil;
		
		(void) [self sharedRegistry];
	}
}


- (id) init
{
	if ((self = [super init]))
	{
		@autoreleasepool
		{
			OOCacheManager			*cache = [OOCacheManager sharedCache];

			// OOCacheManager holds Foundation objects (an unmigrated callee): they arrive through oo::PListFrom.
			_shipData = oo::PListFrom([cache cxx_objectForKey:kShipDataCacheKey inCache:kShipRegistryCacheName]);
			_playerShips = oo::StringsFrom([cache cxx_objectForKey:kPlayerShipsCacheKey inCache:kShipRegistryCacheName]);
			_effectData = oo::PListFrom([cache cxx_objectForKey:kVisualEffectDataCacheKey inCache:kVisualEffectRegistryCacheName]);
			if (_shipData.count() == 0)	// Don't accept nil or empty
			{
				[self loadShipData];
				if (_shipData.count() == 0)
				{
					[NSException raise:@"OOShipRegistryLoadFailure" format:@"Could not load any ship data."];
				}
				if (_playerShips.empty())
				{
					[NSException raise:@"OOShipRegistryLoadFailure" format:@"Could not load any player ships."];
				}
			}
			
			[self loadDemoShipConditions];
			[self loadDemoShips]; // testing only
			if (_demoShips.count() == 0)
			{
				[NSException raise:@"OOShipRegistryLoadFailure" format:@"Could not load or synthesize any demo ships."];
			}
			
			[self loadCachedRoleProbabilitySets];
			if (!_probabilitySets.has_value())
			{
				[self buildRoleProbabilitySets];
				if (_probabilitySets->empty())
				{
					[NSException raise:@"OOShipRegistryLoadFailure" format:@"Could not load or synthesize role probability sets."];
				}
			}
		}
	}
	return self;
}


- (void) dealloc
{

	[super dealloc];
}


- (oo::PList) cxx_shipInfoForKey:(const std::string &)key
{
	const oo::PList *entry = _shipData.find(key);
	return entry != nullptr ? *entry : oo::PList();
}


- (void) cxx_setShipInfoForKey:(const std::string &)key with:(const oo::PList &)newShipData
{
	// A value copy (it was a deep copy into a rebuilt dictionary).
	if (!_shipData.isDict())  _shipData = oo::PList(oo::PList::Dict());
	(*_shipData.getIf<oo::PList::Dict>())[key] = newShipData;
}


- (oo::PList) cxx_effectInfoForKey:(const std::string &)key
{
	const oo::PList *entry = _effectData.find(key);
	return entry != nullptr ? *entry : oo::PList();
}


- (oo::PList) cxx_shipyardInfoForKey:(const std::string &)key
{
	const oo::PList *entry = _shipData.find(key);
	const oo::PList *shipyard = entry != nullptr ? entry->find("_oo_shipyard") : nullptr;
	return shipyard != nullptr ? *shipyard : oo::PList();
}


- (OOProbabilitySet *) cxx_probabilitySetForRole:(const std::string &)role
{
	if (!_probabilitySets.has_value())  return nil;
	auto set = _probabilitySets->find(role);
	return set != _probabilitySets->end() ? set->second.get() : nil;
}


- (oo::PList) cxx_demoShipKeys
{
	// with condition scripts in use, can't cache this value
	[self loadDemoShips];

	return _demoShips;
}


- (std::vector<std::string>) cxx_playerShipKeys
{
	return _playerShips;
}

@end


@implementation OOShipRegistry (OOConveniences)

- (std::vector<std::string>) cxx_shipKeys
{
	std::vector<std::string> keys;
	if (const oo::PList::Dict *ships = _shipData.getIf<oo::PList::Dict>())
	{
		keys.reserve(ships->size());
		for (const auto &[shipKey, shipEntry] : *ships)  keys.push_back(shipKey);
	}
	return keys;
}

- (std::vector<std::string>) cxx_shipRoles
{
	std::vector<std::string> roles;
	if (_probabilitySets.has_value())
	{
		roles.reserve(_probabilitySets->size());
		for (const auto &[role, set] : *_probabilitySets)  roles.push_back(role);
	}
	return roles;
}

- (std::vector<std::string>) cxx_shipKeysWithRole:(const std::string &)role
{
	// OOProbabilitySet is an unmigrated callee: its objects (ship keys) arrive through oo::StringsFrom.
	return oo::StringsFrom([[self cxx_probabilitySetForRole:role] allObjects]);
}


- (std::optional<std::string>) cxx_randomShipKeyForRole:(const std::string &)role
{
	return oo::OptionalString([[self cxx_probabilitySetForRole:role] randomObject]);
}

@end


@implementation OOShipRegistry (OODataLoader)

/*	-loadShipData
	
	Load the data for all ships. This consists of five stages:
		* Load merges shipdata.plist dictionary.
		* Apply all like_ship entries.
		* Load shipdata-overrides.plist and apply patches.
		* Load shipyard.plist, add shipyard data into ship dictionaries, and
		  create _playerShips array.
		* Build role->ship type probability sets.
*/
- (void) loadShipData
{
	NSMutableDictionary		*result = nil;

	_shipData = oo::PList();
	_playerShips.clear();

	// Load shipdata.plist.
	result = [[[ResourceManager dictionaryFromFilesNamed:@"shipdata.plist"
												inFolder:@"Config"
											   mergeMode:MERGE_BASIC
												   cache:NO] mutableCopy] autorelease];
	if (result == nil)  return;
	
	DumpStringAddrs(result, @"shipdata.plist");
	
	// Make each entry mutable to simplify later stages. Also removes any entries that aren't dictionaries.
	if (![self makeShipEntriesMutable:result])  return;
	OOLog(@"shipData.load.progress", @"%@", @"Finished initial cleanup...");
	
	// Apply patches.
	if (![self loadAndApplyShipDataOverrides:result])  return;
	OOLog(@"shipData.load.progress", @"%@", @"Finished applying patches...");
	
	// Strip private keys (anything starting with _oo_).
	if (![self stripPrivateKeys:result])  return;
	OOLog(@"shipData.load.progress", @"%@", @"Finished stripping private keys...");
	
	// Resolve like_ship entries.
	if (![self applyLikeShips:result withKey:@"like_ship"])  return;
	OOLog(@"shipData.load.progress", @"%@", @"Finished resolving like_ships...");
	
	// Clean up subentity declarations and tag subentities so they won't be pruned.
	if (![self canonicalizeAndTagSubentities:result])  return;
	OOLog(@"shipData.load.progress", @"%@", @"Finished cleaning up subentities...");
	
	// Clean out templates and invalid entries.
	if (![self removeUnusableEntries:result shipMode:YES])  return;
	OOLog(@"shipData.load.progress", @"%@", @"Finished removing invalid entries...");
	
	// Add shipyard entries into shipdata entries.
	if (![self loadAndMergeShipyard:result])  return;
	OOLog(@"shipData.load.progress", @"%@", @"Finished adding shipyard entries...");
	
	// Sanitize conditions.
	if (![self sanitizeConditions:result])  return;
	OOLog(@"shipData.load.progress", @"%@", @"Finished validating data...");
	
#if PRELOAD
	// Preload and cache meshes.
	if (![self preloadShipMeshes:result])  return;
	OOLog(@"shipData.load.progress", @"%@", @"Finished loading meshes...");
#endif
	
	// A value (deep) copy; the cache (an unmigrated callee) gets it back as Foundation objects.
	_shipData = oo::PListFrom(result);
	[[OOCacheManager sharedCache] cxx_setObject:oo::ObjectFromPList(_shipData) forKey:kShipDataCacheKey inCache:kShipRegistryCacheName];

	OOLog(@"shipData.load.done", @"%@", @"Ship data loaded.");

	_effectData = oo::PList();

	result = [[[ResourceManager dictionaryFromFilesNamed:@"effectdata.plist"
												inFolder:@"Config"
											   mergeMode:MERGE_BASIC
												   cache:NO] mutableCopy] autorelease];
	if (result == nil)  return;

	// Make each entry mutable to simplify later stages. Also removes any entries that aren't dictionaries.
	if (![self makeShipEntriesMutable:result])  return;
	OOLog(@"effectData.load.progress", @"%@", @"Finished initial cleanup...");

	// Strip private keys (anything starting with _oo_).
	if (![self stripPrivateKeys:result])  return;
	OOLog(@"effectData.load.progress", @"%@", @"Finished stripping private keys...");
	
	// Resolve like_effect entries.
	if (![self applyLikeShips:result withKey:@"like_effect"])  return;
	OOLog(@"effectData.load.progress", @"%@", @"Finished resolving like_effects...");
	
	// Clean up subentity declarations and tag subentities so they won't be pruned.
	if (![self canonicalizeAndTagSubentities:result])  return;
	OOLog(@"effectData.load.progress", @"%@", @"Finished cleaning up subentities...");
	
	// Clean out templates and invalid entries.
	if (![self removeUnusableEntries:result shipMode:NO])  return;
	OOLog(@"effectData.load.progress", @"%@", @"Finished removing invalid entries...");
	
	_effectData = oo::PListFrom(result);
	[[OOCacheManager sharedCache] cxx_setObject:oo::ObjectFromPList(_effectData) forKey:kVisualEffectDataCacheKey inCache:kVisualEffectRegistryCacheName];

	OOLog(@"effectData.load.done", @"%@", @"Effect data loaded.");
}


- (void) loadDemoShipConditions
{
	std::vector<std::string>	conditionScripts;

	// ResourceManager's loader and OOCacheManager are unmigrated callees: convert at the calls.
	const oo::PList initialDemoShips = oo::PListFrom([ResourceManager arrayFromFilesNamed:@"shiplibrary.plist"
																				   inFolder:@"Config"
																				   andMerge:YES
																					  cache:NO]);

	if (const oo::PList::Array *entries = initialDemoShips.getIf<oo::PList::Array>())
	{
		for (const oo::PList &key : *entries)
		{
			std::optional<std::string> conditions = StringForKey(&key, kOODemoShipConditions);
			if (conditions.has_value())
			{
				conditionScripts.push_back(std::move(*conditions));
			}
		}
	}

	[[OOCacheManager sharedCache] cxx_setObject:oo::NSArrayFromStrings(conditionScripts) forKey:"demoship conditions" inCache:"condition scripts"];
}


/*	-loadDemoShips
	
	Load demoships.plist, and filter out non-existent ships. If no existing
	ships remain, try adding coriolis; if this fails, add any ship in
	shipdata.
*/
- (void) loadDemoShips
{
	_demoShips = oo::PList();

	// ResourceManager's loader is an unmigrated callee: its array arrives through oo::PListFrom.
	const oo::PList initialDemoShips = oo::PListFrom([ResourceManager arrayFromFilesNamed:@"shiplibrary.plist"
																				   inFolder:@"Config"
																				   andMerge:YES
																					  cache:NO]);
	const oo::PList::Array noShips;
	const oo::PList::Array &initialEntries = initialDemoShips.isArray() ? *initialDemoShips.getIf<oo::PList::Array>() : noShips;
	oo::PList::Array demoShips = initialEntries;
	// -removeObject: took every equal entry out
	auto removeEntry = [&demoShips](const oo::PList &entry)
	{
		demoShips.erase(std::remove(demoShips.begin(), demoShips.end(), entry), demoShips.end());
	};

	// Note: iterate over initialDemoShips to avoid mutating the collection being enu,erated.
	for (const oo::PList &key : initialEntries)
	{
		const std::optional<std::string> shipKey = StringForKey(&key, kOODemoShipKey);
		if (!key.isDict() || !shipKey.has_value() || _shipData.find(*shipKey) == nullptr)
		{
			removeEntry(key);
		}
		else
		{
			const std::optional<std::string> conditions = StringForKey(&key, kOODemoShipConditions);
			if (conditions.has_value())
			{
				if ([PLAYER status] == STATUS_START_GAME)
				{
					// conditions always false here
					removeEntry(key);
				}
				else
				{
					OOJSScript *condScript = [UNIVERSE getConditionScript:oo::NSStringFrom(*conditions)];
					if (condScript != nil) // should always be non-nil, but just in case
					{
						ooscript::Context context = OOJSAcquireContext();
						BOOL OK;
						bool allow_use;
						ooscript::Value result;
						ooscript::Value args[] = { OOJSValueFromNativeObject(context, oo::NSStringFrom(*shipKey)) };

						OK = [condScript callMethod:OOJSID("allowShowLibraryShip")
										  inContext:context
									  withArguments:args count:sizeof args / sizeof *args
											 result:&result];

						if (OK) OK = ooscript::valueToBoolean(context, result, &allow_use);

						OOJSRelinquishContext(context);
						if (OK && !allow_use)
						{
							/* if the script exists, the function exists, the function
							 * returns a bool, and that bool is false, hide the
							 * ship. Otherwise allow it as default */
							removeEntry(key);
						}
					}
				}
			}
		}
	}

	if (demoShips.empty())
	{
		std::string shipKey;
		if (_shipData.find(kDefaultDemoShip) != nullptr)
		{
			shipKey = kDefaultDemoShip;
		}
		else
		{
			shipKey = _shipData.getIf<oo::PList::Dict>()->begin()->first;	// the first key in key order (was hash order)
		}
		oo::PList::Dict entry;
		entry.emplace(kOODemoShipKey, shipKey);
		demoShips.emplace_back(std::move(entry));
	}

	// now separate out the demoships by class, and add some extra keys
	std::map<std::string, oo::PList::Array, std::less<>> demoList;
	for (const oo::PList &key : demoShips)
	{
		std::string klass = key.get<std::string>(kOODemoShipClass, "ship");
		if (OOShipLibraryCategoryPlural(klass).empty())
		{
			OOLog(@"shipdata.load.warning",@"Unexpected class '%@' in shiplibrary.plist for '%@'",oo::NSStringFrom(klass),oo::NSStringOrNil(StringForKey(&key, kOODemoShipKey)));
			klass = "ship";
		}
		oo::PList::Array &demoClass = demoList[klass];
		oo::PList demoEntry = key;
		oo::PList::Dict &demoEntryValues = *demoEntry.getIf<oo::PList::Dict>();
		// add "name" object to dictionary from ship definition
		const std::optional<std::string> name = StringForKey(_shipData.find(demoEntry.get<std::string>("ship")), kOODemoShipName);
		if (!name.has_value())
		{
			// -setObject:nil forKey: raised
			[NSException raise:NSInvalidArgumentException format:@"Tried to add nil value for key '%s' to dictionary", kOODemoShipName];
		}
		demoEntryValues[kOODemoShipName] = *name;
		// set "class" object to standard ship if not otherwise set
		if (StringForKey(&demoEntry, kOODemoShipClass) != klass)
		{
			demoEntryValues[kOODemoShipClass] = klass;
		}
		demoClass.push_back(std::move(demoEntry));
	}
	// sort each ship list by name (-compare:)
	oo::PList::Array categories;
	categories.reserve(demoList.size());
	for (auto &[demoClassName, demoClass] : demoList)
	{
		std::stable_sort(demoClass.begin(), demoClass.end(), [](const oo::PList &a, const oo::PList &b)
		{
			return oo::str::compare(a.get<std::string>("name"), b.get<std::string>("name")) < 0;
		});
		categories.emplace_back(std::move(demoClass));
	}

	// and then sort the ship list list by class name (the plural category name, -compare:)
	std::stable_sort(categories.begin(), categories.end(), [](const oo::PList &a, const oo::PList &b)
	{
		return oo::str::compare(OOShipLibraryCategoryPlural(a.at(0)->get<std::string>("class")), OOShipLibraryCategoryPlural(b.at(0)->get<std::string>("class"))) < 0;
	});
	_demoShips = oo::PList(std::move(categories));
}


- (void) loadCachedRoleProbabilitySets
{
	// OOCacheManager and OOProbabilitySet are unmigrated callees: convert at the calls.
	const oo::PList cachedSets = oo::PListFrom([[OOCacheManager sharedCache] cxx_objectForKey:kRoleWeightsCacheKey inCache:kShipRegistryCacheName]);
	if (cachedSets.isNull())  return;

	std::map<std::string, oo::ObjCRef<OOProbabilitySet *>, std::less<>> restoredSets;
	if (const oo::PList::Dict *sets = cachedSets.getIf<oo::PList::Dict>())
	{
		for (const auto &[role, representation] : *sets)
		{
			restoredSets[role] = oo::ObjCRef<OOProbabilitySet *>([OOProbabilitySet probabilitySetWithPropertyListRepresentation:oo::ObjectFromPList(representation)]);
		}
	}

	_probabilitySets = std::move(restoredSets);
}


- (void) buildRoleProbabilitySets
{
	std::map<std::string, oo::ObjCRef<OOMutableProbabilitySet *>, std::less<>>	probabilitySets;

	// Build role sets (ships in key order; was hash order)
	if (const oo::PList::Dict *ships = _shipData.getIf<oo::PList::Dict>())
	{
		for (const auto &[shipKey, shipEntry] : *ships)
		{
			[self mergeShipRoles:StringForKey(&shipEntry, "roles").value_or("") forShipKey:shipKey intoProbabilityMap:probabilitySets];
		}
	}

	// Convert role sets to immutable form, and build cache entry.
	std::map<std::string, oo::ObjCRef<OOProbabilitySet *>, std::less<>>	sets;
	oo::PList::Dict		cacheEntry;
	for (const auto &[role, mutableSet] : probabilitySets)
	{
		OOProbabilitySet *pset = [[mutableSet.get() copy] autorelease];
		sets[role] = oo::ObjCRef<OOProbabilitySet *>(pset);
		// OOProbabilitySet is an unmigrated callee (its weights are floats: single reals, written to disk)
		cacheEntry[role] = oo::PListFrom([pset propertyListRepresentation]);
	}

	_probabilitySets = std::move(sets);
	[[OOCacheManager sharedCache] cxx_setObject:oo::ObjectFromPList(oo::PList(std::move(cacheEntry))) forKey:kRoleWeightsCacheKey inCache:kShipRegistryCacheName];
}


/*	-applyLikeShips:
	
	Implement like_ship by copying inherited ship and overwriting with child
	ship values. Done iteratively to report recursive references of arbitrary
	depth. Also removes and reports ships whose like_ship entry does not
	resolve, and handles reference loops by removing all ships involved.
 
	We start with a set of keys all ships that have a like_ships entry. In
	each iteration, every ship whose like_ship entry does not refer to a ship
	which itself has a like_ship entry is finalized. If the set of pending
	ships does not shrink in an iteration, the remaining ships cannot be
	resolved (either their like_ships do not exist, or they form reference
	cycles) so we stop looping and report it.
*/
- (BOOL) applyLikeShips:(NSMutableDictionary *)ioData withKey:(NSString *)likeKey
{
	NSMutableSet			*remainingLikeShips = nil;
	NSString				*key = nil;
	NSString				*parentKey = nil;
	NSDictionary			*shipEntry = nil;
	NSDictionary			*parentEntry = nil;
	NSUInteger				count, lastCount;
	NSMutableArray			*reportedBadShips = nil;
	
	// Build set of ships with like_ship references
	remainingLikeShips = [NSMutableSet set];
	foreachkey (key, ioData)
	{
		shipEntry = [ioData objectForKey:key];
		if (oo::PListView(shipEntry).get<NSString *>(likeKey) != nil)
		{
			[remainingLikeShips addObject:key];
		}
	}
	
	count = lastCount = [remainingLikeShips count];
	while (count != 0)
	{
		foreach (key, [[remainingLikeShips copy] autorelease])
		{
			// Look up like_ship entry
			shipEntry = [ioData objectForKey:key];
			parentKey = [shipEntry objectForKey:likeKey];
			if (![remainingLikeShips containsObject:parentKey])
			{
				// If parent is fully resolved, we can resolve this child.
				parentEntry = [ioData objectForKey:parentKey];
				shipEntry = [self mergeShip:shipEntry withParent:parentEntry];
				if (shipEntry != nil)
				{
					[remainingLikeShips removeObject:key];
					[ioData setObject:shipEntry forKey:key];
				}
			}
		}
		
		count = [remainingLikeShips count];
		if (count == lastCount)
		{
			/*	Fail: we couldn't resolve all like_ship entries.
				Remove unresolved entries, building a list of the ones that
				don't have is_external_dependency set.
			*/
			reportedBadShips = [NSMutableArray array];
			foreach (key, remainingLikeShips)
			{
				if (!oo::PListView(oo::PListView(ioData).get<NSDictionary *>(key)).get<BOOL>(@"is_external_dependency"))
				{
					[reportedBadShips addObject:key];
				}
				[ioData removeObjectForKey:key];
			}
			
			if ([reportedBadShips count] != 0)
			{
				[reportedBadShips sortUsingSelector:@selector(caseInsensitiveCompare:)];
				OOLogERR(@"shipData.merge.failed", @"one or more shipdata.plist entries have %@ references that cannot be resolved: %@", likeKey, [reportedBadShips componentsJoinedByString:@", "]); // FIXME: distinguish shipdata and effectdata
				OOStandardsError(@"Likely missing a dependency in a manifest.plist");
			}
			break;
		}
		lastCount = count;
	}
	
	return YES;
}


- (NSMutableDictionary *) mergeShip:(NSDictionary *)child withParent:(NSDictionary *)parent
{
	NSMutableDictionary *result = [[parent mutableCopy] autorelease];
	if (result == nil)  return nil;
	
	[result addEntriesFromDictionary:child];
	[result removeObjectForKey:@"like_ship"];
	
	// Certain properties cannot be inherited.
	if (oo::PListView(child).get<NSString *>(@"display_name") == nil)  [result removeObjectForKey:@"display_name"];
	if (oo::PListView(child).get<NSString *>(@"is_template") == nil)  [result removeObjectForKey:@"is_template"];
	
	// Since both 'scanClass' and 'scan_class' are accepted as valid keys for the scanClass property,
	// we may end up with conflicting scanClass and scan_class keys from like_ship relationships getting
	// merged in the result dictionary. We want to always have the child overriding the parent setting
	// and we do that by determining which of the two keys belongs to the child dictionary and removing
	// the other one from the result - Nikos 20100512
	if (oo::PListView(result).get<NSString *>(@"scan_class") != nil && oo::PListView(result).get<NSString *>(@"scanClass") != nil)
	{
		if (oo::PListView(child).get<NSString *>(@"scanClass") != nil)
			[result removeObjectForKey:@"scan_class"];
		else
			[result removeObjectForKey:@"scanClass"];
	}
	// TODO: all normalised/non-normalised value name pairs need to be catered for. - Kaks 2010-05-13
	if (oo::PListView(result).get<NSString *>(@"escort_role") != nil && oo::PListView(result).get<NSString *>(@"escort-role") != nil)
	{
		if (oo::PListView(child).get<NSString *>(@"escort-role") != nil)
			[result removeObjectForKey:@"escort_role"];
		else
			[result removeObjectForKey:@"escort-role"];
	}
	if (oo::PListView(result).get<NSString *>(@"escort_ship") != nil && oo::PListView(result).get<NSString *>(@"escort-ship") != nil)
	{
		if (oo::PListView(child).get<NSString *>(@"escort-ship") != nil)
			[result removeObjectForKey:@"escort_ship"];
		else
			[result removeObjectForKey:@"escort-ship"];
	}
	if (oo::PListView(result).get<NSString *>(@"is_carrier") != nil && oo::PListView(result).get<NSString *>(@"isCarrier") != nil)
	{
		if (oo::PListView(child).get<NSString *>(@"isCarrier") != nil)
			[result removeObjectForKey:@"is_carrier"];
		else
			[result removeObjectForKey:@"isCarrier"];
	}
	if (oo::PListView(result).get<NSString *>(@"has_shipyard") != nil && oo::PListView(result).get<NSString *>(@"hasShipyard") != nil)
	{
		if (oo::PListView(child).get<NSString *>(@"hasShipyard") != nil)
			[result removeObjectForKey:@"has_shipyard"];
		else
			[result removeObjectForKey:@"hasShipyard"];
	}	
	return result;
}


- (BOOL) makeShipEntriesMutable:(NSMutableDictionary *)ioData
{
	NSString				*shipKey = nil;
	NSDictionary			*shipEntry = nil;
	
	foreach (shipKey, [ioData allKeys])
	{
		shipEntry = [ioData objectForKey:shipKey];
		if (![shipEntry isKindOfClass:[NSDictionary class]])
		{
			OOLogERR(@"shipData.load.badEntry", @"the shipdata.plist entry \"%@\" is not a dictionary.", shipKey);
			[ioData removeObjectForKey:shipKey];
		}
		else
		{
			shipEntry = [shipEntry mutableCopy];
			
			[ioData setObject:shipEntry forKey:shipKey];
			[shipEntry release];
		}
	}
	
	return YES;
}


- (BOOL) loadAndApplyShipDataOverrides:(NSMutableDictionary *)ioData
{
	NSString				*shipKey = nil;
	NSMutableDictionary		*shipEntry = nil;
	NSDictionary			*overrides = nil;
	NSDictionary			*overridesEntry = nil;
	
	overrides = [ResourceManager dictionaryFromFilesNamed:@"shipdata-overrides.plist"
												 inFolder:@"Config"
												mergeMode:MERGE_SMART
													cache:NO];
	
	foreachkey (shipKey, overrides)
	{
		shipEntry = [ioData objectForKey:shipKey];
		if (shipEntry != nil)
		{
			overridesEntry = [overrides objectForKey:shipKey];
			if (![overridesEntry isKindOfClass:[NSDictionary class]])
			{
				OOLogERR(@"shipData.load.error", @"the shipdata-overrides.plist entry \"%@\" is not a dictionary.", shipKey);
			}
			else
			{
				[shipEntry addEntriesFromDictionary:overridesEntry];
			}
		}
	}
	
	return YES;
}


- (BOOL) stripPrivateKeys:(NSMutableDictionary *)ioData
{
	NSString				*shipKey = nil;
	NSMutableDictionary		*shipEntry = nil;
	NSEnumerator			*attrKeyEnum = nil;
	NSString				*attrKey = nil;
	
	foreachkey (shipKey, ioData)
	{
		shipEntry = [ioData objectForKey:shipKey];
		
		for (attrKeyEnum = [shipEntry keyEnumerator]; (attrKey = [attrKeyEnum nextObject]); )
		{
			if ([attrKey hasPrefix:@"_oo_"])
			{
				[shipEntry removeObjectForKey:attrKey];
			}
		}
	}
	
	return YES;
}


/*	-loadAndMergeShipyard:
	
	Load shipyard.plist, add its entries to appropriate shipyard entries as
	a dictionary under the key "shipyard", and build list of player ships.
	Before that, we strip out any "shipyard" entries already in shipdata, and
	apply any shipyard-overrides.plist stuff to shipyard.
*/
- (BOOL) loadAndMergeShipyard:(NSMutableDictionary *)ioData
{
	NSString				*shipKey = nil;
	NSMutableDictionary		*shipEntry = nil;
	NSDictionary			*shipyard = nil;
	NSDictionary			*shipyardOverrides = nil;
	NSDictionary			*shipyardEntry = nil;
	NSDictionary			*shipyardOverridesEntry = nil;
	NSMutableArray			*playerShips = nil;
	
	// Strip out any shipyard stuff in shipdata (there shouldn't be any).
	foreachkey (shipKey, ioData)
	{
		shipEntry = [ioData objectForKey:shipKey];
		if ([shipEntry objectForKey:@"_oo_shipyard"] != nil)
		{
			[shipEntry removeObjectForKey:@"_oo_shipyard"];
		}
	}
	
	shipyard = [ResourceManager dictionaryFromFilesNamed:@"shipyard.plist"
												inFolder:@"Config"
											   mergeMode:MERGE_BASIC
												   cache:NO];
	shipyardOverrides = [ResourceManager dictionaryFromFilesNamed:@"shipyard-overrides.plist"
														 inFolder:@"Config"
														mergeMode:MERGE_SMART
															cache:NO];
	
	playerShips = [NSMutableArray arrayWithCapacity:[shipyard count]];
	
	// Insert merged shipyard and shipyardOverrides entries.
	foreachkey (shipKey, shipyard)
	{
		shipEntry = [ioData objectForKey:shipKey];
		if (shipEntry != nil)
		{
			shipyardEntry = [shipyard objectForKey:shipKey];
			shipyardOverridesEntry = [shipyardOverrides objectForKey:shipKey];
			shipyardEntry = [shipyardEntry dictionaryByAddingEntriesFromDictionary:shipyardOverridesEntry];
			
			[shipEntry setObject:shipyardEntry forKey:@"_oo_shipyard"];
			
			[playerShips addObject:shipKey];
		}
		else
		{
			OOLogWARN(@"shipData.load.shipyard.unknown", @"the shipyard.plist entry \"%@\" does not have a corresponding shipdata.plist entry, ignoring.", shipKey);
		}
	}
	
	_playerShips = oo::StringsFrom(playerShips);
	[[OOCacheManager sharedCache] cxx_setObject:oo::NSArrayFromStrings(_playerShips) forKey:kPlayerShipsCacheKey inCache:kShipRegistryCacheName];
	
	return YES;
}


- (BOOL) canonicalizeAndTagSubentities:(NSMutableDictionary *)ioData
{
	NSString				*shipKey = nil;
	NSMutableDictionary		*shipEntry = nil;
	NSArray					*subentityDeclarations = nil;
	id						subentityDecl = nil;
	NSDictionary			*subentityDict = nil;
	NSString				*subentityKey = nil;
	NSMutableDictionary		*subentityShipEntry = nil;
	NSMutableSet			*badSubentities = nil;
	NSString				*badSubentitiesList = nil;
	NSMutableArray			*okSubentities = nil;
	BOOL					remove, fatal;
	
	// Convert all subentity declarations to dictionaries and add
	// _oo_is_subentity=YES to all entries used as subentities.
	
	// The declaration helpers take property lists: one snapshot of the ship data per call (they
	// read only "frangible" and "setup_actions", which this loop never writes).
	const oo::PList shipDataSnapshot = oo::PListFrom(ioData);

	// Iterate over all ships. (Iterates over a copy of keys since it mutates the dictionary.)
	foreach (shipKey, [ioData allKeys])
	{
		shipEntry = [ioData objectForKey:shipKey];
		remove = NO;
		badSubentities = nil;
		
		// Iterate over each subentity declaration of each ship
		subentityDeclarations = oo::PListView(shipEntry).get<NSArray *>(@"subentities");
		if (subentityDeclarations != nil)
		{
			okSubentities = [NSMutableArray arrayWithCapacity:[subentityDeclarations count]];
			foreach (subentityDecl, subentityDeclarations)
			{
				subentityDict = oo::ObjectFromPList([self canonicalizeSubentityDeclaration:oo::PListFrom(subentityDecl) forShip:oo::StdString(shipKey) shipData:shipDataSnapshot fatalError:&fatal]);
				
				// If entry is broken, we need to kill this ship.
				if (fatal)
				{
					OOStandardsError(@"Bad subentity definition found");
					remove = YES;
				}
				else if (subentityDict != nil)
				{
					[okSubentities addObject:subentityDict];
					
					// Tag subentities.
					if (![oo::PListView(subentityDict).get<NSString *>(@"type") isEqualToString:@"flasher"])
					{
						subentityKey = oo::PListView(subentityDict).get<NSString *>(@"subentity_key");
						subentityShipEntry = [ioData objectForKey:subentityKey];
						if (subentityKey == nil || subentityShipEntry == nil)
						{
							// Oops, reference to non-existent subent.
							if (badSubentities == nil)  badSubentities = [NSMutableSet set];
							[badSubentities addObject:subentityKey];
						}
						else
						{
							// Subent exists, add _oo_is_subentity so roles aren't required.
							[subentityShipEntry oo_setBool:YES forKey:@"_oo_is_subentity"];
						}
					}
				}
			}
			
			// Set updated subentity list.
			if ([okSubentities count] != 0)
			{
				[shipEntry setObject:okSubentities forKey:@"subentities"];
			}
			else
			{
				[shipEntry removeObjectForKey:@"subentities"];
			}
			
			if (badSubentities != nil)
			{
				if (!oo::PListView(shipEntry).get<BOOL>(@"is_external_dependency"))
				{
					badSubentitiesList = [[[badSubentities allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] componentsJoinedByString:@", "];
					OOLogERR(@"shipData.load.error", @"the shipdata.plist entry \"%@\" has unresolved subentit%@ %@.", shipKey, ([badSubentities count] == 1) ? @"y" : @"ies", badSubentitiesList);
					OOStandardsError(@"Bad subentity definition found");
				}
				remove = YES;
			}
			
			if (remove)
			{
				// Removal is deferred to avoid bogus "entry doesn't exist" errors.
				[shipEntry oo_setBool:YES forKey:@"_oo_deferred_remove"];
			}
		}
	}
	
	return YES;
}


- (BOOL) removeUnusableEntries:(NSMutableDictionary *)ioData shipMode:(BOOL)shipMode
{
	NSString				*shipKey = nil;
	NSMutableDictionary		*shipEntry = nil;
	BOOL					remove;
	NSString				*modelName = nil;
	
	// Clean out invalid entries and templates. (Iterates over a copy of keys since it mutates the dictionary.)
	foreach (shipKey, [ioData allKeys])
	{
		shipEntry = [ioData objectForKey:shipKey];
		remove = NO;
		
		if (oo::PListView(shipEntry).get<BOOL>(@"is_template") || oo::PListView(shipEntry).get<BOOL>(@"_oo_deferred_remove"))  remove = YES;
		else if (shipMode && [oo::PListView(shipEntry).get<NSString *>(@"roles") length] == 0 && !oo::PListView(shipEntry).get<BOOL>(@"_oo_is_subentity") && !oo::PListView(shipEntry).get<BOOL>(@"_oo_is_effect"))
		{
			OOLogERR(@"shipData.load.error", @"the shipdata.plist entry \"%@\" specifies no %@.", shipKey, @"roles");
			remove = YES;
			OOStandardsError(@"Error in shipdata.plist");
		}
		else
		{
			modelName = oo::PListView(shipEntry).get<NSString *>(@"model");
			if (shipMode && [modelName length] == 0)
			{
				OOLogERR(@"shipData.load.error", @"the shipdata.plist entry \"%@\" specifies no %@.", shipKey, @"model");
				OOStandardsError(@"Error in shipdata.plist");
				remove = YES;
			}
			else if ([modelName length] != 0 && [ResourceManager pathForFileNamed:modelName inFolder:@"Models"] == nil)
			{
				OOLogERR(@"shipData.load.error", @"the shipdata.plist entry \"%@\" specifies non-existent model \"%@\".", shipKey, modelName);
				OOStandardsError(@"Error in shipdata.plist");
				remove = YES;
			}
		}
		if (remove)  [ioData removeObjectForKey:shipKey];
	}
	
	return YES;
}


/*	Transform conditions, determinant (if conditions array) and
	shipyard.conditions from hasShipyard to sanitized form.
  Also get list of condition_scripts
*/
- (BOOL) sanitizeConditions:(NSMutableDictionary *)ioData
{
	NSString				*shipKey = nil;
	NSMutableDictionary		*shipEntry = nil;
	NSMutableDictionary		*mutableShipyard = nil;
	NSArray					*conditions = nil;
	NSArray					*hasShipyard = nil;
	NSArray					*shipyardConditions = nil;
	NSString        *condition_script = nil;
	NSString        *shipyard_condition_script = nil;
	
	NSMutableArray *conditionScripts = [[NSMutableArray alloc] init];

	foreach (shipKey, [ioData allKeys])
	{
		shipEntry = [ioData objectForKey:shipKey];
		conditions = [shipEntry objectForKey:@"conditions"];
		condition_script = oo::PListView(shipEntry).get<NSString *>(@"condition_script");
		if (condition_script != nil)
		{
			if (![conditionScripts containsObject:condition_script])
			{
				[conditionScripts addObject:condition_script];
			}
		}

		hasShipyard = [shipEntry objectForKey:@"has_shipyard"];
		if (![hasShipyard isKindOfClass:[NSArray class]])  hasShipyard = nil;	// May also be fuzzy boolean
		if (hasShipyard == nil)
		{
			hasShipyard = [shipEntry objectForKey:@"hasShipyard"];
			if (![hasShipyard isKindOfClass:[NSArray class]])  hasShipyard = nil;	// May also be fuzzy boolean
		}
		shipyardConditions = [oo::PListView(shipEntry).get<NSDictionary *>(@"_oo_shipyard") objectForKey:@"conditions"];
		shipyard_condition_script = oo::PListView(oo::PListView(shipEntry).get<NSDictionary *>(@"_oo_shipyard")).get<NSString *>(@"condition_script");
		if (shipyard_condition_script != nil)
		{
			if (![conditionScripts containsObject:shipyard_condition_script])
			{
				[conditionScripts addObject:shipyard_condition_script];
			}
		}

		
		if (conditions == nil && hasShipyard && shipyardConditions == nil)  continue;
		
		if (conditions != nil)
		{
			OOStandardsDeprecated([NSString stringWithFormat:@"The 'conditions' key is deprecated in shipdata entry %@",shipKey]);
			if (!OOEnforceStandards())
			{
				if ([conditions isKindOfClass:[NSArray class]])
				{
					conditions = OOSanitizeLegacyScriptConditions(conditions, [NSString stringWithFormat:@"<shipdata.plist entry \"%@\">", shipKey]);
				}
				else
				{
					OOLogWARN(@"shipdata.load.warning", @"conditions for shipdata.plist entry \"%@\" are not an array, ignoring.", shipKey);
					conditions = nil;
				}
			
				if (conditions != nil)
				{
					[shipEntry setObject:conditions forKey:@"conditions"];
				}
				else
				{
					[shipEntry removeObjectForKey:@"conditions"];
				}
			}
		}
		
		if (hasShipyard != nil)
		{
			hasShipyard = OOSanitizeLegacyScriptConditions(hasShipyard, [NSString stringWithFormat:@"<shipdata.plist entry \"%@\" hasShipyard conditions>", shipKey]);
			OOStandardsDeprecated([NSString stringWithFormat:@"Use of legacy script conditions in the 'has_shipyard' key is deprecated in shipyard entry %@",shipKey]);
			if (!OOEnforceStandards())
			{
				if (hasShipyard != nil)
				{
					[shipEntry setObject:hasShipyard forKey:@"has_shipyard"];
				}
				else
				{
					[shipEntry removeObjectForKey:@"hasShipyard"];
					[shipEntry removeObjectForKey:@"has_shipyard"];
				}
			}
		}
		
		if (shipyardConditions != nil)
		{
			OOStandardsDeprecated([NSString stringWithFormat:@"The 'conditions' key is deprecated in shipyard entry %@",shipKey]);
			if (!OOEnforceStandards())
			{
				mutableShipyard = [[oo::PListView(shipEntry).get<NSDictionary *>(@"_oo_shipyard") mutableCopy] autorelease];
			
				if ([shipyardConditions isKindOfClass:[NSArray class]])
				{
					shipyardConditions = OOSanitizeLegacyScriptConditions(shipyardConditions, [NSString stringWithFormat:@"<shipyard.plist entry \"%@\">", shipKey]);
				}
				else
				{
					OOLogWARN(@"shipdata.load.warning", @"conditions for shipyard.plist entry \"%@\" are not an array, ignoring.", shipKey);
					shipyardConditions = nil;
				}
			
				if (shipyardConditions != nil)
				{
					[mutableShipyard setObject:shipyardConditions forKey:@"conditions"];
				}
				else
				{
					[mutableShipyard removeObjectForKey:@"conditions"];
				}
			
				[shipEntry setObject:mutableShipyard forKey:@"_oo_shipyard"];
			}
		}
	}

	[[OOCacheManager sharedCache] setObject:conditionScripts forKey:@"ship conditions" inCache:@"condition scripts"];
	[conditionScripts release];

	return YES;
}


#if PRELOAD
- (BOOL) preloadShipMeshes:(NSMutableDictionary *)ioData
{
	NSEnumerator			*shipKeyEnum = nil;
	NSString				*shipKey = nil;
	NSMutableDictionary		*shipEntry = nil;
	BOOL					remove;
	NSString				*modelName = nil;
	OOMesh					*mesh = nil;
	NSUInteger				i = 0, count;
	
	count = [ioData count];
	
	// Preload ship meshes. (Iterates over a copy of keys since it mutates the dictionary.)
	for (shipKeyEnum = [[ioData allKeys] objectEnumerator]; (shipKey = [shipKeyEnum nextObject]); )
	{
		@autoreleasepool
		{
			[[GameController sharedController] setProgressBarValue:(float)i++ / (float)count];
			
			shipEntry = [ioData objectForKey:shipKey];
			remove = NO;
			
			modelName = oo::PListView(shipEntry).get<NSString *>(@"model");
			mesh = [OOMesh meshWithName:modelName
					 materialDictionary:oo::PListView(shipEntry).get<NSDictionary *>(@"materials")
					  shadersDictionary:oo::PListView(shipEntry).get<NSDictionary *>(@"shaders")
								 smooth:oo::PListView(shipEntry).get<BOOL>(@"smooth")
						   shaderMacros:nil
					shaderBindingTarget:nil];
		}	// NOTE: mesh is now invalid, but pointer nil check is OK.
		
		if (mesh == nil)
		{
			// FIXME: what if it's a subentity? Need to rearrange things.
			OOLogERR(@"shipData.load.error", @"model \"%@\" could not be loaded for ship \"%@\", removing.", modelName, shipKey);
			[ioData removeObjectForKey:shipKey];
		}
	}
	
	[[GameController sharedController] setProgressBarValue:-1.0f];
	
	return YES;
}
#endif


- (void) mergeShipRoles:(const std::string &)roles
			 forShipKey:(const std::string &)shipKey
	 intoProbabilityMap:(std::map<std::string, oo::ObjCRef<OOMutableProbabilitySet *>, std::less<>> &)probabilitySets
{
	/*	probabilitySets is a dictionary whose keys are roles and whose values
		are mutable probability sets, whose values are ship keys.

		When creating new ships Oolite looks up this probability map.
		To upgrade all soliton 'thargon' roles to 'EQ_THARGON' we need
		to swap these roles here.
	*/

  // add default [shipKey] role
	std::map<std::string, float, std::less<>> rolesAndWeights;
	for (const auto &[parsedRole, weight] : OOParseRolesFromString(roles))
	{
		rolesAndWeights[parsedRole] = weight;
	}
	rolesAndWeights[oo::str::format("[%s]", shipKey.c_str())] = 1.0f;

	auto thargonValue = rolesAndWeights.find("thargon");
	if (thargonValue != rolesAndWeights.end() && rolesAndWeights.find("EQ_THARGON") == rolesAndWeights.end())
	{
		rolesAndWeights["EQ_THARGON"] = thargonValue->second;
	}

	// (roles in role order; was hash order: each role's set is separate)
	for (const auto &[role, weight] : rolesAndWeights)
	{
		oo::ObjCRef<OOMutableProbabilitySet *> &probSet = probabilitySets[role];
		if (probSet.get() == nil)
		{
			probSet = oo::ObjCRef<OOMutableProbabilitySet *>([OOMutableProbabilitySet probabilitySet]);
		}

		[probSet.get() setWeight:weight forObject:oo::NSStringFrom(shipKey)];
	}
}


- (oo::PList) canonicalizeSubentityDeclaration:(const oo::PList &)declaration
									   forShip:(const std::string &)shipKey
									  shipData:(const oo::PList &)shipData
									fatalError:(BOOL *)outFatalError
{
	oo::PList				result;

	assert(outFatalError != NULL);
	*outFatalError = NO;

	if (declaration.isString())
	{
		// Update old-style string-based declaration.
		cxx_OOStandardsDeprecated(oo::str::format("Old style sub-entity declarations are deprecated in %s", shipKey.c_str()));
		if (!OOEnforceStandards())
		{
			result = [self translateOldStyleSubentityDeclaration:*declaration.getIf<std::string>()
														 forShip:shipKey
														shipData:shipData
													  fatalError:outFatalError];
		}
		if (!result.isNull())
		{
			// Ensure internal translation made sense, and clean up a bit.
			result = [self validateNewStyleSubentityDeclaration:result
														forShip:shipKey
													 fatalError:outFatalError];
		}
	}
	else if (declaration.isDict())
	{
		// Validate dictionary-based declaration.
		result = [self validateNewStyleSubentityDeclaration:declaration
													forShip:shipKey
												 fatalError:outFatalError];
	}
	else
	{
		// (%@ of the declaration's class: the class of the object the property list gives back)
		OOLogERR(@"shipData.load.error.badSubentity", @"subentity declaration for ship %@ should be string or dictionary, found %@.", oo::NSStringFrom(shipKey), [oo::ObjectFromPList(declaration) class]);
		*outFatalError = YES;
	}

	// For frangible ships, bad subentities are non-fatal.
	const oo::PList *shipEntry = shipData.get<oo::PList::Dict>(shipKey);
	if (*outFatalError && shipEntry != nullptr && shipEntry->get<bool>("frangible"))  *outFatalError = NO;

	return result;
}


- (oo::PList) translateOldStyleSubentityDeclaration:(const std::string &)declaration
											forShip:(const std::string &)shipKey
										   shipData:(const oo::PList &)shipData
										 fatalError:(BOOL *)outFatalError
{
	const std::vector<std::string>	tokenStrings = oo::str::tokens(declaration);
	std::string						subentityKey;
	BOOL							isFlasher;

	subentityKey = FirstToken(tokenStrings);
	isFlasher = subentityKey == "*FLASHER*";

	// Sanity check: require eight tokens.
	if (tokenStrings.size() != 8)
	{
		if (!isFlasher)
		{
			OOLogERR(@"shipData.load.error.badSubentity", @"the shipdata.plist entry \"%@\" has a broken subentity definition \"%@\" (should have 8 tokens, has %zu).", oo::NSStringFrom(shipKey), oo::NSStringFrom(subentityKey), tokenStrings.size());
			*outFatalError = YES;
		}
		else
		{
			OOLogWARN(@"shipData.load.warning.badFlasher", @"the shipdata.plist entry \"%@\" has a broken flasher definition (should have 8 tokens, has %zu). This flasher will be ignored.", oo::NSStringFrom(shipKey), tokenStrings.size());
		}
		return oo::PList();
	}

	// The tokens as an array of strings, read with at<float> as the string tokens were.
	oo::PList::Array tokenArray;
	tokenArray.reserve(tokenStrings.size());
	for (const std::string &token : tokenStrings)  tokenArray.emplace_back(token);
	const oo::PList tokens(std::move(tokenArray));

	if (isFlasher)
	{
		return [self translateOldStyleFlasherDeclaration:tokens
												 forShip:shipKey
											  fatalError:outFatalError];
	}
	else
	{
		return [self translateOldStandardBasicSubentityDeclaration:tokens
														   forShip:shipKey
														  shipData:shipData
														fatalError:outFatalError];
	}
}


- (oo::PList) translateOldStyleFlasherDeclaration:(const oo::PList &)tokens
										  forShip:(const std::string &)shipKey
									   fatalError:(BOOL *)outFatalError
{
	Vector					position;
	float					size, frequency, phase, hue;

	position.x = tokens.at<float>(1);
	position.y = tokens.at<float>(2);
	position.z = tokens.at<float>(3);

	hue = tokens.at<float>(4);
	frequency = tokens.at<float>(5);
	phase = tokens.at<float>(6);
	size = tokens.at<float>(7);

	// (the +numberWithFloat: values are single reals)
	oo::PList::Dict colorDict;
	colorDict.emplace("hue", oo::PList::singleReal(hue));

	oo::PList::Dict result;
	result.emplace("type", "flasher");
	result.emplace("position", VectorPList(position));
	result.emplace("colors", oo::PList::Array{ oo::PList(std::move(colorDict)) });
	result.emplace("frequency", oo::PList::singleReal(frequency));
	result.emplace("phase", oo::PList::singleReal(phase));
	result.emplace("size", oo::PList::singleReal(size));
	const oo::PList resultPList(std::move(result));

	std::vector<std::string> tokenStrings;
	for (std::size_t i = 0; i != tokens.count(); ++i)  tokenStrings.push_back(tokens.at<std::string>(i));
	OOLog(@"shipData.translateSubentity.flasher", @"Translated flasher declaration \"%@\" to %@", oo::NSStringFrom(JoinTokens(tokenStrings)), oo::ObjectFromPList(resultPList));

	return resultPList;
}


- (oo::PList) translateOldStandardBasicSubentityDeclaration:(const oo::PList &)tokens
													forShip:(const std::string &)shipKey
												   shipData:(const oo::PList &)shipData
												 fatalError:(BOOL *)outFatalError
{
	std::string				subentityKey;
	Vector					position;
	Quaternion				orientation;
	BOOL					isTurret, isDock = NO;

	subentityKey = tokens.at<std::string>(0);

	isTurret = [self shipIsBallTurretForKey:subentityKey inShipData:shipData];

	position.x = tokens.at<float>(1);
	position.y = tokens.at<float>(2);
	position.z = tokens.at<float>(3);

	orientation.w = tokens.at<float>(4);
	orientation.x = tokens.at<float>(5);
	orientation.y = tokens.at<float>(6);
	orientation.z = tokens.at<float>(7);

	if(orientation.w == 0 && orientation.x == 0 && orientation.y == 0 && orientation.z == 0)
	{
		orientation.w = 1; // avoid dividing by zero.
		OOLogWARN(@"shipData.load.error", @"The ship %@ has an undefined orientation for its %@ subentity. Setting it now at (1,0,0,0)", oo::NSStringFrom(shipKey), oo::NSStringFrom(subentityKey));
	}

	quaternion_normalize(&orientation);

	if (!isTurret)
	{
		isDock = subentityKey.find("dock") != std::string::npos;
	}

	oo::PList::Dict result;
	result.emplace("type", isTurret ? "ball_turret" : "standard");
	result.emplace("subentity_key", subentityKey);
	result.emplace("position", VectorPList(position));
	result.emplace("orientation", QuaternionPList(orientation));
	if (isDock)  result.emplace("is_dock", true);
	const oo::PList resultPList(std::move(result));

	std::vector<std::string> tokenStrings;
	for (std::size_t i = 0; i != tokens.count(); ++i)  tokenStrings.push_back(tokens.at<std::string>(i));
	OOLog(@"shipData.translateSubentity.standard", @"Translated subentity declaration \"%@\" to %@", oo::NSStringFrom(JoinTokens(tokenStrings)), oo::ObjectFromPList(resultPList));

	return resultPList;
}


- (oo::PList) validateNewStyleSubentityDeclaration:(const oo::PList &)declaration
										   forShip:(const std::string &)shipKey
										fatalError:(BOOL *)outFatalError
{
	const std::string		type = StringForKey(&declaration, "type").value_or("standard");

	if (type == "flasher")
	{
		return [self validateNewStyleFlasherDeclaration:declaration forShip:shipKey fatalError:outFatalError];
	}
	else if (type == "standard" || type == "ball_turret")
	{
		return [self validateNewStyleStandardSubentityDeclaration:declaration forShip:shipKey fatalError:outFatalError];
	}
	else
	{
		OOLogERR(@"shipData.load.error.badSubentity", @"subentity declaration for ship %@ does not declare a valid type (must be standard, flasher or ball_turret).", oo::NSStringFrom(shipKey));
		*outFatalError = YES;
		return oo::PList();
	}
}


- (oo::PList) validateNewStyleFlasherDeclaration:(const oo::PList &)declaration
										 forShip:(const std::string &)shipKey
									  fatalError:(BOOL *)outFatalError
{
	Vector					position = kZeroVector;
	float					size, frequency, phase, brightfraction;
	BOOL					initiallyOn;

#define kDefaultFlasherColor "redColor"

	// "Validate" is really "clean up", since all values have defaults.
	const oo::PList *colorList = declaration.get<oo::PList::Array>("colors");
	oo::PList colors = colorList != nullptr ? *colorList : oo::PList();
	if (colors.count() == 0)
	{
		const oo::PList *color = declaration.find("color");
		const oo::PList colorDesc = color != nullptr ? *color : oo::PList(kDefaultFlasherColor);
		if (colorDesc.isArray())
		{
			// an easy made error is adding an array to "color" instead of "colors"
			OOLogWARN(@"shipData.load.warning.flasher.badColor", @"changing flasher for ship %@ from a color to a colors definition.", oo::NSStringFrom(shipKey));
			colors = colorDesc;
		}
		else
		{
			colors = oo::PList(oo::PList::Array{ colorDesc });
		}
	}

	// Validate colours. (OOColor is converted at the call; its components are single reals.)
	oo::PList::Array validColors;
	for (std::size_t i = 0; i != colors.count(); ++i)
	{
		OOColor *color = [OOColor colorWithDescription:oo::ObjectFromPList(*colors.at(i))];
		if (color != nil)
		{
			oo::PList::Array components;
			for (float component : [color cxx_normalizedArray])  components.push_back(oo::PList::singleReal(component));
			validColors.emplace_back(std::move(components));
		}
		else
		{
			OOLogWARN(@"shipdata.load.warning.flasher.badColor", @"skipping invalid colour specifier for flasher for ship %@.", oo::NSStringFrom(shipKey));
		}
	}
	// Ensure there's at least one.
	if (validColors.empty())
	{
		validColors.emplace_back(kDefaultFlasherColor);
	}

	position = VectorForKey(declaration, "position");

	size = declaration.get<float>("size", 8.0);

	if (size <= 0)
	{
		OOLogWARN(@"shipData.load.warning.flasher.badSize", @"skipping flasher of invalid size %g for ship %@.", size, oo::NSStringFrom(shipKey));
		return oo::PList();
	}

	brightfraction = declaration.get<float>("bright_fraction", 0.5);
	if (brightfraction < 0.0 || brightfraction > 1.0)
	{
		OOLogWARN(@"shipData.load.warning.flasher.badFraction", @"skipping flasher of invalid bright fraction %g for ship %@.", brightfraction, oo::NSStringFrom(shipKey));
		return oo::PList();
	}

	frequency = declaration.get<float>("frequency", 2.0);
	phase = declaration.get<float>("phase", 0.0);
	initiallyOn = declaration.get<bool>("initially_on", true);

	oo::PList::Dict result;
	result.emplace("type", "flasher");
	result.emplace("colors", std::move(validColors));
	result.emplace("position", VectorPList(position));
	result.emplace("size", oo::PList::singleReal(size));
	result.emplace("frequency", oo::PList::singleReal(frequency));
	if (phase != 0)  result.emplace("phase", oo::PList::singleReal(phase));
	result.emplace("bright_fraction", oo::PList::singleReal(brightfraction));
	result.emplace("initially_on", initiallyOn ? true : false);

	return oo::PList(std::move(result));
}


- (oo::PList) validateNewStyleStandardSubentityDeclaration:(const oo::PList &)declaration
												   forShip:(const std::string &)shipKey
												fatalError:(BOOL *)outFatalError
{
	Vector					position = kZeroVector;
	Quaternion				orientation = kIdentityQuaternion;
	BOOL					isTurret;
	BOOL					isDock = NO;
	float					fireRate = -1.0f; // out of range constants
	float					weaponRange = -1.0f;
	float					weaponEnergy = -1.0f;

	const oo::PList *subentityKey = declaration.find("subentity_key");
	if (subentityKey == nullptr)
	{
		OOLogERR(@"shipData.load.error.badSubentity", @"subentity declaration for ship %@ specifies no subentity_key.", oo::NSStringFrom(shipKey));
		*outFatalError = YES;
		return oo::PList();
	}

	isTurret = StringForKey(&declaration, "type") == "ball_turret";
	if (isTurret)
	{
		fireRate = declaration.get<float>("fire_rate", -1.0f);
		if (fireRate < 0.25f && fireRate >= 0.0f)
		{
			OOLogWARN(@"shipData.load.warning.turret.badFireRate", @"ball turret fire rate of %g for subentity of ship %@ is invalid, using 0.25.", fireRate, oo::NSStringFrom(shipKey));
			fireRate = 0.25f;
		}
		weaponRange = declaration.get<float>("weapon_range", -1.0f);
		if (weaponRange > TURRET_SHOT_RANGE * COMBAT_WEAPON_RANGE_FACTOR)
		{
			OOLogWARN(@"shipData.load.warning.turret.badWeaponRange", @"ball turret weapon range of %g for subentity of ship %@ is too high, using %.1f.", weaponRange, oo::NSStringFrom(shipKey), TURRET_SHOT_RANGE * COMBAT_WEAPON_RANGE_FACTOR);
			weaponRange = TURRET_SHOT_RANGE * COMBAT_WEAPON_RANGE_FACTOR; // approx. range of primary plasma canon.
		}

		weaponEnergy = declaration.get<float>("weapon_energy", -1.0f);
		if (weaponEnergy > 100.0f)

		{
			OOLogWARN(@"shipData.load.warning.turret.badWeaponEnergy", @"ball turret weapon energy of %g for subentity of ship %@ is too high, using 100.", weaponEnergy, oo::NSStringFrom(shipKey));
			weaponEnergy = 100.0f;
		}
	}
	else
	{
		isDock = declaration.get<bool>("is_dock");
	}

	position = VectorForKey(declaration, "position");
	orientation = QuaternionForKey(declaration, "orientation");
	quaternion_normalize(&orientation);

	const oo::PList *scriptInfo = declaration.get<oo::PList::Dict>("script_info");

	oo::PList::Dict result;
	result.emplace("type", isTurret ? "ball_turret" : "standard");
	result.emplace("subentity_key", *subentityKey);
	result.emplace("position", VectorPList(position));
	result.emplace("orientation", QuaternionPList(orientation));
	if (isDock)
	{
		result["is_dock"] = true;

		result["dock_label"] = declaration.get<std::string>("dock_label", "the docking bay");

		BOOL dockable = declaration.get<bool>("allow_docking", true);
		BOOL playerdockable = declaration.get<bool>("disallowed_docking_collides", false);
		BOOL undockable = declaration.get<bool>("allow_launching", true);

		result["allow_docking"] = dockable ? true : false;
		result["disallowed_docking_collides"] = playerdockable ? true : false;
		result["allow_launching"] = undockable ? true : false;

	}

	if (isTurret)
	{
		// default constants are defined and set in shipEntity
		// (oo_setFloat: stored the float as a double number)
		if (fireRate > 0) result["fire_rate"] = static_cast<double>(fireRate);
		if (weaponRange >= 0) result["weapon_range"] = static_cast<double>(weaponRange);
		if (weaponEnergy >= 0) result["weapon_energy"] = static_cast<double>(weaponEnergy);
	}

	if (scriptInfo != nullptr)
	{
		result["script_info"] = *scriptInfo;
	}

	return oo::PList(std::move(result));
}


- (BOOL) shipIsBallTurretForKey:(const std::string &)shipKey inShipData:(const oo::PList &)shipData
{
	// Test for presence of setup_actions containing initialiseTurret.
	const oo::PList *shipEntry = shipData.get<oo::PList::Dict>(shipKey);
	const oo::PList *setupActions = shipEntry != nullptr ? shipEntry->get<oo::PList::Array>("setup_actions") : nullptr;

	for (std::size_t i = 0; setupActions != nullptr && i != setupActions->count(); ++i)
	{
		const std::string *action = setupActions->at(i)->getIf<std::string>();
		if (FirstToken(oo::str::tokens(action != nullptr ? *action : std::string())) == "initialiseTurret")  return YES;
	}

	if (shipKey == "ballturret")
	{
		// compatibility for OXPs using old subentity declarations and the
		// core turret entity
		return YES;
	}

	return NO;
}

@end


@implementation OOShipRegistry (Singleton)

/*	Canonical singleton boilerplate.
	See Cocoa Fundamentals Guide: Creating a Singleton Instance.
	See also +sharedRegistry above.
	
	NOTE: assumes single-threaded access.
*/

+ (id) allocWithZone:(OOZone *)inZone
{
	if (sSingleton == nil)
	{
		OOLog(@"shipData.load.begin", @"%@", @"Loading ship data.");
		sSingleton = [super allocWithZone:inZone];
		return sSingleton;
	}
	return nil;
}


- (id) copyWithZone:(OOZone *)inZone
{
	return self;
}


- (id) retain
{
	return self;
}


- (NSUInteger) retainCount
{
	return UINT_MAX;
}


- (void) release
{}


- (id) autorelease
{
	return self;
}

@end


/*	One gathered string: the string, its address and where it was found. Was an
	NSDictionary with the address in a pointer box, collected in an NSMutableSet
	(bead oo-3rb.47). A tree walk never meets the same string object twice in the same
	context, so the set's deduplication never applied; the list keeps walk order (the
	set's was hash order), and nothing reads it but the disabled dump below.
*/
struct StringAddr
{
	NSString	*string;
	const void	*address;
	NSString	*context;
};
typedef std::vector<StringAddr> StringAddrList;

static void GatherStringAddrsDict(NSDictionary *dict, StringAddrList &strings, NSString *context);
static void GatherStringAddrsArray(NSArray *array, StringAddrList &strings, NSString *context);
static void GatherStringAddrs(id object, StringAddrList &strings, NSString *context);


static void DumpStringAddrs(NSDictionary *dict, NSString *context)
{
	return;
	static FILE *dump = NULL;
	if (dump == NULL)  dump = fopen("strings.txt", "w");
	if (dump == NULL)  return;
	
	@autoreleasepool
	{
		StringAddrList strings;
		GatherStringAddrs(dict, strings, context);

		for (const StringAddr &entry : strings)
		{
			NSString *string = entry.string;
			NSString *context = entry.context;
			const void *pointer = entry.address;
			
			string = [NSString stringWithFormat:@"%p\t%@:  \"%@\"", pointer, context, string];
			
			fprintf(dump, "%s\n", [string UTF8String]);
		}
		
		fprintf(dump, "\n");
		fflush(dump);
	}
}


static void GatherStringAddrsDict(NSDictionary *dict, StringAddrList &strings, NSString *context)
{
	id key = nil;
	NSString *keyContext = [context stringByAppendingString:@" key"];
	foreachkey (key, dict)
	{
		GatherStringAddrs(key, strings, keyContext);
		GatherStringAddrs([dict objectForKey:key], strings, [context stringByAppendingFormat:@".%@", key]);
	}
}


static void GatherStringAddrsArray(NSArray *array, StringAddrList &strings, NSString *context)
{
	NSString *v = nil;
	unsigned i = 0;
	foreach (v, array)
	{
		GatherStringAddrs(v, strings, [context stringByAppendingFormat:@"[%u]", i++]);
	}
}


static void GatherStringAddrs(id object, StringAddrList &strings, NSString *context)
{
	if ([object isKindOfClass:[NSString class]])
	{
		// The strings and contexts live in the dictionary and the dump's pool, which outlive the list.
		strings.push_back(StringAddr{ object, object, context });
	}
	else if ([object isKindOfClass:[NSArray class]])
	{
		GatherStringAddrsArray(object, strings, context);
	}
	else if ([object isKindOfClass:[NSDictionary class]])
	{
		GatherStringAddrsDict(object, strings, context);
	}
}


