/*

OOEquipmentType.m


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

#import "OOEquipmentType.h"
#import "Universe.h"
#import "OOPListView.h"
#import "OOLegacyScriptWhitelist.h"
#import "OOCacheManager.h"
#import "OODebugStandards.h"
#import "PlayerEntityControls.h"
#import "PlayerEntityKeyMapper.h"
#import "OOFoundationBridge.h"
#import "OODebugStandards.h"
#include "oofnd/String.hpp"

static NSArray			*sEquipmentTypes = nil;
static NSArray			*sEquipmentTypesOutfitting = nil;

namespace {
std::map<std::string, oo::ObjCRef<OOEquipmentType *>, std::less<>>	sEquipmentTypesByIdentifier;
std::map<std::string, std::string, std::less<>>						sMissilesRegistry;	// ship key -> missile role
}

 
@interface OOEquipmentType (Private)

- (id) initWithInfo:(NSArray *)info;

@end


@implementation OOEquipmentType
 
+ (void) loadEquipment
{
	NSArray				*equipmentData = nil;
	NSMutableArray		*equipmentTypes = nil;
	NSArray				*itemInfo = nil;
	OOEquipmentType		*item = nil;
	NSMutableArray *conditionScripts = nil;
	
	equipmentData = [UNIVERSE equipmentData];
	
	[sEquipmentTypes release];
	sEquipmentTypes = nil;
	equipmentTypes = [NSMutableArray arrayWithCapacity:[equipmentData count]];
	conditionScripts = [NSMutableArray arrayWithCapacity:[equipmentData count]];
	std::map<std::string, oo::ObjCRef<OOEquipmentType *>, std::less<>> byIdentifier;
	
	foreach (itemInfo, equipmentData)
	{
		item = [[[OOEquipmentType alloc] initWithInfo:itemInfo] autorelease];
		if (item != nil)
		{
			[equipmentTypes addObject:item];
			byIdentifier[*[item cxx_identifier]] = oo::ObjCRef<OOEquipmentType *>(item);
		}
		NSString* condition_script = [item conditionScript];
		if (condition_script != nil)
		{
			if (![conditionScripts containsObject:condition_script])
			{
				[conditionScripts addObject:condition_script];
			}
		}
	}
	
	[[OOCacheManager sharedCache] setObject:conditionScripts forKey:@"equipment conditions" inCache:@"condition scripts"];

	sEquipmentTypes = [equipmentTypes copy];
	sEquipmentTypesByIdentifier = byIdentifier;

	// same for the outfitting dataset
	equipmentData = [UNIVERSE equipmentDataOutfitting];

	[sEquipmentTypesOutfitting release];
	sEquipmentTypesOutfitting = nil;

	equipmentTypes = [NSMutableArray arrayWithCapacity:[equipmentData count]];
	foreach (itemInfo, equipmentData)
	{
		item = [[[OOEquipmentType alloc] initWithInfo:itemInfo] autorelease];
		if (item != nil)
		{
			[equipmentTypes addObject:item];
		}
	}
	sEquipmentTypesOutfitting = [equipmentTypes copy];

}


+ (void) addEquipmentWithInfo:(NSArray *)itemInfo
{
	NSMutableArray		*equipmentTypes = [NSMutableArray arrayWithArray:sEquipmentTypes];
	NSMutableArray		*equipmentTypesOutfitting = [NSMutableArray arrayWithArray:sEquipmentTypesOutfitting];
	OOEquipmentType		*item = [[[OOEquipmentType alloc] initWithInfo:itemInfo] autorelease];
	if (item != nil)
	{
		[equipmentTypes addObject:item];
		[equipmentTypesOutfitting addObject:item];
		
		[sEquipmentTypes release];
		sEquipmentTypes = nil;
		[sEquipmentTypesOutfitting release];
		sEquipmentTypesOutfitting = nil;
		sEquipmentTypes = [equipmentTypes copy];
		sEquipmentTypesOutfitting = [equipmentTypesOutfitting copy];
		sEquipmentTypesByIdentifier[*[item cxx_identifier]] = oo::ObjCRef<OOEquipmentType *>(item);
	}
}


+ (std::optional<std::string>) cxx_getMissileRegistryRoleForShip:(const std::string &)shipKey
{
	const auto entry = sMissilesRegistry.find(shipKey);
	if (entry == sMissilesRegistry.end())  return std::nullopt;
	return entry->second;
}


+ (void) cxx_setMissileRegistryRole:(const std::string &)role forShip:(const std::string &)shipKey
{
	// (the nil checks on role and ship key are the bridge's; the empty key is still refused here)
	if (!shipKey.empty())
	{
		sMissilesRegistry[shipKey] = role;
	}
}


+ (NSArray *) allEquipmentTypes
{
	return sEquipmentTypes;
}


+ (NSEnumerator *) equipmentEnumerator
{
	return [sEquipmentTypes objectEnumerator];
}


+ (NSEnumerator *) reverseEquipmentEnumerator
{
	return [sEquipmentTypes reverseObjectEnumerator];
}


+ (NSEnumerator *) equipmentEnumeratorOutfitting
{
	return [sEquipmentTypesOutfitting objectEnumerator];
}


+ (OOEquipmentType *) cxx_equipmentTypeWithIdentifier:(const std::string &)identifier
{
	const auto entry = sEquipmentTypesByIdentifier.find(identifier);
	return (entry != sEquipmentTypesByIdentifier.end()) ? entry->second.get() : nil;
}


- (id) initWithInfo:(NSArray *)info
{
	BOOL				OK = YES;
	NSDictionary		*extra = nil;
	NSArray				*conditions = nil;
	NSString			*condition_script = nil;
	NSArray				*keydef = nil;

	self = [super init];
	if (self == nil)  OK = NO;
	
	if (OK && [info count] <= EQUIPMENT_LONG_DESC_INDEX)  OK = NO;
	
	if (OK)
	{
		// Read required attributes
		_techLevel = oo::PListView(info).at<unsigned int>(EQUIPMENT_TECH_LEVEL_INDEX);
		_price = oo::PListView(info).at<unsigned int>(EQUIPMENT_PRICE_INDEX);
		id name = oo::PListView(info).at<NSString *>(EQUIPMENT_SHORT_DESC_INDEX);
		id identifier = oo::PListView(info).at<NSString *>(EQUIPMENT_KEY_INDEX);
		id description = oo::PListView(info).at<NSString *>(EQUIPMENT_LONG_DESC_INDEX);

		if (name == nil || identifier == nil || description == nil)
		{
			OOLog(@"equipment.load", @"***** ERROR: Invalid equipment.plist entry - missing name, identifier or description (\"%@\", %@, \"%@\")", name, identifier, description);
			OK = NO;
		}
		else
		{
			_name = oo::StdString(name);
			_identifier = oo::StdString(identifier);
			_description = oo::StdString(description);
		}
	}
	
	if (OK)
	{
		// Implied attributes for backwards-compatibility
		if (oo::str::hasSuffix(_identifier, "_MISSILE") || oo::str::hasSuffix(_identifier, "_MINE"))
		{
			_isMissileOrMine = YES;
			_requiresEmptyPylon = YES;
		}
		else if (_identifier == "EQ_PASSENGER_BERTH_REMOVAL")
		{
			_requiresFreePassengerBerth = YES;
		}
		else if (_identifier == "EQ_FUEL")
		{
			_requiresNonFullFuel = YES;
		}
		_isVisible = YES;
		_isAvailableToPlayer = YES;
		_isAvailableToNPCs = YES;
		_damageProbability = 1.0;
		_hideValues = NO;
	}
	
	if (OK && [info count] > EQUIPMENT_EXTRA_INFO_INDEX)
	{
		// Read extra info dictionary
		extra = oo::PListView(info).at<NSDictionary *>(EQUIPMENT_EXTRA_INFO_INDEX);
		if (extra != nil)
		{
			
			_isAvailableToAll = (unsigned char)oo::PListView(extra).get<BOOL>(@"available_to_all", _isAvailableToAll);
			_isAvailableToPlayer = (unsigned char)oo::PListView(extra).get<BOOL>(@"available_to_player", _isAvailableToPlayer);
			_isAvailableToNPCs = (unsigned char)oo::PListView(extra).get<BOOL>(@"available_to_NPCs", _isAvailableToNPCs);
			
			_isMissileOrMine = (unsigned char)oo::PListView(extra).get<BOOL>(@"is_external_store", _isMissileOrMine);
			_requiresEmptyPylon = (unsigned char)oo::PListView(extra).get<BOOL>(@"requires_empty_pylon", _requiresEmptyPylon);
			_requiresMountedPylon = (unsigned char)oo::PListView(extra).get<BOOL>(@"requires_mounted_pylon", _requiresMountedPylon);
			_requiresClean = (unsigned char)oo::PListView(extra).get<BOOL>(@"requires_clean", _requiresClean);
			_requiresNotClean = (unsigned char)oo::PListView(extra).get<BOOL>(@"requires_not_clean", _requiresNotClean);
			_portableBetweenShips = (unsigned char)oo::PListView(extra).get<BOOL>(@"portable_between_ships", _portableBetweenShips);
			_requiresFreePassengerBerth = (unsigned char)oo::PListView(extra).get<BOOL>(@"requires_free_passenger_berth", _requiresFreePassengerBerth);
			_requiresFullFuel = (unsigned char)oo::PListView(extra).get<BOOL>(@"requires_full_fuel", _requiresFullFuel);
			_requiresNonFullFuel = (unsigned char)oo::PListView(extra).get<BOOL>(@"requires_non_full_fuel", _requiresNonFullFuel);
			_isVisible = (unsigned char)oo::PListView(extra).get<BOOL>(@"visible", _isVisible);
			_canCarryMultiple = (unsigned char)oo::PListView(extra).get<BOOL>(@"can_carry_multiple", NO);
			_hideValues = (unsigned char)oo::PListView(extra).get<BOOL>(@"hide_values", NO);

			_requiredCargoSpace = oo::PListView(extra).get<unsigned int>(@"requires_cargo_space", _requiredCargoSpace);

			_installTime = oo::PListView(extra).get<unsigned int>(@"installation_time", 0);
			_repairTime = oo::PListView(extra).get<unsigned int>(@"repair_time", 0);
			_provides = [oo::PListView(extra).get<NSArray *>(@"provides", [NSArray array]) retain];

			id dispColor = oo::PListView(extra).get<id>(@"display_color", nil);
			_displayColor = [[OOColor colorWithDescription:dispColor] retain];

			_weaponInfo = [oo::PListView(extra).get<NSDictionary *>(@"weapon_info", [NSDictionary dictionary]) retain];

			_damageProbability = oo::PListView(extra).get<float>(@"damage_probability", (_isMissileOrMine?0.0:1.0));
			
			id object = [extra objectForKey:@"requires_equipment"];
			if ([object isKindOfClass:[NSString class]])  _requiresEquipment = [[NSSet setWithObject:object] retain];
			else if ([object isKindOfClass:[NSArray class]])  _requiresEquipment = [[NSSet setWithArray:object] retain];
			else if (object != nil)
			{
				OOLog(@"equipment.load", @"***** ERROR: %@ for equipment item %@ is not a string or an array.", @"requires_equipment", oo::NSStringFrom(_identifier));
			}
			
			object = [extra objectForKey:@"requires_any_equipment"];
			if ([object isKindOfClass:[NSString class]])  _requiresAnyEquipment = [[NSSet setWithObject:object] retain];
			else if ([object isKindOfClass:[NSArray class]])  _requiresAnyEquipment = [[NSSet setWithArray:object] retain];
			else if (object != nil)
			{
				OOLog(@"equipment.load", @"***** ERROR: %@ for equipment item %@ is not a string or an array.", @"requires_any_equipment", oo::NSStringFrom(_identifier));
			}
			
			object = [extra objectForKey:@"incompatible_with_equipment"];
			if ([object isKindOfClass:[NSString class]])  _incompatibleEquipment = [[NSSet setWithObject:object] retain];
			else if ([object isKindOfClass:[NSArray class]])  _incompatibleEquipment = [[NSSet setWithArray:object] retain];
			else if (object != nil)
			{
				OOLog(@"equipment.load", @"***** ERROR: %@ for equipment item %@ is not a string or an array.", @"incompatible_with_equipment", oo::NSStringFrom(_identifier));
			}
			
			object = [extra objectForKey:@"conditions"];
			if ([object isKindOfClass:[NSString class]])  conditions = [NSArray arrayWithObject:object];
			else if ([object isKindOfClass:[NSArray class]])  conditions = object;
			else if (object != nil)
			{
				OOLog(@"equipment.load", @"***** ERROR: %@ for equipment item %@ is not a string or an array.", @"conditions", oo::NSStringFrom(_identifier));
			}
			if (conditions != nil)
			{
				OOStandardsDeprecated([NSString stringWithFormat:@"The conditions key is deprecated for equipment %@",oo::NSStringFrom(_name)]);
				if (!OOEnforceStandards())
				{
					_conditions = oo::ObjectFromPList(OOSanitizeLegacyScriptConditions(oo::PListFrom(conditions), oo::OptionalString([NSString stringWithFormat:@"<equipment type \"%@\">", oo::NSStringFrom(_name)])));
					[_conditions retain];
				}
			}

			object = [extra objectForKey:@"condition_script"];
			if ([object isKindOfClass:[NSString class]])
			{
				condition_script = object;
			}
			else if (object != nil)
			{
				OOLog(@"equipment.load", @"***** ERROR: %@ for equipment item %@ is not a string.", @"condition_script", oo::NSStringFrom(_identifier));
			}
			if (condition_script != nil)
			{
				_condition_script = [condition_script retain];
			}
			/* Condition scripts are shared: all equipment/ships using the
			 * same condition script use one shared instance. Equipment
			 * scripts and ship scripts are not shared and get one instance
			 * per item. */
			
			_scriptInfo = oo::PListView(extra).get<NSDictionary *>(@"script_info");
			[_scriptInfo retain];
			
			_script = oo::PListView(extra).get<NSString *>(@"script");
			if (_script != nil && ![OOScript jsScriptFromFileNamed:_script properties:nil])  _script = nil;
			[_script retain];
			if (_script != nil)
			{
				_fastAffinityA = !!oo::PListView(extra).get<BOOL>(@"fast_affinity_defensive");
				_fastAffinityB = !!oo::PListView(extra).get<BOOL>(@"fast_affinity_offensive");

				// look for default activate and mode key settings
				// note: the customEquipmentActivation array is only populated when starting a game
				// so the application of any default key settings on equipment will only happen then
				NSString *checking;

				object = [extra objectForKey:@"default_activate_key"];
				if ([object isKindOfClass:[NSArray class]]) keydef = object;
				else if (object != nil)
				{
					OOLog(@"equipment.load", @"***** ERROR: %@ for equipment item %@ is not an array.", @"default_activate_key", oo::NSStringFrom(_identifier));
					object = nil;
				}

				if (object != nil) 
				{
					// do processing for key
					_defaultActivateKey = [PLAYER processKeyCode:keydef];
					checking = oo::NSStringOrNil([PLAYER validateKey:"activate_" + _identifier checkKeys:oo::PListFrom(_defaultActivateKey)]);
					
					if (checking != nil) {
						OOLog(@"equipment.load", @"***** Error: %@ for equipment item %@ is already in use for %@. Default not applied", @"default_activate_key", oo::NSStringFrom(_identifier), checking);
						_defaultActivateKey = nil;
					} 
				}

				object = [extra objectForKey:@"default_mode_key"];
				if ([object isKindOfClass:[NSArray class]]) keydef = object;
				else if (object != nil)
				{
					OOLog(@"equipment.load", @"***** ERROR: %@ for equipment item %@ is not an array.", @"default_mode_key", oo::NSStringFrom(_identifier));
					object = nil;
				}

				if (object != nil) 
				{
					// do processing for key
					_defaultModeKey = [PLAYER processKeyCode:keydef];
					checking = oo::NSStringOrNil([PLAYER validateKey:"mode_" + _identifier checkKeys:oo::PListFrom(_defaultModeKey)]);
					
					if (checking != nil) {
						OOLog(@"equipment.load", @"***** Error: %@ for equipment item %@ is already in use for %@. Default not applied.", @"default_mode_key", oo::NSStringFrom(_identifier), checking);
						_defaultModeKey = nil;
					} 
				}
			}
		}
	}
	
	if (!OK)
	{
		[self release];
		self = nil;
	}
	return self;
}


- (void) dealloc
{
	DESTROY(_displayColor);
	DESTROY(_requiresEquipment);
	DESTROY(_requiresAnyEquipment);
	DESTROY(_incompatibleEquipment);
	DESTROY(_conditions);
	DESTROY(_condition_script);
	DESTROY(_provides);
	DESTROY(_weaponInfo);
	DESTROY(_scriptInfo);
	DESTROY(_script);
	DESTROY(_defaultActivateKey);
	DESTROY(_defaultModeKey);
	
	[super dealloc];
}


- (id) copyWithZone:(OOZone *)zone
{
	// OOEquipmentTypes are immutable.
	return [self retain];
}


- (id) descriptionComponents	// shared selector (proposed ADR-0043)
{
	return oo::NSStringFrom(oo::str::format("%s \"%s\"", _identifier.c_str(), _name.c_str()));
}


- (std::optional<std::string>) cxx_identifier
{
	return _identifier;
}


- (std::optional<std::string>) cxx_damagedIdentifier
{
	return _identifier + "_DAMAGED";
}


- (id) name	// shared selector (proposed ADR-0043)
{
	return oo::NSStringFrom(_name);
}


- (std::optional<std::string>) cxx_descriptiveText
{
	return _description;
}


- (OOTechLevelID) techLevel
{
	return _techLevel;
}


- (OOCreditsQuantity) price
{
	return _price;
}


- (BOOL) isAvailableToAll
{
	return _isAvailableToAll;
}


- (BOOL) requiresEmptyPylon
{
	return _requiresEmptyPylon;
}


- (BOOL) requiresMountedPylon
{
	return _requiresMountedPylon;
}


- (BOOL) requiresCleanLegalRecord
{
	return _requiresClean;
}


- (BOOL) requiresNonCleanLegalRecord
{
	return _requiresNotClean;
}


- (BOOL) requiresFreePassengerBerth
{
	return _requiresFreePassengerBerth;
}


- (BOOL) requiresFullFuel
{
	return _requiresFullFuel;
}


- (BOOL) requiresNonFullFuel
{
	return _requiresNonFullFuel;
}


- (BOOL) isPrimaryWeapon
{
	return oo::str::hasPrefix(_identifier, "EQ_WEAPON");
}


- (BOOL) isMissileOrMine
{
	return _isMissileOrMine;	
}


- (BOOL) isPortableBetweenShips
{
	return _portableBetweenShips;
}


- (BOOL) canCarryMultiple
{
	if ([self isMissileOrMine])  return YES;
	// technically multiple can be fitted, but not to the same mount.
	if ([self isPrimaryWeapon])  return NO;
	
	// hard-coded as special items
	if (_identifier == "EQ_PASSENGER_BERTH" ||
		_identifier == "EQ_TRUMBLE")
	{
		return YES;
	}
	
	return _canCarryMultiple;
}


- (GLfloat) damageProbability 
{
	if ([self isMissileOrMine])  return 0.0;

	return _damageProbability;
}


- (BOOL) canBeDamaged
{
	if ([self isMissileOrMine])  return NO;
	
	if ([self damageProbability] > 0.0)
	{
		return YES;
	}
	
	return NO;
}


- (BOOL) isVisible
{
	return _isVisible;
}


- (BOOL) hideValues
{
	return _hideValues;
}


- (BOOL) isAvailableToPlayer
{
	return _isAvailableToPlayer;
}


- (BOOL) isAvailableToNPCs
{
	return _isAvailableToNPCs;
}


- (OOCargoQuantity) requiredCargoSpace
{
	return _requiredCargoSpace;
}


- (NSSet *) requiresEquipment
{
	return _requiresEquipment;
}


- (NSSet *) requiresAnyEquipment
{
	return _requiresAnyEquipment;
}


- (NSSet *) incompatibleEquipment
{
	return _incompatibleEquipment;
}


- (OOColor *) displayColor
{
	return _displayColor;
}


- (void) setDisplayColor:(OOColor *)color
{
	[_displayColor release];
	_displayColor = [color retain];
}


- (NSArray *) conditions
{
	return _conditions;
}


- (NSString *) conditionScript
{
	return _condition_script;
}


- (NSDictionary *) scriptInfo
{
	return _scriptInfo;
}


- (NSString *) scriptName
{
	return _script;
}


- (BOOL) fastAffinityDefensive
{
	return _fastAffinityA;
}


- (BOOL) fastAffinityOffensive
{
	return _fastAffinityB;
}


- (NSArray *) defaultActivateKey
{
	return _defaultActivateKey;
}


- (NSArray *) defaultModeKey
{
	return _defaultModeKey;
}


- (NSUInteger) installTime
{
	return _installTime;
}


- (NSUInteger) repairTime
{
	if (_repairTime > 0)
	{
		return _repairTime;
	}
	else 
	{
		return _installTime / 2;
	}
}


- (NSArray *) providesForScripting
{
	return [[_provides copy] autorelease];
}


- (BOOL) provides:(NSString *)key
{
	return [_provides containsObject:key];
}


// weapon properties follow
- (BOOL) isTurretLaser
{
	return oo::PListView(_weaponInfo).get<BOOL>(@"is_turret_laser", NO);
}


- (BOOL) isMiningLaser
{
	return oo::PListView(_weaponInfo).get<BOOL>(@"is_mining_laser", NO);
}


- (NSDictionary *) weaponInfo
{
	return _weaponInfo;
}


- (GLfloat) weaponRange
{
	return oo::PListView(_weaponInfo).get<float>(@"range", 12500.0);
}


- (GLfloat) weaponEnergyUse
{
	return oo::PListView(_weaponInfo).get<float>(@"energy", 0.8);
}


- (GLfloat) weaponDamage
{
	return oo::PListView(_weaponInfo).get<float>(@"damage", 15.0);
}


- (GLfloat) weaponRechargeRate
{
	return oo::PListView(_weaponInfo).get<float>(@"recharge_rate", 0.5);
}


- (GLfloat) weaponShotTemperature
{
	return oo::PListView(_weaponInfo).get<float>(@"shot_temperature", 7.0);
}


- (GLfloat) weaponThreatAssessment
{
	return oo::PListView(_weaponInfo).get<float>(@"threat_assessment", 1.0);
}


- (OOColor *) weaponColor
{
	return [OOColor brightColorWithDescription:[_weaponInfo objectForKey:@"color"]];
}


- (NSString *) fxShotMissName
{
	return oo::PListView(_weaponInfo).get<NSString *>(@"fx_shot_miss_name", @"[player-laser-miss]");
}


- (NSString *) fxShotHitName
{
	return oo::PListView(_weaponInfo).get<NSString *>(@"fx_shot_hit_name", @"[player-laser-hit]");
}


- (NSString *) fxShieldHitName
{
	return oo::PListView(_weaponInfo).get<NSString *>(@"fx_hitplayer_shielded_name", @"[player-hit-by-weapon]");
}


- (NSString *) fxUnshieldedHitName
{
	return oo::PListView(_weaponInfo).get<NSString *>(@"fx_hitplayer_unshielded_name", @"[player-direct-hit]");
}


- (NSString *) fxWeaponLaunchedName
{
	return oo::PListView(_weaponInfo).get<NSString *>(@"fx_weapon_launch_name", (oo::str::hasSuffix(_identifier, "_MINE") ? @"[mine-launched]" : @"[missile-launched]"));
}


/*	This method exists purely to suppress Clang static analyzer warnings that
	this ivar is unused (but may be used by categories, which it is).
	FIXME: there must be a feature macro we can use to avoid actually building
	this into the app, but I can't find it in docs.
*/
- (BOOL) suppressClangStuff
{
	return !_jsSelf;
}

@end


#import "PlayerEntityLegacyScriptEngine.h"

@implementation OOEquipmentType (Conveniences)

- (OOTechLevelID) effectiveTechLevel
{
	OOTechLevelID			tl;
	id						missionVar = nil;
	
	tl = [self techLevel];
	if (tl == kOOVariableTechLevel)
	{
		cxx_OOStandardsDeprecated(oo::str::format("TL99 is deprecated for %s", _identifier.c_str()));
		if (!OOEnforceStandards())
		{
			missionVar = [PLAYER missionVariableForKey:oo::NSStringFrom("mission_TL_FOR_" + _identifier)];
			tl = OOUIntegerFromObject(missionVar, tl);
		}
	}
	
	return tl;
}

@end
