/*

OOConstToString.h

Convert various sets of integer constants to strings.
To consider: replacing the integer constants with string constants.
 See also: OOConstToJSString.h.

This has grown beyond "const-to-string" at this point.

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

#import <Foundation/Foundation.h>
#include "ooscript/JSEngine.hpp"
#import "OOFunctionAttributes.h"
#import "OOTypes.h"
#import "MyOpenGLView.h"

enum
{
	// Values used for unknown strings.
	kOOCargoTypeDefault			= CARGO_NOT_CARGO,
//	kOOCommodityTypeDefault		= COMMODITY_UNDEFINED,
	kOOEnergyUnitTypeDefault	= ENERGY_UNIT_NONE,
	kOORouteTypeDefault			= OPTIMIZED_BY_JUMPS
};

/*

To avoid pulling in unnecessary headers, some functions defined in
OOConstToString.m are declared in the header with the appropriate type
declaration, in particular:

	Entity.h:
	OOStringFromEntityStatus()
	OOEntityStatusFromString()
	OOStringFromScanClass()
	OOScanClassFromString()

	ShipEntity.h:
	OOStringFromBehaviour()
	OOEquipmentIdentifierFromWeaponType()
	OOWeaponTypeFromEquipmentIdentifierSloppy()
	OOWeaponTypeFromEquipmentIdentifierStrict()
	OOStringFromWeaponType()
	OOWeaponTypeFromString()
	OODisplayStringFromAlertCondition()
	
	PlayerEntity.h:
	OODisplayRatingStringFromKillCount()
	KillCountToRatingAndKillString()
	OODisplayStringFromLegalStatus()
	OOStringFromGUIScreenID()
	OOGUIScreenIDFromString()
	OOGalacticHyperspaceBehaviourFromString()
	OOStringFromGalacticHyperspaceBehaviour()
	
	Universe.h:
	OODisplayStringFromGovernmentID()
	OODisplayStringFromEconomyID()

*/

#ifdef __cplusplus
extern "C" {
#endif

//NSString *CommodityTypeToString(OOCommodityType commodity) CONST_FUNC;	// returns the commodity identifier
//OOCommodityType StringToCommodityType(NSString *string) PURE_FUNC;		// needs commodity identifier

NSString *CommodityDisplayNameForSymbolicName(NSString *symbolicName);
NSString *CommodityDisplayNameForCommodityArray(NSArray *commodityDefinition);

NSString *DisplayStringForMassUnit(OOMassUnit unit);
NSString *DisplayStringForMassUnitForCommodity(OOCommodityType commodity);

NSString *OOStringFromCompassMode(OOCompassMode mode);
OOCompassMode OOCompassModeFromString(NSString *string);

NSString *OOStringFromLongRangeChartMode(OOLongRangeChartMode chartMode);
OOLongRangeChartMode OOLongRangeChartModeFromString(NSString *string);

NSString *OOStringFromLegalStatusReason(OOLegalStatusReason reason);

#ifdef __cplusplus
}
#endif

#ifdef __cplusplus
// C++ forms (bead oo-nts1, chunk oo-3rb.160): std::string results (never nil) and const
// std::string & parameters (the old nil arrived as "" and matched nothing: the same defaults).
// The Foundation forms live in OOConstToString+FoundationBridge.h.
std::string cxx_JSTypeToString(int /* ooscript::Type */ type);
std::string cxx_CargoTypeToString(OOCargoType cargo);
OOCargoType cxx_StringToCargoType(const std::string &string);
std::string cxx_EnergyUnitTypeToString(OOEnergyUnitType unit);
OOEnergyUnitType cxx_StringToEnergyUnitType(const std::string &string);
std::string cxx_RouteTypeToString(OORouteType routeType);
OORouteType cxx_StringToRouteType(const std::string &string);
std::string cxx_DockingClearanceStatusToString(OODockingClearanceStatus dockingClearanceStatus);
std::string cxx_OOStringFromGraphicsDetail(OOGraphicsDetail detail);
OOGraphicsDetail cxx_OOGraphicsDetailFromString(const std::string &string);
std::string cxx_OOStringFromHDRToneMapper(OOHDRToneMapper toneMapper);
OOHDRToneMapper cxx_OOHDRToneMapperFromString(const std::string &string);
std::string cxx_OOStringFromSDRToneMapper(OOSDRToneMapper toneMapper);
OOSDRToneMapper cxx_OOSDRToneMapperFromString(const std::string &string);
#endif


// Shader settings (OOShaderSetting is OOOpenGL.h's), with C++ linkage as when OOOpenGL.h declared them.
// Programmer-readable shader mode strings.
OOShaderSetting OOShaderSettingFromString(NSString *string);
NSString *OOStringFromShaderSetting(OOShaderSetting setting);
// Localized shader mode strings.
NSString *OODisplayStringFromShaderSetting(OOShaderSetting setting);


/*	TRANSITIONAL (proposed ADR-0043, "Transitional bridges"): the Foundation-typed functions this
	header declared before bead oo-nts1 (chunks oo-3rb.160..163), forwarding to the cxx_ functions,
	so unmigrated callers compile unchanged. Callers move to the cxx_ forms in their own sweep beads.
*/
#import "OOConstToString+FoundationBridge.h"
