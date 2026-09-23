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

#include "ooscript/JSEngine.hpp"
#include <cstring>

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


// Helper class wrapped by JS SystemInfo objects
@interface OOSystemInfo: NSObject
{
@private
	OOGalaxyID				_galaxy;
	OOSystemID				_system;
	NSString				*_planetKey;
}

- (id) initWithGalaxy:(OOGalaxyID)galaxy system:(OOSystemID)system;

- (id) valueForKey:(NSString *)key;
- (void) setValue:(id)value forKey:(NSString *)key;

- (NSArray *) allKeys;

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
		_planetKey = [[NSString stringWithFormat:@"%u %i", galaxy, system] retain];
	}
	return self;
}


- (void) dealloc
{
	[_planetKey release];
	
	[super dealloc];
}


- (NSString *) descriptionComponents
{
	return [NSString stringWithFormat:@"galaxy %u, system %i", _galaxy, _system];
}


- (NSString *) shortDescriptionComponents
{
	return _planetKey;
}


- (NSString *) oo_jsClassName
{
	return @"SystemInfo";
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


- (id) valueForKey:(NSString *)key
{
	if ([UNIVERSE inInterstellarSpace] && _system == -1) 
	{
		return [[UNIVERSE currentSystemData] objectForKey:key];
	}
	return [UNIVERSE systemDataForGalaxy:_galaxy planet:_system key:key];
}


- (void) setValue:(id)value forKey:(NSString *)key
{
	NSString *manifest = [[OOJSScript currentlyRunningScript] propertyNamed:kLocalManifestProperty];

	[UNIVERSE setSystemDataForGalaxy:_galaxy planet:_system key:key value:value  fromManifest:manifest forLayer:OO_LAYER_OXP_DYNAMIC];
}


- (NSArray *) allKeys
{
	if ([UNIVERSE inInterstellarSpace] && _system == -1) 
	{
		return [[UNIVERSE currentSystemData] allKeys];
	}
	return [UNIVERSE systemDataKeysForGalaxy:_galaxy planet:_system];
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
	NSAssert([PLAYER currentGalaxyID] == _galaxy, @"Attempt to use -[OOSystemInfo systemSeed] from a different galaxy.");
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
		OOJSReportWarning(context, @"Could not create system info object for galaxy %u, system %i.", galaxy, system);
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
	
	NSEnumerator *enumerator = nil;
	
	switch (enumOp)
	{
		case EnumerateOp::Init:
		case EnumerateOp::InitAll:	// For ES5 Object.getOwnPropertyNames(). Since we have no non-enumerable properties, this is the same as Init.
		{
			OOSystemInfo *info = (id)ooscript::getPrivate(cx, obj);
			NSArray *keys = [info allKeys];
			enumerator = [[keys objectEnumerator] retain];
			*state = ooscript::privateValue(enumerator);
			
			NSUInteger count = [keys count];
			assert(count <= INT32_MAX);
			if (idp != NULL)  *idp = ooscript::int32Id((int32_t)count);
			return YES;
		}
		
		case EnumerateOp::Next:
		{
			enumerator = static_cast<id>(ooscript::toPrivate(*state));
			NSString *next = [enumerator nextObject];
			if (next != nil)
			{
				ooscript::Value val = [next oo_jsValueInContext:context];
				return ooscript::valueToId(cx, (val), idp);
			}
			// else:
			*state = ooscript::nullValue();
			// Fall through.
		}
		
		case EnumerateOp::Destroy:
		{
			if (enumerator == nil && ooscript::isDouble(*(state)))
			{
				enumerator = static_cast<id>(ooscript::toPrivate(*state));
			}
			[enumerator release];
			
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
					OOJSReportError(context, @"Cannot read systemInfo values for %@.", savedInterstellarInfo ? @"invalid interstellar space reference" : @"other galaxies");
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
					OOJSReportError(context, @"Cannot read systemInfo values for %@.", savedInterstellarInfo ? @"invalid interstellar space reference" : @"other galaxies");
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
		NSString *key = OOStringFromJSString(context, (ooscript::idToString(propID)));
		
		OOSystemDescriptionManager *systemManager = [UNIVERSE systemManager];
		id propValue = nil;
		// interstellar space needs more work at this stage
		if ([info system] != -1)
		{
			propValue = [systemManager getProperty:key forSystem:[info system] inGalaxy:[info galaxy]];
		} else {
			propValue = [info valueForKey:key];
		}
		
		if (propValue != nil)
		{
			if ([propValue isKindOfClass:[NSNumber class]] || OOIsNumberLiteral([propValue description], YES))
			{
				BOOL OK = ooscript::newNumberValue(cx, [propValue doubleValue], value);
				if (!OK)
				{
					*value = ooscript::undefinedValue();
					return NO;
				}
			}
			else
			{
				*value = ([propValue oo_jsValueInContext:context]);
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
		NSString		*key = OOStringFromJSString(context, (ooscript::idToString(propID)));
		OOSystemInfo	*info = OOJSNativeObjectOfClassFromJSObject(context, thisObj, [OOSystemInfo class]);
		
		[info setValue:OOStringFromJSValue(context, *(value)) forKey:key];
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
		OOJSReportBadArguments(context, @"SystemInfo", @"distanceToSystem", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"system info");
		return NO;
	}
	
	BOOL sameGalaxy = ([thisInfo galaxy] == [otherInfo galaxy]);
	if (!sameGalaxy)
	{
		OOJSReportErrorForCaller(context, @"SystemInfo", @"distanceToSystem", @"Cannot calculate distance for systems in other galaxies.");
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
	NSDictionary			*result = nil;
	OORouteType				routeType = OPTIMIZED_BY_JUMPS;
	
	if (!JSSystemInfoGetSystemInfo(context, OOJS_THIS, &thisInfo))  return NO;
	if (oojsArgs.count() < 1 || !ooscript::valueToObject(context, (OOJS_ARGV[0]), OOJSFOBJP(&otherObj)) || !JSSystemInfoGetSystemInfo(context, otherObj, &otherInfo))
	{
		OOJSReportBadArguments(context, @"SystemInfo", @"routeToSystem", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"system info");
		return NO;
	}
	
	BOOL sameGalaxy = ([thisInfo galaxy] == [otherInfo galaxy]);
	if (!sameGalaxy)
	{
		OOJSReportErrorForCaller(context, @"SystemInfo", @"routeToSystem", @"Cannot calculate route for destinations in other galaxies.");
		return NO;
	}
	
	if (oojsArgs.count() >= 2)
	{
		routeType = StringToRouteType(OOStringFromJSValue(context, OOJS_ARGV[1]));
	}
	
	OOJS_BEGIN_FULL_NATIVE(context)
	result = [UNIVERSE routeFromSystem:[thisInfo system] toSystem:[otherInfo system] optimizedBy:routeType];
	OOJS_END_FULL_NATIVE
	
	OOJS_RETURN_OBJECT(result);
	
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
	OOCommodityType commodity = OOStringFromJSValue(context, OOJS_ARGV[0]);
	if (EXPECT_NOT(![[UNIVERSE commodities] goodDefined:commodity]))
	{
		OOJSReportBadArguments(context, @"SystemInfo", @"samplePrice", MIN(oojsArgs.count(), 1U), OOJS_ARGV, NULL, @"Unrecognised commodity type");
		return NO;
	}

	BOOL sameGalaxy = ([thisInfo galaxy] == [PLAYER galaxyNumber]);
	if (!sameGalaxy)
	{
		OOJSReportErrorForCaller(context, @"SystemInfo", @"samplePrice", @"Cannot calculate sample price for destinations in other galaxies.");
		return NO;
	}

	OOCreditsQuantity price = [[UNIVERSE commodities] samplePriceForCommodity:commodity inEconomy:[[thisInfo valueForKey:@"economy"] intValue] withScript:[thisInfo valueForKey:@"commodity_script"] inSystem:[thisInfo system]];

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

	NSString *property = nil;
	id value = nil;
	NSString *manifest = nil;

	int32_t iValue;

	if (oojsArgs.count() < 3)
	{
		OOJSReportBadArguments(context, @"SystemInfo", @"setProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, NULL, @"setProperty(layer, property, value [,manifest])");
		return NO;
	}
	if (!ooscript::valueToInt32(context, (OOJS_ARGV[0]), &iValue))
	{
		OOJSReportBadArguments(context, @"SystemInfo", @"setProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, NULL, @"setProperty(layer, property, value [,manifest])");
		return NO;
	}
	if (iValue < 0 || iValue >= OO_SYSTEM_LAYERS)
	{
		OOJSReportBadArguments(context, @"SystemInfo", @"setProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, NULL, @"layer must be 0, 1, 2 or 3");
		return NO;
	}
	OOSystemLayer layer = (OOSystemLayer)iValue;

	property = OOStringFromJSValue(context, OOJS_ARGV[1]);
	if (!ooscript::isNull(OOJS_ARGV[2]))
	{
		value = OOJSNativeObjectFromJSValue(context, OOJS_ARGV[2]);
	}
	if (oojsArgs.count() >= 4)
	{
		manifest = OOStringFromJSValue(context, OOJS_ARGV[3]);
	}
	else
	{
		manifest = [[OOJSScript currentlyRunningScript] propertyNamed:kLocalManifestProperty];
	}

	[UNIVERSE setSystemDataForGalaxy:[thisInfo galaxy] planet:[thisInfo system] key:property value:value fromManifest:manifest forLayer:layer];

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
		OOJSReportBadArguments(context, @"SystemInfo", @"filteredSystems", oojsArgs.count(), OOJS_ARGV, nil, @"this and predicate function");
		return NO;
	}
	ooscript::Value predicate = OOJS_ARGV[1];
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:256];
	
	// Not OOJS_BEGIN_FULL_NATIVE() - we use the engine while paused.
	OOJSPauseTimeLimiter();
	
	// Iterate over systems.
	BOOL OK = result != nil;
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
				[result addObject:info];
			}
		}
		
		if (!OK)  break;
	}
	
	if (OK)
	{
		OOJS_SET_RVAL([result oo_jsValueInContext:context]);
	}
	else
	{
		OOJS_SET_RVAL(ooscript::undefinedValue());
	}

	[pool release];
	
	OOJSResumeTimeLimiter();
	return OK;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool SystemInfoStaticSetInterstellarProperty(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	NSString *property = nil;
	id value = nil;
	NSString *manifest = nil;

	int32_t iValue;
	OOGalaxyID g;
	OOSystemID s1,s2;

	if (oojsArgs.count() < 6)
	{
		OOJSReportBadArguments(context, @"SystemInfo", @"setInterstellarProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, NULL, @"setProperty(galaxy, fromsystem, tosystem, layer, property, value [,manifest])");
		return NO;
	}
	if (!ooscript::valueToInt32(context, (OOJS_ARGV[0]), &iValue))
	{
		OOJSReportBadArguments(context, @"SystemInfo", @"setInterstellarProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, NULL, @"setProperty(galaxy, fromsystem, tosystem, layer, property, value [,manifest])");
		return NO;
	}
	if (iValue < 0 || iValue > kOOMaximumGalaxyID)
	{
		OOJSReportBadArguments(context, @"SystemInfo", @"setInterstellarProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, NULL, @"galaxy out of range");
		return NO;
	}
	else
	{
		g = (OOGalaxyID)iValue;
	}

	if (!ooscript::valueToInt32(context, (OOJS_ARGV[1]), &iValue))
	{
		OOJSReportBadArguments(context, @"SystemInfo", @"setInterstellarProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, NULL, @"setProperty(galaxy, fromsystem, tosystem, layer, property, value [,manifest])");
		return NO;
	}
	if (iValue < 0 || iValue > kOOMaximumSystemID)
	{
		OOJSReportBadArguments(context, @"SystemInfo", @"setInterstellarProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, NULL, @"fromsystem out of range");
		return NO;
	}
	else
	{
		s1 = (OOSystemID)iValue;
	}

	if (!ooscript::valueToInt32(context, (OOJS_ARGV[2]), &iValue))
	{
		OOJSReportBadArguments(context, @"SystemInfo", @"setInterstellarProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, NULL, @"setProperty(galaxy, fromsystem, tosystem, layer, property, value [,manifest])");
		return NO;
	}
	if (iValue < 0 || iValue > kOOMaximumSystemID)
	{
		OOJSReportBadArguments(context, @"SystemInfo", @"setInterstellarProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, NULL, @"tosystem out of range");
		return NO;
	}
	else
	{
		s2 = (OOSystemID)iValue;
	}

	if (!ooscript::valueToInt32(context, (OOJS_ARGV[3]), &iValue))
	{
		OOJSReportBadArguments(context, @"SystemInfo", @"setInterstellarProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, NULL, @"setProperty(galaxy, fromsystem, tosystem, layer, property, value [,manifest])");
		return NO;
	}
	if (iValue < 0 || iValue >= OO_SYSTEM_LAYERS)
	{
		OOJSReportBadArguments(context, @"SystemInfo", @"setInterstellarProperty", MIN(oojsArgs.count(), 3U), OOJS_ARGV, NULL, @"layer must be 0, 1, 2 or 3");
		return NO;
	}
	OOSystemLayer layer = (OOSystemLayer)iValue;

	property = OOStringFromJSValue(context, OOJS_ARGV[4]);
	if (!ooscript::isNull(OOJS_ARGV[5]))
	{
		value = OOJSNativeObjectFromJSValue(context, OOJS_ARGV[5]);
	}
	if (oojsArgs.count() >= 7)
	{
		manifest = OOStringFromJSValue(context, OOJS_ARGV[6]);
	}
	else
	{
		manifest = [[OOJSScript currentlyRunningScript] propertyNamed:kLocalManifestProperty];
	}

	NSString *key = [NSString stringWithFormat:@"interstellar: %u %u %u",g,s1,s2];
	
	[[UNIVERSE systemManager] setProperty:property forSystemKey:key andLayer:layer toValue:value fromManifest:manifest];

	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace
