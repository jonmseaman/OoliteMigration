/*

PlayerEntity+FoundationBridge.mm

TRANSITIONAL: see PlayerEntity+FoundationBridge.h. Each method forwards to its cxx_ counterpart
and converts the result exactly as the old method produced it.

*/

#import "PlayerEntity.h"	// declares the bridge category at its end
#import "OOFoundationBridge.h"
#import "OOJavaScriptEngine.h"	// OONull


@implementation PlayerEntity (FoundationBridge)

// oo-3rb.164: a dictionary of arrays keyed by +numberWithInt: of the system ID, each array's
// markers in the order they were added (as -prepareMarkedDestination:: built it).
- (NSDictionary *) markedDestinations
{
	NSMutableDictionary *destinations = [NSMutableDictionary dictionaryWithCapacity:256];
	const std::optional<std::map<int, std::vector<oo::PList>>> markers = [self cxx_markedDestinations];
	if (markers.has_value())
	{
		for (const auto &[system, list] : *markers)
		{
			NSMutableArray *array = [NSMutableArray arrayWithCapacity:list.size()];
			for (const oo::PList &marker : list)
			{
				id object = oo::ObjectFromPList(marker);
				if (object != nil)  [array addObject:object];
			}
			[destinations setObject:array forKey:[NSNumber numberWithInt:system]];
		}
	}
	return destinations;
}


// oo-3rb.243: HUD switching, custom dials and multi-function displays
- (BOOL) switchHudTo:(NSString *)hudFileName
{
	if (hudFileName == nil)  return NO;
	return [self cxx_switchHudTo:oo::StdString(hudFileName)];
}


- (float) dialCustomFloat:(NSString *)dialKey
{
	return [self cxx_dialCustomFloat:oo::StdString(dialKey)];
}


- (NSString *) dialCustomString:(NSString *)dialKey
{
	return oo::NSStringFrom([self cxx_dialCustomString:oo::StdString(dialKey)]);
}


- (OOColor *) dialCustomColor:(NSString *)dialKey
{
	return [self cxx_dialCustomColor:oo::StdString(dialKey)];
}


- (void) setDialCustom:(id)value forKey:(NSString *)key
{
	[self cxx_setDialCustom:value forKey:oo::StdString(key)];
}


- (NSArray *) multiFunctionDisplayList
{
	NSMutableArray *list = [NSMutableArray array];
	for (const std::optional<std::string> &key : [self cxx_multiFunctionDisplayList])
	{
		if (key.has_value())  [list addObject:oo::NSStringFrom(*key)];
		else  [list addObject:[OONull null]];
	}
	return list;
}


- (NSString *) multiFunctionText:(NSUInteger) index
{
	return oo::NSStringOrNil([self cxx_multiFunctionText:index]);
}


- (void) setMultiFunctionText:(NSString *)text forKey:(NSString *)key
{
	[self cxx_setMultiFunctionText:oo::OptionalString(text) forKey:oo::OptionalString(key)];
}


- (BOOL) setMultiFunctionDisplay:(NSUInteger) index toKey:(NSString *)key
{
	return [self cxx_setMultiFunctionDisplay:index toKey:oo::OptionalString(key)];
}


- (NSString *) dial_clock
{
	return oo::NSStringFrom([self cxx_dial_clock]);
}


- (NSString *) dial_clock_adjusted
{
	return oo::NSStringFrom([self cxx_dial_clock_adjusted]);
}


- (NSString *) dial_fpsinfo
{
	return oo::NSStringFrom([self cxx_dial_fpsinfo]);
}


- (NSString *) dial_objinfo
{
	return oo::NSStringFrom([self cxx_dial_objinfo]);
}


- (NSString *) compassTargetLabel
{
	return oo::NSStringOrNil([self cxx_compassTargetLabel]);
}


- (NSString *) dialTargetName
{
	return oo::NSStringOrNil([self cxx_dialTargetName]);
}

@end
