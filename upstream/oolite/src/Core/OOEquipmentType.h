/*

OOEquipmentType.h

Class representing a type of ship equipment. Exposed to JavaScript as
EquipmentInfo.


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

#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"
#include "ooscript/JSEngine.hpp"
#import "OOTypes.h"
#import "OOScript.h"
#import "Universe.h"
#include "oofnd/objc/OOObjCRef.h"

#include <map>
#include <optional>
#include <string>


@interface OOEquipmentType: OOObject <OOCopying>
{
@private
	OOTechLevelID			_techLevel;
	OOCreditsQuantity		_price;
	std::string				_name;			// never empty-for-nil: -initWithInfo: fails without all three
	std::string				_identifier;
	std::string				_description;
	unsigned				_isAvailableToAll: 1,
							_requiresEmptyPylon: 1,
							_requiresMountedPylon: 1,
							_requiresClean: 1,
							_requiresNotClean: 1,
							_portableBetweenShips: 1,
							_requiresFreePassengerBerth: 1,
							_requiresFullFuel: 1,
							_requiresNonFullFuel: 1,
							_isMissileOrMine: 1,
							_isVisible: 1,
							_isAvailableToPlayer: 1,
							_isAvailableToNPCs: 1,
							_fastAffinityA: 1,
							_fastAffinityB: 1,
							_canCarryMultiple: 1,
							_hideValues: 1;
	OOColor					*_displayColor;
	NSUInteger				_installTime;
	NSUInteger				_repairTime;
	GLfloat     			_damageProbability;
	OOCargoQuantity			_requiredCargoSpace;
	NSSet					*_requiresEquipment;
	NSSet					*_requiresAnyEquipment;
	NSSet					*_incompatibleEquipment;
	NSArray					*_conditions;
	NSArray					*_provides;
	NSArray					*_defaultActivateKey;
	NSArray					*_defaultModeKey;
	NSDictionary			*_scriptInfo;
	NSDictionary			*_weaponInfo;
	NSString				*_script;
	NSString				*_condition_script;
	
	ooscript::Object _jsSelf;
}

+ (void) loadEquipment;			// Load equipment data; called on loading and when changing to/from strict mode.
+ (void) addEquipmentWithInfo:(NSArray *)itemInfo;	// Used to generate equipment from missile_role entries.

+ (std::optional<std::string>) cxx_getMissileRegistryRoleForShip:(const std::string &)shipKey;	// nullopt: none registered
+ (void) cxx_setMissileRegistryRole:(const std::string &)role forShip:(const std::string &)shipKey;

+ (NSArray *) allEquipmentTypes;
+ (NSEnumerator *) equipmentEnumerator;
+ (NSEnumerator *) reverseEquipmentEnumerator;
+ (NSEnumerator *) equipmentEnumeratorOutfitting;

+ (OOEquipmentType *) cxx_equipmentTypeWithIdentifier:(const std::string &)identifier;	// nil: none

- (std::optional<std::string>) cxx_identifier;
- (std::optional<std::string>) cxx_damagedIdentifier;
- (id) name;			// localized; shared selector (proposed ADR-0043): a string
- (std::optional<std::string>) cxx_descriptiveText;	// localized
- (OOTechLevelID) techLevel;
- (OOCreditsQuantity) price;	// Tenths of credits

- (BOOL) isAvailableToAll;
- (BOOL) requiresEmptyPylon;
- (BOOL) requiresMountedPylon;
- (BOOL) requiresCleanLegalRecord;
- (BOOL) requiresNonCleanLegalRecord;
- (BOOL) requiresFreePassengerBerth;
- (BOOL) requiresFullFuel;
- (BOOL) requiresNonFullFuel;
- (BOOL) isPrimaryWeapon;
- (BOOL) isMissileOrMine;
- (BOOL) isPortableBetweenShips;

- (BOOL) canCarryMultiple;
- (GLfloat) damageProbability;
- (BOOL) canBeDamaged;
- (BOOL) isVisible;				// Visible in UI?
- (BOOL) hideValues;
- (OOColor *) displayColor;
- (void) setDisplayColor:(OOColor *)newColor;

- (BOOL) isAvailableToPlayer;
- (BOOL) isAvailableToNPCs;

- (OOCargoQuantity) requiredCargoSpace;
- (NSSet *) requiresEquipment;		// Set of equipment identifiers; all items required
- (NSSet *) requiresAnyEquipment;	// Set of equipment identifiers; any item required
- (NSSet *) incompatibleEquipment;	// Set of equipment identifiers; all items prohibited

// FIXME: should have general mechanism to handle scripts or legacy conditions.
- (NSArray *) conditions;

- (NSString *) conditionScript;

- (NSDictionary *) scriptInfo;
- (NSString *) scriptName;

- (BOOL) fastAffinityDefensive;
- (BOOL) fastAffinityOffensive;

- (NSArray *) defaultActivateKey;
- (NSArray *) defaultModeKey;

- (NSUInteger) installTime;
- (NSUInteger) repairTime;

- (NSArray *) providesForScripting;
- (BOOL) provides:(NSString *)key;

// weapon properties
- (BOOL) isTurretLaser;
- (BOOL) isMiningLaser;
- (NSDictionary *) weaponInfo;
- (GLfloat) weaponRange;
- (GLfloat) weaponEnergyUse;
- (GLfloat) weaponDamage;
- (GLfloat) weaponRechargeRate;
- (GLfloat) weaponShotTemperature;
- (GLfloat) weaponThreatAssessment;
- (OOColor *) weaponColor;
- (NSString *) fxShotMissName;
- (NSString *) fxShotHitName;
- (NSString *) fxShieldHitName;
- (NSString *) fxUnshieldedHitName;
- (NSString *) fxWeaponLaunchedName;

@end


@interface OOEquipmentType (Conveniences)

- (OOTechLevelID) effectiveTechLevel;

@end


/*	TRANSITIONAL (proposed ADR-0043, "Transitional bridges"): the Foundation-typed API this header
	declared before bead oo-fvnu (chunks oo-3rb.156..159), forwarding to the cxx_ methods above, so
	unmigrated callers compile unchanged. Callers move to the cxx_ API in their own sweep beads.
*/
#import "OOEquipmentType+FoundationBridge.h"
