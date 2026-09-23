/*

OOJSPlanet.mm


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

#import "OOJSPlanet.h"
#import "OOJSEntity.h"
#import "OOJavaScriptEngine.h"
#import "OOJSQuaternion.h"
#import "OOJSVector.h"

#import "OOPlanetEntity.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>
#include <cstdint>

// Retargeted onto the ooscript facade (JSEngine.hpp), the way OOJSVector.mm and
// OOJSFlasher.mm do it (bead oo-sdz exemplar): stub hooks become nullptr, InitClass
// becomes ooscript::initClass, numeric conversion becomes ooscript::newNumberValue/
// valueToNumber, and `this` is renamed to `thisObj` (reserved word in Objective-C++,
// ADR-0001). The class dispatch table itself becomes an ooscript::ClassDef, and
// &sPlanetClass is what DEFINE_JS_OBJECT_GETTER, getJSClass:andPrototype: and
// OOJSRegisterObjectConverter/OOJSRegisterSubclass receive.
namespace ooscript { }
using ooscript::Context;
using ooscript::Object;
using ooscript::Value;
using ooscript::PropertyId;
using ooscript::ClassDef;
using ooscript::ClassFlag;
using ooscript::PropertyFlag;
using ooscript::PropertySpec;
using ooscript::CallArgs;

// Byte-identical facade <-> jsapi views, local to this call site (see OOJSVector.mm).


namespace {
static ooscript::Object sPlanetPrototype;
} // namespace


namespace {
static bool PlanetGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool PlanetSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace


namespace {
static ClassDef sPlanetClass =
{
	"Planet",
	ClassFlag::HasPrivate,
	
	nullptr,			// addProperty
	nullptr,			// delProperty
	PlanetGetProperty,	// getProperty
	PlanetSetProperty,	// setProperty
	nullptr,			// enumerate
	nullptr,			// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,			// resolve
	nullptr,			// convert
	OOJSObjectWrapperFinalize,		// finalize
	nullptr,			// call
	nullptr,			// construct
	nullptr,			// backend: owned by the facade backend, must start null
};
} // namespace


enum : std::uint8_t
{
	// Property IDs
	kPlanet_airColor,			// air color, read/write
	kPlanet_airColorMixRatio,	// air color mix ratio, float, read/write
	kPlanet_airDensity,		// air density, float, read/write
	kPlanet_hasAtmosphere,
	kPlanet_illuminationColor,	// illumination color, read/write
	kPlanet_isMainPlanet,		// Is [UNIVERSE planet], boolean, read-only
	kPlanet_name,				// Name of planet, string, read/write
	kPlanet_radius,				// Radius of planet in metres, read-only
	kPlanet_texture,			// Planet texture read / write
	kPlanet_orientation,		// orientation, quaternion, read/write
	kPlanet_rotationalVelocity,	// read/write
	kPlanet_terminatorThresholdVector,
};


namespace {
static PropertySpec sPlanetProperties[] =
{
	// JS name						ID							flags										getter	setter
	{ "airColor",				kPlanet_airColor,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "airColorMixRatio",			kPlanet_airColorMixRatio,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "airDensity",				kPlanet_airDensity,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "hasAtmosphere",			kPlanet_hasAtmosphere,			PropertyFlag::Permanent | PropertyFlag::Enumerate,	nullptr, nullptr },
	{ "illuminationColor",		kPlanet_illuminationColor,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "isMainPlanet",				kPlanet_isMainPlanet,				PropertyFlag::Permanent | PropertyFlag::Enumerate,	nullptr, nullptr },
	{ "name",					kPlanet_name,						PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "radius",					kPlanet_radius,					PropertyFlag::Permanent | PropertyFlag::Enumerate,	nullptr, nullptr },
	{ "rotationalVelocity",		kPlanet_rotationalVelocity,		PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "texture",					kPlanet_texture,					PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "orientation",				kPlanet_orientation,				PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },	// Not documented since it's inherited from Entity
	{ "terminatorThresholdVector",	kPlanet_terminatorThresholdVector,	PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ 0 }
};
} // namespace


// Raw jsapi mirror of sPlanetProperties for the shared error reporters that still take a
// ooscript::PropertySpec* (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static ooscript::PropertySpec sPlanetPropertiesRaw[] =
{
	// JS name						ID							flags
	{ "airColor",				kPlanet_airColor,					OOJS_PROP_READWRITE_CB },
	{ "airColorMixRatio",			kPlanet_airColorMixRatio,			OOJS_PROP_READWRITE_CB },
	{ "airDensity",				kPlanet_airDensity,				OOJS_PROP_READWRITE_CB },
	{ "hasAtmosphere",			kPlanet_hasAtmosphere,			OOJS_PROP_READONLY_CB },
	{ "illuminationColor",		kPlanet_illuminationColor,			OOJS_PROP_READWRITE_CB },
	{ "isMainPlanet",				kPlanet_isMainPlanet,				OOJS_PROP_READONLY_CB },
	{ "name",					kPlanet_name,						OOJS_PROP_READWRITE_CB },
	{ "radius",					kPlanet_radius,					OOJS_PROP_READONLY_CB },
	{ "rotationalVelocity",		kPlanet_rotationalVelocity,		OOJS_PROP_READWRITE_CB },
	{ "texture",					kPlanet_texture,					OOJS_PROP_READWRITE_CB },
	{ "orientation",				kPlanet_orientation,				OOJS_PROP_READWRITE_CB },	// Not documented since it's inherited from Entity
	{ "terminatorThresholdVector",	kPlanet_terminatorThresholdVector,	OOJS_PROP_READWRITE_CB },
	{ 0 }
};
} // namespace


namespace {
DEFINE_JS_OBJECT_GETTER(JSPlanetGetPlanetEntity, &sPlanetClass, sPlanetPrototype, OOPlanetEntity)
} // namespace


void InitOOJSPlanet(ooscript::Context context, ooscript::Object global)
{
	Object proto = ooscript::initClass((context), (global), (JSEntityPrototype()), &sPlanetClass, OOJSUnconstructableConstruct, 0, sPlanetProperties, nullptr, nullptr, nullptr);
	sPlanetPrototype = (proto);
	OOJSRegisterObjectConverter(&sPlanetClass, OOJSBasicPrivateObjectConverter);
	OOJSRegisterSubclass(&sPlanetClass, JSEntityClass());
}


@implementation OOPlanetEntity (OOJavaScriptExtensions)

- (BOOL) isVisibleToScripts
{
	OOStellarBodyType type = [self planetType];
	return type == STELLAR_TYPE_NORMAL_PLANET || type == STELLAR_TYPE_MOON;
}


- (void)getJSClass:(ooscript::ClassDef **)outClass andPrototype:(ooscript::Object *)outPrototype
{
	*outClass = &sPlanetClass;
	*outPrototype = sPlanetPrototype;
}


- (NSString *) oo_jsClassName
{
	switch ([self planetType])
	{
		case STELLAR_TYPE_NORMAL_PLANET:
			return @"Planet";
		case STELLAR_TYPE_MOON:
			return @"Moon";
		default:
			return @"Unknown";
	}
}

@end


namespace {
static bool PlanetGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = (value);
	
	OOJS_NATIVE_ENTER(context)
	
	OOPlanetEntity				*planet = nil;
	if (!JSPlanetGetPlanetEntity(context, thisObj, &planet))  return NO;
	
	switch (ooscript::idToInt32(propID))
	{
		case kPlanet_airColor:
			*value_raw = OOJSValueFromNativeObject(context, [[planet airColor] normalizedArray]);
			return YES;
			
		case kPlanet_airColorMixRatio:
			return ooscript::newNumberValue(cx, [planet airColorMixRatio], value);
			
		case kPlanet_airDensity:
			return ooscript::newNumberValue(cx, [planet airDensity], value);
			
		case kPlanet_illuminationColor:
			*value_raw = OOJSValueFromNativeObject(context, [[planet illuminationColor] normalizedArray]);
			return YES;

		case kPlanet_isMainPlanet:
			*value_raw = OOJSValueFromBOOL(planet == (id)[UNIVERSE planet]);
			return YES;
			
		case kPlanet_radius:
			return ooscript::newNumberValue(cx, [planet radius], value);
			
		case kPlanet_hasAtmosphere:
			*value_raw = OOJSValueFromBOOL([planet hasAtmosphere]);
			return YES;
			
		case kPlanet_texture:
			*value_raw = OOJSValueFromNativeObject(context, [planet textureFileName]);
			return YES;
			
		case kPlanet_name:
			*value_raw = OOJSValueFromNativeObject(context, [planet name]);
			return YES;

		case kPlanet_orientation:
			return QuaternionToJSValue(context, [planet normalOrientation], value_raw);
		
		case kPlanet_rotationalVelocity:
			return ooscript::newNumberValue(cx, [planet rotationalVelocity], value);
			
		case kPlanet_terminatorThresholdVector:
			return VectorToJSValue(context, [planet terminatorThresholdVector], value_raw);
		
		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sPlanetPropertiesRaw);
			return NO;
	}
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool PlanetSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);
	ooscript::Value *value_raw = (value);
	
	OOJS_NATIVE_ENTER(context)
	
	OOPlanetEntity			*planet = nil;
	NSString				*sValue = nil;
	Quaternion				qValue;
	Vector					vValue;
	double				dValue;
	OOColor				*colorForScript = nil;
	
	if (!JSPlanetGetPlanetEntity(context, thisObj, &planet))  return NO;
	
	switch (ooscript::idToInt32(propID))
	{
		case kPlanet_airColor:
			colorForScript = [OOColor colorWithDescription:OOJSNativeObjectFromJSValue(context, *value_raw)];
			if (colorForScript != nil || ooscript::isNull(*value_raw))
			{
				[planet setAirColor:colorForScript];
				return YES;
			}
			break;
			
		case kPlanet_airColorMixRatio:
			if (ooscript::valueToNumber(cx, *value, &dValue))
			{
				[planet setAirColorMixRatio:dValue];
				return YES;
			}
			break;
			
		case kPlanet_airDensity:
			if (ooscript::valueToNumber(cx, *value, &dValue))
			{
				[planet setAirDensity:dValue];
				return YES;
			}
			break;
			
		case kPlanet_illuminationColor:
			colorForScript = [OOColor colorWithDescription:OOJSNativeObjectFromJSValue(context, *value_raw)];
			if (colorForScript != nil || ooscript::isNull(*value_raw))
			{
				[planet setIlluminationColor:colorForScript];
				return YES;
			}
			break;

		case kPlanet_name:
			sValue = OOStringFromJSValue(context, *value_raw);
			[planet setName:sValue];
			return YES;

		case kPlanet_texture:
		{
			BOOL OK = NO;
			sValue = OOStringFromJSValue(context, *value_raw);
			
			OOJSPauseTimeLimiter();
	
			if ([planet isKindOfClass:[OOPlanetEntity class]])
			{
				if (sValue == nil)
				{
					OOJSReportWarning(context, @"Expected texture string. Value not set.");
				}
				else
				{
					OK = YES;
				}
			}
			
			if (OK)
			{
				OK = [planet setUpPlanetFromTexture:sValue];
				if (!OK)  OOJSReportWarning(context, @"Cannot find texture \"%@\". Value not set.", sValue);
			}

			OOJSResumeTimeLimiter();

			return YES;	// Even if !OK, no exception was raised.
		}
			
		case kPlanet_orientation:
			if (JSValueToQuaternion(context, *value_raw, &qValue))
			{
				quaternion_normalize(&qValue);
				[planet setOrientation:qValue];
				return YES;
			}
			break;

		case kPlanet_rotationalVelocity:
			if (ooscript::valueToNumber(cx, *value, &dValue))
			{
				[planet setRotationalVelocity:dValue];
				return YES;
			}
			break;
			
		case kPlanet_terminatorThresholdVector:
			if (JSValueToVector(context, *value_raw, &vValue))
			{
				[planet setTerminatorThresholdVector:vValue];
				return YES;
			}
			break;
			
		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sPlanetPropertiesRaw);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, (propID), sPlanetPropertiesRaw, *value_raw);
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace
