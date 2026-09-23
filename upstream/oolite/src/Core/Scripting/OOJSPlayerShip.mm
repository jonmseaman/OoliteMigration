/*

OOJSPlayerShip.h

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

#import "OOCollectionExtractors.h"
#import "OOJSPlayerShip.h"
#import "OOJSPlayer.h"
#import "OOJSEntity.h"
#import "OOJSShip.h"
#import "OOJSVector.h"
#import "OOJSQuaternion.h"
#import "OOJavaScriptEngine.h"
#import "EntityOOJavaScriptExtensions.h"
#import "OOSystemDescriptionManager.h"
#import "PlayerEntity.h"
#import "PlayerEntityControls.h"
#import "PlayerEntityContracts.h"
#import "PlayerEntityScriptMethods.h"
#import "PlayerEntityLegacyScriptEngine.h"
#import "PlayerEntitySound.h"
#import "HeadUpDisplay.h"
#import "StationEntity.h"

#import "OOConstToJSString.h"
#import "OOConstToString.h"
#import "OOFunctionAttributes.h"
#import "OOEquipmentType.h"
#import "OOJSEquipmentInfo.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar): the class dispatch table becomes a static ooscript::ClassDef
	(the stub hooks are nullptr), InitClass/DefineObject become ooscript::initClass /
	ooscript::defineObject, native methods and class hooks take the façade's hook signature
	(Context/Object/PropertyId/Value pointer/CallArgs reference), and the directly spelled
	numeric-conversion calls (NewNumberValue, ValueToNumber, ValueToBoolean, ValueToInt32,
	ValueToECMAUint32, SetPrivate, RemoveObjectRoot) become their ooscript:: façade
	equivalents. Natives take the
	façade signature directly (ooscript::Context and a CallArgs reference) and the OOJS_*
	argument-marshalling macros expand to the CallArgs accessors, so the rest of each function
	body is UNCHANGED. `this` is renamed to `thisObj` because it
	is a reserved word once this file compiles as Objective-C++ (ADR-0001).
*/
namespace ooscript { }
using ooscript::Context;
using ooscript::Object;
using ooscript::Value;
using ooscript::PropertyId;
using ooscript::CallArgs;
using ooscript::ClassDef;
using ooscript::ClassFlag;
using ooscript::PropertyFlag;
using ooscript::PropertySpec;
using ooscript::FunctionSpec;

// Byte-identical façade <-> jsapi views, local to this call site (see OOJSVector.mm).
namespace {
static inline Object    *OOJSFOBJP(ooscript::Object *o)  { return reinterpret_cast<Object*>(o); }
} // namespace


namespace {
static ooscript::Object sPlayerShipPrototype;
} // namespace
namespace {
static ooscript::Object sPlayerShipObject;
} // namespace


namespace {
static bool PlayerShipGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool PlayerShipSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace

namespace {
static bool PlayerShipLaunch(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipRemoveAllCargo(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipUseSpecialCargo(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipEngageAutopilotToStation(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipDisengageAutopilot(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipRequestDockingClearance(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipCancelDockingRequest(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipAwardEquipmentToCurrentPylon(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipAddPassenger(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipRemovePassenger(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipAddParcel(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipRemoveParcel(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipAwardContract(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipRemoveContract(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipSetCustomView(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipSetPrimedEquipment(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipResetCustomView(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipResetScannerZoom(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipTakeInternalDamage(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipBeginHyperspaceCountdown(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipCancelHyperspaceCountdown(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipBeginGalacticHyperspaceCountdown(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipSetMultiFunctionDisplay(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipSetMultiFunctionText(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipHideHUDSelector(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipShowHUDSelector(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool PlayerShipSetCustomHUDDial(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace

namespace {
static BOOL ValidateContracts(ooscript::Context context, ooscript::CallArgs &oojsArgs, BOOL isCargo, OOSystemID *start, OOSystemID *destination, double *eta, double *fee, double *premium, NSString *functionName, unsigned *risk);
} // namespace


namespace {
static ClassDef sPlayerShipClass =
{
	"PlayerShip",
	ClassFlag::HasPrivate,
	
	nullptr,				// addProperty (engine default: PropertyStub)
	nullptr,				// delProperty (engine default: PropertyStub)
	PlayerShipGetProperty,	// getProperty
	PlayerShipSetProperty,	// setProperty
	nullptr,				// enumerate (engine default: EnumerateStub)
	nullptr,				// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,				// resolve (engine default: ResolveStub)
	nullptr,				// convert (engine default: ConvertStub)
	OOJSObjectWrapperFinalize,		// finalize
	nullptr,				// call
	nullptr,				// construct
	nullptr,				// backend: owned by the façade backend, must start null
};
} // namespace


enum : std::uint8_t
{
	// Property IDs
	kPlayerShip_activeMissile,                  // index in 'missiles' array of current active missile
	kPlayerShip_aftShield,						// aft shield charge level, nonnegative float, read/write
	kPlayerShip_aftShieldRechargeRate,			// aft shield recharge rate, positive float, read-only
	kPlayerShip_chartHightlightMode,            // what type of information is being shown on the chart
	kPlayerShip_compassMode,					// compass mode, string, read/write
	kPlayerShip_compassTarget,					// object targeted by the compass, entity, read/write
	kPlayerShip_compassType,					// basic / advanced, string, read/write
	kPlayerShip_currentWeapon,					// shortcut property to _aftWeapon, etc. overrides kShip generic version
	kPlayerShip_crosshairs,						// custom plist file defining crosshairs
	kPlayerShip_cursorCoordinates,				// cursor coordinates (unscaled), Vector3D, read only
	kPlayerShip_cursorCoordinatesInLY,			// cursor coordinates (in LY), Vector3D, read only
	kPlayerShip_docked,							// docked, boolean, read-only
	kPlayerShip_dockedStation,					// docked station, entity, read-only
	kPlayerShip_fastEquipmentA,					// fast equipment A, string, read/write
	kPlayerShip_fastEquipmentB,					// fast equipment B, string, read/write
	kPlayerShip_forwardShield,					// forward shield charge level, nonnegative float, read/write
	kPlayerShip_forwardShieldRechargeRate,		// forward shield recharge rate, positive float, read-only
	kPlayerShip_fuelLeakRate,					// fuel leak rate, float, read/write
	kPlayerShip_galacticHyperspaceBehaviour,	// can be standard, all systems reachable or fixed coordinates, integer, read-only
	kPlayerShip_galacticHyperspaceFixedCoords,	// used when fixed coords behaviour is selected, Vector3D, read/write
	kPlayerShip_galacticHyperspaceFixedCoordsInLY,	// used when fixed coords behaviour is selected, Vector3D, read/write
	kPlayerShip_galaxyCoordinates,				// galaxy coordinates (unscaled), Vector3D, read only
	kPlayerShip_galaxyCoordinatesInLY,			// galaxy coordinates (in LY), Vector3D, read only
	kPlayerShip_hud,							// hud name identifier, string, read/write
	kPlayerShip_hudAllowsBigGui,				// hud big gui, string, read only
	kPlayerShip_hudHidden,						// hud visibility, boolean, read/write
	kPlayerShip_injectorsEngaged,				// injectors in use, boolean, read-only
	kPlayerShip_massLockable,					// mass-lockability of player ship, read/write
	kPlayerShip_maxAftShield,					// maximum aft shield charge level, positive float, read-only
	kPlayerShip_maxForwardShield,				// maximum forward shield charge level, positive float, read-only
	kPlayerShip_messageGuiTextColor,			// message gui standard text color, array, read/write
	kPlayerShip_messageGuiTextCommsColor,		// message gui incoming comms text color, array, read/write
	kPlayerShip_multiFunctionDisplays,			// mfd count, positive int, read-only
	kPlayerShip_multiFunctionDisplayList,		// active mfd list, array, read-only
	kPlayerShip_missilesOnline,                 // bool (false for ident mode, true for missile mode)
	kPlayerShip_pitch,							// pitch (overrules Ship)
	kPlayerShip_price,							// idealised trade-in value decicredits, positive int, read-only
	kPlayerShip_primedEquipment,                // currently primed equipment, string, read/write
	kPlayerShip_renovationCost,					// int read-only current renovation cost
	kPlayerShip_reticleColorTarget,				// Reticle color for normal targets, array, read/write
	kPlayerShip_reticleColorTargetSensitive,	// Reticle color for targets picked up when sensitive mode is on, array, read/write
	kPlayerShip_reticleColorWormhole,			// REticle color for wormholes, array, read/write
	kPlayerShip_renovationMultiplier,			// float read-only multiplier for renovation costs
	kPlayerShip_reticleTargetSensitive,			// target box changes color when primary target in crosshairs, boolean, read/write
	kPlayerShip_roll,							// roll (overrules Ship)
	kPlayerShip_routeMode,						// ANA mode
	kPlayerShip_scannerMinimalistic	,			// essentially scanner without gridlines	
	kPlayerShip_scannerNonLinear,				// non linear scanner setting, boolean, read/write
	kPlayerShip_scannerUltraZoom,				// scanner zoom in powers of 2, boolean, read/write
	kPlayerShip_scoopOverride,					// Scooping
	kPlayerShip_serviceLevel,					// servicing level, positive int 75-100, read-only
	kPlayerShip_specialCargo,					// special cargo, string, read-only
	kPlayerShip_targetSystem,					// target system id, int, read-write
	kPlayerShip_nextSystem,						// next hop system id, read-only
	kPlayerShip_infoSystem,						// info (F7 screen) system id, int, read-write
	kPlayerShip_previousSystem,					// previous system id, read-only
	kPlayerShip_torusEngaged,					// torus in use, boolean, read-only
	kPlayerShip_viewDirection,					// view direction identifier, string, read-only
	kPlayerShip_viewPositionAft,					// view position offset, vector, read-only
	kPlayerShip_viewPositionForward,					// view position offset, vector, read-only
	kPlayerShip_viewPositionPort,					// view position offset, vector, read-only
	kPlayerShip_viewPositionStarboard,					// view position offset, vector, read-only
	kPlayerShip_weaponsOnline,					// weapons online status, boolean, read-only
	kPlayerShip_yaw,							// yaw (overrules Ship)
};


namespace {
static PropertySpec sPlayerShipProperties[] =
{
	// JS name								ID											flags									getter	setter
	{ "activeMissile",                  kPlayerShip_activeMissile,                  PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "aftShield",						kPlayerShip_aftShield,						PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "aftShieldRechargeRate",			kPlayerShip_aftShieldRechargeRate,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "chartHighlightMode",             kPlayerShip_chartHightlightMode,            PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "compassMode",					kPlayerShip_compassMode,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "compassTarget",					kPlayerShip_compassTarget,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "compassType",					kPlayerShip_compassType,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "currentWeapon",					kPlayerShip_currentWeapon,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "crosshairs",						kPlayerShip_crosshairs,						PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "cursorCoordinates",				kPlayerShip_cursorCoordinates,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "cursorCoordinatesInLY",			kPlayerShip_cursorCoordinatesInLY,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "docked",							kPlayerShip_docked,							PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "dockedStation",					kPlayerShip_dockedStation,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "fastEquipmentA",					kPlayerShip_fastEquipmentA,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "fastEquipmentB",					kPlayerShip_fastEquipmentB,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "forwardShield",					kPlayerShip_forwardShield,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "forwardShieldRechargeRate",		kPlayerShip_forwardShieldRechargeRate,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "fuelLeakRate",					kPlayerShip_fuelLeakRate,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "galacticHyperspaceBehaviour",	kPlayerShip_galacticHyperspaceBehaviour,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "galacticHyperspaceFixedCoords",	kPlayerShip_galacticHyperspaceFixedCoords,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "galacticHyperspaceFixedCoordsInLY",	kPlayerShip_galacticHyperspaceFixedCoordsInLY,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "galaxyCoordinates",				kPlayerShip_galaxyCoordinates,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "galaxyCoordinatesInLY",			kPlayerShip_galaxyCoordinatesInLY,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "hud",							kPlayerShip_hud,							PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "hudAllowsBigGui",				kPlayerShip_hudAllowsBigGui,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "hudHidden",						kPlayerShip_hudHidden,						PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "injectorsEngaged",				kPlayerShip_injectorsEngaged,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "massLockable",					kPlayerShip_massLockable,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	// manifest defined in OOJSManifest.m
	{ "maxAftShield",					kPlayerShip_maxAftShield,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "maxForwardShield",				kPlayerShip_maxForwardShield,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "messageGuiTextColor",			kPlayerShip_messageGuiTextColor,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "messageGuiTextCommsColor",		kPlayerShip_messageGuiTextCommsColor,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "missilesOnline",					kPlayerShip_missilesOnline,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "multiFunctionDisplays",			kPlayerShip_multiFunctionDisplays,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "multiFunctionDisplayList",  		kPlayerShip_multiFunctionDisplayList,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "price",							kPlayerShip_price,							PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "pitch",							kPlayerShip_pitch,							PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "primedEquipment",				kPlayerShip_primedEquipment,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "renovationCost",					kPlayerShip_renovationCost,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "reticleColorTarget",				kPlayerShip_reticleColorTarget,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "reticleColorTargetSensitive",	kPlayerShip_reticleColorTargetSensitive,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "reticleColorWormhole",			kPlayerShip_reticleColorWormhole,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "renovationMultiplier",			kPlayerShip_renovationMultiplier,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "reticleTargetSensitive",			kPlayerShip_reticleTargetSensitive,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "roll",							kPlayerShip_roll,							PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "routeMode",						kPlayerShip_routeMode,						PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "scannerMinimalistic",				kPlayerShip_scannerMinimalistic,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "scannerNonLinear",				kPlayerShip_scannerNonLinear,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "scannerUltraZoom",				kPlayerShip_scannerUltraZoom,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "scoopOverride",					kPlayerShip_scoopOverride,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "serviceLevel",					kPlayerShip_serviceLevel,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "specialCargo",					kPlayerShip_specialCargo,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "targetSystem",					kPlayerShip_targetSystem,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "nextSystem",                     kPlayerShip_nextSystem,                     PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "infoSystem",						kPlayerShip_infoSystem,						PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ "previousSystem",					kPlayerShip_previousSystem,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "torusEngaged",					kPlayerShip_torusEngaged,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "viewDirection",					kPlayerShip_viewDirection,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "viewPositionAft",				kPlayerShip_viewPositionAft,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "viewPositionForward",			kPlayerShip_viewPositionForward,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "viewPositionPort",				kPlayerShip_viewPositionPort,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "viewPositionStarboard",			kPlayerShip_viewPositionStarboard,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "weaponsOnline",					kPlayerShip_weaponsOnline,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "yaw",							kPlayerShip_yaw,							PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ 0 }			
};
} // namespace


// A raw jsapi mirror of sPlayerShipProperties, used only for the two bad-property error
// reporters in OOJavaScriptEngine.m (OOJSReportBadPropertySelector/Value): those helpers are
// outside this bead's scope (shared across every binding file) and still take a
// ooscript::PropertySpec*, not ooscript::PropertySpec* (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static ooscript::PropertySpec sPlayerShipPropertiesRaw[] =
{
	// JS name								ID											flags
	{ "activeMissile",                  kPlayerShip_activeMissile,                  OOJS_PROP_READONLY_CB },
	{ "aftShield",						kPlayerShip_aftShield,						OOJS_PROP_READWRITE_CB },
	{ "aftShieldRechargeRate",			kPlayerShip_aftShieldRechargeRate,			OOJS_PROP_READWRITE_CB },
	{ "chartHighlightMode",             kPlayerShip_chartHightlightMode,            OOJS_PROP_READWRITE_CB },
	{ "compassMode",					kPlayerShip_compassMode,					OOJS_PROP_READWRITE_CB },
	{ "compassTarget",					kPlayerShip_compassTarget,					OOJS_PROP_READWRITE_CB },
	{ "compassType",					kPlayerShip_compassType,					OOJS_PROP_READWRITE_CB },
	{ "currentWeapon",					kPlayerShip_currentWeapon,					OOJS_PROP_READWRITE_CB },
	{ "crosshairs",						kPlayerShip_crosshairs,						OOJS_PROP_READWRITE_CB },
	{ "cursorCoordinates",				kPlayerShip_cursorCoordinates,				OOJS_PROP_READONLY_CB },
	{ "cursorCoordinatesInLY",			kPlayerShip_cursorCoordinatesInLY,			OOJS_PROP_READONLY_CB },
	{ "docked",							kPlayerShip_docked,							OOJS_PROP_READONLY_CB },
	{ "dockedStation",					kPlayerShip_dockedStation,					OOJS_PROP_READONLY_CB },
	{ "fastEquipmentA",					kPlayerShip_fastEquipmentA,					OOJS_PROP_READWRITE_CB },
	{ "fastEquipmentB",					kPlayerShip_fastEquipmentB,					OOJS_PROP_READWRITE_CB },
	{ "forwardShield",					kPlayerShip_forwardShield,					OOJS_PROP_READWRITE_CB },
	{ "forwardShieldRechargeRate",		kPlayerShip_forwardShieldRechargeRate,		OOJS_PROP_READWRITE_CB },
	{ "fuelLeakRate",					kPlayerShip_fuelLeakRate,					OOJS_PROP_READWRITE_CB },
	{ "galacticHyperspaceBehaviour",	kPlayerShip_galacticHyperspaceBehaviour,	OOJS_PROP_READWRITE_CB },
	{ "galacticHyperspaceFixedCoords",	kPlayerShip_galacticHyperspaceFixedCoords,	OOJS_PROP_READWRITE_CB },
	{ "galacticHyperspaceFixedCoordsInLY",	kPlayerShip_galacticHyperspaceFixedCoordsInLY,	OOJS_PROP_READWRITE_CB },
	{ "galaxyCoordinates",				kPlayerShip_galaxyCoordinates,				OOJS_PROP_READONLY_CB },
	{ "galaxyCoordinatesInLY",			kPlayerShip_galaxyCoordinatesInLY,			OOJS_PROP_READONLY_CB },
	{ "hud",							kPlayerShip_hud,							OOJS_PROP_READWRITE_CB },
	{ "hudAllowsBigGui",				kPlayerShip_hudAllowsBigGui,				OOJS_PROP_READONLY_CB },
	{ "hudHidden",						kPlayerShip_hudHidden,						OOJS_PROP_READWRITE_CB },
	{ "injectorsEngaged",				kPlayerShip_injectorsEngaged,				OOJS_PROP_READONLY_CB },
	{ "massLockable",					kPlayerShip_massLockable,					OOJS_PROP_READWRITE_CB },
	// manifest defined in OOJSManifest.m
	{ "maxAftShield",					kPlayerShip_maxAftShield,					OOJS_PROP_READWRITE_CB },
	{ "maxForwardShield",				kPlayerShip_maxForwardShield,				OOJS_PROP_READWRITE_CB },
	{ "messageGuiTextColor",			kPlayerShip_messageGuiTextColor,			OOJS_PROP_READWRITE_CB },
	{ "messageGuiTextCommsColor",		kPlayerShip_messageGuiTextCommsColor,		OOJS_PROP_READWRITE_CB },
	{ "missilesOnline",					kPlayerShip_missilesOnline,					OOJS_PROP_READONLY_CB },
	{ "multiFunctionDisplays",			kPlayerShip_multiFunctionDisplays,			OOJS_PROP_READONLY_CB },
	{ "multiFunctionDisplayList",  		kPlayerShip_multiFunctionDisplayList,		OOJS_PROP_READONLY_CB },
	{ "price",							kPlayerShip_price,							OOJS_PROP_READONLY_CB },
	{ "pitch",							kPlayerShip_pitch,							OOJS_PROP_READWRITE_CB },
	{ "primedEquipment",				kPlayerShip_primedEquipment,				OOJS_PROP_READWRITE_CB },
	{ "renovationCost",					kPlayerShip_renovationCost,					OOJS_PROP_READONLY_CB },
	{ "reticleColorTarget",				kPlayerShip_reticleColorTarget,				OOJS_PROP_READWRITE_CB },
	{ "reticleColorTargetSensitive",	kPlayerShip_reticleColorTargetSensitive,	OOJS_PROP_READWRITE_CB },
	{ "reticleColorWormhole",			kPlayerShip_reticleColorWormhole,			OOJS_PROP_READWRITE_CB },
	{ "renovationMultiplier",			kPlayerShip_renovationMultiplier,			OOJS_PROP_READONLY_CB },
	{ "reticleTargetSensitive",			kPlayerShip_reticleTargetSensitive,			OOJS_PROP_READWRITE_CB },
	{ "roll",							kPlayerShip_roll,							OOJS_PROP_READWRITE_CB },
	{ "routeMode",						kPlayerShip_routeMode,						OOJS_PROP_READONLY_CB },
	{ "scannerMinimalistic",				kPlayerShip_scannerMinimalistic,			OOJS_PROP_READWRITE_CB },
	{ "scannerNonLinear",				kPlayerShip_scannerNonLinear,				OOJS_PROP_READWRITE_CB },
	{ "scannerUltraZoom",				kPlayerShip_scannerUltraZoom,				OOJS_PROP_READWRITE_CB },
	{ "scoopOverride",					kPlayerShip_scoopOverride,					OOJS_PROP_READWRITE_CB },
	{ "serviceLevel",					kPlayerShip_serviceLevel,					OOJS_PROP_READWRITE_CB },
	{ "specialCargo",					kPlayerShip_specialCargo,					OOJS_PROP_READONLY_CB },
	{ "targetSystem",					kPlayerShip_targetSystem,					OOJS_PROP_READWRITE_CB },
	{ "nextSystem",                     kPlayerShip_nextSystem,                     OOJS_PROP_READONLY_CB },
	{ "infoSystem",						kPlayerShip_infoSystem,						OOJS_PROP_READWRITE_CB },
	{ "previousSystem",					kPlayerShip_previousSystem,					OOJS_PROP_READONLY_CB },
	{ "torusEngaged",					kPlayerShip_torusEngaged,					OOJS_PROP_READONLY_CB },
	{ "viewDirection",					kPlayerShip_viewDirection,					OOJS_PROP_READONLY_CB },
	{ "viewPositionAft",				kPlayerShip_viewPositionAft,				OOJS_PROP_READONLY_CB },
	{ "viewPositionForward",			kPlayerShip_viewPositionForward,			OOJS_PROP_READONLY_CB },
	{ "viewPositionPort",				kPlayerShip_viewPositionPort,				OOJS_PROP_READONLY_CB },
	{ "viewPositionStarboard",			kPlayerShip_viewPositionStarboard,			OOJS_PROP_READONLY_CB },
	{ "weaponsOnline",					kPlayerShip_weaponsOnline,					OOJS_PROP_READONLY_CB },
	{ "yaw",							kPlayerShip_yaw,							OOJS_PROP_READWRITE_CB },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sPlayerShipMethods[] =
{
	// JS name							Function								min args	flags
	{ "addParcel",   					PlayerShipAddParcel,						0,			0 },
	{ "addPassenger",					PlayerShipAddPassenger,						0,			0 },
	{ "awardContract",					PlayerShipAwardContract,					0,			0 },
	{ "awardEquipmentToCurrentPylon",	PlayerShipAwardEquipmentToCurrentPylon,		1,			0 },
	{ "beginHyperspaceCountdown",       PlayerShipBeginHyperspaceCountdown,         0,			0 },
	{ "cancelDockingRequest",			PlayerShipCancelDockingRequest,             1,			0 },
	{ "cancelHyperspaceCountdown",      PlayerShipCancelHyperspaceCountdown,        0,			0 },
	{ "beginGalacticHyperspaceCountdown", PlayerShipBeginGalacticHyperspaceCountdown, 1,			0 },
	{ "disengageAutopilot",				PlayerShipDisengageAutopilot,				0,			0 },
	{ "engageAutopilotToStation",		PlayerShipEngageAutopilotToStation,			1,			0 },
	{ "hideHUDSelector",				PlayerShipHideHUDSelector,					1,			0 },
	{ "launch",							PlayerShipLaunch,							0,			0 },
	{ "removeAllCargo",					PlayerShipRemoveAllCargo,					0,			0 },
	{ "removeContract",					PlayerShipRemoveContract,					2,			0 },
	{ "removeParcel",                   PlayerShipRemoveParcel,                     1,			0 },
	{ "removePassenger",				PlayerShipRemovePassenger,					1,			0 },
	{ "requestDockingClearance",        PlayerShipRequestDockingClearance,          1,			0 },
	{ "resetCustomView",				PlayerShipResetCustomView,					0,			0 },
	{ "resetScannerZoom",				PlayerShipResetScannerZoom,					0,			0 },
	{ "setCustomView",					PlayerShipSetCustomView,					2,			0 },
	{ "setCustomHUDDial",				PlayerShipSetCustomHUDDial,					2,			0 },
	{ "setMultiFunctionDisplay",		PlayerShipSetMultiFunctionDisplay,			1,			0 },
	{ "setMultiFunctionText",			PlayerShipSetMultiFunctionText,				1,			0 },
	{ "setPrimedEquipment",				PlayerShipSetPrimedEquipment,               1,			0 },
	{ "showHUDSelector",				PlayerShipShowHUDSelector,					1,			0 },
	{ "takeInternalDamage",				PlayerShipTakeInternalDamage,				0,			0 },
	{ "useSpecialCargo",				PlayerShipUseSpecialCargo,					1,			0 },
	{ 0 }
};
} // namespace


void InitOOJSPlayerShip(ooscript::Context context, ooscript::Object global)
{
	Object proto = ooscript::initClass((context), (global), (JSShipPrototype()), &sPlayerShipClass, OOJSUnconstructableConstruct, 0, sPlayerShipProperties, sPlayerShipMethods, nullptr, nullptr);
	sPlayerShipPrototype = (proto);
	OOJSRegisterObjectConverter(&sPlayerShipClass, OOJSBasicPrivateObjectConverter);
	OOJSRegisterSubclass(&sPlayerShipClass, JSShipClass());
	
	PlayerEntity *player = [PlayerEntity sharedPlayer];	// NOTE: at time of writing, this creates the player entity. Don't use PLAYER here.
	
	// Create ship object as a property of the player object.
	Object shipObj = ooscript::defineObject((context), (JSPlayerObject()), "ship", &sPlayerShipClass, proto, OOJS_PROP_READONLY);
	sPlayerShipObject = (shipObj);
	ooscript::setPrivate((context), shipObj, OOConsumeReference([player weakRetain]));
	[player setJSSelf:sPlayerShipObject context:context];
	// Analyzer: object leaked. [Expected, object is retained by JS object.]
}


ooscript::ClassDef *JSPlayerShipClass(void)
{
	return &sPlayerShipClass;
}


ooscript::Object JSPlayerShipPrototype(void)
{
	return sPlayerShipPrototype;
}


ooscript::Object JSPlayerShipObject(void)
{
	return sPlayerShipObject;
}


@implementation PlayerEntity (OOJavaScriptExtensions)

- (NSString *) oo_jsClassName
{
	return @"PlayerShip";
}


- (void) setJSSelf:(ooscript::Object)val context:(ooscript::Context)context
{
	_jsSelf = val;
	OOJSAddGCObjectRoot(context, &_jsSelf, "Player jsSelf");
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(javaScriptEngineWillReset:)
												 name:kOOJavaScriptEngineWillResetNotification
											   object:[OOJavaScriptEngine sharedEngine]];
}


- (void) javaScriptEngineWillReset:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] removeObserver:self
													 name:kOOJavaScriptEngineWillResetNotification
												   object:[OOJavaScriptEngine sharedEngine]];
	
	if (_jsSelf != NULL)
	{
		
		ooscript::Context context = OOJSAcquireContext();
		ooscript::removeObjectRoot((context), OOJSFOBJP(&_jsSelf));
		_jsSelf = NULL;
		OOJSRelinquishContext(context);
	}
}

@end


namespace {
static bool PlayerShipGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = (value);
	
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(OOIsPlayerStale() || thisObj == sPlayerShipPrototype))  { *value_raw = ooscript::undefinedValue(); return YES; }
	
	id							result = nil;
	PlayerEntity				*player = OOPlayerForScripting();
	
	switch (ooscript::idToInt32(propID))
	{
		case kPlayerShip_activeMissile:
			return ooscript::newNumberValue(cx, [player activeMissile], value);
                      
		case kPlayerShip_fuelLeakRate:
			return ooscript::newNumberValue(cx, [player fuelLeakRate], value);
			
		case kPlayerShip_docked:
			*value_raw = OOJSValueFromBOOL([player isDocked]);
			return YES;
			
		case kPlayerShip_dockedStation:
			result = [player dockedStation];
			break;
			
		case kPlayerShip_specialCargo:
			result = [player specialCargo];
			break;
			
		case kPlayerShip_reticleColorTarget:
			result = [[[player hud] reticleColorForIndex:OO_RETICLE_COLOR_TARGET] normalizedArray];
			break;
			
		case kPlayerShip_reticleColorTargetSensitive:
			result = [[[player hud] reticleColorForIndex:OO_RETICLE_COLOR_TARGET_SENSITIVE] normalizedArray];
			break;
			
		case kPlayerShip_reticleColorWormhole:
			result = [[[player hud] reticleColorForIndex:OO_RETICLE_COLOR_WORMHOLE] normalizedArray];
			break;
			
		case kPlayerShip_reticleTargetSensitive:
			*value_raw = OOJSValueFromBOOL([[player hud] reticleTargetSensitive]);
			return YES;
			
		case kPlayerShip_galacticHyperspaceBehaviour:
			*value_raw = OOJSValueFromGalacticHyperspaceBehaviour(context, [player galacticHyperspaceBehaviour]);
			return YES;
			
		case kPlayerShip_galacticHyperspaceFixedCoords:
			return NSPointToVectorJSValue(context, [player galacticHyperspaceFixedCoords], value_raw);
			
		case kPlayerShip_galacticHyperspaceFixedCoordsInLY:
			return VectorToJSValue(context, OOGalacticCoordinatesFromInternal([player galacticHyperspaceFixedCoords]), value_raw);

		case kPlayerShip_fastEquipmentA:
			result = [player fastEquipmentA];
			break;

		case kPlayerShip_fastEquipmentB:
			result = [player fastEquipmentB];
			break;

		case kPlayerShip_primedEquipment:
			result = [player currentPrimedEquipment];
			break;

		case kPlayerShip_forwardShield:
			return ooscript::newNumberValue(cx, [player forwardShieldLevel], value);
			
		case kPlayerShip_aftShield:
			return ooscript::newNumberValue(cx, [player aftShieldLevel], value);
			
		case kPlayerShip_maxForwardShield:
			return ooscript::newNumberValue(cx, [player maxForwardShieldLevel], value);
			
		case kPlayerShip_maxAftShield:
			return ooscript::newNumberValue(cx, [player maxAftShieldLevel], value);
			
		case kPlayerShip_forwardShieldRechargeRate:
			// No distinction made internally
			return ooscript::newNumberValue(cx, [player forwardShieldRechargeRate], value);

		case kPlayerShip_aftShieldRechargeRate:
			// No distinction made internally
			return ooscript::newNumberValue(cx, [player aftShieldRechargeRate], value);
			
		case kPlayerShip_multiFunctionDisplays:
			return ooscript::newNumberValue(cx, [[player hud] mfdCount], value);

		case kPlayerShip_multiFunctionDisplayList:
			result = [player multiFunctionDisplayList];
			break;

		case kPlayerShip_missilesOnline:
			*value_raw = OOJSValueFromBOOL(![player dialIdentEngaged]);
			return YES;

		case kPlayerShip_chartHightlightMode:
			result = OOStringFromLongRangeChartMode([player longRangeChartMode]);
			break;

		case kPlayerShip_galaxyCoordinates:
			return NSPointToVectorJSValue(context, [player galaxy_coordinates], value_raw);
			
		case kPlayerShip_galaxyCoordinatesInLY:
			return VectorToJSValue(context, OOGalacticCoordinatesFromInternal([player galaxy_coordinates]), value_raw);
			
		case kPlayerShip_cursorCoordinates:
			return NSPointToVectorJSValue(context, [player cursor_coordinates], value_raw);

		case kPlayerShip_cursorCoordinatesInLY:
			return VectorToJSValue(context, OOGalacticCoordinatesFromInternal([player cursor_coordinates]), value_raw);
			
		case kPlayerShip_targetSystem:
			*value_raw = ooscript::int32Value([player targetSystemID]);
			return YES;

		case kPlayerShip_nextSystem:
			*value_raw = ooscript::int32Value([player nextHopTargetSystemID]);
			return YES;
			
		case kPlayerShip_infoSystem:
			*value_raw = ooscript::int32Value([player infoSystemID]);
			return YES;

		case kPlayerShip_previousSystem:
			*value_raw = ooscript::int32Value([player previousSystemID]);
			return YES;
			
		case kPlayerShip_routeMode:
		{
			OORouteType route = [player ANAMode];
			switch (route)
			{
			case OPTIMIZED_BY_TIME:
				result = @"OPTIMIZED_BY_TIME";
				break;
			case OPTIMIZED_BY_JUMPS:
				result = @"OPTIMIZED_BY_JUMPS";
				break;
			case OPTIMIZED_BY_NONE:
				result = @"OPTIMIZED_BY_NONE";
				break;
			}
			break;
		}
		
		case kPlayerShip_scannerMinimalistic:
			*value_raw = OOJSValueFromBOOL([[player hud] minimalisticScanner]);
			return YES;
			
		case kPlayerShip_scannerNonLinear:
			*value_raw = OOJSValueFromBOOL([[player hud] nonlinearScanner]);
			return YES;
			
		case kPlayerShip_scannerUltraZoom:
			*value_raw = OOJSValueFromBOOL([[player hud] scannerUltraZoom]);
			return YES;
			
		case kPlayerShip_scoopOverride:
			*value_raw = OOJSValueFromBOOL([player scoopOverride]);
			return YES;

		case kPlayerShip_injectorsEngaged:
			*value_raw = OOJSValueFromBOOL([player injectorsEngaged]);
			return YES;
			
		case kPlayerShip_massLockable:
			*value_raw = OOJSValueFromBOOL([player massLockable]);
			return YES;

		case kPlayerShip_torusEngaged:
			*value_raw = OOJSValueFromBOOL([player hyperspeedEngaged]);
			return YES;
			
		case kPlayerShip_compassTarget:
			result = [player compassTarget];
			break;
			
		case kPlayerShip_compassType:
			result = [OOStringFromCompassMode([player compassMode]) isEqualToString:@"COMPASS_MODE_BASIC"] ?
										@"OO_COMPASSTYPE_BASIC" : @"OO_COMPASSTYPE_ADVANCED";
			break;
			
		case kPlayerShip_compassMode:
			*value_raw = OOJSValueFromCompassMode(context, [player compassMode]);
			return YES;
			
		case kPlayerShip_hud:
			result = [[player hud] hudName];
			break;

		case kPlayerShip_crosshairs:
			result = [[player hud] crosshairDefinition];
			break;

		case kPlayerShip_hudAllowsBigGui:
			*value_raw = OOJSValueFromBOOL([[player hud] allowBigGui]);
			return YES;

		case kPlayerShip_hudHidden:
			*value_raw = OOJSValueFromBOOL([[player hud] isHidden]);
			return YES;
			
		case kPlayerShip_weaponsOnline:
			*value_raw = OOJSValueFromBOOL([player weaponsOnline]);
			return YES;
			
		case kPlayerShip_viewDirection:
			*value_raw = OOJSValueFromViewID(context, [UNIVERSE viewDirection]);
			return YES;

		case kPlayerShip_viewPositionAft:
			return VectorToJSValue(context, [player viewpointOffsetAft], value_raw);

		case kPlayerShip_viewPositionForward:
			return VectorToJSValue(context, [player viewpointOffsetForward], value_raw);

		case kPlayerShip_viewPositionPort:
			return VectorToJSValue(context, [player viewpointOffsetPort], value_raw);

		case kPlayerShip_viewPositionStarboard:
			return VectorToJSValue(context, [player viewpointOffsetStarboard], value_raw);

		case kPlayerShip_currentWeapon:
			result = [player weaponTypeForFacing:[player currentWeaponFacing] strict:NO];
			break;
		
	  case kPlayerShip_price:
			return ooscript::newNumberValue(cx, [UNIVERSE tradeInValueForCommanderDictionary:[player commanderDataDictionary]], value);

	  case kPlayerShip_serviceLevel:
			return ooscript::newNumberValue(cx, [player tradeInFactor], value);

		case kPlayerShip_renovationCost:
			return ooscript::newNumberValue(cx, [player renovationCosts], value);

		case kPlayerShip_renovationMultiplier:
			return ooscript::newNumberValue(cx, [player renovationFactor], value);


			// make roll, pitch, yaw reported to JS use same +/- convention as
			// for NPC ships
		case kPlayerShip_pitch:
			return ooscript::newNumberValue(cx, -[player flightPitch], value);

		case kPlayerShip_roll:
			return ooscript::newNumberValue(cx, -[player flightRoll], value);

		case kPlayerShip_yaw:
			return ooscript::newNumberValue(cx, -[player flightYaw], value);
			
		case kPlayerShip_messageGuiTextColor:
			result = [[[UNIVERSE messageGUI] textColor] normalizedArray];
			break;
			
		case kPlayerShip_messageGuiTextCommsColor:
			result = [[[UNIVERSE messageGUI] textCommsColor] normalizedArray];
			break;
			
		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sPlayerShipPropertiesRaw);
	}
	
	*value_raw = OOJSValueFromNativeObject(context, result);
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool PlayerShipSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = (value);
	
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(OOIsPlayerStale())) return YES;
	
	PlayerEntity				*player = OOPlayerForScripting();
	double					fValue;
	bool						bValue;
	int32_t						iValue;
	NSString					*sValue = nil;
	OOGalacticHyperspaceBehaviour ghBehaviour;
	Vector						vValue;
	OOColor						*colorForScript = nil;
	Entity						*eValue = nil;

	switch (ooscript::idToInt32(propID))
	{
		case kPlayerShip_fuelLeakRate:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				[player setFuelLeakRate:fValue];
				return YES;
			}
			break;
			
		case kPlayerShip_massLockable:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[player setMassLockable:bValue];
				return YES;
			}
			break;
			
		case kPlayerShip_reticleTargetSensitive:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[[player hud] setReticleTargetSensitive:bValue];
				return YES;
			}
			break;
		
		case kPlayerShip_chartHightlightMode:
			sValue = OOStringFromJSValue(context, *value_raw);
			if (sValue != nil) 
			{
				OOLongRangeChartMode chartMode = OOLongRangeChartModeFromString(sValue);
				if (chartMode > OOLRC_MODE_UNKNOWN)
				{
					[player setLongRangeChartMode:chartMode];
					[player doScriptEvent:OOJSID("chartHighlightModeChanged") withArgument:OOStringFromLongRangeChartMode([player longRangeChartMode])];
					return YES;
				}
				else
				{
					OOJSReportError(context, @"Unknown chart hightlight mode specified - must be either OOLRC_MODE_SUNCOLOR, OOLRC_MODE_ECONOMY, OOLRC_MODE_GOVERNMENT or OOLRC_MODE_TECHLEVEL.");
				}
			}
			return NO;	// not reachable if successfully set
			break;

		case kPlayerShip_compassMode:
			sValue = OOStringFromJSValue(context, *value_raw);
			if(sValue != nil)
			{
				OOCompassMode mode = OOCompassModeFromJSValue(context, *value_raw);
				[player setCompassMode:mode];
				[player validateCompassTarget];
				return YES;
			}
			break;
			
		case kPlayerShip_compassType:
			sValue = OOStringFromJSValue(context, *value_raw);
			if (sValue != nil)
			{
				if ([sValue isEqualToString:@"OO_COMPASSTYPE_BASIC"])
				{
					[player setCompassMode:COMPASS_MODE_BASIC];
				}
				else  if([sValue isEqualToString:@"OO_COMPASSTYPE_ADVANCED"])
				{
					if (![player hasEquipmentItemProviding:@"EQ_ADVANCED_COMPASS"])
					{
						OOJSReportWarning(context, @"Advanced Compass type requested and set but player ship does not carry the EQ_ADVANCED_COMPASS equipment or has it damaged.");
					}
					[player setCompassMode:COMPASS_MODE_PLANET];
				}
				else
				{
					OOJSReportError(context, @"Unknown compass type specified - must be either OO_COMPASSTYPE_BASIC or OO_COMPASSTYPE_ADVANCED.");
					return NO;
				}
				return YES;
			}
			break;
		
		case kPlayerShip_compassTarget:
			// can't change compass target in basic mode
			if (![player hasEquipmentItemProviding:@"EQ_ADVANCED_COMPASS"]) 
			{
				OOJSReportError(context, @"Compass target cannot be set with a basic compass.");
				return NO;
			}
			// make sure we have a valid entity
			if (!ooscript::isNull(*value_raw) && JSValueToEntity(context, *value_raw, &eValue)) 
			{
				Entity *current = [player compassTarget];
				[player setNextCompassMode];
				[player validateCompassTarget];
				// cycle the targets until we either get back to the start (entity not found) or we find the one we're looking for
				while ([player compassTarget] != current && [player compassTarget] != eValue)
				{
					[player setNextCompassMode];
					[player validateCompassTarget];
				}
				return [player compassTarget] != current;
			}
			else 
			{
				OOJSReportError(context, @"Invalid compass target entity provided.");
				return NO;
			}
			break;

		case kPlayerShip_galacticHyperspaceBehaviour:
			ghBehaviour = OOGalacticHyperspaceBehaviourFromJSValue(context, *value_raw);
			if (ghBehaviour != GALACTIC_HYPERSPACE_BEHAVIOUR_UNKNOWN)
			{
				[player setGalacticHyperspaceBehaviour:ghBehaviour];
				return YES;
			}
			break;
			
		case kPlayerShip_galacticHyperspaceFixedCoords:
			if (JSValueToVector(context, *value_raw, &vValue))
			{
				NSPoint coords = { vValue.x, vValue.y };
				[player setGalacticHyperspaceFixedCoords:coords];
				return YES;
			}
			break;
			
		case kPlayerShip_galacticHyperspaceFixedCoordsInLY:
			if (JSValueToVector(context, *value_raw, &vValue))
			{
				NSPoint coords = OOInternalCoordinatesFromGalactic(vValue);
				[player setGalacticHyperspaceFixedCoords:coords];
				return YES;
			}
			break;
			
		case kPlayerShip_fastEquipmentA:
			sValue = OOStringFromJSValue(context, *value_raw);
			if (sValue != nil)
			{
				[player setFastEquipmentA:sValue];
				return YES;
			}
			break;

		case kPlayerShip_fastEquipmentB:
			sValue = OOStringFromJSValue(context, *value_raw);
			if (sValue != nil)
			{
				[player setFastEquipmentB:sValue];
				return YES;
			}
			break;

		case kPlayerShip_primedEquipment:
			sValue = OOStringFromJSValue(context, *value_raw);
			if (sValue != nil)
			{
				return [player setPrimedEquipment:sValue showMessage:NO];
			}
			break;

		case kPlayerShip_pitch:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				if (!isnan(fValue)) // guard against undefined
				{
					[player decrease_flight_pitch:[player flightPitch] + fValue];
				}
				return YES;
			}
			break;
			
		case kPlayerShip_roll:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				if (!isnan(fValue)) // guard against undefined
				{
					[player decrease_flight_roll:[player flightRoll] + fValue];
				}
				return YES;
			}
			break;
			
		case kPlayerShip_yaw:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				if (!isnan(fValue)) // guard against undefined
				{
					[player decrease_flight_yaw:[player flightYaw] + fValue];
				}
				return YES;
			}
			break;
			
		case kPlayerShip_forwardShield:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				[player setForwardShieldLevel:fValue];
				return YES;
			}
			break;
			
		case kPlayerShip_aftShield:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				[player setAftShieldLevel:fValue];
				return YES;
			}
			break;

		case kPlayerShip_maxForwardShield:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				[player setMaxForwardShieldLevel:fValue];
				return YES;
			}
			break;
			
		case kPlayerShip_maxAftShield:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				[player setMaxAftShieldLevel:fValue];
				return YES;
			}
			break;

		case kPlayerShip_forwardShieldRechargeRate:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				[player setForwardShieldRechargeRate:fValue];
				return YES;
			}
			break;
			
		case kPlayerShip_aftShieldRechargeRate:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				[player setAftShieldRechargeRate:fValue];
				return YES;
			}
			break;
			
		case kPlayerShip_scannerMinimalistic:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[[player hud] setMinimalisticScanner:bValue];
				return YES;
			}
			break;
			
		case kPlayerShip_scannerNonLinear:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[[player hud] setNonlinearScanner:bValue];
				return YES;
			}
			break;
			
		case kPlayerShip_scannerUltraZoom:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[[player hud] setScannerUltraZoom:bValue];
				return YES;
			}
			break;
			
		case kPlayerShip_scoopOverride:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[player setScoopOverride:bValue];
				return YES;
			}
			break;
			
		case kPlayerShip_hud:
			sValue = OOStringFromJSValue(context, *value_raw);
			if (sValue != nil)
			{
				[player switchHudTo:sValue];	// EMMSTRAN: logged error should be a JS warning.
				return YES;
			}
			else
			{
				[player resetHud];
				return YES;
			}
			break;
			
		case kPlayerShip_crosshairs:
			sValue = OOStringFromJSValue(context, *value_raw);
			if (sValue == nil)
			{
				// reset HUD back to its plist settings
				NSString *hud = [[[player hud] hudName] retain];
				[player switchHudTo:hud];
				[hud release];
				return YES;
			}
			else
			{
				if (![[player hud] setCrosshairDefinition:sValue])
				{
					OOJSReportWarning(context, @"Crosshair definition file %@ not found or invalid", sValue);
				}
				return YES;
			}
			break;

		case kPlayerShip_hudHidden:
			if (ooscript::valueToBoolean(cx, *value, &bValue))
			{
				[[player hud] setHidden:bValue];
				return YES;
			}
			break;

	  case kPlayerShip_serviceLevel:
			if (ooscript::valueToNumber(cx, *value, &fValue))
			{
				int newLevel = (int)fValue;
				[player adjustTradeInFactorBy:(newLevel-[player tradeInFactor])];
				return YES;
			}
			
		case kPlayerShip_currentWeapon:
		{
			BOOL exists = NO;
			sValue = JSValueToEquipmentKeyRelaxed(context, *value_raw, &exists);
			if (!exists || sValue == nil) 
			{
				sValue = @"EQ_WEAPON_NONE";
			}
			[player setWeaponMount:[player currentWeaponFacing] toWeapon:sValue inContext:@"scripted"];
			return YES;
		}
		
		case kPlayerShip_targetSystem:
			/* This first check is essential: if removed, it would be
			 * possible to make jumps of arbitrary length - CIM */
			if ([player status] != STATUS_ENTERING_WITCHSPACE)
			{
				/* These checks though similar are less important. The
				 * consequences of allowing jump destination to be set in
				 * flight are not as severe and do not allow the 7LY limit to
				 * be broken. Nevertheless, it is not allowed. - CIM */
				// (except when compiled in debugging mode)
#ifndef OO_DUMP_PLANETINFO
				if (EXPECT_NOT([player status] != STATUS_DOCKED && [player status] != STATUS_LAUNCHING))
				{
					OOJSReportError(context, @"player.ship.targetSystem is read-only unless called when docked.");
					return NO;
				}
#endif
				
				if (ooscript::valueToInt32(cx, *value, &iValue))
				{
					if (iValue >= 0 && iValue < OO_SYSTEMS_PER_GALAXY)
					{ 
						[player setTargetSystemID:iValue];
						return YES;
					}
					else
					{
						return NO;
					}
				}
			}
			else
			{
				OOJSReportError(context, @"player.ship.targetSystem is read-only unless called when docked.");
				return NO;
			}
		
		case kPlayerShip_infoSystem:
			if (ooscript::valueToInt32(cx, *value, &iValue))
			{
				if (iValue >= 0 && iValue < OO_SYSTEMS_PER_GALAXY)
				{ 
					[player setInfoSystemID:iValue moveChart: YES];
					return YES;
				}
				else
				{
					return NO;
				}
			}
			break;
			
		case kPlayerShip_messageGuiTextColor:
			colorForScript = [OOColor colorWithDescription:OOJSNativeObjectFromJSValue(context, *value_raw)];
			if (colorForScript != nil || ooscript::isNull(*value_raw))
			{
				[[UNIVERSE messageGUI] setTextColor:colorForScript];
				return YES;
			}
			break;
			
		case kPlayerShip_messageGuiTextCommsColor:
			colorForScript = [OOColor colorWithDescription:OOJSNativeObjectFromJSValue(context, *value_raw)];
			if (colorForScript != nil || ooscript::isNull(*value_raw))
			{
				[[UNIVERSE messageGUI] setTextCommsColor:colorForScript];
				return YES;
			}
			break;
			
		case kPlayerShip_reticleColorTarget:
			colorForScript = [OOColor colorWithDescription:OOJSNativeObjectFromJSValue(context, *value_raw)];
			if (colorForScript != nil || ooscript::isNull(*value_raw))
			{
				return [[player hud] setReticleColorForIndex:OO_RETICLE_COLOR_TARGET toColor:colorForScript];
			}
			break;
			
		case kPlayerShip_reticleColorTargetSensitive:
			colorForScript = [OOColor colorWithDescription:OOJSNativeObjectFromJSValue(context, *value_raw)];
			if (colorForScript != nil || ooscript::isNull(*value_raw))
			{
				return [[player hud] setReticleColorForIndex:OO_RETICLE_COLOR_TARGET_SENSITIVE toColor:colorForScript];
			}
			break;
			
		case kPlayerShip_reticleColorWormhole:
			colorForScript = [OOColor colorWithDescription:OOJSNativeObjectFromJSValue(context, *value_raw)];
			if (colorForScript != nil || ooscript::isNull(*value_raw))
			{
				return [[player hud] setReticleColorForIndex:OO_RETICLE_COLOR_WORMHOLE toColor:colorForScript];
			}
			break;

		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sPlayerShipPropertiesRaw);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, (propID), sPlayerShipPropertiesRaw, *value_raw);
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// *** Methods ***

// launch()
namespace {
static bool PlayerShipLaunch(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(OOIsPlayerStale()))  OOJS_RETURN_VOID;
	
	[OOPlayerForScripting() launchFromStation];
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// removeAllCargo()
namespace {
static bool PlayerShipRemoveAllCargo(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(OOIsPlayerStale()))  OOJS_RETURN_VOID;
	
	PlayerEntity *player = OOPlayerForScripting();
	
	if ([player isDocked])
	{
		[player removeAllCargo];
		OOJS_RETURN_VOID;
	}
	else
	{
		OOJSReportError(context, @"PlayerShip.removeAllCargo only works when docked.");
		return NO;
	}
	
	OOJS_NATIVE_EXIT
}
} // namespace


// useSpecialCargo(name : String)
namespace {
static bool PlayerShipUseSpecialCargo(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(OOIsPlayerStale()))  OOJS_RETURN_VOID;
	
	PlayerEntity			*player = OOPlayerForScripting();
	NSString				*name = nil;
	
	if (oojsArgs.count() > 0)  name = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(name == nil))
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"useSpecialCargo", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string (special cargo description)");
		return NO;
	}
	
	[player useSpecialCargo:OOStringFromJSValue(context, OOJS_ARGV[0])];
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// engageAutopilotToStation(stationForDocking : Station) : Boolean
namespace {
static bool PlayerShipEngageAutopilotToStation(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(OOIsPlayerStale()))  OOJS_RETURN_VOID;
	
	PlayerEntity			*player = OOPlayerForScripting();
	StationEntity			*stationForDocking = nil;
	
	if (oojsArgs.count() > 0)  stationForDocking = OOJSNativeObjectOfClassFromJSValue(context, OOJS_ARGV[0], [StationEntity class]);
	if (stationForDocking == nil)
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"engageAutopilot", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"station");
		return NO;
	}
	
	OOJS_RETURN_BOOL([player engageAutopilotToStation:stationForDocking]);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// disengageAutopilot()
namespace {
static bool PlayerShipDisengageAutopilot(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(OOIsPlayerStale()))  OOJS_RETURN_VOID;
	
	[OOPlayerForScripting() disengageAutopilot];
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace

namespace {
static bool PlayerShipRequestDockingClearance(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(OOIsPlayerStale()))  OOJS_RETURN_VOID;

	PlayerEntity			*player = OOPlayerForScripting();
	StationEntity			*stationForDocking = nil;
	
	if (oojsArgs.count() > 0)  stationForDocking = OOJSNativeObjectOfClassFromJSValue(context, OOJS_ARGV[0], [StationEntity class]);
	if (stationForDocking == nil)
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"requestDockingClearance", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"station");
		return NO;
	}

	[player requestDockingClearance:stationForDocking];
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace

namespace {
static bool PlayerShipCancelDockingRequest(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(OOIsPlayerStale()))  OOJS_RETURN_VOID;

	PlayerEntity			*player = OOPlayerForScripting();
	StationEntity			*stationForDocking = nil;
	
	if (oojsArgs.count() > 0)  stationForDocking = OOJSNativeObjectOfClassFromJSValue(context, OOJS_ARGV[0], [StationEntity class]);
	if (stationForDocking == nil)
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"cancelDockingRequest", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"station");
		return NO;
	}

	[player cancelDockingRequest:stationForDocking];
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace

// awardEquipmentToCurrentPylon(externalTank: equipmentInfoExpression) : Boolean
namespace {
static bool PlayerShipAwardEquipmentToCurrentPylon(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(OOIsPlayerStale()))  OOJS_RETURN_VOID;
	
	PlayerEntity			*player = OOPlayerForScripting();
	NSString				*key = nil;
	OOEquipmentType			*eqType = nil;
	
	if (oojsArgs.count() > 0)  key = JSValueToEquipmentKey(context, OOJS_ARGV[0]);
	if (key != nil)  eqType = [OOEquipmentType equipmentTypeWithIdentifier:key];
	if (EXPECT_NOT(![eqType isMissileOrMine]))
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"awardEquipmentToCurrentPylon", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"equipment type (external store)");
		return NO;
	}
	
	OOJS_RETURN_BOOL([player assignToActivePylon:key]);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// addPassenger(name: string, start: int, destination: int, ETA: double, fee: double) : Boolean
namespace {
static bool PlayerShipAddPassenger(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	NSString 			*name = nil;
	OOSystemID			start = 0, destination = 0;
	double			eta = 0.0, fee = 0.0, advance = 0.0;
	unsigned			risk = 0;

	if (oojsArgs.count() < 5)
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"addPassenger", oojsArgs.count(), OOJS_ARGV, nil, @"name, start, destination, ETA, fee");
		return NO;
	}
	
	name = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(name == nil))
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"addPassenger", 1, &OOJS_ARGV[0], nil, @"string");
		return NO;
	}
	
	if (!ValidateContracts(context, oojsArgs, NO, &start, &destination, &eta, &fee, &advance, @"addPassenger", &risk))  return NO; // always go through validate contracts (passenger)
	
	// Ensure there's space.
	if ([player passengerCount] >= [player passengerCapacity])  OOJS_RETURN_BOOL(NO);
	
	BOOL OK = [player addPassenger:name start:start destination:destination eta:eta fee:fee advance:advance risk:risk];
	OOJS_RETURN_BOOL(OK);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// removePassenger(name :string)
namespace {
static bool PlayerShipRemovePassenger(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	NSString			*name = nil;
	BOOL				OK = YES;
	
	if (oojsArgs.count() > 0)  name = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(name == nil))
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"removePassenger", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string");
		return NO;
	}
	
	OK = [player passengerCount] > 0 && [name length] > 0;
	if (OK)  OK = [player removePassenger:name];
	
	OOJS_RETURN_BOOL(OK);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// addParcel(description: string, start: int, destination: int, ETA: double, fee: double) : Boolean
namespace {
static bool PlayerShipAddParcel(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	NSString 			*name = nil;
	OOSystemID			start = 0, destination = 0;
	double			eta = 0.0, fee = 0.0, premium = 0.0;
	unsigned			risk = 0;
	
	if (oojsArgs.count() < 5)
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"addParcel", oojsArgs.count(), OOJS_ARGV, nil, @"name, start, destination, ETA, fee");
		return NO;
	}
	
	name = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(name == nil))
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"addParcel", 1, &OOJS_ARGV[0], nil, @"string");
		return NO;
	}
	
	if (!ValidateContracts(context, oojsArgs, NO, &start, &destination, &eta, &fee, &premium, @"addParcel", &risk))  return NO; // always go through validate contracts (passenger/parcel mode)
	
	// Ensure there's space.
	
	BOOL OK = [player addParcel:name start:start destination:destination eta:eta fee:fee premium:premium risk:risk];
	OOJS_RETURN_BOOL(OK);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// removeParcel(description :string)
namespace {
static bool PlayerShipRemoveParcel(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	NSString			*name = nil;
	BOOL				OK = YES;
	
	if (oojsArgs.count() > 0)  name = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(name == nil))
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"removeParcel", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string");
		return NO;
	}
	
	OK = [player parcelCount] > 0 && [name length] > 0;
	if (OK)  OK = [player removeParcel:name];
	
	OOJS_RETURN_BOOL(OK);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// awardContract(quantity: int, commodity: string, start: int, destination: int, eta: double, fee: double) : Boolean
namespace {
static bool PlayerShipAwardContract(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	NSString 			*key = nil;
	int32_t 				qty = 0;
	OOSystemID			start = 0, destination = 0;
	double			eta = 0.0, fee = 0.0, premium = 0.0;
	
	if (oojsArgs.count() < 6)
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"awardContract", oojsArgs.count(), OOJS_ARGV, nil, @"quantity, commodity, start, destination, ETA, fee");
		return NO;
	}
	
	if (!ooscript::valueToInt32(context, (OOJS_ARGV[0]), &qty))
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"awardContract", 1, &OOJS_ARGV[0], nil, @"positive integer (cargo quantity)");
		return NO;
	}
	
	key = OOStringFromJSValue(context, OOJS_ARGV[1]);
	if (EXPECT_NOT(key == nil))
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"awardContract", 1, &OOJS_ARGV[1], nil, @"string (commodity identifier)");
		return NO;
	}
	
	if (!ValidateContracts(context, oojsArgs, YES, &start, &destination, &eta, &fee, &premium, @"awardContract", NULL))  return NO; // always go through validate contracts (cargo)
	
	BOOL OK = [player awardContract:qty commodity:key start:start destination:destination eta:eta fee:fee premium:premium];
	OOJS_RETURN_BOOL(OK);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// removeContract(commodity: string, destination: int)
namespace {
static bool PlayerShipRemoveContract(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	NSString			*key = nil;
	int32_t				dest = 0;
	
	if (oojsArgs.count() < 2)
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"removeContract", oojsArgs.count(), OOJS_ARGV, nil, @"commodity, destination");
		return NO;
	}
	
	key = OOStringFromJSValue(context, OOJS_ARGV[0]);
	
	if (EXPECT_NOT(key == nil))
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"removeContract", 1, &OOJS_ARGV[0], nil, @"string (commodity identifier)");
		return NO;
	}
	
	if (!ooscript::valueToInt32(context, (OOJS_ARGV[1]), &dest) || dest < 0 || dest > 255)
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"removeContract", 1, &OOJS_ARGV[1], nil, @"system ID");
		return NO;
	}
	
	BOOL OK = [player removeContract:key destination:(unsigned)dest];	
	OOJS_RETURN_BOOL(OK);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// setCustomView(position:vector, orientation:quaternion [, weapon:string])
namespace {
static bool PlayerShipSetCustomView(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	
	if (oojsArgs.count() < 2)
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"setCustomView", oojsArgs.count(), OOJS_ARGV, nil, @"position, orientiation, [weapon]");
		return NO;
	}

// must be in custom view
	if ([UNIVERSE viewDirection] != VIEW_CUSTOM) 
	{
		OOJSReportError(context, @"PlayerShip.setCustomView only works when custom view is active.");
		return NO;
	}

	NSMutableDictionary			*viewData = [NSMutableDictionary dictionaryWithCapacity:3];

	Vector position = kZeroVector;
	BOOL gotpos = JSValueToVector(context, OOJS_ARGV[0], &position);
	if (!gotpos)
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"setCustomView", oojsArgs.count(), OOJS_ARGV, nil, @"position, orientiation, [weapon]");
		return NO;
	}
	NSString *positionstr = [[NSString alloc] initWithFormat:@"%f %f %f",position.x,position.y,position.z];   

	Quaternion orientation = kIdentityQuaternion;
	BOOL gotquat = JSValueToQuaternion(context, OOJS_ARGV[1], &orientation);
	if (!gotquat)
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"setCustomView", oojsArgs.count(), OOJS_ARGV, nil, @"position, orientiation, [weapon]");
		return NO;
	}
	NSString *orientationstr = [[NSString alloc] initWithFormat:@"%f %f %f %f",orientation.w,orientation.x,orientation.y,orientation.z];

	[viewData setObject:positionstr forKey:@"view_position"];
	[viewData setObject:orientationstr forKey:@"view_orientation"];

	if (oojsArgs.count() > 2)
	{
		NSString* facing = OOStringFromJSValue(context,OOJS_ARGV[2]);
		[viewData setObject:facing forKey:@"weapon_facing"];
	} 

	[player setCustomViewDataFromDictionary:viewData withScaling:NO];
	[player noteSwitchToView:VIEW_CUSTOM fromView:VIEW_CUSTOM];

	[positionstr release];
	[orientationstr release];

	OOJS_RETURN_BOOL(YES);
	OOJS_NATIVE_EXIT
}
} // namespace


// resetCustomView()
namespace {
static bool PlayerShipResetCustomView(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	
// must be in custom view
	if ([UNIVERSE viewDirection] != VIEW_CUSTOM) 
	{
		OOJSReportError(context, @"PlayerShip.setCustomView only works when custom view is active.");
		return NO;
	}

	[player resetCustomView];
	[player noteSwitchToView:VIEW_CUSTOM fromView:VIEW_CUSTOM];

	OOJS_RETURN_BOOL(YES);
	OOJS_NATIVE_EXIT
}
} // namespace


// resetScannerZoom()
namespace {
static bool PlayerShipResetScannerZoom(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	
	[player resetScannerZoom];

	OOJS_RETURN_VOID;
	OOJS_NATIVE_EXIT
}
} // namespace


// takeInternalDamage()
namespace {
static bool PlayerShipTakeInternalDamage(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	
	BOOL took = [player takeInternalDamage];

	OOJS_RETURN_BOOL(took);
	OOJS_NATIVE_EXIT
}
} // namespace


// beginHyperspaceCountdown([int: spin_time])
namespace {
static bool PlayerShipBeginHyperspaceCountdown(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	int32_t                           spin_time;
	int32_t                           witchspaceSpinUpTime = 0;
	BOOL begun = NO;
	if (oojsArgs.count() < 1) 
	{
		witchspaceSpinUpTime = 0;
#ifdef OO_DUMP_PLANETINFO
		// quick intersystem jumps for debugging
		witchspaceSpinUpTime = 1;
#endif
	}
	else
	{
		if (!ooscript::valueToInt32(context, (OOJS_ARGV[0]), &spin_time) || spin_time < 5 || spin_time > 60)
		{
			OOJSReportBadArguments(context, @"PlayerShip", @"beginHyperspaceCountdown", 1, &OOJS_ARGV[0], nil, @"between 5 and 60 seconds");
			return NO;
		}
		if (spin_time < 5) 
		{
			witchspaceSpinUpTime = 5;
		}
		else
		{
			witchspaceSpinUpTime = spin_time;
		}
	}
	if ([player hasHyperspaceMotor] && [player status] == STATUS_IN_FLIGHT && [player witchJumpChecklist:false])
	{
		[player beginWitchspaceCountdown:witchspaceSpinUpTime];
		begun = YES;
	}
	OOJS_RETURN_BOOL(begun);
	OOJS_NATIVE_EXIT
}
} // namespace


// cancelHyperspaceCountdown()
namespace {
static bool PlayerShipCancelHyperspaceCountdown(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
       
	PlayerEntity            *player = OOPlayerForScripting();
       
	BOOL cancelled = NO;
	if ([player hasHyperspaceMotor] && [player status] == STATUS_WITCHSPACE_COUNTDOWN)
	{
		[player cancelWitchspaceCountdown];
		[player setJumpType:false];
		cancelled = YES;
	}

	OOJS_RETURN_BOOL(cancelled);
	OOJS_NATIVE_EXIT
		
}
} // namespace


namespace {
static bool PlayerShipBeginGalacticHyperspaceCountdown(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	int32_t				spin_time;
	int32_t				witchspaceSpinUpTime = 5;
	BOOL begun = NO;
	if (oojsArgs.count() == 1) 
	{

		if (!ooscript::valueToInt32(context, (OOJS_ARGV[0]), &spin_time) || spin_time < 5 || spin_time > 60)
		{
			OOJSReportBadArguments(context, @"PlayerShip", @"beginGalacticHyperspaceCountdown", 1, &OOJS_ARGV[0], nil, @"between 5 and 60 seconds");
			return NO;
		}
		if (spin_time < 5) 
		{
			witchspaceSpinUpTime = 5;
		}
		else
		{
			witchspaceSpinUpTime = spin_time;
		}
	}
	if ([player hasEquipmentItemProviding:@"EQ_GAL_DRIVE"] && [player status] == STATUS_IN_FLIGHT && [player witchJumpChecklist:true])
	{
		[player setJumpType:YES];
		[player setWitchspaceCountdown:witchspaceSpinUpTime];
		[player setStatus:STATUS_WITCHSPACE_COUNTDOWN];
		[player playGalacticHyperspace];
		// say it!
		[UNIVERSE addMessage:[NSString stringWithFormat:DESC(@"witch-galactic-in-f-seconds"), witchspaceSpinUpTime] forCount:1.0];
		begun = YES;
	}
	OOJS_RETURN_BOOL(begun);
	OOJS_NATIVE_EXIT
}
} // namespace


// setMultiFunctionDisplay(index,key)
namespace {
static bool PlayerShipSetMultiFunctionDisplay(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)

	NSString		*key = nil;
	uint32_t			index = 0;
	PlayerEntity	*player = OOPlayerForScripting();
	BOOL			OK = YES;

	if (oojsArgs.count() > 0)  
	{
		if (!ooscript::valueToECMAUint32(context, (OOJS_ARGV[0]), &index))
		{
			OOJSReportBadArguments(context, @"PlayerShip", @"setMultiFunctionDisplay", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"number (index) [, string (key)]");
			return NO;
		}
	}

	if (oojsArgs.count() > 1)
	{
		key = OOStringFromJSValue(context, OOJS_ARGV[1]);
	}

	OK = [player setMultiFunctionDisplay:index toKey:key];

	OOJS_RETURN_BOOL(OK);

	OOJS_NATIVE_EXIT
}
} // namespace


// setMultiFunctionText(key,value)
namespace {
static bool PlayerShipSetMultiFunctionText(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)

	NSString				*key = nil;
	NSString				*value = nil;
	PlayerEntity			*player = OOPlayerForScripting();
	bool					reflow = NO;

	if (oojsArgs.count() > 0)  
	{
		key = OOStringFromJSValue(context, OOJS_ARGV[0]);
	}
	if (key == nil)
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"setMultiFunctionText", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string (key) [, string (text)]");
		return NO;
	}
	if (oojsArgs.count() > 1)
	{
		value = OOStringFromJSValue(context, OOJS_ARGV[1]);
	}
	if (oojsArgs.count() > 2 && EXPECT_NOT(!ooscript::valueToBoolean(context, (OOJS_ARGV[2]), &reflow)))
	{
		OOJSReportBadArguments(context, @"setMultiFunctionText", @"reflow", oojsArgs.count(), OOJS_ARGV, nil, @"boolean");
		return NO;
	}

	if (!reflow)
	{
		[player setMultiFunctionText:value forKey:key];
	}
	else
	{
		GuiDisplayGen	*gui = [UNIVERSE gui];
		NSString *formatted = [gui reflowTextForMFD:value];
		[player setMultiFunctionText:formatted forKey:key];
	}

	OOJS_RETURN_VOID;

	OOJS_NATIVE_EXIT
}
} // namespace

// setPrimedEquipment(key, [noMessage])
namespace {
static bool PlayerShipSetPrimedEquipment(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)

	NSString				*key = nil;
	PlayerEntity			*player = OOPlayerForScripting();
	bool					showMsg = YES;

	if (oojsArgs.count() > 0)  
	{
		key = OOStringFromJSValue(context, OOJS_ARGV[0]);
	}
	if (key == nil)
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"setPrimedEquipment", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string (key)");
		return NO;
	}
	if (oojsArgs.count() > 1 && EXPECT_NOT(!ooscript::valueToBoolean(context, (OOJS_ARGV[1]), &showMsg)))
 	{
 		OOJSReportBadArguments(context, @"PlayerShip", @"setPrimedEquipment", MIN(oojsArgs.count(), 2U), OOJS_ARGV, nil, @"boolean");
 		return NO;
 	}

	OOJS_RETURN_BOOL([player setPrimedEquipment:key showMessage:showMsg]);

	OOJS_NATIVE_EXIT
}
} // namespace


// setCustomHUDDial(key,value)
namespace {
static bool PlayerShipSetCustomHUDDial(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)

	NSString				*key = nil;
	id						value = nil;
	PlayerEntity			*player = OOPlayerForScripting();

	if (oojsArgs.count() > 0)  
	{
		key = OOStringFromJSValue(context, OOJS_ARGV[0]);
	}
	if (key == nil)
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"setCustomHUDDial", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string (key), value]");
		return NO;
	}
	if (oojsArgs.count() > 1)
	{
		value = OOJSNativeObjectFromJSValue(context, OOJS_ARGV[1]);
	}
	else
	{
		value = @"";
	}

	[player setDialCustom:value forKey:key];
	

	OOJS_RETURN_VOID;

	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool PlayerShipHideHUDSelector(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)

	NSString				*key = nil;
	PlayerEntity			*player = OOPlayerForScripting();

	if (oojsArgs.count() > 0)  
	{
		key = OOStringFromJSValue(context, OOJS_ARGV[0]);
	}
	if (key == nil)
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"hideHUDSelector", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string (selector)");
		return NO;
	}
	[[player hud] setHiddenSelector:key hidden:YES];
	
	OOJS_RETURN_VOID;

	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool PlayerShipShowHUDSelector(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)

	NSString				*key = nil;
	PlayerEntity			*player = OOPlayerForScripting();

	if (oojsArgs.count() > 0)  
	{
		key = OOStringFromJSValue(context, OOJS_ARGV[0]);
	}
	if (key == nil)
	{
		OOJSReportBadArguments(context, @"PlayerShip", @"hideHUDSelector", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"string (selector)");
		return NO;
	}
	[[player hud] setHiddenSelector:key hidden:NO];
	
	OOJS_RETURN_VOID;

	OOJS_NATIVE_EXIT
}
} // namespace



namespace {
static BOOL ValidateContracts(ooscript::Context context, ooscript::CallArgs &oojsArgs, BOOL isCargo, OOSystemID *start, OOSystemID *destination, double *eta, double *fee, double *premium, NSString *functionName, unsigned *risk)
{
	OOJS_PROFILE_ENTER
	
	NSCParameterAssert(context != NULL && oojsArgs.rawVp() != NULL && start != NULL && destination != NULL && eta != NULL && fee != NULL);
	
	Context cx = (context);
	unsigned		uValue, offset = isCargo ? 2 : 1;
	double		fValue;
	int32_t			iValue;
	
	if (!ooscript::valueToInt32(cx, (OOJS_ARGV[offset + 0]), &iValue) || iValue < 0 || iValue > kOOMaximumSystemID)
	{
		OOJSReportBadArguments(context, @"PlayerShip", functionName, 1, &OOJS_ARGV[offset + 0], nil, @"system ID");
		return NO;
	}
	*start = iValue;
	
	if (!ooscript::valueToInt32(cx, (OOJS_ARGV[offset + 1]), &iValue) || iValue < 0 || iValue > kOOMaximumSystemID)
	{
		OOJSReportBadArguments(context, @"PlayerShip", functionName, 1, &OOJS_ARGV[offset + 1], nil, @"system ID");
		return NO;
	}
	*destination = iValue;
	
	
	if (!ooscript::valueToNumber(cx, (OOJS_ARGV[offset + 2]), &fValue) || !isfinite(fValue) || fValue <= [PLAYER clockTime])
	{
		OOJSReportBadArguments(context, @"PlayerShip", functionName, 1, &OOJS_ARGV[offset + 2], nil, @"number (future time)");
		return NO;
	}
	*eta = fValue;
	
	if (!ooscript::valueToNumber(cx, (OOJS_ARGV[offset + 3]), &fValue) || !isfinite(fValue) || fValue < 0.0)
	{
		OOJSReportBadArguments(context, @"PlayerShip", functionName, 1, &OOJS_ARGV[offset + 3], nil, @"number (credits quantity)");
		return NO;
	}
	*fee = fValue;

	if (oojsArgs.count() > offset+4 && ooscript::valueToNumber(cx, (OOJS_ARGV[offset + 4]), &fValue) && isfinite(fValue) && fValue >= 0.0)
	{
		*premium = fValue;
	}

	if (!isCargo)
	{
		if (oojsArgs.count() > offset+5 && ooscript::valueToECMAUint32(cx, (OOJS_ARGV[offset + 5]), &uValue) && isfinite((double)uValue))
		{
			*risk = uValue;
		}
	}
	
	return YES;
	
	OOJS_PROFILE_EXIT
}
} // namespace
