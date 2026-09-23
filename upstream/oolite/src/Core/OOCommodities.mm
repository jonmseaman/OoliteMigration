/*

OOCommodities.m

Oolite
Copyright (C) 2004-2014 Giles C Williams and contributors

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

#import "OOCommodities.h"
#import "OOCommodityMarket.h"

#import "StationEntity.h"
#import "ResourceManager.h"
#import "legacy_random.h"
#import "OOPListView.h"
#import "OOJSScript.h"
#import "PlayerEntity.h"
#import "OOStringExpander.h"
#import "OOFoundationBridge.h"


namespace {

// Moved from OOCommodities.h (bead oo-3rb.154): this file is their only user. (sort_order,
// trumble_opinion, comment and short_comment are read only by OOCommodityMarket.mm, which spells
// its own C++ keys, so their constants went rather than sit here unused.)
// keys in trade-goods.plist
static NSString * const kOOCommodityName			= @"name";
static NSString * const kOOCommodityClasses			= @"classes";
static NSString * const kOOCommodityContainer		= @"quantity_unit";
static NSString * const kOOCommodityPeakExport		= @"peak_export";
static NSString * const kOOCommodityPeakImport		= @"peak_import";
static NSString * const kOOCommodityPriceAverage	= @"price_average";
static NSString * const kOOCommodityPriceEconomic	= @"price_economic";
static NSString * const kOOCommodityPriceRandom		= @"price_random";
// next one cannot be set from file - named for compatibility
static NSString * const kOOCommodityPriceCurrent	= @"price";
static NSString * const kOOCommodityQuantityAverage	= @"quantity_average";
static NSString * const kOOCommodityQuantityEconomic= @"quantity_economic";
static NSString * const kOOCommodityQuantityRandom	= @"quantity_random";
// next one cannot be set from file - named for compatibility
static NSString * const kOOCommodityQuantityCurrent	= @"quantity";
static NSString * const kOOCommodityLegalityExport	= @"legality_export";
static NSString * const kOOCommodityLegalityImport	= @"legality_import";
static NSString * const kOOCommodityCapacity		= @"capacity";
static NSString * const kOOCommodityScript			= @"market_script";
// next one cannot be set from file - named for compatibility
static NSString * const kOOCommodityKey				= @"key";


// keys in secondary market definitions
static NSString * const kOOCommodityMarketType					= @"type";
static NSString * const kOOCommodityMarketName					= @"name";
static NSString * const kOOCommodityMarketPriceAdder			= @"price_adder";
static NSString * const kOOCommodityMarketPriceMultiplier		= @"price_multiplier";
static NSString * const kOOCommodityMarketPriceRandomiser		= @"price_randomiser";
static NSString * const kOOCommodityMarketQuantityAdder			= @"quantity_adder";
static NSString * const kOOCommodityMarketQuantityMultiplier	= @"quantity_multiplier";
static NSString * const kOOCommodityMarketQuantityRandomiser	= @"quantity_randomiser";
static NSString * const kOOCommodityMarketLegalityExport		= @"legality_export";
static NSString * const kOOCommodityMarketLegalityImport		= @"legality_import";
static NSString * const kOOCommodityMarketCapacity				= @"capacity";

// values for "type" in the plist
static NSString * const kOOCommodityMarketTypeValueDefault		= @"default";
static NSString * const kOOCommodityMarketTypeValueClass		= @"class";
static NSString * const kOOCommodityMarketTypeValueGood			= @"good";


// -[NSDictionary oo_stringForKey:] on a commodity's info: a string, or a number's -stringValue;
// nullopt (nil) otherwise.
std::optional<std::string> StringFor(const oo::PList &info, const std::string &key)
{
	const oo::PList *value = info.find(key);
	if (value == nullptr || !(value->isString() || value->isNumber()))  return std::nullopt;
	return info.get<std::string>(key);
}

} // namespace

@interface OOCommodities (OOPrivate)

- (NSDictionary *) modifyGood:(NSDictionary *)good withScript:(OOScript *)script atStation:(StationEntity *)station inSystem:(OOSystemID)system localMode:(BOOL)local;
- (NSDictionary *) createDefinitionFrom:(NSDictionary *) good price:(OOCreditsQuantity)p andQuantity:(OOCargoQuantity)q forKey:(OOCommodityType)key atStation:(StationEntity *)station inSystem:(OOSystemID)system;


- (OOCargoQuantity) generateQuantityForGood:(NSDictionary *)good inEconomy:(OOEconomyID)economy;
- (OOCreditsQuantity) generatePriceForGood:(NSDictionary *)good inEconomy:(OOEconomyID)economy;

- (float) economicBiasForGood:(NSDictionary *)good inEconomy:(OOEconomyID)economy;
- (NSDictionary *) firstModifierForGood:(OOCommodityType)good inClasses:(NSArray *)classes fromList:(NSArray *)definitions;
- (OOCreditsQuantity) adjustPrice:(OOCreditsQuantity)price byRule:(NSDictionary *)rule;
- (OOCargoQuantity) adjustQuantity:(OOCargoQuantity)quantity byRule:(NSDictionary *)rule;
- (NSDictionary *) updateInfoFor:(NSDictionary *)good byRule:(NSDictionary *)rule maxCapacity:(OOCargoQuantity)maxCapacity;

@end


@implementation OOCommodities

/* Older save games store some commodity information by its old index. */
+ (std::optional<std::string>) cxx_legacyCommodityType:(NSUInteger)i
{
	switch (i)
	{
	case 0:
		return "food";
	case 1:
		return "textiles";
	case 2:
		return "radioactives";
	case 3:
		return "slaves";
	case 4:
		return "liquor_wines";
	case 5:
		return "luxuries";
	case 6:
		return "narcotics";
	case 7:
		return "computers";
	case 8:
		return "machinery";
	case 9:
		return "alloys";
	case 10:
		return "firearms";
	case 11:
		return "furs";
	case 12:
		return "minerals";
	case 13:
		return "gold";
	case 14:
		return "platinum";
	case 15:
		return "gem_stones";
	case 16:
		return "alien_items";
	}
	// shouldn't happen
	return "food";
}



- (id) init
{
	self = [super init];
	if (self == nil)  return nil;

	// ResourceManager's dictionary API is not migrated: the merged table arrives through oo::PListFrom.
	// TODO: validation of inputs; convert 't', 'kg', 'g' in quantity_unit to 0, 1, 2 (for now it
	// needs them entering as the ints).
	const oo::PList rawCommodityLists = oo::PListFrom([ResourceManager dictionaryFromFilesNamed:@"trade-goods.plist" inFolder:@"Config" mergeMode:MERGE_SMART cache:YES]);
	if (const oo::PList::Dict *entries = rawCommodityLists.getIf<oo::PList::Dict>())  _commodityLists = *entries;

	return self;
}


- (void) dealloc
{
	[super dealloc];
}


- (OOCommodityMarket *) generateManifestForPlayer
{
	OOCommodityMarket *market = [[OOCommodityMarket alloc] init];

	NSMutableDictionary *good = nil;
	for (const auto &[key, info] : _commodityLists)	// key order (was hash order)
	{
		NSString *commodity = oo::NSStringFrom(key);
		good = [NSMutableDictionary dictionaryWithDictionary:oo::ObjectFromPList(info)];
		[good oo_setUnsignedInteger:0 forKey:kOOCommodityPriceCurrent];
		[good oo_setUnsignedInteger:0 forKey:kOOCommodityQuantityCurrent];
		/* The actual capacity of the player ship is a total, not
		 * per-good, so is managed separately through PlayerEntity */
		[good oo_setUnsignedInteger:UINT32_MAX forKey:kOOCommodityCapacity];
		[good setObject:commodity forKey:kOOCommodityKey];
		
		[market setGood:commodity withInfo:good];
	}
	return [market autorelease];
}


- (OOCommodityMarket *) generateBlankMarket
{
	OOCommodityMarket *market = [[OOCommodityMarket alloc] init];

	NSMutableDictionary *good = nil;
	for (const auto &[key, info] : _commodityLists)	// key order (was hash order)
	{
		NSString *commodity = oo::NSStringFrom(key);
		good = [NSMutableDictionary dictionaryWithDictionary:oo::ObjectFromPList(info)];
		[good oo_setUnsignedInteger:0 forKey:kOOCommodityPriceCurrent];
		[good oo_setUnsignedInteger:0 forKey:kOOCommodityQuantityCurrent];
		[good oo_setUnsignedInteger:0 forKey:kOOCommodityCapacity];
		[good setObject:commodity forKey:kOOCommodityKey];
		
		[market setGood:commodity withInfo:good];
	}
	return [market autorelease];
}


- (NSDictionary *) createDefinitionFrom:(NSDictionary *) good price:(OOCreditsQuantity)p andQuantity:(OOCargoQuantity)q forKey:(OOCommodityType)key atStation:(StationEntity *)station inSystem:(OOSystemID)system
{
	NSMutableDictionary *definition = [NSMutableDictionary dictionaryWithDictionary:good];
	[definition oo_setUnsignedInteger:p forKey:kOOCommodityPriceCurrent];
	[definition oo_setUnsignedInteger:q forKey:kOOCommodityQuantityCurrent];
	if (station == nil && [definition objectForKey:kOOCommodityCapacity] == nil)
	{
		[definition oo_setInteger:MAIN_SYSTEM_MARKET_LIMIT forKey:kOOCommodityCapacity];
	}

	[definition setObject:key forKey:kOOCommodityKey];
	if (station != nil && ![station marketMonitored])
	{
		// clear legal status indicators if the market is not monitored
		[definition oo_setUnsignedInteger:0 forKey:kOOCommodityLegalityExport];		
		[definition oo_setUnsignedInteger:0 forKey:kOOCommodityLegalityImport];
	}

	NSString *goodScriptName = oo::PListView(definition).get<NSString *>(kOOCommodityScript);
	if (goodScriptName == nil)
	{
		return definition;
	}
	OOScript *goodScript = [PLAYER commodityScriptNamed:goodScriptName];
	if (goodScript == nil)
	{
		return definition;
	}
	return [self modifyGood:definition withScript:goodScript atStation:station inSystem:system localMode:NO];
}


- (NSDictionary *) modifyGood:(NSDictionary *)good withScript:(OOScript *)script atStation:(StationEntity *)station inSystem:(OOSystemID)system localMode:(BOOL)localMode
{
	NSDictionary 		*result = nil;
	ooscript::Context context = OOJSAcquireContext();
	ooscript::Value				rval;
	ooscript::Value				args[] = { 
		OOJSValueFromNativeObject(context, good),
		OOJSValueFromNativeObject(context, station),
		ooscript::int32Value(system) 
	};
	BOOL				OK = YES;
	NSString			*errorType = nil;

	if (localMode)
	{
		errorType = @"local";
		OK = [script callMethod:OOJSID("updateLocalCommodityDefinition")
					  inContext:context
				  withArguments:args
						  count:3
						 result:&rval];
	}
	else
	{
		errorType = @"general";
		OK = [script callMethod:OOJSID("updateGeneralCommodityDefinition")
					  inContext:context
				  withArguments:args
						  count:3
						 result:&rval];
	}

	if (!OK)
	{
		OOLog(@"script.commodityScript.error",@"Could not update %@ commodity definition for %@ - unable to call updateLocalCommodityDefinition",errorType,oo::PListView(good).get<NSString *>(kOOCommodityName));
		OOJSRelinquishContext(context);
		return good;
	}

	if (!ooscript::isObjectOrNull(rval))
	{
		OOLog(@"script.commodityScript.error",@"Could not update %@ commodity definition for %@ - return value invalid",errorType,oo::PListView(good).get<NSString *>(kOOCommodityKey));
		OOJSRelinquishContext(context);
		return good;
	}

	result = OOJSNativeObjectFromJSObject(context, ooscript::toObject(rval));
	OOJSRelinquishContext(context);
	if (![result isKindOfClass:[NSDictionary class]])
	{
		OOLog(@"script.commodityScript.error",@"Could not update %@ commodity definition for %@ - return value invalid",errorType,oo::PListView(good).get<NSString *>(kOOCommodityKey));
		return good;
	}
	
	return result;
}


- (OOCommodityMarket *) cxx_generateMarketForSystemWithEconomy:(OOEconomyID)economy andScript:(const std::optional<std::string> &)scriptName
{
	OOScript *script = [PLAYER commodityScriptNamed:oo::NSStringOrNil(scriptName)];

	OOCommodityMarket *market = [[OOCommodityMarket alloc] init];

	for (const auto &[key, info] : _commodityLists)	// key order (was hash order)
	{
		NSString *commodity = oo::NSStringFrom(key);
		NSDictionary *good = oo::ObjectFromPList(info);
		OOCargoQuantity q = [self generateQuantityForGood:good inEconomy:economy];
		// main system market limited to 127 units of each item
		OOCargoQuantity cap = oo::PListView(good).get<unsigned int>(kOOCommodityCapacity, MAIN_SYSTEM_MARKET_LIMIT);
		if (q > cap)
		{
			q = cap;
		}
		OOCreditsQuantity p = [self generatePriceForGood:good inEconomy:economy];
		good = [self createDefinitionFrom:good price:p andQuantity:q forKey:commodity atStation:nil inSystem:[UNIVERSE currentSystemID]];

		if (script != nil)
		{
			good = [self modifyGood:good withScript:script atStation:nil inSystem:[UNIVERSE currentSystemID] localMode:YES];
		}
		[market setGood:commodity withInfo:good];
	}
	return [market autorelease];
}


- (OOCommodityMarket *) generateMarketForStation:(StationEntity *)station
{
	NSArray *marketDefinition = [station marketDefinition];
	NSString *marketScriptName = [station marketScriptName];
	OOScript *marketScript = [PLAYER commodityScriptNamed:marketScriptName];
	if (marketDefinition == nil && marketScript == nil)
	{
		OOCommodityMarket *market = [self generateBlankMarket];
		return market;
	}
	
	OOCommodityMarket *market = [[OOCommodityMarket alloc] init];
	OOCargoQuantity capacity = [station marketCapacity];
	OOCommodityMarket *mainMarket = [UNIVERSE commodityMarket];

	for (const auto &[key, info] : _commodityLists)	// key order (was hash order)
	{
		NSString *commodity = oo::NSStringFrom(key);
		NSDictionary *good = oo::ObjectFromPList(info);
		OOCargoQuantity baseCapacity = oo::PListView(good).get<unsigned int>(kOOCommodityCapacity, MAIN_SYSTEM_MARKET_LIMIT);
		
		// important - ensure baseCapacity cannot be zero
		if (!baseCapacity)  baseCapacity = MAIN_SYSTEM_MARKET_LIMIT;

		OOCargoQuantity q = [mainMarket quantityForGood:commodity];
		OOCreditsQuantity p = [mainMarket priceForGood:commodity];
		
		if (marketScript == nil)
		{
			NSDictionary *modifier = [self firstModifierForGood:commodity inClasses:oo::PListView(good).get<NSArray *>(kOOCommodityClasses) fromList:marketDefinition];
			good = [self updateInfoFor:good byRule:modifier maxCapacity:capacity];
			p = [self adjustPrice:p byRule:modifier];
		
			// first, scale to this station's capacity for this good
			OOCargoQuantity localCapacity = oo::PListView(good).get<unsigned int>(kOOCommodityCapacity);
			if (localCapacity > capacity)
			{
				localCapacity = capacity;
			}
			q = (q * localCapacity) / baseCapacity;
			q = [self adjustQuantity:q byRule:modifier];
			if (q > localCapacity)
			{
				q = localCapacity; // cap
			}
		}
		else
		{
			// only scale to market at this stage
			q = (q * capacity) / baseCapacity;
		}

		good = [self createDefinitionFrom:good price:p andQuantity:q forKey:commodity atStation:station inSystem:[UNIVERSE currentSystemID]];
		if (marketScript != nil)
		{
			good = [self modifyGood:good withScript:marketScript atStation:station inSystem:[UNIVERSE currentSystemID] localMode:YES];
		}

		[market setGood:commodity withInfo:good];
	}
	return [market autorelease];
}


- (NSUInteger) count
{
	return _commodityLists.size();
}


- (id) goods
{
	// key order (was -allKeys, hash order)
	std::vector<std::string> keys;
	for (const auto &entry : _commodityLists)  keys.push_back(entry.first);
	return oo::NSArrayFromStrings(keys);
}


- (BOOL) cxx_goodDefined:(const std::string &)key
{
	const auto entry = _commodityLists.find(key);
	return entry != _commodityLists.end() && entry->second.isDict();
}

- (std::optional<std::string>) cxx_goodNamed:(const std::string &)name
{
	for (const auto &[key, info] : _commodityLists)	// key order (was hash order): the first match wins
	{
		// OOExpand (OOStringExpander) is not migrated: the name crosses at the call.
		const std::optional<std::string> expanded = oo::OptionalString(OOExpand(oo::NSStringOrNil(StringFor(info, oo::StdString(kOOCommodityName)))));
		if (expanded == name) {
			return key;
		}
	}
	return std::nullopt;
}



- (id) getRandomCommodity
{
	// Ranrot() % count indexes the keys in key order (was -allKeys, hash order).
	NSUInteger idx = Ranrot() % _commodityLists.size();
	auto entry = _commodityLists.begin();
	std::advance(entry, idx);
	return oo::NSStringFrom(entry->first);
}


- (OOMassUnit) massUnitForGood:(id)good
{
	const auto entry = _commodityLists.find(oo::StdString(good));
	if (entry == _commodityLists.end() || !entry->second.isDict())
	{
		return UNITS_TONS;
	}
	return OOMassUnitFromNumber(entry->second.get<unsigned int>(oo::StdString(kOOCommodityContainer)));
}




- (OOCargoQuantity) generateQuantityForGood:(NSDictionary *)good inEconomy:(OOEconomyID)economy
{
	float bias = [self economicBiasForGood:good inEconomy:economy];

	float base = oo::PListView(good).get<float>(kOOCommodityQuantityAverage);
	float econ = base * oo::PListView(good).get<float>(kOOCommodityQuantityEconomic) * bias;
	// Two draws, in the order clang evaluated the operands of the former (randf() - randf()).
	float firstDraw = randf();
	float secondDraw = randf();
	float random = base * oo::PListView(good).get<float>(kOOCommodityQuantityRandom) * (firstDraw - secondDraw);
	base += econ + random;
	if (base < 0.0)
	{
		return 0;
	}
	else
	{
		return (OOCargoQuantity)base;
	}
}


- (OOCreditsQuantity) generatePriceForGood:(NSDictionary *)good inEconomy:(OOEconomyID)economy
{
	float bias = [self economicBiasForGood:good inEconomy:economy];

	float base = oo::PListView(good).get<float>(kOOCommodityPriceAverage);
	float econ = base * oo::PListView(good).get<float>(kOOCommodityPriceEconomic) * -bias;
	// Two draws, in the order clang evaluated the operands of the former (randf() - randf()).
	float firstDraw = randf();
	float secondDraw = randf();
	float random = base * oo::PListView(good).get<float>(kOOCommodityPriceRandom) * (firstDraw - secondDraw);
	base += econ + random;
	if (base < 0.0)
	{
		return 0;
	}
	else
	{
		return (OOCreditsQuantity)base;
	}
}


- (OOCreditsQuantity) cxx_samplePriceForCommodity:(const std::string &)commodityKey inEconomy:(OOEconomyID)economy withScript:(const std::optional<std::string> &)scriptNameValue inSystem:(OOSystemID)system
{
	const auto entry = _commodityLists.find(commodityKey);
	if (entry == _commodityLists.end() || !entry->second.isDict())
	{
		return 0;
	}
	// The pricing below is Foundation until chunk 2: key, info and script name cross here.
	NSString *commodity = oo::NSStringFrom(commodityKey);
	NSString *scriptName = oo::NSStringOrNil(scriptNameValue);
	NSDictionary *good = oo::ObjectFromPList(entry->second);
	OOCreditsQuantity p = [self generatePriceForGood:good inEconomy:economy];

	good = [self createDefinitionFrom:good price:p andQuantity:0 forKey:commodity atStation:nil inSystem:system];
	if (scriptName != nil)
	{
		OOScript *script = [PLAYER commodityScriptNamed:scriptName];
		if (script != nil)
		{
			good = [self modifyGood:good withScript:script atStation:nil inSystem:system localMode:YES];
		}
	}
	return oo::PListView(good).get<NSUInteger>(kOOCommodityPriceCurrent);
}


// positive = exporter; negative = importer; range -1.0 .. +1.0
- (float) economicBiasForGood:(NSDictionary *)good inEconomy:(OOEconomyID)economy
{
	OOEconomyID exporter = oo::PListView(good).get<int>(kOOCommodityPeakExport);
	OOEconomyID importer = oo::PListView(good).get<int>(kOOCommodityPeakImport);
	
	// *2 and /2 to work in ints at this stage
	int exDiff = abs(economy-exporter)*2;
	int imDiff = abs(economy-importer)*2;
	int distance = (exDiff+imDiff)/2;

	if (exDiff == imDiff)
	{
		// neutral economy
		return 0.0;
	}
	else if (exDiff > imDiff)
	{
		// closer to the importer, so return -ve
		return -(1.0-((float)imDiff/(float)distance));
	}
	else
	{
		// closer to the exporter, so return +ve
		return 1.0-((float)exDiff/(float)distance);
	}
}


- (NSDictionary *) firstModifierForGood:(OOCommodityType)good inClasses:(NSArray *)classes fromList:(NSArray *)definitions
{
	NSUInteger i;
	for (i = 0; i < [definitions count]; i++)
	{
		NSDictionary *definition = oo::PListView(definitions).at<NSDictionary *>(i);
		if (definition != nil)
		{
			NSString *applicationType = oo::PListView(definition).get<NSString *>(kOOCommodityMarketType, kOOCommodityMarketTypeValueDefault);
			NSString *applicationName = oo::PListView(definition).get<NSString *>(kOOCommodityMarketName, @"");

			if (
				[applicationType isEqualToString:kOOCommodityMarketTypeValueDefault]
				|| ([applicationType isEqualToString:kOOCommodityMarketTypeValueGood] && [applicationName isEqualToString:good])
				|| ([applicationType isEqualToString:kOOCommodityMarketTypeValueClass] && [classes containsObject:applicationName])
				)
			{
				return definition;
			}
		}
	}
	// return a blank dictionary - default values will do the rest
	return [NSDictionary dictionary];
}


- (OOCreditsQuantity) adjustPrice:(OOCreditsQuantity)price byRule:(NSDictionary *)rule
{
	float p = (float)price; // work in floats to avoid rounding problems
	float pa = oo::PListView(rule).get<float>(kOOCommodityMarketPriceAdder, 0.0);
	float pm = oo::PListView(rule).get<float>(kOOCommodityMarketPriceMultiplier, 1.0);
	if (pm <= 0.0 && pa <= 0.0)
	{
		// setting a price multiplier of 0 forces the price to zero
		return 0;
	}
	float pr = oo::PListView(rule).get<float>(kOOCommodityMarketPriceRandomiser, 0.0);
	p += pa;
	p = (p * pm) + (p * pr * (randf()-randf()));
	if (p < 1.0)
	{
		// random variation and non-zero price multiplier can't reduce
		// price below 1 decicredit
		p = 1.0;
	}
	return (OOCreditsQuantity) p;
}


- (OOCargoQuantity) adjustQuantity:(OOCargoQuantity)quantity byRule:(NSDictionary *)rule
{
	float q = (float)quantity; // work in floats to avoid rounding problems
	float qa = oo::PListView(rule).get<float>(kOOCommodityMarketQuantityAdder, 0.0);
	float qm = oo::PListView(rule).get<float>(kOOCommodityMarketQuantityMultiplier, 1.0);
	if (qm <= 0.0 && qa <= 0.0)
	{
		// setting a price multiplier of 0 forces the price to zero
		return 0;
	}
	float qr = oo::PListView(rule).get<float>(kOOCommodityMarketQuantityRandomiser, 0.0);
	q += qa;
	q = (q * qm) + (q * qr * (randf()-randf()));
	if (q < 0.0)
	{
		// random variation and non-zero price multiplier can't reduce
		// quantity below zero
		q = 0.0;
	}
	// may be over station capacity - that gets capped later
	return (OOCargoQuantity) q;
}


- (NSDictionary *) updateInfoFor:(NSDictionary *)good byRule:(NSDictionary *)rule maxCapacity:(OOCargoQuantity)maxCapacity
{
	NSMutableDictionary *tmp = [NSMutableDictionary dictionaryWithDictionary:good];
	NSInteger import = oo::PListView(rule).get<NSInteger>(kOOCommodityMarketLegalityImport, -1);
	if (import >= 0)
	{
		[tmp oo_setInteger:import forKey:kOOCommodityLegalityImport];
	}

	NSInteger exportValue = oo::PListView(rule).get<NSInteger>(kOOCommodityMarketLegalityExport, -1);
	if (exportValue >= 0)
	{
		[tmp oo_setInteger:import forKey:kOOCommodityLegalityExport];
	}

	NSInteger capacity = oo::PListView(rule).get<NSInteger>(kOOCommodityMarketCapacity, -1);
	if (capacity >= 0 && capacity <= (NSInteger)maxCapacity)
	{
		[tmp oo_setInteger:capacity forKey:kOOCommodityCapacity];
	}
	else
	{
		// set to the station max capacity
		[tmp oo_setInteger:maxCapacity forKey:kOOCommodityCapacity];
	}

	return [[tmp copy] autorelease];
}



@end
