/*	test_OOJSStation.mm
	Unit tests for the Station JS binding (src/Core/Scripting/OOJSStation.h/.mm) and its
	StationEntity answers for the class (cxx::StationEntity::getJSClass): bead oo-3oxq, converted the way bead oo-ppc
	converted OOJSVector (proposed ADR-0056 amendments oo-ppc, oo-ykoy and oo-6ia4).

	As test_OOJSWormhole.mm does (amendment oo-ykoy, item 4), it runs the JS class in a real
	context on the game's own façade backend (ooscript/JSEngine_quickjs.cpp), links the game's own
	objects for the binding, its bridge, the engine's exception translator
	(OOJSEngineNativeWrappers.mm) and the converted classes it uses (OOCommodities and
	OOCommodityMarket, C++ since beads oo-9ht.25 and oo-9ht.21 deleted their façades (held as
	oo::Ref), OOEquipmentType, reached through its façade, and OOJSInterfaceDefinition, C++ since
	bead oo-9ht.61 deleted its façade), and
	stands in for the classes the binding messages (Entity, ShipEntity and StationEntity, the
	player, the universe, the game controller and the ship registry answer only the selectors the
	binding sends), for the resource manager and string expander the commodities call, the script
	engine and running script the interface definitions call, and the engine functions the binding
	links against, with the engine headers' linkage. The expectations were written against the
	Objective-C file and run on it first; they pin the JS-visible behaviour (the properties both
	ways, docking, the alert level, the launches, the interfaces, the market, the shipyard's errors,
	a non-station, a native's exception) and what the category answers the engine.
	Run: bash tools/check-core-tests.sh
*/

#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"
#import "OOWeakReference.h"
#import "OOCommodities.h"
#import "OOCommodityMarket.h"
#import "OOJSInterfaceDefinition.h"
#import "OOEquipmentType.h"
#import "OOStringExpander.h"
#include <objc/runtime.h>
#include "OOTypes.h"
#include "OOEntityEnums.h"
#include "ooscript/JSEngine.hpp"
#include "oofnd/objc/OOException.h"
#include "oofnd/PList.hpp"
#include "oofnd/String.hpp"
#import "OODescription.h"
#import "OOObjCPList.h"


// MARK: The classes, as far as the binding sees them ----------------------------------------------

@class StationEntity, GameController;

// As ShipEntity.h and StationEntity.h declare them (the test imports neither).
typedef enum
{
	ALERT_CONDITION_DOCKED	= 0,
	ALERT_CONDITION_GREEN	= 1,
	ALERT_CONDITION_YELLOW	= 2,
	ALERT_CONDITION_RED		= 3
} OOAlertCondition;

typedef enum
{
	STATION_ALERT_LEVEL_GREEN	= ALERT_CONDITION_GREEN,
	STATION_ALERT_LEVEL_YELLOW	= ALERT_CONDITION_YELLOW,
	STATION_ALERT_LEVEL_RED		= ALERT_CONDITION_RED
} OOStationAlertLevel;

typedef OOEquipmentType* OOWeaponType;

@interface Entity: OOWeakRefObject
{
@public
	std::string _name;
	ooscript::Object _jsSelf;
}
- (id) weakRefUnderlyingObject;
@end

@interface ShipEntity: Entity
@end

/*	A station. One whose equivalent tech level is 99 raises from -equivalentTechLevel, one whose
	level is 98 throws a C++ exception, so the test sees what an exception under a native becomes.
*/
@interface StationEntity: ShipEntity
{
@public
	BOOL _npcTraffic;
	BOOL _hasShipyard;
	OOStationAlertLevel _alertLevel;
	std::optional<std::string> _allegiance;
	BOOL _requiresClearance;
	float _roll;
	BOOL _fastDocking;
	BOOL _autoDocking;
	unsigned _contractors, _police, _defenders;
	OOTechLevelID _techLevel;
	float _priceFactor;
	BOOL _suppressReports;
	BOOL _breakPattern;
	std::vector<oo::PList> *_shipyard;
	int _shipyardsMade;
	oo::Ref<OOCommodityMarket> _market;
	int _abortAll;
	id _abortedShip;
	BOOL _fits;
	std::map<std::string, oo::Ref<OOJSInterfaceDefinition>> _interfaces;
	std::string _lastLaunch;
	ShipEntity *_launched;
}
- (BOOL) hasNPCTraffic;
- (void) setHasNPCTraffic:(BOOL)flag;
- (BOOL) hasShipyard;
- (OOStationAlertLevel) alertLevel;
- (void) setAlertLevel:(OOStationAlertLevel)level signallingScript:(BOOL)signallingScript;
- (OOAlertCondition) alertCondition;
- (void) increaseAlertLevel;
- (void) decreaseAlertLevel;
- (std::optional<std::string>) cxx_allegiance;
- (void) cxx_setAllegiance:(const std::optional<std::string> &)newAllegiance;
- (BOOL) requiresDockingClearance;
- (void) setRequiresDockingClearance:(BOOL)newValue;
- (GLfloat) flightRoll;
- (void) setRawRoll:(double)amount;
- (BOOL) allowsFastDocking;
- (void) setAllowsFastDocking:(BOOL)newValue;
- (BOOL) allowsAutoDocking;
- (void) setAllowsAutoDocking:(BOOL)newValue;
- (unsigned) countOfDockedContractors;
- (unsigned) countOfDockedPolice;
- (unsigned) countOfDockedDefenders;
- (OOTechLevelID) equivalentTechLevel;
- (float) equipmentPriceFactor;
- (BOOL) suppressArrivalReports;
- (void) setSuppressArrivalReports:(BOOL)newValue;
- (BOOL) hasBreakPattern;
- (void) setHasBreakPattern:(BOOL)newValue;
- (std::vector<oo::PList> *) cxx_localShipyard;
- (void) generateShipyard;
- (oo::PList) cxx_localMarketForScripting;
- (OOCommodityMarket *) localMarket;
- (void) cxx_setPrice:(OOCreditsQuantity)price forCommodity:(const std::string &)commodity;
- (void) cxx_setQuantity:(OOCargoQuantity)quantity forCommodity:(const std::string &)commodity;
- (void) abortAllDockings;
- (void) abortDockingForShip:(ShipEntity *)ship;
- (BOOL) fitsInDock:(ShipEntity *)ship andLogNoFit:(BOOL)logNoFit;
- (oo::PList) launchIndependentShip:(const std::string &)role;
- (ShipEntity *) launchDefenseShip;
- (ShipEntity *) launchEscort;
- (ShipEntity *) launchScavenger;
- (ShipEntity *) launchMiner;
- (ShipEntity *) launchPirateShip;
- (ShipEntity *) launchShuttle;
- (ShipEntity *) launchPatrol;
- (oo::PList) launchPolice;
- (void) cxx_setInterfaceDefinition:(OOJSInterfaceDefinition *)definition forKey:(const std::string &)key;
@end

@interface PlayerEntity: ShipEntity
{
@public
	StationEntity *_dockedStation;
	OOGUIScreenID _screen;
	BOOL _docked;
	int _marketRefreshes;
	int _shipyardRefreshes;
	std::string _dockLog;
}
- (StationEntity *) dockedStation;
- (OOGUIScreenID) guiScreen;
- (void) setGuiToMarketScreen;
- (void) setGuiToShipyardScreen:(NSUInteger)skip;
- (BOOL) isDocked;
- (void) setDockingClearanceStatus:(OODockingClearanceStatus)newValue;
- (void) safeAllMissiles;
- (void) enterDock:(StationEntity *)station;
- (id) cxx_commodityScriptNamed:(const std::optional<std::string> &)script;
@end

@interface GameController: OOObject
{
@public
	BOOL _paused;
}
- (BOOL) isGamePaused;
- (void) setGamePaused:(BOOL)value;
@end

@interface Universe: OOObject
{
@public
	StationEntity *_station;
	oo::Ref<OOCommodities> _commodities;
	GameController *_controller;
	OOViewID _view;
}
- (StationEntity *) station;
- (OOCommodities *) commodities;
- (GameController *) gameController;
- (void) setViewDirection:(OOViewID)vd;
- (Random_Seed) marketSeed;
- (OOSystemID) currentSystemID;
@end

@interface OOShipRegistry: OOObject
+ (OOShipRegistry *) sharedRegistry;
- (oo::PList) cxx_shipInfoForKey:(const std::string &)key;
- (oo::PList) cxx_shipyardInfoForKey:(const std::string &)key;
@end

@interface ResourceManager: OOObject
+ (oo::PList) cxx_dictionaryFromFilesNamed:(const std::string &)fileName inFolder:(const std::optional<std::string> &)folderName mergeMode:(int)mergeMode cache:(BOOL)useCache;
@end

@interface OOJavaScriptEngine: OOObject
+ (OOJavaScriptEngine *) sharedEngine;
@end


@interface Entity (OOJavaScriptExtensions)
- (void) getJSClass:(ooscript::ClassDef **)outClass andPrototype:(ooscript::Object *)outPrototype;
- (std::optional<std::string>) cxx_oo_jsClassName;
@end


#import "OOJSStation.h"

#include "oo_test.hpp"

#include <cstdarg>
#include <cstdint>
#include <cstring>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>


namespace {
ooscript::Context sContext;
ooscript::ClassDef sFakeEntityClass = { "Entity", ooscript::ClassFlag::HasPrivate };
ooscript::ClassDef sFakeShipClass = { "Ship", ooscript::ClassFlag::HasPrivate };
ooscript::Object sShipPrototype = nullptr;
std::map<ooscript::ClassDef *, ooscript::ClassDef *> sSuperclasses;
std::map<ooscript::ClassDef *, int> sConverters;
}

ooscript::Object gOOEntityJSPrototype = nullptr;


@implementation Entity

- (id) weakRefUnderlyingObject  { return self; }
- (std::optional<std::string>) cxx_descriptionComponents  { return _name; }

// As -[Entity oo_jsValueInContext:] makes one: the class and prototype the entity's category names.
- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context
{
	if (_jsSelf == nullptr)
	{
		ooscript::ClassDef *jsClass = &sFakeShipClass;
		ooscript::Object prototype = sShipPrototype;
		if ([self respondsToSelector:@selector(getJSClass:andPrototype:)])  [self getJSClass:&jsClass andPrototype:&prototype];
		_jsSelf = ooscript::newObject(context, jsClass, prototype, nullptr);
		ooscript::setPrivate(context, _jsSelf, self);
	}
	return ooscript::objectValue(_jsSelf);
}

@end


@implementation ShipEntity
@end


namespace {

ShipEntity *NewShip(const char *name)
{
	ShipEntity *ship = [[ShipEntity alloc] init];	// kept for the life of the test
	ship->_name = name;
	return ship;
}

}	// namespace


@implementation StationEntity

// As cxx::StationEntity::getJSClass and ::jsClassName answer for the engine.
- (void) getJSClass:(ooscript::ClassDef **)outClass andPrototype:(ooscript::Object *)outPrototype  { OOJSStationGetJSClass(outClass, outPrototype); }
- (std::optional<std::string>) cxx_oo_jsClassName  { return OOJSStationJSClassName(); }
- (BOOL) hasNPCTraffic  { return _npcTraffic; }
- (void) setHasNPCTraffic:(BOOL)flag  { _npcTraffic = flag; }
- (BOOL) hasShipyard  { return _hasShipyard; }
- (OOStationAlertLevel) alertLevel  { return _alertLevel; }
- (OOAlertCondition) alertCondition  { return static_cast<OOAlertCondition>(_alertLevel); }
- (void) increaseAlertLevel  { _alertLevel = static_cast<OOStationAlertLevel>(_alertLevel + 1); }
- (void) decreaseAlertLevel  { _alertLevel = static_cast<OOStationAlertLevel>(_alertLevel - 1); }
- (std::optional<std::string>) cxx_allegiance  { return _allegiance; }
- (void) cxx_setAllegiance:(const std::optional<std::string> &)newAllegiance  { _allegiance = newAllegiance; }
- (BOOL) requiresDockingClearance  { return _requiresClearance; }
- (void) setRequiresDockingClearance:(BOOL)newValue  { _requiresClearance = newValue; }
- (GLfloat) flightRoll  { return _roll; }
- (void) setRawRoll:(double)amount  { _roll = static_cast<float>(amount); }
- (BOOL) allowsFastDocking  { return _fastDocking; }
- (void) setAllowsFastDocking:(BOOL)newValue  { _fastDocking = newValue; }
- (BOOL) allowsAutoDocking  { return _autoDocking; }
- (void) setAllowsAutoDocking:(BOOL)newValue  { _autoDocking = newValue; }
- (unsigned) countOfDockedContractors  { return _contractors; }
- (unsigned) countOfDockedPolice  { return _police; }
- (unsigned) countOfDockedDefenders  { return _defenders; }
- (float) equipmentPriceFactor  { return _priceFactor; }
- (BOOL) suppressArrivalReports  { return _suppressReports; }
- (void) setSuppressArrivalReports:(BOOL)newValue  { _suppressReports = newValue; }
- (BOOL) hasBreakPattern  { return _breakPattern; }
- (void) setHasBreakPattern:(BOOL)newValue  { _breakPattern = newValue; }
- (std::vector<oo::PList> *) cxx_localShipyard  { return _shipyard; }
- (OOCommodityMarket *) localMarket  { return _market.get(); }
- (oo::PList) cxx_localMarketForScripting  { return _market->dictionaryForScripting(); }
- (void) cxx_setPrice:(OOCreditsQuantity)price forCommodity:(const std::string &)commodity  { _market->setPrice(price, commodity); }
- (void) cxx_setQuantity:(OOCargoQuantity)quantity forCommodity:(const std::string &)commodity  { _market->setQuantity(quantity, commodity); }
- (void) abortAllDockings  { _abortAll++; }
- (void) abortDockingForShip:(ShipEntity *)ship  { _abortedShip = ship; }
- (BOOL) fitsInDock:(ShipEntity *)ship andLogNoFit:(BOOL)logNoFit  { (void)ship; (void)logNoFit; return _fits; }

- (void) setAlertLevel:(OOStationAlertLevel)level signallingScript:(BOOL)signallingScript
{
	(void)signallingScript;
	if (level < STATION_ALERT_LEVEL_GREEN)  level = STATION_ALERT_LEVEL_GREEN;
	if (level > STATION_ALERT_LEVEL_RED)  level = STATION_ALERT_LEVEL_RED;
	_alertLevel = level;
}

- (OOTechLevelID) equivalentTechLevel
{
	if (_techLevel == 99)  [OOException raise:OOInvalidArgumentException format:"techlevel %s", "boom"];
	if (_techLevel == 98)  throw std::runtime_error("cxx boom");
	return _techLevel;
}

- (void) generateShipyard
{
	_shipyardsMade++;
	if (_shipyard == nullptr)  _shipyard = new std::vector<oo::PList>;
	_shipyard->push_back(oo::PList(oo::PList::Dict{ { "short_description", oo::PList(std::string("Cobra")) } }));
}

- (ShipEntity *) launched:(const char *)what
{
	_lastLaunch = what;
	return _launched;
}

- (oo::PList) launchIndependentShip:(const std::string &)role  { _lastLaunch = "role " + role; return oo::PListObject(_launched); }
- (ShipEntity *) launchDefenseShip  { return [self launched:"defense"]; }
- (ShipEntity *) launchEscort  { return [self launched:"escort"]; }
- (ShipEntity *) launchScavenger  { return [self launched:"scavenger"]; }
- (ShipEntity *) launchMiner  { return [self launched:"miner"]; }
- (ShipEntity *) launchPirateShip  { return [self launched:"pirate"]; }
- (ShipEntity *) launchShuttle  { return [self launched:"shuttle"]; }
- (ShipEntity *) launchPatrol  { return [self launched:"patrol"]; }

- (oo::PList) launchPolice
{
	_lastLaunch = "police";
	std::vector<oo::ObjCRef<ShipEntity *>> ships;
	if (_launched != nil)  ships.emplace_back(_launched);
	ships.emplace_back(_launched);
	return oo::PListFromObjects(ships);
}

- (void) cxx_setInterfaceDefinition:(OOJSInterfaceDefinition *)definition forKey:(const std::string &)key
{
	if (definition == nullptr)  _interfaces.erase(key);
	else  _interfaces[key] = oo::Ref<OOJSInterfaceDefinition>(definition);
}

@end


@implementation PlayerEntity

- (StationEntity *) dockedStation  { return _dockedStation; }
- (OOGUIScreenID) guiScreen  { return _screen; }
- (void) setGuiToMarketScreen  { _marketRefreshes++; }
- (void) setGuiToShipyardScreen:(NSUInteger)skip  { (void)skip; _shipyardRefreshes++; }
- (BOOL) isDocked  { return _docked; }
- (void) setDockingClearanceStatus:(OODockingClearanceStatus)newValue  { _dockLog += "clearance " + std::to_string(static_cast<int>(newValue)) + "; "; }
- (void) safeAllMissiles  { _dockLog += "safe; "; }
- (void) enterDock:(StationEntity *)station  { _dockLog += "dock " + (station != nil ? station->_name : std::string("nil")); _docked = YES; }
- (id) cxx_commodityScriptNamed:(const std::optional<std::string> &)script  { (void)script; return nil; }

@end


@implementation GameController
- (BOOL) isGamePaused  { return _paused; }
- (void) setGamePaused:(BOOL)value  { _paused = value; }
@end


@implementation Universe
- (StationEntity *) station  { return _station; }
- (OOCommodities *) commodities  { return _commodities.get(); }
- (GameController *) gameController  { return _controller; }
- (void) setViewDirection:(OOViewID)vd  { _view = vd; }
- (Random_Seed) marketSeed  { return Random_Seed{}; }
- (OOSystemID) currentSystemID  { return 7; }
@end


@implementation OOShipRegistry
+ (OOShipRegistry *) sharedRegistry  { return nil; }	// the test adds no ship to a shipyard
- (oo::PList) cxx_shipInfoForKey:(const std::string &)key  { (void)key; return oo::PList(); }
- (oo::PList) cxx_shipyardInfoForKey:(const std::string &)key  { (void)key; return oo::PList(); }
@end


@implementation ResourceManager

// trade-goods.plist: food and gems.
+ (oo::PList) cxx_dictionaryFromFilesNamed:(const std::string &)fileName inFolder:(const std::optional<std::string> &)folderName mergeMode:(int)mergeMode cache:(BOOL)useCache
{
	(void)fileName; (void)folderName; (void)mergeMode; (void)useCache;
	return oo::PList(oo::PList::Dict{
		{ "food", oo::PList(oo::PList::Dict{ { "name", oo::PList(std::string("Food")) }, { "quantity_unit", oo::PList(0.0) }, { "price_average", oo::PList(50.0) }, { "quantity_average", oo::PList(40.0) }, { "capacity", oo::PList(100.0) } }) },
		{ "gems", oo::PList(oo::PList::Dict{ { "name", oo::PList(std::string("Gem-stones")) }, { "quantity_unit", oo::PList(2.0) }, { "price_average", oo::PList(160.0) }, { "quantity_average", oo::PList(200.0) } }) },
	});
}

@end


@implementation OOJavaScriptEngine
+ (OOJavaScriptEngine *) sharedEngine
{
	static OOJavaScriptEngine *engine = [[OOJavaScriptEngine alloc] init];
	return engine;
}
@end


// OOJSScript's statics (OOJSScript.h), which the code under test calls since bead oo-9ht.137 deleted
// the Objective-C OOJSScript: a script's object is the OOScript root's facade (stood in for above).
class OOJSScript
{
public:
	static ::OOScript *currentlyRunningScript();
	static void pushScript(::OOScript *script);
	static void popScript(::OOScript *script);
};

::OOScript *OOJSScript::currentlyRunningScript()  { return nil; }
// The interface definition linked here pushes its owner when its callback runs, which no case does
// (the class methods were never sent; as C++ statics they must be defined).
void OOJSScript::pushScript(::OOScript *)  { std::abort(); }
void OOJSScript::popScript(::OOScript *)  { std::abort(); }


// MARK: What the rest of the game provides --------------------------------------------------------

std::optional<std::string> cxx_OOExpandDescriptionString(Random_Seed, const std::string &string, const oo::PList &, const oo::PList &, const std::optional<std::string> &, OOExpandOptions)
{
	return "<" + string + ">";
}

Random_Seed OOStringExpanderDefaultRandomSeed(void)
{
	return Random_Seed{};
}

std::string cxx_OOLookUpDescriptionPRIV(const std::string &key)
{
	return "desc(" + key + ")";
}

// Link stubs (amendment oo-zffj item 2): what OOEquipmentType reaches to load equipment, which the
// test never does (no equipment type is made), and the weapon lookups of addShipToShipyard(), which
// the test's shipyard items never reach.
@interface OOCacheManager: OOObject
@end
@implementation OOCacheManager
@end

@interface OOScript: OOObject
@end
@implementation OOScript
@end

void cxx_OOStandardsDeprecated(const std::string &)  { std::abort(); }
extern "C" BOOL OOEnforceStandards(void)  { std::abort(); }
oo::PList OOSanitizeLegacyScriptConditions(const oo::PList &, const std::optional<std::string> &)  { std::abort(); }
OOWeaponType cxx_OOWeaponTypeFromEquipmentIdentifierSloppy(const std::string &)  { std::abort(); }
extern "C" BOOL isWeaponNone(OOWeaponType)  { std::abort(); }

extern const char * const kOOJavaScriptEngineWillResetNotificationName;
const char * const kOOJavaScriptEngineWillResetNotificationName = "org.aegidian.oolite OOJavaScriptEngine will reset";


// MARK: What the rest of the engine provides ------------------------------------------------------

void cxx_OOJSReportErrorWithArguments(ooscript::Context context, const char *format, va_list args)
{
	std::string msg = oo::str::vformat(format, args);
	ooscript::reportError(context, msg.c_str());
}


void cxx_OOJSReportError(ooscript::Context context, const char *format, ...)
{
	va_list args;
	va_start(args, format);
	cxx_OOJSReportErrorWithArguments(context, format, args);
	va_end(args);
}


namespace {
std::string sLastWarning;
}

void cxx_OOJSReportWarningForCaller(ooscript::Context, const std::optional<std::string> &scriptClass, const std::optional<std::string> &function, const char *format, ...)
{
	va_list args;
	va_start(args, format);
	sLastWarning = scriptClass.value_or("-") + "." + function.value_or("-") + ": " + oo::str::vformat(format, args);
	va_end(args);
}


void cxx_OOJSReportBadArguments(ooscript::Context context, const std::optional<std::string> &scriptClass, const std::optional<std::string> &function, unsigned argc, ooscript::Value *, const std::optional<std::string> &message, const std::optional<std::string> &expectedArgsDescription)
{
	cxx_OOJSReportError(context, "bad arguments: %s.%s(%u) %s / %s", scriptClass.value_or("-").c_str(), function.value_or("-").c_str(), argc, message.value_or("-").c_str(), expectedArgsDescription.value_or("-").c_str());
}


std::optional<std::string> cxx_OOStringFromJSValue(ooscript::Context context, ooscript::Value value)
{
	if (ooscript::isNullOrUndefined(value))  return std::nullopt;
	ooscript::String str = ooscript::valueToString(context, value);
	if (str == nullptr)  return std::nullopt;
	std::size_t length = 0;
	const ooscript::Char16 *chars = ooscript::getStringCharsAndLength(context, str, &length);
	std::string result;
	for (std::size_t i = 0; i < length; i++)  result += static_cast<char>(chars[i]);	// the test's strings are ASCII
	return result;
}


extern "C" ooscript::Value OOJSValueFromNativeObject(ooscript::Context context, id object);


// A property list as JavaScript, as far as the binding hands one over: null, a string, a number,
// an object (its JS value), or an array or dictionary of those.
ooscript::Value OOJSValueFromPList(ooscript::Context context, const oo::PList &plist)
{
	if (const std::string *str = plist.getIf<std::string>())
	{
		ooscript::String js = ooscript::newStringCopyN(context, str->data(), str->size());
		return js != nullptr ? ooscript::stringValue(js) : ooscript::nullValue();
	}
	if (plist.isNumber())  return ooscript::numberValue(plist.doubleValue());
	if (id object = oo::ObjectIn(plist))  return OOJSValueFromNativeObject(context, object);
	if (const oo::PList::Array *array = plist.getIf<oo::PList::Array>())
	{
		std::vector<ooscript::Value> values;
		for (const oo::PList &element : *array)  values.push_back(OOJSValueFromPList(context, element));
		ooscript::Object object = ooscript::newArrayObject(context, static_cast<unsigned>(values.size()), values.data());
		return object != nullptr ? ooscript::objectValue(object) : ooscript::nullValue();
	}
	if (const oo::PList::Dict *dict = plist.getIf<oo::PList::Dict>())
	{
		ooscript::Object object = ooscript::newObject(context, nullptr, nullptr, nullptr);
		for (const auto &entry : *dict)
		{
			ooscript::Value value = OOJSValueFromPList(context, entry.second);
			ooscript::setProperty(context, object, entry.first.c_str(), &value);
		}
		return ooscript::objectValue(object);
	}
	return ooscript::nullValue();
}


// An object as a dictionary, as far as the test hands one over: its "short_description" property.
oo::PList cxx_OOJSPListFromJSObject(ooscript::Context context, ooscript::Object object)
{
	if (ooscript::isArrayObject(context, object))  return oo::PList(oo::PList::Array{});
	oo::PList::Dict dict;
	ooscript::Value value = ooscript::undefinedValue();
	if (ooscript::getProperty(context, object, "short_description", &value) && !ooscript::isUndefined(value))  dict["short_description"] = oo::PList(cxx_OOStringFromJSValue(context, value).value_or(""));
	return oo::PList(std::move(dict));
}


namespace {
PlayerEntity *sPlayer = nil;
}

ooscript::Context gOOJSMainThreadContext = nullptr;
Entity *gOOJSPlayerIfStale = nil;
PlayerEntity *gOOPlayer = nil;
Universe *gSharedUniverse = nil;


extern "C" {

PlayerEntity *OOPlayerForScripting(void)
{
	return sPlayer;
}


ooscript::ClassDef *JSEntityClass(void)
{
	return &sFakeEntityClass;
}


ooscript::ClassDef *JSShipClass(void)
{
	return &sFakeShipClass;
}


ooscript::Object JSShipPrototype(void)
{
	return sShipPrototype;
}


void OOJSReportBadPropertySelector(ooscript::Context context, ooscript::Object, ooscript::PropertyId, ooscript::PropertySpec *)
{
	cxx_OOJSReportError(context, "bad property selector");
}


void OOJSReportBadPropertyValue(ooscript::Context context, ooscript::Object, ooscript::PropertyId, ooscript::PropertySpec *, ooscript::Value)
{
	cxx_OOJSReportError(context, "bad property value");
}


void OOJSRegisterSubclass(ooscript::ClassDef *subclass, ooscript::ClassDef *superclass)
{
	sSuperclasses[subclass] = superclass;
}


BOOL OOJSIsSubclass(ooscript::ClassDef *putativeSubclass, ooscript::ClassDef *superclass)
{
	for (ooscript::ClassDef *c = putativeSubclass; c != nullptr; c = sSuperclasses.count(c) != 0 ? sSuperclasses[c] : nullptr)
	{
		if (c == superclass)  return YES;
	}
	return NO;
}


void OOJSRegisterObjectConverter(ooscript::ClassDef *theClass, oo::PList (*)(ooscript::Context, ooscript::Object))
{
	sConverters[theClass]++;
}


// The engine's object getter: the JS class must be a subclass of the required one, and the
// underlying object must be of the required Objective-C class.
BOOL OOJSObjectGetterImplPRIVATE(ooscript::Context context, ooscript::Object object, ooscript::ClassDef *requiredJSClass, Class requiredObjCClass, const char *, id *outObject)
{
	ooscript::ClassDef *actualClass = const_cast<ooscript::ClassDef *>(ooscript::getObjectClass(context, object));
	if (!OOJSIsSubclass(actualClass, requiredJSClass))
	{
		cxx_OOJSReportError(context, "Native method expected %s, got %s.", requiredJSClass->name, cxx_OOStringFromJSValue(context, ooscript::objectValue(object)).value_or("(null)").c_str());
		return NO;
	}
	*outObject = [(id)ooscript::getPrivate(context, object) weakRefUnderlyingObject];
	if (*outObject != nil && ![*outObject isKindOfClass:requiredObjCClass])
	{
		cxx_OOJSReportError(context, "Native method expected %s from %s.", class_getName(requiredObjCClass), requiredJSClass->name);
		*outObject = nil;
		return NO;
	}
	return YES;
}


// The engine's conversion asks the object for its JS value; nil is null.
ooscript::Value OOJSValueFromNativeObject(ooscript::Context context, id object)
{
	if (object == nil)  return ooscript::nullValue();
	return [object oo_jsValueInContext:context];
}


bool OOJSUnconstructableConstruct(ooscript::Context context, ooscript::CallArgs &)
{
	cxx_OOJSReportError(context, "unconstructable");
	return false;
}


void OOJSObjectWrapperFinalize(ooscript::Context, ooscript::Object)
{
}


void OOJSInitJSIDCachePRIVATE(const char *, ooscript::PropertyId *)
{
	std::abort();	// link stub: the commodity classes' script path
}


int sLimiterPauses = 0;
int sProfileDepth = 0;

void OOJSProfileEnter(struct OOJSProfileStackFrame *, const char *)  { sProfileDepth++; }
void OOJSProfileExit(struct OOJSProfileStackFrame *)  { sProfileDepth--; }

void OOJSPauseTimeLimiter(void)  { sLimiterPauses++; }
void OOJSResumeTimeLimiter(void)  { sLimiterPauses--; }


#ifndef NDEBUG
void OOJSUnreachable(const char *function, const char *, unsigned)
{
	std::printf("unreachable reached in %s\n", function);
	abort();
}
#endif

}	// extern "C"


oo::PList OOJSBasicPrivateObjectConverter(ooscript::Context, ooscript::Object)
{
	return oo::PList();
}


// MARK: The context -------------------------------------------------------------------------------

namespace {

ooscript::Runtime sRuntime;
ooscript::Object sGlobal;
StationEntity *sStation = nil;
StationEntity *sOther = nil;
ShipEntity *sShip = nil;
Universe *sUniverse = nil;


void Define(const char *name, ooscript::Value value)
{
	ooscript::setProperty(sContext, sGlobal, name, &value);
}


void SetUpContext()
{
	if (sContext != nullptr)  return;
	sRuntime = ooscript::newRuntime(8u * 1024u * 1024u);
	sContext = ooscript::newContext(sRuntime, 8192);
	gOOJSMainThreadContext = sContext;
	ooscript::beginRequest(sContext);
	sGlobal = ooscript::getGlobalObject(sContext);
	ooscript::initStandardClasses(sContext, sGlobal);
	gOOEntityJSPrototype = ooscript::initClass(sContext, sGlobal, nullptr, &sFakeEntityClass, OOJSUnconstructableConstruct, 0, nullptr, nullptr, nullptr, nullptr);
	sShipPrototype = ooscript::initClass(sContext, sGlobal, gOOEntityJSPrototype, &sFakeShipClass, OOJSUnconstructableConstruct, 0, nullptr, nullptr, nullptr, nullptr);
	OOJSRegisterSubclass(&sFakeShipClass, &sFakeEntityClass);
	InitOOJSStation(sContext, sGlobal);

	sUniverse = [[Universe alloc] init];	// kept for the life of the test
	gSharedUniverse = sUniverse;
	sUniverse->_controller = [[GameController alloc] init];
	sUniverse->_commodities = oo::makeRef<OOCommodities>();
	sPlayer = [[PlayerEntity alloc] init];
	sPlayer->_name = "player";
	sPlayer->_screen = GUI_SCREEN_STATUS;
	gOOPlayer = sPlayer;
	sStation = [[StationEntity alloc] init];
	sStation->_name = "Coriolis";
	sStation->_npcTraffic = YES;
	sStation->_alertLevel = STATION_ALERT_LEVEL_GREEN;
	sStation->_allegiance = "galcop";
	sStation->_roll = 0.25f;
	sStation->_autoDocking = YES;
	sStation->_contractors = 2;
	sStation->_police = 3;
	sStation->_defenders = 4;
	sStation->_techLevel = 9;
	sStation->_priceFactor = 1.5f;
	sStation->_market = sUniverse->_commodities->generateBlankMarket();
	sUniverse->_station = sStation;
	sOther = [[StationEntity alloc] init];
	sOther->_name = "Rock Hermit";
	sShip = NewShip("Cobra");
	Define("station", [sStation oo_jsValueInContext:sContext]);
	Define("other", [sOther oo_jsValueInContext:sContext]);
	Define("ship", [sShip oo_jsValueInContext:sContext]);
}


// Evaluates src and gives its result as a string ("undefined", "null", ...), or "threw: <message>".
std::string Eval(const char *src)
{
	SetUpContext();
	std::string wrapped = std::string("(function () { try { return String(") + src + "); } catch (e) { return 'threw: ' + (e && e.message !== undefined ? e.message : e); } })()";
	ooscript::Value result = ooscript::undefinedValue();
	if (!ooscript::evaluateScript(sContext, sGlobal, wrapped.c_str(), static_cast<unsigned>(wrapped.size()), "test.js", 1, &result))
	{
		ooscript::clearPendingException(sContext);
		return "<evaluation failed>";
	}
	return cxx_OOStringFromJSValue(sContext, result).value_or("<not a string>");
}


// Eval, and print what came back when it is not what the check expects.
std::string EvalShown(const char *src, const char *expected)
{
	std::string result = Eval(src);
	if (result != expected)  std::printf("    %s\n    gave: %s\n", src, result.c_str());
	return result;
}
#define OO_CHECK_EVAL(src, expected)  OO_CHECK_EQ(EvalShown(src, expected), expected)

}	// namespace


// MARK: Tests -------------------------------------------------------------------------------------

OO_TEST(registration)
{
	SetUpContext();
	ooscript::ClassDef *stationClass = nullptr;
	ooscript::Object prototype = nullptr;
	[sStation getJSClass:&stationClass andPrototype:&prototype];
	OO_CHECK(stationClass != nullptr && std::strcmp(stationClass->name, "Station") == 0);
	OO_CHECK(prototype != nullptr);
	OO_CHECK(OOJSIsSubclass(stationClass, &sFakeShipClass));
	OO_CHECK_EQ(sConverters[stationClass], 1);
	OO_CHECK([sStation cxx_oo_jsClassName] == std::optional<std::string>("Station"));
	OO_CHECK_EVAL("typeof Station", "function");
	OO_CHECK_EVAL("new Station()", "threw: unconstructable");
	OO_CHECK_EVAL("Object.getPrototypeOf(Station.prototype) === Ship.prototype", "true");
	OO_CHECK_EVAL("station instanceof Station && !(ship instanceof Station)", "true");
}


OO_TEST(properties)
{
	SetUpContext();
	OO_CHECK_EVAL("station.isMainStation + ' ' + other.isMainStation", "true false");
	OO_CHECK_EVAL("station.hasNPCTraffic", "true");
	OO_CHECK_EVAL("station.hasShipyard", "false");
	OO_CHECK_EVAL("station.alertCondition", "1");
	OO_CHECK_EVAL("station.allegiance + ' ' + other.allegiance", "galcop null");
	OO_CHECK_EVAL("station.requiresDockingClearance", "false");
	OO_CHECK_EVAL("station.roll", "0.25");
	OO_CHECK_EVAL("station.allowsFastDocking + ' ' + station.allowsAutoDocking", "false true");
	OO_CHECK_EVAL("[station.dockedContractors, station.dockedPolice, station.dockedDefenders].join()", "2,3,4");
	OO_CHECK_EVAL("station.equivalentTechLevel", "9");
	OO_CHECK_EVAL("station.equipmentPriceFactor", "1.5");
	OO_CHECK_EVAL("station.suppressArrivalReports + ' ' + station.breakPattern", "false false");
	OO_CHECK_EVAL("station.shipyard", "null");
	OO_CHECK_EVAL("typeof station.market.food", "object");
	OO_CHECK_EVAL("Object.keys(Station.prototype).join()", "alertCondition,allegiance,allowsAutoDocking,allowsFastDocking,breakPattern,dockedContractors,dockedDefenders,dockedPolice,equipmentPriceFactor,equivalentTechLevel,hasNPCTraffic,hasShipyard,isMainStation,market,requiresDockingClearance,roll,suppressArrivalReports,shipyard");
	// Read-only.
	OO_CHECK_EVAL("(function () { station.dockedPolice = 9; return station.dockedPolice; })()", "3");
}


OO_TEST(setters)
{
	SetUpContext();
	OO_CHECK_EVAL("(function () { station.hasNPCTraffic = false; return station.hasNPCTraffic; })()", "false");
	OO_CHECK_EVAL("(function () { station.alertCondition = 3; return station.alertCondition; })()", "3");
	OO_CHECK_EVAL("(function () { station.alertCondition = 7; return station.alertCondition; })()", "3");	// range-checked by the station
	OO_CHECK_EVAL("(function () { station.alertCondition = 1; return station.alertCondition; })()", "1");
	OO_CHECK_EVAL("(function () { station.allegiance = 'pirate'; return station.allegiance; })()", "pirate");
	OO_CHECK_EVAL("(function () { station.allegiance = null; return station.allegiance; })()", "threw: bad property value");
	OO_CHECK_EVAL("(function () { station.requiresDockingClearance = 1; return station.requiresDockingClearance; })()", "true");
	OO_CHECK_EVAL("(function () { station.roll = 1; return station.roll; })()", "1");
	OO_CHECK_EVAL("(function () { station.roll = 10; return station.roll.toFixed(4); })()", "3.1416");	// clamped to ±pi
	OO_CHECK_EVAL("(function () { station.roll = -10; return station.roll.toFixed(4); })()", "-3.1416");
	OO_CHECK_EVAL("(function () { station.allowsFastDocking = true; station.allowsAutoDocking = false; return station.allowsFastDocking + ' ' + station.allowsAutoDocking; })()", "true false");
	OO_CHECK_EVAL("(function () { station.suppressArrivalReports = true; station.breakPattern = true; return station.suppressArrivalReports + ' ' + station.breakPattern; })()", "true true");
	sStation->_npcTraffic = YES;
	sStation->_allegiance = "galcop";
	sStation->_requiresClearance = NO;
	sStation->_roll = 0.25f;
	sStation->_fastDocking = NO;
	sStation->_autoDocking = YES;
	sStation->_suppressReports = NO;
	sStation->_breakPattern = NO;
}


OO_TEST(docking)
{
	SetUpContext();
	sStation->_abortAll = 0;
	OO_CHECK_EVAL("station.abortAllDockings()", "undefined");
	OO_CHECK_EQ(sStation->_abortAll, 1);
	OO_CHECK_EVAL("station.abortDockingForShip(ship)", "undefined");
	OO_CHECK(sStation->_abortedShip == sShip);
	OO_CHECK_EVAL("station.abortDockingForShip()", "threw: bad arguments: Station.abortDockingForShip(0) - / ship in docking queue");
	sStation->_fits = YES;
	OO_CHECK_EVAL("station.canDockShip(ship)", "true");
	sStation->_fits = NO;
	OO_CHECK_EVAL("station.canDockShip(ship)", "false");
	OO_CHECK_EVAL("station.canDockShip()", "threw: bad arguments: Station.canDockShip(0) - / shipEntity");
	// dockPlayer(): unpauses the game, then docks the player unless it is docked.
	sUniverse->_controller->_paused = YES;
	OO_CHECK_EVAL("station.dockPlayer()", "undefined");
	OO_CHECK(!sUniverse->_controller->_paused);
	OO_CHECK_EQ(sPlayer->_dockLog, "clearance " + std::to_string(static_cast<int>(DOCKING_CLEARANCE_STATUS_GRANTED)) + "; safe; dock Coriolis");
	OO_CHECK_EQ(static_cast<int>(sUniverse->_view), static_cast<int>(VIEW_FORWARD));
	sPlayer->_dockLog.clear();
	OO_CHECK_EVAL("other.dockPlayer()", "undefined");
	OO_CHECK_EQ(sPlayer->_dockLog, std::string());
	sPlayer->_docked = NO;
}


OO_TEST(alertLevel)
{
	SetUpContext();
	sStation->_alertLevel = STATION_ALERT_LEVEL_GREEN;
	OO_CHECK_EVAL("(function () { station.increaseAlertLevel(); station.increaseAlertLevel(); station.increaseAlertLevel(); return station.alertCondition; })()", "3");
	OO_CHECK_EVAL("(function () { station.decreaseAlertLevel(); station.decreaseAlertLevel(); station.decreaseAlertLevel(); return station.alertCondition; })()", "1");
}


OO_TEST(launches)
{
	SetUpContext();
	sStation->_launched = sShip;
	OO_CHECK_EVAL("station.launchShipWithRole('trader') === ship", "true");
	OO_CHECK_EQ(sStation->_lastLaunch, std::string("role trader"));
	sStation->_abortAll = 0;
	OO_CHECK_EVAL("station.launchShipWithRole('trader', true) === ship", "true");
	OO_CHECK_EQ(sStation->_abortAll, 1);
	OO_CHECK_EVAL("station.launchShipWithRole()", "threw: bad arguments: Station.launchShipWithRole(0) - / string (role)");
	const char *launches[][2] = { { "launchDefenseShip", "defense" }, { "launchEscort", "escort" }, { "launchScavenger", "scavenger" }, { "launchMiner", "miner" }, { "launchPirateShip", "pirate" }, { "launchShuttle", "shuttle" }, { "launchPatrol", "patrol" } };
	for (const auto &launch : launches)
	{
		std::string src = std::string("station.") + launch[0] + "() === ship";
		OO_CHECK_EVAL(src.c_str(), "true");
		OO_CHECK_EQ(sStation->_lastLaunch, std::string(launch[1]));
	}
	OO_CHECK_EVAL("station.launchPolice().length + ' ' + (station.launchPolice()[0] === ship)", "2 true");
	sStation->_launched = nil;
	OO_CHECK_EVAL("station.launchMiner()", "null");
	OO_CHECK_EVAL("station.launchShipWithRole('trader')", "null");
	OO_CHECK_EVAL("station.launchPolice().length", "0");	// no ship: none in the array
	OO_CHECK_EQ(sLimiterPauses, 0);
}


OO_TEST(interfaces)
{
	SetUpContext();
	OO_CHECK_EVAL("station.setInterface('k', {title: 'T', summary: 'S', category: 'C', callback: function () {}})", "undefined");
	OO_CHECK(sStation->_interfaces.count("k") == 1);
	if (sStation->_interfaces.count("k") == 1)
	{
		OOJSInterfaceDefinition *definition = sStation->_interfaces["k"].get();
		OO_CHECK(definition->title() == std::optional<std::string>("T"));
		OO_CHECK(definition->summary() == std::optional<std::string>("S"));
		OO_CHECK(definition->category() == std::optional<std::string>("C"));
		OO_CHECK(ooscript::isObject(definition->callback()) && definition->callbackThis() == nullptr);
	}
	OO_CHECK_EVAL("station.setInterface('k2', {title: 'T', summary: 'S', callback: function () {}, cbThis: station})", "undefined");
	OO_CHECK(sStation->_interfaces.count("k2") == 1 && sStation->_interfaces["k2"]->category() == std::optional<std::string>("desc(interfaces-category-uncategorised)"));
	OO_CHECK(sStation->_interfaces.count("k2") == 1 && sStation->_interfaces["k2"]->callbackThis() == sStation->_jsSelf);
	OO_CHECK_EVAL("station.setInterface('k2', {title: 'T', summary: 'S', category: '', callback: function () {}})", "undefined");
	OO_CHECK(sStation->_interfaces.count("k2") == 1 && sStation->_interfaces["k2"]->category() == std::optional<std::string>("desc(interfaces-category-uncategorised)"));
	OO_CHECK_EVAL("station.setInterface('k')", "undefined");
	OO_CHECK(sStation->_interfaces.count("k") == 0);
	OO_CHECK_EVAL("station.setInterface('k2', null)", "undefined");
	OO_CHECK(sStation->_interfaces.empty());
	OO_CHECK_EVAL("station.setInterface()", "threw: bad arguments: Station.setInterface(0) - / key [, definition]");
	OO_CHECK_EVAL("station.setInterface('k', {summary: 'S'})", "threw: bad arguments: Station.setInterface(1) - / key [, definition]; if definition is set, it must have a 'title' property.");
	OO_CHECK_EVAL("station.setInterface('k', {title: ''})", "threw: bad arguments: Station.setInterface(1) - / key [, definition]; if definition is set, 'title' property must be a non-empty string.");
	OO_CHECK_EVAL("station.setInterface('k', {title: 'T'})", "threw: bad arguments: Station.setInterface(1) - / key [, definition]; if definition is set, it must have a 'summary' property.");
	OO_CHECK_EVAL("station.setInterface('k', {title: 'T', summary: ''})", "threw: bad arguments: Station.setInterface(1) - / key [, definition]; if definition is set, 'summary' property must be a non-empty string.");
	OO_CHECK_EVAL("station.setInterface('k', {title: 'T', summary: 'S'})", "threw: bad arguments: Station.setInterface(1) - / key [, definition]; if definition is set, it must have a 'callback' property.");
	OO_CHECK_EVAL("station.setInterface('k', {title: 'T', summary: 'S', callback: 5})", "threw: bad arguments: Station.setInterface(1) - / key [, definition]; 'callback' property must be a function.");
	OO_CHECK(sStation->_interfaces.empty());
}


OO_TEST(market)
{
	SetUpContext();
	OO_CHECK_EVAL("station.setMarketPrice('food', 120)", "true");
	OO_CHECK_EQ(sStation->_market->priceForGood("food"), 120u);
	// A blank market has no capacity: only 0 fits.
	sStation->_market->setQuantity(5, "food");
	OO_CHECK_EVAL("station.setMarketQuantity('food', 0)", "true");
	OO_CHECK_EQ(sStation->_market->quantityForGood("food"), 0u);
	OO_CHECK_EVAL("station.market.food.quantity + ' ' + station.market.food.price", "0 120");
	OO_CHECK_EVAL("station.setMarketQuantity('food', 1)", "threw: bad arguments: Station.setMarketQuantity(2) - / Quantity must be between 0 and the station market capacity");
	OO_CHECK_EVAL("station.setMarketQuantity('food', -1)", "threw: bad arguments: Station.setMarketQuantity(2) - / Quantity must be between 0 and the station market capacity");
	OO_CHECK_EVAL("station.setMarketPrice('food', -1)", "threw: bad arguments: Station.setMarketPrice(2) - / Price must be at least 0 decicredits");
	OO_CHECK_EVAL("station.setMarketPrice('unobtainium', 1)", "threw: bad arguments: Station.setMarketPrice(2) - / Unrecognised commodity type");
	OO_CHECK_EVAL("station.setMarketQuantity('unobtainium', 1)", "threw: bad arguments: Station.setMarketQuantity(2) - / Unrecognised commodity type");
	OO_CHECK_EVAL("station.setMarketPrice('food')", "threw: bad arguments: Station.setMarketPrice(1) - / commodity, credits");
	OO_CHECK_EVAL("station.setMarketQuantity('food')", "threw: bad arguments: Station.setMarketQuantity(1) - / commodity, units");
	// The market screen is refreshed when the player is docked here and looking at it.
	sPlayer->_dockedStation = sStation;
	sPlayer->_screen = GUI_SCREEN_MARKET;
	sPlayer->_marketRefreshes = 0;
	OO_CHECK_EVAL("station.setMarketPrice('food', 100) && station.setMarketQuantity('food', 0)", "true");
	OO_CHECK_EQ(sPlayer->_marketRefreshes, 2);
	sPlayer->_dockedStation = nil;
	sPlayer->_screen = GUI_SCREEN_STATUS;
}


OO_TEST(shipyard)
{
	SetUpContext();
	sLastWarning.clear();
	OO_CHECK_EVAL("station.addShipToShipyard({short_description: 'x'})", "<evaluation failed>");
	OO_CHECK_EQ(sLastWarning, std::string("Station.removeShipFromShipyard: Station does not have shipyard."));
	OO_CHECK_EVAL("station.removeShipFromShipyard(0)", "<evaluation failed>");
	sStation->_hasShipyard = YES;
	sStation->_shipyardsMade = 0;
	OO_CHECK_EVAL("station.shipyard.length + ' ' + station.shipyard[0].short_description", "1 Cobra");
	OO_CHECK_EQ(sStation->_shipyardsMade, 1);
	OO_CHECK_EVAL("station.addShipToShipyard(null)", "undefined");
	OO_CHECK_EVAL("station.addShipToShipyard()", "threw: bad arguments: Station.addShipToShipyard(0) - / shipyard item definition");
	OO_CHECK_EVAL("station.addShipToShipyard({})", "threw: bad arguments: Station.addShipToShipyard(1) - / 'short_description' in dictionary");
	OO_CHECK_EVAL("station.addShipToShipyard([])", "threw: Unidentified native exception");
	OO_CHECK_EVAL("station.addShipToShipyard({short_description: 'x'})", "threw: bad arguments: Station.addShipToShipyard(1) - / 'shipdata_key' in dictionary");
	OO_CHECK_EVAL("station.removeShipFromShipyard(3)", "threw: bad arguments: Station.removeShipFromShipyard(1) - / valid ship index");
	sPlayer->_dockedStation = sStation;
	sPlayer->_screen = GUI_SCREEN_SHIPYARD;
	OO_CHECK_EVAL("station.removeShipFromShipyard(0) + ' ' + station.shipyard.length", "true 0");
	OO_CHECK_EQ(sPlayer->_shipyardRefreshes, 1);
	sPlayer->_dockedStation = nil;
	sPlayer->_screen = GUI_SCREEN_STATUS;
	sStation->_hasShipyard = NO;
}


OO_TEST(otherObjects)
{
	SetUpContext();
	// A non-station entity is refused without a JS error; a non-entity is an error.
	OO_CHECK_EVAL("Object.getOwnPropertyDescriptor(Station.prototype, 'roll').get.call(ship)", "<evaluation failed>");
	OO_CHECK_EVAL("Station.prototype.launchMiner.call(ship)", "undefined");	// stale reference: no-op
	OO_CHECK_EVAL("Station.prototype.launchMiner.call({})", "undefined");	// not a station: no-op
	OO_CHECK_EVAL("Station.prototype.roll", "threw: Native method expected Entity, got [object Object].");
}


OO_TEST(nativeExceptions)
{
	SetUpContext();
	sStation->_techLevel = 99;
	OO_CHECK_EVAL("station.equivalentTechLevel", "threw: Native exception: techlevel boom");
	sStation->_techLevel = 98;
	OO_CHECK_EVAL("station.equivalentTechLevel", "threw: Native exception: cxx boom");
	sStation->_techLevel = 9;
	OO_CHECK_EVAL("station.equivalentTechLevel", "9");
	OO_CHECK_EQ(sLimiterPauses, 0);
	OO_CHECK_EQ(sProfileDepth, 0);
	OO_CHECK(ooscript::isInRequest(sContext));
}


// The JS glue of OOEquipmentType (OOJSPrivateObject), defined in OOJSEquipmentInfo.mm, which
// this test does not link (bead oo-6symp.3): the vtable names these.
ooscript::Value OOEquipmentType::jsValueInContext(ooscript::Context)  { return ooscript::Value(); }
void OOEquipmentType::clearJSSelf(ooscript::Object)  {}
std::optional<std::string> OOEquipmentType::jsDescription()  { return std::nullopt; }


OO_TEST_MAIN()
