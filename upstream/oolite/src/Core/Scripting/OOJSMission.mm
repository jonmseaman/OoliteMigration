/*

OOJSMission.mm


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

#import "OOJSMission.h"
#import "OOJavaScriptEngine.h"
#import "OOJSScript.h"
#import "OOConstToJSString.h"
#import "OOJSVector.h"

#import "OOJSPlayer.h"
#import "PlayerEntityScriptMethods.h"
#import "OOStringExpander.h"
#import "OOCollectionExtractors.h"
#import "OOMusicController.h"
#import "GuiDisplayGen.h"
#import "OODebugStandards.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar): the class dispatch table becomes a static ooscript::ClassDef
	(the stub hooks are nullptr), the class-creation calls become ooscript::initClass and
	ooscript::defineObject, and the directly spelled numeric/object/property calls become their
	ooscript:: equivalents (valueToObject, newNumberValue, getProperty, setProperty,
	deleteProperty, valueToNumber, valueToBoolean, valueToInt32). `this` is renamed to `thisObj`
	because it is a reserved word once this file compiles as Objective-C++ (ADR-0001). The class
	hooks (getProperty, setProperty) and every ooscript::FunctionSpec entry take the façade's
	Context/Object/PropertyId/Value/CallArgs signature directly.
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


namespace {
static bool MissionGetProperty(Context cx, Object thisObj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool MissionSetProperty(Context cx, Object thisObj, PropertyId propID, bool strict, Value *value);
} // namespace

namespace {
static bool MissionMarkSystem(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool MissionUnmarkSystem(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool MissionAddMessageText(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool MissionSetInstructions(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool MissionSetInstructionsKey(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool MissionRunScreen(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool MissionRunShipLibrary(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace

namespace {
static bool MissionSetInstructionsInternal(ooscript::Context context, ooscript::CallArgs &oojsArgs, BOOL isKey);
} // namespace

namespace {
constexpr PropertyFlag kMissionObjectFlags = PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly;
} // namespace

//  Mission screen  callback varibables
namespace {
ooscript::Value			sCallbackFunction;
} // namespace
namespace {
ooscript::Value			sCallbackThis;
} // namespace
namespace {
OOJSScript		*sCallbackScript = nil;
} // namespace

namespace {
ooscript::Object sMissionObject;
} // namespace

namespace {
static ClassDef sMissionClass =
{
	"Mission",
	ClassFlag::None,

	nullptr,			// addProperty (engine default: PropertyStub)
	nullptr,			// delProperty (engine default: PropertyStub)
	MissionGetProperty,	// getProperty
	MissionSetProperty,	// setProperty
	nullptr,			// enumerate (engine default: EnumerateStub)
	nullptr,			// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,			// resolve (engine default: ResolveStub)
	nullptr,			// convert (engine default: ConvertStub)
	nullptr,			// finalize (engine default: FinalizeStub)
	nullptr,			// call
	nullptr,			// construct
	nullptr,			// backend: owned by the façade backend, must start null
};
} // namespace


namespace {
enum : std::uint8_t
{
	kMission_markedSystems,
	kMission_screenID,
	kMission_exitScreen
};
} // namespace


namespace {
static PropertySpec sMissionProperties[] = 
{
	// JS name					ID								flags
	{ "markedSystems", kMission_markedSystems, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "screenID", kMission_screenID, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "exitScreen", kMission_exitScreen, PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared, nullptr, nullptr },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sMissionMethods[] =
{
	// JS name					Function					min args	flags
	{ "addMessageText",			MissionAddMessageText,		1,			0 },
	{ "markSystem",				MissionMarkSystem,			1,			0 },
	{ "runScreen",				MissionRunScreen,			1,			0 }, // the callback function is optional!
	{ "setInstructions",		MissionSetInstructions,	1,			0 },
	{ "setInstructionsKey",		MissionSetInstructionsKey,	1,			0 },
	{ "unmarkSystem",			MissionUnmarkSystem,		1,			0 },
	{ "runShipLibrary",			MissionRunShipLibrary,		0,			0 },
	{ 0 }
};
} // namespace


void InitOOJSMission(ooscript::Context context, ooscript::Object global)
{
	sCallbackFunction = ooscript::nullValue();
	sCallbackThis = ooscript::nullValue();
	
	Object missionPrototype = ooscript::initClass((context), (global), nullptr, &sMissionClass, OOJSUnconstructableConstruct, 0, sMissionProperties, sMissionMethods, nullptr, nullptr);
	sMissionObject = (ooscript::defineObject((context), (global), "mission", &sMissionClass, missionPrototype, kMissionObjectFlags));
	
	// Ensure JS objects are rooted.
	OOJSAddGCValueRoot(context, &sCallbackFunction, "Pending mission callback function");
	OOJSAddGCValueRoot(context, &sCallbackThis, "Pending mission callback this");
}


void MissionRunCallback()
{
	// don't do anything if we don't have a function.
	if (ooscript::isNull(sCallbackFunction) || ooscript::isUndefined(sCallbackFunction))  return;
	
	ooscript::Value				argval = ooscript::undefinedValue();
	ooscript::Value				argval2 = ooscript::undefinedValue();
	ooscript::Value				rval = ooscript::undefinedValue();
	PlayerEntity		*player = OOPlayerForScripting();
	OOJavaScriptEngine	*engine  = [OOJavaScriptEngine sharedEngine];
	ooscript::Context context = OOJSAcquireContext();
	
	/*	Create temporarily-rooted local copies of sCallbackFunction and
		sCallbackThis, then clear the statics. This must be done in advance
		since the callback might call runScreen() and clobber the statics.
	*/
	ooscript::Value				cbFunction = ooscript::undefinedValue();
	ooscript::Object cbThis = NULL;
	OOJSScript			*cbScript = nil;
	
	OOJSAddGCValueRoot(context, &cbFunction, "Mission callback function");
	OOJSAddGCObjectRoot(context, &cbThis, "Mission callback this");
	cbFunction = sCallbackFunction;
	cbScript = sCallbackScript;
	ooscript::valueToObject((context), (sCallbackThis), &cbThis);
	
	sCallbackScript = nil;
	sCallbackFunction = ooscript::nullValue();
	sCallbackThis = ooscript::nullValue();
	
	ooscript::Value args[2];
	argval = OOJSValueFromNativeObject(context, [player missionChoice_string]);
	argval2 = OOJSValueFromNativeObject(context, [player missionKeyPress_string]);
	args[0] = argval;
	args[1] = argval2;

	// now reset the mission choice silently, before calling the callback script.
	[player setMissionChoice:nil keyPress:@"" withEvent:NO];
	
	// Call the callback.
	@try
	{
		[OOJSScript pushScript:cbScript];
		[engine callJSFunction:cbFunction
					 forObject:cbThis
						  argc:2
						  argv:args
						result:&rval];
	}
	@catch (NSException *exception)
	{
		// Squash any exception, allow cleanup to happen and so forth.
		OOLog(kOOLogException, @"Ignoring exception %@:%@ during handling of mission screen completion callback.", [exception name], [exception reason]);
	}
	[OOJSScript popScript:cbScript];
	
	// Manage that memory.
	[cbScript release];
	ooscript::removeValueRoot((context), (&cbFunction));
	ooscript::removeObjectRoot((context), &cbThis);
	
	OOJSRelinquishContext(context);
}


namespace {
static bool MissionGetProperty(Context cx, Object thisObj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	
	OOJS_NATIVE_ENTER(context)

	id result = nil;
	PlayerEntity		*player = OOPlayerForScripting();

	switch (ooscript::idToInt32(propID))
	{
		case kMission_markedSystems:
			result = [player getMissionDestinations];
			if (result == nil)  result = [NSDictionary dictionary];
			result = [result allValues];
			break;

		case kMission_screenID:
			result = [player missionScreenID];
			break;

		case kMission_exitScreen:
			*value = OOJSValueFromGUIScreenID(context, [player missionExitScreen]);
			return YES;

		default:
			OOJSReportBadPropertySelector(context, thisObj, propID, sMissionProperties);
			return NO;
	}

	*value = OOJSValueFromNativeObject(context, result);
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool MissionSetProperty(Context cx, Object thisObj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;
	
	ooscript::Context context = (cx);
	
	OOJS_NATIVE_ENTER(context)
	
	OOGUIScreenID exitScreen;
	PlayerEntity		*player = OOPlayerForScripting();

	switch (ooscript::idToInt32(propID))
	{
		case kMission_exitScreen:
			exitScreen = OOGUIScreenIDFromJSValue(context, *value);
			[player setMissionExitScreen:exitScreen];
			return YES;
	
		default:
			OOJSReportBadPropertySelector(context, thisObj, propID, sMissionProperties);
	}
	
	OOJSReportBadPropertyValue(context, thisObj, propID, sMissionProperties, *value);
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace



// *** Methods ***

// markSystem(integer+)
namespace {
static bool MissionMarkSystem(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	unsigned i;
	int dest;

	// two pass. Once to validate, once to apply if they validate
	for (i=0;i<oojsArgs.count();i++)
	{
		if (!ooscript::valueToInt32(context, (OOJS_ARGV[i]), &dest)) 
		{
			ooscript::clearPendingException(context); // or valueToInt32 exception crashes JS engine
			if (!ooscript::isObjectOrNull(OOJS_ARGV[i]))
			{
				OOJSReportBadArguments(context, @"Mission", @"markSystem", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"numbers or objects");
				return NO;
			}
		}
	}

	for (i=0;i<oojsArgs.count();i++)
	{
		if (ooscript::valueToInt32(context, (OOJS_ARGV[i]), &dest)) 
		{
			OOStandardsDeprecated(@"Use of numbers for mission.markSystem is deprecated");
			if (!OOEnforceStandards())
			{
				[player addMissionDestinationMarker:[player defaultMarker:dest]];
			}
		}
		else // must be object, from above
		{
			ooscript::clearPendingException(context); // or valueToInt32 exception crashes JS engine
			NSDictionary *marker = OOJSNativeObjectFromJSObject(context, ooscript::toObject(OOJS_ARGV[i]));
			OOSystemID system = [marker oo_intForKey:@"system" defaultValue:-1];
			if (system >= 0)
			{
				[player addMissionDestinationMarker:marker];
			}
		}
	}
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// unmarkSystem(integer+)
namespace {
static bool MissionUnmarkSystem(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	unsigned i;
	int dest;

	// two pass. Once to validate, once to apply if they validate
	for (i=0;i<oojsArgs.count();i++)
	{
		if (!ooscript::valueToInt32(context, (OOJS_ARGV[i]), &dest)) 
		{
			ooscript::clearPendingException(context); // or valueToInt32 exception crashes JS engine
			if (!ooscript::isObjectOrNull(OOJS_ARGV[i]))
			{
				OOJSReportBadArguments(context, @"Mission", @"unmarkSystem", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"numbers or objects");
				return NO;
			}
		}
	}

	BOOL result = YES;
	for (i=0;i<oojsArgs.count();i++)
	{
		if (ooscript::valueToInt32(context, (OOJS_ARGV[i]), &dest)) 
		{
			OOStandardsDeprecated(@"Use of numbers for mission.unmarkSystem is deprecated");
			if (!OOEnforceStandards())
			{
				if (![player removeMissionDestinationMarker:[player defaultMarker:dest]]) {
					result = NO;
				}
			}
		}
		else // must be object, from above
		{
			ooscript::clearPendingException(context); // or valueToInt32 exception crashes JS engine
			NSDictionary *marker = OOJSNativeObjectFromJSObject(context, ooscript::toObject(OOJS_ARGV[i]));
			OOSystemID system = [marker oo_intForKey:@"system" defaultValue:-1];
			if (system >= 0)
			{
				if (![player removeMissionDestinationMarker:marker]) {
					result = NO;
				}
			}
		}
	}
	
	OOJS_RETURN_BOOL(result);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// addMessageText(text : String)
namespace {
static bool MissionAddMessageText(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	NSString			*text = nil;
	
	if (EXPECT_NOT(oojsArgs.count() == 0))
	{
		OOJS_RETURN_VOID;
	}
	
	// Found "FIXME: warning if no mission screen running.",,,
	// However: used routinely by the Constrictor mission in F7, without mission screens.
	text = OOStringFromJSValue(context, OOJS_ARGV[0]);
	[player addLiteralMissionText:text];
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// setInstructionsKey(instructionsKey: String [, missionKey : String])
namespace {
static bool MissionSetInstructionsKey(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	return MissionSetInstructionsInternal(context, oojsArgs, YES);
}
} // namespace


// setInstructions(instructions: String [, missionKey : String])
namespace {
static bool MissionSetInstructions(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	return MissionSetInstructionsInternal(context, oojsArgs, NO);
}
} // namespace


namespace {
static bool MissionSetInstructionsInternal(ooscript::Context context, ooscript::CallArgs &oojsArgs, BOOL isKey)
{
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	NSString			*text = nil;
	NSArray				*texts = nil;
	NSString			*missionKey = nil;
	
	if (EXPECT_NOT(oojsArgs.count() == 0))
	{
		OOJSReportWarning(context, @"Usage error: mission.%@() called with no arguments. Treating as Mission.%@(null). This call may fail in a future version of Oolite.", isKey ? @"setInstructionsKey" : @"setInstructions", isKey ? @"setInstructionsKey" : @"setInstructions");
	}
	else if (EXPECT_NOT(ooscript::isUndefined(OOJS_ARGV[0])))
	{
		OOJSReportBadArguments(context, @"Mission", isKey ? @"setInstructionsKey" : @"setInstructions", 1, OOJS_ARGV, NULL, @"string or null");
		return NO;
	}
	else if (!ooscript::isNull(OOJS_ARGV[0]) && ooscript::isObjectOrNull(OOJS_ARGV[0]))
	{
		texts = OOJSNativeObjectFromJSValue(context, OOJS_ARGV[0]);
	}
	else
	{
		text = OOStringFromJSValue(context, OOJS_ARGV[0]);
	}
	
	if (oojsArgs.count() > 1)
	{
		missionKey = OOStringFromJSValueEvenIfNull(context, OOJS_ARGV[1]);
	}
	else
	{
		missionKey = [[OOJSScript currentlyRunningScript] name];
	}
	
	if (text != nil)
	{
		if (isKey)
		{
			[player setMissionDescription:text forMission:missionKey];
		}
		else
		{
			[player setMissionInstructions:text forMission:missionKey];
		}
	}
	else if (texts != nil && !isKey)
	{
		[player setMissionInstructionsList:texts forMission:missionKey];
	}
	else
	{
		[player clearMissionDescriptionForMission:missionKey];
	}
	
	OOJS_RETURN_VOID;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static NSDictionary *GetParameterDictionary(ooscript::Context context, ooscript::Object object, const char *key)
{
	ooscript::Value value = ooscript::nullValue();
	if (ooscript::getProperty((context), (object), key, (&value)))
	{
		if (ooscript::isObjectOrNull(value))
		{
			return OOJSNativeObjectFromJSObject(context, ooscript::toObject(value));
		}
	}
	return nil;
}
} // namespace


namespace {
static NSString *GetParameterString(ooscript::Context context, ooscript::Object object, const char *key)
{
	ooscript::Value value = ooscript::nullValue();
	if (ooscript::getProperty((context), (object), key, (&value)))
	{
		return OOStringFromJSValue(context, value);
	}
	return nil;
}
} // namespace


namespace {
static NSDictionary *GetParameterImageDescriptor(ooscript::Context context, ooscript::Object object, const char *key)
{
	ooscript::Value value = ooscript::nullValue();
	if (ooscript::getProperty((context), (object), key, (&value)))
	{
		return [[UNIVERSE gui] textureDescriptorFromJSValue:value inContext:context callerDescription:@"mission.runScreen()"];
	}
	else
	{
		return nil;
	}
}
} // namespace


// runScreen(params: dict, callBack:function) - if the callback function is null, emulate the old style runMissionScreen
namespace {
static bool MissionRunScreen(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity		*player = OOPlayerForScripting();
	ooscript::Value				function = ooscript::nullValue();
	ooscript::Value				value = ooscript::nullValue();
	ooscript::Object params = NULL;
	
	// No mission screens during intro.
	if ([player status] == STATUS_START_GAME)
	{
		// (though no JS should be loaded at this stage, so this
		// check may be obsolete - CIM)
		OOJS_RETURN_BOOL(NO);
	}
	
	// Validate arguments.
	if (oojsArgs.count() < 1 || !ooscript::valueToObject(context, (OOJS_ARGV[0]), &params))
	{
		OOJSReportBadArguments(context, @"mission", @"runScreen", MIN(oojsArgs.count(), 1U), &OOJS_ARGV[0], nil, @"parameter object");
		return NO;
	}
	
	if (oojsArgs.count() > 1)  function = OOJS_ARGV[1];
	if (!ooscript::isNull(function) && !OOJSValueIsFunction(context, function))
	{
		OOJSReportBadArguments(context, @"mission", @"runScreen", 1, &OOJS_ARGV[1], nil, @"function");
		return NO;
	}
	
	// Not OOJS_BEGIN_FULL_NATIVE() - we use JSAPI while paused.
	OOJSPauseTimeLimiter();
	
	if (!ooscript::isNull(function))
	{

		/* CIM 30/12/12: This following line causes problems in certain
		 * cases, but has to be kept for backward
		 * compatibility. Documenting the third argument of
		 * mission.runScreen will at least help people get around it in
		 * multi-world-script mission screens. (Though, since no-one has
		 * complained yet, perhaps I'm the only one who uses them?) */

		sCallbackScript = [[[OOJSScript currentlyRunningScript] weakRefUnderlyingObject] retain];
		if (oojsArgs.count() > 2)
		{
			sCallbackThis = OOJS_ARGV[2];
		}
		else
		{
			sCallbackThis = OOJSValueFromNativeObject(context, sCallbackScript);
		}
	}
	
	// Apply settings.
	if (ooscript::getProperty(context, (params), "title", (&value)) && !ooscript::isUndefined(value))
	{
		[player setMissionTitle:OOStringFromJSValue(context, value)];
	}
	else
	{
		NSString *titleKey = GetParameterString(context, params, "titleKey");
		if (titleKey != nil)
		{
			NSString *message = [[UNIVERSE missiontext] oo_stringForKey:titleKey];
			if (message != nil)
			{
				[player setMissionTitle:OOExpand(message)];
			}
			else
			{
				OOJSReportWarning(context, @"Mission.runScreen: titleKey '%@' has no entry in missiontext.plist.", titleKey);
			}
		}
	}
	
	[[OOMusicController	sharedController] setMissionMusic:GetParameterString(context, params, "music")];
	[player setMissionOverlayDescriptor:GetParameterImageDescriptor(context, params, "overlay")];
	[player setMissionBackgroundDescriptor:GetParameterImageDescriptor(context, params, "background")];
	[player setMissionBackgroundSpecial:GetParameterString(context, params, "backgroundSpecial")];

	if (ooscript::getProperty(context, (params), "customChartZoom", (&value)) && !ooscript::isUndefined(value))
	{
		double zoom;
		if (ooscript::valueToNumber(context, (value), &zoom))
		{
			if (zoom >= 1 && zoom <= CHART_MAX_ZOOM)
			{
				[player setCustomChartZoom:zoom];
			}
			else 
			{
				OOJSReportWarning(context, @"Mission.runScreen: invalid customChartZoom value specified.");
				[player setCustomChartZoom:1];
			}
		}
	}
	if (ooscript::getProperty(context, (params), "customChartCentre", (&value)) && !ooscript::isUndefined(value))
	{
		Vector vValue;
		if (JSValueToVector(context, value, &vValue))
		{
			NSPoint coords = { vValue.x, vValue.y };
			[player setCustomChartCentre:coords];
		}
		else 
		{
			[player setCustomChartCentre:[player galaxy_coordinates]];
			OOJSReportWarning(context, @"Mission.runScreen: invalid value for customChartCentre. Must be valid vector. Defaulting to current location.");
		}
	}
	if (ooscript::getProperty(context, (params), "customChartCentreInLY", (&value)) && !ooscript::isUndefined(value))
	{
		Vector vValue;
		if (JSValueToVector(context, value, &vValue))
		{
			NSPoint coords = OOInternalCoordinatesFromGalactic(vValue);
			[player setCustomChartCentre:coords];
		}
		else 
		{
			[player setCustomChartCentre:[player galaxy_coordinates]];
			OOJSReportWarning(context, @"Mission.runScreen: invalid value for customChartCentreInLY. Must be valid vector. Defaulting to current location.");
		}
	}

	[UNIVERSE removeDemoShips];	// remove any demoship or miniature planet that may be remaining from previous screens
	
	ShipEntity *demoShip = nil;
	if (ooscript::getProperty(context, (params), "model", (&value)) && !ooscript::isUndefined(value))
	{
		if ([player status] == STATUS_IN_FLIGHT && ooscript::isString(value))
		{
			OOJSReportWarning(context, @"Mission.runScreen: model cannot be displayed while in flight.");
		}
		else
		{
			NSString *role = OOStringFromJSValue(context, value);
			
			bool spinning = true;
			if (ooscript::getProperty(context, (params), "spinModel", (&value)) && !ooscript::isUndefined(value))
			{
				ooscript::valueToBoolean(context, (value), &spinning);
			}
			
		//	[player showShipModel:OOStringFromJSValue(context, value)];
			demoShip = [UNIVERSE makeDemoShipWithRole:role spinning:(bool)spinning];
		}
	}
	if (demoShip != nil)
	{
		if (ooscript::getProperty(context, (params), "modelPersonality", (&value)) && !ooscript::isUndefined(value))
		{
			int32_t personality = 0;
			ooscript::valueToInt32(context, (value), &personality);
			[demoShip setEntityPersonalityInt:personality];
		}
		ooscript::Value demoShipVal = [demoShip oo_jsValueInContext:context];
		ooscript::setProperty(context, (sMissionObject), "displayModel", (&demoShipVal));
	}
	else
	{
		ooscript::deleteProperty(context, (sMissionObject), "displayModel");
	}

	bool allowInterrupt = false;
	// force the allowInterrupt to be YES while in flight
	if ([player status] == STATUS_IN_FLIGHT) 
	{
		allowInterrupt = true;
	} 
	else
	{
		if (ooscript::getProperty(context, (params), "allowInterrupt", (&value)) && !ooscript::isUndefined(value))
		{
			ooscript::valueToBoolean(context, (value), &allowInterrupt);
		}
	}

	if (ooscript::getProperty(context, (params), "exitScreen", (&value)) && !ooscript::isUndefined(value))
	{
		[player setMissionExitScreen:OOGUIScreenIDFromJSValue(context, value)];
	}
	else
	{
		[player setMissionExitScreen:GUI_SCREEN_STATUS];
	}

	if (ooscript::getProperty(context, (params), "screenID", (&value)) && !ooscript::isUndefined(value))
	{
		[player setMissionScreenID:OOStringFromJSValue(context, value)];
	}
	else
	{
		[player clearMissionScreenID];
	}

	[player clearExtraMissionKeys];
	if (ooscript::getProperty(context, (params), "registerKeys", (&value)) && !ooscript::isUndefined(value))
	{
		[player setExtraMissionKeys:GetParameterDictionary(context, params, "registerKeys")];
	}

	bool textEntry = false;
	if (ooscript::getProperty(context, (params), "textEntry", (&value)) && !ooscript::isUndefined(value))
	{
		ooscript::valueToBoolean(context, (value), &textEntry);
	}
	if (textEntry)
	{
		[player setMissionChoiceByTextEntry:YES];
	}
	else
	{
		[player setMissionChoiceByTextEntry:NO];
	}

	// Start the mission screen.
	sCallbackFunction = function;
	[player setGuiToMissionScreenWithCallback:!ooscript::isNull(sCallbackFunction)];

	// Apply more settings. (These must be done after starting the screen for legacy reasons.)
	if (allowInterrupt)
	{
		[player allowMissionInterrupt];
	}
	NSString *message = GetParameterString(context, params, "message");
	if (message != nil)
	{
		[player addLiteralMissionText:message];
	}
	else
	{
		NSString *messageKey = GetParameterString(context, params, "messageKey");
		if (messageKey != nil)  [player addMissionText:messageKey];
	}
	
	if (!textEntry)
	{
		NSDictionary *choices = GetParameterDictionary(context, params, "choices");
		if (choices == nil)
		{
			[player setMissionChoices:GetParameterString(context, params, "choicesKey")];
		}
		else 
		{
			[player setMissionChoicesDictionary:choices];		
		}
	}

	NSString *firstKey = GetParameterString(context, params, "initialChoicesKey");
	if (firstKey != nil)
	{
		OOGUIRow row = [[UNIVERSE gui] rowForKey:firstKey];
		if (row != -1)
		{
			[[UNIVERSE gui] setSelectedRow:row];
		}
	}
	
	// now clean up!
	[player setMissionOverlayDescriptor:nil];
	[player setMissionBackgroundDescriptor:nil];
	[player setMissionTitle:nil];
	[player setMissionMusic:nil];
	
	OOJSResumeTimeLimiter();
	
	OOJS_RETURN_BOOL(YES);
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool MissionRunShipLibrary(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity	*player = OOPlayerForScripting();
	BOOL			OK = YES;
	if ([player status] != STATUS_DOCKED)
	{
		OOJSReportWarning(context, @"Mission.runShipLibrary: must be docked.");
		OK = NO;
	}
	else
	{
		[PLAYER setGuiToIntroFirstGo:NO];
	}
	
	OOJS_RETURN_BOOL(OK);
	
	OOJS_NATIVE_EXIT
}
} // namespace

