/*

OOJSSystemInfo.mm

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

#import "OOJSSystemInfo.h"
#import "OOJavaScriptEngine.h"
#import "PlayerEntityScriptMethods.h"
#import "Universe.h"
#import "OOJSVector.h"
#import "OOIsNumberLiteral.h"
#import "OOConstToString.h"
#import "OOSystemDescriptionManager.h"
#import "OOJSScript.h"
#import "OOStringBridge.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>
#import "OOFoundationBridge.h"
#include "oofnd/objc/OOAssert.h"

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar): the class dispatch table becomes a static ooscript::ClassDef
	(the stub hooks are nullptr), the engine's own InitClass entry point becomes
	ooscript::initClass, native methods and class hooks take the façade's hook signature
	(Context/Object/PropertyId/Value pointer/CallArgs reference), and the directly spelled
	object-creation, numeric-conversion, property-id and function-call engine entry points
	become their ooscript:: façade equivalents. Natives take the
	façade signature directly (ooscript::Context and a CallArgs reference) and the OOJS_*
	argument-marshalling macros expand to the CallArgs accessors, so the rest of each function
	body is UNCHANGED. `this` is
	renamed to `thisObj` because it is a reserved word once this file compiles as Objective-C++
	(ADR-0001).

	SystemInfo is registered as an object converter with &sSystemInfoClass, the same
	ooscript::ClassDef that ooscript::getClass() reports for its instances.
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
using ooscript::EnumerateOp;

// Byte-identical façade <-> jsapi views, local to this call site (see OOJSVector.mm).
namespace {
static inline Object    *OOJSFOBJP(ooscript::Object *o)  { return reinterpret_cast<Object*>(o); }
} // namespace


namespace {
static ooscript::Object sSystemInfoPrototype;
} // namespace
namespace {
static ooscript::Object sCachedSystemInfo;
} // namespace
namespace {
static OOGalaxyID sCachedGalaxy;
} // namespace
namespace {
static OOSystemID sCachedSystem;
} // namespace


namespace {
static bool SystemInfoDeleteProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool SystemInfoGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool SystemInfoSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace
namespace {
static void SystemInfoFinalize(Context cx, Object obj);
} // namespace
namespace {
// The state of a SystemInfo enumeration, kept in the enumeration's private slot (was a retained
// Foundation enumerator over the keys).
struct SystemInfoEnumerationState
{
	std::vector<std::string>	keys;
	std::size_t					next = 0;
};
} // namespace


namespace {
static bool SystemInfoEnumerate(Context cx, Object obj, EnumerateOp enumOp, Value *state, PropertyId *idp);
} // namespace

namespace {
static bool SystemInfoDistanceToSystem(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemInfoRouteToSystem(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemInfoSamplePrice(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemInfoSetPropertyMethod(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace

namespace {
static bool SystemInfoStaticSetInterstellarProperty(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool SystemInfoStaticFilteredSystems(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace

namespace {
static ClassDef sSystemInfoClass =
{
	"SystemInfo",
	ClassFlag::HasPrivate | ClassFlag::NewEnumerate,
	
	nullptr,						// addProperty (engine default: PropertyStub)
	SystemInfoDeleteProperty,		// delProperty
	SystemInfoGetProperty,			// getProperty
	SystemInfoSetProperty,			// setProperty
	nullptr,						// enumerate (ooscript::ClassFlag::NewEnumerate used instead)
	SystemInfoEnumerate,			// newEnumerate
	nullptr,						// resolve (engine default: ResolveStub)
	nullptr,						// convert (engine default: ConvertStub)
	SystemInfoFinalize,				// finalize
	nullptr,						// call
	nullptr,						// construct
	nullptr,						// backend: owned by the façade backend, must start null
};
} // namespace


enum : std::uint8_t
{
	// Property IDs
	kSystemInfo_coordinates,	// system coordinates (in LY), Vector3D (with z = 0), read-only
	kSystemInfo_internalCoordinates,	// system coordinates (unscaled), Vector3D (with z = 0), read-only
	kSystemInfo_galaxyID,		// galaxy number, integer, read-only
	kSystemInfo_systemID		// system number, integer, read-only
};


namespace {
static PropertySpec sSystemInfoProperties[] =
{
	// JS name					ID									flags								getter	setter
	{ "coordinates",			kSystemInfo_coordinates,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared,	nullptr, nullptr },
	{ "internalCoordinates",	kSystemInfo_internalCoordinates,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared,	nullptr, nullptr },
	{ "galaxyID",				kSystemInfo_galaxyID,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared,	nullptr, nullptr },
	{ "systemID",				kSystemInfo_systemID,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared,	nullptr, nullptr },
	{ 0 }
};
} // namespace


// A raw jsapi mirror of sSystemInfoProperties, used only for the bad-property error reporter
// in OOJavaScriptEngine.m (OOJSReportBadPropertySelector): that helper is outside this bead's
// scope (shared across every binding file) and still takes a ooscript::PropertySpec*, not
// ooscript::PropertySpec* (see OOJSVector.mm for the same pattern).
namespace {
static ooscript::PropertySpec sSystemInfoPropertiesRaw[] =
{
	// JS name					ID									flags
	{ "coordinates",			kSystemInfo_coordinates,			OOJS_PROP_READONLY_CB },
	{ "internalCoordinates",	kSystemInfo_internalCoordinates,	OOJS_PROP_READONLY_CB },
	{ "galaxyID",				kSystemInfo_galaxyID,				OOJS_PROP_READONLY_CB },
	{ "systemID",				kSystemInfo_systemID,				OOJS_PROP_READONLY_CB },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sSystemInfoMethods[] =
{
	// JS name					Function					min args	flags
	{ "toString",				OOJSObjectWrapperToString,				0,			0 },
	{ "distanceToSystem",		SystemInfoDistanceToSystem,		1,			0 },
	{ "routeToSystem",			SystemInfoRouteToSystem,		1,			0 },
	{ "samplePrice",			SystemInfoSamplePrice,			1,			0 },
	{ "setProperty",			SystemInfoSetPropertyMethod,	3,			0 },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sSystemInfoStaticMethods[] =
{
	// JS name						Function									min args	flags
	{ "filteredSystems",			SystemInfoStaticFilteredSystems,			2,			0 },
	{ "setInterstellarProperty",	SystemInfoStaticSetInterstellarProperty,	4,			0 },
	{ 0 }
};
} // namespace


namespace {

// A string, or null for none.
oo::PList StringOrNull(const std::optional<std::string> &string)
{
	return string.has_value() ? oo::PList(*string) : oo::PList();
}

// A manifest identifier as the -fromManifest: arguments read it: a string, else none.
std::optional<std::string> ManifestString(const oo::PList &manifest)
{
	if (const std::string *text = manifest.getIf<std::string>())  return *text;
	return std::nullopt;
}

// -intValue of a system property (an NSNumber or an NSString; 0 for nil).
int PropertyIntValue(const oo::PList &value)
{
	if (const std::string *text = value.getIf<std::string>())  return oo::plist_get::intValue(oo::utf8ToUtf16(*text));
	return static_cast<int>(value.int64Value());
}

}	// namespace


// Helper class wrapped by JS SystemInfo objects
@interface OOSystemInfo: OOObject
{
@private
	OOGalaxyID				_galaxy;
	OOSystemID				_system;
	std::string				_planetKey;
}

- (id) initWithGalaxy:(OOGalaxyID)galaxy system:(OOSystemID)system;

- (oo::PList) cxx_valueForKey:(const std::optional<std::string> &)key;	// null for none
- (void) cxx_setValue:(const oo::PList &)value forKey:(const std::string &)key;	// a null value removes

- (std::vector<std::string>) cxx_allKeys;

- (OOGalaxyID) galaxy;
- (OOSystemID) system;
//- (Random_Seed) systemSeed;

@end


namespace {
DEFINE_JS_OBJECT_GETTER(JSSystemInfoGetSystemInfo, &sSystemInfoClass, sSystemInfoPrototype, OOSystemInfo);
} // namespace


@implementation OOSystemInfo

- (id) init
{
	[self release];
	return nil;
}


- (id) initWithGalaxy:(OOGalaxyID)galaxy system:(OOSystemID)system
{
	if (galaxy > kOOMaximumGalaxyID || system > kOOMaximumSystemID || system < kOOMinimumSystemID)
	{
		[self release];
		return nil;
	}
	
	self = [super init];
	if (self)
	{
		_galaxy = galaxy;
		_system = system;
		_planetKey = oo::str::format("%u %i", galaxy, system);
	}
	return self;
}


- (std::optional<std::string>) cxx_descriptionComponents
{
	return oo::str::format("galaxy %u, system %i", _galaxy, _system);
}


- (std::optional<std::string>) cxx_shortDescriptionComponents
{
	return _planetKey;
}


- (std::optional<std::string>) cxx_oo_jsClassName
{
	return std::string("SystemInfo");
}


- (BOOL) isEqual:(id)other
{
	return other == self ||
		   ([other isKindOfClass:[OOSystemInfo class]] &&
			[other galaxy] == _galaxy &&
			[other system] == _system);
			 
}


- (NSUInteger) hash
{
	NSUInteger hash = _galaxy;
	hash <<= 16;
	hash |= (uint16_t)_system;
	return hash;
}


- (oo::PList) cxx_valueForKey:(const std::optional<std::string> &)key
{
	if ([UNIVERSE inInterstellarSpace] && _system == -1) 
	{
		// -objectForKey: (a nil key found nothing)
		const oo::PList systemData = [UNIVERSE cxx_currentSystemData];
		const oo::PList *value = key.has_value() ? systemData.find(*key) : nullptr;
		return (value != nullptr) ? *value : oo::PList();
	}
	return [UNIVERSE cxx_systemDataForGalaxy:_galaxy planet:_system key:key.value_or("")];	// (a nil key as "")
}


- (void) cxx_setValue:(const oo::PList &)value forKey:(const std::string &)key
{
	// The running script's manifest identifier, handed on as it was read.
	const oo::PList manifest = [[OOJSScript currentlyRunningScript] cxx_propertyNamed:kLocalManifestProperty];

	[UNIVERSE cxx_setSystemDataForGalaxy:_galaxy planet:_system key:key value:value fromManifest:ManifestString(manifest) forLayer:OO_LAYER_OXP_DYNAMIC];
}


- (std::vector<std::string>) cxx_allKeys
{
	if ([UNIVERSE inInterstellarSpace] && _system == -1) 
	{
		// the dictionary's keys, in key order (-allKeys gave hash order)
		std::vector<std::string> keys;
		if (const oo::PList::Dict *systemData = [UNIVERSE cxx_currentSystemData].getIf<oo::PList::Dict>())
		{
			for (const auto &entry : *systemData)  keys.push_back(entry.first);
		}
		return keys;
	}
	return [UNIVERSE cxx_systemDataKeysForGalaxy:_galaxy planet:_system];
}


- (OOGalaxyID) galaxy
{
	return _galaxy;
}


- (OOSystemID) system
{
	return _system;
}


/*- (Random_Seed) systemSeed
{
	OOAssert([PLAYER currentGalaxyID] == _galaxy, "Attempt to use -[OOSystemInfo systemSeed] from a different galaxy.");
	return [UNIVERSE systemSeedForSystemNumber:_system];
	}*/


- (NSPoint) coordinates
{
	if ([UNIVERSE inInterstellarSpace] && _system == -1) 
	{
		return [PLAYER galaxy_coordinates];
	}
	return [UNIVERSE coordinatesForSystem:_system];
}


- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context
{
	ooscript::Object jsSelf = NULL;
	ooscript::Value						result = ooscript::nullValue();
	
	jsSelf = (ooscript::newObject((context), &sSystemInfoClass, (sSystemInfoPrototype), nullptr));
	if (jsSelf != NULL)
	{
		if (!ooscript::setPrivate((context), (jsSelf), [self retain]))  jsSelf = NULL;
	}
	if (jsSelf != NULL)  result = ooscript::objectValue(jsSelf);
	
	return result;
}

@end



void InitOOJSSystemInfo(ooscript::Context context, ooscript::Object global)
{
	Object proto = ooscript::initClass((context), (global), nullptr, &sSystemInfoClass, OOJSUnconstructableConstruct, 0, sSystemInfoProperties, sSystemInfoMethods, NULL, sSystemInfoStaticMethods);
	sSystemInfoPrototype = (proto);
	OOJSRegisterObjectConverter(&sSystemInfoClass, OOJSBasicPrivateObjectConverter);
}


ooscript::Value GetJSSystemInfoForSystem(ooscript::Context context, OOGalaxyID galaxy, OOSystemID system)
{
	OOJS_PROFILE_ENTER
	
	// Use cached object if possible.
	if (sCachedSystemInfo != NULL &&
		sCachedGalaxy == galaxy &&
		sCachedSystem == system)
	{
		return ooscript::objectValue(sCachedSystemInfo);
	}
	
	// If not, create a new one.
	OOSystemInfo *info = nil;
	ooscript::Value result;
	OOJS_BEGIN_FULL_NATIVE(context)
	info = [[[OOSystemInfo alloc] initWithGalaxy:galaxy system:system] autorelease];
	OOJS_END_FULL_NATIVE
	
	if (EXPECT_NOT(info == nil))
	{
		cxx_OOJSReportWarning(context, "Could not create system info object for galaxy %u, system %i.", galaxy, system);
	}
	
	result = OOJSValueFromNativeObject(context, info);
	
	// Cache is not a root; we clear it in finalize if necessary.
	sCachedSystemInfo = ooscript::toObject(result);
	sCachedGalaxy = galaxy;
	sCachedSystem = system;
	
	return result;
	
	OOJS_PROFILE_EXIT_JSVAL
}


namespace {
static void SystemInfoFinalize(Context cx, Object obj)
{
	ooscript::Object thisObj = (obj);
	
	OOJS_PROFILE_ENTER
	
	[(id)ooscript::getPrivate(cx, obj) release];
	ooscript::setPrivate(cx, obj, nil);
	
	// Clear now-stale cache entry if appropriate.
	if (sCachedSystemInfo == thisObj)  sCachedSystemInfo = NULL;
	
	OOJS_PROFILE_EXIT_VOID
}
} // namespace


namespace {
static bool SystemInfoEnumerate(Context cx, Object obj, EnumerateOp enumOp, Value *state, PropertyId *idp)
{
	ooscript::Context context = (cx);
	
	OOJS_NATIVE_ENTER(context)
	
	SystemInfoEnumerationState *enumerator = nullptr;
	
	switch (enumOp)
	{
		case EnumerateOp::Init:
		case EnumerateOp::InitAll:	// For ES5 Object.getOwnPropertyNames(). Since we have no non-enumerable properties, this is the same as Init.
		{
			OOSystemInfo *info = (id)ooscript::getPrivate(cx, obj);
			enumerator = new SystemInfoEnumerationState{ [info cxx_allKeys] };
			*state = ooscript::privateValue(enumerator);
			
			NSUInteger count = enumerator->keys.size();
			assert(count <= INT32_MAX);
			if (idp != NULL)  *idp = ooscript::int32Id((int32_t)count);
			return YES;
		}
		
		case EnumerateOp::Next:
		{
			enumerator = static_cast<SystemInfoEnumerationState *>(ooscript::toPrivate(*state));
			if (enumerator->next < enumerator->keys.size())
			{
				ooscript::Value val = OOJSValueFromPList(context, oo::PList(enumerator->keys[enumerator->next++]));
				return ooscript::valueToId(cx, (val), idp);
			}
			// else:
			*state = ooscript::nullValue();
			// Fall through.
		}
		
		case EnumerateOp::Destroy:
		{
			if (enumerator == nullptr && ooscript::isDouble(*(state)))
			{
				enumerator = static_cast<SystemInfoEnumerationState *>(ooscript::toPrivate(*state));
			}
			delete enumerator;
			
			if (idp != NULL)  *idp = ooscript::voidId();
			return YES;
		}
	}
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool SystemInfoDeleteProperty(Context cx, Object obj, PropertyId propID, Value */*value*/)
{
	OOJS_PROFILE_ENTER	// Any exception will be converted in SystemInfoSetProperty()
	
	Value v = ooscript::undefinedValue();
	return SystemInfoSetProperty(cx, obj, propID, false, &v);
	
	OOJS_PROFILE_EXIT
}
} // namespace


namespace {
static bool SystemInfoGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	
	OOJS_NATIVE_ENTER(context)
	
	if (thisObj == sSystemInfoPrototype)
	{
		// Let SpiderMonkey handle access to the prototype object (where info will be nil).
		return YES;
	}
	
	OOSystemInfo	*info = OOJSNativeObjectOfClassFromJSObject(context, thisObj, [OOSystemInfo class]);
	// What if we're trying to access a saved witchspace systemInfo object?
	BOOL savedInterstellarInfo = ![UNIVERSE inInterstellarSpace] && [info system] == -1;
	BOOL sameGalaxy = [PLAYER currentGalaxyID] == [info galaxy];
	
	
	if (ooscript::isInt32Id(propID))
	{
		switch (ooscript::idToInt32(propID))
		{
			case kSystemInfo_coordinates:
				if (sameGalaxy && !savedInterstellarInfo)
				{
					return VectorToJSValue(context, OOGalacticCoordinatesFromInternal([info coordinates]), (value));
				}
				else
				{
					cxx_OOJSReportError(context, "Cannot read systemInfo values for %s.", (savedInterstellarInfo ? "invalid interstellar space reference" : "other galaxies"));
					return NO;
				}
				break;
				
			case kSystemInfo_internalCoordinates:
				if (sameGalaxy && !savedInterstellarInfo)
				{
					return NSPointToVectorJSValue(context, [info coordinates], (value));
				}
				else
				{
					cxx_OOJSReportError(context, "Cannot read systemInfo values for %s.", (savedInterstellarInfo ? "invalid interstellar space reference" : "other galaxies"));
					return NO;
				}
				break;
				
			case kSystemInfo_galaxyID:
				*value = (ooscript::int32Value([info galaxy]));
				return YES;
				
			case kSystemInfo_systemID:
				*value = (ooscript::int32Value([info system]));
				return YES;
				
			default:
				OOJSReportBadPropertySelector(context, thisObj, (propID), sSystemInfoPropertiesRaw);
				return NO;
		}
	}
	else if (ooscript::isStringId(propID))
	{
		std::optional<std::string> key = cxx_OOStringFromJSString(context, (ooscript::idToString(propID)));
		
		OOSystemDescriptionManager *systemManager = [UNIVERSE systemManager];
		oo::PList propValue;
		// interstellar space needs more work at this stage
		if ([info system] != -1)
		{
			propValue = [systemManager cxx_getProperty:key.value_or("") forSystem:[info system] inGalaxy:[info galaxy]];
		} else {
			propValue = [info cxx_valueForKey:key];
		}
		
		if (!propValue.isNull())
		{
			if (propValue.isNumber() || OOIsNumberLiteral(oo::DescriptionOf(propValue), YES))
			{
				// -doubleValue: an NSNumber's, or an NSString's (a number literal)
				const std::string *text = propValue.getIf<std::string>();
				const double number = (text != nullptr) ? oo::plist_get::doubleValue(oo::utf8ToUtf16(*text)) : propValue.doubleValue();
				BOOL OK = ooscript::newNumberValue(cx, number, value);
				if (!OK)
				{
					*value = ooscript::undefinedValue();
					return NO;
				}
			}
			else
			{
				*value = OOJSValueFromPList(context, propValue);	// non-null: as its own glue gave
			}
		}
	}
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool SystemInfoSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	
	if (EXPECT_NOT(thisObj == sSystemInfoPrototype))
	{
		// Let SpiderMonkey handle access to the prototype object (where info will be nil).
		return YES;
	}
	
	OOJS_NATIVE_ENTER(context);
	
	if (ooscript::isStringId(propID))
	{
		std::optional<std::string>	key = cxx_OOStringFromJSString(context, (ooscript::idToString(propID)));
		OOSystemInfo	*info = OOJSNativeObjectOfClassFromJSObject(context, thisObj, [OOSystemInfo class]);
		
		[info cxx_setValue:StringOrNull(cxx_OOStringFromJSValue(context, *(value))) forKey:key.value_or("")];	// (a nil key as "")
	}
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// distanceToSystem(sys : SystemInfo) : Number
namespace {
static bool SystemInfoDistanceToSystem(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	OOSystemInfo			*thisInfo = nil;
	ooscript::Object otherObj = NULL;
	OOSystemInfo			*otherInfo = nil;
	
	if (!JSSystemInfoGetSystemInfo(context, OOJS_THIS, &thisInfo))  return NO;
	if (oojsArgs.count() < 1 || !ooscript::valueToObject(context, (OOJS_ARGV[0]), OOJSFOBJP(&otherObj)) || !JSSystemInfoGetSystemInfo(context, otherObj, &otherInfo))
	{
		cxx_OOJSReportBadArguments(context, "SystemInfo", "distanceToSystem", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "system info");
		return NO;
	}
	
	BOOL sameGalaxy = ([thisInfo galaxy] == [otherInfo galaxy]);
	if (!sameGalaxy)
	{
		cxx_OOJSReportErrorForCaller(context, "SystemInfo", "distanceToSystem", "Cannot calculate distance for systems in other galaxies.");
		return NO;
	}
	
	NSPoint thisCoord = [thisInfo coordinates];
	NSPoint otherCoord = [otherInfo coordinates];
	
	OOJS_RETURN_DOUBLE(distanceBetweenPlanetPositions(thisCoord.x, thisCoord.y, otherCoord.x, otherCoord.y));
	
	OOJS_NATIVE_EXIT
}
} // namespace


// routeToSystem(sys : SystemInfo [, optimizedBy : String]) : Object
namespace {
static bool SystemInfoRouteToSystem(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	OOSystemInfo			*thisInfo = nil;
	ooscript::Object otherObj = NULL;
	OOSystemInfo			*otherInfo = nil;
	oo::PList				result;
	OORouteType				routeType = OPTIMIZED_BY_JUMPS;
	
	if (!JSSystemInfoGetSystemInfo(context, OOJS_THIS, &thisInfo))  return NO;
	if (oojsArgs.count() < 1 || !ooscript::valueToObject(context, (OOJS_ARGV[0]), OOJSFOBJP(&otherObj)) || !JSSystemInfoGetSystemInfo(context, otherObj, &otherInfo))
	{
		cxx_OOJSReportBadArguments(context, "SystemInfo", "routeToSystem", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "system info");
		return NO;
	}
	
	BOOL sameGalaxy = ([thisInfo galaxy] == [otherInfo galaxy]);
	if (!sameGalaxy)
	{
		cxx_OOJSReportErrorForCaller(context, "SystemInfo", "routeToSystem", "Cannot calculate route for destinations in other galaxies.");
		return NO;
	}
	
	if (oojsArgs.count() >= 2)
	{
		routeType = cxx_StringToRouteType(cxx_OOStringFromJSValue(context, OOJS_ARGV[1]).value_or(""));
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	result = [UNIVERSE cxx_routeFromSystem:[thisInfo system] toSystem:[otherInfo system] optimizedBy:routeType];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_PLIST(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// samplePrice(commodity)
namespace {
static bool SystemInfoSamplePrice(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	OOSystemInfo			*thisInfo = nil;
	
	if (!JSSystemInfoGetSystemInfo(context, OOJS_THIS, &thisInfo))  return NO;
	std::optional<std::string> commodity = cxx_OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(![[UNIVERSE commodities] cxx_goodDefined:commodity.value_or("")]))
	{
		cxx_OOJSReportBadArguments(context, "SystemInfo", "samplePrice", MIN(oojsArgs.count(), 1U), OOJS_ARGV, std::nullopt, "Unrecognised commodity type");
		return NO;
	}

	BOOL sameGalaxy = ([thisInfo galaxy] == [PLAYER galaxyNumber]);
	if (!sameGalaxy)
	{
		cxx_OOJSReportErrorForCaller(context, "SystemInfo", "samplePrice", "Cannot calculate sample price for destinations in other galaxies.");
		return NO;
	}

	OOCreditsQuantity price = [[UNIVERSE commodities] cxx_samplePriceForCommodity:commodity.value_or("") inEconomy:PropertyIntValue([thisInfo cxx_valueForKey:std::string("economy")]) withScript:ManifestString([thisInfo cxx_valueForKey:std::string("commodity_script")]) inSystem:[thisInfo system]];

	return ooscript::newNumberValue(context, price, oojsArgs.rawVp());
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool SystemInfoSetPropertyMethod(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	OOSystemInfo			*thisInfo = nil;
	
	if (!JSSystemInfoGetSystemInfo(context, OOJS_THIS, &thisInfo))  return NO;

	std::optional<std::string> property;
	oo::PList value;	// null for a JavaScript null
	oo::PList manifest;	// a string from JavaScript, or the running script's manifest identifier as read

	int32_t iValue;

	if (oojsArgs.count() < 3)
	{
		cxx_OOJSReportBadArguments(context, "SystemInfo", "setProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, std::nullopt, "setProperty(layer, property, value [,manifest])");
		return NO;
	}
	if (!ooscript::valueToInt32(context, (OOJS_ARGV[0]), &iValue))
	{
		cxx_OOJSReportBadArguments(context, "SystemInfo", "setProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, std::nullopt, "setProperty(layer, property, value [,manifest])");
		return NO;
	}
	if (iValue < 0 || iValue >= OO_SYSTEM_LAYERS)
	{
		cxx_OOJSReportBadArguments(context, "SystemInfo", "setProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, std::nullopt, "layer must be 0, 1, 2 or 3");
		return NO;
	}
	OOSystemLayer layer = (OOSystemLayer)iValue;

	property = cxx_OOStringFromJSValue(context, OOJS_ARGV[1]);
	if (!ooscript::isNull(OOJS_ARGV[2]))
	{
		value = cxx_OOJSPListFromJSValue(context, OOJS_ARGV[2]);
	}
	if (oojsArgs.count() >= 4)
	{
		manifest = StringOrNull(cxx_OOStringFromJSValue(context, OOJS_ARGV[3]));
	}
	else
	{
		manifest = [[OOJSScript currentlyRunningScript] cxx_propertyNamed:kLocalManifestProperty];
	}

	[UNIVERSE cxx_setSystemDataForGalaxy:[thisInfo galaxy] planet:[thisInfo system] key:property.value_or("") value:value fromManifest:ManifestString(manifest) forLayer:layer];

	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// filteredSystems(this : Object, predicate : Function) : Array
namespace {
static bool SystemInfoStaticFilteredSystems(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	ooscript::Object jsThis = NULL;
	
	// Get this and predicate arguments
	if (oojsArgs.count() < 2 || !OOJSValueIsFunction(context, OOJS_ARGV[1]) || !ooscript::valueToObject(context, (OOJS_ARGV[0]), OOJSFOBJP(&jsThis)))
	{
		cxx_OOJSReportBadArguments(context, "SystemInfo", "filteredSystems", oojsArgs.count(), OOJS_ARGV, std::nullopt, "this and predicate function");
		return NO;
	}
	ooscript::Value predicate = OOJS_ARGV[1];
	
	std::vector<oo::ObjCRef<OOSystemInfo *>> result;
	BOOL OK;
	@autoreleasepool
	{
		result.reserve(256);
		
		// Not OOJS_BEGIN_FULL_NATIVE() - we use the engine while paused.
		OOJSPauseTimeLimiter();
		
		// Iterate over systems.
		OK = YES;	// (the array was always made)
		OOGalaxyID galaxy = [PLAYER currentGalaxyID];
		OOSystemID system;
		for (system = 0; system <= kOOMaximumSystemID; system++)
		{
			// NOTE: this deliberately bypasses the cache, since iteration is inherently unfriendly to a single-item cache.
			OOSystemInfo *info = [[[OOSystemInfo alloc] initWithGalaxy:galaxy system:system] autorelease];
			ooscript::Value args[1] = { OOJSValueFromNativeObject(context, info) };
			
			ooscript::Value rval = ooscript::undefinedValue();
			OOJSResumeTimeLimiter();
			OK = ooscript::callFunctionValue(context, (jsThis), (predicate), 1, (args), (&rval));
			OOJSPauseTimeLimiter();
			
			if (OK)
			{
				if (ooscript::isExceptionPending(context))
				{
					ooscript::reportPendingException(context);
					OK = NO;
				}
			}
			
			if (OK)
			{
				bool boolVal;
				if (ooscript::valueToBoolean(context, (rval), &boolVal) && boolVal)
				{
					result.emplace_back(info);
				}
			}
			
			if (!OK)  break;
		}
		
		if (OK)
		{
			oo::PList::Array infos;
			infos.reserve(result.size());
			for (const auto &info : result)  infos.push_back(oo::PListObject(info.get()));
			OOJS_SET_RVAL(OOJSValueFromPList(context, oo::PList(std::move(infos))));
		}
		else
		{
			OOJS_SET_RVAL(ooscript::undefinedValue());
		}
	}
	
	OOJSResumeTimeLimiter();
	return OK;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool SystemInfoStaticSetInterstellarProperty(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	std::optional<std::string> property;
	oo::PList value;	// null for a JavaScript null
	oo::PList manifest;	// a string from JavaScript, or the running script's manifest identifier as read

	int32_t iValue;
	OOGalaxyID g;
	OOSystemID s1,s2;

	if (oojsArgs.count() < 6)
	{
		cxx_OOJSReportBadArguments(context, "SystemInfo", "setInterstellarProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, std::nullopt, "setProperty(galaxy, fromsystem, tosystem, layer, property, value [,manifest])");
		return NO;
	}
	if (!ooscript::valueToInt32(context, (OOJS_ARGV[0]), &iValue))
	{
		cxx_OOJSReportBadArguments(context, "SystemInfo", "setInterstellarProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, std::nullopt, "setProperty(galaxy, fromsystem, tosystem, layer, property, value [,manifest])");
		return NO;
	}
	if (iValue < 0 || iValue > kOOMaximumGalaxyID)
	{
		cxx_OOJSReportBadArguments(context, "SystemInfo", "setInterstellarProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, std::nullopt, "galaxy out of range");
		return NO;
	}
	else
	{
		g = (OOGalaxyID)iValue;
	}

	if (!ooscript::valueToInt32(context, (OOJS_ARGV[1]), &iValue))
	{
		cxx_OOJSReportBadArguments(context, "SystemInfo", "setInterstellarProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, std::nullopt, "setProperty(galaxy, fromsystem, tosystem, layer, property, value [,manifest])");
		return NO;
	}
	if (iValue < 0 || iValue > kOOMaximumSystemID)
	{
		cxx_OOJSReportBadArguments(context, "SystemInfo", "setInterstellarProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, std::nullopt, "fromsystem out of range");
		return NO;
	}
	else
	{
		s1 = (OOSystemID)iValue;
	}

	if (!ooscript::valueToInt32(context, (OOJS_ARGV[2]), &iValue))
	{
		cxx_OOJSReportBadArguments(context, "SystemInfo", "setInterstellarProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, std::nullopt, "setProperty(galaxy, fromsystem, tosystem, layer, property, value [,manifest])");
		return NO;
	}
	if (iValue < 0 || iValue > kOOMaximumSystemID)
	{
		cxx_OOJSReportBadArguments(context, "SystemInfo", "setInterstellarProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, std::nullopt, "tosystem out of range");
		return NO;
	}
	else
	{
		s2 = (OOSystemID)iValue;
	}

	if (!ooscript::valueToInt32(context, (OOJS_ARGV[3]), &iValue))
	{
		cxx_OOJSReportBadArguments(context, "SystemInfo", "setInterstellarProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, std::nullopt, "setProperty(galaxy, fromsystem, tosystem, layer, property, value [,manifest])");
		return NO;
	}
	if (iValue < 0 || iValue >= OO_SYSTEM_LAYERS)
	{
		cxx_OOJSReportBadArguments(context, "SystemInfo", "setInterstellarProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, std::nullopt, "layer must be 0, 1, 2 or 3");
		return NO;
	}
	OOSystemLayer layer = (OOSystemLayer)iValue;

	property = cxx_OOStringFromJSValue(context, OOJS_ARGV[4]);
	if (!ooscript::isNull(OOJS_ARGV[5]))
	{
		value = cxx_OOJSPListFromJSValue(context, OOJS_ARGV[5]);
	}
	if (oojsArgs.count() >= 7)
	{
		manifest = StringOrNull(cxx_OOStringFromJSValue(context, OOJS_ARGV[6]));
	}
	else
	{
		manifest = [[OOJSScript currentlyRunningScript] cxx_propertyNamed:kLocalManifestProperty];
	}

	std::string key = oo::str::format("interstellar: %u %u %u",g,s1,s2);
	
	[[UNIVERSE systemManager] cxx_setProperty:property.value_or("") forSystemKey:key andLayer:layer toValue:value fromManifest:ManifestString(manifest)];

	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace
